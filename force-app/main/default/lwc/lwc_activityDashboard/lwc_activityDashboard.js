import { LightningElement, wire } from 'lwc';

import getStores from '@salesforce/apex/ctrl_ActivityDashboardController.getStores';
import getActivities from '@salesforce/apex/ctrl_ActivityDashboardController.getActivities';

export default class ActivityDashboard extends LightningElement {
    isLoading = false;

    fromDate;
    selectedActivityId;
    toDate;
    selectedStoreId = '';
    searchKey = '';

    storeOptions = [];
    activities = [];
    groupedActivities = [];

    showDashboard = true;
    showInteractiveForm = false;
    selectedFormId;

    connectedCallback() {
        this.setDefaultDates();
        this.loadActivities();
    }

    get totalActivities() {
        return this.activities ? this.activities.length : 0;
    }

    get hasGroupedActivities() {
        return this.groupedActivities && this.groupedActivities.length > 0;
    }

    get fromDateDisplay() {
        return this.formatDate(this.fromDate);
    }

    get toDateDisplay() {
        return this.formatDate(this.toDate);
    }

    @wire(getStores)
    wiredStores({ data, error }) {
        if (data) {
            this.storeOptions = data;
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error(error);
        }
    }

    setDefaultDates() {
        const today = new Date();

        const firstDay = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDay = new Date(today.getFullYear(), today.getMonth() + 1, 0);

        this.fromDate = this.toInputDate(firstDay);
        this.toDate = this.toInputDate(lastDay);
    }

    handleFromDateChange(event) {
        this.fromDate = event.target.value;
    }

    handleToDateChange(event) {
        this.toDate = event.target.value;
    }

    handleStoreChange(event) {
        this.selectedStoreId = event.detail.value;
    }

    handleSearchTyping(event) {
        this.searchKey = event.target.value;
    }

    handleClearFilters() {
        this.setDefaultDates();
        this.selectedStoreId = '';
        this.searchKey = '';
        this.loadActivities();
    }

    loadActivities() {
        this.isLoading = true;

        getActivities({
            fromDate: this.fromDate,
            toDate: this.toDate,
            storeId: this.selectedStoreId ? this.selectedStoreId : null,
            searchKey: this.searchKey
        })
            .then(result => {
                this.activities = (result || []).map(item => {
                    return {
                        ...item,
                        activityDateDisplay: this.formatDate(item.activityDate),
                        activityLocation: item.activityLocation || '-',
                        storeName: item.storeName || '-',
                        finalCustomizeFormNo: item.finalCustomizeFormNo || '-',
                        formName: item.formName || '-'
                    };
                });

                this.prepareGroupedActivities();
                this.isLoading = false;
            })
            .catch(error => {
                this.activities = [];
                this.groupedActivities = [];
                this.isLoading = false;

                // eslint-disable-next-line no-console
                console.error(error);
            });
    }

    prepareGroupedActivities() {
        const groupMap = {};

        this.activities.forEach(item => {
            const dateKey = item.activityDate;

            if (!groupMap[dateKey]) {
                groupMap[dateKey] = {
                    dateKey: dateKey,
                    displayDate: this.formatDateWithDay(dateKey),
                    count: 0,
                    expanded: true,
                    iconName: 'utility:chevronup',
                    records: []
                };
            }

            groupMap[dateKey].records.push(item);
            groupMap[dateKey].count += 1;
        });

        this.groupedActivities = Object.values(groupMap);
    }

    toggleGroup(event) {
        const dateKey = event.currentTarget.dataset.date;

        this.groupedActivities = this.groupedActivities.map(group => {
            if (group.dateKey === dateKey) {
                const expanded = !group.expanded;

                return {
                    ...group,
                    expanded: expanded,
                    iconName: expanded ? 'utility:chevronup' : 'utility:chevrondown'
                };
            }

            return group;
        });
    }


    openFormRecord(event) {
        const formId = event.currentTarget.dataset.id;
        const activityId = event.currentTarget.dataset.activityId;

        if (!formId || !activityId) {
            return;
        }

        this.selectedFormId = formId;
        this.selectedActivityId = activityId;

        this.showDashboard = true;
        this.showInteractiveForm = true;
    }

    handleBackToDashboard() {
        this.showInteractiveForm = false;
        this.selectedFormId = null;
        this.selectedActivityId = null;
    }

    toInputDate(dateObj) {
        const year = dateObj.getFullYear();
        const month = String(dateObj.getMonth() + 1).padStart(2, '0');
        const day = String(dateObj.getDate()).padStart(2, '0');

        return `${year}-${month}-${day}`;
    }

    formatDate(dateValue) {
        if (!dateValue) {
            return '';
        }

        const parts = dateValue.split('-');

        if (parts.length !== 3) {
            return dateValue;
        }

        return `${parts[2]}-${parts[1]}-${parts[0]}`;
    }

    formatDateWithDay(dateValue) {
        if (!dateValue) {
            return '';
        }

        const dateObj = new Date(dateValue + 'T00:00:00');

        const day = dateObj.toLocaleDateString('en-US', {
            weekday: 'long'
        });

        return `${this.formatDate(dateValue)} (${day})`;
    }
}