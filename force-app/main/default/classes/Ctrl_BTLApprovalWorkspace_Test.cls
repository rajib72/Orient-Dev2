@IsTest
private class Ctrl_BTLApprovalWorkspace_Test {

    @TestSetup
    static void setupUser() {
        BTL_GoLive_TestDataFactory.createAdministrator();
    }

    @IsTest
    static void testWorkspaceListsAndContext() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    1,
                    Date.today().addDays(1)
                );
            BTL_GoLive_TestDataFactory.createPendingTransaction(scenario);

            Test.startTest();
            Map<String, Object> context =
                Ctrl_BTLApprovalWorkspace.getWorkspaceContext();
            List<Map<String, Object>> pending =
                Ctrl_BTLApprovalWorkspace.getPendingApprovals();
            List<Map<String, Object>> submitted =
                Ctrl_BTLApprovalWorkspace.getMySubmittedApprovals();
            List<Map<String, Object>> admin =
                Ctrl_BTLApprovalWorkspace.getAdminApprovals();
            Test.stopTest();

            System.assertEquals(true, context.get('isAdmin'));
            System.assert(!pending.isEmpty());
            System.assert(!submitted.isEmpty());
            System.assert(!admin.isEmpty());
        }
    }

    @IsTest
    static void testWorkspaceOverviewAndPreview() {
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
            Map<String, Object> overview =
                Ctrl_BTLApprovalWorkspace.getApprovalOverview(
                    transactionRecord.Id
                );
            Map<String, Object> preview =
                Ctrl_BTLApprovalWorkspace.getApprovalPreview(
                    transactionRecord.Id
                );
            Test.stopTest();

            System.assert(overview.containsKey('actionContext'));
            System.assert(preview.containsKey('actionContext'));
        }
    }

    @IsTest
    static void testApproveTeamActivityAdvancesLevel() {
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
                Ctrl_BTLApprovalWorkspace.approveTeamActivity(
                    new List<Id>{ transactionRecord.Id },
                    'Level one approved'
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
    static void testApproveApprovalFinal() {
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
                Ctrl_BTLApprovalWorkspace.approveApproval(
                    transactionRecord.Id,
                    'Final approval'
                );
            transactionRecord =
                BTL_GoLive_TestDataFactory.getTransactionByDate(
                    scenario.dateRecord.Id
                );
            List<Map<String, Object>> actioned =
                Ctrl_BTLApprovalWorkspace.getActionedApprovals();
            Test.stopTest();

            System.assertEquals(true, result.get('success'));
            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED,
                transactionRecord.Approval_Status__c
            );
            System.assert(!actioned.isEmpty());
        }
    }

    @IsTest
    static void testRejectSelectedApprovals() {
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
                Ctrl_BTLApprovalWorkspace.rejectSelectedApprovals(
                    new List<Id>{ transactionRecord.Id },
                    'Please revise manpower'
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
        }
    }

    @IsTest
    static void testRejectApprovalWrapper() {
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
                Ctrl_BTLApprovalWorkspace.rejectApproval(
                    transactionRecord.Id,
                    'Return to Store Manager'
                );
            Test.stopTest();

            System.assertEquals(true, result.get('success'));
        }
    }
}