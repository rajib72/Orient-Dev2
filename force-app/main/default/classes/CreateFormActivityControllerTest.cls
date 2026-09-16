@IsTest
public class CreateFormActivityControllerTest {

    @TestSetup
    static void setupTestData() {

        // Create Store
        Store__c storeObj = new Store__c();
        storeObj.Name = 'Test Store';
        storeObj.Store_Code__c = 'TEST001';
        storeObj.Location__c = 'Test Location';
        insert storeObj;

        // Create another Store to test blank sales executive result
        Store__c storeWithoutExecutive = new Store__c();
        storeWithoutExecutive.Name = 'Store Without Executive';
        storeWithoutExecutive.Store_Code__c = 'TEST002';
        storeWithoutExecutive.Location__c = 'Test Location 2';
        insert storeWithoutExecutive;

        // Create Sales Executives
        Sales_Executives__c se1 = new Sales_Executives__c();
        se1.Name = 'Test Sales Executive 1';
        se1.Store__c = storeObj.Id;
        insert se1;

        Sales_Executives__c se2 = new Sales_Executives__c();
        se2.Name = 'Test Sales Executive 2';
        se2.Store__c = storeObj.Id;
        insert se2;

        // Create Final Customize Form
        Final_Customize_Form__c finalForm = new Final_Customize_Form__c();
        finalForm.Form_Name__c = 'Test Customer Form';
        finalForm.Active__c = true;
        insert finalForm;
    }

    @IsTest
    static void testGetStores() {

        Test.startTest();
        List<CreateFormActivityController.OptionWrapper> storeOptions =
            CreateFormActivityController.getStores();
        Test.stopTest();

        System.assertNotEquals(null, storeOptions, 'Store options should not be null');
        System.assert(storeOptions.size() >= 2, 'At least two stores should be returned');

        Boolean testStoreFound = false;

        for (CreateFormActivityController.OptionWrapper opt : storeOptions) {
            if (opt.label == 'Test Store') {
                testStoreFound = true;
                System.assertNotEquals(null, opt.value, 'Store value should not be null');
            }
        }

        System.assertEquals(true, testStoreFound, 'Test Store should be available in store options');
    }

    @IsTest
    static void testGetSalesExecutivesByStore() {

        Store__c storeObj = [
            SELECT Id
            FROM Store__c
            WHERE Store_Code__c = 'TEST001'
            LIMIT 1
        ];

        Test.startTest();
        List<CreateFormActivityController.OptionWrapper> executiveOptions =
            CreateFormActivityController.getSalesExecutivesByStore(storeObj.Id);
        Test.stopTest();

        System.assertNotEquals(null, executiveOptions, 'Executive options should not be null');
        System.assertEquals(2, executiveOptions.size(), 'Two sales executives should be returned');

        Set<String> executiveNames = new Set<String>();

        for (CreateFormActivityController.OptionWrapper opt : executiveOptions) {
            executiveNames.add(opt.label);
            System.assertNotEquals(null, opt.value, 'Executive Id should not be null');
        }

        System.assertEquals(true, executiveNames.contains('Test Sales Executive 1'));
        System.assertEquals(true, executiveNames.contains('Test Sales Executive 2'));
    }

    @IsTest
    static void testGetSalesExecutivesByStoreWithNullStore() {

        Test.startTest();
        List<CreateFormActivityController.OptionWrapper> executiveOptions =
            CreateFormActivityController.getSalesExecutivesByStore(null);
        Test.stopTest();

        System.assertNotEquals(null, executiveOptions, 'Executive options should not be null');
        System.assertEquals(0, executiveOptions.size(), 'Null store should return empty list');
    }

    @IsTest
    static void testGetSalesExecutivesByStoreNoExecutives() {

        Store__c storeWithoutExecutive = [
            SELECT Id
            FROM Store__c
            WHERE Store_Code__c = 'TEST002'
            LIMIT 1
        ];

        Test.startTest();
        List<CreateFormActivityController.OptionWrapper> executiveOptions =
            CreateFormActivityController.getSalesExecutivesByStore(storeWithoutExecutive.Id);
        Test.stopTest();

        System.assertNotEquals(null, executiveOptions, 'Executive options should not be null');
        System.assertEquals(0, executiveOptions.size(), 'No executives should be returned for this store');
    }

    @IsTest
    static void testCreateActivitySuccess() {

        Store__c storeObj = [
            SELECT Id
            FROM Store__c
            WHERE Store_Code__c = 'TEST001'
            LIMIT 1
        ];

        Final_Customize_Form__c finalForm = [
            SELECT Id
            FROM Final_Customize_Form__c
            WHERE Form_Name__c = 'Test Customer Form'
            LIMIT 1
        ];

        List<Sales_Executives__c> salesExecutives = [
            SELECT Id, Name
            FROM Sales_Executives__c
            WHERE Store__c = :storeObj.Id
            ORDER BY Name ASC
        ];

        List<Id> salesExecutiveIds = new List<Id>();

        for (Sales_Executives__c se : salesExecutives) {
            salesExecutiveIds.add(se.Id);
        }

        Test.startTest();
        Id activityId = CreateFormActivityController.createActivity(
            finalForm.Id,
            storeObj.Id,
            Date.today(),
            'Test Activity Location',
            salesExecutiveIds
        );
        Test.stopTest();

        System.assertNotEquals(null, activityId, 'Activity Id should not be null');

        Form_Activity__c createdActivity = [
            SELECT Id, Final_Customize_Form__c, Assigned_Store__c, Activity_Date__c, Activity_Location__c
            FROM Form_Activity__c
            WHERE Id = :activityId
            LIMIT 1
        ];

        System.assertEquals(finalForm.Id, createdActivity.Final_Customize_Form__c, 'Final Customize Form should match');
        System.assertEquals(storeObj.Id, createdActivity.Assigned_Store__c, 'Assigned Store should match');
        System.assertEquals(Date.today(), createdActivity.Activity_Date__c, 'Activity Date should match');
        System.assertEquals('Test Activity Location', createdActivity.Activity_Location__c, 'Activity Location should match');

        List<Form_Activity_Assigned_Persons__c> assignedPersons = [
            SELECT Id, Form_Activity__c, Store__c, Sales_Executives__c, Person_Name__c
            FROM Form_Activity_Assigned_Persons__c
            WHERE Form_Activity__c = :activityId
        ];

        System.assertEquals(2, assignedPersons.size(), 'Two assigned person records should be created');

        for (Form_Activity_Assigned_Persons__c person : assignedPersons) {
            System.assertEquals(activityId, person.Form_Activity__c, 'Form Activity should match');
            System.assertEquals(storeObj.Id, person.Store__c, 'Store should match');
            System.assertNotEquals(null, person.Sales_Executives__c, 'Sales Executive should not be blank');
            System.assertNotEquals(null, person.Person_Name__c, 'Person Name should not be blank');
        }
    }

    @IsTest
    static void testCreateActivityWithOneInvalidExecutiveId() {

        Store__c storeObj = [
            SELECT Id
            FROM Store__c
            WHERE Store_Code__c = 'TEST001'
            LIMIT 1
        ];

        Final_Customize_Form__c finalForm = [
            SELECT Id
            FROM Final_Customize_Form__c
            WHERE Form_Name__c = 'Test Customer Form'
            LIMIT 1
        ];

        Sales_Executives__c validExecutive = [
            SELECT Id
            FROM Sales_Executives__c
            WHERE Store__c = :storeObj.Id
            LIMIT 1
        ];

        // This is a valid Salesforce Id format but it does not belong to Sales_Executives__c in test data
        Id fakeExecutiveId = UserInfo.getUserId();

        List<Id> salesExecutiveIds = new List<Id>{
            validExecutive.Id,
            fakeExecutiveId
        };

        Test.startTest();
        Id activityId = CreateFormActivityController.createActivity(
            finalForm.Id,
            storeObj.Id,
            Date.today(),
            'Activity With One Valid Executive',
            salesExecutiveIds
        );
        Test.stopTest();

        System.assertNotEquals(null, activityId, 'Activity should be created');

        List<Form_Activity_Assigned_Persons__c> assignedPersons = [
            SELECT Id, Sales_Executives__c
            FROM Form_Activity_Assigned_Persons__c
            WHERE Form_Activity__c = :activityId
        ];

        System.assertEquals(
            1,
            assignedPersons.size(),
            'Only one assigned person should be created because one executive Id is invalid'
        );

        System.assertEquals(validExecutive.Id, assignedPersons[0].Sales_Executives__c);
    }

    @IsTest
    static void testCreateActivityMissingFinalCustomizeForm() {

        Store__c storeObj = [
            SELECT Id
            FROM Store__c
            WHERE Store_Code__c = 'TEST001'
            LIMIT 1
        ];

        Sales_Executives__c se = [
            SELECT Id
            FROM Sales_Executives__c
            WHERE Store__c = :storeObj.Id
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            CreateFormActivityController.createActivity(
                null,
                storeObj.Id,
                Date.today(),
                'Test Location',
                new List<Id>{ se.Id }
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for missing Final Customize Form Id');
    }

    @IsTest
    static void testCreateActivityMissingAssignedStore() {

        Final_Customize_Form__c finalForm = [
            SELECT Id
            FROM Final_Customize_Form__c
            WHERE Form_Name__c = 'Test Customer Form'
            LIMIT 1
        ];

        Sales_Executives__c se = [
            SELECT Id
            FROM Sales_Executives__c
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            CreateFormActivityController.createActivity(
                finalForm.Id,
                null,
                Date.today(),
                'Test Location',
                new List<Id>{ se.Id }
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for missing Assigned Store');
    }

    @IsTest
    static void testCreateActivityMissingActivityDate() {

        Store__c storeObj = [
            SELECT Id
            FROM Store__c
            WHERE Store_Code__c = 'TEST001'
            LIMIT 1
        ];

        Final_Customize_Form__c finalForm = [
            SELECT Id
            FROM Final_Customize_Form__c
            WHERE Form_Name__c = 'Test Customer Form'
            LIMIT 1
        ];

        Sales_Executives__c se = [
            SELECT Id
            FROM Sales_Executives__c
            WHERE Store__c = :storeObj.Id
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            CreateFormActivityController.createActivity(
                finalForm.Id,
                storeObj.Id,
                null,
                'Test Location',
                new List<Id>{ se.Id }
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for missing Activity Date');
    }

    @IsTest
    static void testCreateActivityMissingActivityLocation() {

        Store__c storeObj = [
            SELECT Id
            FROM Store__c
            WHERE Store_Code__c = 'TEST001'
            LIMIT 1
        ];

        Final_Customize_Form__c finalForm = [
            SELECT Id
            FROM Final_Customize_Form__c
            WHERE Form_Name__c = 'Test Customer Form'
            LIMIT 1
        ];

        Sales_Executives__c se = [
            SELECT Id
            FROM Sales_Executives__c
            WHERE Store__c = :storeObj.Id
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            CreateFormActivityController.createActivity(
                finalForm.Id,
                storeObj.Id,
                Date.today(),
                '',
                new List<Id>{ se.Id }
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for missing Activity Location');
    }

    @IsTest
    static void testCreateActivityMissingSalesExecutiveListNull() {

        Store__c storeObj = [
            SELECT Id
            FROM Store__c
            WHERE Store_Code__c = 'TEST001'
            LIMIT 1
        ];

        Final_Customize_Form__c finalForm = [
            SELECT Id
            FROM Final_Customize_Form__c
            WHERE Form_Name__c = 'Test Customer Form'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            CreateFormActivityController.createActivity(
                finalForm.Id,
                storeObj.Id,
                Date.today(),
                'Test Location',
                null
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for null Sales Executive list');
    }

    @IsTest
    static void testCreateActivityMissingSalesExecutiveListEmpty() {

        Store__c storeObj = [
            SELECT Id
            FROM Store__c
            WHERE Store_Code__c = 'TEST001'
            LIMIT 1
        ];

        Final_Customize_Form__c finalForm = [
            SELECT Id
            FROM Final_Customize_Form__c
            WHERE Form_Name__c = 'Test Customer Form'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            CreateFormActivityController.createActivity(
                finalForm.Id,
                storeObj.Id,
                Date.today(),
                'Test Location',
                new List<Id>()
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for empty Sales Executive list');
    }
}