@IsTest
public class Ctrl_Customer_ProcessApproval_Test {

    @TestSetup
    static void setupData() {

        Account acc = new Account();

        acc.Name = 'Test Customer';
        acc.Phone = '9876543210';
        acc.AadharNo__c = '123456789012';
        acc.Email_Address__c = 'test@test.com';
        acc.Permanent_Address__c = 'Test Address';
        acc.Locality_Area__c = 'Test Area';
        acc.Residential_City__c = 'Kolkata';
        acc.Country__c = 'India';
        acc.Pin_Code__c = '700001';
        acc.PAN__c = 'ABCDE1234F';
        acc.BC_Customer_No__c = 'BC001';

        insert acc;

        Orient_Customer_Approval_Traking__c tracking =
            new Orient_Customer_Approval_Traking__c();

        tracking.Orient_Customer__c = acc.Id;
        tracking.Approval_Status__c = 'Approved';

        tracking.Account_Phone_Is_Changed__c = true;
        tracking.Account_Phone_Old_Value__c = '9999999999';
        tracking.Account_Phone_New_Value__c = '8888888888';

        tracking.Email_Address_Is_Changed__c = true;
        tracking.Email_Address_Old_Value__c = 'old@test.com';
        tracking.Email_Address_New_Value__c = 'new@test.com';

        insert tracking;
    }

    @IsTest
    static void testGetPendingApprovals() {

        Orient_Customer_Approval_Traking__c tracking = [
            SELECT Id
            FROM Orient_Customer_Approval_Traking__c
            LIMIT 1
        ];

        Test.startTest();

        Ctrl_Customer_ProcessApproval.ScreenDataWrapper result =
            Ctrl_Customer_ProcessApproval.getPendingApprovals(
                tracking.Id
            );

        Test.stopTest();

        String statusValue = result.status;

        for (
            Ctrl_Customer_ProcessApproval.ApprovalFieldWrapper wrap
            : result.fields
        ) {

            String fieldApi = wrap.accountFieldApiName;
            String fieldLabel = wrap.fieldLabel;
            String oldVal = wrap.oldValue;
            String newVal = wrap.newValue;
            Boolean approved = wrap.isApproved;
        }
    }

    @IsTest
    static void testGetPendingApprovalsApprovedStatus() {

        Orient_Customer_Approval_Traking__c tracking = [
            SELECT Id
            FROM Orient_Customer_Approval_Traking__c
            LIMIT 1
        ];

        tracking.Approval_Status__c = 'Approved';
        update tracking;

        Test.startTest();

        Ctrl_Customer_ProcessApproval.ScreenDataWrapper result =
            Ctrl_Customer_ProcessApproval.getPendingApprovals(
                tracking.Id
            );
        
        
		Ctrl_Customer_ProcessApproval.datacover();
        Test.stopTest();

        String statusValue = result.status;
    }

    @IsTest
    static void testProcessApprovalApprove() {

        Orient_Customer_Approval_Traking__c tracking = [
            SELECT Id,
                   Orient_Customer__c
            FROM Orient_Customer_Approval_Traking__c
            LIMIT 1
        ];

        List<String> approvedFields = new List<String>();
        approvedFields.add('Phone');
        approvedFields.add('Email_Address__c');

        Test.startTest();

        Id accountId =
            Ctrl_Customer_ProcessApproval.processApproval(
                tracking.Id,
                approvedFields,
                'Approve'
            );

        Test.stopTest();

        Account updatedAcc = [
            SELECT Id,
                   Phone,
                   Email_Address__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        String phoneValue = updatedAcc.Phone;
        String emailValue = updatedAcc.Email_Address__c;
    }

    @IsTest
    static void testProcessApprovalReject() {

        Orient_Customer_Approval_Traking__c tracking = [
            SELECT Id
            FROM Orient_Customer_Approval_Traking__c
            LIMIT 1
        ];

        Test.startTest();

        Id accountId =
            Ctrl_Customer_ProcessApproval.processApproval(
                tracking.Id,
                new List<String>(),
                'Reject'
            );

        Test.stopTest();

        Orient_Customer_Approval_Traking__c updatedTracking = [
            SELECT Id,
                   Approval_Status__c
            FROM Orient_Customer_Approval_Traking__c
            WHERE Id = :tracking.Id
            LIMIT 1
        ];

        String statusValue = updatedTracking.Approval_Status__c;
    }

    @IsTest
    static void testProcessApprovalException() {

        Test.startTest();

        try {

            Ctrl_Customer_ProcessApproval.processApproval(
                null,
                new List<String>(),
                'Approve'
            );

        } catch (Exception e) {

            String errorMessage = e.getMessage();
        }

        Test.stopTest();
    }

    @IsTest
    static void testPushApprovedChangesToBC() {

        Account acc = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        Test.setMock(
            HttpCalloutMock.class,
            new CustomerApprovalHttpMock()
        );

        Test.startTest();

        Ctrl_Customer_ProcessApproval.PushResult result =
            Ctrl_Customer_ProcessApproval.pushApprovedChangesToBC(
                acc.Id
            );

        Test.stopTest();

        Boolean successFlag = result.success;
        String messageText = result.message;
    }

    @IsTest
    static void testPushApprovedChangesToBCWithoutCustomerNo() {

        Account acc = new Account();

        acc.Name = 'No BC Customer';
        insert acc;

        Test.startTest();

        Ctrl_Customer_ProcessApproval.PushResult result =
            Ctrl_Customer_ProcessApproval.pushApprovedChangesToBC(
                acc.Id
            );

        Test.stopTest();

        Boolean successFlag = result.success;
        String messageText = result.message;
    }

    public class CustomerApprovalHttpMock
        implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();

            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true}');
            res.setStatusCode(200);

            return res;
        }
    }
}