public without sharing class Ctrl_Hlp_BTLApprovalSharing {

    private static final String ACCESS_READ = 'Read';
    private static final String ACCESS_EDIT = 'Edit';

    /*
     * Optional Apex Sharing Reason.
     * If this RowCause exists on a shareable BTL custom object, the helper
     * uses it. Otherwise it safely falls back to Manual sharing.
     */
    private static final String PREFERRED_ROW_CAUSE =
        'BTL_Approval_Access__c';

    private static final Integer USER_RECORD_ACCESS_CHUNK = 200;

    private class TransactionAccessContext {
        Id transactionId;
        Id submittedById;
        Id pendingWithId;
        String approvalStatus;
        Id activityId;
        Id assignedPersonId;
        Id assignedPersonDateId;
        Id finalCustomizeFormId;
        Id dailyExecutionId;
        Id storeId;
        Id salesExecutiveId;
    }

    private class AccessRequirement {
        Id userId;
        Id recordId;
        String accessLevel;

        AccessRequirement(
            Id userId,
            Id recordId,
            String accessLevel
        ) {
            this.userId = userId;
            this.recordId = recordId;
            this.accessLevel = accessLevel;
        }
    }

    private class AccessSnapshot {
        Boolean canRead = false;
        Boolean canEdit = false;
    }

    private class ShareObjectInfo {
        Boolean shareable = false;
        String shareObjectApiName;
        String rowCause;
        Boolean usesPreferredRowCause = false;
    }

    public static void syncApprovalAccess(
        Set<Id> taggedApprovalIds
    ) {
        if (
            taggedApprovalIds == null ||
            taggedApprovalIds.isEmpty()
        ) {
            return;
        }

        List<Tagged_Approval_Hierarchy__c> transactions = [
            SELECT
                Id,
                Approval_Status__c,
                Pending_With__c,
                Submitted_By__c,
                Form_Activity__c,
                Form_Activity_Assigned_Persons__c,
                Form_Activity_Assigned_Persons__r.Sales_Executives__c,
                Form_Activity_Assigned_Persons_Date__c,
                Form_Activity_Assigned_Persons_Date__r.Store__c,
                Form_Activity_Assigned_Persons_Date__r.Form_Activity_Daily_Execution__c,
                Form_Activity__r.Final_Customize_Form__c
            FROM Tagged_Approval_Hierarchy__c
            WHERE Id IN :taggedApprovalIds
        ];

        if (transactions.isEmpty()) {
            return;
        }

        Map<Id, TransactionAccessContext> contextByTransactionId =
            new Map<Id, TransactionAccessContext>();

        Set<Id> activityIds = new Set<Id>();
        Set<Id> finalCustomizeFormIds = new Set<Id>();

        for (
            Tagged_Approval_Hierarchy__c transactionRecord :
            transactions
        ) {
            TransactionAccessContext contextRecord =
                new TransactionAccessContext();

            contextRecord.transactionId = transactionRecord.Id;
            contextRecord.submittedById = transactionRecord.Submitted_By__c;
            contextRecord.pendingWithId = transactionRecord.Pending_With__c;
            contextRecord.approvalStatus = transactionRecord.Approval_Status__c;
            contextRecord.activityId = transactionRecord.Form_Activity__c;
            contextRecord.assignedPersonId =
                transactionRecord.Form_Activity_Assigned_Persons__c;
            contextRecord.assignedPersonDateId =
                transactionRecord.Form_Activity_Assigned_Persons_Date__c;
            contextRecord.finalCustomizeFormId =
                transactionRecord.Form_Activity__r == null
                    ? null
                    : transactionRecord.Form_Activity__r.Final_Customize_Form__c;
            contextRecord.dailyExecutionId =
                transactionRecord.Form_Activity_Assigned_Persons_Date__r == null
                    ? null
                    : transactionRecord
                        .Form_Activity_Assigned_Persons_Date__r
                        .Form_Activity_Daily_Execution__c;
            contextRecord.storeId =
                transactionRecord.Form_Activity_Assigned_Persons_Date__r == null
                    ? null
                    : transactionRecord
                        .Form_Activity_Assigned_Persons_Date__r
                        .Store__c;
            contextRecord.salesExecutiveId =
                transactionRecord.Form_Activity_Assigned_Persons__r == null
                    ? null
                    : transactionRecord
                        .Form_Activity_Assigned_Persons__r
                        .Sales_Executives__c;

            contextByTransactionId.put(
                transactionRecord.Id,
                contextRecord
            );

            addId(activityIds, contextRecord.activityId);
            addId(
                finalCustomizeFormIds,
                contextRecord.finalCustomizeFormId
            );
        }

        Map<Id, Set<Id>> lineItemIdsByFormId =
            loadFinalFormLineItems(finalCustomizeFormIds);

        Map<Id, Set<Id>> responseIdsByActivityId =
            loadCustomerResponses(activityIds);

        Set<Id> responseIds = new Set<Id>();
        for (Set<Id> ids : responseIdsByActivityId.values()) {
            responseIds.addAll(ids);
        }

        Map<Id, Set<Id>> responseItemIdsByResponseId =
            loadCustomerResponseItems(responseIds);

        Map<Id, List<Approval_Action_History__c>> historiesByTransactionId =
            new Map<Id, List<Approval_Action_History__c>>();

        for (
            Approval_Action_History__c historyRecord : [
                SELECT
                    Id,
                    Approval_Transaction__c,
                    Action_By__c,
                    Assigned_To__c
                FROM Approval_Action_History__c
                WHERE Approval_Transaction__c IN :taggedApprovalIds
            ]
        ) {
            if (
                !historiesByTransactionId.containsKey(
                    historyRecord.Approval_Transaction__c
                )
            ) {
                historiesByTransactionId.put(
                    historyRecord.Approval_Transaction__c,
                    new List<Approval_Action_History__c>()
                );
            }

            historiesByTransactionId
                .get(historyRecord.Approval_Transaction__c)
                .add(historyRecord);
        }

        Map<Id, Map<Id, String>> requiredAccessByUser =
            new Map<Id, Map<Id, String>>();

        Map<Id, Id> fallbackParentByChildId =
            new Map<Id, Id>();

        Set<String> coreEditRequirementKeys =
            new Set<String>();

        for (
            TransactionAccessContext contextRecord :
            contextByTransactionId.values()
        ) {
            Set<Id> relatedReadIds =
                buildRelatedReadIds(
                    contextRecord,
                    lineItemIdsByFormId,
                    responseIdsByActivityId,
                    responseItemIdsByResponseId,
                    historiesByTransactionId
                );

            addFallback(
                fallbackParentByChildId,
                contextRecord.assignedPersonDateId,
                contextRecord.assignedPersonId
            );
            addFallback(
                fallbackParentByChildId,
                contextRecord.assignedPersonId,
                contextRecord.activityId
            );

            if (contextRecord.finalCustomizeFormId != null) {
                Set<Id> lineItemIds =
                    lineItemIdsByFormId.get(
                        contextRecord.finalCustomizeFormId
                    );

                if (lineItemIds != null) {
                    for (Id lineItemId : lineItemIds) {
                        addFallback(
                            fallbackParentByChildId,
                            lineItemId,
                            contextRecord.finalCustomizeFormId
                        );
                    }
                }
            }

            Set<Id> responseIdsForActivity =
                responseIdsByActivityId.get(contextRecord.activityId);

            if (responseIdsForActivity != null) {
                for (Id responseId : responseIdsForActivity) {
                    addFallback(
                        fallbackParentByChildId,
                        responseId,
                        contextRecord.activityId
                    );

                    Set<Id> responseItemIds =
                        responseItemIdsByResponseId.get(responseId);

                    if (responseItemIds != null) {
                        for (Id responseItemId : responseItemIds) {
                            addFallback(
                                fallbackParentByChildId,
                                responseItemId,
                                responseId
                            );
                        }
                    }
                }
            }

            List<Approval_Action_History__c> histories =
                historiesByTransactionId.get(
                    contextRecord.transactionId
                );

            if (histories != null) {
                for (Approval_Action_History__c historyRecord : histories) {
                    addFallback(
                        fallbackParentByChildId,
                        historyRecord.Id,
                        contextRecord.transactionId
                    );
                }
            }

            addReadRequirements(
                requiredAccessByUser,
                contextRecord.submittedById,
                relatedReadIds
            );

            if (histories != null) {
                for (Approval_Action_History__c historyRecord : histories) {
                    addReadRequirements(
                        requiredAccessByUser,
                        historyRecord.Action_By__c,
                        relatedReadIds
                    );
                    addReadRequirements(
                        requiredAccessByUser,
                        historyRecord.Assigned_To__c,
                        relatedReadIds
                    );
                }
            }

            if (contextRecord.pendingWithId != null) {
                addReadRequirements(
                    requiredAccessByUser,
                    contextRecord.pendingWithId,
                    relatedReadIds
                );

                addRequirement(
                    requiredAccessByUser,
                    contextRecord.pendingWithId,
                    contextRecord.transactionId,
                    ACCESS_EDIT
                );
                addRequirement(
                    requiredAccessByUser,
                    contextRecord.pendingWithId,
                    contextRecord.assignedPersonDateId,
                    ACCESS_EDIT
                );

                coreEditRequirementKeys.add(
                    buildKey(
                        contextRecord.pendingWithId,
                        contextRecord.transactionId
                    )
                );
                coreEditRequirementKeys.add(
                    buildKey(
                        contextRecord.pendingWithId,
                        contextRecord.assignedPersonDateId
                    )
                );
            }
        }

        reconcilePreferredShares(requiredAccessByUser);

        applyMissingAccess(
            requiredAccessByUser,
            fallbackParentByChildId
        );

        verifyCoreEditAccess(
            requiredAccessByUser,
            coreEditRequirementKeys
        );
    }

    private static Set<Id> buildRelatedReadIds(
        TransactionAccessContext contextRecord,
        Map<Id, Set<Id>> lineItemIdsByFormId,
        Map<Id, Set<Id>> responseIdsByActivityId,
        Map<Id, Set<Id>> responseItemIdsByResponseId,
        Map<Id, List<Approval_Action_History__c>> historiesByTransactionId
    ) {
        Set<Id> relatedIds = new Set<Id>();

        addId(relatedIds, contextRecord.transactionId);
        addId(relatedIds, contextRecord.activityId);
        addId(relatedIds, contextRecord.assignedPersonId);
        addId(relatedIds, contextRecord.assignedPersonDateId);
        addId(relatedIds, contextRecord.finalCustomizeFormId);
        addId(relatedIds, contextRecord.dailyExecutionId);
        addId(relatedIds, contextRecord.storeId);
        addId(relatedIds, contextRecord.salesExecutiveId);

        if (contextRecord.finalCustomizeFormId != null) {
            Set<Id> lineItemIds =
                lineItemIdsByFormId.get(
                    contextRecord.finalCustomizeFormId
                );
            if (lineItemIds != null) {
                relatedIds.addAll(lineItemIds);
            }
        }

        Set<Id> responseIds =
            responseIdsByActivityId.get(contextRecord.activityId);

        if (responseIds != null) {
            relatedIds.addAll(responseIds);

            for (Id responseId : responseIds) {
                Set<Id> responseItemIds =
                    responseItemIdsByResponseId.get(responseId);
                if (responseItemIds != null) {
                    relatedIds.addAll(responseItemIds);
                }
            }
        }

        List<Approval_Action_History__c> histories =
            historiesByTransactionId.get(
                contextRecord.transactionId
            );

        if (histories != null) {
            for (Approval_Action_History__c historyRecord : histories) {
                addId(relatedIds, historyRecord.Id);
            }
        }

        return relatedIds;
    }

    private static Map<Id, Set<Id>> loadFinalFormLineItems(
        Set<Id> finalCustomizeFormIds
    ) {
        Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();

        if (
            finalCustomizeFormIds == null ||
            finalCustomizeFormIds.isEmpty() ||
            !objectAndFieldExist(
                'Final_Customize_Form_Line_Item__c',
                'Final_Customize_Form__c'
            )
        ) {
            return result;
        }

        Map<String, Object> binds = new Map<String, Object>{
            'parentIds' => finalCustomizeFormIds
        };

        for (
            SObject row : Database.queryWithBinds(
                'SELECT Id, Final_Customize_Form__c ' +
                'FROM Final_Customize_Form_Line_Item__c ' +
                'WHERE Final_Customize_Form__c IN :parentIds',
                binds,
                AccessLevel.SYSTEM_MODE
            )
        ) {
            addChild(
                result,
                (Id) row.get('Final_Customize_Form__c'),
                row.Id
            );
        }

        return result;
    }

    private static Map<Id, Set<Id>> loadCustomerResponses(
        Set<Id> activityIds
    ) {
        Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();

        if (
            activityIds == null ||
            activityIds.isEmpty() ||
            !objectAndFieldExist(
                'BTL_Customer_Response__c',
                'Form_Activity__c'
            )
        ) {
            return result;
        }

        Map<String, Object> binds = new Map<String, Object>{
            'parentIds' => activityIds
        };

        for (
            SObject row : Database.queryWithBinds(
                'SELECT Id, Form_Activity__c ' +
                'FROM BTL_Customer_Response__c ' +
                'WHERE Form_Activity__c IN :parentIds',
                binds,
                AccessLevel.SYSTEM_MODE
            )
        ) {
            addChild(
                result,
                (Id) row.get('Form_Activity__c'),
                row.Id
            );
        }

        return result;
    }

    private static Map<Id, Set<Id>> loadCustomerResponseItems(
        Set<Id> responseIds
    ) {
        Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();

        if (
            responseIds == null ||
            responseIds.isEmpty() ||
            !objectAndFieldExist(
                'BTL_Customer_Response_Items__c',
                'BTL_Customer_Response__c'
            )
        ) {
            return result;
        }

        Map<String, Object> binds = new Map<String, Object>{
            'parentIds' => responseIds
        };

        for (
            SObject row : Database.queryWithBinds(
                'SELECT Id, BTL_Customer_Response__c ' +
                'FROM BTL_Customer_Response_Items__c ' +
                'WHERE BTL_Customer_Response__c IN :parentIds',
                binds,
                AccessLevel.SYSTEM_MODE
            )
        ) {
            addChild(
                result,
                (Id) row.get('BTL_Customer_Response__c'),
                row.Id
            );
        }

        return result;
    }

    private static void applyMissingAccess(
        Map<Id, Map<Id, String>> requiredAccessByUser,
        Map<Id, Id> fallbackParentByChildId
    ) {
        if (requiredAccessByUser.isEmpty()) {
            return;
        }

        Map<Id, Map<Id, AccessSnapshot>> currentAccess =
            loadCurrentAccess(requiredAccessByUser);

        Map<Id, Map<Id, String>> directShareRequirements =
            new Map<Id, Map<Id, String>>();

        Map<Id, Map<Id, String>> fallbackRequirements =
            new Map<Id, Map<Id, String>>();

        for (Id userId : requiredAccessByUser.keySet()) {
            Map<Id, String> userRequirements =
                requiredAccessByUser.get(userId);

            Map<Id, AccessSnapshot> accessByRecord =
                currentAccess.containsKey(userId)
                    ? currentAccess.get(userId)
                    : new Map<Id, AccessSnapshot>();

            for (Id recordId : userRequirements.keySet()) {
                String requiredLevel = userRequirements.get(recordId);
                AccessSnapshot snapshot = accessByRecord.get(recordId);

                if (hasRequiredAccess(snapshot, requiredLevel)) {
                    continue;
                }

                ShareObjectInfo shareInfo =
                    getShareObjectInfo(recordId);

                if (shareInfo.shareable) {
                    addRequirement(
                        directShareRequirements,
                        userId,
                        recordId,
                        requiredLevel
                    );
                    continue;
                }

                Id fallbackParentId =
                    fallbackParentByChildId.get(recordId);

                if (fallbackParentId != null) {
                    addRequirement(
                        fallbackRequirements,
                        userId,
                        fallbackParentId,
                        requiredLevel
                    );
                }
            }
        }

        createOrUpgradeShares(directShareRequirements);

        if (!fallbackRequirements.isEmpty()) {
            Map<Id, Map<Id, AccessSnapshot>> fallbackAccess =
                loadCurrentAccess(fallbackRequirements);

            Map<Id, Map<Id, String>> missingFallbackShares =
                new Map<Id, Map<Id, String>>();

            for (Id userId : fallbackRequirements.keySet()) {
                Map<Id, AccessSnapshot> accessByRecord =
                    fallbackAccess.containsKey(userId)
                        ? fallbackAccess.get(userId)
                        : new Map<Id, AccessSnapshot>();

                for (
                    Id parentId :
                    fallbackRequirements.get(userId).keySet()
                ) {
                    String requiredLevel =
                        fallbackRequirements.get(userId).get(parentId);

                    if (
                        hasRequiredAccess(
                            accessByRecord.get(parentId),
                            requiredLevel
                        )
                    ) {
                        continue;
                    }

                    ShareObjectInfo shareInfo =
                        getShareObjectInfo(parentId);

                    if (shareInfo.shareable) {
                        addRequirement(
                            missingFallbackShares,
                            userId,
                            parentId,
                            requiredLevel
                        );
                    }
                }
            }

            createOrUpgradeShares(missingFallbackShares);
        }
    }

    private static Map<Id, Map<Id, AccessSnapshot>> loadCurrentAccess(
        Map<Id, Map<Id, String>> requiredAccessByUser
    ) {
        Map<Id, Map<Id, AccessSnapshot>> result =
            new Map<Id, Map<Id, AccessSnapshot>>();

        for (Id userId : requiredAccessByUser.keySet()) {
            Set<Id> recordIds =
                requiredAccessByUser.get(userId).keySet();

            result.put(
                userId,
                queryUserRecordAccess(userId, recordIds)
            );
        }

        return result;
    }

    private static Map<Id, AccessSnapshot> queryUserRecordAccess(
        Id userId,
        Set<Id> recordIds
    ) {
        Map<Id, AccessSnapshot> result =
            new Map<Id, AccessSnapshot>();

        if (
            userId == null ||
            recordIds == null ||
            recordIds.isEmpty()
        ) {
            return result;
        }

        Map<String, List<Id>> recordIdsByObject =
            new Map<String, List<Id>>();

        for (Id recordId : recordIds) {
            String objectApiName =
                recordId.getSObjectType()
                    .getDescribe()
                    .getName();

            if (!recordIdsByObject.containsKey(objectApiName)) {
                recordIdsByObject.put(
                    objectApiName,
                    new List<Id>()
                );
            }

            recordIdsByObject.get(objectApiName).add(recordId);
        }

        for (String objectApiName : recordIdsByObject.keySet()) {
            List<Id> objectRecordIds =
                recordIdsByObject.get(objectApiName);

            for (
                Integer startIndex = 0;
                startIndex < objectRecordIds.size();
                startIndex += USER_RECORD_ACCESS_CHUNK
            ) {
                Integer proposedEndIndex =
                    startIndex + USER_RECORD_ACCESS_CHUNK;
                Integer endIndex =
                    proposedEndIndex < objectRecordIds.size()
                        ? proposedEndIndex
                        : objectRecordIds.size();

                Set<Id> chunkIds = new Set<Id>();

                for (
                    Integer rowIndex = startIndex;
                    rowIndex < endIndex;
                    rowIndex++
                ) {
                    chunkIds.add(objectRecordIds[rowIndex]);
                }

                for (
                    UserRecordAccess accessRecord : [
                        SELECT
                            RecordId,
                            HasReadAccess,
                            HasEditAccess
                        FROM UserRecordAccess
                        WHERE UserId = :userId
                        AND RecordId IN :chunkIds
                    ]
                ) {
                    AccessSnapshot snapshot = new AccessSnapshot();
                    snapshot.canRead = accessRecord.HasReadAccess;
                    snapshot.canEdit = accessRecord.HasEditAccess;
                    result.put(accessRecord.RecordId, snapshot);
                }
            }
        }

        return result;
    }

    private static void createOrUpgradeShares(
        Map<Id, Map<Id, String>> requirementsByUser
    ) {
        if (requirementsByUser.isEmpty()) {
            return;
        }

        Map<String, List<AccessRequirement>> requirementsByObject =
            new Map<String, List<AccessRequirement>>();

        for (Id userId : requirementsByUser.keySet()) {
            for (Id recordId : requirementsByUser.get(userId).keySet()) {
                String objectApiName =
                    recordId.getSObjectType().getDescribe().getName();

                if (!requirementsByObject.containsKey(objectApiName)) {
                    requirementsByObject.put(
                        objectApiName,
                        new List<AccessRequirement>()
                    );
                }

                requirementsByObject.get(objectApiName).add(
                    new AccessRequirement(
                        userId,
                        recordId,
                        requirementsByUser.get(userId).get(recordId)
                    )
                );
            }
        }

        for (String objectApiName : requirementsByObject.keySet()) {
            List<AccessRequirement> objectRequirements =
                requirementsByObject.get(objectApiName);

            if (objectRequirements.isEmpty()) {
                continue;
            }

            ShareObjectInfo shareInfo =
                getShareObjectInfo(objectRequirements[0].recordId);

            if (!shareInfo.shareable) {
                continue;
            }

            Set<Id> parentIds = new Set<Id>();
            Set<Id> userIds = new Set<Id>();

            for (AccessRequirement requirement : objectRequirements) {
                parentIds.add(requirement.recordId);
                userIds.add(requirement.userId);
            }

            Map<String, SObject> existingShareByKey =
                queryExistingShares(
                    shareInfo,
                    parentIds,
                    userIds
                );

            List<SObject> sharesToInsert = new List<SObject>();
            List<SObject> sharesToUpdate = new List<SObject>();

            Schema.SObjectType shareType =
                Schema.getGlobalDescribe().get(
                    shareInfo.shareObjectApiName
                );

            for (AccessRequirement requirement : objectRequirements) {
                String key = buildKey(
                    requirement.userId,
                    requirement.recordId
                );

                SObject existingShare =
                    existingShareByKey.get(key);

                if (existingShare == null) {
                    SObject newShare = shareType.newSObject();
                    newShare.put('ParentId', requirement.recordId);
                    newShare.put('UserOrGroupId', requirement.userId);
                    newShare.put('AccessLevel', requirement.accessLevel);
                    newShare.put('RowCause', shareInfo.rowCause);
                    sharesToInsert.add(newShare);
                    continue;
                }

                String existingAccess =
                    String.valueOf(existingShare.get('AccessLevel'));

                if (
                    requirement.accessLevel == ACCESS_EDIT &&
                    existingAccess != ACCESS_EDIT
                ) {
                    existingShare.put('AccessLevel', ACCESS_EDIT);
                    sharesToUpdate.add(existingShare);
                }
            }

            saveShares(
                sharesToInsert,
                sharesToUpdate,
                objectApiName
            );
        }
    }

    private static void reconcilePreferredShares(
        Map<Id, Map<Id, String>> requiredAccessByUser
    ) {
        if (requiredAccessByUser.isEmpty()) {
            return;
        }

        Map<String, List<AccessRequirement>> requirementsByObject =
            new Map<String, List<AccessRequirement>>();

        for (Id userId : requiredAccessByUser.keySet()) {
            for (Id recordId : requiredAccessByUser.get(userId).keySet()) {
                ShareObjectInfo info = getShareObjectInfo(recordId);

                if (
                    !info.shareable ||
                    !info.usesPreferredRowCause
                ) {
                    continue;
                }

                String objectApiName =
                    recordId.getSObjectType().getDescribe().getName();

                if (!requirementsByObject.containsKey(objectApiName)) {
                    requirementsByObject.put(
                        objectApiName,
                        new List<AccessRequirement>()
                    );
                }

                requirementsByObject.get(objectApiName).add(
                    new AccessRequirement(
                        userId,
                        recordId,
                        requiredAccessByUser.get(userId).get(recordId)
                    )
                );
            }
        }

        for (String objectApiName : requirementsByObject.keySet()) {
            List<AccessRequirement> objectRequirements =
                requirementsByObject.get(objectApiName);

            ShareObjectInfo shareInfo =
                getShareObjectInfo(objectRequirements[0].recordId);

            Set<Id> parentIds = new Set<Id>();
            Set<Id> userIds = new Set<Id>();
            Map<String, String> desiredAccessByKey =
                new Map<String, String>();

            for (AccessRequirement requirement : objectRequirements) {
                parentIds.add(requirement.recordId);
                userIds.add(requirement.userId);
                desiredAccessByKey.put(
                    buildKey(
                        requirement.userId,
                        requirement.recordId
                    ),
                    requirement.accessLevel
                );
            }

            Map<String, SObject> existingShares =
                queryExistingShares(
                    shareInfo,
                    parentIds,
                    userIds
                );

            List<SObject> sharesToDowngrade = new List<SObject>();

            for (String key : existingShares.keySet()) {
                String desiredAccess = desiredAccessByKey.get(key);
                SObject shareRecord = existingShares.get(key);

                if (
                    desiredAccess == ACCESS_READ &&
                    String.valueOf(
                        shareRecord.get('AccessLevel')
                    ) == ACCESS_EDIT
                ) {
                    shareRecord.put('AccessLevel', ACCESS_READ);
                    sharesToDowngrade.add(shareRecord);
                }
            }

            if (!sharesToDowngrade.isEmpty()) {
                Database.SaveResult[] results =
                    Database.update(sharesToDowngrade, false);

                assertSaveResults(
                    results,
                    objectApiName + ' BTL share downgrade'
                );
            }
        }
    }

    private static Map<String, SObject> queryExistingShares(
        ShareObjectInfo shareInfo,
        Set<Id> parentIds,
        Set<Id> userIds
    ) {
        Map<String, SObject> result = new Map<String, SObject>();

        if (
            parentIds.isEmpty() ||
            userIds.isEmpty()
        ) {
            return result;
        }

        Map<String, Object> binds = new Map<String, Object>{
            'parentIds' => parentIds,
            'userIds' => userIds,
            'rowCause' => shareInfo.rowCause
        };

        String queryText =
            'SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause ' +
            'FROM ' + shareInfo.shareObjectApiName + ' ' +
            'WHERE ParentId IN :parentIds ' +
            'AND UserOrGroupId IN :userIds ' +
            'AND RowCause = :rowCause';

        for (
            SObject shareRecord : Database.queryWithBinds(
                queryText,
                binds,
                AccessLevel.SYSTEM_MODE
            )
        ) {
            result.put(
                buildKey(
                    (Id) shareRecord.get('UserOrGroupId'),
                    (Id) shareRecord.get('ParentId')
                ),
                shareRecord
            );
        }

        return result;
    }

    private static void saveShares(
        List<SObject> sharesToInsert,
        List<SObject> sharesToUpdate,
        String objectApiName
    ) {
        if (!sharesToInsert.isEmpty()) {
            Database.SaveResult[] insertResults =
                Database.insert(sharesToInsert, false);

            assertSaveResults(
                insertResults,
                objectApiName + ' BTL share insert'
            );
        }

        if (!sharesToUpdate.isEmpty()) {
            Database.SaveResult[] updateResults =
                Database.update(sharesToUpdate, false);

            assertSaveResults(
                updateResults,
                objectApiName + ' BTL share update'
            );
        }
    }

    private static void assertSaveResults(
        Database.SaveResult[] results,
        String operationName
    ) {
        for (Database.SaveResult result : results) {
            if (result.isSuccess()) {
                continue;
            }

            String message = operationName + ' failed.';

            if (
                result.getErrors() != null &&
                !result.getErrors().isEmpty()
            ) {
                message += ' ' + result.getErrors()[0].getMessage();
            }

            throw new AuraHandledException(message);
        }
    }

    private static void verifyCoreEditAccess(
        Map<Id, Map<Id, String>> requiredAccessByUser,
        Set<String> coreEditRequirementKeys
    ) {
        if (coreEditRequirementKeys.isEmpty()) {
            return;
        }

        Map<Id, Map<Id, String>> coreRequirements =
            new Map<Id, Map<Id, String>>();

        for (Id userId : requiredAccessByUser.keySet()) {
            for (Id recordId : requiredAccessByUser.get(userId).keySet()) {
                String key = buildKey(userId, recordId);

                if (!coreEditRequirementKeys.contains(key)) {
                    continue;
                }

                addRequirement(
                    coreRequirements,
                    userId,
                    recordId,
                    ACCESS_EDIT
                );
            }
        }

        Map<Id, Map<Id, AccessSnapshot>> verifiedAccess =
            loadCurrentAccess(coreRequirements);

        for (Id userId : coreRequirements.keySet()) {
            Map<Id, AccessSnapshot> accessByRecord =
                verifiedAccess.get(userId);

            for (Id recordId : coreRequirements.get(userId).keySet()) {
                if (
                    accessByRecord == null ||
                    !hasRequiredAccess(
                        accessByRecord.get(recordId),
                        ACCESS_EDIT
                    )
                ) {
                    throw new AuraHandledException(
                        'BTL approval access could not be granted to the assigned approver. ' +
                        'Please verify object permissions and sharing configuration for record ' +
                        String.valueOf(recordId) + '.'
                    );
                }
            }
        }
    }

    private static ShareObjectInfo getShareObjectInfo(Id recordId) {
        ShareObjectInfo result = new ShareObjectInfo();

        if (recordId == null) {
            return result;
        }

        String objectApiName =
            recordId.getSObjectType().getDescribe().getName();

        if (!objectApiName.endsWith('__c')) {
            return result;
        }

        String shareObjectApiName =
            objectApiName.substring(
                0,
                objectApiName.length() - 3
            ) + '__Share';

        Schema.SObjectType shareType =
            Schema.getGlobalDescribe().get(shareObjectApiName);

        if (shareType == null) {
            return result;
        }

        Map<String, Schema.SObjectField> shareFields =
            shareType.getDescribe().fields.getMap();

        if (
            !shareFields.containsKey('ParentId') ||
            !shareFields.containsKey('UserOrGroupId') ||
            !shareFields.containsKey('AccessLevel') ||
            !shareFields.containsKey('RowCause')
        ) {
            return result;
        }

        result.shareable = true;
        result.shareObjectApiName = shareObjectApiName;
        result.rowCause = 'Manual';

        for (
            Schema.PicklistEntry entry :
            shareFields.get('RowCause')
                .getDescribe()
                .getPicklistValues()
        ) {
            if (entry.getValue() == PREFERRED_ROW_CAUSE) {
                result.rowCause = PREFERRED_ROW_CAUSE;
                result.usesPreferredRowCause = true;
                break;
            }
        }

        return result;
    }

    private static Boolean hasRequiredAccess(
        AccessSnapshot snapshot,
        String requiredLevel
    ) {
        if (snapshot == null) {
            return false;
        }

        return requiredLevel == ACCESS_EDIT
            ? snapshot.canEdit == true
            : snapshot.canRead == true || snapshot.canEdit == true;
    }

    private static void addReadRequirements(
        Map<Id, Map<Id, String>> requirements,
        Id userId,
        Set<Id> recordIds
    ) {
        if (
            userId == null ||
            recordIds == null
        ) {
            return;
        }

        for (Id recordId : recordIds) {
            addRequirement(
                requirements,
                userId,
                recordId,
                ACCESS_READ
            );
        }
    }

    private static void addRequirement(
        Map<Id, Map<Id, String>> requirements,
        Id userId,
        Id recordId,
        String accessLevel
    ) {
        if (
            userId == null ||
            recordId == null
        ) {
            return;
        }

        if (!requirements.containsKey(userId)) {
            requirements.put(
                userId,
                new Map<Id, String>()
            );
        }

        String existingLevel =
            requirements.get(userId).get(recordId);

        if (
            existingLevel == ACCESS_EDIT ||
            existingLevel == accessLevel
        ) {
            return;
        }

        requirements.get(userId).put(
            recordId,
            accessLevel
        );
    }

    private static void addFallback(
        Map<Id, Id> fallbackParentByChildId,
        Id childId,
        Id parentId
    ) {
        if (
            childId != null &&
            parentId != null
        ) {
            fallbackParentByChildId.put(
                childId,
                parentId
            );
        }
    }

    private static void addChild(
        Map<Id, Set<Id>> childrenByParentId,
        Id parentId,
        Id childId
    ) {
        if (
            parentId == null ||
            childId == null
        ) {
            return;
        }

        if (!childrenByParentId.containsKey(parentId)) {
            childrenByParentId.put(
                parentId,
                new Set<Id>()
            );
        }

        childrenByParentId.get(parentId).add(childId);
    }

    private static Boolean objectAndFieldExist(
        String objectApiName,
        String fieldApiName
    ) {
        Schema.SObjectType objectType =
            Schema.getGlobalDescribe().get(objectApiName);

        return
            objectType != null &&
            objectType.getDescribe()
                .fields.getMap()
                .containsKey(fieldApiName);
    }

    private static void addId(
        Set<Id> target,
        Id value
    ) {
        if (value != null) {
            target.add(value);
        }
    }

    private static String buildKey(
        Id userId,
        Id recordId
    ) {
        return String.valueOf(userId) + ':' +
            String.valueOf(recordId);
    }

    private Ctrl_Hlp_BTLApprovalSharing() {
    }
}