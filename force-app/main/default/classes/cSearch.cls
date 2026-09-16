public with sharing class cSearch {

   

    // Search accounts by phone
// Search accounts by phone / whatsapp from starting digits only
@AuraEnabled(cacheable=true)
public static List<Account> searchAccountsByPhone(String phoneKey) {

    if (String.isBlank(phoneKey)) {
        return new List<Account>();
    }

    String searchKey = phoneKey.trim() + '%';

    return [
        SELECT Id, Name, Phone, WhatsApp_Number__c
        FROM Account
        WHERE Phone LIKE :searchKey
           OR WhatsApp_Number__c LIKE :searchKey
        ORDER BY CreatedDate DESC
        LIMIT 10
    ];
}

    // Search today's showroom visits by customer phone
    @AuraEnabled(cacheable=true)
    public static List<Showroom_Visit__c> searchVisitsByPhone(String phoneKey) {
        if (String.isBlank(phoneKey)) {
            return new List<Showroom_Visit__c>();
        }

        String searchKey = phoneKey.trim() + '%';

        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE Phone LIKE :searchKey
               OR WhatsApp_Number__c LIKE :searchKey
        ];

        if (accounts.isEmpty()) {
            return new List<Showroom_Visit__c>();
        }

        Set<Id> accIds = new Set<Id>();
        for (Account acc : accounts) {
            accIds.add(acc.Id);
        }

        Date todayDate = Date.today();
        
        return [
            SELECT Id, Name, CUSTOMERlookup__c, CUSTOMERlookup__r.Name, CUSTOMERlookup__r.Phone,
                   CUSTOMERlookup__r.WhatsApp_Number__c, CUSTOMERlookup__r.Email_Address__c, CUSTOMERlookup__r.Date_Of_Birth__c, CUSTOMERlookup__r.Anniversary_Date__c,
                   CUSTOMERlookup__r.Salesforce_Customer_No__c, CUSTOMERlookup__r.BC_Customer_No__c, CUSTOMERlookup__r.DOB_Verified__c,
                   StoreLookup__c, StoreLookup__r.Name, Marked_As_Exited__c, CreatedDate,
                   Visit_Date__c, Entry_Time__c,
                   (SELECT Id, Status__c, Submitted_Date_Time__c FROM Feedbacks__r LIMIT 1)
            FROM Showroom_Visit__c
            WHERE CUSTOMERlookup__c IN :accIds
            AND DAY_ONLY(CreatedDate) = :todayDate
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * Single round trip for the feedback kiosk: resolves the customer by phone /
     * WhatsApp and returns today's showroom visits alongside them. The customer is
     * returned even when there is no visit today, so the profile screen can still open.
     */
    @AuraEnabled(cacheable=true)
    public static CustomerJourneyWrapper searchCustomerJourney(String phoneKey) {
        CustomerJourneyWrapper result = new CustomerJourneyWrapper();
        result.visits = new List<Showroom_Visit__c>();

        if (String.isBlank(phoneKey)) {
            return result;
        }

        String searchKey = phoneKey.trim() + '%';

        List<Account> accounts = [
            SELECT Id, Name, Phone, WhatsApp_Number__c, Email_Address__c,
                   Date_Of_Birth__c, Anniversary_Date__c,
                   Salesforce_Customer_No__c, BC_Customer_No__c, DOB_Verified__c
            FROM Account
            WHERE Phone LIKE :searchKey
               OR WhatsApp_Number__c LIKE :searchKey
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];

        if (accounts.isEmpty()) {
            return result;
        }

        result.customer = accounts[0];

        Set<Id> accIds = new Set<Id>();
        for (Account acc : accounts) {
            accIds.add(acc.Id);
        }

        Date todayDate = Date.today();

        result.visits = [
            SELECT Id, Name, CUSTOMERlookup__c, CUSTOMERlookup__r.Name, CUSTOMERlookup__r.Phone,
                   CUSTOMERlookup__r.WhatsApp_Number__c, CUSTOMERlookup__r.Email_Address__c,
                   CUSTOMERlookup__r.Date_Of_Birth__c, CUSTOMERlookup__r.Anniversary_Date__c,
                   CUSTOMERlookup__r.Salesforce_Customer_No__c, CUSTOMERlookup__r.BC_Customer_No__c,
                   CUSTOMERlookup__r.DOB_Verified__c,
                   StoreLookup__c, StoreLookup__r.Name, Marked_As_Exited__c, CreatedDate,
                   Visit_Date__c, Entry_Time__c,
                   (SELECT Id, Status__c, Submitted_Date_Time__c FROM Feedbacks__r LIMIT 1)
            FROM Showroom_Visit__c
            WHERE CUSTOMERlookup__c IN :accIds
            AND DAY_ONLY(CreatedDate) = :todayDate
            ORDER BY CreatedDate DESC
        ];

        return result;
    }

    public class CustomerJourneyWrapper {
        @AuraEnabled public Account customer;
        @AuraEnabled public List<Showroom_Visit__c> visits;
    }

    // Get Customer Summary for selected account
    @AuraEnabled(cacheable=true)
    public static List<CustomerSummaryWrapper> getCustomerSummary(Id accountId) {

        List<CustomerSummaryWrapper> wrapperList = new List<CustomerSummaryWrapper>();

        Account acc = [SELECT Id, Name, Phone FROM Account WHERE Id = :accountId LIMIT 1];

        Showroom_Visit__c visit;
        List<Showroom_Visit__c> visitList = [
            SELECT Last_Purchased_Date__c, Last_Visit_Date__c
            FROM Showroom_Visit__c
            WHERE CUSTOMERlookup__c = :acc.Id
            ORDER BY Last_Visit_Date__c DESC
            LIMIT 1
        ];

        if(!visitList.isEmpty()) visit = visitList[0];

        AggregateResult ag = [
            SELECT SUM(Total_Invoice_Amount__c) total
            FROM Invoice__c
            WHERE Customer_Name__c = :acc.Id
        ];

        CustomerSummaryWrapper cw = new CustomerSummaryWrapper();
        cw.CustomerName = acc.Name;
        cw.Phone = acc.Phone;
        cw.LastPurchasedDate = visit != null ? visit.Last_Purchased_Date__c : null;
        cw.LastVisitDate = visit != null ? visit.Last_Visit_Date__c : null;
        cw.TotalInvoiceAmount = (Decimal)ag.get('total');
        cw.AccountId = acc.Id;

        wrapperList.add(cw);
        return wrapperList;
    }

    public class CustomerSummaryWrapper {
        @AuraEnabled public String CustomerName;
        @AuraEnabled public String Phone;
        @AuraEnabled public Date LastPurchasedDate;
        @AuraEnabled public Date LastVisitDate;
        @AuraEnabled public Decimal TotalInvoiceAmount;
        @AuraEnabled public Id AccountId;   // ✅ Added for navigation
    }
}