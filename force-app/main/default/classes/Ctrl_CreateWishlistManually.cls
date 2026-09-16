public with sharing class Ctrl_CreateWishlistManually {
    
    @AuraEnabled
    public static String createWishlistItem(Id showroomVisitId, String barcodeValue) {
        // Early exit to save SOQL queries if inputs are invalid
        if (String.isBlank(showroomVisitId) || String.isBlank(barcodeValue)) {
            throw new AuraHandledException('Showroom Visit ID and Barcode Value are required.');
        }

        // Set a savepoint to rollback the entire transaction if any DML fails
        Savepoint sp = Database.setSavepoint();

        try {
            // 1. Get the active Sales Executive Activity Tracking record
            List<Sales_Executive_Activity_Tracking__c> trackingRecords = [
                SELECT Id 
                FROM Sales_Executive_Activity_Tracking__c 
                WHERE Showroom_Visit__c = :showroomVisitId 
                  AND Session_Status__c = 'Active'
                WITH USER_MODE
                LIMIT 1
            ];
            
            Id trackingId = trackingRecords.isEmpty() ? null : trackingRecords[0].Id;

            // 2. Find and update existing active Wishlist item for this Barcode
            List<Wishlist_Item__c> existingItemsWithSameSKU = [
                SELECT Id, Is_Latest_Wishlist__c 
                FROM Wishlist_Item__c 
                WHERE Showroom_Visit__c = :showroomVisitId 
                  AND Barcode_Value__c = :barcodeValue 
                  AND Is_Latest_Wishlist__c = true 
                WITH USER_MODE
                LIMIT 1
            ];

            if (!existingItemsWithSameSKU.isEmpty()) {
                existingItemsWithSameSKU[0].Is_Latest_Wishlist__c = false;
                update as user existingItemsWithSameSKU[0]; // Enforces FLS on update
            }
            
            // 3. Create the new Wishlist Item
            Wishlist_Item__c newItem = new Wishlist_Item__c(
                Barcode_Value__c = barcodeValue,
                Description__c = 'Created from barcode scanning for product ' + barcodeValue,
                Sales_Executive_Activity_Tracking__c = trackingId,
                Showroom_Visit__c = showroomVisitId,
                Status__c = 'Available',
                Is_Latest_Wishlist__c = true
            );
            
            insert as user newItem; // Enforces FLS on insert
            
            // 4. Create or Update the Counter Record
            // Note: FOR UPDATE locks the record to prevent race conditions during concurrent scans
            List<Barcode_Scanned_Count__c> barcodeCounter = [
                SELECT Counter__c, SKU__c 
                FROM Barcode_Scanned_Count__c 
                WHERE SKU__c = :barcodeValue 
                WITH USER_MODE 
                LIMIT 1 
                FOR UPDATE
            ];

            if (!barcodeCounter.isEmpty()) {
                // Ensure we don't hit a NullPointerException if Counter__c is somehow null
                Decimal currentCount = barcodeCounter[0].Counter__c == null ? 0 : barcodeCounter[0].Counter__c;
                barcodeCounter[0].Counter__c = currentCount + 1;
                update as user barcodeCounter[0];
            } else {
                Barcode_Scanned_Count__c counter = new Barcode_Scanned_Count__c(
                    SKU__c = barcodeValue,
                    Counter__c = 1
                );
                insert as user counter;
            }

            // 5. Return the ID for navigation
            return newItem.Id;
            
        } catch (Exception e) {
            // Rollback database changes to prevent partial data corruption
            Database.rollback(sp);
            
            // Format exception for LWC
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage('Error creating Wishlist Item: ' + e.getMessage());
            throw ahe;
        }
    }
}