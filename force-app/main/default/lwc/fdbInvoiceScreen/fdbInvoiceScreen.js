import { LightningElement, api, track } from 'lwc';
import sendInvoiceEmailOtp from '@salesforce/apex/FeedbackController.sendInvoiceEmailOtp';
import verifyInvoiceOtp from '@salesforce/apex/FeedbackController.verifyInvoiceOtp';
import fetchCustomerInvoices from '@salesforce/apex/FeedbackController.fetchCustomerInvoices';

const SELECTION = {
    LATEST: 'Latest',
    SPECIFIC: 'Specific',
    LAST_12: 'Last12'
};

/** Detail lines, with the separator dropped when BC left a part of them blank. */
function joined(parts) {
    return parts.filter(part => part).join(' · ');
}

/**
 * The two addresses the screen can prove. REGISTERED is the one already on the
 * customer record; PROPOSED is a different address they would rather have the
 * invoice sent to. They are verified apart because a code proves one address
 * and says nothing about any other.
 */
const REGISTERED = 'registered';
const PROPOSED = 'proposed';

/** yyyy-MM-dd in local time, which is what lightning-input type="date" reads. */
function isoDate(value) {
    const pad = part => String(part).padStart(2, '0');
    return value.getFullYear()
        + '-' + pad(value.getMonth() + 1)
        + '-' + pad(value.getDate());
}

function blankMail(email) {
    return {
        email: email || '',
        otp: '',
        reference: '',
        sent: false,
        verified: false,
        error: '',
        loading: false
    };
}

/**
 * Optional step: request a copy of an invoice, sent to a verified address. Owns
 * the email/OTP exchange end to end; the parent raises the actual request once
 * this screen reports a verified address and a selection.
 *
 * Each choice reads the matching invoices out of Business Central so the
 * customer can see the bills being talked about rather than guessing.
 */
export default class FdbInvoiceScreen extends LightningElement {
    @api accountId;

    /**
     * The entry-gate verification. Apex re-checks it on every invoice read -
     * billing history does not go out on the strength of a screen change.
     */
    @api gateOtpReference = '';

    /** Both addresses, each with its own code, and each proved on its own. */
    @track mail = {
        [REGISTERED]: blankMail(''),
        [PROPOSED]: blankMail('')
    };

    /**
     * The address already on the customer record. When there is one it gets a
     * field of its own to confirm; when there is not, the screen asks for a new
     * address and nothing else.
     */
    @api
    get defaultEmail() {
        return this._defaultEmail;
    }
    set defaultEmail(value) {
        this._defaultEmail = value || '';
        // A record arriving late must not wipe a code already in flight.
        const registered = this.mail[REGISTERED];
        if (!registered.sent && !registered.verified) {
            this.patch(REGISTERED, { email: this._defaultEmail });
        }
    }
    _defaultEmail = '';

    /** Set by the parent while the invoice request is in flight. */
    @api isRaising = false;

    @track invoiceSelection = 'Latest';

    // ---- INVOICES READ FROM BUSINESS CENTRAL ----
    @track invoices = [];
    @track isLoadingInvoices = false;
    @track invoiceLoadError = '';

    /** Document numbers of the ticked estimates. Several, on the two lists that allow it. */
    @track pickedDocs = [];

    /** The range the Specific list reads over. Set from the date pickers. */
    @track fromDate = '';
    @track toDate = '';
    @track dateRangeError = '';

    /** Set once the first response lands, so "none found" is not shown before then. */
    @track hasLoadedInvoices = false;

    /**
     * Identifies the newest request. Choices are one tap apart, so a slow
     * reply for an abandoned choice can land after a fast one and overwrite
     * the list with the wrong invoices.
     */
    latestRequest = 0;

    connectedCallback() {
        // The range opens on the same year the other choices read, so switching
        // to Specific shows a list rather than an empty one waiting on dates.
        const today = new Date();
        const yearBack = new Date();
        yearBack.setMonth(yearBack.getMonth() - 12);
        this.fromDate = isoDate(yearBack);
        this.toDate = isoDate(today);

        // Opens on Latest, so show that bill without making them tap first.
        this.loadInvoices();
    }

    // ---- EMAIL FIELDS ----
    get hasRegisteredEmail() {
        return !!(this._defaultEmail && this._defaultEmail.trim());
    }

    /**
     * The cards the template draws. One when the customer has no address on
     * file, two when they do - the one we hold, and an optional different one.
     */
    get emailFields() {
        const fields = [];
        if (this.hasRegisteredEmail) {
            fields.push(this.fieldView(REGISTERED));
        }
        fields.push(this.fieldView(PROPOSED));
        return fields;
    }

    fieldView(key) {
        const state = this.mail[key];
        const isRegistered = key === REGISTERED;
        const isSpare = !isRegistered && this.hasRegisteredEmail;

        let title = 'Email Address';
        let hint = 'We have no email address on your record. Enter one and verify it.';
        if (isRegistered) {
            title = 'Registered Email Address';
            hint = 'The address on your record. Verify it to have the invoice sent here.';
        } else if (isSpare) {
            title = 'Send To A Different Email';
            hint = 'Only if you want the invoice somewhere else. Leave it blank to use your registered address.';
        }

        return {
            key,
            title,
            hint,
            email: state.email,
            otp: state.otp,
            error: state.error,
            /** The registered address is confirmed, never retyped, so it is shown as text. */
            isFixed: isRegistered,
            isOptional: isSpare,
            isVerified: state.verified,
            isBusy: state.loading,
            showSend: !state.sent && !state.verified,
            // Codes expire, so there is always a way to ask for another one
            // without retyping the address to reset the card.
            showOtpInput: state.sent && !state.verified,
            buttonLabel: this.codeButtonLabel(state),
            statusLabel: state.verified ? 'Verified' : (state.sent ? 'Code Sent' : 'Not Verified'),
            statusClass: 'oji__mail-status'
                + (state.verified ? ' oji__mail-status_on' : (state.sent ? ' oji__mail-status_wait' : '')),
            cardClass: 'oji__mail' + (state.verified ? ' oji__mail_on' : '')
        };
    }

    codeButtonLabel(state) {
        if (state.loading) {
            return state.sent ? 'Verifying...' : 'Sending...';
        }
        return state.sent ? 'Verify OTP' : 'Send OTP';
    }

    // ---- WHERE THE INVOICE GOES ----
    get proposedAddress() {
        return (this.mail[PROPOSED].email || '').trim();
    }

    /**
     * The different address once it is proved, the registered one otherwise.
     * Only ever a verified address - an unproved one is not a destination.
     */
    get destination() {
        if (this.proposedAddress && this.mail[PROPOSED].verified) {
            return this.mail[PROPOSED];
        }
        if (this.hasRegisteredEmail && this.mail[REGISTERED].verified) {
            return this.mail[REGISTERED];
        }
        return null;
    }

    get destinationEmail() {
        return this.destination ? this.destination.email.trim() : '';
    }

    /**
     * Typed a different address but not proved it. Falling back to the
     * registered one here would send the invoice to an address they have just
     * said they did not want, so the request waits instead.
     */
    get hasUnverifiedProposed() {
        return !!this.proposedAddress && !this.mail[PROPOSED].verified;
    }

    get showDestination() {
        return !!this.destinationEmail && !this.hasUnverifiedProposed;
    }

    get raiseInvoiceLabel() {
        return this.isRaising ? 'Sending Request...' : 'Raise Invoice Request';
    }

    get isRaiseInvoiceDisabled() {
        return this.isRaising
            || !this.invoiceSelection
            || !this.destinationEmail
            || this.hasUnverifiedProposed
            // Where there are bills to tick, one of them has to be ticked.
            || (this.hasInvoices && !this.pickedCount);
    }

    invoiceChoiceClass(type) {
        return this.invoiceSelection === type ? 'oji__choice oji__choice_on' : 'oji__choice';
    }

    get latestInvoiceClass() { return this.invoiceChoiceClass('Latest'); }
    get specificInvoiceClass() { return this.invoiceChoiceClass('Specific'); }
    get last12InvoiceClass() { return this.invoiceChoiceClass('Last12'); }

    selectLatestInvoice() { this.chooseSelection(SELECTION.LATEST); }
    selectSpecificInvoice() { this.chooseSelection(SELECTION.SPECIFIC); }
    selectLast12Invoice() { this.chooseSelection(SELECTION.LAST_12); }

    /**
     * Latest and Last 12 Months read the same customer over different date
     * windows, so every change of choice means a fresh read.
     */
    chooseSelection(selection) {
        if (this.invoiceSelection === selection) return;
        this.invoiceSelection = selection;
        this.dateRangeError = '';
        this.loadInvoices();
    }

    // ---- DATE RANGE (SPECIFIC ONLY) ----
    /** Only the specific-invoice list is read over a range the customer sets. */
    get showDateRange() {
        return this.invoiceSelection === SELECTION.SPECIFIC;
    }

    handleFromDateChange(event) {
        this.fromDate = event.target.value;
        this.reloadForRange();
    }

    handleToDateChange(event) {
        this.toDate = event.target.value;
        this.reloadForRange();
    }

    /**
     * A back-to-front range is answered here rather than at the callout - BC
     * would return an empty list, which reads as "you have no invoices".
     */
    reloadForRange() {
        if (this.fromDate && this.toDate && this.fromDate > this.toDate) {
            this.dateRangeError = 'The "from" date has to be on or before the "to" date.';
            return;
        }
        this.dateRangeError = '';
        this.loadInvoices();
    }

    // ---- INVOICE LIST ----
    loadInvoices() {
        if (!this.accountId) return;

        const request = ++this.latestRequest;
        this.isLoadingInvoices = true;
        this.invoiceLoadError = '';
        this.invoices = [];
        this.pickedDocs = [];

        fetchCustomerInvoices({
            accountId: this.accountId,
            selectionType: this.invoiceSelection,
            otpReference: this.gateOtpReference,
            // Sent on every read; Apex only honours them for Specific.
            fromDate: this.fromDate,
            toDate: this.toDate
        })
            .then(result => {
                if (request !== this.latestRequest) return;
                this.isLoadingInvoices = false;
                this.hasLoadedInvoices = true;
                this.invoices = result || [];
                this.pickedDocs = this.defaultPicks();
            })
            .catch(error => {
                if (request !== this.latestRequest) return;
                this.isLoadingInvoices = false;
                this.hasLoadedInvoices = true;
                this.invoices = [];
                this.pickedDocs = [];
                this.invoiceLoadError = error.body ? error.body.message : error.message;
            });
    }

    /**
     * What each choice means, applied to the list it just returned. Last 12
     * Months asks for the year, so the year arrives ticked; Specific asks for
     * particular bills, so nothing is ticked until they say which.
     */
    defaultPicks() {
        if (!this.invoices.length) return [];
        if (this.invoiceSelection === SELECTION.SPECIFIC) return [];
        return this.invoices.map(inv => inv.documentNo);
    }

    /** Both lists that allow more than one bill are ticked, not chosen singly. */
    get isMultiPick() {
        return this.invoiceSelection === SELECTION.SPECIFIC
            || this.invoiceSelection === SELECTION.LAST_12;
    }

    handlePickInvoice(event) {
        const doc = event.target.dataset.doc;

        if (!this.isMultiPick) {
            this.pickedDocs = [doc];
            return;
        }

        this.pickedDocs = this.pickedDocs.includes(doc)
            ? this.pickedDocs.filter(picked => picked !== doc)
            : [...this.pickedDocs, doc];
    }

    handleSelectAllInvoices() {
        this.pickedDocs = this.allPicked
            ? []
            : this.invoices.map(inv => inv.documentNo);
    }

    get allPicked() {
        return this.hasInvoices && this.pickedDocs.length === this.invoices.length;
    }

    get selectAllLabel() {
        return this.allPicked ? 'Clear All' : 'Select All';
    }

    get pickedCount() {
        return this.pickedDocs.length;
    }

    /** Only worth showing once there is a list standing there to tick. */
    get showPickBar() {
        return this.isMultiPick && this.hasInvoices && !this.isLoadingInvoices;
    }

    get pickedSummary() {
        const count = this.pickedCount;
        if (!count) return 'No invoices selected yet';
        return count === 1 ? '1 invoice selected' : count + ' invoices selected';
    }

    /**
     * Rows carry their own class and their own joined-up detail lines, because
     * a template cannot drop a separator only when both halves are present.
     */
    get invoiceRows() {
        return this.invoices.map(inv => {
            const isPicked = this.pickedDocs.includes(inv.documentNo);
            return {
                ...inv,
                isPicked,
                whereLine: joined([inv.dateDisplay, inv.locationName]),
                whoLine: joined([inv.customerName, inv.customerCode]),
                rowClass: isPicked && this.isPickable
                    ? 'oji__bill oji__bill_on'
                    : 'oji__bill'
            };
        });
    }

    /** One bill on a single-pick list needs no control at all. */
    get isPickable() {
        return this.isMultiPick || this.invoices.length > 1;
    }

    get invoiceListHeading() {
        if (this.invoiceSelection === SELECTION.SPECIFIC) return 'Choose Your Invoices';
        if (this.invoiceSelection === SELECTION.LAST_12) return 'Invoices From The Last 12 Months';
        return 'Your Latest Invoice';
    }

    get hasInvoices() {
        return this.invoices.length > 0;
    }

    get showNoInvoices() {
        return this.hasLoadedInvoices
            && !this.isLoadingInvoices
            && !this.invoiceLoadError
            && !this.hasInvoices;
    }

    /**
     * The ticked estimates, as the payload the request carries. Built off the
     * rows themselves rather than the document numbers alone, so whatever
     * eventually stores this has the bill in front of it and not just a key.
     */
    get selectedInvoices() {
        return this.invoices.filter(inv => this.pickedDocs.includes(inv.documentNo));
    }

    // ---- EMAIL & OTP ----
    /** Every card writes back through here, so both stay independent. */
    patch(key, changes) {
        this.mail = {
            ...this.mail,
            [key]: { ...this.mail[key], ...changes }
        };
    }

    handleInvoiceEmailChange(e) {
        // A code proves one address. Change the address and it proves nothing.
        this.patch(e.target.dataset.key, {
            email: e.target.value,
            otp: '',
            reference: '',
            sent: false,
            verified: false,
            error: ''
        });
    }

    handleInvoiceOtpChange(e) {
        this.patch(e.target.dataset.key, { otp: e.target.value });
    }

    handleInvoiceSendVerifyOtp(e) {
        const key = e.currentTarget.dataset.key;
        const state = this.mail[key];
        if (state.loading) return;

        if (!state.email || !state.email.trim()) {
            this.patch(key, { error: 'Please enter an email address first.' });
            return;
        }

        if (!state.sent) {
            this.sendCode(key);
        } else {
            this.verifyCode(key);
        }
    }

    handleResendCode(e) {
        const key = e.currentTarget.dataset.key;
        if (this.mail[key].loading) return;
        this.patch(key, { otp: '' });
        this.sendCode(key);
    }

    sendCode(key) {
        this.patch(key, { loading: true, error: '' });

        sendInvoiceEmailOtp({
            accountId: this.accountId,
            emailAddress: this.mail[key].email
        })
        .then(result => {
            if (result && result.success) {
                this.patch(key, { loading: false, reference: result.reference, sent: true });
            } else {
                this.patch(key, {
                    loading: false,
                    error: (result && result.message) || 'Failed to send OTP'
                });
            }
        })
        .catch(error => {
            this.patch(key, {
                loading: false,
                error: error.body ? error.body.message : error.message
            });
        });
    }

    verifyCode(key) {
        const state = this.mail[key];
        if (!state.otp || state.otp.length < 4) {
            this.patch(key, { error: 'Please enter a valid OTP' });
            return;
        }
        this.patch(key, { loading: true, error: '' });

        verifyInvoiceOtp({ otpReference: state.reference, otpCode: state.otp })
            .then(isValid => {
                if (isValid) {
                    this.patch(key, { loading: false, verified: true, error: '' });
                } else {
                    this.patch(key, {
                        loading: false,
                        error: 'That code is not correct. Please check and try again.'
                    });
                }
            })
            .catch(error => {
                // Expired, consumed or too many attempts - the message explains itself
                this.patch(key, {
                    loading: false,
                    error: error.body ? error.body.message : error.message
                });
            });
    }

    // ---- ACTIONS ----
    handleRaiseInvoice() {
        if (this.isRaiseInvoiceDisabled) return;
        const destination = this.destination;
        this.dispatchEvent(new CustomEvent('raise', {
            detail: {
                email: destination.email.trim(),
                selection: this.invoiceSelection,
                // The reference for the address being sent to, not whichever
                // was proved last. Apex re-checks it rather than trusting the
                // screen's own "verified" flag, which is only a client-side
                // boolean.
                otpReference: destination.reference,
                /** The ticked estimates themselves, for whatever stores them. */
                selectedInvoicesJson: JSON.stringify(this.selectedInvoices)
            }
        }));
    }

    handleSkipInvoice() {
        this.dispatchEvent(new CustomEvent('skip'));
    }

    handleNav() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleHelp() {
        this.dispatchEvent(new CustomEvent('help'));
    }
}