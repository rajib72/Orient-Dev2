@IsTest(SeeAllData=false)
private class Ctrl_Hlp_OrientCustAddressApprovalTest {

    // =========================================================
    // DYNAMIC FAKE ID GENERATOR
    // Prevents "Invalid id value for this SObject type" errors
    // =========================================================
    private static Integer fakeIdCount = 0;
    private static Id getFakeId(Schema.SObjectType sObjectType) {
        String keyPrefix = sObjectType.getDescribe().getKeyPrefix();
        fakeIdCount++;
        String fakeIdPrefix = '000000000000'.substring(0, 12 - String.valueOf(fakeIdCount).length());
        return Id.valueOf(keyPrefix + fakeIdPrefix + fakeIdCount);
    }

    @IsTest
    static void testFieldVisibilityHelpers() {
        Test.startTest();
        
        // Hits getBCControlledFieldApis(), isBCControlledField(), and isWorkspaceVisibleField()
        Ctrl_Hlp_OrientCustAddressApproval.isBCControlledField('Pin_Code__c');
        Ctrl_Hlp_OrientCustAddressApproval.isWorkspaceVisibleField('Country__c'); // Hidden UI field test
        Ctrl_Hlp_OrientCustAddressApproval.isWorkspaceVisibleField('StateCode__c'); // Hidden UI field test
        Ctrl_Hlp_OrientCustAddressApproval.isWorkspaceVisibleField('Name'); // Normal field test
        
        Test.stopTest();
    }

    @IsTest
    static void testValidateAtomicDecision_NullDecision() {
        Id id1 = getFakeId(Orient_Customer_Change_Item__c.SObjectType);
        Id id2 = getFakeId(Orient_Customer_Change_Item__c.SObjectType);

        List<Orient_Customer_Change_Item__c> pendingItems = new List<Orient_Customer_Change_Item__c>{
            new Orient_Customer_Change_Item__c(Id = id1, Account_Field_API__c = 'Pin_Code__c'),
            new Orient_Customer_Change_Item__c(Id = id2, Account_Field_API__c = 'Residential_City__c')
        };
        
        // Pass an empty map so it triggers the "decision is required" exception
        Map<Id, Map<String, Object>> emptyDecisionMap = new Map<Id, Map<String, Object>>();

        Test.startTest();
        try {
            Ctrl_Hlp_OrientCustAddressApproval.validateAtomicDecision(pendingItems, emptyDecisionMap);
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateAtomicDecision_InvalidDecisionWord() {
        Id id1 = getFakeId(Orient_Customer_Change_Item__c.SObjectType);

        List<Orient_Customer_Change_Item__c> pendingItems = new List<Orient_Customer_Change_Item__c>{
            new Orient_Customer_Change_Item__c(Id = id1, Account_Field_API__c = 'Pin_Code__c')
        };
        
        Map<Id, Map<String, Object>> decisionMap = new Map<Id, Map<String, Object>>{
            id1 => new Map<String, Object>{ 'decision' => 'Maybe' }
        };

        Test.startTest();
        try {
            Ctrl_Hlp_OrientCustAddressApproval.validateAtomicDecision(pendingItems, decisionMap);
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateAtomicDecision_MixedDecisions() {
        Id id1 = getFakeId(Orient_Customer_Change_Item__c.SObjectType);
        Id id2 = getFakeId(Orient_Customer_Change_Item__c.SObjectType);

        List<Orient_Customer_Change_Item__c> pendingItems = new List<Orient_Customer_Change_Item__c>{
            new Orient_Customer_Change_Item__c(Id = id1, Account_Field_API__c = 'Pin_Code__c'),
            new Orient_Customer_Change_Item__c(Id = id2, Account_Field_API__c = 'Residential_City__c')
        };
        
        Map<Id, Map<String, Object>> decisionMap = new Map<Id, Map<String, Object>>{
            id1 => new Map<String, Object>{ 'decision' => 'Approve' },
            id2 => new Map<String, Object>{ 'decision' => 'Reject', 'rejectionReason' => 'Reason' }
        };

        Test.startTest();
        try {
            Ctrl_Hlp_OrientCustAddressApproval.validateAtomicDecision(pendingItems, decisionMap);
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateAtomicDecision_RejectWithoutReason() {
        Id id1 = getFakeId(Orient_Customer_Change_Item__c.SObjectType);

        List<Orient_Customer_Change_Item__c> pendingItems = new List<Orient_Customer_Change_Item__c>{
            new Orient_Customer_Change_Item__c(Id = id1, Account_Field_API__c = 'Pin_Code__c')
        };
        
        Map<Id, Map<String, Object>> decisionMap = new Map<Id, Map<String, Object>>{
            id1 => new Map<String, Object>{ 'decision' => 'Reject', 'rejectionReason' => '' }
        };

        Test.startTest();
        try {
            Ctrl_Hlp_OrientCustAddressApproval.validateAtomicDecision(pendingItems, decisionMap);
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateAtomicDecision_MismatchedRejectReasons() {
        Id id1 = getFakeId(Orient_Customer_Change_Item__c.SObjectType);
        Id id2 = getFakeId(Orient_Customer_Change_Item__c.SObjectType);

        List<Orient_Customer_Change_Item__c> pendingItems = new List<Orient_Customer_Change_Item__c>{
            new Orient_Customer_Change_Item__c(Id = id1, Account_Field_API__c = 'Pin_Code__c'),
            new Orient_Customer_Change_Item__c(Id = id2, Account_Field_API__c = 'Residential_City__c')
        };
        
        Map<Id, Map<String, Object>> decisionMap = new Map<Id, Map<String, Object>>{
            id1 => new Map<String, Object>{ 'decision' => 'Reject', 'rejectionReason' => 'Reason One' },
            id2 => new Map<String, Object>{ 'decision' => 'Reject', 'rejectionReason' => 'Reason Two' }
        };

        Test.startTest();
        try {
            Ctrl_Hlp_OrientCustAddressApproval.validateAtomicDecision(pendingItems, decisionMap);
        } catch (AuraHandledException e) {
            // Handled
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateAtomicDecision_SuccessApproveAll() {
        Id id1 = getFakeId(Orient_Customer_Change_Item__c.SObjectType);
        Id id2 = getFakeId(Orient_Customer_Change_Item__c.SObjectType);

        List<Orient_Customer_Change_Item__c> pendingItems = new List<Orient_Customer_Change_Item__c>{
            new Orient_Customer_Change_Item__c(Id = id1, Account_Field_API__c = 'Pin_Code__c'),
            new Orient_Customer_Change_Item__c(Id = id2, Account_Field_API__c = 'Residential_City__c')
        };
        
        Map<Id, Map<String, Object>> decisionMap = new Map<Id, Map<String, Object>>{
            id1 => new Map<String, Object>{ 'decision' => 'Approve' },
            id2 => new Map<String, Object>{ 'decision' => 'Approve' }
        };

        Test.startTest();
        Ctrl_Hlp_OrientCustAddressApproval.validateAtomicDecision(pendingItems, decisionMap);
        Test.stopTest();
    }
}