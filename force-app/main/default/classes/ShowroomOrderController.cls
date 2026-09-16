public with sharing class ShowroomOrderController {
    // DTO class used to send Tag Price Detail Line data to LWC
    public class TagPriceDetailDTO {
        @AuraEnabled public String bomItem;
        @AuraEnabled public String purity;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public String uom;
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Decimal amount;
    }
    // DTO class used to send Tag Price SCM data to LWC
    public class TagPriceScmDTO {
        @AuraEnabled public String bomItem;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String makingType;
    }
    // DTO class used to send Account/customer data to LWC while searching by phone
    public class CustomerInfoDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String phone;
        @AuraEnabled public String pan;
        @AuraEnabled public String gst;
        @AuraEnabled public String stateCode;
    }
    // Returns exact customer details based on phone number
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
    // Searches customers by phone starting digits for suggestion dropdown
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
    // DTO used to display Wishlist Item details with ACX weight and price details
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
    // Returns opposite relation for reverse family member contact creation
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
        
        if (relation == 'Father' || relation == 'Mother') {
            if (isMale) return 'Son';
            if (isFemale) return 'Daughter';
        }
        
        if (relation == 'Grandfather' || relation == 'Grandmother') {
            if (isMale) return 'Grandson';
            if (isFemale) return 'Granddaughter';
        }
        
        if (relation == 'Son' || relation == 'Daughter') {
            if (isMale) return 'Father';
            if (isFemale) return 'Mother';
        }
        
        if (relation == 'Brother' || relation == 'Sister') {
            if (isMale) return 'Brother';
            if (isFemale) return 'Sister';
        }
        
        if (relation == 'Husband') {
            return 'Wife';
        }
        
        if (relation == 'Wife') {
            return 'Husband';
        }
        
        if (relation == 'Niece' || relation == 'Nephew') {
            if (isMale) return 'Uncle';
            if (isFemale) return 'Aunt';
        }
        
        Map<String, String> sameRelationMap = new Map<String, String>{
            'Cousin' => 'Cousin',
                'In-laws' => 'In-laws',
                'Friend' => 'Friend',
                'Other' => 'Other'
                };
                    
                    if (sameRelationMap.containsKey(relation)) {
                        return sameRelationMap.get(relation);
                    }
        
        return 'Other';
    }
    // Fetches Showroom Visit details and linked customer information
    @AuraEnabled(cacheable=true)
    public static Showroom_Visit__c getShowroomVisit(Id showroomVisitId) {
        return [
            SELECT Id, Name, Customer_Phone__c, Visit_Date__c,
            CUSTOMERlookup__c,
            CUSTOMERlookup__r.Name,
            CUSTOMERlookup__r.PAN__c,
            CUSTOMERlookup__r.GST__c,
            CUSTOMERlookup__r.StateCode__c,
            StoreLookup__c,CUSTOMERlookup__r.Gender__c,
            Primary_Sales_Executive_Name__c
            FROM Showroom_Visit__c
            WHERE Id = :showroomVisitId
        ];
    }
    // Fetches wishlist items for showroom visit.
    // If same barcode exists multiple times, latest created wishlist item is considered.
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
        // Stores latest wishlist item by barcode to avoid duplicate barcode rows
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
        // Fetch latest ACX Tag Header for each wishlist item to get weight details
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
        // Fetch latest product price from Tag Price Line for each wishlist item
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
    
    // Main method to create Customer Order, Order Line Items, Advance and family member contacts
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
        // Rollback point to revert all DML if any error occurs
        Savepoint sp = Database.setSavepoint();
        Set<Id> accountsToActivate = new Set<Id>();
        try {
            // Validate required showroom visit id
            if (showroomVisitId == null) {
                throw new AuraHandledException('Showroom Visit Id is missing.');
            }
            // Validate at least one wishlist item selected
            if (wishlistItemIds == null || wishlistItemIds.isEmpty()) {
                throw new AuraHandledException('No wishlist items selected.');
            }
            /*if (payAdvance == true && (advanceAmount == null || advanceAmount <= 0)) {
throw new AuraHandledException('Advance amount must be greater than zero.');
}*/
            // Fetch showroom visit and linked primary customer
            Showroom_Visit__c sv = [
                SELECT Id,
                StoreLookup__c,
                Primary_Sales_Executive_Name__c,
                Primary_Sales_Executive_Name__r.Name,
                CUSTOMERlookup__c,CUSTOMERlookup__r.Gender__c
                FROM Showroom_Visit__c
                WHERE Id = :showroomVisitId
                LIMIT 1
            ];
            
            if (sv.CUSTOMERlookup__c == null) {
                throw new AuraHandledException('No customer linked to Showroom Visit.');
            }
            // Fetch primary/showroom customer account with required address fields
            Account showroomCustomer = [
                SELECT Id, Name, Phone, Status__c, Village__c,
                PAN__c, GST__c, StateCode__c,Gender__c,
                Permanent_Address__c,State_Province__c, 
                Pin_Code__c, Locality_Area__c, Residential_City__c, District__c,
                Country__c,Primary_Customer__c
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
            // Block same phone number for showroom customer and alternate billing customer
            if (
                useAlternateCustomer == true &&
                String.isNotBlank(billingCustomerPhone) &&
                billingCustomerPhone == showroomCustomer.Phone
            ) {
                throw new AuraHandledException(
                    'Billing customer phone cannot be same as showroom visit customer phone.'
                );
            }
            // If alternate customer is not selected, order will be created for showroom customer
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
                // If alternate customer is selected, billing customer details are mandatory
                if (existingBillingCustomerId != null) {
                    orderCustomer = [
                        SELECT Id, Name, Phone, Status__c
                        FROM Account
                        WHERE Id = :existingBillingCustomerId
                        LIMIT 1
                    ];
                    accountsToActivate.add(orderCustomer.Id);
                } else {
                    // If no selected customer, check whether Account already exists with billing phone
                    List<Account> existingAccounts = [
                        SELECT Id, Name, Phone, Status__c
                        FROM Account
                        WHERE Phone = :billingCustomerPhone
                        LIMIT 1
                    ];
                    if (!existingAccounts.isEmpty()) {
                        orderCustomer = existingAccounts[0];
                        accountsToActivate.add(orderCustomer.Id);
                    } else {
                        // If no existing billing account found, create new Account
                        orderCustomer = new Account(
                            Name = billingCustomerName,
                            Phone = billingCustomerPhone,
                            Whatsapp_number__c = billingCustomerPhone,
                            Status__c = 'Active'
                        );
                        // If same address checkbox is checked, copy showroom customer address to billing customer
                        if (sameAddressAsPrimary == true) {
                            orderCustomer.Country__c     = showroomCustomer.Country__c;
                            orderCustomer.District__c       = showroomCustomer.District__c;
                            orderCustomer.Residential_City__c      = showroomCustomer.Residential_City__c;
                            orderCustomer.Locality_Area__c = showroomCustomer.Locality_Area__c;
                            orderCustomer.Pin_Code__c    = showroomCustomer.Pin_Code__c;
                            orderCustomer.Permanent_Address__c      = showroomCustomer.Permanent_Address__c;
                            orderCustomer.Village__c      = showroomCustomer.Village__c;
                            orderCustomer.State_Province__c      = showroomCustomer.State_Province__c;
                        }
                        insert orderCustomer;
                        accountsToActivate.add(orderCustomer.Id);
                        // Create contact under showroom customer and map billing customer in family member lookup
                        Contact c = new Contact(
                            LastName    = billingCustomerName,
                            Phone       = billingCustomerPhone,
                            Relation__c = relation,
                            AccountId   = showroomCustomer.Id,
                            Family_Member_Account_Details__c = orderCustomer.Id
                        );
                        insert c;
                    }
                }
                // Update address for existing billing customer also when same address checkbox is checked
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
                // Create or update reverse contact under billing customer account
                List<Contact> existingReverseContacts = [
                    SELECT Id
                    FROM Contact
                    WHERE AccountId = :orderCustomer.Id
                    AND Phone = :showroomCustomer.Phone
                    LIMIT 1
                ];
                if (existingReverseContacts.isEmpty()) {
                    Contact reverseContact = new Contact(
                        LastName    = showroomCustomer.Name,
                        Phone       = showroomCustomer.Phone,
                        Relation__c = getReverseRelation(relation, showroomCustomer.Gender__c),
                        AccountId   = orderCustomer.Id,
                        Family_Member_Account_Details__c = showroomCustomer.Id
                    );
                    insert reverseContact;
                }else {
                    Contact reverseContact = existingReverseContacts[0];
                    reverseContact.Family_Member_Account_Details__c = showroomCustomer.Id;
                    update reverseContact;
                }
                // Create or update billing customer contact under showroom customer account
                List<Contact> existingBillingContactUnderShowroom = [
                    SELECT Id, Family_Member_Account_Details__c
                    FROM Contact
                    WHERE AccountId = :showroomCustomer.Id
                    AND Phone = :billingCustomerPhone
                    LIMIT 1
                ];
                if (existingBillingContactUnderShowroom.isEmpty()) {
                    Contact billingContact = new Contact(
                        LastName                         = billingCustomerName,
                        Phone                            = billingCustomerPhone,
                        Relation__c                      = relation,
                        AccountId                        = showroomCustomer.Id,
                        Family_Member_Account_Details__c = orderCustomer.Id
                    );
                    insert billingContact;
                } else {
                    Contact existingContact = existingBillingContactUnderShowroom[0];
                    existingContact.Family_Member_Account_Details__c = orderCustomer.Id;
                    update existingContact;
                }
            }
            String orderPhone = useAlternateCustomer
                ? billingCustomerPhone
                : showroomCustomer.Phone;
            if (
                !useAlternateCustomer &&
                buyingFor != 'Self' &&
                (!String.isBlank(buyingForName) || !String.isBlank(buyingForPhone))
            ) {
                String prospectPhone = !String.isBlank(buyingForPhone)
                    ? buyingForPhone
                    : '0000000000';
                Account buyingForAccount = new Account(
                    Name = String.isNotBlank(buyingForName)
                    ? buyingForName
                    : buyingFor + ' of ' + showroomCustomer.Name,
                    Phone = prospectPhone,
                    Status__c = 'Prospect'
                );
                insert buyingForAccount;
            }
            // Fetch active sales executive session before creating order
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
            // Create main customer order record
            Customer_Order__c order = new Customer_Order__c(
                Customer__c         = orderCustomer.Id,
                Phone__c            = orderPhone,
                Showroom_Visit__c   = sv.Id,
                Store__c            = sv.StoreLookup__c,
                Sales_Executives__c = activeSession.Sales_Executive__c,
                Order_Date__c       = Date.today(),
                Buying_For__c       = buyingFor,
                Order_Status__c     = 'Draft'
            );
            insert order;
            showroomCustomer.Primary_Customer__c = true;
            update showroomCustomer;
            if (payAdvance == true) {
                Order_Advance__c adv = new Order_Advance__c(
                    Advance_Against__c       = 'Order',
                    Advance_Amount__c        = advanceAmount,
                    Advance_Date__c          = Date.today(),
                    Showroom_Visit__c        = sv.Id,
                    Customer_Order__c        = order.Id,
                    Sales_Executives__c      = activeSession.Sales_Executive__c,
                    Sales_Executive_Name__c  = activeSession.Sales_Executive__r.Name,
                    Orient_Customer__c       = orderCustomer.Id,
                    Customer_Phone__c        = orderPhone
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
            Set<Id> usedWishlistItemIds = new Set<Id>();
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
            }
            List<Customer_Order_Line_Item__c> lines = new List<Customer_Order_Line_Item__c>();
            
            for (Wishlist_Item__c wi : [
                SELECT Id, Barcode_Value__c, Description__c, Total_Price_Incl_GST__c
                FROM Wishlist_Item__c
                WHERE Id IN :wishlistItemIds
            ]) {
                lines.add(new Customer_Order_Line_Item__c(
                    Customer_Order__c = order.Id,
                    Wishlist_Item__c  = wi.Id,
                    Barcode_Value__c  = wi.Barcode_Value__c,
                    Description__c    = wi.Description__c,
                    Final_Price__c    = wi.Total_Price_Incl_GST__c
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
            // Rollback all changes if any error occurs
            Database.rollback(sp);
            throw e;
        }
    }
}