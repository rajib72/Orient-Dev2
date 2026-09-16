public with sharing class DailyActivityController {
    
    @AuraEnabled
    public static Id saveDailyActivity(Map<String, Object> formData, Boolean createNew) {
        
        if (formData == null) {
            throw new AuraHandledException('Form data cannot be empty.');
        }
        
        /************ FORM VALUES ************/
        String customer        = (String) formData.get('customer');
        String phone           = (String) formData.get('phone');
        String activityDateStr = (String) formData.get('activityDate');
        String activityTime    = (String) formData.get('activityTime');
        String description     = (String) formData.get('description');
        String categoryName    = (String) formData.get('category'); // Now contains comma-separated values
        String subCategoryName = (String) formData.get('subCategory'); // Now contains comma-separated values
        
        String finalCustomerName = String.isBlank(customer) ? 'Default Customer' : customer;
        String finalPhone = String.isBlank(phone) ? '' : phone;
        
        String storeIdStr          = (String) formData.get('store');
        String salesExecutiveIdStr = (String) formData.get('salesExecutive');
        String purposeMasterIdStr  = (String) formData.get('purposeMasterId');
        
        Id storeId = String.isBlank(storeIdStr) ? null : Id.valueOf(storeIdStr);
        Id salesExecutiveId = String.isBlank(salesExecutiveIdStr) ? null : Id.valueOf(salesExecutiveIdStr);
        if (salesExecutiveId == null) {
            throw new AuraHandledException('Sales Executive is required.');
        }
        Id purposeMasterId = String.isBlank(purposeMasterIdStr) ? null : Id.valueOf(purposeMasterIdStr);
        
        String netWeight     = (String) formData.get('netWeight');
        String purposeLevel1 = (String) formData.get('purposeLevel1');
        String purposeLevel2 = (String) formData.get('purposeLevel2');
        String purposeLevel3 = (String) formData.get('purposeLevel3');
        
        Decimal budget;
        if (formData.get('budget') != null && !String.isBlank(String.valueOf(formData.get('budget')))) {
            budget = Decimal.valueOf(String.valueOf(formData.get('budget')));
        }
        
        /************ CONVERT DATE ************/
        Date activityDate;
        if (!String.isBlank(activityDateStr)) {
            activityDate = Date.valueOf(activityDateStr);
        }
        
        /************ CONVERT TIME ************/
        Time convertedTime;
        if (!String.isBlank(activityTime)) {
            List<String> parts = activityTime.split(':');
            if (parts.size() >= 2) {
                convertedTime = Time.newInstance(
                    Integer.valueOf(parts[0]),
                    Integer.valueOf(parts[1]),
                    0,
                    0
                );
            }
        }
        
        /************ FIND / CREATE ACCOUNT ************/
        Id accountId;
        
        // Case 1: Customer blank + Phone blank => do not create Account
        if (String.isBlank(customer) && String.isBlank(phone)) {
            accountId = null;
        } else {
            
            // Search existing Account only when phone is available
            if (!String.isBlank(finalPhone)) {
                String normalizedPhone = finalPhone.replaceAll('[^0-9]', '');
                system.debug('normalizedPhone---'+normalizedPhone);
                
                for (Account acc : [
                    SELECT Id, Phone, Whatsapp_Number__c, Status__c, Customer_Type__c, Registration_Mode__c
                    FROM Account
                    WHERE Phone = :finalPhone
                    OR Whatsapp_Number__c = :finalPhone
                    LIMIT 50000
                ]) {
                    String accPhone = acc.Phone != null
                        ? acc.Phone.replaceAll('[^0-9]', '')
                        : '';
                    
                    String accWhatsapp = acc.Whatsapp_Number__c != null
                        ? acc.Whatsapp_Number__c.replaceAll('[^0-9]', '')
                        : '';
                    
                    if (accPhone == normalizedPhone || accWhatsapp == normalizedPhone) {
                        accountId = acc.Id;
                        break;
                    }
                }
            }
            
            // If Account not found, create new Account
            if (accountId == null) {
                Account acc = new Account(
                    Name = finalCustomerName,
                    Phone = finalPhone,
                    Whatsapp_Number__c = finalPhone,
                    Status__c = 'Prospect',
                    Registration_Mode__c = 'CRM',
                    Customer_Type__c = 'Walk-in'
                );
                
                insert acc;
                accountId = acc.Id;
            }
        }
        
        /************ CREATE SHOWROOM VISIT ************/
        Showroom_Visit__c visit = new Showroom_Visit__c();
        
        visit.Customer_Name__c = String.isBlank(customer) && String.isBlank(phone)
            ? ''
            : finalCustomerName;
        
        visit.Phone__c = finalPhone;
        visit.Visit_Date__c = activityDate;
        visit.Entry_Time__c = convertedTime;
        visit.Store_Interaction_Details__c = description;
        
        if (accountId != null) {
            visit.CUSTOMERlookup__c = accountId;
        }
        
        if (!String.isBlank(categoryName)) {
            visit.Category__c = categoryName;
        }
        
        if (!String.isBlank(subCategoryName)) {
            visit.Sub_Category__c = subCategoryName;
        }
        
        if (storeId != null) {
            visit.StoreLookup__c = storeId;
        }
        
        if (!String.isBlank(netWeight)) {
            visit.Net_Weight__c = netWeight;
        }
        
        if (budget != null) {
            visit.Budget__c = budget;
        }
        
        if (salesExecutiveId != null) {
            visit.Primary_Sales_Executive_Name__c = salesExecutiveId;
        }
        
        if (purposeMasterId != null) {
            visit.Purpose_Master__c = purposeMasterId;
        }
        
        if (!String.isBlank(purposeLevel1)) {
            visit.Purpose_Level_1__c = purposeLevel1;
        }
        
        if (!String.isBlank(purposeLevel2)) {
            visit.Purpose_Level_2__c = purposeLevel2;
        }
        
        if (!String.isBlank(purposeLevel3)) {
            visit.Purpose_Level_3__c = purposeLevel3;
        }
        
        insert visit;
        
        /************ FILE UPLOAD ************/
        if (formData.get('designFiles') != null) {
            
            List<Object> uploadedFiles = (List<Object>) formData.get('designFiles');
            List<ContentVersion> contentVersions = new List<ContentVersion>();
            
            for (Object obj : uploadedFiles) {
                
                Map<String, Object> fileMap =
                    (Map<String, Object>) JSON.deserializeUntyped(
                        JSON.serialize(obj)
                    );
                
                String fileName = (String) fileMap.get('fileName');
                String base64Data = (String) fileMap.get('base64Data');
                
                if (!String.isBlank(fileName) && !String.isBlank(base64Data)) {
                    
                    ContentVersion cv = new ContentVersion();
                    cv.Title = fileName;
                    cv.PathOnClient = fileName;
                    cv.VersionData = EncodingUtil.base64Decode(base64Data);
                    cv.FirstPublishLocationId = visit.Id;
                    
                    contentVersions.add(cv);
                }
            }
            
            if (!contentVersions.isEmpty()) {
                insert contentVersions;
            }
        }
        
        /************ CREATE ACTIVITY TRACKING ************/
        Sales_Executive_Activity_Tracking__c tracking =
            new Sales_Executive_Activity_Tracking__c();
        
        tracking.Showroom_Visit__c = visit.Id;
        tracking.Session_Starting_Date__c = activityDate;
        tracking.Session_Start_Time__c = convertedTime;
        tracking.Session_Status__c = 'Active';
        
        if (accountId != null) {
            tracking.Orient_Customer__c = accountId;
        }
        
        if (salesExecutiveId != null) {
            tracking.Sales_Executive__c = salesExecutiveId;
        }
        
        insert tracking;

        /************ CREATE FEEDBACK ************/

        Feedback__c feedback = new Feedback__c();
        feedback.Orient_Customer__c = accountId;
        feedback.Showroom_Visit__c = visit.Id;
        feedback.Store__c = storeId;
        feedback.Visit_Date__c = activityDate;
        feedback.Primary_Sales_Executive_Name__c = salesExecutiveId;
        feedback.Status__c = 'Pending';

        
        insert feedback;

        return visit.Id;
    }
    
    /************ SUPPORT METHODS ************/
    
    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccountByPhone(String phone) {
        if (String.isBlank(phone)) return new List<Account>();
        
        String normalized = phone.replaceAll('[^0-9]', '');
        
        return [
            SELECT Id, Name, Phone, Whatsapp_Number__c
            FROM Account
            WHERE (Phone != null AND Phone LIKE :('%' + normalized + '%'))
            OR (Whatsapp_Number__c != null AND Whatsapp_Number__c LIKE :('%' + normalized + '%'))
            LIMIT 3
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Category__c> getAllCategories() {
        return [
            SELECT Id, Name
            FROM Category__c
            ORDER BY Name
        ];
    }
    
    // UPDATED: Now accepts a list of category names
    @AuraEnabled(cacheable=true)
    public static List<Sub_Category__c> getSubCategoriesByCategory(List<String> categoryNames) {
        if (categoryNames == null || categoryNames.isEmpty()) {
            return new List<Sub_Category__c>();
        }
        
        List<Category__c> cats = [
            SELECT Id
            FROM Category__c
            WHERE Name IN :categoryNames
        ];
        
        return [
            SELECT Id, Name
            FROM Sub_Category__c
            WHERE Category__c IN :cats
            ORDER BY Name
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Store__c> getAllStores() {
        return [
            SELECT Id, Name, Location__c, Store_Code__c
            FROM Store__c
            ORDER BY Name
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Purpose_Master__c> searchPurpose(String searchKey) {
        if (String.isBlank(searchKey)) {
            return new List<Purpose_Master__c>();
        }
        
        String key = '%' + searchKey.trim() + '%';
        
        List<Purpose_Master__c> level1Matches = [
            SELECT Id, Name, Purpose_Level_1__c, Purpose_Level_2__c, Purpose_Level_3__c
            FROM Purpose_Master__c
            WHERE Purpose_Level_1__c LIKE :key
            ORDER BY Purpose_Level_2__c, Purpose_Level_3__c
            LIMIT 50
        ];
        
        if (!level1Matches.isEmpty()) {
            return level1Matches;
        }
        
        return [
            SELECT Id, Name, Purpose_Level_1__c, Purpose_Level_2__c, Purpose_Level_3__c
            FROM Purpose_Master__c
            WHERE Purpose_Level_3__c LIKE :key
            ORDER BY Purpose_Level_2__c, Purpose_Level_3__c
            LIMIT 50
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Sales_Executives__c> getSalesExecutiveByStore(Id storeId) {
        if (storeId == null) return new List<Sales_Executives__c>();
        
        return [
            SELECT Id, Name
            FROM Sales_Executives__c
            WHERE Store__c = :storeId
            ORDER BY Name
        ];
    }
    
    public class StoreAccessWrapper {
        @AuraEnabled public List<Store__c> stores;
        @AuraEnabled public Id defaultStoreId;
    }
    
    @AuraEnabled(cacheable=true)
    public static StoreAccessWrapper getStoreAccessInfo() {
        StoreAccessWrapper wrap = new StoreAccessWrapper();
        wrap.stores = new List<Store__c>();
        wrap.defaultStoreId = null;
        
        User loggedInUser = [
            SELECT Id, Location_Code__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        if (!String.isBlank(loggedInUser.Location_Code__c)) {
            List<Store__c> matchedStores = [
                SELECT Id, Name, Location__c, Store_Code__c
                FROM Store__c
                WHERE Store_Code__c = :loggedInUser.Location_Code__c
                ORDER BY Name
                LIMIT 1
            ];
            
            if (!matchedStores.isEmpty()) {
                wrap.stores = matchedStores;
                wrap.defaultStoreId = matchedStores[0].Id;
            }
        } else {
            wrap.stores = [
                SELECT Id, Name, Location__c, Store_Code__c
                FROM Store__c
                ORDER BY Name
            ];
        }
        
        return wrap;
    }
}