public without sharing class Ctrl_Hlp_BTLEmailNotificationService {

    private static final String EVENT_APPROVAL_REQUIRED =
        'APPROVAL_REQUIRED';
    private static final String EVENT_RETURNED =
        'RETURNED';
    private static final String EVENT_COMPLETED =
        'COMPLETED';

    private static final String TEMPLATE_APPROVAL_REQUIRED =
        'BTL_Approval_Required';
    private static final String TEMPLATE_RETURNED =
        'BTL_Approval_Returned';
    private static final String TEMPLATE_COMPLETED =
        'BTL_Approval_Process_Completed';

    private static final String IST_TIMEZONE =
        'Asia/Kolkata';

    private class MailGroup {
        String eventType;
        Id recipientUserId;
        String recipientName;
        String recipientEmail;
        List<Tagged_Approval_Hierarchy__c> transactions =
            new List<Tagged_Approval_Hierarchy__c>();
    }

    private class EmailLogContext {
        Id formActivityId;
        Id recipientUserId;
        String toAddress;
        String ccAddress;
        String fromAddress;
        String subject;
        String htmlBody;
        String textBody;
    }

    public static void sendApprovalRequired(
        Set<Id> taggedApprovalIds
    ) {
        dispatch(
            EVENT_APPROVAL_REQUIRED,
            taggedApprovalIds
        );
    }

    public static void sendReturned(
        Set<Id> taggedApprovalIds
    ) {
        dispatch(
            EVENT_RETURNED,
            taggedApprovalIds
        );
    }

    public static void sendProcessCompleted(
        Set<Id> taggedApprovalIds
    ) {
        dispatch(
            EVENT_COMPLETED,
            taggedApprovalIds
        );
    }

    private static void dispatch(
        String eventType,
        Set<Id> taggedApprovalIds
    ) {
        if (
            taggedApprovalIds == null ||
            taggedApprovalIds.isEmpty()
        ) {
            return;
        }

        try {
            List<Tagged_Approval_Hierarchy__c> transactions = [
                SELECT
                    Id,
                    Name,
                    Approval_Status__c,
                    Current_Approval_Level__c,
                    Current_Approval_Level__r.Name,
                    Current_Approval_Level__r.Responsible_Team__c,
                    Current_Approval_Level__r.Sr_No__c,
                    Pending_With__c,
                    Pending_With__r.Name,
                    Pending_With__r.Email,
                    Pending_With__r.IsActive,
                    Returned_From_Level__c,
                    Returned_From_Level__r.Name,
                    Returned_From_Level__r.Responsible_Team__c,
                    Returned_From_Level__r.Sr_No__c,
                    Submission_Cycle__c,
                    Submitted_By__c,
                    Submitted_By__r.Name,
                    Submitted_By__r.Email,
                    Submitted_By__r.IsActive,
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
                    Form_Activity_Assigned_Persons__r.Sales_Executives__c,
                    Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                    Form_Activity_Assigned_Persons_Date__c,
                    Form_Activity_Assigned_Persons_Date__r.Name,
                    Form_Activity_Assigned_Persons_Date__r.Store__c,
                    Form_Activity_Assigned_Persons_Date__r.Store__r.Name,
                    Form_Activity_Assigned_Persons_Date__r.Target_Date__c,
                    Form_Activity_Assigned_Persons_Date__r.Activity_Location__c
                FROM Tagged_Approval_Hierarchy__c
                WHERE Id IN :taggedApprovalIds
                ORDER BY
                    Form_Activity__r.Name,
                    Form_Activity_Assigned_Persons_Date__r.Store__r.Name,
                    Form_Activity_Assigned_Persons_Date__r.Target_Date__c,
                    Form_Activity_Assigned_Persons__r.Team_Name__c,
                    Form_Activity_Assigned_Persons__r.Sales_Executives__r.Name,
                    Name
            ];

            Map<String, MailGroup> groups =
                buildGroups(
                    eventType,
                    transactions
                );

            if (groups.isEmpty()) {
                return;
            }

            Map<String, Id> templateIdByEvent =
                loadTemplateIds();

            List<String> testCcAddresses =
                getSandboxTestCcAddresses();

            Id orgWideEmailAddressId =
                getConfiguredOrgWideEmailAddressId();

            String senderEmailAddress =
                getSenderEmailAddress(
                    orgWideEmailAddressId
                );

            List<Messaging.SingleEmailMessage> messages =
                new List<Messaging.SingleEmailMessage>();

            List<EmailLogContext> emailLogContexts =
                new List<EmailLogContext>();

            for (MailGroup groupRecord : groups.values()) {
                if (
                    groupRecord.recipientUserId == null ||
                    String.isBlank(groupRecord.recipientEmail) ||
                    groupRecord.transactions.isEmpty()
                ) {
                    continue;
                }

                Tagged_Approval_Hierarchy__c anchor =
                    groupRecord.transactions[0];

                Messaging.SingleEmailMessage message =
                    new Messaging.SingleEmailMessage();

                message.setTargetObjectId(
                    groupRecord.recipientUserId
                );
                message.setTreatTargetObjectAsRecipient(true);

                /*
                 * The recipient is a Salesforce User. Salesforce requires
                 * saveAsActivity = false for this send path.
                 *
                 * After Messaging.sendEmail succeeds, we manually create one
                 * EmailMessage related to Form_Activity__c for audit/history.
                 */
                message.setSaveAsActivity(false);

                if (orgWideEmailAddressId != null) {
                    message.setOrgWideEmailAddressId(
                        orgWideEmailAddressId
                    );
                }

                List<String> messageCcAddresses =
                    removePrimaryRecipientFromCc(
                        testCcAddresses,
                        groupRecord.recipientEmail
                    );

                if (!messageCcAddresses.isEmpty()) {
                    message.setCcAddresses(
                        messageCcAddresses
                    );
                }

                Id templateId =
                    templateIdByEvent.get(eventType);

                Boolean templateApplied = false;

                if (templateId != null) {
                    templateApplied =
                        applyRenderedTemplate(
                            message,
                            templateId,
                            groupRecord.recipientUserId,
                            anchor.Id
                        );
                }

                if (!templateApplied) {
                    /*
                     * Safe fallback:
                     * If a template is missing or cannot be rendered,
                     * preserve the grouped BTL mail using the existing
                     * programmatic HTML/text body.
                     */
                    message.setSubject(
                        buildSubject(
                            eventType,
                            anchor
                        )
                    );
                    message.setHtmlBody(
                        buildHtmlBody(
                            groupRecord
                        )
                    );
                    message.setPlainTextBody(
                        buildPlainTextBody(
                            groupRecord
                        )
                    );
                }

                EmailLogContext logContext =
                    new EmailLogContext();

                logContext.formActivityId =
                    anchor.Form_Activity__c;
                logContext.recipientUserId =
                    groupRecord.recipientUserId;
                logContext.toAddress =
                    groupRecord.recipientEmail;
                logContext.ccAddress =
                    messageCcAddresses.isEmpty()
                        ? null
                        : String.join(
                            messageCcAddresses,
                            ';'
                        );
                logContext.fromAddress =
                    senderEmailAddress;
                logContext.subject =
                    message.getSubject();
                logContext.htmlBody =
                    message.getHtmlBody();
                logContext.textBody =
                    message.getPlainTextBody();

                messages.add(message);
                emailLogContexts.add(logContext);
            }

            if (messages.isEmpty()) {
                return;
            }

            Messaging.SendEmailResult[] results =
                Messaging.sendEmail(
                    messages,
                    false
                );

            List<EmailMessage> emailMessagesToInsert =
                new List<EmailMessage>();

            Datetime emailLoggedDateTime =
                System.now();

            String sentEmailStatus =
                getSentEmailStatusValue();

            for (
                Integer resultIndex = 0;
                resultIndex < results.size();
                resultIndex++
            ) {
                if (!results[resultIndex].isSuccess()) {
                    String errorMessage =
                        'BTL approval email could not be sent.';

                    Messaging.SendEmailError[] errors =
                        results[resultIndex].getErrors();

                    if (
                        errors != null &&
                        !errors.isEmpty()
                    ) {
                        errorMessage += ' ' +
                            errors[0].getMessage();
                    }

                    System.debug(
                        LoggingLevel.ERROR,
                        errorMessage
                    );
                    continue;
                }

                if (
                    resultIndex >= emailLogContexts.size()
                ) {
                    System.debug(
                        LoggingLevel.ERROR,
                        'BTL approval email was sent but no matching EmailMessage log context was found for result index ' +
                        String.valueOf(resultIndex) +
                        '.'
                    );
                    continue;
                }

                EmailLogContext logContext =
                    emailLogContexts[resultIndex];

                if (logContext.formActivityId == null) {
                    System.debug(
                        LoggingLevel.ERROR,
                        'BTL approval email was sent successfully but EmailMessage logging was skipped because Form_Activity__c is missing.'
                    );
                    continue;
                }

                EmailMessage emailMessageRecord =
                    new EmailMessage();

                emailMessageRecord.RelatedToId =
                    logContext.formActivityId;
                emailMessageRecord.Subject =
                    logContext.subject;
                emailMessageRecord.HtmlBody =
                    logContext.htmlBody;
                emailMessageRecord.TextBody =
                    logContext.textBody;
                emailMessageRecord.FromAddress =
                    logContext.fromAddress;
                emailMessageRecord.ToAddress =
                    logContext.toAddress;
                emailMessageRecord.CcAddress =
                    logContext.ccAddress;
                emailMessageRecord.Incoming =
                    false;
                emailMessageRecord.MessageDate =
                    emailLoggedDateTime;
                emailMessageRecord.Status =
                    sentEmailStatus;

                emailMessagesToInsert.add(
                    emailMessageRecord
                );
            }

            insertEmailMessageLogs(
                emailMessagesToInsert
            );
        } catch (Exception exceptionRecord) {
            /*
             * Email failure must never roll back a valid BTL approval action.
             * The approval data remains the source of truth and the failure is
             * available in debug logs for operational follow-up.
             */
            System.debug(
                LoggingLevel.ERROR,
                'BTL approval email dispatch failed: ' +
                exceptionRecord.getMessage()
            );
        }
    }

    private static void insertEmailMessageLogs(
        List<EmailMessage> emailMessages
    ) {
        if (
            emailMessages == null ||
            emailMessages.isEmpty()
        ) {
            return;
        }

        Database.SaveResult[] saveResults =
            Database.insert(
                emailMessages,
                false
            );

        for (
            Integer resultIndex = 0;
            resultIndex < saveResults.size();
            resultIndex++
        ) {
            if (saveResults[resultIndex].isSuccess()) {
                continue;
            }

            String errorMessage =
                'BTL approval email was sent, but EmailMessage logging failed.';

            Database.Error[] errors =
                saveResults[resultIndex].getErrors();

            if (
                errors != null &&
                !errors.isEmpty()
            ) {
                errorMessage += ' ' +
                    errors[0].getMessage();
            }

            System.debug(
                LoggingLevel.ERROR,
                errorMessage
            );
        }
    }

    private static String getSentEmailStatusValue() {
        for (
            Schema.PicklistEntry entry :
            EmailMessage.Status
                .getDescribe()
                .getPicklistValues()
        ) {
            if (
                entry.isActive() &&
                entry.getLabel()
                    .equalsIgnoreCase('Sent')
            ) {
                return entry.getValue();
            }
        }

        /*
         * Standard EmailMessage API value for Sent.
         * Kept only as a defensive fallback.
         */
        return '3';
    }

    private static String getSenderEmailAddress(
        Id orgWideEmailAddressId
    ) {
        if (orgWideEmailAddressId != null) {
            List<OrgWideEmailAddress> senderRecords = [
                SELECT Id, Address
                FROM OrgWideEmailAddress
                WHERE Id = :orgWideEmailAddressId
                LIMIT 1
            ];

            if (!senderRecords.isEmpty()) {
                return senderRecords[0].Address;
            }
        }

        User currentUser = [
            SELECT Id, Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        return currentUser.Email;
    }

    private static Boolean applyRenderedTemplate(
        Messaging.SingleEmailMessage outboundMessage,
        Id templateId,
        Id recipientUserId,
        Id taggedApprovalId
    ) {
        if (
            outboundMessage == null ||
            templateId == null ||
            recipientUserId == null ||
            taggedApprovalId == null
        ) {
            return false;
        }

        try {
            /*
             * Render the VF Email Template with:
             *
             * whoId  = recipient User
             * whatId = Tagged_Approval_Hierarchy__c
             *
             * This keeps all existing {!relatedTo...} merge fields and the
             * BTLApprovalEmailContent component working exactly as before.
             *
             * The rendered content is then copied to the real outbound
             * message whose WhatId is Form_Activity__c for EmailMessage
             * logging.
             */
            Messaging.SingleEmailMessage renderedMessage =
                Messaging.renderStoredEmailTemplate(
                    templateId,
                    recipientUserId,
                    taggedApprovalId
                );

            if (renderedMessage == null) {
                return false;
            }

            if (String.isNotBlank(renderedMessage.getSubject())) {
                outboundMessage.setSubject(
                    renderedMessage.getSubject()
                );
            }

            if (String.isNotBlank(renderedMessage.getHtmlBody())) {
                outboundMessage.setHtmlBody(
                    renderedMessage.getHtmlBody()
                );
            }

            if (String.isNotBlank(renderedMessage.getPlainTextBody())) {
                outboundMessage.setPlainTextBody(
                    renderedMessage.getPlainTextBody()
                );
            }

            return
                String.isNotBlank(renderedMessage.getSubject()) ||
                String.isNotBlank(renderedMessage.getHtmlBody()) ||
                String.isNotBlank(renderedMessage.getPlainTextBody());
        } catch (Exception renderException) {
            System.debug(
                LoggingLevel.ERROR,
                'BTL approval email template rendering failed. ' +
                'Template Id: ' +
                String.valueOf(templateId) +
                ', Tagged Approval Id: ' +
                String.valueOf(taggedApprovalId) +
                ', Error: ' +
                renderException.getMessage()
            );

            return false;
        }
    }

    private static Id getConfiguredOrgWideEmailAddressId() {
        String configuredAddress =
            System.Label.BTL_Approval_OrgWide_Email;

        if (
            String.isBlank(configuredAddress) ||
            configuredAddress.trim().equalsIgnoreCase('NONE')
        ) {
            return null;
        }

        configuredAddress =
            configuredAddress.trim();

        if (!isValidEmailAddress(configuredAddress)) {
            throw new MailConfigurationException(
                'BTL Approval Org-Wide Email Custom Label contains an invalid email address: ' +
                configuredAddress
            );
        }

        List<OrgWideEmailAddress> matchingAddresses = [
            SELECT
                Id,
                Address,
                DisplayName
            FROM OrgWideEmailAddress
            WHERE Address = :configuredAddress
            LIMIT 2
        ];

        if (matchingAddresses.isEmpty()) {
            throw new MailConfigurationException(
                'No Org-Wide Email Address is configured in Salesforce for "' +
                configuredAddress +
                '". Configure and verify the Org-Wide Email Address, or set Custom Label BTL_Approval_OrgWide_Email to NONE.'
            );
        }

        if (matchingAddresses.size() > 1) {
            throw new MailConfigurationException(
                'Multiple Org-Wide Email Address records were found for "' +
                configuredAddress +
                '". Keep only one matching sender configuration.'
            );
        }

        return matchingAddresses[0].Id;
    }

    private static List<String> getSandboxTestCcAddresses() {
        List<String> result = new List<String>();

        Organization orgRecord = [
            SELECT IsSandbox
            FROM Organization
            LIMIT 1
        ];

        if (orgRecord.IsSandbox != true) {
            return result;
        }

        String configuredValue =
            System.Label.BTL_Approval_Test_CC;

        if (
            String.isBlank(configuredValue) ||
            configuredValue.trim().equalsIgnoreCase('NONE')
        ) {
            return result;
        }

        Set<String> normalizedAddresses = new Set<String>();

        for (String rawAddress : configuredValue.split('[,;]')) {
            String emailAddress =
                String.isBlank(rawAddress)
                    ? null
                    : rawAddress.trim();

            if (String.isBlank(emailAddress)) {
                continue;
            }

            if (!isValidEmailAddress(emailAddress)) {
                continue;
            }

            String normalized =
                emailAddress.toLowerCase();

            if (!normalizedAddresses.contains(normalized)) {
                normalizedAddresses.add(normalized);
                result.add(emailAddress);
            }
        }

        return result;
    }

    private static List<String> removePrimaryRecipientFromCc(
        List<String> configuredCcAddresses,
        String primaryRecipientEmail
    ) {
        List<String> result = new List<String>();

        if (
            configuredCcAddresses == null ||
            configuredCcAddresses.isEmpty()
        ) {
            return result;
        }

        String normalizedPrimary =
            String.isBlank(primaryRecipientEmail)
                ? null
                : primaryRecipientEmail.trim().toLowerCase();

        for (String ccAddress : configuredCcAddresses) {
            if (
                String.isNotBlank(normalizedPrimary) &&
                ccAddress.trim().toLowerCase() ==
                    normalizedPrimary
            ) {
                continue;
            }

            result.add(ccAddress);
        }

        return result;
    }

    private static Boolean isValidEmailAddress(
        String emailAddress
    ) {
        if (String.isBlank(emailAddress)) {
            return false;
        }

        return Pattern.matches(
            '^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$',
            emailAddress.trim()
        );
    }

    private static Map<String, Id> loadTemplateIds() {
        Map<String, Id> result = new Map<String, Id>();

        Map<String, String> eventByDeveloperName =
            new Map<String, String>{
                TEMPLATE_APPROVAL_REQUIRED => EVENT_APPROVAL_REQUIRED,
                TEMPLATE_RETURNED => EVENT_RETURNED,
                TEMPLATE_COMPLETED => EVENT_COMPLETED
            };

        for (EmailTemplate templateRecord : [
            SELECT Id, DeveloperName
            FROM EmailTemplate
            WHERE DeveloperName IN :eventByDeveloperName.keySet()
            AND IsActive = true
        ]) {
            result.put(
                eventByDeveloperName.get(templateRecord.DeveloperName),
                templateRecord.Id
            );
        }

        return result;
    }

    private static Map<String, MailGroup> buildGroups(
        String eventType,
        List<Tagged_Approval_Hierarchy__c> transactions
    ) {
        Map<String, MailGroup> groups =
            new Map<String, MailGroup>();

        for (
            Tagged_Approval_Hierarchy__c transactionRecord :
            transactions
        ) {
            Id recipientUserId;
            String recipientName;
            String recipientEmail;
            Boolean recipientActive = false;

            if (eventType == EVENT_APPROVAL_REQUIRED) {
                if (
                    transactionRecord.Approval_Status__c !=
                        Ctrl_Hlp_BTLApprovalConstants.STATUS_PENDING ||
                    transactionRecord.Pending_With__c == null ||
                    transactionRecord.Pending_With__r == null
                ) {
                    continue;
                }

                recipientUserId =
                    transactionRecord.Pending_With__c;
                recipientName =
                    transactionRecord.Pending_With__r.Name;
                recipientEmail =
                    transactionRecord.Pending_With__r.Email;
                recipientActive =
                    transactionRecord.Pending_With__r.IsActive == true;
            } else if (eventType == EVENT_RETURNED) {
                if (
                    transactionRecord.Approval_Status__c !=
                        Ctrl_Hlp_BTLApprovalConstants.STATUS_RETURNED ||
                    transactionRecord.Submitted_By__c == null ||
                    transactionRecord.Submitted_By__r == null
                ) {
                    continue;
                }

                recipientUserId =
                    transactionRecord.Submitted_By__c;
                recipientName =
                    transactionRecord.Submitted_By__r.Name;
                recipientEmail =
                    transactionRecord.Submitted_By__r.Email;
                recipientActive =
                    transactionRecord.Submitted_By__r.IsActive == true;
            } else if (eventType == EVENT_COMPLETED) {
                Boolean completedStatus =
                    transactionRecord.Approval_Status__c ==
                        Ctrl_Hlp_BTLApprovalConstants.STATUS_APPROVED ||
                    transactionRecord.Approval_Status__c ==
                        Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED;

                if (
                    !completedStatus ||
                    transactionRecord.Submitted_By__c == null ||
                    transactionRecord.Submitted_By__r == null
                ) {
                    continue;
                }

                recipientUserId =
                    transactionRecord.Submitted_By__c;
                recipientName =
                    transactionRecord.Submitted_By__r.Name;
                recipientEmail =
                    transactionRecord.Submitted_By__r.Email;
                recipientActive =
                    transactionRecord.Submitted_By__r.IsActive == true;
            } else {
                continue;
            }

            if (
                !recipientActive ||
                String.isBlank(recipientEmail)
            ) {
                System.debug(
                    LoggingLevel.WARN,
                    'BTL approval email skipped because recipient is inactive or has no email. User: ' +
                    String.valueOf(recipientUserId)
                );
                continue;
            }

            String groupKey = buildGroupKey(
                eventType,
                recipientUserId,
                transactionRecord
            );

            if (!groups.containsKey(groupKey)) {
                MailGroup groupRecord = new MailGroup();
                groupRecord.eventType = eventType;
                groupRecord.recipientUserId = recipientUserId;
                groupRecord.recipientName = recipientName;
                groupRecord.recipientEmail = recipientEmail;
                groups.put(groupKey, groupRecord);
            }

            groups.get(groupKey)
                .transactions
                .add(transactionRecord);
        }

        return groups;
    }

    private static String buildGroupKey(
        String eventType,
        Id recipientUserId,
        Tagged_Approval_Hierarchy__c transactionRecord
    ) {
        String levelKey;

        if (eventType == EVENT_APPROVAL_REQUIRED) {
            levelKey = String.valueOf(
                transactionRecord.Current_Approval_Level__c
            );
        } else if (eventType == EVENT_RETURNED) {
            levelKey = String.valueOf(
                transactionRecord.Returned_From_Level__c
            );
        } else {
            levelKey = transactionRecord.Approval_Status__c;
        }

        return String.join(
            new List<String>{
                eventType,
                String.valueOf(recipientUserId),
                String.valueOf(transactionRecord.Form_Activity__c),
                String.valueOf(
                    transactionRecord
                        .Form_Activity_Assigned_Persons_Date__r == null
                            ? null
                            : transactionRecord
                                .Form_Activity_Assigned_Persons_Date__r
                                .Store__c
                ),
                String.valueOf(
                    transactionRecord
                        .Form_Activity_Assigned_Persons_Date__r == null
                            ? null
                            : transactionRecord
                                .Form_Activity_Assigned_Persons_Date__r
                                .Target_Date__c
                ),
                transactionRecord.Form_Activity_Assigned_Persons__r == null
                    ? ''
                    : safeText(
                        transactionRecord
                            .Form_Activity_Assigned_Persons__r
                            .Team_Name__c
                    ),
                transactionRecord
                    .Form_Activity_Assigned_Persons_Date__r == null
                        ? ''
                        : safeText(
                            transactionRecord
                                .Form_Activity_Assigned_Persons_Date__r
                                .Activity_Location__c
                        )
                            .trim()
                            .toLowerCase(),
                safeText(levelKey)
            },
            '|'
        );
    }

    private static String buildSubject(
        String eventType,
        Tagged_Approval_Hierarchy__c anchor
    ) {
        String activityNumber =
            anchor.Form_Activity__r == null
                ? 'BTL Activity'
                : displayValue(
                    anchor.Form_Activity__r.Name
                );

        String storeName =
            anchor.Form_Activity_Assigned_Persons_Date__r == null ||
            anchor.Form_Activity_Assigned_Persons_Date__r.Store__r == null
                ? 'Store'
                : displayValue(
                    anchor
                        .Form_Activity_Assigned_Persons_Date__r
                        .Store__r.Name
                );

        String dateLabel =
            anchor.Form_Activity_Assigned_Persons_Date__r == null
                ? ''
                : formatDate(
                    anchor
                        .Form_Activity_Assigned_Persons_Date__r
                        .Target_Date__c
                );

        if (eventType == EVENT_APPROVAL_REQUIRED) {
            return 'BTL Approval Required - ' +
                activityNumber + ' - ' +
                storeName +
                (String.isBlank(dateLabel)
                    ? ''
                    : ' - ' + dateLabel);
        }

        if (eventType == EVENT_RETURNED) {
            return 'BTL Approval Returned - ' +
                activityNumber + ' - ' +
                storeName +
                (String.isBlank(dateLabel)
                    ? ''
                    : ' - ' + dateLabel);
        }

        return 'BTL Approval Process Completed - ' +
            activityNumber + ' - ' +
            storeName +
            (String.isBlank(dateLabel)
                ? ''
                : ' - ' + dateLabel);
    }

    private static String buildHtmlBody(
        MailGroup groupRecord
    ) {
        Tagged_Approval_Hierarchy__c anchor =
            groupRecord.transactions[0];

        String title;
        String subtitle;
        String accentColor;
        String softColor;
        String statusLabel;

        if (groupRecord.eventType == EVENT_APPROVAL_REQUIRED) {
            title = 'BTL Approval Required';
            subtitle = getApprovalRequiredSubtitle(anchor);
            accentColor = '#0b5cab';
            softColor = '#eef6ff';
            statusLabel = 'Pending Approval';
        } else if (groupRecord.eventType == EVENT_RETURNED) {
            title = 'BTL Approval Returned';
            subtitle =
                'The activity has been returned to the Store Manager for correction and resubmission.';
            accentColor = '#ba0517';
            softColor = '#fff1f2';
            statusLabel = 'Returned';
        } else {
            title = 'BTL Approval Process Completed';
            Boolean isDropped =
                anchor.Approval_Status__c ==
                    Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED;
            subtitle = isDropped
                ? 'The BTL approval process has been closed because the returned activity was dropped.'
                : 'The BTL approval process has been completed successfully.';
            accentColor = isDropped
                ? '#8e4b10'
                : '#2e844a';
            softColor = isDropped
                ? '#fff7ed'
                : '#edfdf3';
            statusLabel = isDropped
                ? 'Dropped'
                : 'Approved';
        }

        String activityNumber = getActivityNumber(anchor);
        String activityName = getActivityName(anchor);
        String storeName = getStoreName(anchor);
        String targetDate = getTargetDate(anchor);
        String teamName = getTeamName(anchor);
        String location = getActivityLocation(anchor);
        String finalForm = getFinalFormNumber(anchor);
        String submittedBy =
            anchor.Submitted_By__r == null
                ? '—'
                : displayValue(
                    anchor.Submitted_By__r.Name
                );
        String submittedAt =
            formatDateTimeIST(
                anchor.Submitted_Date_Time__c
            );
        String levelName = getRelevantLevelName(
            groupRecord.eventType,
            anchor
        );
        String lastActor =
            anchor.Last_Action_By__r == null
                ? '—'
                : displayValue(
                    anchor.Last_Action_By__r.Name
                );
        String lastActionAt =
            formatDateTimeIST(
                anchor.Last_Action_Date_Time__c
            );
        String comments =
            displayValue(
                groupCommonComments(groupRecord)
            );

        String workspaceUrl = buildWorkspaceUrl(anchor.Id);
        String activityUrl = buildActivityUrl(
            anchor.Form_Activity__c
        );

        String rows = '';

        for (
            Tagged_Approval_Hierarchy__c transactionRecord :
            groupRecord.transactions
        ) {
            rows += '<tr>';
            rows += cell(transactionRecord.Name, false);
            rows += cell(getExecutiveName(transactionRecord), false);
            rows += cell(
                transactionRecord.Form_Activity_Assigned_Persons__r == null
                    ? '—'
                    : displayValue(
                        transactionRecord
                            .Form_Activity_Assigned_Persons__r.Name
                    ),
                false
            );
            rows += cell(
                formatCycle(transactionRecord.Submission_Cycle__c),
                true
            );
            rows += cell(
                displayValue(
                    transactionRecord.Approval_Status__c
                ),
                false
            );
            rows += '</tr>';
        }

        String body = '';
        body += '<!doctype html><html><body style="margin:0;padding:0;background:#f4f6f9;font-family:Arial,Helvetica,sans-serif;color:#181818;">';
        body += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f9;padding:24px 0;"><tr><td align="center">';
        body += '<table role="presentation" width="760" cellpadding="0" cellspacing="0" style="width:760px;max-width:94%;background:#ffffff;border:1px solid #d8dde6;border-radius:14px;overflow:hidden;">';

        body += '<tr><td style="padding:24px 28px;border-top:5px solid ' + accentColor + ';border-bottom:1px solid #e5e5e5;">';
        body += '<div style="font-size:24px;font-weight:700;color:' + accentColor + ';">' + html(title) + '</div>';
        body += '<div style="margin-top:6px;color:#5f6b7a;font-size:13px;line-height:1.5;">' + html(subtitle) + '</div>';
        body += '</td></tr>';

        body += '<tr><td style="padding:22px 28px;">';
        body += '<div style="margin-bottom:16px;">Hello <strong>' + html(groupRecord.recipientName) + '</strong>,</div>';

        body += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:18px;border:1px solid #d8dde6;border-radius:10px;background:' + softColor + ';"><tr>';
        body += '<td style="padding:14px 16px;"><div style="font-size:11px;text-transform:uppercase;font-weight:700;color:#5f6b7a;">Status</div><div style="margin-top:3px;font-size:18px;font-weight:700;color:' + accentColor + ';">' + html(statusLabel) + '</div></td>';
        body += '<td align="right" style="padding:14px 16px;"><div style="font-size:11px;text-transform:uppercase;font-weight:700;color:#5f6b7a;">Records in this mail</div><div style="margin-top:3px;font-size:18px;font-weight:700;">' + String.valueOf(groupRecord.transactions.size()) + '</div></td>';
        body += '</tr></table>';

        body += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin-bottom:18px;border:1px solid #d8dde6;border-radius:10px;">';
        body += infoRow('Activity', activityNumber + (activityName == '—' ? '' : ' - ' + activityName), 'Store', storeName);
        body += infoRow('Target Date', targetDate, 'Team', teamName);
        body += infoRow('Activity Location', location, 'Final Customize Form', finalForm);
        body += infoRow('Submitted By', submittedBy, 'Submitted Date & Time', submittedAt);
        body += infoRow(
            groupRecord.eventType == EVENT_RETURNED
                ? 'Returned From Level'
                : groupRecord.eventType == EVENT_APPROVAL_REQUIRED
                    ? 'Current Approval Level'
                    : 'Final Outcome',
            groupRecord.eventType == EVENT_COMPLETED
                ? statusLabel
                : levelName,
            groupRecord.eventType == EVENT_APPROVAL_REQUIRED
                ? 'Pending With'
                : groupRecord.eventType == EVENT_RETURNED
                    ? 'Rejected / Returned By'
                    : 'Process Completed By',
            groupRecord.eventType == EVENT_APPROVAL_REQUIRED
                ? displayValue(groupRecord.recipientName)
                : lastActor
        );
        body += infoRow(
            'Last Action',
            displayValue(anchor.Last_Action__c),
            'Action Date & Time',
            lastActionAt
        );
        body += '</table>';

        body += '<div style="margin-bottom:8px;font-size:14px;font-weight:700;color:#1f2937;">Assigned Manpower / Approval Records</div>';
        body += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin-bottom:18px;border:1px solid #d8dde6;">';
        body += '<tr style="background:#f3f3f3;">';
        body += headerCell('Approval No.');
        body += headerCell('Sales Executive');
        body += headerCell('Assigned Person');
        body += headerCell('Cycle');
        body += headerCell('Status');
        body += '</tr>';
        body += rows;
        body += '</table>';

        if (
            groupRecord.eventType == EVENT_RETURNED ||
            comments != '—'
        ) {
            body += '<div style="margin-bottom:18px;padding:13px 15px;border:1px solid #d8dde6;border-radius:10px;background:#fafafa;">';
            body += '<div style="font-size:11px;text-transform:uppercase;font-weight:700;color:#5f6b7a;">' +
                (groupRecord.eventType == EVENT_RETURNED
                    ? 'Rejection / Return Reason'
                    : 'Comments') +
                '</div>';
            body += '<div style="margin-top:5px;white-space:pre-wrap;line-height:1.5;">' + html(comments) + '</div>';
            body += '</div>';
        }

        body += '<div style="text-align:center;margin:24px 0 6px;">';
        body += '<a href="' + html(workspaceUrl) + '" style="display:inline-block;margin:0 5px 8px;padding:11px 22px;border-radius:22px;background:' + accentColor + ';color:#ffffff;text-decoration:none;font-weight:700;">View in BTL Approval Workspace</a>';
        if (String.isNotBlank(activityUrl)) {
            body += '<a href="' + html(activityUrl) + '" style="display:inline-block;margin:0 5px 8px;padding:10px 20px;border-radius:22px;border:1px solid #b5bac3;color:#2e2e2e;text-decoration:none;font-weight:700;background:#ffffff;">Open Activity</a>';
        }
        body += '</div>';

        if (groupRecord.eventType == EVENT_RETURNED) {
            body += '<div style="margin-top:14px;padding:12px 14px;border-radius:8px;background:#fff7e6;border:1px solid #f5c451;color:#5c3b00;font-size:12px;line-height:1.5;">This approval is not terminal. Correct the returned activity and resubmit it when ready. The approval will restart from the configured first approval level.</div>';
        }

        body += '<div style="margin-top:22px;color:#7a8593;font-size:11px;text-align:center;">This is an automated Salesforce notification for the Orient BTL approval process.</div>';
        body += '</td></tr></table></td></tr></table></body></html>';

        return body;
    }

    private static String buildPlainTextBody(
        MailGroup groupRecord
    ) {
        Tagged_Approval_Hierarchy__c anchor =
            groupRecord.transactions[0];

        List<String> lines = new List<String>();

        if (groupRecord.eventType == EVENT_APPROVAL_REQUIRED) {
            lines.add('BTL Approval Required');
        } else if (groupRecord.eventType == EVENT_RETURNED) {
            lines.add('BTL Approval Returned');
        } else {
            lines.add('BTL Approval Process Completed');
        }

        lines.add('');
        lines.add('Activity: ' + getActivityNumber(anchor) + ' - ' + getActivityName(anchor));
        lines.add('Store: ' + getStoreName(anchor));
        lines.add('Target Date: ' + getTargetDate(anchor));
        lines.add('Team: ' + getTeamName(anchor));
        lines.add('Records: ' + String.valueOf(groupRecord.transactions.size()));
        lines.add('Submitted By: ' + (anchor.Submitted_By__r == null ? '—' : displayValue(anchor.Submitted_By__r.Name)));
        lines.add('Submitted Date & Time: ' + formatDateTimeIST(anchor.Submitted_Date_Time__c));
        lines.add('Last Action: ' + displayValue(anchor.Last_Action__c));
        lines.add('Action Date & Time: ' + formatDateTimeIST(anchor.Last_Action_Date_Time__c));

        if (groupRecord.eventType == EVENT_RETURNED) {
            lines.add('Returned From: ' + getRelevantLevelName(groupRecord.eventType, anchor));
            lines.add('Reason: ' + displayValue(groupCommonComments(groupRecord)));
        }

        lines.add('');
        lines.add('Approval Records:');

        for (Tagged_Approval_Hierarchy__c transactionRecord : groupRecord.transactions) {
            lines.add(
                '- ' + displayValue(transactionRecord.Name) +
                ' | ' + getExecutiveName(transactionRecord) +
                ' | Cycle ' + formatCycle(
                    transactionRecord.Submission_Cycle__c
                ) +
                ' | ' + displayValue(transactionRecord.Approval_Status__c)
            );
        }

        lines.add('');
        lines.add('Workspace: ' + buildWorkspaceUrl(anchor.Id));

        return String.join(lines, '\n');
    }

    private static String getApprovalRequiredSubtitle(
        Tagged_Approval_Hierarchy__c anchor
    ) {
        if (
            anchor.Last_Action__c ==
                Ctrl_Hlp_BTLApprovalConstants.ACTION_RESUBMITTED
        ) {
            return 'A returned BTL activity has been corrected and resubmitted for your approval.';
        }

        if (
            anchor.Last_Action__c ==
                Ctrl_Hlp_BTLApprovalConstants.ACTION_APPROVED
        ) {
            return 'The previous approval level has approved the activity and it now requires your action.';
        }

        return 'A BTL activity has been submitted and requires your approval.';
    }

    private static String getRelevantLevelName(
        String eventType,
        Tagged_Approval_Hierarchy__c anchor
    ) {
        if (
            eventType == EVENT_APPROVAL_REQUIRED &&
            anchor.Current_Approval_Level__r != null
        ) {
            return displayValue(
                anchor.Current_Approval_Level__r.Responsible_Team__c
            );
        }

        if (
            eventType == EVENT_RETURNED &&
            anchor.Returned_From_Level__r != null
        ) {
            return displayValue(
                anchor.Returned_From_Level__r.Responsible_Team__c
            );
        }

        return '—';
    }

    private static String groupCommonComments(
        MailGroup groupRecord
    ) {
        String commonValue;
        Boolean initialized = false;

        for (
            Tagged_Approval_Hierarchy__c transactionRecord :
            groupRecord.transactions
        ) {
            String currentValue =
                safeText(
                    groupRecord.eventType == EVENT_COMPLETED &&
                    transactionRecord.Approval_Status__c ==
                        Ctrl_Hlp_BTLApprovalConstants.STATUS_DROPPED
                        ? transactionRecord.Drop_Reason__c
                        : transactionRecord.Last_Action_Comments__c
                );

            if (!initialized) {
                commonValue = currentValue;
                initialized = true;
                continue;
            }

            if (commonValue != currentValue) {
                return 'Please review the individual approval history in the BTL Approval Workspace.';
            }
        }

        return commonValue;
    }

    private static String getActivityNumber(
        Tagged_Approval_Hierarchy__c transactionRecord
    ) {
        return transactionRecord.Form_Activity__r == null
            ? '—'
            : displayValue(transactionRecord.Form_Activity__r.Name);
    }

    private static String getActivityName(
        Tagged_Approval_Hierarchy__c transactionRecord
    ) {
        return transactionRecord.Form_Activity__r == null
            ? '—'
            : displayValue(
                transactionRecord.Form_Activity__r.Activity_Name__c
            );
    }

    private static String getStoreName(
        Tagged_Approval_Hierarchy__c transactionRecord
    ) {
        return
            transactionRecord.Form_Activity_Assigned_Persons_Date__r == null ||
            transactionRecord.Form_Activity_Assigned_Persons_Date__r.Store__r == null
                ? '—'
                : displayValue(
                    transactionRecord
                        .Form_Activity_Assigned_Persons_Date__r
                        .Store__r.Name
                );
    }

    private static String getTargetDate(
        Tagged_Approval_Hierarchy__c transactionRecord
    ) {
        return transactionRecord.Form_Activity_Assigned_Persons_Date__r == null
            ? '—'
            : displayValue(
                formatDate(
                    transactionRecord
                        .Form_Activity_Assigned_Persons_Date__r
                        .Target_Date__c
                )
            );
    }

    private static String getTeamName(
        Tagged_Approval_Hierarchy__c transactionRecord
    ) {
        return transactionRecord.Form_Activity_Assigned_Persons__r == null
            ? '—'
            : displayValue(
                transactionRecord
                    .Form_Activity_Assigned_Persons__r
                    .Team_Name__c
            );
    }

    private static String getActivityLocation(
        Tagged_Approval_Hierarchy__c transactionRecord
    ) {
        return transactionRecord.Form_Activity_Assigned_Persons_Date__r == null
            ? '—'
            : displayValue(
                transactionRecord
                    .Form_Activity_Assigned_Persons_Date__r
                    .Activity_Location__c
            );
    }

    private static String getFinalFormNumber(
        Tagged_Approval_Hierarchy__c transactionRecord
    ) {
        return
            transactionRecord.Form_Activity__r == null ||
            transactionRecord.Form_Activity__r.Final_Customize_Form__r == null
                ? '—'
                : displayValue(
                    transactionRecord
                        .Form_Activity__r
                        .Final_Customize_Form__r.Name
                );
    }

    private static String getExecutiveName(
        Tagged_Approval_Hierarchy__c transactionRecord
    ) {
        return
            transactionRecord.Form_Activity_Assigned_Persons__r == null ||
            transactionRecord.Form_Activity_Assigned_Persons__r.Sales_Executives__r == null
                ? '—'
                : displayValue(
                    transactionRecord
                        .Form_Activity_Assigned_Persons__r
                        .Sales_Executives__r.Name
                );
    }

    private static String buildWorkspaceUrl(
        Id taggedApprovalId
    ) {
        if (taggedApprovalId == null) {
            return '';
        }

        return URL.getOrgDomainUrl().toExternalForm() +
            '/lightning/cmp/c__lwc_btlApprovalWorkspace' +
            '?c__transactionId=' +
            EncodingUtil.urlEncode(
                String.valueOf(taggedApprovalId),
                'UTF-8'
            );
    }

    private static String buildActivityUrl(
        Id activityId
    ) {
        if (activityId == null) {
            return '';
        }

        return URL.getOrgDomainUrl().toExternalForm() +
            '/lightning/r/Form_Activity__c/' +
            String.valueOf(activityId) +
            '/view';
    }

    private static String infoRow(
        String leftLabel,
        String leftValue,
        String rightLabel,
        String rightValue
    ) {
        return '<tr>' +
            '<td width="50%" style="padding:10px 12px;border-bottom:1px solid #ecebea;vertical-align:top;">' +
                '<div style="font-size:10px;text-transform:uppercase;font-weight:700;color:#5f6b7a;">' + html(leftLabel) + '</div>' +
                '<div style="margin-top:3px;font-weight:600;">' + html(displayValue(leftValue)) + '</div>' +
            '</td>' +
            '<td width="50%" style="padding:10px 12px;border-bottom:1px solid #ecebea;vertical-align:top;">' +
                '<div style="font-size:10px;text-transform:uppercase;font-weight:700;color:#5f6b7a;">' + html(rightLabel) + '</div>' +
                '<div style="margin-top:3px;font-weight:600;">' + html(displayValue(rightValue)) + '</div>' +
            '</td>' +
        '</tr>';
    }

    private static String headerCell(String value) {
        return '<th align="left" style="padding:9px 10px;border:1px solid #d8dde6;font-size:11px;color:#444;font-weight:700;">' +
            html(value) +
            '</th>';
    }

    private static String cell(
        String value,
        Boolean center
    ) {
        return '<td ' +
            (center ? 'align="center" ' : '') +
            'style="padding:9px 10px;border:1px solid #d8dde6;font-size:12px;vertical-align:top;">' +
            html(displayValue(value)) +
            '</td>';
    }

    private static String formatCycle(Decimal value) {
        return value == null
            ? '0'
            : String.valueOf(value.setScale(0));
    }

    private static String formatDate(Date value) {
        if (value == null) {
            return '';
        }

        Datetime dateTimeValue = Datetime.newInstance(
            value,
            Time.newInstance(0, 0, 0, 0)
        );

        return dateTimeValue.format(
            'dd-MMM-yyyy',
            IST_TIMEZONE
        );
    }

    private static String formatDateTimeIST(
        Datetime value
    ) {
        return value == null
            ? '—'
            : value.format(
                'dd-MMM-yyyy hh:mm a',
                IST_TIMEZONE
            ) + ' IST';
    }

    private static String displayValue(String value) {
        return String.isBlank(value)
            ? '—'
            : value;
    }

    private static String safeText(String value) {
        return value == null
            ? ''
            : value.trim();
    }

    private static String html(String value) {
        if (value == null) {
            return '';
        }

        return value
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&#39;');
    }

    private Ctrl_Hlp_BTLEmailNotificationService() {
    }

    private class MailConfigurationException
        extends Exception {
    }
}