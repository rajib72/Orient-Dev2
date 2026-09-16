@IsTest
private class Ctrl_Hlp_BTLApprovalActionService_Test {

    @TestSetup
    static void setupUser() {
        BTL_GoLive_TestDataFactory.createAdministrator();
    }

    @IsTest
    static void testApproveAdvancesToNextLevel() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    2,
                    Date.today().addDays(1)
                );

            Tagged_Approval_Hierarchy__c transactionRecord =
                BTL_GoLive_TestDataFactory.createPendingTransaction(
                    scenario
                );

            Test.startTest();
            Map<String, Object> result =
                Ctrl_Hlp_BTLApprovalActionService.approve(
                    transactionRecord.Id,
                    'First level approved'
                );
            transactionRecord =
                BTL_GoLive_TestDataFactory.getTransactionByDate(
                    scenario.dateRecord.Id
                );
            Test.stopTest();

            System.assertEquals(true, result.get('success'));
            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING,
                transactionRecord.Approval_Status__c
            );
            System.assertEquals(
                scenario.levels[1].Id,
                transactionRecord.Current_Approval_Level__c
            );
        }
    }

    @IsTest
    static void testFinalApproval() {
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
            Map<String, Object> result =
                Ctrl_Hlp_BTLApprovalActionService.approveMany(
                    new Set<Id>{ transactionRecord.Id },
                    'Final approved'
                );
            transactionRecord =
                BTL_GoLive_TestDataFactory.getTransactionByDate(
                    scenario.dateRecord.Id
                );
            Test.stopTest();

            System.assertEquals(true, result.get('success'));
            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED,
                transactionRecord.Approval_Status__c
            );
            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.ACTION_FINAL_APPROVED,
                transactionRecord.Last_Action__c
            );
        }
    }

    @IsTest
    static void testRejectPendingApproval() {
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
            Map<String, Object> result =
                Ctrl_Hlp_BTLApprovalActionService.rejectMany(
                    new Set<Id>{ transactionRecord.Id },
                    'Return for correction'
                );
            transactionRecord =
                BTL_GoLive_TestDataFactory.getTransactionByDate(
                    scenario.dateRecord.Id
                );
            Test.stopTest();

            System.assertEquals(true, result.get('success'));
            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED,
                transactionRecord.Approval_Status__c
            );
            System.assertEquals(
                scenario.levels[0].Id,
                transactionRecord.Returned_From_Level__c
            );
        }
    }

    @IsTest
    static void testDropReturnedApproval() {
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
            Map<String, Object> result =
                Ctrl_Hlp_BTLApprovalActionService.drop(
                    transactionRecord.Id,
                    'Store Manager dropped activity'
                );
            transactionRecord =
                BTL_GoLive_TestDataFactory.getTransactionByDate(
                    scenario.dateRecord.Id
                );
            Test.stopTest();

            System.assertEquals(true, result.get('success'));
            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED,
                transactionRecord.Approval_Status__c
            );
        }
    }

    @IsTest
    static void testDropForReplacement() {
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
            Map<String, Object> result =
                Ctrl_Hlp_BTLApprovalActionService.dropForReplacement(
                    transactionRecord.Id,
                    'Replacement required'
                );
            Test.stopTest();

            System.assertEquals(true, result.get('success'));
        }
    }

    @IsTest
    static void testValidationBranches() {
        Test.startTest();

        Boolean approveBlocked = false;
        try {
            Ctrl_Hlp_BTLApprovalActionService.approve(null, null);
        } catch (AuraHandledException ex) {
            approveBlocked = true;
        }

        Boolean rejectBlocked = false;
        try {
            Ctrl_Hlp_BTLApprovalActionService.reject(null, 'Reason');
        } catch (AuraHandledException ex) {
            rejectBlocked = true;
        }

        Boolean dropBlocked = false;
        try {
            Ctrl_Hlp_BTLApprovalActionService.dropMany(
                new Set<Id>(),
                'Reason'
            );
        } catch (AuraHandledException ex) {
            dropBlocked = true;
        }

        Test.stopTest();

        System.assertEquals(true, approveBlocked);
        System.assertEquals(true, rejectBlocked);
        System.assertEquals(true, dropBlocked);
    }
}