import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { refreshApex } from '@salesforce/apex';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getEstimationLineItems from '@salesforce/apex/EstimationLineItemHelper.getEstimationLineItems';
import removeLineItems from '@salesforce/apex/EstimationLineItemHelper.removeLineItems';

const COLUMNS = [
    { label: 'SKU', fieldName: 'Sku', type: 'text' },
    { label: 'Gross Weight', fieldName: 'GrossWeight', type: 'number', typeAttributes: { minimumFractionDigits: 3 } },
    { label: 'Net Weight', fieldName: 'NetWeight', type: 'number', typeAttributes: { minimumFractionDigits: 3 } },
    { label: 'Diamond Wt.', fieldName: 'DiamondWt', type: 'number', typeAttributes: { minimumFractionDigits: 3 } },
    { label: 'Stone Wt.', fieldName: 'StoneWt', type: 'number', typeAttributes: { minimumFractionDigits: 3 } },
    //{ label: 'Product Price (Incl. GST)', fieldName: 'ProductPrice', type: 'currency' },
    { label: 'Product Price (Incl. GST)', fieldName: 'ProductPrice', type: 'text' },
    { label: 'Sales Executive', fieldName: 'SalesExecutive', type: 'text' },
    { label: 'Estimation Line Item No', fieldName: 'Name', type: 'text' }
];

export default class RemoveEstimationLineItems extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    @track data = [];
    selectedRows = [];
    isProcessing = false;
    wiredResult;

    // Getter to dynamically update the red badge count
    get recordCount() {
        return this.data ? this.data.length : 0;
    }

    get isRemoveDisabled() {
        return this.selectedRows.length === 0;
    }

    @wire(getEstimationLineItems, { estimationId: '$recordId' })
    wiredLineItems(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            console.log('Raw Data from Apex:', JSON.parse(JSON.stringify(data)));
            this.data = data.map(row => {
                return {
                    Id: row.Id,
                    Name: row.Name,
                    Sku: row.Barcode_Value__c,
                    GrossWeight: row.Wishlist_Item__r?.Gross_Weight__c,
                    NetWeight: row.Wishlist_Item__r?.Net_Wt__c,
                    DiamondWt: row.Wishlist_Item__r?.Diamond_Wt__c,
                    StoneWt: row.Wishlist_Item__r?.Stone_Wt__c,
                    ProductPrice: row.Wishlist_Item__r?.Total_Price_Including_GST__c,

                    SalesExecutive: row.Wishlist_Item__r?.Active_Sales_Executive_Details__c
                };
            });
        } else if (error) {
            this.showToast('Error', 'Failed to load line items.', 'error');
        }
    }

    handleRowSelection(event) {
        const selectedRecords = event.detail.selectedRows;
        this.selectedRows = selectedRecords.map(record => record.Id);
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    //add handle refresh 
    async handleRefresh() {
        this.isProcessing = true;

        try {
            if (!this.wiredResult) {
                this.showToast('Error', 'No data available to refresh.', 'error');
                return;
            }

            this.selectedRows = [];

            await refreshApex(this.wiredResult);

            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);

        } catch (error) {
            this.showToast(
                'Error',
                error.body?.message || error.message || 'An error occurred while refreshing records.',
                'error'
            );
        } finally {
            this.isProcessing = false;
        }
    }

    async handleRemove() {
        if (this.selectedRows.length === 0) return;

        this.isProcessing = true;
        try {
            await removeLineItems({ lineItemIds: this.selectedRows });

            this.showToast('Success', 'Selected Estimation Line Items have been removed.', 'success');

            await refreshApex(this.wiredResult);
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);

            this.closeAction();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'An error occurred while removing records.', 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}