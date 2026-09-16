@isTest
private class Ctrl_ReassignSalesExecutiveTest {

    // ==========================================
    // TEST SETUP
    // ==========================================
    @testSetup
    static void setupData() {

        // Create Store
        Store__c storeRec = new Store__c(
            Name = 'Test Store',
            Store_Code__c = 'LOC001'
        );
        insert storeRec;

        // Create Sales Executive
        Sales_Executives__c salesExec = new Sales_Executives__c(
            Name = 'Test Executive',
            Store__c = storeRec.Id
        );
        insert salesExec;

        // Create Account
        Account acc = new Account(
            Name = 'Test Customer'
        );
        insert acc;

        // Create Showroom Visit
        Showroom_Visit__c visit = new Showroom_Visit__c(
            CUSTOMERlookup__c = acc.Id,
            Marked_As_Exited__c = true
        );
        insert visit;
    }

    // ==========================================
    // TEST getSalesExecutives
    // ==========================================
    @isTest
    static void testGetSalesExecutives() {

        User usr = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        update new User(
            Id = usr.Id,
            Location_Code__c = 'LOC001'
        );

        Test.startTest();

        Ctrl_ReassignSalesExecutive.getSalesExecutives();

        Test.stopTest();
    }

    // ==========================================
    // TEST getSalesExecutives - Blank Location
    // ==========================================
    @isTest
    static void testGetSalesExecutivesBlankLocation() {

        User usr = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        update new User(
            Id = usr.Id,
            Location_Code__c = null
        );

        Test.startTest();

        Ctrl_ReassignSalesExecutive.getSalesExecutives();

        Test.stopTest();
    }

    // ==========================================
    // TEST reassignAndLogActivity
    // ==========================================
    @isTest
    static void testReassignAndLogActivity() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Sales_Executives__c salesExec = [
            SELECT Id
            FROM Sales_Executives__c
            LIMIT 1
        ];

        Test.startTest();

        Ctrl_ReassignSalesExecutive.reassignAndLogActivity(
            visit.Id,
            salesExec.Id
        );

        Test.stopTest();
    }

    // ==========================================
    // TEST Exception Handling
    // ==========================================
    @isTest
    static void testReassignAndLogActivityException() {

        Sales_Executives__c salesExec = [
            SELECT Id
            FROM Sales_Executives__c
            LIMIT 1
        ];

        Test.startTest();

        try {
            Ctrl_ReassignSalesExecutive.reassignAndLogActivity(
                'a00000000000000AAA',
                salesExec.Id
            );
        } catch (Exception e) {

        }

        Test.stopTest();
    }
}