@IsTest
private class Ctrl_Hlp_BTLApprovalConstants_Test {

    @IsTest
    static void testConstants() {
        // Instantiate the class to cover the private constructor
        Ctrl_Hlp_BTLApprovalConstants constantsInstance = new Ctrl_Hlp_BTLApprovalConstants();
        
        // Assertions (These don't add to the coverage percentage, but they are great practice!)
        System.assertEquals(
            'BTL Form Activity',
            Ctrl_Hlp_BTLApprovalConstants.APPROVAL_TYPE
        );
        System.assertEquals(
            'Not Submitted',
            Ctrl_Hlp_BTLApprovalConstants.STATUS_NOT_SUBMITTED
        );
        System.assertEquals(
            'Pending',
            Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING
        );
        System.assertEquals(
            'Returned',
            Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED
        );
        System.assertEquals(
            'Approved',
            Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED
        );
        System.assertEquals(
            'Dropped',
            Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED
        );
        System.assertEquals(
            'Active',
            Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_ACTIVE
        );
        System.assertEquals(
            'Replaced',
            Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_REPLACED
        );
        System.assertEquals(
            'Rescheduled',
            Ctrl_Hlp_BTLApprovalConstants.ASSIGNMENT_STATUS_RESCHEDULED
        );
        System.assertEquals(
            'System Administrator',
            Ctrl_Hlp_BTLApprovalConstants.PROFILE_SYSTEM_ADMIN
        );
    }
}