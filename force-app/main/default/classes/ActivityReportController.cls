public with sharing class ActivityReportController {
    
    @AuraEnabled(cacheable=true)
    public static List<Showroom_Visit__c> getVisits(Date startDate, Date endDate) {
        
        if(startDate == null || endDate == null){
            return new List<Showroom_Visit__c>();
        }
        
        return [
            SELECT Id,Customer_Name__c,CUSTOMERlookup__c,Entry_Time__c,Exit_Time__c,
            Store_Interaction_Details__c,Phone__c,Visit_Date__c,Name,Last_Purchased_Date__c,
            Last_Visit_Date__c,Visit_Purpose__c 
            FROM Showroom_Visit__c 
            WHERE Visit_Date__c >= :startDate
            AND Visit_Date__c <= :endDate
            ORDER BY Visit_Date__c ASC
        ];
    }
}