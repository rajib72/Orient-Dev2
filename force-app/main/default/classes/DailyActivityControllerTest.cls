@isTest
public class DailyActivityControllerTest {

    private static final String EXISTING_PHONE = '9999999999';
    private static final String WHATSAPP_ONLY_PHONE = '6666666666';
    private static final String PHONE_ONLY_PHONE = '5555555555';
    private static final String STORE_CODE = 'ST001';

    @testSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Existing Customer',
            Phone = EXISTING_PHONE,
            Whatsapp_Number__c = EXISTING_PHONE,
            Status__c = 'Prospect',
            Registration_Mode__c = 'CRM',
            Customer_Type__c = 'Walk-in'
        );
        insert acc;

        // Reachable only on WhatsApp: the lookup has to cope with a null Phone.
        Account whatsappOnly = new Account(
            Name = 'WhatsApp Only Customer',
            Whatsapp_Number__c = WHATSAPP_ONLY_PHONE,
            Status__c = 'Prospect',
            Registration_Mode__c = 'CRM',
            Customer_Type__c = 'Walk-in'
        );
        insert whatsappOnly;

        // The mirror case: a landline with no WhatsApp number.
        Account phoneOnly = new Account(
            Name = 'Phone Only Customer',
            Phone = PHONE_ONLY_PHONE,
            Status__c = 'Prospect',
            Registration_Mode__c = 'CRM',
            Customer_Type__c = 'Walk-in'
        );
        insert phoneOnly;

        Category__c cat = new Category__c(
            Name = 'Gold'
        );
        insert cat;

        Sub_Category__c subCat = new Sub_Category__c(
            Name = 'Ring',
            Category__c = cat.Id
        );
        insert subCat;

        Store__c storeRec = new Store__c(
            Name = 'Main Store',
            Store_Code__c = STORE_CODE
        );
        insert storeRec;

        Sales_Executives__c salesExec = new Sales_Executives__c(
            Name = 'Sales Executive',
            Store__c = storeRec.Id
        );
        insert salesExec;

        Purpose_Master__c purpose = new Purpose_Master__c(
            Purpose_Level_1__c = 'Wedding',
            Purpose_Level_2__c = 'Jewellery',
            Purpose_Level_3__c = 'Gold Ring'
        );
        insert purpose;
    }

    // ------------------------------------------------------------- HELPERS

    private static Id storeId() {
        return [SELECT Id FROM Store__c LIMIT 1].Id;
    }

    private static Id salesExecutiveId() {
        return [SELECT Id FROM Sales_Executives__c LIMIT 1].Id;
    }

    private static Id purposeId() {
        return [SELECT Id FROM Purpose_Master__c LIMIT 1].Id;
    }

    /**
     * The smallest form the controller will accept. Sales Executive is not
     * optional - saveDailyActivity refuses the whole request without one - so
     * every case builds on top of this rather than assembling a map by hand.
     */
    private static Map<String, Object> baseForm() {
        return new Map<String, Object>{
            'activityDate' => '2026-05-27',
            'activityTime' => '10:30',
            'store' => storeId(),
            'salesExecutive' => salesExecutiveId()
        };
    }

    private static User buildUser(String lastName, String alias, String locationCode) {
        return new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id,
            LastName = lastName,
            Email = alias + '@dailyactivitytest.com',
            Username = alias + DateTime.now().getTime() + '@dailyactivitytest.com',
            Alias = alias.left(8),
            CompanyName = 'TEST',
            TimeZoneSidKey = 'Asia/Kolkata',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            Location_Code__c = locationCode
        );
    }

    // -------------------------------------------------------- SAVE ACTIVITY

    @isTest
    static void testSaveDailyActivity_CreateAccount() {

        Map<String, Object> formData = baseForm();
        formData.put('customer', 'New Customer');
        formData.put('phone', '8888888888');
        formData.put('description', 'Test Visit');
        formData.put('category', 'Gold');
        formData.put('subCategory', 'Ring');
        formData.put('purposeMasterId', purposeId());
        formData.put('netWeight', '10');
        formData.put('budget', '50000');
        formData.put('purposeLevel1', 'Wedding');
        formData.put('purposeLevel2', 'Jewellery');
        formData.put('purposeLevel3', 'Gold Ring');

        Test.startTest();
        Id visitId = DailyActivityController.saveDailyActivity(formData, true);
        Test.stopTest();

        System.assertNotEquals(null, visitId);

        Showroom_Visit__c visit = [
            SELECT Customer_Name__c, Phone__c, Visit_Date__c, Category__c, Sub_Category__c,
                   Net_Weight__c, Budget__c, StoreLookup__c, Purpose_Level_1__c,
                   CUSTOMERlookup__c, Store_Interaction_Details__c
            FROM Showroom_Visit__c WHERE Id = :visitId
        ];
        System.assertEquals('New Customer', visit.Customer_Name__c);
        System.assertEquals('8888888888', visit.Phone__c);
        System.assertEquals(Date.newInstance(2026, 5, 27), visit.Visit_Date__c);
        System.assertEquals('Gold', visit.Category__c);
        System.assertEquals('Ring', visit.Sub_Category__c);
        System.assertEquals('10', visit.Net_Weight__c);
        System.assertEquals(50000, visit.Budget__c);
        System.assertEquals('Wedding', visit.Purpose_Level_1__c);
        System.assertEquals(storeId(), visit.StoreLookup__c);
        System.assertNotEquals(null, visit.CUSTOMERlookup__c, 'A new customer is created');

        Account created = [
            SELECT Name, Phone, Whatsapp_Number__c, Status__c, Registration_Mode__c, Customer_Type__c
            FROM Account WHERE Id = :visit.CUSTOMERlookup__c
        ];
        System.assertEquals('New Customer', created.Name);
        System.assertEquals('8888888888', created.Phone);
        System.assertEquals('8888888888', created.Whatsapp_Number__c);
        System.assertEquals('Prospect', created.Status__c);
        System.assertEquals('CRM', created.Registration_Mode__c);
        System.assertEquals('Walk-in', created.Customer_Type__c);

        // The visit is only half the record: tracking and feedback hang off it.
        Sales_Executive_Activity_Tracking__c tracking = [
            SELECT Session_Status__c, Session_Starting_Date__c, Orient_Customer__c, Sales_Executive__c
            FROM Sales_Executive_Activity_Tracking__c WHERE Showroom_Visit__c = :visitId
        ];
        System.assertEquals('Active', tracking.Session_Status__c);
        System.assertEquals(Date.newInstance(2026, 5, 27), tracking.Session_Starting_Date__c);
        System.assertEquals(visit.CUSTOMERlookup__c, tracking.Orient_Customer__c);
        System.assertEquals(salesExecutiveId(), tracking.Sales_Executive__c);

        Feedback__c feedback = [
            SELECT Status__c, Orient_Customer__c, Store__c, Visit_Date__c
            FROM Feedback__c WHERE Showroom_Visit__c = :visitId
        ];
        System.assertEquals('Pending', feedback.Status__c);
        System.assertEquals(visit.CUSTOMERlookup__c, feedback.Orient_Customer__c);
        System.assertEquals(storeId(), feedback.Store__c);
    }

    @isTest
    static void testSaveDailyActivity_ExistingAccount() {

        Id existingId = [SELECT Id FROM Account WHERE Phone = :EXISTING_PHONE LIMIT 1].Id;
        Integer accountsBefore = [SELECT COUNT() FROM Account];

        Map<String, Object> formData = baseForm();
        formData.put('customer', 'Existing Customer');
        formData.put('phone', EXISTING_PHONE);
        formData.put('activityTime', '11:45');
        formData.put('description', 'Existing Customer Visit');
        formData.put('category', 'Gold');
        formData.put('subCategory', 'Ring');
        formData.put('purposeMasterId', purposeId());

        Test.startTest();
        Id visitId = DailyActivityController.saveDailyActivity(formData, false);
        Test.stopTest();

        System.assertEquals(existingId,
            [SELECT CUSTOMERlookup__c FROM Showroom_Visit__c WHERE Id = :visitId].CUSTOMERlookup__c,
            'The matching customer is reused');
        System.assertEquals(accountsBefore, [SELECT COUNT() FROM Account],
            'No duplicate customer is created');
    }

    /** A customer we hold only on WhatsApp still matches, despite a null Phone. */
    @isTest
    static void testSaveDailyActivity_MatchesOnWhatsappWithNoPhone() {

        Id expectedId = [
            SELECT Id FROM Account WHERE Whatsapp_Number__c = :WHATSAPP_ONLY_PHONE LIMIT 1
        ].Id;
        Integer accountsBefore = [SELECT COUNT() FROM Account];

        Map<String, Object> formData = baseForm();
        formData.put('customer', 'WhatsApp Only Customer');
        formData.put('phone', WHATSAPP_ONLY_PHONE);

        Test.startTest();
        Id visitId = DailyActivityController.saveDailyActivity(formData, false);
        Test.stopTest();

        System.assertEquals(expectedId,
            [SELECT CUSTOMERlookup__c FROM Showroom_Visit__c WHERE Id = :visitId].CUSTOMERlookup__c);
        System.assertEquals(accountsBefore, [SELECT COUNT() FROM Account]);
    }

    /** And the mirror: a Phone match where the WhatsApp number is null. */
    @isTest
    static void testSaveDailyActivity_MatchesOnPhoneWithNoWhatsapp() {

        Id expectedId = [SELECT Id FROM Account WHERE Phone = :PHONE_ONLY_PHONE LIMIT 1].Id;
        Integer accountsBefore = [SELECT COUNT() FROM Account];

        Map<String, Object> formData = baseForm();
        formData.put('customer', 'Phone Only Customer');
        formData.put('phone', PHONE_ONLY_PHONE);

        Test.startTest();
        Id visitId = DailyActivityController.saveDailyActivity(formData, false);
        Test.stopTest();

        System.assertEquals(expectedId,
            [SELECT CUSTOMERlookup__c FROM Showroom_Visit__c WHERE Id = :visitId].CUSTOMERlookup__c);
        System.assertEquals(accountsBefore, [SELECT COUNT() FROM Account]);
    }

    /** A customer who gave no name and no number gets a visit but no Account. */
    @isTest
    static void testSaveDailyActivity_BlankCustomerAndPhone() {

        Integer accountsBefore = [SELECT COUNT() FROM Account];

        Map<String, Object> formData = baseForm();
        formData.put('activityTime', '12:15');
        formData.put('description', 'No Customer');

        Test.startTest();
        Id visitId = DailyActivityController.saveDailyActivity(formData, false);
        Test.stopTest();

        System.assertNotEquals(null, visitId);

        Showroom_Visit__c visit = [
            SELECT Customer_Name__c, Phone__c, CUSTOMERlookup__c, Store_Interaction_Details__c
            FROM Showroom_Visit__c WHERE Id = :visitId
        ];
        System.assertEquals(null, visit.CUSTOMERlookup__c,
            'Nothing identifies this walk-in, so no Account is invented for them');
        System.assertEquals(null, visit.Customer_Name__c,
            'The name is left empty rather than defaulted');
        System.assertEquals('No Customer', visit.Store_Interaction_Details__c);
        System.assertEquals(accountsBefore, [SELECT COUNT() FROM Account]);

        System.assertEquals(null,
            [SELECT Orient_Customer__c FROM Feedback__c
             WHERE Showroom_Visit__c = :visitId].Orient_Customer__c);
    }

    @isTest
    static void testSaveDailyActivity_WithFileUpload() {

        Map<String, Object> fileMap = new Map<String, Object>();
        fileMap.put('fileName', 'TestFile.txt');
        fileMap.put(
            'base64Data',
            EncodingUtil.base64Encode(Blob.valueOf('Sample File Content'))
        );

        // A row with nothing usable on it is skipped rather than failing the save.
        Map<String, Object> emptyFile = new Map<String, Object>();
        emptyFile.put('fileName', '');
        emptyFile.put('base64Data', '');

        List<Object> files = new List<Object>{ fileMap, emptyFile };

        Map<String, Object> formData = baseForm();
        formData.put('customer', 'File Customer');
        formData.put('phone', '7777777777');
        formData.put('activityTime', '09:15');
        formData.put('designFiles', files);

        Test.startTest();
        Id visitId = DailyActivityController.saveDailyActivity(formData, true);
        Test.stopTest();

        System.assertNotEquals(null, visitId);

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :visitId
        ];
        System.assertEquals(1, links.size(), 'Only the usable file is attached');

        ContentVersion saved = [
            SELECT Title, PathOnClient, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :links[0].ContentDocumentId
        ];
        System.assertEquals('TestFile.txt', saved.Title);
        System.assertEquals('TestFile.txt', saved.PathOnClient);
        System.assertEquals('Sample File Content', saved.VersionData.toString());
    }

    /** An empty file list is not an upload, and must not stop the save. */
    @isTest
    static void testSaveDailyActivity_WithEmptyFileList() {

        Map<String, Object> formData = baseForm();
        formData.put('customer', 'No File Customer');
        formData.put('phone', '7777770000');
        formData.put('designFiles', new List<Object>());

        Test.startTest();
        Id visitId = DailyActivityController.saveDailyActivity(formData, true);
        Test.stopTest();

        System.assertNotEquals(null, visitId);
        System.assertEquals(0, [
            SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :visitId
        ]);
    }

    @isTest
    static void testSaveDailyActivity_NullFormData() {

        Test.startTest();
        try {
            DailyActivityController.saveDailyActivity(null, false);
            System.assert(false, 'Expected an empty form to be refused');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    /** Every visit has to be attributable to somebody on the floor. */
    @isTest
    static void testSaveDailyActivity_RequiresSalesExecutive() {

        Map<String, Object> formData = new Map<String, Object>{
            'activityDate' => '2026-05-27',
            'activityTime' => '12:15',
            'customer' => 'Unattributed Customer',
            'phone' => '7000000000',
            'store' => storeId()
        };

        Test.startTest();
        try {
            DailyActivityController.saveDailyActivity(formData, false);
            System.assert(false, 'Expected a visit with no Sales Executive to be refused');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();

        System.assertEquals(0, [
            SELECT COUNT() FROM Showroom_Visit__c WHERE Phone__c = '7000000000'
        ], 'A refused save must not leave a visit behind');
    }

    // ------------------------------------------------------ SUPPORT METHODS

    @isTest
    static void testSearchAccountByPhone() {

        Test.startTest();
        List<Account> matches = DailyActivityController.searchAccountByPhone(EXISTING_PHONE);
        List<Account> punctuated = DailyActivityController.searchAccountByPhone('99999-99999');
        List<Account> withCountryCode = DailyActivityController.searchAccountByPhone('+91 9999999999');
        List<Account> none = DailyActivityController.searchAccountByPhone('   ');
        Test.stopTest();

        System.assertEquals(1, matches.size());
        System.assertEquals('Existing Customer', matches[0].Name);
        System.assertEquals(1, punctuated.size(), 'Spacing and dashes are stripped before matching');
        System.assertEquals(0, withCountryCode.size(),
            'Only non-digits are stripped - a country code is kept and stops the match');
        System.assertEquals(0, none.size(), 'A blank search returns nothing rather than everything');
    }

    @isTest
    static void testGetAllCategories() {

        Test.startTest();
        List<Category__c> categories = DailyActivityController.getAllCategories();
        Test.stopTest();

        System.assertEquals(1, categories.size());
        System.assertEquals('Gold', categories[0].Name);
    }

    @isTest
    static void testGetSubCategoriesByCategory() {

        Test.startTest();
        List<Sub_Category__c> subCategories =
            DailyActivityController.getSubCategoriesByCategory(new List<String>{ 'Gold' });
        Test.stopTest();

        System.assertEquals(1, subCategories.size());
        System.assertEquals('Ring', subCategories[0].Name);
    }

    @isTest
    static void testGetSubCategoriesByCategory_Empty() {

        Test.startTest();
        System.assertEquals(0,
            DailyActivityController.getSubCategoriesByCategory(null).size());
        System.assertEquals(0,
            DailyActivityController.getSubCategoriesByCategory(new List<String>()).size());
        System.assertEquals(0,
            DailyActivityController.getSubCategoriesByCategory(new List<String>{ 'Nothing' }).size());
        Test.stopTest();
    }

    @isTest
    static void testGetAllStores() {

        Test.startTest();
        List<Store__c> stores = DailyActivityController.getAllStores();
        Test.stopTest();

        System.assertEquals(1, stores.size());
        System.assertEquals('Main Store', stores[0].Name);
        System.assertEquals(STORE_CODE, stores[0].Store_Code__c);
    }

    @isTest
    static void testSearchPurpose() {

        Test.startTest();
        List<Purpose_Master__c> byLevel1 = DailyActivityController.searchPurpose('Wedd');
        // Nothing matches at level 1, so the search falls through to level 3.
        List<Purpose_Master__c> byLevel3 = DailyActivityController.searchPurpose('Gold Ring');
        List<Purpose_Master__c> noMatch = DailyActivityController.searchPurpose('Nothing At All');
        Test.stopTest();

        System.assertEquals(1, byLevel1.size());
        System.assertEquals('Wedding', byLevel1[0].Purpose_Level_1__c);
        System.assertEquals(1, byLevel3.size());
        System.assertEquals('Gold Ring', byLevel3[0].Purpose_Level_3__c);
        System.assertEquals(0, noMatch.size());
    }

    @isTest
    static void testSearchPurpose_Blank() {

        Test.startTest();
        System.assertEquals(0, DailyActivityController.searchPurpose(null).size());
        System.assertEquals(0, DailyActivityController.searchPurpose('  ').size());
        Test.stopTest();
    }

    @isTest
    static void testGetSalesExecutiveByStore() {

        Test.startTest();
        List<Sales_Executives__c> execs =
            DailyActivityController.getSalesExecutiveByStore(storeId());
        Test.stopTest();

        System.assertEquals(1, execs.size());
        System.assertEquals('Sales Executive', execs[0].Name);
    }

    @isTest
    static void testGetSalesExecutiveByStore_Null() {

        Test.startTest();
        System.assertEquals(0, DailyActivityController.getSalesExecutiveByStore(null).size());
        Test.stopTest();
    }

    // ----------------------------------------------------------- STORE ACCESS

    /** A user tied to a location sees that one store, pre-selected. */
    @isTest
    static void testGetStoreAccessInfo_UserWithMatchingLocation() {

        User located = buildUser('Located', 'loc', STORE_CODE);
        insert located;

        Test.startTest();
        System.runAs(located) {
            DailyActivityController.StoreAccessWrapper wrap =
                DailyActivityController.getStoreAccessInfo();

            System.assertEquals(1, wrap.stores.size());
            System.assertEquals('Main Store', wrap.stores[0].Name);
            System.assertEquals(storeId(), wrap.defaultStoreId);
        }
        Test.stopTest();
    }

    /** A location code with no store behind it selects nothing rather than guessing. */
    @isTest
    static void testGetStoreAccessInfo_UserWithUnknownLocation() {

        User elsewhere = buildUser('Elsewhere', 'else', 'ST-NONE');
        insert elsewhere;

        Test.startTest();
        System.runAs(elsewhere) {
            DailyActivityController.StoreAccessWrapper wrap =
                DailyActivityController.getStoreAccessInfo();

            System.assertEquals(0, wrap.stores.size());
            System.assertEquals(null, wrap.defaultStoreId);
        }
        Test.stopTest();
    }

    /** A user with no location at all can pick from every store. */
    @isTest
    static void testGetStoreAccessInfo_UserWithoutLocation() {

        User unlocated = buildUser('Unlocated', 'unloc', null);
        insert unlocated;

        Test.startTest();
        System.runAs(unlocated) {
            DailyActivityController.StoreAccessWrapper wrap =
                DailyActivityController.getStoreAccessInfo();

            System.assertEquals(1, wrap.stores.size());
            System.assertEquals('Main Store', wrap.stores[0].Name);
            System.assertEquals(null, wrap.defaultStoreId,
                'Nothing is pre-selected when the user is not tied to a store');
        }
        Test.stopTest();
    }
}