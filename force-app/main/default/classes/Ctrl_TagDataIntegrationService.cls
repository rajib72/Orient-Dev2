public with sharing class Ctrl_TagDataIntegrationService {
    
    private static final String CLASS_NAME = 'Ctrl_TagDataIntegrationService';
    
    // Main Wrapper to hold the combined response from all APIs
    public class TagResponse {
        @AuraEnabled public HeaderData header;
        @AuraEnabled public List<PriceLineData> priceLines;
        @AuraEnabled public List<DetailLineData> detailLines;
        @AuraEnabled public List<SCMLineData> scmLines;
    }
    
    // Wrapper for First API (ACXTagHeadersAPIJRS)
    public class HeaderData {
        @AuraEnabled public String barCodeNo;
        @AuraEnabled public Decimal grossWt;
        @AuraEnabled public Decimal netWt;
        @AuraEnabled public String goldPurity;
        @AuraEnabled public String goldColour;
        @AuraEnabled public String productName;
        @AuraEnabled public String size;
        @AuraEnabled public String designCode;
        @AuraEnabled public Decimal diamondWt;
        @AuraEnabled public Decimal stoneWt;
        @AuraEnabled public String certificationBy;
        @AuraEnabled public String subCategoryCode;
    }
    
    // Wrapper for Second API (TagPriceLinesJRS)
    public class PriceLineData {
        @AuraEnabled public String barCodeNo;
        @AuraEnabled public Decimal productPrice;
        @AuraEnabled public Decimal gstPercentage;
    }
    
    // Wrapper for Third API (TagPriceDetailLinesJRS)
    public class DetailLineData {
        @AuraEnabled public String barCodeNo;
        @AuraEnabled public String bomItem;
        @AuraEnabled public Decimal purity;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public String uom;
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Decimal amount;
    }
    
    // Wrapper for Fourth API (TagPriceSCMAPIJRS)
    public class SCMLineData {
        @AuraEnabled public String barCodeNo;
        @AuraEnabled public String bomItem;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String makingType;
    }
    
    // ======================================================================================
    // FLOW INTEGRATION METHODS
    // ======================================================================================
    
    public class FlowInput {
        @InvocableVariable(label='Tag No (Barcode)' required=true)
        public String tagNo;
        
        @InvocableVariable(label='Wishlist Item ID' description='Links Header to a Wishlist Item' required=true)
        public Id wishlistItemId;
    }
    
    /**
* Invocable method exposed to Salesforce Flows.
* Requires (callout=true) so it can make HTTP requests mid-flow.
*/
    @InvocableMethod(label='Fetch and Insert Tag API Data' description='Calls BC APIs and creates/updates Header, Price, Detail, and SCM records.' callout=true)
    public static void processTagDataFromFlow(List<FlowInput> inputs) {
        for (FlowInput input : inputs) {
            insertScannedTagRecords(input.tagNo, input.wishlistItemId);
        }
    }
    
    /**
* Dedicated DML Method to fetch API data and upsert the object hierarchy
*/
    /**
* Dedicated DML Method to fetch API data and upsert the object hierarchy
*/
    public static void insertScannedTagRecords(String tagNo, Id wishlistItemId) {
        try {
            // 1. Fetch API Data
            TagResponse tagData = getTagData(tagNo, wishlistItemId);
            
            // If no header data came back, do not proceed with insertions
            if (tagData == null || tagData.header == null || String.isBlank(tagData.header.barCodeNo)) {
                System.debug('Abort Upsert: No Header Data returned for Tag No: ' + tagNo);
                return; 
            }
            
            if (wishlistItemId == null) {
                System.debug('Abort Upsert: No Wishlist Item Id is passed.');
                return; 
            }
            
            String currentBarCode = tagData.header.barCodeNo;
            
            // ==========================================
            // 2. UPSERT HEADER: ACX_Tag_Header__c
            // ==========================================
            List<ACX_Tag_Header__c> existingHeaders = [
                SELECT Id, Bar_Code_No__c 
                FROM ACX_Tag_Header__c 
                WHERE Bar_Code_No__c = :currentBarCode 
                AND Wishlist_Item__c = :wishlistItemId
                LIMIT 1
            ];
            
            ACX_Tag_Header__c headerRec = existingHeaders.isEmpty() ? new ACX_Tag_Header__c() : existingHeaders[0];
            
            // ONLY set the parent if it's a new record
            if (headerRec.Id == null) {
                headerRec.Wishlist_Item__c = wishlistItemId;
            }
            
            headerRec.Bar_Code_No__c = currentBarCode;
            headerRec.Gross_Wt__c = tagData.header.grossWt;
            headerRec.Net_Wt__c = tagData.header.netWt;
            headerRec.Product_Name__c = tagData.header.productName;
            headerRec.Gold_Colour__c = tagData.header.goldColour;
            headerRec.Gold_Purity__c = tagData.header.goldPurity; 
            headerRec.Design_Code__c = tagData.header.designCode;
            headerRec.Diamond_Wt__c = tagData.header.diamondWt;
            headerRec.Certification_By__c = tagData.header.certificationBy; 
            headerRec.Stone_Wt__c = tagData.header.stoneWt;
            headerRec.Size__c = tagData.header.size;
            headerRec.Sub_Category_Code__c = tagData.header.subCategoryCode;
            
            upsert headerRec;
            
            // ==========================================
            // 3. UPSERT PRICE LINES: Tag_Price_Line__c
            // ==========================================
            List<Tag_Price_Line__c> priceLinesToUpsert = new List<Tag_Price_Line__c>();
            if (tagData.priceLines != null && !tagData.priceLines.isEmpty()) {
                
                Map<String, Id> existingPriceLineMap = new Map<String, Id>();
                for (Tag_Price_Line__c existingPL : [
                    SELECT Id, ACX_Tag_Header__c, Bar_Code_No__c 
                    FROM Tag_Price_Line__c 
                    WHERE ACX_Tag_Header__c = :headerRec.Id 
                    AND Bar_Code_No__c = :currentBarCode
                    AND Wishlist_Item__c = :wishlistItemId
                ]) {
                    String key = wishlistItemId + '-' + existingPL.ACX_Tag_Header__c + '-' + existingPL.Bar_Code_No__c;
                    existingPriceLineMap.put(key, existingPL.Id);
                }
                
                for (PriceLineData pl : tagData.priceLines) {
                    Tag_Price_Line__c plRec = new Tag_Price_Line__c();
                    String key = wishlistItemId + '-' + headerRec.Id + '-' + pl.barCodeNo;
                    
                    if (existingPriceLineMap.containsKey(key)) {
                        plRec.Id = existingPriceLineMap.get(key); // Existing Record
                    } else {
                        // New Record: Set parent lookups/master-details
                        plRec.ACX_Tag_Header__c = headerRec.Id;
                        plRec.Wishlist_Item__c = wishlistItemId;
                    }
                    
                    plRec.Bar_Code_No__c = pl.barCodeNo;
                    plRec.Product_Price__c = pl.productPrice;
                    plRec.GST_Percentage__c = pl.gstPercentage;
                    priceLinesToUpsert.add(plRec);
                }
                
                upsert priceLinesToUpsert;
                
                Id primaryPriceLineId = priceLinesToUpsert[0].Id;
                
                // ==========================================
                // 4. UPSERT DETAILS: Tag_Price_Detail_Line__c
                // ==========================================
                if (tagData.detailLines != null && !tagData.detailLines.isEmpty()) {
                    Map<String, Id> existingDetailsMap = new Map<String, Id>();
                    for (Tag_Price_Detail_Line__c existingDL : [
                        SELECT Id, Tag_Price_Line__c, Bar_Code_No__c, BOM_Item__c 
                        FROM Tag_Price_Detail_Line__c 
                        WHERE Tag_Price_Line__c = :primaryPriceLineId 
                        AND Bar_Code_No__c = :currentBarCode
                        AND Wishlist_Item__c = :wishlistItemId
                    ]) {
                        String key = wishlistItemId + '-' + existingDL.Tag_Price_Line__c + '-' + existingDL.Bar_Code_No__c + '-' + existingDL.BOM_Item__c;
                        existingDetailsMap.put(key, existingDL.Id);
                    }
                    
                    List<Tag_Price_Detail_Line__c> detailsToUpsert = new List<Tag_Price_Detail_Line__c>();
                    for (DetailLineData dl : tagData.detailLines) {
                        Tag_Price_Detail_Line__c dlRec = new Tag_Price_Detail_Line__c();
                        String key = wishlistItemId + '-' + primaryPriceLineId + '-' + dl.barCodeNo + '-' + dl.bomItem;
                        
                        if (existingDetailsMap.containsKey(key)) {
                            dlRec.Id = existingDetailsMap.get(key); // Existing Record
                        } else {
                            // New Record: Set parent lookups/master-details
                            dlRec.Tag_Price_Line__c = primaryPriceLineId;
                            dlRec.Wishlist_Item__c = wishlistItemId;
                        }
                        
                        dlRec.Bar_Code_No__c = dl.barCodeNo;
                        dlRec.BOM_Item__c = dl.bomItem;
                        dlRec.Purity__c = String.valueOf(dl.purity);
                        dlRec.Quantity__c = dl.quantity;
                        dlRec.UOM__c = dl.uom;
                        dlRec.Rate__c = dl.rate;
                        dlRec.Amount__c = dl.amount;
                        
                        detailsToUpsert.add(dlRec);
                    }
                    upsert detailsToUpsert;
                }
                
                // ==========================================
                // 5. UPSERT SCMs: Tag_Price_SCM__c
                // ==========================================
                if (tagData.scmLines != null && !tagData.scmLines.isEmpty()) {
                    Map<String, Id> existingSCMMap = new Map<String, Id>();
                    for (Tag_Price_SCM__c existingSCM : [
                        SELECT Id, Tag_Price_Line__c, Bar_Code_No__c, BOM_Item__c 
                        FROM Tag_Price_SCM__c 
                        WHERE Tag_Price_Line__c = :primaryPriceLineId 
                        AND Bar_Code_No__c = :currentBarCode
                        AND Wishlist_Item__c = :wishlistItemId
                    ]) {
                        String key = wishlistItemId + '-' + existingSCM.Tag_Price_Line__c + '-' + existingSCM.Bar_Code_No__c + '-' + existingSCM.BOM_Item__c;
                        existingSCMMap.put(key, existingSCM.Id);
                    }
                    
                    List<Tag_Price_SCM__c> scmsToUpsert = new List<Tag_Price_SCM__c>();
                    for (SCMLineData scm : tagData.scmLines) {
                        Tag_Price_SCM__c scmRec = new Tag_Price_SCM__c();
                        String key = wishlistItemId + '-' + primaryPriceLineId + '-' + scm.barCodeNo + '-' + scm.bomItem;
                        
                        if (existingSCMMap.containsKey(key)) {
                            scmRec.Id = existingSCMMap.get(key); // Existing Record
                        } else {
                            scmRec.Tag_Price_Line__c = primaryPriceLineId;
                            scmRec.Wishlist_Item__c = wishlistItemId;
                        }
                        
                        scmRec.Bar_Code_No__c = scm.barCodeNo;
                        scmRec.BOM_Item__c = scm.bomItem;
                        scmRec.Quantity__c = scm.quantity;
                        scmRec.Rate__c = scm.rate;
                        scmRec.Amount__c = scm.amount;
                        scmRec.Making_Type__c = scm.makingType;
                        
                        scmsToUpsert.add(scmRec);
                    }
                    upsert scmsToUpsert;
                }
            }
            
            // ======================================================================================
            // 6. FIRE ASYNC PROCESS TO FETCH & STORE IMAGES
            // ======================================================================================
            if (headerRec.Id != null && String.isNotBlank(headerRec.Design_Code__c)) {
                fetchAndAttachImagesAsync(headerRec.Id, wishlistItemId, currentBarCode, headerRec.Design_Code__c);
            }
            
        } catch (Exception e) {
            System.debug('Apex Exception in insertScannedTagRecords: ' + e.getMessage());
            IntegrationLogger.logError(CLASS_NAME, 'insertScannedTagRecords', e.getLineNumber(), null, e.getMessage() + '\n' + e.getStackTraceString(), 'Apex DML');
        }
    }
    
    // ======================================================================================
    // ORIGINAL API FETCH LOGIC
    // ======================================================================================
    
    public static TagResponse getTagData(String tagNo, Id wishlistItemId) {
        TagResponse response = new TagResponse();
        response.priceLines = new List<PriceLineData>();
        response.detailLines = new List<DetailLineData>();
        response.scmLines = new List<SCMLineData>();
        
        if (String.isBlank(tagNo)) {
            return response;
        }
        
        // --- Trigger Temporary Table Prep ---
        triggerTemporaryTablePost(tagNo, wishlistItemId);
        
        // Base URL using the Named Credential and Custom Label
        String baseUrl = 'callout:Orient_API_Access_NC/' + System.Label.BC_Endpoint + '/';
        
        // Ensure standard URL encoding for the OData filter
        String encodedTagNo = EncodingUtil.urlEncode(tagNo, 'UTF-8');
        String filterParam = '?$filter=tagNo%20eq%20\'' + encodedTagNo + '\'';
        
        // ---------------------------------------------------------
        // 1. FIRST API: ACXTagHeadersAPIJRS
        // ---------------------------------------------------------
        List<Map<String, Object>> headerRecords = makeCallout(baseUrl + 'ACXTagHeadersAPIJRS' + filterParam);
        
        if (!headerRecords.isEmpty()) {
            Map<String, Object> hData = headerRecords[0];
            
            HeaderData header = new HeaderData();
            
            header.barCodeNo = (String) hData.get('tagNo');
            header.grossWt = getDecimalValue(hData.get('grossWEIGHT'));
            header.netWt = getDecimalValue(hData.get('netWEIGHT'));
            header.goldColour = (String) hData.get('ornamentColor');
            header.productName = (String) hData.get('ornamentCATEGORYCODE');
            header.size = (String) hData.get('ornamentSIZE');
            header.designCode = (String) hData.get('designCODE');
            header.diamondWt = getDecimalValue(hData.get('diamondWEIGHT'));
            header.stoneWt = getDecimalValue(hData.get('stoneWEIGHTCT'));
            header.subCategoryCode = (String) hData.get('ornamentSUBCATEGORYCODE'); // Sub Category Code
            
            // SOQL Mapping: Metal Purity
            Decimal purityValue = getDecimalValue(hData.get('purity'));
            if (purityValue != null) {
                List<Metal_Purity_Master__c> purityList = [
                    SELECT Purity_Code__c 
                    FROM Metal_Purity_Master__c 
                    WHERE Purity__c = :purityValue 
                    LIMIT 1
                ];
                if (!purityList.isEmpty()) {
                    header.goldPurity = purityList[0].Purity_Code__c;
                }
            }
            
            // SOQL Mapping: Certification Vendor
            String vendorValue = (String) hData.get('certificationVendor');
            if (String.isNotBlank(vendorValue)) {
                List<Vendor_Master__c> vendorList = [
                    SELECT Vendor_Name__c 
                    FROM Vendor_Master__c 
                    WHERE Vendor_No__c = :vendorValue 
                    LIMIT 1
                ];
                if (!vendorList.isEmpty()) {
                    header.certificationBy = vendorList[0].Vendor_Name__c;
                }
            }
            
            response.header = header;
        }
        
        // ---------------------------------------------------------
        // 2. SECOND API: TagPriceLinesJRS
        // ---------------------------------------------------------
        List<Map<String, Object>> priceLineRecords = makeCallout(baseUrl + 'TagPriceLinesJRS' + filterParam);        
        for (Map<String, Object> record : priceLineRecords) {
            PriceLineData pl = new PriceLineData();
            pl.barCodeNo = (String) record.get('tagNo');
            pl.productPrice = getDecimalValue(record.get('taxableAmount'));
            response.priceLines.add(pl);
        }
        
        // ---------------------------------------------------------
        // 3. THIRD API: TagPriceDetailLinesJRS
        // ---------------------------------------------------------
        List<Map<String, Object>> detailLineRecords = makeCallout(baseUrl + 'TagPriceDetailLinesJRS' + filterParam);
        for (Map<String, Object> record : detailLineRecords) {
            DetailLineData dl = new DetailLineData();
            dl.barCodeNo = (String) record.get('tagNo');
            dl.bomItem = (String) record.get('item');
            dl.purity = getDecimalValue(record.get('purity'));
            dl.quantity = getDecimalValue(record.get('qty'));
            dl.uom = (String) record.get('uom');
            dl.rate = getDecimalValue(record.get('rate'));
            dl.amount = getDecimalValue(record.get('amount'));
            response.detailLines.add(dl);
        }
        
        // ---------------------------------------------------------
        // 4. FOURTH API: TagPriceSCMAPIJRS
        // ---------------------------------------------------------
        List<Map<String, Object>> scmRecords = makeCallout(baseUrl + 'TagPriceSCMAPIJRS' + filterParam);
        for (Map<String, Object> record : scmRecords) {
            SCMLineData scm = new SCMLineData();
            scm.barCodeNo = (String) record.get('tagNo');
            scm.bomItem = (String) record.get('itemNo');
            scm.quantity = getDecimalValue(record.get('quantity'));
            scm.rate = getDecimalValue(record.get('rate'));
            scm.amount = getDecimalValue(record.get('amount'));
            scm.makingType = (String) record.get('makingTYPE');
            response.scmLines.add(scm);
        }
        
        // ======================================================================================
        // NEW GST INTEGRATION LOGIC (TagPricesJRS -> ItemListJRS -> HSNCodeAPIJRS)
        // ======================================================================================
        
        String itemID = null;
        String gstGroupCode = null;
        String hsnSACCode = null;
        Decimal finalGstValue = null;
        
        // Step 1: Call TagPricesJRS to get itemID
        List<Map<String, Object>> tagPricesRecords = makeCallout(baseUrl + 'TagPricesJRS' + filterParam);
        if (!tagPricesRecords.isEmpty()) {
            itemID = (String) tagPricesRecords[0].get('itemID');
        }
        
        // Step 2: Call ItemListJRS using itemID to get gstGroupCode and hsnSACCode
        if (String.isNotBlank(itemID)) {
            String itemFilter = '?$filter=no%20eq%20\'' + EncodingUtil.urlEncode(itemID, 'UTF-8') + '\'';
            List<Map<String, Object>> itemListRecords = makeCallout(baseUrl + 'ItemListJRS' + itemFilter);
            
            if (!itemListRecords.isEmpty()) {
                gstGroupCode = (String) itemListRecords[0].get('gstGroupCode');
                hsnSACCode = (String) itemListRecords[0].get('hsnSACCode');
            }
        }
        
        // Step 3: Call HSNCodeAPIJRS using gstGroupCode and hsnSACCode to get the final GST %
        if (String.isNotBlank(gstGroupCode) && String.isNotBlank(hsnSACCode)) {
            String hsnFilter = '?$filter=gstGroupCode%20eq%20\'' + EncodingUtil.urlEncode(gstGroupCode, 'UTF-8') + 
                '\'%20and%20code%20eq%20\'' + EncodingUtil.urlEncode(hsnSACCode, 'UTF-8') + '\'';
            List<Map<String, Object>> hsnRecords = makeCallout(baseUrl + 'HSNCodeAPIJRS' + hsnFilter);
            
            if (!hsnRecords.isEmpty()) {
                finalGstValue = getDecimalValue(hsnRecords[0].get('gst'));
            }
        }
        
        // Step 4: Apply the extracted GST value to all price line items in the response payload
        if (finalGstValue != null) {
            for (PriceLineData pl : response.priceLines) {
                pl.gstPercentage = finalGstValue;
            }
        }
        
        return response;
    }
    
    /**
* Utility Method: Triggers the initial POST call to populate BC Temporary Tables
*/
    private static void triggerTemporaryTablePost(String tagNo, Id wishlistItemId) {
        try {
            // 1. Fetch current User's Location_Code__c
            User currentUser = [SELECT Location_Code__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            String locationCode = currentUser.Location_Code__c != null ? currentUser.Location_Code__c : '';
            
            // 2. Fallback logic: If User's Location Code is blank, fetch from the Wishlist Item's Store
            if (String.isBlank(locationCode) && wishlistItemId != null) {
                List<Wishlist_Item__c> wishlistItems = [
                    SELECT Showroom_Visit__r.StoreLookup__r.Store_Code__c 
                    FROM Wishlist_Item__c 
                    WHERE Id = :wishlistItemId 
                    LIMIT 1
                ];
                
                // Using the Safe Navigation operator (?.) to easily avoid Null Pointer Exceptions if parents are missing
                if (!wishlistItems.isEmpty()) {
                    String storeCode = wishlistItems[0].Showroom_Visit__r?.StoreLookup__r?.Store_Code__c;
                    if (String.isNotBlank(storeCode)) {
                        locationCode = storeCode;
                    }
                }
            }
            
            // Ensure it is never null before building the JSON
            if (locationCode == null) {
                locationCode = '';
            }
            
            // 3. Prepare Payload
            Map<String, String> requestBody = new Map<String, String>{
                'Location' => locationCode,
                    'ScanTagNo' => tagNo
                    };
                        
                        // 4. Set up Endpoint and HttpRequest
                        String endpoint = 'callout:Orient_API_Access_NC/' + System.Label.BC_Endpoint + '/TagPriceLinesJRS';
            
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(120000);
            
            // 5. Fire Request 
            HttpResponse res = http.send(req);
            
            // Log if not a successful response (e.g. 200, 201, 204)
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                System.debug('POST Pre-Flight Error Status: ' + res.getStatusCode());
                IntegrationLogger.logError(CLASS_NAME, 'triggerTemporaryTablePost', 0, res.getStatusCode(), res.getBody(), 'POST Callout');
            }
            
        } catch (Exception e) {
            System.debug('Error in POST Pre-Flight Call: ' + e.getMessage());
            IntegrationLogger.logError(CLASS_NAME, 'triggerTemporaryTablePost', e.getLineNumber(), null, e.getMessage(), 'POST Callout Exception');
        }
    }
    
    /**
* Utility Method: Handles the generic HTTP GET requests and extracts the 'value' JSON array.
*/
    private static List<Map<String, Object>> makeCallout(String endpoint) {
        List<Map<String, Object>> resultList = new List<Map<String, Object>>();
        
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(120000); 
        
        try {
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                if (responseMap.containsKey('value')) {
                    List<Object> values = (List<Object>) responseMap.get('value');
                    for (Object val : values) {
                        resultList.add((Map<String, Object>) val);
                    }
                }
            } else {
                System.debug('Callout Error (' + res.getStatusCode() + ') on ' + endpoint + ' : ' + res.getBody());
                // Log non-200 responses
                IntegrationLogger.logError(CLASS_NAME, 'makeCallout', 0, res.getStatusCode(), res.getBody(), 'GET Callout');
            }
        } catch (Exception e) {
            System.debug('Callout Exception: ' + e.getMessage());
            IntegrationLogger.logError(CLASS_NAME, 'makeCallout', e.getLineNumber(), null, e.getMessage(), 'GET Callout Exception');
        }
        
        return resultList;
    }
    
    private static Decimal getDecimalValue(Object val) {
        if (val == null) {
            return null;
        }
        return Decimal.valueOf(String.valueOf(val));
    }
    
    @future(callout=true)
    public static void fetchAndAttachImagesAsync(Id headerId, Id wishlistItemId, String tagNo, String designCode) {
        try {
            // 1. Query the Wishlist Item Name for the Naming Convention
            String wishlistItemName = '';
            if (wishlistItemId != null) {
                List<Wishlist_Item__c> wlList = [SELECT Name FROM Wishlist_Item__c WHERE Id = :wishlistItemId LIMIT 1];
                if (!wlList.isEmpty()) {
                    wishlistItemName = wlList[0].Name;
                }
            }
            
            // Define the base prefix for files
            String filePrefix = (String.isNotBlank(wishlistItemName) ? wishlistItemName + '_' : '') + designCode + '_Media_';
            
            // Base URL using the Named Credential and Custom Label
            String baseUrl = 'callout:Orient_API_Access_NC/' + System.Label.BC_Endpoint + '/';
            String encodedDesignCode = EncodingUtil.urlEncode(designCode, 'UTF-8');
            String endpoint = baseUrl + 'designImageAPIJRS?$filter=designNo%20eq%20\'' + encodedDesignCode + '\''; 
            
            // --- CALLOUT 1: Fetch metadata URLs ---
            List<Map<String, Object>> imageRecords = makeCallout(endpoint);
            List<String> imageUrlsToDownload = new List<String>();
            
            for (Map<String, Object> record : imageRecords) {
                if (record.containsKey('imageUrl') && record.get('imageUrl') != null) {
                    imageUrlsToDownload.add((String) record.get('imageUrl'));
                }
            }
            
            if (imageUrlsToDownload.isEmpty()) {
                return; // No media found for this design
            }
            
            List<ContentVersion> cvList = new List<ContentVersion>();
            Http http = new Http();
            
            // --- CALLOUTS 2+: Download all media files into memory FIRST ---
            // We hold them as Blobs in memory. No DML has happened yet!
            for (Integer i = 0; i < imageUrlsToDownload.size(); i++) {
                String imgUrl = imageUrlsToDownload[i];
                
                String cleanUrl = imgUrl.contains('?') ? imgUrl.substringBefore('?') : imgUrl;
                String ext = cleanUrl.contains('.') ? cleanUrl.substringAfterLast('.') : 'png';
                String finalFileName = filePrefix + (i + 1); 
                
                HttpRequest req = new HttpRequest();
                req.setEndpoint(imgUrl);
                req.setMethod('GET');
                req.setTimeout(60000); 
                
                HttpResponse res = http.send(req);
                
                if (res.getStatusCode() == 200) {
                    ContentVersion cv = new ContentVersion();
                    cv.VersionData = res.getBodyAsBlob(); // Safe in-memory assignment
                    cv.Title = finalFileName;
                    cv.PathOnClient = finalFileName + '.' + ext; 
                    cv.IsMajorVersion = true;
                    cvList.add(cv);
                } else {
                    IntegrationLogger.logError(CLASS_NAME, 'fetchAndAttachImagesAsync', 0, res.getStatusCode(), res.getBody(), 'Media Download Failed for URL: ' + imgUrl);
                }
            }
            
            // ==================================================================================
            // ALL CALLOUTS ARE NOW COMPLETE. IT IS NOW SAFE TO PERFORM DML OPERATIONS.
            // ==================================================================================
            
            // --- DML 1: Find and Delete Existing Old Files ---
            List<ContentDocumentLink> existingLinks = [
                SELECT ContentDocumentId, ContentDocument.Title 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :headerId
            ];
            
            Set<Id> docIdsToDelete = new Set<Id>();
            for (ContentDocumentLink cdl : existingLinks) {
                if (cdl.ContentDocument.Title != null && cdl.ContentDocument.Title.startsWith(filePrefix)) {
                    docIdsToDelete.add(cdl.ContentDocumentId);
                }
            }
            
            if (!docIdsToDelete.isEmpty()) {
                List<ContentDocument> docsToDelete = new List<ContentDocument>();
                for (Id docId : docIdsToDelete) {
                    docsToDelete.add(new ContentDocument(Id = docId));
                }
                delete docsToDelete; // Wipes out the old duplicates completely
            }
            
            // --- DML 2: Insert New ContentVersions ---
            if (!cvList.isEmpty()) {
                insert cvList;
                
                // Query newly created ContentDocumentIds
                Set<Id> cvIds = new Set<Id>();
                for (ContentVersion cv : cvList) {
                    cvIds.add(cv.Id);
                }
                
                List<ContentVersion> insertedCvs = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :cvIds];
                List<ContentDocumentLink> cdlList = new List<ContentDocumentLink>();
                
                // --- DML 3: Link Media to the ACX_Tag_Header__c record ---
                for (ContentVersion cv : insertedCvs) {
                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.LinkedEntityId = headerId;
                    cdl.ContentDocumentId = cv.ContentDocumentId;
                    cdl.ShareType = 'V'; // Viewer permission
                    cdl.Visibility = 'AllUsers'; 
                    cdlList.add(cdl);
                }
                
                if (!cdlList.isEmpty()) {
                    insert cdlList;
                }
            }
            
        } catch (Exception e) {
            System.debug('Apex Exception in fetchAndAttachImagesAsync: ' + e.getMessage());
            IntegrationLogger.logError(CLASS_NAME, 'fetchAndAttachImagesAsync', e.getLineNumber(), null, e.getMessage(), 'Async Media Processing');
        }
    }
}