public without sharing class Ctrl_BTLEmailTemplateContent {

    public Id inputTransactionId { get; set; }
    public String inputMailType { get; set; }

    private Tagged_Approval_Hierarchy__c anchorCache;
    private List<MemberRow> memberRowsCache;

    public class MemberRow {
        public Id transactionId { get; set; }
        public String transactionNo { get; set; }
        public String executiveName { get; set; }
        public String assignedPersonNo { get; set; }
        public String approvalStatus { get; set; }
        public String submissionCycle { get; set; }
        public String workspaceUrl { get; set; }
    }

    public Tagged_Approval_Hierarchy__c getAnchor() {
        if (inputTransactionId == null) {
            return null;
        }

        if (anchorCache == null) {
            List<Tagged_Approval_Hierarchy__c> rows = [
                SELECT
                    Id,
                    Name,
                    Approval_Status__c,
                    Current_Approval_Level__c,
                    Current_Approval_Level__r.Responsible_Team__c,
                    Current_Approval_Level__r.Sr_No__c,
                    Pending_With__c,
                    Pending_With__r.Name,
                    Returned_From_Level__c,
                    Returned_From_Level__r.Responsible_Team__c,
                    Returned_From_Level__r.Sr_No__c,
                    Submission_Cycle__c,
                    Submitted_By__c,
                    Submitted_By__r.Name,
                    Submitted_Date_Time__c,
                    Last_Action__c,
                    Last_Action_By__c,
                    Last_Action_By__r.Name,
                    Last_Action_Date_Time__c,
                    Last_Action_Comments__c,
                    Final_Approved_By__c,
                    Final_Approved_By__r.Name,
                    Final_Approved_Date_Time__c,
                    Dropped_By__c,
                    Dropped_By__r.Name,
                    Dropped_Date_Time__c,
                    Drop_Reason__c,
                    Form_Activity__c,
                    Form_Activity__r.Name,
                    Form_Activity__r.Activity_Name__c,
                    Form_Activity__r.Final_Customize_Form__c,
                    Form_Activity__r.Final_Customize_Form__r.Name,
                    Form_Activity_Assigned_Persons__c,
                    Form_Activity_Assigned_Persons__r.Name,
                    Form_Activity_Assigned_Persons__r.Team_Name__c,
                    Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                    Form_Activity_Assigned_Persons_Date__c,
                    Form_Activity_Assigned_Persons_Date__r.Store__c,
                    Form_Activity_Assigned_Persons_Date__r.Store__r.Name,
                    Form_Activity_Assigned_Persons_Date__r.Target_Date__c,
                    Form_Activity_Assigned_Persons_Date__r.Activity_Location__c
                FROM Tagged_Approval_Hierarchy__c
                WHERE Id = :inputTransactionId
                LIMIT 1
            ];

            anchorCache = rows.isEmpty()
                ? null
                : rows[0];
        }

        return anchorCache;
    }

    public List<MemberRow> getMemberRows() {
        if (memberRowsCache != null) {
            return memberRowsCache;
        }

        memberRowsCache = new List<MemberRow>();

        Tagged_Approval_Hierarchy__c anchorRecord = getAnchor();
        if (anchorRecord == null) {
            return memberRowsCache;
        }

        Id activityId = anchorRecord.Form_Activity__c;
        Id storeId = anchorRecord.Form_Activity_Assigned_Persons_Date__r == null
            ? null
            : anchorRecord.Form_Activity_Assigned_Persons_Date__r.Store__c;
        Date targetDate = anchorRecord.Form_Activity_Assigned_Persons_Date__r == null
            ? null
            : anchorRecord.Form_Activity_Assigned_Persons_Date__r.Target_Date__c;
        String teamName = anchorRecord.Form_Activity_Assigned_Persons__r == null
            ? null
            : anchorRecord.Form_Activity_Assigned_Persons__r.Team_Name__c;
        String activityLocation =
            anchorRecord.Form_Activity_Assigned_Persons_Date__r == null
                ? null
                : anchorRecord
                    .Form_Activity_Assigned_Persons_Date__r
                    .Activity_Location__c;
        Datetime actionDateTime = anchorRecord.Last_Action_Date_Time__c;
        Decimal cycle = anchorRecord.Submission_Cycle__c;

        String queryText =
            'SELECT Id, Name, Approval_Status__c, Submission_Cycle__c, ' +
            'Form_Activity_Assigned_Persons__r.Name, ' +
            'Form_Activity_Assigned_Persons__r.Team_Name__c, ' +
            'Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name ' +
            'FROM Tagged_Approval_Hierarchy__c ' +
            'WHERE Form_Activity__c = :activityId ' +
            'AND Form_Activity_Assigned_Persons_Date__r.Store__c = :storeId ' +
            'AND Form_Activity_Assigned_Persons_Date__r.Target_Date__c = :targetDate ' +
            'AND Last_Action_Date_Time__c = :actionDateTime ' +
            'AND Submission_Cycle__c = :cycle ';

        if (String.isBlank(teamName)) {
            queryText +=
                'AND Form_Activity_Assigned_Persons__r.Team_Name__c = null ';
        } else {
            queryText +=
                'AND Form_Activity_Assigned_Persons__r.Team_Name__c = :teamName ';
        }

        if (String.isBlank(activityLocation)) {
            queryText +=
                'AND Form_Activity_Assigned_Persons_Date__r.Activity_Location__c = null ';
        } else {
            queryText +=
                'AND Form_Activity_Assigned_Persons_Date__r.Activity_Location__c = :activityLocation ';
        }

        if (isApprovalRequired()) {
            queryText +=
                'AND Approval_Status__c = :pendingStatus ' +
                'AND Pending_With__c = :pendingUserId ' +
                'AND Current_Approval_Level__c = :levelId ';
        } else if (isReturned()) {
            queryText +=
                'AND Approval_Status__c = :returnedStatus ' +
                'AND Submitted_By__c = :submittedById ' +
                'AND Returned_From_Level__c = :returnedLevelId ';
        } else {
            queryText +=
                'AND Approval_Status__c = :completedStatus ' +
                'AND Submitted_By__c = :submittedById ';
        }

        queryText +=
            'ORDER BY Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name, Name';

        Map<String, Object> binds = new Map<String, Object>{
            'activityId' => activityId,
            'storeId' => storeId,
            'targetDate' => targetDate,
            'actionDateTime' => actionDateTime,
            'cycle' => cycle,
            'teamName' => teamName,
            'activityLocation' => activityLocation,
            'pendingStatus' => Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING,
            'pendingUserId' => anchorRecord.Pending_With__c,
            'levelId' => anchorRecord.Current_Approval_Level__c,
            'returnedStatus' => Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED,
            'submittedById' => anchorRecord.Submitted_By__c,
            'returnedLevelId' => anchorRecord.Returned_From_Level__c,
            'completedStatus' => anchorRecord.Approval_Status__c
        };

        for (
            Tagged_Approval_Hierarchy__c row :
            (List<Tagged_Approval_Hierarchy__c>) Database.queryWithBinds(
                queryText,
                binds,
                AccessLevel.SYSTEM_MODE
            )
        ) {
            MemberRow member = new MemberRow();
            member.transactionId = row.Id;
            member.transactionNo = displayValue(row.Name);
            member.executiveName =
                row.Form_Activity_Assigned_Persons__r == null ||
                row.Form_Activity_Assigned_Persons__r.Sales_Executives__r == null
                    ? '—'
                    : displayValue(
                        row.Form_Activity_Assigned_Persons__r
                            .Sales_Executives__r.Name
                    );
            member.assignedPersonNo =
                row.Form_Activity_Assigned_Persons__r == null
                    ? '—'
                    : displayValue(
                        row.Form_Activity_Assigned_Persons__r.Name
                    );
            member.approvalStatus = displayValue(row.Approval_Status__c);
            member.submissionCycle = row.Submission_Cycle__c == null
                ? '—'
                : String.valueOf(row.Submission_Cycle__c);
            member.workspaceUrl = buildWorkspaceUrl(row.Id);
            memberRowsCache.add(member);
        }

        if (memberRowsCache.isEmpty()) {
            MemberRow fallback = new MemberRow();
            fallback.transactionId = anchorRecord.Id;
            fallback.transactionNo = displayValue(anchorRecord.Name);
            fallback.executiveName = getExecutiveName();
            fallback.assignedPersonNo = getAssignedPersonNo();
            fallback.approvalStatus = displayValue(anchorRecord.Approval_Status__c);
            fallback.submissionCycle = getSubmissionCycle();
            fallback.workspaceUrl = getWorkspaceUrl();
            memberRowsCache.add(fallback);
        }

        return memberRowsCache;
    }

    public Boolean getIsApprovalRequired() {
        return isApprovalRequired();
    }

    public Boolean getIsReturned() {
        return isReturned();
    }

    public Boolean getIsCompleted() {
        return !isApprovalRequired() && !isReturned();
    }

    public Boolean getIsDropped() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row != null &&
            row.Approval_Status__c ==
                Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED;
    }

    public String getMailTitle() {
        if (isApprovalRequired()) {
            return 'BTL Approval Required';
        }
        if (isReturned()) {
            return 'BTL Approval Returned';
        }
        return 'BTL Approval Process Completed';
    }

    public String getMailSubtitle() {
        if (isApprovalRequired()) {
            return 'A BTL activity is waiting for your approval.';
        }
        if (isReturned()) {
            return 'The BTL activity has been returned for correction and resubmission.';
        }
        return getIsDropped()
            ? 'The BTL approval process has been closed because the returned activity was dropped.'
            : 'The BTL approval process has been completed successfully.';
    }

    public String getStatusLabel() {
        if (isApprovalRequired()) {
            return 'Pending Approval';
        }
        if (isReturned()) {
            return 'Returned';
        }
        return getIsDropped()
            ? 'Dropped'
            : 'Approved';
    }

    public String getRecipientName() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        if (row == null) {
            return 'User';
        }

        if (isApprovalRequired()) {
            return row.Pending_With__r == null
                ? 'User'
                : displayValue(row.Pending_With__r.Name);
        }

        return row.Submitted_By__r == null
            ? 'User'
            : displayValue(row.Submitted_By__r.Name);
    }

    public String getActivityNumber() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null || row.Form_Activity__r == null
            ? '—'
            : displayValue(row.Form_Activity__r.Name);
    }

    public String getActivityName() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null || row.Form_Activity__r == null
            ? '—'
            : displayValue(row.Form_Activity__r.Activity_Name__c);
    }

    public String getStoreName() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null ||
            row.Form_Activity_Assigned_Persons_Date__r == null ||
            row.Form_Activity_Assigned_Persons_Date__r.Store__r == null
                ? '—'
                : displayValue(
                    row.Form_Activity_Assigned_Persons_Date__r.Store__r.Name
                );
    }

    public String getTargetDate() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        Date value = row == null ||
            row.Form_Activity_Assigned_Persons_Date__r == null
                ? null
                : row.Form_Activity_Assigned_Persons_Date__r.Target_Date__c;
        return value == null
            ? '—'
            : value.format();
    }

    public String getTeamName() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null || row.Form_Activity_Assigned_Persons__r == null
            ? '—'
            : displayValue(
                row.Form_Activity_Assigned_Persons__r.Team_Name__c
            );
    }

    public String getActivityLocation() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null ||
            row.Form_Activity_Assigned_Persons_Date__r == null
                ? '—'
                : displayValue(
                    row.Form_Activity_Assigned_Persons_Date__r
                        .Activity_Location__c
                );
    }

    public String getFinalCustomizeFormNo() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null ||
            row.Form_Activity__r == null ||
            row.Form_Activity__r.Final_Customize_Form__r == null
                ? '—'
                : displayValue(
                    row.Form_Activity__r.Final_Customize_Form__r.Name
                );
    }

    public String getSubmittedByName() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null || row.Submitted_By__r == null
            ? '—'
            : displayValue(row.Submitted_By__r.Name);
    }

    public String getSubmittedDateTimeIST() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return formatIST(
            row == null ? null : row.Submitted_Date_Time__c
        );
    }

    public String getCurrentLevelName() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null || row.Current_Approval_Level__r == null
            ? '—'
            : displayValue(
                row.Current_Approval_Level__r.Responsible_Team__c
            );
    }

    public String getPendingWithName() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null || row.Pending_With__r == null
            ? '—'
            : displayValue(row.Pending_With__r.Name);
    }

    public String getReturnedFromLevelName() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null || row.Returned_From_Level__r == null
            ? '—'
            : displayValue(
                row.Returned_From_Level__r.Responsible_Team__c
            );
    }

    public String getLastActionByName() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null || row.Last_Action_By__r == null
            ? '—'
            : displayValue(row.Last_Action_By__r.Name);
    }

    public String getLastActionDateTimeIST() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return formatIST(
            row == null ? null : row.Last_Action_Date_Time__c
        );
    }

    public String getLastActionComments() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null
            ? '—'
            : displayValue(row.Last_Action_Comments__c);
    }

    public String getCompletedByName() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        if (row == null) {
            return '—';
        }

        if (getIsDropped()) {
            return row.Dropped_By__r == null
                ? getLastActionByName()
                : displayValue(row.Dropped_By__r.Name);
        }

        return row.Final_Approved_By__r == null
            ? getLastActionByName()
            : displayValue(row.Final_Approved_By__r.Name);
    }

    public String getCompletedDateTimeIST() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        if (row == null) {
            return '—';
        }

        return formatIST(
            getIsDropped()
                ? row.Dropped_Date_Time__c
                : row.Final_Approved_Date_Time__c
        );
    }

    public String getSubmissionCycle() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null || row.Submission_Cycle__c == null
            ? '—'
            : String.valueOf(row.Submission_Cycle__c);
    }

    public String getExecutiveName() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null ||
            row.Form_Activity_Assigned_Persons__r == null ||
            row.Form_Activity_Assigned_Persons__r.Sales_Executives__r == null
                ? '—'
                : displayValue(
                    row.Form_Activity_Assigned_Persons__r
                        .Sales_Executives__r.Name
                );
    }

    public String getAssignedPersonNo() {
        Tagged_Approval_Hierarchy__c row = getAnchor();
        return row == null || row.Form_Activity_Assigned_Persons__r == null
            ? '—'
            : displayValue(row.Form_Activity_Assigned_Persons__r.Name);
    }

    public String getWorkspaceUrl() {
        return buildWorkspaceUrl(inputTransactionId);
    }

    private Boolean isApprovalRequired() {
        return String.valueOf(inputMailType).trim().toUpperCase() ==
            'APPROVAL_REQUIRED';
    }

    private Boolean isReturned() {
        return String.valueOf(inputMailType).trim().toUpperCase() ==
            'RETURNED';
    }

    private static String buildWorkspaceUrl(Id targetTransactionId) {
        if (targetTransactionId == null) {
            return null;
        }

        return URL.getOrgDomainUrl().toExternalForm() +
            '/lightning/cmp/c__lwc_btlApprovalWorkspace' +
            '?c__transactionId=' +
            EncodingUtil.urlEncode(
                String.valueOf(targetTransactionId),
                'UTF-8'
            );
    }

    private static String formatIST(Datetime value) {
        return value == null
            ? '—'
            : value.format(
                'dd-MMM-yyyy hh:mm a',
                'Asia/Kolkata'
            ) + ' IST';
    }

    private static String displayValue(String value) {
        return String.isBlank(value)
            ? '—'
            : value;
    }
}