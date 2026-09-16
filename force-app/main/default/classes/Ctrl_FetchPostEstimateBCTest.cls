@isTest
public class Ctrl_FetchPostEstimateBCTest {

    @isTest
    static void testFetchPostEstimate() {

        // -----------------------------
        // Test Account
        // -----------------------------
        Account acc = new Account(
            Name = 'Test Customer'
        );
        insert acc;

        // -----------------------------
        // Customer Order
        // -----------------------------
        Customer_Order__c orderRec = new Customer_Order__c(
      //      Name = 'Test Order',
            Customer__c = acc.Id,
            Pre_Document_No__c = 'PRE001'
        );
        insert orderRec;

        // -----------------------------
        // Customer Order Line Item
        // -----------------------------
        Customer_Order_Line_Item__c orderLine = new Customer_Order_Line_Item__c(
            Customer_Order__c = orderRec.Id,
           // Customer__c = acc.Id,
            Barcode_Value__c = 'TAG001',
            Line_Item_Status_On_Salesforce__c = 'Draft'
        );
        insert orderLine;

        // -----------------------------
        // Pre Estimate Header
        // -----------------------------
        Pre_Estimate_Header_From_BC__c preHeader = new Pre_Estimate_Header_From_BC__c(
      //      Name = 'Pre Header',
            Estimation__c = orderRec.Id,
            Pre_Document_No__c = 'PRE001'
        );
        insert preHeader;

        // -----------------------------
        // Pre Estimate Line
        // -----------------------------
        Pre_Estimate_Line_From_BC__c preLine = new Pre_Estimate_Line_From_BC__c(
       //     Name = 'Pre Line',
            Pre_Estimate_Header_From_BC__c = preHeader.Id,
            Tag_No__c = 'TAG001',
            Line_Item_Status_On_Salesforce__c = 'Draft'
        );
        insert preLine;

        // -----------------------------
        // Mock Response
        // -----------------------------
        Test.setMock(HttpCalloutMock.class, new PostEstimateMock());

        Test.startTest();

        Ctrl_FetchPostEstimateBC.fetchPostEstimate(orderRec.Id);

        Test.stopTest();
    }

    // =========================================================
    // MOCK CLASS
    // =========================================================
    public class PostEstimateMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            // -----------------------------------
            // HEADER API RESPONSE
            // -----------------------------------
            if(req.getEndpoint().contains('PostedEstimateHeaderAPIJRS')) {

                res.setBody(
                    '{"value":[' +
                    '{' +
                    '"preDocumentNo":"PRE001",' +
                    '"documentNo":"POST001",' +
                    '"customerCode":"CUST001",' +
                    '"customerName":"Test Customer",' +
                    '"customerPhoneNo":"9999999999",' +
                    '"posted":true,' +
                    '"status":"Posted",' +
                    '"transactionType":"Estimate",' +
                    '"deliveryType":"Store Address",' +
                    '"documentSubType":"Normal"' +
                    '}' +
                    ']}'
                );

                return res;
            }

            // -----------------------------------
            // LINE API RESPONSE
            // -----------------------------------
            if(req.getEndpoint().contains('PostedEstimateLineAPIJRS')) {

                res.setBody(
                    '{"value":[' +
                    '{' +
                    '"tagNo":"TAG001",' +
                    '"itemNo":"ITEM001",' +
                    '"itemDescription":"Gold Ring",' +
                    '"posted":true,' +
                    '"lineNo":1,' +
                    '"grossWeight":10,' +
                    '"netWeight":9,' +
                    '"tagAmount":50000,' +
                    '"taxAmount":1500,' +
                    '"taxableAmount":48500,' +
                    '"documentSubType":"Normal",' +
                    '"makingType":"Net on Gram",' +
                    '"metalType":"Gold",' +
                    '"itemTypeGroup":"Gold",' +
                    '"incentiveCommision":"Gold"' +
                    '}' +
                    ']}'
                );

                return res;
            }

            res.setBody('{"value":[]}');
            return res;
        }
    }
}