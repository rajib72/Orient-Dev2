public with sharing class Ctrl_ReassignSalesExecutive {
    
    @AuraEnabled(cacheable=true)
    public static List<Sales_Executives__c> getSalesExecutives() {
        // 1. Get Current User's Location Code
        Id userId = UserInfo.getUserId();
        User currentUser = [SELECT Location_Code__c FROM User WHERE Id = :userId LIMIT 1];
        
        if (String.isBlank(currentUser.Location_Code__c)) {
            return new List<Sales_Executives__c>();
        }
        
        // 2. Get Store matching the Location Code
        List<Store__c> stores = [SELECT Id FROM Store__c WHERE Store_Code__c = :currentUser.Location_Code__c LIMIT 1];
        if (stores.isEmpty()) {
            return new List<Sales_Executives__c>();
        }
        
        // 3. Get Sales Executives for that Store
        return [SELECT Id, Name FROM Sales_Executives__c WHERE Store__c = :stores[0].Id ORDER BY Name ASC];
    }
    
    @AuraEnabled
    public static void reassignAndLogActivity(Id showroomVisitId, Id salesExecutiveId) {
        try {
            // Get Current Showroom Visit to map the Customer Lookup
            Showroom_Visit__c visit = [
                SELECT Id, CUSTOMERlookup__c 
                FROM Showroom_Visit__c 
                WHERE Id = :showroomVisitId 
                LIMIT 1
            ];
            
            // --- IST TIMEZONE CONVERSION ---
            Datetime now = Datetime.now();
            
            // Format time and date specifically for IST ('Asia/Kolkata')
            String istTimeString = now.format('HH:mm:ss', 'Asia/Kolkata');
            String istDateString = now.format('yyyy-MM-dd', 'Asia/Kolkata');
            
            // Parse strings into standard Salesforce Date/Time objects
            String[] timeParts = istTimeString.split(':');
            Time istTime = Time.newInstance(
                Integer.valueOf(timeParts[0]), 
                Integer.valueOf(timeParts[1]), 
                Integer.valueOf(timeParts[2]), 
                0
            );
            Date istDate = Date.valueOf(istDateString);
            
            // Create Sales Executive Tracking History
            Sales_Executive_Activity_Tracking__c tracking = new Sales_Executive_Activity_Tracking__c(
                Orient_Customer__c = visit.CUSTOMERlookup__c,
                Sales_Executive__c = salesExecutiveId,
                Session_Start_Time__c = istTime,
                Session_Starting_Date__c = istDate,
                Session_Status__c = 'Active',
                Showroom_Visit__c = showroomVisitId
            );
            insert tracking;
            
            // Update Showroom Visit Exited status
            visit.Marked_As_Exited__c = false;
            update visit;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}