@IsTest
public class AddFamilyMemberControllerRevisedTest {

    @TestSetup
    static void setupTestData() {

        Account currentAcc = new Account();
        currentAcc.Name = 'Current Customer';
        currentAcc.Phone = '9876543210';
        insert currentAcc;

        Account existingFamilyAcc = new Account();
        existingFamilyAcc.Name = 'Existing Family Member';
        existingFamilyAcc.Phone = '8888888888';
        insert existingFamilyAcc;

        Account duplicateFamilyAcc = new Account();
        duplicateFamilyAcc.Name = 'Duplicate Family Member';
        duplicateFamilyAcc.Phone = '7777777777';
        insert duplicateFamilyAcc;
    }

    @IsTest
    static void testGetCurrentAccountSuccess() {

        Account acc = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Phone = '9876543210'
            LIMIT 1
        ];

        Test.startTest();
        Account result = AddFamilyMemberControllerRevised.getCurrentAccount(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Account should not be null');
        System.assertEquals(acc.Id, result.Id, 'Same account should be returned');
        System.assertEquals('Current Customer', result.Name, 'Account name should match');
    }

    @IsTest
    static void testGetCurrentAccountMissingId() {

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            AddFamilyMemberControllerRevised.getCurrentAccount(null);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for missing Account Id');
    }

    @IsTest
    static void testSearchAccountsByPhoneSuccess() {

        Test.startTest();
        List<AddFamilyMemberControllerRevised.AccountWrapper> resultList =
            AddFamilyMemberControllerRevised.searchAccountsByPhone('888');
        Test.stopTest();

        System.assertNotEquals(null, resultList, 'Result list should not be null');
        System.assertEquals(1, resultList.size(), 'One matching account should be returned');
        System.assertEquals('Existing Family Member', resultList[0].name);
        System.assertEquals('8888888888', resultList[0].phone);
    }

    @IsTest
    static void testSearchAccountsByPhoneBlank() {

        Test.startTest();
        List<AddFamilyMemberControllerRevised.AccountWrapper> resultList =
            AddFamilyMemberControllerRevised.searchAccountsByPhone('');
        Test.stopTest();

        System.assertNotEquals(null, resultList, 'Result list should not be null');
        System.assertEquals(0, resultList.size(), 'Blank phone should return empty list');
    }

    @IsTest
    static void testSearchAccountsByPhoneLessThanThreeDigits() {

        Test.startTest();
        List<AddFamilyMemberControllerRevised.AccountWrapper> resultList =
            AddFamilyMemberControllerRevised.searchAccountsByPhone('88');
        Test.stopTest();

        System.assertNotEquals(null, resultList, 'Result list should not be null');
        System.assertEquals(0, resultList.size(), 'Less than 3 digits should return empty list');
    }

   @IsTest
static void testSearchAccountsByPhoneWithFormattedInput() {

    Account acc = new Account();
    acc.Name = 'Formatted Search Customer';
    acc.Phone = '9123456780';
    insert acc;

    Test.startTest();
    List<AddFamilyMemberControllerRevised.AccountWrapper> resultList =
        AddFamilyMemberControllerRevised.searchAccountsByPhone('91234');
    Test.stopTest();

    System.assertNotEquals(null, resultList, 'Result should not be null');
    System.assert(resultList.size() > 0, 'Phone search should return matching account');
}
    @IsTest
    static void testSaveFamilyMemberWithNewAccount() {

        Account currentAcc = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Phone = '9876543210'
            LIMIT 1
        ];

        Test.startTest();
        AddFamilyMemberControllerRevised.SaveResponse response =
            AddFamilyMemberControllerRevised.saveFamilyMember(
                currentAcc.Id,
                'Male',
                '9999999999',
                'New Family Member',
                'Brother',
                null
            );
        Test.stopTest();

        System.assertEquals(true, response.success, 'Response success should be true');
        System.assertEquals('Family member added successfully.', response.message);

        Account newFamilyAcc = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Phone = '9999999999'
            LIMIT 1
        ];

        System.assertEquals('New Family Member', newFamilyAcc.Name);

        List<Contact> contacts = [
            SELECT Id, AccountId, Phone, MobilePhone
            FROM Contact
            WHERE AccountId IN :new Set<Id>{ currentAcc.Id, newFamilyAcc.Id }
        ];

        System.assertEquals(2, contacts.size(), 'Self contacts should be created for both accounts');

        List<Relationship__c> relations = [
            SELECT Id, Orient_Customer__c, Family_Member__c, Relationship_Type__c
            FROM Relationship__c
            WHERE Orient_Customer__c IN :new Set<Id>{ currentAcc.Id, newFamilyAcc.Id }
        ];

        System.assertEquals(2, relations.size(), 'Forward and reverse relationships should be created');
    }

    @IsTest
    static void testSaveFamilyMemberWithExistingAccount() {

        Account currentAcc = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Phone = '9876543210'
            LIMIT 1
        ];

        Account existingFamilyAcc = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Phone = '8888888888'
            LIMIT 1
        ];

        Test.startTest();
        AddFamilyMemberControllerRevised.SaveResponse response =
            AddFamilyMemberControllerRevised.saveFamilyMember(
                currentAcc.Id,
                'Female',
                '8888888888',
                'Existing Family Member',
                'Sister',
                existingFamilyAcc.Id
            );
        Test.stopTest();

        System.assertEquals(true, response.success, 'Response success should be true');
        System.assertEquals('Family member added successfully.', response.message);

        List<Relationship__c> relations = [
            SELECT Id, Orient_Customer__c, Relationship_Type__c
            FROM Relationship__c
            WHERE Orient_Customer__c IN :new Set<Id>{ currentAcc.Id, existingFamilyAcc.Id }
        ];

        System.assertEquals(2, relations.size(), 'Forward and reverse relationship records should be created');
    }

    @IsTest
    static void testSaveFamilyMemberWithFormattedPhoneNumber() {

        Account currentAcc = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Phone = '9876543210'
            LIMIT 1
        ];

        Test.startTest();
        AddFamilyMemberControllerRevised.SaveResponse response =
            AddFamilyMemberControllerRevised.saveFamilyMember(
                currentAcc.Id,
                'Male',
                '+91 91234-56789',
                'Formatted Phone Family',
                'Friend',
                null
            );
        Test.stopTest();

        System.assertEquals(true, response.success, 'Formatted phone should be normalized and saved');

        Account familyAcc = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Phone = '9123456789'
            LIMIT 1
        ];

        System.assertEquals('Formatted Phone Family', familyAcc.Name);
        System.assertEquals('9123456789', familyAcc.Phone);
    }

    @IsTest
    static void testSaveFamilyMemberMissingCurrentAccountId() {

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            AddFamilyMemberControllerRevised.saveFamilyMember(
                null,
                'Male',
                '9999999999',
                'Test Family',
                'Brother',
                null
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for missing current account id');
    }

    @IsTest
    static void testSaveFamilyMemberMissingGender() {

        Account currentAcc = [
            SELECT Id
            FROM Account
            WHERE Phone = '9876543210'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            AddFamilyMemberControllerRevised.saveFamilyMember(
                currentAcc.Id,
                '',
                '9999999999',
                'Test Family',
                'Brother',
                null
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for missing gender');
    }

    @IsTest
    static void testSaveFamilyMemberMissingPhone() {

        Account currentAcc = [
            SELECT Id
            FROM Account
            WHERE Phone = '9876543210'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            AddFamilyMemberControllerRevised.saveFamilyMember(
                currentAcc.Id,
                'Male',
                '',
                'Test Family',
                'Brother',
                null
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for missing phone');
    }

    @IsTest
    static void testSaveFamilyMemberInvalidPhoneLength() {

        Account currentAcc = [
            SELECT Id
            FROM Account
            WHERE Phone = '9876543210'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            AddFamilyMemberControllerRevised.saveFamilyMember(
                currentAcc.Id,
                'Male',
                '12345',
                'Test Family',
                'Brother',
                null
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for invalid phone length');
    }

    @IsTest
    static void testSaveFamilyMemberMissingRelationshipType() {

        Account currentAcc = [
            SELECT Id
            FROM Account
            WHERE Phone = '9876543210'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            AddFamilyMemberControllerRevised.saveFamilyMember(
                currentAcc.Id,
                'Male',
                '9999999999',
                'Test Family',
                '',
                null
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for missing relationship type');
    }

    @IsTest
    static void testSaveFamilyMemberSamePhoneAsCurrentCustomer() {

        Account currentAcc = [
            SELECT Id
            FROM Account
            WHERE Phone = '9876543210'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            AddFamilyMemberControllerRevised.saveFamilyMember(
                currentAcc.Id,
                'Male',
                '9876543210',
                'Same Customer',
                'Brother',
                null
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for same phone as current customer');
    }

    @IsTest
    static void testSaveFamilyMemberSelectedAccountPhoneMismatch() {

        Account currentAcc = [
            SELECT Id
            FROM Account
            WHERE Phone = '9876543210'
            LIMIT 1
        ];

        Account existingFamilyAcc = [
            SELECT Id
            FROM Account
            WHERE Phone = '8888888888'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            AddFamilyMemberControllerRevised.saveFamilyMember(
                currentAcc.Id,
                'Male',
                '9999999999',
                'Existing Family Member',
                'Brother',
                existingFamilyAcc.Id
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown when selected account phone does not match entered phone');
    }

    @IsTest
    static void testSaveFamilyMemberMissingFamilyMemberNameForNewAccount() {

        Account currentAcc = [
            SELECT Id
            FROM Account
            WHERE Phone = '9876543210'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            AddFamilyMemberControllerRevised.saveFamilyMember(
                currentAcc.Id,
                'Male',
                '6666666666',
                '',
                'Brother',
                null
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown when new family member name is blank');
    }

    @IsTest
    static void testSaveFamilyMemberDuplicateRelation() {

        Account currentAcc = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Phone = '9876543210'
            LIMIT 1
        ];

        Account duplicateFamilyAcc = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Phone = '7777777777'
            LIMIT 1
        ];

        Contact duplicateFamilyContact = new Contact();
        duplicateFamilyContact.LastName = duplicateFamilyAcc.Name;
        duplicateFamilyContact.AccountId = duplicateFamilyAcc.Id;
        duplicateFamilyContact.Phone = duplicateFamilyAcc.Phone;
        duplicateFamilyContact.MobilePhone = duplicateFamilyAcc.Phone;
        insert duplicateFamilyContact;

        Relationship__c existingRelation = new Relationship__c();
        existingRelation.Orient_Customer__c = currentAcc.Id;
        existingRelation.Family_Member__c = duplicateFamilyContact.Id;
        existingRelation.Relationship_Type__c = 'Brother';
        insert existingRelation;

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            AddFamilyMemberControllerRevised.saveFamilyMember(
                currentAcc.Id,
                'Male',
                '7777777777',
                'Duplicate Family Member',
                'Brother',
                duplicateFamilyAcc.Id
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Exception should be thrown for duplicate relationship'
        );
    }

    // -------------------------------------------------------------------------
    // Helper methods for extra coverage
    // -------------------------------------------------------------------------

    private static Account createTestAccount(String name, String phone) {
        Account acc = new Account();
        acc.Name = name;
        acc.Phone = phone;
        insert acc;
        return acc;
    }

    private static Contact createSelfContact(Account acc) {
        Contact con = new Contact();
        con.LastName = acc.Name;
        con.AccountId = acc.Id;
        con.Phone = acc.Phone;
        con.MobilePhone = acc.Phone;
        insert con;
        return con;
    }

    private static void createRelationship(Account ownerAcc, Account familyAcc, String relationType) {
        Contact familyContact = createSelfContact(familyAcc);

        Relationship__c rel = new Relationship__c();
        rel.Orient_Customer__c = ownerAcc.Id;
        rel.Family_Member__c = familyContact.Id;
        rel.Relationship_Type__c = relationType;
        insert rel;
    }

    private static void runInferenceScenario(
        String currentPhone,
        String existingPhone,
        String newPhone,
        String currentGender,
        String currentToExistingRelation,
        String existingToCurrentRelation,
        String newMemberRelation
    ) {
        Account currentAcc = createTestAccount(
            'Current Customer ' + currentPhone,
            currentPhone
        );

        Account existingFamilyAcc = createTestAccount(
            'Existing Family ' + existingPhone,
            existingPhone
        );

        createRelationship(currentAcc, existingFamilyAcc, currentToExistingRelation);
        createRelationship(existingFamilyAcc, currentAcc, existingToCurrentRelation);

        AddFamilyMemberControllerRevised.SaveResponse response =
            AddFamilyMemberControllerRevised.saveFamilyMember(
                currentAcc.Id,
                currentGender,
                newPhone,
                'New Family ' + newPhone,
                newMemberRelation,
                null
            );

        System.assertEquals(true, response.success, 'Family member should be added successfully');

        List<Relationship__c> relList = [
            SELECT Id, Orient_Customer__c, Family_Member__c, Relationship_Type__c
            FROM Relationship__c
            WHERE Orient_Customer__c IN :new Set<Id>{ currentAcc.Id, existingFamilyAcc.Id }
        ];

        System.assert(relList.size() >= 4, 'Family tree sync should create additional relationship records');
    }

    @IsTest
    static void testFamilyTreeInferenceBranchSetOne() {

        Test.startTest();

        runInferenceScenario(
            '9200000001',
            '9200000002',
            '9200000003',
            'Female',
            'Son',
            'Mother',
            'Husband'
        );

        runInferenceScenario(
            '9200000004',
            '9200000005',
            '9200000006',
            'Male',
            'Daughter',
            'Father',
            'Wife'
        );

        runInferenceScenario(
            '9200000007',
            '9200000008',
            '9200000009',
            'Female',
            'Sister',
            'Sister',
            'Maternal Grandmother'
        );

        Test.stopTest();
    }

    @IsTest
    static void testFamilyTreeInferenceBranchSetTwo() {

        Test.startTest();

        runInferenceScenario(
            '9300000001',
            '9300000002',
            '9300000003',
            'Male',
            'Son',
            'Father',
            'Mother'
        );

        runInferenceScenario(
            '9300000004',
            '9300000005',
            '9300000006',
            'Male',
            'Father',
            'Son',
            'Daughter'
        );

        runInferenceScenario(
            '9300000007',
            '9300000008',
            '9300000009',
            'Female',
            'Wife',
            'Husband',
            'Father'
        );

        Test.stopTest();
    }

    @IsTest
    static void testFamilyTreeInferenceBranchSetThree() {

        Test.startTest();

        runInferenceScenario(
            '9400000001',
            '9400000002',
            '9400000003',
            'Male',
            'Brother',
            'Brother',
            'Son'
        );

        runInferenceScenario(
            '9400000004',
            '9400000005',
            '9400000006',
            'Female',
            'Mother',
            'Daughter',
            'Sister'
        );

        runInferenceScenario(
            '9400000007',
            '9400000008',
            '9400000009',
            'Female',
            'Aunt',
            'Niece',
            'Daughter'
        );

        Test.stopTest();
    }

    @IsTest
    static void testFamilyTreeInferenceFriendBranch() {

        Test.startTest();

        runInferenceScenario(
            '9500000001',
            '9500000002',
            '9500000003',
            'Male',
            'Friend',
            'Friend',
            'Friend'
        );

        Test.stopTest();
    }
}