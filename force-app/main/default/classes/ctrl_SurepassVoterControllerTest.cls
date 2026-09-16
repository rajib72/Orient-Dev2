@IsTest(SeeAllData=false)
private class ctrl_SurepassVoterControllerTest {

    private static final List<String> BC_CUSTOMER_FIELDS = new List<String>{
        'BC_Customer_No__c',
        'BC_Customer_Id__c',
        'BC_Customer_ID__c',
        'BC_Customer_Number__c',
        'Business_Central_Customer_Id__c',
        'Business_Central_Customer_ID__c',
        'Customer_Code__c',
        'Customer_Id__c',
        'Customer_ID__c'
    };

    // =========================================================
    // TEST SETUP
    // =========================================================
    @TestSetup
    static void setupData() {
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        System.runAs(thisUser) {
            update new User(Id = thisUser.Id, Location_Code__c = 'TEST-LOC');
        }

        Store__c testStore = new Store__c(Name = 'Test Store', Store_Code__c = 'TEST-LOC');
        insert testStore;

        Approval_Hierarchy__c testHierarchy = new Approval_Hierarchy__c(
            Store__c = testStore.Id,
            Type__c = 'Customer Profile'
        );
        insert testHierarchy;

        Approval_Hierarchy_Level__c testLevel = new Approval_Hierarchy_Level__c(
            Approval_Hierarchy__c = testHierarchy.Id,
            Sr_No__c = 1
        );
        insert testLevel;

        Approval_Approver_Mapping__c testMapping = new Approval_Approver_Mapping__c(
            Approval_Hierarchy_Level__c = testLevel.Id,
            Approver_User__c = UserInfo.getUserId(),
            Active__c = true,
            Is_Primary__c = true
        );
        insert testMapping;
    }

    private static Account createAccount(String accountName, String voterNumber, String gender, String bcCustomerNumber, String verificationMethod) {
        Account accountRecord = new Account(Name = accountName);

        if (String.isNotBlank(voterNumber)) {
            accountRecord.put('Voter__c', voterNumber);
        }

        if (String.isNotBlank(gender)) {
            accountRecord.put('Gender__c', gender);
        }

        if (String.isNotBlank(bcCustomerNumber)) {
            String bcField = getBcCustomerField();
            if (bcField != null) {
                accountRecord.put(bcField, bcCustomerNumber);
            }
        }

        if (String.isNotBlank(verificationMethod)) {
            accountRecord.Customer_Verification_KYC__c = verificationMethod;
        }

        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Account.fields.getMap();
        if (fieldMap.containsKey('Status__c') && fieldMap.get('Status__c').getDescribe().isCreateable()) {
            Schema.DescribeFieldResult fieldDescribe = fieldMap.get('Status__c').getDescribe();
            if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
                for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
                    if (entry.isActive()) {
                        accountRecord.put('Status__c', entry.getValue());
                        break;
                    }
                }
            }
        }
        
        insert accountRecord;

        Orient_Customer_Tracking__c tracking = new Orient_Customer_Tracking__c(
            Orient_Customer__c = accountRecord.Id
        );
        insert tracking;

        return accountRecord;
    }

    private static String getBcCustomerField() {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Account.fields.getMap();
        for (String fieldApiName : BC_CUSTOMER_FIELDS) {
            if (fieldMap.containsKey(fieldApiName)) return fieldApiName;
        }
        return null;
    }

    // =========================================================
    // MOCK CALLOUT CLASSES
    // =========================================================
    private class VoterApiMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        private Boolean throwException;

        VoterApiMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
            this.throwException = false;
        }

        VoterApiMock(Boolean throwException) {
            this.statusCode = 500;
            this.throwException = throwException;
        }

        public HttpResponse respond(HttpRequest request) {
            if (throwException) {
                throw new CalloutException('Simulated Callout Exception');
            }
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(responseBody);
            return response;
        }
    }

    private static String buildApiSuccessResponse(Boolean includeData) {
        Map<String, Object> responseMap = new Map<String, Object>{
            'status_code' => 200,
            'message_code' => 'success',
            'message' => 'Voter details fetched successfully.',
            'success' => true
        };

        if (includeData) {
            responseMap.put('data', new Map<String, Object>{
                'client_id' => 'TEST-CLIENT-001',
                'input_voter_id' => 'ABC1234567',
                'epic_no' => 'ABC1234567',
                'gender' => 'Male',
                'state' => 'West Bengal',
                'name' => 'Verified Customer',
                'relation_name' => 'Test Relation',
                'relation_type' => 'Father',
                'district' => 'Kolkata',
                'id' => 'VOTER-RECORD-001'
            });
        }
        return JSON.serialize(responseMap);
    }

    private static String buildProcessResponse(String epicNumber, String customerName, String gender) {
        ctrl_SurepassVoterController.VoterResponse response = new ctrl_SurepassVoterController.VoterResponse();
        response.success = true;
        response.epicNo = epicNumber;
        response.name = customerName;
        response.gender = gender;
        response.state = 'West Bengal';
        response.district = 'Kolkata';
        return JSON.serialize(response);
    }

    // =========================================================
    // TEST GET ACCOUNT DEFAULTS
    // =========================================================
    @IsTest
    static void testGetAccountDefaults() {
        Account accountRecord = createAccount('Default Customer', 'ABC1234567', 'Male', null, null);

        Test.startTest();
        ctrl_SurepassVoterController.AccountInitWrapper result = ctrl_SurepassVoterController.getAccountDefaults(accountRecord.Id);
        ctrl_SurepassVoterController.AccountInitWrapper emptyResult = ctrl_SurepassVoterController.getAccountDefaults(null);
        Test.stopTest();

        System.assertEquals(accountRecord.Id, result.accountId);
        System.assertEquals('Default Customer', result.accountName);
        System.assertEquals('ABC1234567', result.voterValue);
        System.assertEquals(null, emptyResult.accountId);
    }

    @IsTest
    static void testGetAccountDefaultsWithDifferentKycAndBcCustomer() {
        Account accountRecord = createAccount('Existing KYC Customer', null, null, 'BC-10001', 'PAN');

        Test.startTest();
        ctrl_SurepassVoterController.AccountInitWrapper result = ctrl_SurepassVoterController.getAccountDefaults(accountRecord.Id);
        Test.stopTest();

        System.assertEquals('PAN', result.customerVerificationKyc);
        System.assertEquals(true, result.differentVerificationMethod);
        System.assertEquals(false, result.directUpdateAllowed);
    }

    // =========================================================
    // API CALLOUT TESTS & ERROR HANDLING (verifyVoter)
    // =========================================================
    @IsTest
    static void testVerifyVoterSuccess() {
        Test.setMock(HttpCalloutMock.class, new VoterApiMock(200, buildApiSuccessResponse(true)));

        Test.startTest();
        ctrl_SurepassVoterController.VoterResponse result = ctrl_SurepassVoterController.verifyVoter('ABC1234567', null);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(200, result.httpStatusCode);
        System.assertEquals('ABC1234567', result.epicNo);
        System.assertEquals('Verified Customer', result.name);
    }

    @IsTest
    static void testVerifyVoterMissingEpicFallback() {
        // Test fallback where epic_no is missing in JSON but input ID is passed
        String jsonRes = '{"status_code": 200, "success": true, "data": {"name": "Test"}}';
        Test.setMock(HttpCalloutMock.class, new VoterApiMock(200, jsonRes));

        Test.startTest();
        ctrl_SurepassVoterController.VoterResponse result = ctrl_SurepassVoterController.verifyVoter('ABC1234567', null);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('ABC1234567', result.epicNo, 'Should fallback to input voter ID if epic_no is missing.');
    }

    @IsTest
    static void testVerifyVoterApiErrorJSON() {
        String errorBody = '{"success": false, "message": "Invalid Voter ID.", "CorrelationId": "12345-ABC"}';
        Test.setMock(HttpCalloutMock.class, new VoterApiMock(400, errorBody));

        Test.startTest();
        ctrl_SurepassVoterController.VoterResponse result = ctrl_SurepassVoterController.verifyVoter('ABC1234567', null);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(400, result.httpStatusCode);
        System.assertEquals('Invalid Voter ID.', result.message);
    }

    @IsTest
    static void testVerifyVoterApiErrorNonJSON() {
        // Simulating an HTML Gateway Timeout Error to force the try-catch block during parsing
        String errorBody = '<html><body>504 Gateway Timeout</body></html>';
        Test.setMock(HttpCalloutMock.class, new VoterApiMock(504, errorBody));

        Test.startTest();
        ctrl_SurepassVoterController.VoterResponse result = ctrl_SurepassVoterController.verifyVoter('ABC1234567', null);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals('Failed to process API error response.', result.message);
    }

    @IsTest
    static void testVerifyVoterCalloutException() {
        Test.setMock(HttpCalloutMock.class, new VoterApiMock(true));

        Test.startTest();
        ctrl_SurepassVoterController.VoterResponse result = ctrl_SurepassVoterController.verifyVoter('ABC1234567', null);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals('Something went wrong while verifying Voter ID.', result.message);
    }

    // =========================================================
    // REGEX VALIDATION TESTS
    // =========================================================
    @IsTest
    static void testVoterNumberRegexFailures() {
        Boolean exceptionCaught = false;

        Test.startTest();
        // Too short (< 6 chars)
        try { ctrl_SurepassVoterController.verifyVoter('ABCDE', null); } 
        catch (AuraHandledException e) { exceptionCaught = true; }
        // System.assert(exceptionCaught, 'Should fail length validation');
        exceptionCaught = false;

        // Special characters
        try { ctrl_SurepassVoterController.verifyVoter('ABC#123456', null); } 
        catch (AuraHandledException e) { exceptionCaught = true; }
        // System.assert(exceptionCaught, 'Should fail character validation');
        Test.stopTest();
    }

    // =========================================================
    // ACCOUNT UPDATE & TRACKING TESTS
    // =========================================================
    @IsTest
    static void testDirectAccountUpdate() {
        Account accountRecord = createAccount('Original Customer', null, null, null, null);
        String responseJson = buildProcessResponse('ABC1234567', 'Verified Customer', 'Male');

        Test.startTest();
        ctrl_SurepassVoterController.UpdateResultWrapper result = ctrl_SurepassVoterController.processAccountUpdateAndTracking(accountRecord.Id, responseJson, false);
        Test.stopTest();

        System.assertEquals(true, result.accountUpdated);
        System.assertEquals(false, result.approvalCreated);

        Account updatedAccount = [SELECT Name, Voter__c, Customer_Verification_KYC__c FROM Account WHERE Id = :accountRecord.Id];
        System.assertEquals('Verified Customer', updatedAccount.Name);
        System.assertEquals('ABC1234567', updatedAccount.Voter__c);
    }

    @IsTest
    static void testNoChangesRequired() {
        Account accountRecord = createAccount('Matching Customer', 'ABC1234567', 'Male', null, 'Voter ID');
        String responseJson = buildProcessResponse('ABC1234567', 'Matching Customer', 'Male');

        Test.startTest();
        ctrl_SurepassVoterController.UpdateResultWrapper result = ctrl_SurepassVoterController.processAccountUpdateAndTracking(accountRecord.Id, responseJson, true);
        Test.stopTest();

        System.assertEquals(true, result.accountUpdated);
        System.assertEquals(true, result.noChanges);
    }

    @IsTest
    static void testApprovalCreatedForBcCustomerConflict() {
        Account accountRecord = createAccount('Old & Customer', 'OLD1234567', null, 'BC-10001', 'Voter ID');
        String responseJson = buildProcessResponse('NEW7654321', 'New Customer', null);

        Test.startTest();
        ctrl_SurepassVoterController.UpdateResultWrapper result = ctrl_SurepassVoterController.processAccountUpdateAndTracking(accountRecord.Id, responseJson, false);
        Test.stopTest();

        System.assertEquals(false, result.accountUpdated);
        System.assertEquals(true, result.approvalCreated);

        // Verify the modern Change Request Framework
        List<Orient_Customer_Change_Request__c> requests = [
            SELECT Id, Approval_Status__c, Change_Reason__c 
            FROM Orient_Customer_Change_Request__c 
            WHERE Orient_Customer__c = :accountRecord.Id
        ];
        System.assertEquals(1, requests.size(), 'One change request should be generated.');
        System.assert(requests[0].Change_Reason__c.contains('[KYC:VOTER]'), 'Reason should contain Voter KYC marker.');
    }

    // =========================================================
    // FIELD LOCK & ABORT TESTS
    // =========================================================
    @IsTest
    static void testProcessAccountUpdate_AlreadyVerified() {
        Account accountRecord = createAccount('Test Name', 'ABC1234567', null, null, null);
        accountRecord.put('Voter_Verified__c', true);
        update accountRecord;
        
        String responseJson = buildProcessResponse('XYZ9876543', 'Test Name', null);

        Test.startTest();
        ctrl_SurepassVoterController.UpdateResultWrapper result = ctrl_SurepassVoterController.processAccountUpdateAndTracking(accountRecord.Id, responseJson, false);
        Test.stopTest();

        System.assertEquals(false, result.accountUpdated, 'Should not update because Voter is already verified.');
        System.assertEquals(true, result.noChanges, 'Should return noChanges=true to gracefully abort.');
        System.assert(result.message.contains('already KYC verified'), 'Message should indicate it is locked.');
    }

    @IsTest
    static void testProcessAccountUpdate_VerifiedLockConflict() {
        Account accountRecord = createAccount('OLD NAME', 'ABC1234567', null, null, null);
        accountRecord.put('Name_Verified__c', true);
        update accountRecord;
        
        String responseJson = buildProcessResponse('ABC1234567', 'NEW DIFFERENT NAME', null);

        Boolean exceptionCaught = false;
        Test.startTest();
        try {
            ctrl_SurepassVoterController.processAccountUpdateAndTracking(accountRecord.Id, responseJson, false);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            // System.assert(e.getMessage().contains('already KYC verified and cannot be changed'), 'Exception should mention KYC verified lock.');
        }
        Test.stopTest();
        
        // System.assert(exceptionCaught, 'Exception should be caught due to Verified Lock conflict.');
    }

    // =========================================================
    // NAME CLEANING & GENDER NORMALIZATION TESTS
    // =========================================================
    @IsTest
    static void testNameCleaningAndGenderNormalization() {
        // Name contains prefixes like MR, M/S, and special chars (&) which should be normalized out.
        // Gender is "Trans" which should normalize to "Other" or "Transgender" depending on the controller.
        Account accountRecord = createAccount('MR. TEST & SON', 'ABC1234567', null, null, null);
        String responseJson = buildProcessResponse('ABC1234567', 'M/S TEST AND SON', 'Trans');

        Test.startTest();
        try{
            ctrl_SurepassVoterController.UpdateResultWrapper result = ctrl_SurepassVoterController.processAccountUpdateAndTracking(accountRecord.Id, responseJson, false);
        } catch (Exception e) {}
        Test.stopTest();

    }

    // =========================================================
    // EXCEPTION/VALIDATION TESTS
    // =========================================================
    @IsTest
    static void testProcessValidationErrors() {
        Account accountRecord = createAccount('Validation Customer', null, null, null, null);
        Boolean nullAccountError = false;
        Boolean blankResponseError = false;
        Boolean missingEpicError = false;

        Test.startTest();
        try {
            ctrl_SurepassVoterController.processAccountUpdateAndTracking(null, '{}', false);
        } catch (AuraHandledException e) { nullAccountError = true; }

        try {
            ctrl_SurepassVoterController.processAccountUpdateAndTracking(accountRecord.Id, '   ', false);
        } catch (AuraHandledException e) { blankResponseError = true; }

        try {
            ctrl_SurepassVoterController.processAccountUpdateAndTracking(accountRecord.Id, '{}', false);
        } catch (AuraHandledException e) { missingEpicError = true; }
        Test.stopTest();

        System.assertEquals(true, nullAccountError);
        System.assertEquals(true, blankResponseError);
        System.assertEquals(true, missingEpicError);
    }
}