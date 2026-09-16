public with sharing class Ctrl_FetchPostEstimateBC {
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
    public static String fetchPostEstimate(Id orderId) {
        Savepoint sp;
        try {
            // Newest first sorting prevents old removed lines from stealing the payload
            List<Customer_Order__c> orders = [
                SELECT Id, Pre_Document_No__c, Post_Document_No__c,
                (SELECT Id, Barcode_Value__c, Line_Item_Status_On_Salesforce__c 
                 FROM Customer_Order_Line_Items__r 
                 WHERE Barcode_Value__c != null 
                 ORDER BY CreatedDate DESC) 
                FROM Customer_Order__c 
                WHERE Id = :orderId LIMIT 1
            ];
            
            if (orders.isEmpty()) return 'Error: Could not find the Estimation record. Invalid Record ID.';
            
            Customer_Order__c order = orders[0];
            String preDocNo = order.Pre_Document_No__c;
            
            if (String.isBlank(preDocNo)) return 'Error: Pre Document No is required to fetch Posted Estimates.';
            
            List<Pre_Estimate_Header_From_BC__c> preHeaders = [
                SELECT Id FROM Pre_Estimate_Header_From_BC__c WHERE Estimation__c = :orderId LIMIT 1
            ];
            Id preHeaderId = preHeaders.isEmpty() ? null : preHeaders[0].Id;
            
            // ==========================================
            // PHASE 1: HTTP CALLOUTS
            // ==========================================
            String headerEndpoint = BC_BASE_URL + '/PostedEstimateHeaderAPIJRS?$filter=preDocumentNo%20eq%20\'' + preDocNo + '\'';
            HttpResponse headerRes = makeCallout(headerEndpoint);
            
            if (headerRes.getStatusCode() != 200) {
                IntegrationLogger.logError('Ctrl_FetchPostEstimateBC', 'fetchPostEstimate', 119, headerRes.getStatusCode(), 'Error fetching Post Header: ' + headerRes.getBody(), 'PostedEstimateHeaderAPIJRS');
                return 'Error: Failed to fetch Posted Header. Check integration logs.';
            }
            
            Map<String, Object> headerResult = (Map<String, Object>) JSON.deserializeUntyped(headerRes.getBody());
            List<Object> headerList = (List<Object>) headerResult.get('value');
            
            if (headerList.isEmpty()) {
                return 'Error: No Posted-Estimate Header found for Pre Document No: ' + preDocNo;
            }
            
            String lineEndpoint = BC_BASE_URL + '/PostedEstimateLineAPIJRS?$filter=preDocumentNo%20eq%20\'' + preDocNo + '\'';
            HttpResponse lineRes = makeCallout(lineEndpoint);
            
            if (lineRes.getStatusCode() != 200) {
                IntegrationLogger.logError('Ctrl_FetchPostEstimateBC', 'fetchPostEstimate', 134, lineRes.getStatusCode(), 'Error fetching Post Lines: ' + lineRes.getBody(), 'PostedEstimateLineAPIJRS');
                return 'Error: Failed to fetch Posted Lines. Check integration logs.';
            }
            
            Map<String, Object> lineResult = (Map<String, Object>) JSON.deserializeUntyped(lineRes.getBody());
            List<Object> lineList = (List<Object>) lineResult.get('value');
            
            // ==========================================
            // PHASE 2: DATABASE OPERATIONS (DML)
            // ==========================================
            sp = Database.setSavepoint();
            
            Map<String, Object> headerData = (Map<String, Object>) headerList[0];
            Post_Estimate_Header_From_BC__c postHeader = processPostHeader(order, preHeaderId, headerData);
            
            if (!lineList.isEmpty()) {
                processPostLines(order, postHeader.Id, preDocNo, lineList);
            }
            
            return 'Success';
            
        } catch (Exception e) {
            if (sp != null) Database.rollback(sp);
            IntegrationLogger.logError('Ctrl_FetchPostEstimateBC', 'fetchPostEstimate', e.getLineNumber(), 500, e.getMessage() + '\n' + e.getStackTraceString(), 'PostedEstimateAPIJRS');
            return 'Exception: ' + e.getMessage();
        }
    }
    
    // ==========================================
    // DATA MAPPING
    // ==========================================
    
    private static Post_Estimate_Header_From_BC__c processPostHeader(Customer_Order__c order, Id preHeaderId, Map<String, Object> data) {
        String preDocNo = (String) data.get('preDocumentNo');
        String postDocNo = (String) data.get('documentNo');
        
        if (order.Post_Document_No__c != postDocNo) {
            order.Post_Document_No__c = postDocNo;
            update order; 
        }
        
        List<Post_Estimate_Header_From_BC__c> existing = [
            SELECT Id FROM Post_Estimate_Header_From_BC__c WHERE Pre_Document_No__c = :preDocNo LIMIT 1
        ];
        
        Post_Estimate_Header_From_BC__c record = existing.isEmpty() ? new Post_Estimate_Header_From_BC__c() : existing[0];
        
        // --- Relationships ---
        record.Estimation__c = order.Id;
        record.Pre_Estimate_Header_From_BC__c = preHeaderId;
        
        // --- Data Mapping ---
        record.Advance_Entry__c = getBoolean(data.get('advanceEntry'));
        record.Amount_To_Customer__c = getDecimal(data.get('amountToCustomer'));
        record.Astrologer_Code__c = (String) data.get('astrologerCode');
        record.Astrologer_Name__c = (String) data.get('astrologerName');
        record.Bargaining_Amount__c = getDecimal(data.get('bargainingAmount'));
        record.Customer_Code__c = (String) data.get('customerCode');
        record.Customer_Name__c = (String) data.get('customerName');
        record.Customer_Order_No__c = (String) data.get('customerOrderNo');
        record.Customer_Phone_No__c = (String) data.get('customerPhoneNo');
        if (data.get('date') != null) record.Date__c = String.valueOf(data.get('date'));
        record.Emp_Grade_Code__c = (String) data.get('empGradeCode');
        record.Final_Amount_To_Customer__c = getDecimal(data.get('finalAmountToCustomer'));
        record.Fixed_Adv_Amt__c = getDecimal(data.get('fixedAdvAmt'));
        record.Location__c = (String) data.get('location');
        record.Location_Name__c = (String) data.get('locationName');
        record.Offers_Discounts__c = (String) data.get('offersDiscounts');
        record.OTP__c = (String) data.get('otp');
        if (data.get('otpSentTime') != null) record.OTP_Sent_Time__c = String.valueOf(data.get('otpSentTime'));
        record.POS_Receipt_No__c = (String) data.get('posReceiptNo');
        record.Post_No__c = postDocNo;
        record.Posted__c = getBoolean(data.get('posted'));
        record.Posted_GL_Document_No__c = (String) data.get('postedGLDocumentNo');
        record.Posted_Sales_Invoice_No__c = (String) data.get('postedSalesInvoiceNo');
        record.Pre_Document_No__c = preDocNo;
        record.Sales_Force_Order_No__c = (String) data.get('salesForceOrderNo');
        record.Sales_Invoice_No__c = (String) data.get('salesInvoiceNo');
        record.Salesperson_Code__c = (String) data.get('salespersonCode');
        record.Salesperson_Name__c = (String) data.get('salespersonName');
        record.Scan_Tag_No__c = (String) data.get('scanTagNo');
        record.Scheme_Entry__c = getBoolean(data.get('schemeEntry'));
        record.Scheme_No__c = (String) data.get('schemeNo');
        record.SMS_Sent__c = getBoolean(data.get('smsSent'));
        record.System_Created_At__c = (String) data.get('systemCreatedAt');
        record.System_Created_By__c = (String) data.get('systemCreatedBy');
        record.System_ID__c = (String) data.get('systemId');
        record.System_Modified_At__c = (String) data.get('systemModifiedAt');
        record.System_Modified_By__c = (String) data.get('systemModifiedBy');
        record.Total_Charges_Amount__c = getDecimal(data.get('totalChargesAmount'));
        record.Total_Diamond_PCS__c = getDecimal(data.get('totalDiamondPCS'));
        record.Total_Diamond_Value__c = getDecimal(data.get('totalDiamondValue'));
        record.Total_Diamond_Weight__c = getDecimal(data.get('totalDiamondWeight'));
        record.Total_Discount_Amount__c = getDecimal(data.get('totalDiscountAmount'));
        record.Total_Gross_Weight__c = getDecimal(data.get('totalGrossWeight'));
        record.Total_Metal_As_Non_Metal_Value__c = getDecimal(data.get('totalMetalAsNonMetalValue'));
        record.Total_Metal_As_Non_Metal_Weight__c = getDecimal(data.get('totalMetalAsNonMetalWeight'));
        record.Total_Metal_Value__c = getDecimal(data.get('totalMetalValue'));
        record.Total_Net_Weight__c = getDecimal(data.get('totalNetWeight'));
        record.Total_Stone_CPCS__c = getDecimal(data.get('totalStoneCPCS'));
        record.Total_Stone_CT_Value__c = getDecimal(data.get('totalStoneCTValue'));
        record.Total_Stone_CT_Weight__c = getDecimal(data.get('totalStoneCTWeight'));
        record.Total_Stone_GPCS__c = getDecimal(data.get('totalStoneGPCS'));
        record.Total_Stone_GRM_Value__c = getDecimal(data.get('totalStoneGRMValue'));
        record.Total_Stone_GRM_Weight__c = getDecimal(data.get('totalStoneGRMWeight'));
        record.Total_Stone_PCS_Value__c = getDecimal(data.get('totalStonePCSValue'));
        record.Total_Stone_PCS_Weight__c = getDecimal(data.get('totalStonePCSWeight'));
        record.Total_Tag_Amount__c = getDecimal(data.get('totalTagAmount'));
        record.Total_Tax_Amount__c = getDecimal(data.get('totalTaxAmount'));
        record.Total_Taxable_Amount__c = getDecimal(data.get('totalTaxableAmount'));
        record.ZM_Discount_Applied__c = getBoolean(data.get('zmDiscountApplied'));
        
        // --- Picklists ---
        record.Delivery_Type__c = getMappedValue(DELIVERY_TYPE_MAP, data.get('deliveryType'));
        record.Document_Sub_Type__c = getMappedValue(DOCUMENT_SUB_TYPE_MAP, data.get('documentSubType'));
        record.Status__c = getMappedValue(STATUS_MAP, data.get('status'));
        record.Transaction_Type__c = getMappedValue(TRANSACTION_TYPE_MAP, data.get('transactionType'));
        
        upsert record; 
        return record;
    }
    
    private static void processPostLines(Customer_Order__c order, Id postHeaderId, String preDocNo, List<Object> lineList) {
        
        // 1. Group incoming BC Tags to handle duplicates accurately
        Map<String, Integer> incomingTagCounts = new Map<String, Integer>();
        for (Object obj : lineList) {
            Map<String, Object> data = (Map<String, Object>) obj;
            String tagNo = (String) data.get('tagNo');
            if (String.isNotBlank(tagNo)) {
                String matchKey = tagNo.trim().toUpperCase();
                incomingTagCounts.put(matchKey, incomingTagCounts.containsKey(matchKey) ? incomingTagCounts.get(matchKey) + 1 : 1);
            }
        }
        
        // 2. Map Parent Order Lines & Update Status safely
        List<Customer_Order_Line_Item__c> orderLinesToUpdate = new List<Customer_Order_Line_Item__c>();
        Map<String, List<Id>> availableOrderLineIdsByTag = new Map<String, List<Id>>();
        
        // Clone the counts to independently track mappings for this loop
        Map<String, Integer> unassignedIncomingOrderCounts = incomingTagCounts.clone();
        
        for (Customer_Order_Line_Item__c col : order.Customer_Order_Line_Items__r) {
            if (col.Line_Item_Status_On_Salesforce__c == 'Draft') {
                continue; 
            }
            if (col.Line_Item_Status_On_Salesforce__c == 'Back To Available Wishlist Item') {
                continue; 
            }
            
            if (String.isNotBlank(col.Barcode_Value__c)) {
                String matchKey = col.Barcode_Value__c.trim().toUpperCase();
                
                // If there's an unassigned matching line in the BC payload
                if (unassignedIncomingOrderCounts.containsKey(matchKey) && unassignedIncomingOrderCounts.get(matchKey) > 0) {
                    
                    unassignedIncomingOrderCounts.put(matchKey, unassignedIncomingOrderCounts.get(matchKey) - 1); // Consume one
                    
                    if (!availableOrderLineIdsByTag.containsKey(matchKey)) {
                        availableOrderLineIdsByTag.put(matchKey, new List<Id>());
                    }
                    availableOrderLineIdsByTag.get(matchKey).add(col.Id); // Queue it up for creation phase
                    
                    if (col.Line_Item_Status_On_Salesforce__c != 'Finalize In Post') {
                        orderLinesToUpdate.add(new Customer_Order_Line_Item__c(
                            Id = col.Id,
                            Line_Item_Status_On_Salesforce__c = 'Finalize In Post'
                        ));
                    }
                } else {
                    // Exhausted payload counts or tag not found in payload -> Mark as Removed
                    if (col.Line_Item_Status_On_Salesforce__c != 'Removed') {
                        orderLinesToUpdate.add(new Customer_Order_Line_Item__c(
                            Id = col.Id,
                            Line_Item_Status_On_Salesforce__c = 'Removed'
                        ));
                    }
                }
            }
        }
        
        // 3. Map Pre-Lines & Update Status 
        List<Pre_Estimate_Line_From_BC__c> preLines = [
            SELECT Id, Tag_No__c, Line_Item_Status_On_Salesforce__c 
            FROM Pre_Estimate_Line_From_BC__c 
            WHERE Pre_Estimate_Header_From_BC__r.Estimation__c = :order.Id
            ORDER BY CreatedDate DESC
        ];
        
        List<Pre_Estimate_Line_From_BC__c> preLinesToUpdate = new List<Pre_Estimate_Line_From_BC__c>();
        Map<String, List<Id>> availablePreLineIdsByTag = new Map<String, List<Id>>();
        
        // Clone the original counts again to handle Pre lines mapping independently
        Map<String, Integer> unassignedIncomingPreCounts = incomingTagCounts.clone();
        
        for (Pre_Estimate_Line_From_BC__c pLine : preLines) {
            if (String.isNotBlank(pLine.Tag_No__c)) {
                String matchKey = pLine.Tag_No__c.trim().toUpperCase();
                
                if (unassignedIncomingPreCounts.containsKey(matchKey) && unassignedIncomingPreCounts.get(matchKey) > 0) {
                    
                    unassignedIncomingPreCounts.put(matchKey, unassignedIncomingPreCounts.get(matchKey) - 1);
                    
                    if (!availablePreLineIdsByTag.containsKey(matchKey)) {
                        availablePreLineIdsByTag.put(matchKey, new List<Id>());
                    }
                    availablePreLineIdsByTag.get(matchKey).add(pLine.Id); // Queue it up for creation phase
                    
                    if (pLine.Line_Item_Status_On_Salesforce__c != 'Finalize In Post') {
                        preLinesToUpdate.add(new Pre_Estimate_Line_From_BC__c(
                            Id = pLine.Id,
                            Line_Item_Status_On_Salesforce__c = 'Finalize In Post'
                        ));
                    }
                } else {
                    if (pLine.Line_Item_Status_On_Salesforce__c != 'Removed') {
                        preLinesToUpdate.add(new Pre_Estimate_Line_From_BC__c(
                            Id = pLine.Id,
                            Line_Item_Status_On_Salesforce__c = 'Removed'
                        ));
                    }
                }
            }
        }
        
        // 4. Map Existing Post Lines (Handling duplicates)
        List<Post_Estimate_Line_From_BC__c> existingLines = [
            SELECT Id, Tag_No__c FROM Post_Estimate_Line_From_BC__c 
            WHERE Post_Estimate_Header_From_BC__c = :postHeaderId
            ORDER BY CreatedDate DESC
        ];
        
        Map<String, List<Post_Estimate_Line_From_BC__c>> tagToExistingLines = new Map<String, List<Post_Estimate_Line_From_BC__c>>();
        for (Post_Estimate_Line_From_BC__c line : existingLines) {
            if (String.isNotBlank(line.Tag_No__c)) {
                String matchKey = line.Tag_No__c.trim().toUpperCase();
                if (!tagToExistingLines.containsKey(matchKey)) {
                    tagToExistingLines.put(matchKey, new List<Post_Estimate_Line_From_BC__c>());
                }
                tagToExistingLines.get(matchKey).add(line);
            }
        }
        
        List<Post_Estimate_Line_From_BC__c> linesToUpsert = new List<Post_Estimate_Line_From_BC__c>();
        
        for (Object obj : lineList) {
            Map<String, Object> data = (Map<String, Object>) obj;
            String tagNo = (String) data.get('tagNo');
            
            if (String.isBlank(tagNo)) continue;
            String matchKey = tagNo.trim().toUpperCase();
            
            Post_Estimate_Line_From_BC__c record;
            
            // Re-use an existing Post Line item if one exists in the list
            if (tagToExistingLines.containsKey(matchKey) && !tagToExistingLines.get(matchKey).isEmpty()) {
                record = tagToExistingLines.get(matchKey).remove(0);
            } else {
                record = new Post_Estimate_Line_From_BC__c();
            }
            
            record.Post_Estimate_Header_From_BC__c = postHeaderId;
            record.Line_Item_Status_On_Salesforce__c = 'Finalize In Post'; // Automatically set for incoming Post lines
            
            // Consume available Order Line IDs 1-by-1
            if (availableOrderLineIdsByTag.containsKey(matchKey) && !availableOrderLineIdsByTag.get(matchKey).isEmpty()) {
                record.Estimation_Line_Item__c = availableOrderLineIdsByTag.get(matchKey).remove(0);
            } else {
                record.Estimation_Line_Item__c = null;
            }
            
            // Consume available Pre Line IDs 1-by-1
            if (availablePreLineIdsByTag.containsKey(matchKey) && !availablePreLineIdsByTag.get(matchKey).isEmpty()) {
                record.Pre_Estimate_Line_From_BC__c = availablePreLineIdsByTag.get(matchKey).remove(0);
            } else {
                record.Pre_Estimate_Line_From_BC__c = null;
            }
            
            // --- Data Mapping ---
            record.Pre_Document_No__c = preDocNo;
            record.Tag_No__c = tagNo; 
            record.Item_No__c = (String) data.get('itemNo');
            record.Item_Description__c = (String) data.get('itemDescription');
            
            record.Accessible_Value__c = getDecimal(data.get('accessibleValue'));
            record.Addl_Offer_Discount_Value__c = getDecimal(data.get('addlOfferDiscountValue'));
            record.Astrologer_Code__c = (String) data.get('astrologerCode');
            record.Bargaining_Amount_Value__c = getDecimal(data.get('bargainingAmountValue'));
            record.Brand_ID__c = (String) data.get('brandID');
            record.Cash__c = getDecimal(data.get('cash'));
            record.Customer_No__c = (String) data.get('customerNo');
            record.Customer_Order_No__c = (String) data.get('customerOrderNo');
            if (data.get('date') != null) record.Date__c = String.valueOf(data.get('date'));
            record.Design_Code__c = (String) data.get('designCODE');
            record.Diamond_PCS__c = getDecimal(data.get('diamondPCS'));
            record.Diamond_Rate__c = getDecimal(data.get('diamondRate'));
            record.Diamond_Value__c = getDecimal(data.get('diamondValue'));
            record.Diamond_Weight__c = getDecimal(data.get('diamondWEIGHT'));
            record.Discount__c = getDecimal(data.get('discount'));
            record.Discount_Per__c = getDecimal(data.get('discount_Per')); 
            record.E_Certificate_View__c = (String) data.get('eCertificateView');
            record.Final_Amount__c = getDecimal(data.get('finalAmount'));
            record.Flexi_Offer_Amount__c = getDecimal(data.get('flexiOfferAmount'));
            record.Free_Item__c = getBoolean(data.get('freeItem'));
            record.Gross_Weight__c = getDecimal(data.get('grossWeight'));
            record.Inclusive_MRP__c = getBoolean(data.get('inclusiveMRP'));
            record.Is_Flexi_Applicable__c = getBoolean(data.get('isFlexiApplicable'));
            record.Key_In_Price__c = getBoolean(data.get('keyInPrice'));
            record.Line_No__c = getDecimal(data.get('lineNo'));
            record.Location__c = (String) data.get('location');
            record.Metal_As_Non_Metal_Rate__c = getDecimal(data.get('metalAsNonMetalRate'));
            record.Metal_As_Non_Metal_Value__c = getDecimal(data.get('metalAsNonMetalValue'));
            record.Metal_As_Non_Metal_Weight__c = getDecimal(data.get('metalAsNonMetalWeight'));
            record.Metal_Value__c = getDecimal(data.get('metalValue'));
            record.MRP_Value__c = getDecimal(data.get('mrpValue'));
            record.Net_Amount__c = getDecimal(data.get('netAmount'));
            record.Net_Weight__c = getDecimal(data.get('netWeight'));
            record.No_Of_PCS__c = getDecimal(data.get('noOfPCS'));
            record.Non_Cash__c = getDecimal(data.get('nonCash'));
            record.Offer_Against_Tag_No__c = (String) data.get('offerAgainstTagNo');
            record.Offer_Discount_Free_Item__c = getBoolean(data.get('offerDiscountFreeItem'));
            record.Offer_Discount_Value__c = getDecimal(data.get('offerDiscountValue'));
            record.Old_Tag_Amount__c = getDecimal(data.get('oldTagAmount'));
            record.Ornament_Category_Code__c = (String) data.get('ornamentCATEGORYCODE');
            record.Ornament_Subcategory__c = (String) data.get('ornamentSUBCATEGORY');
            record.Outward_Amount__c = getDecimal(data.get('outwardAmount'));
            record.Outward_Cost__c = getDecimal(data.get('outwardCost'));
            if(data.get('outwardCoupon') != null) record.Outward_Coupon__c = String.valueOf(data.get('outwardCoupon')); 
            record.Outward_Discount__c = getDecimal(data.get('outwardDiscount'));
            record.POS_Certificate_Print__c = (String) data.get('posCertificatePrint');
            record.Posted__c = getBoolean(data.get('posted'));
            if(data.get('purity') != null) record.Purity__c = String.valueOf(data.get('purity')); 
            record.Sales_Return__c = getBoolean(data.get('salesReturn'));
            record.Salesforce_Order_No__c = (String) data.get('salesForceOrderNo');
            record.Salesperson_Code__c = (String) data.get('salespersonCode');
            record.Scheme_Discount_Value__c = getDecimal(data.get('schemeDiscountValue'));
            record.Section_ID__c = (String) data.get('sectionID');
            record.SMC_Rate__c = getDecimal(data.get('smcRate'));
            record.SMC_Value__c = getDecimal(data.get('smcValue'));
            record.Stone_Amount__c = getDecimal(data.get('stoneAMOUNT'));
            record.Stone_CPCS__c = getDecimal(data.get('stoneCPCS'));
            record.Stone_CT_Rate__c = getDecimal(data.get('stoneCTRate'));
            record.Stone_CT_Value__c = getDecimal(data.get('stoneCTValue'));
            record.Stone_CT_Weight__c = getDecimal(data.get('stoneCTWeight'));
            record.Stone_GPCS__c = getDecimal(data.get('stoneGPCS'));
            record.Stone_GRM_Rate__c = getDecimal(data.get('stoneGRMRate'));
            record.Stone_GRM_Value__c = getDecimal(data.get('stoneGRMValue'));
            record.Stone_GRM_Weight__c = getDecimal(data.get('stoneGRMWeight'));
            record.Stone_PCS_Rate__c = getDecimal(data.get('stonePCSRate'));
            record.Stone_PCS_Value__c = getDecimal(data.get('stonePCSValue'));
            record.Stone_PCS_Weight__c = getDecimal(data.get('stonePCSWeight'));
            record.Stone_Weight__c = getDecimal(data.get('stoneWEIGHT'));
            record.Stone_Weight_CT__c = getDecimal(data.get('stoneWEIGHTCT'));
            
            record.System_Created_At__c = (String) data.get('systemCreatedAt');
            record.System_Created_By__c = (String) data.get('systemCreatedBy');
            record.System_ID__c = (String) data.get('systemId');
            record.System_Modified_At__c = (String) data.get('systemModifiedAt');
            record.System_Modified_By__c = (String) data.get('systemModifiedBy');
            
            record.Tag_Amount__c = getDecimal(data.get('tagAmount'));
            record.Tax_Amount__c = getDecimal(data.get('taxAmount'));
            record.Taxable_Amount__c = getDecimal(data.get('taxableAmount'));
            record.URD_Discount_Value__c = getDecimal(data.get('urdDiscountValue'));
            record.Variant_ID__c = (String) data.get('variantID');
            record.Weight_Range_Code__c = (String) data.get('weightRangeCode');
            
            // --- Mapped Picklists ---
            record.Document_Sub_Type__c = getMappedValue(DOCUMENT_SUB_TYPE_MAP, data.get('documentSubType'));
            record.Incentive_Commision__c = getMappedValue(INCENTIVE_COMMISSION_MAP, data.get('incentiveCommision'));
            record.Making_Type__c = getMappedValue(MAKING_TYPE_MAP, data.get('makingType'));
            record.Metal_Type__c = getMappedValue(METAL_TYPE_MAP, data.get('metalType'));
            record.Item_Type_Group__c = getMappedValue(ITEM_TYPE_GROUP_MAP, data.get('itemTypeGroup'));
            
            linesToUpsert.add(record);
        }
        
        // 5. Commit all DML securely
        if (!orderLinesToUpdate.isEmpty()) update orderLinesToUpdate;
        if (!preLinesToUpdate.isEmpty()) update preLinesToUpdate;
        if (!linesToUpsert.isEmpty()) upsert linesToUpsert;
    }
    
    // ==========================================
    // UTILITIES
    // ==========================================
    
    private static String getMappedValue(Map<String, String> dict, Object val) {
        if (val == null) return null;
        String strVal = String.valueOf(val);
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
}