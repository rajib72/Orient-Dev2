import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getShowroomVisit from '@salesforce/apex/EstimationCreationController.getShowroomVisit';
import getWishlistItems from '@salesforce/apex/EstimationCreationController.getWishlistItems';
import createOrder from '@salesforce/apex/EstimationCreationController.createOrder';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
// import CONTACT_OBJECT from '@salesforce/schema/Contact';
// import RELATION_FIELD from '@salesforce/schema/Contact.Relation__c';
import RELATIONSHIP_OBJECT from '@salesforce/schema/Relationship__c';
import RELATION_FIELD from '@salesforce/schema/Relationship__c.Relationship_Type__c';
import { NavigationMixin } from 'lightning/navigation';
import CUSTOMER_ORDER_OBJECT from '@salesforce/schema/Customer_Order__c';
import BUYING_FOR_FIELD from '@salesforce/schema/Customer_Order__c.Buying_For__c';
//import getCustomerByPhone from '@salesforce/apex/ShowroomOrderController.getCustomerByPhone';
import searchCustomersByPhone from '@salesforce/apex/EstimationCreationController.searchCustomersByPhone';

export default class EstimationCreationLWC extends NavigationMixin(LightningElement) {

    @api recordId;

    @track showroomVisit;
    @track wishlistItems = [];
    @track selectedWishlistIds = [];

    customerName = '';
    phone = '';
    relation = '';
    billingCustomerName = '';
    billingCustomerPhone = '';

    step = 1;
    dataLoaded = false;
    useAlternateCustomer = false;

    @track relationOptions = [];

    buyingFor = 'Self';
    buyingForName = '';
    buyingForPhone = '';
    @track buyingForOptions = [];
    wishlistWireResult;

    // Advance
    payAdvance = false;
    advanceAmount;
    pan = '';
    gst = '';
    stateCode = '';
    stateCodeMessage = '';

    billingCustomerId = null;
    billingStateCode = '';
    sameAddressAsPrimary = false;
    @track billingCustomerSuggestions = [];
    showBillingSuggestions = false;

    gender = '';
    originalGender = '';
    isRelationDisabled = false;
    visitWireResult;//added

    // NEW ADDED: Buying For phone search suggestion variables
    @track buyingForCustomerSuggestions = [];
    showBuyingForSuggestions = false;

    genderOptions = [
        { label: 'Male', value: 'Male' },
        { label: 'Female', value: 'Female' },
        { label: 'Other', value: 'Other' },
        { label: 'Prefer not to say', value: 'Prefer not to say' }
    ];

    /* ================= GETTERS ================= */
    get isStep1() {
        return this.step === 1;
    }

    get isStep2() {
        return this.step === 2;
    }

    get isStep3() {
        return this.step === 3;
    }

    get selectedWishlistItems() {
        return this.wishlistItems.filter(
            item => this.selectedWishlistIds.includes(item.id)
        );
    }

    get showBuyingForSection() {
        return this.buyingFor !== 'Self' && this.buyingFor !== 'Other';
    }

    get buyingForNameLabel() {
        return `${this.buyingFor} Name`;
    }

    get buyingForPhoneLabel() {
        return `${this.buyingFor} Phone`;
    }

    get isBuyingForDisabled() {
        return this.useAlternateCustomer;
    }

    get showAdvanceSection() {
        return this.payAdvance;
    }

    get hasInvalidSelection() {
        return this.wishlistItems.some(
            item =>
                this.selectedWishlistIds.includes(item.id) &&
                item.status !== 'Available'
        );
    }

    get isGenderOtherOrPreferNot() {
        return this.gender === 'Other' || this.gender === 'Prefer not to say';
    }

    get isGenderBlank() {
        return !this.originalGender;
    }

    advanceAgainstOptions = [
        { label: 'Order', value: 'Order' }
    ];

    /* ================= PICKLIST ================= */
  @wire(getObjectInfo, { objectApiName: RELATIONSHIP_OBJECT })
relationshipObjectInfo;

@wire(getPicklistValues, {
    recordTypeId: '$relationshipObjectInfo.data.defaultRecordTypeId',
    fieldApiName: RELATION_FIELD
})
wiredRelationPicklist({ data, error }) {
    if (data) {
        this.relationOptions = data.values.map(v => ({
            label: v.label,
            value: v.value
        }));
    } else if (error) {
        this.showError(error);
    }
}
    @wire(getObjectInfo, { objectApiName: CUSTOMER_ORDER_OBJECT })
    orderObjectInfo;

    get orderRecordTypeId() {
        return this.orderObjectInfo?.data?.defaultRecordTypeId || null;
    }

    @wire(getPicklistValues, {
        recordTypeId: '$orderRecordTypeId',
        fieldApiName: BUYING_FOR_FIELD
    })
    wiredBuyingFor({ data, error }) {
        if (data) {
            this.buyingForOptions = data.values.map(v => ({
                label: v.label,
                value: v.value
            }));
        } else if (error) {
            this.showError(error);
        }
    }

    /* ================= DATA ================= */
    // @wire(getShowroomVisit, { showroomVisitId: '$recordId' })
    // wiredVisit({ data, error }) {
    //     if (data) {
    //         this.showroomVisit = data;
    //         this.customerName = data.CUSTOMERlookup__r?.Name || '';
    //         this.phone = data.Customer_Phone__c || '';
    //         this.gender = data.CUSTOMERlookup__r?.Gender__c || '';
    //         this.originalGender = this.gender;
    //         this.pan = data.CUSTOMERlookup__r?.PAN__c || '';
    //         this.gst = data.CUSTOMERlookup__r?.GST__c || '';
    //         this.stateCode = data.CUSTOMERlookup__r?.StateCode__c || '';

    //         this.stateCodeMessage = this.stateCode
    //             ? ''
    //             : 'Kindly update State Code from Customer Detail page.';

    //         this.dataLoaded = true;
    //     } else if (error) {
    //         this.showError(error);
    //     }
    // }

    // add this wired method for refresh method

    @wire(getShowroomVisit, { showroomVisitId: '$recordId' })
wiredVisit(result) {
    this.visitWireResult = result;

    const { data, error } = result;

    if (data) {
        this.showroomVisit = data;
        this.customerName = data.CUSTOMERlookup__r?.Name || '';
        this.phone = data.Customer_Phone__c || '';
        this.gender = data.CUSTOMERlookup__r?.Gender__c || '';
        this.originalGender = this.gender;
        this.pan = data.CUSTOMERlookup__r?.PAN__c || '';
        this.gst = data.CUSTOMERlookup__r?.GST__c || '';
        this.stateCode = data.CUSTOMERlookup__r?.StateCode__c || '';

        this.stateCodeMessage = this.stateCode
            ? ''
            : 'Kindly update State Code from Customer Detail page.';

        this.dataLoaded = true;
    } else if (error) {
        this.showError(error);
    }
}

    @wire(getWishlistItems, { showroomVisitId: '$recordId' })
    wiredWishlist(result) {
        this.wishlistWireResult = result;

        if (result.data) {
            this.wishlistItems = result.data.map(item => {
                const cleanStatus = item.status ? item.status.trim() : '';
                const statusClass = cleanStatus
                    ? cleanStatus.replace(/\s+/g, '-').toLowerCase()
                    : 'unknown';

                return {
                    ...item,
                    grossWeight: this.formatThreeDecimal(item.grossWeight),
                    diamondWt: this.formatThreeDecimal(item.diamondWt),
                    stoneWt: this.formatThreeDecimal(item.stoneWt),
                    netWeight: this.formatThreeDecimal(item.netWeight),
                    productPrice: this.formatTwoDecimal(item.productPrice),

                    isSelected: this.selectedWishlistIds.includes(item.id),
                    isDisabled: ['Order Placed', 'Cancelled', 'Returned'].includes(cleanStatus),
                    badgeClass: `status-badge ${statusClass}`,

                    isExpanded: false,
                    expandIcon: 'utility:chevronright',

                    tagPriceDetails: (item.tagPriceDetails || []).map((row, index) => ({
                        ...row,
                        key: `TPD-${item.id}-${index}`,
                        quantity: this.formatThreeDecimal(row.quantity),
                        rate: this.formatTwoDecimal(row.rate),
                        amount: this.formatTwoDecimal(row.amount)
                    })),

                    tagPriceScms: (item.tagPriceScms || []).map((row, index) => ({
                        ...row,
                        key: `TPS-${item.id}-${index}`,
                        quantity: this.formatThreeDecimal(row.quantity),
                        rate: this.formatTwoDecimal(row.rate),
                        amount: this.formatTwoDecimal(row.amount)
                    })),

                    hasTagPriceDetails: item.tagPriceDetails && item.tagPriceDetails.length > 0,
                    hasTagPriceScms: item.tagPriceScms && item.tagPriceScms.length > 0
                };
            });
        } else if (result.error) {
            this.showError(result.error);
        }
    }

    /* ================= FORMATTERS ================= */
    formatThreeDecimal(value) {
        if (value === null || value === undefined || value === '') {
            return '0.000';
        }
        return Number(value).toFixed(3);
    }

    formatTwoDecimal(value) {
        if (value === null || value === undefined || value === '') {
            return '0.00';
        }
        return Number(value).toFixed(2);
    }

    /* ================= EVENTS ================= */
    toggleWishlistRow(event) {
        const id = event.currentTarget.dataset.id;

        this.wishlistItems = this.wishlistItems.map(item => {
            if (item.id === id) {
                const expanded = !item.isExpanded;
                return {
                    ...item,
                    isExpanded: expanded,
                    expandIcon: expanded ? 'utility:chevrondown' : 'utility:chevronright'
                };
            }
            return item;
        });
    }

    handleBuyingForChange(event) {
        this.buyingFor = event.target.value;
        this.buyingForName = '';
        this.buyingForPhone = '';
        this.buyingForCustomerSuggestions = [];
        this.showBuyingForSuggestions = false;
    }

    handleBuyingForName(event) {
        this.buyingForName = event.target.value;
    }

    // NEW UPDATED: Buying For phone search logic
    handleBuyingForPhone(event) {
        let value = event.target.value || '';
        value = value.replace(/\D/g, '').slice(0, 15);

        this.buyingForPhone = value;
        event.target.value = value;

        this.buyingForCustomerSuggestions = [];
        this.showBuyingForSuggestions = false;

        if (!value) {
            return;
        }

        searchCustomersByPhone({ phoneKey: value })
            .then(result => {
                this.buyingForCustomerSuggestions = result || [];
                this.showBuyingForSuggestions = this.buyingForCustomerSuggestions.length > 0;
            })
            .catch(error => {
                this.showError(error);
            });
    }
    // add refresh method added 5/06/2026

    async handleRefresh() {
    try {
        this.dataLoaded = false;

        await Promise.all([
            refreshApex(this.visitWireResult),
            refreshApex(this.wishlistWireResult)
        ]);

        this.toast('Success', 'Page refreshed successfully', 'success');
    } catch (error) {
        this.showError(error);
    } finally {
        this.dataLoaded = true;
    }
}

    // NEW ADDED: Select existing Buying For customer
    handleBuyingForCustomerSelect(event) {
        const selectedId = event.currentTarget.dataset.id;

        const selectedCustomer = this.buyingForCustomerSuggestions.find(
            item => item.id === selectedId
        );

        if (!selectedCustomer) {
            return;
        }

        this.buyingForName = selectedCustomer.name;
        this.buyingForPhone = selectedCustomer.phone;

        this.buyingForCustomerSuggestions = [];
        this.showBuyingForSuggestions = false;
    }

    handleCheckbox(event) {
        const id = event.target.dataset.id;
        const checked = event.target.checked;

        if (checked) {
            if (!this.selectedWishlistIds.includes(id)) {
                this.selectedWishlistIds = [...this.selectedWishlistIds, id];
            }
        } else {
            this.selectedWishlistIds = this.selectedWishlistIds.filter(x => x !== id);
        }

        this.wishlistItems = this.wishlistItems.map(item => {
            if (item.id === id) {
                return { ...item, isSelected: checked };
            }
            return item;
        });
    }

    handleGenderChange(event) {
        this.gender = event.target.value;

        if (this.useAlternateCustomer && this.isGenderOtherOrPreferNot) {
            this.relation = 'Other';
            this.isRelationDisabled = true;
        } else {
            this.isRelationDisabled = false;
        }
    }

    handleAlternateCustomerToggle(event) {
        this.useAlternateCustomer = event.target.checked;

        if (this.useAlternateCustomer) {
            if (!this.gender) {
                this.toast(
                    'Error',
                    'Gender is mandatory for primary customer before creating order with another customer.',
                    'error'
                );

                this.useAlternateCustomer = false;
                event.target.checked = false;
                return;
            }

            this.buyingFor = 'Other';
            this.buyingForName = '';
            this.buyingForPhone = '';
            this.buyingForCustomerSuggestions = [];
            this.showBuyingForSuggestions = false;

            if (this.isGenderOtherOrPreferNot) {
                this.relation = 'Other';
                this.isRelationDisabled = true;
            } else {
                this.isRelationDisabled = false;
            }
        } else {
            this.buyingFor = 'Self';
            this.buyingForName = '';
            this.buyingForPhone = '';
            this.buyingForCustomerSuggestions = [];
            this.showBuyingForSuggestions = false;

            this.relation = '';
            this.isRelationDisabled = false;
        }
    }

    handleBillingName(event) {
        this.billingCustomerName = event.target.value;
    }

    handleBillingPhone(event) {
        let value = event.target.value || '';
        value = value.replace(/\D/g, '').slice(0, 15);

        this.billingCustomerPhone = value;
        event.target.value = value;

        this.billingCustomerId = null;
        this.billingCustomerName = '';
        this.billingStateCode = '';
        this.billingCustomerSuggestions = [];
        this.showBillingSuggestions = false;

        if (!value) {
            return;
        }

        searchCustomersByPhone({ phoneKey: value })
            .then(result => {
                this.billingCustomerSuggestions = result || [];
                this.showBillingSuggestions = this.billingCustomerSuggestions.length > 0;
            })
            .catch(error => {
                this.showError(error);
            });
    }

    handleBillingCustomerSelect(event) {
        const selectedId = event.currentTarget.dataset.id;

        const selectedCustomer = this.billingCustomerSuggestions.find(
            item => item.id === selectedId
        );

        if (!selectedCustomer) {
            return;
        }

        this.billingCustomerId = selectedCustomer.id;
        this.billingCustomerName = selectedCustomer.name;
        this.billingCustomerPhone = selectedCustomer.phone;
        this.billingStateCode = selectedCustomer.stateCode || '';

        this.billingCustomerSuggestions = [];
        this.showBillingSuggestions = false;
    }

    handleSameAddressChange(event) {
        this.sameAddressAsPrimary = event.target.checked;

        if (this.sameAddressAsPrimary) {
            this.billingStateCode = this.stateCode;
        } else {
            this.billingStateCode = '';
        }
    }

    handleRelation(event) {
        this.relation = event.target.value;
    }

    goStep1() {
        this.step = 1;
    }

    goStep2() {
        this.step = 2;

        this.wishlistItems = this.wishlistItems.map(item => ({
            ...item,
            isSelected: this.selectedWishlistIds.includes(item.id),
            isExpanded: false,
            expandIcon: 'utility:chevronright'
        }));
    }

    goStep3() {
        if (!this.selectedWishlistIds.length) {
            this.toast('Error', 'Select at least one wishlist item', 'error');
            return;
        }

        if (this.hasInvalidSelection) {
            this.toast(
                'Error',
                'One or more selected wishlist items are already ordered or unavailable.',
                'error'
            );
            return;
        }

        this.step = 3;

        this.wishlistItems = this.wishlistItems.map(item => ({
            ...item,
            isExpanded: false,
            expandIcon: 'utility:chevronright'
        }));
    }

    handleAdvanceToggle(event) {
        this.payAdvance = event.target.checked;
        if (!this.payAdvance) {
            this.advanceAmount = null;
        }
    }

    handleAdvanceAmount(event) {
        let value = Number(event.target.value);

        if (value <= 0) {
            this.toast(
                'Error',
                'Advance amount must be greater than 0',
                'error'
            );
            event.target.value = null;
            this.advanceAmount = null;
            return;
        }

        this.advanceAmount = value;
    }

    /* ================= CREATE ORDER ================= */
    handleCreateOrder() {
        if (!this.recordId) {
            this.toast(
                'Error',
                'Showroom Visit context not found. Please refresh the page.',
                'error'
            );
            return;
        }

        if (this.useAlternateCustomer && !this.gender) {
            this.toast(
                'Error',
                'Please select Gender before creating estimation.',
                'error'
            );
            return;
        }

        if (this.useAlternateCustomer) {
            const phoneRegex = /^[0-9]{1,15}$/;
            if (!phoneRegex.test(this.billingCustomerPhone)) {
                this.toast(
                    'Error',
                    'Billing phone must contain only digits (max 15)',
                    'error'
                );
                return;
            }
        }

        if (this.showBuyingForSection) {
            const phoneRegex = /^[0-9]{1,15}$/;

            if (!this.buyingForName || !this.buyingForPhone) {
                this.toast(
                    'Error',
                    `${this.buyingFor} Name and Phone are mandatory`,
                    'error'
                );
                return;
            }

            if (!phoneRegex.test(this.buyingForPhone)) {
                this.toast(
                    'Error',
                    `${this.buyingFor} phone must contain only digits (max 15)`,
                    'error'
                );
                return;
            }
        }

        if (this.payAdvance) {
            if (!this.advanceAmount || this.advanceAmount <= 0) {
                this.toast(
                    'Error',
                    'Please enter a valid advance amount',
                    'error'
                );
                return;
            }
        }

        if (
            this.useAlternateCustomer &&
            (!this.billingCustomerName || !this.billingCustomerPhone || !this.relation)
        ) {
            this.toast(
                'Error',
                'Billing Customer Name, Phone and Relation are mandatory',
                'error'
            );
            return;
        }

        console.log(
            'Wishlist IDs:',
            JSON.stringify(this.selectedWishlistIds),
            'Length:',
            this.selectedWishlistIds?.length
        );
        console.log('recordId:', this.recordId);

        createOrder({
            showroomVisitId: this.recordId,
            useAlternateCustomer: this.useAlternateCustomer,
            billingCustomerName: this.useAlternateCustomer ? this.billingCustomerName : null,
            billingCustomerPhone: this.useAlternateCustomer ? this.billingCustomerPhone : null,
            relation: this.useAlternateCustomer ? this.relation : null,
            wishlistItemIds: this.selectedWishlistIds,
            buyingFor: this.buyingFor,
            buyingForName: this.buyingForName,
            buyingForPhone: this.buyingForPhone,
            payAdvance: this.payAdvance,
            advanceAmount: this.payAdvance ? this.advanceAmount : null,
            sameAddressAsPrimary: this.useAlternateCustomer ? this.sameAddressAsPrimary : false,
            customerGender: this.isGenderBlank ? this.gender : null,
            existingBillingCustomerId: this.useAlternateCustomer
                ? this.billingCustomerId
                : null
        })
            .then(orderId => {
                this.toast('Success', 'Order created successfully', 'success');

                refreshApex(this.wishlistWireResult);

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: orderId,
                        objectApiName: 'Customer_Order__c',
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                this.showError(error);
            });
    }

    /* ================= UTILS ================= */
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    showError(error) {
        let message = 'Unexpected error occurred';

        if (error?.body?.message) {
            message = error.body.message;
        } else if (error?.message) {
            message = error.message;
        } else if (Array.isArray(error?.body)) {
            message = error.body.map(e => e.message).join(', ');
        }

        console.error('FULL ERROR:', JSON.stringify(error));

        this.toast('Error', message, 'error');
    }
}