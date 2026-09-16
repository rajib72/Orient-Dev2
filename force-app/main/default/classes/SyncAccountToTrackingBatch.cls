global class SyncAccountToTrackingBatch implements Database.Batchable<sObject> {

    // 1. Query only Accounts that HAVE a BC Customer No
    global Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, Customer_Type__c, Title__c, Name, Gender__c, OwnerId, ParentId, ' +
                       'BC_Customer_No__c, Primary_Customer__c, Salesforce_Customer_No__c, Date_Of_Birth__c, ' +
                       'Preferred_Language__c, Preferred_Store__c, PAN__c, Marital_Status__c, Anniversary_Date__c, ' +
                       'Nationality__c, GST__c, AadharNo__c, Phone, Email_Address__c, ' +
                       'Preferred_Communication_Channel__c, Whatsapp_number__c, Preferred_Contact_Time__c, ' +
                       'Occupation_Profession__c, Preferred_Sales_Executive__c, Preferred_Gift_Wrapping__c, ' +
                       'Family_Type__c, Decision_Maker__c, Description, Permanent_Address__c, Village__c, ' +
                       'State_Province__c, Pin_Code__c, Locality_Area__c, Residential_City__c, District__c, Country__c, ' +
                       '(SELECT Id FROM Orient_Customer_Trackings__r ORDER BY CreatedDate ASC LIMIT 1) ' +
                       'FROM Account ' +
                       'WHERE BC_Customer_No__c != null';
        return Database.getQueryLocator(query);
    }

    // 2. Iterate through the filtered Accounts and update the Tracking record checkboxes
    global void execute(Database.BatchableContext BC, List<Account> scope) {
        List<Orient_Customer_Tracking__c> trackingsToUpdate = new List<Orient_Customer_Tracking__c>();

        for (Account acc : scope) {
            // Check if the Account actually has a tracking child record
            if (acc.Orient_Customer_Trackings__r != null && !acc.Orient_Customer_Trackings__r.isEmpty()) {
                Orient_Customer_Tracking__c tracking = acc.Orient_Customer_Trackings__r[0];

                // --- Basic Information ---
                tracking.Customer_Type__c = (acc.Customer_Type__c != null);
                tracking.Title__c = (acc.Title__c != null);
                tracking.Customer_Name__c = String.isNotBlank(acc.Name);
                tracking.Gender__c = (acc.Gender__c != null);
                tracking.Customer_Owner__c = (acc.OwnerId != null);
                tracking.Parent_Customer__c = (acc.ParentId != null);
                tracking.BC_Customer_No__c = true; // Always true because of SOQL filter
                tracking.Primary_Customer__c = (acc.Primary_Customer__c == true); 
                tracking.Salesforce_Customer_No__c = String.isNotBlank(acc.Salesforce_Customer_No__c);

                // --- Personal Details ---
                tracking.Date_Of_Birth_DOB__c = (acc.Date_Of_Birth__c != null);
                tracking.Preferred_Language__c = (acc.Preferred_Language__c != null);
                tracking.Preferred_Store__c = (acc.Preferred_Store__c != null);
                tracking.PAN__c = String.isNotBlank(acc.PAN__c);
                tracking.Marital_Status__c = (acc.Marital_Status__c != null);
                tracking.Anniversary_Date__c = (acc.Anniversary_Date__c != null);
                tracking.Nationality__c = (acc.Nationality__c != null);
                tracking.GST__c = String.isNotBlank(acc.GST__c);
                tracking.AadharNo__c = String.isNotBlank(acc.AadharNo__c);

                // --- Contact Information ---
                tracking.Phone__c = String.isNotBlank(acc.Phone);
                tracking.Email_Address__c = String.isNotBlank(acc.Email_Address__c);
                tracking.Preferred_Communication_Channel__c = (acc.Preferred_Communication_Channel__c != null);
                tracking.Whatsapp_number__c = String.isNotBlank(acc.Whatsapp_number__c);
                tracking.Preferred_Contact_Time__c = (acc.Preferred_Contact_Time__c != null);

                // --- Customer Preferences ---
                tracking.Occupation_Profession__c = (acc.Occupation_Profession__c != null);
                tracking.Preferred_Sales_Executive__c = (acc.Preferred_Sales_Executive__c != null);
                tracking.Preferred_Gift_Wrapping__c = (acc.Preferred_Gift_Wrapping__c != null);
                tracking.Family_Type__c = (acc.Family_Type__c != null);
                tracking.Decision_Maker__c = (acc.Decision_Maker__c != null);

                // --- Remarks ---
                tracking.Description__c = String.isNotBlank(acc.Description);

                // --- Address ---
                tracking.Permanent_Address__c = String.isNotBlank(acc.Permanent_Address__c); 
                tracking.Village__c = String.isNotBlank(acc.Village__c);
                tracking.State_Province__c = String.isNotBlank(acc.State_Province__c);
                tracking.Pin_Code__c = String.isNotBlank(acc.Pin_Code__c);
                tracking.Locality_Area__c = String.isNotBlank(acc.Locality_Area__c); 
                tracking.Residential_City__c = String.isNotBlank(acc.Residential_City__c);
                tracking.District__c = String.isNotBlank(acc.District__c);
                tracking.Country__c = String.isNotBlank(acc.Country__c);

                trackingsToUpdate.add(tracking);
            }
        }

        // 3. Perform a bulk update on the Tracking records
        if (!trackingsToUpdate.isEmpty()) {
            update trackingsToUpdate;
        }
    }

    global void finish(Database.BatchableContext BC) {
        System.debug('Batch execution complete: Tracking records for Accounts with BC Customer Nos have been synced.');
    }
}