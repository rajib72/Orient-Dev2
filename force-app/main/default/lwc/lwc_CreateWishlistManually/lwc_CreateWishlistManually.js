import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createWishlistItem from '@salesforce/apex/Ctrl_CreateWishlistManually.createWishlistItem';

export default class Lwc_CreateWishlistManually extends NavigationMixin(LightningElement) {
    @api recordId; // Automatically inherits the Showroom_Visit__c ID
    @track barcodeValue = '';
    @track isLoading = false;

    // Capture user input
    handleInputChange(event) {
        this.barcodeValue = event.target.value;
    }

    // Disable button if input is empty
    get isButtonDisabled() {
        return !this.barcodeValue || this.barcodeValue.trim().length === 0;
    }

    // Cancel and return to the parent record
    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Showroom_Visit__c', // Redirects back to the parent visit
                actionName: 'view'
            }
        });
    }

    // Execute Apex & Redirect
    handleCreate() {
        if (this.isButtonDisabled) return;

        this.isLoading = true;

        createWishlistItem({ 
            showroomVisitId: this.recordId, 
            barcodeValue: this.barcodeValue.trim() 
        })
        .then(newRecordId => {
            this.isLoading = false;
            this.showToast('Success', 'Wishlist item created.', 'success');
            this.navigateToRecord(newRecordId);
        })
        .catch(error => {
            this.isLoading = false;
            let errorMessage = error.body ? error.body.message : error.message;
            this.showToast('Error', errorMessage, 'error');
        });
    }

    // Replicates the "Redirect to Wishlist item" Flow Screen
    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Wishlist_Item__c',
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}