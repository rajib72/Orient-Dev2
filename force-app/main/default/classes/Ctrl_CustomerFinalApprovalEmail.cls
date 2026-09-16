public without sharing class Ctrl_CustomerFinalApprovalEmail {

    private static final String ITEM_STATUS_FINAL_APPROVED =
        'Final Approved';
    private static final String ITEM_STATUS_RETURNED =
        'Returned';

    public Id changeRequestId { get; set; }

    private Orient_Customer_Change_Request__c requestCache;
    private List<FinalChangeRow> changeRowsCache;

    public class FinalChangeRow {
        public String sectionName { get; set; }
        public String fieldLabel { get; set; }
        public String oldValue { get; set; }
        public String newValue { get; set; }
        public String outcomeLabel { get; set; }
        public String outcomeStyle { get; set; }
        public String decisionByName { get; set; }
        public String decisionDateTimeIST { get; set; }
        public String rejectionReason { get; set; }
        public Boolean isApproved { get; set; }
        public Boolean isRejected { get; set; }
        public Boolean bcPushApplicable { get; set; }
    }

    public Orient_Customer_Change_Request__c getChangeRequest() {
        if (changeRequestId == null) {
            return null;
        }

        if (requestCache == null) {
            List<Orient_Customer_Change_Request__c> requests = [
                SELECT Id,
                       Name,
                       Approval_Status__c,
                       Orient_Customer__c,
                       Orient_Customer__r.Name,
                       Approval_Store__c,
                       Approval_Store__r.Name,
                       Location_Code__c,
                       Change_Reason__c,
                       Submitted_By__c,
                       Submitted_By__r.Name,
                       Submitted_By__r.Email,
                       Submitted_Date_Time__c,
                       Last_Action__c,
                       Last_Action_By__c,
                       Last_Action_By__r.Name,
                       Last_Action_Date_Time__c,
                       BC_Customer_No__c,
                       BC_Push_Status__c,
                       BC_Push_Attempt_Count__c,
                       BC_Push_Date_Time__c,
                       BC_Push_Message__c
                FROM Orient_Customer_Change_Request__c
                WHERE Id = :changeRequestId
                LIMIT 1
            ];

            requestCache =
                requests.isEmpty()
                    ? null
                    : requests[0];
        }

        return requestCache;
    }

    public List<FinalChangeRow> getChangeRows() {
        if (changeRequestId == null) {
            return new List<FinalChangeRow>();
        }

        if (changeRowsCache == null) {
            changeRowsCache =
                new List<FinalChangeRow>();

            for (
                Orient_Customer_Change_Item__c itemRecord :
                [
                    SELECT Id,
                           Account_Field_API__c,
                           Section_Name__c,
                           Sequence__c,
                           Field_Label__c,
                           Old_Display_Value__c,
                           New_Display_Value__c,
                           Item_Approval_Status__c,
                           BC_Push_Applicable__c,
                           Rejected_By__c,
                           Rejected_By__r.Name,
                           Rejected_Date_Time__c,
                           Rejection_Reason__c,
                           Final_Approved_By__c,
                           Final_Approved_By__r.Name,
                           Final_Approved_Date_Time__c
                    FROM Orient_Customer_Change_Item__c
                    WHERE Change_Request__c =
                        :changeRequestId
                    ORDER BY Sequence__c ASC,
                             CreatedDate ASC
                ]
            ) {
                FinalChangeRow row =
                    new FinalChangeRow();

                row.sectionName =
                    displayValue(
                        itemRecord.Section_Name__c
                    );
                row.fieldLabel =
                    displayValue(
                        itemRecord.Field_Label__c
                    );
                row.oldValue =
                    displayValue(
                        itemRecord.Old_Display_Value__c
                    );
                row.newValue =
                    displayValue(
                        itemRecord.New_Display_Value__c
                    );
                row.bcPushApplicable =
                    itemRecord.BC_Push_Applicable__c ==
                    true;

                if (
                    itemRecord.Item_Approval_Status__c ==
                    ITEM_STATUS_FINAL_APPROVED
                ) {
                    row.isApproved = true;
                    row.isRejected = false;
                    row.outcomeLabel =
                        'Approved';
                    row.outcomeStyle =
                        'display:inline-block;padding:4px 9px;border-radius:999px;' +
                        'background:#eaf7ee;color:#2e844a;font-size:11px;font-weight:bold;';
                    row.decisionByName =
                        itemRecord.Final_Approved_By__r ==
                            null
                            ? '—'
                            : displayValue(
                                itemRecord
                                    .Final_Approved_By__r
                                    .Name
                            );
                    row.decisionDateTimeIST =
                        formatIST(
                            itemRecord
                                .Final_Approved_Date_Time__c
                        );
                    row.rejectionReason =
                        '—';
                } else if (
                    itemRecord.Item_Approval_Status__c ==
                    ITEM_STATUS_RETURNED
                ) {
                    row.isApproved = false;
                    row.isRejected = true;
                    row.outcomeLabel =
                        'Rejected';
                    row.outcomeStyle =
                        'display:inline-block;padding:4px 9px;border-radius:999px;' +
                        'background:#fdecef;color:#a31420;font-size:11px;font-weight:bold;';
                    row.decisionByName =
                        itemRecord.Rejected_By__r ==
                            null
                            ? '—'
                            : displayValue(
                                itemRecord
                                    .Rejected_By__r
                                    .Name
                            );
                    row.decisionDateTimeIST =
                        formatIST(
                            itemRecord
                                .Rejected_Date_Time__c
                        );
                    row.rejectionReason =
                        displayValue(
                            itemRecord
                                .Rejection_Reason__c
                        );
                } else {
                    row.isApproved = false;
                    row.isRejected = false;
                    row.outcomeLabel =
                        displayValue(
                            itemRecord
                                .Item_Approval_Status__c
                        );
                    row.outcomeStyle =
                        'display:inline-block;padding:4px 9px;border-radius:999px;' +
                        'background:#f3f3f3;color:#5c5c5c;font-size:11px;font-weight:bold;';
                    row.decisionByName =
                        '—';
                    row.decisionDateTimeIST =
                        '—';
                    row.rejectionReason =
                        '—';
                }

                changeRowsCache.add(
                    row
                );
            }
        }

        return changeRowsCache;
    }

    public Integer getTotalChangeCount() {
        return getChangeRows().size();
    }

    public Integer getApprovedCount() {
        Integer countValue = 0;

        for (
            FinalChangeRow row :
            getChangeRows()
        ) {
            if (row.isApproved == true) {
                countValue++;
            }
        }

        return countValue;
    }

    public Integer getRejectedCount() {
        Integer countValue = 0;

        for (
            FinalChangeRow row :
            getChangeRows()
        ) {
            if (row.isRejected == true) {
                countValue++;
            }
        }

        return countValue;
    }

    public Boolean getHasRejectedChanges() {
        return getRejectedCount() > 0;
    }

    public Boolean getHasBCDetails() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return
            requestRecord != null &&
            (
                String.isNotBlank(
                    requestRecord.BC_Push_Status__c
                ) ||
                String.isNotBlank(
                    requestRecord.BC_Customer_No__c
                )
            );
    }

    public String getCustomerName() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return
            requestRecord == null ||
            requestRecord.Orient_Customer__r ==
                null
                ? '—'
                : displayValue(
                    requestRecord
                        .Orient_Customer__r
                        .Name
                );
    }

    public String getChangeRequestName() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return requestRecord == null
            ? '—'
            : displayValue(
                requestRecord.Name
            );
    }

    public String getApprovalStoreName() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return
            requestRecord == null ||
            requestRecord.Approval_Store__r ==
                null
                ? '—'
                : displayValue(
                    requestRecord
                        .Approval_Store__r
                        .Name
                );
    }

    public String getLocationCode() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return requestRecord == null
            ? '—'
            : displayValue(
                requestRecord.Location_Code__c
            );
    }

    public String getSubmittedByName() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return
            requestRecord == null ||
            requestRecord.Submitted_By__r ==
                null
                ? '—'
                : displayValue(
                    requestRecord
                        .Submitted_By__r
                        .Name
                );
    }

    public String getSubmittedByEmail() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return
            requestRecord == null ||
            requestRecord.Submitted_By__r ==
                null
                ? null
                : requestRecord
                    .Submitted_By__r
                    .Email;
    }

    public String getSubmittedDateTimeIST() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return requestRecord == null
            ? '—'
            : formatIST(
                requestRecord
                    .Submitted_Date_Time__c
            );
    }

    public String getFinalApprovedByName() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return
            requestRecord == null ||
            requestRecord.Last_Action_By__r ==
                null
                ? '—'
                : displayValue(
                    requestRecord
                        .Last_Action_By__r
                        .Name
                );
    }

    public String getFinalApprovedDateTimeIST() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return requestRecord == null
            ? '—'
            : formatIST(
                requestRecord
                    .Last_Action_Date_Time__c
            );
    }

    public String getApprovalStatus() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return requestRecord == null
            ? '—'
            : displayValue(
                requestRecord
                    .Approval_Status__c
            );
    }

    public String getChangeReason() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return requestRecord == null
            ? '—'
            : displayValue(
                requestRecord
                    .Change_Reason__c
            );
    }

    public String getBCCustomerNo() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return requestRecord == null
            ? '—'
            : displayValue(
                requestRecord
                    .BC_Customer_No__c
            );
    }

    public String getBCPushStatus() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return requestRecord == null
            ? '—'
            : displayValue(
                requestRecord
                    .BC_Push_Status__c
            );
    }

    public String getBCPushDateTimeIST() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return requestRecord == null
            ? '—'
            : formatIST(
                requestRecord
                    .BC_Push_Date_Time__c
            );
    }

    public String getBCPushMessage() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        return requestRecord == null
            ? '—'
            : displayValue(
                requestRecord
                    .BC_Push_Message__c
            );
    }

    public String getCustomerUrl() {
        Orient_Customer_Change_Request__c requestRecord =
            getChangeRequest();

        if (
            requestRecord == null ||
            requestRecord.Orient_Customer__c ==
                null
        ) {
            return null;
        }

        return
            URL.getOrgDomainUrl()
                .toExternalForm() +
            '/lightning/r/Account/' +
            String.valueOf(
                requestRecord
                    .Orient_Customer__c
            ) +
            '/view';
    }

    public String getChangeRequestUrl() {
        if (changeRequestId == null) {
            return null;
        }

        /*
         * Deep-link directly into the Customer Approval Workspace.
         * The request Id is passed as URL-addressable component state.
         */
        return
            URL.getOrgDomainUrl()
                .toExternalForm() +
            '/lightning/cmp/c__lwcOrientCustomerApprovalWorkspace' +
            '?c__requestId=' +
            EncodingUtil.urlEncode(
                String.valueOf(
                    changeRequestId
                ),
                'UTF-8'
            );
    }

    private static String formatIST(
        Datetime value
    ) {
        return value == null
            ? '—'
            : value.format(
                'dd-MMM-yyyy hh:mm a',
                'Asia/Kolkata'
            ) + ' IST';
    }

    private static String displayValue(
        String value
    ) {
        return String.isBlank(value)
            ? '—'
            : value;
    }
}