public without sharing class Ctrl_Hlp_RecordSharing {

    private static final String ACCESS_READ = 'Read';
    private static final String ACCESS_EDIT = 'Edit';
    private static final String ROW_CAUSE_MANUAL = 'Manual';

    public class SharingException extends Exception {
    }

    @TestVisible
    private class ShareDescriptor {
        public String targetObjectApi;
        public String shareObjectApi;
        public String parentFieldApi;
        public String accessFieldApi;
        public String rowCause;
        public Schema.SObjectType targetType;
        public Schema.SObjectType shareType;
    }

    public static void syncAccess(
        String objectApiName,
        Set<Id> recordIds,
        Map<Id, String> accessByUserOrGroup,
        String preferredRowCause
    ) {
        if (
            String.isBlank(objectApiName) ||
            recordIds == null ||
            recordIds.isEmpty() ||
            accessByUserOrGroup == null ||
            accessByUserOrGroup.isEmpty()
        ) {
            return;
        }

        ShareDescriptor descriptor =
            resolveShareDescriptor(
                objectApiName,
                preferredRowCause
            );

        if (descriptor == null) {
            return;
        }

        Map<Id, String> normalizedAccess =
            normalizeAccessMap(
                accessByUserOrGroup
            );

        if (normalizedAccess.isEmpty()) {
            return;
        }

        Map<Id, Id> ownerByRecord =
            getOwnerByRecord(
                descriptor,
                recordIds
            );

        Set<Id> userOrGroupIds =
            normalizedAccess.keySet();

        String rowCause =
            descriptor.rowCause;

        String existingSoql =
            'SELECT Id, ' +
            descriptor.parentFieldApi +
            ', UserOrGroupId, ' +
            descriptor.accessFieldApi +
            ', RowCause FROM ' +
            descriptor.shareObjectApi +
            ' WHERE ' +
            descriptor.parentFieldApi +
            ' IN :recordIds' +
            ' AND UserOrGroupId IN :userOrGroupIds' +
            ' AND RowCause = :rowCause';

        List<SObject> existingShares =
            Database.query(
                existingSoql
            );

        Map<String, SObject> existingByKey =
            new Map<String, SObject>();

        for (SObject shareRecord : existingShares) {
            Id parentId =
                (Id) shareRecord.get(
                    descriptor.parentFieldApi
                );
            Id userOrGroupId =
                (Id) shareRecord.get(
                    'UserOrGroupId'
                );

            existingByKey.put(
                buildKey(
                    parentId,
                    userOrGroupId
                ),
                shareRecord
            );
        }

        List<SObject> sharesToInsert =
            new List<SObject>();
        List<SObject> sharesToUpdate =
            new List<SObject>();

        for (Id recordId : recordIds) {
            for (Id userOrGroupId : normalizedAccess.keySet()) {
                if (
                    ownerByRecord.containsKey(recordId) &&
                    ownerByRecord.get(recordId) == userOrGroupId
                ) {
                    continue;
                }

                String desiredAccess =
                    normalizedAccess.get(
                        userOrGroupId
                    );
                String key =
                    buildKey(
                        recordId,
                        userOrGroupId
                    );
                SObject existingShare =
                    existingByKey.get(key);

                if (existingShare == null) {
                    SObject newShare =
                        descriptor.shareType
                            .newSObject();

                    newShare.put(
                        descriptor.parentFieldApi,
                        recordId
                    );
                    newShare.put(
                        'UserOrGroupId',
                        userOrGroupId
                    );
                    newShare.put(
                        descriptor.accessFieldApi,
                        desiredAccess
                    );
                    newShare.put(
                        'RowCause',
                        descriptor.rowCause
                    );

                    populateSupplementalAccessFields(
                        newShare,
                        descriptor
                    );

                    sharesToInsert.add(
                        newShare
                    );
                    continue;
                }

                String existingAccess =
                    String.valueOf(
                        existingShare.get(
                            descriptor.accessFieldApi
                        )
                    );

                if (existingAccess != desiredAccess) {
                    existingShare.put(
                        descriptor.accessFieldApi,
                        desiredAccess
                    );
                    sharesToUpdate.add(
                        existingShare
                    );
                }
            }
        }

        if (!sharesToInsert.isEmpty()) {
            handleSaveResults(
                Database.insert(
                    sharesToInsert,
                    false
                ),
                descriptor.shareObjectApi,
                'create'
            );
        }

        if (!sharesToUpdate.isEmpty()) {
            handleSaveResults(
                Database.update(
                    sharesToUpdate,
                    false
                ),
                descriptor.shareObjectApi,
                'update'
            );
        }
    }

    public static void removeAccess(
        String objectApiName,
        Set<Id> recordIds,
        Set<Id> userOrGroupIds,
        String preferredRowCause
    ) {
        if (
            String.isBlank(objectApiName) ||
            recordIds == null ||
            recordIds.isEmpty() ||
            userOrGroupIds == null ||
            userOrGroupIds.isEmpty()
        ) {
            return;
        }

        ShareDescriptor descriptor =
            resolveShareDescriptor(
                objectApiName,
                preferredRowCause
            );

        if (descriptor == null) {
            return;
        }

        String rowCause =
            descriptor.rowCause;

        String soql =
            'SELECT Id FROM ' +
            descriptor.shareObjectApi +
            ' WHERE ' +
            descriptor.parentFieldApi +
            ' IN :recordIds' +
            ' AND UserOrGroupId IN :userOrGroupIds' +
            ' AND RowCause = :rowCause';

        List<SObject> sharesToDelete =
            Database.query(soql);

        if (sharesToDelete.isEmpty()) {
            return;
        }

        Database.DeleteResult[] results =
            Database.delete(
                sharesToDelete,
                false
            );

        List<String> errors =
            new List<String>();

        for (Database.DeleteResult result : results) {
            if (result.isSuccess()) {
                continue;
            }

            for (Database.Error errorRecord : result.getErrors()) {
                if (
                    !isBenignShareError(
                        errorRecord
                    )
                ) {
                    errors.add(
                        String.valueOf(
                            errorRecord.getStatusCode()
                        ) +
                        ': ' +
                        errorRecord.getMessage()
                    );
                }
            }
        }

        if (!errors.isEmpty()) {
            throw new SharingException(
                'Unable to remove sharing for ' +
                objectApiName +
                ': ' +
                String.join(
                    errors,
                    ' | '
                )
            );
        }
    }

    @TestVisible
    private static ShareDescriptor resolveShareDescriptor(
        String objectApiName,
        String preferredRowCause
    ) {
        Map<String, Schema.SObjectType> globalDescribe =
            Schema.getGlobalDescribe();

        if (!globalDescribe.containsKey(objectApiName)) {
            throw new SharingException(
                'Object "' +
                objectApiName +
                '" does not exist.'
            );
        }

        Boolean isCustom =
            objectApiName.endsWith('__c');

        String shareObjectApi =
            isCustom
                ? objectApiName.substring(
                    0,
                    objectApiName.length() - 3
                ) + '__Share'
                : objectApiName + 'Share';

        if (!globalDescribe.containsKey(shareObjectApi)) {
            /*
             * No share table normally means the object isn't independently
             * shareable (for example Controlled by Parent). In that case the
             * parent access model already owns record visibility.
             */
            return null;
        }

        Schema.SObjectType shareType =
            globalDescribe.get(
                shareObjectApi
            );
        Map<String, Schema.SObjectField> shareFields =
            shareType.getDescribe()
                .fields.getMap();

        String parentFieldApi =
            isCustom
                ? 'ParentId'
                : objectApiName + 'Id';
        String accessFieldApi =
            isCustom
                ? 'AccessLevel'
                : objectApiName +
                    'AccessLevel';

        if (
            !shareFields.containsKey(parentFieldApi) ||
            !shareFields.containsKey('UserOrGroupId') ||
            !shareFields.containsKey(accessFieldApi) ||
            !shareFields.containsKey('RowCause')
        ) {
            throw new SharingException(
                'Sharing table "' +
                shareObjectApi +
                '" does not expose the expected sharing fields.'
            );
        }

        ShareDescriptor descriptor =
            new ShareDescriptor();
        descriptor.targetObjectApi =
            objectApiName;
        descriptor.shareObjectApi =
            shareObjectApi;
        descriptor.parentFieldApi =
            parentFieldApi;
        descriptor.accessFieldApi =
            accessFieldApi;
        descriptor.targetType =
            globalDescribe.get(
                objectApiName
            );
        descriptor.shareType =
            shareType;
        descriptor.rowCause =
            resolveRowCause(
                shareFields.get('RowCause'),
                isCustom
                    ? preferredRowCause
                    : null
            );

        return descriptor;
    }

    /*
     * Standard share objects can require additional access-level fields.
     *
     * Example:
     * AccountShare requires child access values such as
     * OpportunityAccessLevel and CaseAccessLevel when a row is inserted.
     *
     * This method keeps the generic utility reusable by inspecting the
     * share-table fields instead of hard-coding AccountShare logic.
     */
    @TestVisible
    private static void populateSupplementalAccessFields(
        SObject shareRecord,
        ShareDescriptor descriptor
    ) {
        Map<String, Schema.SObjectField> shareFields =
            descriptor.shareType
                .getDescribe()
                .fields.getMap();

        for (String fieldApi : shareFields.keySet()) {
            if (
                fieldApi == descriptor.accessFieldApi ||
                fieldApi == descriptor.parentFieldApi ||
                fieldApi == 'UserOrGroupId' ||
                fieldApi == 'RowCause' ||
                !fieldApi.endsWith('AccessLevel')
            ) {
                continue;
            }

            Schema.DescribeFieldResult fieldDescribe =
                shareFields.get(fieldApi)
                    .getDescribe();

            if (
                !fieldDescribe.isCreateable() ||
                fieldDescribe.isNillable()
            ) {
                continue;
            }

            String safeValue =
                chooseMinimumAccessValue(
                    fieldDescribe
                );

            if (safeValue != null) {
                shareRecord.put(
                    fieldApi,
                    safeValue
                );
            }
        }
    }

    @TestVisible
    private static String chooseMinimumAccessValue(
        Schema.DescribeFieldResult fieldDescribe
    ) {
        Set<String> availableValues =
            new Set<String>();

        for (
            Schema.PicklistEntry entry :
            fieldDescribe.getPicklistValues()
        ) {
            if (entry.isActive()) {
                availableValues.add(
                    entry.getValue()
                );
            }
        }

        if (availableValues.contains('None')) {
            return 'None';
        }

        if (availableValues.contains(ACCESS_READ)) {
            return ACCESS_READ;
        }

        if (availableValues.contains(ACCESS_EDIT)) {
            return ACCESS_EDIT;
        }

        return null;
    }

    @TestVisible
    private static String resolveRowCause(
        Schema.SObjectField rowCauseField,
        String preferredRowCause
    ) {
        Set<String> availableValues =
            new Set<String>();

        for (
            Schema.PicklistEntry entry :
            rowCauseField.getDescribe()
                .getPicklistValues()
        ) {
            if (entry.isActive()) {
                availableValues.add(
                    entry.getValue()
                );
            }
        }

        if (
            String.isNotBlank(
                preferredRowCause
            ) &&
            availableValues.contains(
                preferredRowCause
            )
        ) {
            return preferredRowCause;
        }

        if (
            availableValues.contains(
                ROW_CAUSE_MANUAL
            )
        ) {
            return ROW_CAUSE_MANUAL;
        }

        throw new SharingException(
            'No usable RowCause is available on the share object.'
        );
    }

    @TestVisible
    private static Map<Id, String> normalizeAccessMap(
        Map<Id, String> source
    ) {
        Map<Id, String> result =
            new Map<Id, String>();

        for (Id userOrGroupId : source.keySet()) {
            if (userOrGroupId == null) {
                continue;
            }

            String accessLevel =
                source.get(userOrGroupId);

            if (
                String.isBlank(accessLevel)
            ) {
                continue;
            }

            String normalized =
                accessLevel.trim()
                    .toLowerCase();

            if (normalized == 'read') {
                result.put(
                    userOrGroupId,
                    ACCESS_READ
                );
            } else if (
                normalized == 'edit'
            ) {
                result.put(
                    userOrGroupId,
                    ACCESS_EDIT
                );
            } else {
                throw new SharingException(
                    'Unsupported sharing access level "' +
                    accessLevel +
                    '".'
                );
            }
        }

        return result;
    }

    @TestVisible
    private static Map<Id, Id> getOwnerByRecord(
        ShareDescriptor descriptor,
        Set<Id> recordIds
    ) {
        Map<Id, Id> ownerByRecord =
            new Map<Id, Id>();

        Map<String, Schema.SObjectField> targetFields =
            descriptor.targetType
                .getDescribe()
                .fields.getMap();

        if (!targetFields.containsKey('OwnerId')) {
            return ownerByRecord;
        }

        String soql =
            'SELECT Id, OwnerId FROM ' +
            descriptor.targetObjectApi +
            ' WHERE Id IN :recordIds';

        for (SObject targetRecord : Database.query(soql)) {
            ownerByRecord.put(
                (Id) targetRecord.get('Id'),
                (Id) targetRecord.get('OwnerId')
            );
        }

        return ownerByRecord;
    }

    @TestVisible
    private static String buildKey(
        Id recordId,
        Id userOrGroupId
    ) {
        return String.valueOf(recordId) +
            '|' +
            String.valueOf(userOrGroupId);
    }

    @TestVisible
    private static void handleSaveResults(
        Database.SaveResult[] results,
        String shareObjectApi,
        String operation
    ) {
        List<String> errors =
            new List<String>();

        for (Database.SaveResult result : results) {
            if (result.isSuccess()) {
                continue;
            }

            for (Database.Error errorRecord : result.getErrors()) {
                if (
                    !isBenignShareError(
                        errorRecord
                    )
                ) {
                    errors.add(
                        String.valueOf(
                            errorRecord.getStatusCode()
                        ) +
                        ': ' +
                        errorRecord.getMessage()
                    );
                }
            }
        }

        if (!errors.isEmpty()) {
            throw new SharingException(
                'Unable to ' +
                operation +
                ' ' +
                shareObjectApi +
                ' records: ' +
                String.join(
                    errors,
                    ' | '
                )
            );
        }
    }

    @TestVisible
    private static Boolean isBenignShareError(
        Database.Error errorRecord
    ) {
        String message =
            String.valueOf(
                errorRecord.getMessage()
            ).toLowerCase();

        return (
            message.contains(
                'already has access'
            ) ||
            message.contains(
                'access level below'
            ) ||
            message.contains(
                'cannot share with the owner'
            ) ||
            message.contains(
                'cannot share a record with its owner'
            )
        );
    }
}