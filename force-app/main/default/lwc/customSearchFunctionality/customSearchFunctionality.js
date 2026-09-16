import { LightningElement, track } from 'lwc';
import searchAccountsByPhone from '@salesforce/apex/cSearch.searchAccountsByPhone';
import { NavigationMixin } from 'lightning/navigation';

export default class AccountPhoneSearch extends NavigationMixin(LightningElement) {

    searchKey = '';
    @track accountList = [];

    showNoRecordCard = false;
    showSearchTable = false;
    isModalOpen = false;
    showCreateModal = false;

    columns = [
        { label: 'Customer Name', fieldName: 'Name' },
        { label: 'Phone', fieldName: 'Phone', type: 'phone' },
        { label: 'Last Purchased Date', fieldName: 'Last_Purchased_Date__c', type: 'date' },
        { label: 'Last Visit Date', fieldName: 'Last_Visit_Date__c', type: 'date' },
        { label: 'Total Invoice Amount', fieldName: 'Total_Invoice_Amount__c', type: 'currency' },
        {
            type: 'button',
            typeAttributes: {
                label: 'View',
                name: 'View',
                variant: 'brand'
            }
        }
    ];

    // Allow only digits and max 10 digits
    restrictToNumbers(event) {
        let value = event.target.value || '';

        value = value.replace(/[^0-9]/g, '');

        if (value.length > 10) {
            value = value.substring(0, 10);
        }

        this.searchKey = value;
        event.target.value = value;
    }

    // Block alphabet and special character while typing
    allowOnlyNumbers(event) {
        const allowedKeys = [
            'Backspace',
            'Delete',
            'Tab',
            'Escape',
            'Enter',
            'ArrowLeft',
            'ArrowRight',
            'Home',
            'End'
        ];

        if (allowedKeys.includes(event.key)) {
            return;
        }

        // Allow Ctrl + A/C/V/X
        if (
            event.ctrlKey &&
            ['a', 'c', 'v', 'x'].includes(event.key.toLowerCase())
        ) {
            return;
        }

        if (!/^[0-9]$/.test(event.key)) {
            event.preventDefault();
        }
    }

    // Paste only numbers
    handlePaste(event) {
        event.preventDefault();

        const pastedValue = (event.clipboardData || window.clipboardData).getData('text');
        let numericValue = pastedValue.replace(/[^0-9]/g, '');

        if (numericValue.length > 10) {
            numericValue = numericValue.substring(0, 10);
        }

        this.searchKey = numericValue;
        event.target.value = numericValue;
    }

    // Search logic - same as your previous logic
    handleSearch(event) {
        this.searchKey = event.target.value;

        this.showSearchTable = false;
        this.showNoRecordCard = false;

        if (!this.searchKey || this.searchKey.length < 3) {
            this.accountList = [];
            return;
        }

        searchAccountsByPhone({ phoneKey: this.searchKey })
            .then(result => {
                this.accountList = result.map(acc => ({
                    ...acc,
                    CustomerName: acc.Name,
                    Phone: acc.Phone
                }));

                if (this.accountList.length > 0) {
                    this.showSearchTable = true;
                } else {
                    this.showNoRecordCard = true;
                }
            })
            .catch(error => {
                console.error(error);
                this.accountList = [];
                this.showSearchTable = false;
                this.showNoRecordCard = true;
            });
    }

    handleRowAction(event) {
        const row = event.detail.row;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: row.Id,
                objectApiName: 'Account',
                actionName: 'view'
            }
        });
    }

    handleNoCustomerAction() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Account',
                actionName: 'new'
            }
        });
    }

    openCreateModal() {
        this.showCreateModal = true;
    }

    closeCreateModal() {
        this.showCreateModal = false;
    }
}