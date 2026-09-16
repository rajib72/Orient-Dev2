@isTest
private class Ctrl_WishListItemPageDesignTest {

    @testSetup
    static void setupData() {

        // Create Showroom Visit
        Showroom_Visit__c visit = new Showroom_Visit__c(
           // Name = 'Test Visit'
        );
        insert visit;

        // Create Wishlist Item
        Wishlist_Item__c wishlist = new Wishlist_Item__c(
          //  Name = 'WL-001',
            Showroom_Visit__c = visit.Id
        );
        insert wishlist;

        // Create ACX Header
        ACX_Tag_Header__c header = new ACX_Tag_Header__c(
            Wishlist_Item__c = wishlist.Id,
            Bar_Code_No__c = 'TAG001',
            Product_Name__c = 'Ring',
            Design_Code__c = 'D001',
            Gross_Wt__c = 10,
            Net_Wt__c = 9,
            Gold_Purity__c = '22K',
            Gold_Colour__c = 'Yellow',
            Size__c = '7',
            Diamond_Wt__c = 1,
            Stone_Wt__c = 0.5,
            Certification_By__c = 'IGI'
        );
        insert header;

        // Create Price Line
        Tag_Price_Line__c priceLine = new Tag_Price_Line__c(
            Wishlist_Item__c = wishlist.Id,
            ACX_Tag_Header__c = header.Id,
            Bar_Code_No__c = 'TAG001',
            Product_Price__c = 50000
           // Tax_Amount__c = 1500,
          //  Product_Price_Inclusive_GST__c = 51500
        );
        insert priceLine;

        // Create Detail Line
        Tag_Price_Detail_Line__c detailLine = new Tag_Price_Detail_Line__c(
            Wishlist_Item__c = wishlist.Id,
            Tag_Price_Line__c = priceLine.Id,
            Bar_Code_No__c = 'TAG001',
            BOM_Item__c = 'Gold',
            Purity__c = '22',
            Quantity__c = 1,
            UOM__c = 'GM',
            Rate__c = 5000,
            Amount__c = 5000
        );
        insert detailLine;

        // Create SCM Line
        Tag_Price_SCM__c scmLine = new Tag_Price_SCM__c(
            Wishlist_Item__c = wishlist.Id,
            Tag_Price_Line__c = priceLine.Id,
            Bar_Code_No__c = 'TAG001',
            BOM_Item__c = 'Making',
            Quantity__c = 1,
            Rate__c = 1000,
            Amount__c = 1000,
            Making_Type__c = 'Manual'
        );
        insert scmLine;

        // Create Questions
        Wishlist_Item_Question__c question = new Wishlist_Item_Question__c(
            Wishlist_Item__c = wishlist.Id,
            Question__c = 'Is hallmark available?',
            Question_Checked__c = true
        );
        insert question;

        // Create Image File
        ContentVersion cvImage = new ContentVersion();
        cvImage.Title = 'TestImage';
        cvImage.PathOnClient = 'TestImage.jpg';
        cvImage.VersionData = Blob.valueOf('Image Body');
        insert cvImage;

        ContentVersion insertedImage = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cvImage.Id
            LIMIT 1
        ];

        ContentDocumentLink imageLink = new ContentDocumentLink(
            LinkedEntityId = header.Id,
            ContentDocumentId = insertedImage.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert imageLink;

        // Create Video File
        ContentVersion cvVideo = new ContentVersion();
        cvVideo.Title = 'TestVideo';
        cvVideo.PathOnClient = 'TestVideo.mp4';
        cvVideo.VersionData = Blob.valueOf('Video Body');
        insert cvVideo;

        ContentVersion insertedVideo = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cvVideo.Id
            LIMIT 1
        ];

        ContentDocumentLink videoLink = new ContentDocumentLink(
            LinkedEntityId = header.Id,
            ContentDocumentId = insertedVideo.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert videoLink;
    }

    @isTest
    static void testGetItemByBarcode() {

        Wishlist_Item__c wishlist = [
            SELECT Id
            FROM Wishlist_Item__c
            LIMIT 1
        ];

        Test.startTest();

        Ctrl_WishListItemPageDesign.getItemByBarcode(
            'TAG001',
            wishlist.Id
        );

        Test.stopTest();
    }

    @isTest
    static void testGetItemByBarcode_BlankInputs() {

        Wishlist_Item__c wishlist = [
            SELECT Id
            FROM Wishlist_Item__c
            LIMIT 1
        ];

        Test.startTest();

        Ctrl_WishListItemPageDesign.getItemByBarcode(
            null,
            wishlist.Id
        );

        Ctrl_WishListItemPageDesign.getItemByBarcode(
            'TAG001',
            null
        );

        Ctrl_WishListItemPageDesign.getItemByBarcode(
            '',
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testGetItemByBarcode_NoRecord() {

        Wishlist_Item__c wishlist = [
            SELECT Id
            FROM Wishlist_Item__c
            LIMIT 1
        ];

        Test.startTest();

        Ctrl_WishListItemPageDesign.getItemByBarcode(
            'INVALIDTAG',
            wishlist.Id
        );

        Test.stopTest();
    }

    @isTest
    static void testSaveQuestions() {

        List<Wishlist_Item_Question__c> questions = [
            SELECT Id, Question_Checked__c
            FROM Wishlist_Item_Question__c
        ];

        for (Wishlist_Item_Question__c q : questions) {
            q.Question_Checked__c = false;
        }

        Test.startTest();

        Ctrl_WishListItemPageDesign.saveQuestions(questions);

        Test.stopTest();
    }

    @isTest
    static void testSaveQuestions_NullAndEmpty() {

        Test.startTest();

        Ctrl_WishListItemPageDesign.saveQuestions(null);

        Ctrl_WishListItemPageDesign.saveQuestions(
            new List<Wishlist_Item_Question__c>()
        );

        Test.stopTest();
    }

   @isTest
static void testSaveQuestions_Exception() {

    Wishlist_Item_Question__c question = [
        SELECT Id, Question__c
        FROM Wishlist_Item_Question__c
        LIMIT 1
    ];

    delete question;

    question.Question__c = 'Updated Question';

    Test.startTest();

    try {
        Ctrl_WishListItemPageDesign.saveQuestions(
            new List<Wishlist_Item_Question__c>{ question }
        );
    } catch (Exception e) {
    }

    Test.stopTest();
}
}