@IsTest
private class ctrl_ManageFormActivityPersons_Test {

    @TestSetup
    static void setupUser() {
        BTL_GoLive_TestDataFactory.createAdministrator();
    }

    @IsTest
    static void testReadMethods() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createBasicScenario(
                    Date.today()
                );

            Test.startTest();
            List<ctrl_ManageFormActivityPersonsController.OptionWrapper>
                activityOptions =
                    ctrl_ManageFormActivityPersonsController.getFormActivities(
                        scenario.finalForm.Id
                    );
            ctrl_ManageFormActivityPersonsController.ActivityDetailWrapper
                detail =
                    ctrl_ManageFormActivityPersonsController.getActivityDetails(
                        scenario.activity.Id
                    );
            Test.stopTest();

            System.assertEquals(1, activityOptions.size());
            System.assertEquals(
                String.valueOf(scenario.activity.Id),
                activityOptions[0].value
            );
            System.assertEquals(scenario.activity.Id, detail.formActivityId);
            System.assertEquals(scenario.store.Id, detail.storeId);
            System.assertEquals(1, detail.assignedPersons.size());
            System.assertEquals(3, detail.availableExecutives.size());
        }
    }

    @IsTest
    static void testAddAssignedPerson() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createBasicScenario(
                    Date.today()
                );

            Test.startTest();
            ctrl_ManageFormActivityPersonsController.addAssignedPersons(
                scenario.activity.Id,
                scenario.store.Id,
                new List<Id>{ scenario.additionalExecutive.Id }
            );
            Integer addedCount = [
                SELECT COUNT()
                FROM Form_Activity_Assigned_Persons__c
                WHERE Form_Activity__c = :scenario.activity.Id
                AND Sales_Executives__c =
                    :scenario.additionalExecutive.Id
            ];
            Test.stopTest();

            System.assertEquals(1, addedCount);
        }
    }

    @IsTest
    static void testDuplicateAddIsIgnored() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createBasicScenario(
                    Date.today()
                );

            BTL_GoLive_TestDataFactory.createAssignedPerson(
                scenario.activity.Id,
                scenario.store.Id,
                scenario.additionalExecutive.Id,
                BTL_GoLive_TestDataFactory.DEFAULT_TEAM,
                Date.today(),
                BTL_GoLive_TestDataFactory.DEFAULT_LOCATION
            );

            Test.startTest();
            ctrl_ManageFormActivityPersonsController.addAssignedPersons(
                scenario.activity.Id,
                scenario.store.Id,
                new List<Id>{ scenario.additionalExecutive.Id }
            );
            Integer duplicateCount = [
                SELECT COUNT()
                FROM Form_Activity_Assigned_Persons__c
                WHERE Form_Activity__c = :scenario.activity.Id
                AND Sales_Executives__c =
                    :scenario.additionalExecutive.Id
            ];
            Test.stopTest();

            System.assertEquals(1, duplicateCount);
        }
    }

    @IsTest
    static void testDeleteAssignedPerson() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createBasicScenario(
                    Date.today()
                );

            Form_Activity_Assigned_Persons__c addedPerson =
                BTL_GoLive_TestDataFactory.createAssignedPerson(
                    scenario.activity.Id,
                    scenario.store.Id,
                    scenario.additionalExecutive.Id,
                    BTL_GoLive_TestDataFactory.DEFAULT_TEAM,
                    Date.today(),
                    BTL_GoLive_TestDataFactory.DEFAULT_LOCATION
                );

            Test.startTest();
            ctrl_ManageFormActivityPersonsController.deleteAssignedPerson(
                addedPerson.Id
            );
            Integer remainingCount = [
                SELECT COUNT()
                FROM Form_Activity_Assigned_Persons__c
                WHERE Id = :addedPerson.Id
            ];
            Test.stopTest();

            System.assertEquals(0, remainingCount);
        }
    }

    @IsTest
    static void testNullAndValidationBranches() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createBasicScenario(
                    Date.today()
                );

            Test.startTest();

            List<ctrl_ManageFormActivityPersonsController.OptionWrapper>
                emptyOptions =
                    ctrl_ManageFormActivityPersonsController.getFormActivities(
                        null
                    );
            ctrl_ManageFormActivityPersonsController.ActivityDetailWrapper
                emptyDetail =
                    ctrl_ManageFormActivityPersonsController.getActivityDetails(
                        null
                    );

            Boolean activityRequired = false;
            try {
                ctrl_ManageFormActivityPersonsController.addAssignedPersons(
                    null,
                    null,
                    null
                );
            } catch (AuraHandledException exceptionRecord) {
                activityRequired = true;
            }

            Boolean storeRequired = false;
            try {
                ctrl_ManageFormActivityPersonsController.addAssignedPersons(
                    scenario.activity.Id,
                    null,
                    new List<Id>{ scenario.additionalExecutive.Id }
                );
            } catch (AuraHandledException exceptionRecord) {
                storeRequired = true;
            }

            Boolean executiveRequired = false;
            try {
                ctrl_ManageFormActivityPersonsController.addAssignedPersons(
                    scenario.activity.Id,
                    scenario.store.Id,
                    new List<Id>()
                );
            } catch (AuraHandledException exceptionRecord) {
                executiveRequired = true;
            }

            Boolean deleteIdRequired = false;
            try {
                ctrl_ManageFormActivityPersonsController.deleteAssignedPerson(
                    null
                );
            } catch (AuraHandledException exceptionRecord) {
                deleteIdRequired = true;
            }

            Test.stopTest();

            System.assertEquals(0, emptyOptions.size());
            System.assertEquals(0, emptyDetail.assignedPersons.size());
            System.assertEquals(0, emptyDetail.availableExecutives.size());
            System.assertEquals(true, activityRequired);
            System.assertEquals(true, storeRequired);
            System.assertEquals(true, executiveRequired);
            System.assertEquals(true, deleteIdRequired);
        }
    }
}