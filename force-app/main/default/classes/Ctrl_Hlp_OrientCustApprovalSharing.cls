public without sharing class Ctrl_Hlp_OrientCustApprovalSharing {

    private static final String ACCESS_READ = 'Read';
    private static final String ACCESS_EDIT = 'Edit';

    /*
     * Preferred Apex Sharing Reason.
     * If it isn't configured on the custom object, the generic helper
     * automatically falls back to Manual.
     */
    private static final String PREFERRED_ROW_CAUSE =
        'Customer_Approval_Access__c';

    public static void syncApprovalAccess(
        Id approvalTransactionId
    ) {
        if (approvalTransactionId == null) {
            return;
        }

        List<Tagged_Approval_Hierarchy__c> transactions = [
            SELECT Id,
                   Pending_With__c,
                   Submitted_By__c,
                   Customer_Change_Request__c
            FROM Tagged_Approval_Hierarchy__c
            WHERE Id = :approvalTransactionId
            LIMIT 1
        ];

        if (transactions.isEmpty()) {
            return;
        }

        Tagged_Approval_Hierarchy__c transactionRecord =
            transactions[0];

        if (transactionRecord.Customer_Change_Request__c == null) {
            return;
        }

        /*
         * Build the approval participant list from the transaction history.
         *
         * Current Pending_With:
         *     EDIT
         *
         * Previous Action_By / Assigned_To participants:
         *     READ
         *
         * The submitter is excluded because the submitter normally owns the
         * approval transaction records and already has owner access.
         */
        List<Approval_Action_History__c> histories = [
            SELECT Id,
                   Action_By__c,
                   Assigned_To__c
            FROM Approval_Action_History__c
            WHERE Approval_Transaction__c = :approvalTransactionId
        ];

        Set<Id> participantIds = new Set<Id>();

        if (transactionRecord.Pending_With__c != null) {
            participantIds.add(
                transactionRecord.Pending_With__c
            );
        }

        for (Approval_Action_History__c historyRecord : histories) {
            if (historyRecord.Action_By__c != null) {
                participantIds.add(
                    historyRecord.Action_By__c
                );
            }

            if (historyRecord.Assigned_To__c != null) {
                participantIds.add(
                    historyRecord.Assigned_To__c
                );
            }
        }

        participantIds.remove(
            transactionRecord.Submitted_By__c
        );

        if (participantIds.isEmpty()) {
            return;
        }

        Map<Id, String> accessByParticipant =
            new Map<Id, String>();

        for (Id participantId : participantIds) {
            accessByParticipant.put(
                participantId,
                ACCESS_READ
            );
        }

        if (transactionRecord.Pending_With__c != null) {
            accessByParticipant.put(
                transactionRecord.Pending_With__c,
                ACCESS_EDIT
            );
        }

        /*
         * CORRECT OWD:
         *
         * Orient Customer Change Request = Private
         * Tagged Approval Hierarchy      = Private
         *
         * These are the only transaction parent objects that need explicit
         * Apex sharing for internal approvers.
         */
        Ctrl_Hlp_RecordSharing.syncAccess(
            'Orient_Customer_Change_Request__c',
            new Set<Id>{
                transactionRecord.Customer_Change_Request__c
            },
            accessByParticipant,
            PREFERRED_ROW_CAUSE
        );

        Ctrl_Hlp_RecordSharing.syncAccess(
            'Tagged_Approval_Hierarchy__c',
            new Set<Id>{
                transactionRecord.Id
            },
            accessByParticipant,
            PREFERRED_ROW_CAUSE
        );

        /*
         * No direct sharing required:
         *
         * Orient Customer Change Item = Controlled by Parent
         * Approval Action History     = Controlled by Parent
         *
         * Their visibility follows their parent record.
         *
         * Also no explicit sharing is required for Account, Customer
         * Tracking, Store, Approval Hierarchy, Hierarchy Level or Approver
         * Mapping because their INTERNAL OWD already supplies sufficient
         * Read / Read-Write access.
         */
    }
}