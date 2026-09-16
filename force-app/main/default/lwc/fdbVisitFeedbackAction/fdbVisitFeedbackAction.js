import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import CUSTOMER_FIELD from '@salesforce/schema/Showroom_Visit__c.CUSTOMERlookup__c';

import updateFeedbackToInProgress from '@salesforce/apex/FeedbackController.updateFeedbackToInProgress';
import submitCustomerFeedback from '@salesforce/apex/FeedbackController.submitCustomerFeedback';

import { isAlreadySubmittedError } from 'c/fdbUtils';

/**
 * The questionnaire on its own, opened as a quick action from a showroom
 * visit - for the times a customer answers at the counter rather than on the
 * kiosk. Nothing about the saving is new: it claims the visit's Feedback__c
 * and submits it through the same two Apex calls the kiosk uses, so a
 * response raised here is indistinguishable from one raised there, escalation
 * cases and all.
 *
 * Every visit has a feedback record already, so opening is only a question of
 * what state it is in: Pending or In Progress and the questions open,
 * Completed and it says so. updateFeedbackToInProgress decides that in one
 * round trip - it moves the record on and hands back its id, or raises
 * ALREADY_SUBMITTED - which also settles it against two people opening the
 * same visit at once, in a way reading the status first could not.
 */
export default class FdbVisitFeedbackAction extends LightningElement {
    /**
     * Taken through a setter, not a plain field. A quick action does not have
     * the record id ready when the component connects - it arrives a beat
     * later - so claiming the feedback from connectedCallback sent Apex a
     * null, and a null matched a feedback record with no visit attached at
     * all. The claim starts when the id does.
     */
    _recordId;
    claimStarted = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value && !this.claimStarted) {
            this.claimStarted = true;
            this.claimFeedback();
        }
    }

    @track isLoading = true;
    @track isSubmitting = false;

    /** The feedback for this visit is already Completed - nothing to fill in. */
    @track isCompleted = false;

    /** Set only when something actually went wrong. */
    @track errorMessage = '';

    feedbackId = null;

    @track accountId = null;

    /** Set once the wire has answered either way, so a pending read is not
     *  mistaken for a missing customer. */
    @track accountResolved = false;

    /**
     * The customer behind the visit. Needed at submit: an escalation case is
     * raised against them when the answers are poor enough, and a case with no
     * account behind it is no use to anyone.
     */
    @wire(getRecord, { recordId: '$recordId', fields: [CUSTOMER_FIELD] })
    wiredVisit({ data, error }) {
        if (data) {
            this.accountId = getFieldValue(data, CUSTOMER_FIELD);
            this.accountResolved = true;
        } else if (error) {
            this.accountResolved = true;
            console.error('Could not read the customer on this visit: ', error);
            this.errorMessage = 'The customer on this visit could not be read, so feedback cannot be recorded here.';
        }
    }

    /** Still opening: the record claimed, or the customer read, or both. */
    get isBusy() {
        return this.isLoading || (!this.accountResolved && !this.isCompleted && !this.errorMessage);
    }

    /** Both halves have to be in hand: the record to write, and who it is for. */
    get showForm() {
        return !this.isBusy && !this.isCompleted && !this.errorMessage
            && !!this.feedbackId && !!this.accountId;
    }

    claimFeedback() {
        updateFeedbackToInProgress({ showroomVisitId: this._recordId })
            .then(feedbackId => {
                this.feedbackId = feedbackId;
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                if (isAlreadySubmittedError(error)) {
                    this.isCompleted = true;
                    return;
                }
                console.error('Could not open feedback for this visit: ', error);
                this.errorMessage = error.body ? error.body.message : error.message;
            });
    }

    handleSubmit(event) {
        if (this.isSubmitting) return;

        const { answers, comments, language } = event.detail;
        this.isSubmitting = true;

        submitCustomerFeedback({
            feedbackId: this.feedbackId,
            accountId: this.accountId,
            answers,
            comments,
            language
        })
        .then(() => {
            this.isSubmitting = false;
            this.toast('Feedback Saved', 'Thank you - the response has been recorded.', 'success');
            // The visit's feedback has changed underneath the page that opened us
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            this.handleClose();
        })
        .catch(error => {
            this.isSubmitting = false;
            if (isAlreadySubmittedError(error)) {
                // Somebody else finished it while this one was being filled in
                this.isCompleted = true;
                return;
            }
            console.error('Error submitting feedback: ', error);
            this.toast('Could Not Save', error.body ? error.body.message : error.message, 'error');
        });
    }

    handleIncomplete() {
        this.toast('Required Questions',
            'Please answer all the rating questions before submitting.', 'warning');
    }

    handleHelp() {
        this.toast('Need help?',
            'Answer each question with a star rating, then submit. Comments are optional.', 'info');
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}