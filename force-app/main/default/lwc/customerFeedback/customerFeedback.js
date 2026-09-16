import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import searchCustomerJourney from '@salesforce/apex/cSearch.searchCustomerJourney';
import sendProfileUpdateOtp from '@salesforce/apex/FeedbackController.sendProfileUpdateOtp';
import verifyAndSubmitProfileUpdate from '@salesforce/apex/FeedbackController.verifyAndSubmitProfileUpdate';
import sendInvoiceEmailRequest from '@salesforce/apex/FeedbackController.sendInvoiceEmailRequest';
import sendInvoiceOtp from '@salesforce/apex/FeedbackController.sendInvoiceOtp';
import verifyInvoiceOtp from '@salesforce/apex/FeedbackController.verifyInvoiceOtp';
import submitCustomerFeedback from '@salesforce/apex/FeedbackController.submitCustomerFeedback';
import updateFeedbackToInProgress from '@salesforce/apex/FeedbackController.updateFeedbackToInProgress';

import {
    buildVisitModel,
    buildCustomerOnlyModel,
    formatDateTime,
    isAlreadySubmittedError
} from 'c/fdbUtils';

const SCREEN = {
    WELCOME: 'WELCOME',
    SEARCH: 'SEARCH',
    NOT_FOUND: 'NOT_FOUND',
    NO_VISIT: 'NO_VISIT',
    PROFILE: 'PROFILE',
    FEEDBACK: 'FEEDBACK',
    DONE: 'DONE',
    ALREADY_SUBMITTED: 'ALREADY_SUBMITTED',
    INVOICE: 'INVOICE',
    INVOICE_DONE: 'INVOICE_DONE'
};

/**
 * Orchestrates the customer feedback journey. This component owns the screen
 * state machine, the Apex calls that move the journey along, and the selected
 * visit; each screen is a presentational child that reports back with events.
 */
export default class CustomerFeedback extends LightningElement {

    @track screen = SCREEN.WELCOME;
    @track selectedVisit = null;
    @track visitList = [];

    // Search state
    @track searchError = '';
    @track isSearching = false;

    // In-flight flags handed down to the screens that need them
    @track isSubmittingFeedback = false;
    @track isRaiseInvoiceLoading = false;

    /** True when the profile screen was opened to edit rather than to start feedback. */
    @track profileUpdateMode = false;

    // OTP challenge that gates profile changes
    @track showOtpModal = false;
    @track isOtpBusy = false;
    @track otpError = '';
    @track otpMaskedDestination = '';
    otpReference = '';

    /**
     * The verification that opened the invoice screen, kept so the screen can
     * present it when it reads billing history. Held apart from otpReference,
     * which the email verification inside that screen reuses.
     */
    @track invoiceGateOtpReference = '';
    pendingChanges = [];

    /**
     * Which journey the passcode modal is serving: 'profile' for a profile
     * update, 'invoice' for the gate on the way into the invoice screen. The
     * modal is the same either way; what a verified code then does is not.
     */
    otpFlow = 'profile';

    /** Customer behind the "no visit today" screen, so profile edit needs no re-search. */
    noVisitCustomer = null;

    /** Screen the invoice step was opened from, so Back / Skip can return there. */
    invoiceReturnScreen = SCREEN.DONE;

    /** Verified address the invoice was requested for, shown on the confirmation. */
    @track invoiceRequestedEmail = '';

    currentFeedbackId = null;

    columns = [
        { label: 'Visit No', fieldName: 'Name' },
        { label: 'Customer Name', fieldName: 'CustomerName' },
        { label: 'Phone', fieldName: 'MaskedPhone', type: 'text' },
        { label: 'Store', fieldName: 'StoreName' },
        { label: 'Status', fieldName: 'VisitStatus' },
        {
            type: 'button',
            typeAttributes: {
                // Stays clickable when already submitted so the row opens the
                // "already submitted" screen rather than doing nothing.
                label: { fieldName: 'SelectLabel' },
                name: 'Select',
                variant: { fieldName: 'SelectVariant' }
            }
        }
    ];

    // ---------------------------------------------------------------- SCREENS
    get isWelcomeScreen() { return this.screen === SCREEN.WELCOME; }
    get showSearchScreen() { return this.screen === SCREEN.SEARCH; }
    get isNotFoundScreen() { return this.screen === SCREEN.NOT_FOUND; }
    get isNoVisitScreen() { return this.screen === SCREEN.NO_VISIT; }
    get isProfileScreen() { return this.screen === SCREEN.PROFILE; }
    get isFeedbackScreen() { return this.screen === SCREEN.FEEDBACK; }
    get isDoneScreen() { return this.screen === SCREEN.DONE; }
    get isAlreadySubmittedScreen() { return this.screen === SCREEN.ALREADY_SUBMITTED; }
    get isInvoiceScreen() { return this.screen === SCREEN.INVOICE; }
    get isInvoiceDoneScreen() { return this.screen === SCREEN.INVOICE_DONE; }

    get showSearchTable() {
        return this.visitList.length > 1;
    }

    get accountId() {
        return this.selectedVisit?.CUSTOMERlookup__c;
    }

    get customerEmail() {
        return this.selectedVisit?.CUSTOMERlookup__r?.Email_Address__c || '';
    }

    // ----------------------------------------------------------------- SHARED
    handleHelp() {
        this.toast('Need help?', 'Please ask any Orient Jewellers staff member to assist you.', 'info');
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleStartFeedback() {
        this.screen = SCREEN.SEARCH;
    }

    // ----------------------------------------------------------------- SEARCH
    handleClearSearchError() {
        this.searchError = '';
    }

    handleSearch(event) {
        const phone = event.detail.phone;

        this.visitList = [];
        this.selectedVisit = null;
        this.noVisitCustomer = null;
        this.searchError = '';

        if (!phone || phone.length < 10) {
            this.searchError = 'Please enter a valid 10-digit mobile number.';
            return;
        }

        this.isSearching = true;

        searchCustomerJourney({ phoneKey: phone })
            .then(result => {
                this.isSearching = false;

                const visits = (result && result.visits) || [];
                this.visitList = visits.map(visit => buildVisitModel(visit));

                if (this.visitList.length === 1) {
                    this.selectVisit(this.visitList[0]);
                } else if (this.visitList.length > 1) {
                    // the search screen renders the result table on its own
                } else if (result && result.customer) {
                    // Customer exists but has not visited today. There is no
                    // Feedback__c to fill in, so land on the visit-not-found
                    // screen; a profile update request can still be raised there.
                    this.noVisitCustomer = result.customer;
                    this.screen = SCREEN.NO_VISIT;
                } else {
                    this.screen = SCREEN.NOT_FOUND;
                }
            })
            .catch(error => {
                console.error(error);
                this.isSearching = false;
                this.visitList = [];
                this.screen = SCREEN.NOT_FOUND;
            });
    }

    handleSelectVisit(event) {
        this.selectVisit(event.detail.row);
    }

    /**
     * Back from the search screen. Nothing has been chosen yet, so this is the
     * same as starting over - the number just typed is left behind rather than
     * waiting on the screen for the next customer.
     */
    handleSearchBack() {
        this.resetJourney();
    }

    /**
     * One feedback per showroom visit: a visit that already has a completed
     * Feedback__c never re-enters the questionnaire.
     */
    selectVisit(visit) {
        this.selectedVisit = visit;
        this.visitList = [];

        if (visit.HasCompletedFeedback) {
            this.screen = SCREEN.ALREADY_SUBMITTED;
            return;
        }
        this.profileUpdateMode = false;
        this.screen = SCREEN.PROFILE;
    }

    /** "Search Again" from any dead-end screen. */
    handleSearchAgain() {
        this.noVisitCustomer = null;
        this.selectedVisit = null;
        this.visitList = [];
        this.searchError = '';
        this.screen = SCREEN.SEARCH;

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            const search = this.template.querySelector('c-fdb-search-screen');
            if (search) search.reset();
        });
    }

    // ---------------------------------------------------------------- PROFILE
    /** "Update My Profile" from the Visit Not Found screen. */
    handleUpdateProfileFromNoVisit() {
        if (!this.noVisitCustomer) return;
        this.selectedVisit = buildCustomerOnlyModel(this.noVisitCustomer);
        this.profileUpdateMode = false;
        this.screen = SCREEN.PROFILE;
    }

    /** "Yes, Update My Profile" from the post-feedback screen. */
    handleUpdateProfileAfterFeedback() {
        this.profileUpdateMode = true;
        this.screen = SCREEN.PROFILE;
    }

    /**
     * Back from the profile screen: to the post-feedback screen when the
     * customer came from there, otherwise out to the search screen.
     */
    handleProfileBack() {
        if (this.profileUpdateMode) {
            this.profileUpdateMode = false;
            this.screen = SCREEN.DONE;
            return;
        }
        this.selectedVisit = null;
        this.screen = SCREEN.SEARCH;
    }

    /**
     * Profile screen CTA. With no changes the journey just moves on; with
     * changes the customer is challenged by SMS first, and nothing reaches the
     * approval queue until that code is verified.
     */
    handleProfileContinue(event) {
        const changes = event.detail.changes || [];

        if (changes.length === 0) {
            this.advanceFromProfile(false);
            return;
        }

        this.pendingChanges = changes;
        this.requestOtp();
    }

    /**
     * The destinations just typed, if any. Apex sends the code to whichever one
     * matches the channel it picks, and falls back to what is already on the
     * record when that field is not being changed.
     */
    newValueFor(fieldName) {
        const change = this.pendingChanges.find(c => c.fieldName === fieldName);
        return change ? change.newValue : '';
    }

    /**
     * The fields being changed. Apex picks the template from these, since each
     * kind of change is registered with its own wording - and, for an email
     * change, its own channel.
     */
    get otpChangedFields() {
        return this.pendingChanges.map(c => c.fieldName);
    }

    requestOtp() {
        this.isOtpBusy = true;
        this.otpError = '';

        sendProfileUpdateOtp({
            accountId: this.selectedVisit.CUSTOMERlookup__c,
            newMobile: this.newValueFor('Mobile'),
            newEmail: this.newValueFor('Email'),
            changedFields: this.otpChangedFields
        })
            .then(result => {
                this.isOtpBusy = false;
                if (!result || !result.success) {
                    this.showOtpModal = false;
                    this.toast('Could Not Send Code',
                        (result && result.message) || 'Please ask our showroom team for help.', 'error');
                    return;
                }
                this.otpReference = result.reference;
                this.otpMaskedDestination = result.maskedDestination;
                this.showOtpModal = true;
            })
            .catch(error => {
                this.isOtpBusy = false;
                this.showOtpModal = false;
                console.error('Failed to send profile update OTP: ', error);
                this.toast('Could Not Send Code',
                    error.body ? error.body.message : error.message, 'error');
            });
    }

    handleOtpResend() {
        if (this.otpFlow === 'invoice') {
            this.requestInvoiceOtp();
            return;
        }
        this.requestOtp();
    }

    handleOtpCancel() {
        this.showOtpModal = false;
        this.otpReference = '';
        this.otpError = '';
        this.pendingChanges = [];
        // Cancelling the invoice gate leaves the customer where they were,
        // which the screen state already is - nothing else to undo.
        this.otpFlow = 'profile';
    }

    handleOtpVerify(event) {
        if (this.otpFlow === 'invoice') {
            this.verifyInvoiceCode(event.detail.code);
            return;
        }

        this.isOtpBusy = true;
        this.otpError = '';

        verifyAndSubmitProfileUpdate({
            accountId: this.selectedVisit.CUSTOMERlookup__c,
            showroomVisitId: this.selectedVisit.Id,
            payloadJson: JSON.stringify(this.pendingChanges),
            otpReference: this.otpReference,
            otpCode: event.detail.code
        })
        .then(logId => {
            this.isOtpBusy = false;
            if (!logId) {
                // Wrong code: the modal stays open so they can try again
                this.otpError = 'That code is not correct. Please check and try again.';
                return;
            }
            this.showOtpModal = false;
            this.otpReference = '';
            this.pendingChanges = [];
            this.advanceFromProfile(true);
        })
        .catch(error => {
            this.isOtpBusy = false;
            // Expired, consumed or too many attempts - the message explains itself
            this.otpError = error.body ? error.body.message : error.message;
        });
    }

    advanceFromProfile(didRequestChanges) {
        if (this.profileUpdateMode) {
            // Raised from the post-feedback screen: acknowledge and go back to
            // it, so the invoice request is still within reach.
            if (didRequestChanges) {
                this.toast('Request Recorded',
                    'Your profile update request has been submitted for approval.', 'success');
            } else {
                this.toast('No Changes Requested',
                    'Nothing was selected for update, so no request was raised.', 'info');
            }
            this.profileUpdateMode = false;
            this.screen = SCREEN.DONE;
            return;
        }

        if (this.selectedVisit?.HasVisitToday !== true) {
            // No visit today means no Feedback__c record exists, so there is
            // nothing to collect. Acknowledge and start over.
            this.toast('Thank You!',
                'Your request has been recorded. No showroom visit was found for today, so there is no visit feedback to collect.',
                'success');
            this.resetJourney();
            return;
        }

        this.navigateToFeedback();
    }

    // --------------------------------------------------------------- FEEDBACK
    async navigateToFeedback() {
        try {
            this.currentFeedbackId = await updateFeedbackToInProgress({
                showroomVisitId: this.selectedVisit.Id
            });
            this.screen = SCREEN.FEEDBACK;
        } catch (error) {
            // Another device may have submitted since this journey started
            if (isAlreadySubmittedError(error)) {
                this.screen = SCREEN.ALREADY_SUBMITTED;
                return;
            }
            console.error('Error updating feedback to In Progress: ', error);
            this.screen = SCREEN.FEEDBACK;
        }
    }

    handleBackToProfile() {
        this.screen = SCREEN.PROFILE;
    }

    handleFeedbackIncomplete() {
        this.toast('Required Fields',
            'Please answer all the rating questions before submitting.', 'warning');
    }

    handleFeedbackSubmit(event) {
        if (this.isSubmittingFeedback) return;

        const { answers, comments, language } = event.detail;
        this.isSubmittingFeedback = true;

        submitCustomerFeedback({
            feedbackId: this.currentFeedbackId,
            accountId: this.selectedVisit.CUSTOMERlookup__c,
            answers,
            comments,
            language
        })
        .then(() => {
            this.isSubmittingFeedback = false;
            // Mark it locally too, so returning to this visit lands on the
            // already-submitted screen without another round trip.
            this.selectedVisit = {
                ...this.selectedVisit,
                HasCompletedFeedback: true,
                FeedbackSubmittedAt: formatDateTime(new Date().toISOString())
            };
            this.screen = SCREEN.DONE;
        })
        .catch(error => {
            this.isSubmittingFeedback = false;
            if (isAlreadySubmittedError(error)) {
                this.screen = SCREEN.ALREADY_SUBMITTED;
                return;
            }
            console.error('Error submitting feedback: ', error);
            this.toast('Error', error.body ? error.body.message : error.message, 'error');
        });
    }

    handleCloseFeedback() {
        this.resetJourney();
    }

    // ---------------------------------------------------------------- INVOICE
    /**
     * Offered from both post-feedback screens, so remember where to return.
     *
     * An invoice is a record of what somebody bought, so the screen is gated:
     * a code goes to the number on the customer record and only a verified code
     * opens it. The tablet is handed around a showroom, so whoever is holding
     * it is not necessarily the customer.
     */
    handleRequestInvoice() {
        this.invoiceReturnScreen = this.screen;
        this.otpFlow = 'invoice';
        this.requestInvoiceOtp();
    }

    requestInvoiceOtp() {
        this.isOtpBusy = true;
        this.otpError = '';

        sendInvoiceOtp({ accountId: this.selectedVisit.CUSTOMERlookup__c })
            .then(result => {
                this.isOtpBusy = false;
                if (!result || !result.success) {
                    this.showOtpModal = false;
                    this.otpFlow = 'profile';
                    this.toast('Could Not Send Code',
                        (result && result.message) || 'Please ask our showroom team for help.', 'error');
                    return;
                }
                this.otpReference = result.reference;
                this.otpMaskedDestination = result.maskedDestination;
                this.showOtpModal = true;
            })
            .catch(error => {
                this.isOtpBusy = false;
                this.showOtpModal = false;
                this.otpFlow = 'profile';
                console.error('Failed to send invoice OTP: ', error);
                this.toast('Could Not Send Code',
                    error.body ? error.body.message : error.message, 'error');
            });
    }

    verifyInvoiceCode(code) {
        this.isOtpBusy = true;
        this.otpError = '';

        verifyInvoiceOtp({ otpReference: this.otpReference, otpCode: code })
            .then(isValid => {
                this.isOtpBusy = false;
                if (!isValid) {
                    // Wrong code: the modal stays open so they can try again
                    this.otpError = 'That code is not correct. Please check and try again.';
                    return;
                }
                this.showOtpModal = false;
                // Handed to the invoice screen: Apex will not part with billing
                // history on the strength of a screen change alone.
                this.invoiceGateOtpReference = this.otpReference;
                this.otpReference = '';
                this.otpFlow = 'profile';
                this.screen = SCREEN.INVOICE;
            })
            .catch(error => {
                this.isOtpBusy = false;
                // Expired, consumed or too many attempts - the message explains itself
                this.otpError = error.body ? error.body.message : error.message;
            });
    }

    handleBackFromInvoice() {
        this.screen = this.invoiceReturnScreen || SCREEN.DONE;
    }

    handleSkipInvoice() {
        this.handleBackFromInvoice();
    }

    /**
     * Logs the request and lands on its own confirmation screen. Nothing is
     * emailed from the kiosk - the team sends the invoice from the back office,
     * so what this step produces is a record of the ask against a verified
     * address.
     */
    handleRaiseInvoice(event) {
        const { email, selection, otpReference, selectedInvoicesJson } = event.detail;
        this.isRaiseInvoiceLoading = true;

        sendInvoiceEmailRequest({
            // The customer's Account - the same one the screen read invoices
            // for, and what the case is raised against.
            accountId: this.accountId,
            showroomVisitId: this.selectedVisit.Id,
            emailAddress: email,
            selectionType: selection,
            otpReference,
            selectedInvoicesJson
        })
        .then(result => {
            this.isRaiseInvoiceLoading = false;
            if (result === 'Success') {
                this.invoiceRequestedEmail = email;
                this.screen = SCREEN.INVOICE_DONE;
                return;
            }
            this.toast('Notice', result, 'info');
            this.handleBackFromInvoice();
        })
        .catch(error => {
            this.isRaiseInvoiceLoading = false;
            console.error('Error raising invoice request: ', error);
            this.toast('Could Not Raise Request',
                error.body ? error.body.message : error.message, 'error');
        });
    }

    handleCloseInvoiceDone() {
        this.resetJourney();
    }

    // ------------------------------------------------------------------ RESET
    /** Clears everything so the next customer starts from a blank kiosk. */
    resetJourney() {
        this.screen = SCREEN.WELCOME;
        this.selectedVisit = null;
        this.visitList = [];
        this.noVisitCustomer = null;
        this.currentFeedbackId = null;
        this.searchError = '';
        this.isSearching = false;
        this.isSubmittingFeedback = false;
        this.isRaiseInvoiceLoading = false;
        this.profileUpdateMode = false;
        this.invoiceGateOtpReference = '';
        this.invoiceReturnScreen = SCREEN.DONE;
        this.invoiceRequestedEmail = '';

        this.showOtpModal = false;
        this.isOtpBusy = false;
        this.otpError = '';
        this.otpMaskedDestination = '';
        this.otpReference = '';
        this.pendingChanges = [];
        this.otpFlow = 'profile';
    }
}