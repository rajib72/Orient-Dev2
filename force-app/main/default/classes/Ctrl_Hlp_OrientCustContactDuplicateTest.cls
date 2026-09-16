@IsTest(SeeAllData=false)
private class Ctrl_Hlp_OrientCustContactDuplicateTest {

    @TestSetup
    static void setupData() {
        // Create duplicate dummy accounts to trigger all the matching permutations:
        // 1: Matches Phone and Whatsapp
        // 2: Matches Phone only
        // 3: Matches Whatsapp only
        // 4: Matches Phone again (Triggers the 'duplicateKeys' set collision logic)
        Account dup1 = new Account(Name='Dup1', Phone='9999999999', Whatsapp_number__c='8888888888');
        Account dup2 = new Account(Name='Dup2', Phone='9999999999', Whatsapp_number__c='1111111111');
        Account dup3 = new Account(Name='Dup3', Phone='1111111111', Whatsapp_number__c='8888888888');
        Account dup4 = new Account(Name='Dup4', Phone='9999999999', Whatsapp_number__c='2222222222');
        insert new List<Account>{dup1, dup2, dup3, dup4};

        Account currentAcc = new Account(Name='Current');
        insert currentAcc;

        Orient_Customer_Change_Request__c req = new Orient_Customer_Change_Request__c(Orient_Customer__c = currentAcc.Id);
        insert req;
        
        // Setup pending contact change items to trigger the scanner
        Orient_Customer_Change_Item__c item1 = new Orient_Customer_Change_Item__c(
            Change_Request__c = req.Id,
            Account_Field_API__c = 'Phone',
            New_Value__c = '9999999999',
            Item_Approval_Status__c = 'Pending'
        );
        Orient_Customer_Change_Item__c item2 = new Orient_Customer_Change_Item__c(
            Change_Request__c = req.Id,
            Account_Field_API__c = 'Whatsapp_number__c',
            New_Value__c = '8888888888',
            Item_Approval_Status__c = 'Pending'
        );
        insert new List<Orient_Customer_Change_Item__c>{item1, item2};
    }

    @IsTest
    static void testLookupByRequest_Null() {
        Test.startTest();
        Ctrl_Hlp_OrientCustContactDuplicate.lookupByRequest(null);
        Test.stopTest();
    }

    @IsTest
    static void testLookupByRequest_NoPendingItems() {
        Account acc = new Account(Name='No Pending');
        insert acc;
        Orient_Customer_Change_Request__c req = new Orient_Customer_Change_Request__c(Orient_Customer__c = acc.Id);
        insert req;

        Test.startTest();
        Ctrl_Hlp_OrientCustContactDuplicate.lookupByRequest(req.Id);
        Test.stopTest();
    }

    @IsTest
    static void testLookupByRequest_DuplicatesFound() {
        Orient_Customer_Change_Request__c req = [SELECT Id FROM Orient_Customer_Change_Request__c LIMIT 1];
        
        Test.startTest();
        // This will find the duplicates setup above and trigger the matched paths
        Ctrl_Hlp_OrientCustContactDuplicate.lookupByRequest(req.Id);
        
        // This forces the AuraHandledException to throw because duplicates were found
        try {
            Ctrl_Hlp_OrientCustContactDuplicate.assertNoDuplicateForPendingContactNumbers(req.Id);
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    @IsTest
    static void testLookupByRequest_InvalidLength() {
        Orient_Customer_Change_Request__c req = [SELECT Id FROM Orient_Customer_Change_Request__c LIMIT 1];
        Orient_Customer_Change_Item__c item = [SELECT Id FROM Orient_Customer_Change_Item__c WHERE Account_Field_API__c='Phone' LIMIT 1];
        item.New_Value__c = '123'; // Too short
        update item;

        Test.startTest();
        Ctrl_Hlp_OrientCustContactDuplicate.lookupByRequest(req.Id);
        Test.stopTest();
    }
    
    @IsTest
    static void testLookupByRequest_BlankNumber() {
        Orient_Customer_Change_Request__c req = [SELECT Id FROM Orient_Customer_Change_Request__c LIMIT 1];
        Orient_Customer_Change_Item__c item = [SELECT Id FROM Orient_Customer_Change_Item__c WHERE Account_Field_API__c='Phone' LIMIT 1];
        item.New_Value__c = ''; // Blank
        update item;

        Test.startTest();
        Ctrl_Hlp_OrientCustContactDuplicate.lookupByRequest(req.Id);
        Test.stopTest();
    }

    @IsTest
    static void testLookupByRequest_NoDuplicatesFound() {
        Orient_Customer_Change_Request__c req = [SELECT Id FROM Orient_Customer_Change_Request__c LIMIT 1];
        List<Orient_Customer_Change_Item__c> items = [SELECT Id FROM Orient_Customer_Change_Item__c WHERE Change_Request__c = :req.Id];
        
        for (Orient_Customer_Change_Item__c item : items) {
            item.New_Value__c = '7777777777'; // A number that does not exist in the system
        }
        update items;

        Test.startTest();
        Ctrl_Hlp_OrientCustContactDuplicate.lookupByRequest(req.Id);
        Ctrl_Hlp_OrientCustContactDuplicate.assertNoDuplicateForPendingContactNumbers(req.Id); // Should NOT throw exception
        Test.stopTest();
    }
    
    @IsTest
    static void testLookupByRequest_OnlyPhoneNoDupes() {
        Orient_Customer_Change_Request__c req = [SELECT Id FROM Orient_Customer_Change_Request__c LIMIT 1];
        
        // Remove the Whatsapp item so only phone is evaluated
        Orient_Customer_Change_Item__c item = [SELECT Id FROM Orient_Customer_Change_Item__c WHERE Account_Field_API__c='Whatsapp_number__c' LIMIT 1];
        delete item;
        
        Orient_Customer_Change_Item__c phoneItem = [SELECT Id FROM Orient_Customer_Change_Item__c WHERE Account_Field_API__c='Phone' LIMIT 1];
        phoneItem.New_Value__c = '7777777777';
        update phoneItem;

        Test.startTest();
        Ctrl_Hlp_OrientCustContactDuplicate.lookupByRequest(req.Id);
        Test.stopTest();
    }
    
    @IsTest
    static void testLookupByRequest_OnlyWhatsappNoDupes() {
        Orient_Customer_Change_Request__c req = [SELECT Id FROM Orient_Customer_Change_Request__c LIMIT 1];
        
        // Remove the Phone item so only whatsapp is evaluated
        Orient_Customer_Change_Item__c item = [SELECT Id FROM Orient_Customer_Change_Item__c WHERE Account_Field_API__c='Phone' LIMIT 1];
        delete item;
        
        Orient_Customer_Change_Item__c wpItem = [SELECT Id FROM Orient_Customer_Change_Item__c WHERE Account_Field_API__c='Whatsapp_number__c' LIMIT 1];
        wpItem.New_Value__c = '7777777777';
        update wpItem;

        Test.startTest();
        Ctrl_Hlp_OrientCustContactDuplicate.lookupByRequest(req.Id);
        Test.stopTest();
    }
}