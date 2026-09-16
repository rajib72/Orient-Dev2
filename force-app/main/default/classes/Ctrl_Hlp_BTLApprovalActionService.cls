public inherited sharing class Ctrl_Hlp_BTLApprovalActionService {

    public static Map<String, Object> approve(Id taggedApprovalId, String comments) {
        if (taggedApprovalId == null) {
            throw new AuraHandledException('Approval transaction Id is required.');
        }

        Map<String, Object> result = approveMany(new Set<Id>{ taggedApprovalId }, comments);
        result.put('transactionId', taggedApprovalId);
        return result;
    }

    public static Map<String, Object> approveMany(Set<Id> taggedApprovalIds, String comments) {
        try {
            if (taggedApprovalIds == null || taggedApprovalIds.isEmpty()) {
                throw new AuraHandledException('Select at least one approval record.');
            }

            List<Tagged_Approval_Hierarchy__c> transactions = getLockedTransactions(taggedApprovalIds);

            if (transactions.size() != taggedApprovalIds.size()) {
                throw new AuraHandledException('One or more approval records could not be accessed.');
            }

            Id currentUserId = UserInfo.getUserId();
            Boolean isAdmin = isCurrentUserAdmin();
            Datetime actionDateTime = System.now();
            String normalizedComments = String.isBlank(comments) ? null : comments.trim();
            Set<Id> currentLevelIds = new Set<Id>();

            for (Tagged_Approval_Hierarchy__c transactionRecord : transactions) {
                validatePendingAction(transactionRecord, isAdmin);
                currentLevelIds.add(transactionRecord.Current_Approval_Level__c);
            }

            Map<Id, Approval_Hierarchy_Level__c> currentLevelById = new Map<Id, Approval_Hierarchy_Level__c>([
                SELECT Id, Name, Approval_Hierarchy__c, Responsible_Team__c, Sr_No__c
                FROM Approval_Hierarchy_Level__c
                WHERE Id IN :currentLevelIds
                WITH USER_MODE
            ]);

            if (currentLevelById.size() != currentLevelIds.size()) {
                throw new AuraHandledException('One or more current approval levels could not be found.');
            }

            Set<Id> hierarchyIds = new Set<Id>();
            for (Approval_Hierarchy_Level__c levelRecord : currentLevelById.values()) {
                hierarchyIds.add(levelRecord.Approval_Hierarchy__c);
            }

            List<Approval_Hierarchy_Level__c> allLevels = [
                SELECT Id, Name, Approval_Hierarchy__c, Responsible_Team__c, Sr_No__c
                FROM Approval_Hierarchy_Level__c
                WHERE Approval_Hierarchy__c IN :hierarchyIds
                WITH USER_MODE
                ORDER BY Approval_Hierarchy__c, Sr_No__c ASC
            ];

            Ctrl_Hlp_BTLApproverResolver.validateLevelSequences(
                allLevels
            );

            Map<Id, List<Approval_Hierarchy_Level__c>> levelsByHierarchy = new Map<Id, List<Approval_Hierarchy_Level__c>>();
            for (Approval_Hierarchy_Level__c levelRecord : allLevels) {
                if (!levelsByHierarchy.containsKey(levelRecord.Approval_Hierarchy__c)) {
                    levelsByHierarchy.put(levelRecord.Approval_Hierarchy__c, new List<Approval_Hierarchy_Level__c>());
                }
                levelsByHierarchy.get(levelRecord.Approval_Hierarchy__c).add(levelRecord);
            }

            Map<Id, Approval_Hierarchy_Level__c> nextLevelByCurrentLevelId = new Map<Id, Approval_Hierarchy_Level__c>();
            Set<Id> nextLevelIds = new Set<Id>();

            for (Approval_Hierarchy_Level__c currentLevel : currentLevelById.values()) {
                List<Approval_Hierarchy_Level__c> hierarchyLevels = levelsByHierarchy.get(currentLevel.Approval_Hierarchy__c);
                Approval_Hierarchy_Level__c nextLevel;

                if (hierarchyLevels != null) {
                    for (Approval_Hierarchy_Level__c candidateLevel : hierarchyLevels) {
                        if (candidateLevel.Sr_No__c > currentLevel.Sr_No__c) {
                            nextLevel = candidateLevel;
                            break;
                        }
                    }
                }

                if (nextLevel != null) {
                    nextLevelByCurrentLevelId.put(currentLevel.Id, nextLevel);
                    nextLevelIds.add(nextLevel.Id);
                }
            }

            Map<Id, Approval_Approver_Mapping__c> mappingByNextLevelId = Ctrl_Hlp_BTLApproverResolver.resolveApproversForLevels(nextLevelIds);
            List<Tagged_Approval_Hierarchy__c> transactionsToUpdate = new List<Tagged_Approval_Hierarchy__c>();
            List<Approval_Action_History__c> historyRecords = new List<Approval_Action_History__c>();
            Map<Id, Form_Activity_Assigned_Persons_Date__c> finalDateUpdatesById = new Map<Id, Form_Activity_Assigned_Persons_Date__c>();
            Integer advancedCount = 0;
            Integer finalApprovedCount = 0;
            Set<Id> advancedTransactionIds = new Set<Id>();
            Set<Id> finalApprovedTransactionIds = new Set<Id>();

            for (Tagged_Approval_Hierarchy__c transactionRecord : transactions) {
                Approval_Hierarchy_Level__c currentLevel = currentLevelById.get(transactionRecord.Current_Approval_Level__c);
                Approval_Hierarchy_Level__c nextLevel = nextLevelByCurrentLevelId.get(currentLevel.Id);
                String previousStatus = transactionRecord.Approval_Status__c;

                Approval_Action_History__c historyRecord = new Approval_Action_History__c(
                    Approval_Transaction__c = transactionRecord.Id,
                    Approval_Level__c = currentLevel.Id,
                    Action_By__c = currentUserId,
                    Action_Date_Time__c = actionDateTime,
                    Comments__c = normalizedComments,
                    Previous_Status__c = previousStatus,
                    Submission_Cycle__c = transactionRecord.Submission_Cycle__c
                );

                if (nextLevel != null) {
                    Approval_Approver_Mapping__c nextMapping = mappingByNextLevelId.get(nextLevel.Id);
                    if (nextMapping == null) {
                        throw new AuraHandledException('No approver could be resolved for level "' + nextLevel.Responsible_Team__c + '".');
                    }

                    transactionRecord.Approval_Status__c = Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING;
                    transactionRecord.Current_Approval_Level__c = nextLevel.Id;
                    transactionRecord.Pending_With__c = nextMapping.Approver_User__c;
                    transactionRecord.Returned_From_Level__c = null;
                    transactionRecord.Last_Action__c = Ctrl_Hlp_BTLApprovalConstants.ACTION_APPROVED;
                    transactionRecord.Last_Action_By__c = currentUserId;
                    transactionRecord.Last_Action_Date_Time__c = actionDateTime;
                    transactionRecord.Last_Action_Comments__c = normalizedComments;

                    historyRecord.Action__c = Ctrl_Hlp_BTLApprovalConstants.ACTION_APPROVED;
                    historyRecord.Assigned_To__c = nextMapping.Approver_User__c;
                    historyRecord.New_Status__c = Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING;
                    advancedTransactionIds.add(transactionRecord.Id);
                    advancedCount++;
                } else {
                    transactionRecord.Approval_Status__c = Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED;
                    transactionRecord.Current_Approval_Level__c = null;
                    transactionRecord.Pending_With__c = null;
                    transactionRecord.Returned_From_Level__c = null;
                    transactionRecord.Last_Action__c = Ctrl_Hlp_BTLApprovalConstants.ACTION_FINAL_APPROVED;
                    transactionRecord.Last_Action_By__c = currentUserId;
                    transactionRecord.Last_Action_Date_Time__c = actionDateTime;
                    transactionRecord.Last_Action_Comments__c = normalizedComments;
                    transactionRecord.Final_Approved_By__c = currentUserId;
                    transactionRecord.Final_Approved_Date_Time__c = actionDateTime;

                    historyRecord.Action__c = Ctrl_Hlp_BTLApprovalConstants.ACTION_FINAL_APPROVED;
                    historyRecord.Assigned_To__c = null;
                    historyRecord.New_Status__c = Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED;

                    finalDateUpdatesById.put(transactionRecord.Form_Activity_Assigned_Persons_Date__c,
                        new Form_Activity_Assigned_Persons_Date__c(
                            Id = transactionRecord.Form_Activity_Assigned_Persons_Date__c,
                            Approval_Status__c = Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED,
                            Approval_Locked__c = true,
                            Is_Active__c = true,
                            Assignment_Status__c = Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_ACTIVE
                        )
                    );
                    finalApprovedTransactionIds.add(
                        transactionRecord.Id
                    );
                    finalApprovedCount++;
                }

                transactionsToUpdate.add(transactionRecord);
                historyRecords.add(historyRecord);
            }

            update as user transactionsToUpdate;
            if (!finalDateUpdatesById.isEmpty()) {
                List<Form_Activity_Assigned_Persons_Date__c> finalDateUpdates = finalDateUpdatesById.values();
                update as user finalDateUpdates;
            }
            insert as user historyRecords;

            Ctrl_Hlp_BTLApprovalSharing.syncApprovalAccess(
                taggedApprovalIds
            );

            Ctrl_Hlp_BTLEmailNotificationService.sendApprovalRequired(
                advancedTransactionIds
            );
            Ctrl_Hlp_BTLEmailNotificationService.sendProcessCompleted(
                finalApprovedTransactionIds
            );

            Integer processedCount = transactionsToUpdate.size();
            String message = processedCount == 1
                ? 'The activity was approved successfully.'
                : String.valueOf(processedCount) + ' approval records were approved successfully.';

            return new Map<String, Object>{
                'success' => true,
                'processedCount' => processedCount,
                'advancedCount' => advancedCount,
                'finalApprovedCount' => finalApprovedCount,
                'message' => message
            };
        } catch (AuraHandledException handledException) {
            throw handledException;
        } catch (DmlException dmlException) {
            throw new AuraHandledException('Approval action failed: ' + dmlException.getDmlMessage(0));
        } catch (Exception exceptionRecord) {
            throw new AuraHandledException('Approval action failed: ' + exceptionRecord.getMessage());
        }
    }

    public static Map<String, Object> reject(Id taggedApprovalId, String rejectionReason) {
        if (taggedApprovalId == null) {
            throw new AuraHandledException('Approval transaction Id is required.');
        }

        Map<String, Object> result = rejectMany(new Set<Id>{ taggedApprovalId }, rejectionReason);
        result.put('transactionId', taggedApprovalId);
        return result;
    }

    public static Map<String, Object> rejectMany(Set<Id> taggedApprovalIds, String rejectionReason) {
        try {
            if (taggedApprovalIds == null || taggedApprovalIds.isEmpty()) {
                throw new AuraHandledException('Select at least one approval record.');
            }

            if (String.isBlank(rejectionReason)) {
                throw new AuraHandledException('Rejection reason is required.');
            }

            List<Tagged_Approval_Hierarchy__c> transactions = getLockedTransactions(taggedApprovalIds);
            if (transactions.size() != taggedApprovalIds.size()) {
                throw new AuraHandledException('One or more approval records could not be accessed.');
            }

            Id currentUserId = UserInfo.getUserId();
            Boolean isAdmin = isCurrentUserAdmin();
            Datetime actionDateTime = System.now();
            String normalizedReason = rejectionReason.trim();
            Set<Id> currentLevelIds = new Set<Id>();

            for (Tagged_Approval_Hierarchy__c transactionRecord : transactions) {
                validatePendingAction(transactionRecord, isAdmin);
                if (transactionRecord.Submitted_By__c == null) {
                    throw new AuraHandledException('The original Store Manager could not be identified for approval "' + transactionRecord.Name + '".');
                }
                currentLevelIds.add(transactionRecord.Current_Approval_Level__c);
            }

            Map<Id, Approval_Hierarchy_Level__c> currentLevelById = new Map<Id, Approval_Hierarchy_Level__c>([
                SELECT Id, Name, Approval_Hierarchy__c, Responsible_Team__c, Sr_No__c
                FROM Approval_Hierarchy_Level__c
                WHERE Id IN :currentLevelIds
                WITH USER_MODE
            ]);

            if (currentLevelById.size() != currentLevelIds.size()) {
                throw new AuraHandledException('One or more current approval levels could not be found.');
            }

            List<Tagged_Approval_Hierarchy__c> transactionsToUpdate = new List<Tagged_Approval_Hierarchy__c>();
            List<Approval_Action_History__c> historyRecords = new List<Approval_Action_History__c>();
            Map<Id, Form_Activity_Assigned_Persons_Date__c> dateUpdatesById = new Map<Id, Form_Activity_Assigned_Persons_Date__c>();

            for (Tagged_Approval_Hierarchy__c transactionRecord : transactions) {
                Approval_Hierarchy_Level__c currentLevel = currentLevelById.get(transactionRecord.Current_Approval_Level__c);
                String previousStatus = transactionRecord.Approval_Status__c;

                transactionRecord.Approval_Status__c = Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED;
                transactionRecord.Pending_With__c = transactionRecord.Submitted_By__c;
                transactionRecord.Returned_From_Level__c = currentLevel.Id;
                transactionRecord.Current_Approval_Level__c = null;
                transactionRecord.Last_Action__c = Ctrl_Hlp_BTLApprovalConstants.ACTION_REJECTED;
                transactionRecord.Last_Action_By__c = currentUserId;
                transactionRecord.Last_Action_Date_Time__c = actionDateTime;
                transactionRecord.Last_Action_Comments__c = normalizedReason;
                transactionRecord.Final_Approved_By__c = null;
                transactionRecord.Final_Approved_Date_Time__c = null;

                dateUpdatesById.put(transactionRecord.Form_Activity_Assigned_Persons_Date__c,
                    new Form_Activity_Assigned_Persons_Date__c(
                        Id = transactionRecord.Form_Activity_Assigned_Persons_Date__c,
                        Approval_Status__c = Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED,
                        Approval_Locked__c = false,
                        Is_Active__c = true,
                        Assignment_Status__c = Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_ACTIVE
                    )
                );

                historyRecords.add(new Approval_Action_History__c(
                    Approval_Transaction__c = transactionRecord.Id,
                    Approval_Level__c = currentLevel.Id,
                    Action__c = Ctrl_Hlp_BTLApprovalConstants.ACTION_REJECTED,
                    Action_By__c = currentUserId,
                    Action_Date_Time__c = actionDateTime,
                    Assigned_To__c = transactionRecord.Submitted_By__c,
                    Comments__c = normalizedReason,
                    Previous_Status__c = previousStatus,
                    New_Status__c = Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED,
                    Submission_Cycle__c = transactionRecord.Submission_Cycle__c
                ));

                transactionsToUpdate.add(transactionRecord);
            }

            update as user transactionsToUpdate;
            List<Form_Activity_Assigned_Persons_Date__c> dateUpdates = dateUpdatesById.values();
            update as user dateUpdates;
            insert as user historyRecords;

            Ctrl_Hlp_BTLApprovalSharing.syncApprovalAccess(
                taggedApprovalIds
            );

            Ctrl_Hlp_BTLEmailNotificationService.sendReturned(
                taggedApprovalIds
            );

            Integer processedCount = transactionsToUpdate.size();
            String message = processedCount == 1
                ? 'The activity has been rejected and returned to the Store Manager.'
                : String.valueOf(processedCount) + ' approval records were rejected and returned to their Store Managers.';

            return new Map<String, Object>{
                'success' => true,
                'processedCount' => processedCount,
                'approvalStatus' => Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED,
                'message' => message
            };
        } catch (AuraHandledException handledException) {
            throw handledException;
        } catch (DmlException dmlException) {
            throw new AuraHandledException('Rejection failed: ' + dmlException.getDmlMessage(0));
        } catch (Exception exceptionRecord) {
            throw new AuraHandledException('Rejection failed: ' + exceptionRecord.getMessage());
        }
    }

    public static Map<String, Object> drop(Id taggedApprovalId, String dropReason) {
        if (taggedApprovalId == null) {
            throw new AuraHandledException('Approval transaction Id is required.');
        }

        Map<String, Object> result = dropMany(new Set<Id>{ taggedApprovalId }, dropReason);
        result.put('transactionId', taggedApprovalId);
        return result;
    }

    public static Map<String, Object> dropMany(Set<Id> taggedApprovalIds, String dropReason) {
        return dropManyInternal(taggedApprovalIds, dropReason, false);
    }

    public static Map<String, Object> dropForReplacement(Id taggedApprovalId, String replacementReason) {
        if (taggedApprovalId == null) {
            throw new AuraHandledException('Approval transaction Id is required.');
        }

        Map<String, Object> result = dropManyInternal(
            new Set<Id>{ taggedApprovalId },
            replacementReason,
            true
        );
        result.put('transactionId', taggedApprovalId);
        return result;
    }

    private static Map<String, Object> dropManyInternal(
        Set<Id> taggedApprovalIds,
        String dropReason,
        Boolean isReplacement
    ) {
        try {
            if (taggedApprovalIds == null || taggedApprovalIds.isEmpty()) {
                throw new AuraHandledException('Select at least one returned approval record.');
            }

            if (String.isBlank(dropReason)) {
                throw new AuraHandledException(
                    isReplacement == true
                        ? 'Replacement reason is required.'
                        : 'Drop reason is required.'
                );
            }

            List<Tagged_Approval_Hierarchy__c> transactions = getLockedTransactions(taggedApprovalIds);
            if (transactions.size() != taggedApprovalIds.size()) {
                throw new AuraHandledException('One or more approval records could not be accessed.');
            }

            Id currentUserId = UserInfo.getUserId();
            Datetime actionDateTime = System.now();
            String normalizedReason = dropReason.trim();
            Set<Id> returnedLevelIds = new Set<Id>();
            Set<Id> assignedPersonIds = new Set<Id>();

            for (Tagged_Approval_Hierarchy__c transactionRecord : transactions) {
                if (transactionRecord.Approval_Status__c != Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED) {
                    throw new AuraHandledException('Approval "' + transactionRecord.Name + '" is not in Returned status.');
                }

                if (transactionRecord.Submitted_By__c != currentUserId) {
                    throw new AuraHandledException('Only the submitter can drop approval "' + transactionRecord.Name + '".');
                }

                if (transactionRecord.Returned_From_Level__c == null) {
                    throw new AuraHandledException('Returned approval level is missing for approval "' + transactionRecord.Name + '".');
                }

                if (transactionRecord.Form_Activity_Assigned_Persons_Date__c == null) {
                    throw new AuraHandledException('Assigned Person Date record is missing from approval "' + transactionRecord.Name + '".');
                }

                validateActivityDateOpen(transactionRecord);

                if (transactionRecord.Form_Activity_Assigned_Persons__c == null) {
                    throw new AuraHandledException('Assigned Person record is missing from approval "' + transactionRecord.Name + '".');
                }

                returnedLevelIds.add(transactionRecord.Returned_From_Level__c);
                assignedPersonIds.add(transactionRecord.Form_Activity_Assigned_Persons__c);
            }

            Map<Id, Approval_Hierarchy_Level__c> returnedLevelById = new Map<Id, Approval_Hierarchy_Level__c>([
                SELECT Id, Responsible_Team__c, Sr_No__c
                FROM Approval_Hierarchy_Level__c
                WHERE Id IN :returnedLevelIds
                WITH USER_MODE
            ]);

            if (returnedLevelById.size() != returnedLevelIds.size()) {
                throw new AuraHandledException('One or more returned approval levels could not be found.');
            }

            List<Tagged_Approval_Hierarchy__c> transactionsToUpdate = new List<Tagged_Approval_Hierarchy__c>();
            List<Form_Activity_Assigned_Persons_Date__c> dateRecordsToUpdate = new List<Form_Activity_Assigned_Persons_Date__c>();
            List<Approval_Action_History__c> historyRecords = new List<Approval_Action_History__c>();

            for (Tagged_Approval_Hierarchy__c transactionRecord : transactions) {
                Approval_Hierarchy_Level__c returnedLevel = returnedLevelById.get(transactionRecord.Returned_From_Level__c);
                String previousStatus = transactionRecord.Approval_Status__c;

                transactionRecord.Approval_Status__c = Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED;
                transactionRecord.Current_Approval_Level__c = null;
                transactionRecord.Pending_With__c = null;
                transactionRecord.Last_Action__c = Ctrl_Hlp_BTLApprovalConstants.ACTION_DROPPED;
                transactionRecord.Last_Action_By__c = currentUserId;
                transactionRecord.Last_Action_Date_Time__c = actionDateTime;
                transactionRecord.Last_Action_Comments__c = normalizedReason;
                transactionRecord.Final_Approved_By__c = null;
                transactionRecord.Final_Approved_Date_Time__c = null;
                transactionRecord.Dropped_By__c = currentUserId;
                transactionRecord.Dropped_Date_Time__c = actionDateTime;
                transactionRecord.Drop_Reason__c = normalizedReason;
                transactionsToUpdate.add(transactionRecord);

                dateRecordsToUpdate.add(new Form_Activity_Assigned_Persons_Date__c(
                    Id = transactionRecord.Form_Activity_Assigned_Persons_Date__c,
                    Approval_Status__c = Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED,
                    Approval_Locked__c = true,
                    Is_Active__c = false,
                    Assignment_Status__c = isReplacement == true
                        ? Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_REPLACED
                        : Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_DROPPED,
                    Replacement_Reason__c = isReplacement == true
                        ? normalizedReason
                        : null
                ));

                historyRecords.add(new Approval_Action_History__c(
                    Approval_Transaction__c = transactionRecord.Id,
                    Approval_Level__c = returnedLevel.Id,
                    Action__c = Ctrl_Hlp_BTLApprovalConstants.ACTION_DROPPED,
                    Action_By__c = currentUserId,
                    Action_Date_Time__c = actionDateTime,
                    Assigned_To__c = null,
                    Comments__c = normalizedReason,
                    Previous_Status__c = previousStatus,
                    New_Status__c = Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED,
                    Submission_Cycle__c = transactionRecord.Submission_Cycle__c
                ));
            }

            update as user transactionsToUpdate;
            update as user dateRecordsToUpdate;
            deactivateParentsWithoutActiveDates(assignedPersonIds);
            insert as user historyRecords;

            Ctrl_Hlp_BTLApprovalSharing.syncApprovalAccess(
                taggedApprovalIds
            );

            if (isReplacement != true) {
                Ctrl_Hlp_BTLEmailNotificationService.sendProcessCompleted(
                    taggedApprovalIds
                );
            }

            Integer processedCount = transactionsToUpdate.size();
            String message;

            if (isReplacement == true) {
                message = processedCount == 1
                    ? 'The old manpower assignment was deactivated and marked as Replaced.'
                    : String.valueOf(processedCount) + ' old manpower assignments were deactivated and marked as Replaced.';
            } else {
                message = processedCount == 1
                    ? 'The returned activity has been dropped successfully.'
                    : String.valueOf(processedCount) + ' returned approval records were dropped successfully.';
            }

            return new Map<String, Object>{
                'success' => true,
                'processedCount' => processedCount,
                'approvalStatus' => Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED,
                'assignmentStatus' => isReplacement == true
                    ? Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_REPLACED
                    : Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_DROPPED,
                'message' => message
            };
        } catch (AuraHandledException handledException) {
            throw handledException;
        } catch (DmlException dmlException) {
            throw new AuraHandledException('Drop action failed: ' + dmlException.getDmlMessage(0));
        } catch (Exception exceptionRecord) {
            throw new AuraHandledException('Drop action failed: ' + exceptionRecord.getMessage());
        }
    }

    private static void deactivateParentsWithoutActiveDates(Set<Id> assignedPersonIds) {
        if (assignedPersonIds == null || assignedPersonIds.isEmpty()) {
            return;
        }

        Set<Id> parentsWithActiveDates = new Set<Id>();

        for (AggregateResult resultRecord : [
            SELECT Form_Activity_Assigned_Persons__c assignedPersonId, COUNT(Id) activeDateCount
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Form_Activity_Assigned_Persons__c IN :assignedPersonIds
            AND (Is_Active__c = true OR Assignment_Status__c = null)
            GROUP BY Form_Activity_Assigned_Persons__c
        ]) {
            parentsWithActiveDates.add((Id) resultRecord.get('assignedPersonId'));
        }

        List<Form_Activity_Assigned_Persons__c> parentsToDeactivate = new List<Form_Activity_Assigned_Persons__c>();

        for (Id assignedPersonId : assignedPersonIds) {
            if (!parentsWithActiveDates.contains(assignedPersonId)) {
                parentsToDeactivate.add(new Form_Activity_Assigned_Persons__c(
                    Id = assignedPersonId,
                    Is_Active__c = false
                ));
            }
        }

        if (!parentsToDeactivate.isEmpty()) {
            update as user parentsToDeactivate;
        }
    }

    private static List<Tagged_Approval_Hierarchy__c> getLockedTransactions(Set<Id> taggedApprovalIds) {
        return [
            SELECT Id, Name, Approval_Hierarchy__c, Approval_Status__c,
                Current_Approval_Level__c, Pending_With__c, Returned_From_Level__c,
                Submission_Cycle__c, Submitted_By__c, Submitted_Date_Time__c,
                Last_Action__c, Last_Action_By__c, Last_Action_Date_Time__c,
                Last_Action_Comments__c, Final_Approved_By__c,
                Final_Approved_Date_Time__c, Form_Activity_Assigned_Persons__c,
                Form_Activity_Assigned_Persons_Date__c,
                Form_Activity_Assigned_Persons_Date__r.Target_Date__c,
                Form_Activity_Assigned_Persons_Date__r.Is_Active__c,
                Form_Activity_Assigned_Persons_Date__r.Assignment_Status__c
            FROM Tagged_Approval_Hierarchy__c
            WHERE Id IN :taggedApprovalIds
            WITH USER_MODE
            FOR UPDATE
        ];
    }

    private static void validatePendingAction(Tagged_Approval_Hierarchy__c transactionRecord, Boolean isAdmin) {
        if (transactionRecord.Approval_Status__c != Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING) {
            throw new AuraHandledException('Approval "' + transactionRecord.Name + '" is no longer pending.');
        }

        if (!isAdmin && transactionRecord.Pending_With__c == null) {
            throw new AuraHandledException('Pending approver is not configured for approval "' + transactionRecord.Name + '".');
        }

        if (!isAdmin && transactionRecord.Pending_With__c != UserInfo.getUserId()) {
            throw new AuraHandledException('Approval "' + transactionRecord.Name + '" is currently assigned to another user.');
        }

        if (transactionRecord.Form_Activity_Assigned_Persons_Date__c == null) {
            throw new AuraHandledException('Assigned Person Date record is missing from approval "' + transactionRecord.Name + '".');
        }

        if (
            transactionRecord.Form_Activity_Assigned_Persons_Date__r == null ||
            (
                transactionRecord.Form_Activity_Assigned_Persons_Date__r.Is_Active__c != true &&
                String.isNotBlank(transactionRecord.Form_Activity_Assigned_Persons_Date__r.Assignment_Status__c)
            )
        ) {
            throw new AuraHandledException(
                'Approval "' + transactionRecord.Name + '" belongs to an inactive, replaced, or dropped manpower assignment.'
            );
        }

        validateActivityDateOpen(transactionRecord);

        if (transactionRecord.Current_Approval_Level__c == null) {
            throw new AuraHandledException('Current approval level is missing from approval "' + transactionRecord.Name + '".');
        }
    }

    private static void validateActivityDateOpen(
        Tagged_Approval_Hierarchy__c transactionRecord
    ) {
        Date targetDate =
            transactionRecord.Form_Activity_Assigned_Persons_Date__r == null
                ? null
                : transactionRecord.Form_Activity_Assigned_Persons_Date__r.Target_Date__c;

        if (targetDate != null && targetDate < Date.today()) {
            throw new AuraHandledException(
                'Approval "' +
                transactionRecord.Name +
                '" is Date Over. The activity date has passed, so no further approval action is allowed.'
            );
        }
    }

    private static Boolean isCurrentUserAdmin() {
        Id profileId = UserInfo.getProfileId();
        Profile currentProfile = [
            SELECT Name 
            FROM Profile 
            WHERE Id = :profileId 
            LIMIT 1
        ];

        return currentProfile.Name == Ctrl_Hlp_BTLApprovalConstants.PROFILE_SYSTEM_ADMIN;
    }
}