public with sharing class FeedbackController {
    
    @AuraEnabled(cacheable=true)
    public static List<Feedback_Question__c> getFeedbackQuestions() {
        return [
            SELECT Id, Question_EN__c, Question_BN__c, Sequence__c
            FROM Feedback_Question__c
            ORDER BY Sequence__c ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getFeedbackVideoUrls() {
        String searchTitle = '%feedbackvideo%';
        List<ContentVersion> cvs = [
            SELECT Id, Title FROM ContentVersion 
            WHERE Title LIKE :searchTitle AND IsLatest = true 
            ORDER BY CreatedDate DESC
        ];
        
        List<String> urls = new List<String>();
        for (ContentVersion cv : cvs) {
            urls.add('/sfc/servlet.shepherd/version/download/' + cv.Id);
        }
        
        return urls;
    }

    // --- PROFILE UPDATE & OTP LOGIC ---

    /**
     * Step 1 of a profile update: sends a one-time code to the destination the
     * customer is asking us to move to, so the code proves they hold it. An
     * email change is verified by email, everything else by SMS; only when the
     * request leaves that destination alone does the code go to what is already
     * on the record. Nothing is written to the approval queue until the code
     * comes back verified.
     *
     * @param newMobile     the mobile number typed on the profile screen, or
     *                      blank when this request does not change the mobile
     * @param newEmail      the email address typed on the profile screen, or
     *                      blank when this request does not change the email
     * @param changedFields the profile fields being changed, which pick the
     *                      template - each kind of change is registered with its
     *                      own wording, so the message has to know what it is about
     */
    @AuraEnabled
    public static FDB_OtpService.SendResult sendProfileUpdateOtp(
        Id accountId, String newMobile, String newEmail, List<String> changedFields) {
        try {
            String mobile = normaliseMobile(newMobile);

            if (String.isNotBlank(newMobile) && !isValidMobile(mobile)) {
                throw new AuraHandledException(
                    'Please enter a valid 10-digit mobile number before requesting a code.');
            }

            if (String.isNotBlank(newEmail) && !isValidEmail(newEmail.trim())) {
                throw new AuraHandledException(
                    'Please enter a valid email address before requesting a code.');
            }

            return FDB_OtpService.send(
                accountId, 'Profile Update', changedFields, mobile,
                newEmail == null ? null : newEmail.trim());
        } catch (FDB_OtpService.OtpException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (FDB_ShreeSmsGateway.ConfigurationException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to send verification code: ' + e.getMessage());
        }
    }

    /** Digits only, with any leading 91 / +91 country code dropped. */
    @TestVisible
    private static String normaliseMobile(String mobile) {
        if (String.isBlank(mobile)) return '';
        String digits = mobile.replaceAll('[^0-9]', '');
        if (digits.length() > 10) {
            digits = digits.substring(digits.length() - 10);
        }
        return digits;
    }

    /** Indian mobile numbers are 10 digits and start 6-9. */
    @TestVisible
    private static Boolean isValidMobile(String digits) {
        return String.isNotBlank(digits) && Pattern.matches('[6-9][0-9]{9}', digits);
    }

    /**
     * Deliberately loose. The real proof that an address is good is that the
     * code sent to it comes back, so this only needs to catch a typo before we
     * spend a send on it.
     */
    @TestVisible
    private static Boolean isValidEmail(String address) {
        return String.isNotBlank(address)
            && Pattern.matches('[^@\\s]+@[^@\\s.]+(\\.[^@\\s.]+)+', address);
    }

    /**
     * Step 2: verifies the code and, only on success, logs the requested
     * changes for approval.
     *
     */
    @AuraEnabled
    public static String verifyAndSubmitProfileUpdate(
        Id accountId, Id showroomVisitId, String payloadJson, String otpReference, String otpCode) {
        try {
            if (!FDB_OtpService.verify(otpReference, otpCode)) {
                return null;
            }
            return submitProfileUpdateRequest(accountId, showroomVisitId, payloadJson);
        } catch (FDB_OtpService.OtpException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to verify the code: ' + e.getMessage());
        }
    }

    /**
     * Raises the customer's request as a real approval, not just a log line.
     *
     * It writes the same records the back-office profile change screen writes -
     * a Change Request header, one Change Item per field, an approval
     * transaction parked at level 1, and the opening audit row - so a request
     * made at the counter lands in the one approver workspace alongside every
     * other customer profile change. The Profile Update Log stays as the
     * customer-side record of what was asked for and that a code proved it.
     *
     */
    @AuraEnabled
    public static String submitProfileUpdateRequest(Id accountId, Id showroomVisitId, String payloadJson) {
        try {
            Map<String, String> requestedValues = parseProfilePayload(payloadJson);

            if (requestedValues.isEmpty()) {
                throw new AuraHandledException('No profile changes were selected, so nothing was raised.');
            }

            Map<String, Orient_Customer_Field_Mapping__mdt> mappingByField =
                getProfileFieldMappings(requestedValues.keySet());

            Account customer = queryCustomerForApproval(accountId, mappingByField.values());
            Orient_Customer_Tracking__c tracking = getCustomerTracking(accountId);
            List<ProfileChange> changes = buildProfileChanges(customer, mappingByField, requestedValues);

            // validateNoDuplicateContact(accountId, changes);
            validateNoPendingApproval(accountId, changes);

            ApprovalRouting routing = resolveProfileApprovalRouting(showroomVisitId, accountId);

            Id submitterId = UserInfo.getUserId();
            Datetime actionedAt = System.now();

            Boolean pushesToBc = false;
            for (ProfileChange change : changes) {
                pushesToBc = pushesToBc || change.mapping.BC_Push_Supported__c == true;
            }

            Orient_Customer_Change_Request__c request = new Orient_Customer_Change_Request__c(
                Orient_Customer__c = accountId,
                Orient_Customer_Tracking__c = tracking == null ? null : tracking.Id,
                Request_Type__c = REQUEST_TYPE_PROFILE,
                Approval_Store__c = routing.store.Id,
                Location_Code__c = routing.store.Store_Code__c,
                Approval_Hierarchy__c = routing.hierarchy.Id,
                Approval_Status__c = STATUS_PENDING,
                Request_Status__c = REQUEST_STATUS_OPEN,
                Change_Reason__c = CHANGE_REASON,
                Submitted_By__c = submitterId,
                Submitted_Date_Time__c = actionedAt,
                BC_Customer_No__c = (String) customer.get('BC_Customer_No__c'),
                Last_Action__c = ACTION_SUBMITTED,
                Last_Action_By__c = submitterId,
                Last_Action_Date_Time__c = actionedAt,
                BC_Push_Status__c = pushesToBc ? null : BC_STATUS_NOT_REQUIRED,
                BC_Push_Attempt_Count__c = 0
            );

            insert request;

            List<Orient_Customer_Change_Item__c> items = new List<Orient_Customer_Change_Item__c>();

            for (ProfileChange change : changes) {
                items.add(new Orient_Customer_Change_Item__c(
                    Change_Request__c = request.Id,
                    Account_Field_API__c = change.mapping.Account_Field_API__c,
                    Field_Label__c = change.mapping.Field_Label__c,
                    Field_Data_Type__c = String.valueOf(change.fieldDescribe.getType()),
                    Section_Name__c = change.mapping.Section_Name__c,
                    Sequence__c = change.mapping.Sequence__c,
                    Tracking_Field_API__c = change.mapping.Tracking_Field_API__c,
                    Old_Value__c = change.oldValue,
                    New_Value__c = change.newValue,
                    Old_Display_Value__c = change.oldDisplay,
                    New_Display_Value__c = change.newDisplay,
                    Value_Source__c = VALUE_SOURCE_USER,
                    BC_Push_Applicable__c = change.mapping.BC_Push_Supported__c == true,
                    BC_Payload_Key__c = change.mapping.BC_Payload_Key__c,
                    Item_Approval_Status__c = STATUS_PENDING
                ));
            }

            insert items;

            Tagged_Approval_Hierarchy__c approvalTransaction = new Tagged_Approval_Hierarchy__c(
                Approval_Hierarchy__c = routing.hierarchy.Id,
                Customer_Change_Request__c = request.Id,
                Approval_Status__c = STATUS_PENDING,
                Current_Approval_Level__c = routing.firstLevel.Id,
                Pending_With__c = routing.firstApprover.Approver_User__c,
                Returned_From_Level__c = null,
                Submitted_By__c = submitterId,
                Submitted_Date_Time__c = actionedAt,
                Last_Action__c = ACTION_SUBMITTED,
                Last_Action_By__c = submitterId,
                Last_Action_Date_Time__c = actionedAt,
                Last_Action_Comments__c = CHANGE_REASON
            );

            insert approvalTransaction;

            insert new Approval_Action_History__c(
                Approval_Transaction__c = approvalTransaction.Id,
                Approval_Level__c = routing.firstLevel.Id,
                Action__c = ACTION_SUBMITTED,
                Action_By__c = submitterId,
                Action_Date_Time__c = actionedAt,
                Assigned_To__c = routing.firstApprover.Approver_User__c,
                Comments__c = CHANGE_REASON,
                Previous_Status__c = STATUS_NOT_SUBMITTED,
                New_Status__c = STATUS_PENDING
            );

            Ctrl_Hlp_OrientCustApprovalSharing.syncApprovalAccess(approvalTransaction.Id);


            return request.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            // The customer gets a short message; the log keeps what actually broke.
            System.debug(LoggingLevel.ERROR,
                'Profile update submission failed: ' + e + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Failed to submit the profile update: ' + e.getMessage());
        }
    }

    /** Approval_Hierarchy__c.Type__c value that governs customer profile changes. */
    @TestVisible
    private static final String PROFILE_APPROVAL_TYPE = 'Customer Profile';

    /**
     * The profile screen speaks in its own short keys; approval speaks in
     * Account field API names. Everything else about a field - its label, its
     * BC payload key, whether it is editable at all - is read from
     * Orient_Customer_Field_Mapping__mdt, the same metadata the back-office
     * screen reads, so the two routes cannot drift apart.
     */
    private static final Map<String, String> ACCOUNT_FIELD_BY_SCREEN_KEY = new Map<String, String>{
        'Mobile' => 'Phone',
        'WhatsApp' => 'Whatsapp_number__c',
        'Email' => 'Email_Address__c',
        'DOB' => 'Date_Of_Birth__c',
        'DOA' => 'Anniversary_Date__c'
    };

    private static final String STATUS_PENDING = 'Pending';
    private static final String STATUS_NOT_SUBMITTED = 'Not Submitted';
    private static final String ACTION_SUBMITTED = 'Submitted';
    private static final String REQUEST_TYPE_PROFILE = 'Profile Update';
    private static final String REQUEST_STATUS_OPEN = 'Open';
    private static final String BC_STATUS_NOT_REQUIRED = 'Not Required';
    private static final String CHANGE_MODE_VERIFIED = 'Verified Lock';
    private static final String CHANGE_MODE_NEVER = 'Never Editable';
    private static final String VALUE_SOURCE_USER = 'User Entered';

    /** Stands in for the reason the back-office screen makes its user type. */
    private static final String CHANGE_REASON =
        'Requested by the customer on the showroom feedback screen and verified by one-time code.';

    /**
     * Routing problems are the store's to fix, not the customer's to understand,
     * so every one of them says the same thing to the person at the counter.
     */
    private static final String ROUTING_ERROR =
        'Profile update approvals are not set up correctly for this store yet. '
        + 'Please ask the store team to contact the administrator.';

    /** Told apart from a configuration problem: here there is no store to ask. */
    private static final String STORE_ERROR =
        'We could not work out which store should approve this update. '
        + 'Please ask the store team to raise it for you.';

    private class ProfileChange {
        Orient_Customer_Field_Mapping__mdt mapping;
        Schema.DescribeFieldResult fieldDescribe;
        String oldValue;
        String newValue;
        String oldDisplay;
        String newDisplay;
    }

    private class ApprovalRouting {
        Store__c store;
        Approval_Hierarchy__c hierarchy;
        Approval_Hierarchy_Level__c firstLevel;
        Approval_Approver_Mapping__c firstApprover;
    }

    /**
     * The hierarchy that a profile update has to travel up: hierarchies are held
     * one per store per type, so the store and the Customer Profile type together
     * pick exactly one record.
     *
     * @return the hierarchy, or null when that store has none configured
     */
    public static Approval_Hierarchy__c getProfileApprovalHierarchy(Id storeId) {
        if (storeId == null) {
            return null;
        }

        List<Approval_Hierarchy__c> hierarchies = [
            SELECT Id, Name, Type__c, Store__c, Store__r.Name
            FROM Approval_Hierarchy__c
            WHERE Type__c = :PROFILE_APPROVAL_TYPE
            AND Store__c = :storeId
            LIMIT 1
        ];

        return hierarchies.isEmpty() ? null : hierarchies[0];
    }

    /**
     * Which store's approvers own this change, in the order the answer is most
     * likely to be right.
     *
     * The visit comes first: a request raised at a counter belongs to that
     * counter. But the same screen runs without a visit - a customer looked up
     * by search has none - so it falls back to the store of the person raising
     * it, which is how the back-office screen has always decided, and finally to
     * the store the customer is registered against.
     *
     * @return the store, or null when none of the three can answer
     */
    private static Store__c resolveApprovalStore(Id showroomVisitId, Id accountId) {
        if (showroomVisitId != null) {
            List<Showroom_Visit__c> visits = [
                SELECT Id, StoreLookup__c, StoreLookup__r.Name, StoreLookup__r.Store_Code__c
                FROM Showroom_Visit__c
                WHERE Id = :showroomVisitId
                LIMIT 1
            ];

            if (!visits.isEmpty() && visits[0].StoreLookup__c != null) {
                return visits[0].StoreLookup__r;
            }
        }

        List<User> runningUsers = [
            SELECT Id, Location_Code__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (!runningUsers.isEmpty() && String.isNotBlank(runningUsers[0].Location_Code__c)) {
            String locationCode = runningUsers[0].Location_Code__c.trim();

            List<Store__c> stores = [
                SELECT Id, Name, Store_Code__c
                FROM Store__c
                WHERE Store_Code__c = :locationCode
                LIMIT 2
            ];

            // Two stores on one code is a configuration problem, not an answer:
            // fall through rather than guess which counter is meant.
            if (stores.size() == 1) {
                return stores[0];
            }
        }

        List<Account> customers = [
            SELECT Id, Preferred_Store__c, Preferred_Store__r.Name, Preferred_Store__r.Store_Code__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        if (!customers.isEmpty() && customers[0].Preferred_Store__c != null) {
            return customers[0].Preferred_Store__r;
        }

        return null;
    }

    /** [{fieldName, newValue}] as the screen sends it, keyed by Account field. */
    @TestVisible
    private static Map<String, String> parseProfilePayload(String payloadJson) {
        Map<String, String> values = new Map<String, String>();

        if (String.isBlank(payloadJson)) {
            return values;
        }

        Object parsed;

        try {
            parsed = JSON.deserializeUntyped(payloadJson);
        } catch (Exception e) {
            throw new AuraHandledException('The profile update could not be read.');
        }

        if (!(parsed instanceof List<Object>)) {
            throw new AuraHandledException('The profile update could not be read.');
        }

        for (Object entry : (List<Object>) parsed) {
            if (!(entry instanceof Map<String, Object>)) continue;

            Map<String, Object> row = (Map<String, Object>) entry;
            String screenKey = row.get('fieldName') == null ? null : String.valueOf(row.get('fieldName'));
            String newValue = row.get('newValue') == null ? null : String.valueOf(row.get('newValue')).trim();

            if (String.isBlank(screenKey) || String.isBlank(newValue)) continue;

            if (!ACCOUNT_FIELD_BY_SCREEN_KEY.containsKey(screenKey)) {
                throw new AuraHandledException('"' + screenKey + '" cannot be updated from this screen.');
            }

            values.put(ACCOUNT_FIELD_BY_SCREEN_KEY.get(screenKey), newValue);
        }

        return values;
    }

    /**
     * The metadata row behind each requested field. A field that is inactive,
     * not marked for approval, or Never Editable has no business reaching the
     * approval queue at all, so it is stopped here.
     */
    private static Map<String, Orient_Customer_Field_Mapping__mdt> getProfileFieldMappings(
        Set<String> accountFields) {

        Map<String, Orient_Customer_Field_Mapping__mdt> mappingByField =
            new Map<String, Orient_Customer_Field_Mapping__mdt>();

        for (Orient_Customer_Field_Mapping__mdt mapping : [
            SELECT DeveloperName, Account_Field_API__c, Field_Label__c, Tracking_Field_API__c,
                   Section_Name__c, Sequence__c, Change_Mode__c, Requires_Approval__c,
                   BC_Push_Supported__c, BC_Payload_Key__c, Verification_Field_API__c
            FROM Orient_Customer_Field_Mapping__mdt
            WHERE Active__c = true
            AND Account_Field_API__c IN :accountFields
        ]) {
            mappingByField.put(mapping.Account_Field_API__c, mapping);
        }

        for (String accountField : accountFields) {
            Orient_Customer_Field_Mapping__mdt mapping = mappingByField.get(accountField);

            if (mapping == null
                || mapping.Requires_Approval__c != true
                || mapping.Change_Mode__c == CHANGE_MODE_NEVER) {
                throw new AuraHandledException(
                    'One of the fields requested is not open for customer updates, so the request was not raised.');
            }
        }

        return mappingByField;
    }

    private static Account queryCustomerForApproval(
        Id accountId, List<Orient_Customer_Field_Mapping__mdt> mappings) {

        Map<String, Schema.SObjectField> accountFieldMap = Schema.SObjectType.Account.fields.getMap();
        Set<String> fields = new Set<String>{ 'Id', 'Name', 'BC_Customer_No__c' };

        for (Orient_Customer_Field_Mapping__mdt mapping : mappings) {
            fields.add(mapping.Account_Field_API__c);

            if (String.isNotBlank(mapping.Verification_Field_API__c)
                && accountFieldMap.containsKey(mapping.Verification_Field_API__c)) {
                fields.add(mapping.Verification_Field_API__c);
            }
        }

        List<Account> rows = Database.query(
            'SELECT ' + String.join(new List<String>(fields), ',')
            + ' FROM Account WHERE Id = :accountId LIMIT 1');

        if (rows.isEmpty()) {
            throw new AuraHandledException('The customer record could not be found.');
        }

        return rows[0];
    }

    private static Orient_Customer_Tracking__c getCustomerTracking(Id accountId) {
        List<Orient_Customer_Tracking__c> rows = [
            SELECT Id
            FROM Orient_Customer_Tracking__c
            WHERE Orient_Customer__c = :accountId
            LIMIT 1
        ];

        return rows.isEmpty() ? null : rows[0];
    }

    /**
     * One entry per field that is genuinely changing. A value that already
     * matches what we hold is dropped rather than sent to an approver to rubber
     * stamp, and if that leaves nothing at all the request is refused.
     */
    private static List<ProfileChange> buildProfileChanges(
        Account customer,
        Map<String, Orient_Customer_Field_Mapping__mdt> mappingByField,
        Map<String, String> requestedValues) {

        Map<String, Schema.SObjectField> accountFieldMap = Schema.SObjectType.Account.fields.getMap();
        List<ProfileChange> changes = new List<ProfileChange>();

        for (String accountField : requestedValues.keySet()) {
            Orient_Customer_Field_Mapping__mdt mapping = mappingByField.get(accountField);
            Schema.DescribeFieldResult fieldDescribe = accountFieldMap.get(accountField).getDescribe();

            /*
             * A Verified Lock field is frozen the moment the store verifies it -
             * that is what verification is for. The screen greys these out, so
             * this is the backstop for a stale tab rather than the first line of
             * defence.
             */
            if (mapping.Change_Mode__c == CHANGE_MODE_VERIFIED
                && String.isNotBlank(mapping.Verification_Field_API__c)
                && ((Boolean) customer.get(mapping.Verification_Field_API__c)) == true) {
                throw new AuraHandledException(
                    mapping.Field_Label__c + ' is already verified and can no longer be changed here. '
                    + 'Please ask the store team for help.');
            }

            String newValue = normaliseProfileValue(accountField, requestedValues.get(accountField), fieldDescribe);
            Object currentValue = customer.get(accountField);
            String oldValue = currentValue == null ? null : String.valueOf(currentValue);

            if (newValue.equals(oldValue)) continue;

            ProfileChange change = new ProfileChange();
            change.mapping = mapping;
            change.fieldDescribe = fieldDescribe;
            change.oldValue = oldValue;
            change.newValue = newValue;
            change.oldDisplay = formatProfileValue(oldValue, fieldDescribe);
            change.newDisplay = formatProfileValue(newValue, fieldDescribe);
            changes.add(change);
        }

        if (changes.isEmpty()) {
            throw new AuraHandledException(
                'The details entered already match what we hold, so there is nothing to approve.');
        }

        return changes;
    }

    /**
     * Validates a typed value and puts it in the shape the Account field stores,
     * so what an approver reads is what will be written on approval.
     */
    private static String normaliseProfileValue(
        String accountField, String rawValue, Schema.DescribeFieldResult fieldDescribe) {

        if (fieldDescribe.getType() == Schema.DisplayType.Date) {
            Date parsedDate;

            try {
                parsedDate = Date.valueOf(rawValue);
            } catch (Exception e) {
                parsedDate = null;
            }

            if (parsedDate == null) {
                throw new AuraHandledException('Please enter a valid date.');
            }

            if (parsedDate > Date.today()) {
                throw new AuraHandledException('That date cannot be in the future.');
            }

            return String.valueOf(parsedDate);
        }

        if (accountField == 'Email_Address__c') {
            String email = rawValue.trim();

            if (!isValidEmail(email)) {
                throw new AuraHandledException('Please enter a valid email address.');
            }

            return email;
        }

        if (accountField == 'Phone' || accountField == 'Whatsapp_number__c') {
            String mobile = normaliseMobile(rawValue);

            if (!isValidMobile(mobile)) {
                throw new AuraHandledException('Please enter a valid 10-digit mobile number.');
            }

            return mobile;
        }

        return rawValue.trim();
    }

    private static String formatProfileValue(String value, Schema.DescribeFieldResult fieldDescribe) {
        if (String.isBlank(value)) {
            return '';
        }

        if (fieldDescribe.getType() == Schema.DisplayType.Date) {
            try {
                return Date.valueOf(value).format();
            } catch (Exception e) {
                return value;
            }
        }

        return value;
    }

    // /**
    //  * A number already on another customer is a merge waiting to happen, so it
    //  * is refused before an approver ever sees it. Unlike the back-office screen
    //  * this does not name the other customer - the person reading it here is a
    //  * customer, not staff.
    //  */
    // private static void validateNoDuplicateContact(Id accountId, List<ProfileChange> changes) {
    //     for (ProfileChange change : changes) {
    //         String accountField = change.mapping.Account_Field_API__c;
    //
    //         if (accountField != 'Phone' && accountField != 'Whatsapp_number__c') continue;
    //
    //         String contactNumber = change.newValue;
    //
    //         List<Account> matches = [
    //             SELECT Id
    //             FROM Account
    //             WHERE Id != :accountId
    //             AND (Phone = :contactNumber OR Whatsapp_number__c = :contactNumber)
    //             LIMIT 1
    //         ];
    //
    //         if (!matches.isEmpty()) {
    //             throw new AuraHandledException(
    //                 'That number is already registered to another customer. '
    //                 + 'Please check it and try again, or ask the store team for help.');
    //         }
    //     }
    // }

    /**
     * One field, one open approval. Only a still-Pending item on a still-Pending
     * request blocks: once a field has been approved or returned, the customer is
     * free to ask again.
     */
    private static void validateNoPendingApproval(Id accountId, List<ProfileChange> changes) {
        Set<String> accountFields = new Set<String>();

        for (ProfileChange change : changes) {
            accountFields.add(change.mapping.Account_Field_API__c);
        }

        List<Orient_Customer_Change_Item__c> pendingItems = [
            SELECT Field_Label__c
            FROM Orient_Customer_Change_Item__c
            WHERE Account_Field_API__c IN :accountFields
            AND Change_Request__r.Orient_Customer__c = :accountId
            AND Item_Approval_Status__c = :STATUS_PENDING
            AND Change_Request__r.Approval_Status__c = :STATUS_PENDING
            LIMIT 1
        ];

        if (!pendingItems.isEmpty()) {
            throw new AuraHandledException(
                pendingItems[0].Field_Label__c + ' is already waiting for approval from an earlier request. '
                + 'Please wait for that one to be completed.');
        }
    }

    /**
     * Store, hierarchy, level, approver - the chain a request has to have before
     * it is worth writing.
     *
     * Every level is checked, not just the first: a hierarchy with a broken
     * level 3 is better refused at submission than discovered by a request that
     * gets stranded halfway up.
     */
    private static ApprovalRouting resolveProfileApprovalRouting(Id showroomVisitId, Id accountId) {
        ApprovalRouting routing = new ApprovalRouting();
        routing.store = resolveApprovalStore(showroomVisitId, accountId);

        if (routing.store == null) {
            throw new AuraHandledException(STORE_ERROR);
        }

        routing.hierarchy = getProfileApprovalHierarchy(routing.store.Id);

        if (routing.hierarchy == null) {
            throw new AuraHandledException(ROUTING_ERROR);
        }

        List<Approval_Hierarchy_Level__c> levels = [
            SELECT Id, Name, Responsible_Team__c, Sr_No__c
            FROM Approval_Hierarchy_Level__c
            WHERE Approval_Hierarchy__c = :routing.hierarchy.Id
            ORDER BY Sr_No__c ASC, CreatedDate ASC
        ];

        if (levels.isEmpty()) {
            throw new AuraHandledException(ROUTING_ERROR);
        }

        Set<Decimal> usedSequences = new Set<Decimal>();

        for (Approval_Hierarchy_Level__c level : levels) {
            if (level.Sr_No__c == null || usedSequences.contains(level.Sr_No__c)) {
                throw new AuraHandledException(ROUTING_ERROR);
            }

            usedSequences.add(level.Sr_No__c);
        }

        Map<Id, Approval_Approver_Mapping__c> approverByLevel =
            new Map<Id, Approval_Approver_Mapping__c>();

        Set<Id> levelIds = new Map<Id, Approval_Hierarchy_Level__c>(levels).keySet();
        Date today = Date.today();

        for (Approval_Approver_Mapping__c approver : [
            SELECT Id, Approval_Hierarchy_Level__c, Approver_User__c
            FROM Approval_Approver_Mapping__c
            WHERE Approval_Hierarchy_Level__c IN :levelIds
            AND Active__c = true
            AND Is_Primary__c = true
            AND Approver_User__c != null
            AND Approver_User__r.IsActive = true
            AND (Effective_From__c = null OR Effective_From__c <= :today)
            AND (Effective_To__c = null OR Effective_To__c >= :today)
        ]) {
            // Two active primary approvers on one level is as broken as none:
            // there is no way to say which of them the request is waiting on.
            if (approverByLevel.containsKey(approver.Approval_Hierarchy_Level__c)) {
                throw new AuraHandledException(ROUTING_ERROR);
            }

            approverByLevel.put(approver.Approval_Hierarchy_Level__c, approver);
        }

        for (Approval_Hierarchy_Level__c level : levels) {
            if (!approverByLevel.containsKey(level.Id)) {
                throw new AuraHandledException(ROUTING_ERROR);
            }
        }

        routing.firstLevel = levels[0];
        routing.firstApprover = approverByLevel.get(routing.firstLevel.Id);
        return routing;
    }

    /**
     * Template key for the invoice gate. Nothing is being changed here, so
     * there is no changed field to pick a template by - this stands in for one.
     * Add an SMS Template record with Profile_Field__c set to this value and it
     * is used automatically; until then the default template is.
     */
    @TestVisible
    private static final String INVOICE_TEMPLATE_KEY = 'InvoiceRequest';

    /**
     * Gate on the way into the invoice screen: texts a code to the number
     * already on the customer record.
     *
     * Deliberately the number on file, not a typed one. An invoice is a record
     * of what somebody bought, so the question here is "are you the customer we
     * hold this number for", which only the registered number can answer. That
     * is the opposite of the profile update flow, where the code goes to the new
     * number precisely because the point is to prove the new one.
     */
    @AuraEnabled
    public static FDB_OtpService.SendResult sendInvoiceOtp(Id accountId) {
        try {
            return FDB_OtpService.send(
                accountId, 'Invoice Email', new List<String>{ INVOICE_TEMPLATE_KEY }, null, null);
        } catch (FDB_OtpService.OtpException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (FDB_ShreeSmsGateway.ConfigurationException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to send verification code: ' + e.getMessage());
        }
    }

    /**
     * Template key for verifying the address an invoice is to be sent to. Add an
     * SMS Template record with Profile_Field__c set to this value and Channel__c
     * set to Email; until then the default template is used.
     */
    @TestVisible
    private static final String INVOICE_EMAIL_TEMPLATE_KEY = 'InvoiceEmail';

    /**
     * Second gate, inside the invoice screen: emails a code to the address the
     * customer has just typed.
     *
     * The gate on the way in proved they are the customer we hold this record
     * for. This one proves the address they want the invoice sent to is really
     * theirs - which the number on file cannot answer, since the whole point may
     * be to send it somewhere new.
     *
     * Its own Purpose__c, separate from the entry gate, so the resend cooldown
     * counts the two flows apart. They happen seconds from each other.
     */
    @AuraEnabled
    public static FDB_OtpService.SendResult sendInvoiceEmailOtp(Id accountId, String emailAddress) {
        try {
            String address = emailAddress == null ? '' : emailAddress.trim();

            if (!isValidEmail(address)) {
                throw new AuraHandledException(
                    'Please enter a valid email address before requesting a code.');
            }

            return FDB_OtpService.send(
                accountId, 'Invoice Email Verification',
                new List<String>{ INVOICE_EMAIL_TEMPLATE_KEY }, null, address);
        } catch (FDB_OtpService.OtpException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to send verification code: ' + e.getMessage());
        }
    }

    /** @return true only for a live, unconsumed code that matches */
    @AuraEnabled
    public static Boolean verifyInvoiceOtp(String otpReference, String otpCode) {
        try {
            return FDB_OtpService.verify(otpReference, otpCode);
        } catch (FDB_OtpService.OtpException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Failed to verify the code: ' + e.getMessage());
        }
    }

    /**
     * The customer's posted invoices, read live from Business Central for the
     * invoice screen to list.
     *
     * Gated on the same code that opened the screen. The screen itself is only
     * reachable after that code is verified, but a client-side screen change
     * guards nothing - without this check anyone who can reach the site could
     * read any customer's billing history by passing an account id.
     *
     * @param selectionType Latest, Specific or Last12, from the invoice screen
     * @param otpReference  the entry-gate verification, from sendInvoiceOtp
     * @param fromDate      yyyy-MM-dd, the range the customer set; Specific only
     * @param toDate        yyyy-MM-dd, as above
     */
    @AuraEnabled
    public static List<FDB_BCInvoiceService.Invoice> fetchCustomerInvoices(
        Id accountId, String selectionType, String otpReference,
        String fromDate, String toDate) {
        try {
            if (!FDB_OtpService.isVerified(otpReference)) {
                throw new AuraHandledException(
                    'Please verify your identity before viewing invoices.');
            }

            return FDB_BCInvoiceService.fetch(accountId, selectionType, fromDate, toDate);
        } catch (FDB_BCInvoiceService.InvoiceException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not load your invoices: ' + e.getMessage());
        }
    }

    /** Nothing is emailed from the kiosk - the case is the ask, and the team works it. */
    @TestVisible
    private static final String INVOICE_CASE_PRIORITY = 'Medium';

    /** Description is a 32k field; the payload is trimmed rather than the insert lost. */
    private static final Integer CASE_DESCRIPTION_LIMIT = 32000;

    /**
     * The customer's request for a copy of an invoice, raised as a Case for the
     * back office to work. Nothing is emailed from here - what this call does is
     * refuse to let the screen report success unless the address really was
     * verified, which is a question only the server can answer, and then write
     * the ask down where somebody will see it.
     *
     * @param otpReference the verification that proved the address, from
     *                     sendInvoiceEmailOtp
     * @param selectedInvoicesJson the estimates the customer ticked, as a JSON
     *                     array. It goes onto the case description as JSON, so
     *                     whoever sends the invoice has the bills in front of
     *                     them and not just a count.
     */
    @AuraEnabled
    public static String sendInvoiceEmailRequest(
        Id accountId, Id showroomVisitId, String emailAddress, String selectionType,
        String otpReference, String selectedInvoicesJson) {
        try {
            if (!FDB_OtpService.isVerified(otpReference)) {
                throw new AuraHandledException(
                    'Please verify the email address before raising the request.');
            }

            List<Object> selected = parseSelectedInvoices(selectedInvoicesJson);

            // The case hangs off the customer's Account. Without one it would
            // land in the queue attached to nobody, which is not a request
            // anybody can work.
            if (accountId == null) {
                throw new AuraHandledException(
                    'We could not tell which customer this request is for. Please ask our showroom team for help.');
            }

            Case c = new Case();
            c.AccountId = accountId;
            c.Priority = INVOICE_CASE_PRIORITY;
            c.Subject = 'Invoice Copy Request - ' + selectedCountLabel(selected.size())
                + ' to ' + emailAddress;
            c.Description = invoiceCaseDescription(
                showroomVisitId, emailAddress, selectionType, selected);

            // The invoice step runs off a showroom visit, so its feedback is the
            // record this belongs beside when there is one.
            Id feedbackId = feedbackIdForVisit(showroomVisitId);
            if (feedbackId != null) {
                c.Feedback__c = feedbackId;
            }

            insert c;

            return 'Success';
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error raising the invoice request: ' + e.getMessage());
        }
    }

    private static String selectedCountLabel(Integer count) {
        return count == 1 ? '1 invoice' : count + ' invoices';
    }

    /**
     * The whole ask as JSON, so the description can be read by a person and
     * parsed by whatever automation comes later without either being second
     * class. The selection alone would not say where to send it, so the address
     * and the choice travel with it.
     */
    private static String invoiceCaseDescription(
        Id showroomVisitId, String emailAddress, String selectionType, List<Object> selected) {

        Map<String, Object> payload = new Map<String, Object>{
            'requestType' => 'Invoice Copy Request',
            'requestedAt' => System.now().format('yyyy-MM-dd HH:mm:ss'),
            'sendToEmail' => emailAddress,
            'selectionType' => selectionType,
            'showroomVisitId' => showroomVisitId,
            'invoiceCount' => selected.size(),
            'invoices' => selected
        };

        String description = JSON.serializePretty(payload);
        if (description.length() > CASE_DESCRIPTION_LIMIT) {
            // Better a readable case that says it was cut than a failed insert.
            String notice = '\n\n[Truncated - the full selection was longer than this field allows.]';
            description = description.substring(0, CASE_DESCRIPTION_LIMIT - notice.length()) + notice;
        }
        return description;
    }

    /** Null when the visit has no feedback yet, which the caller treats as fine. */
    private static Id feedbackIdForVisit(Id showroomVisitId) {
        if (showroomVisitId == null) {
            return null;
        }
        List<Feedback__c> feedbacks = [
            SELECT Id FROM Feedback__c WHERE Showroom_Visit__c = :showroomVisitId LIMIT 1
        ];
        return feedbacks.isEmpty() ? null : feedbacks[0].Id;
    }

    /**
     * The ticked estimates, as sent by the screen. Read back here rather than
     * passed straight through so a payload that is not a JSON array is caught
     * before it reaches a case description.
     */
    private static List<Object> parseSelectedInvoices(String selectedInvoicesJson) {
        if (String.isBlank(selectedInvoicesJson)) {
            return new List<Object>();
        }
        try {
            return (List<Object>) JSON.deserializeUntyped(selectedInvoicesJson);
        } catch (Exception e) {
            throw new AuraHandledException(
                'We could not read which invoices were selected. Please pick them again.');
        }
    }

    // Marker the LWC matches on so it can route to the "already submitted" screen
    // instead of surfacing a raw error to the customer.
    public static final String ALREADY_SUBMITTED = 'FEEDBACK_ALREADY_SUBMITTED';

    @AuraEnabled
    public static String updateFeedbackToInProgress(Id showroomVisitId) {
        // Without this, a null id is not an error - it matches any feedback
        // that has no visit attached, and answers about that record instead.
        // A caller that has not resolved its visit yet was told the feedback
        // was already submitted, about a record it had never asked for.
        if (showroomVisitId == null) {
            throw new AuraHandledException('No showroom visit was supplied, so its feedback could not be opened.');
        }

        Feedback__c fb;
        try {
            fb = [SELECT Id, Status__c FROM Feedback__c WHERE Showroom_Visit__c = :showroomVisitId LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException('Error reading feedback for this visit: ' + e.getMessage());
        }

        // One feedback per showroom visit. A completed record is never reopened.
        if (fb.Status__c == 'Completed') {
            throw new AuraHandledException(ALREADY_SUBMITTED);
        }

        try {
            fb.Status__c = 'In Progress';
            update fb;
            return fb.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating feedback to In Progress: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String submitCustomerFeedback(Id feedbackId, Id accountId, Map<String, String> answers, String comments, String language) {
        // Re-read and lock the row so two devices cannot both submit for one visit
        Feedback__c fb;
        try {
            fb = [SELECT Id, Status__c, Overall_Rating__c, Staff_Rating__c, Clarity_Rating__c, Purpose_Fulfilled__c, Visit_Or_Recommend_Again__c, Comments__c
                  FROM Feedback__c WHERE Id = :feedbackId LIMIT 1 FOR UPDATE];
        } catch (Exception e) {
            throw new AuraHandledException('Error reading feedback record: ' + e.getMessage());
        }

        if (fb.Status__c == 'Completed') {
            throw new AuraHandledException(ALREADY_SUBMITTED);
        }

        try {
            fb.Status__c = 'Completed';
            fb.Submitted_Date_Time__c = System.now();
            fb.Submitted_Channel__c = 'Store Device';
            if (language == 'BN') {
                fb.Language__c = 'Bengali';
            } else {
                fb.Language__c = 'English';
            }
            fb.Overall_Rating__c = answers.get('q1');
            fb.Staff_Rating__c = answers.get('q2');
            fb.Clarity_Rating__c = answers.get('q3');
            fb.Purpose_Fulfilled__c = answers.get('q4');
            fb.Visit_Or_Recommend_Again__c = answers.get('q5');
            fb.Comments__c = comments;

            //update fb;

            fb.Average_Score__c = weightedScore(fb);
            update fb;

            CaseAssessment assessment = assessFeedback(fb, comments);

            if (assessment.priority != null) {
                Case c = new Case();
                c.AccountId = accountId;
                c.Priority = assessment.priority;
                c.Feedback__c = fb.Id;
                c.Subject = 'Customer Feedback Escalation - ' + assessment.reasons[0];
                // The score is not what raises a case and does not belong in the
                // reasons - the stars and the comment are what a case is worked
                // from, and a number beside them only invites arguing with it.
                c.Description =
                    'Feedback generated a case.\n\nWhy:\n- '
                    + String.join(assessment.reasons, '\n- ')
                    + '\n\nComments: ' + (String.isBlank(comments) ? '(none)' : comments);
                insert c;

                fb.Case_Created__c = true;
                update fb;
            }

            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error submitting feedback: ' + e.getMessage());
        }
    }

    // ------------------------------------------------------------ SCORING

    /**
     * Which answer each question's Sequence__c is stored in. The five rated
     * questions live in their own fields on Feedback__c rather than in rows, so
     * the weightings on Feedback_Question__c are joined back to them by
     * sequence. A question with no entry here (the comments question, which
     * carries no weighting) takes no part in the score.
     */
    private static Map<Decimal, String> ratedAnswers(Feedback__c fb) {
        return new Map<Decimal, String>{
            1 => fb.Overall_Rating__c,
            2 => fb.Staff_Rating__c,
            3 => fb.Clarity_Rating__c,
            4 => fb.Purpose_Fulfilled__c,
            5 => fb.Visit_Or_Recommend_Again__c
        };
    }

    /**
     * The visit's score: each answer multiplied by its question's weighting, all
     * of them added up. Three stars on a question weighted 40% is 1.2, and a
     * full set of fives comes to 5.00 because the weightings total 100%.
     *
     * A question answered N.A. is not a rating, so it cannot be scored. Its
     * weighting is handed to the first question instead of being dropped, which
     * keeps the total weighting at 100% and the score on the same 1-5 scale for
     * every customer. Nothing on Feedback_Question__c is touched - the shift
     * happens here, for this one calculation.
     */
    @TestVisible
    private static Decimal weightedScore(Feedback__c fb) {
        Map<Decimal, String> answers = ratedAnswers(fb);

        List<Integer> stars = new List<Integer>();
        List<Decimal> weights = new List<Decimal>();

        // Weighting belonging to questions that came back N.A. or unanswered
        Decimal carried = 0;

        for (Feedback_Question__c question : [
            SELECT Sequence__c, Weightage__c
            FROM Feedback_Question__c
            WHERE Weightage__c != NULL
            ORDER BY Sequence__c ASC
        ]) {
            if (!answers.containsKey(question.Sequence__c)) {
                continue;
            }

            Integer answerStars = starsOf(answers.get(question.Sequence__c));
            if (answerStars == null) {
                carried += question.Weightage__c;
                continue;
            }

            stars.add(answerStars);
            weights.add(question.Weightage__c);
        }

        if (stars.isEmpty()) {
            return 0;
        }

        // The first question, or the first one that was actually rated when the
        // first itself came back N.A. - carried weighting has to land somewhere
        // that can be scored.
        weights[0] += carried;

        Decimal score = 0;
        for (Integer i = 0; i < stars.size(); i++) {
            score += weights[i] * stars[i];
        }

        // Weightage__c is a percent field: 40 means 40%.
        return (score / 100).setScale(2, System.RoundingMode.HALF_UP);
    }

    /** What the rules decided: the priority to raise at, and what triggered it. */
    @TestVisible
    private class CaseAssessment {
        String priority;
        List<String> reasons = new List<String>();
    }

    private static final Map<String, Integer> PRIORITY_RANK = new Map<String, Integer>{
        'Medium' => 1, 'High' => 2, 'Critical' => 3
    };

    /** The five mandatory questions, in the order they are asked. */
    private static final List<String> QUESTION_LABELS = new List<String>{
        'Overall experience',
        'Staff',
        'Clarity of information',
        'Purpose of visit fulfilled',
        'Would visit or recommend again'
    };

    /**
     * Decides whether this feedback earns a case, at what priority, and why.
     *
     * The rules, in the customer's words:
     *   - any mandatory question at 1 star            -> Critical
     *   - any mandatory question at 2 stars           -> High
     *   - Q4 (purpose) at 1-2 stars                   -> case, unfulfilled visit purpose
     *   - Q5 (return/recommend) at 1-2 stars          -> case, retention concern
     *   - any question at 3 stars with a negative
     *     comment                                     -> Medium, for Customer Care
     *   - any rating at all with a seriously negative
     *     comment                                     -> case off the back of the comment
     *   - everything 4-5 stars and no negative comment -> no case
     *
     * More than one rule can fire; the case is raised at the highest priority
     * any of them asked for, and every reason is listed on it. The N.A. answer
     * on the clarity question is not a rating, so it triggers nothing.
     */
    @TestVisible
    private static CaseAssessment assessFeedback(Feedback__c fb, String comments) {
        CaseAssessment result = new CaseAssessment();

        Boolean negativeComment = isNegativeComment(comments);
        Boolean seriousComment = isSeriouslyNegativeComment(comments);

        List<String> ratings = new List<String>{
            fb.Overall_Rating__c,
            fb.Staff_Rating__c,
            fb.Clarity_Rating__c,
            fb.Purpose_Fulfilled__c,
            fb.Visit_Or_Recommend_Again__c
        };

        for (Integer i = 0; i < ratings.size(); i++) {
            Integer stars = starsOf(ratings[i]);
            if (stars == null) continue;

            if (stars == 1) {
                raise(result, 'Critical', '1 star on "' + QUESTION_LABELS[i] + '"');
            } else if (stars == 2) {
                raise(result, 'High', '2 stars on "' + QUESTION_LABELS[i] + '"');
            } else if (stars == 3 && negativeComment) {
                raise(result, 'Medium',
                      '3 stars on "' + QUESTION_LABELS[i] + '" with a negative comment');
            }
        }

        // Named separately from the generic 1-2 star rules above so the case says
        // what went wrong, not just how low the number was.
        if (isLowScore(fb.Purpose_Fulfilled__c)) {
            raise(result, 'High', 'Visit purpose not fulfilled');
        }
        if (isLowScore(fb.Visit_Or_Recommend_Again__c)) {
            raise(result, 'High', 'Customer retention concern - unlikely to return or recommend');
        }

        // A serious complaint stands on its own, however the stars fell.
        if (seriousComment) {
            raise(result, 'High', 'Serious negative comment left by the customer');
        }

        return result;
    }

    /** Keeps the highest priority asked for and records every reason. */
    private static void raise(CaseAssessment result, String priority, String reason) {
        result.reasons.add(reason);
        if (result.priority == null
                || PRIORITY_RANK.get(priority) > PRIORITY_RANK.get(result.priority)) {
            result.priority = priority;
        }
    }

    /** The star count behind an answer, or null when it is not a rating (N.A.). */
    @TestVisible
    private static Integer starsOf(String answer) {
        if (String.isBlank(answer) || !answer.isNumeric()) return null;
        return Integer.valueOf(answer);
    }

    /** True for an answered 1-5 question sitting at 1 or 2 stars. */
    @TestVisible
    private static Boolean isLowScore(String answer) {
        Integer stars = starsOf(answer);
        return stars != null && stars <= 2;
    }

    /**
     * Comment screening is a keyword match, deliberately kept simple and
     * readable: it costs nothing at submit time and an admin can see exactly
     * why a case was raised. It is a net, not a judge - it will miss a complaint
     * phrased politely, and it only reads Latin script, so a comment typed in
     * Bengali will not match. Cases raised by the star rules are unaffected.
     */
    private static final List<String> SERIOUS_NEGATIVE_TERMS = new List<String>{
        'rude', 'misbehav', 'insult', 'humiliat', 'harass', 'abus', 'cheat', 'fraud',
        'scam', 'worst', 'pathetic', 'disgust', 'arrogant', 'shouted', 'shouting',
        'never come back', 'never again', 'never visit', 'ignored me', 'racist',
        'discriminat', 'threat', 'fake'
    };

    private static final List<String> NEGATIVE_TERMS = new List<String>{
        'bad', 'poor', 'not good', 'not happy', 'unhappy', 'disappoint', 'dissatisf',
        'not satisfied', 'slow', 'delay', 'too long', 'waited', 'waiting', 'dirty',
        'careless', 'unprofessional', 'overpriced', 'too expensive', 'complain',
        'problem', 'issue', 'no response', 'terrible', 'horrible', 'useless',
        'mislead', 'misguide', 'wrong', 'never'
    };

    /** Serious terms count as negative too - the tiers stack. */
    @TestVisible
    private static Boolean isNegativeComment(String comments) {
        return containsAny(comments, NEGATIVE_TERMS) || isSeriouslyNegativeComment(comments);
    }

    @TestVisible
    private static Boolean isSeriouslyNegativeComment(String comments) {
        return containsAny(comments, SERIOUS_NEGATIVE_TERMS);
    }

    private static Boolean containsAny(String text, List<String> terms) {
        if (String.isBlank(text)) return false;
        String haystack = text.toLowerCase();
        for (String term : terms) {
            if (haystack.contains(term)) return true;
        }
        return false;
    }
}