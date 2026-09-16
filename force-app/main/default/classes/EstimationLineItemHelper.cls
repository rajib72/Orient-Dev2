public with sharing class EstimationLineItemHelper {
    
    @AuraEnabled(cacheable=true)
    public static List<Customer_Order_Line_Item__c> getEstimationLineItems(Id estimationId) {
        return [
            SELECT Id, Name, Barcode_Value__c,
                   Wishlist_Item__r.Gross_Weight__c,
                   Wishlist_Item__r.Net_Wt__c,
                   Wishlist_Item__r.Diamond_Wt__c,
                   Wishlist_Item__r.Stone_Wt__c,
                   Wishlist_Item__r.Total_Price_Including_GST__c,
                   Wishlist_Item__r.Active_Sales_Executive_Details__c,
                   Line_Item_Status_On_Salesforce__c
            FROM Customer_Order_Line_Item__c
            WHERE Customer_Order__c = :estimationId 
              AND Line_Item_Status_On_Salesforce__c = 'Draft'
           // WITH USER_MODE
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static void removeLineItems(List<Id> lineItemIds) {
        if (lineItemIds == null || lineItemIds.isEmpty()) {
            return;
        }
        
        // 1. Query the Line Items to get the parent Wishlist_Item__c IDs
        List<Customer_Order_Line_Item__c> lineItems = [
            SELECT Id, Wishlist_Item__c 
            FROM Customer_Order_Line_Item__c 
            WHERE Id IN :lineItemIds
            WITH USER_MODE
        ];
        
        List<Customer_Order_Line_Item__c> itemsToUpdate = new List<Customer_Order_Line_Item__c>();
        
        // Using a Map for the parent records prevents duplicate ID errors in DML
        Map<Id, Wishlist_Item__c> wishlistsToUpdateMap = new Map<Id, Wishlist_Item__c>();
        
        // 2. Loop through the records and prepare both updates
        for (Customer_Order_Line_Item__c item : lineItems) {
            
            // Prepare the Line Item for update
            itemsToUpdate.add(new Customer_Order_Line_Item__c(
                Id = item.Id,
                Line_Item_Status_On_Salesforce__c = 'Back To Available Wishlist Item'
            ));
            
            // Prepare the parent Wishlist Item for update (if one is attached)
            if (item.Wishlist_Item__c != null) {
                wishlistsToUpdateMap.put(item.Wishlist_Item__c, new Wishlist_Item__c(
                    Id = item.Wishlist_Item__c,
                    Status__c = 'Available'
                ));
            }
        }
        
        // 3. Perform the updates, respecting user permissions
        if (!itemsToUpdate.isEmpty()) {
            update as user itemsToUpdate;
        }
        
        if (!wishlistsToUpdateMap.isEmpty()) {
            update as user wishlistsToUpdateMap.values();
        }
    }
}