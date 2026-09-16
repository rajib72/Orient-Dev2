public with sharing class Ctrl_BTLApprovalWorkspace {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getWorkspaceContext() {
        User currentUser = [
            SELECT Id, Name, Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        Boolean isAdmin =
            currentUser.Profile.Name ==
            Ctrl_Hlp_BTLApprovalConstants.PROFILE_SYSTEM_ADMIN;

        return new Map<String, Object>{
            'userId' => currentUser.Id,
            'userName' => currentUser.Name,
            'profileName' => currentUser.Profile.Name,
            'isAdmin' => isAdmin
        };
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getPendingApprovals() {
        Id currentUserId = UserInfo.getUserId();
        Boolean isAdmin = isCurrentUserAdmin();
        String pendingStatus = Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING;
        Date today = Date.today();
        String dateOpenClause =
            'Form_Activity_Assigned_Persons_Date__r.Target_Date__c >= :today';
        String whereClause = isAdmin
            ? dateOpenClause + ' AND Approval_Status__c = :pendingStatus'
            : dateOpenClause +
                ' AND Pending_With__c = :currentUserId' +
                ' AND Approval_Status__c = :pendingStatus';

        Map<String, Object> bindValues = new Map<String, Object>{
            'pendingStatus' => pendingStatus,
            'today' => today
        };

        if (!isAdmin) {
            bindValues.put('currentUserId', currentUserId);
        }

        List<Tagged_Approval_Hierarchy__c> transactions = queryTransactions(
            whereClause,
            bindValues,
            'Submitted_Date_Time__c ASC'
        );

        List<Map<String, Object>> rows = new List<Map<String, Object>>();

        for (Tagged_Approval_Hierarchy__c transactionRecord : transactions) {
            Map<String, Object> row = buildTransactionRow(transactionRecord);
            row.put('canPreview', true);
            row.put('canApprove', true);
            row.put('canReject', true);
            rows.add(row);
        }

        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getMySubmittedApprovals() {
        Id currentUserId = UserInfo.getUserId();

        List<Tagged_Approval_Hierarchy__c> transactions =
            queryTransactions(
                'Submitted_By__c = :currentUserId',
                new Map<String, Object>{
                    'currentUserId' => currentUserId
                },
                'Submitted_Date_Time__c DESC'
            );

        List<Map<String, Object>> rows =
            new List<Map<String, Object>>();

        for (Tagged_Approval_Hierarchy__c transactionRecord : transactions) {
            Map<String, Object> row = buildTransactionRow(transactionRecord);
            row.put('canPreview', true);
            row.put('canApprove', false);
            row.put('canReject', false);
            rows.add(row);
        }

        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getActionedApprovals() {
        Id currentUserId = UserInfo.getUserId();

        Set<String> actionValues = new Set<String>{
            Ctrl_Hlp_BTLApprovalConstants.ACTION_APPROVED,
            Ctrl_Hlp_BTLApprovalConstants.ACTION_REJECTED,
            Ctrl_Hlp_BTLApprovalConstants.ACTION_FINAL_APPROVED,
            Ctrl_Hlp_BTLApprovalConstants.ACTION_DROPPED
        };

        List<Approval_Action_History__c> historyRecords = [
            SELECT
                Id,
                Name,
                Approval_Transaction__c,
                Approval_Transaction__r.Name,
                Approval_Transaction__r.Approval_Status__c,
                Approval_Transaction__r.Current_Approval_Level__c,
                Approval_Transaction__r.Current_Approval_Level__r.Responsible_Team__c,
                Approval_Transaction__r.Pending_With__c,
                Approval_Transaction__r.Pending_With__r.Name,
                Approval_Transaction__r.Submitted_By__c,
                Approval_Transaction__r.Submitted_By__r.Name,
                Approval_Transaction__r.Submitted_Date_Time__c,
                Approval_Transaction__r.Returned_From_Level__c,
                Approval_Transaction__r.Returned_From_Level__r.Responsible_Team__c,
                Approval_Transaction__r.Form_Activity__c,
                Approval_Transaction__r.Form_Activity__r.Name,
                Approval_Transaction__r.Form_Activity__r.Activity_Name__c,
                Approval_Transaction__r.Form_Activity__r.Final_Customize_Form__c,
                Approval_Transaction__r.Form_Activity__r.Final_Customize_Form__r.Name,
                Approval_Transaction__r.Form_Activity_Assigned_Persons__c,
                Approval_Transaction__r.Form_Activity_Assigned_Persons__r.Team_Name__c,
                Approval_Transaction__r.Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                Approval_Transaction__r.Form_Activity_Assigned_Persons_Date__c,
                Approval_Transaction__r.Form_Activity_Assigned_Persons_Date__r.Name,
                Approval_Transaction__r.Form_Activity_Assigned_Persons_Date__r.Store__c,
                Approval_Transaction__r.Form_Activity_Assigned_Persons_Date__r.Store__r.Name,
                Approval_Transaction__r.Form_Activity_Assigned_Persons_Date__r.Target_Date__c,
                Approval_Transaction__r.Form_Activity_Assigned_Persons_Date__r.Activity_Location__c,
                Action__c,
                Action_By__c,
                Action_By__r.Name,
                Action_Date_Time__c,
                Approval_Level__c,
                Approval_Level__r.Responsible_Team__c,
                Assigned_To__c,
                Assigned_To__r.Name,
                Comments__c,
                Previous_Status__c,
                New_Status__c,
                Submission_Cycle__c
            FROM Approval_Action_History__c
            WHERE Action_By__c = :currentUserId
            AND Action__c IN :actionValues
            AND Approval_Transaction__r.Form_Activity__c != NULL
            WITH USER_MODE
            ORDER BY Action_Date_Time__c DESC
            LIMIT 500
        ];

        List<Map<String, Object>> rows =
            new List<Map<String, Object>>();

        for (
            Approval_Action_History__c historyRecord :
            historyRecords
        ) {
            rows.add(
                new Map<String, Object>{
                    'historyId' => historyRecord.Id,
                    'historyNo' => historyRecord.Name,
                    'transactionId' =>
                        historyRecord.Approval_Transaction__c,
                    'transactionNo' =>
                        historyRecord.Approval_Transaction__r.Name,
                    'approvalStatus' =>
                        historyRecord.Approval_Transaction__r.Approval_Status__c,
                    'currentLevel' =>
                        historyRecord.Approval_Transaction__r.Current_Approval_Level__r == null
                                ? null
                                : historyRecord.Approval_Transaction__r.Current_Approval_Level__r.Responsible_Team__c,
                    'pendingWithId' =>
                        historyRecord.Approval_Transaction__r.Pending_With__c,
                    'pendingWith' =>
                        historyRecord.Approval_Transaction__r.Pending_With__r == null
                                ? null
                                : historyRecord.Approval_Transaction__r.Pending_With__r.Name,
                    'submittedById' =>
                        historyRecord.Approval_Transaction__r.Submitted_By__c,
                    'submittedBy' =>
                        historyRecord.Approval_Transaction__r.Submitted_By__r == null
                                ? null
                                : historyRecord.Approval_Transaction__r.Submitted_By__r.Name,
                    'submittedDateTime' =>
                        historyRecord.Approval_Transaction__r.Submitted_Date_Time__c,
                    'returnedFromLevel' =>
                        historyRecord.Approval_Transaction__r.Returned_From_Level__r == null
                                ? null
                                : historyRecord.Approval_Transaction__r.Returned_From_Level__r.Responsible_Team__c,
                    'action' =>
                        historyRecord.Action__c,
                    'actionBy' =>
                        historyRecord.Action_By__r.Name,
                    'actionDateTime' =>
                        historyRecord.Action_Date_Time__c,
                    'actionLevel' =>
                        historyRecord.Approval_Level__r == null
                            ? null
                            : historyRecord.Approval_Level__r.Responsible_Team__c,
                    'assignedTo' =>
                        historyRecord.Assigned_To__r == null
                            ? null
                            : historyRecord.Assigned_To__r.Name,
                    'comments' =>
                        historyRecord.Comments__c,
                    'previousStatus' =>
                        historyRecord.Previous_Status__c,
                    'newStatus' =>
                        historyRecord.New_Status__c,
                    'submissionCycle' =>
                        historyRecord.Submission_Cycle__c,
                    'activityId' =>
                        historyRecord.Approval_Transaction__r.Form_Activity__c,
                    'activityNo' =>
                        historyRecord.Approval_Transaction__r.Form_Activity__r.Name,
                    'activityName' =>
                        historyRecord.Approval_Transaction__r.Form_Activity__r.Activity_Name__c,
                    'finalCustomizeFormId' =>
                        historyRecord.Approval_Transaction__r.Form_Activity__r.Final_Customize_Form__c,
                    'finalCustomizeFormNo' =>
                        historyRecord.Approval_Transaction__r.Form_Activity__r.Final_Customize_Form__r == null
                                ? null
                                : historyRecord.Approval_Transaction__r.Form_Activity__r.Final_Customize_Form__r.Name,
                    'assignedPersonId' =>
                        historyRecord.Approval_Transaction__r.Form_Activity_Assigned_Persons__c,
                    'executiveName' =>
                        historyRecord.Approval_Transaction__r.Form_Activity_Assigned_Persons__r == null ||
                        historyRecord.Approval_Transaction__r.Form_Activity_Assigned_Persons__r.Sales_Executives__r == null
                                ? null
                                : historyRecord.Approval_Transaction__r.Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                    'teamName' =>
                        historyRecord.Approval_Transaction__r.Form_Activity_Assigned_Persons__r == null
                                ? null
                                : historyRecord.Approval_Transaction__r.Form_Activity_Assigned_Persons__r.Team_Name__c,
                    'assignedPersonDateId' =>
                        historyRecord.Approval_Transaction__r.Form_Activity_Assigned_Persons_Date__c,
                    'assignedPersonDateNo' =>
                        historyRecord.Approval_Transaction__r.Form_Activity_Assigned_Persons_Date__r.Name,
                    'storeId' =>
                        historyRecord.Approval_Transaction__r.Form_Activity_Assigned_Persons_Date__r.Store__c,
                    'storeName' =>
                        historyRecord.Approval_Transaction__r.Form_Activity_Assigned_Persons_Date__r.Store__r.Name,
                    'targetDate' =>
                        historyRecord.Approval_Transaction__r.Form_Activity_Assigned_Persons_Date__r.Target_Date__c,
                    'activityLocation' =>
                        historyRecord.Approval_Transaction__r.Form_Activity_Assigned_Persons_Date__r.Activity_Location__c
                }
            );
        }

        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAdminApprovals() {
        if (!isCurrentUserAdmin()) {
            return new List<Map<String, Object>>();
        }

        List<Tagged_Approval_Hierarchy__c> transactions =
            queryTransactions(
                null,
                new Map<String, Object>(),
                'LastModifiedDate DESC'
            );

        List<Map<String, Object>> rows =
            new List<Map<String, Object>>();

        for (
            Tagged_Approval_Hierarchy__c transactionRecord :
            transactions
        ) {
            Map<String, Object> row =
                buildTransactionRow(transactionRecord);

            row.put('canPreview', true);
            Boolean canAct =
                transactionRecord.Approval_Status__c ==
                    Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING &&
                !isDateOver(
                    transactionRecord.Form_Activity_Assigned_Persons_Date__r == null
                        ? null
                        : transactionRecord.Form_Activity_Assigned_Persons_Date__r.Target_Date__c
                );
            row.put('canApprove', canAct);
            row.put('canReject', canAct);

            rows.add(row);
        }

        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getApprovalOverview(
        Id taggedApprovalId
    ) {
        return buildPreviewResponse(
            taggedApprovalId,
            false
        );
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getApprovalPreview(
        Id taggedApprovalId
    ) {
        return buildPreviewResponse(
            taggedApprovalId,
            true
        );
    }

    private static Map<String, Object> buildPreviewResponse(
        Id taggedApprovalId,
        Boolean includeFullDetails
    ) {
        if (taggedApprovalId == null) {
            throw new AuraHandledException(
                'Approval transaction Id is required.'
            );
        }

        List<Tagged_Approval_Hierarchy__c> transactions = [
            SELECT
                Id,
                Approval_Status__c,
                Current_Approval_Level__c,
                Current_Approval_Level__r.Responsible_Team__c,
                Pending_With__c,
                Pending_With__r.Name,
                Submitted_By__c,
                Form_Activity_Assigned_Persons_Date__c,
                Form_Activity_Assigned_Persons_Date__r.Target_Date__c
            FROM Tagged_Approval_Hierarchy__c
            WHERE Id = :taggedApprovalId
            WITH USER_MODE
            LIMIT 1
        ];

        if (transactions.isEmpty()) {
            throw new AuraHandledException(
                'Approval transaction could not be found.'
            );
        }

        Tagged_Approval_Hierarchy__c transactionRecord =
            transactions[0];

        Id currentUserId = UserInfo.getUserId();
        Boolean isAdmin = isCurrentUserAdmin();

        Boolean previouslyActioned = false;

        if (!isAdmin) {
            previouslyActioned = [
                SELECT COUNT()
                FROM Approval_Action_History__c
                WHERE Approval_Transaction__c =
                    :transactionRecord.Id
                AND Action_By__c = :currentUserId
            ] > 0;
        }

        Boolean canView =
            isAdmin ||
            transactionRecord.Pending_With__c == currentUserId ||
            transactionRecord.Submitted_By__c == currentUserId ||
            previouslyActioned;

        if (!canView) {
            throw new AuraHandledException(
                'You are not authorised to preview this approval.'
            );
        }

        Map<String, Object> preview =
            includeFullDetails == true
                ? Ctrl_Hlp_BTLApprovalPreviewService.buildPreview(
                    transactionRecord.Form_Activity_Assigned_Persons_Date__c
                )
                : Ctrl_Hlp_BTLApprovalPreviewService.buildOverview(
                    transactionRecord.Form_Activity_Assigned_Persons_Date__c
                );

        Boolean targetDateOver = isDateOver(
            transactionRecord.Form_Activity_Assigned_Persons_Date__r == null
                ? null
                : transactionRecord.Form_Activity_Assigned_Persons_Date__r.Target_Date__c
        );

        Boolean dateOver = targetDateOver &&
            (
                transactionRecord.Approval_Status__c ==
                    Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING ||
                transactionRecord.Approval_Status__c ==
                    Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED ||
                transactionRecord.Approval_Status__c ==
                    Ctrl_Hlp_BTLApprovalConstants.STATUS_NOT_SUBMITTED
            );

        Boolean canAct =
            !targetDateOver &&
            transactionRecord.Approval_Status__c ==
                Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING &&
            (isAdmin || transactionRecord.Pending_With__c == currentUserId);

        preview.put(
            'actionContext',
            new Map<String, Object>{
                'transactionId' => transactionRecord.Id,
                'approvalStatus' =>
                    transactionRecord.Approval_Status__c,
                'displayStatus' =>
                    dateOver
                        ? Ctrl_Hlp_BTLApprovalConstants.DISPLAY_STATUS_DATE_OVER
                        : transactionRecord.Approval_Status__c,
                'isDateOver' => dateOver,
                'dateOverMessage' => dateOver
                    ? 'The activity date has passed. This approval is read-only and no Approve or Reject action is allowed.'
                    : null,
                'currentLevel' =>
                    transactionRecord.Current_Approval_Level__r == null
                            ? null
                            : transactionRecord.Current_Approval_Level__r.Responsible_Team__c,
                'pendingWithUserId' =>
                    transactionRecord.Pending_With__c,
                'pendingWithUserName' =>
                    transactionRecord.Pending_With__r == null
                        ? null
                        : transactionRecord.Pending_With__r.Name,
                'canApprove' => canAct,
                'canReject' => canAct,
                'isAdminView' => isAdmin && !canAct
            }
        );

        return preview;
    }

    @AuraEnabled
    public static Map<String, Object> approveApproval(
        Id taggedApprovalId,
        String comments
    ) {
        return Ctrl_Hlp_BTLApprovalActionService.approve(
            taggedApprovalId,
            comments
        );
    }

    @AuraEnabled
    public static Map<String, Object> rejectApproval(
        Id taggedApprovalId,
        String rejectionReason
    ) {
        return Ctrl_Hlp_BTLApprovalActionService.reject(
            taggedApprovalId,
            rejectionReason
        );
    }

    @AuraEnabled
    public static Map<String, Object> approveTeamActivity(List<Id> taggedApprovalIds, String comments) {
        Set<Id> approvalIds = new Set<Id>();

        if (taggedApprovalIds != null) {
            approvalIds.addAll(taggedApprovalIds);
        }

        return Ctrl_Hlp_BTLApprovalActionService.approveMany(approvalIds, comments);
    }

    @AuraEnabled
    public static Map<String, Object> rejectSelectedApprovals(List<Id> taggedApprovalIds, String rejectionReason) {
        Set<Id> approvalIds = new Set<Id>();

        if (taggedApprovalIds != null) {
            approvalIds.addAll(taggedApprovalIds);
        }

        return Ctrl_Hlp_BTLApprovalActionService.rejectMany(approvalIds, rejectionReason);
    }

    private static List<Tagged_Approval_Hierarchy__c>
        queryTransactions(
            String whereClause,
            Map<String, Object> bindValues,
            String orderByClause
        ) {

        String queryText =
            'SELECT ' +
                'Id, Name, ' +
                'Approval_Hierarchy__c, ' +
                'Approval_Hierarchy__r.Name, ' +
                'Approval_Hierarchy__r.Type__c, ' +
                'Approval_Status__c, ' +
                'Current_Approval_Level__c, ' +
                'Current_Approval_Level__r.Name, ' +
                'Current_Approval_Level__r.Responsible_Team__c, ' +
                'Current_Approval_Level__r.Sr_No__c, ' +
                'Pending_With__c, ' +
                'Pending_With__r.Name, ' +
                'Returned_From_Level__c, ' +
                'Returned_From_Level__r.Responsible_Team__c, ' +
                'Submission_Cycle__c, ' +
                'Submitted_By__c, ' +
                'Submitted_By__r.Name, ' +
                'Submitted_Date_Time__c, ' +
                'Last_Action__c, ' +
                'Last_Action_By__c, ' +
                'Last_Action_By__r.Name, ' +
                'Last_Action_Date_Time__c, ' +
                'Last_Action_Comments__c, ' +
                'Final_Approved_By__c, ' +
                'Final_Approved_By__r.Name, ' +
                'Final_Approved_Date_Time__c, ' +
                'Dropped_By__c, ' +
                'Dropped_By__r.Name, ' +
                'Dropped_Date_Time__c, ' +
                'Drop_Reason__c, ' +
                'Form_Activity__c, ' +
                'Form_Activity__r.Name, ' +
                'Form_Activity__r.Activity_Name__c, ' +
                'Form_Activity__r.Final_Customize_Form__c, ' +
                'Form_Activity__r.Final_Customize_Form__r.Name, ' +
                'Form_Activity_Assigned_Persons__c, ' +
                'Form_Activity_Assigned_Persons__r.Name, ' +
                'Form_Activity_Assigned_Persons__r.Team_Name__c, ' +
                'Form_Activity_Assigned_Persons__r.Sales_Executives__c, ' +
                'Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name, ' +
                'Form_Activity_Assigned_Persons_Date__c, ' +
                'Form_Activity_Assigned_Persons_Date__r.Name, ' +
                'Form_Activity_Assigned_Persons_Date__r.Store__c, ' +
                'Form_Activity_Assigned_Persons_Date__r.Store__r.Name, ' +
                'Form_Activity_Assigned_Persons_Date__r.Target_Date__c, ' +
                'Form_Activity_Assigned_Persons_Date__r.Activity_Location__c, ' +
                'CreatedDate, LastModifiedDate ' +
            'FROM Tagged_Approval_Hierarchy__c';

        String finalWhere = 'Form_Activity__c != NULL AND Form_Activity_Assigned_Persons_Date__c != NULL AND Form_Activity_Assigned_Persons__c != NULL';

        if (String.isNotBlank(whereClause)) {
            finalWhere += ' AND (' + whereClause + ')';
        }

        queryText += ' WHERE ' + finalWhere;

        if (String.isNotBlank(orderByClause)) {
            queryText += ' ORDER BY ' + orderByClause;
        }

        return Database.queryWithBinds(
            queryText,
            bindValues,
            AccessLevel.USER_MODE
        );
    }

    private static Map<String, Object> buildTransactionRow(
        Tagged_Approval_Hierarchy__c transactionRecord
    ) {
        Date targetDate =
            transactionRecord.Form_Activity_Assigned_Persons_Date__r == null
                ? null
                : transactionRecord.Form_Activity_Assigned_Persons_Date__r.Target_Date__c;

        Boolean dateOver = isDateOver(targetDate);
        String displayStatus = dateOver &&
            (
                transactionRecord.Approval_Status__c ==
                    Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING ||
                transactionRecord.Approval_Status__c ==
                    Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED ||
                transactionRecord.Approval_Status__c ==
                    Ctrl_Hlp_BTLApprovalConstants.STATUS_NOT_SUBMITTED
            )
                ? Ctrl_Hlp_BTLApprovalConstants.DISPLAY_STATUS_DATE_OVER
                : transactionRecord.Approval_Status__c;

        return new Map<String, Object>{
            'transactionId' => transactionRecord.Id,
            'transactionNo' => transactionRecord.Name,
            'approvalHierarchyId' =>
                transactionRecord.Approval_Hierarchy__c,
            'approvalHierarchyNo' =>
                transactionRecord.Approval_Hierarchy__r == null
                    ? null
                    : transactionRecord.Approval_Hierarchy__r.Name,
            'approvalStatus' =>
                transactionRecord.Approval_Status__c,
            'displayStatus' => displayStatus,
            'isDateOver' => dateOver,
            'dateOverMessage' => dateOver
                ? 'The activity date has passed. No further approval action is allowed.'
                : null,
            'currentLevelId' =>
                transactionRecord.Current_Approval_Level__c,
            'currentLevel' =>
                transactionRecord.Current_Approval_Level__r == null
                    ? null
                    : transactionRecord.Current_Approval_Level__r.Responsible_Team__c,
            'levelSequence' =>
                transactionRecord.Current_Approval_Level__r == null
                    ? null
                    : transactionRecord.Current_Approval_Level__r.Sr_No__c,
            'pendingWithId' =>
                transactionRecord.Pending_With__c,
            'pendingWith' =>
                transactionRecord.Pending_With__r == null
                    ? null
                    : transactionRecord.Pending_With__r.Name,
            'returnedFromLevel' =>
                transactionRecord.Returned_From_Level__r == null
                    ? null
                    : transactionRecord.Returned_From_Level__r.Responsible_Team__c,
            'submissionCycle' =>
                transactionRecord.Submission_Cycle__c,
            'submittedById' =>
                transactionRecord.Submitted_By__c,
            'submittedBy' =>
                transactionRecord.Submitted_By__r == null
                    ? null
                    : transactionRecord.Submitted_By__r.Name,
            'submittedDateTime' =>
                transactionRecord.Submitted_Date_Time__c,
            'lastAction' =>
                transactionRecord.Last_Action__c,
            'lastActionBy' =>
                transactionRecord.Last_Action_By__r == null
                    ? null
                    : transactionRecord.Last_Action_By__r.Name,
            'lastActionDateTime' =>
                transactionRecord.Last_Action_Date_Time__c,
            'lastActionComments' =>
                transactionRecord.Last_Action_Comments__c,
            'finalApprovedBy' =>
                transactionRecord.Final_Approved_By__r == null
                    ? null
                    : transactionRecord.Final_Approved_By__r.Name,
            'finalApprovedDateTime' => transactionRecord.Final_Approved_Date_Time__c,
            'droppedBy' => transactionRecord.Dropped_By__r == null ? null : transactionRecord.Dropped_By__r.Name,
            'droppedDateTime' => transactionRecord.Dropped_Date_Time__c,
            'dropReason' => transactionRecord.Drop_Reason__c,
            'activityId' =>
                transactionRecord.Form_Activity__c,
            'activityNo' =>
                transactionRecord.Form_Activity__r == null
                    ? null
                    : transactionRecord.Form_Activity__r.Name,
            'activityName' =>
                transactionRecord.Form_Activity__r == null
                    ? null
                    : transactionRecord.Form_Activity__r.Activity_Name__c,
            'finalCustomizeFormId' =>
                transactionRecord.Form_Activity__r == null
                    ? null
                    : transactionRecord.Form_Activity__r.Final_Customize_Form__c,
            'finalCustomizeFormNo' =>
                transactionRecord.Form_Activity__r == null ||
                transactionRecord.Form_Activity__r.Final_Customize_Form__r == null
                        ? null
                        : transactionRecord.Form_Activity__r.Final_Customize_Form__r.Name,
            'assignedPersonId' =>
                transactionRecord.Form_Activity_Assigned_Persons__c,
            'assignedPersonNo' =>
                transactionRecord.Form_Activity_Assigned_Persons__r == null
                        ? null
                        : transactionRecord.Form_Activity_Assigned_Persons__r.Name,
            'executiveName' =>
                transactionRecord.Form_Activity_Assigned_Persons__r == null ||
                transactionRecord.Form_Activity_Assigned_Persons__r.Sales_Executives__r == null
                        ? null
                        : transactionRecord.Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
            'teamName' =>
                transactionRecord.Form_Activity_Assigned_Persons__r == null
                        ? null
                        : transactionRecord.Form_Activity_Assigned_Persons__r.Team_Name__c,
            'assignedPersonDateId' =>
                transactionRecord.Form_Activity_Assigned_Persons_Date__c,
            'assignedPersonDateNo' =>
                transactionRecord.Form_Activity_Assigned_Persons_Date__r == null
                        ? null
                        : transactionRecord.Form_Activity_Assigned_Persons_Date__r.Name,
            'storeId' =>
                transactionRecord.Form_Activity_Assigned_Persons_Date__r == null
                        ? null
                        : transactionRecord.Form_Activity_Assigned_Persons_Date__r.Store__c,
            'storeName' =>
                transactionRecord.Form_Activity_Assigned_Persons_Date__r == null ||
                transactionRecord.Form_Activity_Assigned_Persons_Date__r.Store__r == null
                        ? null
                        : transactionRecord.Form_Activity_Assigned_Persons_Date__r.Store__r.Name,
            'targetDate' => targetDate,
            'activityLocation' =>
                transactionRecord.Form_Activity_Assigned_Persons_Date__r == null
                        ? null
                        : transactionRecord.Form_Activity_Assigned_Persons_Date__r.Activity_Location__c,
            'createdDate' =>
                transactionRecord.CreatedDate,
            'lastModifiedDate' =>
                transactionRecord.LastModifiedDate
        };
    }

    private static Boolean isDateOver(Date targetDate) {
        return targetDate != null && targetDate < Date.today();
    }

    private static void validateAdminAccess() {
        if (!isCurrentUserAdmin()) {
            throw new AuraHandledException(
                'Only System Administrators can view all approvals.'
            );
        }
    }

    private static Boolean isCurrentUserAdmin() {
        User currentUser = [
            SELECT Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        return currentUser.Profile.Name ==
            Ctrl_Hlp_BTLApprovalConstants.PROFILE_SYSTEM_ADMIN;
    }
}