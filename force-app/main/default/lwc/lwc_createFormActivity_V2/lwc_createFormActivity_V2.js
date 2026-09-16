import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getStores
    from '@salesforce/apex/Ctrl_CreateFormActivityController.getStores';

import getTeams
    from '@salesforce/apex/Ctrl_CreateFormActivityController.getTeams';

import getSalesExecutivesByStores
    from '@salesforce/apex/Ctrl_CreateFormActivityController.getSalesExecutivesByStores';

import createActivity
    from '@salesforce/apex/Ctrl_CreateFormActivityController.createActivity';

export default class LwcCreateFormActivityV2 extends LightningElement {
    @api recordId;

    isLoading = false;
    isSaving = false;

    activityName;
    activityDate;
    activityEndDate;

    storeOptions = [];
    selectedStoreIds = [];
    storeError = '';
    isStoreDropdownOpen = false;

    teamOptions = [];
    teamSectionsByStoreId = {};
    teamSectionCounter = 0;

    salesExecutiveOptions = [];
    selectedSalesExecutiveIds = [];

    /*
     * Tracks the order in which a date-wise Activity Location
     * becomes the master/source for a Store + Team + Date group.
     */
    locationSourceCounter = 0;

    get hasSelectedStores() {
        return (
            Array.isArray(this.selectedStoreIds) &&
            this.selectedStoreIds.length > 0
        );
    }

    get hasSalesExecutives() {
        return (
            Array.isArray(this.salesExecutiveOptions) &&
            this.salesExecutiveOptions.length > 0
        );
    }

    get hasTeams() {
        return (
            Array.isArray(this.teamOptions) &&
            this.teamOptions.length > 0
        );
    }

    get selectedCount() {
        return Array.isArray(this.selectedSalesExecutiveIds)
            ? this.selectedSalesExecutiveIds.length
            : 0;
    }

    get isSaveDisabled() {
        return this.isLoading || this.isSaving;
    }

    get storeDropdownClass() {
        return this.isStoreDropdownOpen
            ? 'slds-combobox slds-dropdown-trigger ' +
              'slds-dropdown-trigger_click slds-is-open'
            : 'slds-combobox slds-dropdown-trigger ' +
              'slds-dropdown-trigger_click';
    }

    get selectedStoreDisplay() {
        const selectedStores = this.storeOptions.filter(
            item => item.selected
        );

        if (!selectedStores.length) {
            return 'Select Stores';
        }

        if (selectedStores.length === 1) {
            return selectedStores[0].label;
        }

        return `${selectedStores.length} Stores Selected`;
    }

    get selectedStoreTextClass() {
        return this.hasSelectedStores
            ? 'selectedText'
            : 'placeholderText';
    }

    get selectedStorePills() {
        return this.storeOptions.filter(item => item.selected);
    }

    get storeExecutiveGroups() {
        return this.selectedStorePills.map(store => {
            const storeExecutives =
                this.salesExecutiveOptions.filter(
                    executive =>
                        executive.storeId === store.value
                );

            const rawSections =
                this.teamSectionsByStoreId[store.value] || [];

            const teamSections = rawSections.map(
                (section, index) => {
                    const executives = storeExecutives.map(
                        executive => {
                            const assignedToThisSection =
                                executive.selected &&
                                executive.teamSectionId ===
                                    section.id;

                            const assignedToAnotherSection =
                                executive.selected &&
                                executive.teamSectionId !==
                                    section.id;

                            let cardClass =
                                assignedToThisSection
                                    ? 'executiveCard selectedCard'
                                    : 'executiveCard';

                            if (
                                assignedToAnotherSection ||
                                (
                                    !section.teamName &&
                                    !assignedToThisSection
                                )
                            ) {
                                cardClass += ' disabledCard';
                            }

                            const dateAssignments =
                                executive.dateAssignments || [];

                            const hasAssignedDates =
                                assignedToThisSection &&
                                dateAssignments.length > 0;

                            let assignmentSubText =
                                'Sales Executive';

                            if (assignedToThisSection) {
                                assignmentSubText =
                                    `Team: ${executive.teamName}`;
                            } else if (
                                assignedToAnotherSection
                            ) {
                                assignmentSubText =
                                    `Already assigned to ` +
                                    `${executive.teamName}`;
                            }

                            return {
                                ...executive,
                                selected:
                                    assignedToThisSection,
                                assignedToAnotherSection,
                                cardClass,
                                assignedDateDisplay:
                                    this.getAssignedDateDisplay(
                                        executive
                                    ),
                                dateTextClass:
                                    hasAssignedDates
                                        ? 'selectedText'
                                        : 'placeholderText',
                                hasAssignedDates,
                                selectedDatePills:
                                    this.getSelectedDatePills(
                                        executive
                                    ),
                                dateOptions:
                                    this.buildDateOptionsForExecutive(
                                        executive
                                    ),
                                dateAssignmentRows:
                                    this.getDateAssignmentRows(
                                        executive
                                    ),
                                assignmentSubText
                            };
                        }
                    );

                    return {
                        id: section.id,
                        indexLabel: index + 1,
                        selectedTeamName:
                            section.teamName || '',
                        teamOptions:
                            this.getTeamOptionsForSection(
                                store.value,
                                section.id
                            ),
                        executives,
                        hasExecutives:
                            executives.length > 0,
                        canRemove:
                            rawSections.length > 1
                    };
                }
            );

            const selectedExecutives =
                storeExecutives.filter(
                    executive => executive.selected
                );

            return {
                storeId: store.value,
                storeName: store.label,
                teamSections,
                totalCount: storeExecutives.length,
                selectedCount:
                    selectedExecutives.length,
                disableAddTeam:
                    this.isSaving ||
                    !this.hasTeams ||
                    rawSections.length >=
                        this.teamOptions.length
            };
        });
    }

    get dateOptions() {
        const options = [];

        if (
            !this.activityDate ||
            !this.activityEndDate
        ) {
            return options;
        }

        const startDate =
            this.parseDateString(this.activityDate);

        const endDate =
            this.parseDateString(this.activityEndDate);

        if (
            !startDate ||
            !endDate ||
            endDate < startDate
        ) {
            return options;
        }

        const currentDate = new Date(startDate);
        let counter = 0;

        while (
            currentDate <= endDate &&
            counter < 366
        ) {
            const value =
                this.formatDateValue(currentDate);

            options.push({
                label: this.formatDateLabel(value),
                value
            });

            currentDate.setDate(
                currentDate.getDate() + 1
            );

            counter += 1;
        }

        return options;
    }

    @wire(getStores)
    wiredStores({ data, error }) {
        if (data) {
            this.storeOptions = data.map(item => ({
                label: item.label,
                value: item.value,
                selected: false,
                optionClass: 'storeOption'
            }));
        } else if (error) {
            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        }
    }

    @wire(getTeams)
    wiredTeams({ data, error }) {
        if (data) {
            this.teamOptions = data.map(item => ({
                label: item.label,
                value: item.value
            }));
        } else if (error) {
            this.teamOptions = [];

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
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

    toggleStoreDropdown(event) {
        event.stopPropagation();

        if (this.isSaving) {
            return;
        }

        this.isStoreDropdownOpen =
            !this.isStoreDropdownOpen;
    }

    handleStoreOptionClick(event) {
        event.stopPropagation();

        if (this.isSaving) {
            return;
        }

        const storeId =
            event.currentTarget.dataset.id;

        this.storeOptions =
            this.storeOptions.map(item => {
                if (item.value !== storeId) {
                    return item;
                }

                const isSelected = !item.selected;

                return {
                    ...item,
                    selected: isSelected,
                    optionClass: isSelected
                        ? 'storeOption selectedOption'
                        : 'storeOption'
                };
            });

        this.selectedStoreIds =
            this.storeOptions
                .filter(item => item.selected)
                .map(item => item.value);

        this.syncTeamSections();
        this.storeError = '';

        this.loadSalesExecutives();
    }

    handleRemoveStore(event) {
        event.stopPropagation();

        if (this.isSaving) {
            return;
        }

        const storeId =
            event.currentTarget.dataset.id;

        this.storeOptions =
            this.storeOptions.map(item => {
                if (item.value === storeId) {
                    return {
                        ...item,
                        selected: false,
                        optionClass: 'storeOption'
                    };
                }

                return item;
            });

        this.selectedStoreIds =
            this.storeOptions
                .filter(item => item.selected)
                .map(item => item.value);

        this.syncTeamSections();
        this.loadSalesExecutives();
    }

    syncTeamSections() {
        const updatedSections = {};

        this.selectedStoreIds.forEach(storeId => {
            const existingSections =
                this.teamSectionsByStoreId[
                    storeId
                ] || [];

            updatedSections[storeId] =
                existingSections.length > 0
                    ? existingSections.map(section => ({
                        ...section
                    }))
                    : [this.createTeamSection()];
        });

        this.teamSectionsByStoreId =
            updatedSections;
    }

    createTeamSection() {
        this.teamSectionCounter += 1;

        return {
            id:
                `team-section-` +
                `${this.teamSectionCounter}`,
            teamName: ''
        };
    }

    getTeamSection(storeId, sectionId) {
        return (
            this.teamSectionsByStoreId[
                storeId
            ] || []
        ).find(
            section => section.id === sectionId
        );
    }

    getTeamOptionsForSection(
        storeId,
        sectionId
    ) {
        const sections =
            this.teamSectionsByStoreId[
                storeId
            ] || [];

        const usedTeamNames = new Set(
            sections
                .filter(
                    section =>
                        section.id !== sectionId
                )
                .map(section => section.teamName)
                .filter(Boolean)
        );

        return this.teamOptions.map(option => ({
            ...option,
            disabled:
                usedTeamNames.has(option.value)
        }));
    }

    handleAddTeam(event) {
        event.stopPropagation();

        if (this.isSaving) {
            return;
        }

        const storeId =
            event.currentTarget.dataset.storeId;

        const sections = [
            ...(
                this.teamSectionsByStoreId[
                    storeId
                ] || []
            )
        ];

        if (
            sections.length >=
            this.teamOptions.length
        ) {
            this.showToast(
                'Information',
                'All available Teams are already ' +
                'added for this Store.',
                'info'
            );

            return;
        }

        sections.push(this.createTeamSection());

        this.teamSectionsByStoreId = {
            ...this.teamSectionsByStoreId,
            [storeId]: sections
        };
    }

    handleRemoveTeam(event) {
        event.stopPropagation();

        if (this.isSaving) {
            return;
        }

        const storeId =
            event.currentTarget.dataset.storeId;

        const sectionId =
            event.currentTarget.dataset.sectionId;

        const sections = [
            ...(
                this.teamSectionsByStoreId[
                    storeId
                ] || []
            )
        ];

        if (sections.length <= 1) {
            return;
        }

        this.salesExecutiveOptions =
            this.salesExecutiveOptions.map(
                executive => {
                    if (
                        executive.storeId ===
                            storeId &&
                        executive.teamSectionId ===
                            sectionId
                    ) {
                        return {
                            ...executive,
                            selected: false,
                            teamName: '',
                            teamSectionId: '',
                            dateAssignments: [],
                            isDateDropdownOpen:
                                false
                        };
                    }

                    return executive;
                }
            );

        this.teamSectionsByStoreId = {
            ...this.teamSectionsByStoreId,
            [storeId]:
                sections.filter(
                    section =>
                        section.id !== sectionId
                )
        };

        this.refreshSelectedExecutiveIds();
    }

    handleTeamChange(event) {
        if (this.isSaving) {
            return;
        }

        const storeId =
            event.currentTarget.dataset.storeId;

        const sectionId =
            event.currentTarget.dataset.sectionId;

        const selectedTeamName =
            event.detail.value;

        const sections = [
            ...(
                this.teamSectionsByStoreId[
                    storeId
                ] || []
            )
        ];

        const duplicateExists =
            sections.some(
                section =>
                    section.id !== sectionId &&
                    section.teamName ===
                        selectedTeamName
            );

        if (duplicateExists) {
            this.showToast(
                'Validation Error',
                'The same Team cannot be added ' +
                'twice under one Store.',
                'error'
            );

            this.teamSectionsByStoreId = {
                ...this.teamSectionsByStoreId
            };

            return;
        }

        this.teamSectionsByStoreId = {
            ...this.teamSectionsByStoreId,
            [storeId]:
                sections.map(section => {
                    if (
                        section.id !== sectionId
                    ) {
                        return section;
                    }

                    return {
                        ...section,
                        teamName:
                            selectedTeamName
                    };
                })
        };

        /*
         * When the Team value changes, previously selected
         * Executives under that section retain their dates
         * and locations, but their Team Name is updated.
         */
        const updatedExecutives =
            this.salesExecutiveOptions.map(
                executive => {
                    if (
                        executive.storeId ===
                            storeId &&
                        executive.teamSectionId ===
                            sectionId
                    ) {
                        return {
                            ...executive,
                            teamName:
                                selectedTeamName
                        };
                    }

                    return executive;
                }
            );

        this.salesExecutiveOptions =
            this.reconcileSharedLocationAssignments(
                updatedExecutives
            );
    }

    loadSalesExecutives() {
        if (
            !this.selectedStoreIds ||
            this.selectedStoreIds.length === 0
        ) {
            this.salesExecutiveOptions = [];
            this.selectedSalesExecutiveIds = [];
            this.isLoading = false;

            return;
        }

        const previousSelectionMap =
            new Map();

        this.salesExecutiveOptions.forEach(
            item => {
                previousSelectionMap.set(
                    item.value,
                    {
                        selected: item.selected,
                        teamName:
                            item.teamName || '',
                        teamSectionId:
                            item.teamSectionId || '',
                        dateAssignments:
                            this.cloneDateAssignments(
                                item.dateAssignments
                            ),
                        isDateDropdownOpen:
                            item.isDateDropdownOpen ||
                            false
                    }
                );
            }
        );

        this.isLoading = true;

        getSalesExecutivesByStores({
            storeIds: this.selectedStoreIds
        })
            .then(result => {
                this.salesExecutiveOptions =
                    result.map(item => {
                        const previousData =
                            previousSelectionMap.get(
                                item.value
                            );

                        const sectionStillExists =
                            previousData &&
                            previousData.teamSectionId &&
                            this.getTeamSection(
                                item.storeId,
                                previousData
                                    .teamSectionId
                            );

                        const isSelected =
                            Boolean(
                                previousData &&
                                previousData.selected &&
                                sectionStillExists
                            );

                        let dateAssignments =
                            isSelected
                                ? this.cloneDateAssignments(
                                    previousData
                                        .dateAssignments
                                )
                                : [];

                        if (
                            isSelected &&
                            dateAssignments.length === 0 &&
                            this.activityDate
                        ) {
                            dateAssignments = [
                                this.newDateAssignment(
                                    this.activityDate
                                )
                            ];
                        }

                        return {
                            label: item.label,
                            value: item.value,
                            storeId: item.storeId,
                            storeName:
                                item.storeName,
                            selected:
                                isSelected,
                            teamName:
                                isSelected
                                    ? previousData
                                        .teamName
                                    : '',
                            teamSectionId:
                                isSelected
                                    ? previousData
                                        .teamSectionId
                                    : '',
                            dateAssignments,
                            isDateDropdownOpen:
                                isSelected
                                    ? previousData
                                        .isDateDropdownOpen
                                    : false,
                            initial:
                                item.label
                                    ? item.label
                                        .charAt(0)
                                        .toUpperCase()
                                    : 'S'
                        };
                    });

                this.normalizeSelectedExecutiveDates();
                this.refreshSelectedExecutiveIds();

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
        if (this.isSaving) {
            return;
        }

        const executiveId =
            event.currentTarget.dataset.id;

        const storeId =
            event.currentTarget.dataset.storeId;

        const sectionId =
            event.currentTarget.dataset.sectionId;

        const selectedExecutive =
            this.salesExecutiveOptions.find(
                item =>
                    item.value === executiveId
            );

        const teamSection =
            this.getTeamSection(
                storeId,
                sectionId
            );

        if (
            !selectedExecutive ||
            !teamSection
        ) {
            return;
        }

        const assignedToAnotherSection =
            selectedExecutive.selected &&
            selectedExecutive.teamSectionId !==
                sectionId;

        if (assignedToAnotherSection) {
            this.showToast(
                'Validation Error',
                `${selectedExecutive.label} is ` +
                `already assigned to ` +
                `${selectedExecutive.teamName}.`,
                'error'
            );

            return;
        }

        const assignedToThisSection =
            selectedExecutive.selected &&
            selectedExecutive.teamSectionId ===
                sectionId;

        if (
            !assignedToThisSection &&
            !teamSection.teamName
        ) {
            this.showToast(
                'Validation Error',
                'Please select a Team before ' +
                'selecting a Sales Executive.',
                'error'
            );

            return;
        }

        const updatedExecutives =
            this.salesExecutiveOptions.map(
                item => {
                    if (
                        item.value !== executiveId
                    ) {
                        return item;
                    }

                    const newSelectedValue =
                        !assignedToThisSection;

                    let dateAssignments =
                        this.cloneDateAssignments(
                            item.dateAssignments
                        );

                    if (
                        newSelectedValue &&
                        dateAssignments.length === 0 &&
                        this.activityDate
                    ) {
                        dateAssignments = [
                            this.newDateAssignment(
                                this.activityDate
                            )
                        ];
                    }

                    if (!newSelectedValue) {
                        dateAssignments = [];
                    }

                    return {
                        ...item,
                        selected:
                            newSelectedValue,
                        teamName:
                            newSelectedValue
                                ? teamSection.teamName
                                : '',
                        teamSectionId:
                            newSelectedValue
                                ? sectionId
                                : '',
                        dateAssignments,
                        isDateDropdownOpen:
                            false
                    };
                }
            );

        this.salesExecutiveOptions =
            this.reconcileSharedLocationAssignments(
                updatedExecutives
            );

        this.refreshSelectedExecutiveIds();
    }

    toggleExecutiveDateDropdown(event) {
        event.stopPropagation();

        if (this.isSaving) {
            return;
        }

        const executiveId =
            event.currentTarget.dataset.id;

        this.salesExecutiveOptions =
            this.salesExecutiveOptions.map(
                item => {
                    if (
                        item.value === executiveId
                    ) {
                        return {
                            ...item,
                            isDateDropdownOpen:
                                !item.isDateDropdownOpen
                        };
                    }

                    return {
                        ...item,
                        isDateDropdownOpen:
                            false
                    };
                }
            );
    }

    handleExecutiveDateOptionClick(event) {
        event.stopPropagation();

        if (this.isSaving) {
            return;
        }

        const executiveId =
            event.currentTarget.dataset.execId;

        const selectedDate =
            event.currentTarget.dataset.date;

        const updatedExecutives =
            this.salesExecutiveOptions.map(
                item => {
                    if (
                        item.value !== executiveId
                    ) {
                        return item;
                    }

                    let dateAssignments =
                        this.cloneDateAssignments(
                            item.dateAssignments
                        );

                    const selectedDateExists =
                        dateAssignments.some(
                            assignment =>
                                assignment.targetDate ===
                                    selectedDate
                        );

                    if (selectedDateExists) {
                        dateAssignments =
                            dateAssignments.filter(
                                assignment =>
                                    assignment.targetDate !==
                                        selectedDate
                            );
                    } else {
                        dateAssignments.push(
                            this.newDateAssignment(
                                selectedDate
                            )
                        );
                    }

                    dateAssignments.sort(
                        (first, second) =>
                            first.targetDate
                                .localeCompare(
                                    second.targetDate
                                )
                    );

                    return {
                        ...item,
                        dateAssignments
                    };
                }
            );

        this.salesExecutiveOptions =
            this.reconcileSharedLocationAssignments(
                updatedExecutives
            );
    }

    handleRemoveExecutiveDate(event) {
        event.stopPropagation();

        if (this.isSaving) {
            return;
        }

        const executiveId =
            event.currentTarget.dataset.execId;

        const selectedDate =
            event.currentTarget.dataset.date;

        const updatedExecutives =
            this.salesExecutiveOptions.map(
                item => {
                    if (
                        item.value !== executiveId
                    ) {
                        return item;
                    }

                    const dateAssignments =
                        this.cloneDateAssignments(
                            item.dateAssignments
                        ).filter(
                            assignment =>
                                assignment.targetDate !==
                                    selectedDate
                        );

                    return {
                        ...item,
                        dateAssignments
                    };
                }
            );

        this.salesExecutiveOptions =
            this.reconcileSharedLocationAssignments(
                updatedExecutives
            );
    }

    handleDateLocationChange(event) {
        if (this.isSaving) {
            return;
        }

        const executiveId =
            event.currentTarget.dataset.execId;

        const targetDate =
            event.currentTarget.dataset.date;

        const activityLocation =
            (event.target.value || '').toUpperCase();

        event.target.value =
            activityLocation;

        const sourceExecutive =
            this.salesExecutiveOptions.find(
                item =>
                    item.value === executiveId
            );

        if (
            !sourceExecutive ||
            !sourceExecutive.selected ||
            !sourceExecutive.storeId ||
            !sourceExecutive.teamName
        ) {
            return;
        }

        const sourceAssignment =
            (
                sourceExecutive
                    .dateAssignments || []
            ).find(
                assignment =>
                    assignment.targetDate ===
                        targetDate
            );

        /*
         * Inherited rows are disabled in the UI.
         * This guard also prevents accidental programmatic edits.
         */
        if (
            sourceAssignment &&
            sourceAssignment.isLocationInherited
        ) {
            return;
        }

        let sourceOrder =
            sourceAssignment &&
            Number(
                sourceAssignment
                    .locationSourceOrder
            ) > 0
                ? Number(
                    sourceAssignment
                        .locationSourceOrder
                )
                : this.nextLocationSourceOrder();

        const sourceTeamKey =
            this.normalizeTeamKey(
                sourceExecutive.teamName
            );

        this.salesExecutiveOptions =
            this.salesExecutiveOptions.map(
                item => {
                    if (
                        !item.selected ||
                        item.storeId !==
                            sourceExecutive.storeId ||
                        this.normalizeTeamKey(
                            item.teamName
                        ) !== sourceTeamKey
                    ) {
                        return item;
                    }

                    const dateAssignments =
                        this.cloneDateAssignments(
                            item.dateAssignments
                        ).map(assignment => {
                            if (
                                assignment.targetDate !==
                                    targetDate
                            ) {
                                return assignment;
                            }

                            return {
                                ...assignment,
                                activityLocation,
                                locationSourceExecutiveId:
                                    executiveId,
                                locationSourceOrder:
                                    sourceOrder,
                                isLocationInherited:
                                    item.value !==
                                        executiveId
                            };
                        });

                    return {
                        ...item,
                        dateAssignments
                    };
                }
            );
    }

    stopEvent(event) {
        event.stopPropagation();
    }

    normalizeSelectedExecutiveDates() {
        const normalizedExecutives =
            this.salesExecutiveOptions.map(
                item => {
                    if (!item.selected) {
                        return item;
                    }

                    let dateAssignments =
                        this.cloneDateAssignments(
                            item.dateAssignments
                        ).filter(assignment => {
                            const dateValue =
                                assignment.targetDate;

                            if (!dateValue) {
                                return false;
                            }

                            if (
                                this.activityDate &&
                                dateValue <
                                    this.activityDate
                            ) {
                                return false;
                            }

                            if (
                                this.activityEndDate &&
                                dateValue >
                                    this.activityEndDate
                            ) {
                                return false;
                            }

                            return true;
                        });

                    if (
                        dateAssignments.length === 0 &&
                        this.activityDate
                    ) {
                        dateAssignments = [
                            this.newDateAssignment(
                                this.activityDate
                            )
                        ];
                    }

                    dateAssignments.sort(
                        (first, second) =>
                            first.targetDate
                                .localeCompare(
                                    second.targetDate
                                )
                    );

                    return {
                        ...item,
                        dateAssignments
                    };
                }
            );

        this.salesExecutiveOptions =
            this.reconcileSharedLocationAssignments(
                normalizedExecutives
            );
    }

    getAssignedDateDisplay(executive) {
        const dateAssignments =
            executive.dateAssignments || [];

        if (dateAssignments.length === 0) {
            return 'Select Target Dates';
        }

        if (dateAssignments.length === 1) {
            return this.formatDateLabel(
                dateAssignments[0]
                    .targetDate
            );
        }

        return (
            `${dateAssignments.length} ` +
            `Dates Selected`
        );
    }

    getSelectedDatePills(executive) {
        const dateAssignments =
            executive.dateAssignments || [];

        return dateAssignments.map(
            assignment => ({
                label:
                    this.formatDateLabel(
                        assignment.targetDate
                    ),
                value:
                    assignment.targetDate
            })
        );
    }

    getDateAssignmentRows(executive) {
        const dateAssignments =
            executive.dateAssignments || [];

        return dateAssignments.map(
            assignment => ({
                key:
                    `${executive.value}-` +
                    `${assignment.targetDate}`,
                targetDate:
                    assignment.targetDate,
                targetDateLabel:
                    this.formatDateLabel(
                        assignment.targetDate
                    ),
                activityLocation:
                    assignment.activityLocation ||
                    '',
                isLocationInherited:
                    Boolean(
                        assignment
                            .isLocationInherited
                    ),
                isLocationDisabled:
                    this.isSaving ||
                    Boolean(
                        assignment
                            .isLocationInherited
                    )
            })
        );
    }

    buildDateOptionsForExecutive(executive) {
        const selectedDates =
            (
                executive.dateAssignments || []
            ).map(
                assignment =>
                    assignment.targetDate
            );

        return this.dateOptions.map(
            dateOption => {
                const isSelected =
                    selectedDates.includes(
                        dateOption.value
                    );

                return {
                    label:
                        dateOption.label,
                    value:
                        dateOption.value,
                    selected:
                        isSelected,
                    optionClass:
                        isSelected
                            ? 'dateOption ' +
                              'selectedDateOption'
                            : 'dateOption'
                };
            }
        );
    }

    validateStores() {
        if (
            !this.selectedStoreIds ||
            this.selectedStoreIds.length === 0
        ) {
            this.storeError =
                'Please select at least one ' +
                'Assigned Store.';

            return false;
        }

        this.storeError = '';
        return true;
    }

    validateDateRange() {
        const endDateInput =
            this.template.querySelector(
                '[data-id="activityEndDate"]'
            );

        if (!endDateInput) {
            return true;
        }

        if (
            this.activityDate &&
            this.activityEndDate &&
            this.activityEndDate <
                this.activityDate
        ) {
            endDateInput.setCustomValidity(
                'Activity End Date cannot be ' +
                'before Activity Start Date.'
            );
        } else {
            endDateInput.setCustomValidity('');
        }

        endDateInput.reportValidity();

        return endDateInput.checkValidity();
    }

    validateAssignments() {
        if (!this.hasTeams) {
            this.showToast(
                'Validation Error',
                'No Team records are available in ' +
                'Team Custom Metadata.',
                'error'
            );

            return false;
        }

        if (
            !this.selectedSalesExecutiveIds ||
            this.selectedSalesExecutiveIds
                .length === 0
        ) {
            this.showToast(
                'Validation Error',
                'Please select at least one ' +
                'Sales Executive.',
                'error'
            );

            return false;
        }

        const missingStoreNames = [];

        this.selectedStoreIds.forEach(
            storeId => {
                const hasExecutiveForStore =
                    this.salesExecutiveOptions.some(
                        executive =>
                            executive.storeId ===
                                storeId &&
                            executive.selected
                    );

                if (!hasExecutiveForStore) {
                    const store =
                        this.storeOptions.find(
                            item =>
                                item.value ===
                                storeId
                        );

                    missingStoreNames.push(
                        store
                            ? store.label
                            : storeId
                    );
                }
            }
        );

        if (missingStoreNames.length > 0) {
            this.showToast(
                'Validation Error',
                'Please select at least one ' +
                'Sales Executive for each ' +
                'selected Store. Missing: ' +
                missingStoreNames.join(', '),
                'error'
            );

            return false;
        }

        /*
         * Blank Team sections are allowed because adding
         * additional Teams is optional.
         *
         * However, when a Team is selected in a section,
         * at least one Executive must be selected for it.
         */
        const teamSectionsWithoutExecutives = [];

        this.selectedStoreIds.forEach(
            storeId => {
                const store =
                    this.storeOptions.find(
                        item =>
                            item.value === storeId
                    );

                const sections =
                    this.teamSectionsByStoreId[
                        storeId
                    ] || [];

                sections.forEach(section => {
                    if (!section.teamName) {
                        return;
                    }

                    const hasExecutive =
                        this.salesExecutiveOptions.some(
                            executive =>
                                executive.storeId ===
                                    storeId &&
                                executive.selected &&
                                executive.teamSectionId ===
                                    section.id
                        );

                    if (!hasExecutive) {
                        teamSectionsWithoutExecutives.push(
                            `${store
                                ? store.label
                                : storeId} - ` +
                            `${section.teamName}`
                        );
                    }
                });
            }
        );

        if (
            teamSectionsWithoutExecutives.length > 0
        ) {
            this.showToast(
                'Validation Error',
                'Please select at least one ' +
                'Sales Executive for: ' +
                teamSectionsWithoutExecutives
                    .join(', '),
                'error'
            );

            return false;
        }

        const missingTeamExecutives = [];
        const missingDateExecutives = [];
        const invalidDateExecutives = [];
        const missingLocationRows = [];

        this.salesExecutiveOptions.forEach(
            executive => {
                if (!executive.selected) {
                    return;
                }

                if (!executive.teamName) {
                    missingTeamExecutives.push(
                        executive.label
                    );
                }

                const dateAssignments =
                    executive.dateAssignments || [];

                if (
                    dateAssignments.length === 0
                ) {
                    missingDateExecutives.push(
                        executive.label
                    );

                    return;
                }

                const hasInvalidDate =
                    dateAssignments.some(
                        assignment => {
                            const dateValue =
                                assignment
                                    .targetDate;

                            return Boolean(
                                this.activityDate &&
                                this.activityEndDate &&
                                (
                                    dateValue <
                                        this.activityDate ||
                                    dateValue >
                                        this.activityEndDate
                                )
                            );
                        }
                    );

                if (hasInvalidDate) {
                    invalidDateExecutives.push(
                        executive.label
                    );
                }

                dateAssignments.forEach(
                    assignment => {
                        if (
                            !assignment
                                .activityLocation ||
                            !assignment
                                .activityLocation
                                .trim()
                        ) {
                            missingLocationRows.push(
                                `${executive.label} - ` +
                                `${this.formatDateLabel(
                                    assignment
                                        .targetDate
                                )}`
                            );
                        }
                    }
                );
            }
        );

        if (
            missingTeamExecutives.length > 0
        ) {
            this.showToast(
                'Validation Error',
                'Please select Team for: ' +
                missingTeamExecutives.join(', '),
                'error'
            );

            return false;
        }

        if (
            missingDateExecutives.length > 0
        ) {
            this.showToast(
                'Validation Error',
                'Please select Target Date(s) ' +
                'for: ' +
                missingDateExecutives.join(', '),
                'error'
            );

            return false;
        }

        if (
            invalidDateExecutives.length > 0
        ) {
            this.showToast(
                'Validation Error',
                'Target Date(s) must be between ' +
                'Activity Start Date and Activity ' +
                'End Date for: ' +
                invalidDateExecutives.join(', '),
                'error'
            );

            return false;
        }

        if (missingLocationRows.length > 0) {
            const firstFiveRows =
                missingLocationRows.slice(0, 5);

            const remainingCount =
                missingLocationRows.length -
                firstFiveRows.length;

            const remainingText =
                remainingCount > 0
                    ? ` and ${remainingCount} more`
                    : '';

            this.showToast(
                'Validation Error',
                'Please enter Activity Location ' +
                'for: ' +
                firstFiveRows.join(', ') +
                remainingText,
                'error'
            );

            return false;
        }

        return true;
    }

    getSalesExecutiveAssignments() {
        return this.salesExecutiveOptions
            .filter(item => item.selected)
            .map(item => ({
                salesExecutiveId:
                    item.value,
                teamName:
                    item.teamName,
                dateAssignments:
                    this.cloneDateAssignments(
                        item.dateAssignments
                    ).map(assignment => ({
                        targetDate:
                            assignment.targetDate,
                        activityLocation:
                            assignment
                                .activityLocation ||
                            ''
                    }))
            }));
    }

    handleSave() {
        /*
         * Prevent multiple Apex calls from rapid
         * or repeated button clicks.
         */
        if (this.isSaving) {
            return;
        }

        const isStoreValid =
            this.validateStores();

        const isDateRangeValid =
            this.validateDateRange();

        const inputComponents = [
            ...this.template.querySelectorAll(
                'lightning-input, ' +
                'lightning-combobox'
            )
        ];

        const allValid =
            inputComponents.reduce(
                (
                    validSoFar,
                    inputComponent
                ) => {
                    inputComponent
                        .reportValidity();

                    return (
                        validSoFar &&
                        inputComponent
                            .checkValidity()
                    );
                },
                true
            );

        if (
            !allValid ||
            !isStoreValid ||
            !isDateRangeValid
        ) {
            return;
        }

        if (!this.validateAssignments()) {
            return;
        }

        /*
         * Set before calling Apex so the Save button
         * is disabled immediately.
         */
        this.isSaving = true;
        this.isLoading = true;
        this.isStoreDropdownOpen = false;

        createActivity({
            finalCustomizeFormId:
                this.recordId,
            assignedStoreIds:
                this.selectedStoreIds,
            activityName:
                this.activityName,
            activityDate:
                this.activityDate,
            activityEndDate:
                this.activityEndDate,
            salesExecutiveAssignments:
                this.getSalesExecutiveAssignments()
        })
            .then(result => {
                this.isLoading = false;

                const createdRecordIds =
                    this.extractCreatedRecordIds(
                        result
                    );

                const firstCreatedRecordId =
                    createdRecordIds.length > 0
                        ? createdRecordIds[0]
                        : null;

                this.showToast(
                    'Success',
                    'Activity records, Team ' +
                    'assignments, target dates and ' +
                    'date-wise locations were ' +
                    'created successfully.',
                    'success'
                );

                /*
                 * The launcher catches this event,
                 * closes the modal and navigates to
                 * the first created Form Activity.
                 */
                this.dispatchEvent(
                    new CustomEvent(
                        'activitycreated',
                        {
                            detail: {
                                recordId:
                                    firstCreatedRecordId,
                                createdRecordIds
                            },
                            bubbles: true,
                            composed: true
                        }
                    )
                );

                /*
                 * Retained for backward compatibility
                 * if the same child component is also
                 * opened as a Screen Quick Action.
                 */
                this.dispatchEvent(
                    new CloseActionScreenEvent()
                );
            })
            .catch(error => {
                this.isLoading = false;

                /*
                 * Enable Save again only when the
                 * Apex call fails.
                 */
                this.isSaving = false;

                this.showToast(
                    'Error',
                    this.getErrorMessage(error),
                    'error'
                );
            });
    }

    extractCreatedRecordIds(result) {
        if (Array.isArray(result)) {
            return result.filter(Boolean);
        }

        if (
            result &&
            Array.isArray(
                result.createdActivityIds
            )
        ) {
            return result.createdActivityIds
                .filter(Boolean);
        }

        if (
            result &&
            Array.isArray(result.recordIds)
        ) {
            return result.recordIds
                .filter(Boolean);
        }

        if (
            typeof result === 'string' &&
            result
        ) {
            return [result];
        }

        return [];
    }

    refreshSelectedExecutiveIds() {
        this.selectedSalesExecutiveIds =
            this.salesExecutiveOptions
                .filter(item => item.selected)
                .map(item => item.value);
    }

    newDateAssignment(targetDate) {
        return {
            targetDate,
            activityLocation: '',
            locationSourceExecutiveId: null,
            locationSourceOrder: null,
            isLocationInherited: false
        };
    }

    cloneDateAssignments(
        dateAssignments
    ) {
        return (
            dateAssignments || []
        ).map(assignment => ({
            targetDate:
                assignment.targetDate,
            activityLocation:
                assignment.activityLocation || '',
            locationSourceExecutiveId:
                assignment
                    .locationSourceExecutiveId ||
                null,
            locationSourceOrder:
                assignment
                    .locationSourceOrder ||
                null,
            isLocationInherited:
                Boolean(
                    assignment
                        .isLocationInherited
                )
        }));
    }

    nextLocationSourceOrder() {
        this.locationSourceCounter += 1;

        return this.locationSourceCounter;
    }

    normalizeTeamKey(teamName) {
        return (
            teamName || ''
        )
            .trim()
            .toLowerCase();
    }

    getLocationGroupKey(
        storeId,
        teamName,
        targetDate
    ) {
        return (
            `${storeId || ''}||` +
            `${this.normalizeTeamKey(
                teamName
            )}||` +
            `${targetDate || ''}`
        );
    }

    reconcileSharedLocationAssignments(
        executiveOptions
    ) {
        const reconciledExecutives =
            (
                executiveOptions || []
            ).map(executive => ({
                ...executive,
                dateAssignments:
                    this.cloneDateAssignments(
                        executive
                            .dateAssignments
                    )
            }));

        const groupMembersByKey =
            new Map();

        reconciledExecutives.forEach(
            (
                executive,
                executiveIndex
            ) => {
                if (
                    !executive.selected ||
                    !executive.storeId ||
                    !executive.teamName
                ) {
                    return;
                }

                (
                    executive
                        .dateAssignments || []
                ).forEach(
                    (
                        assignment,
                        assignmentIndex
                    ) => {
                        if (
                            !assignment.targetDate
                        ) {
                            return;
                        }

                        const groupKey =
                            this.getLocationGroupKey(
                                executive.storeId,
                                executive.teamName,
                                assignment
                                    .targetDate
                            );

                        if (
                            !groupMembersByKey
                                .has(groupKey)
                        ) {
                            groupMembersByKey.set(
                                groupKey,
                                []
                            );
                        }

                        groupMembersByKey
                            .get(groupKey)
                            .push({
                                executive,
                                assignment,
                                executiveIndex,
                                assignmentIndex
                            });
                    }
                );
            }
        );

        groupMembersByKey.forEach(
            members => {
                if (!members.length) {
                    return;
                }

                /*
                 * A valid source is the row that points to itself
                 * and is not inherited.
                 */
                let sourceCandidates =
                    members.filter(member =>
                        member.assignment
                            .locationSourceExecutiveId ===
                                member.executive.value &&
                        !member.assignment
                            .isLocationInherited
                    );

                sourceCandidates.sort(
                    (first, second) => {
                        const firstOrder =
                            Number(
                                first.assignment
                                    .locationSourceOrder
                            ) || Number.MAX_SAFE_INTEGER;

                        const secondOrder =
                            Number(
                                second.assignment
                                    .locationSourceOrder
                            ) || Number.MAX_SAFE_INTEGER;

                        if (
                            firstOrder !==
                            secondOrder
                        ) {
                            return (
                                firstOrder -
                                secondOrder
                            );
                        }

                        return (
                            first.executiveIndex -
                            second.executiveIndex
                        );
                    }
                );

                let sourceMember =
                    sourceCandidates.length > 0
                        ? sourceCandidates[0]
                        : null;

                /*
                 * Defensive recovery:
                 * if replicas still reference a source that is
                 * present in the group, restore that row as source.
                 */
                if (!sourceMember) {
                    const referencedSourceIds =
                        new Set(
                            members
                                .map(member =>
                                    member.assignment
                                        .locationSourceExecutiveId
                                )
                                .filter(Boolean)
                        );

                    sourceMember =
                        members.find(member =>
                            referencedSourceIds.has(
                                member.executive
                                    .value
                            )
                        ) || null;
                }

                const hadSourceReference =
                    members.some(member =>
                        Boolean(
                            member.assignment
                                .locationSourceExecutiveId
                        )
                    );

                /*
                 * If the former source was removed from this
                 * Store + Team + Date group, promote the first
                 * remaining row while preserving the location.
                 *
                 * If no source has ever been established and all
                 * rows are blank, leave every row editable until
                 * the first actual location entry is made.
                 */
                if (!sourceMember) {
                    const firstNonBlankMember =
                        members.find(member =>
                            Boolean(
                                (
                                    member.assignment
                                        .activityLocation ||
                                    ''
                                ).trim()
                            )
                        );

                    if (
                        firstNonBlankMember ||
                        hadSourceReference
                    ) {
                        sourceMember =
                            firstNonBlankMember ||
                            members[0];
                    }
                }

                if (!sourceMember) {
                    members.forEach(member => {
                        member.assignment
                            .locationSourceExecutiveId =
                            null;
                        member.assignment
                            .locationSourceOrder =
                            null;
                        member.assignment
                            .isLocationInherited =
                            false;
                    });

                    return;
                }

                let sourceOrder =
                    Number(
                        sourceMember.assignment
                            .locationSourceOrder
                    );

                if (
                    !sourceOrder ||
                    sourceOrder <= 0
                ) {
                    sourceOrder =
                        this.nextLocationSourceOrder();
                } else if (
                    sourceOrder >
                    this.locationSourceCounter
                ) {
                    this.locationSourceCounter =
                        sourceOrder;
                }

                const sourceExecutiveId =
                    sourceMember.executive.value;

                const sourceLocation =
                    sourceMember.assignment
                        .activityLocation || '';

                members.forEach(member => {
                    member.assignment
                        .activityLocation =
                        sourceLocation;

                    member.assignment
                        .locationSourceExecutiveId =
                        sourceExecutiveId;

                    member.assignment
                        .locationSourceOrder =
                        sourceOrder;

                    member.assignment
                        .isLocationInherited =
                        member.executive.value !==
                            sourceExecutiveId;
                });
            }
        );

        return reconciledExecutives;
    }

    parseDateString(dateString) {
        if (!dateString) {
            return null;
        }

        const parts =
            dateString.split('-');

        if (parts.length !== 3) {
            return null;
        }

        return new Date(
            Number(parts[0]),
            Number(parts[1]) - 1,
            Number(parts[2])
        );
    }

    formatDateValue(dateObject) {
        const year =
            dateObject.getFullYear();

        const month =
            String(
                dateObject.getMonth() + 1
            ).padStart(2, '0');

        const day =
            String(
                dateObject.getDate()
            ).padStart(2, '0');

        return `${year}-${month}-${day}`;
    }

    formatDateLabel(dateString) {
        const dateObject =
            this.parseDateString(dateString);

        if (!dateObject) {
            return dateString;
        }

        const months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec'
        ];

        const day =
            String(
                dateObject.getDate()
            ).padStart(2, '0');

        const month =
            months[
                dateObject.getMonth()
            ];

        const year =
            dateObject.getFullYear();

        return `${day}-${month}-${year}`;
    }

    handleCancel() {
        if (this.isSaving) {
            return;
        }

        /*
         * The custom launcher listens for this event
         * and navigates to Final_Customize_Form__c.
         */
        this.dispatchEvent(
            new CustomEvent(
                'activitycancel',
                {
                    detail: {
                        recordId: this.recordId
                    },
                    bubbles: true,
                    composed: true
                }
            )
        );

        /*
         * Retained for Screen Quick Action support.
         */
        this.dispatchEvent(
            new CloseActionScreenEvent()
        );
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    getErrorMessage(error) {
        if (
            error &&
            error.body &&
            error.body.message
        ) {
            return error.body.message;
        }

        if (
            error &&
            Array.isArray(error.body)
        ) {
            return error.body
                .map(item => item.message)
                .join(', ');
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Something went wrong.';
    }
}