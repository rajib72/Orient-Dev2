public with sharing class ShowroomWishlistNotOrderedController {
    
    /************DTO************/
    public class WishlistDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String barcode;
        @AuraEnabled public String description;
        @AuraEnabled public String status;
        
        public WishlistDTO(Wishlist_Item__c wi) {
            this.id = wi.Id;
            this.name = wi.Name;
            this.barcode = wi.Barcode_Value__c;
            this.description = wi.Description__c;
            this.status = wi.Status__c;
        }
    }
    
    /************ FETCH AVAILABLE ITEMS ************/
    @AuraEnabled(cacheable=true)
    public static List<WishlistDTO> getAvailableWishlistItems(Id showroomVisitId) {
        
        List<Wishlist_Item__c> wishlistRecords = [
            SELECT Id, Name, Barcode_Value__c, Description__c, Status__c
            FROM Wishlist_Item__c
            WHERE Showroom_Visit__c = :showroomVisitId
            AND Status__c = 'Available'
            ORDER BY CreatedDate ASC
        ];
        
        List<WishlistDTO> result = new List<WishlistDTO>();
        
        for (Wishlist_Item__c wi : wishlistRecords) {
            result.add(new WishlistDTO(wi));
        }
        
        return result;
    }
    
    /************ UPDATE NOT ORDERED ************/
    @AuraEnabled
public static void markAsNotOrdered(
    Map<Id, String> wishlistReasonMap
) {
    if (wishlistReasonMap == null || wishlistReasonMap.isEmpty()) {
        throw new AuraHandledException('No wishlist items selected.');
    }

    List<Wishlist_Item__c> items = [
        SELECT Id, Status__c, Reason_For_Not_Ordered__c
        FROM Wishlist_Item__c
        WHERE Id IN :wishlistReasonMap.keySet()
        FOR UPDATE
    ];

    try {
        for (Wishlist_Item__c wi : items) {
            wi.Status__c = 'Not Ordered';
            wi.Reason_For_Not_Ordered__c = wishlistReasonMap.get(wi.Id);
        }

        update items;

    } catch (DmlException e) {
        // 🔥 THIS is what exposes the real error to LWC
        throw new AuraHandledException(
            'Failed to update wishlist item(s): ' + e.getDmlMessage(0)
        );
    }
}

    
}