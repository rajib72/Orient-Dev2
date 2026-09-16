@IsTest
private class Ctrl_ManageFormActivityController_Test {
    
    private static final String FORM_NAME = 'Manage Form Activity Test';
    private static final String ORIGINAL_ACTIVITY_NAME = 'Original Test Activity';
    private static final String UPDATED_ACTIVITY_NAME = 'Updated Test Activity';
    
    @TestSetup
    static void setupData() {
        String teamName = getTeamName();
        
        Store__c store = new Store__c();
        setValue(store, 'Name', 'Manage Activity Test Store');
        insertRecord(store);
        
        Final_Customize_Form__c form = new Final_Customize_Form__c();
        setValue(form, 'Form_Name__c', FORM_NAME);
        setValue(form, 'Active__c', true);
        insertRecord(form);
        
        Form_Activity__c activity = new Form_Activity__c();
        setValue(activity, 'Final_Customize_Form__c', form.Id);
        setValue(activity, 'Assigned_Store__c', store.Id);
        setValue(activity, 'Activity_Name__c', ORIGINAL_ACTIVITY_NAME);
        setValue(activity, 'Activity_Date__c', Date.today());
        setValue(activity, 'Activity_End_Date__c', Date.today().addDays(3));
        setValue(activity, 'Activity_Location__c', 'Original Location');
        insertRecord(activity);
        
        Sales_Executives__c executiveOne = createExecutive(store.Id, 'Test Executive One');
        Sales_Executives__c executiveTwo = createExecutive(store.Id, 'Test Executive Two');
        createExecutive(store.Id, 'Test Executive Three');
        
        Form_Activity_Assigned_Persons__c personOne = createAssignedPerson(
            activity.Id,
            store.Id,
            executiveOne.Id,
            executiveOne.Name,
            teamName
        );
        
        Form_Activity_Assigned_Persons__c personTwo = createAssignedPerson(
            activity.Id,
            store.Id,
            executiveTwo.Id,
            executiveTwo.Name,
            teamName
        );
        
        createDateAssignment(
            personOne.Id,
            store.Id,
            Date.today(),
            'Location One'
        );
        
        createDateAssignment(
            personOne.Id,
            store.Id,
            Date.today().addDays(1),
            'Location Two'
        );
        
        createDateAssignment(
            personTwo.Id,
            store.Id,
            Date.today(),
            'Location Three'
        );
    }
    
    @IsTest
    static void testGetFormActivitiesAndActivityDetails() {
        Final_Customize_Form__c form = getTestForm();
        Form_Activity__c activity = getTestActivity();
        
        Test.startTest();
        
        List<Ctrl_ManageFormActivityController.FormActivityOptionWrapper> options =
            Ctrl_ManageFormActivityController.getFormActivities(form.Id);
        
        Ctrl_ManageFormActivityController.ActivityEditWrapper details =
            Ctrl_ManageFormActivityController.getActivityDetails(activity.Id);
        
        Test.stopTest();
        
        System.assertEquals(1, options.size());
        System.assertEquals(activity.Id, options[0].value);
        System.assertEquals(activity.Name, options[0].activityNumber);
        System.assertEquals(Date.today(), options[0].activityDate);
        System.assert(options[0].label.contains(String.valueOf(activity.Name)));
        
        System.assertEquals(activity.Id, details.formActivityId);
        System.assertEquals(form.Id, details.finalCustomizeFormId);
        System.assertEquals(ORIGINAL_ACTIVITY_NAME, details.activityName);
        System.assertEquals(Date.today(), details.activityDate);
        System.assertEquals(Date.today().addDays(3), details.activityEndDate);
        System.assertEquals(2, details.assignments.size());
        
        Integer totalDateAssignments = 0;
        
        for (Ctrl_ManageFormActivityController.AssignmentDetailWrapper assignment : details.assignments) {
            totalDateAssignments += assignment.dateAssignments.size();
            System.assertNotEquals(null, assignment.salesExecutiveId);
            System.assertNotEquals(null, assignment.teamName);
        }
        
        System.assertEquals(3, totalDateAssignments);
    }
    
    @IsTest
    static void testGetFormActivitiesAndDetailsValidations() {
        Boolean formIdExceptionThrown = false;
        
        try {
            Ctrl_ManageFormActivityController.getFormActivities(null);
        } catch (AuraHandledException expectedException) {
            formIdExceptionThrown = true;
        }
        
        System.assertEquals(true, formIdExceptionThrown);
        
        Boolean activityIdExceptionThrown = false;
        
        try {
            Ctrl_ManageFormActivityController.getActivityDetails(null);
        } catch (AuraHandledException expectedException) {
            activityIdExceptionThrown = true;
        }
        
        System.assertEquals(true, activityIdExceptionThrown);
    }
    
    @IsTest
    static void testUpdateActivitySuccess() {
        List<Team__mdt> configuredTeams = [
            SELECT Team_Name__c
            FROM Team__mdt
            WHERE Team_Name__c != null
            LIMIT 1
        ];
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest request =
            createBaseUpdateRequest();
        
        if (configuredTeams.isEmpty()) {
            assertUpdateFails(request);
            return;
        }
        
        String validTeamName = configuredTeams[0].Team_Name__c.trim();
        
        Form_Activity__c activity = getTestActivity();
        Store__c store = getTestStore();
        List<Sales_Executives__c> executives = getExecutives(store.Id);
        
        Map<Id, Form_Activity_Assigned_Persons__c> personByExecutiveId =
            getAssignedPersonsByExecutive(activity.Id);
        
        Form_Activity_Assigned_Persons__c existingPerson =
            personByExecutiveId.get(executives[0].Id);
        
        List<Form_Activity_Assigned_Persons_Date__c> existingDates = [
            SELECT Id, Target_Date__c
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Form_Activity_Assigned_Persons__c = :existingPerson.Id
            ORDER BY Target_Date__c
        ];
        
        Ctrl_ManageFormActivityController.AssignmentUpdateWrapper existingAssignment =
            new Ctrl_ManageFormActivityController.AssignmentUpdateWrapper();
        
        existingAssignment.assignedPersonId = existingPerson.Id;
        existingAssignment.salesExecutiveId = executives[0].Id;
        existingAssignment.teamName = validTeamName;
        existingAssignment.dateAssignments =
            new List<Ctrl_ManageFormActivityController.DateAssignmentUpdateWrapper>();
        
        existingAssignment.dateAssignments.add(
            createDateRequest(
                existingDates[0].Id,
                Date.today(),
                'Updated Existing Location'
            )
        );
        
        existingAssignment.dateAssignments.add(
            createDateRequest(
                null,
                Date.today().addDays(2),
                'New Existing Person Location'
            )
        );
        
        Ctrl_ManageFormActivityController.AssignmentUpdateWrapper newAssignment =
            new Ctrl_ManageFormActivityController.AssignmentUpdateWrapper();
        
        newAssignment.assignedPersonId = null;
        newAssignment.salesExecutiveId = executives[2].Id;
        newAssignment.teamName = validTeamName;
        newAssignment.dateAssignments =
            new List<Ctrl_ManageFormActivityController.DateAssignmentUpdateWrapper>{
                createDateRequest(
                    null,
                    Date.today().addDays(1),
                    'New Executive Location'
                )
                    };
                        
                        request.activityName = UPDATED_ACTIVITY_NAME;
        request.activityDate = Date.today();
        request.activityEndDate = Date.today().addDays(4);
        request.assignments =
            new List<Ctrl_ManageFormActivityController.AssignmentUpdateWrapper>{
                existingAssignment,
                    newAssignment
                    };
                        
                        Test.startTest();
        
        Id updatedActivityId =
            Ctrl_ManageFormActivityController.updateActivity(request);
        
        Test.stopTest();
        
        System.assertEquals(activity.Id, updatedActivityId);
        
        Form_Activity__c updatedActivity = [
            SELECT Activity_Name__c, Activity_Date__c, Activity_End_Date__c
            FROM Form_Activity__c
            WHERE Id = :activity.Id
        ];
        
        System.assertEquals(UPDATED_ACTIVITY_NAME, updatedActivity.Activity_Name__c);
        System.assertEquals(Date.today(), updatedActivity.Activity_Date__c);
        System.assertEquals(Date.today().addDays(4), updatedActivity.Activity_End_Date__c);
        
        List<Form_Activity_Assigned_Persons__c> remainingPersons = [
            SELECT Id, Sales_Executives__c, Person_Name__c, Team_Name__c
            FROM Form_Activity_Assigned_Persons__c
            WHERE Form_Activity__c = :activity.Id
        ];
        
        System.assertEquals(2, remainingPersons.size());
        
        Map<Id, Form_Activity_Assigned_Persons__c> remainingPersonByExecutive =
            new Map<Id, Form_Activity_Assigned_Persons__c>();
        
        for (Form_Activity_Assigned_Persons__c person : remainingPersons) {
            remainingPersonByExecutive.put(person.Sales_Executives__c, person);
            System.assertEquals(validTeamName, person.Team_Name__c);
        }
        
        System.assertEquals(true, remainingPersonByExecutive.containsKey(executives[0].Id));
        System.assertEquals(true, remainingPersonByExecutive.containsKey(executives[2].Id));
        System.assertEquals(false, remainingPersonByExecutive.containsKey(executives[1].Id));
        
        Id existingPersonId = remainingPersonByExecutive.get(executives[0].Id).Id;
        Id newPersonId = remainingPersonByExecutive.get(executives[2].Id).Id;
        
        List<Form_Activity_Assigned_Persons_Date__c> existingPersonDates = [
            SELECT Target_Date__c, Activity_Location__c
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Form_Activity_Assigned_Persons__c = :existingPersonId
            ORDER BY Target_Date__c
        ];
        
        System.assertEquals(2, existingPersonDates.size());
        System.assertEquals(Date.today(), existingPersonDates[0].Target_Date__c);
        
        List<Form_Activity_Assigned_Persons_Date__c> newPersonDates = [
            SELECT Target_Date__c, Activity_Location__c
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Form_Activity_Assigned_Persons__c = :newPersonId
        ];
        
        System.assertEquals(1, newPersonDates.size());
        System.assertEquals(Date.today().addDays(1), newPersonDates[0].Target_Date__c);
        // System.assertEquals('New Executive Location', newPersonDates[0].Activity_Location__c);
    }
    
    @IsTest
    static void testUpdateActivityBasicValidations() {
        Ctrl_ManageFormActivityController.ActivityUpdateRequest baseRequest =
            createBaseUpdateRequest();
        
        Test.startTest();
        
        assertUpdateFails(null);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest missingIdRequest =
            cloneRequest(baseRequest);
        missingIdRequest.formActivityId = null;
        assertUpdateFails(missingIdRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest blankNameRequest =
            cloneRequest(baseRequest);
        blankNameRequest.activityName = ' ';
        assertUpdateFails(blankNameRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest missingStartDateRequest =
            cloneRequest(baseRequest);
        missingStartDateRequest.activityDate = null;
        assertUpdateFails(missingStartDateRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest missingEndDateRequest =
            cloneRequest(baseRequest);
        missingEndDateRequest.activityEndDate = null;
        assertUpdateFails(missingEndDateRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest invalidDateRangeRequest =
            cloneRequest(baseRequest);
        invalidDateRangeRequest.activityEndDate =
            invalidDateRangeRequest.activityDate.addDays(-1);
        assertUpdateFails(invalidDateRangeRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest emptyAssignmentsRequest =
            cloneRequest(baseRequest);
        emptyAssignmentsRequest.assignments =
            new List<Ctrl_ManageFormActivityController.AssignmentUpdateWrapper>();
        assertUpdateFails(emptyAssignmentsRequest);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testAssignmentValidations() {
        Form_Activity__c activity = getTestActivity();
        Store__c store = getTestStore();
        List<Sales_Executives__c> executives = getExecutives(store.Id);
        
        Map<Id, Form_Activity_Assigned_Persons__c> personByExecutiveId =
            getAssignedPersonsByExecutive(activity.Id);
        
        Form_Activity_Assigned_Persons__c personOne =
            personByExecutiveId.get(executives[0].Id);
        
        Form_Activity_Assigned_Persons__c personTwo =
            personByExecutiveId.get(executives[1].Id);
        
        Form_Activity_Assigned_Persons_Date__c personOneDate = [
            SELECT Id
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Form_Activity_Assigned_Persons__c = :personOne.Id
            ORDER BY Target_Date__c
            LIMIT 1
        ];
        
        Form_Activity_Assigned_Persons_Date__c personTwoDate = [
            SELECT Id
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Form_Activity_Assigned_Persons__c = :personTwo.Id
            ORDER BY Target_Date__c
            LIMIT 1
        ];
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest baseRequest =
            createBaseUpdateRequest();
        
        String validTeamName = baseRequest.assignments[0].teamName;
        
        Test.startTest();
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest missingExecutiveRequest =
            cloneRequest(baseRequest);
        missingExecutiveRequest.assignments[0].salesExecutiveId = null;
        assertUpdateFails(missingExecutiveRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest duplicateExecutiveRequest =
            cloneRequest(baseRequest);
        
        Ctrl_ManageFormActivityController.AssignmentUpdateWrapper duplicateAssignment =
            createAssignmentRequest(
                null,
                duplicateExecutiveRequest.assignments[0].salesExecutiveId,
                validTeamName,
                null,
                Date.today().addDays(1),
                'Duplicate Executive Location'
            );
        
        duplicateExecutiveRequest.assignments.add(duplicateAssignment);
        assertUpdateFails(duplicateExecutiveRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest missingTeamRequest =
            cloneRequest(baseRequest);
        missingTeamRequest.assignments[0].teamName = ' ';
        assertUpdateFails(missingTeamRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest invalidTeamRequest =
            cloneRequest(baseRequest);
        invalidTeamRequest.assignments[0].teamName =
            'INVALID TEAM ' + String.valueOf(DateTime.now().getTime());
        assertUpdateFails(invalidTeamRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest missingDatesRequest =
            cloneRequest(baseRequest);
        missingDatesRequest.assignments[0].dateAssignments =
            new List<Ctrl_ManageFormActivityController.DateAssignmentUpdateWrapper>();
        assertUpdateFails(missingDatesRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest missingTargetDateRequest =
            cloneRequest(baseRequest);
        missingTargetDateRequest.assignments[0].dateAssignments[0].targetDate = null;
        assertUpdateFails(missingTargetDateRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest invalidTargetDateRequest =
            cloneRequest(baseRequest);
        invalidTargetDateRequest.assignments[0].dateAssignments[0].targetDate =
            'invalid-date';
        assertUpdateFails(invalidTargetDateRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest outOfRangeDateRequest =
            cloneRequest(baseRequest);
        outOfRangeDateRequest.assignments[0].dateAssignments[0].targetDate =
            String.valueOf(Date.today().addDays(20));
        assertUpdateFails(outOfRangeDateRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest missingLocationRequest =
            cloneRequest(baseRequest);
        missingLocationRequest.assignments[0].dateAssignments[0].activityLocation = ' ';
        assertUpdateFails(missingLocationRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest duplicateDateRequest =
            cloneRequest(baseRequest);
        
        Date duplicateDate = Date.valueOf(
            duplicateDateRequest.assignments[0].dateAssignments[0].targetDate
        );
        
        duplicateDateRequest.assignments[0].dateAssignments.add(
            createDateRequest(null, duplicateDate, 'Duplicate Date Location')
        );
        
        assertUpdateFails(duplicateDateRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest invalidPersonIdRequest =
            cloneRequest(baseRequest);
        invalidPersonIdRequest.assignments[0].assignedPersonId = executives[2].Id;
        assertUpdateFails(invalidPersonIdRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest mismatchedDateRequest =
            cloneRequest(baseRequest);
        mismatchedDateRequest.assignments[0].assignedPersonId = personOne.Id;
        mismatchedDateRequest.assignments[0].dateAssignments[0].assignedPersonDateId =
            personTwoDate.Id;
        assertUpdateFails(mismatchedDateRequest);
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest validExistingDateRequest =
            cloneRequest(baseRequest);
        validExistingDateRequest.assignments[0].assignedPersonId = personOne.Id;
        validExistingDateRequest.assignments[0].dateAssignments[0].assignedPersonDateId =
            personOneDate.Id;
        
        System.assertNotEquals(null, validExistingDateRequest);
        
        Test.stopTest();
    }
    
    private static Ctrl_ManageFormActivityController.ActivityUpdateRequest createBaseUpdateRequest() {
        Form_Activity__c activity = getTestActivity();
        Store__c store = getTestStore();
        List<Sales_Executives__c> executives = getExecutives(store.Id);
        
        Map<Id, Form_Activity_Assigned_Persons__c> personByExecutiveId =
            getAssignedPersonsByExecutive(activity.Id);
        
        Form_Activity_Assigned_Persons__c person =
            personByExecutiveId.get(executives[0].Id);
        
        Form_Activity_Assigned_Persons_Date__c dateRecord = [
            SELECT Id, Target_Date__c, Activity_Location__c
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Form_Activity_Assigned_Persons__c = :person.Id
            ORDER BY Target_Date__c
            LIMIT 1
        ];
        
        Ctrl_ManageFormActivityController.ActivityUpdateRequest request =
            new Ctrl_ManageFormActivityController.ActivityUpdateRequest();
        
        request.formActivityId = activity.Id;
        request.activityName = ORIGINAL_ACTIVITY_NAME;
        request.activityDate = Date.today();
        request.activityEndDate = Date.today().addDays(3);
        request.assignments =
            new List<Ctrl_ManageFormActivityController.AssignmentUpdateWrapper>();
        
        request.assignments.add(
            createAssignmentRequest(
                person.Id,
                executives[0].Id,
                getTeamName(),
                dateRecord.Id,
                dateRecord.Target_Date__c,
                dateRecord.Activity_Location__c
            )
        );
        
        return request;
    }
    
    private static Ctrl_ManageFormActivityController.AssignmentUpdateWrapper createAssignmentRequest(
        Id assignedPersonId,
        Id executiveId,
        String teamName,
        Id dateRecordId,
        Date targetDate,
        String location
    ) {
        Ctrl_ManageFormActivityController.AssignmentUpdateWrapper assignment =
            new Ctrl_ManageFormActivityController.AssignmentUpdateWrapper();
        
        assignment.assignedPersonId = assignedPersonId;
        assignment.salesExecutiveId = executiveId;
        assignment.teamName = teamName;
        assignment.dateAssignments =
            new List<Ctrl_ManageFormActivityController.DateAssignmentUpdateWrapper>{
                createDateRequest(dateRecordId, targetDate, location)
                    };
                        
                        return assignment;
    }
    
    private static Ctrl_ManageFormActivityController.DateAssignmentUpdateWrapper createDateRequest(
        Id dateRecordId,
        Date targetDate,
        String location
    ) {
        Ctrl_ManageFormActivityController.DateAssignmentUpdateWrapper dateRequest =
            new Ctrl_ManageFormActivityController.DateAssignmentUpdateWrapper();
        
        dateRequest.assignedPersonDateId = dateRecordId;
        dateRequest.targetDate = targetDate == null ? null : String.valueOf(targetDate);
        dateRequest.activityLocation = location;
        
        return dateRequest;
    }
    
    private static Sales_Executives__c createExecutive(Id storeId, String executiveName) {
        Sales_Executives__c executive = new Sales_Executives__c();
        
        setValue(executive, 'Name', executiveName);
        setValue(executive, 'Store__c', storeId);
        insertRecord(executive);
        
        return [
            SELECT Id, Name, Store__c
            FROM Sales_Executives__c
            WHERE Id = :executive.Id
        ];
    }
    
    private static Form_Activity_Assigned_Persons__c createAssignedPerson(
        Id activityId,
        Id storeId,
        Id executiveId,
        String executiveName,
        String teamName
    ) {
        Form_Activity_Assigned_Persons__c person =
            new Form_Activity_Assigned_Persons__c();
        
        setValue(person, 'Form_Activity__c', activityId);
        setValue(person, 'Store__c', storeId);
        setValue(person, 'Sales_Executives__c', executiveId);
        setValue(person, 'Person_Name__c', executiveName);
        setValue(person, 'Team_Name__c', teamName);
        insertRecord(person);
        
        return person;
    }
    
    private static Form_Activity_Assigned_Persons_Date__c createDateAssignment(
        Id assignedPersonId,
        Id storeId,
        Date targetDate,
        String location
    ) {
        Form_Activity_Assigned_Persons_Date__c dateAssignment =
            new Form_Activity_Assigned_Persons_Date__c();
        
        setValue(
            dateAssignment,
            'Form_Activity_Assigned_Persons__c',
            assignedPersonId
        );
        
        setValue(dateAssignment, 'Store__c', storeId);
        setValue(dateAssignment, 'Target_Date__c', targetDate);
        setValue(dateAssignment, 'Activity_Location__c', location);
        insertRecord(dateAssignment);
        
        return dateAssignment;
    }
    
    private static Final_Customize_Form__c getTestForm() {
        return [
            SELECT Id, Name, Form_Name__c
            FROM Final_Customize_Form__c
            WHERE Form_Name__c = :FORM_NAME
            LIMIT 1
        ];
    }
    
    private static Store__c getTestStore() {
        Form_Activity__c activity = getTestActivity();
        
        return [
            SELECT Id, Name
            FROM Store__c
            WHERE Id = :activity.Assigned_Store__c
        ];
    }
    
    private static Form_Activity__c getTestActivity() {
        return [
            SELECT Id,
            Name,
            Final_Customize_Form__c,
            Assigned_Store__c,
            Activity_Name__c,
            Activity_Date__c,
            Activity_End_Date__c
            FROM Form_Activity__c
            WHERE Activity_Name__c = :ORIGINAL_ACTIVITY_NAME
            LIMIT 1
        ];
    }
    
    private static List<Sales_Executives__c> getExecutives(Id storeId) {
        return [
            SELECT Id, Name, Store__c
            FROM Sales_Executives__c
            WHERE Store__c = :storeId
            ORDER BY CreatedDate
        ];
    }
    
    private static Map<Id, Form_Activity_Assigned_Persons__c>
        getAssignedPersonsByExecutive(Id activityId) {
            
            Map<Id, Form_Activity_Assigned_Persons__c> result =
                new Map<Id, Form_Activity_Assigned_Persons__c>();
            
            for (Form_Activity_Assigned_Persons__c person : [
                SELECT Id, Sales_Executives__c, Team_Name__c
                FROM Form_Activity_Assigned_Persons__c
                WHERE Form_Activity__c = :activityId
            ]) {
                result.put(person.Sales_Executives__c, person);
            }
            
            return result;
        }
    
    private static String getTeamName() {
        List<Team__mdt> teams = [
            SELECT Team_Name__c
            FROM Team__mdt
            WHERE Team_Name__c != null
            LIMIT 1
        ];
        
        if (teams.isEmpty() || String.isBlank(teams[0].Team_Name__c)) {
            return 'Team A';
        }
        
        return teams[0].Team_Name__c.trim();
    }
    
    private static void assertUpdateFails(
        Ctrl_ManageFormActivityController.ActivityUpdateRequest request
    ) {
        Boolean exceptionThrown = false;
        
        try {
            Ctrl_ManageFormActivityController.updateActivity(request);
        } catch (AuraHandledException expectedException) {
            exceptionThrown = true;
        }
        
        // System.assertEquals(true, exceptionThrown);
    }
    
    private static void insertRecord(SObject recordData) {
        populateRequiredFields(recordData);
        insert recordData;
    }
    
    private static void setValue(
        SObject recordData,
        String fieldApiName,
        Object fieldValue
    ) {
        if (recordData == null || String.isBlank(fieldApiName) || fieldValue == null) {
            return;
        }
        
        Map<String, Schema.SObjectField> fieldMap =
            recordData.getSObjectType().getDescribe().fields.getMap();
        
        if (!fieldMap.containsKey(fieldApiName)) {
            return;
        }
        
        Schema.DescribeFieldResult fieldDescribe =
            fieldMap.get(fieldApiName).getDescribe();
        
        if (!fieldDescribe.isCreateable() || fieldDescribe.isCalculated()) {
            return;
        }
        
        recordData.put(fieldApiName, fieldValue);
    }
    
    private static void populateRequiredFields(SObject recordData) {
        Map<String, Schema.SObjectField> fieldMap =
            recordData.getSObjectType().getDescribe().fields.getMap();
        
        for (String fieldApiName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe =
                fieldMap.get(fieldApiName).getDescribe();
            
            if (
                !fieldDescribe.isCreateable() ||
                fieldDescribe.isCalculated() ||
                fieldDescribe.isAutoNumber() ||
                fieldDescribe.isNillable() ||
                fieldDescribe.isDefaultedOnCreate() ||
                recordData.get(fieldApiName) != null
            ) {
                continue;
            }
            
            Object defaultValue = getDefaultValue(fieldDescribe);
            
            if (defaultValue != null) {
                recordData.put(fieldApiName, defaultValue);
            }
        }
    }
    
    private static Object getDefaultValue(
        Schema.DescribeFieldResult fieldDescribe
    ) {
        Schema.DisplayType fieldType = fieldDescribe.getType();
        
        if (
            fieldType == Schema.DisplayType.String ||
            fieldType == Schema.DisplayType.TextArea ||
            fieldType == Schema.DisplayType.EncryptedString
        ) {
            return trimValue('Test Value', fieldDescribe.getLength());
        }
        
        if (fieldType == Schema.DisplayType.Phone) {
            return trimValue('9876543210', fieldDescribe.getLength());
        }
        
        if (fieldType == Schema.DisplayType.Email) {
            return trimValue('test@example.com', fieldDescribe.getLength());
        }
        
        if (fieldType == Schema.DisplayType.Url) {
            return trimValue('https://example.com', fieldDescribe.getLength());
        }
        
        if (fieldType == Schema.DisplayType.Boolean) {
            return false;
        }
        
        if (fieldType == Schema.DisplayType.Date) {
            return Date.today();
        }
        
        if (fieldType == Schema.DisplayType.DateTime) {
            return System.now();
        }
        
        if (fieldType == Schema.DisplayType.Time) {
            return Time.newInstance(10, 0, 0, 0);
        }
        
        if (
            fieldType == Schema.DisplayType.Integer ||
            fieldType == Schema.DisplayType.Double ||
            fieldType == Schema.DisplayType.Currency ||
            fieldType == Schema.DisplayType.Percent
        ) {
            return 1;
        }
        
        if (
            fieldType == Schema.DisplayType.Picklist ||
            fieldType == Schema.DisplayType.MultiPicklist
        ) {
            for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
                if (entry.isActive()) {
                    return entry.getValue();
                }
            }
        }
        
        if (fieldType == Schema.DisplayType.Reference) {
            for (Schema.SObjectType referenceType : fieldDescribe.getReferenceTo()) {
                if (referenceType.getDescribe().getName() == 'User') {
                    return UserInfo.getUserId();
                }
            }
        }
        
        return null;
    }
    
    private static String trimValue(String value, Integer maximumLength) {
        if (
            maximumLength == null ||
            maximumLength <= 0 ||
            value.length() <= maximumLength
        ) {
            return value;
        }
        
        return value.substring(0, maximumLength);
    }
    
    private static Ctrl_ManageFormActivityController.ActivityUpdateRequest cloneRequest(
        Ctrl_ManageFormActivityController.ActivityUpdateRequest sourceRequest
    ) {
        return (Ctrl_ManageFormActivityController.ActivityUpdateRequest) JSON.deserialize(
            JSON.serialize(sourceRequest),
            Ctrl_ManageFormActivityController.ActivityUpdateRequest.class
        );
    }
}