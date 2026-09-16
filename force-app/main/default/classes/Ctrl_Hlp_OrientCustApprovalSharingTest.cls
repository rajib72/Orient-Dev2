@IsTest(SeeAllData=false)
private class Ctrl_Hlp_OrientCustApprovalSharingTest {

    @TestSetup
    static void setupData() {
        // Create an arbitrary user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'sharer', 
            Email = 'sharer_test@testorg.com', 
            EmailEncodingKey = 'UTF-8', 
            LastName = 'SharerTest', 
            LanguageLocaleKey = 'en_US', 
            LocaleSidKey = 'en_US', 
            ProfileId = p.Id, 
            TimeZoneSidKey = 'America/Los_Angeles', 
            UserName = 'sharer_test@testorg.com.example'
        );
        insert testUser;

        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        Orient_Customer_Change_Request__c req = new Orient_Customer_Change_Request__c(
            Orient_Customer__c = acc.Id
        );
        insert req;

        Approval_Hierarchy__c ah = new Approval_Hierarchy__c( 
            Type__c = 'Customer Profile'
        );
        insert ah;

        // Transaction 1: Has a valid request and multiple distinct participants
        Tagged_Approval_Hierarchy__c tag1 = new Tagged_Approval_Hierarchy__c(
            Customer_Change_Request__c = req.Id,
            Pending_With__c = testUser.Id,
            Submitted_By__c = UserInfo.getUserId(),
            Approval_Hierarchy__c = ah.Id
        );

        // Transaction 2: Missing the Customer Change Request lookup
        Tagged_Approval_Hierarchy__c tag2 = new Tagged_Approval_Hierarchy__c(
            Approval_Hierarchy__c = ah.Id,
            Submitted_By__c = UserInfo.getUserId()
        );

        // Transaction 3: All participants are the submitter (tests empty participant list logic)
        Tagged_Approval_Hierarchy__c tag3 = new Tagged_Approval_Hierarchy__c(
            Customer_Change_Request__c = req.Id,
            Pending_With__c = UserInfo.getUserId(),
            Submitted_By__c = UserInfo.getUserId(),
            Approval_Hierarchy__c = ah.Id
        );
        insert new List<Tagged_Approval_Hierarchy__c>{tag1, tag2, tag3};

        // Create action histories to populate the participant lists
        Approval_Action_History__c history1 = new Approval_Action_History__c(
            Approval_Transaction__c = tag1.Id,
            Action_By__c = testUser.Id,
            Assigned_To__c = UserInfo.getUserId()
        );

        Approval_Action_History__c history2 = new Approval_Action_History__c(
            Approval_Transaction__c = tag3.Id,
            Action_By__c = UserInfo.getUserId(),
            Assigned_To__c = UserInfo.getUserId()
        );
        insert new List<Approval_Action_History__c>{history1, history2};
    }

    @IsTest
    static void testSyncApprovalAccess_Standard() {
        List<Tagged_Approval_Hierarchy__c> tags = [SELECT Id FROM Tagged_Approval_Hierarchy__c];
        
        Test.startTest();
        // 1. Null fast-return
        Ctrl_Hlp_OrientCustApprovalSharing.syncApprovalAccess(null);
        
        // 2. Fire for all setups (Standard, Missing Lookup, and Empty Participants)
        for(Tagged_Approval_Hierarchy__c tag : tags) {
            Ctrl_Hlp_OrientCustApprovalSharing.syncApprovalAccess(tag.Id);
        }
        Test.stopTest();
    }
}