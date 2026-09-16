@isTest
public class OrientSalesExecutiveSyncServiceTest {

    /* ================= MOCK SUCCESS ================= */

    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            String body =
            '{' +
                '"value": [' +
                    '{' +
                        '"code":"SE001",' +
                        '"name":"John Doe",' +
                        '"locationCode":"LOC001",' +
                        '"eMail":"john@test.com",' +
                        '"eMail2":"john2@test.com",' +
                        '"avgEstimatedValueLCY":100.50,' +
                        '"avgCalcdCurrentValueLCY":200.75,' +
                        '"blocked":false,' +
                        '"calcdCurrentValueLCY":150.25,' +
                        '"commission":10.5,' +
                        '"costLCY":50.5,' +
                        '"coupledToDataverse":true,' +
                        '"durationMin":15,' +
                        '"estimatedValueLCY":300.50,' +
                        '"globalDimension1Code":"GD1",' +
                        '"globalDimension2Code":"GD2",' +
                        '"jobTitle":"Manager",' +
                        '"nextTaskDate":"2026-01-01",' +
                        '"noOfInteractions":5,' +
                        '"noOfOpportunities":2,' +
                        '"opportunityEntryExists":true,' +
                        '"phoneNo":"9999999999",' +
                        '"privacyBlocked":false,' +
                        '"searchEMail":"search@test.com",' +
                        '"taskEntryExists":true' +
                    '},' +
                    '{' +
                        '"code":"SE002",' +
                        '"name":"Jane Smith",' +
                        '"locationCode":"LOC002"' +
                    '}' +
                ']' +
            '}';

            res.setBody(body);
            return res;
        }
    }

    /* ================= MOCK FAILURE ================= */

    private class FailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Server Error');

            return res;
        }
    }

    /* ================= MOCK EMPTY ================= */

    private class EmptyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"value":[]}');

            return res;
        }
    }

    /* ================= TEST SUCCESS ================= */

    @isTest
    static void testSyncSalesExecutives() {

        Store__c st = new Store__c(
            Name = 'Main Store',
            Store_Code__c = 'LOC001'
        );
        insert st;

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();

        OrientSalesExecutiveSyncService.syncSalesExecutives();

        Test.stopTest();
    }

    /* ================= TEST EMPTY ================= */

    @isTest
    static void testSyncSalesExecutivesEmpty() {

        Test.setMock(HttpCalloutMock.class, new EmptyMock());

        Test.startTest();

        OrientSalesExecutiveSyncService.syncSalesExecutives();

        Test.stopTest();
    }

    /* ================= TEST FAILURE ================= */

    @isTest
    static void testSyncSalesExecutivesFailure() {

        Test.setMock(HttpCalloutMock.class, new FailureMock());

        Test.startTest();

        try {
            OrientSalesExecutiveSyncService.syncSalesExecutives();
        } catch (Exception e) {

        }

        Test.stopTest();
    }

    /* ================= TEST INVALID DATE ================= */

    private class InvalidDateMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            String body =
            '{' +
                '"value": [' +
                    '{' +
                        '"code":"SE003",' +
                        '"name":"Invalid Date User",' +
                        '"locationCode":"LOC003",' +
                        '"nextTaskDate":"0001-01-01"' +
                    '}' +
                ']' +
            '}';

            res.setBody(body);

            return res;
        }
    }

    @isTest
    static void testInvalidDateHandling() {

        Test.setMock(HttpCalloutMock.class, new InvalidDateMock());

        Test.startTest();

        OrientSalesExecutiveSyncService.syncSalesExecutives();

        Test.stopTest();
    }

    /* ================= TEST NULL VALUES ================= */

    private class NullValueMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            String body =
            '{' +
                '"value": [' +
                    '{' +
                        '"code":"SE004",' +
                        '"name":"Null User",' +
                        '"locationCode":null,' +
                        '"blocked":null,' +
                        '"durationMin":null' +
                    '}' +
                ']' +
            '}';

            res.setBody(body);

            return res;
        }
    }

    @isTest
    static void testNullValuesHandling() {

        Test.setMock(HttpCalloutMock.class, new NullValueMock());

        Test.startTest();

        OrientSalesExecutiveSyncService.syncSalesExecutives();

        Test.stopTest();
    }
}