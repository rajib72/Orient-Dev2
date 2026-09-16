@IsTest
public class ShowroomWishlistNotOrderedControllerTest {

    @TestSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Test Customer',
            Phone = '9999999999'
        );
        insert acc;

        Store__c storeRec = new Store__c(
            Name = 'Test Store',
            Store_Code__c = 'ST001'
        );
        insert storeRec;

        Sales_Executives__c salesExec = new Sales_Executives__c(
            Name = 'Test Sales Executive',
            Store__c = storeRec.Id
        );
        insert salesExec;

        Showroom_Visit__c visit = new Showroom_Visit__c();
        visit.Customer_Name__c = 'Test Customer';
        visit.Phone__c = '9999999999';
        visit.Visit_Date__c = Date.today();
        visit.Entry_Time__c = Time.newInstance(10, 30, 0, 0);
        visit.CUSTOMERlookup__c = acc.Id;
        visit.StoreLookup__c = storeRec.Id;
        visit.Primary_Sales_Executive_Name__c = salesExec.Id;
        insert visit;

        List<Wishlist_Item__c> wishlistItems = new List<Wishlist_Item__c>();

        wishlistItems.add(new Wishlist_Item__c(
            Showroom_Visit__c = visit.Id,
            Barcode_Value__c = 'BAR001',
            Description__c = 'Test Description 1',
            Status__c = 'Available'
        ));

        wishlistItems.add(new Wishlist_Item__c(
            Showroom_Visit__c = visit.Id,
            Barcode_Value__c = 'BAR002',
            Description__c = 'Test Description 2',
            Status__c = 'Available'
        ));

        wishlistItems.add(new Wishlist_Item__c(
            Showroom_Visit__c = visit.Id,
            Barcode_Value__c = 'BAR003',
            Description__c = 'Test Description 3',
            Status__c = 'Order Placed'
        ));

        insert wishlistItems;
    }

    private static String getValidNotOrderedReason() {

        Schema.DescribeFieldResult fieldDescribe =
            Wishlist_Item__c.Reason_For_Not_Ordered__c.getDescribe();

        List<Schema.PicklistEntry> picklistValues =
            fieldDescribe.getPicklistValues();

        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }

        return null;
    }

    @IsTest
    static void testGetAvailableWishlistItems() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Test.startTest();

        List<ShowroomWishlistNotOrderedController.WishlistDTO> result =
            ShowroomWishlistNotOrderedController.getAvailableWishlistItems(
                visit.Id
            );

        Test.stopTest();

        System.assertEquals(
            2,
            result.size(),
            'Only Available wishlist items should be returned.'
        );

        System.assertNotEquals(
            null,
            result[0].id,
            'DTO Id should not be null.'
        );

        System.assertNotEquals(
            null,
            result[0].name,
            'DTO Name should not be null.'
        );

        System.assertEquals(
            'Available',
            result[0].status,
            'DTO status should be Available.'
        );
    }

    @IsTest
    static void testGetAvailableWishlistItemsNoRecords() {

        Account acc = new Account(
            Name = 'Another Customer',
            Phone = '8888888888'
        );
        insert acc;

        Showroom_Visit__c newVisit = new Showroom_Visit__c();
        newVisit.Customer_Name__c = 'Another Customer';
        newVisit.Phone__c = '8888888888';
        newVisit.Visit_Date__c = Date.today();
        newVisit.Entry_Time__c = Time.newInstance(11, 0, 0, 0);
        newVisit.CUSTOMERlookup__c = acc.Id;
        insert newVisit;

        Test.startTest();

        List<ShowroomWishlistNotOrderedController.WishlistDTO> result =
            ShowroomWishlistNotOrderedController.getAvailableWishlistItems(
                newVisit.Id
            );

        Test.stopTest();

        System.assertEquals(
            0,
            result.size(),
            'No wishlist item should be returned for this visit.'
        );
    }

    @IsTest
    static void testMarkAsNotOrderedSuccess() {

        String validReason = getValidNotOrderedReason();

        System.assertNotEquals(
            null,
            validReason,
            'Reason_For_Not_Ordered__c must have at least one active picklist value.'
        );

        List<Wishlist_Item__c> availableItems = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Status__c = 'Available'
        ];

        Map<Id, String> wishlistReasonMap = new Map<Id, String>();

        for (Wishlist_Item__c item : availableItems) {
            wishlistReasonMap.put(
                item.Id,
                validReason
            );
        }

        Test.startTest();

        ShowroomWishlistNotOrderedController.markAsNotOrdered(
            wishlistReasonMap
        );

        Test.stopTest();

        List<Wishlist_Item__c> updatedItems = [
            SELECT Id, Status__c, Reason_For_Not_Ordered__c
            FROM Wishlist_Item__c
            WHERE Id IN :wishlistReasonMap.keySet()
        ];

        System.assertEquals(
            2,
            updatedItems.size(),
            'Two wishlist items should be updated.'
        );

        for (Wishlist_Item__c item : updatedItems) {

            System.assertEquals(
                'Not Ordered',
                item.Status__c,
                'Status should be updated to Not Ordered.'
            );

            System.assertEquals(
                validReason,
                item.Reason_For_Not_Ordered__c,
                'Reason should be updated.'
            );
        }
    }

    @IsTest
    static void testMarkAsNotOrderedEmptyMap() {

        Boolean exceptionThrown = false;

        try {
            Test.startTest();

            ShowroomWishlistNotOrderedController.markAsNotOrdered(
                new Map<Id, String>()
            );

            Test.stopTest();

        } catch (Exception e) {
            exceptionThrown = true;
        }

        System.assertEquals(
            true,
            exceptionThrown,
            'Exception should be thrown for empty map.'
        );
    }

    @IsTest
    static void testMarkAsNotOrderedNullMap() {

        Boolean exceptionThrown = false;

        try {
            Test.startTest();

            ShowroomWishlistNotOrderedController.markAsNotOrdered(null);

            Test.stopTest();

        } catch (Exception e) {
            exceptionThrown = true;
        }

        System.assertEquals(
            true,
            exceptionThrown,
            'Exception should be thrown for null map.'
        );
    }
}