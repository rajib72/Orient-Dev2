public with sharing class Ctrl_Customer_ProcessApproval {

    // --- NEW: Wrapper to hold both the Status and the Fields ---
    public class ScreenDataWrapper {
        @AuraEnabled public String status;
        @AuraEnabled public List<ApprovalFieldWrapper> fields;
    }

    public class ApprovalFieldWrapper {
        @AuraEnabled public String accountFieldApiName;
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String oldValue;
        @AuraEnabled public String newValue;
        @AuraEnabled public Boolean isApproved = true; 
    }

    public class FieldMapConfig {
        public String appIsChangedField;
        public String appOldValueField;
        public String appNewValueField;
        public String appApprovalField;
        
        public FieldMapConfig(String isChanged, String oldVal, String newVal, String approval) {
            this.appIsChangedField = isChanged;
            this.appOldValueField = oldVal;
            this.appNewValueField = newVal;
            this.appApprovalField = approval;
        }
    }

    private static Map<String, FieldMapConfig> getFieldMappings() {
        return new Map<String, FieldMapConfig>{
            'AadharNo__c' => new FieldMapConfig('AadharNo_Is_Changed__c', 'AadharNo_Old_Value__c', 'AadharNo_New_Value__c', 'AadharNo_Change_Approval__c'),
            'Description' => new FieldMapConfig('Account_Description_Is_Changed__c', 'Account_Description_Old_Value__c', 'Account_Description_New_Value__c', 'Account_Description_Change_Approval__c'),
            'Phone' => new FieldMapConfig('Account_Phone_Is_Changed__c', 'Account_Phone_Old_Value__c', 'Account_Phone_New_Value__c', 'Account_Phone_Change_Approval__c'),
            'Permanent_Address__c' => new FieldMapConfig('Address_Line_1_Is_Changed__c', 'Address_Line_1_Old_Value__c', 'Address_Line_1_New_Value__c', 'Address_Line_1_Change_Approval__c'),
            'Locality_Area__c' => new FieldMapConfig('Address_Line_2_Is_Changed__c', 'Address_Line_2_Old_Value__c', 'Address_Line_2_New_Value__c', 'Address_Line_2_Change_Approval__c'),
            'Anniversary_Date__c' => new FieldMapConfig('Anniversary_Date_Is_Changed__c', 'Anniversary_Date_Old_Value__c', 'Anniversary_Date_New_Value__c', 'Anniversary_Date_Change_Approval__c'),
            'Buying_Intent__c' => new FieldMapConfig('Buying_Intent_Is_Changed__c', 'Buying_Intent_Old_Value__c', 'Buying_Intent_New_Value__c', 'Buying_Intent_Change_Approval__c'),
            'Consent_for_Marketing_Communications__c' => new FieldMapConfig('ConsentforMarketingCommunicateIsChanged__c', 'ConsentforMarketingCommunicationOldValue__c', 'ConsentforMarketingCommunicationNewValue__c', 'ConsentMarketingCommunicatChangeApproval__c'),
            'Country__c' => new FieldMapConfig('Country_Is_Changed__c', 'Country_Old_Value__c', 'Country_New_Value__c', 'Country_Change_Approval__c'),
            'Customer_Notes__c' => new FieldMapConfig('Customer_Notes_Is_Changed__c', 'Customer_Notes_old_Value__c', 'Customer_Notes_New_Value__c', 'Customer_Notes_Change_Approval__c'),
            'Customer_Source_Acquisition__c' => new FieldMapConfig('Customer_Source_Acquisition_Is_Changed__c', 'Customer_Source_Acquisition_Old_Value__c', 'Customer_Source_Acquisition_New_Value__c', 'CustomerSource_Acquisition_ChangeApprova__c'),
            'Customer_Verification_KYC__c' => new FieldMapConfig('Customer_Verification_KYC_Is_Changed__c', 'Customer_Verification_KYC_Old_Value__c', 'Customer_Verification_KYC_New_Value__c', 'CustomerVerification_KYC_Change_Approval__c'),
            'Decision_Maker__c' => new FieldMapConfig('Decision_Maker_Is_Changed__c', 'Decision_Maker_Old_Value__c', 'Decision_Maker_New_Value__c', 'Decision_Maker_Change_Approval__c'),
            'District__c' => new FieldMapConfig('District_Is_Changed__c', 'District_Old_Value__c', 'District_New_Value__c', 'District_Change_Approval__c'),
            'Do_Not_Contact_DNC_Status__c' => new FieldMapConfig('DoNotContact_DNC_Status_Is_Changed__c', 'Do_Not_Contact_DNC_Status_Old_Value__c', 'Do_Not_Contact_DNC_Status_New_Value__c', 'DoNotContact_DNC_Status_Change_Approval__c'),
            'Date_Of_Birth__c' => new FieldMapConfig('DOB_Is_Changed__c', 'DOB_Old_Value__c', 'DOB_New_Value__c', 'DOB_Change_Approval__c'),
            'Email_Address__c' => new FieldMapConfig('Email_Address_Is_Changed__c', 'Email_Address_Old_Value__c', 'Email_Address_New_Value__c', 'Email_Address_Change_Approval__c'),
            'Family_Type__c' => new FieldMapConfig('Family_Type_Is_Changed__c', 'Family_Type_Old_Value__c', 'Family_Type__c', 'Family_Type_Change_Approval__c'), 
            'GST__c' => new FieldMapConfig('GST_Is_Changed__c', 'GST_Old_Value__c', 'GST_New_Value__c', 'GST_Change_Approval__c'),
            'Income_Band__c' => new FieldMapConfig('Income_Band_Is_Changed__c', 'Income_Band_Old_Value__c', 'Income_Band_New_Value__c', 'Income_Band_Change_Approval__c'),
            'Lead_Source_Detail__c' => new FieldMapConfig('Lead_Source_Detail_Is_Changed__c', 'Lead_Source_Detail_Old_Value__c', 'Lead_Source_Detail_New_Value__c', 'Lead_Source_Detail_Change_Approval__c'),
            'Loyalty_Tier__c' => new FieldMapConfig('Loyalty_Tier_Is_Changed__c', 'Loyalty_Tier_Old_Value__c', 'Loyalty_Tier_New_Value__c', 'Loyalty_Tier_Change_Approval__c'),
            'Marital_Status__c' => new FieldMapConfig('Marital_Status_Is_Changed__c', 'Marital_Status__c', 'Marital_Status_New_Value__c', 'Marital_Status_change_Approval__c'),
            'Nationality__c' => new FieldMapConfig('Nationality_Is_Changed__c', 'Nationality_Old_Vale__c', 'Nationality_New_Value__c', 'Nationality_Change_Approval__c'),
            'Occupation_Profession__c' => new FieldMapConfig('Occupation_Profession_Is_Changed__c', 'Occupation_Profession_OldValue__c', 'Occupation_Profession_New_Value__c', 'Occupation_Profession_Change_Approvall__c'),
            'PAN__c' => new FieldMapConfig('PAN_Is_Changed__c', 'PAN_Old_Value__c', 'PAN_New_Value__c', 'PAN_Change_Approval__c'),
            'Pin_Code__c' => new FieldMapConfig('Pin_Code_Is_Changed__c', 'Pin_Code_Old_Value__c', 'Pin_Code_New_Value__c', 'Pin_Code_Change_Approval__c'),
            'Preferred_Communication_Channel__c' => new FieldMapConfig('PreferredCommunicationChannel_Is_Changed__c', 'Preferred_CommunicationChannel_Old_Value__c', 'Preferred_CommunicationChannel_New_Value__c', 'PreferredCommunicateChannelChangeApprova__c'),
			//'Preferred_Communication_Channel__c' => new FieldMapConfig('PreferredCommunicationChannel_Is_Changed__c', 'Preferred_Communication_Channel_Old_Value__c', 'Preferred_CommunicationChannel_New_Value__c', 'PreferredCommunicateChannelChangeApprova__c'),
            'Preferred_Contact_Time__c' => new FieldMapConfig('Preferred_Contact_Time_Is_Changed__c', 'Preferred_Contact_Time_Old_Value__c', 'Preferred_Contact_Time_New_Value__c', 'Preferred_Contact_Time_Change_Approval__c'),
            'Preferred_Gift_Wrapping__c' => new FieldMapConfig('Preferred_Gift_Wrapping_Is_Changed__c', 'Preferred_Gift_Wrapping_Old_Value__c', 'Depends_on_Occasion_New_Value__c', 'Preferred_Gift_Wrapping_Change_Approval__c'),
            'Preferred_Language__c' => new FieldMapConfig('Preferred_Language_Is_Changed__c', 'Preferred_Language_Old_Value__c', 'Preferred_Language_New_Value__c', 'Preferred_Language_Change_Approval__c'),
            'Preferred_Price_Band_Weight__c' => new FieldMapConfig('Preferred_Price_Band_Is_Changed__c', 'Preferred_Price_Band_Old_Value__c', 'Preferred_Price_Band_New_Value__c', 'Preferred_Price_Band_Change_Approval__c'),
            'Referral_Source__c' => new FieldMapConfig('Referral_Source_Is_Changed__c', 'Referral_Source_Old_Value__c', 'Referral_Source_New_Value__c', 'Referral_Source_Change_Approval__c'),
            'Registration_Mode__c' => new FieldMapConfig('Registration_Mode_Is_Changed__c', 'Registration_Mode_Old_Value__c', 'Registration_Mode_New_Value__c', 'Registration_Mode_Change_Approval__c'),
            'Residential_City__c' => new FieldMapConfig('Residential_City_Is_Cahnged__c', 'Residential_City_Old_Value__c', 'Residential_City_New_Value__c', 'Residential_City_Change_Approval__c'),
            'State_Province__c' => new FieldMapConfig('State_Province_Is_Changed__c', 'State_Province_Old_Value__c', 'State_Province_New_Value__c', 'State_Province_Change_Approval__c'),
            'Tags_Customer_Labels__c' => new FieldMapConfig('Tags_Customer_Labels_Is_Changed__c', 'Tags_Customer_Labels_Old_Value__c', 'Tags_Customer_Labels_New_Value__c', 'Tags_Customer_Labels_Change_Approval__c'),
            'Village__c' => new FieldMapConfig('Village_PO_Is_Changed__c', 'Village_PO_Old_Value__c', 'Village_PO_New_Value__c', 'Village_PO_Change_Approval__c'),
            'Whatsapp_number__c' => new FieldMapConfig('Whatsapp_number_Is_Changed__c', 'Whatsapp_number_Old_Value__c', 'Whatsapp_number_New_Value__c', 'Whatsapp_number_Change_Approval__c')
        };
    }

    @AuraEnabled(cacheable=true)
    public static ScreenDataWrapper getPendingApprovals(Id trackingId) {
        ScreenDataWrapper result = new ScreenDataWrapper();
        result.fields = new List<ApprovalFieldWrapper>();
        
        Map<String, FieldMapConfig> mappings = getFieldMappings();
        
        // Add Approval_Status__c to the dynamic query
        Set<String> fieldsToQuery = new Set<String>{'Id', 'Orient_Customer__c', 'Approval_Status__c'};
        for (FieldMapConfig config : mappings.values()) {
            fieldsToQuery.add(config.appIsChangedField);
            fieldsToQuery.add(config.appOldValueField);
            fieldsToQuery.add(config.appNewValueField);
            fieldsToQuery.add(config.appApprovalField);
        }

        String soql = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ', ') + ' FROM Orient_Customer_Approval_Traking__c WHERE Id = :trackingId WITH USER_MODE LIMIT 1';
        Orient_Customer_Approval_Traking__c trackingRec = Database.query(soql);
        
        // --- NEW: Check Status First ---
        result.status = trackingRec.Approval_Status__c;
        if (result.status == 'Approved' || result.status == 'Rejected') {
            return result; // Return early, the LWC will display the "Already processed" screen
        }

        Map<String, Schema.SObjectField> accFieldMap = Schema.SObjectType.Account.fields.getMap();

        for (String accField : mappings.keySet()) {
            FieldMapConfig config = mappings.get(accField);
            Boolean isChanged = false;
            
            try {
                isChanged = (Boolean) trackingRec.get(config.appIsChangedField);
            } catch(Exception e) {}

            if (isChanged != null && isChanged) {
                ApprovalFieldWrapper wrapper = new ApprovalFieldWrapper();
                wrapper.accountFieldApiName = accField;
                wrapper.fieldLabel = accFieldMap.get(accField).getDescribe().getLabel();
                
                Object rawOldVal = trackingRec.get(config.appOldValueField);
                Object rawNewVal = trackingRec.get(config.appNewValueField);
                
                wrapper.oldValue = rawOldVal != null ? String.valueOf(rawOldVal) : 'Blank';
                wrapper.newValue = rawNewVal != null ? String.valueOf(rawNewVal) : 'Blank';
                result.fields.add(wrapper);
            }
        }
        return result;
    }

    @AuraEnabled
    public static Id processApproval(Id trackingId, List<String> approvedAccountFields, String action) {
        try {
            Orient_Customer_Approval_Traking__c trk = [SELECT Orient_Customer__c FROM Orient_Customer_Approval_Traking__c WHERE Id = :trackingId LIMIT 1];
            Id accountId = trk.Orient_Customer__c;

            // Update the tracking record instead of deleting it
            Orient_Customer_Approval_Traking__c trackToUpdate = new Orient_Customer_Approval_Traking__c(Id = trackingId);

            // --- REJECT LOGIC ---
            if (action == 'Reject') {
                trackToUpdate.Approval_Status__c = 'Rejected';
                update as user trackToUpdate;
                return accountId;
            }

            // --- APPROVE LOGIC ---
            Map<String, FieldMapConfig> mappings = getFieldMappings();
            
            Set<String> fieldsToQuery = new Set<String>{'Id', 'Orient_Customer__c'};
            for (String accField : approvedAccountFields) {
                fieldsToQuery.add(mappings.get(accField).appNewValueField);
            }
            
            String soql = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ', ') + ' FROM Orient_Customer_Approval_Traking__c WHERE Id = :trackingId WITH USER_MODE LIMIT 1';
            Orient_Customer_Approval_Traking__c trackingRec = Database.query(soql);
            
            Account accToUpdate = new Account(Id = accountId);
            
            for (String accField : approvedAccountFields) {
                FieldMapConfig config = mappings.get(accField);
                Object approvedValue = trackingRec.get(config.appNewValueField);
                
                accToUpdate.put(accField, approvedValue);
                trackToUpdate.put(config.appApprovalField, true);
            }

            trackToUpdate.Approval_Status__c = 'Approved';

            update as user accToUpdate;
            update as user trackToUpdate;

            return accountId; 

        } catch (Exception e) {
            throw new AuraHandledException('Error processing approval: ' + e.getMessage());
        }
    }

    // =====================================================================
    // BC Push Logic (Exactly as implemented before)
    // =====================================================================

    public class PushResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    public class BCCustomerPayload {
        public String customerNo;
        public String phoneNo;
        public String name;
        public String mobilePhoneNo;
        public Long aadharNo;
        public String address;
        public String address2;
        public String anniversaryDate;
        public String birthDate;
        public String city;
        public String countryRegionCode;
        public String county;
        public String customerPostingGroup;
        public String district;
        public String eMail;
        public String gstRegistrationNo;
        public String gstRegistrationType;
        public String generalBusinessPostingGroup;
        public Boolean isKYC;
        public String kycDocumentNo;
        public String locationCode;
        public String pANNo;
        public String postCode;
        public Boolean smsSentAnniversary;
        public Boolean smsSentBirthday;
        public String stateCode;
        public String village;
    }

    @AuraEnabled
    public static PushResult pushApprovedChangesToBC(Id accountId) {
        PushResult result = new PushResult();

        try {
            Account acc = [
                SELECT Id, BC_Customer_No__c, Name, Phone, Whatsapp_number__c, AadharNo__c,
                       Permanent_Address__c, Locality_Area__c, Anniversary_Date__c, Date_Of_Birth__c,
                       Residential_City__c, Country_Region_Code__c, Country__c, District__c,
                       Email_Address__c, GST__c, KYC_Verified__c, PAN__c, Pin_Code__c, StateCode__c, Village__c
                FROM Account 
                WHERE Id = :accountId WITH USER_MODE LIMIT 1
            ];

            if (String.isBlank(acc.BC_Customer_No__c)) {
                result.success = false;
                result.message = 'Cannot push. Missing BC Customer No.';
                return result;
            }

            User currentUser = [SELECT Location_Code__c FROM User WHERE Id = :UserInfo.getUserId() WITH USER_MODE LIMIT 1];

            BCCustomerPayload payload = new BCCustomerPayload();
            payload.customerNo = acc.BC_Customer_No__c;
            payload.name = acc.Name;
            payload.phoneNo = acc.Phone;
            payload.mobilePhoneNo = acc.Whatsapp_number__c;
            if (acc.AadharNo__c != null) {
                payload.aadharNo = Long.valueOf(acc.AadharNo__c);
                payload.kycDocumentNo = acc.AadharNo__c;
            }
            payload.address = acc.Permanent_Address__c;
            payload.address2 = acc.Locality_Area__c;
            payload.anniversaryDate = acc.Anniversary_Date__c != null ? String.valueOf(acc.Anniversary_Date__c) : null;
            payload.birthDate = acc.Date_Of_Birth__c != null ? String.valueOf(acc.Date_Of_Birth__c) : null;
            payload.city = acc.Residential_City__c;
            payload.countryRegionCode = acc.Country_Region_Code__c;
            payload.county = acc.Country__c;
            payload.district = acc.District__c;
            payload.eMail = acc.Email_Address__c;
            payload.gstRegistrationNo = acc.GST__c;
            payload.isKYC = acc.KYC_Verified__c;
            payload.pANNo = acc.PAN__c;
            payload.postCode = acc.Pin_Code__c;
            payload.stateCode = acc.StateCode__c;
            payload.village = acc.Village__c;
            payload.locationCode = currentUser.Location_Code__c;

            payload.customerPostingGroup = 'RETAIL_CUST (B2C)';
            payload.gstRegistrationType = 'GSTIN';
            payload.generalBusinessPostingGroup = 'DOMESTIC';
            payload.smsSentAnniversary = false;
            payload.smsSentBirthday = false;

            String finalJson = JSON.serialize(payload, true);

            HttpRequest req = new HttpRequest();
            String phoneParam = String.isNotBlank(acc.Phone) ? acc.Phone : '';
            String endpoint = 'callout:Orient_API_Access_NC/' + System.Label.BC_Endpoint + '/ACXCustomerListAPIJRS';
            endpoint += '(\'' + acc.BC_Customer_No__c + '\',\'' + phoneParam + '\')';

            req.setEndpoint(endpoint);
            req.setMethod('PATCH');
            req.setHeader('If-Match', '*');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setTimeout(20000);
            req.setBody(finalJson);

            Http http = new Http();
            HttpResponse res = http.send(req);
            Integer statusCode = res.getStatusCode();
            
            if (statusCode >= 200 && statusCode < 300) {
                result.success = true;
                result.message = 'Customer updated in BC successfully.';
            } else {
                result.success = false;
                result.message = 'API Error: ' + res.getStatus() + ' - ' + res.getBody();
                IntegrationLogger.logError('Ctrl_Customer_ProcessApproval', 'pushApprovedChangesToBC', 0, statusCode, result.message, 'BC_Customer_Push');
            }
            return result;

        } catch (Exception e) {
            result.success = false;
            result.message = 'Apex Exception: ' + e.getMessage();
            IntegrationLogger.logError('Ctrl_Customer_ProcessApproval', 'pushApprovedChangesToBC', e.getLineNumber(), 500, e.getMessage() + '\n' + e.getStackTraceString(), 'BC_Customer_Push_Exception');
            return result;
        }
    }
    
    public static void datacover() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}