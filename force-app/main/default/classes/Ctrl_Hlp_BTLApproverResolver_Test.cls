@IsTest
private class Ctrl_Hlp_BTLApproverResolver_Test {

    @TestSetup
    static void setupUser() {
        BTL_GoLive_TestDataFactory.createAdministrator();
    }

    @IsTest
    static void testApproverResolution() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    2,
                    Date.today().addDays(1)
                );

            Test.startTest();
            Map<Id, Ctrl_Hlp_BTLApproverResolver.Resolution> firstApprovers =
                Ctrl_Hlp_BTLApproverResolver.resolveFirstApprovers(
                    new Set<Id>{ scenario.hierarchy.Id }
                );

            System.assertEquals(1, firstApprovers.size());
            System.assertEquals(
                scenario.levels[0].Id,
                firstApprovers.get(scenario.hierarchy.Id).level.Id
            );

            Ctrl_Hlp_BTLApproverResolver.Resolution oneLevel =
                Ctrl_Hlp_BTLApproverResolver.resolveApproverForLevel(
                    scenario.levels[0].Id
                );
            System.assertEquals(
                UserInfo.getUserId(),
                oneLevel.mapping.Approver_User__c
            );

            Map<Id, Approval_Approver_Mapping__c> mappings =
                Ctrl_Hlp_BTLApproverResolver.resolveApproversForLevels(
                    new Set<Id>{
                        scenario.levels[0].Id,
                        scenario.levels[1].Id
                    }
                );
            System.assertEquals(2, mappings.size());

            Ctrl_Hlp_BTLApproverResolver.validateLevelSequences(
                scenario.levels
            );
            Test.stopTest();
        }
    }

    @IsTest
    static void testValidationBranches() {
        System.assertEquals(
            0,
            Ctrl_Hlp_BTLApproverResolver.resolveFirstApprovers(
                new Set<Id>()
            ).size()
        );
        System.assertEquals(
            0,
            Ctrl_Hlp_BTLApproverResolver.resolveApproversForLevels(
                new Set<Id>()
            ).size()
        );

        Boolean nullLevelBlocked = false;
        try {
            Ctrl_Hlp_BTLApproverResolver.resolveApproverForLevel(null);
        } catch (AuraHandledException ex) {
            nullLevelBlocked = true;
        }
        System.assertEquals(true, nullLevelBlocked);

        Boolean duplicateBlocked = false;
        try {
            Ctrl_Hlp_BTLApproverResolver.validateLevelSequences(
                new List<Approval_Hierarchy_Level__c>{
                    new Approval_Hierarchy_Level__c(
                        Approval_Hierarchy__c = UserInfo.getUserId(),
                        Sr_No__c = 1
                    ),
                    new Approval_Hierarchy_Level__c(
                        Approval_Hierarchy__c = UserInfo.getUserId(),
                        Sr_No__c = 1
                    )
                }
            );
        } catch (AuraHandledException ex) {
            duplicateBlocked = true;
        }
        System.assertEquals(true, duplicateBlocked);
    }
}