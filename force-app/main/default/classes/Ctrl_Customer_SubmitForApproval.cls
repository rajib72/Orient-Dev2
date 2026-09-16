public with sharing class Ctrl_Customer_SubmitForApproval {

    // 1. FIXED: Changed oldValue and newValue from Object to String
    public class LockedFieldWrapper {
        @AuraEnabled public String accountFieldApiName;
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String inputType; 
        @AuraEnabled public String oldValue; 
        @AuraEnabled public Boolean isSelected = false;
        @AuraEnabled public String newValue; 
    }

    public class FieldMapConfig {
        public String trackingField;
        public String appIsChangedField;
        public String appOldValueField;
        public String appNewValueField;
        
        public FieldMapConfig(String tracking, String isChanged, String oldVal, String newVal) {
            this.trackingField = tracking;
            this.appIsChangedField = isChanged;
            this.appOldValueField = oldVal;
            this.appNewValueField = newVal;
        }
    }

    private static Map<String, FieldMapConfig> getFieldMappings() {
        return new Map<String, FieldMapConfig>{
            'AadharNo__c' => new FieldMapConfig('AadharNo__c', 'AadharNo_Is_Changed__c', 'AadharNo_Old_Value__c', 'AadharNo_New_Value__c'),
            'Description' => new FieldMapConfig('Description__c', 'Account_Description_Is_Changed__c', 'Account_Description_Old_Value__c', 'Account_Description_New_Value__c'),
            'Phone' => new FieldMapConfig('Phone__c', 'Account_Phone_Is_Changed__c', 'Account_Phone_Old_Value__c', 'Account_Phone_New_Value__c'),
            'Permanent_Address__c' => new FieldMapConfig('Permanent_Address__c', 'Address_Line_1_Is_Changed__c', 'Address_Line_1_Old_Value__c', 'Address_Line_1_New_Value__c'),
            'Locality_Area__c' => new FieldMapConfig('Locality_Area__c', 'Address_Line_2_Is_Changed__c', 'Address_Line_2_Old_Value__c', 'Address_Line_2_New_Value__c'),
            'Anniversary_Date__c' => new FieldMapConfig('Anniversary_Date__c', 'Anniversary_Date_Is_Changed__c', 'Anniversary_Date_Old_Value__c', 'Anniversary_Date_New_Value__c'),
            //'Buying_Intent__c' => new FieldMapConfig('Buying_Intent__c', 'Buying_Intent_Is_Changed__c', 'Buying_Intent_Old_Value__c', 'Buying_Intent_New_Value__c'),
            //'Consent_for_Marketing_Communications__c' => new FieldMapConfig('Consent_for_Marketing_Communications__c', 'ConsentforMarketingCommunicateIsChanged__c', 'ConsentforMarketingCommunicationOldValue__c', 'ConsentforMarketingCommunicationNewValue__c'),
            'Country__c' => new FieldMapConfig('Country__c', 'Country_Is_Changed__c', 'Country_Old_Value__c', 'Country_New_Value__c'),
            'Customer_Notes__c' => new FieldMapConfig('Customer_Notes__c', 'Customer_Notes_Is_Changed__c', 'Customer_Notes_old_Value__c', 'Customer_Notes_New_Value__c'),
            'Customer_Source_Acquisition__c' => new FieldMapConfig('Customer_Source_Acquisition__c', 'Customer_Source_Acquisition_Is_Changed__c', 'Customer_Source_Acquisition_Old_Value__c', 'Customer_Source_Acquisition_New_Value__c'),
            'Customer_Verification_KYC__c' => new FieldMapConfig('Customer_Verification_KYC__c', 'Customer_Verification_KYC_Is_Changed__c', 'Customer_Verification_KYC_Old_Value__c', 'Customer_Verification_KYC_New_Value__c'),
            'Decision_Maker__c' => new FieldMapConfig('Decision_Maker__c', 'Decision_Maker_Is_Changed__c', 'Decision_Maker_Old_Value__c', 'Decision_Maker_New_Value__c'),
            'District__c' => new FieldMapConfig('District__c', 'District_Is_Changed__c', 'District_Old_Value__c', 'District_New_Value__c'),
            'Do_Not_Contact_DNC_Status__c' => new FieldMapConfig('Do_Not_Contact_DNC_Status__c', 'DoNotContact_DNC_Status_Is_Changed__c', 'Do_Not_Contact_DNC_Status_Old_Value__c', 'Do_Not_Contact_DNC_Status_New_Value__c'),
            'Date_Of_Birth__c' => new FieldMapConfig('Date_Of_Birth_DOB__c', 'DOB_Is_Changed__c', 'DOB_Old_Value__c', 'DOB_New_Value__c'),
            'Email_Address__c' => new FieldMapConfig('Email_Address__c', 'Email_Address_Is_Changed__c', 'Email_Address_Old_Value__c', 'Email_Address_New_Value__c'),
            'Family_Type__c' => new FieldMapConfig('Family_Type__c', 'Family_Type_Is_Changed__c', 'Family_Type_Old_Value__c', 'Family_Type__c'),
            'GST__c' => new FieldMapConfig('GST__c', 'GST_Is_Changed__c', 'GST_Old_Value__c', 'GST_New_Value__c'),
            'Income_Band__c' => new FieldMapConfig('Income_Band__c', 'Income_Band_Is_Changed__c', 'Income_Band_Old_Value__c', 'Income_Band_New_Value__c'),
            'Lead_Source_Detail__c' => new FieldMapConfig('Lead_Source_Detail__c', 'Lead_Source_Detail_Is_Changed__c', 'Lead_Source_Detail_Old_Value__c', 'Lead_Source_Detail_New_Value__c'),
            //'Loyalty_Tier__c' => new FieldMapConfig('Loyalty_Tier__c', 'Loyalty_Tier_Is_Changed__c', 'Loyalty_Tier_Old_Value__c', 'Loyalty_Tier_New_Value__c'),
            'Marital_Status__c' => new FieldMapConfig('Marital_Status__c', 'Marital_Status_Is_Changed__c', 'Marital_Status__c', 'Marital_Status_New_Value__c'),
            'Nationality__c' => new FieldMapConfig('Nationality__c', 'Nationality_Is_Changed__c', 'Nationality_Old_Vale__c', 'Nationality_New_Value__c'),
            'Occupation_Profession__c' => new FieldMapConfig('Occupation_Profession__c', 'Occupation_Profession_Is_Changed__c', 'Occupation_Profession_OldValue__c', 'Occupation_Profession_New_Value__c'),
            'PAN__c' => new FieldMapConfig('PAN__c', 'PAN_Is_Changed__c', 'PAN_Old_Value__c', 'PAN_New_Value__c'),
            'Pin_Code__c' => new FieldMapConfig('Pin_Code__c', 'Pin_Code_Is_Changed__c', 'Pin_Code_Old_Value__c', 'Pin_Code_New_Value__c'),
            'Preferred_Communication_Channel__c' => new FieldMapConfig('Preferred_Communication_Channel__c', 'PreferredCommunicationChannel_Is_Changed__c', 'Preferred_CommunicationChannel_Old_Value__c', 'Preferred_CommunicationChannel_New_Value__c'),
            'Preferred_Contact_Time__c' => new FieldMapConfig('Preferred_Contact_Time__c', 'Preferred_Contact_Time_Is_Changed__c', 'Preferred_Contact_Time_Old_Value__c', 'Preferred_Contact_Time_New_Value__c'),
            'Preferred_Gift_Wrapping__c' => new FieldMapConfig('Preferred_Gift_Wrapping__c', 'Preferred_Gift_Wrapping_Is_Changed__c', 'Preferred_Gift_Wrapping_Old_Value__c', 'Depends_on_Occasion_New_Value__c'),
            'Preferred_Language__c' => new FieldMapConfig('Preferred_Language__c', 'Preferred_Language_Is_Changed__c', 'Preferred_Language_Old_Value__c', 'Preferred_Language_New_Value__c'),
            'Preferred_Price_Band_Weight__c' => new FieldMapConfig('Preferred_Price_Band__c', 'Preferred_Price_Band_Is_Changed__c', 'Preferred_Price_Band_Old_Value__c', 'Preferred_Price_Band_New_Value__c'),
			//'Preferred_Price_Band_Weight__c' => new FieldMapConfig('Preferred_Price_Band_Weight__c', 'Preferred_Price_Band_Is_Changed__c', 'Preferred_Price_Band_Old_Value__c', 'Preferred_Price_Band_New_Value__c'),
            'Referral_Source__c' => new FieldMapConfig('Referral_Source__c', 'Referral_Source_Is_Changed__c', 'Referral_Source_Old_Value__c', 'Referral_Source_New_Value__c'),
            'Registration_Mode__c' => new FieldMapConfig('Registration_Mode__c', 'Registration_Mode_Is_Changed__c', 'Registration_Mode_Old_Value__c', 'Registration_Mode_New_Value__c'),
            'Residential_City__c' => new FieldMapConfig('Residential_City__c', 'Residential_City_Is_Cahnged__c', 'Residential_City_Old_Value__c', 'Residential_City_New_Value__c'),
            'State_Province__c' => new FieldMapConfig('State_Province__c', 'State_Province_Is_Changed__c', 'State_Province_Old_Value__c', 'State_Province_New_Value__c'),
            'Tags_Customer_Labels__c' => new FieldMapConfig('Tags_Customer_Labels__c', 'Tags_Customer_Labels_Is_Changed__c', 'Tags_Customer_Labels_Old_Value__c', 'Tags_Customer_Labels_New_Value__c'),
            'Village__c' => new FieldMapConfig('Village__c', 'Village_PO_Is_Changed__c', 'Village_PO_Old_Value__c', 'Village_PO_New_Value__c'),
            'Whatsapp_number__c' => new FieldMapConfig('Whatsapp_number__c', 'Whatsapp_number_Is_Changed__c', 'Whatsapp_number_Old_Value__c', 'Whatsapp_number_New_Value__c')
        };
    }

	@AuraEnabled(cacheable=true)
    public static List<LockedFieldWrapper> getLockedFields(Id accountId) {
        List<LockedFieldWrapper> wrapperList = new List<LockedFieldWrapper>();
        Map<String, FieldMapConfig> mappings = getFieldMappings();
        
        Set<String> trkFieldsToQuery = new Set<String>{'Id'};
        // ADDED BC_Customer_No__c to the query set
        Set<String> accFieldsToQuery = new Set<String>{'Id', 'BC_Customer_No__c'};
        
        for (String accField : mappings.keySet()) {
            accFieldsToQuery.add(accField);
            trkFieldsToQuery.add(mappings.get(accField).trackingField);
        }
        
        String trkSoql = 'SELECT ' + String.join(new List<String>(trkFieldsToQuery), ', ') + ' FROM Orient_Customer_Tracking__c WHERE Orient_Customer__c = :accountId WITH USER_MODE LIMIT 1';
        List<Orient_Customer_Tracking__c> trackingRecords = Database.query(trkSoql);

        if (trackingRecords.isEmpty()) {
            return wrapperList; 
        }
        Orient_Customer_Tracking__c tracking = trackingRecords[0];

        String accSoql = 'SELECT ' + String.join(new List<String>(accFieldsToQuery), ', ') + ' FROM Account WHERE Id = :accountId WITH USER_MODE LIMIT 1';
        Account acc = Database.query(accSoql);

        // ==========================================
        // NEW VALIDATION: Check for BC Customer No
        // ==========================================
        if (String.isBlank(acc.BC_Customer_No__c)) {
            throw new AuraHandledException('This Account has not been synced to Business Central yet. BC Customer No is required to request changes.');
        }
        // ==========================================

        Map<String, Schema.SObjectField> accFieldMap = Schema.SObjectType.Account.fields.getMap();

        for (String accField : mappings.keySet()) {
            FieldMapConfig config = mappings.get(accField);
            
            Boolean isLocked = false;
            try {
                isLocked = (Boolean) tracking.get(config.trackingField);
            } catch (Exception e) {}
            
            if (isLocked != null && isLocked) {
                LockedFieldWrapper wrapper = new LockedFieldWrapper();
                wrapper.accountFieldApiName = accField;
                
                Schema.DescribeFieldResult fieldDescribe = accFieldMap.get(accField).getDescribe();
                wrapper.fieldLabel = fieldDescribe.getLabel();
                
                Object rawOldVal = acc.get(accField);
                wrapper.oldValue = rawOldVal != null ? String.valueOf(rawOldVal) : null;
                
                Schema.DisplayType type = fieldDescribe.getType();
                if (type == Schema.DisplayType.Date) wrapper.inputType = 'date';
                else if (type == Schema.DisplayType.Phone) wrapper.inputType = 'tel';
                else if (type == Schema.DisplayType.Email) wrapper.inputType = 'email';
                else wrapper.inputType = 'text';

                wrapperList.add(wrapper);
            }
        }
        return wrapperList;
    }

    // @AuraEnabled
    // public static String submitApprovalRequest(Id accountId, String payloadJson) {
    //     try {
    //         // Now JSON.deserialize will succeed because oldValue and newValue are typed as Strings
    //         List<LockedFieldWrapper> requestedChanges = (List<LockedFieldWrapper>) JSON.deserialize(payloadJson, List<LockedFieldWrapper>.class);
    //         Map<String, FieldMapConfig> mappings = getFieldMappings();

    //         Orient_Customer_Approval_Traking__c approvalRecord = new Orient_Customer_Approval_Traking__c(
    //             Orient_Customer__c = accountId
    //         );

    //         Boolean hasChanges = false;
    //         Map<String, Schema.SObjectField> accFieldMap = Schema.SObjectType.Account.fields.getMap();

    //         for (LockedFieldWrapper change : requestedChanges) {
    //             if (change.isSelected && String.isNotBlank(change.newValue)) {
    //                 FieldMapConfig config = mappings.get(change.accountFieldApiName);
                    
    //                 approvalRecord.put(config.appIsChangedField, true);
                    
    //                 Schema.DisplayType fieldType = accFieldMap.get(change.accountFieldApiName).getDescribe().getType();
                    
    //                 // 3. FIXED: Properly cast Strings back to Decimal/Date before database insert
                    
    //                 // Cast and Set Old Value
    //                 if (String.isNotBlank(change.oldValue)) {
    //                     if (fieldType == Schema.DisplayType.Date) {
    //                         approvalRecord.put(config.appOldValueField, Date.valueOf(change.oldValue));
    //                     } else if (fieldType == Schema.DisplayType.Double || fieldType == Schema.DisplayType.Currency || fieldType == Schema.DisplayType.Percent) {
    //                         approvalRecord.put(config.appOldValueField, Decimal.valueOf(change.oldValue));
    //                     } else {
    //                         approvalRecord.put(config.appOldValueField, change.oldValue);
    //                     }
    //                 }
                    
    //                 // Cast and Set New Value
    //                 if (fieldType == Schema.DisplayType.Date) {
    //                     approvalRecord.put(config.appNewValueField, Date.valueOf(change.newValue));
    //                 } else if (fieldType == Schema.DisplayType.Double || fieldType == Schema.DisplayType.Currency || fieldType == Schema.DisplayType.Percent) {
    //                     approvalRecord.put(config.appNewValueField, Decimal.valueOf(change.newValue));
    //                 } else {
    //                     approvalRecord.put(config.appNewValueField, change.newValue);
    //                 }
                    
    //                 hasChanges = true;
    //             }
    //         }

    //         if (hasChanges) {
    //             insert as user approvalRecord;
    //             return approvalRecord.Id;
    //         } else {
    //             return 'NO_CHANGES_SELECTED';
    //         }
    //     } catch (Exception e) {
    //         throw new AuraHandledException('Error creating approval request: ' + e.getMessage());
    //     }
    // }

    @AuraEnabled
    public static String submitApprovalRequest(Id accountId, String payloadJson) {
        try {
            List<LockedFieldWrapper> requestedChanges = (List<LockedFieldWrapper>) JSON.deserialize(payloadJson, List<LockedFieldWrapper>.class);
            Map<String, FieldMapConfig> mappings = getFieldMappings();

            Orient_Customer_Approval_Traking__c approvalRecord = new Orient_Customer_Approval_Traking__c(
                Orient_Customer__c = accountId
            );

            Boolean hasChanges = false;
            Map<String, Schema.SObjectField> accFieldMap = Schema.SObjectType.Account.fields.getMap();
            
            // --- NEW: Start building the HTML table for the Email Template ---
            String summaryHtml = '<table border="1" cellpadding="5" style="border-collapse: collapse; text-align: left; width: 100%; font-family: sans-serif;">';
            summaryHtml += '<tr style="background-color: #f3f3f3;"><th>Field Name</th><th>Old Value</th><th>Requested New Value</th></tr>';

            for (LockedFieldWrapper change : requestedChanges) {
                if (change.isSelected && String.isNotBlank(change.newValue)) {
                    FieldMapConfig config = mappings.get(change.accountFieldApiName);
                    
                    approvalRecord.put(config.appIsChangedField, true);
                    Schema.DisplayType fieldType = accFieldMap.get(change.accountFieldApiName).getDescribe().getType();
                    
                    // Cast and Set Old Value
                    if (String.isNotBlank(change.oldValue)) {
                        if (fieldType == Schema.DisplayType.Date) {
                            approvalRecord.put(config.appOldValueField, Date.valueOf(change.oldValue));
                        } else if (fieldType == Schema.DisplayType.Double || fieldType == Schema.DisplayType.Currency || fieldType == Schema.DisplayType.Percent) {
                            approvalRecord.put(config.appOldValueField, Decimal.valueOf(change.oldValue));
                        } else {
                            approvalRecord.put(config.appOldValueField, change.oldValue);
                        }
                    }
                    
                    // Cast and Set New Value
                    if (fieldType == Schema.DisplayType.Date) {
                        approvalRecord.put(config.appNewValueField, Date.valueOf(change.newValue));
                    } else if (fieldType == Schema.DisplayType.Double || fieldType == Schema.DisplayType.Currency || fieldType == Schema.DisplayType.Percent) {
                        approvalRecord.put(config.appNewValueField, Decimal.valueOf(change.newValue));
                    } else {
                        approvalRecord.put(config.appNewValueField, change.newValue);
                    }
                    
                    hasChanges = true;
                    
                    // --- NEW: Add the row to our HTML Summary ---
                    String oldValDisplay = String.isNotBlank(change.oldValue) ? change.oldValue : '<i>Blank</i>';
                    summaryHtml += '<tr>';
                    summaryHtml += '<td><b>' + change.fieldLabel + '</b></td>';
                    summaryHtml += '<td>' + oldValDisplay + '</td>';
                    summaryHtml += '<td style="color: green; font-weight: bold;">' + change.newValue + '</td>';
                    summaryHtml += '</tr>';
                }
            }

            summaryHtml += '</table>'; // Close the table

            if (hasChanges) {
                // Save the HTML into our new Rich Text field
                approvalRecord.Approval_Summary__c = summaryHtml;
                
                insert as user approvalRecord;
                return approvalRecord.Id;
            } else {
                return 'NO_CHANGES_SELECTED';
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error creating approval request: ' + e.getMessage());
        }
    }
}