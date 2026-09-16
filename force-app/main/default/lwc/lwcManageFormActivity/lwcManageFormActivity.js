import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getFormActivities
    from '@salesforce/apex/Ctrl_ManageFormActivityController.getFormActivities';

import getActivityDetails
    from '@salesforce/apex/Ctrl_ManageFormActivityController.getActivityDetails';

import updateActivity
    from '@salesforce/apex/Ctrl_ManageFormActivityController.updateActivity';

import getTeams
    from '@salesforce/apex/Ctrl_CreateFormActivityController.getTeams';

import getSalesExecutivesByStores
    from '@salesforce/apex/Ctrl_CreateFormActivityController.getSalesExecutivesByStores';

export default class LwcManageFormActivity extends LightningElement {
    @api recordId;

    activityOptions = [];
    selectedActivityId;

    activityName;
    activityDate;
    activityEndDate;

    storeId;
    storeName;

    teamOptions = [];
    teamSections = [];
    teamSectionCounter = 0;

    salesExecutiveOptions = [];

    /*
     * Runtime-only source tracking for shared
     * Store + Team + Target Date locations.
     *
     * No Salesforce field is required for this.
     */
    locationSourceCounter = 0;
    dateAssignmentSequence = 0;

    hasLockedAssignments = false;
    activityEditLockMessage = '';
    isReturnedForCorrection = false;

    isLoading = false;
    isSaving = false;

    get hasActivities() {
        return this.activityOptions.length > 0;
    }

    get hasSelectedActivity() {
        return Boolean(this.selectedActivityId);
    }

    get selectedCount() {
        return this.salesExecutiveOptions.filter(
            executive => executive.selected
        ).length;
    }

    get isActivityPickerDisabled() {
        return this.isSaving || this.isLoading;
    }

    get isEditorDisabled() {
        return (
            this.isSaving ||
            this.isLoading
        );
    }

    get isUpdateDisabled() {
        return (
            this.isEditorDisabled ||
            !this.selectedActivityId
        );
    }

    get disableAddTeam() {
        return (
            this.isEditorDisabled ||
            this.teamOptions.length === 0 ||
            this.teamSections.length >=
                this.teamOptions.length
        );
    }

    get dateOptions() {
        const options = [];

        if (!this.activityDate || !this.activityEndDate) {
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
        let safetyCounter = 0;

        while (
            currentDate <= endDate &&
            safetyCounter < 366
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

            safetyCounter += 1;
        }

        return options;
    }

    get teamSectionsView() {
        return this.teamSections.map(
            (section, index) => {
                const sectionHasLockedAssignments =
                    this.salesExecutiveOptions.some(
                        executive =>
                            executive.selected &&
                            executive.teamSectionId ===
                                section.id &&
                            this.hasLockedDateAssignments(
                                executive
                            )
                    );

                const executives =
                    this.salesExecutiveOptions.map(
                        executive => {
                            const assignedToThisSection =
                                executive.selected &&
                                executive.teamSectionId ===
                                    section.id;

                            const assignedElsewhere =
                                executive.selected &&
                                executive.teamSectionId !==
                                    section.id;

                            const executiveHasLockedAssignments =
                                assignedToThisSection &&
                                this.hasLockedDateAssignments(
                                    executive
                                );

                            let cardClass =
                                assignedToThisSection
                                    ? 'executiveCard selectedCard'
                                    : 'executiveCard';

                            if (
                                assignedElsewhere ||
                                (
                                    !section.teamName &&
                                    !assignedToThisSection
                                )
                            ) {
                                cardClass += ' disabledCard';
                            }

                            const hasAssignedDates =
                                assignedToThisSection &&
                                executive
                                    .dateAssignments
                                    .length > 0;

                            let assignmentSubText =
                                'Sales Executive';

                            if (assignedToThisSection) {
                                const lockedCount =
                                    (
                                        executive
                                            .dateAssignments || []
                                    ).filter(
                                        dateAssignment =>
                                            dateAssignment
                                                .isEditLocked
                                    ).length;

                                assignmentSubText =
                                    `Team: ${executive.teamName}`;

                                if (lockedCount > 0) {
                                    assignmentSubText +=
                                        ` · ${lockedCount} locked date(s)`;
                                }
                            } else if (assignedElsewhere) {
                                assignmentSubText =
                                    `Already assigned to ${executive.teamName}`;
                            }

                            return {
                                ...executive,
                                selected:
                                    assignedToThisSection,
                                cardClass,
                                assignmentSubText,
                                hasLockedAssignments:
                                    executiveHasLockedAssignments,
                                hasAssignedDates,
                                assignedDateDisplay:
                                    this.getAssignedDateDisplay(
                                        executive
                                    ),
                                dateTextClass:
                                    hasAssignedDates
                                        ? 'selectedText'
                                        : 'placeholderText',
                                selectedDatePills:
                                    this.getSelectedDatePills(
                                        executive
                                    ),
                                dateAssignmentRows:
                                    this.getDateAssignmentRows(
                                        executive
                                    ),
                                dateOptions:
                                    this.buildDateOptions(
                                        executive
                                    )
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
                            section.id
                        ),
                    executives,
                    hasLockedAssignments:
                        sectionHasLockedAssignments,
                    isTeamLocked:
                        this.isEditorDisabled ||
                        sectionHasLockedAssignments,
                    canRemove:
                        !this.isEditorDisabled &&
                        !sectionHasLockedAssignments &&
                        this.teamSections.length > 1
                };
            }
        );
    }

    @wire(getFormActivities, {
        finalCustomizeFormId: '$recordId'
    })
    wiredActivities({ data, error }) {
        if (data) {
            this.activityOptions = data.map(
                activity => ({
                    label: activity.label,
                    value: activity.value
                })
            );
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
            this.teamOptions = data.map(team => ({
                label: team.label,
                value: team.value
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

    handleActivitySelectionChange(event) {
        if (this.isSaving) {
            return;
        }

        this.selectedActivityId =
            event.detail.value;

        this.hasLockedAssignments = false;
        this.activityEditLockMessage = '';
        this.isReturnedForCorrection = false;

        this.loadActivity();
    }

    loadActivity() {
        if (!this.selectedActivityId) {
            return;
        }

        this.isLoading = true;

        getActivityDetails({
            formActivityId:
                this.selectedActivityId
        })
            .then(activityDetails => {
                return getSalesExecutivesByStores({
                    storeIds: [
                        activityDetails.storeId
                    ]
                }).then(executives => ({
                    activityDetails,
                    executives
                }));
            })
            .then(result => {
                this.initializeEditor(
                    result.activityDetails,
                    result.executives
                );

                this.isLoading = false;
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

    initializeEditor(details, availableExecutives) {
        this.activityName =
            details.activityName;

        this.activityDate =
            details.activityDate;

        this.activityEndDate =
            details.activityEndDate;

        this.storeId =
            details.storeId;

        this.storeName =
            details.storeName;

        this.hasLockedAssignments =
            details.hasLockedAssignments === true;

        this.activityEditLockMessage =
            details.editLockMessage || '';

        this.isReturnedForCorrection =
            details.isReturnedForCorrection === true;

        this.teamSections = [];
        this.teamSectionCounter = 0;
        this.locationSourceCounter = 0;
        this.dateAssignmentSequence = 0;

        const sectionIdByTeamName =
            new Map();

        (details.assignments || []).forEach(
            assignment => {
                if (
                    assignment.teamName &&
                    !sectionIdByTeamName.has(
                        assignment.teamName
                    )
                ) {
                    const section =
                        this.createTeamSection(
                            assignment.teamName
                        );

                    this.teamSections.push(section);

                    sectionIdByTeamName.set(
                        assignment.teamName,
                        section.id
                    );
                }
            }
        );

        if (this.teamSections.length === 0) {
            this.teamSections = [
                this.createTeamSection('')
            ];
        }

        const assignmentByExecutiveId =
            new Map();

        (details.assignments || []).forEach(
            assignment => {
                assignmentByExecutiveId.set(
                    assignment.salesExecutiveId,
                    assignment
                );
            }
        );

        this.salesExecutiveOptions =
            (availableExecutives || []).map(
                executive => {
                    const assignment =
                        assignmentByExecutiveId.get(
                            executive.value
                        );

                    return this.buildExecutiveState(
                        executive.value,
                        executive.label,
                        assignment,
                        sectionIdByTeamName
                    );
                }
            );

        const availableExecutiveIds =
            new Set(
                this.salesExecutiveOptions.map(
                    executive => executive.value
                )
            );

        /*
         * Preserve an already-assigned executive even if the
         * normal Store lookup does not currently return it.
         */
        (details.assignments || []).forEach(
            assignment => {
                if (
                    !availableExecutiveIds.has(
                        assignment.salesExecutiveId
                    )
                ) {
                    this.salesExecutiveOptions.push(
                        this.buildExecutiveState(
                            assignment.salesExecutiveId,
                            assignment.salesExecutiveName,
                            assignment,
                            sectionIdByTeamName
                        )
                    );
                }
            }
        );

        /*
         * Database stores the location value, but not which
         * executive originally typed it.
         *
         * Therefore Manage Activity deterministically chooses
         * the first displayed executive in each
         * Store + Team + Target Date group as the editable
         * source. All later rows become replicas.
         *
         * If older data contains different locations inside
         * one group, the first displayed executive's value is
         * treated as canonical in the editor.
         */
        this.salesExecutiveOptions =
            this.initializeLoadedSharedLocationAssignments(
                this.salesExecutiveOptions
            );
    }

    buildExecutiveState(
        executiveId,
        executiveName,
        assignment,
        sectionIdByTeamName
    ) {
        return {
            value: executiveId,
            label: executiveName,
            initial: executiveName
                ? executiveName
                    .charAt(0)
                    .toUpperCase()
                : 'S',

            selected:
                Boolean(assignment),

            assignedPersonId:
                assignment
                    ? assignment.assignedPersonId
                    : null,

            teamName:
                assignment
                    ? assignment.teamName
                    : '',

            teamSectionId:
                assignment
                    ? sectionIdByTeamName.get(
                        assignment.teamName
                    )
                    : '',

            dateAssignments:
                assignment
                    ? (
                        assignment.dateAssignments ||
                        []
                    ).map(dateAssignment => ({
                        assignedPersonDateId:
                            dateAssignment
                                .assignedPersonDateId,
                        targetDate:
                            dateAssignment.targetDate,
                        activityLocation:
                            dateAssignment
                                .activityLocation || '',
                        locationSourceExecutiveId:
                            null,
                        locationSourceOrder:
                            null,
                        isLocationInherited:
                            false,
                        assignmentKey:
                            dateAssignment
                                .assignedPersonDateId
                                ? `existing-${dateAssignment.assignedPersonDateId}`
                                : this.nextDateAssignmentKey(),
                        sharedLocationGroupKey:
                            null,
                        isExistingLocationSplit:
                            false,
                        approvalStatus:
                            dateAssignment
                                .approvalStatus || '',
                        approvalLocked:
                            dateAssignment
                                .approvalLocked === true,
                        isEditLocked:
                            dateAssignment
                                .isEditLocked === true,
                        lockMessage:
                            dateAssignment
                                .lockMessage || '',
                        sharedLocationLocked:
                            false
                    }))
                    : [],

            isDateDropdownOpen: false
        };
    }

    hasLockedDateAssignments(executive) {
        return Boolean(
            executive &&
            (
                executive.dateAssignments || []
            ).some(
                dateAssignment =>
                    dateAssignment.isEditLocked ===
                        true
            )
        );
    }

    hasLockedDateInSection(sectionId) {
        return this.salesExecutiveOptions.some(
            executive =>
                executive.selected &&
                executive.teamSectionId ===
                    sectionId &&
                this.hasLockedDateAssignments(
                    executive
                )
        );
    }

    getLockedTargetDates() {
        const lockedDates = [];

        this.salesExecutiveOptions.forEach(
            executive => {
                if (!executive.selected) {
                    return;
                }

                (
                    executive.dateAssignments || []
                ).forEach(dateAssignment => {
                    if (
                        dateAssignment.isEditLocked &&
                        dateAssignment.targetDate
                    ) {
                        lockedDates.push(
                            dateAssignment.targetDate
                        );
                    }
                });
            }
        );

        return lockedDates;
    }

    createTeamSection(teamName) {
        this.teamSectionCounter += 1;

        return {
            id:
                `manage-team-${this.teamSectionCounter}`,
            teamName: teamName || ''
        };
    }

    getTeamOptionsForSection(sectionId) {
        const selectedTeamNames =
            new Set(
                this.teamSections
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
                selectedTeamNames.has(
                    option.value
                )
        }));
    }

    handleAddTeam() {
        if (this.disableAddTeam) {
            return;
        }

        this.teamSections = [
            ...this.teamSections,
            this.createTeamSection('')
        ];
    }

    handleRemoveTeam(event) {
        if (this.isEditorDisabled) {
            return;
        }

        const sectionId =
            event.currentTarget.dataset.sectionId;

        if (
            this.hasLockedDateInSection(
                sectionId
            )
        ) {
            this.showToast(
                'Team Locked',
                'This Team contains one or more Sales Executive Target Dates that are pending for approval or already approved. Those protected assignments must remain in the same Team.',
                'warning'
            );
            return;
        }

        if (this.teamSections.length <= 1) {
            return;
        }

        const updatedExecutives =
            this.salesExecutiveOptions.map(
                executive => {
                    if (
                        executive.teamSectionId ===
                        sectionId
                    ) {
                        return {
                            ...executive,
                            selected: false,
                            assignedPersonId: null,
                            teamName: '',
                            teamSectionId: '',
                            dateAssignments: [],
                            isDateDropdownOpen: false
                        };
                    }

                    return executive;
                }
            );

        this.teamSections =
            this.teamSections.filter(
                section =>
                    section.id !== sectionId
            );

        this.salesExecutiveOptions =
            this.reconcileSharedLocationAssignments(
                updatedExecutives
            );
    }

    handleTeamChange(event) {
        if (this.isEditorDisabled) {
            return;
        }

        const sectionId =
            event.currentTarget.dataset.sectionId;

        const selectedTeamName =
            event.detail.value;

        if (
            this.hasLockedDateInSection(
                sectionId
            )
        ) {
            this.showToast(
                'Team Locked',
                'The Team cannot be changed because it contains a Sales Executive Target Date that is pending for approval or already approved.',
                'warning'
            );

            this.teamSections = [
                ...this.teamSections
            ];

            return;
        }

        const duplicateExists =
            this.teamSections.some(
                section =>
                    section.id !== sectionId &&
                    section.teamName ===
                        selectedTeamName
            );

        if (duplicateExists) {
            this.showToast(
                'Validation Error',
                'The same Team cannot be selected twice.',
                'error'
            );

            this.teamSections = [
                ...this.teamSections
            ];

            return;
        }

        this.teamSections =
            this.teamSections.map(
                section => {
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
                }
            );

        const updatedExecutives =
            this.salesExecutiveOptions.map(
                executive => {
                    if (
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

    handleExecutiveCardClick(event) {
        if (this.isEditorDisabled) {
            return;
        }

        const executiveId =
            event.currentTarget.dataset.id;

        const sectionId =
            event.currentTarget.dataset.sectionId;

        const section =
            this.teamSections.find(
                item => item.id === sectionId
            );

        const executive =
            this.salesExecutiveOptions.find(
                item => item.value === executiveId
            );

        if (!section || !executive) {
            return;
        }

        const assignedElsewhere =
            executive.selected &&
            executive.teamSectionId !==
                sectionId;

        if (assignedElsewhere) {
            this.showToast(
                'Validation Error',
                `${executive.label} is already assigned to ${executive.teamName}.`,
                'error'
            );

            return;
        }

        const assignedToThisSection =
            executive.selected &&
            executive.teamSectionId ===
                sectionId;

        if (
            assignedToThisSection &&
            this.hasLockedDateAssignments(
                executive
            )
        ) {
            this.showToast(
                'Sales Executive Locked',
                `${executive.label} has one or more Target Dates that are pending for approval or already approved. The Sales Executive cannot be removed from this Team, but unlocked dates can still be managed.`,
                'warning'
            );
            return;
        }

        if (
            !assignedToThisSection &&
            !section.teamName
        ) {
            this.showToast(
                'Validation Error',
                'Please select a Team first.',
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

                    if (assignedToThisSection) {
                        return {
                            ...item,
                            selected: false,
                            assignedPersonId: null,
                            teamName: '',
                            teamSectionId: '',
                            dateAssignments: [],
                            isDateDropdownOpen: false
                        };
                    }

                    let dateAssignments =
                        this.cloneDateAssignments(
                            item.dateAssignments
                        );

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

                    return {
                        ...item,
                        selected: true,
                        teamName:
                            section.teamName,
                        teamSectionId:
                            sectionId,
                        dateAssignments,
                        isDateDropdownOpen: false
                    };
                }
            );

        this.salesExecutiveOptions =
            this.reconcileSharedLocationAssignments(
                updatedExecutives
            );
    }

    handleActivityNameChange(event) {
        if (this.isEditorDisabled) {
            return;
        }

        this.activityName =
            event.target.value;
    }

    handleActivityDateChange(event) {
        if (this.isEditorDisabled) {
            return;
        }

        const proposedStartDate =
            event.target.value;

        const blockedLockedDate =
            this.getLockedTargetDates()
                .find(
                    lockedDate =>
                        proposedStartDate &&
                        lockedDate <
                            proposedStartDate
                );

        if (blockedLockedDate) {
            event.target.value =
                this.activityDate;

            this.showToast(
                'Locked Target Date',
                `Activity Start Date cannot be moved after ${this.formatDateLabel(blockedLockedDate)} because that date contains a pending or approved Sales Executive assignment.`,
                'warning'
            );
            return;
        }

        this.activityDate =
            proposedStartDate;

        this.validateDateRange();
        this.normalizeDates();
    }

    handleActivityEndDateChange(event) {
        if (this.isEditorDisabled) {
            return;
        }

        const proposedEndDate =
            event.target.value;

        const blockedLockedDate =
            this.getLockedTargetDates()
                .find(
                    lockedDate =>
                        proposedEndDate &&
                        lockedDate >
                            proposedEndDate
                );

        if (blockedLockedDate) {
            event.target.value =
                this.activityEndDate;

            this.showToast(
                'Locked Target Date',
                `Activity End Date cannot be moved before ${this.formatDateLabel(blockedLockedDate)} because that date contains a pending or approved Sales Executive assignment.`,
                'warning'
            );
            return;
        }

        this.activityEndDate =
            proposedEndDate;

        this.validateDateRange();
        this.normalizeDates();
    }

    toggleExecutiveDateDropdown(event) {
        if (this.isEditorDisabled) {
            return;
        }

        event.stopPropagation();

        if (this.isSaving) {
            return;
        }

        const executiveId =
            event.currentTarget.dataset.id;

        this.salesExecutiveOptions =
            this.salesExecutiveOptions.map(
                executive => ({
                    ...executive,
                    isDateDropdownOpen:
                        executive.value === executiveId
                            ? !executive
                                .isDateDropdownOpen
                            : false
                })
            );
    }

    handleExecutiveDateOptionClick(event) {
        event.stopPropagation();

        if (this.isEditorDisabled) {
            return;
        }

        const executiveId =
            event.currentTarget.dataset.execId;

        const targetDate =
            event.currentTarget.dataset.date;

        const selectedExecutive =
            this.salesExecutiveOptions.find(
                executive =>
                    executive.value === executiveId
            );

        const matchingAssignments =
            selectedExecutive
                ? (
                    selectedExecutive.dateAssignments || []
                ).filter(
                    dateAssignment =>
                        dateAssignment.targetDate ===
                            targetDate
                )
                : [];

        if (
            matchingAssignments.length === 1 &&
            matchingAssignments[0].isEditLocked
        ) {
            this.showToast(
                'Target Date Locked',
                matchingAssignments[0].lockMessage ||
                    'This Target Date is pending for approval or already approved and cannot be removed.',
                'warning'
            );
            return;
        }

        if (matchingAssignments.length > 1) {
            this.showToast(
                'Location-wise Schedule',
                'This date contains multiple Activity Location groups created by Postpone/Prepone. Remove a specific date/location pill instead of clearing the complete date.',
                'warning'
            );
            return;
        }

        const existingAssignmentKey =
            matchingAssignments.length === 1
                ? matchingAssignments[0]
                    .assignmentKey
                : null;

        const updatedExecutives =
            this.salesExecutiveOptions.map(
                executive => {
                    if (
                        executive.value !== executiveId
                    ) {
                        return executive;
                    }

                    let dateAssignments =
                        this.cloneDateAssignments(
                            executive.dateAssignments
                        );

                    if (existingAssignmentKey) {
                        dateAssignments =
                            dateAssignments.filter(
                                dateAssignment =>
                                    dateAssignment
                                        .assignmentKey !==
                                    existingAssignmentKey
                            );
                    } else {
                        dateAssignments.push(
                            this.newDateAssignment(
                                targetDate
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
                        ...executive,
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

        if (this.isEditorDisabled) {
            return;
        }

        const executiveId =
            event.currentTarget.dataset.execId;

        const assignmentKey =
            event.currentTarget.dataset.assignmentKey;

        const selectedExecutive =
            this.salesExecutiveOptions.find(
                executive =>
                    executive.value === executiveId
            );

        const selectedAssignment =
            selectedExecutive
                ? (
                    selectedExecutive.dateAssignments ||
                    []
                ).find(
                    dateAssignment =>
                        dateAssignment.assignmentKey ===
                            assignmentKey
                )
                : null;

        if (
            selectedAssignment &&
            selectedAssignment.isEditLocked
        ) {
            this.showToast(
                'Target Date Locked',
                selectedAssignment.lockMessage ||
                    'This Target Date is pending for approval or already approved and cannot be removed.',
                'warning'
            );
            return;
        }

        const updatedExecutives =
            this.salesExecutiveOptions.map(
                executive => {
                    if (
                        executive.value !== executiveId
                    ) {
                        return executive;
                    }

                    return {
                        ...executive,
                        dateAssignments:
                            this.cloneDateAssignments(
                                executive.dateAssignments
                            ).filter(
                                dateAssignment =>
                                    dateAssignment
                                        .assignmentKey !==
                                    assignmentKey
                            )
                    };
                }
            );

        this.salesExecutiveOptions =
            this.reconcileSharedLocationAssignments(
                updatedExecutives
            );
    }

    handleDateLocationChange(event) {
        if (this.isEditorDisabled) {
            return;
        }

        const executiveId =
            event.currentTarget.dataset.execId;

        const assignmentKey =
            event.currentTarget.dataset.assignmentKey;

        const activityLocation =
            (event.target.value || '').toUpperCase();

        event.target.value =
            activityLocation;

        const sourceExecutive =
            this.salesExecutiveOptions.find(
                executive =>
                    executive.value === executiveId
            );

        if (
            !sourceExecutive ||
            !sourceExecutive.selected ||
            !sourceExecutive.teamName
        ) {
            return;
        }

        const sourceAssignment =
            (
                sourceExecutive.dateAssignments || []
            ).find(
                dateAssignment =>
                    dateAssignment.assignmentKey ===
                        assignmentKey
            );

        if (!sourceAssignment) {
            return;
        }

        /*
         * Replica rows are disabled in the template.
         * Keep this guard as a second line of protection.
         */
        if (
            sourceAssignment.isEditLocked ||
            sourceAssignment.sharedLocationLocked
        ) {
            this.showToast(
                'Activity Location Locked',
                sourceAssignment.lockMessage ||
                    'This Activity Location is shared with a pending or approved Target Date assignment and cannot be changed.',
                'warning'
            );
            return;
        }

        if (sourceAssignment.isLocationInherited) {
            return;
        }

        const sourceOrder =
            Number(
                sourceAssignment.locationSourceOrder
            ) > 0
                ? Number(
                    sourceAssignment.locationSourceOrder
                )
                : this.nextLocationSourceOrder();

        const sourceTeamKey =
            this.normalizeTeamKey(
                sourceExecutive.teamName
            );

        const sourceGroupKey =
            sourceAssignment.sharedLocationGroupKey ||
            this.getLocationGroupKey(
                sourceExecutive.teamName,
                sourceAssignment.targetDate
            );

        this.salesExecutiveOptions =
            this.salesExecutiveOptions.map(
                executive => {
                    if (
                        !executive.selected ||
                        this.normalizeTeamKey(
                            executive.teamName
                        ) !== sourceTeamKey
                    ) {
                        return executive;
                    }

                    const dateAssignments =
                        this.cloneDateAssignments(
                            executive.dateAssignments
                        ).map(dateAssignment => {
                            const assignmentGroupKey =
                                dateAssignment
                                    .sharedLocationGroupKey ||
                                this.getLocationGroupKey(
                                    executive.teamName,
                                    dateAssignment.targetDate
                                );

                            if (
                                assignmentGroupKey !==
                                sourceGroupKey
                            ) {
                                return dateAssignment;
                            }

                            return {
                                ...dateAssignment,
                                activityLocation,
                                locationSourceExecutiveId:
                                    executiveId,
                                locationSourceOrder:
                                    sourceOrder,
                                isLocationInherited:
                                    executive.value !==
                                        executiveId
                            };
                        });

                    return {
                        ...executive,
                        dateAssignments
                    };
                }
            );
    }

    normalizeDates() {
        const updatedExecutives =
            this.salesExecutiveOptions.map(
                executive => {
                    if (!executive.selected) {
                        return executive;
                    }

                    let validDates =
                        this.cloneDateAssignments(
                            executive.dateAssignments
                        ).filter(
                            dateAssignment => {
                                if (
                                    dateAssignment
                                        .isEditLocked
                                ) {
                                    return true;
                                }

                                if (
                                    this.activityDate &&
                                    dateAssignment
                                        .targetDate <
                                        this.activityDate
                                ) {
                                    return false;
                                }

                                if (
                                    this.activityEndDate &&
                                    dateAssignment
                                        .targetDate >
                                        this.activityEndDate
                                ) {
                                    return false;
                                }

                                return true;
                            }
                        );

                    if (
                        validDates.length === 0 &&
                        this.activityDate
                    ) {
                        validDates = [
                            this.newDateAssignment(
                                this.activityDate
                            )
                        ];
                    }

                    validDates.sort(
                        (first, second) =>
                            first.targetDate
                                .localeCompare(
                                    second.targetDate
                                )
                    );

                    return {
                        ...executive,
                        dateAssignments:
                            validDates
                    };
                }
            );

        this.salesExecutiveOptions =
            this.reconcileSharedLocationAssignments(
                updatedExecutives
            );
    }

    buildDateOptions(executive) {
        return this.dateOptions.map(option => {
            const matchingAssignments =
                (
                    executive.dateAssignments || []
                ).filter(
                    dateAssignment =>
                        dateAssignment.targetDate ===
                            option.value
                );

            const selected =
                matchingAssignments.length > 0;

            const locked =
                matchingAssignments.some(
                    dateAssignment =>
                        dateAssignment.isEditLocked
                );

            return {
                ...option,
                selected,
                locked,
                optionClass:
                    selected
                        ? 'dateOption selectedDateOption'
                        : 'dateOption'
            };
        });
    }

    getAssignedDateDisplay(executive) {
        const assignments =
            executive.dateAssignments || [];

        if (assignments.length === 0) {
            return 'Select Target Dates';
        }

        const uniqueDates =
            new Set(
                assignments.map(
                    dateAssignment =>
                        dateAssignment.targetDate
                )
            );

        if (
            assignments.length === 1 &&
            uniqueDates.size === 1
        ) {
            return this.formatDateLabel(
                assignments[0].targetDate
            );
        }

        if (
            assignments.length > uniqueDates.size
        ) {
            return (
                `${uniqueDates.size} Date(s) / ` +
                `${assignments.length} Location Group(s)`
            );
        }

        return `${uniqueDates.size} Dates Selected`;
    }

    getSelectedDatePills(executive) {
        const dateCounts = new Map();

        (executive.dateAssignments || []).forEach(
            dateAssignment => {
                dateCounts.set(
                    dateAssignment.targetDate,
                    (
                        dateCounts.get(
                            dateAssignment.targetDate
                        ) || 0
                    ) + 1
                );
            }
        );

        return (
            executive.dateAssignments || []
        ).map(dateAssignment => {
            const hasMultipleLocationGroups =
                (
                    dateCounts.get(
                        dateAssignment.targetDate
                    ) || 0
                ) > 1;

            return {
                label:
                    this.formatDateLabel(
                        dateAssignment.targetDate
                    ) +
                    (
                        hasMultipleLocationGroups
                            ? ` · ${dateAssignment.activityLocation || 'Location'}`
                            : ''
                    ),
                value:
                    dateAssignment.assignmentKey,
                targetDate:
                    dateAssignment.targetDate,
                assignmentKey:
                    dateAssignment.assignmentKey,
                isLocked:
                    Boolean(
                        dateAssignment.isEditLocked
                    ),
                isRemoveDisabled:
                    this.isEditorDisabled ||
                    Boolean(
                        dateAssignment.isEditLocked
                    ),
                lockMessage:
                    dateAssignment.lockMessage || ''
            };
        });
    }

    getDateAssignmentRows(executive) {
        return executive.dateAssignments.map(
            dateAssignment => {
                const isLocationGroupLocked =
                    Boolean(
                        dateAssignment
                            .sharedLocationLocked
                    );

                const isRowLocked =
                    Boolean(
                        dateAssignment
                            .isEditLocked
                    );

                return {
                    key:
                        `${executive.value}-${dateAssignment.assignmentKey}`,
                    assignmentKey:
                        dateAssignment.assignmentKey,
                    targetDate:
                        dateAssignment.targetDate,
                    targetDateLabel:
                        this.formatDateLabel(
                            dateAssignment.targetDate
                        ),
                    activityLocation:
                        dateAssignment.activityLocation || '',
                    approvalStatus:
                        dateAssignment.approvalStatus || '',
                    isEditLocked:
                        isRowLocked,
                    showLockIcon:
                        isRowLocked ||
                        isLocationGroupLocked,
                    lockMessage:
                        dateAssignment.lockMessage ||
                        (
                            isLocationGroupLocked
                                ? 'Activity Location is locked because another Sales Executive in the same Team and Target Date location group is pending for approval or already approved.'
                                : ''
                        ),
                    isLocationInherited:
                        Boolean(
                            dateAssignment.isLocationInherited
                        ),
                    isLocationDisabled:
                        this.isEditorDisabled ||
                        isRowLocked ||
                        isLocationGroupLocked ||
                        Boolean(
                            dateAssignment.isLocationInherited
                        )
                };
            }
        );
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
                'Activity End Date cannot be before Activity Start Date.'
            );
        } else {
            endDateInput.setCustomValidity('');
        }

        endDateInput.reportValidity();

        return endDateInput.checkValidity();
    }

    validateAssignments() {
        const selectedExecutives =
            this.salesExecutiveOptions.filter(
                executive =>
                    executive.selected
            );

        if (selectedExecutives.length === 0) {
            this.showToast(
                'Validation Error',
                'Please select at least one Sales Executive.',
                'error'
            );

            return false;
        }

        const emptySelectedTeams = [];

        this.teamSections.forEach(section => {
            if (!section.teamName) {
                return;
            }

            const hasExecutive =
                selectedExecutives.some(
                    executive =>
                        executive.teamSectionId ===
                        section.id
                );

            if (!hasExecutive) {
                emptySelectedTeams.push(
                    section.teamName
                );
            }
        });

        if (emptySelectedTeams.length > 0) {
            this.showToast(
                'Validation Error',
                'Please select at least one Sales Executive for: ' +
                emptySelectedTeams.join(', '),
                'error'
            );

            return false;
        }

        for (
            const executive of selectedExecutives
        ) {
            if (!executive.teamName) {
                this.showToast(
                    'Validation Error',
                    `Please select Team for ${executive.label}.`,
                    'error'
                );

                return false;
            }

            if (
                executive.dateAssignments.length ===
                0
            ) {
                this.showToast(
                    'Validation Error',
                    `Please select Target Date(s) for ${executive.label}.`,
                    'error'
                );

                return false;
            }

            for (
                const dateAssignment of
                executive.dateAssignments
            ) {
                if (
                    !dateAssignment
                        .activityLocation ||
                    !dateAssignment
                        .activityLocation
                        .trim()
                ) {
                    this.showToast(
                        'Validation Error',
                        `Please enter Activity Location for ${executive.label} - ${this.formatDateLabel(dateAssignment.targetDate)}.`,
                        'error'
                    );

                    return false;
                }
            }
        }

        return true;
    }

    handleUpdate() {
        if (this.isEditorDisabled) {
            return;
        }

        const allValid = [
            ...this.template.querySelectorAll(
                'lightning-input, lightning-combobox'
            )
        ].reduce(
            (valid, component) => {
                component.reportValidity();

                return (
                    valid &&
                    component.checkValidity()
                );
            },
            true
        );

        if (
            !allValid ||
            !this.validateDateRange() ||
            !this.validateAssignments()
        ) {
            return;
        }

        this.isSaving = true;
        this.isLoading = true;

        updateActivity({
            request: this.buildUpdateRequest()
        })
            .then(updatedActivityId => {
                this.isLoading = false;

                this.showToast(
                    'Success',
                    'Form Activity was updated successfully.',
                    'success'
                );

                this.dispatchEvent(
                    new CustomEvent(
                        'activityupdated',
                        {
                            detail: {
                                recordId:
                                    updatedActivityId
                            },
                            bubbles: true,
                            composed: true
                        }
                    )
                );

                this.dispatchEvent(
                    new CloseActionScreenEvent()
                );
            })
            .catch(error => {
                this.isLoading = false;
                this.isSaving = false;

                this.showToast(
                    'Error',
                    this.getErrorMessage(error),
                    'error'
                );
            });
    }

    buildUpdateRequest() {
        return {
            formActivityId:
                this.selectedActivityId,
            activityName:
                this.activityName,
            activityDate:
                this.activityDate,
            activityEndDate:
                this.activityEndDate,

            assignments:
                this.salesExecutiveOptions
                    .filter(
                        executive =>
                            executive.selected
                    )
                    .map(executive => ({
                        assignedPersonId:
                            executive
                                .assignedPersonId ||
                            null,

                        salesExecutiveId:
                            executive.value,

                        teamName:
                            executive.teamName,

                        dateAssignments:
                            executive
                                .dateAssignments
                                .map(
                                    dateAssignment => ({
                                        assignedPersonDateId:
                                            dateAssignment
                                                .assignedPersonDateId ||
                                            null,

                                        targetDate:
                                            dateAssignment
                                                .targetDate,

                                        activityLocation:
                                            dateAssignment
                                                .activityLocation
                                    })
                                )
                    }))
        };
    }

    handleCancel() {
        if (this.isSaving) {
            return;
        }

        this.dispatchEvent(
            new CustomEvent(
                'activitycancel',
                {
                    detail: {
                        recordId:
                            this.recordId
                    },
                    bubbles: true,
                    composed: true
                }
            )
        );

        this.dispatchEvent(
            new CloseActionScreenEvent()
        );
    }

    stopEvent(event) {
        event.stopPropagation();
    }


    nextDateAssignmentKey() {
        this.dateAssignmentSequence += 1;
        return `manage-date-${this.dateAssignmentSequence}`;
    }

    newDateAssignment(targetDate) {
        return {
            assignedPersonDateId: null,
            targetDate,
            activityLocation: '',
            locationSourceExecutiveId: null,
            locationSourceOrder: null,
            isLocationInherited: false,
            assignmentKey:
                this.nextDateAssignmentKey(),
            sharedLocationGroupKey: null,
            isExistingLocationSplit: false,
            approvalStatus: '',
            approvalLocked: false,
            isEditLocked: false,
            lockMessage: '',
            sharedLocationLocked: false
        };
    }

    cloneDateAssignments(dateAssignments) {
        return (dateAssignments || []).map(
            dateAssignment => ({
                assignedPersonDateId:
                    dateAssignment.assignedPersonDateId ||
                    null,
                targetDate:
                    dateAssignment.targetDate,
                activityLocation:
                    dateAssignment.activityLocation || '',
                locationSourceExecutiveId:
                    dateAssignment.locationSourceExecutiveId ||
                    null,
                locationSourceOrder:
                    dateAssignment.locationSourceOrder ||
                    null,
                isLocationInherited:
                    Boolean(
                        dateAssignment.isLocationInherited
                    ),
                assignmentKey:
                    dateAssignment.assignmentKey ||
                    (
                        dateAssignment.assignedPersonDateId
                            ? `existing-${dateAssignment.assignedPersonDateId}`
                            : this.nextDateAssignmentKey()
                    ),
                sharedLocationGroupKey:
                    dateAssignment.sharedLocationGroupKey ||
                    null,
                isExistingLocationSplit:
                    Boolean(
                        dateAssignment.isExistingLocationSplit
                    ),
                approvalStatus:
                    dateAssignment.approvalStatus || '',
                approvalLocked:
                    dateAssignment.approvalLocked === true,
                isEditLocked:
                    dateAssignment.isEditLocked === true,
                lockMessage:
                    dateAssignment.lockMessage || '',
                sharedLocationLocked:
                    dateAssignment.sharedLocationLocked === true
            })
        );
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

    normalizeLocationKey(activityLocation) {
        return (
            activityLocation || ''
        )
            .trim()
            .toLowerCase();
    }

    getLocationGroupKey(
        teamName,
        targetDate
    ) {
        return (
            `${this.storeId || ''}||` +
            `${this.normalizeTeamKey(
                teamName
            )}||` +
            `${targetDate || ''}`
        );
    }

    buildSharedLocationGroups(
        executiveOptions
    ) {
        const groupMembersByKey =
            new Map();

        (executiveOptions || []).forEach(
            (
                executive,
                executiveIndex
            ) => {
                if (
                    !executive.selected ||
                    !executive.teamName
                ) {
                    return;
                }

                (
                    executive.dateAssignments ||
                    []
                ).forEach(
                    (
                        dateAssignment,
                        assignmentIndex
                    ) => {
                        if (
                            !dateAssignment.targetDate
                        ) {
                            return;
                        }

                        const groupKey =
                            dateAssignment
                                .sharedLocationGroupKey ||
                            this.getLocationGroupKey(
                                executive.teamName,
                                dateAssignment.targetDate
                            );

                        if (
                            !groupMembersByKey.has(
                                groupKey
                            )
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
                                dateAssignment,
                                executiveIndex,
                                assignmentIndex
                            });
                    }
                );
            }
        );

        return groupMembersByKey;
    }

    initializeLoadedSharedLocationAssignments(
        executiveOptions
    ) {
        const initializedExecutives =
            (executiveOptions || []).map(
                executive => ({
                    ...executive,
                    dateAssignments:
                        this.cloneDateAssignments(
                            executive.dateAssignments
                        )
                })
            );

        /*
         * First group only by Store + Team + Date so we can
         * detect whether Postpone/Prepone has already produced
         * multiple legitimate location-wise execution groups on
         * the same date.
         */
        const baseGroups = new Map();

        initializedExecutives.forEach(
            (executive, executiveIndex) => {
                if (
                    !executive.selected ||
                    !executive.teamName
                ) {
                    return;
                }

                (
                    executive.dateAssignments || []
                ).forEach(
                    (dateAssignment, assignmentIndex) => {
                        const baseGroupKey =
                            this.getLocationGroupKey(
                                executive.teamName,
                                dateAssignment.targetDate
                            );

                        if (!baseGroups.has(baseGroupKey)) {
                            baseGroups.set(
                                baseGroupKey,
                                []
                            );
                        }

                        baseGroups.get(baseGroupKey).push({
                            executive,
                            dateAssignment,
                            executiveIndex,
                            assignmentIndex
                        });
                    }
                );
            }
        );

        baseGroups.forEach(
            (members, baseGroupKey) => {
                const membersByLocation = new Map();

                members.forEach(member => {
                    const locationKey =
                        this.normalizeLocationKey(
                            member.dateAssignment
                                .activityLocation
                        );

                    if (!membersByLocation.has(locationKey)) {
                        membersByLocation.set(
                            locationKey,
                            []
                        );
                    }

                    membersByLocation
                        .get(locationKey)
                        .push(member);
                });

                const isExistingLocationSplit =
                    membersByLocation.size > 1;

                membersByLocation.forEach(
                    (locationMembers, locationKey) => {
                        if (!locationMembers.length) {
                            return;
                        }

                        const sharedLocationLocked =
                            locationMembers.some(
                                member =>
                                    member.dateAssignment
                                        .isEditLocked ===
                                            true
                            );

                        const sourceMember =
                            locationMembers.find(
                                member =>
                                    member.dateAssignment
                                        .isEditLocked ===
                                            true
                            ) ||
                            locationMembers[0];

                        const sourceExecutiveId =
                            sourceMember.executive.value;

                        const sourceLocation =
                            sourceMember.dateAssignment
                                .activityLocation || '';

                        const sourceOrder =
                            this.nextLocationSourceOrder();

                        const sharedLocationGroupKey =
                            isExistingLocationSplit
                                ? (
                                    `${baseGroupKey}||` +
                                    `existing-location||${locationKey}`
                                )
                                : null;

                        locationMembers.forEach(member => {
                            member.dateAssignment
                                .activityLocation =
                                sourceLocation;

                            member.dateAssignment
                                .locationSourceExecutiveId =
                                sourceExecutiveId;

                            member.dateAssignment
                                .locationSourceOrder =
                                sourceOrder;

                            member.dateAssignment
                                .isLocationInherited =
                                member.executive.value !==
                                    sourceExecutiveId;

                            member.dateAssignment
                                .sharedLocationGroupKey =
                                sharedLocationGroupKey;

                            member.dateAssignment
                                .isExistingLocationSplit =
                                isExistingLocationSplit;

                            member.dateAssignment
                                .sharedLocationLocked =
                                sharedLocationLocked;
                        });
                    }
                );
            }
        );

        return initializedExecutives;
    }

    reconcileSharedLocationAssignments(
        executiveOptions
    ) {
        const reconciledExecutives =
            (executiveOptions || []).map(
                executive => ({
                    ...executive,
                    dateAssignments:
                        this.cloneDateAssignments(
                            executive
                                .dateAssignments
                        )
                })
            );

        const groupMembersByKey =
            this.buildSharedLocationGroups(
                reconciledExecutives
            );

        groupMembersByKey.forEach(
            members => {
                if (!members.length) {
                    return;
                }

                const sharedLocationLocked =
                    members.some(
                        member =>
                            member.dateAssignment
                                .isEditLocked ===
                                    true
                    );

                let sourceCandidates =
                    members.filter(member =>
                        member.dateAssignment
                            .locationSourceExecutiveId ===
                                member.executive.value &&
                        !member.dateAssignment
                            .isLocationInherited
                    );

                if (sharedLocationLocked) {
                    const lockedSourceCandidates =
                        sourceCandidates.filter(
                            member =>
                                member.dateAssignment
                                    .isEditLocked ===
                                        true
                        );

                    if (
                        lockedSourceCandidates.length > 0
                    ) {
                        sourceCandidates =
                            lockedSourceCandidates;
                    }
                }

                sourceCandidates.sort(
                    (first, second) => {
                        const firstOrder =
                            Number(
                                first.dateAssignment
                                    .locationSourceOrder
                            ) ||
                            Number.MAX_SAFE_INTEGER;

                        const secondOrder =
                            Number(
                                second.dateAssignment
                                    .locationSourceOrder
                            ) ||
                            Number.MAX_SAFE_INTEGER;

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
                 * Defensive recovery when a source row remains
                 * in the group but its inherited/source flags
                 * became stale after UI changes.
                 */
                if (!sourceMember) {
                    const referencedSourceIds =
                        new Set(
                            members
                                .map(member =>
                                    member.dateAssignment
                                        .locationSourceExecutiveId
                                )
                                .filter(Boolean)
                        );

                    sourceMember =
                        (
                            sharedLocationLocked
                                ? members.find(
                                    member =>
                                        member.dateAssignment
                                            .isEditLocked ===
                                                true &&
                                        referencedSourceIds.has(
                                            member.executive.value
                                        )
                                )
                                : null
                        ) ||
                        members.find(member =>
                            referencedSourceIds.has(
                                member.executive.value
                            )
                        ) ||
                        null;
                }

                const hadSourceReference =
                    members.some(member =>
                        Boolean(
                            member.dateAssignment
                                .locationSourceExecutiveId
                        )
                    );

                /*
                 * If the former source was removed, promote the
                 * first remaining non-blank row and preserve its
                 * location. If no location was ever entered,
                 * keep rows editable until the first actual
                 * location entry establishes the source.
                 */
                if (!sourceMember) {
                    const firstNonBlankMember =
                        (
                            sharedLocationLocked
                                ? members.find(
                                    member =>
                                        member.dateAssignment
                                            .isEditLocked ===
                                                true &&
                                        Boolean(
                                            (
                                                member.dateAssignment
                                                    .activityLocation ||
                                                ''
                                            ).trim()
                                        )
                                )
                                : null
                        ) ||
                        members.find(member =>
                            Boolean(
                                (
                                    member.dateAssignment
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
                        member.dateAssignment
                            .locationSourceExecutiveId =
                            null;

                        member.dateAssignment
                            .locationSourceOrder =
                            null;

                        member.dateAssignment
                            .isLocationInherited =
                            false;

                        member.dateAssignment
                            .sharedLocationLocked =
                            sharedLocationLocked;
                    });

                    return;
                }

                let sourceOrder =
                    Number(
                        sourceMember
                            .dateAssignment
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
                    sourceMember
                        .dateAssignment
                        .activityLocation || '';

                members.forEach(member => {
                    member.dateAssignment
                        .activityLocation =
                        sourceLocation;

                    member.dateAssignment
                        .locationSourceExecutiveId =
                        sourceExecutiveId;

                    member.dateAssignment
                        .locationSourceOrder =
                        sourceOrder;

                    member.dateAssignment
                        .isLocationInherited =
                        member.executive.value !==
                            sourceExecutiveId;

                    member.dateAssignment
                        .sharedLocationLocked =
                        sharedLocationLocked;
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
            'Jan', 'Feb', 'Mar', 'Apr',
            'May', 'Jun', 'Jul', 'Aug',
            'Sep', 'Oct', 'Nov', 'Dec'
        ];

        const day =
            String(
                dateObject.getDate()
            ).padStart(2, '0');

        return (
            `${day}-` +
            `${months[dateObject.getMonth()]}-` +
            `${dateObject.getFullYear()}`
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

        if (error && error.message) {
            return error.message;
        }

        return 'Something went wrong.';
    }
}