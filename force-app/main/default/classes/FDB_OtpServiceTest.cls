@isTest
private class FDB_OtpServiceTest {

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

    /** HTTP 200 with a body the gateway uses to say no. */
    private class SmsRejectedMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/plain');
            res.setBody('error|invalid template id');
            res.setStatusCode(200);
            return res;
        }
    }

    @testSetup
    static void setup() {
        insert new List<Account>{
            new Account(
                Name = 'Test Customer',
                Phone = '9876543210',
                Email_Address__c = 'test@example.com'
            ),
            // Nothing to send to, on either channel.
            new Account(Name = 'Contactless Customer')
        };
    }

    private static Account contactable() {
        return [SELECT Id FROM Account WHERE Name = 'Test Customer' LIMIT 1];
    }

    private static Account contactless() {
        return [SELECT Id FROM Account WHERE Name = 'Contactless Customer' LIMIT 1];
    }

    private static OTP_Verification__c pendingOtp(Id accountId, String reference, String code) {
        return new OTP_Verification__c(
            Customer__c = accountId,
            Reference__c = reference,
            Code_Hash__c = FDB_OtpService.hash(code, reference),
            Destination__c = '9876543210',
            Channel__c = 'SMS',
            Purpose__c = 'Profile Update',
            Status__c = 'Pending',
            Expires_At__c = System.now().addSeconds(600),
            Attempts__c = 0
        );
    }

    // ---------------------------------------------------------------- SENDING

    @isTest
    static void testSendSms() {
        Account acc = contactable();
        Test.setMock(HttpCalloutMock.class, new SmsAcceptedMock());

        Test.startTest();
        FDB_OtpService.SendResult result = FDB_OtpService.send(
            acc.Id, 'Profile Update', new List<String>{ 'Mobile' }, '9876543211', null);
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);
        System.assertNotEquals(null, result.reference);
        System.assertEquals('+91 98XXXXXX11', result.maskedDestination);
        System.assertEquals(FDB_OtpService.VALIDITY_SECONDS, result.validitySeconds);

        OTP_Verification__c issued = [
            SELECT Channel__c, Status__c, Destination__c, Template__c,
                   Provider_Message_Id__c, Attempts__c
            FROM OTP_Verification__c WHERE Reference__c = :result.reference
        ];
        System.assertEquals('SMS', issued.Channel__c);
        System.assertEquals('Pending', issued.Status__c);
        System.assertEquals('9876543211', issued.Destination__c);
        System.assertEquals('Mobile_Update', issued.Template__c);
        System.assertEquals('273524927', issued.Provider_Message_Id__c);
        System.assertEquals(0, issued.Attempts__c);
    }

    /** Nothing typed on the screen means the number already on the record. */
    @isTest
    static void testSendSmsFallsBackToNumberOnFile() {
        Account acc = contactable();
        Test.setMock(HttpCalloutMock.class, new SmsAcceptedMock());

        Test.startTest();
        FDB_OtpService.SendResult result = FDB_OtpService.send(
            acc.Id, 'Invoice Email', new List<String>{ 'InvoiceRequest' }, null, null);
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);
        System.assertEquals('9876543210',
            [SELECT Destination__c FROM OTP_Verification__c
             WHERE Reference__c = :result.reference].Destination__c);
    }

    @isTest
    static void testSendEmail() {
        Account acc = contactable();

        Test.startTest();
        FDB_OtpService.SendResult result = FDB_OtpService.send(
            acc.Id, 'Invoice Email Verification',
            new List<String>{ 'InvoiceEmail' }, null, 'newemail@example.com');
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);
        System.assertEquals('n****l@example.com', result.maskedDestination);

        OTP_Verification__c issued = [
            SELECT Channel__c, Status__c, Destination__c, Template__c, Provider_Response__c
            FROM OTP_Verification__c WHERE Reference__c = :result.reference
        ];
        System.assertEquals('Email', issued.Channel__c);
        System.assertEquals('Pending', issued.Status__c);
        System.assertEquals('newemail@example.com', issued.Destination__c);
        System.assertEquals('Invoice_Email_Verification', issued.Template__c);
        System.assert(issued.Provider_Response__c.contains('Queued for delivery'),
            issued.Provider_Response__c);
    }

    /** Two matching templates: the lower Priority__c wins. */
    @isTest
    static void testSendPicksLowestPriorityTemplate() {
        Account acc = contactable();

        Test.startTest();
        FDB_OtpService.SendResult result = FDB_OtpService.send(
            acc.Id, 'Profile Update',
            new List<String>{ 'Email', 'InvoiceEmail' }, null, 'newemail@example.com');
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);

        List<SMS_Template__mdt> candidates = [
            SELECT DeveloperName, Priority__c
            FROM SMS_Template__mdt
            WHERE Is_Active__c = true AND Profile_Field__c IN ('Email', 'InvoiceEmail')
            ORDER BY Priority__c ASC NULLS LAST
        ];
        System.assertEquals(candidates[0].DeveloperName,
            [SELECT Template__c FROM OTP_Verification__c
             WHERE Reference__c = :result.reference].Template__c);
    }

    /** A gateway that says no is still written down, so the failure is auditable. */
    @isTest
    static void testSendSmsRejectedByGateway() {
        Account acc = contactable();
        Test.setMock(HttpCalloutMock.class, new SmsRejectedMock());

        Test.startTest();
        FDB_OtpService.SendResult result = FDB_OtpService.send(
            acc.Id, 'Profile Update', new List<String>{ 'Mobile' }, '9876543211', null);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.message.contains('could not send the verification code'), result.message);
        System.assertEquals(null, result.reference, 'A failed send hands back no reference');

        OTP_Verification__c issued = [
            SELECT Status__c, Provider_Response__c FROM OTP_Verification__c
        ];
        System.assertEquals('Failed', issued.Status__c);
        System.assert(issued.Provider_Response__c.contains('rejected'), issued.Provider_Response__c);
    }

    @isTest
    static void testSendWithNothingToSendTo() {
        Account acc = contactless();

        Test.startTest();
        FDB_OtpService.SendResult sms = FDB_OtpService.send(
            acc.Id, 'Profile Update', new List<String>{ 'Mobile' }, null, null);
        FDB_OtpService.SendResult email = FDB_OtpService.send(
            acc.Id, 'Invoice Email Verification', new List<String>{ 'InvoiceEmail' }, null, null);
        Test.stopTest();

        System.assertEquals(false, sms.success);
        System.assertEquals('No mobile number is on file for this customer.', sms.message);
        System.assertEquals(false, email.success);
        System.assertEquals('No email address is on file for this customer.', email.message);
        System.assertEquals(0, [SELECT COUNT() FROM OTP_Verification__c],
            'Nothing was sent, so there is nothing to record');
    }

    @isTest
    static void testSendToUnknownCustomer() {
        Test.startTest();
        try {
            FDB_OtpService.send(
                '001000000000000AAA', 'Profile Update', new List<String>{ 'Mobile' }, null, null);
            System.assert(false, 'Expected a missing customer to be reported');
        } catch (FDB_OtpService.OtpException e) {
            System.assert(e.getMessage().contains('Customer record not found'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testThrottling() {
        Account acc = contactable();
        insert pendingOtp(acc.Id, 'REF123', '123456');

        Test.startTest();
        try {
            FDB_OtpService.send(acc.Id, 'Profile Update', new List<String>{ 'Mobile' }, '9876543210', null);
            System.assert(false, 'Expected the resend cooldown to bite');
        } catch (FDB_OtpService.OtpException e) {
            System.assert(e.getMessage().contains('wait a few seconds'), e.getMessage());
        }
        Test.stopTest();
    }

    /** The cooldown counts per purpose, so two flows do not block each other. */
    @isTest
    static void testThrottlingIsPerPurpose() {
        Account acc = contactable();
        insert pendingOtp(acc.Id, 'REF124', '123456');

        Test.startTest();
        FDB_OtpService.SendResult result = FDB_OtpService.send(
            acc.Id, 'Invoice Email Verification',
            new List<String>{ 'InvoiceEmail' }, null, 'other@example.com');
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);
    }

    // ----------------------------------------------------------- VERIFYING

    @isTest
    static void testVerifySuccess() {
        Account acc = contactable();
        String ref = 'REF_TEST';
        insert pendingOtp(acc.Id, ref, '123456');

        Test.startTest();
        Boolean isSuccess = FDB_OtpService.verify(ref, ' 123456 ');
        Test.stopTest();

        System.assertEquals(true, isSuccess, 'A padded code is trimmed before hashing');
        System.assertEquals(true, FDB_OtpService.isVerified(ref));
        System.assertEquals('Verified',
            [SELECT Status__c FROM OTP_Verification__c WHERE Reference__c = :ref].Status__c);
    }

    @isTest
    static void testVerifyWrongCode() {
        Account acc = contactable();
        String ref = 'REF_TEST2';
        OTP_Verification__c otp = pendingOtp(acc.Id, ref, '123456');
        insert otp;

        Test.startTest();
        Boolean isSuccess = FDB_OtpService.verify(ref, '654321');
        Test.stopTest();

        System.assertEquals(false, isSuccess);
        System.assertEquals(false, FDB_OtpService.isVerified(ref));

        OTP_Verification__c after = [
            SELECT Attempts__c, Status__c FROM OTP_Verification__c WHERE Id = :otp.Id
        ];
        System.assertEquals(1, after.Attempts__c);
        System.assertEquals('Pending', after.Status__c, 'One wrong guess does not close it');
    }

    /** The guess that uses up the last attempt closes the code for good. */
    @isTest
    static void testVerifyWrongCodeOnLastAttempt() {
        Account acc = contactable();
        String ref = 'REF_TEST6';
        OTP_Verification__c otp = pendingOtp(acc.Id, ref, '123456');
        otp.Attempts__c = FDB_OtpService.MAX_ATTEMPTS - 1;
        insert otp;

        Test.startTest();
        Boolean isSuccess = FDB_OtpService.verify(ref, '654321');
        Test.stopTest();

        System.assertEquals(false, isSuccess);

        OTP_Verification__c after = [
            SELECT Attempts__c, Status__c FROM OTP_Verification__c WHERE Id = :otp.Id
        ];
        System.assertEquals(FDB_OtpService.MAX_ATTEMPTS, after.Attempts__c);
        System.assertEquals('Failed', after.Status__c);
    }

    @isTest
    static void testVerifyExpired() {
        Account acc = contactable();
        String ref = 'REF_TEST3';
        OTP_Verification__c otp = pendingOtp(acc.Id, ref, '123456');
        otp.Expires_At__c = System.now().addSeconds(-10);
        insert otp;

        Test.startTest();
        try {
            FDB_OtpService.verify(ref, '123456');
            System.assert(false, 'Expected an expired code to be refused');
        } catch (FDB_OtpService.OtpException e) {
            System.assert(e.getMessage().contains('expired'), e.getMessage());
        }
        Test.stopTest();

        System.assertEquals('Expired',
            [SELECT Status__c FROM OTP_Verification__c WHERE Id = :otp.Id].Status__c);
    }

    @isTest
    static void testVerifyMaxAttempts() {
        Account acc = contactable();
        String ref = 'REF_TEST4';
        OTP_Verification__c otp = pendingOtp(acc.Id, ref, '123456');
        otp.Attempts__c = FDB_OtpService.MAX_ATTEMPTS;
        insert otp;

        Test.startTest();
        try {
            FDB_OtpService.verify(ref, '123456');
            System.assert(false, 'Expected a burnt-out code to be refused');
        } catch (FDB_OtpService.OtpException e) {
            System.assert(e.getMessage().contains('Too many incorrect attempts'), e.getMessage());
        }
        Test.stopTest();

        System.assertEquals('Failed',
            [SELECT Status__c FROM OTP_Verification__c WHERE Id = :otp.Id].Status__c);
    }

    @isTest
    static void testVerifyAlreadyUsed() {
        Account acc = contactable();
        String ref = 'REF_TEST5';
        OTP_Verification__c otp = pendingOtp(acc.Id, ref, '123456');
        otp.Status__c = 'Verified';
        insert otp;

        Test.startTest();
        try {
            FDB_OtpService.verify(ref, '123456');
            System.assert(false, 'Expected a consumed code to be refused');
        } catch (FDB_OtpService.OtpException e) {
            System.assert(e.getMessage().contains('already been used'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testVerifyBlankInput() {
        Test.startTest();
        try {
            FDB_OtpService.verify(null, '123456');
            System.assert(false, 'Expected a missing reference to be refused');
        } catch (FDB_OtpService.OtpException e) {
            System.assert(e.getMessage().contains('enter the verification code'), e.getMessage());
        }

        try {
            FDB_OtpService.verify('REF_TEST', '  ');
            System.assert(false, 'Expected a missing code to be refused');
        } catch (FDB_OtpService.OtpException e) {
            System.assert(e.getMessage().contains('enter the verification code'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testVerifyUnknownReference() {
        Test.startTest();
        try {
            FDB_OtpService.verify('NO_SUCH_REF', '123456');
            System.assert(false, 'Expected an unknown reference to be refused');
        } catch (FDB_OtpService.OtpException e) {
            System.assert(e.getMessage().contains('expired'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testIsVerified() {
        System.assertEquals(false, FDB_OtpService.isVerified(null));
        System.assertEquals(false, FDB_OtpService.isVerified('  '));
        System.assertEquals(false, FDB_OtpService.isVerified('NO_SUCH_REF'));
    }

    // ------------------------------------------------------------- HELPERS

    @isTest
    static void testHelpers() {
        String code = FDB_OtpService.generateCode();
        System.assertNotEquals(null, code);
        System.assertEquals(6, code.length());
        System.assert(code.isNumeric(), code);
        System.assert(Integer.valueOf(code) >= 100000, 'Never starts with a zero');

        System.assertEquals(10, FDB_OtpService.validityMinutes());

        System.assertEquals('your email address', FDB_OtpService.maskEmail(null));
        System.assertEquals('your email address', FDB_OtpService.maskEmail('no-at-sign'));
        System.assertEquals('t****t@example.com', FDB_OtpService.maskEmail('test@example.com'));
        System.assertEquals('****@example.com', FDB_OtpService.maskEmail('ab@example.com'));

        System.assertEquals('your registered number', FDB_OtpService.maskMobile(null));
        System.assertEquals('your registered number', FDB_OtpService.maskMobile('123'));
        System.assertEquals('+91 98XXXXXX10', FDB_OtpService.maskMobile('9876543210'));
        System.assertEquals('+91 98XXXXXX10', FDB_OtpService.maskMobile('+91 98765-43210'));
    }

    @isTest
    static void testBuildMessage() {
        SMS_Template__mdt template = [
            SELECT Message__c FROM SMS_Template__mdt
            WHERE DeveloperName = 'Mobile_Update' LIMIT 1
        ];

        String built = FDB_OtpService.buildMessage(template, '123456', '9876543210');

        System.assert(built.contains('123456'), built);
        System.assert(!built.contains('{code}'), built);
        System.assert(!built.contains('{minutes}'), built);
        System.assert(!built.contains('{destination}'), built);

        System.assert(!FDB_OtpService.buildMessage(template, '123456', null).contains('{destination}'),
            'A null destination leaves the slot empty rather than the word "null"');
    }

    @isTest
    static void testResolveTemplate() {
        SMS_Template__mdt fallback = FDB_OtpService.resolveTemplate(null);
        System.assertEquals(true, fallback.Is_Default__c,
            'No changed fields falls back to the default template');

        SMS_Template__mdt email = FDB_OtpService.resolveTemplate(new List<String>{ 'Email' });
        System.assertEquals('Email', email.Channel__c);

        SMS_Template__mdt unknown = FDB_OtpService.resolveTemplate(new List<String>{ 'NotAField' });
        System.assertEquals(fallback.DeveloperName, unknown.DeveloperName,
            'An unmatched field falls back too');
    }
}