@IsTest
private class Ctrl_PurchaseBehaviourInsightsTest {

    @TestSetup
    static void setupTestData() {
        // Customer 1: Has insights
        Account acc1 = new Account(
            Name = 'Debolina Sen',
            Phone = '9876543210',
            WhatsApp_Number__c = '9876543210',
            Email_Address__c = 'debolina@example.com',
            BC_Customer_No__c = 'BC-99001',
            Preferred_Store_Name__c = 'Bowbazar Showroom'
        );
        insert acc1;

        // Customer 2: Has no insights
        Account acc2 = new Account(
            Name = 'Rahul Sharma',
            Phone = '9123456780',
            WhatsApp_Number__c = '9123456780',
            Email_Address__c = 'rahul@example.com',
            BC_Customer_No__c = 'BC-99002',
            Preferred_Store_Name__c = 'Gariahat Showroom'
        );
        insert acc2;

        Date today = Date.today();

        // Insight 1: Recent & High Frequency (VIP)
        Purchase_Behaviour_Insights__c pbi1 = new Purchase_Behaviour_Insights__c(
            Customer_Name__c = acc1.Id,
            Average_Ticket_Size__c = 185000,
            Purchase_Frequency__c = 5.2,
            Last_Purchase_Date__c = today.addDays(-20),
            Next_Expected_Purchase_Date__c = today.addDays(10), // DUE_SOON
            Purchase_Occasion__c = 'Wedding & Bridal'
        );
        insert pbi1;

        // Insight 2: Historical / Overdue next date / Regular Buyer
        Purchase_Behaviour_Insights__c pbi2 = new Purchase_Behaviour_Insights__c(
            Customer_Name__c = acc1.Id,
            Average_Ticket_Size__c = 65000,
            Purchase_Frequency__c = 2.5,
            Last_Purchase_Date__c = today.addDays(-150),
            Next_Expected_Purchase_Date__c = today.addDays(-10), // OVERDUE
            Purchase_Occasion__c = 'Festival & Diwali'
        );
        insert pbi2;

        // Customer 3: Occasional buyer with upcoming > 15 days
        Account acc3 = new Account(
            Name = 'Amit Roy',
            Phone = '9988776655',
            WhatsApp_Number__c = '9988776655'
        );
        insert acc3;

        Purchase_Behaviour_Insights__c pbi3 = new Purchase_Behaviour_Insights__c(
            Customer_Name__c = acc3.Id,
            Average_Ticket_Size__c = 25000,
            Purchase_Frequency__c = 1.2, // Occasional Buyer
            Last_Purchase_Date__c = today.addDays(-80),
            Next_Expected_Purchase_Date__c = today.addDays(45), // UPCOMING
            Purchase_Occasion__c = 'Birthday Gift'
        );
        insert pbi3;
    }

    @IsTest
    static void testSearchCustomersByPhone() {
        Test.startTest();
        // Exact phone search
        List<Ctrl_PurchaseBehaviourInsights.CustomerSearchResult> results1 =
            Ctrl_PurchaseBehaviourInsights.searchCustomersByPhone('9876543210');
        System.assertNotEquals(0, results1.size(), 'Should find customer by phone number');
        System.assertEquals('Debolina Sen', results1[0].customerName);

        // Partial phone with spaces
        List<Ctrl_PurchaseBehaviourInsights.CustomerSearchResult> results2 =
            Ctrl_PurchaseBehaviourInsights.searchCustomersByPhone('9876 54');
        System.assertNotEquals(0, results2.size(), 'Should find customer with formatted partial phone');

        // Empty phone
        List<Ctrl_PurchaseBehaviourInsights.CustomerSearchResult> resultsEmpty =
            Ctrl_PurchaseBehaviourInsights.searchCustomersByPhone('');
        System.assertEquals(0, resultsEmpty.size(), 'Empty search should return empty list');

        // Non-existent phone
        List<Ctrl_PurchaseBehaviourInsights.CustomerSearchResult> resultsNone =
            Ctrl_PurchaseBehaviourInsights.searchCustomersByPhone('0000000000');
        System.assertEquals(0, resultsNone.size(), 'Non-matching search should return empty list');
        Test.stopTest();
    }

    @IsTest
    static void testGetCustomerInsightsPayloadWithInsights() {
        Account acc = [SELECT Id FROM Account WHERE Phone = '9876543210' LIMIT 1];

        Test.startTest();
        Ctrl_PurchaseBehaviourInsights.CustomerInsightPayload payload =
            Ctrl_PurchaseBehaviourInsights.getCustomerInsightsPayload(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, payload, 'Payload should not be null');
        System.assertEquals(true, payload.hasInsights, 'Customer should have insights');
        System.assertEquals(2, payload.totalInsightsCount, 'Should have 2 insight records');
        System.assertNotEquals(null, payload.latestInsight, 'Latest insight should be populated');
        System.assertEquals('High Frequency • VIP', payload.latestInsight.frequencyTier);
        System.assertEquals('DUE_SOON', payload.latestInsight.nextPurchaseStatus);
        System.assertNotEquals(null, payload.latestInsight.averageTicketSize, 'ATS should be populated');
        System.assertNotEquals(null, payload.latestInsight.formattedTicketSize, 'Formatted ATS should not be null');

        // Check second insight (overdue, regular buyer)
        System.assertEquals('OVERDUE', payload.insights[1].nextPurchaseStatus);
        System.assertEquals('Regular Buyer', payload.insights[1].frequencyTier);
    }

    @IsTest
    static void testGetCustomerInsightsOccasionalBuyer() {
        Account acc = [SELECT Id FROM Account WHERE Phone = '9988776655' LIMIT 1];

        Test.startTest();
        Ctrl_PurchaseBehaviourInsights.CustomerInsightPayload payload =
            Ctrl_PurchaseBehaviourInsights.getCustomerInsightsPayload(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, payload);
        System.assertEquals('Occasional Buyer', payload.latestInsight.frequencyTier);
        System.assertEquals('UPCOMING', payload.latestInsight.nextPurchaseStatus);
    }

    @IsTest
    static void testGetCustomerInsightsPayloadWithoutInsights() {
        Account acc = [SELECT Id FROM Account WHERE Phone = '9123456780' LIMIT 1];

        Test.startTest();
        Ctrl_PurchaseBehaviourInsights.CustomerInsightPayload payload =
            Ctrl_PurchaseBehaviourInsights.getCustomerInsightsPayload(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, payload, 'Payload should not be null');
        System.assertEquals(false, payload.hasInsights, 'Customer should have no insights');
        System.assertEquals(0, payload.totalInsightsCount, 'Should have 0 insight records');
        System.assertEquals(null, payload.latestInsight, 'Latest insight should be null');
    }

    @IsTest
    static void testResolveRecordContext() {
        Account acc = [SELECT Id FROM Account WHERE Phone = '9876543210' LIMIT 1];
        Purchase_Behaviour_Insights__c pbi = [SELECT Id FROM Purchase_Behaviour_Insights__c WHERE Customer_Name__c = :acc.Id LIMIT 1];

        Test.startTest();
        // Resolve with Account Id
        Ctrl_PurchaseBehaviourInsights.CustomerInsightPayload payloadAcc =
            Ctrl_PurchaseBehaviourInsights.resolveRecordContext(acc.Id);
        System.assertNotEquals(null, payloadAcc);
        System.assertEquals('Debolina Sen', payloadAcc.customer.customerName);

        // Resolve with Insight Id
        Ctrl_PurchaseBehaviourInsights.CustomerInsightPayload payloadPbi =
            Ctrl_PurchaseBehaviourInsights.resolveRecordContext(pbi.Id);
        System.assertNotEquals(null, payloadPbi);
        System.assertEquals('Debolina Sen', payloadPbi.customer.customerName);

        // Resolve with null
        Ctrl_PurchaseBehaviourInsights.CustomerInsightPayload payloadNull =
            Ctrl_PurchaseBehaviourInsights.resolveRecordContext(null);
        System.assertEquals(null, payloadNull);
        Test.stopTest();
    }

    @IsTest
    static void testErrorHandling() {
        Test.startTest();
        Boolean caughtEx = false;
        try {
            Ctrl_PurchaseBehaviourInsights.getCustomerInsightsPayload(null);
        } catch (AuraHandledException ex) {
            caughtEx = true;
        }
        System.assert(caughtEx, 'Should throw AuraHandledException when ID is null');
        Test.stopTest();
    }
}