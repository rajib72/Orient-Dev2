@IsTest
public class Ctrl_CreateWishlistManually_Test {

    @TestSetup
    static void setupData() {

        Showroom_Visit__c showroomVisit = new Showroom_Visit__c(
     //       Name = 'Test Visit'
        );
        insert showroomVisit;

        Sales_Executive_Activity_Tracking__c trackingRec =
            new Sales_Executive_Activity_Tracking__c();

        trackingRec.Showroom_Visit__c = showroomVisit.Id;
        trackingRec.Session_Status__c = 'Active';

        insert trackingRec;

        Wishlist_Item__c existingWishlist = new Wishlist_Item__c();

        existingWishlist.Showroom_Visit__c = showroomVisit.Id;
        existingWishlist.Barcode_Value__c = 'SKU001';
        existingWishlist.Description__c = 'Existing Wishlist';
        existingWishlist.Status__c = 'Available';
        existingWishlist.Is_Latest_Wishlist__c = true;
        existingWishlist.Sales_Executive_Activity_Tracking__c =
            trackingRec.Id;

        insert existingWishlist;

        Barcode_Scanned_Count__c counter =
            new Barcode_Scanned_Count__c();

        counter.SKU__c = 'SKU001';
        counter.Counter__c = 5;

        insert counter;
    }

    @IsTest
    static void testCreateWishlistItemExistingSKU() {

        Showroom_Visit__c showroomVisit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Test.startTest();

        String wishlistId =
            Ctrl_CreateWishlistManually.createWishlistItem(
                showroomVisit.Id,
                'SKU001'
            );

        Test.stopTest();

        Wishlist_Item__c createdWishlist = [
            SELECT Id,
                   Barcode_Value__c,
                   Is_Latest_Wishlist__c,
                   Status__c
            FROM Wishlist_Item__c
            WHERE Id = :wishlistId
            LIMIT 1
        ];

        Barcode_Scanned_Count__c updatedCounter = [
            SELECT Id,
                   SKU__c,
                   Counter__c
            FROM Barcode_Scanned_Count__c
            WHERE SKU__c = 'SKU001'
            LIMIT 1
        ];

        Id createdId = createdWishlist.Id;
        String barcode = createdWishlist.Barcode_Value__c;
        Boolean latestFlag = createdWishlist.Is_Latest_Wishlist__c;
        String status = createdWishlist.Status__c;

        Decimal counterValue = updatedCounter.Counter__c;
    }

    @IsTest
    static void testCreateWishlistItemNewSKU() {

        Showroom_Visit__c showroomVisit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Test.startTest();

        String wishlistId =
            Ctrl_CreateWishlistManually.createWishlistItem(
                showroomVisit.Id,
                'SKU999'
            );

        Test.stopTest();

        Wishlist_Item__c createdWishlist = [
            SELECT Id,
                   Barcode_Value__c
            FROM Wishlist_Item__c
            WHERE Id = :wishlistId
            LIMIT 1
        ];

        Barcode_Scanned_Count__c counter = [
            SELECT Id,
                   SKU__c,
                   Counter__c
            FROM Barcode_Scanned_Count__c
            WHERE SKU__c = 'SKU999'
            LIMIT 1
        ];

        Id createdId = createdWishlist.Id;
        String barcode = createdWishlist.Barcode_Value__c;

        Decimal counterValue = counter.Counter__c;
    }

    @IsTest
    static void testCreateWishlistItemWithoutTrackingRecord() {

        Showroom_Visit__c showroomVisit = new Showroom_Visit__c(
      //      Name = 'Visit Without Tracking'
        );
        insert showroomVisit;

        Test.startTest();

        String wishlistId =
            Ctrl_CreateWishlistManually.createWishlistItem(
                showroomVisit.Id,
                'SKU777'
            );

        Test.stopTest();

        Wishlist_Item__c wishlist = [
            SELECT Id,
                   Sales_Executive_Activity_Tracking__c,
                   Barcode_Value__c
            FROM Wishlist_Item__c
            WHERE Id = :wishlistId
            LIMIT 1
        ];

        Id createdId = wishlist.Id;
        Id trackingId = wishlist.Sales_Executive_Activity_Tracking__c;
        String barcode = wishlist.Barcode_Value__c;
    }

    @IsTest
    static void testCreateWishlistItemBlankInputs() {

        Test.startTest();

        try {

            Ctrl_CreateWishlistManually.createWishlistItem(
                null,
                null
            );

        } catch (Exception e) {

            String errorMessage = e.getMessage();
        }

        Test.stopTest();
    }

    @IsTest
    static void testCreateWishlistItemBlankBarcode() {

        Showroom_Visit__c showroomVisit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Test.startTest();

        try {

            Ctrl_CreateWishlistManually.createWishlistItem(
                showroomVisit.Id,
                ''
            );

        } catch (Exception e) {

            String errorMessage = e.getMessage();
        }

        Test.stopTest();
    }
}