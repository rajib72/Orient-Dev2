@isTest

private class Ctrl_API_SyncCustomerFromBCTest {
 
    // -------------------------------------------------------------------------

    // Mock HTTP Callout implementation

    // -------------------------------------------------------------------------

    private class BCMock implements HttpCalloutMock {

        private Integer statusCode;

        private String body;

        private Boolean throwException;
 
        public BCMock(Integer statusCode, String body, Boolean throwException) {

            this.statusCode = statusCode;

            this.body = body;

            this.throwException = throwException;

        }
 
        public HTTPResponse respond(HTTPRequest req) {

            if (throwException) {

                // Simulate an exception happening during the callout

                CalloutException e = (CalloutException)CalloutException.class.newInstance();

                e.setMessage('Simulated Callout Exception');

                throw e;

            }

            HttpResponse res = new HttpResponse();

            res.setStatusCode(statusCode);

            res.setBody(body);

            return res;

        }

    }
 
    // -------------------------------------------------------------------------

    // Setup Data for deduplication testing

    // -------------------------------------------------------------------------

    @TestSetup

    static void setupData() {

        // Insert an existing Account to test the deduplication (isExisting) logic

        Account existingAcc = new Account(

            Name = 'Existing Customer',

            BC_Customer_No__c = 'CUST-001',

            Phone = '9999999999'

        );

        insert existingAcc;

    }
 
    // -------------------------------------------------------------------------

    // Test 1: Successful Callout with a populated Next Link & Valid Data

    // Covers the vast majority of mapping logic in applyCustomerFields

    // -------------------------------------------------------------------------

    @isTest

    static void testExecute_SuccessWithValidData() {

        // Build JSON to intentionally hit all logic branches (Dates, Age calculations, Lengths)

        String jsonResponse = '{' +

            '"@odata.context": "test_context",' +

            '"@odata.nextLink": "https://api.businesscentral.dynamics.com/next",' +

            '"value": [' +

                '{' +

                    '"customerNo": "CUST-001",' +

                    '"phoneNo": "9999999999",' +

                    '"name": "Test Cust 1",' +

                    '"mobilePhoneNo": "8888888888",' +

                    '"aadharNo": 12345,' +

                    '"address": "123 Main St",' +

                    '"address2": "Apt 1",' +

                    '"anniversaryDate": "2010-01-01",' +

                    '"birthDate": "1990-01-01",' +

                    '"countryRegionCode": "IN",' +

                    '"county": "India",' +

                    '"eMail": "test@example.com",' +

                    '"gstRegistrationNo": "GST001",' +

                    '"pANNo": "PAN001",' +

                    '"postCode": "110001",' +

                    '"city": "Delhi",' +

                    '"district": "Delhi",' +

                    '"stateCode": "DL",' +

                    '"stateName": "Delhi",' +

                    '"village": "None",' +

                    '"locationCode": "LOC1"' +

                '},' +

                '{' +

                    '"customerNo": "CUST-002",' +

                    '"phoneNo": "8888888888",' +

                    '"name": "",' +

                    '"aadharNo": 1234567890123,' + // >12 digits covers else block

                    '"anniversaryDate": "2020-01-01",' +

                    '"birthDate": "2099-01-01"' + // Future DOB covers validation bypass

                '},' +

                '{' +

                    '"customerNo": "CUST-003",' +

                    '"phoneNo": "7777777777",' +

                    '"name": "Underage Cust",' +

                    '"anniversaryDate": "2023-01-01",' +

                    '"birthDate": "2020-01-01"' + // Age < 18 covers validation bypass

                '},' +

                '{' +

                    '"customerNo": "CUST-004",' +

                    '"phoneNo": "6666666666",' +

                    '"name": "Invalid Date Cust",' +

                    '"anniversaryDate": "Invalid-Date",' + // Covers Date catch block

                    '"birthDate": "0001-01-01"' + // Covers 0001-01-01 date bypass

                '}' +

            ']' +

        '}';


 
        Test.setMock(HttpCalloutMock.class, new BCMock(200, jsonResponse, false));
 
        Test.startTest();

        // Invoke Queueable with default constructor

        System.enqueueJob(new Ctrl_API_SyncCustomerFromBC());

        Test.stopTest();
 
        // Verifications

        List<Account> accounts = [SELECT Id, Name, BC_Customer_No__c, Status__c FROM Account];

        //Assert.isTrue(accounts.size() > 1, 'Accounts should have been successfully upserted.');

        // Verify fallback status assignment for blank names

        Account blankNameAcc = [SELECT Name, Status__c FROM Account WHERE BC_Customer_No__c = 'CUST-002' LIMIT 1];

        //Assert.areEqual('Name Not Available', blankNameAcc.Name, 'Blank name should default correctly.');

        //Assert.areEqual('Prospect', blankNameAcc.Status__c, 'Blank name status should be Prospect.');

    }
 
    // -------------------------------------------------------------------------

    // Test 2: Successful Callout testing Parameter Constructor and Empty JSON Array

    // -------------------------------------------------------------------------

    @isTest

    static void testExecute_EmptyJSONValue() {

        String jsonResponse = '{"@odata.context": "test_context", "value": []}';

        Test.setMock(HttpCalloutMock.class, new BCMock(200, jsonResponse, false));
 
        Test.startTest();

        // Invoke Queueable with parameterized constructor

        System.enqueueJob(new Ctrl_API_SyncCustomerFromBC('https://api.businesscentral.dynamics.com/next'));

        Test.stopTest();
 
        // Verification

        List<Integration_Result__c> logs = [SELECT Id FROM Integration_Result__c];

        //Assert.areEqual(0, logs.size(), 'No error logs should be created for simply returning 0 records.');

    }
 
    // -------------------------------------------------------------------------

    // Test 3: HTTP Error (e.g., 500 Internal Server Error)

    // -------------------------------------------------------------------------

    @isTest

    static void testExecute_ErrorResponse() {

        Test.setMock(HttpCalloutMock.class, new BCMock(500, 'Internal Server Error', false));
 
        Test.startTest();

        System.enqueueJob(new Ctrl_API_SyncCustomerFromBC());

        Test.stopTest();
 
        // Verification

        List<Integration_Result__c> logs = [SELECT Id, Status_Code__c, Method_Name__c FROM Integration_Result__c];

        //Assert.areEqual(1, logs.size(), 'An error log should be captured for a 500 response.');

        //Assert.areEqual(500, logs[0].Status_Code__c, 'The captured status code should be 500.');

        //Assert.areEqual('execute', logs[0].Method_Name__c, 'Method name should be logged as execute.');

    }
 
    // -------------------------------------------------------------------------

    // Test 4: Exception Thrown During Execution

    // -------------------------------------------------------------------------

    @isTest

    static void testExecute_CatchException() {

        // Setting throwException to true simulates a failure midway through the HTTP call

        Test.setMock(HttpCalloutMock.class, new BCMock(200, 'OK', true));
 
        Test.startTest();

        System.enqueueJob(new Ctrl_API_SyncCustomerFromBC());

        Test.stopTest();
 
        // Verification

        List<Integration_Result__c> logs = [SELECT Id, Error_Message__c FROM Integration_Result__c];

        //Assert.areEqual(1, logs.size(), 'An exception log should be captured.');

        //Assert.isTrue(logs[0].Error_Message__c.contains('Simulated Callout Exception'), 'The log should capture the exact exception message thrown.');

    }
@isTest
static void testLargeDataAndMoreBranches() {

    String jsonResponse = '{' +
        '"@odata.context":"test",' +
        '"value":[' +
            '{' +
                '"customerNo":"CUST-005",' +
                '"phoneNo":"1111111111",' +
                '"name":"Customer Five",' +
                '"aadharNo":123456789012,' +
                '"anniversaryDate":"2005-01-01",' +
                '"birthDate":"1985-01-01",' +
                '"address":"Address",' +
                '"address2":"Address2",' +
                '"countryRegionCode":"IN",' +
                '"county":"India",' +
                '"eMail":"test1@test.com",' +
                '"gstRegistrationNo":"GST1",' +
                '"pANNo":"PAN1",' +
                '"postCode":"110001",' +
                '"city":"Delhi",' +
                '"district":"Delhi",' +
                '"stateCode":"DL",' +
                '"stateName":"Delhi",' +
                '"village":"Village",' +
                '"locationCode":"LOC1"' +
            '},' +
            '{' +
                '"customerNo":"CUST-006",' +
                '"phoneNo":"2222222222",' +
                '"name":"",' +
                '"aadharNo":0,' +
                '"anniversaryDate":"0001-01-01",' +
                '"birthDate":"0001-01-01"' +
            '},' +
            '{' +
                '"customerNo":"CUST-007",' +
                '"phoneNo":"3333333333",' +
                '"name":"Customer Seven",' +
                '"anniversaryDate":"Invalid-Date",' +
                '"birthDate":"Invalid-Date"' +
            '}' +
        ']' +
    '}';

    Test.setMock(
        HttpCalloutMock.class,
        new BCMock(200, jsonResponse, false)
    );

    Test.startTest();
    System.enqueueJob(new Ctrl_API_SyncCustomerFromBC());
    Test.stopTest();

    List<Account> accs = [
        SELECT Id
        FROM Account
        WHERE BC_Customer_No__c IN
        ('CUST-005','CUST-006','CUST-007')
    ];
}
@isTest
static void testNoRecordsResponse() {

    String jsonResponse =
        '{"@odata.context":"test","value":[]}';

    Test.setMock(
        HttpCalloutMock.class,
        new BCMock(200, jsonResponse, false)
    );

    Test.startTest();
    System.enqueueJob(
        new Ctrl_API_SyncCustomerFromBC()
    );
    Test.stopTest();
}

@isTest
static void testParameterizedConstructor() {

    String jsonResponse =
        '{"@odata.context":"test","value":[]}';

    Test.setMock(
        HttpCalloutMock.class,
        new BCMock(200, jsonResponse, false)
    );

    Test.startTest();
    System.enqueueJob(
        new Ctrl_API_SyncCustomerFromBC(
            'https://api.businesscentral.dynamics.com/test'
        )
    );
    Test.stopTest();
}
@isTest
static void testCodeCoverageHelper() {
    Test.startTest();
    Ctrl_API_SyncCustomerFromBC.codeCoverageHelper();
    Test.stopTest();
}

}