import {
    LightningElement,
    track,
    wire
} from 'lwc';

import {
    CurrentPageReference
} from 'lightning/navigation';

import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';

import getWorkspaceData
    from '@salesforce/apex/Ctrl_OrientCustomerApprovalWorkspace.getWorkspaceData';

import getApprovalPreview
    from '@salesforce/apex/Ctrl_OrientCustomerApprovalWorkspace.getApprovalPreview';

import getApprovalPreviewByRequestId
    from '@salesforce/apex/Ctrl_OrientCustomerApprovalWorkspace.getApprovalPreviewByRequestId';

import submitFieldDecisions
    from '@salesforce/apex/Ctrl_OrientCustomerApprovalWorkspace.submitFieldDecisions';

import lookupCustomersWithSameContactNumbers
    from '@salesforce/apex/Ctrl_OrientCustomerApprovalWorkspace.lookupCustomersWithSameContactNumbers';

import rejectEntireRequestForDuplicateContactNumber
    from '@salesforce/apex/Ctrl_OrientCustomerApprovalWorkspace.rejectEntireRequestForDuplicateContactNumber';

import refreshWorkspaceData
    from '@salesforce/apex/Ctrl_OrientCustomerApprovalWorkspace.refreshWorkspaceData';

import refreshApprovalPreview
    from '@salesforce/apex/Ctrl_OrientCustomerApprovalWorkspace.refreshApprovalPreview';

import getSupportingDocuments
    from '@salesforce/apex/Ctrl_OrientCustomerProfileChange.getSupportingDocuments';

export default class LwcOrientCustomerApprovalWorkspace extends LightningElement {
    @track pendingApprovals = [];
    @track actionedApprovals = [];
    @track allPendingApprovals = [];
    @track allRequests = [];
    @track preview;

    isAdmin = false;
    profileName = '';
    approvedCount = 0;

    activeTab = 'pending';
    searchKey = '';

    approvalComments = '';
    rejectionReason = '';
    rejectionReasonError = '';

    isLoading = false;
    isPreviewLoading = false;
    isActionLoading = false;

    loadError = '';
    fieldDecisionError = '';

    kycDecision = '';
    kycRejectionReason = '';

    bcAddressDecision = '';
    bcAddressRejectionReason = '';

    isRefreshing = false;
    isRefreshingPreview = false;

    isLoadingDocuments = false;

    isPhoneLookupLoading = false;
    phoneLookupPerformed = false;
    phoneDuplicateFound = false;
    phoneLookupMessage = '';
    phoneLookupMatches = [];

    duplicatePhoneRejectionReason = '';
    duplicatePhoneRejectionError = '';

    directRequestId = null;
    directRequestPreviewOpened = false;
    workspaceDataLoaded = false;

    showSupportingDocumentPreview = false;
    supportingDocumentPreviewFiles = [];
    supportingDocumentPreviewSelectedId;

    @wire(CurrentPageReference)
    handleCurrentPageReference(pageReference) {
        const requestId =
            pageReference?.state?.c__requestId;

        if (
            !requestId ||
            requestId === this.directRequestId
        ) {
            return;
        }

        this.directRequestId =
            requestId;

        this.directRequestPreviewOpened =
            false;

        if (this.workspaceDataLoaded) {
            this.openDirectRequestPreview();
        }
    }

    connectedCallback() {
        this.loadWorkspace();
    }

    get pendingCount() {
        return this.pendingApprovals.length;
    }

    get actionedCount() {
        return this.actionedApprovals.length;
    }

    get allPendingCount() {
        return this.allPendingApprovals.length;
    }

    get allRequestCount() {
        return this.allRequests.length;
    }

    get workspaceDescription() {
        return this.isAdmin
            ? 'Review every Customer Profile approval request and take action as System Administrator.'
            : 'Review Customer Profile changes assigned to you and track the approvals you have already actioned.';
    }

    get pendingTabClass() {
        return this.getTabClass(
            'pending'
        );
    }

    get allPendingTabClass() {
        return this.getTabClass(
            'allPending'
        );
    }

    get actionedTabClass() {
        return this.getTabClass(
            'actioned'
        );
    }

    get allRequestsTabClass() {
        return this.getTabClass(
            'allRequests'
        );
    }

    get isPendingTab() {
        return this.activeTab ===
            'pending';
    }

    get isAllPendingTab() {
        return this.activeTab ===
            'allPending';
    }

    get isActionedTab() {
        return this.activeTab ===
            'actioned';
    }

    get isAllRequestsTab() {
        return this.activeTab ===
            'allRequests';
    }

    get filteredPendingApprovals() {
        return this.filterRows(
            this.pendingApprovals
        );
    }

    get filteredAllPendingApprovals() {
        return this.filterRows(
            this.allPendingApprovals
        );
    }

    get filteredActionedApprovals() {
        return this.filterRows(
            this.actionedApprovals
        );
    }

    get filteredAllRequests() {
        return this.filterRows(
            this.allRequests
        );
    }

    get hasPendingRows() {
        return this.filteredPendingApprovals.length >
            0;
    }

    get hasAllPendingRows() {
        return this.filteredAllPendingApprovals.length >
            0;
    }

    get hasActionedRows() {
        return this.filteredActionedApprovals.length >
            0;
    }

    get hasAllRequestRows() {
        return this.filteredAllRequests.length >
            0;
    }

    get hasLoadError() {
        return Boolean(
            this.loadError
        );
    }

    get showPreview() {
        return Boolean(
            this.preview
        );
    }

    get showWorkspaceSpinner() {
        return (
            this.isLoading &&
            !this.showPreview
        );
    }

    get showPhoneDuplicateLookup() {
        return (
            this.preview?.hasPendingContactNumberChange ===
                true &&
            this.preview?.canReject ===
                true
        );
    }

    get phoneLookupButtonDisabled() {
        return (
            this.isActionLoading ||
            this.isPhoneLookupLoading
        );
    }

    get phoneDecisionControlsDisabled() {
        if (!this.showPhoneDuplicateLookup) {
            return false;
        }

        return (
            !this.phoneLookupPerformed ||
            this.phoneDuplicateFound
        );
    }

    get showPhoneLookupSuccess() {
        return (
            this.phoneLookupPerformed &&
            !this.phoneDuplicateFound
        );
    }

    get showPhoneLookupDuplicate() {
        return (
            this.phoneLookupPerformed &&
            this.phoneDuplicateFound
        );
    }

    get duplicatePhoneRejectDisabled() {
        return (
            this.isActionLoading ||
            !this.phoneDuplicateFound ||
            !String(
                this.duplicatePhoneRejectionReason ||
                ''
            ).trim()
        );
    }

    get phoneLookupButtonLabel() {
        return this.isPhoneLookupLoading
            ? 'Checking Customers...'
            : 'Lookup Customers With Same Phone / WhatsApp';
    }

    get showKycAtomicDecision() {
        return (
            this.preview?.isKycRequest ===
                true &&
            this.preview?.canApprove ===
                true
        );
    }

    get kycDecisionOptions() {
        const kycLabel =
            this.preview?.kycDisplayName ||
            'KYC';

        return [
            {
                label:
                    `Approve All ${kycLabel} Fields`,
                value:
                    'Approve'
            },
            {
                label:
                    `Return All ${kycLabel} Fields`,
                value:
                    'Reject'
            }
        ];
    }

    get isKycRejectedDecision() {
        return this.kycDecision ===
            'Reject';
    }

    get kycDecisionControlsDisabled() {
        return (
            this.phoneDecisionControlsDisabled ||
            this.isActionLoading
        );
    }

    get showBCAddressGroupDecision() {
        return (
            this.preview?.hasPendingBCControlledAddress ===
                true &&
            this.preview?.canApprove ===
                true
        );
    }

    get bcAddressDecisionOptions() {
        return [
            {
                label:
                    'Approve All BC Address Fields',
                value:
                    'Approve'
            },
            {
                label:
                    'Reject All BC Address Fields',
                value:
                    'Reject'
            }
        ];
    }

    get isBCAddressRejectedDecision() {
        return this.bcAddressDecision ===
            'Reject';
    }

    get bcAddressDecisionControlsDisabled() {
        return (
            this.phoneDecisionControlsDisabled ||
            this.isActionLoading
        );
    }

    get fieldDecisionSubmitDisabled() {
        if (
            this.phoneDecisionControlsDisabled ||
            this.isActionLoading ||
            !this.preview?.canApprove ||
            (
                !this.preview?.isFinalLevel &&
                !this.preview?.routingReady
            )
        ) {
            return true;
        }

        const actionable =
            (
                this.preview?.changes ||
                []
            ).filter(
                item =>
                    item.isActionable ===
                    true
            );

        if (!actionable.length) {
            return true;
        }

        if (
            this.preview?.isKycRequest ===
            true
        ) {
            if (!this.kycDecision) {
                return true;
            }

            if (
                this.kycDecision ===
                    'Reject' &&
                !String(
                    this.kycRejectionReason ||
                    ''
                ).trim()
            ) {
                return true;
            }

            return false;
        }

        return actionable.some(
            item => {
                if (!item.decision) {
                    return true;
                }

                return (
                    item.decision ===
                        'Reject' &&
                    !String(
                        item.rejectionReasonInput ||
                        ''
                    ).trim()
                );
            }
        );
    }

    get fieldDecisionSubmitLabel() {
        if (this.isActionLoading) {
            if (
                this.preview?.isKycRequest ===
                true
            ) {
                return 'Processing KYC Decision...';
            }

            return this.preview?.isFinalLevel
                ? 'Processing Final Decisions...'
                : 'Submitting...';
        }

        if (
            this.preview?.isKycRequest ===
            true
        ) {
            return this.preview?.isFinalLevel
                ? 'Submit Final KYC Decision'
                : 'Submit KYC Decision';
        }

        return this.preview?.isFinalLevel
            ? 'Submit Final Decisions'
            : 'Submit Field Decisions';
    }

    get previewStatusClass() {
        return this.getStatusClass(
            this.preview?.approvalStatus
        );
    }

    get routingClass() {
        if (
            this.preview?.isFinalLevel
        ) {
            return 'routing-card routing-card-final';
        }

        if (
            this.preview?.routingReady
        ) {
            return 'routing-card routing-card-ready';
        }

        return 'routing-card routing-card-error';
    }

    get adminOverrideText() {
        return this.preview?.pendingWithName
            ? `This request is assigned to ${this.preview.pendingWithName}. You can act on it because your Profile is System Administrator.`
            : 'You can act on this request because your Profile is System Administrator.';
    }

    async loadWorkspace() {
        this.isLoading =
            true;

        this.loadError =
            '';

        try {
            const result =
                await getWorkspaceData();

            this.applyWorkspaceData(
                result
            );

            this.workspaceDataLoaded =
                true;

            await this.openDirectRequestPreview();
        } catch (error) {
            this.loadError =
                this.reduceError(
                    error
                );

            this.showToast(
                'Unable to Load Customer Approval Workspace',
                this.loadError,
                'error'
            );
        } finally {
            this.isLoading =
                false;
        }
    }

    async openDirectRequestPreview() {
        if (
            !this.directRequestId ||
            this.directRequestPreviewOpened
        ) {
            return;
        }

        this.directRequestPreviewOpened =
            true;

        this.isPreviewLoading =
            true;

        this.approvalComments =
            '';

        this.rejectionReason =
            '';

        this.rejectionReasonError =
            '';

        this.resetPhoneLookupState();
        this.resetBCAddressDecisionState();
        this.resetKycDecisionState();

        try {
            const result =
                await getApprovalPreviewByRequestId({
                    requestId:
                        this.directRequestId
                });

            this.preview =
                this.decoratePreview(
                    result
                );
        } catch (error) {
            this.directRequestPreviewOpened =
                false;

            this.showToast(
                'Unable to Open Change Request',
                this.reduceError(
                    error
                ),
                'error'
            );
        } finally {
            this.isPreviewLoading =
                false;
        }
    }

    applyWorkspaceData(result) {
        this.isAdmin =
            result?.isAdmin ===
            true;

        this.profileName =
            result?.profileName ||
            '';

        this.approvedCount =
            result?.approvedCount ||
            0;

        this.pendingApprovals =
            this.decorateRows(
                result?.pendingApprovals ||
                []
            );

        this.actionedApprovals =
            this.decorateRows(
                result?.actionedApprovals ||
                []
            );

        this.allPendingApprovals =
            this.decorateRows(
                result?.allPendingApprovals ||
                []
            );

        this.allRequests =
            this.decorateRows(
                result?.allRequests ||
                []
            );

        if (
            !this.isAdmin &&
            (
                this.activeTab ===
                    'allPending' ||
                this.activeTab ===
                    'allRequests'
            )
        ) {
            this.activeTab =
                'pending';
        }
    }

    decorateRows(rows) {
        return rows.map(
            row =>
                this.decorateRow(
                    row
                )
        );
    }

    decorateRow(row) {
        const action =
            row.myAction ||
            row.lastAction ||
            '';

        return {
            ...row,

            customerName:
                row.customerName ||
                '—',

            requestName:
                row.requestName ||
                '—',

            storeName:
                row.storeName ||
                '—',

            submittedByName:
                row.submittedByName ||
                '—',

            currentLevelName:
                row.currentLevelName ||
                '—',

            pendingWithName:
                row.pendingWithName ||
                '—',

            changeReason:
                row.changeReason ||
                '—',

            changeCount:
                row.changeCount ||
                0,

            actionLabel:
                action ||
                '—',

            approvalStatusDisplay:
                row.approvalStatus ===
                    'Returned'
                    ? 'Rejected'
                    : (
                        row.approvalStatus ||
                        '—'
                    ),

            statusClass:
                this.getStatusClass(
                    row.approvalStatus
                ),

            actionClass:
                this.getActionClass(
                    action
                )
        };
    }

    getTabClass(tabName) {
        return this.activeTab ===
            tabName
            ? 'workspace-tab workspace-tab-active'
            : 'workspace-tab';
    }

    getStatusClass(statusValue) {
        const status =
            String(
                statusValue ||
                ''
            ).toLowerCase();

        if (
            status ===
            'pending'
        ) {
            return 'status-pill status-pending';
        }

        if (
            status.includes(
                'approved'
            )
        ) {
            return 'status-pill status-approved';
        }

        if (
            status ===
                'returned' ||
            status ===
                'rejected'
        ) {
            return 'status-pill status-returned';
        }

        return 'status-pill';
    }

    getActionClass(actionValue) {
        const action =
            String(
                actionValue ||
                ''
            ).toLowerCase();

        if (
            action.includes(
                'approved'
            )
        ) {
            return 'action-pill action-approved';
        }

        if (
            action.includes(
                'reject'
            ) ||
            action.includes(
                'return'
            )
        ) {
            return 'action-pill action-returned';
        }

        return 'action-pill';
    }

    filterRows(rows) {
        const search =
            String(
                this.searchKey ||
                ''
            )
                .trim()
                .toLowerCase();

        if (!search) {
            return rows;
        }

        return rows.filter(
            row => {
                const searchableText =
                    [
                        row.requestName,
                        row.customerName,
                        row.storeName,
                        row.submittedByName,
                        row.currentLevelName,
                        row.pendingWithName,
                        row.approvalStatus,
                        row.changeReason,
                        row.myAction,
                        row.lastAction
                    ]
                        .filter(
                            Boolean
                        )
                        .join(
                            ' '
                        )
                        .toLowerCase();

                return searchableText.includes(
                    search
                );
            }
        );
    }

    handleTabChange(event) {
        const tab =
            event.currentTarget
                ?.dataset
                ?.tab;

        const allowedTabs =
            this.isAdmin
                ? [
                    'pending',
                    'allPending',
                    'actioned',
                    'allRequests'
                ]
                : [
                    'pending',
                    'actioned'
                ];

        if (
            allowedTabs.includes(
                tab
            )
        ) {
            this.activeTab =
                tab;
        }
    }

    handleSearch(event) {
        this.searchKey =
            event.target?.value ||
            '';
    }

    handleClearSearch() {
        this.searchKey =
            '';

        const input =
            this.template.querySelector(
                '[data-id="workspaceSearch"]'
            );

        if (input) {
            input.value =
                '';
        }
    }

    async handleRefresh() {
        if (
            this.isRefreshing
        ) {
            return;
        }

        this.isRefreshing =
            true;

        this.isLoading =
            true;

        this.loadError =
            '';

        try {
            const result =
                await refreshWorkspaceData();

            this.applyWorkspaceData(
                result
            );

            this.showToast(
                'Workspace Refreshed',
                'Customer approval data was refreshed directly from Apex.',
                'success'
            );
        } catch (error) {
            this.loadError =
                this.reduceError(
                    error
                );

            this.showToast(
                'Workspace Refresh Failed',
                this.loadError,
                'error'
            );
        } finally {
            this.isLoading =
                false;

            this.isRefreshing =
                false;
        }
    }

    async handlePreview(event) {
        const approvalTransactionId =
            event.currentTarget
                ?.dataset
                ?.transactionId;

        if (
            !approvalTransactionId
        ) {
            return;
        }

        this.isPreviewLoading =
            true;

        this.approvalComments =
            '';

        this.rejectionReason =
            '';

        this.rejectionReasonError =
            '';

        this.resetPhoneLookupState();
        this.resetBCAddressDecisionState();
        this.resetKycDecisionState();

        try {
            const result =
                await getApprovalPreview({
                    approvalTransactionId
                });

            this.preview =
                this.decoratePreview(
                    result
                );
        } catch (error) {
            this.showToast(
                'Unable to Load Approval Preview',
                this.reduceError(
                    error
                ),
                'error'
            );
        } finally {
            this.isPreviewLoading =
                false;
        }
    }

    decoratePreview(result) {
        return {
            ...result,

            approvalStatusDisplay:
                result?.approvalStatus ===
                    'Returned'
                    ? 'Rejected'
                    : (
                        result?.approvalStatus ||
                        '—'
                    ),

            customerName:
                result?.customerName ||
                '—',

            requestName:
                result?.requestName ||
                '—',

            storeName:
                result?.storeName ||
                '—',

            locationCode:
                result?.locationCode ||
                '—',

            submittedByName:
                result?.submittedByName ||
                '—',

            currentLevelName:
                result?.currentLevelName ||
                '—',

            pendingWithName:
                result?.pendingWithName ||
                '—',

            changeReason:
                result?.changeReason ||
                '—',

            bcCustomerNoDisplay:
                result?.bcCustomerNo ||
                '—',

            bcPushStatusDisplay:
                result?.bcPushStatus ||
                'Not Attempted',

            bcPushMessageDisplay:
                result?.bcPushMessage ||
                '—',

            bcPushAttemptDisplay:
                result?.bcPushAttemptCount ||
                0,

            showBCDetails:
                result?.hasBCApplicableChanges ===
                    true ||
                Boolean(
                    result?.bcCustomerNo
                ) ||
                Boolean(
                    result?.bcPushStatus
                ) ||
                Boolean(
                    result?.bcPushMessage
                ),

            changes:
                this.decorateChanges(
                    result?.changes ||
                    [],
                    result?.hasPendingBCControlledAddress ===
                        true &&
                    result?.canApprove ===
                        true,
                    result?.isKycRequest ===
                        true
                ),

            history:
                (
                    result?.history ||
                    []
                ).map(
                    item => ({
                        ...item,

                        actionByName:
                            item.actionByName ||
                            '—',

                        approvalLevelName:
                            item.approvalLevelName ||
                            '—',

                        assignedToName:
                            item.assignedToName ||
                            '—',

                        comments:
                            item.comments ||
                            null,

                        customerChangeItemLabel:
                            item.customerChangeItemLabel ||
                            null,

                        actionClass:
                            this.getActionClass(
                                item.action
                            )
                    })
                )
        };
    }

    decorateChanges(
        items,
        showBCAddressGroupDecision,
        isKycRequest
    ) {
        const decoratedChanges =
            (
                items ||
                []
            ).map(
                item => {
                    const status =
                        item.itemApprovalStatus ||
                        'Pending';

                    return {
                        ...item,

                        sectionName:
                            item.sectionName ||
                            'Customer Profile',

                        fieldLabel:
                            item.fieldLabel ||
                            item.accountFieldApi,

                        oldDisplayValue:
                            item.oldDisplayValue ||
                            '—',

                        newDisplayValue:
                            item.newDisplayValue ||
                            '—',

                        itemApprovalStatus:
                            status,

                        itemApprovalStatusDisplay:
                            status ===
                                'Returned'
                                ? 'Rejected'
                                : status,

                        itemStatusClass:
                            this.getItemStatusClass(
                                status
                            ),

                        isRejected:
                            status ===
                            'Returned',

                        isFinalApproved:
                            status ===
                            'Final Approved',

                        rejectedFromLevelName:
                            item.rejectedFromLevelName ||
                            '—',

                        rejectedByName:
                            item.rejectedByName ||
                            '—',

                        rejectionReason:
                            item.rejectionReason ||
                            '—',

                        finalApprovedByName:
                            item.finalApprovedByName ||
                            '—',

                        bcControlledAddress:
                            item.bcControlledAddress ===
                            true,

                        workspaceVisible:
                            item.workspaceVisible !==
                            false,

                        showIndividualDecisionPanel:
                            item.isActionable ===
                                true &&
                            item.bcControlledAddress !==
                                true &&
                            isKycRequest !==
                                true,

                        showBCAddressDecisionAfter:
                            false,

                        bcAddressDecisionKey:
                            `${item.changeItemId}-bc-address-decision`,

                        decision:
                            '',

                        rejectionReasonInput:
                            '',

                        isRejectedDecision:
                            false,

                        decisionOptions: [
                            {
                                label:
                                    'Approve',
                                value:
                                    'Approve'
                            },
                            {
                                label:
                                    'Reject',
                                value:
                                    'Reject'
                            }
                        ]
                    };
                }
            );

        let lastVisibleBCAddressIndex =
            -1;

        decoratedChanges.forEach(
            (
                item,
                index
            ) => {
                if (
                    item.workspaceVisible ===
                        true &&
                    item.bcControlledAddress ===
                        true
                ) {
                    lastVisibleBCAddressIndex =
                        index;
                }
            }
        );

        if (
            showBCAddressGroupDecision ===
                true &&
            isKycRequest !==
                true &&
            lastVisibleBCAddressIndex >=
                0
        ) {
            decoratedChanges[
                lastVisibleBCAddressIndex
            ].showBCAddressDecisionAfter =
                true;
        }

        return decoratedChanges;
    }

    async handleRefreshPreview() {
        const approvalTransactionId =
            this.preview
                ?.approvalTransactionId;

        if (
            !approvalTransactionId ||
            this.isRefreshingPreview
        ) {
            return;
        }

        this.isRefreshingPreview =
            true;

        this.isPreviewLoading =
            true;

        this.resetPhoneLookupState();
        this.resetBCAddressDecisionState();
        this.resetKycDecisionState();

        try {
            const result =
                await refreshApprovalPreview({
                    approvalTransactionId
                });

            this.preview =
                this.decoratePreview(
                    result
                );

            this.showToast(
                'Preview Refreshed',
                'Approval Preview was refreshed directly from Apex.',
                'success'
            );
        } catch (error) {
            this.showToast(
                'Preview Refresh Failed',
                this.reduceError(
                    error
                ),
                'error'
            );
        } finally {
            this.isPreviewLoading =
                false;

            this.isRefreshingPreview =
                false;
        }
    }

    async handlePreviewSupportingDocuments() {
        const requestId =
            this.preview?.requestId;

        if (
            !requestId ||
            this.isLoadingDocuments
        ) {
            return;
        }

        this.isLoadingDocuments =
            true;

        try {
            const documents =
                await getSupportingDocuments({
                    requestId
                });

            const previewDocuments =
                (
                    documents ||
                    []
                ).map(
                    item => ({
                        contentDocumentId:
                            item.contentDocumentId,

                        latestVersionId:
                            item.latestVersionId,

                        title:
                            item.title,

                        fileExtension:
                            item.fileExtension,

                        name:
                            this.buildSupportingDocumentName(
                                item
                            )
                    })
                );

            if (
                !previewDocuments.length
            ) {
                this.showToast(
                    'No Supporting Documents',
                    'No supporting document is attached to this Customer Change Request.',
                    'info'
                );

                return;
            }

            this.supportingDocumentPreviewFiles =
                previewDocuments;

            this.supportingDocumentPreviewSelectedId =
                previewDocuments[
                    0
                ].contentDocumentId;

            this.showSupportingDocumentPreview =
                true;
        } catch (error) {
            this.showToast(
                'Unable to Preview Supporting Documents',
                this.reduceError(
                    error
                ),
                'error'
            );
        } finally {
            this.isLoadingDocuments =
                false;
        }
    }

    buildSupportingDocumentName(
        documentInfo
    ) {
        const title =
            documentInfo?.title ||
            'Supporting Document';

        const extension =
            documentInfo
                ?.fileExtension;

        if (
            extension &&
            !title
                .toLowerCase()
                .endsWith(
                    `.${String(
                        extension
                    ).toLowerCase()}`
                )
        ) {
            return `${title}.${extension}`;
        }

        return title;
    }

    handleCloseSupportingDocumentPreview() {
        this.showSupportingDocumentPreview =
            false;

        this.supportingDocumentPreviewFiles =
            [];

        this.supportingDocumentPreviewSelectedId =
            null;
    }

    getItemStatusClass(
        statusValue
    ) {
        const status =
            String(
                statusValue ||
                ''
            ).toLowerCase();

        if (
            status ===
            'pending'
        ) {
            return 'item-status-pill item-status-pending';
        }

        if (
            status ===
            'returned'
        ) {
            return 'item-status-pill item-status-returned';
        }

        if (
            status.includes(
                'approved'
            )
        ) {
            return 'item-status-pill item-status-approved';
        }

        return 'item-status-pill';
    }

    resetPhoneLookupState() {
        this.isPhoneLookupLoading =
            false;

        this.phoneLookupPerformed =
            false;

        this.phoneDuplicateFound =
            false;

        this.phoneLookupMessage =
            '';

        this.phoneLookupMatches =
            [];

        this.duplicatePhoneRejectionReason =
            '';

        this.duplicatePhoneRejectionError =
            '';
    }

    async handleLookupCustomersWithSameContactNumbers() {
        if (
            !this.preview
                ?.approvalTransactionId ||
            this.phoneLookupButtonDisabled
        ) {
            return;
        }

        this.isPhoneLookupLoading =
            true;

        this.phoneLookupMessage =
            '';

        this.phoneLookupMatches =
            [];

        this.duplicatePhoneRejectionError =
            '';

        try {
            const result =
                await lookupCustomersWithSameContactNumbers({
                    approvalTransactionId:
                        this.preview
                            .approvalTransactionId
                });

            this.phoneLookupPerformed =
                true;

            this.phoneDuplicateFound =
                result?.duplicateFound ===
                true;

            this.phoneLookupMessage =
                result?.message ||
                '';

            this.phoneLookupMatches =
                (
                    result?.matchingCustomers ||
                    []
                ).map(
                    (
                        item,
                        index
                    ) => ({
                        ...item,

                        rowKey:
                            `${item.customerId || 'customer'}-` +
                            `${item.requestedFieldApi || 'contact'}-` +
                            `${index}`,

                        customerName:
                            item.customerName ||
                            '—',

                        bcCustomerNoDisplay:
                            item.bcCustomerNo ||
                            '—',

                        requestedFieldLabel:
                            item.requestedFieldLabel ||
                            'Contact Number',

                        requestedNumber:
                            item.requestedNumber ||
                            '—',

                        matchSource:
                            item.matchSource ||
                            'Customer Contact'
                    })
                );

            if (
                this.phoneDuplicateFound
            ) {
                this.resetBCAddressDecisionState();
                this.resetKycDecisionState();

                this.preview = {
                    ...this.preview,

                    changes:
                        (
                            this.preview
                                ?.changes ||
                            []
                        ).map(
                            item => ({
                                ...item,

                                decision:
                                    '',

                                rejectionReasonInput:
                                    '',

                                isRejectedDecision:
                                    false
                            })
                        )
                };

                this.showToast(
                    'Duplicate Phone / WhatsApp Found',
                    this.phoneLookupMessage ||
                        'Another customer exists with one of the requested Phone / WhatsApp numbers. The entire request must be rejected.',
                    'error'
                );
            } else {
                this.showToast(
                    'Contact Number Lookup Completed',
                    this.phoneLookupMessage ||
                        'No other customer was found with the requested Phone / WhatsApp number(s).',
                    'success'
                );
            }
        } catch (error) {
            this.phoneLookupPerformed =
                false;

            this.phoneDuplicateFound =
                false;

            this.phoneLookupMessage =
                this.reduceError(
                    error
                );

            this.showToast(
                'Contact Number Lookup Failed',
                this.phoneLookupMessage,
                'error'
            );
        } finally {
            this.isPhoneLookupLoading =
                false;
        }
    }

    handleDuplicatePhoneRejectionReason(
        event
    ) {
        this.duplicatePhoneRejectionReason =
            event.detail?.value ??
            event.target?.value ??
            '';

        this.duplicatePhoneRejectionError =
            '';
    }

    async handleRejectEntireRequestForDuplicateContactNumber() {
        if (
            this.duplicatePhoneRejectDisabled ||
            !this.preview
                ?.approvalTransactionId
        ) {
            return;
        }

        this.isActionLoading =
            true;

        this.duplicatePhoneRejectionError =
            '';

        try {
            const result =
                await rejectEntireRequestForDuplicateContactNumber({
                    approvalTransactionId:
                        this.preview
                            .approvalTransactionId,

                    rejectionReason:
                        String(
                            this.duplicatePhoneRejectionReason ||
                            ''
                        ).trim()
                });

            this.showToast(
                'Request Rejected',
                result?.message ||
                    'The entire Customer Profile approval request was rejected because a duplicate Phone / WhatsApp customer was found.',
                'success'
            );

            this.preview =
                null;

            this.approvalComments =
                '';

            this.resetPhoneLookupState();
            this.resetBCAddressDecisionState();
            this.resetKycDecisionState();

            await this.loadWorkspace();
        } catch (error) {
            this.duplicatePhoneRejectionError =
                this.reduceError(
                    error
                );

            this.showToast(
                'Request Rejection Failed',
                this.duplicatePhoneRejectionError,
                'error'
            );
        } finally {
            this.isActionLoading =
                false;
        }
    }

    resetKycDecisionState() {
        this.kycDecision =
            '';

        this.kycRejectionReason =
            '';
    }

    handleKycDecision(event) {
        const decision =
            event.detail?.value ||
            event.target?.value ||
            '';

        this.kycDecision =
            decision;

        if (
            decision !==
            'Reject'
        ) {
            this.kycRejectionReason =
                '';
        }

        if (!this.preview) {
            return;
        }

        const rejectionReason =
            decision ===
                'Reject'
                ? this.kycRejectionReason
                : '';

        this.preview = {
            ...this.preview,

            changes:
                (
                    this.preview.changes ||
                    []
                ).map(
                    item =>
                        item.isActionable ===
                            true
                            ? {
                                ...item,

                                decision,

                                isRejectedDecision:
                                    decision ===
                                    'Reject',

                                rejectionReasonInput:
                                    rejectionReason
                            }
                            : item
                )
        };

        this.fieldDecisionError =
            '';
    }

    handleKycRejectionReason(event) {
        const reason =
            event.detail?.value ??
            event.target?.value ??
            '';

        this.kycRejectionReason =
            reason;

        if (!this.preview) {
            return;
        }

        this.preview = {
            ...this.preview,

            changes:
                (
                    this.preview.changes ||
                    []
                ).map(
                    item =>
                        item.isActionable ===
                            true &&
                        this.kycDecision ===
                            'Reject'
                            ? {
                                ...item,

                                rejectionReasonInput:
                                    reason
                            }
                            : item
                )
        };

        this.fieldDecisionError =
            '';
    }

    resetBCAddressDecisionState() {
        this.bcAddressDecision =
            '';

        this.bcAddressRejectionReason =
            '';
    }

    handleBCAddressDecision(event) {
        const decision =
            event.detail?.value ||
            event.target?.value ||
            '';

        this.bcAddressDecision =
            decision;

        if (
            decision !==
            'Reject'
        ) {
            this.bcAddressRejectionReason =
                '';
        }

        if (!this.preview) {
            return;
        }

        this.preview = {
            ...this.preview,

            changes:
                (
                    this.preview.changes ||
                    []
                ).map(
                    item => {
                        if (
                            item.isActionable !==
                                true ||
                            item.bcControlledAddress !==
                                true
                        ) {
                            return item;
                        }

                        return {
                            ...item,

                            decision,

                            isRejectedDecision:
                                decision ===
                                'Reject',

                            rejectionReasonInput:
                                decision ===
                                    'Reject'
                                    ? this.bcAddressRejectionReason
                                    : ''
                        };
                    }
                )
        };

        this.fieldDecisionError =
            '';
    }

    handleBCAddressRejectionReason(event) {
        const reason =
            event.detail?.value ??
            event.target?.value ??
            '';

        this.bcAddressRejectionReason =
            reason;

        if (!this.preview) {
            return;
        }

        this.preview = {
            ...this.preview,

            changes:
                (
                    this.preview.changes ||
                    []
                ).map(
                    item =>
                        item.isActionable ===
                            true &&
                        item.bcControlledAddress ===
                            true
                            ? {
                                ...item,

                                rejectionReasonInput:
                                    reason
                            }
                            : item
                )
        };

        this.fieldDecisionError =
            '';
    }

    handleItemDecision(event) {
        const changeItemId =
            event.currentTarget
                ?.dataset
                ?.itemId;

        const decision =
            event.detail?.value ||
            event.target?.value ||
            '';

        if (
            !changeItemId ||
            !this.preview
        ) {
            return;
        }

        this.preview = {
            ...this.preview,

            changes:
                this.preview.changes.map(
                    item => {
                        if (
                            item.changeItemId !==
                            changeItemId
                        ) {
                            return item;
                        }

                        return {
                            ...item,

                            decision,

                            isRejectedDecision:
                                decision ===
                                'Reject',

                            rejectionReasonInput:
                                decision ===
                                    'Reject'
                                    ? item.rejectionReasonInput
                                    : ''
                        };
                    }
                )
        };

        this.fieldDecisionError =
            '';
    }

    handleItemRejectionReason(event) {
        const changeItemId =
            event.currentTarget
                ?.dataset
                ?.itemId;

        const reason =
            event.detail?.value ??
            event.target?.value ??
            '';

        if (
            !changeItemId ||
            !this.preview
        ) {
            return;
        }

        this.preview = {
            ...this.preview,

            changes:
                this.preview.changes.map(
                    item =>
                        item.changeItemId ===
                            changeItemId
                            ? {
                                ...item,

                                rejectionReasonInput:
                                    reason
                            }
                            : item
                )
        };

        this.fieldDecisionError =
            '';
    }

    async handleSubmitFieldDecisions() {
        if (
            this.fieldDecisionSubmitDisabled ||
            !this.preview
                ?.approvalTransactionId
        ) {
            return;
        }

        const actionable =
            (
                this.preview?.changes ||
                []
            ).filter(
                item =>
                    item.isActionable ===
                    true
            );

        const decisions =
            actionable.map(
                item => ({
                    changeItemId:
                        item.changeItemId,

                    decision:
                        item.decision,

                    rejectionReason:
                        item.decision ===
                            'Reject'
                            ? String(
                                item.rejectionReasonInput ||
                                ''
                            ).trim()
                            : null
                })
            );

        this.isActionLoading =
            true;

        this.fieldDecisionError =
            '';

        try {
            const result =
                await submitFieldDecisions({
                    approvalTransactionId:
                        this.preview
                            .approvalTransactionId,

                    decisionsJson:
                        JSON.stringify(
                            decisions
                        ),

                    comments:
                        String(
                            this.approvalComments ||
                            ''
                        ).trim()
                });

            this.showToast(
                this.preview?.isKycRequest ===
                    true
                    ? (
                        result?.approvalStatus ===
                            'Returned'
                            ? 'KYC Request Returned'
                            : 'KYC Decision Submitted'
                    )
                    : (
                        result?.approvalStatus ===
                            'Returned'
                            ? 'Fields Rejected'
                            : this.preview?.isAdminOverride
                                ? 'Admin Field Decisions Submitted'
                                : 'Field Decisions Submitted'
                    ),

                result?.message ||
                    (
                        this.preview?.isKycRequest ===
                            true
                            ? 'The atomic KYC approval decision was submitted successfully.'
                            : 'Field approval decisions were submitted successfully.'
                    ),

                'success'
            );

            this.preview =
                null;

            this.approvalComments =
                '';

            this.resetBCAddressDecisionState();
            this.resetKycDecisionState();

            await this.loadWorkspace();
        } catch (error) {
            this.fieldDecisionError =
                this.reduceError(
                    error
                );

            this.showToast(
                'Field Decision Submission Failed',
                this.fieldDecisionError,
                'error'
            );
        } finally {
            this.isActionLoading =
                false;
        }
    }

    handleClosePreview() {
        if (
            this.isActionLoading
        ) {
            return;
        }

        this.handleCloseSupportingDocumentPreview();

        this.preview =
            null;

        this.approvalComments =
            '';

        this.fieldDecisionError =
            '';

        this.resetPhoneLookupState();
        this.resetBCAddressDecisionState();
        this.resetKycDecisionState();

        this.isPreviewLoading =
            false;

        this.isRefreshingPreview =
            false;
    }

    handleApprovalComments(event) {
        this.approvalComments =
            event.detail?.value ??
            event.target?.value ??
            '';
    }

    showToast(
        title,
        message,
        variant
    ) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,

                mode:
                    variant ===
                        'error'
                        ? 'sticky'
                        : 'dismissable'
            })
        );
    }

    reduceError(error) {
        if (
            Array.isArray(
                error?.body
            )
        ) {
            return error.body
                .map(
                    item =>
                        item.message
                )
                .filter(
                    Boolean
                )
                .join(
                    ', '
                );
        }

        const pageErrors =
            error?.body
                ?.output
                ?.errors ||
            [];

        if (
            pageErrors.length
        ) {
            return pageErrors
                .map(
                    item =>
                        item.message
                )
                .filter(
                    Boolean
                )
                .join(
                    ', '
                );
        }

        const fieldErrors =
            error?.body
                ?.output
                ?.fieldErrors ||
            {};

        const fieldMessages =
            Object.values(
                fieldErrors
            )
                .flat()
                .map(
                    item =>
                        item.message
                )
                .filter(
                    Boolean
                );

        if (
            fieldMessages.length
        ) {
            return fieldMessages.join(
                ', '
            );
        }

        return (
            error?.body?.message ||
            error?.message ||
            'An unexpected error occurred in the Customer Approval Workspace.'
        );
    }
}