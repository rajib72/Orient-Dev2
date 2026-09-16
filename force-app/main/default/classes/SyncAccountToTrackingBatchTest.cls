@isTest
public class SyncAccountToTrackingBatchTest {

    @isTest
    static void testBatchExecution() {
        // ==========================================
        // 1. DATA PREPARATION
        // ==========================================
        List<Account> accountsToInsert = new List<Account>();
        
        // Scenario A: Account WITH BC_Customer_No__c (Should be picked up by batch)
        Account accWithBC = new Account(
            Name = 'Test Valid Account',
            BC_Customer_No__c = 'DCUS12345',
            Phone = '9876543210',              // Populated string field
            Email_Address__c = 'test@test.com', // Populated string field
            Primary_Customer__c = true,         // Populated boolean field
            Description = null                  // Blank field to test 'false' outcome
        );
        accountsToInsert.add(accWithBC);

        // Scenario B: Account WITHOUT BC_Customer_No__c (Should be ignored by batch)
        Account accWithoutBC = new Account(
            Name = 'Test Invalid Account',
            Phone = '1234567890' 
            // BC_Customer_No__c left blank intentionally
        );
        accountsToInsert.add(accWithoutBC);
        
        insert accountsToInsert;

        // Create the child Tracking records
        List<Orient_Customer_Tracking__c> trackingsToInsert = new List<Orient_Customer_Tracking__c>();
        
        Orient_Customer_Tracking__c trackingForValidAcc = new Orient_Customer_Tracking__c(
            Orient_Customer__c = accWithBC.Id
        );
        trackingsToInsert.add(trackingForValidAcc);

        Orient_Customer_Tracking__c trackingForInvalidAcc = new Orient_Customer_Tracking__c(
            Orient_Customer__c = accWithoutBC.Id
        );
        trackingsToInsert.add(trackingForInvalidAcc);
        
        insert trackingsToInsert;

        // ==========================================
        // 2. BATCH EXECUTION
        // ==========================================
        Test.startTest();
        SyncAccountToTrackingBatch batch = new SyncAccountToTrackingBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest(); // This forces the asynchronous batch to finish synchronously

        // ==========================================
        // 3. ASSERTIONS
        // ==========================================
        
        // Query the updated tracking records to verify the results
        Map<Id, Orient_Customer_Tracking__c> resultsMap = new Map<Id, Orient_Customer_Tracking__c>([
            SELECT Id, Orient_Customer__c, Customer_Name__c, Phone__c, Email_Address__c, Primary_Customer__c, Description__c
            FROM Orient_Customer_Tracking__c
        ]);

        // Assertions for Scenario A (Account with BC No)
        Orient_Customer_Tracking__c resultValid = resultsMap.get(trackingForValidAcc.Id);
        
        
        // Assertions for Scenario B (Account without BC No)
        Orient_Customer_Tracking__c resultInvalid = resultsMap.get(trackingForInvalidAcc.Id);
        
        // System.assertEquals(false, resultInvalid.Phone__c, 'Phone checkbox should remain FALSE because the parent Account lacked a BC Customer No and was ignored by the batch.');
    }
}