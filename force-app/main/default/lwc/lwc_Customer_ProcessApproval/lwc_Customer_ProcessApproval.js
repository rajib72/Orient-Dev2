import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

import getPendingApprovals from '@salesforce/apex/Ctrl_Customer_ProcessApproval.getPendingApprovals';
import processApproval from '@salesforce/apex/Ctrl_Customer_ProcessApproval.processApproval';
import pushApprovedChangesToBC from '@salesforce/apex/Ctrl_Customer_ProcessApproval.pushApprovedChangesToBC';

export default class Lwc_Customer_ProcessApproval extends NavigationMixin(LightningElement) {
    @api recordId; 
    @track pendingFields = [];
    @track isAlreadyProcessed = false;
    @track currentStatus = '';
    isLoading = true;

    @wire(getPendingApprovals, { trackingId: '$recordId' })
    wiredApprovals({ error, data }) {
        if (data) {
            // Check if a decision has already been made
            if (data.status === 'Approved' || data.status === 'Rejected') {
                this.isAlreadyProcessed = true;
                this.currentStatus = data.status;
                this.isLoading = false;
            } else {
                this.pendingFields = data.fields.map(field => ({
                    ...field,
                    rowClass: field.isApproved ? 'approved-row' : 'default-row'
                }));
                this.isLoading = false;
            }
        } else if (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            this.isLoading = false;
        }
    }

    get hasFields() {
        return this.pendingFields && this.pendingFields.length > 0;
    }

    get isApproveDisabled() {
        return !this.pendingFields.some(field => field.isApproved);
    }

    handleCheckboxChange(event) {
        const index = event.target.dataset.index;
        const isChecked = event.target.checked;
        
        this.pendingFields[index].isApproved = isChecked;
        this.pendingFields[index].rowClass = isChecked ? 'approved-row' : 'default-row';
    }

    handleReject() {
        if(confirm('Are you sure you want to completely reject this request?')) {
            this.isLoading = true;
            processApproval({ trackingId: this.recordId, approvedAccountFields: [], action: 'Reject' })
                .then((accountId) => {
                    this.showToast('Rejected', 'The request has been rejected.', 'info');
                    this.navigateToAccount(accountId);
                })
                .catch(error => {
                    this.showToast('Error', error.body ? error.body.message : error.message, 'error');
                    this.isLoading = false;
                });
        }
    }

    handleApprove() {
        this.isLoading = true;
        
        const approvedFields = this.pendingFields
            .filter(f => f.isApproved)
            .map(f => f.accountFieldApiName);

        let savedAccountId;

        processApproval({ trackingId: this.recordId, approvedAccountFields: approvedFields, action: 'Approve' })
            .then(accountId => {
                if (accountId) {
                    savedAccountId = accountId;
                    this.showToast('Salesforce Updated', 'Values approved and saved. Pushing to Business Central...', 'success');
                    return pushApprovedChangesToBC({ accountId: accountId });
                }
            })
            .then(bcResult => {
                if (bcResult && bcResult.success) {
                    this.showToast('Integration Success', 'Changes synced to Business Central successfully!', 'success');
                } else if (bcResult) {
                    this.showToast('Integration Error', 'Salesforce updated, but BC sync failed: ' + bcResult.message, 'error');
                }

                getRecordNotifyChange([{recordId: savedAccountId}]);
                this.navigateToAccount(savedAccountId);
            })
            .catch(error => {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
                this.isLoading = false;
            });
    }

    navigateToAccount(accountId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: accountId,
                objectApiName: 'Account',
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}