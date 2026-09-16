import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

// Updated imports to use the new Apex controller name
import getSalesExecutives from '@salesforce/apex/Ctrl_ReassignSalesExecutive.getSalesExecutives';
import reassignAndLogActivity from '@salesforce/apex/Ctrl_ReassignSalesExecutive.reassignAndLogActivity';

export default class Lwc_ReassignSalesExecutive extends LightningElement {
    @api recordId;

    @track salesExecOptions = [];
    selectedSalesExecId;
    isLoading = true;
    isSaving = false;

    // Fetch the filtered Sales Executives
    @wire(getSalesExecutives)
    wiredExecs({ error, data }) {
        if (data) {
            this.salesExecOptions = data.map(exec => {
                return { label: exec.Name, value: exec.Id };
            });
            this.isLoading = false;
        } else if (error) {
            this.showToast('Error', 'Failed to load Sales Executives', 'error');
            this.isLoading = false;
        }
    }

    handleChange(event) {
        this.selectedSalesExecId = event.detail.value;
    }

    handleSave() {
        if (!this.selectedSalesExecId) {
            this.showToast('Error', 'Please select a Sales Person', 'error');
            return;
        }

        this.isSaving = true;

        reassignAndLogActivity({
            showroomVisitId: this.recordId,
            salesExecutiveId: this.selectedSalesExecId
        })
            .then(() => {
                this.showToast('Success', 'Sales Executive reassigned successfully.', 'success');

                // Refresh the record data on the page
                notifyRecordUpdateAvailable([{ recordId: this.recordId }]);

                // Close the quick action modal
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                let errorMessage = error.body ? error.body.message : error.message;
                this.showToast('Error', errorMessage, 'error');
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}