public with sharing class ctrl_StoreManagerDailyActivityController {

    private static final String FORM_ACTIVITY_OBJECT = 'Form_Activity__c';
    private static final String ACTIVITY_NAME_FIELD = 'Activity_Name__c';
    private static final String ACTIVITY_STORE_FIELD = 'Assigned_Store__c';
    private static final String ACTIVITY_START_DATE_FIELD = 'Activity_Date__c';
    private static final String ACTIVITY_END_DATE_FIELD = 'Activity_End_Date__c';
    private static final String FINAL_CUSTOMIZE_FORM_FIELD = 'Final_Customize_Form__c';

    private static final String ASSIGNED_PERSON_OBJECT = 'Form_Activity_Assigned_Persons__c';
    private static final String ASSIGNED_PERSON_ACTIVITY_FIELD = 'Form_Activity__c';
    private static final String ASSIGNED_PERSON_TEAM_FIELD = 'Team_Name__c';
    private static final String ASSIGNED_EXECUTIVE_FIELD = 'Sales_Executives__c';
    private static final String ACTUAL_EXECUTIVE_FIELD = 'Actual_Executives__c';

    private static final String ASSIGNED_PERSON_DATE_OBJECT = 'Form_Activity_Assigned_Persons_Date__c';
    private static final String DATE_ASSIGNED_PERSON_FIELD = 'Form_Activity_Assigned_Persons__c';
    private static final String ACTIVITY_LOCATION_FIELD = 'Activity_Location__c';
    private static final String TARGET_DATE_FIELD = 'Target_Date__c';
    private static final String ACTUAL_DATE_FIELD = 'Actual_Date__c';

    private static final String CUSTOMER_RESPONSE_OBJECT = 'BTL_Customer_Response__c';
    private static final String RESPONSE_ACTIVITY_FIELD = 'Form_Activity__c';
    private static final String RESPONSE_DATE_FIELD = 'Response_Date__c';
    private static final String RESPONSE_EXECUTIVE_FIELD = 'Executive__c';

    private static final String SYSTEM_ADMIN_PROFILE = 'System Administrator';
    private static final String NO_TEAM_KEY = 'NO_TEAM';

    @AuraEnabled
    public static DashboardResponse getDashboard(Date selectedDate, String selectedStore) {
        if (selectedDate == null) {
            selectedDate = Date.today();
        }

        validateConfiguration();

        User currentUser = [
            SELECT Id, Store__c, Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];

        Boolean isSystemAdministrator =
            currentUser.Profile.Name == SYSTEM_ADMIN_PROFILE;

        List<String> availableStores = isSystemAdministrator
            ? getAvailableStores()
            : new List<String>();

        String storeFilter;

        if (isSystemAdministrator) {
            if (!isAllStoresSelection(selectedStore)) {
                if (!availableStores.contains(selectedStore)) {
                    throw new AuraHandledException(
                        'You do not have access to the selected store.'
                    );
                }
                storeFilter = selectedStore;
            }
        } else {
            if (String.isBlank(currentUser.Store__c)) {
                throw new AuraHandledException(
                    'No store is assigned to your user account.'
                );
            }
            storeFilter = currentUser.Store__c;
        }

        DashboardResponse response = new DashboardResponse();
        response.store = String.isBlank(storeFilter) ? 'All Stores' : storeFilter;
        response.selectedDate = selectedDate;
        response.refreshedAt = System.now();
        response.isSystemAdministrator = isSystemAdministrator;
        response.availableStores = availableStores;
        response.formActivityObjectApiName = FORM_ACTIVITY_OBJECT;
        response.activities = new List<ActivityRow>();
        response.executives = new List<ExecutiveRow>();

        Map<Id, ActivityRow> baseActivityById = new Map<Id, ActivityRow>();
        List<Id> activityOrder = new List<Id>();

        loadBaseActivities(
            selectedDate,
            storeFilter,
            response,
            baseActivityById,
            activityOrder
        );

        if (baseActivityById.isEmpty()) {
            return response;
        }

        TeamContext context = new TeamContext();

        loadAssignedPersons(
            baseActivityById.keySet(),
            baseActivityById,
            context
        );

        createRowsForActivitiesWithoutAssignments(
            activityOrder,
            baseActivityById,
            context
        );

        loadTargetLocations(selectedDate, context);

        loadCustomerResponseCounts(
            baseActivityById.keySet(),
            selectedDate,
            context
        );

        finaliseActivityRows(
            activityOrder,
            response,
            context
        );

        finaliseExecutiveRows(response, context);

        return response;
    }

    private static void loadBaseActivities(
        Date selectedDate,
        String storeFilter,
        DashboardResponse response,
        Map<Id, ActivityRow> baseActivityById,
        List<Id> activityOrder
    ) {
        Set<String> activityFields = new Set<String>{'Id', 'Name'};

        addFieldWithDisplayName(
            activityFields,
            FORM_ACTIVITY_OBJECT,
            ACTIVITY_NAME_FIELD
        );
        addFieldWithDisplayName(
            activityFields,
            FORM_ACTIVITY_OBJECT,
            ACTIVITY_STORE_FIELD
        );
        addFieldWithDisplayName(
            activityFields,
            FORM_ACTIVITY_OBJECT,
            ACTIVITY_START_DATE_FIELD
        );
        addFieldWithDisplayName(
            activityFields,
            FORM_ACTIVITY_OBJECT,
            ACTIVITY_END_DATE_FIELD
        );
        addFieldWithDisplayName(
            activityFields,
            FORM_ACTIVITY_OBJECT,
            FINAL_CUSTOMIZE_FORM_FIELD
        );

        if (hasField(FORM_ACTIVITY_OBJECT, 'OwnerId')) {
            activityFields.add('OwnerId');
            activityFields.add('Owner.Name');
        }

        List<String> activityConditions = new List<String>{
            ACTIVITY_START_DATE_FIELD + ' <= :selectedDate',
            ACTIVITY_END_DATE_FIELD + ' >= :selectedDate'
        };

        if (!String.isBlank(storeFilter)) {
            activityConditions.add(
                getActivityStoreFilterPath() + ' = :storeFilter'
            );
        }

        String activityQuery =
            'SELECT ' + joinFields(activityFields) +
            ' FROM ' + FORM_ACTIVITY_OBJECT +
            ' WHERE ' + String.join(activityConditions, ' AND ') +
            ' WITH USER_MODE' +
            ' ORDER BY ' + ACTIVITY_START_DATE_FIELD + ', Name';

        List<SObject> activityRecords = Database.query(activityQuery);

        for (SObject activityRecord : activityRecords) {
            Id activityId = (Id) activityRecord.get('Id');
            ActivityRow row = new ActivityRow();

            row.activityId = activityId;
            row.activityNo = String.valueOf(activityRecord.get('Name'));
            row.activityName = getDisplayValue(
                activityRecord,
                FORM_ACTIVITY_OBJECT,
                ACTIVITY_NAME_FIELD
            );
            row.store = getDisplayValue(
                activityRecord,
                FORM_ACTIVITY_OBJECT,
                ACTIVITY_STORE_FIELD
            );
            row.startDate = getDateValue(
                activityRecord,
                ACTIVITY_START_DATE_FIELD
            );
            row.endDate = getDateValue(
                activityRecord,
                ACTIVITY_END_DATE_FIELD
            );
            row.finalFormId = getReferenceId(
                activityRecord,
                FORM_ACTIVITY_OBJECT,
                FINAL_CUSTOMIZE_FORM_FIELD
            );
            row.finalFormName = getDisplayValue(
                activityRecord,
                FORM_ACTIVITY_OBJECT,
                FINAL_CUSTOMIZE_FORM_FIELD
            );

            if (hasField(FORM_ACTIVITY_OBJECT, 'OwnerId')) {
                SObject ownerRecord = activityRecord.getSObject('Owner');
                if (ownerRecord != null) {
                    row.ownerName = String.valueOf(ownerRecord.get('Name'));
                }
            }

            row.duration =
                row.startDate != null && row.endDate != null
                    ? row.startDate.daysBetween(row.endDate) + 1
                    : 0;

            row.status = calculateStatus(
                row.startDate,
                row.endDate,
                selectedDate
            );

            if (row.startDate == selectedDate) {
                response.startingToday++;
            }

            if (
                row.endDate != null &&
                row.endDate >= selectedDate &&
                row.endDate <= selectedDate.addDays(3)
            ) {
                response.endingSoon++;
            }

            baseActivityById.put(activityId, row);
            activityOrder.add(activityId);
        }

        // Summary remains activity-based, not team-row-based.
        response.activeToday = activityOrder.size();
    }

    private static void loadAssignedPersons(
        Set<Id> activityIds,
        Map<Id, ActivityRow> baseActivityById,
        TeamContext context
    ) {
        Set<String> assignedFields = new Set<String>{
            'Id',
            'Name',
            ASSIGNED_PERSON_ACTIVITY_FIELD
        };

        addFieldWithDisplayName(
            assignedFields,
            ASSIGNED_PERSON_OBJECT,
            ASSIGNED_PERSON_TEAM_FIELD
        );
        addFieldWithDisplayName(
            assignedFields,
            ASSIGNED_PERSON_OBJECT,
            ASSIGNED_EXECUTIVE_FIELD
        );

        if (hasField(ASSIGNED_PERSON_OBJECT, ACTUAL_EXECUTIVE_FIELD)) {
            addFieldWithDisplayName(
                assignedFields,
                ASSIGNED_PERSON_OBJECT,
                ACTUAL_EXECUTIVE_FIELD
            );
        }

        String assignedPersonQuery =
            'SELECT ' + joinFields(assignedFields) +
            ' FROM ' + ASSIGNED_PERSON_OBJECT +
            ' WHERE ' + ASSIGNED_PERSON_ACTIVITY_FIELD + ' IN :activityIds' +
            ' WITH USER_MODE' +
            ' ORDER BY Name';

        List<SObject> assignedPersonRecords =
            Database.query(assignedPersonQuery);

        for (SObject assignedRecord : assignedPersonRecords) {
            Id assignmentId = (Id) assignedRecord.get('Id');
            Id activityId = (Id) assignedRecord.get(
                ASSIGNED_PERSON_ACTIVITY_FIELD
            );

            ActivityRow baseRow = baseActivityById.get(activityId);
            if (baseRow == null) {
                continue;
            }

            String teamName = getDisplayValue(
                assignedRecord,
                ASSIGNED_PERSON_OBJECT,
                ASSIGNED_PERSON_TEAM_FIELD
            );
            String teamKey = buildTeamKey(teamName);
            String rowKey = buildActivityTeamRowKey(activityId, teamKey);

            ActivityRow activityRow = context.activityRowByKey.get(rowKey);
            if (activityRow == null) {
                activityRow = createTeamActivityRow(
                    baseRow,
                    teamName,
                    teamKey,
                    rowKey
                );
                context.activityRowByKey.put(rowKey, activityRow);
                addTeamKeyForActivity(context, activityId, teamKey);
            }

            PersonRow person = new PersonRow();
            person.assignmentId = assignmentId;
            person.teamName = teamName;
            person.executiveId = getReferenceId(
                assignedRecord,
                ASSIGNED_PERSON_OBJECT,
                ASSIGNED_EXECUTIVE_FIELD
            );
            person.executiveName = getDisplayValue(
                assignedRecord,
                ASSIGNED_PERSON_OBJECT,
                ASSIGNED_EXECUTIVE_FIELD
            );

            if (hasField(ASSIGNED_PERSON_OBJECT, ACTUAL_EXECUTIVE_FIELD)) {
                person.actualExecutiveName = getDisplayValue(
                    assignedRecord,
                    ASSIGNED_PERSON_OBJECT,
                    ACTUAL_EXECUTIVE_FIELD
                );
            }

            activityRow.persons.add(person);
            activityRow.assignmentIds.add(assignmentId);

            context.assignmentIds.add(assignmentId);
            context.rowKeyByAssignmentId.put(assignmentId, rowKey);

            String baseExecutiveKey = getFieldKey(
                assignedRecord,
                ASSIGNED_PERSON_OBJECT,
                ASSIGNED_EXECUTIVE_FIELD
            );

            if (String.isBlank(baseExecutiveKey)) {
                baseExecutiveKey = normalizeTextKey(person.executiveName);
            }

            if (!String.isBlank(baseExecutiveKey)) {
                context.distinctExecutiveKeys.add(baseExecutiveKey);

                String executiveTeamKey =
                    baseExecutiveKey + '|' + teamKey;

                context.executiveTeamKeyByAssignmentId.put(
                    assignmentId,
                    executiveTeamKey
                );

                if (!context.executiveByKey.containsKey(executiveTeamKey)) {
                    ExecutiveRow executiveRow = new ExecutiveRow();
                    executiveRow.rowKey = executiveTeamKey;
                    executiveRow.executiveId = person.executiveId;
                    executiveRow.executiveName = person.executiveName;
                    executiveRow.teamName = teamName;
                    executiveRow.assignedActivities = 0;
                    executiveRow.targetLocations = 0;
                    executiveRow.customerResponses = 0;
                    context.executiveByKey.put(executiveTeamKey, executiveRow);
                }

                if (!context.activitiesByExecutive.containsKey(executiveTeamKey)) {
                    context.activitiesByExecutive.put(
                        executiveTeamKey,
                        new Set<Id>()
                    );
                }
                context.activitiesByExecutive.get(executiveTeamKey).add(activityId);
            }

            registerResponseExecutiveMapping(
                activityId,
                person.executiveName,
                rowKey,
                baseExecutiveKey,
                teamKey,
                context
            );
        }
    }

    private static void registerResponseExecutiveMapping(
        Id activityId,
        String executiveName,
        String teamRowKey,
        String baseExecutiveKey,
        String teamKey,
        TeamContext context
    ) {
        String normalizedExecutiveName = normalizeTextKey(executiveName);
        if (String.isBlank(normalizedExecutiveName)) {
            return;
        }

        String activityExecutiveNameKey =
            buildActivityExecutiveNameKey(
                activityId,
                normalizedExecutiveName
            );

        if (!context.ambiguousActivityExecutiveNames.contains(
            activityExecutiveNameKey
        )) {
            String existingRowKey =
                context.teamRowKeyByActivityExecutiveName.get(
                    activityExecutiveNameKey
                );

            if (String.isBlank(existingRowKey)) {
                context.teamRowKeyByActivityExecutiveName.put(
                    activityExecutiveNameKey,
                    teamRowKey
                );
            } else if (existingRowKey != teamRowKey) {
                context.teamRowKeyByActivityExecutiveName.remove(
                    activityExecutiveNameKey
                );
                context.ambiguousActivityExecutiveNames.add(
                    activityExecutiveNameKey
                );
            }
        }

        if (!String.isBlank(baseExecutiveKey)) {
            String executiveTeamKey = baseExecutiveKey + '|' + teamKey;

            if (!context.ambiguousExecutiveSummaryNames.contains(
                activityExecutiveNameKey
            )) {
                String existingExecutiveKey =
                    context.executiveSummaryKeyByActivityExecutiveName.get(
                        activityExecutiveNameKey
                    );

                if (String.isBlank(existingExecutiveKey)) {
                    context.executiveSummaryKeyByActivityExecutiveName.put(
                        activityExecutiveNameKey,
                        executiveTeamKey
                    );
                } else if (existingExecutiveKey != executiveTeamKey) {
                    context.executiveSummaryKeyByActivityExecutiveName.remove(
                        activityExecutiveNameKey
                    );
                    context.ambiguousExecutiveSummaryNames.add(
                        activityExecutiveNameKey
                    );
                }
            }
        }
    }

    private static void createRowsForActivitiesWithoutAssignments(
        List<Id> activityOrder,
        Map<Id, ActivityRow> baseActivityById,
        TeamContext context
    ) {
        for (Id activityId : activityOrder) {
            if (context.teamKeysByActivityId.containsKey(activityId)) {
                continue;
            }

            ActivityRow baseRow = baseActivityById.get(activityId);
            String rowKey = buildActivityTeamRowKey(
                activityId,
                NO_TEAM_KEY
            );

            ActivityRow activityRow = createTeamActivityRow(
                baseRow,
                null,
                NO_TEAM_KEY,
                rowKey
            );

            context.activityRowByKey.put(rowKey, activityRow);
            addTeamKeyForActivity(context, activityId, NO_TEAM_KEY);
        }
    }

    private static ActivityRow createTeamActivityRow(
        ActivityRow baseRow,
        String teamName,
        String teamKey,
        String rowKey
    ) {
        ActivityRow row = new ActivityRow();

        row.rowKey = rowKey;
        row.teamKey = teamKey;
        row.hasTeam = teamKey != NO_TEAM_KEY;
        row.activityId = baseRow.activityId;
        row.activityNo = baseRow.activityNo;
        row.activityName = baseRow.activityName;
        row.finalFormId = baseRow.finalFormId;
        row.finalFormName = baseRow.finalFormName;
        row.store = baseRow.store;
        row.startDate = baseRow.startDate;
        row.endDate = baseRow.endDate;
        row.duration = baseRow.duration;
        row.status = baseRow.status;
        row.ownerName = baseRow.ownerName;
        row.teamName = teamName;

        row.assignedPersons = 0;
        row.todayTargetLocations = 0;
        row.completedLocations = 0;
        row.customerResponsesToday = 0;
        row.totalResponses = 0;
        row.completionPercent = 0;
        row.assignmentIds = new List<Id>();
        row.persons = new List<PersonRow>();
        row.todayLocations = new List<String>();

        return row;
    }

    private static void addTeamKeyForActivity(
        TeamContext context,
        Id activityId,
        String teamKey
    ) {
        if (!context.teamKeysByActivityId.containsKey(activityId)) {
            context.teamKeysByActivityId.put(
                activityId,
                new Set<String>()
            );
        }
        context.teamKeysByActivityId.get(activityId).add(teamKey);
    }

    private static void loadTargetLocations(
        Date selectedDate,
        TeamContext context
    ) {
        if (context.assignmentIds.isEmpty()) {
            return;
        }

        Set<String> dateFields = new Set<String>{
            'Id',
            DATE_ASSIGNED_PERSON_FIELD,
            TARGET_DATE_FIELD,
            ACTUAL_DATE_FIELD
        };

        addFieldWithDisplayName(
            dateFields,
            ASSIGNED_PERSON_DATE_OBJECT,
            ACTIVITY_LOCATION_FIELD
        );

        Set<Id> assignmentIds = context.assignmentIds;

        String targetDateQuery =
            'SELECT ' + joinFields(dateFields) +
            ' FROM ' + ASSIGNED_PERSON_DATE_OBJECT +
            ' WHERE ' + DATE_ASSIGNED_PERSON_FIELD + ' IN :assignmentIds' +
            ' AND ' + TARGET_DATE_FIELD + ' = :selectedDate' +
            ' WITH USER_MODE';

        List<SObject> dateRecords = Database.query(targetDateQuery);

        for (SObject dateRecord : dateRecords) {
            Id assignmentId = (Id) dateRecord.get(
                DATE_ASSIGNED_PERSON_FIELD
            );
            String rowKey = context.rowKeyByAssignmentId.get(assignmentId);
            ActivityRow activityRow = context.activityRowByKey.get(rowKey);

            if (activityRow == null) {
                continue;
            }

            activityRow.todayTargetLocations++;

            String locationName = getDisplayValue(
                dateRecord,
                ASSIGNED_PERSON_DATE_OBJECT,
                ACTIVITY_LOCATION_FIELD
            );

            if (
                !String.isBlank(locationName) &&
                !activityRow.todayLocations.contains(locationName)
            ) {
                activityRow.todayLocations.add(locationName);
            }

            if (dateRecord.get(ACTUAL_DATE_FIELD) != null) {
                activityRow.completedLocations++;
            }

            String executiveTeamKey =
                context.executiveTeamKeyByAssignmentId.get(assignmentId);

            if (
                !String.isBlank(executiveTeamKey) &&
                context.executiveByKey.containsKey(executiveTeamKey)
            ) {
                context.executiveByKey.get(executiveTeamKey).targetLocations++;
            }
        }
    }

    private static void loadCustomerResponseCounts(
        Set<Id> activityIds,
        Date selectedDate,
        TeamContext context
    ) {
        String totalResponseQuery =
            'SELECT ' +
            RESPONSE_ACTIVITY_FIELD + ' activityId, ' +
            RESPONSE_EXECUTIVE_FIELD + ' executiveValue, ' +
            'COUNT(Id) responseCount' +
            ' FROM ' + CUSTOMER_RESPONSE_OBJECT +
            ' WHERE ' + RESPONSE_ACTIVITY_FIELD + ' IN :activityIds' +
            ' WITH USER_MODE' +
            ' GROUP BY ' +
            RESPONSE_ACTIVITY_FIELD + ', ' +
            RESPONSE_EXECUTIVE_FIELD;

        List<AggregateResult> totalResults =
            Database.query(totalResponseQuery);

        applyResponseAggregateCounts(
            totalResults,
            false,
            context
        );

        Schema.DisplayType responseDateType =
            getFieldDescribe(
                CUSTOMER_RESPONSE_OBJECT,
                RESPONSE_DATE_FIELD
            ).getType();

        DateTime dayStart = DateTime.newInstance(
            selectedDate,
            Time.newInstance(0, 0, 0, 0)
        );
        DateTime dayEnd = dayStart.addDays(1);

        String responseDateCondition;

        if (responseDateType == Schema.DisplayType.Date) {
            responseDateCondition =
                RESPONSE_DATE_FIELD + ' = :selectedDate';
        } else if (responseDateType == Schema.DisplayType.DateTime) {
            responseDateCondition =
                RESPONSE_DATE_FIELD + ' >= :dayStart' +
                ' AND ' +
                RESPONSE_DATE_FIELD + ' < :dayEnd';
        } else {
            throw new AuraHandledException(
                RESPONSE_DATE_FIELD +
                ' must be a Date or Date/Time field.'
            );
        }

        String todayResponseQuery =
            'SELECT ' +
            RESPONSE_ACTIVITY_FIELD + ' activityId, ' +
            RESPONSE_EXECUTIVE_FIELD + ' executiveValue, ' +
            'COUNT(Id) responseCount' +
            ' FROM ' + CUSTOMER_RESPONSE_OBJECT +
            ' WHERE ' + RESPONSE_ACTIVITY_FIELD + ' IN :activityIds' +
            ' AND ' + responseDateCondition +
            ' WITH USER_MODE' +
            ' GROUP BY ' +
            RESPONSE_ACTIVITY_FIELD + ', ' +
            RESPONSE_EXECUTIVE_FIELD;

        List<AggregateResult> todayResults =
            Database.query(todayResponseQuery);

        applyResponseAggregateCounts(
            todayResults,
            true,
            context
        );
    }

    private static void applyResponseAggregateCounts(
        List<AggregateResult> aggregateRecords,
        Boolean isToday,
        TeamContext context
    ) {
        for (AggregateResult result : aggregateRecords) {
            Id activityId = (Id) result.get('activityId');
            String executiveValue = result.get('executiveValue') == null
                ? null
                : String.valueOf(result.get('executiveValue'));
            Integer responseCount = (Integer) result.get('responseCount');

            String teamRowKey = resolveResponseTeamRowKey(
                activityId,
                executiveValue,
                context
            );

            ActivityRow activityRow =
                context.activityRowByKey.get(teamRowKey);

            if (activityRow != null) {
                if (isToday) {
                    activityRow.customerResponsesToday += responseCount;
                } else {
                    activityRow.totalResponses += responseCount;
                }
            }

            if (isToday) {
                updateExecutiveResponseCounts(
                    activityId,
                    executiveValue,
                    responseCount,
                    context
                );
            }
        }
    }

    private static String resolveResponseTeamRowKey(
        Id activityId,
        String executiveValue,
        TeamContext context
    ) {
        Set<String> teamKeys =
            context.teamKeysByActivityId.get(activityId);

        if (teamKeys == null || teamKeys.isEmpty()) {
            return null;
        }

        if (teamKeys.size() == 1) {
            for (String teamKey : teamKeys) {
                return buildActivityTeamRowKey(activityId, teamKey);
            }
        }

        Set<String> resolvedRowKeys = new Set<String>();

        for (String executiveName : splitExecutiveNames(executiveValue)) {
            String normalizedName = normalizeTextKey(executiveName);
            if (String.isBlank(normalizedName)) {
                continue;
            }

            String activityExecutiveNameKey =
                buildActivityExecutiveNameKey(
                    activityId,
                    normalizedName
                );

            if (
                context.ambiguousActivityExecutiveNames.contains(
                    activityExecutiveNameKey
                )
            ) {
                return null;
            }

            String rowKey =
                context.teamRowKeyByActivityExecutiveName.get(
                    activityExecutiveNameKey
                );

            if (!String.isBlank(rowKey)) {
                resolvedRowKeys.add(rowKey);
            }
        }

        if (resolvedRowKeys.size() != 1) {
            return null;
        }

        for (String rowKey : resolvedRowKeys) {
            return rowKey;
        }

        return null;
    }

    private static void updateExecutiveResponseCounts(
        Id activityId,
        String executiveValue,
        Integer responseCount,
        TeamContext context
    ) {
        Set<String> countedExecutiveKeys = new Set<String>();

        for (String executiveName : splitExecutiveNames(executiveValue)) {
            String normalizedName = normalizeTextKey(executiveName);
            if (String.isBlank(normalizedName)) {
                continue;
            }

            String activityExecutiveNameKey =
                buildActivityExecutiveNameKey(
                    activityId,
                    normalizedName
                );

            if (
                context.ambiguousExecutiveSummaryNames.contains(
                    activityExecutiveNameKey
                )
            ) {
                continue;
            }

            String executiveTeamKey =
                context.executiveSummaryKeyByActivityExecutiveName.get(
                    activityExecutiveNameKey
                );

            if (
                !String.isBlank(executiveTeamKey) &&
                !countedExecutiveKeys.contains(executiveTeamKey) &&
                context.executiveByKey.containsKey(executiveTeamKey)
            ) {
                context.executiveByKey.get(
                    executiveTeamKey
                ).customerResponses += responseCount;
                countedExecutiveKeys.add(executiveTeamKey);
            }
        }
    }

    private static List<String> splitExecutiveNames(String executiveValue) {
        List<String> executiveNames = new List<String>();

        if (String.isBlank(executiveValue)) {
            return executiveNames;
        }

        for (String value : executiveValue.split('[,;]')) {
            if (!String.isBlank(value)) {
                executiveNames.add(value.trim());
            }
        }

        return executiveNames;
    }

    private static void finaliseActivityRows(
        List<Id> activityOrder,
        DashboardResponse response,
        TeamContext context
    ) {
        for (Id activityId : activityOrder) {
            Set<String> teamKeySet =
                context.teamKeysByActivityId.get(activityId);

            if (teamKeySet == null || teamKeySet.isEmpty()) {
                continue;
            }

            List<String> namedTeamKeys = new List<String>();
            Boolean hasNoTeamRow = false;

            for (String teamKey : teamKeySet) {
                if (teamKey == NO_TEAM_KEY) {
                    hasNoTeamRow = true;
                } else {
                    namedTeamKeys.add(teamKey);
                }
            }

            namedTeamKeys.sort();

            List<String> orderedTeamKeys = new List<String>();
            orderedTeamKeys.addAll(namedTeamKeys);
            if (hasNoTeamRow) {
                orderedTeamKeys.add(NO_TEAM_KEY);
            }

            for (String teamKey : orderedTeamKeys) {
                String rowKey = buildActivityTeamRowKey(
                    activityId,
                    teamKey
                );
                ActivityRow row = context.activityRowByKey.get(rowKey);

                if (row == null) {
                    continue;
                }

                row.assignedPersons = row.persons.size();

                if (row.todayTargetLocations > 0) {
                    row.completionPercent =
                        (
                            Decimal.valueOf(
                                String.valueOf(row.completedLocations)
                            ) *
                            100 /
                            row.todayTargetLocations
                        ).setScale(1);
                }

                row.todayLocations.sort();
                response.activities.add(row);
            }
        }
    }

    private static void finaliseExecutiveRows(
        DashboardResponse response,
        TeamContext context
    ) {
        List<String> executiveKeys = new List<String>();
        executiveKeys.addAll(context.executiveByKey.keySet());
        executiveKeys.sort();

        for (String executiveKey : executiveKeys) {
            ExecutiveRow executiveRow =
                context.executiveByKey.get(executiveKey);
            Set<Id> assignedActivityIds =
                context.activitiesByExecutive.get(executiveKey);

            executiveRow.assignedActivities =
                assignedActivityIds == null
                    ? 0
                    : assignedActivityIds.size();

            response.executives.add(executiveRow);
        }

        response.assignedExecutives =
            context.distinctExecutiveKeys.size();
    }

    private static String calculateStatus(
        Date startDate,
        Date endDate,
        Date selectedDate
    ) {
        if (startDate == selectedDate) {
            return 'Starting Today';
        }

        if (
            endDate != null &&
            endDate >= selectedDate &&
            endDate <= selectedDate.addDays(3)
        ) {
            return 'Ending Soon';
        }

        return 'Active';
    }

    private static String buildTeamKey(String teamName) {
        String normalizedTeamName = normalizeTextKey(teamName);
        return String.isBlank(normalizedTeamName)
            ? NO_TEAM_KEY
            : normalizedTeamName;
    }

    private static String buildActivityTeamRowKey(
        Id activityId,
        String teamKey
    ) {
        return String.valueOf(activityId) + '|' + teamKey;
    }

    private static String buildActivityExecutiveNameKey(
        Id activityId,
        String normalizedExecutiveName
    ) {
        if (
            activityId == null ||
            String.isBlank(normalizedExecutiveName)
        ) {
            return null;
        }

        return String.valueOf(activityId) + '|' + normalizedExecutiveName;
    }

    private static Boolean isAllStoresSelection(String selectedStore) {
        return String.isBlank(selectedStore) ||
            selectedStore == 'ALL' ||
            selectedStore == 'All Stores';
    }

    private static String getActivityStoreFilterPath() {
        Schema.DescribeFieldResult fieldDescribe =
            getFieldDescribe(
                FORM_ACTIVITY_OBJECT,
                ACTIVITY_STORE_FIELD
            );

        if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
            String relationshipName = fieldDescribe.getRelationshipName();

            if (String.isBlank(relationshipName)) {
                throw new AuraHandledException(
                    'Unable to identify the Assigned Store relationship.'
                );
            }

            return relationshipName + '.Name';
        }

        return ACTIVITY_STORE_FIELD;
    }

    private static List<String> getAvailableStores() {
        List<String> stores = new List<String>();
        Schema.DescribeFieldResult fieldDescribe =
            User.Store__c.getDescribe();

        for (Schema.PicklistEntry picklistEntry : fieldDescribe.getPicklistValues()) {
            if (picklistEntry.isActive()) {
                stores.add(picklistEntry.getValue());
            }
        }

        stores.sort();
        return stores;
    }

    private static void validateConfiguration() {
        validateField(FORM_ACTIVITY_OBJECT, ACTIVITY_NAME_FIELD);
        validateField(FORM_ACTIVITY_OBJECT, ACTIVITY_STORE_FIELD);
        validateField(FORM_ACTIVITY_OBJECT, ACTIVITY_START_DATE_FIELD);
        validateField(FORM_ACTIVITY_OBJECT, ACTIVITY_END_DATE_FIELD);
        validateField(FORM_ACTIVITY_OBJECT, FINAL_CUSTOMIZE_FORM_FIELD);

        validateField(
            ASSIGNED_PERSON_OBJECT,
            ASSIGNED_PERSON_ACTIVITY_FIELD
        );
        validateField(
            ASSIGNED_PERSON_OBJECT,
            ASSIGNED_PERSON_TEAM_FIELD
        );
        validateField(
            ASSIGNED_PERSON_OBJECT,
            ASSIGNED_EXECUTIVE_FIELD
        );

        validateField(
            ASSIGNED_PERSON_DATE_OBJECT,
            DATE_ASSIGNED_PERSON_FIELD
        );
        validateField(
            ASSIGNED_PERSON_DATE_OBJECT,
            ACTIVITY_LOCATION_FIELD
        );
        validateField(
            ASSIGNED_PERSON_DATE_OBJECT,
            TARGET_DATE_FIELD
        );
        validateField(
            ASSIGNED_PERSON_DATE_OBJECT,
            ACTUAL_DATE_FIELD
        );

        validateField(
            CUSTOMER_RESPONSE_OBJECT,
            RESPONSE_ACTIVITY_FIELD
        );
        validateField(
            CUSTOMER_RESPONSE_OBJECT,
            RESPONSE_DATE_FIELD
        );
        validateField(
            CUSTOMER_RESPONSE_OBJECT,
            RESPONSE_EXECUTIVE_FIELD
        );
    }

    private static void addFieldWithDisplayName(
        Set<String> selectedFields,
        String objectApiName,
        String fieldApiName
    ) {
        Schema.DescribeFieldResult fieldDescribe =
            getFieldDescribe(objectApiName, fieldApiName);

        selectedFields.add(fieldApiName);

        if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
            String relationshipName = fieldDescribe.getRelationshipName();
            if (!String.isBlank(relationshipName)) {
                selectedFields.add(relationshipName + '.Name');
            }
        }
    }

    private static String getDisplayValue(
        SObject record,
        String objectApiName,
        String fieldApiName
    ) {
        Object rawValue = record.get(fieldApiName);

        if (rawValue == null) {
            return null;
        }

        Schema.DescribeFieldResult fieldDescribe =
            getFieldDescribe(objectApiName, fieldApiName);

        if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
            String relationshipName = fieldDescribe.getRelationshipName();

            if (!String.isBlank(relationshipName)) {
                SObject relatedRecord = record.getSObject(relationshipName);
                if (relatedRecord != null) {
                    return String.valueOf(relatedRecord.get('Name'));
                }
            }
        }

        return String.valueOf(rawValue);
    }

    private static String getReferenceId(
        SObject record,
        String objectApiName,
        String fieldApiName
    ) {
        Schema.DescribeFieldResult fieldDescribe =
            getFieldDescribe(objectApiName, fieldApiName);

        if (fieldDescribe.getType() != Schema.DisplayType.Reference) {
            return null;
        }

        Object value = record.get(fieldApiName);
        return value == null ? null : String.valueOf(value);
    }

    private static String getFieldKey(
        SObject record,
        String objectApiName,
        String fieldApiName
    ) {
        Schema.DescribeFieldResult fieldDescribe =
            getFieldDescribe(objectApiName, fieldApiName);
        Object value = record.get(fieldApiName);

        if (value == null) {
            return null;
        }

        if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
            return String.valueOf(value);
        }

        return normalizeTextKey(String.valueOf(value));
    }

    private static String normalizeTextKey(String value) {
        return String.isBlank(value)
            ? null
            : value.trim().toUpperCase();
    }

    private static Date getDateValue(
        SObject record,
        String fieldApiName
    ) {
        Object value = record.get(fieldApiName);

        if (value == null) {
            return null;
        }

        if (value instanceof Date) {
            return (Date) value;
        }

        if (value instanceof DateTime) {
            return ((DateTime) value).date();
        }

        return null;
    }

    private static String joinFields(Set<String> fields) {
        List<String> fieldList = new List<String>();
        fieldList.addAll(fields);
        fieldList.sort();
        return String.join(fieldList, ', ');
    }

    private static Boolean hasField(
        String objectApiName,
        String fieldApiName
    ) {
        Schema.SObjectType objectType =
            Schema.getGlobalDescribe().get(objectApiName);

        if (objectType == null) {
            return false;
        }

        return objectType
            .getDescribe()
            .fields
            .getMap()
            .containsKey(fieldApiName);
    }

    private static void validateField(
        String objectApiName,
        String fieldApiName
    ) {
        getFieldDescribe(objectApiName, fieldApiName);
    }

    private static Schema.DescribeFieldResult getFieldDescribe(
        String objectApiName,
        String fieldApiName
    ) {
        Schema.SObjectType objectType =
            Schema.getGlobalDescribe().get(objectApiName);

        if (objectType == null) {
            throw new AuraHandledException(
                'Dashboard configuration error. Object not found: ' +
                objectApiName
            );
        }

        Map<String, Schema.SObjectField> fieldMap =
            objectType.getDescribe().fields.getMap();

        if (!fieldMap.containsKey(fieldApiName)) {
            throw new AuraHandledException(
                'Dashboard configuration error. Field not found: ' +
                objectApiName + '.' + fieldApiName
            );
        }

        return fieldMap.get(fieldApiName).getDescribe();
    }

    private class TeamContext {
        private Map<String, ActivityRow> activityRowByKey =
            new Map<String, ActivityRow>();
        private Map<Id, Set<String>> teamKeysByActivityId =
            new Map<Id, Set<String>>();
        private Set<Id> assignmentIds = new Set<Id>();
        private Map<Id, String> rowKeyByAssignmentId =
            new Map<Id, String>();
        private Map<Id, String> executiveTeamKeyByAssignmentId =
            new Map<Id, String>();
        private Map<String, ExecutiveRow> executiveByKey =
            new Map<String, ExecutiveRow>();
        private Map<String, Set<Id>> activitiesByExecutive =
            new Map<String, Set<Id>>();
        private Map<String, String> teamRowKeyByActivityExecutiveName =
            new Map<String, String>();
        private Set<String> ambiguousActivityExecutiveNames =
            new Set<String>();
        private Map<String, String> executiveSummaryKeyByActivityExecutiveName =
            new Map<String, String>();
        private Set<String> ambiguousExecutiveSummaryNames =
            new Set<String>();
        private Set<String> distinctExecutiveKeys = new Set<String>();
    }

    public class DashboardResponse {
        @AuraEnabled public String store { get; set; }
        @AuraEnabled public Date selectedDate { get; set; }
        @AuraEnabled public DateTime refreshedAt { get; set; }
        @AuraEnabled public Boolean isSystemAdministrator { get; set; }
        @AuraEnabled public List<String> availableStores { get; set; }
        @AuraEnabled public String formActivityObjectApiName { get; set; }
        @AuraEnabled public Integer activeToday { get; set; }
        @AuraEnabled public Integer startingToday { get; set; }
        @AuraEnabled public Integer endingSoon { get; set; }
        @AuraEnabled public Integer assignedExecutives { get; set; }
        @AuraEnabled public List<ActivityRow> activities { get; set; }
        @AuraEnabled public List<ExecutiveRow> executives { get; set; }

        public DashboardResponse() {
            activeToday = 0;
            startingToday = 0;
            endingSoon = 0;
            assignedExecutives = 0;
            isSystemAdministrator = false;
            availableStores = new List<String>();
        }
    }

    public class ActivityRow {
        @AuraEnabled public String rowKey { get; set; }
        @AuraEnabled public String teamKey { get; set; }
        @AuraEnabled public Boolean hasTeam { get; set; }
        @AuraEnabled public Id activityId { get; set; }
        @AuraEnabled public String activityNo { get; set; }
        @AuraEnabled public String activityName { get; set; }
        @AuraEnabled public String finalFormId { get; set; }
        @AuraEnabled public String finalFormName { get; set; }
        @AuraEnabled public String store { get; set; }
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        @AuraEnabled public Integer duration { get; set; }
        @AuraEnabled public Integer assignedPersons { get; set; }
        @AuraEnabled public Integer todayTargetLocations { get; set; }
        @AuraEnabled public Integer completedLocations { get; set; }
        @AuraEnabled public Integer customerResponsesToday { get; set; }
        @AuraEnabled public Integer totalResponses { get; set; }
        @AuraEnabled public Decimal completionPercent { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String teamName { get; set; }
        @AuraEnabled public List<Id> assignmentIds { get; set; }
        @AuraEnabled public List<PersonRow> persons { get; set; }
        @AuraEnabled public List<String> todayLocations { get; set; }
    }

    public class PersonRow {
        @AuraEnabled public Id assignmentId { get; set; }
        @AuraEnabled public String executiveId { get; set; }
        @AuraEnabled public String executiveName { get; set; }
        @AuraEnabled public String actualExecutiveName { get; set; }
        @AuraEnabled public String teamName { get; set; }
    }

    public class ExecutiveRow {
        @AuraEnabled public String rowKey { get; set; }
        @AuraEnabled public String executiveId { get; set; }
        @AuraEnabled public String executiveName { get; set; }
        @AuraEnabled public String teamName { get; set; }
        @AuraEnabled public Integer assignedActivities { get; set; }
        @AuraEnabled public Integer targetLocations { get; set; }
        @AuraEnabled public Integer customerResponses { get; set; }
    }
}