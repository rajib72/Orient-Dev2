@RestResource(urlMapping='/CreateActiveCust/*')
global with sharing class Ctrl_API_CreateActiveCustomer {

    private static final Integer CHUNK_SIZE = 200;
    private static final String CLASS_NAME = 'Ctrl_API_CreateActiveCustomer';
    private static final String METHOD_NAME = 'createAccounts';
    private static final String API_TYPE = 'Inbound_CreateActiveCustomer';

    // =========================================================
    // RESPONSE WRAPPERS
    // =========================================================
    global class RecordResult {
        public Boolean success;
        public Id recordId;
        public String customerNo;
        public String errorMessage;
    }

    global class ApiResponse {
        public Boolean success;
        public String message;
        public Integer totalReceived;
        public Integer totalProcessed;
        public Integer totalSuccess;
        public Integer totalFailed;
        public List<RecordResult> results = new List<RecordResult>();
    }

    // =========================================================
    // MAIN INBOUND ENDPOINT
    // =========================================================
    @HttpPost
    global static void createAccounts() {

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        ApiResponse responseBody = new ApiResponse();

        Datetime requestDateTime = System.now();
        String correlationId = createCorrelationId(req);
        String endpoint = req == null ? null : req.requestURI;
        String safeRequestHeaders = buildSafeRequestHeaders(req);
        String requestJson;

        try {

            res.addHeader(
                'Content-Type',
                'application/json'
            );

            // =====================================================
            // REQUEST BODY VALIDATION
            // =====================================================
            if (
                req == null ||
                req.requestBody == null ||
                String.isBlank(
                    req.requestBody.toString()
                )
            ) {

                initializeEmptyResponse(
                    responseBody
                );

                responseBody.success = false;
                responseBody.message =
                    'Request body is required.';

                res.statusCode = 400;
                res.responseBody =
                    Blob.valueOf(
                        JSON.serializePretty(
                            responseBody
                        )
                    );

                insertSingleIntegrationLog(
                    correlationId,
                    endpoint,
                    null,
                    safeRequestHeaders,
                    res.responseBody.toString(),
                    null,
                    400,
                    'Bad Request',
                    false,
                    'Validation Failed',
                    responseBody.message,
                    null,
                    requestDateTime,
                    System.now()
                );

                return;
            }

            requestJson =
                req.requestBody.toString();

            System.debug(
                'Incoming Request =====> ' +
                requestJson
            );

            Object requestData;

            try {

                requestData =
                    JSON.deserializeUntyped(
                        requestJson
                    );

            } catch (Exception jsonEx) {

                initializeEmptyResponse(
                    responseBody
                );

                responseBody.success = false;
                responseBody.message =
                    'Invalid JSON format.';

                res.statusCode = 400;
                res.responseBody =
                    Blob.valueOf(
                        JSON.serializePretty(
                            responseBody
                        )
                    );

                insertSingleIntegrationLog(
                    correlationId,
                    endpoint,
                    requestJson,
                    safeRequestHeaders,
                    res.responseBody.toString(),
                    null,
                    400,
                    'Bad Request',
                    false,
                    'Validation Failed',
                    jsonEx.getMessage(),
                    jsonEx,
                    requestDateTime,
                    System.now()
                );

                return;
            }

            List<Object> payloadList =
                new List<Object>();

            if (
                requestData instanceof
                    List<Object>
            ) {

                payloadList =
                    (List<Object>)
                        requestData;

            } else if (
                requestData instanceof
                    Map<String, Object>
            ) {

                payloadList.add(
                    requestData
                );

            } else {

                initializeEmptyResponse(
                    responseBody
                );

                responseBody.success = false;
                responseBody.message =
                    'Invalid JSON format. Expected one customer object or a list of customer objects.';

                res.statusCode = 400;
                res.responseBody =
                    Blob.valueOf(
                        JSON.serializePretty(
                            responseBody
                        )
                    );

                insertSingleIntegrationLog(
                    correlationId,
                    endpoint,
                    requestJson,
                    safeRequestHeaders,
                    res.responseBody.toString(),
                    null,
                    400,
                    'Bad Request',
                    false,
                    'Validation Failed',
                    responseBody.message,
                    null,
                    requestDateTime,
                    System.now()
                );

                return;
            }

            responseBody.totalReceived =
                payloadList.size();

            responseBody.totalProcessed = 0;
            responseBody.totalSuccess = 0;
            responseBody.totalFailed = 0;

            if (payloadList.isEmpty()) {

                responseBody.success = false;
                responseBody.message =
                    'No records received.';

                res.statusCode = 400;
                res.responseBody =
                    Blob.valueOf(
                        JSON.serializePretty(
                            responseBody
                        )
                    );

                insertSingleIntegrationLog(
                    correlationId,
                    endpoint,
                    requestJson,
                    safeRequestHeaders,
                    res.responseBody.toString(),
                    null,
                    400,
                    'Bad Request',
                    false,
                    'Validation Failed',
                    responseBody.message,
                    null,
                    requestDateTime,
                    System.now()
                );

                return;
            }

            if (
                payloadList.size() >
                CHUNK_SIZE
            ) {

                responseBody.success = false;
                responseBody.message =
                    'Maximum 200 records allowed per request.';

                res.statusCode = 400;
                res.responseBody =
                    Blob.valueOf(
                        JSON.serializePretty(
                            responseBody
                        )
                    );

                insertSingleIntegrationLog(
                    correlationId,
                    endpoint,
                    requestJson,
                    safeRequestHeaders,
                    res.responseBody.toString(),
                    null,
                    400,
                    'Bad Request',
                    false,
                    'Validation Failed',
                    responseBody.message,
                    null,
                    requestDateTime,
                    System.now()
                );

                return;
            }

            // =====================================================
            // LOAD ACTIVE INBOUND CMDT MAPPINGS
            // =====================================================
            List<Customer_Field_Mapping_For_BC_Sync__mdt>
                metadataMappings =
                    getActiveInboundMappings();

            Map<String, Customer_Field_Mapping_For_BC_Sync__mdt>
                inboundMappings =
                    buildInboundMappingByKey(
                        metadataMappings
                    );

            /*
             * These lookup maps resolve API names case-insensitively.
             * This uses the same approach that fixed the outbound
             * metadata field-resolution problem.
             */
            Map<String, String>
                accountFieldApiLookup =
                    getAccountFieldApiLookup();

            Map<String, String>
                accountFieldTypeLookup =
                    getAccountFieldTypeLookup();

            Map<String, String>
                trackingFieldApiLookup =
                    getTrackingFieldApiLookup();

            Map<String, String>
                trackingFieldTypeLookup =
                    getTrackingFieldTypeLookup();

            // =====================================================
            // PRE-COLLECT MATCH KEYS
            // =====================================================
            Set<String> customerNos =
                new Set<String>();

            Set<String> phoneNumbers =
                new Set<String>();

            for (Object obj : payloadList) {

                if (
                    !(obj instanceof
                        Map<String, Object>)
                ) {
                    continue;
                }

                Map<String, Object> payload =
                    (Map<String, Object>)
                        obj;

                String customerNo =
                    getPayloadStringIgnoreCase(
                        payload,
                        'customerNo'
                    );

                String phone =
                    getPayloadStringIgnoreCase(
                        payload,
                        'phone'
                    );

                if (
                    String.isNotBlank(
                        customerNo
                    )
                ) {
                    customerNos.add(
                        customerNo.trim()
                    );
                }

                if (
                    String.isNotBlank(
                        phone
                    )
                ) {
                    phoneNumbers.add(
                        phone.trim()
                    );
                }
            }

            // =====================================================
            // MATCH EXISTING ACCOUNTS
            //
            // Priority is applied later:
            // 1. BC Customer No
            // 2. Phone
            // 3. Create
            // =====================================================
            Map<String, Account>
                existingAccountsByCustomerNo =
                    new Map<String, Account>();

            Map<String, Account>
                existingAccountsByPhone =
                    new Map<String, Account>();

            if (
                !customerNos.isEmpty() ||
                !phoneNumbers.isEmpty()
            ) {

                for (
                    Account existingAccount :
                    [
                        SELECT
                            Id,
                            BC_Customer_No__c,
                            Phone
                        FROM Account
                        WHERE
                            BC_Customer_No__c IN :customerNos
                            OR Phone IN :phoneNumbers
                    ]
                ) {

                    if (
                        String.isNotBlank(
                            existingAccount
                                .BC_Customer_No__c
                        )
                    ) {

                        existingAccountsByCustomerNo.put(
                            existingAccount
                                .BC_Customer_No__c
                                .trim(),
                            existingAccount
                        );
                    }

                    if (
                        String.isNotBlank(
                            existingAccount.Phone
                        )
                    ) {

                        existingAccountsByPhone.put(
                            existingAccount
                                .Phone
                                .trim(),
                            existingAccount
                        );
                    }
                }
            }

            // =====================================================
            // BUILD ACCOUNT DML LIST
            // =====================================================
            List<Account> accountsToProcess =
                new List<Account>();

            List<Integer> resultIndexes =
                new List<Integer>();

            Map<Integer, Set<String>>
                trackingFieldsByResultIndex =
                    new Map<Integer, Set<String>>();

            /*
             * Keep request fragment for final success/failure logs.
             */
            Map<Integer, String>
                requestJsonByResultIndex =
                    new Map<Integer, String>();

            for (
                Integer i = 0;
                i < payloadList.size();
                i++
            ) {

                RecordResult rr =
                    new RecordResult();

                responseBody.results.add(
                    rr
                );

                Object obj =
                    payloadList[i];

                requestJsonByResultIndex.put(
                    i,
                    safeSerialize(obj)
                );

                if (
                    !(obj instanceof
                        Map<String, Object>)
                ) {

                    rr.success = false;
                    rr.errorMessage =
                        'Invalid payload format at index ' +
                        i;

                    responseBody.totalFailed++;

                    continue;
                }

                Map<String, Object> payload =
                    (Map<String, Object>)
                        obj;

                Account accountToSave =
                    new Account();

                Set<String> trackingCheckboxes =
                    new Set<String>();

                // =================================================
                // PRESERVE EXISTING BUSINESS RULE:
                // NAME IS REQUIRED FOR EVERY INBOUND RECORD
                // =================================================
                String accountName =
                    getPayloadStringIgnoreCase(
                        payload,
                        'name'
                    );

                if (
                    String.isBlank(
                        accountName
                    )
                ) {

                    rr.success = false;
                    rr.errorMessage =
                        'Name is required.';

                    responseBody.totalFailed++;

                    continue;
                }

                accountToSave.Name =
                    accountName.trim();

                // =================================================
                // METADATA-DRIVEN FIELD MAPPING
                //
                // IMPORTANT INBOUND RULES:
                // - null / "" / whitespace => ignore completely
                // - BC can update a field even if it is already locked
                // - meaningful received field => tracking TRUE
                // =================================================
                for (
                    String externalKey :
                    payload.keySet()
                ) {

                    if (
                        String.isBlank(
                            externalKey
                        )
                    ) {
                        continue;
                    }

                    String normalizedExternalKey =
                        externalKey
                            .trim()
                            .toLowerCase();

                    if (
                        !inboundMappings
                            .containsKey(
                                normalizedExternalKey
                            )
                    ) {
                        continue;
                    }

                    Customer_Field_Mapping_For_BC_Sync__mdt
                        mapping =
                            inboundMappings.get(
                                normalizedExternalKey
                            );

                    if (
                        mapping == null ||
                        mapping.Inbound_Enabled__c !=
                            true ||
                        String.isBlank(
                            mapping
                                .Account_Field_API__c
                        )
                    ) {
                        continue;
                    }

                    Object incomingValue =
                        payload.get(
                            externalKey
                        );

                    /*
                     * BC null/blank means DO NOTHING.
                     * It must never clear Salesforce.
                     */
                    if (
                        !hasMeaningfulValue(
                            incomingValue
                        )
                    ) {
                        continue;
                    }

                    String accountField =
                        resolveApiName(
                            mapping
                                .Account_Field_API__c,
                            accountFieldApiLookup
                        );

                    if (
                        String.isBlank(
                            accountField
                        )
                    ) {

                        System.debug(
                            LoggingLevel.WARN,
                            'Inbound BC Sync - Invalid Account field in CMDT: ' +
                            mapping.Account_Field_API__c +
                            ' | Mapping=' +
                            mapping.DeveloperName
                        );

                        continue;
                    }

                    Object valueToApply =
                        incomingValue;

                    try {

                        Object convertedValue =
                            convertInboundValue(
                                accountField,
                                valueToApply,
                                accountFieldTypeLookup
                            );

                        /*
                         * A meaningful inbound value should never
                         * convert to null except an unsupported value.
                         */
                        if (
                            convertedValue ==
                                null
                        ) {
                            continue;
                        }

                        /*
                         * No tracking-lock check here.
                         * BC is the source of truth for inbound sync.
                         */
                        accountToSave.put(
                            accountField,
                            convertedValue
                        );

                        /*
                         * The tracking checkbox is set whenever BC
                         * explicitly sent a meaningful value, even if
                         * the Salesforce value was already the same.
                         */
                        if (
                            mapping
                                .Lock_After_Sync__c ==
                                true &&
                            String.isNotBlank(
                                mapping
                                    .Tracking_Field_API__c
                            )
                        ) {

                            String trackingField =
                                resolveApiName(
                                    mapping
                                        .Tracking_Field_API__c,
                                    trackingFieldApiLookup
                                );

                            if (
                                String.isNotBlank(
                                    trackingField
                                ) &&
                                isBooleanField(
                                    trackingField,
                                    trackingFieldTypeLookup
                                )
                            ) {

                                trackingCheckboxes.add(
                                    trackingField
                                );
                            }
                        }

                    } catch (
                        Exception fieldEx
                    ) {

                        System.debug(
                            LoggingLevel.ERROR,
                            'Inbound Field Mapping Error =====> ' +
                            externalKey +
                            ' -> ' +
                            accountField +
                            ' :: ' +
                            fieldEx.getMessage()
                        );
                    }
                }

                // =================================================
                // MATCHING VALUES
                // =================================================
                String customerNo =
                    getPayloadStringIgnoreCase(
                        payload,
                        'customerNo'
                    );

                String phone =
                    getPayloadStringIgnoreCase(
                        payload,
                        'phone'
                    );

                if (
                    String.isNotBlank(
                        customerNo
                    )
                ) {

                    customerNo =
                        customerNo.trim();

                    accountToSave
                        .BC_Customer_No__c =
                            customerNo;
                }

                if (
                    String.isNotBlank(
                        phone
                    )
                ) {

                    phone =
                        phone.trim();

                    accountToSave.Phone =
                        phone;
                }

                // =================================================
                // MATCH PRIORITY
                // 1. BC Customer No
                // 2. Phone
                // 3. New Account
                // =================================================
                if (
                    String.isNotBlank(
                        customerNo
                    ) &&
                    existingAccountsByCustomerNo
                        .containsKey(
                            customerNo
                        )
                ) {

                    accountToSave.Id =
                        existingAccountsByCustomerNo
                            .get(customerNo)
                            .Id;

                    System.debug(
                        'Updating Existing Record by Customer No =====> ' +
                        accountToSave.Id
                    );

                } else if (
                    String.isNotBlank(
                        phone
                    ) &&
                    existingAccountsByPhone
                        .containsKey(
                            phone
                        )
                ) {

                    accountToSave.Id =
                        existingAccountsByPhone
                            .get(phone)
                            .Id;

                    System.debug(
                        'Updating Existing Record by Phone =====> ' +
                        accountToSave.Id
                    );

                } else {

                    System.debug(
                        'Creating New Account =====> Customer No: ' +
                        customerNo +
                        ' | Phone: ' +
                        phone
                    );
                }

                accountsToProcess.add(
                    accountToSave
                );

                resultIndexes.add(
                    i
                );

                trackingFieldsByResultIndex.put(
                    i,
                    trackingCheckboxes
                );
            }

            responseBody.totalProcessed =
                accountsToProcess.size();

            // =====================================================
            // UPSERT ACCOUNTS
            // =====================================================
            Map<Id, Set<String>>
                trackingFieldsByAccount =
                    new Map<Id, Set<String>>();

            Map<Id, Set<Integer>>
                resultIndexesByAccount =
                    new Map<Id, Set<Integer>>();

            Integer startIndex = 0;

            while (
                startIndex <
                accountsToProcess.size()
            ) {

                Integer endIndex =
                    Math.min(
                        startIndex +
                            CHUNK_SIZE,
                        accountsToProcess.size()
                    );

                List<Account> chunk =
                    new List<Account>();

                for (
                    Integer x = startIndex;
                    x < endIndex;
                    x++
                ) {

                    chunk.add(
                        accountsToProcess[x]
                    );
                }

                Database.UpsertResult[]
                    dmlResults =
                        Database.upsert(
                            chunk,
                            false
                        );

                for (
                    Integer j = 0;
                    j < dmlResults.size();
                    j++
                ) {

                    Database.UpsertResult sr =
                        dmlResults[j];

                    Integer originalIndex =
                        resultIndexes[
                            startIndex + j
                        ];

                    RecordResult rr =
                        responseBody.results[
                            originalIndex
                        ];

                    Account sourceAccount =
                        chunk[j];

                    if (sr.isSuccess()) {

                        Id accountId =
                            sr.getId();

                        rr.success = true;
                        rr.recordId =
                            accountId;

                        rr.customerNo =
                            sourceAccount
                                .BC_Customer_No__c;

                        responseBody
                            .totalSuccess++;

                        if (
                            !trackingFieldsByAccount
                                .containsKey(
                                    accountId
                                )
                        ) {

                            trackingFieldsByAccount
                                .put(
                                    accountId,
                                    new Set<String>()
                                );
                        }

                        if (
                            trackingFieldsByResultIndex
                                .containsKey(
                                    originalIndex
                                )
                        ) {

                            trackingFieldsByAccount
                                .get(
                                    accountId
                                )
                                .addAll(
                                    trackingFieldsByResultIndex
                                        .get(
                                            originalIndex
                                        )
                                );
                        }

                        if (
                            !resultIndexesByAccount
                                .containsKey(
                                    accountId
                                )
                        ) {

                            resultIndexesByAccount
                                .put(
                                    accountId,
                                    new Set<Integer>()
                                );
                        }

                        resultIndexesByAccount
                            .get(accountId)
                            .add(
                                originalIndex
                            );

                    } else {

                        rr.success = false;

                        String errorMessage =
                            buildDmlErrorMessage(
                                sr.getErrors()
                            );

                        rr.errorMessage =
                            errorMessage;

                        responseBody
                            .totalFailed++;
                    }
                }

                startIndex =
                    endIndex;
            }

            // =====================================================
            // UPSERT TRACKING RECORDS
            //
            // Only meaningful fields received from BC are locked.
            // Existing TRUE values remain TRUE because we only write
            // TRUE values and never set FALSE.
            // =====================================================
            if (
                !trackingFieldsByAccount
                    .isEmpty()
            ) {

                Map<Id, Orient_Customer_Tracking__c>
                    existingTrackingByAccount =
                        new Map<Id, Orient_Customer_Tracking__c>();

                for (
                    Orient_Customer_Tracking__c
                        existingTracking :
                    [
                        SELECT
                            Id,
                            Orient_Customer__c
                        FROM
                            Orient_Customer_Tracking__c
                        WHERE
                            Orient_Customer__c IN
                                :trackingFieldsByAccount
                                    .keySet()
                    ]
                ) {

                    if (
                        !existingTrackingByAccount
                            .containsKey(
                                existingTracking
                                    .Orient_Customer__c
                            )
                    ) {

                        existingTrackingByAccount
                            .put(
                                existingTracking
                                    .Orient_Customer__c,
                                existingTracking
                            );
                    }
                }

                List<Orient_Customer_Tracking__c>
                    trackingRecords =
                        new List<Orient_Customer_Tracking__c>();

                List<Id> trackingAccountIds =
                    new List<Id>();

                for (
                    Id accountId :
                    trackingFieldsByAccount
                        .keySet()
                ) {

                    Orient_Customer_Tracking__c
                        trackingRecord;

                    if (
                        existingTrackingByAccount
                            .containsKey(
                                accountId
                            )
                    ) {

                        trackingRecord =
                            existingTrackingByAccount
                                .get(
                                    accountId
                                );

                    } else {

                        trackingRecord =
                            new Orient_Customer_Tracking__c(
                                Orient_Customer__c =
                                    accountId
                            );
                    }

                    for (
                        String checkboxField :
                        trackingFieldsByAccount
                            .get(accountId)
                    ) {

                        try {

                            trackingRecord.put(
                                checkboxField,
                                true
                            );

                        } catch (
                            Exception trackingFieldEx
                        ) {

                            System.debug(
                                LoggingLevel.ERROR,
                                'Inbound Tracking Field Error =====> ' +
                                checkboxField +
                                ' :: ' +
                                trackingFieldEx
                                    .getMessage()
                            );
                        }
                    }

                    trackingRecords.add(
                        trackingRecord
                    );

                    trackingAccountIds.add(
                        accountId
                    );
                }

                Database.UpsertResult[]
                    trackingResults =
                        Database.upsert(
                            trackingRecords,
                            false
                        );

                for (
                    Integer i = 0;
                    i < trackingResults.size();
                    i++
                ) {

                    if (
                        trackingResults[i]
                            .isSuccess()
                    ) {
                        continue;
                    }

                    Id accountId =
                        trackingAccountIds[i];

                    String errorMessage =
                        buildDmlErrorMessage(
                            trackingResults[i]
                                .getErrors()
                        );

                    if (
                        resultIndexesByAccount
                            .containsKey(
                                accountId
                            )
                    ) {

                        for (
                            Integer resultIndex :
                            resultIndexesByAccount
                                .get(accountId)
                        ) {

                            RecordResult rr =
                                responseBody.results[
                                    resultIndex
                                ];

                            if (
                                rr.success ==
                                    true
                            ) {

                                rr.success =
                                    false;

                                rr.errorMessage =
                                    'Account saved successfully, but Orient Customer Tracking failed: ' +
                                    errorMessage;

                                responseBody
                                    .totalSuccess--;

                                responseBody
                                    .totalFailed++;
                            }
                        }
                    }
                }
            }

            // =====================================================
            // FINAL API RESPONSE
            // =====================================================
            responseBody.success =
                responseBody.totalFailed ==
                    0;

            responseBody.message =
                responseBody.totalFailed ==
                    0
                ? 'All records processed successfully.'
                : 'Some records failed.';

            res.statusCode =
                responseBody.totalFailed ==
                    0
                ? 200
                : 207;

            res.responseBody =
                Blob.valueOf(
                    JSON.serializePretty(
                        responseBody
                    )
                );

            // =====================================================
            // BULK INTEGRATION LOGS
            // One log per inbound customer/result.
            // =====================================================
            insertResultLogs(
                correlationId,
                endpoint,
                safeRequestHeaders,
                requestDateTime,
                System.now(),
                responseBody,
                requestJsonByResultIndex
            );

        } catch (Exception e) {

            System.debug(
                'Unhandled Exception =====> ' +
                e.getMessage()
            );

            System.debug(
                'Stack Trace =====> ' +
                e.getStackTraceString()
            );

            responseBody.success =
                false;

            responseBody.message =
                e.getMessage();

            if (
                responseBody.totalReceived ==
                    null
            ) {
                responseBody.totalReceived = 0;
            }

            if (
                responseBody.totalProcessed ==
                    null
            ) {
                responseBody.totalProcessed = 0;
            }

            responseBody.totalSuccess = 0;
            responseBody.totalFailed = 1;

            res.statusCode = 500;

            res.responseBody =
                Blob.valueOf(
                    JSON.serializePretty(
                        responseBody
                    )
                );

            insertSingleIntegrationLog(
                correlationId,
                endpoint,
                requestJson,
                safeRequestHeaders,
                res.responseBody.toString(),
                null,
                500,
                'Internal Server Error',
                false,
                'Exception',
                e.getMessage(),
                e,
                requestDateTime,
                System.now()
            );
        }
    }

    // =========================================================
    // ACTIVE INBOUND CMDT
    // =========================================================
    private static List<Customer_Field_Mapping_For_BC_Sync__mdt>
        getActiveInboundMappings() {

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
            FROM
                Customer_Field_Mapping_For_BC_Sync__mdt
            WHERE
                Active__c = true
                AND Inbound_Enabled__c = true
            ORDER BY
                DeveloperName
        ];
    }

    // =========================================================
    // INBOUND KEY -> CMDT MAPPING
    //
    // IMPORTANT:
    // Inbound processing uses ONLY Inbound_Key__c.
    // Outbound_Key__c is never treated as an inbound alias.
    //
    // Example:
    // Locality_Area__c
    // Inbound_Key__c  = locality_area
    // Outbound_Key__c = address2
    //
    // For this inbound API BC must send:
    // "locality_area" : "..."
    //
    // "address2" is outbound-only and will be ignored inbound.
    // =========================================================
    private static Map<String, Customer_Field_Mapping_For_BC_Sync__mdt>
        buildInboundMappingByKey(
            List<Customer_Field_Mapping_For_BC_Sync__mdt>
                mappings
        ) {

        Map<String, Customer_Field_Mapping_For_BC_Sync__mdt>
            result =
                new Map<String, Customer_Field_Mapping_For_BC_Sync__mdt>();

        if (mappings == null) {
            return result;
        }

        for (
            Customer_Field_Mapping_For_BC_Sync__mdt mapping :
            mappings
        ) {

            if (
                mapping == null ||
                mapping.Active__c != true ||
                mapping.Inbound_Enabled__c != true ||
                String.isBlank(
                    mapping.Inbound_Key__c
                )
            ) {
                continue;
            }

            result.put(
                mapping
                    .Inbound_Key__c
                    .trim()
                    .toLowerCase(),
                mapping
            );
        }

        return result;
    }

    // =========================================================
    // CASE-INSENSITIVE ACCOUNT FIELD API LOOKUP
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

            if (
                String.isNotBlank(
                    mapKey
                )
            ) {

                lookup.put(
                    mapKey
                        .trim()
                        .toLowerCase(),
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
    // ACCOUNT FIELD TYPE LOOKUP
    // =========================================================
    private static Map<String, String>
        getAccountFieldTypeLookup() {

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

            String fieldType =
                String.valueOf(
                    Account.SObjectType
                        .getDescribe()
                        .fields
                        .getMap()
                        .get(mapKey)
                        .getDescribe()
                        .getType()
                ).toUpperCase();

            if (
                String.isNotBlank(
                    canonicalApiName
                )
            ) {

                lookup.put(
                    canonicalApiName
                        .trim()
                        .toLowerCase(),
                    fieldType
                );
            }
        }

        return lookup;
    }

    // =========================================================
    // CASE-INSENSITIVE TRACKING FIELD API LOOKUP
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

            if (
                String.isNotBlank(
                    mapKey
                )
            ) {

                lookup.put(
                    mapKey
                        .trim()
                        .toLowerCase(),
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
    // TRACKING FIELD TYPE LOOKUP
    // =========================================================
    private static Map<String, String>
        getTrackingFieldTypeLookup() {

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

            String fieldType =
                String.valueOf(
                    new Orient_Customer_Tracking__c()
                        .getSObjectType()
                        .getDescribe()
                        .fields
                        .getMap()
                        .get(mapKey)
                        .getDescribe()
                        .getType()
                ).toUpperCase();

            if (
                String.isNotBlank(
                    canonicalApiName
                )
            ) {

                lookup.put(
                    canonicalApiName
                        .trim()
                        .toLowerCase(),
                    fieldType
                );
            }
        }

        return lookup;
    }

    // =========================================================
    // RESOLVE CONFIGURED API NAME
    // =========================================================
    private static String resolveApiName(
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
    // FIELD TYPE CHECK
    // =========================================================
    private static Boolean isBooleanField(
        String canonicalApiName,
        Map<String, String> typeLookup
    ) {

        if (
            String.isBlank(
                canonicalApiName
            ) ||
            typeLookup == null
        ) {
            return false;
        }

        String fieldType =
            typeLookup.get(
                canonicalApiName
                    .trim()
                    .toLowerCase()
            );

        return fieldType ==
            'BOOLEAN';
    }

    // =========================================================
    // DYNAMIC INBOUND VALUE CONVERSION
    // =========================================================
    private static Object convertInboundValue(
        String accountFieldApi,
        Object incomingValue,
        Map<String, String> fieldTypeLookup
    ) {

        if (
            String.isBlank(
                accountFieldApi
            ) ||
            !hasMeaningfulValue(
                incomingValue
            )
        ) {
            return null;
        }

        String fieldType =
            fieldTypeLookup == null
            ? null
            : fieldTypeLookup.get(
                accountFieldApi
                    .trim()
                    .toLowerCase()
            );

        if (
            String.isBlank(
                fieldType
            )
        ) {
            return incomingValue;
        }

        String stringValue =
            String.valueOf(
                incomingValue
            ).trim();

        if (
            fieldType ==
                'DATE'
        ) {

            return Date.valueOf(
                stringValue
            );
        }

        if (
            fieldType ==
                'DATETIME'
        ) {

            String normalized =
                stringValue
                    .replace(
                        'T',
                        ' '
                    );

            if (
                normalized.endsWith(
                    'Z'
                )
            ) {

                normalized =
                    normalized.substring(
                        0,
                        normalized.length() -
                            1
                    );
            }

            Integer decimalIndex =
                normalized.indexOf('.');

            if (
                decimalIndex >
                    0
            ) {

                normalized =
                    normalized.substring(
                        0,
                        decimalIndex
                    );
            }

            return Datetime.valueOfGmt(
                normalized
            );
        }

        if (
            fieldType ==
                'CURRENCY' ||
            fieldType ==
                'DOUBLE' ||
            fieldType ==
                'PERCENT'
        ) {

            return Decimal.valueOf(
                stringValue
            );
        }

        if (
            fieldType ==
                'INTEGER'
        ) {

            return Integer.valueOf(
                stringValue
            );
        }

        if (
            fieldType ==
                'BOOLEAN'
        ) {

            return Boolean.valueOf(
                stringValue
            );
        }

        if (
            fieldType ==
                'REFERENCE'
        ) {

            return Id.valueOf(
                stringValue
            );
        }

        /*
         * Text, Email, Phone, Picklist, TextArea etc.
         */
        return String.valueOf(
            incomingValue
        );
    }

    // =========================================================
    // CASE-INSENSITIVE PAYLOAD VALUE
    // =========================================================
    private static Object getPayloadValueIgnoreCase(
        Map<String, Object> payload,
        String requestedKey
    ) {

        if (
            payload == null ||
            String.isBlank(
                requestedKey
            )
        ) {
            return null;
        }

        String normalizedRequestedKey =
            requestedKey
                .trim()
                .toLowerCase();

        for (
            String actualKey :
            payload.keySet()
        ) {

            if (
                String.isNotBlank(
                    actualKey
                ) &&
                actualKey
                    .trim()
                    .toLowerCase() ==
                    normalizedRequestedKey
            ) {

                return payload.get(
                    actualKey
                );
            }
        }

        return null;
    }

    // =========================================================
    // CASE-INSENSITIVE STRING PAYLOAD VALUE
    // =========================================================
    private static String getPayloadStringIgnoreCase(
        Map<String, Object> payload,
        String requestedKey
    ) {

        Object value =
            getPayloadValueIgnoreCase(
                payload,
                requestedKey
            );

        if (
            !hasMeaningfulValue(
                value
            )
        ) {
            return null;
        }

        return String.valueOf(
            value
        );
    }

    // =========================================================
    // MEANINGFUL VALUE
    //
    // null / "" / whitespace = false
    // 0 / false / Date etc. = true
    // =========================================================
    private static Boolean hasMeaningfulValue(
        Object value
    ) {

        if (
            value ==
                null
        ) {
            return false;
        }

        if (
            value instanceof
                String
        ) {

            return String.isNotBlank(
                String.valueOf(
                    value
                )
            );
        }

        return true;
    }

    // =========================================================
    // DML ERROR MESSAGE
    // =========================================================
    private static String buildDmlErrorMessage(
        Database.Error[] errors
    ) {

        if (
            errors == null ||
            errors.isEmpty()
        ) {
            return 'Unknown DML error.';
        }

        List<String> messages =
            new List<String>();

        for (
            Database.Error errorRecord :
            errors
        ) {

            messages.add(
                errorRecord
                    .getStatusCode() +
                ': ' +
                errorRecord
                    .getMessage()
            );
        }

        return String.join(
            messages,
            ' | '
        );
    }

    // =========================================================
    // INITIALIZE EMPTY RESPONSE
    // =========================================================
    private static void initializeEmptyResponse(
        ApiResponse responseBody
    ) {

        responseBody.totalReceived = 0;
        responseBody.totalProcessed = 0;
        responseBody.totalSuccess = 0;
        responseBody.totalFailed = 0;
    }

    // =========================================================
    // CORRELATION ID
    // =========================================================
    private static String createCorrelationId(
        RestRequest req
    ) {

        try {

            if (
                req != null &&
                req.headers != null
            ) {

                String suppliedId =
                    req.headers.get(
                        'X-Correlation-Id'
                    );

                if (
                    String.isNotBlank(
                        suppliedId
                    )
                ) {

                    return truncateText(
                        suppliedId.trim(),
                        255
                    );
                }
            }

        } catch (Exception ignoreEx) {
            // Fall through and create an internal correlation id.
        }

        return String.valueOf(
            System.now()
                .getTime()
        ) +
        '-' +
        String.valueOf(
            Crypto.getRandomInteger()
        );
    }

    // =========================================================
    // SAFE INBOUND HEADERS
    //
    // Authorization is intentionally NOT logged.
    // =========================================================
    private static String buildSafeRequestHeaders(
        RestRequest req
    ) {

        Map<String, String> safeHeaders =
            new Map<String, String>();

        if (
            req == null ||
            req.headers == null
        ) {
            return JSON.serialize(
                safeHeaders
            );
        }

        String contentType =
            req.headers.get(
                'Content-Type'
            );

        String userAgent =
            req.headers.get(
                'User-Agent'
            );

        String correlationHeader =
            req.headers.get(
                'X-Correlation-Id'
            );

        if (
            String.isNotBlank(
                contentType
            )
        ) {

            safeHeaders.put(
                'Content-Type',
                contentType
            );
        }

        if (
            String.isNotBlank(
                userAgent
            )
        ) {

            safeHeaders.put(
                'User-Agent',
                userAgent
            );
        }

        if (
            String.isNotBlank(
                correlationHeader
            )
        ) {

            safeHeaders.put(
                'X-Correlation-Id',
                correlationHeader
            );
        }

        return JSON.serialize(
            safeHeaders
        );
    }

    // =========================================================
    // BULK SUCCESS / FAILURE LOGS
    // =========================================================
    private static void insertResultLogs(
        String correlationId,
        String endpoint,
        String safeRequestHeaders,
        Datetime requestDateTime,
        Datetime responseDateTime,
        ApiResponse responseBody,
        Map<Integer, String>
            requestJsonByResultIndex
    ) {

        if (
            responseBody == null ||
            responseBody.results == null ||
            responseBody.results.isEmpty()
        ) {
            return;
        }

        List<Integration_Result__c>
            logs =
                new List<Integration_Result__c>();

        Long durationMs =
            requestDateTime == null ||
            responseDateTime == null
            ? 0
            : responseDateTime.getTime() -
                requestDateTime.getTime();

        for (
            Integer i = 0;
            i < responseBody.results.size();
            i++
        ) {

            RecordResult rr =
                responseBody.results[i];

            Boolean success =
                rr != null &&
                rr.success == true;

            Integration_Result__c logRecord =
                new Integration_Result__c();

            logRecord.Apex_Class_Name__c =
                CLASS_NAME;

            logRecord.Method_Name__c =
                METHOD_NAME;

            logRecord.API_Type__c =
                API_TYPE;

            logRecord.Correlation_Id__c =
                truncateText(
                    correlationId,
                    255
                );

            logRecord.Endpoint__c =
                truncateText(
                    endpoint,
                    255
                );

            logRecord.HTTP_Method__c =
                'POST';

            logRecord.Request_Date_Time__c =
                requestDateTime;

            logRecord.Response_Date_Time__c =
                responseDateTime;

            logRecord.Duration_Milliseconds__c =
                durationMs;

            if (
                requestJsonByResultIndex !=
                    null &&
                requestJsonByResultIndex
                    .containsKey(i)
            ) {

                logRecord.Request_JSON__c =
                    truncateText(
                        requestJsonByResultIndex
                            .get(i),
                        131072
                    );
            }

            logRecord.Request_Headers__c =
                truncateText(
                    safeRequestHeaders,
                    131072
                );

            logRecord.Response_Body__c =
                truncateText(
                    safeSerialize(rr),
                    131072
                );

            logRecord.Status_Code__c =
                success
                ? 200
                : 400;

            logRecord.Response_Status__c =
                success
                ? 'Processed'
                : 'Failed';

            logRecord.Success__c =
                success;

            logRecord.Log_Status__c =
                success
                ? 'Success'
                : 'Failed';

            logRecord.Error_Message__c =
                rr == null
                ? null
                : truncateText(
                    rr.errorMessage,
                    32768
                );

            logRecord.Related_Object_API__c =
                'Account';

            if (
                rr != null &&
                rr.recordId != null
            ) {

                logRecord.Related_Record_Id__c =
                    String.valueOf(
                        rr.recordId
                    );
            }

            logRecord.Attempt_Number__c =
                1;

            logRecord.Is_Retry__c =
                false;

            logs.add(
                logRecord
            );
        }

        insertLogsSafely(
            logs
        );
    }

    // =========================================================
    // REQUEST-LEVEL LOG
    // =========================================================
    private static void insertSingleIntegrationLog(
        String correlationId,
        String endpoint,
        String requestBody,
        String requestHeaders,
        String responseBody,
        Id relatedRecordId,
        Integer statusCode,
        String responseStatus,
        Boolean success,
        String logStatus,
        String errorMessage,
        Exception exceptionRecord,
        Datetime requestDateTime,
        Datetime responseDateTime
    ) {

        Integration_Result__c logRecord =
            new Integration_Result__c();

        logRecord.Apex_Class_Name__c =
            CLASS_NAME;

        logRecord.Method_Name__c =
            METHOD_NAME;

        logRecord.API_Type__c =
            API_TYPE;

        logRecord.Correlation_Id__c =
            truncateText(
                correlationId,
                255
            );

        logRecord.Endpoint__c =
            truncateText(
                endpoint,
                255
            );

        logRecord.HTTP_Method__c =
            'POST';

        logRecord.Request_Date_Time__c =
            requestDateTime;

        logRecord.Response_Date_Time__c =
            responseDateTime;

        if (
            requestDateTime != null &&
            responseDateTime != null
        ) {

            logRecord.Duration_Milliseconds__c =
                responseDateTime.getTime() -
                requestDateTime.getTime();
        }

        logRecord.Request_JSON__c =
            truncateText(
                requestBody,
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

        logRecord.Log_Status__c =
            logStatus;

        logRecord.Error_Message__c =
            truncateText(
                errorMessage,
                32768
            );

        logRecord.Related_Object_API__c =
            'Account';

        if (
            relatedRecordId != null
        ) {

            logRecord.Related_Record_Id__c =
                String.valueOf(
                    relatedRecordId
                );
        }

        logRecord.Attempt_Number__c =
            1;

        logRecord.Is_Retry__c =
            false;

        if (
            exceptionRecord != null
        ) {

            logRecord.Exception_Type__c =
                truncateText(
                    exceptionRecord
                        .getTypeName(),
                    255
                );

            logRecord.Line_Number__c =
                exceptionRecord
                    .getLineNumber();

            logRecord.Stack_Trace__c =
                truncateText(
                    exceptionRecord
                        .getStackTraceString(),
                    131072
                );
        }

        insertLogsSafely(
            new List<Integration_Result__c>{
                logRecord
            }
        );
    }

    // =========================================================
    // NON-BLOCKING LOG INSERT
    // =========================================================
    private static void insertLogsSafely(
        List<Integration_Result__c>
            logs
    ) {

        if (
            logs == null ||
            logs.isEmpty()
        ) {
            return;
        }

        try {

            Database.insert(
                logs,
                false
            );

        } catch (Exception logEx) {

            System.debug(
                LoggingLevel.ERROR,
                'Integration_Result__c logging failed: ' +
                logEx.getMessage()
            );
        }
    }

    // =========================================================
    // SAFE SERIALIZE
    // =========================================================
    private static String safeSerialize(
        Object value
    ) {

        try {

            return JSON.serialize(
                value
            );

        } catch (Exception serializeEx) {

            return String.valueOf(
                value
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
}