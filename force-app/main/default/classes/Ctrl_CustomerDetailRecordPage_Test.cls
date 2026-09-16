@IsTest
public class Ctrl_CustomerDetailRecordPage_Test {

    @TestSetup
    static void setupData() {

        Account acc1 = new Account();
        acc1.Name = 'Test Customer 1';
        acc1.Phone = '9876543210';
        acc1.Whatsapp_number__c = '9876543210';
        acc1.Status__c = 'Active';
        insert acc1;

        Account acc2 = new Account();
        acc2.Name = 'Test Customer 2';
        acc2.Phone = '9999999999';
        acc2.Whatsapp_number__c = '9999999999';
        acc2.Status__c = 'Active';
        insert acc2;

        Orient_Customer_Tracking__c tracking = new Orient_Customer_Tracking__c();
        tracking.Orient_Customer__c = acc1.Id;
        tracking.Customer_Name__c = true;
        tracking.Phone__c = true;
        tracking.Email_Address__c = true;
        insert tracking;

        Showroom_Visit__c visitRec = new Showroom_Visit__c();
        visitRec.CUSTOMERlookup__c = acc1.Id;
        insert visitRec;
    }

    @IsTest
    static void testGetTrackingRecord() {

        Account acc = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        Test.startTest();

        Orient_Customer_Tracking__c result =
            Ctrl_CustomerDetailRecordPage.getTrackingRecord(acc.Id);

        Test.stopTest();

        if (result != null) {

    Id trackingId = result.Id;
    Boolean customerName = result.Customer_Name__c;
}
    }

    @IsTest
    static void testCheckDuplicateAccountWithPhoneAndWhatsapp() {

        List<Account> accList = [
            SELECT Id, Phone, Whatsapp_number__c
            FROM Account
            ORDER BY CreatedDate ASC
        ];

        Account currentAcc = accList[0];
        Account existingAcc = accList[1];

        Test.startTest();

        Account duplicateAcc =
            Ctrl_CustomerDetailRecordPage.checkDuplicateAccount(
                existingAcc.Phone,
                existingAcc.Whatsapp_number__c,
                currentAcc.Id
            );

        Test.stopTest();

        if (duplicateAcc != null) {

            Id accId = duplicateAcc.Id;
            String accName = duplicateAcc.Name;
        }
    }

    @IsTest
    static void testCheckDuplicateAccountWithOnlyPhone() {

        List<Account> accList = [
            SELECT Id, Phone
            FROM Account
            ORDER BY CreatedDate ASC
        ];

        Account currentAcc = accList[0];
        Account existingAcc = accList[1];

        Test.startTest();

        Account duplicateAcc =
            Ctrl_CustomerDetailRecordPage.checkDuplicateAccount(
                existingAcc.Phone,
                null,
                currentAcc.Id
            );

        Test.stopTest();

        if (duplicateAcc != null) {

            Id accId = duplicateAcc.Id;
        }
    }

    @IsTest
    static void testCheckDuplicateAccountWithOnlyWhatsapp() {

        List<Account> accList = [
            SELECT Id, Whatsapp_number__c
            FROM Account
            ORDER BY CreatedDate ASC
        ];

        Account currentAcc = accList[0];
        Account existingAcc = accList[1];

        Test.startTest();

        Account duplicateAcc =
            Ctrl_CustomerDetailRecordPage.checkDuplicateAccount(
                null,
                existingAcc.Whatsapp_number__c,
                currentAcc.Id
            );

        Test.stopTest();

        if (duplicateAcc != null) {

            Id accId = duplicateAcc.Id;
        }
    }

    @IsTest
    static void testCheckDuplicateAccountNoDuplicate() {

        Account acc = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        Test.startTest();

        Account duplicateAcc =
            Ctrl_CustomerDetailRecordPage.checkDuplicateAccount(
                '1111111111',
                '2222222222',
                acc.Id
            );

        Test.stopTest();
    }

    @IsTest
    static void testMergeAndInactiveAccount() {

        List<Account> accList = [
            SELECT Id, Status__c
            FROM Account
            ORDER BY CreatedDate ASC
        ];

        Account currentAcc = accList[0];
        Account existingAcc = accList[1];

        Test.startTest();

        Ctrl_CustomerDetailRecordPage.mergeAndInactiveAccount(
            currentAcc.Id,
            existingAcc.Id
        );

        Test.stopTest();

        List<Showroom_Visit__c> updatedVisits = [
            SELECT Id, CUSTOMERlookup__c
            FROM Showroom_Visit__c
            WHERE CUSTOMERlookup__c = :existingAcc.Id
        ];

        for (Showroom_Visit__c visitRec : updatedVisits) {

            Id visitId = visitRec.Id;
            Id customerId = visitRec.CUSTOMERlookup__c;
        }
    }

    @IsTest
    static void testGetTrackingRecordNoData() {

        Account acc = new Account();
        acc.Name = 'No Tracking Account';
        insert acc;

        Test.startTest();

        Orient_Customer_Tracking__c result =
            Ctrl_CustomerDetailRecordPage.getTrackingRecord(acc.Id);

        Test.stopTest();
    }

    @IsTest
    static void testMergeAndInactiveAccountException() {

        Test.startTest();

        try {

            Ctrl_CustomerDetailRecordPage.mergeAndInactiveAccount(
                null,
                null
            );

        } catch (Exception e) {

            String errMsg = e.getMessage();
        }

        Test.stopTest();
    }
}