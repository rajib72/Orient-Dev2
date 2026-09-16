@IsTest
private class Ctrl_API_CreateActiveCustomerTest {

    // =========================================================
    // TEST DATA SETUP
    // =========================================================
    @TestSetup
    static void setupTestData() {
        Account existingAcc = new Account();
        existingAcc.Name = 'Existing Customer';
        existingAcc.BC_Customer_No__c = 'CUST-EXIST-001';
        insert existingAcc;
    }

    // =========================================================
    // HELPER METHODS
    // =========================================================
    private static void setRestContext(String jsonBody) {
        RestRequest request   = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI    = '/services/apexrest/CreateActiveCust/';
        request.httpMethod    = 'POST';
        if (jsonBody != null) {
            request.requestBody = Blob.valueOf(jsonBody);
        }
        RestContext.request   = request;
        RestContext.response  = response;
    }

    // =========================================================
    // TEST 1: Single record - successful creation (no customerNo)
    // =========================================================
    @IsTest
    static void testCreateSingleAccount_NoCustomerNo() {

        Map<String, Object> payload = new Map<String, Object>{
            'name'  => 'John Doe',
            'phone' => '9876543210',
            'email' => 'john@test.com'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Name = 'John Doe'
        ];
        
        System.assertEquals(1, accounts.size(), 'One new account should be created.');
        System.assertEquals('John Doe', accounts[0].Name, 'Account name should match the payload.');
        System.assertEquals('9876543210', accounts[0].Phone, 'Account phone should match the payload.');
        System.assertEquals(200, RestContext.response.statusCode, 'HTTP Status should be 200 OK.');
    }

    // =========================================================
    // TEST 2: Single record - creation WITH customerNo (new)
    // =========================================================
    @IsTest
    static void testCreateSingleAccount_WithCustomerNo_New() {

        Map<String, Object> payload = new Map<String, Object>{
            'name'       => 'New Customer',
            'phone'      => '9000000001',
            'customerNo' => 'CUST-NEW-001'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id, Name, BC_Customer_No__c
            FROM Account
            WHERE BC_Customer_No__c = 'CUST-NEW-001'
        ];
        
        System.assertEquals(1, accounts.size(), 'One account should be created with the specified BC Customer No.');
        System.assertEquals('New Customer', accounts[0].Name, 'Account name should match.');
        System.assertEquals(200, RestContext.response.statusCode, 'HTTP Status should be 200 OK.');
    }

    // =========================================================
    // TEST 3: Single record - UPDATE existing via customerNo
    // =========================================================
    @IsTest
    static void testUpdateExistingAccount_WithCustomerNo() {

        Account existing = [
            SELECT Id, BC_Customer_No__c
            FROM Account
            WHERE BC_Customer_No__c = 'CUST-EXIST-001'
            LIMIT 1
        ];

        Map<String, Object> payload = new Map<String, Object>{
            'name'       => 'Updated Customer Name',
            'phone'      => '9000000002',
            'customerNo' => 'CUST-EXIST-001'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        Account updated = [
            SELECT Id, Name, BC_Customer_No__c
            FROM Account
            WHERE BC_Customer_No__c = 'CUST-EXIST-001'
            LIMIT 1
        ];
        
        System.assertEquals(existing.Id, updated.Id, 'The existing account should be updated, not a new one created.');
        System.assertEquals('Updated Customer Name', updated.Name, 'The account name should be updated.');
    }

    // =========================================================
    // TEST 4: Bulk records - successful creation
    // =========================================================
    @IsTest
    static void testCreateBulkAccounts() {

        List<Map<String, Object>> payloadList =
            new List<Map<String, Object>>();

        for (Integer i = 1; i <= 5; i++) {
            payloadList.add(new Map<String, Object>{
                'name'       => 'Bulk User ' + i,
                'phone'      => '9876500' + String.valueOf(i).leftPad(3, '0'),
                'customerNo' => 'BULK-CUST-' + i
            });
        }

        setRestContext(JSON.serialize(payloadList));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id, Name
            FROM Account
            WHERE Name LIKE 'Bulk User%'
        ];
        
        System.assertEquals(5, accounts.size(), '5 bulk accounts should be successfully created.');
        System.assertEquals(200, RestContext.response.statusCode, 'HTTP Status should be 200 OK.');
    }

    // =========================================================
    // TEST 5: Empty array [] → payloadList.isEmpty() → 400
    // =========================================================
    @IsTest
    static void testEmptyArrayPayload() {

        setRestContext('[]');

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        RestResponse res = RestContext.response;
        String responseStr = res.responseBody.toString();
        
        System.assertEquals(400, res.statusCode, 'Status code should be 400 for an empty array.');
        System.assert(responseStr.contains('No records received.'), 'Error message should complain about no records.');
    }

    // =========================================================
    // TEST 6: Exceeds 200 records limit → 400
    // =========================================================
    @IsTest
    static void testExceedsMaxRecordsLimit() {

        List<Map<String, Object>> payloadList =
            new List<Map<String, Object>>();

        for (Integer i = 1; i <= 201; i++) {
            payloadList.add(new Map<String, Object>{
                'name'  => 'Limit User ' + i,
                'phone' => '9000000' + String.valueOf(i).leftPad(3, '0')
            });
        }

        setRestContext(JSON.serialize(payloadList));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        RestResponse res = RestContext.response;
        String responseStr = res.responseBody.toString();
        
        System.assertEquals(400, res.statusCode, 'Status code should be 400 for exceeding the chunk size.');
        System.assert(responseStr.contains('Maximum 200 records allowed'), 'Error message should state the 200 limit.');
    }

    // =========================================================
    // TEST 7: Exactly 200 records - boundary test → 200
    // =========================================================
    @IsTest
    static void testExactlyMaxRecords() {

        List<Map<String, Object>> payloadList =
            new List<Map<String, Object>>();

        for (Integer i = 1; i <= 200; i++) {
            payloadList.add(new Map<String, Object>{
                'name'       => 'Exact Limit User ' + i,
                'customerNo' => 'EXACT-' + String.valueOf(i).leftPad(3, '0')
            });
        }

        setRestContext(JSON.serialize(payloadList));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE Name LIKE 'Exact Limit User%'
        ];
        
        System.assertEquals(200, accounts.size(), 'Exactly 200 accounts should be created successfully.');
        System.assertEquals(200, RestContext.response.statusCode, 'HTTP Status should be 200 OK.');
    }

    // =========================================================
    // TEST 8: Missing required field 'name' → validation fail
    // =========================================================
    @IsTest
    static void testMissingNameField() {

        Map<String, Object> payload = new Map<String, Object>{
            'phone' => '9876543210'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id FROM Account WHERE Phone = '9876543210'
        ];
        
        System.assertEquals(0, accounts.size(), 'Account should not be created if Name is missing.');
        System.assertEquals(207, RestContext.response.statusCode, 'Status code should be 207 Multi-Status for partial/complete batch failures.');
    }

    // =========================================================
    // TEST 9: Empty string for name → validation fail
    // =========================================================
    @IsTest
    static void testEmptyNameField() {

        Map<String, Object> payload = new Map<String, Object>{
            'name'  => '',
            'phone' => '9000000003'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id FROM Account WHERE Phone = '9000000003'
        ];
        
        System.assertEquals(0, accounts.size(), 'Account should not be created if Name is an empty string.');
    }

    // =========================================================
    // TEST 10: Null name field → validation fail
    // =========================================================
    @IsTest
    static void testNullNameField() {

        Map<String, Object> payload = new Map<String, Object>{
            'name'  => null,
            'phone' => '9000000004'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id FROM Account WHERE Phone = '9000000004'
        ];
        
        System.assertEquals(0, accounts.size(), 'Account should not be created if Name is explicitly null.');
    }

    // =========================================================
    // TEST 11: Mixed valid and invalid records → 207
    // =========================================================
    @IsTest
    static void testMixedValidInvalidRecords() {

        List<Map<String, Object>> payloadList =
            new List<Map<String, Object>>{
                new Map<String, Object>{
                    'name'  => 'Valid User 1',
                    'phone' => '1111111111'
                },
                new Map<String, Object>{
                    'phone' => '2222222222' // Missing name
                },
                new Map<String, Object>{
                    'name'  => 'Valid User 2',
                    'phone' => '3333333333'
                }
            };

        setRestContext(JSON.serialize(payloadList));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id, Name FROM Account WHERE Name LIKE 'Valid User%'
        ];
        
        System.assertEquals(2, accounts.size(), 'Only the two valid records should be inserted.');
        System.assertEquals(207, RestContext.response.statusCode, 'Status code should be 207 for mixed success and failures.');
    }

    // =========================================================
    // TEST 12: Date field - valid date format
    // =========================================================
    @IsTest
    static void testValidDateField() {

        Map<String, Object> payload = new Map<String, Object>{
            'name'             => 'Date Test User',
            'dob'              => '1985-05-20',
            'anniversary_date' => '2010-06-15'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id, Name, Date_Of_Birth__c, Anniversary_Date__c
            FROM Account
            WHERE Name = 'Date Test User'
        ];
        
        System.assertEquals(1, accounts.size(), 'Account should be created successfully.');
        System.assertEquals(Date.valueOf('1985-05-20'), accounts[0].Date_Of_Birth__c, 'Date of Birth should map correctly.');
        System.assertEquals(Date.valueOf('2010-06-15'), accounts[0].Anniversary_Date__c, 'Anniversary date should map correctly.');
    }

    // =========================================================
    // TEST 13: Date field - INVALID format → field skipped,
    //          account still created (covers catch in field mapping)
    // =========================================================
    @IsTest
    static void testInvalidDateFormat() {

        Map<String, Object> payload = new Map<String, Object>{
            'name' => 'Invalid Date User',
            'dob'  => 'not-a-date'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id, Name, Date_Of_Birth__c
            FROM Account
            WHERE Name = 'Invalid Date User'
        ];
        
        System.assertEquals(1, accounts.size(), 'Account should still be created despite invalid date field format.');
        System.assertEquals(null, accounts[0].Date_Of_Birth__c, 'Invalid date field should gracefully fail and remain null.');
    }

    // =========================================================
    // TEST 14: Boolean field - valid value
    // =========================================================
    @IsTest
    static void testBooleanFieldHandling() {

        Map<String, Object> payload = new Map<String, Object>{
            'name'                  => 'Boolean Test User',
            'consent_for_marketing' => true,
            'dnc_status'            => false
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id,
                   Consent_for_Marketing_Communications__c,
                   Do_Not_Contact_DNC_Status__c
            FROM Account
            WHERE Name = 'Boolean Test User'
        ];
    }

    // =========================================================
    // TEST 15: Unknown/unmapped fields are ignored
    // =========================================================
    @IsTest
    static void testUnknownFieldsIgnored() {

        Map<String, Object> payload = new Map<String, Object>{
            'name'            => 'Unknown Field User',
            'unknown_field_1' => 'Some Value',
            'unknown_field_2' => 12345
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id, Name FROM Account WHERE Name = 'Unknown Field User'
        ];
        
        System.assertEquals(1, accounts.size(), 'Account should be created successfully, ignoring unmapped fields.');
    }

    // =========================================================
    // TEST 16: Null value for a mapped field → field skipped
    // =========================================================
    @IsTest
    static void testNullValueForMappedField() {

        Map<String, Object> payload = new Map<String, Object>{
            'name'   => 'Null Field User',
            'phone'  => null,
            'gender' => 'Male'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id, Name, Phone, Gender__c
            FROM Account
            WHERE Name = 'Null Field User'
        ];
        
        System.assertEquals(1, accounts.size(), 'Account should be created successfully.');
        System.assertEquals(null, accounts[0].Phone, 'Mapped fields passed as null should remain null.');
        System.assertEquals('Male', accounts[0].Gender__c, 'Valid string fields should map properly.');
    }

    // =========================================================
    // TEST 17: Invalid JSON format → 400 (exception path)
    // =========================================================
    @IsTest
    static void testMalformedJson() {

        setRestContext('{name: "Test", phone:');

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        RestResponse res = RestContext.response;
        String responseStr = res.responseBody.toString();
        
        System.assertEquals(400, res.statusCode, 'Status code should be 400 Bad Request for malformed JSON.');
        System.assert(responseStr.contains('Invalid JSON format'), 'Response message should indicate invalid JSON format.');
    }

    // =========================================================
    // TEST 18: Null request body → 400 (exception path)
    // =========================================================
    @IsTest
    static void testNullRequestBody() {

        setRestContext(null);

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        RestResponse res = RestContext.response;
        String responseStr = res.responseBody.toString();
        
        System.assertEquals(400, res.statusCode, 'Status code should be 400 for a null request body.');
        System.assert(responseStr.contains('Request body is required'), 'Response message should indicate body is required.');
    }

    // =========================================================
    // TEST 19: Empty string body → 400 (exception path)
    // =========================================================
    @IsTest
    static void testEmptyStringBody() {

        setRestContext('');

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        RestResponse res = RestContext.response;
        String responseStr = res.responseBody.toString();
        
        System.assertEquals(400, res.statusCode, 'Status code should be 400 for an empty string body.');
    }

    // =========================================================
    // TEST 20: Non-object/non-array primitive JSON → 400
    //          Covers the "Invalid JSON format" branch
    // =========================================================
    @IsTest
    static void testInvalidJsonType_PlainString() {

        setRestContext('"just a string"');

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        RestResponse res = RestContext.response;
        String responseStr = res.responseBody.toString();
        
        System.assertEquals(400, res.statusCode, 'Status code should be 400 for plain string JSON payload.');
        System.assert(responseStr.contains('Invalid JSON format'), 'Error message should indicate expected format.');
    }

    // =========================================================
    // TEST 21: Non-object element inside array
    //          Covers !(obj instanceof Map<String, Object>) branch
    // =========================================================
    @IsTest
    static void testNonObjectElementInArray() {

        String mixedJson =
            '[' +
            '"not_an_object",' +
            '{"name":"Valid User Array","phone":"9123456789"}' +
            ']';

        setRestContext(mixedJson);

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id, Name FROM Account WHERE Name = 'Valid User Array'
        ];
        
        System.assertEquals(1, accounts.size(), 'Only the valid JSON object inside the array should be inserted.');
        System.assertEquals(207, RestContext.response.statusCode, 'Status code should be 207 Multi-Status for partial processing.');
    }

    // =========================================================
    // TEST 22: customerNo with whitespace → trimmed correctly
    // =========================================================
    @IsTest
    static void testCustomerNoWithWhitespace() {

        Map<String, Object> payload = new Map<String, Object>{
            'name'       => 'Trim Test User',
            'customerNo' => '  CUST-TRIM-001  '
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id, BC_Customer_No__c
            FROM Account
            WHERE BC_Customer_No__c = 'CUST-TRIM-001'
        ];
        
        System.assertEquals(1, accounts.size(), 'Account should be inserted and customerNo whitespace should be trimmed.');
    }

    // =========================================================
    // TEST 23: Blank customerNo → no BC_Customer_No__c set
    // =========================================================
    @IsTest
    static void testBlankCustomerNo() {

        Map<String, Object> payload = new Map<String, Object>{
            'name'       => 'No CustomerNo User',
            'customerNo' => ''
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id, Name, BC_Customer_No__c
            FROM Account
            WHERE Name = 'No CustomerNo User'
        ];
        
        System.assertEquals(1, accounts.size(), 'Account should be inserted.');
        System.assertEquals(null, accounts[0].BC_Customer_No__c, 'Blank customerNo should not populate the field.');
    }

    // =========================================================
    // TEST 24: All field mappings - comprehensive coverage
    // =========================================================
    @IsTest
    static void testAllFieldsMapping() {

        Map<String, Object> payload = new Map<String, Object>{
            'name'                     => 'Complete User',
            'customerNo'               => 'CUST-COMPLETE-001',
            'phone'                    => '1111111111',
            'email'                    => 'complete@test.com',
            'whatsapp'                 => '2222222222',
            'country'                  => 'India',
            'pincode'                  => '560001',
            'residential_city'         => 'Bengaluru',
            'permanent_address'        => 'Complete Address Line',
            'locality_area'            => 'Indiranagar',
            'dob'                      => '1995-03-10',
            'anniversary_date'         => '2020-01-01',
            'gender'                   => 'Female',
            'marital_status'           => 'Married',
            'customer_type'            => 'Premium',
            'status'                   => 'Active',
            'customer_source'          => 'Website',
            'consent_for_marketing'    => true,
            'preferred_language'       => 'English',
            'loyalty_tier'             => 'Gold',
            'gst'                      => '22AAAAA0000A1Z5',
            'pan'                      => 'AAAAA1234A',
            'nationality'              => 'Indian',
            'occupation'               => 'Professional',
            'income_band'              => '10-20 Lakhs',
            'family_type'              => 'Nuclear',
            'tags'                     => 'VIP',
            'customer_notes'           => 'Test notes',
            'description'              => 'Test description',
            'title'                    => 'Mr.',
            'preferred_channel'        => 'Email',
            'preferred_time'           => 'Evening',
            'preferred_gift_wrapping'  => true,
            'preferred_price_band'     => '5000-10000',
            'referral_source'          => 'Friend',
            'registration_mode'        => 'Online',
            'state'                    => 'Karnataka',
            'state_code'               => 'KA',
            'dnc_status'               => false,
            'kyc_type'                 => 'Aadhar',
            'buying_intent'            => 'High',
            'gender_other'             => 'Other',
            'preferred_language_other' => 'French',
            'aadharNo'                 => '123456789012',
            'lead_source_detail'       => 'Campaign'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id, Name, BC_Customer_No__c,
                   Phone, Email_Address__c,
                   Date_Of_Birth__c, Gender__c,
                   Consent_for_Marketing_Communications__c
            FROM Account
            WHERE BC_Customer_No__c = 'CUST-COMPLETE-001'
        ];
    }

    // =========================================================
    // TEST 25: Mixed insert and update in same batch
    // =========================================================
    @IsTest
    static void testMixedInsertAndUpdateInBatch() {

        List<Account> preExisting = new List<Account>();
        for (Integer i = 1; i <= 3; i++) {
            preExisting.add(new Account(
                Name              = 'Pre Existing ' + i,
                BC_Customer_No__c = 'PRE-CUST-' + i
            ));
        }
        insert preExisting;

        List<Map<String, Object>> payloadList =
            new List<Map<String, Object>>();

        for (Integer i = 1; i <= 3; i++) {
            payloadList.add(new Map<String, Object>{
                'name'       => 'Updated Pre Existing ' + i,
                'customerNo' => 'PRE-CUST-' + i
            });
        }
        for (Integer i = 1; i <= 3; i++) {
            payloadList.add(new Map<String, Object>{
                'name'       => 'Brand New ' + i,
                'customerNo' => 'NEW-CUST-' + i
            });
        }

        setRestContext(JSON.serialize(payloadList));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> updated = [
            SELECT Id, Name
            FROM Account
            WHERE BC_Customer_No__c LIKE 'PRE-CUST-%'
        ];

        List<Account> inserted = [
            SELECT Id, Name
            FROM Account
            WHERE BC_Customer_No__c LIKE 'NEW-CUST-%'
        ];
        
        System.assertEquals(3, updated.size(), '3 pre-existing records should have been updated.');
        System.assertEquals(3, inserted.size(), '3 brand new records should have been inserted.');
        System.assertEquals('Updated Pre Existing 1', updated[0].Name, 'Updates should apply correctly.');
    }

    // =========================================================
    // TEST 26: Response structure validation
    // =========================================================
    @IsTest
    static void testResponseStructure() {

        List<Map<String, Object>> payloadList =
            new List<Map<String, Object>>{
                new Map<String, Object>{
                    'name'       => 'Response Test 1',
                    'customerNo' => 'RESP-001'
                },
                new Map<String, Object>{
                    'phone' => '9999999999' // Intentionally missing Name to fail
                }
            };

        setRestContext(JSON.serialize(payloadList));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        RestResponse res = RestContext.response;
        String responseStr = res.responseBody.toString();
        
        System.assert(responseStr.contains('"totalProcessed" : 1') || responseStr.contains('"totalProcessed": 1'), 'Response structure should specify total processed count.');
        System.assert(responseStr.contains('"totalFailed" : 1') || responseStr.contains('"totalFailed": 1'), 'Response structure should specify total failed count.');
        System.assertEquals(207, res.statusCode, 'Status code should be 207 for mixed results.');
    }

    // =========================================================
    // TEST 27: Numeric field as string
    // =========================================================
    @IsTest
    static void testNumericFieldAsString() {

        Map<String, Object> payload = new Map<String, Object>{
            'name'    => 'Numeric Field User',
            'pincode' => '560001'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        Ctrl_API_CreateActiveCustomer.createAccounts();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Id, Name, Pin_Code__c
            FROM Account
            WHERE Name = 'Numeric Field User'
        ];
        
        System.assertEquals(1, accounts.size(), 'Account should be inserted successfully.');
        System.assertEquals('560001', accounts[0].Pin_Code__c, 'Pin code (which might be typed differently in mapping) should parse string correctly.');
    }
}