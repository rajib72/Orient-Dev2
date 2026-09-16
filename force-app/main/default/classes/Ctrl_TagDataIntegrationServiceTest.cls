@isTest
private class Ctrl_TagDataIntegrationServiceTest {

    @testSetup
    static void setupData() {

        Metal_Purity_Master__c purity = new Metal_Purity_Master__c(
            Purity__c = 22,
            Purity_Code__c = '22K'
        );
        insert purity;

        Vendor_Master__c vendor = new Vendor_Master__c(
            Vendor_No__c = 'V001',
            Vendor_Name__c = 'Test Vendor'
        );
        insert vendor;
    }

    @isTest
    static void testProcessTagDataFromFlow_Success() {

        Showroom_Visit__c visit = new Showroom_Visit__c(
            //Name = 'Test Visit'
        );
        insert visit;

        Wishlist_Item__c dummyItem = new Wishlist_Item__c(
            Showroom_Visit__c = visit.Id
        );
        insert dummyItem;

        List<Ctrl_TagDataIntegrationService.FlowInput> inputs =
            new List<Ctrl_TagDataIntegrationService.FlowInput>();

        Ctrl_TagDataIntegrationService.FlowInput input =
            new Ctrl_TagDataIntegrationService.FlowInput();

        input.tagNo = 'TAG001';
        input.wishlistItemId = dummyItem.Id;

        inputs.add(input);

        Test.startTest();

        Test.setMock(
            HttpCalloutMock.class,
            new TagIntegrationMock(200)
        );

        // INSERT FLOW
        Ctrl_TagDataIntegrationService.processTagDataFromFlow(inputs);

        // UPDATE FLOW
        Ctrl_TagDataIntegrationService.processTagDataFromFlow(inputs);

        Test.stopTest();
    }

    @isTest
    static void testInsertScannedTagRecords_NullAndEmptyScenarios() {

        Test.startTest();

        Ctrl_TagDataIntegrationService.insertScannedTagRecords(
            null,
            null
        );

        Test.setMock(
            HttpCalloutMock.class,
            new TagIntegrationMock(200)
        );

        Ctrl_TagDataIntegrationService.insertScannedTagRecords(
            'TAG001',
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testDMLFailureCoverage() {

        Test.startTest();

        Test.setMock(
            HttpCalloutMock.class,
            new TagIntegrationMock(200)
        );

        // Passing User Id intentionally
        Ctrl_TagDataIntegrationService.insertScannedTagRecords(
            'TAG001',
            UserInfo.getUserId()
        );

        Test.stopTest();
    }

    @isTest
    static void testCalloutErrorHandling() {

        Showroom_Visit__c visit = new Showroom_Visit__c(
          //  Name = 'Test Visit'
        );
        insert visit;

        Wishlist_Item__c dummyItem = new Wishlist_Item__c(
            Showroom_Visit__c = visit.Id
        );
        insert dummyItem;

        Test.startTest();

        Test.setMock(
            HttpCalloutMock.class,
            new TagIntegrationMock(404)
        );

        Ctrl_TagDataIntegrationService.insertScannedTagRecords(
            'TAG001',
            dummyItem.Id
        );

        Test.stopTest();
    }

    // =====================================================================
    // MOCK CLASS
    // =====================================================================

    private class TagIntegrationMock implements HttpCalloutMock {

        private Integer statusCode;

        public TagIntegrationMock(Integer statusCode) {
            this.statusCode = statusCode;
        }

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();

            res.setHeader(
                'Content-Type',
                'application/json'
            );

            // ERROR RESPONSE
            if (statusCode != 200) {

                res.setStatusCode(statusCode);

                res.setBody(
                    '{"error":"Simulated Error"}'
                );

                return res;
            }

            // ============================================================
            // POST CALL
            // ============================================================

            if (req.getMethod() == 'POST') {

                res.setStatusCode(201);

                res.setBody(
                    '{"status":"success"}'
                );
            }

            // ============================================================
            // HEADER API
            // ============================================================

            else if (
                req.getEndpoint().contains('ACXTagHeadersAPIJRS')
            ) {

                res.setStatusCode(200);

                res.setBody(
                    '{"value":[' +
                    '{' +
                    '"tagNo":"TAG001",' +
                    '"grossWEIGHT":10.5,' +
                    '"netWEIGHT":10.0,' +
                    '"purity":22,' +
                    '"certificationVendor":"V001",' +
                    '"ornamentColor":"Yellow",' +
                    '"ornamentCATEGORYCODE":"Ring",' +
                    '"ornamentSIZE":"7",' +
                    '"designCODE":"D001",' +
                    '"diamondWEIGHT":0.5,' +
                    '"stoneWEIGHTCT":null' +
                    '}' +
                    ']}'
                );
            }

            // ============================================================
            // PRICE LINES API
            // ============================================================

            else if (
                req.getEndpoint().contains('TagPriceLinesJRS') &&
                req.getMethod() == 'GET'
            ) {

                res.setStatusCode(200);

                res.setBody(
                    '{"value":[' +
                    '{' +
                    '"tagNo":"TAG001",' +
                    '"taxableAmount":50000' +
                    '}' +
                    ']}'
                );
            }

            // ============================================================
            // DETAIL LINES API
            // ============================================================

            else if (
                req.getEndpoint().contains('TagPriceDetailLinesJRS')
            ) {

                res.setStatusCode(200);

                res.setBody(
                    '{"value":[' +
                    '{' +
                    '"tagNo":"TAG001",' +
                    '"item":"Gold",' +
                    '"purity":22,' +
                    '"qty":1,' +
                    '"uom":"GM",' +
                    '"rate":5000,' +
                    '"amount":50000' +
                    '}' +
                    ']}'
                );
            }

            // ============================================================
            // SCM API
            // ============================================================

            else if (
                req.getEndpoint().contains('TagPriceSCMAPIJRS')
            ) {

                res.setStatusCode(200);

                res.setBody(
                    '{"value":[' +
                    '{' +
                    '"tagNo":"TAG001",' +
                    '"itemNo":"SCM01",' +
                    '"quantity":1,' +
                    '"rate":500,' +
                    '"amount":500,' +
                    '"makingTYPE":"Machine"' +
                    '}' +
                    ']}'
                );
            }

            // ============================================================
            // TAG PRICES API
            // ============================================================

            else if (
                req.getEndpoint().contains('TagPricesJRS')
            ) {

                res.setStatusCode(200);

                res.setBody(
                    '{"value":[' +
                    '{' +
                    '"itemID":"ITEM001"' +
                    '}' +
                    ']}'
                );
            }

            // ============================================================
            // ITEM LIST API
            // ============================================================

            else if (
                req.getEndpoint().contains('ItemListJRS')
            ) {

                res.setStatusCode(200);

                res.setBody(
                    '{"value":[' +
                    '{' +
                    '"gstGroupCode":"GST01",' +
                    '"hsnSACCode":"HSN01"' +
                    '}' +
                    ']}'
                );
            }

            // ============================================================
            // HSN API
            // ============================================================

            else if (
                req.getEndpoint().contains('HSNCodeAPIJRS')
            ) {

                res.setStatusCode(200);

                res.setBody(
                    '{"value":[' +
                    '{' +
                    '"gst":3' +
                    '}' +
                    ']}'
                );
            }

            // ============================================================
            // IMAGE API
            // ============================================================

            else if (
                req.getEndpoint().contains('designImageAPIJRS')
            ) {

                res.setStatusCode(200);

                res.setBody(
                    '{"value":[' +
                    '{' +
                    '"imageUrl":"https://dummyimage.com/test.png"' +
                    '}' +
                    ']}'
                );
            }

            // ============================================================
            // IMAGE DOWNLOAD
            // ============================================================

            else if (
                req.getEndpoint().contains('dummyimage.com')
            ) {

                res.setStatusCode(200);

                res.setBodyAsBlob(
                    Blob.valueOf('Dummy Image Content')
                );
            }

            // ============================================================
            // FALLBACK
            // ============================================================

            else {

                res.setStatusCode(200);

                res.setBody('{"value":[]}');
            }

            return res;
        }
    }
}