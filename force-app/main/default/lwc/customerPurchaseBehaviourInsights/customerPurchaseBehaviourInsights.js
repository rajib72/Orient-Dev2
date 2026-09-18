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

    @track categories = [];
    @track activeCategoryKey = 'all';
    @track fieldSearchTerm = '';
    @track totalCategoriesCount = 0;
    @track activeCategoriesCount = 0;
    @track totalFieldsCount = 0;

    isLoading = false;
    loadingMessage = 'Loading...';
    searchPerformed = false;

    connectedCallback() {
        if (this.recordId) {
            this.loadByRecordId(this.recordId);
        }
    }

    /* -------------------------------------------------------------
     * RECORD CONTEXT LOADER (FOR ACCOUNT / ANY INSIGHT RECORD PAGES)
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
                    this.customerMatches = [];
                    await this.loadCustomerInsights(decoratedMatches[0].customerId);
                } else {
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
        this.loadingMessage = 'Loading Customer 360 intelligence across all 13 modules...';
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
        this.totalCategoriesCount = payload.totalCategoriesCount || 0;
        this.activeCategoriesCount = payload.activeCategoriesCount || 0;
        this.totalFieldsCount = payload.totalFieldsCount || 0;
        this.categories = payload.categories || [];

        const rawList = payload.insights || [];
        this.insightsList = rawList.map((item) => {
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
        this.categories = [];
        this.activeCategoryKey = 'all';
        this.fieldSearchTerm = '';
        this.searchPerformed = false;
        this.customerMatches = [];
    }

    async handleRefresh() {
        if (this.activeCustomer && this.activeCustomer.customerId) {
            await this.loadCustomerInsights(this.activeCustomer.customerId);
            this.showToast('Success', 'Customer 360 insights refreshed successfully.', 'success');
        }
    }

    /* -------------------------------------------------------------
     * CATEGORY TAB & FILTER ACTIONS
     * ----------------------------------------------------------- */
    handleCategoryTabClick(event) {
        const selectedKey = event.currentTarget.dataset.key;
        if (selectedKey) {
            this.activeCategoryKey = selectedKey;
        }
    }

    handleFieldSearchInput(event) {
        this.fieldSearchTerm = (event.target.value || '').trim().toLowerCase();
    }

    handleClearFieldSearch() {
        this.fieldSearchTerm = '';
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
            this.insightsList = this.insightsList.map(item => ({
                ...item,
                rowClass: item.recordId === recordId ? 'oj-row-selected' : ''
            }));
        }
    }

    /* -------------------------------------------------------------
     * RECORD NAVIGATION ACTIONS
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

    handleViewCategoryRecord(event) {
        const recId = event.currentTarget.dataset.id;
        const objName = event.currentTarget.dataset.object;
        if (!recId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recId,
                objectApiName: objName || 'Account',
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

    get hasFieldSearchInput() {
        return !!this.fieldSearchTerm && this.fieldSearchTerm.length > 0;
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


    /* -------------------------------------------------------------
     * CATEGORY TABS & FILTERED MODULES GETTERS
     * ----------------------------------------------------------- */
    get categoryTabs() {
        const allTab = {
            key: 'all',
            label: 'All Modules (360°)',
            shortCode: 'ALL',
            fieldCount: this.totalFieldsCount,
            hasRecord: this.activeCategoriesCount > 0,
            activeClass: this.activeCategoryKey === 'all' ? 'oj-tab-btn oj-tab-btn-active' : 'oj-tab-btn'
        };

        const moduleTabs = (this.categories || []).map(cat => ({
            key: cat.categoryKey,
            label: cat.objectLabel,
            shortCode: cat.shortCode,
            fieldCount: cat.fieldCount,
            hasRecord: cat.hasRecord,
            activeClass: this.activeCategoryKey === cat.categoryKey ? 'oj-tab-btn oj-tab-btn-active' : 'oj-tab-btn'
        }));

        return [allTab, ...moduleTabs];
    }

    get filteredCategories() {
        if (!this.categories || this.categories.length === 0) {
            return [];
        }

        const term = this.fieldSearchTerm;
        const selectedKey = this.activeCategoryKey;

        return this.categories
            .filter(cat => selectedKey === 'all' || cat.categoryKey === selectedKey)
            .map(cat => {
                const allFields = cat.fields || [];
                const matchedFields = term
                    ? allFields.filter(f =>
                        (f.label && f.label.toLowerCase().includes(term)) ||
                        (f.apiName && f.apiName.toLowerCase().includes(term)) ||
                        (f.value && String(f.value).toLowerCase().includes(term))
                    )
                    : allFields;

                return {
                    ...cat,
                    displayFields: matchedFields,
                    matchingFieldsCount: matchedFields.length,
                    statusBadgeClass: cat.hasRecord ? 'oj-badge-status-linked' : 'oj-badge-status-none',
                    statusBadgeText: cat.hasRecord ? 'Record Linked' : 'No Record'
                };
            })
            .filter(cat => !term || cat.displayFields.length > 0);
    }

    get hasFilteredCategories() {
        return this.filteredCategories && this.filteredCategories.length > 0;
    }

    get totalMatchingFieldsCount() {
        let count = 0;
        for (const cat of this.filteredCategories) {
            count += cat.matchingFieldsCount || 0;
        }
        return count;
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