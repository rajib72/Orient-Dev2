public with sharing class ctrl_PanVerificationController {

    private static final String PAN_API_URL =
        System.Label.Surepass_Endpoint + '/api/v1/pan/pan-comprehensive';

    @AuraEnabled
    public static AccountInitialDataWrapper getAccountInitialData(
        Id accountId
    ) {
        if (accountId == null) {
            throw new AuraHandledException(
                'Account Id is required.'
            );
        }

        Account acc = [
            SELECT Id,
                   Name,
                   PAN__c,
                   Date_Of_Birth__c,
                   Gender__c,
                   Status__c,
                   BC_Customer_No__c,
                   PAN_Verified__c,
                   Name_Verified__c,
                   DOB_Verified__c,
                   Gender_Verified__c,
                   Customer_Verification_KYC__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        AccountInitialDataWrapper wrap =
            new AccountInitialDataWrapper();

        wrap.accountName = acc.Name;
        wrap.panNumber = acc.PAN__c;
        wrap.dateOfBirth = acc.Date_Of_Birth__c;
        wrap.accountGender = acc.Gender__c;
        wrap.accountStatus = acc.Status__c;
        wrap.bcCustomerNo = acc.BC_Customer_No__c;
        wrap.panVerified = acc.PAN_Verified__c;
        wrap.customerVerificationKyc =
            acc.Customer_Verification_KYC__c;

        wrap.differentVerificationMethod =
            isDifferentVerificationMethod(
                acc.Customer_Verification_KYC__c,
                'PAN'
            );

        /*
         * This value is only an initial UI hint. The final decision is
         * recalculated after verification and again in updateAccountPan().
         * Account Status is intentionally not part of the KYC decision.
         */
        wrap.directUpdateAllowed =
            String.isBlank(acc.BC_Customer_No__c) &&
            !wrap.differentVerificationMethod;

        /*
         * Name, DOB and Gender are allowed to be blank. A verified value
         * may safely fill a blank Account field without approval.
         */
        wrap.canShowComponent = true;
        wrap.validationMessage = '';

        return wrap;
    }

    @AuraEnabled
    public static PanResponseWrapper verifyPan(
        String panNumber
    ) {
        if (String.isBlank(panNumber)) {
            throw new AuraHandledException(
                'Please enter PAN number.'
            );
        }

        panNumber = panNumber.trim().toUpperCase();

        String tokenValue = System.Label.Surepass_API_Key;

        if (String.isBlank(tokenValue)) {
            throw new AuraHandledException(
                'Surepass API Key is missing in Custom Label.'
            );
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(PAN_API_URL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader(
            'Authorization',
            'Bearer ' + tokenValue
        );
        req.setTimeout(120000);

        Map<String, Object> requestBody =
            new Map<String, Object>();

        requestBody.put('id_number', panNumber);

        String requestJson =
            JSON.serialize(
                requestBody
            );

        req.setBody(
            requestJson
        );

        Http http = new Http();
        HttpResponse res;

        try {
            res = http.send(req);
        } catch (Exception e) {
            createPanFailureLog(
                'verifyPan',
                PAN_API_URL,
                'POST',
                requestJson,
                null,
                'Callout Exception',
                0,
                e.getMessage(),
                e
            );

            throw new AuraHandledException(
                'PAN API callout failed: ' + e.getMessage()
            );
        }

        PanResponseWrapper response;

        try {
            response = (PanResponseWrapper) JSON.deserialize(
                res.getBody(),
                PanResponseWrapper.class
            );
        } catch (Exception e) {
            createPanFailureLog(
                'verifyPan',
                PAN_API_URL,
                'POST',
                requestJson,
                res.getBody(),
                res.getStatus(),
                res.getStatusCode(),
                'Unable to parse Surepass PAN response: ' +
                    e.getMessage(),
                e
            );

            throw new AuraHandledException(
                'Error parsing API response.'
            );
        }

        if (
            res.getStatusCode() != 200 ||
            response == null ||
            response.success != true
        ) {
            String errorMsg =
                response != null &&
                String.isNotBlank(response.message)
                    ? response.message
                    : 'PAN verification failed. Please check the details and try again.';

            createPanFailureLog(
                'verifyPan',
                PAN_API_URL,
                'POST',
                requestJson,
                res.getBody(),
                res.getStatus(),
                res.getStatusCode(),
                errorMsg,
                null
            );

            if (response == null) {
                response = new PanResponseWrapper();
                response.success = false;
            }

            response.message = errorMsg;
            return response;
        }

        if (response.data == null) {
            createPanFailureLog(
                'verifyPan',
                PAN_API_URL,
                'POST',
                requestJson,
                res.getBody(),
                res.getStatus(),
                res.getStatusCode(),
                'Success was true but data object was null.',
                null
            );

            response.success = false;
            response.message =
                'PAN details not found in the response.';

            return response;
        }

        return response;
    }

    @AuraEnabled
    public static UpdateResultWrapper updateAccountPan(
        Id accountId,
        String panNumber,
        Boolean createApprovalRecord,
        String newDob,
        String newName,
        String newGender
    ) {
        if (accountId == null) {
            throw new AuraHandledException(
                'Account Id is required.'
            );
        }

        if (String.isBlank(panNumber)) {
            throw new AuraHandledException(
                'PAN number is required.'
            );
        }

        /*
         * The Account is locked and re-read so that Apex always makes
         * the final direct-update versus approval decision from the
         * latest values.
         */
        Account acc = [
            SELECT Id,
                   Name,
                   PAN__c,
                   Date_Of_Birth__c,
                   Gender__c,
                   Status__c,
                   BC_Customer_No__c,
                   PAN_Verified__c,
                   Name_Verified__c,
                   DOB_Verified__c,
                   Gender_Verified__c,
                   Customer_Verification_KYC__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
            FOR UPDATE
        ];

        String formattedPan =
            panNumber.trim().toUpperCase();

        String formattedName =
            String.isNotBlank(newName)
                ? newName.trim()
                : null;

        Date formattedDob = parseDob(newDob);

        String formattedGender =
            resolveGenderValue(newGender);

        Boolean isPanChanged =
            normalizeText(acc.PAN__c) !=
            normalizeText(formattedPan);

        Boolean isNameChanged =
            String.isNotBlank(formattedName) &&
            normalizeText(acc.Name) !=
            normalizeText(formattedName);

        Boolean isDobChanged =
            formattedDob != null &&
            acc.Date_Of_Birth__c != formattedDob;

        Boolean isGenderChanged =
            String.isNotBlank(formattedGender) &&
            normalizeGender(acc.Gender__c) !=
            normalizeGender(formattedGender);

        /*
         * Verified Lock rule.
         *
         * Once a field has been verified by any KYC source, a later KYC
         * response cannot replace that value and cannot send the mismatch
         * for approval. Matching verified values are allowed to continue.
         */
        List<String> verifiedLockedConflicts =
            new List<String>();

        if (
            acc.PAN_Verified__c == true &&
            isPanChanged
        ) {
            verifiedLockedConflicts.add('PAN');
        }

        if (
            acc.Name_Verified__c == true &&
            isNameChanged
        ) {
            verifiedLockedConflicts.add(
                'Customer Name'
            );
        }

        if (
            acc.DOB_Verified__c == true &&
            isDobChanged
        ) {
            verifiedLockedConflicts.add(
                'Date Of Birth'
            );
        }

        if (
            acc.Gender_Verified__c == true &&
            isGenderChanged
        ) {
            verifiedLockedConflicts.add(
                'Gender'
            );
        }

        if (!verifiedLockedConflicts.isEmpty()) {
            throw new AuraHandledException(
                'The following Customer field(s) are already KYC verified and cannot be changed: ' +
                String.join(
                    verifiedLockedConflicts,
                    ', '
                ) +
                '. No Account update or approval request was created.'
            );
        }

        /*
         * A blank Account field is fillable and is not a conflict.
         * Conflict means that both the current Account value and the
         * verified value are populated but they are different.
         */
        Boolean isPanConflict =
            String.isNotBlank(acc.PAN__c) &&
            isPanChanged;

        Boolean isNameConflict =
            String.isNotBlank(acc.Name) &&
            String.isNotBlank(formattedName) &&
            isNameChanged;

        Boolean isDobConflict =
            acc.Date_Of_Birth__c != null &&
            formattedDob != null &&
            isDobChanged;

        Boolean isGenderConflict =
            String.isNotBlank(acc.Gender__c) &&
            String.isNotBlank(formattedGender) &&
            isGenderChanged;

        Boolean hasAnyDataChange =
            isPanChanged ||
            isNameChanged ||
            isDobChanged ||
            isGenderChanged;

        Boolean hasAnyConflict =
            isPanConflict ||
            isNameConflict ||
            isDobConflict ||
            isGenderConflict;

        Boolean differentVerificationMethod =
            isDifferentVerificationMethod(
                acc.Customer_Verification_KYC__c,
                'PAN'
            );

        Boolean hasBcCustomerNumber =
            isBcCustomerNumberPresent(
                acc.BC_Customer_No__c
            );

        /*
         * Final routing rules:
         *
         * 1. Account Status is never checked.
         * 2. When BC Customer No. is blank:
         *    - first PAN verification or PAN re-verification can update;
         *    - after another KYC method, only a populated conflicting
         *      value requires approval. Matching values and blank fields
         *      update directly.
         * 3. When BC Customer No. exists:
         *    - populated conflicting values require approval;
         *    - matching values and blank fields update directly.
         */
        Boolean approvalRequired =
            hasAnyDataChange &&
            hasAnyConflict &&
            (
                hasBcCustomerNumber ||
                differentVerificationMethod
            );

        UpdateResultWrapper result =
            new UpdateResultWrapper();

        /*
         * createApprovalRecord is retained for compatibility only.
         * Apex independently decides the correct action.
         */
        if (!approvalRequired) {
            if (isPanChanged) {
                acc.PAN__c = formattedPan;
            }

            if (
                isNameChanged &&
                String.isNotBlank(formattedName)
            ) {
                acc.Name = formattedName;
            }

            if (
                isDobChanged &&
                formattedDob != null
            ) {
                acc.Date_Of_Birth__c = formattedDob;
            }

            if (
                isGenderChanged &&
                String.isNotBlank(formattedGender)
            ) {
                acc.Gender__c = formattedGender;
            }

            acc.PAN_Verified__c = true;
            acc.Name_Verified__c = true;

            if (formattedDob != null) {
                acc.DOB_Verified__c = true;
            }

            if (String.isNotBlank(formattedGender)) {
                setOptionalBooleanField(
                    acc,
                    'Gender_Verified__c',
                    true
                );
            }

            /*
             * Preserve the first completed KYC method. PAN is stored only
             * when no customer verification method has been recorded yet.
             */
            if (
                String.isBlank(
                    acc.Customer_Verification_KYC__c
                )
            ) {
                acc.Customer_Verification_KYC__c = 'PAN';
            }

            update acc;

            result.accountUpdated = true;
            result.approvalCreated = false;
            result.noChanges = !hasAnyDataChange;
            result.message =
                hasAnyDataChange
                    ? 'Account details updated successfully with the verified PAN information.'
                    : 'PAN verification completed successfully. The Account values already matched.';

            return result;
        }

        /*
         * Approval path.
         *
         * The legacy KYC-specific approval record creation has been removed.
         * The verified values now enter the standard Customer Profile
         * approval architecture.
         */
        Map<String, Object> approvalChanges =
            new Map<String, Object>();

        if (isPanChanged) {
            approvalChanges.put(
                'PAN__c',
                formattedPan
            );
        }

        if (
            isNameChanged &&
            String.isNotBlank(formattedName)
        ) {
            approvalChanges.put(
                'Name',
                formattedName
            );
        }

        if (
            isDobChanged &&
            formattedDob != null
        ) {
            approvalChanges.put(
                'Date_Of_Birth__c',
                formattedDob
            );
        }

        if (
            isGenderChanged &&
            String.isNotBlank(formattedGender)
        ) {
            approvalChanges.put(
                'Gender__c',
                formattedGender
            );
        }

        String verificationDetail =
            hasBcCustomerNumber
                ? 'The customer already has a BC Customer No. and one or more populated Customer Profile values conflict with the verified PAN response.'
                : 'Another KYC method was completed earlier and one or more populated Customer Profile values conflict with the verified PAN response.';

        Ctrl_OrientCustomerProfileChange.SubmitResult
            approvalSubmission =
                Ctrl_OrientCustomerProfileChange.submitKycProfileChanges(
                        accountId,
                        JSON.serialize(
                            approvalChanges
                        ),
                        'PAN',
                        verificationDetail
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
                : 'PAN changes submitted for Customer Profile approval successfully.';

        return result;
    }

    private static Boolean isDirectUpdateAllowed(
        String accountStatus,
        Object bcCustomerNumber,
        String existingVerificationMethod
    ) {
        /*
         * Retained for the initial UI wrapper only. Account Status is
         * intentionally ignored. The final decision is made after field
         * comparison in updateAccountPan().
         */
        return (
            !isBcCustomerNumberPresent(
                bcCustomerNumber
            ) &&
            !isDifferentVerificationMethod(
                existingVerificationMethod,
                'PAN'
            )
        );
    }

    private static Boolean isBcCustomerNumberPresent(
        Object bcCustomerNumber
    ) {
        if (bcCustomerNumber == null) {
            return false;
        }

        return String.isNotBlank(
            String.valueOf(
                bcCustomerNumber
            ).trim()
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

    private static String resolveGenderValue(
        String rawGender
    ) {
        if (String.isBlank(rawGender)) {
            return null;
        }

        String cleanGender = rawGender.trim();
        String normalizedApiGender =
            normalizeGender(cleanGender);

        Schema.SObjectField genderField =
            Schema.SObjectType.Account
                .fields
                .getMap()
                .get('Gender__c');

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
                    normalizeGender(entry.getValue()) ==
                    normalizedApiGender;

                Boolean labelMatches =
                    normalizeGender(entry.getLabel()) ==
                    normalizedApiGender;

                if (valueMatches || labelMatches) {
                    return entry.getValue();
                }
            }
        }

        return cleanGender;
    }

    private static String normalizeGender(
        String input
    ) {
        if (String.isBlank(input)) {
            return '';
        }

        String genderValue =
            input.trim().toLowerCase();

        if (
            genderValue == 'm' ||
            genderValue == 'male'
        ) {
            return 'Male';
        }

        if (
            genderValue == 'f' ||
            genderValue == 'female'
        ) {
            return 'Female';
        }

        if (
            genderValue == 't' ||
            genderValue == 'trans' ||
            genderValue == 'transgender'
        ) {
            return 'Other';
        }

        if (
            genderValue == 'o' ||
            genderValue == 'other' ||
            genderValue == 'others'
        ) {
            return 'Other';
        }

        return genderValue;
    }

    private static void setOptionalBooleanField(
        SObject recordValue,
        String fieldApiName,
        Boolean fieldValue
    ) {
        if (
            recordValue == null ||
            String.isBlank(fieldApiName)
        ) {
            return;
        }

        Map<String, Schema.SObjectField> fieldMap =
            recordValue.getSObjectType()
                .getDescribe()
                .fields
                .getMap();

        if (!fieldMap.containsKey(fieldApiName)) {
            return;
        }

        Schema.DescribeFieldResult fieldDescribe =
            fieldMap.get(fieldApiName).getDescribe();

        if (fieldDescribe.isUpdateable()) {
            recordValue.put(
                fieldApiName,
                fieldValue
            );
        }
    }

    /*
     * Direct PAN/Surepass failure logging.
     * Legacy shared logger dependency is intentionally not used.
     */
    private static void createPanFailureLog(
        String methodName,
        String endpoint,
        String httpMethod,
        String requestJson,
        String responseBody,
        String responseStatus,
        Integer statusCode,
        String errorMessage,
        Exception exceptionValue
    ) {
        try {
            Integration_Result__c logRecord =
                new Integration_Result__c();

            logRecord.Apex_Class_Name__c =
                'ctrl_PanVerificationController';

            logRecord.Method_Name__c =
                truncatePanLogValue(
                    methodName,
                    255
                );

            logRecord.API_Type__c =
                'Surepass PAN';

            logRecord.Endpoint__c =
                truncatePanLogValue(
                    endpoint,
                    255
                );

            logRecord.Request_Date_Time__c =
                System.now();

            logRecord.Response_Date_Time__c =
                System.now();

            logRecord.Request_JSON__c =
                truncatePanLogValue(
                    requestJson,
                    131072
                );

            logRecord.Response_Body__c =
                truncatePanLogValue(
                    responseBody,
                    131072
                );

            logRecord.Response_Status__c =
                truncatePanLogValue(
                    responseStatus,
                    255
                );

            logRecord.Status_Code__c =
                statusCode;

            logRecord.Error_Message__c =
                truncatePanLogValue(
                    errorMessage,
                    32768
                );

            logRecord.Success__c =
                false;

            if (exceptionValue != null) {
                logRecord.Exception_Type__c =
                    truncatePanLogValue(
                        exceptionValue.getTypeName(),
                        255
                    );

                logRecord.Line_Number__c =
                    exceptionValue.getLineNumber();

                logRecord.Stack_Trace__c =
                    truncatePanLogValue(
                        exceptionValue.getStackTraceString(),
                        131072
                    );
            }

            String correlationId =
                extractPanCorrelationId(
                    String.valueOf(
                        responseBody
                    ) +
                    ' ' +
                    String.valueOf(
                        errorMessage
                    )
                );

            if (String.isNotBlank(correlationId)) {
                logRecord.Correlation_Id__c =
                    truncatePanLogValue(
                        correlationId,
                        255
                    );
            }

            putPanActivePicklistValue(
                logRecord,
                'HTTP_Method__c',
                new List<String>{
                    httpMethod
                }
            );

            putPanActivePicklistValue(
                logRecord,
                'Log_Status__c',
                new List<String>{
                    'Failed',
                    'Error',
                    'Failure'
                }
            );

            insert logRecord;
        } catch (Exception loggingException) {
            System.debug(
                LoggingLevel.ERROR,
                'Unable to create PAN Integration_Result__c: ' +
                loggingException.getMessage()
            );
        }
    }

    private static void putPanActivePicklistValue(
        SObject recordValue,
        String fieldApi,
        List<String> preferredValues
    ) {
        if (
            recordValue == null ||
            String.isBlank(fieldApi) ||
            preferredValues == null
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
                    entry.getValue() == preferredValue
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

    private static String extractPanCorrelationId(
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

    private static String truncatePanLogValue(
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

    private static Date parseDob(
        String dobValue
    ) {
        if (String.isBlank(dobValue)) {
            return null;
        }

        String cleanDob = dobValue.trim();

        try {
            // yyyy-mm-dd
            if (
                Pattern.matches(
                    '\\d{4}-\\d{2}-\\d{2}',
                    cleanDob
                )
            ) {
                return Date.valueOf(cleanDob);
            }

            // dd-mm-yyyy
            if (
                Pattern.matches(
                    '\\d{2}-\\d{2}-\\d{4}',
                    cleanDob
                )
            ) {
                List<String> parts =
                    cleanDob.split('-');

                return Date.valueOf(
                    parts[2] +
                    '-' +
                    parts[1] +
                    '-' +
                    parts[0]
                );
            }

            // dd/mm/yyyy
            if (
                Pattern.matches(
                    '\\d{2}/\\d{2}/\\d{4}',
                    cleanDob
                )
            ) {
                List<String> parts =
                    cleanDob.split('/');

                return Date.valueOf(
                    parts[2] +
                    '-' +
                    parts[1] +
                    '-' +
                    parts[0]
                );
            }

            return Date.valueOf(cleanDob);
        } catch (Exception e) {
            createPanFailureLog(
                'parseDob',
                null,
                null,
                dobValue,
                null,
                'Salesforce Validation',
                0,
                'DOB Parse Error: ' +
                    e.getMessage() +
                    ' | DOB Value: ' +
                    dobValue,
                e
            );

            return null;
        }
    }

    private static String normalizeText(
        String input
    ) {
        if (String.isBlank(input)) {
            return '';
        }

        return input
            .trim()
            .toLowerCase()
            .replaceAll('\\s+', ' ');
    }

    private static String getHtmlValue(
        Object value
    ) {
        if (value == null) {
            return '<i>Blank</i>';
        }

        String textValue =
            String.valueOf(value);

        if (String.isBlank(textValue)) {
            return '<i>Blank</i>';
        }

        return textValue.escapeHtml4();
    }

    private static String formatDateForDisplay(Date dateValue) {
        if (dateValue == null) {
            return null;
        }

        String dayValue = String.valueOf(dateValue.day()).leftPad(2, '0');
        String monthValue = String.valueOf(dateValue.month()).leftPad(2, '0');
        String yearValue = String.valueOf(dateValue.year());

        return dayValue + '/' + monthValue + '/' + yearValue;
    }

    public class AccountInitialDataWrapper {
        @AuraEnabled public String accountName;
        @AuraEnabled public String panNumber;
        @AuraEnabled public Date dateOfBirth;
        @AuraEnabled public String accountGender;
        @AuraEnabled public String accountStatus;
        @AuraEnabled public String bcCustomerNo;
        @AuraEnabled public Boolean panVerified;
        @AuraEnabled public String customerVerificationKyc;
        @AuraEnabled public Boolean differentVerificationMethod;
        @AuraEnabled public Boolean directUpdateAllowed;
        @AuraEnabled public Boolean canShowComponent;
        @AuraEnabled public String validationMessage;
    }

    public class UpdateResultWrapper {
        @AuraEnabled public Boolean accountUpdated;
        @AuraEnabled public Boolean approvalCreated;
        @AuraEnabled public Boolean noChanges;
        @AuraEnabled public String message;
    }

    public class PanResponseWrapper {
        @AuraEnabled public PanData data;
        @AuraEnabled public Integer status_code;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String message_code;
    }

    public class PanData {
        @AuraEnabled public String client_id;
        @AuraEnabled public String pan_number;
        @AuraEnabled public String full_name;
        @AuraEnabled public List<String> full_name_split;
        @AuraEnabled public String masked_aadhaar;
        @AuraEnabled public PanAddress address;
        @AuraEnabled public String email;
        @AuraEnabled public String phone_number;
        @AuraEnabled public String gender;
        @AuraEnabled public String dob;
        @AuraEnabled public String input_dob;
        @AuraEnabled public Boolean aadhaar_linked;
        @AuraEnabled public Boolean dob_verified;
        @AuraEnabled public Boolean dob_check;
        @AuraEnabled public String category;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean less_info;
    }

    public class PanAddress {
        @AuraEnabled public String line_1;
        @AuraEnabled public String line_2;
        @AuraEnabled public String street_name;
        @AuraEnabled public String zip;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String country;
        @AuraEnabled public String full;
    }
}