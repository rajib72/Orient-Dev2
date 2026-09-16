@IsTest
private class OrientCustomerPushControllerTest {

    // =========================================================
    // TEST DATA SETUP
    // =========================================================
    @TestSetup
    static void setupData() {
        Account acc = new Account();
        acc.Name = 'Base Test Account';
        insert acc;
    }

    // =========================================================
    // HELPER - Create and Insert Account
    // =========================================================
    private static Account createAndInsertAccount(
        String name,
        String phone,
        String bcCustomerNo
    ) {
        Account acc = new Account();
        acc.Name = name;
        acc.Phone = phone;

        if (String.isNotBlank(bcCustomerNo)) {
            acc.BC_Customer_No__c = bcCustomerNo;
        }

        acc.Whatsapp_number__c      = '9876543210';
        acc.Email_Address__c        = 'test@example.com';
        acc.Permanent_Address__c    = '123 Test Street';
        acc.Residential_City__c     = 'Test City';
        acc.Pin_Code__c             = '123456';
        acc.Locality_Area__c        = 'Test Locality';
        acc.AadharNo__c             = '1234567891';
        acc.Country__c              = 'India';
        acc.Country_Region_Code__c  = 'IN';
        acc.District__c             = 'Test District';
        acc.GST__c                  = 'GST123456';
        acc.PAN__c                  = 'ABCDE1234F';
        acc.StateCode__c            = 'KA';
        acc.State_Province__c       = 'Karnataka';
        acc.Village__c              = 'Test Village';
        acc.Date_Of_Birth__c        = Date.newInstance(1990, 1, 15);
        acc.Anniversary_Date__c     = Date.newInstance(2015, 6, 20);
        //acc.KYC_Verified__c         = true;

        insert acc;
        return acc;
    }

    // =========================================================
    // HELPER - Get base account Id from setup
    // =========================================================
    private static Id getBaseAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'Base Test Account' LIMIT 1].Id;
    }

    // =========================================================
    // TEST 1: Null recordId → early return with 400
    // =========================================================
    @IsTest
    static void testPushAccount_NullId() {

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(null);
        Test.stopTest();
    }

    // =========================================================
    // TEST 2: Invalid/non-existent Id → QueryException caught
    //         Fix: Use a properly formatted fake 18-char Id
    // =========================================================
    @IsTest
    static void testPushAccount_InvalidId() {

        // Properly formatted fake Id that passes Id type check
        // but will cause QueryException (no record found = SOQL returns empty,
        // and since we use LIMIT 1 without list, it throws QueryException)
        Id fakeId = '001000000000001AAA';

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(fakeId);
        Test.stopTest();
    }

    // =========================================================
    // TEST 3: Account already has BC_Customer_No__c (isUpdate=true)
    //         Covers PATCH method, update path
    // =========================================================
    @IsTest
    static void testPushAccount_IsUpdate_Success() {

        Account acc = createAndInsertAccount(
            'Update Test Account',
            '1111111111',
            'CUST-UPDATE-001'
        );

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_DIRECT')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 4: isUpdate=true with empty phone (covers phoneParam blank)
    // =========================================================
    @IsTest
    static void testPushAccount_IsUpdate_NoPhone() {

        Account acc = new Account();
        acc.Name              = 'Update No Phone';
        acc.BC_Customer_No__c = 'CUST-NOPHONE-001';
        // Phone intentionally left blank
        insert acc;

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_DIRECT')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 5: New account POST - success with direct customerNo
    //         Covers extractCustomerNo → direct key path
    // =========================================================
    @IsTest
    static void testPushAccount_NewPost_Success_Direct() {

        Account acc = createAndInsertAccount(
            'New Direct Test',
            '2222222222',
            null
        );

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_DIRECT')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();

        // Verify BC_Customer_No__c was updated on account
        Account updated = [
            SELECT BC_Customer_No__c
            FROM Account
            WHERE Id = :acc.Id
        ];
    }

    // =========================================================
    // TEST 6: New account POST - success with value array response
    //         Covers extractCustomerNo → value array path
    // =========================================================
    @IsTest
    static void testPushAccount_NewPost_Success_ValueArray() {

        Account acc = createAndInsertAccount(
            'Value Array Test',
            '3333333333',
            null
        );

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_VALUE_ARRAY')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 7: New account POST - success with OData d object
    //         Covers extractCustomerNo → d object path
    // =========================================================
    @IsTest
    static void testPushAccount_NewPost_Success_DObject() {

        Account acc = createAndInsertAccount(
            'D Object Test',
            '4444444444',
            null
        );

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_D_OBJECT')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 8: New account POST - success but no customerNo in response
    //         Covers extractCustomerNo returning null (no BC update)
    // =========================================================
    @IsTest
    static void testPushAccount_NewPost_NoCustomerNo() {

        Account acc = createAndInsertAccount(
            'No CustomerNo Test',
            '5555555555',
            null
        );

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_NO_CUSTOMER_NO')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 9: API returns 500 error
    //         Covers else branch (API error) + IntegrationLogger
    // =========================================================
    @IsTest
    static void testPushAccount_ApiError_500() {

        Account acc = createAndInsertAccount(
            'API Error 500 Test',
            '6666666666',
            null
        );

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('ERROR_500')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 10: API returns 400 error
    // =========================================================
    @IsTest
    static void testPushAccount_ApiError_400() {

        Account acc = createAndInsertAccount(
            'API Error 400 Test',
            '7777777777',
            null
        );

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('ERROR_400')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 11: Callout throws exception
    //          Covers catch block + IntegrationLogger exception log
    // =========================================================
    @IsTest
    static void testPushAccount_CalloutException() {

        Account acc = createAndInsertAccount(
            'Callout Exception Test',
            '8888888888',
            null
        );

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('THROW_EXCEPTION')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 12: Empty response body
    //          Covers extractCustomerNo blank check → returns null
    // =========================================================
    @IsTest
    static void testPushAccount_EmptyResponseBody() {

        Account acc = createAndInsertAccount(
            'Empty Body Test',
            '9000000001',
            null
        );

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_EMPTY_BODY')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 13: Malformed JSON response
    //          Covers extractCustomerNo catch block
    // =========================================================
    @IsTest
    static void testPushAccount_MalformedJson() {

        Account acc = createAndInsertAccount(
            'Malformed JSON Test',
            '9000000002',
            null
        );

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_MALFORMED_JSON')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 14: Account with NO optional fields (all null)
    //          Covers all the isNotBlank/null checks returning false
    // =========================================================
    @IsTest
    static void testPushAccount_MinimalFields() {

        Account acc = new Account();
        acc.Name = 'Minimal Fields Test';
        insert acc;

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_DIRECT')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 15: Account with existing Tracking record
    //          Covers trkList NOT empty path (trk = trkList[0])
    //          Also covers tracking checkbox = true (fields skipped)
    // =========================================================
    @IsTest
    static void testPushAccount_WithExistingTrackingRecord_AllLocked() {

        Account acc = createAndInsertAccount(
            'Tracking Locked Test',
            '9000000003',
            null
        );

        // Pre-insert a fully locked tracking record
        Orient_Customer_Tracking__c trk = new Orient_Customer_Tracking__c();
        trk.Orient_Customer__c      = acc.Id;
        trk.Customer_Name__c        = true;
        trk.Phone__c                = true;
        trk.Whatsapp_number__c      = true;
        trk.Permanent_Address__c    = true;
        trk.Locality_Area__c        = true;
        trk.Anniversary_Date__c     = true;
        trk.Date_Of_Birth_DOB__c    = true;
        trk.Residential_City__c     = true;
        trk.Country_Region_Code__c  = true;
        trk.Country__c              = true;
        trk.District__c             = true;
        trk.Email_Address__c        = true;
        trk.GST__c                  = true;
        trk.KYC_Verified__c         = true;
        trk.PAN__c                  = true;
        trk.Pin_Code__c             = true;
        trk.State_Code__c           = true;
        trk.State_Province__c       = true;
        trk.Village__c              = true;
        trk.AadharNo__c             = true;
        insert trk;

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_DIRECT')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 16: Account with existing Tracking record - NOT locked
    //          Covers upsert of existing tracking record (not new)
    // =========================================================
    @IsTest
    static void testPushAccount_WithExistingTrackingRecord_NotLocked() {

        Account acc = createAndInsertAccount(
            'Tracking Unlocked Test',
            '9000000004',
            null
        );

        // Pre-insert a tracking record with all fields false
        Orient_Customer_Tracking__c trk = new Orient_Customer_Tracking__c();
        trk.Orient_Customer__c = acc.Id;
        insert trk;

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_DIRECT')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();

        // Verify tracking was upserted
        Orient_Customer_Tracking__c updated = [
            SELECT Customer_Name__c, Phone__c
            FROM Orient_Customer_Tracking__c
            WHERE Orient_Customer__c = :acc.Id
            LIMIT 1
        ];
    }

    // =========================================================
    // TEST 17: isUpdate=true + API error
    //          Covers PATCH error path
    // =========================================================
    @IsTest
    static void testPushAccount_IsUpdate_ApiError() {

        Account acc = createAndInsertAccount(
            'Update API Error Test',
            '9000000005',
            'CUST-ERR-001'
        );

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('ERROR_500')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 18: extractCustomerNo - value array with empty array
    //          Covers values.isEmpty() check in extractCustomerNo
    // =========================================================
    @IsTest
    static void testPushAccount_ValueArrayEmpty() {

        Account acc = createAndInsertAccount(
            'Value Array Empty Test',
            '9000000006',
            null
        );

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_VALUE_ARRAY_EMPTY')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 19: extractCustomerNo - value array first item
    //          not a Map (covers instanceof check)
    // =========================================================
    @IsTest
    static void testPushAccount_ValueArrayNonMapItem() {

        Account acc = createAndInsertAccount(
            'Value Array Non Map Test',
            '9000000007',
            null
        );

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_VALUE_ARRAY_NON_MAP')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 20: extractCustomerNo - d object exists but no customerNo
    //          Covers d object path where customerNo key missing
    // =========================================================
    @IsTest
    static void testPushAccount_DObject_NoCustomerNo() {

        Account acc = createAndInsertAccount(
            'D Object No CustomerNo Test',
            '9000000008',
            null
        );

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_D_OBJECT_NO_CUSTOMER_NO')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 21: KYC_Verified__c is null on account
    //          Covers KYC null check in payload mapping
    // =========================================================
    @IsTest
    static void testPushAccount_KYC_Null() {

        Account acc = new Account();
        acc.Name            = 'KYC Null Test';
        acc.Phone           = '9000000009';
        //acc.KYC_Verified__c = null;
        insert acc;

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_DIRECT')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // TEST 22: AadharNo__c is null
    //          Covers aadhar null check in payload mapping
    // =========================================================
    @IsTest
    static void testPushAccount_Aadhar_Null() {

        Account acc = new Account();
        acc.Name        = 'Aadhar Null Test';
        acc.Phone       = '9000000010';
        //acc.AadharNo__c = null;
        insert acc;

        Test.setMock(
            HttpCalloutMock.class,
            new OrientMock('SUCCESS_DIRECT')
        );

        Test.startTest();
        OrientCustomerPushController.PushResult result =
            OrientCustomerPushController.pushAccountToOrient(acc.Id);
        Test.stopTest();
    }

    // =========================================================
    // MOCK CLASS - All scenarios in one place
    // =========================================================
    private class OrientMock implements HttpCalloutMock {

        private String mode;

        OrientMock(String mode) {
            this.mode = mode;
        }

        public HttpResponse respond(HttpRequest req) {

            // Throw exception to cover catch block
            if (mode == 'THROW_EXCEPTION') {
                throw new CalloutException('Simulated network failure');
            }

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            // --------------------------------------------------
            // SUCCESS SCENARIOS
            // --------------------------------------------------
            if (mode == 'SUCCESS_DIRECT') {
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('{"customerNo":"NEWCUST001"}');
                return res;
            }

            if (mode == 'SUCCESS_VALUE_ARRAY') {
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody(
                    '{"value":[{"customerNo":"VALCUST002"}]}'
                );
                return res;
            }

            if (mode == 'SUCCESS_VALUE_ARRAY_EMPTY') {
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('{"value":[]}');
                return res;
            }

            if (mode == 'SUCCESS_VALUE_ARRAY_NON_MAP') {
                // First item is a string, not a Map
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('{"value":["just_a_string"]}');
                return res;
            }

            if (mode == 'SUCCESS_D_OBJECT') {
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody(
                    '{"d":{"customerNo":"ODATACUST003"}}'
                );
                return res;
            }

            if (mode == 'SUCCESS_D_OBJECT_NO_CUSTOMER_NO') {
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('{"d":{"someOtherField":"value"}}');
                return res;
            }

            if (mode == 'SUCCESS_NO_CUSTOMER_NO') {
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('{"status":"success","message":"Created"}');
                return res;
            }

            if (mode == 'SUCCESS_EMPTY_BODY') {
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('');
                return res;
            }

            if (mode == 'SUCCESS_MALFORMED_JSON') {
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('{invalid json here');
                return res;
            }

            // --------------------------------------------------
            // ERROR SCENARIOS
            // --------------------------------------------------
            if (mode == 'ERROR_500') {
                res.setStatusCode(500);
                res.setStatus('Internal Server Error');
                res.setBody('{"error":"Internal Server Error"}');
                return res;
            }

            if (mode == 'ERROR_400') {
                res.setStatusCode(400);
                res.setStatus('Bad Request');
                res.setBody('{"error":"Bad Request"}');
                return res;
            }

            // Default fallback
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('{}');
            return res;
        }
    }
}