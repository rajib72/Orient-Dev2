import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh'; // Added native LWC refresh
import fetchPreEstimate from '@salesforce/apex/Ctrl_FetchPreEstimateBC.fetchPreEstimate';

export default class Lwc_FetchPreEstimateBC extends LightningElement {
    isLoading = false;
    _recordId;
    hasExecuted = false; 

    @api 
    set recordId(value) {
        this._recordId = value;
        if (value && !this.hasExecuted) {
            this.hasExecuted = true;
            this.isLoading = true;
            this.invokeApex();
        }
    }

    get recordId() {
        return this._recordId;
    }

    invokeApex() {
        fetchPreEstimate({ orderId: this.recordId })
            .then(result => {
                if (result === 'Success') {
                    this.showToast('Success', 'Pre-Estimate Data fetched successfully.', 'success');
                } else {
                    this.showToast('Error', result, 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
                // Close the modal
                this.dispatchEvent(new CloseActionScreenEvent());
                // Safely refresh the standard page view
                this.dispatchEvent(new RefreshEvent()); 
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}