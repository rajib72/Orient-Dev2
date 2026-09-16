import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import getLineItemsForProcessing from '@salesforce/apex/Ctrl_PushEstimateToBC.getLineItemsForProcessing';
import pushSingleLineItemToBC from '@salesforce/apex/Ctrl_PushEstimateToBC.pushSingleLineItemToBC';

export default class Lwc_PushEstimateToBC extends LightningElement {
    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (this._recordId) {
            this.fetchLineItems();
        }
    }

    @track lineItems = [];
    @track selectAll = false;
    isLoading = true;
    isProcessing = false;

    get hasResults() {
        return this.lineItems && this.lineItems.length > 0;
    }

    // Disable if loading, processing, no results, or NO items are actively selected
    get disableProcessButton() {
        const hasSelectedPendingItems = this.lineItems.some(item => item.isSelected && item.status === 'Pending');
        return this.isLoading || this.isProcessing || !this.hasResults || !hasSelectedPendingItems;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async fetchLineItems() {
        this.isLoading = true;
        this.selectAll = false;
        try {
            const items = await getLineItemsForProcessing({ orderId: this.recordId });

            this.lineItems = items.map(item => {
                let badgeTheme = 'slds-theme_warning'; 
                if (item.status === 'Synced' || item.status === 'Success') badgeTheme = 'slds-theme_success';
                else if (item.status === 'Validation Error') badgeTheme = 'slds-theme_error';

                const isPending = item.status === 'Pending';

                return {
                    ...item,
                    badgeClass: badgeTheme,
                    documentNo: item.documentNo || '---',
                    salesExecutiveCode: item.salesExecutiveCode || 'N/A',
                    salesExecutiveName: item.salesExecutiveName || 'N/A',
                    finalPrice: item.finalPrice != null ? item.finalPrice : 0,
                    isSelected: false,      // Default empty checkbox
                    isDisabled: !isPending  // Can only select pending items
                };
            });
        } catch (error) {
            console.error('Error fetching line items: ', error);
        } finally {
            this.isLoading = false;
        }
    }

    // ADDED
    handleRefresh() {
        this.fetchLineItems(); // Re-runs your existing server call
    }
    // ADDED
    
    handleRowSelection(event) {
        const itemId = event.target.dataset.id;
        const isChecked = event.target.checked;
        
        this.lineItems = this.lineItems.map(item => {
            if (item.lineItemId === itemId) {
                return { ...item, isSelected: isChecked };
            }
            return item;
        });
        this.updateSelectAllState();
    }

    handleSelectAll(event) {
        const isChecked = event.target.checked;
        this.selectAll = isChecked;
        
        this.lineItems = this.lineItems.map(item => {
            // Only toggle items that are eligible for selection
            if (!item.isDisabled) {
                return { ...item, isSelected: isChecked };
            }
            return item;
        });
    }

    updateSelectAllState() {
        const selectableItems = this.lineItems.filter(item => !item.isDisabled);
        if (selectableItems.length === 0) {
            this.selectAll = false;
        } else {
            this.selectAll = selectableItems.every(item => item.isSelected);
        }
    }

    async handleProcess() {
        this.isProcessing = true;

        try {
            for (let i = 0; i < this.lineItems.length; i++) {
                let currentItem = this.lineItems[i];

                // Check BOTH that it is 'Pending' AND user checked the box
                if (currentItem.isSelected && currentItem.isValid && currentItem.status === 'Pending') {
                    this.updateItemState(currentItem.lineItemId, 'Processing...', 'slds-theme_inverse', '', '---');

                    try {
                        const result = await pushSingleLineItemToBC({ lineItemId: currentItem.lineItemId });

                        if (result.isSuccess) {
                            this.updateItemState(currentItem.lineItemId, 'Success', 'slds-theme_success', '', result.documentNo);
                            // Disable checkbox and deselect after success
                            this.markItemProcessed(currentItem.lineItemId);
                        } else {
                            this.updateItemState(currentItem.lineItemId, 'API Error', 'slds-theme_error', result.errorMessage, '---');
                        }
                    } catch (error) {
                        const errorMsg = error.body ? error.body.message : error.message;
                        this.updateItemState(currentItem.lineItemId, 'System Error', 'slds-theme_error', errorMsg, '---');
                    }
                }
            }
            this.updateSelectAllState(); // Refresh Select All check post-processing
        } finally {
            this.isProcessing = false;
        }
    }

    updateItemState(id, status, badgeClass, errorMsg, docNo) {
        this.lineItems = this.lineItems.map(item => {
            if (item.lineItemId === id) {
                return { ...item, status: status, badgeClass: badgeClass, errorMessage: errorMsg, documentNo: docNo };
            }
            return item;
        });
    }

    markItemProcessed(id) {
        this.lineItems = this.lineItems.map(item => {
            if (item.lineItemId === id) {
                return { ...item, isSelected: false, isDisabled: true };
            }
            return item;
        });
    }
}