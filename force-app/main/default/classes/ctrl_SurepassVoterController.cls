public with sharing class ctrl_SurepassVoterController {

    private static final String ENDPOINT_URL =
        System.Label.Surepass_Endpoint + '/api/v1/voter-id/voter-id';

    private static final String ACCOUNT_VOTER_FIELD = 'Voter__c';

    private static final String ACCOUNT_VOTER_VERIFIED_FIELD = 'Voter_Verified__c';

    private static final String ACCOUNT_STATUS_FIELD = 'Status__c';

    private static final String ACCOUNT_GENDER_FIELD = 'Gender__c';

    private static final String ACCOUNT_NAME_VERIFIED_FIELD =
        'Name_Verified__c';

    private static final String ACCOUNT_GENDER_VERIFIED_FIELD =
        'Gender_Verified__c';

    /*
     * The exact field used by PAN is included first.
     * Remaining candidates are retained to avoid breaking orgs
     * where a different BC field API name is being used.
     */
    private static final List<String> BC_CUSTOMER_FIELD_CANDIDATES =
        new List<String>{
            'BC_Customer_No__c',
            'BC_Customer_Id__c',
            'BC_Customer_ID__c',
            'BC_Customer_Number__c',
            'Business_Central_Customer_Id__c',
            'Business_Central_Customer_ID__c',
            'Customer_Code__c',
            'Customer_Id__c',
            'Customer_ID__c'
        };

    @AuraEnabled(cacheable=true)
    public static AccountInitWrapper getAccountDefaults(
        Id recordId
    ) {
        AccountInitWrapper wrapperObj =
            new AccountInitWrapper();

        if (recordId == null) {
            return wrapperObj;
        }

        ensureAccountFieldExists(
            ACCOUNT_VOTER_FIELD
        );

        String bcCustomerField =
            getBcCustomerIdField();

        Set<String> fieldSet = new Set<String>{
            'Id',
            'Name',
            ACCOUNT_VOTER_FIELD,
            'Customer_Verification_KYC__c'
        };

        if (accountFieldExists(ACCOUNT_STATUS_FIELD)) {
            fieldSet.add(ACCOUNT_STATUS_FIELD);
        }

        if (accountFieldExists(ACCOUNT_GENDER_FIELD)) {
            fieldSet.add(ACCOUNT_GENDER_FIELD);
        }

        if (
            accountFieldExists(
                ACCOUNT_NAME_VERIFIED_FIELD
            )
        ) {
            fieldSet.add(
                ACCOUNT_NAME_VERIFIED_FIELD
            );
        }

        if (
            accountFieldExists(
                ACCOUNT_GENDER_VERIFIED_FIELD
            )
        ) {
            fieldSet.add(
                ACCOUNT_GENDER_VERIFIED_FIELD
            );
        }

        if (
            accountFieldExists(
                ACCOUNT_VOTER_VERIFIED_FIELD
            )
        ) {
            fieldSet.add(
                ACCOUNT_VOTER_VERIFIED_FIELD
            );
        }

        if (String.isNotBlank(bcCustomerField)) {
            fieldSet.add(bcCustomerField);
        }

        String query =
            'SELECT ' +
            String.join(
                new List<String>(fieldSet),
                ', '
            ) +
            ' FROM Account ' +
            'WHERE Id = :recordId ' +
            'LIMIT 1';

        Account acc = Database.query(query);

        wrapperObj.accountId = acc.Id;
        wrapperObj.accountName = acc.Name;

        wrapperObj.accountGender =
            getSObjectValueAsString(
                acc,
                ACCOUNT_GENDER_FIELD
            );

        wrapperObj.voterValue =
            getSObjectValueAsString(
                acc,
                ACCOUNT_VOTER_FIELD
            );

        wrapperObj.accountStatus =
            getSObjectValueAsString(
                acc,
                ACCOUNT_STATUS_FIELD
            );

        wrapperObj.bcCustomerId =
            String.isNotBlank(bcCustomerField)
                ? getSObjectValueAsString(
                    acc,
                    bcCustomerField
                )
                : '';

        wrapperObj.bcCustomerFieldFound =
            String.isNotBlank(bcCustomerField);

        wrapperObj.customerVerificationKyc =
            getSObjectValueAsString(
                acc,
                'Customer_Verification_KYC__c'
            );

        wrapperObj.nameVerified =
            getSObjectBooleanValue(
                acc,
                ACCOUNT_NAME_VERIFIED_FIELD
            );

        wrapperObj.genderVerified =
            getSObjectBooleanValue(
                acc,
                ACCOUNT_GENDER_VERIFIED_FIELD
            );

        wrapperObj.voterVerified =
            getSObjectBooleanValue(
                acc,
                ACCOUNT_VOTER_VERIFIED_FIELD
            );

        wrapperObj.differentVerificationMethod =
            isDifferentVerificationMethod(
                wrapperObj.customerVerificationKyc,
                'Voter ID'
            );

        /*
         * Initial UI hint only. Account Status is intentionally ignored.
         * The final action is recalculated after field comparison and
         * again in processAccountUpdateAndTracking().
         */
        wrapperObj.directUpdateAllowed =
            isDirectUpdateAllowed(
                wrapperObj.accountStatus,
                wrapperObj.bcCustomerId,
                wrapperObj.bcCustomerFieldFound,
                wrapperObj.customerVerificationKyc
            );

        return wrapperObj;
    }

    @AuraEnabled(cacheable=false)
    public static VoterResponse verifyVoter(
        String voterNumber,
        Id recordId
    ) {
        VoterResponse result =
            new VoterResponse();

        String requestJson;
        Datetime requestDateTime;
        Long startTime;

        try {
            String cleanVoterNumber =
                cleanVoterNumber(voterNumber);

            String tokenValue =
                getBearerToken();

            Map<String, Object> requestBody =
                new Map<String, Object>{
                    'id_number' => cleanVoterNumber
                };

            HttpRequest req = new HttpRequest();

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
                tokenValue
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
            HttpResponse res = http.send(req);

            result.httpStatusCode =
                res.getStatusCode();

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
                    recordId,
                    'verifyVoter',
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

                result.success = false;
                result.message = cleanMessage;

                return result;
            }

            Map<String, Object> parsedResponse =
                (Map<String, Object>)
                    JSON.deserializeUntyped(
                        res.getBody()
                    );

            result.statusCode =
                getString(
                    parsedResponse,
                    'status_code'
                );

            result.messageCode =
                getString(
                    parsedResponse,
                    'message_code'
                );

            Boolean apiSuccess =
                getBoolean(
                    parsedResponse,
                    'success'
                );

            Object dataObj =
                parsedResponse.get('data');

            if (!apiSuccess || dataObj == null) {
                result.success = false;

                result.message =
                    String.isBlank(
                        getString(
                            parsedResponse,
                            'message'
                        )
                    )
                        ? 'Voter details not found.'
                        : getString(
                            parsedResponse,
                            'message'
                        );

                createSurepassFailureLog(
                    recordId,
                    'verifyVoter',
                    ENDPOINT_URL,
                    'POST',
                    requestJson,
                    res.getBody(),
                    res.getStatus(),
                    res.getStatusCode(),
                    result.message,
                    'Surepass Functional Error',
                    null,
                    requestDateTime,
                    System.now(),
                    startTime
                );

                return result;
            }

            Map<String, Object> dataMap =
                (Map<String, Object>) dataObj;

            result.success = true;

            result.message =
                'Voter details fetched successfully from Surepass.';

            result.clientId =
                getString(dataMap, 'client_id');

            result.inputVoterId =
                getString(dataMap, 'input_voter_id');

            result.epicNo =
                getString(dataMap, 'epic_no');

            if (String.isBlank(result.epicNo)) {
                result.epicNo =
                    cleanVoterNumber;
            }

            result.gender =
                getString(dataMap, 'gender');

            result.state =
                getString(dataMap, 'state');

            result.name =
                getString(dataMap, 'name');

            result.relationName =
                getString(dataMap, 'relation_name');

            result.relationType =
                getString(dataMap, 'relation_type');

            result.houseNo =
                getString(dataMap, 'house_no');

            result.age =
                getString(dataMap, 'age');

            result.area =
                getString(dataMap, 'area');

            result.district =
                getString(dataMap, 'district');

            result.multiple =
                getBoolean(dataMap, 'multiple');

            result.lastUpdate =
                getString(dataMap, 'last_update');

            result.assemblyConstituency =
                getString(
                    dataMap,
                    'assembly_constituency'
                );

            result.assemblyConstituencyNumber =
                getString(
                    dataMap,
                    'assembly_constituency_number'
                );

            result.pollingStation =
                getString(
                    dataMap,
                    'polling_station'
                );

            result.partNumber =
                getString(
                    dataMap,
                    'part_number'
                );

            result.partName =
                getString(
                    dataMap,
                    'part_name'
                );

            result.slnoInpart =
                getString(
                    dataMap,
                    'slno_inpart'
                );

            result.psLatLong =
                getString(
                    dataMap,
                    'ps_lat_long'
                );

            result.sectionNo =
                getString(
                    dataMap,
                    'section_no'
                );

            result.rlnNameV1 =
                getString(dataMap, 'rln_name_v1');

            result.rlnNameV2 =
                getString(dataMap, 'rln_name_v2');

            result.rlnNameV3 =
                getString(dataMap, 'rln_name_v3');

            result.nameV1 =
                getString(dataMap, 'name_v1');

            result.nameV2 =
                getString(dataMap, 'name_v2');

            result.nameV3 =
                getString(dataMap, 'name_v3');

            result.parliamentaryName =
                getString(
                    dataMap,
                    'parliamentary_name'
                );

            result.parliamentaryNumber =
                getString(
                    dataMap,
                    'parliamentary_number'
                );

            result.parliamentaryConstituency =
                getString(
                    dataMap,
                    'parliamentary_constituency'
                );

            result.stCode =
                getString(dataMap, 'st_code');

            result.voterRecordId =
                getString(dataMap, 'id');

            return result;

        } catch (AuraHandledException e) {
            result.success = false;
            result.message = e.getMessage();
            return result;
        } catch (Exception e) {
            createSurepassFailureLog(
                recordId,
                'verifyVoter',
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

            result.success = false;
            result.message =
                'Something went wrong while verifying Voter ID.';

            return result;
        }
    }

    @AuraEnabled(cacheable=false)
    public static UpdateResultWrapper processAccountUpdateAndTracking(
        Id recordId,
        String responseJson,
        Boolean trackName
    ) {
        if (recordId == null) {
            throw new AuraHandledException(
                'Account Id is missing.'
            );
        }

        if (String.isBlank(responseJson)) {
            throw new AuraHandledException(
                'Voter response data is required.'
            );
        }

        try {
            VoterResponse responseObj =
                (VoterResponse) JSON.deserialize(
                    responseJson,
                    VoterResponse.class
                );

            if (responseObj == null) {
                throw new AuraHandledException(
                    'Invalid Voter response data.'
                );
            }

            if (String.isBlank(responseObj.epicNo)) {
                throw new AuraHandledException(
                    'Voter / EPIC number was not found in the verified response.'
                );
            }

            String bcCustomerField =
                getBcCustomerIdField();

            Boolean bcCustomerFieldFound =
                String.isNotBlank(
                    bcCustomerField
                );

            Set<String> fieldSet =
                new Set<String>{
                    'Id',
                    'Name',
                    ACCOUNT_VOTER_FIELD,
                    'Customer_Verification_KYC__c'
                };

            if (
                accountFieldExists(
                    ACCOUNT_STATUS_FIELD
                )
            ) {
                fieldSet.add(
                    ACCOUNT_STATUS_FIELD
                );
            }

            if (
                accountFieldExists(
                    ACCOUNT_GENDER_FIELD
                )
            ) {
                fieldSet.add(
                    ACCOUNT_GENDER_FIELD
                );
            }

            if (
                accountFieldExists(
                    ACCOUNT_NAME_VERIFIED_FIELD
                )
            ) {
                fieldSet.add(
                    ACCOUNT_NAME_VERIFIED_FIELD
                );
            }

            if (
                accountFieldExists(
                    ACCOUNT_GENDER_VERIFIED_FIELD
                )
            ) {
                fieldSet.add(
                    ACCOUNT_GENDER_VERIFIED_FIELD
                );
            }

            if (
                accountFieldExists(
                    ACCOUNT_VOTER_VERIFIED_FIELD
                )
            ) {
                fieldSet.add(
                    ACCOUNT_VOTER_VERIFIED_FIELD
                );
            }

            if (bcCustomerFieldFound) {
                fieldSet.add(
                    bcCustomerField
                );
            }

            String query =
                'SELECT ' +
                String.join(
                    new List<String>(fieldSet),
                    ', '
                ) +
                ' FROM Account ' +
                'WHERE Id = :recordId ' +
                'LIMIT 1 ' +
                'FOR UPDATE';

            Account acc =
                Database.query(query);

            /*
             * Point 8: once the Voter / EPIC field itself has already
             * completed KYC verification, Voter verification becomes
             * read-only. Do not update and do not create approval.
             */
            if (
                getSObjectBooleanValue(
                    acc,
                    ACCOUNT_VOTER_VERIFIED_FIELD
                ) == true
            ) {
                UpdateResultWrapper alreadyVerifiedResult =
                    new UpdateResultWrapper();

                alreadyVerifiedResult.accountUpdated =
                    false;
                alreadyVerifiedResult.approvalCreated =
                    false;
                alreadyVerifiedResult.noChanges =
                    true;
                alreadyVerifiedResult.message =
                    'Voter / EPIC details are already KYC verified. No Account update or approval request is allowed.';

                return alreadyVerifiedResult;
            }

            String currentVoter =
                getSObjectValueAsString(
                    acc,
                    ACCOUNT_VOTER_FIELD
                );

            String currentGender =
                getSObjectValueAsString(
                    acc,
                    ACCOUNT_GENDER_FIELD
                );

            String bcCustomerId =
                bcCustomerFieldFound
                    ? getSObjectValueAsString(
                        acc,
                        bcCustomerField
                    )
                    : '';

            String formattedGender =
                resolveGenderValue(
                    responseObj.gender
                );

            Boolean isNameChanged =
                String.isNotBlank(responseObj.name) &&
                cleanExactName(acc.Name) !=
                cleanExactName(responseObj.name);

            Boolean isVoterChanged =
                normalizeVoterNumber(currentVoter) !=
                normalizeVoterNumber(
                    responseObj.epicNo
                );

            Boolean isGenderChanged =
                String.isNotBlank(formattedGender) &&
                normalizeGender(currentGender) !=
                normalizeGender(
                    formattedGender
                );

            /*
             * Verified Lock rule.
             *
             * A Voter verification cannot overwrite a value that was
             * already verified by PAN, Voter or another KYC source.
             * Such a mismatch is blocked completely: no direct update
             * and no approval request.
             */
            List<String> verifiedLockedConflicts =
                new List<String>();

            if (
                getSObjectBooleanValue(
                    acc,
                    ACCOUNT_NAME_VERIFIED_FIELD
                ) == true &&
                isNameChanged
            ) {
                verifiedLockedConflicts.add(
                    'Customer Name'
                );
            }

            if (
                getSObjectBooleanValue(
                    acc,
                    ACCOUNT_GENDER_VERIFIED_FIELD
                ) == true &&
                isGenderChanged
            ) {
                verifiedLockedConflicts.add(
                    'Gender'
                );
            }

            if (
                getSObjectBooleanValue(
                    acc,
                    ACCOUNT_VOTER_VERIFIED_FIELD
                ) == true &&
                isVoterChanged
            ) {
                verifiedLockedConflicts.add(
                    'Voter / EPIC Number'
                );
            }

            if (!verifiedLockedConflicts.isEmpty()) {
                throw new AuraHandledException(
                    'The following Customer field(s) are already KYC verified and cannot be changed through Voter verification: ' +
                    String.join(
                        verifiedLockedConflicts,
                        ', '
                    ) +
                    '. No Account update or approval request was created.'
                );
            }

            /*
             * Blank Account values may be filled directly. A conflict
             * exists only when both the Account value and the verified
             * value are populated but different.
             */
            Boolean isNameConflict =
                String.isNotBlank(acc.Name) &&
                String.isNotBlank(responseObj.name) &&
                isNameChanged;

            Boolean isVoterConflict =
                String.isNotBlank(currentVoter) &&
                isVoterChanged;

            Boolean isGenderConflict =
                String.isNotBlank(currentGender) &&
                String.isNotBlank(formattedGender) &&
                isGenderChanged;

            Boolean hasAnyChanges =
                isNameChanged ||
                isVoterChanged ||
                isGenderChanged;

            Boolean hasAnyConflict =
                isNameConflict ||
                isVoterConflict ||
                isGenderConflict;

            Boolean differentVerificationMethod =
                isDifferentVerificationMethod(
                    acc.Customer_Verification_KYC__c,
                    'Voter ID'
                );

            Boolean hasBcCustomerNumber =
                String.isNotBlank(
                    bcCustomerId
                );

            /*
             * Account Status is never checked.
             *
             * BC blank:
             * - first/same Voter KYC can update;
             * - after another KYC, only populated conflicting values
             *   require approval.
             *
             * BC available:
             * - populated conflicting values require approval;
             * - matching values and blank fields update directly.
             */
            Boolean approvalRequired =
                hasAnyChanges &&
                hasAnyConflict &&
                (
                    hasBcCustomerNumber ||
                    differentVerificationMethod
                );

            UpdateResultWrapper result =
                new UpdateResultWrapper();

            /*
             * trackName is retained for backward compatibility only.
             * Apex independently makes the final decision.
             */
            if (!approvalRequired) {
                updateAccountVoterDirectly(
                    recordId,
                    acc,
                    responseObj,
                    formattedGender
                );

                result.accountUpdated = true;
                result.approvalCreated = false;
                result.noChanges = !hasAnyChanges;

                result.message =
                    hasAnyChanges
                        ? 'Account Voter details updated successfully.'
                        : 'Voter verification completed successfully. The Account values already matched.';

                return result;
            }

            Ctrl_OrientCustomerProfileChange.SubmitResult
                approvalSubmission =
                    createVoterApprovalTracking(
                        recordId,
                        acc,
                        responseObj,
                        formattedGender,
                        differentVerificationMethod,
                        hasBcCustomerNumber
                    );

            result.accountUpdated = false;
            result.approvalCreated = true;
            result.noChanges = false;

            result.message =
                approvalSubmission != null &&
                String.isNotBlank(
                    approvalSubmission.message
                )
                    ? approvalSubmission.message
                    : 'Voter ID changes submitted for Customer Profile approval successfully.';

            return result;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error processing Voter update: ' +
                e.getMessage()
            );
        }
    }

    private static void updateAccountVoterDirectly(
        Id recordId,
        Account acc,
        VoterResponse responseObj,
        String formattedGender
    ) {
        Schema.DescribeFieldResult voterFieldDescribe =
            getAccountFieldDescribe(
                ACCOUNT_VOTER_FIELD
            );

        if (!voterFieldDescribe.isUpdateable()) {
            throw new AuraHandledException(
                'You do not have permission to update the Account Voter field.'
            );
        }

        Account accToUpdate =
            new Account(Id = recordId);

        accToUpdate.put(
            ACCOUNT_VOTER_FIELD,
            responseObj.epicNo.trim().toUpperCase()
        );

        if (String.isNotBlank(responseObj.name)) {
            accToUpdate.Name =
                responseObj.name.trim();
        }

        if (String.isNotBlank(formattedGender)) {
            putIfFieldUpdateable(
                accToUpdate,
                ACCOUNT_GENDER_FIELD,
                formattedGender
            );
        }

        putIfFieldUpdateable(
            accToUpdate,
            ACCOUNT_VOTER_VERIFIED_FIELD,
            true
        );

        putIfFieldUpdateable(
            accToUpdate,
            'Voter_ID_Verified__c',
            true
        );

        putIfFieldUpdateable(
            accToUpdate,
            'Voter_Verified__c',
            true
        );

        putIfFieldUpdateable(
            accToUpdate,
            'Voter_Verification_Done__c',
            true
        );

        putIfFieldUpdateable(
            accToUpdate,
            'Name_Verified__c',
            true
        );

        putIfFieldUpdateable(
            accToUpdate,
            'Gender_Verified__c',
            true
        );

        if (
            String.isBlank(
                acc.Customer_Verification_KYC__c
            )
        ) {
            accToUpdate.Customer_Verification_KYC__c =
                'Voter ID';
        }

        update as user accToUpdate;
    }

    private static Ctrl_OrientCustomerProfileChange.SubmitResult
        createVoterApprovalTracking(
            Id recordId,
            Account acc,
            VoterResponse responseObj,
            String formattedGender,
            Boolean differentVerificationMethod,
            Boolean hasBcCustomerNumber
        ) {
        String currentVoter =
            getSObjectValueAsString(
                acc,
                ACCOUNT_VOTER_FIELD
            );

        String currentGender =
            getSObjectValueAsString(
                acc,
                ACCOUNT_GENDER_FIELD
            );

        Boolean isNameChanged =
            String.isNotBlank(responseObj.name) &&
            cleanExactName(acc.Name) !=
            cleanExactName(responseObj.name);

        Boolean isVoterChanged =
            normalizeVoterNumber(currentVoter) !=
            normalizeVoterNumber(
                responseObj.epicNo
            );

        Boolean isGenderChanged =
            String.isNotBlank(formattedGender) &&
            normalizeGender(currentGender) !=
            normalizeGender(formattedGender);

        Map<String, Object> approvalChanges =
            new Map<String, Object>();

        if (isNameChanged) {
            approvalChanges.put(
                'Name',
                responseObj.name.trim()
            );
        }

        if (isVoterChanged) {
            approvalChanges.put(
                'Voter__c',
                responseObj.epicNo.trim().toUpperCase()
            );
        }

        if (isGenderChanged) {
            approvalChanges.put(
                'Gender__c',
                formattedGender
            );
        }

        if (approvalChanges.isEmpty()) {
            throw new AuraHandledException(
                'No different Voter values were found for creating a Customer Profile approval request.'
            );
        }

        String verificationDetail =
            hasBcCustomerNumber == true
                ? 'The customer already has a BC Customer No. and one or more populated Customer Profile values conflict with the verified Voter ID response.'
                : 'Another KYC method was completed earlier and one or more populated Customer Profile values conflict with the verified Voter ID response.';

        return Ctrl_OrientCustomerProfileChange.submitKycProfileChanges(
                recordId,
                JSON.serialize(
                    approvalChanges
                ),
                'Voter ID',
                verificationDetail
            );
    }

    private static Boolean isDirectUpdateAllowed(
        String accountStatus,
        String bcCustomerId,
        Boolean bcCustomerFieldFound,
        String existingVerificationMethod
    ) {
        if (bcCustomerFieldFound != true) {
            return false;
        }

        /*
         * Initial UI hint only. Account Status is intentionally ignored.
         * The final routing is based on BC Customer No., existing KYC and
         * actual field conflicts after verification.
         */
        return (
            String.isBlank(bcCustomerId) &&
            !isDifferentVerificationMethod(
                existingVerificationMethod,
                'Voter ID'
            )
        );
    }

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
                'ctrl_SurepassVoterController';

            logRecord.Method_Name__c =
                methodName;

            logRecord.API_Type__c =
                'Surepass Voter API';

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
                'Unable to create Voter Integration_Result__c: ' +
                loggingException.getMessage()
            );

            return null;
        }
    }

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

    private static String getBearerToken() {
        String tokenValue =
            System.Label.Surepass_API_Key;

        if (
            String.isBlank(tokenValue) &&
            Test.isRunningTest()
        ) {
            tokenValue = 'test-token';
        }

        if (String.isBlank(tokenValue)) {
            throw new AuraHandledException(
                'Surepass API key is missing.'
            );
        }

        tokenValue = tokenValue.trim();

        if (
            !tokenValue
                .toLowerCase()
                .startsWith('bearer ')
        ) {
            tokenValue =
                'Bearer ' + tokenValue;
        }

        return tokenValue;
    }

    private static String cleanVoterNumber(
        String voterNumber
    ) {
        if (String.isBlank(voterNumber)) {
            throw new AuraHandledException(
                'Please enter Voter / EPIC number.'
            );
        }

        String cleanValue =
            voterNumber
                .trim()
                .toUpperCase();

        if (
            !Pattern.matches(
                '^[A-Z0-9]{6,20}$',
                cleanValue
            )
        ) {
            throw new AuraHandledException(
                'Please enter a valid Voter / EPIC number.'
            );
        }

        return cleanValue;
    }

    private static String normalizeVoterNumber(
        String voterNumber
    ) {
        return String.isBlank(voterNumber)
            ? ''
            : voterNumber
                .trim()
                .toUpperCase();
    }

    private static Boolean accountFieldExists(
        String fieldApiName
    ) {
        if (String.isBlank(fieldApiName)) {
            return false;
        }

        return Schema.SObjectType.Account
            .fields
            .getMap()
            .containsKey(fieldApiName);
    }

    private static void ensureAccountFieldExists(
        String fieldApiName
    ) {
        if (!accountFieldExists(fieldApiName)) {
            throw new AuraHandledException(
                'Account field not found: ' +
                fieldApiName
            );
        }
    }

    private static String getBcCustomerIdField() {
        Map<String, Schema.SObjectField> fieldMap =
            Schema.SObjectType.Account
                .fields
                .getMap();

        for (
            String fieldApiName :
            BC_CUSTOMER_FIELD_CANDIDATES
        ) {
            if (fieldMap.containsKey(fieldApiName)) {
                return fieldApiName;
            }
        }

        return null;
    }

    private static Schema.DescribeFieldResult
        getAccountFieldDescribe(
            String fieldApiName
        ) {
        ensureAccountFieldExists(
            fieldApiName
        );

        return Schema.SObjectType.Account
            .fields
            .getMap()
            .get(fieldApiName)
            .getDescribe();
    }

    private static String getSObjectValueAsString(
        SObject recordObj,
        String fieldApiName
    ) {
        if (
            recordObj == null ||
            String.isBlank(fieldApiName)
        ) {
            return '';
        }

        Map<String, Schema.SObjectField> fieldMap =
            recordObj
                .getSObjectType()
                .getDescribe()
                .fields
                .getMap();

        if (!fieldMap.containsKey(fieldApiName)) {
            return '';
        }

        try {
            Object valueObj =
                recordObj.get(fieldApiName);

            return valueObj == null
                ? ''
                : String.valueOf(valueObj);
        } catch (Exception e) {
            return '';
        }
    }

    private static Boolean getSObjectBooleanValue(
        SObject recordObj,
        String fieldApiName
    ) {
        if (
            recordObj == null ||
            String.isBlank(fieldApiName)
        ) {
            return false;
        }

        Map<String, Schema.SObjectField> fieldMap =
            recordObj
                .getSObjectType()
                .getDescribe()
                .fields
                .getMap();

        if (!fieldMap.containsKey(fieldApiName)) {
            return false;
        }

        try {
            Object valueObj =
                recordObj.get(fieldApiName);

            if (valueObj instanceof Boolean) {
                return (Boolean) valueObj;
            }

            return valueObj != null &&
                String.valueOf(valueObj)
                    .equalsIgnoreCase('true');
        } catch (Exception e) {
            return false;
        }
    }

    private static String getString(
        Map<String, Object> sourceMap,
        String keyName
    ) {
        if (
            sourceMap == null ||
            !sourceMap.containsKey(keyName) ||
            sourceMap.get(keyName) == null
        ) {
            return '';
        }

        return String.valueOf(
            sourceMap.get(keyName)
        );
    }

    private static Boolean getBoolean(
        Map<String, Object> sourceMap,
        String keyName
    ) {
        if (
            sourceMap == null ||
            !sourceMap.containsKey(keyName) ||
            sourceMap.get(keyName) == null
        ) {
            return false;
        }

        Object valueObj =
            sourceMap.get(keyName);

        if (valueObj instanceof Boolean) {
            return (Boolean) valueObj;
        }

        return String.valueOf(valueObj)
            .equalsIgnoreCase('true');
    }

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
            '\\bMR\\b',
            ''
        );

        name = name.replaceAll(
            '\\bMRS\\b',
            ''
        );

        name = name.replaceAll(
            '\\bSHRI\\b',
            ''
        );

        name = name.replaceAll(
            '\\bSMT\\b',
            ''
        );

        name = name.replaceAll(
            '\\bSRI\\b',
            ''
        );

        name = name
            .replaceAll('\\s+', ' ')
            .trim();

        return name;
    }

    private static String normalizeGender(
        String value
    ) {
        if (String.isBlank(value)) {
            return '';
        }

        String genderValue =
            value
                .trim()
                .toLowerCase();

        if (
            genderValue == 'm' ||
            genderValue == 'male'
        ) {
            return 'male';
        }

        if (
            genderValue == 'f' ||
            genderValue == 'female'
        ) {
            return 'female';
        }

        if (
            genderValue == 't' ||
            genderValue == 'trans' ||
            genderValue == 'transgender'
        ) {
            return 'transgender';
        }

        if (
            genderValue == 'o' ||
            genderValue == 'other' ||
            genderValue == 'others'
        ) {
            return 'other';
        }

        return genderValue;
    }

    private static String formatGenderForDisplay(
        String value
    ) {
        String normalizedValue =
            normalizeGender(value);

        if (normalizedValue == 'male') {
            return 'Male';
        }

        if (normalizedValue == 'female') {
            return 'Female';
        }

        if (
            normalizedValue == 'transgender'
        ) {
            return 'Transgender';
        }

        if (normalizedValue == 'other') {
            return 'Other';
        }

        return String.isBlank(value)
            ? ''
            : value.trim();
    }

    private static String resolveGenderValue(
        String rawGender
    ) {
        if (String.isBlank(rawGender)) {
            return null;
        }

        String cleanGender =
            rawGender.trim();

        String normalizedApiGender =
            normalizeGender(cleanGender);

        Schema.SObjectField genderField =
            Schema.SObjectType.Account
                .fields
                .getMap()
                .get(ACCOUNT_GENDER_FIELD);

        if (genderField == null) {
            return cleanGender;
        }

        Schema.DescribeFieldResult genderDescribe =
            genderField.getDescribe();

        if (
            genderDescribe.getType() ==
                Schema.DisplayType.Picklist ||
            genderDescribe.getType() ==
                Schema.DisplayType.MultiPicklist
        ) {
            for (
                Schema.PicklistEntry entry :
                genderDescribe.getPicklistValues()
            ) {
                if (!entry.isActive()) {
                    continue;
                }

                Boolean valueMatches =
                    normalizeGender(
                        entry.getValue()
                    ) ==
                    normalizedApiGender;

                Boolean labelMatches =
                    normalizeGender(
                        entry.getLabel()
                    ) ==
                    normalizedApiGender;

                if (
                    valueMatches ||
                    labelMatches
                ) {
                    return entry.getValue();
                }
            }
        }

        return cleanGender;
    }

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

        if (fieldMap.containsKey(fieldApiName)) {
            recordValue.put(
                fieldApiName,
                value
            );

            return true;
        }

        return false;
    }

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

    private static String escapeHtml(
        String value
    ) {
        return String.isBlank(value)
            ? ''
            : value.escapeHtml4();
    }

    private static String formatDateForDisplay(
        String value
    ) {
        if (String.isBlank(value)) {
            return '';
        }

        String cleanValue =
            value.trim();

        try {
            /*
             * Remove an ISO or space-separated time portion.
             */
            if (
                cleanValue.contains('T') &&
                cleanValue.length() >= 10
            ) {
                cleanValue =
                    cleanValue.substring(0, 10);
            } else if (
                cleanValue.contains(' ') &&
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

    public class AccountInitWrapper {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String accountGender;
        @AuraEnabled public String voterValue;
        @AuraEnabled public String accountStatus;
        @AuraEnabled public String bcCustomerId;
        @AuraEnabled public Boolean bcCustomerFieldFound;
        @AuraEnabled public String customerVerificationKyc;
        @AuraEnabled public Boolean nameVerified;
        @AuraEnabled public Boolean genderVerified;
        @AuraEnabled public Boolean voterVerified;
        @AuraEnabled public Boolean differentVerificationMethod;
        @AuraEnabled public Boolean directUpdateAllowed;
    }

    public class UpdateResultWrapper {
        @AuraEnabled public Boolean accountUpdated;
        @AuraEnabled public Boolean approvalCreated;
        @AuraEnabled public Boolean noChanges;
        @AuraEnabled public String message;
    }

    public class VoterResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Integer httpStatusCode;
        @AuraEnabled public String statusCode;
        @AuraEnabled public String messageCode;

        @AuraEnabled public String clientId;
        @AuraEnabled public String inputVoterId;
        @AuraEnabled public String epicNo;
        @AuraEnabled public String gender;
        @AuraEnabled public String state;
        @AuraEnabled public String name;
        @AuraEnabled public String relationName;
        @AuraEnabled public String relationType;
        @AuraEnabled public String houseNo;
        @AuraEnabled public String age;
        @AuraEnabled public String area;
        @AuraEnabled public String district;
        @AuraEnabled public Boolean multiple;
        @AuraEnabled public String lastUpdate;

        @AuraEnabled public String assemblyConstituency;
        @AuraEnabled public String assemblyConstituencyNumber;
        @AuraEnabled public String pollingStation;
        @AuraEnabled public String partNumber;
        @AuraEnabled public String partName;
        @AuraEnabled public String slnoInpart;
        @AuraEnabled public String psLatLong;
        @AuraEnabled public String sectionNo;

        @AuraEnabled public String rlnNameV1;
        @AuraEnabled public String rlnNameV2;
        @AuraEnabled public String rlnNameV3;
        @AuraEnabled public String nameV1;
        @AuraEnabled public String nameV2;
        @AuraEnabled public String nameV3;
        @AuraEnabled public String parliamentaryName;
        @AuraEnabled public String parliamentaryNumber;
        @AuraEnabled public String parliamentaryConstituency;
        @AuraEnabled public String stCode;
        @AuraEnabled public String voterRecordId;
    }
}