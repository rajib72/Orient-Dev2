import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getAccountFieldOptions from '@salesforce/apex/BTLAccountFieldSelectorController.getAccountFieldOptions';
import getExistingCustomerFieldName from '@salesforce/apex/BTLAccountFieldSelectorController.getExistingCustomerFieldName';
import saveCustomerFieldName from '@salesforce/apex/BTLAccountFieldSelectorController.saveCustomerFieldName';

export default class BtlAccountFieldSelector extends LightningElement {
    @api recordId;

    isLoading = false;

    searchKey = '';
    accountFieldOptions = [];
    selectedAccountFieldApiName;

    get filteredAccountFieldOptions() {
        let filteredOptions = [];

        if (!this.searchKey) {
            filteredOptions = [...this.accountFieldOptions];
        } else {
            const searchText = this.searchKey.toLowerCase();

            filteredOptions = this.accountFieldOptions.filter(item => {
                const label = item.label ? item.label.toLowerCase() : '';
                const value = item.value ? item.value.toLowerCase() : '';
                const fieldType = item.fieldType ? item.fieldType.toLowerCase() : '';

                return (
                    label.includes(searchText) ||
                    value.includes(searchText) ||
                    fieldType.includes(searchText)
                );
            });
        }

        if (
            this.selectedAccountFieldApiName &&
            !filteredOptions.some(item => item.value === this.selectedAccountFieldApiName)
        ) {
            const selectedOption = this.accountFieldOptions.find(
                item => item.value === this.selectedAccountFieldApiName
            );

            if (selectedOption) {
                filteredOptions = [selectedOption, ...filteredOptions];
            }
        }

        return filteredOptions;
    }

    get filteredFieldCount() {
        return this.filteredAccountFieldOptions.length;
    }

    get showNoResult() {
        return this.searchKey && this.filteredAccountFieldOptions.length === 0;
    }

    @wire(getAccountFieldOptions)
    wiredAccountFields({ data, error }) {
        if (data) {
            this.accountFieldOptions = data.map(item => {
                return {
                    label: item.label,
                    value: item.value,
                    fieldType: item.fieldType
                };
            });
        } else if (error) {
            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        }
    }

    @wire(getExistingCustomerFieldName, { btlQuestionId: '$recordId' })
    wiredExistingValue({ data, error }) {
        if (data !== undefined) {
            this.selectedAccountFieldApiName = data;
        } else if (error) {
            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        }
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
    }

    handleAccountFieldChange(event) {
        this.selectedAccountFieldApiName = event.detail.value;
        this.saveSelectedField();
    }

    saveSelectedField() {
        if (!this.recordId) {
            this.showToast(
                'Error',
                'BTL Question record id is missing.',
                'error'
            );
            return;
        }

        if (!this.selectedAccountFieldApiName) {
            this.showToast(
                'Validation Error',
                'Please select an Account field.',
                'error'
            );
            return;
        }

        this.isLoading = true;

        saveCustomerFieldName({
            btlQuestionId: this.recordId,
            accountFieldApiName: this.selectedAccountFieldApiName
        })
            .then(() => {
                this.isLoading = false;

                this.showToast(
                    'Success',
                    'Account field API name saved successfully.',
                    'success'
                );
            })
            .catch(error => {
                this.isLoading = false;

                this.showToast(
                    'Error',
                    this.getErrorMessage(error),
                    'error'
                );
            });
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