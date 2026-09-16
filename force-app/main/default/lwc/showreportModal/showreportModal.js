import { LightningElement, api } from 'lwc';

export default class ShowreportModal extends LightningElement {
    @api showModal = false;
    @api title = '';
    @api size = 'large';

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
    
}