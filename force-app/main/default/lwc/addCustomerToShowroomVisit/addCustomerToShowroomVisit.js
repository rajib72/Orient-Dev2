import { LightningElement, api, track } from 'lwc';
import searchCustomersByPhone from '@salesforce/apex/ShowroomVisitAddCustomerController.searchCustomersByPhone';
import addCustomerToShowroomVisit from '@salesforce/apex/ShowroomVisitAddCustomerController.addCustomerToShowroomVisit';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

export default class AddCustomerToShowroomVisit extends LightningElement {
    @api recordId;

    @track phoneNumber = '';
    @track customerName = '';
    @track customerList = [];
    @track selectedCustomerIds = [];

    existingCustomerId = null;
    isExistingCustomer = false;
    isLoading = false;
    hasSearched = false;
    hideCustomerTable = false;

    searchDelayTimeout;

    columns = [
        {
            label: 'Customer Name',
            fieldName: 'customerName',
            type: 'text'
        },
        {
            label: 'Phone',
            fieldName: 'phone',
            type: 'text'
        }
    ];

    get showSearchHint() {
        return !this.phoneNumber || this.phoneNumber.trim().length < 3;
    }

    get showCustomerTable() {
        return (
            !this.hideCustomerTable &&
            this.customerList &&
            this.customerList.length > 0
        );
    }

    get showNoCustomerMessage() {
        return (
            this.hasSearched &&
            this.phoneNumber &&
            this.phoneNumber.trim().length >= 3 &&
            this.customerList.length === 0 &&
            !this.isExistingCustomer
        );
    }

    get disableAdd() {
        return (
            !this.phoneNumber ||
            this.phoneNumber.trim() === '' ||
            !this.customerName ||
            this.customerName.trim() === ''
        );
    }

    handlePhoneChange(event) {
        this.phoneNumber = event.target.value;

        this.customerName = '';
        this.existingCustomerId = null;
        this.isExistingCustomer = false;
        this.customerList = [];
        this.selectedCustomerIds = [];
        this.hasSearched = false;
        this.hideCustomerTable = false;

        window.clearTimeout(this.searchDelayTimeout);

        if (this.phoneNumber && this.phoneNumber.trim().length >= 3) {
            this.searchDelayTimeout = setTimeout(() => {
                this.searchCustomers();
            }, 500);
        }
    }

    searchCustomers() {
        this.isLoading = true;

        searchCustomersByPhone({
            phoneNumber: this.phoneNumber.trim()
        })
            .then(result => {
                this.hasSearched = true;
                this.customerList = result ? result : [];
                this.hideCustomerTable = false;
            })
            .catch(error => {
                this.customerList = [];
                this.showToast('Error', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCustomerSelection(event) {
        const selectedRows = event.detail.selectedRows;

        if (selectedRows && selectedRows.length > 0) {
            const selectedCustomer = selectedRows[0];

            this.existingCustomerId = selectedCustomer.customerId;
            this.customerName = selectedCustomer.customerName;
            this.phoneNumber = selectedCustomer.phone;
            this.isExistingCustomer = true;
            this.selectedCustomerIds = [selectedCustomer.customerId];

            // Hide search table after existing customer selection
            this.hideCustomerTable = true;
        } else {
            this.existingCustomerId = null;
            this.customerName = '';
            this.isExistingCustomer = false;
            this.selectedCustomerIds = [];
            this.hideCustomerTable = false;
        }
    }

    handleNameChange(event) {
        this.customerName = event.target.value;
    }

    handleAdd() {
        if (!this.phoneNumber || this.phoneNumber.trim() === '') {
            this.showToast('Error', 'Please enter customer phone number.', 'error');
            return;
        }

        if (!this.customerName || this.customerName.trim() === '') {
            this.showToast('Error', 'Please enter customer name.', 'error');
            return;
        }

        this.isLoading = true;

        addCustomerToShowroomVisit({
            showroomVisitId: this.recordId,
            phoneNumber: this.phoneNumber.trim(),
            customerName: this.customerName.trim(),
            existingCustomerId: this.existingCustomerId
        })
            .then(result => {
                this.showToast('Success', result, 'success');

                // Refresh LDS cache for current Showroom Visit record
                notifyRecordUpdateAvailable([
                    {
                        recordId: this.recordId
                    }
                ]);

                // Refresh standard Lightning record page
                this.dispatchEvent(new RefreshEvent());

                // Close quick action after refresh event
                setTimeout(() => {
                    this.dispatchEvent(new CloseActionScreenEvent());
                }, 300);
            })
            .catch(error => {
                this.showToast('Error', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    getErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Something went wrong.';
    }
}