@IsTest
public class ActivityReportControllerTest {

    @TestSetup
    static void setupTestData() {

        // Create Store
        Store__c store = new Store__c();
        store.Name = 'Test Store';
        store.Store_Code__c = 'TEST001';
        store.Location__c = 'Test Location';
        insert store;

        // Create Sales Executive
        Sales_Executives__c salesExecutive = new Sales_Executives__c();
        salesExecutive.Name = 'Test Sales Executive';
        salesExecutive.Store__c = store.Id;
        insert salesExecutive;

        // Create Account
        Account acc = new Account();
        acc.Name = 'Test Customer Account';
        acc.Phone = '9876543210';
        insert acc;

        List<Showroom_Visit__c> visitList = new List<Showroom_Visit__c>();

        Showroom_Visit__c visit1 = new Showroom_Visit__c();
        visit1.Customer_Name__c = 'Test Customer 1';
        visit1.Phone__c = '9876543210';
        visit1.Visit_Date__c = Date.today();
        visit1.Entry_Time__c = Time.newInstance(10, 30, 0, 0);
        visit1.Exit_Time__c = Time.newInstance(11, 30, 0, 0);
        visit1.Store_Interaction_Details__c = 'Customer visited showroom for inquiry';
        visit1.CUSTOMERlookup__c = acc.Id;
        visit1.StoreLookup__c = store.Id;
        visit1.Primary_Sales_Executive_Name__c = salesExecutive.Id;
        visitList.add(visit1);

        Showroom_Visit__c visit2 = new Showroom_Visit__c();
        visit2.Customer_Name__c = 'Test Customer 2';
        visit2.Phone__c = '9876543211';
        visit2.Visit_Date__c = Date.today().addDays(-5);
        visit2.Entry_Time__c = Time.newInstance(12, 0, 0, 0);
        visit2.Exit_Time__c = Time.newInstance(13, 0, 0, 0);
        visit2.Store_Interaction_Details__c = 'Customer visited showroom for product demo';
        visit2.CUSTOMERlookup__c = acc.Id;
        visit2.StoreLookup__c = store.Id;
        visit2.Primary_Sales_Executive_Name__c = salesExecutive.Id;
        visitList.add(visit2);

        Showroom_Visit__c visit3 = new Showroom_Visit__c();
        visit3.Customer_Name__c = 'Old Customer';
        visit3.Phone__c = '9876543212';
        visit3.Visit_Date__c = Date.today().addDays(-30);
        visit3.Entry_Time__c = Time.newInstance(14, 0, 0, 0);
        visit3.Exit_Time__c = Time.newInstance(15, 0, 0, 0);
        visit3.Store_Interaction_Details__c = 'Old showroom visit';
        visit3.CUSTOMERlookup__c = acc.Id;
        visit3.StoreLookup__c = store.Id;
        visit3.Primary_Sales_Executive_Name__c = salesExecutive.Id;
        visitList.add(visit3);

        insert visitList;
    }

    @IsTest
    static void testGetVisitsWithValidDateRange() {

        Date startDate = Date.today().addDays(-10);
        Date endDate = Date.today();

        Test.startTest();
        List<Showroom_Visit__c> visits = ActivityReportController.getVisits(startDate, endDate);
        Test.stopTest();

        System.assertNotEquals(null, visits, 'Visit list should not be null');
        System.assertEquals(2, visits.size(), 'Only 2 showroom visits should come within date range');

        for (Showroom_Visit__c visit : visits) {
            System.assert(
                visit.Visit_Date__c >= startDate && visit.Visit_Date__c <= endDate,
                'Visit date should be inside selected date range'
            );
        }
    }

    @IsTest
    static void testGetVisitsWithNullStartDate() {

        Test.startTest();
        List<Showroom_Visit__c> visits = ActivityReportController.getVisits(null, Date.today());
        Test.stopTest();

        System.assertNotEquals(null, visits, 'Visit list should not be null');
        System.assertEquals(0, visits.size(), 'If start date is null, method should return empty list');
    }

    @IsTest
    static void testGetVisitsWithNullEndDate() {

        Test.startTest();
        List<Showroom_Visit__c> visits = ActivityReportController.getVisits(Date.today().addDays(-10), null);
        Test.stopTest();

        System.assertNotEquals(null, visits, 'Visit list should not be null');
        System.assertEquals(0, visits.size(), 'If end date is null, method should return empty list');
    }

    @IsTest
    static void testGetVisitsWithNoMatchingRecords() {

        Date startDate = Date.today().addDays(-100);
        Date endDate = Date.today().addDays(-90);

        Test.startTest();
        List<Showroom_Visit__c> visits = ActivityReportController.getVisits(startDate, endDate);
        Test.stopTest();

        System.assertNotEquals(null, visits, 'Visit list should not be null');
        System.assertEquals(0, visits.size(), 'No records should come for this date range');
    }
}