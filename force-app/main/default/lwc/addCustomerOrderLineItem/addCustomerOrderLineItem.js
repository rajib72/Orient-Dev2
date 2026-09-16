import { LightningElement, api, track, wire } from 'lwc';
import getAvailableWishlistItems from '@salesforce/apex/CustomerOrderLineItemController.getAvailableWishlistItems';
import saveSelectedWishlistItems from '@salesforce/apex/CustomerOrderLineItemController.saveSelectedWishlistItems';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { refreshApex } from '@salesforce/apex';
import { RefreshEvent } from 'lightning/refresh';
export default class AddCustomerOrderLineItem extends LightningElement {
    @api recordId;

    @track wishlistItems = [];
    @track selectedRowIds = [];

    isLoading = true;
    wiredWishlistResult;

    columns = [
        {
            label: 'Wishlist Item',
            fieldName: 'wishlistName',
            type: 'text'
        },
        {
            label: 'Barcode',
            fieldName: 'barcodeValue',
            type: 'text'
        },
        {
            label: 'Gross Wt.',
            fieldName: 'grWt',
            type: 'number'
        },
        {
            label: 'Net Wt.',
            fieldName: 'netWt',
            type: 'number'
        },
        {
            label: 'Diamond Wt.',
            fieldName: 'diaWt',
            type: 'number'
        },
        {
            label: 'Sales Executive',
            fieldName: 'salesExe',
            type: 'text'
        },
        {
            label: 'Product Price(Incl.GST)',
            fieldName: 'priceGST',
            type: 'currency'
        }

    ];

    @wire(getAvailableWishlistItems, { customerOrderId: '$recordId' })
    wiredWishlistItems(result) {
        this.wiredWishlistResult = result;
        this.isLoading = false;

        if (result.data) {
            this.wishlistItems = result.data;
        } else if (result.error) {
            this.wishlistItems = [];
            this.showToast('Error', this.getErrorMessage(result.error), 'error');
        }
    }
    get availableItemCount() {
        return this.wishlistItems ? this.wishlistItems.length : 0;
    }

    get hasData() {
        return this.wishlistItems && this.wishlistItems.length > 0;
    }

    get disableSave() {
        return this.isLoading || !this.selectedRowIds || this.selectedRowIds.length === 0;
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedRowIds = selectedRows.map(row => row.wishlistId);
    }

    handleCheckboxChange(event) {
        const wishlistId = event.target.dataset.id;
        const isChecked = event.target.checked;

        if (isChecked) {
            if (!this.selectedRowIds.includes(wishlistId)) {
                this.selectedRowIds = [...this.selectedRowIds, wishlistId];
            }
        } else {
            this.selectedRowIds = this.selectedRowIds.filter(id => id !== wishlistId);
        }
    }

    handleSave() {
        if (!this.selectedRowIds || this.selectedRowIds.length === 0) {
            this.showToast('Error', 'Please select at least one wishlist item.', 'error');
            return;
        }

        this.isLoading = true;

        saveSelectedWishlistItems({
            customerOrderId: this.recordId,
            wishlistItemIds: this.selectedRowIds
        })
            .then(result => {
                this.showToast('Success', result, 'success');

                return refreshApex(this.wiredWishlistResult);
            })
            .then(() => {
                this.dispatchEvent(new RefreshEvent());
                this.dispatchEvent(new CloseActionScreenEvent());
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
        let message = 'Something went wrong.';

        if (error && error.body && error.body.message) {
            message = error.body.message;
        } else if (error && error.message) {
            message = error.message;
        }

        return message;
    }
    handleRefresh() {
    this.isLoading = true;

    if (!this.wiredWishlistResult) {
        this.isLoading = false;
        this.showToast('Error', 'No data available to refresh.', 'error');
        return;
    }

    refreshApex(this.wiredWishlistResult)
        .then(() => {
            this.selectedRowIds = [];
        })
        .catch(error => {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
}
    

}