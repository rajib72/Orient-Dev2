public with sharing class Ctrl_PurchaseBehaviourInsights {

    public class CustomerSearchResult {
        @AuraEnabled public Id customerId { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String whatsAppNumber { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String salesforceCustomerNo { get; set; }
        @AuraEnabled public String bcCustomerNo { get; set; }
        @AuraEnabled public String preferredStore { get; set; }
    }

    public class CustomerInsightDetail {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String recordName { get; set; }
        @AuraEnabled public Id customerId { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public Decimal averageTicketSize { get; set; }
        @AuraEnabled public Decimal purchaseFrequency { get; set; }
        @AuraEnabled public Date lastPurchaseDate { get; set; }
        @AuraEnabled public Date nextExpectedPurchaseDate { get; set; }
        @AuraEnabled public String purchaseOccasion { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
        @AuraEnabled public Datetime lastModifiedDate { get; set; }
        @AuraEnabled public String formattedTicketSize { get; set; }
        @AuraEnabled public Integer daysSinceLastPurchase { get; set; }
        @AuraEnabled public Integer daysUntilNextPurchase { get; set; }
        @AuraEnabled public String nextPurchaseStatus { get; set; } // 'OVERDUE', 'DUE_SOON', 'UPCOMING', 'UNSPECIFIED'
        @AuraEnabled public String frequencyTier { get; set; }      // 'High Frequency • VIP', 'Regular Buyer', 'Occasional Buyer'
    }

    public class CustomerInsightPayload {
        @AuraEnabled public CustomerSearchResult customer { get; set; }
        @AuraEnabled public List<CustomerInsightDetail> insights { get; set; }
        @AuraEnabled public CustomerInsightDetail latestInsight { get; set; }
        @AuraEnabled public Boolean hasInsights { get; set; }
        @AuraEnabled public Integer totalInsightsCount { get; set; }
    }

    /**
     * Search customers (Accounts) by Phone or WhatsApp number.
     * Supports exact or partial phone digits.
     */
    @AuraEnabled(cacheable=true)
    public static List<CustomerSearchResult> searchCustomersByPhone(String phoneKey) {
        if (String.isBlank(phoneKey)) {
            return new List<CustomerSearchResult>();
        }

        String rawTerm = phoneKey.trim();
        String searchPattern = '%' + rawTerm + '%';

        // Also create digits-only search if punctuation/spaces exist
        String digitsOnly = rawTerm.replaceAll('[^0-9]', '');
        String digitsPattern = String.isNotBlank(digitsOnly) ? '%' + digitsOnly + '%' : searchPattern;

        List<Account> accounts = [
            SELECT Id, Name, Phone, WhatsApp_Number__c, Email_Address__c,
                   Salesforce_Customer_No__c, BC_Customer_No__c, Preferred_Store_Name__c
            FROM Account
            WHERE Phone LIKE :searchPattern
               OR Phone LIKE :digitsPattern
               OR WhatsApp_Number__c LIKE :searchPattern
               OR WhatsApp_Number__c LIKE :digitsPattern
            ORDER BY CreatedDate DESC
            LIMIT 25
        ];

        List<CustomerSearchResult> results = new List<CustomerSearchResult>();
        for (Account acc : accounts) {
            CustomerSearchResult res = new CustomerSearchResult();
            res.customerId = acc.Id;
            res.customerName = acc.Name;
            res.phone = acc.Phone;
            res.whatsAppNumber = acc.WhatsApp_Number__c;
            res.email = acc.Email_Address__c;
            res.salesforceCustomerNo = acc.Salesforce_Customer_No__c;
            res.bcCustomerNo = acc.BC_Customer_No__c;
            res.preferredStore = acc.Preferred_Store_Name__c;
            results.add(res);
        }
        return results;
    }

    /**
     * Retrieve full Purchase Behaviour Insights payload for a selected Account ID.
     */
    @AuraEnabled
    public static CustomerInsightPayload getCustomerInsightsPayload(Id customerId) {
        if (customerId == null) {
            throw new AuraHandledException('Customer ID is required.');
        }

        List<Account> accList = [
            SELECT Id, Name, Phone, WhatsApp_Number__c, Email_Address__c,
                   Salesforce_Customer_No__c, BC_Customer_No__c, Preferred_Store_Name__c
            FROM Account
            WHERE Id = :customerId
            LIMIT 1
        ];

        if (accList.isEmpty()) {
            throw new AuraHandledException('Customer record not found for Id: ' + customerId);
        }

        Account acc = accList[0];

        CustomerSearchResult custResult = new CustomerSearchResult();
        custResult.customerId = acc.Id;
        custResult.customerName = acc.Name;
        custResult.phone = acc.Phone;
        custResult.whatsAppNumber = acc.WhatsApp_Number__c;
        custResult.email = acc.Email_Address__c;
        custResult.salesforceCustomerNo = acc.Salesforce_Customer_No__c;
        custResult.bcCustomerNo = acc.BC_Customer_No__c;
        custResult.preferredStore = acc.Preferred_Store_Name__c;

        List<Purchase_Behaviour_Insights__c> pbiList = [
            SELECT Id, Name, Customer_Name__c,
                   Average_Ticket_Size__c, Purchase_Frequency__c,
                   Last_Purchase_Date__c, Next_Expected_Purchase_Date__c,
                   Purchase_Occasion__c, CreatedDate, LastModifiedDate
            FROM Purchase_Behaviour_Insights__c
            WHERE Customer_Name__c = :customerId
            ORDER BY Last_Purchase_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 50
        ];

        CustomerInsightPayload payload = new CustomerInsightPayload();
        payload.customer = custResult;
        payload.insights = new List<CustomerInsightDetail>();
        payload.totalInsightsCount = pbiList.size();
        payload.hasInsights = !pbiList.isEmpty();

        Date today = Date.today();

        for (Purchase_Behaviour_Insights__c pbi : pbiList) {
            CustomerInsightDetail detail = new CustomerInsightDetail();
            detail.recordId = pbi.Id;
            detail.recordName = pbi.Name;
            detail.customerId = pbi.Customer_Name__c;
            detail.customerName = acc.Name;
            detail.averageTicketSize = pbi.Average_Ticket_Size__c;
            detail.purchaseFrequency = pbi.Purchase_Frequency__c;
            detail.lastPurchaseDate = pbi.Last_Purchase_Date__c;
            detail.nextExpectedPurchaseDate = pbi.Next_Expected_Purchase_Date__c;
            detail.purchaseOccasion = pbi.Purchase_Occasion__c;
            detail.createdDate = pbi.CreatedDate;
            detail.lastModifiedDate = pbi.LastModifiedDate;

            // Formatted Ticket Size
            if (detail.averageTicketSize != null) {
                detail.formattedTicketSize = '₹ ' + String.valueOf(detail.averageTicketSize.setScale(0).format());
            } else {
                detail.formattedTicketSize = '₹ 0';
            }

            // Days since last purchase
            if (detail.lastPurchaseDate != null) {
                detail.daysSinceLastPurchase = detail.lastPurchaseDate.daysBetween(today);
            }

            // Days until next purchase & status
            if (detail.nextExpectedPurchaseDate != null) {
                detail.daysUntilNextPurchase = today.daysBetween(detail.nextExpectedPurchaseDate);
                if (detail.daysUntilNextPurchase < 0) {
                    detail.nextPurchaseStatus = 'OVERDUE';
                } else if (detail.daysUntilNextPurchase <= 15) {
                    detail.nextPurchaseStatus = 'DUE_SOON';
                } else {
                    detail.nextPurchaseStatus = 'UPCOMING';
                }
            } else {
                detail.nextPurchaseStatus = 'UNSPECIFIED';
            }

            // Frequency tier
            if (detail.purchaseFrequency != null) {
                if (detail.purchaseFrequency >= 4) {
                    detail.frequencyTier = 'High Frequency • VIP';
                } else if (detail.purchaseFrequency >= 2) {
                    detail.frequencyTier = 'Regular Buyer';
                } else {
                    detail.frequencyTier = 'Occasional Buyer';
                }
            } else {
                detail.frequencyTier = 'Not Evaluated';
            }

            payload.insights.add(detail);
        }

        if (!payload.insights.isEmpty()) {
            payload.latestInsight = payload.insights[0];
        }

        return payload;
    }

    /**
     * Resolves context automatically when recordId is provided (Account or Purchase_Behaviour_Insights__c).
     */
    @AuraEnabled
    public static CustomerInsightPayload resolveRecordContext(Id recordId) {
        if (recordId == null) {
            return null;
        }

        String sObjName = recordId.getSobjectType().getDescribe().getName();

        if (sObjName == 'Account') {
            return getCustomerInsightsPayload(recordId);
        } else if (sObjName == 'Purchase_Behaviour_Insights__c') {
            List<Purchase_Behaviour_Insights__c> pbiList = [
                SELECT Customer_Name__c
                FROM Purchase_Behaviour_Insights__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (!pbiList.isEmpty() && pbiList[0].Customer_Name__c != null) {
                return getCustomerInsightsPayload(pbiList[0].Customer_Name__c);
            }
        }

        return null;
    }
}