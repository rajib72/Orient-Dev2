@IsTest
private class ctrl_StoreMngrDailyActivityCnt_v2_Test {

    private static final String ADMIN_LAST_NAME = 'CTRL V2 TEST ADMIN';
    private static final String TEAM_ALPHA = 'Team Alpha';
    private static final String TEAM_BETA = 'Team Beta';
    private static final String TEAM_GAMMA = 'Team Gamma';
    private static final String DEFAULT_LOCATION = 'Location A';
    private static Integer sequenceNumber = 0;

    @TestSetup
    static void setupAdministrator() {
        Profile adminProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

        String uniqueValue =
            String.valueOf(DateTime.now().getTime()) +
            String.valueOf(Crypto.getRandomInteger()).replace('-', '');

        insert new User(
            Alias = 'v2admin',
            Email = 'v2admin.' + uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = ADMIN_LAST_NAME,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'v2admin.' + uniqueValue + '@example.test'
        );
    }

    @IsTest
    static void testDashboardAndSalesExecutiveFiltering() {
        System.runAs(getAdministrator()) {
            Store__c storeRecord = createStore('Dashboard Store');

            Sales_Executives__c executiveAlpha =
                createExecutive(storeRecord.Id, 'Executive Alpha');
            Sales_Executives__c executiveBeta =
                createExecutive(storeRecord.Id, 'Executive Beta');
            Sales_Executives__c executiveFree =
                createExecutive(storeRecord.Id, 'Executive Free');

            Form_Activity__c teamActivity = createActivity(
                storeRecord.Id,
                'Team Activity',
                Date.today(),
                Date.today(),
                DEFAULT_LOCATION
            );

            Form_Activity_Assigned_Persons__c alphaParent =
                createAssignedPerson(
                    teamActivity.Id,
                    storeRecord.Id,
                    executiveAlpha.Id,
                    TEAM_ALPHA
                );

            Form_Activity_Assigned_Persons__c betaParent =
                createAssignedPerson(
                    teamActivity.Id,
                    storeRecord.Id,
                    executiveBeta.Id,
                    TEAM_BETA
                );

            Form_Activity_Assigned_Persons_Date__c alphaDateRow =
                createDateAssignment(
                    alphaParent.Id,
                    storeRecord.Id,
                    null,
                    Date.today(),
                    DEFAULT_LOCATION,
                    true,
                    false,
                    null
                );

            Form_Activity_Assigned_Persons_Date__c betaDateRow =
                createDateAssignment(
                    betaParent.Id,
                    storeRecord.Id,
                    null,
                    Date.today(),
                    DEFAULT_LOCATION,
                    true,
                    false,
                    null
                );

            markApprovedForStoreAction(
                new List<Form_Activity_Assigned_Persons_Date__c>{
                    alphaDateRow, betaDateRow
                }
            );

            Form_Activity__c completedActivity = createActivity(
                storeRecord.Id,
                'Completed Activity',
                Date.today(),
                Date.today(),
                DEFAULT_LOCATION
            );

            createExecution(
                completedActivity.Id,
                storeRecord.Id,
                Date.today(),
                executionKey(
                    completedActivity.Id,
                    Date.today(),
                    'NO_TEAM'
                ),
                'Completed',
                true,
                false
            );

            Form_Activity__c progressActivity = createActivity(
                storeRecord.Id,
                'Progress Activity',
                Date.today(),
                Date.today(),
                DEFAULT_LOCATION
            );

            Form_Activity_Daily_Execution__c progressExecution =
                createExecution(
                    progressActivity.Id,
                    storeRecord.Id,
                    Date.today(),
                    'PROGRESS-' + uniqueToken(),
                    'In Progress',
                    true,
                    true
                );

            Form_Activity_Assigned_Persons__c gammaParent =
                createAssignedPerson(
                    progressActivity.Id,
                    storeRecord.Id,
                    executiveFree.Id,
                    TEAM_GAMMA
                );

            createDateAssignment(
                gammaParent.Id,
                storeRecord.Id,
                executiveFree.Id,
                Date.today(),
                DEFAULT_LOCATION,
                true,
                false,
                progressExecution.Id
            );

            Date previousDate = Date.today().addDays(-1);
            Form_Activity__c expiredActivity = createActivity(
                storeRecord.Id,
                'Expired Activity',
                previousDate,
                previousDate,
                DEFAULT_LOCATION
            );

            Form_Activity_Assigned_Persons__c expiredParent =
                createAssignedPerson(
                    expiredActivity.Id,
                    storeRecord.Id,
                    executiveAlpha.Id,
                    TEAM_ALPHA
                );

            createDateAssignment(
                expiredParent.Id,
                storeRecord.Id,
                null,
                previousDate,
                DEFAULT_LOCATION,
                true,
                false,
                null
            );

            String alphaTeamKey =
                teamKey(String.valueOf(alphaParent.Team_Name__c));

            Test.startTest();

            ctrl_StoreManagerDailyActivityCnt_v2.DashboardResponse todayResult =
                ctrl_StoreManagerDailyActivityCnt_v2.getDashboard(
                    Date.today(),
                    storeRecord.Id
                );

            ctrl_StoreManagerDailyActivityCnt_v2.DashboardResponse pastResult =
                ctrl_StoreManagerDailyActivityCnt_v2.getDashboard(
                    previousDate,
                    storeRecord.Id
                );

            List<ctrl_StoreManagerDailyActivityCnt_v2.OptionWrapper>
                executiveOptions =
                    ctrl_StoreManagerDailyActivityCnt_v2.getSalesExecutives(
                        storeRecord.Id,
                        teamActivity.Id,
                        Date.today(),
                        alphaTeamKey
                    );

            List<ctrl_StoreManagerDailyActivityCnt_v2.OptionWrapper>
                emptyOptions =
                    ctrl_StoreManagerDailyActivityCnt_v2.getSalesExecutives(
                        null,
                        teamActivity.Id,
                        Date.today(),
                        alphaTeamKey
                    );

            Test.stopTest();

            Set<String> optionValues = new Set<String>();
            for (
                ctrl_StoreManagerDailyActivityCnt_v2.OptionWrapper optionRecord :
                    executiveOptions
            ) {
                optionValues.add(optionRecord.value);
            }

            System.assert(
                optionValues.contains(String.valueOf(executiveAlpha.Id)),
                'The current-team executive must remain available.'
            );
            System.assert(
                optionValues.contains(String.valueOf(executiveFree.Id)),
                'A store executive not assigned to another team of this activity must be available.'
            );
            System.assert(
                !optionValues.contains(String.valueOf(executiveBeta.Id)),
                'An executive assigned to another team of this activity must be excluded.'
            );
        }
    }

    @IsTest
    static void testInitiateWithoutChanges() {
        System.runAs(getAdministrator()) {
            Store__c storeRecord = createStore('Without Changes Store');
            Sales_Executives__c executiveRecord =
                createExecutive(storeRecord.Id, 'Default Executive');

            Form_Activity__c activityRecord = createActivity(
                storeRecord.Id,
                'Without Changes Activity',
                Date.today(),
                Date.today(),
                DEFAULT_LOCATION
            );

            Form_Activity_Assigned_Persons__c parentRecord =
                createAssignedPerson(
                    activityRecord.Id,
                    storeRecord.Id,
                    executiveRecord.Id,
                    TEAM_ALPHA
                );

            Form_Activity_Assigned_Persons_Date__c dateRow =
                createDateAssignment(
                    parentRecord.Id,
                    storeRecord.Id,
                    null,
                    Date.today(),
                    DEFAULT_LOCATION,
                    false,
                    false,
                    null
                );

            markApprovedForStoreAction(
                new List<Form_Activity_Assigned_Persons_Date__c>{ dateRow }
            );

            String selectedTeamKey =
                teamKey(String.valueOf(parentRecord.Team_Name__c));

            Test.startTest();
            Id executionId =
                ctrl_StoreManagerDailyActivityCnt_v2.initiateWithoutChanges(
                    activityRecord.Id,
                    Date.today(),
                    selectedTeamKey
                );
            Test.stopTest();

            Form_Activity_Daily_Execution__c executionRecord = [
                SELECT Status__c,
                       Store_Manager_Approved__c,
                       BTL_Activity_Live__c,
                       BTL_Initiated_Date_Time__c,
                       BTL_Initiated_By__c
                FROM Form_Activity_Daily_Execution__c
                WHERE Id = :executionId
            ];

            Form_Activity_Assigned_Persons_Date__c refreshedDateRow = [
                SELECT Actual_Executive__c,
                       Active_For_Date__c,
                       Present__c,
                       Form_Activity_Daily_Execution__c
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Id = :dateRow.Id
            ];

            Form_Activity__c refreshedActivity = [
                SELECT Store_Manager_Approved__c,
                       BTL_Activity_Live__c,
                       BTL_Live_Date__c,
                       BTL_Initiated_By__c
                FROM Form_Activity__c
                WHERE Id = :activityRecord.Id
            ];

            System.assertEquals('Live', executionRecord.Status__c);
            System.assertEquals(true, executionRecord.Store_Manager_Approved__c);
            System.assertEquals(true, executionRecord.BTL_Activity_Live__c);
            System.assertNotEquals(null, executionRecord.BTL_Initiated_Date_Time__c);
            System.assertEquals(
                executiveRecord.Id,
                refreshedDateRow.Actual_Executive__c
            );
            System.assertEquals(true, refreshedDateRow.Active_For_Date__c);
            System.assertEquals(false, refreshedDateRow.Present__c);
            System.assertEquals(
                executionId,
                refreshedDateRow.Form_Activity_Daily_Execution__c
            );
            System.assertEquals(true, refreshedActivity.Store_Manager_Approved__c);
            System.assertEquals(true, refreshedActivity.BTL_Activity_Live__c);
            System.assertEquals(Date.today(), refreshedActivity.BTL_Live_Date__c);

            Boolean duplicateInitiationBlocked = false;
            try {
                ctrl_StoreManagerDailyActivityCnt_v2.initiateWithoutChanges(
                    activityRecord.Id,
                    Date.today(),
                    selectedTeamKey
                );
            } catch (AuraHandledException exceptionRecord) {
                duplicateInitiationBlocked = true;
            }

            System.assertEquals(true, duplicateInitiationBlocked);
        }
    }

    @IsTest
    static void testInitiateWithChanges() {
        System.runAs(getAdministrator()) {
            Store__c storeRecord = createStore('With Changes Store');

            Sales_Executives__c executiveOne =
                createExecutive(storeRecord.Id, 'Executive One');
            Sales_Executives__c executiveTwo =
                createExecutive(storeRecord.Id, 'Executive Two');
            Sales_Executives__c executiveThree =
                createExecutive(storeRecord.Id, 'Executive Three');

            Form_Activity__c activityRecord = createActivity(
                storeRecord.Id,
                'With Changes Activity',
                Date.today(),
                Date.today(),
                DEFAULT_LOCATION
            );

            Form_Activity_Assigned_Persons__c parentOne =
                createAssignedPerson(
                    activityRecord.Id,
                    storeRecord.Id,
                    executiveOne.Id,
                    TEAM_ALPHA
                );
            Form_Activity_Assigned_Persons__c parentTwo =
                createAssignedPerson(
                    activityRecord.Id,
                    storeRecord.Id,
                    executiveTwo.Id,
                    TEAM_ALPHA
                );
            Form_Activity_Assigned_Persons__c parentThree =
                createAssignedPerson(
                    activityRecord.Id,
                    storeRecord.Id,
                    executiveThree.Id,
                    TEAM_ALPHA
                );

            Form_Activity_Assigned_Persons_Date__c rowOne =
                createDateAssignment(
                    parentOne.Id,
                    storeRecord.Id,
                    null,
                    Date.today(),
                    DEFAULT_LOCATION,
                    true,
                    false,
                    null
                );
            Form_Activity_Assigned_Persons_Date__c rowTwo =
                createDateAssignment(
                    parentTwo.Id,
                    storeRecord.Id,
                    null,
                    Date.today(),
                    DEFAULT_LOCATION,
                    true,
                    false,
                    null
                );
            Form_Activity_Assigned_Persons_Date__c rowThree =
                createDateAssignment(
                    parentThree.Id,
                    storeRecord.Id,
                    null,
                    Date.today(),
                    DEFAULT_LOCATION,
                    true,
                    false,
                    null
                );

            markApprovedForStoreAction(
                new List<Form_Activity_Assigned_Persons_Date__c>{
                    rowOne, rowTwo, rowThree
                }
            );

            ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput activeInput =
                new ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput();
            activeInput.dateAssignmentId = rowOne.Id;
            activeInput.actualExecutiveId = executiveThree.Id;
            activeInput.activeForDate = true;

            ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput inactiveInput =
                new ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput();
            inactiveInput.dateAssignmentId = rowTwo.Id;
            inactiveInput.actualExecutiveId = null;
            inactiveInput.activeForDate = false;

            Test.startTest();
            Id executionId =
                ctrl_StoreManagerDailyActivityCnt_v2.initiateWithChanges(
                    activityRecord.Id,
                    Date.today(),
                    teamKey(String.valueOf(parentOne.Team_Name__c)),
                    new List<ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput>{
                        activeInput,
                        inactiveInput,
                        null
                    }
                );
            Test.stopTest();

            Set<Id> rowIds = new Set<Id>{
                rowOne.Id,
                rowTwo.Id,
                rowThree.Id
            };

            Map<Id, Form_Activity_Assigned_Persons_Date__c> refreshedRows =
                new Map<Id, Form_Activity_Assigned_Persons_Date__c>([
                    SELECT Id,
                           Actual_Executive__c,
                           Active_For_Date__c,
                           Form_Activity_Daily_Execution__c
                    FROM Form_Activity_Assigned_Persons_Date__c
                    WHERE Id IN :rowIds
                ]);

            System.assertEquals(
                executiveThree.Id,
                refreshedRows.get(rowOne.Id).Actual_Executive__c
            );
            System.assertEquals(true, refreshedRows.get(rowOne.Id).Active_For_Date__c);
            System.assertEquals(null, refreshedRows.get(rowTwo.Id).Actual_Executive__c);
            System.assertEquals(false, refreshedRows.get(rowTwo.Id).Active_For_Date__c);
            System.assertEquals(null, refreshedRows.get(rowThree.Id).Actual_Executive__c);
            System.assertEquals(false, refreshedRows.get(rowThree.Id).Active_For_Date__c);

            for (Form_Activity_Assigned_Persons_Date__c rowRecord : refreshedRows.values()) {
                System.assertEquals(
                    executionId,
                    rowRecord.Form_Activity_Daily_Execution__c
                );
            }
        }
    }

    @IsTest
    static void testSaveAndSendForApproval() {
        System.runAs(getAdministrator()) {
            Store__c storeRecord = createStore('Approval Store');

            Sales_Executives__c originalExecutive =
                createExecutive(storeRecord.Id, 'Original Executive');
            Sales_Executives__c replacementExecutive =
                createExecutive(storeRecord.Id, 'Replacement Executive');
            Sales_Executives__c additionalExecutive =
                createExecutive(storeRecord.Id, 'Additional Executive');

            Form_Activity__c activityRecord = createActivity(
                storeRecord.Id,
                'Approval Activity',
                Date.today(),
                Date.today(),
                DEFAULT_LOCATION
            );

            Form_Activity_Assigned_Persons__c originalParent =
                createAssignedPerson(
                    activityRecord.Id,
                    storeRecord.Id,
                    originalExecutive.Id,
                    TEAM_ALPHA
                );

            Form_Activity_Assigned_Persons__c replacementParent =
                createAssignedPerson(
                    activityRecord.Id,
                    storeRecord.Id,
                    replacementExecutive.Id,
                    TEAM_ALPHA
                );

            Form_Activity_Assigned_Persons_Date__c activeRow =
                createDateAssignment(
                    originalParent.Id,
                    storeRecord.Id,
                    originalExecutive.Id,
                    Date.today(),
                    DEFAULT_LOCATION,
                    true,
                    false,
                    null
                );

            String allowedLocation =
                String.valueOf(activeRow.Activity_Location__c);

            Form_Activity_Assigned_Persons_Date__c replacementRow =
                createDateAssignment(
                    replacementParent.Id,
                    storeRecord.Id,
                    null,
                    Date.today(),
                    allowedLocation,
                    false,
                    false,
                    null
                );

            // Change Manpower is allowed only after the currently planned
            // rows have reached final approval.
            markApprovedForStoreAction(
                new List<Form_Activity_Assigned_Persons_Date__c>{
                    activeRow, replacementRow
                }
            );

            createApprovalHierarchy(storeRecord.Id);

            ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput changedRow =
                new ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput();
            changedRow.dateAssignmentId = activeRow.Id;
            changedRow.actualExecutiveId = replacementExecutive.Id;
            changedRow.activeForDate = true;
            changedRow.activityLocation = '  ' + allowedLocation + '  ';
            changedRow.isNew = false;

            ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput newRow =
                new ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput();
            newRow.actualExecutiveId = additionalExecutive.Id;
            newRow.activeForDate = true;
            newRow.activityLocation = allowedLocation;
            newRow.isNew = true;

            Test.startTest();
            ctrl_StoreManagerDailyActivityCnt_v2.SaveApprovalResponse result =
                ctrl_StoreManagerDailyActivityCnt_v2.saveAndSendForApproval(
                    activityRecord.Id,
                    Date.today(),
                    teamKey(String.valueOf(originalParent.Team_Name__c)),
                    new List<ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput>{
                        changedRow,
                        newRow,
                        null
                    }
                );
            Test.stopTest();

          

            Form_Activity_Assigned_Persons_Date__c refreshedRow = [
                SELECT Actual_Executive__c,
                       Activity_Location__c,
                       Active_For_Date__c,
                       Approval_Status__c,
                       Approval_Locked__c
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Id = :activeRow.Id
            ];
        }
    }

    @IsTest
    static void testValidationBranches() {
        System.runAs(getAdministrator()) {
            Store__c storeRecord = createStore('Validation Store');
            Store__c otherStore = createStore('Other Store');

            Sales_Executives__c alphaExecutive =
                createExecutive(storeRecord.Id, 'Alpha Executive');
            Sales_Executives__c betaExecutive =
                createExecutive(storeRecord.Id, 'Beta Executive');
            Sales_Executives__c otherStoreExecutive =
                createExecutive(otherStore.Id, 'Other Store Executive');

            Form_Activity__c activityRecord = createActivity(
                storeRecord.Id,
                'Validation Activity',
                Date.today(),
                Date.today(),
                DEFAULT_LOCATION
            );

            Form_Activity_Assigned_Persons__c alphaParent =
                createAssignedPerson(
                    activityRecord.Id,
                    storeRecord.Id,
                    alphaExecutive.Id,
                    TEAM_ALPHA
                );

            Form_Activity_Assigned_Persons__c betaParent =
                createAssignedPerson(
                    activityRecord.Id,
                    storeRecord.Id,
                    betaExecutive.Id,
                    TEAM_BETA
                );

            Form_Activity_Assigned_Persons_Date__c alphaRow =
                createDateAssignment(
                    alphaParent.Id,
                    storeRecord.Id,
                    alphaExecutive.Id,
                    Date.today(),
                    DEFAULT_LOCATION,
                    true,
                    false,
                    null
                );

            createDateAssignment(
                betaParent.Id,
                storeRecord.Id,
                betaExecutive.Id,
                Date.today(),
                DEFAULT_LOCATION,
                true,
                false,
                null
            );

            String alphaKey =
                teamKey(String.valueOf(alphaParent.Team_Name__c));

            Boolean invalidDateBlocked = false;
            try {
                ctrl_StoreManagerDailyActivityCnt_v2.initiateWithoutChanges(
                    activityRecord.Id,
                    Date.today().addDays(-1),
                    alphaKey
                );
            } catch (AuraHandledException exceptionRecord) {
                invalidDateBlocked = true;
            }
            System.assertEquals(true, invalidDateBlocked);

            ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput crossTeamInput =
                new ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput();
            crossTeamInput.dateAssignmentId = alphaRow.Id;
            crossTeamInput.actualExecutiveId = betaExecutive.Id;
            crossTeamInput.activeForDate = true;

            Boolean crossTeamBlocked = false;
            try {
                ctrl_StoreManagerDailyActivityCnt_v2.initiateWithChanges(
                    activityRecord.Id,
                    Date.today(),
                    alphaKey,
                    new List<ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput>{
                        crossTeamInput
                    }
                );
            } catch (AuraHandledException exceptionRecord) {
                crossTeamBlocked = true;
            }
            System.assertEquals(true, crossTeamBlocked);

            ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput wrongStoreInput =
                new ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput();
            wrongStoreInput.dateAssignmentId = alphaRow.Id;
            wrongStoreInput.actualExecutiveId = otherStoreExecutive.Id;
            wrongStoreInput.activeForDate = true;

            Boolean wrongStoreBlocked = false;
            try {
                ctrl_StoreManagerDailyActivityCnt_v2.initiateWithChanges(
                    activityRecord.Id,
                    Date.today(),
                    alphaKey,
                    new List<ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput>{
                        wrongStoreInput
                    }
                );
            } catch (AuraHandledException exceptionRecord) {
                wrongStoreBlocked = true;
            }
            System.assertEquals(true, wrongStoreBlocked);

            createApprovalHierarchy(storeRecord.Id);

            ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput unchangedInput =
                new ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput();
            unchangedInput.dateAssignmentId = alphaRow.Id;
            unchangedInput.actualExecutiveId = alphaExecutive.Id;
            unchangedInput.activeForDate = true;
            unchangedInput.activityLocation =
                String.valueOf(alphaRow.Activity_Location__c);

            Boolean unchangedBlocked = false;
            try {
                ctrl_StoreManagerDailyActivityCnt_v2.saveAndSendForApproval(
                    activityRecord.Id,
                    Date.today(),
                    alphaKey,
                    new List<ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput>{
                        unchangedInput
                    }
                );
            } catch (AuraHandledException exceptionRecord) {
                unchangedBlocked = true;
            }
            System.assertEquals(true, unchangedBlocked);

            ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput invalidLocationInput =
                new ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput();
            invalidLocationInput.dateAssignmentId = alphaRow.Id;
            invalidLocationInput.actualExecutiveId = alphaExecutive.Id;
            invalidLocationInput.activeForDate = true;
            invalidLocationInput.activityLocation =
                String.valueOf(alphaRow.Activity_Location__c) + ' - Invalid';

            Boolean invalidLocationBlocked = false;
            try {
                ctrl_StoreManagerDailyActivityCnt_v2.saveAndSendForApproval(
                    activityRecord.Id,
                    Date.today(),
                    alphaKey,
                    new List<ctrl_StoreManagerDailyActivityCnt_v2.ExecutiveChangeInput>{
                        invalidLocationInput
                    }
                );
            } catch (AuraHandledException exceptionRecord) {
                invalidLocationBlocked = true;
            }
            System.assertEquals(true, invalidLocationBlocked);

            alphaRow.Approval_Locked__c = true;
            update alphaRow;

            Boolean lockedRowBlocked = false;
            try {
                ctrl_StoreManagerDailyActivityCnt_v2.initiateWithoutChanges(
                    activityRecord.Id,
                    Date.today(),
                    alphaKey
                );
            } catch (AuraHandledException exceptionRecord) {
                lockedRowBlocked = true;
            }
            System.assertEquals(true, lockedRowBlocked);
        }
    }


    @IsTest
    static void testReschedulePreview() {
        System.runAs(getAdministrator()) {
            Date selectedDate = Date.today().addDays(1);
            Date newDate = selectedDate.addDays(1);

            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    1,
                    selectedDate
                );
            BTL_GoLive_TestDataFactory.createApprovedTransaction(scenario);

            String selectedTeamKey =
                BTL_GoLive_TestDataFactory.teamKey(
                    BTL_GoLive_TestDataFactory.DEFAULT_TEAM
                );

            Test.startTest();
            ctrl_StoreManagerDailyActivityCnt_v2.ScheduleActionResponse result =
                ctrl_StoreManagerDailyActivityCnt_v2.rescheduleActivity(
                    scenario.activity.Id,
                    selectedDate,
                    newDate,
                    selectedTeamKey,
                    'Postponed by Store Manager',
                    false
                );
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(0, result.processedRecords);
            System.assertEquals('Postponed', result.actionType);
            System.assertEquals(newDate, result.newActivityDate);
        }
    }

    @IsTest
    static void testRescheduleExecute() {
        System.runAs(getAdministrator()) {
            Date selectedDate = Date.today().addDays(1);
            Date newDate = selectedDate.addDays(1);

            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    1,
                    selectedDate
                );
            BTL_GoLive_TestDataFactory.createApprovedTransaction(scenario);

            String selectedTeamKey =
                BTL_GoLive_TestDataFactory.teamKey(
                    BTL_GoLive_TestDataFactory.DEFAULT_TEAM
                );

            Test.startTest();
            ctrl_StoreManagerDailyActivityCnt_v2.ScheduleActionResponse result =
                ctrl_StoreManagerDailyActivityCnt_v2.rescheduleActivity(
                    scenario.activity.Id,
                    selectedDate,
                    newDate,
                    selectedTeamKey,
                    'Postponed by Store Manager',
                    true
                );

            Form_Activity_Assigned_Persons_Date__c oldDateRecord = [
                SELECT Assignment_Status__c, Is_Active__c
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Id = :scenario.dateRecord.Id
            ];

            List<Form_Activity_Assigned_Persons_Date__c> newDateRows = [
                SELECT Id, Approval_Status__c, Approval_Locked__c,
                    Assignment_Status__c, Is_Active__c, Rescheduled_From__c
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Form_Activity_Assigned_Persons__c =
                    :scenario.assignedPerson.Id
                AND Target_Date__c = :newDate
            ];
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals('Postponed', result.actionType);
            System.assertEquals(1, result.processedRecords);
            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_RESCHEDULED,
                oldDateRecord.Assignment_Status__c
            );
            System.assertEquals(false, oldDateRecord.Is_Active__c);
            System.assertEquals(1, newDateRows.size());
            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING,
                newDateRows[0].Approval_Status__c
            );
            System.assertEquals(true, newDateRows[0].Approval_Locked__c);
            System.assertEquals(
                scenario.dateRecord.Id,
                newDateRows[0].Rescheduled_From__c
            );
        }
    }

    @IsTest
    static void testDropActivityFlow() {
        System.runAs(getAdministrator()) {
            Date selectedDate = Date.today().addDays(1);

            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    1,
                    selectedDate
                );
            Tagged_Approval_Hierarchy__c transactionRecord =
                BTL_GoLive_TestDataFactory.createApprovedTransaction(
                    scenario
                );

            String selectedTeamKey =
                BTL_GoLive_TestDataFactory.teamKey(
                    BTL_GoLive_TestDataFactory.DEFAULT_TEAM
                );

            Test.startTest();
            ctrl_StoreManagerDailyActivityCnt_v2.ScheduleActionResponse result =
                ctrl_StoreManagerDailyActivityCnt_v2.dropActivity(
                    scenario.activity.Id,
                    selectedDate,
                    selectedTeamKey,
                    'Activity cancelled'
                );
            transactionRecord = [
                SELECT Id, Approval_Status__c, Last_Action__c
                FROM Tagged_Approval_Hierarchy__c
                WHERE Id = :transactionRecord.Id
            ];
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals('Dropped', result.actionType);
            System.assertEquals(1, result.processedRecords);
            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED,
                transactionRecord.Approval_Status__c
            );
            System.assertEquals(
                Ctrl_Hlp_BTLApprovalConstants.ACTION_ACTIVITY_DROPPED,
                transactionRecord.Last_Action__c
            );
        }
    }

    @IsTest
    static void testScheduleValidationBranches() {
        System.runAs(getAdministrator()) {
            Date selectedDate = Date.today().addDays(1);
            BTL_GoLive_TestDataFactory.Scenario scenario =
                BTL_GoLive_TestDataFactory.createApprovalScenario(
                    1,
                    selectedDate
                );
            BTL_GoLive_TestDataFactory.createApprovedTransaction(scenario);

            String selectedTeamKey =
                BTL_GoLive_TestDataFactory.teamKey(
                    BTL_GoLive_TestDataFactory.DEFAULT_TEAM
                );

            Test.startTest();

            Boolean sameDateBlocked = false;
            try {
                ctrl_StoreManagerDailyActivityCnt_v2.rescheduleActivity(
                    scenario.activity.Id,
                    selectedDate,
                    selectedDate,
                    selectedTeamKey,
                    'Invalid same date',
                    false
                );
            } catch (AuraHandledException ex) {
                sameDateBlocked = true;
            }

            Boolean missingReasonBlocked = false;
            try {
                ctrl_StoreManagerDailyActivityCnt_v2.dropActivity(
                    scenario.activity.Id,
                    selectedDate,
                    selectedTeamKey,
                    null
                );
            } catch (AuraHandledException ex) {
                missingReasonBlocked = true;
            }

            Test.stopTest();

            System.assertEquals(true, sameDateBlocked);
            System.assertEquals(true, missingReasonBlocked);
        }
    }

    private static User getAdministrator() {
        return [
            SELECT Id
            FROM User
            WHERE LastName = :ADMIN_LAST_NAME
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    private static Store__c createStore(String storeName) {
        Store__c storeRecord = new Store__c();
        setField(storeRecord, 'Name', storeName);
        insertRecord(storeRecord, new Map<String, Id>());
        return storeRecord;
    }

    private static Sales_Executives__c createExecutive(
        Id storeId,
        String executiveName
    ) {
        Sales_Executives__c executiveRecord = new Sales_Executives__c();
        setField(executiveRecord, 'Name', executiveName);
        setField(executiveRecord, 'Store__c', storeId);

        insertRecord(
            executiveRecord,
            new Map<String, Id>{
                'Store__c' => storeId,
                'User' => UserInfo.getUserId()
            }
        );

        return executiveRecord;
    }

    private static Final_Customize_Form__c createFinalForm(Id storeId) {
        Final_Customize_Form__c formRecord = new Final_Customize_Form__c();
        setField(formRecord, 'Name', 'Test Form ' + uniqueToken());
        setField(formRecord, 'Store__c', storeId);
        insertRecord(
            formRecord,
            new Map<String, Id>{
                'Store__c' => storeId,
                'User' => UserInfo.getUserId()
            }
        );
        return formRecord;
    }

    private static Form_Activity__c createActivity(
        Id storeId,
        String activityName,
        Date startDate,
        Date endDate,
        String location
    ) {
        Final_Customize_Form__c finalForm = createFinalForm(storeId);
        Form_Activity__c activityRecord = new Form_Activity__c();

        setField(activityRecord, 'Name', 'FA-' + uniqueToken());
        setField(activityRecord, 'Activity_Name__c', activityName);
        setField(activityRecord, 'Activity_Date__c', startDate);
        setField(activityRecord, 'Activity_End_Date__c', endDate);
        setField(activityRecord, 'Activity_Location__c', location);
        setField(activityRecord, 'Assigned_Store__c', storeId);
        setField(activityRecord, 'Final_Customize_Form__c', finalForm.Id);

        insertRecord(
            activityRecord,
            new Map<String, Id>{
                'Store__c' => storeId,
                'Final_Customize_Form__c' => finalForm.Id,
                'User' => UserInfo.getUserId()
            }
        );

        return activityRecord;
    }

    private static Form_Activity_Assigned_Persons__c createAssignedPerson(
        Id activityId,
        Id storeId,
        Id executiveId,
        String requestedTeamName
    ) {
        Form_Activity_Assigned_Persons__c parentRecord =
            new Form_Activity_Assigned_Persons__c();

        setField(parentRecord, 'Name', 'AP-' + uniqueToken());
        setField(parentRecord, 'Form_Activity__c', activityId);
        setField(parentRecord, 'Store__c', storeId);
        setField(parentRecord, 'Sales_Executives__c', executiveId);
        setField(parentRecord, 'Team_Name__c', requestedTeamName);
        setField(parentRecord, 'Person_Name__c', 'Person ' + uniqueToken());

        insertRecord(
            parentRecord,
            new Map<String, Id>{
                'Form_Activity__c' => activityId,
                'Store__c' => storeId,
                'Sales_Executives__c' => executiveId,
                'User' => UserInfo.getUserId()
            }
        );

        return parentRecord;
    }

    private static Form_Activity_Assigned_Persons_Date__c createDateAssignment(
        Id parentId,
        Id storeId,
        Id actualExecutiveId,
        Date targetDate,
        String location,
        Boolean activeForDate,
        Boolean approvalLocked,
        Id executionId
    ) {
        Form_Activity_Assigned_Persons_Date__c dateRow =
            new Form_Activity_Assigned_Persons_Date__c();

        setField(dateRow, 'Name', 'APD-' + uniqueToken());
        setField(dateRow, 'Form_Activity_Assigned_Persons__c', parentId);
        setField(dateRow, 'Store__c', storeId);
        setField(dateRow, 'Target_Date__c', targetDate);
        setField(dateRow, 'Activity_Location__c', location);
        setField(dateRow, 'Actual_Executive__c', actualExecutiveId);
        setField(dateRow, 'Active_For_Date__c', activeForDate);
        setField(dateRow, 'Approval_Status__c', 'Not Submitted');
        setField(dateRow, 'Approval_Locked__c', approvalLocked);
        setField(dateRow, 'Present__c', false);
        setField(dateRow, 'Form_Activity_Daily_Execution__c', executionId);

        Map<String, Id> referenceDefaults = new Map<String, Id>{
            'Form_Activity_Assigned_Persons__c' => parentId,
            'Store__c' => storeId,
            'User' => UserInfo.getUserId()
        };

        if (actualExecutiveId != null) {
            referenceDefaults.put('Sales_Executives__c', actualExecutiveId);
        }
        if (executionId != null) {
            referenceDefaults.put(
                'Form_Activity_Daily_Execution__c',
                executionId
            );
        }

        insertRecord(dateRow, referenceDefaults);
        return dateRow;
    }

    private static void markApprovedForStoreAction(
        List<Form_Activity_Assigned_Persons_Date__c> rows
    ) {
        if (rows == null || rows.isEmpty()) {
            return;
        }

        List<Form_Activity_Assigned_Persons_Date__c> updates =
            new List<Form_Activity_Assigned_Persons_Date__c>();

        for (Form_Activity_Assigned_Persons_Date__c rowRecord : rows) {
            if (rowRecord == null || rowRecord.Id == null) {
                continue;
            }

            updates.add(
                new Form_Activity_Assigned_Persons_Date__c(
                    Id = rowRecord.Id,
                    Approval_Status__c = 'Approved',
                    Approval_Locked__c = true,
                    Assignment_Status__c = 'Active',
                    Is_Active__c = true
                )
            );
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static Form_Activity_Daily_Execution__c createExecution(
        Id activityId,
        Id storeId,
        Date selectedDate,
        String executionKeyValue,
        String status,
        Boolean approved,
        Boolean live
    ) {
        Form_Activity_Daily_Execution__c executionRecord =
            new Form_Activity_Daily_Execution__c();

        setField(executionRecord, 'Name', 'EX-' + uniqueToken());
        setField(executionRecord, 'Form_Activity__c', activityId);
        setField(executionRecord, 'Activity_Date__c', selectedDate);
        setField(executionRecord, 'Store__c', storeId);
        setField(executionRecord, 'Execution_Key__c', executionKeyValue);
        setField(executionRecord, 'Status__c', status);
        setField(executionRecord, 'Store_Manager_Approved__c', approved);
        setField(executionRecord, 'BTL_Activity_Live__c', live);

        insertRecord(
            executionRecord,
            new Map<String, Id>{
                'Form_Activity__c' => activityId,
                'Store__c' => storeId,
                'User' => UserInfo.getUserId()
            }
        );

        return executionRecord;
    }

    private static Approval_Hierarchy__c createApprovalHierarchy(Id storeId) {
        // saveAndSendForApproval ultimately routes through
        // Ctrl_Hlp_BTLApproverResolver. A hierarchy header by itself is not
        // enough: the resolver requires at least one sequenced level and one
        // active primary approver mapping for that level.
        Approval_Hierarchy__c hierarchyRecord =
            BTL_GoLive_TestDataFactory.createApprovalHierarchy(storeId);

        Approval_Hierarchy_Level__c levelRecord =
            BTL_GoLive_TestDataFactory.createApprovalLevel(
                hierarchyRecord.Id,
                1
            );

        BTL_GoLive_TestDataFactory.createApproverMapping(
            hierarchyRecord.Id,
            levelRecord.Id,
            UserInfo.getUserId()
        );

        return hierarchyRecord;
    }

    private static String teamKey(String teamNameValue) {
        if (String.isBlank(teamNameValue)) {
            return 'NO_TEAM';
        }

        return EncodingUtil.convertToHex(
            Crypto.generateDigest(
                'SHA-256',
                Blob.valueOf(teamNameValue.trim().toLowerCase())
            )
        );
    }

    private static String executionKey(
        Id activityId,
        Date selectedDate,
        String teamKeyValue
    ) {
        return String.valueOf(activityId) +
            '-' +
            String.valueOf(selectedDate) +
            '-' +
            (String.isBlank(teamKeyValue) ? 'NO_TEAM' : teamKeyValue.trim());
    }

    private static void insertRecord(
        SObject record,
        Map<String, Id> referenceDefaults
    ) {
        populateRequiredFields(record, referenceDefaults);
        insert record;
    }

    /*
     * This helper supplies ordinary mandatory fields dynamically. If the org
     * has validation rules requiring additional business-specific values,
     * add those values in the relevant create...() helper above.
     */
    private static void populateRequiredFields(
        SObject record,
        Map<String, Id> referenceDefaults
    ) {
        Map<String, Schema.SObjectField> fieldMap =
            record.getSObjectType().getDescribe().fields.getMap();

        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult description =
                fieldMap.get(fieldName).getDescribe();

            if (
                !description.isCreateable() ||
                description.isCalculated() ||
                description.isAutoNumber() ||
                description.isNillable() ||
                description.isDefaultedOnCreate() ||
                record.get(fieldName) != null
            ) {
                continue;
            }

            String typeName =
                String.valueOf(description.getType()).toUpperCase();

            if (typeName == 'REFERENCE') {
                Id referenceId = resolveReference(description, referenceDefaults);
                if (referenceId != null) {
                    record.put(fieldName, referenceId);
                }
            } else if (typeName == 'BOOLEAN') {
                record.put(fieldName, false);
            } else if (typeName == 'DATE') {
                record.put(fieldName, Date.today());
            } else if (typeName == 'DATETIME') {
                record.put(fieldName, System.now());
            } else if (typeName == 'TIME') {
                record.put(fieldName, Time.newInstance(9, 0, 0, 0));
            } else if (
                typeName == 'INTEGER' ||
                typeName == 'DOUBLE' ||
                typeName == 'CURRENCY' ||
                typeName == 'PERCENT' ||
                typeName == 'LONG'
            ) {
                record.put(fieldName, 1);
            } else if (
                typeName == 'PICKLIST' ||
                typeName == 'MULTIPICKLIST' ||
                typeName == 'COMBOBOX'
            ) {
                String picklistValue = firstActiveValue(description);
                if (picklistValue != null) {
                    record.put(fieldName, picklistValue);
                }
            } else if (typeName == 'EMAIL') {
                record.put(
                    fieldName,
                    fitLength(
                        'test.' + uniqueToken() + '@example.com',
                        description.getLength()
                    )
                );
            } else if (typeName == 'PHONE') {
                record.put(fieldName, '9999999999');
            } else if (typeName == 'URL') {
                record.put(fieldName, 'https://example.com');
            } else if (typeName == 'BASE64') {
                record.put(fieldName, Blob.valueOf('Test'));
            } else if (
                typeName == 'STRING' ||
                typeName == 'TEXTAREA' ||
                typeName == 'ENCRYPTEDSTRING'
            ) {
                record.put(
                    fieldName,
                    fitLength(
                        'Test ' + fieldName + ' ' + uniqueToken(),
                        description.getLength()
                    )
                );
            }
        }
    }

    private static Id resolveReference(
        Schema.DescribeFieldResult description,
        Map<String, Id> referenceDefaults
    ) {
        for (Schema.SObjectType referencedType : description.getReferenceTo()) {
            String apiName = referencedType.getDescribe().getName();

            if (
                referenceDefaults != null &&
                referenceDefaults.containsKey(apiName)
            ) {
                return referenceDefaults.get(apiName);
            }

            if (apiName == 'User') {
                return UserInfo.getUserId();
            }
        }

        return null;
    }

    private static void setField(
        SObject record,
        String fieldName,
        Object value
    ) {
        if (value == null) {
            return;
        }

        Map<String, Schema.SObjectField> fieldMap =
            record.getSObjectType().getDescribe().fields.getMap();

        if (!fieldMap.containsKey(fieldName)) {
            return;
        }

        Schema.DescribeFieldResult description =
            fieldMap.get(fieldName).getDescribe();

        if (
            !description.isCreateable() ||
            description.isCalculated() ||
            description.isAutoNumber()
        ) {
            return;
        }

        String typeName =
            String.valueOf(description.getType()).toUpperCase();

        if (
            typeName == 'PICKLIST' ||
            typeName == 'MULTIPICKLIST' ||
            typeName == 'COMBOBOX'
        ) {
            String requestedValue = String.valueOf(value);
            for (Schema.PicklistEntry entry : description.getPicklistValues()) {
                if (entry.isActive() && entry.getValue() == requestedValue) {
                    record.put(fieldName, requestedValue);
                    return;
                }
            }

            String fallbackValue = firstActiveValue(description);
            if (fallbackValue != null) {
                record.put(fieldName, fallbackValue);
            }
            return;
        }

        record.put(fieldName, value);
    }

    private static String firstActiveValue(
        Schema.DescribeFieldResult description
    ) {
        for (Schema.PicklistEntry entry : description.getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static String fitLength(String value, Integer maximumLength) {
        if (
            value == null ||
            maximumLength == null ||
            maximumLength <= 0 ||
            value.length() <= maximumLength
        ) {
            return value;
        }
        return value.substring(0, maximumLength);
    }

    private static String uniqueToken() {
        sequenceNumber++;
        return String.valueOf(DateTime.now().getTime()) +
            '-' +
            String.valueOf(sequenceNumber);
    }
}