@IsTest
private class ctrl_ActivityDashboardController_Test {

    private static final String EXISTING_PHONE = '9876543210';
    private static final String NEW_PHONE = '9123456780';

    private class TestData {
        BTL_Activities__c btlActivity;
        Store__c storeOne;
        Store__c storeTwo;
        Final_Customize_Form__c form;
        Form_Activity__c activity;
        Form_Activity__c secondActivity;
        BTL_Questions__c phoneQuestion;
        BTL_Questions__c nameQuestion;
        Final_Customize_Form_Line_Item__c phoneLineItem;
        Final_Customize_Form_Line_Item__c nameLineItem;
        Sales_Executives__c executive;
        Form_Activity_Daily_Execution__c execution;
        Form_Activity_Assigned_Persons__c assignedPerson;
        Form_Activity_Assigned_Persons_Date__c dateAssignment;
    }

    @TestSetup
    static void setupData() {

        Store__c storeOne = new Store__c();
        setValue(
            storeOne,
            'Name',
            'Kolkata Central Store'
        );
        insertRecord(storeOne);

        Store__c storeTwo = new Store__c();
        setValue(
            storeTwo,
            'Name',
            'Delhi North Store'
        );
        insertRecord(storeTwo);

        /*
         * Required parent record for BTL_Questions__c.
         */
        BTL_Activities__c btlActivity =
            new BTL_Activities__c();

        setValue(
            btlActivity,
            'Name',
            'Test BTL Activity'
        );

        insertRecord(btlActivity);

        System.assertNotEquals(
            null,
            btlActivity.Id,
            'BTL Activity should be created.'
        );

        Final_Customize_Form__c form =
            new Final_Customize_Form__c();

        setValue(
            form,
            'Name',
            'BTL Customer Form'
        );

        setValue(
            form,
            'Form_Name__c',
            'Customer Engagement Survey'
        );

        setValue(
            form,
            'Active__c',
            true
        );

        setValue(
            form,
            'BTL_Activities__c',
            btlActivity.Id
        );

        insertRecord(form);

        Form_Activity__c activity =
            new Form_Activity__c();

        setValue(
            activity,
            'Name',
            'BTL-ACT-001'
        );

        setValue(
            activity,
            'Activity_Name__c',
            'Customer Engagement Activity'
        );

        setValue(
            activity,
            'Activity_Date__c',
            Date.today()
        );

        setValue(
            activity,
            'Activity_End_Date__c',
            Date.today().addDays(2)
        );

        setValue(
            activity,
            'Activity_Location__c',
            'Salt Lake Sector V'
        );

        setValue(
            activity,
            'Assigned_Store__c',
            storeOne.Id
        );

        setValue(
            activity,
            'Final_Customize_Form__c',
            form.Id
        );

        setValue(
            activity,
            'BTL_Activities__c',
            btlActivity.Id
        );

        insertRecord(activity);

        Form_Activity__c secondActivity =
            new Form_Activity__c();

        setValue(
            secondActivity,
            'Name',
            'BTL-ACT-002'
        );

        setValue(
            secondActivity,
            'Activity_Name__c',
            'Delhi Customer Activity'
        );

        setValue(
            secondActivity,
            'Activity_Date__c',
            Date.today().addDays(-5)
        );

        setValue(
            secondActivity,
            'Activity_End_Date__c',
            Date.today().addDays(-3)
        );

        setValue(
            secondActivity,
            'Activity_Location__c',
            'Connaught Place'
        );

        setValue(
            secondActivity,
            'Assigned_Store__c',
            storeTwo.Id
        );

        setValue(
            secondActivity,
            'Final_Customize_Form__c',
            form.Id
        );

        setValue(
            secondActivity,
            'BTL_Activities__c',
            btlActivity.Id
        );

        insertRecord(secondActivity);

        /*
         * BTL_Activities__c is a mandatory Master-Detail field.
         * It is assigned directly before insertion.
         *
         * Name is Auto Number and therefore is not populated.
         */
        BTL_Questions__c phoneQuestion =
            new BTL_Questions__c(
                BTL_Activities__c =
                    btlActivity.Id,

                Question__c =
                    'Enter customer phone number',

                Customer_Field_Name__c =
                    'Phone',

                Purpose__c =
                    'Customer phone capture'
            );

        setPreferredPicklistValue(
            phoneQuestion,
            'Answer_Type__c',
            new List<String>{
                'Numaric',
                'Numeric',
                'Number'
            }
        );

        insertRecord(phoneQuestion);

        System.assertEquals(
            btlActivity.Id,
            phoneQuestion.BTL_Activities__c,
            'Phone question should have the required BTL Activity.'
        );

        BTL_Questions__c nameQuestion =
            new BTL_Questions__c(
                BTL_Activities__c =
                    btlActivity.Id,

                Question__c =
                    'Enter customer name',

                Customer_Field_Name__c =
                    'Name',

                Purpose__c =
                    'Customer name capture'
            );

        setPreferredPicklistValue(
            nameQuestion,
            'Answer_Type__c',
            new List<String>{
                'Alphanumeric',
                'Text',
                'Alpha Numeric'
            }
        );

        insertRecord(nameQuestion);

        System.assertEquals(
            btlActivity.Id,
            nameQuestion.BTL_Activities__c,
            'Name question should have the required BTL Activity.'
        );

        Final_Customize_Form_Line_Item__c phoneLineItem =
            new Final_Customize_Form_Line_Item__c();

        setValue(
            phoneLineItem,
            'Name',
            'Phone Question'
        );

        setValue(
            phoneLineItem,
            'Final_Customize_Form__c',
            form.Id
        );

        setValue(
            phoneLineItem,
            'BTL_Questions__c',
            phoneQuestion.Id
        );

        setValue(
            phoneLineItem,
            'Question__c',
            'Phone Number'
        );

        setPreferredPicklistValue(
            phoneLineItem,
            'Answer_Type__c',
            new List<String>{
                'Numaric',
                'Numeric',
                'Number'
            }
        );

        setValue(
            phoneLineItem,
            'Sl_No__c',
            1
        );

        setValue(
            phoneLineItem,
            'Mandatory__c',
            true
        );

        setValue(
            phoneLineItem,
            'BTL_Activities__c',
            btlActivity.Id
        );

        insertRecord(phoneLineItem);

        Final_Customize_Form_Line_Item__c nameLineItem =
            new Final_Customize_Form_Line_Item__c();

        setValue(
            nameLineItem,
            'Name',
            'Name Question'
        );

        setValue(
            nameLineItem,
            'Final_Customize_Form__c',
            form.Id
        );

        setValue(
            nameLineItem,
            'BTL_Questions__c',
            nameQuestion.Id
        );

        setValue(
            nameLineItem,
            'Question__c',
            'Customer Name'
        );

        setPreferredPicklistValue(
            nameLineItem,
            'Answer_Type__c',
            new List<String>{
                'Alphanumeric',
                'Text',
                'Alpha Numeric'
            }
        );

        setValue(
            nameLineItem,
            'Sl_No__c',
            2
        );

        setValue(
            nameLineItem,
            'Mandatory__c',
            true
        );

        setValue(
            nameLineItem,
            'BTL_Activities__c',
            btlActivity.Id
        );

        insertRecord(nameLineItem);

        Final_Customize_Form_Line_Item_Answer__c
            answerOption =
                new Final_Customize_Form_Line_Item_Answer__c();

        setValue(
            answerOption,
            'Name',
            'Sample Option'
        );

        setValue(
            answerOption,
            'Final_Customize_Form_Line_Item__c',
            nameLineItem.Id
        );

        setValue(
            answerOption,
            'Answer__c',
            'Retail Customer'
        );

        setValue(
            answerOption,
            'BTL_Activities__c',
            btlActivity.Id
        );

        insertRecord(answerOption);

        Account existingCustomer =
            new Account();

        setValue(
            existingCustomer,
            'Name',
            'Existing BTL Customer'
        );

        setValue(
            existingCustomer,
            'Phone',
            EXISTING_PHONE
        );

        setValue(
            existingCustomer,
            'BC_Customer_No__c',
            'BC-10001'
        );

        setValue(
            existingCustomer,
            'Address_Line_1__c',
            '12 Test Street'
        );

        setValue(
            existingCustomer,
            'Address_Line_2__c',
            'Near Test Park'
        );

        setValue(
            existingCustomer,
            'Village_PO__c',
            'Salt Lake'
        );

        setValue(
            existingCustomer,
            'Residential_City__c',
            'Kolkata'
        );

        setValue(
            existingCustomer,
            'State_Province__c',
            'West Bengal'
        );

        setValue(
            existingCustomer,
            'District__c',
            'Kolkata'
        );

        setValue(
            existingCustomer,
            'Pin_Code__c',
            '700091'
        );

        setValue(
            existingCustomer,
            'Country__c',
            'India'
        );

        setValueByFieldType(
            existingCustomer,
            'DOB__c',
            '1990-01-15'
        );

        insertRecord(existingCustomer);

        Sales_Executives__c executive =
            new Sales_Executives__c();

        setValue(
            executive,
            'Name',
            'Test Sales Executive'
        );

        setValue(
            executive,
            'Store__c',
            storeOne.Id
        );

        setValue(
            executive,
            'BTL_Activities__c',
            btlActivity.Id
        );

        insertRecord(executive);

        Form_Activity_Daily_Execution__c execution =
            new Form_Activity_Daily_Execution__c();

        setValue(
            execution,
            'Name',
            'Daily Execution'
        );

        setValue(
            execution,
            'Form_Activity__c',
            activity.Id
        );

        setValue(
            execution,
            'Activity_Date__c',
            Date.today()
        );

        setValue(
            execution,
            'Store__c',
            storeOne.Id
        );

        setPreferredPicklistValue(
            execution,
            'Status__c',
            new List<String>{
                'Live',
                'In Progress',
                'Pending Initiation'
            }
        );

        setValue(
            execution,
            'Execution_Key__c',
            String.valueOf(activity.Id) +
                '-' +
                String.valueOf(Date.today()) +
                '-TEAM-A'
        );

        setValue(
            execution,
            'Store_Manager_Approved__c',
            true
        );

        setValue(
            execution,
            'BTL_Activity_Live__c',
            true
        );

        setValue(
            execution,
            'BTL_Activities__c',
            btlActivity.Id
        );

        insertRecord(execution);

        Form_Activity_Assigned_Persons__c assignedPerson =
            new Form_Activity_Assigned_Persons__c();

        setValue(
            assignedPerson,
            'Name',
            'Team A Assignment'
        );

        setValue(
            assignedPerson,
            'Form_Activity__c',
            activity.Id
        );

        setValue(
            assignedPerson,
            'Store__c',
            storeOne.Id
        );

        setValue(
            assignedPerson,
            'Team_Name__c',
            'Team A'
        );

        setValue(
            assignedPerson,
            'Sales_Executives__c',
            executive.Id
        );

        setValue(
            assignedPerson,
            'BTL_Activities__c',
            btlActivity.Id
        );

        insertRecord(assignedPerson);

        Form_Activity_Assigned_Persons_Date__c
            dateAssignment =
                new Form_Activity_Assigned_Persons_Date__c();

        setValue(
            dateAssignment,
            'Form_Activity_Assigned_Persons__c',
            assignedPerson.Id
        );

        setValue(
            dateAssignment,
            'Target_Date__c',
            Date.today()
        );

        setValue(
            dateAssignment,
            'Actual_Date__c',
            Date.today()
        );

        setValue(
            dateAssignment,
            'Activity_Location__c',
            'Salt Lake Sector V'
        );

        setValue(
            dateAssignment,
            'Store__c',
            storeOne.Id
        );

        setValue(
            dateAssignment,
            'Actual_Executive__c',
            executive.Id
        );

        setValue(
            dateAssignment,
            'Active_For_Date__c',
            true
        );

        setValue(
            dateAssignment,
            'Form_Activity_Daily_Execution__c',
            execution.Id
        );

        setValue(
            dateAssignment,
            'BTL_Activities__c',
            btlActivity.Id
        );

        insertRecord(dateAssignment);
    }

    @IsTest
    static void testGetStoresAndActivities() {

        TestData data =
            loadTestData();

        Test.startTest();

        List<
            ctrl_ActivityDashboardController.OptionWrapper
        > stores =
            ctrl_ActivityDashboardController.getStores();

        List<
            ctrl_ActivityDashboardController.ActivityWrapper
        > storeAndSearchResults =
            ctrl_ActivityDashboardController.getActivities(
                Date.today().addDays(-10),
                Date.today().addDays(10),
                data.storeOne.Id,
                'Salt Lake'
            );

        List<
            ctrl_ActivityDashboardController.ActivityWrapper
        > storeOnlyResults =
            ctrl_ActivityDashboardController.getActivities(
                Date.today().addDays(-10),
                Date.today().addDays(10),
                data.storeOne.Id,
                null
            );

        List<
            ctrl_ActivityDashboardController.ActivityWrapper
        > searchOnlyResults =
            ctrl_ActivityDashboardController.getActivities(
                Date.today().addDays(-10),
                Date.today().addDays(10),
                null,
                'Connaught'
            );

        List<
            ctrl_ActivityDashboardController.ActivityWrapper
        > allResults =
            ctrl_ActivityDashboardController.getActivities(
                Date.today().addDays(-10),
                Date.today().addDays(10),
                null,
                ' '
            );

        Test.stopTest();

        System.assert(
            stores.size() >= 3,
            'All Stores plus the two test stores should be returned.'
        );

        System.assertEquals(
            '',
            stores[0].value
        );

        System.assertEquals(
            'All Stores',
            stores[0].label
        );

        System.assertEquals(
            1,
            storeAndSearchResults.size()
        );

        System.assertEquals(
            data.activity.Id,
            storeAndSearchResults[0].activityId
        );

        System.assertEquals(
            'Salt Lake Sector V',
            storeAndSearchResults[0].activityLocation
        );

        System.assertEquals(
            data.storeOne.Id,
            storeAndSearchResults[0].storeId
        );

        System.assertEquals(
            data.form.Id,
            storeAndSearchResults[0]
                .finalCustomizeFormId
        );

        System.assertEquals(
            1,
            storeOnlyResults.size()
        );

        System.assertEquals(
            data.activity.Id,
            storeOnlyResults[0].activityId
        );

        System.assertEquals(
            1,
            searchOnlyResults.size()
        );

        System.assertEquals(
            data.secondActivity.Id,
            searchOnlyResults[0].activityId
        );

        System.assertEquals(
            2,
            allResults.size()
        );
    }

    @IsTest
    static void testGetInteractiveForm() {

        TestData data =
            loadTestData();

        Test.startTest();

        ctrl_ActivityDashboardController.InteractiveFormWrapper result = ctrl_ActivityDashboardController.getInteractiveForm(data.form.Id);

        Test.stopTest();
    }

    @IsTest
    static void testGetInteractiveFormMissingId() {

        Boolean exceptionThrown =
            false;

        Test.startTest();

        try {
            ctrl_ActivityDashboardController.getInteractiveForm(null);
        } catch (
            AuraHandledException expectedException
        ) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown
        );
    }

    @IsTest
    static void testGetCustomerDetailsByPhone() {

        TestData data =
            loadTestData();

        Test.startTest();

        ctrl_ActivityDashboardController.CustomerDetailsWrapper result =
                ctrl_ActivityDashboardController.getCustomerDetailsByPhone(
                        '+91' + EXISTING_PHONE,
                        data.form.Id
                    );

        ctrl_ActivityDashboardController.CustomerDetailsWrapper blankResult =
                ctrl_ActivityDashboardController.getCustomerDetailsByPhone(
                        ' ',
                        data.form.Id
                    );

        ctrl_ActivityDashboardController.CustomerDetailsWrapper missingResult =
                ctrl_ActivityDashboardController.getCustomerDetailsByPhone(
                        '9999999999',
                        data.form.Id
                    );

        Test.stopTest();

        System.assertNotEquals(
            null,
            result
        );

        System.assertEquals(
            'Existing BTL Customer',
            result.customerName
        );

        System.assertEquals(
            EXISTING_PHONE,
            result.phone
        );

        System.assertEquals(
            'BC-10001',
            result.bcCustomerNo
        );

        System.assertEquals(
            'Kolkata',
            result.residentialCity
        );

        System.assertEquals(
            'India',
            result.country
        );

        System.assertEquals(
            EXISTING_PHONE,
            result.fieldValues.get('Phone')
        );

        System.assertEquals(
            null,
            blankResult
        );

        System.assertEquals(
            null,
            missingResult
        );
    }

    @IsTest
    static void testInvalidPhoneLookup() {

        TestData data =
            loadTestData();

        Boolean exceptionThrown =
            false;

        Test.startTest();

        try {
            ctrl_ActivityDashboardController.getCustomerDetailsByPhone(
                    '555123',
                    data.form.Id
                );
        } catch (
            AuraHandledException expectedException
        ) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown
        );
    }

    @IsTest
    static void testSaveExistingCustomerResponse() {

        TestData data =
            loadTestData();

        List<ctrl_ActivityDashboardController.CustomerAnswerWrapper> answers =
            buildAnswers(
                data,
                EXISTING_PHONE,
                'Existing BTL Customer'
            );

        Test.startTest();

        Id responseId = ctrl_ActivityDashboardController.saveCustomerResponse(
                    data.activity.Id,
                    data.execution.Id,
                    EXISTING_PHONE,
                    22.5726,
                    88.3639,
                    answers
                );

        Test.stopTest();

        BTL_Customer_Response__c response = [
            SELECT Id,
                   Form_Activity__c,
                   Phone_No__c,
                   Orient_Customer__c,
                   Form_Activity_Daily_Execution__c,
                   Captured_By_Team__c,
                   Geo_Location__Latitude__s,
                   Geo_Location__Longitude__s
            FROM BTL_Customer_Response__c
            WHERE Id = :responseId
        ];

        Account existingCustomer = [
            SELECT Id
            FROM Account
            WHERE Phone = :EXISTING_PHONE
            LIMIT 1
        ];

        System.assertEquals(
            data.activity.Id,
            response.Form_Activity__c
        );

        System.assertEquals(
            EXISTING_PHONE,
            response.Phone_No__c
        );

        System.assertEquals(
            existingCustomer.Id,
            response.Orient_Customer__c
        );

        System.assertEquals(
            data.execution.Id,
            response.Form_Activity_Daily_Execution__c
        );

        System.assertEquals(
            'Team A',
            response.Captured_By_Team__c
        );

        System.assertEquals(
            Decimal.valueOf('22.5726'),
            response.Geo_Location__Latitude__s
        );

        System.assertEquals(
            Decimal.valueOf('88.3639'),
            response.Geo_Location__Longitude__s
        );

        Integer itemCount = [
            SELECT COUNT()
            FROM BTL_Customer_Response_Items__c
            WHERE BTL_Customer_Response__c =
                :responseId
        ];

        System.assertEquals(
            2,
            itemCount
        );
    }

    @IsTest
    static void testSaveResponseCreatesProspect() {

        TestData data =
            loadTestData();

        List<ctrl_ActivityDashboardController.CustomerAnswerWrapper> answers =
            buildAnswers(
                data,
                NEW_PHONE,
                'New Prospect Customer'
            );

        Test.startTest();

        Id responseId = ctrl_ActivityDashboardController.saveCustomerResponse(
                    data.activity.Id,
                    null,
                    NEW_PHONE,
                    null,
                    null,
                    answers
                );

        Test.stopTest();

        BTL_Customer_Response__c response = [
            SELECT Id,
                   Phone_No__c,
                   Orient_Customer__c,
                   Form_Activity_Daily_Execution__c,
                   Captured_By_Team__c
            FROM BTL_Customer_Response__c
            WHERE Id = :responseId
        ];

        Account createdProspect = [
            SELECT Id,
                   Name,
                   Phone,
                   Status__c
            FROM Account
            WHERE Id =
                :response.Orient_Customer__c
        ];

        System.assertEquals(
            NEW_PHONE,
            response.Phone_No__c
        );

        System.assertEquals(
            null,
            response.Form_Activity_Daily_Execution__c
        );

        System.assertEquals(
            null,
            response.Captured_By_Team__c
        );

        System.assertEquals(
            'New Prospect Customer',
            createdProspect.Name
        );

        System.assertEquals(
            NEW_PHONE,
            createdProspect.Phone
        );

        System.assertEquals(
            'Prospect',
            createdProspect.Status__c
        );
    }

    @IsTest
    static void testSaveResponseValidations() {

        TestData data =
            loadTestData();

        List<ctrl_ActivityDashboardController.CustomerAnswerWrapper> answers =
            buildAnswers(
                data,
                EXISTING_PHONE,
                'Validation Customer'
            );

        assertSaveFails(
            null,
            null,
            EXISTING_PHONE,
            answers
        );

        assertSaveFails(
            data.activity.Id,
            null,
            '12345',
            answers
        );

        assertSaveFails(
            data.activity.Id,
            null,
            EXISTING_PHONE,
            new List<ctrl_ActivityDashboardController.CustomerAnswerWrapper>()
        );
    }

    @IsTest
    static void testExecutionMustBelongToActivity() {

        TestData data =
            loadTestData();

        Boolean exceptionThrown =
            false;

        Test.startTest();

        try {
            ctrl_ActivityDashboardController.saveCustomerResponse(
                    data.secondActivity.Id,
                    data.execution.Id,
                    EXISTING_PHONE,
                    null,
                    null,
                    buildAnswers(
                        data,
                        EXISTING_PHONE,
                        'Mismatch Customer'
                    )
                );
        } catch (
            AuraHandledException expectedException
        ) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown
        );
    }

    @IsTest
    static void testExecutionWithoutTeam() {

        TestData data =
            loadTestData();

        Form_Activity_Daily_Execution__c
            executionWithoutTeam =
                new Form_Activity_Daily_Execution__c();

        setValue(
            executionWithoutTeam,
            'Form_Activity__c',
            data.activity.Id
        );

        setValue(
            executionWithoutTeam,
            'Activity_Date__c',
            Date.today()
        );

        setValue(
            executionWithoutTeam,
            'Store__c',
            data.storeOne.Id
        );

        setPreferredPicklistValue(
            executionWithoutTeam,
            'Status__c',
            new List<String>{
                'Live',
                'In Progress',
                'Pending Initiation'
            }
        );

        setValue(
            executionWithoutTeam,
            'Execution_Key__c',
            String.valueOf(data.activity.Id) +
                '-' +
                String.valueOf(Date.today()) +
                '-NO-TEAM'
        );

        setValue(
            executionWithoutTeam,
            'BTL_Activities__c',
            data.btlActivity.Id
        );

        insertRecord(executionWithoutTeam);

        Boolean exceptionThrown =
            false;

        Test.startTest();

        try {
            ctrl_ActivityDashboardController.saveCustomerResponse(
                    data.activity.Id,
                    executionWithoutTeam.Id,
                    EXISTING_PHONE,
                    null,
                    null,
                    buildAnswers(
                        data,
                        EXISTING_PHONE,
                        'No Team Customer'
                    )
                );
        } catch (
            AuraHandledException expectedException
        ) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown
        );
    }

    private static TestData loadTestData() {

        TestData data =
            new TestData();

        data.btlActivity = [
            SELECT Id
            FROM BTL_Activities__c
            LIMIT 1
        ];

        for (Store__c storeRecord : [
            SELECT Id,
                   Name
            FROM Store__c
            WHERE Name IN (
                'Kolkata Central Store',
                'Delhi North Store'
            )
        ]) {
            if (
                storeRecord.Name ==
                'Kolkata Central Store'
            ) {
                data.storeOne =
                    storeRecord;
            } else if (
                storeRecord.Name ==
                'Delhi North Store'
            ) {
                data.storeTwo =
                    storeRecord;
            }
        }

        data.form = [
            SELECT Id,
                   Name,
                   Form_Name__c,
                   Active__c
            FROM Final_Customize_Form__c
            WHERE Form_Name__c =
                'Customer Engagement Survey'
            LIMIT 1
        ];

        for (
            Form_Activity__c activityRecord : [
                SELECT Id,
                       Activity_Location__c,
                       Assigned_Store__c,
                       Final_Customize_Form__c
                FROM Form_Activity__c
                WHERE Final_Customize_Form__c =
                    :data.form.Id
            ]
        ) {
            if (
                activityRecord.Activity_Location__c ==
                'Salt Lake Sector V'
            ) {
                data.activity =
                    activityRecord;
            } else if (
                activityRecord.Activity_Location__c ==
                'Connaught Place'
            ) {
                data.secondActivity =
                    activityRecord;
            }
        }

        for (
            BTL_Questions__c question : [
                SELECT Id,
                       Customer_Field_Name__c,
                       BTL_Activities__c
                FROM BTL_Questions__c
                WHERE Customer_Field_Name__c
                    IN ('Phone', 'Name')
            ]
        ) {
            if (
                question.Customer_Field_Name__c ==
                'Phone'
            ) {
                data.phoneQuestion =
                    question;
            } else if (
                question.Customer_Field_Name__c ==
                'Name'
            ) {
                data.nameQuestion =
                    question;
            }
        }

        for (
            Final_Customize_Form_Line_Item__c
                lineItem : [
                    SELECT Id,
                           Question__c,
                           BTL_Questions__c
                    FROM Final_Customize_Form_Line_Item__c
                    WHERE Final_Customize_Form__c =
                        :data.form.Id
                ]
        ) {
            if (
                lineItem.Question__c ==
                'Phone Number'
            ) {
                data.phoneLineItem =
                    lineItem;
            } else if (
                lineItem.Question__c ==
                'Customer Name'
            ) {
                data.nameLineItem =
                    lineItem;
            }
        }

        data.executive = [
            SELECT Id,
                   Store__c
            FROM Sales_Executives__c
            WHERE Store__c =
                :data.storeOne.Id
            LIMIT 1
        ];

        data.execution = [
            SELECT Id,
                   Form_Activity__c,
                   Activity_Date__c,
                   Store__c
            FROM Form_Activity_Daily_Execution__c
            WHERE Form_Activity__c =
                :data.activity.Id
            LIMIT 1
        ];

        data.assignedPerson = [
            SELECT Id,
                   Form_Activity__c,
                   Team_Name__c
            FROM Form_Activity_Assigned_Persons__c
            WHERE Form_Activity__c =
                :data.activity.Id
            LIMIT 1
        ];

        data.dateAssignment = [
            SELECT Id,
                   Form_Activity_Assigned_Persons__c,
                   Form_Activity_Daily_Execution__c,
                   Active_For_Date__c
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Form_Activity_Daily_Execution__c =
                :data.execution.Id
            LIMIT 1
        ];

        System.assertEquals(
            data.btlActivity.Id,
            data.phoneQuestion.BTL_Activities__c
        );

        System.assertEquals(
            data.btlActivity.Id,
            data.nameQuestion.BTL_Activities__c
        );

        return data;
    }

    private static List<ctrl_ActivityDashboardController.CustomerAnswerWrapper> buildAnswers(
        TestData data,
        String phoneNumber,
        String customerName
    ) {
        ctrl_ActivityDashboardController.CustomerAnswerWrapper phoneAnswer =
                new ctrl_ActivityDashboardController.CustomerAnswerWrapper();

        phoneAnswer.lineItemId =
            data.phoneLineItem.Id;

        phoneAnswer.question =
            'Phone Number';

        phoneAnswer.answerType =
            'Numeric';

        phoneAnswer.answer =
            phoneNumber;

        ctrl_ActivityDashboardController.CustomerAnswerWrapper nameAnswer =
                new ctrl_ActivityDashboardController.CustomerAnswerWrapper();

        nameAnswer.lineItemId =
            data.nameLineItem.Id;

        nameAnswer.question =
            'Customer Name';

        nameAnswer.answerType =
            'Text';

        nameAnswer.answer =
            customerName;

        return new List<ctrl_ActivityDashboardController.CustomerAnswerWrapper>{
            phoneAnswer,
            nameAnswer
        };
    }

    private static void assertSaveFails(
        Id activityId,
        Id executionId,
        String phone,
        List<ctrl_ActivityDashboardController.CustomerAnswerWrapper> answers
    ) {
        Boolean exceptionThrown =
            false;

        try {
            ctrl_ActivityDashboardController.saveCustomerResponse(
                    activityId,
                    executionId,
                    phone,
                    null,
                    null,
                    answers
                );
        } catch (
            AuraHandledException expectedException
        ) {
            exceptionThrown =
                true;
        }

        System.assertEquals(
            true,
            exceptionThrown
        );
    }

    private static void insertRecord(
        SObject recordData
    ) {
        populateRequiredFields(
            recordData
        );

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

        Map<String, Schema.SObjectField>
            fieldMap =
                recordData.getSObjectType().getDescribe().fields.getMap();

        if (
            !fieldMap.containsKey(
                fieldApiName
            )
        ) {
            return;
        }

        Schema.DescribeFieldResult
            fieldDescribe =
                fieldMap
                    .get(fieldApiName)
                    .getDescribe();

        if (
            !fieldDescribe.isCreateable() ||
            fieldDescribe.isCalculated()
        ) {
            return;
        }

        recordData.put(
            fieldApiName,
            fieldValue
        );
    }

    private static void setPreferredPicklistValue(
        SObject recordData,
        String fieldApiName,
        List<String> preferredValues
    ) {
        if (
            recordData == null ||
            String.isBlank(fieldApiName) ||
            preferredValues == null ||
            preferredValues.isEmpty()
        ) {
            return;
        }

        Map<String, Schema.SObjectField>
            fieldMap =
                recordData
                    .getSObjectType()
                    .getDescribe()
                    .fields
                    .getMap();

        if (
            !fieldMap.containsKey(
                fieldApiName
            )
        ) {
            return;
        }

        Schema.DescribeFieldResult
            fieldDescribe =
                fieldMap
                    .get(fieldApiName)
                    .getDescribe();

        if (
            !fieldDescribe.isCreateable() ||
            fieldDescribe.isCalculated()
        ) {
            return;
        }

        if (
            fieldDescribe.getType() !=
                Schema.DisplayType.Picklist &&
            fieldDescribe.getType() !=
                Schema.DisplayType.MultiPicklist
        ) {
            recordData.put(
                fieldApiName,
                preferredValues[0]
            );

            return;
        }

        for (
            String preferredValue :
            preferredValues
        ) {
            for (
                Schema.PicklistEntry
                    picklistEntry :
                    fieldDescribe
                        .getPicklistValues()
            ) {
                if (
                    picklistEntry.isActive() &&
                    picklistEntry
                        .getValue()
                        .equalsIgnoreCase(
                            preferredValue
                        )
                ) {
                    recordData.put(
                        fieldApiName,
                        picklistEntry.getValue()
                    );

                    return;
                }
            }
        }

        if (
            !fieldDescribe
                .isRestrictedPicklist()
        ) {
            recordData.put(
                fieldApiName,
                preferredValues[0]
            );

            return;
        }

        for (
            Schema.PicklistEntry
                picklistEntry :
                fieldDescribe
                    .getPicklistValues()
        ) {
            if (
                picklistEntry.isActive()
            ) {
                recordData.put(
                    fieldApiName,
                    picklistEntry.getValue()
                );

                return;
            }
        }
    }

    private static void setValueByFieldType(
        SObject recordData,
        String fieldApiName,
        String sourceValue
    ) {
        if (
            recordData == null ||
            String.isBlank(fieldApiName) ||
            sourceValue == null
        ) {
            return;
        }

        Map<String, Schema.SObjectField>
            fieldMap =
                recordData
                    .getSObjectType()
                    .getDescribe()
                    .fields
                    .getMap();

        if (
            !fieldMap.containsKey(
                fieldApiName
            )
        ) {
            return;
        }

        Schema.DescribeFieldResult
            fieldDescribe =
                fieldMap
                    .get(fieldApiName)
                    .getDescribe();

        if (
            !fieldDescribe.isCreateable() ||
            fieldDescribe.isCalculated()
        ) {
            return;
        }

        Object convertedValue;

        if (
            fieldDescribe.getType() ==
            Schema.DisplayType.Date
        ) {
            convertedValue =
                Date.valueOf(
                    sourceValue
                );
        } else if (
            fieldDescribe.getType() ==
            Schema.DisplayType.DateTime
        ) {
            convertedValue =
                DateTime.valueOf(
                    sourceValue +
                    ' 00:00:00'
                );
        } else {
            convertedValue =
                sourceValue;
        }

        recordData.put(
            fieldApiName,
            convertedValue
        );
    }

    private static void populateRequiredFields(
        SObject recordData
    ) {
        Map<String, Schema.SObjectField>
            fieldMap =
                recordData
                    .getSObjectType()
                    .getDescribe()
                    .fields
                    .getMap();

        for (
            String fieldApiName :
            fieldMap.keySet()
        ) {
            Schema.DescribeFieldResult
                fieldDescribe =
                    fieldMap
                        .get(fieldApiName)
                        .getDescribe();

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

            Object defaultValue =
                buildDefaultValue(
                    fieldDescribe
                );

            if (
                defaultValue != null
            ) {
                recordData.put(
                    fieldApiName,
                    defaultValue
                );
            }
        }
    }

    private static Object buildDefaultValue(
        Schema.DescribeFieldResult
            fieldDescribe
    ) {
        Schema.DisplayType fieldType =
            fieldDescribe.getType();

        if (
            fieldType ==
                Schema.DisplayType.String ||
            fieldType ==
                Schema.DisplayType.TextArea ||
            fieldType ==
                Schema.DisplayType.EncryptedString
        ) {
            return trimToLength(
                'Test Value',
                fieldDescribe.getLength()
            );
        }

        if (
            fieldType ==
            Schema.DisplayType.Phone
        ) {
            return trimToLength(
                '9876543210',
                fieldDescribe.getLength()
            );
        }

        if (
            fieldType ==
            Schema.DisplayType.Email
        ) {
            return trimToLength(
                'test@example.com',
                fieldDescribe.getLength()
            );
        }

        if (
            fieldType ==
            Schema.DisplayType.Url
        ) {
            return trimToLength(
                'https://example.com',
                fieldDescribe.getLength()
            );
        }

        if (
            fieldType ==
            Schema.DisplayType.Boolean
        ) {
            return false;
        }

        if (
            fieldType ==
            Schema.DisplayType.Date
        ) {
            return Date.today();
        }

        if (
            fieldType ==
            Schema.DisplayType.DateTime
        ) {
            return System.now();
        }

        if (
            fieldType ==
            Schema.DisplayType.Time
        ) {
            return Time.newInstance(
                10,
                0,
                0,
                0
            );
        }

        if (
            fieldType ==
                Schema.DisplayType.Integer ||
            fieldType ==
                Schema.DisplayType.Double ||
            fieldType ==
                Schema.DisplayType.Currency ||
            fieldType ==
                Schema.DisplayType.Percent
        ) {
            return 1;
        }

        if (
            fieldType ==
                Schema.DisplayType.Picklist ||
            fieldType ==
                Schema.DisplayType.MultiPicklist
        ) {
            for (
                Schema.PicklistEntry
                    picklistEntry :
                    fieldDescribe
                        .getPicklistValues()
            ) {
                if (
                    picklistEntry.isActive()
                ) {
                    return
                        picklistEntry.getValue();
                }
            }
        }

        if (
            fieldType ==
            Schema.DisplayType.Reference
        ) {
            for (
                Schema.SObjectType
                    referencedType :
                    fieldDescribe
                        .getReferenceTo()
            ) {
                if (
                    referencedType
                        .getDescribe()
                        .getName() ==
                    'User'
                ) {
                    return
                        UserInfo.getUserId();
                }
            }
        }

        return null;
    }

    private static String trimToLength(
        String value,
        Integer maximumLength
    ) {
        if (
            maximumLength == null ||
            maximumLength <= 0
        ) {
            return value;
        }

        return (
            value.length() <= maximumLength
        )
            ? value
            : value.substring(
                0,
                maximumLength
            );
    }
}