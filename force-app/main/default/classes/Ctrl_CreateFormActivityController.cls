/**
 * Class Name  : Ctrl_CreateFormActivityController
 *
 * Description :
 * Creates one Form Activity per selected Store.
 *
 * Supports:
 * - Multiple Stores
 * - Multiple Teams per Store
 * - Multiple Sales Executives per Team
 * - Target-date-wise Activity Locations
 * - Returning created Form Activity IDs for navigation
 */
public with sharing class Ctrl_CreateFormActivityController {

    /* =========================================================
       CUSTOM METADATA CONFIGURATION
       ========================================================= */

    private static final String TEAM_METADATA_OBJECT_API = 'Team__mdt';

    private static final String TEAM_METADATA_NAME_FIELD_API = 'Team_Name__c';


    /* =========================================================
       FORM ACTIVITY ASSIGNED PERSON CONFIGURATION
       ========================================================= */

    /*
     * Change this constant only when the actual field API name
     * in your Salesforce org is different.
     */
    private static final String ASSIGNED_PERSON_TEAM_FIELD_API =
        'Team_Name__c';


    /* =========================================================
       ASSIGNED PERSON DATE CONFIGURATION
       ========================================================= */

    private static final String ASSIGNED_PERSON_DATE_OBJECT_API =
        'Form_Activity_Assigned_Persons_Date__c';

    private static final String ASSIGNED_PERSON_DATE_PARENT_FIELD_API =
        'Form_Activity_Assigned_Persons__c';

    private static final String ASSIGNED_PERSON_TARGET_DATE_FIELD_API =
        'Target_Date__c';

    /*
     * Change this constant only when the actual field API name
     * in your Salesforce org is different.
     */
    private static final String ASSIGNED_PERSON_DATE_LOCATION_FIELD_API =
        'Activity_Location__c';


    /* =========================================================
       GET STORES
       ========================================================= */

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getStores() {

        List<OptionWrapper> options =
            new List<OptionWrapper>();

        for (Store__c storeRecord : [
            SELECT Id, Name
            FROM Store__c
            ORDER BY Name ASC
            LIMIT 500
        ]) {
            options.add(
                new OptionWrapper(
                    String.valueOf(storeRecord.Id),
                    storeRecord.Name
                )
            );
        }

        return options;
    }


    /* =========================================================
       GET TEAMS FROM CUSTOM METADATA
       ========================================================= */

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getTeams() {

        List<OptionWrapper> options =
            new List<OptionWrapper>();

        Schema.SObjectType teamMetadataType =
            Schema.getGlobalDescribe().get(
                TEAM_METADATA_OBJECT_API
            );

        if (teamMetadataType == null) {
            throw new AuraHandledException(
                'Team Custom Metadata Type was not found. ' +
                'Please check API name: ' +
                TEAM_METADATA_OBJECT_API
            );
        }

        Map<String, Schema.SObjectField> teamFieldMap =
            teamMetadataType
                .getDescribe()
                .fields
                .getMap();

        if (
            !teamFieldMap.containsKey(
                TEAM_METADATA_NAME_FIELD_API
            )
        ) {
            throw new AuraHandledException(
                'Team Name field was not found on Team ' +
                'Custom Metadata. Please check API name: ' +
                TEAM_METADATA_NAME_FIELD_API
            );
        }

        String queryText =
            'SELECT DeveloperName, MasterLabel, ' +
            TEAM_METADATA_NAME_FIELD_API +
            ' FROM ' +
            TEAM_METADATA_OBJECT_API +
            ' ORDER BY ' +
            TEAM_METADATA_NAME_FIELD_API +
            ' ASC';

        Set<String> addedTeamNames =
            new Set<String>();

        for (
            SObject metadataRecord :
            Database.query(queryText)
        ) {
            Object rawTeamName =
                metadataRecord.get(
                    TEAM_METADATA_NAME_FIELD_API
                );

            String teamName =
                rawTeamName == null
                    ? null
                    : String.valueOf(rawTeamName).trim();

            if (
                String.isNotBlank(teamName) &&
                !addedTeamNames.contains(teamName)
            ) {
                addedTeamNames.add(teamName);

                options.add(
                    new OptionWrapper(
                        teamName,
                        teamName
                    )
                );
            }
        }

        return options;
    }


    /* =========================================================
       GET SALES EXECUTIVES FOR SELECTED STORES
       ========================================================= */

    @AuraEnabled(cacheable=true)
    public static List<SalesExecutiveOptionWrapper>
        getSalesExecutivesByStores(
            List<Id> storeIds
        ) {

        List<SalesExecutiveOptionWrapper> options =
            new List<SalesExecutiveOptionWrapper>();

        Set<Id> storeIdSet =
            new Set<Id>();

        if (storeIds != null) {
            for (Id storeId : storeIds) {
                if (storeId != null) {
                    storeIdSet.add(storeId);
                }
            }
        }

        if (storeIdSet.isEmpty()) {
            return options;
        }

        for (Sales_Executives__c executiveRecord : [
            SELECT
                Id,
                Name,
                Store__c,
                Store__r.Name
            FROM Sales_Executives__c
            WHERE Store__c IN :storeIdSet
            ORDER BY
                Store__r.Name ASC,
                Name ASC
            LIMIT 1000
        ]) {
            options.add(
                new SalesExecutiveOptionWrapper(
                    String.valueOf(
                        executiveRecord.Id
                    ),
                    executiveRecord.Name,
                    String.valueOf(
                        executiveRecord.Store__c
                    ),
                    executiveRecord.Store__r != null
                        ? executiveRecord.Store__r.Name
                        : ''
                )
            );
        }

        return options;
    }


    /* =========================================================
       CREATE FORM ACTIVITIES
       ========================================================= */

    @AuraEnabled
    public static List<Id> createActivity(
        Id finalCustomizeFormId,
        List<Id> assignedStoreIds,
        String activityName,
        Date activityDate,
        Date activityEndDate,
        List<SalesExecutiveAssignmentWrapper>
            salesExecutiveAssignments
    ) {

        validateMainActivityInputs(
            finalCustomizeFormId,
            activityName,
            activityDate,
            activityEndDate
        );


        /* -----------------------------------------------------
           NORMALIZE SELECTED STORES
           ----------------------------------------------------- */

        List<Id> finalStoreIds =
            new List<Id>();

        Set<Id> storeIdSet =
            new Set<Id>();

        if (assignedStoreIds != null) {
            for (Id storeId : assignedStoreIds) {

                if (
                    storeId != null &&
                    !storeIdSet.contains(storeId)
                ) {
                    storeIdSet.add(storeId);
                    finalStoreIds.add(storeId);
                }
            }
        }

        if (finalStoreIds.isEmpty()) {
            throw new AuraHandledException(
                'Please select at least one Assigned Store.'
            );
        }


        /* -----------------------------------------------------
           VALIDATE STORES
           ----------------------------------------------------- */

        Map<Id, Store__c> storeMap =
            new Map<Id, Store__c>([
                SELECT Id, Name
                FROM Store__c
                WHERE Id IN :storeIdSet
            ]);

        if (
            storeMap.size() !=
            storeIdSet.size()
        ) {
            throw new AuraHandledException(
                'One or more selected Stores are invalid ' +
                'or unavailable.'
            );
        }


        /* -----------------------------------------------------
           VALIDATE REQUIRED OBJECTS AND FIELDS
           ----------------------------------------------------- */

        SchemaValidationResult schemaResult =
            validateRequiredSchema();

        Set<String> validTeamNames =
            getValidTeamNames();

        if (validTeamNames.isEmpty()) {
            throw new AuraHandledException(
                'No Team records are available in ' +
                'Team Custom Metadata.'
            );
        }


        /* -----------------------------------------------------
           VALIDATE SALES EXECUTIVE ASSIGNMENTS
           ----------------------------------------------------- */

        if (
            salesExecutiveAssignments == null ||
            salesExecutiveAssignments.isEmpty()
        ) {
            throw new AuraHandledException(
                'Please select at least one Sales Executive.'
            );
        }

        Set<Id> selectedExecutiveIdSet =
            new Set<Id>();

        Map<Id, NormalizedExecutiveAssignment>
            normalizedAssignmentByExecutiveId =
                new Map<
                    Id,
                    NormalizedExecutiveAssignment
                >();

        for (
            SalesExecutiveAssignmentWrapper assignment :
            salesExecutiveAssignments
        ) {
            if (
                assignment == null ||
                String.isBlank(
                    assignment.salesExecutiveId
                )
            ) {
                continue;
            }

            Id executiveId;

            try {
                executiveId =
                    (Id) assignment.salesExecutiveId;
            } catch (Exception exceptionRecord) {
                throw new AuraHandledException(
                    'Invalid Sales Executive selected.'
                );
            }

            /*
             * One Sales Executive can belong to only one
             * Team within this activity creation transaction.
             */
            if (
                selectedExecutiveIdSet.contains(
                    executiveId
                )
            ) {
                throw new AuraHandledException(
                    'The same Sales Executive cannot be ' +
                    'assigned to more than one Team.'
                );
            }

            if (
                String.isBlank(
                    assignment.teamName
                )
            ) {
                throw new AuraHandledException(
                    'Please select a Team for every selected ' +
                    'Sales Executive.'
                );
            }

            String selectedTeamName =
                assignment.teamName.trim();

            if (
                !validTeamNames.contains(
                    selectedTeamName
                )
            ) {
                throw new AuraHandledException(
                    'Invalid Team selected: ' +
                    selectedTeamName
                );
            }

            if (
                assignment.dateAssignments == null ||
                assignment.dateAssignments.isEmpty()
            ) {
                throw new AuraHandledException(
                    'Please select Target Date(s) for every ' +
                    'selected Sales Executive.'
                );
            }

            List<NormalizedDateAssignment>
                normalizedDateAssignments =
                    new List<
                        NormalizedDateAssignment
                    >();

            Set<Date> uniqueTargetDates =
                new Set<Date>();

            for (
                DateAssignmentWrapper dateAssignment :
                assignment.dateAssignments
            ) {
                if (
                    dateAssignment == null ||
                    String.isBlank(
                        dateAssignment.targetDate
                    )
                ) {
                    continue;
                }

                Date targetDate;

                try {
                    targetDate =
                        Date.valueOf(
                            dateAssignment.targetDate
                        );
                } catch (Exception exceptionRecord) {
                    throw new AuraHandledException(
                        'Invalid Target Date selected.'
                    );
                }

                if (
                    targetDate < activityDate ||
                    targetDate > activityEndDate
                ) {
                    throw new AuraHandledException(
                        'Target Date(s) must be between ' +
                        'Activity Start Date and Activity End Date.'
                    );
                }

                if (
                    uniqueTargetDates.contains(
                        targetDate
                    )
                ) {
                    throw new AuraHandledException(
                        'The same Target Date cannot be selected ' +
                        'more than once for a Sales Executive.'
                    );
                }

                if (
                    String.isBlank(
                        dateAssignment.activityLocation
                    )
                ) {
                    throw new AuraHandledException(
                        'Please enter Activity Location for ' +
                        'every selected Target Date.'
                    );
                }

                uniqueTargetDates.add(targetDate);

                normalizedDateAssignments.add(
                    new NormalizedDateAssignment(
                        targetDate,
                        normalizeActivityLocation(
                            dateAssignment.activityLocation
                        )
                    )
                );
            }

            if (
                normalizedDateAssignments.isEmpty()
            ) {
                throw new AuraHandledException(
                    'Please select Target Date(s) for every ' +
                    'selected Sales Executive.'
                );
            }

            selectedExecutiveIdSet.add(
                executiveId
            );

            normalizedAssignmentByExecutiveId.put(
                executiveId,
                new NormalizedExecutiveAssignment(
                    executiveId,
                    selectedTeamName,
                    normalizedDateAssignments
                )
            );
        }

        if (
            selectedExecutiveIdSet.isEmpty()
        ) {
            throw new AuraHandledException(
                'Please select at least one Sales Executive.'
            );
        }


        /* -----------------------------------------------------
           QUERY AND VALIDATE SELECTED EXECUTIVES
           ----------------------------------------------------- */

        List<Sales_Executives__c> selectedExecutives = [
            SELECT
                Id,
                Name,
                Store__c,
                Store__r.Name
            FROM Sales_Executives__c
            WHERE Id IN :selectedExecutiveIdSet
            AND Store__c IN :storeIdSet
        ];

        if (
            selectedExecutives.size() !=
            selectedExecutiveIdSet.size()
        ) {
            throw new AuraHandledException(
                'One or more selected Sales Executives do not ' +
                'belong to the selected Stores.'
            );
        }

        /*
         * One Store + Team + Target Date represents one activity
         * execution location. Every Sales Executive assigned to
         * that same grouping must therefore carry the same
         * Activity Location.
         */
        validateSharedDateLocations(
            selectedExecutives,
            normalizedAssignmentByExecutiveId
        );

        Map<Id, List<Sales_Executives__c>>
            executivesByStoreId =
                new Map<
                    Id,
                    List<Sales_Executives__c>
                >();

        for (
            Sales_Executives__c executiveRecord :
            selectedExecutives
        ) {
            if (
                !executivesByStoreId.containsKey(
                    executiveRecord.Store__c
                )
            ) {
                executivesByStoreId.put(
                    executiveRecord.Store__c,
                    new List<
                        Sales_Executives__c
                    >()
                );
            }

            executivesByStoreId
                .get(executiveRecord.Store__c)
                .add(executiveRecord);
        }


        /* -----------------------------------------------------
           REQUIRE EXECUTIVE FOR EVERY SELECTED STORE
           ----------------------------------------------------- */

        List<String> missingExecutiveStoreNames =
            new List<String>();

        for (Id storeId : finalStoreIds) {
            if (
                !executivesByStoreId.containsKey(
                    storeId
                ) ||
                executivesByStoreId
                    .get(storeId)
                    .isEmpty()
            ) {
                missingExecutiveStoreNames.add(
                    storeMap.containsKey(storeId)
                        ? storeMap.get(storeId).Name
                        : String.valueOf(storeId)
                );
            }
        }

        if (
            !missingExecutiveStoreNames.isEmpty()
        ) {
            throw new AuraHandledException(
                'Please select at least one Sales Executive ' +
                'for each selected Store. Missing Store(s): ' +
                String.join(
                    missingExecutiveStoreNames,
                    ', '
                )
            );
        }


        /* -----------------------------------------------------
           CREATE ONE FORM ACTIVITY PER STORE
           ----------------------------------------------------- */

        List<Form_Activity__c> activitiesToInsert =
            new List<Form_Activity__c>();

        for (Id storeId : finalStoreIds) {
            activitiesToInsert.add(
                new Form_Activity__c(
                    Final_Customize_Form__c =
                        finalCustomizeFormId,
                    Assigned_Store__c =
                        storeId,
                    Activity_Name__c =
                        activityName.trim(),
                    Activity_Date__c =
                        activityDate,
                    Activity_End_Date__c =
                        activityEndDate
                )
            );
        }

        insert activitiesToInsert;


        /* -----------------------------------------------------
           CREATE ASSIGNED PERSON RECORDS
           ----------------------------------------------------- */

        List<Form_Activity_Assigned_Persons__c>
            assignedPersonsToInsert =
                new List<
                    Form_Activity_Assigned_Persons__c
                >();

        for (
            Form_Activity__c activityRecord :
            activitiesToInsert
        ) {
            List<Sales_Executives__c>
                executivesForStore =
                    executivesByStoreId.get(
                        activityRecord
                            .Assigned_Store__c
                    );

            if (executivesForStore == null) {
                continue;
            }

            for (
                Sales_Executives__c executiveRecord :
                executivesForStore
            ) {
                NormalizedExecutiveAssignment
                    normalizedAssignment =
                        normalizedAssignmentByExecutiveId
                            .get(executiveRecord.Id);

                if (normalizedAssignment == null) {
                    continue;
                }

                Form_Activity_Assigned_Persons__c
                    assignedPerson =
                        new Form_Activity_Assigned_Persons__c();

                assignedPerson.Form_Activity__c =
                    activityRecord.Id;

                assignedPerson.Store__c =
                    activityRecord.Assigned_Store__c;

                assignedPerson.Sales_Executives__c =
                    executiveRecord.Id;

                assignedPerson.Person_Name__c =
                    executiveRecord.Name;

                assignedPerson.put(
                    ASSIGNED_PERSON_TEAM_FIELD_API,
                    normalizedAssignment.teamName
                );

                assignedPersonsToInsert.add(
                    assignedPerson
                );
            }
        }

        if (
            !assignedPersonsToInsert.isEmpty()
        ) {
            insert assignedPersonsToInsert;
        }


        /* -----------------------------------------------------
           CREATE TARGET-DATE-WISE LOCATION RECORDS
           ----------------------------------------------------- */

        List<SObject> assignedPersonDateRows =
            new List<SObject>();

        for (
            Form_Activity_Assigned_Persons__c
                assignedPerson :
            assignedPersonsToInsert
        ) {
            NormalizedExecutiveAssignment
                normalizedAssignment =
                    normalizedAssignmentByExecutiveId.get(
                        assignedPerson
                            .Sales_Executives__c
                    );

            if (normalizedAssignment == null) {
                continue;
            }

            for (
                NormalizedDateAssignment
                    dateAssignment :
                normalizedAssignment
                    .dateAssignments
            ) {
                SObject dateRow =
                    schemaResult
                        .dateObjectType
                        .newSObject();

                dateRow.put(
                    ASSIGNED_PERSON_DATE_PARENT_FIELD_API,
                    assignedPerson.Id
                );

                dateRow.put(
                    ASSIGNED_PERSON_TARGET_DATE_FIELD_API,
                    dateAssignment.targetDate
                );

                dateRow.put(
                    ASSIGNED_PERSON_DATE_LOCATION_FIELD_API,
                    dateAssignment.activityLocation
                );

                assignedPersonDateRows.add(
                    dateRow
                );
            }
        }

        if (
            !assignedPersonDateRows.isEmpty()
        ) {
            insert assignedPersonDateRows;
        }


        /* -----------------------------------------------------
           RETURN CREATED FORM ACTIVITY IDS
           ----------------------------------------------------- */

        List<Id> createdActivityIds =
            new List<Id>();

        /*
         * activitiesToInsert retains the same order as
         * finalStoreIds. Therefore, the first returned ID
         * corresponds to the first selected Store.
         */
        for (
            Form_Activity__c activityRecord :
            activitiesToInsert
        ) {
            createdActivityIds.add(
                activityRecord.Id
            );
        }

        return createdActivityIds;
    }


    private static String normalizeActivityLocation(
        String activityLocation
    ) {
        return String.isBlank(activityLocation)
            ? null
            : activityLocation.trim().toUpperCase();
    }


    /* =========================================================
       VALIDATE SHARED STORE + TEAM + DATE LOCATION
       ========================================================= */

    private static void validateSharedDateLocations(
        List<Sales_Executives__c> selectedExecutives,
        Map<Id, NormalizedExecutiveAssignment>
            normalizedAssignmentByExecutiveId
    ) {
        Map<String, String> locationByGroupKey =
            new Map<String, String>();

        for (
            Sales_Executives__c executiveRecord :
            selectedExecutives
        ) {
            NormalizedExecutiveAssignment
                normalizedAssignment =
                    normalizedAssignmentByExecutiveId.get(
                        executiveRecord.Id
                    );

            if (normalizedAssignment == null) {
                continue;
            }

            for (
                NormalizedDateAssignment
                    dateAssignment :
                normalizedAssignment.dateAssignments
            ) {
                String groupKey =
                    String.valueOf(
                        executiveRecord.Store__c
                    ) +
                    '||' +
                    (
                        normalizedAssignment.teamName == null
                            ? ''
                            : normalizedAssignment
                                .teamName
                                .trim()
                                .toLowerCase()
                    ) +
                    '||' +
                    String.valueOf(
                        dateAssignment.targetDate
                    );

                String currentLocation =
                    dateAssignment.activityLocation == null
                        ? ''
                        : dateAssignment
                            .activityLocation
                            .trim();

                if (
                    !locationByGroupKey.containsKey(
                        groupKey
                    )
                ) {
                    locationByGroupKey.put(
                        groupKey,
                        currentLocation
                    );

                    continue;
                }

                if (
                    locationByGroupKey.get(
                        groupKey
                    ) != currentLocation
                ) {
                    throw new AuraHandledException(
                        'Activity Location must be the same ' +
                        'for Store ' +
                        (
                            executiveRecord.Store__r != null
                                ? executiveRecord
                                    .Store__r
                                    .Name
                                : String.valueOf(
                                    executiveRecord
                                        .Store__c
                                )
                        ) +
                        ', Team ' +
                        normalizedAssignment.teamName +
                        ' and Target Date ' +
                        String.valueOf(
                            dateAssignment.targetDate
                        ) +
                        '.'
                    );
                }
            }
        }
    }


    /* =========================================================
       MAIN INPUT VALIDATION
       ========================================================= */

    private static void validateMainActivityInputs(
        Id finalCustomizeFormId,
        String activityName,
        Date activityDate,
        Date activityEndDate
    ) {
        if (finalCustomizeFormId == null) {
            throw new AuraHandledException(
                'Final Customize Form record id is missing.'
            );
        }

        if (String.isBlank(activityName)) {
            throw new AuraHandledException(
                'Please enter Activity Name.'
            );
        }

        if (activityDate == null) {
            throw new AuraHandledException(
                'Please enter Activity Start Date.'
            );
        }

        if (activityEndDate == null) {
            throw new AuraHandledException(
                'Please enter Activity End Date.'
            );
        }

        if (
            activityEndDate < activityDate
        ) {
            throw new AuraHandledException(
                'Activity End Date cannot be before ' +
                'Activity Start Date.'
            );
        }
    }


    /* =========================================================
       GET VALID TEAM NAMES
       ========================================================= */

    private static Set<String> getValidTeamNames() {

        Set<String> validTeamNames =
            new Set<String>();

        Schema.SObjectType teamMetadataType =
            Schema.getGlobalDescribe().get(
                TEAM_METADATA_OBJECT_API
            );

        if (teamMetadataType == null) {
            throw new AuraHandledException(
                'Team Custom Metadata Type was not found. ' +
                'Please check API name: ' +
                TEAM_METADATA_OBJECT_API
            );
        }

        Map<String, Schema.SObjectField> teamFieldMap =
            teamMetadataType
                .getDescribe()
                .fields
                .getMap();

        if (
            !teamFieldMap.containsKey(
                TEAM_METADATA_NAME_FIELD_API
            )
        ) {
            throw new AuraHandledException(
                'Team Name field was not found on Team ' +
                'Custom Metadata. Please check API name: ' +
                TEAM_METADATA_NAME_FIELD_API
            );
        }

        String queryText =
            'SELECT ' +
            TEAM_METADATA_NAME_FIELD_API +
            ' FROM ' +
            TEAM_METADATA_OBJECT_API;

        for (
            SObject metadataRecord :
            Database.query(queryText)
        ) {
            Object rawTeamName =
                metadataRecord.get(
                    TEAM_METADATA_NAME_FIELD_API
                );

            String teamName =
                rawTeamName == null
                    ? null
                    : String.valueOf(
                        rawTeamName
                    ).trim();

            if (
                String.isNotBlank(teamName)
            ) {
                validTeamNames.add(teamName);
            }
        }

        return validTeamNames;
    }


    /* =========================================================
       VALIDATE REQUIRED OBJECTS AND FIELDS
       ========================================================= */

    private static SchemaValidationResult
        validateRequiredSchema() {

        Schema.SObjectType assignedPersonObjectType =
            Schema.getGlobalDescribe().get(
                'Form_Activity_Assigned_Persons__c'
            );

        if (
            assignedPersonObjectType == null
        ) {
            throw new AuraHandledException(
                'Assigned Person object was not found.'
            );
        }

        Map<String, Schema.SObjectField>
            assignedPersonFieldMap =
                assignedPersonObjectType
                    .getDescribe()
                    .fields
                    .getMap();

        if (
            !assignedPersonFieldMap.containsKey(
                ASSIGNED_PERSON_TEAM_FIELD_API
            )
        ) {
            throw new AuraHandledException(
                'Team field was not found on Form Activity ' +
                '- Assigned Persons. Please check API name: ' +
                ASSIGNED_PERSON_TEAM_FIELD_API
            );
        }

        Schema.SObjectType dateObjectType =
            Schema.getGlobalDescribe().get(
                ASSIGNED_PERSON_DATE_OBJECT_API
            );

        if (dateObjectType == null) {
            throw new AuraHandledException(
                'Date child object was not found. ' +
                'Please check API name: ' +
                ASSIGNED_PERSON_DATE_OBJECT_API
            );
        }

        Map<String, Schema.SObjectField>
            dateFieldMap =
                dateObjectType
                    .getDescribe()
                    .fields
                    .getMap();

        if (
            !dateFieldMap.containsKey(
                ASSIGNED_PERSON_DATE_PARENT_FIELD_API
            )
        ) {
            throw new AuraHandledException(
                'Parent lookup field was not found on the ' +
                'date child object. Please check API name: ' +
                ASSIGNED_PERSON_DATE_PARENT_FIELD_API
            );
        }

        if (
            !dateFieldMap.containsKey(
                ASSIGNED_PERSON_TARGET_DATE_FIELD_API
            )
        ) {
            throw new AuraHandledException(
                'Target Date field was not found on the date ' +
                'child object. Please check API name: ' +
                ASSIGNED_PERSON_TARGET_DATE_FIELD_API
            );
        }

        if (
            !dateFieldMap.containsKey(
                ASSIGNED_PERSON_DATE_LOCATION_FIELD_API
            )
        ) {
            throw new AuraHandledException(
                'Activity Location field was not found on ' +
                'the date child object. Please check API name: ' +
                ASSIGNED_PERSON_DATE_LOCATION_FIELD_API
            );
        }

        return new SchemaValidationResult(
            dateObjectType
        );
    }


    /* =========================================================
       AURA-ENABLED WRAPPERS
       ========================================================= */

    public class OptionWrapper {

        @AuraEnabled
        public String label;

        @AuraEnabled
        public String value;

        public OptionWrapper(
            String value,
            String label
        ) {
            this.value = value;
            this.label = label;
        }
    }


    public class SalesExecutiveOptionWrapper {

        @AuraEnabled
        public String label;

        @AuraEnabled
        public String value;

        @AuraEnabled
        public String storeId;

        @AuraEnabled
        public String storeName;

        public SalesExecutiveOptionWrapper(
            String value,
            String label,
            String storeId,
            String storeName
        ) {
            this.value = value;
            this.label = label;
            this.storeId = storeId;
            this.storeName = storeName;
        }
    }


    public class SalesExecutiveAssignmentWrapper {

        @AuraEnabled
        public String salesExecutiveId {
            get;
            set;
        }

        @AuraEnabled
        public String teamName {
            get;
            set;
        }

        @AuraEnabled
        public List<DateAssignmentWrapper>
            dateAssignments {
                get;
                set;
            }
    }


    public class DateAssignmentWrapper {

        @AuraEnabled
        public String targetDate {
            get;
            set;
        }

        @AuraEnabled
        public String activityLocation {
            get;
            set;
        }
    }


    /* =========================================================
       INTERNAL NORMALIZED WRAPPERS
       ========================================================= */

    private class NormalizedExecutiveAssignment {

        private Id executiveId;
        private String teamName;

        private List<NormalizedDateAssignment>
            dateAssignments;

        private NormalizedExecutiveAssignment(
            Id executiveId,
            String teamName,
            List<NormalizedDateAssignment>
                dateAssignments
        ) {
            this.executiveId =
                executiveId;

            this.teamName =
                teamName;

            this.dateAssignments =
                dateAssignments;
        }
    }


    private class NormalizedDateAssignment {

        private Date targetDate;
        private String activityLocation;

        private NormalizedDateAssignment(
            Date targetDate,
            String activityLocation
        ) {
            this.targetDate =
                targetDate;

            this.activityLocation =
                activityLocation;
        }
    }


    private class SchemaValidationResult {

        private Schema.SObjectType
            dateObjectType;

        private SchemaValidationResult(
            Schema.SObjectType
                dateObjectType
        ) {
            this.dateObjectType =
                dateObjectType;
        }
    }
}