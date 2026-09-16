@IsTest
private class ctrl_CustomerOrderLineItemRelList_Test {

    @TestSetup
    static void setupData() {

        Account acc = new Account();
        acc.Name = 'Test Customer';
        insert acc;

        Customer_Order__c customerOrder = new Customer_Order__c();
        customerOrder.Customer__c = acc.Id;

        /*
         * Add other mandatory fields of Customer_Order__c here if required.
         * Example:
         * customerOrder.Order_Date__c = Date.today();
         * customerOrder.Store__c = store.Id;
         * customerOrder.Showroom_Visit__c = showroomVisit.Id;
         */

        insert customerOrder;

        List<Customer_Order_Line_Item__c> lineItems = new List<Customer_Order_Line_Item__c>();

        Customer_Order_Line_Item__c item1 = new Customer_Order_Line_Item__c();
        item1.Customer_Order__c = customerOrder.Id;
        item1.Line_Item_Status_On_Salesforce__c = 'Draft';
        item1.Barcode_Value__c = 'SGPB/1001';
        lineItems.add(item1);

        Customer_Order_Line_Item__c item2 = new Customer_Order_Line_Item__c();
        item2.Customer_Order__c = customerOrder.Id;
        item2.Line_Item_Status_On_Salesforce__c = 'Finalize In Post';
        item2.Barcode_Value__c = 'SGPB/1002';
        lineItems.add(item2);

        Customer_Order_Line_Item__c item3 = new Customer_Order_Line_Item__c();
        item3.Customer_Order__c = customerOrder.Id;
        item3.Line_Item_Status_On_Salesforce__c = 'Finalize In Pre';
        item3.Barcode_Value__c = 'SGPB/1003';
        lineItems.add(item3);

        Customer_Order_Line_Item__c item4 = new Customer_Order_Line_Item__c();
        item4.Customer_Order__c = customerOrder.Id;
        item4.Line_Item_Status_On_Salesforce__c = 'Sent To ERP - PRE';
        item4.Barcode_Value__c = 'SGPB/1004';
        lineItems.add(item4);

        Customer_Order_Line_Item__c item5 = new Customer_Order_Line_Item__c();
        item5.Customer_Order__c = customerOrder.Id;
        item5.Line_Item_Status_On_Salesforce__c = 'Newly Added';
        item5.Barcode_Value__c = 'SGPB/1005';
        lineItems.add(item5);

        Customer_Order_Line_Item__c item6 = new Customer_Order_Line_Item__c();
        item6.Customer_Order__c = customerOrder.Id;
        item6.Line_Item_Status_On_Salesforce__c = 'Back To Available Wishlist Item';
        item6.Barcode_Value__c = 'SGPB/1006';
        lineItems.add(item6);

        Customer_Order_Line_Item__c item7 = new Customer_Order_Line_Item__c();
        item7.Customer_Order__c = customerOrder.Id;
        item7.Line_Item_Status_On_Salesforce__c = 'Removed';
        item7.Barcode_Value__c = 'SGPB/1007';
        lineItems.add(item7);

        insert lineItems;
    }

    @IsTest
    static void testGetLineItems_WithValidCustomerOrderId() {

        Customer_Order__c customerOrder = [
            SELECT Id
            FROM Customer_Order__c
            LIMIT 1
        ];

        Test.startTest();

        List<Customer_Order_Line_Item__c> result =
            ctrl_CustomerOrderLineItemRelatedList.getLineItems(customerOrder.Id);

        Test.stopTest();
    }

    @IsTest
    static void testGetLineItems_WithNullCustomerOrderId() {

        Test.startTest();

        List<Customer_Order_Line_Item__c> result =
            ctrl_CustomerOrderLineItemRelatedList.getLineItems(null);

        Test.stopTest();
    }

    @IsTest
    static void testGetLineItems_WithNoChildRecords() {

        Account acc = new Account();
        acc.Name = 'Test Customer Without Line Item';
        insert acc;

        Customer_Order__c customerOrder = new Customer_Order__c();
        customerOrder.Customer__c = acc.Id;

        /*
         * Add other mandatory fields of Customer_Order__c here if required.
         */

        insert customerOrder;

        Test.startTest();

        List<Customer_Order_Line_Item__c> result =
            ctrl_CustomerOrderLineItemRelatedList.getLineItems(customerOrder.Id);

        Test.stopTest();
    }

    @IsTest
    static void testLineItemStatusSorterDirectly() {

        List<Customer_Order_Line_Item__c> items = [
            SELECT
                Id,
                Name,
                Line_Item_Status_On_Salesforce__c,
                Barcode_Value__c,
                CreatedDate
            FROM Customer_Order_Line_Item__c
            LIMIT 7
        ];

        Test.startTest();

        ctrl_CustomerOrderLineItemRelatedList.LineItemStatusSorter sorter =
            new ctrl_CustomerOrderLineItemRelatedList.LineItemStatusSorter();

        items.sort(sorter);

        Test.stopTest();
    }
}