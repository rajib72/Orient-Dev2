@IsTest
private class Ctrl_Hlp_BTLApprovalPreviewService_Test {

    @TestSetup
    static void setupUser() {
        BTL_GoLive_TestDataFactory.createAdministrator();
    }

    @IsTest
    static void testBuildOverviewAndPreview() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createBasicScenario(
                    Date.today().addDays(1)
                );

            Test.startTest();
            Map<String, Object> overview =
                Ctrl_Hlp_BTLApprovalPreviewService.buildOverview(
                    scenario.dateRecord.Id
                );
            Map<String, Object> preview =
                Ctrl_Hlp_BTLApprovalPreviewService.buildPreview(
                    scenario.dateRecord.Id
                );
            Test.stopTest();

            System.assertNotEquals(null, overview);
            System.assertNotEquals(null, preview);
            System.assert(overview.containsKey('summary'));
            System.assert(preview.containsKey('sections'));
        }
    }

    @IsTest
    static void testNullValidation() {
        Boolean overviewBlocked = false;
        try {
            Ctrl_Hlp_BTLApprovalPreviewService.buildOverview(null);
        } catch (AuraHandledException ex) {
            overviewBlocked = true;
        }
        System.assertEquals(true, overviewBlocked);

        Boolean previewBlocked = false;
        try {
            Ctrl_Hlp_BTLApprovalPreviewService.buildPreview(null);
        } catch (AuraHandledException ex) {
            previewBlocked = true;
        }
        System.assertEquals(true, previewBlocked);
    }
}