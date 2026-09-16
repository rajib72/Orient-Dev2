public with sharing class Ctrl_Hlp_BTLApprovalPreviewService {

    private class QueryBundle {
        String objectApiName;
        String objectLabel;
        List<String> fieldApiNames = new List<String>();
        List<SObject> records = new List<SObject>();
    }


    public static Map<String, Object> buildOverview(
        Id assignedPersonDateId
    ) {
        if (assignedPersonDateId == null) {
            throw new AuraHandledException(
                'Assigned Person Date Id is required.'
            );
        }

        Form_Activity_Assigned_Persons_Date__c selectedDate = [
            SELECT
                Id,
                Name,
                Store__c,
                Store__r.Name,
                Target_Date__c,
                Actual_Date__c,
                Activity_Location__c,
                Present__c,
                Status__c,
                Approval_Status__c,
                Approval_Locked__c,
                Is_Active__c,
                Assignment_Status__c,
                Replacement_Of__c,
                Replacement_Reason__c,
                Attendance_Date_Time__c,
                Attendance_Marked_By__c,
                Attendance_Marked_By__r.Name,
                Actual_Executive__c,
                Actual_Executive__r.Name,
                Form_Activity_Assigned_Persons__c,
                Form_Activity_Assigned_Persons__r.Name,
                Form_Activity_Assigned_Persons__r.Is_Active__c,
                Form_Activity_Assigned_Persons__r.Person_Name__c,
                Form_Activity_Assigned_Persons__r.Assigned_Date__c,
                Form_Activity_Assigned_Persons__r.Team_Name__c,
                Form_Activity_Assigned_Persons__r.Sales_Executives__c,
                Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                Form_Activity_Assigned_Persons__r.Actual_Executives__c,
                Form_Activity_Assigned_Persons__r.Actual_Executives__r.Name,
                Form_Activity_Assigned_Persons__r.Form_Activity__c,
                Form_Activity_Assigned_Persons__r.Form_Activity__r.Name,
                Form_Activity_Assigned_Persons__r.Form_Activity__r.Activity_Name__c,
                Form_Activity_Assigned_Persons__r.Form_Activity__r.Final_Customize_Form__c,
                Form_Activity_Assigned_Persons__r.Form_Activity__r.Final_Customize_Form__r.Name
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Id = :assignedPersonDateId
            WITH USER_MODE
            LIMIT 1
        ];

        Id activityId =
            selectedDate.Form_Activity_Assigned_Persons__r.Form_Activity__c;

        Id finalCustomizeFormId =
            selectedDate.Form_Activity_Assigned_Persons__r.Form_Activity__r.Final_Customize_Form__c;

        List<Form_Activity_Assigned_Persons__c> assignedPersons = [
            SELECT
                Id,
                Name,
                Is_Active__c,
                Person_Name__c,
                Assigned_Date__c,
                Activity_Location__c,
                Team_Name__c,
                Store__c,
                Store__r.Name,
                Sales_Executives__c,
                Sales_Executives__r.Name,
                Actual_Executives__c,
                Actual_Executives__r.Name,
                Form_Activity__c
            FROM Form_Activity_Assigned_Persons__c
            WHERE Form_Activity__c = :activityId
            WITH USER_MODE
            ORDER BY Store__r.Name, Team_Name__c, Name
        ];

        Set<Id> assignedPersonIds = new Set<Id>();
        Map<Id, Form_Activity_Assigned_Persons__c>
            assignedPersonById = new Map<Id, Form_Activity_Assigned_Persons__c>();

        for (
            Form_Activity_Assigned_Persons__c assignedPerson :
            assignedPersons
        ) {
            assignedPersonIds.add(assignedPerson.Id);
            assignedPersonById.put(
                assignedPerson.Id,
                assignedPerson
            );
        }

        List<Form_Activity_Assigned_Persons_Date__c> scheduleRecords =
            new List<Form_Activity_Assigned_Persons_Date__c>();

        if (!assignedPersonIds.isEmpty()) {
            scheduleRecords = [
                SELECT
                    Id,
                    Name,
                    Form_Activity_Assigned_Persons__c,
                    Store__c,
                    Store__r.Name,
                    Target_Date__c,
                    Actual_Date__c,
                    Activity_Location__c,
                    Present__c,
                    Status__c,
                    Approval_Status__c,
                    Approval_Locked__c,
                    Is_Active__c,
                    Assignment_Status__c,
                    Replacement_Of__c,
                    Replacement_Reason__c,
                    Attendance_Date_Time__c,
                    Attendance_Marked_By__c,
                    Attendance_Marked_By__r.Name,
                    Actual_Executive__c,
                    Actual_Executive__r.Name
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Form_Activity_Assigned_Persons__c
                    IN :assignedPersonIds
                AND (
                    Is_Active__c = true
                    OR Assignment_Status__c = null
                    OR Id = :assignedPersonDateId
                )
                WITH USER_MODE
                ORDER BY Target_Date__c, Store__r.Name, Name
            ];
        }

        List<Tagged_Approval_Hierarchy__c> transactions = [
            SELECT
                Id,
                Name,
                Approval_Status__c,
                Current_Approval_Level__c,
                Current_Approval_Level__r.Responsible_Team__c,
                Pending_With__c,
                Pending_With__r.Name,
                Returned_From_Level__c,
                Returned_From_Level__r.Responsible_Team__c,
                Submission_Cycle__c,
                Submitted_By__c,
                Submitted_By__r.Name,
                Submitted_Date_Time__c,
                Last_Action__c,
                Last_Action_By__c,
                Last_Action_By__r.Name,
                Last_Action_Date_Time__c,
                Last_Action_Comments__c,
                Final_Approved_By__c,
                Final_Approved_By__r.Name,
                Final_Approved_Date_Time__c,
                Dropped_By__c,
                Dropped_By__r.Name,
                Dropped_Date_Time__c,
                Drop_Reason__c,
                CreatedDate
            FROM Tagged_Approval_Hierarchy__c
            WHERE Form_Activity_Assigned_Persons_Date__c =
                :assignedPersonDateId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        Tagged_Approval_Hierarchy__c latestTransaction =
            transactions.isEmpty()
                ? null
                : transactions[0];

        String approvalStatus =
            latestTransaction != null &&
            String.isNotBlank(
                latestTransaction.Approval_Status__c
            )
                ? latestTransaction.Approval_Status__c
                : selectedDate.Approval_Status__c;

        if (String.isBlank(approvalStatus)) {
            approvalStatus = Ctrl_Hlp_BTLApprovalConstants.STATUS_NOT_SUBMITTED;
        }

        Map<String, Object> summary = new Map<String, Object>{
            'assignedPersonDateId' => selectedDate.Id,
            'assignedPersonDateNo' => selectedDate.Name,
            'assignedPersonId' =>
                selectedDate.Form_Activity_Assigned_Persons__c,
            'assignedPersonNo' =>
                selectedDate.Form_Activity_Assigned_Persons__r.Name,
            'assignedPersonName' =>
                selectedDate.Form_Activity_Assigned_Persons__r.Person_Name__c,
            'activityId' => activityId,
            'activityNo' =>
                selectedDate.Form_Activity_Assigned_Persons__r.Form_Activity__r.Name,
            'activityName' =>
                selectedDate.Form_Activity_Assigned_Persons__r.Form_Activity__r.Activity_Name__c,
            'finalCustomizeFormId' => finalCustomizeFormId,
            'finalCustomizeFormNo' =>
                selectedDate.Form_Activity_Assigned_Persons__r.Form_Activity__r.Final_Customize_Form__r == null
                        ? null
                        : selectedDate.Form_Activity_Assigned_Persons__r.Form_Activity__r.Final_Customize_Form__r.Name,
            'storeId' => selectedDate.Store__c,
            'storeName' =>
                selectedDate.Store__r == null
                    ? null
                    : selectedDate.Store__r.Name,
            'executiveName' =>
                selectedDate.Form_Activity_Assigned_Persons__r.Sales_Executives__r == null
                        ? null
                        : selectedDate.Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
            'actualExecutiveName' =>
                selectedDate.Actual_Executive__r != null
                    ? selectedDate.Actual_Executive__r.Name
                    : (
                        selectedDate.Form_Activity_Assigned_Persons__r.Actual_Executives__r == null
                                ? null
                                : selectedDate.Form_Activity_Assigned_Persons__r.Actual_Executives__r.Name
                    ),
            'teamName' =>
                selectedDate.Form_Activity_Assigned_Persons__r.Team_Name__c,
            'assignedDate' =>
                selectedDate.Form_Activity_Assigned_Persons__r.Assigned_Date__c,
            'targetDate' => selectedDate.Target_Date__c,
            'actualDate' => selectedDate.Actual_Date__c,
            'activityLocation' =>
                selectedDate.Activity_Location__c,
            'present' => selectedDate.Present__c,
            'attendanceStatus' => selectedDate.Status__c,
            'attendanceDateTime' =>
                selectedDate.Attendance_Date_Time__c,
            'attendanceMarkedBy' =>
                selectedDate.Attendance_Marked_By__r == null
                    ? null
                    : selectedDate.Attendance_Marked_By__r.Name,
            'approvalStatus' => approvalStatus,
            'approvalLocked' => selectedDate.Approval_Locked__c == true,
            'isActive' => selectedDate.Is_Active__c == true || String.isBlank(selectedDate.Assignment_Status__c),
            'assignmentStatus' => String.isBlank(selectedDate.Assignment_Status__c)
                ? Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_ACTIVE
                : selectedDate.Assignment_Status__c,
            'replacementOfId' => selectedDate.Replacement_Of__c,
            'replacementReason' => selectedDate.Replacement_Reason__c
        };

        if (latestTransaction != null) {
            summary.put('transactionId', latestTransaction.Id);
            summary.put('transactionNo', latestTransaction.Name);
            summary.put(
                'currentLevel',
                latestTransaction.Current_Approval_Level__r == null
                    ? null
                    : latestTransaction.Current_Approval_Level__r.Responsible_Team__c
            );
            summary.put(
                'pendingWith',
                latestTransaction.Pending_With__r == null
                    ? null
                    : latestTransaction.Pending_With__r.Name
            );
            summary.put(
                'returnedFromLevel',
                latestTransaction.Returned_From_Level__r == null
                    ? null
                    : latestTransaction.Returned_From_Level__r.Responsible_Team__c
            );
            summary.put(
                'submissionCycle',
                latestTransaction.Submission_Cycle__c
            );
            summary.put(
                'submittedBy',
                latestTransaction.Submitted_By__r == null
                    ? null
                    : latestTransaction.Submitted_By__r.Name
            );
            summary.put(
                'submittedDateTime',
                latestTransaction.Submitted_Date_Time__c
            );
            summary.put(
                'lastAction',
                latestTransaction.Last_Action__c
            );
            summary.put(
                'lastActionBy',
                latestTransaction.Last_Action_By__r == null
                    ? null
                    : latestTransaction.Last_Action_By__r.Name
            );
            summary.put(
                'lastActionDateTime',
                latestTransaction.Last_Action_Date_Time__c
            );
            summary.put(
                'lastActionComments',
                latestTransaction.Last_Action_Comments__c
            );
            summary.put(
                'finalApprovedBy',
                latestTransaction.Final_Approved_By__r == null
                    ? null
                    : latestTransaction.Final_Approved_By__r.Name
            );
            summary.put(
                'finalApprovedDateTime',
                latestTransaction.Final_Approved_Date_Time__c
            );
            summary.put(
                'droppedBy',
                latestTransaction.Dropped_By__r == null
                    ? null
                    : latestTransaction.Dropped_By__r.Name
            );
            summary.put(
                'droppedDateTime',
                latestTransaction.Dropped_Date_Time__c
            );
            summary.put(
                'dropReason',
                latestTransaction.Drop_Reason__c
            );
        }

        List<Map<String, Object>> assignedPersonRows =
            new List<Map<String, Object>>();

        Set<Id> personsWithSchedule = new Set<Id>();
        Set<Id> relatedRecordIds = new Set<Id>();

        addId(relatedRecordIds, selectedDate.Id);
        addId(
            relatedRecordIds,
            selectedDate.Form_Activity_Assigned_Persons__c
        );
        addId(relatedRecordIds, activityId);
        addId(relatedRecordIds, finalCustomizeFormId);

        for (
            Form_Activity_Assigned_Persons_Date__c scheduleRecord :
            scheduleRecords
        ) {
            Form_Activity_Assigned_Persons__c assignedPerson =
                assignedPersonById.get(
                    scheduleRecord.Form_Activity_Assigned_Persons__c
                );

            personsWithSchedule.add(
                scheduleRecord.Form_Activity_Assigned_Persons__c
            );
            relatedRecordIds.add(scheduleRecord.Id);

            assignedPersonRows.add(
                buildAssignedPersonRow(
                    assignedPerson,
                    scheduleRecord,
                    assignedPersonDateId
                )
            );
        }

        for (
            Form_Activity_Assigned_Persons__c assignedPerson :
            assignedPersons
        ) {
            relatedRecordIds.add(assignedPerson.Id);

            if (
                assignedPerson.Is_Active__c != true &&
                assignedPerson.Id != selectedDate.Form_Activity_Assigned_Persons__c
            ) {
                continue;
            }

            if (!personsWithSchedule.contains(assignedPerson.Id)) {
                assignedPersonRows.add(
                    buildAssignedPersonRow(
                        assignedPerson,
                        null,
                        assignedPersonDateId
                    )
                );
            }
        }

        List<String> warnings = new List<String>();

        QueryBundle customerResponses = queryOptionalChildren(
            'BTL_Customer_Response__c',
            new List<String>{ 'Form_Activity__c' },
            new Set<Id>{ activityId },
            'CreatedDate',
            warnings
        );

        Set<Id> responseIds = new Set<Id>();

        for (SObject responseRecord : customerResponses.records) {
            responseIds.add(responseRecord.Id);
            relatedRecordIds.add(responseRecord.Id);
        }

        QueryBundle responseItems = queryOptionalChildren(
            'BTL_Customer_Response_Items__c',
            new List<String>{ 'BTL_Customer_Response__c' },
            responseIds,
            'CreatedDate',
            warnings
        );

        for (SObject responseItem : responseItems.records) {
            relatedRecordIds.add(responseItem.Id);
        }

        QueryBundle notes = queryByParentIds(
            'Note',
            'ParentId',
            relatedRecordIds,
            'CreatedDate',
            warnings
        );

        QueryBundle legacyAttachments = queryByParentIds(
            'Attachment',
            'ParentId',
            relatedRecordIds,
            'CreatedDate',
            warnings
        );

        List<Map<String, Object>> files = getRelatedFiles(
            relatedRecordIds,
            warnings
        );

        Map<String, Object> supportingInfo =
            new Map<String, Object>{
                'assignedPersonCount' => assignedPersonRows.size(),
                'scheduleCount' => scheduleRecords.size(),
                'customerResponseCount' =>
                    customerResponses.records.size(),
                'customerAnswerCount' =>
                    responseItems.records.size(),
                'fileCount' => files.size(),
                'noteCount' => notes.records.size(),
                'legacyAttachmentCount' =>
                    legacyAttachments.records.size()
            };

        return new Map<String, Object>{
            'summary' => summary,
            'assignedPersons' => assignedPersonRows,
            'supportingInfo' => supportingInfo,
            'warnings' => warnings
        };
    }

    private static Map<String, Object> buildAssignedPersonRow(
        Form_Activity_Assigned_Persons__c assignedPerson,
        Form_Activity_Assigned_Persons_Date__c scheduleRecord,
        Id selectedDateId
    ) {
        String approvalStatus =
            scheduleRecord == null ||
            String.isBlank(scheduleRecord.Approval_Status__c)
                ? Ctrl_Hlp_BTLApprovalConstants.STATUS_NOT_SUBMITTED
                : scheduleRecord.Approval_Status__c;

        return new Map<String, Object>{
            'assignedPersonId' =>
                assignedPerson == null
                    ? null
                    : assignedPerson.Id,
            'assignedPersonNo' =>
                assignedPerson == null
                    ? null
                    : assignedPerson.Name,
            'assignedPersonName' =>
                assignedPerson == null
                    ? null
                    : assignedPerson.Person_Name__c,
            'dateRecordId' =>
                scheduleRecord == null
                    ? null
                    : scheduleRecord.Id,
            'dateRecordNo' =>
                scheduleRecord == null
                    ? null
                    : scheduleRecord.Name,
            'isSelectedRecord' =>
                scheduleRecord != null &&
                scheduleRecord.Id == selectedDateId,
            'executiveName' =>
                assignedPerson == null ||
                assignedPerson.Sales_Executives__r == null
                    ? null
                    : assignedPerson.Sales_Executives__r.Name,
            'actualExecutiveName' =>
                scheduleRecord != null &&
                scheduleRecord.Actual_Executive__r != null
                    ? scheduleRecord.Actual_Executive__r.Name
                    : (
                        assignedPerson == null ||
                        assignedPerson.Actual_Executives__r == null
                            ? null
                            : assignedPerson.Actual_Executives__r.Name
                    ),
            'teamName' =>
                assignedPerson == null
                    ? null
                    : assignedPerson.Team_Name__c,
            'storeName' =>
                scheduleRecord != null &&
                scheduleRecord.Store__r != null
                    ? scheduleRecord.Store__r.Name
                    : (
                        assignedPerson == null ||
                        assignedPerson.Store__r == null
                            ? null
                            : assignedPerson.Store__r.Name
                    ),
            'assignedDate' =>
                assignedPerson == null
                    ? null
                    : assignedPerson.Assigned_Date__c,
            'targetDate' =>
                scheduleRecord == null
                    ? null
                    : scheduleRecord.Target_Date__c,
            'actualDate' =>
                scheduleRecord == null
                    ? null
                    : scheduleRecord.Actual_Date__c,
            'location' =>
                scheduleRecord != null &&
                String.isNotBlank(
                    scheduleRecord.Activity_Location__c
                )
                    ? scheduleRecord.Activity_Location__c
                    : (
                        assignedPerson == null
                            ? null
                            : assignedPerson.Activity_Location__c
                    ),
            'present' =>
                scheduleRecord != null &&
                scheduleRecord.Present__c == true,
            'attendanceStatus' =>
                scheduleRecord == null
                    ? null
                    : scheduleRecord.Status__c,
            'attendanceDateTime' =>
                scheduleRecord == null
                    ? null
                    : scheduleRecord.Attendance_Date_Time__c,
            'attendanceMarkedBy' =>
                scheduleRecord == null ||
                scheduleRecord.Attendance_Marked_By__r == null
                    ? null
                    : scheduleRecord.Attendance_Marked_By__r.Name,
            'approvalStatus' => approvalStatus,
            'approvalLocked' => scheduleRecord != null && scheduleRecord.Approval_Locked__c == true,
            'isActive' => scheduleRecord == null
                ? assignedPerson != null && assignedPerson.Is_Active__c == true
                : scheduleRecord.Is_Active__c == true || String.isBlank(scheduleRecord.Assignment_Status__c),
            'assignmentStatus' => scheduleRecord == null || String.isBlank(scheduleRecord.Assignment_Status__c)
                ? Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_ACTIVE
                : scheduleRecord.Assignment_Status__c,
            'replacementOfId' => scheduleRecord == null ? null : scheduleRecord.Replacement_Of__c,
            'replacementReason' => scheduleRecord == null ? null : scheduleRecord.Replacement_Reason__c
        };
    }

    public static Map<String, Object> buildPreview(
        Id assignedPersonDateId
    ) {
        if (assignedPersonDateId == null) {
            throw new AuraHandledException(
                'Assigned Person Date Id is required.'
            );
        }

        Form_Activity_Assigned_Persons_Date__c dateRecord = [
            SELECT
                Id,
                Name,
                Store__c,
                Store__r.Name,
                Target_Date__c,
                Activity_Location__c,
                Approval_Status__c,
                Approval_Locked__c,
                Form_Activity_Daily_Execution__c,
                Form_Activity_Assigned_Persons__c,
                Form_Activity_Assigned_Persons__r.Name,
                Form_Activity_Assigned_Persons__r.Team_Name__c,
                Form_Activity_Assigned_Persons__r.Sales_Executives__c,
                Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                Form_Activity_Assigned_Persons__r.Form_Activity__c,
                Form_Activity_Assigned_Persons__r.Form_Activity__r.Name,
                Form_Activity_Assigned_Persons__r.Form_Activity__r.Final_Customize_Form__c,
                Form_Activity_Assigned_Persons__r.Form_Activity__r.Final_Customize_Form__r.Name
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Id = :assignedPersonDateId
            WITH USER_MODE
            LIMIT 1
        ];

        Id assignedPersonId =
            dateRecord.Form_Activity_Assigned_Persons__c;

        Id activityId =
            dateRecord.Form_Activity_Assigned_Persons__r.Form_Activity__c;

        Id finalCustomizeFormId =
            dateRecord.Form_Activity_Assigned_Persons__r.Form_Activity__r.Final_Customize_Form__c;

        List<String> warnings = new List<String>();
        List<Map<String, Object>> sections =
            new List<Map<String, Object>>();

        Set<Id> allRelatedRecordIds = new Set<Id>();

        addId(allRelatedRecordIds, assignedPersonDateId);
        addId(allRelatedRecordIds, assignedPersonId);
        addId(allRelatedRecordIds, activityId);
        addId(allRelatedRecordIds, finalCustomizeFormId);
        addId(
            allRelatedRecordIds,
            dateRecord.Form_Activity_Daily_Execution__c
        );

        addSection(
            sections,
            'finalCustomizeForm',
            'Final Customize Form Information',
            queryByIds(
                'Final_Customize_Form__c',
                new Set<Id>{ finalCustomizeFormId },
                null,
                warnings
            )
        );

        QueryBundle formLineItems = queryOptionalChildren(
            'Final_Customize_Form_Line_Item__c',
            new List<String>{
                'Final_Customize_Form__c'
            },
            new Set<Id>{ finalCustomizeFormId },
            'CreatedDate',
            warnings
        );

        addSection(
            sections,
            'formLineItems',
            'Final Customize Form Questions and Line Items',
            formLineItems
        );

        addRecordIds(formLineItems.records, allRelatedRecordIds);

        addSection(
            sections,
            'formActivity',
            'Complete Form Activity Information',
            queryByIds(
                'Form_Activity__c',
                new Set<Id>{ activityId },
                null,
                warnings
            )
        );

        addSection(
            sections,
            'assignedPerson',
            'Assigned Person Information',
            queryByIds(
                'Form_Activity_Assigned_Persons__c',
                new Set<Id>{ assignedPersonId },
                null,
                warnings
            )
        );

        addSection(
            sections,
            'assignedPersonDate',
            'Assigned Person Date Information',
            queryByIds(
                'Form_Activity_Assigned_Persons_Date__c',
                new Set<Id>{ assignedPersonDateId },
                null,
                warnings
            )
        );

        addSection(
            sections,
            'dailyExecution',
            'Attendance and Daily Execution Information',
            queryByIds(
                'Form_Activity_Daily_Execution__c',
                dateRecord.Form_Activity_Daily_Execution__c == null
                    ? new Set<Id>()
                    : new Set<Id>{
                        dateRecord.Form_Activity_Daily_Execution__c
                    },
                null,
                warnings
            )
        );

        QueryBundle customerResponses = queryOptionalChildren(
            'BTL_Customer_Response__c',
            new List<String>{
                'Form_Activity__c'
            },
            new Set<Id>{ activityId },
            'CreatedDate',
            warnings
        );

        addSection(
            sections,
            'customerResponses',
            'Customer Responses',
            customerResponses
        );

        Set<Id> responseIds = addRecordIds(
            customerResponses.records,
            allRelatedRecordIds
        );

        QueryBundle responseItems = queryOptionalChildren(
            'BTL_Customer_Response_Items__c',
            new List<String>{
                'BTL_Customer_Response__c'
            },
            responseIds,
            'CreatedDate',
            warnings
        );

        addSection(
            sections,
            'customerResponseItems',
            'Question-wise Customer Answers',
            responseItems
        );

        addRecordIds(responseItems.records, allRelatedRecordIds);

        List<Tagged_Approval_Hierarchy__c> summaryTransactions = [
            SELECT
                Id,
                Name,
                Approval_Hierarchy__c,
                Approval_Status__c,
                Current_Approval_Level__c,
                Current_Approval_Level__r.Name,
                Current_Approval_Level__r.Responsible_Team__c,
                Pending_With__c,
                Pending_With__r.Name,
                Returned_From_Level__c,
                Returned_From_Level__r.Name,
                Returned_From_Level__r.Responsible_Team__c,
                Submission_Cycle__c,
                Submitted_By__c,
                Submitted_By__r.Name,
                Submitted_Date_Time__c,
                Last_Action__c,
                Last_Action_By__c,
                Last_Action_By__r.Name,
                Last_Action_Date_Time__c,
                Last_Action_Comments__c,
                Final_Approved_By__c,
                Final_Approved_By__r.Name,
                Final_Approved_Date_Time__c,
                Dropped_By__c,
                Dropped_By__r.Name,
                Dropped_Date_Time__c,
                Drop_Reason__c,
                CreatedDate
            FROM Tagged_Approval_Hierarchy__c
            WHERE Form_Activity_Assigned_Persons_Date__c =
                :assignedPersonDateId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ];

        Set<Id> transactionIds = new Set<Id>();
        Set<Id> hierarchyIds = new Set<Id>();

        for (
            Tagged_Approval_Hierarchy__c transactionRecord :
            summaryTransactions
        ) {
            addId(transactionIds, transactionRecord.Id);
            addId(allRelatedRecordIds, transactionRecord.Id);
            addId(
                hierarchyIds,
                transactionRecord.Approval_Hierarchy__c
            );
        }

        addSection(
            sections,
            'approvalTransaction',
            'Approval Transaction Information',
            queryByIds(
                'Tagged_Approval_Hierarchy__c',
                transactionIds,
                'CreatedDate',
                warnings
            )
        );

        if (hierarchyIds.isEmpty() && dateRecord.Store__c != null) {
            List<Approval_Hierarchy__c> configuredHierarchies = [
                SELECT Id
                FROM Approval_Hierarchy__c
                WHERE Store__c = :dateRecord.Store__c
                AND Type__c =
                    :Ctrl_Hlp_BTLApprovalConstants.APPROVAL_TYPE
                WITH USER_MODE
            ];

            for (
                Approval_Hierarchy__c hierarchyRecord :
                configuredHierarchies
            ) {
                addId(hierarchyIds, hierarchyRecord.Id);
                addId(allRelatedRecordIds, hierarchyRecord.Id);
            }

            if (configuredHierarchies.isEmpty()) {
                warnings.add(
                    'No BTL Form Activity approval hierarchy is configured for store "' +
                    (
                        dateRecord.Store__r == null
                            ? ''
                            : dateRecord.Store__r.Name
                    ) +
                    '".'
                );
            }

            if (configuredHierarchies.size() > 1) {
                warnings.add(
                    'Multiple BTL Form Activity approval hierarchies are configured for this store.'
                );
            }
        }

        addSection(
            sections,
            'approvalHierarchy',
            'Approval Hierarchy Configuration',
            queryByIds(
                'Approval_Hierarchy__c',
                hierarchyIds,
                null,
                warnings
            )
        );

        QueryBundle levels = queryByParentIds(
            'Approval_Hierarchy_Level__c',
            'Approval_Hierarchy__c',
            hierarchyIds,
            'Sr_No__c',
            warnings
        );

        addSection(
            sections,
            'approvalLevels',
            'Approval Levels and Sequence',
            levels
        );

        Set<Id> levelIds = addRecordIds(
            levels.records,
            allRelatedRecordIds
        );

        QueryBundle approverMappings = queryByParentIds(
            'Approval_Approver_Mapping__c',
            'Approval_Hierarchy_Level__c',
            levelIds,
            'CreatedDate',
            warnings
        );

        addSection(
            sections,
            'approverMappings',
            'Configured Approvers',
            approverMappings
        );

        addRecordIds(
            approverMappings.records,
            allRelatedRecordIds
        );

        QueryBundle approvalHistory = queryByParentIds(
            'Approval_Action_History__c',
            'Approval_Transaction__c',
            transactionIds,
            'Action_Date_Time__c',
            warnings
        );

        addSection(
            sections,
            'approvalHistory',
            'Complete Approval History',
            approvalHistory
        );

        addRecordIds(
            approvalHistory.records,
            allRelatedRecordIds
        );

        QueryBundle legacyAttachments = queryByParentIds(
            'Attachment',
            'ParentId',
            allRelatedRecordIds,
            'CreatedDate',
            warnings
        );

        addSection(
            sections,
            'legacyAttachments',
            'Legacy Attachments',
            legacyAttachments
        );

        QueryBundle notes = queryByParentIds(
            'Note',
            'ParentId',
            allRelatedRecordIds,
            'CreatedDate',
            warnings
        );

        addSection(
            sections,
            'notes',
            'Notes',
            notes
        );

        Tagged_Approval_Hierarchy__c latestTransaction =
            summaryTransactions.isEmpty()
                ? null
                : summaryTransactions[0];

        String currentStatus =
            latestTransaction != null &&
            String.isNotBlank(
                latestTransaction.Approval_Status__c
            )
                ? latestTransaction.Approval_Status__c
                : dateRecord.Approval_Status__c;

        if (String.isBlank(currentStatus)) {
            currentStatus = Ctrl_Hlp_BTLApprovalConstants.STATUS_NOT_SUBMITTED;
        }

        Map<String, Object> summary =
            new Map<String, Object>{
                'assignedPersonDateId' => assignedPersonDateId,
                'assignedPersonDateNo' => dateRecord.Name,
                'activityId' => activityId,
                'activityNo' =>
                    dateRecord.Form_Activity_Assigned_Persons__r.Form_Activity__r.Name,
                'finalCustomizeFormId' => finalCustomizeFormId,
                'finalCustomizeFormNo' =>
                    dateRecord.Form_Activity_Assigned_Persons__r.Form_Activity__r.Final_Customize_Form__r == null
                            ? null
                            : dateRecord.Form_Activity_Assigned_Persons__r.Form_Activity__r.Final_Customize_Form__r.Name,
                'storeId' => dateRecord.Store__c,
                'storeName' =>
                    dateRecord.Store__r == null
                        ? null
                        : dateRecord.Store__r.Name,
                'executiveName' =>
                    dateRecord.Form_Activity_Assigned_Persons__r.Sales_Executives__r == null
                            ? null
                            : dateRecord.Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                'teamName' =>
                    dateRecord.Form_Activity_Assigned_Persons__r.Team_Name__c,
                'targetDate' => dateRecord.Target_Date__c,
                'activityLocation' =>
                    dateRecord.Activity_Location__c,
                'approvalStatus' => currentStatus,
                'approvalLocked' =>
                    dateRecord.Approval_Locked__c == true
            };

        if (latestTransaction != null) {
            summary.put(
                'transactionId',
                latestTransaction.Id
            );
            summary.put(
                'transactionNo',
                latestTransaction.Name
            );
            summary.put(
                'currentLevel',
                latestTransaction.Current_Approval_Level__r == null
                    ? null
                    : latestTransaction.Current_Approval_Level__r.Responsible_Team__c
            );
            summary.put(
                'pendingWith',
                latestTransaction.Pending_With__r == null
                    ? null
                    : latestTransaction.Pending_With__r.Name
            );
            summary.put(
                'returnedFromLevel',
                latestTransaction.Returned_From_Level__r == null
                    ? null
                    : latestTransaction.Returned_From_Level__r.Responsible_Team__c
            );
            summary.put(
                'submissionCycle',
                latestTransaction.Submission_Cycle__c
            );
            summary.put(
                'submittedBy',
                latestTransaction.Submitted_By__r == null
                    ? null
                    : latestTransaction.Submitted_By__r.Name
            );
            summary.put(
                'submittedDateTime',
                latestTransaction.Submitted_Date_Time__c
            );
            summary.put(
                'lastAction',
                latestTransaction.Last_Action__c
            );
            summary.put(
                'lastActionBy',
                latestTransaction.Last_Action_By__r == null
                    ? null
                    : latestTransaction.Last_Action_By__r.Name
            );
            summary.put(
                'lastActionDateTime',
                latestTransaction.Last_Action_Date_Time__c
            );
            summary.put(
                'lastActionComments',
                latestTransaction.Last_Action_Comments__c
            );
            summary.put(
                'finalApprovedBy',
                latestTransaction.Final_Approved_By__r == null
                    ? null
                    : latestTransaction.Final_Approved_By__r.Name
            );
            summary.put(
                'finalApprovedDateTime',
                latestTransaction.Final_Approved_Date_Time__c
            );
            summary.put(
                'droppedBy',
                latestTransaction.Dropped_By__r == null
                    ? null
                    : latestTransaction.Dropped_By__r.Name
            );
            summary.put(
                'droppedDateTime',
                latestTransaction.Dropped_Date_Time__c
            );
            summary.put(
                'dropReason',
                latestTransaction.Drop_Reason__c
            );
        }

        return new Map<String, Object>{
            'summary' => summary,
            'sections' => sections,
            'files' =>
                getRelatedFiles(
                    allRelatedRecordIds,
                    warnings
                ),
            'warnings' => warnings
        };
    }

    private static QueryBundle queryOptionalChildren(
        String objectApiName,
        List<String> possibleParentFields,
        Set<Id> parentIds,
        String orderByField,
        List<String> warnings
    ) {
        QueryBundle emptyBundle =
            prepareBundle(objectApiName, warnings);

        if (
            emptyBundle == null ||
            parentIds == null ||
            parentIds.isEmpty()
        ) {
            return emptyBundle;
        }

        Schema.SObjectType objectType =
            Schema.getGlobalDescribe().get(objectApiName);

        if (objectType == null) {
            return emptyBundle;
        }

        Map<String, Schema.SObjectField> fieldMap =
            objectType.getDescribe().fields.getMap();

        for (String parentField : possibleParentFields) {
            if (fieldMap.containsKey(parentField)) {
                return queryByParentIds(
                    objectApiName,
                    parentField,
                    parentIds,
                    orderByField,
                    warnings
                );
            }
        }

        warnings.add(
            'No supported parent relationship field was found on "' +
            objectApiName +
            '".'
        );

        return emptyBundle;
    }

    private static QueryBundle queryByIds(
        String objectApiName,
        Set<Id> recordIds,
        String orderByField,
        List<String> warnings
    ) {
        QueryBundle bundle =
            prepareBundle(objectApiName, warnings);

        if (
            bundle == null ||
            recordIds == null ||
            recordIds.isEmpty()
        ) {
            return bundle;
        }

        bundle.records = executeQuery(
            bundle,
            'Id IN :recordIds',
            new Map<String, Object>{
                'recordIds' => recordIds
            },
            orderByField,
            warnings
        );

        return bundle;
    }

    private static QueryBundle queryByParentIds(
        String objectApiName,
        String parentFieldApiName,
        Set<Id> parentIds,
        String orderByField,
        List<String> warnings
    ) {
        QueryBundle bundle =
            prepareBundle(objectApiName, warnings);

        if (
            bundle == null ||
            parentIds == null ||
            parentIds.isEmpty()
        ) {
            return bundle;
        }

        Schema.SObjectType objectType =
            Schema.getGlobalDescribe().get(objectApiName);

        if (objectType == null) {
            return bundle;
        }

        Map<String, Schema.SObjectField> fieldMap =
            objectType.getDescribe().fields.getMap();

        if (!fieldMap.containsKey(parentFieldApiName)) {
            warnings.add(
                'Field "' +
                objectApiName +
                '.' +
                parentFieldApiName +
                '" was not found.'
            );
            return bundle;
        }

        bundle.records = executeQuery(
            bundle,
            parentFieldApiName + ' IN :parentIds',
            new Map<String, Object>{
                'parentIds' => parentIds
            },
            orderByField,
            warnings
        );

        return bundle;
    }

    private static QueryBundle prepareBundle(
        String objectApiName,
        List<String> warnings
    ) {
        QueryBundle bundle = new QueryBundle();
        bundle.objectApiName = objectApiName;

        Schema.SObjectType objectType =
            Schema.getGlobalDescribe().get(objectApiName);

        if (objectType == null) {
            warnings.add(
                'Object "' + objectApiName + '" was not found.'
            );
            return bundle;
        }

        Schema.DescribeSObjectResult objectDescribe =
            objectType.getDescribe();

        bundle.objectLabel = objectDescribe.getLabel();

        if (!objectDescribe.isAccessible()) {
            warnings.add(
                'Current user does not have read access to "' +
                objectDescribe.getLabel() +
                '".'
            );
            return bundle;
        }

        Map<String, Schema.SObjectField> fieldMap =
            objectDescribe.fields.getMap();

        List<String> readableFields =
            new List<String>();

        for (String fieldApiName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe =
                fieldMap.get(fieldApiName).getDescribe();

            if (
                fieldDescribe.isAccessible() &&
                !fieldDescribe.isDeprecatedAndHidden() &&
                fieldDescribe.getType() !=
                    Schema.DisplayType.Base64
            ) {
                readableFields.add(fieldApiName);
            }
        }

        readableFields.sort();
        bundle.fieldApiNames = readableFields;
        return bundle;
    }

    private static List<SObject> executeQuery(
        QueryBundle bundle,
        String whereClause,
        Map<String, Object> bindValues,
        String orderByField,
        List<String> warnings
    ) {
        if (
            bundle == null ||
            bundle.fieldApiNames.isEmpty()
        ) {
            return new List<SObject>();
        }

        Schema.DescribeSObjectResult objectDescribe =
            Schema.getGlobalDescribe().get(bundle.objectApiName).getDescribe();

        Map<String, Schema.SObjectField> fieldMap =
            objectDescribe.fields.getMap();

        List<String> selectFields =
            new List<String>(bundle.fieldApiNames);

        Set<String> relationshipNames =
            new Set<String>();

        for (String fieldApiName : bundle.fieldApiNames) {
            Schema.DescribeFieldResult fieldDescribe =
                fieldMap.get(fieldApiName).getDescribe();

            if (
                fieldDescribe.getType() ==
                    Schema.DisplayType.Reference &&
                String.isNotBlank(
                    fieldDescribe.getRelationshipName()
                ) &&
                !relationshipNames.contains(
                    fieldDescribe.getRelationshipName()
                )
            ) {
                relationshipNames.add(
                    fieldDescribe.getRelationshipName()
                );
                selectFields.add(
                    fieldDescribe.getRelationshipName() +
                    '.Name'
                );
            }
        }

        String orderByClause = buildOrderByClause(
            bundle.objectApiName,
            orderByField
        );

        String queryText =
            'SELECT ' +
            String.join(selectFields, ',') +
            ' FROM ' +
            bundle.objectApiName +
            ' WHERE ' +
            whereClause +
            orderByClause;

        try {
            return Database.queryWithBinds(
                queryText,
                bindValues,
                AccessLevel.USER_MODE
            );
        } catch (Exception firstException) {
            String fallbackQuery =
                'SELECT ' +
                String.join(bundle.fieldApiNames, ',') +
                ' FROM ' +
                bundle.objectApiName +
                ' WHERE ' +
                whereClause +
                orderByClause;

            try {
                return Database.queryWithBinds(
                    fallbackQuery,
                    bindValues,
                    AccessLevel.USER_MODE
                );
            } catch (Exception finalException) {
                warnings.add(
                    'Unable to load "' +
                    (
                        String.isBlank(bundle.objectLabel)
                            ? bundle.objectApiName
                            : bundle.objectLabel
                    ) +
                    '": ' +
                    finalException.getMessage()
                );
                return new List<SObject>();
            }
        }
    }

    private static String buildOrderByClause(
        String objectApiName,
        String orderByField
    ) {
        if (String.isBlank(orderByField)) {
            return '';
        }

        Schema.SObjectType objectType =
            Schema.getGlobalDescribe().get(objectApiName);

        if (objectType == null) {
            return '';
        }

        Map<String, Schema.SObjectField> fieldMap =
            objectType.getDescribe().fields.getMap();

        if (!fieldMap.containsKey(orderByField)) {
            return '';
        }

        Schema.DescribeFieldResult describeResult =
            fieldMap.get(orderByField).getDescribe();

        return describeResult.isSortable()
            ? ' ORDER BY ' +
                orderByField +
                ' ASC NULLS LAST'
            : '';
    }

    private static void addSection(
        List<Map<String, Object>> sections,
        String key,
        String title,
        QueryBundle bundle
    ) {
        if (bundle == null) {
            return;
        }

        List<Map<String, Object>> records =
            new List<Map<String, Object>>();

        for (SObject recordValue : bundle.records) {
            records.add(
                convertRecord(
                    bundle.objectApiName,
                    recordValue,
                    bundle.fieldApiNames
                )
            );
        }

        sections.add(
            new Map<String, Object>{
                'key' => key,
                'title' => title,
                'objectApiName' => bundle.objectApiName,
                'objectLabel' => bundle.objectLabel,
                'recordCount' => records.size(),
                'records' => records
            }
        );
    }

    private static Map<String, Object> convertRecord(
        String objectApiName,
        SObject recordValue,
        List<String> fieldApiNames
    ) {
        Schema.DescribeSObjectResult objectDescribe =
            Schema.getGlobalDescribe().get(objectApiName).getDescribe();

        Map<String, Schema.SObjectField> fieldMap =
            objectDescribe.fields.getMap();

        List<Map<String, Object>> fields =
            new List<Map<String, Object>>();

        for (String fieldApiName : fieldApiNames) {
            Schema.DescribeFieldResult fieldDescribe =
                fieldMap.get(fieldApiName).getDescribe();

            Object rawValue;

            try {
                rawValue = recordValue.get(fieldApiName);
            } catch (Exception ignoredException) {
                rawValue = null;
            }

            fields.add(
                new Map<String, Object>{
                    'apiName' => fieldApiName,
                    'label' => fieldDescribe.getLabel(),
                    'dataType' =>
                        String.valueOf(fieldDescribe.getType()),
                    'value' =>
                        formatFieldValue(
                            recordValue,
                            fieldDescribe,
                            rawValue
                        ),
                    'isBlank' => rawValue == null,
                    'referenceId' =>
                        fieldDescribe.getType() ==
                            Schema.DisplayType.Reference &&
                        rawValue != null
                            ? String.valueOf(rawValue)
                            : null
                }
            );
        }

        return new Map<String, Object>{
            'id' => recordValue.Id,
            'title' =>
                getRecordTitle(
                    objectDescribe,
                    recordValue
                ),
            'fields' => fields
        };
    }

    private static String formatFieldValue(
        SObject recordValue,
        Schema.DescribeFieldResult fieldDescribe,
        Object rawValue
    ) {
        if (rawValue == null) {
            return '';
        }

        if (
            fieldDescribe.getType() ==
                Schema.DisplayType.Reference
        ) {
            String relationshipName =
                fieldDescribe.getRelationshipName();

            if (String.isNotBlank(relationshipName)) {
                try {
                    SObject relatedRecord =
                        recordValue.getSObject(
                            relationshipName
                        );

                    if (
                        relatedRecord != null &&
                        relatedRecord.get('Name') != null
                    ) {
                        return String.valueOf(
                            relatedRecord.get('Name')
                        );
                    }
                } catch (Exception ignoredException) {
                }
            }
        }

        if (
            fieldDescribe.getType() ==
                Schema.DisplayType.DateTime
        ) {
            return ((Datetime) rawValue).format(
                'dd/MM/yyyy, hh:mm a'
            );
        }

        if (
            fieldDescribe.getType() ==
                Schema.DisplayType.Date
        ) {
            return ((Date) rawValue).format();
        }

        if (
            fieldDescribe.getType() ==
                Schema.DisplayType.Boolean
        ) {
            return ((Boolean) rawValue)
                ? 'Yes'
                : 'No';
        }

        return String.valueOf(rawValue);
    }

    private static String getRecordTitle(
        Schema.DescribeSObjectResult objectDescribe,
        SObject recordValue
    ) {
        try {
            Object nameValue = recordValue.get('Name');

            if (nameValue != null) {
                return String.valueOf(nameValue);
            }
        } catch (Exception ignoredException) {
        }

        return
            objectDescribe.getLabel() +
            ' - ' +
            String.valueOf(recordValue.Id);
    }

    private static Set<Id> addRecordIds(
        List<SObject> records,
        Set<Id> targetSet
    ) {
        Set<Id> result = new Set<Id>();

        if (records == null) {
            return result;
        }

        for (SObject recordValue : records) {
            addId(result, recordValue.Id);
            addId(targetSet, recordValue.Id);
        }

        return result;
    }

    private static void addId(
        Set<Id> targetSet,
        Id recordId
    ) {
        if (targetSet != null && recordId != null) {
            targetSet.add(recordId);
        }
    }

    private static List<Map<String, Object>> getRelatedFiles(
        Set<Id> relatedRecordIds,
        List<String> warnings
    ) {
        List<Map<String, Object>> files =
            new List<Map<String, Object>>();

        if (
            relatedRecordIds == null ||
            relatedRecordIds.isEmpty()
        ) {
            return files;
        }

        try {
            List<ContentDocumentLink> links = [
                SELECT
                    LinkedEntityId,
                    ContentDocumentId,
                    ContentDocument.Title,
                    ContentDocument.FileType,
                    ContentDocument.LatestPublishedVersionId,
                    ContentDocument.CreatedDate
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :relatedRecordIds
                WITH USER_MODE
                ORDER BY ContentDocument.CreatedDate DESC
            ];

            Set<Id> processedIds = new Set<Id>();

            for (ContentDocumentLink linkRecord : links) {
                if (
                    processedIds.contains(
                        linkRecord.ContentDocumentId
                    )
                ) {
                    continue;
                }

                processedIds.add(
                    linkRecord.ContentDocumentId
                );

                files.add(
                    new Map<String, Object>{
                        'contentDocumentId' =>
                            linkRecord.ContentDocumentId,
                        'latestVersionId' =>
                            linkRecord.ContentDocument.LatestPublishedVersionId,
                        'title' =>
                            linkRecord.ContentDocument.Title,
                        'fileType' =>
                            linkRecord.ContentDocument.FileType,
                        'createdDate' =>
                            linkRecord.ContentDocument.CreatedDate
                    }
                );
            }
        } catch (Exception fileException) {
            warnings.add(
                'Unable to load Salesforce Files: ' +
                fileException.getMessage()
            );
        }

        return files;
    }
}