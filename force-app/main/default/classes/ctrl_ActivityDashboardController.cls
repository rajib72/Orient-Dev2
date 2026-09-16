public with sharing class ctrl_ActivityDashboardController {

    private static final String CUSTOMER_OBJECT_API = 'Account';
    private static final String CUSTOMER_STATUS_FIELD_API = 'Status__c';

    private static final String INDIAN_MOBILE_REGEX =
        '^(\\+91)?[6-9][0-9]{9}$';

    private static final List<String> CUSTOMER_PHONE_FIELD_CANDIDATES =
        new List<String>{
            'Phone',
            'Account_Phone__c'
        };

    private static final String CUSTOMER_NAME_FIELD_API = 'Name';
    private static final String DOB_FIELD_API = 'DOB__c';
    private static final String BC_CUSTOMER_NO_FIELD_API = 'BC_Customer_No__c';

    private static final String ADDRESS_LINE_1_FIELD_API = 'Address_Line_1__c';
    private static final String ADDRESS_LINE_2_FIELD_API = 'Address_Line_2__c';
    private static final String VILLAGE_PO_FIELD_API = 'Village_PO__c';
    private static final String RESIDENTIAL_CITY_FIELD_API = 'Residential_City__c';
    private static final String STATE_PROVINCE_FIELD_API = 'State_Province__c';
    private static final String DISTRICT_FIELD_API = 'District__c';
    private static final String PIN_CODE_FIELD_API = 'Pin_Code__c';
    private static final String COUNTRY_FIELD_API = 'Country__c';

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getStores() {
        List<OptionWrapper> options = new List<OptionWrapper>();
        options.add(new OptionWrapper('', 'All Stores'));

        for (Store__c storeRecord : [
            SELECT Id, Name
            FROM Store__c
            ORDER BY Name ASC
            LIMIT 500
        ]) {
            options.add(
                new OptionWrapper(
                    String.valueOf(storeRecord.Id),
                    storeRecord.Name
                )
            );
        }

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<ActivityWrapper> getActivities(
        Date fromDate,
        Date toDate,
        Id storeId,
        String searchKey
    ) {
        String searchText = String.isBlank(searchKey)
            ? null
            : '%' + searchKey.trim() + '%';

        List<Form_Activity__c> activityList;

        if (storeId != null && searchText != null) {
            activityList = [
                SELECT Id,
                       Name,
                       Activity_Date__c,
                       Activity_Location__c,
                       Assigned_Store__c,
                       Assigned_Store__r.Name,
                       Final_Customize_Form__c,
                       Final_Customize_Form__r.Name,
                       Final_Customize_Form__r.Form_Name__c
                FROM Form_Activity__c
                WHERE Activity_Date__c >= :fromDate
                AND Activity_Date__c <= :toDate
                AND Assigned_Store__c = :storeId
                AND (
                    Name LIKE :searchText
                    OR Activity_Location__c LIKE :searchText
                    OR Assigned_Store__r.Name LIKE :searchText
                    OR Final_Customize_Form__r.Name LIKE :searchText
                    OR Final_Customize_Form__r.Form_Name__c LIKE :searchText
                )
                ORDER BY Activity_Date__c DESC, CreatedDate DESC
                LIMIT 1000
            ];
        } else if (storeId != null) {
            activityList = [
                SELECT Id,
                       Name,
                       Activity_Date__c,
                       Activity_Location__c,
                       Assigned_Store__c,
                       Assigned_Store__r.Name,
                       Final_Customize_Form__c,
                       Final_Customize_Form__r.Name,
                       Final_Customize_Form__r.Form_Name__c
                FROM Form_Activity__c
                WHERE Activity_Date__c >= :fromDate
                AND Activity_Date__c <= :toDate
                AND Assigned_Store__c = :storeId
                ORDER BY Activity_Date__c DESC, CreatedDate DESC
                LIMIT 1000
            ];
        } else if (searchText != null) {
            activityList = [
                SELECT Id,
                       Name,
                       Activity_Date__c,
                       Activity_Location__c,
                       Assigned_Store__c,
                       Assigned_Store__r.Name,
                       Final_Customize_Form__c,
                       Final_Customize_Form__r.Name,
                       Final_Customize_Form__r.Form_Name__c
                FROM Form_Activity__c
                WHERE Activity_Date__c >= :fromDate
                AND Activity_Date__c <= :toDate
                AND (
                    Name LIKE :searchText
                    OR Activity_Location__c LIKE :searchText
                    OR Assigned_Store__r.Name LIKE :searchText
                    OR Final_Customize_Form__r.Name LIKE :searchText
                    OR Final_Customize_Form__r.Form_Name__c LIKE :searchText
                )
                ORDER BY Activity_Date__c DESC, CreatedDate DESC
                LIMIT 1000
            ];
        } else {
            activityList = [
                SELECT Id,
                       Name,
                       Activity_Date__c,
                       Activity_Location__c,
                       Assigned_Store__c,
                       Assigned_Store__r.Name,
                       Final_Customize_Form__c,
                       Final_Customize_Form__r.Name,
                       Final_Customize_Form__r.Form_Name__c
                FROM Form_Activity__c
                WHERE Activity_Date__c >= :fromDate
                AND Activity_Date__c <= :toDate
                ORDER BY Activity_Date__c DESC, CreatedDate DESC
                LIMIT 1000
            ];
        }

        List<ActivityWrapper> result = new List<ActivityWrapper>();

        for (Form_Activity__c activityRecord : activityList) {
            ActivityWrapper wrapper = new ActivityWrapper();

            wrapper.activityId = activityRecord.Id;
            wrapper.activityNo = activityRecord.Name;
            wrapper.activityDate = activityRecord.Activity_Date__c;
            wrapper.activityLocation = activityRecord.Activity_Location__c;

            wrapper.storeId = activityRecord.Assigned_Store__c;
            wrapper.storeName = activityRecord.Assigned_Store__r != null
                ? activityRecord.Assigned_Store__r.Name
                : '';

            wrapper.finalCustomizeFormId =
                activityRecord.Final_Customize_Form__c;

            wrapper.finalCustomizeFormNo =
                activityRecord.Final_Customize_Form__r != null
                    ? activityRecord.Final_Customize_Form__r.Name
                    : '';

            wrapper.formName =
                activityRecord.Final_Customize_Form__r != null
                    ? activityRecord.Final_Customize_Form__r.Form_Name__c
                    : '';

            result.add(wrapper);
        }

        return result;
    }

    @AuraEnabled
    public static InteractiveFormWrapper getInteractiveForm(
        Id finalCustomizeFormId
    ) {
        if (finalCustomizeFormId == null) {
            throw new AuraHandledException(
                'Final Customize Form Id is missing.'
            );
        }

        Final_Customize_Form__c formRecord = [
            SELECT Id,
                   Name,
                   Form_Name__c,
                   Active__c
            FROM Final_Customize_Form__c
            WHERE Id = :finalCustomizeFormId
            LIMIT 1
        ];

        InteractiveFormWrapper response = new InteractiveFormWrapper();

        response.formId = formRecord.Id;
        response.formNo = formRecord.Name;
        response.formName = formRecord.Form_Name__c;
        response.active = formRecord.Active__c;
        response.questions = new List<QuestionWrapper>();

        Map<String, Schema.SObjectField> customerFieldMap =
            getCustomerFieldMap();

        List<Final_Customize_Form_Line_Item__c> lineItems = [
            SELECT Id,
                   Name,
                   Question__c,
                   Answer_Type__c,
                   Sl_No__c,
                   Mandatory__c,
                   Final_Customize_Form__c,
                   BTL_Questions__c,
                   BTL_Questions__r.Customer_Field_Name__c
            FROM Final_Customize_Form_Line_Item__c
            WHERE Final_Customize_Form__c = :finalCustomizeFormId
            ORDER BY Sl_No__c ASC NULLS LAST, CreatedDate ASC
        ];

        Set<Id> lineItemIds = new Set<Id>();

        for (Final_Customize_Form_Line_Item__c lineItem : lineItems) {
            lineItemIds.add(lineItem.Id);
        }

        Map<Id, List<OptionWrapper>> answerOptionsMap =
            new Map<Id, List<OptionWrapper>>();

        if (!lineItemIds.isEmpty()) {
            for (Final_Customize_Form_Line_Item_Answer__c answerOption : [
                SELECT Id,
                       Name,
                       Answer__c,
                       Final_Customize_Form_Line_Item__c
                FROM Final_Customize_Form_Line_Item_Answer__c
                WHERE Final_Customize_Form_Line_Item__c IN :lineItemIds
                ORDER BY CreatedDate ASC
            ]) {
                Id parentLineItemId =
                    answerOption.Final_Customize_Form_Line_Item__c;

                if (!answerOptionsMap.containsKey(parentLineItemId)) {
                    answerOptionsMap.put(
                        parentLineItemId,
                        new List<OptionWrapper>()
                    );
                }

                String optionLabel =
                    String.isBlank(answerOption.Answer__c)
                        ? answerOption.Name
                        : answerOption.Answer__c;

                answerOptionsMap.get(parentLineItemId).add(
                    new OptionWrapper(
                        optionLabel,
                        optionLabel
                    )
                );
            }
        }

        for (Final_Customize_Form_Line_Item__c lineItem : lineItems) {
            QuestionWrapper questionWrapper = new QuestionWrapper();

            String mappedFieldApi;

            if (
                lineItem.BTL_Questions__r != null &&
                String.isNotBlank(
                    lineItem.BTL_Questions__r.Customer_Field_Name__c
                )
            ) {
                mappedFieldApi = resolveFieldApiName(
                    customerFieldMap,
                    lineItem.BTL_Questions__r
                        .Customer_Field_Name__c
                        .trim()
                );
            }

            questionWrapper.lineItemId = lineItem.Id;
            questionWrapper.lineItemNo = lineItem.Name;
            questionWrapper.serialNo = lineItem.Sl_No__c;
            questionWrapper.question = lineItem.Question__c;
            questionWrapper.answerType = lineItem.Answer_Type__c;

            questionWrapper.isRequired =
                lineItem.Mandatory__c == true;

            questionWrapper.fieldType =
                getFieldType(lineItem.Answer_Type__c);

            questionWrapper.mappedCustomerFieldApi =
                mappedFieldApi;

            questionWrapper.lockWhenCustomerFound =
                isProtectedCustomerField(mappedFieldApi);

            questionWrapper.options =
                answerOptionsMap.containsKey(lineItem.Id)
                    ? answerOptionsMap.get(lineItem.Id)
                    : new List<OptionWrapper>();

            response.questions.add(questionWrapper);
        }

        return response;
    }

    @AuraEnabled(cacheable=true)
    public static CustomerDetailsWrapper getCustomerDetailsByPhone(
        String phoneNo,
        Id finalCustomizeFormId
    ) {
        if (String.isBlank(phoneNo)) {
            return null;
        }

        String normalizedPhone =
            normalizeIndianMobileNumber(phoneNo);

        Map<String, Schema.SObjectField> customerFieldMap =
            getCustomerFieldMap();

        Set<String> mappedCustomerFieldApis =
            getMappedCustomerFieldApis(
                finalCustomizeFormId,
                customerFieldMap
            );

        SObject customerRecord =
            getCustomerRecordByPhone(
                normalizedPhone,
                mappedCustomerFieldApis
            );

        if (customerRecord == null) {
            return null;
        }

        CustomerDetailsWrapper wrapper =
            new CustomerDetailsWrapper();

        wrapper.customerId =
            String.valueOf(customerRecord.get('Id'));

        wrapper.customerName =
            getStringValue(
                customerRecord,
                CUSTOMER_NAME_FIELD_API
            );

        wrapper.phone =
            normalizedPhone;

        wrapper.dob =
            getStringValue(
                customerRecord,
                DOB_FIELD_API
            );

        wrapper.bcCustomerNo =
            getStringValue(
                customerRecord,
                BC_CUSTOMER_NO_FIELD_API
            );

        wrapper.addressLine1 =
            getStringValue(
                customerRecord,
                ADDRESS_LINE_1_FIELD_API
            );

        wrapper.addressLine2 =
            getStringValue(
                customerRecord,
                ADDRESS_LINE_2_FIELD_API
            );

        wrapper.villagePo =
            getStringValue(
                customerRecord,
                VILLAGE_PO_FIELD_API
            );

        wrapper.residentialCity =
            getStringValue(
                customerRecord,
                RESIDENTIAL_CITY_FIELD_API
            );

        wrapper.stateProvince =
            getStringValue(
                customerRecord,
                STATE_PROVINCE_FIELD_API
            );

        wrapper.district =
            getStringValue(
                customerRecord,
                DISTRICT_FIELD_API
            );

        wrapper.pinCode =
            getStringValue(
                customerRecord,
                PIN_CODE_FIELD_API
            );

        wrapper.country =
            getStringValue(
                customerRecord,
                COUNTRY_FIELD_API
            );

        wrapper.fieldValues =
            new Map<String, String>();

        for (String mappedFieldApi : mappedCustomerFieldApis) {
            wrapper.fieldValues.put(
                mappedFieldApi,
                getFieldValueForLwc(
                    customerRecord,
                    mappedFieldApi,
                    customerFieldMap
                )
            );
        }

        return wrapper;
    }

    @AuraEnabled
    public static Id saveCustomerResponse(
        Id formActivityId,
        Id dailyExecutionId,
        String phoneNo,
        Decimal latitude,
        Decimal longitude,
        List<CustomerAnswerWrapper> answers
    ) {
        if (formActivityId == null) {
            throw new AuraHandledException(
                'Form Activity Id is missing.'
            );
        }

        String normalizedPhone =
            normalizeIndianMobileNumber(phoneNo);

        if (answers == null || answers.isEmpty()) {
            throw new AuraHandledException(
                'No answers found to save.'
            );
        }

        DailyExecutionCaptureContext captureContext;

        /*
         * dailyExecutionId is intentionally optional because the same
         * interactive form is also used by other LWCs. Only the BTL
         * execution flow supplies it and receives Daily Execution/Team
         * tagging on the response.
         */
        if (dailyExecutionId != null) {
            captureContext =
                getDailyExecutionCaptureContext(
                    dailyExecutionId,
                    formActivityId
                );
        }

        SObject existingCustomer =
            getCustomerRecordByPhone(
                normalizedPhone,
                new Set<String>()
            );

        Id orientCustomerId;

        if (existingCustomer != null) {
            orientCustomerId =
                (Id) existingCustomer.get('Id');
        } else {
            orientCustomerId =
                createProspectCustomer(
                    normalizedPhone,
                    answers
                );
        }

        BTL_Customer_Response__c responseRecord =
            new BTL_Customer_Response__c();

        responseRecord.Form_Activity__c =
            formActivityId;

        responseRecord.Phone_No__c =
            normalizedPhone;

        responseRecord.Orient_Customer__c =
            orientCustomerId;

        responseRecord.Actual_Date_Time__c =
            System.now();

        if (captureContext != null) {
            responseRecord.Form_Activity_Daily_Execution__c =
                captureContext.dailyExecutionId;

            responseRecord.Captured_By_Team__c =
                captureContext.teamName;
        }

        if (latitude != null && longitude != null) {
            responseRecord.Geo_Location__Latitude__s =
                latitude;

            responseRecord.Geo_Location__Longitude__s =
                longitude;
        }

        insert responseRecord;

        List<BTL_Customer_Response_Items__c> responseItems =
            new List<BTL_Customer_Response_Items__c>();

        for (CustomerAnswerWrapper answerWrapper : answers) {
            if (answerWrapper == null) {
                continue;
            }

            BTL_Customer_Response_Items__c responseItem =
                new BTL_Customer_Response_Items__c();

            responseItem.BTL_Customer_Response__c =
                responseRecord.Id;

            responseItem.Question__c =
                answerWrapper.question;

            responseItem.Answer__c =
                answerWrapper.answer;

            responseItems.add(responseItem);
        }

        if (!responseItems.isEmpty()) {
            insert responseItems;
        }

        return responseRecord.Id;
    }


    private static DailyExecutionCaptureContext
        getDailyExecutionCaptureContext(
            Id dailyExecutionId,
            Id formActivityId
        )
    {
        List<Form_Activity_Daily_Execution__c> executions = [
            SELECT Id,
                   Form_Activity__c
            FROM Form_Activity_Daily_Execution__c
            WHERE Id = :dailyExecutionId
            LIMIT 1
        ];

        if (executions.isEmpty()) {
            throw new AuraHandledException(
                'The BTL Daily Execution record was not found.'
            );
        }

        Form_Activity_Daily_Execution__c execution =
            executions[0];

        if (execution.Form_Activity__c != formActivityId) {
            throw new AuraHandledException(
                'The BTL Daily Execution does not belong to the selected Form Activity.'
            );
        }

        String firstTeamName;

        /*
         * A Daily Execution is expected to represent one team. If old
         * data contains more than one team, use the first non-blank team
         * returned, matching the execution context used to open the form.
         */
        for (
            Form_Activity_Assigned_Persons_Date__c assignment : [
                SELECT Id,
                       Form_Activity_Assigned_Persons__r.Team_Name__c
                FROM Form_Activity_Assigned_Persons_Date__c
                WHERE Form_Activity_Daily_Execution__c = :dailyExecutionId
                AND Active_For_Date__c = true
                ORDER BY CreatedDate ASC, Id ASC
            ]
        ) {
            if (
                assignment.Form_Activity_Assigned_Persons__r != null &&
                String.isNotBlank(
                    assignment
                        .Form_Activity_Assigned_Persons__r
                        .Team_Name__c
                )
            ) {
                firstTeamName =
                    assignment
                        .Form_Activity_Assigned_Persons__r
                        .Team_Name__c
                        .trim();

                break;
            }
        }

        if (String.isBlank(firstTeamName)) {
            throw new AuraHandledException(
                'Team information was not found for this BTL Daily Execution.'
            );
        }

        DailyExecutionCaptureContext context =
            new DailyExecutionCaptureContext();

        context.dailyExecutionId =
            dailyExecutionId;

        context.teamName =
            firstTeamName;

        return context;
    }

    private class DailyExecutionCaptureContext {
        Id dailyExecutionId;
        String teamName;
    }

    private static Set<String> getMappedCustomerFieldApis(
        Id finalCustomizeFormId,
        Map<String, Schema.SObjectField> customerFieldMap
    ) {
        Set<String> mappedFieldApis =
            new Set<String>();

        if (finalCustomizeFormId == null) {
            return mappedFieldApis;
        }

        for (Final_Customize_Form_Line_Item__c lineItem : [
            SELECT BTL_Questions__c,
                   BTL_Questions__r.Customer_Field_Name__c
            FROM Final_Customize_Form_Line_Item__c
            WHERE Final_Customize_Form__c = :finalCustomizeFormId
            AND BTL_Questions__c != null
        ]) {
            if (
                lineItem.BTL_Questions__r == null ||
                String.isBlank(
                    lineItem.BTL_Questions__r.Customer_Field_Name__c
                )
            ) {
                continue;
            }

            String resolvedFieldApi =
                resolveFieldApiName(
                    customerFieldMap,
                    lineItem.BTL_Questions__r
                        .Customer_Field_Name__c
                        .trim()
                );

            if (String.isNotBlank(resolvedFieldApi)) {
                mappedFieldApis.add(resolvedFieldApi);
            }
        }

        return mappedFieldApis;
    }

    private static Boolean isProtectedCustomerField(
        String fieldApiName
    ) {
        if (String.isBlank(fieldApiName)) {
            return false;
        }

        String normalizedFieldApi =
            fieldApiName.trim().toLowerCase();

        return (
            normalizedFieldApi == 'phone' ||
            normalizedFieldApi == 'whatsapp_number__c'
        );
    }

    private static String normalizeIndianMobileNumber(
        String phoneNo
    ) {
        if (String.isBlank(phoneNo)) {
            throw new AuraHandledException(
                'Please enter Phone No.'
            );
        }

        Pattern phonePattern =
            Pattern.compile(INDIAN_MOBILE_REGEX);

        Matcher phoneMatcher =
            phonePattern.matcher(phoneNo);

        if (!phoneMatcher.matches()) {
            throw new AuraHandledException(
                'Enter exactly 10 numeric digits starting with ' +
                '6, 7, 8, or 9. You may optionally prefix +91.'
            );
        }

        if (phoneNo.startsWith('+91')) {
            return phoneNo.substring(3);
        }

        return phoneNo;
    }

    private static SObject getCustomerRecordByPhone(
        String phoneNo,
        Set<String> additionalQueryFields
    ) {
        if (String.isBlank(phoneNo)) {
            return null;
        }

        String normalizedPhone =
            normalizeIndianMobileNumber(phoneNo);

        Map<String, Schema.SObjectField> fieldMap =
            getCustomerFieldMap();

        String phoneFieldApi =
            resolveFirstAvailableFieldApiName(
                fieldMap,
                CUSTOMER_PHONE_FIELD_CANDIDATES
            );

        if (String.isBlank(phoneFieldApi)) {
            throw new AuraHandledException(
                'Phone field not found on customer object. Checked: ' +
                String.join(
                    CUSTOMER_PHONE_FIELD_CANDIDATES,
                    ', '
                )
            );
        }

        /*
         * Every field is added through addFieldIfExists.
         * This prevents duplicates such as Name/name or Phone/phone.
         */
        List<String> queryFields =
            new List<String>();

        addFieldIfExists(
            queryFields,
            fieldMap,
            'Id'
        );

        addFieldIfExists(
            queryFields,
            fieldMap,
            CUSTOMER_NAME_FIELD_API
        );

        addFieldIfExists(
            queryFields,
            fieldMap,
            phoneFieldApi
        );

        addFieldIfExists(
            queryFields,
            fieldMap,
            DOB_FIELD_API
        );

        addFieldIfExists(
            queryFields,
            fieldMap,
            BC_CUSTOMER_NO_FIELD_API
        );

        addFieldIfExists(
            queryFields,
            fieldMap,
            ADDRESS_LINE_1_FIELD_API
        );

        addFieldIfExists(
            queryFields,
            fieldMap,
            ADDRESS_LINE_2_FIELD_API
        );

        addFieldIfExists(
            queryFields,
            fieldMap,
            VILLAGE_PO_FIELD_API
        );

        addFieldIfExists(
            queryFields,
            fieldMap,
            RESIDENTIAL_CITY_FIELD_API
        );

        addFieldIfExists(
            queryFields,
            fieldMap,
            STATE_PROVINCE_FIELD_API
        );

        addFieldIfExists(
            queryFields,
            fieldMap,
            DISTRICT_FIELD_API
        );

        addFieldIfExists(
            queryFields,
            fieldMap,
            PIN_CODE_FIELD_API
        );

        addFieldIfExists(
            queryFields,
            fieldMap,
            COUNTRY_FIELD_API
        );

        if (additionalQueryFields != null) {
            for (String additionalFieldApi : additionalQueryFields) {
                addFieldIfExists(
                    queryFields,
                    fieldMap,
                    additionalFieldApi
                );
            }
        }

        String phoneWithCountryCode =
            '+91' + normalizedPhone;

        String queryString =
            'SELECT ' +
            String.join(queryFields, ',') +
            ' FROM ' +
            CUSTOMER_OBJECT_API +
            ' WHERE (' +
            phoneFieldApi +
            ' = :normalizedPhone OR ' +
            phoneFieldApi +
            ' = :phoneWithCountryCode)' +
            ' ORDER BY CreatedDate DESC LIMIT 1';

        List<SObject> customerRecords =
            Database.query(queryString);

        return customerRecords.isEmpty()
            ? null
            : customerRecords[0];
    }

    private static Id createProspectCustomer(
        String phoneNo,
        List<CustomerAnswerWrapper> answers
    ) {
        String normalizedPhone =
            normalizeIndianMobileNumber(phoneNo);

        Map<String, Schema.SObjectField> customerFieldMap =
            getCustomerFieldMap();

        Schema.SObjectType customerObjectType =
            Schema.getGlobalDescribe().get(
                CUSTOMER_OBJECT_API
            );

        SObject customerRecord =
            customerObjectType.newSObject();

        Map<String, String> mappedAnswerByCustomerField =
            getMappedAnswerByCustomerField(
                answers,
                customerFieldMap
            );

        for (
            String customerFieldApi :
            mappedAnswerByCustomerField.keySet()
        ) {
            String resolvedFieldApi =
                resolveFieldApiName(
                    customerFieldMap,
                    customerFieldApi
                );

            if (String.isBlank(resolvedFieldApi)) {
                continue;
            }

            Schema.DescribeFieldResult fieldDescribe =
                customerFieldMap.get(
                    resolvedFieldApi
                ).getDescribe();

            if (!fieldDescribe.isCreateable()) {
                continue;
            }

            String answerValue =
                mappedAnswerByCustomerField.get(
                    customerFieldApi
                );

            if (String.isBlank(answerValue)) {
                continue;
            }

            Object convertedValue =
                convertAnswerValue(
                    answerValue,
                    fieldDescribe
                );

            if (convertedValue != null) {
                customerRecord.put(
                    resolvedFieldApi,
                    convertedValue
                );
            }
        }

        String phoneFieldApi =
            resolveFirstAvailableFieldApiName(
                customerFieldMap,
                CUSTOMER_PHONE_FIELD_CANDIDATES
            );

        putIfCreateable(
            customerRecord,
            customerFieldMap,
            phoneFieldApi,
            normalizedPhone
        );

        putIfCreateable(
            customerRecord,
            customerFieldMap,
            CUSTOMER_STATUS_FIELD_API,
            'Prospect'
        );

        String existingName =
            getStringValue(
                customerRecord,
                CUSTOMER_NAME_FIELD_API
            );

        if (String.isBlank(existingName)) {
            String fallbackName =
                getFirstNonBlankAnswer(answers);

            if (String.isBlank(fallbackName)) {
                fallbackName =
                    'Prospect - ' + normalizedPhone;
            }

            putIfCreateable(
                customerRecord,
                customerFieldMap,
                CUSTOMER_NAME_FIELD_API,
                fallbackName
            );
        }

        insert customerRecord;

        return (Id) customerRecord.get('Id');
    }

    private static Map<String, String> getMappedAnswerByCustomerField(
        List<CustomerAnswerWrapper> answers,
        Map<String, Schema.SObjectField> customerFieldMap
    ) {
        Map<String, String> mappedAnswers =
            new Map<String, String>();

        if (answers == null || answers.isEmpty()) {
            return mappedAnswers;
        }

        Set<Id> lineItemIds =
            new Set<Id>();

        for (CustomerAnswerWrapper answerWrapper : answers) {
            if (
                answerWrapper != null &&
                answerWrapper.lineItemId != null
            ) {
                lineItemIds.add(
                    answerWrapper.lineItemId
                );
            }
        }

        if (lineItemIds.isEmpty()) {
            return mappedAnswers;
        }

        Map<Id, String> fieldApiByLineItemId =
            new Map<Id, String>();

        for (Final_Customize_Form_Line_Item__c lineItem : [
            SELECT Id,
                   BTL_Questions__c,
                   BTL_Questions__r.Customer_Field_Name__c
            FROM Final_Customize_Form_Line_Item__c
            WHERE Id IN :lineItemIds
        ]) {
            if (
                lineItem.BTL_Questions__r == null ||
                String.isBlank(
                    lineItem.BTL_Questions__r.Customer_Field_Name__c
                )
            ) {
                continue;
            }

            String resolvedFieldApi =
                resolveFieldApiName(
                    customerFieldMap,
                    lineItem.BTL_Questions__r
                        .Customer_Field_Name__c
                        .trim()
                );

            if (String.isNotBlank(resolvedFieldApi)) {
                fieldApiByLineItemId.put(
                    lineItem.Id,
                    resolvedFieldApi
                );
            }
        }

        for (CustomerAnswerWrapper answerWrapper : answers) {
            if (
                answerWrapper == null ||
                answerWrapper.lineItemId == null ||
                String.isBlank(answerWrapper.answer)
            ) {
                continue;
            }

            String mappedFieldApi =
                fieldApiByLineItemId.get(
                    answerWrapper.lineItemId
                );

            if (String.isBlank(mappedFieldApi)) {
                continue;
            }

            mappedAnswers.put(
                mappedFieldApi,
                answerWrapper.answer
            );
        }

        return mappedAnswers;
    }

    private static Map<String, Schema.SObjectField>
        getCustomerFieldMap()
    {
        Map<String, Schema.SObjectType> globalDescribe =
            Schema.getGlobalDescribe();

        if (!globalDescribe.containsKey(CUSTOMER_OBJECT_API)) {
            throw new AuraHandledException(
                'Customer object not found: ' +
                CUSTOMER_OBJECT_API
            );
        }

        Schema.SObjectType customerObjectType =
            globalDescribe.get(CUSTOMER_OBJECT_API);

        return customerObjectType
            .getDescribe()
            .fields
            .getMap();
    }

    private static String getFieldValueForLwc(
        SObject recordData,
        String fieldApiName,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        if (
            recordData == null ||
            fieldMap == null ||
            String.isBlank(fieldApiName)
        ) {
            return '';
        }

        String resolvedFieldApi =
            resolveFieldApiName(
                fieldMap,
                fieldApiName
            );

        if (String.isBlank(resolvedFieldApi)) {
            return '';
        }

        Object fieldValue;

        try {
            fieldValue =
                recordData.get(resolvedFieldApi);
        } catch (Exception fieldException) {
            return '';
        }

        if (fieldValue == null) {
            return '';
        }

        Schema.DisplayType fieldType =
            fieldMap.get(
                resolvedFieldApi
            ).getDescribe().getType();

        if (fieldType == Schema.DisplayType.Date) {
            return String.valueOf(
                (Date) fieldValue
            );
        }

        if (fieldType == Schema.DisplayType.DateTime) {
            return ((Datetime) fieldValue).formatGmt(
                'yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''
            );
        }

        if (fieldType == Schema.DisplayType.Boolean) {
            return ((Boolean) fieldValue)
                ? 'true'
                : 'false';
        }

        return String.valueOf(fieldValue);
    }

    private static Object convertAnswerValue(
        String answerValue,
        Schema.DescribeFieldResult fieldDescribe
    ) {
        if (
            String.isBlank(answerValue) ||
            fieldDescribe == null
        ) {
            return null;
        }

        Schema.DisplayType fieldType =
            fieldDescribe.getType();

        try {
            if (
                fieldType == Schema.DisplayType.String ||
                fieldType == Schema.DisplayType.TextArea ||
                fieldType == Schema.DisplayType.Phone ||
                fieldType == Schema.DisplayType.Email ||
                fieldType == Schema.DisplayType.Url ||
                fieldType == Schema.DisplayType.Picklist ||
                fieldType == Schema.DisplayType.MultiPicklist ||
                fieldType == Schema.DisplayType.Id ||
                fieldType == Schema.DisplayType.Reference
            ) {
                return answerValue;
            }

            if (
                fieldType == Schema.DisplayType.Integer ||
                fieldType == Schema.DisplayType.Double ||
                fieldType == Schema.DisplayType.Currency ||
                fieldType == Schema.DisplayType.Percent
            ) {
                return Decimal.valueOf(answerValue);
            }

            if (fieldType == Schema.DisplayType.Boolean) {
                String booleanValue =
                    answerValue.trim().toLowerCase();

                return (
                    booleanValue == 'true' ||
                    booleanValue == 'yes' ||
                    booleanValue == '1'
                );
            }

            if (fieldType == Schema.DisplayType.Date) {
                return Date.valueOf(answerValue);
            }

            if (fieldType == Schema.DisplayType.DateTime) {
                String dateTimeText =
                    answerValue.trim();

                if (dateTimeText.contains('T')) {
                    dateTimeText =
                        dateTimeText.replace('T', ' ');
                }

                if (dateTimeText.endsWith('Z')) {
                    dateTimeText =
                        dateTimeText.substring(
                            0,
                            dateTimeText.length() - 1
                        );
                }

                if (dateTimeText.contains('.')) {
                    dateTimeText =
                        dateTimeText.substring(
                            0,
                            dateTimeText.indexOf('.')
                        );
                }

                return DateTime.valueOf(dateTimeText);
            }
        } catch (Exception conversionException) {
            return null;
        }

        return answerValue;
    }

    private static String getFirstNonBlankAnswer(
        List<CustomerAnswerWrapper> answers
    ) {
        if (answers == null) {
            return null;
        }

        for (CustomerAnswerWrapper answerWrapper : answers) {
            if (
                answerWrapper != null &&
                String.isNotBlank(answerWrapper.answer)
            ) {
                return answerWrapper.answer.trim();
            }
        }

        return null;
    }

    private static void putIfCreateable(
        SObject recordData,
        Map<String, Schema.SObjectField> fieldMap,
        String fieldApiName,
        Object fieldValue
    ) {
        if (
            recordData == null ||
            fieldMap == null ||
            String.isBlank(fieldApiName) ||
            fieldValue == null
        ) {
            return;
        }

        String resolvedFieldApi =
            resolveFieldApiName(
                fieldMap,
                fieldApiName
            );

        if (String.isBlank(resolvedFieldApi)) {
            return;
        }

        Schema.DescribeFieldResult fieldDescribe =
            fieldMap.get(
                resolvedFieldApi
            ).getDescribe();

        if (!fieldDescribe.isCreateable()) {
            return;
        }

        recordData.put(
            resolvedFieldApi,
            fieldValue
        );
    }

    private static String getFieldType(
        String answerType
    ) {
        if (String.isBlank(answerType)) {
            return 'text';
        }

        String typeValue =
            answerType.trim().toLowerCase();

        if (
            typeValue == 'numaric' ||
            typeValue == 'numeric' ||
            typeValue == 'number'
        ) {
            return 'number';
        }

        if (
            typeValue == 'alphanumeric' ||
            typeValue == 'alphanumaric' ||
            typeValue == 'alpha numeric' ||
            typeValue == 'text'
        ) {
            return 'text';
        }

        if (typeValue == 'date') {
            return 'date';
        }

        if (
            typeValue == 'date & time' ||
            typeValue == 'datetime' ||
            typeValue == 'date time'
        ) {
            return 'datetime';
        }

        if (typeValue == 'picklist') {
            return 'picklist';
        }

        if (
            typeValue == 'multi-picklist' ||
            typeValue == 'multipicklist' ||
            typeValue == 'multi picklist'
        ) {
            return 'multipicklist';
        }

        return 'text';
    }

    /*
     * Adds a field to the dynamic query only once.
     * Duplicate checking is case-insensitive.
     */
    private static void addFieldIfExists(
        List<String> queryFields,
        Map<String, Schema.SObjectField> fieldMap,
        String fieldApiName
    ) {
        if (
            queryFields == null ||
            fieldMap == null ||
            String.isBlank(fieldApiName)
        ) {
            return;
        }

        String resolvedFieldApi =
            resolveFieldApiName(
                fieldMap,
                fieldApiName
            );

        if (String.isBlank(resolvedFieldApi)) {
            return;
        }

        for (String existingQueryField : queryFields) {
            if (
                String.isNotBlank(existingQueryField) &&
                existingQueryField.equalsIgnoreCase(
                    resolvedFieldApi
                )
            ) {
                return;
            }
        }

        queryFields.add(resolvedFieldApi);
    }

    private static String resolveFirstAvailableFieldApiName(
        Map<String, Schema.SObjectField> fieldMap,
        List<String> requestedFieldApis
    ) {
        if (
            fieldMap == null ||
            requestedFieldApis == null
        ) {
            return null;
        }

        for (String requestedFieldApi : requestedFieldApis) {
            String resolvedFieldApi =
                resolveFieldApiName(
                    fieldMap,
                    requestedFieldApi
                );

            if (String.isNotBlank(resolvedFieldApi)) {
                return resolvedFieldApi;
            }
        }

        return null;
    }

    private static String resolveFieldApiName(
        Map<String, Schema.SObjectField> fieldMap,
        String requestedFieldApi
    ) {
        if (
            fieldMap == null ||
            String.isBlank(requestedFieldApi)
        ) {
            return null;
        }

        if (fieldMap.containsKey(requestedFieldApi)) {
            return requestedFieldApi;
        }

        String requestedLower =
            requestedFieldApi.trim().toLowerCase();

        for (String existingFieldApi : fieldMap.keySet()) {
            if (
                existingFieldApi != null &&
                existingFieldApi.toLowerCase() ==
                    requestedLower
            ) {
                return existingFieldApi;
            }
        }

        return null;
    }

    private static String getStringValue(
        SObject recordData,
        String fieldApiName
    ) {
        if (
            recordData == null ||
            String.isBlank(fieldApiName)
        ) {
            return '';
        }

        Object fieldValue;

        try {
            fieldValue =
                recordData.get(fieldApiName);
        } catch (Exception fieldException) {
            return '';
        }

        return fieldValue == null
            ? ''
            : String.valueOf(fieldValue);
    }

    public class CustomerAnswerWrapper {
        @AuraEnabled
        public Id lineItemId { get; set; }

        @AuraEnabled
        public String question { get; set; }

        @AuraEnabled
        public String answerType { get; set; }

        @AuraEnabled
        public String answer { get; set; }
    }

    public class CustomerDetailsWrapper {
        @AuraEnabled public String customerId;
        @AuraEnabled public String customerName;
        @AuraEnabled public String phone;
        @AuraEnabled public String dob;
        @AuraEnabled public String bcCustomerNo;

        @AuraEnabled public String addressLine1;
        @AuraEnabled public String addressLine2;
        @AuraEnabled public String villagePo;
        @AuraEnabled public String residentialCity;
        @AuraEnabled public String stateProvince;
        @AuraEnabled public String district;
        @AuraEnabled public String pinCode;
        @AuraEnabled public String country;

        @AuraEnabled
        public Map<String, String> fieldValues;
    }

    public class OptionWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public OptionWrapper(
            String value,
            String label
        ) {
            this.value = value;
            this.label = label;
        }
    }

    public class ActivityWrapper {
        @AuraEnabled public Id activityId;
        @AuraEnabled public String activityNo;
        @AuraEnabled public Date activityDate;
        @AuraEnabled public String activityLocation;

        @AuraEnabled public Id storeId;
        @AuraEnabled public String storeName;

        @AuraEnabled public Id finalCustomizeFormId;
        @AuraEnabled public String finalCustomizeFormNo;
        @AuraEnabled public String formName;
    }

    public class InteractiveFormWrapper {
        @AuraEnabled public Id formId;
        @AuraEnabled public String formNo;
        @AuraEnabled public String formName;
        @AuraEnabled public Boolean active;
        @AuraEnabled public List<QuestionWrapper> questions;
    }

    public class QuestionWrapper {
        @AuraEnabled public Id lineItemId;
        @AuraEnabled public String lineItemNo;
        @AuraEnabled public Decimal serialNo;
        @AuraEnabled public String question;
        @AuraEnabled public String answerType;
        @AuraEnabled public String fieldType;
        @AuraEnabled public Boolean isRequired;

        @AuraEnabled
        public String mappedCustomerFieldApi;

        @AuraEnabled
        public Boolean lockWhenCustomerFound;

        @AuraEnabled
        public List<OptionWrapper> options;
    }
}

// public with sharing class ctrl_ActivityDashboardController {

//     private static final String CUSTOMER_OBJECT_API = 'Account';
//     private static final String CUSTOMER_STATUS_FIELD_API = 'Status__c';

//     private static final String INDIAN_MOBILE_REGEX =
//         '^(\\+91)?[6-9][0-9]{9}$';

//     private static final List<String> CUSTOMER_PHONE_FIELD_CANDIDATES =
//         new List<String>{
//             'Phone',
//             'Account_Phone__c'
//         };

//     private static final String CUSTOMER_NAME_FIELD_API = 'Name';
//     private static final String DOB_FIELD_API = 'DOB__c';
//     private static final String BC_CUSTOMER_NO_FIELD_API = 'BC_Customer_No__c';

//     private static final String ADDRESS_LINE_1_FIELD_API = 'Address_Line_1__c';
//     private static final String ADDRESS_LINE_2_FIELD_API = 'Address_Line_2__c';
//     private static final String VILLAGE_PO_FIELD_API = 'Village_PO__c';
//     private static final String RESIDENTIAL_CITY_FIELD_API = 'Residential_City__c';
//     private static final String STATE_PROVINCE_FIELD_API = 'State_Province__c';
//     private static final String DISTRICT_FIELD_API = 'District__c';
//     private static final String PIN_CODE_FIELD_API = 'Pin_Code__c';
//     private static final String COUNTRY_FIELD_API = 'Country__c';

//     @AuraEnabled(cacheable=true)
//     public static List<OptionWrapper> getStores() {
//         List<OptionWrapper> options = new List<OptionWrapper>();
//         options.add(new OptionWrapper('', 'All Stores'));

//         for (Store__c storeRecord : [
//             SELECT Id, Name
//             FROM Store__c
//             ORDER BY Name ASC
//             LIMIT 500
//         ]) {
//             options.add(
//                 new OptionWrapper(
//                     String.valueOf(storeRecord.Id),
//                     storeRecord.Name
//                 )
//             );
//         }

//         return options;
//     }

//     @AuraEnabled(cacheable=true)
//     public static List<ActivityWrapper> getActivities(
//         Date fromDate,
//         Date toDate,
//         Id storeId,
//         String searchKey
//     ) {
//         String searchText = String.isBlank(searchKey)
//             ? null
//             : '%' + searchKey.trim() + '%';

//         List<Form_Activity__c> activityList;

//         if (storeId != null && searchText != null) {
//             activityList = [
//                 SELECT Id,
//                        Name,
//                        Activity_Date__c,
//                        Activity_Location__c,
//                        Assigned_Store__c,
//                        Assigned_Store__r.Name,
//                        Final_Customize_Form__c,
//                        Final_Customize_Form__r.Name,
//                        Final_Customize_Form__r.Form_Name__c
//                 FROM Form_Activity__c
//                 WHERE Activity_Date__c >= :fromDate
//                 AND Activity_Date__c <= :toDate
//                 AND Assigned_Store__c = :storeId
//                 AND (
//                     Name LIKE :searchText
//                     OR Activity_Location__c LIKE :searchText
//                     OR Assigned_Store__r.Name LIKE :searchText
//                     OR Final_Customize_Form__r.Name LIKE :searchText
//                     OR Final_Customize_Form__r.Form_Name__c LIKE :searchText
//                 )
//                 ORDER BY Activity_Date__c DESC, CreatedDate DESC
//                 LIMIT 1000
//             ];
//         } else if (storeId != null) {
//             activityList = [
//                 SELECT Id,
//                        Name,
//                        Activity_Date__c,
//                        Activity_Location__c,
//                        Assigned_Store__c,
//                        Assigned_Store__r.Name,
//                        Final_Customize_Form__c,
//                        Final_Customize_Form__r.Name,
//                        Final_Customize_Form__r.Form_Name__c
//                 FROM Form_Activity__c
//                 WHERE Activity_Date__c >= :fromDate
//                 AND Activity_Date__c <= :toDate
//                 AND Assigned_Store__c = :storeId
//                 ORDER BY Activity_Date__c DESC, CreatedDate DESC
//                 LIMIT 1000
//             ];
//         } else if (searchText != null) {
//             activityList = [
//                 SELECT Id,
//                        Name,
//                        Activity_Date__c,
//                        Activity_Location__c,
//                        Assigned_Store__c,
//                        Assigned_Store__r.Name,
//                        Final_Customize_Form__c,
//                        Final_Customize_Form__r.Name,
//                        Final_Customize_Form__r.Form_Name__c
//                 FROM Form_Activity__c
//                 WHERE Activity_Date__c >= :fromDate
//                 AND Activity_Date__c <= :toDate
//                 AND (
//                     Name LIKE :searchText
//                     OR Activity_Location__c LIKE :searchText
//                     OR Assigned_Store__r.Name LIKE :searchText
//                     OR Final_Customize_Form__r.Name LIKE :searchText
//                     OR Final_Customize_Form__r.Form_Name__c LIKE :searchText
//                 )
//                 ORDER BY Activity_Date__c DESC, CreatedDate DESC
//                 LIMIT 1000
//             ];
//         } else {
//             activityList = [
//                 SELECT Id,
//                        Name,
//                        Activity_Date__c,
//                        Activity_Location__c,
//                        Assigned_Store__c,
//                        Assigned_Store__r.Name,
//                        Final_Customize_Form__c,
//                        Final_Customize_Form__r.Name,
//                        Final_Customize_Form__r.Form_Name__c
//                 FROM Form_Activity__c
//                 WHERE Activity_Date__c >= :fromDate
//                 AND Activity_Date__c <= :toDate
//                 ORDER BY Activity_Date__c DESC, CreatedDate DESC
//                 LIMIT 1000
//             ];
//         }

//         List<ActivityWrapper> result = new List<ActivityWrapper>();

//         for (Form_Activity__c activityRecord : activityList) {
//             ActivityWrapper wrapper = new ActivityWrapper();

//             wrapper.activityId = activityRecord.Id;
//             wrapper.activityNo = activityRecord.Name;
//             wrapper.activityDate = activityRecord.Activity_Date__c;
//             wrapper.activityLocation = activityRecord.Activity_Location__c;

//             wrapper.storeId = activityRecord.Assigned_Store__c;
//             wrapper.storeName = activityRecord.Assigned_Store__r != null
//                 ? activityRecord.Assigned_Store__r.Name
//                 : '';

//             wrapper.finalCustomizeFormId =
//                 activityRecord.Final_Customize_Form__c;

//             wrapper.finalCustomizeFormNo =
//                 activityRecord.Final_Customize_Form__r != null
//                     ? activityRecord.Final_Customize_Form__r.Name
//                     : '';

//             wrapper.formName =
//                 activityRecord.Final_Customize_Form__r != null
//                     ? activityRecord.Final_Customize_Form__r.Form_Name__c
//                     : '';

//             result.add(wrapper);
//         }

//         return result;
//     }

//     @AuraEnabled
//     public static InteractiveFormWrapper getInteractiveForm(
//         Id finalCustomizeFormId
//     ) {
//         if (finalCustomizeFormId == null) {
//             throw new AuraHandledException(
//                 'Final Customize Form Id is missing.'
//             );
//         }

//         Final_Customize_Form__c formRecord = [
//             SELECT Id,
//                    Name,
//                    Form_Name__c,
//                    Active__c
//             FROM Final_Customize_Form__c
//             WHERE Id = :finalCustomizeFormId
//             LIMIT 1
//         ];

//         InteractiveFormWrapper response = new InteractiveFormWrapper();

//         response.formId = formRecord.Id;
//         response.formNo = formRecord.Name;
//         response.formName = formRecord.Form_Name__c;
//         response.active = formRecord.Active__c;
//         response.questions = new List<QuestionWrapper>();

//         Map<String, Schema.SObjectField> customerFieldMap =
//             getCustomerFieldMap();

//         List<Final_Customize_Form_Line_Item__c> lineItems = [
//             SELECT Id,
//                    Name,
//                    Question__c,
//                    Answer_Type__c,
//                    Sl_No__c,
//                    Mandatory__c,
//                    Final_Customize_Form__c,
//                    BTL_Questions__c,
//                    BTL_Questions__r.Customer_Field_Name__c
//             FROM Final_Customize_Form_Line_Item__c
//             WHERE Final_Customize_Form__c = :finalCustomizeFormId
//             ORDER BY Sl_No__c ASC NULLS LAST, CreatedDate ASC
//         ];

//         Set<Id> lineItemIds = new Set<Id>();

//         for (Final_Customize_Form_Line_Item__c lineItem : lineItems) {
//             lineItemIds.add(lineItem.Id);
//         }

//         Map<Id, List<OptionWrapper>> answerOptionsMap =
//             new Map<Id, List<OptionWrapper>>();

//         if (!lineItemIds.isEmpty()) {
//             for (Final_Customize_Form_Line_Item_Answer__c answerOption : [
//                 SELECT Id,
//                        Name,
//                        Answer__c,
//                        Final_Customize_Form_Line_Item__c
//                 FROM Final_Customize_Form_Line_Item_Answer__c
//                 WHERE Final_Customize_Form_Line_Item__c IN :lineItemIds
//                 ORDER BY CreatedDate ASC
//             ]) {
//                 Id parentLineItemId =
//                     answerOption.Final_Customize_Form_Line_Item__c;

//                 if (!answerOptionsMap.containsKey(parentLineItemId)) {
//                     answerOptionsMap.put(
//                         parentLineItemId,
//                         new List<OptionWrapper>()
//                     );
//                 }

//                 String optionLabel =
//                     String.isBlank(answerOption.Answer__c)
//                         ? answerOption.Name
//                         : answerOption.Answer__c;

//                 answerOptionsMap.get(parentLineItemId).add(
//                     new OptionWrapper(
//                         optionLabel,
//                         optionLabel
//                     )
//                 );
//             }
//         }

//         for (Final_Customize_Form_Line_Item__c lineItem : lineItems) {
//             QuestionWrapper questionWrapper = new QuestionWrapper();

//             String mappedFieldApi;

//             if (
//                 lineItem.BTL_Questions__r != null &&
//                 String.isNotBlank(
//                     lineItem.BTL_Questions__r.Customer_Field_Name__c
//                 )
//             ) {
//                 mappedFieldApi = resolveFieldApiName(
//                     customerFieldMap,
//                     lineItem.BTL_Questions__r
//                         .Customer_Field_Name__c
//                         .trim()
//                 );
//             }

//             questionWrapper.lineItemId = lineItem.Id;
//             questionWrapper.lineItemNo = lineItem.Name;
//             questionWrapper.serialNo = lineItem.Sl_No__c;
//             questionWrapper.question = lineItem.Question__c;
//             questionWrapper.answerType = lineItem.Answer_Type__c;

//             questionWrapper.isRequired =
//                 lineItem.Mandatory__c == true;

//             questionWrapper.fieldType =
//                 getFieldType(lineItem.Answer_Type__c);

//             questionWrapper.mappedCustomerFieldApi =
//                 mappedFieldApi;

//             questionWrapper.lockWhenCustomerFound =
//                 isProtectedCustomerField(mappedFieldApi);

//             questionWrapper.options =
//                 answerOptionsMap.containsKey(lineItem.Id)
//                     ? answerOptionsMap.get(lineItem.Id)
//                     : new List<OptionWrapper>();

//             response.questions.add(questionWrapper);
//         }

//         return response;
//     }

//     @AuraEnabled(cacheable=true)
//     public static CustomerDetailsWrapper getCustomerDetailsByPhone(
//         String phoneNo,
//         Id finalCustomizeFormId
//     ) {
//         if (String.isBlank(phoneNo)) {
//             return null;
//         }

//         String normalizedPhone =
//             normalizeIndianMobileNumber(phoneNo);

//         Map<String, Schema.SObjectField> customerFieldMap =
//             getCustomerFieldMap();

//         Set<String> mappedCustomerFieldApis =
//             getMappedCustomerFieldApis(
//                 finalCustomizeFormId,
//                 customerFieldMap
//             );

//         SObject customerRecord =
//             getCustomerRecordByPhone(
//                 normalizedPhone,
//                 mappedCustomerFieldApis
//             );

//         if (customerRecord == null) {
//             return null;
//         }

//         CustomerDetailsWrapper wrapper =
//             new CustomerDetailsWrapper();

//         wrapper.customerId =
//             String.valueOf(customerRecord.get('Id'));

//         wrapper.customerName =
//             getStringValue(
//                 customerRecord,
//                 CUSTOMER_NAME_FIELD_API
//             );

//         wrapper.phone =
//             normalizedPhone;

//         wrapper.dob =
//             getStringValue(
//                 customerRecord,
//                 DOB_FIELD_API
//             );

//         wrapper.bcCustomerNo =
//             getStringValue(
//                 customerRecord,
//                 BC_CUSTOMER_NO_FIELD_API
//             );

//         wrapper.addressLine1 =
//             getStringValue(
//                 customerRecord,
//                 ADDRESS_LINE_1_FIELD_API
//             );

//         wrapper.addressLine2 =
//             getStringValue(
//                 customerRecord,
//                 ADDRESS_LINE_2_FIELD_API
//             );

//         wrapper.villagePo =
//             getStringValue(
//                 customerRecord,
//                 VILLAGE_PO_FIELD_API
//             );

//         wrapper.residentialCity =
//             getStringValue(
//                 customerRecord,
//                 RESIDENTIAL_CITY_FIELD_API
//             );

//         wrapper.stateProvince =
//             getStringValue(
//                 customerRecord,
//                 STATE_PROVINCE_FIELD_API
//             );

//         wrapper.district =
//             getStringValue(
//                 customerRecord,
//                 DISTRICT_FIELD_API
//             );

//         wrapper.pinCode =
//             getStringValue(
//                 customerRecord,
//                 PIN_CODE_FIELD_API
//             );

//         wrapper.country =
//             getStringValue(
//                 customerRecord,
//                 COUNTRY_FIELD_API
//             );

//         wrapper.fieldValues =
//             new Map<String, String>();

//         for (String mappedFieldApi : mappedCustomerFieldApis) {
//             wrapper.fieldValues.put(
//                 mappedFieldApi,
//                 getFieldValueForLwc(
//                     customerRecord,
//                     mappedFieldApi,
//                     customerFieldMap
//                 )
//             );
//         }

//         return wrapper;
//     }

//     @AuraEnabled
//     public static Id saveCustomerResponse(
//         Id formActivityId,
//         String phoneNo,
//         Decimal latitude,
//         Decimal longitude,
//         List<CustomerAnswerWrapper> answers
//     ) {
//         if (formActivityId == null) {
//             throw new AuraHandledException(
//                 'Form Activity Id is missing.'
//             );
//         }

//         String normalizedPhone =
//             normalizeIndianMobileNumber(phoneNo);

//         if (answers == null || answers.isEmpty()) {
//             throw new AuraHandledException(
//                 'No answers found to save.'
//             );
//         }

//         SObject existingCustomer =
//             getCustomerRecordByPhone(
//                 normalizedPhone,
//                 new Set<String>()
//             );

//         Id orientCustomerId;

//         if (existingCustomer != null) {
//             orientCustomerId =
//                 (Id) existingCustomer.get('Id');
//         } else {
//             orientCustomerId =
//                 createProspectCustomer(
//                     normalizedPhone,
//                     answers
//                 );
//         }

//         BTL_Customer_Response__c responseRecord =
//             new BTL_Customer_Response__c();

//         responseRecord.Form_Activity__c =
//             formActivityId;

//         responseRecord.Phone_No__c =
//             normalizedPhone;

//         responseRecord.Orient_Customer__c =
//             orientCustomerId;

//         responseRecord.Actual_Date_Time__c =
//             System.now();

//         if (latitude != null && longitude != null) {
//             responseRecord.Geo_Location__Latitude__s =
//                 latitude;

//             responseRecord.Geo_Location__Longitude__s =
//                 longitude;
//         }

//         insert responseRecord;

//         List<BTL_Customer_Response_Items__c> responseItems =
//             new List<BTL_Customer_Response_Items__c>();

//         for (CustomerAnswerWrapper answerWrapper : answers) {
//             if (answerWrapper == null) {
//                 continue;
//             }

//             BTL_Customer_Response_Items__c responseItem =
//                 new BTL_Customer_Response_Items__c();

//             responseItem.BTL_Customer_Response__c =
//                 responseRecord.Id;

//             responseItem.Question__c =
//                 answerWrapper.question;

//             responseItem.Answer__c =
//                 answerWrapper.answer;

//             responseItems.add(responseItem);
//         }

//         if (!responseItems.isEmpty()) {
//             insert responseItems;
//         }

//         return responseRecord.Id;
//     }

//     private static Set<String> getMappedCustomerFieldApis(
//         Id finalCustomizeFormId,
//         Map<String, Schema.SObjectField> customerFieldMap
//     ) {
//         Set<String> mappedFieldApis =
//             new Set<String>();

//         if (finalCustomizeFormId == null) {
//             return mappedFieldApis;
//         }

//         for (Final_Customize_Form_Line_Item__c lineItem : [
//             SELECT BTL_Questions__c,
//                    BTL_Questions__r.Customer_Field_Name__c
//             FROM Final_Customize_Form_Line_Item__c
//             WHERE Final_Customize_Form__c = :finalCustomizeFormId
//             AND BTL_Questions__c != null
//         ]) {
//             if (
//                 lineItem.BTL_Questions__r == null ||
//                 String.isBlank(
//                     lineItem.BTL_Questions__r.Customer_Field_Name__c
//                 )
//             ) {
//                 continue;
//             }

//             String resolvedFieldApi =
//                 resolveFieldApiName(
//                     customerFieldMap,
//                     lineItem.BTL_Questions__r
//                         .Customer_Field_Name__c
//                         .trim()
//                 );

//             if (String.isNotBlank(resolvedFieldApi)) {
//                 mappedFieldApis.add(resolvedFieldApi);
//             }
//         }

//         return mappedFieldApis;
//     }

//     private static Boolean isProtectedCustomerField(
//         String fieldApiName
//     ) {
//         if (String.isBlank(fieldApiName)) {
//             return false;
//         }

//         String normalizedFieldApi =
//             fieldApiName.trim().toLowerCase();

//         return (
//             normalizedFieldApi == 'phone' ||
//             normalizedFieldApi == 'whatsapp_number__c'
//         );
//     }

//     private static String normalizeIndianMobileNumber(
//         String phoneNo
//     ) {
//         if (String.isBlank(phoneNo)) {
//             throw new AuraHandledException(
//                 'Please enter Phone No.'
//             );
//         }

//         Pattern phonePattern =
//             Pattern.compile(INDIAN_MOBILE_REGEX);

//         Matcher phoneMatcher =
//             phonePattern.matcher(phoneNo);

//         if (!phoneMatcher.matches()) {
//             throw new AuraHandledException(
//                 'Enter exactly 10 numeric digits starting with ' +
//                 '6, 7, 8, or 9. You may optionally prefix +91.'
//             );
//         }

//         if (phoneNo.startsWith('+91')) {
//             return phoneNo.substring(3);
//         }

//         return phoneNo;
//     }

//     private static SObject getCustomerRecordByPhone(
//         String phoneNo,
//         Set<String> additionalQueryFields
//     ) {
//         if (String.isBlank(phoneNo)) {
//             return null;
//         }

//         String normalizedPhone =
//             normalizeIndianMobileNumber(phoneNo);

//         Map<String, Schema.SObjectField> fieldMap =
//             getCustomerFieldMap();

//         String phoneFieldApi =
//             resolveFirstAvailableFieldApiName(
//                 fieldMap,
//                 CUSTOMER_PHONE_FIELD_CANDIDATES
//             );

//         if (String.isBlank(phoneFieldApi)) {
//             throw new AuraHandledException(
//                 'Phone field not found on customer object. Checked: ' +
//                 String.join(
//                     CUSTOMER_PHONE_FIELD_CANDIDATES,
//                     ', '
//                 )
//             );
//         }

//         /*
//          * Every field is added through addFieldIfExists.
//          * This prevents duplicates such as Name/name or Phone/phone.
//          */
//         List<String> queryFields =
//             new List<String>();

//         addFieldIfExists(
//             queryFields,
//             fieldMap,
//             'Id'
//         );

//         addFieldIfExists(
//             queryFields,
//             fieldMap,
//             CUSTOMER_NAME_FIELD_API
//         );

//         addFieldIfExists(
//             queryFields,
//             fieldMap,
//             phoneFieldApi
//         );

//         addFieldIfExists(
//             queryFields,
//             fieldMap,
//             DOB_FIELD_API
//         );

//         addFieldIfExists(
//             queryFields,
//             fieldMap,
//             BC_CUSTOMER_NO_FIELD_API
//         );

//         addFieldIfExists(
//             queryFields,
//             fieldMap,
//             ADDRESS_LINE_1_FIELD_API
//         );

//         addFieldIfExists(
//             queryFields,
//             fieldMap,
//             ADDRESS_LINE_2_FIELD_API
//         );

//         addFieldIfExists(
//             queryFields,
//             fieldMap,
//             VILLAGE_PO_FIELD_API
//         );

//         addFieldIfExists(
//             queryFields,
//             fieldMap,
//             RESIDENTIAL_CITY_FIELD_API
//         );

//         addFieldIfExists(
//             queryFields,
//             fieldMap,
//             STATE_PROVINCE_FIELD_API
//         );

//         addFieldIfExists(
//             queryFields,
//             fieldMap,
//             DISTRICT_FIELD_API
//         );

//         addFieldIfExists(
//             queryFields,
//             fieldMap,
//             PIN_CODE_FIELD_API
//         );

//         addFieldIfExists(
//             queryFields,
//             fieldMap,
//             COUNTRY_FIELD_API
//         );

//         if (additionalQueryFields != null) {
//             for (String additionalFieldApi : additionalQueryFields) {
//                 addFieldIfExists(
//                     queryFields,
//                     fieldMap,
//                     additionalFieldApi
//                 );
//             }
//         }

//         String phoneWithCountryCode =
//             '+91' + normalizedPhone;

//         String queryString =
//             'SELECT ' +
//             String.join(queryFields, ',') +
//             ' FROM ' +
//             CUSTOMER_OBJECT_API +
//             ' WHERE (' +
//             phoneFieldApi +
//             ' = :normalizedPhone OR ' +
//             phoneFieldApi +
//             ' = :phoneWithCountryCode)' +
//             ' ORDER BY CreatedDate DESC LIMIT 1';

//         List<SObject> customerRecords =
//             Database.query(queryString);

//         return customerRecords.isEmpty()
//             ? null
//             : customerRecords[0];
//     }

//     private static Id createProspectCustomer(
//         String phoneNo,
//         List<CustomerAnswerWrapper> answers
//     ) {
//         String normalizedPhone =
//             normalizeIndianMobileNumber(phoneNo);

//         Map<String, Schema.SObjectField> customerFieldMap =
//             getCustomerFieldMap();

//         Schema.SObjectType customerObjectType =
//             Schema.getGlobalDescribe().get(
//                 CUSTOMER_OBJECT_API
//             );

//         SObject customerRecord =
//             customerObjectType.newSObject();

//         Map<String, String> mappedAnswerByCustomerField =
//             getMappedAnswerByCustomerField(
//                 answers,
//                 customerFieldMap
//             );

//         for (
//             String customerFieldApi :
//             mappedAnswerByCustomerField.keySet()
//         ) {
//             String resolvedFieldApi =
//                 resolveFieldApiName(
//                     customerFieldMap,
//                     customerFieldApi
//                 );

//             if (String.isBlank(resolvedFieldApi)) {
//                 continue;
//             }

//             Schema.DescribeFieldResult fieldDescribe =
//                 customerFieldMap.get(
//                     resolvedFieldApi
//                 ).getDescribe();

//             if (!fieldDescribe.isCreateable()) {
//                 continue;
//             }

//             String answerValue =
//                 mappedAnswerByCustomerField.get(
//                     customerFieldApi
//                 );

//             if (String.isBlank(answerValue)) {
//                 continue;
//             }

//             Object convertedValue =
//                 convertAnswerValue(
//                     answerValue,
//                     fieldDescribe
//                 );

//             if (convertedValue != null) {
//                 customerRecord.put(
//                     resolvedFieldApi,
//                     convertedValue
//                 );
//             }
//         }

//         String phoneFieldApi =
//             resolveFirstAvailableFieldApiName(
//                 customerFieldMap,
//                 CUSTOMER_PHONE_FIELD_CANDIDATES
//             );

//         putIfCreateable(
//             customerRecord,
//             customerFieldMap,
//             phoneFieldApi,
//             normalizedPhone
//         );

//         putIfCreateable(
//             customerRecord,
//             customerFieldMap,
//             CUSTOMER_STATUS_FIELD_API,
//             'Prospect'
//         );

//         String existingName =
//             getStringValue(
//                 customerRecord,
//                 CUSTOMER_NAME_FIELD_API
//             );

//         if (String.isBlank(existingName)) {
//             String fallbackName =
//                 getFirstNonBlankAnswer(answers);

//             if (String.isBlank(fallbackName)) {
//                 fallbackName =
//                     'Prospect - ' + normalizedPhone;
//             }

//             putIfCreateable(
//                 customerRecord,
//                 customerFieldMap,
//                 CUSTOMER_NAME_FIELD_API,
//                 fallbackName
//             );
//         }

//         insert customerRecord;

//         return (Id) customerRecord.get('Id');
//     }

//     private static Map<String, String> getMappedAnswerByCustomerField(
//         List<CustomerAnswerWrapper> answers,
//         Map<String, Schema.SObjectField> customerFieldMap
//     ) {
//         Map<String, String> mappedAnswers =
//             new Map<String, String>();

//         if (answers == null || answers.isEmpty()) {
//             return mappedAnswers;
//         }

//         Set<Id> lineItemIds =
//             new Set<Id>();

//         for (CustomerAnswerWrapper answerWrapper : answers) {
//             if (
//                 answerWrapper != null &&
//                 answerWrapper.lineItemId != null
//             ) {
//                 lineItemIds.add(
//                     answerWrapper.lineItemId
//                 );
//             }
//         }

//         if (lineItemIds.isEmpty()) {
//             return mappedAnswers;
//         }

//         Map<Id, String> fieldApiByLineItemId =
//             new Map<Id, String>();

//         for (Final_Customize_Form_Line_Item__c lineItem : [
//             SELECT Id,
//                    BTL_Questions__c,
//                    BTL_Questions__r.Customer_Field_Name__c
//             FROM Final_Customize_Form_Line_Item__c
//             WHERE Id IN :lineItemIds
//         ]) {
//             if (
//                 lineItem.BTL_Questions__r == null ||
//                 String.isBlank(
//                     lineItem.BTL_Questions__r.Customer_Field_Name__c
//                 )
//             ) {
//                 continue;
//             }

//             String resolvedFieldApi =
//                 resolveFieldApiName(
//                     customerFieldMap,
//                     lineItem.BTL_Questions__r
//                         .Customer_Field_Name__c
//                         .trim()
//                 );

//             if (String.isNotBlank(resolvedFieldApi)) {
//                 fieldApiByLineItemId.put(
//                     lineItem.Id,
//                     resolvedFieldApi
//                 );
//             }
//         }

//         for (CustomerAnswerWrapper answerWrapper : answers) {
//             if (
//                 answerWrapper == null ||
//                 answerWrapper.lineItemId == null ||
//                 String.isBlank(answerWrapper.answer)
//             ) {
//                 continue;
//             }

//             String mappedFieldApi =
//                 fieldApiByLineItemId.get(
//                     answerWrapper.lineItemId
//                 );

//             if (String.isBlank(mappedFieldApi)) {
//                 continue;
//             }

//             mappedAnswers.put(
//                 mappedFieldApi,
//                 answerWrapper.answer
//             );
//         }

//         return mappedAnswers;
//     }

//     private static Map<String, Schema.SObjectField>
//         getCustomerFieldMap()
//     {
//         Map<String, Schema.SObjectType> globalDescribe =
//             Schema.getGlobalDescribe();

//         if (!globalDescribe.containsKey(CUSTOMER_OBJECT_API)) {
//             throw new AuraHandledException(
//                 'Customer object not found: ' +
//                 CUSTOMER_OBJECT_API
//             );
//         }

//         Schema.SObjectType customerObjectType =
//             globalDescribe.get(CUSTOMER_OBJECT_API);

//         return customerObjectType
//             .getDescribe()
//             .fields
//             .getMap();
//     }

//     private static String getFieldValueForLwc(
//         SObject recordData,
//         String fieldApiName,
//         Map<String, Schema.SObjectField> fieldMap
//     ) {
//         if (
//             recordData == null ||
//             fieldMap == null ||
//             String.isBlank(fieldApiName)
//         ) {
//             return '';
//         }

//         String resolvedFieldApi =
//             resolveFieldApiName(
//                 fieldMap,
//                 fieldApiName
//             );

//         if (String.isBlank(resolvedFieldApi)) {
//             return '';
//         }

//         Object fieldValue;

//         try {
//             fieldValue =
//                 recordData.get(resolvedFieldApi);
//         } catch (Exception fieldException) {
//             return '';
//         }

//         if (fieldValue == null) {
//             return '';
//         }

//         Schema.DisplayType fieldType =
//             fieldMap.get(
//                 resolvedFieldApi
//             ).getDescribe().getType();

//         if (fieldType == Schema.DisplayType.Date) {
//             return String.valueOf(
//                 (Date) fieldValue
//             );
//         }

//         if (fieldType == Schema.DisplayType.DateTime) {
//             return ((Datetime) fieldValue).formatGmt(
//                 'yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''
//             );
//         }

//         if (fieldType == Schema.DisplayType.Boolean) {
//             return ((Boolean) fieldValue)
//                 ? 'true'
//                 : 'false';
//         }

//         return String.valueOf(fieldValue);
//     }

//     private static Object convertAnswerValue(
//         String answerValue,
//         Schema.DescribeFieldResult fieldDescribe
//     ) {
//         if (
//             String.isBlank(answerValue) ||
//             fieldDescribe == null
//         ) {
//             return null;
//         }

//         Schema.DisplayType fieldType =
//             fieldDescribe.getType();

//         try {
//             if (
//                 fieldType == Schema.DisplayType.String ||
//                 fieldType == Schema.DisplayType.TextArea ||
//                 fieldType == Schema.DisplayType.Phone ||
//                 fieldType == Schema.DisplayType.Email ||
//                 fieldType == Schema.DisplayType.Url ||
//                 fieldType == Schema.DisplayType.Picklist ||
//                 fieldType == Schema.DisplayType.MultiPicklist ||
//                 fieldType == Schema.DisplayType.Id ||
//                 fieldType == Schema.DisplayType.Reference
//             ) {
//                 return answerValue;
//             }

//             if (
//                 fieldType == Schema.DisplayType.Integer ||
//                 fieldType == Schema.DisplayType.Double ||
//                 fieldType == Schema.DisplayType.Currency ||
//                 fieldType == Schema.DisplayType.Percent
//             ) {
//                 return Decimal.valueOf(answerValue);
//             }

//             if (fieldType == Schema.DisplayType.Boolean) {
//                 String booleanValue =
//                     answerValue.trim().toLowerCase();

//                 return (
//                     booleanValue == 'true' ||
//                     booleanValue == 'yes' ||
//                     booleanValue == '1'
//                 );
//             }

//             if (fieldType == Schema.DisplayType.Date) {
//                 return Date.valueOf(answerValue);
//             }

//             if (fieldType == Schema.DisplayType.DateTime) {
//                 String dateTimeText =
//                     answerValue.trim();

//                 if (dateTimeText.contains('T')) {
//                     dateTimeText =
//                         dateTimeText.replace('T', ' ');
//                 }

//                 if (dateTimeText.endsWith('Z')) {
//                     dateTimeText =
//                         dateTimeText.substring(
//                             0,
//                             dateTimeText.length() - 1
//                         );
//                 }

//                 if (dateTimeText.contains('.')) {
//                     dateTimeText =
//                         dateTimeText.substring(
//                             0,
//                             dateTimeText.indexOf('.')
//                         );
//                 }

//                 return DateTime.valueOf(dateTimeText);
//             }
//         } catch (Exception conversionException) {
//             return null;
//         }

//         return answerValue;
//     }

//     private static String getFirstNonBlankAnswer(
//         List<CustomerAnswerWrapper> answers
//     ) {
//         if (answers == null) {
//             return null;
//         }

//         for (CustomerAnswerWrapper answerWrapper : answers) {
//             if (
//                 answerWrapper != null &&
//                 String.isNotBlank(answerWrapper.answer)
//             ) {
//                 return answerWrapper.answer.trim();
//             }
//         }

//         return null;
//     }

//     private static void putIfCreateable(
//         SObject recordData,
//         Map<String, Schema.SObjectField> fieldMap,
//         String fieldApiName,
//         Object fieldValue
//     ) {
//         if (
//             recordData == null ||
//             fieldMap == null ||
//             String.isBlank(fieldApiName) ||
//             fieldValue == null
//         ) {
//             return;
//         }

//         String resolvedFieldApi =
//             resolveFieldApiName(
//                 fieldMap,
//                 fieldApiName
//             );

//         if (String.isBlank(resolvedFieldApi)) {
//             return;
//         }

//         Schema.DescribeFieldResult fieldDescribe =
//             fieldMap.get(
//                 resolvedFieldApi
//             ).getDescribe();

//         if (!fieldDescribe.isCreateable()) {
//             return;
//         }

//         recordData.put(
//             resolvedFieldApi,
//             fieldValue
//         );
//     }

//     private static String getFieldType(
//         String answerType
//     ) {
//         if (String.isBlank(answerType)) {
//             return 'text';
//         }

//         String typeValue =
//             answerType.trim().toLowerCase();

//         if (
//             typeValue == 'numaric' ||
//             typeValue == 'numeric' ||
//             typeValue == 'number'
//         ) {
//             return 'number';
//         }

//         if (
//             typeValue == 'alphanumeric' ||
//             typeValue == 'alphanumaric' ||
//             typeValue == 'alpha numeric' ||
//             typeValue == 'text'
//         ) {
//             return 'text';
//         }

//         if (typeValue == 'date') {
//             return 'date';
//         }

//         if (
//             typeValue == 'date & time' ||
//             typeValue == 'datetime' ||
//             typeValue == 'date time'
//         ) {
//             return 'datetime';
//         }

//         if (typeValue == 'picklist') {
//             return 'picklist';
//         }

//         if (
//             typeValue == 'multi-picklist' ||
//             typeValue == 'multipicklist' ||
//             typeValue == 'multi picklist'
//         ) {
//             return 'multipicklist';
//         }

//         return 'text';
//     }

//     /*
//      * Adds a field to the dynamic query only once.
//      * Duplicate checking is case-insensitive.
//      */
//     private static void addFieldIfExists(
//         List<String> queryFields,
//         Map<String, Schema.SObjectField> fieldMap,
//         String fieldApiName
//     ) {
//         if (
//             queryFields == null ||
//             fieldMap == null ||
//             String.isBlank(fieldApiName)
//         ) {
//             return;
//         }

//         String resolvedFieldApi =
//             resolveFieldApiName(
//                 fieldMap,
//                 fieldApiName
//             );

//         if (String.isBlank(resolvedFieldApi)) {
//             return;
//         }

//         for (String existingQueryField : queryFields) {
//             if (
//                 String.isNotBlank(existingQueryField) &&
//                 existingQueryField.equalsIgnoreCase(
//                     resolvedFieldApi
//                 )
//             ) {
//                 return;
//             }
//         }

//         queryFields.add(resolvedFieldApi);
//     }

//     private static String resolveFirstAvailableFieldApiName(
//         Map<String, Schema.SObjectField> fieldMap,
//         List<String> requestedFieldApis
//     ) {
//         if (
//             fieldMap == null ||
//             requestedFieldApis == null
//         ) {
//             return null;
//         }

//         for (String requestedFieldApi : requestedFieldApis) {
//             String resolvedFieldApi =
//                 resolveFieldApiName(
//                     fieldMap,
//                     requestedFieldApi
//                 );

//             if (String.isNotBlank(resolvedFieldApi)) {
//                 return resolvedFieldApi;
//             }
//         }

//         return null;
//     }

//     private static String resolveFieldApiName(
//         Map<String, Schema.SObjectField> fieldMap,
//         String requestedFieldApi
//     ) {
//         if (
//             fieldMap == null ||
//             String.isBlank(requestedFieldApi)
//         ) {
//             return null;
//         }

//         if (fieldMap.containsKey(requestedFieldApi)) {
//             return requestedFieldApi;
//         }

//         String requestedLower =
//             requestedFieldApi.trim().toLowerCase();

//         for (String existingFieldApi : fieldMap.keySet()) {
//             if (
//                 existingFieldApi != null &&
//                 existingFieldApi.toLowerCase() ==
//                     requestedLower
//             ) {
//                 return existingFieldApi;
//             }
//         }

//         return null;
//     }

//     private static String getStringValue(
//         SObject recordData,
//         String fieldApiName
//     ) {
//         if (
//             recordData == null ||
//             String.isBlank(fieldApiName)
//         ) {
//             return '';
//         }

//         Object fieldValue;

//         try {
//             fieldValue =
//                 recordData.get(fieldApiName);
//         } catch (Exception fieldException) {
//             return '';
//         }

//         return fieldValue == null
//             ? ''
//             : String.valueOf(fieldValue);
//     }

//     public class CustomerAnswerWrapper {
//         @AuraEnabled
//         public Id lineItemId { get; set; }

//         @AuraEnabled
//         public String question { get; set; }

//         @AuraEnabled
//         public String answerType { get; set; }

//         @AuraEnabled
//         public String answer { get; set; }
//     }

//     public class CustomerDetailsWrapper {
//         @AuraEnabled public String customerId;
//         @AuraEnabled public String customerName;
//         @AuraEnabled public String phone;
//         @AuraEnabled public String dob;
//         @AuraEnabled public String bcCustomerNo;

//         @AuraEnabled public String addressLine1;
//         @AuraEnabled public String addressLine2;
//         @AuraEnabled public String villagePo;
//         @AuraEnabled public String residentialCity;
//         @AuraEnabled public String stateProvince;
//         @AuraEnabled public String district;
//         @AuraEnabled public String pinCode;
//         @AuraEnabled public String country;

//         @AuraEnabled
//         public Map<String, String> fieldValues;
//     }

//     public class OptionWrapper {
//         @AuraEnabled public String label;
//         @AuraEnabled public String value;

//         public OptionWrapper(
//             String value,
//             String label
//         ) {
//             this.value = value;
//             this.label = label;
//         }
//     }

//     public class ActivityWrapper {
//         @AuraEnabled public Id activityId;
//         @AuraEnabled public String activityNo;
//         @AuraEnabled public Date activityDate;
//         @AuraEnabled public String activityLocation;

//         @AuraEnabled public Id storeId;
//         @AuraEnabled public String storeName;

//         @AuraEnabled public Id finalCustomizeFormId;
//         @AuraEnabled public String finalCustomizeFormNo;
//         @AuraEnabled public String formName;
//     }

//     public class InteractiveFormWrapper {
//         @AuraEnabled public Id formId;
//         @AuraEnabled public String formNo;
//         @AuraEnabled public String formName;
//         @AuraEnabled public Boolean active;
//         @AuraEnabled public List<QuestionWrapper> questions;
//     }

//     public class QuestionWrapper {
//         @AuraEnabled public Id lineItemId;
//         @AuraEnabled public String lineItemNo;
//         @AuraEnabled public Decimal serialNo;
//         @AuraEnabled public String question;
//         @AuraEnabled public String answerType;
//         @AuraEnabled public String fieldType;
//         @AuraEnabled public Boolean isRequired;

//         @AuraEnabled
//         public String mappedCustomerFieldApi;

//         @AuraEnabled
//         public Boolean lockWhenCustomerFound;

//         @AuraEnabled
//         public List<OptionWrapper> options;
//     }
// }