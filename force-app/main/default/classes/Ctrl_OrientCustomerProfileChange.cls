public with sharing class Ctrl_OrientCustomerProfileChange {

    private static final String APPROVAL_TYPE = 'Customer Profile';
    private static final String STATUS_NOT_SUBMITTED = 'Not Submitted';
    private static final String STATUS_PENDING = 'Pending';
    private static final String STATUS_RETURNED = 'Returned';
    private static final String ACTION_SUBMITTED = 'Submitted';
    private static final String ACTION_RESUBMITTED = 'Resubmitted';
    private static final String REQUEST_TYPE_PROFILE = 'Profile Update';
    private static final String REQUEST_STATUS_OPEN = 'Open';
    private static final String BC_STATUS_NOT_REQUIRED = 'Not Required';
    private static final String CHANGE_MODE_STANDARD = 'Standard Approval';
    private static final String CHANGE_MODE_VERIFIED = 'Verified Lock';
    private static final String CHANGE_MODE_ADDRESS = 'Address API Only';
    private static final String CHANGE_MODE_NEVER = 'Never Editable';
    private static final String VALUE_SOURCE_USER = 'User Entered';

    /*
     * KYC submission context is internal to the current Apex transaction.
     * It allows the Surepass KYC controllers to reuse the Customer Profile
     * approval architecture without weakening the normal Customer Profile UI.
     */
    private static final String KYC_METHOD_PAN = 'PAN';
    private static final String KYC_METHOD_VOTER = 'Voter ID';
    private static final String KYC_METHOD_GST = 'GST';
    private static Boolean kycSubmissionContext = false;
    private static String kycPrimaryFieldContext;

    public class FieldRule {
        @AuraEnabled public String developerName;
        @AuraEnabled public String accountFieldApi;
        @AuraEnabled public String trackingFieldApi;
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String sectionName;
        @AuraEnabled public Decimal sequence;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Boolean requiresApproval;
        @AuraEnabled public Boolean bcPushSupported;
        @AuraEnabled public String bcPayloadKey;
        @AuraEnabled public String changeMode;
        @AuraEnabled public String verificationFieldApi;
        @AuraEnabled public Boolean trackingControlled;
        @AuraEnabled public Boolean verified;
        @AuraEnabled public Boolean editableForApproval;
        @AuraEnabled public Boolean addressApiOnly;
        @AuraEnabled public String fieldDataType;
        @AuraEnabled public String currentRawValue;
        @AuraEnabled public String currentDisplayValue;
    }

    public class ApprovalFormData {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id trackingId;
        @AuraEnabled public List<FieldRule> fields;
        @AuraEnabled public List<String> configurationWarnings;
    }

    public class SubmitResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id requestId;
        @AuraEnabled public String requestName;
        @AuraEnabled public Id approvalTransactionId;
        @AuraEnabled public Id pendingWithId;
        @AuraEnabled public String pendingWithName;
        @AuraEnabled public Integer changeCount;
        @AuraEnabled public String message;
    }

    public class MobileDuplicateResult {
        @AuraEnabled public Boolean duplicateFound;
        @AuraEnabled public Id customerId;
        @AuraEnabled public String customerName;
        @AuraEnabled public String message;
    }

    public class SupportingDocumentInfo {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Id latestVersionId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileExtension;
    }

    public class ReturnedRequestSummary {
        @AuraEnabled public Id approvalTransactionId;
        @AuraEnabled public Id requestId;
        @AuraEnabled public String requestName;
        @AuraEnabled public String customerName;
        @AuraEnabled public Decimal submissionCycle;
        @AuraEnabled public Id returnedFromLevelId;
        @AuraEnabled public String returnedFromLevelName;
        @AuraEnabled public Id rejectedById;
        @AuraEnabled public String rejectedByName;
        @AuraEnabled public Datetime rejectedDateTime;
        @AuraEnabled public String rejectionReason;
        @AuraEnabled public Integer changeCount;
    }

    public class ReturnedRequestData {
        @AuraEnabled public Id approvalTransactionId;
        @AuraEnabled public Id requestId;
        @AuraEnabled public String requestName;
        @AuraEnabled public Id customerId;
        @AuraEnabled public String customerName;
        @AuraEnabled public Decimal submissionCycle;
        @AuraEnabled public String previousChangeReason;
        @AuraEnabled public Id returnedFromLevelId;
        @AuraEnabled public String returnedFromLevelName;
        @AuraEnabled public Id rejectedById;
        @AuraEnabled public String rejectedByName;
        @AuraEnabled public Datetime rejectedDateTime;
        @AuraEnabled public String rejectionReason;
        @AuraEnabled public Integer returnedFieldCount;
        @AuraEnabled public List<ReturnedChangeItem> changes;
    }

    public class ReturnedChangeItem {
        @AuraEnabled public Id changeItemId;
        @AuraEnabled public String accountFieldApi;
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String sectionName;
        @AuraEnabled public Decimal sequence;
        @AuraEnabled public String fieldDataType;
        @AuraEnabled public String trackingFieldApi;
        @AuraEnabled public String currentAccountRawValue;
        @AuraEnabled public String currentAccountDisplayValue;
        @AuraEnabled public String previousRequestedRawValue;
        @AuraEnabled public String previousRequestedDisplayValue;
        @AuraEnabled public Boolean editableForResubmit;
        @AuraEnabled public String lockedMessage;
        @AuraEnabled public Boolean bcPushApplicable;
        @AuraEnabled public String bcPayloadKey;
        @AuraEnabled public Id rejectedFromLevelId;
        @AuraEnabled public String rejectedFromLevelName;
        @AuraEnabled public Id rejectedById;
        @AuraEnabled public String rejectedByName;
        @AuraEnabled public Datetime rejectedDateTime;
        @AuraEnabled public String rejectionReason;
    }

    public class ResubmitResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id requestId;
        @AuraEnabled public String requestName;
        @AuraEnabled public Id approvalTransactionId;
        @AuraEnabled public Decimal submissionCycle;
        @AuraEnabled public Id pendingWithId;
        @AuraEnabled public String pendingWithName;
        @AuraEnabled public Integer changeCount;
        @AuraEnabled public String message;
    }

    @TestVisible
    private class PendingChange {
        public Orient_Customer_Field_Mapping__mdt mapping;
        public Schema.DescribeFieldResult fieldDescribe;
        public Object oldValue;
        public Object newValue;
        public String oldRawValue;
        public String newRawValue;
        public String oldDisplayValue;
        public String newDisplayValue;
    }

    @TestVisible
    private class CustomerApprovalResolution {
        public Approval_Hierarchy__c hierarchy;
        public Approval_Hierarchy_Level__c firstLevel;
        public Approval_Approver_Mapping__c firstMapping;
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldRule> getFieldRules() {
        List<FieldRule> result = new List<FieldRule>();

        for (Orient_Customer_Field_Mapping__mdt mapping : getActiveMappings()) {
            FieldRule row = new FieldRule();
            row.developerName = mapping.DeveloperName;
            row.accountFieldApi = mapping.Account_Field_API__c;
            row.trackingFieldApi = mapping.Tracking_Field_API__c;
            row.fieldLabel = mapping.Field_Label__c;
            row.sectionName = mapping.Section_Name__c;
            row.sequence = mapping.Sequence__c;
            row.active = mapping.Active__c;
            row.requiresApproval = mapping.Requires_Approval__c;
            row.bcPushSupported = mapping.BC_Push_Supported__c;
            row.bcPayloadKey = mapping.BC_Payload_Key__c;
            row.changeMode = mapping.Change_Mode__c;
            row.verificationFieldApi = mapping.Verification_Field_API__c;
            row.addressApiOnly =
                mapping.Change_Mode__c == CHANGE_MODE_ADDRESS;
            result.add(row);
        }

        return result;
    }


    @AuraEnabled
    public static ApprovalFormData getApprovalForm(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Customer Id is required.');
        }

        ApprovalFormData response = new ApprovalFormData();
        response.accountId = accountId;
        response.fields = new List<FieldRule>();
        response.configurationWarnings = new List<String>();

        Map<String, Schema.SObjectField> accountFieldMap =
            Schema.SObjectType.Account.fields.getMap();
        Map<String, Schema.SObjectField> trackingFieldMap =
            Schema.SObjectType.Orient_Customer_Tracking__c.fields.getMap();

        List<Orient_Customer_Field_Mapping__mdt> eligibleMappings =
            new List<Orient_Customer_Field_Mapping__mdt>();

        Set<String> accountFieldsToQuery = new Set<String>{ 'Id', 'Name' };
        Set<String> trackingFieldsToQuery =
            new Set<String>{ 'Id', 'Orient_Customer__c' };

        for (Orient_Customer_Field_Mapping__mdt mapping : getActiveMappings()) {
            if (
                mapping.Requires_Approval__c != true ||
                (
                    mapping.Change_Mode__c != CHANGE_MODE_STANDARD &&
                    mapping.Change_Mode__c != CHANGE_MODE_VERIFIED &&
                    mapping.Change_Mode__c != CHANGE_MODE_ADDRESS
                )
            ) {
                continue;
            }

            if (
                String.isBlank(mapping.Account_Field_API__c) ||
                !accountFieldMap.containsKey(mapping.Account_Field_API__c)
            ) {
                response.configurationWarnings.add(
                    'Account field mapping is invalid for "' +
                    mapping.MasterLabel + '".'
                );
                continue;
            }

            Schema.DescribeFieldResult accountDescribe =
                accountFieldMap.get(mapping.Account_Field_API__c).getDescribe();

            if (!accountDescribe.isAccessible()) {
                response.configurationWarnings.add(
                    'You do not have read access to "' +
                    mapping.Field_Label__c + '". The field was skipped.'
                );
                continue;
            }

            if (!accountDescribe.isUpdateable()) {
                response.configurationWarnings.add(
                    '"' + mapping.Field_Label__c +
                    '" is not editable for your profile. The field was skipped.'
                );
                continue;
            }

            if (
                String.isBlank(mapping.Tracking_Field_API__c) ||
                !trackingFieldMap.containsKey(mapping.Tracking_Field_API__c)
            ) {
                response.configurationWarnings.add(
                    'Tracking field mapping is invalid for "' +
                    mapping.Field_Label__c + '".'
                );
                continue;
            }

            Schema.DescribeFieldResult trackingDescribe =
                trackingFieldMap.get(mapping.Tracking_Field_API__c).getDescribe();

            if (!trackingDescribe.isAccessible()) {
                response.configurationWarnings.add(
                    'You do not have access to the Customer Tracking configuration for "' +
                    mapping.Field_Label__c + '". The field was skipped.'
                );
                continue;
            }

            if (trackingDescribe.getType() != Schema.DisplayType.Boolean) {
                response.configurationWarnings.add(
                    'Tracking field "' +
                    mapping.Tracking_Field_API__c +
                    '" must be a Checkbox.'
                );
                continue;
            }

            if (mapping.Change_Mode__c == CHANGE_MODE_VERIFIED) {
                if (
                    String.isBlank(mapping.Verification_Field_API__c) ||
                    !accountFieldMap.containsKey(mapping.Verification_Field_API__c)
                ) {
                    response.configurationWarnings.add(
                        'Verification field mapping is invalid for "' +
                        mapping.Field_Label__c + '".'
                    );
                    continue;
                }

                Schema.DescribeFieldResult verificationDescribe =
                    accountFieldMap.get(
                        mapping.Verification_Field_API__c
                    ).getDescribe();

                if (!verificationDescribe.isAccessible()) {
                    response.configurationWarnings.add(
                        'Verification permission is not available for "' +
                        mapping.Field_Label__c + '". The field was skipped.'
                    );
                    continue;
                }

                if (
                    verificationDescribe.getType() !=
                        Schema.DisplayType.Boolean
                ) {
                    response.configurationWarnings.add(
                        'Verification field "' +
                        mapping.Verification_Field_API__c +
                        '" must be a Checkbox.'
                    );
                    continue;
                }

                accountFieldsToQuery.add(
                    mapping.Verification_Field_API__c
                );
            }

            accountFieldsToQuery.add(mapping.Account_Field_API__c);
            trackingFieldsToQuery.add(mapping.Tracking_Field_API__c);
            eligibleMappings.add(mapping);
        }

        Account accountRecord =
            queryAccount(accountId, accountFieldsToQuery);

        response.accountName = accountRecord.Name;

        Orient_Customer_Tracking__c trackingRecord =
            queryTrackingRecord(accountId, trackingFieldsToQuery);

        if (trackingRecord == null) {
            throw new AuraHandledException(
                'No Orient Customer Tracking record is available for this customer.'
            );
        }

        response.trackingId = trackingRecord.Id;

        for (
            Orient_Customer_Field_Mapping__mdt mapping :
            eligibleMappings
        ) {
            Boolean trackingControlled =
                (Boolean) trackingRecord.get(
                    mapping.Tracking_Field_API__c
                );

            if (
                trackingControlled != true &&
                kycSubmissionContext != true
            ) {
                continue;
            }

            Boolean isVerified = false;

            if (mapping.Change_Mode__c == CHANGE_MODE_VERIFIED) {
                isVerified =
                    ((Boolean) accountRecord.get(
                        mapping.Verification_Field_API__c
                    )) == true;
            }

            FieldRule row = new FieldRule();
            row.developerName = mapping.DeveloperName;
            row.accountFieldApi = mapping.Account_Field_API__c;
            row.trackingFieldApi = mapping.Tracking_Field_API__c;
            row.fieldLabel = mapping.Field_Label__c;
            row.sectionName = String.isBlank(mapping.Section_Name__c)
                ? 'Customer Profile'
                : mapping.Section_Name__c;
            row.sequence = mapping.Sequence__c;
            row.active = mapping.Active__c;
            row.requiresApproval = mapping.Requires_Approval__c;
            row.bcPushSupported = mapping.BC_Push_Supported__c;
            row.bcPayloadKey = mapping.BC_Payload_Key__c;
            row.changeMode = mapping.Change_Mode__c;
            row.verificationFieldApi =
                mapping.Verification_Field_API__c;
            Schema.DescribeFieldResult fieldDescribe =
                accountFieldMap.get(mapping.Account_Field_API__c).getDescribe();
            Object currentValue =
                accountRecord.get(mapping.Account_Field_API__c);

            row.trackingControlled =
                trackingControlled == true;
            row.verified = isVerified;
            row.addressApiOnly =
                mapping.Change_Mode__c ==
                    CHANGE_MODE_ADDRESS;
            row.editableForApproval =
                kycSubmissionContext == true
                    ? true
                    : (
                        row.addressApiOnly == true
                            ? false
                            : !isVerified
                    );
            row.fieldDataType = String.valueOf(fieldDescribe.getType());
            row.currentRawValue = serializeValue(currentValue);
            row.currentDisplayValue =
                formatDisplayValue(currentValue, fieldDescribe);
            response.fields.add(row);
        }

        populateFieldRuleReferenceDisplayValues(
            response.fields,
            accountRecord,
            accountFieldMap
        );

        return response;
    }

    @AuraEnabled
    public static MobileDuplicateResult checkDuplicateMobileNumber(
        Id accountId,
        String mobileNumber
    ) {
        MobileDuplicateResult result = new MobileDuplicateResult();
        result.duplicateFound = false;

        if (String.isBlank(mobileNumber)) {
            return result;
        }

        String normalizedMobile = normalizePhone(mobileNumber);

        if (String.isBlank(normalizedMobile)) {
            return result;
        }

        if (normalizedMobile.length() != 10) {
            result.message = 'Mobile number must contain exactly 10 digits.';
            return result;
        }

        List<Account> matches = [
            SELECT Id, Name
            FROM Account
            WHERE Id != :accountId
            AND (Phone = :normalizedMobile OR Whatsapp_number__c = :normalizedMobile)
            WITH USER_MODE
            LIMIT 1
        ];

        if (!matches.isEmpty()) {
            result.duplicateFound = true;
            result.customerId = matches[0].Id;
            result.customerName = matches[0].Name;
            result.message =
                'A customer already exists with this mobile number: "' +
                matches[0].Name + '". Please enter a different mobile number.';
        }

        return result;
    }

    @AuraEnabled
    public static ApprovalFormData refreshApprovalForm(Id accountId) {
        return getApprovalForm(accountId);
    }

    @AuraEnabled
    public static ReturnedRequestData refreshReturnedRequestDetails(
        Id approvalTransactionId
    ) {
        return getReturnedRequestDetails(approvalTransactionId);
    }

    @AuraEnabled
    public static void linkSupportingDocuments(
        Id requestId,
        List<Id> contentDocumentIds
    ) {
        if (requestId == null) {
            throw new AuraHandledException(
                'Customer Change Request Id is required.'
            );
        }

        if (
            contentDocumentIds == null ||
            contentDocumentIds.isEmpty()
        ) {
            return;
        }

        Id currentUserId = UserInfo.getUserId();

        List<Orient_Customer_Change_Request__c> requests = [
            SELECT Id, Submitted_By__c
            FROM Orient_Customer_Change_Request__c
            WHERE Id = :requestId
            WITH USER_MODE
            LIMIT 1
        ];

        if (requests.isEmpty()) {
            throw new AuraHandledException(
                'Customer Change Request could not be found.'
            );
        }

        User currentUser = [
            SELECT Id, Profile.Name
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ];

        Boolean isAdmin =
            currentUser.Profile != null &&
            currentUser.Profile.Name == 'System Administrator';

        if (
            requests[0].Submitted_By__c != currentUserId &&
            !isAdmin
        ) {
            throw new AuraHandledException(
                'Only the request submitter or System Administrator can attach supporting documents.'
            );
        }

        Set<Id> requestedDocumentIds =
            new Set<Id>(contentDocumentIds);

        Set<Id> accessibleDocumentIds = new Set<Id>();
        for (ContentDocument documentRecord : [
            SELECT Id
            FROM ContentDocument
            WHERE Id IN :requestedDocumentIds
        ]) {
            accessibleDocumentIds.add(documentRecord.Id);
        }

        if (accessibleDocumentIds.isEmpty()) {
            return;
        }

        Set<Id> alreadyLinkedDocumentIds = new Set<Id>();
        for (ContentDocumentLink existingLink : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :requestId
            AND ContentDocumentId IN :accessibleDocumentIds
        ]) {
            alreadyLinkedDocumentIds.add(
                existingLink.ContentDocumentId
            );
        }

        List<ContentDocumentLink> linksToInsert =
            new List<ContentDocumentLink>();

        for (Id documentId : accessibleDocumentIds) {
            if (alreadyLinkedDocumentIds.contains(documentId)) {
                continue;
            }

            linksToInsert.add(
                new ContentDocumentLink(
                    LinkedEntityId = requestId,
                    ContentDocumentId = documentId,
                    ShareType = 'V'
                )
            );
        }

        if (!linksToInsert.isEmpty()) {
            insert linksToInsert;
        }
    }

    @AuraEnabled
    public static void removeSupportingDocument(
        Id requestId,
        Id contentDocumentId
    ) {
        if (contentDocumentId == null) {
            throw new AuraHandledException(
                'Supporting Document Id is required.'
            );
        }

        Id currentUserId = UserInfo.getUserId();

        /*
         * Before a Change Request exists, uploaded files are private
         * to the authenticated uploader. Remove the private file itself.
         */
        if (requestId == null) {
            List<ContentDocument> privateDocuments = [
                SELECT Id, CreatedById
                FROM ContentDocument
                WHERE Id = :contentDocumentId
                LIMIT 1
            ];

            if (privateDocuments.isEmpty()) {
                return;
            }

            if (
                privateDocuments[0].CreatedById !=
                currentUserId
            ) {
                throw new AuraHandledException(
                    'You can remove only supporting documents that you uploaded.'
                );
            }

            delete privateDocuments[0];
            return;
        }

        /*
         * Once a Change Request exists, remove the document only from
         * this approval request. Do not delete the ContentDocument
         * globally because it may be linked elsewhere.
         */
        List<Orient_Customer_Change_Request__c> requests = [
            SELECT Id, Submitted_By__c
            FROM Orient_Customer_Change_Request__c
            WHERE Id = :requestId
            WITH USER_MODE
            LIMIT 1
        ];

        if (requests.isEmpty()) {
            throw new AuraHandledException(
                'Customer Change Request could not be found.'
            );
        }

        User currentUser = [
            SELECT Id, Profile.Name
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ];

        Boolean isAdmin =
            currentUser.Profile != null &&
            currentUser.Profile.Name ==
                'System Administrator';

        if (
            requests[0].Submitted_By__c != currentUserId &&
            !isAdmin
        ) {
            throw new AuraHandledException(
                'Only the request submitter or System Administrator can remove supporting documents.'
            );
        }

        List<ContentDocumentLink> requestLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :requestId
            AND ContentDocumentId = :contentDocumentId
            LIMIT 1
        ];

        if (!requestLinks.isEmpty()) {
            delete requestLinks[0];
        }
    }

    @AuraEnabled
    public static Id saveCapturedSupportingImage(
        Id requestId,
        String fileName,
        String base64Data
    ) {
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException(
                'Captured image data is required.'
            );
        }

        Id currentUserId = UserInfo.getUserId();

        if (requestId != null) {
            List<Orient_Customer_Change_Request__c> requests = [
                SELECT Id, Submitted_By__c
                FROM Orient_Customer_Change_Request__c
                WHERE Id = :requestId
                WITH USER_MODE
                LIMIT 1
            ];

            if (requests.isEmpty()) {
                throw new AuraHandledException(
                    'Customer Change Request could not be found.'
                );
            }

            User currentUser = [
                SELECT Id, Profile.Name
                FROM User
                WHERE Id = :currentUserId
                LIMIT 1
            ];

            Boolean isAdmin =
                currentUser.Profile != null &&
                currentUser.Profile.Name ==
                    'System Administrator';

            if (
                requests[0].Submitted_By__c !=
                    currentUserId &&
                !isAdmin
            ) {
                throw new AuraHandledException(
                    'Only the request submitter or System Administrator can add captured supporting images.'
                );
            }
        }

        String safeFileName =
            String.isBlank(fileName)
                ? 'Supporting_Capture.jpg'
                : fileName.trim();

        if (!safeFileName.toLowerCase().endsWith('.jpg') &&
            !safeFileName.toLowerCase().endsWith('.jpeg') &&
            !safeFileName.toLowerCase().endsWith('.png')) {
            safeFileName += '.jpg';
        }

        String titleValue =
            safeFileName.contains('.')
                ? safeFileName.substring(
                    0,
                    safeFileName.lastIndexOf('.')
                )
                : safeFileName;

        Blob imageBlob;

        try {
            imageBlob =
                EncodingUtil.base64Decode(base64Data);
        } catch (Exception decodeException) {
            throw new AuraHandledException(
                'The captured image could not be decoded.'
            );
        }

        if (imageBlob == null || imageBlob.size() == 0) {
            throw new AuraHandledException(
                'The captured image is empty.'
            );
        }

        ContentVersion versionRecord =
            new ContentVersion(
                Title = titleValue,
                PathOnClient = safeFileName,
                VersionData = imageBlob
            );

        if (requestId != null) {
            versionRecord.FirstPublishLocationId =
                requestId;
        }

        insert versionRecord;

        versionRecord = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
            LIMIT 1
        ];

        return versionRecord.ContentDocumentId;
    }

    @AuraEnabled
    public static List<SupportingDocumentInfo> getSupportingDocuments(
        Id requestId
    ) {
        if (requestId == null) {
            throw new AuraHandledException(
                'Customer Change Request Id is required.'
            );
        }

        List<Orient_Customer_Change_Request__c> requests = [
            SELECT Id
            FROM Orient_Customer_Change_Request__c
            WHERE Id = :requestId
            WITH USER_MODE
            LIMIT 1
        ];

        if (requests.isEmpty()) {
            throw new AuraHandledException(
                'You do not have access to this Customer Change Request.'
            );
        }

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.FileExtension,
                   ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :requestId
        ];

        List<SupportingDocumentInfo> result =
            new List<SupportingDocumentInfo>();

        for (ContentDocumentLink linkRecord : links) {
            SupportingDocumentInfo row =
                new SupportingDocumentInfo();

            row.contentDocumentId =
                linkRecord.ContentDocumentId;
            row.latestVersionId =
                linkRecord.ContentDocument.LatestPublishedVersionId;
            row.title =
                linkRecord.ContentDocument.Title;
            row.fileExtension =
                linkRecord.ContentDocument.FileExtension;

            result.add(row);
        }

        return result;
    }

    @AuraEnabled
    public static List<ReturnedRequestSummary> getReturnedRequests(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Customer Id is required.');
        }

        Id currentUserId = UserInfo.getUserId();

        List<Tagged_Approval_Hierarchy__c> transactions = [
            SELECT Id, Approval_Status__c, Submission_Cycle__c,
                   Submitted_By__c, Pending_With__c,
                   Customer_Change_Request__c,
                   Customer_Change_Request__r.Name,
                   Customer_Change_Request__r.Orient_Customer__r.Name
            FROM Tagged_Approval_Hierarchy__c
            WHERE Customer_Change_Request__r.Orient_Customer__c = :accountId
            AND Customer_Change_Request__c != null
            AND Approval_Status__c = :STATUS_RETURNED
            AND Submitted_By__c = :currentUserId
            AND Pending_With__c = :currentUserId
            WITH USER_MODE
            ORDER BY Last_Action_Date_Time__c DESC, CreatedDate DESC
        ];

        Set<Id> requestIds = new Set<Id>();
        for (Tagged_Approval_Hierarchy__c transactionRecord : transactions) {
            requestIds.add(transactionRecord.Customer_Change_Request__c);
        }

        Map<Id, Integer> returnedCountByRequest =
            new Map<Id, Integer>();

        Map<Id, Orient_Customer_Change_Item__c> latestReturnedByRequest =
            new Map<Id, Orient_Customer_Change_Item__c>();

        if (!requestIds.isEmpty()) {
            for (Orient_Customer_Change_Item__c itemRecord : [
                SELECT Id, Change_Request__c,
                       Rejected_From_Level__c,
                       Rejected_From_Level__r.Name,
                       Rejected_From_Level__r.Responsible_Team__c,
                       Rejected_By__c, Rejected_By__r.Name,
                       Rejected_Date_Time__c,
                       Rejection_Reason__c
                FROM Orient_Customer_Change_Item__c
                WHERE Change_Request__c IN :requestIds
                AND Item_Approval_Status__c = :STATUS_RETURNED
                WITH USER_MODE
                ORDER BY Rejected_Date_Time__c DESC NULLS LAST
            ]) {
                Integer currentCount =
                    returnedCountByRequest.containsKey(
                        itemRecord.Change_Request__c
                    )
                        ? returnedCountByRequest.get(
                            itemRecord.Change_Request__c
                        )
                        : 0;

                returnedCountByRequest.put(
                    itemRecord.Change_Request__c,
                    currentCount + 1
                );

                if (
                    !latestReturnedByRequest.containsKey(
                        itemRecord.Change_Request__c
                    )
                ) {
                    latestReturnedByRequest.put(
                        itemRecord.Change_Request__c,
                        itemRecord
                    );
                }
            }
        }

        List<ReturnedRequestSummary> result =
            new List<ReturnedRequestSummary>();

        for (Tagged_Approval_Hierarchy__c transactionRecord : transactions) {
            ReturnedRequestSummary row =
                new ReturnedRequestSummary();

            row.approvalTransactionId =
                transactionRecord.Id;
            row.requestId =
                transactionRecord.Customer_Change_Request__c;
            row.requestName =
                transactionRecord.Customer_Change_Request__r.Name;
            row.customerName =
                transactionRecord.Customer_Change_Request__r
                    .Orient_Customer__r.Name;
            row.submissionCycle =
                transactionRecord.Submission_Cycle__c;
            row.changeCount =
                returnedCountByRequest.containsKey(row.requestId)
                    ? returnedCountByRequest.get(row.requestId)
                    : 0;

            Orient_Customer_Change_Item__c latestItem =
                latestReturnedByRequest.get(row.requestId);

            if (latestItem != null) {
                row.returnedFromLevelId =
                    latestItem.Rejected_From_Level__c;
                row.returnedFromLevelName =
                    getApprovalLevelLabel(
                        latestItem.Rejected_From_Level__r
                    );
                row.rejectedById =
                    latestItem.Rejected_By__c;
                row.rejectedByName =
                    latestItem.Rejected_By__r == null
                        ? null
                        : latestItem.Rejected_By__r.Name;
                row.rejectedDateTime =
                    latestItem.Rejected_Date_Time__c;
                row.rejectionReason =
                    latestItem.Rejection_Reason__c;
            }

            result.add(row);
        }

        return result;
    }

    @AuraEnabled
    public static ReturnedRequestData getReturnedRequestDetails(
        Id approvalTransactionId
    ) {
        if (approvalTransactionId == null) {
            throw new AuraHandledException(
                'Approval Transaction Id is required.'
            );
        }

        Id currentUserId = UserInfo.getUserId();

        List<Tagged_Approval_Hierarchy__c> transactions = [
            SELECT Id, Approval_Status__c, Submission_Cycle__c,
                   Submitted_By__c, Pending_With__c,
                   Customer_Change_Request__c,
                   Customer_Change_Request__r.Name,
                   Customer_Change_Request__r.Orient_Customer__c,
                   Customer_Change_Request__r.Orient_Customer__r.Name,
                   Customer_Change_Request__r.Change_Reason__c
            FROM Tagged_Approval_Hierarchy__c
            WHERE Id = :approvalTransactionId
            AND Customer_Change_Request__c != null
            WITH USER_MODE
            LIMIT 1
        ];

        if (transactions.isEmpty()) {
            throw new AuraHandledException(
                'Returned Customer Profile request could not be found.'
            );
        }

        Tagged_Approval_Hierarchy__c transactionRecord =
            transactions[0];

        if (
            transactionRecord.Approval_Status__c != STATUS_RETURNED ||
            transactionRecord.Submitted_By__c != currentUserId ||
            transactionRecord.Pending_With__c != currentUserId
        ) {
            throw new AuraHandledException(
                'This returned request is not currently available to you for correction and resubmission.'
            );
        }

        String returnedKycMethod =
            extractKycMethodFromReason(
                transactionRecord.Customer_Change_Request__r
                    .Change_Reason__c
            );

        Boolean isKycReturnedRequest =
            String.isNotBlank(returnedKycMethod);

        Boolean previousKycContext =
            kycSubmissionContext;
        String previousPrimaryField =
            kycPrimaryFieldContext;

        if (isKycReturnedRequest) {
            kycSubmissionContext = true;
            kycPrimaryFieldContext =
                getKycPrimaryFieldApi(
                    returnedKycMethod
                );
        }

        ApprovalFormData currentForm;

        try {
            currentForm =
                getApprovalForm(
                    transactionRecord.Customer_Change_Request__r
                        .Orient_Customer__c
                );
        } finally {
            kycSubmissionContext =
                previousKycContext;
            kycPrimaryFieldContext =
                previousPrimaryField;
        }

        Map<String, FieldRule> currentRuleByField =
            new Map<String, FieldRule>();

        for (FieldRule rule : currentForm.fields) {
            currentRuleByField.put(
                rule.accountFieldApi,
                rule
            );
        }

        List<Orient_Customer_Change_Item__c> items = [
            SELECT Id, Account_Field_API__c, Field_Label__c,
                   Field_Data_Type__c, Section_Name__c, Sequence__c,
                   Tracking_Field_API__c,
                   Old_Value__c, Old_Display_Value__c,
                   New_Value__c, New_Display_Value__c,
                   BC_Push_Applicable__c, BC_Payload_Key__c,
                   Rejected_From_Level__c,
                   Rejected_From_Level__r.Name,
                   Rejected_From_Level__r.Responsible_Team__c,
                   Rejected_By__c, Rejected_By__r.Name,
                   Rejected_Date_Time__c,
                   Rejection_Reason__c,
                   Item_Approval_Status__c,
                   Submission_Cycle__c
            FROM Orient_Customer_Change_Item__c
            WHERE Change_Request__c =
                :transactionRecord.Customer_Change_Request__c
            AND Item_Approval_Status__c = :STATUS_RETURNED
            WITH USER_MODE
            ORDER BY Section_Name__c ASC,
                     Sequence__c ASC,
                     CreatedDate ASC
        ];

        if (items.isEmpty()) {
            throw new AuraHandledException(
                'No Returned Customer Profile fields are available for correction.'
            );
        }

        ReturnedRequestData result =
            new ReturnedRequestData();

        result.approvalTransactionId =
            transactionRecord.Id;
        result.requestId =
            transactionRecord.Customer_Change_Request__c;
        result.requestName =
            transactionRecord.Customer_Change_Request__r.Name;
        result.customerId =
            transactionRecord.Customer_Change_Request__r
                .Orient_Customer__c;
        result.customerName =
            transactionRecord.Customer_Change_Request__r
                .Orient_Customer__r.Name;
        result.submissionCycle =
            transactionRecord.Submission_Cycle__c;
        result.previousChangeReason =
            transactionRecord.Customer_Change_Request__r
                .Change_Reason__c;
        result.returnedFieldCount =
            items.size();
        result.changes =
            new List<ReturnedChangeItem>();

        Orient_Customer_Change_Item__c latestRejectedItem;

        for (Orient_Customer_Change_Item__c item : items) {
            if (
                latestRejectedItem == null ||
                (
                    item.Rejected_Date_Time__c != null &&
                    (
                        latestRejectedItem.Rejected_Date_Time__c == null ||
                        item.Rejected_Date_Time__c >
                            latestRejectedItem.Rejected_Date_Time__c
                    )
                )
            ) {
                latestRejectedItem = item;
            }

            FieldRule currentRule =
                currentRuleByField.get(
                    item.Account_Field_API__c
                );

            ReturnedChangeItem row =
                new ReturnedChangeItem();

            row.changeItemId = item.Id;
            row.accountFieldApi =
                item.Account_Field_API__c;
            row.fieldLabel =
                item.Field_Label__c;
            row.sectionName =
                item.Section_Name__c;
            row.sequence =
                item.Sequence__c;
            row.fieldDataType =
                item.Field_Data_Type__c;
            row.trackingFieldApi =
                item.Tracking_Field_API__c;
            row.previousRequestedRawValue =
                item.New_Value__c;
            row.previousRequestedDisplayValue =
                String.isBlank(item.New_Display_Value__c)
                    ? '—'
                    : item.New_Display_Value__c;
            row.bcPushApplicable =
                item.BC_Push_Applicable__c;
            row.bcPayloadKey =
                item.BC_Payload_Key__c;
            row.rejectedFromLevelId =
                item.Rejected_From_Level__c;
            row.rejectedFromLevelName =
                getApprovalLevelLabel(
                    item.Rejected_From_Level__r
                );
            row.rejectedById =
                item.Rejected_By__c;
            row.rejectedByName =
                item.Rejected_By__r == null
                    ? null
                    : item.Rejected_By__r.Name;
            row.rejectedDateTime =
                item.Rejected_Date_Time__c;
            row.rejectionReason =
                item.Rejection_Reason__c;

            if (currentRule != null) {
                row.currentAccountRawValue =
                    currentRule.currentRawValue;
                row.currentAccountDisplayValue =
                    String.isBlank(currentRule.currentDisplayValue)
                        ? '—'
                        : currentRule.currentDisplayValue;
                row.fieldDataType =
                    currentRule.fieldDataType;
                row.editableForResubmit =
                    currentRule.editableForApproval == true;
                row.lockedMessage =
                    row.editableForResubmit
                        ? null
                        : (
                            currentRule.verified == true
                                ? 'This field is now verified and cannot be corrected through approval.'
                                : 'This field is no longer editable through Customer Profile approval.'
                        );
            } else {
                row.currentAccountRawValue =
                    item.Old_Value__c;
                row.currentAccountDisplayValue =
                    String.isBlank(item.Old_Display_Value__c)
                        ? '—'
                        : item.Old_Display_Value__c;
                row.editableForResubmit = false;
                row.lockedMessage =
                    'This field is no longer eligible for Customer Profile approval. Contact your Salesforce Administrator.';
            }

            result.changes.add(row);
        }

        if (latestRejectedItem != null) {
            result.returnedFromLevelId =
                latestRejectedItem.Rejected_From_Level__c;
            result.returnedFromLevelName =
                getApprovalLevelLabel(
                    latestRejectedItem.Rejected_From_Level__r
                );
            result.rejectedById =
                latestRejectedItem.Rejected_By__c;
            result.rejectedByName =
                latestRejectedItem.Rejected_By__r == null
                    ? null
                    : latestRejectedItem.Rejected_By__r.Name;
            result.rejectedDateTime =
                latestRejectedItem.Rejected_Date_Time__c;
            result.rejectionReason =
                latestRejectedItem.Rejection_Reason__c;
        }

        return result;
    }

    @AuraEnabled
    public static ResubmitResult resubmitReturnedRequest(
        Id approvalTransactionId,
        String changesJson,
        String reason
    ) {
        if (approvalTransactionId == null) {
            throw new AuraHandledException(
                'Approval Transaction Id is required.'
            );
        }

        if (String.isBlank(reason)) {
            throw new AuraHandledException(
                'Correction / Resubmission Reason is required.'
            );
        }

        Map<String, Object> proposedValues =
            parseChanges(changesJson);

        Id currentUserId =
            UserInfo.getUserId();

        List<Tagged_Approval_Hierarchy__c> transactions = [
            SELECT Id, Approval_Hierarchy__c, Approval_Status__c,
                   Current_Approval_Level__c, Pending_With__c,
                   Returned_From_Level__c, Submission_Cycle__c,
                   Submitted_By__c, Submitted_Date_Time__c,
                   Customer_Change_Request__c,
                   Customer_Change_Request__r.Name,
                   Customer_Change_Request__r.Orient_Customer__c,
                   Customer_Change_Request__r.Orient_Customer_Tracking__c,
                   Customer_Change_Request__r.Approval_Store__c,
                   Customer_Change_Request__r.Location_Code__c,
                   Customer_Change_Request__r.Change_Reason__c
            FROM Tagged_Approval_Hierarchy__c
            WHERE Id = :approvalTransactionId
            AND Customer_Change_Request__c != null
            LIMIT 1
            FOR UPDATE
        ];

        if (transactions.isEmpty()) {
            throw new AuraHandledException(
                'Returned Customer Profile request could not be found.'
            );
        }

        Tagged_Approval_Hierarchy__c transactionRecord =
            transactions[0];

        String returnedKycMethod =
            extractKycMethodFromReason(
                transactionRecord.Customer_Change_Request__r
                    .Change_Reason__c
            );

        Boolean isKycReturnedRequest =
            String.isNotBlank(returnedKycMethod);

        if (
            !isKycReturnedRequest &&
            hasReservedKycReasonMarker(reason)
        ) {
            throw new AuraHandledException(
                'The [KYC:*] Change Reason prefix is system-reserved and cannot be entered manually.'
            );
        }

        if (
            transactionRecord.Approval_Status__c != STATUS_RETURNED
        ) {
            throw new AuraHandledException(
                'This request is no longer Returned. Refresh the Customer record and try again.'
            );
        }

        if (
            transactionRecord.Submitted_By__c != currentUserId ||
            transactionRecord.Pending_With__c != currentUserId
        ) {
            throw new AuraHandledException(
                'Only the original submitter can correct and resubmit this returned request.'
            );
        }

        if (
            transactionRecord.Customer_Change_Request__r
                .Approval_Store__c == null
        ) {
            throw new AuraHandledException(
                'Approval Store is missing from this Customer Profile request.'
            );
        }

        Store__c approvalStore = [
            SELECT Id, Name, Store_Code__c
            FROM Store__c
            WHERE Id =
                :transactionRecord.Customer_Change_Request__r
                    .Approval_Store__c
            WITH USER_MODE
            LIMIT 1
        ];

        CustomerApprovalResolution approvalResolution =
            resolveCustomerApprovalRouting(
                approvalStore
            );

        List<Orient_Customer_Change_Item__c> existingItems = [
            SELECT Id, Change_Request__c,
                   Account_Field_API__c,
                   Field_Label__c,
                   Field_Data_Type__c,
                   Section_Name__c,
                   Sequence__c,
                   Tracking_Field_API__c,
                   Old_Value__c,
                   Old_Display_Value__c,
                   New_Value__c,
                   New_Display_Value__c,
                   BC_Push_Applicable__c,
                   BC_Payload_Key__c,
                   Item_Approval_Status__c,
                   Submission_Cycle__c,
                   Rejected_From_Level__c,
                   Rejected_By__c,
                   Rejected_Date_Time__c,
                   Rejection_Reason__c,
                   Final_Approved_By__c,
                   Final_Approved_Date_Time__c
            FROM Orient_Customer_Change_Item__c
            WHERE Change_Request__c =
                :transactionRecord.Customer_Change_Request__c
            AND Item_Approval_Status__c = :STATUS_RETURNED
            FOR UPDATE
        ];

        if (existingItems.isEmpty()) {
            throw new AuraHandledException(
                'No Returned Customer Profile fields are available for resubmission.'
            );
        }

        Set<String> existingFieldApis =
            new Set<String>();

        for (Orient_Customer_Change_Item__c item : existingItems) {
            existingFieldApis.add(
                item.Account_Field_API__c
            );
        }

        for (String submittedFieldApi : proposedValues.keySet()) {
            if (!existingFieldApis.contains(submittedFieldApi)) {
                throw new AuraHandledException(
                    'Field "' + submittedFieldApi +
                    '" is not a Returned field on this request and cannot be resubmitted.'
                );
            }
        }

        Map<String, Orient_Customer_Field_Mapping__mdt>
            mappingByAccountField =
                getMappingByAccountField();

        Map<String, Schema.SObjectField> accountFieldMap =
            Schema.SObjectType.Account.fields.getMap();

        Map<String, Schema.SObjectField> trackingFieldMap =
            Schema.SObjectType.Orient_Customer_Tracking__c
                .fields.getMap();

        Set<String> accountFieldsToQuery =
            new Set<String>{ 'Id', 'Name' };

        Set<String> trackingFieldsToQuery =
            new Set<String>{ 'Id', 'Orient_Customer__c' };

        for (Orient_Customer_Change_Item__c item : existingItems) {
            Orient_Customer_Field_Mapping__mdt mapping =
                mappingByAccountField.get(
                    item.Account_Field_API__c
                );

            validateMappingForApproval(
                item.Account_Field_API__c,
                mapping,
                accountFieldMap,
                trackingFieldMap
            );

            accountFieldsToQuery.add(
                item.Account_Field_API__c
            );
            trackingFieldsToQuery.add(
                mapping.Tracking_Field_API__c
            );

            if (
                String.isNotBlank(mapping.Verification_Field_API__c) &&
                accountFieldMap.containsKey(mapping.Verification_Field_API__c)
            ) {
                accountFieldsToQuery.add(
                    mapping.Verification_Field_API__c
                );
            }
        }

        if (
            existingFieldApis.contains('GST__c') &&
            accountFieldMap.containsKey('PAN__c') &&
            accountFieldMap.get('PAN__c').getDescribe().isAccessible()
        ) {
            accountFieldsToQuery.add('PAN__c');
        }

        if (
            existingFieldApis.contains('PAN__c') &&
            accountFieldMap.containsKey('GST__c') &&
            accountFieldMap.get('GST__c').getDescribe().isAccessible()
        ) {
            accountFieldsToQuery.add('GST__c');
        }

        Id accountId =
            transactionRecord.Customer_Change_Request__r
                .Orient_Customer__c;

        Account accountRecord =
            queryAccount(
                accountId,
                accountFieldsToQuery
            );

        Orient_Customer_Tracking__c trackingRecord =
            queryTrackingRecord(
                accountId,
                trackingFieldsToQuery
            );

        if (trackingRecord == null) {
            throw new AuraHandledException(
                'No Orient Customer Tracking record is available for this customer.'
            );
        }

        List<PendingChange> changes =
            new List<PendingChange>();

        Map<String, Orient_Customer_Change_Item__c> itemByField =
            new Map<String, Orient_Customer_Change_Item__c>();

        Integer actualChangeCount = 0;

        for (Orient_Customer_Change_Item__c item : existingItems) {
            String fieldApi =
                item.Account_Field_API__c;

            Orient_Customer_Field_Mapping__mdt mapping =
                mappingByAccountField.get(fieldApi);

            Boolean trackingLocked =
                (Boolean) trackingRecord.get(
                    mapping.Tracking_Field_API__c
                );

            if (
                trackingLocked != true &&
                !isKycReturnedRequest
            ) {
                throw new AuraHandledException(
                    '"' + mapping.Field_Label__c +
                    '" is no longer locked for Customer Profile approval. ' +
                    'The returned request cannot be resubmitted until the configuration is corrected.'
                );
            }

            if (
                !isKycReturnedRequest &&
                mapping.Change_Mode__c == CHANGE_MODE_VERIFIED &&
                String.isNotBlank(mapping.Verification_Field_API__c) &&
                accountFieldMap.containsKey(mapping.Verification_Field_API__c) &&
                ((Boolean) accountRecord.get(mapping.Verification_Field_API__c)) == true
            ) {
                throw new AuraHandledException(
                    mapping.Field_Label__c +
                    ' is now verified and cannot be changed through this returned request.'
                );
            }

            Schema.DescribeFieldResult fieldDescribe =
                accountFieldMap.get(fieldApi).getDescribe();

            Object oldValue =
                accountRecord.get(fieldApi);

            Object submittedValue =
                proposedValues.containsKey(fieldApi)
                    ? proposedValues.get(fieldApi)
                    : item.New_Value__c;

            Object newValue =
                convertIncomingValue(
                    submittedValue,
                    fieldDescribe
                );

            PendingChange change =
                new PendingChange();

            change.mapping = mapping;
            change.fieldDescribe = fieldDescribe;
            change.oldValue = oldValue;
            change.newValue = newValue;
            change.oldRawValue = serializeValue(oldValue);
            change.newRawValue = serializeValue(newValue);
            change.oldDisplayValue =
                formatDisplayValue(oldValue, fieldDescribe);
            change.newDisplayValue =
                formatDisplayValue(newValue, fieldDescribe);

            changes.add(change);
            itemByField.put(fieldApi, item);

            if (
                !valuesEqual(
                    oldValue,
                    newValue,
                    fieldDescribe.getType()
                ) ||
                (
                    isKycReturnedRequest &&
                    fieldApi ==
                        getKycPrimaryFieldApi(
                            returnedKycMethod
                        )
                )
            ) {
                actualChangeCount++;
            }
        }

        if (actualChangeCount == 0) {
            throw new AuraHandledException(
                'All Returned requested values now match the current Customer Profile. At least one actual change is required to resubmit.'
            );
        }

        populateReferenceDisplayValues(changes);
        validateBusinessFieldRules(accountRecord, changes);
        validateNoDuplicateContactValues(accountId, changes);
        validateNoOverlappingOpenRequest(
            accountId,
            changes,
            transactionRecord.Customer_Change_Request__c
        );

        Decimal currentCycle =
            transactionRecord.Submission_Cycle__c == null
                ? 1
                : transactionRecord.Submission_Cycle__c;

        Decimal nextCycle =
            currentCycle + 1;

        Boolean hasBCApplicableChange = false;

        List<Orient_Customer_Change_Item__c> itemUpdates =
            new List<Orient_Customer_Change_Item__c>();

        Map<Id, String> correctionSummaryByItem =
            new Map<Id, String>();

        for (PendingChange change : changes) {
            Orient_Customer_Change_Item__c existingItem =
                itemByField.get(
                    change.mapping.Account_Field_API__c
                );

            correctionSummaryByItem.put(
                existingItem.Id,
                (
                    String.isBlank(existingItem.New_Display_Value__c)
                        ? '—'
                        : existingItem.New_Display_Value__c
                ) +
                ' → ' +
                (
                    String.isBlank(change.newDisplayValue)
                        ? '—'
                        : change.newDisplayValue
                )
            );

            existingItem.Field_Label__c =
                change.mapping.Field_Label__c;
            existingItem.Field_Data_Type__c =
                String.valueOf(change.fieldDescribe.getType());
            existingItem.Section_Name__c =
                change.mapping.Section_Name__c;
            existingItem.Sequence__c =
                change.mapping.Sequence__c;
            existingItem.Tracking_Field_API__c =
                change.mapping.Tracking_Field_API__c;
            existingItem.New_Value__c =
                change.newRawValue;
            existingItem.New_Display_Value__c =
                change.newDisplayValue;
            existingItem.Value_Source__c =
                VALUE_SOURCE_USER;
            existingItem.BC_Push_Applicable__c =
                change.mapping.BC_Push_Supported__c;
            existingItem.BC_Payload_Key__c =
                change.mapping.BC_Payload_Key__c;

            existingItem.Item_Approval_Status__c =
                STATUS_PENDING;
            existingItem.Submission_Cycle__c =
                nextCycle;

            existingItem.Rejected_From_Level__c = null;
            existingItem.Rejected_By__c = null;
            existingItem.Rejected_Date_Time__c = null;
            existingItem.Rejection_Reason__c = null;

            existingItem.Final_Approved_By__c = null;
            existingItem.Final_Approved_Date_Time__c = null;

            itemUpdates.add(existingItem);

            if (change.mapping.BC_Push_Supported__c == true) {
                hasBCApplicableChange = true;
            }
        }

        update itemUpdates;

        Datetime actionDateTime =
            System.now();

        String trimmedReason =
            isKycReturnedRequest
                ? buildKycResubmissionReason(
                    returnedKycMethod,
                    reason
                )
                : reason.trim();

        Orient_Customer_Change_Request__c requestRecord =
            new Orient_Customer_Change_Request__c(
                Id = transactionRecord.Customer_Change_Request__c,
                Orient_Customer_Tracking__c = trackingRecord.Id,
                Approval_Store__c = approvalStore.Id,
                Approval_Hierarchy__c =
                    approvalResolution.hierarchy.Id,
                Approval_Status__c = STATUS_PENDING,
                Request_Status__c = REQUEST_STATUS_OPEN,
                Change_Reason__c = trimmedReason,
                Submitted_By__c = currentUserId,
                Submitted_Date_Time__c = actionDateTime,
                Submission_Cycle__c = nextCycle,
                Last_Action__c = ACTION_RESUBMITTED,
                Last_Action_By__c = currentUserId,
                Last_Action_Date_Time__c = actionDateTime,
                BC_Push_Status__c =
                    hasBCApplicableChange
                        ? null
                        : BC_STATUS_NOT_REQUIRED,
                BC_Push_Message__c = null,
                BC_Push_Date_Time__c = null,
                BC_Push_Attempt_Count__c = 0,
                BC_Integration_Log__c = null
            );

        update requestRecord;

        transactionRecord.Approval_Hierarchy__c =
            approvalResolution.hierarchy.Id;
        transactionRecord.Approval_Status__c =
            STATUS_PENDING;
        transactionRecord.Current_Approval_Level__c =
            approvalResolution.firstLevel.Id;
        transactionRecord.Pending_With__c =
            approvalResolution.firstMapping.Approver_User__c;
        transactionRecord.Returned_From_Level__c = null;
        transactionRecord.Submission_Cycle__c = nextCycle;
        transactionRecord.Submitted_By__c = currentUserId;
        transactionRecord.Submitted_Date_Time__c = actionDateTime;
        transactionRecord.Last_Action__c = ACTION_RESUBMITTED;
        transactionRecord.Last_Action_By__c = currentUserId;
        transactionRecord.Last_Action_Date_Time__c = actionDateTime;
        transactionRecord.Last_Action_Comments__c = trimmedReason;

        update transactionRecord;

        Schema.DescribeFieldResult commentsDescribe =
            Schema.SObjectType.Approval_Action_History__c
                .fields.Comments__c;

        Integer commentsMaxLength =
            commentsDescribe.getLength();

        List<Approval_Action_History__c> historyRecords =
            new List<Approval_Action_History__c>();

        for (
            Orient_Customer_Change_Item__c itemUpdate :
            itemUpdates
        ) {
            String itemComments =
                trimmedReason;

            String correctionSummary =
                correctionSummaryByItem.get(
                    itemUpdate.Id
                );

            if (String.isNotBlank(correctionSummary)) {
                itemComments +=
                    '\nCorrection: ' +
                    correctionSummary;
            }

            if (
                commentsMaxLength > 0 &&
                itemComments.length() > commentsMaxLength
            ) {
                itemComments =
                    itemComments.substring(
                        0,
                        commentsMaxLength
                    );
            }

            historyRecords.add(
                new Approval_Action_History__c(
                    Approval_Transaction__c =
                        transactionRecord.Id,
                    Customer_Change_Item__c =
                        itemUpdate.Id,
                    Approval_Level__c =
                        approvalResolution.firstLevel.Id,
                    Action__c =
                        ACTION_RESUBMITTED,
                    Action_By__c =
                        currentUserId,
                    Action_Date_Time__c =
                        actionDateTime,
                    Assigned_To__c =
                        approvalResolution.firstMapping.Approver_User__c,
                    Comments__c =
                        itemComments,
                    Previous_Status__c =
                        STATUS_RETURNED,
                    New_Status__c =
                        STATUS_PENDING,
                    Submission_Cycle__c =
                        nextCycle
                )
            );
        }

        insert historyRecords;

        requestRecord = [
            SELECT Id, Name
            FROM Orient_Customer_Change_Request__c
            WHERE Id = :requestRecord.Id
            WITH USER_MODE
            LIMIT 1
        ];

        ResubmitResult result =
            new ResubmitResult();

        result.success = true;
        result.requestId = requestRecord.Id;
        result.requestName = requestRecord.Name;
        result.approvalTransactionId =
            transactionRecord.Id;
        result.submissionCycle = nextCycle;
        result.pendingWithId =
            approvalResolution.firstMapping.Approver_User__c;
        result.pendingWithName =
            getUserName(
                approvalResolution.firstMapping.Approver_User__c
            );
        result.changeCount =
            itemUpdates.size();
        result.message =
            String.valueOf(itemUpdates.size()) +
            ' Returned field(s) from ' +
            requestRecord.Name +
            ' were corrected and resubmitted from the first Customer Profile approval level.';

        return result;
    }

    /*
     * Internal entry point for Surepass PAN / Voter ID / GSTIN approval.
     *
     * The normal Customer Profile submission rules remain unchanged.
     * KYC is allowed to submit a Verified Lock field even when its current
     * verification checkbox is already true, because a new Surepass response
     * may legitimately require correction/re-verification.
     */
    public static SubmitResult submitKycProfileChanges(
        Id accountId,
        String changesJson,
        String kycMethod
    ) {
        return submitKycProfileChanges(
            accountId,
            changesJson,
            kycMethod,
            null
        );
    }

    public static SubmitResult submitKycProfileChanges(
        Id accountId,
        String changesJson,
        String kycMethod,
        String verificationDetail
    ) {
        String normalizedKycMethod =
            normalizeKycMethod(kycMethod);

        Map<String, Object> proposedValues =
            parseChanges(changesJson);

        if (proposedValues.isEmpty()) {
            throw new AuraHandledException(
                'No KYC customer profile values were supplied for approval.'
            );
        }

        Set<String> allowedFieldApis =
            getKycAllowedFieldApis(
                normalizedKycMethod
            );

        for (String fieldApi : proposedValues.keySet()) {
            if (!allowedFieldApis.contains(fieldApi)) {
                throw new AuraHandledException(
                    'Field "' + fieldApi +
                    '" is not supported for ' +
                    getKycDisplayName(normalizedKycMethod) +
                    ' approval.'
                );
            }
        }

        Boolean previousKycContext =
            kycSubmissionContext;
        String previousPrimaryField =
            kycPrimaryFieldContext;

        kycSubmissionContext = true;
        kycPrimaryFieldContext =
            getKycPrimaryFieldApi(
                normalizedKycMethod
            );

        try {
            return submitProfileChanges(
                accountId,
                changesJson,
                buildKycChangeReason(
                    normalizedKycMethod,
                    verificationDetail
                )
            );
        } finally {
            kycSubmissionContext =
                previousKycContext;
            kycPrimaryFieldContext =
                previousPrimaryField;
        }
    }

    @AuraEnabled
    public static SubmitResult submitProfileChanges(
        Id accountId,
        String changesJson,
        String reason
    ) {
        return submitProfileChangesInternal(
            accountId,
            changesJson,
            reason,
            null,
            false
        );
    }

    @AuraEnabled
    public static SubmitResult submitProfileChangesWithAddress(
        Id accountId,
        String changesJson,
        String reason,
        String addressSelectionJson
    ) {
        return submitProfileChangesInternal(
            accountId,
            changesJson,
            reason,
            addressSelectionJson,
            true
        );
    }

    @TestVisible
    private static SubmitResult submitProfileChangesInternal(
        Id accountId,
        String changesJson,
        String reason,
        String addressSelectionJson,
        Boolean allowAddressApi
    ) {
        if (accountId == null) {
            throw new AuraHandledException('Customer Id is required.');
        }

        if (String.isBlank(reason)) {
            throw new AuraHandledException('Change Reason is required.');
        }

        if (
            kycSubmissionContext != true &&
            hasReservedKycReasonMarker(reason)
        ) {
            throw new AuraHandledException(
                'The [KYC:*] Change Reason prefix is system-reserved and cannot be entered manually.'
            );
        }

        Map<String, Object> proposedValues = parseChanges(changesJson);
        if (proposedValues.isEmpty()) {
            throw new AuraHandledException('No customer profile changes were selected for approval.');
        }

        Map<String, Orient_Customer_Field_Mapping__mdt> mappingByAccountField =
            getMappingByAccountField();

        Set<String> submittedFieldApis =
            new Set<String>(
                proposedValues.keySet()
            );

        Set<String> submittedAddressFieldApis =
            new Set<String>();

        for (String fieldApi : submittedFieldApis) {
            Orient_Customer_Field_Mapping__mdt mapping =
                mappingByAccountField.get(
                    fieldApi
                );

            if (
                mapping != null &&
                mapping.Change_Mode__c ==
                    CHANGE_MODE_ADDRESS
            ) {
                submittedAddressFieldApis.add(
                    fieldApi
                );
            }
        }

        if (
            !submittedAddressFieldApis.isEmpty()
        ) {
            if (allowAddressApi != true) {
                throw new AuraHandledException(
                    'Business Central controlled address fields can be changed only from the BC Address selector.'
                );
            }

            if (
                String.isBlank(
                    addressSelectionJson
                )
            ) {
                throw new AuraHandledException(
                    'Select the Business Central address again before sending the request for approval.'
                );
            }

            Ctrl_OrientCustomerAddressSelection.AddressValidationResult
                    addressValidation =
                        Ctrl_OrientCustomerAddressSelection.validateSelection(
                                addressSelectionJson
                            );

            if (
                addressValidation == null ||
                addressValidation.valid != true ||
                addressValidation.canonicalValues == null
            ) {
                throw new AuraHandledException(
                    'The selected Business Central address could not be validated.'
                );
            }

            for (
                String addressFieldApi :
                submittedAddressFieldApis
            ) {
                if (
                    !addressValidation.canonicalValues.containsKey(
                            addressFieldApi
                        )
                ) {
                    throw new AuraHandledException(
                        'Business Central did not return a canonical value for address field "' +
                        addressFieldApi +
                        '". Search and select the address again.'
                    );
                }

                proposedValues.put(
                    addressFieldApi,
                    addressValidation
                        .canonicalValues
                        .get(
                            addressFieldApi
                        )
                );
            }
        }

        Map<String, Schema.SObjectField> accountFieldMap =
            Schema.SObjectType.Account.fields.getMap();
        Map<String, Schema.SObjectField> trackingFieldMap =
            Schema.SObjectType.Orient_Customer_Tracking__c.fields.getMap();

        Set<String> accountFieldsToQuery = new Set<String>{ 'Id', 'Name' };
        Set<String> trackingFieldsToQuery = new Set<String>{ 'Id', 'Orient_Customer__c' };

        for (String fieldApi : proposedValues.keySet()) {
            Orient_Customer_Field_Mapping__mdt mapping =
                mappingByAccountField.get(fieldApi);

            validateMappingForApproval(
                fieldApi,
                mapping,
                accountFieldMap,
                trackingFieldMap,
                allowAddressApi
            );

            accountFieldsToQuery.add(fieldApi);
            trackingFieldsToQuery.add(mapping.Tracking_Field_API__c);

            if (
                String.isNotBlank(mapping.Verification_Field_API__c) &&
                accountFieldMap.containsKey(mapping.Verification_Field_API__c)
            ) {
                accountFieldsToQuery.add(mapping.Verification_Field_API__c);
            }
        }

        if (
            proposedValues.containsKey('GST__c') &&
            accountFieldMap.containsKey('PAN__c') &&
            accountFieldMap.get('PAN__c').getDescribe().isAccessible()
        ) {
            accountFieldsToQuery.add('PAN__c');
        }

        if (
            proposedValues.containsKey('PAN__c') &&
            accountFieldMap.containsKey('GST__c') &&
            accountFieldMap.get('GST__c').getDescribe().isAccessible()
        ) {
            accountFieldsToQuery.add('GST__c');
        }

        Account accountRecord = queryAccount(accountId, accountFieldsToQuery);
        Orient_Customer_Tracking__c trackingRecord =
            queryTrackingRecord(accountId, trackingFieldsToQuery);

        if (trackingRecord == null) {
            throw new AuraHandledException(
                'No Orient Customer Tracking record is available for this customer.'
            );
        }

        List<PendingChange> changes = new List<PendingChange>();

        for (String fieldApi : proposedValues.keySet()) {
            Orient_Customer_Field_Mapping__mdt mapping =
                mappingByAccountField.get(fieldApi);

            Boolean trackingLocked =
                (Boolean) trackingRecord.get(mapping.Tracking_Field_API__c);

            if (
                trackingLocked != true &&
                kycSubmissionContext != true
            ) {
                throw new AuraHandledException(
                    '"' + mapping.Field_Label__c +
                    '" is no longer locked for Customer Profile approval. ' +
                    'Refresh the customer record and try again.'
                );
            }

            if (
                kycSubmissionContext != true &&
                mapping.Change_Mode__c == CHANGE_MODE_VERIFIED &&
                String.isNotBlank(mapping.Verification_Field_API__c) &&
                accountFieldMap.containsKey(mapping.Verification_Field_API__c) &&
                ((Boolean) accountRecord.get(mapping.Verification_Field_API__c)) == true
            ) {
                throw new AuraHandledException(
                    mapping.Field_Label__c +
                    ' is already verified and cannot be changed.'
                );
            }

            Schema.DescribeFieldResult fieldDescribe =
                accountFieldMap.get(fieldApi).getDescribe();

            Object oldValue = accountRecord.get(fieldApi);
            Object newValue = convertIncomingValue(
                proposedValues.get(fieldApi),
                fieldDescribe
            );

            if (
                valuesEqual(
                    oldValue,
                    newValue,
                    fieldDescribe.getType()
                ) &&
                !(
                    kycSubmissionContext == true &&
                    fieldApi == kycPrimaryFieldContext
                )
            ) {
                continue;
            }

            PendingChange change = new PendingChange();
            change.mapping = mapping;
            change.fieldDescribe = fieldDescribe;
            change.oldValue = oldValue;
            change.newValue = newValue;
            change.oldRawValue = serializeValue(oldValue);
            change.newRawValue = serializeValue(newValue);
            change.oldDisplayValue = formatDisplayValue(oldValue, fieldDescribe);
            change.newDisplayValue = formatDisplayValue(newValue, fieldDescribe);
            changes.add(change);
        }

        if (changes.isEmpty()) {
            throw new AuraHandledException(
                'The requested values already match the current customer profile.'
            );
        }

        populateReferenceDisplayValues(changes);
        validateBusinessFieldRules(accountRecord, changes);
        validateNoDuplicateContactValues(accountId, changes);
        validateNoOverlappingOpenRequest(accountId, changes);

        User submittingUser = [
            SELECT Id, Name, Location_Code__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];

        if (String.isBlank(submittingUser.Location_Code__c)) {
            throw new AuraHandledException(
                'Your Location Code is not configured. Please contact your Salesforce Administrator.'
            );
        }

        Store__c approvalStore = resolveStore(submittingUser.Location_Code__c);
        CustomerApprovalResolution approvalResolution =
            resolveCustomerApprovalRouting(approvalStore);

        Approval_Hierarchy__c hierarchy = approvalResolution.hierarchy;
        Approval_Hierarchy_Level__c firstLevel = approvalResolution.firstLevel;
        Approval_Approver_Mapping__c firstMapping = approvalResolution.firstMapping;

        Boolean hasBCApplicableChange = false;
        for (PendingChange change : changes) {
            if (change.mapping.BC_Push_Supported__c == true) {
                hasBCApplicableChange = true;
                break;
            }
        }

        Datetime actionDateTime = System.now();

        Orient_Customer_Change_Request__c requestRecord =
            new Orient_Customer_Change_Request__c(
                Orient_Customer__c = accountId,
                Orient_Customer_Tracking__c = trackingRecord.Id,
                Request_Type__c = REQUEST_TYPE_PROFILE,
                Approval_Store__c = approvalStore.Id,
                Location_Code__c = submittingUser.Location_Code__c.trim(),
                Approval_Hierarchy__c = hierarchy.Id,
                Approval_Status__c = STATUS_PENDING,
                Request_Status__c = REQUEST_STATUS_OPEN,
                Change_Reason__c = reason.trim(),
                Submitted_By__c = submittingUser.Id,
                Submitted_Date_Time__c = actionDateTime,
                Submission_Cycle__c = 1,
                Last_Action__c = ACTION_SUBMITTED,
                Last_Action_By__c = submittingUser.Id,
                Last_Action_Date_Time__c = actionDateTime,
                BC_Push_Status__c = hasBCApplicableChange
                    ? null
                    : BC_STATUS_NOT_REQUIRED,
                BC_Push_Attempt_Count__c = 0
            );

        insert as user requestRecord;

        List<Orient_Customer_Change_Item__c> itemRecords =
            new List<Orient_Customer_Change_Item__c>();

        for (PendingChange change : changes) {
            itemRecords.add(
                new Orient_Customer_Change_Item__c(
                    Change_Request__c = requestRecord.Id,
                    Account_Field_API__c = change.mapping.Account_Field_API__c,
                    Field_Label__c = change.mapping.Field_Label__c,
                    Field_Data_Type__c = String.valueOf(
                        change.fieldDescribe.getType()
                    ),
                    Section_Name__c = change.mapping.Section_Name__c,
                    Sequence__c = change.mapping.Sequence__c,
                    Tracking_Field_API__c = change.mapping.Tracking_Field_API__c,
                    Old_Value__c = change.oldRawValue,
                    New_Value__c = change.newRawValue,
                    Old_Display_Value__c = change.oldDisplayValue,
                    New_Display_Value__c = change.newDisplayValue,
                    Value_Source__c = VALUE_SOURCE_USER,
                    BC_Push_Applicable__c = change.mapping.BC_Push_Supported__c,
                    BC_Payload_Key__c = change.mapping.BC_Payload_Key__c,
                    Item_Approval_Status__c = STATUS_PENDING,
                    Submission_Cycle__c = 1
                )
            );
        }

        insert as user itemRecords;

        Tagged_Approval_Hierarchy__c approvalTransaction =
            new Tagged_Approval_Hierarchy__c(
                Approval_Hierarchy__c = hierarchy.Id,
                Customer_Change_Request__c = requestRecord.Id,
                Approval_Status__c = STATUS_PENDING,
                Current_Approval_Level__c = firstLevel.Id,
                Pending_With__c = firstMapping.Approver_User__c,
                Returned_From_Level__c = null,
                Submission_Cycle__c = 1,
                Submitted_By__c = submittingUser.Id,
                Submitted_Date_Time__c = actionDateTime,
                Last_Action__c = ACTION_SUBMITTED,
                Last_Action_By__c = submittingUser.Id,
                Last_Action_Date_Time__c = actionDateTime,
                Last_Action_Comments__c = reason.trim()
            );

        insert as user approvalTransaction;

        Approval_Action_History__c historyRecord =
            new Approval_Action_History__c(
                Approval_Transaction__c = approvalTransaction.Id,
                Approval_Level__c = firstLevel.Id,
                Action__c = ACTION_SUBMITTED,
                Action_By__c = submittingUser.Id,
                Action_Date_Time__c = actionDateTime,
                Assigned_To__c = firstMapping.Approver_User__c,
                Comments__c = reason.trim(),
                Previous_Status__c = STATUS_NOT_SUBMITTED,
                New_Status__c = STATUS_PENDING,
                Submission_Cycle__c = 1
            );

        insert as user historyRecord;

        requestRecord = [
            SELECT Id, Name
            FROM Orient_Customer_Change_Request__c
            WHERE Id = :requestRecord.Id
            WITH USER_MODE
            LIMIT 1
        ];

        SubmitResult result = new SubmitResult();
        result.success = true;
        result.requestId = requestRecord.Id;
        result.requestName = requestRecord.Name;
        result.approvalTransactionId = approvalTransaction.Id;
        result.pendingWithId = firstMapping.Approver_User__c;
        result.pendingWithName = getUserName(
            firstMapping.Approver_User__c
        );
        result.changeCount = itemRecords.size();
        result.message =
            requestRecord.Name + ' was sent for Customer Profile approval.';
        return result;
    }

    @TestVisible
    private static String normalizeKycMethod(
        String kycMethod
    ) {
        if (String.isBlank(kycMethod)) {
            throw new AuraHandledException(
                'KYC method is required.'
            );
        }

        String normalized =
            kycMethod
                .replaceAll('[^A-Za-z0-9]', '')
                .toUpperCase();

        if (normalized == 'PAN') {
            return KYC_METHOD_PAN;
        }

        if (
            normalized == 'VOTER' ||
            normalized == 'VOTERID'
        ) {
            return KYC_METHOD_VOTER;
        }

        if (
            normalized == 'GST' ||
            normalized == 'GSTIN'
        ) {
            return KYC_METHOD_GST;
        }

        throw new AuraHandledException(
            'Unsupported KYC method: ' +
            kycMethod + '.'
        );
    }

    @TestVisible
    private static Set<String> getKycAllowedFieldApis(
        String normalizedKycMethod
    ) {
        if (normalizedKycMethod == KYC_METHOD_PAN) {
            return new Set<String>{
                'PAN__c',
                'Name',
                'Date_Of_Birth__c',
                'Gender__c'
            };
        }

        if (normalizedKycMethod == KYC_METHOD_VOTER) {
            return new Set<String>{
                'Voter__c',
                'Name',
                'Gender__c'
            };
        }

        if (normalizedKycMethod == KYC_METHOD_GST) {
            return new Set<String>{
                'GST__c',
                'Name'
            };
        }

        return new Set<String>();
    }

    @TestVisible
    private static String getKycPrimaryFieldApi(
        String normalizedKycMethod
    ) {
        if (normalizedKycMethod == KYC_METHOD_PAN) {
            return 'PAN__c';
        }

        if (normalizedKycMethod == KYC_METHOD_VOTER) {
            return 'Voter__c';
        }

        if (normalizedKycMethod == KYC_METHOD_GST) {
            return 'GST__c';
        }

        return null;
    }

    @TestVisible
    private static String getKycDisplayName(
        String normalizedKycMethod
    ) {
        if (normalizedKycMethod == KYC_METHOD_PAN) {
            return 'PAN KYC';
        }

        if (normalizedKycMethod == KYC_METHOD_VOTER) {
            return 'Voter ID KYC';
        }

        return 'GSTIN KYC';
    }

    @TestVisible
    private static String getKycReasonMarker(
        String normalizedKycMethod
    ) {
        if (normalizedKycMethod == KYC_METHOD_PAN) {
            return '[KYC:PAN]';
        }

        if (normalizedKycMethod == KYC_METHOD_VOTER) {
            return '[KYC:VOTER]';
        }

        if (normalizedKycMethod == KYC_METHOD_GST) {
            return '[KYC:GST]';
        }

        return null;
    }

    @TestVisible
    private static String buildKycChangeReason(
        String normalizedKycMethod,
        String verificationDetail
    ) {
        String reason =
            getKycReasonMarker(normalizedKycMethod) +
            ' Automatically generated from Surepass ' +
            getKycDisplayName(normalizedKycMethod) +
            ' verification. Verified KYC data differs from the current Customer Profile and requires approval before the controlled values are updated.';

        if (String.isNotBlank(verificationDetail)) {
            reason +=
                ' Verification review: ' +
                verificationDetail.trim();
        }

        return reason;
    }

    @TestVisible
    private static Boolean hasReservedKycReasonMarker(
        String reason
    ) {
        if (String.isBlank(reason)) {
            return false;
        }

        return reason
            .trim()
            .toUpperCase()
            .startsWith('[KYC:');
    }

    @TestVisible
    private static String extractKycMethodFromReason(
        String reason
    ) {
        if (String.isBlank(reason)) {
            return null;
        }

        String normalizedReason =
            reason.trim().toUpperCase();

        if (normalizedReason.startsWith('[KYC:PAN]')) {
            return KYC_METHOD_PAN;
        }

        if (normalizedReason.startsWith('[KYC:VOTER]')) {
            return KYC_METHOD_VOTER;
        }

        if (normalizedReason.startsWith('[KYC:GST]')) {
            return KYC_METHOD_GST;
        }

        return null;
    }

    @TestVisible
    private static String buildKycResubmissionReason(
        String normalizedKycMethod,
        String correctionReason
    ) {
        return
            getKycReasonMarker(normalizedKycMethod) +
            ' KYC-originated Customer Profile request corrected and resubmitted. ' +
            'Correction / Resubmission Reason: ' +
            correctionReason.trim();
    }

    @TestVisible
    private static List<Orient_Customer_Field_Mapping__mdt> getActiveMappings() {
        return [
            SELECT DeveloperName,
                   MasterLabel,
                   Active__c,
                   Account_Field_API__c,
                   Tracking_Field_API__c,
                   Field_Label__c,
                   Section_Name__c,
                   Sequence__c,
                   Requires_Approval__c,
                   BC_Push_Supported__c,
                   BC_Payload_Key__c,
                   Change_Mode__c,
                   Verification_Field_API__c
            FROM Orient_Customer_Field_Mapping__mdt
            WHERE Active__c = true
            ORDER BY Sequence__c, MasterLabel
        ];
    }

    @TestVisible
    private static Map<String, Orient_Customer_Field_Mapping__mdt>
        getMappingByAccountField() {

        Map<String, Orient_Customer_Field_Mapping__mdt> result =
            new Map<String, Orient_Customer_Field_Mapping__mdt>();

        for (Orient_Customer_Field_Mapping__mdt mapping : getActiveMappings()) {
            if (
                mapping.Requires_Approval__c != true ||
                (
                    mapping.Change_Mode__c != CHANGE_MODE_STANDARD &&
                    mapping.Change_Mode__c != CHANGE_MODE_VERIFIED &&
                    mapping.Change_Mode__c != CHANGE_MODE_ADDRESS
                ) ||
                String.isBlank(mapping.Account_Field_API__c)
            ) {
                continue;
            }

            if (result.containsKey(mapping.Account_Field_API__c)) {
                throw new AuraHandledException(
                    'Duplicate active Customer Field Mapping found for ' +
                    mapping.Account_Field_API__c + '.'
                );
            }

            result.put(mapping.Account_Field_API__c, mapping);
        }

        return result;
    }

    @TestVisible
    private static Map<String, Object> parseChanges(String changesJson) {
        if (String.isBlank(changesJson)) {
            return new Map<String, Object>();
        }

        try {
            Object parsed = JSON.deserializeUntyped(changesJson);
            if (!(parsed instanceof Map<String, Object>)) {
                throw new AuraHandledException('Invalid customer change payload.');
            }
            return (Map<String, Object>) parsed;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Invalid customer change payload.');
        }
    }

    @TestVisible
    private static void validateMappingForApproval(
        String fieldApi,
        Orient_Customer_Field_Mapping__mdt mapping,
        Map<String, Schema.SObjectField> accountFieldMap,
        Map<String, Schema.SObjectField> trackingFieldMap
    ) {
        validateMappingForApproval(
            fieldApi,
            mapping,
            accountFieldMap,
            trackingFieldMap,
            false
        );
    }

    @TestVisible
    private static void validateMappingForApproval(
        String fieldApi,
        Orient_Customer_Field_Mapping__mdt mapping,
        Map<String, Schema.SObjectField> accountFieldMap,
        Map<String, Schema.SObjectField> trackingFieldMap,
        Boolean allowAddressApi
    ) {
        if (mapping == null || mapping.Active__c != true) {
            throw new AuraHandledException(
                'No active Customer Field Mapping is configured for ' + fieldApi + '.'
            );
        }

        if (!accountFieldMap.containsKey(fieldApi)) {
            throw new AuraHandledException(
                'Account field ' + fieldApi + ' does not exist.'
            );
        }

        Schema.DescribeFieldResult accountDescribe =
            accountFieldMap.get(fieldApi).getDescribe();

        if (!accountDescribe.isAccessible() || !accountDescribe.isUpdateable()) {
            throw new AuraHandledException(
                'You do not have permission to request a change for ' +
                mapping.Field_Label__c + '.'
            );
        }

        if (
            String.isBlank(mapping.Tracking_Field_API__c) ||
            !trackingFieldMap.containsKey(mapping.Tracking_Field_API__c)
        ) {
            throw new AuraHandledException(
                'Tracking field is not configured correctly for ' +
                mapping.Field_Label__c + '.'
            );
        }

        Schema.DescribeFieldResult trackingDescribe =
            trackingFieldMap.get(mapping.Tracking_Field_API__c).getDescribe();

        if (!trackingDescribe.isAccessible()) {
            throw new AuraHandledException(
                'You do not have access to the Customer Tracking configuration for ' +
                mapping.Field_Label__c + '.'
            );
        }

        if (trackingDescribe.getType() != Schema.DisplayType.Boolean) {
            throw new AuraHandledException(
                'Tracking field for ' + mapping.Field_Label__c +
                ' must be a Checkbox.'
            );
        }

        if (mapping.Requires_Approval__c != true) {
            throw new AuraHandledException(
                mapping.Field_Label__c + ' is not configured for approval.'
            );
        }

        if (mapping.Change_Mode__c == CHANGE_MODE_VERIFIED) {
            if (
                String.isBlank(mapping.Verification_Field_API__c) ||
                !accountFieldMap.containsKey(
                    mapping.Verification_Field_API__c
                )
            ) {
                throw new AuraHandledException(
                    'Verification field is not configured correctly for ' +
                    mapping.Field_Label__c + '.'
                );
            }

            Schema.DescribeFieldResult verificationDescribe =
                accountFieldMap.get(
                    mapping.Verification_Field_API__c
                ).getDescribe();

            if (!verificationDescribe.isAccessible()) {
                throw new AuraHandledException(
                    'You do not have access to the verification status for ' +
                    mapping.Field_Label__c + '.'
                );
            }

            if (
                verificationDescribe.getType() !=
                    Schema.DisplayType.Boolean
            ) {
                throw new AuraHandledException(
                    'Verification field for ' +
                    mapping.Field_Label__c +
                    ' must be a Checkbox.'
                );
            }
        }

        if (
            mapping.Change_Mode__c ==
                CHANGE_MODE_ADDRESS &&
            allowAddressApi != true
        ) {
            throw new AuraHandledException(
                mapping.Field_Label__c +
                ' can be changed only through the Business Central Address selector.'
            );
        }

        if (mapping.Change_Mode__c == CHANGE_MODE_NEVER) {
            throw new AuraHandledException(
                mapping.Field_Label__c + ' cannot be changed.'
            );
        }

        if (
            mapping.Change_Mode__c != CHANGE_MODE_STANDARD &&
            mapping.Change_Mode__c != CHANGE_MODE_VERIFIED &&
            !(
                mapping.Change_Mode__c ==
                    CHANGE_MODE_ADDRESS &&
                allowAddressApi == true
            )
        ) {
            throw new AuraHandledException(
                'Unsupported Change Mode for ' + mapping.Field_Label__c + '.'
            );
        }
    }

    @TestVisible
    private static Account queryAccount(Id accountId, Set<String> fieldsToQuery) {
        Map<String, Schema.SObjectField> fieldMap =
            Schema.SObjectType.Account.fields.getMap();
        List<String> fields = new List<String>();

        for (String fieldApi : fieldsToQuery) {
            if (!fieldMap.containsKey(fieldApi)) {
                continue;
            }

            if (fieldMap.get(fieldApi).getDescribe().isAccessible()) {
                fields.add(fieldApi);
            }
        }

        if (!fields.contains('Id')) {
            fields.add('Id');
        }
        if (fieldMap.containsKey('Name') &&
            fieldMap.get('Name').getDescribe().isAccessible() &&
            !fields.contains('Name')) {
            fields.add('Name');
        }

        fields.sort();

        String soql =
            'SELECT ' + String.join(fields, ',') +
            ' FROM Account WHERE Id = :accountId LIMIT 1';

        List<SObject> rows = Database.query(soql);
        if (rows.isEmpty()) {
            throw new AuraHandledException('Customer could not be found.');
        }
        return (Account) rows[0];
    }

    @TestVisible
    private static Orient_Customer_Tracking__c queryTrackingRecord(
        Id accountId,
        Set<String> fieldsToQuery
    ) {
        Map<String, Schema.SObjectField> fieldMap =
            Schema.SObjectType.Orient_Customer_Tracking__c.fields.getMap();
        List<String> fields = new List<String>();

        for (String fieldApi : fieldsToQuery) {
            if (!fieldMap.containsKey(fieldApi)) {
                continue;
            }

            if (fieldMap.get(fieldApi).getDescribe().isAccessible()) {
                fields.add(fieldApi);
            }
        }

        if (!fields.contains('Id')) {
            fields.add('Id');
        }

        if (
            fieldMap.containsKey('Orient_Customer__c') &&
            fieldMap.get('Orient_Customer__c').getDescribe().isAccessible() &&
            !fields.contains('Orient_Customer__c')
        ) {
            fields.add('Orient_Customer__c');
        }

        fields.sort();

        String soql =
            'SELECT ' + String.join(fields, ',') +
            ' FROM Orient_Customer_Tracking__c' +
            ' WHERE Orient_Customer__c = :accountId' +
            ' LIMIT 1';

        List<SObject> rows = Database.query(soql);
        return rows.isEmpty()
            ? null
            : (Orient_Customer_Tracking__c) rows[0];
    }

    @TestVisible
    private static Object convertIncomingValue(
        Object rawValue,
        Schema.DescribeFieldResult fieldDescribe
    ) {
        if (rawValue == null) {
            return null;
        }

        String stringValue = String.valueOf(rawValue);
        Schema.DisplayType typeValue = fieldDescribe.getType();

        if (
            typeValue == Schema.DisplayType.String ||
            typeValue == Schema.DisplayType.TextArea ||
            typeValue == Schema.DisplayType.Phone ||
            typeValue == Schema.DisplayType.Email ||
            typeValue == Schema.DisplayType.Url ||
            typeValue == Schema.DisplayType.Picklist ||
            typeValue == Schema.DisplayType.MultiPicklist ||
            typeValue == Schema.DisplayType.EncryptedString
        ) {
            return stringValue;
        }

        if (typeValue == Schema.DisplayType.Reference || typeValue == Schema.DisplayType.Id) {
            return String.isBlank(stringValue) ? null : (Id) stringValue;
        }

        if (typeValue == Schema.DisplayType.Boolean) {
            return rawValue instanceof Boolean
                ? rawValue
                : Boolean.valueOf(stringValue);
        }

        if (typeValue == Schema.DisplayType.Date) {
            return String.isBlank(stringValue)
                ? null
                : Date.valueOf(stringValue);
        }

        if (typeValue == Schema.DisplayType.DateTime) {
            if (String.isBlank(stringValue)) {
                return null;
            }
            String normalized = stringValue.replace('T', ' ').replace('Z', '');
            return Datetime.valueOf(normalized);
        }

        if (typeValue == Schema.DisplayType.Integer) {
            return String.isBlank(stringValue)
                ? null
                : Integer.valueOf(stringValue);
        }

        if (
            typeValue == Schema.DisplayType.Double ||
            typeValue == Schema.DisplayType.Currency ||
            typeValue == Schema.DisplayType.Percent
        ) {
            return String.isBlank(stringValue)
                ? null
                : Decimal.valueOf(stringValue);
        }

        return rawValue;
    }

    @TestVisible
    private static Boolean valuesEqual(
        Object oldValue,
        Object newValue,
        Schema.DisplayType fieldType
    ) {
        if (oldValue == null && newValue == null) {
            return true;
        }
        if (oldValue == null || newValue == null) {
            return false;
        }

        if (
            fieldType == Schema.DisplayType.String ||
            fieldType == Schema.DisplayType.TextArea ||
            fieldType == Schema.DisplayType.Phone ||
            fieldType == Schema.DisplayType.Email ||
            fieldType == Schema.DisplayType.Url
        ) {
            return String.valueOf(oldValue) == String.valueOf(newValue);
        }

        return oldValue == newValue;
    }

    @TestVisible
    private static String serializeValue(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    @TestVisible
    private static String formatDisplayValue(
        Object value,
        Schema.DescribeFieldResult fieldDescribe
    ) {
        if (value == null) {
            return '';
        }

        Schema.DisplayType typeValue = fieldDescribe.getType();

        if (typeValue == Schema.DisplayType.Boolean) {
            return ((Boolean) value) ? 'Yes' : 'No';
        }

        if (typeValue == Schema.DisplayType.Picklist) {
            String rawValue = String.valueOf(value);
            for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
                if (entry.getValue() == rawValue) {
                    return entry.getLabel();
                }
            }
        }

        if (typeValue == Schema.DisplayType.Date) {
            return ((Date) value).format();
        }

        if (typeValue == Schema.DisplayType.DateTime) {
            return ((Datetime) value).format();
        }

        return String.valueOf(value);
    }

    @TestVisible
    private static void populateFieldRuleReferenceDisplayValues(
        List<FieldRule> rules,
        Account accountRecord,
        Map<String, Schema.SObjectField> accountFieldMap
    ) {
        if (rules == null || rules.isEmpty() || accountRecord == null) {
            return;
        }

        Map<String, Set<Id>> idsByObjectName = new Map<String, Set<Id>>();
        Map<Id, String> displayById = new Map<Id, String>();

        for (FieldRule rule : rules) {
            if (
                rule == null ||
                String.isBlank(rule.accountFieldApi) ||
                !accountFieldMap.containsKey(rule.accountFieldApi)
            ) {
                continue;
            }

            Schema.DescribeFieldResult fieldDescribe =
                accountFieldMap.get(rule.accountFieldApi).getDescribe();

            if (fieldDescribe.getType() != Schema.DisplayType.Reference) {
                continue;
            }

            Object value = accountRecord.get(rule.accountFieldApi);
            if (value == null) {
                continue;
            }

            try {
                Id referenceId = (Id) String.valueOf(value);
                String objectName =
                    referenceId.getSObjectType().getDescribe().getName();

                if (!idsByObjectName.containsKey(objectName)) {
                    idsByObjectName.put(objectName, new Set<Id>());
                }
                idsByObjectName.get(objectName).add(referenceId);
            } catch (Exception ignoreInvalidReference) {
                // Current raw value remains the fallback display.
            }
        }

        for (String objectName : idsByObjectName.keySet()) {
            try {
                Schema.SObjectType objectType =
                    Schema.getGlobalDescribe().get(objectName);

                if (objectType == null) {
                    continue;
                }

                Map<String, Schema.SObjectField> objectFields =
                    objectType.getDescribe().fields.getMap();
                String nameFieldApi;

                for (String fieldApi : objectFields.keySet()) {
                    Schema.DescribeFieldResult describeResult =
                        objectFields.get(fieldApi).getDescribe();

                    if (
                        describeResult.isNameField() &&
                        describeResult.isAccessible()
                    ) {
                        nameFieldApi = fieldApi;
                        break;
                    }
                }

                if (String.isBlank(nameFieldApi)) {
                    continue;
                }

                Set<Id> referenceIds = idsByObjectName.get(objectName);
                String queryString =
                    'SELECT Id,' + nameFieldApi +
                    ' FROM ' + objectName +
                    ' WHERE Id IN :referenceIds';

                for (SObject row : Database.query(queryString)) {
                    displayById.put(
                        (Id) row.get('Id'),
                        String.valueOf(row.get(nameFieldApi))
                    );
                }
            } catch (Exception ignoreReferenceDisplayError) {
                // Current raw value remains the fallback display.
            }
        }

        for (FieldRule rule : rules) {
            if (
                rule == null ||
                String.isBlank(rule.accountFieldApi) ||
                !accountFieldMap.containsKey(rule.accountFieldApi)
            ) {
                continue;
            }

            Schema.DescribeFieldResult fieldDescribe =
                accountFieldMap.get(rule.accountFieldApi).getDescribe();

            if (fieldDescribe.getType() != Schema.DisplayType.Reference) {
                continue;
            }

            Object value = accountRecord.get(rule.accountFieldApi);
            if (value == null) {
                rule.currentDisplayValue = '';
                continue;
            }

            try {
                Id referenceId = (Id) String.valueOf(value);
                rule.currentDisplayValue =
                    displayById.containsKey(referenceId)
                        ? displayById.get(referenceId)
                        : String.valueOf(value);
            } catch (Exception ignoreInvalidReference) {
                rule.currentDisplayValue = String.valueOf(value);
            }
        }
    }

    @TestVisible
    private static void populateReferenceDisplayValues(List<PendingChange> changes) {
        Map<String, Set<Id>> idsByObjectName = new Map<String, Set<Id>>();
        Map<Id, String> displayById = new Map<Id, String>();

        for (PendingChange change : changes) {
            if (change.fieldDescribe.getType() != Schema.DisplayType.Reference) {
                continue;
            }

            for (Object value : new List<Object>{ change.oldValue, change.newValue }) {
                if (value == null) {
                    continue;
                }

                try {
                    Id referenceId = (Id) String.valueOf(value);
                    String objectName = referenceId.getSObjectType().getDescribe().getName();

                    if (!idsByObjectName.containsKey(objectName)) {
                        idsByObjectName.put(objectName, new Set<Id>());
                    }
                    idsByObjectName.get(objectName).add(referenceId);
                } catch (Exception ignoreInvalidReference) {
                    // Keep raw Id as the display fallback.
                }
            }
        }

        for (String objectName : idsByObjectName.keySet()) {
            try {
                Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
                if (objectType == null) {
                    continue;
                }

                String nameFieldApi;
                for (String fieldApi : objectType.getDescribe().fields.getMap().keySet()) {
                    if (objectType.getDescribe().fields.getMap().get(fieldApi).getDescribe().isNameField()) {
                        nameFieldApi = fieldApi;
                        break;
                    }
                }

                if (String.isBlank(nameFieldApi)) {
                    continue;
                }

                Set<Id> referenceIds = idsByObjectName.get(objectName);
                String queryString =
                    'SELECT Id,' + nameFieldApi +
                    ' FROM ' + objectName +
                    ' WHERE Id IN :referenceIds WITH USER_MODE';

                for (SObject row : Database.query(queryString)) {
                    displayById.put(
                        (Id) row.get('Id'),
                        String.valueOf(row.get(nameFieldApi))
                    );
                }
            } catch (Exception ignoreReferenceDisplayError) {
                // Approval still proceeds with the raw reference Id as fallback.
            }
        }

        for (PendingChange change : changes) {
            if (change.fieldDescribe.getType() != Schema.DisplayType.Reference) {
                continue;
            }

            change.oldDisplayValue = resolveReferenceDisplay(change.oldValue, displayById);
            change.newDisplayValue = resolveReferenceDisplay(change.newValue, displayById);
        }
    }

    @TestVisible
    private static String resolveReferenceDisplay(
        Object value,
        Map<Id, String> displayById
    ) {
        if (value == null) {
            return '';
        }

        try {
            Id referenceId = (Id) String.valueOf(value);
            return displayById.containsKey(referenceId)
                ? displayById.get(referenceId)
                : String.valueOf(referenceId);
        } catch (Exception e) {
            return String.valueOf(value);
        }
    }

	@TestVisible
    private static void validateBusinessFieldRules(
        Account accountRecord,
        List<PendingChange> changes
    ) {
        Boolean panChanged = false;
        Boolean gstChanged = false;
        Boolean phoneChanged = false;
        Boolean whatsappChanged = false;
        Boolean aadhaarChanged = false;

        String proposedPan =
            accountRecord.getPopulatedFieldsAsMap().containsKey('PAN__c') &&
            accountRecord.get('PAN__c') != null
                ? String.valueOf(accountRecord.get('PAN__c'))
                    .trim()
                    .toUpperCase()
                : null;

        String proposedGst =
            accountRecord.getPopulatedFieldsAsMap().containsKey('GST__c') &&
            accountRecord.get('GST__c') != null
                ? String.valueOf(accountRecord.get('GST__c'))
                    .trim()
                    .toUpperCase()
                : null;

        String proposedPhone;
        String proposedWhatsapp;
        String proposedAadhaar;

        for (PendingChange change : changes) {
            String fieldApi = change.mapping.Account_Field_API__c;
            String value = change.newValue == null
                ? null
                : String.valueOf(change.newValue).trim();

            if (fieldApi == 'PAN__c') {
                panChanged = true;
                proposedPan = String.isBlank(value)
                    ? null
                    : value.toUpperCase();
                change.newValue = proposedPan;
                change.newRawValue = proposedPan;
                change.newDisplayValue = proposedPan;
            } else if (fieldApi == 'GST__c') {
                gstChanged = true;
                proposedGst = String.isBlank(value)
                    ? null
                    : value.toUpperCase();
                change.newValue = proposedGst;
                change.newRawValue = proposedGst;
                change.newDisplayValue = proposedGst;
            } else if (fieldApi == 'Phone') {
                phoneChanged = true;
                proposedPhone = normalizePhone(change.newValue);
                change.newValue = proposedPhone;
                change.newRawValue = proposedPhone;
                change.newDisplayValue = proposedPhone;
            } else if (fieldApi == 'Whatsapp_number__c') {
                whatsappChanged = true;
                proposedWhatsapp = normalizePhone(change.newValue);
                change.newValue = proposedWhatsapp;
                change.newRawValue = proposedWhatsapp;
                change.newDisplayValue = proposedWhatsapp;
            } else if (fieldApi == 'AadharNo__c') {
                aadhaarChanged = true;
                proposedAadhaar = normalizePhone(change.newValue);
                change.newValue = proposedAadhaar;
                change.newRawValue = proposedAadhaar;
                change.newDisplayValue = proposedAadhaar;
            }
        }

        if (
            (panChanged || gstChanged) &&
            String.isNotBlank(proposedPan) &&
            !Pattern.matches(
                '^[A-Z]{5}[0-9]{4}[A-Z]{1}$',
                proposedPan
            )
        ) {
            throw new AuraHandledException(
                'Invalid PAN format. It must contain 5 letters, 4 numbers, and 1 letter.'
            );
        }

        if (
            (panChanged || gstChanged) &&
            String.isNotBlank(proposedGst)
        ) {
            if (String.isBlank(proposedPan)) {
                throw new AuraHandledException(
                    'PAN is mandatory when GST is provided.'
                );
            }

            if (
                !Pattern.matches(
                    '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
                    proposedGst
                )
            ) {
                throw new AuraHandledException(
                    'Invalid GST format.'
                );
            }

            if (
                proposedGst.length() >= 12 &&
                proposedGst.substring(2, 12) != proposedPan
            ) {
                throw new AuraHandledException(
                    'The GST number does not match the PAN.'
                );
            }
        }

        if (
            phoneChanged &&
            String.isNotBlank(proposedPhone) &&
            proposedPhone.length() != 10
        ) {
            throw new AuraHandledException(
                'Phone must contain exactly 10 digits.'
            );
        }

        if (
            whatsappChanged &&
            String.isNotBlank(proposedWhatsapp) &&
            proposedWhatsapp.length() != 10
        ) {
            throw new AuraHandledException(
                'WhatsApp number must contain exactly 10 digits.'
            );
        }

        if (
            aadhaarChanged &&
            String.isNotBlank(proposedAadhaar) &&
            proposedAadhaar.length() != 12
        ) {
            throw new AuraHandledException(
                'Aadhaar number must contain exactly 12 digits.'
            );
        }
    }

    @TestVisible
    private static String getUserName(Id userId) {
        if (userId == null) {
            return null;
        }

        List<User> users = [
            SELECT Id, Name
            FROM User
            WHERE Id = :userId
            WITH USER_MODE
            LIMIT 1
        ];

        return users.isEmpty() ? null : users[0].Name;
    }

    @TestVisible
    private static void validateNoDuplicateContactValues(
        Id accountId,
        List<PendingChange> changes
    ) {
        String proposedPhone;
        String proposedWhatsapp;

        for (PendingChange change : changes) {
            if (change.mapping.Account_Field_API__c == 'Phone') {
                proposedPhone = normalizePhone(change.newValue);
            } else if (change.mapping.Account_Field_API__c == 'Whatsapp_number__c') {
                proposedWhatsapp = normalizePhone(change.newValue);
            }
        }

        if (String.isNotBlank(proposedPhone)) {
            List<Account> matches = [
                SELECT Id, Name
                FROM Account
                WHERE Id != :accountId
                AND (
                    Phone = :proposedPhone
                    OR Whatsapp_number__c = :proposedPhone
                )
                WITH USER_MODE
                LIMIT 1
            ];

            if (!matches.isEmpty()) {
                throw new AuraHandledException(
                    'A customer already exists with this mobile number: "' +
                    matches[0].Name + '". Please enter a different mobile number.'
                );
            }
        }

        if (String.isNotBlank(proposedWhatsapp)) {
            List<Account> matches = [
                SELECT Id, Name
                FROM Account
                WHERE Id != :accountId
                AND (
                    Phone = :proposedWhatsapp
                    OR Whatsapp_number__c = :proposedWhatsapp
                )
                WITH USER_MODE
                LIMIT 1
            ];

            if (!matches.isEmpty()) {
                throw new AuraHandledException(
                    'The requested WhatsApp number already belongs to customer "' +
                    matches[0].Name + '".'
                );
            }
        }
    }

    @TestVisible
    private static String normalizePhone(Object value) {
        if (value == null) {
            return null;
        }
        return String.valueOf(value).replaceAll('[^0-9]', '');
    }

    @TestVisible
    private static void validateNoOverlappingOpenRequest(
        Id accountId,
        List<PendingChange> changes
    ) {
        validateNoOverlappingOpenRequest(accountId, changes, null);
    }

    @TestVisible
    private static void validateNoOverlappingOpenRequest(
        Id accountId,
        List<PendingChange> changes,
        Id excludedRequestId
    ) {
        Set<String> changedFieldApis = new Set<String>();
        for (PendingChange change : changes) {
            changedFieldApis.add(change.mapping.Account_Field_API__c);
        }

        /*Set<String> openStatuses = new Set<String>{
            STATUS_PENDING,
            STATUS_RETURNED
        };*/

        Set<String> openStatuses = new Set<String>{
            STATUS_PENDING
        };

        List<Orient_Customer_Change_Item__c> existingItems;

        if (excludedRequestId == null) {
            existingItems = [
                SELECT Id,
                       Account_Field_API__c,
                       Field_Label__c,
                       Change_Request__c,
                       Change_Request__r.Name,
                       Change_Request__r.Approval_Status__c
                FROM Orient_Customer_Change_Item__c
                WHERE Account_Field_API__c IN :changedFieldApis
                AND Change_Request__r.Orient_Customer__c = :accountId
                AND Change_Request__r.Approval_Status__c IN :openStatuses
                WITH USER_MODE
                LIMIT 1
            ];
        } else {
            existingItems = [
                SELECT Id,
                       Account_Field_API__c,
                       Field_Label__c,
                       Change_Request__c,
                       Change_Request__r.Name,
                       Change_Request__r.Approval_Status__c
                FROM Orient_Customer_Change_Item__c
                WHERE Account_Field_API__c IN :changedFieldApis
                AND Change_Request__r.Orient_Customer__c = :accountId
                AND Change_Request__r.Approval_Status__c IN :openStatuses
                AND Change_Request__c != :excludedRequestId
                WITH USER_MODE
                LIMIT 1
            ];
        }

        if (!existingItems.isEmpty()) {
            Orient_Customer_Change_Item__c existingItem = existingItems[0];
            throw new AuraHandledException(
                'Change request "' + existingItem.Change_Request__r.Name +
                '" is already ' + existingItem.Change_Request__r.Approval_Status__c +
                ' for "' + existingItem.Field_Label__c +
                '". Complete that request before resubmitting this field.'
            );
        }
    }

    @TestVisible
    private static Store__c resolveStore(String locationCode) {
        String normalizedLocationCode = locationCode.trim();

        List<Store__c> stores = [
            SELECT Id, Name, Store_Code__c
            FROM Store__c
            WHERE Store_Code__c = :normalizedLocationCode
            WITH USER_MODE
            ORDER BY Name
            LIMIT 2
        ];

        if (stores.isEmpty()) {
            throw new AuraHandledException(
                'No Store is configured for Location Code "' +
                normalizedLocationCode + '".'
            );
        }

        if (stores.size() > 1) {
            throw new AuraHandledException(
                'Multiple Stores are configured for Location Code "' +
                normalizedLocationCode + '".'
            );
        }

        return stores[0];
    }

    @TestVisible
    private static Approval_Hierarchy__c resolveHierarchy(Id storeId) {
        List<Approval_Hierarchy__c> hierarchies = [
            SELECT Id, Name, Store__c, Store__r.Name, Type__c
            FROM Approval_Hierarchy__c
            WHERE Store__c = :storeId
            AND Type__c = :APPROVAL_TYPE
            WITH USER_MODE
            LIMIT 2
        ];

        if (hierarchies.isEmpty()) {
            throw new AuraHandledException(
                'No Customer Profile approval hierarchy is configured for this Store.'
            );
        }

        if (hierarchies.size() > 1) {
            throw new AuraHandledException(
                'Multiple Customer Profile approval hierarchies are configured for Store "' +
                hierarchies[0].Store__r.Name + '".'
            );
        }

        return hierarchies[0];
    }

    @TestVisible
    private static CustomerApprovalResolution resolveCustomerApprovalRouting(
        Store__c approvalStore
    ) {
        if (approvalStore == null || approvalStore.Id == null) {
            throw new AuraHandledException(
                'Approval Store could not be resolved for Customer Profile approval.'
            );
        }

        Approval_Hierarchy__c hierarchy = resolveHierarchy(approvalStore.Id);

        List<Approval_Hierarchy_Level__c> levels = [
            SELECT Id, Name, Approval_Hierarchy__c, Responsible_Team__c, Sr_No__c
            FROM Approval_Hierarchy_Level__c
            WHERE Approval_Hierarchy__c = :hierarchy.Id
            WITH USER_MODE
            ORDER BY Sr_No__c ASC, CreatedDate ASC
        ];

        if (levels.isEmpty()) {
            throw new AuraHandledException(
                'No approval level is configured for the Customer Profile hierarchy of Store "' +
                approvalStore.Name + '".'
            );
        }

        Set<Decimal> usedSequences = new Set<Decimal>();
        Set<Id> levelIds = new Set<Id>();

        for (Approval_Hierarchy_Level__c levelRecord : levels) {
            if (levelRecord.Sr_No__c == null) {
                throw new AuraHandledException(
                    'Approval sequence is missing for level "' +
                    getApprovalLevelLabel(levelRecord) + '".'
                );
            }

            if (usedSequences.contains(levelRecord.Sr_No__c)) {
                throw new AuraHandledException(
                    'Duplicate approval sequence ' +
                    String.valueOf(levelRecord.Sr_No__c) +
                    ' is configured in the Customer Profile hierarchy of Store "' +
                    approvalStore.Name + '".'
                );
            }

            usedSequences.add(levelRecord.Sr_No__c);
            levelIds.add(levelRecord.Id);
        }

        Date todayValue = Date.today();
        List<Approval_Approver_Mapping__c> mappings = [
            SELECT Id, Approval_Hierarchy_Level__c, Approver_User__c,
                   Approver_User__r.Name, Approver_User__r.IsActive,
                   Active__c, Is_Primary__c, Effective_From__c, Effective_To__c
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

        Map<Id, List<Approval_Approver_Mapping__c>> mappingsByLevel =
            new Map<Id, List<Approval_Approver_Mapping__c>>();

        for (Approval_Approver_Mapping__c mappingRecord : mappings) {
            if (!mappingsByLevel.containsKey(mappingRecord.Approval_Hierarchy_Level__c)) {
                mappingsByLevel.put(
                    mappingRecord.Approval_Hierarchy_Level__c,
                    new List<Approval_Approver_Mapping__c>()
                );
            }
            mappingsByLevel.get(mappingRecord.Approval_Hierarchy_Level__c).add(mappingRecord);
        }

        for (Approval_Hierarchy_Level__c levelRecord : levels) {
            List<Approval_Approver_Mapping__c> levelMappings = mappingsByLevel.get(levelRecord.Id);
            String levelLabel = getApprovalLevelLabel(levelRecord);

            if (levelMappings == null || levelMappings.isEmpty()) 
                throw new AuraHandledException('No active primary approver is configured for approval level "' + levelLabel + '".');

            if (levelMappings.size() > 1) 
                throw new AuraHandledException('Multiple active primary approvers are configured for approval level "' + levelLabel + '".');
        }

        CustomerApprovalResolution result = new CustomerApprovalResolution();
        result.hierarchy = hierarchy;
        result.firstLevel = levels[0];
        result.firstMapping = mappingsByLevel.get(levels[0].Id)[0];
        return result;
    }

    @TestVisible
    private static String getApprovalLevelLabel(Approval_Hierarchy_Level__c levelRecord) {
        if (levelRecord == null) 
            return 'Unknown Level';

        return String.isNotBlank(levelRecord.Responsible_Team__c)? levelRecord.Responsible_Team__c : levelRecord.Name;
    }
   
}