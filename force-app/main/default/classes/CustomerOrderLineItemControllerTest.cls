@isTest
private class CustomerOrderLineItemControllerTest {

    @testSetup
    static void setupData() {

        // Account
        Account acc = new Account(
            Name = 'Test Customer'
        );
        insert acc;

        // Store
        Store__c storeRec = new Store__c(
            Store_Code__c = 'STR001'
        );
        insert storeRec;

        // Showroom Visit
        Showroom_Visit__c visit = new Showroom_Visit__c(
            CUSTOMERlookup__c = acc.Id,
            StoreLookup__c = storeRec.Id
        );
        insert visit;

        // Customer Order
        Customer_Order__c orderRec = new Customer_Order__c(
            Customer__c = acc.Id,
            Showroom_Visit__c = visit.Id
        );
        insert orderRec;

        // Wishlist Items
        Wishlist_Item__c wish1 = new Wishlist_Item__c(
            Showroom_Visit__c = visit.Id,
            Barcode_Value__c = 'BAR001'
        );
        insert wish1;

        Wishlist_Item__c wish2 = new Wishlist_Item__c(
            Showroom_Visit__c = visit.Id,
            Barcode_Value__c = 'BAR002'
        );
        insert wish2;

        // Duplicate Barcode Wishlist
        Wishlist_Item__c wish3 = new Wishlist_Item__c(
            Showroom_Visit__c = visit.Id,
            Barcode_Value__c = 'BAR001'
        );
        insert wish3;

        // Existing Order Line Item
        Customer_Order_Line_Item__c lineItem = new Customer_Order_Line_Item__c(
            Customer_Order__c = orderRec.Id,
            Barcode_Value__c = 'BAR002'
        );
        insert lineItem;
    }

    @isTest
    static void testGetAvailableWishlistItems() {

        Customer_Order__c orderRec = [
            SELECT Id
            FROM Customer_Order__c
            LIMIT 1
        ];

        Test.startTest();

        CustomerOrderLineItemController.getAvailableWishlistItems(orderRec.Id);

        Test.stopTest();
    }

    @isTest
    static void testGetAvailableWishlistItems_NullOrderId() {

        Test.startTest();

        try {
            CustomerOrderLineItemController.getAvailableWishlistItems(null);
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testGetAvailableWishlistItems_NoShowroomVisit() {

        Account acc = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        Customer_Order__c orderRec = new Customer_Order__c(
            Customer__c = acc.Id
        );
        insert orderRec;

        Test.startTest();

        try {
            CustomerOrderLineItemController.getAvailableWishlistItems(orderRec.Id);
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testSaveSelectedWishlistItems() {

        Customer_Order__c orderRec = [
            SELECT Id
            FROM Customer_Order__c
            LIMIT 1
        ];

        List<Wishlist_Item__c> wishlistItems = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Barcode_Value__c = 'BAR001'
        ];

        List<Id> wishlistIds = new List<Id>();

        for (Wishlist_Item__c wish : wishlistItems) {
            wishlistIds.add(wish.Id);
        }

        Test.startTest();

        CustomerOrderLineItemController.saveSelectedWishlistItems(
            orderRec.Id,
            wishlistIds
        );

        Test.stopTest();
    }

    @isTest
    static void testSaveSelectedWishlistItems_NullOrderId() {

        List<Id> wishlistIds = new List<Id>();

        Test.startTest();

        try {
            CustomerOrderLineItemController.saveSelectedWishlistItems(
                null,
                wishlistIds
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testSaveSelectedWishlistItems_EmptyWishlist() {

        Customer_Order__c orderRec = [
            SELECT Id
            FROM Customer_Order__c
            LIMIT 1
        ];

        Test.startTest();

        try {
            CustomerOrderLineItemController.saveSelectedWishlistItems(
                orderRec.Id,
                new List<Id>()
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testSaveSelectedWishlistItems_NoShowroomVisit() {

        Account acc = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        Customer_Order__c orderRec = new Customer_Order__c(
            Customer__c = acc.Id
        );
        insert orderRec;

        List<Wishlist_Item__c> wishlistItems = [
            SELECT Id
            FROM Wishlist_Item__c
            LIMIT 1
        ];

        List<Id> wishlistIds = new List<Id>();
        wishlistIds.add(wishlistItems[0].Id);

        Test.startTest();

        try {
            CustomerOrderLineItemController.saveSelectedWishlistItems(
                orderRec.Id,
                wishlistIds
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testSaveSelectedWishlistItems_AlreadyExists() {

        Customer_Order__c orderRec = [
            SELECT Id
            FROM Customer_Order__c
            LIMIT 1
        ];

        List<Wishlist_Item__c> wishlistItems = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Barcode_Value__c = 'BAR002'
        ];

        List<Id> wishlistIds = new List<Id>();

        for (Wishlist_Item__c wish : wishlistItems) {
            wishlistIds.add(wish.Id);
        }

        Test.startTest();

        try {
            CustomerOrderLineItemController.saveSelectedWishlistItems(
                orderRec.Id,
                wishlistIds
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }
}