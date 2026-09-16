import { LightningElement, api, wire, track } from 'lwc';
import getLineItems from '@salesforce/apex/ctrl_CustomerOrderLineItemRelatedList.getLineItems';
import { refreshApex } from '@salesforce/apex';

export default class Lwc_customerOrderLineItemRelatedList extends LightningElement {
    @api recordId;

    @track lineItems = [];
    isLoading = true;
    wiredResult;

    @wire(getLineItems, { customerOrderId: '$recordId' })
    wiredLineItems(result) {
        this.wiredResult = result;

        if (result.data) {
            this.lineItems = result.data.map((item) => {
                const statusApiValue = item.Line_Item_Status_On_Salesforce__c;
                const statusLabel = this.getStatusLabel(statusApiValue);

                return {
                    ...item,
                    recordUrl: '/' + item.Id,
                    statusLabel: statusLabel,
                    statusClass: this.getStatusClass(statusApiValue),
                    statusDotClass: this.getStatusDotClass(statusApiValue)
                };
            });

            this.isLoading = false;
        } else if (result.error) {
            console.error('Error fetching line items:', result.error);
            this.lineItems = [];
            this.isLoading = false;
        }
    }

    get recordCount() {
        return this.lineItems ? this.lineItems.length : 0;
    }

    get hasRecords() {
        return this.lineItems && this.lineItems.length > 0;
    }

    getStatusLabel(status) {
        switch (status) {
            case 'Draft':
                return 'Ready For Invoice';

            case 'Back To Available Wishlist Item':
                return 'Removed From CRM';

            case 'Sent To ERP - PRE':
                return 'Sent To ERP - PRE';

            case 'Finalize In Pre':
                return 'Finalized In Pre';

            case 'Finalize In Post':
                return 'Finalized In Post';

            case 'Removed':
                return 'Removed From ERP';

            case 'Newly Added':
                return 'Newly Added';

            default:
                return status;
        }
    }

    getStatusClass(status) {
        const baseClass = 'status-pill ';

        switch (status) {
            case 'Draft':
                return baseClass + 'status-ready';

            case 'Back To Available Wishlist Item':
                return baseClass + 'status-removed';

            case 'Sent To ERP - PRE':
                return baseClass + 'status-sent-pre';

            case 'Finalize In Pre':
                return baseClass + 'status-finalize-pre';

            case 'Finalize In Post':
                return baseClass + 'status-finalize-post';

            case 'Removed':
                return baseClass + 'status-removed-erp';

            case 'Newly Added':
                return baseClass + 'status-new';

            default:
                return baseClass + 'status-default';
        }
    }

    getStatusDotClass(status) {
        const baseClass = 'status-dot ';

        switch (status) {
            case 'Draft':
                return baseClass + 'dot-ready';

            case 'Back To Available Wishlist Item':
            case 'Removed':
                return baseClass + 'dot-removed';

            case 'Sent To ERP - PRE':
                return baseClass + 'dot-sent-pre';

            case 'Finalize In Pre':
                return baseClass + 'dot-finalize-pre';

            case 'Finalize In Post':
                return baseClass + 'dot-finalize-post';

            case 'Newly Added':
                return baseClass + 'dot-new';

            default:
                return baseClass + 'dot-default';
        }
    }

    handleRefresh() {
        this.isLoading = true;

        refreshApex(this.wiredResult)
            .finally(() => {
                this.isLoading = false;
            });
    }
}