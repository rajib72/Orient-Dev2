@IsTest
public class BTL_GoLive_TestDataFactory {

    public static final String ADMIN_LAST_NAME = 'BTL GO LIVE ADMIN';
    public static final String DEFAULT_TEAM = 'Team Alpha';
    public static final String DEFAULT_LOCATION = 'Location A';
    private static Integer sequenceNumber = 0;

    public class Scenario {
        public Store__c store;
        public Sales_Executives__c originalExecutive;
        public Sales_Executives__c replacementExecutive;
        public Sales_Executives__c additionalExecutive;
        public Final_Customize_Form__c finalForm;
        public Form_Activity__c activity;
        public Form_Activity_Assigned_Persons__c assignedPerson;
        public Form_Activity_Assigned_Persons_Date__c dateRecord;
        public Approval_Hierarchy__c hierarchy;
        public List<Approval_Hierarchy_Level__c> levels =
            new List<Approval_Hierarchy_Level__c>();
        public List<Approval_Approver_Mapping__c> mappings =
            new List<Approval_Approver_Mapping__c>();
    }

    public static User createAdministrator() {
        Profile adminProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

        String uniqueValue = uniqueToken().replace('-', '');

        User userRecord = new User(
            Alias = fitLength('btladmin', 8),
            Email = 'btl.golive.' + uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = ADMIN_LAST_NAME,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'btl.golive.' + uniqueValue + '@example.test'
        );

        insert userRecord;
        return userRecord;
    }

    public static User getAdministrator() {
        return [
            SELECT Id, Name, Email, Profile.Name, Store__c
            FROM User
            WHERE LastName = :ADMIN_LAST_NAME
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    public static Scenario createBasicScenario(Date targetDate) {
        Scenario scenario = new Scenario();

        Date effectiveTargetDate =
            targetDate == null ? Date.today() : targetDate;

        scenario.store = createStore('BTL Test Store ' + uniqueToken());
        scenario.originalExecutive = createExecutive(
            scenario.store.Id,
            'Original Executive ' + uniqueToken()
        );
        scenario.replacementExecutive = createExecutive(
            scenario.store.Id,
            'Replacement Executive ' + uniqueToken()
        );
        scenario.additionalExecutive = createExecutive(
            scenario.store.Id,
            'Additional Executive ' + uniqueToken()
        );
        scenario.finalForm = createFinalForm(scenario.store.Id);
        scenario.activity = createActivity(
            scenario.store.Id,
            scenario.finalForm.Id,
            'BTL Test Activity ' + uniqueToken(),
            Date.today().addDays(-2),
            Date.today().addDays(10),
            DEFAULT_LOCATION
        );
        scenario.assignedPerson = createAssignedPerson(
            scenario.activity.Id,
            scenario.store.Id,
            scenario.originalExecutive.Id,
            DEFAULT_TEAM,
            effectiveTargetDate,
            DEFAULT_LOCATION
        );
        scenario.dateRecord = createDateAssignment(
            scenario.assignedPerson.Id,
            scenario.store.Id,
            scenario.originalExecutive.Id,
            effectiveTargetDate,
            DEFAULT_LOCATION
        );

        return scenario;
    }

    public static Scenario createApprovalScenario(
        Integer levelCount,
        Date targetDate
    ) {
        Scenario scenario = createBasicScenario(targetDate);

        scenario.hierarchy = createApprovalHierarchy(
            scenario.store.Id
        );

        Integer effectiveLevelCount =
            levelCount == null || levelCount <= 0 ? 1 : levelCount;

        for (Integer indexValue = 1; indexValue <= effectiveLevelCount; indexValue++) {
            Approval_Hierarchy_Level__c levelRecord =
                createApprovalLevel(
                    scenario.hierarchy.Id,
                    indexValue
                );

            scenario.levels.add(levelRecord);

            scenario.mappings.add(
                createApproverMapping(
                    scenario.hierarchy.Id,
                    levelRecord.Id,
                    UserInfo.getUserId()
                )
            );
        }

        return scenario;
    }

    public static Store__c createStore(String storeName) {
        Store__c storeRecord = new Store__c();
        setField(storeRecord, 'Name', storeName);

        insertRecord(
            storeRecord,
            new Map<String, Id>{
                'User' => UserInfo.getUserId()
            }
        );

        return storeRecord;
    }

    public static Sales_Executives__c createExecutive(
        Id storeId,
        String executiveName
    ) {
        Sales_Executives__c executiveRecord =
            new Sales_Executives__c();

        setField(executiveRecord, 'Name', executiveName);
        setField(executiveRecord, 'Store__c', storeId);
        setField(executiveRecord, 'Active__c', true);
        setField(executiveRecord, 'Is_Active__c', true);
        setField(executiveRecord, 'Status__c', 'Active');
        setField(executiveRecord, 'Executive_Status__c', 'Active');
        setField(executiveRecord, 'Team_Name__c', DEFAULT_TEAM);

        insertRecord(
            executiveRecord,
            new Map<String, Id>{
                'Store__c' => storeId,
                'User' => UserInfo.getUserId()
            }
        );

        return executiveRecord;
    }

    public static Final_Customize_Form__c createFinalForm(Id storeId) {
        Final_Customize_Form__c formRecord =
            new Final_Customize_Form__c();

        setField(
            formRecord,
            'Name',
            'BTL Form ' + uniqueToken()
        );
        setField(formRecord, 'Store__c', storeId);

        insertRecord(
            formRecord,
            new Map<String, Id>{
                'Store__c' => storeId,
                'User' => UserInfo.getUserId()
            }
        );

        return formRecord;
    }

    public static Form_Activity__c createActivity(
        Id storeId,
        Id finalFormId,
        String activityName,
        Date startDate,
        Date endDate,
        String activityLocation
    ) {
        Form_Activity__c activityRecord = new Form_Activity__c();

        setField(
            activityRecord,
            'Name',
            'FA-' + uniqueToken()
        );
        setField(
            activityRecord,
            'Activity_Name__c',
            activityName
        );
        setField(
            activityRecord,
            'Activity_Date__c',
            startDate
        );
        setField(
            activityRecord,
            'Activity_End_Date__c',
            endDate
        );
        setField(
            activityRecord,
            'Activity_Location__c',
            activityLocation
        );
        setField(
            activityRecord,
            'Assigned_Store__c',
            storeId
        );
        setField(
            activityRecord,
            'Final_Customize_Form__c',
            finalFormId
        );

        insertRecord(
            activityRecord,
            new Map<String, Id>{
                'Store__c' => storeId,
                'Final_Customize_Form__c' => finalFormId,
                'User' => UserInfo.getUserId()
            }
        );

        return activityRecord;
    }

    public static Form_Activity_Assigned_Persons__c createAssignedPerson(
        Id activityId,
        Id storeId,
        Id executiveId,
        String teamName,
        Date assignedDate,
        String activityLocation
    ) {
        Form_Activity_Assigned_Persons__c parentRecord =
            new Form_Activity_Assigned_Persons__c();

        setField(parentRecord, 'Name', 'AP-' + uniqueToken());
        setField(parentRecord, 'Form_Activity__c', activityId);
        setField(parentRecord, 'Store__c', storeId);
        setField(parentRecord, 'Sales_Executives__c', executiveId);
        setField(parentRecord, 'Person_Name__c', 'Person ' + uniqueToken());
        setField(parentRecord, 'Team_Name__c', teamName);
        setField(parentRecord, 'Assigned_Date__c', assignedDate);
        setField(parentRecord, 'Activity_Location__c', activityLocation);
        setField(parentRecord, 'Is_Active__c', true);

        insertRecord(
            parentRecord,
            new Map<String, Id>{
                'Form_Activity__c' => activityId,
                'Store__c' => storeId,
                'Sales_Executives__c' => executiveId,
                'User' => UserInfo.getUserId()
            }
        );

        return parentRecord;
    }

    public static Form_Activity_Assigned_Persons_Date__c createDateAssignment(
        Id parentId,
        Id storeId,
        Id actualExecutiveId,
        Date targetDate,
        String activityLocation
    ) {
        Form_Activity_Assigned_Persons_Date__c dateRecord =
            new Form_Activity_Assigned_Persons_Date__c();

        setField(dateRecord, 'Name', 'APD-' + uniqueToken());
        setField(
            dateRecord,
            'Form_Activity_Assigned_Persons__c',
            parentId
        );
        setField(dateRecord, 'Store__c', storeId);
        setField(dateRecord, 'Target_Date__c', targetDate);
        setField(dateRecord, 'Activity_Location__c', activityLocation);
        setField(dateRecord, 'Actual_Executive__c', actualExecutiveId);
        setField(dateRecord, 'Active_For_Date__c', true);
        setField(dateRecord, 'Is_Active__c', true);
        setField(
            dateRecord,
            'Assignment_Status__c',
            Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_ACTIVE
        );
        setField(
            dateRecord,
            'Approval_Status__c',
            Ctrl_Hlp_BTLApprovalConstants.STATUS_NOT_SUBMITTED
        );
        setField(dateRecord, 'Approval_Locked__c', false);
        setField(dateRecord, 'Present__c', false);

        Map<String, Id> referenceDefaults = new Map<String, Id>{
            'Form_Activity_Assigned_Persons__c' => parentId,
            'Store__c' => storeId,
            'User' => UserInfo.getUserId()
        };

        if (actualExecutiveId != null) {
            referenceDefaults.put(
                'Sales_Executives__c',
                actualExecutiveId
            );
        }

        insertRecord(dateRecord, referenceDefaults);
        return dateRecord;
    }

    public static Approval_Hierarchy__c createApprovalHierarchy(
        Id storeId
    ) {
        Approval_Hierarchy__c hierarchyRecord =
            new Approval_Hierarchy__c();

        setField(
            hierarchyRecord,
            'Name',
            'BTL Approval ' + uniqueToken()
        );
        setField(hierarchyRecord, 'Store__c', storeId);

        // Critical exact value used by Ctrl_BTLApprovalSubmission queries.
        hierarchyRecord.Type__c =
            Ctrl_Hlp_BTLApprovalConstants.APPROVAL_TYPE;

        insertRecord(
            hierarchyRecord,
            new Map<String, Id>{
                'Store__c' => storeId,
                'User' => UserInfo.getUserId()
            }
        );

        return hierarchyRecord;
    }

    public static Approval_Hierarchy_Level__c createApprovalLevel(
        Id hierarchyId,
        Integer sequenceValue
    ) {
        Approval_Hierarchy_Level__c levelRecord =
            new Approval_Hierarchy_Level__c();

        setField(
            levelRecord,
            'Name',
            'Level ' + String.valueOf(sequenceValue) + ' ' + uniqueToken()
        );
        levelRecord.Approval_Hierarchy__c = hierarchyId;
        levelRecord.Sr_No__c = sequenceValue;

        // System Administrator approver is accepted regardless of the
        // configured Responsible Team. Use this label where it is a valid
        // value; otherwise setField safely selects the first active value.
        setField(
            levelRecord,
            'Responsible_Team__c',
            Ctrl_Hlp_BTLApprovalConstants.PROFILE_SYSTEM_ADMIN
        );

        insertRecord(
            levelRecord,
            new Map<String, Id>{
                'Approval_Hierarchy__c' => hierarchyId,
                'User' => UserInfo.getUserId()
            }
        );

        return levelRecord;
    }

    public static Approval_Approver_Mapping__c createApproverMapping(
        Id hierarchyId,
        Id levelId,
        Id approverUserId
    ) {
        Approval_Approver_Mapping__c mappingRecord =
            new Approval_Approver_Mapping__c();

        setField(
            mappingRecord,
            'Name',
            'BTL Mapping ' + uniqueToken()
        );
        mappingRecord.Approval_Hierarchy_Level__c = levelId;
        mappingRecord.Approver_User__c = approverUserId;
        mappingRecord.Active__c = true;
        mappingRecord.Is_Primary__c = true;
        mappingRecord.Effective_From__c = Date.today().addDays(-1);
        mappingRecord.Effective_To__c = Date.today().addDays(30);

        insertRecord(
            mappingRecord,
            new Map<String, Id>{
                'Approval_Hierarchy__c' => hierarchyId,
                'Approval_Hierarchy_Level__c' => levelId,
                'User' => approverUserId
            }
        );

        return mappingRecord;
    }

    public static Tagged_Approval_Hierarchy__c createApprovalTransaction(
        Scenario scenario,
        String approvalStatus,
        Integer levelIndex,
        Decimal submissionCycle
    ) {
        if (
            scenario == null ||
            scenario.hierarchy == null ||
            scenario.dateRecord == null ||
            scenario.assignedPerson == null ||
            scenario.activity == null
        ) {
            throw new TestDataFactoryException(
                'An approval scenario is required before creating a transaction.'
            );
        }

        Integer effectiveLevelIndex =
            levelIndex == null || levelIndex < 0 ? 0 : levelIndex;

        Approval_Hierarchy_Level__c selectedLevel;
        if (!scenario.levels.isEmpty()) {
            if (effectiveLevelIndex >= scenario.levels.size()) {
                effectiveLevelIndex = scenario.levels.size() - 1;
            }
            selectedLevel = scenario.levels[effectiveLevelIndex];
        }

        String effectiveStatus = String.isBlank(approvalStatus)
            ? Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING
            : approvalStatus;

        Decimal effectiveCycle =
            submissionCycle == null || submissionCycle <= 0
                ? 1
                : submissionCycle;

        Id currentUserId = UserInfo.getUserId();
        Datetime actionDateTime = System.now().addMinutes(-5);

        Tagged_Approval_Hierarchy__c transactionRecord =
            new Tagged_Approval_Hierarchy__c();

        transactionRecord.Approval_Hierarchy__c = scenario.hierarchy.Id;
        transactionRecord.Form_Activity__c = scenario.activity.Id;
        transactionRecord.Form_Activity_Assigned_Persons__c =
            scenario.assignedPerson.Id;
        transactionRecord.Form_Activity_Assigned_Persons_Date__c =
            scenario.dateRecord.Id;
        transactionRecord.Approval_Status__c = effectiveStatus;
        transactionRecord.Submission_Cycle__c = effectiveCycle;
        transactionRecord.Submitted_By__c = currentUserId;
        transactionRecord.Submitted_Date_Time__c = actionDateTime;
        transactionRecord.Last_Action_By__c = currentUserId;
        transactionRecord.Last_Action_Date_Time__c = actionDateTime;
        transactionRecord.Last_Action_Comments__c = 'BTL test fixture';

        if (
            effectiveStatus ==
                Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING
        ) {
            if (selectedLevel == null) {
                throw new TestDataFactoryException(
                    'A Pending approval transaction requires an approval level.'
                );
            }

            transactionRecord.Current_Approval_Level__c = selectedLevel.Id;
            transactionRecord.Pending_With__c = currentUserId;
            transactionRecord.Returned_From_Level__c = null;
            transactionRecord.Last_Action__c =
                Ctrl_Hlp_BTLApprovalConstants.ACTION_SUBMITTED;
        } else if (
            effectiveStatus ==
                Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED
        ) {
            if (selectedLevel == null) {
                throw new TestDataFactoryException(
                    'A Returned approval transaction requires an approval level.'
                );
            }

            transactionRecord.Current_Approval_Level__c = null;
            transactionRecord.Pending_With__c = currentUserId;
            transactionRecord.Returned_From_Level__c = selectedLevel.Id;
            transactionRecord.Last_Action__c =
                Ctrl_Hlp_BTLApprovalConstants.ACTION_REJECTED;
        } else if (
            effectiveStatus ==
                Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED
        ) {
            transactionRecord.Current_Approval_Level__c = null;
            transactionRecord.Pending_With__c = null;
            transactionRecord.Returned_From_Level__c = null;
            transactionRecord.Last_Action__c =
                Ctrl_Hlp_BTLApprovalConstants.ACTION_FINAL_APPROVED;
            transactionRecord.Final_Approved_By__c = currentUserId;
            transactionRecord.Final_Approved_Date_Time__c = actionDateTime;
        } else if (
            effectiveStatus ==
                Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED
        ) {
            transactionRecord.Current_Approval_Level__c = null;
            transactionRecord.Pending_With__c = null;
            transactionRecord.Returned_From_Level__c =
                selectedLevel == null ? null : selectedLevel.Id;
            transactionRecord.Last_Action__c =
                Ctrl_Hlp_BTLApprovalConstants.ACTION_DROPPED;
            transactionRecord.Dropped_By__c = currentUserId;
            transactionRecord.Dropped_Date_Time__c = actionDateTime;
            transactionRecord.Drop_Reason__c = 'BTL test fixture drop';
        }

        insertRecord(
            transactionRecord,
            new Map<String, Id>{
                'Approval_Hierarchy__c' => scenario.hierarchy.Id,
                'Form_Activity__c' => scenario.activity.Id,
                'Form_Activity_Assigned_Persons__c' =>
                    scenario.assignedPerson.Id,
                'Form_Activity_Assigned_Persons_Date__c' =>
                    scenario.dateRecord.Id,
                'User' => currentUserId
            }
        );

        Boolean isPending =
            effectiveStatus == Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING;
        Boolean isApproved =
            effectiveStatus == Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED;
        Boolean isDropped =
            effectiveStatus == Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED;

        Form_Activity_Assigned_Persons_Date__c dateUpdate =
            new Form_Activity_Assigned_Persons_Date__c(
                Id = scenario.dateRecord.Id,
                Approval_Status__c = effectiveStatus,
                Approval_Locked__c = isPending || isApproved || isDropped,
                Is_Active__c = !isDropped,
                Assignment_Status__c = isDropped
                    ? Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_DROPPED
                    : Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_ACTIVE
            );
        update dateUpdate;

        scenario.dateRecord.Approval_Status__c = effectiveStatus;
        scenario.dateRecord.Approval_Locked__c =
            isPending || isApproved || isDropped;
        scenario.dateRecord.Is_Active__c = !isDropped;
        scenario.dateRecord.Assignment_Status__c = isDropped
            ? Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_DROPPED
            : Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_ACTIVE;

        return transactionRecord;
    }

    public static Tagged_Approval_Hierarchy__c createPendingTransaction(
        Scenario scenario
    ) {
        return createApprovalTransaction(
            scenario,
            Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING,
            0,
            1
        );
    }

    public static Tagged_Approval_Hierarchy__c createReturnedTransaction(
        Scenario scenario
    ) {
        return createApprovalTransaction(
            scenario,
            Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED,
            0,
            1
        );
    }

    public static Tagged_Approval_Hierarchy__c createApprovedTransaction(
        Scenario scenario
    ) {
        return createApprovalTransaction(
            scenario,
            Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED,
            0,
            1
        );
    }

    private class TestDataFactoryException extends Exception {
    }

    public static Tagged_Approval_Hierarchy__c getTransactionByDate(
        Id dateRecordId
    ) {
        return [
            SELECT
                Id,
                Name,
                Approval_Hierarchy__c,
                Approval_Status__c,
                Current_Approval_Level__c,
                Pending_With__c,
                Returned_From_Level__c,
                Submission_Cycle__c,
                Submitted_By__c,
                Last_Action__c,
                Form_Activity__c,
                Form_Activity_Assigned_Persons__c,
                Form_Activity_Assigned_Persons_Date__c
            FROM Tagged_Approval_Hierarchy__c
            WHERE Form_Activity_Assigned_Persons_Date__c = :dateRecordId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    public static String teamKey(String teamNameValue) {
        if (String.isBlank(teamNameValue)) {
            return 'NO_TEAM';
        }

        return EncodingUtil.convertToHex(
            Crypto.generateDigest(
                'SHA-256',
                Blob.valueOf(
                    teamNameValue.trim().toLowerCase()
                )
            )
        );
    }

    public static String locationKey(String locationValue) {
        String normalized = String.isBlank(locationValue)
            ? ''
            : locationValue.trim().toLowerCase();

        if (String.isBlank(normalized)) {
            return 'NO_LOCATION';
        }

        return EncodingUtil.convertToHex(
            Crypto.generateDigest(
                'SHA-256',
                Blob.valueOf(normalized)
            )
        );
    }

    public static void insertRecord(
        SObject recordValue,
        Map<String, Id> referenceDefaults
    ) {
        populateRequiredFields(
            recordValue,
            referenceDefaults
        );
        insert recordValue;
    }

    public static void populateRequiredFields(
        SObject recordValue,
        Map<String, Id> referenceDefaults
    ) {
        Map<String, Schema.SObjectField> fieldMap =
            recordValue
                .getSObjectType()
                .getDescribe()
                .fields
                .getMap();

        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult description =
                fieldMap.get(fieldName).getDescribe();

            if (
                !description.isCreateable() ||
                description.isCalculated() ||
                description.isAutoNumber() ||
                description.isNillable() ||
                description.isDefaultedOnCreate() ||
                recordValue.get(fieldName) != null
            ) {
                continue;
            }

            String typeName =
                String.valueOf(description.getType()).toUpperCase();

            if (typeName == 'REFERENCE') {
                Id referenceId = resolveReference(
                    description,
                    referenceDefaults
                );

                if (referenceId != null) {
                    recordValue.put(fieldName, referenceId);
                }
            } else if (typeName == 'BOOLEAN') {
                recordValue.put(fieldName, false);
            } else if (typeName == 'DATE') {
                recordValue.put(fieldName, Date.today());
            } else if (typeName == 'DATETIME') {
                recordValue.put(fieldName, System.now());
            } else if (typeName == 'TIME') {
                recordValue.put(
                    fieldName,
                    Time.newInstance(9, 0, 0, 0)
                );
            } else if (
                typeName == 'INTEGER' ||
                typeName == 'DOUBLE' ||
                typeName == 'CURRENCY' ||
                typeName == 'PERCENT' ||
                typeName == 'LONG'
            ) {
                recordValue.put(fieldName, 1);
            } else if (
                typeName == 'PICKLIST' ||
                typeName == 'MULTIPICKLIST' ||
                typeName == 'COMBOBOX'
            ) {
                String picklistValue =
                    firstActiveValue(description);

                if (picklistValue != null) {
                    recordValue.put(
                        fieldName,
                        picklistValue
                    );
                }
            } else if (typeName == 'EMAIL') {
                recordValue.put(
                    fieldName,
                    fitLength(
                        'test.' + uniqueToken() + '@example.com',
                        description.getLength()
                    )
                );
            } else if (typeName == 'PHONE') {
                recordValue.put(fieldName, '9999999999');
            } else if (typeName == 'URL') {
                recordValue.put(
                    fieldName,
                    'https://example.com'
                );
            } else if (typeName == 'BASE64') {
                recordValue.put(
                    fieldName,
                    Blob.valueOf('Test')
                );
            } else if (
                typeName == 'STRING' ||
                typeName == 'TEXTAREA' ||
                typeName == 'ENCRYPTEDSTRING'
            ) {
                recordValue.put(
                    fieldName,
                    fitLength(
                        'Test ' + fieldName + ' ' + uniqueToken(),
                        description.getLength()
                    )
                );
            }
        }
    }

    public static void setField(
        SObject recordValue,
        String fieldName,
        Object value
    ) {
        if (value == null) {
            return;
        }

        Map<String, Schema.SObjectField> fieldMap =
            recordValue
                .getSObjectType()
                .getDescribe()
                .fields
                .getMap();

        if (!fieldMap.containsKey(fieldName)) {
            return;
        }

        Schema.DescribeFieldResult description =
            fieldMap.get(fieldName).getDescribe();

        if (
            !description.isCreateable() ||
            description.isCalculated() ||
            description.isAutoNumber()
        ) {
            return;
        }

        String typeName =
            String.valueOf(description.getType()).toUpperCase();

        if (
            typeName == 'PICKLIST' ||
            typeName == 'MULTIPICKLIST' ||
            typeName == 'COMBOBOX'
        ) {
            String requestedValue = String.valueOf(value);

            for (
                Schema.PicklistEntry entry :
                description.getPicklistValues()
            ) {
                if (
                    entry.isActive() &&
                    entry.getValue() == requestedValue
                ) {
                    recordValue.put(
                        fieldName,
                        requestedValue
                    );
                    return;
                }
            }

            String fallbackValue =
                firstActiveValue(description);

            if (fallbackValue != null) {
                recordValue.put(
                    fieldName,
                    fallbackValue
                );
            }
            return;
        }

        recordValue.put(fieldName, value);
    }

    private static Id resolveReference(
        Schema.DescribeFieldResult description,
        Map<String, Id> referenceDefaults
    ) {
        for (
            Schema.SObjectType referencedType :
            description.getReferenceTo()
        ) {
            String apiName =
                referencedType.getDescribe().getName();

            if (
                referenceDefaults != null &&
                referenceDefaults.containsKey(apiName)
            ) {
                return referenceDefaults.get(apiName);
            }

            if (apiName == 'User') {
                return UserInfo.getUserId();
            }
        }

        return null;
    }

    private static String firstActiveValue(
        Schema.DescribeFieldResult description
    ) {
        for (
            Schema.PicklistEntry entry :
            description.getPicklistValues()
        ) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static String fitLength(
        String value,
        Integer maximumLength
    ) {
        if (
            value == null ||
            maximumLength == null ||
            maximumLength <= 0 ||
            value.length() <= maximumLength
        ) {
            return value;
        }

        return value.substring(0, maximumLength);
    }

    private static String uniqueToken() {
        sequenceNumber++;

        return String.valueOf(DateTime.now().getTime()) +
            '-' +
            String.valueOf(sequenceNumber) +
            '-' +
            String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    }
}