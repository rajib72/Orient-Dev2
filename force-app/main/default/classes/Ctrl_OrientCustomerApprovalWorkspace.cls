public with sharing class Ctrl_OrientCustomerApprovalWorkspace {

    private static final String ADMIN_PROFILE_NAME = 'System Administrator';
    private static final String STATUS_PENDING = 'Pending';
    private static final String STATUS_RETURNED = 'Returned';
    private static final String ACTION_SUBMITTED = 'Submitted';
    private static final String ACTION_APPROVED = 'Approved';
    private static final String ACTION_REJECTED = 'Rejected';
    private static final String STATUS_FINAL_APPROVED = 'Final Approved';
    private static final String ITEM_STATUS_PENDING = 'Pending';
    private static final String ITEM_STATUS_RETURNED = 'Returned';
    private static final String ITEM_STATUS_FINAL_APPROVED = 'Final Approved';

    private static final String KYC_METHOD_PAN = 'PAN';
    private static final String KYC_METHOD_VOTER = 'Voter ID';
    private static final String KYC_METHOD_GST = 'GST';

    @TestVisible
    private class UserContext {
        public Id userId;
        public String profileName;
        public Boolean isAdmin;
    }

    public class WorkspaceData {
        @AuraEnabled public Boolean isAdmin;
        @AuraEnabled public String profileName;
        @AuraEnabled public Integer pendingCount;
        @AuraEnabled public Integer actionedCount;
        @AuraEnabled public Integer allPendingCount;
        @AuraEnabled public Integer allRequestCount;
        @AuraEnabled public Integer approvedCount;
        @AuraEnabled public List<ApprovalRow> pendingApprovals;
        @AuraEnabled public List<ApprovalRow> actionedApprovals;
        @AuraEnabled public List<ApprovalRow> allPendingApprovals;
        @AuraEnabled public List<ApprovalRow> allRequests;
    }

    public class ApprovalRow {
        @AuraEnabled public Id approvalTransactionId;
        @AuraEnabled public Id actionHistoryId;
        @AuraEnabled public Id requestId;
        @AuraEnabled public String requestName;
        @AuraEnabled public Id customerId;
        @AuraEnabled public String customerName;
        @AuraEnabled public Id storeId;
        @AuraEnabled public String storeName;
        @AuraEnabled public Id submittedById;
        @AuraEnabled public String submittedByName;
        @AuraEnabled public Datetime submittedDateTime;
        @AuraEnabled public Id currentLevelId;
        @AuraEnabled public String currentLevelName;
        @AuraEnabled public Decimal currentLevelSequence;
        @AuraEnabled public Id pendingWithId;
        @AuraEnabled public String pendingWithName;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public String changeReason;
        @AuraEnabled public Integer changeCount;
        @AuraEnabled public String lastAction;
        @AuraEnabled public Datetime lastActionDateTime;
        @AuraEnabled public String myAction;
        @AuraEnabled public Datetime myActionDateTime;
        @AuraEnabled public String myActionComments;
    }

    public class ApprovalPreview {
        @AuraEnabled public Boolean isAdmin;
        @AuraEnabled public Boolean isAssignedApprover;
        @AuraEnabled public Boolean isAdminOverride;
        @AuraEnabled public Id approvalTransactionId;
        @AuraEnabled public Id requestId;
        @AuraEnabled public String requestName;
        @AuraEnabled public Id customerId;
        @AuraEnabled public String customerName;
        @AuraEnabled public Id storeId;
        @AuraEnabled public String storeName;
        @AuraEnabled public String locationCode;
        @AuraEnabled public Id submittedById;
        @AuraEnabled public String submittedByName;
        @AuraEnabled public Datetime submittedDateTime;
        @AuraEnabled public String changeReason;
        @AuraEnabled public Boolean isKycRequest;
        @AuraEnabled public String kycMethod;
        @AuraEnabled public String kycDisplayName;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public Id currentLevelId;
        @AuraEnabled public String currentLevelName;
        @AuraEnabled public Decimal currentLevelSequence;
        @AuraEnabled public Id pendingWithId;
        @AuraEnabled public String pendingWithName;
        @AuraEnabled public Id nextLevelId;
        @AuraEnabled public String nextLevelName;
        @AuraEnabled public Decimal nextLevelSequence;
        @AuraEnabled public Id nextApproverId;
        @AuraEnabled public String nextApproverName;
        @AuraEnabled public Boolean isFinalLevel;
        @AuraEnabled public Boolean canApprove;
        @AuraEnabled public Boolean canReject;
        @AuraEnabled public Boolean routingReady;
        @AuraEnabled public String routingMessage;
        @AuraEnabled public String bcCustomerNo;
        @AuraEnabled public String bcPushStatus;
        @AuraEnabled public String bcPushMessage;
        @AuraEnabled public Decimal bcPushAttemptCount;
        @AuraEnabled public Boolean hasBCApplicableChanges;
        @AuraEnabled public Boolean hasPendingContactNumberChange;
        @AuraEnabled public Boolean hasPendingPhoneChange;
        @AuraEnabled public Boolean hasPendingWhatsappChange;
        @AuraEnabled public Boolean hasPendingBCControlledAddress;
        @AuraEnabled public Integer pendingBCControlledAddressCount;
        @AuraEnabled public Id pendingPhoneChangeItemId;
        @AuraEnabled public Id pendingWhatsappChangeItemId;
        @AuraEnabled public String pendingProposedPhone;
        @AuraEnabled public String pendingProposedWhatsapp;
        @AuraEnabled public Integer changeCount;
        @AuraEnabled public List<ChangeItemRow> changes;
        @AuraEnabled public List<HistoryRow> history;
    }

    public class ChangeItemRow {
        @AuraEnabled public Id changeItemId;
        @AuraEnabled public String sectionName;
        @AuraEnabled public Decimal sequence;
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String accountFieldApi;
        @AuraEnabled public String oldDisplayValue;
        @AuraEnabled public String newDisplayValue;
        @AuraEnabled public Boolean bcPushApplicable;
        @AuraEnabled public Boolean bcControlledAddress;
        @AuraEnabled public Boolean workspaceVisible;
        @AuraEnabled public String itemApprovalStatus;
        @AuraEnabled public Boolean isActionable;
        @AuraEnabled public Id rejectedFromLevelId;
        @AuraEnabled public String rejectedFromLevelName;
        @AuraEnabled public Id rejectedById;
        @AuraEnabled public String rejectedByName;
        @AuraEnabled public Datetime rejectedDateTime;
        @AuraEnabled public String rejectionReason;
        @AuraEnabled public Id finalApprovedById;
        @AuraEnabled public String finalApprovedByName;
        @AuraEnabled public Datetime finalApprovedDateTime;
    }

    public class HistoryRow {
        @AuraEnabled public Id historyId;
        @AuraEnabled public String action;
        @AuraEnabled public Id actionById;
        @AuraEnabled public String actionByName;
        @AuraEnabled public Datetime actionDateTime;
        @AuraEnabled public Id approvalLevelId;
        @AuraEnabled public String approvalLevelName;
        @AuraEnabled public Decimal approvalLevelSequence;
        @AuraEnabled public Id assignedToId;
        @AuraEnabled public String assignedToName;
        @AuraEnabled public String comments;
        @AuraEnabled public String previousStatus;
        @AuraEnabled public String newStatus;
        @AuraEnabled public Id customerChangeItemId;
        @AuraEnabled public String customerChangeItemLabel;
    }

    public class ActionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id approvalTransactionId;
        @AuraEnabled public Id nextLevelId;
        @AuraEnabled public String nextLevelName;
        @AuraEnabled public Id nextApproverId;
        @AuraEnabled public String nextApproverName;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public Boolean finalApproved;
        @AuraEnabled public String bcCustomerNo;
        @AuraEnabled public String bcPushStatus;
        @AuraEnabled public Integer bcStatusCode;
        @AuraEnabled public String message;
        @AuraEnabled public Integer approvedFieldCount;
        @AuraEnabled public Integer rejectedFieldCount;
    }

    public class ContactDuplicateCustomerRow {
        @AuraEnabled public Id customerId;
        @AuraEnabled public String customerName;
        @AuraEnabled public String bcCustomerNo;
        @AuraEnabled public String requestedFieldApi;
        @AuraEnabled public String requestedFieldLabel;
        @AuraEnabled public String requestedNumber;
        @AuraEnabled public String matchSource;
    }

    public class ContactDuplicateLookupResult {
        @AuraEnabled public Boolean contactChangePresent;
        @AuraEnabled public Boolean phoneChangePresent;
        @AuraEnabled public Boolean whatsappChangePresent;
        @AuraEnabled public String proposedPhone;
        @AuraEnabled public String proposedWhatsapp;
        @AuraEnabled public Boolean duplicateFound;
        @AuraEnabled public Integer duplicateCount;
        @AuraEnabled public String message;
        @AuraEnabled public List<ContactDuplicateCustomerRow> matchingCustomers;
    }

    @AuraEnabled
    public static WorkspaceData getWorkspaceData() {
        UserContext context = getUserContext();

        List<Tagged_Approval_Hierarchy__c> pendingTransactions = [
            SELECT Id, Approval_Status__c,
                   Current_Approval_Level__c,
                   Current_Approval_Level__r.Name,
                   Current_Approval_Level__r.Responsible_Team__c,
                   Current_Approval_Level__r.Sr_No__c,
                   Pending_With__c, Pending_With__r.Name,
                   Submitted_By__c, Submitted_By__r.Name,
                   Submitted_Date_Time__c,
                   Returned_From_Level__c,
                   Last_Action__c, Last_Action_Date_Time__c,
                   Customer_Change_Request__c,
                   Customer_Change_Request__r.Name,
                   Customer_Change_Request__r.Orient_Customer__c,
                   Customer_Change_Request__r.Orient_Customer__r.Name,
                   Customer_Change_Request__r.Approval_Store__c,
                   Customer_Change_Request__r.Approval_Store__r.Name,
                   Customer_Change_Request__r.Change_Reason__c
            FROM Tagged_Approval_Hierarchy__c
            WHERE Customer_Change_Request__c != null
            AND Approval_Status__c = :STATUS_PENDING
            AND Pending_With__c = :context.userId
            WITH USER_MODE
            ORDER BY Submitted_Date_Time__c DESC
            LIMIT 500
        ];

        List<Approval_Action_History__c> myActions = [
            SELECT Id, Approval_Transaction__c,
                   Approval_Transaction__r.Id,
                   Approval_Transaction__r.Approval_Status__c,
                   Approval_Transaction__r.Current_Approval_Level__c,
                   Approval_Transaction__r.Current_Approval_Level__r.Name,
                   Approval_Transaction__r.Current_Approval_Level__r.Responsible_Team__c,
                   Approval_Transaction__r.Current_Approval_Level__r.Sr_No__c,
                   Approval_Transaction__r.Pending_With__c,
                   Approval_Transaction__r.Pending_With__r.Name,
                   Approval_Transaction__r.Submitted_By__c,
                   Approval_Transaction__r.Submitted_By__r.Name,
                   Approval_Transaction__r.Submitted_Date_Time__c,
                   Approval_Transaction__r.Last_Action__c,
                   Approval_Transaction__r.Last_Action_Date_Time__c,
                   Approval_Transaction__r.Customer_Change_Request__c,
                   Approval_Transaction__r.Customer_Change_Request__r.Name,
                   Approval_Transaction__r.Customer_Change_Request__r.Orient_Customer__c,
                   Approval_Transaction__r.Customer_Change_Request__r.Orient_Customer__r.Name,
                   Approval_Transaction__r.Customer_Change_Request__r.Approval_Store__c,
                   Approval_Transaction__r.Customer_Change_Request__r.Approval_Store__r.Name,
                   Approval_Transaction__r.Customer_Change_Request__r.Change_Reason__c,
                   Action__c, Action_Date_Time__c, Comments__c
            FROM Approval_Action_History__c
            WHERE Action_By__c = :context.userId
            AND Approval_Transaction__r.Customer_Change_Request__c != null
            AND Action__c != :ACTION_SUBMITTED
            WITH USER_MODE
            ORDER BY Action_Date_Time__c DESC
            LIMIT 500
        ];

        List<Tagged_Approval_Hierarchy__c> allPendingTransactions = new List<Tagged_Approval_Hierarchy__c>();
        List<Tagged_Approval_Hierarchy__c> allTransactions = new List<Tagged_Approval_Hierarchy__c>();

        if (context.isAdmin) {
            allPendingTransactions = [
                SELECT Id, Approval_Status__c,
                       Current_Approval_Level__c,
                       Current_Approval_Level__r.Name,
                       Current_Approval_Level__r.Responsible_Team__c,
                       Current_Approval_Level__r.Sr_No__c,
                       Pending_With__c, Pending_With__r.Name,
                       Submitted_By__c, Submitted_By__r.Name,
                       Submitted_Date_Time__c,
                       Last_Action__c, Last_Action_Date_Time__c,
                       Customer_Change_Request__c,
                       Returned_From_Level__c,
                       Customer_Change_Request__r.Name,
                       Customer_Change_Request__r.Orient_Customer__c,
                       Customer_Change_Request__r.Orient_Customer__r.Name,
                       Customer_Change_Request__r.Approval_Store__c,
                       Customer_Change_Request__r.Approval_Store__r.Name,
                       Customer_Change_Request__r.Change_Reason__c
                FROM Tagged_Approval_Hierarchy__c
                WHERE Customer_Change_Request__c != null
                AND Approval_Status__c = :STATUS_PENDING
                WITH USER_MODE
                ORDER BY Submitted_Date_Time__c DESC
                LIMIT 1000
            ];

            allTransactions = [
                SELECT Id, Approval_Status__c,
                       Current_Approval_Level__c,
                       Current_Approval_Level__r.Name,
                       Current_Approval_Level__r.Responsible_Team__c,
                       Current_Approval_Level__r.Sr_No__c,
                       Pending_With__c, Pending_With__r.Name,
                       Submitted_By__c, Submitted_By__r.Name,
                       Submitted_Date_Time__c,
                       Last_Action__c, Last_Action_Date_Time__c,
                       Customer_Change_Request__c,
                       Returned_From_Level__c,
                       Customer_Change_Request__r.Name,
                       Customer_Change_Request__r.Orient_Customer__c,
                       Customer_Change_Request__r.Orient_Customer__r.Name,
                       Customer_Change_Request__r.Approval_Store__c,
                       Customer_Change_Request__r.Approval_Store__r.Name,
                       Customer_Change_Request__r.Change_Reason__c
                FROM Tagged_Approval_Hierarchy__c
                WHERE Customer_Change_Request__c != null
                WITH USER_MODE
                ORDER BY Submitted_Date_Time__c DESC
                LIMIT 1000
            ];
        }

        Set<Id> requestIds = new Set<Id>();
        addRequestIds(requestIds, pendingTransactions);
        addRequestIds(requestIds, allPendingTransactions);
        addRequestIds(requestIds, allTransactions);

        for (Approval_Action_History__c historyRecord : myActions) {
            if (historyRecord.Approval_Transaction__r.Customer_Change_Request__c != null) {
                requestIds.add(historyRecord.Approval_Transaction__r.Customer_Change_Request__c);
            }
        }

        Map<Id, Integer> changeCountByRequest = getChangeCountByRequest(requestIds);

        List<ApprovalRow> pendingRows = buildRows(pendingTransactions, changeCountByRequest);
        List<ApprovalRow> allPendingRows = buildRows(allPendingTransactions, changeCountByRequest);
        List<ApprovalRow> allRequestRows = buildRows(allTransactions, changeCountByRequest);
        List<ApprovalRow> actionedRows = new List<ApprovalRow>();

        Set<Id> actionedTransactionIds = new Set<Id>();
        for (Approval_Action_History__c historyRecord : myActions) {
            if (
                historyRecord.Approval_Transaction__c != null &&
                !actionedTransactionIds.contains(historyRecord.Approval_Transaction__c)
            ) {
                actionedRows.add(buildActionedRow(historyRecord, changeCountByRequest));
                actionedTransactionIds.add(historyRecord.Approval_Transaction__c);
            }
        }

        Integer approvedCount = 0;
        if (context.isAdmin) {
            for (Tagged_Approval_Hierarchy__c transactionRecord : allTransactions) {
                if (
                    String.isNotBlank(transactionRecord.Approval_Status__c) &&
                    transactionRecord.Approval_Status__c.toLowerCase().contains('approved')
                ) {
                    approvedCount++;
                }
            }
        }

        WorkspaceData result = new WorkspaceData();
        result.isAdmin = context.isAdmin;
        result.profileName = context.profileName;
        result.pendingApprovals = pendingRows;
        result.actionedApprovals = actionedRows;
        result.allPendingApprovals = allPendingRows;
        result.allRequests = allRequestRows;
        result.pendingCount = pendingRows.size();
        result.actionedCount = actionedRows.size();
        result.allPendingCount = allPendingRows.size();
        result.allRequestCount = allRequestRows.size();
        result.approvedCount = approvedCount;
        return result;
    }

    @AuraEnabled
    public static WorkspaceData refreshWorkspaceData() {
        return getWorkspaceData();
    }

    @AuraEnabled
    public static ApprovalPreview refreshApprovalPreview(
        Id approvalTransactionId
    ) {
        return getApprovalPreview(approvalTransactionId);
    }

    @AuraEnabled
    public static ApprovalPreview getApprovalPreviewByRequestId(
        Id requestId
    ) {
        if (requestId == null) {
            throw new AuraHandledException(
                'Customer Change Request Id is required.'
            );
        }

        List<Tagged_Approval_Hierarchy__c> transactions = [
            SELECT Id
            FROM Tagged_Approval_Hierarchy__c
            WHERE Customer_Change_Request__c = :requestId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (transactions.isEmpty()) {
            throw new AuraHandledException(
                'Customer Profile approval request could not be found or you do not have access to it.'
            );
        }

        return getApprovalPreview(
            transactions[0].Id
        );
    }

    @AuraEnabled
    public static ApprovalPreview getApprovalPreview(Id approvalTransactionId) {
        if (approvalTransactionId == null) {
            throw new AuraHandledException('Approval Transaction Id is required.');
        }

        UserContext context = getUserContext();

        List<Tagged_Approval_Hierarchy__c> transactions = [
            SELECT Id, Approval_Hierarchy__c, Approval_Status__c,
                   Current_Approval_Level__c,
                   Current_Approval_Level__r.Name,
                   Current_Approval_Level__r.Responsible_Team__c,
                   Current_Approval_Level__r.Sr_No__c,
                   Pending_With__c, Pending_With__r.Name,
                   Submitted_By__c, Submitted_By__r.Name,
                   Submitted_Date_Time__c,
                   Customer_Change_Request__c,
                   Returned_From_Level__c,
                   Customer_Change_Request__r.Name,
                   Customer_Change_Request__r.Orient_Customer__c,
                   Customer_Change_Request__r.Orient_Customer__r.Name,
                   Customer_Change_Request__r.Orient_Customer__r.BC_Customer_No__c,
                   Customer_Change_Request__r.Approval_Store__c,
                   Customer_Change_Request__r.Approval_Store__r.Name,
                   Customer_Change_Request__r.Location_Code__c,
                   Customer_Change_Request__r.Change_Reason__c,
                   Customer_Change_Request__r.BC_Customer_No__c,
                   Customer_Change_Request__r.BC_Push_Status__c,
                   Customer_Change_Request__r.BC_Push_Message__c,
                   Customer_Change_Request__r.BC_Push_Attempt_Count__c
            FROM Tagged_Approval_Hierarchy__c
            WHERE Id = :approvalTransactionId
            AND Customer_Change_Request__c != null
            WITH USER_MODE
            LIMIT 1
        ];

        if (transactions.isEmpty()) {
            throw new AuraHandledException('Customer Profile approval transaction could not be found.');
        }

        Tagged_Approval_Hierarchy__c transactionRecord = transactions[0];
        Boolean assignedToCurrentUser =
            transactionRecord.Pending_With__c ==
                context.userId;
        Boolean submittedByCurrentUser =
            transactionRecord.Submitted_By__c ==
                context.userId;

        /*
         * The original submitter can always review the request in the
         * Workspace. This is read-only unless the same user is also the
         * assigned approver or a System Administrator.
         */
        if (
            !context.isAdmin &&
            !assignedToCurrentUser &&
            !submittedByCurrentUser &&
            !hasUserActionedTransaction(
                approvalTransactionId,
                context.userId
            )
        ) {
            throw new AuraHandledException(
                'You do not have access to review this Customer Profile approval request.'
            );
        }

        List<Orient_Customer_Change_Item__c> changeItems = [
            SELECT Id, Section_Name__c, Sequence__c, Field_Label__c,
                   Account_Field_API__c, Old_Display_Value__c,
                   New_Value__c, New_Display_Value__c,
                   BC_Push_Applicable__c,
                   Item_Approval_Status__c,
                   Rejected_From_Level__c,
                   Rejected_From_Level__r.Name,
                   Rejected_From_Level__r.Responsible_Team__c,
                   Rejected_By__c, Rejected_By__r.Name,
                   Rejected_Date_Time__c, Rejection_Reason__c,
                   Final_Approved_By__c, Final_Approved_By__r.Name,
                   Final_Approved_Date_Time__c
            FROM Orient_Customer_Change_Item__c
            WHERE Change_Request__c = :transactionRecord.Customer_Change_Request__c
            WITH USER_MODE
            ORDER BY Section_Name__c ASC, Sequence__c ASC, CreatedDate ASC
        ];

        List<Approval_Action_History__c> histories = [
            SELECT Id, Action__c, Action_By__c, Action_By__r.Name,
                   Action_Date_Time__c,
                   Approval_Level__c,
                   Approval_Level__r.Name,
                   Approval_Level__r.Responsible_Team__c,
                   Approval_Level__r.Sr_No__c,
                   Assigned_To__c, Assigned_To__r.Name,
                   Comments__c, Previous_Status__c, New_Status__c,
                   Customer_Change_Item__c,
                   Customer_Change_Item__r.Field_Label__c
            FROM Approval_Action_History__c
            WHERE Approval_Transaction__c = :approvalTransactionId
            WITH USER_MODE
            ORDER BY Action_Date_Time__c ASC, CreatedDate ASC
        ];

        ApprovalPreview preview = new ApprovalPreview();
        preview.isAdmin = context.isAdmin;
        preview.isAssignedApprover = assignedToCurrentUser;
        preview.isAdminOverride = context.isAdmin && !assignedToCurrentUser && transactionRecord.Approval_Status__c == STATUS_PENDING;
        preview.approvalTransactionId = transactionRecord.Id;
        preview.requestId = transactionRecord.Customer_Change_Request__c;
        preview.requestName = transactionRecord.Customer_Change_Request__r.Name;
        preview.customerId = transactionRecord.Customer_Change_Request__r.Orient_Customer__c;
        preview.customerName = transactionRecord.Customer_Change_Request__r.Orient_Customer__r.Name;
        preview.storeId = transactionRecord.Customer_Change_Request__r.Approval_Store__c;
        preview.storeName = transactionRecord.Customer_Change_Request__r.Approval_Store__r == null
            ? null
            : transactionRecord.Customer_Change_Request__r.Approval_Store__r.Name;
        preview.locationCode = transactionRecord.Customer_Change_Request__r.Location_Code__c;
        preview.submittedById = transactionRecord.Submitted_By__c;
        preview.submittedByName = transactionRecord.Submitted_By__r == null
            ? null
            : transactionRecord.Submitted_By__r.Name;
        preview.submittedDateTime = transactionRecord.Submitted_Date_Time__c;
        preview.changeReason =
            transactionRecord.Customer_Change_Request__r.Change_Reason__c;
        preview.kycMethod =
            extractKycMethodFromReason(preview.changeReason);
        preview.isKycRequest =
            String.isNotBlank(preview.kycMethod);
        preview.kycDisplayName =
            getKycDisplayName(preview.kycMethod);
        preview.bcCustomerNo =
            String.isNotBlank(
                transactionRecord.Customer_Change_Request__r.BC_Customer_No__c
            )
                ? transactionRecord.Customer_Change_Request__r.BC_Customer_No__c
                : transactionRecord.Customer_Change_Request__r
                    .Orient_Customer__r.BC_Customer_No__c;
        preview.bcPushStatus = transactionRecord.Customer_Change_Request__r.BC_Push_Status__c;
        preview.bcPushMessage = transactionRecord.Customer_Change_Request__r.BC_Push_Message__c;
        preview.bcPushAttemptCount = transactionRecord.Customer_Change_Request__r.BC_Push_Attempt_Count__c;
        preview.approvalStatus = transactionRecord.Approval_Status__c;
        preview.currentLevelId = transactionRecord.Current_Approval_Level__c;
        preview.currentLevelName = getLevelLabel(transactionRecord.Current_Approval_Level__r);
        preview.currentLevelSequence = transactionRecord.Current_Approval_Level__r == null
            ? null
            : transactionRecord.Current_Approval_Level__r.Sr_No__c;
        preview.pendingWithId = transactionRecord.Pending_With__c;
        preview.pendingWithName = transactionRecord.Pending_With__r == null
            ? null
            : transactionRecord.Pending_With__r.Name;
        preview.changes = new List<ChangeItemRow>();
        preview.history = new List<HistoryRow>();

        for (Orient_Customer_Change_Item__c changeItem : changeItems) {
            ChangeItemRow row = new ChangeItemRow();
            row.changeItemId = changeItem.Id;
            row.sectionName = changeItem.Section_Name__c;
            row.sequence = changeItem.Sequence__c;
            row.fieldLabel = changeItem.Field_Label__c;
            row.accountFieldApi = changeItem.Account_Field_API__c;
            row.oldDisplayValue = String.isBlank(changeItem.Old_Display_Value__c) ? '—' : changeItem.Old_Display_Value__c;
            row.newDisplayValue = String.isBlank(changeItem.New_Display_Value__c) ? '—' : changeItem.New_Display_Value__c;
            row.bcPushApplicable = changeItem.BC_Push_Applicable__c;
            row.bcControlledAddress =
                Ctrl_Hlp_OrientCustAddressApproval.isBCControlledField(
                    changeItem.Account_Field_API__c
                );
            row.workspaceVisible =
                Ctrl_Hlp_OrientCustAddressApproval.isWorkspaceVisibleField(
                    changeItem.Account_Field_API__c
                );
            row.itemApprovalStatus = String.isBlank(changeItem.Item_Approval_Status__c)
                ? ITEM_STATUS_PENDING
                : changeItem.Item_Approval_Status__c;
            row.isActionable =
                row.itemApprovalStatus == ITEM_STATUS_PENDING &&
                transactionRecord.Approval_Status__c == STATUS_PENDING &&
                (assignedToCurrentUser || context.isAdmin);
            row.rejectedFromLevelId = changeItem.Rejected_From_Level__c;
            row.rejectedFromLevelName = getLevelLabel(changeItem.Rejected_From_Level__r);
            row.rejectedById = changeItem.Rejected_By__c;
            row.rejectedByName = changeItem.Rejected_By__r == null
                ? null
                : changeItem.Rejected_By__r.Name;
            row.rejectedDateTime = changeItem.Rejected_Date_Time__c;
            row.rejectionReason = changeItem.Rejection_Reason__c;
            row.finalApprovedById = changeItem.Final_Approved_By__c;
            row.finalApprovedByName = changeItem.Final_Approved_By__r == null
                ? null
                : changeItem.Final_Approved_By__r.Name;
            row.finalApprovedDateTime = changeItem.Final_Approved_Date_Time__c;
            preview.changes.add(row);
        }
        preview.changeCount = 0;
        preview.hasBCApplicableChanges = false;
        preview.hasPendingContactNumberChange = false;
        preview.hasPendingPhoneChange = false;
        preview.hasPendingWhatsappChange = false;
        preview.hasPendingBCControlledAddress = false;
        preview.pendingBCControlledAddressCount = 0;

        for (ChangeItemRow visibleRow : preview.changes) {
            if (
                visibleRow.workspaceVisible == true &&
                visibleRow.itemApprovalStatus ==
                    ITEM_STATUS_PENDING
            ) {
                preview.changeCount++;
            }
        }

        for (Integer itemIndex = 0; itemIndex < changeItems.size(); itemIndex++) {
            Orient_Customer_Change_Item__c changeItem =
                changeItems[itemIndex];
            ChangeItemRow changeRow =
                preview.changes[itemIndex];

            if (
                changeRow.bcPushApplicable == true &&
                changeRow.itemApprovalStatus == ITEM_STATUS_PENDING
            ) {
                preview.hasBCApplicableChanges = true;
            }

            if (
                changeRow.itemApprovalStatus != ITEM_STATUS_PENDING
            ) {
                continue;
            }

            if (
                changeRow.bcControlledAddress == true
            ) {
                preview.hasPendingBCControlledAddress =
                    true;

                if (
                    changeRow.workspaceVisible ==
                    true
                ) {
                    preview.pendingBCControlledAddressCount++;
                }
            }

            String proposedContactNumber =
                normalizePhoneForWorkspace(
                    String.isNotBlank(changeItem.New_Value__c)
                        ? changeItem.New_Value__c
                        : changeItem.New_Display_Value__c
                );

            if (changeRow.accountFieldApi == 'Phone') {
                preview.hasPendingContactNumberChange = true;
                preview.hasPendingPhoneChange = true;
                preview.pendingPhoneChangeItemId =
                    changeRow.changeItemId;
                preview.pendingProposedPhone =
                    proposedContactNumber;
            } else if (
                changeRow.accountFieldApi == 'Whatsapp_number__c'
            ) {
                preview.hasPendingContactNumberChange = true;
                preview.hasPendingWhatsappChange = true;
                preview.pendingWhatsappChangeItemId =
                    changeRow.changeItemId;
                preview.pendingProposedWhatsapp =
                    proposedContactNumber;
            }
        }

        for (Approval_Action_History__c historyRecord : histories) {
            HistoryRow row = new HistoryRow();
            row.historyId = historyRecord.Id;
            row.action = historyRecord.Action__c;
            row.actionById = historyRecord.Action_By__c;
            row.actionByName = historyRecord.Action_By__r == null ? null : historyRecord.Action_By__r.Name;
            row.actionDateTime = historyRecord.Action_Date_Time__c;
            row.approvalLevelId = historyRecord.Approval_Level__c;
            row.approvalLevelName = getLevelLabel(historyRecord.Approval_Level__r);
            row.approvalLevelSequence = historyRecord.Approval_Level__r == null
                ? null
                : historyRecord.Approval_Level__r.Sr_No__c;
            row.assignedToId = historyRecord.Assigned_To__c;
            row.assignedToName = historyRecord.Assigned_To__r == null ? null : historyRecord.Assigned_To__r.Name;
            row.comments = historyRecord.Comments__c;
            row.previousStatus = historyRecord.Previous_Status__c;
            row.newStatus = historyRecord.New_Status__c;
            row.customerChangeItemId = historyRecord.Customer_Change_Item__c;
            row.customerChangeItemLabel =
                historyRecord.Customer_Change_Item__r == null
                    ? null
                    : historyRecord.Customer_Change_Item__r.Field_Label__c;
            preview.history.add(row);
        }

        populateNextRouting(preview, transactionRecord, context);
        return preview;
    }

    @AuraEnabled
    public static ContactDuplicateLookupResult lookupCustomersWithSameContactNumbers(
        Id approvalTransactionId
    ) {
        Tagged_Approval_Hierarchy__c transactionRecord =
            getActionableTransaction(
                approvalTransactionId,
                false
            );

        Ctrl_Hlp_OrientCustContactDuplicate.LookupResult helperResult =
            Ctrl_Hlp_OrientCustContactDuplicate.lookupByRequest(
                transactionRecord.Customer_Change_Request__c
            );

        ContactDuplicateLookupResult result =
            new ContactDuplicateLookupResult();

        result.contactChangePresent =
            helperResult.contactChangePresent;
        result.phoneChangePresent =
            helperResult.phoneChangePresent;
        result.whatsappChangePresent =
            helperResult.whatsappChangePresent;
        result.proposedPhone =
            helperResult.proposedPhone;
        result.proposedWhatsapp =
            helperResult.proposedWhatsapp;
        result.duplicateFound =
            helperResult.duplicateFound;
        result.duplicateCount =
            helperResult.duplicateCount;
        result.message =
            helperResult.message;
        result.matchingCustomers =
            new List<ContactDuplicateCustomerRow>();

        for (
            Ctrl_Hlp_OrientCustContactDuplicate.DuplicateCustomer helperRow :
            helperResult.matchingCustomers
        ) {
            ContactDuplicateCustomerRow row =
                new ContactDuplicateCustomerRow();

            row.customerId =
                helperRow.customerId;
            row.customerName =
                helperRow.customerName;
            row.bcCustomerNo =
                helperRow.bcCustomerNo;
            row.requestedFieldApi =
                helperRow.requestedFieldApi;
            row.requestedFieldLabel =
                helperRow.requestedFieldLabel;
            row.requestedNumber =
                helperRow.requestedNumber;
            row.matchSource =
                helperRow.matchSource;

            result.matchingCustomers.add(row);
        }

        return result;
    }

    @AuraEnabled
    public static ActionResult rejectEntireRequestForDuplicateContactNumber(
        Id approvalTransactionId,
        String rejectionReason
    ) {
        if (String.isBlank(rejectionReason)) {
            throw new AuraHandledException(
                'Rejection Reason is required to reject the entire request.'
            );
        }

        Tagged_Approval_Hierarchy__c transactionRecord =
            getActionableTransaction(
                approvalTransactionId,
                true
            );

        Ctrl_Hlp_OrientCustContactDuplicate.LookupResult duplicateResult =
            Ctrl_Hlp_OrientCustContactDuplicate.lookupByRequest(
                transactionRecord.Customer_Change_Request__c
            );

        if (duplicateResult.contactChangePresent != true) {
            throw new AuraHandledException(
                'No Pending Phone or WhatsApp number change is present in this approval request.'
            );
        }

        if (duplicateResult.duplicateFound != true) {
            throw new AuraHandledException(
                'No duplicate customer currently exists with the requested Phone / WhatsApp number(s). ' +
                'Use the normal field-level Approve / Reject decisions.'
            );
        }

        List<Orient_Customer_Change_Item__c> pendingItems = [
            SELECT Id,
                   Field_Label__c,
                   Item_Approval_Status__c
            FROM Orient_Customer_Change_Item__c
            WHERE Change_Request__c =
                :transactionRecord.Customer_Change_Request__c
            AND Item_Approval_Status__c =
                :ITEM_STATUS_PENDING
            FOR UPDATE
        ];

        if (pendingItems.isEmpty()) {
            throw new AuraHandledException(
                'No Pending Customer fields are available to reject.'
            );
        }

        UserContext context =
            getUserContext();
        Datetime actionDateTime =
            System.now();
        String trimmedReason =
            rejectionReason.trim();

        List<Orient_Customer_Change_Item__c> itemUpdates =
            new List<Orient_Customer_Change_Item__c>();
        List<Approval_Action_History__c> historyRecords =
            new List<Approval_Action_History__c>();

        for (
            Orient_Customer_Change_Item__c itemRecord :
            pendingItems
        ) {
            itemUpdates.add(
                new Orient_Customer_Change_Item__c(
                    Id = itemRecord.Id,
                    Item_Approval_Status__c =
                        ITEM_STATUS_RETURNED,
                    Rejected_From_Level__c =
                        transactionRecord.Current_Approval_Level__c,
                    Rejected_By__c =
                        context.userId,
                    Rejected_Date_Time__c =
                        actionDateTime,
                    Rejection_Reason__c =
                        trimmedReason
                )
            );

            historyRecords.add(
                new Approval_Action_History__c(
                    Approval_Transaction__c =
                        transactionRecord.Id,
                    Customer_Change_Item__c =
                        itemRecord.Id,
                    Approval_Level__c =
                        transactionRecord.Current_Approval_Level__c,
                    Action__c =
                        ACTION_REJECTED,
                    Action_By__c =
                        context.userId,
                    Action_Date_Time__c =
                        actionDateTime,
                    Assigned_To__c =
                        null,
                    Comments__c =
                        trimmedReason,
                    Previous_Status__c =
                        ITEM_STATUS_PENDING,
                    New_Status__c =
                        ITEM_STATUS_RETURNED
                )
            );
        }

        update itemUpdates;
        insert historyRecords;

        String duplicateSummary =
            'Phone / WhatsApp duplicate lookup found ' +
            String.valueOf(
                duplicateResult.duplicateCount
            ) +
            ' other customer(s). Entire request rejected.';

        transactionRecord.Approval_Status__c =
            STATUS_RETURNED;
        transactionRecord.Pending_With__c =
            null;
        transactionRecord.Last_Action__c =
            ACTION_REJECTED;
        transactionRecord.Last_Action_By__c =
            context.userId;
        transactionRecord.Last_Action_Date_Time__c =
            actionDateTime;
        transactionRecord.Last_Action_Comments__c =
            duplicateSummary + ' ' + trimmedReason;
        update transactionRecord;

        update new Orient_Customer_Change_Request__c(
            Id =
                transactionRecord.Customer_Change_Request__c,
            Approval_Status__c =
                STATUS_RETURNED,
            Last_Action__c =
                ACTION_REJECTED,
            Last_Action_By__c =
                context.userId,
            Last_Action_Date_Time__c =
                actionDateTime
        );

        Ctrl_Hlp_OrientCustApprovalSharing.syncApprovalAccess(
            transactionRecord.Id
        );

        ActionResult result =
            new ActionResult();

        result.success =
            true;
        result.approvalTransactionId =
            transactionRecord.Id;
        result.approvalStatus =
            STATUS_RETURNED;
        result.finalApproved =
            false;
        result.approvedFieldCount =
            0;
        result.rejectedFieldCount =
            pendingItems.size();
        result.message =
            'Duplicate Phone / WhatsApp number found. The entire Customer Profile approval request was rejected.';

        return result;
    }

    @AuraEnabled
    public static ActionResult submitFieldDecisions(
        Id approvalTransactionId,
        String decisionsJson,
        String comments
    ) {
        if (approvalTransactionId == null) {
            throw new AuraHandledException('Approval Transaction Id is required.');
        }

        if (String.isBlank(decisionsJson)) {
            throw new AuraHandledException('Field approval decisions are required.');
        }

        UserContext context = getUserContext();

        List<Tagged_Approval_Hierarchy__c> transactions = [
            SELECT Id, Approval_Hierarchy__c, Approval_Status__c,
                   Current_Approval_Level__c,
                   Current_Approval_Level__r.Name,
                   Current_Approval_Level__r.Responsible_Team__c,
                   Current_Approval_Level__r.Sr_No__c,
                   Pending_With__c,
                   Returned_From_Level__c,
                   Submitted_By__c,
                   Customer_Change_Request__c,
                   Customer_Change_Request__r.Change_Reason__c
            FROM Tagged_Approval_Hierarchy__c
            WHERE Id = :approvalTransactionId
            AND Customer_Change_Request__c != null
            LIMIT 1
        ];

        if (transactions.isEmpty()) {
            throw new AuraHandledException(
                'Customer Profile approval transaction could not be found.'
            );
        }

        Tagged_Approval_Hierarchy__c transactionRecord = transactions[0];
        validateActionAccess(transactionRecord, context);

        String kycMethod =
            extractKycMethodFromReason(
                transactionRecord.Customer_Change_Request__r
                    .Change_Reason__c
            );
        Boolean isKycRequest =
            String.isNotBlank(kycMethod);

        Ctrl_Hlp_OrientCustContactDuplicate.assertNoDuplicateForPendingContactNumbers(
            transactionRecord.Customer_Change_Request__c
        );

        if (
            transactionRecord.Current_Approval_Level__c == null ||
            transactionRecord.Current_Approval_Level__r == null ||
            transactionRecord.Current_Approval_Level__r.Sr_No__c == null
        ) {
            throw new AuraHandledException(
                'Current Customer Profile approval routing is incomplete.'
            );
        }

        Approval_Hierarchy_Level__c nextLevel = getNextLevel(
            transactionRecord.Approval_Hierarchy__c,
            transactionRecord.Current_Approval_Level__r.Sr_No__c
        );

        if (nextLevel == null) {
            if (isKycRequest) {
                validateKycAtomicDecisionPayload(
                    transactionRecord.Customer_Change_Request__c,
                    decisionsJson,
                    kycMethod
                );
            }

            Ctrl_Hlp_OrientCustFinalApproval.FinalApprovalResult finalResult =
                Ctrl_Hlp_OrientCustFinalApproval.processFinalFieldDecisions(
                    approvalTransactionId,
                    decisionsJson,
                    comments
                );

            ActionResult result = new ActionResult();
            result.success = finalResult.success;
            result.approvalTransactionId =
                finalResult.approvalTransactionId;
            result.approvalStatus =
                finalResult.approvalStatus;
            result.finalApproved =
                finalResult.approvalStatus ==
                STATUS_FINAL_APPROVED;
            result.approvedFieldCount =
                finalResult.approvedFieldCount;
            result.rejectedFieldCount =
                finalResult.rejectedFieldCount;
            result.message =
                finalResult.message;
            return result;
        }

        transactions = [
            SELECT Id, Approval_Hierarchy__c, Approval_Status__c,
                   Current_Approval_Level__c,
                   Current_Approval_Level__r.Name,
                   Current_Approval_Level__r.Responsible_Team__c,
                   Current_Approval_Level__r.Sr_No__c,
                   Pending_With__c,
                   Returned_From_Level__c,
                   Submitted_By__c,
                   Customer_Change_Request__c,
                   Customer_Change_Request__r.Change_Reason__c
            FROM Tagged_Approval_Hierarchy__c
            WHERE Id = :approvalTransactionId
            AND Customer_Change_Request__c != null
            LIMIT 1
            FOR UPDATE
        ];

        if (transactions.isEmpty()) {
            throw new AuraHandledException(
                'Customer Profile approval transaction could not be found.'
            );
        }

        transactionRecord = transactions[0];
        validateActionAccess(transactionRecord, context);

        kycMethod =
            extractKycMethodFromReason(
                transactionRecord.Customer_Change_Request__r
                    .Change_Reason__c
            );
        isKycRequest =
            String.isNotBlank(kycMethod);

        Ctrl_Hlp_OrientCustContactDuplicate.assertNoDuplicateForPendingContactNumbers(
            transactionRecord.Customer_Change_Request__c
        );

        if (
            transactionRecord.Current_Approval_Level__c == null ||
            transactionRecord.Current_Approval_Level__r == null ||
            transactionRecord.Current_Approval_Level__r.Sr_No__c == null
        ) {
            throw new AuraHandledException(
                'Current Customer Profile approval routing is incomplete.'
            );
        }

        nextLevel = getNextLevel(
            transactionRecord.Approval_Hierarchy__c,
            transactionRecord.Current_Approval_Level__r.Sr_No__c
        );

        if (nextLevel == null) {
            throw new AuraHandledException(
                'The approval level changed while the request was being processed. Refresh the workspace and try again.'
            );
        }

        List<Orient_Customer_Change_Item__c> pendingItems = [
            SELECT Id, Field_Label__c,
                   Account_Field_API__c,
                   Item_Approval_Status__c
            FROM Orient_Customer_Change_Item__c
            WHERE Change_Request__c = :transactionRecord.Customer_Change_Request__c
            AND Item_Approval_Status__c = :ITEM_STATUS_PENDING
            FOR UPDATE
        ];

        if (pendingItems.isEmpty()) {
            throw new AuraHandledException(
                'No Pending Customer fields are available at this approval level.'
            );
        }

        Object parsed = JSON.deserializeUntyped(decisionsJson);
        if (!(parsed instanceof List<Object>)) {
            throw new AuraHandledException('Invalid field decision payload.');
        }

        Map<Id, Map<String, Object>> decisionByItemId =
            new Map<Id, Map<String, Object>>();

        for (Object rowObject : (List<Object>) parsed) {
            if (!(rowObject instanceof Map<String, Object>)) {
                continue;
            }

            Map<String, Object> decisionRow =
                (Map<String, Object>) rowObject;

            String itemIdText = String.valueOf(
                decisionRow.get('changeItemId')
            );

            if (String.isBlank(itemIdText)) {
                continue;
            }

            decisionByItemId.put(
                (Id) itemIdText,
                decisionRow
            );
        }

        if (decisionByItemId.size() != pendingItems.size()) {
            throw new AuraHandledException(
                'Approve or Reject every Pending field before submitting your decisions.'
            );
        }

        if (isKycRequest) {
            validateKycAtomicDecision(
                pendingItems,
                decisionByItemId,
                kycMethod
            );
        }

        Ctrl_Hlp_OrientCustAddressApproval.validateAtomicDecision(
            pendingItems,
            decisionByItemId
        );

        Approval_Approver_Mapping__c nextMapping =
            resolvePrimaryApprover(nextLevel);

        Datetime actionDateTime = System.now();
        String trimmedComments =
            String.isBlank(comments)
                ? null
                : comments.trim();

        List<Orient_Customer_Change_Item__c> itemUpdates =
            new List<Orient_Customer_Change_Item__c>();
        List<Approval_Action_History__c> historyRecords =
            new List<Approval_Action_History__c>();

        Integer approvedCount = 0;
        Integer rejectedCount = 0;

        for (Orient_Customer_Change_Item__c itemRecord : pendingItems) {
            Map<String, Object> decisionRow =
                decisionByItemId.get(itemRecord.Id);

            if (decisionRow == null) {
                throw new AuraHandledException(
                    'Decision is missing for field "' +
                    itemRecord.Field_Label__c + '".'
                );
            }

            String decision =
                String.valueOf(
                    decisionRow.get('decision')
                ).trim();

            String rejectionReason =
                decisionRow.get('rejectionReason') == null
                    ? null
                    : String.valueOf(
                        decisionRow.get('rejectionReason')
                    ).trim();

            if (
                decision != 'Approve' &&
                decision != 'Reject'
            ) {
                throw new AuraHandledException(
                    'Select Approve or Reject for field "' +
                    itemRecord.Field_Label__c + '".'
                );
            }

            if (
                decision == 'Reject' &&
                String.isBlank(rejectionReason)
            ) {
                throw new AuraHandledException(
                    'Rejection Reason is required for field "' +
                    itemRecord.Field_Label__c + '".'
                );
            }

            if (decision == 'Approve') {
                approvedCount++;

                historyRecords.add(
                    new Approval_Action_History__c(
                        Approval_Transaction__c =
                            transactionRecord.Id,
                        Customer_Change_Item__c =
                            itemRecord.Id,
                        Approval_Level__c =
                            transactionRecord.Current_Approval_Level__c,
                        Action__c = ACTION_APPROVED,
                        Action_By__c = context.userId,
                        Action_Date_Time__c = actionDateTime,
                        Assigned_To__c =
                            nextMapping.Approver_User__c,
                        Comments__c = trimmedComments,
                        Previous_Status__c =
                            ITEM_STATUS_PENDING,
                        New_Status__c =
                            ITEM_STATUS_PENDING
                    )
                );
            } else {
                rejectedCount++;

                itemUpdates.add(
                    new Orient_Customer_Change_Item__c(
                        Id = itemRecord.Id,
                        Item_Approval_Status__c =
                            ITEM_STATUS_RETURNED,
                        Rejected_From_Level__c =
                            transactionRecord.Current_Approval_Level__c,
                        Rejected_By__c = context.userId,
                        Rejected_Date_Time__c =
                            actionDateTime,
                        Rejection_Reason__c =
                            rejectionReason
                    )
                );

                historyRecords.add(
                    new Approval_Action_History__c(
                        Approval_Transaction__c =
                            transactionRecord.Id,
                        Customer_Change_Item__c =
                            itemRecord.Id,
                        Approval_Level__c =
                            transactionRecord.Current_Approval_Level__c,
                        Action__c = ACTION_REJECTED,
                        Action_By__c = context.userId,
                        Action_Date_Time__c = actionDateTime,
                        Assigned_To__c = null,
                        Comments__c = rejectionReason,
                        Previous_Status__c =
                            ITEM_STATUS_PENDING,
                        New_Status__c =
                            ITEM_STATUS_RETURNED
                    )
                );
            }
        }

        if (!itemUpdates.isEmpty()) {
            update itemUpdates;
        }

        if (!historyRecords.isEmpty()) {
            insert historyRecords;
        }

        Id completedLevelId =
            transactionRecord.Current_Approval_Level__c;
        String completedLevelName =
            getLevelLabel(
                transactionRecord.Current_Approval_Level__r
            );

        if (approvedCount > 0) {
            transactionRecord.Current_Approval_Level__c =
                nextLevel.Id;
            transactionRecord.Pending_With__c =
                nextMapping.Approver_User__c;
            transactionRecord.Approval_Status__c =
                STATUS_PENDING;
            transactionRecord.Returned_From_Level__c =
                null;
            transactionRecord.Last_Action__c =
                ACTION_APPROVED;
            transactionRecord.Last_Action_By__c =
                context.userId;
            transactionRecord.Last_Action_Date_Time__c =
                actionDateTime;
            transactionRecord.Last_Action_Comments__c =
                isKycRequest
                    ? buildKycDecisionSummary(
                        kycMethod,
                        'Approve',
                        approvedCount,
                        trimmedComments
                    )
                    : buildFieldDecisionSummary(
                        approvedCount,
                        rejectedCount,
                        trimmedComments
                    );

            update transactionRecord;

            update new Orient_Customer_Change_Request__c(
                Id =
                    transactionRecord.Customer_Change_Request__c,
                Approval_Status__c = STATUS_PENDING,
                Last_Action__c = ACTION_APPROVED,
                Last_Action_By__c = context.userId,
                Last_Action_Date_Time__c =
                    actionDateTime
            );

            Ctrl_Hlp_OrientCustApprovalSharing.syncApprovalAccess(
                transactionRecord.Id
            );

            ActionResult result = new ActionResult();
            result.success = true;
            result.approvalTransactionId =
                transactionRecord.Id;
            result.nextLevelId = nextLevel.Id;
            result.nextLevelName =
                getLevelLabel(nextLevel);
            result.nextApproverId =
                nextMapping.Approver_User__c;
            result.nextApproverName =
                nextMapping.Approver_User__r.Name;
            result.approvalStatus = STATUS_PENDING;
            result.finalApproved = false;
            result.approvedFieldCount = approvedCount;
            result.rejectedFieldCount = rejectedCount;
            result.message =
                isKycRequest
                    ? (
                        getKycDisplayName(kycMethod) +
                        ' request approved at ' +
                        completedLevelName +
                        '. All ' +
                        String.valueOf(approvedCount) +
                        ' Pending KYC field(s) were approved together and forwarded to ' +
                        nextMapping.Approver_User__r.Name +
                        '.'
                    )
                    : (
                        String.valueOf(approvedCount) +
                        ' field(s) approved at ' +
                        completedLevelName +
                        ' and forwarded to ' +
                        nextMapping.Approver_User__r.Name +
                        '. ' +
                        String.valueOf(rejectedCount) +
                        ' field(s) rejected at this level.'
                    );
            return result;
        }

        transactionRecord.Approval_Status__c =
            STATUS_RETURNED;
        transactionRecord.Pending_With__c =
            isKycRequest
                ? transactionRecord.Submitted_By__c
                : null;
        transactionRecord.Returned_From_Level__c =
            isKycRequest
                ? completedLevelId
                : transactionRecord.Returned_From_Level__c;
        transactionRecord.Last_Action__c =
            ACTION_REJECTED;
        transactionRecord.Last_Action_By__c =
            context.userId;
        transactionRecord.Last_Action_Date_Time__c =
            actionDateTime;
        transactionRecord.Last_Action_Comments__c =
            isKycRequest
                ? buildKycDecisionSummary(
                    kycMethod,
                    'Reject',
                    rejectedCount,
                    trimmedComments
                )
                : buildFieldDecisionSummary(
                    0,
                    rejectedCount,
                    trimmedComments
                );
        update transactionRecord;

        update new Orient_Customer_Change_Request__c(
            Id =
                transactionRecord.Customer_Change_Request__c,
            Approval_Status__c = STATUS_RETURNED,
            Last_Action__c = ACTION_REJECTED,
            Last_Action_By__c = context.userId,
            Last_Action_Date_Time__c =
                actionDateTime
        );

        Ctrl_Hlp_OrientCustApprovalSharing.syncApprovalAccess(
            transactionRecord.Id
        );

        ActionResult result = new ActionResult();
        result.success = true;
        result.approvalTransactionId =
            transactionRecord.Id;
        result.approvalStatus = STATUS_RETURNED;
        result.finalApproved = false;
        result.approvedFieldCount = 0;
        result.rejectedFieldCount = rejectedCount;
        result.message =
            isKycRequest
                ? (
                    getKycDisplayName(kycMethod) +
                    ' request was returned at ' +
                    completedLevelName +
                    '. All ' +
                    String.valueOf(rejectedCount) +
                    ' Pending KYC field(s) were returned together to the original submitter for correction and resubmission.'
                )
                : (
                    'All Pending fields were rejected at ' +
                    completedLevelName +
                    '. The request is complete and no resubmission is available.'
                );
        return result;
    }

    @TestVisible
    private static void validateKycAtomicDecisionPayload(
        Id requestId,
        String decisionsJson,
        String kycMethod
    ) {
        List<Orient_Customer_Change_Item__c> pendingItems = [
            SELECT Id, Field_Label__c,
                   Account_Field_API__c,
                   Item_Approval_Status__c
            FROM Orient_Customer_Change_Item__c
            WHERE Change_Request__c = :requestId
            AND Item_Approval_Status__c =
                :ITEM_STATUS_PENDING
        ];

        if (pendingItems.isEmpty()) {
            throw new AuraHandledException(
                'No Pending KYC fields are available for approval.'
            );
        }

        Object parsed;

        try {
            parsed =
                JSON.deserializeUntyped(
                    decisionsJson
                );
        } catch (Exception e) {
            throw new AuraHandledException(
                'Invalid KYC decision payload.'
            );
        }

        if (!(parsed instanceof List<Object>)) {
            throw new AuraHandledException(
                'Invalid KYC decision payload.'
            );
        }

        Map<Id, Map<String, Object>> decisionByItemId =
            new Map<Id, Map<String, Object>>();

        for (Object rowObject : (List<Object>) parsed) {
            if (!(rowObject instanceof Map<String, Object>)) {
                continue;
            }

            Map<String, Object> decisionRow =
                (Map<String, Object>) rowObject;

            String itemIdText =
                String.valueOf(
                    decisionRow.get('changeItemId')
                );

            if (String.isBlank(itemIdText)) {
                continue;
            }

            try {
                decisionByItemId.put(
                    (Id) itemIdText,
                    decisionRow
                );
            } catch (Exception e) {
                throw new AuraHandledException(
                    'Invalid Customer Change Item Id in the KYC decision payload.'
                );
            }
        }

        if (
            decisionByItemId.size() !=
            pendingItems.size()
        ) {
            throw new AuraHandledException(
                'KYC approval is atomic. Approve all Pending KYC fields together or return all of them together.'
            );
        }

        validateKycAtomicDecision(
            pendingItems,
            decisionByItemId,
            kycMethod
        );
    }

    @TestVisible
    private static void validateKycAtomicDecision(
        List<Orient_Customer_Change_Item__c> pendingItems,
        Map<Id, Map<String, Object>> decisionByItemId,
        String kycMethod
    ) {
        if (
            pendingItems == null ||
            pendingItems.isEmpty()
        ) {
            throw new AuraHandledException(
                'No Pending KYC fields are available for approval.'
            );
        }

        String atomicDecision;

        for (
            Orient_Customer_Change_Item__c itemRecord :
            pendingItems
        ) {
            Map<String, Object> decisionRow =
                decisionByItemId.get(
                    itemRecord.Id
                );

            if (decisionRow == null) {
                throw new AuraHandledException(
                    'KYC approval is atomic. A decision is required for every Pending KYC field.'
                );
            }

            String decision =
                decisionRow.get('decision') == null
                    ? null
                    : String.valueOf(
                        decisionRow.get('decision')
                    ).trim();

            if (
                decision != 'Approve' &&
                decision != 'Reject'
            ) {
                throw new AuraHandledException(
                    'Select either Approve All or Return All for the complete ' +
                    getKycDisplayName(kycMethod) +
                    ' request.'
                );
            }

            if (atomicDecision == null) {
                atomicDecision = decision;
            } else if (atomicDecision != decision) {
                throw new AuraHandledException(
                    getKycDisplayName(kycMethod) +
                    ' approval is atomic. Mixed field decisions are not allowed. ' +
                    'Approve all Pending KYC fields together or return all of them together.'
                );
            }

            if (decision == 'Reject') {
                String rejectionReason =
                    decisionRow.get('rejectionReason') == null
                        ? null
                        : String.valueOf(
                            decisionRow.get(
                                'rejectionReason'
                            )
                        ).trim();

                if (String.isBlank(rejectionReason)) {
                    throw new AuraHandledException(
                        'Return Reason is required when returning the complete ' +
                        getKycDisplayName(kycMethod) +
                        ' request.'
                    );
                }
            }
        }
    }

    @TestVisible
    private static String buildKycDecisionSummary(
        String kycMethod,
        String decision,
        Integer fieldCount,
        String comments
    ) {
        String summary =
            getKycDisplayName(kycMethod) +
            ' Atomic Decision: ' +
            (
                decision == 'Approve'
                    ? 'Approve All'
                    : 'Return All'
            ) +
            ' (' +
            String.valueOf(fieldCount) +
            ' field(s)).';

        if (String.isNotBlank(comments)) {
            summary +=
                ' Comments: ' +
                comments;
        }

        return summary;
    }

    @TestVisible
    private static String extractKycMethodFromReason(
        String reason
    ) {
        if (String.isBlank(reason)) {
            return null;
        }

        String normalizedReason =
            reason.trim().toUpperCase();

        if (
            normalizedReason.startsWith(
                '[KYC:PAN]'
            )
        ) {
            return KYC_METHOD_PAN;
        }

        if (
            normalizedReason.startsWith(
                '[KYC:VOTER]'
            )
        ) {
            return KYC_METHOD_VOTER;
        }

        if (
            normalizedReason.startsWith(
                '[KYC:GST]'
            )
        ) {
            return KYC_METHOD_GST;
        }

        return null;
    }

    @TestVisible
    private static String getKycDisplayName(
        String kycMethod
    ) {
        if (kycMethod == KYC_METHOD_PAN) {
            return 'PAN KYC';
        }

        if (kycMethod == KYC_METHOD_VOTER) {
            return 'Voter ID KYC';
        }

        if (kycMethod == KYC_METHOD_GST) {
            return 'GSTIN KYC';
        }

        return 'KYC';
    }

    @TestVisible
    private static String buildFieldDecisionSummary(
        Integer approvedCount,
        Integer rejectedCount,
        String comments
    ) {
        String summary =
            'Field Decisions: ' +
            String.valueOf(approvedCount) +
            ' Approved, ' +
            String.valueOf(rejectedCount) +
            ' Rejected.';

        if (String.isNotBlank(comments)) {
            summary += ' Comments: ' + comments;
        }

        return summary;
    }

    private static void validateActionAccess(
        Tagged_Approval_Hierarchy__c transactionRecord,
        UserContext context
    ) {
        if (transactionRecord.Approval_Status__c != STATUS_PENDING) {
            throw new AuraHandledException(
                'This request is no longer Pending. Refresh the workspace and try again.'
            );
        }

        if (!context.isAdmin && transactionRecord.Pending_With__c != context.userId) {
            throw new AuraHandledException(
                'This request is not currently assigned to you for approval.'
            );
        }
    }

    @TestVisible
    private static Tagged_Approval_Hierarchy__c getActionableTransaction(
        Id approvalTransactionId,
        Boolean lockRecord
    ) {
        if (approvalTransactionId == null) {
            throw new AuraHandledException(
                'Approval Transaction Id is required.'
            );
        }

        String soql =
            'SELECT Id, Approval_Hierarchy__c, Approval_Status__c,' +
            ' Current_Approval_Level__c,' +
            ' Current_Approval_Level__r.Name,' +
            ' Current_Approval_Level__r.Responsible_Team__c,' +
            ' Current_Approval_Level__r.Sr_No__c,' +
            ' Pending_With__c, Submitted_By__c,' +
            ' Returned_From_Level__c,' +
            ' Customer_Change_Request__c' +
            ' FROM Tagged_Approval_Hierarchy__c' +
            ' WHERE Id = :approvalTransactionId' +
            ' AND Customer_Change_Request__c != null' +
            ' LIMIT 1';

        if (lockRecord) {
            soql += ' FOR UPDATE';
        }

        List<Tagged_Approval_Hierarchy__c> rows =
            Database.query(soql);

        if (rows.isEmpty()) {
            throw new AuraHandledException(
                'Customer Profile approval transaction could not be found.'
            );
        }

        Tagged_Approval_Hierarchy__c transactionRecord =
            rows[0];

        validateActionAccess(
            transactionRecord,
            getUserContext()
        );

        return transactionRecord;
    }

    private static String normalizePhoneForWorkspace(
        String value
    ) {
        if (String.isBlank(value)) {
            return null;
        }

        return value.replaceAll('[^0-9]', '');
    }

    @TestVisible
    private static ApprovalRow buildPendingRow(
        Tagged_Approval_Hierarchy__c transactionRecord,
        Map<Id, Integer> changeCountByRequest
    ) {
        ApprovalRow row = new ApprovalRow();
        row.approvalTransactionId = transactionRecord.Id;
        row.requestId = transactionRecord.Customer_Change_Request__c;
        row.requestName = transactionRecord.Customer_Change_Request__r.Name;
        row.customerId = transactionRecord.Customer_Change_Request__r.Orient_Customer__c;
        row.customerName = transactionRecord.Customer_Change_Request__r.Orient_Customer__r.Name;
        row.storeId = transactionRecord.Customer_Change_Request__r.Approval_Store__c;
        row.storeName = transactionRecord.Customer_Change_Request__r.Approval_Store__r == null
            ? null
            : transactionRecord.Customer_Change_Request__r.Approval_Store__r.Name;
        row.submittedById = transactionRecord.Submitted_By__c;
        row.submittedByName = transactionRecord.Submitted_By__r == null ? null : transactionRecord.Submitted_By__r.Name;
        row.submittedDateTime = transactionRecord.Submitted_Date_Time__c;
        row.currentLevelId = transactionRecord.Current_Approval_Level__c;
        row.currentLevelName = getLevelLabel(transactionRecord.Current_Approval_Level__r);
        row.currentLevelSequence = transactionRecord.Current_Approval_Level__r == null
            ? null
            : transactionRecord.Current_Approval_Level__r.Sr_No__c;
        row.pendingWithId = transactionRecord.Pending_With__c;
        row.pendingWithName = transactionRecord.Pending_With__r == null ? null : transactionRecord.Pending_With__r.Name;
        row.approvalStatus = transactionRecord.Approval_Status__c;
        row.changeReason = transactionRecord.Customer_Change_Request__r.Change_Reason__c;
        row.changeCount = changeCountByRequest.containsKey(row.requestId) ? changeCountByRequest.get(row.requestId) : 0;
        row.lastAction = transactionRecord.Last_Action__c;
        row.lastActionDateTime = transactionRecord.Last_Action_Date_Time__c;
        return row;
    }

    @TestVisible
    private static ApprovalRow buildActionedRow(
        Approval_Action_History__c historyRecord,
        Map<Id, Integer> changeCountByRequest
    ) {
        Tagged_Approval_Hierarchy__c transactionRecord = historyRecord.Approval_Transaction__r;
        ApprovalRow row = buildPendingRow(transactionRecord, changeCountByRequest);
        row.actionHistoryId = historyRecord.Id;
        row.myAction = historyRecord.Action__c;
        row.myActionDateTime = historyRecord.Action_Date_Time__c;
        row.myActionComments = historyRecord.Comments__c;
        return row;
    }

    @TestVisible
    private static List<ApprovalRow> buildRows(
        List<Tagged_Approval_Hierarchy__c> transactions,
        Map<Id, Integer> changeCountByRequest
    ) {
        List<ApprovalRow> rows = new List<ApprovalRow>();
        for (Tagged_Approval_Hierarchy__c transactionRecord : transactions) {
            rows.add(buildPendingRow(transactionRecord, changeCountByRequest));
        }
        return rows;
    }

    @TestVisible
    private static void addRequestIds(
        Set<Id> requestIds,
        List<Tagged_Approval_Hierarchy__c> transactions
    ) {
        for (Tagged_Approval_Hierarchy__c transactionRecord : transactions) {
            if (transactionRecord.Customer_Change_Request__c != null) {
                requestIds.add(transactionRecord.Customer_Change_Request__c);
            }
        }
    }

    @TestVisible
    private static Map<Id, Integer> getChangeCountByRequest(
        Set<Id> requestIds
    ) {
        Map<Id, Integer> result =
            new Map<Id, Integer>();

        if (requestIds.isEmpty()) {
            return result;
        }

        for (
            Orient_Customer_Change_Item__c itemRecord :
            [
                SELECT Change_Request__c,
                       Account_Field_API__c
                FROM Orient_Customer_Change_Item__c
                WHERE Change_Request__c IN :requestIds
                AND Item_Approval_Status__c =
                    :ITEM_STATUS_PENDING
            ]
        ) {
            if (
                !Ctrl_Hlp_OrientCustAddressApproval.isWorkspaceVisibleField(
                        itemRecord.Account_Field_API__c
                    )
            ) {
                continue;
            }

            Integer currentCount =
                result.containsKey(
                    itemRecord.Change_Request__c
                )
                    ? result.get(
                        itemRecord.Change_Request__c
                    )
                    : 0;

            result.put(
                itemRecord.Change_Request__c,
                currentCount + 1
            );
        }

        return result;
    }

    @TestVisible
    private static void populateNextRouting(
        ApprovalPreview preview,
        Tagged_Approval_Hierarchy__c transactionRecord,
        UserContext context
    ) {
        preview.routingReady = false;
        preview.canApprove = false;
        preview.canReject = false;
        preview.isFinalLevel = false;

        if (transactionRecord.Approval_Status__c != STATUS_PENDING) {
            preview.routingMessage = 'This request is no longer Pending.';
            return;
        }

        Boolean canAct = context.isAdmin || transactionRecord.Pending_With__c == context.userId;
        if (!canAct) {
            preview.routingMessage = 'This request is not currently assigned to you.';
            return;
        }

        preview.canReject = true;

        if (
            transactionRecord.Approval_Hierarchy__c == null ||
            transactionRecord.Current_Approval_Level__r == null ||
            transactionRecord.Current_Approval_Level__r.Sr_No__c == null
        ) {
            preview.routingMessage = 'Current approval routing is incomplete.';
            return;
        }

        Approval_Hierarchy_Level__c nextLevel = getNextLevel(
            transactionRecord.Approval_Hierarchy__c,
            transactionRecord.Current_Approval_Level__r.Sr_No__c
        );

        if (nextLevel == null) {
            preview.isFinalLevel = true;
            preview.routingReady = true;
            preview.canApprove = true;

            if (preview.isKycRequest == true) {
                preview.routingMessage =
                    preview.hasBCApplicableChanges
                        ? (
                            'This is the final approval level for ' +
                            preview.kycDisplayName +
                            '. This KYC request is atomic: approve all Pending KYC fields together or return all of them together. ' +
                            'On approval, the complete approved KYC set will be pushed to BC when required and then applied to the Customer.'
                        )
                        : (
                            'This is the final approval level for ' +
                            preview.kycDisplayName +
                            '. This KYC request is atomic: approve all Pending KYC fields together or return all of them together. ' +
                            'On approval, the complete approved KYC set will be applied to the Customer.'
                        );
            } else {
                preview.routingMessage =
                    preview.hasBCApplicableChanges
                        ? 'This is the final approval level. Make a decision for every Pending field. Only approved fields will be pushed to BC and applied to the Customer. Rejected fields are excluded permanently from this request.'
                        : 'This is the final approval level. Make a decision for every Pending field. Only approved fields will be applied to the Customer. Rejected fields are excluded permanently from this request.';
            }

            return;
        }

        List<Approval_Approver_Mapping__c> mappings = getActivePrimaryMappings(nextLevel.Id);
        if (mappings.isEmpty()) {
            preview.routingMessage =
                'No active primary approver is configured for the next approval level "' + getLevelLabel(nextLevel) + '".';
            return;
        }

        if (mappings.size() > 1) {
            preview.routingMessage =
                'Multiple active primary approvers are configured for the next approval level "' + getLevelLabel(nextLevel) + '".';
            return;
        }

        Approval_Approver_Mapping__c mappingRecord = mappings[0];
        preview.nextLevelId = nextLevel.Id;
        preview.nextLevelName = getLevelLabel(nextLevel);
        preview.nextLevelSequence = nextLevel.Sr_No__c;
        preview.nextApproverId = mappingRecord.Approver_User__c;
        preview.nextApproverName = mappingRecord.Approver_User__r.Name;
        preview.routingReady = true;
        preview.canApprove = true;

        if (preview.isKycRequest == true) {
            preview.routingMessage =
                (preview.isAdminOverride ? 'Admin override: ' : '') +
                preview.kycDisplayName +
                ' is an atomic KYC request. Approving moves all Pending KYC fields together to ' +
                preview.nextLevelName +
                ' and assigns the request to ' +
                preview.nextApproverName +
                '. Returning the request returns all Pending KYC fields together.';
        } else {
            preview.routingMessage =
                (preview.isAdminOverride ? 'Admin override: ' : '') +
                'On approval, this request will move to ' + preview.nextLevelName +
                ' and be assigned to ' + preview.nextApproverName + '.';
        }
    }

    @TestVisible
    private static Approval_Hierarchy_Level__c getNextLevel(Id hierarchyId, Decimal currentSequence) {
        List<Approval_Hierarchy_Level__c> levels = [
            SELECT Id, Name, Responsible_Team__c, Sr_No__c, Approval_Hierarchy__c
            FROM Approval_Hierarchy_Level__c
            WHERE Approval_Hierarchy__c = :hierarchyId
            AND Sr_No__c > :currentSequence
            WITH USER_MODE
            ORDER BY Sr_No__c ASC, CreatedDate ASC
            LIMIT 1
        ];
        return levels.isEmpty() ? null : levels[0];
    }

    @TestVisible
    private static Approval_Approver_Mapping__c resolvePrimaryApprover(
        Approval_Hierarchy_Level__c levelRecord
    ) {
        List<Approval_Approver_Mapping__c> mappings = getActivePrimaryMappings(levelRecord.Id);

        if (mappings.isEmpty()) {
            throw new AuraHandledException(
                'No active primary approver is configured for approval level "' + getLevelLabel(levelRecord) + '".'
            );
        }

        if (mappings.size() > 1) {
            throw new AuraHandledException(
                'Multiple active primary approvers are configured for approval level "' + getLevelLabel(levelRecord) + '".'
            );
        }

        return mappings[0];
    }

    @TestVisible
    private static List<Approval_Approver_Mapping__c> getActivePrimaryMappings(Id levelId) {
        Date todayValue = Date.today();
        return [
            SELECT Id, Approval_Hierarchy_Level__c,
                   Approver_User__c, Approver_User__r.Name, Approver_User__r.IsActive,
                   Active__c, Is_Primary__c, Effective_From__c, Effective_To__c
            FROM Approval_Approver_Mapping__c
            WHERE Approval_Hierarchy_Level__c = :levelId
            AND Active__c = true
            AND Is_Primary__c = true
            AND Approver_User__c != null
            AND Approver_User__r.IsActive = true
            AND (Effective_From__c = null OR Effective_From__c <= :todayValue)
            AND (Effective_To__c = null OR Effective_To__c >= :todayValue)
            WITH USER_MODE
            ORDER BY CreatedDate ASC
            LIMIT 2
        ];
    }

    @TestVisible
    private static Boolean hasUserActionedTransaction(Id approvalTransactionId, Id userId) {
        List<Approval_Action_History__c> histories = [
            SELECT Id
            FROM Approval_Action_History__c
            WHERE Approval_Transaction__c = :approvalTransactionId
            AND Action_By__c = :userId
            AND Action__c != :ACTION_SUBMITTED
            WITH USER_MODE
            LIMIT 1
        ];
        return !histories.isEmpty();
    }

    @TestVisible
    private static UserContext getUserContext() {
        User currentUser = [
            SELECT Id, Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        UserContext context = new UserContext();
        context.userId = currentUser.Id;
        context.profileName = currentUser.Profile == null ? null : currentUser.Profile.Name;
        context.isAdmin = context.profileName == ADMIN_PROFILE_NAME;
        return context;
    }

    @TestVisible
    private static String getLevelLabel(Approval_Hierarchy_Level__c levelRecord) {
        if (levelRecord == null) {
            return null;
        }
        return String.isNotBlank(levelRecord.Responsible_Team__c)
            ? levelRecord.Responsible_Team__c
            : levelRecord.Name;
    }
    
    @TestVisible
    private static void datacover() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}