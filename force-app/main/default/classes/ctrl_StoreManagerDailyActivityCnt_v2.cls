public with sharing class ctrl_StoreManagerDailyActivityCnt_v2 {

    private static final String SYSTEM_ADMIN_PROFILE =
        'System Administrator';

    private static final String STATUS_PENDING =
        'Pending Initiation';

    private static final String STATUS_LIVE =
        'Live';

    private static final String STATUS_IN_PROGRESS =
        'In Progress';

    private static final String STATUS_COMPLETED =
        'Completed';

    private static final String STATUS_EXPIRED =
        'Expired';

    private static final String NO_TEAM_KEY =
        'NO_TEAM';

    private static final String NO_LOCATION_KEY =
        'NO_LOCATION';

    private static final String APPROVAL_TYPE_BTL_FORM_ACTIVITY =
        'BTL Form Activity';

    private static final String APPROVAL_STATUS_NOT_SUBMITTED =
        'Not Submitted';

    private static final String APPROVAL_STATUS_APPROVED =
        'Approved';

    private static final String APPROVAL_STATUS_DROPPED =
        'Dropped';

    private static final String ASSIGNMENT_STATUS_ACTIVE =
        'Active';

    private static final String ASSIGNMENT_STATUS_REPLACED =
        'Replaced';

    private static final String ASSIGNMENT_STATUS_DROPPED =
        'Dropped';

    private static final String ASSIGNMENT_STATUS_RESCHEDULED =
        'Rescheduled';

    private static final String ACTION_RESCHEDULED =
        'Rescheduled';

    private static final String ACTION_ACTIVITY_DROPPED =
        'Activity Dropped';

    private static final String STATUS_PENDING_APPROVAL =
        'Pending For Approval';

    @AuraEnabled
    public static DashboardResponse getDashboard(
        Date selectedDate,
        Id selectedStoreId
    ) {
        if (selectedDate == null) {
            selectedDate = Date.today();
        }

        AccessContext accessContext = getAccessContext();

        Id effectiveStoreId;

        if (accessContext.isSystemAdministrator) {
            effectiveStoreId = selectedStoreId;

            if (effectiveStoreId != null) {
                validateStoreExists(effectiveStoreId);
            }
        } else {
            effectiveStoreId = accessContext.storeId;
        }

        DashboardResponse response = new DashboardResponse();
        response.selectedDate = selectedDate;
        response.refreshedAt = System.now();
        response.isSystemAdministrator =
            accessContext.isSystemAdministrator;
        response.selectedStoreId = effectiveStoreId;
        response.storeOptions = getStoreOptions(accessContext);
        response.activities = new List<ActivityRow>();

        List<Form_Activity__c> activityRecords;

        if (effectiveStoreId == null) {
            activityRecords = [
                SELECT Id,
                       Name,
                       Activity_Name__c,
                       Activity_Date__c,
                       Activity_End_Date__c,
                       Activity_Location__c,
                       Assigned_Store__c,
                       Assigned_Store__r.Name,
                       Final_Customize_Form__c,
                       Final_Customize_Form__r.Name
                FROM Form_Activity__c
                WHERE Activity_Date__c <= :selectedDate
                AND Activity_End_Date__c >= :selectedDate
                ORDER BY Assigned_Store__r.Name,
                         Activity_Name__c,
                         Name
                LIMIT 2000
            ];
        } else {
            activityRecords = [
                SELECT Id,
                       Name,
                       Activity_Name__c,
                       Activity_Date__c,
                       Activity_End_Date__c,
                       Activity_Location__c,
                       Assigned_Store__c,
                       Assigned_Store__r.Name,
                       Final_Customize_Form__c,
                       Final_Customize_Form__r.Name
                FROM Form_Activity__c
                WHERE Activity_Date__c <= :selectedDate
                AND Activity_End_Date__c >= :selectedDate
                AND Assigned_Store__c = :effectiveStoreId
                ORDER BY Activity_Name__c, Name
                LIMIT 2000
            ];
        }

        if (activityRecords.isEmpty()) {
            return response;
        }

        Set<Id> activityIds = new Set<Id>();

        for (Form_Activity__c activity : activityRecords) {
            activityIds.add(activity.Id);
        }

        Map<String, List<MemberRow>> membersByGroupKey =
            new Map<String, List<MemberRow>>();

        Map<Id, Set<String>> teamKeysByActivityId =
            new Map<Id, Set<String>>();

        /*
         * Team identity remains part of the Store Manager
         * activity grain. Activity Location is added as the
         * next grouping dimension:
         *
         * Form Activity + Selected Date + Team + Location.
         */
        Map<String, Set<String>>
            locationKeysByActivityTeamGroupKey =
                new Map<String, Set<String>>();

        Map<String, String> teamNameByGroupKey =
            new Map<String, String>();

        Map<String, String> locationNameByGroupKey =
            new Map<String, String>();

        Map<String, Set<Id>> executionIdsByGroupKey =
            new Map<String, Set<Id>>();

        Map<String, Boolean> approvalLockedByGroupKey =
            new Map<String, Boolean>();

        Map<String, Integer> totalAssignmentsByGroupKey =
            new Map<String, Integer>();

        Map<String, Integer> activeAssignmentsByGroupKey =
            new Map<String, Integer>();

        Map<String, Integer> approvedAssignmentsByGroupKey =
            new Map<String, Integer>();

        Map<Id, Integer> activeAssignmentsByActivityId =
            new Map<Id, Integer>();

        Map<Id, Integer> approvedAssignmentsByActivityId =
            new Map<Id, Integer>();

        for (
            Form_Activity_Assigned_Persons_Date__c dateAssignment : [
                SELECT Id,
                       Target_Date__c,
                       Actual_Date__c,
                       Activity_Location__c,
                       Form_Activity_Daily_Execution__c,
                       Actual_Executive__c,
                       Actual_Executive__r.Name,
                       Active_For_Date__c,
                       Is_Active__c,
                       Assignment_Status__c,
                       Replacement_Of__c,
                       Approval_Status__c,
                       Approval_Locked__c,
                       Present__c,
                       Attendance_Date_Time__c,
                       Form_Activity_Assigned_Persons__c,
                       Form_Activity_Assigned_Persons__r.Form_Activity__c,
                       Form_Activity_Assigned_Persons__r.Person_Name__c,
                       Form_Activity_Assigned_Persons__r.Team_Name__c,
                       Form_Activity_Assigned_Persons__r.Sales_Executives__c,
                       Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Form_Activity_Assigned_Persons__r.Form_Activity__c
                    IN :activityIds
                AND Target_Date__c = :selectedDate
                ORDER BY
                    Form_Activity_Assigned_Persons__r.Team_Name__c,
                    Activity_Location__c,
                    Form_Activity_Assigned_Persons__r.Person_Name__c
            ]
        ) {
            Id activityId =
                dateAssignment
                    .Form_Activity_Assigned_Persons__r
                    .Form_Activity__c;

            String teamName = cleanTeamName(
                dateAssignment
                    .Form_Activity_Assigned_Persons__r
                    .Team_Name__c
            );

            String teamKey = buildTeamKey(teamName);

            String activityTeamGroupKey =
                buildActivityTeamGroupKey(
                    activityId,
                    teamKey
                );

            String locationName =
                cleanLocation(
                    dateAssignment.Activity_Location__c
                );

            String locationKey =
                buildLocationKey(locationName);

            String groupKey =
                buildActivityTeamLocationGroupKey(
                    activityId,
                    teamKey,
                    locationKey
                );

            if (!teamKeysByActivityId.containsKey(activityId)) {
                teamKeysByActivityId.put(
                    activityId,
                    new Set<String>()
                );
            }

            teamKeysByActivityId.get(activityId).add(teamKey);

            teamNameByGroupKey.put(
                activityTeamGroupKey,
                teamName
            );

            if (
                !locationKeysByActivityTeamGroupKey
                    .containsKey(activityTeamGroupKey)
            ) {
                locationKeysByActivityTeamGroupKey.put(
                    activityTeamGroupKey,
                    new Set<String>()
                );
            }

            locationKeysByActivityTeamGroupKey
                .get(activityTeamGroupKey)
                .add(locationKey);

            locationNameByGroupKey.put(
                groupKey,
                locationName
            );

            incrementGroupCount(
                totalAssignmentsByGroupKey,
                groupKey
            );

            if (!isOperationalAssignment(dateAssignment)) {
                continue;
            }

            incrementGroupCount(
                activeAssignmentsByGroupKey,
                groupKey
            );

            incrementActivityCount(
                activeAssignmentsByActivityId,
                activityId
            );

            if (
                dateAssignment.Approval_Status__c ==
                    APPROVAL_STATUS_APPROVED
            ) {
                incrementGroupCount(
                    approvedAssignmentsByGroupKey,
                    groupKey
                );

                incrementActivityCount(
                    approvedAssignmentsByActivityId,
                    activityId
                );
            }

            if (!membersByGroupKey.containsKey(groupKey)) {
                membersByGroupKey.put(
                    groupKey,
                    new List<MemberRow>()
                );
            }

            MemberRow member = new MemberRow();
            member.dateAssignmentId = dateAssignment.Id;
            member.assignedPersonId =
                dateAssignment
                    .Form_Activity_Assigned_Persons__c;

            member.assignedExecutiveId =
                dateAssignment
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__c;

            member.assignedExecutiveName =
                dateAssignment
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__r == null
                ? dateAssignment
                    .Form_Activity_Assigned_Persons__r
                    .Person_Name__c
                : dateAssignment
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__r.Name;

            member.actualExecutiveId =
                dateAssignment.Actual_Executive__c;

            member.actualExecutiveName =
                dateAssignment.Actual_Executive__r == null
                ? null
                : dateAssignment.Actual_Executive__r.Name;

            member.displayExecutiveId =
                member.actualExecutiveId == null
                ? member.assignedExecutiveId
                : member.actualExecutiveId;

            member.displayExecutiveName =
                String.isBlank(member.actualExecutiveName)
                ? member.assignedExecutiveName
                : member.actualExecutiveName;

            member.teamName = teamName;
            member.activityLocation =
                dateAssignment.Activity_Location__c;
            member.activeForDate =
                dateAssignment.Active_For_Date__c;
            member.isReplacement =
                dateAssignment.Replacement_Of__c != null;
            member.approvalStatus =
                dateAssignment.Approval_Status__c;
            member.approvalLocked =
                dateAssignment.Approval_Locked__c;
            member.present = dateAssignment.Present__c;

            if (dateAssignment.Approval_Locked__c == true) {
                approvalLockedByGroupKey.put(
                    groupKey,
                    true
                );
            }

            membersByGroupKey.get(groupKey).add(member);

            if (
                dateAssignment.Form_Activity_Daily_Execution__c
                    != null
            ) {
                if (
                    !executionIdsByGroupKey.containsKey(
                        groupKey
                    )
                ) {
                    executionIdsByGroupKey.put(
                        groupKey,
                        new Set<Id>()
                    );
                }

                executionIdsByGroupKey
                    .get(groupKey)
                    .add(
                        dateAssignment
                            .Form_Activity_Daily_Execution__c
                    );
            }
        }

        Map<Id, Form_Activity_Daily_Execution__c>
            executionById =
                new Map<Id, Form_Activity_Daily_Execution__c>();

        Map<String, Form_Activity_Daily_Execution__c>
            executionByExecutionKey =
                new Map<String, Form_Activity_Daily_Execution__c>();

        for (
            Form_Activity_Daily_Execution__c execution : [
                SELECT Id,
                       Name,
                       Form_Activity__c,
                       Activity_Date__c,
                       Store__c,
                       Status__c,
                       Execution_Key__c,
                       Store_Manager_Approved__c,
                       BTL_Activity_Live__c,
                       BTL_Initiated_Date_Time__c,
                       BTL_Initiated_By__c,
                       BTL_Initiated_By__r.Name,
                       Start_Date_Time__c,
                       Completed_Date_Time__c
                FROM Form_Activity_Daily_Execution__c
                WHERE Form_Activity__c IN :activityIds
                AND Activity_Date__c = :selectedDate
            ]
        ) {
            executionById.put(execution.Id, execution);

            if (!String.isBlank(execution.Execution_Key__c)) {
                executionByExecutionKey.put(
                    execution.Execution_Key__c,
                    execution
                );
            }
        }

        for (Form_Activity__c activity : activityRecords) {
            Set<String> teamKeys =
                teamKeysByActivityId.get(activity.Id);

            if (teamKeys == null || teamKeys.isEmpty()) {
                teamKeys = new Set<String>{
                    NO_TEAM_KEY
                };

                String noTeamGroupKey =
                    buildActivityTeamGroupKey(
                        activity.Id,
                        NO_TEAM_KEY
                    );

                teamNameByGroupKey.put(
                    noTeamGroupKey,
                    null
                );

                locationKeysByActivityTeamGroupKey.put(
                    noTeamGroupKey,
                    new Set<String>{
                        NO_LOCATION_KEY
                    }
                );

                locationNameByGroupKey.put(
                    buildActivityTeamLocationGroupKey(
                        activity.Id,
                        NO_TEAM_KEY,
                        NO_LOCATION_KEY
                    ),
                    null
                );
            }

            List<String> sortedTeamKeys =
                getSortedTeamKeys(
                    activity.Id,
                    teamKeys,
                    teamNameByGroupKey
                );

            for (String teamKey : sortedTeamKeys) {
                String activityTeamGroupKey =
                    buildActivityTeamGroupKey(
                        activity.Id,
                        teamKey
                    );

                String teamName =
                    teamNameByGroupKey.get(
                        activityTeamGroupKey
                    );

                Set<String> locationKeys =
                    locationKeysByActivityTeamGroupKey.get(
                        activityTeamGroupKey
                    );

                if (
                    locationKeys == null ||
                    locationKeys.isEmpty()
                ) {
                    locationKeys = new Set<String>{
                        NO_LOCATION_KEY
                    };

                    locationNameByGroupKey.put(
                        buildActivityTeamLocationGroupKey(
                            activity.Id,
                            teamKey,
                            NO_LOCATION_KEY
                        ),
                        null
                    );
                }

                List<String> sortedLocationKeys =
                    getSortedLocationKeys(
                        activity.Id,
                        teamKey,
                        locationKeys,
                        locationNameByGroupKey
                    );

                for (
                    String locationKey :
                        sortedLocationKeys
                ) {
                    String groupKey =
                        buildActivityTeamLocationGroupKey(
                            activity.Id,
                            teamKey,
                            locationKey
                        );

                    ActivityRow row = new ActivityRow();

                    row.rowKey = groupKey;
                    row.teamKey = teamKey;
                    row.teamName = teamName;
                    row.hasTeam =
                        !String.isBlank(teamName);
                    row.locationKey = locationKey;
                    row.activityId = activity.Id;
                    row.activityNo = activity.Name;
                    row.activityName =
                        String.isBlank(
                            activity.Activity_Name__c
                        )
                        ? activity.Name
                        : activity.Activity_Name__c;

                    row.startDate =
                        activity.Activity_Date__c;
                    row.endDate =
                        activity.Activity_End_Date__c;
                    row.activityLocation =
                        locationNameByGroupKey.get(
                            groupKey
                        );

                    row.storeId =
                        activity.Assigned_Store__c;
                    row.storeName =
                        activity.Assigned_Store__r == null
                        ? ''
                        : activity
                            .Assigned_Store__r.Name;

                    row.finalCustomizeFormId =
                        activity.Final_Customize_Form__c;

                    row.finalCustomizeFormName =
                        activity
                            .Final_Customize_Form__r ==
                                null
                        ? ''
                        : activity
                            .Final_Customize_Form__r
                            .Name;

                    Integer totalAssignmentCount =
                        getGroupCount(
                            totalAssignmentsByGroupKey,
                            groupKey
                        );

                    Integer activeAssignmentCount =
                        getGroupCount(
                            activeAssignmentsByGroupKey,
                            groupKey
                        );

                    if (
                        totalAssignmentCount > 0 &&
                        activeAssignmentCount == 0
                    ) {
                        continue;
                    }

                    Integer approvedAssignmentCount =
                        getGroupCount(
                            approvedAssignmentsByGroupKey,
                            groupKey
                        );

                    row.approvalApproved =
                        activeAssignmentCount > 0 &&
                        approvedAssignmentCount ==
                            activeAssignmentCount;

                    row.approvalStatus =
                        row.approvalApproved
                        ? APPROVAL_STATUS_APPROVED
                        : STATUS_PENDING_APPROVAL;

                    Integer activityActiveAssignmentCount =
                        getActivityCount(
                            activeAssignmentsByActivityId,
                            activity.Id
                        );

                    Integer activityApprovedAssignmentCount =
                        getActivityCount(
                            approvedAssignmentsByActivityId,
                            activity.Id
                        );

                    row.activityFullyApproved =
                        activityActiveAssignmentCount > 0 &&
                        activityApprovedAssignmentCount ==
                            activityActiveAssignmentCount;

                    row.members =
                        membersByGroupKey.containsKey(
                            groupKey
                        )
                        ? membersByGroupKey.get(groupKey)
                        : new List<MemberRow>();

                    row.assignedExecutiveCount =
                        row.members.size();

                    String expectedExecutionKey =
                        buildExecutionKey(
                            activity.Id,
                            selectedDate,
                            teamKey,
                            locationKey
                        );

                    Form_Activity_Daily_Execution__c
                        execution =
                            getExecutionForGroup(
                                groupKey,
                                expectedExecutionKey,
                                executionIdsByGroupKey,
                                executionById,
                                executionByExecutionKey
                            );

                    if (execution == null) {
                        row.status =
                            selectedDate < Date.today()
                            ? STATUS_EXPIRED
                            : STATUS_PENDING;

                        row.storeManagerApproved = false;
                        row.btlActivityLive = false;
                    } else {
                        row.dailyExecutionId =
                            execution.Id;
                        row.status =
                            execution.Status__c;
                        row.storeManagerApproved =
                            execution
                                .Store_Manager_Approved__c;
                        row.btlActivityLive =
                            execution.BTL_Activity_Live__c;
                        row.initiatedDateTime =
                            execution
                                .BTL_Initiated_Date_Time__c;
                        row.initiatedByName =
                            execution
                                .BTL_Initiated_By__r ==
                                    null
                            ? ''
                            : execution
                                .BTL_Initiated_By__r
                                .Name;
                        row.startDateTime =
                            execution.Start_Date_Time__c;
                        row.completedDateTime =
                            execution
                                .Completed_Date_Time__c;

                        if (
                            selectedDate < Date.today() &&
                            row.status != STATUS_COMPLETED
                        ) {
                            row.status = STATUS_EXPIRED;
                        }
                    }

                    row.approvalLocked =
                        approvalLockedByGroupKey
                            .containsKey(groupKey) &&
                        approvalLockedByGroupKey
                            .get(groupKey) == true;

                    Boolean executionAlreadyStarted =
                        row.status == STATUS_LIVE ||
                        row.status ==
                            STATUS_IN_PROGRESS ||
                        row.status ==
                            STATUS_COMPLETED;

                    if (
                        !row.approvalApproved &&
                        !executionAlreadyStarted
                    ) {
                        row.status =
                            STATUS_PENDING_APPROVAL;
                    }

                    row.canInitiate =
                        row.approvalApproved &&
                        selectedDate == Date.today() &&
                        row.status == STATUS_PENDING &&
                        !row.btlActivityLive;

                    Boolean
                        scheduleManagementAvailable =
                            row.approvalApproved &&
                            selectedDate >= Date.today() &&
                            row.status ==
                                STATUS_PENDING &&
                            !row.btlActivityLive;

                    row.canReschedule =
                        scheduleManagementAvailable;

                    row.canDrop =
                        scheduleManagementAvailable;

                    if (row.status == STATUS_PENDING) {
                        response.pendingInitiation++;
                    } else if (
                        row.status == STATUS_LIVE
                    ) {
                        response.liveActivities++;
                    } else if (
                        row.status == STATUS_IN_PROGRESS
                    ) {
                        response.inProgressActivities++;
                    } else if (
                        row.status == STATUS_COMPLETED
                    ) {
                        response.completedActivities++;
                    }

                    response.activities.add(row);
                }
            }
        }

        response.totalActivities =
            response.activities.size();

        return response;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getSalesExecutives(
        Id storeId,
        Id activityId,
        Date selectedDate,
        String teamKey
    ) {
        if (storeId == null) {
            return new List<OptionWrapper>();
        }

        validateStoreExists(storeId);

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        Set<Id> executiveIdsInOtherTeams =
            getExecutiveIdsAssignedToOtherTeams(
                activityId,
                selectedDate,
                effectiveTeamKey
            );

        Set<Id> executiveIdsInCurrentTeam =
            getExecutiveIdsAssignedToTeam(
                activityId,
                selectedDate,
                effectiveTeamKey
            );

        List<OptionWrapper> results =
            new List<OptionWrapper>();

        for (
            Sales_Executives__c executive : [
                SELECT Id, Name
                FROM Sales_Executives__c
                WHERE Store__c = :storeId
                ORDER BY Name
                LIMIT 1000
            ]
        ) {
            if (
                executiveIdsInOtherTeams.contains(
                    executive.Id
                ) &&
                !executiveIdsInCurrentTeam.contains(
                    executive.Id
                )
            ) {
                continue;
            }

            results.add(
                new OptionWrapper(
                    executive.Name,
                    String.valueOf(executive.Id)
                )
            );
        }

        return results;
    }

    @AuraEnabled
    public static Id initiateWithoutChanges(
        Id activityId,
        Date selectedDate,
        String teamKey
    ) {
        return initiateWithoutChangesInternal(
            activityId,
            selectedDate,
            teamKey,
            null
        );
    }

    @AuraEnabled
    public static Id initiateWithoutChangesByLocation(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey
    ) {
        return initiateWithoutChangesInternal(
            activityId,
            selectedDate,
            teamKey,
            locationKey
        );
    }

    private static Id initiateWithoutChangesInternal(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey
    ) {
        validateInitiationInput(
            activityId,
            selectedDate
        );

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        Form_Activity__c activity =
            getActivityForInitiation(
                activityId,
                selectedDate
            );

        List<Form_Activity_Assigned_Persons_Date__c>
            dateAssignments =
                getDateAssignmentsForUpdate(
                    activityId,
                    selectedDate,
                    effectiveTeamKey,
                    locationKey
                );

        if (dateAssignments.isEmpty()) {
            throw new AuraHandledException(
                'No Sales Executives are assigned for the selected team and date.'
            );
        }

        validateAssignmentsApprovedForStoreAction(
            dateAssignments
        );

        Form_Activity_Daily_Execution__c execution =
            getOrCreateDailyExecution(
                activity,
                selectedDate,
                effectiveTeamKey,
                locationKey
            );

        validateExecutionNotAlreadyInitiated(execution);

        Boolean hasSavedApprovedComposition = false;

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            if (
                dateAssignment.Active_For_Date__c == true ||
                dateAssignment.Actual_Executive__c != null
            ) {
                hasSavedApprovedComposition = true;
                break;
            }
        }

        Set<Id> usedExecutiveIds = new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            Boolean isActive =
                hasSavedApprovedComposition
                    ? dateAssignment.Active_For_Date__c == true
                    : true;

            Id assignedExecutiveId =
                dateAssignment
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__c;

            Id effectiveExecutiveId =
                isActive
                    ? (
                        dateAssignment.Actual_Executive__c != null
                            ? dateAssignment.Actual_Executive__c
                            : assignedExecutiveId
                    )
                    : null;

            if (
                isActive &&
                effectiveExecutiveId == null
            ) {
                throw new AuraHandledException(
                    'A predefined Sales Executive is missing for one or more active assignments.'
                );
            }

            if (
                isActive &&
                usedExecutiveIds.contains(
                    effectiveExecutiveId
                )
            ) {
                throw new AuraHandledException(
                    'The same Sales Executive cannot be assigned more than once within the selected team.'
                );
            }

            if (isActive) {
                usedExecutiveIds.add(
                    effectiveExecutiveId
                );
            }

            dateAssignment.Form_Activity_Daily_Execution__c =
                execution.Id;

            dateAssignment.Actual_Executive__c =
                effectiveExecutiveId;

            dateAssignment.Active_For_Date__c =
                isActive;

            dateAssignment.Present__c = false;
            dateAssignment.Actual_Date__c = null;
            dateAssignment.Attendance_Date_Time__c =
                null;
            dateAssignment.Attendance_Marked_By__c =
                null;
        }

        if (usedExecutiveIds.isEmpty()) {
            throw new AuraHandledException(
                'No approved active manpower composition was found for initiation.'
            );
        }

        validateNoCrossTeamExecutiveAssignments(
            activityId,
            selectedDate,
            effectiveTeamKey,
            usedExecutiveIds
        );

        update dateAssignments;

        activateExecution(execution);
        updateParentInitiationSnapshot(
            activity,
            selectedDate
        );

        return execution.Id;
    }

    @AuraEnabled
    public static Id initiateWithChanges(
        Id activityId,
        Date selectedDate,
        String teamKey,
        List<ExecutiveChangeInput> executiveChanges
    ) {
        validateInitiationInput(
            activityId,
            selectedDate
        );

        if (
            executiveChanges == null ||
            executiveChanges.isEmpty()
        ) {
            throw new AuraHandledException(
                'Executive assignment details are required.'
            );
        }

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        Form_Activity__c activity =
            getActivityForInitiation(
                activityId,
                selectedDate
            );

        List<Form_Activity_Assigned_Persons_Date__c>
            dateAssignments =
                getDateAssignmentsForUpdate(
                    activityId,
                    selectedDate,
                    effectiveTeamKey
                );

        if (dateAssignments.isEmpty()) {
            throw new AuraHandledException(
                'No Sales Executives are assigned for the selected team and date.'
            );
        }

        validateAssignmentsApprovedForStoreAction(
            dateAssignments
        );

        Set<Id> validDateAssignmentIds = new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            validDateAssignmentIds.add(
                dateAssignment.Id
            );
        }

        Map<Id, ExecutiveChangeInput> changeByDateRowId =
            new Map<Id, ExecutiveChangeInput>();

        Set<Id> selectedExecutiveIds = new Set<Id>();

        for (ExecutiveChangeInput input : executiveChanges) {
            if (
                input == null ||
                input.dateAssignmentId == null
            ) {
                continue;
            }

            if (
                !validDateAssignmentIds.contains(
                    input.dateAssignmentId
                )
            ) {
                throw new AuraHandledException(
                    'One or more executive assignment rows do not belong to the selected team.'
                );
            }

            changeByDateRowId.put(
                input.dateAssignmentId,
                input
            );

            if (
                input.activeForDate == true &&
                input.actualExecutiveId != null
            ) {
                selectedExecutiveIds.add(
                    input.actualExecutiveId
                );
            }
        }

        if (selectedExecutiveIds.isEmpty()) {
            throw new AuraHandledException(
                'Please select at least one active Sales Executive.'
            );
        }

        validateNoCrossTeamExecutiveAssignments(
            activityId,
            selectedDate,
            effectiveTeamKey,
            selectedExecutiveIds
        );

        Set<Id> validExecutiveIds = new Set<Id>();

        for (
            Sales_Executives__c executive : [
                SELECT Id
                FROM Sales_Executives__c
                WHERE Id IN :selectedExecutiveIds
                AND Store__c = :activity.Assigned_Store__c
            ]
        ) {
            validExecutiveIds.add(executive.Id);
        }

        if (
            validExecutiveIds.size() !=
            selectedExecutiveIds.size()
        ) {
            throw new AuraHandledException(
                'One or more selected Sales Executives do not belong to this store.'
            );
        }

        Form_Activity_Daily_Execution__c execution =
            getOrCreateDailyExecution(
                activity,
                selectedDate,
                effectiveTeamKey
            );

        validateExecutionNotAlreadyInitiated(execution);

        Integer activeMemberCount = 0;
        Set<Id> usedExecutiveIds = new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            ExecutiveChangeInput input =
                changeByDateRowId.get(
                    dateAssignment.Id
                );

            if (input == null) {
                dateAssignment.Active_For_Date__c =
                    false;
                dateAssignment.Actual_Executive__c =
                    null;
            } else {
                Boolean isActive =
                    input.activeForDate == true;

                if (
                    isActive &&
                    input.actualExecutiveId == null
                ) {
                    throw new AuraHandledException(
                        'Please select an executive for every active row.'
                    );
                }

                if (
                    isActive &&
                    usedExecutiveIds.contains(
                        input.actualExecutiveId
                    )
                ) {
                    throw new AuraHandledException(
                        'The same Sales Executive cannot be assigned more than once within the selected team.'
                    );
                }

                dateAssignment.Active_For_Date__c =
                    isActive;

                dateAssignment.Actual_Executive__c =
                    isActive
                    ? input.actualExecutiveId
                    : null;

                if (isActive) {
                    activeMemberCount++;
                    usedExecutiveIds.add(
                        input.actualExecutiveId
                    );
                }
            }

            dateAssignment.Form_Activity_Daily_Execution__c =
                execution.Id;
            dateAssignment.Present__c = false;
            dateAssignment.Actual_Date__c = null;
            dateAssignment.Attendance_Date_Time__c =
                null;
            dateAssignment.Attendance_Marked_By__c =
                null;
        }

        if (activeMemberCount == 0) {
            throw new AuraHandledException(
                'Please keep at least one Sales Executive active for the selected team.'
            );
        }

        update dateAssignments;

        activateExecution(execution);
        updateParentInitiationSnapshot(
            activity,
            selectedDate
        );

        return execution.Id;
    }


    @AuraEnabled
    public static SaveApprovalResponse saveAndSendForApproval(
        Id activityId,
        Date selectedDate,
        String teamKey,
        List<ExecutiveChangeInput> executiveChanges
    ) {
        return saveAndSendForApprovalInternal(
            activityId,
            selectedDate,
            teamKey,
            null,
            executiveChanges
        );
    }

    @AuraEnabled
    public static SaveApprovalResponse saveAndSendForApprovalByLocation(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey,
        List<ExecutiveChangeInput> executiveChanges
    ) {
        return saveAndSendForApprovalInternal(
            activityId,
            selectedDate,
            teamKey,
            locationKey,
            executiveChanges
        );
    }

    private static SaveApprovalResponse saveAndSendForApprovalInternal(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey,
        List<ExecutiveChangeInput> executiveChanges
    ) {
        validateInitiationInput(
            activityId,
            selectedDate
        );

        if (
            executiveChanges == null ||
            executiveChanges.isEmpty()
        ) {
            throw new AuraHandledException(
                'Executive assignment details are required.'
            );
        }

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        Form_Activity__c activity =
            getActivityForInitiation(
                activityId,
                selectedDate
            );

        if (activity.Assigned_Store__c == null) {
            throw new AuraHandledException(
                'A Store must be assigned to the Form Activity.'
            );
        }

        List<Form_Activity_Assigned_Persons_Date__c>
            dateAssignments =
                getDateAssignmentsForUpdate(
                    activityId,
                    selectedDate,
                    effectiveTeamKey,
                    locationKey
                );

        if (dateAssignments.isEmpty()) {
            throw new AuraHandledException(
                'No Sales Executives are assigned for the selected team and date.'
            );
        }

        validateAssignmentsApprovedForStoreAction(
            dateAssignments
        );

        String effectiveTeamName =
            cleanTeamName(
                dateAssignments[0]
                    .Form_Activity_Assigned_Persons__r
                    .Team_Name__c
            );

        Map<Id, Form_Activity_Assigned_Persons_Date__c>
            dateAssignmentById =
                new Map<
                    Id,
                    Form_Activity_Assigned_Persons_Date__c
                >();

        Map<String, String> allowedLocationByKey =
            new Map<String, String>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            dateAssignmentById.put(
                dateAssignment.Id,
                dateAssignment
            );

            String location =
                cleanLocation(
                    dateAssignment.Activity_Location__c
                );

            if (!String.isBlank(location)) {
                allowedLocationByKey.put(
                    normalizeLocationKey(location),
                    location
                );
            }
        }

        Map<Id, ExecutiveChangeInput>
            existingInputByDateAssignmentId =
                new Map<Id, ExecutiveChangeInput>();

        List<ExecutiveChangeInput> newInputs =
            new List<ExecutiveChangeInput>();

        for (ExecutiveChangeInput input : executiveChanges) {
            if (input == null) {
                continue;
            }

            Boolean isNewInput =
                input.isNew == true ||
                input.dateAssignmentId == null;

            if (isNewInput) {
                if (input.actualExecutiveId == null) {
                    throw new AuraHandledException(
                        'Please select an executive for every additional row.'
                    );
                }

                validateRequestedLocation(
                    input.activityLocation,
                    allowedLocationByKey
                );

                newInputs.add(input);
                continue;
            }

            if (
                !dateAssignmentById.containsKey(
                    input.dateAssignmentId
                )
            ) {
                throw new AuraHandledException(
                    'One or more executive assignment rows do not belong to the selected team.'
                );
            }

            if (
                existingInputByDateAssignmentId.containsKey(
                    input.dateAssignmentId
                )
            ) {
                throw new AuraHandledException(
                    'The same executive assignment row was submitted more than once.'
                );
            }

            Boolean isActive =
                input.activeForDate == true;

            if (
                isActive &&
                input.actualExecutiveId == null
            ) {
                throw new AuraHandledException(
                    'Please select an executive for every active row.'
                );
            }

            if (isActive) {
                validateRequestedLocation(
                    input.activityLocation,
                    allowedLocationByKey
                );
            }

            existingInputByDateAssignmentId.put(
                input.dateAssignmentId,
                input
            );
        }

        Set<Id> finalActiveExecutiveIds =
            new Set<Id>();

        Set<String> finalExecutiveLocationKeys =
            new Set<String>();

        Integer finalActiveCount = 0;

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            ExecutiveChangeInput input =
                existingInputByDateAssignmentId.get(
                    dateAssignment.Id
                );

            Boolean isActive =
                input == null
                ? dateAssignment.Active_For_Date__c
                : input.activeForDate == true;

            Id executiveId;

            if (input == null) {
                executiveId =
                    dateAssignment.Actual_Executive__c == null
                    ? dateAssignment
                        .Form_Activity_Assigned_Persons__r
                        .Sales_Executives__c
                    : dateAssignment.Actual_Executive__c;
            } else {
                executiveId =
                    isActive
                    ? input.actualExecutiveId
                    : null;
            }

            if (!isActive) {
                continue;
            }

            if (executiveId == null) {
                throw new AuraHandledException(
                    'Please select an executive for every active row.'
                );
            }

            String effectiveLocation =
                input == null
                    ? dateAssignment.Activity_Location__c
                    : input.activityLocation;

            String executiveLocationKey =
                buildExecutiveLocationKey(
                    executiveId,
                    effectiveLocation
                );

            if (
                !finalExecutiveLocationKeys.add(
                    executiveLocationKey
                )
            ) {
                throw new AuraHandledException(
                    'The same Sales Executive cannot be selected more than once for the same Activity Location within the selected Team.'
                );
            }

            finalActiveExecutiveIds.add(
                executiveId
            );

            finalActiveCount++;
        }

        for (ExecutiveChangeInput input : newInputs) {
            String executiveLocationKey =
                buildExecutiveLocationKey(
                    input.actualExecutiveId,
                    input.activityLocation
                );

            if (
                !finalExecutiveLocationKeys.add(
                    executiveLocationKey
                )
            ) {
                throw new AuraHandledException(
                    'The same Sales Executive cannot be selected more than once for the same Activity Location within the selected Team.'
                );
            }

            finalActiveExecutiveIds.add(
                input.actualExecutiveId
            );

            finalActiveCount++;
        }

        if (finalActiveCount == 0) {
            throw new AuraHandledException(
                'Please keep at least one Sales Executive active for the selected team.'
            );
        }

        validateNoCrossTeamExecutiveAssignments(
            activityId,
            selectedDate,
            effectiveTeamKey,
            finalActiveExecutiveIds
        );

        Set<Id> validExecutiveIds =
            new Set<Id>();

        for (
            Sales_Executives__c executive : [
                SELECT Id
                FROM Sales_Executives__c
                WHERE Id IN :finalActiveExecutiveIds
                AND Store__c = :activity.Assigned_Store__c
            ]
        ) {
            validExecutiveIds.add(executive.Id);
        }

        if (
            validExecutiveIds.size() !=
            finalActiveExecutiveIds.size()
        ) {
            throw new AuraHandledException(
                'One or more selected Sales Executives do not belong to this store.'
            );
        }

        List<Form_Activity_Assigned_Persons_Date__c>
            changedDateAssignments =
                new List<
                    Form_Activity_Assigned_Persons_Date__c
                >();

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            ExecutiveChangeInput input =
                existingInputByDateAssignmentId.get(
                    dateAssignment.Id
                );

            if (input == null) {
                continue;
            }

            Boolean requestedActive =
                input.activeForDate == true;

            Id requestedExecutiveId =
                requestedActive
                ? input.actualExecutiveId
                : null;

            String requestedLocation =
                requestedActive
                ? cleanLocation(input.activityLocation)
                : dateAssignment.Activity_Location__c;

            Boolean hasChanged =
                dateAssignment.Active_For_Date__c !=
                    requestedActive ||
                dateAssignment.Actual_Executive__c !=
                    requestedExecutiveId ||
                normalizeLocationKey(
                    dateAssignment.Activity_Location__c
                ) !=
                normalizeLocationKey(
                    requestedLocation
                );

            if (!hasChanged) {
                continue;
            }

            dateAssignment.Active_For_Date__c =
                requestedActive;

            dateAssignment.Actual_Executive__c =
                requestedExecutiveId;

            if (requestedActive) {
                dateAssignment.Activity_Location__c =
                    requestedLocation;
            }

            changedDateAssignments.add(
                dateAssignment
            );
        }

        if (
            changedDateAssignments.isEmpty() &&
            newInputs.isEmpty()
        ) {
            throw new AuraHandledException(
                'No executive or location changes were found.'
            );
        }

        if (!changedDateAssignments.isEmpty()) {
            update changedDateAssignments;
        }

        List<Form_Activity_Assigned_Persons__c>
            newAssignedPersons =
                new List<
                    Form_Activity_Assigned_Persons__c
                >();

        for (ExecutiveChangeInput input : newInputs) {
            newAssignedPersons.add(
                new Form_Activity_Assigned_Persons__c(
                    Form_Activity__c =
                        activity.Id,
                    Store__c =
                        activity.Assigned_Store__c,
                    Team_Name__c =
                        effectiveTeamName,
                    Sales_Executives__c =
                        input.actualExecutiveId,
                    Is_Active__c =
                        true
                )
            );
        }

        if (!newAssignedPersons.isEmpty()) {
            insert newAssignedPersons;
        }

        List<Form_Activity_Assigned_Persons_Date__c>
            newDateAssignments =
                new List<
                    Form_Activity_Assigned_Persons_Date__c
                >();

        for (
            Integer index = 0;
            index < newInputs.size();
            index++
        ) {
            ExecutiveChangeInput input =
                newInputs[index];

            newDateAssignments.add(
                new Form_Activity_Assigned_Persons_Date__c(
                    Form_Activity_Assigned_Persons__c =
                        newAssignedPersons[index].Id,
                    Target_Date__c =
                        selectedDate,
                    Activity_Location__c =
                        cleanLocation(
                            input.activityLocation
                        ),
                    Store__c =
                        activity.Assigned_Store__c,
                    Actual_Executive__c =
                        input.actualExecutiveId,
                    Active_For_Date__c =
                        true,
                    Is_Active__c =
                        true,
                    Assignment_Status__c =
                        ASSIGNMENT_STATUS_ACTIVE,
                    Approval_Status__c =
                        APPROVAL_STATUS_NOT_SUBMITTED,
                    Approval_Locked__c =
                        false
                )
            );
        }

        if (!newDateAssignments.isEmpty()) {
            insert newDateAssignments;
        }

        Set<Id> finalActiveDateAssignmentIds =
            new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            ExecutiveChangeInput input =
                existingInputByDateAssignmentId.get(
                    dateAssignment.Id
                );

            Boolean isActive =
                input == null
                    ? dateAssignment.Active_For_Date__c
                    : input.activeForDate == true;

            if (isActive) {
                finalActiveDateAssignmentIds.add(
                    dateAssignment.Id
                );
            }
        }

        for (
            Form_Activity_Assigned_Persons_Date__c
                newDateAssignment : newDateAssignments
        ) {
            finalActiveDateAssignmentIds.add(
                newDateAssignment.Id
            );
        }

        Map<String, Object> approvalResult =
            Ctrl_BTLApprovalSubmission.submitRevisedRecords(
                new List<Id>(
                    finalActiveDateAssignmentIds
                ),
                'Store Manager Initiate With Changes'
            );

        SaveApprovalResponse response =
            new SaveApprovalResponse();

        response.updatedExecutiveRecords =
            changedDateAssignments.size();

        response.createdExecutiveRecords =
            newAssignedPersons.size();

        response.taggedApprovalRecords =
            approvalResult == null ||
            approvalResult.get('processedCount') == null
                ? 0
                : Integer.valueOf(
                    String.valueOf(
                        approvalResult.get(
                            'processedCount'
                        )
                    )
                );

        response.message =
            'Executive changes were saved and the complete active composition was sent for custom BTL approval.';

        return response;
    }


    @AuraEnabled
    public static ScheduleActionResponse rescheduleActivity(
        Id activityId,
        Date currentDate,
        Date newDate,
        String teamKey,
        String reason,
        Boolean executeAction
    ) {
        return rescheduleActivityInternal(
            activityId,
            currentDate,
            newDate,
            teamKey,
            null,
            reason,
            executeAction
        );
    }

    @AuraEnabled
    public static ScheduleActionResponse rescheduleActivityByLocation(
        Id activityId,
        Date currentDate,
        Date newDate,
        String teamKey,
        String locationKey,
        String reason,
        Boolean executeAction
    ) {
        return rescheduleActivityInternal(
            activityId,
            currentDate,
            newDate,
            teamKey,
            locationKey,
            reason,
            executeAction
        );
    }

    private static ScheduleActionResponse rescheduleActivityInternal(
        Id activityId,
        Date currentDate,
        Date newDate,
        String teamKey,
        String locationKey,
        String reason,
        Boolean executeAction
    ) {
        validateScheduleActionInput(
            activityId,
            currentDate,
            reason
        );

        if (newDate == null) {
            throw new AuraHandledException(
                'Please select the new activity date.'
            );
        }

        if (newDate < Date.today()) {
            throw new AuraHandledException(
                'The new activity date cannot be before today.'
            );
        }

        if (newDate == currentDate) {
            throw new AuraHandledException(
                'The new activity date must be different from the current activity date.'
            );
        }

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        Form_Activity__c activity =
            getActivityForScheduleManagement(
                activityId,
                currentDate
            );

        if (
            activity.Activity_Date__c != null &&
            newDate < activity.Activity_Date__c
        ) {
            throw new AuraHandledException(
                'The new activity date cannot be before the Form Activity start date.'
            );
        }

        if (
            activity.Activity_End_Date__c != null &&
            newDate > activity.Activity_End_Date__c
        ) {
            throw new AuraHandledException(
                'The new activity date cannot be after the Form Activity end date.'
            );
        }

        List<Form_Activity_Assigned_Persons_Date__c>
            currentAssignments =
                getActivityDateAssignmentsForManagement(
                    activityId,
                    currentDate,
                    effectiveTeamKey,
                    locationKey
                );

        validateAssignmentsApprovedForStoreAction(
            currentAssignments
        );

        validateAssignmentsNotInitiated(
            currentAssignments
        );

        /*
         * If the destination already contains another Activity
         * Location for the same Team/date, do NOT block the
         * reschedule. Return a warning so the Store Manager can
         * consciously Continue or Cancel from the LWC.
         */
        String locationWarning =
            getRescheduleDestinationLocationWarning(
                activityId,
                newDate,
                effectiveTeamKey,
                currentAssignments
            );

        List<ScheduleConflictRow> conflicts =
            getScheduleConflicts(
                currentAssignments,
                newDate
            );

        if (executeAction != true) {
            ScheduleActionResponse previewResponse =
                new ScheduleActionResponse();

            previewResponse.processedRecords = 0;
            previewResponse.newActivityDate = newDate;
            previewResponse.actionType =
                newDate > currentDate
                    ? 'Postponed'
                    : 'Preponed';
            previewResponse.conflicts = conflicts;
            previewResponse.locationWarning =
                locationWarning;
            previewResponse.message =
                conflicts.isEmpty()
                ? 'No executive scheduling conflict was found.'
                : String.valueOf(conflicts.size()) +
                    ' executive scheduling conflict(s) were found.';

            return previewResponse;
        }

        Set<Id> currentDateRecordIds = new Set<Id>();
        Set<Id> assignedPersonIds = new Set<Id>();
        Datetime actionDateTime = System.now();
        String cleanedReason = reason.trim();

        for (
            Form_Activity_Assigned_Persons_Date__c
                currentAssignment : currentAssignments
        ) {
            currentDateRecordIds.add(
                currentAssignment.Id
            );

            assignedPersonIds.add(
                currentAssignment
                    .Form_Activity_Assigned_Persons__c
            );
        }

        Map<Id, Tagged_Approval_Hierarchy__c>
            oldTransactionByDateId =
                getSingleTransactionByDateId(
                    currentDateRecordIds
                );

        if (
            oldTransactionByDateId.size() !=
                currentDateRecordIds.size()
        ) {
            throw new AuraHandledException(
                'An approved transaction could not be found for one or more activity assignments.'
            );
        }

        List<Form_Activity_Assigned_Persons_Date__c>
            newDateAssignments =
                new List<
                    Form_Activity_Assigned_Persons_Date__c
                >();

        List<Tagged_Approval_Hierarchy__c>
            oldTransactionsToUpdate =
                new List<Tagged_Approval_Hierarchy__c>();

        List<Approval_Action_History__c>
            oldHistoryRecords =
                new List<Approval_Action_History__c>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                currentAssignment : currentAssignments
        ) {
            Decimal previousCycle =
                currentAssignment.Reschedule_Cycle__c == null
                    ? 0
                    : currentAssignment.Reschedule_Cycle__c;

            currentAssignment.Is_Active__c = false;
            currentAssignment.Active_For_Date__c = false;
            currentAssignment.Assignment_Status__c =
                ASSIGNMENT_STATUS_RESCHEDULED;
            currentAssignment.Approval_Locked__c = true;
            currentAssignment.Rescheduled_By__c =
                UserInfo.getUserId();
            currentAssignment.Rescheduled_Date_Time__c =
                actionDateTime;
            currentAssignment.Reschedule_Reason__c =
                cleanedReason;

            newDateAssignments.add(
                new Form_Activity_Assigned_Persons_Date__c(
                    Form_Activity_Assigned_Persons__c =
                        currentAssignment
                            .Form_Activity_Assigned_Persons__c,
                    Target_Date__c = newDate,
                    Activity_Location__c =
                        currentAssignment
                            .Activity_Location__c,
                    Store__c =
                        currentAssignment.Store__c,
                    Actual_Executive__c =
                        currentAssignment.Actual_Executive__c,
                    Active_For_Date__c = true,
                    Is_Active__c = true,
                    Assignment_Status__c =
                        ASSIGNMENT_STATUS_ACTIVE,
                    Approval_Status__c =
                        APPROVAL_STATUS_NOT_SUBMITTED,
                    Approval_Locked__c = false,
                    Rescheduled_From__c =
                        currentAssignment.Id,
                    Rescheduled_By__c =
                        UserInfo.getUserId(),
                    Rescheduled_Date_Time__c =
                        actionDateTime,
                    Reschedule_Reason__c =
                        cleanedReason,
                    Reschedule_Cycle__c =
                        previousCycle + 1
                )
            );

            Tagged_Approval_Hierarchy__c oldTransaction =
                oldTransactionByDateId.get(
                    currentAssignment.Id
                );

            String previousApprovalStatus =
                oldTransaction.Approval_Status__c;

            oldTransaction.Last_Action__c =
                ACTION_RESCHEDULED;
            oldTransaction.Last_Action_By__c =
                UserInfo.getUserId();
            oldTransaction.Last_Action_Date_Time__c =
                actionDateTime;
            oldTransaction.Last_Action_Comments__c =
                buildRescheduleComments(
                    currentDate,
                    newDate,
                    cleanedReason
                );

            oldTransactionsToUpdate.add(
                oldTransaction
            );

            oldHistoryRecords.add(
                new Approval_Action_History__c(
                    Approval_Transaction__c =
                        oldTransaction.Id,
                    Approval_Level__c =
                        oldTransaction
                            .Current_Approval_Level__c,
                    Action__c =
                        ACTION_RESCHEDULED,
                    Action_By__c =
                        UserInfo.getUserId(),
                    Action_Date_Time__c =
                        actionDateTime,
                    Comments__c =
                        buildRescheduleComments(
                            currentDate,
                            newDate,
                            cleanedReason
                        ),
                    Previous_Status__c =
                        previousApprovalStatus,
                    New_Status__c =
                        previousApprovalStatus,
                    Submission_Cycle__c =
                        oldTransaction
                            .Submission_Cycle__c
                )
            );
        }

        update currentAssignments;
        insert newDateAssignments;
        update oldTransactionsToUpdate;
        insert oldHistoryRecords;

        List<Form_Activity_Assigned_Persons__c>
            parentsToReactivate =
                new List<
                    Form_Activity_Assigned_Persons__c
                >();

        for (Id assignedPersonId : assignedPersonIds) {
            parentsToReactivate.add(
                new Form_Activity_Assigned_Persons__c(
                    Id = assignedPersonId,
                    Is_Active__c = true
                )
            );
        }

        if (!parentsToReactivate.isEmpty()) {
            update parentsToReactivate;
        }

        List<Id> newDateAssignmentIds =
            new List<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                newDateAssignment : newDateAssignments
        ) {
            newDateAssignmentIds.add(
                newDateAssignment.Id
            );
        }

        Ctrl_BTLApprovalSubmission.submitSelectedRecords(
                newDateAssignmentIds,
                buildRescheduleComments(
                    currentDate,
                    newDate,
                    cleanedReason
                )
            );

        ScheduleActionResponse response =
            new ScheduleActionResponse();

        response.processedRecords =
            newDateAssignments.size();
        response.newActivityDate =
            newDate;
        response.actionType =
            newDate > currentDate
                ? 'Postponed'
                : 'Preponed';
        response.conflicts = conflicts;
        response.locationWarning =
            locationWarning;
        response.message =
            String.valueOf(
                newDateAssignments.size()
            ) +
            ' manpower assignment(s) for the selected Team were ' +
            response.actionType.toLowerCase() +
            ' and sent for approval.';

        return response;
    }

    @AuraEnabled
    public static ScheduleActionResponse dropActivity(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String reason
    ) {
        return dropActivityInternal(
            activityId,
            selectedDate,
            teamKey,
            null,
            reason
        );
    }

    @AuraEnabled
    public static ScheduleActionResponse dropActivityByLocation(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey,
        String reason
    ) {
        return dropActivityInternal(
            activityId,
            selectedDate,
            teamKey,
            locationKey,
            reason
        );
    }

    private static ScheduleActionResponse dropActivityInternal(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey,
        String reason
    ) {
        validateScheduleActionInput(
            activityId,
            selectedDate,
            reason
        );

        getActivityForScheduleManagement(
            activityId,
            selectedDate
        );

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        List<Form_Activity_Assigned_Persons_Date__c>
            currentAssignments =
                getActivityDateAssignmentsForManagement(
                    activityId,
                    selectedDate,
                    effectiveTeamKey,
                    locationKey
                );

        validateAssignmentsApprovedForStoreAction(
            currentAssignments
        );

        validateAssignmentsNotInitiated(
            currentAssignments
        );

        Set<Id> currentDateRecordIds = new Set<Id>();
        Set<Id> assignedPersonIds = new Set<Id>();
        Datetime actionDateTime = System.now();
        String cleanedReason = reason.trim();

        for (
            Form_Activity_Assigned_Persons_Date__c
                currentAssignment : currentAssignments
        ) {
            currentDateRecordIds.add(
                currentAssignment.Id
            );

            assignedPersonIds.add(
                currentAssignment
                    .Form_Activity_Assigned_Persons__c
            );
        }

        Map<Id, Tagged_Approval_Hierarchy__c>
            transactionByDateId =
                getSingleTransactionByDateId(
                    currentDateRecordIds
                );

        if (
            transactionByDateId.size() !=
                currentDateRecordIds.size()
        ) {
            throw new AuraHandledException(
                'An approved transaction could not be found for one or more activity assignments.'
            );
        }

        List<Tagged_Approval_Hierarchy__c>
            transactionsToUpdate =
                new List<Tagged_Approval_Hierarchy__c>();

        List<Approval_Action_History__c>
            historyRecords =
                new List<Approval_Action_History__c>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                currentAssignment : currentAssignments
        ) {
            currentAssignment.Is_Active__c = false;
            currentAssignment.Active_For_Date__c = false;
            currentAssignment.Assignment_Status__c =
                ASSIGNMENT_STATUS_DROPPED;
            currentAssignment.Approval_Status__c =
                APPROVAL_STATUS_DROPPED;
            currentAssignment.Approval_Locked__c = true;

            Tagged_Approval_Hierarchy__c transactionRecord =
                transactionByDateId.get(
                    currentAssignment.Id
                );

            String previousStatus =
                transactionRecord.Approval_Status__c;

            Id previousApprovalLevelId =
                transactionRecord
                    .Current_Approval_Level__c;

            transactionRecord.Approval_Status__c =
                APPROVAL_STATUS_DROPPED;
            transactionRecord.Current_Approval_Level__c =
                null;
            transactionRecord.Pending_With__c =
                null;
            transactionRecord.Last_Action__c =
                ACTION_ACTIVITY_DROPPED;
            transactionRecord.Last_Action_By__c =
                UserInfo.getUserId();
            transactionRecord.Last_Action_Date_Time__c =
                actionDateTime;
            transactionRecord.Last_Action_Comments__c =
                cleanedReason;
            transactionRecord.Dropped_By__c =
                UserInfo.getUserId();
            transactionRecord.Dropped_Date_Time__c =
                actionDateTime;
            transactionRecord.Drop_Reason__c =
                cleanedReason;

            transactionsToUpdate.add(
                transactionRecord
            );

            historyRecords.add(
                new Approval_Action_History__c(
                    Approval_Transaction__c =
                        transactionRecord.Id,
                    Approval_Level__c =
                        previousApprovalLevelId,
                    Action__c =
                        ACTION_ACTIVITY_DROPPED,
                    Action_By__c =
                        UserInfo.getUserId(),
                    Action_Date_Time__c =
                        actionDateTime,
                    Comments__c =
                        cleanedReason,
                    Previous_Status__c =
                        previousStatus,
                    New_Status__c =
                        APPROVAL_STATUS_DROPPED,
                    Submission_Cycle__c =
                        transactionRecord
                            .Submission_Cycle__c
                )
            );
        }

        update currentAssignments;
        update transactionsToUpdate;
        insert historyRecords;

        deactivateAssignedPersonsWithoutActiveDates(
            assignedPersonIds
        );

        ScheduleActionResponse response =
            new ScheduleActionResponse();

        response.processedRecords =
            currentAssignments.size();
        response.actionType =
            'Dropped';
        response.message =
            String.valueOf(
                currentAssignments.size()
            ) +
            ' manpower assignment(s) for the selected Team were dropped successfully.';

        return response;
    }

    private static List<ScheduleConflictRow>
        getScheduleConflicts(
            List<Form_Activity_Assigned_Persons_Date__c>
                movingAssignments,
            Date targetDate
        ) {
        List<ScheduleConflictRow> conflicts =
            new List<ScheduleConflictRow>();

        if (
            movingAssignments == null ||
            movingAssignments.isEmpty() ||
            targetDate == null
        ) {
            return conflicts;
        }

        Set<Id> movingExecutiveIds = new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c assignment :
                movingAssignments
        ) {
            Id executiveId =
                assignment.Actual_Executive__c != null
                ? assignment.Actual_Executive__c
                : assignment
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__c;

            if (executiveId != null) {
                movingExecutiveIds.add(executiveId);
            }
        }

        if (movingExecutiveIds.isEmpty()) {
            return conflicts;
        }

        Map<Id, Form_Activity_Assigned_Persons_Date__c>
            candidateById =
                new Map<Id, Form_Activity_Assigned_Persons_Date__c>();

        for (
            Form_Activity_Assigned_Persons_Date__c candidate : [
                SELECT Id,
                       Actual_Executive__c,
                       Actual_Executive__r.Name,
                       Active_For_Date__c,
                       Is_Active__c,
                       Assignment_Status__c,
                       Approval_Status__c,
                       Form_Activity_Assigned_Persons__r.Sales_Executives__c,
                       Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                       Form_Activity_Assigned_Persons__r.Team_Name__c,
                       Form_Activity_Assigned_Persons__r.Form_Activity__c,
                       Form_Activity_Assigned_Persons__r.Form_Activity__r.Name,
                       Form_Activity_Assigned_Persons__r.Form_Activity__r.Activity_Name__c
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Target_Date__c = :targetDate
                AND Active_For_Date__c = true
                AND Actual_Executive__c IN :movingExecutiveIds
            ]
        ) {
            candidateById.put(candidate.Id, candidate);
        }

        for (
            Form_Activity_Assigned_Persons_Date__c candidate : [
                SELECT Id,
                       Actual_Executive__c,
                       Actual_Executive__r.Name,
                       Active_For_Date__c,
                       Is_Active__c,
                       Assignment_Status__c,
                       Approval_Status__c,
                       Form_Activity_Assigned_Persons__r.Sales_Executives__c,
                       Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                       Form_Activity_Assigned_Persons__r.Team_Name__c,
                       Form_Activity_Assigned_Persons__r.Form_Activity__c,
                       Form_Activity_Assigned_Persons__r.Form_Activity__r.Name,
                       Form_Activity_Assigned_Persons__r.Form_Activity__r.Activity_Name__c
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Target_Date__c = :targetDate
                AND Active_For_Date__c = true
                AND Form_Activity_Assigned_Persons__r.Sales_Executives__c
                    IN :movingExecutiveIds
            ]
        ) {
            candidateById.put(candidate.Id, candidate);
        }

        Set<String> conflictKeys = new Set<String>();

        for (
            Form_Activity_Assigned_Persons_Date__c candidate :
                candidateById.values()
        ) {
            if (!isOperationalAssignment(candidate)) {
                continue;
            }

            Id effectiveExecutiveId =
                candidate.Actual_Executive__c != null
                ? candidate.Actual_Executive__c
                : candidate
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__c;

            if (
                effectiveExecutiveId == null ||
                !movingExecutiveIds.contains(effectiveExecutiveId)
            ) {
                continue;
            }

            Id existingActivityId =
                candidate
                    .Form_Activity_Assigned_Persons__r
                    .Form_Activity__c;

            String existingTeamName =
                cleanTeamName(
                    candidate
                        .Form_Activity_Assigned_Persons__r
                        .Team_Name__c
                );

            String conflictKey =
                String.valueOf(effectiveExecutiveId) +
                '|' +
                String.valueOf(existingActivityId) +
                '|' +
                buildTeamKey(existingTeamName);

            if (!conflictKeys.add(conflictKey)) {
                continue;
            }

            ScheduleConflictRow conflict =
                new ScheduleConflictRow();

            conflict.executiveId = effectiveExecutiveId;
            conflict.executiveName =
                candidate.Actual_Executive__c != null &&
                candidate.Actual_Executive__r != null
                ? candidate.Actual_Executive__r.Name
                : candidate
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__r == null
                    ? 'Sales Executive'
                    : candidate
                        .Form_Activity_Assigned_Persons__r
                        .Sales_Executives__r.Name;

            conflict.activityId = existingActivityId;

            Form_Activity__c existingActivity =
                candidate
                    .Form_Activity_Assigned_Persons__r
                    .Form_Activity__r;

            conflict.activityName =
                existingActivity == null
                ? 'Another Activity'
                : String.isBlank(
                    existingActivity.Activity_Name__c
                )
                    ? existingActivity.Name
                    : existingActivity.Activity_Name__c;

            conflict.teamName =
                String.isBlank(existingTeamName)
                ? 'No Team'
                : existingTeamName;

            conflicts.add(conflict);
        }

        return conflicts;
    }

    private static void validateScheduleActionInput(
        Id activityId,
        Date selectedDate,
        String reason
    ) {
        if (activityId == null || selectedDate == null) {
            throw new AuraHandledException(
                'Form Activity and activity date are required.'
            );
        }

        if (selectedDate < Date.today()) {
            throw new AuraHandledException(
                'A past activity is Date Over and cannot be rescheduled or dropped.'
            );
        }

        if (String.isBlank(reason)) {
            throw new AuraHandledException(
                'Reason is required.'
            );
        }
    }

    private static Form_Activity__c
        getActivityForScheduleManagement(
            Id activityId,
            Date selectedDate
        ) {
        Form_Activity__c activity = [
            SELECT Id,
                   Name,
                   Activity_Name__c,
                   Activity_Date__c,
                   Activity_End_Date__c,
                   Assigned_Store__c
            FROM Form_Activity__c
            WHERE Id = :activityId
            LIMIT 1
            FOR UPDATE
        ];

        AccessContext accessContext =
            getAccessContext();

        if (
            !accessContext.isSystemAdministrator &&
            activity.Assigned_Store__c !=
                accessContext.storeId
        ) {
            throw new AuraHandledException(
                'You do not have access to manage this store activity.'
            );
        }

        if (
            activity.Activity_End_Date__c != null &&
            selectedDate > activity.Activity_End_Date__c
        ) {
            throw new AuraHandledException(
                'The selected date is after the Form Activity end date.'
            );
        }

        return activity;
    }

    private static List<
        Form_Activity_Assigned_Persons_Date__c
    > getActivityDateAssignmentsForManagement(
        Id activityId,
        Date selectedDate,
        String teamKey
    ) {
        return getActivityDateAssignmentsForManagement(
            activityId,
            selectedDate,
            teamKey,
            null
        );
    }

    private static List<
        Form_Activity_Assigned_Persons_Date__c
    > getActivityDateAssignmentsForManagement(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey
    ) {
        List<Form_Activity_Assigned_Persons_Date__c>
            assignments =
                new List<
                    Form_Activity_Assigned_Persons_Date__c
                >();

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        String effectiveLocationKey =
            locationKey == null
                ? null
                : normalizeRequestedLocationKey(
                    locationKey
                );

        List<Form_Activity_Assigned_Persons_Date__c> queriedAssignments = [
            SELECT Id,
                   Name,
                   Target_Date__c,
                   Activity_Location__c,
                   Store__c,
                   Actual_Executive__c,
                   Active_For_Date__c,
                   Is_Active__c,
                   Assignment_Status__c,
                   Approval_Status__c,
                   Approval_Locked__c,
                   Rescheduled_From__c,
                   Rescheduled_By__c,
                   Rescheduled_Date_Time__c,
                   Reschedule_Reason__c,
                   Reschedule_Cycle__c,
                   Form_Activity_Daily_Execution__c,
                   Form_Activity_Daily_Execution__r.Status__c,
                   Form_Activity_Daily_Execution__r.Store_Manager_Approved__c,
                   Form_Activity_Daily_Execution__r.BTL_Activity_Live__c,
                   Form_Activity_Assigned_Persons__c,
                   Form_Activity_Assigned_Persons__r.Form_Activity__c,
                   Form_Activity_Assigned_Persons__r.Team_Name__c,
                   Form_Activity_Assigned_Persons__r.Sales_Executives__c
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Form_Activity_Assigned_Persons__r.Form_Activity__c
                = :activityId
            AND Target_Date__c = :selectedDate
            FOR UPDATE
        ];

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : queriedAssignments
        ) {
            String assignmentTeamKey =
                buildTeamKey(
                    dateAssignment
                        .Form_Activity_Assigned_Persons__r
                        .Team_Name__c
                );

            String assignmentLocationKey =
                buildLocationKey(
                    dateAssignment.Activity_Location__c
                );

            if (
                assignmentTeamKey == effectiveTeamKey &&
                (
                    effectiveLocationKey == null ||
                    assignmentLocationKey ==
                        effectiveLocationKey
                ) &&
                isOperationalAssignment(dateAssignment)
            ) {
                assignments.add(
                    dateAssignment
                );
            }
        }

        if (assignments.isEmpty()) {
            throw new AuraHandledException(
                'No active manpower assignments were found for the selected Team, Activity Location, and date.'
            );
        }

        return assignments;
    }

    private static String getRescheduleDestinationLocationWarning(
        Id activityId,
        Date newDate,
        String teamKey,
        List<Form_Activity_Assigned_Persons_Date__c>
            currentAssignments
    ) {
        if (
            activityId == null ||
            newDate == null ||
            currentAssignments == null ||
            currentAssignments.isEmpty()
        ) {
            return null;
        }

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        String requestedLocation =
            currentAssignments[0].Activity_Location__c;

        String requestedLocationKey =
            buildLocationKey(requestedLocation);

        Set<String> existingDifferentLocations =
            new Set<String>();

        List<Form_Activity_Assigned_Persons_Date__c> targetAssignments = [
            SELECT Id,
                   Activity_Location__c,
                   Is_Active__c,
                   Assignment_Status__c,
                   Approval_Status__c,
                   Form_Activity_Assigned_Persons__r.Team_Name__c
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Form_Activity_Assigned_Persons__r.Form_Activity__c
                = :activityId
            AND Target_Date__c = :newDate
            FOR UPDATE
        ];

        for (
            Form_Activity_Assigned_Persons_Date__c
                targetAssignment : targetAssignments
        ) {
            if (!isOperationalAssignment(targetAssignment)) {
                continue;
            }

            String targetTeamKey =
                buildTeamKey(
                    targetAssignment
                        .Form_Activity_Assigned_Persons__r
                        .Team_Name__c
                );

            if (targetTeamKey != effectiveTeamKey) {
                continue;
            }

            String targetLocationKey =
                buildLocationKey(
                    targetAssignment.Activity_Location__c
                );

            if (
                targetLocationKey ==
                    requestedLocationKey
            ) {
                continue;
            }

            existingDifferentLocations.add(
                String.isBlank(
                    targetAssignment.Activity_Location__c
                )
                    ? 'No Location'
                    : targetAssignment
                        .Activity_Location__c
                        .trim()
            );
        }

        if (existingDifferentLocations.isEmpty()) {
            return null;
        }

        List<String> locationNames =
            new List<String>();
        locationNames.addAll(
            existingDifferentLocations
        );
        locationNames.sort();

        String movingLocation =
            String.isBlank(requestedLocation)
                ? 'No Location'
                : requestedLocation.trim();

        return (
            'Warning: The selected Team already has Activity Location ' +
            (locationNames.size() == 1
                ? '"' + locationNames[0] + '"'
                : '"' + String.join(locationNames, '", "') + '"') +
            ' for ' +
            String.valueOf(newDate) +
            '. You are moving Activity Location "' +
            movingLocation +
            '" to the same Team and date. ' +
            'If you continue, both Activity Locations will remain as separate location-wise activity groups.'
        );
    }

    private static void validateAssignmentsNotInitiated(
        List<Form_Activity_Assigned_Persons_Date__c>
            dateAssignments
    ) {
        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            if (
                dateAssignment
                    .Form_Activity_Daily_Execution__c !=
                        null &&
                (
                    dateAssignment
                        .Form_Activity_Daily_Execution__r
                        .Store_Manager_Approved__c ==
                            true ||
                    dateAssignment
                        .Form_Activity_Daily_Execution__r
                        .BTL_Activity_Live__c ==
                            true ||
                    dateAssignment
                        .Form_Activity_Daily_Execution__r
                        .Status__c ==
                            STATUS_LIVE ||
                    dateAssignment
                        .Form_Activity_Daily_Execution__r
                        .Status__c ==
                            STATUS_IN_PROGRESS ||
                    dateAssignment
                        .Form_Activity_Daily_Execution__r
                        .Status__c ==
                            STATUS_COMPLETED
                )
            ) {
                throw new AuraHandledException(
                    'An activity that is already initiated, live, in progress, or completed cannot be rescheduled or dropped.'
                );
            }
        }
    }

    private static Map<Id, Tagged_Approval_Hierarchy__c>
        getSingleTransactionByDateId(
            Set<Id> dateAssignmentIds
        ) {
        Map<Id, Tagged_Approval_Hierarchy__c>
            transactionByDateId =
                new Map<
                    Id,
                    Tagged_Approval_Hierarchy__c
                >();

        List<Tagged_Approval_Hierarchy__c> transactions = [
            SELECT Id,
                   Approval_Status__c,
                   Current_Approval_Level__c,
                   Pending_With__c,
                   Submission_Cycle__c,
                   Last_Action__c,
                   Last_Action_By__c,
                   Last_Action_Date_Time__c,
                   Last_Action_Comments__c,
                   Dropped_By__c,
                   Dropped_Date_Time__c,
                   Drop_Reason__c,
                   Form_Activity_Assigned_Persons_Date__c
            FROM Tagged_Approval_Hierarchy__c
            WHERE Form_Activity_Assigned_Persons_Date__c
                IN :dateAssignmentIds
            FOR UPDATE
        ];

        for (
            Tagged_Approval_Hierarchy__c
                transactionRecord : transactions
        ) {
            Id dateRecordId =
                transactionRecord
                    .Form_Activity_Assigned_Persons_Date__c;

            if (
                transactionByDateId.containsKey(
                    dateRecordId
                )
            ) {
                throw new AuraHandledException(
                    'Multiple approval transactions exist for one or more activity assignments.'
                );
            }

            transactionByDateId.put(
                dateRecordId,
                transactionRecord
            );
        }

        return transactionByDateId;
    }

    private static void
        deactivateAssignedPersonsWithoutActiveDates(
            Set<Id> assignedPersonIds
        ) {
        if (
            assignedPersonIds == null ||
            assignedPersonIds.isEmpty()
        ) {
            return;
        }

        Set<Id> parentIdsWithActiveDates =
            new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                remainingDateRecord : [
                    SELECT Id,
                           Form_Activity_Assigned_Persons__c,
                           Is_Active__c,
                           Assignment_Status__c,
                           Approval_Status__c
                    FROM Form_Activity_Assigned_Persons_Date__c
                    WHERE Form_Activity_Assigned_Persons__c
                        IN :assignedPersonIds
                ]
        ) {
            if (
                isOperationalAssignment(
                    remainingDateRecord
                )
            ) {
                parentIdsWithActiveDates.add(
                    remainingDateRecord
                        .Form_Activity_Assigned_Persons__c
                );
            }
        }

        List<Form_Activity_Assigned_Persons__c>
            parentsToDeactivate =
                new List<
                    Form_Activity_Assigned_Persons__c
                >();

        for (Id assignedPersonId : assignedPersonIds) {
            if (
                !parentIdsWithActiveDates.contains(
                    assignedPersonId
                )
            ) {
                parentsToDeactivate.add(
                    new Form_Activity_Assigned_Persons__c(
                        Id = assignedPersonId,
                        Is_Active__c = false
                    )
                );
            }
        }

        if (!parentsToDeactivate.isEmpty()) {
            update parentsToDeactivate;
        }
    }

    private static String buildRescheduleComments(
        Date currentDate,
        Date newDate,
        String reason
    ) {
        String movementType =
            newDate > currentDate
                ? 'Postponed'
                : 'Preponed';

        return movementType +
            ' from ' +
            String.valueOf(currentDate) +
            ' to ' +
            String.valueOf(newDate) +
            '. Reason: ' +
            reason;
    }

    private static void validateRequestedLocation(
        String requestedLocation,
        Map<String, String> allowedLocationByKey
    ) {
        String cleanedLocation =
            cleanLocation(requestedLocation);

        if (String.isBlank(cleanedLocation)) {
            throw new AuraHandledException(
                'Please select an Activity Location for every active executive.'
            );
        }

        if (
            !allowedLocationByKey.containsKey(
                normalizeLocationKey(
                    cleanedLocation
                )
            )
        ) {
            throw new AuraHandledException(
                'The selected Activity Location is not available for this Team, Form Activity, and Date.'
            );
        }
    }

    private static String cleanLocation(
        String location
    ) {
        return String.isBlank(location)
            ? null
            : location.trim();
    }

    private static String normalizeLocationKey(
        String location
    ) {
        String cleanedLocation =
            cleanLocation(location);

        return String.isBlank(cleanedLocation)
            ? ''
            : cleanedLocation.toLowerCase();
    }

    private static String buildExecutiveLocationKey(
        Id executiveId,
        String activityLocation
    ) {
        return (
            executiveId == null
                ? ''
                : String.valueOf(executiveId)
        ) +
        '||' +
        normalizeLocationKey(
            activityLocation
        );
    }

    private static String buildLocationKey(
        String location
    ) {
        String normalizedLocation =
            normalizeLocationKey(location);

        if (String.isBlank(normalizedLocation)) {
            return NO_LOCATION_KEY;
        }

        Blob digest = Crypto.generateDigest(
            'SHA-256',
            Blob.valueOf(normalizedLocation)
        );

        return EncodingUtil.convertToHex(digest);
    }

    private static String normalizeRequestedLocationKey(
        String locationKey
    ) {
        return String.isBlank(locationKey)
            ? NO_LOCATION_KEY
            : locationKey.trim();
    }

    private static void validateInitiationInput(
        Id activityId,
        Date selectedDate
    ) {
        if (activityId == null || selectedDate == null) {
            throw new AuraHandledException(
                'Activity and date are required.'
            );
        }

        if (selectedDate != Date.today()) {
            throw new AuraHandledException(
                'An activity can be initiated only for today.'
            );
        }
    }

    private static Form_Activity__c
        getActivityForInitiation(
            Id activityId,
            Date selectedDate
        ) {
        Form_Activity__c activity = [
            SELECT Id,
                   Name,
                   Assigned_Store__c,
                   Activity_Date__c,
                   Activity_End_Date__c,
                   Store_Manager_Approved__c,
                   BTL_Activity_Live__c,
                   BTL_Live_Date__c,
                   BTL_Initiated_Date_Time__c,
                   BTL_Initiated_By__c
            FROM Form_Activity__c
            WHERE Id = :activityId
            LIMIT 1
            FOR UPDATE
        ];

        if (
            activity.Activity_Date__c == null ||
            activity.Activity_End_Date__c == null ||
            selectedDate < activity.Activity_Date__c ||
            selectedDate > activity.Activity_End_Date__c
        ) {
            throw new AuraHandledException(
                'The selected date is outside the activity duration.'
            );
        }

        AccessContext accessContext = getAccessContext();

        if (
            !accessContext.isSystemAdministrator &&
            activity.Assigned_Store__c !=
                accessContext.storeId
        ) {
            throw new AuraHandledException(
                'You do not have access to initiate this store activity.'
            );
        }

        return activity;
    }

    private static List<
        Form_Activity_Assigned_Persons_Date__c
    > getDateAssignmentsForUpdate(
        Id activityId,
        Date selectedDate,
        String teamKey
    ) {
        return getDateAssignmentsForUpdate(
            activityId,
            selectedDate,
            teamKey,
            null
        );
    }

    private static List<
        Form_Activity_Assigned_Persons_Date__c
    > getDateAssignmentsForUpdate(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey
    ) {
        List<Form_Activity_Assigned_Persons_Date__c>
            matchingAssignments =
                new List<Form_Activity_Assigned_Persons_Date__c>();

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        String effectiveLocationKey =
            locationKey == null
                ? null
                : normalizeRequestedLocationKey(
                    locationKey
                );

        List<Form_Activity_Assigned_Persons_Date__c> queriedAssignments = [
            SELECT Id,
                   Target_Date__c,
                   Actual_Date__c,
                   Activity_Location__c,
                   Form_Activity_Daily_Execution__c,
                   Actual_Executive__c,
                   Active_For_Date__c,
                   Is_Active__c,
                   Assignment_Status__c,
                   Approval_Status__c,
                   Approval_Locked__c,
                   Present__c,
                   Attendance_Date_Time__c,
                   Attendance_Marked_By__c,
                   Form_Activity_Assigned_Persons__c,
                   Form_Activity_Assigned_Persons__r.Team_Name__c,
                   Form_Activity_Assigned_Persons__r.Sales_Executives__c
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Form_Activity_Assigned_Persons__r.Form_Activity__c
                = :activityId
            AND Target_Date__c = :selectedDate
            FOR UPDATE
        ];

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : queriedAssignments
        ) {
            String assignmentTeamKey =
                buildTeamKey(
                    dateAssignment
                        .Form_Activity_Assigned_Persons__r
                        .Team_Name__c
                );

            String assignmentLocationKey =
                buildLocationKey(
                    dateAssignment.Activity_Location__c
                );

            if (
                assignmentTeamKey == effectiveTeamKey &&
                (
                    effectiveLocationKey == null ||
                    assignmentLocationKey ==
                        effectiveLocationKey
                ) &&
                isOperationalAssignment(dateAssignment)
            ) {
                matchingAssignments.add(
                    dateAssignment
                );
            }
        }

        return matchingAssignments;
    }

    private static void
        validateAssignmentsApprovedForStoreAction(
            List<
                Form_Activity_Assigned_Persons_Date__c
            > dateAssignments
        ) {
        if (
            dateAssignments == null ||
            dateAssignments.isEmpty()
        ) {
            throw new AuraHandledException(
                'No active Sales Executive assignments were found for this Team activity.'
            );
        }

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            if (
                dateAssignment.Approval_Status__c !=
                    APPROVAL_STATUS_APPROVED
            ) {
                throw new AuraHandledException(
                    'This Team activity is Pending For Approval. Store Manager actions are available only after final approval.'
                );
            }
        }
    }

    private static Boolean isOperationalAssignment(
        Form_Activity_Assigned_Persons_Date__c
            dateAssignment
    ) {
        if (dateAssignment == null) {
            return false;
        }

        if (
            dateAssignment.Approval_Status__c ==
                APPROVAL_STATUS_DROPPED ||
            dateAssignment.Assignment_Status__c ==
                ASSIGNMENT_STATUS_DROPPED ||
            dateAssignment.Assignment_Status__c ==
                ASSIGNMENT_STATUS_REPLACED ||
            dateAssignment.Assignment_Status__c ==
                ASSIGNMENT_STATUS_RESCHEDULED
        ) {
            return false;
        }

        if (dateAssignment.Is_Active__c == true) {
            return true;
        }

        return String.isBlank(
            dateAssignment.Assignment_Status__c
        );
    }


    private static void incrementActivityCount(
        Map<Id, Integer> countByActivityId,
        Id activityId
    ) {
        countByActivityId.put(
            activityId,
            getActivityCount(
                countByActivityId,
                activityId
            ) + 1
        );
    }

    private static Integer getActivityCount(
        Map<Id, Integer> countByActivityId,
        Id activityId
    ) {
        return countByActivityId.containsKey(
            activityId
        )
            ? countByActivityId.get(
                activityId
            )
            : 0;
    }

    private static void incrementGroupCount(
        Map<String, Integer> countByGroupKey,
        String groupKey
    ) {
        countByGroupKey.put(
            groupKey,
            getGroupCount(
                countByGroupKey,
                groupKey
            ) + 1
        );
    }

    private static Integer getGroupCount(
        Map<String, Integer> countByGroupKey,
        String groupKey
    ) {
        return countByGroupKey.containsKey(groupKey)
            ? countByGroupKey.get(groupKey)
            : 0;
    }

    private static void
        validateNoCrossTeamExecutiveAssignments(
            Id activityId,
            Date selectedDate,
            String teamKey,
            Set<Id> selectedExecutiveIds
        ) {
        if (
            selectedExecutiveIds == null ||
            selectedExecutiveIds.isEmpty()
        ) {
            return;
        }

        Set<Id> executiveIdsInOtherTeams =
            getExecutiveIdsAssignedToOtherTeams(
                activityId,
                selectedDate,
                teamKey
            );

        for (Id executiveId : selectedExecutiveIds) {
            if (
                executiveIdsInOtherTeams.contains(
                    executiveId
                )
            ) {
                throw new AuraHandledException(
                    'A Sales Executive cannot be assigned to more than one Team for the same Form Activity.'
                );
            }
        }
    }

    private static Set<Id>
        getExecutiveIdsAssignedToOtherTeams(
            Id activityId,
            Date selectedDate,
            String teamKey
        ) {
        Set<Id> executiveIds =
            new Set<Id>();

        if (activityId == null) {
            return executiveIds;
        }

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        for (
            Form_Activity_Assigned_Persons__c
                assignedPerson : [
                    SELECT Id,
                           Team_Name__c,
                           Sales_Executives__c
                    FROM Form_Activity_Assigned_Persons__c
                    WHERE Form_Activity__c = :activityId
                ]
        ) {
            if (
                buildTeamKey(
                    assignedPerson.Team_Name__c
                ) == effectiveTeamKey
            ) {
                continue;
            }

            if (
                assignedPerson.Sales_Executives__c !=
                    null
            ) {
                executiveIds.add(
                    assignedPerson.Sales_Executives__c
                );
            }
        }

        if (selectedDate == null) {
            return executiveIds;
        }

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : [
                    SELECT Id,
                           Actual_Executive__c,
                           Active_For_Date__c,
                           Form_Activity_Assigned_Persons__r.Team_Name__c
                    FROM Form_Activity_Assigned_Persons_Date__c
                    WHERE Form_Activity_Assigned_Persons__r.Form_Activity__c
                        = :activityId
                    AND Target_Date__c = :selectedDate
                    AND Active_For_Date__c = true
                    AND Actual_Executive__c != null
                ]
        ) {
            if (
                buildTeamKey(
                    dateAssignment
                        .Form_Activity_Assigned_Persons__r
                        .Team_Name__c
                ) == effectiveTeamKey
            ) {
                continue;
            }

            executiveIds.add(
                dateAssignment.Actual_Executive__c
            );
        }

        return executiveIds;
    }

    private static Set<Id>
        getExecutiveIdsAssignedToTeam(
            Id activityId,
            Date selectedDate,
            String teamKey
        ) {
        Set<Id> executiveIds =
            new Set<Id>();

        if (activityId == null) {
            return executiveIds;
        }

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        for (
            Form_Activity_Assigned_Persons__c
                assignedPerson : [
                    SELECT Id,
                           Team_Name__c,
                           Sales_Executives__c
                    FROM Form_Activity_Assigned_Persons__c
                    WHERE Form_Activity__c = :activityId
                ]
        ) {
            if (
                buildTeamKey(
                    assignedPerson.Team_Name__c
                ) != effectiveTeamKey
            ) {
                continue;
            }

            if (
                assignedPerson.Sales_Executives__c !=
                    null
            ) {
                executiveIds.add(
                    assignedPerson.Sales_Executives__c
                );
            }
        }

        if (selectedDate == null) {
            return executiveIds;
        }

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : [
                    SELECT Id,
                           Actual_Executive__c,
                           Form_Activity_Assigned_Persons__r.Team_Name__c
                    FROM Form_Activity_Assigned_Persons_Date__c
                    WHERE Form_Activity_Assigned_Persons__r.Form_Activity__c
                        = :activityId
                    AND Target_Date__c = :selectedDate
                    AND Actual_Executive__c != null
                ]
        ) {
            if (
                buildTeamKey(
                    dateAssignment
                        .Form_Activity_Assigned_Persons__r
                        .Team_Name__c
                ) != effectiveTeamKey
            ) {
                continue;
            }

            executiveIds.add(
                dateAssignment.Actual_Executive__c
            );
        }

        return executiveIds;
    }

    private static Form_Activity_Daily_Execution__c
        getOrCreateDailyExecution(
            Form_Activity__c activity,
            Date selectedDate,
            String teamKey
        ) {
        return getOrCreateDailyExecution(
            activity,
            selectedDate,
            teamKey,
            null
        );
    }

    private static Form_Activity_Daily_Execution__c
        getOrCreateDailyExecution(
            Form_Activity__c activity,
            Date selectedDate,
            String teamKey,
            String locationKey
        ) {
        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        String executionKey =
            locationKey == null
            ? buildLegacyExecutionKey(
                activity.Id,
                selectedDate,
                effectiveTeamKey
            )
            : buildExecutionKey(
                activity.Id,
                selectedDate,
                effectiveTeamKey,
                locationKey
            );

        List<Form_Activity_Daily_Execution__c>
            existingExecutions = [
                SELECT Id,
                       Status__c,
                       Store_Manager_Approved__c,
                       BTL_Activity_Live__c
                FROM Form_Activity_Daily_Execution__c
                WHERE Execution_Key__c = :executionKey
                LIMIT 1
                FOR UPDATE
            ];

        if (!existingExecutions.isEmpty()) {
            return existingExecutions[0];
        }

        Form_Activity_Daily_Execution__c execution =
            new Form_Activity_Daily_Execution__c();

        execution.Form_Activity__c = activity.Id;
        execution.Activity_Date__c = selectedDate;
        execution.Store__c =
            activity.Assigned_Store__c;
        execution.Status__c = STATUS_PENDING;
        execution.Execution_Key__c = executionKey;
        execution.Store_Manager_Approved__c = false;
        execution.BTL_Activity_Live__c = false;

        insert execution;

        return execution;
    }

    private static void
        validateExecutionNotAlreadyInitiated(
            Form_Activity_Daily_Execution__c execution
        ) {
        if (
            execution.BTL_Activity_Live__c == true ||
            execution.Store_Manager_Approved__c == true ||
            execution.Status__c == STATUS_LIVE ||
            execution.Status__c == STATUS_IN_PROGRESS ||
            execution.Status__c == STATUS_COMPLETED
        ) {
            throw new AuraHandledException(
                'This activity has already been initiated for today.'
            );
        }
    }

    private static void activateExecution(
        Form_Activity_Daily_Execution__c execution
    ) {
        execution.Store_Manager_Approved__c = true;
        execution.BTL_Activity_Live__c = true;
        execution.Status__c = STATUS_LIVE;
        execution.BTL_Initiated_Date_Time__c =
            System.now();
        execution.BTL_Initiated_By__c =
            UserInfo.getUserId();

        update execution;
    }

    private static void updateParentInitiationSnapshot(
        Form_Activity__c activity,
        Date selectedDate
    ) {
        activity.Store_Manager_Approved__c = true;
        activity.BTL_Activity_Live__c = true;
        activity.BTL_Live_Date__c = selectedDate;
        activity.BTL_Initiated_Date_Time__c =
            System.now();
        activity.BTL_Initiated_By__c =
            UserInfo.getUserId();

        update activity;
    }

    private static String buildLegacyExecutionKey(
        Id activityId,
        Date activityDate,
        String teamKey
    ) {
        return String.valueOf(activityId) +
            '-' +
            String.valueOf(activityDate) +
            '-' +
            normalizeRequestedTeamKey(teamKey);
    }

    private static String buildExecutionKey(
        Id activityId,
        Date activityDate,
        String teamKey,
        String locationKey
    ) {
        String executionGroupSeed =
            normalizeRequestedTeamKey(teamKey) +
            '|' +
            normalizeRequestedLocationKey(
                locationKey
            );

        Blob digest = Crypto.generateDigest(
            'SHA-256',
            Blob.valueOf(executionGroupSeed)
        );

        return String.valueOf(activityId) +
            '-' +
            String.valueOf(activityDate) +
            '-' +
            EncodingUtil.convertToHex(digest);
    }

    private static String buildActivityTeamGroupKey(
        Id activityId,
        String teamKey
    ) {
        return String.valueOf(activityId) +
            '|' +
            normalizeRequestedTeamKey(teamKey);
    }

    private static String
        buildActivityTeamLocationGroupKey(
            Id activityId,
            String teamKey,
            String locationKey
        ) {
        return buildActivityTeamGroupKey(
            activityId,
            teamKey
        ) +
            '|' +
            normalizeRequestedLocationKey(
                locationKey
            );
    }

    private static String cleanTeamName(
        String teamName
    ) {
        return String.isBlank(teamName)
            ? null
            : teamName.trim();
    }

    private static String buildTeamKey(
        String teamName
    ) {
        String cleanedTeamName =
            cleanTeamName(teamName);

        if (String.isBlank(cleanedTeamName)) {
            return NO_TEAM_KEY;
        }

        String normalizedTeamName =
            cleanedTeamName.toLowerCase();

        Blob digest = Crypto.generateDigest(
            'SHA-256',
            Blob.valueOf(normalizedTeamName)
        );

        return EncodingUtil.convertToHex(digest);
    }

    private static String normalizeRequestedTeamKey(
        String teamKey
    ) {
        return String.isBlank(teamKey)
            ? NO_TEAM_KEY
            : teamKey.trim();
    }

    private static List<String> getSortedTeamKeys(
        Id activityId,
        Set<String> teamKeys,
        Map<String, String> teamNameByGroupKey
    ) {
        List<TeamKeySortWrapper> sortableTeams =
            new List<TeamKeySortWrapper>();

        for (String teamKey : teamKeys) {
            String groupKey =
                buildActivityTeamGroupKey(
                    activityId,
                    teamKey
                );

            sortableTeams.add(
                new TeamKeySortWrapper(
                    teamKey,
                    teamNameByGroupKey.get(groupKey)
                )
            );
        }

        sortableTeams.sort();

        List<String> sortedTeamKeys =
            new List<String>();

        for (
            TeamKeySortWrapper sortableTeam :
                sortableTeams
        ) {
            sortedTeamKeys.add(
                sortableTeam.teamKey
            );
        }

        return sortedTeamKeys;
    }

    private static List<String> getSortedLocationKeys(
        Id activityId,
        String teamKey,
        Set<String> locationKeys,
        Map<String, String> locationNameByGroupKey
    ) {
        List<LocationKeySortWrapper> sortableLocations =
            new List<LocationKeySortWrapper>();

        for (String locationKey : locationKeys) {
            String groupKey =
                buildActivityTeamLocationGroupKey(
                    activityId,
                    teamKey,
                    locationKey
                );

            sortableLocations.add(
                new LocationKeySortWrapper(
                    locationKey,
                    locationNameByGroupKey.get(
                        groupKey
                    )
                )
            );
        }

        sortableLocations.sort();

        List<String> sortedLocationKeys =
            new List<String>();

        for (
            LocationKeySortWrapper sortableLocation :
                sortableLocations
        ) {
            sortedLocationKeys.add(
                sortableLocation.locationKey
            );
        }

        return sortedLocationKeys;
    }

    private static Form_Activity_Daily_Execution__c
        getExecutionForGroup(
            String groupKey,
            String expectedExecutionKey,
            Map<String, Set<Id>> executionIdsByGroupKey,
            Map<Id, Form_Activity_Daily_Execution__c>
                executionById,
            Map<String, Form_Activity_Daily_Execution__c>
                executionByExecutionKey
        ) {
        Form_Activity_Daily_Execution__c selectedExecution;

        Set<Id> linkedExecutionIds =
            executionIdsByGroupKey.get(groupKey);

        if (
            linkedExecutionIds != null &&
            !linkedExecutionIds.isEmpty()
        ) {
            for (Id executionId : linkedExecutionIds) {
                Form_Activity_Daily_Execution__c
                    candidateExecution =
                        executionById.get(executionId);

                if (candidateExecution == null) {
                    continue;
                }

                if (
                    selectedExecution == null ||
                    getExecutionPriority(
                        candidateExecution.Status__c
                    ) >
                    getExecutionPriority(
                        selectedExecution.Status__c
                    )
                ) {
                    selectedExecution =
                        candidateExecution;
                }
            }
        }

        if (
            selectedExecution == null &&
            executionByExecutionKey.containsKey(
                expectedExecutionKey
            )
        ) {
            selectedExecution =
                executionByExecutionKey.get(
                    expectedExecutionKey
                );
        }

        return selectedExecution;
    }

    private static Integer getExecutionPriority(
        String status
    ) {
        if (status == STATUS_COMPLETED) {
            return 5;
        }

        if (status == STATUS_IN_PROGRESS) {
            return 4;
        }

        if (status == STATUS_LIVE) {
            return 3;
        }

        if (status == STATUS_PENDING) {
            return 2;
        }

        if (status == STATUS_EXPIRED) {
            return 1;
        }

        return 0;
    }

    // private static AccessContext getAccessContext() {
    //     User currentUser = [
    //         SELECT Id,
    //                Store__c,
    //                Profile.Name
    //         FROM User
    //         WHERE Id = :UserInfo.getUserId()
    //         LIMIT 1
    //     ];

    //     AccessContext context = new AccessContext();
    //     context.isSystemAdministrator =
    //         currentUser.Profile.Name ==
    //             SYSTEM_ADMIN_PROFILE;

    //     if (context.isSystemAdministrator) {
    //         return context;
    //     }

    //     if (String.isBlank(currentUser.Store__c)) {
    //         throw new AuraHandledException(
    //             'No store is assigned to the logged-in user.'
    //         );
    //     }

    //     List<Store__c> assignedStores = [
    //         SELECT Id, Name
    //         FROM Store__c
    //         WHERE Name = :currentUser.Store__c
    //         LIMIT 1
    //     ];

    //     if (assignedStores.isEmpty()) {
    //         throw new AuraHandledException(
    //             'The store mapped on the logged-in user was not found.'
    //         );
    //     }

    //     context.storeId = assignedStores[0].Id;
    //     context.storeName = assignedStores[0].Name;

    //     return context;
    // }

    private static AccessContext getAccessContext() {
        // 1. Query User without the Profile relationship
        User currentUser = [
            SELECT Id,
                   Store__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        // 2. Query Profile directly
        Id profileId = UserInfo.getProfileId();
        Profile currentProfile = [
            SELECT Name 
            FROM Profile 
            WHERE Id = :profileId 
            LIMIT 1
        ];

        AccessContext context = new AccessContext();
        
        // 3. Use currentProfile.Name instead of currentUser.Profile.Name
        context.isSystemAdministrator =
            currentProfile.Name ==
                SYSTEM_ADMIN_PROFILE;

        if (context.isSystemAdministrator) {
            return context;
        }

        if (String.isBlank(currentUser.Store__c)) {
            throw new AuraHandledException(
                'No store is assigned to the logged-in user.'
            );
        }

        List<Store__c> assignedStores = [
            SELECT Id, Name
            FROM Store__c
            WHERE Name = :currentUser.Store__c
            LIMIT 1
        ];

        if (assignedStores.isEmpty()) {
            throw new AuraHandledException(
                'The store mapped on the logged-in user was not found.'
            );
        }

        context.storeId = assignedStores[0].Id;
        context.storeName = assignedStores[0].Name;

        return context;
    }

    private static List<OptionWrapper> getStoreOptions(
        AccessContext accessContext
    ) {
        List<OptionWrapper> options =
            new List<OptionWrapper>();

        if (!accessContext.isSystemAdministrator) {
            options.add(
                new OptionWrapper(
                    accessContext.storeName,
                    String.valueOf(accessContext.storeId)
                )
            );

            return options;
        }

        options.add(
            new OptionWrapper(
                'All Stores',
                ''
            )
        );

        for (
            Store__c storeRecord : [
                SELECT Id, Name
                FROM Store__c
                ORDER BY Name
                LIMIT 500
            ]
        ) {
            options.add(
                new OptionWrapper(
                    storeRecord.Name,
                    String.valueOf(storeRecord.Id)
                )
            );
        }

        return options;
    }

    private static void validateStoreExists(
        Id storeId
    ) {
        if (
            [
                SELECT COUNT()
                FROM Store__c
                WHERE Id = :storeId
            ] == 0
        ) {
            throw new AuraHandledException(
                'The selected Store was not found.'
            );
        }
    }

    private class TeamKeySortWrapper
        implements Comparable {

        private String teamKey;
        private String teamName;

        private TeamKeySortWrapper(
            String teamKey,
            String teamName
        ) {
            this.teamKey = teamKey;
            this.teamName = teamName;
        }

        public Integer compareTo(
            Object otherObject
        ) {
            TeamKeySortWrapper otherTeam =
                (TeamKeySortWrapper) otherObject;

            String currentName =
                String.isBlank(teamName)
                ? ''
                : teamName.trim().toLowerCase();

            String otherName =
                String.isBlank(otherTeam.teamName)
                ? ''
                : otherTeam.teamName
                    .trim()
                    .toLowerCase();

            Integer nameComparison =
                currentName.compareTo(otherName);

            if (nameComparison != 0) {
                return nameComparison;
            }

            return teamKey.compareTo(
                otherTeam.teamKey
            );
        }
    }

    private class LocationKeySortWrapper
        implements Comparable {

        private String locationKey;
        private String locationName;

        private LocationKeySortWrapper(
            String locationKey,
            String locationName
        ) {
            this.locationKey = locationKey;
            this.locationName = locationName;
        }

        public Integer compareTo(
            Object otherObject
        ) {
            LocationKeySortWrapper otherLocation =
                (LocationKeySortWrapper) otherObject;

            String currentName =
                String.isBlank(locationName)
                ? ''
                : locationName
                    .trim()
                    .toLowerCase();

            String otherName =
                String.isBlank(
                    otherLocation.locationName
                )
                ? ''
                : otherLocation
                    .locationName
                    .trim()
                    .toLowerCase();

            Integer nameComparison =
                currentName.compareTo(otherName);

            if (nameComparison != 0) {
                return nameComparison;
            }

            return locationKey.compareTo(
                otherLocation.locationKey
            );
        }
    }

    private class AccessContext {
        Boolean isSystemAdministrator;
        Id storeId;
        String storeName;
    }

    public class ExecutiveChangeInput {
        @AuraEnabled
        public Id dateAssignmentId { get; set; }

        @AuraEnabled
        public Id actualExecutiveId { get; set; }

        @AuraEnabled
        public Boolean activeForDate { get; set; }

        @AuraEnabled
        public String activityLocation { get; set; }

        @AuraEnabled
        public Boolean isNew { get; set; }
    }

    public class ScheduleConflictRow {
        @AuraEnabled
        public Id executiveId { get; set; }

        @AuraEnabled
        public String executiveName { get; set; }

        @AuraEnabled
        public Id activityId { get; set; }

        @AuraEnabled
        public String activityName { get; set; }

        @AuraEnabled
        public String teamName { get; set; }
    }

    public class ScheduleActionResponse {
        @AuraEnabled
        public Integer processedRecords {
            get;
            set;
        }

        @AuraEnabled
        public Date newActivityDate {
            get;
            set;
        }

        @AuraEnabled
        public String actionType {
            get;
            set;
        }

        @AuraEnabled
        public List<ScheduleConflictRow> conflicts {
            get;
            set;
        }

        @AuraEnabled
        public String locationWarning {
            get;
            set;
        }

        @AuraEnabled
        public String message {
            get;
            set;
        }
    }

    public class SaveApprovalResponse {
        @AuraEnabled
        public Integer updatedExecutiveRecords {
            get;
            set;
        }

        @AuraEnabled
        public Integer createdExecutiveRecords {
            get;
            set;
        }

        @AuraEnabled
        public Integer taggedApprovalRecords {
            get;
            set;
        }

        @AuraEnabled
        public String message { get; set; }
    }

    public class DashboardResponse {
        @AuraEnabled
        public Date selectedDate { get; set; }

        @AuraEnabled
        public DateTime refreshedAt { get; set; }

        @AuraEnabled
        public Boolean isSystemAdministrator {
            get;
            set;
        }

        @AuraEnabled
        public Id selectedStoreId { get; set; }

        @AuraEnabled
        public List<OptionWrapper> storeOptions {
            get;
            set;
        }

        @AuraEnabled
        public Integer totalActivities { get; set; }

        @AuraEnabled
        public Integer pendingInitiation { get; set; }

        @AuraEnabled
        public Integer liveActivities { get; set; }

        @AuraEnabled
        public Integer inProgressActivities { get; set; }

        @AuraEnabled
        public Integer completedActivities { get; set; }

        @AuraEnabled
        public List<ActivityRow> activities {
            get;
            set;
        }

        public DashboardResponse() {
            totalActivities = 0;
            pendingInitiation = 0;
            liveActivities = 0;
            inProgressActivities = 0;
            completedActivities = 0;
            storeOptions = new List<OptionWrapper>();
            activities = new List<ActivityRow>();
        }
    }

    public class ActivityRow {
        @AuraEnabled
        public String rowKey { get; set; }

        @AuraEnabled
        public String teamKey { get; set; }

        @AuraEnabled
        public String teamName { get; set; }

        @AuraEnabled
        public Boolean hasTeam { get; set; }

        @AuraEnabled
        public String locationKey { get; set; }

        @AuraEnabled
        public Id activityId { get; set; }

        @AuraEnabled
        public Id dailyExecutionId { get; set; }

        @AuraEnabled
        public String activityNo { get; set; }

        @AuraEnabled
        public String activityName { get; set; }

        @AuraEnabled
        public Date startDate { get; set; }

        @AuraEnabled
        public Date endDate { get; set; }

        @AuraEnabled
        public String activityLocation { get; set; }

        @AuraEnabled
        public Id storeId { get; set; }

        @AuraEnabled
        public String storeName { get; set; }

        @AuraEnabled
        public Id finalCustomizeFormId { get; set; }

        @AuraEnabled
        public String finalCustomizeFormName {
            get;
            set;
        }

        @AuraEnabled
        public String status { get; set; }

        @AuraEnabled
        public Boolean storeManagerApproved {
            get;
            set;
        }

        @AuraEnabled
        public Boolean btlActivityLive { get; set; }

        @AuraEnabled
        public DateTime initiatedDateTime { get; set; }

        @AuraEnabled
        public String initiatedByName { get; set; }

        @AuraEnabled
        public DateTime startDateTime { get; set; }

        @AuraEnabled
        public DateTime completedDateTime { get; set; }

        @AuraEnabled
        public Integer assignedExecutiveCount {
            get;
            set;
        }

        @AuraEnabled
        public Boolean canInitiate { get; set; }

        @AuraEnabled
        public Boolean canReschedule { get; set; }

        @AuraEnabled
        public Boolean canDrop { get; set; }

        @AuraEnabled
        public Boolean activityFullyApproved {
            get;
            set;
        }

        @AuraEnabled
        public Boolean approvalLocked { get; set; }

        @AuraEnabled
        public Boolean approvalApproved { get; set; }

        @AuraEnabled
        public String approvalStatus { get; set; }

        @AuraEnabled
        public List<MemberRow> members { get; set; }
    }

    public class MemberRow {
        @AuraEnabled
        public Id dateAssignmentId { get; set; }

        @AuraEnabled
        public Id assignedPersonId { get; set; }

        @AuraEnabled
        public Id assignedExecutiveId { get; set; }

        @AuraEnabled
        public String assignedExecutiveName {
            get;
            set;
        }

        @AuraEnabled
        public Id actualExecutiveId { get; set; }

        @AuraEnabled
        public String actualExecutiveName {
            get;
            set;
        }

        @AuraEnabled
        public Id displayExecutiveId { get; set; }

        @AuraEnabled
        public String displayExecutiveName {
            get;
            set;
        }

        @AuraEnabled
        public String teamName { get; set; }

        @AuraEnabled
        public String activityLocation { get; set; }

        @AuraEnabled
        public Boolean activeForDate { get; set; }

        @AuraEnabled
        public Boolean isReplacement { get; set; }

        @AuraEnabled
        public String approvalStatus { get; set; }

        @AuraEnabled
        public Boolean approvalLocked { get; set; }

        @AuraEnabled
        public Boolean present { get; set; }
    }

    public class OptionWrapper {
        @AuraEnabled
        public String label { get; set; }

        @AuraEnabled
        public String value { get; set; }

        public OptionWrapper(
            String label,
            String value
        ) {
            this.label = label;
            this.value = value;
        }
    }
}

/*public with sharing class ctrl_StoreManagerDailyActivityCnt_v2 {

    private static final String SYSTEM_ADMIN_PROFILE =
        'System Administrator';

    private static final String STATUS_PENDING =
        'Pending Initiation';

    private static final String STATUS_LIVE =
        'Live';

    private static final String STATUS_IN_PROGRESS =
        'In Progress';

    private static final String STATUS_COMPLETED =
        'Completed';

    private static final String STATUS_EXPIRED =
        'Expired';

    private static final String NO_TEAM_KEY =
        'NO_TEAM';

    private static final String NO_LOCATION_KEY =
        'NO_LOCATION';

    private static final String APPROVAL_TYPE_BTL_FORM_ACTIVITY =
        'BTL Form Activity';

    private static final String APPROVAL_STATUS_NOT_SUBMITTED =
        'Not Submitted';

    private static final String APPROVAL_STATUS_APPROVED =
        'Approved';

    private static final String APPROVAL_STATUS_DROPPED =
        'Dropped';

    private static final String ASSIGNMENT_STATUS_ACTIVE =
        'Active';

    private static final String ASSIGNMENT_STATUS_REPLACED =
        'Replaced';

    private static final String ASSIGNMENT_STATUS_DROPPED =
        'Dropped';

    private static final String ASSIGNMENT_STATUS_RESCHEDULED =
        'Rescheduled';

    private static final String ACTION_RESCHEDULED =
        'Rescheduled';

    private static final String ACTION_ACTIVITY_DROPPED =
        'Activity Dropped';

    private static final String STATUS_PENDING_APPROVAL =
        'Pending For Approval';

    @AuraEnabled
    public static DashboardResponse getDashboard(
        Date selectedDate,
        Id selectedStoreId
    ) {
        if (selectedDate == null) {
            selectedDate = Date.today();
        }

        AccessContext accessContext = getAccessContext();

        Id effectiveStoreId;

        if (accessContext.isSystemAdministrator) {
            effectiveStoreId = selectedStoreId;

            if (effectiveStoreId != null) {
                validateStoreExists(effectiveStoreId);
            }
        } else {
            effectiveStoreId = accessContext.storeId;
        }

        DashboardResponse response = new DashboardResponse();
        response.selectedDate = selectedDate;
        response.refreshedAt = System.now();
        response.isSystemAdministrator =
            accessContext.isSystemAdministrator;
        response.selectedStoreId = effectiveStoreId;
        response.storeOptions = getStoreOptions(accessContext);
        response.activities = new List<ActivityRow>();

        List<Form_Activity__c> activityRecords;

        if (effectiveStoreId == null) {
            activityRecords = [
                SELECT Id,
                       Name,
                       Activity_Name__c,
                       Activity_Date__c,
                       Activity_End_Date__c,
                       Activity_Location__c,
                       Assigned_Store__c,
                       Assigned_Store__r.Name,
                       Final_Customize_Form__c,
                       Final_Customize_Form__r.Name
                FROM Form_Activity__c
                WHERE Activity_Date__c <= :selectedDate
                AND Activity_End_Date__c >= :selectedDate
                ORDER BY Assigned_Store__r.Name,
                         Activity_Name__c,
                         Name
                LIMIT 2000
            ];
        } else {
            activityRecords = [
                SELECT Id,
                       Name,
                       Activity_Name__c,
                       Activity_Date__c,
                       Activity_End_Date__c,
                       Activity_Location__c,
                       Assigned_Store__c,
                       Assigned_Store__r.Name,
                       Final_Customize_Form__c,
                       Final_Customize_Form__r.Name
                FROM Form_Activity__c
                WHERE Activity_Date__c <= :selectedDate
                AND Activity_End_Date__c >= :selectedDate
                AND Assigned_Store__c = :effectiveStoreId
                ORDER BY Activity_Name__c, Name
                LIMIT 2000
            ];
        }

        if (activityRecords.isEmpty()) {
            return response;
        }

        Set<Id> activityIds = new Set<Id>();

        for (Form_Activity__c activity : activityRecords) {
            activityIds.add(activity.Id);
        }

        Map<String, List<MemberRow>> membersByGroupKey =
            new Map<String, List<MemberRow>>();

        Map<Id, Set<String>> teamKeysByActivityId =
            new Map<Id, Set<String>>();

        Map<String, Set<String>>
            locationKeysByActivityTeamGroupKey =
                new Map<String, Set<String>>();

        Map<String, String> teamNameByGroupKey =
            new Map<String, String>();

        Map<String, String> locationNameByGroupKey =
            new Map<String, String>();

        Map<String, Set<Id>> executionIdsByGroupKey =
            new Map<String, Set<Id>>();

        Map<String, Boolean> approvalLockedByGroupKey =
            new Map<String, Boolean>();

        Map<String, Integer> totalAssignmentsByGroupKey =
            new Map<String, Integer>();

        Map<String, Integer> activeAssignmentsByGroupKey =
            new Map<String, Integer>();

        Map<String, Integer> approvedAssignmentsByGroupKey =
            new Map<String, Integer>();

        Map<Id, Integer> activeAssignmentsByActivityId =
            new Map<Id, Integer>();

        Map<Id, Integer> approvedAssignmentsByActivityId =
            new Map<Id, Integer>();

        for (
            Form_Activity_Assigned_Persons_Date__c dateAssignment : [
                SELECT Id,
                       Target_Date__c,
                       Actual_Date__c,
                       Activity_Location__c,
                       Form_Activity_Daily_Execution__c,
                       Actual_Executive__c,
                       Actual_Executive__r.Name,
                       Active_For_Date__c,
                       Is_Active__c,
                       Assignment_Status__c,
                       Replacement_Of__c,
                       Approval_Status__c,
                       Approval_Locked__c,
                       Present__c,
                       Attendance_Date_Time__c,
                       Form_Activity_Assigned_Persons__c,
                       Form_Activity_Assigned_Persons__r.Form_Activity__c,
                       Form_Activity_Assigned_Persons__r.Person_Name__c,
                       Form_Activity_Assigned_Persons__r.Team_Name__c,
                       Form_Activity_Assigned_Persons__r.Sales_Executives__c,
                       Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Form_Activity_Assigned_Persons__r.Form_Activity__c
                    IN :activityIds
                AND Target_Date__c = :selectedDate
                ORDER BY
                    Form_Activity_Assigned_Persons__r.Team_Name__c,
                    Activity_Location__c,
                    Form_Activity_Assigned_Persons__r.Person_Name__c
            ]
        ) {
            Id activityId =
                dateAssignment
                    .Form_Activity_Assigned_Persons__r
                    .Form_Activity__c;

            String teamName = cleanTeamName(
                dateAssignment
                    .Form_Activity_Assigned_Persons__r
                    .Team_Name__c
            );

            String teamKey = buildTeamKey(teamName);

            String activityTeamGroupKey =
                buildActivityTeamGroupKey(
                    activityId,
                    teamKey
                );

            String locationName =
                cleanLocation(
                    dateAssignment.Activity_Location__c
                );

            String locationKey =
                buildLocationKey(locationName);

            String groupKey =
                buildActivityTeamLocationGroupKey(
                    activityId,
                    teamKey,
                    locationKey
                );

            if (!teamKeysByActivityId.containsKey(activityId)) {
                teamKeysByActivityId.put(
                    activityId,
                    new Set<String>()
                );
            }

            teamKeysByActivityId.get(activityId).add(teamKey);

            teamNameByGroupKey.put(
                activityTeamGroupKey,
                teamName
            );

            if (
                !locationKeysByActivityTeamGroupKey
                    .containsKey(activityTeamGroupKey)
            ) {
                locationKeysByActivityTeamGroupKey.put(
                    activityTeamGroupKey,
                    new Set<String>()
                );
            }

            locationKeysByActivityTeamGroupKey
                .get(activityTeamGroupKey)
                .add(locationKey);

            locationNameByGroupKey.put(
                groupKey,
                locationName
            );

            incrementGroupCount(
                totalAssignmentsByGroupKey,
                groupKey
            );

            if (!isOperationalAssignment(dateAssignment)) {
                continue;
            }

            incrementGroupCount(
                activeAssignmentsByGroupKey,
                groupKey
            );

            incrementActivityCount(
                activeAssignmentsByActivityId,
                activityId
            );

            if (
                dateAssignment.Approval_Status__c ==
                    APPROVAL_STATUS_APPROVED
            ) {
                incrementGroupCount(
                    approvedAssignmentsByGroupKey,
                    groupKey
                );

                incrementActivityCount(
                    approvedAssignmentsByActivityId,
                    activityId
                );
            }

            if (!membersByGroupKey.containsKey(groupKey)) {
                membersByGroupKey.put(
                    groupKey,
                    new List<MemberRow>()
                );
            }

            MemberRow member = new MemberRow();
            member.dateAssignmentId = dateAssignment.Id;
            member.assignedPersonId =
                dateAssignment
                    .Form_Activity_Assigned_Persons__c;

            member.assignedExecutiveId =
                dateAssignment
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__c;

            member.assignedExecutiveName =
                dateAssignment
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__r == null
                ? dateAssignment
                    .Form_Activity_Assigned_Persons__r
                    .Person_Name__c
                : dateAssignment
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__r.Name;

            member.actualExecutiveId =
                dateAssignment.Actual_Executive__c;

            member.actualExecutiveName =
                dateAssignment.Actual_Executive__r == null
                ? null
                : dateAssignment.Actual_Executive__r.Name;

            member.displayExecutiveId =
                member.actualExecutiveId == null
                ? member.assignedExecutiveId
                : member.actualExecutiveId;

            member.displayExecutiveName =
                String.isBlank(member.actualExecutiveName)
                ? member.assignedExecutiveName
                : member.actualExecutiveName;

            member.teamName = teamName;
            member.activityLocation =
                dateAssignment.Activity_Location__c;
            member.activeForDate =
                dateAssignment.Active_For_Date__c;
            member.isReplacement =
                dateAssignment.Replacement_Of__c != null;
            member.approvalStatus =
                dateAssignment.Approval_Status__c;
            member.approvalLocked =
                dateAssignment.Approval_Locked__c;
            member.present = dateAssignment.Present__c;

            if (dateAssignment.Approval_Locked__c == true) {
                approvalLockedByGroupKey.put(
                    groupKey,
                    true
                );
            }

            membersByGroupKey.get(groupKey).add(member);

            if (
                dateAssignment.Form_Activity_Daily_Execution__c
                    != null
            ) {
                if (
                    !executionIdsByGroupKey.containsKey(
                        groupKey
                    )
                ) {
                    executionIdsByGroupKey.put(
                        groupKey,
                        new Set<Id>()
                    );
                }

                executionIdsByGroupKey
                    .get(groupKey)
                    .add(
                        dateAssignment
                            .Form_Activity_Daily_Execution__c
                    );
            }
        }

        Map<Id, Form_Activity_Daily_Execution__c>
            executionById =
                new Map<Id, Form_Activity_Daily_Execution__c>();

        Map<String, Form_Activity_Daily_Execution__c>
            executionByExecutionKey =
                new Map<String, Form_Activity_Daily_Execution__c>();

        for (
            Form_Activity_Daily_Execution__c execution : [
                SELECT Id,
                       Name,
                       Form_Activity__c,
                       Activity_Date__c,
                       Store__c,
                       Status__c,
                       Execution_Key__c,
                       Store_Manager_Approved__c,
                       BTL_Activity_Live__c,
                       BTL_Initiated_Date_Time__c,
                       BTL_Initiated_By__c,
                       BTL_Initiated_By__r.Name,
                       Start_Date_Time__c,
                       Completed_Date_Time__c
                FROM Form_Activity_Daily_Execution__c
                WHERE Form_Activity__c IN :activityIds
                AND Activity_Date__c = :selectedDate
            ]
        ) {
            executionById.put(execution.Id, execution);

            if (!String.isBlank(execution.Execution_Key__c)) {
                executionByExecutionKey.put(
                    execution.Execution_Key__c,
                    execution
                );
            }
        }

        for (Form_Activity__c activity : activityRecords) {
            Set<String> teamKeys =
                teamKeysByActivityId.get(activity.Id);

            if (teamKeys == null || teamKeys.isEmpty()) {
                teamKeys = new Set<String>{
                    NO_TEAM_KEY
                };

                String noTeamGroupKey =
                    buildActivityTeamGroupKey(
                        activity.Id,
                        NO_TEAM_KEY
                    );

                teamNameByGroupKey.put(
                    noTeamGroupKey,
                    null
                );

                locationKeysByActivityTeamGroupKey.put(
                    noTeamGroupKey,
                    new Set<String>{
                        NO_LOCATION_KEY
                    }
                );

                locationNameByGroupKey.put(
                    buildActivityTeamLocationGroupKey(
                        activity.Id,
                        NO_TEAM_KEY,
                        NO_LOCATION_KEY
                    ),
                    null
                );
            }

            List<String> sortedTeamKeys =
                getSortedTeamKeys(
                    activity.Id,
                    teamKeys,
                    teamNameByGroupKey
                );

            for (String teamKey : sortedTeamKeys) {
                String activityTeamGroupKey =
                    buildActivityTeamGroupKey(
                        activity.Id,
                        teamKey
                    );

                String teamName =
                    teamNameByGroupKey.get(
                        activityTeamGroupKey
                    );

                Set<String> locationKeys =
                    locationKeysByActivityTeamGroupKey.get(
                        activityTeamGroupKey
                    );

                if (
                    locationKeys == null ||
                    locationKeys.isEmpty()
                ) {
                    locationKeys = new Set<String>{
                        NO_LOCATION_KEY
                    };

                    locationNameByGroupKey.put(
                        buildActivityTeamLocationGroupKey(
                            activity.Id,
                            teamKey,
                            NO_LOCATION_KEY
                        ),
                        null
                    );
                }

                List<String> sortedLocationKeys =
                    getSortedLocationKeys(
                        activity.Id,
                        teamKey,
                        locationKeys,
                        locationNameByGroupKey
                    );

                for (
                    String locationKey :
                        sortedLocationKeys
                ) {
                    String groupKey =
                        buildActivityTeamLocationGroupKey(
                            activity.Id,
                            teamKey,
                            locationKey
                        );

                    ActivityRow row = new ActivityRow();

                    row.rowKey = groupKey;
                    row.teamKey = teamKey;
                    row.teamName = teamName;
                    row.hasTeam =
                        !String.isBlank(teamName);
                    row.locationKey = locationKey;
                    row.activityId = activity.Id;
                    row.activityNo = activity.Name;
                    row.activityName =
                        String.isBlank(
                            activity.Activity_Name__c
                        )
                        ? activity.Name
                        : activity.Activity_Name__c;

                    row.startDate =
                        activity.Activity_Date__c;
                    row.endDate =
                        activity.Activity_End_Date__c;
                    row.activityLocation =
                        locationNameByGroupKey.get(
                            groupKey
                        );

                    row.storeId =
                        activity.Assigned_Store__c;
                    row.storeName =
                        activity.Assigned_Store__r == null
                        ? ''
                        : activity
                            .Assigned_Store__r.Name;

                    row.finalCustomizeFormId =
                        activity.Final_Customize_Form__c;

                    row.finalCustomizeFormName =
                        activity
                            .Final_Customize_Form__r ==
                                null
                        ? ''
                        : activity
                            .Final_Customize_Form__r
                            .Name;

                    Integer totalAssignmentCount =
                        getGroupCount(
                            totalAssignmentsByGroupKey,
                            groupKey
                        );

                    Integer activeAssignmentCount =
                        getGroupCount(
                            activeAssignmentsByGroupKey,
                            groupKey
                        );

                    if (
                        totalAssignmentCount > 0 &&
                        activeAssignmentCount == 0
                    ) {
                        continue;
                    }

                    Integer approvedAssignmentCount =
                        getGroupCount(
                            approvedAssignmentsByGroupKey,
                            groupKey
                        );

                    row.approvalApproved =
                        activeAssignmentCount > 0 &&
                        approvedAssignmentCount ==
                            activeAssignmentCount;

                    row.approvalStatus =
                        row.approvalApproved
                        ? APPROVAL_STATUS_APPROVED
                        : STATUS_PENDING_APPROVAL;

                    Integer activityActiveAssignmentCount =
                        getActivityCount(
                            activeAssignmentsByActivityId,
                            activity.Id
                        );

                    Integer activityApprovedAssignmentCount =
                        getActivityCount(
                            approvedAssignmentsByActivityId,
                            activity.Id
                        );

                    row.activityFullyApproved =
                        activityActiveAssignmentCount > 0 &&
                        activityApprovedAssignmentCount ==
                            activityActiveAssignmentCount;

                    row.members =
                        membersByGroupKey.containsKey(
                            groupKey
                        )
                        ? membersByGroupKey.get(groupKey)
                        : new List<MemberRow>();

                    row.assignedExecutiveCount =
                        row.members.size();

                    String expectedExecutionKey =
                        buildExecutionKey(
                            activity.Id,
                            selectedDate,
                            teamKey,
                            locationKey
                        );

                    Form_Activity_Daily_Execution__c
                        execution =
                            getExecutionForGroup(
                                groupKey,
                                expectedExecutionKey,
                                executionIdsByGroupKey,
                                executionById,
                                executionByExecutionKey
                            );

                    if (execution == null) {
                        row.status =
                            selectedDate < Date.today()
                            ? STATUS_EXPIRED
                            : STATUS_PENDING;

                        row.storeManagerApproved = false;
                        row.btlActivityLive = false;
                    } else {
                        row.dailyExecutionId =
                            execution.Id;
                        row.status =
                            execution.Status__c;
                        row.storeManagerApproved =
                            execution
                                .Store_Manager_Approved__c;
                        row.btlActivityLive =
                            execution.BTL_Activity_Live__c;
                        row.initiatedDateTime =
                            execution
                                .BTL_Initiated_Date_Time__c;
                        row.initiatedByName =
                            execution
                                .BTL_Initiated_By__r ==
                                    null
                            ? ''
                            : execution
                                .BTL_Initiated_By__r
                                .Name;
                        row.startDateTime =
                            execution.Start_Date_Time__c;
                        row.completedDateTime =
                            execution
                                .Completed_Date_Time__c;

                        if (
                            selectedDate < Date.today() &&
                            row.status != STATUS_COMPLETED
                        ) {
                            row.status = STATUS_EXPIRED;
                        }
                    }

                    row.approvalLocked =
                        approvalLockedByGroupKey
                            .containsKey(groupKey) &&
                        approvalLockedByGroupKey
                            .get(groupKey) == true;

                    Boolean executionAlreadyStarted =
                        row.status == STATUS_LIVE ||
                        row.status ==
                            STATUS_IN_PROGRESS ||
                        row.status ==
                            STATUS_COMPLETED;

                    if (
                        !row.approvalApproved &&
                        !executionAlreadyStarted
                    ) {
                        row.status =
                            STATUS_PENDING_APPROVAL;
                    }

                    row.canInitiate =
                        row.approvalApproved &&
                        selectedDate == Date.today() &&
                        row.status == STATUS_PENDING &&
                        !row.btlActivityLive;

                    Boolean
                        scheduleManagementAvailable =
                            row.approvalApproved &&
                            selectedDate >= Date.today() &&
                            row.status ==
                                STATUS_PENDING &&
                            !row.btlActivityLive;

                    row.canReschedule =
                        scheduleManagementAvailable;

                    row.canDrop =
                        scheduleManagementAvailable;

                    if (row.status == STATUS_PENDING) {
                        response.pendingInitiation++;
                    } else if (
                        row.status == STATUS_LIVE
                    ) {
                        response.liveActivities++;
                    } else if (
                        row.status == STATUS_IN_PROGRESS
                    ) {
                        response.inProgressActivities++;
                    } else if (
                        row.status == STATUS_COMPLETED
                    ) {
                        response.completedActivities++;
                    }

                    response.activities.add(row);
                }
            }
        }

        response.totalActivities =
            response.activities.size();

        return response;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getSalesExecutives(
        Id storeId,
        Id activityId,
        Date selectedDate,
        String teamKey
    ) {
        if (storeId == null) {
            return new List<OptionWrapper>();
        }

        validateStoreExists(storeId);

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        Set<Id> executiveIdsInOtherTeams =
            getExecutiveIdsAssignedToOtherTeams(
                activityId,
                selectedDate,
                effectiveTeamKey
            );

        Set<Id> executiveIdsInCurrentTeam =
            getExecutiveIdsAssignedToTeam(
                activityId,
                selectedDate,
                effectiveTeamKey
            );

        List<OptionWrapper> results =
            new List<OptionWrapper>();

        for (
            Sales_Executives__c executive : [
                SELECT Id, Name
                FROM Sales_Executives__c
                WHERE Store__c = :storeId
                ORDER BY Name
                LIMIT 1000
            ]
        ) {
            if (
                executiveIdsInOtherTeams.contains(
                    executive.Id
                ) &&
                !executiveIdsInCurrentTeam.contains(
                    executive.Id
                )
            ) {
                continue;
            }

            results.add(
                new OptionWrapper(
                    executive.Name,
                    String.valueOf(executive.Id)
                )
            );
        }

        return results;
    }

    @AuraEnabled
    public static Id initiateWithoutChanges(
        Id activityId,
        Date selectedDate,
        String teamKey
    ) {
        return initiateWithoutChangesInternal(
            activityId,
            selectedDate,
            teamKey,
            null
        );
    }

    @AuraEnabled
    public static Id initiateWithoutChangesByLocation(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey
    ) {
        return initiateWithoutChangesInternal(
            activityId,
            selectedDate,
            teamKey,
            locationKey
        );
    }

    private static Id initiateWithoutChangesInternal(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey
    ) {
        validateInitiationInput(
            activityId,
            selectedDate
        );

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        Form_Activity__c activity =
            getActivityForInitiation(
                activityId,
                selectedDate
            );

        List<Form_Activity_Assigned_Persons_Date__c>
            dateAssignments =
                getDateAssignmentsForUpdate(
                    activityId,
                    selectedDate,
                    effectiveTeamKey,
                    locationKey
                );

        if (dateAssignments.isEmpty()) {
            throw new AuraHandledException(
                'No Sales Executives are assigned for the selected team and date.'
            );
        }

        validateAssignmentsApprovedForStoreAction(
            dateAssignments
        );

        Form_Activity_Daily_Execution__c execution =
            getOrCreateDailyExecution(
                activity,
                selectedDate,
                effectiveTeamKey,
                locationKey
            );

        validateExecutionNotAlreadyInitiated(execution);

        Boolean hasSavedApprovedComposition = false;

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            if (
                dateAssignment.Active_For_Date__c == true ||
                dateAssignment.Actual_Executive__c != null
            ) {
                hasSavedApprovedComposition = true;
                break;
            }
        }

        Set<Id> usedExecutiveIds = new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            Boolean isActive =
                hasSavedApprovedComposition
                    ? dateAssignment.Active_For_Date__c == true
                    : true;

            Id assignedExecutiveId =
                dateAssignment
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__c;

            Id effectiveExecutiveId =
                isActive
                    ? (
                        dateAssignment.Actual_Executive__c != null
                            ? dateAssignment.Actual_Executive__c
                            : assignedExecutiveId
                    )
                    : null;

            if (
                isActive &&
                effectiveExecutiveId == null
            ) {
                throw new AuraHandledException(
                    'A predefined Sales Executive is missing for one or more active assignments.'
                );
            }

            if (
                isActive &&
                usedExecutiveIds.contains(
                    effectiveExecutiveId
                )
            ) {
                throw new AuraHandledException(
                    'The same Sales Executive cannot be assigned more than once within the selected team.'
                );
            }

            if (isActive) {
                usedExecutiveIds.add(
                    effectiveExecutiveId
                );
            }

            dateAssignment.Form_Activity_Daily_Execution__c =
                execution.Id;

            dateAssignment.Actual_Executive__c =
                effectiveExecutiveId;

            dateAssignment.Active_For_Date__c =
                isActive;

            dateAssignment.Present__c = false;
            dateAssignment.Actual_Date__c = null;
            dateAssignment.Attendance_Date_Time__c =
                null;
            dateAssignment.Attendance_Marked_By__c =
                null;
        }

        if (usedExecutiveIds.isEmpty()) {
            throw new AuraHandledException(
                'No approved active manpower composition was found for initiation.'
            );
        }

        validateNoCrossTeamExecutiveAssignments(
            activityId,
            selectedDate,
            effectiveTeamKey,
            usedExecutiveIds
        );

        update dateAssignments;

        activateExecution(execution);
        updateParentInitiationSnapshot(
            activity,
            selectedDate
        );

        return execution.Id;
    }

    @AuraEnabled
    public static Id initiateWithChanges(
        Id activityId,
        Date selectedDate,
        String teamKey,
        List<ExecutiveChangeInput> executiveChanges
    ) {
        validateInitiationInput(
            activityId,
            selectedDate
        );

        if (
            executiveChanges == null ||
            executiveChanges.isEmpty()
        ) {
            throw new AuraHandledException(
                'Executive assignment details are required.'
            );
        }

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        Form_Activity__c activity =
            getActivityForInitiation(
                activityId,
                selectedDate
            );

        List<Form_Activity_Assigned_Persons_Date__c>
            dateAssignments =
                getDateAssignmentsForUpdate(
                    activityId,
                    selectedDate,
                    effectiveTeamKey
                );

        if (dateAssignments.isEmpty()) {
            throw new AuraHandledException(
                'No Sales Executives are assigned for the selected team and date.'
            );
        }

        validateAssignmentsApprovedForStoreAction(
            dateAssignments
        );

        Set<Id> validDateAssignmentIds = new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            validDateAssignmentIds.add(
                dateAssignment.Id
            );
        }

        Map<Id, ExecutiveChangeInput> changeByDateRowId =
            new Map<Id, ExecutiveChangeInput>();

        Set<Id> selectedExecutiveIds = new Set<Id>();

        for (ExecutiveChangeInput input : executiveChanges) {
            if (
                input == null ||
                input.dateAssignmentId == null
            ) {
                continue;
            }

            if (
                !validDateAssignmentIds.contains(
                    input.dateAssignmentId
                )
            ) {
                throw new AuraHandledException(
                    'One or more executive assignment rows do not belong to the selected team.'
                );
            }

            changeByDateRowId.put(
                input.dateAssignmentId,
                input
            );

            if (
                input.activeForDate == true &&
                input.actualExecutiveId != null
            ) {
                selectedExecutiveIds.add(
                    input.actualExecutiveId
                );
            }
        }

        if (selectedExecutiveIds.isEmpty()) {
            throw new AuraHandledException(
                'Please select at least one active Sales Executive.'
            );
        }

        validateNoCrossTeamExecutiveAssignments(
            activityId,
            selectedDate,
            effectiveTeamKey,
            selectedExecutiveIds
        );

        Set<Id> validExecutiveIds = new Set<Id>();

        for (
            Sales_Executives__c executive : [
                SELECT Id
                FROM Sales_Executives__c
                WHERE Id IN :selectedExecutiveIds
                AND Store__c = :activity.Assigned_Store__c
            ]
        ) {
            validExecutiveIds.add(executive.Id);
        }

        if (
            validExecutiveIds.size() !=
            selectedExecutiveIds.size()
        ) {
            throw new AuraHandledException(
                'One or more selected Sales Executives do not belong to this store.'
            );
        }

        Form_Activity_Daily_Execution__c execution =
            getOrCreateDailyExecution(
                activity,
                selectedDate,
                effectiveTeamKey
            );

        validateExecutionNotAlreadyInitiated(execution);

        Integer activeMemberCount = 0;
        Set<Id> usedExecutiveIds = new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            ExecutiveChangeInput input =
                changeByDateRowId.get(
                    dateAssignment.Id
                );

            if (input == null) {
                dateAssignment.Active_For_Date__c =
                    false;
                dateAssignment.Actual_Executive__c =
                    null;
            } else {
                Boolean isActive =
                    input.activeForDate == true;

                if (
                    isActive &&
                    input.actualExecutiveId == null
                ) {
                    throw new AuraHandledException(
                        'Please select an executive for every active row.'
                    );
                }

                if (
                    isActive &&
                    usedExecutiveIds.contains(
                        input.actualExecutiveId
                    )
                ) {
                    throw new AuraHandledException(
                        'The same Sales Executive cannot be assigned more than once within the selected team.'
                    );
                }

                dateAssignment.Active_For_Date__c =
                    isActive;

                dateAssignment.Actual_Executive__c =
                    isActive
                    ? input.actualExecutiveId
                    : null;

                if (isActive) {
                    activeMemberCount++;
                    usedExecutiveIds.add(
                        input.actualExecutiveId
                    );
                }
            }

            dateAssignment.Form_Activity_Daily_Execution__c =
                execution.Id;
            dateAssignment.Present__c = false;
            dateAssignment.Actual_Date__c = null;
            dateAssignment.Attendance_Date_Time__c =
                null;
            dateAssignment.Attendance_Marked_By__c =
                null;
        }

        if (activeMemberCount == 0) {
            throw new AuraHandledException(
                'Please keep at least one Sales Executive active for the selected team.'
            );
        }

        update dateAssignments;

        activateExecution(execution);
        updateParentInitiationSnapshot(
            activity,
            selectedDate
        );

        return execution.Id;
    }


    @AuraEnabled
    public static SaveApprovalResponse saveAndSendForApproval(
        Id activityId,
        Date selectedDate,
        String teamKey,
        List<ExecutiveChangeInput> executiveChanges
    ) {
        return saveAndSendForApprovalInternal(
            activityId,
            selectedDate,
            teamKey,
            null,
            executiveChanges
        );
    }

    @AuraEnabled
    public static SaveApprovalResponse saveAndSendForApprovalByLocation(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey,
        List<ExecutiveChangeInput> executiveChanges
    ) {
        return saveAndSendForApprovalInternal(
            activityId,
            selectedDate,
            teamKey,
            locationKey,
            executiveChanges
        );
    }

    private static SaveApprovalResponse saveAndSendForApprovalInternal(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey,
        List<ExecutiveChangeInput> executiveChanges
    ) {
        validateInitiationInput(
            activityId,
            selectedDate
        );

        if (
            executiveChanges == null ||
            executiveChanges.isEmpty()
        ) {
            throw new AuraHandledException(
                'Executive assignment details are required.'
            );
        }

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        Form_Activity__c activity =
            getActivityForInitiation(
                activityId,
                selectedDate
            );

        if (activity.Assigned_Store__c == null) {
            throw new AuraHandledException(
                'A Store must be assigned to the Form Activity.'
            );
        }

        List<Form_Activity_Assigned_Persons_Date__c>
            dateAssignments =
                getDateAssignmentsForUpdate(
                    activityId,
                    selectedDate,
                    effectiveTeamKey,
                    locationKey
                );

        if (dateAssignments.isEmpty()) {
            throw new AuraHandledException(
                'No Sales Executives are assigned for the selected team and date.'
            );
        }

        validateAssignmentsApprovedForStoreAction(
            dateAssignments
        );

        String effectiveTeamName =
            cleanTeamName(
                dateAssignments[0]
                    .Form_Activity_Assigned_Persons__r
                    .Team_Name__c
            );

        Map<Id, Form_Activity_Assigned_Persons_Date__c>
            dateAssignmentById =
                new Map<
                    Id,
                    Form_Activity_Assigned_Persons_Date__c
                >();

        Map<String, String> allowedLocationByKey =
            new Map<String, String>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            dateAssignmentById.put(
                dateAssignment.Id,
                dateAssignment
            );

            String location =
                cleanLocation(
                    dateAssignment.Activity_Location__c
                );

            if (!String.isBlank(location)) {
                allowedLocationByKey.put(
                    normalizeLocationKey(location),
                    location
                );
            }
        }

        Map<Id, ExecutiveChangeInput>
            existingInputByDateAssignmentId =
                new Map<Id, ExecutiveChangeInput>();

        List<ExecutiveChangeInput> newInputs =
            new List<ExecutiveChangeInput>();

        for (ExecutiveChangeInput input : executiveChanges) {
            if (input == null) {
                continue;
            }

            Boolean isNewInput =
                input.isNew == true ||
                input.dateAssignmentId == null;

            if (isNewInput) {
                if (input.actualExecutiveId == null) {
                    throw new AuraHandledException(
                        'Please select an executive for every additional row.'
                    );
                }

                validateRequestedLocation(
                    input.activityLocation,
                    allowedLocationByKey
                );

                newInputs.add(input);
                continue;
            }

            if (
                !dateAssignmentById.containsKey(
                    input.dateAssignmentId
                )
            ) {
                throw new AuraHandledException(
                    'One or more executive assignment rows do not belong to the selected team.'
                );
            }

            if (
                existingInputByDateAssignmentId.containsKey(
                    input.dateAssignmentId
                )
            ) {
                throw new AuraHandledException(
                    'The same executive assignment row was submitted more than once.'
                );
            }

            Boolean isActive =
                input.activeForDate == true;

            if (
                isActive &&
                input.actualExecutiveId == null
            ) {
                throw new AuraHandledException(
                    'Please select an executive for every active row.'
                );
            }

            if (isActive) {
                validateRequestedLocation(
                    input.activityLocation,
                    allowedLocationByKey
                );
            }

            existingInputByDateAssignmentId.put(
                input.dateAssignmentId,
                input
            );
        }

        Set<Id> finalActiveExecutiveIds =
            new Set<Id>();

        Set<String> finalExecutiveLocationKeys =
            new Set<String>();

        Integer finalActiveCount = 0;

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            ExecutiveChangeInput input =
                existingInputByDateAssignmentId.get(
                    dateAssignment.Id
                );

            Boolean isActive =
                input == null
                ? dateAssignment.Active_For_Date__c
                : input.activeForDate == true;

            Id executiveId;

            if (input == null) {
                executiveId =
                    dateAssignment.Actual_Executive__c == null
                    ? dateAssignment
                        .Form_Activity_Assigned_Persons__r
                        .Sales_Executives__c
                    : dateAssignment.Actual_Executive__c;
            } else {
                executiveId =
                    isActive
                    ? input.actualExecutiveId
                    : null;
            }

            if (!isActive) {
                continue;
            }

            if (executiveId == null) {
                throw new AuraHandledException(
                    'Please select an executive for every active row.'
                );
            }

            String effectiveLocation =
                input == null
                    ? dateAssignment.Activity_Location__c
                    : input.activityLocation;

            String executiveLocationKey =
                buildExecutiveLocationKey(
                    executiveId,
                    effectiveLocation
                );

            if (
                !finalExecutiveLocationKeys.add(
                    executiveLocationKey
                )
            ) {
                throw new AuraHandledException(
                    'The same Sales Executive cannot be selected more than once for the same Activity Location within the selected Team.'
                );
            }

            finalActiveExecutiveIds.add(
                executiveId
            );

            finalActiveCount++;
        }

        for (ExecutiveChangeInput input : newInputs) {
            String executiveLocationKey =
                buildExecutiveLocationKey(
                    input.actualExecutiveId,
                    input.activityLocation
                );

            if (
                !finalExecutiveLocationKeys.add(
                    executiveLocationKey
                )
            ) {
                throw new AuraHandledException(
                    'The same Sales Executive cannot be selected more than once for the same Activity Location within the selected Team.'
                );
            }

            finalActiveExecutiveIds.add(
                input.actualExecutiveId
            );

            finalActiveCount++;
        }

        if (finalActiveCount == 0) {
            throw new AuraHandledException(
                'Please keep at least one Sales Executive active for the selected team.'
            );
        }

        validateNoCrossTeamExecutiveAssignments(
            activityId,
            selectedDate,
            effectiveTeamKey,
            finalActiveExecutiveIds
        );

        Set<Id> validExecutiveIds =
            new Set<Id>();

        for (
            Sales_Executives__c executive : [
                SELECT Id
                FROM Sales_Executives__c
                WHERE Id IN :finalActiveExecutiveIds
                AND Store__c = :activity.Assigned_Store__c
            ]
        ) {
            validExecutiveIds.add(executive.Id);
        }

        if (
            validExecutiveIds.size() !=
            finalActiveExecutiveIds.size()
        ) {
            throw new AuraHandledException(
                'One or more selected Sales Executives do not belong to this store.'
            );
        }

        List<Form_Activity_Assigned_Persons_Date__c>
            changedDateAssignments =
                new List<
                    Form_Activity_Assigned_Persons_Date__c
                >();

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            ExecutiveChangeInput input =
                existingInputByDateAssignmentId.get(
                    dateAssignment.Id
                );

            if (input == null) {
                continue;
            }

            Boolean requestedActive =
                input.activeForDate == true;

            Id requestedExecutiveId =
                requestedActive
                ? input.actualExecutiveId
                : null;

            String requestedLocation =
                requestedActive
                ? cleanLocation(input.activityLocation)
                : dateAssignment.Activity_Location__c;

            Boolean hasChanged =
                dateAssignment.Active_For_Date__c !=
                    requestedActive ||
                dateAssignment.Actual_Executive__c !=
                    requestedExecutiveId ||
                normalizeLocationKey(
                    dateAssignment.Activity_Location__c
                ) !=
                normalizeLocationKey(
                    requestedLocation
                );

            if (!hasChanged) {
                continue;
            }

            dateAssignment.Active_For_Date__c =
                requestedActive;

            dateAssignment.Actual_Executive__c =
                requestedExecutiveId;

            if (requestedActive) {
                dateAssignment.Activity_Location__c =
                    requestedLocation;
            }

            changedDateAssignments.add(
                dateAssignment
            );
        }

        if (
            changedDateAssignments.isEmpty() &&
            newInputs.isEmpty()
        ) {
            throw new AuraHandledException(
                'No executive or location changes were found.'
            );
        }

        if (!changedDateAssignments.isEmpty()) {
            update changedDateAssignments;
        }

        List<Form_Activity_Assigned_Persons__c>
            newAssignedPersons =
                new List<
                    Form_Activity_Assigned_Persons__c
                >();

        for (ExecutiveChangeInput input : newInputs) {
            newAssignedPersons.add(
                new Form_Activity_Assigned_Persons__c(
                    Form_Activity__c =
                        activity.Id,
                    Store__c =
                        activity.Assigned_Store__c,
                    Team_Name__c =
                        effectiveTeamName,
                    Sales_Executives__c =
                        input.actualExecutiveId,
                    Is_Active__c =
                        true
                )
            );
        }

        if (!newAssignedPersons.isEmpty()) {
            insert newAssignedPersons;
        }

        List<Form_Activity_Assigned_Persons_Date__c>
            newDateAssignments =
                new List<
                    Form_Activity_Assigned_Persons_Date__c
                >();

        for (
            Integer index = 0;
            index < newInputs.size();
            index++
        ) {
            ExecutiveChangeInput input =
                newInputs[index];

            newDateAssignments.add(
                new Form_Activity_Assigned_Persons_Date__c(
                    Form_Activity_Assigned_Persons__c =
                        newAssignedPersons[index].Id,
                    Target_Date__c =
                        selectedDate,
                    Activity_Location__c =
                        cleanLocation(
                            input.activityLocation
                        ),
                    Store__c =
                        activity.Assigned_Store__c,
                    Actual_Executive__c =
                        input.actualExecutiveId,
                    Active_For_Date__c =
                        true,
                    Is_Active__c =
                        true,
                    Assignment_Status__c =
                        ASSIGNMENT_STATUS_ACTIVE,
                    Approval_Status__c =
                        APPROVAL_STATUS_NOT_SUBMITTED,
                    Approval_Locked__c =
                        false
                )
            );
        }

        if (!newDateAssignments.isEmpty()) {
            insert newDateAssignments;
        }

        Set<Id> finalActiveDateAssignmentIds =
            new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            ExecutiveChangeInput input =
                existingInputByDateAssignmentId.get(
                    dateAssignment.Id
                );

            Boolean isActive =
                input == null
                    ? dateAssignment.Active_For_Date__c
                    : input.activeForDate == true;

            if (isActive) {
                finalActiveDateAssignmentIds.add(
                    dateAssignment.Id
                );
            }
        }

        for (
            Form_Activity_Assigned_Persons_Date__c
                newDateAssignment : newDateAssignments
        ) {
            finalActiveDateAssignmentIds.add(
                newDateAssignment.Id
            );
        }

        Map<String, Object> approvalResult =
            Ctrl_BTLApprovalSubmission.submitRevisedRecords(
                new List<Id>(
                    finalActiveDateAssignmentIds
                ),
                'Store Manager Initiate With Changes'
            );

        SaveApprovalResponse response =
            new SaveApprovalResponse();

        response.updatedExecutiveRecords =
            changedDateAssignments.size();

        response.createdExecutiveRecords =
            newAssignedPersons.size();

        response.taggedApprovalRecords =
            approvalResult == null ||
            approvalResult.get('processedCount') == null
                ? 0
                : Integer.valueOf(
                    String.valueOf(
                        approvalResult.get(
                            'processedCount'
                        )
                    )
                );

        response.message =
            'Executive changes were saved and the complete active composition was sent for custom BTL approval.';

        return response;
    }


    @AuraEnabled
    public static ScheduleActionResponse rescheduleActivity(
        Id activityId,
        Date currentDate,
        Date newDate,
        String teamKey,
        String reason,
        Boolean executeAction
    ) {
        return rescheduleActivityInternal(
            activityId,
            currentDate,
            newDate,
            teamKey,
            null,
            reason,
            executeAction
        );
    }

    @AuraEnabled
    public static ScheduleActionResponse rescheduleActivityByLocation(
        Id activityId,
        Date currentDate,
        Date newDate,
        String teamKey,
        String locationKey,
        String reason,
        Boolean executeAction
    ) {
        return rescheduleActivityInternal(
            activityId,
            currentDate,
            newDate,
            teamKey,
            locationKey,
            reason,
            executeAction
        );
    }

    private static ScheduleActionResponse rescheduleActivityInternal(
        Id activityId,
        Date currentDate,
        Date newDate,
        String teamKey,
        String locationKey,
        String reason,
        Boolean executeAction
    ) {
        validateScheduleActionInput(
            activityId,
            currentDate,
            reason
        );

        if (newDate == null) {
            throw new AuraHandledException(
                'Please select the new activity date.'
            );
        }

        if (newDate < Date.today()) {
            throw new AuraHandledException(
                'The new activity date cannot be before today.'
            );
        }

        if (newDate == currentDate) {
            throw new AuraHandledException(
                'The new activity date must be different from the current activity date.'
            );
        }

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        Form_Activity__c activity =
            getActivityForScheduleManagement(
                activityId,
                currentDate
            );

        if (
            activity.Activity_Date__c != null &&
            newDate < activity.Activity_Date__c
        ) {
            throw new AuraHandledException(
                'The new activity date cannot be before the Form Activity start date.'
            );
        }

        if (
            activity.Activity_End_Date__c != null &&
            newDate > activity.Activity_End_Date__c
        ) {
            throw new AuraHandledException(
                'The new activity date cannot be after the Form Activity end date.'
            );
        }

        List<Form_Activity_Assigned_Persons_Date__c>
            currentAssignments =
                getActivityDateAssignmentsForManagement(
                    activityId,
                    currentDate,
                    effectiveTeamKey,
                    locationKey
                );

        validateAssignmentsApprovedForStoreAction(
            currentAssignments
        );

        validateAssignmentsNotInitiated(
            currentAssignments
        );

        String locationWarning =
            getRescheduleDestinationLocationWarning(
                activityId,
                newDate,
                effectiveTeamKey,
                currentAssignments
            );

        List<ScheduleConflictRow> conflicts =
            getScheduleConflicts(
                currentAssignments,
                newDate
            );

        if (executeAction != true) {
            ScheduleActionResponse previewResponse =
                new ScheduleActionResponse();

            previewResponse.processedRecords = 0;
            previewResponse.newActivityDate = newDate;
            previewResponse.actionType =
                newDate > currentDate
                    ? 'Postponed'
                    : 'Preponed';
            previewResponse.conflicts = conflicts;
            previewResponse.locationWarning =
                locationWarning;
            previewResponse.message =
                conflicts.isEmpty()
                ? 'No executive scheduling conflict was found.'
                : String.valueOf(conflicts.size()) +
                    ' executive scheduling conflict(s) were found.';

            return previewResponse;
        }

        Set<Id> currentDateRecordIds = new Set<Id>();
        Set<Id> assignedPersonIds = new Set<Id>();
        Datetime actionDateTime = System.now();
        String cleanedReason = reason.trim();

        for (
            Form_Activity_Assigned_Persons_Date__c
                currentAssignment : currentAssignments
        ) {
            currentDateRecordIds.add(
                currentAssignment.Id
            );

            assignedPersonIds.add(
                currentAssignment
                    .Form_Activity_Assigned_Persons__c
            );
        }

        Map<Id, Tagged_Approval_Hierarchy__c>
            oldTransactionByDateId =
                getSingleTransactionByDateId(
                    currentDateRecordIds
                );

        if (
            oldTransactionByDateId.size() !=
                currentDateRecordIds.size()
        ) {
            throw new AuraHandledException(
                'An approved transaction could not be found for one or more activity assignments.'
            );
        }

        List<Form_Activity_Assigned_Persons_Date__c>
            newDateAssignments =
                new List<
                    Form_Activity_Assigned_Persons_Date__c
                >();

        List<Tagged_Approval_Hierarchy__c>
            oldTransactionsToUpdate =
                new List<Tagged_Approval_Hierarchy__c>();

        List<Approval_Action_History__c>
            oldHistoryRecords =
                new List<Approval_Action_History__c>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                currentAssignment : currentAssignments
        ) {
            Decimal previousCycle =
                currentAssignment.Reschedule_Cycle__c == null
                    ? 0
                    : currentAssignment.Reschedule_Cycle__c;

            currentAssignment.Is_Active__c = false;
            currentAssignment.Active_For_Date__c = false;
            currentAssignment.Assignment_Status__c =
                ASSIGNMENT_STATUS_RESCHEDULED;
            currentAssignment.Approval_Locked__c = true;
            currentAssignment.Rescheduled_By__c =
                UserInfo.getUserId();
            currentAssignment.Rescheduled_Date_Time__c =
                actionDateTime;
            currentAssignment.Reschedule_Reason__c =
                cleanedReason;

            newDateAssignments.add(
                new Form_Activity_Assigned_Persons_Date__c(
                    Form_Activity_Assigned_Persons__c =
                        currentAssignment
                            .Form_Activity_Assigned_Persons__c,
                    Target_Date__c = newDate,
                    Activity_Location__c =
                        currentAssignment
                            .Activity_Location__c,
                    Store__c =
                        currentAssignment.Store__c,
                    Actual_Executive__c =
                        currentAssignment.Actual_Executive__c,
                    Active_For_Date__c = true,
                    Is_Active__c = true,
                    Assignment_Status__c =
                        ASSIGNMENT_STATUS_ACTIVE,
                    Approval_Status__c =
                        APPROVAL_STATUS_NOT_SUBMITTED,
                    Approval_Locked__c = false,
                    Rescheduled_From__c =
                        currentAssignment.Id,
                    Rescheduled_By__c =
                        UserInfo.getUserId(),
                    Rescheduled_Date_Time__c =
                        actionDateTime,
                    Reschedule_Reason__c =
                        cleanedReason,
                    Reschedule_Cycle__c =
                        previousCycle + 1
                )
            );

            Tagged_Approval_Hierarchy__c oldTransaction =
                oldTransactionByDateId.get(
                    currentAssignment.Id
                );

            String previousApprovalStatus =
                oldTransaction.Approval_Status__c;

            oldTransaction.Last_Action__c =
                ACTION_RESCHEDULED;
            oldTransaction.Last_Action_By__c =
                UserInfo.getUserId();
            oldTransaction.Last_Action_Date_Time__c =
                actionDateTime;
            oldTransaction.Last_Action_Comments__c =
                buildRescheduleComments(
                    currentDate,
                    newDate,
                    cleanedReason
                );

            oldTransactionsToUpdate.add(
                oldTransaction
            );

            oldHistoryRecords.add(
                new Approval_Action_History__c(
                    Approval_Transaction__c =
                        oldTransaction.Id,
                    Approval_Level__c =
                        oldTransaction
                            .Current_Approval_Level__c,
                    Action__c =
                        ACTION_RESCHEDULED,
                    Action_By__c =
                        UserInfo.getUserId(),
                    Action_Date_Time__c =
                        actionDateTime,
                    Comments__c =
                        buildRescheduleComments(
                            currentDate,
                            newDate,
                            cleanedReason
                        ),
                    Previous_Status__c =
                        previousApprovalStatus,
                    New_Status__c =
                        previousApprovalStatus,
                    Submission_Cycle__c =
                        oldTransaction
                            .Submission_Cycle__c
                )
            );
        }

        update currentAssignments;
        insert newDateAssignments;
        update oldTransactionsToUpdate;
        insert oldHistoryRecords;

        List<Form_Activity_Assigned_Persons__c>
            parentsToReactivate =
                new List<
                    Form_Activity_Assigned_Persons__c
                >();

        for (Id assignedPersonId : assignedPersonIds) {
            parentsToReactivate.add(
                new Form_Activity_Assigned_Persons__c(
                    Id = assignedPersonId,
                    Is_Active__c = true
                )
            );
        }

        if (!parentsToReactivate.isEmpty()) {
            update parentsToReactivate;
        }

        List<Id> newDateAssignmentIds =
            new List<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                newDateAssignment : newDateAssignments
        ) {
            newDateAssignmentIds.add(
                newDateAssignment.Id
            );
        }

        Ctrl_BTLApprovalSubmission.submitSelectedRecords(
                newDateAssignmentIds,
                buildRescheduleComments(
                    currentDate,
                    newDate,
                    cleanedReason
                )
            );

        ScheduleActionResponse response =
            new ScheduleActionResponse();

        response.processedRecords =
            newDateAssignments.size();
        response.newActivityDate =
            newDate;
        response.actionType =
            newDate > currentDate
                ? 'Postponed'
                : 'Preponed';
        response.conflicts = conflicts;
        response.locationWarning =
            locationWarning;
        response.message =
            String.valueOf(
                newDateAssignments.size()
            ) +
            ' manpower assignment(s) for the selected Team were ' +
            response.actionType.toLowerCase() +
            ' and sent for approval.';

        return response;
    }

    @AuraEnabled
    public static ScheduleActionResponse dropActivity(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String reason
    ) {
        return dropActivityInternal(
            activityId,
            selectedDate,
            teamKey,
            null,
            reason
        );
    }

    @AuraEnabled
    public static ScheduleActionResponse dropActivityByLocation(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey,
        String reason
    ) {
        return dropActivityInternal(
            activityId,
            selectedDate,
            teamKey,
            locationKey,
            reason
        );
    }

    private static ScheduleActionResponse dropActivityInternal(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey,
        String reason
    ) {
        validateScheduleActionInput(
            activityId,
            selectedDate,
            reason
        );

        getActivityForScheduleManagement(
            activityId,
            selectedDate
        );

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        List<Form_Activity_Assigned_Persons_Date__c>
            currentAssignments =
                getActivityDateAssignmentsForManagement(
                    activityId,
                    selectedDate,
                    effectiveTeamKey,
                    locationKey
                );

        validateAssignmentsApprovedForStoreAction(
            currentAssignments
        );

        validateAssignmentsNotInitiated(
            currentAssignments
        );

        Set<Id> currentDateRecordIds = new Set<Id>();
        Set<Id> assignedPersonIds = new Set<Id>();
        Datetime actionDateTime = System.now();
        String cleanedReason = reason.trim();

        for (
            Form_Activity_Assigned_Persons_Date__c
                currentAssignment : currentAssignments
        ) {
            currentDateRecordIds.add(
                currentAssignment.Id
            );

            assignedPersonIds.add(
                currentAssignment
                    .Form_Activity_Assigned_Persons__c
            );
        }

        Map<Id, Tagged_Approval_Hierarchy__c>
            transactionByDateId =
                getSingleTransactionByDateId(
                    currentDateRecordIds
                );

        if (
            transactionByDateId.size() !=
                currentDateRecordIds.size()
        ) {
            throw new AuraHandledException(
                'An approved transaction could not be found for one or more activity assignments.'
            );
        }

        List<Tagged_Approval_Hierarchy__c>
            transactionsToUpdate =
                new List<Tagged_Approval_Hierarchy__c>();

        List<Approval_Action_History__c>
            historyRecords =
                new List<Approval_Action_History__c>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                currentAssignment : currentAssignments
        ) {
            currentAssignment.Is_Active__c = false;
            currentAssignment.Active_For_Date__c = false;
            currentAssignment.Assignment_Status__c =
                ASSIGNMENT_STATUS_DROPPED;
            currentAssignment.Approval_Status__c =
                APPROVAL_STATUS_DROPPED;
            currentAssignment.Approval_Locked__c = true;

            Tagged_Approval_Hierarchy__c transactionRecord =
                transactionByDateId.get(
                    currentAssignment.Id
                );

            String previousStatus =
                transactionRecord.Approval_Status__c;

            Id previousApprovalLevelId =
                transactionRecord
                    .Current_Approval_Level__c;

            transactionRecord.Approval_Status__c =
                APPROVAL_STATUS_DROPPED;
            transactionRecord.Current_Approval_Level__c =
                null;
            transactionRecord.Pending_With__c =
                null;
            transactionRecord.Last_Action__c =
                ACTION_ACTIVITY_DROPPED;
            transactionRecord.Last_Action_By__c =
                UserInfo.getUserId();
            transactionRecord.Last_Action_Date_Time__c =
                actionDateTime;
            transactionRecord.Last_Action_Comments__c =
                cleanedReason;
            transactionRecord.Dropped_By__c =
                UserInfo.getUserId();
            transactionRecord.Dropped_Date_Time__c =
                actionDateTime;
            transactionRecord.Drop_Reason__c =
                cleanedReason;

            transactionsToUpdate.add(
                transactionRecord
            );

            historyRecords.add(
                new Approval_Action_History__c(
                    Approval_Transaction__c =
                        transactionRecord.Id,
                    Approval_Level__c =
                        previousApprovalLevelId,
                    Action__c =
                        ACTION_ACTIVITY_DROPPED,
                    Action_By__c =
                        UserInfo.getUserId(),
                    Action_Date_Time__c =
                        actionDateTime,
                    Comments__c =
                        cleanedReason,
                    Previous_Status__c =
                        previousStatus,
                    New_Status__c =
                        APPROVAL_STATUS_DROPPED,
                    Submission_Cycle__c =
                        transactionRecord
                            .Submission_Cycle__c
                )
            );
        }

        update currentAssignments;
        update transactionsToUpdate;
        insert historyRecords;

        deactivateAssignedPersonsWithoutActiveDates(
            assignedPersonIds
        );

        ScheduleActionResponse response =
            new ScheduleActionResponse();

        response.processedRecords =
            currentAssignments.size();
        response.actionType =
            'Dropped';
        response.message =
            String.valueOf(
                currentAssignments.size()
            ) +
            ' manpower assignment(s) for the selected Team were dropped successfully.';

        return response;
    }

    private static List<ScheduleConflictRow>
        getScheduleConflicts(
            List<Form_Activity_Assigned_Persons_Date__c>
                movingAssignments,
            Date targetDate
        ) {
        List<ScheduleConflictRow> conflicts =
            new List<ScheduleConflictRow>();

        if (
            movingAssignments == null ||
            movingAssignments.isEmpty() ||
            targetDate == null
        ) {
            return conflicts;
        }

        Set<Id> movingExecutiveIds = new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c assignment :
                movingAssignments
        ) {
            Id executiveId =
                assignment.Actual_Executive__c != null
                ? assignment.Actual_Executive__c
                : assignment
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__c;

            if (executiveId != null) {
                movingExecutiveIds.add(executiveId);
            }
        }

        if (movingExecutiveIds.isEmpty()) {
            return conflicts;
        }

        Map<Id, Form_Activity_Assigned_Persons_Date__c>
            candidateById =
                new Map<Id, Form_Activity_Assigned_Persons_Date__c>();

        for (
            Form_Activity_Assigned_Persons_Date__c candidate : [
                SELECT Id,
                       Actual_Executive__c,
                       Actual_Executive__r.Name,
                       Active_For_Date__c,
                       Is_Active__c,
                       Assignment_Status__c,
                       Approval_Status__c,
                       Form_Activity_Assigned_Persons__r.Sales_Executives__c,
                       Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                       Form_Activity_Assigned_Persons__r.Team_Name__c,
                       Form_Activity_Assigned_Persons__r.Form_Activity__c,
                       Form_Activity_Assigned_Persons__r.Form_Activity__r.Name,
                       Form_Activity_Assigned_Persons__r.Form_Activity__r.Activity_Name__c
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Target_Date__c = :targetDate
                AND Active_For_Date__c = true
                AND Actual_Executive__c IN :movingExecutiveIds
            ]
        ) {
            candidateById.put(candidate.Id, candidate);
        }

        for (
            Form_Activity_Assigned_Persons_Date__c candidate : [
                SELECT Id,
                       Actual_Executive__c,
                       Actual_Executive__r.Name,
                       Active_For_Date__c,
                       Is_Active__c,
                       Assignment_Status__c,
                       Approval_Status__c,
                       Form_Activity_Assigned_Persons__r.Sales_Executives__c,
                       Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                       Form_Activity_Assigned_Persons__r.Team_Name__c,
                       Form_Activity_Assigned_Persons__r.Form_Activity__c,
                       Form_Activity_Assigned_Persons__r.Form_Activity__r.Name,
                       Form_Activity_Assigned_Persons__r.Form_Activity__r.Activity_Name__c
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Target_Date__c = :targetDate
                AND Active_For_Date__c = true
                AND Form_Activity_Assigned_Persons__r.Sales_Executives__c
                    IN :movingExecutiveIds
            ]
        ) {
            candidateById.put(candidate.Id, candidate);
        }

        Set<String> conflictKeys = new Set<String>();

        for (
            Form_Activity_Assigned_Persons_Date__c candidate :
                candidateById.values()
        ) {
            if (!isOperationalAssignment(candidate)) {
                continue;
            }

            Id effectiveExecutiveId =
                candidate.Actual_Executive__c != null
                ? candidate.Actual_Executive__c
                : candidate
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__c;

            if (
                effectiveExecutiveId == null ||
                !movingExecutiveIds.contains(effectiveExecutiveId)
            ) {
                continue;
            }

            Id existingActivityId =
                candidate
                    .Form_Activity_Assigned_Persons__r
                    .Form_Activity__c;

            String existingTeamName =
                cleanTeamName(
                    candidate
                        .Form_Activity_Assigned_Persons__r
                        .Team_Name__c
                );

            String conflictKey =
                String.valueOf(effectiveExecutiveId) +
                '|' +
                String.valueOf(existingActivityId) +
                '|' +
                buildTeamKey(existingTeamName);

            if (!conflictKeys.add(conflictKey)) {
                continue;
            }

            ScheduleConflictRow conflict =
                new ScheduleConflictRow();

            conflict.executiveId = effectiveExecutiveId;
            conflict.executiveName =
                candidate.Actual_Executive__c != null &&
                candidate.Actual_Executive__r != null
                ? candidate.Actual_Executive__r.Name
                : candidate
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__r == null
                    ? 'Sales Executive'
                    : candidate
                        .Form_Activity_Assigned_Persons__r
                        .Sales_Executives__r.Name;

            conflict.activityId = existingActivityId;

            Form_Activity__c existingActivity =
                candidate
                    .Form_Activity_Assigned_Persons__r
                    .Form_Activity__r;

            conflict.activityName =
                existingActivity == null
                ? 'Another Activity'
                : String.isBlank(
                    existingActivity.Activity_Name__c
                )
                    ? existingActivity.Name
                    : existingActivity.Activity_Name__c;

            conflict.teamName =
                String.isBlank(existingTeamName)
                ? 'No Team'
                : existingTeamName;

            conflicts.add(conflict);
        }

        return conflicts;
    }

    private static void validateScheduleActionInput(
        Id activityId,
        Date selectedDate,
        String reason
    ) {
        if (activityId == null || selectedDate == null) {
            throw new AuraHandledException(
                'Form Activity and activity date are required.'
            );
        }

        if (selectedDate < Date.today()) {
            throw new AuraHandledException(
                'A past activity is Date Over and cannot be rescheduled or dropped.'
            );
        }

        if (String.isBlank(reason)) {
            throw new AuraHandledException(
                'Reason is required.'
            );
        }
    }

    private static Form_Activity__c
        getActivityForScheduleManagement(
            Id activityId,
            Date selectedDate
        ) {
        Form_Activity__c activity = [
            SELECT Id,
                   Name,
                   Activity_Name__c,
                   Activity_Date__c,
                   Activity_End_Date__c,
                   Assigned_Store__c
            FROM Form_Activity__c
            WHERE Id = :activityId
            LIMIT 1
            FOR UPDATE
        ];

        AccessContext accessContext =
            getAccessContext();

        if (
            !accessContext.isSystemAdministrator &&
            activity.Assigned_Store__c !=
                accessContext.storeId
        ) {
            throw new AuraHandledException(
                'You do not have access to manage this store activity.'
            );
        }

        if (
            activity.Activity_End_Date__c != null &&
            selectedDate > activity.Activity_End_Date__c
        ) {
            throw new AuraHandledException(
                'The selected date is after the Form Activity end date.'
            );
        }

        return activity;
    }

    private static List<
        Form_Activity_Assigned_Persons_Date__c
    > getActivityDateAssignmentsForManagement(
        Id activityId,
        Date selectedDate,
        String teamKey
    ) {
        return getActivityDateAssignmentsForManagement(
            activityId,
            selectedDate,
            teamKey,
            null
        );
    }

    private static List<
        Form_Activity_Assigned_Persons_Date__c
    > getActivityDateAssignmentsForManagement(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey
    ) {
        List<Form_Activity_Assigned_Persons_Date__c>
            assignments =
                new List<
                    Form_Activity_Assigned_Persons_Date__c
                >();

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        String effectiveLocationKey =
            locationKey == null
                ? null
                : normalizeRequestedLocationKey(
                    locationKey
                );

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : [
                    SELECT Id,
                           Name,
                           Target_Date__c,
                           Activity_Location__c,
                           Store__c,
                           Actual_Executive__c,
                           Active_For_Date__c,
                           Is_Active__c,
                           Assignment_Status__c,
                           Approval_Status__c,
                           Approval_Locked__c,
                           Rescheduled_From__c,
                           Rescheduled_By__c,
                           Rescheduled_Date_Time__c,
                           Reschedule_Reason__c,
                           Reschedule_Cycle__c,
                           Form_Activity_Daily_Execution__c,
                           Form_Activity_Daily_Execution__r.Status__c,
                           Form_Activity_Daily_Execution__r.Store_Manager_Approved__c,
                           Form_Activity_Daily_Execution__r.BTL_Activity_Live__c,
                           Form_Activity_Assigned_Persons__c,
                           Form_Activity_Assigned_Persons__r.Form_Activity__c,
                           Form_Activity_Assigned_Persons__r.Team_Name__c,
                           Form_Activity_Assigned_Persons__r.Sales_Executives__c
                    FROM Form_Activity_Assigned_Persons_Date__c
                    WHERE Form_Activity_Assigned_Persons__r.Form_Activity__c
                        = :activityId
                    AND Target_Date__c = :selectedDate
                    FOR UPDATE
                ]
        ) {
            String assignmentTeamKey =
                buildTeamKey(
                    dateAssignment
                        .Form_Activity_Assigned_Persons__r
                        .Team_Name__c
                );

            String assignmentLocationKey =
                buildLocationKey(
                    dateAssignment.Activity_Location__c
                );

            if (
                assignmentTeamKey == effectiveTeamKey &&
                (
                    effectiveLocationKey == null ||
                    assignmentLocationKey ==
                        effectiveLocationKey
                ) &&
                isOperationalAssignment(dateAssignment)
            ) {
                assignments.add(
                    dateAssignment
                );
            }
        }

        if (assignments.isEmpty()) {
            throw new AuraHandledException(
                'No active manpower assignments were found for the selected Team, Activity Location, and date.'
            );
        }

        return assignments;
    }

    private static String getRescheduleDestinationLocationWarning(
        Id activityId,
        Date newDate,
        String teamKey,
        List<Form_Activity_Assigned_Persons_Date__c>
            currentAssignments
    ) {
        if (
            activityId == null ||
            newDate == null ||
            currentAssignments == null ||
            currentAssignments.isEmpty()
        ) {
            return null;
        }

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        String requestedLocation =
            currentAssignments[0].Activity_Location__c;

        String requestedLocationKey =
            buildLocationKey(requestedLocation);

        Set<String> existingDifferentLocations =
            new Set<String>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                targetAssignment : [
                    SELECT Id,
                           Activity_Location__c,
                           Is_Active__c,
                           Assignment_Status__c,
                           Approval_Status__c,
                           Form_Activity_Assigned_Persons__r.Team_Name__c
                    FROM Form_Activity_Assigned_Persons_Date__c
                    WHERE Form_Activity_Assigned_Persons__r.Form_Activity__c
                        = :activityId
                    AND Target_Date__c = :newDate
                    FOR UPDATE
                ]
        ) {
            if (!isOperationalAssignment(targetAssignment)) {
                continue;
            }

            String targetTeamKey =
                buildTeamKey(
                    targetAssignment
                        .Form_Activity_Assigned_Persons__r
                        .Team_Name__c
                );

            if (targetTeamKey != effectiveTeamKey) {
                continue;
            }

            String targetLocationKey =
                buildLocationKey(
                    targetAssignment.Activity_Location__c
                );

            if (
                targetLocationKey ==
                    requestedLocationKey
            ) {
                continue;
            }

            existingDifferentLocations.add(
                String.isBlank(
                    targetAssignment.Activity_Location__c
                )
                    ? 'No Location'
                    : targetAssignment
                        .Activity_Location__c
                        .trim()
            );
        }

        if (existingDifferentLocations.isEmpty()) {
            return null;
        }

        List<String> locationNames =
            new List<String>();
        locationNames.addAll(
            existingDifferentLocations
        );
        locationNames.sort();

        String movingLocation =
            String.isBlank(requestedLocation)
                ? 'No Location'
                : requestedLocation.trim();

        return (
            'Warning: The selected Team already has Activity Location ' +
            (locationNames.size() == 1
                ? '"' + locationNames[0] + '"'
                : '"' + String.join(locationNames, '", "') + '"') +
            ' for ' +
            String.valueOf(newDate) +
            '. You are moving Activity Location "' +
            movingLocation +
            '" to the same Team and date. ' +
            'If you continue, both Activity Locations will remain as separate location-wise activity groups.'
        );
    }

    private static void validateAssignmentsNotInitiated(
        List<Form_Activity_Assigned_Persons_Date__c>
            dateAssignments
    ) {
        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            if (
                dateAssignment
                    .Form_Activity_Daily_Execution__c !=
                        null &&
                (
                    dateAssignment
                        .Form_Activity_Daily_Execution__r
                        .Store_Manager_Approved__c ==
                            true ||
                    dateAssignment
                        .Form_Activity_Daily_Execution__r
                        .BTL_Activity_Live__c ==
                            true ||
                    dateAssignment
                        .Form_Activity_Daily_Execution__r
                        .Status__c ==
                            STATUS_LIVE ||
                    dateAssignment
                        .Form_Activity_Daily_Execution__r
                        .Status__c ==
                            STATUS_IN_PROGRESS ||
                    dateAssignment
                        .Form_Activity_Daily_Execution__r
                        .Status__c ==
                            STATUS_COMPLETED
                )
            ) {
                throw new AuraHandledException(
                    'An activity that is already initiated, live, in progress, or completed cannot be rescheduled or dropped.'
                );
            }
        }
    }

    private static Map<Id, Tagged_Approval_Hierarchy__c>
        getSingleTransactionByDateId(
            Set<Id> dateAssignmentIds
        ) {
        Map<Id, Tagged_Approval_Hierarchy__c>
            transactionByDateId =
                new Map<
                    Id,
                    Tagged_Approval_Hierarchy__c
                >();

        for (
            Tagged_Approval_Hierarchy__c
                transactionRecord : [
                    SELECT Id,
                           Approval_Status__c,
                           Current_Approval_Level__c,
                           Pending_With__c,
                           Submission_Cycle__c,
                           Last_Action__c,
                           Last_Action_By__c,
                           Last_Action_Date_Time__c,
                           Last_Action_Comments__c,
                           Dropped_By__c,
                           Dropped_Date_Time__c,
                           Drop_Reason__c,
                           Form_Activity_Assigned_Persons_Date__c
                    FROM Tagged_Approval_Hierarchy__c
                    WHERE Form_Activity_Assigned_Persons_Date__c
                        IN :dateAssignmentIds
                    FOR UPDATE
                ]
        ) {
            Id dateRecordId =
                transactionRecord
                    .Form_Activity_Assigned_Persons_Date__c;

            if (
                transactionByDateId.containsKey(
                    dateRecordId
                )
            ) {
                throw new AuraHandledException(
                    'Multiple approval transactions exist for one or more activity assignments.'
                );
            }

            transactionByDateId.put(
                dateRecordId,
                transactionRecord
            );
        }

        return transactionByDateId;
    }

    private static void
        deactivateAssignedPersonsWithoutActiveDates(
            Set<Id> assignedPersonIds
        ) {
        if (
            assignedPersonIds == null ||
            assignedPersonIds.isEmpty()
        ) {
            return;
        }

        Set<Id> parentIdsWithActiveDates =
            new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c
                remainingDateRecord : [
                    SELECT Id,
                           Form_Activity_Assigned_Persons__c,
                           Is_Active__c,
                           Assignment_Status__c,
                           Approval_Status__c
                    FROM Form_Activity_Assigned_Persons_Date__c
                    WHERE Form_Activity_Assigned_Persons__c
                        IN :assignedPersonIds
                ]
        ) {
            if (
                isOperationalAssignment(
                    remainingDateRecord
                )
            ) {
                parentIdsWithActiveDates.add(
                    remainingDateRecord
                        .Form_Activity_Assigned_Persons__c
                );
            }
        }

        List<Form_Activity_Assigned_Persons__c>
            parentsToDeactivate =
                new List<
                    Form_Activity_Assigned_Persons__c
                >();

        for (Id assignedPersonId : assignedPersonIds) {
            if (
                !parentIdsWithActiveDates.contains(
                    assignedPersonId
                )
            ) {
                parentsToDeactivate.add(
                    new Form_Activity_Assigned_Persons__c(
                        Id = assignedPersonId,
                        Is_Active__c = false
                    )
                );
            }
        }

        if (!parentsToDeactivate.isEmpty()) {
            update parentsToDeactivate;
        }
    }

    private static String buildRescheduleComments(
        Date currentDate,
        Date newDate,
        String reason
    ) {
        String movementType =
            newDate > currentDate
                ? 'Postponed'
                : 'Preponed';

        return movementType +
            ' from ' +
            String.valueOf(currentDate) +
            ' to ' +
            String.valueOf(newDate) +
            '. Reason: ' +
            reason;
    }

    private static void validateRequestedLocation(
        String requestedLocation,
        Map<String, String> allowedLocationByKey
    ) {
        String cleanedLocation =
            cleanLocation(requestedLocation);

        if (String.isBlank(cleanedLocation)) {
            throw new AuraHandledException(
                'Please select an Activity Location for every active executive.'
            );
        }

        if (
            !allowedLocationByKey.containsKey(
                normalizeLocationKey(
                    cleanedLocation
                )
            )
        ) {
            throw new AuraHandledException(
                'The selected Activity Location is not available for this Team, Form Activity, and Date.'
            );
        }
    }

    private static String cleanLocation(
        String location
    ) {
        return String.isBlank(location)
            ? null
            : location.trim();
    }

    private static String normalizeLocationKey(
        String location
    ) {
        String cleanedLocation =
            cleanLocation(location);

        return String.isBlank(cleanedLocation)
            ? ''
            : cleanedLocation.toLowerCase();
    }

    private static String buildExecutiveLocationKey(
        Id executiveId,
        String activityLocation
    ) {
        return (
            executiveId == null
                ? ''
                : String.valueOf(executiveId)
        ) +
        '||' +
        normalizeLocationKey(
            activityLocation
        );
    }

    private static String buildLocationKey(
        String location
    ) {
        String normalizedLocation =
            normalizeLocationKey(location);

        if (String.isBlank(normalizedLocation)) {
            return NO_LOCATION_KEY;
        }

        Blob digest = Crypto.generateDigest(
            'SHA-256',
            Blob.valueOf(normalizedLocation)
        );

        return EncodingUtil.convertToHex(digest);
    }

    private static String normalizeRequestedLocationKey(
        String locationKey
    ) {
        return String.isBlank(locationKey)
            ? NO_LOCATION_KEY
            : locationKey.trim();
    }

    private static void validateInitiationInput(
        Id activityId,
        Date selectedDate
    ) {
        if (activityId == null || selectedDate == null) {
            throw new AuraHandledException(
                'Activity and date are required.'
            );
        }

        if (selectedDate != Date.today()) {
            throw new AuraHandledException(
                'An activity can be initiated only for today.'
            );
        }
    }

    private static Form_Activity__c
        getActivityForInitiation(
            Id activityId,
            Date selectedDate
        ) {
        Form_Activity__c activity = [
            SELECT Id,
                   Name,
                   Assigned_Store__c,
                   Activity_Date__c,
                   Activity_End_Date__c,
                   Store_Manager_Approved__c,
                   BTL_Activity_Live__c,
                   BTL_Live_Date__c,
                   BTL_Initiated_Date_Time__c,
                   BTL_Initiated_By__c
            FROM Form_Activity__c
            WHERE Id = :activityId
            LIMIT 1
            FOR UPDATE
        ];

        if (
            activity.Activity_Date__c == null ||
            activity.Activity_End_Date__c == null ||
            selectedDate < activity.Activity_Date__c ||
            selectedDate > activity.Activity_End_Date__c
        ) {
            throw new AuraHandledException(
                'The selected date is outside the activity duration.'
            );
        }

        AccessContext accessContext = getAccessContext();

        if (
            !accessContext.isSystemAdministrator &&
            activity.Assigned_Store__c !=
                accessContext.storeId
        ) {
            throw new AuraHandledException(
                'You do not have access to initiate this store activity.'
            );
        }

        return activity;
    }

    private static List<
        Form_Activity_Assigned_Persons_Date__c
    > getDateAssignmentsForUpdate(
        Id activityId,
        Date selectedDate,
        String teamKey
    ) {
        return getDateAssignmentsForUpdate(
            activityId,
            selectedDate,
            teamKey,
            null
        );
    }

    private static List<
        Form_Activity_Assigned_Persons_Date__c
    > getDateAssignmentsForUpdate(
        Id activityId,
        Date selectedDate,
        String teamKey,
        String locationKey
    ) {
        List<Form_Activity_Assigned_Persons_Date__c>
            matchingAssignments =
                new List<Form_Activity_Assigned_Persons_Date__c>();

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        String effectiveLocationKey =
            locationKey == null
                ? null
                : normalizeRequestedLocationKey(
                    locationKey
                );

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : [
                    SELECT Id,
                           Target_Date__c,
                           Actual_Date__c,
                           Activity_Location__c,
                           Form_Activity_Daily_Execution__c,
                           Actual_Executive__c,
                           Active_For_Date__c,
                           Is_Active__c,
                           Assignment_Status__c,
                           Approval_Status__c,
                           Approval_Locked__c,
                           Present__c,
                           Attendance_Date_Time__c,
                           Attendance_Marked_By__c,
                           Form_Activity_Assigned_Persons__c,
                           Form_Activity_Assigned_Persons__r.Team_Name__c,
                           Form_Activity_Assigned_Persons__r.Sales_Executives__c
                    FROM Form_Activity_Assigned_Persons_Date__c
                    WHERE Form_Activity_Assigned_Persons__r.Form_Activity__c
                        = :activityId
                    AND Target_Date__c = :selectedDate
                    FOR UPDATE
                ]
        ) {
            String assignmentTeamKey =
                buildTeamKey(
                    dateAssignment
                        .Form_Activity_Assigned_Persons__r
                        .Team_Name__c
                );

            String assignmentLocationKey =
                buildLocationKey(
                    dateAssignment.Activity_Location__c
                );

            if (
                assignmentTeamKey == effectiveTeamKey &&
                (
                    effectiveLocationKey == null ||
                    assignmentLocationKey ==
                        effectiveLocationKey
                ) &&
                isOperationalAssignment(dateAssignment)
            ) {
                matchingAssignments.add(
                    dateAssignment
                );
            }
        }

        return matchingAssignments;
    }

    private static void
        validateAssignmentsApprovedForStoreAction(
            List<
                Form_Activity_Assigned_Persons_Date__c
            > dateAssignments
        ) {
        if (
            dateAssignments == null ||
            dateAssignments.isEmpty()
        ) {
            throw new AuraHandledException(
                'No active Sales Executive assignments were found for this Team activity.'
            );
        }

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : dateAssignments
        ) {
            if (
                dateAssignment.Approval_Status__c !=
                    APPROVAL_STATUS_APPROVED
            ) {
                throw new AuraHandledException(
                    'This Team activity is Pending For Approval. Store Manager actions are available only after final approval.'
                );
            }
        }
    }

    private static Boolean isOperationalAssignment(
        Form_Activity_Assigned_Persons_Date__c
            dateAssignment
    ) {
        if (dateAssignment == null) {
            return false;
        }

        if (
            dateAssignment.Approval_Status__c ==
                APPROVAL_STATUS_DROPPED ||
            dateAssignment.Assignment_Status__c ==
                ASSIGNMENT_STATUS_DROPPED ||
            dateAssignment.Assignment_Status__c ==
                ASSIGNMENT_STATUS_REPLACED ||
            dateAssignment.Assignment_Status__c ==
                ASSIGNMENT_STATUS_RESCHEDULED
        ) {
            return false;
        }

        if (dateAssignment.Is_Active__c == true) {
            return true;
        }

        return String.isBlank(
            dateAssignment.Assignment_Status__c
        );
    }


    private static void incrementActivityCount(
        Map<Id, Integer> countByActivityId,
        Id activityId
    ) {
        countByActivityId.put(
            activityId,
            getActivityCount(
                countByActivityId,
                activityId
            ) + 1
        );
    }

    private static Integer getActivityCount(
        Map<Id, Integer> countByActivityId,
        Id activityId
    ) {
        return countByActivityId.containsKey(
            activityId
        )
            ? countByActivityId.get(
                activityId
            )
            : 0;
    }

    private static void incrementGroupCount(
        Map<String, Integer> countByGroupKey,
        String groupKey
    ) {
        countByGroupKey.put(
            groupKey,
            getGroupCount(
                countByGroupKey,
                groupKey
            ) + 1
        );
    }

    private static Integer getGroupCount(
        Map<String, Integer> countByGroupKey,
        String groupKey
    ) {
        return countByGroupKey.containsKey(groupKey)
            ? countByGroupKey.get(groupKey)
            : 0;
    }

    private static void
        validateNoCrossTeamExecutiveAssignments(
            Id activityId,
            Date selectedDate,
            String teamKey,
            Set<Id> selectedExecutiveIds
        ) {
        if (
            selectedExecutiveIds == null ||
            selectedExecutiveIds.isEmpty()
        ) {
            return;
        }

        Set<Id> executiveIdsInOtherTeams =
            getExecutiveIdsAssignedToOtherTeams(
                activityId,
                selectedDate,
                teamKey
            );

        for (Id executiveId : selectedExecutiveIds) {
            if (
                executiveIdsInOtherTeams.contains(
                    executiveId
                )
            ) {
                throw new AuraHandledException(
                    'A Sales Executive cannot be assigned to more than one Team for the same Form Activity.'
                );
            }
        }
    }

    private static Set<Id>
        getExecutiveIdsAssignedToOtherTeams(
            Id activityId,
            Date selectedDate,
            String teamKey
        ) {
        Set<Id> executiveIds =
            new Set<Id>();

        if (activityId == null) {
            return executiveIds;
        }

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        for (
            Form_Activity_Assigned_Persons__c
                assignedPerson : [
                    SELECT Id,
                           Team_Name__c,
                           Sales_Executives__c
                    FROM Form_Activity_Assigned_Persons__c
                    WHERE Form_Activity__c = :activityId
                ]
        ) {
            if (
                buildTeamKey(
                    assignedPerson.Team_Name__c
                ) == effectiveTeamKey
            ) {
                continue;
            }

            if (
                assignedPerson.Sales_Executives__c !=
                    null
            ) {
                executiveIds.add(
                    assignedPerson.Sales_Executives__c
                );
            }
        }

        if (selectedDate == null) {
            return executiveIds;
        }

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : [
                    SELECT Id,
                           Actual_Executive__c,
                           Active_For_Date__c,
                           Form_Activity_Assigned_Persons__r.Team_Name__c
                    FROM Form_Activity_Assigned_Persons_Date__c
                    WHERE Form_Activity_Assigned_Persons__r.Form_Activity__c
                        = :activityId
                    AND Target_Date__c = :selectedDate
                    AND Active_For_Date__c = true
                    AND Actual_Executive__c != null
                ]
        ) {
            if (
                buildTeamKey(
                    dateAssignment
                        .Form_Activity_Assigned_Persons__r
                        .Team_Name__c
                ) == effectiveTeamKey
            ) {
                continue;
            }

            executiveIds.add(
                dateAssignment.Actual_Executive__c
            );
        }

        return executiveIds;
    }

    private static Set<Id>
        getExecutiveIdsAssignedToTeam(
            Id activityId,
            Date selectedDate,
            String teamKey
        ) {
        Set<Id> executiveIds =
            new Set<Id>();

        if (activityId == null) {
            return executiveIds;
        }

        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        for (
            Form_Activity_Assigned_Persons__c
                assignedPerson : [
                    SELECT Id,
                           Team_Name__c,
                           Sales_Executives__c
                    FROM Form_Activity_Assigned_Persons__c
                    WHERE Form_Activity__c = :activityId
                ]
        ) {
            if (
                buildTeamKey(
                    assignedPerson.Team_Name__c
                ) != effectiveTeamKey
            ) {
                continue;
            }

            if (
                assignedPerson.Sales_Executives__c !=
                    null
            ) {
                executiveIds.add(
                    assignedPerson.Sales_Executives__c
                );
            }
        }

        if (selectedDate == null) {
            return executiveIds;
        }

        for (
            Form_Activity_Assigned_Persons_Date__c
                dateAssignment : [
                    SELECT Id,
                           Actual_Executive__c,
                           Form_Activity_Assigned_Persons__r.Team_Name__c
                    FROM Form_Activity_Assigned_Persons_Date__c
                    WHERE Form_Activity_Assigned_Persons__r.Form_Activity__c
                        = :activityId
                    AND Target_Date__c = :selectedDate
                    AND Actual_Executive__c != null
                ]
        ) {
            if (
                buildTeamKey(
                    dateAssignment
                        .Form_Activity_Assigned_Persons__r
                        .Team_Name__c
                ) != effectiveTeamKey
            ) {
                continue;
            }

            executiveIds.add(
                dateAssignment.Actual_Executive__c
            );
        }

        return executiveIds;
    }

    private static Form_Activity_Daily_Execution__c
        getOrCreateDailyExecution(
            Form_Activity__c activity,
            Date selectedDate,
            String teamKey
        ) {
        return getOrCreateDailyExecution(
            activity,
            selectedDate,
            teamKey,
            null
        );
    }

    private static Form_Activity_Daily_Execution__c
        getOrCreateDailyExecution(
            Form_Activity__c activity,
            Date selectedDate,
            String teamKey,
            String locationKey
        ) {
        String effectiveTeamKey =
            normalizeRequestedTeamKey(teamKey);

        String executionKey =
            locationKey == null
            ? buildLegacyExecutionKey(
                activity.Id,
                selectedDate,
                effectiveTeamKey
            )
            : buildExecutionKey(
                activity.Id,
                selectedDate,
                effectiveTeamKey,
                locationKey
            );

        List<Form_Activity_Daily_Execution__c>
            existingExecutions = [
                SELECT Id,
                       Status__c,
                       Store_Manager_Approved__c,
                       BTL_Activity_Live__c
                FROM Form_Activity_Daily_Execution__c
                WHERE Execution_Key__c = :executionKey
                LIMIT 1
                FOR UPDATE
            ];

        if (!existingExecutions.isEmpty()) {
            return existingExecutions[0];
        }

        Form_Activity_Daily_Execution__c execution =
            new Form_Activity_Daily_Execution__c();

        execution.Form_Activity__c = activity.Id;
        execution.Activity_Date__c = selectedDate;
        execution.Store__c =
            activity.Assigned_Store__c;
        execution.Status__c = STATUS_PENDING;
        execution.Execution_Key__c = executionKey;
        execution.Store_Manager_Approved__c = false;
        execution.BTL_Activity_Live__c = false;

        insert execution;

        return execution;
    }

    private static void
        validateExecutionNotAlreadyInitiated(
            Form_Activity_Daily_Execution__c execution
        ) {
        if (
            execution.BTL_Activity_Live__c == true ||
            execution.Store_Manager_Approved__c == true ||
            execution.Status__c == STATUS_LIVE ||
            execution.Status__c == STATUS_IN_PROGRESS ||
            execution.Status__c == STATUS_COMPLETED
        ) {
            throw new AuraHandledException(
                'This activity has already been initiated for today.'
            );
        }
    }

    private static void activateExecution(
        Form_Activity_Daily_Execution__c execution
    ) {
        execution.Store_Manager_Approved__c = true;
        execution.BTL_Activity_Live__c = true;
        execution.Status__c = STATUS_LIVE;
        execution.BTL_Initiated_Date_Time__c =
            System.now();
        execution.BTL_Initiated_By__c =
            UserInfo.getUserId();

        update execution;
    }

    private static void updateParentInitiationSnapshot(
        Form_Activity__c activity,
        Date selectedDate
    ) {
        activity.Store_Manager_Approved__c = true;
        activity.BTL_Activity_Live__c = true;
        activity.BTL_Live_Date__c = selectedDate;
        activity.BTL_Initiated_Date_Time__c =
            System.now();
        activity.BTL_Initiated_By__c =
            UserInfo.getUserId();

        update activity;
    }

    private static String buildLegacyExecutionKey(
        Id activityId,
        Date activityDate,
        String teamKey
    ) {
        return String.valueOf(activityId) +
            '-' +
            String.valueOf(activityDate) +
            '-' +
            normalizeRequestedTeamKey(teamKey);
    }

    private static String buildExecutionKey(
        Id activityId,
        Date activityDate,
        String teamKey,
        String locationKey
    ) {
        String executionGroupSeed =
            normalizeRequestedTeamKey(teamKey) +
            '|' +
            normalizeRequestedLocationKey(
                locationKey
            );

        Blob digest = Crypto.generateDigest(
            'SHA-256',
            Blob.valueOf(executionGroupSeed)
        );

        return String.valueOf(activityId) +
            '-' +
            String.valueOf(activityDate) +
            '-' +
            EncodingUtil.convertToHex(digest);
    }

    private static String buildActivityTeamGroupKey(
        Id activityId,
        String teamKey
    ) {
        return String.valueOf(activityId) +
            '|' +
            normalizeRequestedTeamKey(teamKey);
    }

    private static String
        buildActivityTeamLocationGroupKey(
            Id activityId,
            String teamKey,
            String locationKey
        ) {
        return buildActivityTeamGroupKey(
            activityId,
            teamKey
        ) +
            '|' +
            normalizeRequestedLocationKey(
                locationKey
            );
    }

    private static String cleanTeamName(
        String teamName
    ) {
        return String.isBlank(teamName)
            ? null
            : teamName.trim();
    }

    private static String buildTeamKey(
        String teamName
    ) {
        String cleanedTeamName =
            cleanTeamName(teamName);

        if (String.isBlank(cleanedTeamName)) {
            return NO_TEAM_KEY;
        }

        String normalizedTeamName =
            cleanedTeamName.toLowerCase();

        Blob digest = Crypto.generateDigest(
            'SHA-256',
            Blob.valueOf(normalizedTeamName)
        );

        return EncodingUtil.convertToHex(digest);
    }

    private static String normalizeRequestedTeamKey(
        String teamKey
    ) {
        return String.isBlank(teamKey)
            ? NO_TEAM_KEY
            : teamKey.trim();
    }

    private static List<String> getSortedTeamKeys(
        Id activityId,
        Set<String> teamKeys,
        Map<String, String> teamNameByGroupKey
    ) {
        List<TeamKeySortWrapper> sortableTeams =
            new List<TeamKeySortWrapper>();

        for (String teamKey : teamKeys) {
            String groupKey =
                buildActivityTeamGroupKey(
                    activityId,
                    teamKey
                );

            sortableTeams.add(
                new TeamKeySortWrapper(
                    teamKey,
                    teamNameByGroupKey.get(groupKey)
                )
            );
        }

        sortableTeams.sort();

        List<String> sortedTeamKeys =
            new List<String>();

        for (
            TeamKeySortWrapper sortableTeam :
                sortableTeams
        ) {
            sortedTeamKeys.add(
                sortableTeam.teamKey
            );
        }

        return sortedTeamKeys;
    }

    private static List<String> getSortedLocationKeys(
        Id activityId,
        String teamKey,
        Set<String> locationKeys,
        Map<String, String> locationNameByGroupKey
    ) {
        List<LocationKeySortWrapper> sortableLocations =
            new List<LocationKeySortWrapper>();

        for (String locationKey : locationKeys) {
            String groupKey =
                buildActivityTeamLocationGroupKey(
                    activityId,
                    teamKey,
                    locationKey
                );

            sortableLocations.add(
                new LocationKeySortWrapper(
                    locationKey,
                    locationNameByGroupKey.get(
                        groupKey
                    )
                )
            );
        }

        sortableLocations.sort();

        List<String> sortedLocationKeys =
            new List<String>();

        for (
            LocationKeySortWrapper sortableLocation :
                sortableLocations
        ) {
            sortedLocationKeys.add(
                sortableLocation.locationKey
            );
        }

        return sortedLocationKeys;
    }

    private static Form_Activity_Daily_Execution__c
        getExecutionForGroup(
            String groupKey,
            String expectedExecutionKey,
            Map<String, Set<Id>> executionIdsByGroupKey,
            Map<Id, Form_Activity_Daily_Execution__c>
                executionById,
            Map<String, Form_Activity_Daily_Execution__c>
                executionByExecutionKey
        ) {
        Form_Activity_Daily_Execution__c selectedExecution;

        Set<Id> linkedExecutionIds =
            executionIdsByGroupKey.get(groupKey);

        if (
            linkedExecutionIds != null &&
            !linkedExecutionIds.isEmpty()
        ) {
            for (Id executionId : linkedExecutionIds) {
                Form_Activity_Daily_Execution__c
                    candidateExecution =
                        executionById.get(executionId);

                if (candidateExecution == null) {
                    continue;
                }

                if (
                    selectedExecution == null ||
                    getExecutionPriority(
                        candidateExecution.Status__c
                    ) >
                    getExecutionPriority(
                        selectedExecution.Status__c
                    )
                ) {
                    selectedExecution =
                        candidateExecution;
                }
            }
        }

        if (
            selectedExecution == null &&
            executionByExecutionKey.containsKey(
                expectedExecutionKey
            )
        ) {
            selectedExecution =
                executionByExecutionKey.get(
                    expectedExecutionKey
                );
        }

        return selectedExecution;
    }

    private static Integer getExecutionPriority(
        String status
    ) {
        if (status == STATUS_COMPLETED) {
            return 5;
        }

        if (status == STATUS_IN_PROGRESS) {
            return 4;
        }

        if (status == STATUS_LIVE) {
            return 3;
        }

        if (status == STATUS_PENDING) {
            return 2;
        }

        if (status == STATUS_EXPIRED) {
            return 1;
        }

        return 0;
    }

    private static AccessContext getAccessContext() {
        User currentUser = [
            SELECT Id,
                   Store__c,
                   Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        AccessContext context = new AccessContext();
        context.isSystemAdministrator =
            currentUser.Profile.Name ==
                SYSTEM_ADMIN_PROFILE;

        if (context.isSystemAdministrator) {
            return context;
        }

        if (String.isBlank(currentUser.Store__c)) {
            throw new AuraHandledException(
                'No store is assigned to the logged-in user.'
            );
        }

        List<Store__c> assignedStores = [
            SELECT Id, Name
            FROM Store__c
            WHERE Name = :currentUser.Store__c
            LIMIT 1
        ];

        if (assignedStores.isEmpty()) {
            throw new AuraHandledException(
                'The store mapped on the logged-in user was not found.'
            );
        }

        context.storeId = assignedStores[0].Id;
        context.storeName = assignedStores[0].Name;

        return context;
    }

    private static List<OptionWrapper> getStoreOptions(
        AccessContext accessContext
    ) {
        List<OptionWrapper> options =
            new List<OptionWrapper>();

        if (!accessContext.isSystemAdministrator) {
            options.add(
                new OptionWrapper(
                    accessContext.storeName,
                    String.valueOf(accessContext.storeId)
                )
            );

            return options;
        }

        options.add(
            new OptionWrapper(
                'All Stores',
                ''
            )
        );

        for (
            Store__c storeRecord : [
                SELECT Id, Name
                FROM Store__c
                ORDER BY Name
                LIMIT 500
            ]
        ) {
            options.add(
                new OptionWrapper(
                    storeRecord.Name,
                    String.valueOf(storeRecord.Id)
                )
            );
        }

        return options;
    }

    private static void validateStoreExists(
        Id storeId
    ) {
        if (
            [
                SELECT COUNT()
                FROM Store__c
                WHERE Id = :storeId
            ] == 0
        ) {
            throw new AuraHandledException(
                'The selected Store was not found.'
            );
        }
    }

    private class TeamKeySortWrapper
        implements Comparable {

        private String teamKey;
        private String teamName;

        private TeamKeySortWrapper(
            String teamKey,
            String teamName
        ) {
            this.teamKey = teamKey;
            this.teamName = teamName;
        }

        public Integer compareTo(
            Object otherObject
        ) {
            TeamKeySortWrapper otherTeam =
                (TeamKeySortWrapper) otherObject;

            String currentName =
                String.isBlank(teamName)
                ? ''
                : teamName.trim().toLowerCase();

            String otherName =
                String.isBlank(otherTeam.teamName)
                ? ''
                : otherTeam.teamName
                    .trim()
                    .toLowerCase();

            Integer nameComparison =
                currentName.compareTo(otherName);

            if (nameComparison != 0) {
                return nameComparison;
            }

            return teamKey.compareTo(
                otherTeam.teamKey
            );
        }
    }

    private class LocationKeySortWrapper
        implements Comparable {

        private String locationKey;
        private String locationName;

        private LocationKeySortWrapper(
            String locationKey,
            String locationName
        ) {
            this.locationKey = locationKey;
            this.locationName = locationName;
        }

        public Integer compareTo(
            Object otherObject
        ) {
            LocationKeySortWrapper otherLocation =
                (LocationKeySortWrapper) otherObject;

            String currentName =
                String.isBlank(locationName)
                ? ''
                : locationName
                    .trim()
                    .toLowerCase();

            String otherName =
                String.isBlank(
                    otherLocation.locationName
                )
                ? ''
                : otherLocation
                    .locationName
                    .trim()
                    .toLowerCase();

            Integer nameComparison =
                currentName.compareTo(otherName);

            if (nameComparison != 0) {
                return nameComparison;
            }

            return locationKey.compareTo(
                otherLocation.locationKey
            );
        }
    }

    private class AccessContext {
        Boolean isSystemAdministrator;
        Id storeId;
        String storeName;
    }

    public class ExecutiveChangeInput {
        @AuraEnabled
        public Id dateAssignmentId { get; set; }

        @AuraEnabled
        public Id actualExecutiveId { get; set; }

        @AuraEnabled
        public Boolean activeForDate { get; set; }

        @AuraEnabled
        public String activityLocation { get; set; }

        @AuraEnabled
        public Boolean isNew { get; set; }
    }

    public class ScheduleConflictRow {
        @AuraEnabled
        public Id executiveId { get; set; }

        @AuraEnabled
        public String executiveName { get; set; }

        @AuraEnabled
        public Id activityId { get; set; }

        @AuraEnabled
        public String activityName { get; set; }

        @AuraEnabled
        public String teamName { get; set; }
    }

    public class ScheduleActionResponse {
        @AuraEnabled
        public Integer processedRecords {
            get;
            set;
        }

        @AuraEnabled
        public Date newActivityDate {
            get;
            set;
        }

        @AuraEnabled
        public String actionType {
            get;
            set;
        }

        @AuraEnabled
        public List<ScheduleConflictRow> conflicts {
            get;
            set;
        }

        @AuraEnabled
        public String locationWarning {
            get;
            set;
        }

        @AuraEnabled
        public String message {
            get;
            set;
        }
    }

    public class SaveApprovalResponse {
        @AuraEnabled
        public Integer updatedExecutiveRecords {
            get;
            set;
        }

        @AuraEnabled
        public Integer createdExecutiveRecords {
            get;
            set;
        }

        @AuraEnabled
        public Integer taggedApprovalRecords {
            get;
            set;
        }

        @AuraEnabled
        public String message { get; set; }
    }

    public class DashboardResponse {
        @AuraEnabled
        public Date selectedDate { get; set; }

        @AuraEnabled
        public DateTime refreshedAt { get; set; }

        @AuraEnabled
        public Boolean isSystemAdministrator {
            get;
            set;
        }

        @AuraEnabled
        public Id selectedStoreId { get; set; }

        @AuraEnabled
        public List<OptionWrapper> storeOptions {
            get;
            set;
        }

        @AuraEnabled
        public Integer totalActivities { get; set; }

        @AuraEnabled
        public Integer pendingInitiation { get; set; }

        @AuraEnabled
        public Integer liveActivities { get; set; }

        @AuraEnabled
        public Integer inProgressActivities { get; set; }

        @AuraEnabled
        public Integer completedActivities { get; set; }

        @AuraEnabled
        public List<ActivityRow> activities {
            get;
            set;
        }

        public DashboardResponse() {
            totalActivities = 0;
            pendingInitiation = 0;
            liveActivities = 0;
            inProgressActivities = 0;
            completedActivities = 0;
            storeOptions = new List<OptionWrapper>();
            activities = new List<ActivityRow>();
        }
    }

    public class ActivityRow {
        @AuraEnabled
        public String rowKey { get; set; }

        @AuraEnabled
        public String teamKey { get; set; }

        @AuraEnabled
        public String teamName { get; set; }

        @AuraEnabled
        public Boolean hasTeam { get; set; }

        @AuraEnabled
        public String locationKey { get; set; }

        @AuraEnabled
        public Id activityId { get; set; }

        @AuraEnabled
        public Id dailyExecutionId { get; set; }

        @AuraEnabled
        public String activityNo { get; set; }

        @AuraEnabled
        public String activityName { get; set; }

        @AuraEnabled
        public Date startDate { get; set; }

        @AuraEnabled
        public Date endDate { get; set; }

        @AuraEnabled
        public String activityLocation { get; set; }

        @AuraEnabled
        public Id storeId { get; set; }

        @AuraEnabled
        public String storeName { get; set; }

        @AuraEnabled
        public Id finalCustomizeFormId { get; set; }

        @AuraEnabled
        public String finalCustomizeFormName {
            get;
            set;
        }

        @AuraEnabled
        public String status { get; set; }

        @AuraEnabled
        public Boolean storeManagerApproved {
            get;
            set;
        }

        @AuraEnabled
        public Boolean btlActivityLive { get; set; }

        @AuraEnabled
        public DateTime initiatedDateTime { get; set; }

        @AuraEnabled
        public String initiatedByName { get; set; }

        @AuraEnabled
        public DateTime startDateTime { get; set; }

        @AuraEnabled
        public DateTime completedDateTime { get; set; }

        @AuraEnabled
        public Integer assignedExecutiveCount {
            get;
            set;
        }

        @AuraEnabled
        public Boolean canInitiate { get; set; }

        @AuraEnabled
        public Boolean canReschedule { get; set; }

        @AuraEnabled
        public Boolean canDrop { get; set; }

        @AuraEnabled
        public Boolean activityFullyApproved {
            get;
            set;
        }

        @AuraEnabled
        public Boolean approvalLocked { get; set; }

        @AuraEnabled
        public Boolean approvalApproved { get; set; }

        @AuraEnabled
        public String approvalStatus { get; set; }

        @AuraEnabled
        public List<MemberRow> members { get; set; }
    }

    public class MemberRow {
        @AuraEnabled
        public Id dateAssignmentId { get; set; }

        @AuraEnabled
        public Id assignedPersonId { get; set; }

        @AuraEnabled
        public Id assignedExecutiveId { get; set; }

        @AuraEnabled
        public String assignedExecutiveName {
            get;
            set;
        }

        @AuraEnabled
        public Id actualExecutiveId { get; set; }

        @AuraEnabled
        public String actualExecutiveName {
            get;
            set;
        }

        @AuraEnabled
        public Id displayExecutiveId { get; set; }

        @AuraEnabled
        public String displayExecutiveName {
            get;
            set;
        }

        @AuraEnabled
        public String teamName { get; set; }

        @AuraEnabled
        public String activityLocation { get; set; }

        @AuraEnabled
        public Boolean activeForDate { get; set; }

        @AuraEnabled
        public Boolean isReplacement { get; set; }

        @AuraEnabled
        public String approvalStatus { get; set; }

        @AuraEnabled
        public Boolean approvalLocked { get; set; }

        @AuraEnabled
        public Boolean present { get; set; }
    }

    public class OptionWrapper {
        @AuraEnabled
        public String label { get; set; }

        @AuraEnabled
        public String value { get; set; }

        public OptionWrapper(
            String label,
            String value
        ) {
            this.label = label;
            this.value = value;
        }
    }
}*/