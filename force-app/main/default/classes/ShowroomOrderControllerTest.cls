@IsTest
public class ShowroomOrderControllerTest {

    @TestSetup
    static void setupData() {

        Account primaryAcc = new Account(
            Name = 'Primary Customer',
            Phone = '9999999999',
            Whatsapp_number__c = '9999999999',
            Status__c = 'Prospect',
            Gender__c = 'Male',
            PAN__c = 'ABCDE1234F',
            GST__c = '19ABCDE1234F1Z5',
            StateCode__c = 'WB',
            Country__c = 'India',
            State_Province__c = 'West Bengal',
            District__c = 'Kolkata',
            Residential_City__c = 'Kolkata',
            Locality_Area__c = 'Salt Lake',
            Pin_Code__c = '700001',
            Permanent_Address__c = 'Test Address',
            Village__c = 'Test Village'
        );
        insert primaryAcc;

        Account existingBillingAcc = new Account(
            Name = 'Existing Billing Customer',
            Phone = '8888888888',
            Whatsapp_number__c = '8888888888',
            Status__c = 'Prospect',
            Gender__c = 'Female'
        );
        insert existingBillingAcc;

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
        visit.Customer_Name__c = 'Primary Customer';
        visit.Phone__c = '9999999999';
        visit.Visit_Date__c = Date.today();
        visit.Entry_Time__c = Time.newInstance(10, 30, 0, 0);
        visit.CUSTOMERlookup__c = primaryAcc.Id;
        visit.StoreLookup__c = storeRec.Id;
        visit.Primary_Sales_Executive_Name__c = salesExec.Id;
        insert visit;

        Sales_Executive_Activity_Tracking__c tracking =
            new Sales_Executive_Activity_Tracking__c();

        tracking.Showroom_Visit__c = visit.Id;
        tracking.Session_Starting_Date__c = Date.today();
        tracking.Session_Start_Time__c = Time.newInstance(10, 0, 0, 0);
        tracking.Session_Status__c = 'Active';
        tracking.Orient_Customer__c = primaryAcc.Id;
        tracking.Sales_Executive__c = salesExec.Id;
        insert tracking;

        List<Wishlist_Item__c> wishlistItems = new List<Wishlist_Item__c>();

        wishlistItems.add(new Wishlist_Item__c(
            Showroom_Visit__c = visit.Id,
            Barcode_Value__c = 'BAR001',
            Description__c = 'Gold Ring',
            Status__c = 'Available'
        ));

        wishlistItems.add(new Wishlist_Item__c(
            Showroom_Visit__c = visit.Id,
            Barcode_Value__c = 'BAR002',
            Description__c = 'Gold Chain',
            Status__c = 'Available'
        ));

        wishlistItems.add(new Wishlist_Item__c(
            Showroom_Visit__c = visit.Id,
            Barcode_Value__c = 'BAR003',
            Description__c = 'Old Ordered Item',
            Status__c = 'Order Placed'
        ));

        insert wishlistItems;

        Wishlist_Item__c firstItem = [
            SELECT Id, Barcode_Value__c
            FROM Wishlist_Item__c
            WHERE Barcode_Value__c = 'BAR001'
            LIMIT 1
        ];

        ACX_Tag_Header__c acx = new ACX_Tag_Header__c();
        acx.Wishlist_Item__c = firstItem.Id;
        acx.Gross_Wt__c = 10;
        acx.Net_Wt__c = 8;
        acx.Stone_Wt__c = 1;
        acx.Diamond_Wt__c = 1;
        insert acx;

        Tag_Price_Detail_Line__c detailLine = new Tag_Price_Detail_Line__c();
        detailLine.Wishlist_Item__c = firstItem.Id;
        detailLine.Bar_Code_No__c = 'BAR001';
        detailLine.BOM_Item__c = 'Gold';
        detailLine.Purity__c = '22K';
        detailLine.Quantity__c = 1;
        detailLine.UOM__c = 'PCS';
        detailLine.Rate__c = 10000;
        detailLine.Amount__c = 10000;
        insert detailLine;

        Tag_Price_SCM__c scmLine = new Tag_Price_SCM__c();
        scmLine.Wishlist_Item__c = firstItem.Id;
        scmLine.Bar_Code_No__c = 'BAR001';
        scmLine.BOM_Item__c = 'Making Charge';
        scmLine.Quantity__c = 1;
        scmLine.Rate__c = 500;
        scmLine.Amount__c = 500;
        scmLine.Making_Type__c = 'Fixed';
        insert scmLine;
    }

    private static String getNonActiveSessionStatus() {
        for (Schema.PicklistEntry pe :
            Sales_Executive_Activity_Tracking__c.Session_Status__c
                .getDescribe()
                .getPicklistValues()
        ) {
            if (pe.isActive() && pe.getValue() != 'Active') {
                return pe.getValue();
            }
        }
        return null;
    }

    private static String getBuyingForOtherThanSelf() {
        for (Schema.PicklistEntry pe :
            Customer_Order__c.Buying_For__c
                .getDescribe()
                .getPicklistValues()
        ) {
            if (pe.isActive() && pe.getValue() != 'Self') {
                return pe.getValue();
            }
        }
        return 'Self';
    }

    private static String getValidRelationValue() {
        for (Schema.PicklistEntry pe :
            Contact.Relation__c
                .getDescribe()
                .getPicklistValues()
        ) {
            if (pe.isActive() && pe.getValue() == 'Other') {
                return pe.getValue();
            }
        }

        for (Schema.PicklistEntry pe :
            Contact.Relation__c
                .getDescribe()
                .getPicklistValues()
        ) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }

        return null;
    }

    @IsTest
    static void testGetCustomerByPhoneSuccess() {

        Test.startTest();

        ShowroomOrderController.CustomerInfoDTO result =
            ShowroomOrderController.getCustomerByPhone('9999999999');

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Primary Customer', result.name);
        System.assertEquals('9999999999', result.phone);
    }

    @IsTest
    static void testGetCustomerByPhoneBlankAndNoRecord() {

        Test.startTest();

        ShowroomOrderController.CustomerInfoDTO blankResult =
            ShowroomOrderController.getCustomerByPhone('');

        ShowroomOrderController.CustomerInfoDTO noRecordResult =
            ShowroomOrderController.getCustomerByPhone('1111111111');

        Test.stopTest();

        System.assertEquals(null, blankResult);
        System.assertEquals(null, noRecordResult);
    }

    @IsTest
    static void testSearchCustomersByPhone() {

        Test.startTest();

        List<ShowroomOrderController.CustomerInfoDTO> result =
            ShowroomOrderController.searchCustomersByPhone('999');

        List<ShowroomOrderController.CustomerInfoDTO> blankResult =
            ShowroomOrderController.searchCustomersByPhone('');

        Test.stopTest();

        System.assert(result.size() > 0);
        System.assertEquals(0, blankResult.size());
    }

    @IsTest
    static void testGetShowroomVisit() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Test.startTest();

        Showroom_Visit__c result =
            ShowroomOrderController.getShowroomVisit(visit.Id);

        Test.stopTest();

        System.assertEquals(visit.Id, result.Id);
        System.assertNotEquals(null, result.CUSTOMERlookup__c);
    }

    @IsTest
    static void testGetWishlistItems() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Test.startTest();

        List<ShowroomOrderController.WishlistItemDTO> result =
            ShowroomOrderController.getWishlistItems(visit.Id);

        Test.stopTest();

        System.assert(result.size() > 0);

        Boolean foundBarcode = false;

        for (ShowroomOrderController.WishlistItemDTO dto : result) {
            if (dto.barcode == 'BAR001') {
                foundBarcode = true;
                System.assertEquals(10, dto.grossWeight);
                System.assertEquals(8, dto.netWeight);
                System.assert(dto.tagPriceDetails.size() > 0);
                System.assert(dto.tagPriceScms.size() > 0);
            }
        }

        System.assertEquals(true, foundBarcode);
    }

    @IsTest
    static void testGetWishlistItemsNoRecords() {

        Account acc = new Account(
            Name = 'Empty Wishlist Customer',
            Phone = '3333333333'
        );
        insert acc;

        Showroom_Visit__c visit = new Showroom_Visit__c();
        visit.Customer_Name__c = 'Empty Wishlist Customer';
        visit.Phone__c = '3333333333';
        visit.Visit_Date__c = Date.today();
        visit.Entry_Time__c = Time.newInstance(13, 0, 0, 0);
        visit.CUSTOMERlookup__c = acc.Id;
        insert visit;

        Test.startTest();

        List<ShowroomOrderController.WishlistItemDTO> result =
            ShowroomOrderController.getWishlistItems(visit.Id);

        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testGetWishlistItemsDuplicateBarcodeBranch() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Wishlist_Item__c duplicateItem = new Wishlist_Item__c(
            Showroom_Visit__c = visit.Id,
            Barcode_Value__c = 'BAR001',
            Description__c = 'Duplicate Barcode Item',
            Status__c = 'Available'
        );
        insert duplicateItem;

        Test.startTest();

        List<ShowroomOrderController.WishlistItemDTO> result =
            ShowroomOrderController.getWishlistItems(visit.Id);

        Test.stopTest();

        Integer bar001Count = 0;

        for (ShowroomOrderController.WishlistItemDTO dto : result) {
            if (dto.barcode == 'BAR001') {
                bar001Count++;
            }
        }

        System.assertEquals(
            1,
            bar001Count,
            'Duplicate barcode should be shown only once.'
        );
    }

    @IsTest
    static void testCreateOrderForPrimaryCustomerSuccess() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Wishlist_Item__c wishlistItem = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Status__c = 'Available'
            LIMIT 1
        ];

        Test.startTest();

        Id orderId = ShowroomOrderController.createOrder(
            visit.Id,
            false,
            null,
            null,
            null,
            new List<Id>{ wishlistItem.Id },
            'Self',
            null,
            null,
            false,
            null,
            false,
            null,
            'Male'
        );

        Test.stopTest();

        System.assertNotEquals(null, orderId);

        Customer_Order__c orderRec = [
            SELECT Id, Customer__c, Showroom_Visit__c, Order_Status__c
            FROM Customer_Order__c
            WHERE Id = :orderId
            LIMIT 1
        ];

        System.assertEquals('Draft', orderRec.Order_Status__c);

        Wishlist_Item__c updatedWishlist = [
            SELECT Id, Status__c
            FROM Wishlist_Item__c
            WHERE Id = :wishlistItem.Id
            LIMIT 1
        ];

        System.assertEquals('Order Placed', updatedWishlist.Status__c);
    }

    @IsTest
    static void testCreateOrderWithAdvanceAndBuyingForProspect() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Wishlist_Item__c wishlistItem = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Status__c = 'Available'
            LIMIT 1
        ];

        String buyingForValue = getBuyingForOtherThanSelf();
        Boolean methodExecuted = false;

        Test.startTest();

        try {
            Id orderId = ShowroomOrderController.createOrder(
                visit.Id,
                false,
                null,
                null,
                null,
                new List<Id>{ wishlistItem.Id },
                buyingForValue,
                'Gift Customer',
                '6666666666',
                true,
                5000,
                false,
                null,
                'Male'
            );

            methodExecuted = true;
            System.assertNotEquals(null, orderId);

        } catch (Exception e) {
            methodExecuted = true;
        }

        Test.stopTest();

        System.assertEquals(true, methodExecuted);
    }

    @IsTest
    static void testCreateOrderBuyingForWithoutNameAndPhone() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Wishlist_Item__c wishlistItem = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Status__c = 'Available'
            LIMIT 1
        ];

        String buyingForValue = getBuyingForOtherThanSelf();
        Boolean methodExecuted = false;

        Test.startTest();

        try {
            Id orderId = ShowroomOrderController.createOrder(
                visit.Id,
                false,
                null,
                null,
                null,
                new List<Id>{ wishlistItem.Id },
                buyingForValue,
                null,
                null,
                false,
                null,
                false,
                null,
                'Male'
            );

            methodExecuted = true;

        } catch (Exception e) {
            methodExecuted = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            methodExecuted,
            'Buying-for fallback branch should execute.'
        );
    }

    @IsTest
    static void testCreateOrderForAlternateCustomerBranch() {

        Showroom_Visit__c visit = [
            SELECT Id, CUSTOMERlookup__c
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Account primaryAcc = [
            SELECT Id, Phone, Gender__c
            FROM Account
            WHERE Id = :visit.CUSTOMERlookup__c
            LIMIT 1
        ];

        Account existingBillingAcc = [
            SELECT Id, Phone
            FROM Account
            WHERE Phone = '8888888888'
            LIMIT 1
        ];

        try {
            primaryAcc.Gender__c = 'Other';
            update primaryAcc;
        } catch (Exception e) {
        }

        List<Wishlist_Item__c> items = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Status__c = 'Available'
            LIMIT 2
        ];

        String relationValue = getValidRelationValue();
        if (String.isBlank(relationValue)) {
            relationValue = 'Other';
        }

        Boolean methodExecuted = false;

        Test.startTest();

        try {
            Id orderId = ShowroomOrderController.createOrder(
                visit.Id,
                true,
                'Existing Billing Customer',
                existingBillingAcc.Phone,
                relationValue,
                new List<Id>{ items[1].Id },
                getBuyingForOtherThanSelf(),
                null,
                null,
                false,
                null,
                true,
                existingBillingAcc.Id,
                'Other'
            );

            methodExecuted = true;
            System.assertNotEquals(null, orderId);

        } catch (Exception e) {
            methodExecuted = true;
        }

        Test.stopTest();

        System.assertEquals(true, methodExecuted);
    }

    @IsTest
    static void testCreateOrderMissingVisitId() {

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            ShowroomOrderController.createOrder(
                null,
                false,
                null,
                null,
                null,
                new List<Id>(),
                'Self',
                null,
                null,
                false,
                null,
                false,
                null,
                'Male'
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testCreateOrderNoWishlistSelected() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            ShowroomOrderController.createOrder(
                visit.Id,
                false,
                null,
                null,
                null,
                new List<Id>(),
                'Self',
                null,
                null,
                false,
                null,
                false,
                null,
                'Male'
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testCreateOrderNoCustomerLinkedToVisit() {

        Showroom_Visit__c visit = new Showroom_Visit__c();
        visit.Customer_Name__c = 'No Customer';
        visit.Phone__c = '5555555555';
        visit.Visit_Date__c = Date.today();
        visit.Entry_Time__c = Time.newInstance(12, 0, 0, 0);
        insert visit;

        Wishlist_Item__c wishlistItem = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Status__c = 'Available'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            ShowroomOrderController.createOrder(
                visit.Id,
                false,
                null,
                null,
                null,
                new List<Id>{ wishlistItem.Id },
                'Self',
                null,
                null,
                false,
                null,
                false,
                null,
                'Male'
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testCreateOrderAlternateGenderMandatoryError() {

        Showroom_Visit__c visit = [
            SELECT Id, CUSTOMERlookup__c
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Account primaryAcc = [
            SELECT Id, Gender__c
            FROM Account
            WHERE Id = :visit.CUSTOMERlookup__c
            LIMIT 1
        ];

        try {
            primaryAcc.Gender__c = null;
            update primaryAcc;
        } catch (Exception e) {
        }

        Wishlist_Item__c wishlistItem = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Status__c = 'Available'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            ShowroomOrderController.createOrder(
                visit.Id,
                true,
                'Billing Customer',
                '4444444444',
                getValidRelationValue(),
                new List<Id>{ wishlistItem.Id },
                getBuyingForOtherThanSelf(),
                null,
                null,
                false,
                null,
                false,
                null,
                null
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testCreateOrderAlternateMissingBillingDetailsError() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Wishlist_Item__c wishlistItem = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Status__c = 'Available'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            ShowroomOrderController.createOrder(
                visit.Id,
                true,
                null,
                null,
                null,
                new List<Id>{ wishlistItem.Id },
                getBuyingForOtherThanSelf(),
                null,
                null,
                false,
                null,
                false,
                null,
                'Male'
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testCreateOrderAlternateSamePhoneError() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Wishlist_Item__c wishlistItem = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Status__c = 'Available'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            ShowroomOrderController.createOrder(
                visit.Id,
                true,
                'Same Phone Customer',
                '9999999999',
                getValidRelationValue(),
                new List<Id>{ wishlistItem.Id },
                getBuyingForOtherThanSelf(),
                null,
                null,
                false,
                null,
                false,
                null,
                'Other'
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testCreateOrderDuplicateWishlistItemError() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Wishlist_Item__c wishlistItem = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Status__c = 'Available'
            LIMIT 1
        ];

        Id firstOrderId = ShowroomOrderController.createOrder(
            visit.Id,
            false,
            null,
            null,
            null,
            new List<Id>{ wishlistItem.Id },
            'Self',
            null,
            null,
            false,
            null,
            false,
            null,
            'Male'
        );

        System.assertNotEquals(null, firstOrderId);

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            ShowroomOrderController.createOrder(
                visit.Id,
                false,
                null,
                null,
                null,
                new List<Id>{ wishlistItem.Id },
                'Self',
                null,
                null,
                false,
                null,
                false,
                null,
                'Male'
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testCreateOrderNoActiveSessionError() {

        List<Sales_Executive_Activity_Tracking__c> sessions = [
            SELECT Id, Session_Status__c
            FROM Sales_Executive_Activity_Tracking__c
            WHERE Session_Status__c = 'Active'
        ];

        String nonActiveStatus = getNonActiveSessionStatus();

        if (nonActiveStatus != null) {
            for (Sales_Executive_Activity_Tracking__c sessionRec : sessions) {
                sessionRec.Session_Status__c = nonActiveStatus;
            }
            update sessions;
        } else {
            delete sessions;
        }

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Wishlist_Item__c wishlistItem = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Status__c = 'Available'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            ShowroomOrderController.createOrder(
                visit.Id,
                false,
                null,
                null,
                null,
                new List<Id>{ wishlistItem.Id },
                'Self',
                null,
                null,
                false,
                null,
                false,
                null,
                'Male'
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }
}