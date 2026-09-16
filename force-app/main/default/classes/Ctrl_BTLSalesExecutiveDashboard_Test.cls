@IsTest
private class Ctrl_BTLSalesExecutiveDashboard_Test {

    private static final String STORE_ONE_NAME = 'BTL Test Store One';
    private static final String STORE_TWO_NAME = 'BTL Test Store Two';
    private static final String TODAY_EXECUTION_KEY = 'BTL-TEST-TODAY';
    private static final String PAST_EXECUTION_KEY = 'BTL-TEST-PAST';

    @TestSetup
    static void setupData() {
        BTL_Activities__c btlActivity = new BTL_Activities__c();
        insertRecord(btlActivity);

        Store__c storeOne = new Store__c();
        setValue(storeOne, 'Name', STORE_ONE_NAME);
        setValue(storeOne, 'BTL_Activities__c', btlActivity.Id);
        insertRecord(storeOne);

        Store__c storeTwo = new Store__c();
        setValue(storeTwo, 'Name', STORE_TWO_NAME);
        setValue(storeTwo, 'BTL_Activities__c', btlActivity.Id);
        insertRecord(storeTwo);

        Final_Customize_Form__c form = new Final_Customize_Form__c();
        setValue(form, 'Form_Name__c', 'BTL Dashboard Test Form');
        setValue(form, 'Active__c', true);
        setValue(form, 'BTL_Activities__c', btlActivity.Id);
        insertRecord(form);

        Form_Activity__c todayActivity = new Form_Activity__c();
        setValue(todayActivity, 'Activity_Name__c', 'Today BTL Activity');
        setValue(todayActivity, 'Activity_Date__c', Date.today());
        setValue(todayActivity, 'Activity_End_Date__c', Date.today());
        setValue(todayActivity, 'Activity_Location__c', 'Today Test Location');
        setValue(todayActivity, 'Assigned_Store__c', storeOne.Id);
        setValue(todayActivity, 'Final_Customize_Form__c', form.Id);
        setValue(todayActivity, 'BTL_Activities__c', btlActivity.Id);
        insertRecord(todayActivity);

        Form_Activity__c pastActivity = new Form_Activity__c();
        setValue(pastActivity, 'Activity_Name__c', 'Past BTL Activity');
        setValue(pastActivity, 'Activity_Date__c', Date.today().addDays(-5));
        setValue(pastActivity, 'Activity_End_Date__c', Date.today().addDays(-5));
        setValue(pastActivity, 'Activity_Location__c', 'Past Test Location');
        setValue(pastActivity, 'Assigned_Store__c', storeOne.Id);
        setValue(pastActivity, 'Final_Customize_Form__c', form.Id);
        setValue(pastActivity, 'BTL_Activities__c', btlActivity.Id);
        insertRecord(pastActivity);

        Sales_Executives__c executiveOne = new Sales_Executives__c();
        setValue(executiveOne, 'Name', 'BTL Executive One');
        setValue(executiveOne, 'Store__c', storeOne.Id);
        setValue(executiveOne, 'BTL_Activities__c', btlActivity.Id);
        insertRecord(executiveOne);

        Sales_Executives__c executiveTwo = new Sales_Executives__c();
        setValue(executiveTwo, 'Name', 'BTL Executive Two');
        setValue(executiveTwo, 'Store__c', storeOne.Id);
        setValue(executiveTwo, 'BTL_Activities__c', btlActivity.Id);
        insertRecord(executiveTwo);

        Form_Activity_Daily_Execution__c todayExecution =
            new Form_Activity_Daily_Execution__c();

        setValue(todayExecution, 'Form_Activity__c', todayActivity.Id);
        setValue(todayExecution, 'Activity_Date__c', Date.today());
        setValue(todayExecution, 'Store__c', storeOne.Id);
        setValue(todayExecution, 'Status__c', 'Live');
        setValue(todayExecution, 'Execution_Key__c', TODAY_EXECUTION_KEY);
        setValue(todayExecution, 'Store_Manager_Approved__c', true);
        setValue(todayExecution, 'BTL_Activity_Live__c', true);
        setValue(todayExecution, 'BTL_Initiated_Date_Time__c', System.now());
        setValue(todayExecution, 'BTL_Initiated_By__c', UserInfo.getUserId());
        setValue(todayExecution, 'BTL_Activities__c', btlActivity.Id);
        insertRecord(todayExecution);

        Form_Activity_Daily_Execution__c pastExecution =
            new Form_Activity_Daily_Execution__c();

        setValue(pastExecution, 'Form_Activity__c', pastActivity.Id);
        setValue(pastExecution, 'Activity_Date__c', Date.today().addDays(-5));
        setValue(pastExecution, 'Store__c', storeOne.Id);
        setValue(pastExecution, 'Status__c', 'In Progress');
        setValue(pastExecution, 'Execution_Key__c', PAST_EXECUTION_KEY);
        setValue(pastExecution, 'Store_Manager_Approved__c', true);
        setValue(pastExecution, 'BTL_Activity_Live__c', true);
        setValue(
            pastExecution,
            'BTL_Initiated_Date_Time__c',
            System.now().addDays(-5)
        );
        setValue(pastExecution, 'BTL_Initiated_By__c', UserInfo.getUserId());
        setValue(pastExecution, 'BTL_Activities__c', btlActivity.Id);
        insertRecord(pastExecution);

        Form_Activity_Assigned_Persons__c todayPersonOne =
            createAssignedPerson(
                todayActivity.Id,
                storeOne.Id,
                executiveOne.Id,
                btlActivity.Id,
                'Team A'
            );

        Form_Activity_Assigned_Persons__c todayPersonTwo =
            createAssignedPerson(
                todayActivity.Id,
                storeOne.Id,
                executiveTwo.Id,
                btlActivity.Id,
                'Team A'
            );

        Form_Activity_Assigned_Persons__c pastPerson =
            createAssignedPerson(
                pastActivity.Id,
                storeOne.Id,
                executiveOne.Id,
                btlActivity.Id,
                'Team A'
            );

        createDateAssignment(
            todayPersonOne.Id,
            todayExecution.Id,
            storeOne.Id,
            executiveOne.Id,
            btlActivity.Id,
            Date.today(),
            'Today Test Location',
            false
        );

        createDateAssignment(
            todayPersonTwo.Id,
            todayExecution.Id,
            storeOne.Id,
            executiveTwo.Id,
            btlActivity.Id,
            Date.today(),
            'Today Test Location',
            false
        );

        createDateAssignment(
            pastPerson.Id,
            pastExecution.Id,
            storeOne.Id,
            executiveOne.Id,
            btlActivity.Id,
            Date.today().addDays(-5),
            'Past Test Location',
            true
        );

        Account customer = new Account();
        setValue(customer, 'Name', 'BTL Test Customer');
        setValue(customer, 'Phone', '9876543210');
        setValue(customer, 'Status__c', 'Prospect');
        insertRecord(customer);

        createResponse(
            todayActivity.Id,
            todayExecution.Id,
            customer.Id,
            btlActivity.Id,
            '9876543210',
            Date.today(),
            'BTL Executive One'
        );

        createResponse(
            pastActivity.Id,
            pastExecution.Id,
            customer.Id,
            btlActivity.Id,
            '9876543211',
            Date.today().addDays(-5),
            'BTL Executive One'
        );
    }

    @IsTest
    static void testDashboardContextAndDashboardData() {
        User adminUser = createAdminUser('dash');

        System.runAs(adminUser) {
            Store__c storeOne = [
                SELECT Id
                FROM Store__c
                WHERE Name = :STORE_ONE_NAME
                LIMIT 1
            ];

            Test.startTest();

            Ctrl_BTLSalesExecutiveDashboard.DashboardContextWrapper context =
                Ctrl_BTLSalesExecutiveDashboard.getDashboardContext();

            Ctrl_BTLSalesExecutiveDashboard.DashboardWrapper todayDashboard =
                Ctrl_BTLSalesExecutiveDashboard.getDashboardData(
                    'TODAY',
                    storeOne.Id
                );

            Ctrl_BTLSalesExecutiveDashboard.DashboardWrapper invalidTabDashboard =
                Ctrl_BTLSalesExecutiveDashboard.getDashboardData(
                    'INVALID',
                    storeOne.Id
                );

            Ctrl_BTLSalesExecutiveDashboard.DashboardWrapper pastDashboard =
                Ctrl_BTLSalesExecutiveDashboard.getDashboardData(
                    'PAST',
                    storeOne.Id
                );

            Test.stopTest();

            System.assertEquals(true, context.isSystemAdministrator);
            System.assert(context.storeOptions.size() >= 3);
            System.assertEquals('All Stores', context.storeOptions[0].label);
            System.assertEquals('', context.storeOptions[0].value);

            System.assertEquals(Date.today(), todayDashboard.serverDate);
            System.assertEquals('TODAY', todayDashboard.tabName);
            System.assertEquals(1, todayDashboard.activities.size());

            Ctrl_BTLSalesExecutiveDashboard.ActivityWrapper todayRow =
                todayDashboard.activities[0];

            System.assertEquals('Today BTL Activity', todayRow.activityName);
            System.assertEquals('Today Test Location', todayRow.activityLocation);
            System.assertEquals('Live', todayRow.status);
            System.assertEquals(2, todayRow.memberCount);
            System.assertEquals(1, todayRow.responseCount);
            System.assertEquals(true, todayRow.canStart);
            System.assertEquals(false, todayRow.canContinue);
            System.assertEquals(false, todayRow.canComplete);
            System.assertEquals(false, todayRow.canViewResponses);

            System.assertEquals('TODAY', invalidTabDashboard.tabName);
            System.assertEquals(1, invalidTabDashboard.activities.size());

            System.assertEquals('PAST', pastDashboard.tabName);
            System.assertEquals(1, pastDashboard.activities.size());

            Ctrl_BTLSalesExecutiveDashboard.ActivityWrapper pastRow =
                pastDashboard.activities[0];

            System.assertEquals('Past BTL Activity', pastRow.activityName);
            System.assertEquals('Past Test Location', pastRow.activityLocation);
            System.assertEquals('Expired', pastRow.status);
            System.assertEquals(1, pastRow.memberCount);
            System.assertEquals(1, pastRow.responseCount);
            System.assertEquals(true, pastRow.canViewResponses);
            System.assertEquals(false, pastRow.canStart);
        }
    }

    @IsTest
    static void testStartCompleteAndResponseMethods() {
        User adminUser = createAdminUser('flow');

        System.runAs(adminUser) {
            Form_Activity_Daily_Execution__c execution = [
                SELECT Id
                FROM Form_Activity_Daily_Execution__c
                WHERE Execution_Key__c = :TODAY_EXECUTION_KEY
                LIMIT 1
            ];

            List<Form_Activity_Assigned_Persons_Date__c> attendanceRows = [
                SELECT Id, Actual_Executive__r.Name
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Form_Activity_Daily_Execution__c = :execution.Id
                ORDER BY Actual_Executive__r.Name
            ];

            Test.startTest();

            Ctrl_BTLSalesExecutiveDashboard.startActivity(
                execution.Id,
                new List<Id>{ attendanceRows[0].Id }
            );

            String presentNames =
                Ctrl_BTLSalesExecutiveDashboard.getPresentExecutiveNames(
                    execution.Id
                );

            List<Ctrl_BTLSalesExecutiveDashboard.ResponseWrapper> responses =
                Ctrl_BTLSalesExecutiveDashboard.getActivityResponses(
                    execution.Id
                );

            Ctrl_BTLSalesExecutiveDashboard.completeActivity(execution.Id);

            Test.stopTest();

            Form_Activity_Daily_Execution__c updatedExecution = [
                SELECT Status__c,
                       Start_Date_Time__c,
                       Started_By__c,
                       Completed_Date_Time__c,
                       Completed_By__c
                FROM Form_Activity_Daily_Execution__c
                WHERE Id = :execution.Id
            ];

            System.assertEquals('Completed', updatedExecution.Status__c);
            System.assertNotEquals(null, updatedExecution.Start_Date_Time__c);
            System.assertEquals(adminUser.Id, updatedExecution.Started_By__c);
            System.assertNotEquals(null, updatedExecution.Completed_Date_Time__c);
            System.assertEquals(adminUser.Id, updatedExecution.Completed_By__c);

            List<Form_Activity_Assigned_Persons_Date__c> updatedAttendance = [
                SELECT Id,
                       Present__c,
                       Actual_Date__c,
                       Attendance_Date_Time__c,
                       Attendance_Marked_By__c
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Form_Activity_Daily_Execution__c = :execution.Id
            ];

            Integer presentCount = 0;
            Integer absentCount = 0;

            for (Form_Activity_Assigned_Persons_Date__c row : updatedAttendance) {
                if (row.Present__c) {
                    presentCount++;
                    System.assertEquals(Date.today(), row.Actual_Date__c);
                    System.assertNotEquals(null, row.Attendance_Date_Time__c);
                    System.assertEquals(
                        adminUser.Id,
                        row.Attendance_Marked_By__c
                    );
                } else {
                    absentCount++;
                    System.assertEquals(null, row.Actual_Date__c);
                    System.assertEquals(null, row.Attendance_Date_Time__c);
                    System.assertEquals(null, row.Attendance_Marked_By__c);
                }
            }

            System.assertEquals(1, presentCount);
            System.assertEquals(1, absentCount);
            System.assertEquals(
                attendanceRows[0].Actual_Executive__r.Name,
                presentNames
            );

            System.assertEquals(1, responses.size());
            System.assertEquals('9876543210', responses[0].phoneNo);
            System.assertEquals(
                'BTL Test Customer',
                responses[0].customerName
            );
        }
    }

    @IsTest
    static void testValidationBranches() {
        User adminUser = createAdminUser('valid');

        System.runAs(adminUser) {
            Form_Activity_Daily_Execution__c todayExecution = [
                SELECT Id
                FROM Form_Activity_Daily_Execution__c
                WHERE Execution_Key__c = :TODAY_EXECUTION_KEY
                LIMIT 1
            ];

            Form_Activity_Daily_Execution__c pastExecution = [
                SELECT Id
                FROM Form_Activity_Daily_Execution__c
                WHERE Execution_Key__c = :PAST_EXECUTION_KEY
                LIMIT 1
            ];

            Id todayAttendanceId = [
                SELECT Id
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Form_Activity_Daily_Execution__c = :todayExecution.Id
                LIMIT 1
            ].Id;

            Id pastAttendanceId = [
                SELECT Id
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Form_Activity_Daily_Execution__c = :pastExecution.Id
                LIMIT 1
            ].Id;

            Account customer = [
                SELECT Id
                FROM Account
                WHERE Phone = '9876543210'
                LIMIT 1
            ];

            Test.startTest();

            assertStartFails(
                null,
                new List<Id>{ todayAttendanceId }
            );

            assertStartFails(
                todayExecution.Id,
                new List<Id>()
            );

            assertStartFails(
                todayExecution.Id,
                new List<Id>{ customer.Id }
            );

            assertStartFails(
                pastExecution.Id,
                new List<Id>{ pastAttendanceId }
            );

            assertCompleteFails(null);
            assertCompleteFails(todayExecution.Id);

            System.assertEquals(
                0,
                Ctrl_BTLSalesExecutiveDashboard.getActivityResponses(null).size()
            );

            System.assertEquals(
                null,
                Ctrl_BTLSalesExecutiveDashboard.getPresentExecutiveNames(null)
            );

            Boolean invalidStoreThrown = false;

            try {
                Ctrl_BTLSalesExecutiveDashboard.getDashboardData(
                    'TODAY',
                    customer.Id
                );
            } catch (AuraHandledException expectedException) {
                invalidStoreThrown = true;
            }

            System.assertEquals(true, invalidStoreThrown);

            Test.stopTest();
        }
    }

    @IsTest
    static void testCompleteRequiresResponse() {
        User adminUser = createAdminUser('noresp');

        System.runAs(adminUser) {
            Store__c storeOne = [
                SELECT Id
                FROM Store__c
                WHERE Name = :STORE_ONE_NAME
                LIMIT 1
            ];

            Form_Activity__c activity = [
                SELECT Id
                FROM Form_Activity__c
                WHERE Activity_Location__c = 'Today Test Location'
                LIMIT 1
            ];

            BTL_Activities__c btlActivity = [
                SELECT Id
                FROM BTL_Activities__c
                LIMIT 1
            ];

            Form_Activity_Daily_Execution__c execution =
                new Form_Activity_Daily_Execution__c();

            setValue(execution, 'Form_Activity__c', activity.Id);
            setValue(execution, 'Activity_Date__c', Date.today());
            setValue(execution, 'Store__c', storeOne.Id);
            setValue(execution, 'Status__c', 'In Progress');
            setValue(
                execution,
                'Execution_Key__c',
                'BTL-TEST-NO-RESPONSE'
            );
            setValue(execution, 'Store_Manager_Approved__c', true);
            setValue(execution, 'BTL_Activity_Live__c', true);
            setValue(execution, 'BTL_Activities__c', btlActivity.Id);
            insertRecord(execution);

            Test.startTest();
            assertCompleteFails(execution.Id);
            Test.stopTest();

            Form_Activity_Daily_Execution__c unchangedExecution = [
                SELECT Status__c
                FROM Form_Activity_Daily_Execution__c
                WHERE Id = :execution.Id
            ];

            System.assertEquals(
                'In Progress',
                unchangedExecution.Status__c
            );
        }
    }

    private static Form_Activity_Assigned_Persons__c createAssignedPerson(
        Id activityId,
        Id storeId,
        Id executiveId,
        Id btlActivityId,
        String teamName
    ) {
        Form_Activity_Assigned_Persons__c person =
            new Form_Activity_Assigned_Persons__c();

        setValue(person, 'Form_Activity__c', activityId);
        setValue(person, 'Store__c', storeId);
        setValue(person, 'Sales_Executives__c', executiveId);
        setValue(person, 'Team_Name__c', teamName);
        setValue(person, 'BTL_Activities__c', btlActivityId);
        insertRecord(person);

        return person;
    }

    private static Form_Activity_Assigned_Persons_Date__c createDateAssignment(
        Id assignedPersonId,
        Id executionId,
        Id storeId,
        Id executiveId,
        Id btlActivityId,
        Date targetDate,
        String location,
        Boolean present
    ) {
        Form_Activity_Assigned_Persons_Date__c row =
            new Form_Activity_Assigned_Persons_Date__c();

        setValue(
            row,
            'Form_Activity_Assigned_Persons__c',
            assignedPersonId
        );
        setValue(
            row,
            'Form_Activity_Daily_Execution__c',
            executionId
        );
        setValue(row, 'Store__c', storeId);
        setValue(row, 'Actual_Executive__c', executiveId);
        setValue(row, 'Target_Date__c', targetDate);

        if (present) {
            setValue(row, 'Actual_Date__c', targetDate);
            setValue(row, 'Attendance_Date_Time__c', System.now());
            setValue(
                row,
                'Attendance_Marked_By__c',
                UserInfo.getUserId()
            );
        }

        setValue(row, 'Activity_Location__c', location);
        setValue(row, 'Active_For_Date__c', true);
        setValue(row, 'Present__c', present);
        setValue(row, 'BTL_Activities__c', btlActivityId);
        insertRecord(row);

        return row;
    }

    private static BTL_Customer_Response__c createResponse(
        Id activityId,
        Id executionId,
        Id customerId,
        Id btlActivityId,
        String phone,
        Date responseDate,
        String executiveNames
    ) {
        BTL_Customer_Response__c response =
            new BTL_Customer_Response__c();

        setValue(response, 'Form_Activity__c', activityId);
        setValue(
            response,
            'Form_Activity_Daily_Execution__c',
            executionId
        );
        setValue(response, 'Orient_Customer__c', customerId);
        setValue(response, 'Phone_No__c', phone);
        setValue(response, 'Actual_Date_Time__c', System.now());
        setValue(response, 'Response_Date__c', responseDate);
        setValue(response, 'Executive__c', executiveNames);
        setValue(response, 'Captured_By_Team__c', 'Team A');
        setValue(response, 'BTL_Activities__c', btlActivityId);
        insertRecord(response);

        return response;
    }

    private static User createAdminUser(String suffix) {
        Profile adminProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

        User runningUser = [
            SELECT TimeZoneSidKey,
                   LocaleSidKey,
                   EmailEncodingKey,
                   LanguageLocaleKey
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];

        String uniqueValue =
            String.valueOf(DateTime.now().getTime()) + suffix;

        User adminUser = new User(
            FirstName = 'BTL',
            LastName = 'Dashboard Test',
            Alias = 'btltst',
            Email = 'btl.dashboard.' + uniqueValue + '@example.com',
            Username = 'btl.dashboard.' + uniqueValue + '@example.com',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = runningUser.TimeZoneSidKey,
            LocaleSidKey = runningUser.LocaleSidKey,
            EmailEncodingKey = runningUser.EmailEncodingKey,
            LanguageLocaleKey = runningUser.LanguageLocaleKey
        );

        insert adminUser;
        return adminUser;
    }

    private static void assertStartFails(
        Id executionId,
        List<Id> attendanceIds
    ) {
        Boolean exceptionThrown = false;

        try {
            Ctrl_BTLSalesExecutiveDashboard.startActivity(
                executionId,
                attendanceIds
            );
        } catch (AuraHandledException expectedException) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown);
    }

    private static void assertCompleteFails(Id executionId) {
        Boolean exceptionThrown = false;

        try {
            Ctrl_BTLSalesExecutiveDashboard.completeActivity(
                executionId
            );
        } catch (AuraHandledException expectedException) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown);
    }

    private static void insertRecord(SObject recordData) {
        populateRequiredFields(recordData);
        insert recordData;
    }

    private static void setValue(
        SObject recordData,
        String fieldApiName,
        Object fieldValue
    ) {
        if (
            recordData == null ||
            String.isBlank(fieldApiName) ||
            fieldValue == null
        ) {
            return;
        }

        Map<String, Schema.SObjectField> fieldMap =
            recordData.getSObjectType()
                .getDescribe()
                .fields
                .getMap();

        if (!fieldMap.containsKey(fieldApiName)) {
            return;
        }

        Schema.DescribeFieldResult fieldDescribe =
            fieldMap.get(fieldApiName).getDescribe();

        if (
            !fieldDescribe.isCreateable() ||
            fieldDescribe.isCalculated()
        ) {
            return;
        }

        recordData.put(fieldApiName, fieldValue);
    }

    private static void populateRequiredFields(SObject recordData) {
        Map<String, Schema.SObjectField> fieldMap =
            recordData.getSObjectType()
                .getDescribe()
                .fields
                .getMap();

        for (String fieldApiName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe =
                fieldMap.get(fieldApiName).getDescribe();

            if (
                !fieldDescribe.isCreateable() ||
                fieldDescribe.isCalculated() ||
                fieldDescribe.isAutoNumber() ||
                fieldDescribe.isNillable() ||
                fieldDescribe.isDefaultedOnCreate() ||
                recordData.get(fieldApiName) != null
            ) {
                continue;
            }

            Object defaultValue = getDefaultValue(fieldDescribe);

            if (defaultValue != null) {
                recordData.put(fieldApiName, defaultValue);
            }
        }
    }

    private static Object getDefaultValue(
        Schema.DescribeFieldResult fieldDescribe
    ) {
        Schema.DisplayType fieldType = fieldDescribe.getType();

        if (
            fieldType == Schema.DisplayType.String ||
            fieldType == Schema.DisplayType.TextArea ||
            fieldType == Schema.DisplayType.EncryptedString
        ) {
            return trimValue(
                'Test Value',
                fieldDescribe.getLength()
            );
        }

        if (fieldType == Schema.DisplayType.Phone) {
            return trimValue(
                '9876543210',
                fieldDescribe.getLength()
            );
        }

        if (fieldType == Schema.DisplayType.Email) {
            return trimValue(
                'test@example.com',
                fieldDescribe.getLength()
            );
        }

        if (fieldType == Schema.DisplayType.Url) {
            return trimValue(
                'https://example.com',
                fieldDescribe.getLength()
            );
        }

        if (fieldType == Schema.DisplayType.Boolean) {
            return false;
        }

        if (fieldType == Schema.DisplayType.Date) {
            return Date.today();
        }

        if (fieldType == Schema.DisplayType.DateTime) {
            return System.now();
        }

        if (fieldType == Schema.DisplayType.Time) {
            return Time.newInstance(10, 0, 0, 0);
        }

        if (
            fieldType == Schema.DisplayType.Integer ||
            fieldType == Schema.DisplayType.Double ||
            fieldType == Schema.DisplayType.Currency ||
            fieldType == Schema.DisplayType.Percent
        ) {
            return 1;
        }

        if (
            fieldType == Schema.DisplayType.Picklist ||
            fieldType == Schema.DisplayType.MultiPicklist
        ) {
            for (
                Schema.PicklistEntry entry :
                fieldDescribe.getPicklistValues()
            ) {
                if (entry.isActive()) {
                    return entry.getValue();
                }
            }
        }

        if (fieldType == Schema.DisplayType.Reference) {
            for (
                Schema.SObjectType referenceType :
                fieldDescribe.getReferenceTo()
            ) {
                if (
                    referenceType.getDescribe().getName() == 'User'
                ) {
                    return UserInfo.getUserId();
                }
            }
        }

        return null;
    }

    private static String trimValue(
        String value,
        Integer maximumLength
    ) {
        if (
            maximumLength == null ||
            maximumLength <= 0 ||
            value.length() <= maximumLength
        ) {
            return value;
        }

        return value.substring(0, maximumLength);
    }
}