public with sharing class BTLAccountFieldSelectorController {

    @AuraEnabled(cacheable=true)
    public static List<FieldOptionWrapper> getAccountFieldOptions() {
        List<FieldOptionWrapper> options = new List<FieldOptionWrapper>();

        Map<String, Schema.SObjectField> accountFieldMap =
            Schema.SObjectType.Account.fields.getMap();

        for (String fieldApiName : accountFieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe =
                accountFieldMap.get(fieldApiName).getDescribe();

            if (fieldDescribe.isDeprecatedAndHidden()) {
                continue;
            }

            if (!fieldDescribe.isAccessible()) {
                continue;
            }

            String fieldLabel = fieldDescribe.getLabel();
            String fieldType = String.valueOf(fieldDescribe.getType());

            options.add(
                new FieldOptionWrapper(
                    fieldLabel + ' (' + fieldApiName + ')',
                    fieldApiName,
                    fieldType
                )
            );
        }

        options.sort();
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static String getExistingCustomerFieldName(Id btlQuestionId) {
        if (btlQuestionId == null) {
            return null;
        }

        BTL_Questions__c questionRecord = [
            SELECT Id, Customer_Field_Name__c
            FROM BTL_Questions__c
            WHERE Id = :btlQuestionId
            LIMIT 1
        ];

        return questionRecord.Customer_Field_Name__c;
    }

    @AuraEnabled
    public static void saveCustomerFieldName(
        Id btlQuestionId,
        String accountFieldApiName
    ) {
        if (btlQuestionId == null) {
            throw new AuraHandledException('BTL Question record id is missing.');
        }

        if (String.isBlank(accountFieldApiName)) {
            throw new AuraHandledException('Please select an Account field.');
        }

        accountFieldApiName = accountFieldApiName.trim();

        Map<String, Schema.SObjectField> accountFieldMap =
            Schema.SObjectType.Account.fields.getMap();

        if (!accountFieldMap.containsKey(accountFieldApiName)) {
            throw new AuraHandledException('Invalid Account field selected.');
        }

        Schema.DescribeSObjectResult btlQuestionDescribe =
            BTL_Questions__c.SObjectType.getDescribe();

        if (!btlQuestionDescribe.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update BTL Question.');
        }

        Schema.DescribeFieldResult customerFieldDescribe =
            BTL_Questions__c.Customer_Field_Name__c.getDescribe();

        if (!customerFieldDescribe.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update Customer Field Name.');
        }

        BTL_Questions__c questionRecord = new BTL_Questions__c();
        questionRecord.Id = btlQuestionId;
        questionRecord.Customer_Field_Name__c = accountFieldApiName;

        update questionRecord;
    }

    public class FieldOptionWrapper implements Comparable {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String fieldType;

        public FieldOptionWrapper(
            String label,
            String value,
            String fieldType
        ) {
            this.label = label;
            this.value = value;
            this.fieldType = fieldType;
        }

        public Integer compareTo(Object compareTo) {
            FieldOptionWrapper otherOption = (FieldOptionWrapper) compareTo;

            if (this.label == null && otherOption.label == null) {
                return 0;
            }

            if (this.label == null) {
                return -1;
            }

            if (otherOption.label == null) {
                return 1;
            }

            return this.label.toLowerCase().compareTo(otherOption.label.toLowerCase());
        }
    }
}