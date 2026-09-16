public without sharing class Ctrl_Hlp_OrientCustAddressApproval {

    public static final String CHANGE_MODE_ADDRESS =
        'Address API Only';

    private static final Set<String> HIDDEN_UI_FIELD_APIS =
        new Set<String>{
            'Country__c',
            'StateCode__c',
            'Country_Region_Code__c'
        };

    private static Set<String> cachedBCControlledFieldApis;

    public static Set<String> getBCControlledFieldApis() {
        if (cachedBCControlledFieldApis == null) {
            cachedBCControlledFieldApis =
                new Set<String>();

            for (
                Orient_Customer_Field_Mapping__mdt mapping :
                [
                    SELECT Account_Field_API__c
                    FROM Orient_Customer_Field_Mapping__mdt
                    WHERE Active__c = true
                    AND Requires_Approval__c = true
                    AND Change_Mode__c = :CHANGE_MODE_ADDRESS
                ]
            ) {
                if (
                    String.isNotBlank(
                        mapping.Account_Field_API__c
                    )
                ) {
                    cachedBCControlledFieldApis.add(
                        mapping.Account_Field_API__c
                    );
                }
            }
        }

        Set<String> result =
            new Set<String>();
        result.addAll(
            cachedBCControlledFieldApis
        );
        return result;
    }

    public static Boolean isBCControlledField(
        String accountFieldApi
    ) {
        return
            String.isNotBlank(accountFieldApi) &&
            getBCControlledFieldApis().contains(
                accountFieldApi
            );
    }

    public static Boolean isWorkspaceVisibleField(
        String accountFieldApi
    ) {
        if (
            !isBCControlledField(
                accountFieldApi
            )
        ) {
            return true;
        }

        return !HIDDEN_UI_FIELD_APIS.contains(
            accountFieldApi
        );
    }

    public static void validateAtomicDecision(
        List<Orient_Customer_Change_Item__c> pendingItems,
        Map<Id, Map<String, Object>> decisionByItemId
    ) {
        List<Orient_Customer_Change_Item__c> addressItems =
            new List<Orient_Customer_Change_Item__c>();

        for (
            Orient_Customer_Change_Item__c itemRecord :
            pendingItems
        ) {
            if (
                isBCControlledField(
                    itemRecord.Account_Field_API__c
                )
            ) {
                addressItems.add(
                    itemRecord
                );
            }
        }

        if (addressItems.isEmpty()) {
            return;
        }

        String groupDecision;
        String groupRejectionReason;

        for (
            Orient_Customer_Change_Item__c itemRecord :
            addressItems
        ) {
            Map<String, Object> decisionRow =
                decisionByItemId.get(
                    itemRecord.Id
                );

            if (decisionRow == null) {
                throw new AuraHandledException(
                    'A decision is required for the complete Business Central controlled address.'
                );
            }

            String decision =
                decisionRow.get('decision') == null
                    ? null
                    : String.valueOf(
                        decisionRow.get(
                            'decision'
                        )
                    ).trim();

            if (
                decision != 'Approve' &&
                decision != 'Reject'
            ) {
                throw new AuraHandledException(
                    'Select Approve All or Reject All for the Business Central controlled address.'
                );
            }

            if (groupDecision == null) {
                groupDecision =
                    decision;
            } else if (
                groupDecision !=
                decision
            ) {
                throw new AuraHandledException(
                    'Business Central controlled address fields must be approved or rejected together.'
                );
            }

            if (decision == 'Reject') {
                String rejectionReason =
                    decisionRow.get(
                        'rejectionReason'
                    ) == null
                        ? null
                        : String.valueOf(
                            decisionRow.get(
                                'rejectionReason'
                            )
                        ).trim();

                if (
                    String.isBlank(
                        rejectionReason
                    )
                ) {
                    throw new AuraHandledException(
                        'Rejection Reason is required when rejecting the Business Central controlled address.'
                    );
                }

                if (
                    groupRejectionReason ==
                    null
                ) {
                    groupRejectionReason =
                        rejectionReason;
                } else if (
                    groupRejectionReason !=
                    rejectionReason
                ) {
                    throw new AuraHandledException(
                        'Use one common rejection reason for the complete Business Central controlled address.'
                    );
                }
            }
        }
    }
}