import { LightningElement, api } from 'lwc';

/** Confirmation after an invoice copy has been requested. */
export default class FdbInvoiceDoneScreen extends LightningElement {

    /** The verified address the invoice is going to, shown back for reassurance. */
    @api email = '';

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleNav() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleHelp() {
        this.dispatchEvent(new CustomEvent('help'));
    }
}