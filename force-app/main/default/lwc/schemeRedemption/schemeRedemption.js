import { LightningElement } from 'lwc';

export default class SchemeRedemption extends LightningElement {
    handleCancel() {
        // Fire event to parent to close modal
        this.dispatchEvent(
        new CustomEvent('close', {
            bubbles: true,
            composed: true
        })
    );
    }

}