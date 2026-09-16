public with sharing class AddFamilyMemberControllerRevised {

    public class AccountWrapper {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String name;
        @AuraEnabled public String phone;

        public AccountWrapper(Account acc) {
            accountId = acc.Id;
            name = acc.Name;
            phone = acc.Phone;
        }
    }

    public class SaveResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=true)
    public static Account getCurrentAccount(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Account Id is missing.');
        }

        return [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<AccountWrapper> searchAccountsByPhone(String phone) {
        List<AccountWrapper> result = new List<AccountWrapper>();

        if (String.isBlank(phone)) {
            return result;
        }

        String cleanPhone = normalizePhone(phone);

        if (String.isBlank(cleanPhone) || cleanPhone.length() < 3) {
            return result;
        }

        String likePhone = '%' + cleanPhone + '%';

        List<Account> accList = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Phone LIKE :likePhone
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ];

        for (Account acc : accList) {
            result.add(new AccountWrapper(acc));
        }

        return result;
    }

    @AuraEnabled
    public static SaveResponse saveFamilyMember(
        Id currentAccountId,
        String currentAccountGender,
        String phone,
        String familyMemberName,
        String relationshipType,
        Id selectedExistingAccountId
    ) {
        SaveResponse res = new SaveResponse();
        res.success = false;

        try {
            if (currentAccountId == null) {
                throw new AuraHandledException('Current Account Id is missing.');
            }

            if (String.isBlank(currentAccountGender)) {
                throw new AuraHandledException('Please select current account gender.');
            }

            if (String.isBlank(phone)) {
                throw new AuraHandledException('Please enter phone number.');
            }

            String cleanPhone = normalizePhone(phone);

            if (cleanPhone.length() != 10) {
                throw new AuraHandledException('Please enter valid 10 digit phone number.');
            }

            if (String.isBlank(relationshipType)) {
                throw new AuraHandledException('Please select relationship type.');
            }

            Account currentAcc = [
                SELECT Id, Name, Phone
                FROM Account
                WHERE Id = :currentAccountId
                LIMIT 1
            ];

            String currentAccPhone = normalizePhone(currentAcc.Phone);

            if (!String.isBlank(currentAccPhone) && currentAccPhone == cleanPhone) {
                throw new AuraHandledException('Please input different phone number. This phone number belongs to current customer.');
            }

            Account familyAcc;

            if (selectedExistingAccountId != null) {
                familyAcc = [
                    SELECT Id, Name, Phone
                    FROM Account
                    WHERE Id = :selectedExistingAccountId
                    LIMIT 1
                ];

                String selectedAccPhone = normalizePhone(familyAcc.Phone);

                if (selectedAccPhone != cleanPhone) {
                    throw new AuraHandledException('Selected account phone number does not match with entered phone number.');
                }
            } else {
                List<Account> existingAccList = [
                    SELECT Id, Name, Phone
                    FROM Account
                    WHERE Phone = :cleanPhone
                    LIMIT 1
                ];

                if (!existingAccList.isEmpty()) {
                    familyAcc = existingAccList[0];
                } else {
                    if (String.isBlank(familyMemberName)) {
                        throw new AuraHandledException('Please enter family member name.');
                    }

                    familyAcc = new Account();
                    familyAcc.Name = familyMemberName.trim();
                    familyAcc.Phone = cleanPhone;
                    insert familyAcc;
                }
            }

            if (familyAcc.Id == currentAcc.Id) {
                throw new AuraHandledException('Please select or create a different family member account.');
            }

            Contact currentContact = getOrCreateSelfContact(currentAcc);
            Contact familyContact = getOrCreateSelfContact(familyAcc);

            Boolean alreadyExists = checkRelationAlreadyExists(currentAcc.Id, familyAcc.Id);

            if (alreadyExists) {
                throw new AuraHandledException('Relation with this phone number already exists for this customer.');
            }

            createOrUpdateRelationship(
                currentAcc.Id,
                familyContact.Id,
                relationshipType
            );

            String reverseRelation = getReverseRelation(relationshipType, currentAccountGender);

            createOrUpdateRelationship(
                familyAcc.Id,
                currentContact.Id,
                reverseRelation
            );

            syncCompleteFamilyTree(currentAcc.Id, familyAcc.Id);

            res.success = true;
            res.message = 'Family member added successfully.';
            return res;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error while adding family member: ' + e.getMessage());
        }
    }

    private static Contact getOrCreateSelfContact(Account acc) {
        String cleanPhone = normalizePhone(acc.Phone);

        List<Contact> conList;

        if (!String.isBlank(cleanPhone)) {
            conList = [
                SELECT Id, FirstName, LastName, Phone, MobilePhone, AccountId
                FROM Contact
                WHERE AccountId = :acc.Id
                AND (
                    Phone = :cleanPhone
                    OR MobilePhone = :cleanPhone
                )
                LIMIT 1
            ];
        } else {
            conList = [
                SELECT Id, FirstName, LastName, Phone, MobilePhone, AccountId
                FROM Contact
                WHERE AccountId = :acc.Id
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
        }

        if (!conList.isEmpty()) {
            return conList[0];
        }

        Contact con = new Contact();
        con.LastName = acc.Name;
        con.AccountId = acc.Id;

        if (!String.isBlank(cleanPhone)) {
            con.Phone = cleanPhone;
            con.MobilePhone = cleanPhone;
        }

        insert con;
        return con;
    }

    private static Boolean checkRelationAlreadyExists(Id currentAccountId, Id familyAccountId) {
        if (currentAccountId == null || familyAccountId == null) {
            return false;
        }

        List<Relationship__c> existingRelationList = [
            SELECT Id
            FROM Relationship__c
            WHERE Orient_Customer__c = :currentAccountId
            AND Family_Member__r.AccountId = :familyAccountId
            LIMIT 1
        ];

        return !existingRelationList.isEmpty();
    }

    private static void createOrUpdateRelationship(Id orientCustomerId, Id familyMemberContactId, String relationType) {
        if (orientCustomerId == null || familyMemberContactId == null) {
            return;
        }

        List<Relationship__c> existingList = [
            SELECT Id, Relationship_Type__c
            FROM Relationship__c
            WHERE Orient_Customer__c = :orientCustomerId
            AND Family_Member__c = :familyMemberContactId
            LIMIT 1
        ];

        if (!existingList.isEmpty()) {
            Relationship__c rel = existingList[0];

            if (rel.Relationship_Type__c != relationType) {
                rel.Relationship_Type__c = relationType;
                update rel;
            }

            return;
        }

        Relationship__c newRel = new Relationship__c();
        newRel.Orient_Customer__c = orientCustomerId;
        newRel.Family_Member__c = familyMemberContactId;
        newRel.Relationship_Type__c = relationType;
        insert newRel;
    }

    private static void syncCompleteFamilyTree(Id currentAccountId, Id newFamilyAccountId) {
        Set<Id> familyAccountIds = collectConnectedFamilyAccounts(
            new Set<Id>{ currentAccountId, newFamilyAccountId }
        );

        if (familyAccountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, Name, Phone
            FROM Account
            WHERE Id IN :familyAccountIds
        ]);

        Map<Id, Contact> accountToContactMap = new Map<Id, Contact>();

        for (Account acc : accountMap.values()) {
            Contact con = getOrCreateSelfContact(acc);
            accountToContactMap.put(acc.Id, con);
        }

        Map<Id, Map<Id, Relationship__c>> existingRelationMap = buildExistingRelationMap(familyAccountIds);

        List<Relationship__c> toInsert = new List<Relationship__c>();

        for (Id ownerAccountId : familyAccountIds) {
            for (Id targetAccountId : familyAccountIds) {
                if (ownerAccountId == targetAccountId) {
                    continue;
                }

                if (
                    existingRelationMap.containsKey(ownerAccountId) &&
                    existingRelationMap.get(ownerAccountId).containsKey(targetAccountId)
                ) {
                    continue;
                }

                Contact targetContact = accountToContactMap.get(targetAccountId);

                if (targetContact == null) {
                    continue;
                }

                String inferredRelation = inferMissingRelation(
                    ownerAccountId,
                    targetAccountId,
                    currentAccountId,
                    existingRelationMap
                );

                Relationship__c newRel = new Relationship__c();
                newRel.Orient_Customer__c = ownerAccountId;
                newRel.Family_Member__c = targetContact.Id;
                newRel.Relationship_Type__c = inferredRelation;
                toInsert.add(newRel);

                if (!existingRelationMap.containsKey(ownerAccountId)) {
                    existingRelationMap.put(ownerAccountId, new Map<Id, Relationship__c>());
                }

                existingRelationMap.get(ownerAccountId).put(targetAccountId, newRel);
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }

    private static Set<Id> collectConnectedFamilyAccounts(Set<Id> startAccountIds) {
        Set<Id> result = new Set<Id>();
        result.addAll(startAccountIds);

        Boolean changed = true;
        Integer loopCount = 0;

        while (changed && loopCount < 5) {
            changed = false;
            loopCount++;

            List<Relationship__c> relList = [
                SELECT Id,
                       Orient_Customer__c,
                       Family_Member__c,
                       Family_Member__r.AccountId
                FROM Relationship__c
                WHERE Orient_Customer__c IN :result
                OR Family_Member__r.AccountId IN :result
            ];

            for (Relationship__c rel : relList) {
                if (rel.Orient_Customer__c != null && !result.contains(rel.Orient_Customer__c)) {
                    result.add(rel.Orient_Customer__c);
                    changed = true;
                }

                if (
                    rel.Family_Member__r != null &&
                    rel.Family_Member__r.AccountId != null &&
                    !result.contains(rel.Family_Member__r.AccountId)
                ) {
                    result.add(rel.Family_Member__r.AccountId);
                    changed = true;
                }
            }
        }

        return result;
    }

    private static Map<Id, Map<Id, Relationship__c>> buildExistingRelationMap(Set<Id> accountIds) {
        Map<Id, Map<Id, Relationship__c>> result = new Map<Id, Map<Id, Relationship__c>>();

        List<Relationship__c> relList = [
            SELECT Id,
                   Orient_Customer__c,
                   Family_Member__c,
                   Family_Member__r.AccountId,
                   Relationship_Type__c
            FROM Relationship__c
            WHERE Orient_Customer__c IN :accountIds
        ];

        for (Relationship__c rel : relList) {
            if (
                rel.Orient_Customer__c == null ||
                rel.Family_Member__r == null ||
                rel.Family_Member__r.AccountId == null
            ) {
                continue;
            }

            Id ownerAccountId = rel.Orient_Customer__c;
            Id targetAccountId = rel.Family_Member__r.AccountId;

            if (!result.containsKey(ownerAccountId)) {
                result.put(ownerAccountId, new Map<Id, Relationship__c>());
            }

            result.get(ownerAccountId).put(targetAccountId, rel);
        }

        return result;
    }

    private static String inferMissingRelation(
        Id ownerAccountId,
        Id targetAccountId,
        Id centerAccountId,
        Map<Id, Map<Id, Relationship__c>> existingRelationMap
    ) {
        String ownerToCenter = getRelationType(existingRelationMap, ownerAccountId, centerAccountId);
        String centerToTarget = getRelationType(existingRelationMap, centerAccountId, targetAccountId);
        String centerToOwner = getRelationType(existingRelationMap, centerAccountId, ownerAccountId);

        if (String.isBlank(ownerToCenter) || String.isBlank(centerToTarget)) {
            return 'Other';
        }

        return inferRelationFromCenter(ownerToCenter, centerToTarget, centerToOwner);
    }

    private static String getRelationType(
        Map<Id, Map<Id, Relationship__c>> existingRelationMap,
        Id ownerAccountId,
        Id targetAccountId
    ) {
        if (
            !existingRelationMap.containsKey(ownerAccountId) ||
            !existingRelationMap.get(ownerAccountId).containsKey(targetAccountId)
        ) {
            return null;
        }

        return existingRelationMap.get(ownerAccountId).get(targetAccountId).Relationship_Type__c;
    }

    private static String inferRelationFromCenter(
        String ownerToCenter,
        String centerToTarget,
        String centerToOwner
    ) {
        if (String.isBlank(ownerToCenter) || String.isBlank(centerToTarget)) {
            return 'Other';
        }

        if (ownerToCenter == 'Mother' && centerToTarget == 'Husband') {
            return 'Father';
        }

        if (ownerToCenter == 'Father' && centerToTarget == 'Wife') {
            return 'Mother';
        }
        /*
    Sibling shared grandparent logic:
    Example:
    Ankita -> Ishita = Sister
    Ankita -> Raya = Maternal Grandmother
    So Ishita -> Raya = Maternal Grandmother
*/
if (
    (ownerToCenter == 'Brother' || ownerToCenter == 'Sister') &&
    (
        centerToTarget == 'Maternal Grandmother' ||
        centerToTarget == 'Maternal Grandfather' ||
        centerToTarget == 'Grandmother' ||
        centerToTarget == 'Grandfather'
    )
) {
    return centerToTarget;
}

        if (centerToTarget == 'Maternal Grandmother') {
            if (centerToOwner == 'Mother') {
                return 'Mother';
            }

            if (centerToOwner == 'Father') {
                return 'Mother In-laws';
            }

            return 'Other';
        }

        if (centerToTarget == 'Maternal Grandfather') {
            if (centerToOwner == 'Mother') {
                return 'Father';
            }

            if (centerToOwner == 'Father') {
                return 'Father In-laws';
            }

            return 'Other';
        }

        if (centerToTarget == 'Grandmother') {
            if (centerToOwner == 'Father') {
                return 'Mother';
            }

            if (centerToOwner == 'Mother') {
                return 'Mother In-laws';
            }

            return 'Other';
        }

        if (centerToTarget == 'Grandfather') {
            if (centerToOwner == 'Father') {
                return 'Father';
            }

            if (centerToOwner == 'Mother') {
                return 'Father In-laws';
            }

            return 'Other';
        }

        if (
            (ownerToCenter == 'Father' || ownerToCenter == 'Mother') &&
            centerToTarget == 'Father'
        ) {
            return 'Grandfather';
        }

        if (
            (ownerToCenter == 'Father' || ownerToCenter == 'Mother') &&
            centerToTarget == 'Mother'
        ) {
            return 'Grandmother';
        }

        if (
            (ownerToCenter == 'Son' || ownerToCenter == 'Daughter') &&
            centerToTarget == 'Son'
        ) {
            return 'Grandson';
        }

        if (
            (ownerToCenter == 'Son' || ownerToCenter == 'Daughter') &&
            centerToTarget == 'Daughter'
        ) {
            return 'Granddaughter';
        }

        if (
            (ownerToCenter == 'Son' || ownerToCenter == 'Daughter') &&
            centerToTarget == 'Wife'
        ) {
            return 'Daughter In-laws';
        }

        if (
            (ownerToCenter == 'Son' || ownerToCenter == 'Daughter') &&
            centerToTarget == 'Husband'
        ) {
            return 'Son In-laws';
        }

        if (isParentRelation(ownerToCenter) && centerToTarget == 'Son') {
            return 'Brother';
        }

        if (isParentRelation(ownerToCenter) && centerToTarget == 'Daughter') {
            return 'Sister';
        }

        if (
            (ownerToCenter == 'Husband' || ownerToCenter == 'Wife') &&
            isChildRelation(centerToTarget)
        ) {
            return centerToTarget;
        }

        if (
            (ownerToCenter == 'Husband' || ownerToCenter == 'Wife') &&
            centerToTarget == 'Father'
        ) {
            return 'Father In-laws';
        }

        if (
            (ownerToCenter == 'Husband' || ownerToCenter == 'Wife') &&
            centerToTarget == 'Mother'
        ) {
            return 'Mother In-laws';
        }

        if (ownerToCenter == 'Father' || ownerToCenter == 'Mother') {
            if (centerToTarget == 'Husband') {
                return 'Son In-laws';
            }

            if (centerToTarget == 'Wife') {
                return 'Daughter In-laws';
            }
        }

        if (ownerToCenter == 'Brother' || ownerToCenter == 'Sister') {
            if (centerToTarget == 'Son') {
                return 'Nephew';
            }

            if (centerToTarget == 'Daughter') {
                return 'Niece';
            }
        }

        if (ownerToCenter == 'Son' || ownerToCenter == 'Daughter') {
            if (centerToTarget == 'Brother') {
                return 'Uncle';
            }

            if (centerToTarget == 'Sister') {
                return 'Aunt';
            }
        }

        if (
            (ownerToCenter == 'Niece' || ownerToCenter == 'Nephew') &&
            isChildRelation(centerToTarget)
        ) {
            return 'Cousin';
        }

        if (centerToTarget == 'Cousin') {
            return 'Cousin';
        }

        if (centerToTarget == 'Friend') {
            return 'Friend';
        }

        if (
            (ownerToCenter == 'Husband' || ownerToCenter == 'Wife') &&
            centerToTarget == 'Brother'
        ) {
            return 'Brother In-laws';
        }

        if (
            (ownerToCenter == 'Husband' || ownerToCenter == 'Wife') &&
            centerToTarget == 'Sister'
        ) {
            return 'Sister In-laws';
        }

        return 'Other';
    }

    private static Boolean isChildRelation(String relationType) {
        return relationType == 'Son' || relationType == 'Daughter';
    }

    private static Boolean isParentRelation(String relationType) {
        return relationType == 'Father' || relationType == 'Mother';
    }

    private static String getReverseRelation(String relation, String currentGender) {
        if (String.isBlank(relation)) {
            return 'Other';
        }

        if (
            String.isBlank(currentGender) ||
            currentGender == 'Other' ||
            currentGender == 'Prefer not to say'
        ) {
            return 'Other';
        }

        Boolean isMale = currentGender == 'Male';
        Boolean isFemale = currentGender == 'Female';

        if (relation == 'Father') {
            return isMale ? 'Son' : isFemale ? 'Daughter' : 'Other';
        }

        if (relation == 'Mother') {
            return isMale ? 'Son' : isFemale ? 'Daughter' : 'Other';
        }

        if (relation == 'Son') {
            return isMale ? 'Father' : isFemale ? 'Mother' : 'Other';
        }

        if (relation == 'Daughter') {
            return isMale ? 'Father' : isFemale ? 'Mother' : 'Other';
        }

        if (relation == 'Brother') {
            return isMale ? 'Brother' : isFemale ? 'Sister' : 'Other';
        }

        if (relation == 'Sister') {
            return isMale ? 'Brother' : isFemale ? 'Sister' : 'Other';
        }

        if (relation == 'Husband') {
            return 'Wife';
        }

        if (relation == 'Wife') {
            return 'Husband';
        }

        if (relation == 'Cousin') {
            return 'Cousin';
        }

        if (relation == 'Friend') {
            return 'Friend';
        }

        if (relation == 'Niece') {
            return isMale ? 'Uncle' : isFemale ? 'Aunt' : 'Other';
        }

        if (relation == 'Nephew') {
            return isMale ? 'Uncle' : isFemale ? 'Aunt' : 'Other';
        }

        if (relation == 'Aunt') {
            return isMale ? 'Nephew' : isFemale ? 'Niece' : 'Other';
        }

        if (relation == 'Uncle') {
            return isMale ? 'Nephew' : isFemale ? 'Niece' : 'Other';
        }

        if (relation == 'Father In-laws') {
            return isMale ? 'Son In-laws' : isFemale ? 'Daughter In-laws' : 'Other';
        }

        if (relation == 'Mother In-laws') {
            return isMale ? 'Son In-laws' : isFemale ? 'Daughter In-laws' : 'Other';
        }

        if (relation == 'Son In-laws') {
            return isMale ? 'Father In-laws' : isFemale ? 'Mother In-laws' : 'Other';
        }

        if (relation == 'Daughter In-laws') {
            return isMale ? 'Father In-laws' : isFemale ? 'Mother In-laws' : 'Other';
        }

        if (relation == 'Brother In-laws') {
            return isMale ? 'Brother In-laws' : isFemale ? 'Sister In-laws' : 'Other';
        }

        if (relation == 'Sister In-laws') {
            return isMale ? 'Brother In-laws' : isFemale ? 'Sister In-laws' : 'Other';
        }

        if (relation == 'Grandfather') {
            return isMale ? 'Grandson' : isFemale ? 'Granddaughter' : 'Other';
        }

        if (relation == 'Grandmother') {
            return isMale ? 'Grandson' : isFemale ? 'Granddaughter' : 'Other';
        }

        if (relation == 'Maternal Grandfather') {
            return isMale ? 'Grandson' : isFemale ? 'Granddaughter' : 'Other';
        }

        if (relation == 'Maternal Grandmother') {
            return isMale ? 'Grandson' : isFemale ? 'Granddaughter' : 'Other';
        }

        if (relation == 'Grandson') {
            return isMale ? 'Grandfather' : isFemale ? 'Grandmother' : 'Other';
        }

        if (relation == 'Granddaughter') {
            return isMale ? 'Grandfather' : isFemale ? 'Grandmother' : 'Other';
        }

        if (relation == 'Other') {
            return 'Other';
        }

        return 'Other';
    }

    private static String normalizePhone(String phone) {
        if (String.isBlank(phone)) {
            return '';
        }

        String result = '';

        for (Integer i = 0; i < phone.length(); i++) {
            String ch = phone.substring(i, i + 1);

            if (ch >= '0' && ch <= '9') {
                result += ch;
            }
        }

        if (result.length() > 10) {
            result = result.substring(result.length() - 10);
        }

        return result;
    }
}