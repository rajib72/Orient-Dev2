import { LightningElement } from 'lwc';

export default class OpenFormButton extends LightningElement {

    showForm = false;

    toggleForm() {
        this.showForm = !this.showForm; // Toggle open/close
    }

    get buttonLabel() {
        return this.showForm ? 'Close Form' : 'Open Customer Enrollment Form';
    }
}