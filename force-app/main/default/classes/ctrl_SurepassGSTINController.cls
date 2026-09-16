public with sharing class ctrl_SurepassGSTINController {

    private static final String ENDPOINT_URL =
        System.Label.Surepass_Endpoint + '/api/v1/corporate/gstin';

    private static final String ACCOUNT_NAME_VERIFIED_FIELD =
        'Name_Verified__c';

    private static final String ACCOUNT_GSTIN_VERIFIED_FIELD =
        'GSTIN_Verified__c';

    private static final String GST_NAME_DIRECT =
        'DIRECT';

    private static final String GST_NAME_REVIEW =
        'REVIEW';

    private static final String GST_NAME_BLOCKED =
        'BLOCKED';

    private class GSTNameEvaluation {
        public String outcome;
        public String proposedName;
        public String message;
    }

    @AuraEnabled(cacheable=false)
    public static GSTINResponse verifyGSTIN(
        String idNumber,
        Id accountId
    ) {
        String requestJson;
        Datetime requestDateTime;
        Long startTime;

        try {
            if (String.isBlank(idNumber)) {
                GSTINResponse reqErr =
                    new GSTINResponse();

                reqErr.success = false;
                reqErr.message =
                    'GSTIN / ID Number is required.';

                return reqErr;
            }

            idNumber =
                idNumber.trim().toUpperCase();

            String apiKey =
                System.Label.Surepass_API_Key;

            if (String.isBlank(apiKey)) {
                GSTINResponse keyErr =
                    new GSTINResponse();

                keyErr.success = false;
                keyErr.message =
                    'Surepass API Key is not configured in Custom Label.';

                return keyErr;
            }

            apiKey = apiKey.trim();

            if (
                !apiKey
                    .toLowerCase()
                    .startsWith('bearer ')
            ) {
                apiKey =
                    'Bearer ' + apiKey;
            }

            Map<String, Object> requestBody =
                new Map<String, Object>{
                    'id_number' => idNumber
                };

            HttpRequest req =
                new HttpRequest();

            req.setEndpoint(ENDPOINT_URL);
            req.setMethod('POST');
            req.setTimeout(120000);

            req.setHeader(
                'Content-Type',
                'application/json'
            );

            req.setHeader(
                'Accept',
                'application/json'
            );

            req.setHeader(
                'Authorization',
                apiKey
            );

            requestJson =
                JSON.serialize(
                    requestBody
                );

            req.setBody(
                requestJson
            );

            requestDateTime =
                System.now();

            startTime =
                requestDateTime.getTime();

            Http http = new Http();
            HttpResponse res =
                http.send(req);

            if (res.getStatusCode() != 200) {
                String cleanMessage =
                    'Unknown API Error';

                try {
                    Map<String, Object> errResponse =
                        (Map<String, Object>)
                            JSON.deserializeUntyped(
                                res.getBody()
                            );

                    if (
                        errResponse.containsKey('message') &&
                        errResponse.get('message') != null
                    ) {
                        cleanMessage =
                            String.valueOf(
                                errResponse.get('message')
                            );
                    } else {
                        cleanMessage =
                            res.getBody();
                    }
                } catch (Exception parseEx) {
                    cleanMessage =
                        'Failed to process API error response.';
                }

                createSurepassFailureLog(
                    accountId,
                    'verifyGSTIN',
                    ENDPOINT_URL,
                    'POST',
                    requestJson,
                    res.getBody(),
                    res.getStatus(),
                    res.getStatusCode(),
                    cleanMessage,
                    null,
                    null,
                    requestDateTime,
                    System.now(),
                    startTime
                );

                GSTINResponse errRes =
                    new GSTINResponse();

                errRes.success = false;
                errRes.message = cleanMessage;

                return errRes;
            }

            GSTINResponse apiResponse =
                (GSTINResponse) JSON.deserialize(
                    res.getBody(),
                    GSTINResponse.class
                );

            if (
                apiResponse == null ||
                apiResponse.success != true ||
                apiResponse.data == null
            ) {
                String functionalMessage =
                    apiResponse != null &&
                    String.isNotBlank(
                        apiResponse.message
                    )
                        ? apiResponse.message
                        : 'GSTIN details were not returned by Surepass.';

                createSurepassFailureLog(
                    accountId,
                    'verifyGSTIN',
                    ENDPOINT_URL,
                    'POST',
                    requestJson,
                    res.getBody(),
                    res.getStatus(),
                    res.getStatusCode(),
                    functionalMessage,
                    'Surepass Functional Error',
                    null,
                    requestDateTime,
                    System.now(),
                    startTime
                );

                if (apiResponse == null) {
                    apiResponse =
                        new GSTINResponse();

                    apiResponse.success =
                        false;

                    apiResponse.message =
                        functionalMessage;
                }

                return apiResponse;
            }

            if (
                apiResponse.data != null &&
                String.isBlank(
                    apiResponse.data.gstin
                )
            ) {
                apiResponse.data.gstin =
                    idNumber;
            }

            return apiResponse;

        } catch (Exception e) {
            createSurepassFailureLog(
                accountId,
                'verifyGSTIN',
                ENDPOINT_URL,
                'POST',
                requestJson,
                null,
                'Callout Exception',
                500,
                e.getMessage(),
                e.getTypeName(),
                e,
                requestDateTime,
                System.now(),
                startTime
            );

            GSTINResponse excRes =
                new GSTINResponse();

            excRes.success = false;
            excRes.message =
                'Something went wrong while verifying GSTIN.';

            return excRes;
        }
    }

    /*
     * Main method used by the LWC.
     *
     * The browser does not decide whether to update directly or
     * create approval. Apex checks the latest Account values.
     */
    @AuraEnabled(cacheable=false)
    public static GSTINProcessResult
        processGSTINUpdateAndTracking(
            Id accountId,
            String responseJson,
            String proposedAccountName,
            String matchReason,
            Boolean requestApproval
        ) {
        if (accountId == null) {
            throw new AuraHandledException(
                'Account Id is required.'
            );
        }

        try {
            GSTINResponse responseObj =
                parseGSTINResponse(
                    responseJson
                );

            GSTINData gstData =
                responseObj.data;

            Account acc =
                getAccount(
                    accountId
                );

            validateCommonUpdateRules(
                acc,
                gstData
            );

            /*
             * GST follows the approved GSTIN decision matrix:
             *
             * DIRECT  -> PAN matches, GSTIN Active, and eligible name
             *            matches exactly.
             * REVIEW  -> PAN matches, GSTIN Active, and the name is
             *            similar / approval-worthy.
             * BLOCKED -> clear customer-name mismatch.
             *
             * BC Customer No. and previous KYC method do not convert a
             * hard mismatch into an approval.
             */
            GSTNameEvaluation nameEvaluation =
                evaluateGSTName(
                    acc.Name,
                    gstData
                );

            String verifiedAccountName =
                nameEvaluation.proposedName;

            Boolean isNameChanged =
                isAccountNameChanged(
                    acc.Name,
                    verifiedAccountName
                );

            Boolean isGstinChanged =
                cleanGSTIN(
                    acc.GST__c
                ) !=
                cleanGSTIN(
                    gstData.gstin
                );

            /*
             * Verified Lock:
             * once Name or GSTIN has already been verified, a different
             * value cannot be updated and cannot be sent for approval.
             */
            validateVerifiedGSTFieldLocks(
                acc,
                isNameChanged,
                isGstinChanged
            );

            if (
                nameEvaluation.outcome ==
                GST_NAME_BLOCKED
            ) {
                throw new AuraHandledException(
                    nameEvaluation.message
                );
            }

            GSTINProcessResult result =
                new GSTINProcessResult();

            if (
                nameEvaluation.outcome ==
                GST_NAME_DIRECT
            ) {
                updateAccountDirectly(
                    acc,
                    gstData,
                    verifiedAccountName,
                    isNameChanged
                );

                result.accountUpdated =
                    true;
                result.approvalCreated =
                    false;
                result.noChanges =
                    !isNameChanged &&
                    !isGstinChanged;

                result.message =
                    result.noChanges
                        ? 'GSTIN verification completed successfully. The Account values already matched.'
                        : 'Account updated successfully with the verified GSTIN details.';

                return result;
            }

            /*
             * REVIEW is the only GST scenario that creates approval.
             * The full changed GST KYC set moves together atomically.
             */
            String approvalId =
                createApprovalTrackingInternal(
                    accountId,
                    acc,
                    gstData,
                    verifiedAccountName,
                    String.isNotBlank(
                        matchReason
                    )
                        ? matchReason
                        : nameEvaluation.message
                );

            result.accountUpdated =
                false;
            result.approvalCreated =
                true;
            result.noChanges =
                false;
            result.approvalRecordId =
                approvalId;

            result.message =
                'GSTIN details require review and were submitted for Customer Profile approval. The Account remains unchanged until approval is completed.';

            return result;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error processing GSTIN changes: ' +
                e.getMessage()
            );
        }
    }


    /*
     * Retained for compatibility with any other existing caller.
     * Direct update eligibility is now enforced here as well.
     */
    @AuraEnabled(cacheable=false)
    public static String updateAccountGSTIN(
        Id accountId,
        String responseJson
    ) {
        if (accountId == null) {
            throw new AuraHandledException(
                'Account Id is required.'
            );
        }

        try {
            GSTINResponse responseObj =
                parseGSTINResponse(
                    responseJson
                );

            GSTINData gstData =
                responseObj.data;

            Account acc =
                getAccount(
                    accountId
                );

            validateCommonUpdateRules(
                acc,
                gstData
            );

            GSTNameEvaluation nameEvaluation =
                evaluateGSTName(
                    acc.Name,
                    gstData
                );

            String verifiedAccountName =
                nameEvaluation.proposedName;

            Boolean isNameChanged =
                isAccountNameChanged(
                    acc.Name,
                    verifiedAccountName
                );

            Boolean isGstinChanged =
                cleanGSTIN(
                    acc.GST__c
                ) !=
                cleanGSTIN(
                    gstData.gstin
                );

            validateVerifiedGSTFieldLocks(
                acc,
                isNameChanged,
                isGstinChanged
            );

            if (
                nameEvaluation.outcome ==
                GST_NAME_BLOCKED
            ) {
                throw new AuraHandledException(
                    nameEvaluation.message
                );
            }

            if (
                nameEvaluation.outcome ==
                GST_NAME_REVIEW
            ) {
                throw new AuraHandledException(
                    'The verified GSTIN name requires approval review. Direct update is not allowed.'
                );
            }

            updateAccountDirectly(
                acc,
                gstData,
                verifiedAccountName,
                isNameChanged
            );

            return 'UPDATED';

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error updating Account: ' +
                e.getMessage()
            );
        }
    }


    /*
     * Retained for compatibility with any existing caller.
     */
    @AuraEnabled(cacheable=false)
    public static String createGSTINApprovalTracking(
        Id accountId,
        String responseJson,
        String proposedAccountName,
        String matchReason
    ) {
        if (accountId == null) {
            throw new AuraHandledException(
                'Account Id is required.'
            );
        }

        try {
            GSTINResponse responseObj =
                parseGSTINResponse(
                    responseJson
                );

            GSTINData gstData =
                responseObj.data;

            Account acc =
                getAccount(
                    accountId
                );

            validateCommonUpdateRules(
                acc,
                gstData
            );

            GSTNameEvaluation nameEvaluation =
                evaluateGSTName(
                    acc.Name,
                    gstData
                );

            String verifiedAccountName =
                nameEvaluation.proposedName;

            Boolean isNameChanged =
                isAccountNameChanged(
                    acc.Name,
                    verifiedAccountName
                );

            Boolean isGstinChanged =
                cleanGSTIN(
                    acc.GST__c
                ) !=
                cleanGSTIN(
                    gstData.gstin
                );

            validateVerifiedGSTFieldLocks(
                acc,
                isNameChanged,
                isGstinChanged
            );

            if (
                nameEvaluation.outcome ==
                GST_NAME_BLOCKED
            ) {
                throw new AuraHandledException(
                    nameEvaluation.message
                );
            }

            if (
                nameEvaluation.outcome !=
                GST_NAME_REVIEW
            ) {
                return 'APPROVAL_NOT_REQUIRED';
            }

            return createApprovalTrackingInternal(
                accountId,
                acc,
                gstData,
                verifiedAccountName,
                String.isNotBlank(
                    matchReason
                )
                    ? matchReason
                    : nameEvaluation.message
            );

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error creating approval request: ' +
                e.getMessage()
            );
        }
    }

    @TestVisible
    private static Id createSurepassFailureLog(
        Id accountId,
        String methodName,
        String endpoint,
        String httpMethod,
        String requestJson,
        String responseBody,
        String responseStatus,
        Integer statusCode,
        String errorMessage,
        String exceptionType,
        Exception exceptionRecord,
        Datetime requestDateTime,
        Datetime responseDateTime,
        Long startTime
    ) {
        try {
            Integration_Result__c logRecord =
                new Integration_Result__c();

            logRecord.Apex_Class_Name__c =
                'ctrl_SurepassGSTINController';

            logRecord.Method_Name__c =
                methodName;

            logRecord.API_Type__c =
                'Surepass GSTIN API';

            logRecord.Endpoint__c =
                truncateLogValue(
                    endpoint,
                    255
                );

            logRecord.Request_JSON__c =
                truncateLogValue(
                    requestJson,
                    131072
                );

            logRecord.Request_Headers__c =
                JSON.serialize(
                    new Map<String, Object>{
                        'Content-Type' => 'application/json',
                        'Accept' => 'application/json'
                    }
                );

            logRecord.Response_Body__c =
                truncateLogValue(
                    responseBody,
                    131072
                );

            logRecord.Response_Status__c =
                truncateLogValue(
                    responseStatus,
                    255
                );

            logRecord.Status_Code__c =
                statusCode;

            logRecord.Error_Message__c =
                truncateLogValue(
                    errorMessage,
                    32768
                );

            logRecord.Exception_Type__c =
                truncateLogValue(
                    exceptionType,
                    255
                );

            logRecord.Request_Date_Time__c =
                requestDateTime == null
                    ? System.now()
                    : requestDateTime;

            logRecord.Response_Date_Time__c =
                responseDateTime == null
                    ? System.now()
                    : responseDateTime;

            if (startTime != null) {
                logRecord.Duration_Milliseconds__c =
                    logRecord.Response_Date_Time__c.getTime() -
                    startTime;
            }

            logRecord.Attempt_Number__c =
                1;

            logRecord.Is_Retry__c =
                false;

            logRecord.Success__c =
                false;

            if (accountId != null) {
                logRecord.Related_Object_API__c =
                    'Account';

                logRecord.Related_Record_Id__c =
                    String.valueOf(
                        accountId
                    );
            }

            String correlationId =
                extractCorrelationId(
                    responseBody
                );

            if (String.isBlank(correlationId)) {
                correlationId =
                    extractCorrelationId(
                        errorMessage
                    );
            }

            logRecord.Correlation_Id__c =
                truncateLogValue(
                    correlationId,
                    255
                );

            if (exceptionRecord != null) {
                logRecord.Line_Number__c =
                    exceptionRecord.getLineNumber();

                logRecord.Stack_Trace__c =
                    truncateLogValue(
                        exceptionRecord.getStackTraceString(),
                        131072
                    );
            }

            putActiveIntegrationPicklistValue(
                logRecord,
                'HTTP_Method__c',
                new List<String>{
                    httpMethod
                }
            );

            putActiveIntegrationPicklistValue(
                logRecord,
                'Log_Status__c',
                new List<String>{
                    'Failed',
                    'Error',
                    'Failure'
                }
            );

            insert logRecord;

            return logRecord.Id;
        } catch (Exception loggingException) {
            System.debug(
                LoggingLevel.ERROR,
                'Unable to create GSTIN Integration_Result__c: ' +
                loggingException.getMessage()
            );

            return null;
        }
    }

    @TestVisible
    private static void putActiveIntegrationPicklistValue(
        SObject recordValue,
        String fieldApi,
        List<String> preferredValues
    ) {
        if (
            recordValue == null ||
            String.isBlank(fieldApi) ||
            preferredValues == null ||
            preferredValues.isEmpty()
        ) {
            return;
        }

        Map<String, Schema.SObjectField> fieldMap =
            recordValue
                .getSObjectType()
                .getDescribe()
                .fields
                .getMap();

        if (!fieldMap.containsKey(fieldApi)) {
            return;
        }

        Schema.DescribeFieldResult fieldDescribe =
            fieldMap.get(fieldApi).getDescribe();

        if (
            fieldDescribe.getType() !=
            Schema.DisplayType.Picklist
        ) {
            return;
        }

        for (String preferredValue : preferredValues) {
            if (String.isBlank(preferredValue)) {
                continue;
            }

            for (
                Schema.PicklistEntry entry :
                fieldDescribe.getPicklistValues()
            ) {
                if (
                    entry.isActive() &&
                    entry.getValue() ==
                        preferredValue
                ) {
                    recordValue.put(
                        fieldApi,
                        preferredValue
                    );
                    return;
                }
            }
        }
    }

    @TestVisible
    private static String extractCorrelationId(
        String sourceText
    ) {
        if (String.isBlank(sourceText)) {
            return null;
        }

        try {
            Pattern correlationPattern =
                Pattern.compile(
                    '(?i)(CorrelationId|correlation_id|correlationId)[^A-Za-z0-9\\-]+([A-Za-z0-9\\-]+)'
                );

            Matcher correlationMatcher =
                correlationPattern.matcher(
                    sourceText
                );

            if (correlationMatcher.find()) {
                return correlationMatcher.group(2);
            }
        } catch (Exception ignoreException) {
            // Optional diagnostic field only.
        }

        return null;
    }

    @TestVisible
    private static String truncateLogValue(
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

        return value.length() > maxLength
            ? value.substring(
                0,
                maxLength
            )
            : value;
    }

    @TestVisible
    private static void updateAccountDirectly(
        Account existingAccount,
        GSTINData gstData,
        String verifiedAccountName,
        Boolean isNameChanged
    ) {
        Account accToUpdate =
            new Account(
                Id = existingAccount.Id
            );

        accToUpdate.GST__c =
            gstData.gstin
                .trim()
                .toUpperCase();

        if (
            isNameChanged &&
            String.isNotBlank(
                verifiedAccountName
            )
        ) {
            accToUpdate.Name =
                verifiedAccountName.trim();
        }

        putIfFieldUpdateable(
            accToUpdate,
            'GST_Verified__c',
            true
        );

        putIfFieldUpdateable(
            accToUpdate,
            'GSTIN_Verified__c',
            true
        );

        putIfFieldUpdateable(
            accToUpdate,
            'Name_Verified__c',
            true
        );

        /*
         * GSTIN verification does not verify DOB.
         * DOB_Verified__c is intentionally not modified.
         */

        if (
            String.isBlank(
                existingAccount
                    .Customer_Verification_KYC__c
            )
        ) {
            accToUpdate
                .Customer_Verification_KYC__c =
                'GST';
        }

        update as user accToUpdate;
    }

    @TestVisible
    private static String
        createApprovalTrackingInternal(
            Id accountId,
            Account acc,
            GSTINData gstData,
            String verifiedAccountName,
            String matchReason
        ) {
        Boolean isNameChanged =
            isAccountNameChanged(
                acc.Name,
                verifiedAccountName
            );

        Boolean isGstinChanged =
            cleanGSTIN(acc.GST__c) !=
            cleanGSTIN(gstData.gstin);

        Map<String, Object> approvalChanges =
            new Map<String, Object>();

        if (
            isNameChanged &&
            String.isNotBlank(
                verifiedAccountName
            )
        ) {
            approvalChanges.put(
                'Name',
                verifiedAccountName.trim()
            );
        }

        /*
         * Once approval is required, every changed GST KYC field moves
         * together. Unchanged fields are not manufactured as approval
         * items.
         */
        if (isGstinChanged) {
            approvalChanges.put(
                'GST__c',
                gstData.gstin.trim().toUpperCase()
            );
        }

        if (approvalChanges.isEmpty()) {
            throw new AuraHandledException(
                'No different GSTIN values were found for creating a Customer Profile approval request.'
            );
        }

        String verificationDetail =
            String.isNotBlank(
                matchReason
            )
                ? matchReason.trim()
                : 'PAN matches and GSTIN is Active, but the Customer Name requires approval review under the GSTIN name-matching rules.';

        Ctrl_OrientCustomerProfileChange.SubmitResult
            approvalSubmission =
                Ctrl_OrientCustomerProfileChange.submitKycProfileChanges(
                        accountId,
                        JSON.serialize(
                            approvalChanges
                        ),
                        'GST',
                        verificationDetail
                    );

        return approvalSubmission == null ||
            approvalSubmission.approvalTransactionId == null
                ? null
                : String.valueOf(
                    approvalSubmission.approvalTransactionId
                );
    }

    @TestVisible
    private static Boolean isDifferentVerificationMethod(
        String existingMethod,
        String currentMethod
    ) {
        String normalizedExisting =
            normalizeVerificationMethod(existingMethod);

        String normalizedCurrent =
            normalizeVerificationMethod(currentMethod);

        return (
            String.isNotBlank(normalizedExisting) &&
            normalizedExisting != normalizedCurrent
        );
    }

    @TestVisible
    private static String normalizeVerificationMethod(
        String value
    ) {
        if (String.isBlank(value)) {
            return '';
        }

        String normalized =
            value.replaceAll('[^A-Za-z0-9]', '')
                .toUpperCase();

        if (normalized == 'GSTIN' || normalized == 'GST') {
            return 'GST';
        }

        if (
            normalized == 'VOTER' ||
            normalized == 'VOTERID'
        ) {
            return 'VOTERID';
        }

        return normalized;
    }

    @TestVisible
    private static Account getAccount(
        Id accountId
    ) {
        return [
            SELECT Id,
                   Name,
                   PAN__c,
                   GST__c,
                   Name_Verified__c,
                   GSTIN_Verified__c,
                   Status__c,
                   BC_Customer_No__c,
                   Customer_Verification_KYC__c
            FROM Account
            WHERE Id = :accountId
            WITH USER_MODE
            LIMIT 1
            FOR UPDATE
        ];
    }

    @TestVisible
    private static GSTINResponse
        parseGSTINResponse(
            String responseJson
        ) {
        if (String.isBlank(responseJson)) {
            throw new AuraHandledException(
                'GSTIN response data is required.'
            );
        }

        GSTINResponse responseObj =
            (GSTINResponse) JSON.deserialize(
                responseJson,
                GSTINResponse.class
            );

        if (
            responseObj == null ||
            responseObj.data == null
        ) {
            throw new AuraHandledException(
                'No GSTIN data found.'
            );
        }

        if (
            String.isBlank(
                responseObj.data.gstin
            )
        ) {
            throw new AuraHandledException(
                'GSTIN number was not found in the verified response.'
            );
        }

        return responseObj;
    }

    @TestVisible
    private static void validateCommonUpdateRules(
        Account acc,
        GSTINData gstData
    ) {
        if (String.isBlank(acc.PAN__c)) {
            throw new AuraHandledException(
                'PAN is not available in the Customer Profile.'
            );
        }

        String gstinPan =
            getPANFromGSTINData(gstData);

        if (String.isBlank(gstinPan)) {
            throw new AuraHandledException(
                'PAN could not be identified from the verified GSTIN details.'
            );
        }

        if (
            cleanPAN(acc.PAN__c) !=
            cleanPAN(gstinPan)
        ) {
            throw new AuraHandledException(
                'The PAN in the Customer Profile does not match the PAN contained in the provided GSTIN.'
            );
        }

        if (
            !isActiveGSTIN(
                gstData.gstin_status
            )
        ) {
            throw new AuraHandledException(
                'Only Active GSTINs are allowed for update.'
            );
        }
    }

    /*
     * Server-side GST name decision.
     *
     * This intentionally mirrors the approved GSTIN functional rule:
     * - Proprietorship: Account Name may exactly match Legal or Business Name.
     * - Other constitutions: direct match requires Legal Name.
     * - Similar / approval-worthy name -> REVIEW.
     * - Clearly unrelated name -> BLOCKED.
     */
    @TestVisible
    private static GSTNameEvaluation evaluateGSTName(
        String currentAccountName,
        GSTINData gstData
    ) {
        GSTNameEvaluation evaluation =
            new GSTNameEvaluation();

        String legalName =
            gstData == null
                ? null
                : gstData.legal_name;

        String businessName =
            gstData == null
                ? null
                : gstData.business_name;

        Boolean proprietorship =
            gstData != null &&
            isProprietorship(
                gstData.constitution_of_business
            );

        Boolean legalExactMatch =
            String.isNotBlank(legalName) &&
            cleanExactName(
                currentAccountName
            ) ==
            cleanExactName(
                legalName
            );

        Boolean businessExactMatch =
            String.isNotBlank(businessName) &&
            cleanExactName(
                currentAccountName
            ) ==
            cleanExactName(
                businessName
            );

        if (
            legalExactMatch ||
            (
                proprietorship &&
                businessExactMatch
            )
        ) {
            evaluation.outcome =
                GST_NAME_DIRECT;

            evaluation.proposedName =
                legalExactMatch
                    ? legalName
                    : businessName;

            evaluation.message =
                legalExactMatch
                    ? 'The Customer Name matches the GSTIN Legal Name.'
                    : 'The Customer Name matches the GSTIN Business Name for a proprietorship.';

            return evaluation;
        }

        Boolean legalSimilar =
            areNamesSimilar(
                currentAccountName,
                legalName
            );

        Boolean businessSimilar =
            areNamesSimilar(
                currentAccountName,
                businessName
            );

        if (
            legalSimilar ||
            businessSimilar
        ) {
            evaluation.outcome =
                GST_NAME_REVIEW;

            /*
             * For non-proprietorship records Legal Name remains the
             * authoritative proposed Account Name even when the Business
             * Name is what made the record review-worthy.
             */
            if (proprietorship) {
                evaluation.proposedName =
                    legalSimilar &&
                    String.isNotBlank(
                        legalName
                    )
                        ? legalName
                        : businessName;
            } else {
                evaluation.proposedName =
                    String.isNotBlank(
                        legalName
                    )
                        ? legalName
                        : businessName;
            }

            evaluation.message =
                'PAN matches and GSTIN is Active, but the Customer Name is only a possible match. Approval review is required.';

            return evaluation;
        }

        evaluation.outcome =
            GST_NAME_BLOCKED;

        evaluation.proposedName =
            String.isNotBlank(
                legalName
            )
                ? legalName
                : businessName;

        evaluation.message =
            'The Customer Name is clearly different from the verified GSTIN name. ' +
            'This GSTIN verification is blocked. No Account update or approval request was created.';

        return evaluation;
    }

    @TestVisible
    private static void validateVerifiedGSTFieldLocks(
        Account acc,
        Boolean isNameChanged,
        Boolean isGstinChanged
    ) {
        if (acc == null) {
            return;
        }

        List<String> verifiedLockedConflicts =
            new List<String>();

        if (
            acc.Name_Verified__c == true &&
            isNameChanged
        ) {
            verifiedLockedConflicts.add(
                'Customer Name'
            );
        }

        if (
            acc.GSTIN_Verified__c == true &&
            isGstinChanged
        ) {
            verifiedLockedConflicts.add(
                'GSTIN'
            );
        }

        if (!verifiedLockedConflicts.isEmpty()) {
            throw new AuraHandledException(
                'The following Customer field(s) are already KYC verified and cannot be changed through GSTIN verification: ' +
                String.join(
                    verifiedLockedConflicts,
                    ', '
                ) +
                '. No Account update or approval request was created.'
            );
        }
    }

    @TestVisible
    private static Boolean areNamesSimilar(
        String nameOne,
        String nameTwo
    ) {
        String firstName =
            normalizeLooseName(
                nameOne
            );

        String secondName =
            normalizeLooseName(
                nameTwo
            );

        if (
            String.isBlank(firstName) ||
            String.isBlank(secondName)
        ) {
            return false;
        }

        if (firstName == secondName) {
            return true;
        }

        if (
            firstName.length() >= 4 &&
            secondName.length() >= 4 &&
            (
                firstName.contains(
                    secondName
                ) ||
                secondName.contains(
                    firstName
                )
            )
        ) {
            return true;
        }

        List<String> firstTokens =
            firstName.split('\\s+');

        List<String> secondTokens =
            secondName.split('\\s+');

        Set<String> secondTokenSet =
            new Set<String>(
                secondTokens
            );

        Integer commonCount =
            0;

        for (
            String token :
            firstTokens
        ) {
            if (
                String.isNotBlank(token) &&
                secondTokenSet.contains(
                    token
                )
            ) {
                commonCount++;
            }
        }

        Integer maxTokenCount =
            Math.max(
                firstTokens.size(),
                secondTokens.size()
            );

        return (
            commonCount >= 2 ||
            (
                maxTokenCount > 0 &&
                Decimal.valueOf(
                    String.valueOf(
                        commonCount
                    )
                ) /
                Decimal.valueOf(
                    String.valueOf(
                        maxTokenCount
                    )
                ) >=
                0.6
            )
        );
    }

    @TestVisible
    private static String normalizeLooseName(
        String value
    ) {
        String normalized =
            cleanExactName(
                value
            );

        if (String.isBlank(normalized)) {
            return '';
        }

        normalized =
            normalized.replaceAll(
                '\\b(MR|MRS|SHRI|SMT|SRI)\\b',
                ' '
            );

        normalized =
            normalized.replaceAll(
                '\\b(PRIVATE|LIMITED|COMPANY|LLP|LLC|INC|INDIA|THE)\\b',
                ' '
            );

        return normalized
            .replaceAll(
                '\\s+',
                ' '
            )
            .trim();
    }

    @TestVisible
    private static String resolveProposedAccountName(
        String currentAccountName,
        GSTINData gstData,
        String requestedProposedName
    ) {
        if (gstData == null) {
            return null;
        }

        String legalName =
            gstData.legal_name;

        String businessName =
            gstData.business_name;

        Boolean proprietorship =
            isProprietorship(
                gstData
                    .constitution_of_business
            );

        /*
         * Only accept the frontend-proposed value if it is one of
         * the actual verified names.
         */
        if (
            String.isNotBlank(
                requestedProposedName
            )
        ) {
            if (
                String.isNotBlank(legalName) &&
                cleanExactName(
                    requestedProposedName
                ) ==
                cleanExactName(legalName)
            ) {
                return legalName;
            }

            if (
                proprietorship &&
                String.isNotBlank(
                    businessName
                ) &&
                cleanExactName(
                    requestedProposedName
                ) ==
                cleanExactName(
                    businessName
                )
            ) {
                return businessName;
            }
        }

        if (proprietorship) {
            if (
                String.isNotBlank(legalName) &&
                cleanExactName(
                    currentAccountName
                ) ==
                cleanExactName(legalName)
            ) {
                return legalName;
            }

            if (
                String.isNotBlank(
                    businessName
                ) &&
                cleanExactName(
                    currentAccountName
                ) ==
                cleanExactName(
                    businessName
                )
            ) {
                return businessName;
            }

            return String.isNotBlank(legalName)
                ? legalName
                : businessName;
        }

        return String.isNotBlank(legalName)
            ? legalName
            : businessName;
    }

    @TestVisible
    private static Boolean
        isAccountNameChanged(
            String oldName,
            String verifiedName
        ) {
        if (String.isBlank(verifiedName)) {
            return false;
        }

        return (
            cleanExactName(oldName) !=
            cleanExactName(verifiedName)
        );
    }

    @TestVisible
    private static String getPANFromGSTINData(
        GSTINData gstData
    ) {
        if (gstData == null) {
            return null;
        }

        if (
            String.isNotBlank(
                gstData.pan_number
            )
        ) {
            return gstData.pan_number;
        }

        if (
            String.isNotBlank(
                gstData.gstin
            ) &&
            gstData.gstin.length() == 15
        ) {
            return gstData.gstin.substring(
                2,
                12
            );
        }

        return null;
    }

    @TestVisible
    private static Boolean isProprietorship(
        String constitution
    ) {
        return (
            String.isNotBlank(constitution) &&
            constitution
                .toLowerCase()
                .contains('proprietor')
        );
    }

    @TestVisible
    private static Boolean isActiveGSTIN(
        String status
    ) {
        return (
            String.isNotBlank(status) &&
            status
                .trim()
                .equalsIgnoreCase('active')
        );
    }

    @TestVisible
    private static String cleanPAN(
        String value
    ) {
        return String.isBlank(value)
            ? ''
            : value.trim().toUpperCase();
    }

    @TestVisible
    private static String cleanGSTIN(
        String value
    ) {
        return String.isBlank(value)
            ? ''
            : value.trim().toUpperCase();
    }

    @TestVisible
    private static String cleanExactName(
        String value
    ) {
        if (String.isBlank(value)) {
            return '';
        }

        String name =
            value.toUpperCase();

        name = name.replace(
            '&',
            ' AND '
        );

        name = name.replaceAll(
            '[^A-Z0-9\\s]',
            ' '
        );

        name = name
            .replaceAll('\\s+', ' ')
            .trim();

        name = name.replaceAll(
            '^(M\\s*S|MS|MESSRS|MESSERS)\\s+',
            ''
        );

        name = name.replaceAll(
            '\\bL\\s+L\\s+P\\b',
            'LLP'
        );

        name = name.replaceAll(
            '\\bLIMITED\\s+LIABILITY\\s+PARTNERSHIP\\b',
            'LLP'
        );

        name = name.replaceAll(
            '\\bPVT\\b',
            'PRIVATE'
        );

        name = name.replaceAll(
            '\\bLTD\\b',
            'LIMITED'
        );

        name = name.replaceAll(
            '\\bC\\s+O\\b',
            'COMPANY'
        );

        name = name.replaceAll(
            '\\bCO\\b',
            'COMPANY'
        );

        return name
            .replaceAll('\\s+', ' ')
            .trim();
    }

    @TestVisible
    private static Boolean putIfFieldExists(
        SObject recordValue,
        String fieldApiName,
        Object value
    ) {
        if (
            recordValue == null ||
            String.isBlank(fieldApiName)
        ) {
            return false;
        }

        Map<String, Schema.SObjectField> fieldMap =
            recordValue
                .getSObjectType()
                .getDescribe()
                .fields
                .getMap();

        if (!fieldMap.containsKey(fieldApiName)) {
            return false;
        }

        recordValue.put(
            fieldApiName,
            value
        );

        return true;
    }

    @TestVisible
    private static Boolean putIfFieldUpdateable(
        SObject recordValue,
        String fieldApiName,
        Object value
    ) {
        if (
            recordValue == null ||
            String.isBlank(fieldApiName)
        ) {
            return false;
        }

        Map<String, Schema.SObjectField> fieldMap =
            recordValue
                .getSObjectType()
                .getDescribe()
                .fields
                .getMap();

        if (!fieldMap.containsKey(fieldApiName)) {
            return false;
        }

        Schema.DescribeFieldResult fieldDescribe =
            fieldMap
                .get(fieldApiName)
                .getDescribe();

        if (!fieldDescribe.isUpdateable()) {
            return false;
        }

        recordValue.put(
            fieldApiName,
            value
        );

        return true;
    }

    @TestVisible
    private static String buildSummaryRow(
        String fieldLabel,
        Object oldValue,
        Object newValue
    ) {
        String row = '<tr>';

        row +=
            '<td><b>' +
            escapeHtml(fieldLabel) +
            '</b></td>';

        row +=
            '<td>' +
            htmlValue(oldValue) +
            '</td>';

        row +=
            '<td style="color: green; font-weight: bold;">' +
            htmlValue(newValue) +
            '</td>';

        row += '</tr>';

        return row;
    }

    @TestVisible
    private static String buildInfoRow(
        String label,
        Object value
    ) {
        String row = '<tr>';

        row +=
            '<td><b>' +
            escapeHtml(label) +
            '</b></td>';

        row +=
            '<td>' +
            htmlValue(value) +
            '</td>';

        row += '</tr>';

        return row;
    }

    @TestVisible
    private static String htmlValue(
        Object value
    ) {
        if (
            value == null ||
            String.isBlank(
                String.valueOf(value)
            )
        ) {
            return '<i>Blank</i>';
        }

        return escapeHtml(
            String.valueOf(value)
        );
    }

    @TestVisible
    private static String escapeHtml(
        String value
    ) {
        return String.isBlank(value)
            ? ''
            : value.escapeHtml4();
    }

    @TestVisible
    private static String formatDateForDisplay(
        String value
    ) {
        if (String.isBlank(value)) {
            return '';
        }

        String cleanValue =
            value.trim();

        try {
            if (
                (
                    cleanValue.contains('T') ||
                    cleanValue.contains(' ')
                ) &&
                cleanValue.length() >= 10
            ) {
                cleanValue =
                    cleanValue.substring(0, 10);
            }

            if (
                Pattern.matches(
                    '\\d{2}/\\d{2}/\\d{4}',
                    cleanValue
                )
            ) {
                return cleanValue;
            }

            if (
                Pattern.matches(
                    '\\d{4}-\\d{2}-\\d{2}',
                    cleanValue
                )
            ) {
                List<String> parts =
                    cleanValue.split('-');

                return (
                    parts[2] +
                    '/' +
                    parts[1] +
                    '/' +
                    parts[0]
                );
            }

            if (
                Pattern.matches(
                    '\\d{2}-\\d{2}-\\d{4}',
                    cleanValue
                )
            ) {
                return cleanValue.replace(
                    '-',
                    '/'
                );
            }

            if (
                Pattern.matches(
                    '\\d{4}/\\d{2}/\\d{2}',
                    cleanValue
                )
            ) {
                List<String> parts =
                    cleanValue.split('/');

                return (
                    parts[2] +
                    '/' +
                    parts[1] +
                    '/' +
                    parts[0]
                );
            }
        } catch (Exception e) {
            return value;
        }

        return value;
    }

    public class GSTINProcessResult {
        @AuraEnabled public Boolean accountUpdated;
        @AuraEnabled public Boolean approvalCreated;
        @AuraEnabled public Boolean noChanges;
        @AuraEnabled public String approvalRecordId;
        @AuraEnabled public String message;
    }

    public class GSTINResponse {
        @AuraEnabled public GSTINData data {
            get;
            set;
        }

        @AuraEnabled public Integer status_code {
            get;
            set;
        }

        @AuraEnabled public Boolean success {
            get;
            set;
        }

        @AuraEnabled public String message {
            get;
            set;
        }

        @AuraEnabled public String message_code {
            get;
            set;
        }
    }

    public class GSTINData {
        @AuraEnabled public Boolean einvoice_status {
            get;
            set;
        }

        @AuraEnabled public String client_id {
            get;
            set;
        }

        @AuraEnabled public String gstin {
            get;
            set;
        }

        @AuraEnabled public String pan_number {
            get;
            set;
        }

        @AuraEnabled public String fy {
            get;
            set;
        }

        @AuraEnabled public String business_name {
            get;
            set;
        }

        @AuraEnabled public String legal_name {
            get;
            set;
        }

        @AuraEnabled public String center_jurisdiction {
            get;
            set;
        }

        @AuraEnabled public String state_jurisdiction {
            get;
            set;
        }

        @AuraEnabled public String date_of_registration {
            get;
            set;
        }

        @AuraEnabled public String constitution_of_business {
            get;
            set;
        }

        @AuraEnabled public String taxpayer_type {
            get;
            set;
        }

        @AuraEnabled public String gstin_status {
            get;
            set;
        }

        @AuraEnabled public String date_of_cancellation {
            get;
            set;
        }

        @AuraEnabled public String field_visit_conducted {
            get;
            set;
        }

        @AuraEnabled public List<String> nature_bus_activities {
            get;
            set;
        }

        @AuraEnabled public String nature_of_core_business_activity_code {
            get;
            set;
        }

        @AuraEnabled public String nature_of_core_business_activity_description {
            get;
            set;
        }

        @AuraEnabled public String aadhaar_validation {
            get;
            set;
        }

        @AuraEnabled public String aadhaar_validation_date {
            get;
            set;
        }

        @AuraEnabled public String address {
            get;
            set;
        }
    }
}