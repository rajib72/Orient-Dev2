public with sharing class EstimationCreationController {
    
    public class TagPriceDetailDTO {
        @AuraEnabled public String bomItem;
        @AuraEnabled public String purity;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public String uom;
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Decimal amount;
    }
    
    public class TagPriceScmDTO {
        @AuraEnabled public String bomItem;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String makingType;
    }
    
    public class CustomerInfoDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String phone;
        @AuraEnabled public String pan;
        @AuraEnabled public String gst;
        @AuraEnabled public String stateCode;
    }
    
    @AuraEnabled(cacheable=true)
    public static CustomerInfoDTO getCustomerByPhone(String phone) {
        if (String.isBlank(phone)) {
            return null;
        }
        
        List<Account> accList = [
            SELECT Id, Name, Phone, PAN__c, GST__c, StateCode__c
            FROM Account
            WHERE Phone = :phone
            LIMIT 1
        ];
        
        if (accList.isEmpty()) {
            return null;
        }
        
        Account acc = accList[0];
        
        CustomerInfoDTO dto = new CustomerInfoDTO();
        dto.id = acc.Id;
        dto.name = acc.Name;
        dto.phone = acc.Phone;
        dto.pan = acc.PAN__c;
        dto.gst = acc.GST__c;
        dto.stateCode = acc.StateCode__c;
        return dto;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<CustomerInfoDTO> searchCustomersByPhone(String phoneKey) {
        List<CustomerInfoDTO> result = new List<CustomerInfoDTO>();
        
        if (String.isBlank(phoneKey)) {
            return result;
        }
        
        String searchKey = phoneKey + '%';
        
        for (Account acc : [
            SELECT Id, Name, Phone, PAN__c, GST__c, StateCode__c
            FROM Account
            WHERE Phone LIKE :searchKey
            LIMIT 10
        ]) {
            CustomerInfoDTO dto = new CustomerInfoDTO();
            dto.id = acc.Id;
            dto.name = acc.Name;
            dto.phone = acc.Phone;
            dto.pan = acc.PAN__c;
            dto.gst = acc.GST__c;
            dto.stateCode = acc.StateCode__c;
            result.add(dto);
        }
        
        return result;
    }
    
    public class WishlistItemDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String barcode;
        @AuraEnabled public String description;
        @AuraEnabled public String salesExecutive;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal grossWeight;
        @AuraEnabled public Decimal netWeight;
        @AuraEnabled public Decimal diamondWt;
        @AuraEnabled public Decimal stoneWt;
        @AuraEnabled public Decimal productPrice;
        @AuraEnabled public List<TagPriceDetailDTO> tagPriceDetails;
        @AuraEnabled public List<TagPriceScmDTO> tagPriceScms;
        
        public WishlistItemDTO(Wishlist_Item__c wi) {
            this.id = wi.Id;
            this.name = wi.Name;
            this.barcode = wi.Barcode_Value__c;
            this.description = wi.Description__c;
            
            String code = wi.Active_Sales_Executive_Code__c;
            String executiveName = wi.Active_Sales_Executice_Name__c;
            
            if (String.isNotBlank(code) && String.isNotBlank(executiveName)) {
                this.salesExecutive = code + ' - ' + executiveName;
            } else if (String.isNotBlank(code)) {
                this.salesExecutive = code;
            } else {
                this.salesExecutive = executiveName;
            }
            
            this.status = wi.Status__c;
        }
    }
    
    private static String getReverseRelation(String relation, String primaryGender) {
        if (String.isBlank(relation)) {
            return 'Other';
        }
        
        if (
            String.isBlank(primaryGender) ||
            primaryGender == 'Other' ||
            primaryGender == 'Prefer not to say'
        ) {
            return 'Other';
        }
        
        Boolean isMale = primaryGender == 'Male';
        Boolean isFemale = primaryGender == 'Female';
        
        if (relation == 'Father') {
            return isMale ? 'Son' : isFemale ? 'Daughter' : 'Other';
        }
        
        if (relation == 'Mother') {
            return isMale ? 'Son' : isFemale ? 'Daughter' : 'Other';
        }
        
        if (relation == 'Son') {
            return isMale ? 'Father' : isFemale ? 'Mother' : 'Other';
        }
        
        if (relation == 'Daughter') {
            return isMale ? 'Father' : isFemale ? 'Mother' : 'Other';
        }
        
        if (relation == 'Brother') {
            return isMale ? 'Brother' : isFemale ? 'Sister' : 'Other';
        }
        
        if (relation == 'Sister') {
            return isMale ? 'Brother' : isFemale ? 'Sister' : 'Other';
        }
        
        if (relation == 'Husband') {
            return 'Wife';
        }
        
        if (relation == 'Wife') {
            return 'Husband';
        }
        
        if (relation == 'Cousin') {
            return 'Cousin';
        }
        
        if (relation == 'Friend') {
            return 'Friend';
        }
        
        if (relation == 'Niece') {
            return isMale ? 'Uncle' : isFemale ? 'Aunt' : 'Other';
        }
        
        if (relation == 'Nephew') {
            return isMale ? 'Uncle' : isFemale ? 'Aunt' : 'Other';
        }
        
        if (relation == 'Aunt') {
            return isMale ? 'Nephew' : isFemale ? 'Niece' : 'Other';
        }
        
        if (relation == 'Uncle') {
            return isMale ? 'Nephew' : isFemale ? 'Niece' : 'Other';
        }
        
        if (relation == 'Father In-laws') {
            return isMale ? 'Son In-laws' : isFemale ? 'Daughter In-laws' : 'Other';
        }
        
        if (relation == 'Mother In-laws') {
            return isMale ? 'Son In-laws' : isFemale ? 'Daughter In-laws' : 'Other';
        }
        
        if (relation == 'Son In-laws') {
            return isMale ? 'Father In-laws' : isFemale ? 'Mother In-laws' : 'Other';
        }
        
        if (relation == 'Daughter In-laws') {
            return isMale ? 'Father In-laws' : isFemale ? 'Mother In-laws' : 'Other';
        }
        
        if (relation == 'Brother In-laws') {
            return isMale ? 'Brother In-laws' : isFemale ? 'Sister In-laws' : 'Other';
        }
        
        if (relation == 'Sister In-laws') {
            return isMale ? 'Brother In-laws' : isFemale ? 'Sister In-laws' : 'Other';
        }
        
        if (relation == 'Grandfather') {
            return isMale ? 'Grandson' : isFemale ? 'Granddaughter' : 'Other';
        }
        
        if (relation == 'Grandmother') {
            return isMale ? 'Grandson' : isFemale ? 'Granddaughter' : 'Other';
        }
        
        if (relation == 'Maternal Grandfather') {
            return isMale ? 'Grandson' : isFemale ? 'Granddaughter' : 'Other';
        }
        
        if (relation == 'Maternal Grandmother') {
            return isMale ? 'Grandson' : isFemale ? 'Granddaughter' : 'Other';
        }
        
        if (relation == 'Grandson') {
            return isMale ? 'Grandfather' : isFemale ? 'Grandmother' : 'Other';
        }
        
        if (relation == 'Granddaughter') {
            return isMale ? 'Grandfather' : isFemale ? 'Grandmother' : 'Other';
        }
        
        if (relation == 'Other') {
            return 'Other';
        }
        
        return 'Other';
    }
    
    @AuraEnabled(cacheable=true)
    public static Showroom_Visit__c getShowroomVisit(Id showroomVisitId) {
        return [
            SELECT Id, Name, Customer_Phone__c, Visit_Date__c,
            CUSTOMERlookup__c,
            CUSTOMERlookup__r.Name,
            CUSTOMERlookup__r.PAN__c,
            CUSTOMERlookup__r.GST__c,
            CUSTOMERlookup__r.StateCode__c,
            StoreLookup__c,
            CUSTOMERlookup__r.Gender__c,
            Primary_Sales_Executive_Name__c
            FROM Showroom_Visit__c
            WHERE Id = :showroomVisitId
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<WishlistItemDTO> getWishlistItems(Id showroomVisitId) {
        List<Wishlist_Item__c> allItems = [
            SELECT Id, Name,
            Barcode_Value__c,
            Description__c,
            Sales_Executive_Name__c,
            Active_Sales_Executice_Name__c,
            Active_Sales_Executive_Code__c,
            Status__c,
            CreatedDate
            FROM Wishlist_Item__c
            WHERE Showroom_Visit__c = :showroomVisitId
            ORDER BY CreatedDate DESC
        ];
        
        List<WishlistItemDTO> result = new List<WishlistItemDTO>();
        
        if (allItems.isEmpty()) {
            return result;
        }
        
        Map<String, Wishlist_Item__c> uniqueBarcodeMap = new Map<String, Wishlist_Item__c>();
        List<Wishlist_Item__c> items = new List<Wishlist_Item__c>();
        
        for (Wishlist_Item__c wi : allItems) {
            String barcodeKey = String.isNotBlank(wi.Barcode_Value__c)
                ? wi.Barcode_Value__c
                : String.valueOf(wi.Id);
            
            if (!uniqueBarcodeMap.containsKey(barcodeKey)) {
                uniqueBarcodeMap.put(barcodeKey, wi);
                items.add(wi);
            }
        }
        
        Set<Id> wishlistIds = new Set<Id>();
        Set<String> barcodes = new Set<String>();
        
        for (Wishlist_Item__c wi : items) {
            wishlistIds.add(wi.Id);
            
            if (String.isNotBlank(wi.Barcode_Value__c)) {
                barcodes.add(wi.Barcode_Value__c);
            }
        }
        
        Map<Id, ACX_Tag_Header__c> acxMap = new Map<Id, ACX_Tag_Header__c>();
        
        for (ACX_Tag_Header__c acx : [
            SELECT Id,
            Wishlist_Item__c,
            Gross_Wt__c,
            Net_Wt__c,
            Stone_Wt__c,
            Diamond_Wt__c,
            CreatedDate
            FROM ACX_Tag_Header__c
            WHERE Wishlist_Item__c IN :wishlistIds
            ORDER BY CreatedDate DESC
        ]) {
            if (!acxMap.containsKey(acx.Wishlist_Item__c)) {
                acxMap.put(acx.Wishlist_Item__c, acx);
            }
        }
        
        Map<Id, Decimal> productPriceMap = new Map<Id, Decimal>();
        
        for (Tag_Price_Line__c tpl : [
            SELECT Id,
            Wishlist_Item__c,
            Product_Price_Inclusive_GST__c,
            CreatedDate
            FROM Tag_Price_Line__c
            WHERE Wishlist_Item__c IN :wishlistIds
            ORDER BY CreatedDate DESC
        ]) {
            if (!productPriceMap.containsKey(tpl.Wishlist_Item__c)) {
                productPriceMap.put(
                    tpl.Wishlist_Item__c,
                    tpl.Product_Price_Inclusive_GST__c
                );
            }
        }
        
        Map<Id, List<TagPriceDetailDTO>> detailMap = new Map<Id, List<TagPriceDetailDTO>>();
        Map<Id, List<TagPriceScmDTO>> scmMap = new Map<Id, List<TagPriceScmDTO>>();
        
        for (Id wiId : wishlistIds) {
            detailMap.put(wiId, new List<TagPriceDetailDTO>());
            scmMap.put(wiId, new List<TagPriceScmDTO>());
        }
        
        for (Tag_Price_Detail_Line__c row : [
            SELECT Id,
            BOM_Item__c,
            Purity__c,
            Quantity__c,
            UOM__c,
            Rate__c,
            Amount__c,
            Bar_Code_No__c,
            Wishlist_Item__c
            FROM Tag_Price_Detail_Line__c
            WHERE Wishlist_Item__c IN :wishlistIds
            OR Bar_Code_No__c IN :barcodes
            ORDER BY CreatedDate ASC
        ]) {
            Id wiId = row.Wishlist_Item__c;
            
            if (wiId == null && String.isNotBlank(row.Bar_Code_No__c)) {
                for (Wishlist_Item__c wi : items) {
                    if (wi.Barcode_Value__c == row.Bar_Code_No__c) {
                        wiId = wi.Id;
                        break;
                    }
                }
            }
            
            if (wiId != null && detailMap.containsKey(wiId)) {
                TagPriceDetailDTO d = new TagPriceDetailDTO();
                d.bomItem = row.BOM_Item__c;
                d.purity = row.Purity__c;
                d.quantity = row.Quantity__c;
                d.uom = row.UOM__c;
                d.rate = row.Rate__c;
                d.amount = row.Amount__c;
                detailMap.get(wiId).add(d);
            }
        }
        
        for (Tag_Price_SCM__c row : [
            SELECT Id,
            BOM_Item__c,
            Quantity__c,
            Rate__c,
            Amount__c,
            Making_Type__c,
            Bar_Code_No__c,
            Wishlist_Item__c
            FROM Tag_Price_SCM__c
            WHERE Wishlist_Item__c IN :wishlistIds
            OR Bar_Code_No__c IN :barcodes
            ORDER BY CreatedDate ASC
        ]) {
            Id wiId = row.Wishlist_Item__c;
            
            if (wiId == null && String.isNotBlank(row.Bar_Code_No__c)) {
                for (Wishlist_Item__c wi : items) {
                    if (wi.Barcode_Value__c == row.Bar_Code_No__c) {
                        wiId = wi.Id;
                        break;
                    }
                }
            }
            
            if (wiId != null && scmMap.containsKey(wiId)) {
                TagPriceScmDTO s = new TagPriceScmDTO();
                s.bomItem = row.BOM_Item__c;
                s.quantity = row.Quantity__c;
                s.rate = row.Rate__c;
                s.amount = row.Amount__c;
                s.makingType = row.Making_Type__c;
                scmMap.get(wiId).add(s);
            }
        }
        
        for (Wishlist_Item__c wi : items) {
            WishlistItemDTO dto = new WishlistItemDTO(wi);
            
            ACX_Tag_Header__c acx = acxMap.get(wi.Id);
            
            if (acx != null) {
                dto.grossWeight = acx.Gross_Wt__c;
                dto.netWeight = acx.Net_Wt__c;
                dto.diamondWt = acx.Diamond_Wt__c;
                dto.stoneWt = acx.Stone_Wt__c;
            }
            
            dto.productPrice = productPriceMap.get(wi.Id);
            dto.tagPriceDetails = detailMap.get(wi.Id);
            dto.tagPriceScms = scmMap.get(wi.Id);
            result.add(dto);
        }
        
        return result;
    }
    
    @AuraEnabled
    public static Id createOrder(
        Id showroomVisitId,
        Boolean useAlternateCustomer,
        String billingCustomerName,
        String billingCustomerPhone,
        String relation,
        List<Id> wishlistItemIds,
        String buyingFor,
        String buyingForName,
        String buyingForPhone,
        Boolean payAdvance,
        Decimal advanceAmount,
        Boolean sameAddressAsPrimary,
        Id existingBillingCustomerId,
        String customerGender
    ) {
        Savepoint sp = Database.setSavepoint();
        Set<Id> accountsToActivate = new Set<Id>();
        
        try {
            if (showroomVisitId == null) {
                throw new AuraHandledException('Showroom Visit Id is missing.');
            }
            
            if (wishlistItemIds == null || wishlistItemIds.isEmpty()) {
                throw new AuraHandledException('No wishlist items selected.');
            }
            
            Showroom_Visit__c sv = [
                SELECT Id,
                StoreLookup__c,
                Primary_Sales_Executive_Name__c,
                Primary_Sales_Executive_Name__r.Name,
                CUSTOMERlookup__c,
                CUSTOMERlookup__r.Gender__c
                FROM Showroom_Visit__c
                WHERE Id = :showroomVisitId
                LIMIT 1
            ];
            
            if (sv.CUSTOMERlookup__c == null) {
                throw new AuraHandledException('No customer linked to Showroom Visit.');
            }
            
            Account showroomCustomer = [
                SELECT Id, Name, Phone, Status__c, Village__c,
                PAN__c, GST__c, StateCode__c, Gender__c,
                Permanent_Address__c, State_Province__c,
                Pin_Code__c, Locality_Area__c, Residential_City__c, District__c,
                Country__c, Primary_Customer__c
                FROM Account
                WHERE Id = :sv.CUSTOMERlookup__c
                LIMIT 1
            ];
            
            Account orderCustomer;
            
            if (String.isBlank(showroomCustomer.Gender__c) && String.isNotBlank(customerGender)) {
                showroomCustomer.Gender__c = customerGender;
            }
            
            if (useAlternateCustomer == true && String.isBlank(showroomCustomer.Gender__c)) {
                throw new AuraHandledException(
                    'Gender is mandatory for primary customer before creating order with another customer.'
                );
            }
            
            if (
                useAlternateCustomer == true &&
                (
                    showroomCustomer.Gender__c == 'Other' ||
                    showroomCustomer.Gender__c == 'Prefer not to say'
                )
            ) {
                relation = 'Other';
            }
            
            if (
                useAlternateCustomer == true &&
                String.isNotBlank(billingCustomerPhone) &&
                billingCustomerPhone == showroomCustomer.Phone
            ) {
                throw new AuraHandledException(
                    'Billing customer phone cannot be same as showroom visit customer phone.'
                );
            }
            
            if (useAlternateCustomer != true) {
                orderCustomer = showroomCustomer;
                accountsToActivate.add(showroomCustomer.Id);
            } else {
                if (
                    String.isBlank(billingCustomerName) ||
                    String.isBlank(billingCustomerPhone) ||
                    String.isBlank(relation)
                ) {
                    throw new AuraHandledException(
                        'Billing Customer Name, Phone and Relation are mandatory.'
                    );
                }
                
                if (existingBillingCustomerId != null) {
                    orderCustomer = [
                        SELECT Id, Name, Phone, Status__c,
                        Country__c, District__c, Residential_City__c,
                        Locality_Area__c, Pin_Code__c, Permanent_Address__c,
                        Village__c, State_Province__c
                        FROM Account
                        WHERE Id = :existingBillingCustomerId
                        LIMIT 1
                    ];
                    accountsToActivate.add(orderCustomer.Id);
                } else {
                    List<Account> existingAccounts = [
                        SELECT Id, Name, Phone, Status__c,
                        Country__c, District__c, Residential_City__c,
                        Locality_Area__c, Pin_Code__c, Permanent_Address__c,
                        Village__c, State_Province__c
                        FROM Account
                        WHERE Phone = :billingCustomerPhone
                        LIMIT 1
                    ];
                    
                    if (!existingAccounts.isEmpty()) {
                        orderCustomer = existingAccounts[0];
                        accountsToActivate.add(orderCustomer.Id);
                    } else {
                        orderCustomer = new Account(
                            Name = billingCustomerName,
                            Phone = billingCustomerPhone,
                            Whatsapp_number__c = billingCustomerPhone,
                            Status__c = 'Active'
                        );
                        
                        if (sameAddressAsPrimary == true) {
                            orderCustomer.Country__c = showroomCustomer.Country__c;
                            orderCustomer.District__c = showroomCustomer.District__c;
                            orderCustomer.Residential_City__c = showroomCustomer.Residential_City__c;
                            orderCustomer.Locality_Area__c = showroomCustomer.Locality_Area__c;
                            orderCustomer.Pin_Code__c = showroomCustomer.Pin_Code__c;
                            orderCustomer.Permanent_Address__c = showroomCustomer.Permanent_Address__c;
                            orderCustomer.Village__c = showroomCustomer.Village__c;
                            orderCustomer.State_Province__c = showroomCustomer.State_Province__c;
                        }
                        
                        insert orderCustomer;
                        accountsToActivate.add(orderCustomer.Id);
                    }
                }
                
                if (sameAddressAsPrimary == true && orderCustomer != null) {
                    orderCustomer.Country__c = showroomCustomer.Country__c;
                    orderCustomer.District__c = showroomCustomer.District__c;
                    orderCustomer.Residential_City__c = showroomCustomer.Residential_City__c;
                    orderCustomer.Locality_Area__c = showroomCustomer.Locality_Area__c;
                    orderCustomer.Pin_Code__c = showroomCustomer.Pin_Code__c;
                    orderCustomer.Permanent_Address__c = showroomCustomer.Permanent_Address__c;
                    orderCustomer.Village__c = showroomCustomer.Village__c;
                    orderCustomer.State_Province__c = showroomCustomer.State_Province__c;
                    update orderCustomer;
                }
                
                Contact showroomCustomerContact = getOrCreateSelfContact(showroomCustomer);
                Contact billingCustomerContact = getOrCreateSelfContact(orderCustomer);
                
                createOrUpdateRelationship(
                    showroomCustomer.Id,
                    billingCustomerContact.Id,
                    relation
                );
                
                String reverseRelation = getReverseRelation(relation, showroomCustomer.Gender__c);
                
                createOrUpdateRelationship(
                    orderCustomer.Id,
                    showroomCustomerContact.Id,
                    reverseRelation
                );
                
                syncCompleteFamilyTree(showroomCustomer.Id, orderCustomer.Id);
            }
            
            String orderPhone = useAlternateCustomer
                ? billingCustomerPhone
                : showroomCustomer.Phone;
            
            /*
* NEW UPDATED LOGIC:
* Buying For phone search + account create/reuse + relationship create.
* Order is still created against showroom customer when useAlternateCustomer = false.
*/
            if (
                !useAlternateCustomer &&
                buyingFor != 'Self' &&
                buyingFor != 'Other'
            ) {
                if (String.isBlank(buyingForName)) {
                    throw new AuraHandledException(buyingFor + ' Name is mandatory.');
                }
                
                if (String.isBlank(buyingForPhone)) {
                    throw new AuraHandledException(buyingFor + ' Phone is mandatory.');
                }
                
                String cleanBuyingForPhone = normalizePhone(buyingForPhone);
                String cleanShowroomPhone = normalizePhone(showroomCustomer.Phone);
                
                if (String.isBlank(cleanBuyingForPhone)) {
                    throw new AuraHandledException(buyingFor + ' Phone is mandatory.');
                }
                
                if (
                    String.isNotBlank(cleanShowroomPhone) &&
                    cleanBuyingForPhone == cleanShowroomPhone
                ) {
                    throw new AuraHandledException(
                        buyingFor + ' phone cannot be same as showroom visit customer phone.'
                    );
                }
                
                Account buyingForAccount;
                
                List<Account> existingBuyingForAccounts = [
                    SELECT Id, Name, Phone, Status__c,
                    Country__c, District__c, Residential_City__c,
                    Locality_Area__c, Pin_Code__c, Permanent_Address__c,
                    Village__c, State_Province__c
                    FROM Account
                    WHERE Phone = :cleanBuyingForPhone
                    LIMIT 1
                ];
                
                if (!existingBuyingForAccounts.isEmpty()) {
                    buyingForAccount = existingBuyingForAccounts[0];
                } else {
                    buyingForAccount = new Account(
                        Name = buyingForName,
                        Phone = cleanBuyingForPhone,
                        Whatsapp_number__c = cleanBuyingForPhone,
                        Status__c = 'Prospect'
                    );
                    
                    insert buyingForAccount;
                }
                
                Contact showroomCustomerContact = getOrCreateSelfContact(showroomCustomer);
                Contact buyingForContact = getOrCreateSelfContact(buyingForAccount);
                
                createOrUpdateRelationship(
                    showroomCustomer.Id,
                    buyingForContact.Id,
                    buyingFor
                );
                
                String reverseBuyingForRelation = getReverseRelation(
                    buyingFor,
                    showroomCustomer.Gender__c
                );
                
                createOrUpdateRelationship(
                    buyingForAccount.Id,
                    showroomCustomerContact.Id,
                    reverseBuyingForRelation
                );
                
                syncCompleteFamilyTree(showroomCustomer.Id, buyingForAccount.Id);
            }
            
            List<Sales_Executive_Activity_Tracking__c> activeSessions = [
                SELECT Id,
                Sales_Executive__c,
                Sales_Executive__r.Name
                FROM Sales_Executive_Activity_Tracking__c
                WHERE Session_Status__c = 'Active'
                LIMIT 1
            ];
            
            if (activeSessions.isEmpty()) {
                throw new AuraHandledException(
                    'No active sales executive session found. Please login before creating order.'
                );
            }
            
            Sales_Executive_Activity_Tracking__c activeSession = activeSessions[0];
            
            Customer_Order__c order = new Customer_Order__c(
                Customer__c = orderCustomer.Id,
                Phone__c = orderPhone,
                Showroom_Visit__c = sv.Id,
                Store__c = sv.StoreLookup__c,
                Sales_Executives__c = activeSession.Sales_Executive__c,
                Order_Date__c = Date.today(),
                Buying_For__c = buyingFor,
                Order_Status__c = 'Draft'
            );
            
            insert order;
            
            showroomCustomer.Primary_Customer__c = true;
            update showroomCustomer;
            
            if (payAdvance == true) {
                Order_Advance__c adv = new Order_Advance__c(
                    Advance_Against__c = 'Order',
                    Advance_Amount__c = advanceAmount,
                    Advance_Date__c = Date.today(),
                    Showroom_Visit__c = sv.Id,
                    Customer_Order__c = order.Id,
                    Sales_Executives__c = activeSession.Sales_Executive__c,
                    Sales_Executive_Name__c = activeSession.Sales_Executive__r.Name,
                    Orient_Customer__c = orderCustomer.Id,
                    Customer_Phone__c = orderPhone
                );
                
                insert adv;
            }
            
            if (!accountsToActivate.isEmpty()) {
                List<Account> accs = [
                    SELECT Id, Status__c
                    FROM Account
                    WHERE Id IN :accountsToActivate
                ];
                
                for (Account a : accs) {
                    a.Status__c = 'Active';
                }
                
                update accs;
            }
            
            /*Set<Id> usedWishlistItemIds = new Set<Id>();

for (Customer_Order_Line_Item__c li : [
SELECT Wishlist_Item__c
FROM Customer_Order_Line_Item__c
WHERE Wishlist_Item__c IN :wishlistItemIds
]) {
usedWishlistItemIds.add(li.Wishlist_Item__c);
}

if (!usedWishlistItemIds.isEmpty()) {
throw new AuraHandledException(
'One or more selected wishlist items are already used in an order.'
);
}*/
            
            Set<Id> usedWishlistItemIds = new Set<Id>();
            
            for (Customer_Order_Line_Item__c li : [
                SELECT Wishlist_Item__c,
                Wishlist_Item__r.Status__c
                FROM Customer_Order_Line_Item__c
                WHERE Wishlist_Item__c IN :wishlistItemIds
                AND Wishlist_Item__r.Status__c = 'Order Placed'
            ]) {
                usedWishlistItemIds.add(li.Wishlist_Item__c);
            }
            
            if (!usedWishlistItemIds.isEmpty()) {
                throw new AuraHandledException(
                    'One or more selected wishlist items are already order placed.'
                );
            }
            
            List<Customer_Order_Line_Item__c> lines = new List<Customer_Order_Line_Item__c>();
            
            for (Wishlist_Item__c wi : [
                SELECT Id, Barcode_Value__c, Description__c, Total_Price_Incl_GST__c
                FROM Wishlist_Item__c
                WHERE Id IN :wishlistItemIds
            ]) {
                lines.add(new Customer_Order_Line_Item__c(
                    Customer_Order__c = order.Id,
                    Wishlist_Item__c = wi.Id,
                    Barcode_Value__c = wi.Barcode_Value__c,
                    Description__c = wi.Description__c,
                    Final_Price__c = wi.Total_Price_Incl_GST__c
                ));
            }
            
            insert lines;
            
            List<Wishlist_Item__c> wishlistToUpdate = new List<Wishlist_Item__c>();
            
            for (Wishlist_Item__c wi : [
                SELECT Id, Status__c
                FROM Wishlist_Item__c
                WHERE Id IN :wishlistItemIds
            ]) {
                wi.Status__c = 'Order Placed';
                wishlistToUpdate.add(wi);
            }
            
            update wishlistToUpdate;
            
            return order.Id;
            
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }
    
    private static Contact getOrCreateSelfContact(Account acc) {
        if (acc == null || acc.Id == null) {
            throw new AuraHandledException('Account information is missing for contact creation.');
        }
        
        String cleanPhone = normalizePhone(acc.Phone);
        
        List<Contact> conList;
        
        if (String.isNotBlank(cleanPhone)) {
            conList = [
                SELECT Id, FirstName, LastName, Phone, MobilePhone, AccountId
                FROM Contact
                WHERE AccountId = :acc.Id
                AND (
                    Phone = :cleanPhone
                    OR MobilePhone = :cleanPhone
                )
                LIMIT 1
            ];
        } else {
            conList = [
                SELECT Id, FirstName, LastName, Phone, MobilePhone, AccountId
                FROM Contact
                WHERE AccountId = :acc.Id
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
        }
        
        if (!conList.isEmpty()) {
            return conList[0];
        }
        
        Contact con = new Contact();
        con.LastName = String.isNotBlank(acc.Name) ? acc.Name : 'Customer';
        con.AccountId = acc.Id;
        
        if (String.isNotBlank(cleanPhone)) {
            con.Phone = cleanPhone;
            con.MobilePhone = cleanPhone;
        }
        
        insert con;
        return con;
    }
    
    private static void createOrUpdateRelationship(
        Id orientCustomerId,
        Id familyMemberContactId,
        String relationType
    ) {
        if (orientCustomerId == null || familyMemberContactId == null) {
            return;
        }
        
        Contact familyContact = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Id = :familyMemberContactId
            LIMIT 1
        ];
        
        if (familyContact.AccountId == null) {
            return;
        }
        
        List<Relationship__c> existingList = [
            SELECT Id, Relationship_Type__c, Family_Member__c
            FROM Relationship__c
            WHERE Orient_Customer__c = :orientCustomerId
            AND Family_Member__r.AccountId = :familyContact.AccountId
            LIMIT 1
        ];
        
        if (!existingList.isEmpty()) {
            Relationship__c existingRel = existingList[0];
            
            Boolean needUpdate = false;
            
            if (existingRel.Relationship_Type__c != relationType) {
                existingRel.Relationship_Type__c = relationType;
                needUpdate = true;
            }
            
            if (existingRel.Family_Member__c != familyMemberContactId) {
                existingRel.Family_Member__c = familyMemberContactId;
                needUpdate = true;
            }
            
            if (needUpdate) {
                update existingRel;
            }
            
            return;
        }
        
        Relationship__c newRel = new Relationship__c();
        newRel.Orient_Customer__c = orientCustomerId;
        newRel.Family_Member__c = familyMemberContactId;
        newRel.Relationship_Type__c = relationType;
        insert newRel;
    }
    
    private static void syncCompleteFamilyTree(Id currentAccountId, Id newFamilyAccountId) {
        Set<Id> familyAccountIds = collectConnectedFamilyAccounts(
            new Set<Id>{ currentAccountId, newFamilyAccountId }
        );
        
        if (familyAccountIds.isEmpty()) {
            return;
        }
        
        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, Name, Phone
            FROM Account
            WHERE Id IN :familyAccountIds
        ]);
        
        Map<Id, Contact> accountToContactMap = new Map<Id, Contact>();
        
        for (Account acc : accountMap.values()) {
            Contact con = getOrCreateSelfContact(acc);
            accountToContactMap.put(acc.Id, con);
        }
        
        Map<Id, Map<Id, Relationship__c>> existingRelationMap =
            buildExistingRelationMap(familyAccountIds);
        
        List<Relationship__c> toInsert = new List<Relationship__c>();
        
        for (Id ownerAccountId : familyAccountIds) {
            for (Id targetAccountId : familyAccountIds) {
                if (ownerAccountId == targetAccountId) {
                    continue;
                }
                
                if (
                    existingRelationMap.containsKey(ownerAccountId) &&
                    existingRelationMap.get(ownerAccountId).containsKey(targetAccountId)
                ) {
                    continue;
                }
                
                Contact targetContact = accountToContactMap.get(targetAccountId);
                
                if (targetContact == null) {
                    continue;
                }
                
                String inferredRelation = inferMissingRelation(
                    ownerAccountId,
                    targetAccountId,
                    currentAccountId,
                    existingRelationMap
                );
                
                Relationship__c newRel = new Relationship__c();
                newRel.Orient_Customer__c = ownerAccountId;
                newRel.Family_Member__c = targetContact.Id;
                newRel.Relationship_Type__c = inferredRelation;
                toInsert.add(newRel);
                
                if (!existingRelationMap.containsKey(ownerAccountId)) {
                    existingRelationMap.put(ownerAccountId, new Map<Id, Relationship__c>());
                }
                
                existingRelationMap.get(ownerAccountId).put(targetAccountId, newRel);
            }
        }
        
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }
    
    private static Set<Id> collectConnectedFamilyAccounts(Set<Id> startAccountIds) {
        Set<Id> result = new Set<Id>();
        result.addAll(startAccountIds);
        
        Boolean changed = true;
        Integer loopCount = 0;
        
        while (changed && loopCount < 5) {
            changed = false;
            loopCount++;
            
            List<Relationship__c> relList = [
                SELECT Id,
                Orient_Customer__c,
                Family_Member__c,
                Family_Member__r.AccountId
                FROM Relationship__c
                WHERE Orient_Customer__c IN :result
                OR Family_Member__r.AccountId IN :result
            ];
            
            for (Relationship__c rel : relList) {
                if (
                    rel.Orient_Customer__c != null &&
                    !result.contains(rel.Orient_Customer__c)
                ) {
                    result.add(rel.Orient_Customer__c);
                    changed = true;
                }
                
                if (
                    rel.Family_Member__r != null &&
                    rel.Family_Member__r.AccountId != null &&
                    !result.contains(rel.Family_Member__r.AccountId)
                ) {
                    result.add(rel.Family_Member__r.AccountId);
                    changed = true;
                }
            }
        }
        
        return result;
    }
    
    private static Map<Id, Map<Id, Relationship__c>> buildExistingRelationMap(Set<Id> accountIds) {
        Map<Id, Map<Id, Relationship__c>> result =
            new Map<Id, Map<Id, Relationship__c>>();
        
        List<Relationship__c> relList = [
            SELECT Id,
            Orient_Customer__c,
            Family_Member__c,
            Family_Member__r.AccountId,
            Relationship_Type__c
            FROM Relationship__c
            WHERE Orient_Customer__c IN :accountIds
        ];
        
        for (Relationship__c rel : relList) {
            if (
                rel.Orient_Customer__c == null ||
                rel.Family_Member__r == null ||
                rel.Family_Member__r.AccountId == null
            ) {
                continue;
            }
            
            Id ownerAccountId = rel.Orient_Customer__c;
            Id targetAccountId = rel.Family_Member__r.AccountId;
            
            if (!result.containsKey(ownerAccountId)) {
                result.put(ownerAccountId, new Map<Id, Relationship__c>());
            }
            
            result.get(ownerAccountId).put(targetAccountId, rel);
        }
        
        return result;
    }
    
    private static String inferMissingRelation(
        Id ownerAccountId,
        Id targetAccountId,
        Id centerAccountId,
        Map<Id, Map<Id, Relationship__c>> existingRelationMap
    ) {
        String ownerToCenter = getRelationType(
            existingRelationMap,
            ownerAccountId,
            centerAccountId
        );
        
        String centerToTarget = getRelationType(
            existingRelationMap,
            centerAccountId,
            targetAccountId
        );
        
        String centerToOwner = getRelationType(
            existingRelationMap,
            centerAccountId,
            ownerAccountId
        );
        
        if (String.isBlank(ownerToCenter) || String.isBlank(centerToTarget)) {
            return 'Other';
        }
        
        return inferRelationFromCenter(ownerToCenter, centerToTarget, centerToOwner);
    }
    
    private static String getRelationType(
        Map<Id, Map<Id, Relationship__c>> existingRelationMap,
        Id ownerAccountId,
        Id targetAccountId
    ) {
        if (
            !existingRelationMap.containsKey(ownerAccountId) ||
            !existingRelationMap.get(ownerAccountId).containsKey(targetAccountId)
        ) {
            return null;
        }
        
        return existingRelationMap
            .get(ownerAccountId)
            .get(targetAccountId)
            .Relationship_Type__c;
    }
    
    private static String inferRelationFromCenter(
        String ownerToCenter,
        String centerToTarget,
        String centerToOwner
    ) {
        if (String.isBlank(ownerToCenter) || String.isBlank(centerToTarget)) {
            return 'Other';
        }
        
        /*
Parent profile should identify child's father/mother as spouse.
Example:
Father -> Child = Son/Daughter
Child -> Mother = Mother
So Father -> Mother = Wife
*/
        if (
            (ownerToCenter == 'Son' || ownerToCenter == 'Daughter') &&
            centerToTarget == 'Mother'
        ) {
            return 'Wife';
        }
        
        if (
            (ownerToCenter == 'Son' || ownerToCenter == 'Daughter') &&
            centerToTarget == 'Father'
        ) {
            return 'Husband';
        }
        
        /*
Sibling shared grandparent logic.
If one sibling has grandparent, other sibling also gets same grandparent relation.
*/
        if (
            (ownerToCenter == 'Brother' || ownerToCenter == 'Sister') &&
            (
                centerToTarget == 'Maternal Grandmother' ||
                centerToTarget == 'Maternal Grandfather' ||
                centerToTarget == 'Grandmother' ||
                centerToTarget == 'Grandfather'
            )
        ) {
            return centerToTarget;
        }
        
        /*
Parent spouse logic:
Child -> Mother -> Husband = Father
Child -> Father -> Wife = Mother
*/
        if (ownerToCenter == 'Mother' && centerToTarget == 'Husband') {
            return 'Father';
        }
        
        if (ownerToCenter == 'Father' && centerToTarget == 'Wife') {
            return 'Mother';
        }
        
        /*
Maternal grandparent reverse side logic:
Example:
Child -> Maternal Grandmother
Mother profile should see her as Mother
Father profile should see her as Mother In-laws
*/
        if (centerToTarget == 'Maternal Grandmother') {
            if (centerToOwner == 'Mother') {
                return 'Mother';
            }
            
            if (centerToOwner == 'Father') {
                return 'Mother In-laws';
            }
            
            return 'Other';
        }
        
        if (centerToTarget == 'Maternal Grandfather') {
            if (centerToOwner == 'Mother') {
                return 'Father';
            }
            
            if (centerToOwner == 'Father') {
                return 'Father In-laws';
            }
            
            return 'Other';
        }
        
        /*
Paternal grandparent reverse side logic:
Existing Grandfather / Grandmother is treated as father's side.
*/
        if (centerToTarget == 'Grandmother') {
            if (centerToOwner == 'Father') {
                return 'Mother';
            }
            
            if (centerToOwner == 'Mother') {
                return 'Mother In-laws';
            }
            
            return 'Other';
        }
        
        if (centerToTarget == 'Grandfather') {
            if (centerToOwner == 'Father') {
                return 'Father';
            }
            
            if (centerToOwner == 'Mother') {
                return 'Father In-laws';
            }
            
            return 'Other';
        }
        
        /*
Child -> Parent -> Parent.
UPDATED:
If child sees center as Mother, then center's parents are maternal grandparents.
If child sees center as Father, then center's parents are paternal grandparents.
*/
        if (ownerToCenter == 'Mother' && centerToTarget == 'Father') {
            return 'Maternal Grandfather';
        }
        
        if (ownerToCenter == 'Mother' && centerToTarget == 'Mother') {
            return 'Maternal Grandmother';
        }
        
        if (ownerToCenter == 'Father' && centerToTarget == 'Father') {
            return 'Grandfather';
        }
        
        if (ownerToCenter == 'Father' && centerToTarget == 'Mother') {
            return 'Grandmother';
        }
        
        /*
Grandchild logic:
Parent -> Child -> Child = Grandson / Granddaughter
*/
        if (
            (ownerToCenter == 'Son' || ownerToCenter == 'Daughter') &&
            centerToTarget == 'Son'
        ) {
            return 'Grandson';
        }
        
        if (
            (ownerToCenter == 'Son' || ownerToCenter == 'Daughter') &&
            centerToTarget == 'Daughter'
        ) {
            return 'Granddaughter';
        }
        
        /*
Child spouse logic:
Parent -> Child -> Spouse = Son In-laws / Daughter In-laws
*/
        if (
            (ownerToCenter == 'Son' || ownerToCenter == 'Daughter') &&
            centerToTarget == 'Wife'
        ) {
            return 'Daughter In-laws';
        }
        
        if (
            (ownerToCenter == 'Son' || ownerToCenter == 'Daughter') &&
            centerToTarget == 'Husband'
        ) {
            return 'Son In-laws';
        }
        
        /*
Sibling logic:
Parent profile sees another child as Brother/Sister of existing child.
*/
        if (isParentRelation(ownerToCenter) && centerToTarget == 'Son') {
            return 'Brother';
        }
        
        if (isParentRelation(ownerToCenter) && centerToTarget == 'Daughter') {
            return 'Sister';
        }
        
        /*
Spouse should see spouse's child as Son/Daughter.
*/
        if (
            (ownerToCenter == 'Husband' || ownerToCenter == 'Wife') &&
            isChildRelation(centerToTarget)
        ) {
            return centerToTarget;
        }
        
        /*
Parent of spouse.
*/
        if (
            (ownerToCenter == 'Husband' || ownerToCenter == 'Wife') &&
            centerToTarget == 'Father'
        ) {
            return 'Father In-laws';
        }
        
        if (
            (ownerToCenter == 'Husband' || ownerToCenter == 'Wife') &&
            centerToTarget == 'Mother'
        ) {
            return 'Mother In-laws';
        }
        
        /*
Parent -> child spouse.
*/
        if (ownerToCenter == 'Father' || ownerToCenter == 'Mother') {
            if (centerToTarget == 'Husband') {
                return 'Son In-laws';
            }
            
            if (centerToTarget == 'Wife') {
                return 'Daughter In-laws';
            }
        }
        
        /*
Sibling child:
Brother/Sister's son = Nephew
Brother/Sister's daughter = Niece
*/
        if (ownerToCenter == 'Brother' || ownerToCenter == 'Sister') {
            if (centerToTarget == 'Son') {
                return 'Nephew';
            }
            
            if (centerToTarget == 'Daughter') {
                return 'Niece';
            }
        }
        
        /*
Parent sibling:
Parent's brother = Uncle
Parent's sister = Aunt
*/
        if (ownerToCenter == 'Son' || ownerToCenter == 'Daughter') {
            if (centerToTarget == 'Brother') {
                return 'Uncle';
            }
            
            if (centerToTarget == 'Sister') {
                return 'Aunt';
            }
        }
        
        /*
Cousin logic:
Aunt/Uncle's child = Cousin
*/
        if (
            (ownerToCenter == 'Aunt' || ownerToCenter == 'Uncle') &&
            isChildRelation(centerToTarget)
        ) {
            return 'Cousin';
        }
        
        /*
Existing cousin relation should remain cousin.
*/
        if (centerToTarget == 'Cousin') {
            return 'Cousin';
        }
        
        /*
Friend logic:
Existing Friend relation will be copied as Friend.
Keep this only if client wants friend to sync in family tree.
*/
        if (centerToTarget == 'Friend') {
            return 'Friend';
        }
        
        /*
Brother / Sister in-laws.
*/
        if (
            (ownerToCenter == 'Husband' || ownerToCenter == 'Wife') &&
            centerToTarget == 'Brother'
        ) {
            return 'Brother In-laws';
        }
        
        if (
            (ownerToCenter == 'Husband' || ownerToCenter == 'Wife') &&
            centerToTarget == 'Sister'
        ) {
            return 'Sister In-laws';
        }
        
        return 'Other';
    }
    private static Boolean isChildRelation(String relationType) {
        return relationType == 'Son' || relationType == 'Daughter';
    }
    private static Boolean isParentRelation(String relationType) {
        return relationType == 'Father' || relationType == 'Mother';
    }
    
    private static String normalizePhone(String phone) {
        if (String.isBlank(phone)) {
            return '';
        }
        
        String result = '';
        
        for (Integer i = 0; i < phone.length(); i++) {
            String ch = phone.substring(i, i + 1);
            
            if (ch >= '0' && ch <= '9') {
                result += ch;
            }
        }
        
        if (result.length() > 10) {
            result = result.substring(result.length() - 10);
        }
        
        return result;
    }
}