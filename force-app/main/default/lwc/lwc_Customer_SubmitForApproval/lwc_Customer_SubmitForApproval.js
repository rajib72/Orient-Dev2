import { LightningElement, api, track, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLockedFields from '@salesforce/apex/Ctrl_Customer_SubmitForApproval.getLockedFields';
import submitApprovalRequest from '@salesforce/apex/Ctrl_Customer_SubmitForApproval.submitApprovalRequest';

export default class Lwc_Customer_SubmitForApproval extends LightningElement {
    @api recordId;
    @track lockedFields = [];
    isLoading = true;

    // @wire(getLockedFields, { accountId: '$recordId' })
    // wiredFields({ error, data }) {
    //     if (data) {
    //         this.lockedFields = data.map(field => ({
    //             ...field,
    //             inputDisabled: true,
    //             rowClass: 'default-row' // Add default styling class
    //         }));
    //         this.isLoading = false;
    //     } else if (error) {
    //         this.showToast('Error', error.body ? error.body.message : error.message, 'error');
    //         this.isLoading = false;
    //     }
    // }

    @wire(getLockedFields, { accountId: '$recordId' })
    wiredFields({ error, data }) {
        if (data) {
            this.lockedFields = data.map(field => ({
                ...field,
                inputDisabled: true,
                rowClass: 'default-row' 
            }));
            this.isLoading = false;
        } else if (error) {
            // Show the error thrown by Apex and instantly close the modal
            this.showToast('Action Blocked', error.body ? error.body.message : error.message, 'error');
            this.closeAction(); 
        }
    }

    get hasFields() {
        return this.lockedFields && this.lockedFields.length > 0;
    }

    get isSubmitDisabled() {
        return !this.lockedFields.some(field => field.isSelected);
    }

    handleCheckboxChange(event) {
        const index = event.target.dataset.index;
        const isChecked = event.target.checked;
        
        this.lockedFields[index].isSelected = isChecked;
        this.lockedFields[index].inputDisabled = !isChecked;
        
        // Dynamically apply the highlight class if checked
        this.lockedFields[index].rowClass = isChecked ? 'selected-row' : 'default-row';
    }

    handleValueChange(event) {
        const index = event.target.dataset.index;
        this.lockedFields[index].newValue = event.target.value;
    }

    submitRequest() {
        this.isLoading = true;
        const payloadJson = JSON.stringify(this.lockedFields);

        submitApprovalRequest({ accountId: this.recordId, payloadJson: payloadJson })
            .then(result => {
                if (result === 'NO_CHANGES_SELECTED') {
                    this.showToast('Warning', 'Please select at least one field and provide a new value.', 'warning');
                } else {
                    this.showToast('Success', 'Approval Request Submitted Successfully.', 'success');
                    this.closeAction();
                }
            })
            .catch(error => {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}