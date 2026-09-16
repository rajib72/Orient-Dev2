public with sharing class Ctrl_OrientCustomerAddressSelection {

    private static final String DEFAULT_COUNTRY_REGION = 'IN';
    private static final String DEFAULT_COUNTRY = 'INDIA';

    public class PostalOption {
        @AuraEnabled public String code;
        @AuraEnabled public String city;
        @AuraEnabled public String stateCode;
        @AuraEnabled public String district;
        @AuraEnabled public String countryRegionCode;
        @AuraEnabled public String county;
        @AuraEnabled public String searchCity;
    }

    public class VillageOption {
        @AuraEnabled public String name;
        @AuraEnabled public String postCode;
    }

    public class StateOption {
        @AuraEnabled public String code;
        @AuraEnabled public String description;
        @AuraEnabled public String stateCodeGSTRegNo;
        @AuraEnabled public String stateCodeForETDSTCS;
    }

    public class LookupResponse {
        @AuraEnabled public String status;
        @AuraEnabled public String message;
        @AuraEnabled public List<PostalOption> postalOptions =
            new List<PostalOption>();
    }

    public class VillageResponse {
        @AuraEnabled public String status;
        @AuraEnabled public String message;
        @AuraEnabled public List<VillageOption> villageOptions =
            new List<VillageOption>();
    }

    public class AddressValidationResult {
        @AuraEnabled public Boolean valid;
        @AuraEnabled public String message;
        @AuraEnabled public Map<String, String> canonicalValues =
            new Map<String, String>();
    }

    @AuraEnabled(cacheable=false)
    public static LookupResponse getPostCodesByPin(
        String pinCode
    ) {
        if (String.isBlank(pinCode)) {
            throw new AuraHandledException(
                'Pin Code is required.'
            );
        }

        LookupResponse response =
            new LookupResponse();

        String filter =
            'code eq \'' +
            escapeODataValue(pinCode.trim()) +
            '\'';

        String endpoint =
            'callout:Orient_API_Access_NC/' +
            System.Label.BC_Endpoint + 
            '/PostCodesJRS?$filter=' +
            EncodingUtil.urlEncode(
                filter,
                'UTF-8'
            );

        HttpRequest request =
            buildGetRequest(endpoint);

        HttpResponse httpResponse =
            new Http().send(request);

        if (
            httpResponse.getStatusCode() < 200 ||
            httpResponse.getStatusCode() >= 300
        ) {
            response.status = 'Error';
            response.message =
                'HTTP Error: ' +
                httpResponse.getStatusCode() +
                ' - ' +
                httpResponse.getStatus();
            return response;
        }

        Map<String, Object> root =
            (Map<String, Object>)
            JSON.deserializeUntyped(
                httpResponse.getBody()
            );

        List<Object> values =
            (List<Object>) root.get('value');

        if (values != null) {
            for (Object item : values) {
                if (
                    !(item instanceof Map<String, Object>)
                ) {
                    continue;
                }

                Map<String, Object> row =
                    (Map<String, Object>) item;

                PostalOption option =
                    new PostalOption();

                option.code =
                    str(row.get('code'));
                option.city =
                    str(row.get('city'));
                option.stateCode =
                    str(row.get('stateCode'));
                option.district =
                    str(row.get('district'));
                option.countryRegionCode =
                    str(row.get('countryRegionCode'));
                option.county =
                    str(row.get('county'));
                option.searchCity =
                    str(row.get('searchCity'));

                response.postalOptions.add(
                    option
                );
            }
        }

        response.status = 'Success';
        response.message =
            response.postalOptions.isEmpty()
                ? 'No postcode records found.'
                : 'Postcode records loaded successfully.';

        return response;
    }

    @AuraEnabled(cacheable=false)
    public static StateOption getStateByCode(
        String stateCode
    ) {
        if (String.isBlank(stateCode)) {
            throw new AuraHandledException(
                'State code is required.'
            );
        }

        String filter =
            'code eq \'' +
            escapeODataValue(stateCode.trim()) +
            '\'';

        String endpoint =
            'callout:Orient_API_Access_NC/' +
            System.Label.BC_Endpoint + 
            '/StatesJRS?$filter=' +
            EncodingUtil.urlEncode(
                filter,
                'UTF-8'
            );

        HttpResponse response =
            new Http().send(
                buildGetRequest(endpoint)
            );

        if (
            response.getStatusCode() < 200 ||
            response.getStatusCode() >= 300
        ) {
            throw new AuraHandledException(
                'State API Error: ' +
                response.getStatus()
            );
        }

        Map<String, Object> root =
            (Map<String, Object>)
            JSON.deserializeUntyped(
                response.getBody()
            );

        List<Object> values =
            (List<Object>) root.get('value');

        if (
            values == null ||
            values.isEmpty()
        ) {
            throw new AuraHandledException(
                'No state found for code: ' +
                stateCode
            );
        }

        Map<String, Object> first =
            (Map<String, Object>) values[0];

        StateOption state =
            new StateOption();

        state.code =
            str(first.get('code'));
        state.description =
            str(first.get('description'));
        state.stateCodeGSTRegNo =
            str(first.get('stateCodeGSTRegNo'));
        state.stateCodeForETDSTCS =
            str(first.get('stateCodeForETDSTCS'));

        return state;
    }

    @AuraEnabled(cacheable=false)
    public static VillageResponse getVillagesByPin(
        String pinCode
    ) {
        if (String.isBlank(pinCode)) {
            throw new AuraHandledException(
                'Pin Code is required.'
            );
        }

        VillageResponse response =
            new VillageResponse();

        String filter =
            'postCode eq \'' +
            escapeODataValue(pinCode.trim()) +
            '\'';

        String endpoint =
            'callout:Orient_API_Access_NC/' +
            System.Label.BC_Endpoint +
            '/VillagesJRS?$filter=' +
            EncodingUtil.urlEncode(
                filter,
                'UTF-8'
            );

        HttpResponse httpResponse =
            new Http().send(
                buildGetRequest(endpoint)
            );

        if (
            httpResponse.getStatusCode() < 200 ||
            httpResponse.getStatusCode() >= 300
        ) {
            response.status = 'Error';
            response.message =
                'HTTP Error: ' +
                httpResponse.getStatusCode() +
                ' - ' +
                httpResponse.getStatus();
            return response;
        }

        Map<String, Object> root =
            (Map<String, Object>)
            JSON.deserializeUntyped(
                httpResponse.getBody()
            );

        List<Object> values =
            (List<Object>) root.get('value');

        if (values != null) {
            for (Object item : values) {
                if (
                    !(item instanceof Map<String, Object>)
                ) {
                    continue;
                }

                Map<String, Object> row =
                    (Map<String, Object>) item;

                VillageOption option =
                    new VillageOption();

                option.name =
                    str(row.get('name'));
                option.postCode =
                    str(row.get('postCode'));

                response.villageOptions.add(
                    option
                );
            }
        }

        response.status = 'Success';
        response.message =
            response.villageOptions.isEmpty()
                ? 'No villages found for selected postcode.'
                : 'Village records loaded successfully.';

        return response;
    }

    /*
     * Security boundary for Address API Only fields.
     *
     * The browser selection is NOT trusted. Before a Customer Change Request
     * is created, the selected address is re-checked against Business Central
     * and a canonical field/value map is returned.
     */
    public static AddressValidationResult validateSelection(
        String selectionJson
    ) {
        if (String.isBlank(selectionJson)) {
            throw new AuraHandledException(
                'Select an address from the Business Central address lookup before submitting.'
            );
        }

        Map<String, Object> selectedValues =
            parseSelection(selectionJson);

        String pinCode =
            selectedText(
                selectedValues,
                'Pin_Code__c'
            );
        String city =
            selectedText(
                selectedValues,
                'Residential_City__c'
            );
        String stateCode =
            selectedText(
                selectedValues,
                'StateCode__c'
            );
        String district =
            selectedText(
                selectedValues,
                'District__c'
            );
        String village =
            selectedText(
                selectedValues,
                'Village__c'
            );

        if (
            String.isBlank(pinCode) ||
            String.isBlank(city) ||
            String.isBlank(stateCode) ||
            String.isBlank(district) ||
            String.isBlank(village)
        ) {
            throw new AuraHandledException(
                'The selected address is incomplete. Pin Code, State, District, City and Village are required.'
            );
        }

        LookupResponse postCodeResponse =
            getPostCodesByPin(pinCode);

        if (
            postCodeResponse == null ||
            postCodeResponse.status != 'Success'
        ) {
            throw new AuraHandledException(
                postCodeResponse == null
                    ? 'Unable to validate the selected Pin Code.'
                    : postCodeResponse.message
            );
        }

        PostalOption matchedPostal;

        for (
            PostalOption postal :
            postCodeResponse.postalOptions
        ) {
            if (
                sameText(postal.code, pinCode) &&
                sameText(postal.city, city) &&
                sameText(postal.stateCode, stateCode) &&
                sameText(postal.district, district)
            ) {
                matchedPostal = postal;
                break;
            }
        }

        if (matchedPostal == null) {
            throw new AuraHandledException(
                'The selected State / District / City combination is no longer valid for Pin Code ' +
                pinCode +
                '. Search the address again.'
            );
        }

        StateOption matchedState =
            getStateByCode(
                matchedPostal.stateCode
            );

        VillageResponse villageResponse =
            getVillagesByPin(
                matchedPostal.code
            );

        if (
            villageResponse == null ||
            villageResponse.status != 'Success'
        ) {
            throw new AuraHandledException(
                villageResponse == null
                    ? 'Unable to validate the selected Village.'
                    : villageResponse.message
            );
        }

        VillageOption matchedVillage;

        for (
            VillageOption villageOption :
            villageResponse.villageOptions
        ) {
            if (
                sameText(
                    villageOption.name,
                    village
                )
            ) {
                matchedVillage =
                    villageOption;
                break;
            }
        }

        if (matchedVillage == null) {
            throw new AuraHandledException(
                'The selected Village is no longer available for Pin Code ' +
                pinCode +
                '. Search the address again.'
            );
        }

        AddressValidationResult result =
            new AddressValidationResult();

        result.valid = true;
        result.message =
            'Address selection validated successfully against Business Central.';

        result.canonicalValues.put(
            'Pin_Code__c',
            matchedPostal.code
        );
        result.canonicalValues.put(
            'Residential_City__c',
            matchedPostal.city
        );
        result.canonicalValues.put(
            'Country__c',
            String.isBlank(matchedPostal.county)
                ? DEFAULT_COUNTRY
                : matchedPostal.county
        );
        result.canonicalValues.put(
            'Country_Region_Code__c',
            String.isBlank(
                matchedPostal.countryRegionCode
            )
                ? DEFAULT_COUNTRY_REGION
                : matchedPostal.countryRegionCode
        );
        result.canonicalValues.put(
            'District__c',
            matchedPostal.district
        );
        result.canonicalValues.put(
            'StateCode__c',
            String.isBlank(matchedState.code)
                ? matchedPostal.stateCode
                : matchedState.code
        );
        result.canonicalValues.put(
            'State_Province__c',
            matchedState.description
        );
        result.canonicalValues.put(
            'Village__c',
            matchedVillage.name
        );

        validateBrowserSelectionAgainstCanonical(
            selectedValues,
            result.canonicalValues
        );

        return result;
    }

    private static void validateBrowserSelectionAgainstCanonical(
        Map<String, Object> selectedValues,
        Map<String, String> canonicalValues
    ) {
        for (
            String fieldApi :
            canonicalValues.keySet()
        ) {
            if (
                !selectedValues.containsKey(
                    fieldApi
                )
            ) {
                continue;
            }

            String browserValue =
                str(
                    selectedValues.get(
                        fieldApi
                    )
                );

            String canonicalValue =
                canonicalValues.get(
                    fieldApi
                );

            if (
                !sameText(
                    browserValue,
                    canonicalValue
                )
            ) {
                throw new AuraHandledException(
                    'The selected address changed while it was being validated. Search and select the address again.'
                );
            }
        }
    }

    private static Map<String, Object> parseSelection(
        String selectionJson
    ) {
        try {
            Object parsed =
                JSON.deserializeUntyped(
                    selectionJson
                );

            if (
                !(parsed instanceof Map<String, Object>)
            ) {
                throw new AuraHandledException(
                    'Invalid address selection payload.'
                );
            }

            return (Map<String, Object>) parsed;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Invalid address selection payload.'
            );
        }
    }

    private static String selectedText(
        Map<String, Object> values,
        String fieldApi
    ) {
        return values.containsKey(fieldApi)
            ? str(values.get(fieldApi))
            : null;
    }

    private static HttpRequest buildGetRequest(
        String endpoint
    ) {
        HttpRequest request =
            new HttpRequest();

        request.setMethod('GET');
        request.setEndpoint(endpoint);
        request.setHeader(
            'Accept',
            'application/json'
        );
        request.setTimeout(20000);

        return request;
    }

    private static Boolean sameText(
        String leftValue,
        String rightValue
    ) {
        String leftNormalized =
            normalizeText(leftValue);
        String rightNormalized =
            normalizeText(rightValue);

        return leftNormalized ==
            rightNormalized;
    }

    private static String normalizeText(
        String value
    ) {
        return String.isBlank(value)
            ? ''
            : value.trim().toLowerCase();
    }

    private static String escapeODataValue(
        String value
    ) {
        return value == null
            ? ''
            : value.replace(
                '\'',
                '\'\''
            );
    }

    private static String str(
        Object value
    ) {
        return value == null
            ? null
            : String.valueOf(value);
    }
}