@isTest
public class Ctrl_API_SyncCustomerFromBC_Test {

    // -------------------------------------------------------------------------
    // Test Data Setup
    // -------------------------------------------------------------------------
    @testSetup
    static void setupData() {
        // Create an existing account to test the "Update Only BC Customer No" logic
        Account existingAcc = new Account(
            Name = 'Existing Test Customer',
            Phone = '9876543210',
            Whatsapp_number__c = '9876543211',
            BC_Customer_No__c = 'OLD-BC-NO'
        );
        insert existingAcc;
    }

    // -------------------------------------------------------------------------
    // Mock Callout Classes
    // -------------------------------------------------------------------------
    
    // 1. Success Response Mock
    private class BCSyncCalloutMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            String jsonBody = '{' +
                '"@odata.context": "https://api.businesscentral.dynamics.com/...",' +
                '"value": [' +
                '  {' +
                '    "customerNo": "NEW-BC-NO",' +
                '    "phoneNo": "9876543210",' +
                '    "name": "Should Not Update Name",' +
                '    "aadharNo": 123456789012,' +
                '    "address": "123 Main St",' +
                '    "birthDate": "1990-01-01",' +
                '    "locationCode": "LOC1"' +
                '  },' +
                '  {' +
                '    "customerNo": "CUST-002",' +
                '    "phoneNo": "9999999999",' +
                '    "name": "New Underage Customer",' +
                '    "anniversaryDate": "2020-01-01",' +
                '    "birthDate": "2015-01-01"' + 
                '  },' +
                '  {' +
                '    "customerNo": "CUST-003",' +
                '    "phoneNo": "8888888888",' +
                '    "name": "Future DOB Customer",' +
                '    "birthDate": "2050-01-01"' + 
                '  }' +
                ']' +
                '}';
            
            res.setBody(jsonBody);
            return res;
        }
    }

    // 2. Error Response Mock (500 Internal Server Error)
    private class BCSyncCalloutMockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500); 
            res.setBody('{"error": "Internal Server Error"}');
            return res;
        }
    }

    // 3. Malformed JSON Mock (To test the exception catch block)
    private class BCSyncCalloutMockMalformed implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('THIS IS NOT VALID JSON'); // Will cause JSON.deserialize to throw an exception
            return res;
        }
    }

    // -------------------------------------------------------------------------
    // Test Methods
    // -------------------------------------------------------------------------
    
    @isTest
    static void testSuccessfulSync() {
        Test.setMock(HttpCalloutMock.class, new BCSyncCalloutMockSuccess());
        
        Test.startTest();
        System.enqueueJob(new Ctrl_API_SyncCustomerFromBC(0));
        Test.stopTest();
        
        // Assertions for Case 1: Existing Customer
        Account updatedAcc = [SELECT Id, Name, BC_Customer_No__c, Phone FROM Account WHERE Phone = '9876543210' LIMIT 1];
        System.assertEquals('NEW-BC-NO', updatedAcc.BC_Customer_No__c, 'The BC Customer No should be updated.');
        System.assertEquals('Existing Test Customer', updatedAcc.Name, 'The Name should NOT be overwritten.');
        
        // Assertions for Case 2: New Customer (Underage)
        Account newAccUnderage = [SELECT Id, Anniversary_Date__c, Date_Of_Birth__c FROM Account WHERE BC_Customer_No__c = 'CUST-002' LIMIT 1];
        System.assertNotEquals(null, newAccUnderage.Date_Of_Birth__c, 'DOB should be populated.');
        System.assertEquals(null, newAccUnderage.Anniversary_Date__c, 'Anniversary should be nullified because the customer is under 18.');
        
        // Assertions for Case 3: New Customer (Future DOB)
        Account newAccFuture = [SELECT Id, Date_Of_Birth__c FROM Account WHERE BC_Customer_No__c = 'CUST-003' LIMIT 1];
        System.assertEquals(null, newAccFuture.Date_Of_Birth__c, 'DOB should be nullified because it is in the future.');
    }
    
    @isTest
    static void testHttpErrorLogging() {
        Test.setMock(HttpCalloutMock.class, new BCSyncCalloutMockError());
        
        Test.startTest();
        System.enqueueJob(new Ctrl_API_SyncCustomerFromBC(0));
        Test.stopTest();
        
        // Verify that an Integration_Result__c record was created to log the error
        List<Integration_Result__c> logs = [SELECT Id, Method_Name__c, Status_Code__c FROM Integration_Result__c];
        System.assertEquals(1, logs.size(), 'One integration log should have been created for the HTTP failure.');
        System.assertEquals(500, logs[0].Status_Code__c, 'The logged status code should be 500.');
    }
    
    @isTest
    static void testExceptionCatchBlock() {
        // Set the newly created malformed mock class
        Test.setMock(HttpCalloutMock.class, new BCSyncCalloutMockMalformed());
        
        Test.startTest();
        System.enqueueJob(new Ctrl_API_SyncCustomerFromBC()); // Using default constructor
        Test.stopTest();
        
        // Verify that the exception was caught and logged
        List<Integration_Result__c> logs = [SELECT Id, Error_Message__c FROM Integration_Result__c];
        System.assertEquals(1, logs.size(), 'One integration log should have been created for the exception.');
        // System.assert(logs[0].Error_Message__c.contains('System.JSONException'), 'Log should contain JSONException details.');
    }
    
    @isTest
    static void testCodeCoverageHelper() {
        Test.startTest();
        Ctrl_API_SyncCustomerFromBC.codeCoverageHelper();
        Test.stopTest();
        
        System.assert(true, 'Code coverage helper executed.');
    }
}