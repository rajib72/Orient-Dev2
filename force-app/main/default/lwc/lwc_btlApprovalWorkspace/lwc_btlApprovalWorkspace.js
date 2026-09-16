import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';

import getWorkspaceContext
    from '@salesforce/apex/Ctrl_BTLApprovalWorkspace.getWorkspaceContext';
import getPendingApprovals
    from '@salesforce/apex/Ctrl_BTLApprovalWorkspace.getPendingApprovals';
import getMySubmittedApprovals
    from '@salesforce/apex/Ctrl_BTLApprovalWorkspace.getMySubmittedApprovals';
import getActionedApprovals
    from '@salesforce/apex/Ctrl_BTLApprovalWorkspace.getActionedApprovals';
import getAdminApprovals
    from '@salesforce/apex/Ctrl_BTLApprovalWorkspace.getAdminApprovals';
import getApprovalOverview
    from '@salesforce/apex/Ctrl_BTLApprovalWorkspace.getApprovalOverview';
import getApprovalPreview
    from '@salesforce/apex/Ctrl_BTLApprovalWorkspace.getApprovalPreview';
import approveApproval
    from '@salesforce/apex/Ctrl_BTLApprovalWorkspace.approveApproval';
import approveTeamActivity
    from '@salesforce/apex/Ctrl_BTLApprovalWorkspace.approveTeamActivity';
import rejectApproval
    from '@salesforce/apex/Ctrl_BTLApprovalWorkspace.rejectApproval';
import rejectSelectedApprovals
    from '@salesforce/apex/Ctrl_BTLApprovalWorkspace.rejectSelectedApprovals';

export default class Lwc_btlApprovalWorkspace extends LightningElement {

    currentUserId;
    currentUserName;
    currentProfileName;
    isAdmin = false;

    directTransactionId;
    directPreviewOpened = false;

    wiredContextResult;
    wiredPendingResult;
    wiredSubmittedResult;
    wiredActionedResult;
    wiredAdminResult;

    contextLoaded = false;
    pendingLoaded = false;
    submittedLoaded = false;
    actionedLoaded = false;
    adminLoaded = false;

    pendingRows = [];
    submittedRows = [];
    actionedRows = [];
    adminRows = [];
    collapsedPendingGroupKeys = [];
    collapsedSubmittedGroupKeys = [];
    collapsedActionedGroupKeys = [];
    collapsedAdminGroupKeys = [];
    selectedPendingGroupKeys = [];
    selectedAdminGroupKeys = [];
    bulkActionComments = '';

    activeTab = 'pending';
    searchKey = '';
    adminStatusFilter = 'All';

    isLoading = true;
    isPreviewMode = false;
    errorMessage;

    previewTransactionId;
    isGroupPreview = false;
    previewGroupRows = [];
    previewGroupTransactionIds = [];
    previewSummary = {};
    assignedPersonRows = [];
    supportingCards = [];
    previewWarnings = [];

    detailedSections = [];
    detailedFiles = [];
    isFullDetailsLoaded = false;
    showFullDetails = false;

    actionContext = {};
    actionComments = '';
    forceReadOnlyPreview = false;

    get pendingCount() {
        return this.pendingRows.length;
    }

    get submittedCount() {
        return this.submittedRows.length;
    }

    get actionedCount() {
        return this.actionedRows.length;
    }

    get adminCount() {
        return this.adminRows.length;
    }

    get pendingTabLabel() {
        return `Pending Approvals (${this.pendingCount})`;
    }

    get submittedTabLabel() {
        return `My Submitted Approvals (${this.submittedCount})`;
    }

    get actionedTabLabel() {
        return `My Actioned Approvals (${this.actionedCount})`;
    }

    get adminTabLabel() {
        return `All Approvals (${this.adminCount})`;
    }

    get showAdminStatusFilter() {
        return this.isAdmin && this.activeTab === 'admin';
    }

    get adminStatusOptions() {
        return [
            { label: 'All Statuses', value: 'All' },
            { label: 'Pending', value: 'Pending' },
            { label: 'Returned', value: 'Returned' },
            { label: 'Approved', value: 'Approved' },
            { label: 'Dropped', value: 'Dropped' },
            { label: 'Date Over', value: 'Date Over' },
            { label: 'Cancelled', value: 'Cancelled' }
        ];
    }

    get filteredPendingRows() {
        return this.filterRows(this.pendingRows);
    }

    get filteredPendingGroups() {
        return this.buildApprovalGroups(this.filteredPendingRows, 'pending');
    }

    get filteredSubmittedRows() {
        return this.filterRows(this.submittedRows);
    }

    get filteredSubmittedGroups() {
        return this.buildApprovalGroups(this.filteredSubmittedRows, 'submitted');
    }

    get filteredActionedRows() {
        return this.filterRows(this.actionedRows);
    }

    get filteredActionedGroups() {
        return this.buildApprovalGroups(this.filteredActionedRows, 'actioned');
    }

    get filteredAdminRows() {
        return this.filterRows(
            this.adminRows,
            this.adminStatusFilter
        );
    }

    get filteredAdminGroups() {
        return this.buildApprovalGroups(this.filteredAdminRows, 'admin');
    }

    get hasPendingRows() {
        return this.filteredPendingGroups.length > 0;
    }

    get hasSubmittedRows() {
        return this.filteredSubmittedGroups.length > 0;
    }

    get hasActionedRows() {
        return this.filteredActionedGroups.length > 0;
    }

    get hasAdminRows() {
        return this.filteredAdminGroups.length > 0;
    }

    get hasPreviewWarnings() {
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

    get canApprove() {
        return !this.forceReadOnlyPreview && this.actionContext?.canApprove === true;
    }

    get canReject() {
        return !this.forceReadOnlyPreview && this.actionContext?.canReject === true;
    }

    get canAct() {
        if (this.isGroupPreview) {
            return this.selectablePreviewGroupCount > 0;
        }

        return this.canApprove || this.canReject;
    }

    get isReadOnlyPreview() {
        return this.isPreviewMode && !this.canAct;
    }

    get activeBulkGroups() {
        if (this.activeTab === 'admin') {
            return this.filteredAdminGroups.filter((group) => group.isBulkSelected);
        }

        return this.filteredPendingGroups.filter((group) => group.isBulkSelected);
    }

    get activeBulkTransactionIds() {
        const transactionIds = this.activeBulkGroups.flatMap((group) => group.actionableTransactionIds || []);
        return [...new Set(transactionIds)];
    }

    get selectedBulkActivityCount() {
        return this.activeBulkGroups.length;
    }

    get selectedBulkApprovalCount() {
        return this.activeBulkTransactionIds.length;
    }

    get showPendingBulkActionPanel() {
        return this.activeTab === 'pending' && this.selectedBulkActivityCount > 0;
    }

    get showAdminBulkActionPanel() {
        return this.activeTab === 'admin' && this.selectedBulkActivityCount > 0;
    }

    get bulkSelectionSummary() {
        const activityLabel = this.selectedBulkActivityCount === 1 ? 'activity' : 'activities';
        const approvalLabel = this.selectedBulkApprovalCount === 1 ? 'approval record' : 'approval records';
        return `${this.selectedBulkActivityCount} ${activityLabel} selected • ${this.selectedBulkApprovalCount} ${approvalLabel}`;
    }

    get bulkApproveLabel() {
        return this.selectedBulkActivityCount === 1
            ? 'Approve Selected Activity'
            : `Approve Selected Activities (${this.selectedBulkActivityCount})`;
    }

    get bulkRejectLabel() {
        return this.selectedBulkActivityCount === 1
            ? 'Reject Selected Activity'
            : `Reject Selected Activities (${this.selectedBulkActivityCount})`;
    }

    get hasPreviewGroupRows() {
        return this.previewGroupRows.length > 0;
    }

    get previewGroupCount() {
        return this.previewGroupRows.length;
    }

    get selectablePreviewGroupRows() {
        return this.previewGroupRows.filter((row) => row.isApprovalSelectable);
    }

    get selectedPreviewGroupRows() {
        return this.previewGroupRows.filter((row) => row.isSelected);
    }

    get selectedPreviewGroupTransactionIds() {
        return this.selectedPreviewGroupRows.map((row) => row.transactionId);
    }

    get selectedPreviewGroupCount() {
        return this.selectedPreviewGroupRows.length;
    }

    get selectablePreviewGroupCount() {
        return this.selectablePreviewGroupRows.length;
    }

    get allPreviewGroupRowsSelected() {
        return this.selectablePreviewGroupCount > 0 &&
            this.selectedPreviewGroupCount === this.selectablePreviewGroupCount;
    }

    get disablePreviewGroupSelectAll() {
        return this.selectablePreviewGroupCount === 0;
    }

    get canApproveFullTeam() {
        return this.isGroupPreview &&
            this.previewGroupRows.length > 1 &&
            this.previewGroupRows.every((row) => row.isApprovalSelectable);
    }

    get isFullTeamSelection() {
        return this.canApproveFullTeam &&
            this.selectedPreviewGroupCount === this.previewGroupRows.length;
    }

    get canApproveGroupSelection() {
        return this.isGroupPreview &&
            this.selectedPreviewGroupCount > 0 &&
            this.selectedPreviewGroupRows.every((row) => row.isApprovalSelectable);
    }

    get showStandardApproveButton() {
        return !this.isGroupPreview && this.canApprove;
    }

    get showGroupApproveButton() {
        return this.canApproveGroupSelection;
    }

    get groupApproveLabel() {
        if (this.isFullTeamSelection) {
            return `Approve Full Team (${this.selectedPreviewGroupCount})`;
        }

        if (this.selectedPreviewGroupCount === 1) {
            return 'Approve This Record';
        }

        return `Approve Selected Records (${this.selectedPreviewGroupCount})`;
    }

    get previewGroupSelectionSummary() {
        return `${this.selectedPreviewGroupCount} of ${this.selectablePreviewGroupCount} selected`;
    }

    get teamSelectionMessage() {
        if (this.selectablePreviewGroupCount === 0) {
            return 'No approval record in this team activity is currently available for your action.';
        }

        if (this.isFullTeamSelection) {
            return 'All eligible records are selected and can be approved or rejected together.';
        }

        if (this.selectedPreviewGroupCount === 1) {
            return 'One approval record is selected. Only this record will be processed.';
        }

        if (this.selectedPreviewGroupCount > 1) {
            return `${this.selectedPreviewGroupCount} approval records are selected. Only the selected records will be processed.`;
        }

        return 'Select at least one approval record to continue.';
    }

    get assignedPersonsSectionClass() {
        return this.isGroupPreview
            ? 'overview-section team-approval-section'
            : 'overview-section';
    }

    get assignedPersonSelectionHint() {
        return this.isGroupPreview
            ? `${this.previewGroupSelectionSummary} • Tap a row to select or deselect.`
            : 'The selected approval row is highlighted.';
    }

    get teamSelectionNoteClass() {
        return this.selectedPreviewGroupCount > 0
            ? 'team-selection-feedback'
            : 'team-selection-feedback team-selection-feedback-warning';
    }

    get teamSelectionNoteIcon() {
        return this.selectedPreviewGroupCount > 0
            ? 'utility:check'
            : 'utility:info';
    }

    get showStandardRejectButton() {
        return !this.isGroupPreview && this.canReject;
    }

    get canRejectGroupSelection() {
        return this.isGroupPreview &&
            this.selectedPreviewGroupCount > 0 &&
            this.selectedPreviewGroupRows.every((row) => row.isApprovalSelectable);
    }

    get showGroupRejectButton() {
        return this.canRejectGroupSelection;
    }

    get groupRejectLabel() {
        if (this.isFullTeamSelection) {
            return `Reject Full Team (${this.selectedPreviewGroupCount})`;
        }

        if (this.selectedPreviewGroupCount === 1) {
            return 'Reject This Record';
        }

        return `Reject Selected Records (${this.selectedPreviewGroupCount})`;
    }

    get approvalSummaryFields() {
        const summary = this.previewSummary || {};

        const fields = [
            {
                key: 'approvalStatus',
                label: 'Approval Status',
                value: this.displayValue(summary.approvalStatus),
                valueClass: summary.approvalStatus
                    ? `overview-value ${this.getStatusClass(summary.approvalStatus)}`
                    : 'overview-value'
            },
            {
                key: 'currentLevel',
                label: 'Current Approval Level',
                value: this.displayValue(summary.currentLevel),
                valueClass: 'overview-value'
            },
            {
                key: 'pendingWith',
                label: 'Pending With',
                value: this.displayValue(summary.pendingWith),
                valueClass: 'overview-value'
            },
            {
                key: 'returnedFromLevel',
                label: 'Returned From Level',
                value: this.displayValue(summary.returnedFromLevel),
                valueClass: 'overview-value'
            },
            {
                key: 'submissionCycle',
                label: 'Submission Cycle',
                value: this.displayValue(summary.submissionCycle),
                valueClass: 'overview-value'
            },
            {
                key: 'submittedBy',
                label: 'Submitted By',
                value: this.displayValue(summary.submittedBy),
                valueClass: 'overview-value'
            },
            {
                key: 'submittedDateTime',
                label: 'Submitted Date & Time',
                value: this.formatDateTime(summary.submittedDateTime),
                valueClass: 'overview-value'
            },
            {
                key: 'lastAction',
                label: 'Last Action',
                value: this.displayValue(summary.lastAction),
                valueClass: summary.lastAction
                    ? `overview-value ${this.getActionClass(summary.lastAction)}`
                    : 'overview-value'
            }
        ];

        if (summary.approvalStatus === 'Dropped') {
            fields.push(
                {
                    key: 'droppedBy',
                    label: 'Dropped By',
                    value: this.displayValue(summary.droppedBy),
                    valueClass: 'overview-value'
                },
                {
                    key: 'droppedDateTime',
                    label: 'Dropped Date & Time',
                    value: this.formatDateTime(summary.droppedDateTime),
                    valueClass: 'overview-value'
                },
                {
                    key: 'dropReason',
                    label: 'Drop Reason',
                    value: this.displayValue(summary.dropReason),
                    valueClass: 'overview-value'
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
                value: this.joinValues(
                    summary.activityNo,
                    summary.activityName
                )
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

    @wire(CurrentPageReference)
    wiredCurrentPageReference(pageReference) {
        const transactionId =
            pageReference?.state?.c__transactionId;

        if (!transactionId) {
            return;
        }

        if (transactionId !== this.directTransactionId) {
            this.directTransactionId = transactionId;
            this.directPreviewOpened = false;
        }

        this.tryOpenDirectPreview();
    }

    async tryOpenDirectPreview() {
        if (
            !this.contextLoaded ||
            !this.directTransactionId ||
            this.directPreviewOpened
        ) {
            return;
        }

        this.directPreviewOpened = true;

        await this.openPreview(
            this.directTransactionId,
            []
        );
    }

    @wire(getWorkspaceContext)
    wiredWorkspaceContext(result) {
        this.wiredContextResult = result;
        this.contextLoaded = true;

        if (result.data) {
            this.currentUserId = result.data.userId;
            this.currentUserName = result.data.userName;
            this.currentProfileName = result.data.profileName;
            this.isAdmin = result.data.isAdmin === true;
        } else if (result.error) {
            this.errorMessage = this.reduceError(result.error);
        }

        this.updateInitialLoading();
        this.tryOpenDirectPreview();
    }

    @wire(getPendingApprovals)
    wiredPendingApprovals(result) {
        this.wiredPendingResult = result;
        this.pendingLoaded = true;

        if (result.data) {
            this.pendingRows = this.prepareTransactionRows(result.data);
        } else if (result.error) {
            this.pendingRows = [];
            this.errorMessage = this.reduceError(result.error);
        }

        this.updateInitialLoading();
    }

    @wire(getMySubmittedApprovals)
    wiredSubmittedApprovals(result) {
        this.wiredSubmittedResult = result;
        this.submittedLoaded = true;

        if (result.data) {
            this.submittedRows = this.prepareTransactionRows(result.data);
        } else if (result.error) {
            this.submittedRows = [];
            this.errorMessage = this.reduceError(result.error);
        }

        this.updateInitialLoading();
    }

    @wire(getActionedApprovals)
    wiredActionedApprovals(result) {
        this.wiredActionedResult = result;
        this.actionedLoaded = true;

        if (result.data) {
            this.actionedRows = this.prepareActionedRows(result.data);
        } else if (result.error) {
            this.actionedRows = [];
            this.errorMessage = this.reduceError(result.error);
        }

        this.updateInitialLoading();
    }

    @wire(getAdminApprovals)
    wiredAdminApprovals(result) {
        this.wiredAdminResult = result;
        this.adminLoaded = true;

        if (result.data) {
            this.adminRows = this.prepareTransactionRows(result.data);
        } else if (result.error) {
            this.adminRows = [];
            this.errorMessage = this.reduceError(result.error);
        }

        this.updateInitialLoading();
    }

    updateInitialLoading() {
        if (
            this.contextLoaded &&
            this.pendingLoaded &&
            this.submittedLoaded &&
            this.actionedLoaded &&
            this.adminLoaded
        ) {
            this.isLoading = false;
        }
    }

    prepareTransactionRows(rows) {
        return rows.map((row) => ({
            ...row,
            groupKey: this.getGroupKey(row),
            transactionUrl: this.buildRecordUrl(row.transactionId),
            activityUrl: this.buildRecordUrl(row.activityId),
            dateRecordUrl: this.buildRecordUrl(row.assignedPersonDateId),
            finalFormUrl: this.buildRecordUrl(row.finalCustomizeFormId),
            formattedTargetDate: this.formatDate(row.targetDate),
            formattedSubmittedDateTime: this.formatDateTime(row.submittedDateTime),
            formattedLastActionDateTime: this.formatDateTime(row.lastActionDateTime),
            currentLevelDisplay: this.displayValue(row.currentLevel),
            pendingWithDisplay: this.displayValue(row.pendingWith),
            displayStatus: row.displayStatus || row.approvalStatus,
            statusClass: this.getStatusClass(
                row.displayStatus || row.approvalStatus
            ),
            lastActionClass: this.getActionClass(row.lastAction)
        }));
    }

    prepareActionedRows(rows) {
        return rows.map((row) => ({
            ...row,
            groupKey: this.getGroupKey(row),
            transactionUrl:
                this.buildRecordUrl(row.transactionId),
            activityUrl:
                this.buildRecordUrl(row.activityId),
            dateRecordUrl:
                this.buildRecordUrl(row.assignedPersonDateId),
            finalFormUrl:
                this.buildRecordUrl(row.finalCustomizeFormId),
            formattedTargetDate:
                this.formatDate(row.targetDate),
            formattedActionDateTime:
                this.formatDateTime(row.actionDateTime),
            formattedSubmittedDateTime:
                this.formatDateTime(row.submittedDateTime),
            currentLevelDisplay:
                this.displayValue(row.currentLevel),
            pendingWithDisplay:
                this.displayValue(row.pendingWith),
            displayStatus:
                row.displayStatus || row.approvalStatus,
            statusClass:
                this.getStatusClass(
                    row.displayStatus || row.approvalStatus
                ),
            actionClass:
                this.getActionClass(row.action)
        }));
    }

    filterRows(rows, statusFilter = 'All') {
        const normalizedSearch = (this.searchKey || '')
            .trim()
            .toLowerCase();

        return rows.filter((row) => {
            const rowStatus =
                row.displayStatus || row.approvalStatus;

            const matchesStatus =
                statusFilter === 'All' ||
                rowStatus === statusFilter;

            if (!matchesStatus) {
                return false;
            }

            if (!normalizedSearch) {
                return true;
            }

            return [
                row.transactionNo,
                row.finalCustomizeFormNo,
                row.activityNo,
                row.activityName,
                row.assignedPersonDateNo,
                row.storeName,
                row.executiveName,
                row.teamName,
                row.activityLocation,
                row.submittedBy,
                row.currentLevel,
                row.pendingWith,
                row.returnedFromLevel,
                row.displayStatus,
                row.approvalStatus,
                row.lastAction,
                row.action,
                row.actionLevel,
                row.assignedTo,
                row.comments
            ]
                .filter(Boolean)
                .join(' ')
                .toLowerCase()
                .includes(normalizedSearch);
        });
    }


    buildApprovalGroups(rows, source) {
        const groupsByKey = new Map();

        rows.forEach((row) => {
            const groupKey = row.groupKey || this.getGroupKey(row);

            if (!groupsByKey.has(groupKey)) {
                groupsByKey.set(groupKey, {
                    key: groupKey,
                    source,
                    finalCustomizeFormNo: row.finalCustomizeFormNo || '—',
                    finalFormUrl: row.finalFormUrl,
                    activityNo: row.activityNo || '—',
                    activityName: row.activityName || '—',
                    activityUrl: row.activityUrl,
                    storeName: row.storeName || '—',
                    teamName: row.teamName || '—',
                    activityLocation:
                        row.activityLocation || '—',
                    formattedTargetDate: row.formattedTargetDate || '—',
                    firstTransactionId: row.transactionId,
                    rows: []
                });
            }

            groupsByKey.get(groupKey).rows.push(row);
        });

        const collapsedKeys = source === 'pending'
            ? this.collapsedPendingGroupKeys
            : source === 'submitted'
                ? this.collapsedSubmittedGroupKeys
                : source === 'actioned'
                    ? this.collapsedActionedGroupKeys
                    : this.collapsedAdminGroupKeys;

        return Array.from(groupsByKey.values()).map((group) => {
            const uniquePeople = new Set();
            const statusCounts = {
                Pending: 0,
                Returned: 0,
                Approved: 0,
                'Date Over': 0,
                Dropped: 0,
                Cancelled: 0,
                Other: 0
            };

            group.rows.forEach((row) => {
                uniquePeople.add(
                    row.assignedPersonId ||
                    row.executiveName ||
                    row.assignedPersonDateId ||
                    row.transactionId
                );

                if (
                    Object.prototype.hasOwnProperty.call(
                        statusCounts,
                        row.displayStatus || row.approvalStatus
                    )
                ) {
                    statusCounts[
                        row.displayStatus || row.approvalStatus
                    ] += 1;
                } else {
                    statusCounts.Other += 1;
                }
            });

            const statusItems = [];

            [
                'Pending',
                'Returned',
                'Approved',
                'Date Over',
                'Dropped',
                'Cancelled'
            ].forEach((status) => {
                if (statusCounts[status] > 0) {
                    statusItems.push({
                        key: `${group.key}-${status}`,
                        label: `${statusCounts[status]} ${status}`,
                        className: `group-status-pill ${this.getStatusClass(status)}`
                    });
                }
            });

            if (statusCounts.Other > 0) {
                statusItems.push({
                    key: `${group.key}-Other`,
                    label: `${statusCounts.Other} Other`,
                    className: 'group-status-pill status-badge status-neutral'
                });
            }

            const memberRows = [...group.rows].sort((left, right) => {
                const leftName = left.executiveName || '';
                const rightName = right.executiveName || '';
                return leftName.localeCompare(rightName);
            });

            const isMultiPerson = uniquePeople.size > 1;
            const isExpanded = !collapsedKeys.includes(group.key);
            const selectedGroupKeys = source === 'pending'
                ? this.selectedPendingGroupKeys
                : source === 'admin'
                    ? this.selectedAdminGroupKeys
                    : [];
            const actionableRows = source === 'submitted' || source === 'actioned'
                ? []
                : memberRows.filter((row) =>
                row.isDateOver !== true &&
                row.approvalStatus === 'Pending' &&
                (
                    this.isAdmin ||
                    row.canApprove === true ||
                    row.pendingWithId === this.currentUserId
                )
            );
            const uniqueApprovalCount = new Set(
                memberRows.map((row) => row.transactionId)
            ).size;
            const approvalCount = source === 'actioned'
                ? uniqueApprovalCount
                : memberRows.length;
            const isBulkSelectable = actionableRows.length > 0;
            const isBulkSelected = isBulkSelectable && selectedGroupKeys.includes(group.key);

            return {
                ...group,
                rows: memberRows,
                peopleCount: uniquePeople.size,
                peopleLabel: uniquePeople.size === 1
                    ? '1 Assigned Person'
                    : `${uniquePeople.size} Assigned People`,
                approvalCount,
                approvalLabel: approvalCount === 1
                    ? '1 Approval Record'
                    : `${approvalCount} Approval Records`,
                previewLabel: isMultiPerson ? 'Team Preview' : 'Preview',
                isMultiPerson,
                transactionIds: memberRows.map((row) => row.transactionId),
                actionableTransactionIds: actionableRows.map((row) => row.transactionId),
                actionableCount: actionableRows.length,
                isBulkSelectable,
                isBulkSelected,
                bulkSelectionDisabled: !isBulkSelectable,
                bulkSelectionLabel: isBulkSelectable
                    ? `Select ${group.activityNo} for bulk action`
                    : `${group.activityNo} has no pending approval available for action`,
                cardClass: source === 'pending'
                    ? isBulkSelected
                        ? 'approval-group-card pending-group-card bulk-selected-group-card'
                        : 'approval-group-card pending-group-card'
                    : isBulkSelected
                        ? 'approval-group-card bulk-selected-group-card'
                        : 'approval-group-card',
                canApproveFullTeam: isMultiPerson && memberRows.every((row) =>
                    row.isDateOver !== true &&
                    row.approvalStatus === 'Pending' &&
                    (
                        this.isAdmin ||
                        row.canApprove === true ||
                        row.pendingWithId === this.currentUserId
                    )
                ),
                statusItems,
                isExpanded,
                toggleIcon: isExpanded
                    ? 'utility:chevronup'
                    : 'utility:chevrondown',
                toggleTitle: isExpanded
                    ? 'Collapse activity'
                    : 'Expand activity'
            };
        });
    }

    handleGroupToggle(event) {
        const groupKey = event.currentTarget.dataset.key;
        const source = event.currentTarget.dataset.source;

        if (!groupKey) {
            return;
        }

        const propertyName = source === 'pending'
            ? 'collapsedPendingGroupKeys'
            : source === 'submitted'
                ? 'collapsedSubmittedGroupKeys'
                : source === 'actioned'
                    ? 'collapsedActionedGroupKeys'
                    : 'collapsedAdminGroupKeys';

        const currentValues = this[propertyName];

        this[propertyName] = currentValues.includes(groupKey)
            ? currentValues.filter((key) => key !== groupKey)
            : [...currentValues, groupKey];
    }

    handleGroupBulkSelection(event) {
        const groupKey = event.currentTarget.dataset.key;
        const source = event.currentTarget.dataset.source;
        const checked = event.target.checked;

        if (!groupKey) {
            return;
        }

        const propertyName = source === 'admin'
            ? 'selectedAdminGroupKeys'
            : 'selectedPendingGroupKeys';
        const currentValues = this[propertyName];

        if (checked && !currentValues.includes(groupKey)) {
            this[propertyName] = [...currentValues, groupKey];
        } else if (!checked) {
            this[propertyName] = currentValues.filter((key) => key !== groupKey);
        }
    }

    handleBulkActionComments(event) {
        this.bulkActionComments = event.target.value;
    }

    handleClearBulkSelection() {
        if (this.activeTab === 'admin') {
            this.selectedAdminGroupKeys = [];
        } else {
            this.selectedPendingGroupKeys = [];
        }
        this.bulkActionComments = '';
    }

    clearAllBulkSelections() {
        this.selectedPendingGroupKeys = [];
        this.selectedAdminGroupKeys = [];
        this.bulkActionComments = '';
    }

    handleSearch(event) {
        this.searchKey = event.target.value;
    }

    handleAdminStatusFilter(event) {
        this.adminStatusFilter = event.detail.value;
    }

    handleTabActive(event) {
        this.activeTab = event.target.value;
        this.bulkActionComments = '';
    }

    handleActionComments(event) {
        this.actionComments = event.target.value;
    }

    async handleRefresh() {
        this.clearAllBulkSelections();
        await this.refreshWorkspaceData(true);
    }

    async refreshWorkspaceData(showSuccessToast = false) {
        this.isLoading = true;
        this.errorMessage = undefined;

        try {
            const refreshRequests = [
                this.wiredContextResult,
                this.wiredPendingResult,
                this.wiredSubmittedResult,
                this.wiredActionedResult,
                this.wiredAdminResult
            ]
                .filter(Boolean)
                .map((wireResult) => refreshApex(wireResult));

            await Promise.all(refreshRequests);

            if (showSuccessToast) {
                this.showToast('Refreshed', 'Approval data has been refreshed.', 'success');
            }
        } catch (error) {
            this.errorMessage = this.reduceError(error);
            this.showToast('Refresh Failed', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handlePreview(event) {
        const transactionId = event.currentTarget.dataset.id;
        const source = event.currentTarget.dataset.source;

        if (!transactionId) {
            return;
        }

        await this.openPreview(transactionId, [], source === 'submitted');
    }

    async handleGroupPreview(event) {
        const groupKey = event.currentTarget.dataset.key;
        const source = event.currentTarget.dataset.source;
        const selectedTransactionId = event.currentTarget.dataset.id;
        const sourceRows = source === 'admin'
            ? this.adminRows
            : source === 'submitted'
                ? this.submittedRows
                : source === 'actioned'
                    ? this.actionedRows
                    : this.pendingRows;
        const rawGroupRows = sourceRows.filter((row) => row.groupKey === groupKey);
        const groupRows = source === 'actioned'
            ? Array.from(new Map(rawGroupRows.map((row) => [row.transactionId, row])).values())
            : rawGroupRows;

        if (!groupRows.length) {
            this.showToast(
                'Preview Failed',
                'No approval record was found for this activity.',
                'error'
            );
            return;
        }

        const actionableRow = groupRows.find((row) =>
            row.approvalStatus === 'Pending' &&
            (this.isAdmin || row.canApprove === true || row.pendingWithId === this.currentUserId)
        );
        const primaryTransactionId = actionableRow?.transactionId || selectedTransactionId || groupRows[0].transactionId;
        const previewRows = groupRows.length > 1 ? groupRows : [];
        await this.openPreview(
            primaryTransactionId,
            previewRows,
            source === 'submitted'
        );
    }

    handleAssignedPersonSelection(event) {
        const transactionId =
            event.currentTarget.dataset.transactionId;

        this.toggleAssignedPersonSelection(transactionId);
    }

    handleAssignedPersonKeydown(event) {
        if (event.key !== 'Enter' && event.key !== ' ') {
            return;
        }

        event.preventDefault();

        const transactionId =
            event.currentTarget.dataset.transactionId;

        this.toggleAssignedPersonSelection(transactionId);
    }

    toggleAssignedPersonSelection(transactionId) {
        if (!this.isGroupPreview || !transactionId) {
            return;
        }

        let selectionChanged = false;

        this.previewGroupRows = this.previewGroupRows.map((row) => {
            if (
                row.transactionId !== transactionId ||
                row.selectionDisabled
            ) {
                return row;
            }

            selectionChanged = true;

            return {
                ...row,
                isSelected: !row.isSelected
            };
        });

        if (selectionChanged) {
            this.syncAssignedPersonSelection();
        }
    }

    syncAssignedPersonSelection() {
        const groupRowByDateId = new Map(
            this.previewGroupRows
                .filter((row) => row.assignedPersonDateId)
                .map((row) => [
                    row.assignedPersonDateId,
                    row
                ])
        );

        this.assignedPersonRows = this.assignedPersonRows.map(
            (assignment) => this.decorateAssignedPersonSelection(
                assignment,
                groupRowByDateId.get(assignment.dateRecordId)
            )
        );
    }

    decorateAssignedPersonSelection(assignment, groupRow) {
        if (!this.isGroupPreview) {
            return {
                ...assignment,
                transactionId: null,
                showSelectionMarker: false,
                showSelectedIcon: false,
                rowTabIndex: -1,
                selectionAriaLabel:
                    'Approval activity information'
            };
        }

        const isSelectable =
            groupRow?.isApprovalSelectable === true;

        const isSelected =
            isSelectable &&
            groupRow?.isSelected === true;

        let rowClass =
            'assigned-row assignment-selection-disabled';

        if (isSelectable) {
            rowClass = isSelected
                ? 'assigned-row assignment-selectable assignment-selected'
                : 'assigned-row assignment-selectable assignment-unselected';
        }

        let indicatorClass =
            'selection-indicator selection-indicator-disabled';

        if (isSelectable) {
            indicatorClass = isSelected
                ? 'selection-indicator selection-indicator-selected'
                : 'selection-indicator';
        }

        return {
            ...assignment,
            transactionId:
                groupRow?.transactionId || null,
            isApprovalSelectable:
                isSelectable,
            isSelectedForApproval:
                isSelected,
            showSelectionMarker:
                true,
            showSelectedIcon:
                isSelected,
            selectionIndicatorClass:
                indicatorClass,
            rowClass:
                rowClass,
            rowTabIndex:
                isSelectable ? 0 : -1,
            selectionAriaLabel:
                isSelectable
                    ? `${isSelected ? 'Deselect' : 'Select'} ${assignment.displayName} for approval`
                    : `${assignment.displayName} is not available for approval`
        };
    }


    async openPreview(transactionId, groupRows, forceReadOnly = false) {
        this.isLoading = true;
        this.errorMessage = undefined;
        this.resetPreviewState();
        this.forceReadOnlyPreview = forceReadOnly;
        this.previewTransactionId = transactionId;
        this.isGroupPreview = groupRows.length > 0;
        this.previewGroupTransactionIds = groupRows.map((row) => row.transactionId);
        this.previewGroupRows = groupRows.map((row) => {
            const isApprovalSelectable =
                !this.forceReadOnlyPreview &&
                row.isDateOver !== true &&
                row.approvalStatus === 'Pending' &&
                (
                    this.isAdmin ||
                    row.canApprove === true ||
                    row.pendingWithId === this.currentUserId
                );

            const displayStatus =
                row.displayStatus || row.approvalStatus;

            return {
                ...row,
                key: row.transactionId,
                displayStatus,
                scopeAssignedPerson: row.executiveName || row.assignedPersonNo || '—',
                isApprovalSelectable,
                isSelected: isApprovalSelectable,
                selectionDisabled: !isApprovalSelectable,
                statusClass: this.getStatusClass(displayStatus),
                lastActionClass: this.getActionClass(row.lastAction)
            };
        });

        try {
            const result = await getApprovalOverview({ taggedApprovalId: transactionId });
            this.prepareOverview(result);
            this.isPreviewMode = true;
            window.scrollTo({ top: 0, behavior: 'smooth' });
        } catch (error) {
            this.errorMessage = this.reduceError(error);
            this.showToast('Preview Failed', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    prepareOverview(result) {
        const summary = result?.summary || {};
        this.actionContext = result?.actionContext || {};

        const previewDisplayStatus =
            this.actionContext.displayStatus ||
            summary.approvalStatus;

        this.previewSummary = {
            ...summary,
            displayStatus: previewDisplayStatus,
            isDateOver:
                this.actionContext.isDateOver === true,
            formattedTargetDate:
                this.formatDate(summary.targetDate),
            statusClass:
                this.getStatusClass(previewDisplayStatus)
        };

        const groupRowByDateId = new Map(
            this.previewGroupRows
                .filter((row) => row.assignedPersonDateId)
                .map((row) => [
                    row.assignedPersonDateId,
                    row
                ])
        );

        this.assignedPersonRows = (
            result?.assignedPersons || []
        ).map((row, index) => {
            const assignment = {
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
                formattedTargetDate:
                    this.formatDate(row.targetDate),
                formattedActualDate:
                    this.formatDate(row.actualDate),
                attendanceDisplay:
                    this.getAttendanceDisplay(row),
                displayStatus:
                    this.actionContext.isDateOver === true
                        ? 'Date Over'
                        : row.approvalStatus,
                statusClass:
                    this.getStatusClass(
                        this.actionContext.isDateOver === true
                            ? 'Date Over'
                            : row.approvalStatus
                    ),
                rowClass:
                    row.isSelectedRecord
                        ? 'assigned-row selected-assignment-row'
                        : 'assigned-row'
            };

            return this.decorateAssignedPersonSelection(
                assignment,
                groupRowByDateId.get(row.dateRecordId)
            );
        });

        this.supportingCards = this.buildSupportingCards(
            result?.supportingInfo || {}
        );

        this.previewWarnings = this.mapWarnings(
            result?.warnings || []
        );

        if (
            this.actionContext.isDateOver === true &&
            this.actionContext.dateOverMessage
        ) {
            this.previewWarnings = this.mergeWarnings(
                this.previewWarnings,
                [this.actionContext.dateOverMessage]
            );
        }
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
                    taggedApprovalId: this.previewTransactionId
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

        this.detailedFiles = this.prepareFiles(
            result?.files || []
        );

        this.previewWarnings = this.mergeWarnings(
            this.previewWarnings,
            result?.warnings || []
        );

        if (result?.actionContext) {
            this.actionContext = result.actionContext;
        }
    }

    async handleBulkApprove() {
        const selectedIds = this.activeBulkTransactionIds;

        if (!selectedIds.length) {
            this.showToast('Selection Required', 'Select at least one pending activity.', 'warning');
            return;
        }

        const confirmed = await LightningConfirm.open({
            label: 'Approve Selected Activities',
            theme: 'success',
            message: `Approve ${selectedIds.length} approval record(s) across ${this.selectedBulkActivityCount} selected activity group(s)?`
        });

        if (!confirmed) {
            return;
        }

        this.isLoading = true;

        try {
            const result = selectedIds.length === 1
                ? await approveApproval({
                    taggedApprovalId: selectedIds[0],
                    comments: this.bulkActionComments?.trim() || null
                })
                : await approveTeamActivity({
                    taggedApprovalIds: selectedIds,
                    comments: this.bulkActionComments?.trim() || null
                });

            this.showToast('Bulk Approval Successful', result?.message || 'Selected activities were approved.', 'success');
            this.clearAllBulkSelections();
            await this.refreshWorkspaceData();
        } catch (error) {
            this.showToast('Bulk Approval Failed', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleBulkReject() {
        const selectedIds = this.activeBulkTransactionIds;
        const reason = this.bulkActionComments?.trim();

        if (!selectedIds.length) {
            this.showToast('Selection Required', 'Select at least one pending activity.', 'warning');
            return;
        }

        if (!reason) {
            this.showToast('Rejection Reason Required', 'Enter a rejection reason before rejecting the selected activities.', 'warning');
            return;
        }

        const confirmed = await LightningConfirm.open({
            label: 'Reject Selected Activities',
            theme: 'error',
            message: `Reject ${selectedIds.length} approval record(s) across ${this.selectedBulkActivityCount} selected activity group(s)?`
        });

        if (!confirmed) {
            return;
        }

        this.isLoading = true;

        try {
            const result = selectedIds.length === 1
                ? await rejectApproval({
                    taggedApprovalId: selectedIds[0],
                    rejectionReason: reason
                })
                : await rejectSelectedApprovals({
                    taggedApprovalIds: selectedIds,
                    rejectionReason: reason
                });

            this.showToast('Bulk Rejection Successful', result?.message || 'Selected activities were rejected.', 'success');
            this.clearAllBulkSelections();
            await this.refreshWorkspaceData();
        } catch (error) {
            this.showToast('Bulk Rejection Failed', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleApprove() {
        const transactionId =
            this.actionContext?.transactionId;

        if (!transactionId) {
            return;
        }

        const confirmed = await LightningConfirm.open({
            label: 'Approve Activity',
            theme: 'success',
            message:
                `Approve this activity at ` +
                `${this.actionContext.currentLevel || 'the current'} level?`
        });

        if (!confirmed) {
            return;
        }

        this.isLoading = true;

        try {
            const result = await approveApproval({
                taggedApprovalId: transactionId,
                comments:
                    this.actionComments?.trim() || null
            });

            this.showToast(
                'Approval Successful',
                result?.message ||
                    'The activity was approved successfully.',
                'success'
            );

            this.closePreview();
            this.clearAllBulkSelections();
            await this.refreshWorkspaceData();
        } catch (error) {
            this.showToast(
                'Approval Failed',
                this.reduceError(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async handleApproveGroupSelection() {
        const selectedIds = this.selectedPreviewGroupTransactionIds;

        if (!selectedIds.length) {
            this.showToast(
                'Selection Required',
                'Select at least one approval record.',
                'warning'
            );
            return;
        }

        const isSingleSelection = selectedIds.length === 1;
        const confirmationLabel = this.isFullTeamSelection
            ? 'Approve Full Team Activity'
            : isSingleSelection
                ? 'Approve Selected Record'
                : 'Approve Selected Records';
        const confirmationMessage = this.isFullTeamSelection
            ? `Approve all ${selectedIds.length} records in this team activity?`
            : isSingleSelection
                ? 'Approve the selected approval record?'
                : `Approve the ${selectedIds.length} selected approval records?`;

        const confirmed = await LightningConfirm.open({
            label: confirmationLabel,
            theme: 'success',
            message: confirmationMessage
        });

        if (!confirmed) {
            return;
        }

        this.isLoading = true;

        try {
            let result;

            if (isSingleSelection) {
                result = await approveApproval({
                    taggedApprovalId: selectedIds[0],
                    comments: this.actionComments?.trim() || null
                });
            } else {
                result = await approveTeamActivity({
                    taggedApprovalIds: selectedIds,
                    comments: this.actionComments?.trim() || null
                });
            }

            const toastTitle = this.isFullTeamSelection
                ? 'Team Approval Successful'
                : isSingleSelection
                    ? 'Approval Successful'
                    : 'Selected Approvals Successful';

            this.showToast(
                toastTitle,
                result?.message || 'The selected approval record(s) were approved successfully.',
                'success'
            );

            this.closePreview();
            this.clearAllBulkSelections();
            await this.refreshWorkspaceData();
        } catch (error) {
            this.showToast(
                'Approval Failed',
                this.reduceError(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async handleRejectGroupSelection() {
        const selectedIds = this.selectedPreviewGroupTransactionIds;
        const reason = this.actionComments?.trim();

        if (!selectedIds.length) {
            this.showToast('Selection Required', 'Select at least one approval record.', 'warning');
            return;
        }

        if (!reason) {
            this.showToast('Rejection Reason Required', 'Enter a rejection reason before rejecting the selected record(s).', 'warning');
            return;
        }

        const isSingleSelection = selectedIds.length === 1;
        const confirmationLabel = this.isFullTeamSelection
            ? 'Reject Full Team Activity'
            : isSingleSelection
                ? 'Reject Selected Record'
                : 'Reject Selected Records';
        const confirmationMessage = this.isFullTeamSelection
            ? `Reject all ${selectedIds.length} records in this team activity?`
            : isSingleSelection
                ? 'Reject the selected approval record?'
                : `Reject the ${selectedIds.length} selected approval records?`;

        const confirmed = await LightningConfirm.open({
            label: confirmationLabel,
            theme: 'error',
            message: confirmationMessage
        });

        if (!confirmed) {
            return;
        }

        this.isLoading = true;

        try {
            const result = isSingleSelection
                ? await rejectApproval({
                    taggedApprovalId: selectedIds[0],
                    rejectionReason: reason
                })
                : await rejectSelectedApprovals({
                    taggedApprovalIds: selectedIds,
                    rejectionReason: reason
                });

            const toastTitle = this.isFullTeamSelection
                ? 'Team Rejection Successful'
                : isSingleSelection
                    ? 'Activity Returned'
                    : 'Selected Rejections Successful';

            this.showToast(toastTitle, result?.message || 'The selected approval record(s) were rejected.', 'success');
            this.closePreview();
            this.clearAllBulkSelections();
            await this.refreshWorkspaceData();
        } catch (error) {
            this.showToast('Rejection Failed', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleReject() {
        const transactionId =
            this.actionContext?.transactionId;

        const reason = this.actionComments?.trim();

        if (!reason) {
            this.showToast(
                'Rejection Reason Required',
                'Enter a rejection reason before rejecting the activity.',
                'warning'
            );
            return;
        }

        const confirmed = await LightningConfirm.open({
            label: 'Reject Activity',
            theme: 'error',
            message:
                'Reject this activity and return it to the Store Manager?'
        });

        if (!confirmed) {
            return;
        }

        this.isLoading = true;

        try {
            const result = await rejectApproval({
                taggedApprovalId: transactionId,
                rejectionReason: reason
            });

            this.showToast(
                'Activity Returned',
                result?.message ||
                    'The activity was returned to the Store Manager.',
                'success'
            );

            this.closePreview();
            this.clearAllBulkSelections();
            await this.refreshWorkspaceData();
        } catch (error) {
            this.showToast(
                'Rejection Failed',
                this.reduceError(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleBackFromPreview() {
        this.closePreview();
    }

    closePreview() {
        this.isPreviewMode = false;
        this.resetPreviewState();
        this.errorMessage = undefined;
    }

    resetPreviewState() {
        this.previewTransactionId = undefined;
        this.isGroupPreview = false;
        this.previewGroupRows = [];
        this.previewGroupTransactionIds = [];
        this.previewSummary = {};
        this.assignedPersonRows = [];
        this.supportingCards = [];
        this.previewWarnings = [];
        this.detailedSections = [];
        this.detailedFiles = [];
        this.isFullDetailsLoaded = false;
        this.showFullDetails = false;
        this.actionContext = {};
        this.actionComments = '';
        this.forceReadOnlyPreview = false;
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

    getGroupKey(row) {
        return [
            row.finalCustomizeFormId || row.finalCustomizeFormNo || '',
            row.activityId || row.activityNo || '',
            row.storeId || row.storeName || '',
            row.targetDate || '',
            row.teamName || '',
            (row.activityLocation || '')
                .trim()
                .toLowerCase()
        ].join('|');
    }

    buildRecordUrl(recordId) {
        return recordId
            ? `/lightning/r/${recordId}/view`
            : '#';
    }

    getStatusClass(status) {
        const value = (status || '').trim().toLowerCase();

        if (value === 'approved' || value === 'final approved' || value === 'completed') {
            return 'status-badge status-approved';
        }

        if (value === 'pending' || value === 'pending approval') {
            return 'status-badge status-pending';
        }

        if (value === 'rejected' || value === 'declined') {
            return 'status-badge status-rejected';
        }

        if (value === 'returned' || value === 'sent back') {
            return 'status-badge status-returned';
        }

        if (value === 'submitted') {
            return 'status-badge status-submitted';
        }

        if (value === 'resubmitted') {
            return 'status-badge status-resubmitted';
        }

        if (value === 'dropped') {
            return 'status-badge status-dropped';
        }

        if (value === 'date over' || value === 'expired') {
            return 'status-badge status-date-over';
        }

        if (value === 'cancelled' || value === 'canceled') {
            return 'status-badge status-cancelled';
        }

        if (value === 'not submitted' || value === 'draft' || value === 'new') {
            return 'status-badge status-not-submitted';
        }

        if (value === 'in progress' || value === 'processing') {
            return 'status-badge status-progress';
        }

        if (value === 'failed' || value === 'error') {
            return 'status-badge status-error';
        }

        return 'status-badge status-neutral';
    }

    getActionClass(action) {
        const value = (action || '').trim().toLowerCase();

        if (value === 'approved') {
            return 'status-badge status-approved';
        }

        if (value === 'final approved') {
            return 'status-badge status-final-approved';
        }

        if (value === 'rejected') {
            return 'status-badge status-rejected';
        }

        if (value === 'returned') {
            return 'status-badge status-returned';
        }

        if (value === 'submitted') {
            return 'status-badge status-submitted';
        }

        if (value === 'resubmitted') {
            return 'status-badge status-resubmitted';
        }

        if (value === 'pending') {
            return 'status-badge status-pending';
        }

        if (value === 'dropped') {
            return 'status-badge status-dropped';
        }

        if (value === 'cancelled' || value === 'canceled') {
            return 'status-badge status-cancelled';
        }

        if (value === 'failed' || value === 'error') {
            return 'status-badge status-error';
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