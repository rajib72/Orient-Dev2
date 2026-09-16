import { LightningElement, api } from 'lwc';

export default class Modal extends LightningElement {
    @api showModal = false;
    @api title = '';
    

    @api open() {
        this.showModal = true;
    }

    @api close() {
        this.showModal = false;
    }

    closeModal() {
        this.close();
        this.dispatchEvent(new CustomEvent('close'));
    }

    
}