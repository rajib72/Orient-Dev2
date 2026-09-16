/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : ctrl_ManageFormActivityPersonsTest
 * Description     : Test class for ctrl_ManageFormActivityPersonsController
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@isTest
private class ctrl_ManageFormActivityPersonsTest {

    @testSetup
    static void setupTestData() {
        // 1. Create a mock Store 
        Store__c testStore = new Store__c(Name = 'Test Store 123');
        insert testStore;

        // 2. Create a mock Final Customize Form (Removed Name assignment)
        Final_Customize_Form__c testForm = new Final_Customize_Form__c();
        insert testForm;

        // 3. Create Sales Executives (Assuming Name is a Text field here since it didn't error)
        Sales_Executives__c testExec1 = new Sales_Executives__c(Name = 'John Doe', Store__c = testStore.Id);
        Sales_Executives__c testExec2 = new Sales_Executives__c(Name = 'Jane Smith', Store__c = testStore.Id);
        insert new List<Sales_Executives__c>{ testExec1, testExec2 };

        // 4. Create Form Activity (Removed Name assignment)
        Form_Activity__c testActivity = new Form_Activity__c(
            Final_Customize_Form__c = testForm.Id,
            Assigned_Store__c = testStore.Id,
            Activity_Date__c = Date.today()
        );
        insert testActivity;

        // 5. Assign one executive to the activity
        Form_Activity_Assigned_Persons__c assignedPerson = new Form_Activity_Assigned_Persons__c(
            Form_Activity__c = testActivity.Id,
            Store__c = testStore.Id,
            Sales_Executives__c = testExec1.Id,
            // Assuming Person_Name__c is a custom text field, leave it. If it's auto-number too, remove this line.
            Person_Name__c = testExec1.Name 
        );
        insert assignedPerson;
    }

    @isTest
    static void testGetFormActivities() {
        Final_Customize_Form__c testForm = [SELECT Id FROM Final_Customize_Form__c LIMIT 1];

        Test.startTest();
        // Positive Test
        List<ctrl_ManageFormActivityPersonsController.OptionWrapper> results = 
            ctrl_ManageFormActivityPersonsController.getFormActivities(testForm.Id);

        // Negative Test (Null ID)
        List<ctrl_ManageFormActivityPersonsController.OptionWrapper> nullResults = 
            ctrl_ManageFormActivityPersonsController.getFormActivities(null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return exactly 1 option wrapper for the form activity');
        System.assertEquals(0, nullResults.size(), 'Should return an empty list for a null Form ID');
    }

    @isTest
    static void testGetActivityDetails() {
        Form_Activity__c testActivity = [SELECT Id, Assigned_Store__c FROM Form_Activity__c LIMIT 1];

        Test.startTest();
        // Positive Test
        ctrl_ManageFormActivityPersonsController.ActivityDetailWrapper result = 
            ctrl_ManageFormActivityPersonsController.getActivityDetails(testActivity.Id);

        // Negative Test (Null ID)
        ctrl_ManageFormActivityPersonsController.ActivityDetailWrapper nullResult = 
            ctrl_ManageFormActivityPersonsController.getActivityDetails(null);
        Test.stopTest();

        // Assertions for Valid Details
        System.assertNotEquals(null, result, 'Result wrapper should not be null');
        System.assertEquals(testActivity.Id, result.formActivityId, 'Activity ID should match the queried record');
        System.assertEquals(1, result.assignedPersons.size(), 'There should be 1 assigned person initially');
        System.assertEquals(2, result.availableExecutives.size(), 'There should be 2 available executives tied to the store');

        // Verify the 'alreadyAssigned' flag is working properly
        for (ctrl_ManageFormActivityPersonsController.ExecutiveWrapper exec : result.availableExecutives) {
            if (exec.name == 'John Doe') {
                System.assertEquals(true, exec.alreadyAssigned, 'John Doe should be flagged as already assigned');
            } else {
                System.assertEquals(false, exec.alreadyAssigned, 'Jane Smith should NOT be flagged as assigned');
            }
        }

        // Assertion for Null Request
        System.assertEquals(null, nullResult.formActivityId, 'Null result should have no Activity ID');
    }

    @isTest
    static void testAddAssignedPersonsSuccess() {
        Form_Activity__c testActivity = [SELECT Id, Assigned_Store__c FROM Form_Activity__c LIMIT 1];
        Sales_Executives__c unassignedExec = [SELECT Id FROM Sales_Executives__c WHERE Name = 'Jane Smith' LIMIT 1];
        Sales_Executives__c assignedExec = [SELECT Id FROM Sales_Executives__c WHERE Name = 'John Doe' LIMIT 1];

        Test.startTest();
        // Assign the unassigned executive (Jane) and attempt to re-assign the already assigned one (John)
        List<Id> execIdsToAssign = new List<Id>{ unassignedExec.Id, assignedExec.Id };
        ctrl_ManageFormActivityPersonsController.addAssignedPersons(testActivity.Id, testActivity.Assigned_Store__c, execIdsToAssign);
        Test.stopTest();

        List<Form_Activity_Assigned_Persons__c> allAssigned = [
            SELECT Id, Sales_Executives__c
            FROM Form_Activity_Assigned_Persons__c
            WHERE Form_Activity__c = :testActivity.Id
        ];

        // Should be exactly 2 (John and Jane). The duplicate John should have been skipped by the duplicate check logic.
        System.assertEquals(2, allAssigned.size(), 'There should be exactly 2 assigned persons with no duplicates created');
    }

    @isTest
    static void testAddAssignedPersonsExceptions() {
        // Generate mock IDs for exception testing to bypass actual DML necessity
        Id mockActivityId = 'a00000000000001AAA'; 
        Id mockStoreId = 'a01000000000001AAA'; 

        Test.startTest();

        // 1. Missing Activity ID
        try {
            ctrl_ManageFormActivityPersonsController.addAssignedPersons(null, mockStoreId, new List<Id>{ mockStoreId });
            System.assert(false, 'Expected AuraHandledException for missing Activity ID');
        } catch (AuraHandledException e) {
            // Success: Exception caught. Message check skipped due to Salesforce "Script-thrown exception" limitation in tests.
            System.assert(e != null, 'Exception was successfully thrown');
        }

        // 2. Missing Store ID
        try {
            ctrl_ManageFormActivityPersonsController.addAssignedPersons(mockActivityId, null, new List<Id>{ mockStoreId });
            System.assert(false, 'Expected AuraHandledException for missing Store ID');
        } catch (AuraHandledException e) {
            System.assert(e != null, 'Exception was successfully thrown');
        }

        // 3. Missing/Empty Executive List
        try {
            ctrl_ManageFormActivityPersonsController.addAssignedPersons(mockActivityId, mockStoreId, new List<Id>());
            System.assert(false, 'Expected AuraHandledException for missing Executives');
        } catch (AuraHandledException e) {
            System.assert(e != null, 'Exception was successfully thrown');
        }

        Test.stopTest();
    }

    @isTest
    static void testDeleteAssignedPerson() {
        Form_Activity_Assigned_Persons__c assignedPerson = [SELECT Id FROM Form_Activity_Assigned_Persons__c LIMIT 1];

        Test.startTest();
        // 1. Successfully delete the record
        ctrl_ManageFormActivityPersonsController.deleteAssignedPerson(assignedPerson.Id);

        // 2. Trigger null ID exception
        try {
            ctrl_ManageFormActivityPersonsController.deleteAssignedPerson(null);
            System.assert(false, 'Expected AuraHandledException for missing Assigned Person ID');
        } catch (AuraHandledException e) {
            // Success: Exception caught.
            System.assert(e != null, 'Exception was successfully thrown');
        }
        Test.stopTest();

        List<Form_Activity_Assigned_Persons__c> remaining = [SELECT Id FROM Form_Activity_Assigned_Persons__c];
        System.assertEquals(0, remaining.size(), 'The assigned person should have been successfully deleted');
    }
}