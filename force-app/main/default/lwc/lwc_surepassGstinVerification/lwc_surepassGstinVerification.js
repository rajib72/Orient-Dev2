import { LightningElement, api, track, wire } from 'lwc';
import {
    getRecord,
    getFieldValue,
    notifyRecordUpdateAvailable
} from 'lightning/uiRecordApi';

import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';

import verifyGSTIN
    from '@salesforce/apex/ctrl_SurepassGSTINController.verifyGSTIN';

import processGSTINUpdateAndTracking
    from '@salesforce/apex/ctrl_SurepassGSTINController.processGSTINUpdateAndTracking';

import ACCOUNT_NAME from '@salesforce/schema/Account.Name';
import ACCOUNT_PAN from '@salesforce/schema/Account.PAN__c';
import ACCOUNT_GST from '@salesforce/schema/Account.GST__c';
import ACCOUNT_STATUS from '@salesforce/schema/Account.Status__c';
import ACCOUNT_BC_CUSTOMER_NO
    from '@salesforce/schema/Account.BC_Customer_No__c';
import ACCOUNT_CUSTOMER_VERIFICATION_KYC
    from '@salesforce/schema/Account.Customer_Verification_KYC__c';
import ACCOUNT_NAME_VERIFIED
    from '@salesforce/schema/Account.Name_Verified__c';
import ACCOUNT_GSTIN_VERIFIED
    from '@salesforce/schema/Account.GSTIN_Verified__c';

const FIELDS = [
    ACCOUNT_NAME,
    ACCOUNT_PAN,
    ACCOUNT_GST,
    ACCOUNT_STATUS,
    ACCOUNT_BC_CUSTOMER_NO,
    ACCOUNT_CUSTOMER_VERIFICATION_KYC,
    ACCOUNT_NAME_VERIFIED,
    ACCOUNT_GSTIN_VERIFIED
];

export default class SurepassGstinVerification extends LightningElement {
    @api recordId;

    gstinNumber = '';

    @track gstinData;
    @track responseData;
    @track result = {};
    @track comparisonDetails = {};

    errorMessage = '';

    isLoading = false;
    isUpdating = false;
    isRefreshing = false;

    showResult = false;
    showPanMissingPopup = false;
    showPanMismatchPopup = false;
    showReviewPopup = false;
    showConfirmUpdatePopup = false;
    showApprovalConfirmPopup = false;
    showApprovalSubmittedPopup = false;
    showSuccessPopup = false;

    outcome;
    proposedAccountName;
    reviewReason;
    lastProcessAction;

    isNameMismatch = false;
    isGstinMismatch = false;
    hasAnyAccountChange = false;
    isCustomerInfoMatch = false;

    isNameConflict = false;
    isGstinConflict = false;
    hasConflictingDetails = false;
    requiresApproval = false;

    verifiedFieldConflict = false;
    verifiedFieldConflictFields = [];

    @wire(getRecord, {
        recordId: '$recordId',
        fields: FIELDS
    })
    accountRecord;

    get accName() {
        return (
            getFieldValue(
                this.accountRecord.data,
                ACCOUNT_NAME
            ) || ''
        );
    }

    get accPan() {
        return (
            getFieldValue(
                this.accountRecord.data,
                ACCOUNT_PAN
            ) || ''
        );
    }

    get accGst() {
        return (
            getFieldValue(
                this.accountRecord.data,
                ACCOUNT_GST
            ) || ''
        );
    }

    get accountStatus() {
        return (
            getFieldValue(
                this.accountRecord.data,
                ACCOUNT_STATUS
            ) || ''
        );
    }

    get bcCustomerNo() {
        return (
            getFieldValue(
                this.accountRecord.data,
                ACCOUNT_BC_CUSTOMER_NO
            ) || ''
        );
    }

    get customerVerificationKyc() {
        return (
            getFieldValue(
                this.accountRecord.data,
                ACCOUNT_CUSTOMER_VERIFICATION_KYC
            ) || ''
        );
    }

    get nameVerified() {
        return (
            getFieldValue(
                this.accountRecord.data,
                ACCOUNT_NAME_VERIFIED
            ) === true
        );
    }

    get gstinVerified() {
        return (
            getFieldValue(
                this.accountRecord.data,
                ACCOUNT_GSTIN_VERIFIED
            ) === true
        );
    }

    get hasExistingCustomerVerification() {
        return Boolean(
            this.customerVerificationKyc &&
            String(
                this.customerVerificationKyc
            ).trim()
        );
    }

    get hasDifferentExistingVerification() {
        const existingMethod =
            this.normalizeVerificationMethod(
                this.customerVerificationKyc
            );

        return (
            existingMethod !== '' &&
            existingMethod !== 'GST'
        );
    }

    /*
     * GST direct update follows the GSTIN name-match result, not BC
     * Customer No. or Account Status.
     */
    get canDirectUpdate() {
        return (
            this.outcome === 'VERIFIED' &&
            !this.verifiedFieldConflict
        );
    }

    get formattedRegistrationDate() {
        return this.formatDateDDMMYYYY(
            this.gstinData
                ? this.gstinData.date_of_registration
                : null
        );
    }

    handleGSTChange(event) {
        this.gstinNumber = event.target.value
            ? event.target.value.toUpperCase()
            : '';

        event.target.value = this.gstinNumber;

        this.resetState();
    }

    resetState() {
        this.errorMessage = '';
        this.gstinData = null;
        this.responseData = null;
        this.result = {};
        this.comparisonDetails = {};

        this.showResult = false;
        this.showPanMissingPopup = false;
        this.showPanMismatchPopup = false;
        this.showReviewPopup = false;
        this.showConfirmUpdatePopup = false;
        this.showApprovalConfirmPopup = false;
        this.showApprovalSubmittedPopup = false;
        this.showSuccessPopup = false;

        this.outcome = null;
        this.proposedAccountName = null;
        this.reviewReason = null;
        this.lastProcessAction = null;

        this.isNameMismatch = false;
        this.isGstinMismatch = false;
        this.hasAnyAccountChange = false;
        this.isCustomerInfoMatch = false;

        this.isNameConflict = false;
        this.isGstinConflict = false;
        this.hasConflictingDetails = false;
        this.requiresApproval = false;

        this.verifiedFieldConflict = false;
        this.verifiedFieldConflictFields = [];
    }

    closeModals() {
        this.showPanMissingPopup = false;
        this.showPanMismatchPopup = false;
        this.showReviewPopup = false;
        this.showConfirmUpdatePopup = false;
        this.showApprovalConfirmPopup = false;
        this.showApprovalSubmittedPopup = false;
        this.showSuccessPopup = false;
    }

    handleCancel() {
        this.resetState();
    }

    async handleRefresh() {
        this.isRefreshing = true;
        this.errorMessage = '';

        try {
            await this.refreshAccountData();

            if (this.gstinData) {
                this.evaluateAccountChanges();
            }

            this.showToast(
                'Success',
                'Customer details refreshed successfully.',
                'success'
            );
        } catch (error) {
            this.errorMessage =
                this.getErrorMessage(error);

            this.showToast(
                'Error',
                this.errorMessage,
                'error'
            );
        } finally {
            this.isRefreshing = false;
        }
    }

    async refreshAccountData() {
        try {
            await refreshApex(this.accountRecord);
        } catch (refreshError) {
            // LDS refresh below remains the fallback.
        }

        if (this.recordId) {
            await notifyRecordUpdateAvailable([
                {
                    recordId: this.recordId
                }
            ]);
        }

        this.dispatchEvent(new RefreshEvent());
    }

    async handleVerify() {
        this.resetState();

        if (!this.accountRecord.data) {
            this.errorMessage =
                'Account details are still loading. Please try again.';
            return;
        }

        const enteredGstin = (
            this.gstinNumber || ''
        ).trim().toUpperCase();

        if (!enteredGstin) {
            this.errorMessage =
                'Please enter GSTIN / ID Number.';
            return;
        }

        if (!this.isValidGSTINFormat(enteredGstin)) {
            this.errorMessage =
                'Please enter a valid 15-character GSTIN.';
            return;
        }

        if (!this.accPan || !this.accPan.trim()) {
            this.showPanMissingPopup = true;
            return;
        }

        const panFromEnteredGstin =
            this.extractPanFromGstin(
                enteredGstin
            );

        if (
            panFromEnteredGstin !==
            this.cleanPan(this.accPan)
        ) {
            this.showPanMismatchPopup = true;
            return;
        }

        this.isLoading = true;

        try {
            const apiResult = await verifyGSTIN({
                idNumber: enteredGstin,
                accountId: this.recordId
            });

            if (
                apiResult &&
                apiResult.success === true &&
                apiResult.data
            ) {
                if (!apiResult.data.gstin) {
                    apiResult.data.gstin =
                        enteredGstin;
                }

                this.gstinData =
                    apiResult.data;

                this.responseData =
                    apiResult;

                this.gstinNumber =
                    this.gstinData.gstin ||
                    enteredGstin;

                const apiPan = this.cleanPan(
                    this.gstinData.pan_number
                );

                if (
                    apiPan &&
                    apiPan !== this.cleanPan(this.accPan)
                ) {
                    this.showPanMismatchPopup = true;
                    return;
                }

                this.evaluateVerificationResult();
                this.showResult = true;
            } else {
                this.errorMessage =
                    apiResult?.message ||
                    'Unable to verify GSTIN.';
            }
        } catch (error) {
            this.errorMessage =
                this.getErrorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }

    evaluateVerificationResult() {
        const gstStatus =
            this.gstinData?.gstin_status || '';

        const constitution =
            this.gstinData?.constitution_of_business || '';

        const legalName =
            this.gstinData?.legal_name || '';

        const businessName =
            this.gstinData?.business_name || '';

        const isActive =
            this.isActiveGSTIN(gstStatus);

        const isProp =
            this.isProprietorship(
                constitution
            );

        const legalExactMatch =
            this.cleanExactName(
                this.accName
            ) ===
            this.cleanExactName(
                legalName
            );

        const businessExactMatch =
            this.cleanExactName(
                this.accName
            ) ===
            this.cleanExactName(
                businessName
            );

        const legalSimilar =
            this.areNamesSimilar(
                this.accName,
                legalName
            );

        const businessSimilar =
            this.areNamesSimilar(
                this.accName,
                businessName
            );

        this.proposedAccountName =
            this.determineProposedAccountName(
                isProp,
                legalExactMatch,
                businessExactMatch,
                legalSimilar,
                businessSimilar,
                legalName,
                businessName
            );

        this.evaluateAccountChanges();

        if (!isActive) {
            this.outcome =
                'GSTIN_NOT_ACTIVE';

            this.requiresApproval =
                false;

            this.reviewReason =
                'The verified GSTIN is not Active. Account update and approval processing are blocked.';

            this.result = {
                variant: 'error',
                icon: 'utility:error',
                title: 'GSTIN Not Active',
                message:
                    'The provided GSTIN has been verified, but its status is not Active. Customer details cannot be updated.',
                panMatch: 'Matched',
                nameMatch:
                    this.getDirectNameStatusText(
                        isProp,
                        legalExactMatch,
                        businessExactMatch
                    ),
                gstinStatus:
                    gstStatus || 'Not Active',
                overallResult:
                    'Cannot Proceed',
                infoMessage:
                    'Only Active GSTINs are allowed for update.'
            };

            return;
        }

        /*
         * Verified Lock has priority over approval.
         * A value already verified by another KYC source cannot be
         * overwritten and cannot be sent for approval.
         */
        if (this.verifiedFieldConflict) {
            this.outcome =
                'VERIFIED_FIELD_CONFLICT';

            this.requiresApproval =
                false;

            const lockedFields =
                this.verifiedFieldConflictFields.join(
                    ', '
                );

            this.reviewReason =
                `Already verified Customer field(s) do not match the GSTIN response: ${lockedFields}.`;

            this.result = {
                variant: 'error',
                icon: 'utility:lock',
                title: 'Verified Customer Details Locked',
                message:
                    'One or more values returned by GSTIN verification conflict with Customer fields that are already KYC verified.',
                panMatch: 'Matched',
                nameMatch:
                    legalExactMatch ||
                    (
                        isProp &&
                        businessExactMatch
                    )
                        ? 'Matched'
                        : 'Mismatch',
                gstinStatus: 'Active',
                overallResult: 'Cannot Proceed',
                infoMessage:
                    'Verified fields cannot be changed and cannot be sent for approval.'
            };

            return;
        }

        /*
         * DIRECT SUCCESS
         * - Proprietorship: Legal OR Business Name exact match.
         * - Other constitutions: Legal Name exact match only.
         */
        if (
            (
                isProp &&
                (
                    legalExactMatch ||
                    businessExactMatch
                )
            ) ||
            (
                !isProp &&
                legalExactMatch
            )
        ) {
            this.outcome =
                'VERIFIED';

            this.requiresApproval =
                false;

            this.reviewReason =
                legalExactMatch
                    ? 'The Customer Name matches the Legal Name registered under the GSTIN.'
                    : 'The Customer Name matches the Business Name registered under the GSTIN for a proprietorship.';

            this.result = {
                variant: 'success',
                icon: 'utility:success',
                title: 'GSTIN Details Verified',
                message:
                    'The PAN and Customer Name satisfy the GSTIN verification rules. Please review the fetched information before proceeding.',
                panMatch: 'Matched',
                nameMatch:
                    legalExactMatch
                        ? 'Matched with Legal Name'
                        : 'Matched with Business Name',
                gstinStatus: 'Active',
                overallResult: 'Verified',
                infoMessage:
                    this.reviewReason
            };

            return;
        }

        /*
         * REVIEW REQUIRED is the ONLY approval scenario.
         */
        if (
            legalSimilar ||
            businessSimilar
        ) {
            this.outcome =
                'REVIEW_REQUIRED';

            this.requiresApproval =
                true;

            this.reviewReason =
                'The Customer Name appears similar to the verified GSTIN name, but it does not satisfy the direct-match rule.';

            this.result = {
                variant: 'warning',
                icon: 'utility:warning',
                title: 'GSTIN Details Require Review',
                message:
                    'The PAN matches and GSTIN is Active, but the Customer Name requires approval review.',
                panMatch: 'Matched',
                nameMatch: 'Possible Match',
                gstinStatus: 'Active',
                overallResult: 'Approval Required',
                infoMessage:
                    this.reviewReason
            };

            return;
        }

        /*
         * HARD MISMATCH is blocked. It must never create approval.
         */
        this.outcome =
            'MISMATCH_BLOCKED';

        this.requiresApproval =
            false;

        this.reviewReason =
            'The Customer Name is clearly different from the Legal Name / eligible Business Name associated with the GSTIN.';

        this.result = {
            variant: 'error',
            icon: 'utility:error',
            title: 'GSTIN Details Mismatch',
            message:
                'The PAN matches, but the Customer Name is clearly unrelated to the verified GSTIN name.',
            panMatch: 'Matched',
            nameMatch: 'Mismatch',
            gstinStatus: 'Active',
            overallResult: 'Cannot Proceed',
            infoMessage:
                'This GSTIN verification is blocked. No Account update or approval request can be created.'
        };
    }

    determineProposedAccountName(
        isProp,
        legalExactMatch,
        businessExactMatch,
        legalSimilar,
        businessSimilar,
        legalName,
        businessName
    ) {
        if (isProp) {
            if (legalExactMatch && legalName) {
                return legalName;
            }

            if (businessExactMatch && businessName) {
                return businessName;
            }

            if (legalSimilar && legalName) {
                return legalName;
            }

            if (businessSimilar && businessName) {
                return businessName;
            }

            return legalName || businessName || '';
        }

        return legalName || businessName || '';
    }

    evaluateAccountChanges() {
        if (!this.gstinData) {
            return;
        }

        const verifiedName =
            this.proposedAccountName ||
            this.gstinData.legal_name ||
            this.gstinData.business_name ||
            '';

        const verifiedGstin =
            this.gstinData.gstin ||
            this.gstinNumber ||
            '';

        const normalizedAccountName =
            this.cleanExactName(
                this.accName
            );

        const normalizedVerifiedName =
            this.cleanExactName(
                verifiedName
            );

        const normalizedAccountGstin =
            this.cleanGstin(
                this.accGst
            );

        const normalizedVerifiedGstin =
            this.cleanGstin(
                verifiedGstin
            );

        this.isNameMismatch =
            normalizedVerifiedName !== '' &&
            normalizedAccountName !==
                normalizedVerifiedName;

        this.isGstinMismatch =
            normalizedVerifiedGstin !== '' &&
            normalizedAccountGstin !==
                normalizedVerifiedGstin;

        /*
         * Blank Account values are safe to populate directly.
         * A conflict exists only when a populated Account value differs
         * from the populated value verified by Surepass.
         */
        this.isNameConflict =
            normalizedAccountName !== '' &&
            normalizedVerifiedName !== '' &&
            this.isNameMismatch;

        this.isGstinConflict =
            normalizedAccountGstin !== '' &&
            normalizedVerifiedGstin !== '' &&
            this.isGstinMismatch;

        this.hasConflictingDetails =
            this.isNameConflict ||
            this.isGstinConflict;

        this.isCustomerInfoMatch =
            !this.isNameConflict;

        this.hasAnyAccountChange =
            this.isNameMismatch ||
            this.isGstinMismatch;

        this.verifiedFieldConflictFields = [];

        if (
            this.nameVerified &&
            this.isNameMismatch
        ) {
            this.verifiedFieldConflictFields.push(
                'Customer Name'
            );
        }

        if (
            this.gstinVerified &&
            this.isGstinMismatch
        ) {
            this.verifiedFieldConflictFields.push(
                'GSTIN'
            );
        }

        this.verifiedFieldConflict =
            this.verifiedFieldConflictFields.length > 0;

        /*
         * GST approval is driven by the name-match outcome.
         * This assignment is useful when Account data is refreshed after
         * verification while keeping the previously calculated outcome.
         */
        this.requiresApproval =
            this.outcome ===
                'REVIEW_REQUIRED' &&
            !this.verifiedFieldConflict;

        this.comparisonDetails = {
            accountName:
                this.accName || 'Blank',

            verifiedName:
                verifiedName || 'Blank',

            accountPan:
                this.accPan || 'Blank',

            verifiedPan:
                this.gstinData.pan_number ||
                this.extractPanFromGstin(
                    verifiedGstin
                ) ||
                'Blank',

            accountGstin:
                this.accGst || 'Blank',

            verifiedGstin:
                verifiedGstin || 'Blank'
        };
    }


    handleProceedUpdate() {
        this.openReviewPopup();
    }

    handleSendForApproval() {
        this.openReviewPopup();
    }

    handleReviewNoChanges() {
        this.openReviewPopup();
    }

    openReviewPopup() {
        if (
            !this.recordId ||
            !this.responseData ||
            !this.gstinData
        ) {
            return;
        }

        this.evaluateAccountChanges();
        this.showReviewPopup = true;
    }

    handleProceedFromReview() {
        this.showReviewPopup = false;

        if (
            this.outcome ===
                'REVIEW_REQUIRED' &&
            !this.verifiedFieldConflict
        ) {
            this.showApprovalConfirmPopup = true;
            return;
        }

        if (
            this.outcome ===
                'VERIFIED' &&
            !this.verifiedFieldConflict
        ) {
            this.showConfirmUpdatePopup = true;
        }
    }


    handleConfirmUpdate() {
        this.showConfirmUpdatePopup = false;
        this.executeGSTINProcess(false);
    }

    handleConfirmSendForApproval() {
        this.showApprovalConfirmPopup = false;
        this.executeGSTINProcess(true);
    }

    async executeGSTINProcess(requestApproval) {
        if (
            !this.recordId ||
            !this.responseData
        ) {
            return;
        }

        this.isUpdating = true;
        this.errorMessage = '';

        try {
            const processResult =
                await processGSTINUpdateAndTracking({
                    accountId: this.recordId,
                    responseJson: JSON.stringify(
                        this.responseData
                    ),
                    proposedAccountName:
                        this.proposedAccountName,
                    matchReason:
                        this.reviewReason,
                    requestApproval:
                        requestApproval
                });

            await this.refreshAccountData();

            if (
                processResult &&
                processResult.noChanges
            ) {
                this.lastProcessAction =
                    'NO_CHANGES';

                this.showSuccessPopup = true;

                this.showToast(
                    'Success',
                    processResult.message ||
                        'The verified GSTIN details already match the Account.',
                    'success'
                );

                return;
            }

            if (
                processResult &&
                processResult.approvalCreated
            ) {
                this.lastProcessAction =
                    'APPROVAL';

                this.showApprovalSubmittedPopup =
                    true;

                this.showToast(
                    'Success',
                    processResult.message ||
                        'GSTIN changes submitted for approval.',
                    'success'
                );

                return;
            }

            if (
                processResult &&
                processResult.accountUpdated
            ) {
                this.lastProcessAction =
                    'UPDATED';

                this.showSuccessPopup = true;

                this.showToast(
                    'Success',
                    processResult.message ||
                        'Account updated successfully with GSTIN information.',
                    'success'
                );
            }
        } catch (error) {
            this.errorMessage =
                this.getErrorMessage(error);

            this.showToast(
                'Error',
                this.errorMessage,
                'error'
            );
        } finally {
            this.isUpdating = false;
        }
    }

    closeApprovalSubmitted() {
        this.showApprovalSubmittedPopup = false;
        this.resetState();
    }

    closeSuccessPopup() {
        this.showSuccessPopup = false;
        this.resetState();
    }

    get reviewModalTitle() {
        return this.outcome ===
            'REVIEW_REQUIRED'
            ? 'GSTIN Details Require Review'
            : 'GSTIN Details Verified';
    }

    get reviewModalDescription() {
        if (
            this.outcome ===
            'REVIEW_REQUIRED'
        ) {
            return 'The PAN matches and GSTIN is Active, but the Customer Name does not satisfy the direct-match rule. Please review the proposed values before submitting them for approval.';
        }

        return 'The GSTIN satisfies the direct verification rules. Please review the details before updating the Customer.';
    }

    get reviewModalIcon() {
        return this.outcome ===
            'REVIEW_REQUIRED'
            ? 'utility:warning'
            : 'utility:success';
    }

    get reviewModalIconClass() {
        return this.outcome ===
            'REVIEW_REQUIRED'
            ? 'modal-warning-icon'
            : 'modal-success-icon';
    }

    get reviewProceedButtonLabel() {
        return this.outcome ===
            'REVIEW_REQUIRED'
            ? 'Proceed for Approval'
            : 'Continue';
    }

    get showNameComparisonRow() {
        return (
            this.isCustomerInfoMatch ||
            this.isNameMismatch
        );
    }

    get showGstinComparisonRow() {
        return (
            this.isCustomerInfoMatch ||
            this.isGstinMismatch
        );
    }

    get showApprovalInformation() {
        return (
            this.outcome ===
                'REVIEW_REQUIRED' &&
            !this.verifiedFieldConflict
        );
    }

    get isProcessableOutcome() {
        return (
            this.outcome === 'VERIFIED' ||
            this.outcome === 'REVIEW_REQUIRED'
        );
    }

    get showDirectUpdateAction() {
        return (
            this.outcome ===
                'VERIFIED' &&
            !this.verifiedFieldConflict &&
            this.hasAnyAccountChange
        );
    }

    get showApprovalAction() {
        return (
            this.outcome ===
                'REVIEW_REQUIRED' &&
            !this.verifiedFieldConflict
        );
    }

    get showNoChangeAction() {
        return (
            this.outcome ===
                'VERIFIED' &&
            !this.verifiedFieldConflict &&
            !this.hasAnyAccountChange
        );
    }

    get showBlockedAction() {
        return (
            this.outcome ===
                'GSTIN_NOT_ACTIVE' ||
            this.outcome ===
                'MISMATCH_BLOCKED' ||
            this.outcome ===
                'VERIFIED_FIELD_CONFLICT'
        );
    }

    get successPopupTitle() {
        return this.lastProcessAction ===
            'NO_CHANGES'
            ? 'GSTIN Details Already Match'
            : 'GSTIN Updated Successfully';
    }

    get successPopupDescription() {
        if (
            this.lastProcessAction ===
            'NO_CHANGES'
        ) {
            return 'The verified GSTIN details already match the Account details. No Account information changes were required.';
        }

        return 'The verified GSTIN details have been successfully updated in the customer Account.';
    }

    isValidGSTINFormat(value) {
        const gstin = (
            value || ''
        ).trim().toUpperCase();

        const gstinPattern =
            /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/;

        return gstinPattern.test(gstin);
    }

    extractPanFromGstin(value) {
        const gstin = (
            value || ''
        ).trim().toUpperCase();

        if (gstin.length !== 15) {
            return '';
        }

        return gstin.substring(2, 12);
    }

    cleanPan(value) {
        return (
            value || ''
        ).trim().toUpperCase();
    }

    cleanGstin(value) {
        return (
            value || ''
        ).trim().toUpperCase();
    }

    normalizeVerificationMethod(value) {
        if (!value) {
            return '';
        }

        const normalized = String(value)
            .replace(/[^a-zA-Z0-9]/g, '')
            .toUpperCase();

        if (normalized === 'GSTIN' || normalized === 'GST') {
            return 'GST';
        }

        if (
            normalized === 'VOTER' ||
            normalized === 'VOTERID'
        ) {
            return 'VOTERID';
        }

        return normalized;
    }

    cleanExactName(value) {
        let name = (
            value || ''
        ).toString().toUpperCase();

        name = name.replace(/&/g, ' AND ');
        name = name.replace(/[^A-Z0-9\s]/g, ' ');
        name = name.replace(/\s+/g, ' ').trim();

        name = name.replace(
            /^(M\s*S|MS|MESSRS|MESSERS)\s+/g,
            ''
        );

        name = name.replace(
            /\bL\s+L\s+P\b/g,
            'LLP'
        );

        name = name.replace(
            /\bLIMITED\s+LIABILITY\s+PARTNERSHIP\b/g,
            'LLP'
        );

        name = name.replace(
            /\bPVT\b/g,
            'PRIVATE'
        );

        name = name.replace(
            /\bLTD\b/g,
            'LIMITED'
        );

        name = name.replace(
            /\bC\s+O\b/g,
            'COMPANY'
        );

        name = name.replace(
            /\bCO\b/g,
            'COMPANY'
        );

        return name
            .replace(/\s+/g, ' ')
            .trim();
    }

    normalizeLooseName(value) {
        return this.cleanExactName(value)
            .replace(
                /\b(MR|MRS|SHRI|SMT|SRI)\b/g,
                ' '
            )
            .replace(
                /\b(PRIVATE|LIMITED|COMPANY|LLP|LLC|INC|INDIA|THE)\b/g,
                ' '
            )
            .replace(/\s+/g, ' ')
            .trim();
    }

    areNamesSimilar(nameOne, nameTwo) {
        const firstName =
            this.normalizeLooseName(nameOne);

        const secondName =
            this.normalizeLooseName(nameTwo);

        if (!firstName || !secondName) {
            return false;
        }

        if (firstName === secondName) {
            return true;
        }

        if (
            firstName.length >= 4 &&
            secondName.length >= 4 &&
            (
                firstName.includes(secondName) ||
                secondName.includes(firstName)
            )
        ) {
            return true;
        }

        const firstTokens =
            firstName.split(' ').filter(Boolean);

        const secondTokens =
            secondName.split(' ').filter(Boolean);

        if (
            !firstTokens.length ||
            !secondTokens.length
        ) {
            return false;
        }

        let commonCount = 0;

        firstTokens.forEach((token) => {
            if (secondTokens.includes(token)) {
                commonCount += 1;
            }
        });

        const maxTokenCount = Math.max(
            firstTokens.length,
            secondTokens.length
        );

        return (
            commonCount >= 2 ||
            commonCount / maxTokenCount >= 0.6
        );
    }

    isProprietorship(value) {
        return (
            value || ''
        ).toLowerCase().includes(
            'proprietor'
        );
    }

    isActiveGSTIN(value) {
        return (
            value || ''
        ).trim().toLowerCase() === 'active';
    }

    getDirectNameStatusText(
        isProp,
        legalExactMatch,
        businessExactMatch
    ) {
        if (legalExactMatch) {
            return 'Matched with Legal Name';
        }

        if (
            isProp &&
            businessExactMatch
        ) {
            return 'Matched with Business Name';
        }

        return 'Mismatch';
    }

    formatDateDDMMYYYY(value) {
        if (!value) {
            return '';
        }

        let dateValue =
            String(value).trim();

        if (dateValue.includes('T')) {
            dateValue =
                dateValue.split('T')[0];
        } else if (dateValue.includes(' ')) {
            dateValue =
                dateValue.split(' ')[0];
        }

        if (
            /^\d{2}\/\d{2}\/\d{4}$/.test(
                dateValue
            )
        ) {
            return dateValue;
        }

        if (
            /^\d{4}-\d{2}-\d{2}$/.test(
                dateValue
            )
        ) {
            const parts =
                dateValue.split('-');

            return `${parts[2]}/${parts[1]}/${parts[0]}`;
        }

        if (
            /^\d{4}\/\d{2}\/\d{2}$/.test(
                dateValue
            )
        ) {
            const parts =
                dateValue.split('/');

            return `${parts[2]}/${parts[1]}/${parts[0]}`;
        }

        if (
            /^\d{2}-\d{2}-\d{4}$/.test(
                dateValue
            )
        ) {
            return dateValue.replace(
                /-/g,
                '/'
            );
        }

        return dateValue;
    }

    getErrorMessage(error) {
        return (
            error?.body?.message ||
            error?.message ||
            'Something went wrong.'
        );
    }

    get disableVerifyButton() {
        return (
            this.isLoading ||
            this.isUpdating ||
            this.isRefreshing ||
            !this.gstinNumber
        );
    }

    get disableActionButton() {
        return (
            this.isLoading ||
            this.isUpdating ||
            this.isRefreshing
        );
    }

    get disableRefreshButton() {
        return (
            this.isLoading ||
            this.isUpdating ||
            this.isRefreshing
        );
    }

    get bannerClass() {
        return `verification-banner ${
            this.result?.variant || ''
        }`;
    }

    get bannerIcon() {
        return (
            this.result?.icon ||
            'utility:info'
        );
    }

    get panPillClass() {
        return 'result-pill success-pill';
    }

    get namePillClass() {
        if (this.outcome === 'VERIFIED') {
            return 'result-pill success-pill';
        }

        if (
            this.outcome ===
            'REVIEW_REQUIRED'
        ) {
            return 'result-pill warning-pill';
        }

        return 'result-pill error-pill';
    }

    get gstinStatusPillClass() {
        return this.outcome ===
            'GSTIN_NOT_ACTIVE'
            ? 'result-pill error-pill'
            : 'result-pill success-pill';
    }

    get overallPillClass() {
        if (this.outcome === 'VERIFIED') {
            return 'result-pill success-pill';
        }

        if (
            this.outcome ===
            'REVIEW_REQUIRED'
        ) {
            return 'result-pill warning-pill';
        }

        return 'result-pill error-pill';
    }

    get statusClass() {
        return this.isActiveGSTIN(
            this.gstinData?.gstin_status
        )
            ? 'status-active'
            : 'status-inactive';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}