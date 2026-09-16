@IsTest
private class Ctrl_BTLEmailTemplateContent_Test {

    @TestSetup
    static void setupUser() {
        BTL_GoLive_TestDataFactory.createAdministrator();
    }

    @IsTest
    static void testApprovalRequiredTemplate() {
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
            exerciseTemplate(transactionRecord.Id, 'APPROVAL_REQUIRED');
            Test.stopTest();
        }
    }

    @IsTest
    static void testReturnedTemplate() {
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
            exerciseTemplate(transactionRecord.Id, 'RETURNED');
            Test.stopTest();
        }
    }

    @IsTest
    static void testCompletedTemplate() {
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
            exerciseTemplate(transactionRecord.Id, 'COMPLETED');
            Test.stopTest();
        }
    }

    @IsTest
    static void testNullTransactionReturnsSafeValues() {
        Test.startTest();
        Ctrl_BTLEmailTemplateContent content =
            new Ctrl_BTLEmailTemplateContent();

        // Mail type is a required template input. The production helper calls
        // trim()/toUpperCase() on this value, so do not test an impossible
        // Visualforce/template state with a null mail type.
        content.inputMailType = 'COMPLETED';

        System.assertEquals(null, content.getAnchor());
        System.assertEquals(0, content.getMemberRows().size());
        System.assertEquals(false, content.getIsApprovalRequired());
        System.assertEquals(false, content.getIsReturned());
        System.assertEquals(true, content.getIsCompleted());
        System.assertEquals(false, content.getIsDropped());
        System.assertEquals('BTL Approval Process Completed', content.getMailTitle());
        content.getMailSubtitle();
        content.getStatusLabel();
        System.assertEquals(null, content.getWorkspaceUrl());
        Test.stopTest();
    }

    private static void exerciseTemplate(
        Id transactionId,
        String mailType
    ) {
        Ctrl_BTLEmailTemplateContent content =
            new Ctrl_BTLEmailTemplateContent();

        content.inputTransactionId = transactionId;
        content.inputMailType = mailType;

        System.assertNotEquals(null, content.getAnchor());
        System.assert(!content.getMemberRows().isEmpty());

        content.getIsApprovalRequired();
        content.getIsReturned();
        content.getIsCompleted();
        content.getIsDropped();
        content.getMailTitle();
        content.getMailSubtitle();
        content.getStatusLabel();
        content.getRecipientName();
        content.getActivityNumber();
        content.getActivityName();
        content.getStoreName();
        content.getTargetDate();
        content.getTeamName();
        content.getActivityLocation();
        content.getFinalCustomizeFormNo();
        content.getSubmittedByName();
        content.getSubmittedDateTimeIST();
        content.getCurrentLevelName();
        content.getPendingWithName();
        content.getReturnedFromLevelName();
        content.getLastActionByName();
        content.getLastActionDateTimeIST();
        content.getLastActionComments();
        content.getCompletedByName();
        content.getCompletedDateTimeIST();
        content.getSubmissionCycle();
        content.getExecutiveName();
        content.getAssignedPersonNo();
        content.getWorkspaceUrl();
    }
}