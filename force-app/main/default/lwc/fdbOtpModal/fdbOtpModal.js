import { LightningElement, api, track } from 'lwc';

const RESEND_COOLDOWN_SECONDS = 30;

/**
 * Passcode challenge shown over the profile screen. Purely presentational -
 * the parent sends the code, verifies it and decides what happens next.
 */
export default class FdbOtpModal extends LightningElement {
    /** Masked number the code went to, e.g. "+91 98XXXXXX10". */
    @api maskedDestination = '';

    /** Set by the parent while a verify or resend round trip is in flight. */
    @api isBusy = false;

    /** Message to show under the field; cleared as soon as the user types. */
    @api
    get error() {
        return this.errorMessage;
    }
    set error(value) {
        this.errorMessage = value || '';
    }

    @track errorMessage = '';
    @track code = '';
    @track secondsLeft = RESEND_COOLDOWN_SECONDS;

    timer;

    connectedCallback() {
        this.startCooldown();
    }

    disconnectedCallback() {
        this.clearTimer();
    }

    renderedCallback() {
        if (!this.hasFocused) {
            const input = this.template.querySelector('.ojo__input');
            if (input) {
                input.focus();
                this.hasFocused = true;
            }
        }
    }

    startCooldown() {
        this.clearTimer();
        this.secondsLeft = RESEND_COOLDOWN_SECONDS;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.timer = setInterval(() => {
            this.secondsLeft -= 1;
            if (this.secondsLeft <= 0) this.clearTimer();
        }, 1000);
    }

    clearTimer() {
        if (this.timer) {
            clearInterval(this.timer);
            this.timer = undefined;
        }
    }

    // ---- LABELS ----
    get verifyLabel() {
        return this.isBusy ? 'Verifying...' : 'Verify & Continue';
    }

    get isVerifyDisabled() {
        return this.isBusy || this.code.length < 6;
    }

    get isResendDisabled() {
        return this.isBusy || this.secondsLeft > 0;
    }

    get resendLabel() {
        return this.secondsLeft > 0
            ? `Resend code in ${this.secondsLeft}s`
            : 'Resend code';
    }

    // ---- INPUT ----
    handleCodeInput(event) {
        const digits = (event.target.value || '').replace(/[^0-9]/g, '').substring(0, 6);
        this.code = digits;
        event.target.value = digits;
        this.errorMessage = '';
    }

    handleKeyDown(event) {
        if (event.key === 'Enter' && !this.isVerifyDisabled) {
            event.preventDefault();
            this.handleVerify();
        }
    }

    // ---- ACTIONS ----
    handleVerify() {
        if (this.isVerifyDisabled) return;
        this.dispatchEvent(new CustomEvent('verify', { detail: { code: this.code } }));
    }

    handleResend() {
        if (this.isResendDisabled) return;
        this.code = '';
        this.errorMessage = '';
        this.startCooldown();
        this.dispatchEvent(new CustomEvent('resend'));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }
}