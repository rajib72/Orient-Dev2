import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import {
    registerRefreshHandler,
    unregisterRefreshHandler,
    RefreshEvent
} from 'lightning/refresh';

import {
    getRecord,
    getFieldValue,
    notifyRecordUpdateAvailable
} from 'lightning/uiRecordApi';

import getTrackingRecord
    from '@salesforce/apex/Ctrl_CustomerDetailRecordPage.getTrackingRecord';

import checkDuplicateAccount
    from '@salesforce/apex/Ctrl_CustomerDetailRecordPage.checkDuplicateAccount';

import mergeAndInactiveAccount
    from '@salesforce/apex/Ctrl_CustomerDetailRecordPage.mergeAndInactiveAccount';

// Verification fields
import AADHAAR_VERIFIED
    from '@salesforce/schema/Account.Aadhaar_Verified__c';

import DOB_VERIFIED
    from '@salesforce/schema/Account.DOB_Verified__c';

import GSTIN_VERIFIED
    from '@salesforce/schema/Account.GSTIN_Verified__c';

import NAME_VERIFIED
    from '@salesforce/schema/Account.Name_Verified__c';

import PAN_VERIFIED
    from '@salesforce/schema/Account.PAN_Verified__c';

import VOTER_VERIFIED
    from '@salesforce/schema/Account.Voter_Verified__c';

import GENDER_VERIFIED
    from '@salesforce/schema/Account.Gender_Verified__c';

// KYC fields
import CUSTOMER_VERIFICATION_KYC
    from '@salesforce/schema/Account.Customer_Verification_KYC__c';

import KYC_VERIFIED
    from '@salesforce/schema/Account.KYC_Verified__c';

const VERIFICATION_FIELDS = [
    AADHAAR_VERIFIED,
    DOB_VERIFIED,
    GSTIN_VERIFIED,
    NAME_VERIFIED,
    PAN_VERIFIED,
    VOTER_VERIFIED,
    GENDER_VERIFIED,
    CUSTOMER_VERIFICATION_KYC,
    KYC_VERIFIED
];

const VERIFIED_FIELD_MAP = {
    AadharNo__c: 'Aadhaar_Verified__c',
    Date_Of_Birth__c: 'DOB_Verified__c',
    GST__c: 'GSTIN_Verified__c',
    Name: 'Name_Verified__c',
    PAN__c: 'PAN_Verified__c',
    Voter__c: 'Voter_Verified__c',
    Gender__c: 'Gender_Verified__c',
    Customer_Verification_KYC__c: 'Customer_Verification_KYC__c',
    KYC_Verified__c: 'KYC_Verified__c'
};

/*
 * These Salesforce Date fields use a custom text input in edit mode.
 * The user enters DD/MM/YYYY, while Salesforce receives YYYY-MM-DD.
 */
const MANUAL_DATE_FIELD_CONFIG = {
    Date_Of_Birth__c: {
        label: 'Date of Birth'
    },
    Anniversary_Date__c: {
        label: 'Anniversary Date'
    }
};

export default class Lwc_CustomerDetailRecordPage extends LightningElement {
    @api recordId;

    isEditMode = false;
    isDataLoaded = false;
    isRefreshing = false;

    @track showDuplicateModal = false;
    @track duplicateModalStep = 1;
    @track duplicateName = '';
    @track duplicatePhone = '';

    duplicateAccountId = '';

    @track currentGender = '';
    @track currentLanguage = '';
    @track verificationFlags = {};
    @track formSections = [];
    @track manualDateValues = {};

    loadedManualDateValues = {};
    trackingData = null;
    isTrackingSuccess = false;

    wiredTrackingResult;
    wiredAccountVerificationResult;
    refreshHandlerId;

    rawSections = [
        {
            id: 'basic',
            label: 'Basic Information',
            left: [
                {
                    accountApi: 'Customer_Type__c',
                    trackingApi: 'Customer_Type__c'
                },
                {
                    accountApi: 'Title__c',
                    trackingApi: 'Title__c'
                },
                {
                    accountApi: 'Name',
                    trackingApi: 'Customer_Name__c'
                },
                {
                    accountApi: 'Gender__c',
                    trackingApi: 'Gender__c'
                },
                {
                    accountApi: 'Gender_Other__c',
                    trackingApi: 'Gender_Other__c'
                }
            ],
            right: [
                {
                    accountApi: 'OwnerId',
                    trackingApi: 'Customer_Owner__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'ParentId',
                    trackingApi: 'Parent_Customer__c'
                },
                {
                    accountApi: 'BC_Customer_No__c',
                    trackingApi: 'BC_Customer_No__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'Primary_Customer__c',
                    trackingApi: 'Primary_Customer__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'Salesforce_Customer_No__c',
                    trackingApi: 'Salesforce_Customer_No__c',
                    isAlwaysReadonly: true
                }
            ]
        },
        {
            id: 'personal',
            label: 'Personal Details',
            left: [
                {
                    accountApi: 'Date_Of_Birth__c',
                    trackingApi: 'Date_Of_Birth_DOB__c',
                    isManualDate: true
                },
                {
                    accountApi: 'Preferred_Language__c',
                    trackingApi: 'Preferred_Language__c'
                },
                {
                    accountApi: 'Preferred_Language_Other__c',
                    trackingApi: 'Preferred_Language_Other__c'
                },
                {
                    accountApi: 'Preferred_Store__c',
                    trackingApi: 'Preferred_Store__c'
                },
                {
                    accountApi: 'PAN__c',
                    trackingApi: 'PAN__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'Voter__c',
                    trackingApi: 'Voter__c',
                    isAlwaysReadonly: true
                }
            ],
            right: [
                {
                    accountApi: 'Marital_Status__c',
                    trackingApi: 'Marital_Status__c'
                },
                {
                    accountApi: 'Anniversary_Date__c',
                    trackingApi: 'Anniversary_Date__c',
                    isManualDate: true
                },
                {
                    accountApi: 'Nationality__c',
                    trackingApi: 'Nationality__c'
                },
                {
                    accountApi: 'GST__c',
                    trackingApi: 'GST__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'AadharNo__c',
                    trackingApi: 'AadharNo__c'
                }
            ]
        },
        {
            id: 'contact',
            label: 'Contact Information',
            left: [
                {
                    accountApi: 'Phone',
                    trackingApi: 'Phone__c'
                },
                {
                    accountApi: 'Email_Address__c',
                    trackingApi: 'Email_Address__c'
                },
                {
                    accountApi: 'Preferred_Communication_Channel__c',
                    trackingApi: 'Preferred_Communication_Channel__c'
                }
            ],
            right: [
                {
                    accountApi: 'Whatsapp_number__c',
                    trackingApi: 'Whatsapp_number__c'
                },
                {
                    accountApi: 'Preferred_Contact_Time__c',
                    trackingApi: 'Preferred_Contact_Time__c'
                }
            ]
        },
        {
            id: 'preferences',
            label: 'Customer Preferences',
            left: [
                {
                    accountApi: 'Occupation_Profession__c',
                    trackingApi: 'Occupation_Profession__c'
                },
                {
                    accountApi: 'Preferred_Sales_Executive__c',
                    trackingApi: 'Preferred_Sales_Executive__c'
                },
                {
                    accountApi: 'Preferred_Gift_Wrapping__c',
                    trackingApi: 'Preferred_Gift_Wrapping__c'
                }
            ],
            right: [
                {
                    accountApi: 'Family_Type__c',
                    trackingApi: 'Family_Type__c'
                },
                {
                    accountApi: 'Decision_Maker__c',
                    trackingApi: 'Decision_Maker__c'
                }
            ]
        },
        {
            id: 'remarks',
            label: 'Remarks',
            left: [
                {
                    accountApi: 'Description',
                    trackingApi: 'Description__c'
                }
            ],
            right: []
        },
        {
            id: 'address',
            label: 'Address',
            left: [
                {
                    accountApi: 'Permanent_Address__c',
                    trackingApi: 'Permanent_Address__c'
                },
                {
                    accountApi: 'Landmark__c',
                    trackingApi: 'Landmark__c'
                },
                {
                    accountApi: 'Village__c',
                    trackingApi: 'Village__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'State_Province__c',
                    trackingApi: 'State_Province__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'Pin_Code__c',
                    trackingApi: 'Pin_Code__c',
                    isAlwaysReadonly: true
                }
            ],
            right: [
                {
                    accountApi: 'Locality_Area__c',
                    trackingApi: 'Locality_Area__c'
                },
                {
                    accountApi: 'Residential_City__c',
                    trackingApi: 'Residential_City__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'District__c',
                    trackingApi: 'District__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'Country__c',
                    trackingApi: 'Country__c',
                    isAlwaysReadonly: true
                }
            ]
        },
        {
            id: 'additional',
            label: 'Additional Details',
            left: [
                {
                    accountApi: 'Consent_for_Marketing_Communications__c',
                    trackingApi: 'Consent_for_Marketing_Communications__c'
                },
                {
                    accountApi: 'Buying_Intent__c',
                    trackingApi: 'Buying_Intent__c'
                },
                {
                    accountApi: 'Registration_Mode__c',
                    trackingApi: 'Registration_Mode__c'
                },
                {
                    accountApi: 'Age_Group__c',
                    trackingApi: 'Age_Group__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'Loyalty_Tier__c',
                    trackingApi: 'Loyalty_Tier__c'
                },
                {
                    accountApi: 'Customer_Verification_KYC__c',
                    trackingApi: 'Customer_Verification_KYC__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'KYC_Verified__c',
                    trackingApi: 'KYC_Verified__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'Income_Band__c',
                    trackingApi: 'Income_Band__c'
                },
                {
                    accountApi: 'Customer_Notes__c',
                    trackingApi: 'Customer_Notes__c'
                }
            ],
            right: [
                {
                    accountApi: 'Total_Purchased_Amount_Roll__c',
                    trackingApi: 'Total_Purchased_Amount__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'Date_of_First_Purchase__c',
                    trackingApi: 'Date_of_First_Purchase__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'Date_of_Last_Purchase__c',
                    trackingApi: 'Date_of_Last_Purchase__c',
                    isAlwaysReadonly: true
                },
                {
                    accountApi: 'Lead_Source_Detail__c',
                    trackingApi: 'Lead_Source_Detail__c'
                },
                {
                    accountApi: 'Referral_Source__c',
                    trackingApi: 'Referral_Source__c'
                },
                {
                    accountApi: 'Preferred_Price_Band_Weight__c',
                    trackingApi: 'Preferred_Price_Band__c'
                },
                {
                    accountApi: 'Customer_Source_Acquisition__c',
                    trackingApi: 'Customer_Source_Acquisition__c'
                },
                {
                    accountApi: 'Tags_Customer_Labels__c',
                    trackingApi: 'Tags_Customer_Labels__c'
                },
                {
                    accountApi: 'Do_Not_Contact_DNC_Status__c',
                    trackingApi: 'Do_Not_Contact_DNC_Status__c'
                }
            ]
        }
    ];

    get isStep1() {
        return this.duplicateModalStep === 1;
    }

    connectedCallback() {
        this.refreshHandlerId = registerRefreshHandler(
            this,
            this.refreshHandler.bind(this)
        );
    }

    disconnectedCallback() {
        if (this.refreshHandlerId) {
            unregisterRefreshHandler(this.refreshHandlerId);
        }
    }

    refreshHandler() {
        return this.refreshPageData();
    }

    async refreshPageData() {
        try {
            this.isDataLoaded = false;

            const refreshPromises = [];

            // Refresh Apex tracking record
            if (this.wiredTrackingResult) {
                refreshPromises.push(
                    refreshApex(this.wiredTrackingResult)
                );
            }

            /*
             * Refresh Lightning Data Service Account data.
             * This refreshes verification fields and record forms.
             */
            if (this.recordId) {
                refreshPromises.push(
                    notifyRecordUpdateAvailable([
                        {
                            recordId: this.recordId
                        }
                    ])
                );
            }

            await Promise.all(refreshPromises);

            this.buildSections();
        } catch (error) {
            console.error('Refresh Error:', error);
            throw error;
        } finally {
            this.isDataLoaded = true;
        }
    }

    async handleManualRefresh() {
        if (this.isRefreshing) {
            return;
        }

        this.isRefreshing = true;

        try {
            await this.refreshPageData();
            this.dispatchEvent(new RefreshEvent());

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Refreshed',
                    message: 'Customer data refreshed successfully.',
                    variant: 'success'
                })
            );
        } catch (error) {
            console.error('Manual Refresh Error:', error);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Refresh Failed',
                    message:
                        error?.body?.message ||
                        error?.message ||
                        'Unable to refresh customer data.',
                    variant: 'error'
                })
            );
        } finally {
            this.isRefreshing = false;
        }
    }

    @wire(getTrackingRecord, {
        accountId: '$recordId'
    })
    wiredTracking(result) {
        this.wiredTrackingResult = result;

        const { error, data } = result;

        if (data) {
            this.trackingData = data;
            this.isTrackingSuccess = true;
        } else if (error) {
            console.error('Tracking Error:', error);

            this.trackingData = null;
            this.isTrackingSuccess = false;
        } else {
            this.trackingData = null;
            this.isTrackingSuccess = false;
        }

        this.buildSections();
        this.isDataLoaded = true;
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: VERIFICATION_FIELDS
    })
    wiredAccountVerification(result) {
        this.wiredAccountVerificationResult = result;

        const { error, data } = result;

        if (data) {
            const customerVerificationKycValue = getFieldValue(
                data,
                CUSTOMER_VERIFICATION_KYC
            );

            this.verificationFlags = {
                Aadhaar_Verified__c:
                    getFieldValue(data, AADHAAR_VERIFIED) === true,

                DOB_Verified__c:
                    getFieldValue(data, DOB_VERIFIED) === true,

                GSTIN_Verified__c:
                    getFieldValue(data, GSTIN_VERIFIED) === true,

                Name_Verified__c:
                    getFieldValue(data, NAME_VERIFIED) === true,

                PAN_Verified__c:
                    getFieldValue(data, PAN_VERIFIED) === true,

                Voter_Verified__c:
                    getFieldValue(data, VOTER_VERIFIED) === true,

                Gender_Verified__c:
                    getFieldValue(data, GENDER_VERIFIED) === true,

                Customer_Verification_KYC__c:
                    customerVerificationKycValue !== null &&
                    customerVerificationKycValue !== undefined &&
                    String(customerVerificationKycValue).trim() !== '',

                KYC_Verified__c:
                    getFieldValue(data, KYC_VERIFIED) === true
            };

            this.buildSections();
        } else if (error) {
            console.error(
                'Verification Fields Error:',
                error
            );

            this.verificationFlags = {};
            this.buildSections();
        }
    }

    handleFormLoad(event) {
        let fields;

        if (
            event.detail.records &&
            event.detail.records[this.recordId]
        ) {
            fields =
                event.detail.records[this.recordId].fields;
        } else if (
            event.detail.record &&
            event.detail.record.fields
        ) {
            fields = event.detail.record.fields;
        }

        if (fields) {
            this.currentGender =
                fields.Gender__c?.value || '';

            this.currentLanguage =
                fields.Preferred_Language__c?.value || '';

            const loadedDateValues = {
                ...this.manualDateValues
            };

            let hasLoadedManualDateField = false;

            Object.keys(MANUAL_DATE_FIELD_CONFIG).forEach(
                fieldApi => {
                    if (
                        Object.prototype.hasOwnProperty.call(
                            fields,
                            fieldApi
                        )
                    ) {
                        loadedDateValues[fieldApi] =
                            this.formatSalesforceDateForDisplay(
                                fields[fieldApi]?.value
                            );

                        hasLoadedManualDateField = true;
                    }
                }
            );

            /*
             * The view form contains the date output fields and supplies
             * their values. The edit form uses custom text inputs, so its
             * load event may not include those date fields. In that case,
             * keep the values already loaded by the view form.
             */
            if (hasLoadedManualDateField) {
                this.manualDateValues = {
                    ...loadedDateValues
                };

                this.loadedManualDateValues = {
                    ...loadedDateValues
                };
            }

            this.buildSections();
        }
    }

    handleFieldChange(event) {
        const fieldName = event.target.fieldName;
        const value = event.target.value;

        let requiresRebuild = false;

        if (fieldName === 'Gender__c') {
            this.currentGender = value;
            requiresRebuild = true;
        } else if (
            fieldName === 'Preferred_Language__c'
        ) {
            this.currentLanguage = value;
            requiresRebuild = true;
        }

        if (requiresRebuild) {
            this.buildSections();
        }
    }


    handleManualDateInput(event) {
        const inputComponent = event.currentTarget;
        const fieldName = inputComponent.dataset.fieldName;

        const formattedValue =
            this.formatManualDateWhileTyping(
                inputComponent.value
            );

        /*
         * lightning-input fires change while the user types.
         * Keep both the component value and the rendered field model
         * synchronized so the input immediately displays DD/MM/YYYY.
         */
        inputComponent.value = formattedValue;

        this.manualDateValues = {
            ...this.manualDateValues,
            [fieldName]: formattedValue
        };

        this.formSections = this.formSections.map(section => ({
            ...section,
            left: section.left.map(field =>
                field.accountApi === fieldName
                    ? {
                        ...field,
                        manualDateValue: formattedValue
                    }
                    : field
            ),
            right: section.right.map(field =>
                field.accountApi === fieldName
                    ? {
                        ...field,
                        manualDateValue: formattedValue
                    }
                    : field
            )
        }));
    }

    formatManualDateWhileTyping(value) {
        const digits = String(value || '')
            .replace(/\D/g, '')
            .substring(0, 8);

        if (digits.length <= 2) {
            return digits;
        }

        if (digits.length <= 4) {
            return `${digits.substring(0, 2)}/${digits.substring(2)}`;
        }

        return `${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4)}`;
    }

    formatSalesforceDateForDisplay(value) {
        if (!value) {
            return '';
        }

        const match = String(value).match(
            /^(\d{4})-(\d{2})-(\d{2})$/
        );

        if (!match) {
            return '';
        }

        return `${match[3]}/${match[2]}/${match[1]}`;
    }

    convertDisplayDateToSalesforceDate(
        displayValue,
        fieldLabel
    ) {
        const normalizedValue =
            String(displayValue || '').trim();

        if (!normalizedValue) {
            return {
                isValid: true,
                value: null
            };
        }

        const match = normalizedValue.match(
            /^(\d{2})\/(\d{2})\/(\d{4})$/
        );

        if (!match) {
            return {
                isValid: false,
                message:
                    `${fieldLabel} must be entered in DD/MM/YYYY format.`
            };
        }

        const day = Number(match[1]);
        const month = Number(match[2]);
        const year = Number(match[3]);

        const isLeapYear =
            year % 400 === 0 ||
            (year % 4 === 0 && year % 100 !== 0);

        const daysInMonth = [
            31,
            isLeapYear ? 29 : 28,
            31,
            30,
            31,
            30,
            31,
            31,
            30,
            31,
            30,
            31
        ];

        const isValidCalendarDate =
            year >= 1 &&
            month >= 1 &&
            month <= 12 &&
            day >= 1 &&
            day <= daysInMonth[month - 1];

        if (!isValidCalendarDate) {
            return {
                isValid: false,
                message:
                    `${fieldLabel} contains an invalid calendar date.`
            };
        }

        return {
            isValid: true,
            value: `${match[3]}-${match[2]}-${match[1]}`
        };
    }

    applyManualDatesToFields(fields) {
        for (
            const fieldApi of
            Object.keys(MANUAL_DATE_FIELD_CONFIG)
        ) {
            /*
             * Preserve the existing verified-field locking behaviour.
             */
            if (this.isAccountFieldVerified(fieldApi)) {
                if (
                    Object.prototype.hasOwnProperty.call(
                        fields,
                        fieldApi
                    )
                ) {
                    delete fields[fieldApi];
                }

                continue;
            }

            const fieldConfig =
                MANUAL_DATE_FIELD_CONFIG[fieldApi];

            const conversionResult =
                this.convertDisplayDateToSalesforceDate(
                    this.manualDateValues[fieldApi],
                    fieldConfig.label
                );

            if (!conversionResult.isValid) {
                return conversionResult;
            }

            fields[fieldApi] = conversionResult.value;
        }

        return {
            isValid: true
        };
    }

    isAccountFieldVerified(accountApi) {
        const verificationApi =
            VERIFIED_FIELD_MAP[accountApi];

        return verificationApi
            ? this.verificationFlags[verificationApi] === true
            : false;
    }

    buildSections() {
        const data = this.trackingData;
        const isDataSuccess = this.isTrackingSuccess;

        this.formSections = this.rawSections.map(section => {
            const existingSection =
                this.formSections.find(
                    existingItem =>
                        existingItem.id === section.id
                );

            const isOpen = existingSection
                ? existingSection.isOpen
                : true;

            const processFields = fields => {
                return fields.map(field => {
                    let isVisible = true;

                    if (
                        field.accountApi ===
                        'Gender_Other__c'
                    ) {
                        isVisible =
                            this.currentGender === 'Other';
                    } else if (
                        field.accountApi ===
                        'Preferred_Language_Other__c'
                    ) {
                        isVisible =
                            this.currentLanguage === 'Other';
                    }

                    const isVerified =
                        this.isAccountFieldVerified(
                            field.accountApi
                        );

                    const isTrackingReadonly =
                        isDataSuccess && data
                            ? data[field.trackingApi] === true
                            : false;

                    const isGenderVerified =
                        this.isAccountFieldVerified(
                            'Gender__c'
                        );

                    /*
                     * If Gender is verified, Gender Other
                     * must also remain locked.
                     */
                    const isGenderDependentFieldLocked =
                        field.accountApi ===
                        'Gender_Other__c' &&
                        isGenderVerified;

                    const isReadonly =
                        field.isAlwaysReadonly === true ||
                        isTrackingReadonly ||
                        isVerified ||
                        isGenderDependentFieldLocked;

                    const baseViewClass =
                        'customer-field-row';

                    const baseEditWrapperClass =
                        'customer-field-row';

                    return {
                        ...field,
                        isReadonly,
                        isVerified,
                        isVisible,
                        viewClass: isVisible
                            ? baseViewClass
                            : `${baseViewClass} slds-hide`,
                        editWrapperClass: isVisible
                            ? baseEditWrapperClass
                            : `${baseEditWrapperClass} slds-hide`,
                        editClass: '',
                        manualDateLabel: field.isManualDate
                            ? MANUAL_DATE_FIELD_CONFIG[
                                field.accountApi
                            ]?.label
                            : '',
                        manualDateValue: field.isManualDate
                            ? this.manualDateValues[
                            field.accountApi
                            ] || ''
                            : ''
                    };
                });
            };

            return {
                ...section,
                left: processFields(section.left),
                right: processFields(section.right),
                isOpen,
                isHidden: !isOpen,
                sectionClass: isOpen
                    ? 'slds-section slds-is-open'
                    : 'slds-section',
                iconName: isOpen
                    ? 'utility:chevrondown'
                    : 'utility:chevronright'
            };
        });
    }

    toggleSection(event) {
        const sectionId =
            event.currentTarget.dataset.id;

        this.formSections =
            this.formSections.map(section => {
                if (section.id === sectionId) {
                    const newIsOpen = !section.isOpen;

                    return {
                        ...section,
                        isOpen: newIsOpen,
                        isHidden: !newIsOpen,
                        sectionClass: newIsOpen
                            ? 'slds-section slds-is-open'
                            : 'slds-section',
                        iconName: newIsOpen
                            ? 'utility:chevrondown'
                            : 'utility:chevronright'
                    };
                }

                return section;
            });
    }

    enableEditMode() {
        this.isEditMode = true;
    }

    handleCancel() {
        this.manualDateValues = {
            ...this.loadedManualDateValues
        };

        this.isEditMode = false;
    }

    showErrorToast(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Validation Error',
                message,
                variant: 'error'
            })
        );
    }

    async handleSubmit(event) {
        event.preventDefault();

        const fields = event.detail.fields;

        const manualDateResult =
            this.applyManualDatesToFields(fields);

        if (!manualDateResult.isValid) {
            this.showErrorToast(
                manualDateResult.message
            );
            return;
        }

        if (this.currentGender !== 'Other') {
            fields.Gender_Other__c = null;
        }

        if (this.currentLanguage !== 'Other') {
            fields.Preferred_Language_Other__c = null;
        }

        const panValue = fields.PAN__c
            ? fields.PAN__c.trim().toUpperCase()
            : '';

        const gstValue = fields.GST__c
            ? fields.GST__c.trim().toUpperCase()
            : '';

        const phoneRaw = fields.Phone
            ? fields.Phone.replace(/\D/g, '')
            : '';

        const whatsappRaw =
            fields.Whatsapp_number__c
                ? fields.Whatsapp_number__c.replace(
                    /\D/g,
                    ''
                )
                : '';

        const aadharRaw = fields.AadharNo__c
            ? String(fields.AadharNo__c).replace(
                /\D/g,
                ''
            )
            : '';

        const panRegex =
            /^[A-Z]{5}[0-9]{4}[A-Z]{1}$/;

        if (
            panValue &&
            !panRegex.test(panValue)
        ) {
            this.showErrorToast(
                'Invalid PAN format. It must be 5 letters, 4 numbers, and 1 letter (e.g., ABCDE1234F).'
            );
            return;
        }

        if (gstValue) {
            if (!panValue) {
                this.showErrorToast(
                    'PAN is mandatory if a GST number is provided.'
                );
                return;
            }

            const gstRegex =
                /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/;

            if (!gstRegex.test(gstValue)) {
                this.showErrorToast(
                    'Invalid GST format. Ensure it follows standard formatting (e.g., 22ABCDE1234F1Z5).'
                );
                return;
            }

            if (
                gstValue.substring(2, 12) !==
                panValue
            ) {
                this.showErrorToast(
                    'The GST number provided does not match the entered PAN.'
                );
                return;
            }
        }

        if (
            fields.Phone &&
            phoneRaw.length !== 10
        ) {
            this.showErrorToast(
                'Account Phone must be exactly 10 digits.'
            );
            return;
        }

        if (
            fields.Whatsapp_number__c &&
            whatsappRaw.length !== 10
        ) {
            this.showErrorToast(
                'WhatsApp number must be exactly 10 digits.'
            );
            return;
        }

        if (
            fields.AadharNo__c &&
            aadharRaw.length !== 12
        ) {
            this.showErrorToast(
                'Aadhar number must be exactly 12 digits.'
            );
            return;
        }

        if (fields.Phone) {
            fields.Phone = phoneRaw;
        }

        if (fields.Whatsapp_number__c) {
            fields.Whatsapp_number__c =
                whatsappRaw;
        }

        if (fields.PAN__c) {
            fields.PAN__c = panValue;
        }

        if (fields.GST__c) {
            fields.GST__c = gstValue;
        }

        /*
         * Remove verified fields from submitted data
         * so the values cannot be changed.
         */
        Object.keys(VERIFIED_FIELD_MAP).forEach(
            accountFieldApi => {
                if (
                    this.isAccountFieldVerified(
                        accountFieldApi
                    ) &&
                    Object.prototype.hasOwnProperty.call(
                        fields,
                        accountFieldApi
                    )
                ) {
                    delete fields[accountFieldApi];
                }
            }
        );

        /*
         * Gender Other is locked when
         * Gender has already been verified.
         */
        if (
            this.isAccountFieldVerified('Gender__c') &&
            Object.prototype.hasOwnProperty.call(
                fields,
                'Gender_Other__c'
            )
        ) {
            delete fields.Gender_Other__c;
        }

        try {
            const duplicateAccount =
                await checkDuplicateAccount({
                    phoneNo: phoneRaw,
                    whatsappNo: whatsappRaw,
                    recordId: this.recordId
                });

            if (duplicateAccount) {
                this.duplicateAccountId =
                    duplicateAccount.Id;

                this.duplicateName =
                    duplicateAccount.Name;

                this.duplicatePhone =
                    duplicateAccount.Phone ||
                    duplicateAccount
                        .Whatsapp_number__c;

                this.duplicateModalStep = 1;
                this.showDuplicateModal = true;
            } else {
                const editForm =
                    this.template.querySelector(
                        'lightning-record-edit-form'
                    );

                if (editForm) {
                    editForm.submit(fields);
                }
            }
        } catch (error) {
            console.error(
                'Error checking duplicate:',
                error
            );

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message:
                        error?.body?.message ||
                        'Something went wrong while checking for duplicates.',
                    variant: 'error'
                })
            );
        }
    }

    handleCancelMerge() {
        this.showDuplicateModal = false;
        this.duplicateModalStep = 1;
    }

    handleStep1Continue() {
        this.duplicateModalStep = 2;
    }

    handleStep2Back() {
        this.duplicateModalStep = 1;
    }

    async handleContinueMerge() {
        this.showDuplicateModal = false;

        try {
            await mergeAndInactiveAccount({
                currentAccountId: this.recordId,
                existingAccountId:
                    this.duplicateAccountId
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Customer Transferred',
                    message:
                        'Current account marked as Inactive and Showroom Visits tagged to the existing Customer successfully.',
                    variant: 'success'
                })
            );

            await this.refreshPageData();

            this.dispatchEvent(
                new RefreshEvent()
            );
        } catch (error) {
            console.error(
                'Error merging records:',
                error
            );

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Merge Error',
                    message:
                        error?.body?.message ||
                        'Something went wrong while transferring records.',
                    variant: 'error'
                })
            );
        }
    }

    async handleSuccess() {
        this.isEditMode = false;

        await this.refreshPageData();

        this.dispatchEvent(
            new RefreshEvent()
        );

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Record saved successfully.',
                variant: 'success'
            })
        );
    }

    handleError(event) {
        event.preventDefault();

        const errorMessage =
            event.detail?.detail ||
            event.detail?.message ||
            'An error occurred while saving. Please check your inputs.';

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error Saving Record',
                message: errorMessage,
                variant: 'error',
                mode: 'dismissable'
            })
        );
    }
}