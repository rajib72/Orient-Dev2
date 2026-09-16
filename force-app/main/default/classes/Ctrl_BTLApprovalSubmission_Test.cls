@IsTest
private class Ctrl_BTLApprovalSubmission_Test {

    @TestSetup
    static void setupUser() {
        BTL_GoLive_TestDataFactory.createAdministrator();
    }

    @IsTest
    static void testGetRowsOverviewAndPreview() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    1,
                    Date.today().addDays(1)
                );

            Test.startTest();
            List<Map<String, Object>> rows =
                Ctrl_BTLApprovalSubmission.getSubmissionRows(
                    scenario.finalForm.Id
                );
            Map<String, Object> overview =
                Ctrl_BTLApprovalSubmission.getApprovalOverview(
                    scenario.dateRecord.Id
                );
            Map<String, Object> preview =
                Ctrl_BTLApprovalSubmission.getApprovalPreview(
                    scenario.dateRecord.Id
                );
            Test.stopTest();

            System.assertEquals(1, rows.size());
            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.STATUS_NOT_SUBMITTED,
                String.valueOf(rows[0].get('approvalStatus'))
            );
            System.assert(overview.containsKey('summary'));
            System.assert(preview.containsKey('sections'));
        }
    }

    @IsTest
    static void testInitialSubmission() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    1,
                    Date.today().addDays(1)
                );

            Test.startTest();
            Map<String, Object> result =
                Ctrl_BTLApprovalSubmission.submitSelectedRecords(
                    new List<Id>{ scenario.dateRecord.Id },
                    'Initial BTL submission'
                );
            Tagged_Approval_Hierarchy__c transactionRecord =
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
                scenario.levels[0].Id,
                transactionRecord.Current_Approval_Level__c
            );
            System.assertEquals(
                UserInfo.getUserId(),
                transactionRecord.Pending_With__c
            );
        }
    }

    @IsTest
    static void testReturnedRows() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    1,
                    Date.today().addDays(1)
                );
            BTL_GoLive_TestDataFactory.createReturnedTransaction(scenario);

            Test.startTest();
            List<Map<String, Object>> returnedRows =
                Ctrl_BTLApprovalSubmission.getSubmissionRows(
                    scenario.finalForm.Id
                );
            Test.stopTest();

            System.assertEquals(1, returnedRows.size());
            System.assertEquals(true, returnedRows[0].get('isReturned'));
        }
    }

    @IsTest
    static void testReturnedResubmission() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    1,
                    Date.today().addDays(1)
                );
            BTL_GoLive_TestDataFactory.createReturnedTransaction(scenario);

            Test.startTest();
            Map<String, Object> result =
                Ctrl_BTLApprovalSubmission.submitRevisedRecords(
                    new List<Id>{ scenario.dateRecord.Id },
                    'Corrected and resubmitted'
                );
            Tagged_Approval_Hierarchy__c transactionRecord =
                BTL_GoLive_TestDataFactory.getTransactionByDate(
                    scenario.dateRecord.Id
                );
            Test.stopTest();

            System.assertEquals(true, result.get('success'));
            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING,
                transactionRecord.Approval_Status__c
            );
            System.assertEquals(2, transactionRecord.Submission_Cycle__c);
        }
    }

    @IsTest
    static void testDropReturnedRecord() {
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
                Ctrl_BTLApprovalSubmission.dropSelectedRecords(
                    new List<Id>{ transactionRecord.Id },
                    'Activity cancelled by Store Manager'
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
    static void testEligibleReturnedManpower() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    1,
                    Date.today().addDays(1)
                );
            BTL_GoLive_TestDataFactory.createReturnedTransaction(scenario);

            Test.startTest();
            List<Map<String, Object>> eligibleRows =
                Ctrl_BTLApprovalSubmission.getEligibleManpower(
                    scenario.dateRecord.Id
                );
            Test.stopTest();

            Set<Id> eligibleIds = new Set<Id>();
            for (Map<String, Object> row : eligibleRows) {
                eligibleIds.add((Id) row.get('executiveId'));
            }

            System.assert(
                eligibleIds.contains(scenario.additionalExecutive.Id)
            );
        }
    }

    @IsTest
    static void testAddReturnedManpower() {
        System.runAs(BTL_GoLive_TestDataFactory.getAdministrator()) {
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    1,
                    Date.today().addDays(1)
                );
            BTL_GoLive_TestDataFactory.createReturnedTransaction(scenario);

            Test.startTest();
            Map<String, Object> addResult =
                Ctrl_BTLApprovalSubmission.addReturnedManpower(
                    scenario.dateRecord.Id,
                    new List<Id>{ scenario.additionalExecutive.Id }
                );
            Test.stopTest();

            System.assertEquals(true, addResult.get('success'));
            System.assertEquals(
                1,
                Integer.valueOf(
                    String.valueOf(addResult.get('createdCount'))
                )
            );
        }
    }

    @IsTest
    static void testReplaceReturnedManpower() {
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
                Ctrl_BTLApprovalSubmission.replaceReturnedManpower(
                    transactionRecord.Id,
                    scenario.replacementExecutive.Id,
                    'Replacement requested'
                );
            Test.stopTest();

            System.assertEquals(true, result.get('success'));
            System.assertNotEquals(
                null,
                result.get('newAssignedPersonDateId')
            );
        }
    }

    @IsTest
    static void testValidationBranches() {
        Test.startTest();

        Boolean submitBlocked = false;
        try {
            Ctrl_BTLApprovalSubmission.submitSelectedRecords(
                new List<Id>(),
                null
            );
        } catch (AuraHandledException ex) {
            submitBlocked = true;
        }

        Boolean revisedBlocked = false;
        try {
            Ctrl_BTLApprovalSubmission.submitRevisedRecords(
                new List<Id>(),
                null
            );
        } catch (AuraHandledException ex) {
            revisedBlocked = true;
        }

        Test.stopTest();

        System.assertEquals(true, submitBlocked);
        System.assertEquals(true, revisedBlocked);
    }
}