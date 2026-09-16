import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getStores from '@salesforce/apex/CreateFormActivityController.getStores';
import getSalesExecutivesByStores from '@salesforce/apex/CreateFormActivityController.getSalesExecutivesByStores';
import createActivity from '@salesforce/apex/CreateFormActivityController.createActivity';

export default class CreateFormActivity extends LightningElement {
    @api recordId;

    isLoading = false;

    activityName;
    activityDate;
    activityEndDate;

    storeOptions = [];
    selectedStoreIds = [];
    storeLocationByStoreId = {};
    storeError = '';
    isStoreDropdownOpen = false;

    salesExecutiveOptions = [];
    selectedSalesExecutiveIds = [];

    get hasSelectedStores() {
        return this.selectedStoreIds && this.selectedStoreIds.length > 0;
    }

    get hasSalesExecutives() {
        return this.salesExecutiveOptions && this.salesExecutiveOptions.length > 0;
    }

    get selectedCount() {
        return this.selectedSalesExecutiveIds ? this.selectedSalesExecutiveIds.length : 0;
    }

    get storeDropdownClass() {
        return this.isStoreDropdownOpen
            ? 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open'
            : 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
    }

    get selectedStoreDisplay() {
        const selectedStores = this.storeOptions.filter(item => item.selected);

        if (!selectedStores.length) {
            return 'Select Stores';
        }

        if (selectedStores.length === 1) {
            return selectedStores[0].label;
        }

        return selectedStores.length + ' Stores Selected';
    }

    get selectedStoreTextClass() {
        return this.hasSelectedStores ? 'selectedText' : 'placeholderText';
    }

    get selectedStorePills() {
        return this.storeOptions.filter(item => item.selected);
    }

    get storeExecutiveGroups() {
        const groups = [];

        this.selectedStorePills.forEach(store => {
            const executives = this.salesExecutiveOptions
                .filter(exec => exec.storeId === store.value)
                .map(exec => {
                    return {
                        ...exec,
                        assignedDateDisplay: this.getAssignedDateDisplay(exec),
                        dateTextClass: exec.assignedDates && exec.assignedDates.length > 0
                            ? 'selectedText'
                            : 'placeholderText',
                        hasAssignedDates: exec.assignedDates && exec.assignedDates.length > 0,
                        selectedDatePills: this.getSelectedDatePills(exec),
                        dateOptions: this.buildDateOptionsForExecutive(exec)
                    };
                });

            const selectedExecutives = executives.filter(exec => exec.selected);

            groups.push({
                storeId: store.value,
                storeName: store.label,
                activityLocation: this.storeLocationByStoreId[store.value] || '',
                executives: executives,
                totalCount: executives.length,
                selectedCount: selectedExecutives.length,
                hasExecutives: executives.length > 0
            });
        });

        return groups;
    }

    get dateOptions() {
        const options = [];

        if (!this.activityDate || !this.activityEndDate) {
            return options;
        }

        const startDate = this.parseDateString(this.activityDate);
        const endDate = this.parseDateString(this.activityEndDate);

        if (!startDate || !endDate || endDate < startDate) {
            return options;
        }

        let currentDate = new Date(startDate);
        let counter = 0;

        while (currentDate <= endDate && counter < 366) {
            const value = this.formatDateValue(currentDate);

            options.push({
                label: this.formatDateLabel(value),
                value: value
            });

            currentDate.setDate(currentDate.getDate() + 1);
            counter++;
        }

        return options;
    }

    @wire(getStores)
    wiredStores({ data, error }) {
        if (data) {
            this.storeOptions = data.map(item => {
                return {
                    label: item.label,
                    value: item.value,
                    selected: false,
                    optionClass: 'storeOption'
                };
            });
        } else if (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }

    handleActivityNameChange(event) {
        this.activityName = event.target.value;
    }

    handleActivityDateChange(event) {
        this.activityDate = event.target.value;
        this.validateDateRange();
        this.normalizeSelectedExecutiveDates();
    }

    handleActivityEndDateChange(event) {
        this.activityEndDate = event.target.value;
        this.validateDateRange();
        this.normalizeSelectedExecutiveDates();
    }

    handleStoreActivityLocationChange(event) {
        const storeId = event.target.dataset.storeId;
        const locationValue = event.target.value;

        this.storeLocationByStoreId = {
            ...this.storeLocationByStoreId,
            [storeId]: locationValue
        };
    }

    toggleStoreDropdown(event) {
        event.stopPropagation();
        this.isStoreDropdownOpen = !this.isStoreDropdownOpen;
    }

    handleStoreOptionClick(event) {
        event.stopPropagation();

        const storeId = event.currentTarget.dataset.id;

        this.storeOptions = this.storeOptions.map(item => {
            if (item.value === storeId) {
                const isSelected = !item.selected;

                return {
                    ...item,
                    selected: isSelected,
                    optionClass: isSelected ? 'storeOption selectedOption' : 'storeOption'
                };
            }

            return item;
        });

        this.selectedStoreIds = this.storeOptions
            .filter(item => item.selected)
            .map(item => item.value);

        this.syncStoreLocations();
        this.storeError = '';
        this.loadSalesExecutives();
    }

    handleRemoveStore(event) {
        event.stopPropagation();

        const storeId = event.currentTarget.dataset.id;

        this.storeOptions = this.storeOptions.map(item => {
            if (item.value === storeId) {
                return {
                    ...item,
                    selected: false,
                    optionClass: 'storeOption'
                };
            }

            return item;
        });

        this.selectedStoreIds = this.storeOptions
            .filter(item => item.selected)
            .map(item => item.value);

        this.syncStoreLocations();
        this.loadSalesExecutives();
    }

    syncStoreLocations() {
        const updatedLocationMap = {};

        this.selectedStoreIds.forEach(storeId => {
            updatedLocationMap[storeId] = this.storeLocationByStoreId[storeId] || '';
        });

        this.storeLocationByStoreId = updatedLocationMap;
    }

    loadSalesExecutives() {
        if (!this.selectedStoreIds || this.selectedStoreIds.length === 0) {
            this.salesExecutiveOptions = [];
            this.selectedSalesExecutiveIds = [];
            return;
        }

        const previousSelectionMap = new Map();

        this.salesExecutiveOptions.forEach(item => {
            previousSelectionMap.set(item.value, {
                selected: item.selected,
                assignedDates: item.assignedDates || [],
                isDateDropdownOpen: item.isDateDropdownOpen || false
            });
        });

        this.isLoading = true;

        getSalesExecutivesByStores({
            storeIds: this.selectedStoreIds
        })
            .then(result => {
                this.salesExecutiveOptions = result.map(item => {
                    const previousData = previousSelectionMap.get(item.value);
                    const isSelected = previousData ? previousData.selected : false;

                    let assignedDates = previousData && previousData.assignedDates
                        ? [...previousData.assignedDates]
                        : [];

                    if (isSelected && assignedDates.length === 0 && this.activityDate) {
                        assignedDates = [this.activityDate];
                    }

                    return {
                        label: item.label,
                        value: item.value,
                        storeId: item.storeId,
                        storeName: item.storeName,
                        selected: isSelected,
                        assignedDates: assignedDates,
                        isDateDropdownOpen: previousData ? previousData.isDateDropdownOpen : false,
                        initial: item.label ? item.label.charAt(0).toUpperCase() : 'S',
                        cardClass: isSelected ? 'executiveCard selectedCard' : 'executiveCard'
                    };
                });

                this.normalizeSelectedExecutiveDates();

                this.selectedSalesExecutiveIds = this.salesExecutiveOptions
                    .filter(item => item.selected)
                    .map(item => item.value);

                this.isLoading = false;
            })
            .catch(error => {
                this.salesExecutiveOptions = [];
                this.selectedSalesExecutiveIds = [];
                this.isLoading = false;

                this.showToast(
                    'Error',
                    this.getErrorMessage(error),
                    'error'
                );
            });
    }

    handleExecutiveCardClick(event) {
        const executiveId = event.currentTarget.dataset.id;

        this.salesExecutiveOptions = this.salesExecutiveOptions.map(item => {
            if (item.value === executiveId) {
                const newSelectedValue = !item.selected;

                let assignedDates = item.assignedDates ? [...item.assignedDates] : [];

                if (newSelectedValue && assignedDates.length === 0 && this.activityDate) {
                    assignedDates = [this.activityDate];
                }

                if (!newSelectedValue) {
                    assignedDates = [];
                }

                return {
                    ...item,
                    selected: newSelectedValue,
                    assignedDates: assignedDates,
                    isDateDropdownOpen: false,
                    cardClass: newSelectedValue ? 'executiveCard selectedCard' : 'executiveCard'
                };
            }

            return item;
        });

        this.selectedSalesExecutiveIds = this.salesExecutiveOptions
            .filter(item => item.selected)
            .map(item => item.value);
    }

    toggleExecutiveDateDropdown(event) {
        event.stopPropagation();

        const executiveId = event.currentTarget.dataset.id;

        this.salesExecutiveOptions = this.salesExecutiveOptions.map(item => {
            if (item.value === executiveId) {
                return {
                    ...item,
                    isDateDropdownOpen: !item.isDateDropdownOpen
                };
            }

            return {
                ...item,
                isDateDropdownOpen: false
            };
        });
    }

    handleExecutiveDateOptionClick(event) {
        event.stopPropagation();

        const executiveId = event.currentTarget.dataset.execId;
        const selectedDate = event.currentTarget.dataset.date;

        this.salesExecutiveOptions = this.salesExecutiveOptions.map(item => {
            if (item.value === executiveId) {
                let assignedDates = item.assignedDates ? [...item.assignedDates] : [];

                if (assignedDates.includes(selectedDate)) {
                    assignedDates = assignedDates.filter(dateValue => dateValue !== selectedDate);
                } else {
                    assignedDates.push(selectedDate);
                }

                assignedDates.sort();

                return {
                    ...item,
                    assignedDates: assignedDates
                };
            }

            return item;
        });
    }

    handleRemoveExecutiveDate(event) {
        event.stopPropagation();

        const executiveId = event.currentTarget.dataset.execId;
        const selectedDate = event.currentTarget.dataset.date;

        this.salesExecutiveOptions = this.salesExecutiveOptions.map(item => {
            if (item.value === executiveId) {
                const assignedDates = item.assignedDates
                    ? item.assignedDates.filter(dateValue => dateValue !== selectedDate)
                    : [];

                return {
                    ...item,
                    assignedDates: assignedDates
                };
            }

            return item;
        });
    }

    stopEvent(event) {
        event.stopPropagation();
    }

    normalizeSelectedExecutiveDates() {
        this.salesExecutiveOptions = this.salesExecutiveOptions.map(item => {
            if (!item.selected) {
                return item;
            }

            let assignedDates = item.assignedDates ? [...item.assignedDates] : [];

            assignedDates = assignedDates.filter(dateValue => {
                if (!dateValue) {
                    return false;
                }

                if (this.activityDate && dateValue < this.activityDate) {
                    return false;
                }

                if (this.activityEndDate && dateValue > this.activityEndDate) {
                    return false;
                }

                return true;
            });

            if (assignedDates.length === 0 && this.activityDate) {
                assignedDates = [this.activityDate];
            }

            assignedDates.sort();

            return {
                ...item,
                assignedDates: assignedDates
            };
        });
    }

    getAssignedDateDisplay(exec) {
        if (!exec.assignedDates || exec.assignedDates.length === 0) {
            return 'Select Target Dates';
        }

        if (exec.assignedDates.length === 1) {
            return this.formatDateLabel(exec.assignedDates[0]);
        }

        return exec.assignedDates.length + ' Dates Selected';
    }

    getSelectedDatePills(exec) {
        if (!exec.assignedDates || exec.assignedDates.length === 0) {
            return [];
        }

        return exec.assignedDates.map(dateValue => {
            return {
                label: this.formatDateLabel(dateValue),
                value: dateValue
            };
        });
    }

    buildDateOptionsForExecutive(exec) {
        const selectedDates = exec.assignedDates || [];

        return this.dateOptions.map(dateOption => {
            const isSelected = selectedDates.includes(dateOption.value);

            return {
                label: dateOption.label,
                value: dateOption.value,
                selected: isSelected,
                optionClass: isSelected ? 'dateOption selectedDateOption' : 'dateOption'
            };
        });
    }

    validateStores() {
        if (!this.selectedStoreIds || this.selectedStoreIds.length === 0) {
            this.storeError = 'Please select at least one Assigned Store.';
            return false;
        }

        this.storeError = '';
        return true;
    }

    validateStoreLocations() {
        const missingStoreNames = [];

        this.selectedStoreIds.forEach(storeId => {
            const locationValue = this.storeLocationByStoreId[storeId];

            if (!locationValue || !locationValue.trim()) {
                const store = this.storeOptions.find(item => item.value === storeId);
                missingStoreNames.push(store ? store.label : storeId);
            }
        });

        if (missingStoreNames.length > 0) {
            this.showToast(
                'Validation Error',
                'Please enter Activity Location for: ' + missingStoreNames.join(', '),
                'error'
            );
            return false;
        }

        return true;
    }

    validateDateRange() {
        const endDateInput = this.template.querySelector('[data-id="activityEndDate"]');

        if (!endDateInput) {
            return true;
        }

        if (this.activityDate && this.activityEndDate && this.activityEndDate < this.activityDate) {
            endDateInput.setCustomValidity('Activity End Date cannot be before Activity Start Date.');
        } else {
            endDateInput.setCustomValidity('');
        }

        endDateInput.reportValidity();
        return endDateInput.checkValidity();
    }

    validateSalesExecutivesForStores() {
        if (!this.selectedSalesExecutiveIds || this.selectedSalesExecutiveIds.length === 0) {
            this.showToast(
                'Validation Error',
                'Please select at least one Sales Executive.',
                'error'
            );
            return false;
        }

        const missingStoreNames = [];

        this.selectedStoreIds.forEach(storeId => {
            const hasExecutiveForStore = this.salesExecutiveOptions.some(exec => {
                return exec.storeId === storeId && exec.selected;
            });

            if (!hasExecutiveForStore) {
                const store = this.storeOptions.find(item => item.value === storeId);
                missingStoreNames.push(store ? store.label : storeId);
            }
        });

        if (missingStoreNames.length > 0) {
            this.showToast(
                'Validation Error',
                'Please select at least one Sales Executive for each selected Store. Missing: ' + missingStoreNames.join(', '),
                'error'
            );
            return false;
        }

        const missingDateExecutives = [];
        const invalidDateExecutives = [];

        this.salesExecutiveOptions.forEach(exec => {
            if (exec.selected) {
                if (!exec.assignedDates || exec.assignedDates.length === 0) {
                    missingDateExecutives.push(exec.label);
                } else {
                    const hasInvalidDate = exec.assignedDates.some(dateValue => {
                        return (
                            this.activityDate &&
                            this.activityEndDate &&
                            (
                                dateValue < this.activityDate ||
                                dateValue > this.activityEndDate
                            )
                        );
                    });

                    if (hasInvalidDate) {
                        invalidDateExecutives.push(exec.label);
                    }
                }
            }
        });

        if (missingDateExecutives.length > 0) {
            this.showToast(
                'Validation Error',
                'Please select Target Date(s) for: ' + missingDateExecutives.join(', '),
                'error'
            );
            return false;
        }

        if (invalidDateExecutives.length > 0) {
            this.showToast(
                'Validation Error',
                'Target Date(s) must be between Activity Start Date and Activity End Date for: ' + invalidDateExecutives.join(', '),
                'error'
            );
            return false;
        }

        return true;
    }

    getStoreLocationAssignments() {
        return this.selectedStoreIds.map(storeId => {
            return {
                storeId: storeId,
                activityLocation: this.storeLocationByStoreId[storeId]
            };
        });
    }

    getSalesExecutiveAssignments() {
        return this.salesExecutiveOptions
            .filter(item => item.selected)
            .map(item => {
                return {
                    salesExecutiveId: item.value,
                    assignedDates: item.assignedDates || []
                };
            });
    }

    handleSave() {
        const isStoreValid = this.validateStores();
        const isDateRangeValid = this.validateDateRange();
        const isStoreLocationValid = this.validateStoreLocations();

        const allValid = [
            ...this.template.querySelectorAll('lightning-input, lightning-combobox')
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        if (!allValid || !isStoreValid || !isDateRangeValid || !isStoreLocationValid) {
            return;
        }

        if (!this.validateSalesExecutivesForStores()) {
            return;
        }

        this.isLoading = true;

        createActivity({
            finalCustomizeFormId: this.recordId,
            assignedStoreIds: this.selectedStoreIds,
            activityName: this.activityName,
            activityDate: this.activityDate,
            activityEndDate: this.activityEndDate,
            storeLocationAssignments: this.getStoreLocationAssignments(),
            salesExecutiveAssignments: this.getSalesExecutiveAssignments()
        })
            .then(() => {
                this.isLoading = false;

                this.showToast(
                    'Success',
                    'Activity records and assigned person target dates created successfully.',
                    'success'
                );

                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                this.isLoading = false;

                this.showToast(
                    'Error',
                    this.getErrorMessage(error),
                    'error'
                );
            });
    }

    parseDateString(dateString) {
        if (!dateString) {
            return null;
        }

        const parts = dateString.split('-');

        if (parts.length !== 3) {
            return null;
        }

        return new Date(
            Number(parts[0]),
            Number(parts[1]) - 1,
            Number(parts[2])
        );
    }

    formatDateValue(dateObj) {
        const year = dateObj.getFullYear();
        const month = String(dateObj.getMonth() + 1).padStart(2, '0');
        const day = String(dateObj.getDate()).padStart(2, '0');

        return `${year}-${month}-${day}`;
    }

    formatDateLabel(dateString) {
        const dateObj = this.parseDateString(dateString);

        if (!dateObj) {
            return dateString;
        }

        const months = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];

        const day = String(dateObj.getDate()).padStart(2, '0');
        const month = months[dateObj.getMonth()];
        const year = dateObj.getFullYear();

        return `${day}-${month}-${year}`;
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
        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Something went wrong.';
    }
}