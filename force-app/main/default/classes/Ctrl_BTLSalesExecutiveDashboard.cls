public with sharing class Ctrl_BTLSalesExecutiveDashboard {

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

    private static final Integer PAST_ACTIVITY_DAYS = 90;

    @AuraEnabled(cacheable=true)
    public static DashboardContextWrapper getDashboardContext() {

        AccessContext accessContext =
            getAccessContext();

        DashboardContextWrapper response =
            new DashboardContextWrapper();

        response.isSystemAdministrator =
            accessContext.isSystemAdministrator;

        response.defaultStoreId =
            accessContext.storeId;

        response.defaultStoreName =
            accessContext.storeName;

        response.storeOptions =
            new List<OptionWrapper>();

        if (accessContext.isSystemAdministrator) {

            response.storeOptions.add(
                new OptionWrapper(
                    'All Stores',
                    ''
                )
            );

            for (
                Store__c storeRecord : [
                    SELECT Id, Name
                    FROM Store__c
                    WITH USER_MODE
                    ORDER BY Name
                    LIMIT 500
                ]
            ) {
                response.storeOptions.add(
                    new OptionWrapper(
                        storeRecord.Name,
                        String.valueOf(storeRecord.Id)
                    )
                );
            }

        } else {

            response.storeOptions.add(
                new OptionWrapper(
                    accessContext.storeName,
                    String.valueOf(accessContext.storeId)
                )
            );
        }

        return response;
    }

    @AuraEnabled(cacheable=true)
    public static DashboardWrapper getDashboardData(
        String tabName,
        Id selectedStoreId
    ) {
        AccessContext accessContext =
            getAccessContext();

        String normalizedTab =
            String.isBlank(tabName)
            ? 'TODAY'
            : tabName.trim().toUpperCase();

        if (
            normalizedTab != 'TODAY' &&
            normalizedTab != 'PAST'
        ) {
            normalizedTab = 'TODAY';
        }

        Id effectiveStoreId;

        if (accessContext.isSystemAdministrator) {

            effectiveStoreId =
                selectedStoreId;

            if (effectiveStoreId != null) {
                validateStoreExists(
                    effectiveStoreId
                );
            }

        } else {

            effectiveStoreId =
                accessContext.storeId;
        }

        Date todayDate =
            Date.today();

        Date pastStartDate =
            todayDate.addDays(
                -PAST_ACTIVITY_DAYS
            );

        String executionQuery =
            'SELECT Id, ' +
            'Name, ' +
            'Form_Activity__c, ' +
            'Form_Activity__r.Name, ' +
            'Form_Activity__r.Activity_Name__c, ' +
            'Form_Activity__r.Final_Customize_Form__c, ' +
            'Activity_Date__c, ' +
            'Store__c, ' +
            'Store__r.Name, ' +
            'Status__c, ' +
            'Store_Manager_Approved__c, ' +
            'BTL_Activity_Live__c, ' +
            'BTL_Initiated_Date_Time__c, ' +
            'BTL_Initiated_By__c, ' +
            'BTL_Initiated_By__r.Name, ' +
            'Start_Date_Time__c, ' +
            'Started_By__c, ' +
            'Started_By__r.Name, ' +
            'Completed_Date_Time__c, ' +
            'Completed_By__c, ' +
            'Completed_By__r.Name ' +
            'FROM Form_Activity_Daily_Execution__c ' +
            'WHERE Store_Manager_Approved__c = true ' +
            'AND BTL_Activity_Live__c = true ';

        Map<String, Object> executionBinds =
            new Map<String, Object>();

        if (normalizedTab == 'TODAY') {

            executionQuery +=
                'AND Activity_Date__c = :todayDate ';

            executionBinds.put(
                'todayDate',
                todayDate
            );

        } else {

            executionQuery +=
                'AND Activity_Date__c < :todayDate ' +
                'AND Activity_Date__c >= :pastStartDate ';

            executionBinds.put(
                'todayDate',
                todayDate
            );

            executionBinds.put(
                'pastStartDate',
                pastStartDate
            );
        }

        if (effectiveStoreId != null) {

            executionQuery +=
                'AND Store__c = :effectiveStoreId ';

            executionBinds.put(
                'effectiveStoreId',
                effectiveStoreId
            );
        }

        executionQuery +=
            'ORDER BY Activity_Date__c DESC, ' +
            'Store__r.Name, ' +
            'Form_Activity__r.Activity_Name__c ' +
            'LIMIT 5000';

        List<Form_Activity_Daily_Execution__c>
            executionRecords =
                new List<Form_Activity_Daily_Execution__c>();

        for (
            SObject executionObject :
            Database.queryWithBinds(
                executionQuery,
                executionBinds,
                AccessLevel.USER_MODE
            )
        ) {
            executionRecords.add(
                (Form_Activity_Daily_Execution__c)
                    executionObject
            );
        }

        DashboardWrapper response =
            new DashboardWrapper();

        response.serverDate =
            todayDate;

        response.tabName =
            normalizedTab;

        response.activities =
            new List<ActivityWrapper>();

        if (executionRecords.isEmpty()) {
            return response;
        }

        Set<Id> executionIds =
            new Set<Id>();

        for (
            Form_Activity_Daily_Execution__c execution :
            executionRecords
        ) {
            executionIds.add(
                execution.Id
            );
        }

        Map<Id, List<MemberWrapper>>
            membersByExecutionId =
                getMembersByExecution(
                    executionIds
                );

        Map<Id, Integer>
            responseCountByExecutionId =
                getResponseCounts(
                    executionIds
                );

        for (
            Form_Activity_Daily_Execution__c execution :
            executionRecords
        ) {
            ActivityWrapper activity =
                new ActivityWrapper();

            activity.dailyExecutionId =
                execution.Id;

            activity.activityId =
                execution.Form_Activity__c;

            activity.activityNo =
                execution.Form_Activity__r == null
                ? null
                : execution.Form_Activity__r.Name;

            activity.activityName =
                execution.Form_Activity__r == null
                ? null
                : execution
                    .Form_Activity__r
                    .Activity_Name__c;

            if (
                String.isBlank(
                    activity.activityName
                )
            ) {
                activity.activityName =
                    activity.activityNo;
            }

            activity.activityDate =
                execution.Activity_Date__c;

            activity.storeId =
                execution.Store__c;

            activity.storeName =
                execution.Store__r == null
                ? null
                : execution.Store__r.Name;

            activity.finalCustomizeFormId =
                execution.Form_Activity__r == null
                ? null
                : execution
                    .Form_Activity__r
                    .Final_Customize_Form__c;

            activity.initiatedDateTime =
                execution
                    .BTL_Initiated_Date_Time__c;

            activity.initiatedByName =
                execution.BTL_Initiated_By__r == null
                ? null
                : execution
                    .BTL_Initiated_By__r.Name;

            activity.startDateTime =
                execution.Start_Date_Time__c;

            activity.startedByName =
                execution.Started_By__r == null
                ? null
                : execution.Started_By__r.Name;

            activity.completedDateTime =
                execution.Completed_Date_Time__c;

            activity.completedByName =
                execution.Completed_By__r == null
                ? null
                : execution.Completed_By__r.Name;

            activity.members =
                membersByExecutionId.containsKey(
                    execution.Id
                )
                ? membersByExecutionId.get(
                    execution.Id
                )
                : new List<MemberWrapper>();

            /*
             * Activity Location belongs to the date-level assignment.
             * If more than one location exists, use the first non-blank
             * location returned for this Daily Execution.
             */
            activity.activityLocation =
                getFirstExecutionLocation(
                    activity.members
                );

            activity.memberCount =
                activity.members.size();

            activity.responseCount =
                responseCountByExecutionId.containsKey(
                    execution.Id
                )
                ? responseCountByExecutionId.get(
                    execution.Id
                )
                : 0;

            activity.status =
                execution.Status__c;

            Boolean isToday =
                execution.Activity_Date__c ==
                    todayDate;

            if (
                execution.Activity_Date__c <
                    todayDate &&
                activity.status != STATUS_COMPLETED
            ) {
                activity.status =
                    STATUS_EXPIRED;
            }

            activity.canStart =
                isToday &&
                activity.status == STATUS_LIVE &&
                activity.memberCount > 0;

            activity.canContinue =
                isToday &&
                activity.status ==
                    STATUS_IN_PROGRESS;

            activity.canComplete =
                isToday &&
                activity.status ==
                    STATUS_IN_PROGRESS;

            activity.canViewResponses =
                activity.responseCount > 0 &&
                (
                    activity.status ==
                        STATUS_COMPLETED ||
                    activity.status ==
                        STATUS_EXPIRED
                );

            response.activities.add(
                activity
            );
        }

        return response;
    }

    @AuraEnabled
    public static void startActivity(
        Id dailyExecutionId,
        List<Id> presentDateAssignmentIds
    ) {
        if (dailyExecutionId == null) {
            throw new AuraHandledException(
                'Daily Execution Id is required.'
            );
        }

        if (
            presentDateAssignmentIds == null ||
            presentDateAssignmentIds.isEmpty()
        ) {
            throw new AuraHandledException(
                'Please mark at least one member as Present.'
            );
        }

        List<Form_Activity_Daily_Execution__c>
            executionList = [
                SELECT Id,
                       Form_Activity__c,
                       Activity_Date__c,
                       Store__c,
                       Status__c,
                       Store_Manager_Approved__c,
                       BTL_Activity_Live__c,
                       Start_Date_Time__c,
                       Started_By__c
                FROM Form_Activity_Daily_Execution__c
                WHERE Id = :dailyExecutionId
                WITH USER_MODE
                LIMIT 1
            ];

        if (executionList.isEmpty()) {
            throw new AuraHandledException(
                'Daily Execution record was not found.'
            );
        }

        Form_Activity_Daily_Execution__c execution =
            executionList[0];

        validateExecutionAccess(
            execution
        );

        if (
            execution.Activity_Date__c !=
            Date.today()
        ) {
            throw new AuraHandledException(
                'Only today’s activity can be started.'
            );
        }

        if (
            execution.Store_Manager_Approved__c !=
                true ||
            execution.BTL_Activity_Live__c !=
                true
        ) {
            throw new AuraHandledException(
                'This activity is not live yet.'
            );
        }

        if (
            execution.Status__c ==
            STATUS_IN_PROGRESS
        ) {
            throw new AuraHandledException(
                'This activity is already in progress.'
            );
        }

        if (
            execution.Status__c ==
            STATUS_COMPLETED
        ) {
            throw new AuraHandledException(
                'This activity has already been completed.'
            );
        }

        if (
            execution.Status__c !=
            STATUS_LIVE
        ) {
            throw new AuraHandledException(
                'This activity cannot be started in its current status.'
            );
        }

        List<Form_Activity_Assigned_Persons_Date__c>
            attendanceRows = [
                SELECT Id,
                       Form_Activity_Daily_Execution__c,
                       Actual_Executive__c,
                       Actual_Executive__r.Name,
                       Active_For_Date__c,
                       Present__c,
                       Actual_Date__c,
                       Attendance_Date_Time__c,
                       Attendance_Marked_By__c
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Form_Activity_Daily_Execution__c
                    = :dailyExecutionId
                AND Active_For_Date__c = true
                WITH USER_MODE
            ];

        if (attendanceRows.isEmpty()) {
            throw new AuraHandledException(
                'No active Sales Executives were found for this activity.'
            );
        }

        Set<Id> validAttendanceIds =
            new Set<Id>();

        for (
            Form_Activity_Assigned_Persons_Date__c row :
            attendanceRows
        ) {
            validAttendanceIds.add(
                row.Id
            );
        }

        Set<Id> selectedAttendanceIds =
            new Set<Id>(
                presentDateAssignmentIds
            );

        for (
            Id selectedAttendanceId :
            selectedAttendanceIds
        ) {
            if (
                !validAttendanceIds.contains(
                    selectedAttendanceId
                )
            ) {
                throw new AuraHandledException(
                    'An invalid attendance record was selected.'
                );
            }
        }

        DateTime attendanceDateTime =
            System.now();

        Id currentUserId =
            UserInfo.getUserId();

        for (
            Form_Activity_Assigned_Persons_Date__c row :
            attendanceRows
        ) {
            Boolean isPresent =
                selectedAttendanceIds.contains(
                    row.Id
                );

            row.Present__c =
                isPresent;

            row.Actual_Date__c =
                isPresent
                ? Date.today()
                : null;

            row.Attendance_Date_Time__c =
                isPresent
                ? attendanceDateTime
                : null;

            row.Attendance_Marked_By__c =
                isPresent
                ? currentUserId
                : null;
        }

        Database.update(
            attendanceRows,
            AccessLevel.USER_MODE
        );

        execution.Status__c =
            STATUS_IN_PROGRESS;

        execution.Start_Date_Time__c =
            System.now();

        execution.Started_By__c =
            currentUserId;

        Database.update(
            execution,
            AccessLevel.USER_MODE
        );
    }

    @AuraEnabled
    public static void completeActivity(
        Id dailyExecutionId
    ) {
        if (dailyExecutionId == null) {
            throw new AuraHandledException(
                'Daily Execution Id is required.'
            );
        }

        List<Form_Activity_Daily_Execution__c>
            executionList = [
                SELECT Id,
                       Activity_Date__c,
                       Store__c,
                       Status__c,
                       Completed_Date_Time__c,
                       Completed_By__c
                FROM Form_Activity_Daily_Execution__c
                WHERE Id = :dailyExecutionId
                WITH USER_MODE
                LIMIT 1
            ];

        if (executionList.isEmpty()) {
            throw new AuraHandledException(
                'Daily Execution record was not found.'
            );
        }

        Form_Activity_Daily_Execution__c execution =
            executionList[0];

        validateExecutionAccess(
            execution
        );

        if (
            execution.Activity_Date__c !=
            Date.today()
        ) {
            throw new AuraHandledException(
                'Past activities cannot be completed.'
            );
        }

        if (
            execution.Status__c ==
            STATUS_COMPLETED
        ) {
            throw new AuraHandledException(
                'This activity is already completed.'
            );
        }

        if (
            execution.Status__c !=
            STATUS_IN_PROGRESS
        ) {
            throw new AuraHandledException(
                'Only an In Progress activity can be completed.'
            );
        }

        Integer responseCount = [
            SELECT COUNT()
            FROM BTL_Customer_Response__c
            WHERE Form_Activity_Daily_Execution__c
                = :dailyExecutionId
            WITH USER_MODE
        ];

        if (responseCount == 0) {
            throw new AuraHandledException(
                'Please capture at least one BTL response before completing the activity.'
            );
        }

        execution.Status__c =
            STATUS_COMPLETED;

        execution.Completed_Date_Time__c =
            System.now();

        execution.Completed_By__c =
            UserInfo.getUserId();

        Database.update(
            execution,
            AccessLevel.USER_MODE
        );
    }

    @AuraEnabled(cacheable=true)
    public static List<ResponseWrapper>
        getActivityResponses(
            Id dailyExecutionId
        ) {
        if (dailyExecutionId == null) {
            return new List<ResponseWrapper>();
        }

        List<Form_Activity_Daily_Execution__c>
            executionList = [
                SELECT Id,
                       Store__c
                FROM Form_Activity_Daily_Execution__c
                WHERE Id = :dailyExecutionId
                WITH USER_MODE
                LIMIT 1
            ];

        if (executionList.isEmpty()) {
            throw new AuraHandledException(
                'Daily Execution record was not found.'
            );
        }

        validateExecutionAccess(
            executionList[0]
        );

        List<ResponseWrapper> results =
            new List<ResponseWrapper>();

        for (
            BTL_Customer_Response__c responseRecord : [
                SELECT Id,
                       Name,
                       Phone_No__c,
                       Actual_Date_Time__c,
                       Response_Date__c,
                       Executive__c,
                       Orient_Customer__c,
                       Orient_Customer__r.Name
                FROM BTL_Customer_Response__c
                WHERE Form_Activity_Daily_Execution__c
                    = :dailyExecutionId
                WITH USER_MODE
                ORDER BY Actual_Date_Time__c DESC
                LIMIT 1000
            ]
        ) {
            ResponseWrapper wrapper =
                new ResponseWrapper();

            wrapper.responseId =
                responseRecord.Id;

            wrapper.responseNo =
                responseRecord.Name;

            wrapper.phoneNo =
                responseRecord.Phone_No__c;

            wrapper.actualDateTime =
                responseRecord
                    .Actual_Date_Time__c;

            wrapper.responseDate =
                responseRecord.Response_Date__c;

            wrapper.executiveNames =
                responseRecord.Executive__c;

            wrapper.customerId =
                responseRecord
                    .Orient_Customer__c;

            wrapper.customerName =
                responseRecord.Orient_Customer__r ==
                    null
                ? null
                : responseRecord
                    .Orient_Customer__r.Name;

            results.add(
                wrapper
            );
        }

        return results;
    }

    @AuraEnabled(cacheable=true)
    public static String getPresentExecutiveNames(
        Id dailyExecutionId
    ) {
        if (dailyExecutionId == null) {
            return null;
        }

        Form_Activity_Daily_Execution__c execution = [
            SELECT Id,
                   Store__c
            FROM Form_Activity_Daily_Execution__c
            WHERE Id = :dailyExecutionId
            WITH USER_MODE
            LIMIT 1
        ];

        validateExecutionAccess(
            execution
        );

        List<String> executiveNames =
            new List<String>();

        Set<String> uniqueNames =
            new Set<String>();

        for (
            Form_Activity_Assigned_Persons_Date__c row : [
                SELECT Actual_Executive__c,
                       Actual_Executive__r.Name
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Form_Activity_Daily_Execution__c
                    = :dailyExecutionId
                AND Active_For_Date__c = true
                AND Present__c = true
                WITH USER_MODE
                ORDER BY Actual_Executive__r.Name
            ]
        ) {
            if (
                row.Actual_Executive__r != null &&
                !String.isBlank(
                    row.Actual_Executive__r.Name
                ) &&
                !uniqueNames.contains(
                    row.Actual_Executive__r.Name
                )
            ) {
                uniqueNames.add(
                    row.Actual_Executive__r.Name
                );

                executiveNames.add(
                    row.Actual_Executive__r.Name
                );
            }
        }

        return String.join(
            executiveNames,
            ', '
        );
    }

    private static Map<Id, List<MemberWrapper>>
        getMembersByExecution(
            Set<Id> executionIds
        ) {
        Map<Id, List<MemberWrapper>>
            membersByExecutionId =
                new Map<Id, List<MemberWrapper>>();

        if (
            executionIds == null ||
            executionIds.isEmpty()
        ) {
            return membersByExecutionId;
        }

        for (
            Form_Activity_Assigned_Persons_Date__c
                memberRecord : [
                    SELECT Id,
                           Form_Activity_Daily_Execution__c,
                           Form_Activity_Assigned_Persons__c,
                           Form_Activity_Assigned_Persons__r.Team_Name__c,
                           Form_Activity_Assigned_Persons__r.Sales_Executives__c,
                           Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                           Actual_Executive__c,
                           Actual_Executive__r.Name,
                           Activity_Location__c,
                           Target_Date__c,
                           Actual_Date__c,
                           Active_For_Date__c,
                           Present__c,
                           Attendance_Date_Time__c,
                           Attendance_Marked_By__c,
                           Attendance_Marked_By__r.Name
                    FROM Form_Activity_Assigned_Persons_Date__c
                    WHERE Form_Activity_Daily_Execution__c
                        IN :executionIds
                    AND Active_For_Date__c = true
                    WITH USER_MODE
                    ORDER BY Actual_Executive__r.Name
                ]
        ) {
            Id executionId =
                memberRecord
                    .Form_Activity_Daily_Execution__c;

            if (executionId == null) {
                continue;
            }

            if (
                !membersByExecutionId.containsKey(
                    executionId
                )
            ) {
                membersByExecutionId.put(
                    executionId,
                    new List<MemberWrapper>()
                );
            }

            MemberWrapper member =
                new MemberWrapper();

            member.dateAssignmentId =
                memberRecord.Id;

            member.assignedPersonId =
                memberRecord
                    .Form_Activity_Assigned_Persons__c;

            member.assignedExecutiveId =
                memberRecord
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__c;

            member.assignedExecutiveName =
                memberRecord
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__r == null
                ? null
                : memberRecord
                    .Form_Activity_Assigned_Persons__r
                    .Sales_Executives__r.Name;

            member.actualExecutiveId =
                memberRecord.Actual_Executive__c;

            member.actualExecutiveName =
                memberRecord.Actual_Executive__r == null
                ? null
                : memberRecord
                    .Actual_Executive__r.Name;

            member.executiveId =
                member.actualExecutiveId != null
                ? member.actualExecutiveId
                : member.assignedExecutiveId;

            member.memberName =
                !String.isBlank(
                    member.actualExecutiveName
                )
                ? member.actualExecutiveName
                : member.assignedExecutiveName;

            member.teamName =
                memberRecord
                    .Form_Activity_Assigned_Persons__r
                    .Team_Name__c;

            member.activityLocation =
                memberRecord.Activity_Location__c;

            member.targetDate =
                memberRecord.Target_Date__c;

            member.actualDate =
                memberRecord.Actual_Date__c;

            member.activeForDate =
                memberRecord.Active_For_Date__c;

            member.present =
                memberRecord.Present__c;

            member.attendanceDateTime =
                memberRecord
                    .Attendance_Date_Time__c;

            member.attendanceMarkedByName =
                memberRecord.Attendance_Marked_By__r ==
                    null
                ? null
                : memberRecord
                    .Attendance_Marked_By__r.Name;

            membersByExecutionId
                .get(executionId)
                .add(member);
        }

        return membersByExecutionId;
    }


    private static String getFirstExecutionLocation(
        List<MemberWrapper> members
    ) {
        if (members == null || members.isEmpty()) {
            return null;
        }

        for (MemberWrapper member : members) {
            if (
                member != null &&
                String.isNotBlank(
                    member.activityLocation
                )
            ) {
                return member.activityLocation.trim();
            }
        }

        return null;
    }

    private static Map<Id, Integer>
        getResponseCounts(
            Set<Id> executionIds
        ) {
        Map<Id, Integer>
            responseCountByExecutionId =
                new Map<Id, Integer>();

        if (
            executionIds == null ||
            executionIds.isEmpty()
        ) {
            return responseCountByExecutionId;
        }

        String responseCountQuery =
            'SELECT Form_Activity_Daily_Execution__c, ' +
            'COUNT(Id) responseCount ' +
            'FROM BTL_Customer_Response__c ' +
            'WHERE Form_Activity_Daily_Execution__c ' +
            'IN :executionIds ' +
            'GROUP BY Form_Activity_Daily_Execution__c';

        Map<String, Object> bindValues =
            new Map<String, Object>{
                'executionIds' => executionIds
            };

        for (
            SObject aggregateObject :
            Database.queryWithBinds(
                responseCountQuery,
                bindValues,
                AccessLevel.USER_MODE
            )
        ) {
            AggregateResult aggregateResult =
                (AggregateResult)
                    aggregateObject;

            Id executionId =
                (Id) aggregateResult.get(
                    'Form_Activity_Daily_Execution__c'
                );

            Integer responseCount =
                (Integer) aggregateResult.get(
                    'responseCount'
                );

            responseCountByExecutionId.put(
                executionId,
                responseCount
            );
        }

        return responseCountByExecutionId;
    }

    private static void validateExecutionAccess(
        Form_Activity_Daily_Execution__c execution
    ) {
        AccessContext accessContext =
            getAccessContext();

        if (
            !accessContext.isSystemAdministrator &&
            execution.Store__c !=
                accessContext.storeId
        ) {
            throw new AuraHandledException(
                'You do not have access to this store activity.'
            );
        }
    }

    // private static AccessContext getAccessContext() {

    //     User currentUser = [
    //         SELECT Id,
    //                Store__c,
    //                Profile.Name
    //         FROM User
    //         WHERE Id = :UserInfo.getUserId()
    //         WITH USER_MODE
    //         LIMIT 1
    //     ];

    //     AccessContext context =
    //         new AccessContext();

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

    //     List<Store__c> stores = [
    //         SELECT Id, Name
    //         FROM Store__c
    //         WHERE Name = :currentUser.Store__c
    //         WITH USER_MODE
    //         LIMIT 1
    //     ];

    //     if (stores.isEmpty()) {
    //         throw new AuraHandledException(
    //             'The store mapped on the logged-in user was not found.'
    //         );
    //     }

    //     context.storeId =
    //         stores[0].Id;

    //     context.storeName =
    //         stores[0].Name;

    //     return context;
    // }

    private static AccessContext getAccessContext() {
        User currentUser = [
            SELECT Id, Store__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        Boolean isAdmin = false;
        
        try {
            // Dynamic SOQL prevents strict compile-time validation.
            // If the user's license restricts Profile access, this throws an error, 
            // the catch block swallows it, and sets isAdmin to false.
            Id profileId = UserInfo.getProfileId();
            String query = 'SELECT Name FROM Profile WHERE Id = :profileId LIMIT 1';
            List<SObject> profiles = Database.query(query);
            
            if (!profiles.isEmpty() && String.valueOf(profiles[0].get('Name')) == SYSTEM_ADMIN_PROFILE) {
                isAdmin = true;
            }
        } catch (Exception e) {
            // Restricted user licenses (like the Sales Executive) will safely fall here.
            isAdmin = false;
        }

        AccessContext context = new AccessContext();
        context.isSystemAdministrator = isAdmin;

        if (context.isSystemAdministrator) {
            return context;
        }

        if (String.isBlank(currentUser.Store__c)) {
            throw new AuraHandledException('No store is assigned to the logged-in user.');
        }

        List<Store__c> stores = [
            SELECT Id, Name
            FROM Store__c
            WHERE Name = :currentUser.Store__c
            WITH USER_MODE
            LIMIT 1
        ];

        if (stores.isEmpty()) {
            throw new AuraHandledException('The store mapped on the logged-in user was not found.');
        }

        context.storeId = stores[0].Id;
        context.storeName = stores[0].Name;

        return context;
    }

    private static void validateStoreExists(
        Id storeId
    ) {
        Integer storeCount = [
            SELECT COUNT()
            FROM Store__c
            WHERE Id = :storeId
            WITH USER_MODE
        ];

        if (storeCount == 0) {
            throw new AuraHandledException(
                'The selected Store record was not found.'
            );
        }
    }

    private class AccessContext {
        Boolean isSystemAdministrator;
        Id storeId;
        String storeName;
    }

    public class DashboardContextWrapper {

        @AuraEnabled
        public Boolean isSystemAdministrator;

        @AuraEnabled
        public Id defaultStoreId;

        @AuraEnabled
        public String defaultStoreName;

        @AuraEnabled
        public List<OptionWrapper> storeOptions;
    }

    public class DashboardWrapper {

        @AuraEnabled
        public Date serverDate;

        @AuraEnabled
        public String tabName;

        @AuraEnabled
        public List<ActivityWrapper> activities;
    }

    public class ActivityWrapper {

        @AuraEnabled
        public Id dailyExecutionId;

        @AuraEnabled
        public Id activityId;

        @AuraEnabled
        public String activityNo;

        @AuraEnabled
        public String activityName;

        @AuraEnabled
        public Date activityDate;

        @AuraEnabled
        public String activityLocation;

        @AuraEnabled
        public Id storeId;

        @AuraEnabled
        public String storeName;

        @AuraEnabled
        public Id finalCustomizeFormId;

        @AuraEnabled
        public String status;

        @AuraEnabled
        public DateTime initiatedDateTime;

        @AuraEnabled
        public String initiatedByName;

        @AuraEnabled
        public DateTime startDateTime;

        @AuraEnabled
        public String startedByName;

        @AuraEnabled
        public DateTime completedDateTime;

        @AuraEnabled
        public String completedByName;

        @AuraEnabled
        public Integer memberCount;

        @AuraEnabled
        public Integer responseCount;

        @AuraEnabled
        public Boolean canStart;

        @AuraEnabled
        public Boolean canContinue;

        @AuraEnabled
        public Boolean canComplete;

        @AuraEnabled
        public Boolean canViewResponses;

        @AuraEnabled
        public List<MemberWrapper> members;
    }

    public class MemberWrapper {

        @AuraEnabled
        public Id dateAssignmentId;

        @AuraEnabled
        public Id assignedPersonId;

        @AuraEnabled
        public Id assignedExecutiveId;

        @AuraEnabled
        public String assignedExecutiveName;

        @AuraEnabled
        public Id actualExecutiveId;

        @AuraEnabled
        public String actualExecutiveName;

        @AuraEnabled
        public Id executiveId;

        @AuraEnabled
        public String memberName;

        @AuraEnabled
        public String teamName;

        @AuraEnabled
        public String activityLocation;

        @AuraEnabled
        public Date targetDate;

        @AuraEnabled
        public Date actualDate;

        @AuraEnabled
        public Boolean activeForDate;

        @AuraEnabled
        public Boolean present;

        @AuraEnabled
        public DateTime attendanceDateTime;

        @AuraEnabled
        public String attendanceMarkedByName;
    }

    public class ResponseWrapper {

        @AuraEnabled
        public Id responseId;

        @AuraEnabled
        public String responseNo;

        @AuraEnabled
        public Id customerId;

        @AuraEnabled
        public String customerName;

        @AuraEnabled
        public String phoneNo;

        @AuraEnabled
        public Date responseDate;

        @AuraEnabled
        public DateTime actualDateTime;

        @AuraEnabled
        public String executiveNames;
    }

    public class OptionWrapper {

        @AuraEnabled
        public String label;

        @AuraEnabled
        public String value;

        public OptionWrapper(
            String label,
            String value
        ) {
            this.label =
                label;

            this.value =
                value;
        }
    }
}