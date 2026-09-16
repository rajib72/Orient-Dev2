public with sharing class Ctrl_WishListItemPageDesign {

    public class DetailLineWrapper {
        @AuraEnabled public String bomItem;
        @AuraEnabled public String purity;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public String uom;
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Decimal amount;
    }

    public class ScmLineWrapper {
        @AuraEnabled public String bomItem;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String makingType;
    }

    public class QuestionWrapper {
        @AuraEnabled public Id questionId;
        @AuraEnabled public String questionText;
        @AuraEnabled public Boolean isChecked;
    }

    // New wrapper handles BOTH Photos & Videos
    public class MediaWrapper {
        @AuraEnabled public String url;
        @AuraEnabled public Boolean isImage;
        @AuraEnabled public Boolean isVideo;
        @AuraEnabled public String key;
    }

    @AuraEnabled
    public static Map<String, Object> getItemByBarcode(String barcode, Id wishlistId) {
        Map<String, Object> result = new Map<String, Object>();

        if (String.isBlank(barcode) || wishlistId == null) {
            return result;
        }

        // 1. ACX_Tag_Header__c
        List<ACX_Tag_Header__c> acxList = [
            SELECT Id, Product_Name__c, Design_Code__c, Gross_Wt__c, Net_Wt__c,
                   Gold_Purity__c, Gold_Colour__c, Size__c, Diamond_Wt__c,
                   Stone_Wt__c, Certification_By__c, Bar_Code_No__c, Wishlist_Item__c
            FROM ACX_Tag_Header__c
            WHERE Wishlist_Item__c = :wishlistId
              AND Bar_Code_No__c = :barcode
            LIMIT 1
        ];

        if (acxList.isEmpty()) {
            return result;
        }

        ACX_Tag_Header__c acx = acxList[0];

        result.put('recordId', acx.Id);
        result.put('productName', acx.Product_Name__c);
        result.put('barcode', acx.Bar_Code_No__c);
        result.put('designCode', acx.Design_Code__c);
        result.put('grossWeight', acx.Gross_Wt__c);
        result.put('netWeight', acx.Net_Wt__c);
        result.put('goldPurity', acx.Gold_Purity__c);
        result.put('goldColor', acx.Gold_Colour__c);
        result.put('size', acx.Size__c);
        result.put('diamondWeight', acx.Diamond_Wt__c);
        result.put('stoneWeight', acx.Stone_Wt__c);
        result.put('certificationBy', acx.Certification_By__c);

        // 2. Tag_Price_Line__c
        List<Tag_Price_Line__c> tagPriceList = [
            SELECT Id, Product_Price__c, Tax_Amount__c, Product_Price_Inclusive_GST__c, Bar_Code_No__c, Wishlist_Item__c
            FROM Tag_Price_Line__c
            WHERE Wishlist_Item__c = :wishlistId AND Bar_Code_No__c = :barcode
            LIMIT 1
        ];

        Tag_Price_Line__c tagPrice = tagPriceList.isEmpty() ? null : tagPriceList[0];
        result.put('price', tagPrice != null ? tagPrice.Product_Price__c : null);
        result.put('productPriceInclusiveGST', tagPrice != null ? tagPrice.Product_Price_Inclusive_GST__c : null);
        result.put('taxAmount', tagPrice != null ? tagPrice.Tax_Amount__c : null);

        // 3. Tag_Price_Detail_Line__c
        List<DetailLineWrapper> detailLines = new List<DetailLineWrapper>();
        for (Tag_Price_Detail_Line__c row : [
            SELECT Id, BOM_Item__c, Purity__c, Quantity__c, UOM__c, Rate__c, Amount__c, Bar_Code_No__c, Wishlist_Item__c
            FROM Tag_Price_Detail_Line__c
            WHERE Wishlist_Item__c = :wishlistId AND Bar_Code_No__c = :barcode
            ORDER BY CreatedDate ASC
        ]) {
            DetailLineWrapper d = new DetailLineWrapper();
            d.bomItem = row.BOM_Item__c;
            d.purity = row.Purity__c;
            d.quantity = row.Quantity__c;
            d.uom = row.UOM__c;
            d.rate = row.Rate__c;
            d.amount = row.Amount__c;
            detailLines.add(d);
        }
        result.put('detailLines', detailLines);

        // 4. Tag_Price_SCM__c
        List<ScmLineWrapper> scmLines = new List<ScmLineWrapper>();
        for (Tag_Price_SCM__c row : [
            SELECT Id, BOM_Item__c, Quantity__c, Rate__c, Amount__c, Making_Type__c, Bar_Code_No__c, Wishlist_Item__c
            FROM Tag_Price_SCM__c
            WHERE Wishlist_Item__c = :wishlistId AND Bar_Code_No__c = :barcode
            ORDER BY CreatedDate ASC
        ]) {
            ScmLineWrapper s = new ScmLineWrapper();
            s.bomItem = row.BOM_Item__c;
            s.quantity = row.Quantity__c;
            s.rate = row.Rate__c;
            s.amount = row.Amount__c;
            s.makingType = row.Making_Type__c;
            scmLines.add(s);
        }
        result.put('scmLines', scmLines);

        // 5. Media Retrieval (Images AND Videos) from ACX_Tag_Header__c
        List<MediaWrapper> mediaItems = new List<MediaWrapper>();
        Set<String> videoTypes = new Set<String>{'MP4', 'MOV', 'WMV', 'AVI', 'M4V', 'MKV', 'WEBM'};

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :acx.Id
        ];

        if (!links.isEmpty()) {
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink cdl : links) {
                docIds.add(cdl.ContentDocumentId);
            }

            for (ContentVersion cv : [
                SELECT Id, FileType, FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                  AND IsLatest = true
            ]) {
                MediaWrapper mw = new MediaWrapper();
                mw.url = '/sfc/servlet.shepherd/version/download/' + cv.Id;
                mw.key = cv.Id;

                String ext = cv.FileExtension != null ? cv.FileExtension.toUpperCase() : '';
                String fType = cv.FileType != null ? cv.FileType.toUpperCase() : '';

                // Identify if file is a video
                if (videoTypes.contains(ext) || videoTypes.contains(fType)) {
                    mw.isVideo = true;
                    mw.isImage = false;
                } else {
                    mw.isVideo = false;
                    mw.isImage = true;
                }
                
                mediaItems.add(mw);
            }
        }
        result.put('mediaItems', mediaItems);

        // 6. Fetch Wishlist Item Questions related to Wishlist Item
        List<QuestionWrapper> questionsList = new List<QuestionWrapper>();
        for (Wishlist_Item_Question__c q : [
            SELECT Id, Question__c, Question_Checked__c 
            FROM Wishlist_Item_Question__c 
            WHERE Wishlist_Item__c = :wishlistId 
            ORDER BY Name ASC
        ]) {
            QuestionWrapper qw = new QuestionWrapper();
            qw.questionId = q.Id;
            qw.questionText = q.Question__c;
            qw.isChecked = q.Question_Checked__c;
            questionsList.add(qw);
        }
        result.put('questions', questionsList);

        return result;
    }

    @AuraEnabled
    public static void saveQuestions(List<Wishlist_Item_Question__c> questionsToUpdate) {
        try {
            if (questionsToUpdate != null && !questionsToUpdate.isEmpty()) {
                update questionsToUpdate;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error updating questions: ' + e.getMessage());
        }
    }
}
/*public with sharing class Ctrl_WishListItemPageDesign {

    public class DetailLineWrapper {
        @AuraEnabled public String bomItem;
        @AuraEnabled public String purity;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public String uom;
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Decimal amount;
    }

    public class ScmLineWrapper {
        @AuraEnabled public String bomItem;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal rate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String makingType;
    }

    // New wrapper to carry question data
    public class QuestionWrapper {
        @AuraEnabled public Id questionId;
        @AuraEnabled public String questionText;
        @AuraEnabled public Boolean isChecked;
    }

    @AuraEnabled
    public static Map<String, Object> getItemByBarcode(String barcode, Id wishlistId) {
        Map<String, Object> result = new Map<String, Object>();

        if (String.isBlank(barcode) || wishlistId == null) {
            return result;
        }

        // 1. ACX_Tag_Header__c
        List<ACX_Tag_Header__c> acxList = [
            SELECT Id,
                   Product_Name__c,
                   Design_Code__c,
                   Gross_Wt__c,
                   Net_Wt__c,
                   Gold_Purity__c,
                   Gold_Colour__c,
                   Size__c,
                   Diamond_Wt__c,
                   Stone_Wt__c,
                   Certification_By__c,
                   Bar_Code_No__c,
                   Wishlist_Item__c
            FROM ACX_Tag_Header__c
            WHERE Wishlist_Item__c = :wishlistId
              AND Bar_Code_No__c = :barcode
            LIMIT 1
        ];

        if (acxList.isEmpty()) {
            return result;
        }

        ACX_Tag_Header__c acx = acxList[0];

        result.put('recordId', acx.Id);
        result.put('productName', acx.Product_Name__c);
        result.put('barcode', acx.Bar_Code_No__c);
        result.put('designCode', acx.Design_Code__c);
        result.put('grossWeight', acx.Gross_Wt__c);
        result.put('netWeight', acx.Net_Wt__c);
        result.put('goldPurity', acx.Gold_Purity__c);
        result.put('goldColor', acx.Gold_Colour__c);
        result.put('size', acx.Size__c);
        result.put('diamondWeight', acx.Diamond_Wt__c);
        result.put('stoneWeight', acx.Stone_Wt__c);
        result.put('certificationBy', acx.Certification_By__c);

        // 2. Tag_Price_Line__c
        List<Tag_Price_Line__c> tagPriceList = [
            SELECT Id,
                   Product_Price__c,Tax_Amount__c,Product_Price_Inclusive_GST__c,
                   Bar_Code_No__c,
                   Wishlist_Item__c
            FROM Tag_Price_Line__c
            WHERE Wishlist_Item__c = :wishlistId
              AND Bar_Code_No__c = :barcode
            LIMIT 1
        ];

        Tag_Price_Line__c tagPrice = tagPriceList.isEmpty() ? null : tagPriceList[0];
        result.put('price', tagPrice != null ? tagPrice.Product_Price__c : null);
        result.put('productPriceInclusiveGST', tagPrice != null ? tagPrice.Product_Price_Inclusive_GST__c : null);
        result.put('taxAmount', tagPrice != null ? tagPrice.Tax_Amount__c : null);

        // 3. Tag_Price_Detail_Line__c
        List<DetailLineWrapper> detailLines = new List<DetailLineWrapper>();
        for (Tag_Price_Detail_Line__c row : [
            SELECT Id, BOM_Item__c, Purity__c, Quantity__c, UOM__c, Rate__c, Amount__c, Bar_Code_No__c, Wishlist_Item__c
            FROM Tag_Price_Detail_Line__c
            WHERE Wishlist_Item__c = :wishlistId
              AND Bar_Code_No__c = :barcode
            ORDER BY CreatedDate ASC
        ]) {
            DetailLineWrapper d = new DetailLineWrapper();
            d.bomItem = row.BOM_Item__c;
            d.purity = row.Purity__c;
            d.quantity = row.Quantity__c;
            d.uom = row.UOM__c;
            d.rate = row.Rate__c;
            d.amount = row.Amount__c;
            detailLines.add(d);
        }
        result.put('detailLines', detailLines);

        // 4. Tag_Price_SCM__c
        List<ScmLineWrapper> scmLines = new List<ScmLineWrapper>();
        for (Tag_Price_SCM__c row : [
            SELECT Id, BOM_Item__c, Quantity__c, Rate__c, Amount__c, Making_Type__c, Bar_Code_No__c, Wishlist_Item__c
            FROM Tag_Price_SCM__c
            WHERE Wishlist_Item__c = :wishlistId
              AND Bar_Code_No__c = :barcode
            ORDER BY CreatedDate ASC
        ]) {
            ScmLineWrapper s = new ScmLineWrapper();
            s.bomItem = row.BOM_Item__c;
            s.quantity = row.Quantity__c;
            s.rate = row.Rate__c;
            s.amount = row.Amount__c;
            s.makingType = row.Making_Type__c;
            scmLines.add(s);
        }
        result.put('scmLines', scmLines);

        // 5. Images from ACX_Tag_Header__c
        List<String> imageUrls = new List<String>();
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :acx.Id
        ];

        if (!links.isEmpty()) {
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink cdl : links) {
                docIds.add(cdl.ContentDocumentId);
            }

            for (ContentVersion cv : [
                SELECT Id
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                  AND IsLatest = true
            ]) {
                imageUrls.add('/sfc/servlet.shepherd/version/download/' + cv.Id);
            }
        }
        result.put('images', imageUrls);

        // 6. Fetch Wishlist Item Questions related to Wishlist Item
        List<QuestionWrapper> questionsList = new List<QuestionWrapper>();
        for (Wishlist_Item_Question__c q : [
            SELECT Id, Question__c, Question_Checked__c 
            FROM Wishlist_Item_Question__c 
            WHERE Wishlist_Item__c = :wishlistId 
            ORDER BY Name ASC
        ]) {
            QuestionWrapper qw = new QuestionWrapper();
            qw.questionId = q.Id;
            qw.questionText = q.Question__c;
            qw.isChecked = q.Question_Checked__c;
            questionsList.add(qw);
        }
        result.put('questions', questionsList);

        return result;
    }

    // New method to handle Updating the Checkboxes
    @AuraEnabled
    public static void saveQuestions(List<Wishlist_Item_Question__c> questionsToUpdate) {
        try {
            if (questionsToUpdate != null && !questionsToUpdate.isEmpty()) {
                update questionsToUpdate;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error updating questions: ' + e.getMessage());
        }
    }
} */