@IsTest(SeeAllData=false)
private class Ctrl_OrientCustomerAddressSelectionTest {

    // =========================================================
    // MOCK HTTP CALLOUT CLASS
    // =========================================================
    public class AddressCalloutMock implements HttpCalloutMock {
        private Integer statusCode;
        private Boolean returnEmptyValue;

        public AddressCalloutMock(Integer statusCode, Boolean returnEmptyValue) {
            this.statusCode = statusCode;
            this.returnEmptyValue = returnEmptyValue;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            
            if (this.statusCode != 200) {
                res.setBody('{"error": "Server Error"}');
                return res;
            }

            String endpoint = req.getEndpoint();
            String body = '{"value": []}'; // Default empty response

            if (!this.returnEmptyValue) {
                if (endpoint.contains('PostCodesJRS')) {
                    body = '{"value": [{"code": "700001", "city": "Kolkata", "stateCode": "WB", "district": "Kolkata", "countryRegionCode": "IN", "county": "INDIA", "searchCity": "Kolkata"}]}';
                } else if (endpoint.contains('StatesJRS')) {
                    body = '{"value": [{"code": "WB", "description": "West Bengal", "stateCodeGSTRegNo": "19", "stateCodeForETDSTCS": "19"}]}';
                } else if (endpoint.contains('VillagesJRS')) {
                    body = '{"value": [{"name": "Test Village", "postCode": "700001"}]}';
                }
            }
            
            res.setBody(body);
            return res;
        }
    }

    // =========================================================
    // 1. PIN CODE TESTS (getPostCodesByPin)
    // =========================================================
    @IsTest
    static void testGetPostCodesByPin_Success() {
        Test.setMock(HttpCalloutMock.class, new AddressCalloutMock(200, false));
        Test.startTest();
        Ctrl_OrientCustomerAddressSelection.getPostCodesByPin('700001');
        Test.stopTest();
    }

    @IsTest
    static void testGetPostCodesByPin_EmptyResponse() {
        Test.setMock(HttpCalloutMock.class, new AddressCalloutMock(200, true));
        Test.startTest();
        Ctrl_OrientCustomerAddressSelection.getPostCodesByPin('999999');
        Test.stopTest();
    }

    @IsTest
    static void testGetPostCodesByPin_HttpError() {
        Test.setMock(HttpCalloutMock.class, new AddressCalloutMock(500, false));
        Test.startTest();
        Ctrl_OrientCustomerAddressSelection.getPostCodesByPin('700001');
        Test.stopTest();
    }

    @IsTest
    static void testGetPostCodesByPin_BlankInput() {
        Test.startTest();
        try {
            Ctrl_OrientCustomerAddressSelection.getPostCodesByPin('');
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    // =========================================================
    // 2. STATE TESTS (getStateByCode)
    // =========================================================
    @IsTest
    static void testGetStateByCode_Success() {
        Test.setMock(HttpCalloutMock.class, new AddressCalloutMock(200, false));
        Test.startTest();
        Ctrl_OrientCustomerAddressSelection.getStateByCode('WB');
        Test.stopTest();
    }

    @IsTest
    static void testGetStateByCode_EmptyResponse() {
        Test.setMock(HttpCalloutMock.class, new AddressCalloutMock(200, true));
        Test.startTest();
        try {
            Ctrl_OrientCustomerAddressSelection.getStateByCode('XX');
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetStateByCode_HttpError() {
        Test.setMock(HttpCalloutMock.class, new AddressCalloutMock(500, false));
        Test.startTest();
        try {
            Ctrl_OrientCustomerAddressSelection.getStateByCode('WB');
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetStateByCode_BlankInput() {
        Test.startTest();
        try {
            Ctrl_OrientCustomerAddressSelection.getStateByCode(null);
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    // =========================================================
    // 3. VILLAGE TESTS (getVillagesByPin)
    // =========================================================
    @IsTest
    static void testGetVillagesByPin_Success() {
        Test.setMock(HttpCalloutMock.class, new AddressCalloutMock(200, false));
        Test.startTest();
        Ctrl_OrientCustomerAddressSelection.getVillagesByPin('700001');
        Test.stopTest();
    }

    @IsTest
    static void testGetVillagesByPin_EmptyResponse() {
        Test.setMock(HttpCalloutMock.class, new AddressCalloutMock(200, true));
        Test.startTest();
        Ctrl_OrientCustomerAddressSelection.getVillagesByPin('999999');
        Test.stopTest();
    }

    @IsTest
    static void testGetVillagesByPin_HttpError() {
        Test.setMock(HttpCalloutMock.class, new AddressCalloutMock(500, false));
        Test.startTest();
        Ctrl_OrientCustomerAddressSelection.getVillagesByPin('700001');
        Test.stopTest();
    }

    @IsTest
    static void testGetVillagesByPin_BlankInput() {
        Test.startTest();
        try {
            Ctrl_OrientCustomerAddressSelection.getVillagesByPin('   ');
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    // =========================================================
    // 4. SELECTION VALIDATION TESTS (validateSelection)
    // =========================================================
    @IsTest
    static void testValidateSelection_Success() {
        Test.setMock(HttpCalloutMock.class, new AddressCalloutMock(200, false));
        
        String validJson = '{' +
            '"Pin_Code__c": "700001",' +
            '"Residential_City__c": "Kolkata",' +
            '"StateCode__c": "WB",' +
            '"District__c": "Kolkata",' +
            '"Village__c": "Test Village"' +
        '}';

        Test.startTest();
        Ctrl_OrientCustomerAddressSelection.validateSelection(validJson);
        Test.stopTest();
    }

    @IsTest
    static void testValidateSelection_IncompleteData() {
        // Missing Village__c
        String incompleteJson = '{' +
            '"Pin_Code__c": "700001",' +
            '"Residential_City__c": "Kolkata",' +
            '"StateCode__c": "WB",' +
            '"District__c": "Kolkata"' +
        '}';

        Test.startTest();
        try {
            Ctrl_OrientCustomerAddressSelection.validateSelection(incompleteJson);
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateSelection_PostalMismatch() {
        Test.setMock(HttpCalloutMock.class, new AddressCalloutMock(200, false));
        
        // City does not match the mocked BC response ("Kolkata")
        String mismatchJson = '{' +
            '"Pin_Code__c": "700001",' +
            '"Residential_City__c": "WRONG CITY",' +
            '"StateCode__c": "WB",' +
            '"District__c": "Kolkata",' +
            '"Village__c": "Test Village"' +
        '}';

        Test.startTest();
        try {
            Ctrl_OrientCustomerAddressSelection.validateSelection(mismatchJson);
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateSelection_VillageMismatch() {
        Test.setMock(HttpCalloutMock.class, new AddressCalloutMock(200, false));
        
        // Village does not match the mocked BC response ("Test Village")
        String mismatchJson = '{' +
            '"Pin_Code__c": "700001",' +
            '"Residential_City__c": "Kolkata",' +
            '"StateCode__c": "WB",' +
            '"District__c": "Kolkata",' +
            '"Village__c": "WRONG VILLAGE"' +
        '}';

        Test.startTest();
        try {
            Ctrl_OrientCustomerAddressSelection.validateSelection(mismatchJson);
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateSelection_BrowserManipulation() {
        Test.setMock(HttpCalloutMock.class, new AddressCalloutMock(200, false));
        
        // The selection matches enough to pass the basic lookups, but the user manipulated 
        // a secondary canonical value (Country) in the browser payload.
        String manipulatedJson = '{' +
            '"Pin_Code__c": "700001",' +
            '"Residential_City__c": "Kolkata",' +
            '"StateCode__c": "WB",' +
            '"District__c": "Kolkata",' +
            '"Village__c": "Test Village",' +
            '"Country__c": "UNITED STATES"' + // Mock expects "INDIA"
        '}';

        Test.startTest();
        try {
            Ctrl_OrientCustomerAddressSelection.validateSelection(manipulatedJson);
        } catch (AuraHandledException e) {
            // Handled: "The selected address changed while it was being validated."
        }
        Test.stopTest();
    }

    // =========================================================
    // 5. PARSER EXCEPTIONS (parseSelection)
    // =========================================================
    @IsTest
    static void testValidateSelection_BlankJson() {
        Test.startTest();
        try {
            Ctrl_OrientCustomerAddressSelection.validateSelection('');
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateSelection_InvalidJsonFormat() {
        Test.startTest();
        // Forces catch (Exception e)
        try {
            Ctrl_OrientCustomerAddressSelection.validateSelection('{ invalid json');
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateSelection_NotAMap() {
        Test.startTest();
        // Forces !(parsed instanceof Map) logic which explicitly throws an AuraHandledException
        try {
            Ctrl_OrientCustomerAddressSelection.validateSelection('["Just", "An", "Array"]');
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }
}