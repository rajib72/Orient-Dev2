@isTest
private class Ctrl_TrackerSyncTest {

    @isTest
    static void testTriggerInsertAndUpdate() {
        // ---------------------------------------------------
        // 1. TEST INSERT SCENARIO
        // ---------------------------------------------------
        
        // Create an Account that SHOULD get a Tracker
        Account accWithBC = new Account(
            Name = 'Test Account 1',
            BC_Customer_No__c = 'BC-001',
            Phone = '1234567890',
            NumberOfEmployees = 100,
            AnnualRevenue = null // Intentionally blank for now
        );
        
        // Create an Account that SHOULD NOT get a Tracker
        Account accWithoutBC = new Account(
            Name = 'Test Account 2',
            Phone = '0987654321'
        );
        
        Test.startTest();
        // This will fire the AccountTrigger -> TrackerSyncService.upsertTrackerCheckboxes()
        insert new List<Account>{accWithBC, accWithoutBC};
        
        // ---------------------------------------------------
        // VERIFY INSERT
        // ---------------------------------------------------
        List<Orient_Customer_Tracking__c> trackers = [
            SELECT Id, Orient_Customer__c, Customer_Name__c, Phone__c, Employees__c, Annual_Revenue__c 
            FROM Orient_Customer_Tracking__c
        ];
        
        
        // ---------------------------------------------------
        // 2. TEST UPDATE SCENARIO
        // ---------------------------------------------------
        
        // Let's remove the employees and add revenue to see if the Tracker updates accordingly
        accWithBC.NumberOfEmployees = null;
        accWithBC.AnnualRevenue = 50000;
        
        // This fires the AccountTrigger on Update
        update accWithBC;
        Test.stopTest();
        
        // ---------------------------------------------------
        // VERIFY UPDATE
        // ---------------------------------------------------
        Orient_Customer_Tracking__c updatedTracker = [
            SELECT Employees__c, Annual_Revenue__c 
            FROM Orient_Customer_Tracking__c 
            WHERE Orient_Customer__c = :accWithBC.Id 
            LIMIT 1
        ];
    }
    
    @isTest
    static void testBatchClass() {
        // ---------------------------------------------------
        // 3. TEST BATCH APEX SCENARIO
        // ---------------------------------------------------
        
        // Create dummy Accounts in bulk
        List<Account> accountsToInsert = new List<Account>();
        for(Integer i = 0; i < 50; i++) {
            accountsToInsert.add(new Account(
                Name = 'Batch Test Account ' + i,
                BC_Customer_No__c = 'BATCH-' + i,
                Website = 'www.test' + i + '.com'
            ));
        }
        insert accountsToInsert;
        
        // Because of our trigger, Trackers were just created for these 50 accounts.
        // To properly test the Batch class's ability to create missing records, 
        // we will delete these existing trackers first.
        delete [SELECT Id FROM Orient_Customer_Tracking__c];
        
        // Verify they are deleted
        Integer countBeforeBatch = [SELECT COUNT() FROM Orient_Customer_Tracking__c];
        System.assertEquals(0, countBeforeBatch, 'Trackers should be deleted prior to batch run.');
        
        Test.startTest();
        // Execute the Batch class
        Ctrl_TrackerSyncBatch batchJob = new Ctrl_TrackerSyncBatch();
        Database.executeBatch(batchJob, 200);
        Test.stopTest();
        
        // Verify the Batch successfully recreated all 50 trackers
        List<Orient_Customer_Tracking__c> batchTrackers = [
            SELECT Id, Customer_Name__c, Website__c 
            FROM Orient_Customer_Tracking__c
        ];
        
        System.assertEquals(50, batchTrackers.size(), 'Batch should have processed and created 50 trackers.');
    }
}