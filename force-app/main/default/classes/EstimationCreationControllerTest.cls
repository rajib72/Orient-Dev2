@isTest
public class EstimationCreationControllerTest {

    @testSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Primary Customer',
            Phone = '9876543210',
            Status__c = 'Prospect',
            Gender__c = 'Male'
        );
        insert acc;

        Store__c store = new Store__c(
            Name = 'Main Store',
            Store_Code__c = 'STR001'
        );
        insert store;

        Sales_Executives__c salesExec = new Sales_Executives__c(
            Name = 'Sales Executive',
            Store__c = store.Id
        );
        insert salesExec;

        Showroom_Visit__c visit = new Showroom_Visit__c(
            CUSTOMERlookup__c = acc.Id,
         //   Customer_Phone__c = '9876543210',
            Visit_Date__c = Date.today(),
            StoreLookup__c = store.Id,
            Primary_Sales_Executive_Name__c = salesExec.Id
        );
        insert visit;

        Sales_Executive_Activity_Tracking__c tracking =
            new Sales_Executive_Activity_Tracking__c(
                Showroom_Visit__c = visit.Id,
                Session_Starting_Date__c = Date.today(),
                Session_Status__c = 'Active',
                Sales_Executive__c = salesExec.Id
            );
        insert tracking;

        Wishlist_Item__c wi1 = new Wishlist_Item__c(
        //    Name = 'Wishlist 1',
            Showroom_Visit__c = visit.Id,
            Barcode_Value__c = 'BC001',
            Description__c = 'Jewellery 1',
            Status__c = 'Available'
          //  Total_Price_Incl_GST__c = 1000
        );
        insert wi1;

        Wishlist_Item__c wi2 = new Wishlist_Item__c(
        //    Name = 'Wishlist 2',
            Showroom_Visit__c = visit.Id,
            Barcode_Value__c = 'BC002',
            Description__c = 'Jewellery 2',
            Status__c = 'Available'
         //   Total_Price_Incl_GST__c = 2000
        );
        insert wi2;

        ACX_Tag_Header__c tagHeader = new ACX_Tag_Header__c(
            Wishlist_Item__c = wi1.Id,
            Gross_Wt__c = 10,
            Net_Wt__c = 9,
            Stone_Wt__c = 1,
            Diamond_Wt__c = 0.5
        );
        insert tagHeader;

        Tag_Price_Line__c tpl = new Tag_Price_Line__c(
            Wishlist_Item__c = wi1.Id
          //  Product_Price_Inclusive_GST__c = 5000
        );
        insert tpl;

        Tag_Price_Detail_Line__c detailLine =
            new Tag_Price_Detail_Line__c(
                Wishlist_Item__c = wi1.Id,
                BOM_Item__c = 'Gold',
                Quantity__c = 1,
                Rate__c = 100,
                Amount__c = 100
            );
        insert detailLine;

        Tag_Price_SCM__c scm =
            new Tag_Price_SCM__c(
                Wishlist_Item__c = wi1.Id,
                BOM_Item__c = 'Making',
                Quantity__c = 1,
                Rate__c = 50,
                Amount__c = 50,
                Making_Type__c = 'Fixed'
            );
        insert scm;
    }

    @isTest
    static void testGetCustomerByPhone() {

        Test.startTest();

        EstimationCreationController.getCustomerByPhone('9876543210');

        Test.stopTest();
    }

    @isTest
    static void testSearchCustomersByPhone() {

        Test.startTest();

        EstimationCreationController.searchCustomersByPhone('987');

        Test.stopTest();
    }

    @isTest
    static void testGetShowroomVisit() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Test.startTest();

        EstimationCreationController.getShowroomVisit(visit.Id);

        Test.stopTest();
    }

    @isTest
    static void testGetWishlistItems() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Test.startTest();

        EstimationCreationController.getWishlistItems(visit.Id);

        Test.stopTest();
    }

    @isTest
    static void testCreateOrderPrimaryCustomer() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        List<Wishlist_Item__c> wishlist = [
            SELECT Id
            FROM Wishlist_Item__c
            LIMIT 2
        ];

        List<Id> wishlistIds = new List<Id>();

        for (Wishlist_Item__c wi : wishlist) {
            wishlistIds.add(wi.Id);
        }

        Test.startTest();

        EstimationCreationController.createOrder(
            visit.Id,
            false,
            null,
            null,
            null,
            wishlistIds,
            'Self',
            null,
            null,
            true,
            500,
            false,
            null,
            'Male'
        );

        Test.stopTest();
    }

    @isTest
    static void testCreateOrderAlternateCustomer() {

        Showroom_Visit__c visit = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Wishlist_Item__c wi = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Barcode_Value__c = 'BC002'
            LIMIT 1
        ];

        Test.startTest();

        EstimationCreationController.createOrder(
            visit.Id,
            true,
            'Billing Customer',
            '9999999999',
            'Father',
            new List<Id>{ wi.Id },
            'Self',
            null,
            null,
            false,
            0,
            true,
            null,
            'Male'
        );

        Test.stopTest();
    }

    @isTest
    static void testCreateOrderBuyingFor() {

        Account acc = new Account(
            Name = 'Second Customer',
            Phone = '8888888888',
            Status__c = 'Prospect',
            Gender__c = 'Male'
        );
        insert acc;

        Store__c store = [
            SELECT Id
            FROM Store__c
            LIMIT 1
        ];

        Sales_Executives__c salesExec = [
            SELECT Id
            FROM Sales_Executives__c
            LIMIT 1
        ];

        Showroom_Visit__c visit = new Showroom_Visit__c(
            CUSTOMERlookup__c = acc.Id,
         //   Customer_Phone__c = '8888888888',
            Visit_Date__c = Date.today(),
            StoreLookup__c = store.Id,
            Primary_Sales_Executive_Name__c = salesExec.Id
        );
        insert visit;

        Wishlist_Item__c wi = new Wishlist_Item__c(
      //      Name = 'Wishlist 3',
            Showroom_Visit__c = visit.Id,
            Barcode_Value__c = 'BC003',
            Description__c = 'Jewellery',
            Status__c = 'Available'
            //Total_Price_Incl_GST__c = 3000
        );
        insert wi;

        Test.startTest();

        EstimationCreationController.createOrder(
            visit.Id,
            false,
            null,
            null,
            null,
            new List<Id>{ wi.Id },
            'Brother',
            'Brother Customer',
            '7777777777',
            false,
            0,
            false,
            null,
            'Male'
        );

        Test.stopTest();
    }

    @isTest
    static void testCreateOrderExceptionFlow() {

        Test.startTest();

        try {
            EstimationCreationController.createOrder(
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
                0,
                false,
                null,
                'Male'
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testGetCustomerByPhoneBlank() {

        Test.startTest();

        EstimationCreationController.getCustomerByPhone(null);

        Test.stopTest();
    }

    @isTest
    static void testSearchCustomersByPhoneBlank() {

        Test.startTest();

        EstimationCreationController.searchCustomersByPhone('');

        Test.stopTest();
    }

    @isTest
    static void testGetWishlistItemsNoData() {

        Account acc = new Account(
            Name = 'Empty Customer',
            Phone = '6666666666',
            Status__c = 'Prospect'
        );
        insert acc;

        Store__c store = [
            SELECT Id
            FROM Store__c
            LIMIT 1
        ];

        Sales_Executives__c salesExec = [
            SELECT Id
            FROM Sales_Executives__c
            LIMIT 1
        ];

        Showroom_Visit__c visit = new Showroom_Visit__c(
            CUSTOMERlookup__c = acc.Id,
        //    Customer_Phone__c = '6666666666',
            Visit_Date__c = Date.today(),
            StoreLookup__c = store.Id,
            Primary_Sales_Executive_Name__c = salesExec.Id
        );
        insert visit;

        Test.startTest();

        EstimationCreationController.getWishlistItems(visit.Id);

        Test.stopTest();
    }

    @isTest
static void testDuplicateWishlistOrderFlow() {

    Showroom_Visit__c visit = [
        SELECT Id, CUSTOMERlookup__c, StoreLookup__c
        FROM Showroom_Visit__c
        LIMIT 1
    ];

    Sales_Executive_Activity_Tracking__c tracking = [
        SELECT Id, Sales_Executive__c
        FROM Sales_Executive_Activity_Tracking__c
        LIMIT 1
    ];

    Wishlist_Item__c wi = [
        SELECT Id
        FROM Wishlist_Item__c
        LIMIT 1
    ];

    Customer_Order__c orderRec = new Customer_Order__c(
        Customer__c = visit.CUSTOMERlookup__c,
        Showroom_Visit__c = visit.Id,
        Store__c = visit.StoreLookup__c,
        Sales_Executives__c = tracking.Sales_Executive__c,
        Order_Date__c = Date.today(),
        Order_Status__c = 'Draft'
    );
    insert orderRec;

    Customer_Order_Line_Item__c li =
        new Customer_Order_Line_Item__c(
            Customer_Order__c = orderRec.Id,
            Wishlist_Item__c = wi.Id
        );
    insert li;

    Test.startTest();

    try {
        EstimationCreationController.createOrder(
            visit.Id,
            false,
            null,
            null,
            null,
            new List<Id>{ wi.Id },
            'Self',
            null,
            null,
            false,
            0,
            false,
            null,
            'Male'
        );
    } catch (Exception e) {
    }

    Test.stopTest();
    
}
    
    
    @isTest
static void testCreateOrderWithMotherRelation() {

    Showroom_Visit__c visit = [
        SELECT Id
        FROM Showroom_Visit__c
        LIMIT 1
    ];

    Wishlist_Item__c wi = [
        SELECT Id
        FROM Wishlist_Item__c
        WHERE Barcode_Value__c = 'BC001'
        LIMIT 1
    ];

    Test.startTest();

    EstimationCreationController.createOrder(
        visit.Id,
        true,
        'Mother Customer',
        '9111111111',
        'Mother',
        new List<Id>{ wi.Id },
        'Self',
        null,
        null,
        false,
        0,
        true,
        null,
        'Male'
    );

    Test.stopTest();
}

@isTest
static void testCreateOrderWithWifeRelation() {

    Account acc = new Account(
        Name = 'Female Customer',
        Phone = '9222222222',
        Status__c = 'Prospect',
        Gender__c = 'Female'
    );
    insert acc;

    Store__c store = [
        SELECT Id
        FROM Store__c
        LIMIT 1
    ];

    Sales_Executives__c salesExec = [
        SELECT Id
        FROM Sales_Executives__c
        LIMIT 1
    ];

    Showroom_Visit__c visit = new Showroom_Visit__c(
        CUSTOMERlookup__c = acc.Id,
    //    Customer_Phone__c = '9222222222',
        Visit_Date__c = Date.today(),
        StoreLookup__c = store.Id,
        Primary_Sales_Executive_Name__c = salesExec.Id
    );
    insert visit;

    Wishlist_Item__c wi = new Wishlist_Item__c(
    //    Name = 'Wishlist Wife',
        Showroom_Visit__c = visit.Id,
        Barcode_Value__c = 'BCWIFE',
        Description__c = 'Jewellery',
        Status__c = 'Available'
    //    Total_Price_Incl_GST__c = 4000
    );
    insert wi;

    Test.startTest();

    EstimationCreationController.createOrder(
        visit.Id,
        true,
        'Husband Customer',
        '9333333333',
        'Husband',
        new List<Id>{ wi.Id },
        'Self',
        null,
        null,
        false,
        0,
        false,
        null,
        'Female'
    );

    Test.stopTest();
}

@isTest
static void testCreateOrderWithBuyingForSon() {

    Account acc = new Account(
        Name = 'Parent Customer',
        Phone = '9444444444',
        Status__c = 'Prospect',
        Gender__c = 'Male'
    );
    insert acc;

    Store__c store = [
        SELECT Id
        FROM Store__c
        LIMIT 1
    ];

    Sales_Executives__c salesExec = [
        SELECT Id
        FROM Sales_Executives__c
        LIMIT 1
    ];

    Showroom_Visit__c visit = new Showroom_Visit__c(
        CUSTOMERlookup__c = acc.Id,
      //  Customer_Phone__c = '9444444444',
        Visit_Date__c = Date.today(),
        StoreLookup__c = store.Id,
        Primary_Sales_Executive_Name__c = salesExec.Id
    );
    insert visit;

    Wishlist_Item__c wi = new Wishlist_Item__c(
   //     Name = 'Wishlist Son',
        Showroom_Visit__c = visit.Id,
        Barcode_Value__c = 'BCSON',
        Description__c = 'Jewellery',
        Status__c = 'Available'
     //   Total_Price_Incl_GST__c = 5000
    );
    insert wi;

    Test.startTest();

    EstimationCreationController.createOrder(
        visit.Id,
        false,
        null,
        null,
        null,
        new List<Id>{ wi.Id },
        'Son',
        'Son Customer',
        '9555555555',
        false,
        0,
        false,
        null,
        'Male'
    );

    Test.stopTest();
}

@isTest
static void testCreateOrderWithExistingBillingCustomer() {

    Account billingAcc = new Account(
        Name = 'Existing Billing',
        Phone = '9666666666',
        Status__c = 'Prospect'
    );
    insert billingAcc;

    Showroom_Visit__c visit = [
        SELECT Id
        FROM Showroom_Visit__c
        LIMIT 1
    ];

    Wishlist_Item__c wi = [
        SELECT Id
        FROM Wishlist_Item__c
        WHERE Barcode_Value__c = 'BC002'
        LIMIT 1
    ];

    Test.startTest();

    EstimationCreationController.createOrder(
        visit.Id,
        true,
        'Existing Billing',
        '9666666666',
        'Brother',
        new List<Id>{ wi.Id },
        'Self',
        null,
        null,
        false,
        0,
        false,
        billingAcc.Id,
        'Male'
    );

    Test.stopTest();
}

@isTest
static void testGetWishlistItemsAgain() {

    Showroom_Visit__c visit = [
        SELECT Id
        FROM Showroom_Visit__c
        LIMIT 1
    ];

    Test.startTest();

    List<EstimationCreationController.WishlistItemDTO> result =
        EstimationCreationController.getWishlistItems(visit.Id);

    Test.stopTest();
}
@isTest
static void testMassFamilyRelationshipCoverage() {

    Store__c store = [
        SELECT Id
        FROM Store__c
        LIMIT 1
    ];

    Sales_Executives__c salesExec = [
        SELECT Id
        FROM Sales_Executives__c
        LIMIT 1
    ];

    Account rootAcc = new Account(
        Name = 'Root Customer',
        Phone = '7000000001',
        Status__c = 'Prospect',
        Gender__c = 'Male'
    );
    insert rootAcc;

    Showroom_Visit__c visit = new Showroom_Visit__c(
        CUSTOMERlookup__c = rootAcc.Id,
    //    Customer_Phone__c = '7000000001',
        Visit_Date__c = Date.today(),
        StoreLookup__c = store.Id,
        Primary_Sales_Executive_Name__c = salesExec.Id
    );
    insert visit;

    List<Wishlist_Item__c> wis = new List<Wishlist_Item__c>();

    wis.add(new Wishlist_Item__c(
   //     Name = 'Wishlist Father',
        Showroom_Visit__c = visit.Id,
        Barcode_Value__c = 'BCF1',
        Description__c = 'Jewellery',
        Status__c = 'Available'
     //   Total_Price_Incl_GST__c = 1000
    ));

    wis.add(new Wishlist_Item__c(
     //   Name = 'Wishlist Mother',
        Showroom_Visit__c = visit.Id,
        Barcode_Value__c = 'BCM1',
        Description__c = 'Jewellery',
        Status__c = 'Available'
     //   Total_Price_Incl_GST__c = 2000
    ));

    wis.add(new Wishlist_Item__c(
    //    Name = 'Wishlist Brother',
        Showroom_Visit__c = visit.Id,
        Barcode_Value__c = 'BCB1',
        Description__c = 'Jewellery',
        Status__c = 'Available'
      //  Total_Price_Incl_GST__c = 3000
    ));

    insert wis;

    Test.startTest();

    EstimationCreationController.createOrder(
        visit.Id,
        true,
        'Father Customer',
        '8000000001',
        'Father',
        new List<Id>{ wis[0].Id },
        'Self',
        null,
        null,
        false,
        0,
        false,
        null,
        'Male'
    );

    EstimationCreationController.createOrder(
        visit.Id,
        true,
        'Mother Customer',
        '8000000002',
        'Mother',
        new List<Id>{ wis[1].Id },
        'Self',
        null,
        null,
        false,
        0,
        false,
        null,
        'Male'
    );

    EstimationCreationController.createOrder(
        visit.Id,
        true,
        'Brother Customer',
        '8000000003',
        'Brother',
        new List<Id>{ wis[2].Id },
        'Self',
        null,
        null,
        false,
        0,
        false,
        null,
        'Male'
    );

    Test.stopTest();
}
}