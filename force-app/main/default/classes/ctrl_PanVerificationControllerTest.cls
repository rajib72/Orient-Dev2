@IsTest(SeeAllData=false)
private class ctrl_PanVerificationControllerTest {

    @TestSetup
    static void setupData() {
        // 1. Setup User Location Code (Required for the new Approval Routing)
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        System.runAs(thisUser) {
            update new User(Id = thisUser.Id, Location_Code__c = 'TEST-LOC');
        }

        // 2. Create Store & Approval Routing Architecture
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

    private static Account createAccount(String accountName, String panNumber, Date dateOfBirth, String gender, String bcCustomerNumber, String verificationMethod) {
        Account accountRecord = new Account(Name = accountName);

        if (panNumber != null) {
            accountRecord.PAN__c = panNumber;
        }

        if (dateOfBirth != null) {
            accountRecord.Date_Of_Birth__c = dateOfBirth;
        }

        if (gender != null) {
            accountRecord.Gender__c = gender;
        }

        if (bcCustomerNumber != null) {
            accountRecord.BC_Customer_No__c = bcCustomerNumber;
        }

        if (verificationMethod != null) {
            accountRecord.Customer_Verification_KYC__c = verificationMethod;
        }

        setAccountStatus(accountRecord);
        insert accountRecord;

        // The new architecture requires a Tracking Record to exist for the account
        Orient_Customer_Tracking__c tracking = new Orient_Customer_Tracking__c(
            Orient_Customer__c = accountRecord.Id
        );
        insert tracking;

        return accountRecord;
    }

    private static void setAccountStatus(Account accountRecord) {
        Schema.DescribeFieldResult statusDescribe = Account.Status__c.getDescribe();

        if (!statusDescribe.isCreateable()) {
            return;
        }

        if (statusDescribe.getType() == Schema.DisplayType.Picklist) {
            for (Schema.PicklistEntry entry : statusDescribe.getPicklistValues()) {
                if (entry.isActive()) {
                    accountRecord.Status__c = entry.getValue();
                    return;
                }
            }
        }
    }

    private static String getPanKycMethod() {
        return 'PAN';
    }

    private static String getNonPanKycMethod() {
        return 'GST';
    }

    private static String getGenderValue() {
        return 'Male';
    }

    private static String getDifferentGenderValue(String existingGender) {
        return (existingGender == 'Male') ? 'Female' : 'Male';
    }

    private static String buildSuccessResponse() {
        Map<String, Object> responseBody = new Map<String, Object>{
            'status_code' => 200,
            'success' => true,
            'message' => 'PAN verified successfully',
            'message_code' => 'success',
            'data' => new Map<String, Object>{
                'client_id' => 'TEST-CLIENT-001',
                'pan_number' => 'ABCDE1234F',
                'full_name' => 'Test Customer',
                'full_name_split' => new List<String>{'Test', 'Customer'},
                'masked_aadhaar' => 'XXXX-XXXX-1234',
                'email' => 'test@example.com',
                'phone_number' => '9999999999',
                'gender' => 'M',
                'dob' => '15/08/1990',
                'input_dob' => '15/08/1990',
                'aadhaar_linked' => true,
                'dob_verified' => true,
                'dob_check' => true,
                'category' => 'Individual',
                'status' => 'VALID',
                'less_info' => false,
                'address' => new Map<String, Object>{
                    'line_1' => 'Test Address Line 1',
                    'line_2' => 'Test Address Line 2',
                    'street_name' => 'Test Street',
                    'zip' => '700001',
                    'city' => 'Kolkata',
                    'state' => 'West Bengal',
                    'country' => 'India',
                    'full' => 'Test Address, Kolkata, India'
                }
            }
        };

        return JSON.serialize(responseBody);
    }

    private class PanApiMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        private Boolean throwException;

        PanApiMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
            this.throwException = false;
        }

        PanApiMock(Boolean throwException) {
            this.throwException = throwException;
        }

        public HttpResponse respond(HttpRequest request) {
            if (throwException) {
                throw new CalloutException('Mock callout failure');
            }

            System.assertEquals('POST', request.getMethod());
            System.assertEquals('application/json', request.getHeader('Content-Type'));
            System.assert(request.getEndpoint().endsWith('/api/v1/pan/pan-comprehensive'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(responseBody);
            return response;
        }
    }

    @IsTest
    static void testGetAccountInitialData() {
        String panKycMethod = getPanKycMethod();
        String genderValue = getGenderValue();

        Account accountRecord = createAccount(
            'Initial Data Customer',
            'ABCDE1234F',
            Date.newInstance(1990, 8, 15),
            genderValue,
            null,
            panKycMethod
        );

        Test.startTest();
        ctrl_PanVerificationController.AccountInitialDataWrapper result = ctrl_PanVerificationController.getAccountInitialData(accountRecord.Id);
        Test.stopTest();

        System.assertEquals('Initial Data Customer', result.accountName);
        System.assertEquals('ABCDE1234F', result.panNumber);
        System.assertEquals(Date.newInstance(1990, 8, 15), result.dateOfBirth);
        System.assertEquals(panKycMethod, result.customerVerificationKyc);
    }

    @IsTest
    static void testGetAccountInitialDataForDifferentKyc() {
        String nonPanKycMethod = getNonPanKycMethod();
        Account accountRecord = createAccount(
            'Different KYC Customer',
            null,
            null,
            null,
            null,
            nonPanKycMethod
        );

        Test.startTest();
        ctrl_PanVerificationController.AccountInitialDataWrapper result = ctrl_PanVerificationController.getAccountInitialData(accountRecord.Id);
        Test.stopTest();

        System.assertEquals(nonPanKycMethod, result.customerVerificationKyc);
        System.assertEquals(true, result.differentVerificationMethod);
        System.assertEquals(false, result.directUpdateAllowed);
    }

    @IsTest
    static void testVerifyPanSuccess() {
        Test.setMock(HttpCalloutMock.class, new PanApiMock(200, buildSuccessResponse()));

        Test.startTest();
        ctrl_PanVerificationController.PanResponseWrapper result = ctrl_PanVerificationController.verifyPan('ABCDE1234F');
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(200, result.status_code);
        System.assertNotEquals(null, result.data);
        System.assertEquals('ABCDE1234F', result.data.pan_number);
        System.assertEquals('Test Customer', result.data.full_name);
    }
    
    @IsTest
    static void testVerifyPanApiError() {
        String errorBody = JSON.serialize(new Map<String, Object>{
            'success' => false,
            'message' => 'Invalid PAN.'
        });

        Test.setMock(HttpCalloutMock.class, new PanApiMock(400, errorBody));

        Test.startTest();
        ctrl_PanVerificationController.PanResponseWrapper result = ctrl_PanVerificationController.verifyPan('INVALID123');
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals('Invalid PAN.', result.message);
    }

    @IsTest
    static void testVerifyPanCalloutException() {
        Test.setMock(HttpCalloutMock.class, new PanApiMock(true));

        Test.startTest();
        try {
            ctrl_PanVerificationController.verifyPan('ABCDE1234F');
            System.assert(false, 'Exception should have been thrown');
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void testDirectAccountUpdate() {
        String genderValue = getGenderValue();
        Account accountRecord = createAccount(
            'Original Customer',
            null,
            null,
            null,
            null,
            null
        );

        Test.startTest();
        ctrl_PanVerificationController.UpdateResultWrapper result = ctrl_PanVerificationController.updateAccountPan(accountRecord.Id, 'ABCDE1234F', false, '15/08/1990', 'Updated Customer', genderValue);
        Test.stopTest();

        System.assertEquals(true, result.accountUpdated);
        System.assertEquals(false, result.approvalCreated);

        Account updatedAccount = [
            SELECT Name, PAN__c, Date_Of_Birth__c, PAN_Verified__c, Name_Verified__c, DOB_Verified__c, Customer_Verification_KYC__c
            FROM Account
            WHERE Id = :accountRecord.Id
        ];

        System.assertEquals('Updated Customer', updatedAccount.Name);
        System.assertEquals('ABCDE1234F', updatedAccount.PAN__c);
        System.assertEquals(Date.newInstance(1990, 8, 15), updatedAccount.Date_Of_Birth__c);
        System.assertEquals(true, updatedAccount.PAN_Verified__c);
        System.assertEquals('PAN', updatedAccount.Customer_Verification_KYC__c);
    }

    @IsTest
    static void testNoChangesRequired() {
        String panKycMethod = getPanKycMethod();
        String genderValue = getGenderValue();

        Account accountRecord = createAccount(
            'Existing Customer',
            'ABCDE1234F',
            Date.newInstance(1990, 8, 15),
            genderValue,
            null,
            panKycMethod
        );

        Test.startTest();
        ctrl_PanVerificationController.UpdateResultWrapper result = ctrl_PanVerificationController.updateAccountPan(accountRecord.Id, 'ABCDE1234F', false, '1990-08-15', 'Existing Customer', genderValue);
        Test.stopTest();

        System.assertEquals(true, result.accountUpdated);
        System.assertEquals(false, result.approvalCreated);
        System.assertEquals(true, result.noChanges);
    }

    // =========================================================
    // NEW APPROVAL ARCHITECTURE TESTING
    // Tests that the proper Change Request and Items are created
    // =========================================================
    @IsTest
    static void testApprovalCreatedForBcCustomerConflict() {
        String panKycMethod = getPanKycMethod();
        String oldGender = getGenderValue();
        String newGender = getDifferentGenderValue(oldGender);

        Account accountRecord = createAccount(
            'Original & Customer',
            'AAAAA1111A',
            Date.newInstance(1985, 1, 10),
            oldGender,
            'BC-10001',
            panKycMethod
        );

        Test.startTest();
        ctrl_PanVerificationController.UpdateResultWrapper result = ctrl_PanVerificationController.updateAccountPan(accountRecord.Id, 'BBBBB2222B', false, '20/02/1990', 'New <Customer>', newGender);
        Test.stopTest();

        System.assertEquals(false, result.accountUpdated);
        System.assertEquals(true, result.approvalCreated);

        // Query the new Change Request Object
        Orient_Customer_Change_Request__c requestRecord = [
            SELECT Id, Approval_Status__c, Change_Reason__c 
            FROM Orient_Customer_Change_Request__c 
            WHERE Orient_Customer__c = :accountRecord.Id 
            LIMIT 1
        ];
  
        // Query the linked Change Items
        List<Orient_Customer_Change_Item__c> items = [
            SELECT Account_Field_API__c, Old_Value__c, New_Value__c 
            FROM Orient_Customer_Change_Item__c 
            WHERE Change_Request__c = :requestRecord.Id
        ];
        
        Boolean foundPan = false;
        Boolean foundName = false;
        
        for (Orient_Customer_Change_Item__c item : items) {
            if (item.Account_Field_API__c == 'PAN__c') {
                foundPan = true;
                System.assertEquals('AAAAA1111A', item.Old_Value__c);
                System.assertEquals('BBBBB2222B', item.New_Value__c);
            }
            if (item.Account_Field_API__c == 'Name') {
                foundName = true;
                System.assertEquals('Original & Customer', item.Old_Value__c);
                System.assertEquals('New <Customer>', item.New_Value__c);
            }
        }
        
    }

    @IsTest
    static void testApprovalCreatedForPreviousKycMethod() {
        String nonPanKycMethod = getNonPanKycMethod();

        Account accountRecord = createAccount(
            'Previous KYC Customer',
            'AAAAA1111A',
            Date.newInstance(1988, 5, 5),
            null,
            null,
            nonPanKycMethod
        );

        Test.startTest();
        ctrl_PanVerificationController.UpdateResultWrapper result = ctrl_PanVerificationController.updateAccountPan(accountRecord.Id, 'BBBBB2222B', false, null, 'Previous KYC Customer', null);
        Test.stopTest();

        System.assertEquals(false, result.accountUpdated);
        System.assertEquals(true, result.approvalCreated);

        Orient_Customer_Change_Request__c requestRecord = [
            SELECT Id, Change_Reason__c 
            FROM Orient_Customer_Change_Request__c 
            WHERE Orient_Customer__c = :accountRecord.Id 
            LIMIT 1
        ];
        
        System.assert(requestRecord.Change_Reason__c.contains('Another KYC method was completed earlier'));
    }

    @IsTest
    static void testRequiredParameterValidation() {
        Account accountRecord = createAccount(
            'Validation Customer',
            null,
            null,
            null,
            null,
            null
        );

        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            ctrl_PanVerificationController.getAccountInitialData(null);
        } catch (AuraHandledException e) { exceptionCaught = true; }
        System.assert(exceptionCaught); exceptionCaught = false;

        try {
            ctrl_PanVerificationController.updateAccountPan(null, 'ABCDE1234F', false, null, null, null);
        } catch (AuraHandledException e) { exceptionCaught = true; }
        System.assert(exceptionCaught); exceptionCaught = false;

        try {
            ctrl_PanVerificationController.updateAccountPan(accountRecord.Id, '   ', false, null, null, null);
        } catch (AuraHandledException e) { exceptionCaught = true; }
        System.assert(exceptionCaught); exceptionCaught = false;

        try {
            ctrl_PanVerificationController.verifyPan('   ');
        } catch (AuraHandledException e) { exceptionCaught = true; }
        System.assert(exceptionCaught);
        Test.stopTest();
    }
}