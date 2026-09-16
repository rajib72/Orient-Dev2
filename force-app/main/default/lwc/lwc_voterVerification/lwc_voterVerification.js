import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { RefreshEvent } from 'lightning/refresh';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getAccountDefaults
    from '@salesforce/apex/ctrl_SurepassVoterController.getAccountDefaults';

import verifyVoter
    from '@salesforce/apex/ctrl_SurepassVoterController.verifyVoter';

import processAccountUpdateAndTracking
    from '@salesforce/apex/ctrl_SurepassVoterController.processAccountUpdateAndTracking';

export default class VoterVerification extends LightningElement {
    @api recordId;

    voterNumber = '';

    accountName = '';
    accountGender = '';
    existingVoter = '';
    accountStatus = '';
    bcCustomerId = '';
    customerVerificationKyc = '';
    differentVerificationMethod = false;

    nameVerified = false;
    genderVerified = false;
    voterVerified = false;

    verifiedFieldConflict = false;
    verifiedFieldConflictFields = [];

    canDirectUpdate = false;

    voterData;
    rawVoterData;

    successMessage = '';
    errorMessage = '';

    isLoading = false;
    isRefreshing = false;
    isUpdated = false;
    requiresApproval = false;

    isCustomerInfoMatch = false;
    isNameMismatch = false;
    isGenderMismatch = false;
    isVoterMismatch = false;
    hasAnyAccountChange = false;

    isNameConflict = false;
    isGenderConflict = false;
    isVoterConflict = false;
    hasConflictingDetails = false;

    lastActionType = '';

    @track showMismatchPopup = false;
    @track showConfirmPopup = false;
    @track showApprovalPopup = false;
    @track showApprovalSubmittedPopup = false;
    @track showSuccessPopup = false;

    @track mismatchDetails = {};

    wiredAccountResult;

    @wire(getAccountDefaults, { recordId: '$recordId' })
    wiredAccountDefaults(result) {
        this.wiredAccountResult = result;

        if (result.data) {
            this.accountName = result.data.accountName || '';
            this.accountGender = result.data.accountGender || '';
            this.existingVoter = result.data.voterValue || '';
            this.accountStatus = result.data.accountStatus || '';
            this.bcCustomerId = result.data.bcCustomerId || '';
            this.customerVerificationKyc =
                result.data.customerVerificationKyc || '';

            this.nameVerified =
                result.data.nameVerified === true;

            this.genderVerified =
                result.data.genderVerified === true;

            this.voterVerified =
                result.data.voterVerified === true;

            this.differentVerificationMethod =
                result.data.differentVerificationMethod === true;

            /*
             * This is only an initial hint. The final action is calculated
             * after comparing the verified values and is enforced again
             * in Apex. Account Status is not part of the decision.
             */
            this.canDirectUpdate =
                result.data.directUpdateAllowed === true;

            if (!this.voterNumber && result.data.voterValue) {
                this.voterNumber = result.data.voterValue;
            }

            if (this.voterData) {
                this.evaluateComparison();
            }
        } else if (result.error) {
            this.errorMessage = this.reduceErrors(result.error);
        }
    }

    get disableVerifyButton() {
        return (
            this.isLoading ||
            this.isRefreshing ||
            !this.voterNumber
        );
    }

    get disableRefreshButton() {
        return this.isLoading || this.isRefreshing;
    }

    get disableUpdateButton() {
        return (
            this.isLoading ||
            this.isRefreshing ||
            !this.voterData ||
            this.isUpdated ||
            this.voterVerified ||
            this.verifiedFieldConflict
        );
    }

    get updateButtonLabel() {
        if (this.voterVerified) {
            return 'Voter Already Verified';
        }

        if (this.verifiedFieldConflict) {
            return 'Verified Details Locked';
        }

        if (this.isUpdated && this.lastActionType === 'approval') {
            return 'Approval Submitted';
        }

        if (this.isUpdated && this.lastActionType === 'noChanges') {
            return 'Verification Complete';
        }

        if (this.isUpdated) {
            return 'Voter Updated';
        }

        if (
            this.requiresApproval &&
            this.hasAnyAccountChange
        ) {
            return 'Send for Approval';
        }

        if (!this.hasAnyAccountChange && this.voterData) {
            return 'Review Voter Details';
        }

        return 'Update Voter';
    }

    get updateButtonIcon() {
        if (
            this.requiresApproval &&
            this.hasAnyAccountChange
        ) {
            return 'utility:approval';
        }

        return 'utility:save';
    }

    get updateButtonClass() {
        return (
            this.requiresApproval &&
            this.hasAnyAccountChange
        )
            ? 'update-btn approval-btn'
            : 'update-btn';
    }

    get changesModalTitle() {
        if (this.verifiedFieldConflict) {
            return 'Verified Customer Details Locked';
        }

        if (this.hasConflictingDetails) {
            return 'Voter Details Mismatch';
        }

        if (this.hasAnyAccountChange) {
            return 'Voter Details Review';
        }

        return 'Voter Details Match';
    }

    get changesModalDescription() {
        if (this.verifiedFieldConflict) {
            return 'One or more values returned by Voter verification conflict with Customer fields that are already KYC verified. Verified fields cannot be changed and cannot be sent for approval.';
        }

        if (this.hasConflictingDetails) {
            return 'One or more populated Account values conflict with the verified Voter details. Please review the differences below.';
        }

        if (this.hasAnyAccountChange) {
            return 'The verified Voter details match the existing populated customer information. Blank or new Voter fields can be updated directly after confirmation.';
        }

        return 'All verified Voter details match the details currently available in the Account.';
    }

    get changesProceedButtonLabel() {
        if (
            this.requiresApproval &&
            this.hasAnyAccountChange
        ) {
            return 'Proceed for Approval';
        }

        return 'Continue';
    }

    get changesModalIcon() {
        return this.hasAnyAccountChange
            ? 'utility:error'
            : 'utility:success';
    }

    get changesModalIconClass() {
        return this.hasAnyAccountChange
            ? 'warning-icon-header'
            : 'success-icon-header';
    }

    get showApprovalInfo() {
        return (
            this.requiresApproval &&
            this.hasAnyAccountChange
        );
    }

    /*
     * When customer information matches, all relevant fields are shown
     * for review.
     *
     * When it does not match, only mismatched fields are shown.
     */
    get showNameComparisonRow() {
        return (
            !this.hasAnyAccountChange ||
            this.isNameMismatch
        );
    }

    get showGenderComparisonRow() {
        return (
            !this.hasAnyAccountChange ||
            this.isGenderMismatch
        );
    }

    get showVoterComparisonRow() {
        return (
            !this.hasAnyAccountChange ||
            this.isVoterMismatch
        );
    }

    get genderLabel() {
        return this.formatGenderLabel(
            this.voterData
                ? this.voterData.gender
                : ''
        );
    }

    get accountGenderLabel() {
        return this.formatGenderLabel(this.accountGender);
    }

    get relationTypeLabel() {
        if (
            !this.voterData ||
            !this.voterData.relationType
        ) {
            return '';
        }

        const relationMap = {
            FTHR: 'Father',
            MTHR: 'Mother',
            HUSB: 'Husband',
            WIFE: 'Wife',
            GURD: 'Guardian'
        };

        return (
            relationMap[this.voterData.relationType] ||
            this.voterData.relationType
        );
    }

    get successPopupTitle() {
        if (this.lastActionType === 'noChanges') {
            return 'Voter Details Already Match';
        }

        return 'Voter Updated Successfully';
    }

    get successPopupDescription() {
        if (this.lastActionType === 'noChanges') {
            return 'The verified Voter details already match the Account details. No Account changes were required.';
        }

        return 'The verified Voter name, gender and Voter number have been successfully updated in the customer Account.';
    }

    handleVoterInput(event) {
        this.voterNumber = event.target.value
            ? event.target.value.toUpperCase()
            : '';

        this.voterData = null;
        this.rawVoterData = null;

        this.isUpdated = false;
        this.requiresApproval = false;
        this.lastActionType = '';

        this.resetComparison();
        this.clearMessages();
    }

    async handleRefresh() {
        this.isRefreshing = true;
        this.clearMessages();

        try {
            if (this.wiredAccountResult) {
                await refreshApex(this.wiredAccountResult);
            }

            if (this.recordId) {
                await notifyRecordUpdateAvailable([
                    {
                        recordId: this.recordId
                    }
                ]);
            }

            this.dispatchEvent(new RefreshEvent());

            this.showToast(
                'Success',
                'Customer details refreshed successfully.',
                'success'
            );
        } catch (error) {
            this.errorMessage = this.reduceErrors(error);

            this.showToast(
                'Error',
                this.errorMessage,
                'error'
            );
        } finally {
            this.isRefreshing = false;
        }
    }

    async handleVerifyVoter() {
        this.clearMessages();

        const voterNo = this.normalizeVoterNumber(
            this.voterNumber
        );

        if (!voterNo) {
            this.errorMessage =
                'Please enter Voter / EPIC number.';
            return;
        }

        this.isLoading = true;
        this.voterData = null;
        this.rawVoterData = null;

        this.isUpdated = false;
        this.lastActionType = '';

        this.resetComparison();

        try {
            const response = await verifyVoter({
                voterNumber: voterNo,
                recordId: this.recordId
            });

            if (response && response.success) {
                const rawResponse = JSON.parse(
                    JSON.stringify(response)
                );

                if (!rawResponse.epicNo) {
                    rawResponse.epicNo = voterNo;
                }

                this.rawVoterData = rawResponse;

                this.voterData =
                    this.formatDateFieldsForDisplay(
                        rawResponse
                    );

                this.voterNumber =
                    this.voterData.epicNo || voterNo;

                this.evaluateComparison();

                if (this.voterVerified) {
                    this.successMessage = '';
                    this.errorMessage =
                        'Voter / EPIC details are already KYC verified. No Account update or approval request is allowed.';

                    this.showToast(
                        'Voter Already Verified',
                        this.errorMessage,
                        'info'
                    );

                    return;
                }

                if (this.verifiedFieldConflict) {
                    const lockedFields =
                        this.verifiedFieldConflictFields.join(', ');

                    this.successMessage = '';
                    this.errorMessage =
                        `Already verified Customer field(s) do not match the Voter response: ${lockedFields}. No Account update or approval is allowed.`;

                    this.showToast(
                        'Verified Details Locked',
                        this.errorMessage,
                        'error'
                    );

                    return;
                }

                if (this.requiresApproval) {
                    this.successMessage =
                        'Voter details fetched successfully from Surepass. One or more populated Account values conflict with the verified details, so approval is required.';
                } else if (!this.hasAnyAccountChange) {
                    this.successMessage =
                        'Voter details fetched successfully from Surepass. The verified details already match the Account.';
                } else if (this.hasConflictingDetails) {
                    this.successMessage =
                        'Voter details fetched successfully from Surepass. The changes are eligible for direct update because this is the first or same KYC method and the BC Customer No. is blank.';
                } else {
                    this.successMessage =
                        'Voter details fetched successfully from Surepass. Matching values and blank fields can be updated directly after confirmation.';
                }

                this.showToast(
                    'Success',
                    'Voter details fetched successfully.',
                    'success'
                );
            } else {
                this.errorMessage =
                    response?.message ||
                    'Voter details not found.';

                this.showToast(
                    'Error',
                    this.errorMessage,
                    'error'
                );
            }
        } catch (error) {
            this.errorMessage = this.reduceErrors(error);

            this.showToast(
                'Error',
                this.errorMessage,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleUpdateVoter() {
        this.clearMessages();

        if (!this.recordId) {
            this.errorMessage =
                'Account record Id is missing.';
            return;
        }

        if (!this.voterData) {
            this.errorMessage =
                'Please verify Voter details first.';
            return;
        }

        this.evaluateComparison();
        this.showMismatchPopup = true;
    }

    evaluateComparison() {
        if (!this.voterData) {
            this.resetComparison();
            return;
        }

        const apiName = this.voterData.name || '';
        const accName = this.accountName || '';

        const apiGender =
            this.voterData.gender || '';

        const accGender =
            this.accountGender || '';

        const apiVoter =
            this.voterData.epicNo ||
            this.voterNumber ||
            '';

        const accVoter =
            this.existingVoter || '';

        const normalizedApiName =
            this.cleanExactName(apiName);

        const normalizedAccName =
            this.cleanExactName(accName);

        const normalizedApiGender =
            this.normalizeGender(apiGender);

        const normalizedAccGender =
            this.normalizeGender(accGender);

        const normalizedApiVoter =
            this.normalizeVoterNumber(apiVoter);

        const normalizedAccVoter =
            this.normalizeVoterNumber(accVoter);

        const hasVerifiedName =
            normalizedApiName !== '';

        const hasVerifiedGender =
            normalizedApiGender !== '';

        this.isNameMismatch =
            hasVerifiedName &&
            normalizedApiName !== normalizedAccName;

        this.isGenderMismatch =
            hasVerifiedGender &&
            normalizedApiGender !== normalizedAccGender;

        this.isVoterMismatch =
            normalizedApiVoter !== '' &&
            normalizedApiVoter !== normalizedAccVoter;

        /*
         * Blank Account values are safe to fill. Conflict means a
         * populated Account value disagrees with a populated verified
         * value.
         */
        this.isNameConflict =
            normalizedAccName !== '' &&
            hasVerifiedName &&
            this.isNameMismatch;

        this.isGenderConflict =
            normalizedAccGender !== '' &&
            hasVerifiedGender &&
            this.isGenderMismatch;

        this.isVoterConflict =
            normalizedAccVoter !== '' &&
            this.isVoterMismatch;

        this.hasConflictingDetails =
            this.isNameConflict ||
            this.isGenderConflict ||
            this.isVoterConflict;

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
            this.genderVerified &&
            this.isGenderMismatch
        ) {
            this.verifiedFieldConflictFields.push(
                'Gender'
            );
        }

        if (
            this.voterVerified &&
            this.isVoterMismatch
        ) {
            this.verifiedFieldConflictFields.push(
                'Voter / EPIC Number'
            );
        }

        this.verifiedFieldConflict =
            this.verifiedFieldConflictFields.length > 0;

        this.isCustomerInfoMatch =
            !this.isNameConflict &&
            !this.isGenderConflict;

        this.hasAnyAccountChange =
            this.isNameMismatch ||
            this.isGenderMismatch ||
            this.isVoterMismatch;

        const hasBcCustomerNumber =
            this.bcCustomerId &&
            String(this.bcCustomerId).trim() !== '';

        this.requiresApproval =
            !this.verifiedFieldConflict &&
            this.hasAnyAccountChange &&
            this.hasConflictingDetails &&
            (
                hasBcCustomerNumber ||
                this.differentVerificationMethod
            );

        this.canDirectUpdate =
            !this.verifiedFieldConflict &&
            !this.requiresApproval;

        this.mismatchDetails = {
            accName: accName || 'Blank',
            apiName: apiName || 'Blank',

            accGender:
                this.formatGenderLabel(accGender) ||
                'Blank',

            apiGender:
                this.formatGenderLabel(apiGender) ||
                'Blank',

            accVoter: accVoter || 'Blank',
            apiVoter: apiVoter || 'Blank'
        };
    }

    handleProceedFromChanges() {
        this.showMismatchPopup = false;

        if (this.requiresApproval) {
            this.showApprovalPopup = true;
            return;
        }

        /*
         * Matching details and safe blank-field additions both use the
         * explicit confirmation popup before the final Account update.
         */
        this.showConfirmPopup = true;
    }

    handleConfirmUpdate() {
        this.closeModals();
        this.executeDataSave(false);
    }

    handleSendForApproval() {
        this.closeModals();
        this.executeDataSave(true);
    }

    async executeDataSave(requestApproval) {
        this.clearMessages();

        if (!this.recordId) {
            this.errorMessage =
                'Account record Id is missing.';
            return;
        }

        if (!this.rawVoterData) {
            this.errorMessage =
                'Please verify Voter details first.';
            return;
        }

        this.isLoading = true;

        try {
            /*
             * Apex independently determines the correct action using
             * the latest BC Customer No., existing Customer Verification
             * (KYC) method and populated field conflicts.
             */
            const result =
                await processAccountUpdateAndTracking({
                    recordId: this.recordId,
                    responseJson: JSON.stringify(
                        this.rawVoterData
                    ),
                    trackName: requestApproval
                });

            if (result && result.approvalCreated) {
                this.isUpdated = true;
                this.lastActionType = 'approval';
                this.requiresApproval = true;

                this.successMessage =
                    result.message ||
                    'Approval request submitted successfully.';

                this.showApprovalSubmittedPopup = true;

                this.showToast(
                    'Success',
                    this.successMessage,
                    'success'
                );
            } else if (result && result.accountUpdated) {
                this.isUpdated = true;
                this.lastActionType = 'updated';
                this.requiresApproval = false;

                this.existingVoter =
                    this.rawVoterData.epicNo ||
                    this.existingVoter;

                this.voterNumber =
                    this.rawVoterData.epicNo ||
                    this.voterNumber;

                this.accountName =
                    this.rawVoterData.name ||
                    this.accountName;

                if (this.rawVoterData.gender) {
                    this.accountGender =
                        this.formatGenderLabel(
                            this.rawVoterData.gender
                        );
                }

                this.successMessage =
                    result.message ||
                    'Account Voter details updated successfully.';

                this.showSuccessPopup = true;

                this.showToast(
                    'Success',
                    this.successMessage,
                    'success'
                );
            } else {
                this.isUpdated = true;
                this.lastActionType = 'noChanges';

                this.successMessage =
                    result && result.message
                        ? result.message
                        : 'The verified Voter details already match the Account. No changes were required.';

                this.showSuccessPopup = true;

                this.showToast(
                    'Information',
                    this.successMessage,
                    'info'
                );
            }

            await notifyRecordUpdateAvailable([
                {
                    recordId: this.recordId
                }
            ]);

            if (this.wiredAccountResult) {
                await refreshApex(
                    this.wiredAccountResult
                );
            }

            this.dispatchEvent(new RefreshEvent());
        } catch (error) {
            this.errorMessage = this.reduceErrors(error);

            this.showToast(
                'Error',
                this.errorMessage,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    resetComparison() {
        this.isCustomerInfoMatch = false;
        this.isNameMismatch = false;
        this.isGenderMismatch = false;
        this.isVoterMismatch = false;
        this.hasAnyAccountChange = false;
        this.isNameConflict = false;
        this.isGenderConflict = false;
        this.isVoterConflict = false;
        this.hasConflictingDetails = false;
        this.verifiedFieldConflict = false;
        this.verifiedFieldConflictFields = [];
        this.requiresApproval = false;
        this.mismatchDetails = {};
    }

    closeModals() {
        this.showMismatchPopup = false;
        this.showConfirmPopup = false;
        this.showApprovalPopup = false;
        this.showApprovalSubmittedPopup = false;
        this.showSuccessPopup = false;
    }

    clearMessages() {
        this.successMessage = '';
        this.errorMessage = '';
        this.closeModals();
    }

    normalizeVoterNumber(value) {
        return value
            ? String(value).trim().toUpperCase()
            : '';
    }

    cleanExactName(value) {
        let name = (value || '')
            .toString()
            .toUpperCase();

        name = name.replace(/&/g, ' AND ');
        name = name.replace(/[^A-Z0-9\s]/g, ' ');
        name = name.replace(/\s+/g, ' ').trim();
        name = name.replace(
            /^(M\s*S|MS|MESSRS|MESSERS)\s+/g,
            ''
        );

        name = name.replace(/\bMR\b/g, '');
        name = name.replace(/\bMRS\b/g, '');
        name = name.replace(/\bSHRI\b/g, '');
        name = name.replace(/\bSMT\b/g, '');
        name = name.replace(/\bSRI\b/g, '');
        name = name.replace(/\s+/g, ' ').trim();

        return name;
    }

    normalizeGender(value) {
        if (!value) {
            return '';
        }

        const genderValue = String(value)
            .trim()
            .toLowerCase();

        if (
            genderValue === 'm' ||
            genderValue === 'male'
        ) {
            return 'male';
        }

        if (
            genderValue === 'f' ||
            genderValue === 'female'
        ) {
            return 'female';
        }

        if (
            genderValue === 't' ||
            genderValue === 'trans' ||
            genderValue === 'transgender'
        ) {
            return 'transgender';
        }

        if (
            genderValue === 'o' ||
            genderValue === 'other' ||
            genderValue === 'others'
        ) {
            return 'other';
        }

        return genderValue;
    }

    formatGenderLabel(value) {
        const normalizedGender =
            this.normalizeGender(value);

        if (normalizedGender === 'male') {
            return 'Male';
        }

        if (normalizedGender === 'female') {
            return 'Female';
        }

        if (normalizedGender === 'transgender') {
            return 'Transgender';
        }

        if (normalizedGender === 'other') {
            return 'Other';
        }

        return value
            ? String(value).trim()
            : '';
    }

    formatDateFieldsForDisplay(data) {
        if (!data) {
            return data;
        }

        if (Array.isArray(data)) {
            return data.map((item) =>
                this.formatDateFieldsForDisplay(item)
            );
        }

        if (typeof data === 'object') {
            const formattedData = {};

            Object.keys(data).forEach((key) => {
                const value = data[key];

                if (
                    value &&
                    typeof value === 'object'
                ) {
                    formattedData[key] =
                        this.formatDateFieldsForDisplay(
                            value
                        );
                } else if (
                    this.shouldFormatAsDate(key, value)
                ) {
                    formattedData[key] =
                        this.formatDateDDMMYYYY(value);
                } else {
                    formattedData[key] = value;
                }
            });

            return formattedData;
        }

        return data;
    }

    shouldFormatAsDate(key, value) {
        if (!value || typeof value !== 'string') {
            return false;
        }

        const keyName = key
            ? key.toLowerCase()
            : '';

        const valueText = value.trim();

        const isDateKey =
            keyName.includes('date') ||
            keyName.includes('update');

        const isDateValue =
            /^\d{4}-\d{2}-\d{2}$/.test(valueText) ||
            /^\d{4}-\d{2}-\d{2}T/.test(valueText) ||
            /^\d{4}-\d{2}-\d{2}\s/.test(valueText) ||
            /^\d{2}-\d{2}-\d{4}$/.test(valueText) ||
            /^\d{2}\/\d{2}\/\d{4}$/.test(valueText) ||
            /^\d{4}\/\d{2}\/\d{2}$/.test(valueText);

        return isDateKey && isDateValue;
    }

    formatDateDDMMYYYY(value) {
        if (!value) {
            return '';
        }

        let dateValue = String(value).trim();

        /*
         * Removes both ISO and space-separated time portions.
         */
        if (dateValue.includes('T')) {
            dateValue = dateValue.split('T')[0];
        } else if (dateValue.includes(' ')) {
            dateValue = dateValue.split(' ')[0];
        }

        if (/^\d{2}\/\d{2}\/\d{4}$/.test(dateValue)) {
            return dateValue;
        }

        if (/^\d{4}-\d{2}-\d{2}$/.test(dateValue)) {
            const parts = dateValue.split('-');

            return `${parts[2]}/${parts[1]}/${parts[0]}`;
        }

        if (/^\d{4}\/\d{2}\/\d{2}$/.test(dateValue)) {
            const parts = dateValue.split('/');

            return `${parts[2]}/${parts[1]}/${parts[0]}`;
        }

        if (/^\d{2}-\d{2}-\d{4}$/.test(dateValue)) {
            return dateValue.replace(/-/g, '/');
        }

        return dateValue;
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

    reduceErrors(error) {
        if (!error) {
            return 'Unknown error occurred.';
        }

        if (Array.isArray(error.body)) {
            return error.body
                .map((item) => item.message)
                .join(', ');
        }

        if (
            error.body &&
            typeof error.body.message === 'string'
        ) {
            return error.body.message;
        }

        if (typeof error.message === 'string') {
            return error.message;
        }

        return 'Unknown error occurred.';
    }
}