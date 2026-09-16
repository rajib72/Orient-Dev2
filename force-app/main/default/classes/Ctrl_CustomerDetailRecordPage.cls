public with sharing class Ctrl_CustomerDetailRecordPage {
    
    @AuraEnabled(cacheable=true)
    public static Orient_Customer_Tracking__c getTrackingRecord(Id accountId) {
        try {
            List<Orient_Customer_Tracking__c> trackingRecords = [
                SELECT Id, AadharNo__c, Age_Group__c, Anniversary_Date__c, BC_Customer_No__c, 
                       Buying_Intent__c, Consent_for_Marketing_Communications__c, Country__c, 
                       Country_Region_Code__c, Customer_Name__c, Customer_Notes__c, Customer_Owner__c, 
                       Customer_Source_Acquisition__c, Customer_Type__c, Customer_Verification_KYC__c, 
                       Date_Of_Birth_DOB__c, Date_of_First_Purchase__c, Date_of_Last_Purchase__c, 
                       Decision_Maker__c, Description__c, District__c, Do_Not_Contact_DNC_Status__c, 
                       Email_Address__c, Family_Type__c, Gender__c, Gender_Other__c, GST__c, Income_Band__c, 
                       KYC_Verified__c, Lead_Source_Detail__c, Locality_Area__c, Loyalty_Tier__c, 
                       Marital_Status__c, Nationality__c, Occupation_Profession__c, PAN__c, 
                       Parent_Customer__c, Permanent_Address__c, Phone__c, Pin_Code__c, 
                       Preferred_Communication_Channel__c, Preferred_Contact_Time__c, 
                       Preferred_Gift_Wrapping__c, Preferred_Language__c, Preferred_Language_Other__c, Preferred_Price_Band__c, 
                       Preferred_Sales_Executive__c, Preferred_Store__c, Primary_Customer__c, 
                       Referral_Source__c, Registration_Mode__c, Residential_City__c, 
                       Salesforce_Customer_No__c, State_Province__c, State_Code__c, 
                       Tags_Customer_Labels__c, Title__c, Total_Purchased_Amount__c, Village__c, 
                       Whatsapp_number__c, Landmark__c, Voter__c
                FROM Orient_Customer_Tracking__c
                WHERE Orient_Customer__c = :accountId
                WITH USER_MODE
                LIMIT 1
            ];
            
            if (!trackingRecords.isEmpty()) {
                return trackingRecords[0];
            }
            return null;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching tracking record permissions: ' + e.getMessage());
        }
    }

    // Changed return type from Boolean to Account to retrieve duplicate details
    @AuraEnabled
    public static Account checkDuplicateAccount(String phoneNo, String whatsappNo, Id recordId) {
        List<Account> duplicateList = new List<Account>();

        if (String.isNotBlank(phoneNo) && String.isNotBlank(whatsappNo)) {
            duplicateList = [SELECT Id, Name, Phone, Whatsapp_number__c FROM Account 
                             WHERE Id != :recordId 
                             AND (Phone = :phoneNo OR Whatsapp_number__c = :whatsappNo) 
                             WITH USER_MODE
                             LIMIT 1];
        } else if (String.isNotBlank(phoneNo)) {
            duplicateList = [SELECT Id, Name, Phone, Whatsapp_number__c FROM Account 
                             WHERE Id != :recordId 
                             AND Phone = :phoneNo 
                             WITH USER_MODE
                             LIMIT 1];
        } else if (String.isNotBlank(whatsappNo)) {
            duplicateList = [SELECT Id, Name, Phone, Whatsapp_number__c FROM Account 
                             WHERE Id != :recordId 
                             AND Whatsapp_number__c = :whatsappNo 
                             WITH USER_MODE
                             LIMIT 1];
        }

        return !duplicateList.isEmpty() ? duplicateList[0] : null;
    }

    // New Method for Inactivating Account and mapping Showroom Visits
    @AuraEnabled
    public static void mergeAndInactiveAccount(Id currentAccountId, Id existingAccountId) {
        try {
            // 1. Mark the current account as Inactive
            Account currentAcc = new Account(Id = currentAccountId, Status__c = 'Inactive');
            update as user currentAcc;

            // 2. Fetch and Re-parent Showroom Visits
            List<Showroom_Visit__c> visitsToUpdate = [SELECT Id, CUSTOMERlookup__c 
                                                      FROM Showroom_Visit__c 
                                                      WHERE CUSTOMERlookup__c = :currentAccountId 
                                                      WITH USER_MODE];
            
            if (!visitsToUpdate.isEmpty()) {
                for(Showroom_Visit__c sv : visitsToUpdate) {
                    sv.CUSTOMERlookup__c = existingAccountId;
                }
                update as user visitsToUpdate;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error executing merge operation: ' + e.getMessage());
        }
    }
}