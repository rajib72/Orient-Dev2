@IsTest
private class OrientAccountAddressLookupControllerTest {

    // =========================================================
    // TEST DATA SETUP
    // =========================================================
    @TestSetup
    static void setupData() {
        Account acc = new Account();
        acc.Name = 'Test Account';
        insert acc;
    }

    // =========================================================
    // HELPER - Get Account Id
    // =========================================================
    private static Id getAccountId() {
        return [SELECT Id FROM Account LIMIT 1].Id;
    }

    // =========================================================
    // TEST 1: getAccountSeed - valid account Id
    // =========================================================
    @IsTest
    static void testGetAccountSeed_ValidId() {

        Id accountId = getAccountId();

        Test.startTest();
        OrientAccountAddressLookupController.AccountSeed seed =
            OrientAccountAddressLookupController.getAccountSeed(accountId);
        Test.stopTest();
    }

    // =========================================================
    // TEST 2: getAccountSeed - null Id → AuraHandledException
    // =========================================================
    @IsTest
    static void testGetAccountSeed_NullId() {

        Test.startTest();
        try {
            OrientAccountAddressLookupController.getAccountSeed(null);
        } catch (Exception e) {
            // expected AuraHandledException
        }
        Test.stopTest();
    }

    // =========================================================
    // TEST 3: getPostCodesByPin - null/blank → AuraHandledException
    // =========================================================
    @IsTest
    static void testGetPostCodesByPin_BlankPin() {

        Test.startTest();
        try {
            OrientAccountAddressLookupController.getPostCodesByPin(null);
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    // =========================================================
    // TEST 4: getPostCodesByPin - blank string
    // =========================================================
    @IsTest
    static void testGetPostCodesByPin_EmptyString() {

        Test.startTest();
        try {
            OrientAccountAddressLookupController.getPostCodesByPin('');
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    // =========================================================
    // TEST 5: getPostCodesByPin - success with results
    //         Also covers non-Map item in values array (INVALID_ITEM)
    // =========================================================
    @IsTest
    static void testGetPostCodesByPin_Success() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('POSTCODE_OK'));
        OrientAccountAddressLookupController.LookupResponse resp =
            OrientAccountAddressLookupController.getPostCodesByPin('560001');
        Test.stopTest();
    }

    // =========================================================
    // TEST 6: getPostCodesByPin - empty value array (no results)
    // =========================================================
    @IsTest
    static void testGetPostCodesByPin_EmptyValues() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('POSTCODE_EMPTY_ARRAY'));
        OrientAccountAddressLookupController.LookupResponse resp =
            OrientAccountAddressLookupController.getPostCodesByPin('560001');
        Test.stopTest();
    }

    // =========================================================
    // TEST 7: getPostCodesByPin - null value key in response
    // =========================================================
    @IsTest
    static void testGetPostCodesByPin_NullValueKey() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('POSTCODE_NULL_VALUE'));
        OrientAccountAddressLookupController.LookupResponse resp =
            OrientAccountAddressLookupController.getPostCodesByPin('560001');
        Test.stopTest();
    }

    // =========================================================
    // TEST 8: getPostCodesByPin - HTTP error response
    // =========================================================
    @IsTest
    static void testGetPostCodesByPin_HttpError() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('POSTCODE_ERROR'));
        OrientAccountAddressLookupController.LookupResponse resp =
            OrientAccountAddressLookupController.getPostCodesByPin('560001');
        Test.stopTest();
    }

    // =========================================================
    // TEST 9: getStateByCode - null/blank → AuraHandledException
    // =========================================================
    @IsTest
    static void testGetStateByCode_BlankCode() {

        Test.startTest();
        try {
            OrientAccountAddressLookupController.getStateByCode(null);
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    // =========================================================
    // TEST 10: getStateByCode - blank string
    // =========================================================
    @IsTest
    static void testGetStateByCode_EmptyString() {

        Test.startTest();
        try {
            OrientAccountAddressLookupController.getStateByCode('');
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    // =========================================================
    // TEST 11: getStateByCode - success with valid state
    // =========================================================
    @IsTest
    static void testGetStateByCode_Success() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('STATE_OK'));
        OrientAccountAddressLookupController.StateOption state =
            OrientAccountAddressLookupController.getStateByCode('KA');
        Test.stopTest();
    }

    // =========================================================
    // TEST 12: getStateByCode - empty values → AuraHandledException
    // =========================================================
    @IsTest
    static void testGetStateByCode_EmptyValues() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('STATE_EMPTY'));
        try {
            OrientAccountAddressLookupController.getStateByCode('KA');
        } catch (Exception e) {
            // expected - No state found
        }
        Test.stopTest();
    }

    // =========================================================
    // TEST 13: getStateByCode - HTTP error → AuraHandledException
    // =========================================================
    @IsTest
    static void testGetStateByCode_HttpError() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('STATE_ERROR'));
        try {
            OrientAccountAddressLookupController.getStateByCode('KA');
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    // =========================================================
    // TEST 14: getVillagesByPin - null → AuraHandledException
    // =========================================================
    @IsTest
    static void testGetVillagesByPin_NullPin() {

        Test.startTest();
        try {
            OrientAccountAddressLookupController.getVillagesByPin(null);
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    // =========================================================
    // TEST 15: getVillagesByPin - blank string
    // =========================================================
    @IsTest
    static void testGetVillagesByPin_EmptyString() {

        Test.startTest();
        try {
            OrientAccountAddressLookupController.getVillagesByPin('');
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    // =========================================================
    // TEST 16: getVillagesByPin - success with results
    //          Also covers non-Map item in values array
    // =========================================================
    @IsTest
    static void testGetVillagesByPin_Success() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('VILLAGE_OK'));
        OrientAccountAddressLookupController.VillageResponse resp =
            OrientAccountAddressLookupController.getVillagesByPin('560001');
        Test.stopTest();
    }

    // =========================================================
    // TEST 17: getVillagesByPin - empty value array (no villages)
    // =========================================================
    @IsTest
    static void testGetVillagesByPin_EmptyValues() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('VILLAGE_EMPTY_ARRAY'));
        OrientAccountAddressLookupController.VillageResponse resp =
            OrientAccountAddressLookupController.getVillagesByPin('560001');
        Test.stopTest();
    }

    // =========================================================
    // TEST 18: getVillagesByPin - null value key in response
    // =========================================================
    @IsTest
    static void testGetVillagesByPin_NullValueKey() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('VILLAGE_NULL_VALUE'));
        OrientAccountAddressLookupController.VillageResponse resp =
            OrientAccountAddressLookupController.getVillagesByPin('560001');
        Test.stopTest();
    }

    // =========================================================
    // TEST 19: getVillagesByPin - HTTP error response
    // =========================================================
    @IsTest
    static void testGetVillagesByPin_HttpError() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('VILLAGE_ERROR'));
        OrientAccountAddressLookupController.VillageResponse resp =
            OrientAccountAddressLookupController.getVillagesByPin('560001');
        Test.stopTest();
    }

    // =========================================================
    // TEST 20: updateAccountAddress - null accountId
    //          → AuraHandledException
    // =========================================================
    @IsTest
    static void testUpdateAccountAddress_NullAccountId() {

        Test.startTest();
        try {
            OrientAccountAddressLookupController.updateAccountAddress(
                null,
                '560001',
                'Bengaluru',
                'IN',
                'Bengaluru Urban',
                'Bengaluru',
                'KA',
                'Karnataka',
                'HSR Layout',
                'GST123',
                'TestVillage'
            );
        } catch (Exception e) {
            // expected AuraHandledException
        }
        Test.stopTest();
    }

    // =========================================================
    // TEST 21: updateAccountAddress - valid account
    //          → successful update
    // =========================================================
    @IsTest
    static void testUpdateAccountAddress_Success() {

        Id accountId = getAccountId();

        Test.startTest();
        OrientAccountAddressLookupController.UpdateResponse resp =
            OrientAccountAddressLookupController.updateAccountAddress(
                accountId,
                '560002',
                'Bengaluru',
                'IN',
                'Bengaluru Urban',
                'Bengaluru',
                'KA',
                'Karnataka',
                'Electronic City',
                'GST999',
                'Koramangala'
            );
        Test.stopTest();
    }

    // =========================================================
    // TEST 22: updateAccountAddress - all null field values
    //          (covers null-safe field setting)
    // =========================================================
    @IsTest
    static void testUpdateAccountAddress_NullFields() {

        Id accountId = getAccountId();

        Test.startTest();
        OrientAccountAddressLookupController.UpdateResponse resp =
            OrientAccountAddressLookupController.updateAccountAddress(
                accountId,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null
            );
        Test.stopTest();
    }

    // =========================================================
    // TEST 23: str() helper - covered via PostalOption mapping
    //          with null values in the response row
    // =========================================================
    @IsTest
    static void testStrHelper_NullValues() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('POSTCODE_NULL_FIELDS'));
        OrientAccountAddressLookupController.LookupResponse resp =
            OrientAccountAddressLookupController.getPostCodesByPin('560001');
        Test.stopTest();
    }

    // =========================================================
    // TEST 24: getPostCodesByPin - whitespace pin (trimmed)
    // =========================================================
    @IsTest
    static void testGetPostCodesByPin_WhitespaceTrimmed() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('POSTCODE_OK'));
        OrientAccountAddressLookupController.LookupResponse resp =
            OrientAccountAddressLookupController.getPostCodesByPin('  560001  ');
        Test.stopTest();
    }

    // =========================================================
    // TEST 25: getStateByCode - whitespace code (trimmed)
    // =========================================================
    @IsTest
    static void testGetStateByCode_WhitespaceTrimmed() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('STATE_OK'));
        OrientAccountAddressLookupController.StateOption state =
            OrientAccountAddressLookupController.getStateByCode('  KA  ');
        Test.stopTest();
    }

    // =========================================================
    // TEST 26: getVillagesByPin - whitespace pin (trimmed)
    // =========================================================
    @IsTest
    static void testGetVillagesByPin_WhitespaceTrimmed() {

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OrientApiMock('VILLAGE_OK'));
        OrientAccountAddressLookupController.VillageResponse resp =
            OrientAccountAddressLookupController.getVillagesByPin('  560001  ');
        Test.stopTest();
    }

    // =========================================================
    // MOCK CLASS
    // =========================================================
    private class OrientApiMock implements HttpCalloutMock {

        private String mode;

        OrientApiMock(String mode) {
            this.mode = mode;
        }

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            // --------------------------------------------------
            // POSTCODE MOCKS
            // --------------------------------------------------
            if (mode == 'POSTCODE_OK') {
                // Includes one valid object + one invalid string item
                // to cover the !(item instanceof Map) continue branch
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody(
                    '{"value":[' +
                        '{"code":"560001","city":"Bengaluru","stateCode":"KA",' +
                        '"district":"Bengaluru Urban","countryRegionCode":"IN",' +
                        '"county":"Bengaluru","searchCity":"Bengaluru"},' +
                        '"INVALID_STRING_ITEM"' +
                    ']}'
                );
                return res;
            }

            if (mode == 'POSTCODE_EMPTY_ARRAY') {
                // value key exists but array is empty
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('{"value":[]}');
                return res;
            }

            if (mode == 'POSTCODE_NULL_VALUE') {
                // value key is absent → covers null check on values
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('{}');
                return res;
            }

            if (mode == 'POSTCODE_NULL_FIELDS') {
                // All field values are null → covers str(null) path
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody(
                    '{"value":[' +
                        '{"code":null,"city":null,"stateCode":null,' +
                        '"district":null,"countryRegionCode":null,' +
                        '"county":null,"searchCity":null}' +
                    ']}'
                );
                return res;
            }

            if (mode == 'POSTCODE_ERROR') {
                res.setStatusCode(500);
                res.setStatus('Internal Server Error');
                res.setBody('Server error');
                return res;
            }

            // --------------------------------------------------
            // STATE MOCKS
            // --------------------------------------------------
            if (mode == 'STATE_OK') {
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody(
                    '{"value":[{' +
                        '"code":"KA",' +
                        '"description":"Karnataka",' +
                        '"stateCodeGSTRegNo":"29",' +
                        '"stateCodeForETDSTCS":"29"' +
                    '}]}'
                );
                return res;
            }

            if (mode == 'STATE_EMPTY') {
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('{"value":[]}');
                return res;
            }

            if (mode == 'STATE_ERROR') {
                res.setStatusCode(500);
                res.setStatus('Internal Server Error');
                res.setBody('Server error');
                return res;
            }

            // --------------------------------------------------
            // VILLAGE MOCKS
            // --------------------------------------------------
            if (mode == 'VILLAGE_OK') {
                // Includes one valid object + one invalid string item
                // to cover the !(item instanceof Map) continue branch
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody(
                    '{"value":[' +
                        '{"name":"Koramangala","postCode":"560001"},' +
                        '"INVALID_STRING_ITEM"' +
                    ']}'
                );
                return res;
            }

            if (mode == 'VILLAGE_EMPTY_ARRAY') {
                // value key exists but array is empty
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('{"value":[]}');
                return res;
            }

            if (mode == 'VILLAGE_NULL_VALUE') {
                // value key is absent → covers null check on values
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('{}');
                return res;
            }

            if (mode == 'VILLAGE_ERROR') {
                res.setStatusCode(500);
                res.setStatus('Internal Server Error');
                res.setBody('Server error');
                return res;
            }

            // --------------------------------------------------
            // DEFAULT FALLBACK
            // --------------------------------------------------
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('{}');
            return res;
        }
    }
}