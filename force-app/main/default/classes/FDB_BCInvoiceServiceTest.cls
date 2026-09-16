@isTest
private class FDB_BCInvoiceServiceTest {

    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public String responseBody;
        public Integer statusCode;

        public MockHttpResponseGenerator(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            res.setStatusCode(statusCode);
            return res;
        }
    }

    @testSetup
    static void setup() {
        Account acc = new Account(
            Name = 'Test Customer',
            BC_Customer_No__c = 'CUST-001',
            Phone = '9876543210'
        );
        insert acc;

        Account accNoBc = new Account(
            Name = 'Test Customer No BC',
            Phone = '9876543211'
        );
        insert accNoBc;
    }

    @isTest
    static void testFetchLatest() {
        Account acc = [SELECT Id FROM Account WHERE BC_Customer_No__c = 'CUST-001' LIMIT 1];

        String jsonResponse = '{"value": [{"documentNo": "INV-001", "preDocumentNo": "PRE-001", "date": "2023-10-15", "customerCode": "CUST-001", "customerName": "Test Customer", "amountToCustomer": 150.00, "locationName": "Store A", "salespersonName": "Sales Rep"}]}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, jsonResponse));

        Test.startTest();
        List<FDB_BCInvoiceService.Invoice> invoices = FDB_BCInvoiceService.fetch(acc.Id, FDB_BCInvoiceService.SELECTION_LATEST, null, null);
        Test.stopTest();

        System.assertEquals(1, invoices.size());
        System.assertEquals('INV-001', invoices[0].documentNo);
        System.assertEquals(150.00, invoices[0].amount);
    }

    @isTest
    static void testFetchLast12() {
        Account acc = [SELECT Id FROM Account WHERE BC_Customer_No__c = 'CUST-001' LIMIT 1];

        String jsonResponse = '{"value": [{"documentNo": "INV-002", "finalAmountToCustomer": 200.50}]}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, jsonResponse));

        Test.startTest();
        List<FDB_BCInvoiceService.Invoice> invoices = FDB_BCInvoiceService.fetch(acc.Id, FDB_BCInvoiceService.SELECTION_LAST_12, null, null);
        Test.stopTest();

        System.assertEquals(1, invoices.size());
        System.assertEquals('INV-002', invoices[0].documentNo);
        System.assertEquals(200.50, invoices[0].amount);
    }

    @isTest
    static void testFetchSpecificDates() {
        Account acc = [SELECT Id FROM Account WHERE BC_Customer_No__c = 'CUST-001' LIMIT 1];

        String jsonResponse = '{"value": []}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, jsonResponse));

        Test.startTest();
        List<FDB_BCInvoiceService.Invoice> invoices = FDB_BCInvoiceService.fetch(acc.Id, FDB_BCInvoiceService.SELECTION_SPECIFIC, '2023-01-01', '2023-12-31');
        Test.stopTest();

        System.assertEquals(0, invoices.size());
    }

    @isTest
    static void testFetchSpecificDatesInvalidRange() {
        Account acc = [SELECT Id FROM Account WHERE BC_Customer_No__c = 'CUST-001' LIMIT 1];

        Test.startTest();
        try {
            FDB_BCInvoiceService.fetch(acc.Id, FDB_BCInvoiceService.SELECTION_SPECIFIC, '2023-12-31', '2023-01-01');
            System.assert(false, 'Expected InvoiceException');
        } catch (FDB_BCInvoiceService.InvoiceException e) {
            System.assert(e.getMessage().contains('on or before'));
        }
        Test.stopTest();
    }

    @isTest
    static void testFetchNoCustomerCode() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Customer No BC' LIMIT 1];

        Test.startTest();
        try {
            FDB_BCInvoiceService.fetch(acc.Id, FDB_BCInvoiceService.SELECTION_LATEST, null, null);
            System.assert(false, 'Expected InvoiceException');
        } catch (FDB_BCInvoiceService.InvoiceException e) {
            System.assert(e.getMessage().contains('No billing account'));
        }
        Test.stopTest();
    }

    @isTest
    static void testFetchCalloutError() {
        Account acc = [SELECT Id FROM Account WHERE BC_Customer_No__c = 'CUST-001' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        try {
            FDB_BCInvoiceService.fetch(acc.Id, FDB_BCInvoiceService.SELECTION_LATEST, null, null);
            System.assert(false, 'Expected InvoiceException');
        } catch (FDB_BCInvoiceService.InvoiceException e) {
            System.assert(e.getMessage().contains('reach the billing system'));
        }
        Test.stopTest();
    }
}