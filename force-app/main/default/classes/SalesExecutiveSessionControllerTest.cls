@isTest
public class SalesExecutiveSessionControllerTest {

    /* ================= MOCK DATA ================= */

    private static Store__c createStore() {
        Store__c st = new Store__c(
            Name = 'Main Store',
            Store_Code__c = 'ST001'
        );
        insert st;
        return st;
    }

    private static Account createAccount() {
        Account acc = new Account(
            Name = 'Test Customer',
            Phone = '9876543210'
        );
        insert acc;
        return acc;
    }

    private static Sales_Executives__c createSalesExecutive(
        String name,
        Store__c st
    ) {
        Sales_Executives__c se = new Sales_Executives__c(
            Name = name,
            code__c = name.replace(' ', '_'),
            Sales_Executive_Code__c = name.replace(' ', '_'),
            Store__c = st.Id
        );
        insert se;
        return se;
    }

    private static Showroom_Visit__c createVisit(
        Account acc,
        Store__c st
    ) {
        Showroom_Visit__c sv = new Showroom_Visit__c(
            CUSTOMERlookup__c = acc.Id,
            StoreLookup__c = st.Id
        );
        insert sv;
        return sv;
    }

    private static Sales_Executive_Activity_Tracking__c createSession(
        Id visitId,
        Id salesExecId
    ) {
        Sales_Executive_Activity_Tracking__c s =
            new Sales_Executive_Activity_Tracking__c(
                Showroom_Visit__c = visitId,
                Sales_Executive__c = salesExecId,
                Session_Status__c = 'Active',
                Session_Starting_Date__c = System.today(),
                Session_Start_Time__c = System.now().time().addSeconds(-600)
            );

        insert s;
        return s;
    }

    /* ================= TEST GET SESSIONS ================= */

    @isTest
    static void testGetSessions() {

        Store__c st = createStore();
        Account acc = createAccount();

        Sales_Executives__c se =
            createSalesExecutive('Exec One', st);

        Showroom_Visit__c sv =
            createVisit(acc, st);

        createSession(sv.Id, se.Id);

        Test.startTest();

        SalesExecutiveSessionController.getSessions(sv.Id);

        Test.stopTest();
    }

    /* ================= TEST GET SALES EXECUTIVES ================= */

    @isTest
    static void testGetSalesExecutivesByShowroom() {

        Store__c st = createStore();
        Account acc = createAccount();

        createSalesExecutive('Exec One', st);
        createSalesExecutive('Exec Two', st);

        Showroom_Visit__c sv =
            createVisit(acc, st);

        Test.startTest();

        SalesExecutiveSessionController.getSalesExecutivesByShowroom(
            sv.Id
        );

        Test.stopTest();
    }

    /* ================= TEST HANDOVER SESSION ================= */

    @isTest
    static void testHandoverSession() {

        Store__c st = createStore();
        Account acc = createAccount();

        Sales_Executives__c se1 =
            createSalesExecutive('Exec One', st);

        Sales_Executives__c se2 =
            createSalesExecutive('Exec Two', st);

        Showroom_Visit__c sv =
            createVisit(acc, st);

        createSession(sv.Id, se1.Id);

        Test.startTest();

        SalesExecutiveSessionController.handoverSession(
            sv.Id,
            se2.Id
        );

        Test.stopTest();
    }

    /* ================= TEST SAME EXECUTIVE HANDOVER ================= */

    @isTest
    static void testHandoverSameExecutive() {

        Store__c st = createStore();
        Account acc = createAccount();

        Sales_Executives__c se1 =
            createSalesExecutive('Exec One', st);

        Showroom_Visit__c sv =
            createVisit(acc, st);

        createSession(sv.Id, se1.Id);

        Test.startTest();

        try {
            SalesExecutiveSessionController.handoverSession(
                sv.Id,
                se1.Id
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    /* ================= TEST MARK SESSION EXIT ================= */

    @isTest
    static void testMarkSessionExit() {

        Store__c st = createStore();
        Account acc = createAccount();

        Sales_Executives__c se =
            createSalesExecutive('Exec One', st);

        Showroom_Visit__c sv =
            createVisit(acc, st);

        createSession(sv.Id, se.Id);

        Time validEndTime =
            System.now().time().addSeconds(-60);

        String endTimeStr =
            String.valueOf(validEndTime.hour()).leftPad(2, '0') +
            ':' +
            String.valueOf(validEndTime.minute()).leftPad(2, '0') +
            ':' +
            String.valueOf(validEndTime.second()).leftPad(2, '0');

        Test.startTest();

        SalesExecutiveSessionController.markSessionExit(
            sv.Id,
            System.today(),
            endTimeStr,
            '00:10:00'
        );

        Test.stopTest();
    }

    /* ================= TEST MARK EXIT WITH FOLLOWUP ================= */

    @isTest
    static void testMarkSessionExitWithFollowUp() {

        Store__c st = createStore();
        Account acc = createAccount();

        Sales_Executives__c se =
            createSalesExecutive('Exec One', st);

        Showroom_Visit__c sv =
            createVisit(acc, st);

        createSession(sv.Id, se.Id);

        Time validEndTime =
            System.now().time().addSeconds(-60);

        String endTimeStr =
            String.valueOf(validEndTime.hour()).leftPad(2, '0') +
            ':' +
            String.valueOf(validEndTime.minute()).leftPad(2, '0') +
            ':' +
            String.valueOf(validEndTime.second()).leftPad(2, '0');

        Test.startTest();

        SalesExecutiveSessionController.markSessionExitWithFollowUp(
            sv.Id,
            System.today(),
            endTimeStr,
            '00:15:00',
            System.today().addDays(2)
        );

        Test.stopTest();
    }

    /* ================= TEST FOLLOWUP PAST DATE ================= */

    @isTest
    static void testFollowUpPastDate() {

        Store__c st = createStore();
        Account acc = createAccount();

        Sales_Executives__c se =
            createSalesExecutive('Exec One', st);

        Showroom_Visit__c sv =
            createVisit(acc, st);

        createSession(sv.Id, se.Id);

        Time validEndTime =
            System.now().time().addSeconds(-60);

        String endTimeStr =
            String.valueOf(validEndTime.hour()).leftPad(2, '0') +
            ':' +
            String.valueOf(validEndTime.minute()).leftPad(2, '0') +
            ':' +
            String.valueOf(validEndTime.second()).leftPad(2, '0');

        Test.startTest();

        try {
            SalesExecutiveSessionController.markSessionExitWithFollowUp(
                sv.Id,
                System.today(),
                endTimeStr,
                '00:15:00',
                System.today().addDays(-1)
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    /* ================= TEST NULL SHOWROOM ================= */

    @isTest
    static void testNullInputs() {

        Test.startTest();

        SalesExecutiveSessionController.getSessions(null);

        SalesExecutiveSessionController.getSalesExecutivesByShowroom(
            null
        );

        try {
            SalesExecutiveSessionController.handoverSession(
                null,
                null
            );
        } catch (Exception e) {
        }

        Test.stopTest();
    }
}