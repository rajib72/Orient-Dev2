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

    public class FieldDetail {
        @AuraEnabled public String apiName { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String displayType { get; set; } // TEXT, NUMBER, CURRENCY, DATE, DATETIME, BOOLEAN, PERCENT, PICKLIST, TEXTAREA
        @AuraEnabled public String badgeClass { get; set; }
        @AuraEnabled public Boolean isBoolean { get; set; }
        @AuraEnabled public Boolean isHighlight { get; set; }
        @AuraEnabled public String helpText { get; set; }
    }

    public class InsightCategory {
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String objectLabel { get; set; }
        @AuraEnabled public String categoryKey { get; set; }
        @AuraEnabled public String shortCode { get; set; }
        @AuraEnabled public String icon { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Boolean hasRecord { get; set; }
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String recordName { get; set; }
        @AuraEnabled public Integer fieldCount { get; set; }
        @AuraEnabled public String formattedLastModified { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
        @AuraEnabled public Datetime lastModifiedDate { get; set; }
        @AuraEnabled public List<FieldDetail> fields { get; set; }
    }

    public class CustomerInsightPayload {
        @AuraEnabled public CustomerSearchResult customer { get; set; }
        @AuraEnabled public List<CustomerInsightDetail> insights { get; set; }
        @AuraEnabled public CustomerInsightDetail latestInsight { get; set; }
        @AuraEnabled public Boolean hasInsights { get; set; }
        @AuraEnabled public Integer totalInsightsCount { get; set; }
        @AuraEnabled public List<InsightCategory> categories { get; set; }
        @AuraEnabled public Integer totalCategoriesCount { get; set; }
        @AuraEnabled public Integer activeCategoriesCount { get; set; }
        @AuraEnabled public Integer totalFieldsCount { get; set; }
    }

    private class CategoryConfig {
        public String objectApiName;
        public String objectLabel;
        public String categoryKey;
        public String shortCode;
        public String icon;
        public String description;

        public CategoryConfig(String objName, String label, String key, String code, String icon, String descText) {
            this.objectApiName = objName;
            this.objectLabel = label;
            this.categoryKey = key;
            this.shortCode = code;
            this.icon = icon;
            this.description = descText;
        }
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
     * Retrieve full Customer 360 Insights payload for a selected Account ID across all 13 modules.
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

        // 1. Existing Purchase Behaviour Insights records query
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

        // 2. Build all 13 Insight Categories with all their custom fields
        payload.categories = buildAllInsightCategories(customerId);
        payload.totalCategoriesCount = payload.categories.size();

        Integer activeCount = 0;
        Integer fieldCount = 0;
        for (InsightCategory cat : payload.categories) {
            if (cat.hasRecord) {
                activeCount++;
                fieldCount += cat.fieldCount != null ? cat.fieldCount : 0;
            }
        }
        payload.activeCategoriesCount = activeCount;
        payload.totalFieldsCount = fieldCount;

        return payload;
    }

    /**
     * Resolves context automatically when recordId is provided (Account or any of the 13 Insight objects).
     */
    @AuraEnabled
    public static CustomerInsightPayload resolveRecordContext(Id recordId) {
        if (recordId == null) {
            return null;
        }

        String sObjName = recordId.getSobjectType().getDescribe().getName();

        if (sObjName == 'Account') {
            return getCustomerInsightsPayload(recordId);
        }

        Set<String> insightObjects = new Set<String>{
            'Purchase_Behaviour_Insights__c',
            'Loyalty_Retention_Insights__c',
            'Product_Design_Preference_Insights__c',
            'Service_After_Sales_Insights__c',
            'Digital_Omni_Channel_Insights__c',
            'Financial_Scheme_Insights__c',
            'Visit_Store_Interaction_Insights__c',
            'Customer_Satisfaction_NPS_Insights__c',
            'Loyalty_Reward_Insights__c',
            'Risk_Compliance_Insights__c',
            'Referral_Advocacy_Insights__c',
            'Event_Occasion_Insights__c',
            'Engagement_Communication_Insights__c'
        };

        if (insightObjects.contains(sObjName)) {
            String soql = 'SELECT Customer_Name__c FROM ' + String.escapeSingleQuotes(sObjName) + ' WHERE Id = :recordId LIMIT 1';
            List<SObject> recs = Database.query(soql);
            if (!recs.isEmpty() && recs[0].get('Customer_Name__c') != null) {
                return getCustomerInsightsPayload((Id)recs[0].get('Customer_Name__c'));
            }
        }

        return null;
    }

    /**
     * Dynamically constructs metadata and queries data for all 13 Insight objects.
     */
    private static List<InsightCategory> buildAllInsightCategories(Id customerId) {
        List<CategoryConfig> configs = new List<CategoryConfig>{
            new CategoryConfig('Purchase_Behaviour_Insights__c', 'Purchase Behaviour Insights', 'purchase_behaviour', 'PBI', 'utility:cart', 'Ticket sizes, purchase cadences, buying frequency, and upcoming expected purchase dates'),
            new CategoryConfig('Loyalty_Retention_Insights__c', 'Loyalty & Retention Insights', 'loyalty_retention', 'LRI', 'utility:ribbon', 'Customer lifetime value, retention risk, loyalty milestones, and membership tiers'),
            new CategoryConfig('Product_Design_Preference_Insights__c', 'Product & Design Preferences', 'product_design', 'PDP', 'utility:magicwand', 'Gold karats, diamond affinities, jewellery categories, design styles, and craftsmanship preferences'),
            new CategoryConfig('Service_After_Sales_Insights__c', 'Service & After-Sales Insights', 'service_after_sales', 'SAS', 'utility:maintenance', 'Jewellery cleaning, repairs, resizing, warranty claims, and after-sales service satisfaction'),
            new CategoryConfig('Digital_Omni_Channel_Insights__c', 'Digital & Omni-Channel Insights', 'digital_omnichannel', 'DOC', 'utility:touch_action', 'App usage, website browsing, virtual try-ons, cart abandonment, and omni-channel touchpoints'),
            new CategoryConfig('Financial_Scheme_Insights__c', 'Financial & Scheme Insights', 'financial_schemes', 'FSI', 'utility:moneybag', 'Gold savings schemes, EMI utilization, advance booking plans, and payment preferences'),
            new CategoryConfig('Visit_Store_Interaction_Insights__c', 'Visit & Store Interaction Insights', 'visit_store', 'VSI', 'utility:checkin', 'Showroom footfall, preferred branches, visit durations, staff interactions, and lounge visits'),
            new CategoryConfig('Customer_Satisfaction_NPS_Insights__c', 'Customer Satisfaction & NPS', 'satisfaction_nps', 'CSN', 'utility:like', 'Net Promoter Score, sentiment ratings, staff behaviour feedback, and resolution scores'),
            new CategoryConfig('Loyalty_Reward_Insights__c', 'Loyalty & Reward Insights', 'loyalty_rewards', 'LRO', 'utility:award', 'Loyalty point balances, expiry dates, reward redemptions, and coupon utilization'),
            new CategoryConfig('Risk_Compliance_Insights__c', 'Risk & Compliance Insights', 'risk_compliance', 'RCI', 'utility:shield', 'KYC verification, PAN/Aadhaar status, AML compliance, return abuse, and fraud risk monitoring'),
            new CategoryConfig('Referral_Advocacy_Insights__c', 'Referral & Advocacy Insights', 'referral_advocacy', 'RAI', 'utility:share', 'Customer referrals, advocacy tiers, social media reviews, testimonials, and influencer score'),
            new CategoryConfig('Event_Occasion_Insights__c', 'Event & Occasion Insights', 'event_occasions', 'EOI', 'utility:event', 'Upcoming anniversaries, birthdays, weddings, festive calendars, and occasion budgets'),
            new CategoryConfig('Engagement_Communication_Insights__c', 'Engagement & Communication Insights', 'engagement_comm', 'ECI', 'utility:chat', 'WhatsApp engagement, SMS response rate, email open rates, campaign responses, and channel preferences')
        };

        List<InsightCategory> result = new List<InsightCategory>();

        for (CategoryConfig cfg : configs) {
            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(cfg.objectApiName);
            if (sObjType == null) {
                continue;
            }

            Schema.DescribeSObjectResult ds = sObjType.getDescribe();
            if (!ds.isAccessible()) {
                continue;
            }

            InsightCategory cat = new InsightCategory();
            cat.objectApiName = cfg.objectApiName;
            cat.objectLabel = cfg.objectLabel;
            cat.categoryKey = cfg.categoryKey;
            cat.shortCode = cfg.shortCode;
            cat.icon = cfg.icon;
            cat.description = cfg.description;
            cat.hasRecord = false;
            cat.fields = new List<FieldDetail>();
            cat.fieldCount = 0;

            Map<String, Schema.SObjectField> fieldMap = ds.fields.getMap();

            // Collect all custom fields and queryable fields
            Set<String> queryFields = new Set<String>{ 'Id', 'Name', 'CreatedDate', 'LastModifiedDate' };
            List<Schema.DescribeFieldResult> customFieldDescribes = new List<Schema.DescribeFieldResult>();

            for (Schema.SObjectField fld : fieldMap.values()) {
                Schema.DescribeFieldResult dfr = fld.getDescribe();
                String fname = dfr.getName();
                if (dfr.isAccessible() && fname.endsWith('__c') && fname != 'Customer_Name__c') {
                    queryFields.add(fname);
                    customFieldDescribes.add(dfr);
                }
            }

            // Query latest record for this customer
            List<String> fieldList = new List<String>(queryFields);
            String soql = 'SELECT ' + String.join(fieldList, ', ') +
                          ' FROM ' + String.escapeSingleQuotes(cfg.objectApiName) +
                          ' WHERE Customer_Name__c = :customerId' +
                          ' ORDER BY LastModifiedDate DESC LIMIT 1';

            List<SObject> records = Database.query(soql);

            if (!records.isEmpty()) {
                SObject rec = records[0];
                cat.hasRecord = true;
                cat.recordId = rec.Id;
                cat.recordName = (String)rec.get('Name');
                cat.createdDate = (Datetime)rec.get('CreatedDate');
                cat.lastModifiedDate = (Datetime)rec.get('LastModifiedDate');

                if (cat.lastModifiedDate != null) {
                    cat.formattedLastModified = cat.lastModifiedDate.format('dd MMM yyyy, hh:mm a');
                }

                // Sort fields alphabetically by label
                Map<String, Schema.DescribeFieldResult> sortedMap = new Map<String, Schema.DescribeFieldResult>();
                List<String> sortKeys = new List<String>();
                for (Schema.DescribeFieldResult dfr : customFieldDescribes) {
                    String sortKey = dfr.getLabel().toLowerCase() + '___' + dfr.getName();
                    sortedMap.put(sortKey, dfr);
                    sortKeys.add(sortKey);
                }
                sortKeys.sort();

                for (String sortKey : sortKeys) {
                    Schema.DescribeFieldResult dfr = sortedMap.get(sortKey);
                    FieldDetail fd = buildFieldDetail(rec, dfr);
                    cat.fields.add(fd);
                }
                cat.fieldCount = cat.fields.size();
            } else {
                // If no record exists, still list all fields as unpopulated so user sees structure
                Map<String, Schema.DescribeFieldResult> sortedMap = new Map<String, Schema.DescribeFieldResult>();
                List<String> sortKeys = new List<String>();
                for (Schema.DescribeFieldResult dfr : customFieldDescribes) {
                    String sortKey = dfr.getLabel().toLowerCase() + '___' + dfr.getName();
                    sortedMap.put(sortKey, dfr);
                    sortKeys.add(sortKey);
                }
                sortKeys.sort();

                for (String sortKey : sortKeys) {
                    Schema.DescribeFieldResult dfr = sortedMap.get(sortKey);
                    FieldDetail fd = new FieldDetail();
                    fd.apiName = dfr.getName();
                    fd.label = dfr.getLabel();
                    fd.helpText = dfr.getInlineHelpText();
                    fd.value = '—';
                    fd.displayType = String.valueOf(dfr.getType());
                    fd.badgeClass = 'oj-field-pill-empty';
                    fd.isBoolean = dfr.getType() == Schema.DisplayType.BOOLEAN;
                    fd.isHighlight = false;
                    cat.fields.add(fd);
                }
                cat.fieldCount = cat.fields.size();
            }

            result.add(cat);
        }

        return result;
    }

    /**
     * Formats an individual field value based on its Salesforce DisplayType.
     */
    private static FieldDetail buildFieldDetail(SObject rec, Schema.DescribeFieldResult dfr) {
        FieldDetail fd = new FieldDetail();
        fd.apiName = dfr.getName();
        fd.label = dfr.getLabel();
        fd.helpText = dfr.getInlineHelpText();
        fd.isBoolean = false;
        fd.isHighlight = false;

        Object rawVal = rec.get(dfr.getName());
        Schema.DisplayType dt = dfr.getType();

        if (rawVal == null) {
            fd.value = '—';
            fd.displayType = String.valueOf(dt);
            fd.badgeClass = 'oj-field-pill-empty';
            if (dt == Schema.DisplayType.BOOLEAN) {
                fd.isBoolean = true;
                fd.value = 'No';
                fd.badgeClass = 'oj-field-pill-no';
            }
            return fd;
        }

        if (dt == Schema.DisplayType.BOOLEAN) {
            Boolean b = (Boolean)rawVal;
            fd.isBoolean = true;
            fd.displayType = 'BOOLEAN';
            if (b) {
                fd.value = 'Yes';
                fd.badgeClass = 'oj-field-pill-yes';
                fd.isHighlight = true;
            } else {
                fd.value = 'No';
                fd.badgeClass = 'oj-field-pill-no';
            }
        } else if (dt == Schema.DisplayType.CURRENCY) {
            Decimal curVal = (Decimal)rawVal;
            fd.displayType = 'CURRENCY';
            if (curVal == curVal.setScale(0)) {
                fd.value = '₹ ' + curVal.setScale(0).format();
            } else {
                fd.value = '₹ ' + curVal.setScale(2).format();
            }
        } else if (dt == Schema.DisplayType.PERCENT) {
            Decimal pctVal = (Decimal)rawVal;
            fd.displayType = 'PERCENT';
            fd.value = String.valueOf(pctVal.setScale(2)) + '%';
        } else if (dt == Schema.DisplayType.DATE) {
            Date d = (Date)rawVal;
            fd.displayType = 'DATE';
            Datetime dtm = Datetime.newInstance(d.year(), d.month(), d.day());
            fd.value = dtm.format('dd MMM yyyy');
        } else if (dt == Schema.DisplayType.DATETIME) {
            Datetime dtm = (Datetime)rawVal;
            fd.displayType = 'DATETIME';
            fd.value = dtm.format('dd MMM yyyy, hh:mm a');
        } else if (dt == Schema.DisplayType.DOUBLE || dt == Schema.DisplayType.INTEGER) {
            Decimal num = (Decimal)rawVal;
            fd.displayType = 'NUMBER';
            if (num == num.setScale(0)) {
                fd.value = num.setScale(0).format();
            } else {
                fd.value = num.setScale(2).format();
            }
        } else if (dt == Schema.DisplayType.PICKLIST || dt == Schema.DisplayType.MULTIPICKLIST) {
            String strVal = String.valueOf(rawVal);
            fd.displayType = 'PICKLIST';
            fd.value = strVal;
            fd.badgeClass = getPillBadgeClass(strVal);
            if (fd.badgeClass != null) {
                fd.isHighlight = true;
            }
        } else if (dt == Schema.DisplayType.TEXTAREA) {
            fd.displayType = 'TEXTAREA';
            fd.value = String.valueOf(rawVal);
        } else {
            String strVal = String.valueOf(rawVal);
            fd.displayType = 'TEXT';
            fd.value = strVal;
            fd.badgeClass = getPillBadgeClass(strVal);
            if (fd.badgeClass != null) {
                fd.isHighlight = true;
            }
        }

        return fd;
    }

    /**
     * Determines highlight badge classes for prominent business keywords.
     */
    private static String getPillBadgeClass(String textVal) {
        if (String.isBlank(textVal)) return null;
        String lower = textVal.toLowerCase();

        if (lower.contains('vip') || lower.contains('high frequency') || lower.contains('platinum') || lower.contains('promoter') || lower.contains('gold tier')) {
            return 'oj-field-pill-gold';
        }
        if (lower.contains('high-risk') || lower.contains('fraud') || lower.contains('overdue') || lower.contains('critical') || lower.contains('abuse') || lower.contains('dormant')) {
            return 'oj-field-pill-danger';
        }
        if (lower.contains('active') || lower.contains('verified') || lower.contains('eligible') || lower.contains('satisfied') || lower.contains('promoter') || lower.contains('regular')) {
            return 'oj-field-pill-success';
        }
        if (lower.contains('medium') || lower.contains('neutral') || lower.contains('in review') || lower.contains('due soon')) {
            return 'oj-field-pill-warning';
        }
        return 'oj-field-pill-neutral';
    }
}