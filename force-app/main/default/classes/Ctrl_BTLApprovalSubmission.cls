public with sharing class Ctrl_BTLApprovalSubmission {

    private class CurrentUserContext {
        User userRecord;
        String profileName;
        Boolean isSystemAdministrator;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getSubmissionRows(
        Id finalCustomizeFormId
    ) {
        if (finalCustomizeFormId == null) {
            throw new AuraHandledException(
                'Final Customize Form Id is required.'
            );
        }

        CurrentUserContext userContext =
            getCurrentUserContext();

        validateSubmitterProfile(userContext);

        List<Form_Activity_Assigned_Persons_Date__c> dateRecords = [
            SELECT
                Id,
                Name,
                Target_Date__c,
                Activity_Location__c,
                Approval_Status__c,
                Approval_Locked__c,
                Is_Active__c,
                Assignment_Status__c,
                Replacement_Of__c,
                Replacement_Reason__c,
                Store__c,
                Store__r.Name,
                Form_Activity_Assigned_Persons__c,
                Form_Activity_Assigned_Persons__r.Name,
                Form_Activity_Assigned_Persons__r.Is_Active__c,
                Form_Activity_Assigned_Persons__r.Person_Name__c,
                Form_Activity_Assigned_Persons__r.Team_Name__c,
                Form_Activity_Assigned_Persons__r.Sales_Executives__c,
                Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                Form_Activity_Assigned_Persons__r.Form_Activity__c,
                Form_Activity_Assigned_Persons__r.Form_Activity__r.Name,
                Form_Activity_Assigned_Persons__r.Form_Activity__r.Activity_Name__c,
                Form_Activity_Assigned_Persons__r.Form_Activity__r.Final_Customize_Form__c
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE
                Form_Activity_Assigned_Persons__r.Form_Activity__r.Final_Customize_Form__c =
                        :finalCustomizeFormId
                AND (Is_Active__c = true OR Assignment_Status__c = null)
            WITH USER_MODE
            ORDER BY
                Target_Date__c ASC,
                Store__r.Name ASC,
                Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name ASC
        ];

        if (dateRecords.isEmpty()) {
            return new List<Map<String, Object>>();
        }

        Set<Id> dateRecordIds = new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c dateRecord :
            dateRecords
        ) {
            dateRecordIds.add(dateRecord.Id);
        }

        List<Tagged_Approval_Hierarchy__c> transactions = [
            SELECT
                Id,
                Name,
                Form_Activity_Assigned_Persons_Date__c,
                Approval_Status__c,
                Current_Approval_Level__c,
                Current_Approval_Level__r.Responsible_Team__c,
                Pending_With__c,
                Pending_With__r.Name,
                Returned_From_Level__c,
                Returned_From_Level__r.Responsible_Team__c,
                Returned_From_Level__r.Sr_No__c,
                Submission_Cycle__c,
                Submitted_By__c,
                Submitted_By__r.Name,
                Last_Action__c,
                Last_Action_Comments__c,
                CreatedDate
            FROM Tagged_Approval_Hierarchy__c
            WHERE Form_Activity_Assigned_Persons_Date__c
                IN :dateRecordIds
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ];

        Map<Id, Tagged_Approval_Hierarchy__c>
            latestTransactionByDate = new Map<Id, Tagged_Approval_Hierarchy__c>();

        for (
            Tagged_Approval_Hierarchy__c transactionRecord :
            transactions
        ) {
            Id dateRecordId =
                transactionRecord.Form_Activity_Assigned_Persons_Date__c;

            if (
                !latestTransactionByDate.containsKey(
                    dateRecordId
                )
            ) {
                latestTransactionByDate.put(
                    dateRecordId,
                    transactionRecord
                );
            }
        }

        List<Map<String, Object>> rows =
            new List<Map<String, Object>>();

        for (
            Form_Activity_Assigned_Persons_Date__c dateRecord :
            dateRecords
        ) {
            if (!hasStoreAccess(userContext, dateRecord)) {
                continue;
            }

            Tagged_Approval_Hierarchy__c transactionRecord =
                latestTransactionByDate.get(dateRecord.Id);

            String approvalStatus =
                transactionRecord != null &&
                String.isNotBlank(
                    transactionRecord.Approval_Status__c
                )
                    ? transactionRecord.Approval_Status__c
                    : dateRecord.Approval_Status__c;

            if (String.isBlank(approvalStatus)) {
                approvalStatus = Ctrl_Hlp_BTLApprovalConstants.STATUS_NOT_SUBMITTED;
            }

            Boolean isEligible =
                approvalStatus ==
                    Ctrl_Hlp_BTLApprovalConstants.STATUS_NOT_SUBMITTED ||
                approvalStatus ==
                    Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED;

            if (!isEligible) {
                continue;
            }

            Boolean isDateOver =
                dateRecord.Target_Date__c != null &&
                dateRecord.Target_Date__c < Date.today();

            String displayStatus = isDateOver
                ? Ctrl_Hlp_BTLApprovalConstants.DISPLAY_STATUS_DATE_OVER
                : approvalStatus;

            if (
                !isDateOver &&
                approvalStatus == Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED &&
                transactionRecord != null &&
                transactionRecord.Returned_From_Level__r != null
            ) {
                displayStatus = 'Returned by ' + transactionRecord.Returned_From_Level__r.Responsible_Team__c;
            }

            Boolean canDrop =
                !isDateOver &&
                approvalStatus == Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED &&
                transactionRecord != null &&
                transactionRecord.Submitted_By__c == userContext.userRecord.Id;

            rows.add(
                new Map<String, Object>{
                    'dateRecordId' => dateRecord.Id,
                    'dateRecordNo' => dateRecord.Name,
                    'activityId' =>
                        dateRecord.Form_Activity_Assigned_Persons__r.Form_Activity__c,
                    'activityNo' =>
                        dateRecord.Form_Activity_Assigned_Persons__r.Form_Activity__r.Name,
                    'activityName' =>
                        dateRecord.Form_Activity_Assigned_Persons__r.Form_Activity__r.Activity_Name__c,
                    'assignedPersonId' =>
                        dateRecord.Form_Activity_Assigned_Persons__c,
                    'assignedPersonNo' => dateRecord.Form_Activity_Assigned_Persons__r.Name,
                    'assignedPersonName' => dateRecord.Form_Activity_Assigned_Persons__r.Person_Name__c,
                    'executiveName' =>
                        dateRecord.Form_Activity_Assigned_Persons__r.Sales_Executives__r == null
                                ? null
                                : dateRecord.Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                    'teamName' =>
                        dateRecord.Form_Activity_Assigned_Persons__r.Team_Name__c,
                    'storeId' => dateRecord.Store__c,
                    'storeName' =>
                        dateRecord.Store__r == null
                            ? null
                            : dateRecord.Store__r.Name,
                    'targetDate' =>
                        dateRecord.Target_Date__c,
                    'activityLocation' =>
                        dateRecord.Activity_Location__c,
                    'approvalStatus' => approvalStatus,
                    'displayStatus' => displayStatus,
                    'approvalLocked' =>
                        dateRecord.Approval_Locked__c == true,
                    'isActive' => isActiveAssignmentDate(dateRecord),
                    'assignmentStatus' => String.isBlank(dateRecord.Assignment_Status__c)
                        ? Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_ACTIVE
                        : dateRecord.Assignment_Status__c,
                    'replacementOfId' => dateRecord.Replacement_Of__c,
                    'replacementReason' => dateRecord.Replacement_Reason__c,
                    'isDateOver' => isDateOver,
                    'dateOverMessage' => isDateOver
                        ? 'The activity date has passed. No submission, resubmission, drop, or manpower change is allowed.'
                        : null,
                    'canSelect' =>
                        !isDateOver &&
                        dateRecord.Approval_Locked__c != true &&
                        isActiveAssignmentDate(dateRecord),
                    'canSubmit' =>
                        !isDateOver &&
                        dateRecord.Approval_Locked__c != true &&
                        isActiveAssignmentDate(dateRecord),
                    'canDrop' => canDrop,
                    'isReturned' => approvalStatus == Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED,
                    'returnedFromLevel' =>
                        transactionRecord == null || transactionRecord.Returned_From_Level__r == null
                            ? null
                            : transactionRecord.Returned_From_Level__r.Responsible_Team__c,
                    'returnedFromLevelSequence' =>
                        transactionRecord == null || transactionRecord.Returned_From_Level__r == null
                            ? null
                            : transactionRecord.Returned_From_Level__r.Sr_No__c,
                    'submittedById' => transactionRecord == null ? null : transactionRecord.Submitted_By__c,
                    'submittedByName' =>
                        transactionRecord == null || transactionRecord.Submitted_By__r == null
                            ? null
                            : transactionRecord.Submitted_By__r.Name,
                    'transactionId' =>
                        transactionRecord == null
                            ? null
                            : transactionRecord.Id,
                    'transactionNo' =>
                        transactionRecord == null
                            ? null
                            : transactionRecord.Name,
                    'submissionCycle' =>
                        transactionRecord == null
                            ? 0
                            : transactionRecord.Submission_Cycle__c,
                    'lastActionComments' =>
                        transactionRecord == null
                            ? null
                            : transactionRecord.Last_Action_Comments__c
                }
            );
        }

        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getApprovalOverview(
        Id assignedPersonDateId
    ) {
        return Ctrl_Hlp_BTLApprovalPreviewService.buildOverview(assignedPersonDateId);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getApprovalPreview(
        Id assignedPersonDateId
    ) {
        return Ctrl_Hlp_BTLApprovalPreviewService.buildPreview(assignedPersonDateId);
    }

    @AuraEnabled
    public static Map<String, Object> submitSelectedRecords(
        List<Id> assignedPersonDateIds,
        String comments
    ) {
        try {
            Set<Id> requestedIds = new Set<Id>();

            if (assignedPersonDateIds != null) {
                for (Id recordId : assignedPersonDateIds) {
                    if (recordId != null) {
                        requestedIds.add(recordId);
                    }
                }
            }

            if (requestedIds.isEmpty()) {
                throw new AuraHandledException(
                    'Select at least one activity before submission.'
                );
            }

            CurrentUserContext userContext =
                getCurrentUserContext();

            validateSubmitterProfile(userContext);

            List<Form_Activity_Assigned_Persons_Date__c>
                dateRecords = [
                    SELECT
                        Id,
                        Name,
                        Store__c,
                        Store__r.Name,
                        Target_Date__c,
                        Approval_Status__c,
                        Approval_Locked__c,
                        Is_Active__c,
                        Assignment_Status__c,
                        Form_Activity_Assigned_Persons__c,
                        Form_Activity_Assigned_Persons__r.Form_Activity__c
                    FROM Form_Activity_Assigned_Persons_Date__c
                    WHERE Id IN :requestedIds
                    WITH USER_MODE
                    FOR UPDATE
                ];

            if (dateRecords.size() != requestedIds.size()) {
                throw new AuraHandledException(
                    'One or more selected activity records could not be accessed.'
                );
            }

            Set<Id> storeIds = new Set<Id>();

            for (
                Form_Activity_Assigned_Persons_Date__c dateRecord :
                dateRecords
            ) {
                if (!hasStoreAccess(userContext, dateRecord)) {
                    throw new AuraHandledException(
                        'You cannot submit activity "' +
                        dateRecord.Name +
                        '" because it belongs to store "' +
                        (
                            dateRecord.Store__r == null
                                ? ''
                                : dateRecord.Store__r.Name
                        ) +
                        '".'
                    );
                }

                if (!isActiveAssignmentDate(dateRecord)) {
                    throw new AuraHandledException(
                        'Activity "' +
                        dateRecord.Name +
                        '" is inactive or has already been replaced/dropped.'
                    );
                }

                validateActivityDateOpen(
                    dateRecord.Target_Date__c,
                    dateRecord.Name
                );

                if (dateRecord.Approval_Locked__c == true) {
                    throw new AuraHandledException(
                        'Activity "' +
                        dateRecord.Name +
                        '" is currently locked for approval.'
                    );
                }

                if (dateRecord.Store__c == null) {
                    throw new AuraHandledException(
                        'Store is missing on activity "' +
                        dateRecord.Name +
                        '".'
                    );
                }

                storeIds.add(dateRecord.Store__c);
            }

            List<Tagged_Approval_Hierarchy__c>
                existingTransactions = [
                    SELECT
                        Id,
                        Approval_Hierarchy__c,
                        Approval_Status__c,
                        Form_Activity__c,
                        Form_Activity_Assigned_Persons__c,
                        Form_Activity_Assigned_Persons_Date__c,
                        Submission_Cycle__c,
                        Submitted_By__c,
                        Submitted_Date_Time__c,
                        Returned_From_Level__c
                    FROM Tagged_Approval_Hierarchy__c
                    WHERE Form_Activity_Assigned_Persons_Date__c
                        IN :requestedIds
                    WITH USER_MODE
                    FOR UPDATE
                ];

            Map<Id, Tagged_Approval_Hierarchy__c>
                existingByDate = new Map<Id, Tagged_Approval_Hierarchy__c>();

            for (
                Tagged_Approval_Hierarchy__c transactionRecord :
                existingTransactions
            ) {
                Id dateRecordId =
                    transactionRecord.Form_Activity_Assigned_Persons_Date__c;

                if (existingByDate.containsKey(dateRecordId)) {
                    throw new AuraHandledException(
                        'Multiple approval transactions exist for Assigned Person Date record: ' +
                        dateRecordId
                    );
                }

                existingByDate.put(
                    dateRecordId,
                    transactionRecord
                );
            }

            List<Approval_Hierarchy__c> hierarchies = [
                SELECT
                    Id,
                    Name,
                    Store__c,
                    Store__r.Name,
                    Type__c
                FROM Approval_Hierarchy__c
                WHERE Store__c IN :storeIds
                AND Type__c =
                    :Ctrl_Hlp_BTLApprovalConstants.APPROVAL_TYPE
                WITH USER_MODE
            ];

            Map<Id, Approval_Hierarchy__c> hierarchyByStore =
                new Map<Id, Approval_Hierarchy__c>();

            for (Approval_Hierarchy__c hierarchy : hierarchies) {
                if (
                    hierarchyByStore.containsKey(
                        hierarchy.Store__c
                    )
                ) {
                    throw new AuraHandledException(
                        'Multiple BTL Form Activity approval hierarchies are configured for store "' +
                        hierarchy.Store__r.Name +
                        '".'
                    );
                }

                hierarchyByStore.put(
                    hierarchy.Store__c,
                    hierarchy
                );
            }

            for (Id storeId : storeIds) {
                if (!hierarchyByStore.containsKey(storeId)) {
                    throw new AuraHandledException(
                        'No BTL Form Activity approval hierarchy is configured for one of the selected stores.'
                    );
                }
            }

            Set<Id> hierarchyIds = new Set<Id>();

            for (
                Approval_Hierarchy__c hierarchy :
                hierarchyByStore.values()
            ) {
                hierarchyIds.add(hierarchy.Id);
            }

            Map<Id, Ctrl_Hlp_BTLApproverResolver.Resolution>
                resolutionByHierarchy = Ctrl_Hlp_BTLApproverResolver.resolveFirstApprovers(hierarchyIds);

            Datetime actionDateTime = System.now();

            List<Tagged_Approval_Hierarchy__c>
                transactionsToInsert = new List<Tagged_Approval_Hierarchy__c>();

            List<Tagged_Approval_Hierarchy__c>
                transactionsToUpdate = new List<Tagged_Approval_Hierarchy__c>();

            List<Form_Activity_Assigned_Persons_Date__c>
                dateRecordsToUpdate = new List<Form_Activity_Assigned_Persons_Date__c>();

            Map<Id, Tagged_Approval_Hierarchy__c>
                workingTransactionByDate = new Map<Id, Tagged_Approval_Hierarchy__c>();

            Map<Id, Ctrl_Hlp_BTLApproverResolver.Resolution>
                resolutionByDate = new Map<Id, Ctrl_Hlp_BTLApproverResolver.Resolution>();

            Map<Id, String> actionByDate =
                new Map<Id, String>();

            Map<Id, String> previousStatusByDate =
                new Map<Id, String>();

            Integer submittedCount = 0;
            Integer resubmittedCount = 0;

            for (
                Form_Activity_Assigned_Persons_Date__c dateRecord :
                dateRecords
            ) {
                Approval_Hierarchy__c hierarchy =
                    hierarchyByStore.get(dateRecord.Store__c);

                Ctrl_Hlp_BTLApproverResolver.Resolution resolution =
                    resolutionByHierarchy.get(hierarchy.Id);

                Tagged_Approval_Hierarchy__c transactionRecord =
                    existingByDate.get(dateRecord.Id);

                String previousStatus =
                    transactionRecord != null &&
                    String.isNotBlank(
                        transactionRecord.Approval_Status__c
                    )
                        ? transactionRecord.Approval_Status__c
                        : dateRecord.Approval_Status__c;

                if (String.isBlank(previousStatus)) {
                    previousStatus = Ctrl_Hlp_BTLApprovalConstants.STATUS_NOT_SUBMITTED;
                }

                if (
                    previousStatus ==
                        Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING
                ) {
                    throw new AuraHandledException(
                        'Activity "' +
                        dateRecord.Name +
                        '" is already pending for approval.'
                    );
                }

                if (previousStatus == Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED) {
                    throw new AuraHandledException('Activity "' + dateRecord.Name + '" is already approved.');
                }

                if (previousStatus == Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED) {
                    throw new AuraHandledException('Activity "' + dateRecord.Name + '" was dropped and cannot be resubmitted.');
                }

                if (previousStatus == Ctrl_Hlp_BTLApprovalConstants.STATUS_CANCELLED) {
                    throw new AuraHandledException('Activity "' + dateRecord.Name + '" is cancelled and cannot be submitted.');
                }

                String actionValue =
                    previousStatus ==
                        Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED
                            ? Ctrl_Hlp_BTLApprovalConstants.ACTION_RESUBMITTED
                            : Ctrl_Hlp_BTLApprovalConstants.ACTION_SUBMITTED;

                Decimal previousCycle =
                    transactionRecord == null ||
                    transactionRecord.Submission_Cycle__c == null
                        ? 0
                        : transactionRecord.Submission_Cycle__c;

                if (transactionRecord == null) {
                    transactionRecord = new Tagged_Approval_Hierarchy__c();
                    transactionsToInsert.add(transactionRecord);
                    submittedCount++;
                } else {
                    transactionsToUpdate.add(transactionRecord);

                    if (
                        actionValue ==
                            Ctrl_Hlp_BTLApprovalConstants.ACTION_RESUBMITTED
                    ) {
                        resubmittedCount++;
                    } else {
                        submittedCount++;
                    }
                }

                transactionRecord.Approval_Hierarchy__c = hierarchy.Id;
                transactionRecord.Form_Activity__c = dateRecord.Form_Activity_Assigned_Persons__r.Form_Activity__c;
                transactionRecord.Form_Activity_Assigned_Persons__c = dateRecord.Form_Activity_Assigned_Persons__c;
                transactionRecord.Form_Activity_Assigned_Persons_Date__c = dateRecord.Id;
                transactionRecord.Approval_Status__c = Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING;
                transactionRecord.Current_Approval_Level__c = resolution.level.Id;
                transactionRecord.Pending_With__c = resolution.mapping.Approver_User__c;
                transactionRecord.Returned_From_Level__c = null;
                transactionRecord.Submission_Cycle__c = previousCycle + 1;
                transactionRecord.Submitted_By__c = userContext.userRecord.Id;
                transactionRecord.Submitted_Date_Time__c = actionDateTime;
                transactionRecord.Last_Action__c = actionValue;
                transactionRecord.Last_Action_By__c = userContext.userRecord.Id;
                transactionRecord.Last_Action_Date_Time__c = actionDateTime;
                transactionRecord.Last_Action_Comments__c =
                    String.isBlank(comments)
                        ? null
                        : comments.trim();
                transactionRecord.Final_Approved_By__c = null;
                transactionRecord.Final_Approved_Date_Time__c = null;
                transactionRecord.Dropped_By__c = null;
                transactionRecord.Dropped_Date_Time__c = null;
                transactionRecord.Drop_Reason__c = null;

                workingTransactionByDate.put(
                    dateRecord.Id,
                    transactionRecord
                );

                resolutionByDate.put(
                    dateRecord.Id,
                    resolution
                );

                actionByDate.put(
                    dateRecord.Id,
                    actionValue
                );

                previousStatusByDate.put(
                    dateRecord.Id,
                    previousStatus
                );

                dateRecordsToUpdate.add(
                    new Form_Activity_Assigned_Persons_Date__c(
                        Id = dateRecord.Id,
                        Approval_Status__c =
                            Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING,
                        Approval_Locked__c = true,
                        Is_Active__c = true,
                        Assignment_Status__c = Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_ACTIVE
                    )
                );
            }

            if (!transactionsToInsert.isEmpty()) {
                insert as user transactionsToInsert;
            }

            if (!transactionsToUpdate.isEmpty()) {
                update as user transactionsToUpdate;
            }

            List<Approval_Action_History__c>
                historyRecords = new List<Approval_Action_History__c>();

            for (
                Form_Activity_Assigned_Persons_Date__c dateRecord :
                dateRecords
            ) {
                Tagged_Approval_Hierarchy__c transactionRecord =
                    workingTransactionByDate.get(dateRecord.Id);

                Ctrl_Hlp_BTLApproverResolver.Resolution resolution =
                    resolutionByDate.get(dateRecord.Id);

                historyRecords.add(
                    new Approval_Action_History__c(
                        Approval_Transaction__c =
                            transactionRecord.Id,
                        Approval_Level__c =
                            resolution.level.Id,
                        Action__c =
                            actionByDate.get(dateRecord.Id),
                        Action_By__c =
                            userContext.userRecord.Id,
                        Action_Date_Time__c =
                            actionDateTime,
                        Assigned_To__c =
                            resolution.mapping.Approver_User__c,
                        Comments__c =
                            String.isBlank(comments)
                                ? null
                                : comments.trim(),
                        Previous_Status__c =
                            previousStatusByDate.get(dateRecord.Id),
                        New_Status__c =
                            Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING,
                        Submission_Cycle__c =
                            transactionRecord.Submission_Cycle__c
                    )
                );
            }

            update as user dateRecordsToUpdate;
            insert as user historyRecords;

            Set<Id> transactionIdsForSharing = new Set<Id>();
            for (
                Tagged_Approval_Hierarchy__c transactionRecord :
                workingTransactionByDate.values()
            ) {
                if (transactionRecord.Id != null) {
                    transactionIdsForSharing.add(transactionRecord.Id);
                }
            }

            Ctrl_Hlp_BTLApprovalSharing.syncApprovalAccess(
                transactionIdsForSharing
            );

            Ctrl_Hlp_BTLEmailNotificationService.sendApprovalRequired(
                transactionIdsForSharing
            );

            Integer totalProcessed =
                submittedCount + resubmittedCount;

            return new Map<String, Object>{
                'success' => true,
                'processedCount' => totalProcessed,
                'submittedCount' => submittedCount,
                'resubmittedCount' => resubmittedCount,
                'message' =>
                    String.valueOf(totalProcessed) +
                    ' activity record(s) successfully sent for approval.'
            };
        } catch (AuraHandledException handledException) {
            throw handledException;
        } catch (DmlException dmlException) {
            throw new AuraHandledException(
                'Approval submission failed: ' +
                dmlException.getDmlMessage(0)
            );
        } catch (Exception exceptionRecord) {
            throw new AuraHandledException(
                'Approval submission failed: ' +
                exceptionRecord.getMessage()
            );
        }
    }

    public static Map<String, Object> submitRevisedRecords(
        List<Id> assignedPersonDateIds,
        String comments
    ) {
        try {
            Set<Id> requestedIds = new Set<Id>();

            if (assignedPersonDateIds != null) {
                for (Id recordId : assignedPersonDateIds) {
                    if (recordId != null) {
                        requestedIds.add(recordId);
                    }
                }
            }

            if (requestedIds.isEmpty()) {
                throw new AuraHandledException(
                    'Select at least one activity before submission.'
                );
            }

            CurrentUserContext userContext =
                getCurrentUserContext();

            validateSubmitterProfile(userContext);

            List<Form_Activity_Assigned_Persons_Date__c>
                dateRecords = [
                    SELECT
                        Id,
                        Name,
                        Store__c,
                        Store__r.Name,
                        Target_Date__c,
                        Approval_Status__c,
                        Approval_Locked__c,
                        Is_Active__c,
                        Assignment_Status__c,
                        Form_Activity_Assigned_Persons__c,
                        Form_Activity_Assigned_Persons__r.Form_Activity__c
                    FROM Form_Activity_Assigned_Persons_Date__c
                    WHERE Id IN :requestedIds
                    WITH USER_MODE
                    FOR UPDATE
                ];

            if (dateRecords.size() != requestedIds.size()) {
                throw new AuraHandledException(
                    'One or more selected activity records could not be accessed.'
                );
            }

            Set<Id> storeIds = new Set<Id>();

            for (
                Form_Activity_Assigned_Persons_Date__c dateRecord :
                dateRecords
            ) {
                if (!hasStoreAccess(userContext, dateRecord)) {
                    throw new AuraHandledException(
                        'You cannot submit activity "' +
                        dateRecord.Name +
                        '" because it belongs to store "' +
                        (
                            dateRecord.Store__r == null
                                ? ''
                                : dateRecord.Store__r.Name
                        ) +
                        '".'
                    );
                }

                if (!isActiveAssignmentDate(dateRecord)) {
                    throw new AuraHandledException(
                        'Activity "' +
                        dateRecord.Name +
                        '" is inactive or has already been replaced/dropped.'
                    );
                }

                validateActivityDateOpen(
                    dateRecord.Target_Date__c,
                    dateRecord.Name
                );

                if (dateRecord.Store__c == null) {
                    throw new AuraHandledException(
                        'Store is missing on activity "' +
                        dateRecord.Name +
                        '".'
                    );
                }

                storeIds.add(dateRecord.Store__c);
            }

            List<Tagged_Approval_Hierarchy__c>
                existingTransactions = [
                    SELECT
                        Id,
                        Approval_Hierarchy__c,
                        Approval_Status__c,
                        Form_Activity__c,
                        Form_Activity_Assigned_Persons__c,
                        Form_Activity_Assigned_Persons_Date__c,
                        Submission_Cycle__c,
                        Submitted_By__c,
                        Submitted_Date_Time__c,
                        Returned_From_Level__c
                    FROM Tagged_Approval_Hierarchy__c
                    WHERE Form_Activity_Assigned_Persons_Date__c
                        IN :requestedIds
                    WITH USER_MODE
                    FOR UPDATE
                ];

            Map<Id, Tagged_Approval_Hierarchy__c>
                existingByDate = new Map<Id, Tagged_Approval_Hierarchy__c>();

            for (
                Tagged_Approval_Hierarchy__c transactionRecord :
                existingTransactions
            ) {
                Id dateRecordId =
                    transactionRecord.Form_Activity_Assigned_Persons_Date__c;

                if (existingByDate.containsKey(dateRecordId)) {
                    throw new AuraHandledException(
                        'Multiple approval transactions exist for Assigned Person Date record: ' +
                        dateRecordId
                    );
                }

                existingByDate.put(
                    dateRecordId,
                    transactionRecord
                );
            }

            List<Approval_Hierarchy__c> hierarchies = [
                SELECT
                    Id,
                    Name,
                    Store__c,
                    Store__r.Name,
                    Type__c
                FROM Approval_Hierarchy__c
                WHERE Store__c IN :storeIds
                AND Type__c =
                    :Ctrl_Hlp_BTLApprovalConstants.APPROVAL_TYPE
                WITH USER_MODE
            ];

            Map<Id, Approval_Hierarchy__c> hierarchyByStore =
                new Map<Id, Approval_Hierarchy__c>();

            for (Approval_Hierarchy__c hierarchy : hierarchies) {
                if (
                    hierarchyByStore.containsKey(
                        hierarchy.Store__c
                    )
                ) {
                    throw new AuraHandledException(
                        'Multiple BTL Form Activity approval hierarchies are configured for store "' +
                        hierarchy.Store__r.Name +
                        '".'
                    );
                }

                hierarchyByStore.put(
                    hierarchy.Store__c,
                    hierarchy
                );
            }

            for (Id storeId : storeIds) {
                if (!hierarchyByStore.containsKey(storeId)) {
                    throw new AuraHandledException(
                        'No BTL Form Activity approval hierarchy is configured for one of the selected stores.'
                    );
                }
            }

            Set<Id> hierarchyIds = new Set<Id>();

            for (
                Approval_Hierarchy__c hierarchy :
                hierarchyByStore.values()
            ) {
                hierarchyIds.add(hierarchy.Id);
            }

            Map<Id, Ctrl_Hlp_BTLApproverResolver.Resolution>
                resolutionByHierarchy = Ctrl_Hlp_BTLApproverResolver.resolveFirstApprovers(hierarchyIds);

            Datetime actionDateTime = System.now();

            List<Tagged_Approval_Hierarchy__c>
                transactionsToInsert = new List<Tagged_Approval_Hierarchy__c>();

            List<Tagged_Approval_Hierarchy__c>
                transactionsToUpdate = new List<Tagged_Approval_Hierarchy__c>();

            List<Form_Activity_Assigned_Persons_Date__c>
                dateRecordsToUpdate = new List<Form_Activity_Assigned_Persons_Date__c>();

            Map<Id, Tagged_Approval_Hierarchy__c>
                workingTransactionByDate = new Map<Id, Tagged_Approval_Hierarchy__c>();

            Map<Id, Ctrl_Hlp_BTLApproverResolver.Resolution>
                resolutionByDate = new Map<Id, Ctrl_Hlp_BTLApproverResolver.Resolution>();

            Map<Id, String> actionByDate =
                new Map<Id, String>();

            Map<Id, String> previousStatusByDate =
                new Map<Id, String>();

            Integer submittedCount = 0;
            Integer resubmittedCount = 0;

            for (
                Form_Activity_Assigned_Persons_Date__c dateRecord :
                dateRecords
            ) {
                Approval_Hierarchy__c hierarchy =
                    hierarchyByStore.get(dateRecord.Store__c);

                Ctrl_Hlp_BTLApproverResolver.Resolution resolution =
                    resolutionByHierarchy.get(hierarchy.Id);

                Tagged_Approval_Hierarchy__c transactionRecord =
                    existingByDate.get(dateRecord.Id);

                String previousStatus =
                    transactionRecord != null &&
                    String.isNotBlank(
                        transactionRecord.Approval_Status__c
                    )
                        ? transactionRecord.Approval_Status__c
                        : dateRecord.Approval_Status__c;

                if (String.isBlank(previousStatus)) {
                    previousStatus = Ctrl_Hlp_BTLApprovalConstants.STATUS_NOT_SUBMITTED;
                }

                if (
                    previousStatus ==
                        Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING
                ) {
                    throw new AuraHandledException(
                        'Activity "' +
                        dateRecord.Name +
                        '" is already pending for approval.'
                    );
                }

                if (previousStatus == Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED) {
                    throw new AuraHandledException('Activity "' + dateRecord.Name + '" was dropped and cannot be resubmitted.');
                }

                if (previousStatus == Ctrl_Hlp_BTLApprovalConstants.STATUS_CANCELLED) {
                    throw new AuraHandledException('Activity "' + dateRecord.Name + '" is cancelled and cannot be submitted.');
                }

                String actionValue =
                    transactionRecord == null
                        ? Ctrl_Hlp_BTLApprovalConstants.ACTION_SUBMITTED
                        : Ctrl_Hlp_BTLApprovalConstants.ACTION_RESUBMITTED;

                Decimal previousCycle =
                    transactionRecord == null ||
                    transactionRecord.Submission_Cycle__c == null
                        ? 0
                        : transactionRecord.Submission_Cycle__c;

                if (transactionRecord == null) {
                    transactionRecord = new Tagged_Approval_Hierarchy__c();
                    transactionsToInsert.add(transactionRecord);
                    submittedCount++;
                } else {
                    transactionsToUpdate.add(transactionRecord);

                    if (
                        actionValue ==
                            Ctrl_Hlp_BTLApprovalConstants.ACTION_RESUBMITTED
                    ) {
                        resubmittedCount++;
                    } else {
                        submittedCount++;
                    }
                }

                transactionRecord.Approval_Hierarchy__c = hierarchy.Id;
                transactionRecord.Form_Activity__c = dateRecord.Form_Activity_Assigned_Persons__r.Form_Activity__c;
                transactionRecord.Form_Activity_Assigned_Persons__c = dateRecord.Form_Activity_Assigned_Persons__c;
                transactionRecord.Form_Activity_Assigned_Persons_Date__c = dateRecord.Id;
                transactionRecord.Approval_Status__c = Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING;
                transactionRecord.Current_Approval_Level__c = resolution.level.Id;
                transactionRecord.Pending_With__c = resolution.mapping.Approver_User__c;
                transactionRecord.Returned_From_Level__c = null;
                transactionRecord.Submission_Cycle__c = previousCycle + 1;
                transactionRecord.Submitted_By__c = userContext.userRecord.Id;
                transactionRecord.Submitted_Date_Time__c = actionDateTime;
                transactionRecord.Last_Action__c = actionValue;
                transactionRecord.Last_Action_By__c = userContext.userRecord.Id;
                transactionRecord.Last_Action_Date_Time__c = actionDateTime;
                transactionRecord.Last_Action_Comments__c =
                    String.isBlank(comments)
                        ? null
                        : comments.trim();
                transactionRecord.Final_Approved_By__c = null;
                transactionRecord.Final_Approved_Date_Time__c = null;
                transactionRecord.Dropped_By__c = null;
                transactionRecord.Dropped_Date_Time__c = null;
                transactionRecord.Drop_Reason__c = null;

                workingTransactionByDate.put(
                    dateRecord.Id,
                    transactionRecord
                );

                resolutionByDate.put(
                    dateRecord.Id,
                    resolution
                );

                actionByDate.put(
                    dateRecord.Id,
                    actionValue
                );

                previousStatusByDate.put(
                    dateRecord.Id,
                    previousStatus
                );

                dateRecordsToUpdate.add(
                    new Form_Activity_Assigned_Persons_Date__c(
                        Id = dateRecord.Id,
                        Approval_Status__c =
                            Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING,
                        Approval_Locked__c = true,
                        Is_Active__c = true,
                        Assignment_Status__c = Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_ACTIVE
                    )
                );
            }

            if (!transactionsToInsert.isEmpty()) {
                insert as user transactionsToInsert;
            }

            if (!transactionsToUpdate.isEmpty()) {
                update as user transactionsToUpdate;
            }

            List<Approval_Action_History__c>
                historyRecords = new List<Approval_Action_History__c>();

            for (
                Form_Activity_Assigned_Persons_Date__c dateRecord :
                dateRecords
            ) {
                Tagged_Approval_Hierarchy__c transactionRecord =
                    workingTransactionByDate.get(dateRecord.Id);

                Ctrl_Hlp_BTLApproverResolver.Resolution resolution =
                    resolutionByDate.get(dateRecord.Id);

                historyRecords.add(
                    new Approval_Action_History__c(
                        Approval_Transaction__c =
                            transactionRecord.Id,
                        Approval_Level__c =
                            resolution.level.Id,
                        Action__c =
                            actionByDate.get(dateRecord.Id),
                        Action_By__c =
                            userContext.userRecord.Id,
                        Action_Date_Time__c =
                            actionDateTime,
                        Assigned_To__c =
                            resolution.mapping.Approver_User__c,
                        Comments__c =
                            String.isBlank(comments)
                                ? null
                                : comments.trim(),
                        Previous_Status__c =
                            previousStatusByDate.get(dateRecord.Id),
                        New_Status__c =
                            Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING,
                        Submission_Cycle__c =
                            transactionRecord.Submission_Cycle__c
                    )
                );
            }

            update as user dateRecordsToUpdate;
            insert as user historyRecords;

            Set<Id> transactionIdsForSharing = new Set<Id>();
            for (
                Tagged_Approval_Hierarchy__c transactionRecord :
                workingTransactionByDate.values()
            ) {
                if (transactionRecord.Id != null) {
                    transactionIdsForSharing.add(transactionRecord.Id);
                }
            }

            Ctrl_Hlp_BTLApprovalSharing.syncApprovalAccess(
                transactionIdsForSharing
            );

            Ctrl_Hlp_BTLEmailNotificationService.sendApprovalRequired(
                transactionIdsForSharing
            );

            Integer totalProcessed =
                submittedCount + resubmittedCount;

            return new Map<String, Object>{
                'success' => true,
                'processedCount' => totalProcessed,
                'submittedCount' => submittedCount,
                'resubmittedCount' => resubmittedCount,
                'message' =>
                    String.valueOf(totalProcessed) +
                    ' activity record(s) successfully sent for approval.'
            };
        } catch (AuraHandledException handledException) {
            throw handledException;
        } catch (DmlException dmlException) {
            throw new AuraHandledException(
                'Approval submission failed: ' +
                dmlException.getDmlMessage(0)
            );
        } catch (Exception exceptionRecord) {
            throw new AuraHandledException(
                'Approval submission failed: ' +
                exceptionRecord.getMessage()
            );
        }
    }

    @AuraEnabled
    public static Map<String, Object> dropSelectedRecords(
        List<Id> taggedApprovalIds,
        String dropReason
    ) {
        Set<Id> requestedIds = new Set<Id>();

        if (taggedApprovalIds != null) {
            for (Id transactionId : taggedApprovalIds) {
                if (transactionId != null) {
                    requestedIds.add(transactionId);
                }
            }
        }

        return Ctrl_Hlp_BTLApprovalActionService.dropMany(requestedIds, dropReason);
    }


    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEligibleManpower(Id assignedPersonDateId) {
        ManpowerReference reference = getManpowerReference(assignedPersonDateId, true);
        Set<Id> excludedExecutiveIds = getExistingExecutiveIds(reference);
        List<SObject> executiveRecords = queryEligibleExecutives(reference.storeId, excludedExecutiveIds, null);
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        for (SObject executiveRecord : executiveRecords) {
            results.add(new Map<String, Object>{
                'executiveId' => (Id) executiveRecord.get('Id'),
                'executiveName' => String.valueOf(executiveRecord.get('Name')),
                'storeId' => reference.storeId,
                'storeName' => reference.storeName,
                'teamName' => getOptionalText(executiveRecord, new List<String>{ 'Team_Name__c' }),
                'employeeCode' => getOptionalText(executiveRecord, new List<String>{ 'Employee_Code__c', 'Code__c' })
            });
        }

        return results;
    }

    @AuraEnabled
    public static Map<String, Object> addReturnedManpower(Id assignedPersonDateId, List<Id> salesExecutiveIds) {
        try {
            Set<Id> requestedExecutiveIds = normalizeIds(salesExecutiveIds);
            if (requestedExecutiveIds.isEmpty()) {
                throw new AuraHandledException('Select at least one manpower record to add.');
            }

            ManpowerReference reference = getManpowerReference(assignedPersonDateId, true);
            Set<Id> existingExecutiveIds = getExistingExecutiveIds(reference);
            List<SObject> executiveRecords = queryEligibleExecutives(reference.storeId, existingExecutiveIds, requestedExecutiveIds);

            if (executiveRecords.size() != requestedExecutiveIds.size()) {
                throw new AuraHandledException('One or more selected manpower records are inactive, belong to another store, or are already assigned.');
            }

            List<Form_Activity_Assigned_Persons__c> assignments = new List<Form_Activity_Assigned_Persons__c>();
            for (SObject executiveRecord : executiveRecords) {
                assignments.add(buildAssignment(reference, executiveRecord));
            }
            insert as user assignments;

            List<Form_Activity_Assigned_Persons_Date__c> dateRecords = new List<Form_Activity_Assigned_Persons_Date__c>();
            for (Form_Activity_Assigned_Persons__c assignment : assignments) {
                dateRecords.add(buildDateRecord(reference, assignment.Id));
            }
            insert as user dateRecords;

            return new Map<String, Object>{
                'success' => true,
                'createdCount' => dateRecords.size(),
                'message' => String.valueOf(dateRecords.size()) + ' manpower record(s) added successfully. Select the new records and submit them for approval.'
            };
        } catch (AuraHandledException handledException) {
            throw handledException;
        } catch (DmlException dmlException) {
            throw new AuraHandledException('Unable to add manpower: ' + dmlException.getDmlMessage(0));
        } catch (Exception exceptionRecord) {
            throw new AuraHandledException('Unable to add manpower: ' + exceptionRecord.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> replaceReturnedManpower(
        Id taggedApprovalId,
        Id replacementExecutiveId,
        String changeReason
    ) {
        try {
            if (taggedApprovalId == null || replacementExecutiveId == null) {
                throw new AuraHandledException('Returned approval and replacement manpower are required.');
            }

            List<Tagged_Approval_Hierarchy__c> transactions = [
                SELECT Id, Name, Approval_Status__c, Submitted_By__c, Returned_From_Level__c,
                    Form_Activity_Assigned_Persons__c,
                    Form_Activity_Assigned_Persons_Date__c
                FROM Tagged_Approval_Hierarchy__c
                WHERE Id = :taggedApprovalId
                WITH USER_MODE
                LIMIT 1
                FOR UPDATE
            ];

            if (transactions.isEmpty()) {
                throw new AuraHandledException('Returned approval record could not be found.');
            }

            Tagged_Approval_Hierarchy__c transactionRecord = transactions[0];
            validateReturnedSubmitter(transactionRecord);

            ManpowerReference reference = getManpowerReference(
                transactionRecord.Form_Activity_Assigned_Persons_Date__c,
                true
            );

            Set<Id> existingExecutiveIds = getExistingExecutiveIds(reference);
            List<SObject> executiveRecords = queryEligibleExecutives(
                reference.storeId,
                existingExecutiveIds,
                new Set<Id>{ replacementExecutiveId }
            );

            if (executiveRecords.size() != 1) {
                throw new AuraHandledException(
                    'The selected replacement is inactive, belongs to another store, is already assigned to this activity/team, or was previously replaced.'
                );
            }

            SObject replacementExecutive = executiveRecords[0];
            String replacementName = String.valueOf(replacementExecutive.get('Name'));
            String normalizedReason = 'Manpower replaced by ' + replacementName + '.';

            if (String.isNotBlank(changeReason)) {
                normalizedReason += ' ' + changeReason.trim();
            }

            Ctrl_Hlp_BTLApprovalActionService.dropForReplacement(
                transactionRecord.Id,
                normalizedReason
            );

            Form_Activity_Assigned_Persons__c newAssignment = buildAssignment(
                reference,
                replacementExecutive
            );
            insert as user newAssignment;

            Form_Activity_Assigned_Persons_Date__c newDateRecord = buildDateRecord(
                reference,
                newAssignment.Id,
                reference.dateRecordId,
                normalizedReason
            );
            insert as user newDateRecord;

            return new Map<String, Object>{
                'success' => true,
                'oldAssignedPersonId' => reference.assignedPersonId,
                'oldAssignedPersonDateId' => reference.dateRecordId,
                'newAssignedPersonId' => newAssignment.Id,
                'newAssignedPersonDateId' => newDateRecord.Id,
                'message' => replacementName +
                    ' was added as the replacement. The old assignment remains in audit history as Replaced and the new record is ready for submission.'
            };
        } catch (AuraHandledException handledException) {
            throw handledException;
        } catch (DmlException dmlException) {
            throw new AuraHandledException('Unable to replace manpower: ' + dmlException.getDmlMessage(0));
        } catch (Exception exceptionRecord) {
            throw new AuraHandledException('Unable to replace manpower: ' + exceptionRecord.getMessage());
        }
    }

    private class ManpowerReference {
        Id dateRecordId;
        Id assignedPersonId;
        Id transactionId;
        Id activityId;
        Id storeId;
        String storeName;
        String teamName;
        Date targetDate;
        String activityLocation;
        Boolean activeForDate;
        SObject sourceAssignment;
        SObject sourceDateRecord;
    }

    private static ManpowerReference getManpowerReference(
        Id assignedPersonDateId,
        Boolean requireReturnedSubmitter
    ) {
        if (assignedPersonDateId == null) {
            throw new AuraHandledException('Assigned Person Date Id is required.');
        }

        List<Form_Activity_Assigned_Persons_Date__c> dateRecords = [
            SELECT Id, Name, Store__c, Store__r.Name, Target_Date__c, Activity_Location__c,
                Active_for_Date__c, Is_Active__c, Assignment_Status__c,
                Approval_Status__c,
                Form_Activity_Assigned_Persons__c,
                Form_Activity_Assigned_Persons__r.Team_Name__c,
                Form_Activity_Assigned_Persons__r.Form_Activity__c
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Id = :assignedPersonDateId
            WITH USER_MODE
            LIMIT 1
        ];

        if (dateRecords.isEmpty()) {
            throw new AuraHandledException('Assigned Person Date record could not be found.');
        }

        Form_Activity_Assigned_Persons_Date__c dateRecord = dateRecords[0];

        validateActivityDateOpen(
            dateRecord.Target_Date__c,
            dateRecord.Name
        );

        if (!isActiveAssignmentDate(dateRecord)) {
            throw new AuraHandledException(
                'The selected manpower assignment is inactive, replaced, or dropped and cannot be changed.'
            );
        }

        List<Tagged_Approval_Hierarchy__c> transactions = [
            SELECT Id, Name, Approval_Status__c, Submitted_By__c, Returned_From_Level__c
            FROM Tagged_Approval_Hierarchy__c
            WHERE Form_Activity_Assigned_Persons_Date__c = :assignedPersonDateId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (requireReturnedSubmitter) {
            if (transactions.isEmpty()) {
                throw new AuraHandledException('This activity has not been returned for correction.');
            }
            validateReturnedSubmitter(transactions[0]);
        }

        ManpowerReference reference = new ManpowerReference();
        reference.dateRecordId = dateRecord.Id;
        reference.assignedPersonId = dateRecord.Form_Activity_Assigned_Persons__c;
        reference.transactionId = transactions.isEmpty() ? null : transactions[0].Id;
        reference.activityId = dateRecord.Form_Activity_Assigned_Persons__r.Form_Activity__c;
        reference.storeId = dateRecord.Store__c;
        reference.storeName = dateRecord.Store__r == null ? null : dateRecord.Store__r.Name;
        reference.teamName = dateRecord.Form_Activity_Assigned_Persons__r.Team_Name__c;
        reference.targetDate = dateRecord.Target_Date__c;
        reference.activityLocation = dateRecord.Activity_Location__c;
        reference.activeForDate = dateRecord.Active_for_Date__c;
        reference.sourceAssignment = queryAllAccessibleFields(
            'Form_Activity_Assigned_Persons__c',
            reference.assignedPersonId
        );
        reference.sourceDateRecord = queryAllAccessibleFields(
            'Form_Activity_Assigned_Persons_Date__c',
            reference.dateRecordId
        );
        return reference;
    }

    private static void validateReturnedSubmitter(Tagged_Approval_Hierarchy__c transactionRecord) {
        if (transactionRecord.Approval_Status__c != Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED) {
            throw new AuraHandledException('Manpower can be changed only for a Returned activity.');
        }

        if (transactionRecord.Submitted_By__c != UserInfo.getUserId()) {
            throw new AuraHandledException(
                'Only the original submitter can change or add manpower for this returned activity.'
            );
        }
    }

    private static void validateActivityDateOpen(
        Date targetDate,
        String recordName
    ) {
        if (targetDate != null && targetDate < Date.today()) {
            throw new AuraHandledException(
                'Activity "' +
                (String.isBlank(recordName) ? '' : recordName) +
                '" is Date Over. The target date has passed, so no further approval-related action is allowed.'
            );
        }
    }

    private static Boolean isActiveAssignmentDate(
        Form_Activity_Assigned_Persons_Date__c dateRecord
    ) {
        if (dateRecord == null) {
            return false;
        }

        if (
            dateRecord.Approval_Status__c ==
                Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED ||
            dateRecord.Assignment_Status__c ==
                Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_DROPPED ||
            dateRecord.Assignment_Status__c ==
                Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_REPLACED ||
            dateRecord.Assignment_Status__c ==
                Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_RESCHEDULED
        ) {
            return false;
        }

        return dateRecord.Is_Active__c == true ||
            String.isBlank(dateRecord.Assignment_Status__c);
    }

    private static Set<Id> getExistingExecutiveIds(ManpowerReference reference) {
        Set<Id> executiveIds = new Set<Id>();
        String replacedStatus = Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_REPLACED;

        for (Form_Activity_Assigned_Persons_Date__c dateRecord : [
            SELECT Form_Activity_Assigned_Persons__r.Sales_Executives__c,
                Form_Activity_Assigned_Persons__r.Team_Name__c
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Form_Activity_Assigned_Persons__r.Form_Activity__c = :reference.activityId
            AND Store__c = :reference.storeId
            AND Target_Date__c = :reference.targetDate
            AND (
                Is_Active__c = true
                OR Assignment_Status__c = null
                OR Assignment_Status__c = :replacedStatus
            )
            WITH USER_MODE
        ]) {
            if (!sameText(dateRecord.Form_Activity_Assigned_Persons__r.Team_Name__c, reference.teamName)) {
                continue;
            }

            Id executiveId = dateRecord.Form_Activity_Assigned_Persons__r.Sales_Executives__c;
            if (executiveId != null) {
                executiveIds.add(executiveId);
            }
        }
        return executiveIds;
    }

    private static Boolean sameText(String firstValue, String secondValue) {
        if (String.isBlank(firstValue) && String.isBlank(secondValue)) {
            return true;
        }

        if (String.isBlank(firstValue) || String.isBlank(secondValue)) {
            return false;
        }

        return firstValue.trim().equalsIgnoreCase(secondValue.trim());
    }

    private static List<SObject> queryEligibleExecutives(
        Id storeId,
        Set<Id> excludedExecutiveIds,
        Set<Id> requestedExecutiveIds
    ) {
        if (storeId == null) {
            throw new AuraHandledException('Store is missing from the returned activity.');
        }

        Schema.SObjectType executiveType = Schema.getGlobalDescribe().get('Sales_Executives__c');
        if (executiveType == null || !executiveType.getDescribe().isAccessible()) {
            throw new AuraHandledException('Sales Executives object is not available to the current user.');
        }

        Map<String, Schema.SObjectField> fields = executiveType.getDescribe().fields.getMap();
        if (!fields.containsKey('Store__c')) {
            throw new AuraHandledException('Store__c is not configured on Sales Executives.');
        }

        List<String> selectFields = new List<String>{ 'Id', 'Name' };
        for (String optionalField : new List<String>{ 'Team_Name__c', 'Employee_Code__c', 'Code__c' }) {
            if (fields.containsKey(optionalField) && fields.get(optionalField).getDescribe().isAccessible()) {
                selectFields.add(optionalField);
            }
        }

        String whereClause = 'Store__c = :storeId';
        Map<String, Object> bindValues = new Map<String, Object>{ 'storeId' => storeId };

        String activeField = getBooleanField(fields, new List<String>{ 'Active__c', 'Is_Active__c' });
        if (activeField != null) {
            whereClause += ' AND ' + activeField + ' = true';
        } else {
            String activeStatusField = getActiveStatusField(fields, new List<String>{ 'Status__c', 'Executive_Status__c' });
            if (activeStatusField != null) {
                whereClause += ' AND ' + activeStatusField + ' = :activeStatus';
                bindValues.put('activeStatus', 'Active');
            }
        }

        if (excludedExecutiveIds != null && !excludedExecutiveIds.isEmpty()) {
            whereClause += ' AND Id NOT IN :excludedExecutiveIds';
            bindValues.put('excludedExecutiveIds', excludedExecutiveIds);
        }

        if (requestedExecutiveIds != null) {
            whereClause += ' AND Id IN :requestedExecutiveIds';
            bindValues.put('requestedExecutiveIds', requestedExecutiveIds);
        }

        String queryText = 'SELECT ' + String.join(selectFields, ',') +
            ' FROM Sales_Executives__c WHERE ' + whereClause + ' ORDER BY Name';
        return Database.queryWithBinds(queryText, bindValues, AccessLevel.USER_MODE);
    }

    private static String getBooleanField(
        Map<String, Schema.SObjectField> fields,
        List<String> candidates
    ) {
        for (String candidate : candidates) {
            if (fields.containsKey(candidate)) {
                Schema.DescribeFieldResult describeResult = fields.get(candidate).getDescribe();
                if (describeResult.isAccessible() && describeResult.getType() == Schema.DisplayType.Boolean) {
                    return candidate;
                }
            }
        }
        return null;
    }

    private static String getActiveStatusField(
        Map<String, Schema.SObjectField> fields,
        List<String> candidates
    ) {
        for (String candidate : candidates) {
            if (!fields.containsKey(candidate)) {
                continue;
            }

            Schema.DescribeFieldResult describeResult = fields.get(candidate).getDescribe();
            if (!describeResult.isAccessible() || describeResult.getType() != Schema.DisplayType.Picklist) {
                continue;
            }

            for (Schema.PicklistEntry entry : describeResult.getPicklistValues()) {
                if (entry.isActive() && entry.getValue().equalsIgnoreCase('Active')) {
                    return candidate;
                }
            }
        }
        return null;
    }

    private static String getOptionalText(SObject recordValue, List<String> candidates) {
        Map<String, Object> values = recordValue.getPopulatedFieldsAsMap();
        for (String candidate : candidates) {
            if (values.containsKey(candidate) && values.get(candidate) != null) {
                return String.valueOf(values.get(candidate));
            }
        }
        return null;
    }

    private static Set<Id> normalizeIds(List<Id> sourceIds) {
        Set<Id> result = new Set<Id>();
        if (sourceIds != null) {
            for (Id sourceId : sourceIds) {
                if (sourceId != null) {
                    result.add(sourceId);
                }
            }
        }
        return result;
    }

    private static Form_Activity_Assigned_Persons__c buildAssignment(
        ManpowerReference reference,
        SObject executiveRecord
    ) {
        Set<String> excludedFields = new Set<String>{
            'Id',
            'OwnerId',
            'Form_Activity__c',
            'Sales_Executives__c',
            'Person_Name__c',
            'Actual_Executives__c',
            'Is_Active__c'
        };

        Form_Activity_Assigned_Persons__c assignment =
            (Form_Activity_Assigned_Persons__c) copyCreateableFields(
                reference.sourceAssignment,
                Form_Activity_Assigned_Persons__c.SObjectType,
                excludedFields,
                false
            );

        assignment.Form_Activity__c = reference.activityId;
        assignment.Sales_Executives__c = (Id) executiveRecord.get('Id');
        assignment.Person_Name__c = String.valueOf(executiveRecord.get('Name'));
        assignment.Store__c = reference.storeId;
        assignment.Team_Name__c = reference.teamName;
        assignment.Assigned_Date__c = reference.targetDate;
        assignment.Activity_Location__c = reference.activityLocation;
        assignment.Actual_Executives__c = null;
        assignment.Is_Active__c = true;
        return assignment;
    }

    private static Form_Activity_Assigned_Persons_Date__c buildDateRecord(
        ManpowerReference reference,
        Id assignmentId
    ) {
        return buildDateRecord(reference, assignmentId, null, null);
    }

    private static Form_Activity_Assigned_Persons_Date__c buildDateRecord(
        ManpowerReference reference,
        Id assignmentId,
        Id replacementOfId,
        String replacementReason
    ) {
        Set<String> excludedFields = new Set<String>{
            'Id',
            'OwnerId',
            'Form_Activity_Assigned_Persons__c',
            'Approval_Status__c',
            'Approval_Locked__c',
            'Is_Active__c',
            'Assignment_Status__c',
            'Replacement_Of__c',
            'Replacement_Reason__c',
            'Active_for_Date__c',
            'Actual_Date__c',
            'Present__c',
            'Status__c',
            'Attendance_Date_Time__c',
            'Attendance_Marked_By__c',
            'Actual_Executive__c',
            'Form_Activity_Daily_Execution__c'
        };

        Form_Activity_Assigned_Persons_Date__c dateRecord =
            (Form_Activity_Assigned_Persons_Date__c) copyCreateableFields(
                reference.sourceDateRecord,
                Form_Activity_Assigned_Persons_Date__c.SObjectType,
                excludedFields,
                true
            );

        dateRecord.Form_Activity_Assigned_Persons__c = assignmentId;
        dateRecord.Store__c = reference.storeId;
        dateRecord.Target_Date__c = reference.targetDate;
        dateRecord.Activity_Location__c = reference.activityLocation;
        dateRecord.Active_for_Date__c = false;
        dateRecord.Approval_Status__c = Ctrl_Hlp_BTLApprovalConstants.STATUS_NOT_SUBMITTED;
        dateRecord.Approval_Locked__c = false;
        dateRecord.Is_Active__c = true;
        dateRecord.Assignment_Status__c = Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_ACTIVE;
        dateRecord.Replacement_Of__c = replacementOfId;
        dateRecord.Replacement_Reason__c = String.isBlank(replacementReason)
            ? null
            : replacementReason.trim();
        return dateRecord;
    }

    private static SObject queryAllAccessibleFields(String objectApiName, Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Source record Id is required for manpower cloning.');
        }

        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        if (objectType == null || !objectType.getDescribe().isAccessible()) {
            throw new AuraHandledException(objectApiName + ' is not accessible to the current user.');
        }

        List<String> accessibleFields = new List<String>();
        for (String fieldName : objectType.getDescribe().fields.getMap().keySet()) {
            if (objectType.getDescribe().fields.getMap().get(fieldName).getDescribe().isAccessible()) {
                accessibleFields.add(fieldName);
            }
        }
        accessibleFields.sort();

        if (accessibleFields.isEmpty()) {
            throw new AuraHandledException('No accessible fields were found on ' + objectApiName + '.');
        }

        String queryText = 'SELECT ' + String.join(accessibleFields, ',') +
            ' FROM ' + objectApiName + ' WHERE Id = :recordId LIMIT 1';

        List<SObject> records = Database.queryWithBinds(
            queryText,
            new Map<String, Object>{ 'recordId' => recordId },
            AccessLevel.USER_MODE
        );

        if (records.isEmpty()) {
            throw new AuraHandledException('Source record could not be loaded for manpower cloning.');
        }

        return records[0];
    }

    private static SObject copyCreateableFields(
        SObject sourceRecord,
        Schema.SObjectType targetType,
        Set<String> excludedFields,
        Boolean skipOperationalResultFields
    ) {
        if (sourceRecord == null) {
            throw new AuraHandledException('Source record is missing for manpower cloning.');
        }

        SObject targetRecord = targetType.newSObject();
        Map<String, Schema.SObjectField> targetFields = targetType.getDescribe().fields.getMap();
        Map<String, Object> populatedValues = sourceRecord.getPopulatedFieldsAsMap();

        for (String fieldName : populatedValues.keySet()) {
            if (excludedFields != null && excludedFields.contains(fieldName)) {
                continue;
            }

            if (!targetFields.containsKey(fieldName)) {
                continue;
            }

            Schema.DescribeFieldResult fieldDescribe = targetFields.get(fieldName).getDescribe();
            if (
                !fieldDescribe.isCreateable() ||
                fieldDescribe.isCalculated() ||
                fieldDescribe.isAutoNumber() ||
                fieldDescribe.isUnique() ||
                fieldDescribe.isExternalId()
            ) {
                continue;
            }

            if (skipOperationalResultFields == true && isOperationalResultField(fieldName)) {
                continue;
            }

            targetRecord.put(fieldName, populatedValues.get(fieldName));
        }

        return targetRecord;
    }

    private static Boolean isOperationalResultField(String fieldApiName) {
        if (String.isBlank(fieldApiName)) {
            return false;
        }

        String normalizedName = fieldApiName.toLowerCase();
        return normalizedName.contains('actual_') ||
            normalizedName.contains('attendance') ||
            normalizedName.contains('execution') ||
            normalizedName.contains('check_in') ||
            normalizedName.contains('check_out') ||
            normalizedName.contains('present') ||
            normalizedName.contains('completed') ||
            normalizedName.contains('completion');
    }

    private static CurrentUserContext getCurrentUserContext() {
        // 1. Query User without the Profile relationship
        User currentUser = [
            SELECT
                Id,
                Name,
                Store__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        // 2. Query Profile directly using UserInfo
        Id profileId = UserInfo.getProfileId();
        Profile currentProfile = [
            SELECT Id, Name
            FROM Profile
            WHERE Id = :profileId
            LIMIT 1
        ];

        CurrentUserContext context = new CurrentUserContext();
        context.userRecord = currentUser;
        context.profileName = currentProfile.Name;
        context.isSystemAdministrator =
            currentProfile.Name == Ctrl_Hlp_BTLApprovalConstants.PROFILE_SYSTEM_ADMIN;

        return context;
    }

    private static void validateSubmitterProfile(
        CurrentUserContext userContext
    ) {
        if (userContext.isSystemAdministrator) {
            return;
        }

        // Reference userContext.profileName directly
        if (
            userContext.profileName !=
                Ctrl_Hlp_BTLApprovalConstants.PROFILE_STORE_MANAGER
        ) {
            throw new AuraHandledException(
                'Only Store Manager users can send activities for approval.'
            );
        }

        if (
            String.isBlank(
                userContext.userRecord.Store__c
            )
        ) {
            throw new AuraHandledException(
                'Store is not configured on your User record.'
            );
        }
    }

    private static Boolean hasStoreAccess(
        CurrentUserContext userContext,
        Form_Activity_Assigned_Persons_Date__c dateRecord
    ) {
        if (userContext.isSystemAdministrator) {
            return true;
        }

        if (
            dateRecord.Store__c == null ||
            dateRecord.Store__r == null ||
            String.isBlank(dateRecord.Store__r.Name) ||
            String.isBlank(userContext.userRecord.Store__c)
        ) {
            return false;
        }

        return userContext.userRecord.Store__c.trim().equalsIgnoreCase(
                dateRecord.Store__r.Name.trim()
            );
    }
}