public with sharing class Ctrl_Hlp_BTLApproverResolver {

    public class Resolution {
        public Approval_Hierarchy_Level__c level;
        public Approval_Approver_Mapping__c mapping;

        public Resolution(
            Approval_Hierarchy_Level__c level,
            Approval_Approver_Mapping__c mapping
        ) {
            this.level = level;
            this.mapping = mapping;
        }
    }

    public static Map<Id, Resolution> resolveFirstApprovers(
        Set<Id> hierarchyIds
    ) {
        Map<Id, Resolution> result = new Map<Id, Resolution>();

        if (hierarchyIds == null || hierarchyIds.isEmpty()) {
            return result;
        }

        List<Approval_Hierarchy_Level__c> levels = [
            SELECT
                Id,
                Name,
                Approval_Hierarchy__c,
                Responsible_Team__c,
                Sr_No__c
            FROM Approval_Hierarchy_Level__c
            WHERE Approval_Hierarchy__c IN :hierarchyIds
            WITH USER_MODE
            ORDER BY Approval_Hierarchy__c, Sr_No__c ASC
        ];

        validateLevelSequences(levels);

        Map<Id, Approval_Hierarchy_Level__c> firstLevelByHierarchy =
            new Map<Id, Approval_Hierarchy_Level__c>();

        for (Approval_Hierarchy_Level__c levelRecord : levels) {
            if (
                !firstLevelByHierarchy.containsKey(
                    levelRecord.Approval_Hierarchy__c
                )
            ) {
                firstLevelByHierarchy.put(
                    levelRecord.Approval_Hierarchy__c,
                    levelRecord
                );
            }
        }

        Set<Id> firstLevelIds = new Set<Id>();

        for (Id hierarchyId : hierarchyIds) {
            Approval_Hierarchy_Level__c firstLevel =
                firstLevelByHierarchy.get(hierarchyId);

            if (firstLevel == null) {
                throw new AuraHandledException(
                    'No approval level is configured for hierarchy: ' +
                    hierarchyId
                );
            }

            firstLevelIds.add(firstLevel.Id);
        }

        Map<Id, Approval_Approver_Mapping__c> mappingByLevel =
            resolveMappings(firstLevelIds);

        for (Id hierarchyId : hierarchyIds) {
            Approval_Hierarchy_Level__c firstLevel =
                firstLevelByHierarchy.get(hierarchyId);

            result.put(
                hierarchyId,
                new Resolution(
                    firstLevel,
                    mappingByLevel.get(firstLevel.Id)
                )
            );
        }

        return result;
    }

    public static Map<Id, Approval_Approver_Mapping__c> resolveApproversForLevels(Set<Id> approvalLevelIds) {
        return resolveMappings(approvalLevelIds);
    }

    public static Resolution resolveApproverForLevel(
        Id approvalLevelId
    ) {
        if (approvalLevelId == null) {
            throw new AuraHandledException(
                'Approval level Id is required.'
            );
        }

        List<Approval_Hierarchy_Level__c> levels = [
            SELECT
                Id,
                Name,
                Approval_Hierarchy__c,
                Responsible_Team__c,
                Sr_No__c
            FROM Approval_Hierarchy_Level__c
            WHERE Id = :approvalLevelId
            WITH USER_MODE
            LIMIT 1
        ];

        if (levels.isEmpty()) {
            throw new AuraHandledException(
                'Approval level could not be found.'
            );
        }

        Map<Id, Approval_Approver_Mapping__c> mappingByLevel =
            resolveMappings(new Set<Id>{ approvalLevelId });

        return new Resolution(
            levels[0],
            mappingByLevel.get(approvalLevelId)
        );
    }

    // private static Map<Id, Approval_Approver_Mapping__c>
    //     resolveMappings(Set<Id> levelIds) {

    //     Map<Id, Approval_Approver_Mapping__c> result =
    //         new Map<Id, Approval_Approver_Mapping__c>();

    //     if (levelIds == null || levelIds.isEmpty()) {
    //         return result;
    //     }

    //     Map<Id, Approval_Hierarchy_Level__c> levelById =
    //         new Map<Id, Approval_Hierarchy_Level__c>([
    //             SELECT
    //                 Id,
    //                 Name,
    //                 Approval_Hierarchy__c,
    //                 Responsible_Team__c,
    //                 Sr_No__c
    //             FROM Approval_Hierarchy_Level__c
    //             WHERE Id IN :levelIds
    //             WITH USER_MODE
    //         ]);

    //     Date todayValue = Date.today();

    //     List<Approval_Approver_Mapping__c> mappings = [
    //         SELECT
    //             Id,
    //             Approval_Hierarchy_Level__c,
    //             Approver_User__c,
    //             Approver_User__r.Name,
    //             Approver_User__r.IsActive,
    //             Approver_User__r.Profile.Name,
    //             Active__c,
    //             Is_Primary__c,
    //             Effective_From__c,
    //             Effective_To__c
    //         FROM Approval_Approver_Mapping__c
    //         WHERE Approval_Hierarchy_Level__c IN :levelIds
    //         AND Active__c = true
    //         AND Is_Primary__c = true
    //         AND Approver_User__c != null
    //         AND Approver_User__r.IsActive = true
    //         AND (
    //             Effective_From__c = null
    //             OR Effective_From__c <= :todayValue
    //         )
    //         AND (
    //             Effective_To__c = null
    //             OR Effective_To__c >= :todayValue
    //         )
    //         WITH USER_MODE
    //     ];

    //     Map<Id, List<Approval_Approver_Mapping__c>> mappingsByLevel =
    //         new Map<Id, List<Approval_Approver_Mapping__c>>();

    //     for (Approval_Approver_Mapping__c mappingRecord : mappings) {
    //         if (
    //             !mappingsByLevel.containsKey(
    //                 mappingRecord.Approval_Hierarchy_Level__c
    //             )
    //         ) {
    //             mappingsByLevel.put(
    //                 mappingRecord.Approval_Hierarchy_Level__c,
    //                 new List<Approval_Approver_Mapping__c>()
    //             );
    //         }

    //         mappingsByLevel.get(mappingRecord.Approval_Hierarchy_Level__c).add(mappingRecord);
    //     }

    //     for (Id levelId : levelIds) {
    //         Approval_Hierarchy_Level__c levelRecord =
    //             levelById.get(levelId);

    //         if (levelRecord == null) {
    //             throw new AuraHandledException(
    //                 'Approval level could not be found: ' +
    //                 levelId
    //             );
    //         }

    //         List<Approval_Approver_Mapping__c> levelMappings =
    //             mappingsByLevel.get(levelId);

    //         if (levelMappings == null || levelMappings.isEmpty()) {
    //             throw new AuraHandledException(
    //                 'No active primary approver is configured for level "' +
    //                 levelRecord.Responsible_Team__c +
    //                 '".'
    //             );
    //         }

    //         if (levelMappings.size() > 1) {
    //             throw new AuraHandledException(
    //                 'Multiple active primary approvers are configured for level "' +
    //                 levelRecord.Responsible_Team__c +
    //                 '".'
    //             );
    //         }

    //         Approval_Approver_Mapping__c selectedMapping =
    //             levelMappings[0];

    //         validateMappedUserProfile(
    //             levelRecord,
    //             selectedMapping
    //         );

    //         result.put(levelId, selectedMapping);
    //     }

    //     return result;
    // }

    private static Map<Id, Approval_Approver_Mapping__c> resolveMappings(Set<Id> levelIds) {
        Map<Id, Approval_Approver_Mapping__c> result = new Map<Id, Approval_Approver_Mapping__c>();

        if (levelIds == null || levelIds.isEmpty()) {
            return result;
        }

        Map<Id, Approval_Hierarchy_Level__c> levelById = new Map<Id, Approval_Hierarchy_Level__c>([
            SELECT Id, Name, Approval_Hierarchy__c, Responsible_Team__c, Sr_No__c
            FROM Approval_Hierarchy_Level__c
            WHERE Id IN :levelIds
            WITH USER_MODE
        ]);

        Date todayValue = Date.today();

        // 1. Removed Approver_User__r.ProfileId from this USER_MODE query
        List<Approval_Approver_Mapping__c> mappings = [
            SELECT
                Id,
                Approval_Hierarchy_Level__c,
                Approver_User__c,
                Approver_User__r.Name,
                Approver_User__r.IsActive,
                Active__c,
                Is_Primary__c,
                Effective_From__c,
                Effective_To__c
            FROM Approval_Approver_Mapping__c
            WHERE Approval_Hierarchy_Level__c IN :levelIds
            AND Active__c = true
            AND Is_Primary__c = true
            AND Approver_User__c != null
            AND Approver_User__r.IsActive = true
            AND (Effective_From__c = null OR Effective_From__c <= :todayValue)
            AND (Effective_To__c = null OR Effective_To__c >= :todayValue)
            WITH USER_MODE
        ];

        Set<Id> approverUserIds = new Set<Id>();
        Map<Id, List<Approval_Approver_Mapping__c>> mappingsByLevel = new Map<Id, List<Approval_Approver_Mapping__c>>();

        for (Approval_Approver_Mapping__c mappingRecord : mappings) {
            approverUserIds.add(mappingRecord.Approver_User__c);

            if (!mappingsByLevel.containsKey(mappingRecord.Approval_Hierarchy_Level__c)) {
                mappingsByLevel.put(mappingRecord.Approval_Hierarchy_Level__c, new List<Approval_Approver_Mapping__c>());
            }
            mappingsByLevel.get(mappingRecord.Approval_Hierarchy_Level__c).add(mappingRecord);
        }

        // 2. System Mode Query: Safely get ProfileIds for the mapped Approvers
        List<User> approverUsers = [
            SELECT Id, ProfileId 
            FROM User 
            WHERE Id IN :approverUserIds
        ];

        Set<Id> profileIds = new Set<Id>();
        for (User u : approverUsers) {
            profileIds.add(u.ProfileId);
        }

        // 3. System Mode Query: Safely get Profile Names
        Map<Id, Profile> profilesMap = new Map<Id, Profile>([
            SELECT Id, Name 
            FROM Profile 
            WHERE Id IN :profileIds
        ]);

        // 4. Map Approver UserId directly to Profile Name
        Map<Id, String> profileNameByUserId = new Map<Id, String>();
        for (User u : approverUsers) {
            Profile p = profilesMap.get(u.ProfileId);
            if (p != null) {
                profileNameByUserId.put(u.Id, p.Name);
            }
        }

        for (Id levelId : levelIds) {
            Approval_Hierarchy_Level__c levelRecord = levelById.get(levelId);

            if (levelRecord == null) {
                throw new AuraHandledException('Approval level could not be found: ' + levelId);
            }

            List<Approval_Approver_Mapping__c> levelMappings = mappingsByLevel.get(levelId);

            if (levelMappings == null || levelMappings.isEmpty()) {
                throw new AuraHandledException(
                    'No active primary approver is configured for level "' + levelRecord.Responsible_Team__c + '".'
                );
            }

            if (levelMappings.size() > 1) {
                throw new AuraHandledException(
                    'Multiple active primary approvers are configured for level "' + levelRecord.Responsible_Team__c + '".'
                );
            }

            Approval_Approver_Mapping__c selectedMapping = levelMappings[0];

            validateMappedUserProfile(
                levelRecord,
                selectedMapping,
                profileNameByUserId
            );

            result.put(levelId, selectedMapping);
        }

        return result;
    }

    public static void validateLevelSequences(
        List<Approval_Hierarchy_Level__c> levels
    ) {
        if (levels == null || levels.isEmpty()) {
            return;
        }

        Map<Id, Set<Decimal>> usedSequenceByHierarchy =
            new Map<Id, Set<Decimal>>();

        for (Approval_Hierarchy_Level__c levelRecord : levels) {
            String levelLabel =
                String.isNotBlank(levelRecord.Responsible_Team__c)
                    ? levelRecord.Responsible_Team__c
                    : levelRecord.Name;

            if (levelRecord.Approval_Hierarchy__c == null) {
                throw new AuraHandledException(
                    'Approval hierarchy is missing for level "' +
                    levelLabel + '".'
                );
            }

            if (
                levelRecord.Sr_No__c == null ||
                levelRecord.Sr_No__c <= 0
            ) {
                throw new AuraHandledException(
                    'Approval sequence must be a positive number for level "' +
                    levelLabel + '".'
                );
            }

            if (
                !usedSequenceByHierarchy.containsKey(
                    levelRecord.Approval_Hierarchy__c
                )
            ) {
                usedSequenceByHierarchy.put(
                    levelRecord.Approval_Hierarchy__c,
                    new Set<Decimal>()
                );
            }

            Set<Decimal> usedSequences =
                usedSequenceByHierarchy.get(
                    levelRecord.Approval_Hierarchy__c
                );

            if (usedSequences.contains(levelRecord.Sr_No__c)) {
                throw new AuraHandledException(
                    'Duplicate approval sequence ' +
                    String.valueOf(levelRecord.Sr_No__c) +
                    ' is configured in the same approval hierarchy. ' +
                    'Each approval level must have a unique Sr No.'
                );
            }

            usedSequences.add(levelRecord.Sr_No__c);
        }
    }

    // private static void validateMappedUserProfile(
    //     Approval_Hierarchy_Level__c levelRecord,
    //     Approval_Approver_Mapping__c selectedMapping
    // ) {
    //     String requiredProfile =
    //         levelRecord.Responsible_Team__c;

    //     String actualProfile =
    //         selectedMapping.Approver_User__r.Profile.Name;

    //     Boolean isSystemAdministrator =
    //         actualProfile ==
    //             Ctrl_Hlp_BTLApprovalConstants.PROFILE_SYSTEM_ADMIN;

    //     if (isSystemAdministrator) {
    //         return;
    //     }

    //     if (
    //         String.isNotBlank(requiredProfile) &&
    //         (
    //             String.isBlank(actualProfile) ||
    //             !requiredProfile.equalsIgnoreCase(actualProfile)
    //         )
    //     ) {
    //         throw new AuraHandledException(
    //             'Approver configuration mismatch. Level "' +
    //             requiredProfile +
    //             '" is mapped to user "' +
    //             selectedMapping.Approver_User__r.Name +
    //             '" whose profile is "' +
    //             actualProfile +
    //             '".'
    //         );
    //     }
    // }

    private static void validateMappedUserProfile(
        Approval_Hierarchy_Level__c levelRecord,
        Approval_Approver_Mapping__c selectedMapping,
        Map<Id, String> profileNameByUserId
    ) {
        String requiredProfile = levelRecord.Responsible_Team__c;
        String actualProfile = profileNameByUserId.get(selectedMapping.Approver_User__c);

        Boolean isSystemAdministrator = 
            actualProfile == Ctrl_Hlp_BTLApprovalConstants.PROFILE_SYSTEM_ADMIN;

        if (isSystemAdministrator) {
            return;
        }

        if (
            String.isNotBlank(requiredProfile) &&
            (String.isBlank(actualProfile) || !requiredProfile.equalsIgnoreCase(actualProfile))
        ) {
            throw new AuraHandledException(
                'Approver configuration mismatch. Level "' +
                requiredProfile +
                '" is mapped to user "' +
                selectedMapping.Approver_User__r.Name +
                '" whose profile is "' +
                actualProfile +
                '".'
            );
        }
    }
}