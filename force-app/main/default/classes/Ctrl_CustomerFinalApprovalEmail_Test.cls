@isTest(SeeAllData=false)
private class Ctrl_CustomerFinalApprovalEmail_Test {
    
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
            Approval_Status__c = 'Final Approved',
            Submitted_By__c = UserInfo.getUserId(),
            Submitted_Date_Time__c = System.now(),
            Last_Action_By__c = UserInfo.getUserId(),
            Last_Action_Date_Time__c = System.now(),
            BC_Customer_No__c = 'BC-1234',
            BC_Push_Status__c = 'Success',
            BC_Push_Attempt_Count__c = 1,
            BC_Push_Date_Time__c = System.now(),
            BC_Push_Message__c = 'Pushed to BC'
        );
        insert req;

        // Create 3 items to hit all 3 UI color blocks (Approved, Returned, Pending)
        Orient_Customer_Change_Item__c item1 = new Orient_Customer_Change_Item__c(
            Change_Request__c = req.Id,
            Account_Field_API__c = 'Name',
            Field_Label__c = 'Customer Name',
            Old_Display_Value__c = 'Old Name',
            New_Display_Value__c = 'New Name',
            Item_Approval_Status__c = 'Final Approved',
            Final_Approved_By__c = UserInfo.getUserId(),
            Final_Approved_Date_Time__c = System.now(),
            BC_Push_Applicable__c = true
        );
        Orient_Customer_Change_Item__c item2 = new Orient_Customer_Change_Item__c(
            Change_Request__c = req.Id,
            Account_Field_API__c = 'Phone',
            Field_Label__c = 'Phone',
            Old_Display_Value__c = '123',
            New_Display_Value__c = '456',
            Item_Approval_Status__c = 'Returned',
            Rejected_By__c = UserInfo.getUserId(),
            Rejected_Date_Time__c = System.now(),
            Rejection_Reason__c = 'Bad Phone Number'
        );
        Orient_Customer_Change_Item__c item3 = new Orient_Customer_Change_Item__c(
            Change_Request__c = req.Id,
            Account_Field_API__c = 'Email_Address__c',
            Item_Approval_Status__c = 'Pending'
        );
        insert new List<Orient_Customer_Change_Item__c>{item1, item2, item3};
    }

    @isTest
    static void testEmailController() {
        Orient_Customer_Change_Request__c req = [SELECT Id FROM Orient_Customer_Change_Request__c LIMIT 1];
        
        Ctrl_CustomerFinalApprovalEmail ctrl = new Ctrl_CustomerFinalApprovalEmail();
        
        Test.startTest();
        
        // 1. Test Null State (Simulates before the component ID is bound)
        ctrl.getChangeRequest();
        ctrl.getChangeRows();
        ctrl.getChangeRequestUrl();

        // 2. Bind ID and Fire All Getters
        ctrl.changeRequestId = req.Id;
        ctrl.getChangeRequest();
        ctrl.getChangeRows();
        ctrl.getTotalChangeCount();
        ctrl.getApprovedCount();
        ctrl.getRejectedCount();
        ctrl.getHasRejectedChanges();
        ctrl.getHasBCDetails();
        ctrl.getCustomerName();
        ctrl.getChangeRequestName();
        ctrl.getApprovalStoreName();
        ctrl.getLocationCode();
        ctrl.getSubmittedByName();
        ctrl.getSubmittedByEmail();
        ctrl.getSubmittedDateTimeIST();
        ctrl.getFinalApprovedByName();
        ctrl.getFinalApprovedDateTimeIST();
        ctrl.getApprovalStatus();
        ctrl.getChangeReason();
        ctrl.getBCCustomerNo();
        ctrl.getBCPushStatus();
        ctrl.getBCPushDateTimeIST();
        ctrl.getBCPushMessage();
        ctrl.getCustomerUrl();
        ctrl.getChangeRequestUrl();
        
        // 3. Re-call to hit the `requestCache != null` branches
        ctrl.getChangeRequest();
        ctrl.getChangeRows();
        
        Test.stopTest();
    }
}