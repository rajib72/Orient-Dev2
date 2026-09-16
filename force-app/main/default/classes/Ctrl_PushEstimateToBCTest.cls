@isTest
public class Ctrl_PushEstimateToBCTest {

    @isTest
    static void testGetLineItemsForProcessing() {

        // -----------------------------
        // Account
        // -----------------------------
        Account acc = new Account(
            Name = 'Test Customer'
        );
        insert acc;

        // -----------------------------
        // Customer Order
        // -----------------------------
        Customer_Order__c orderRec = new Customer_Order__c(
           // Name = 'EST-001',
            Customer__c = acc.Id
          //  BC_Customer_No__c = 'BC001',
          //  Location_Code__c = 'LOC001'
        );
        insert orderRec;

        // -----------------------------
        // Line Item
        // -----------------------------
        Customer_Order_Line_Item__c lineItem = new Customer_Order_Line_Item__c(
            Customer_Order__c = orderRec.Id,
         //   Customer__c = acc.Id,
            Barcode_Value__c = 'TAG001',
           // Sales_Executive_Code__c = 'EX001',
          //  Sales_Executive_Name__c = 'Test Executive',
            Final_Price__c = 5000
        );
        insert lineItem;

        Test.startTest();

        Ctrl_PushEstimateToBC.getLineItemsForProcessing(orderRec.Id);

        Test.stopTest();
    }

    @isTest
    static void testPushSingleLineItemToBC() {

        // -----------------------------
        // Account
        // -----------------------------
        Account acc = new Account(
            Name = 'Test Customer'
        );
        insert acc;

        // -----------------------------
        // Customer Order
        // -----------------------------
        Customer_Order__c orderRec = new Customer_Order__c(
          //  Name = 'EST-002',
            Customer__c = acc.Id
          //  BC_Customer_No__c = 'BC002',
            //Location_Code__c = 'LOC002'
        );
        insert orderRec;

        // -----------------------------
        // Line Item
        // -----------------------------
        Customer_Order_Line_Item__c lineItem = new Customer_Order_Line_Item__c(
            Customer_Order__c = orderRec.Id,
         //   Customer__c = acc.Id,
            Barcode_Value__c = 'TAG002',
         //   Sales_Executive_Code__c = 'EX002',
          //  Sales_Executive_Name__c = 'Executive 2',
            Final_Price__c = 10000
        );
        insert lineItem;

        // -----------------------------
        // Mock
        // -----------------------------
        Test.setMock(HttpCalloutMock.class, new PushEstimateMock());

        Test.startTest();

        Ctrl_PushEstimateToBC.pushSingleLineItemToBC(lineItem.Id);

        Test.stopTest();
    }

    // =========================================================
    // MOCK CLASS
    // =========================================================
    public class PushEstimateMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(201);

            res.setBody(
                '{' +
                '"documentNo":"PRE12345"' +
                '}'
            );

            return res;
        }
    }
}