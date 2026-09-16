public with sharing class CustomerEnrollmentController {

    //SAVE CUSTOMER RECORD
   @AuraEnabled
public static Account saveCustomer(Map<String, Object> formData) {
    Account cust = new Account();

    // Dynamically map all incoming Account fields
    for (String key : formData.keySet()) {
        if (Schema.sObjectType.Account.fields.getMap().containsKey(key)) {
            Schema.DescribeFieldResult fieldDescribe =
                Schema.sObjectType.Account.fields.getMap().get(key).getDescribe();

            // Handle DATE fields safely
            if (fieldDescribe.getType() == Schema.DisplayType.Date) {

                if (formData.get(key) != null && formData.get(key) instanceof String) {
                    Date dateVal;

                    try {
                        dateVal = Date.valueOf((String)formData.get(key));
                    } catch (Exception ex) {
                        throw new AuraHandledException('Invalid date format for ' + key);
                    }

                    // Server-side DOB validation
                    if (key == 'Date_Of_Birth__c' && dateVal >= Date.today()) {
                        throw new AuraHandledException(
                            'Enter valid DOB. DOB cannot be today or a future date'
                        );
                    }

                    cust.put(key, dateVal);
                }

            } else {
                // Non-date fields
                cust.put(key, formData.get(key));
            }
        }
    }

    // // Auto-map custom address fields → Billing & Shipping fields
    // if (formData.containsKey('Residential_City__c'))
    //     cust.BillingCity = (String) formData.get('Residential_City__c');
    // if (formData.containsKey('Locality_Area__c'))
    //     cust.BillingStreet = (String) formData.get('Locality_Area__c');
    // if (formData.containsKey('Pin_Code__c'))
    //     cust.BillingPostalCode = (String) formData.get('Pin_Code__c');
    // if (formData.containsKey('State_Province__c'))
    //     cust.BillingState = (String) formData.get('State_Province__c');
    // if (formData.containsKey('Country__c'))
    //     cust.BillingCountry = (String) formData.get('Country__c');

    // // Shipping address = EXACT same mapping
    // if (formData.containsKey('Residential_City__c'))
    //     cust.ShippingCity = (String) formData.get('Residential_City__c');
    // if (formData.containsKey('Locality_Area__c'))
    //     cust.ShippingStreet = (String) formData.get('Locality_Area__c');
    // if (formData.containsKey('Pin_Code__c'))
    //     cust.ShippingPostalCode = (String) formData.get('Pin_Code__c');
    // if (formData.containsKey('State_Province__c'))
    //     cust.ShippingState = (String) formData.get('State_Province__c');
    // if (formData.containsKey('Country__c'))
    //     cust.ShippingCountry = (String) formData.get('Country__c');

    // Default status if not provided
    if (!formData.containsKey('Status__c') ||
        String.isBlank(String.valueOf(formData.get('Status__c')))) {
        cust.Status__c = 'Prospect';
    }

    
    String phoneNo = String.isBlank(cust.Phone) ? null : cust.Phone.trim();

    String whatsappNo;
    if (cust.get('Whatsapp_number__c') != null) {
        whatsappNo = String.valueOf(cust.get('Whatsapp_number__c')).trim();
    }

    if (!String.isBlank(phoneNo) || !String.isBlank(whatsappNo)) {

        List<Account> existingAccounts = [
            SELECT Id, Name, Phone, Whatsapp_number__c
            FROM Account
            WHERE
                Phone = :phoneNo
                OR Phone = :whatsappNo
                OR Whatsapp_number__c = :phoneNo
                OR Whatsapp_number__c = :whatsappNo
            LIMIT 1
        ];

        if (!existingAccounts.isEmpty()) {
            throw new AuraHandledException(
                'Account already exists with same Phone or WhatsApp Number.'
            );
        }
    }

    // Save account
    try {
        insert cust;
    } catch (Exception e) {
        throw new AuraHandledException('Error saving customer: ' + e.getMessage());
    }

    return cust;
}

    //FETCH PICKLIST VALUES
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPicklistValues() {

        Map<String, List<String>> picklistMap = new Map<String, List<String>>();

        // All picklists you want to load
        List<String> picklistFields = new List<String>{
            'Title__c','Customer_Type__c','Gender__c','Marital_Status__c','Preferred_Language__c',
            'Nationality__c','Occupation_Profession__c','Family_Type__c','Decision_Maker__c','Preferred_Store__c',
            'Customer_Source_Acquisition__c','Customer_Verification__c','Preferred_Price_Band_Weight__c','Buying_Intent__c',
            'Tags_Customer_Labels__c','Do_Not_Contact_DNC_Status__c','Preferred_Gift_Wrapping__c','Consent_for_Marketing_Communications__c',
            'Income_Band__c','Registration_Mode__c','KYC_Verified__c','Preferred_Contact_Time__c',
            'Preferred_Communication_Channel__c','Customer_Verification_KYC__c','Status__c'
        };

        Schema.DescribeSObjectResult accountDescribe = Account.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> fieldsMap = accountDescribe.fields.getMap();

        for (String fieldName : picklistFields) {
            if (fieldsMap.containsKey(fieldName)) {
                List<String> values = new List<String>();
                Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();

                for (Schema.PicklistEntry pe : fieldDescribe.getPicklistValues()) {
                    if (pe.isActive()) values.add(pe.getValue());
                }

                picklistMap.put(fieldName, values);
            }
        }

        return picklistMap;
    }

    //UPLOAD FILE TO ACCOUNT
    @AuraEnabled
    public static void uploadFile(Id parentId, String fileName, String base64Data) {
        try {
            Blob fileBody = EncodingUtil.base64Decode(base64Data);

            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = fileBody;
            cv.FirstPublishLocationId = parentId;

            insert cv;

        } catch (Exception e) {
            throw new AuraHandledException('File upload failed: ' + e.getMessage());
        }
    }

    //GET ACTIVE USERS FOR SALES EXECUTIVE PICKLIST
    @AuraEnabled(cacheable=true)
    public static List<User> getActiveUsers() {

        return [
            SELECT Id, Name
            FROM User
            WHERE IsActive = TRUE
            ORDER BY Name
            LIMIT 200
        ];
    }

}