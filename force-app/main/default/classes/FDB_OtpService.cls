/**
 * One-time passcode issue and verification, backed by OTP_Verification__c.
 *
 * The plain code is never stored - only a SHA-256 of the code salted with the
 * record's reference, so a person with read access to the object still cannot
 * complete somebody else's verification.
 */
public with sharing class FDB_OtpService {

    /**
     * How long a code stays usable. The SMS quotes this back to the customer
     * through the second DLT variable, so the two can never drift apart.
     * Prefer whole minutes - validityMinutes() rounds up otherwise.
     */
    public static final Integer VALIDITY_SECONDS = 600;
    public static final Integer MAX_ATTEMPTS = 5;

    /** Wall-clock gap enforced between two sends to the same destination. */
    public static final Integer RESEND_COOLDOWN_SECONDS = 30;

    public class OtpException extends Exception {}

    public class SendResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String reference;
        @AuraEnabled public String maskedDestination;
        @AuraEnabled public Integer validitySeconds;
    }

    /**
     * Issues a code and delivers it on whichever channel the chosen template
     * uses. A request to change the email address is verified by email; every
     * other change is verified by SMS.
     *
     * Any callout happens before DML - Salesforce forbids a callout once there
     * is uncommitted work in the transaction.
     *
     * @param changedFields the profile fields this request is changing, which
     *                      decide the template. Empty falls back to the
     *                      template flagged as default.
     * @param newMobile     the mobile typed on the profile screen, or blank
     * @param newEmail      the email typed on the profile screen, or blank
     */
    public static SendResult send(Id accountId, String purpose, List<String> changedFields,
                                  String newMobile, String newEmail) {
        SendResult result = new SendResult();
        result.validitySeconds = VALIDITY_SECONDS;

        SMS_Template__mdt template = resolveTemplate(changedFields);
        Boolean isEmail = 'Email'.equalsIgnoreCase(template.Channel__c);

        // The code proves the customer holds the destination they are claiming,
        // so a newly typed one always wins over what is already on the record.
        String destination = isEmail ? newEmail : newMobile;
        if (String.isBlank(destination)) {
            destination = onFile(accountId, isEmail);
        }

        if (String.isBlank(destination)) {
            result.success = false;
            result.message = isEmail
                ? 'No email address is on file for this customer.'
                : 'No mobile number is on file for this customer.';
            return result;
        }

        assertNotThrottled(accountId, purpose);

        String code = generateCode();
        String reference = generateReference();

        Delivery sent = isEmail
            ? deliverEmail(destination, template, code)
            : deliverSms(destination, template, code);

        // Record the attempt either way, so a failed send is auditable
        OTP_Verification__c otp = new OTP_Verification__c(
            Customer__c = accountId,
            Reference__c = reference,
            Code_Hash__c = hash(code, reference),
            Destination__c = destination,
            Channel__c = isEmail ? 'Email' : 'SMS',
            Purpose__c = purpose,
            Template__c = template.DeveloperName,
            Status__c = sent.success ? 'Pending' : 'Failed',
            Expires_At__c = System.now().addSeconds(VALIDITY_SECONDS),
            Attempts__c = 0,
            Provider_Message_Id__c = sent.messageId,
            Provider_Response__c = sent.response
        );

        insert otp;

        if (!sent.success) {
            result.success = false;
            result.message = 'We could not send the verification code. Please try again or ask our showroom team for help.';
            return result;
        }

        result.success = true;
        result.reference = reference;
        result.maskedDestination = isEmail ? maskEmail(destination) : maskMobile(destination);
        result.message = 'A verification code has been sent to ' + result.maskedDestination + '.';
        return result;
    }

    /**
     * Checks a code against its reference and consumes it on success.
     *
     * @return true only for a live, unconsumed code that matches
     */
    public static Boolean verify(String reference, String code) {
        if (String.isBlank(reference) || String.isBlank(code)) {
            throw new OtpException('Please enter the verification code.');
        }

        List<OTP_Verification__c> found = [
            SELECT Id, Code_Hash__c, Expires_At__c, Attempts__c, Status__c
            FROM OTP_Verification__c
            WHERE Reference__c = :reference
            LIMIT 1
            FOR UPDATE
        ];

        if (found.isEmpty()) {
            throw new OtpException('This verification has expired. Please request a new code.');
        }

        OTP_Verification__c otp = found[0];

        if (otp.Status__c == 'Verified') {
            throw new OtpException('This code has already been used. Please request a new one.');
        }

        if (otp.Expires_At__c < System.now()) {
            otp.Status__c = 'Expired';
            update otp;
            throw new OtpException('This code has expired. Please request a new one.');
        }

        if (otp.Attempts__c >= MAX_ATTEMPTS) {
            otp.Status__c = 'Failed';
            update otp;
            throw new OtpException('Too many incorrect attempts. Please request a new code.');
        }

        otp.Attempts__c = otp.Attempts__c + 1;

        if (hash(code.trim(), reference) != otp.Code_Hash__c) {
            if (otp.Attempts__c >= MAX_ATTEMPTS) {
                otp.Status__c = 'Failed';
            }
            update otp;
            return false;
        }

        otp.Status__c = 'Verified';
        update otp;
        return true;
    }

    /** True when this reference has been verified and not yet acted upon. */
    public static Boolean isVerified(String reference) {
        if (String.isBlank(reference)) return false;
        return [
            SELECT COUNT()
            FROM OTP_Verification__c
            WHERE Reference__c = :reference AND Status__c = 'Verified'
        ] == 1;
    }

    // ----------------------------------------------------------------- DELIVERY

    /** What the audit trail needs from a send, whichever channel carried it. */
    private class Delivery {
        Boolean success = false;
        String messageId;
        String response;
    }

    private static Delivery deliverSms(String mobile, SMS_Template__mdt template, String code) {
        FDB_ShreeSmsGateway.GatewayResult sent = FDB_ShreeSmsGateway.send(
            mobile, buildMessage(template, code, mobile),
            template.Template_Id__c, template.Sender_Id__c);

        Delivery d = new Delivery();
        d.success = sent.success;
        d.messageId = sent.messageId;
        d.response = String.isNotBlank(sent.errorMessage) ? sent.errorMessage : sent.rawResponse;
        return d;
    }

    /**
     * Sends the code from the Org-Wide Email Address named by the
     * OTP_Email_From_Address label.
     *
     * The label holds the address rather than the record id because org-wide
     * addresses get different ids in every org, so an id would survive neither
     * a sandbox refresh nor the move to production.
     *
     * setSaveAsActivity(false) keeps a verification code out of the customer's
     * activity timeline, where anyone with read access to the account could
     * read it back.
     */
    private static Delivery deliverEmail(String address, SMS_Template__mdt template, String code) {
        Delivery d = new Delivery();

        String fromAddress = emailFromAddress();
        List<OrgWideEmailAddress> owa = [
            SELECT Id FROM OrgWideEmailAddress WHERE Address = :fromAddress LIMIT 1
        ];
        if (owa.isEmpty()) {
            throw new OtpException(
                'The OTP sender address "' + fromAddress + '" is not set up as an Org-Wide Email '
                + 'Address in this org. Ask an administrator to add and verify it.');
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ address });
        mail.setOrgWideEmailAddressId(owa[0].Id);
        mail.setSubject(String.isNotBlank(template.Subject__c)
            ? template.Subject__c
            : 'Your verification code');
        mail.setPlainTextBody(buildMessage(template, code, address));
        mail.setSaveAsActivity(false);

        try {
            Long startTime = System.now().getTime();
            List<Messaging.SendEmailResult> results =
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail }, false);

            if (results[0].isSuccess()) {
                d.success = true;
                d.response = 'Queued for delivery to ' + address;
            } else {
                d.response = results[0].getErrors()[0].getMessage();
            }
        } catch (Exception e) {
            d.response = 'Email send failed: ' + e.getMessage();
        }
        return d;
    }

    /** Custom Labels throw if undefined in some contexts, so read defensively. */
    private static String emailFromAddress() {
        try {
            String value = System.Label.OTP_Email_From_Address;
            return value == null ? '' : value.trim();
        } catch (Exception e) {
            return '';
        }
    }

    /** The destination already on the customer record, for the given channel. */
    private static String onFile(Id accountId, Boolean isEmail) {
        if (accountId == null) return '';
        List<Account> accounts = [
            SELECT Phone, Email_Address__c FROM Account WHERE Id = :accountId LIMIT 1
        ];
        if (accounts.isEmpty()) {
            throw new OtpException('Customer record not found.');
        }
        return isEmail ? accounts[0].Email_Address__c : accounts[0].Phone;
    }

    // ------------------------------------------------------------------ HELPERS

    /**
     * Picks the DLT template for this request.
     *
     * DLT registers one template per kind of change, so a request that touches
     * the mobile number cannot borrow the date-of-birth wording. When somebody
     * changes several fields at once there is no message that honestly covers
     * all of them, so the lowest Priority__c wins - mobile first, because it is
     * the field that decides where every future code goes.
     *
     * Which field maps to which template lives in SMS_Template__mdt rather than
     * here, so registering the next approved template is an admin job.
     *
     * Read with SOQL, not getAll(): getAll() never returns long text area
     * fields, so Message__c would come back null and every send would fail.
     * SOQL against a custom metadata type is exempt from the query governor
     * limits, so there is nothing to save by caching this.
     */
    @TestVisible
    private static SMS_Template__mdt resolveTemplate(List<String> changedFields) {
        List<String> fields = changedFields == null ? new List<String>() : changedFields;

        SMS_Template__mdt best;
        SMS_Template__mdt fallback;

        List<SMS_Template__mdt> active = [
            SELECT DeveloperName, Template_Id__c, Message__c, Profile_Field__c,
                   Priority__c, Sender_Id__c, Is_Default__c, Channel__c, Subject__c
            FROM SMS_Template__mdt
            WHERE Is_Active__c = true
        ];

        for (SMS_Template__mdt t : active) {
            if (t.Is_Default__c == true) {
                fallback = t;
            }

            if (String.isBlank(t.Profile_Field__c) || !fields.contains(t.Profile_Field__c)) {
                continue;
            }
            if (best == null || priorityOf(t) < priorityOf(best)) {
                best = t;
            }
        }

        SMS_Template__mdt chosen = best != null ? best : fallback;

        if (chosen == null || String.isBlank(chosen.Message__c)) {
            throw new OtpException(
                'No message template is configured for this request. Ask an administrator to '
                + 'check the SMS Template custom metadata records.');
        }

        // DLT governs SMS only, so an email template has no template id and an
        // SMS one is useless without it.
        if (!'Email'.equalsIgnoreCase(chosen.Channel__c) && String.isBlank(chosen.Template_Id__c)) {
            throw new OtpException(
                'The "' + chosen.DeveloperName + '" template has no DLT Template ID, so it cannot '
                + 'be sent by SMS. Ask an administrator to check it.');
        }
        return chosen;
    }

    /** Unset priority sorts last, so a half-filled record cannot outrank a complete one. */
    private static Decimal priorityOf(SMS_Template__mdt t) {
        return t.Priority__c == null ? 9999 : t.Priority__c;
    }

    /**
     * Fills the variable slots in the approved text.
     *
     * Everything except {code}, {destination} and {minutes} has to survive byte
     * for byte - the telco drops any message that does not match its
     * registration - which is why the text is stored beside its template id
     * rather than written here.
     *
     * {destination} is the address or number the code is going to. Templates
     * that read it back to the customer ("Email Address being verified: ...")
     * use it; the rest simply have no such slot and are unaffected.
     *
     * Plain replacement rather than String.format: format treats a single quote
     * as an escape character, so an apostrophe anywhere in an approved text
     * would silently mangle the message.
     */
    @TestVisible
    private static String buildMessage(SMS_Template__mdt template, String code, String destination) {
        return template.Message__c
            .replace('{code}', code)
            .replace('{destination}', destination == null ? '' : destination)
            .replace('{minutes}', String.valueOf(validityMinutes()));
    }

    /**
     * Whole minutes for the second template variable. Rounds up, so the SMS
     * never promises less time than the code actually has.
     */
    @TestVisible
    private static Integer validityMinutes() {
        return Math.ceil(VALIDITY_SECONDS / 60.0).intValue();
    }

    /** Cryptographically random 6 digits, never starting with a zero. */
    @TestVisible
    private static String generateCode() {
        Integer value = Math.abs(Crypto.getRandomInteger());
        return String.valueOf(Math.mod(value, 900000) + 100000);
    }

    private static String generateReference() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128));
    }

    @TestVisible
    private static String hash(String code, String reference) {
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(code + '|' + reference));
        return EncodingUtil.convertToHex(digest);
    }

    /** Blocks a rapid second send for the same customer and purpose. */
    private static void assertNotThrottled(Id accountId, String purpose) {
        if (accountId == null) return;

        DateTime cutoff = System.now().addSeconds(-RESEND_COOLDOWN_SECONDS);
        Integer recent = [
            SELECT COUNT()
            FROM OTP_Verification__c
            WHERE Customer__c = :accountId
              AND Purpose__c = :purpose
              AND CreatedDate > :cutoff
        ];

        if (recent > 0) {
            throw new OtpException(
                'A code was just sent. Please wait a few seconds before requesting another.');
        }
    }

    /**
     * Shows enough of the address for the customer to recognise it and no more:
     * r****r@orientgroup.org.in. Short local parts are hidden outright rather
     * than half-revealed.
     */
    @TestVisible
    private static String maskEmail(String address) {
        if (String.isBlank(address) || !address.contains('@')) return 'your email address';
        List<String> parts = address.split('@', 2);
        String name = parts[0];
        String masked = name.length() > 2
            ? name.substring(0, 1) + '****' + name.substring(name.length() - 1)
            : '****';
        return masked + '@' + parts[1];
    }

    @TestVisible
    private static String maskMobile(String mobile) {
        String digits = mobile == null ? '' : mobile.replaceAll('[^0-9]', '');
        if (digits.length() < 10) return 'your registered number';
        String last10 = digits.substring(digits.length() - 10);
        return '+91 ' + last10.substring(0, 2) + 'XXXXXX' + last10.substring(8);
    }
}