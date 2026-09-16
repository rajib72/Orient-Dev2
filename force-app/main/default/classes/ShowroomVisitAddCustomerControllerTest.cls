@IsTest
public class ShowroomVisitAddCustomerControllerTest {

    @TestSetup
    static void setupTestData() {

        // Store created because Showroom Visit may have mandatory Store lookup
        Store__c store = new Store__c();
        store.Name = 'Test Store';
        store.Store_Code__c = 'TEST001';
        store.Location__c = 'Test Location';
        insert store;

        // Sales Executive created because Showroom Visit may have mandatory Sales Executive lookup
        Sales_Executives__c salesExecutive = new Sales_Executives__c();
        salesExecutive.Name = 'Test Sales Executive';
        salesExecutive.Store__c = store.Id;
        insert salesExecutive;

        // Existing customer
        Account acc = new Account();
        acc.Name = 'Existing Test Customer';
        acc.Phone = '9876543210';
        insert acc;

        // Showroom Visit record
        Showroom_Visit__c sv = new Showroom_Visit__c();
        sv.Customer_Name__c = 'Walk In Customer';
        sv.Phone__c = '9999999999';
        sv.Visit_Date__c = Date.today();
        sv.Entry_Time__c = Time.newInstance(10, 30, 0, 0);
        sv.Store_Interaction_Details__c = 'Test showroom visit description';
        sv.StoreLookup__c = store.Id;
        sv.Primary_Sales_Executive_Name__c = salesExecutive.Id;
        insert sv;
    }

    @IsTest
    static void testSearchCustomersByPhoneSuccess() {

        Test.startTest();
        List<ShowroomVisitAddCustomerController.CustomerWrapper> resultList =
            ShowroomVisitAddCustomerController.searchCustomersByPhone('987');
        Test.stopTest();

        System.assertNotEquals(null, resultList, 'Result list should not be null');
        System.assertEquals(1, resultList.size(), 'One matching customer should be returned');
        System.assertEquals('Existing Test Customer', resultList[0].customerName);
        System.assertEquals('9876543210', resultList[0].phone);
    }

    @IsTest
    static void testSearchCustomersByPhoneBlankValue() {

        Test.startTest();
        List<ShowroomVisitAddCustomerController.CustomerWrapper> resultList =
            ShowroomVisitAddCustomerController.searchCustomersByPhone('');
        Test.stopTest();

        System.assertNotEquals(null, resultList, 'Result list should not be null');
        System.assertEquals(0, resultList.size(), 'Blank phone should return empty list');
    }

    @IsTest
    static void testSearchCustomersByPhoneLessThanThreeDigits() {

        Test.startTest();
        List<ShowroomVisitAddCustomerController.CustomerWrapper> resultList =
            ShowroomVisitAddCustomerController.searchCustomersByPhone('98');
        Test.stopTest();

        System.assertNotEquals(null, resultList, 'Result list should not be null');
        System.assertEquals(0, resultList.size(), 'Less than 3 digits should return empty list');
    }

    @IsTest
    static void testAddExistingCustomerToShowroomVisit() {

        Account existingCustomer = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Phone = '9876543210'
            LIMIT 1
        ];

        Showroom_Visit__c sv = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Test.startTest();
        String message = ShowroomVisitAddCustomerController.addCustomerToShowroomVisit(
            sv.Id,
            '9876543210',
            'Existing Test Customer',
            existingCustomer.Id
        );
        Test.stopTest();

        System.assertEquals('Customer added successfully.', message);

        Showroom_Visit__c updatedVisit = [
            SELECT Id, CUSTOMERlookup__c, Customer_Name__c
            FROM Showroom_Visit__c
            WHERE Id = :sv.Id
            LIMIT 1
        ];

        System.assertEquals(existingCustomer.Id, updatedVisit.CUSTOMERlookup__c);
        System.assertEquals(existingCustomer.Name, updatedVisit.Customer_Name__c);
    }

    @IsTest
    static void testAddNewCustomerToShowroomVisit() {

        Showroom_Visit__c sv = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Test.startTest();
        String message = ShowroomVisitAddCustomerController.addCustomerToShowroomVisit(
            sv.Id,
            '8888888888',
            'New Test Customer',
            null
        );
        Test.stopTest();

        System.assertEquals('Customer added successfully.', message);

        Account newCustomer = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Phone = '8888888888'
            LIMIT 1
        ];

        Showroom_Visit__c updatedVisit = [
            SELECT Id, CUSTOMERlookup__c, Customer_Name__c
            FROM Showroom_Visit__c
            WHERE Id = :sv.Id
            LIMIT 1
        ];

        System.assertEquals(newCustomer.Id, updatedVisit.CUSTOMERlookup__c);
        System.assertEquals('New Test Customer', updatedVisit.Customer_Name__c);
    }

    @IsTest
    static void testAddCustomerMissingShowroomVisitId() {

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            ShowroomVisitAddCustomerController.addCustomerToShowroomVisit(
                null,
                '9876543210',
                'Test Customer',
                null
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown when Showroom Visit Id is missing');
    }

    @IsTest
    static void testAddCustomerMissingPhone() {

        Showroom_Visit__c sv = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            ShowroomVisitAddCustomerController.addCustomerToShowroomVisit(
                sv.Id,
                '',
                'Test Customer',
                null
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown when phone number is missing');
    }

    @IsTest
    static void testAddCustomerMissingName() {

        Showroom_Visit__c sv = [
            SELECT Id
            FROM Showroom_Visit__c
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            ShowroomVisitAddCustomerController.addCustomerToShowroomVisit(
                sv.Id,
                '9876543210',
                '',
                null
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown when customer name is missing');
    }
}