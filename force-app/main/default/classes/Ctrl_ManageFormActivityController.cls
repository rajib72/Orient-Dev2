/**
 * Class Name  : Ctrl_ManageFormActivityController
 *
 * Description :
 * Loads and updates an existing Form Activity with:
 * - Activity information
 * - Multiple Teams
 * - Assigned Sales Executives
 * - Target dates
 * - Date-wise Activity Locations
 */
public with sharing class Ctrl_ManageFormActivityController {

    @AuraEnabled(cacheable=true)
    public static List<FormActivityOptionWrapper> getFormActivities(
        Id finalCustomizeFormId
    ) {
        if (finalCustomizeFormId == null) {
            throw new AuraHandledException(
                'Final Customize Form record id is missing.'
            );
        }

        List<FormActivityOptionWrapper> options =
            new List<FormActivityOptionWrapper>();

        for (Form_Activity__c activityRecord : [
            SELECT
                Id,
                Name,
                Activity_Name__c,
                Activity_Date__c,
                Activity_End_Date__c,
                Assigned_Store__c,
                Assigned_Store__r.Name,
                CreatedDate
            FROM Form_Activity__c
            WHERE Final_Customize_Form__c = :finalCustomizeFormId
            ORDER BY CreatedDate DESC
            LIMIT 500
        ]) {
            String storeName =
                activityRecord.Assigned_Store__r != null
                    ? activityRecord.Assigned_Store__r.Name
                    : '';

            String activityDateText =
                activityRecord.Activity_Date__c != null
                    ? String.valueOf(activityRecord.Activity_Date__c)
                    : '';

            String optionLabel =
                activityRecord.Name +
                ' | ' +
                storeName +
                ' | ' +
                activityDateText;

            options.add(
                new FormActivityOptionWrapper(
                    activityRecord.Id,
                    optionLabel,
                    activityRecord.Name,
                    storeName,
                    activityRecord.Activity_Date__c
                )
            );
        }

        return options;
    }

    @AuraEnabled
    public static ActivityEditWrapper getActivityDetails(
        Id formActivityId
    ) {
        if (formActivityId == null) {
            throw new AuraHandledException(
                'Please select a Form Activity.'
            );
        }

        List<Form_Activity__c> activityRecords = [
            SELECT
                Id,
                Name,
                Final_Customize_Form__c,
                Assigned_Store__c,
                Assigned_Store__r.Name,
                Activity_Name__c,
                Activity_Date__c,
                Activity_End_Date__c
            FROM Form_Activity__c
            WHERE Id = :formActivityId
            LIMIT 1
        ];

        if (activityRecords.isEmpty()) {
            throw new AuraHandledException(
                'The selected Form Activity was not found.'
            );
        }

        Form_Activity__c activityRecord =
            activityRecords[0];

        List<Form_Activity_Assigned_Persons__c> assignedPersons = [
            SELECT
                Id,
                Form_Activity__c,
                Store__c,
                Sales_Executives__c,
                Sales_Executives__r.Name,
                Person_Name__c,
                Team_Name__c
            FROM Form_Activity_Assigned_Persons__c
            WHERE Form_Activity__c = :formActivityId
            ORDER BY Team_Name__c ASC, Person_Name__c ASC
        ];

        Set<Id> assignedPersonIds =
            new Map<Id, Form_Activity_Assigned_Persons__c>(
                assignedPersons
            ).keySet();

        Map<Id, List<DateAssignmentDetailWrapper>>
            datesByAssignedPersonId =
                new Map<
                    Id,
                    List<DateAssignmentDetailWrapper>
                >();

        Boolean hasLockedCurrentAssignment = false;
        Boolean hasApprovedCurrentAssignment = false;
        Boolean hasPendingCurrentAssignment = false;
        Boolean hasReturnedCurrentAssignment = false;

        if (!assignedPersonIds.isEmpty()) {
            for (
                Form_Activity_Assigned_Persons_Date__c dateRecord :
                [
                    SELECT
                        Id,
                        Form_Activity_Assigned_Persons__c,
                        Target_Date__c,
                        Activity_Location__c,
                        Approval_Status__c,
                        Approval_Locked__c,
                        Is_Active__c,
                        Assignment_Status__c,
                        Rescheduled_From__c
                    FROM Form_Activity_Assigned_Persons_Date__c
                    WHERE Form_Activity_Assigned_Persons__c
                        IN :assignedPersonIds
                    ORDER BY Target_Date__c ASC
                ]
            ) {
                if (!isCurrentManageDateRecord(dateRecord)) {
                    continue;
                }

                String approvalStatus =
                    dateRecord.Approval_Status__c;

                Boolean rowApprovalLocked =
                    isManageDateRecordLocked(
                        dateRecord
                    );

                if (rowApprovalLocked) {
                    hasLockedCurrentAssignment = true;
                }

                if (
                    approvalStatus ==
                    Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED
                ) {
                    hasApprovedCurrentAssignment = true;
                }

                if (
                    approvalStatus ==
                    Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING
                ) {
                    hasPendingCurrentAssignment = true;
                }

                if (
                    approvalStatus ==
                    Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED
                ) {
                    hasReturnedCurrentAssignment = true;
                }

                Id parentId =
                    dateRecord
                        .Form_Activity_Assigned_Persons__c;

                if (
                    !datesByAssignedPersonId.containsKey(
                        parentId
                    )
                ) {
                    datesByAssignedPersonId.put(
                        parentId,
                        new List<
                            DateAssignmentDetailWrapper
                        >()
                    );
                }

                datesByAssignedPersonId
                    .get(parentId)
                    .add(
                        new DateAssignmentDetailWrapper(
                            dateRecord.Id,
                            dateRecord.Target_Date__c,
                            dateRecord.Activity_Location__c,
                            approvalStatus,
                            dateRecord.Approval_Locked__c,
                            rowApprovalLocked,
                            buildManageDateLockMessage(
                                approvalStatus,
                                rowApprovalLocked
                            )
                        )
                    );
            }
        }

        List<AssignmentDetailWrapper> assignments =
            new List<AssignmentDetailWrapper>();

        for (
            Form_Activity_Assigned_Persons__c assignedPerson :
            assignedPersons
        ) {
            if (
                !datesByAssignedPersonId.containsKey(
                    assignedPerson.Id
                ) ||
                datesByAssignedPersonId.get(
                    assignedPerson.Id
                ).isEmpty()
            ) {
                continue;
            }

            assignments.add(
                new AssignmentDetailWrapper(
                    assignedPerson.Id,
                    assignedPerson.Sales_Executives__c,
                    assignedPerson.Sales_Executives__r != null
                        ? assignedPerson
                            .Sales_Executives__r
                            .Name
                        : assignedPerson.Person_Name__c,
                    assignedPerson.Team_Name__c,
                    datesByAssignedPersonId.containsKey(
                        assignedPerson.Id
                    )
                        ? datesByAssignedPersonId.get(
                            assignedPerson.Id
                        )
                        : new List<
                            DateAssignmentDetailWrapper
                        >()
                )
            );
        }

        String editLockMessage = null;

        if (hasLockedCurrentAssignment) {
            if (
                hasApprovedCurrentAssignment &&
                hasPendingCurrentAssignment
            ) {
                editLockMessage =
                    'Some Sales Executive date assignments are approved and some are pending for approval. Only those locked date assignments are read-only; all other editable dates can still be managed.';
            } else if (hasApprovedCurrentAssignment) {
                editLockMessage =
                    'Approved Sales Executive date assignments are locked. Other dates and unlocked assignments can still be managed.';
            } else {
                editLockMessage =
                    'Some Sales Executive date assignments are currently locked for approval. Only those Target Dates are read-only; other dates and unlocked assignments can still be managed.';
            }
        }

        Boolean isReturnedForCorrection =
            hasReturnedCurrentAssignment;

        return new ActivityEditWrapper(
            activityRecord.Id,
            activityRecord.Name,
            activityRecord.Final_Customize_Form__c,
            activityRecord.Assigned_Store__c,
            activityRecord.Assigned_Store__r != null
                ? activityRecord.Assigned_Store__r.Name
                : '',
            activityRecord.Activity_Name__c,
            activityRecord.Activity_Date__c,
            activityRecord.Activity_End_Date__c,
            assignments,
            false,
            editLockMessage,
            isReturnedForCorrection,
            hasLockedCurrentAssignment
        );
    }

    @AuraEnabled
    public static Id updateActivity(
        ActivityUpdateRequest request
    ) {
        if (
            request == null ||
            request.formActivityId == null
        ) {
            throw new AuraHandledException(
                'Form Activity record id is missing.'
            );
        }

        List<Form_Activity__c> activityRecords = [
            SELECT
                Id,
                Final_Customize_Form__c,
                Assigned_Store__c,
                Assigned_Store__r.Name,
                Activity_Name__c,
                Activity_Date__c,
                Activity_End_Date__c
            FROM Form_Activity__c
            WHERE Id = :request.formActivityId
            LIMIT 1
            FOR UPDATE
        ];

        if (activityRecords.isEmpty()) {
            throw new AuraHandledException(
                'The selected Form Activity was not found.'
            );
        }

        Form_Activity__c activityRecord =
            activityRecords[0];

        validateActivityInputs(request);

        Set<String> validTeamNames =
            getValidTeamNames();

        if (validTeamNames.isEmpty()) {
            throw new AuraHandledException(
                'No Team records are available in Team Custom Metadata.'
            );
        }

        if (
            request.assignments == null ||
            request.assignments.isEmpty()
        ) {
            throw new AuraHandledException(
                'Please select at least one Sales Executive.'
            );
        }

        List<Form_Activity_Assigned_Persons__c>
            existingAssignedPersons = [
                SELECT
                    Id,
                    Form_Activity__c,
                    Store__c,
                    Sales_Executives__c,
                    Person_Name__c,
                    Team_Name__c
                FROM Form_Activity_Assigned_Persons__c
                WHERE Form_Activity__c =
                    :activityRecord.Id
                FOR UPDATE
            ];

        Map<Id, Form_Activity_Assigned_Persons__c>
            existingAssignedPersonMap =
                new Map<
                    Id,
                    Form_Activity_Assigned_Persons__c
                >(existingAssignedPersons);

        Set<Id> existingAssignedPersonIds =
            existingAssignedPersonMap.keySet();

        List<Form_Activity_Assigned_Persons_Date__c>
            existingDateRecords =
                new List<
                    Form_Activity_Assigned_Persons_Date__c
                >();

        if (!existingAssignedPersonIds.isEmpty()) {
            existingDateRecords = [
                SELECT
                    Id,
                    Form_Activity_Assigned_Persons__c,
                    Target_Date__c,
                    Activity_Location__c,
                    Approval_Status__c,
                    Approval_Locked__c,
                    Is_Active__c,
                    Assignment_Status__c,
                    Rescheduled_From__c,
                    Form_Activity_Assigned_Persons__r.Team_Name__c
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Form_Activity_Assigned_Persons__c
                    IN :existingAssignedPersonIds
                FOR UPDATE
            ];
        }

        Map<Id, Form_Activity_Assigned_Persons_Date__c>
            existingDateRecordMap =
                new Map<
                    Id,
                    Form_Activity_Assigned_Persons_Date__c
                >(existingDateRecords);

        Set<Id> submittedAssignedPersonIds =
            new Set<Id>();

        Set<Id> submittedDateRecordIds =
            new Set<Id>();

        Set<Id> submittedExecutiveIds =
            new Set<Id>();

        List<NormalizedAssignment>
            normalizedAssignments =
                new List<NormalizedAssignment>();

        for (
            AssignmentUpdateWrapper assignment :
            request.assignments
        ) {
            if (
                assignment == null ||
                assignment.salesExecutiveId == null
            ) {
                throw new AuraHandledException(
                    'A Sales Executive is missing from one of the assignments.'
                );
            }

            if (
                submittedExecutiveIds.contains(
                    assignment.salesExecutiveId
                )
            ) {
                throw new AuraHandledException(
                    'The same Sales Executive cannot be assigned to multiple Teams.'
                );
            }

            submittedExecutiveIds.add(
                assignment.salesExecutiveId
            );

            if (
                String.isBlank(
                    assignment.teamName
                )
            ) {
                throw new AuraHandledException(
                    'Please select a Team for every Sales Executive.'
                );
            }

            String normalizedTeamName =
                assignment.teamName.trim();

            if (
                !validTeamNames.contains(
                    normalizedTeamName
                )
            ) {
                throw new AuraHandledException(
                    'Invalid Team selected: ' +
                    normalizedTeamName
                );
            }

            if (
                assignment.assignedPersonId != null
            ) {
                if (
                    !existingAssignedPersonMap.containsKey(
                        assignment.assignedPersonId
                    )
                ) {
                    throw new AuraHandledException(
                        'An Assigned Person record does not belong to the selected Form Activity.'
                    );
                }

                if (
                    submittedAssignedPersonIds.contains(
                        assignment.assignedPersonId
                    )
                ) {
                    throw new AuraHandledException(
                        'The same Assigned Person record was submitted more than once.'
                    );
                }

                submittedAssignedPersonIds.add(
                    assignment.assignedPersonId
                );
            }

            if (
                assignment.dateAssignments == null ||
                assignment.dateAssignments.isEmpty()
            ) {
                throw new AuraHandledException(
                    'Please select at least one Target Date for every Sales Executive.'
                );
            }

            Set<String> uniqueDateLocationKeys =
                new Set<String>();

            List<NormalizedDateAssignment>
                normalizedDateAssignments =
                    new List<
                        NormalizedDateAssignment
                    >();

            for (
                DateAssignmentUpdateWrapper dateAssignment :
                assignment.dateAssignments
            ) {
                if (
                    dateAssignment == null ||
                    String.isBlank(
                        dateAssignment.targetDate
                    )
                ) {
                    throw new AuraHandledException(
                        'A Target Date is missing.'
                    );
                }

                Date normalizedTargetDate;

                try {
                    normalizedTargetDate =
                        Date.valueOf(
                            dateAssignment.targetDate
                        );
                } catch (Exception exceptionRecord) {
                    throw new AuraHandledException(
                        'An invalid Target Date was provided.'
                    );
                }

                if (
                    normalizedTargetDate <
                        request.activityDate ||
                    normalizedTargetDate >
                        request.activityEndDate
                ) {
                    throw new AuraHandledException(
                        'Target Dates must be between Activity Start Date and Activity End Date.'
                    );
                }

                if (
                    String.isBlank(
                        dateAssignment.activityLocation
                    )
                ) {
                    throw new AuraHandledException(
                        'Please enter Activity Location for every Target Date.'
                    );
                }

                String dateLocationKey =
                    String.valueOf(normalizedTargetDate) +
                    '||' +
                    normalizeManageLocationKey(
                        dateAssignment.activityLocation
                    );

                if (
                    uniqueDateLocationKeys.contains(
                        dateLocationKey
                    )
                ) {
                    throw new AuraHandledException(
                        'The same Target Date and Activity Location cannot be selected twice for a Sales Executive.'
                    );
                }

                uniqueDateLocationKeys.add(
                    dateLocationKey
                );

                if (
                    dateAssignment.assignedPersonDateId != null
                ) {
                    if (
                        assignment.assignedPersonId == null
                    ) {
                        throw new AuraHandledException(
                            'A new Assigned Person cannot contain an existing date record id.'
                        );
                    }

                    if (
                        !existingDateRecordMap.containsKey(
                            dateAssignment
                                .assignedPersonDateId
                        )
                    ) {
                        throw new AuraHandledException(
                            'A date record does not belong to the selected Form Activity.'
                        );
                    }

                    Form_Activity_Assigned_Persons_Date__c
                        existingDateRecord =
                            existingDateRecordMap.get(
                                dateAssignment
                                    .assignedPersonDateId
                            );

                    if (
                        existingDateRecord
                            .Form_Activity_Assigned_Persons__c
                        != assignment.assignedPersonId
                    ) {
                        throw new AuraHandledException(
                            'A date record is linked to a different Assigned Person.'
                        );
                    }

                    if (
                        submittedDateRecordIds.contains(
                            dateAssignment
                                .assignedPersonDateId
                        )
                    ) {
                        throw new AuraHandledException(
                            'The same date record was submitted more than once.'
                        );
                    }

                    submittedDateRecordIds.add(
                        dateAssignment
                            .assignedPersonDateId
                    );
                }

                normalizedDateAssignments.add(
                    new NormalizedDateAssignment(
                        dateAssignment
                            .assignedPersonDateId,
                        normalizedTargetDate,
                        normalizeActivityLocation(
                            dateAssignment.activityLocation
                        )
                    )
                );
            }

            normalizedAssignments.add(
                new NormalizedAssignment(
                    assignment.assignedPersonId,
                    assignment.salesExecutiveId,
                    normalizedTeamName,
                    normalizedDateAssignments
                )
            );
        }

        Map<Id, Sales_Executives__c>
            selectedExecutiveMap =
                new Map<Id, Sales_Executives__c>([
                    SELECT
                        Id,
                        Name,
                        Store__c
                    FROM Sales_Executives__c
                    WHERE Id IN :submittedExecutiveIds
                ]);

        if (
            selectedExecutiveMap.size() !=
            submittedExecutiveIds.size()
        ) {
            throw new AuraHandledException(
                'One or more selected Sales Executives are invalid.'
            );
        }

        for (
            Sales_Executives__c executiveRecord :
            selectedExecutiveMap.values()
        ) {
            if (
                executiveRecord.Store__c !=
                activityRecord.Assigned_Store__c
            ) {
                throw new AuraHandledException(
                    'Every selected Sales Executive must belong to the Form Activity Store.'
                );
            }
        }

        /*
         * Approval locking is granular at the current
         * Sales Executive + Target Date row.
         *
         * Pending / Approved rows must remain unchanged.
         * Other dates on the same Form Activity remain editable.
         */
        validateLockedManageRecords(
            request,
            existingAssignedPersonMap,
            existingDateRecords,
            normalizedAssignments
        );

        /*
         * One Form Activity has one Store. Within that Store,
         * Team + Target Date represents one activity execution
         * location. Every selected Sales Executive in that
         * same group must therefore carry the same location.
         */
        validateSharedDateLocations(
            normalizedAssignments,
            activityRecord,
            existingDateRecords
        );

        /*
         * Delete removed child date records before inserting
         * replacement dates.
         */
        List<Form_Activity_Assigned_Persons_Date__c>
            dateRecordsToDelete =
                new List<
                    Form_Activity_Assigned_Persons_Date__c
                >();

        Set<Id> assignedPersonIdsWithHistoricalDates =
            new Set<Id>();

        Set<Id> assignedPersonIdsWithLockedCurrentDates =
            new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                existingDateRecord :
            existingDateRecords
        ) {
            if (
                isCurrentManageDateRecord(
                    existingDateRecord
                ) &&
                isManageDateRecordLocked(
                    existingDateRecord
                )
            ) {
                assignedPersonIdsWithLockedCurrentDates.add(
                    existingDateRecord
                        .Form_Activity_Assigned_Persons__c
                );
            }
        }

        for (
            Form_Activity_Assigned_Persons_Date__c
                existingDateRecord :
            existingDateRecords
        ) {
            if (!isCurrentManageDateRecord(existingDateRecord)) {
                assignedPersonIdsWithHistoricalDates.add(
                    existingDateRecord
                        .Form_Activity_Assigned_Persons__c
                );
                continue;
            }

            if (
                isManageDateRecordLocked(
                    existingDateRecord
                )
            ) {
                continue;
            }

            if (
                !submittedDateRecordIds.contains(
                    existingDateRecord.Id
                )
            ) {
                dateRecordsToDelete.add(
                    existingDateRecord
                );
            }
        }

        if (!dateRecordsToDelete.isEmpty()) {
            delete dateRecordsToDelete;
        }

        /*
         * Delete Assigned Persons removed from the submitted
         * structure.
         */
        List<Form_Activity_Assigned_Persons__c>
            assignedPersonsToDelete =
                new List<
                    Form_Activity_Assigned_Persons__c
                >();

        for (
            Form_Activity_Assigned_Persons__c
                existingAssignedPerson :
            existingAssignedPersons
        ) {
            if (
                !submittedAssignedPersonIds.contains(
                    existingAssignedPerson.Id
                ) &&
                !assignedPersonIdsWithHistoricalDates.contains(
                    existingAssignedPerson.Id
                ) &&
                !assignedPersonIdsWithLockedCurrentDates.contains(
                    existingAssignedPerson.Id
                )
            ) {
                assignedPersonsToDelete.add(
                    existingAssignedPerson
                );
            }
        }

        if (!assignedPersonsToDelete.isEmpty()) {
            delete assignedPersonsToDelete;
        }

        activityRecord.Activity_Name__c =
            request.activityName.trim();

        activityRecord.Activity_Date__c =
            request.activityDate;

        activityRecord.Activity_End_Date__c =
            request.activityEndDate;

        update activityRecord;

        List<Form_Activity_Assigned_Persons__c>
            assignedPersonsToUpdate =
                new List<
                    Form_Activity_Assigned_Persons__c
                >();

        List<Form_Activity_Assigned_Persons__c>
            assignedPersonsToInsert =
                new List<
                    Form_Activity_Assigned_Persons__c
                >();

        List<Id> insertedPersonExecutiveIds =
            new List<Id>();

        Map<Id, Id> assignedPersonIdByExecutiveId =
            new Map<Id, Id>();

        for (
            NormalizedAssignment normalizedAssignment :
            normalizedAssignments
        ) {
            Sales_Executives__c executiveRecord =
                selectedExecutiveMap.get(
                    normalizedAssignment.executiveId
                );

            if (
                normalizedAssignment.assignedPersonId != null
            ) {
                Form_Activity_Assigned_Persons__c
                    assignedPerson =
                        existingAssignedPersonMap.get(
                            normalizedAssignment
                                .assignedPersonId
                        );

                Boolean parentChanged =
                    assignedPerson.Store__c !=
                        activityRecord.Assigned_Store__c ||
                    assignedPerson.Sales_Executives__c !=
                        executiveRecord.Id ||
                    assignedPerson.Person_Name__c !=
                        executiveRecord.Name ||
                    normalizeManageTextKey(
                        assignedPerson.Team_Name__c
                    ) !=
                    normalizeManageTextKey(
                        normalizedAssignment.teamName
                    );

                if (
                    parentChanged &&
                    !assignedPersonIdsWithLockedCurrentDates.contains(
                        assignedPerson.Id
                    )
                ) {
                    assignedPerson.Store__c =
                        activityRecord.Assigned_Store__c;

                    assignedPerson.Sales_Executives__c =
                        executiveRecord.Id;

                    assignedPerson.Person_Name__c =
                        executiveRecord.Name;

                    assignedPerson.Team_Name__c =
                        normalizedAssignment.teamName;

                    assignedPersonsToUpdate.add(
                        assignedPerson
                    );
                }

                assignedPersonIdByExecutiveId.put(
                    executiveRecord.Id,
                    assignedPerson.Id
                );
            } else {
                Form_Activity_Assigned_Persons__c
                    newAssignedPerson =
                        new Form_Activity_Assigned_Persons__c(
                            Form_Activity__c =
                                activityRecord.Id,
                            Store__c =
                                activityRecord.Assigned_Store__c,
                            Sales_Executives__c =
                                executiveRecord.Id,
                            Person_Name__c =
                                executiveRecord.Name,
                            Team_Name__c =
                                normalizedAssignment.teamName
                        );

                assignedPersonsToInsert.add(
                    newAssignedPerson
                );

                insertedPersonExecutiveIds.add(
                    executiveRecord.Id
                );
            }
        }

        if (!assignedPersonsToUpdate.isEmpty()) {
            update assignedPersonsToUpdate;
        }

        if (!assignedPersonsToInsert.isEmpty()) {
            insert assignedPersonsToInsert;

            for (
                Integer indexValue = 0;
                indexValue <
                    assignedPersonsToInsert.size();
                indexValue++
            ) {
                assignedPersonIdByExecutiveId.put(
                    insertedPersonExecutiveIds[
                        indexValue
                    ],
                    assignedPersonsToInsert[
                        indexValue
                    ].Id
                );
            }
        }

        List<Form_Activity_Assigned_Persons_Date__c>
            dateRecordsToUpdate =
                new List<
                    Form_Activity_Assigned_Persons_Date__c
                >();

        List<Form_Activity_Assigned_Persons_Date__c>
            dateRecordsToInsert =
                new List<
                    Form_Activity_Assigned_Persons_Date__c
                >();

        for (
            NormalizedAssignment normalizedAssignment :
            normalizedAssignments
        ) {
            Id assignedPersonId =
                assignedPersonIdByExecutiveId.get(
                    normalizedAssignment.executiveId
                );

            if (assignedPersonId == null) {
                throw new AuraHandledException(
                    'Unable to resolve an Assigned Person record.'
                );
            }

            for (
                NormalizedDateAssignment
                    normalizedDateAssignment :
                normalizedAssignment.dateAssignments
            ) {
                if (
                    normalizedDateAssignment.dateRecordId != null
                ) {
                    Form_Activity_Assigned_Persons_Date__c
                        existingDateRecord =
                            existingDateRecordMap.get(
                                normalizedDateAssignment
                                    .dateRecordId
                            );

                    if (
                        isManageDateRecordLocked(
                            existingDateRecord
                        )
                    ) {
                        /*
                         * The granular lock validation above has
                         * already confirmed this row is unchanged.
                         * Avoid unnecessary DML on protected rows.
                         */
                        continue;
                    }

                    Boolean dateChanged =
                        existingDateRecord
                            .Form_Activity_Assigned_Persons__c !=
                                assignedPersonId ||
                        existingDateRecord.Target_Date__c !=
                            normalizedDateAssignment.targetDate ||
                        !sameStoredActivityLocation(
                            existingDateRecord.Activity_Location__c,
                            normalizedDateAssignment.activityLocation
                        );

                    if (dateChanged) {
                        existingDateRecord
                            .Form_Activity_Assigned_Persons__c =
                                assignedPersonId;

                        existingDateRecord.Target_Date__c =
                            normalizedDateAssignment.targetDate;

                        existingDateRecord.Activity_Location__c =
                            normalizedDateAssignment
                                .activityLocation;

                        dateRecordsToUpdate.add(
                            existingDateRecord
                        );
                    }
                } else {
                    dateRecordsToInsert.add(
                        new Form_Activity_Assigned_Persons_Date__c(
                            Form_Activity_Assigned_Persons__c =
                                assignedPersonId,
                            Target_Date__c =
                                normalizedDateAssignment
                                    .targetDate,
                            Activity_Location__c =
                                normalizedDateAssignment
                                    .activityLocation
                        )
                    );
                }
            }
        }

        if (!dateRecordsToUpdate.isEmpty()) {
            update dateRecordsToUpdate;
        }

        if (!dateRecordsToInsert.isEmpty()) {
            insert dateRecordsToInsert;
        }

        return activityRecord.Id;
    }

    private static Boolean isManageDateRecordLocked(
        Form_Activity_Assigned_Persons_Date__c dateRecord
    ) {
        if (dateRecord == null) {
            return false;
        }

        String approvalStatus =
            dateRecord.Approval_Status__c;

        return
            dateRecord.Approval_Locked__c == true ||
            approvalStatus ==
                Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING ||
            approvalStatus ==
                Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED;
    }

    private static String buildManageDateLockMessage(
        String approvalStatus,
        Boolean isLocked
    ) {
        if (isLocked != true) {
            return null;
        }

        if (
            approvalStatus ==
            Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED
        ) {
            return
                'This Sales Executive assignment is already approved for this Target Date and cannot be changed.';
        }

        if (
            approvalStatus ==
            Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING
        ) {
            return
                'This Sales Executive assignment is currently pending for approval for this Target Date and cannot be changed.';
        }

        return
            'This Sales Executive assignment is currently locked for approval for this Target Date and cannot be changed.';
    }

    private static String normalizeManageTextKey(
        String value
    ) {
        return String.isBlank(value)
            ? ''
            : value.trim().toLowerCase();
    }

    private static void validateLockedManageRecords(
        ActivityUpdateRequest request,
        Map<Id, Form_Activity_Assigned_Persons__c>
            existingAssignedPersonMap,
        List<Form_Activity_Assigned_Persons_Date__c>
            existingDateRecords,
        List<NormalizedAssignment> normalizedAssignments
    ) {
        Map<Id, NormalizedAssignment>
            requestedAssignmentByParentId =
                new Map<Id, NormalizedAssignment>();

        Map<Id, NormalizedDateAssignment>
            requestedDateById =
                new Map<Id, NormalizedDateAssignment>();

        if (normalizedAssignments != null) {
            for (
                NormalizedAssignment normalizedAssignment :
                normalizedAssignments
            ) {
                if (normalizedAssignment == null) {
                    continue;
                }

                if (
                    normalizedAssignment.assignedPersonId != null
                ) {
                    requestedAssignmentByParentId.put(
                        normalizedAssignment.assignedPersonId,
                        normalizedAssignment
                    );
                }

                for (
                    NormalizedDateAssignment dateAssignment :
                    normalizedAssignment.dateAssignments
                ) {
                    if (
                        dateAssignment != null &&
                        dateAssignment.dateRecordId != null
                    ) {
                        requestedDateById.put(
                            dateAssignment.dateRecordId,
                            dateAssignment
                        );
                    }
                }
            }
        }

        if (existingDateRecords == null) {
            return;
        }

        for (
            Form_Activity_Assigned_Persons_Date__c
                existingDateRecord :
            existingDateRecords
        ) {
            if (
                !isCurrentManageDateRecord(
                    existingDateRecord
                ) ||
                !isManageDateRecordLocked(
                    existingDateRecord
                )
            ) {
                continue;
            }

            Date lockedDate =
                existingDateRecord.Target_Date__c;

            if (
                lockedDate != null &&
                (
                    lockedDate < request.activityDate ||
                    lockedDate > request.activityEndDate
                )
            ) {
                throw new AuraHandledException(
                    'Activity Start / End Date cannot exclude locked Target Date ' +
                    String.valueOf(lockedDate) +
                    '. Pending or approved date assignments must remain inside the activity period.'
                );
            }

            Id parentId =
                existingDateRecord
                    .Form_Activity_Assigned_Persons__c;

            Form_Activity_Assigned_Persons__c
                existingParent =
                    existingAssignedPersonMap.get(
                        parentId
                    );

            NormalizedAssignment
                requestedAssignment =
                    requestedAssignmentByParentId.get(
                        parentId
                    );

            String dateLabel =
                String.valueOf(
                    existingDateRecord.Target_Date__c
                );

            if (
                existingParent == null ||
                requestedAssignment == null
            ) {
                throw new AuraHandledException(
                    'The Sales Executive assignment for locked Target Date ' +
                    dateLabel +
                    ' cannot be removed while it is pending for approval or already approved.'
                );
            }

            if (
                requestedAssignment.executiveId !=
                    existingParent.Sales_Executives__c
            ) {
                throw new AuraHandledException(
                    'The Sales Executive cannot be changed for locked Target Date ' +
                    dateLabel +
                    '.'
                );
            }

            if (
                normalizeManageTextKey(
                    requestedAssignment.teamName
                ) !=
                normalizeManageTextKey(
                    existingParent.Team_Name__c
                )
            ) {
                throw new AuraHandledException(
                    'The Team cannot be changed for a Sales Executive that has locked Target Date ' +
                    dateLabel +
                    '.'
                );
            }

            NormalizedDateAssignment
                requestedDate =
                    requestedDateById.get(
                        existingDateRecord.Id
                    );

            if (requestedDate == null) {
                throw new AuraHandledException(
                    'Locked Target Date ' +
                    dateLabel +
                    ' cannot be removed while it is pending for approval or already approved.'
                );
            }

            if (
                requestedDate.targetDate !=
                    existingDateRecord.Target_Date__c
            ) {
                throw new AuraHandledException(
                    'Locked Target Date ' +
                    dateLabel +
                    ' cannot be changed.'
                );
            }

            if (
                normalizeManageLocationKey(
                    requestedDate.activityLocation
                ) !=
                normalizeManageLocationKey(
                    existingDateRecord.Activity_Location__c
                )
            ) {
                throw new AuraHandledException(
                    'Activity Location cannot be changed for locked Target Date ' +
                    dateLabel +
                    '.'
                );
            }
        }
    }


    private static Boolean isCurrentManageDateRecord(
        Form_Activity_Assigned_Persons_Date__c dateRecord
    ) {
        if (dateRecord == null) {
            return false;
        }

        String assignmentStatus =
            dateRecord.Assignment_Status__c;

        if (
            assignmentStatus ==
                Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_DROPPED ||
            assignmentStatus ==
                Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_REPLACED ||
            assignmentStatus ==
                Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_RESCHEDULED
        ) {
            return false;
        }

        if (dateRecord.Is_Active__c == true) {
            return true;
        }

        /*
         * Legacy records created before Is_Active__c /
         * Assignment_Status__c were introduced are still
         * considered current when both values are blank.
         */
        return
            dateRecord.Is_Active__c == null &&
            String.isBlank(assignmentStatus);
    }

    private static String normalizeActivityLocation(
        String activityLocation
    ) {
        return String.isBlank(activityLocation)
            ? null
            : activityLocation.trim().toUpperCase();
    }

    private static Boolean sameStoredActivityLocation(
        String storedLocation,
        String normalizedLocation
    ) {
        if (
            storedLocation == null &&
            normalizedLocation == null
        ) {
            return true;
        }

        if (
            storedLocation == null ||
            normalizedLocation == null
        ) {
            return false;
        }

        return storedLocation.equals(
            normalizedLocation
        );
    }


    private static String normalizeManageLocationKey(
        String activityLocation
    ) {
        return String.isBlank(activityLocation)
            ? ''
            : activityLocation.trim().toLowerCase();
    }

    private static String buildManageTeamDateKey(
        String teamName,
        Date targetDate
    ) {
        return (
            String.isBlank(teamName)
                ? ''
                : teamName.trim().toLowerCase()
        ) +
        '||' +
        String.valueOf(targetDate);
    }

    private static void validateSharedDateLocations(
        List<NormalizedAssignment> normalizedAssignments,
        Form_Activity__c activityRecord,
        List<Form_Activity_Assigned_Persons_Date__c>
            existingDateRecords
    ) {
        Map<String, Set<String>> existingLocationsByGroupKey =
            new Map<String, Set<String>>();

        if (existingDateRecords != null) {
            for (
                Form_Activity_Assigned_Persons_Date__c existingDateRecord :
                existingDateRecords
            ) {
                if (!isCurrentManageDateRecord(existingDateRecord)) {
                    continue;
                }

                String existingTeamName =
                    existingDateRecord
                        .Form_Activity_Assigned_Persons__r == null
                        ? null
                        : existingDateRecord
                            .Form_Activity_Assigned_Persons__r
                            .Team_Name__c;

                String existingGroupKey =
                    buildManageTeamDateKey(
                        existingTeamName,
                        existingDateRecord.Target_Date__c
                    );

                if (
                    !existingLocationsByGroupKey.containsKey(
                        existingGroupKey
                    )
                ) {
                    existingLocationsByGroupKey.put(
                        existingGroupKey,
                        new Set<String>()
                    );
                }

                existingLocationsByGroupKey
                    .get(existingGroupKey)
                    .add(
                        normalizeManageLocationKey(
                            existingDateRecord.Activity_Location__c
                        )
                    );
            }
        }

        Map<String, Set<String>> requestedLocationsByGroupKey =
            new Map<String, Set<String>>();

        Map<String, String> displayTeamByGroupKey =
            new Map<String, String>();

        Map<String, Date> displayDateByGroupKey =
            new Map<String, Date>();

        if (normalizedAssignments != null) {
            for (
                NormalizedAssignment normalizedAssignment :
                normalizedAssignments
            ) {
                if (normalizedAssignment == null) {
                    continue;
                }

                for (
                    NormalizedDateAssignment dateAssignment :
                    normalizedAssignment.dateAssignments
                ) {
                    String groupKey =
                        buildManageTeamDateKey(
                            normalizedAssignment.teamName,
                            dateAssignment.targetDate
                        );

                    if (
                        !requestedLocationsByGroupKey.containsKey(
                            groupKey
                        )
                    ) {
                        requestedLocationsByGroupKey.put(
                            groupKey,
                            new Set<String>()
                        );
                    }

                    requestedLocationsByGroupKey
                        .get(groupKey)
                        .add(
                            normalizeManageLocationKey(
                                dateAssignment.activityLocation
                            )
                        );

                    displayTeamByGroupKey.put(
                        groupKey,
                        normalizedAssignment.teamName
                    );

                    displayDateByGroupKey.put(
                        groupKey,
                        dateAssignment.targetDate
                    );
                }
            }
        }

        String storeName =
            activityRecord != null &&
            activityRecord.Assigned_Store__r != null
                ? activityRecord.Assigned_Store__r.Name
                : (
                    activityRecord != null
                        ? String.valueOf(
                            activityRecord.Assigned_Store__c
                        )
                        : ''
                );

        for (String groupKey : requestedLocationsByGroupKey.keySet()) {
            Set<String> requestedLocations =
                requestedLocationsByGroupKey.get(groupKey);

            if (
                requestedLocations == null ||
                requestedLocations.size() <= 1
            ) {
                continue;
            }

            Set<String> existingLocations =
                existingLocationsByGroupKey.get(groupKey);

            /*
             * Normal planning still enforces one location for
             * Store + Team + Date.
             *
             * Exception: Postpone/Prepone may legitimately create
             * multiple location-wise execution groups on the same
             * Team + Date. If that split already exists in current
             * data, Manage Activity preserves it instead of merging
             * the locations back together.
             */
            if (
                existingLocations == null ||
                existingLocations.size() <= 1 ||
                requestedLocations.size() >
                    existingLocations.size()
            ) {
                throw new AuraHandledException(
                    'Activity Location must be the same for Store ' +
                    storeName +
                    ', Team ' +
                    displayTeamByGroupKey.get(groupKey) +
                    ' and Target Date ' +
                    String.valueOf(
                        displayDateByGroupKey.get(groupKey)
                    ) +
                    '. Multiple locations for the same Team and date can only be preserved when they already exist from Postpone/Prepone processing.'
                );
            }
        }
    }


    private static void validateActivityInputs(
        ActivityUpdateRequest request
    ) {
        if (String.isBlank(request.activityName)) {
            throw new AuraHandledException(
                'Please enter Activity Name.'
            );
        }

        if (request.activityDate == null) {
            throw new AuraHandledException(
                'Please enter Activity Start Date.'
            );
        }

        if (request.activityEndDate == null) {
            throw new AuraHandledException(
                'Please enter Activity End Date.'
            );
        }

        if (
            request.activityEndDate <
            request.activityDate
        ) {
            throw new AuraHandledException(
                'Activity End Date cannot be before Activity Start Date.'
            );
        }
    }

    private static Set<String> getValidTeamNames() {
        Set<String> teamNames =
            new Set<String>();

        for (Team__mdt teamRecord : [
            SELECT Team_Name__c
            FROM Team__mdt
        ]) {
            if (
                String.isNotBlank(
                    teamRecord.Team_Name__c
                )
            ) {
                teamNames.add(
                    teamRecord.Team_Name__c.trim()
                );
            }
        }

        return teamNames;
    }

    public class FormActivityOptionWrapper {
        @AuraEnabled public Id value;
        @AuraEnabled public String label;
        @AuraEnabled public String activityNumber;
        @AuraEnabled public String storeName;
        @AuraEnabled public Date activityDate;

        public FormActivityOptionWrapper(
            Id value,
            String label,
            String activityNumber,
            String storeName,
            Date activityDate
        ) {
            this.value = value;
            this.label = label;
            this.activityNumber = activityNumber;
            this.storeName = storeName;
            this.activityDate = activityDate;
        }
    }

    public class ActivityEditWrapper {
        @AuraEnabled public Id formActivityId;
        @AuraEnabled public String activityNumber;
        @AuraEnabled public Id finalCustomizeFormId;
        @AuraEnabled public Id storeId;
        @AuraEnabled public String storeName;
        @AuraEnabled public String activityName;
        @AuraEnabled public Date activityDate;
        @AuraEnabled public Date activityEndDate;
        @AuraEnabled public List<AssignmentDetailWrapper> assignments;
        @AuraEnabled public Boolean isEditLocked;
        @AuraEnabled public String editLockMessage;
        @AuraEnabled public Boolean isReturnedForCorrection;
        @AuraEnabled public Boolean hasLockedAssignments;

        public ActivityEditWrapper(
            Id formActivityId,
            String activityNumber,
            Id finalCustomizeFormId,
            Id storeId,
            String storeName,
            String activityName,
            Date activityDate,
            Date activityEndDate,
            List<AssignmentDetailWrapper> assignments,
            Boolean isEditLocked,
            String editLockMessage,
            Boolean isReturnedForCorrection,
            Boolean hasLockedAssignments
        ) {
            this.formActivityId = formActivityId;
            this.activityNumber = activityNumber;
            this.finalCustomizeFormId =
                finalCustomizeFormId;
            this.storeId = storeId;
            this.storeName = storeName;
            this.activityName = activityName;
            this.activityDate = activityDate;
            this.activityEndDate = activityEndDate;
            this.assignments = assignments;
            this.isEditLocked = isEditLocked == true;
            this.editLockMessage = editLockMessage;
            this.isReturnedForCorrection =
                isReturnedForCorrection == true;
            this.hasLockedAssignments =
                hasLockedAssignments == true;
        }
    }

    public class AssignmentDetailWrapper {
        @AuraEnabled public Id assignedPersonId;
        @AuraEnabled public Id salesExecutiveId;
        @AuraEnabled public String salesExecutiveName;
        @AuraEnabled public String teamName;
        @AuraEnabled public List<DateAssignmentDetailWrapper> dateAssignments;

        public AssignmentDetailWrapper(
            Id assignedPersonId,
            Id salesExecutiveId,
            String salesExecutiveName,
            String teamName,
            List<DateAssignmentDetailWrapper> dateAssignments
        ) {
            this.assignedPersonId =
                assignedPersonId;
            this.salesExecutiveId =
                salesExecutiveId;
            this.salesExecutiveName =
                salesExecutiveName;
            this.teamName = teamName;
            this.dateAssignments =
                dateAssignments;
        }
    }

    public class DateAssignmentDetailWrapper {
        @AuraEnabled public Id assignedPersonDateId;
        @AuraEnabled public Date targetDate;
        @AuraEnabled public String activityLocation;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public Boolean approvalLocked;
        @AuraEnabled public Boolean isEditLocked;
        @AuraEnabled public String lockMessage;

        public DateAssignmentDetailWrapper(
            Id assignedPersonDateId,
            Date targetDate,
            String activityLocation,
            String approvalStatus,
            Boolean approvalLocked,
            Boolean isEditLocked,
            String lockMessage
        ) {
            this.assignedPersonDateId =
                assignedPersonDateId;
            this.targetDate = targetDate;
            this.activityLocation =
                activityLocation;
            this.approvalStatus =
                approvalStatus;
            this.approvalLocked =
                approvalLocked == true;
            this.isEditLocked =
                isEditLocked == true;
            this.lockMessage =
                lockMessage;
        }
    }

    public class ActivityUpdateRequest {
        @AuraEnabled public Id formActivityId {
            get;
            set;
        }

        @AuraEnabled public String activityName {
            get;
            set;
        }

        @AuraEnabled public Date activityDate {
            get;
            set;
        }

        @AuraEnabled public Date activityEndDate {
            get;
            set;
        }

        @AuraEnabled public List<AssignmentUpdateWrapper> assignments {
            get;
            set;
        }
    }

    public class AssignmentUpdateWrapper {
        @AuraEnabled public Id assignedPersonId {
            get;
            set;
        }

        @AuraEnabled public Id salesExecutiveId {
            get;
            set;
        }

        @AuraEnabled public String teamName {
            get;
            set;
        }

        @AuraEnabled public List<DateAssignmentUpdateWrapper> dateAssignments {
            get;
            set;
        }
    }

    public class DateAssignmentUpdateWrapper {
        @AuraEnabled public Id assignedPersonDateId {
            get;
            set;
        }

        @AuraEnabled public String targetDate {
            get;
            set;
        }

        @AuraEnabled public String activityLocation {
            get;
            set;
        }
    }

    private class NormalizedAssignment {
        private Id assignedPersonId;
        private Id executiveId;
        private String teamName;
        private List<NormalizedDateAssignment> dateAssignments;

        private NormalizedAssignment(
            Id assignedPersonId,
            Id executiveId,
            String teamName,
            List<NormalizedDateAssignment> dateAssignments
        ) {
            this.assignedPersonId =
                assignedPersonId;
            this.executiveId = executiveId;
            this.teamName = teamName;
            this.dateAssignments =
                dateAssignments;
        }
    }

    private class NormalizedDateAssignment {
        private Id dateRecordId;
        private Date targetDate;
        private String activityLocation;

        private NormalizedDateAssignment(
            Id dateRecordId,
            Date targetDate,
            String activityLocation
        ) {
            this.dateRecordId = dateRecordId;
            this.targetDate = targetDate;
            this.activityLocation =
                activityLocation;
        }
    }
}