import { LightningElement, api, track, wire } from 'lwc';
import getAvailableWishlistItems
    from '@salesforce/apex/ShowroomWishlistNotOrderedController.getAvailableWishlistItems';
import markAsNotOrdered
    from '@salesforce/apex/ShowroomWishlistNotOrderedController.markAsNotOrdered';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';


export default class WishlistNotOrdered extends NavigationMixin(LightningElement) {

    @api recordId;

    @track wishlistItems = [];

    reasonOptions = [
        { label: 'Customer Deferred', value: 'Customer Deferred' },
        { label: 'Budget Issue', value: 'Budget Issue' },
        { label: 'Price Not Accepted', value: 'Price Not Accepted' },
        { label: 'Stock Not Available', value: 'Stock Not Available' },
        { label: 'Design Not Finalized', value: 'Design Not Finalized' },
        { label: 'Purchased Elsewhere', value: 'Purchased Elsewhere' },
        { label: 'Other', value: 'Other' }
    ];
    // ===== MODAL STATE =====
    showReasonModal = false;
    activeWishlistId;
    selectedReason;
    connectedCallback() {
        // Mobile app reuses component instance
        setTimeout(() => {
            if (this.wiredResult) {
                refreshApex(this.wiredResult);
            }
        }, 0);
    }


    get hasNoWishlistItems() {
        return !this.wishlistItems || this.wishlistItems.length === 0;
    }

    /* ================= LOAD DATA ================= */
    @wire(getAvailableWishlistItems, { showroomVisitId: '$recordId' })
    wiredWishlist(result) {
        this.wiredResult = result;

        const { data, error } = result;
        if (data) {
            this.wishlistItems = data.map(item => {
                const cleanStatus = item.status ? item.status.trim() : '';

                return {
                    ...item,
                    selected: false,
                    reason: '',
                    displayReason: 'Select Reason',

                    statusClass: cleanStatus
                        .toLowerCase()
                        .replace(/\s+/g, '-'),

                    statusClassName:
                        'status-badge ' +
                        cleanStatus.toLowerCase().replace(/\s+/g, '-'),


                    // LWC-safe disable flag
                    isDisabled: cleanStatus !== 'Available'
                };
            });
        } else if (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }



    /* ================= EVENTS ================= */
    handleCheckbox(event) {
        const id = event.target.dataset.id;
        const checked = event.target.checked;

        this.wishlistItems = this.wishlistItems.map(item =>
            item.id === id
                ? {
                    ...item,
                    selected: checked,
                    reason: checked ? item.reason : ''
                }
                : item
        );
    }


    handleRowReasonChange(event) {
        const id = event.target.dataset.id;
        const value = event.detail.value;

        this.wishlistItems = this.wishlistItems.map(item =>
            item.id === id ? { ...item, reason: value } : item
        );
    }

    handleSave() {
        // only rows where checkbox is checked
        const selectedItems = this.wishlistItems.filter(item => item.selected);

        if (!selectedItems.length) {
            this.showToast(
                'Error',
                'Please select at least one wishlist item',
                'error'
            );
            return;
        }

        // checkbox checked but reason missing → BLOCK SAVE
        const invalidRow = selectedItems.find(item => !item.reason);

        if (invalidRow) {
            this.showToast(
                'Error',
                'Please select a reason for all selected items',
                'error'
            );
            return;
        }

        // prepare payload ONLY for checked rows
        const reasonMap = {};
        selectedItems.forEach(item => {
            reasonMap[item.id] = item.reason;
        });

        markAsNotOrdered({ wishlistReasonMap: reasonMap })
            .then(async () => {
                this.showToast(
                    'Success',
                    'Wishlist items updated successfully',
                    'success'
                );

                // FORCE APEX REFRESH
                await refreshApex(this.wiredResult);


                // navigate back
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.recordId,
                        objectApiName: 'Showroom_Visit__c',
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                let message = 'Unknown error';

                if (error?.body?.message) {
                    message = error.body.message;
                } else if (Array.isArray(error?.body)) {
                    message = error.body.map(e => e.message).join(', ');
                } else if (error?.message) {
                    message = error.message;
                }

                this.showToast('Error', message, 'error');
            });
    }


    /* ================= UTIL ================= */
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
    // ===== MOBILE MODAL =====
    openReasonPopup(event) {
        this.activeWishlistId = event.currentTarget.dataset.id;
        const item = this.wishlistItems.find(i => i.id === this.activeWishlistId);
        this.selectedReason = item?.reason || '';
        this.showReasonModal = true;
    }

    handlePopupReasonChange(event) {
        const value = event.detail.value;

        this.wishlistItems = this.wishlistItems.map(item =>
            item.id === this.activeWishlistId
                ? {
                    ...item,
                    reason: value,
                    displayReason: value   // THIS WAS MISSING
                }
                : item
        );

        this.closeReasonPopup();
    }

    closeReasonPopup() {
        this.showReasonModal = false;
        this.activeWishlistId = null;
    }

}