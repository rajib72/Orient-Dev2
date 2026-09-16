@IsTest
public class ctrl_ActivityDashboardControllerTest {

    @TestSetup
    static void setupTestData() {

        Store__c storeObj = new Store__c();
        storeObj.Name = 'Test Store Kolkata';
        storeObj.Store_Code__c = 'TS001';
        storeObj.Location__c = 'Kolkata';
        insert storeObj;

        Final_Customize_Form__c finalForm = new Final_Customize_Form__c();
        finalForm.Form_Name__c = 'Customer Feedback Form';
        finalForm.Active__c = true;
        insert finalForm;

        Form_Activity__c activity = new Form_Activity__c();
        activity.Activity_Date__c = Date.today();
        activity.Activity_Location__c = 'Kolkata Mall';
        activity.Assigned_Store__c = storeObj.Id;
        activity.Final_Customize_Form__c = finalForm.Id;
        insert activity;

        Form_Activity__c activity2 = new Form_Activity__c();
        activity2.Activity_Date__c = Date.today().addDays(-1);
        activity2.Activity_Location__c = 'Salt Lake';
        activity2.Assigned_Store__c = storeObj.Id;
        activity2.Final_Customize_Form__c = finalForm.Id;
        insert activity2;

        Final_Customize_Form_Line_Item__c lineItem1 = new Final_Customize_Form_Line_Item__c();
        lineItem1.Final_Customize_Form__c = finalForm.Id;
        lineItem1.Question__c = 'May I know your good name?';
        insert lineItem1;

        Final_Customize_Form_Line_Item__c lineItem2 = new Final_Customize_Form_Line_Item__c();
        lineItem2.Final_Customize_Form__c = finalForm.Id;
        lineItem2.Question__c = 'Are you interested?';
        insert lineItem2;

        Final_Customize_Form_Line_Item__c lineItem3 = new Final_Customize_Form_Line_Item__c();
        lineItem3.Final_Customize_Form__c = finalForm.Id;
        lineItem3.Question__c = 'Age';
        insert lineItem3;

        Final_Customize_Form_Line_Item_Answer__c answer1 =
            new Final_Customize_Form_Line_Item_Answer__c();
        answer1.Final_Customize_Form_Line_Item__c = lineItem2.Id;
        insert answer1;

        Final_Customize_Form_Line_Item_Answer__c answer2 =
            new Final_Customize_Form_Line_Item_Answer__c();
        answer2.Final_Customize_Form_Line_Item__c = lineItem2.Id;
        insert answer2;
    }

    @IsTest
    static void testGetStores() {

        Test.startTest();
        List<ctrl_ActivityDashboardController.OptionWrapper> storeOptions =
            ctrl_ActivityDashboardController.getStores();
        Test.stopTest();

        System.assertNotEquals(null, storeOptions);
        System.assert(storeOptions.size() >= 2);
        System.assertEquals('', storeOptions[0].value);
        System.assertEquals('All Stores', storeOptions[0].label);
    }

    @IsTest
    static void testGetActivitiesWithoutStoreAndWithoutSearch() {

        Test.startTest();
        List<ctrl_ActivityDashboardController.ActivityWrapper> resultList =
            ctrl_ActivityDashboardController.getActivities(
                Date.today().addDays(-5),
                Date.today().addDays(5),
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, resultList);
        System.assertEquals(2, resultList.size());
        System.assertNotEquals(null, resultList[0].activityId);
        System.assertNotEquals(null, resultList[0].activityNo);
    }

    @IsTest
    static void testGetActivitiesWithStoreOnly() {

        Store__c storeObj = [
            SELECT Id
            FROM Store__c
            WHERE Store_Code__c = 'TS001'
            LIMIT 1
        ];

        Test.startTest();
        List<ctrl_ActivityDashboardController.ActivityWrapper> resultList =
            ctrl_ActivityDashboardController.getActivities(
                Date.today().addDays(-5),
                Date.today().addDays(5),
                storeObj.Id,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, resultList);
        System.assertEquals(2, resultList.size());
        System.assertEquals(storeObj.Id, resultList[0].storeId);
    }

   @IsTest
static void testGetActivitiesWithSearchOnly() {

    Test.startTest();
    List<ctrl_ActivityDashboardController.ActivityWrapper> resultList =
        ctrl_ActivityDashboardController.getActivities(
            Date.today().addDays(-5),
            Date.today().addDays(5),
            null,
            'Kolkata Mall'
        );
    Test.stopTest();

    System.assertNotEquals(null, resultList);
    System.assertEquals(1, resultList.size());
    System.assertEquals('Kolkata Mall', resultList[0].activityLocation);
}
    @IsTest
    static void testGetActivitiesWithStoreAndSearch() {

        Store__c storeObj = [
            SELECT Id
            FROM Store__c
            WHERE Store_Code__c = 'TS001'
            LIMIT 1
        ];

        Test.startTest();
        List<ctrl_ActivityDashboardController.ActivityWrapper> resultList =
            ctrl_ActivityDashboardController.getActivities(
                Date.today().addDays(-5),
                Date.today().addDays(5),
                storeObj.Id,
                'Customer Feedback'
            );
        Test.stopTest();

        System.assertNotEquals(null, resultList);
        System.assert(resultList.size() > 0);
    }

    @IsTest
    static void testGetActivitiesNoMatch() {

        Test.startTest();
        List<ctrl_ActivityDashboardController.ActivityWrapper> resultList =
            ctrl_ActivityDashboardController.getActivities(
                Date.today().addDays(-5),
                Date.today().addDays(5),
                null,
                'No Match Search Text'
            );
        Test.stopTest();

        System.assertNotEquals(null, resultList);
        System.assertEquals(0, resultList.size());
    }

    @IsTest
    static void testGetInteractiveFormSuccess() {

        Final_Customize_Form__c finalForm = [
            SELECT Id, Name, Form_Name__c, Active__c
            FROM Final_Customize_Form__c
            WHERE Form_Name__c = 'Customer Feedback Form'
            LIMIT 1
        ];

        Test.startTest();
        ctrl_ActivityDashboardController.InteractiveFormWrapper formWrapper =
            ctrl_ActivityDashboardController.getInteractiveForm(finalForm.Id);
        Test.stopTest();

        System.assertNotEquals(null, formWrapper);
        System.assertEquals(finalForm.Id, formWrapper.formId);
        System.assertEquals('Customer Feedback Form', formWrapper.formName);
        System.assertEquals(true, formWrapper.active);
        System.assertEquals(3, formWrapper.questions.size());

        for (ctrl_ActivityDashboardController.QuestionWrapper q : formWrapper.questions) {
            System.assertNotEquals(null, q.lineItemId);
            System.assertNotEquals(null, q.question);
            System.assertNotEquals(null, q.fieldType);
        }
    }

    @IsTest
    static void testGetInteractiveFormMissingId() {

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            ctrl_ActivityDashboardController.getInteractiveForm(null);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testSaveCustomerResponseSuccess() {

        Form_Activity__c activity = [
            SELECT Id
            FROM Form_Activity__c
            WHERE Activity_Location__c = 'Kolkata Mall'
            LIMIT 1
        ];

        List<ctrl_ActivityDashboardController.CustomerAnswerWrapper> answers =
            new List<ctrl_ActivityDashboardController.CustomerAnswerWrapper>();

        ctrl_ActivityDashboardController.CustomerAnswerWrapper ans1 =
            new ctrl_ActivityDashboardController.CustomerAnswerWrapper();
        ans1.question = 'May I know your good name?';
        ans1.answerType = 'Text';
        ans1.answer = 'Amit Test';
        answers.add(ans1);

        ctrl_ActivityDashboardController.CustomerAnswerWrapper ans2 =
            new ctrl_ActivityDashboardController.CustomerAnswerWrapper();
        ans2.question = 'Are you interested?';
        ans2.answerType = 'Picklist';
        ans2.answer = 'Yes';
        answers.add(ans2);

        Test.startTest();
        Id responseId = ctrl_ActivityDashboardController.saveCustomerResponse(
            activity.Id,
            '9876543210',
            22.5726,
            88.3639,
            answers
        );
        Test.stopTest();

        System.assertNotEquals(null, responseId);

        BTL_Customer_Response__c response = [
            SELECT Id, Form_Activity__c, Phone_No__c,
                   Geo_Location__Latitude__s, Geo_Location__Longitude__s
            FROM BTL_Customer_Response__c
            WHERE Id = :responseId
            LIMIT 1
        ];

        System.assertEquals(activity.Id, response.Form_Activity__c);
        System.assertEquals('9876543210', response.Phone_No__c);
        System.assertEquals(22.5726, response.Geo_Location__Latitude__s);
        System.assertEquals(88.3639, response.Geo_Location__Longitude__s);

        List<BTL_Customer_Response_Items__c> itemList = [
            SELECT Id, Question__c, Answer__c
            FROM BTL_Customer_Response_Items__c
            WHERE BTL_Customer_Response__c = :responseId
        ];

        System.assertEquals(2, itemList.size());
    }

    @IsTest
    static void testSaveCustomerResponseWithNullAnswerRow() {

        Form_Activity__c activity = [
            SELECT Id
            FROM Form_Activity__c
            LIMIT 1
        ];

        List<ctrl_ActivityDashboardController.CustomerAnswerWrapper> answers =
            new List<ctrl_ActivityDashboardController.CustomerAnswerWrapper>();

        answers.add(null);

        ctrl_ActivityDashboardController.CustomerAnswerWrapper ans =
            new ctrl_ActivityDashboardController.CustomerAnswerWrapper();
        ans.question = 'Age';
        ans.answerType = 'Number';
        ans.answer = '30';
        answers.add(ans);

        Test.startTest();
        Id responseId = ctrl_ActivityDashboardController.saveCustomerResponse(
            activity.Id,
            '9999999999',
            null,
            null,
            answers
        );
        Test.stopTest();

        System.assertNotEquals(null, responseId);

        List<BTL_Customer_Response_Items__c> itemList = [
            SELECT Id
            FROM BTL_Customer_Response_Items__c
            WHERE BTL_Customer_Response__c = :responseId
        ];

        System.assertEquals(1, itemList.size());
    }

    @IsTest
    static void testSaveCustomerResponseMissingActivityId() {

        List<ctrl_ActivityDashboardController.CustomerAnswerWrapper> answers =
            new List<ctrl_ActivityDashboardController.CustomerAnswerWrapper>();

        ctrl_ActivityDashboardController.CustomerAnswerWrapper ans =
            new ctrl_ActivityDashboardController.CustomerAnswerWrapper();
        ans.question = 'Test Question';
        ans.answer = 'Test Answer';
        answers.add(ans);

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            ctrl_ActivityDashboardController.saveCustomerResponse(
                null,
                '9876543210',
                null,
                null,
                answers
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testSaveCustomerResponseMissingPhone() {

        Form_Activity__c activity = [
            SELECT Id
            FROM Form_Activity__c
            LIMIT 1
        ];

        List<ctrl_ActivityDashboardController.CustomerAnswerWrapper> answers =
            new List<ctrl_ActivityDashboardController.CustomerAnswerWrapper>();

        ctrl_ActivityDashboardController.CustomerAnswerWrapper ans =
            new ctrl_ActivityDashboardController.CustomerAnswerWrapper();
        ans.question = 'Test Question';
        ans.answer = 'Test Answer';
        answers.add(ans);

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            ctrl_ActivityDashboardController.saveCustomerResponse(
                activity.Id,
                '',
                null,
                null,
                answers
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testSaveCustomerResponseNoAnswers() {

        Form_Activity__c activity = [
            SELECT Id
            FROM Form_Activity__c
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            ctrl_ActivityDashboardController.saveCustomerResponse(
                activity.Id,
                '9876543210',
                null,
                null,
                new List<ctrl_ActivityDashboardController.CustomerAnswerWrapper>()
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testSaveCustomerResponseNullAnswers() {

        Form_Activity__c activity = [
            SELECT Id
            FROM Form_Activity__c
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            ctrl_ActivityDashboardController.saveCustomerResponse(
                activity.Id,
                '9876543210',
                null,
                null,
                null
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }
}