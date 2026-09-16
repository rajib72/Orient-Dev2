import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import searchCustomersByPhone from '@salesforce/apex/Ctrl_PurchaseBehaviourInsights.searchCustomersByPhone';
import getCustomerInsightsPayload from '@salesforce/apex/Ctrl_PurchaseBehaviourInsights.getCustomerInsightsPayload';
import resolveRecordContext from '@salesforce/apex/Ctrl_PurchaseBehaviourInsights.resolveRecordContext';

export default class CustomerPurchaseBehaviourInsights extends NavigationMixin(LightningElement) {
    @api recordId;

    @track searchKey = '';
    @track lastSearchedKey = '';
    @track customerMatches = [];
    @track activeCustomer = null;
    @track insightsList = [];
    @track selectedInsight = null;
    @track selectedInsightId = null;

    isLoading = false;
    loadingMessage = 'Loading...';
    searchPerformed = false;

    connectedCallback() {
        if (this.recordId) {
            this.loadByRecordId(this.recordId);
        }
    }

    /* -------------------------------------------------------------
     * RECORD CONTEXT LOADER (FOR ACCOUNT / INSIGHT RECORD PAGES)
     * ----------------------------------------------------------- */
    async loadByRecordId(recId) {
        this.isLoading = true;
        this.loadingMessage = 'Resolving record context...';
        try {
            const payload = await resolveRecordContext({ recordId: recId });
            if (payload && payload.customer) {
                this.applyPayload(payload);
            }
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /* -------------------------------------------------------------
     * SEARCH HANDLERS
     * ----------------------------------------------------------- */
    handleSearchInput(event) {
        this.searchKey = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            this.handleSearchClick();
        }
    }

    handleClearSearch() {
        this.searchKey = '';
        this.customerMatches = [];
        this.searchPerformed = false;
    }

    async handleSearchClick() {
        const query = (this.searchKey || '').trim();
        if (!query || query.length < 3) {
            this.showToast('Notice', 'Please enter at least 3 digits to search.', 'warning');
            return;
        }

        this.isLoading = true;
        this.loadingMessage = 'Searching customer records...';
        this.searchPerformed = true;
        this.lastSearchedKey = query;
        this.customerMatches = [];

        try {
            const results = await searchCustomersByPhone({ phoneKey: query });
            if (results && results.length > 0) {
                const decoratedMatches = results.map(c => ({
                    ...c,
                    customerNameInitials: this.getInitials(c.customerName)
                }));

                if (decoratedMatches.length === 1) {
                    // Exact single match: auto-select customer directly
                    this.customerMatches = [];
                    await this.loadCustomerInsights(decoratedMatches[0].customerId);
                } else {
                    // Multiple matches found: let user choose
                    this.customerMatches = decoratedMatches;
                }
            } else {
                this.customerMatches = [];
            }
        } catch (error) {
            this.showToast('Search Failed', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSelectCustomer(event) {
        const customerId = event.currentTarget.dataset.id;
        if (!customerId) return;
        await this.loadCustomerInsights(customerId);
    }

    /* -------------------------------------------------------------
     * INSIGHTS LOADER
     * ----------------------------------------------------------- */
    async loadCustomerInsights(customerId) {
        this.isLoading = true;
        this.loadingMessage = 'Loading purchase behaviour insights...';
        try {
            const payload = await getCustomerInsightsPayload({ customerId: customerId });
            this.applyPayload(payload);
            this.customerMatches = [];
        } catch (error) {
            this.showToast('Load Failed', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    applyPayload(payload) {
        this.activeCustomer = payload.customer;

        const rawList = payload.insights || [];
        this.insightsList = rawList.map((item, index) => {
            return {
                ...item,
                formattedShortDate: item.lastPurchaseDate ? this.formatDate(item.lastPurchaseDate) : 'No Date',
                formattedLastDate: item.lastPurchaseDate ? this.formatDate(item.lastPurchaseDate) : '—',
                formattedNextDate: item.nextExpectedPurchaseDate ? this.formatDate(item.nextExpectedPurchaseDate) : '—',
                formattedCreatedDate: item.createdDate ? this.formatDateTime(item.createdDate) : '—',
                rowClass: item.recordId === (payload.latestInsight && payload.latestInsight.recordId) ? 'oj-row-selected' : ''
            };
        });

        if (payload.latestInsight) {
            this.selectedInsightId = payload.latestInsight.recordId;
            this.selectedInsight = payload.latestInsight;
        } else if (this.insightsList.length > 0) {
            this.selectedInsightId = this.insightsList[0].recordId;
            this.selectedInsight = this.insightsList[0];
        } else {
            this.selectedInsightId = null;
            this.selectedInsight = null;
        }
    }

    handleChangeCustomer() {
        this.activeCustomer = null;
        this.insightsList = [];
        this.selectedInsight = null;
        this.selectedInsightId = null;
        this.searchPerformed = false;
        this.customerMatches = [];
    }

    async handleRefresh() {
        if (this.activeCustomer && this.activeCustomer.customerId) {
            await this.loadCustomerInsights(this.activeCustomer.customerId);
            this.showToast('Success', 'Customer insights refreshed successfully.', 'success');
        }
    }

    handleSnapshotChange(event) {
        const recordId = event.target.value;
        this.selectInsightById(recordId);
    }

    handleRowSelect(event) {
        const recordId = event.currentTarget.dataset.id;
        this.selectInsightById(recordId);
    }

    selectInsightById(recordId) {
        const found = this.insightsList.find(item => item.recordId === recordId);
        if (found) {
            this.selectedInsightId = recordId;
            this.selectedInsight = found;
            // Update selected row styling in table
            this.insightsList = this.insightsList.map(item => ({
                ...item,
                rowClass: item.recordId === recordId ? 'oj-row-selected' : ''
            }));
        }
    }

    /* -------------------------------------------------------------
     * NAVIGATION ACTIONS
     * ----------------------------------------------------------- */
    handleViewAccount() {
        if (!this.activeCustomer || !this.activeCustomer.customerId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.activeCustomer.customerId,
                objectApiName: 'Account',
                actionName: 'view'
            }
        });
    }

    handleViewInsightRecord() {
        if (!this.selectedInsight || !this.selectedInsight.recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.selectedInsight.recordId,
                objectApiName: 'Purchase_Behaviour_Insights__c',
                actionName: 'view'
            }
        });
    }

    /* -------------------------------------------------------------
     * COMPUTED GETTERS & UI HELPERS
     * ----------------------------------------------------------- */
    get hasSearchInput() {
        return !!this.searchKey && this.searchKey.length > 0;
    }

    get isSearchDisabled() {
        return !this.searchKey || this.searchKey.trim().length < 3 || this.isLoading;
    }

    get showCustomerPicker() {
        return !this.activeCustomer && this.customerMatches && this.customerMatches.length > 1;
    }

    get showNoCustomerFound() {
        return !this.activeCustomer && this.searchPerformed && (!this.customerMatches || this.customerMatches.length === 0);
    }

    get hasActiveCustomer() {
        return !!this.activeCustomer;
    }

    get hasInsights() {
        return !!this.selectedInsight;
    }

    get hasMultipleInsights() {
        return this.insightsList && this.insightsList.length > 1;
    }

    get isInitialState() {
        return !this.activeCustomer && !this.showCustomerPicker && !this.showNoCustomerFound;
    }

    get activeCustomerInitials() {
        return this.activeCustomer ? this.getInitials(this.activeCustomer.customerName) : 'OJ';
    }

    get activeCustomerPhoneHref() {
        return this.activeCustomer && this.activeCustomer.phone ? `tel:${this.activeCustomer.phone}` : '#';
    }

    get selectedInsightFormattedATS() {
        if (!this.selectedInsight) return '₹ 0';
        if (this.selectedInsight.formattedTicketSize && this.selectedInsight.formattedTicketSize !== '₹ 0') {
            return this.selectedInsight.formattedTicketSize;
        }
        if (this.selectedInsight.averageTicketSize != null) {
            return new Intl.NumberFormat('en-IN', {
                style: 'currency',
                currency: 'INR',
                maximumFractionDigits: 0
            }).format(this.selectedInsight.averageTicketSize);
        }
        return '₹ 0';
    }

    get selectedInsightFormattedLastPurchase() {
        if (!this.selectedInsight || !this.selectedInsight.lastPurchaseDate) {
            return 'No Record';
        }
        return this.formatDate(this.selectedInsight.lastPurchaseDate);
    }

    get selectedInsightFormattedNextPurchase() {
        if (!this.selectedInsight || !this.selectedInsight.nextExpectedPurchaseDate) {
            return 'Not Scheduled';
        }
        return this.formatDate(this.selectedInsight.nextExpectedPurchaseDate);
    }

    get selectedInsightDaysAgoLabel() {
        if (!this.selectedInsight || this.selectedInsight.daysSinceLastPurchase == null) {
            return null;
        }
        const d = this.selectedInsight.daysSinceLastPurchase;
        if (d === 0) return 'Purchased Today';
        if (d === 1) return '1 day ago';
        return `${d} days ago`;
    }

    get selectedInsightOccasion() {
        return this.selectedInsight && this.selectedInsight.purchaseOccasion
            ? this.selectedInsight.purchaseOccasion
            : 'General / Ongoing';
    }

    get selectedInsightFormattedCreatedDate() {
        if (!this.selectedInsight || !this.selectedInsight.createdDate) {
            return '—';
        }
        return this.formatDateTime(this.selectedInsight.createdDate);
    }

    get frequencyTierBadgeClass() {
        if (!this.selectedInsight) return 'oj-badge-neutral';
        const tier = (this.selectedInsight.frequencyTier || '').toLowerCase();
        if (tier.includes('vip') || tier.includes('high')) {
            return 'oj-badge-gold';
        }
        if (tier.includes('regular')) {
            return 'oj-badge-maroon';
        }
        return 'oj-badge-neutral';
    }

    get nextPurchaseBadgeClass() {
        if (!this.selectedInsight) return 'oj-badge-neutral';
        const status = this.selectedInsight.nextPurchaseStatus;
        if (status === 'OVERDUE') return 'oj-badge-overdue';
        if (status === 'DUE_SOON') return 'oj-badge-warning';
        if (status === 'UPCOMING') return 'oj-badge-positive';
        return 'oj-badge-neutral';
    }

    get nextPurchaseStatusLabel() {
        if (!this.selectedInsight) return '';
        const status = this.selectedInsight.nextPurchaseStatus;
        const days = this.selectedInsight.daysUntilNextPurchase;

        if (status === 'OVERDUE') {
            return days ? `⚠️ Overdue by ${Math.abs(days)} days` : '⚠️ Overdue';
        }
        if (status === 'DUE_SOON') {
            return days === 0 ? '⚡ Due Today' : `⚡ Due in ${days} days`;
        }
        if (status === 'UPCOMING') {
            return `✓ In ${days} days`;
        }
        return 'Not Scheduled';
    }

    /* -------------------------------------------------------------
     * FORMATTERS
     * ----------------------------------------------------------- */
    getInitials(name) {
        if (!name) return 'OJ';
        const parts = name.trim().split(/\s+/);
        if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase();
        return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        try {
            const d = new Date(dateStr + 'T00:00:00');
            return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
        } catch (e) {
            return dateStr;
        }
    }

    formatDateTime(dtStr) {
        if (!dtStr) return '';
        try {
            const d = new Date(dtStr);
            return d.toLocaleString('en-IN', {
                day: 'numeric',
                month: 'short',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        } catch (e) {
            return dtStr;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'An unexpected error occurred.';
    }
}