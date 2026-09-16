/**
 * Transport for ShreeSMS (https://web.shreesms.net).
 *
 * Everything provider-specific lives in buildEndpoint() so swapping gateways,
 * or correcting the parameter names, touches one method and nothing else.
 *
 * Account-wide configuration is read from Custom Labels, matching the pattern
 * used by the Surepass integrations in this org:
 *   ShreeSMS_Endpoint      https://web.shreesms.net/API/SendSMS.aspx
 *   ShreeSMS_API_Key       the account APIkey
 *   ShreeSMS_Sender_Id     the 6-character registered sender / header, e.g. ORIOTP
 *   ShreeSMS_DLT_Entity_Id the registered DLT principal entity id
 *
 * Anything that varies per message - the DLT template id, and the sender when a
 * template was approved under a different header - arrives as an argument. Those
 * come from SMS_Template__mdt, which keeps each template id next to the exact
 * text it was registered with. See FDB_OtpService.resolveTemplate.
 *
 * The endpoint must also be allowed under Setup > Remote Site Settings
 * (or fronted by a Named Credential).
 */
public with sharing class FDB_ShreeSmsGateway {

    public class GatewayResult {
        public Boolean success;
        public String messageId;
        public String rawResponse;
        public String errorMessage;
    }

    /** Thrown when the integration has not been configured yet. */
    public class ConfigurationException extends Exception {}

    private static final Integer TIMEOUT_MS = 60000;

    /** ShreeSMS message class. 3 is the transactional / OTP route. */
    private static final String SMS_TYPE = '3';

    /**
     * Sends one message to one Indian mobile number.
     *
     * The template id and the text are two halves of one registration, so they
     * are passed together and never sourced separately.
     *
     * @param mobile     10-digit number, with or without the 91 prefix
     * @param message    the exact text approved on the DLT template
     * @param templateId the DLT template id that text was registered under
     * @param senderId   header override, or blank for the account default
     */
    public static GatewayResult send(String mobile, String message, String templateId, String senderId) {
        GatewayResult result = new GatewayResult();
        result.success = false;

        String endpoint = safeLabel('ShreeSMS_Endpoint');
        String apiKey = safeLabel('ShreeSMS_API_Key');

        if (String.isBlank(endpoint) || String.isBlank(apiKey)) {
            throw new ConfigurationException(
                'ShreeSMS is not configured. Set the ShreeSMS_Endpoint and ShreeSMS_API_Key Custom Labels.');
        }

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(buildEndpoint(endpoint, apiKey, normalise(mobile), message, templateId, senderId));
            req.setMethod('GET');
            req.setTimeout(TIMEOUT_MS);

            HttpResponse res = new Http().send(req);
            result.rawResponse = truncate(res.getBody(), 2000);

            if (res.getStatusCode() == 200) {
                result.success = isAccepted(res.getBody());
                result.messageId = truncate(extractMessageId(res.getBody()), 255);
                if (!result.success) {
                    result.errorMessage = 'SMS gateway rejected the message: ' + result.rawResponse;
                }
            } else {
                result.errorMessage = 'SMS gateway returned HTTP ' + res.getStatusCode()
                    + ': ' + result.rawResponse;
            }
        } catch (Exception e) {
            result.errorMessage = 'SMS gateway callout failed: ' + e.getMessage();
        }

        return result;
    }

    /**
     * ==================== PROVIDER-SPECIFIC ====================
     * Builds the query string ShreeSMS expects.
     *
     * The parameter names below are taken from a request verified by hand
     * against the live account:
     *
     *   /API/SendSMS.aspx?APIkey=..&SenderID=..&SMSType=3&Mobile=..
     *                    &MsgText=..&EntityID=..&TemplateID=..
     *
     * Do not "tidy" these names. This gateway answers HTTP 200 for a request
     * it did not understand, so a wrong name fails silently rather than loudly.
     */
    @TestVisible
    private static String buildEndpoint(String endpoint, String apiKey, String mobile, String message,
                                        String templateId, String senderId) {
        String url = endpoint
            + (endpoint.contains('?') ? '&' : '?')
            + 'APIkey=' + encode(apiKey)
            + '&SMSType=' + SMS_TYPE
            + '&Mobile=' + encode(mobile)
            + '&MsgText=' + encode(message);

        // A template approved under a different header carries its own sender
        String sender = String.isNotBlank(senderId) ? senderId : safeLabel('ShreeSMS_Sender_Id');
        if (String.isNotBlank(sender)) {
            url += '&SenderID=' + encode(sender);
        }

        // One DLT principal entity covers every template on the account
        String dltEntity = safeLabel('ShreeSMS_DLT_Entity_Id');
        if (String.isNotBlank(dltEntity)) {
            url += '&EntityID=' + encode(dltEntity);
        }

        // No fallback here on purpose. A template id borrowed from anywhere but
        // the record the text came from is how a message ends up registered as
        // one thing and worded as another, which the telco drops without
        // telling us. Better to fail here than to send something undeliverable.
        if (String.isBlank(templateId)) {
            throw new ConfigurationException(
                'No DLT template id was supplied. Check the SMS Template custom metadata records.');
        }
        url += '&TemplateID=' + encode(templateId);

        return url;
    }

    /**
     * urlEncode renders a space as '+', which ASP.NET does decode, but the
     * message has to survive a byte-exact DLT template comparison downstream.
     * Emitting %20 keeps the request identical to the one tested by hand.
     * Any '+' left after encoding was a space - a literal '+' becomes %2B.
     */
    private static String encode(String value) {
        return EncodingUtil.urlEncode(value == null ? '' : value, 'UTF-8').replace('+', '%20');
    }

    /**
     * These gateways answer 200 for both success and failure, so the body is
     * what decides. A verified acceptance looks like:
     *
     *   ok|9831013797|273524927<br />
     *
     * Whitelisting the "ok" marker rather than blacklisting error words: an
     * unrecognised body is then treated as a failure, which is the safe way
     * round. Blacklisting lets any unforeseen error text read as success.
     */
    @TestVisible
    private static Boolean isAccepted(String body) {
        return parts(body).size() > 0 && parts(body)[0].equalsIgnoreCase('ok');
    }

    /**
     * Pulls the provider's message id - the third field - so the record holds
     * something that can actually be quoted to ShreeSMS support.
     */
    @TestVisible
    private static String extractMessageId(String body) {
        List<String> segments = parts(body);
        return segments.size() >= 3 ? segments[2] : '';
    }

    /** Splits the pipe-delimited body, stripping the trailing HTML noise. */
    private static List<String> parts(String body) {
        if (String.isBlank(body)) return new List<String>();
        String cleaned = body.replaceAll('<[^>]*>', '').trim();
        List<String> segments = new List<String>();
        for (String segment : cleaned.split('\\|')) {
            segments.add(segment.trim());
        }
        return segments;
    }

    /** Strips spaces, punctuation and any leading 91 / +91 country code. */
    @TestVisible
    private static String normalise(String mobile) {
        if (String.isBlank(mobile)) return '';
        String digits = mobile.replaceAll('[^0-9]', '');
        if (digits.length() > 10) {
            digits = digits.substring(digits.length() - 10);
        }
        return digits;
    }

    /** Custom Labels throw if undefined in some contexts, so read defensively. */
    private static String safeLabel(String name) {
        try {
            Map<String, String> known = new Map<String, String>{
                'ShreeSMS_Endpoint' => System.Label.ShreeSMS_Endpoint,
                'ShreeSMS_API_Key' => System.Label.ShreeSMS_API_Key,
                'ShreeSMS_Sender_Id' => System.Label.ShreeSMS_Sender_Id,
                'ShreeSMS_DLT_Entity_Id' => System.Label.ShreeSMS_DLT_Entity_Id
            };
            String value = known.get(name);
            return value == null ? '' : value.trim();
        } catch (Exception e) {
            return '';
        }
    }

    private static String truncate(String value, Integer max) {
        if (String.isBlank(value)) return '';
        return value.length() > max ? value.substring(0, max) : value;
    }
}