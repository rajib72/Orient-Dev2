public with sharing class Ctrl_FetchPreEstimateBC {
    private static final String BC_BASE_URL = 'callout:Orient_API_Access_NC/' + System.Label.BC_Endpoint;
    // ==========================================
    // STATIC MAPPING DICTIONARIES
    // ==========================================
    private static Map<String, String> TRANSACTION_TYPE_MAP = new Map<String, String>{
        'Estimate'         => '0= Estimate',
        'Scheme'           => '1= Scheme',
        'Advance'          => '2= Advance',
        'Old Gold'         => '3= Old Gold',
        'Sales Return'     => '4= Sales Return',
        'Old Gold Return'  => '5= Old Gold Return',
        'Customer Receipt' => '6= Customer Receipt',
        'None'             => '7= None',
        'Free Item'        => '8= Free Item'
    };
                
    private static Map<String, String> DOCUMENT_SUB_TYPE_MAP = new Map<String, String>{
        'Normal' => '0= Normal',
        'B2B'    => '1= B2B',
        'B2C'    => '2= B2C'
    };
                            
    private static Map<String, String> DELIVERY_TYPE_MAP = new Map<String, String>{
        'Store Address'    => '0= Store Address',
        'Customer Address' => '1= Customer Address'
    };
                                        
    private static Map<String, String> STATUS_MAP = new Map<String, String>{
        'Open'     => '0= Open',
        'Released' => '1= Released',
        'Posted'   => '2= Posted',
        'Closed'   => '3= Closed',
        'Park'     => '4= Park',
        'Cancel'   => '5= Cancel'
    };
                                                    
    private static Map<String, String> INCENTIVE_COMMISSION_MAP = new Map<String, String>{
        'None'          => '0= None',
        'Gold'          => '1= Gold',
        'Silver'        => '2= Silver',
        'Platinum'      => '3= Platinum',
        'Diamond'       => '4= Diamond',
        'MRP'           => '5= MRP',
        'Gem Stone'     => '6= Gem Stone',
        'Loose Diamond' => '7= Loose Diamond'
    };
                                                        
    private static Map<String, String> MAKING_TYPE_MAP = new Map<String, String>{
        ''                  => '0= (Empty)',
        ' '                 => '0= (Empty)',
        'Net on Gram'       => '1= Net on Gram',
        'Per Pcs'           => '2= Per Pcs',
        'Percentage on Gross'=> '3= Percentage on Gross',
        'Percentage On Net' => '4= Percentage On Net',
        'Certification DPC' => '5= Certification DPC',
        'HallMarking'       => '6= HallMarking',
        'Markup'            => '7= Markup',
        'Net on Pure'       => '8= Net on Pure',
        'Gross on Pure'     => '9= Gross on Pure',
        'Wastage Gross'     => '10= Wastage Gross',
        'Wastge Net'        => '11= Wastge Net',
        'Brand'             => '12= Brand',
        'Brand Per PCS'     => '13= Brand Per PCS',
        'Wastage PCS'       => '14= Wastage PCS',
        'Gross on Gram'     => '15= Gross on Gram',
        'HallMarking Pcs'   => '16= HallMarking Pcs',
        'Fix/Lumpsum'       => '17= Fix/Lumpsum'
    };
                                                            
    private static Map<String, String> METAL_TYPE_MAP = new Map<String, String>{
        'None'                      => '0= None',
        'Gold'                      => '1= Gold',
        'Silver'                    => '2= Silver',
        'Platinum'                  => '3= Platinum',
        'Others'                    => '4= Others',
        'Stone_CT'                  => '5= Stone_CT',
        'Stone_GM'                  => '6= Stone_GM',
        'Diamond'                   => '7= Diamond',
        'Stone_Pcs'                 => '8= Stone_Pcs',
        'MRP Gold'                  => '9= MRP Gold',
        'MRP Silver'                => '10= MRP Silver',
        'MRP Platinum'              => '11= MRP Platinum',
        'MRP Gold Weight'           => '12= MRP Gold Weight',
        'MRP Silver Weight'         => '13= MRP Silver Weight',
        'MRP Platinum Weight'       => '14= MRP Platinum Weight',
        'Non Metal as Metal'        => '17= Non Metal as Metal',
        'MRP Stone_CT'              => '18= MRP Stone_CT',
        'MRP Stone_GM'              => '19= MRP Stone_GM',
        'MRP Diamond'               => '20= MRP Diamond',
        'MRP Stone_CT Weight'       => '21= MRP Stone_CT Weight',
        'MRP Stone_GM Weight'       => '22= MRP Stone_GM Weight',
        'MRP Diamond Weight'        => '23= MRP Diamond Weight',
        'Stone_CT Precious'         => '24= Stone_CT Precious',
        'Stone_GM Precious'         => '25= Stone_GM Precious',
        'Stone_CT Semi Precious'    => '26= Stone_CT Semi Precious',
        'Stone_GM Semi Precious'    => '27= Stone_GM Semi Precious'
    };
                                                                
    private static Map<String, String> ITEM_TYPE_GROUP_MAP = new Map<String, String>{
        'None'     => '0= None',
        'Gold'     => '1= Gold',
        'Silver'   => '2= Silver',
        'Platinum' => '3= Platinum',
        'Diamond'  => '4= Diamond',
        'MRP'      => '5= MRP'
    };
                                                                    
    // ==========================================
    // MAIN METHOD
    // ==========================================
                                                                    
    @AuraEnabled
    public static String fetchPreEstimate(Id orderId) {
        Savepoint sp; 
        try {
            // Newest first sorting prevents old removed lines from stealing the payload
            List<Customer_Order__c> orders = [
                SELECT Id, Pre_Document_No__c, 
                (SELECT Id, Barcode_Value__c, Line_Item_Status_On_Salesforce__c, Wishlist_Item__c
                 FROM Customer_Order_Line_Items__r
                 WHERE Barcode_Value__c != null 
                 ORDER BY CreatedDate DESC) 
                FROM Customer_Order__c 
                WHERE Id = :orderId LIMIT 1
            ];
                                                                                
            if (orders.isEmpty()) {
                return 'Error: Could not find the Estimation record. Invalid Record ID.';
            }
                                                                                
            Customer_Order__c order = orders[0];
            String docNo = order.Pre_Document_No__c;
                                                                                
            if (String.isBlank(docNo)) {
                return 'Error: Pre Document No is missing on this Estimation.';
            }
                                                                                
            String headerEndpoint = BC_BASE_URL + '/EstimateHeaderAPIJRS?$filter=documentNo%20eq%20\'' + docNo + '\'';
            HttpResponse headerRes = makeCallout(headerEndpoint);
                                                                                
            if (headerRes.getStatusCode() != 200) {
                IntegrationLogger.logError('Ctrl_FetchPreEstimateBC', 'fetchPreEstimate', 104, headerRes.getStatusCode(), 'Error fetching Header: ' + headerRes.getBody(), 'EstimateHeaderAPIJRS');
                return 'Error: Failed to fetch Pre-Estimate Header. Check integration logs.';
            }
                                                                                
            Map<String, Object> headerResult = (Map<String, Object>) JSON.deserializeUntyped(headerRes.getBody());
            List<Object> headerList = (List<Object>) headerResult.get('value');
                                                                                
            if (headerList.isEmpty()) {
                return 'Error: No Pre-Estimate Header found in BC for Document No: ' + docNo;
            }
                                                                                
            String lineEndpoint = BC_BASE_URL + '/EstimateLineAPIJRS?$filter=documentNo%20eq%20\'' + docNo + '\'';
            HttpResponse lineRes = makeCallout(lineEndpoint);
                                                                                
            if (lineRes.getStatusCode() != 200) {
                IntegrationLogger.logError('Ctrl_FetchPreEstimateBC', 'fetchPreEstimate', 119, lineRes.getStatusCode(), 'Error fetching Lines: ' + lineRes.getBody(), 'EstimateLineAPIJRS');
                return 'Error: Failed to fetch Pre-Estimate Lines. Check integration logs.';
            }
                                                                                
            Map<String, Object> lineResult = (Map<String, Object>) JSON.deserializeUntyped(lineRes.getBody());
            List<Object> lineList = (List<Object>) lineResult.get('value');
                                                                                
            sp = Database.setSavepoint(); 
                                                                                
            Map<String, Object> headerData = (Map<String, Object>) headerList[0];
            Pre_Estimate_Header_From_BC__c preHeader = processPreHeader(order.Id, docNo, headerData);
                                                                                
            processPreLines(order, preHeader.Id, docNo, lineList);
                                                                                
            return 'Success';
                                                                                
        } catch (Exception e) {
            if (sp != null) Database.rollback(sp);
            IntegrationLogger.logError('Ctrl_FetchPreEstimateBC', 'fetchPreEstimate', e.getLineNumber(), 500, e.getMessage() + '\n' + e.getStackTraceString(), 'EstimateAPIJRS');
            return 'Exception: ' + e.getMessage();
        }
    }
    
    // ==========================================
    // DATA MAPPING
    // ==========================================
    
    private static Pre_Estimate_Header_From_BC__c processPreHeader(Id orderId, String docNo, Map<String, Object> data) {
        List<Pre_Estimate_Header_From_BC__c> existing = [
            SELECT Id FROM Pre_Estimate_Header_From_BC__c 
            WHERE Document_No__c = :docNo AND Estimation__c = :orderId LIMIT 1
        ];
        
        Pre_Estimate_Header_From_BC__c record = existing.isEmpty() ? new Pre_Estimate_Header_From_BC__c() : existing[0];
        
        if (existing.isEmpty()) {
            record.Estimation__c = orderId;
        }
        
        record.Additional_Offers__c = (String) data.get('additionalOffersDiscounts');
        record.Amount_to_Customer__c = getDecimal(data.get('amountToCustomer'));
        record.Astrologer_Code__c = (String) data.get('astrologerCode');
        record.Astrologer_Name__c = (String) data.get('astrologerName');
        record.Bargaining_Amount__c = getDecimal(data.get('bargainingAmount'));
        record.Customer_Code__c = (String) data.get('customerCode');
        record.Customer_Name__c = (String) data.get('customerName');
        record.Customer_Order_No__c = (String) data.get('customerOrderNo');
        record.Customer_Phone_No__c = (String) data.get('customerPhoneNo');
        if (data.get('date') != null) record.Date__c = Date.valueOf((String) data.get('date'));
        record.Document_No__c = docNo; 
        record.Emp_Grade_Code__c = (String) data.get('empGradeCode');
        record.Final_Amount__c = getDecimal(data.get('finalAmountToCustomer'));
        record.Fixed_Adv_Amt__c = getDecimal(data.get('fixedAdvAmt'));
        record.Location__c = (String) data.get('location');
        record.Offers_Discounts__c = (String) data.get('offersDiscounts');
        record.OTP__c = (String) data.get('otp');
        
        if (data.get('otpSentTime') != null && String.isNotBlank((String) data.get('otpSentTime'))) {
            record.OTP_Sent_Time__c = parseTime((String) data.get('otpSentTime'));
        }
        
        record.POS_Receipt_No__c = (String) data.get('posReceiptNo');
        record.Posted__c = getBoolean(data.get('posted'));
        record.Pre_Document_No__c = docNo; 
        record.Salesperson_Code__c = (String) data.get('salespersonCode');
        record.Salesperson_Name__c = (String) data.get('salespersonName');
        record.Scan_Tag_No__c = (String) data.get('tagNo');
        record.Scheme_Entry__c = getBoolean(data.get('schemeEntry'));
        record.Scheme_No__c = (String) data.get('schemeNo');
        record.SMS_Sent__c = getBoolean(data.get('smsSent'));
        record.Total_Charges_Amount__c = getDecimal(data.get('totalChargesAmount'));
        record.Total_Diamond_PCS__c = getDecimal(data.get('totalDiamondPCS'));
        record.Total_Diamond_Value__c = getDecimal(data.get('totalDiamondValue'));
        record.Total_Diamond_Weight__c = getDecimal(data.get('totalDiamondWeight'));
        record.Total_Discount_Amount__c = getDecimal(data.get('totalDiscountAmount'));
        record.Total_Gross_Weight__c = getDecimal(data.get('totalGrossWeight'));
        record.Total_Metal_as_Non_Metal_Value__c = getDecimal(data.get('totalMetalAsNonMetalValue'));
        record.Total_Metal_as_Non_Metal_Weight__c = getDecimal(data.get('totalMetalAsNonMetalWeight'));
        record.Total_Metal_Value__c = getDecimal(data.get('totalMetalValue'));
        record.Total_Net_Weight__c = getDecimal(data.get('totalNetWeight'));
        record.Total_Stone_CT_Value__c = getDecimal(data.get('totalStoneCTValue'));
        record.Total_Stone_CT_Weight__c = getDecimal(data.get('totalStoneCTWeight'));
        record.Total_Stone_GRM_Value__c = getDecimal(data.get('totalStoneGRMValue'));
        record.Total_Stone_GRM_Weight__c = getDecimal(data.get('totalStoneGRMWeight'));
        record.Total_Stone_PCS_Value__c = getDecimal(data.get('totalStonePCSValue'));
        record.Total_Stone_PCS_Weight__c = getDecimal(data.get('totalStonePCSWeight'));
        record.Total_Stone_CPCS__c = getDecimal(data.get('totalStoneCPCS'));
        record.Total_Stone_GPCS__c = getDecimal(data.get('totalStoneGPCS'));
        record.Total_Tag_Amount__c = getDecimal(data.get('totalTagAmount'));
        record.Total_Tax_Amount__c = getDecimal(data.get('totalTaxAmount'));
        record.Total_Taxable_Amount__c = getDecimal(data.get('totalTaxableAmount'));
        record.ZM_Discount__c = getBoolean(data.get('zmDiscountApplied'));
        
        // --- Mapped Picklist Fields ---
        record.Delivery_Type__c = getMappedValue(DELIVERY_TYPE_MAP, data.get('deliveryType'));
        record.Document_Sub_Type__c = getMappedValue(DOCUMENT_SUB_TYPE_MAP, data.get('documentSubType'));
        record.Status__c = getMappedValue(STATUS_MAP, data.get('status'));
        record.Transaction_Type__c = getMappedValue(TRANSACTION_TYPE_MAP, data.get('transactionType'));
        
        upsert record;
        return record;
    }
    
    private static void processPreLines(Customer_Order__c order, Id headerId, String docNo, List<Object> lineList) {
        
        // 1. Group incoming BC Tags to track actual instances
        Map<String, Integer> incomingTagCounts = new Map<String, Integer>();
        for (Object obj : lineList) {
            Map<String, Object> data = (Map<String, Object>) obj;
            String tagNo = (String) data.get('tagNo');
            if (String.isNotBlank(tagNo)) {
                String matchKey = tagNo.trim().toUpperCase();
                incomingTagCounts.put(matchKey, incomingTagCounts.containsKey(matchKey) ? incomingTagCounts.get(matchKey) + 1 : 1);
            }
        }
        
        // 2. Map Parent Order Lines & Update Status Handling Duplicates
        List<Customer_Order_Line_Item__c> orderLinesToUpdate = new List<Customer_Order_Line_Item__c>();
        Map<Id, Wishlist_Item__c> wishlistsToUpdate = new Map<Id, Wishlist_Item__c>();
        Map<String, List<Id>> availableOrderLineIdsByTag = new Map<String, List<Id>>();
        
        // Clone mapping counts to check off SF lines securely
        Map<String, Integer> unassignedIncomingCounts = incomingTagCounts.clone();
        
        for (Customer_Order_Line_Item__c col : order.Customer_Order_Line_Items__r) {
            // Immediately ignore Draft and Wishlist Items so they aren't touched
            if (col.Line_Item_Status_On_Salesforce__c == 'Draft') {
                continue; 
            }
            if (col.Line_Item_Status_On_Salesforce__c == 'Back To Available Wishlist Item') {
                continue; 
            }
            
            if (String.isNotBlank(col.Barcode_Value__c)) {
                String matchKey = col.Barcode_Value__c.trim().toUpperCase();
                
                // If there's an unassigned matching line in the BC payload
                if (unassignedIncomingCounts.containsKey(matchKey) && unassignedIncomingCounts.get(matchKey) > 0) {
                    
                    unassignedIncomingCounts.put(matchKey, unassignedIncomingCounts.get(matchKey) - 1); // Consume one instance
                    
                    if (!availableOrderLineIdsByTag.containsKey(matchKey)) {
                        availableOrderLineIdsByTag.put(matchKey, new List<Id>());
                    }
                    availableOrderLineIdsByTag.get(matchKey).add(col.Id); // Queue it up for mapping
                    
                    if (col.Line_Item_Status_On_Salesforce__c != 'Finalize In Pre') {
                        orderLinesToUpdate.add(new Customer_Order_Line_Item__c(
                            Id = col.Id,
                            Line_Item_Status_On_Salesforce__c = 'Finalize In Pre'
                        ));
                    }
                } else {
                    // Tag is not in payload or all payload instances already consumed -> Mark Removed
                    if (col.Line_Item_Status_On_Salesforce__c != 'Removed') {
                        orderLinesToUpdate.add(new Customer_Order_Line_Item__c(
                            Id = col.Id,
                            Line_Item_Status_On_Salesforce__c = 'Removed'
                        ));
                        
                        if (col.Wishlist_Item__c != null) {
                            wishlistsToUpdate.put(col.Wishlist_Item__c, new Wishlist_Item__c(
                                Id = col.Wishlist_Item__c,
                                Status__c = 'Available'
                            ));
                        }
                    }
                }
            }
        }
        
        // 3. Map Existing Pre-Lines grouping by Duplicates
        List<Pre_Estimate_Line_From_BC__c> existingLines = [
            SELECT Id, Tag_No__c FROM Pre_Estimate_Line_From_BC__c 
            WHERE Pre_Estimate_Header_From_BC__c = :headerId AND Pre_Document_No__c = :docNo
            ORDER BY CreatedDate DESC
        ];
        
        Map<String, List<Pre_Estimate_Line_From_BC__c>> tagToExistingLines = new Map<String, List<Pre_Estimate_Line_From_BC__c>>();
        for (Pre_Estimate_Line_From_BC__c line : existingLines) {
            if (String.isNotBlank(line.Tag_No__c)) {
                String matchKey = line.Tag_No__c.trim().toUpperCase();
                if (!tagToExistingLines.containsKey(matchKey)) {
                    tagToExistingLines.put(matchKey, new List<Pre_Estimate_Line_From_BC__c>());
                }
                tagToExistingLines.get(matchKey).add(line);
            }
        }
        
        List<Pre_Estimate_Line_From_BC__c> linesToUpsert = new List<Pre_Estimate_Line_From_BC__c>();
        
        for (Object obj : lineList) {
            Map<String, Object> data = (Map<String, Object>) obj;
            String tagNo = (String) data.get('tagNo');
            
            if (String.isBlank(tagNo)) continue;
            String matchKey = tagNo.trim().toUpperCase();
            
            Pre_Estimate_Line_From_BC__c record;
            
            // Re-use an existing Pre Line if one exists in the list
            if (tagToExistingLines.containsKey(matchKey) && !tagToExistingLines.get(matchKey).isEmpty()) {
                record = tagToExistingLines.get(matchKey).remove(0);
            } else {
                record = new Pre_Estimate_Line_From_BC__c();
            }
            
            record.Pre_Estimate_Header_From_BC__c = headerId;
            record.Pre_Document_No__c = docNo;
            
            // Consume available Order Line IDs 1-by-1
            if (availableOrderLineIdsByTag.containsKey(matchKey) && !availableOrderLineIdsByTag.get(matchKey).isEmpty()) {
                record.Customer_Order_Line_Item__c = availableOrderLineIdsByTag.get(matchKey).remove(0);
                record.Line_Item_Status_On_Salesforce__c = 'Finalize In Pre';
            } else {
                record.Customer_Order_Line_Item__c = null;
                record.Line_Item_Status_On_Salesforce__c = 'Newly Added';
            }
            
            record.Accessible_Value__c = getDecimal(data.get('accessibleValue'));
            record.Additional_Offer__c = getDecimal(data.get('addlOfferDiscountValue'));
            record.Astrologer_Code__c = (String) data.get('astrologerCode');
            record.Bargaining_Amount__c = getDecimal(data.get('bargainingAmountValue'));
            record.BRAND_ID__c = (String) data.get('brandID');
            record.Cash__c = getDecimal(data.get('cash'));
            record.Customer_No__c = (String) data.get('customerNo');
            record.Customer_Order_No__c = (String) data.get('customerOrderNo');
            if (data.get('date') != null) record.Date__c = Date.valueOf((String) data.get('date'));
            record.DESIGN_CODE__c = (String) data.get('designCODE');
            record.DIAMOND_PCS__c = getDecimal(data.get('diamondPCS'));
            record.Diamond_Rate__c = getDecimal(data.get('diamondRate'));
            record.Diamond_Value__c = getDecimal(data.get('diamondValue'));
            record.DIAMOND_WEIGHT__c = getDecimal(data.get('diamondWEIGHT'));
            record.Discount__c = getDecimal(data.get('discount'));
            record.DiscountPercentage__c = getDecimal(data.get('discountPer'));
            record.E_Certificate_View__c = (String) data.get('eCertificateView');
            record.Final_Amount__c = getDecimal(data.get('finalAmount'));
            record.Flexi_Applicable__c = getBoolean(data.get('isFlexiApplicable'));
            record.Flexi_Offer__c = getDecimal(data.get('flexiOfferAmount'));
            record.Free_Item__c = getBoolean(data.get('freeItem'));
            record.Gross_Weight__c = getDecimal(data.get('grossWeight'));
            record.Inclusive_MRP__c = getBoolean(data.get('inclusiveMRP'));
            record.Item_Description__c = (String) data.get('itemDescription');
            record.Item_No__c = (String) data.get('itemNo');
            record.Key_in_Price__c = getBoolean(data.get('keyInPrice'));
            record.Line_No__c = getDecimal(data.get('lineNo'));
            record.Location__c = (String) data.get('location');
            record.Metal_as_Non_Metal_Rate__c = getDecimal(data.get('metalAsNonMetalRate'));
            record.Metal_as_Non_Metal_Value__c = getDecimal(data.get('metalAsNonMetalValue'));
            record.Metal_as_Non_Metal_Weight__c = getDecimal(data.get('metalAsNonMetalWeight'));
            record.Metal_Value__c = getDecimal(data.get('metalValue'));
            record.MRP_Value__c = getDecimal(data.get('mrpValue'));
            record.Net_Amount__c = getDecimal(data.get('netAmount'));
            record.Net_Weight__c = getDecimal(data.get('netWeight'));
            record.No_of_PCS__c = getDecimal(data.get('noOfPCS'));
            record.Non_Cash__c = getDecimal(data.get('nonCash'));
            record.Offer_Against_Tag_No__c = (String) data.get('offerAgainstTagNo');
            record.Offer_Discount_Value__c = getDecimal(data.get('offerDiscountValue'));
            record.Offer_Free_Item__c = getBoolean(data.get('offerDiscountFreeItem'));
            record.ORNAMENT_CATEGORY__c = (String) data.get('ornamentCATEGORYCODE');
            record.ORNAMENT_SUB_CATEGORY__c = (String) data.get('ornamentSUBCATEGORY');
            record.Outward_Amount__c = getDecimal(data.get('outwardAmount'));
            record.Outward_Cost__c = getDecimal(data.get('outwardCost'));
            record.Outward_Coupon__c = getDecimal(data.get('outwardCoupon')); 
            record.Outward_Discount__c = getDecimal(data.get('outwardDiscount'));
            record.POS_Certificate__c = (String) data.get('posCertificatePrint');
            record.Posted__c = getBoolean(data.get('posted'));
            record.Purity__c = getDecimal(data.get('purity'));
            record.Salesperson_Code__c = (String) data.get('salespersonCode');
            record.Scheme_Discount__c = getDecimal(data.get('schemeDiscountValue'));
            record.SECTION_ID__c = (String) data.get('sectionID');
            record.SMC_Rate__c = getDecimal(data.get('smcRate'));
            record.SMC_Value__c = getDecimal(data.get('smcValue'));
            record.Stone_CT_Rate__c = getDecimal(data.get('stoneCTRate'));
            record.Stone_CT_Value__c = getDecimal(data.get('stoneCTValue'));
            record.Stone_CT_Weight__c = getDecimal(data.get('stoneCTWeight'));
            record.Stone_GRM_Rate__c = getDecimal(data.get('stoneGRMRate'));
            record.Stone_GRM_Value__c = getDecimal(data.get('stoneGRMValue'));
            record.Stone_GRM_Weight__c = getDecimal(data.get('stoneGRMWeight'));
            record.Stone_PCS_Rate__c = getDecimal(data.get('stonePCSRate'));
            record.Stone_PCS_Value__c = getDecimal(data.get('stonePCSValue'));
            record.Stone_PCS_Weight__c = getDecimal(data.get('stonePCSWeight'));
            record.STONE_AMOUNT__c = getDecimal(data.get('stoneAMOUNT'));
            record.STONE_CPCS__c = getDecimal(data.get('stoneCPCS'));
            record.STONE_GPCS__c = getDecimal(data.get('stoneGPCS'));
            record.STONE_WEIGHT__c = getDecimal(data.get('stoneWEIGHT'));
            record.STONE_WEIGHT_CT__c = getDecimal(data.get('stoneWEIGHTCT'));
            record.Tag_Amount__c = getDecimal(data.get('tagAmount'));
            record.Tag_No__c = tagNo; 
            record.Tax_Amount__c = getDecimal(data.get('taxAmount'));
            record.Taxable_Amount__c = getDecimal(data.get('taxableAmount'));
            record.URD_Discount__c = getDecimal(data.get('urdDiscountValue'));
            record.Variant_ID__c = (String) data.get('variantID');
            record.Weight_Range_Code__c = (String) data.get('weightRangeCode');
            
            record.Document_Sub_Type__c = getMappedValue(DOCUMENT_SUB_TYPE_MAP, data.get('documentSubType'));
            record.Incentive_Commission__c = getMappedValue(INCENTIVE_COMMISSION_MAP, data.get('incentiveCommision'));
            record.Making_Type__c = getMappedValue(MAKING_TYPE_MAP, data.get('makingType'));
            record.Metal_Type__c = getMappedValue(METAL_TYPE_MAP, data.get('metalType'));
            record.Item_Type_Group__c = getMappedValue(ITEM_TYPE_GROUP_MAP, data.get('itemTypeGroup'));
            
            linesToUpsert.add(record);
        }
        
        if (!orderLinesToUpdate.isEmpty()) update orderLinesToUpdate;
        if (!linesToUpsert.isEmpty()) upsert linesToUpsert;
        
        if (!wishlistsToUpdate.isEmpty()) {
            update wishlistsToUpdate.values();
        }
    }   
    
    // ==========================================
    // UTILITIES
    // ==========================================
    
    private static String getMappedValue(Map<String, String> dict, Object val) {
        if (val == null) return null;
        String strVal = String.valueOf(val);
        // Return mapped value if it exists, otherwise return original string
        return dict.containsKey(strVal) ? dict.get(strVal) : strVal;
    }
    
    private static HttpResponse makeCallout(String endpoint) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(120000);
        return http.send(req);
    }
    
    private static Decimal getDecimal(Object val) {
        if (val == null) return 0.00;
        return Decimal.valueOf(String.valueOf(val));
    }
    
    private static Boolean getBoolean(Object val) {
        if (val == null) return false;
        return Boolean.valueOf(String.valueOf(val));
    }
    
    private static Time parseTime(String timeStr) {
        try {
            List<String> parts = timeStr.split(':');
            return Time.newInstance(
                Integer.valueOf(parts[0]),
                Integer.valueOf(parts[1]),
                Integer.valueOf(parts[2]),
                0
            );
        } catch (Exception e) {
            return null; 
        }
    }
}