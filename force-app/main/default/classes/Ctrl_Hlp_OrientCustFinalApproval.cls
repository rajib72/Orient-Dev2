public with sharing class Ctrl_Hlp_OrientCustFinalApproval {

    private static final String ADMIN_PROFILE_NAME = 'System Administrator';
    private static final String STATUS_PENDING = 'Pending';
    private static final String STATUS_RETURNED = 'Returned';
    private static final String STATUS_FINAL_APPROVED = 'Final Approved';
    private static final String ACTION_FINAL_APPROVED = 'Final Approved';
    private static final String ACTION_REJECTED = 'Rejected';
    private static final String ITEM_STATUS_PENDING = 'Pending';
    private static final String ITEM_STATUS_RETURNED = 'Returned';
    private static final String ITEM_STATUS_FINAL_APPROVED = 'Final Approved';
    private static final String BC_STATUS_SUCCESS = 'Success';
    private static final String BC_STATUS_FAILED = 'Failed';
    private static final String BC_STATUS_NOT_REQUIRED = 'Not Required';

    private static final String KYC_METHOD_PAN = 'PAN';
    private static final String KYC_METHOD_VOTER = 'Voter ID';
    private static final String KYC_METHOD_GST = 'GST';

    public class FinalApprovalResult {
        public Boolean success;
        public Id approvalTransactionId;
        public String approvalStatus;
        public String message;
        public String bcCustomerNo;
        public String bcPushStatus;
        public Integer bcStatusCode;
        public Integer approvedFieldCount;
        public Integer rejectedFieldCount;
        public Boolean hasReturnedFields;
    }

    private class BCPushResult {
        public Boolean success;
        public Integer statusCode;
        public String message;
        public String requestBody;
        public String responseBody;
        public String customerNo;
        public Boolean wasCreate;

        /*
         * Diagnostic information persisted to Integration_Result__c
         * when a BC attempt fails.
         */
        public String endpoint;
        public String httpMethod;
        public String requestHeaders;
        public String responseStatus;
        public String correlationId;
        public Datetime requestDateTime;
        public Datetime responseDateTime;
        public Long durationMilliseconds;
        public String exceptionType;
        public Integer lineNumber;
        public String stackTrace;
    }

    public static FinalApprovalResult processFinalApproval(
        Id approvalTransactionId,
        String comments
    ) {
        if (approvalTransactionId == null) {
            throw new AuraHandledException('Approval Transaction Id is required.');
        }

        User currentUser = [
            SELECT Id, Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        Boolean isAdmin = currentUser.Profile != null &&
            currentUser.Profile.Name == ADMIN_PROFILE_NAME;

        Tagged_Approval_Hierarchy__c transactionRecord = getTransaction(approvalTransactionId, false);
        validateActionAccess(transactionRecord, currentUser.Id, isAdmin);
        validateFinalLevel(transactionRecord);

        Orient_Customer_Change_Request__c requestRecord = transactionRecord.Customer_Change_Request__r;
        List<Orient_Customer_Change_Item__c> changeItems = getChangeItems(requestRecord.Id);
        if (changeItems.isEmpty()) {
            throw new AuraHandledException('No Customer Profile change item is available for final approval.');
        }

        Map<String, Schema.SObjectField> accountFieldMap = Schema.SObjectType.Account.fields.getMap();
        validateAccountChangeFields(changeItems, accountFieldMap);
        validateFinalPicklistConfiguration(hasBCApplicableChanges(changeItems));

        Account accountRecord = getAccountForFinalApproval(
            requestRecord.Orient_Customer__c,
            changeItems,
            accountFieldMap
        );

        validateKycVerifiedFieldLocksAtFinalApproval(
            accountRecord,
            changeItems,
            requestRecord.Change_Reason__c,
            accountFieldMap
        );

        Account mergedAccount = accountRecord.clone(true, true, false, false);
        applyChangesToAccountInMemory(mergedAccount, changeItems, accountFieldMap);
        validateDuplicateMobileValues(mergedAccount, accountRecord.Id, changeItems);

        Boolean bcPushRequired = hasBCApplicableChanges(changeItems);
        BCPushResult bcResult = new BCPushResult();
        bcResult.success = true;
        bcResult.customerNo = objectToString(accountRecord.get('BC_Customer_No__c'));
        bcResult.message = 'No BC push is required for the approved fields.';

        Decimal attemptCount = requestRecord.BC_Push_Attempt_Count__c == null
            ? 0
            : requestRecord.BC_Push_Attempt_Count__c;

        if (bcPushRequired) {
            bcResult = pushApprovedChangesToBC(
                accountRecord,
                mergedAccount,
                requestRecord,
                changeItems,
                accountFieldMap
            );
            attemptCount++;

            if (!bcResult.success) {
                Id integrationLogId =
                    createBCFailureIntegrationLog(
                        requestRecord,
                        bcResult,
                        attemptCount
                    );

                Orient_Customer_Change_Request__c failedRequestUpdate =
                    new Orient_Customer_Change_Request__c(
                        Id = requestRecord.Id,
                        BC_Customer_No__c = bcResult.customerNo,
                        BC_Push_Status__c = BC_STATUS_FAILED,
                        BC_Push_Attempt_Count__c = attemptCount,
                        BC_Push_Date_Time__c = System.now(),
                        BC_Push_Message__c =
                            truncateMessage(
                                bcResult.message
                            ),
                        BC_Integration_Log__c =
                            integrationLogId
                    );
                update as user failedRequestUpdate;

                FinalApprovalResult failedResult = new FinalApprovalResult();
                failedResult.success = false;
                failedResult.approvalTransactionId = transactionRecord.Id;
                failedResult.approvalStatus = STATUS_PENDING;
                failedResult.bcCustomerNo = bcResult.customerNo;
                failedResult.bcPushStatus = BC_STATUS_FAILED;
                failedResult.bcStatusCode = bcResult.statusCode;
                failedResult.message =
                    'BC update failed. The request remains Pending at the final approval level. ' +
                    bcResult.message;
                return failedResult;
            }
        }

        Tagged_Approval_Hierarchy__c lockedTransaction = getTransaction(approvalTransactionId, true);
        validateActionAccess(lockedTransaction, currentUser.Id, isAdmin);
        validateFinalLevel(lockedTransaction);

        Datetime actionDateTime = System.now();
        String trimmedComments = String.isBlank(comments) ? null : comments.trim();
        Id finalLevelId = lockedTransaction.Current_Approval_Level__c;

        Account accountUpdate = buildAccountUpdate(
            accountRecord.Id,
            changeItems,
            accountFieldMap
        );

        applyKycVerificationCompletion(
            accountUpdate,
            accountRecord,
            changeItems,
            requestRecord.Change_Reason__c,
            accountFieldMap
        );

        if (bcResult.wasCreate == true && String.isNotBlank(bcResult.customerNo)) {
            accountUpdate.put('BC_Customer_No__c', bcResult.customerNo);
            accountUpdate.put('Status__c', 'Active');
        }
        update as user accountUpdate;

        String finalBcCustomerNo = String.isNotBlank(bcResult.customerNo)
            ? bcResult.customerNo
            : objectToString(accountRecord.get('BC_Customer_No__c'));

        Orient_Customer_Change_Request__c requestUpdate =
            new Orient_Customer_Change_Request__c(
                Id = requestRecord.Id,
                Approval_Status__c = STATUS_FINAL_APPROVED,
                Last_Action__c = ACTION_FINAL_APPROVED,
                Last_Action_By__c = currentUser.Id,
                Last_Action_Date_Time__c = actionDateTime,
                BC_Customer_No__c = finalBcCustomerNo,
                BC_Push_Status__c = bcPushRequired ? BC_STATUS_SUCCESS : BC_STATUS_NOT_REQUIRED,
                BC_Push_Attempt_Count__c = bcPushRequired ? attemptCount : requestRecord.BC_Push_Attempt_Count__c,
                BC_Push_Date_Time__c = bcPushRequired ? actionDateTime : requestRecord.BC_Push_Date_Time__c,
                BC_Push_Message__c = bcPushRequired
                    ? truncateMessage(bcResult.message)
                    : 'No BC push was required for this final approval.'
            );
        update as user requestUpdate;

        lockedTransaction.Approval_Status__c = STATUS_FINAL_APPROVED;
        lockedTransaction.Pending_With__c = null;
        lockedTransaction.Returned_From_Level__c = null;
        lockedTransaction.Final_Approved_By__c = currentUser.Id;
        lockedTransaction.Final_Approved_Date_Time__c = actionDateTime;
        lockedTransaction.Last_Action__c = ACTION_FINAL_APPROVED;
        lockedTransaction.Last_Action_By__c = currentUser.Id;
        lockedTransaction.Last_Action_Date_Time__c = actionDateTime;
        lockedTransaction.Last_Action_Comments__c = trimmedComments;
        update as user lockedTransaction;

        Approval_Action_History__c historyRecord = new Approval_Action_History__c(
            Approval_Transaction__c = lockedTransaction.Id,
            Approval_Level__c = finalLevelId,
            Action__c = ACTION_FINAL_APPROVED,
            Action_By__c = currentUser.Id,
            Action_Date_Time__c = actionDateTime,
            Assigned_To__c = null,
            Comments__c = trimmedComments,
            Previous_Status__c = STATUS_PENDING,
            New_Status__c = STATUS_FINAL_APPROVED,
            Submission_Cycle__c = lockedTransaction.Submission_Cycle__c
        );
        insert as user historyRecord;

        FinalApprovalResult result = new FinalApprovalResult();
        result.success = true;
        result.approvalTransactionId = lockedTransaction.Id;
        result.approvalStatus = STATUS_FINAL_APPROVED;
        result.bcCustomerNo = finalBcCustomerNo;
        result.bcPushStatus = bcPushRequired ? BC_STATUS_SUCCESS : BC_STATUS_NOT_REQUIRED;
        result.bcStatusCode = bcResult.statusCode;
        result.message = bcPushRequired
            ? 'Final approval completed successfully. The approved Customer values were updated in Salesforce and pushed to BC.'
            : 'Final approval completed successfully. The approved Customer values were updated in Salesforce. No BC push was required.';
        return result;
    }


    public static FinalApprovalResult processFinalFieldDecisions(
        Id approvalTransactionId,
        String decisionsJson,
        String comments
    ) {
        if (approvalTransactionId == null) {
            throw new AuraHandledException('Approval Transaction Id is required.');
        }

        if (String.isBlank(decisionsJson)) {
            throw new AuraHandledException('Final field approval decisions are required.');
        }

        User currentUser = [
            SELECT Id, Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        Boolean isAdmin =
            currentUser.Profile != null &&
            currentUser.Profile.Name == ADMIN_PROFILE_NAME;

        Tagged_Approval_Hierarchy__c transactionRecord =
            getTransaction(approvalTransactionId, false);

        validateActionAccess(
            transactionRecord,
            currentUser.Id,
            isAdmin
        );
        validateFinalLevel(transactionRecord);

        Orient_Customer_Change_Request__c requestRecord =
            transactionRecord.Customer_Change_Request__r;

        List<Orient_Customer_Change_Item__c> pendingItems =
            getPendingChangeItems(
                requestRecord.Id,
                transactionRecord.Submission_Cycle__c,
                false
            );

        if (pendingItems.isEmpty()) {
            throw new AuraHandledException(
                'No Pending Customer fields are available for final approval.'
            );
        }

        Map<Id, Map<String, Object>> decisionByItemId =
            parseFieldDecisions(decisionsJson);

        validateDecisionCoverage(
            pendingItems,
            decisionByItemId
        );

        validateAtomicKycFinalDecision(
            requestRecord.Change_Reason__c,
            pendingItems,
            decisionByItemId
        );

        List<Orient_Customer_Change_Item__c> approvedItems =
            new List<Orient_Customer_Change_Item__c>();

        Integer rejectedCount = 0;

        for (Orient_Customer_Change_Item__c itemRecord : pendingItems) {
            Map<String, Object> decisionRow =
                decisionByItemId.get(itemRecord.Id);

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
                approvedItems.add(itemRecord);
            } else {
                rejectedCount++;
            }
        }

        Integer approvedCount = approvedItems.size();

        if (approvedCount == 0) {
            return completeAllRejectedFinalDecision(
                transactionRecord,
                decisionByItemId,
                currentUser.Id,
                String.isBlank(comments)
                    ? null
                    : comments.trim()
            );
        }

        Map<String, Schema.SObjectField> accountFieldMap =
            Schema.SObjectType.Account.fields.getMap();

        validateAccountChangeFields(
            approvedItems,
            accountFieldMap
        );

        Boolean bcPushRequired =
            hasBCApplicableChanges(approvedItems);

        validateFinalFieldPicklistConfiguration(
            bcPushRequired,
            rejectedCount > 0
        );

        Account accountRecord =
            getAccountForFinalApproval(
                requestRecord.Orient_Customer__c,
                approvedItems,
                accountFieldMap
            );

        validateKycVerifiedFieldLocksAtFinalApproval(
            accountRecord,
            approvedItems,
            requestRecord.Change_Reason__c,
            accountFieldMap
        );

        Account mergedAccount =
            accountRecord.clone(
                true,
                true,
                false,
                false
            );

        applyChangesToAccountInMemory(
            mergedAccount,
            approvedItems,
            accountFieldMap
        );

        validateDuplicateMobileValues(
            mergedAccount,
            accountRecord.Id,
            approvedItems
        );

        BCPushResult bcResult = new BCPushResult();
        bcResult.success = true;
        bcResult.customerNo =
            objectToString(
                accountRecord.get('BC_Customer_No__c')
            );
        bcResult.message =
            'No BC push is required for the final-approved fields.';

        Decimal attemptCount =
            requestRecord.BC_Push_Attempt_Count__c == null
                ? 0
                : requestRecord.BC_Push_Attempt_Count__c;

        if (bcPushRequired) {
            bcResult =
                pushApprovedChangesToBC(
                    accountRecord,
                    mergedAccount,
                    requestRecord,
                    approvedItems,
                    accountFieldMap
                );

            attemptCount++;

            if (!bcResult.success) {
                Id integrationLogId =
                    createBCFailureIntegrationLog(
                        requestRecord,
                        bcResult,
                        attemptCount
                    );

                Orient_Customer_Change_Request__c failedRequestUpdate =
                    new Orient_Customer_Change_Request__c(
                        Id = requestRecord.Id,
                        BC_Customer_No__c =
                            bcResult.customerNo,
                        BC_Push_Status__c =
                            BC_STATUS_FAILED,
                        BC_Push_Attempt_Count__c =
                            attemptCount,
                        BC_Push_Date_Time__c =
                            System.now(),
                        BC_Push_Message__c =
                            truncateMessage(
                                bcResult.message
                            ),
                        BC_Integration_Log__c =
                            integrationLogId
                    );

                update failedRequestUpdate;

                FinalApprovalResult failedResult =
                    new FinalApprovalResult();

                failedResult.success = false;
                failedResult.approvalTransactionId =
                    transactionRecord.Id;
                failedResult.approvalStatus =
                    STATUS_PENDING;
                failedResult.bcCustomerNo =
                    bcResult.customerNo;
                failedResult.bcPushStatus =
                    BC_STATUS_FAILED;
                failedResult.bcStatusCode =
                    bcResult.statusCode;
                failedResult.approvedFieldCount =
                    approvedCount;
                failedResult.rejectedFieldCount =
                    rejectedCount;
                failedResult.hasReturnedFields =
                    false;
                failedResult.message =
                    'BC update failed. No final field decisions were committed. ' +
                    'The request remains Pending at the final approval level. ' +
                    bcResult.message;

                return failedResult;
            }
        }

        Tagged_Approval_Hierarchy__c lockedTransaction =
            getTransaction(
                approvalTransactionId,
                true
            );

        validateActionAccess(
            lockedTransaction,
            currentUser.Id,
            isAdmin
        );
        validateFinalLevel(lockedTransaction);

        List<Orient_Customer_Change_Item__c> lockedPendingItems =
            getPendingChangeItems(
                lockedTransaction.Customer_Change_Request__c,
                lockedTransaction.Submission_Cycle__c,
                true
            );

        validateDecisionCoverage(
            lockedPendingItems,
            decisionByItemId
        );

        validateAtomicKycFinalDecision(
            requestRecord.Change_Reason__c,
            lockedPendingItems,
            decisionByItemId
        );

        Datetime actionDateTime = System.now();
        String trimmedComments =
            String.isBlank(comments)
                ? null
                : comments.trim();

        Id finalLevelId =
            lockedTransaction.Current_Approval_Level__c;

        List<Orient_Customer_Change_Item__c> finalApprovedItems =
            new List<Orient_Customer_Change_Item__c>();

        List<Orient_Customer_Change_Item__c> itemUpdates =
            new List<Orient_Customer_Change_Item__c>();

        List<Approval_Action_History__c> historyRecords =
            new List<Approval_Action_History__c>();

        Integer finalRejectedCount = 0;

        for (Orient_Customer_Change_Item__c itemRecord : lockedPendingItems) {
            Map<String, Object> decisionRow =
                decisionByItemId.get(itemRecord.Id);

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

            if (decision == 'Approve') {
                finalApprovedItems.add(itemRecord);

                itemUpdates.add(
                    new Orient_Customer_Change_Item__c(
                        Id = itemRecord.Id,
                        Item_Approval_Status__c =
                            ITEM_STATUS_FINAL_APPROVED,
                        Final_Approved_By__c =
                            currentUser.Id,
                        Final_Approved_Date_Time__c =
                            actionDateTime,
                        Rejected_From_Level__c =
                            null,
                        Rejected_By__c =
                            null,
                        Rejected_Date_Time__c =
                            null,
                        Rejection_Reason__c =
                            null
                    )
                );

                historyRecords.add(
                    new Approval_Action_History__c(
                        Approval_Transaction__c =
                            lockedTransaction.Id,
                        Customer_Change_Item__c =
                            itemRecord.Id,
                        Approval_Level__c =
                            finalLevelId,
                        Action__c =
                            ACTION_FINAL_APPROVED,
                        Action_By__c =
                            currentUser.Id,
                        Action_Date_Time__c =
                            actionDateTime,
                        Assigned_To__c =
                            null,
                        Comments__c =
                            trimmedComments,
                        Previous_Status__c =
                            ITEM_STATUS_PENDING,
                        New_Status__c =
                            ITEM_STATUS_FINAL_APPROVED,
                        Submission_Cycle__c =
                            lockedTransaction.Submission_Cycle__c
                    )
                );
            } else {
                finalRejectedCount++;

                itemUpdates.add(
                    new Orient_Customer_Change_Item__c(
                        Id = itemRecord.Id,
                        Item_Approval_Status__c =
                            ITEM_STATUS_RETURNED,
                        Rejected_From_Level__c =
                            finalLevelId,
                        Rejected_By__c =
                            currentUser.Id,
                        Rejected_Date_Time__c =
                            actionDateTime,
                        Rejection_Reason__c =
                            rejectionReason,
                        Final_Approved_By__c =
                            null,
                        Final_Approved_Date_Time__c =
                            null
                    )
                );

                historyRecords.add(
                    new Approval_Action_History__c(
                        Approval_Transaction__c =
                            lockedTransaction.Id,
                        Customer_Change_Item__c =
                            itemRecord.Id,
                        Approval_Level__c =
                            finalLevelId,
                        Action__c =
                            ACTION_REJECTED,
                        Action_By__c =
                            currentUser.Id,
                        Action_Date_Time__c =
                            actionDateTime,
                        Assigned_To__c =
                            lockedTransaction.Submitted_By__c,
                        Comments__c =
                            rejectionReason,
                        Previous_Status__c =
                            ITEM_STATUS_PENDING,
                        New_Status__c =
                            ITEM_STATUS_RETURNED,
                        Submission_Cycle__c =
                            lockedTransaction.Submission_Cycle__c
                    )
                );
            }
        }

        Account accountUpdate =
            buildAccountUpdate(
                accountRecord.Id,
                finalApprovedItems,
                accountFieldMap
            );

        applyKycVerificationCompletion(
            accountUpdate,
            accountRecord,
            finalApprovedItems,
            requestRecord.Change_Reason__c,
            accountFieldMap
        );

        if (
            bcResult.wasCreate == true &&
            String.isNotBlank(
                bcResult.customerNo
            )
        ) {
            accountUpdate.put(
                'BC_Customer_No__c',
                bcResult.customerNo
            );
            accountUpdate.put(
                'Status__c',
                'Active'
            );
        }

        update accountUpdate;

        if (!itemUpdates.isEmpty()) {
            update itemUpdates;
        }

        if (!historyRecords.isEmpty()) {
            insert historyRecords;
        }

        String finalBcCustomerNo =
            String.isNotBlank(
                bcResult.customerNo
            )
                ? bcResult.customerNo
                : objectToString(
                    accountRecord.get(
                        'BC_Customer_No__c'
                    )
                );

        Integer previousReturnedCount = [
            SELECT COUNT()
            FROM Orient_Customer_Change_Item__c
            WHERE Change_Request__c =
                :lockedTransaction.Customer_Change_Request__c
            AND Item_Approval_Status__c =
                :ITEM_STATUS_RETURNED
        ];

        Boolean hasReturnedFields =
            previousReturnedCount > 0;

        String bcStatusValue =
            bcPushRequired
                ? BC_STATUS_SUCCESS
                : BC_STATUS_NOT_REQUIRED;

        Orient_Customer_Change_Request__c requestUpdate =
            new Orient_Customer_Change_Request__c(
                Id =
                    lockedTransaction.Customer_Change_Request__c,
                Approval_Status__c =
                    hasReturnedFields
                        ? STATUS_RETURNED
                        : STATUS_FINAL_APPROVED,
                Last_Action__c =
                    hasReturnedFields
                        ? ACTION_REJECTED
                        : ACTION_FINAL_APPROVED,
                Last_Action_By__c =
                    currentUser.Id,
                Last_Action_Date_Time__c =
                    actionDateTime,
                BC_Customer_No__c =
                    finalBcCustomerNo,
                BC_Push_Status__c =
                    bcStatusValue,
                BC_Push_Attempt_Count__c =
                    bcPushRequired
                        ? attemptCount
                        : requestRecord.BC_Push_Attempt_Count__c,
                BC_Push_Date_Time__c =
                    bcPushRequired
                        ? actionDateTime
                        : requestRecord.BC_Push_Date_Time__c,
                BC_Push_Message__c =
                    bcPushRequired
                        ? truncateMessage(
                            bcResult.message
                        )
                        : 'No BC push was required for the final-approved fields.'
            );

        update requestUpdate;

        lockedTransaction.Approval_Status__c =
            hasReturnedFields
                ? STATUS_RETURNED
                : STATUS_FINAL_APPROVED;

        lockedTransaction.Pending_With__c =
            hasReturnedFields
                ? lockedTransaction.Submitted_By__c
                : null;

        lockedTransaction.Returned_From_Level__c =
            finalRejectedCount > 0
                ? finalLevelId
                : null;

        lockedTransaction.Final_Approved_By__c =
            hasReturnedFields
                ? null
                : currentUser.Id;

        lockedTransaction.Final_Approved_Date_Time__c =
            hasReturnedFields
                ? null
                : actionDateTime;

        lockedTransaction.Last_Action__c =
            hasReturnedFields
                ? ACTION_REJECTED
                : ACTION_FINAL_APPROVED;

        lockedTransaction.Last_Action_By__c =
            currentUser.Id;

        lockedTransaction.Last_Action_Date_Time__c =
            actionDateTime;

        lockedTransaction.Last_Action_Comments__c =
            buildFinalFieldDecisionSummary(
                finalApprovedItems.size(),
                previousReturnedCount,
                trimmedComments
            );

        update lockedTransaction;

        FinalApprovalResult result =
            new FinalApprovalResult();

        result.success = true;
        result.approvalTransactionId =
            lockedTransaction.Id;
        result.approvalStatus =
            lockedTransaction.Approval_Status__c;
        result.bcCustomerNo =
            finalBcCustomerNo;
        result.bcPushStatus =
            bcStatusValue;
        result.bcStatusCode =
            bcResult.statusCode;
        result.approvedFieldCount =
            finalApprovedItems.size();
        result.rejectedFieldCount =
            previousReturnedCount;
        result.hasReturnedFields =
            hasReturnedFields;

        if (hasReturnedFields) {
            result.message =
                String.valueOf(
                    finalApprovedItems.size()
                ) +
                ' field(s) reached Final Approval and were applied to the Customer. ' +
                String.valueOf(
                    previousReturnedCount
                ) +
                ' field(s) remain Returned for correction and resubmission.' +
                (
                    bcPushRequired
                        ? ' Final-approved BC fields were pushed successfully.'
                        : ''
                );
        } else {
            result.message =
                String.valueOf(
                    finalApprovedItems.size()
                ) +
                ' field(s) reached Final Approval and were applied to the Customer. ' +
                (
                    bcPushRequired
                        ? ' The BC update completed successfully.'
                        : ' No BC push was required.'
                );
        }

        return result;
    }

    @TestVisible
    private static FinalApprovalResult completeAllRejectedFinalDecision(
        Tagged_Approval_Hierarchy__c transactionRecord,
        Map<Id, Map<String, Object>> decisionByItemId,
        Id actionUserId,
        String comments
    ) {
        Tagged_Approval_Hierarchy__c lockedTransaction =
            getTransaction(
                transactionRecord.Id,
                true
            );

        User currentUser = [
            SELECT Id, Profile.Name
            FROM User
            WHERE Id = :actionUserId
            LIMIT 1
        ];

        Boolean isAdmin =
            currentUser.Profile != null &&
            currentUser.Profile.Name == ADMIN_PROFILE_NAME;

        validateActionAccess(
            lockedTransaction,
            actionUserId,
            isAdmin
        );
        validateFinalLevel(
            lockedTransaction
        );

        List<Orient_Customer_Change_Item__c> lockedPendingItems =
            getPendingChangeItems(
                lockedTransaction.Customer_Change_Request__c,
                lockedTransaction.Submission_Cycle__c,
                true
            );

        validateDecisionCoverage(
            lockedPendingItems,
            decisionByItemId
        );

        if (lockedTransaction.Submitted_By__c == null) {
            throw new AuraHandledException(
                'The original submitter is missing. The rejected fields cannot be returned.'
            );
        }

        Datetime actionDateTime =
            System.now();

        List<Orient_Customer_Change_Item__c> itemUpdates =
            new List<Orient_Customer_Change_Item__c>();

        List<Approval_Action_History__c> historyRecords =
            new List<Approval_Action_History__c>();

        for (Orient_Customer_Change_Item__c itemRecord : lockedPendingItems) {
            Map<String, Object> decisionRow =
                decisionByItemId.get(
                    itemRecord.Id
                );

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
                decision != 'Reject' ||
                String.isBlank(
                    rejectionReason
                )
            ) {
                throw new AuraHandledException(
                    'Every final-level field must be rejected with a reason when no field is approved.'
                );
            }

            itemUpdates.add(
                new Orient_Customer_Change_Item__c(
                    Id =
                        itemRecord.Id,
                    Item_Approval_Status__c =
                        ITEM_STATUS_RETURNED,
                    Rejected_From_Level__c =
                        lockedTransaction.Current_Approval_Level__c,
                    Rejected_By__c =
                        actionUserId,
                    Rejected_Date_Time__c =
                        actionDateTime,
                    Rejection_Reason__c =
                        rejectionReason,
                    Final_Approved_By__c =
                        null,
                    Final_Approved_Date_Time__c =
                        null
                )
            );

            historyRecords.add(
                new Approval_Action_History__c(
                    Approval_Transaction__c =
                        lockedTransaction.Id,
                    Customer_Change_Item__c =
                        itemRecord.Id,
                    Approval_Level__c =
                        lockedTransaction.Current_Approval_Level__c,
                    Action__c =
                        ACTION_REJECTED,
                    Action_By__c =
                        actionUserId,
                    Action_Date_Time__c =
                        actionDateTime,
                    Assigned_To__c =
                        lockedTransaction.Submitted_By__c,
                    Comments__c =
                        rejectionReason,
                    Previous_Status__c =
                        ITEM_STATUS_PENDING,
                    New_Status__c =
                        ITEM_STATUS_RETURNED,
                    Submission_Cycle__c =
                        lockedTransaction.Submission_Cycle__c
                )
            );
        }

        update itemUpdates;
        insert historyRecords;

        update new Orient_Customer_Change_Request__c(
            Id =
                lockedTransaction.Customer_Change_Request__c,
            Approval_Status__c =
                STATUS_RETURNED,
            Last_Action__c =
                ACTION_REJECTED,
            Last_Action_By__c =
                actionUserId,
            Last_Action_Date_Time__c =
                actionDateTime
        );

        lockedTransaction.Approval_Status__c =
            STATUS_RETURNED;
        lockedTransaction.Pending_With__c =
            lockedTransaction.Submitted_By__c;
        lockedTransaction.Returned_From_Level__c =
            lockedTransaction.Current_Approval_Level__c;
        lockedTransaction.Last_Action__c =
            ACTION_REJECTED;
        lockedTransaction.Last_Action_By__c =
            actionUserId;
        lockedTransaction.Last_Action_Date_Time__c =
            actionDateTime;
        lockedTransaction.Last_Action_Comments__c =
            buildFinalFieldDecisionSummary(
                0,
                lockedPendingItems.size(),
                comments
            );
        lockedTransaction.Final_Approved_By__c =
            null;
        lockedTransaction.Final_Approved_Date_Time__c =
            null;

        update lockedTransaction;

        FinalApprovalResult result =
            new FinalApprovalResult();

        result.success = true;
        result.approvalTransactionId =
            lockedTransaction.Id;
        result.approvalStatus =
            STATUS_RETURNED;
        result.approvedFieldCount =
            0;
        result.rejectedFieldCount =
            lockedPendingItems.size();
        result.hasReturnedFields =
            true;
        result.message =
            'All surviving fields were rejected at the final approval level and returned to the original submitter.';

        return result;
    }

    @TestVisible
    private static Map<Id, Map<String, Object>> parseFieldDecisions(
        String decisionsJson
    ) {
        Object parsed =
            JSON.deserializeUntyped(
                decisionsJson
            );

        if (
            !(parsed instanceof List<Object>)
        ) {
            throw new AuraHandledException(
                'Invalid final field decision payload.'
            );
        }

        Map<Id, Map<String, Object>> decisionByItemId =
            new Map<Id, Map<String, Object>>();

        for (
            Object rowObject :
            (List<Object>) parsed
        ) {
            if (
                !(rowObject instanceof Map<String, Object>)
            ) {
                continue;
            }

            Map<String, Object> decisionRow =
                (Map<String, Object>) rowObject;

            String itemIdText =
                decisionRow.get('changeItemId') == null
                    ? null
                    : String.valueOf(
                        decisionRow.get(
                            'changeItemId'
                        )
                    );

            if (
                String.isBlank(
                    itemIdText
                )
            ) {
                continue;
            }

            decisionByItemId.put(
                (Id) itemIdText,
                decisionRow
            );
        }

        return decisionByItemId;
    }

    @TestVisible
    private static void validateDecisionCoverage(
        List<Orient_Customer_Change_Item__c> pendingItems,
        Map<Id, Map<String, Object>> decisionByItemId
    ) {
        if (
            decisionByItemId.size() !=
            pendingItems.size()
        ) {
            throw new AuraHandledException(
                'Approve or Reject every Pending field before submitting final decisions.'
            );
        }

        Set<Id> pendingIds =
            new Set<Id>();

        for (
            Orient_Customer_Change_Item__c itemRecord :
            pendingItems
        ) {
            pendingIds.add(
                itemRecord.Id
            );

            if (
                !decisionByItemId.containsKey(
                    itemRecord.Id
                )
            ) {
                throw new AuraHandledException(
                    'Decision is missing for field "' +
                    itemRecord.Field_Label__c +
                    '".'
                );
            }
        }

        for (
            Id decisionItemId :
            decisionByItemId.keySet()
        ) {
            if (
                !pendingIds.contains(
                    decisionItemId
                )
            ) {
                throw new AuraHandledException(
                    'The final field decision payload contains a field that is no longer Pending.'
                );
            }
        }
    }

    /*
     * KYC requests are atomic at the final approval level.
     * Every Pending KYC field must receive the same decision:
     * either Approve All or Reject/Return All.
     *
     * Normal Customer Profile requests retain field-level decisions.
     */
    @TestVisible
    private static void validateAtomicKycFinalDecision(
        String changeReason,
        List<Orient_Customer_Change_Item__c> pendingItems,
        Map<Id, Map<String, Object>> decisionByItemId
    ) {
        String kycMethod =
            extractKycMethodFromReason(
                changeReason
            );

        if (String.isBlank(kycMethod)) {
            return;
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

            if (
                decisionRow == null ||
                decisionRow.get('decision') == null
            ) {
                throw new AuraHandledException(
                    'A decision is required for every Pending KYC field.'
                );
            }

            String decision =
                String.valueOf(
                    decisionRow.get('decision')
                ).trim();

            if (
                decision != 'Approve' &&
                decision != 'Reject'
            ) {
                throw new AuraHandledException(
                    'KYC approval supports only Approve All or Return All.'
                );
            }

            if (atomicDecision == null) {
                atomicDecision =
                    decision;
            } else if (
                atomicDecision !=
                decision
            ) {
                throw new AuraHandledException(
                    getKycDisplayNameForFinalApproval(
                        kycMethod
                    ) +
                    ' is an atomic KYC approval. ' +
                    'All Pending KYC fields must be approved together or returned together. ' +
                    'Mixed field decisions are not allowed.'
                );
            }
        }
    }

    @TestVisible
    private static String getKycDisplayNameForFinalApproval(
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
    private static List<Orient_Customer_Change_Item__c> getPendingChangeItems(
        Id requestId,
        Decimal submissionCycle,
        Boolean forUpdate
    ) {
        if (forUpdate) {
            return [
                SELECT Id, Change_Request__c,
                       Account_Field_API__c,
                       Field_Data_Type__c,
                       Field_Label__c,
                       New_Value__c,
                       New_Display_Value__c,
                       Tracking_Field_API__c,
                       BC_Push_Applicable__c,
                       BC_Payload_Key__c,
                       Section_Name__c,
                       Sequence__c,
                       Item_Approval_Status__c,
                       Submission_Cycle__c
                FROM Orient_Customer_Change_Item__c
                WHERE Change_Request__c =
                    :requestId
                AND Item_Approval_Status__c =
                    :ITEM_STATUS_PENDING
                AND Submission_Cycle__c =
                    :submissionCycle
                FOR UPDATE
            ];
        }

        return [
            SELECT Id, Change_Request__c,
                   Account_Field_API__c,
                   Field_Data_Type__c,
                   Field_Label__c,
                   New_Value__c,
                   New_Display_Value__c,
                   Tracking_Field_API__c,
                   BC_Push_Applicable__c,
                   BC_Payload_Key__c,
                   Section_Name__c,
                   Sequence__c,
                   Item_Approval_Status__c,
                   Submission_Cycle__c
            FROM Orient_Customer_Change_Item__c
            WHERE Change_Request__c =
                :requestId
            AND Item_Approval_Status__c =
                :ITEM_STATUS_PENDING
            AND Submission_Cycle__c =
                :submissionCycle
            WITH USER_MODE
            ORDER BY Sequence__c ASC,
                     CreatedDate ASC
        ];
    }

    @TestVisible
    private static String buildFinalFieldDecisionSummary(
        Integer approvedCount,
        Integer returnedCount,
        String comments
    ) {
        String summary =
            'Final Field Decisions: ' +
            String.valueOf(
                approvedCount
            ) +
            ' Final Approved, ' +
            String.valueOf(
                returnedCount
            ) +
            ' Returned.';

        if (
            String.isNotBlank(
                comments
            )
        ) {
            summary +=
                ' Comments: ' +
                comments;
        }

        return summary;
    }

    @TestVisible
    private static Tagged_Approval_Hierarchy__c getTransaction(
        Id approvalTransactionId,
        Boolean forUpdate
    ) {
        String queryText =
            'SELECT Id, Approval_Hierarchy__c, Approval_Status__c, ' +
            'Current_Approval_Level__c, Current_Approval_Level__r.Name, ' +
            'Current_Approval_Level__r.Responsible_Team__c, Current_Approval_Level__r.Sr_No__c, ' +
            'Pending_With__c, Submission_Cycle__c, Submitted_By__c, ' +
            'Customer_Change_Request__c, ' +
            'Customer_Change_Request__r.Id, Customer_Change_Request__r.Orient_Customer__c, ' +
            'Customer_Change_Request__r.Orient_Customer_Tracking__c, ' +
            'Customer_Change_Request__r.Location_Code__c, ' +
            'Customer_Change_Request__r.Change_Reason__c, ' +
            'Customer_Change_Request__r.BC_Push_Attempt_Count__c, ' +
            'Customer_Change_Request__r.BC_Push_Date_Time__c, ' +
            'Customer_Change_Request__r.BC_Push_Status__c, ' +
            'Customer_Change_Request__r.BC_Push_Message__c, ' +
            'Customer_Change_Request__r.BC_Customer_No__c ' +
            'FROM Tagged_Approval_Hierarchy__c ' +
            'WHERE Id = \'' + String.escapeSingleQuotes(String.valueOf(approvalTransactionId)) + '\' ' +
            'AND Customer_Change_Request__c != null LIMIT 1';

        if (forUpdate) {
            queryText += ' FOR UPDATE';
        }

        List<Tagged_Approval_Hierarchy__c> transactions = Database.query(queryText);
        if (transactions.isEmpty()) {
            throw new AuraHandledException('Customer Profile approval transaction could not be found.');
        }
        return transactions[0];
    }

    @TestVisible
    private static void validateActionAccess(
        Tagged_Approval_Hierarchy__c transactionRecord,
        Id userId,
        Boolean isAdmin
    ) {
        if (transactionRecord.Approval_Status__c != STATUS_PENDING) {
            throw new AuraHandledException(
                'This request is no longer Pending. Refresh the workspace and try again.'
            );
        }

        if (!isAdmin && transactionRecord.Pending_With__c != userId) {
            throw new AuraHandledException(
                'This request is not currently assigned to you for approval.'
            );
        }
    }

    @TestVisible
    private static void validateFinalLevel(Tagged_Approval_Hierarchy__c transactionRecord) {
        if (
            transactionRecord.Approval_Hierarchy__c == null ||
            transactionRecord.Current_Approval_Level__c == null ||
            transactionRecord.Current_Approval_Level__r == null ||
            transactionRecord.Current_Approval_Level__r.Sr_No__c == null
        ) {
            throw new AuraHandledException(
                'Current Customer Profile approval routing is incomplete.'
            );
        }

        List<Approval_Hierarchy_Level__c> nextLevels = [
            SELECT Id
            FROM Approval_Hierarchy_Level__c
            WHERE Approval_Hierarchy__c = :transactionRecord.Approval_Hierarchy__c
            AND Sr_No__c > :transactionRecord.Current_Approval_Level__r.Sr_No__c
            WITH USER_MODE
            LIMIT 1
        ];

        if (!nextLevels.isEmpty()) {
            throw new AuraHandledException(
                'This request is not at the final approval level. Refresh the workspace and try again.'
            );
        }
    }

    @TestVisible
    private static List<Orient_Customer_Change_Item__c> getChangeItems(Id requestId) {
        return [
            SELECT Id, Change_Request__c, Account_Field_API__c,
                   Field_Data_Type__c, Field_Label__c,
                   New_Value__c, New_Display_Value__c,
                   Tracking_Field_API__c,
                   BC_Push_Applicable__c, BC_Payload_Key__c,
                   Section_Name__c, Sequence__c,
                   Item_Approval_Status__c, Submission_Cycle__c,
                   Rejected_From_Level__c, Rejected_By__c,
                   Rejected_Date_Time__c, Rejection_Reason__c,
                   Final_Approved_By__c, Final_Approved_Date_Time__c
            FROM Orient_Customer_Change_Item__c
            WHERE Change_Request__c = :requestId
            WITH USER_MODE
            ORDER BY Sequence__c ASC, CreatedDate ASC
        ];
    }

    @TestVisible
    private static void validateAccountChangeFields(
        List<Orient_Customer_Change_Item__c> changeItems,
        Map<String, Schema.SObjectField> accountFieldMap
    ) {
        for (Orient_Customer_Change_Item__c item : changeItems) {
            if (
                String.isBlank(item.Account_Field_API__c) ||
                !accountFieldMap.containsKey(item.Account_Field_API__c)
            ) {
                throw new AuraHandledException(
                    'Account field configuration is invalid for change item "' + item.Field_Label__c + '".'
                );
            }

            Schema.DescribeFieldResult fieldDescribe =
                accountFieldMap.get(item.Account_Field_API__c).getDescribe();
            if (!fieldDescribe.isUpdateable()) {
                throw new AuraHandledException(
                    'You do not have permission to update Customer field "' + item.Field_Label__c + '".'
                );
            }

            if (
                item.BC_Push_Applicable__c == true &&
                String.isBlank(item.BC_Payload_Key__c)
            ) {
                throw new AuraHandledException(
                    'BC Payload Key is missing for Customer field "' + item.Field_Label__c + '".'
                );
            }
        }
    }

    @TestVisible
    private static Account getAccountForFinalApproval(
        Id accountId,
        List<Orient_Customer_Change_Item__c> changeItems,
        Map<String, Schema.SObjectField> accountFieldMap
    ) {
        if (accountId == null) {
            throw new AuraHandledException('Customer is missing from the Change Request.');
        }

        Set<String> fieldApis = new Set<String>{
            'Id', 'Name', 'Permanent_Address__c', 'Residential_City__c',
            'Pin_Code__c', 'Email_Address__c', 'Customer_Verification_KYC__c',
            'Whatsapp_number__c', 'Phone', 'Locality_Area__c', 'AadharNo__c',
            'BC_Customer_No__c', 'Country__c', 'Country_Region_Code__c',
            'KYC_Verified__c', 'Date_Of_Birth__c', 'Anniversary_Date__c',
            'District__c', 'GST__c', 'PAN__c', 'StateCode__c',
            'State_Province__c', 'Village__c', 'Status__c', 'Landmark__c'
        };

        Set<String> changedFieldApis =
            new Set<String>();

        for (Orient_Customer_Change_Item__c item : changeItems) {
            if (accountFieldMap.containsKey(item.Account_Field_API__c)) {
                fieldApis.add(item.Account_Field_API__c);
                changedFieldApis.add(item.Account_Field_API__c);
            }
        }

        /*
         * Query the mapped verification checkbox as well so the final
         * approval can re-check Verified Lock immediately before the BC
         * push / Salesforce commit.
         */
        if (!changedFieldApis.isEmpty()) {
            for (
                Orient_Customer_Field_Mapping__mdt mapping : [
                    SELECT Account_Field_API__c,
                           Verification_Field_API__c,
                           Change_Mode__c,
                           Active__c
                    FROM Orient_Customer_Field_Mapping__mdt
                    WHERE Active__c = true
                    AND Account_Field_API__c IN :changedFieldApis
                ]
            ) {
                if (
                    String.isNotBlank(
                        mapping.Verification_Field_API__c
                    ) &&
                    accountFieldMap.containsKey(
                        mapping.Verification_Field_API__c
                    )
                ) {
                    fieldApis.add(
                        mapping.Verification_Field_API__c
                    );
                }
            }
        }

        List<String> queryFields = new List<String>();
        queryFields.addAll(fieldApis);
        queryFields.sort();

        String queryText =
            'SELECT ' + String.join(queryFields, ',') +
            ' FROM Account WHERE Id = \'' +
            String.escapeSingleQuotes(String.valueOf(accountId)) +
            '\' WITH USER_MODE LIMIT 1';

        List<Account> accounts = Database.query(queryText);
        if (accounts.isEmpty()) {
            throw new AuraHandledException('Customer record could not be found.');
        }
        return accounts[0];
    }

    /*
     * Defense-in-depth Verified Lock check for KYC final approval.
     *
     * A request can remain Pending for some time. If any requested field
     * becomes verified before the final approver acts, the old KYC request
     * must not overwrite that verified value.
     */
    @TestVisible
    private static void validateKycVerifiedFieldLocksAtFinalApproval(
        Account currentAccount,
        List<Orient_Customer_Change_Item__c> approvedItems,
        String changeReason,
        Map<String, Schema.SObjectField> accountFieldMap
    ) {
        if (
            currentAccount == null ||
            approvedItems == null ||
            approvedItems.isEmpty() ||
            String.isBlank(
                extractKycMethodFromReason(
                    changeReason
                )
            )
        ) {
            return;
        }

        Set<String> requestedFieldApis =
            new Set<String>();

        for (
            Orient_Customer_Change_Item__c itemRecord :
            approvedItems
        ) {
            if (
                String.isNotBlank(
                    itemRecord.Account_Field_API__c
                )
            ) {
                requestedFieldApis.add(
                    itemRecord.Account_Field_API__c
                );
            }
        }

        if (requestedFieldApis.isEmpty()) {
            return;
        }

        Map<String, Orient_Customer_Field_Mapping__mdt>
            mappingByField =
                new Map<String, Orient_Customer_Field_Mapping__mdt>();

        for (
            Orient_Customer_Field_Mapping__mdt mapping : [
                SELECT Account_Field_API__c,
                       Field_Label__c,
                       Verification_Field_API__c,
                       Change_Mode__c,
                       Active__c
                FROM Orient_Customer_Field_Mapping__mdt
                WHERE Active__c = true
                AND Account_Field_API__c IN :requestedFieldApis
            ]
        ) {
            mappingByField.put(
                mapping.Account_Field_API__c,
                mapping
            );
        }

        List<String> lockedFieldLabels =
            new List<String>();

        for (
            Orient_Customer_Change_Item__c itemRecord :
            approvedItems
        ) {
            Orient_Customer_Field_Mapping__mdt mapping =
                mappingByField.get(
                    itemRecord.Account_Field_API__c
                );

            if (
                mapping == null ||
                mapping.Change_Mode__c !=
                    'Verified Lock' ||
                String.isBlank(
                    mapping.Verification_Field_API__c
                ) ||
                !accountFieldMap.containsKey(
                    mapping.Verification_Field_API__c
                )
            ) {
                continue;
            }

            Object verificationValue;

            try {
                verificationValue =
                    currentAccount.get(
                        mapping.Verification_Field_API__c
                    );
            } catch (Exception missingQueriedField) {
                verificationValue =
                    null;
            }

            Boolean isVerified =
                verificationValue instanceof Boolean
                    ? (Boolean) verificationValue
                    : (
                        verificationValue != null &&
                        String.valueOf(
                            verificationValue
                        ).equalsIgnoreCase(
                            'true'
                        )
                    );

            if (!isVerified) {
                continue;
            }

            Schema.DescribeFieldResult fieldDescribe =
                accountFieldMap.get(
                    itemRecord.Account_Field_API__c
                ).getDescribe();

            Object currentValue =
                currentAccount.get(
                    itemRecord.Account_Field_API__c
                );

            Object requestedValue =
                deserializeAccountValue(
                    itemRecord.New_Value__c,
                    fieldDescribe
                );

            if (
                !finalApprovalValuesEqual(
                    currentValue,
                    requestedValue
                )
            ) {
                lockedFieldLabels.add(
                    String.isNotBlank(
                        mapping.Field_Label__c
                    )
                        ? mapping.Field_Label__c
                        : itemRecord.Field_Label__c
                );
            }
        }

        if (!lockedFieldLabels.isEmpty()) {
            throw new AuraHandledException(
                'Final KYC approval cannot continue because the following Customer field(s) are already verified: ' +
                String.join(
                    lockedFieldLabels,
                    ', '
                ) +
                '. No BC push or Salesforce field update was committed.'
            );
        }
    }

    @TestVisible
    private static Boolean finalApprovalValuesEqual(
        Object currentValue,
        Object requestedValue
    ) {
        if (
            currentValue == null &&
            requestedValue == null
        ) {
            return true;
        }

        if (
            currentValue == null ||
            requestedValue == null
        ) {
            return false;
        }

        return String.valueOf(
            currentValue
        ) ==
        String.valueOf(
            requestedValue
        );
    }

    @TestVisible
    private static void applyChangesToAccountInMemory(
        Account accountRecord,
        List<Orient_Customer_Change_Item__c> changeItems,
        Map<String, Schema.SObjectField> accountFieldMap
    ) {
        for (Orient_Customer_Change_Item__c item : changeItems) {
            Schema.DescribeFieldResult fieldDescribe =
                accountFieldMap.get(item.Account_Field_API__c).getDescribe();
            accountRecord.put(
                item.Account_Field_API__c,
                deserializeAccountValue(item.New_Value__c, fieldDescribe)
            );
        }
    }

    @TestVisible
    private static Account buildAccountUpdate(
        Id accountId,
        List<Orient_Customer_Change_Item__c> changeItems,
        Map<String, Schema.SObjectField> accountFieldMap
    ) {
        Account accountUpdate = new Account(Id = accountId);
        for (Orient_Customer_Change_Item__c item : changeItems) {
            Schema.DescribeFieldResult fieldDescribe =
                accountFieldMap.get(item.Account_Field_API__c).getDescribe();
            accountUpdate.put(
                item.Account_Field_API__c,
                deserializeAccountValue(item.New_Value__c, fieldDescribe)
            );
        }
        return accountUpdate;
    }

    @TestVisible
    private static Object deserializeAccountValue(
        String rawValue,
        Schema.DescribeFieldResult fieldDescribe
    ) {
        if (fieldDescribe == null) {
            return rawValue;
        }

        Schema.DisplayType typeValue = fieldDescribe.getType();
        String stringValue = rawValue == null ? null : rawValue.trim();

        if (typeValue == Schema.DisplayType.Reference || typeValue == Schema.DisplayType.Id) {
            return String.isBlank(stringValue) ? null : (Id) stringValue;
        }
        if (typeValue == Schema.DisplayType.Boolean) {
            return String.isBlank(stringValue) ? null : Boolean.valueOf(stringValue);
        }
        if (typeValue == Schema.DisplayType.Date) {
            return String.isBlank(stringValue) ? null : Date.valueOf(stringValue);
        }
        if (typeValue == Schema.DisplayType.DateTime) {
            if (String.isBlank(stringValue)) {
                return null;
            }
            return Datetime.valueOf(stringValue.replace('T', ' ').replace('Z', ''));
        }
        if (typeValue == Schema.DisplayType.Integer) {
            return String.isBlank(stringValue) ? null : Integer.valueOf(stringValue);
        }
        if (
            typeValue == Schema.DisplayType.Double ||
            typeValue == Schema.DisplayType.Currency ||
            typeValue == Schema.DisplayType.Percent
        ) {
            return String.isBlank(stringValue) ? null : Decimal.valueOf(stringValue);
        }
        return rawValue;
    }

    /*
     * KYC-originated requests are identified by the machine-readable prefix
     * in Change Reason. Only fields that actually reached Final Approval get
     * their mapped verification checkbox set to true.
     */
    /*
     * KYC verification is completed only after Final Approval.
     *
     * A Surepass KYC method verifies a complete logical field set even when
     * only the mismatched values needed approval:
     *
     * PAN      -> PAN, Name, DOB, Gender
     * Voter ID -> Voter / EPIC, Name, Gender
     * GST      -> GSTIN, Name
     *
     * Matching fields are intentionally NOT manufactured as approval items.
     * Their verification checkboxes are completed here, together with the
     * changed fields that actually reached Final Approval.
     */
    @TestVisible
    private static void applyKycVerificationCompletion(
        Account accountUpdate,
        Account currentAccount,
        List<Orient_Customer_Change_Item__c> approvedItems,
        String changeReason,
        Map<String, Schema.SObjectField> accountFieldMap
    ) {
        String kycMethod =
            extractKycMethodFromReason(
                changeReason
            );

        if (
            String.isBlank(kycMethod) ||
            accountUpdate == null ||
            currentAccount == null ||
            approvedItems == null ||
            approvedItems.isEmpty()
        ) {
            return;
        }

        Set<String> approvedFieldApis =
            new Set<String>();

        for (
            Orient_Customer_Change_Item__c itemRecord :
            approvedItems
        ) {
            if (
                String.isNotBlank(
                    itemRecord.Account_Field_API__c
                )
            ) {
                approvedFieldApis.add(
                    itemRecord.Account_Field_API__c
                );
            }
        }

        /*
         * The verification scope is based on the KYC method, not only on
         * fields whose values were different.
         *
         * Example:
         * PAN + Name match, while DOB + Gender require approval.
         * Only DOB + Gender are Change Items, but after Final Approval all
         * four PAN verification flags must be completed.
         */
        Set<String> verificationScopeFieldApis =
            new Set<String>();

        if (kycMethod == KYC_METHOD_PAN) {
            verificationScopeFieldApis.add(
                'PAN__c'
            );
            verificationScopeFieldApis.add(
                'Name'
            );
            verificationScopeFieldApis.add(
                'Date_Of_Birth__c'
            );
            verificationScopeFieldApis.add(
                'Gender__c'
            );
        } else if (
            kycMethod == KYC_METHOD_VOTER
        ) {
            verificationScopeFieldApis.add(
                'Voter__c'
            );
            verificationScopeFieldApis.add(
                'Name'
            );
            verificationScopeFieldApis.add(
                'Gender__c'
            );
        } else if (
            kycMethod == KYC_METHOD_GST
        ) {
            verificationScopeFieldApis.add(
                'GST__c'
            );
            verificationScopeFieldApis.add(
                'Name'
            );
        }

        /*
         * Keep every actually approved KYC field in scope as a defensive
         * fallback if the KYC field set is expanded in the future.
         */
        verificationScopeFieldApis.addAll(
            approvedFieldApis
        );

        if (!verificationScopeFieldApis.isEmpty()) {
            for (
                Orient_Customer_Field_Mapping__mdt mapping : [
                    SELECT Account_Field_API__c,
                           Change_Mode__c,
                           Verification_Field_API__c,
                           Active__c
                    FROM Orient_Customer_Field_Mapping__mdt
                    WHERE Active__c = true
                    AND Account_Field_API__c IN
                        :verificationScopeFieldApis
                ]
            ) {
                if (
                    String.isBlank(
                        mapping.Verification_Field_API__c
                    ) ||
                    !accountFieldMap.containsKey(
                        mapping.Verification_Field_API__c
                    )
                ) {
                    continue;
                }

                Schema.DescribeFieldResult
                    verificationDescribe =
                        accountFieldMap.get(
                            mapping.Verification_Field_API__c
                        ).getDescribe();

                if (
                    verificationDescribe.getType() ==
                        Schema.DisplayType.Boolean
                ) {
                    accountUpdate.put(
                        mapping.Verification_Field_API__c,
                        true
                    );
                }
            }
        }

        /*
         * Preserve the existing secondary/system verification indicators.
         * These now complete for the KYC method even when the primary
         * identifier already matched and therefore was not an approval item.
         */
        if (kycMethod == KYC_METHOD_GST) {
            putSystemBooleanIfFieldExists(
                accountUpdate,
                accountFieldMap,
                'GST_Verified__c'
            );
        }

        if (kycMethod == KYC_METHOD_VOTER) {
            putSystemBooleanIfFieldExists(
                accountUpdate,
                accountFieldMap,
                'Voter_ID_Verified__c'
            );

            putSystemBooleanIfFieldExists(
                accountUpdate,
                accountFieldMap,
                'Voter_Verification_Done__c'
            );
        }

        if (
            String.isBlank(
                currentAccount.Customer_Verification_KYC__c
            ) &&
            accountFieldMap.containsKey(
                'Customer_Verification_KYC__c'
            )
        ) {
            accountUpdate.put(
                'Customer_Verification_KYC__c',
                kycMethod
            );
        }
    }

    @TestVisible
    private static void putSystemBooleanIfFieldExists(
        Account accountUpdate,
        Map<String, Schema.SObjectField> accountFieldMap,
        String fieldApi
    ) {
        if (
            accountUpdate == null ||
            accountFieldMap == null ||
            String.isBlank(fieldApi) ||
            !accountFieldMap.containsKey(fieldApi)
        ) {
            return;
        }

        Schema.DescribeFieldResult fieldDescribe =
            accountFieldMap.get(fieldApi).getDescribe();

        if (
            fieldDescribe.getType() ==
                Schema.DisplayType.Boolean
        ) {
            accountUpdate.put(
                fieldApi,
                true
            );
        }
    }

    @TestVisible
    private static String extractKycMethodFromReason(
        String changeReason
    ) {
        if (String.isBlank(changeReason)) {
            return null;
        }

        String normalizedReason =
            changeReason.trim().toUpperCase();

        if (normalizedReason.startsWith('[KYC:PAN]')) {
            return KYC_METHOD_PAN;
        }

        if (normalizedReason.startsWith('[KYC:VOTER]')) {
            return KYC_METHOD_VOTER;
        }

        if (normalizedReason.startsWith('[KYC:GST]')) {
            return KYC_METHOD_GST;
        }

        return null;
    }

    @TestVisible
    private static void validateDuplicateMobileValues(
        Account mergedAccount,
        Id currentAccountId,
        List<Orient_Customer_Change_Item__c> changeItems
    ) {
        Boolean phoneChanged = false;
        Boolean whatsappChanged = false;
        for (Orient_Customer_Change_Item__c item : changeItems) {
            phoneChanged = phoneChanged || item.Account_Field_API__c == 'Phone';
            whatsappChanged = whatsappChanged || item.Account_Field_API__c == 'Whatsapp_number__c';
        }

        Set<String> valuesToCheck = new Set<String>();
        if (phoneChanged && mergedAccount.Phone != null) {
            valuesToCheck.add(normalizePhone(mergedAccount.Phone));
        }
        if (whatsappChanged && mergedAccount.Whatsapp_number__c != null) {
            valuesToCheck.add(normalizePhone(mergedAccount.Whatsapp_number__c));
        }
        valuesToCheck.remove(null);
        valuesToCheck.remove('');

        if (valuesToCheck.isEmpty()) {
            return;
        }

        List<Account> duplicates = [
            SELECT Id, Name, Phone, Whatsapp_number__c
            FROM Account
            WHERE Id != :currentAccountId
            AND (Phone IN :valuesToCheck OR Whatsapp_number__c IN :valuesToCheck)
            WITH USER_MODE
            LIMIT 1
        ];

        if (!duplicates.isEmpty()) {
            throw new AuraHandledException(
                'Final approval cannot be completed because another customer already exists with the requested mobile number: "' +
                duplicates[0].Name + '".'
            );
        }
    }

    @TestVisible
    private static BCPushResult pushApprovedChangesToBC(
        Account originalAccount,
        Account mergedAccount,
        Orient_Customer_Change_Request__c requestRecord,
        List<Orient_Customer_Change_Item__c> changeItems,
        Map<String, Schema.SObjectField> accountFieldMap
    ) {
        BCPushResult result =
            new BCPushResult();

        String existingCustomerNo =
            objectToString(
                originalAccount.get(
                    'BC_Customer_No__c'
                )
            );

        Boolean isUpdate =
            String.isNotBlank(
                existingCustomerNo
            );

        result.wasCreate =
            !isUpdate;

        result.customerNo =
            existingCustomerNo;

        Map<String, Object> payload =
            isUpdate
                ? buildUpdatePayload(
                    changeItems,
                    accountFieldMap
                )
                : buildCreatePayload(
                    mergedAccount
                );

        if (
            String.isNotBlank(
                requestRecord.Location_Code__c
            )
        ) {
            payload.put(
                'locationCode',
                requestRecord.Location_Code__c.trim()
            );
        }

        if (isUpdate) {
            payload.put(
                'customerNo',
                existingCustomerNo
            );
        }

        if (
            payload.containsKey(
                'aadharNo'
            )
        ) {
            Object aadhaarValue =
                payload.get(
                    'aadharNo'
                );

            payload.put(
                'kycDocumentNo',
                aadhaarValue == null
                    ? null
                    : String.valueOf(
                        aadhaarValue
                    )
            );
        }

        if (
            payload.containsKey(
                'gstRegistrationNo'
            ) &&
            payload.get(
                'gstRegistrationNo'
            ) != null
        ) {
            payload.put(
                'customerPostingGroup',
                'RETAIL_CUST (B2C)'
            );

            payload.put(
                'gstRegistrationType',
                'GSTIN'
            );

            payload.put(
                'generalBusinessPostingGroup',
                'DOMESTIC'
            );
        }

        String effectivePhone =
            normalizePhone(
                mergedAccount.Phone
            );

        if (
            String.isBlank(
                effectivePhone
            )
        ) {
            result.success =
                false;
            result.statusCode =
                400;
            result.responseStatus =
                'Validation Failed';
            result.exceptionType =
                'BC Payload Validation';
            result.message =
                'Phone Number is required before the approved Customer changes can be pushed to BC.';
            result.requestDateTime =
                System.now();
            result.responseDateTime =
                result.requestDateTime;
            result.durationMilliseconds =
                0;
            result.requestBody =
                JSON.serialize(
                    payload,
                    true
                );
            return result;
        }

        if (
            !isUpdate &&
            !payload.containsKey(
                'phoneNo'
            )
        ) {
            payload.put(
                'phoneNo',
                effectivePhone
            );
        }

        if (
            !isUpdate &&
            !payload.containsKey(
                'name'
            ) &&
            String.isNotBlank(
                mergedAccount.Name
            )
        ) {
            payload.put(
                'name',
                mergedAccount.Name
            );
        }

        String finalJson =
            JSON.serialize(
                payload,
                true
            );

        result.requestBody =
            finalJson;

        HttpRequest request =
            new HttpRequest();

        String endpoint =
            'callout:Orient_API_Access_NC/' +
            System.Label.BC_Endpoint +
            '/ACXCustomerListAPIJRS';

        if (isUpdate) {
            String originalPhone =
                normalizePhone(
                    originalAccount.Phone
                );

            String phoneParameter =
                String.isNotBlank(
                    originalPhone
                )
                    ? originalPhone
                    : effectivePhone;

            endpoint +=
                '(\'' +
                escapeODataValue(
                    existingCustomerNo
                ) +
                '\',\'' +
                escapeODataValue(
                    phoneParameter
                ) +
                '\')';

            request.setMethod(
                'PATCH'
            );

            request.setHeader(
                'If-Match',
                '*'
            );
        } else {
            request.setMethod(
                'POST'
            );
        }

        request.setEndpoint(
            endpoint
        );

        request.setHeader(
            'Content-Type',
            'application/json'
        );

        request.setHeader(
            'Accept',
            'application/json'
        );

        request.setTimeout(
            20000
        );

        request.setBody(
            finalJson
        );

        result.endpoint =
            endpoint;

        result.httpMethod =
            request.getMethod();

        Map<String, Object> safeHeaders =
            new Map<String, Object>{
                'Content-Type' =>
                    'application/json',
                'Accept' =>
                    'application/json'
            };

        if (isUpdate) {
            safeHeaders.put(
                'If-Match',
                '*'
            );
        }

        result.requestHeaders =
            JSON.serialize(
                safeHeaders
            );

        result.requestDateTime =
            System.now();

        Long startTime =
            result.requestDateTime.getTime();

        try {
            HttpResponse response =
                new Http().send(
                    request
                );

            result.responseDateTime =
                System.now();

            result.durationMilliseconds =
                result.responseDateTime.getTime() -
                startTime;

            result.statusCode =
                response.getStatusCode();

            result.responseStatus =
                response.getStatus();

            result.responseBody =
                response.getBody();

            result.correlationId =
                extractCorrelationId(
                    result.responseBody
                );

            result.success =
                result.statusCode >= 200 &&
                result.statusCode < 300;

            if (!result.success) {
                result.exceptionType =
                    'BC HTTP Error';

                result.lineNumber =
                    0;

                result.message =
                    'API Error: ' +
                    response.getStatus() +
                    ' - ' +
                    response.getBody();

                return result;
            }

            if (!isUpdate) {
                result.customerNo =
                    extractCustomerNo(
                        result.responseBody
                    );

                if (
                    String.isBlank(
                        result.customerNo
                    )
                ) {
                    result.success =
                        false;

                    result.statusCode =
                        502;

                    result.responseStatus =
                        'Invalid BC Success Response';

                    result.exceptionType =
                        'BC Response Validation';

                    result.lineNumber =
                        0;

                    result.message =
                        'BC returned a successful response but Customer No was not available in the response.';

                    return result;
                }
            }

            result.message =
                isUpdate
                    ? 'Customer updated in BC successfully.'
                    : 'Customer created in BC successfully.';

            return result;
        } catch (Exception e) {
            result.responseDateTime =
                System.now();

            result.durationMilliseconds =
                result.responseDateTime.getTime() -
                startTime;

            result.success =
                false;

            result.statusCode =
                500;

            result.responseStatus =
                'Callout Exception';

            result.exceptionType =
                e.getTypeName();

            result.lineNumber =
                e.getLineNumber();

            result.stackTrace =
                e.getStackTraceString();

            result.message =
                'BC callout failed: ' +
                e.getMessage();

            result.responseBody =
                e.getMessage();

            return result;
        }
    }

    /*
     * Stores one Integration_Result__c for every failed BC attempt and
     * returns its Id so the Customer Change Request can point to the
     * latest failed integration attempt through BC_Integration_Log__c.
     *
     * Logging failure must never replace the real BC error shown to the
     * approver, therefore any log-DML exception is handled defensively.
     */
    @TestVisible
    private static Id createBCFailureIntegrationLog(
        Orient_Customer_Change_Request__c requestRecord,
        BCPushResult bcResult,
        Decimal attemptNumber
    ) {
        if (
            requestRecord == null ||
            requestRecord.Id == null ||
            bcResult == null
        ) {
            return null;
        }

        try {
            Integration_Result__c logRecord =
                new Integration_Result__c();

            logRecord.Apex_Class_Name__c =
                truncateForField(
                    'Ctrl_Hlp_OrientCustFinalApproval',
                    255
                );

            logRecord.Method_Name__c =
                truncateForField(
                    'pushApprovedChangesToBC',
                    255
                );

            logRecord.API_Type__c =
                truncateForField(
                    'BC Customer Profile Final Approval',
                    255
                );

            logRecord.Attempt_Number__c =
                attemptNumber;

            logRecord.Is_Retry__c =
                attemptNumber != null &&
                attemptNumber > 1;

            logRecord.Endpoint__c =
                truncateForField(
                    bcResult.endpoint,
                    255
                );

            logRecord.Error_Message__c =
                truncateForField(
                    bcResult.message,
                    32768
                );

            logRecord.Exception_Type__c =
                truncateForField(
                    bcResult.exceptionType,
                    255
                );

            logRecord.Line_Number__c =
                bcResult.lineNumber;

            logRecord.Related_Object_API__c =
                'Orient_Customer_Change_Request__c';

            logRecord.Related_Record_Id__c =
                String.valueOf(
                    requestRecord.Id
                );

            logRecord.Request_Date_Time__c =
                bcResult.requestDateTime;

            logRecord.Response_Date_Time__c =
                bcResult.responseDateTime;

            logRecord.Duration_Milliseconds__c =
                bcResult.durationMilliseconds;

            logRecord.Request_Headers__c =
                truncateForField(
                    bcResult.requestHeaders,
                    131072
                );

            logRecord.Request_JSON__c =
                truncateForField(
                    bcResult.requestBody,
                    131072
                );

            logRecord.Response_Body__c =
                truncateForField(
                    bcResult.responseBody,
                    131072
                );

            logRecord.Response_Status__c =
                truncateForField(
                    bcResult.responseStatus,
                    255
                );

            logRecord.Stack_Trace__c =
                truncateForField(
                    bcResult.stackTrace,
                    131072
                );

            logRecord.Status_Code__c =
                bcResult.statusCode;

            logRecord.Success__c =
                false;

            logRecord.Correlation_Id__c =
                truncateForField(
                    String.isNotBlank(
                        bcResult.correlationId
                    )
                        ? bcResult.correlationId
                        : extractCorrelationId(
                            bcResult.message
                        ),
                    255
                );

            /*
             * These are picklists. Set them only when the value is active
             * in the org so a logging record can never fail because of a
             * restricted picklist configuration.
             */
            putActivePicklistValue(
                logRecord,
                'HTTP_Method__c',
                new List<String>{
                    bcResult.httpMethod
                }
            );

            putActivePicklistValue(
                logRecord,
                'Log_Status__c',
                new List<String>{
                    'Failed',
                    'Error',
                    'Failure'
                }
            );

            insert logRecord;

            return logRecord.Id;
        } catch (Exception loggingException) {
            System.debug(
                LoggingLevel.ERROR,
                'Unable to create Integration_Result__c for BC failure. ' +
                loggingException.getMessage() +
                '\n' +
                loggingException.getStackTraceString()
            );

            return null;
        }
    }

    @TestVisible
    private static void putActivePicklistValue(
        SObject recordValue,
        String fieldApi,
        List<String> preferredValues
    ) {
        if (
            recordValue == null ||
            String.isBlank(
                fieldApi
            ) ||
            preferredValues == null ||
            preferredValues.isEmpty()
        ) {
            return;
        }

        Map<String, Schema.SObjectField> fieldMap =
            recordValue
                .getSObjectType()
                .getDescribe()
                .fields
                .getMap();

        if (
            !fieldMap.containsKey(
                fieldApi
            )
        ) {
            return;
        }

        Schema.DescribeFieldResult fieldDescribe =
            fieldMap.get(
                fieldApi
            ).getDescribe();

        if (
            fieldDescribe.getType() !=
            Schema.DisplayType.Picklist
        ) {
            return;
        }

        for (
            String preferredValue :
            preferredValues
        ) {
            if (
                String.isBlank(
                    preferredValue
                )
            ) {
                continue;
            }

            for (
                Schema.PicklistEntry entry :
                fieldDescribe.getPicklistValues()
            ) {
                if (
                    entry.isActive() &&
                    entry.getValue() ==
                        preferredValue
                ) {
                    recordValue.put(
                        fieldApi,
                        preferredValue
                    );
                    return;
                }
            }
        }
    }

    @TestVisible
    private static String extractCorrelationId(
        String sourceText
    ) {
        if (
            String.isBlank(
                sourceText
            )
        ) {
            return null;
        }

        try {
            Pattern correlationPattern =
                Pattern.compile(
                    'CorrelationId\\s*:\\s*([A-Za-z0-9\\-]+)'
                );

            Matcher correlationMatcher =
                correlationPattern.matcher(
                    sourceText
                );

            if (
                correlationMatcher.find()
            ) {
                return correlationMatcher.group(
                    1
                );
            }
        } catch (Exception ignoreCorrelationParse) {
            // Correlation Id is optional diagnostic information.
        }

        return null;
    }

    @TestVisible
    private static String truncateForField(
        String value,
        Integer maxLength
    ) {
        if (
            String.isBlank(
                value
            ) ||
            maxLength == null ||
            maxLength <= 0
        ) {
            return value;
        }

        return value.length() > maxLength
            ? value.substring(
                0,
                maxLength
            )
            : value;
    }

    @TestVisible
    private static Map<String, Object> buildUpdatePayload(
        List<Orient_Customer_Change_Item__c> changeItems,
        Map<String, Schema.SObjectField> accountFieldMap
    ) {
        Map<String, Object> payload = new Map<String, Object>();
        for (Orient_Customer_Change_Item__c item : changeItems) {
            if (item.BC_Push_Applicable__c != true) {
                continue;
            }

            Schema.DescribeFieldResult fieldDescribe =
                accountFieldMap.get(item.Account_Field_API__c).getDescribe();
            Object accountValue = deserializeAccountValue(item.New_Value__c, fieldDescribe);
            payload.put(
                item.BC_Payload_Key__c,
                toBCPayloadValue(item.BC_Payload_Key__c, accountValue)
            );
        }
        return payload;
    }

    @TestVisible
    private static Map<String, Object> buildCreatePayload(Account acc) {
        Map<String, Object> payload = new Map<String, Object>();
        putIfNotBlank(payload, 'name', acc.Name);
        putIfNotBlank(payload, 'phoneNo', acc.Phone);
        putIfNotBlank(payload, 'mobilePhoneNo', acc.Whatsapp_number__c);
        putIfNotBlank(payload, 'address', acc.Permanent_Address__c);
        putIfNotBlank(payload, 'address2', acc.Locality_Area__c);
        if (acc.Anniversary_Date__c != null) {
            payload.put(
                'anniversaryDate',
                formatDateForBC(
                    acc.Anniversary_Date__c
                )
            );
        }

        if (acc.Date_Of_Birth__c != null) {
            payload.put(
                'birthDate',
                formatDateForBC(
                    acc.Date_Of_Birth__c
                )
            );
        }
        putIfNotBlank(payload, 'city', acc.Residential_City__c);
        putIfNotBlank(payload, 'countryRegionCode', acc.Country_Region_Code__c);
        putIfNotBlank(payload, 'county', acc.Country__c);
        putIfNotBlank(payload, 'district', acc.District__c);
        putIfNotBlank(payload, 'eMail', acc.Email_Address__c);
        putIfNotBlank(payload, 'gstRegistrationNo', acc.GST__c);
        if (acc.KYC_Verified__c != null) payload.put('isKYC', acc.KYC_Verified__c);
        putIfNotBlank(payload, 'pANNo', acc.PAN__c);
        putIfNotBlank(payload, 'postCode', acc.Pin_Code__c);
        putIfNotBlank(payload, 'stateCode', acc.StateCode__c);
        putIfNotBlank(payload, 'village', acc.Village__c);
        putIfNotBlank(payload, 'landmark', acc.Landmark__c);

        if (String.isNotBlank(acc.AadharNo__c)) {
            try {
                payload.put('aadharNo', Long.valueOf(acc.AadharNo__c));
                payload.put('kycDocumentNo', acc.AadharNo__c);
            } catch (Exception e) {
                throw new AuraHandledException('Aadhaar Number must contain only numeric digits before BC push.');
            }
        }

        if (String.isNotBlank(acc.GST__c)) {
            payload.put('customerPostingGroup', 'RETAIL_CUST (B2C)');
            payload.put('gstRegistrationType', 'GSTIN');
            payload.put('generalBusinessPostingGroup', 'DOMESTIC');
        }
        return payload;
    }

    @TestVisible
    private static Object toBCPayloadValue(
        String payloadKey,
        Object value
    ) {
        if (value == null) {
            return null;
        }

        if (payloadKey == 'aadharNo') {
            try {
                return Long.valueOf(
                    String.valueOf(value)
                );
            } catch (Exception e) {
                throw new AuraHandledException(
                    'Aadhaar Number must contain only numeric digits before BC push.'
                );
            }
        }

        if (payloadKey == 'isKYC') {
            return value instanceof Boolean
                ? value
                : Boolean.valueOf(
                    String.valueOf(value)
                );
        }

        /*
         * Business Central OData Edm.Date accepts yyyy-MM-dd only.
         * Do not send Salesforce Date values with a 00:00:00 time portion.
         */
        if (value instanceof Date) {
            return formatDateForBC(
                (Date) value
            );
        }

        /*
         * Datetime remains separate because a BC DateTime field may
         * legitimately require a date-time value.
         */
        if (value instanceof Datetime) {
            return String.valueOf(value);
        }

        return value;
    }

    @TestVisible
    private static String formatDateForBC(
        Date dateValue
    ) {
        if (dateValue == null) {
            return null;
        }

        String monthValue =
            dateValue.month() < 10
                ? '0' + String.valueOf(dateValue.month())
                : String.valueOf(dateValue.month());

        String dayValue =
            dateValue.day() < 10
                ? '0' + String.valueOf(dateValue.day())
                : String.valueOf(dateValue.day());

        return
            String.valueOf(dateValue.year()) +
            '-' +
            monthValue +
            '-' +
            dayValue;
    }

    @TestVisible
    private static Boolean hasBCApplicableChanges(List<Orient_Customer_Change_Item__c> changeItems) {
        for (Orient_Customer_Change_Item__c item : changeItems) {
            if (item.BC_Push_Applicable__c == true) {
                return true;
            }
        }
        return false;
    }

    @TestVisible
    private static void validateFinalPicklistConfiguration(Boolean bcPushRequired) {
        validateFinalFieldPicklistConfiguration(bcPushRequired, false);
    }

    @TestVisible
    private static void validateFinalFieldPicklistConfiguration(
        Boolean bcPushRequired,
        Boolean hasRejectedFields
    ) {
        validatePicklistValue(
            Schema.SObjectType.Tagged_Approval_Hierarchy__c.fields.Approval_Status__c,
            STATUS_FINAL_APPROVED,
            'Tagged Approval Hierarchy Approval Status'
        );
        validatePicklistValue(
            Schema.SObjectType.Tagged_Approval_Hierarchy__c.fields.Last_Action__c,
            ACTION_FINAL_APPROVED,
            'Tagged Approval Hierarchy Last Action'
        );
        validatePicklistValue(
            Schema.SObjectType.Orient_Customer_Change_Request__c.fields.Approval_Status__c,
            STATUS_FINAL_APPROVED,
            'Customer Change Request Approval Status'
        );
        validatePicklistValue(
            Schema.SObjectType.Orient_Customer_Change_Request__c.fields.Last_Action__c,
            ACTION_FINAL_APPROVED,
            'Customer Change Request Last Action'
        );
        validatePicklistValue(
            Schema.SObjectType.Approval_Action_History__c.fields.Action__c,
            ACTION_FINAL_APPROVED,
            'Approval Action History Action'
        );
        validatePicklistValue(
            Schema.SObjectType.Approval_Action_History__c.fields.New_Status__c,
            STATUS_FINAL_APPROVED,
            'Approval Action History New Status'
        );

        validatePicklistValue(
            Schema.SObjectType.Orient_Customer_Change_Item__c.fields.Item_Approval_Status__c,
            ITEM_STATUS_FINAL_APPROVED,
            'Customer Change Item Approval Status'
        );

        validatePicklistValue(
            Schema.SObjectType.Approval_Action_History__c.fields.New_Status__c,
            ITEM_STATUS_FINAL_APPROVED,
            'Approval Action History New Status'
        );

        if (hasRejectedFields) {
            validatePicklistValue(
                Schema.SObjectType.Orient_Customer_Change_Item__c.fields.Item_Approval_Status__c,
                ITEM_STATUS_RETURNED,
                'Customer Change Item Approval Status'
            );

            validatePicklistValue(
                Schema.SObjectType.Tagged_Approval_Hierarchy__c.fields.Approval_Status__c,
                STATUS_RETURNED,
                'Tagged Approval Hierarchy Approval Status'
            );

            validatePicklistValue(
                Schema.SObjectType.Orient_Customer_Change_Request__c.fields.Approval_Status__c,
                STATUS_RETURNED,
                'Customer Change Request Approval Status'
            );

            validatePicklistValue(
                Schema.SObjectType.Tagged_Approval_Hierarchy__c.fields.Last_Action__c,
                ACTION_REJECTED,
                'Tagged Approval Hierarchy Last Action'
            );

            validatePicklistValue(
                Schema.SObjectType.Orient_Customer_Change_Request__c.fields.Last_Action__c,
                ACTION_REJECTED,
                'Customer Change Request Last Action'
            );

            validatePicklistValue(
                Schema.SObjectType.Approval_Action_History__c.fields.Action__c,
                ACTION_REJECTED,
                'Approval Action History Action'
            );

            validatePicklistValue(
                Schema.SObjectType.Approval_Action_History__c.fields.New_Status__c,
                ITEM_STATUS_RETURNED,
                'Approval Action History New Status'
            );
        }

        if (bcPushRequired) {
            validatePicklistValue(
                Schema.SObjectType.Orient_Customer_Change_Request__c.fields.BC_Push_Status__c,
                BC_STATUS_SUCCESS,
                'Customer Change Request BC Push Status'
            );
            validatePicklistValue(
                Schema.SObjectType.Orient_Customer_Change_Request__c.fields.BC_Push_Status__c,
                BC_STATUS_FAILED,
                'Customer Change Request BC Push Status'
            );
        } else {
            validatePicklistValue(
                Schema.SObjectType.Orient_Customer_Change_Request__c.fields.BC_Push_Status__c,
                BC_STATUS_NOT_REQUIRED,
                'Customer Change Request BC Push Status'
            );
        }
    }

    @TestVisible
    private static void validatePicklistValue(
        Schema.DescribeFieldResult describeResult,
        String expectedValue,
        String fieldLabel
    ) {
        if (describeResult == null || describeResult.getType() != Schema.DisplayType.Picklist) {
            return;
        }

        for (Schema.PicklistEntry entry : describeResult.getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == expectedValue) {
                return;
            }
        }

        throw new AuraHandledException(
            'Configuration error: picklist value "' + expectedValue +
            '" is not active for ' + fieldLabel + '.'
        );
    }

	@TestVisible
    private static String objectToString(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    @TestVisible
    private static void putIfNotBlank(Map<String, Object> payload, String key, String value) {
        if (String.isNotBlank(value)) {
            payload.put(key, value);
        }
    }

    @TestVisible
    private static String normalizePhone(String value) {
        return String.isBlank(value) ? null : value.replaceAll('[^0-9]', '');
    }

    @TestVisible
    private static String escapeODataValue(String value) {
        return String.isBlank(value) ? '' : value.replace('\'', '\'\'');
    }

    @TestVisible
    private static String truncateMessage(String message) {
        if (String.isBlank(message)) {
            return message;
        }
        return message.length() > 32000 ? message.substring(0, 32000) : message;
    }

    @TestVisible
    private static String extractCustomerNo(String responseBody) {
        if (String.isBlank(responseBody)) {
            return null;
        }

        try {
            Object parsedResponse = JSON.deserializeUntyped(responseBody);
            if (parsedResponse instanceof Map<String, Object>) {
                Map<String, Object> responseMap = (Map<String, Object>) parsedResponse;

                if (responseMap.containsKey('customerNo') && responseMap.get('customerNo') != null) {
                    return String.valueOf(responseMap.get('customerNo'));
                }

                if (
                    responseMap.containsKey('value') &&
                    responseMap.get('value') instanceof List<Object>
                ) {
                    List<Object> values = (List<Object>) responseMap.get('value');
                    if (!values.isEmpty() && values[0] instanceof Map<String, Object>) {
                        Map<String, Object> firstValue = (Map<String, Object>) values[0];
                        if (firstValue.containsKey('customerNo') && firstValue.get('customerNo') != null) {
                            return String.valueOf(firstValue.get('customerNo'));
                        }
                    }
                }

                if (
                    responseMap.containsKey('d') &&
                    responseMap.get('d') instanceof Map<String, Object>
                ) {
                    Map<String, Object> nestedResponse =
                        (Map<String, Object>) responseMap.get('d');
                    if (
                        nestedResponse.containsKey('customerNo') &&
                        nestedResponse.get('customerNo') != null
                    ) {
                        return String.valueOf(nestedResponse.get('customerNo'));
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error extracting customerNo: ' + e.getMessage());
        }
        return null;
    }
}