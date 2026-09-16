import { LightningElement, api, track } from 'lwc';
import getAccountInitialData from '@salesforce/apex/ctrl_PanVerificationController.getAccountInitialData';
import verifyPan from '@salesforce/apex/ctrl_PanVerificationController.verifyPan';
import updateAccountPan from '@salesforce/apex/ctrl_PanVerificationController.updateAccountPan';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { RefreshEvent } from 'lightning/refresh';

export default class PanVerification extends LightningElement {
    @api recordId;

    @track panNumber = '';
    @track panDetails;
    @track errorMessage = '';

    @track accountPan = '';
    @track accountName = '';
    @track accountDob = null;
    @track accountGender = '';
    @track accountStatus = '';
    @track bcCustomerNo = '';
    @track customerVerificationKyc = '';
    @track differentVerificationMethod = false;

    /*
     * Apex calculates the final action from the latest Account data.
     * Account Status is not checked. BC Customer No., the existing KYC
     * method and populated field conflicts determine approval.
     */
    canDirectUpdate = false;

    showMismatchModal = false;
    showConfirmModal = false;
    showApprovalModal = false;
    showApprovalSubmittedModal = false;
    showSuccessModal = false;

    isExactMatch = false;
    isPanMismatch = false;
    isNameMismatch = false;
    isDobMismatch = false;
    isGenderMismatch = false;

    isPanConflict = false;
    isNameConflict = false;
    isDobConflict = false;
    isGenderConflict = false;
    hasConflictingDetails = false;
    requiresApproval = false;

    isLoading = false;
    isInitialLoading = true;
    isRefreshing = false;
    showSuccess = false;
    showError = false;
    canShowComponent = false;
    initialValidationMessage = '';

    get formattedAccountDob() {
        return this.formatDobForDisplay(this.accountDob);
    }

    get formattedPanDob() {
        return this.formatDobForDisplay(
            this.panDetails ? this.panDetails.dob : null
        );
    }

    formatDobForDisplay(value) {
        if (!value) {
            return '';
        }

        let dateValue = String(value).trim();

        /*
         * Remove any time portion, for example:
         * 1994-02-18 00:00:00
         * 1994-02-18T00:00:00.000Z
         */
        if (dateValue.includes('T')) {
            dateValue = dateValue.split('T')[0];
        } else if (dateValue.includes(' ')) {
            dateValue = dateValue.split(' ')[0];
        }

        // yyyy-mm-dd → dd/mm/yyyy
        if (/^\d{4}-\d{2}-\d{2}$/.test(dateValue)) {
            const parts = dateValue.split('-');
            return `${parts[2]}/${parts[1]}/${parts[0]}`;
        }

        // dd-mm-yyyy → dd/mm/yyyy
        if (/^\d{2}-\d{2}-\d{4}$/.test(dateValue)) {
            return dateValue.replace(/-/g, '/');
        }

        // Already dd/mm/yyyy
        if (/^\d{2}\/\d{2}\/\d{4}$/.test(dateValue)) {
            return dateValue;
        }

        return dateValue;
    }

    connectedCallback() {
        this.loadAccountInitialData();
    }

    loadAccountInitialData() {
        if (!this.recordId) {
            this.isInitialLoading = false;
            this.canShowComponent = false;
            this.canDirectUpdate = false;
            this.initialValidationMessage = 'Account Id not found.';
            return Promise.resolve();
        }

        return getAccountInitialData({ accountId: this.recordId })
            .then(result => {
                if (result) {
                    this.panNumber = result.panNumber || '';
                    this.accountPan = result.panNumber || '';
                    this.accountName = result.accountName || '';
                    this.accountDob = result.dateOfBirth;
                    this.accountGender = result.accountGender || '';
                    this.accountStatus = result.accountStatus || '';
                    this.bcCustomerNo = result.bcCustomerNo || '';
                    this.customerVerificationKyc =
                        result.customerVerificationKyc || '';
                    this.differentVerificationMethod =
                        result.differentVerificationMethod === true;
                    this.canDirectUpdate = result.directUpdateAllowed === true;
                    this.canShowComponent = result.canShowComponent;
                    this.initialValidationMessage = result.validationMessage;
                }
            })
            .catch(error => {
                this.canShowComponent = false;
                this.canDirectUpdate = false;
                this.initialValidationMessage = this.getErrorMessage(error);
            })
            .finally(() => {
                this.isInitialLoading = false;
            });
    }

    async handleRefresh() {
        this.isRefreshing = true;
        this.errorMessage = '';
        this.showError = false;

        try {
            await this.loadAccountInitialData();

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
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isRefreshing = false;
        }
    }

    handlePanChange(event) {
        this.panNumber = event.target.value
            ? event.target.value.toUpperCase()
            : '';

        this.panDetails = null;
        this.showSuccess = false;
        this.showError = false;
        this.errorMessage = '';

        this.resetComparisonFlags();
    }

    handleVerifyPan() {
        if (!this.panNumber) {
            this.showToast('Error', 'Please enter PAN number.', 'error');
            return;
        }

        this.isLoading = true;
        this.panDetails = null;
        this.showSuccess = false;
        this.showError = false;
        this.errorMessage = '';

        this.resetComparisonFlags();

        verifyPan({ panNumber: this.panNumber })
            .then(result => {
                if (result && result.success && result.data) {
                    this.panDetails = result.data;
                    this.panNumber = result.data.pan_number;
                    this.showSuccess = true;
                    this.showError = false;
                } else {
                    this.errorMessage =
                        result && result.message
                            ? result.message
                            : 'PAN details not found.';

                    this.showError = true;
                    this.showSuccess = false;
                }
            })
            .catch(error => {
                this.errorMessage = this.getErrorMessage(error);
                this.showError = true;
                this.showSuccess = false;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleUpdatePan() {
        if (!this.recordId) {
            this.showToast('Error', 'Record Id not found.', 'error');
            return;
        }

        if (!this.panDetails || !this.panDetails.pan_number) {
            this.showToast('Error', 'Please verify PAN first.', 'error');
            return;
        }

        const accPanNorm = this.normalizePan(this.accountPan);
        const apiPanNorm = this.normalizePan(this.panDetails.pan_number);

        const accNameNorm = this.normalizeName(this.accountName);
        const apiNameNorm = this.normalizeName(this.panDetails.full_name);

        const accDobNorm = this.normalizeDateForCompare(this.accountDob);
        const apiDobNorm = this.normalizeDateForCompare(this.panDetails.dob);

        const accGenderNorm = this.normalizeGender(this.accountGender);
        const apiGenderNorm = this.normalizeGender(this.panDetails.gender);

        const hasVerifiedName = apiNameNorm !== '';
        const hasVerifiedDob = apiDobNorm !== '';
        const hasVerifiedGender = apiGenderNorm !== '';

        this.isPanMismatch =
            apiPanNorm !== '' &&
            accPanNorm !== apiPanNorm;

        this.isNameMismatch =
            hasVerifiedName &&
            accNameNorm !== apiNameNorm;

        this.isDobMismatch =
            hasVerifiedDob &&
            accDobNorm !== apiDobNorm;

        this.isGenderMismatch =
            hasVerifiedGender &&
            accGenderNorm !== apiGenderNorm;

        /*
         * Blank Account values are safe to fill and therefore are not
         * conflicts. A conflict exists only when both values are populated
         * and different.
         */
        this.isPanConflict =
            accPanNorm !== '' &&
            this.isPanMismatch;

        this.isNameConflict =
            accNameNorm !== '' &&
            hasVerifiedName &&
            this.isNameMismatch;

        this.isDobConflict =
            accDobNorm !== '' &&
            hasVerifiedDob &&
            this.isDobMismatch;

        this.isGenderConflict =
            accGenderNorm !== '' &&
            hasVerifiedGender &&
            this.isGenderMismatch;

        this.hasConflictingDetails =
            this.isPanConflict ||
            this.isNameConflict ||
            this.isDobConflict ||
            this.isGenderConflict;

        const hasAnyAccountChange =
            this.isPanMismatch ||
            this.isNameMismatch ||
            this.isDobMismatch ||
            this.isGenderMismatch;

        const hasBcCustomerNumber =
            this.normalizeTextValue(this.bcCustomerNo) !== '';

        /*
         * Status is not checked.
         *
         * BC blank:
         * - first/same KYC can update;
         * - after another KYC, only populated conflicting values require
         *   approval.
         *
         * BC available:
         * - populated conflicting values require approval;
         * - blank fields may be filled directly.
         */
        this.requiresApproval =
            hasAnyAccountChange &&
            this.hasConflictingDetails &&
            (
                hasBcCustomerNumber ||
                this.differentVerificationMethod
            );

        this.canDirectUpdate = !this.requiresApproval;

        this.isExactMatch =
            !this.isNameMismatch &&
            !this.isDobMismatch &&
            !this.isGenderMismatch;

        if (hasAnyAccountChange) {
            this.showMismatchModal = true;
        } else {
            this.proceedWithStatusCheck();
        }
    }

    closeAllModals() {
        this.showMismatchModal = false;
        this.showConfirmModal = false;
        this.showApprovalModal = false;
        this.showApprovalSubmittedModal = false;
        this.showSuccessModal = false;
    }

    handleProceedUpdate() {
        this.proceedWithStatusCheck();
    }

    proceedWithStatusCheck() {
        this.showMismatchModal = false;
        this.showConfirmModal = false;
        this.showApprovalModal = false;

        if (this.requiresApproval) {
            this.showApprovalModal = true;
            return;
        }

        /*
         * Every permitted Account update, including filling a blank field,
         * requires the explicit final confirmation.
         */
        this.showConfirmModal = true;
    }

    handleConfirmUpdate() {
        this.closeAllModals();
        this.executeApexUpdate(false);
    }

    handleSendForApproval() {
        this.closeAllModals();
        this.executeApexUpdate(true);
    }

    async executeApexUpdate(createApprovalRecord) {
        this.isLoading = true;

        const dobToUpdate = this.panDetails
            ? this.panDetails.dob
            : null;

        const nameToUpdate = this.panDetails
            ? this.panDetails.full_name
            : null;

        const genderToUpdate = this.panDetails
            ? this.panDetails.gender
            : null;

        try {
            const result = await updateAccountPan({
                accountId: this.recordId,
                panNumber: this.panDetails.pan_number,
                createApprovalRecord: createApprovalRecord,
                newDob: dobToUpdate,
                newName: nameToUpdate,
                newGender: genderToUpdate
            });

            await this.loadAccountInitialData();

            await notifyRecordUpdateAvailable([
                {
                    recordId: this.recordId
                }
            ]);

            this.dispatchEvent(new RefreshEvent());

            if (result && result.approvalCreated) {
                this.showApprovalSubmittedModal = true;

                this.showToast(
                    'Success',
                    result.message ||
                    'Approval request submitted successfully.',
                    'success'
                );
            } else if (result && result.noChanges) {
                this.showToast(
                    'Information',
                    result.message ||
                    'The verified PAN details already match the Account.',
                    'info'
                );
            } else if (
                result &&
                result.accountUpdated &&
                this.isExactMatch
            ) {
                this.showSuccessModal = true;
            } else {
                this.showToast(
                    'Success',
                    result && result.message
                        ? result.message
                        : 'Account details updated successfully.',
                    'success'
                );
            }

            this.isExactMatch = false;
        } catch (error) {
            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    resetComparisonFlags() {
        this.isExactMatch = false;
        this.isPanMismatch = false;
        this.isNameMismatch = false;
        this.isDobMismatch = false;
        this.isGenderMismatch = false;
        this.isPanConflict = false;
        this.isNameConflict = false;
        this.isDobConflict = false;
        this.isGenderConflict = false;
        this.hasConflictingDetails = false;
        this.requiresApproval = false;
    }

    normalizeTextValue(value) {
        return value
            ? String(value).trim()
            : '';
    }

    normalizePan(value) {
        return value
            ? String(value).trim().toUpperCase()
            : '';
    }

    normalizeName(value) {
        return value
            ? String(value)
                .trim()
                .toLowerCase()
                .replace(/\s+/g, ' ')
            : '';
    }

    normalizeGender(value) {
        if (!value) {
            return '';
        }

        const genderValue = String(value)
            .trim()
            .toLowerCase();

        if (genderValue === 'm' || genderValue === 'male') {
            return 'male';
        }

        if (genderValue === 'f' || genderValue === 'female') {
            return 'female';
        }

        if (
            genderValue === 't' ||
            genderValue === 'transgender' ||
            genderValue === 'trans'
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

    normalizeDateForCompare(value) {
        if (!value) {
            return '';
        }

        let dateValue = String(value).trim();

        if (/^\d{4}-\d{2}-\d{2}$/.test(dateValue)) {
            return dateValue;
        }

        if (/^\d{2}[-/]\d{2}[-/]\d{4}$/.test(dateValue)) {
            const separator = dateValue.includes('-')
                ? '-'
                : '/';

            const parts = dateValue.split(separator);

            return `${parts[2]}-${parts[1]}-${parts[0]}`;
        }

        return dateValue;
    }

    get aadhaarLinkedText() {
        if (!this.panDetails) {
            return '';
        }

        return this.panDetails.aadhaar_linked
            ? 'Yes'
            : 'No';
    }

    get disableRefreshButton() {
        return (
            this.isLoading ||
            this.isInitialLoading ||
            this.isRefreshing
        );
    }

    getErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Something went wrong.';
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