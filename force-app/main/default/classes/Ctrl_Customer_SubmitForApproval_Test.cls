@IsTest
public class Ctrl_Customer_SubmitForApproval_Test {

    @TestSetup
    static void setupData() {

        Account acc = new Account();
        acc.Name = 'Test Customer';
        acc.Phone = '9876543210';
        acc.Email_Address__c = 'test@test.com';
        acc.BC_Customer_No__c = 'BC001';
        acc.Country__c = 'India';
        acc.Permanent_Address__c = 'Old Address';
        insert acc;

        Orient_Customer_Tracking__c tracking = new Orient_Customer_Tracking__c();
        tracking.Orient_Customer__c = acc.Id;

        tracking.Phone__c = true;
        tracking.Email_Address__c = true;
        tracking.Country__c = true;
        tracking.Permanent_Address__c = true;

        insert tracking;
    }

    @IsTest
    static void testGetLockedFields() {

        Account acc = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        Test.startTest();

        List<Ctrl_Customer_SubmitForApproval.LockedFieldWrapper> result =
            Ctrl_Customer_SubmitForApproval.getLockedFields(acc.Id);

        Test.stopTest();

        for (Ctrl_Customer_SubmitForApproval.LockedFieldWrapper wrap : result) {

            String apiName = wrap.accountFieldApiName;
            String label = wrap.fieldLabel;
            String inputType = wrap.inputType;
            String oldValue = wrap.oldValue;
        }
    }

    @IsTest
    static void testSubmitApprovalRequest() {

        Account acc = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        List<Ctrl_Customer_SubmitForApproval.LockedFieldWrapper> wrapperList =
            new List<Ctrl_Customer_SubmitForApproval.LockedFieldWrapper>();

        Ctrl_Customer_SubmitForApproval.LockedFieldWrapper phoneWrap =
            new Ctrl_Customer_SubmitForApproval.LockedFieldWrapper();

        phoneWrap.accountFieldApiName = 'Phone';
        phoneWrap.fieldLabel = 'Phone';
        phoneWrap.oldValue = '9876543210';
        phoneWrap.newValue = '9999999999';
        phoneWrap.isSelected = true;

        wrapperList.add(phoneWrap);

        Ctrl_Customer_SubmitForApproval.LockedFieldWrapper emailWrap =
            new Ctrl_Customer_SubmitForApproval.LockedFieldWrapper();

        emailWrap.accountFieldApiName = 'Email_Address__c';
        emailWrap.fieldLabel = 'Email';
        emailWrap.oldValue = 'test@test.com';
        emailWrap.newValue = 'new@test.com';
        emailWrap.isSelected = true;

        wrapperList.add(emailWrap);

        String payloadJson = JSON.serialize(wrapperList);

        Test.startTest();

        String response =
            Ctrl_Customer_SubmitForApproval.submitApprovalRequest(
                acc.Id,
                payloadJson
            );

        Test.stopTest();

        List<Orient_Customer_Approval_Traking__c> approvalList = [
            SELECT Id,
                   Orient_Customer__c,
                   Approval_Summary__c
            FROM Orient_Customer_Approval_Traking__c
        ];

        for (Orient_Customer_Approval_Traking__c rec : approvalList) {

            Id recId = rec.Id;
            Id accId = rec.Orient_Customer__c;
            String summary = rec.Approval_Summary__c;
        }
    }

    @IsTest
    static void testSubmitApprovalRequestNoSelection() {

        Account acc = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        List<Ctrl_Customer_SubmitForApproval.LockedFieldWrapper> wrapperList =
            new List<Ctrl_Customer_SubmitForApproval.LockedFieldWrapper>();

        Ctrl_Customer_SubmitForApproval.LockedFieldWrapper phoneWrap =
            new Ctrl_Customer_SubmitForApproval.LockedFieldWrapper();

        phoneWrap.accountFieldApiName = 'Phone';
        phoneWrap.fieldLabel = 'Phone';
        phoneWrap.oldValue = '9876543210';
        phoneWrap.newValue = '';
        phoneWrap.isSelected = false;

        wrapperList.add(phoneWrap);

        String payloadJson = JSON.serialize(wrapperList);

        Test.startTest();

        String response =
            Ctrl_Customer_SubmitForApproval.submitApprovalRequest(
                acc.Id,
                payloadJson
            );

        Test.stopTest();
    }

    @IsTest
    static void testGetLockedFieldsWithoutBCCustomerNo() {

        Account acc = new Account();
        acc.Name = 'No BC Customer';
        insert acc;

        Orient_Customer_Tracking__c tracking = new Orient_Customer_Tracking__c();
        tracking.Orient_Customer__c = acc.Id;
        tracking.Phone__c = true;

        insert tracking;

        Test.startTest();

        try {

            Ctrl_Customer_SubmitForApproval.getLockedFields(acc.Id);

        } catch (Exception e) {

            String msg = e.getMessage();
        }

        Test.stopTest();
    }

    @IsTest
    static void testSubmitApprovalRequestException() {

        Account acc = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        Test.startTest();

        try {

            Ctrl_Customer_SubmitForApproval.submitApprovalRequest(
                acc.Id,
                'Invalid Json'
            );

        } catch (Exception e) {

            String err = e.getMessage();
        }

        Test.stopTest();
    }
}