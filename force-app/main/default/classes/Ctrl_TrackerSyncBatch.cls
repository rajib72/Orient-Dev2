public class Ctrl_TrackerSyncBatch implements Database.Batchable<sObject> {

    // Checkboxes that should ALWAYS be checked by default
    private static final Set<String> ALWAYS_TRUE_CHECKBOXES = new Set<String>{
        'Consent_for_Marketing_Communications__c',
        'Buying_Intent__c',
        'Registration_Mode__c',
        'Loyalty_Tier__c',
        'Customer_Verification_KYC__c',
        'KYC_Verified__c'
    };

    // Maps Account Field API Names to Tracker Checkbox API Names
    private static final Map<String, String> FIELD_MAP = new Map<String, String>{
        'AadharNo__c' => 'AadharNo__c',
        'AccountNumber' => 'Account_Number__c',
        'Site' => 'Account_Site__c',
        'AccountSource' => 'Account_Source__c',
        'Age_Group__c' => 'Age_Group__c',
        'Anniversary_Date__c' => 'Anniversary_Date__c',
        'AnnualRevenue' => 'Annual_Revenue__c',
        'BC_Customer_No__c' => 'BC_Customer_No__c',
        'BillingAddress' => 'Billing_Address__c',
        'Buying_Intent__c' => 'Buying_Intent__c',
        'Consent_for_Marketing_Communications__c' => 'Consent_for_Marketing_Communications__c',
        'Country__c' => 'Country__c',
        'Country_Region_Code__c' => 'Country_Region_Code__c',
        'Name' => 'Customer_Name__c',
        'Customer_Notes__c' => 'Customer_Notes__c',
        'OwnerId' => 'Customer_Owner__c',
        'Customer_Photo__c' => 'Customer_Photo__c',
        'IsCustomerPortal' => 'Customer_Portal_Account__c',
        'Customer_Source_Acquisition__c' => 'Customer_Source_Acquisition__c',
        'Customer_Type__c' => 'Customer_Type__c',
        'Customer_Verification_KYC__c' => 'Customer_Verification_KYC__c',
        'Jigsaw' => 'Data_com_Key__c',
        'Date_Of_Birth__c' => 'Date_Of_Birth_DOB__c',
        'Date_of_First_Purchase__c' => 'Date_of_First_Purchase__c',
        'Date_of_Last_Purchase__c' => 'Date_of_Last_Purchase__c',
        'Decision_Maker__c' => 'Decision_Maker__c',
        'Description' => 'Description__c',
        'District__c' => 'District__c',
        'Do_Not_Contact_DNC_Status__c' => 'Do_Not_Contact_DNC_Status__c',
        'Tier' => 'Einstein_Account_Tier__c',
        'Email_Address__c' => 'Email_Address__c',
        'NumberOfEmployees' => 'Employees__c',
        'Family_Type__c' => 'Family_Type__c',
        'Fax' => 'Fax__c',
        'First_Name__c' => 'First_Name__c',
        'Gender__c' => 'Gender__c',
        'Gender_Other__c' => 'Gender_Other__c',
        'GST__c' => 'GST__c',
        'Income_Band__c' => 'Income_Band__c',
        'Industry' => 'Industry__c',
        'Invoice__c' => 'Invoice__c',
        'KYC_Verified__c' => 'KYC_Verified__c',
        'Last_Name__c' => 'Last_Name__c',
        'Lead_Source_Detail__c' => 'Lead_Source_Detail__c',
        'Locality_Area__c' => 'Locality_Area__c',
        'Loyalty_Tier__c' => 'Loyalty_Tier__c',
        'Marital_Status__c' => 'Marital_Status__c',
        'Middle_Name__c' => 'Middle_Name__c',
        'Nationality__c' => 'Nationality__c',
        'Occupation_Profession__c' => 'Occupation_Profession__c',
        'Order__c' => 'Order__c',
        'Ownership' => 'Ownership__c',
        'PAN__c' => 'PAN__c',
        'ParentId' => 'Parent_Customer__c',
        'Permanent_Address__c' => 'Permanent_Address__c',
        'Phone' => 'Phone__c',
        'Photo_URL__c' => 'Photo_URL__c',
        'Pin_Code__c' => 'Pin_Code__c',
        'Preferred_Communication_Channel__c' => 'Preferred_Communication_Channel__c',
        'Preferred_Contact_Time__c' => 'Preferred_Contact_Time__c',
        'Preferred_Gift_Wrapping__c' => 'Preferred_Gift_Wrapping__c',
        'Preferred_Language__c' => 'Preferred_Language__c',
        'Preferred_Language_Other__c' => 'Preferred_Language_Other__c',
        'Preferred_Price_Band_Weight__c' => 'Preferred_Price_Band__c',
        'Preferred_Sales_Executive__c' => 'Preferred_Sales_Executive__c',
        'Preferred_Store__c' => 'Preferred_Store__c',
        'Preferred_Store_Name__c' => 'Preferred_Store_Name__c',
        'Primary_Customer__c' => 'Primary_Customer__c',
        'Purchased_Amount__c' => 'Purchased_Amount__c',
        'Rating' => 'Rating__c',
        'Referral_Source__c' => 'Referral_Source__c',
        'Registration_Mode__c' => 'Registration_Mode__c',
        'Residential_City__c' => 'Residential_City__c',
        'Salesforce_Customer_No__c' => 'Salesforce_Customer_No__c',
        'ShippingAddress' => 'Shipping_Address__c',
        'Sic' => 'SIC_Code__c',
        'SicDesc' => 'SIC_Description__c',
        'State_Province__c' => 'State_Province__c',
        'StateCode__c' => 'State_Code__c',
        'Status__c' => 'Status__c',
        'Tags_Customer_Labels__c' => 'Tags_Customer_Labels__c',
        'TickerSymbol' => 'Ticker_Symbol__c',
        'Title__c' => 'Title__c',
        'Total_Purchased_Amount__c' => 'Total_Purchased_Amount__c',
        'Type' => 'Type__c',
        'Village__c' => 'Village__c',
        'Website' => 'Website__c',
        'Whatsapp_number__c' => 'Whatsapp_number__c'
    };

    public Database.QueryLocator start(Database.BatchableContext bc) {
        List<String> fieldsToQuery = new List<String>(FIELD_MAP.keySet());
        if (!fieldsToQuery.contains('Id')) {
            fieldsToQuery.add('Id');
        }
        
        String query = 'SELECT ' + String.join(fieldsToQuery, ', ') + 
                       ' FROM Account WHERE BC_Customer_No__c != null';
                       
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : scope) {
            accountIds.add(acc.Id);
        }
        
        List<Orient_Customer_Tracking__c> existingTrackers = [
            SELECT Id, Orient_Customer__c 
            FROM Orient_Customer_Tracking__c 
            WHERE Orient_Customer__c IN :accountIds
        ];
        
        Map<Id, Orient_Customer_Tracking__c> accIdToTrackerMap = new Map<Id, Orient_Customer_Tracking__c>();
        for (Orient_Customer_Tracking__c tracker : existingTrackers) {
            accIdToTrackerMap.put(tracker.Orient_Customer__c, tracker);
        }
        
        List<Orient_Customer_Tracking__c> trackersToUpsert = new List<Orient_Customer_Tracking__c>();
        
        for (Account acc : scope) {
            Orient_Customer_Tracking__c currentTracker;
            
            if (accIdToTrackerMap.containsKey(acc.Id)) {
                currentTracker = accIdToTrackerMap.get(acc.Id);
            } else {
                currentTracker = new Orient_Customer_Tracking__c(Orient_Customer__c = acc.Id);
            }
            
            Boolean hasUpdates = false;
            
            for (String accFieldApi : FIELD_MAP.keySet()) {
                String trackerCheckboxApi = FIELD_MAP.get(accFieldApi);
                
                try {
                    Boolean hasValue = false;
                    
                    // --- NEW LOGIC HERE ---
                    if (ALWAYS_TRUE_CHECKBOXES.contains(trackerCheckboxApi)) {
                        hasValue = true;
                    } else {
                        Object fieldValue = acc.get(accFieldApi);
                        if (fieldValue instanceof String) {
                            hasValue = String.isNotBlank((String)fieldValue);
                        } else if (fieldValue instanceof Boolean) {
                            hasValue = (Boolean)fieldValue;
                        } else {
                            hasValue = (fieldValue != null);
                        }
                    }
                    
                    currentTracker.put(trackerCheckboxApi, hasValue);
                    hasUpdates = true;
                    
                } catch (Exception e) {
                    System.debug('Error accessing field ' + accFieldApi + ' on Account ' + acc.Id + ': ' + e.getMessage());
                }
            }
            
            if (hasUpdates || currentTracker.Id == null) {
                trackersToUpsert.add(currentTracker);
            }
        }
        
        if (!trackersToUpsert.isEmpty()) {
            upsert trackersToUpsert;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Tracker Sync Batch complete.');
    }
}