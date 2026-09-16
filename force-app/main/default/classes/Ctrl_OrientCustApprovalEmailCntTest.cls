@isTest(SeeAllData=false)
private class Ctrl_OrientCustApprovalEmailCntTest {
    
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Email Customer');
        insert acc;

        Store__c store = new Store__c(Name = 'Test Store', Store_Code__c = '1234');
        insert store;

        Orient_Customer_Change_Request__c req = new Orient_Customer_Change_Request__c(
            Orient_Customer__c = acc.Id,
            Approval_Store__c = store.Id,
            Location_Code__c = '1234',
            Change_Reason__c = 'Test Reason',
            Approval_Status__c = 'Pending',
            Submitted_By__c = UserInfo.getUserId(),
            Submitted_Date_Time__c = System.now()
        );
        insert req;

        Orient_Customer_Change_Item__c item1 = new Orient_Customer_Change_Item__c(
            Change_Request__c = req.Id,
            Account_Field_API__c = 'Name',
            Field_Label__c = 'Customer Name',
            Item_Approval_Status__c = 'Pending'
        );
        insert item1;

        Approval_Hierarchy__c hierarchy = new Approval_Hierarchy__c(Type__c = 'Customer Profile');
        insert hierarchy;

        Approval_Hierarchy_Level__c level = new Approval_Hierarchy_Level__c(
            Approval_Hierarchy__c = hierarchy.Id,
            Responsible_Team__c = 'Senior Store Manager'
        );
        insert level;

        Tagged_Approval_Hierarchy__c tag = new Tagged_Approval_Hierarchy__c(
            Customer_Change_Request__c = req.Id,
            Approval_Hierarchy__c = hierarchy.Id,
            Current_Approval_Level__c = level.Id,
            Pending_With__c = UserInfo.getUserId(),
            Approval_Status__c = 'Pending'
        );
        insert tag;
    }

    @isTest
    static void testEmailContentController() {
        Tagged_Approval_Hierarchy__c tag = [SELECT Id FROM Tagged_Approval_Hierarchy__c LIMIT 1];
        
        Ctrl_OrientCustomerApprovalEmailContent ctrl = new Ctrl_OrientCustomerApprovalEmailContent();
        
        Test.startTest();
        
        // 1. Test Null State (Simulates before the component ID is bound)
        ctrl.getApprovalTransaction();
        ctrl.getChangeRows();
        ctrl.getChangeRequestId();
        ctrl.getCustomerId();
        ctrl.getCustomerUrl();
        ctrl.getChangeRequestUrl();
        ctrl.getSubmittedDateTimeIST();

        // 2. Bind ID and Fire All Getters
        ctrl.taggedApprovalId = tag.Id;
        ctrl.getApprovalTransaction();
        ctrl.getChangeRows();
        ctrl.getChangeCount();
        ctrl.getCustomerName();
        ctrl.getChangeRequestName();
        ctrl.getApprovalStoreName();
        ctrl.getSubmittedByName();
        ctrl.getSubmittedDateTime();
        ctrl.getSubmittedDateTimeIST();
        ctrl.getLocationCode();
        ctrl.getChangeReason();
        ctrl.getCurrentApprovalLevel();
        ctrl.getPendingWithName();
        ctrl.getApprovalStatus();
        ctrl.getCustomerUrl();
        ctrl.getChangeRequestUrl();

        // 3. Re-call to hit the `approvalTransactionCache != null` branches
        ctrl.getApprovalTransaction();
        ctrl.getChangeRows();
        
        Test.stopTest();
    }
}