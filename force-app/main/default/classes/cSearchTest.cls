@IsTest
private class cSearchTest {

    private static final String PHONE_MAIN = '9990001111';
    private static final String WHATSAPP_ONLY = '8880002222';
    private static final String PHONE_QUIET = '7770003333';

    @testSetup
    static void setupData() {

        Account withPhone = new Account(
            Name = 'Journey Customer',
            Phone = PHONE_MAIN,
            WhatsApp_Number__c = PHONE_MAIN,
            Email_Address__c = 'journey@test.com',
            Date_Of_Birth__c = Date.newInstance(1990, 5, 20),
            Anniversary_Date__c = Date.newInstance(2015, 11, 2),
            BC_Customer_No__c = 'BC-JOURNEY-1',
            DOB_Verified__c = true
        );

        // Reachable only on WhatsApp, so the Phone half of the OR is null.
        Account whatsappOnly = new Account(
            Name = 'WhatsApp Customer',
            WhatsApp_Number__c = WHATSAPP_ONLY
        );

        // Exists, but has never visited and never bought anything.
        Account quiet = new Account(
            Name = 'Quiet Customer',
            Phone = PHONE_QUIET
        );

        insert new List<Account>{ withPhone, whatsappOnly, quiet };

        Store__c store = new Store__c(Name = 'Kiosk Store', Store_Code__c = 'KS-01');
        insert store;

        Showroom_Visit__c todayVisit = new Showroom_Visit__c(
            CUSTOMERlookup__c = withPhone.Id,
            StoreLookup__c = store.Id,
            Visit_Date__c = Date.today(),
            Entry_Time__c = Time.newInstance(10, 30, 0, 0),
            Last_Visit_Date__c = Date.today(),
            Last_Purchased_Date__c = Date.today().addDays(-30)
        );

        Showroom_Visit__c olderVisit = new Showroom_Visit__c(
            CUSTOMERlookup__c = withPhone.Id,
            StoreLookup__c = store.Id,
            Visit_Date__c = Date.today().addDays(-5),
            Last_Visit_Date__c = Date.today().addDays(-5),
            Last_Purchased_Date__c = Date.today().addDays(-90)
        );

        Showroom_Visit__c whatsappVisit = new Showroom_Visit__c(
            CUSTOMERlookup__c = whatsappOnly.Id,
            StoreLookup__c = store.Id,
            Visit_Date__c = Date.today()
        );

        insert new List<Showroom_Visit__c>{ todayVisit, olderVisit, whatsappVisit };

        // CreatedDate is what the visit searches filter on, and it cannot be set
        // on insert - only moved afterwards.
        Test.setCreatedDate(olderVisit.Id, DateTime.now().addDays(-5));

        insert new Feedback__c(
            Showroom_Visit__c = todayVisit.Id,
            Orient_Customer__c = withPhone.Id,
            Status__c = 'Completed',
            Submitted_Date_Time__c = System.now()
        );

        insert new List<Invoice__c>{
            new Invoice__c(Customer_Name__c = withPhone.Id, Total_Invoice_Amount__c = 15000),
            new Invoice__c(Customer_Name__c = withPhone.Id, Total_Invoice_Amount__c = 5000)
        };
    }

    private static Id accountIdNamed(String name) {
        return [SELECT Id FROM Account WHERE Name = :name LIMIT 1].Id;
    }

    // ------------------------------------------------------ ACCOUNT SEARCH

    @IsTest
    static void testSearchAccountsByPhone() {

        Test.startTest();
        List<Account> byPhone = cSearch.searchAccountsByPhone(PHONE_MAIN);
        List<Account> byPrefix = cSearch.searchAccountsByPhone('9990');
        List<Account> byWhatsapp = cSearch.searchAccountsByPhone(WHATSAPP_ONLY);
        List<Account> padded = cSearch.searchAccountsByPhone('  ' + PHONE_QUIET + '  ');
        Test.stopTest();

        System.assertEquals(1, byPhone.size());
        System.assertEquals('Journey Customer', byPhone[0].Name);
        System.assertEquals(PHONE_MAIN, byPhone[0].Phone);

        System.assertEquals(1, byPrefix.size(), 'A leading fragment is enough');

        System.assertEquals(1, byWhatsapp.size(),
            'A customer held only on WhatsApp is still found');
        System.assertEquals('WhatsApp Customer', byWhatsapp[0].Name);

        System.assertEquals(1, padded.size(), 'The key is trimmed before searching');
        System.assertEquals('Quiet Customer', padded[0].Name);
    }

    @IsTest
    static void testSearchAccountsByPhoneWithNoKey() {

        Test.startTest();
        System.assertEquals(0, cSearch.searchAccountsByPhone(null).size());
        System.assertEquals(0, cSearch.searchAccountsByPhone('').size());
        System.assertEquals(0, cSearch.searchAccountsByPhone('   ').size());
        Test.stopTest();
    }

    /** The match is anchored at the start: a middle fragment finds nothing. */
    @IsTest
    static void testSearchAccountsByPhoneMatchesPrefixOnly() {

        Test.startTest();
        List<Account> middleFragment = cSearch.searchAccountsByPhone('0001111');
        List<Account> unknown = cSearch.searchAccountsByPhone('1234');
        Test.stopTest();

        System.assertEquals(0, middleFragment.size());
        System.assertEquals(0, unknown.size());
    }

    // -------------------------------------------------------- VISIT SEARCH

    @IsTest
    static void testSearchVisitsByPhone() {

        Test.startTest();
        List<Showroom_Visit__c> visits = cSearch.searchVisitsByPhone(PHONE_MAIN);
        Test.stopTest();

        System.assertEquals(1, visits.size(),
            'Only today counts - the backdated visit is not returned');

        Showroom_Visit__c visit = visits[0];
        System.assertEquals('Journey Customer', visit.CUSTOMERlookup__r.Name);
        System.assertEquals(PHONE_MAIN, visit.CUSTOMERlookup__r.Phone);
        System.assertEquals('journey@test.com', visit.CUSTOMERlookup__r.Email_Address__c);
        System.assertEquals('BC-JOURNEY-1', visit.CUSTOMERlookup__r.BC_Customer_No__c);
        System.assertEquals(true, visit.CUSTOMERlookup__r.DOB_Verified__c);
        System.assertEquals('Kiosk Store', visit.StoreLookup__r.Name);
        System.assertEquals(Time.newInstance(10, 30, 0, 0), visit.Entry_Time__c);

        System.assertEquals(1, visit.Feedbacks__r.size(),
            'The kiosk needs the feedback state in the same round trip');
        System.assertEquals('Completed', visit.Feedbacks__r[0].Status__c);
    }

    @IsTest
    static void testSearchVisitsByPhoneFindsWhatsappCustomer() {

        Test.startTest();
        List<Showroom_Visit__c> visits = cSearch.searchVisitsByPhone(WHATSAPP_ONLY);
        Test.stopTest();

        System.assertEquals(1, visits.size());
        System.assertEquals('WhatsApp Customer', visits[0].CUSTOMERlookup__r.Name);
        System.assertEquals(0, visits[0].Feedbacks__r.size(),
            'This visit has no feedback yet, and that is not an error');
    }

    @IsTest
    static void testSearchVisitsByPhoneWithNoKey() {

        Test.startTest();
        System.assertEquals(0, cSearch.searchVisitsByPhone(null).size());
        System.assertEquals(0, cSearch.searchVisitsByPhone('  ').size());
        Test.stopTest();
    }

    @IsTest
    static void testSearchVisitsByPhoneWithNoMatchingCustomer() {

        Test.startTest();
        List<Showroom_Visit__c> visits = cSearch.searchVisitsByPhone('1234');
        Test.stopTest();

        System.assertEquals(0, visits.size());
    }

    /** A known customer who has not come in today has no visits to show. */
    @IsTest
    static void testSearchVisitsByPhoneForCustomerWithNoVisitToday() {

        Test.startTest();
        List<Showroom_Visit__c> visits = cSearch.searchVisitsByPhone(PHONE_QUIET);
        Test.stopTest();

        System.assertEquals(0, visits.size());
    }

    // ----------------------------------------------------- CUSTOMER JOURNEY

    @IsTest
    static void testSearchCustomerJourney() {

        Test.startTest();
        cSearch.CustomerJourneyWrapper result = cSearch.searchCustomerJourney(PHONE_MAIN);
        Test.stopTest();

        System.assertNotEquals(null, result.customer);
        System.assertEquals('Journey Customer', result.customer.Name);
        System.assertEquals('journey@test.com', result.customer.Email_Address__c);
        System.assertEquals(Date.newInstance(1990, 5, 20), result.customer.Date_Of_Birth__c);
        System.assertEquals(Date.newInstance(2015, 11, 2), result.customer.Anniversary_Date__c);
        System.assertEquals('BC-JOURNEY-1', result.customer.BC_Customer_No__c);

        System.assertEquals(1, result.visits.size());
        System.assertEquals('Kiosk Store', result.visits[0].StoreLookup__r.Name);
        System.assertEquals(1, result.visits[0].Feedbacks__r.size());
    }

    /**
     * The point of the single round trip: the profile screen still opens for a
     * customer who has not been in today.
     */
    @IsTest
    static void testSearchCustomerJourneyReturnsCustomerWithoutVisits() {

        Test.startTest();
        cSearch.CustomerJourneyWrapper result = cSearch.searchCustomerJourney(PHONE_QUIET);
        Test.stopTest();

        System.assertNotEquals(null, result.customer, 'The customer is returned regardless');
        System.assertEquals('Quiet Customer', result.customer.Name);
        System.assertEquals(0, result.visits.size());
    }

    @IsTest
    static void testSearchCustomerJourneyWithNoKey() {

        Test.startTest();
        cSearch.CustomerJourneyWrapper blank = cSearch.searchCustomerJourney('   ');
        cSearch.CustomerJourneyWrapper nullKey = cSearch.searchCustomerJourney(null);
        Test.stopTest();

        System.assertEquals(null, blank.customer);
        System.assertEquals(0, blank.visits.size(),
            'The visit list is always a list, never null, so the LWC can iterate it');
        System.assertEquals(null, nullKey.customer);
        System.assertEquals(0, nullKey.visits.size());
    }

    @IsTest
    static void testSearchCustomerJourneyWithNoMatch() {

        Test.startTest();
        cSearch.CustomerJourneyWrapper result = cSearch.searchCustomerJourney('1234');
        Test.stopTest();

        System.assertEquals(null, result.customer);
        System.assertEquals(0, result.visits.size());
    }

    // ----------------------------------------------------- CUSTOMER SUMMARY

    @IsTest
    static void testGetCustomerSummary() {

        Id accountId = accountIdNamed('Journey Customer');

        Test.startTest();
        List<cSearch.CustomerSummaryWrapper> summary = cSearch.getCustomerSummary(accountId);
        Test.stopTest();

        System.assertEquals(1, summary.size());

        cSearch.CustomerSummaryWrapper row = summary[0];
        System.assertEquals('Journey Customer', row.CustomerName);
        System.assertEquals(PHONE_MAIN, row.Phone);
        System.assertEquals(accountId, row.AccountId);
        System.assertEquals(20000, row.TotalInvoiceAmount, 'Both invoices are added up');
        System.assertEquals(Date.today(), row.LastVisitDate,
            'The most recent visit wins');
        System.assertEquals(Date.today().addDays(-30), row.LastPurchasedDate);
    }

    /** A customer with no history still gets a row, just an empty one. */
    @IsTest
    static void testGetCustomerSummaryForCustomerWithNoHistory() {

        Id accountId = accountIdNamed('Quiet Customer');

        Test.startTest();
        List<cSearch.CustomerSummaryWrapper> summary = cSearch.getCustomerSummary(accountId);
        Test.stopTest();

        System.assertEquals(1, summary.size());

        cSearch.CustomerSummaryWrapper row = summary[0];
        System.assertEquals('Quiet Customer', row.CustomerName);
        System.assertEquals(accountId, row.AccountId);
        System.assertEquals(null, row.LastVisitDate);
        System.assertEquals(null, row.LastPurchasedDate);
        System.assertEquals(null, row.TotalInvoiceAmount,
            'SUM over no rows is null, not zero');
    }

    /**
     * There is no guard on the customer lookup, so an id that resolves to
     * nothing surfaces as a raw QueryException rather than a handled message.
     */
    @IsTest
    static void testGetCustomerSummaryWithUnknownCustomer() {

        Test.startTest();
        try {
            cSearch.getCustomerSummary('001000000000000AAA');
            System.assert(false, 'Expected the missing customer to stop the call');
        } catch (QueryException e) {
            System.assert(e.getMessage().contains('List has no rows'), e.getMessage());
        }

        try {
            cSearch.getCustomerSummary(null);
            System.assert(false, 'Expected a null customer Id to stop the call');
        } catch (QueryException e) {
            System.assert(e.getMessage().contains('List has no rows'), e.getMessage());
        }
        Test.stopTest();
    }
}