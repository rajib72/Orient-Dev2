@IsTest
private class ctrl_StoreManagerDailyActivity_Test {

    @TestSetup
    static void setupUser() {
        BTL_GoLive_TestDataFactory.createAdministrator();
    }

    @IsTest
    static void testAdministratorDashboard() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createBasicScenario(
                    Date.today()
                );

            Test.startTest();
            ctrl_StoreManagerDailyActivityController.DashboardResponse response =
                ctrl_StoreManagerDailyActivityController.getDashboard(
                    Date.today(),
                    null
                );
            Test.stopTest();

            System.assertEquals(true, response.isSystemAdministrator);
            System.assertEquals('All Stores', response.store);
            System.assertEquals(Date.today(), response.selectedDate);
            System.assertNotEquals(null, response.refreshedAt);
            System.assertEquals('Form_Activity__c', response.formActivityObjectApiName);
            System.assert(response.activeToday >= 1);
            System.assert(!response.activities.isEmpty());
            System.assert(!response.executives.isEmpty());
            System.assert(response.assignedExecutives >= 1);

            Boolean activityFound = false;
            for (
                ctrl_StoreManagerDailyActivityController.ActivityRow row :
                response.activities
            ) {
                if (row.activityId == scenario.activity.Id) {
                    activityFound = true;
                    System.assertEquals(
                        BTL_GoLive_TestDataFactory.DEFAULT_TEAM,
                        row.teamName
                    );
                    System.assert(row.assignedPersons >= 1);
                    System.assert(row.todayTargetLocations >= 1);
                    System.assert(!row.persons.isEmpty());
                }
            }
            System.assertEquals(true, activityFound);
        }
    }

    @IsTest
    static void testDefaultDateAndInvalidStoreValidation() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.createBasicScenario(
                Date.today()
            );

            ctrl_StoreManagerDailyActivityController.DashboardResponse response =
                ctrl_StoreManagerDailyActivityController.getDashboard(
                    null,
                    'All Stores'
                );

            System.assertEquals(Date.today(), response.selectedDate);
            System.assertEquals(true, response.isSystemAdministrator);

            Boolean invalidStoreBlocked = false;
            try {
                ctrl_StoreManagerDailyActivityController.getDashboard(
                    Date.today(),
                    '___NOT_A_CONFIGURED_STORE___'
                );
            } catch (AuraHandledException exceptionRecord) {
                invalidStoreBlocked = true;
            }

            System.assertEquals(true, invalidStoreBlocked);
        }
    }
}