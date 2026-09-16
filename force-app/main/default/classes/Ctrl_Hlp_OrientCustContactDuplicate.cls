public with sharing class Ctrl_Hlp_OrientCustContactDuplicate {

    private static final String ITEM_STATUS_PENDING = 'Pending';
    private static final String PHONE_FIELD_API = 'Phone';
    private static final String WHATSAPP_FIELD_API = 'Whatsapp_number__c';

    private static final Set<String> CONTACT_FIELD_APIS =
        new Set<String>{
            PHONE_FIELD_API,
            WHATSAPP_FIELD_API
        };

    public class RequestedContact {
        public Id changeItemId;
        public String fieldApi;
        public String fieldLabel;
        public String proposedNumber;
    }

    public class DuplicateCustomer {
        public Id customerId;
        public String customerName;
        public String bcCustomerNo;
        public String requestedFieldApi;
        public String requestedFieldLabel;
        public String requestedNumber;
        public String matchSource;
    }

    public class LookupResult {
        public Boolean contactChangePresent;
        public Boolean phoneChangePresent;
        public Boolean whatsappChangePresent;
        public Id currentCustomerId;
        public String proposedPhone;
        public String proposedWhatsapp;
        public Boolean duplicateFound;
        public Integer duplicateCount;
        public String message;
        public List<RequestedContact> requestedContacts;
        public List<DuplicateCustomer> matchingCustomers;

        public LookupResult() {
            contactChangePresent = false;
            phoneChangePresent = false;
            whatsappChangePresent = false;
            duplicateFound = false;
            duplicateCount = 0;
            requestedContacts = new List<RequestedContact>();
            matchingCustomers = new List<DuplicateCustomer>();
        }
    }

    public static LookupResult lookupByRequest(Id requestId) {
        LookupResult result = new LookupResult();

        if (requestId == null) {
            return result;
        }

        List<Orient_Customer_Change_Item__c> contactItems = [
            SELECT Id,
                   Change_Request__c,
                   Change_Request__r.Orient_Customer__c,
                   Account_Field_API__c,
                   Field_Label__c,
                   New_Value__c,
                   New_Display_Value__c,
                   Item_Approval_Status__c
            FROM Orient_Customer_Change_Item__c
            WHERE Change_Request__c = :requestId
            AND Account_Field_API__c IN :CONTACT_FIELD_APIS
            AND Item_Approval_Status__c = :ITEM_STATUS_PENDING
            ORDER BY Sequence__c ASC, CreatedDate ASC
        ];

        if (contactItems.isEmpty()) {
            result.message =
                'No Pending Phone or WhatsApp number change is present in this approval request.';
            return result;
        }

        result.contactChangePresent = true;
        result.currentCustomerId =
            contactItems[0].Change_Request__r.Orient_Customer__c;

        Set<String> proposedNumbers =
            new Set<String>();

        for (
            Orient_Customer_Change_Item__c contactItem :
            contactItems
        ) {
            String rawValue =
                String.isNotBlank(contactItem.New_Value__c)
                    ? contactItem.New_Value__c
                    : contactItem.New_Display_Value__c;

            String normalizedNumber =
                normalizePhone(rawValue);

            RequestedContact requested =
                new RequestedContact();

            requested.changeItemId =
                contactItem.Id;
            requested.fieldApi =
                contactItem.Account_Field_API__c;
            requested.fieldLabel =
                String.isBlank(contactItem.Field_Label__c)
                    ? getFieldLabel(contactItem.Account_Field_API__c)
                    : contactItem.Field_Label__c;
            requested.proposedNumber =
                normalizedNumber;

            result.requestedContacts.add(requested);

            if (
                contactItem.Account_Field_API__c ==
                PHONE_FIELD_API
            ) {
                result.phoneChangePresent = true;
                result.proposedPhone =
                    normalizedNumber;
            } else if (
                contactItem.Account_Field_API__c ==
                WHATSAPP_FIELD_API
            ) {
                result.whatsappChangePresent = true;
                result.proposedWhatsapp =
                    normalizedNumber;
            }

            if (String.isBlank(normalizedNumber)) {
                result.message =
                    'A requested Phone / WhatsApp number is blank and cannot be checked.';
                return result;
            }

            if (normalizedNumber.length() != 10) {
                result.message =
                    requested.fieldLabel +
                    ' must contain exactly 10 digits before duplicate lookup.';
                return result;
            }

            proposedNumbers.add(normalizedNumber);
        }

        List<Account> matches = [
            SELECT Id,
                   Name,
                   BC_Customer_No__c,
                   Phone,
                   Whatsapp_number__c
            FROM Account
            WHERE Id != :result.currentCustomerId
            AND (
                Phone IN :proposedNumbers
                OR Whatsapp_number__c IN :proposedNumbers
            )
            ORDER BY Name ASC
            LIMIT 100
        ];

        Set<String> duplicateKeys =
            new Set<String>();

        for (RequestedContact requested : result.requestedContacts) {
            for (Account accountRecord : matches) {
                String normalizedPhone =
                    normalizePhone(accountRecord.Phone);
                String normalizedWhatsapp =
                    normalizePhone(accountRecord.Whatsapp_number__c);

                Boolean phoneMatched =
                    normalizedPhone ==
                    requested.proposedNumber;
                Boolean whatsappMatched =
                    normalizedWhatsapp ==
                    requested.proposedNumber;

                if (!phoneMatched && !whatsappMatched) {
                    continue;
                }

                String duplicateKey =
                    String.valueOf(accountRecord.Id) +
                    '|' +
                    requested.fieldApi +
                    '|' +
                    requested.proposedNumber;

                if (duplicateKeys.contains(duplicateKey)) {
                    continue;
                }

                duplicateKeys.add(duplicateKey);

                DuplicateCustomer match =
                    new DuplicateCustomer();

                match.customerId =
                    accountRecord.Id;
                match.customerName =
                    accountRecord.Name;
                match.bcCustomerNo =
                    accountRecord.BC_Customer_No__c;
                match.requestedFieldApi =
                    requested.fieldApi;
                match.requestedFieldLabel =
                    requested.fieldLabel;
                match.requestedNumber =
                    requested.proposedNumber;

                if (phoneMatched && whatsappMatched) {
                    match.matchSource =
                        'Phone & WhatsApp';
                } else if (phoneMatched) {
                    match.matchSource =
                        'Phone';
                } else {
                    match.matchSource =
                        'WhatsApp';
                }

                result.matchingCustomers.add(match);
            }
        }

        result.duplicateCount =
            result.matchingCustomers.size();
        result.duplicateFound =
            result.duplicateCount > 0;

        if (result.duplicateFound) {
            result.message =
                String.valueOf(result.duplicateCount) +
                ' duplicate match(es) found for the requested Phone / WhatsApp number(s).';
        } else if (
            result.phoneChangePresent &&
            result.whatsappChangePresent
        ) {
            result.message =
                'No other customer was found with either the requested Phone or WhatsApp number.';
        } else if (result.phoneChangePresent) {
            result.message =
                'No other customer was found with the requested Phone number.';
        } else {
            result.message =
                'No other customer was found with the requested WhatsApp number.';
        }

        return result;
    }

    public static void assertNoDuplicateForPendingContactNumbers(
        Id requestId
    ) {
        LookupResult result =
            lookupByRequest(requestId);

        if (
            result.contactChangePresent == true &&
            result.duplicateFound == true
        ) {
            throw new AuraHandledException(
                'Another customer already exists with one of the requested Phone / WhatsApp numbers. ' +
                'Run the customer duplicate lookup again and reject the entire approval request.'
            );
        }
    }

    private static String normalizePhone(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        return value.replaceAll('[^0-9]', '');
    }

    private static String getFieldLabel(String fieldApi) {
        return fieldApi == WHATSAPP_FIELD_API
            ? 'WhatsApp Number'
            : 'Phone';
    }
}