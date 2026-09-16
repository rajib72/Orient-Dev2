public without sharing class Ctrl_OrientCustomerApprovalEmailContent {

    public Id taggedApprovalId { get; set; }

    private Tagged_Approval_Hierarchy__c approvalTransactionCache;
    private List<EmailChangeRow> changeRowsCache;

    public class EmailChangeRow {
        public String sectionName { get; set; }
        public String fieldLabel { get; set; }
        public String oldValue { get; set; }
        public String newValue { get; set; }
    }

    public Tagged_Approval_Hierarchy__c getApprovalTransaction() {
        if (taggedApprovalId == null) {
            return null;
        }

        if (approvalTransactionCache == null) {
            List<Tagged_Approval_Hierarchy__c> transactions = [
                SELECT Id, Name,
                       Approval_Status__c,
                       Customer_Change_Request__c,
                       Customer_Change_Request__r.Name,
                       Customer_Change_Request__r.Orient_Customer__c,
                       Customer_Change_Request__r.Orient_Customer__r.Name,
                       Customer_Change_Request__r.Approval_Store__c,
                       Customer_Change_Request__r.Approval_Store__r.Name,
                       Customer_Change_Request__r.Location_Code__c,
                       Customer_Change_Request__r.Change_Reason__c,
                       Customer_Change_Request__r.Submitted_By__c,
                       Customer_Change_Request__r.Submitted_By__r.Name,
                       Customer_Change_Request__r.Submitted_Date_Time__c,
                       Current_Approval_Level__c,
                       Current_Approval_Level__r.Responsible_Team__c,
                       Current_Approval_Level__r.Sr_No__c,
                       Pending_With__c,
                       Pending_With__r.Name
                FROM Tagged_Approval_Hierarchy__c
                WHERE Id = :taggedApprovalId
                LIMIT 1
            ];

            approvalTransactionCache = transactions.isEmpty()
                ? null
                : transactions[0];
        }

        return approvalTransactionCache;
    }

    public List<EmailChangeRow> getChangeRows() {
        Id requestId = getChangeRequestId();

        if (requestId == null) {
            return new List<EmailChangeRow>();
        }

        if (changeRowsCache == null) {
            changeRowsCache = new List<EmailChangeRow>();

            for (Orient_Customer_Change_Item__c itemRecord : [
                SELECT Id,
                       Account_Field_API__c,
                       Field_Label__c,
                       Section_Name__c,
                       Sequence__c,
                       Old_Display_Value__c,
                       New_Display_Value__c
                FROM Orient_Customer_Change_Item__c
                WHERE Change_Request__c = :requestId
                AND Item_Approval_Status__c = 'Pending'
                ORDER BY Sequence__c ASC, CreatedDate ASC
            ]) {
                if (!Ctrl_Hlp_OrientCustAddressApproval.isWorkspaceVisibleField(itemRecord.Account_Field_API__c)) {
                    continue;
                }

                EmailChangeRow row = new EmailChangeRow();
                row.sectionName = displayValue(itemRecord.Section_Name__c);
                row.fieldLabel = displayValue(itemRecord.Field_Label__c);
                row.oldValue = displayValue(itemRecord.Old_Display_Value__c);
                row.newValue = displayValue(itemRecord.New_Display_Value__c);
                changeRowsCache.add(row);
            }
        }

        return changeRowsCache;
    }

    public Integer getChangeCount() {
        return getChangeRows().size();
    }

    public Id getChangeRequestId() {
        Tagged_Approval_Hierarchy__c transactionRecord = getApprovalTransaction();
        return transactionRecord == null
            ? null
            : transactionRecord.Customer_Change_Request__c;
    }

    public Id getCustomerId() {
        Tagged_Approval_Hierarchy__c transactionRecord = getApprovalTransaction();
        return transactionRecord == null ||
            transactionRecord.Customer_Change_Request__r == null
                ? null
                : transactionRecord.Customer_Change_Request__r.Orient_Customer__c;
    }

    public String getCustomerName() {
        Tagged_Approval_Hierarchy__c transactionRecord = getApprovalTransaction();
        return transactionRecord == null ||
            transactionRecord.Customer_Change_Request__r == null ||
            transactionRecord.Customer_Change_Request__r.Orient_Customer__r == null
                ? '—'
                : displayValue(
                    transactionRecord.Customer_Change_Request__r.Orient_Customer__r.Name
                );
    }

    public String getChangeRequestName() {
        Tagged_Approval_Hierarchy__c transactionRecord = getApprovalTransaction();
        return transactionRecord == null ||
            transactionRecord.Customer_Change_Request__r == null
                ? '—'
                : displayValue(transactionRecord.Customer_Change_Request__r.Name);
    }

    public String getApprovalStoreName() {
        Tagged_Approval_Hierarchy__c transactionRecord = getApprovalTransaction();
        return transactionRecord == null ||
            transactionRecord.Customer_Change_Request__r == null ||
            transactionRecord.Customer_Change_Request__r.Approval_Store__r == null
                ? '—'
                : displayValue(
                    transactionRecord.Customer_Change_Request__r.Approval_Store__r.Name
                );
    }

    public String getSubmittedByName() {
        Tagged_Approval_Hierarchy__c transactionRecord = getApprovalTransaction();
        return transactionRecord == null ||
            transactionRecord.Customer_Change_Request__r == null ||
            transactionRecord.Customer_Change_Request__r.Submitted_By__r == null
                ? '—'
                : displayValue(
                    transactionRecord.Customer_Change_Request__r.Submitted_By__r.Name
                );
    }

    public Datetime getSubmittedDateTime() {
        Tagged_Approval_Hierarchy__c transactionRecord = getApprovalTransaction();
        return transactionRecord == null ||
            transactionRecord.Customer_Change_Request__r == null
                ? null
                : transactionRecord.Customer_Change_Request__r.Submitted_Date_Time__c;
    }

    public String getSubmittedDateTimeIST() {
        Datetime submittedDateTime = getSubmittedDateTime();

        return submittedDateTime == null
            ? '—'
            : submittedDateTime.format(
                'dd-MMM-yyyy hh:mm a',
                'Asia/Kolkata'
            ) + ' IST';
    }

    public String getLocationCode() {
        Tagged_Approval_Hierarchy__c transactionRecord = getApprovalTransaction();
        return transactionRecord == null ||
            transactionRecord.Customer_Change_Request__r == null
                ? '—'
                : displayValue(
                    transactionRecord.Customer_Change_Request__r.Location_Code__c
                );
    }

    public String getChangeReason() {
        Tagged_Approval_Hierarchy__c transactionRecord = getApprovalTransaction();
        return transactionRecord == null ||
            transactionRecord.Customer_Change_Request__r == null
                ? '—'
                : displayValue(
                    transactionRecord.Customer_Change_Request__r.Change_Reason__c
                );
    }

    public String getCurrentApprovalLevel() {
        Tagged_Approval_Hierarchy__c transactionRecord = getApprovalTransaction();
        return transactionRecord == null ||
            transactionRecord.Current_Approval_Level__r == null
                ? '—'
                : displayValue(
                    transactionRecord.Current_Approval_Level__r.Responsible_Team__c
                );
    }

    public String getPendingWithName() {
        Tagged_Approval_Hierarchy__c transactionRecord = getApprovalTransaction();
        return transactionRecord == null ||
            transactionRecord.Pending_With__r == null
                ? 'Approver'
                : displayValue(transactionRecord.Pending_With__r.Name);
    }

    public String getApprovalStatus() {
        Tagged_Approval_Hierarchy__c transactionRecord = getApprovalTransaction();
        return transactionRecord == null
            ? '—'
            : displayValue(transactionRecord.Approval_Status__c);
    }

    public String getCustomerUrl() {
        Id customerId = getCustomerId();

        if (customerId == null) {
            return null;
        }

        return URL.getOrgDomainUrl().toExternalForm() +
            '/lightning/r/Account/' + String.valueOf(customerId) + '/view';
    }

    public String getChangeRequestUrl() {
        Id requestId = getChangeRequestId();

        if (requestId == null) {
            return null;
        }

        return URL.getOrgDomainUrl().toExternalForm() +
            '/lightning/r/Orient_Customer_Change_Request__c/' +
            String.valueOf(requestId) + '/view';
    }

    private static String displayValue(String value) {
        return String.isBlank(value) ? '—' : value;
    }
}