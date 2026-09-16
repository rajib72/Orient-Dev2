@isTest
private class EstimationLineItemHelperTest {
 
    private static Map<String, Id> createdIds = new Map<String, Id>();
 
    @testSetup
    static void setupData() {
        Id customerId     = createMinimalRecordId(getReferenceObjectName(Customer_Order__c.Customer__c), 3);
        Id showroomVisitId = createMinimalRecordId(getReferenceObjectName(Wishlist_Item__c.Showroom_Visit__c), 3);
 
        Customer_Order__c estimation = new Customer_Order__c();
        estimation.Customer__c   = customerId;
        estimation.Order_Date__c = Date.today();
        insert estimation;
 
        Wishlist_Item__c wishlistWithParent = new Wishlist_Item__c();
        wishlistWithParent.Showroom_Visit__c = showroomVisitId;
        wishlistWithParent.Status__c         = 'Available';
        wishlistWithParent.Barcode_Value__c   = 'WISH-001';
        insert wishlistWithParent;
 
        Wishlist_Item__c wishlistWithoutParent = new Wishlist_Item__c();
        wishlistWithoutParent.Showroom_Visit__c = showroomVisitId;
        wishlistWithoutParent.Status__c         = 'Available';
        wishlistWithoutParent.Barcode_Value__c   = 'WISH-002';
        insert wishlistWithoutParent;
 
        Customer_Order_Line_Item__c lineItemWithWishlist = new Customer_Order_Line_Item__c();
        lineItemWithWishlist.Customer_Order__c             = estimation.Id;
        lineItemWithWishlist.Wishlist_Item__c              = wishlistWithParent.Id;
        lineItemWithWishlist.Barcode_Value__c              = 'BAR-001';
        lineItemWithWishlist.Line_Item_Status_On_Salesforce__c = 'Draft';
        insert lineItemWithWishlist;
 
        Customer_Order_Line_Item__c lineItemWithoutWishlist = new Customer_Order_Line_Item__c();
        lineItemWithoutWishlist.Customer_Order__c             = estimation.Id;
        lineItemWithoutWishlist.Barcode_Value__c              = 'BAR-002';
        lineItemWithoutWishlist.Line_Item_Status_On_Salesforce__c = 'Draft';
        insert lineItemWithoutWishlist;
    }
 
    @isTest
    static void testGetEstimationLineItems() {
        Customer_Order__c estimation = [
            SELECT Id
            FROM Customer_Order__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
 
        Test.startTest();
        List<Customer_Order_Line_Item__c> items = EstimationLineItemHelper.getEstimationLineItems(estimation.Id);
        Test.stopTest();
 
        // No System.assert used, as requested.
        items.size();
    }
 
    @isTest
    static void testRemoveLineItems() {
        List<Customer_Order_Line_Item__c> items = [
            SELECT Id
            FROM Customer_Order_Line_Item__c
            WHERE Line_Item_Status_On_Salesforce__c = 'Draft'
            ORDER BY CreatedDate ASC
        ];
 
        List<Id> lineItemIds = new List<Id>();
        for (Customer_Order_Line_Item__c li : items) {
            lineItemIds.add(li.Id);
        }
 
        Test.startTest();
        EstimationLineItemHelper.removeLineItems(lineItemIds);
        Test.stopTest();
 
        List<Customer_Order_Line_Item__c> updatedItems = [
            SELECT Id, Line_Item_Status_On_Salesforce__c, Wishlist_Item__c
            FROM Customer_Order_Line_Item__c
            WHERE Id IN :lineItemIds
        ];
        updatedItems.size();
 
        List<Wishlist_Item__c> updatedWishlists = [
            SELECT Id, Status__c
            FROM Wishlist_Item__c
            WHERE Id IN (
                SELECT Wishlist_Item__c
                FROM Customer_Order_Line_Item__c
                WHERE Id IN :lineItemIds
                AND Wishlist_Item__c != null
            )
        ];
        updatedWishlists.size();
    }
 
    @isTest
    static void testRemoveLineItemsWithEmptyList() {
        Test.startTest();
        EstimationLineItemHelper.removeLineItems(new List<Id>());
        Test.stopTest();
    }
 
    private static String getReferenceObjectName(Schema.SObjectField fieldToken) {
        Schema.DescribeFieldResult dfr = fieldToken.getDescribe();
        List<Schema.SObjectType> refs = dfr.getReferenceTo();
        if (refs == null || refs.isEmpty()) {
            return null;
        }
        return refs[0].getDescribe().getName();
    }
 
    private static Id createMinimalRecordId(String objectApiName, Integer depth) {
        if (String.isBlank(objectApiName)) {
            return null;
        }
 
        if (createdIds.containsKey(objectApiName)) {
            return createdIds.get(objectApiName);
        }
 
        Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectApiName);
        if (sType == null) {
            return null;
        }
 
        SObject record = sType.newSObject();
        Map<String, Schema.SObjectField> fieldMap = sType.getDescribe().fields.getMap();
 
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
 
            if (!dfr.isCreateable() || dfr.isCalculated() || dfr.isAutoNumber()) {
                continue;
            }
 
            if (fieldName == 'OwnerId' || fieldName == 'RecordTypeId' ||
                fieldName == 'CreatedById' || fieldName == 'LastModifiedById') {
                continue;
            }
 
            if (!dfr.isNillable()) {
                if (dfr.getType() == Schema.DisplayType.Reference && depth > 0) {
                    List<Schema.SObjectType> refs = dfr.getReferenceTo();
                    if (refs != null && !refs.isEmpty()) {
                        Id parentId = createMinimalRecordId(refs[0].getDescribe().getName(), depth - 1);
                        if (parentId != null) {
                            record.put(fieldName, parentId);
                        }
                    }
                } else {
                    record.put(fieldName, getDummyValue(dfr));
                }
            }
        }
 
        insert record;
        Id newId = (Id)record.get('Id');
        createdIds.put(objectApiName, newId);
        return newId;
    }
 
    private static Object getDummyValue(Schema.DescribeFieldResult dfr) {
        switch on dfr.getType() {
            when STRING, TEXTAREA, PHONE, EMAIL, URL, PICKLIST, MULTIPICKLIST, COMBOBOX, ENCRYPTEDSTRING {
                return 'Test';
            }
            when BOOLEAN {
                return true;
            }
            when DATE {
                return Date.today();
            }
            when DATETIME {
                return System.now();
            }
            when INTEGER {
                return 1;
            }
            when LONG {
                return 1;
            }
            when DOUBLE {
                return 1;
            }
            when CURRENCY {
                return 1;
            }
            when PERCENT {
                return 1;
            }
            when TIME {
                return Time.newInstance(0, 0, 0, 0);
            }
            when REFERENCE {
                return null;
            }
            when else {
                return 'Test';
            }
        }
    }
}