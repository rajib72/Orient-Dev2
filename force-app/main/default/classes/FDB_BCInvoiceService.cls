/**
 * Reads a customer's posted invoices out of Business Central for the kiosk's
 * "Request Previous Invoice" screen.
 *
 * BC is the book of record for what somebody actually bought, so the screen
 * asks BC directly rather than reading Post_Estimate_Header_From_BC__c - that
 * object only holds the orders somebody pulled down through the estimate flow,
 * which is not the same thing as the customer's billing history.
 */
public with sharing class FDB_BCInvoiceService {

    private static final String BASE_URL =
        'callout:Orient_API_Access_NC/v2.0/ca9359fb-16ff-4067-8c86-89513acaa3b2'
        + '/OJTESTINGEXCLUSIVE/ODataV4/Company(\'My%20Company\')/PostedEstimateHeaderAPIJRS';

    /** How far back "Last 12 Months" and the specific-invoice picker look. */
    private static final Integer LOOKBACK_MONTHS = 12;

    /**
     * The BC header field the date filter runs on. The payload also carries
     * systemCreatedAt, which is when the row was written; `date` is the
     * business date printed on the bill, which is the one the customer
     * recognises. Swap this constant if the filter should follow the row
     * instead of the bill.
     */
    private static final String DATE_FIELD = 'date';

    private static final Integer CALLOUT_TIMEOUT_MS = 120000;

    // The three choices on the invoice screen.
    public static final String SELECTION_LATEST = 'Latest';
    public static final String SELECTION_SPECIFIC = 'Specific';
    public static final String SELECTION_LAST_12 = 'Last12';

    public class InvoiceException extends Exception {}

    /** One row on the screen: bill no, who it was billed to, where, value, date. */
    public class Invoice {
        @AuraEnabled public String documentNo;
        @AuraEnabled public String preDocumentNo;
        /** Raw yyyy-MM-dd, kept so the client can sort or compare without reparsing a display string. */
        @AuraEnabled public String invoiceDate;
        @AuraEnabled public String dateDisplay;
        @AuraEnabled public String customerCode;
        @AuraEnabled public String customerName;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String amountDisplay;
        @AuraEnabled public String locationName;
        @AuraEnabled public String salespersonName;
    }

    /**
     * @param selectionType one of the SELECTION_* constants. Latest returns at
     *                      most one row; the other two return everything in the
     *                      window, newest first.
     * @param fromDate      yyyy-MM-dd, honoured by Specific only. Blank falls
     *                      back to the standard lookback.
     * @param toDate        yyyy-MM-dd, as above
     * @return the customer's posted invoices, newest first; empty when they
     *         have none in range
     */
    public static List<Invoice> fetch(
        Id accountId, String selectionType, String fromDate, String toDate) {

        String customerCode = customerCodeFor(accountId);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + buildQuery(customerCode, selectionType, fromDate, toDate));
        req.setMethod('GET');
        req.setTimeout(CALLOUT_TIMEOUT_MS);

        Long startTime = System.now().getTime();
        HttpResponse res = new Http().send(req);
        Long duration = System.now().getTime() - startTime;

        Boolean isSuccess = res.getStatusCode() == 200;

        FDB_IntegrationLogger.logCallout(
            'FDB_BCInvoiceService', 'fetch', null, res.getStatusCode(),
            isSuccess ? null : 'Failed to fetch posted invoices for ' + customerCode + ': ' + res.getBody(),
            'PostedEstimateHeaderAPIJRS', isSuccess, null, res.getBody(),
            req.getEndpoint(), req.getMethod(), startTime, duration, null
        );

        if (!isSuccess) {
            throw new InvoiceException(
                'We could not reach the billing system just now. Please ask our showroom team for help.');
        }

        Map<String, Object> body =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> rows = (List<Object>) body.get('value');

        List<Invoice> invoices = new List<Invoice>();
        if (rows == null) {
            return invoices;
        }

        for (Object row : rows) {
            invoices.add(toInvoice((Map<String, Object>) row));
        }
        return invoices;
    }

    /**
     * BC knows the customer by the code held on the Account, so a customer we
     * have never pushed to BC has no invoice history to read.
     */
    private static String customerCodeFor(Id accountId) {
        if (accountId == null) {
            throw new InvoiceException('We could not tell which customer to look up.');
        }

        List<Account> accounts = [
            SELECT Id, BC_Customer_No__c FROM Account WHERE Id = :accountId LIMIT 1
        ];

        if (accounts.isEmpty() || String.isBlank(accounts[0].BC_Customer_No__c)) {
            throw new InvoiceException(
                'No billing account is linked to this customer yet, so there are no invoices to show.');
        }
        return accounts[0].BC_Customer_No__c.trim();
    }

    /**
     * Every call is scoped to the one customer; the selection only moves the
     * date part. "Specific" reads whatever range the customer set on the
     * screen, falling back to the standard lookback when they set none;
     * "Last 12 Months" is always the lookback.
     */
    private static String buildQuery(
        String customerCode, String selectionType, String fromDate, String toDate) {

        String filterExpr = 'customerCode eq ' + quoted(customerCode);

        if (SELECTION_LATEST.equalsIgnoreCase(selectionType)) {
            return '?$filter=' + encode(filterExpr)
                + '&$orderby=' + DATE_FIELD + '%20desc'
                + '&$top=1';
        }

        Date windowStart = Date.today().addMonths(-LOOKBACK_MONTHS);
        Date windowEnd = null;

        if (SELECTION_SPECIFIC.equalsIgnoreCase(selectionType)) {
            Date chosenFrom = parsedDate(fromDate, 'from');
            Date chosenTo = parsedDate(toDate, 'to');

            if (chosenFrom != null && chosenTo != null && chosenFrom > chosenTo) {
                throw new InvoiceException(
                    'The "from" date has to be on or before the "to" date.');
            }
            if (chosenFrom != null) {
                windowStart = chosenFrom;
            }
            windowEnd = chosenTo;
        }

        filterExpr += ' and ' + DATE_FIELD + ' ge ' + isoDate(windowStart);
        if (windowEnd != null) {
            filterExpr += ' and ' + DATE_FIELD + ' le ' + isoDate(windowEnd);
        }

        return '?$filter=' + encode(filterExpr)
            + '&$orderby=' + DATE_FIELD + '%20desc';
    }

    /**
     * Parses a date off the screen. Round-tripping it through Date and back out
     * of isoDate() is what keeps the filter safe: whatever arrives, only a
     * yyyy-MM-dd literal this class built itself ever reaches the query.
     */
    private static Date parsedDate(String raw, String which) {
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return Date.valueOf(raw.trim().substring(0, 10));
        } catch (Exception e) {
            throw new InvoiceException(
                'The "' + which + '" date was not one we could read. Please pick it again.');
        }
    }

    private static Invoice toInvoice(Map<String, Object> row) {
        Invoice inv = new Invoice();
        inv.documentNo = (String) row.get('documentNo');
        inv.preDocumentNo = (String) row.get('preDocumentNo');
        inv.locationName = trimmed((String) row.get('locationName'));
        inv.customerCode = trimmed((String) row.get('customerCode'));
        inv.customerName = trimmed((String) row.get('customerName'));
        inv.salespersonName = trimmed((String) row.get('salespersonName'));

        inv.invoiceDate = row.get(DATE_FIELD) == null ? null : String.valueOf(row.get(DATE_FIELD));
        inv.dateDisplay = formatDate(inv.invoiceDate);

        inv.amount = billValue(row);
        inv.amountDisplay = formatAmount(inv.amount);
        return inv;
    }

    /**
     * What the customer paid. finalAmountToCustomer is the figure on the bill
     * once everything is applied, so it is the one the screen prints - a
     * genuine zero on it is still what that bill says. The other two are only
     * read when BC left it empty, which older or simpler documents do.
     */
    private static Decimal billValue(Map<String, Object> row) {
        Decimal finalAmount = toDecimal(row.get('finalAmountToCustomer'));
        if (finalAmount != null) {
            return finalAmount;
        }

        for (String field : new List<String>{ 'amountToCustomer', 'totalTagAmount' }) {
            Decimal value = toDecimal(row.get(field));
            if (value != null && value != 0) {
                return value;
            }
        }
        return 0;
    }

    // ---------------------------------------------------------------- FORMATTING

    /** OData string literal - a quote inside one is escaped by doubling it. */
    private static String quoted(String value) {
        return '\'' + value.replace('\'', '\'\'') + '\'';
    }

    /**
     * Named credential endpoints are sent as written, so the spaces in the
     * filter have to be escaped here. Everything else in the expression is
     * either alphanumeric or legal in a query string as it stands.
     */
    private static String encode(String filterExpr) {
        return filterExpr.replace(' ', '%20');
    }

    /** yyyy-MM-dd, built by hand so no timezone can shift the boundary. */
    private static String isoDate(Date value) {
        return String.valueOf(value.year())
            + '-' + String.valueOf(value.month()).leftPad(2, '0')
            + '-' + String.valueOf(value.day()).leftPad(2, '0');
    }

    private static String formatDate(String raw) {
        if (String.isBlank(raw) || raw.length() < 10) {
            return raw;
        }
        try {
            Date parsed = Date.valueOf(raw.substring(0, 10));
            return DateTime.newInstance(parsed, Time.newInstance(0, 0, 0, 0)).format('dd MMM yyyy');
        } catch (Exception e) {
            return raw;
        }
    }

    /**
     * Grouped, always to two decimals. Decimal.format() groups but drops the
     * scale, so 319.00 comes back as "319" - not what a bill should read - and
     * the paise are put back by hand. The currency symbol is the template's job.
     */
    private static String formatAmount(Decimal value) {
        Decimal amount = (value == null ? 0 : value).setScale(2, System.RoundingMode.HALF_UP);
        Boolean isNegative = amount < 0;
        Decimal magnitude = isNegative ? -amount : amount;

        Long rupees = magnitude.longValue();
        Integer paise = ((magnitude - rupees) * 100).intValue();

        return (isNegative ? '-' : '')
            + Decimal.valueOf(rupees).format()
            + '.' + String.valueOf(paise).leftPad(2, '0');
    }

    private static Decimal toDecimal(Object value) {
        if (value == null) {
            return null;
        }
        try {
            return Decimal.valueOf(String.valueOf(value));
        } catch (Exception e) {
            return null;
        }
    }

    private static String trimmed(String value) {
        return value == null ? null : value.trim();
    }
}