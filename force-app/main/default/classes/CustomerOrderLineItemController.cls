public with sharing class CustomerOrderLineItemController {
    
    public class WishlistWrapper {
        @AuraEnabled public Id wishlistId;
        @AuraEnabled public String wishlistName;
        @AuraEnabled public String barcodeValue;
        @AuraEnabled public Datetime createdDate;
        
        @AuraEnabled public Decimal grWt;
        @AuraEnabled public Decimal netWt;
        @AuraEnabled public Decimal diaWt;
        @AuraEnabled public String salesExe;
        @AuraEnabled public Decimal priceGST;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<WishlistWrapper> getAvailableWishlistItems(Id customerOrderId) {
        try {
            if (customerOrderId == null) {
                throw new AuraHandledException('Customer Order Id is missing.');
            }
            
            Customer_Order__c orderRec = [
                SELECT Id, Showroom_Visit__c
                FROM Customer_Order__c
                WHERE Id = :customerOrderId
                LIMIT 1
            ];
            
            if (orderRec.Showroom_Visit__c == null) {
                throw new AuraHandledException('No Showroom Visit is tagged with this Customer Order.');
            }
            
            Set<String> existingBarcodeSet = new Set<String>();
            
            for (Customer_Order_Line_Item__c lineItem : [
                SELECT Id, Barcode_Value__c
                FROM Customer_Order_Line_Item__c
                WHERE Customer_Order__c = :customerOrderId
                AND Barcode_Value__c != null 
                AND (Line_Item_Status_On_Salesforce__c != 'Back To Available Wishlist Item' AND Line_Item_Status_On_Salesforce__c != 'Removed') // ADDED
            ]) {
                existingBarcodeSet.add(lineItem.Barcode_Value__c);
            }
            
            Set<String> addedWishlistBarcodeSet = new Set<String>();
            List<WishlistWrapper> result = new List<WishlistWrapper>();
            
            /*
Important logic:
ORDER BY CreatedDate DESC means latest wishlist item will come first.
If same barcode exists multiple times, we only add the first/latest one.
*/
            for (Wishlist_Item__c wish : [
                SELECT Id, Name, Barcode_Value__c, CreatedDate,
                Gross_Weight__c,
                Net_Wt__c,
                Diamond_Wt__c,
                Active_Sales_Executive_Details__c,
                Total_Price_Incl_GST__c
                FROM Wishlist_Item__c
                WHERE Showroom_Visit__c = :orderRec.Showroom_Visit__c
                AND Barcode_Value__c != null
                AND Status__c = 'Available'
                ORDER BY CreatedDate DESC
            ]) {
                if (
                    !existingBarcodeSet.contains(wish.Barcode_Value__c) &&
                    !addedWishlistBarcodeSet.contains(wish.Barcode_Value__c)
                ) {
                    WishlistWrapper wrap = new WishlistWrapper();
                    wrap.wishlistId = wish.Id;
                    wrap.wishlistName = wish.Name;
                    wrap.barcodeValue = wish.Barcode_Value__c;
                    wrap.createdDate = wish.CreatedDate;
                    wrap.grWt = wish.Gross_Weight__c;
                    wrap.netWt = wish.Net_Wt__c;
                    wrap.diaWt = wish.Diamond_Wt__c;
                    wrap.salesExe = wish.Active_Sales_Executive_Details__c != null ? wish.Active_Sales_Executive_Details__c : '';
                    wrap.priceGST = wish.Total_Price_Incl_GST__c;
                    
                    result.add(wrap);
                    addedWishlistBarcodeSet.add(wish.Barcode_Value__c);
                }
            }
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String saveSelectedWishlistItems(Id customerOrderId, List<Id> wishlistItemIds) {
        try {
            if (customerOrderId == null) {
                throw new AuraHandledException('Customer Order Id is missing.');
            }
            
            if (wishlistItemIds == null || wishlistItemIds.isEmpty()) {
                throw new AuraHandledException('Please select at least one wishlist item.');
            }
            
            Customer_Order__c orderRec = [
                SELECT Id, Showroom_Visit__c
                FROM Customer_Order__c
                WHERE Id = :customerOrderId
                LIMIT 1
            ];
            
            if (orderRec.Showroom_Visit__c == null) {
                throw new AuraHandledException('No Showroom Visit is tagged with this Customer Order.');
            }
            
            Set<String> existingBarcodeSet = new Set<String>();
            
            for (Customer_Order_Line_Item__c lineItem : [
                SELECT Id, Barcode_Value__c
                FROM Customer_Order_Line_Item__c
                WHERE Customer_Order__c = :customerOrderId
                AND Barcode_Value__c != null 
                AND (Line_Item_Status_On_Salesforce__c != 'Back To Available Wishlist Item' AND Line_Item_Status_On_Salesforce__c != 'Removed') // ADDED
            ]) {
                existingBarcodeSet.add(lineItem.Barcode_Value__c);
            }
            
            /*
Again latest CreatedDate first.
This also protects save logic if duplicate wishlist ids are somehow passed.
*/
            List<Wishlist_Item__c> selectedWishlistItems = [
                SELECT Id, Name, Barcode_Value__c, CreatedDate,Total_Price_Incl_GST__c
                FROM Wishlist_Item__c
                WHERE Id IN :wishlistItemIds
                AND Showroom_Visit__c = :orderRec.Showroom_Visit__c
                AND Barcode_Value__c != null
                AND Status__c = 'Available'
                ORDER BY CreatedDate DESC
            ];
            
            Set<String> insertedBarcodeSet = new Set<String>();
            List<Customer_Order_Line_Item__c> lineItemsToInsert = new List<Customer_Order_Line_Item__c>();
            
            List<Wishlist_Item__c> wishlistToUpdate = new List<Wishlist_Item__c>();
            
            for (Wishlist_Item__c wish : selectedWishlistItems) {
                if (
                    !existingBarcodeSet.contains(wish.Barcode_Value__c) &&
                    !insertedBarcodeSet.contains(wish.Barcode_Value__c)
                ) {
                    Customer_Order_Line_Item__c lineItem = new Customer_Order_Line_Item__c();
                    
                    lineItem.Customer_Order__c = customerOrderId;
                    lineItem.Wishlist_Item__c = wish.Id;
                    lineItem.Barcode_Value__c = wish.Barcode_Value__c;
                    lineItem.Final_Price__c = wish .Total_Price_Incl_GST__c;
                    
                    /*
Add extra mappings here if required.

Example:
lineItem.Product__c = wish.Product__c;
lineItem.Quantity__c = wish.Quantity__c;
lineItem.Rate__c = wish.Rate__c;
*/
                    
                    lineItemsToInsert.add(lineItem);
                    insertedBarcodeSet.add(wish.Barcode_Value__c);
                    
                    Wishlist_Item__c w = new Wishlist_Item__c();
                    w.Id = wish.Id;
                    w.Status__c = 'Order Placed';
                    
                    wishlistToUpdate.add(w);
                }
            }
            
            if (lineItemsToInsert.isEmpty()) {
                throw new AuraHandledException('Selected barcode already exists in Customer Order Line Items.');
            }
            
            insert lineItemsToInsert;
            update wishlistToUpdate;
            
            return lineItemsToInsert.size() + ' Customer Order Line Item(s) created successfully.';
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}