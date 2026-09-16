@isTest
private class Ctrl_FetchPreEstimateBCTest {

    // ==========================================
    // MOCK CLASS
    // ==========================================
    private class FetchPreEstimateMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            String endpoint = req.getEndpoint();

            // Header API Response
            if(endpoint.contains('EstimateHeaderAPIJRS')) {

                res.setStatusCode(200);

                res.setBody(
                    '{"value":[{' +
                    '"documentNo":"DOC001",' +
                    '"additionalOffersDiscounts":"Offer",' +
                    '"amountToCustomer":1000,' +
                    '"astrologerCode":"AST01",' +
                    '"astrologerName":"Test Astro",' +
                    '"bargainingAmount":100,' +
                    '"customerCode":"CUST01",' +
                    '"customerName":"Test Customer",' +
                    '"customerOrderNo":"ORD001",' +
                    '"customerPhoneNo":"9999999999",' +
                    '"date":"2026-05-27",' +
                    '"empGradeCode":"E1",' +
                    '"finalAmountToCustomer":1200,' +
                    '"fixedAdvAmt":50,' +
                    '"location":"KOL",' +
                    '"offersDiscounts":"DISC",' +
                    '"otp":"1234",' +
                    '"otpSentTime":"10:10:10",' +
                    '"posReceiptNo":"POS01",' +
                    '"posted":true,' +
                    '"salespersonCode":"SP01",' +
                    '"salespersonName":"Sales User",' +
                    '"tagNo":"TAG001",' +
                    '"schemeEntry":false,' +
                    '"schemeNo":"SCH01",' +
                    '"smsSent":true,' +
                    '"totalChargesAmount":10,' +
                    '"totalDiamondPCS":1,' +
                    '"totalDiamondValue":100,' +
                    '"totalDiamondWeight":1,' +
                    '"totalDiscountAmount":5,' +
                    '"totalGrossWeight":20,' +
                    '"totalMetalAsNonMetalValue":50,' +
                    '"totalMetalAsNonMetalWeight":5,' +
                    '"totalMetalValue":500,' +
                    '"totalNetWeight":18,' +
                    '"totalStoneCTValue":20,' +
                    '"totalStoneCTWeight":2,' +
                    '"totalStoneGRMValue":10,' +
                    '"totalStoneGRMWeight":1,' +
                    '"totalStonePCSValue":5,' +
                    '"totalStonePCSWeight":1,' +
                    '"totalStoneCPCS":1,' +
                    '"totalStoneGPCS":1,' +
                    '"totalTagAmount":1000,' +
                    '"totalTaxAmount":18,' +
                    '"totalTaxableAmount":900,' +
                    '"zmDiscountApplied":false,' +
                    '"deliveryType":"Store Address",' +
                    '"documentSubType":"Normal",' +
                    '"status":"Open",' +
                    '"transactionType":"Estimate"' +
                    '}]}'
                );

            }
            // Line API Response
            else if(endpoint.contains('EstimateLineAPIJRS')) {

                res.setStatusCode(200);

                res.setBody(
                    '{"value":[{' +
                    '"tagNo":"TAG001",' +
                    '"accessibleValue":100,' +
                    '"addlOfferDiscountValue":10,' +
                    '"astrologerCode":"AST01",' +
                    '"bargainingAmountValue":5,' +
                    '"brandID":"BR01",' +
                    '"cash":100,' +
                    '"customerNo":"CUST01",' +
                    '"customerOrderNo":"ORD001",' +
                    '"date":"2026-05-27",' +
                    '"designCODE":"DES01",' +
                    '"diamondPCS":1,' +
                    '"diamondRate":100,' +
                    '"diamondValue":100,' +
                    '"diamondWEIGHT":1,' +
                    '"discount":10,' +
                    '"discountPer":2,' +
                    '"eCertificateView":"YES",' +
                    '"finalAmount":1000,' +
                    '"isFlexiApplicable":true,' +
                    '"flexiOfferAmount":20,' +
                    '"freeItem":false,' +
                    '"grossWeight":15,' +
                    '"inclusiveMRP":false,' +
                    '"itemDescription":"Gold Ring",' +
                    '"itemNo":"ITM01",' +
                    '"keyInPrice":false,' +
                    '"lineNo":1,' +
                    '"location":"KOL",' +
                    '"metalAsNonMetalRate":1,' +
                    '"metalAsNonMetalValue":1,' +
                    '"metalAsNonMetalWeight":1,' +
                    '"metalValue":500,' +
                    '"mrpValue":1000,' +
                    '"netAmount":900,' +
                    '"netWeight":12,' +
                    '"noOfPCS":1,' +
                    '"nonCash":0,' +
                    '"offerAgainstTagNo":"TAG002",' +
                    '"offerDiscountValue":5,' +
                    '"offerDiscountFreeItem":false,' +
                    '"ornamentCATEGORYCODE":"ORN01",' +
                    '"ornamentSUBCATEGORY":"SUB01",' +
                    '"outwardAmount":0,' +
                    '"outwardCost":0,' +
                    '"outwardCoupon":0,' +
                    '"outwardDiscount":0,' +
                    '"posCertificatePrint":"YES",' +
                    '"posted":true,' +
                    '"purity":22,' +
                    '"salespersonCode":"SP01",' +
                    '"schemeDiscountValue":5,' +
                    '"sectionID":"SEC01",' +
                    '"smcRate":1,' +
                    '"smcValue":1,' +
                    '"stoneCTRate":1,' +
                    '"stoneCTValue":1,' +
                    '"stoneCTWeight":1,' +
                    '"stoneGRMRate":1,' +
                    '"stoneGRMValue":1,' +
                    '"stoneGRMWeight":1,' +
                    '"stonePCSRate":1,' +
                    '"stonePCSValue":1,' +
                    '"stonePCSWeight":1,' +
                    '"stoneAMOUNT":1,' +
                    '"stoneCPCS":1,' +
                    '"stoneGPCS":1,' +
                    '"stoneWEIGHT":1,' +
                    '"stoneWEIGHTCT":1,' +
                    '"tagAmount":1000,' +
                    '"taxAmount":18,' +
                    '"taxableAmount":900,' +
                    '"urdDiscountValue":0,' +
                    '"variantID":"VAR01",' +
                    '"weightRangeCode":"W1",' +
                    '"documentSubType":"Normal",' +
                    '"incentiveCommision":"Gold",' +
                    '"makingType":"Per Pcs",' +
                    '"metalType":"Gold",' +
                    '"itemTypeGroup":"Gold"' +
                    '}]}'
                );
            }

            return res;
        }
    }

    // ==========================================
    // TEST METHOD
    // ==========================================
    @isTest
    static void testFetchPreEstimate() {

        Account acc = new Account(
            Name = 'Test Customer'
        );
        insert acc;

        Customer_Order__c orderRec = new Customer_Order__c(
          //  Name = 'EST-001',
            Customer__c = acc.Id,
            Pre_Document_No__c = 'DOC001'
        );
        insert orderRec;

        Customer_Order_Line_Item__c lineItem = new Customer_Order_Line_Item__c(
            Customer_Order__c = orderRec.Id,
            Barcode_Value__c = 'TAG001',
            Line_Item_Status_On_Salesforce__c = 'Finalize In Pre'
        );
        insert lineItem;

        Test.setMock(HttpCalloutMock.class, new FetchPreEstimateMock());

        Test.startTest();

        Ctrl_FetchPreEstimateBC.fetchPreEstimate(orderRec.Id);

        Test.stopTest();
    }

    // ==========================================
    // TEST FOR BLANK DOCUMENT NUMBER
    // ==========================================
    @isTest
    static void testFetchPreEstimateBlankDocNo() {

        Account acc = new Account(
            Name = 'Test Customer 2'
        );
        insert acc;

        Customer_Order__c orderRec = new Customer_Order__c(
          //  Name = 'EST-002',
            Customer__c = acc.Id
        );
        insert orderRec;

        Test.startTest();

        Ctrl_FetchPreEstimateBC.fetchPreEstimate(orderRec.Id);

        Test.stopTest();
    }

    // ==========================================
    // TEST FOR INVALID ORDER ID
    // ==========================================
    @isTest
    static void testFetchPreEstimateInvalidId() {

        Test.startTest();

        Ctrl_FetchPreEstimateBC.fetchPreEstimate('a00000000000000AAA');

        Test.stopTest();
    }
}