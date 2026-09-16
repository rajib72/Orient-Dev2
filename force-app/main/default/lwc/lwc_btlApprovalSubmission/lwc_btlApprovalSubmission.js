import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';

import getSubmissionRows from '@salesforce/apex/Ctrl_BTLApprovalSubmission.getSubmissionRows';
import getApprovalOverview from '@salesforce/apex/Ctrl_BTLApprovalSubmission.getApprovalOverview';
import getApprovalPreview from '@salesforce/apex/Ctrl_BTLApprovalSubmission.getApprovalPreview';
import submitSelectedRecords from '@salesforce/apex/Ctrl_BTLApprovalSubmission.submitSelectedRecords';
import dropSelectedRecords from '@salesforce/apex/Ctrl_BTLApprovalSubmission.dropSelectedRecords';
import getEligibleManpower from '@salesforce/apex/Ctrl_BTLApprovalSubmission.getEligibleManpower';
import addReturnedManpower from '@salesforce/apex/Ctrl_BTLApprovalSubmission.addReturnedManpower';
import replaceReturnedManpower from '@salesforce/apex/Ctrl_BTLApprovalSubmission.replaceReturnedManpower';

export default class Lwc_btlApprovalSubmission extends LightningElement {
    _recordId;
    wiredRowsResult;

    rows = [];
    searchKey = '';
    statusFilter = 'Not Submitted';
    submissionComments = '';
    previewDropReason = '';
    collapsedGroupKeys = [];

    isLoading = true;
    isPreviewMode = false;
    errorMessage;

    previewRecordId;
    previewGroupKey;
    previewIsTeam = false;
    previewSummary = {};
    assignedPersonRows = [];
    supportingCards = [];
    previewWarnings = [];

    detailedSections = [];
    detailedFiles = [];
    isFullDetailsLoaded = false;
    showFullDetails = false;

    showManpowerPanel = false;
    manpowerMode;
    manpowerRows = [];
    manpowerSearchKey = '';
    selectedManpowerIds = [];
    manpowerChangeReason = '';

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        if (value && value !== this._recordId) {
            this._recordId = value;
        }
    }

    get panelTitle() {
        if (!this.isPreviewMode) {
            return 'Send BTL Activities for Approval';
        }

        return this.previewIsTeam
            ? 'Team Submission Preview'
            : 'Activity Submission Preview';
    }

    get statusOptions() {
        return [
            { label: 'All Records', value: 'All' },
            { label: 'Not Submitted', value: 'Not Submitted' },
            { label: 'Returned', value: 'Returned' },
            { label: 'Date Over', value: 'Date Over' }
        ];
    }

    get filteredRows() {
        const searchValue = (this.searchKey || '').trim().toLowerCase();

        return this.rows.filter((row) => {
            const rowStatus =
                row.isDateOver === true
                    ? 'Date Over'
                    : row.approvalStatus;

            const matchesStatus =
                this.statusFilter === 'All' ||
                rowStatus === this.statusFilter;

            if (!matchesStatus) {
                return false;
            }

            if (!searchValue) {
                return true;
            }

            return [
                row.activityNo,
                row.activityName,
                row.dateRecordNo,
                row.assignedPersonName,
                row.assignedPersonNo,
                row.storeName,
                row.executiveName,
                row.teamName,
                row.activityLocation,
                row.displayStatus,
                row.returnedFromLevel,
                row.submittedByName
            ]
                .filter(Boolean)
                .join(' ')
                .toLowerCase()
                .includes(searchValue);
        });
    }

    get filteredGroups() {
        return this.buildSubmissionGroups(this.filteredRows);
    }

    get hasRows() {
        return this.filteredGroups.length > 0;
    }

    get totalRows() {
        return this.rows.length;
    }

    get groupCount() {
        return this.buildSubmissionGroups(this.rows).length;
    }

    get selectedRows() {
        return this.rows.filter((row) => row.isSelected);
    }

    get selectedCount() {
        return this.selectedRows.length;
    }

    get notSubmittedCount() {
        return this.rows.filter(
            (row) =>
                row.isDateOver !== true &&
                row.approvalStatus === 'Not Submitted'
        ).length;
    }

    get returnedCount() {
        return this.rows.filter(
            (row) =>
                row.isDateOver !== true &&
                row.approvalStatus === 'Returned'
        ).length;
    }

    get dateOverCount() {
        return this.rows.filter(
            (row) => row.isDateOver === true
        ).length;
    }

    get dropEligibleCount() {
        return this.rows.filter((row) => row.canDrop).length;
    }

    get visibleSelectableCount() {
        return this.filteredRows.filter(
            (row) => !row.selectionDisabled
        ).length;
    }

    get disableSelectVisible() {
        return this.visibleSelectableCount === 0;
    }

    get allVisibleSelected() {
        const selectableRows = this.filteredRows.filter(
            (row) => !row.selectionDisabled
        );

        return (
            selectableRows.length > 0 &&
            selectableRows.every((row) => row.isSelected)
        );
    }

    get disableSubmit() {
        return this.isLoading || this.selectedCount === 0;
    }

    get canDropSelected() {
        return (
            this.selectedRows.length > 0 &&
            this.selectedRows.every(
                (row) => row.canDrop && row.transactionId
            )
        );
    }

    get showDropButton() {
        return this.canDropSelected;
    }

    get submitButtonLabel() {
        return this.getActionLabel('Submit', this.selectedRows);
    }

    get dropButtonLabel() {
        return this.getActionLabel('Drop', this.selectedRows);
    }

    get selectedActionMessage() {
        if (
            !this.selectedCount &&
            this.filteredRows.length > 0 &&
            this.visibleSelectableCount === 0
        ) {
            return 'These records are Date Over and are kept only for visibility. No further approval-related action is required.';
        }

        if (!this.selectedCount) {
            return 'Select an individual record or use Select Team to process a complete activity team.';
        }

        if (this.canDropSelected) {
            return `${this.selectedCount} record(s) selected. They can be resubmitted or permanently dropped.`;
        }

        return `${this.selectedCount} record(s) selected for submission or resubmission.`;
    }

    get hasWarnings() {
        return this.previewWarnings.length > 0;
    }

    get hasAssignedPersons() {
        return this.assignedPersonRows.length > 0;
    }

    get hasDetailedFiles() {
        return this.detailedFiles.length > 0;
    }

    get detailedFileCount() {
        return this.detailedFiles.length;
    }

    get detailButtonLabel() {
        return this.showFullDetails
            ? 'Hide Full Details'
            : 'View Full Details';
    }

    get detailButtonIcon() {
        return this.showFullDetails
            ? 'utility:chevronup'
            : 'utility:chevrondown';
    }

    get previewSelectedRows() {
        if (!this.previewGroupKey) {
            return [];
        }

        return this.rows.filter(
            (row) =>
                this.getGroupKey(row) === this.previewGroupKey &&
                row.isSelected
        );
    }

    get previewSubmitLabel() {
        return this.getActionLabel('Submit', this.previewSelectedRows);
    }

    get disablePreviewSubmit() {
        return this.isLoading || this.previewSelectedRows.length === 0;
    }

    get previewCanDrop() {
        return (
            this.previewSelectedRows.length > 0 &&
            this.previewSelectedRows.every(
                (row) => row.canDrop && row.transactionId
            )
        );
    }

    get previewDropLabel() {
        return this.getActionLabel('Drop', this.previewSelectedRows);
    }


    get previewGroupRows() {
        if (!this.previewGroupKey) {
            return [];
        }

        return this.rows.filter(
            (row) => this.getGroupKey(row) === this.previewGroupKey
        );
    }

    get canManageReturnedManpower() {
        return this.previewGroupRows.some((row) => row.canDrop);
    }

    get disableChangeManpower() {
        return !(
            this.previewSelectedRows.length === 1 &&
            this.previewSelectedRows[0].canDrop &&
            this.previewSelectedRows[0].transactionId
        );
    }

    get manpowerPanelTitle() {
        return this.manpowerMode === 'change'
            ? 'Change Manpower'
            : 'Add Manpower';
    }

    get isChangeManpowerMode() {
        return this.manpowerMode === 'change';
    }

    get filteredManpowerRows() {
        const searchValue = (this.manpowerSearchKey || '').trim().toLowerCase();
        if (!searchValue) {
            return this.manpowerRows;
        }

        return this.manpowerRows.filter((row) =>
            [row.executiveName, row.teamName, row.employeeCode, row.storeName]
                .filter(Boolean)
                .join(' ')
                .toLowerCase()
                .includes(searchValue)
        );
    }

    get hasManpowerRows() {
        return this.filteredManpowerRows.length > 0;
    }

    get selectedManpowerCount() {
        return this.selectedManpowerIds.length;
    }

    get disableSaveManpower() {
        if (this.isLoading) {
            return true;
        }

        if (this.isChangeManpowerMode) {
            return this.selectedManpowerIds.length !== 1;
        }

        return this.selectedManpowerIds.length === 0;
    }

    get manpowerSaveLabel() {
        if (this.isChangeManpowerMode) {
            return 'Replace Manpower';
        }

        return this.selectedManpowerIds.length > 1
            ? `Add Selected Manpower (${this.selectedManpowerIds.length})`
            : 'Add Manpower';
    }

    get approvalSummaryFields() {
        const summary = this.previewSummary || {};
        const fields = [
            {
                key: 'approvalStatus',
                label: 'Approval Status',
                value: this.displayValue(summary.approvalStatus)
            },
            {
                key: 'currentLevel',
                label: 'Current Approval Level',
                value: this.displayValue(summary.currentLevel)
            },
            {
                key: 'pendingWith',
                label: 'Pending With',
                value: this.displayValue(summary.pendingWith)
            },
            {
                key: 'submissionCycle',
                label: 'Submission Cycle',
                value: this.displayValue(summary.submissionCycle)
            },
            {
                key: 'submittedBy',
                label: 'Submitted By',
                value: this.displayValue(summary.submittedBy)
            },
            {
                key: 'submittedDateTime',
                label: 'Submitted Date & Time',
                value: this.formatDateTime(summary.submittedDateTime)
            },
            {
                key: 'returnedFromLevel',
                label: 'Returned From Level',
                value: this.displayValue(summary.returnedFromLevel)
            },
            {
                key: 'lastAction',
                label: 'Last Action',
                value: this.displayValue(summary.lastAction)
            }
        ];

        if (summary.approvalStatus === 'Dropped') {
            fields.push(
                {
                    key: 'droppedBy',
                    label: 'Dropped By',
                    value: this.displayValue(summary.droppedBy)
                },
                {
                    key: 'droppedDateTime',
                    label: 'Dropped Date & Time',
                    value: this.formatDateTime(summary.droppedDateTime)
                }
            );
        }

        return fields;
    }

    get activityOverviewFields() {
        const summary = this.previewSummary || {};

        return [
            {
                key: 'finalForm',
                label: 'Final Customize Form',
                value: this.displayValue(summary.finalCustomizeFormNo)
            },
            {
                key: 'activity',
                label: 'Form Activity',
                value: this.joinValues(summary.activityNo, summary.activityName)
            },
            {
                key: 'assignment',
                label: 'Selected Assignment',
                value: this.joinValues(
                    summary.assignedPersonDateNo,
                    summary.assignedPersonNo
                )
            },
            {
                key: 'person',
                label: 'Assigned Person / Executive',
                value: this.joinValues(
                    summary.assignedPersonName,
                    summary.executiveName
                )
            },
            {
                key: 'team',
                label: 'Team',
                value: this.displayValue(summary.teamName)
            },
            {
                key: 'store',
                label: 'Store',
                value: this.displayValue(summary.storeName)
            },
            {
                key: 'targetDate',
                label: 'Target Date',
                value: this.formatDate(summary.targetDate)
            },
            {
                key: 'actualDate',
                label: 'Actual Date',
                value: this.formatDate(summary.actualDate)
            },
            {
                key: 'location',
                label: 'Activity Location',
                value: this.displayValue(summary.activityLocation)
            },
            {
                key: 'attendance',
                label: 'Attendance',
                value: this.getAttendanceDisplay(summary)
            },
            {
                key: 'actualExecutive',
                label: 'Actual Executive',
                value: this.displayValue(summary.actualExecutiveName)
            },
            {
                key: 'attendanceMarkedBy',
                label: 'Attendance Marked By',
                value: this.displayValue(summary.attendanceMarkedBy)
            }
        ];
    }

    @wire(getSubmissionRows, { finalCustomizeFormId: '$_recordId' })
    wiredSubmissionRows(result) {
        this.wiredRowsResult = result;

        if (result.data) {
            this.rows = this.prepareSubmissionRows(result.data);
            this.errorMessage = undefined;
        } else if (result.error) {
            this.rows = [];
            this.errorMessage = this.reduceError(result.error);
        }

        this.isLoading = false;
    }

    prepareSubmissionRows(rows) {
        return (rows || []).map((row) => ({
            ...row,
            isSelected: false,
            selectionDisabled: !row.canSelect,
            formattedTargetDate: this.formatDate(row.targetDate),
            displayStatus:
                row.displayStatus || row.approvalStatus,
            statusClass:
                this.getStatusClass(
                    row.displayStatus || row.approvalStatus
                ),
            rowClass:
                row.isDateOver === true
                    ? 'submission-row date-over-row'
                    : 'submission-row'
        }));
    }

    buildSubmissionGroups(rows) {
        const groupMap = new Map();

        (rows || []).forEach((row) => {
            const groupKey = this.getGroupKey(row);

            if (!groupMap.has(groupKey)) {
                groupMap.set(groupKey, {
                    key: groupKey,
                    activityId: row.activityId,
                    activityNo: row.activityNo,
                    activityName: row.activityName,
                    storeName: row.storeName,
                    teamName: row.teamName,
                    activityLocation:
                        row.activityLocation || '—',
                    targetDate: row.targetDate,
                    formattedTargetDate: row.formattedTargetDate,
                    previewRecordId: row.dateRecordId,
                    rows: []
                });
            }

            groupMap.get(groupKey).rows.push(row);
        });

        return Array.from(groupMap.values()).map((group) => {
            const selectableRows = group.rows.filter(
                (row) => !row.selectionDisabled
            );
            const selectedRows = selectableRows.filter(
                (row) => row.isSelected
            );
            const notSubmittedCount = group.rows.filter(
                (row) =>
                    row.isDateOver !== true &&
                    row.approvalStatus === 'Not Submitted'
            ).length;
            const returnedCount = group.rows.filter(
                (row) =>
                    row.isDateOver !== true &&
                    row.approvalStatus === 'Returned'
            ).length;
            const dateOverCount = group.rows.filter(
                (row) => row.isDateOver === true
            ).length;
            const dropEligibleCount = group.rows.filter(
                (row) => row.canDrop
            ).length;
            const isExpanded = !this.collapsedGroupKeys.includes(group.key);

            return {
                ...group,
                rows: group.rows.map((row) => ({
                    ...row,
                    rowClass: row.isDateOver === true
                        ? 'submission-row date-over-row'
                        : row.isSelected
                            ? 'submission-row selected-submission-row'
                            : 'submission-row'
                })),
                assignedCount: group.rows.length,
                selectableCount: selectableRows.length,
                selectedCount: selectedRows.length,
                allSelected:
                    selectableRows.length > 0 &&
                    selectedRows.length === selectableRows.length,
                notSubmittedCount,
                returnedCount,
                dateOverCount,
                dropEligibleCount,
                hasNotSubmitted: notSubmittedCount > 0,
                hasReturned: returnedCount > 0,
                hasDateOver: dateOverCount > 0,
                hasDropEligible: dropEligibleCount > 0,
                disableGroupSelection: selectableRows.length === 0,
                cardClass:
                    dateOverCount === group.rows.length
                        ? 'activity-group-card date-over-group-card'
                        : 'activity-group-card',
                isExpanded,
                toggleIcon: isExpanded
                    ? 'utility:chevronup'
                    : 'utility:chevrondown',
                previewLabel:
                    group.rows.length > 1 ? 'Team Preview' : 'Preview'
            };
        });
    }

    handleSearch(event) {
        this.searchKey = event.target.value;
    }

    handleStatusFilter(event) {
        this.statusFilter = event.detail.value;
    }

    handleComments(event) {
        this.submissionComments = event.target.value;
    }

    handlePreviewDropReason(event) {
        this.previewDropReason = event.target.value;
    }

    handleRowSelection(event) {
        event.stopPropagation();
        const recordId = event.target.dataset.id;
        const checked = event.target.checked;
        this.setRowSelection(recordId, checked);
    }

    handleGroupSelection(event) {
        event.stopPropagation();
        const groupKey = event.target.dataset.key;
        const checked = event.target.checked;

        this.rows = this.rows.map((row) =>
            this.getGroupKey(row) === groupKey && !row.selectionDisabled
                ? { ...row, isSelected: checked }
                : row
        );

        this.syncPreviewSelectionState();
    }

    handleSelectAll(event) {
        const checked = event.target.checked;
        const visibleIds = new Set(
            this.filteredRows
                .filter((row) => !row.selectionDisabled)
                .map((row) => row.dateRecordId)
        );

        this.rows = this.rows.map((row) =>
            visibleIds.has(row.dateRecordId)
                ? { ...row, isSelected: checked }
                : row
        );

        this.syncPreviewSelectionState();
    }

    handleToggleGroup(event) {
        const groupKey = event.currentTarget.dataset.key;

        this.collapsedGroupKeys = this.collapsedGroupKeys.includes(groupKey)
            ? this.collapsedGroupKeys.filter((key) => key !== groupKey)
            : [...this.collapsedGroupKeys, groupKey];
    }

    async handlePreview(event) {
        const assignedPersonDateId = event.currentTarget.dataset.id;
        const groupKey = event.currentTarget.dataset.groupKey;
        const groupSize = Number(event.currentTarget.dataset.groupSize || 1);

        if (!assignedPersonDateId) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = undefined;
        this.resetPreviewState();
        this.previewRecordId = assignedPersonDateId;
        this.previewGroupKey = groupKey;
        this.previewIsTeam = groupSize > 1;

        const groupRows = this.rows.filter(
            (row) => this.getGroupKey(row) === groupKey
        );

        if (
            groupRows.length &&
            !groupRows.some((row) => row.isSelected)
        ) {
            this.rows = this.rows.map((row) =>
                this.getGroupKey(row) === groupKey && !row.selectionDisabled
                    ? { ...row, isSelected: true }
                    : row
            );
        }

        try {
            const result = await getApprovalOverview({
                assignedPersonDateId
            });

            this.prepareOverview(result);
            this.isPreviewMode = true;
        } catch (error) {
            this.errorMessage = this.reduceError(error);
            this.showToast('Preview Failed', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    prepareOverview(result) {
        const summary = result?.summary || {};

        const previewDateOver =
            this.previewGroupRows.some(
                (row) => row.isDateOver === true
            );

        const previewDisplayStatus = previewDateOver
            ? 'Date Over'
            : summary.approvalStatus;

        this.previewSummary = {
            ...summary,
            displayStatus: previewDisplayStatus,
            isDateOver: previewDateOver,
            formattedTargetDate: this.formatDate(summary.targetDate),
            statusClass: this.getStatusClass(previewDisplayStatus)
        };

        this.assignedPersonRows = (
            result?.assignedPersons || []
        ).map((row, index) => {
            const sourceRow = this.rows.find(
                (candidate) => candidate.dateRecordId === row.dateRecordId
            );
            const inPreviewGroup =
                sourceRow &&
                this.getGroupKey(sourceRow) === this.previewGroupKey;
            const isSelectable =
                Boolean(inPreviewGroup) &&
                !sourceRow.selectionDisabled;
            const isSelected =
                Boolean(inPreviewGroup) &&
                sourceRow.isSelected;

            return {
                ...row,
                key:
                    row.dateRecordId ||
                    row.assignedPersonId ||
                    `assignment-${index}`,
                displayName:
                    row.assignedPersonName ||
                    row.executiveName ||
                    row.assignedPersonNo ||
                    '—',
                formattedAssignedDate: this.formatDate(row.assignedDate),
                formattedTargetDate: this.formatDate(row.targetDate),
                formattedActualDate: this.formatDate(row.actualDate),
                attendanceDisplay: this.getAttendanceDisplay(row),
                displayStatus:
                    sourceRow?.isDateOver === true
                        ? 'Date Over'
                        : row.approvalStatus,
                statusClass: this.getStatusClass(
                    sourceRow?.isDateOver === true
                        ? 'Date Over'
                        : row.approvalStatus
                ),
                isSelectable,
                isSelected,
                selectionIcon: isSelected
                    ? 'utility:check'
                    : 'utility:add',
                selectionTitle: isSelectable
                    ? isSelected
                        ? 'Selected. Click to remove.'
                        : 'Click to select.'
                    : 'Not eligible for this submission group.',
                rowClass: isSelectable
                    ? isSelected
                        ? 'assigned-row selectable-assignment-row selected-assignment-row'
                        : 'assigned-row selectable-assignment-row'
                    : row.isSelectedRecord
                        ? 'assigned-row selected-assignment-row disabled-assignment-row'
                        : 'assigned-row disabled-assignment-row'
            };
        });

        this.supportingCards = this.buildSupportingCards(
            result?.supportingInfo || {}
        );
        this.previewWarnings = this.mapWarnings(result?.warnings || []);

        if (previewDateOver) {
            this.previewWarnings = this.mergeWarnings(
                this.previewWarnings,
                [
                    'The activity date has passed. This activity is Date Over and no submission, resubmission, drop, or manpower change is allowed.'
                ]
            );
        }
    }

    handlePreviewAssignmentClick(event) {
        const recordId = event.currentTarget.dataset.id;
        const row = this.assignedPersonRows.find(
            (item) => item.dateRecordId === recordId
        );

        if (!row?.isSelectable) {
            return;
        }

        this.setRowSelection(recordId, !row.isSelected);
    }

    setRowSelection(recordId, checked) {
        this.rows = this.rows.map((row) =>
            row.dateRecordId === recordId && !row.selectionDisabled
                ? { ...row, isSelected: checked }
                : row
        );
        this.syncPreviewSelectionState();
    }

    syncPreviewSelectionState() {
        if (!this.isPreviewMode || !this.assignedPersonRows.length) {
            return;
        }

        this.assignedPersonRows = this.assignedPersonRows.map((assignment) => {
            const sourceRow = this.rows.find(
                (row) => row.dateRecordId === assignment.dateRecordId
            );
            const isSelected = Boolean(sourceRow?.isSelected);

            return {
                ...assignment,
                isSelected,
                selectionIcon: isSelected
                    ? 'utility:check'
                    : 'utility:add',
                rowClass: assignment.isSelectable
                    ? isSelected
                        ? 'assigned-row selectable-assignment-row selected-assignment-row'
                        : 'assigned-row selectable-assignment-row'
                    : assignment.rowClass
            };
        });
    }


    async handleOpenAddManpower() {
        const referenceRow = this.previewGroupRows.find((row) => row.canDrop);
        if (!referenceRow) {
            this.showToast(
                'Returned Activity Required',
                'Manpower can be added only by the original submitter of a Returned activity.',
                'warning'
            );
            return;
        }

        await this.openManpowerPanel('add', referenceRow.dateRecordId);
    }

    async handleOpenChangeManpower() {
        if (this.disableChangeManpower) {
            this.showToast(
                'Select One Returned Manpower',
                'Keep exactly one returned manpower row selected before choosing Change Manpower.',
                'warning'
            );
            return;
        }

        await this.openManpowerPanel('change', this.previewSelectedRows[0].dateRecordId);
    }

    async openManpowerPanel(mode, assignedPersonDateId) {
        this.isLoading = true;
        this.manpowerMode = mode;
        this.manpowerRows = [];
        this.selectedManpowerIds = [];
        this.manpowerSearchKey = '';
        this.manpowerChangeReason = '';

        try {
            const result = await getEligibleManpower({ assignedPersonDateId });
            this.manpowerRows = (result || []).map((row) => ({
                ...row,
                isSelected: false,
                rowClass: 'manpower-option-row'
            }));
            this.showManpowerPanel = true;
        } catch (error) {
            this.showToast(
                'Unable to Load Manpower',
                this.reduceError(error),
                'error'
            );
            this.resetManpowerPanel();
        } finally {
            this.isLoading = false;
        }
    }

    handleManpowerSearch(event) {
        this.manpowerSearchKey = event.target.value;
    }

    handleManpowerReason(event) {
        this.manpowerChangeReason = event.target.value;
    }

    handleManpowerSelection(event) {
        event.stopPropagation();
        const executiveId = event.target.dataset.id;
        const checked = event.target.checked;
        this.setManpowerSelection(executiveId, checked);
    }

    handleManpowerRowClick(event) {
        const executiveId = event.currentTarget.dataset.id;
        const selected = this.selectedManpowerIds.includes(executiveId);
        this.setManpowerSelection(executiveId, !selected);
    }

    setManpowerSelection(executiveId, checked) {
        if (this.isChangeManpowerMode) {
            this.selectedManpowerIds = checked ? [executiveId] : [];
        } else if (checked) {
            this.selectedManpowerIds = Array.from(
                new Set([...this.selectedManpowerIds, executiveId])
            );
        } else {
            this.selectedManpowerIds = this.selectedManpowerIds.filter(
                (id) => id !== executiveId
            );
        }

        this.manpowerRows = this.manpowerRows.map((row) => {
            const isSelected = this.selectedManpowerIds.includes(row.executiveId);
            return {
                ...row,
                isSelected,
                rowClass: isSelected
                    ? 'manpower-option-row selected-manpower-option-row'
                    : 'manpower-option-row'
            };
        });
    }

    handleCloseManpowerPanel() {
        this.resetManpowerPanel();
    }

    async handleSaveManpower() {
        if (this.disableSaveManpower) {
            return;
        }

        const isReplacement = this.isChangeManpowerMode;

        this.isLoading = true;
        try {
            let result;

            if (isReplacement) {
                const selectedRow = this.previewSelectedRows[0];

                result = await replaceReturnedManpower({
                    taggedApprovalId: selectedRow.transactionId,
                    replacementExecutiveId: this.selectedManpowerIds[0],
                    changeReason: this.manpowerChangeReason?.trim() || null
                });
            } else {
                const referenceRow = this.previewGroupRows.find((row) => row.canDrop);

                result = await addReturnedManpower({
                    assignedPersonDateId: referenceRow.dateRecordId,
                    salesExecutiveIds: this.selectedManpowerIds
                });
            }

            this.showToast(
                'Manpower Updated',
                result?.message || 'Manpower was updated successfully.',
                'success'
            );

            this.resetManpowerPanel();
            await this.refreshSubmissionRows();

            if (isReplacement && result?.newAssignedPersonDateId) {
                const newDateRecordId = result.newAssignedPersonDateId;
                const replacementRow = this.rows.find(
                    (row) => row.dateRecordId === newDateRecordId
                );

                if (replacementRow) {
                    this.previewRecordId = newDateRecordId;
                    this.previewGroupKey = this.getGroupKey(replacementRow);

                    const groupRows = this.rows.filter(
                        (row) => this.getGroupKey(row) === this.previewGroupKey
                    );

                    this.previewIsTeam = groupRows.length > 1;

                    this.rows = this.rows.map((row) => ({
                        ...row,
                        isSelected: row.dateRecordId === newDateRecordId
                    }));

                    const overview = await getApprovalOverview({
                        assignedPersonDateId: newDateRecordId
                    });

                    this.prepareOverview(overview);
                    this.isPreviewMode = true;
                    return;
                }
            }

            this.isPreviewMode = false;
            this.resetPreviewState();
        } catch (error) {
            this.showToast(
                'Manpower Update Failed',
                this.reduceError(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    resetManpowerPanel() {
        this.showManpowerPanel = false;
        this.manpowerMode = undefined;
        this.manpowerRows = [];
        this.manpowerSearchKey = '';
        this.selectedManpowerIds = [];
        this.manpowerChangeReason = '';
    }

    async handleToggleFullDetails() {
        if (this.showFullDetails) {
            this.showFullDetails = false;
            return;
        }

        if (!this.isFullDetailsLoaded) {
            this.isLoading = true;

            try {
                const result = await getApprovalPreview({
                    assignedPersonDateId: this.previewRecordId
                });

                this.prepareDetailedPreview(result);
                this.isFullDetailsLoaded = true;
            } catch (error) {
                this.showToast(
                    'Unable to Load Full Details',
                    this.reduceError(error),
                    'error'
                );
                return;
            } finally {
                this.isLoading = false;
            }
        }

        this.showFullDetails = true;
    }

    prepareDetailedPreview(result) {
        this.detailedSections = this.prepareSections(
            result?.sections || []
        );
        this.detailedFiles = this.prepareFiles(result?.files || []);
        this.previewWarnings = this.mergeWarnings(
            this.previewWarnings,
            result?.warnings || []
        );
    }

    async handleSubmit() {
        await this.executeSubmit(this.selectedRows);
    }

    async handleSubmitFromPreview() {
        await this.executeSubmit(this.previewSelectedRows);
    }

    async executeSubmit(selectedRows) {
        const selectedIds = (selectedRows || []).map(
            (row) => row.dateRecordId
        );

        if (!selectedIds.length) {
            this.showToast(
                'Selection Required',
                'Select at least one activity.',
                'warning'
            );
            return;
        }

        this.isLoading = true;
        this.errorMessage = undefined;

        try {
            const result = await submitSelectedRecords({
                assignedPersonDateIds: selectedIds,
                comments: this.submissionComments?.trim() || null
            });

            this.showToast(
                'Success',
                result?.message ||
                    'Selected activities were sent for approval.',
                'success'
            );

            this.submissionComments = '';
            this.previewDropReason = '';
            this.isPreviewMode = false;
            this.resetPreviewState();
            await this.refreshSubmissionRows();
        } catch (error) {
            this.errorMessage = this.reduceError(error);
            this.showToast(
                'Submission Failed',
                this.errorMessage,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async handleDrop() {
        await this.executeDrop(
            this.selectedRows,
            this.submissionComments,
            false
        );
    }

    async handleDropFromPreview() {
        await this.executeDrop(
            this.previewSelectedRows,
            this.previewDropReason,
            true
        );
    }

    async executeDrop(selectedRows, reasonValue, isPreview) {
        const rowsToDrop = selectedRows || [];

        if (
            !rowsToDrop.length ||
            !rowsToDrop.every((row) => row.canDrop && row.transactionId)
        ) {
            this.showToast(
                'Drop Not Available',
                'Only Returned records can be dropped, and only by their original submitter.',
                'warning'
            );
            return;
        }

        const dropReason = reasonValue?.trim();
        if (!dropReason) {
            if (isPreview) {
                const dropReasonInput = this.template.querySelector(
                    '[data-id="previewDropReason"]'
                );

                if (dropReasonInput) {
                    dropReasonInput.reportValidity();
                }
            }

            this.showToast(
                'Drop Reason Required',
                'Enter a reason before dropping the selected activity records.',
                'warning'
            );
            return;
        }

        const confirmed = await LightningConfirm.open({
            label: 'Drop Returned Activity',
            theme: 'error',
            message:
                `${rowsToDrop.length} returned record(s) will be permanently dropped and cannot be resubmitted. Continue?`
        });

        if (!confirmed) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = undefined;

        try {
            const result = await dropSelectedRecords({
                taggedApprovalIds: rowsToDrop.map(
                    (row) => row.transactionId
                ),
                dropReason
            });

            this.showToast(
                'Activity Dropped',
                result?.message ||
                    'Selected returned activities were dropped.',
                'success'
            );

            this.submissionComments = '';
            this.previewDropReason = '';
            this.isPreviewMode = false;
            this.resetPreviewState();
            await this.refreshSubmissionRows();
        } catch (error) {
            this.errorMessage = this.reduceError(error);
            this.showToast(
                'Drop Failed',
                this.errorMessage,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleBackFromPreview() {
        this.isPreviewMode = false;
        this.resetPreviewState();
        this.errorMessage = undefined;
    }

    resetPreviewState() {
        this.previewRecordId = undefined;
        this.previewGroupKey = undefined;
        this.previewDropReason = '';
        this.previewIsTeam = false;
        this.previewSummary = {};
        this.assignedPersonRows = [];
        this.supportingCards = [];
        this.previewWarnings = [];
        this.detailedSections = [];
        this.detailedFiles = [];
        this.isFullDetailsLoaded = false;
        this.showFullDetails = false;
        this.resetManpowerPanel();
    }

    async handleRefresh() {
        await this.refreshSubmissionRows(true);
    }

    async refreshSubmissionRows(showSuccessToast = false) {
        if (!this.wiredRowsResult) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = undefined;

        try {
            await refreshApex(this.wiredRowsResult);

            if (showSuccessToast) {
                this.showToast(
                    'Refreshed',
                    'Eligible activities have been refreshed.',
                    'success'
                );
            }
        } catch (error) {
            this.errorMessage = this.reduceError(error);
            this.showToast('Refresh Failed', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    getActionLabel(action, selectedRows) {
        const rows = selectedRows || [];
        const count = rows.length;

        if (!count) {
            return `${action} Selected Records`;
        }

        if (count === 1) {
            return `${action} This Record`;
        }

        const groupKeys = new Set(
            rows.map((row) => this.getGroupKey(row))
        );

        if (groupKeys.size === 1) {
            const groupKey = Array.from(groupKeys)[0];
            const groupRows = this.rows.filter(
                (row) =>
                    this.getGroupKey(row) === groupKey &&
                    !row.selectionDisabled
            );

            if (groupRows.length === count) {
                return `${action} Full Team (${count})`;
            }

            return `${action} Selected Records (${count})`;
        }

        return `${action} Selected Activities (${count})`;
    }

    getGroupKey(row) {
        return [
            row.activityId || row.activityNo || '',
            row.storeId || row.storeName || '',
            row.teamName || '',
            row.targetDate || '',
            (row.activityLocation || '')
                .trim()
                .toLowerCase()
        ].join('|');
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    buildSupportingCards(info) {
        return [
            {
                key: 'assigned',
                label: 'Assigned Persons',
                value: info.assignedPersonCount || 0,
                icon: 'standard:people'
            },
            {
                key: 'schedule',
                label: 'Scheduled Dates',
                value: info.scheduleCount || 0,
                icon: 'standard:event'
            },
            {
                key: 'responses',
                label: 'Customer Responses',
                value: info.customerResponseCount || 0,
                icon: 'standard:feedback'
            },
            {
                key: 'answers',
                label: 'Recorded Answers',
                value: info.customerAnswerCount || 0,
                icon: 'utility:question'
            },
            {
                key: 'files',
                label: 'Files',
                value:
                    (info.fileCount || 0) +
                    (info.legacyAttachmentCount || 0),
                icon: 'standard:file'
            },
            {
                key: 'notes',
                label: 'Notes',
                value: info.noteCount || 0,
                icon: 'standard:note'
            }
        ];
    }

    prepareSections(sections) {
        return sections.map((section, sectionIndex) => {
            const records = (section.records || []).map(
                (record, recordIndex) => ({
                    ...record,
                    key:
                        record.id ||
                        `${sectionIndex}-${recordIndex}`,
                    fields: (record.fields || []).map(
                        (field, fieldIndex) => {
                            const displayValue =
                                field.value === null ||
                                field.value === undefined
                                    ? ''
                                    : String(field.value);

                            return {
                                ...field,
                                key:
                                    `${sectionIndex}-` +
                                    `${recordIndex}-` +
                                    `${field.apiName || fieldIndex}`,
                                displayValue,
                                hasValue:
                                    displayValue.trim().length > 0,
                                containerClass:
                                    this.getFieldContainerClass(
                                        field.dataType
                                    )
                            };
                        }
                    )
                })
            );

            return {
                ...section,
                key:
                    section.key ||
                    `section-${sectionIndex}`,
                records,
                recordCount: records.length,
                hasRecords: records.length > 0
            };
        });
    }

    prepareFiles(files) {
        return files.map((file, index) => ({
            ...file,
            key:
                file.contentDocumentId ||
                `file-${index}`,
            url:
                `/lightning/r/ContentDocument/` +
                `${file.contentDocumentId}/view`,
            formattedCreatedDate:
                this.formatDateTime(file.createdDate)
        }));
    }

    mapWarnings(warnings) {
        return warnings.map((warning, index) => ({
            key: `warning-${index}`,
            message: warning
        }));
    }

    mergeWarnings(existingWarnings, newWarnings) {
        const messages = new Set(
            (existingWarnings || []).map(
                (warning) => warning.message
            )
        );

        (newWarnings || []).forEach((warning) => {
            messages.add(warning);
        });

        return Array.from(messages).map((message, index) => ({
            key: `warning-${index}`,
            message
        }));
    }

    getAttendanceDisplay(record) {
        if (record?.present === true) {
            return record.attendanceStatus
                ? `Present • ${record.attendanceStatus}`
                : 'Present';
        }

        return record?.attendanceStatus || 'Not Marked';
    }

    joinValues(firstValue, secondValue) {
        const values = [firstValue, secondValue]
            .filter(
                (value) =>
                    value !== null &&
                    value !== undefined &&
                    String(value).trim() !== ''
            );

        return values.length ? values.join(' • ') : '—';
    }

    getStatusClass(status) {
        const value = (status || '').toLowerCase();

        if (value === 'approved') {
            return 'status-badge status-approved';
        }

        if (value === 'pending') {
            return 'status-badge status-pending';
        }

        if (value === 'returned') {
            return 'status-badge status-returned';
        }

        if (value === 'cancelled') {
            return 'status-badge status-cancelled';
        }

        if (value === 'dropped') {
            return 'status-badge status-dropped';
        }

        if (value === 'date over' || value === 'expired') {
            return 'status-badge status-date-over';
        }

        if (value === 'not submitted') {
            return 'status-badge status-not-submitted';
        }

        return 'status-badge status-neutral';
    }

    getFieldContainerClass(dataType) {
        const longTypes = [
            'TEXTAREA',
            'LONGTEXTAREA',
            'RICHTEXTAREA',
            'ADDRESS'
        ];

        return longTypes.includes(
            String(dataType || '').toUpperCase()
        )
            ? 'field-item field-item-full'
            : 'field-item';
    }

    formatDate(value) {
        if (!value) {
            return '—';
        }

        try {
            return new Intl.DateTimeFormat('en-IN', {
                day: '2-digit',
                month: 'short',
                year: 'numeric'
            }).format(new Date(`${value}T00:00:00`));
        } catch (error) {
            return String(value);
        }
    }

    formatDateTime(value) {
        if (!value) {
            return '—';
        }

        try {
            return new Intl.DateTimeFormat('en-IN', {
                day: '2-digit',
                month: 'short',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
                hour12: true
            }).format(new Date(value));
        } catch (error) {
            return String(value);
        }
    }

    displayValue(value) {
        return value === null ||
            value === undefined ||
            String(value).trim() === ''
                ? '—'
                : String(value);
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body
                .map((item) => item.message)
                .join(', ');
        }

        return (
            error?.body?.message ||
            error?.message ||
            'An unexpected error occurred.'
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
}