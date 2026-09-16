import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { CurrentPageReference } from 'lightning/navigation';
import FORM_FACTOR from '@salesforce/client/formFactor';

import getApprovalForm
    from '@salesforce/apex/Ctrl_OrientCustomerProfileChange.getApprovalForm';
import submitProfileChanges
    from '@salesforce/apex/Ctrl_OrientCustomerProfileChange.submitProfileChangesWithAddress';
import checkDuplicateMobileNumber
    from '@salesforce/apex/Ctrl_OrientCustomerProfileChange.checkDuplicateMobileNumber';
import refreshApprovalForm
    from '@salesforce/apex/Ctrl_OrientCustomerProfileChange.refreshApprovalForm';
import linkSupportingDocuments
    from '@salesforce/apex/Ctrl_OrientCustomerProfileChange.linkSupportingDocuments';
import removeSupportingDocument
    from '@salesforce/apex/Ctrl_OrientCustomerProfileChange.removeSupportingDocument';

export default class LwcOrientCustomerSendForApprovalAction extends LightningElement {
    _recordId;
    initializedRecordId;
    recordContextTimer;
    mobileValidationSequence = 0;

    @track sections = [];
    @track approvalFields = [];
    @track configurationWarnings = [];
    @track changedFieldApis = [];
    @track uploadedSupportingFiles = [];

    changedValues = {};
    addressSelectionValues = {};
    addressSelectionSummary = '';
    showAddressSelector = false;

    customerName = '';
    changeReason = '';
    reasonError = '';


    loadError = '';
    isLoading = false;
    isSubmitting = false;
    isCheckingMobile = false;
    isRefreshingData = false;
    isLoadingDocuments = false;
    isRemovingDocument = false;

    showSupportingDocumentPreview = false;
    supportingDocumentPreviewFiles = [];
    supportingDocumentPreviewSelectedId;

    @api
    set recordId(value) {
        if (!value || value === this._recordId) {
            return;
        }

        this._recordId = value;
        this.clearRecordContextTimer();
        this.initializeForRecord();
    }

    get recordId() {
        return this._recordId;
    }

    @wire(CurrentPageReference)
    wiredPageReference(pageRef) {
        const pageRecordId =
            pageRef?.attributes?.recordId ||
            pageRef?.state?.recordId;

        if (pageRecordId && !this._recordId) {
            this.recordId = pageRecordId;
        }
    }

    connectedCallback() {
        this.recordContextTimer = window.setTimeout(() => {
            if (!this._recordId) {
                this.isLoading = false;
                this.loadError =
                    'Unable to identify the Customer record. Close this action and open it again.';
            }
        }, 3000);
    }

    disconnectedCallback() {
        this.clearRecordContextTimer();
    }

    clearRecordContextTimer() {
        if (this.recordContextTimer) {
            window.clearTimeout(this.recordContextTimer);
            this.recordContextTimer = null;
        }
    }

    initializeForRecord() {
        if (!this._recordId || this.initializedRecordId === this._recordId) {
            return;
        }

        this.initializedRecordId = this._recordId;
        this.loadApprovalForm();
    }

    get isWaitingForRecord() {
        return !this._recordId && !this.loadError;
    }

    get showSpinner() {
        return (
            this.isLoading ||
            this.isSubmitting ||
            this.isWaitingForRecord
        );
    }

    get hasLoadError() {
        return Boolean(this.loadError);
    }

    get showContent() {
        return !this.isLoading && !this.isWaitingForRecord && !this.hasLoadError;
    }

    get headerTitle() {
        return 'Customer Profile Change Approval';
    }

    get headerSubtitle() {
        return 'Submit locked customer fields through the configured approval hierarchy';
    }

    get allowMultipleFileUpload() {
        return FORM_FACTOR === 'Large';
    }

    get supportingUploadRecordId() {
        return undefined;
    }

    get hasUploadedSupportingFiles() {
        return this.uploadedSupportingFiles.length > 0;
    }

    get supportingDocumentButtonLabel() {
        return 'Preview Uploaded Documents';
    }

    get refreshButtonLabel() {
        return this.isRefreshingData
            ? 'Refreshing...'
            : 'Refresh Data';
    }

    get hasApprovalFields() {
        return this.approvalFields.length > 0;
    }

    get hasEditableFields() {
        return this.approvalFields.some(
            field =>
                field.editableForApproval === true ||
                field.addressApiOnly === true
        );
    }

    get hasStandardApprovalFields() {
        return this.approvalFields.some(
            field =>
                field.sectionName !== 'Address'
        );
    }

    get hasAddressApprovalFields() {
        return this.approvalFields.some(
            field =>
                field.sectionName === 'Address'
        );
    }

    get addressManualFields() {
        return this.approvalFields
            .filter(
                field =>
                    field.sectionName === 'Address' &&
                    field.addressApiOnly !== true
            )
            .map(field => ({
                ...field,
                requestedInputWrapClass:
                    `address-request-input-wrap${field.isChanged ? ' address-request-input-wrap-changed' : ''}`
            }));
    }

    get addressApiApprovalFields() {
        return this.approvalFields.filter(
            field =>
                field.sectionName === 'Address' &&
                field.addressApiOnly === true
        );
    }

    get visibleAddressApiFields() {
        const hiddenAddressUiFields =
            new Set([
                'Country__c',
                'StateCode__c',
                'Country_Region_Code__c'
            ]);

        const preferredOrder = [
            'Pin_Code__c',
            'Residential_City__c',
            'Village__c',
            'District__c',
            'State_Province__c'
        ];

        return this.addressApiApprovalFields
            .filter(
                field =>
                    !hiddenAddressUiFields.has(
                        field.accountFieldApi
                    )
            )
            .map(field => ({
                ...field,
                addressApiTileClass:
                    `bc-address-tile${field.isChanged ? ' bc-address-tile-changed' : ''}`,
                addressRequestedDisplayValue:
                    this.hasSelectedAddress
                        ? field.requestedDisplayValue
                        : 'Select from BC',
                addressRequestedValueClass:
                    `bc-value-text requested-bc-value${field.isChanged ? ' requested-bc-value-changed' : ''}`
            }))
            .sort((left, right) => {
                const leftIndex =
                    preferredOrder.indexOf(
                        left.accountFieldApi
                    );
                const rightIndex =
                    preferredOrder.indexOf(
                        right.accountFieldApi
                    );

                const normalizedLeft =
                    leftIndex === -1
                        ? 999
                        : leftIndex;
                const normalizedRight =
                    rightIndex === -1
                        ? 999
                        : rightIndex;

                if (
                    normalizedLeft !==
                    normalizedRight
                ) {
                    return normalizedLeft -
                        normalizedRight;
                }

                return Number(
                    left.sequence || 0
                ) - Number(
                    right.sequence || 0
                );
            });
    }

    get addressSelectorStatusLabel() {
        return this.hasSelectedAddress
            ? 'BC address selected'
            : 'Select the verified location from Business Central';
    }

    get quickActionPanelClass() {
        if (FORM_FACTOR === 'Medium') {
            return 'orient-quick-action-panel orient-quick-action-panel-tablet';
        }

        if (FORM_FACTOR === 'Small') {
            return 'orient-quick-action-panel orient-quick-action-panel-mobile';
        }

        return 'orient-quick-action-panel orient-quick-action-panel-desktop';
    }

    get isTabletFormFactor() {
        return FORM_FACTOR === 'Medium';
    }

    get addressUiClass() {
        return FORM_FACTOR === 'Large'
            ? 'address-ui address-ui-desktop'
            : 'address-ui address-ui-mobile';
    }

    get addressComparisonClass() {
        return FORM_FACTOR === 'Large'
            ? 'address-comparison address-comparison-desktop'
            : 'address-comparison address-comparison-mobile';
    }

    get addressLocationGridClass() {
        return FORM_FACTOR === 'Large'
            ? 'address-location-grid address-location-grid-desktop'
            : 'address-location-grid address-location-grid-mobile';
    }

    get isMobileAddressUi() {
        return FORM_FACTOR !== 'Large';
    }

    get currentAddressPinCode() {
        const pinField =
            this.approvalFields.find(
                field =>
                    field.accountFieldApi ===
                    'Pin_Code__c'
            );

        return pinField?.currentRawValue ||
            '';
    }

    get hasSelectedAddress() {
        return Object.keys(
            this.addressSelectionValues || {}
        ).length > 0;
    }

    get addressSelectorButtonLabel() {
        return this.hasSelectedAddress
            ? 'Change Selected Address'
            : 'Select New Address';
    }

    get hasWarnings() {
        return this.configurationWarnings.length > 0;
    }

    get warningLabel() {
        const count = this.configurationWarnings.length;
        return count === 1
            ? '1 field configuration warning'
            : `${count} field configuration warnings`;
    }

    get fieldCountLabel() {
        const total = this.approvalFields.length;
        const editable =
            this.approvalFields.filter(
                field =>
                    field.editableForApproval === true ||
                    field.addressApiOnly === true
            ).length;

        return `${editable} available of ${total}`;
    }

    get changedCount() {
        return this.changedFieldApis.length;
    }

    get changeCountLabel() {
        const count = this.changedCount;
        return `${count} change${count === 1 ? '' : 's'} selected`;
    }

    get hasFieldValidationError() {
        return this.approvalFields.some(field => Boolean(field.validationMessage));
    }

    get disableSubmit() {
        return (
            this.isLoading ||
            this.isSubmitting ||
            this.isCheckingMobile ||
            !this.hasEditableFields ||
            this.changedCount === 0 ||
            this.hasFieldValidationError
        );
    }

    get submitButtonLabel() {
        return this.isSubmitting ? 'Sending...' : 'Send For Approval';
    }

    get reasonCardClass() {
        return this.reasonError
            ? 'reason-card reason-card-error'
            : 'reason-card';
    }

    get footerStatus() {
        return this.changeCountLabel;
    }

    async loadApprovalForm() {
        this.isLoading = true;
        this.loadError = '';
        this.customerName = '';
        this.changeReason = '';
        this.reasonError = '';
        this.sections = [];
        this.approvalFields = [];
        this.configurationWarnings = [];
        this.changedFieldApis = [];
        this.changedValues = {};
        this.addressSelectionValues = {};
        this.addressSelectionSummary = '';
        this.showAddressSelector = false;
        this.isCheckingMobile = false;
        this.mobileValidationSequence++;

        try {
            const formResult =
                await getApprovalForm({
                    accountId: this._recordId
                });

            this.applyApprovalFormResult(
                formResult
            );
        } catch (error) {
            this.loadError =
                this.reduceError(error);

            this.showToast(
                'Unable to Load Customer Approval',
                this.loadError,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    applyApprovalFormResult(formResult) {
        this.customerName =
            formResult?.accountName ||
            'Customer';

        this.configurationWarnings =
            formResult?.configurationWarnings ||
            [];

        const rows =
            (formResult?.fields || []).map(
                row => ({
                    ...row,
                    verified:
                        row.verified === true,
                    editableForApproval:
                        row.editableForApproval === true,
                    addressApiOnly:
                        row.addressApiOnly === true,
                    currentDisplayValue:
                        row.currentDisplayValue || '—',
                    currentRawValue:
                        row.currentRawValue ?? '',
                    lockedMessage:
                        row.verified === true
                            ? 'Verified and locked'
                            : 'Not available for approval change',
                    isChanged: false,
                    validationMessage: '',
                    isValidating: false,
                    cardClass:
                        'change-card',
                    requestedPanelClass:
                        'value-panel requested-panel',
                    requestedDisplayValue:
                        '—'
                })
            );

        this.approvalFields = rows;
        this.sections =
            this.buildSections(rows);
    }

    buildSections(rows) {
        const sectionMap = new Map();

        rows.forEach(row => {
            const sectionName =
                row.sectionName ||
                'Customer Profile';

            if (!sectionMap.has(sectionName)) {
                sectionMap.set(
                    sectionName,
                    {
                        key:
                            this.toSectionKey(
                                sectionName
                            ),
                        label:
                            sectionName,
                        isAddressSection:
                            sectionName ===
                            'Address',
                        fields: []
                    }
                );
            }

            const hiddenAddressUiFields =
                new Set([
                    'Country__c',
                    'StateCode__c',
                    'Country_Region_Code__c'
                ]);

            if (
                sectionName === 'Address' &&
                hiddenAddressUiFields.has(
                    row.accountFieldApi
                )
            ) {
                return;
            }

            sectionMap
                .get(sectionName)
                .fields
                .push(row);
        });

        return Array.from(
            sectionMap.values()
        );
    }

    toSectionKey(value) {
        return String(value || 'customer-profile')
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/^-|-$/g, '');
    }

    handleOpenAddressSelector() {
        this.showAddressSelector =
            true;
    }

    handleCancelAddressSelector() {
        this.showAddressSelector =
            false;
    }

    handleClearAddressSelection() {
        const addressFieldApis =
            new Set(
                this.addressApiApprovalFields.map(
                    field =>
                        field.accountFieldApi
                )
            );

        const nextValues = {
            ...this.changedValues
        };

        addressFieldApis.forEach(
            fieldApi => {
                delete nextValues[
                    fieldApi
                ];
            }
        );

        this.changedValues =
            nextValues;
        this.changedFieldApis =
            this.changedFieldApis.filter(
                fieldApi =>
                    !addressFieldApis.has(
                        fieldApi
                    )
            );
        this.addressSelectionValues =
            {};
        this.addressSelectionSummary =
            '';
        this.showAddressSelector =
            false;

        this.refreshChangeIndicators();
    }

    handleAddressSelected(event) {
        const selectedValues =
            event.detail?.values ||
            {};

        const addressFields =
            this.addressApiApprovalFields;

        const changedSet =
            new Set(
                this.changedFieldApis
            );
        const nextValues = {
            ...this.changedValues
        };

        addressFields.forEach(
            field => {
                const fieldApi =
                    field.accountFieldApi;

                if (
                    !Object.prototype.hasOwnProperty.call(
                        selectedValues,
                        fieldApi
                    )
                ) {
                    return;
                }

                const newValue =
                    selectedValues[
                        fieldApi
                    ];

                const changed =
                    this.normalizeComparable(
                        field,
                        newValue
                    ) !==
                    this.normalizeComparable(
                        field,
                        field.currentRawValue
                    );

                if (changed) {
                    changedSet.add(
                        fieldApi
                    );
                    nextValues[
                        fieldApi
                    ] =
                        newValue;
                } else {
                    changedSet.delete(
                        fieldApi
                    );
                    delete nextValues[
                        fieldApi
                    ];
                }
            }
        );

        this.changedValues =
            nextValues;
        this.changedFieldApis =
            Array.from(
                changedSet
            );
        this.addressSelectionValues = {
            ...selectedValues
        };
        this.addressSelectionSummary =
            event.detail?.summary ||
            '';
        this.showAddressSelector =
            false;

        this.refreshChangeIndicators();

        const addressChangeCount =
            addressFields.filter(
                field =>
                    changedSet.has(
                        field.accountFieldApi
                    )
            ).length;

        if (addressChangeCount === 0) {
            this.showToast(
                'No Address Change Detected',
                'The selected Business Central address matches the current approval-controlled address values.',
                'info'
            );
            return;
        }

        this.showToast(
            'Address Selected',
            `${addressChangeCount} address field${addressChangeCount === 1 ? '' : 's'} changed and will be included in this approval request.`,
            'success'
        );
    }

    async handleFieldChange(event) {
        const fieldApi =
            event.target?.dataset?.fieldApi ||
            event.currentTarget?.dataset?.fieldApi;

        if (!fieldApi) {
            return;
        }

        const field = this.approvalFields.find(
            item => item.accountFieldApi === fieldApi
        );

        if (!field || field.editableForApproval !== true) {
            return;
        }

        const rawValue = event.detail?.value !== undefined
            ? event.detail.value
            : event.target?.value;

        const newValue =
            this.normalizeInputComponentValue(
                field,
                rawValue
            );

        this.changedValues = {
            ...this.changedValues,
            [fieldApi]: newValue
        };

        const changed =
            this.normalizeComparable(field, newValue) !==
            this.normalizeComparable(field, field.currentRawValue);

        const changedSet = new Set(this.changedFieldApis);

        if (changed) {
            changedSet.add(fieldApi);
        } else {
            changedSet.delete(fieldApi);
            const nextValues = { ...this.changedValues };
            delete nextValues[fieldApi];
            this.changedValues = nextValues;
        }

        this.changedFieldApis = Array.from(changedSet);

        if (this.isDuplicateContactField(fieldApi)) {
            this.mobileValidationSequence++;
            this.isCheckingMobile = false;
            this.updateFieldState(fieldApi, {
                validationMessage: '',
                isValidating: false
            });
        } else {
            this.clearFieldValidation(fieldApi);
        }

        this.refreshChangeIndicators();

        if (
            this.isDuplicateContactField(fieldApi) &&
            changed
        ) {
            await this.validateMobileNumber(
                fieldApi,
                newValue
            );
        }
    }

    isDuplicateContactField(fieldApi) {
        return (
            fieldApi === 'Phone' ||
            fieldApi === 'Whatsapp_number__c'
        );
    }

    getDuplicateContactLabel(fieldApi) {
        return fieldApi === 'Whatsapp_number__c'
            ? 'WhatsApp number'
            : 'Phone number';
    }

    async validateMobileNumber(fieldApi, value) {
        const normalizedMobile =
            this.normalizeValue(
                fieldApi,
                value
            );

        const validationSequence =
            ++this.mobileValidationSequence;

        const fieldLabel =
            this.getDuplicateContactLabel(
                fieldApi
            );

        if (!normalizedMobile) {
            this.isCheckingMobile = false;
            this.updateFieldState(fieldApi, {
                validationMessage: '',
                isValidating: false
            });
            this.refreshChangeIndicators();
            return;
        }

        if (
            String(normalizedMobile).length !==
            10
        ) {
            this.isCheckingMobile = false;
            this.updateFieldState(fieldApi, {
                validationMessage:
                    `${fieldLabel} must contain exactly 10 digits.`,
                isValidating: false
            });
            this.refreshChangeIndicators();
            return;
        }

        this.isCheckingMobile = true;
        this.updateFieldState(fieldApi, {
            validationMessage: '',
            isValidating: true
        });
        this.refreshChangeIndicators();

        try {
            const result =
                await checkDuplicateMobileNumber({
                    accountId:
                        this._recordId,
                    mobileNumber:
                        normalizedMobile
                });

            if (
                validationSequence !==
                this.mobileValidationSequence
            ) {
                return;
            }

            if (result?.duplicateFound) {
                const customerName =
                    result.customerName ||
                    'another customer';

                const message =
                    `A customer already exists with this ${fieldLabel.toLowerCase()}: "${customerName}". ` +
                    `Please enter a different ${fieldLabel.toLowerCase()}.`;

                this.updateFieldState(
                    fieldApi,
                    {
                        validationMessage:
                            message,
                        isValidating:
                            false
                    }
                );

                this.showToast(
                    fieldApi ===
                        'Whatsapp_number__c'
                        ? 'Duplicate WhatsApp Number'
                        : 'Duplicate Phone Number',
                    message,
                    'error'
                );
            } else {
                this.updateFieldState(
                    fieldApi,
                    {
                        validationMessage: '',
                        isValidating: false
                    }
                );
            }
        } catch (error) {
            if (
                validationSequence !==
                this.mobileValidationSequence
            ) {
                return;
            }

            this.updateFieldState(
                fieldApi,
                {
                    validationMessage:
                        this.reduceError(error),
                    isValidating:
                        false
                }
            );
        } finally {
            if (
                validationSequence ===
                this.mobileValidationSequence
            ) {
                this.isCheckingMobile =
                    false;
                this.refreshChangeIndicators();
            }
        }
    }

    updateFieldState(fieldApi, updates) {
        this.approvalFields =
            this.approvalFields.map(field =>
                field.accountFieldApi === fieldApi
                    ? { ...field, ...updates }
                    : field
            );
    }

    clearFieldValidation(fieldApi) {
        this.updateFieldState(fieldApi, {
            validationMessage: '',
            isValidating: false
        });
    }

    refreshChangeIndicators() {
        const changedSet =
            new Set(this.changedFieldApis);

        const rows =
            this.approvalFields.map(field => {
                const isChanged =
                    changedSet.has(field.accountFieldApi);

                let requestedPanelClass =
                    'value-panel requested-panel';

                if (field.validationMessage) {
                    requestedPanelClass +=
                        ' requested-panel-error';
                } else if (isChanged) {
                    requestedPanelClass +=
                        ' requested-panel-changed';
                }

                const changedValue =
                    Object.prototype.hasOwnProperty.call(
                        this.changedValues,
                        field.accountFieldApi
                    )
                        ? this.changedValues[
                            field.accountFieldApi
                        ]
                        : null;

                return {
                    ...field,
                    isChanged,
                    requestedDisplayValue:
                        isChanged
                            ? (
                                changedValue === undefined ||
                                changedValue === null ||
                                changedValue === ''
                                    ? '—'
                                    : String(
                                        changedValue
                                    )
                            )
                            : '—',
                    cardClass: isChanged
                        ? 'change-card change-card-changed'
                        : 'change-card',
                    requestedPanelClass
                };
            });

        this.approvalFields = rows;
        this.sections = this.buildSections(rows);
    }

    handleReasonInput(event) {
        this.changeReason =
            event.detail?.value ??
            event.target?.value ??
            '';

        if (this.changeReason.trim()) {
            this.reasonError = '';
        }
    }

    async handleRefreshData() {
        if (this.isRefreshingData) {
            return;
        }

        this.isRefreshingData = true;
        this.isLoading = true;
        this.addressSelectionValues = {};
        this.addressSelectionSummary = '';
        this.showAddressSelector = false;

        try {
            const formResult =
                await refreshApprovalForm({
                    accountId:
                        this._recordId
                });

            this.applyApprovalFormResult(
                formResult
            );

            this.showToast(
                'Data Refreshed',
                'Customer Profile approval data was refreshed from Salesforce.',
                'success'
            );
        } catch (error) {
            this.showToast(
                'Refresh Failed',
                this.reduceError(error),
                'error'
            );
        } finally {
            this.isLoading = false;
            this.isRefreshingData = false;
        }
    }

    buildDocumentDisplayName(documentInfo) {
        const title =
            documentInfo?.title ||
            'Supporting Document';

        const extension =
            documentInfo?.fileExtension;

        if (
            extension &&
            !title.toLowerCase().endsWith(
                `.${String(extension).toLowerCase()}`
            )
        ) {
            return `${title}.${extension}`;
        }

        return title;
    }

    handlePreviewSupportingFile(event) {
        const documentId =
            event.currentTarget?.dataset
                ?.documentId;

        if (!documentId) {
            return;
        }

        this.openSupportingDocumentPreview(
            this.uploadedSupportingFiles,
            documentId
        );
    }

    async handleRemoveSupportingFile(event) {
        const documentId =
            event.currentTarget?.dataset
                ?.documentId;

        if (
            !documentId ||
            this.isRemovingDocument
        ) {
            return;
        }

        const file =
            this.uploadedSupportingFiles.find(
                item =>
                    item.documentId ===
                    documentId
            );

        this.isRemovingDocument = true;

        try {
            await removeSupportingDocument({
                requestId: null,
                contentDocumentId:
                    documentId
            });

            this.uploadedSupportingFiles =
                this.uploadedSupportingFiles.filter(
                    item =>
                        item.documentId !==
                        documentId
                );

            this.showToast(
                'Supporting Document Removed',
                `${file?.name || 'The file'} was removed.`,
                'success'
            );
        } catch (error) {
            this.showToast(
                'Unable to Remove Document',
                this.reduceError(error),
                'error'
            );
        } finally {
            this.isRemovingDocument = false;
        }
    }

    handleSupportingUploadFinished(event) {
        const uploadedFiles =
            event.detail?.files || [];

        if (!uploadedFiles.length) {
            return;
        }

        const existingIds =
            new Set(
                this.uploadedSupportingFiles.map(
                    file => file.documentId
                )
            );

        const newFiles = [
            ...this.uploadedSupportingFiles
        ];

        uploadedFiles.forEach(file => {
            if (
                file.documentId &&
                !existingIds.has(file.documentId)
            ) {
                newFiles.push({
                    name: file.name,
                    documentId: file.documentId
                });

                existingIds.add(
                    file.documentId
                );
            }
        });

        this.uploadedSupportingFiles =
            newFiles;

        this.showToast(
            'Supporting Document Uploaded',
            `${uploadedFiles.length} supporting document(s) uploaded successfully.`,
            'success'
        );
    }

    async handlePreviewSupportingDocuments() {
        if (this.isLoadingDocuments) {
            return;
        }

        this.isLoadingDocuments = true;

        try {
            const documents =
                [...this.uploadedSupportingFiles];

            if (!documents.length) {
                this.showToast(
                    'No Supporting Documents',
                    'No supporting document is currently available to preview.',
                    'info'
                );
                return;
            }

            this.openSupportingDocumentPreview(
                documents,
                documents[0]?.contentDocumentId ||
                    documents[0]?.documentId
            );
        } catch (error) {
            this.showToast(
                'Unable to Preview Documents',
                this.reduceError(error),
                'error'
            );
        } finally {
            this.isLoadingDocuments = false;
        }
    }

    openSupportingDocumentPreview(
        documents,
        selectedDocumentId
    ) {
        const normalizedDocuments =
            (documents || [])
                .map(item => ({
                    ...item,
                    contentDocumentId:
                        item.contentDocumentId ||
                        item.documentId,
                    name:
                        item.name ||
                        this.buildDocumentDisplayName(
                            item
                        )
                }))
                .filter(
                    item =>
                        Boolean(
                            item.contentDocumentId
                        )
                );

        if (!normalizedDocuments.length) {
            return;
        }

        this.supportingDocumentPreviewFiles =
            normalizedDocuments;
        this.supportingDocumentPreviewSelectedId =
            selectedDocumentId ||
            normalizedDocuments[0].contentDocumentId;
        this.showSupportingDocumentPreview = true;
    }

    handleCloseSupportingDocumentPreview() {
        this.showSupportingDocumentPreview = false;
        this.supportingDocumentPreviewFiles = [];
        this.supportingDocumentPreviewSelectedId = null;
    }

    handleRetry() {
        if (!this._recordId) {
            this.loadError =
                'Customer record context is still unavailable. Close this action and open it again.';
            return;
        }

        this.initializedRecordId = null;
        this.initializeForRecord();
    }

    closeAction() {
        this.dispatchEvent(
            new CustomEvent(
                'closemobileaction',
                {
                    bubbles: true,
                    composed: true
                }
            )
        );

        this.dispatchEvent(
            new CloseActionScreenEvent()
        );
    }

    handleCancel() {
        if (this.isSubmitting) {
            return;
        }

        this.dispatchEvent(
            new CloseActionScreenEvent()
        );
    }

    async handleSubmit() {
        if (this.disableSubmit) {
            return;
        }

        try {
            const reasonInput =
                this.template.querySelector(
                    'lightning-textarea[data-id="changeReason"]'
                );

            const submittedReason =
                String(
                    reasonInput?.value ||
                    this.changeReason ||
                    ''
                ).trim();

            this.changeReason =
                submittedReason;

            if (!submittedReason) {
                this.reasonError =
                    'Enter a Change Reason before sending this request for approval.';

                if (reasonInput?.focus) {
                    reasonInput.focus();
                }

                this.showToast(
                    'Change Reason Required',
                    this.reasonError,
                    'error'
                );

                return;
            }

            this.reasonError = '';

            if (this.hasFieldValidationError) {
                this.showToast(
                    'Correct Field Errors',
                    'Correct the highlighted field validation errors before sending for approval.',
                    'error'
                );
                return;
            }

            const payload = {};

            this.changedFieldApis.forEach(fieldApi => {
                if (
                    Object.prototype.hasOwnProperty.call(
                        this.changedValues,
                        fieldApi
                    )
                ) {
                    payload[fieldApi] =
                        this.normalizeValue(
                            fieldApi,
                            this.changedValues[fieldApi]
                        );
                    return;
                }

                const input =
                    this.template.querySelector(
                        `lightning-input-field[data-field-api="${fieldApi}"]`
                    );

                if (input) {
                    payload[fieldApi] =
                        this.normalizeValue(
                            fieldApi,
                            input.value
                        );
                }
            });

            if (Object.keys(payload).length === 0) {
                this.showToast(
                    'No Changes Selected',
                    'Change at least one locked Customer field before sending for approval.',
                    'warning'
                );
                return;
            }

            this.isSubmitting = true;

            const result =
                await submitProfileChanges({
                    accountId: this._recordId,
                    changesJson: JSON.stringify(payload),
                    reason: submittedReason,
                    addressSelectionJson:
                        this.hasSelectedAddress
                            ? JSON.stringify(
                                this.addressSelectionValues
                            )
                            : null
                });

            if (
                this.uploadedSupportingFiles.length &&
                result?.requestId
            ) {
                try {
                    await linkSupportingDocuments({
                        requestId:
                            result.requestId,
                        contentDocumentIds:
                            this.uploadedSupportingFiles.map(
                                file => file.documentId
                            )
                    });
                } catch (documentError) {
                    this.showToast(
                        'Approval Submitted - Document Link Warning',
                        'The approval request was submitted, but one or more supporting documents could not be linked to the Change Request. ' +
                            this.reduceError(documentError),
                        'warning'
                    );
                }
            }

            const approverText =
                result?.pendingWithName
                    ? ` Pending with ${result.pendingWithName}.`
                    : '';

            this.showToast(
                'Sent For Approval',
                `${result?.message ||
                    'Customer Profile change request created successfully.'}${approverText}`,
                'success'
            );

            this.closeAction();
        } catch (error) {
            this.showToast(
                'Customer Approval Submission Failed',
                this.reduceError(error),
                'error'
            );
        } finally {
            this.isSubmitting = false;
        }
    }

    normalizeInputComponentValue(field, value) {
        if (!Array.isArray(value)) {
            return value;
        }

        const fieldType =
            String(field?.fieldDataType || '').toUpperCase();

        if (
            fieldType === 'REFERENCE' ||
            fieldType === 'ID'
        ) {
            return value.length
                ? value[0]
                : null;
        }

        if (fieldType === 'MULTIPICKLIST') {
            return value.join(';');
        }

        return value;
    }

    deserializeStoredValue(rawValue, fieldDataType) {
        if (
            rawValue === undefined ||
            rawValue === null ||
            rawValue === ''
        ) {
            return null;
        }

        const fieldType =
            String(fieldDataType || '').toUpperCase();

        if (fieldType === 'BOOLEAN') {
            return String(rawValue).toLowerCase() === 'true';
        }

        if (
            fieldType === 'CURRENCY' ||
            fieldType === 'DOUBLE' ||
            fieldType === 'INTEGER' ||
            fieldType === 'LONG' ||
            fieldType === 'PERCENT'
        ) {
            const numberValue = Number(rawValue);
            return Number.isNaN(numberValue)
                ? rawValue
                : numberValue;
        }

        return rawValue;
    }

    normalizeComparable(field, value) {
        if (
            value === undefined ||
            value === null ||
            value === ''
        ) {
            return '';
        }

        const normalized =
            this.normalizeValue(
                field.accountFieldApi,
                value
            );

        if (Array.isArray(normalized)) {
            return normalized.join(';');
        }

        const fieldType =
            String(
                field.fieldDataType || ''
            ).toUpperCase();

        if (
            fieldType === 'CURRENCY' ||
            fieldType === 'DOUBLE' ||
            fieldType === 'INTEGER' ||
            fieldType === 'LONG' ||
            fieldType === 'PERCENT'
        ) {
            const numberValue =
                Number(normalized);

            return Number.isNaN(numberValue)
                ? String(normalized)
                : String(numberValue);
        }

        if (fieldType === 'BOOLEAN') {
            return String(
                normalized === true ||
                normalized === 'true'
            );
        }

        return String(normalized).trim();
    }

    normalizeValue(fieldApi, value) {
        if (
            value === undefined ||
            value === null
        ) {
            return null;
        }

        if (
            fieldApi === 'PAN__c' ||
            fieldApi === 'GST__c'
        ) {
            return String(value)
                .trim()
                .toUpperCase();
        }

        if (
            fieldApi === 'Phone' ||
            fieldApi ===
                'Whatsapp_number__c' ||
            fieldApi ===
                'AadharNo__c'
        ) {
            return String(value)
                .replace(/\D/g, '');
        }

        return value;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
                mode:
                    variant === 'error'
                        ? 'sticky'
                        : 'dismissable'
            })
        );
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body
                .map(item => item.message)
                .filter(Boolean)
                .join(', ');
        }

        const pageErrors =
            error?.body?.output?.errors || [];

        if (pageErrors.length) {
            return pageErrors
                .map(item => item.message)
                .filter(Boolean)
                .join(', ');
        }

        const fieldErrors =
            error?.body?.output?.fieldErrors || {};

        const fieldMessages =
            Object.values(fieldErrors)
                .flat()
                .map(item => item.message)
                .filter(Boolean);

        if (fieldMessages.length) {
            return fieldMessages.join(', ');
        }

        return (
            error?.body?.message ||
            error?.message ||
            'An unexpected error occurred while processing the Customer Profile approval.'
        );
    }
}