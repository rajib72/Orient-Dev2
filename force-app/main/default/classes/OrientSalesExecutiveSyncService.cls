public with sharing class OrientSalesExecutiveSyncService {

    public class SyncResult {
        @AuraEnabled public Integer totalReceived;
        @AuraEnabled public Integer totalUpserted;
        @AuraEnabled public Integer totalFailed;
        @AuraEnabled public String message;
    }

    // Sanitize the label to remove backslashes and encode single quotes
    private static final String ENDPOINT_PATH = 
        ('callout:Orient_API_Access_NC/' + System.Label.BC_Endpoint + '/SalesPersonsAPIJRS');

    @AuraEnabled
    public static SyncResult syncSalesExecutives() {
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(ENDPOINT_PATH);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new AuraHandledException(
                'Business Central callout failed. Status: ' +
                res.getStatus() +
                ' Body: ' +
                res.getBody()
            );
        }

        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> values = (List<Object>) root.get('value');

        // --- NEW LOGIC: Gather Location Codes & Query Stores ---
        Set<String> locationCodes = new Set<String>();
        if (values != null) {
            for (Object obj : values) {
                Map<String, Object> row = (Map<String, Object>) obj;
                String locCode = stringValue(row.get('locationCode'));
                if (String.isNotBlank(locCode)) {
                    locationCodes.add(locCode);
                }
            }
        }

        // Map to quickly fetch Store Id by Store Code
        Map<String, Id> storeCodeToIdMap = new Map<String, Id>();
        if (!locationCodes.isEmpty()) {
            for (Store__c store : [SELECT Id, Store_Code__c FROM Store__c WHERE Store_Code__c IN :locationCodes]) {
                storeCodeToIdMap.put(store.Store_Code__c, store.Id);
            }
        }
        // -------------------------------------------------------

        List<Sales_Executives__c> records = new List<Sales_Executives__c>();

        if (values != null) {
            for (Object obj : values) {
                Map<String, Object> row = (Map<String, Object>) obj;
                
                // Pass the Store Map to the buildRecord method
                Sales_Executives__c rec = buildRecord(row, storeCodeToIdMap);

                if (String.isNotBlank(rec.code__c)) {
                    records.add(rec);
                }
            }
        }

        SyncResult out = new SyncResult();
        out.totalReceived = values == null ? 0 : values.size();

        if (records.isEmpty()) {
            out.totalUpserted = 0;
            out.totalFailed = 0;
            out.message = 'No valid records found to upsert.';
            return out;
        }

        Database.UpsertResult[] results = Database.upsert(records, Sales_Executives__c.Fields.code__c, false);

        Integer successCount = 0;
        Integer failCount = 0;
        List<String> errors = new List<String>();

        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                successCount++;
            } else {
                failCount++;
                for (Database.Error err : results[i].getErrors()) {
                    errors.add('Row ' + (i + 1) + ': ' + err.getMessage());
                }
            }
        }

        out.totalUpserted = successCount;
        out.totalFailed = failCount;
        out.message =
            'Sync complete. Received: ' + out.totalReceived +
            ', Upserted: ' + successCount +
            ', Failed: ' + failCount +
            (errors.isEmpty() ? '' : ' | ' + String.join(errors, ' ; '));

        return out;
    }

    private static Sales_Executives__c buildRecord(Map<String, Object> row, Map<String, Id> storeCodeToIdMap) {
        Sales_Executives__c rec = new Sales_Executives__c();

        Map<String, Schema.SObjectField> fieldMap =
            Sales_Executives__c.SObjectType.getDescribe().fields.getMap();

        String codeVal = stringValue(row.get('code'));
        String nameVal = stringValue(row.get('name'));
        String locCode = stringValue(row.get('locationCode'));

        // Required / important mappings
        putText(rec, fieldMap, 'code__c', codeVal);
        putText(rec, fieldMap, 'Sales_Executive_Code__c', codeVal);
        putText(rec, fieldMap, 'Name', nameVal);
        putText(rec, fieldMap, 'name__c', nameVal);
        
        // --- NEW LOGIC: Map the Lookup Field ---
        putText(rec, fieldMap, 'locationCode__c', locCode);
        if (String.isNotBlank(locCode) && storeCodeToIdMap.containsKey(locCode)) {
            // If the store code exists in our Map, link the Sales Executive to the Store
            rec.put('Store__c', storeCodeToIdMap.get(locCode));
        }
        // ---------------------------------------

        // Remaining fields from Business Central
        putText(rec, fieldMap, 'eMail__c', row.get('eMail'));
        putText(rec, fieldMap, 'eMail2__c', row.get('eMail2'));
        putDecimal(rec, fieldMap, 'avgEstimatedValueLCY__c', row.get('avgEstimatedValueLCY'));
        putDecimal(rec, fieldMap, 'avgCalcdCurrentValueLCY__c', row.get('avgCalcdCurrentValueLCY'));
        putBoolean(rec, fieldMap, 'blocked__c', row.get('blocked'));
        putDecimal(rec, fieldMap, 'calcdCurrentValueLCY__c', row.get('calcdCurrentValueLCY'));
        putDecimal(rec, fieldMap, 'commission__c', row.get('commission'));
        putDecimal(rec, fieldMap, 'costLCY__c', row.get('costLCY'));
        putBoolean(rec, fieldMap, 'coupledToDataverse__c', row.get('coupledToDataverse'));
        putInteger(rec, fieldMap, 'durationMin__c', row.get('durationMin'));
        putDecimal(rec, fieldMap, 'estimatedValueLCY__c', row.get('estimatedValueLCY'));
        putText(rec, fieldMap, 'globalDimension1Code__c', row.get('globalDimension1Code'));
        putText(rec, fieldMap, 'globalDimension2Code__c', row.get('globalDimension2Code'));
        putText(rec, fieldMap, 'jobTitle__c', row.get('jobTitle'));
        putDate(rec, fieldMap, 'nextTaskDate__c', row.get('nextTaskDate'));
        putInteger(rec, fieldMap, 'noOfInteractions__c', row.get('noOfInteractions'));
        putInteger(rec, fieldMap, 'noOfOpportunities__c', row.get('noOfOpportunities'));
        putBoolean(rec, fieldMap, 'opportunityEntryExists__c', row.get('opportunityEntryExists'));
        putText(rec, fieldMap, 'phoneNo__c', row.get('phoneNo'));
        putBoolean(rec, fieldMap, 'privacyBlocked__c', row.get('privacyBlocked'));
        putText(rec, fieldMap, 'searchEMail__c', row.get('searchEMail'));
        putBoolean(rec, fieldMap, 'taskEntryExists__c', row.get('taskEntryExists'));

        return rec;
    }

    private static void putText(SObject rec, Map<String, Schema.SObjectField> fieldMap, String fieldApi, Object rawVal) {
        if (!fieldMap.containsKey(fieldApi) || rawVal == null) return;
        String val = String.valueOf(rawVal);
        rec.put(fieldApi, val);
    }

    private static void putBoolean(SObject rec, Map<String, Schema.SObjectField> fieldMap, String fieldApi, Object rawVal) {
        if (!fieldMap.containsKey(fieldApi) || rawVal == null) return;

        if (rawVal instanceof Boolean) {
            rec.put(fieldApi, rawVal);
        } else {
            rec.put(fieldApi, Boolean.valueOf(String.valueOf(rawVal)));
        }
    }

    private static void putInteger(SObject rec, Map<String, Schema.SObjectField> fieldMap, String fieldApi, Object rawVal) {
        if (!fieldMap.containsKey(fieldApi) || rawVal == null) return;

        String val = String.valueOf(rawVal).trim();
        if (String.isBlank(val)) return;

        rec.put(fieldApi, Integer.valueOf(val));
    }

    private static void putDecimal(SObject rec, Map<String, Schema.SObjectField> fieldMap, String fieldApi, Object rawVal) {
        if (!fieldMap.containsKey(fieldApi) || rawVal == null) return;

        String val = String.valueOf(rawVal).trim();
        if (String.isBlank(val)) return;

        rec.put(fieldApi, Decimal.valueOf(val));
    }

    private static void putDate(SObject rec, Map<String, Schema.SObjectField> fieldMap, String fieldApi, Object rawVal) {
        if (!fieldMap.containsKey(fieldApi) || rawVal == null) return;

        String val = String.valueOf(rawVal).trim();
        if (String.isBlank(val)) return;

        // Business Central sends 0001-01-01 for empty dates
        if (val.startsWith('0001-01-01')) return;

        rec.put(fieldApi, Date.valueOf(val.substring(0, 10)));
    }

    private static String stringValue(Object rawVal) {
        return rawVal == null ? null : String.valueOf(rawVal).trim();
    }
}