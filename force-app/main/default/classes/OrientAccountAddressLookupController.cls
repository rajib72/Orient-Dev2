public with sharing class OrientAccountAddressLookupController {
    public class AccountSeed {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String pinCode;
        @AuraEnabled public String accountName;
    }

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
        @AuraEnabled public List<PostalOption> postalOptions = new List<PostalOption>();
    }

    public class VillageResponse {
        @AuraEnabled public String status;
        @AuraEnabled public String message;
        @AuraEnabled public List<VillageOption> villageOptions = new List<VillageOption>();
    }

    public class UpdateResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id recordId;
    }

    @AuraEnabled(cacheable=true)
    public static AccountSeed getAccountSeed(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Account Id is required.');
        }

        Account acc = [
            SELECT Id, Name, Pin_Code__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        AccountSeed seed = new AccountSeed();
        seed.accountId = acc.Id;
        seed.accountName = acc.Name;
        seed.pinCode = acc.Pin_Code__c;
        return seed;
    }

    @AuraEnabled(cacheable=false)
    public static LookupResponse getPostCodesByPin(String pinCode) {
        if (String.isBlank(pinCode)) {
            throw new AuraHandledException('Pin Code is required.');
        }

        LookupResponse resp = new LookupResponse();

        String filter = 'code eq \'' + pinCode.trim() + '\'';
        String endpoint =
            'callout:Orient_API_Access_NC/' + System.Label.BC_Endpoint + '/PostCodesJRS?$filter=' + EncodingUtil.urlEncode(filter, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endpoint);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            resp.status = 'Error';
            resp.message = 'HTTP Error: ' + res.getStatusCode() + ' - ' + res.getStatus();
            return resp;
        }

        Map<String, Object> root = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
        List<Object> values = (List<Object>)root.get('value');

        if (values != null) {
            for (Object item : values) {
                if (!(item instanceof Map<String, Object>)) continue;
                Map<String, Object> row = (Map<String, Object>)item;

                PostalOption opt = new PostalOption();
                opt.code = str(row.get('code'));
                opt.city = str(row.get('city'));
                opt.stateCode = str(row.get('stateCode'));
                opt.district = str(row.get('district'));
                opt.countryRegionCode = str(row.get('countryRegionCode'));
                opt.county = str(row.get('county'));
                opt.searchCity = str(row.get('searchCity'));
                resp.postalOptions.add(opt);
            }
        }

        resp.status = 'Success';
        resp.message = resp.postalOptions.isEmpty()
            ? 'No postcode records found.'
            : 'Postcode records loaded successfully.';
        return resp;
    }

    @AuraEnabled(cacheable=false)
    public static StateOption getStateByCode(String stateCode) {
        if (String.isBlank(stateCode)) {
            throw new AuraHandledException('State code is required.');
        }

        String filter = 'code eq \'' + stateCode.trim() + '\'';
        String endpoint =
            'callout:Orient_API_Access_NC/' + System.Label.BC_Endpoint + '/StatesJRS?$filter=' + EncodingUtil.urlEncode(filter, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endpoint);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new AuraHandledException('State API Error: ' + res.getStatus());
        }

        Map<String, Object> root = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
        List<Object> values = (List<Object>)root.get('value');

        if (values == null || values.isEmpty()) {
            throw new AuraHandledException('No state found for code: ' + stateCode);
        }

        Map<String, Object> first = (Map<String, Object>)values[0];

        StateOption s = new StateOption();
        s.code = str(first.get('code'));
        s.description = str(first.get('description'));
        s.stateCodeGSTRegNo = str(first.get('stateCodeGSTRegNo'));
        s.stateCodeForETDSTCS = str(first.get('stateCodeForETDSTCS'));
        return s;
    }

    @AuraEnabled(cacheable=false)
    public static VillageResponse getVillagesByPin(String pinCode) {
        if (String.isBlank(pinCode)) {
            throw new AuraHandledException('Pin Code is required.');
        }

        VillageResponse resp = new VillageResponse();

        String filter = 'postCode eq \'' + pinCode.trim() + '\'';
        String endpoint =
            'callout:Orient_API_Access_NC/' + System.Label.BC_Endpoint + '/VillagesJRS?$filter=' + EncodingUtil.urlEncode(filter, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endpoint);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            resp.status = 'Error';
            resp.message = 'HTTP Error: ' + res.getStatusCode() + ' - ' + res.getStatus();
            return resp;
        }

        Map<String, Object> root = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
        List<Object> values = (List<Object>)root.get('value');

        if (values != null) {
            for (Object item : values) {
                if (!(item instanceof Map<String, Object>)) continue;
                Map<String, Object> row = (Map<String, Object>)item;

                VillageOption opt = new VillageOption();
                opt.name = str(row.get('name'));
                opt.postCode = str(row.get('postCode'));
                resp.villageOptions.add(opt);
            }
        }

        resp.status = 'Success';
        resp.message = resp.villageOptions.isEmpty()
            ? 'No villages found for selected postcode.'
            : 'Village records loaded successfully.';
        return resp;
    }

    @AuraEnabled
    public static UpdateResponse updateAccountAddress(
        Id accountId,
        String selectedPinCode,
        String selectedCity,
        String selectedCountryRegionCode,
        String selectedCounty,
        String selectedDistrict,
        String selectedStateCode,
        String selectedStateDescription,
        String selectedLocalityArea,
        String selectedGST,
        String selectedVillage
    ) {
        if (accountId == null) {
            throw new AuraHandledException('Account Id is required.');
        }

        Account acc = new Account(Id = accountId);
        acc.Pin_Code__c = selectedPinCode;
        acc.Residential_City__c = selectedCity;
        acc.Country__c = selectedCounty;
        acc.Country_Region_Code__c = selectedCountryRegionCode;
        acc.District__c = selectedDistrict;
        acc.StateCode__c = selectedStateCode;
        acc.State_Province__c = selectedStateDescription;
        //acc.Locality_Area__c = selectedLocalityArea;
        //acc.GST__c = selectedGST;
        acc.Village__c = selectedVillage;

        update acc;

        UpdateResponse resp = new UpdateResponse();
        resp.success = true;
        resp.message = 'Account address updated successfully.';
        resp.recordId = accountId;
        return resp;
    }

    private static String str(Object obj) {
        return obj == null ? null : String.valueOf(obj);
    }
}