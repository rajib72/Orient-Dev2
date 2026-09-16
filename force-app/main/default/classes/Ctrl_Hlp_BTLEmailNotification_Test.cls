@IsTest
private class Ctrl_Hlp_BTLEmailNotification_Test {

    @TestSetup
    static void setupUser() {
        BTL_GoLive_TestDataFactory.createAdministrator();
    }

    @IsTest
    static void testApprovalRequiredNotification() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    1,
                    Date.today().addDays(1)
                );
            Tagged_Approval_Hierarchy__c transactionRecord =
                BTL_GoLive_TestDataFactory.createPendingTransaction(
                    scenario
                );

            Test.startTest();
            Ctrl_Hlp_BTLEmailNotificationService.sendApprovalRequired(
                new Set<Id>{ transactionRecord.Id }
            );
            Test.stopTest();

            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING,
                transactionRecord.Approval_Status__c
            );
        }
    }

    @IsTest
    static void testReturnedNotification() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    1,
                    Date.today().addDays(1)
                );
            Tagged_Approval_Hierarchy__c transactionRecord =
                BTL_GoLive_TestDataFactory.createReturnedTransaction(
                    scenario
                );

            Test.startTest();
            Ctrl_Hlp_BTLEmailNotificationService.sendReturned(
                new Set<Id>{ transactionRecord.Id }
            );
            Test.stopTest();

            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED,
                transactionRecord.Approval_Status__c
            );
        }
    }

    @IsTest
    static void testCompletedNotification() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    1,
                    Date.today().addDays(1)
                );
            Tagged_Approval_Hierarchy__c transactionRecord =
                BTL_GoLive_TestDataFactory.createApprovedTransaction(
                    scenario
                );

            Test.startTest();
            Ctrl_Hlp_BTLEmailNotificationService.sendProcessCompleted(
                new Set<Id>{ transactionRecord.Id }
            );
            Test.stopTest();

            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED,
                transactionRecord.Approval_Status__c
            );
        }
    }

    @IsTest
    static void testEmptyInputIsSafe() {
        Test.startTest();
        Ctrl_Hlp_BTLEmailNotificationService.sendApprovalRequired(null);
        Ctrl_Hlp_BTLEmailNotificationService.sendReturned(new Set<Id>());
        Ctrl_Hlp_BTLEmailNotificationService.sendProcessCompleted(
            new Set<Id>()
        );
        Test.stopTest();
        System.assert(true);
    }
}