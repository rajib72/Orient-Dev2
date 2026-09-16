public with sharing class OrientCustomerPushController {

    private static final String CLASS_NAME = 'OrientCustomerPushController';
    private static final String METHOD_NAME = 'pushAccountToOrient';
    private static final String API_TYPE = 'BC_Customer_Push';

    public class PushResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Boolean alreadySent;
        @AuraEnabled public Integer statusCode;
        @AuraEnabled public String message;
        @AuraEnabled public String requestBody;
        @AuraEnabled public String responseBody;
        @AuraEnabled public String recordId;
        @AuraEnabled public String customerNo;
    }

    @AuraEnabled
    public static PushResult pushAccountToOrient(Id recordId) {

        PushResult result = new PushResult();

        Id accountId;
        String endpoint;
        String httpMethod;
        String finalJson;
        String requestHeaders;

        Datetime requestDateTime;
        Datetime responseDateTime;
        Long calloutStartMs;
        Long durationMs;

        try {

            // =====================================================
            // VALIDATE RECORD ID
            // =====================================================
            if (recordId == null) {

                result.success = false;
                result.statusCode = 400;
                result.message = 'Record Id is required.';

                Datetime logTime = System.now();

                insertIntegrationLog(
                    null,
                    null,
                    null,
                    null,
                    null,
                    null,
                    400,
                    'Validation Failed',
                    false,
                    'Validation Failed',
                    result.message,
                    null,
                    null,
                    logTime,
                    logTime,
                    0
                );

                return result;
            }

            // =====================================================
            // DETERMINE SOURCE OBJECT
            // =====================================================
            String sourceObject =
                recordId
                    .getSObjectType()
                    .getDescribe()
                    .getName();

            accountId = recordId;

            // Push can also be invoked from Customer_Order__c.
            if (sourceObject == 'Customer_Order__c') {

                Customer_Order__c orderRecord = [
                    SELECT Id, Customer__c
                    FROM Customer_Order__c
                    WHERE Id = :recordId
                    WITH USER_MODE
                    LIMIT 1
                ];

                if (orderRecord.Customer__c == null) {

                    result.success = false;
                    result.statusCode = 400;
                    result.message =
                        'No associated Customer found on this order.';

                    Datetime logTime = System.now();

                    insertIntegrationLog(
                        null,
                        null,
                        null,
                        null,
                        null,
                        null,
                        400,
                        'Validation Failed',
                        false,
                        'Validation Failed',
                        result.message,
                        null,
                        null,
                        logTime,
                        logTime,
                        0
                    );

                    return result;
                }

                accountId = orderRecord.Customer__c;
            }

            result.recordId =
                String.valueOf(accountId);

            // =====================================================
            // LOAD ACTIVE FIELD MAPPINGS
            // =====================================================
            List<Customer_Field_Mapping_For_BC_Sync__mdt> mappings =
                getActiveMappings();

            System.debug(
                LoggingLevel.DEBUG,
                'BC SYNC - Active metadata mappings = ' +
                mappings.size()
            );

            // =====================================================
            // FETCH ACCOUNT WITH ALL CONFIGURED FIELDS
            // =====================================================
            Account acc =
                getAccountRecord(
                    accountId,
                    mappings
                );

            // =====================================================
            // VALIDATE PHONE
            // =====================================================
            if (String.isBlank(acc.Phone)) {

                result.success = false;
                result.statusCode = 400;
                result.message =
                    'Please fill Phone Number first to push to ERP';

                Datetime logTime = System.now();

                insertIntegrationLog(
                    accountId,
                    null,
                    null,
                    null,
                    null,
                    null,
                    400,
                    'Validation Failed',
                    false,
                    'Validation Failed',
                    result.message,
                    null,
                    null,
                    logTime,
                    logTime,
                    0
                );

                return result;
            }

            // =====================================================
            // FETCH CURRENT USER LOCATION
            // =====================================================
            User currentUser = [
                SELECT Id, Location_Code__c
                FROM User
                WHERE Id = :UserInfo.getUserId()
                WITH USER_MODE
                LIMIT 1
            ];

            // =====================================================
            // FETCH / CREATE TRACKING RECORD
            // =====================================================
            Orient_Customer_Tracking__c trackingRecord =
                getTrackingRecord(
                    accountId,
                    mappings
                );

            Boolean isUpdate =
                String.isNotBlank(
                    acc.BC_Customer_No__c
                );

            // =====================================================
            // BUILD METADATA-DRIVEN OUTBOUND PAYLOAD
            // =====================================================
            Map<String, Object> payload =
                buildOutboundPayload(
                    acc,
                    trackingRecord,
                    mappings
                );

            // Existing BC customer => PATCH identity.
            if (isUpdate) {
                payload.put(
                    'customerNo',
                    acc.BC_Customer_No__c
                );
            }

            // User Location Code is special integration logic.
            if (
                String.isNotBlank(
                    currentUser.Location_Code__c
                )
            ) {
                payload.put(
                    'locationCode',
                    currentUser.Location_Code__c
                );
            }

            // =====================================================
            // KYC DOCUMENT TYPE SPECIAL VALUE MAPPING
            //
            // Salesforce Customer_Verification_KYC__c values and
            // Business Central kycDocumentType values are different.
            //
            // Only these three values are supported for outbound sync:
            //
            // Salesforce "Aadhaar Card" -> BC "Aadhaar Card"
            // Salesforce "Voter ID"     -> BC "Voter Id Card"
            // Salesforce "PAN"          -> BC "Form 60/61"
            //
            // Any other Salesforce value is intentionally omitted.
            //
            // CMDT configuration required:
            // Account_Field_API__c  = Customer_Verification_KYC__c
            // Outbound_Enabled__c   = true
            // Outbound_Key__c       = kycDocumentType
            // Lock_After_Sync__c    = true
            // =====================================================
            if (
                payload.containsKey('kycDocumentType') &&
                payload.get('kycDocumentType') != null
            ) {

                String salesforceKycType =
                    String.valueOf(
                        payload.get('kycDocumentType')
                    ).trim();

                if (salesforceKycType == 'Aadhaar Card') {

                    payload.put(
                        'kycDocumentType',
                        'Aadhaar Card'
                    );

                } else if (salesforceKycType == 'Voter ID') {

                    payload.put(
                        'kycDocumentType',
                        'Voter Id Card'
                    );

                } else if (salesforceKycType == 'PAN') {

                    payload.put(
                        'kycDocumentType',
                        'Form 60/61'
                    );

                } else {

                    // Only Aadhaar, Voter and PAN are mapped to BC.
                    payload.remove(
                        'kycDocumentType'
                    );
                }
            }

            // =====================================================
            // AADHAAR SPECIAL HANDLING
            // Metadata adds aadharNo. BC expects it as a number and
            // also expects kycDocumentNo.
            // =====================================================
            if (
                payload.containsKey('aadharNo') &&
                payload.get('aadharNo') != null
            ) {

                String aadhaarValue =
                    String.valueOf(
                        payload.get('aadharNo')
                    ).trim();

                try {

                    payload.put(
                        'aadharNo',
                        Long.valueOf(aadhaarValue)
                    );

                    payload.put(
                        'kycDocumentNo',
                        aadhaarValue
                    );

                } catch (Exception aadhaarEx) {

                    result.success = false;
                    result.statusCode = 400;
                    result.message =
                        'Invalid Aadhaar Number. Aadhaar must contain only numeric digits.';

                    Datetime logTime = System.now();

                    insertIntegrationLog(
                        accountId,
                        null,
                        null,
                        JSON.serialize(payload),
                        null,
                        null,
                        400,
                        'Validation Failed',
                        false,
                        'Validation Failed',
                        result.message,
                        aadhaarEx,
                        aadhaarEx.getStackTraceString(),
                        logTime,
                        logTime,
                        0
                    );

                    return result;
                }
            }

            // =====================================================
            // GST SPECIAL VALUES
            // =====================================================
            if (
                payload.containsKey('gstRegistrationNo') &&
                payload.get('gstRegistrationNo') != null &&
                String.isNotBlank(
                    String.valueOf(
                        payload.get('gstRegistrationNo')
                    )
                )
            ) {

                payload.put(
                    'customerPostingGroup',
                    'RETAIL_CUST (B2C)'
                );

                payload.put(
                    'gstRegistrationType',
                    'GSTIN'
                );

                payload.put(
                    'generalBusinessPostingGroup',
                    'DOMESTIC'
                );
            }

            // =====================================================
            // SERIALIZE REQUEST
            // =====================================================
            finalJson =
                JSON.serialize(payload);

            result.requestBody =
                finalJson;

            System.debug(
                LoggingLevel.DEBUG,
                'BC SYNC - Final Request JSON => ' +
                finalJson
            );

            // =====================================================
            // CONFIGURE HTTP REQUEST
            // =====================================================
            HttpRequest request =
                new HttpRequest();

            endpoint =
                'callout:Orient_API_Access_NC/' +
                System.Label.BC_Endpoint +
                '/ACXCustomerListAPIJRS';

            if (isUpdate) {

                endpoint +=
                    '(\'' +
                    acc.BC_Customer_No__c +
                    '\',\'' +
                    acc.Phone +
                    '\')';

                httpMethod =
                    'PATCH';

                request.setMethod(
                    httpMethod
                );

                request.setHeader(
                    'If-Match',
                    '*'
                );

            } else {

                httpMethod =
                    'POST';

                request.setMethod(
                    httpMethod
                );
            }

            request.setEndpoint(
                endpoint
            );

            request.setHeader(
                'Content-Type',
                'application/json'
            );

            request.setHeader(
                'Accept',
                'application/json'
            );

            request.setTimeout(
                20000
            );

            request.setBody(
                finalJson
            );

            // Only safe/non-sensitive request headers are logged.
            Map<String, String> safeHeaderMap =
                new Map<String, String>{
                    'Content-Type' => 'application/json',
                    'Accept' => 'application/json'
                };

            if (isUpdate) {
                safeHeaderMap.put(
                    'If-Match',
                    '*'
                );
            }

            requestHeaders =
                JSON.serialize(
                    safeHeaderMap
                );

            // =====================================================
            // CALLOUT
            // =====================================================
            requestDateTime =
                System.now();

            calloutStartMs =
                requestDateTime.getTime();

            HttpResponse response =
                new Http().send(request);

            responseDateTime =
                System.now();

            durationMs =
                responseDateTime.getTime() -
                calloutStartMs;

            result.statusCode =
                response.getStatusCode();

            result.responseBody =
                response.getBody();

            result.success =
                result.statusCode >= 200 &&
                result.statusCode < 300;

            // =====================================================
            // LOG ACTUAL BC CALLOUT
            // =====================================================
            insertIntegrationLog(
                accountId,
                endpoint,
                httpMethod,
                finalJson,
                requestHeaders,
                result.responseBody,
                result.statusCode,
                response.getStatus(),
                result.success,
                result.success
                    ? 'Success'
                    : 'Failed',
                result.success
                    ? null
                    : response.getBody(),
                null,
                null,
                requestDateTime,
                responseDateTime,
                durationMs
            );

            // =====================================================
            // PROCESS SUCCESS
            // =====================================================
            if (result.success) {

                if (!isUpdate) {

                    String returnedCustomerNo =
                        extractCustomerNo(
                            result.responseBody
                        );

                    if (
                        String.isNotBlank(
                            returnedCustomerNo
                        )
                    ) {

                        result.customerNo =
                            returnedCustomerNo;

                        Account accountToUpdate =
                            new Account(
                                Id = acc.Id,
                                BC_Customer_No__c =
                                    returnedCustomerNo,
                                Status__c =
                                    'Active'
                            );

                        update as user
                            accountToUpdate;

                        // Keep the in-memory Account synchronized because
                        // the lock routine uses this same instance.
                        acc.BC_Customer_No__c =
                            returnedCustomerNo;

                        acc.Status__c =
                            'Active';
                    }

                } else {

                    result.customerNo =
                        acc.BC_Customer_No__c;
                }

                // =================================================
                // FINAL LOCKING RULE
                //
                // Any configured Lock_After_Sync field with a
                // meaningful Account value becomes TRUE after a
                // successful BC sync, even if it was not part of the
                // outbound JSON.
                //
                // Blank fields remain unchanged/unlocked.
                // =================================================
                lockPopulatedFields(
                    acc,
                    trackingRecord,
                    mappings
                );

                upsert as user
                    trackingRecord;

                result.message =
                    isUpdate
                    ? 'Customer updated in BC successfully.'
                    : 'Customer sent successfully.';

            } else {

                result.message =
                    'API Error: ' +
                    response.getStatus() +
                    ' - ' +
                    response.getBody();
            }

            return result;

        } catch (Exception e) {

            result.success = false;
            result.statusCode = 500;
            result.message =
                'Apex Exception: ' +
                e.getMessage();

            result.responseBody =
                e.getStackTraceString();

            Datetime exceptionTime =
                System.now();

            Long exceptionDuration =
                requestDateTime == null
                ? 0
                : exceptionTime.getTime() -
                    requestDateTime.getTime();

            insertIntegrationLog(
                accountId,
                endpoint,
                httpMethod,
                finalJson,
                requestHeaders,
                result.responseBody,
                500,
                'Exception',
                false,
                'Exception',
                e.getMessage(),
                e,
                e.getStackTraceString(),
                requestDateTime,
                exceptionTime,
                exceptionDuration
            );

            return result;
        }
    }

    // =========================================================
    // ACTIVE CUSTOM METADATA
    // =========================================================
    private static List<Customer_Field_Mapping_For_BC_Sync__mdt>
        getActiveMappings() {

        return [
            SELECT
                DeveloperName,
                MasterLabel,
                Account_Field_API__c,
                Tracking_Field_API__c,
                Inbound_Key__c,
                Outbound_Key__c,
                Inbound_Enabled__c,
                Outbound_Enabled__c,
                Lock_After_Sync__c,
                Active__c
            FROM Customer_Field_Mapping_For_BC_Sync__mdt
            WHERE Active__c = true
            ORDER BY DeveloperName
        ];
    }

    // =========================================================
    // CASE-INSENSITIVE ACCOUNT FIELD LOOKUP
    //
    // IMPORTANT:
    // No explicit Schema.SObjectField declarations are used here.
    // This avoids the earlier compilation issue and also fixes the
    // describe-map casing issue shown in the debug log.
    // =========================================================
    private static Map<String, String>
        getAccountFieldApiLookup() {

        Map<String, String> lookup =
            new Map<String, String>();

        for (
            String mapKey :
            Account.SObjectType
                .getDescribe()
                .fields
                .getMap()
                .keySet()
        ) {

            String canonicalApiName =
                Account.SObjectType
                    .getDescribe()
                    .fields
                    .getMap()
                    .get(mapKey)
                    .getDescribe()
                    .getName();

            if (String.isNotBlank(mapKey)) {
                lookup.put(
                    mapKey.trim().toLowerCase(),
                    canonicalApiName
                );
            }

            if (
                String.isNotBlank(
                    canonicalApiName
                )
            ) {
                lookup.put(
                    canonicalApiName
                        .trim()
                        .toLowerCase(),
                    canonicalApiName
                );
            }
        }

        return lookup;
    }

    // =========================================================
    // CASE-INSENSITIVE TRACKING FIELD LOOKUP
    // =========================================================
    private static Map<String, String>
        getTrackingFieldApiLookup() {

        Map<String, String> lookup =
            new Map<String, String>();

        for (
            String mapKey :
            new Orient_Customer_Tracking__c()
                .getSObjectType()
                .getDescribe()
                .fields
                .getMap()
                .keySet()
        ) {

            String canonicalApiName =
                new Orient_Customer_Tracking__c()
                    .getSObjectType()
                    .getDescribe()
                    .fields
                    .getMap()
                    .get(mapKey)
                    .getDescribe()
                    .getName();

            if (String.isNotBlank(mapKey)) {
                lookup.put(
                    mapKey.trim().toLowerCase(),
                    canonicalApiName
                );
            }

            if (
                String.isNotBlank(
                    canonicalApiName
                )
            ) {
                lookup.put(
                    canonicalApiName
                        .trim()
                        .toLowerCase(),
                    canonicalApiName
                );
            }
        }

        return lookup;
    }

    // =========================================================
    // RESOLVE ACCOUNT API NAME
    // =========================================================
    private static String resolveAccountFieldApi(
        String configuredApiName,
        Map<String, String> lookup
    ) {

        if (
            String.isBlank(
                configuredApiName
            ) ||
            lookup == null
        ) {
            return null;
        }

        return lookup.get(
            configuredApiName
                .trim()
                .toLowerCase()
        );
    }

    // =========================================================
    // RESOLVE TRACKING API NAME
    // =========================================================
    private static String resolveTrackingFieldApi(
        String configuredApiName,
        Map<String, String> lookup
    ) {

        if (
            String.isBlank(
                configuredApiName
            ) ||
            lookup == null
        ) {
            return null;
        }

        return lookup.get(
            configuredApiName
                .trim()
                .toLowerCase()
        );
    }

    // =========================================================
    // FETCH ACCOUNT DYNAMICALLY
    // =========================================================
    private static Account getAccountRecord(
        Id accountId,
        List<Customer_Field_Mapping_For_BC_Sync__mdt>
            mappings
    ) {

        Set<String> fieldApis =
            new Set<String>{
                'Id',
                'Name',
                'Phone',
                'BC_Customer_No__c',
                'Status__c',
                'GST__c',
                'AadharNo__c'
            };

        Map<String, String> accountFieldLookup =
            getAccountFieldApiLookup();

        for (
            Customer_Field_Mapping_For_BC_Sync__mdt mapping :
            mappings
        ) {

            if (
                mapping == null ||
                String.isBlank(
                    mapping.Account_Field_API__c
                )
            ) {
                continue;
            }

            String canonicalApiName =
                resolveAccountFieldApi(
                    mapping.Account_Field_API__c,
                    accountFieldLookup
                );

            if (
                String.isBlank(
                    canonicalApiName
                )
            ) {

                System.debug(
                    LoggingLevel.WARN,
                    'BC SYNC - Account field not found from CMDT: ' +
                    mapping.Account_Field_API__c +
                    ' | Mapping=' +
                    mapping.DeveloperName
                );

                continue;
            }

            fieldApis.add(
                canonicalApiName
            );
        }

        List<String> sortedFields =
            new List<String>();

        sortedFields.addAll(
            fieldApis
        );

        sortedFields.sort();

        String queryText =
            'SELECT ' +
            String.join(
                sortedFields,
                ','
            ) +
            ' FROM Account' +
            ' WHERE Id = :accountId' +
            ' WITH USER_MODE' +
            ' LIMIT 1';

        System.debug(
            LoggingLevel.DEBUG,
            'BC SYNC - Account Query => ' +
            queryText
        );

        List<SObject> records =
            Database.query(
                queryText
            );

        if (records.isEmpty()) {
            throw new AuraHandledException(
                'Customer could not be found.'
            );
        }

        return (Account)
            records[0];
    }

    // =========================================================
    // FETCH / CREATE TRACKING RECORD
    // =========================================================
    private static Orient_Customer_Tracking__c
        getTrackingRecord(
            Id accountId,
            List<Customer_Field_Mapping_For_BC_Sync__mdt>
                mappings
        ) {

        Set<String> fieldApis =
            new Set<String>{
                'Id',
                'Orient_Customer__c'
            };

        Map<String, String> trackingFieldLookup =
            getTrackingFieldApiLookup();

        for (
            Customer_Field_Mapping_For_BC_Sync__mdt mapping :
            mappings
        ) {

            if (
                mapping == null ||
                String.isBlank(
                    mapping.Tracking_Field_API__c
                )
            ) {
                continue;
            }

            String canonicalApiName =
                resolveTrackingFieldApi(
                    mapping.Tracking_Field_API__c,
                    trackingFieldLookup
                );

            if (
                String.isBlank(
                    canonicalApiName
                )
            ) {

                System.debug(
                    LoggingLevel.WARN,
                    'BC SYNC - Tracking field not found from CMDT: ' +
                    mapping.Tracking_Field_API__c +
                    ' | Mapping=' +
                    mapping.DeveloperName
                );

                continue;
            }

            fieldApis.add(
                canonicalApiName
            );
        }

        List<String> sortedFields =
            new List<String>();

        sortedFields.addAll(
            fieldApis
        );

        sortedFields.sort();

        String queryText =
            'SELECT ' +
            String.join(
                sortedFields,
                ','
            ) +
            ' FROM Orient_Customer_Tracking__c' +
            ' WHERE Orient_Customer__c = :accountId' +
            ' WITH USER_MODE' +
            ' LIMIT 1';

        System.debug(
            LoggingLevel.DEBUG,
            'BC SYNC - Tracking Query => ' +
            queryText
        );

        List<SObject> records =
            Database.query(
                queryText
            );

        if (!records.isEmpty()) {

            return
                (Orient_Customer_Tracking__c)
                    records[0];
        }

        return new Orient_Customer_Tracking__c(
            Orient_Customer__c =
                accountId
        );
    }

    // =========================================================
    // BUILD METADATA-DRIVEN OUTBOUND PAYLOAD
    // =========================================================
    private static Map<String, Object>
        buildOutboundPayload(
            Account acc,
            Orient_Customer_Tracking__c trackingRecord,
            List<Customer_Field_Mapping_For_BC_Sync__mdt>
                mappings
        ) {

        Map<String, Object> payload =
            new Map<String, Object>();

        Map<String, String> accountFieldLookup =
            getAccountFieldApiLookup();

        Map<String, String> trackingFieldLookup =
            getTrackingFieldApiLookup();

        for (
            Customer_Field_Mapping_For_BC_Sync__mdt mapping :
            mappings
        ) {

            if (
                mapping == null ||
                mapping.Active__c != true ||
                mapping.Outbound_Enabled__c != true ||
                String.isBlank(
                    mapping.Account_Field_API__c
                ) ||
                String.isBlank(
                    mapping.Outbound_Key__c
                )
            ) {
                continue;
            }

            String accountField =
                resolveAccountFieldApi(
                    mapping.Account_Field_API__c,
                    accountFieldLookup
                );

            if (
                String.isBlank(
                    accountField
                )
            ) {
                continue;
            }

            // -------------------------------------------------
            // DO NOT RESEND AN ALREADY LOCKED FIELD
            // -------------------------------------------------
            if (
                mapping.Lock_After_Sync__c == true &&
                String.isNotBlank(
                    mapping.Tracking_Field_API__c
                )
            ) {

                String trackingField =
                    resolveTrackingFieldApi(
                        mapping.Tracking_Field_API__c,
                        trackingFieldLookup
                    );

                if (
                    String.isNotBlank(
                        trackingField
                    ) &&
                    isTrackingLocked(
                        trackingRecord,
                        trackingField
                    )
                ) {
                    continue;
                }
            }

            Object accountValue;

            try {

                accountValue =
                    acc.get(
                        accountField
                    );

            } catch (Exception fieldEx) {

                System.debug(
                    LoggingLevel.ERROR,
                    'BC SYNC - Unable to read Account field ' +
                    accountField +
                    ': ' +
                    fieldEx.getMessage()
                );

                continue;
            }

            if (
                !hasMeaningfulValue(
                    accountValue
                )
            ) {
                continue;
            }

            payload.put(
                mapping
                    .Outbound_Key__c
                    .trim(),
                accountValue
            );

            System.debug(
                LoggingLevel.DEBUG,
                'BC SYNC - Payload Field => ' +
                accountField +
                ' -> ' +
                mapping.Outbound_Key__c +
                ' = ' +
                String.valueOf(
                    accountValue
                )
            );
        }

        return payload;
    }

    // =========================================================
    // LOCK ALL POPULATED CONFIGURED FIELDS AFTER SUCCESS
    // =========================================================
    private static void lockPopulatedFields(
        Account acc,
        Orient_Customer_Tracking__c trackingRecord,
        List<Customer_Field_Mapping_For_BC_Sync__mdt>
            mappings
    ) {

        if (
            acc == null ||
            trackingRecord == null ||
            mappings == null
        ) {
            return;
        }

        Map<String, String> accountFieldLookup =
            getAccountFieldApiLookup();

        Map<String, String> trackingFieldLookup =
            getTrackingFieldApiLookup();

        for (
            Customer_Field_Mapping_For_BC_Sync__mdt mapping :
            mappings
        ) {

            if (
                mapping == null ||
                mapping.Active__c != true ||
                mapping.Lock_After_Sync__c != true ||
                String.isBlank(
                    mapping.Account_Field_API__c
                ) ||
                String.isBlank(
                    mapping.Tracking_Field_API__c
                )
            ) {
                continue;
            }

            String accountField =
                resolveAccountFieldApi(
                    mapping.Account_Field_API__c,
                    accountFieldLookup
                );

            String trackingField =
                resolveTrackingFieldApi(
                    mapping.Tracking_Field_API__c,
                    trackingFieldLookup
                );

            if (
                String.isBlank(
                    accountField
                ) ||
                String.isBlank(
                    trackingField
                )
            ) {
                continue;
            }

            Object accountValue;

            try {

                accountValue =
                    acc.get(
                        accountField
                    );

            } catch (Exception fieldEx) {

                System.debug(
                    LoggingLevel.ERROR,
                    'BC SYNC - Unable to evaluate field for locking ' +
                    accountField +
                    ': ' +
                    fieldEx.getMessage()
                );

                continue;
            }

            // Blank Account values remain unchanged/unlocked.
            if (
                !hasMeaningfulValue(
                    accountValue
                )
            ) {
                continue;
            }

            try {

                trackingRecord.put(
                    trackingField,
                    true
                );

                System.debug(
                    LoggingLevel.DEBUG,
                    'BC SYNC - Locked Field => ' +
                    accountField +
                    ' -> ' +
                    trackingField
                );

            } catch (Exception trackingEx) {

                System.debug(
                    LoggingLevel.ERROR,
                    'BC SYNC - Unable to set tracking field ' +
                    trackingField +
                    ': ' +
                    trackingEx.getMessage()
                );
            }
        }
    }

    // =========================================================
    // CHECK TRACKING LOCK
    // =========================================================
    private static Boolean isTrackingLocked(
        Orient_Customer_Tracking__c trackingRecord,
        String trackingField
    ) {

        if (
            trackingRecord == null ||
            String.isBlank(
                trackingField
            )
        ) {
            return false;
        }

        try {

            Object fieldValue =
                trackingRecord.get(
                    trackingField
                );

            if (fieldValue == null) {
                return false;
            }

            return (Boolean)
                fieldValue;

        } catch (Exception ex) {

            return false;
        }
    }

    // =========================================================
    // MEANINGFUL VALUE
    //
    // null / blank String => false
    // 0 / false / Date / Id => true
    // =========================================================
    private static Boolean hasMeaningfulValue(
        Object value
    ) {

        if (value == null) {
            return false;
        }

        if (value instanceof String) {

            return String.isNotBlank(
                String.valueOf(value)
            );
        }

        return true;
    }

    // =========================================================
    // DIRECT INTEGRATION RESULT LOGGING
    // =========================================================
    private static void insertIntegrationLog(
        Id relatedRecordId,
        String endpoint,
        String httpMethod,
        String requestJson,
        String requestHeaders,
        String responseBody,
        Integer statusCode,
        String responseStatus,
        Boolean success,
        String logStatus,
        String errorMessage,
        Exception exceptionRecord,
        String stackTrace,
        Datetime requestDateTime,
        Datetime responseDateTime,
        Long durationMs
    ) {

        try {

            Integration_Result__c logRecord =
                new Integration_Result__c();

            logRecord.Apex_Class_Name__c =
                CLASS_NAME;

            logRecord.Method_Name__c =
                METHOD_NAME;

            logRecord.API_Type__c =
                API_TYPE;

            logRecord.Related_Object_API__c =
                'Account';

            if (relatedRecordId != null) {

                logRecord.Related_Record_Id__c =
                    String.valueOf(
                        relatedRecordId
                    );
            }

            logRecord.Endpoint__c =
                truncateText(
                    endpoint,
                    255
                );

            if (
                String.isNotBlank(
                    httpMethod
                )
            ) {

                logRecord.HTTP_Method__c =
                    httpMethod;
            }

            logRecord.Request_Date_Time__c =
                requestDateTime;

            logRecord.Response_Date_Time__c =
                responseDateTime;

            logRecord.Duration_Milliseconds__c =
                durationMs;

            logRecord.Request_JSON__c =
                truncateText(
                    requestJson,
                    131072
                );

            logRecord.Request_Headers__c =
                truncateText(
                    requestHeaders,
                    131072
                );

            logRecord.Response_Body__c =
                truncateText(
                    responseBody,
                    131072
                );

            logRecord.Status_Code__c =
                statusCode;

            logRecord.Response_Status__c =
                truncateText(
                    responseStatus,
                    255
                );

            logRecord.Success__c =
                success == true;

            if (
                String.isNotBlank(
                    logStatus
                )
            ) {

                logRecord.Log_Status__c =
                    logStatus;
            }

            logRecord.Error_Message__c =
                truncateText(
                    errorMessage,
                    32768
                );

            logRecord.Attempt_Number__c =
                1;

            logRecord.Is_Retry__c =
                false;

            if (exceptionRecord != null) {

                logRecord.Exception_Type__c =
                    truncateText(
                        exceptionRecord
                            .getTypeName(),
                        255
                    );

                logRecord.Line_Number__c =
                    exceptionRecord
                        .getLineNumber();

                String finalStackTrace =
                    String.isNotBlank(
                        stackTrace
                    )
                    ? stackTrace
                    : exceptionRecord
                        .getStackTraceString();

                logRecord.Stack_Trace__c =
                    truncateText(
                        finalStackTrace,
                        131072
                    );
            }

            insert logRecord;

        } catch (Exception logException) {

            System.debug(
                LoggingLevel.ERROR,
                'Integration_Result__c logging failed: ' +
                logException.getMessage()
            );
        }
    }

    // =========================================================
    // SAFE TEXT TRUNCATION
    // =========================================================
    private static String truncateText(
        String value,
        Integer maxLength
    ) {

        if (
            value == null ||
            maxLength == null ||
            maxLength <= 0
        ) {
            return value;
        }

        if (
            value.length() <=
            maxLength
        ) {
            return value;
        }

        return value.substring(
            0,
            maxLength
        );
    }

    // =========================================================
    // EXTRACT BC CUSTOMER NUMBER
    // =========================================================
    private static String extractCustomerNo(
        String responseBody
    ) {

        if (
            String.isBlank(
                responseBody
            )
        ) {
            return null;
        }

        try {

            Object parsedResponse =
                JSON.deserializeUntyped(
                    responseBody
                );

            if (
                parsedResponse instanceof
                    Map<String, Object>
            ) {

                Map<String, Object> responseMap =
                    (Map<String, Object>)
                        parsedResponse;

                // Direct:
                // { "customerNo" : "CUS001" }
                if (
                    responseMap.containsKey(
                        'customerNo'
                    ) &&
                    responseMap.get(
                        'customerNo'
                    ) != null
                ) {

                    return String.valueOf(
                        responseMap.get(
                            'customerNo'
                        )
                    );
                }

                // OData:
                // { "value" : [ { "customerNo" : "CUS001" } ] }
                if (
                    responseMap.containsKey(
                        'value'
                    ) &&
                    responseMap.get(
                        'value'
                    ) instanceof
                        List<Object>
                ) {

                    List<Object> values =
                        (List<Object>)
                            responseMap.get(
                                'value'
                            );

                    if (
                        !values.isEmpty() &&
                        values[0] instanceof
                            Map<String, Object>
                    ) {

                        Map<String, Object> firstValue =
                            (Map<String, Object>)
                                values[0];

                        if (
                            firstValue.containsKey(
                                'customerNo'
                            ) &&
                            firstValue.get(
                                'customerNo'
                            ) != null
                        ) {

                            return String.valueOf(
                                firstValue.get(
                                    'customerNo'
                                )
                            );
                        }
                    }
                }

                // Nested:
                // { "d" : { "customerNo" : "CUS001" } }
                if (
                    responseMap.containsKey(
                        'd'
                    ) &&
                    responseMap.get(
                        'd'
                    ) instanceof
                        Map<String, Object>
                ) {

                    Map<String, Object> nestedResponse =
                        (Map<String, Object>)
                            responseMap.get(
                                'd'
                            );

                    if (
                        nestedResponse.containsKey(
                            'customerNo'
                        ) &&
                        nestedResponse.get(
                            'customerNo'
                        ) != null
                    ) {

                        return String.valueOf(
                            nestedResponse.get(
                                'customerNo'
                            )
                        );
                    }
                }
            }

        } catch (Exception extractionException) {

            System.debug(
                LoggingLevel.ERROR,
                'Error extracting customerNo: ' +
                extractionException
                    .getMessage()
            );
        }

        return null;
    }
}