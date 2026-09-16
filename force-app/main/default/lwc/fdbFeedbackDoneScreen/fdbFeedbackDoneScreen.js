import { LightningElement } from 'lwc';

/** Confirmation after a successful submission, offering the follow-up actions. */
export default class FdbFeedbackDoneScreen extends LightningElement {

    handleUpdateProfileAfterFeedback() {
        this.dispatchEvent(new CustomEvent('updateprofile'));
    }

    handleRequestInvoiceAfterFeedback() {
        this.dispatchEvent(new CustomEvent('requestinvoice'));
    }

    handleCloseFeedback() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleNav() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleHelp() {
        this.dispatchEvent(new CustomEvent('help'));
    }
}