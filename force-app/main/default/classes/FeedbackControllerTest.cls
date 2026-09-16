@isTest
private class FeedbackControllerTest {

    /** Answers the ShreeSMS "accepted" shape: ok|<mobile>|<message id>. */
    private class SmsAcceptedMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/plain');
            res.setBody('ok|9831013797|273524927<br />');
            res.setStatusCode(200);
            return res;
        }
    }

    /** A Business Central invoice list, for the invoice screen tests. */
    private class BcInvoiceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"value":[{"documentNo":"INV-001","date":"2024-05-02",'
                + '"customerCode":"CUST-001","customerName":"Test Account",'
                + '"amountToCustomer":150.00,"locationName":"Test Store"}]}');
            res.setStatusCode(200);
            return res;
        }
    }

    private static final String VERIFIED_REF = 'REF_VERIFIED';
    private static final String PENDING_REF  = 'REF_PENDING';
    private static final String PENDING_CODE = '123456';

    @testSetup
    static void setup() {
        Store__c store = new Store__c(Name='Test Store', Store_Code__c='TS-01');
        insert store;

        Approval_Hierarchy__c hierarchy = new Approval_Hierarchy__c(
            Type__c='Customer Profile', Store__c=store.Id
        );
        insert hierarchy;

        Approval_Hierarchy_Level__c level = new Approval_Hierarchy_Level__c(
            Approval_Hierarchy__c=hierarchy.Id, Sr_No__c=1
        );
        insert level;

        Id adminProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id;
        Long stamp = DateTime.now().getTime();

        User approver = new User(
            ProfileId = adminProfileId,
            LastName = 'AppAdmin',
            Email = 'admin@test.com',
            Username = 'admin' + stamp + '@test.com',
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            Location_Code__c = 'TS-01'
        );

        // Deliberately no Location_Code__c: this is the user the routing tests
        // run as, so the store can only come from the customer record.
        User unlocated = new User(
            ProfileId = adminProfileId,
            LastName = 'NoLocation',
            Email = 'noloc@test.com',
            Username = 'noloc' + stamp + '@test.com',
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'noloc',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US'
        );

        insert new List<User>{ approver, unlocated };

        insert new Approval_Approver_Mapping__c(
            Approval_Hierarchy_Level__c=level.Id,
            Approver_User__c=approver.Id,
            Active__c=true,
            Is_Primary__c=true,
            Effective_From__c=Date.today().addDays(-1)
        );

        Account acc = new Account(
            Name='Test Account',
            Phone='9876543210',
            Email_Address__c='customer@test.com',
            BC_Customer_No__c='CUST-001',
            Preferred_Store__c=store.Id
        );
        insert acc;

        // No preferred store, so it exercises the "which store approves this?"
        // failure, and it also owns the OTP fixtures so they cannot throttle a
        // send made against the main customer.
        Account other = new Account(
            Name='Other Customer',
            Phone='9876543299'
        );
        insert other;

        insert new List<Feedback_Question__c>{
            new Feedback_Question__c(Question_EN__c='Overall?',  Sequence__c=1, Weightage__c=20),
            new Feedback_Question__c(Question_EN__c='Staff?',    Sequence__c=2, Weightage__c=20),
            new Feedback_Question__c(Question_EN__c='Clarity?',  Sequence__c=3, Weightage__c=20),
            new Feedback_Question__c(Question_EN__c='Purpose?',  Sequence__c=4, Weightage__c=20),
            new Feedback_Question__c(Question_EN__c='Return?',   Sequence__c=5, Weightage__c=20),
            // Carries a weighting but has no field behind it, so scoring skips it.
            new Feedback_Question__c(Question_EN__c='Comments?', Sequence__c=6, Weightage__c=5)
        };

        List<Showroom_Visit__c> visits = new List<Showroom_Visit__c>{
            new Showroom_Visit__c(CUSTOMERlookup__c=acc.Id, StoreLookup__c=store.Id),
            new Showroom_Visit__c(CUSTOMERlookup__c=acc.Id, StoreLookup__c=store.Id),
            new Showroom_Visit__c(CUSTOMERlookup__c=acc.Id, StoreLookup__c=store.Id)
        };
        insert visits;

        insert new List<Feedback__c>{
            new Feedback__c(Orient_Customer__c=acc.Id, Showroom_Visit__c=visits[0].Id, Status__c='Pending'),
            new Feedback__c(Orient_Customer__c=acc.Id, Showroom_Visit__c=visits[1].Id, Status__c='Completed'),
            // Unattached to a visit, for the submit tests.
            new Feedback__c(Orient_Customer__c=acc.Id, Status__c='In Progress'),
            new Feedback__c(Orient_Customer__c=acc.Id, Status__c='In Progress'),
            new Feedback__c(Orient_Customer__c=acc.Id, Status__c='In Progress'),
            new Feedback__c(Orient_Customer__c=acc.Id, Status__c='In Progress')
        };

        insert new List<OTP_Verification__c>{
            new OTP_Verification__c(
                Customer__c = other.Id,
                Reference__c = VERIFIED_REF,
                Code_Hash__c = FDB_OtpService.hash(PENDING_CODE, VERIFIED_REF),
                Destination__c = 'customer@test.com',
                Channel__c = 'Email',
                Purpose__c = 'Invoice Email Verification',
                Status__c = 'Verified',
                Expires_At__c = System.now().addSeconds(600),
                Attempts__c = 0
            ),
            new OTP_Verification__c(
                Customer__c = other.Id,
                Reference__c = PENDING_REF,
                Code_Hash__c = FDB_OtpService.hash(PENDING_CODE, PENDING_REF),
                Destination__c = '9876543211',
                Channel__c = 'SMS',
                Purpose__c = 'Profile Update',
                Status__c = 'Pending',
                Expires_At__c = System.now().addSeconds(600),
                Attempts__c = 0
            )
        };
    }

    private static Account mainAccount() {
        return [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
    }

    private static Account otherAccount() {
        return [SELECT Id FROM Account WHERE Name = 'Other Customer' LIMIT 1];
    }

    private static User unlocatedUser() {
        return [SELECT Id FROM User WHERE LastName = 'NoLocation' LIMIT 1];
    }

    /**
     * What the customer would have been shown, when it can be read at all.
     *
     * Until "Improved AuraHandledException Error Messages" is switched on,
     * getMessage() answers with a fixed placeholder rather than the text the
     * screen gets, so there is nothing to compare against. The exception
     * reaching the caller is the contract either way; this checks the wording
     * on top of that wherever the org lets it.
     */
    private static void assertHandled(AuraHandledException e, String expected) {
        String actual = e.getMessage();
        if (actual != 'Script-thrown exception') {
            System.assert(actual.contains(expected),
                'Expected a message mentioning "' + expected + '" but got: ' + actual);
        }
    }

    private static Feedback__c freeFeedback(Integer index) {
        List<Feedback__c> pool = [
            SELECT Id FROM Feedback__c
            WHERE Status__c = 'In Progress'
            ORDER BY CreatedDate ASC, Id ASC
        ];
        return pool[index];
    }

    // ------------------------------------------------------------- QUESTIONS

    @isTest
    static void testGetFeedbackQuestions() {
        List<Feedback_Question__c> qs = FeedbackController.getFeedbackQuestions();
        System.assertEquals(6, qs.size(), 'Every configured question should be returned');
        System.assertEquals('Overall?', qs[0].Question_EN__c, 'Ordered by sequence');
        System.assertEquals(6, qs[5].Sequence__c);
    }

    @isTest
    static void testGetFeedbackVideoUrls() {
        ContentVersion cv = new ContentVersion(
            Title = 'Test feedbackvideo 1',
            PathOnClient = 'Test_feedbackvideo_1.mp4',
            VersionData = Blob.valueOf('test video content'),
            IsMajorVersion = true
        );
        insert cv;

        Test.startTest();
        List<String> urls = FeedbackController.getFeedbackVideoUrls();
        Test.stopTest();

        System.assertEquals(1, urls.size(), 'Should find the feedback video');
        System.assert(urls[0].contains('/sfc/servlet.shepherd/version/download/'), 'URL should contain download path');
    }

    // ------------------------------------------------------ INPUT VALIDATION

    @isTest
    static void testValidations() {
        System.assertEquals('9876543210', FeedbackController.normaliseMobile('+91 98765-43210'));
        System.assertEquals('9876543210', FeedbackController.normaliseMobile('9876543210'));
        System.assertEquals('', FeedbackController.normaliseMobile(null));
        System.assertEquals('', FeedbackController.normaliseMobile('   '));

        System.assertEquals(true, FeedbackController.isValidMobile('9876543210'));
        System.assertEquals(false, FeedbackController.isValidMobile('12345'));
        System.assertEquals(false, FeedbackController.isValidMobile('1234567890'));
        System.assertEquals(false, FeedbackController.isValidMobile(null));

        System.assertEquals(true, FeedbackController.isValidEmail('test@example.com'));
        System.assertEquals(false, FeedbackController.isValidEmail('invalid_email'));
        System.assertEquals(false, FeedbackController.isValidEmail('a@b'));
        System.assertEquals(false, FeedbackController.isValidEmail(null));
    }

    // -------------------------------------------------------- PROFILE OTP

    @isTest
    static void testSendProfileUpdateOtpSuccess() {
        Account acc = mainAccount();
        Test.setMock(HttpCalloutMock.class, new SmsAcceptedMock());

        Test.startTest();
        FDB_OtpService.SendResult result = FeedbackController.sendProfileUpdateOtp(
            acc.Id, '+91 98765 43211', null, new List<String>{ 'Mobile' });
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);
        System.assertNotEquals(null, result.reference);

        OTP_Verification__c issued = [
            SELECT Destination__c, Purpose__c, Channel__c
            FROM OTP_Verification__c
            WHERE Reference__c = :result.reference
        ];
        System.assertEquals('9876543211', issued.Destination__c, 'The typed number is normalised');
        System.assertEquals('Profile Update', issued.Purpose__c);
        System.assertEquals('SMS', issued.Channel__c);
    }

    @isTest
    static void testSendProfileUpdateOtpInvalidMobile() {
        Account acc = mainAccount();

        Test.startTest();
        try {
            FeedbackController.sendProfileUpdateOtp(
                acc.Id, '123', null, new List<String>{ 'Mobile' });
            System.assert(false, 'Expected a validation error');
        } catch (AuraHandledException e) {
            assertHandled(e, 'valid 10-digit mobile number');
        }
        Test.stopTest();
    }

    @isTest
    static void testSendProfileUpdateOtpInvalidEmail() {
        Account acc = mainAccount();

        Test.startTest();
        try {
            FeedbackController.sendProfileUpdateOtp(
                acc.Id, null, 'not-an-address', new List<String>{ 'Email' });
            System.assert(false, 'Expected a validation error');
        } catch (AuraHandledException e) {
            assertHandled(e, 'valid email address');
        }
        Test.stopTest();
    }

    /** A second send inside the cooldown surfaces as a handled message. */
    @isTest
    static void testSendProfileUpdateOtpThrottled() {
        Account acc = mainAccount();
        Test.setMock(HttpCalloutMock.class, new SmsAcceptedMock());

        Test.startTest();
        FeedbackController.sendProfileUpdateOtp(acc.Id, '9876543211', null, new List<String>{ 'Mobile' });
        try {
            FeedbackController.sendProfileUpdateOtp(acc.Id, '9876543211', null, new List<String>{ 'Mobile' });
            System.assert(false, 'Expected the resend cooldown to bite');
        } catch (AuraHandledException e) {
            assertHandled(e, 'wait a few seconds');
        }
        Test.stopTest();
    }

    // ------------------------------------------------- VERIFY THEN SUBMIT

    @isTest
    static void testVerifyAndSubmitProfileUpdate() {
        Account acc = mainAccount();
        String payload = '[{"fieldName":"Mobile","newValue":"9876543211"}]';

        Test.startTest();
        String requestId = FeedbackController.verifyAndSubmitProfileUpdate(
            acc.Id, null, payload, PENDING_REF, PENDING_CODE);
        Test.stopTest();

        System.assertNotEquals(null, requestId, 'A verified code should raise a request');

        Orient_Customer_Change_Request__c request = [
            SELECT Approval_Status__c, Request_Type__c, Location_Code__c,
                   (SELECT Account_Field_API__c, New_Value__c FROM Orient_Customer_Change_Items__r)
            FROM Orient_Customer_Change_Request__c
            WHERE Id = :requestId
        ];
        System.assertEquals('Pending', request.Approval_Status__c);
        System.assertEquals('Profile Update', request.Request_Type__c);
        System.assertEquals('TS-01', request.Location_Code__c);
        System.assertEquals(1, request.Orient_Customer_Change_Items__r.size());
        System.assertEquals('Phone', request.Orient_Customer_Change_Items__r[0].Account_Field_API__c);
        System.assertEquals('9876543211', request.Orient_Customer_Change_Items__r[0].New_Value__c);

        System.assertEquals(1, [
            SELECT COUNT() FROM Tagged_Approval_Hierarchy__c
            WHERE Customer_Change_Request__c = :requestId
        ]);
    }

    /** A wrong code is not an error - it is simply "no". */
    @isTest
    static void testVerifyAndSubmitProfileUpdateWrongCode() {
        Account acc = mainAccount();
        String payload = '[{"fieldName":"Mobile","newValue":"9876543211"}]';

        Test.startTest();
        String requestId = FeedbackController.verifyAndSubmitProfileUpdate(
            acc.Id, null, payload, PENDING_REF, '999999');
        Test.stopTest();

        System.assertEquals(null, requestId);
        System.assertEquals(0, [SELECT COUNT() FROM Orient_Customer_Change_Request__c]);
    }

    @isTest
    static void testVerifyAndSubmitProfileUpdateUnknownReference() {
        Account acc = mainAccount();

        Test.startTest();
        try {
            FeedbackController.verifyAndSubmitProfileUpdate(
                acc.Id, null, '[]', 'NO_SUCH_REF', PENDING_CODE);
            System.assert(false, 'Expected the missing reference to be reported');
        } catch (AuraHandledException e) {
            assertHandled(e, 'expired');
        }
        Test.stopTest();
    }

    // --------------------------------------------------- DIRECT SUBMISSION

    @isTest
    static void testSubmitProfileUpdateRequestDate() {
        Account acc = mainAccount();
        String payload = '[{"fieldName":"DOB","newValue":"1990-05-20"},'
                       + '{"fieldName":"Email","newValue":" new@test.com "}]';

        Test.startTest();
        String requestId = FeedbackController.submitProfileUpdateRequest(acc.Id, null, payload);
        Test.stopTest();

        System.assertNotEquals(null, requestId);

        Map<String, Orient_Customer_Change_Item__c> byField =
            new Map<String, Orient_Customer_Change_Item__c>();
        for (Orient_Customer_Change_Item__c item : [
            SELECT Account_Field_API__c, New_Value__c, New_Display_Value__c, Old_Display_Value__c
            FROM Orient_Customer_Change_Item__c
            WHERE Change_Request__c = :requestId
        ]) {
            byField.put(item.Account_Field_API__c, item);
        }

        System.assertEquals(2, byField.size());
        System.assertEquals('1990-05-20', byField.get('Date_Of_Birth__c').New_Value__c);
        System.assertEquals(Date.newInstance(1990, 5, 20).format(),
            byField.get('Date_Of_Birth__c').New_Display_Value__c,
            'A date is formatted in the reader\'s locale, not left as the ISO value');
        System.assertEquals(null, byField.get('Date_Of_Birth__c').Old_Display_Value__c,
            'Nothing was on file, and an empty display value is stored as null');
        System.assertEquals('new@test.com', byField.get('Email_Address__c').New_Value__c,
            'The typed address is trimmed');
    }

    @isTest
    static void testSubmitProfileUpdateRequestEmptyPayload() {
        Account acc = mainAccount();

        Test.startTest();
        try {
            FeedbackController.submitProfileUpdateRequest(acc.Id, null, '[]');
            System.assert(false, 'Expected an empty payload to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'No profile changes were selected');
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Orient_Customer_Change_Request__c],
            'A refused request must not reach the approval queue');
    }

    @isTest
    static void testSubmitProfileUpdateRequestUsesVisitStore() {
        Account acc = mainAccount();
        Showroom_Visit__c visit = [SELECT Id FROM Showroom_Visit__c LIMIT 1];
        String payload = '[{"fieldName":"WhatsApp","newValue":"9876543212"}]';

        Test.startTest();
        String requestId = FeedbackController.submitProfileUpdateRequest(acc.Id, visit.Id, payload);
        Test.stopTest();

        Orient_Customer_Change_Request__c request = [
            SELECT Location_Code__c FROM Orient_Customer_Change_Request__c WHERE Id = :requestId
        ];
        System.assertEquals('TS-01', request.Location_Code__c,
            'The visit decides which counter approves it');
    }

    // ------------------------------------------------------ PAYLOAD PARSING

    @isTest
    static void testParseProfilePayloadEmpty() {
        System.assertEquals(0, FeedbackController.parseProfilePayload(null).size());
        System.assertEquals(0, FeedbackController.parseProfilePayload('  ').size());
        System.assertEquals(0, FeedbackController.parseProfilePayload('["not-a-map"]').size(),
            'Entries that are not objects are skipped');
        System.assertEquals(0, FeedbackController.parseProfilePayload(
            '[{"fieldName":"Mobile","newValue":"  "}]').size(),
            'A blank value is nothing to approve');
    }

    @isTest
    static void testParseProfilePayloadMalformed() {
        try {
            FeedbackController.parseProfilePayload('{not json');
            System.assert(false, 'Expected unreadable JSON to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'could not be read');
        }

        try {
            FeedbackController.parseProfilePayload('{"fieldName":"Mobile"}');
            System.assert(false, 'Expected a non-array payload to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'could not be read');
        }
    }

    @isTest
    static void testSubmitProfileUpdateRequestUnknownField() {
        Account acc = mainAccount();

        Test.startTest();
        try {
            FeedbackController.submitProfileUpdateRequest(
                acc.Id, null, '[{"fieldName":"PAN","newValue":"ABCDE1234F"}]');
            System.assert(false, 'Expected a field outside the screen to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'cannot be updated from this screen');
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Orient_Customer_Change_Request__c],
            'A refused request must not reach the approval queue');
    }

    // ------------------------------------------------------ VALUE VALIDATION

    @isTest
    static void testSubmitProfileUpdateRequestInvalidValues() {
        Account acc = mainAccount();

        Test.startTest();
        try {
            FeedbackController.submitProfileUpdateRequest(
                acc.Id, null, '[{"fieldName":"DOB","newValue":"not-a-date"}]');
            System.assert(false, 'Expected an unreadable date to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'valid date');
        }

        try {
            FeedbackController.submitProfileUpdateRequest(
                acc.Id, null, '[{"fieldName":"DOA","newValue":"2099-01-01"}]');
            System.assert(false, 'Expected a future date to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'cannot be in the future');
        }

        try {
            FeedbackController.submitProfileUpdateRequest(
                acc.Id, null, '[{"fieldName":"Email","newValue":"nope"}]');
            System.assert(false, 'Expected an unusable address to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'valid email address');
        }

        try {
            FeedbackController.submitProfileUpdateRequest(
                acc.Id, null, '[{"fieldName":"Mobile","newValue":"12345"}]');
            System.assert(false, 'Expected an unusable number to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'valid 10-digit mobile number');
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Orient_Customer_Change_Request__c],
            'A refused request must not reach the approval queue');
    }

    @isTest
    static void testSubmitProfileUpdateRequestNoActualChange() {
        Account acc = mainAccount();

        Test.startTest();
        try {
            FeedbackController.submitProfileUpdateRequest(
                acc.Id, null, '[{"fieldName":"Mobile","newValue":"9876543210"}]');
            System.assert(false, 'Expected an unchanged value to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'already match what we hold');
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Orient_Customer_Change_Request__c],
            'A refused request must not reach the approval queue');
    }

    @isTest
    static void testSubmitProfileUpdateRequestVerifiedLock() {
        Account acc = mainAccount();
        update new Account(Id = acc.Id, DOB_Verified__c = true);

        Test.startTest();
        try {
            FeedbackController.submitProfileUpdateRequest(
                acc.Id, null, '[{"fieldName":"DOB","newValue":"1990-05-20"}]');
            System.assert(false, 'Expected a verified field to be locked');
        } catch (AuraHandledException e) {
            assertHandled(e, 'already verified');
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Orient_Customer_Change_Request__c],
            'A refused request must not reach the approval queue');
    }

    @isTest
    static void testSubmitProfileUpdateRequestUnknownCustomer() {
        Test.startTest();
        try {
            FeedbackController.submitProfileUpdateRequest(
                '001000000000000AAA', null, '[{"fieldName":"Mobile","newValue":"9876543211"}]');
            System.assert(false, 'Expected a missing customer to be reported');
        } catch (AuraHandledException e) {
            assertHandled(e, 'could not be found');
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Orient_Customer_Change_Request__c],
            'A refused request must not reach the approval queue');
    }



    /*
    @isTest
    static void testSubmitProfileUpdateRequestDuplicateNumber() {
        Account acc = mainAccount();

        Test.startTest();
        try {
            FeedbackController.submitProfileUpdateRequest(
                acc.Id, null, '[{"fieldName":"Mobile","newValue":"9876543299"}]');
            System.assert(false, 'Expected another customer\'s number to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'already registered to another customer');
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Orient_Customer_Change_Request__c],
            'A refused request must not reach the approval queue');
    }
    */

    @isTest
    static void testSubmitProfileUpdateRequestAlreadyPending() {
        Account acc = mainAccount();
        String payload = '[{"fieldName":"Mobile","newValue":"9876543211"}]';

        Test.startTest();
        FeedbackController.submitProfileUpdateRequest(acc.Id, null, payload);
        try {
            FeedbackController.submitProfileUpdateRequest(acc.Id, null, payload);
            System.assert(false, 'Expected the open approval to block a second request');
        } catch (AuraHandledException e) {
            assertHandled(e, 'already waiting for approval');
        }
        Test.stopTest();
    }

    // ------------------------------------------------------------- ROUTING

    @isTest
    static void testGetProfileApprovalHierarchy() {
        System.assertEquals(null, FeedbackController.getProfileApprovalHierarchy(null));

        Store__c store = [SELECT Id FROM Store__c WHERE Store_Code__c = 'TS-01' LIMIT 1];
        System.assertNotEquals(null, FeedbackController.getProfileApprovalHierarchy(store.Id));

        Store__c unmapped = new Store__c(Name='Unmapped Store', Store_Code__c='TS-99');
        insert unmapped;
        System.assertEquals(null, FeedbackController.getProfileApprovalHierarchy(unmapped.Id));
    }

    @isTest
    static void testSubmitProfileUpdateRequestNoStore() {
        Account other = otherAccount();

        Test.startTest();
        System.runAs(unlocatedUser()) {
            try {
                FeedbackController.submitProfileUpdateRequest(
                    other.Id, null, '[{"fieldName":"Email","newValue":"someone@test.com"}]');
                System.assert(false, 'Expected the missing store to be reported');
            } catch (AuraHandledException e) {
                assertHandled(e, 'which store should approve');
            }
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Orient_Customer_Change_Request__c],
            'A refused request must not reach the approval queue');
    }

    @isTest
    static void testSubmitProfileUpdateRequestNoHierarchy() {
        Store__c unmapped = new Store__c(Name='Unmapped Store', Store_Code__c='TS-98');
        insert unmapped;

        Account other = otherAccount();
        update new Account(Id = other.Id, Preferred_Store__c = unmapped.Id);

        Test.startTest();
        System.runAs(unlocatedUser()) {
            try {
                FeedbackController.submitProfileUpdateRequest(
                    other.Id, null, '[{"fieldName":"Email","newValue":"someone@test.com"}]');
                System.assert(false, 'Expected the unconfigured hierarchy to be reported');
            } catch (AuraHandledException e) {
                assertHandled(e, 'not set up correctly for this store');
            }
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Orient_Customer_Change_Request__c],
            'A refused request must not reach the approval queue');
    }

    @isTest
    static void testSubmitProfileUpdateRequestHierarchyWithoutLevels() {
        Store__c bare = new Store__c(Name='Bare Store', Store_Code__c='TS-97');
        insert bare;
        insert new Approval_Hierarchy__c(Type__c='Customer Profile', Store__c=bare.Id);

        Account other = otherAccount();
        update new Account(Id = other.Id, Preferred_Store__c = bare.Id);

        Test.startTest();
        System.runAs(unlocatedUser()) {
            try {
                FeedbackController.submitProfileUpdateRequest(
                    other.Id, null, '[{"fieldName":"Email","newValue":"someone@test.com"}]');
                System.assert(false, 'Expected a hierarchy with no levels to be refused');
            } catch (AuraHandledException e) {
                assertHandled(e, 'not set up correctly for this store');
            }
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Orient_Customer_Change_Request__c],
            'A refused request must not reach the approval queue');
    }

    @isTest
    static void testSubmitProfileUpdateRequestLevelWithoutApprover() {
        Store__c orphan = new Store__c(Name='Orphan Store', Store_Code__c='TS-96');
        insert orphan;

        Approval_Hierarchy__c hierarchy =
            new Approval_Hierarchy__c(Type__c='Customer Profile', Store__c=orphan.Id);
        insert hierarchy;
        insert new Approval_Hierarchy_Level__c(Approval_Hierarchy__c=hierarchy.Id, Sr_No__c=1);

        Account other = otherAccount();
        update new Account(Id = other.Id, Preferred_Store__c = orphan.Id);

        Test.startTest();
        System.runAs(unlocatedUser()) {
            try {
                FeedbackController.submitProfileUpdateRequest(
                    other.Id, null, '[{"fieldName":"Email","newValue":"someone@test.com"}]');
                System.assert(false, 'Expected a level with nobody on it to be refused');
            } catch (AuraHandledException e) {
                assertHandled(e, 'not set up correctly for this store');
            }
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Orient_Customer_Change_Request__c],
            'A refused request must not reach the approval queue');
    }

    @isTest
    static void testSubmitProfileUpdateRequestDuplicateLevelSequence() {
        Store__c clashing = new Store__c(Name='Clashing Store', Store_Code__c='TS-95');
        insert clashing;

        Approval_Hierarchy__c hierarchy =
            new Approval_Hierarchy__c(Type__c='Customer Profile', Store__c=clashing.Id);
        insert hierarchy;

        insert new List<Approval_Hierarchy_Level__c>{
            new Approval_Hierarchy_Level__c(Approval_Hierarchy__c=hierarchy.Id, Sr_No__c=1),
            new Approval_Hierarchy_Level__c(Approval_Hierarchy__c=hierarchy.Id, Sr_No__c=1)
        };

        Account other = otherAccount();
        update new Account(Id = other.Id, Preferred_Store__c = clashing.Id);

        Test.startTest();
        System.runAs(unlocatedUser()) {
            try {
                FeedbackController.submitProfileUpdateRequest(
                    other.Id, null, '[{"fieldName":"Email","newValue":"someone@test.com"}]');
                System.assert(false, 'Expected two levels on one sequence to be refused');
            } catch (AuraHandledException e) {
                assertHandled(e, 'not set up correctly for this store');
            }
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Orient_Customer_Change_Request__c],
            'A refused request must not reach the approval queue');
    }

    // -------------------------------------------------------- INVOICE GATE

    @isTest
    static void testSendInvoiceOtp() {
        Account acc = mainAccount();
        Test.setMock(HttpCalloutMock.class, new SmsAcceptedMock());

        Test.startTest();
        FDB_OtpService.SendResult result = FeedbackController.sendInvoiceOtp(acc.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);

        OTP_Verification__c issued = [
            SELECT Destination__c, Purpose__c FROM OTP_Verification__c
            WHERE Reference__c = :result.reference
        ];
        System.assertEquals('9876543210', issued.Destination__c,
            'The invoice gate always texts the number on file');
        System.assertEquals('Invoice Email', issued.Purpose__c);
    }

    @isTest
    static void testSendInvoiceOtpThrottled() {
        Account acc = mainAccount();
        Test.setMock(HttpCalloutMock.class, new SmsAcceptedMock());

        Test.startTest();
        FeedbackController.sendInvoiceOtp(acc.Id);
        try {
            FeedbackController.sendInvoiceOtp(acc.Id);
            System.assert(false, 'Expected the resend cooldown to bite');
        } catch (AuraHandledException e) {
            assertHandled(e, 'wait a few seconds');
        }
        Test.stopTest();
    }

    @isTest
    static void testSendInvoiceEmailOtp() {
        Account acc = mainAccount();

        Test.startTest();
        FDB_OtpService.SendResult result =
            FeedbackController.sendInvoiceEmailOtp(acc.Id, '  buyer@test.com ');
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);

        OTP_Verification__c issued = [
            SELECT Destination__c, Channel__c, Purpose__c FROM OTP_Verification__c
            WHERE Reference__c = :result.reference
        ];
        System.assertEquals('buyer@test.com', issued.Destination__c);
        System.assertEquals('Email', issued.Channel__c);
        System.assertEquals('Invoice Email Verification', issued.Purpose__c);
    }

    @isTest
    static void testSendInvoiceEmailOtpInvalidAddress() {
        Account acc = mainAccount();

        Test.startTest();
        try {
            FeedbackController.sendInvoiceEmailOtp(acc.Id, 'nope');
            System.assert(false, 'Expected an unusable address to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'valid email address');
        }
        Test.stopTest();
    }

    @isTest
    static void testSendInvoiceEmailOtpThrottled() {
        Account acc = mainAccount();

        Test.startTest();
        FeedbackController.sendInvoiceEmailOtp(acc.Id, 'buyer@test.com');
        try {
            FeedbackController.sendInvoiceEmailOtp(acc.Id, 'buyer@test.com');
            System.assert(false, 'Expected the resend cooldown to bite');
        } catch (AuraHandledException e) {
            assertHandled(e, 'wait a few seconds');
        }
        Test.stopTest();
    }

    @isTest
    static void testVerifyInvoiceOtp() {
        Test.startTest();
        System.assertEquals(false, FeedbackController.verifyInvoiceOtp(PENDING_REF, '999999'));
        System.assertEquals(true, FeedbackController.verifyInvoiceOtp(PENDING_REF, PENDING_CODE));
        Test.stopTest();
    }

    @isTest
    static void testVerifyInvoiceOtpBlankCode() {
        Test.startTest();
        try {
            FeedbackController.verifyInvoiceOtp(PENDING_REF, '');
            System.assert(false, 'Expected a blank code to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'enter the verification code');
        }
        Test.stopTest();
    }

    // ----------------------------------------------------------- INVOICES

    @isTest
    static void testFetchCustomerInvoices() {
        Account acc = mainAccount();
        Test.setMock(HttpCalloutMock.class, new BcInvoiceMock());

        Test.startTest();
        List<FDB_BCInvoiceService.Invoice> invoices = FeedbackController.fetchCustomerInvoices(
            acc.Id, FDB_BCInvoiceService.SELECTION_LATEST, VERIFIED_REF, null, null);
        Test.stopTest();

        System.assertEquals(1, invoices.size());
        System.assertEquals('INV-001', invoices[0].documentNo);
    }

    @isTest
    static void testFetchCustomerInvoicesUnverified() {
        Account acc = mainAccount();

        Test.startTest();
        try {
            FeedbackController.fetchCustomerInvoices(
                acc.Id, FDB_BCInvoiceService.SELECTION_LATEST, 'NO_SUCH_REF', null, null);
            System.assert(false, 'Expected an unverified reference to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'verify your identity');
        }
        Test.stopTest();
    }

    @isTest
    static void testFetchCustomerInvoicesWithoutBillingAccount() {
        Account other = otherAccount();

        Test.startTest();
        try {
            FeedbackController.fetchCustomerInvoices(
                other.Id, FDB_BCInvoiceService.SELECTION_LATEST, VERIFIED_REF, null, null);
            System.assert(false, 'Expected a customer with no BC code to be reported');
        } catch (AuraHandledException e) {
            assertHandled(e, 'No billing account');
        }
        Test.stopTest();
    }

    // --------------------------------------------------- INVOICE COPY CASE

    @isTest
    static void testSendInvoiceEmailRequest() {
        Account acc = mainAccount();
        Showroom_Visit__c visit = [
            SELECT Id FROM Showroom_Visit__c
            WHERE Id IN (SELECT Showroom_Visit__c FROM Feedback__c WHERE Status__c = 'Pending')
            LIMIT 1
        ];

        Test.startTest();
        String outcome = FeedbackController.sendInvoiceEmailRequest(
            acc.Id, visit.Id, 'buyer@test.com', 'Latest', VERIFIED_REF,
            '[{"documentNo":"INV-001"}]');
        Test.stopTest();

        System.assertEquals('Success', outcome);

        Case raised = [SELECT Subject, Priority, Description, AccountId, Feedback__c FROM Case];
        System.assertEquals(acc.Id, raised.AccountId);
        System.assertEquals('Medium', raised.Priority);
        System.assertEquals('Invoice Copy Request - 1 invoice to buyer@test.com', raised.Subject);
        System.assertNotEquals(null, raised.Feedback__c, 'It hangs off the visit\'s feedback');
        System.assert(raised.Description.contains('INV-001'), raised.Description);
    }

    @isTest
    static void testSendInvoiceEmailRequestWithoutVisit() {
        Account acc = mainAccount();

        Test.startTest();
        String outcome = FeedbackController.sendInvoiceEmailRequest(
            acc.Id, null, 'buyer@test.com', 'Last12', VERIFIED_REF, null);
        Test.stopTest();

        System.assertEquals('Success', outcome);

        Case raised = [SELECT Subject, Feedback__c FROM Case];
        System.assertEquals('Invoice Copy Request - 0 invoices to buyer@test.com', raised.Subject);
        System.assertEquals(null, raised.Feedback__c);
    }

    @isTest
    static void testSendInvoiceEmailRequestUnverified() {
        Account acc = mainAccount();

        Test.startTest();
        try {
            FeedbackController.sendInvoiceEmailRequest(
                acc.Id, null, 'buyer@test.com', 'Latest', 'NO_SUCH_REF', '[]');
            System.assert(false, 'Expected an unverified address to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'verify the email address');
        }
        Test.stopTest();
    }

    @isTest
    static void testSendInvoiceEmailRequestWithoutCustomer() {
        Test.startTest();
        try {
            FeedbackController.sendInvoiceEmailRequest(
                null, null, 'buyer@test.com', 'Latest', VERIFIED_REF, '[]');
            System.assert(false, 'Expected a request with no customer to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'which customer this request is for');
        }
        Test.stopTest();
    }

    @isTest
    static void testSendInvoiceEmailRequestUnreadableSelection() {
        Account acc = mainAccount();

        Test.startTest();
        try {
            FeedbackController.sendInvoiceEmailRequest(
                acc.Id, null, 'buyer@test.com', 'Latest', VERIFIED_REF, '{not json');
            System.assert(false, 'Expected an unreadable selection to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, 'could not read which invoices');
        }
        Test.stopTest();
    }

    /** A selection too long for the Description field is cut, not lost. */
    @isTest
    static void testSendInvoiceEmailRequestTruncatesDescription() {
        Account acc = mainAccount();

        String filler = 'x'.repeat(80);
        List<String> rows = new List<String>();
        for (Integer i = 0; i < 500; i++) {
            rows.add('{"documentNo":"INV-' + i + '","note":"' + filler + '"}');
        }
        String selection = '[' + String.join(rows, ',') + ']';

        Test.startTest();
        String outcome = FeedbackController.sendInvoiceEmailRequest(
            acc.Id, null, 'buyer@test.com', 'Last12', VERIFIED_REF, selection);
        Test.stopTest();

        System.assertEquals('Success', outcome);

        Case raised = [SELECT Description FROM Case];
        System.assertEquals(32000, raised.Description.length());
        System.assert(raised.Description.endsWith('allows.]'), 'It says it was cut');
    }

    // ------------------------------------------------------------ FEEDBACK

    @isTest
    static void testUpdateFeedbackToInProgress() {
        Feedback__c pending = [
            SELECT Id, Showroom_Visit__c FROM Feedback__c WHERE Status__c = 'Pending' LIMIT 1
        ];

        Test.startTest();
        String feedbackId = FeedbackController.updateFeedbackToInProgress(pending.Showroom_Visit__c);
        Test.stopTest();

        System.assertEquals(pending.Id, feedbackId);
        System.assertEquals('In Progress',
            [SELECT Status__c FROM Feedback__c WHERE Id = :pending.Id].Status__c);
    }

    @isTest
    static void testUpdateFeedbackToInProgressWithoutVisit() {
        Test.startTest();
        try {
            FeedbackController.updateFeedbackToInProgress(null);
            System.assert(false, 'Expected a null visit to be refused rather than matched');
        } catch (AuraHandledException e) {
            assertHandled(e, 'No showroom visit was supplied');
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateFeedbackToInProgressAlreadyCompleted() {
        Feedback__c done = [
            SELECT Showroom_Visit__c FROM Feedback__c WHERE Status__c = 'Completed' LIMIT 1
        ];

        Test.startTest();
        try {
            FeedbackController.updateFeedbackToInProgress(done.Showroom_Visit__c);
            System.assert(false, 'Expected a completed feedback to stay closed');
        } catch (AuraHandledException e) {
            assertHandled(e, FeedbackController.ALREADY_SUBMITTED);
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateFeedbackToInProgressVisitWithoutFeedback() {
        Set<Id> attached = new Set<Id>();
        for (Feedback__c fb : [SELECT Showroom_Visit__c FROM Feedback__c WHERE Showroom_Visit__c != null]) {
            attached.add(fb.Showroom_Visit__c);
        }
        Showroom_Visit__c orphan = [
            SELECT Id FROM Showroom_Visit__c WHERE Id NOT IN :attached LIMIT 1
        ];

        Test.startTest();
        try {
            FeedbackController.updateFeedbackToInProgress(orphan.Id);
            System.assert(false, 'Expected a visit with no feedback to be reported');
        } catch (AuraHandledException e) {
            assertHandled(e, 'Error reading feedback');
        }
        Test.stopTest();
    }

    @isTest
    static void testSubmitCustomerFeedbackHappy() {
        Account acc = mainAccount();
        Feedback__c fb = freeFeedback(0);

        Map<String, String> answers = new Map<String, String>{
            'q1' => '5', 'q2' => '5', 'q3' => '5', 'q4' => '5', 'q5' => '5'
        };

        Test.startTest();
        String outcome = FeedbackController.submitCustomerFeedback(
            fb.Id, acc.Id, answers, 'Lovely service, thank you', 'BN');
        Test.stopTest();

        System.assertEquals('Success', outcome);

        Feedback__c saved = [
            SELECT Status__c, Language__c, Submitted_Channel__c, Average_Score__c,
                   Case_Created__c, Comments__c
            FROM Feedback__c WHERE Id = :fb.Id
        ];
        System.assertEquals('Completed', saved.Status__c);
        System.assertEquals('Bengali', saved.Language__c);
        System.assertEquals('Store Device', saved.Submitted_Channel__c);
        System.assertEquals(5.00, saved.Average_Score__c, 'Five fives on 100% of weighting');
        System.assertEquals(false, saved.Case_Created__c);
        System.assertEquals(0, [SELECT COUNT() FROM Case]);
    }

    @isTest
    static void testSubmitCustomerFeedbackRaisesCriticalCase() {
        Account acc = mainAccount();
        Feedback__c fb = freeFeedback(0);

        Map<String, String> answers = new Map<String, String>{
            'q1' => '1', 'q2' => '2', 'q3' => '3', 'q4' => '4', 'q5' => '5'
        };

        Test.startTest();
        FeedbackController.submitCustomerFeedback(
            fb.Id, acc.Id, answers, 'The staff were rude and the wait was too long', 'EN');
        Test.stopTest();

        Feedback__c saved = [
            SELECT Language__c, Case_Created__c, Average_Score__c
            FROM Feedback__c WHERE Id = :fb.Id
        ];
        System.assertEquals('English', saved.Language__c);
        System.assertEquals(true, saved.Case_Created__c);
        System.assertEquals(3.00, saved.Average_Score__c);

        Case raised = [SELECT Priority, Subject, Description, Feedback__c FROM Case];
        System.assertEquals('Critical', raised.Priority, 'One star outranks everything else');
        System.assertEquals(fb.Id, raised.Feedback__c);
        System.assert(raised.Subject.contains('Overall experience'), raised.Subject);
        System.assert(raised.Description.contains('2 stars on "Staff"'), raised.Description);
        System.assert(raised.Description.contains('3 stars on "Clarity of information"'),
            raised.Description);
        System.assert(raised.Description.contains('Serious negative comment'), raised.Description);
    }

    @isTest
    static void testSubmitCustomerFeedbackNotApplicableAndLowScores() {
        Account acc = mainAccount();
        Feedback__c fb = freeFeedback(0);

        Map<String, String> answers = new Map<String, String>{
            'q1' => '4', 'q2' => '4', 'q3' => 'N.A.', 'q4' => '2', 'q5' => '2'
        };

        Test.startTest();
        FeedbackController.submitCustomerFeedback(
            fb.Id, acc.Id, answers, 'Bad experience overall', 'EN');
        Test.stopTest();

        Feedback__c saved = [
            SELECT Average_Score__c, Case_Created__c FROM Feedback__c WHERE Id = :fb.Id
        ];
        // N.A. carries its 20% onto the first question: (40*4 + 20*4 + 20*2 + 20*2)/100
        System.assertEquals(3.20, saved.Average_Score__c);
        System.assertEquals(true, saved.Case_Created__c);

        Case raised = [SELECT Priority, Description FROM Case];
        System.assertEquals('High', raised.Priority);
        System.assert(raised.Description.contains('Visit purpose not fulfilled'), raised.Description);
        System.assert(raised.Description.contains('Customer retention concern'), raised.Description);
        System.assert(!raised.Description.contains('Clarity of information'),
            'N.A. is not a rating, so it triggers nothing');
    }

    @isTest
    static void testSubmitCustomerFeedbackUnanswered() {
        Account acc = mainAccount();
        Feedback__c fb = freeFeedback(0);

        Test.startTest();
        FeedbackController.submitCustomerFeedback(
            fb.Id, acc.Id, new Map<String, String>(), null, 'EN');
        Test.stopTest();

        Feedback__c saved = [
            SELECT Average_Score__c, Case_Created__c FROM Feedback__c WHERE Id = :fb.Id
        ];
        System.assertEquals(0, saved.Average_Score__c, 'Nothing rated scores nothing');
        System.assertEquals(false, saved.Case_Created__c);
        System.assertEquals(0, [SELECT COUNT() FROM Case]);
    }

    @isTest
    static void testSubmitCustomerFeedbackAlreadySubmitted() {
        Account acc = mainAccount();
        Feedback__c done = [SELECT Id FROM Feedback__c WHERE Status__c = 'Completed' LIMIT 1];

        Test.startTest();
        try {
            FeedbackController.submitCustomerFeedback(
                done.Id, acc.Id, new Map<String, String>{ 'q1' => '5' }, null, 'EN');
            System.assert(false, 'Expected a second submission to be refused');
        } catch (AuraHandledException e) {
            assertHandled(e, FeedbackController.ALREADY_SUBMITTED);
        }
        Test.stopTest();
    }

    @isTest
    static void testSubmitCustomerFeedbackUnknownRecord() {
        Account acc = mainAccount();

        Test.startTest();
        try {
            FeedbackController.submitCustomerFeedback(
                null, acc.Id, new Map<String, String>{ 'q1' => '5' }, null, 'EN');
            System.assert(false, 'Expected a missing feedback record to be reported');
        } catch (AuraHandledException e) {
            assertHandled(e, 'Error reading feedback record');
        }
        Test.stopTest();
    }

    // ------------------------------------------------------------- SCORING

    @isTest
    static void testStarsAndScoreHelpers() {
        System.assertEquals(null, FeedbackController.starsOf(null));
        System.assertEquals(null, FeedbackController.starsOf('N.A.'));
        System.assertEquals(3, FeedbackController.starsOf('3'));

        System.assertEquals(true, FeedbackController.isLowScore('1'));
        System.assertEquals(true, FeedbackController.isLowScore('2'));
        System.assertEquals(false, FeedbackController.isLowScore('3'));
        System.assertEquals(false, FeedbackController.isLowScore('N.A.'));
    }

    @isTest
    static void testCommentScreening() {
        System.assertEquals(false, FeedbackController.isNegativeComment(null));
        System.assertEquals(false, FeedbackController.isNegativeComment('Everything was lovely'));
        System.assertEquals(true, FeedbackController.isNegativeComment('The wait was too long'));
        System.assertEquals(true, FeedbackController.isNegativeComment('Staff were RUDE'),
            'Serious terms count as negative too');

        System.assertEquals(false, FeedbackController.isSeriouslyNegativeComment('slow service'));
        System.assertEquals(true, FeedbackController.isSeriouslyNegativeComment('This was a scam'));
    }

    @isTest
    static void testWeightedScoreIgnoresUnratedQuestions() {
        Feedback__c fb = new Feedback__c(
            Overall_Rating__c = '4',
            Staff_Rating__c = '4',
            Clarity_Rating__c = '4',
            Purpose_Fulfilled__c = '4',
            Visit_Or_Recommend_Again__c = '4'
        );

        Test.startTest();
        Decimal score = FeedbackController.weightedScore(fb);
        Test.stopTest();

        System.assertEquals(4.00, score,
            'The comments question carries a weighting but no answer, so it takes no part');
    }
}