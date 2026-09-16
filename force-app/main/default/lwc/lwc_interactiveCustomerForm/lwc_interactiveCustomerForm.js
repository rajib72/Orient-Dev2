import { LightningElement, api } from 'lwc';
import getInteractiveForm from '@salesforce/apex/ctrl_ActivityDashboardController.getInteractiveForm';
import saveCustomerResponse from '@salesforce/apex/ctrl_ActivityDashboardController.saveCustomerResponse';
import getCustomerDetailsByPhone from '@salesforce/apex/ctrl_ActivityDashboardController.getCustomerDetailsByPhone';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Lwc_interactiveCustomerForm extends LightningElement {
    @api formId;
    @api activityId;

    /*
     * Optional so this reusable form continues to work when opened
     * from LWCs that do not use the BTL Daily Execution model.
     */
    @api dailyExecutionId;

    @api isModalView = false;

    isLoading = false;
    isCustomerSearchLoading = false;

    selectedFormId;
    selectedFormNo;
    selectedFormName;
    selectedQuestions = [];

    phoneNo = '';
    normalizedPhoneNo = '';

    latitude;
    longitude;
    locationMessage = 'Fetching current location...';

    customerDetails;
    customerNotFound = false;

    customerSearchRequestToken = 0;
    lastSearchedPhone = '';

    connectedCallback() {
        this.selectedFormId = this.formId;
        this.loadInteractiveForm();
        this.captureCurrentLocation();
    }

    get questionCount() {
        return this.selectedQuestions
            ? this.selectedQuestions.length
            : 0;
    }

    get hasQuestions() {
        return (
            this.selectedQuestions &&
            this.selectedQuestions.length > 0
        );
    }

    get isPhoneValid() {
        return Boolean(this.normalizedPhoneNo);
    }

    get isCustomerInfoDisabled() {
        return !this.isPhoneValid;
    }

    get customerInformationClass() {
        return this.isCustomerInfoDisabled
            ? 'customerInformationDisabled'
            : 'customerInformationEnabled';
    }

    get showCustomerDetails() {
        return this.customerDetails != null;
    }

    get showCustomerNotFound() {
        return (
            this.customerNotFound === true &&
            !this.customerDetails
        );
    }

    loadInteractiveForm() {
        if (!this.formId) {
            this.showToast(
                'Error',
                'Form Id is missing.',
                'error'
            );
            return;
        }

        this.isLoading = true;

        getInteractiveForm({
            finalCustomizeFormId: this.formId
        })
            .then(result => {
                this.selectedFormId = result.formId;
                this.selectedFormNo = result.formNo;
                this.selectedFormName = result.formName;

                this.selectedQuestions = (result.questions || []).map(q => {
                    return {
                        ...q,
                        value: '',
                        selectedValues: [],

                        isRequired:
                            q.isRequired === true,

                        mappedCustomerFieldApi:
                            q.mappedCustomerFieldApi || '',

                        lockWhenCustomerFound:
                            q.lockWhenCustomerFound === true,

                        lockAnswer: false,
                        prefilledFromCustomer: false,
                        isDisabled: true,

                        isText:
                            q.fieldType === 'text',

                        isNumber:
                            q.fieldType === 'number',

                        isDate:
                            q.fieldType === 'date',

                        isDateTime:
                            q.fieldType === 'datetime',

                        isPicklist:
                            q.fieldType === 'picklist',

                        isMultiPicklist:
                            q.fieldType === 'multipicklist',

                        hasOptions:
                            q.options &&
                            q.options.length > 0
                    };
                });

                this.refreshQuestionDisabledState();
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;

                this.showToast(
                    'Error',
                    this.getErrorMessage(error),
                    'error'
                );
            });
    }

    captureCurrentLocation() {
        if (!navigator.geolocation) {
            this.locationMessage =
                'Location is not supported in this browser.';
            return;
        }

        navigator.geolocation.getCurrentPosition(
            position => {
                this.latitude =
                    position.coords.latitude;

                this.longitude =
                    position.coords.longitude;

                this.locationMessage =
                    'Current location captured.';
            },
            () => {
                this.latitude = null;
                this.longitude = null;

                this.locationMessage =
                    'Location permission not allowed.';
            },
            {
                enableHighAccuracy: true,
                timeout: 10000,
                maximumAge: 0
            }
        );
    }

    handlePhoneKeyDown(event) {
        const allowedControlKeys = [
            'Backspace',
            'Delete',
            'Tab',
            'ArrowLeft',
            'ArrowRight',
            'ArrowUp',
            'ArrowDown',
            'Home',
            'End',
            'Enter',
            'Escape'
        ];

        if (event.ctrlKey || event.metaKey) {
            return;
        }

        if (allowedControlKeys.includes(event.key)) {
            return;
        }

        if (/^[0-9]$/.test(event.key)) {
            return;
        }

        if (
            event.key === '+' &&
            (!this.phoneNo || this.phoneNo.length === 0)
        ) {
            return;
        }

        event.preventDefault();
    }

    sanitizePhoneInput(rawValue) {
        if (
            rawValue === null ||
            rawValue === undefined
        ) {
            return '';
        }

        let enteredValue = String(rawValue);

        enteredValue =
            enteredValue.replace(/[^0-9+]/g, '');

        const hasLeadingPlus =
            enteredValue.startsWith('+');

        const digitsOnly =
            enteredValue.replace(/\D/g, '');

        if (hasLeadingPlus) {
            return ('+' + digitsOnly).substring(0, 13);
        }

        return digitsOnly.substring(0, 10);
    }

    normalizePhoneNumber(phoneValue) {
        if (
            phoneValue === null ||
            phoneValue === undefined
        ) {
            return '';
        }

        const phoneMatch =
            String(phoneValue).match(
                /^(?:\+91)?([6-9][0-9]{9})$/
            );

        return phoneMatch
            ? phoneMatch[1]
            : '';
    }

    getPhoneValidationMessage() {
        if (!this.phoneNo) {
            return '';
        }

        if (!this.normalizedPhoneNo) {
            return (
                'Enter exactly 10 numeric digits starting with ' +
                '6, 7, 8, or 9. You may optionally prefix +91.'
            );
        }

        return '';
    }

    setPhoneInputValidity(
        inputComponent,
        shouldReportValidity
    ) {
        if (!inputComponent) {
            return;
        }

        inputComponent.setCustomValidity(
            this.getPhoneValidationMessage()
        );

        if (shouldReportValidity) {
            inputComponent.reportValidity();
        }
    }

    handlePhoneChange(event) {
        const previousPhone =
            this.normalizedPhoneNo;

        const sanitizedValue =
            this.sanitizePhoneInput(
                event.target.value || ''
            );

        if (event.target.value !== sanitizedValue) {
            event.target.value = sanitizedValue;
        }

        this.phoneNo = sanitizedValue;

        this.normalizedPhoneNo =
            this.normalizePhoneNumber(
                this.phoneNo
            );

        this.setPhoneInputValidity(
            event.target,
            false
        );

        /*
         * Clear any old customer result immediately when the
         * entered number changes.
         */
        if (
            previousPhone !==
            this.normalizedPhoneNo
        ) {
            this.customerSearchRequestToken += 1;
            this.lastSearchedPhone = '';

            this.isCustomerSearchLoading = false;
            this.customerDetails = null;
            this.customerNotFound = false;

            this.clearCustomerAutofill();
        }

        this.refreshQuestionDisabledState();

        /*
         * Search immediately as soon as the number becomes valid.
         */
        if (
            this.normalizedPhoneNo &&
            this.lastSearchedPhone !==
                this.normalizedPhoneNo
        ) {
            this.searchCustomerByPhone();
        }
    }

    handlePhoneBlur(event) {
        const sanitizedValue =
            this.sanitizePhoneInput(
                event.target.value || ''
            );

        if (event.target.value !== sanitizedValue) {
            event.target.value = sanitizedValue;
        }

        this.phoneNo = sanitizedValue;

        this.normalizedPhoneNo =
            this.normalizePhoneNumber(
                this.phoneNo
            );

        this.setPhoneInputValidity(
            event.target,
            true
        );

        this.refreshQuestionDisabledState();

        /*
         * Fallback only. Normally the search already runs
         * from handlePhoneChange.
         */
        if (
            this.normalizedPhoneNo &&
            this.lastSearchedPhone !==
                this.normalizedPhoneNo
        ) {
            this.searchCustomerByPhone();
        }
    }

    searchCustomerByPhone() {
        const phoneToSearch =
            this.normalizedPhoneNo;

        if (!phoneToSearch) {
            this.customerDetails = null;
            this.customerNotFound = false;
            this.isCustomerSearchLoading = false;
            return;
        }

        if (
            this.lastSearchedPhone === phoneToSearch &&
            (
                this.customerDetails ||
                this.customerNotFound ||
                this.isCustomerSearchLoading
            )
        ) {
            return;
        }

        const currentRequestToken =
            ++this.customerSearchRequestToken;

        this.lastSearchedPhone =
            phoneToSearch;

        this.isCustomerSearchLoading =
            true;

        getCustomerDetailsByPhone({
            phoneNo: phoneToSearch,
            finalCustomizeFormId: this.formId
        })
            .then(result => {
                if (
                    currentRequestToken !==
                        this.customerSearchRequestToken ||
                    phoneToSearch !==
                        this.normalizedPhoneNo
                ) {
                    return;
                }

                this.isCustomerSearchLoading =
                    false;

                if (result) {
                    this.customerDetails = {
                        ...result,
                        phone: phoneToSearch
                    };

                    this.customerNotFound =
                        false;

                    this.applyCustomerAutofill();
                } else {
                    this.customerDetails = null;
                    this.customerNotFound = true;

                    this.clearCustomerAutofill();
                    this.refreshQuestionDisabledState();
                }
            })
            .catch(error => {
                if (
                    currentRequestToken !==
                    this.customerSearchRequestToken
                ) {
                    return;
                }

                this.isCustomerSearchLoading =
                    false;

                this.customerDetails = null;
                this.customerNotFound = false;
                this.lastSearchedPhone = '';

                this.clearCustomerAutofill();
                this.refreshQuestionDisabledState();

                this.showToast(
                    'Error',
                    this.getErrorMessage(error),
                    'error'
                );
            });
    }

    applyCustomerAutofill() {
        if (!this.customerDetails) {
            return;
        }

        const fieldValues =
            this.customerDetails.fieldValues || {};

        this.selectedQuestions =
            this.selectedQuestions.map(q => {
                const mappedFieldApi =
                    q.mappedCustomerFieldApi;

                if (!mappedFieldApi) {
                    return {
                        ...q,
                        lockAnswer: false,
                        prefilledFromCustomer: false
                    };
                }

                const hasMappedValue =
                    Object.prototype.hasOwnProperty.call(
                        fieldValues,
                        mappedFieldApi
                    );

                const mappedValue =
                    hasMappedValue &&
                    fieldValues[mappedFieldApi] !== null &&
                    fieldValues[mappedFieldApi] !== undefined
                        ? String(
                            fieldValues[mappedFieldApi]
                        )
                        : '';

                return {
                    ...q,
                    value: mappedValue,

                    selectedValues:
                        q.isMultiPicklist && mappedValue
                            ? mappedValue
                                .split(';')
                                .filter(value => value)
                            : [],

                    /*
                     * Phone and Whatsapp_number__c are locked
                     * based on the value returned by Apex.
                     */
                    lockAnswer:
                        q.lockWhenCustomerFound === true,

                    prefilledFromCustomer:
                        hasMappedValue
                };
            });

        this.refreshQuestionDisabledState();
    }

    clearCustomerAutofill() {
        this.selectedQuestions =
            this.selectedQuestions.map(q => {
                if (!q.prefilledFromCustomer) {
                    return {
                        ...q,
                        lockAnswer: false
                    };
                }

                return {
                    ...q,
                    value: '',
                    selectedValues: [],
                    lockAnswer: false,
                    prefilledFromCustomer: false
                };
            });
    }

    refreshQuestionDisabledState() {
        this.selectedQuestions =
            this.selectedQuestions.map(q => {
                return {
                    ...q,
                    isDisabled:
                        this.isCustomerInfoDisabled ||
                        q.lockAnswer
                };
            });
    }

    handleAnswerChange(event) {
        const lineItemId =
            event.target.dataset.id;

        const value =
            event.detail &&
            event.detail.value !== undefined
                ? event.detail.value
                : event.target.value;

        this.selectedQuestions =
            this.selectedQuestions.map(q => {
                if (q.lineItemId === lineItemId) {
                    return {
                        ...q,
                        value: value
                    };
                }

                return q;
            });
    }

    handleMultiPicklistChange(event) {
        const lineItemId =
            event.target.dataset.id;

        const values =
            event.detail &&
            event.detail.value
                ? event.detail.value
                : [];

        this.selectedQuestions =
            this.selectedQuestions.map(q => {
                if (q.lineItemId === lineItemId) {
                    return {
                        ...q,
                        selectedValues: values,
                        value: values.join(';')
                    };
                }

                return q;
            });
    }

    handleResetAnswers() {
        this.customerSearchRequestToken += 1;
        this.lastSearchedPhone = '';

        this.phoneNo = '';
        this.normalizedPhoneNo = '';

        this.customerDetails = null;
        this.customerNotFound = false;
        this.isCustomerSearchLoading = false;

        this.selectedQuestions =
            this.selectedQuestions.map(q => {
                return {
                    ...q,
                    value: '',
                    selectedValues: [],
                    lockAnswer: false,
                    prefilledFromCustomer: false,
                    isDisabled: true
                };
            });

        const phoneInput =
            this.template.querySelector(
                '[data-phone-input="true"]'
            );

        if (phoneInput) {
            phoneInput.value = '';
            phoneInput.setCustomValidity('');
            phoneInput.reportValidity();
        }
    }

    handleSaveAnswers() {
        const phoneInput =
            this.template.querySelector(
                '[data-phone-input="true"]'
            );

        this.phoneNo =
            this.sanitizePhoneInput(
                this.phoneNo
            );

        this.normalizedPhoneNo =
            this.normalizePhoneNumber(
                this.phoneNo
            );

        this.setPhoneInputValidity(
            phoneInput,
            true
        );

        if (!this.normalizedPhoneNo) {
            this.showToast(
                'Validation Error',
                'Please enter a valid 10-digit Phone No starting with 6, 7, 8, or 9.',
                'error'
            );
            return;
        }

        const inputComponents = [
            ...this.template.querySelectorAll(
                'lightning-input, ' +
                'lightning-combobox, ' +
                'lightning-dual-listbox'
            )
        ];

        const allValid =
            inputComponents.reduce(
                (validSoFar, inputComponent) => {
                    inputComponent.reportValidity();

                    return (
                        validSoFar &&
                        inputComponent.checkValidity()
                    );
                },
                true
            );

        if (!allValid) {
            return;
        }

        if (!this.activityId) {
            this.showToast(
                'Error',
                'Form Activity Id is missing.',
                'error'
            );
            return;
        }

        const answerPayload =
            this.selectedQuestions.map(q => {
                return {
                    lineItemId: q.lineItemId,
                    question: q.question,
                    answerType: q.answerType,
                    answer: q.value
                };
            });

        this.isLoading = true;

        saveCustomerResponse({
            formActivityId: this.activityId,

            /*
             * Null for existing consumers that do not provide it.
             * The BTL Sales Executive dashboard supplies this value.
             */
            dailyExecutionId:
                this.dailyExecutionId || null,

            phoneNo: this.normalizedPhoneNo,
            latitude: this.latitude,
            longitude: this.longitude,
            answers: answerPayload
        })
            .then(() => {
                this.isLoading = false;

                this.showToast(
                    'Success',
                    'Customer response saved successfully.',
                    'success'
                );

                this.dispatchEvent(
                    new CustomEvent(
                        'backtodashboard'
                    )
                );
            })
            .catch(error => {
                this.isLoading = false;

                this.showToast(
                    'Error',
                    this.getErrorMessage(error),
                    'error'
                );
            });
    }

    handleBack() {
        this.dispatchEvent(
            new CustomEvent(
                'backtodashboard'
            )
        );
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    getErrorMessage(error) {
        if (
            error &&
            error.body &&
            error.body.message
        ) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Something went wrong.';
    }
}

// import { LightningElement, api } from 'lwc';
// import getInteractiveForm from '@salesforce/apex/ctrl_ActivityDashboardController.getInteractiveForm';
// import saveCustomerResponse from '@salesforce/apex/ctrl_ActivityDashboardController.saveCustomerResponse';
// import getCustomerDetailsByPhone from '@salesforce/apex/ctrl_ActivityDashboardController.getCustomerDetailsByPhone';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// export default class Lwc_interactiveCustomerForm extends LightningElement {
//     @api formId;
//     @api activityId;
//     @api isModalView = false;

//     isLoading = false;
//     isCustomerSearchLoading = false;

//     selectedFormId;
//     selectedFormNo;
//     selectedFormName;
//     selectedQuestions = [];

//     phoneNo = '';
//     normalizedPhoneNo = '';

//     latitude;
//     longitude;
//     locationMessage = 'Fetching current location...';

//     customerDetails;
//     customerNotFound = false;

//     customerSearchRequestToken = 0;
//     lastSearchedPhone = '';

//     connectedCallback() {
//         this.selectedFormId = this.formId;
//         this.loadInteractiveForm();
//         this.captureCurrentLocation();
//     }

//     get questionCount() {
//         return this.selectedQuestions
//             ? this.selectedQuestions.length
//             : 0;
//     }

//     get hasQuestions() {
//         return (
//             this.selectedQuestions &&
//             this.selectedQuestions.length > 0
//         );
//     }

//     get isPhoneValid() {
//         return Boolean(this.normalizedPhoneNo);
//     }

//     get isCustomerInfoDisabled() {
//         return !this.isPhoneValid;
//     }

//     get customerInformationClass() {
//         return this.isCustomerInfoDisabled
//             ? 'customerInformationDisabled'
//             : 'customerInformationEnabled';
//     }

//     get showCustomerDetails() {
//         return this.customerDetails != null;
//     }

//     get showCustomerNotFound() {
//         return (
//             this.customerNotFound === true &&
//             !this.customerDetails
//         );
//     }

//     loadInteractiveForm() {
//         if (!this.formId) {
//             this.showToast(
//                 'Error',
//                 'Form Id is missing.',
//                 'error'
//             );
//             return;
//         }

//         this.isLoading = true;

//         getInteractiveForm({
//             finalCustomizeFormId: this.formId
//         })
//             .then(result => {
//                 this.selectedFormId = result.formId;
//                 this.selectedFormNo = result.formNo;
//                 this.selectedFormName = result.formName;

//                 this.selectedQuestions = (result.questions || []).map(q => {
//                     return {
//                         ...q,
//                         value: '',
//                         selectedValues: [],

//                         isRequired:
//                             q.isRequired === true,

//                         mappedCustomerFieldApi:
//                             q.mappedCustomerFieldApi || '',

//                         lockWhenCustomerFound:
//                             q.lockWhenCustomerFound === true,

//                         lockAnswer: false,
//                         prefilledFromCustomer: false,
//                         isDisabled: true,

//                         isText:
//                             q.fieldType === 'text',

//                         isNumber:
//                             q.fieldType === 'number',

//                         isDate:
//                             q.fieldType === 'date',

//                         isDateTime:
//                             q.fieldType === 'datetime',

//                         isPicklist:
//                             q.fieldType === 'picklist',

//                         isMultiPicklist:
//                             q.fieldType === 'multipicklist',

//                         hasOptions:
//                             q.options &&
//                             q.options.length > 0
//                     };
//                 });

//                 this.refreshQuestionDisabledState();
//                 this.isLoading = false;
//             })
//             .catch(error => {
//                 this.isLoading = false;

//                 this.showToast(
//                     'Error',
//                     this.getErrorMessage(error),
//                     'error'
//                 );
//             });
//     }

//     captureCurrentLocation() {
//         if (!navigator.geolocation) {
//             this.locationMessage =
//                 'Location is not supported in this browser.';
//             return;
//         }

//         navigator.geolocation.getCurrentPosition(
//             position => {
//                 this.latitude =
//                     position.coords.latitude;

//                 this.longitude =
//                     position.coords.longitude;

//                 this.locationMessage =
//                     'Current location captured.';
//             },
//             () => {
//                 this.latitude = null;
//                 this.longitude = null;

//                 this.locationMessage =
//                     'Location permission not allowed.';
//             },
//             {
//                 enableHighAccuracy: true,
//                 timeout: 10000,
//                 maximumAge: 0
//             }
//         );
//     }

//     handlePhoneKeyDown(event) {
//         const allowedControlKeys = [
//             'Backspace',
//             'Delete',
//             'Tab',
//             'ArrowLeft',
//             'ArrowRight',
//             'ArrowUp',
//             'ArrowDown',
//             'Home',
//             'End',
//             'Enter',
//             'Escape'
//         ];

//         if (event.ctrlKey || event.metaKey) {
//             return;
//         }

//         if (allowedControlKeys.includes(event.key)) {
//             return;
//         }

//         if (/^[0-9]$/.test(event.key)) {
//             return;
//         }

//         if (
//             event.key === '+' &&
//             (!this.phoneNo || this.phoneNo.length === 0)
//         ) {
//             return;
//         }

//         event.preventDefault();
//     }

//     sanitizePhoneInput(rawValue) {
//         if (
//             rawValue === null ||
//             rawValue === undefined
//         ) {
//             return '';
//         }

//         let enteredValue = String(rawValue);

//         enteredValue =
//             enteredValue.replace(/[^0-9+]/g, '');

//         const hasLeadingPlus =
//             enteredValue.startsWith('+');

//         const digitsOnly =
//             enteredValue.replace(/\D/g, '');

//         if (hasLeadingPlus) {
//             return ('+' + digitsOnly).substring(0, 13);
//         }

//         return digitsOnly.substring(0, 10);
//     }

//     normalizePhoneNumber(phoneValue) {
//         if (
//             phoneValue === null ||
//             phoneValue === undefined
//         ) {
//             return '';
//         }

//         const phoneMatch =
//             String(phoneValue).match(
//                 /^(?:\+91)?([6-9][0-9]{9})$/
//             );

//         return phoneMatch
//             ? phoneMatch[1]
//             : '';
//     }

//     getPhoneValidationMessage() {
//         if (!this.phoneNo) {
//             return '';
//         }

//         if (!this.normalizedPhoneNo) {
//             return (
//                 'Enter exactly 10 numeric digits starting with ' +
//                 '6, 7, 8, or 9. You may optionally prefix +91.'
//             );
//         }

//         return '';
//     }

//     setPhoneInputValidity(
//         inputComponent,
//         shouldReportValidity
//     ) {
//         if (!inputComponent) {
//             return;
//         }

//         inputComponent.setCustomValidity(
//             this.getPhoneValidationMessage()
//         );

//         if (shouldReportValidity) {
//             inputComponent.reportValidity();
//         }
//     }

//     handlePhoneChange(event) {
//         const previousPhone =
//             this.normalizedPhoneNo;

//         const sanitizedValue =
//             this.sanitizePhoneInput(
//                 event.target.value || ''
//             );

//         if (event.target.value !== sanitizedValue) {
//             event.target.value = sanitizedValue;
//         }

//         this.phoneNo = sanitizedValue;

//         this.normalizedPhoneNo =
//             this.normalizePhoneNumber(
//                 this.phoneNo
//             );

//         this.setPhoneInputValidity(
//             event.target,
//             false
//         );

//         /*
//          * Clear any old customer result immediately when the
//          * entered number changes.
//          */
//         if (
//             previousPhone !==
//             this.normalizedPhoneNo
//         ) {
//             this.customerSearchRequestToken += 1;
//             this.lastSearchedPhone = '';

//             this.isCustomerSearchLoading = false;
//             this.customerDetails = null;
//             this.customerNotFound = false;

//             this.clearCustomerAutofill();
//         }

//         this.refreshQuestionDisabledState();

//         /*
//          * Search immediately as soon as the number becomes valid.
//          */
//         if (
//             this.normalizedPhoneNo &&
//             this.lastSearchedPhone !==
//                 this.normalizedPhoneNo
//         ) {
//             this.searchCustomerByPhone();
//         }
//     }

//     handlePhoneBlur(event) {
//         const sanitizedValue =
//             this.sanitizePhoneInput(
//                 event.target.value || ''
//             );

//         if (event.target.value !== sanitizedValue) {
//             event.target.value = sanitizedValue;
//         }

//         this.phoneNo = sanitizedValue;

//         this.normalizedPhoneNo =
//             this.normalizePhoneNumber(
//                 this.phoneNo
//             );

//         this.setPhoneInputValidity(
//             event.target,
//             true
//         );

//         this.refreshQuestionDisabledState();

//         /*
//          * Fallback only. Normally the search already runs
//          * from handlePhoneChange.
//          */
//         if (
//             this.normalizedPhoneNo &&
//             this.lastSearchedPhone !==
//                 this.normalizedPhoneNo
//         ) {
//             this.searchCustomerByPhone();
//         }
//     }

//     searchCustomerByPhone() {
//         const phoneToSearch =
//             this.normalizedPhoneNo;

//         if (!phoneToSearch) {
//             this.customerDetails = null;
//             this.customerNotFound = false;
//             this.isCustomerSearchLoading = false;
//             return;
//         }

//         if (
//             this.lastSearchedPhone === phoneToSearch &&
//             (
//                 this.customerDetails ||
//                 this.customerNotFound ||
//                 this.isCustomerSearchLoading
//             )
//         ) {
//             return;
//         }

//         const currentRequestToken =
//             ++this.customerSearchRequestToken;

//         this.lastSearchedPhone =
//             phoneToSearch;

//         this.isCustomerSearchLoading =
//             true;

//         getCustomerDetailsByPhone({
//             phoneNo: phoneToSearch,
//             finalCustomizeFormId: this.formId
//         })
//             .then(result => {
//                 if (
//                     currentRequestToken !==
//                         this.customerSearchRequestToken ||
//                     phoneToSearch !==
//                         this.normalizedPhoneNo
//                 ) {
//                     return;
//                 }

//                 this.isCustomerSearchLoading =
//                     false;

//                 if (result) {
//                     this.customerDetails = {
//                         ...result,
//                         phone: phoneToSearch
//                     };

//                     this.customerNotFound =
//                         false;

//                     this.applyCustomerAutofill();
//                 } else {
//                     this.customerDetails = null;
//                     this.customerNotFound = true;

//                     this.clearCustomerAutofill();
//                     this.refreshQuestionDisabledState();
//                 }
//             })
//             .catch(error => {
//                 if (
//                     currentRequestToken !==
//                     this.customerSearchRequestToken
//                 ) {
//                     return;
//                 }

//                 this.isCustomerSearchLoading =
//                     false;

//                 this.customerDetails = null;
//                 this.customerNotFound = false;
//                 this.lastSearchedPhone = '';

//                 this.clearCustomerAutofill();
//                 this.refreshQuestionDisabledState();

//                 this.showToast(
//                     'Error',
//                     this.getErrorMessage(error),
//                     'error'
//                 );
//             });
//     }

//     applyCustomerAutofill() {
//         if (!this.customerDetails) {
//             return;
//         }

//         const fieldValues =
//             this.customerDetails.fieldValues || {};

//         this.selectedQuestions =
//             this.selectedQuestions.map(q => {
//                 const mappedFieldApi =
//                     q.mappedCustomerFieldApi;

//                 if (!mappedFieldApi) {
//                     return {
//                         ...q,
//                         lockAnswer: false,
//                         prefilledFromCustomer: false
//                     };
//                 }

//                 const hasMappedValue =
//                     Object.prototype.hasOwnProperty.call(
//                         fieldValues,
//                         mappedFieldApi
//                     );

//                 const mappedValue =
//                     hasMappedValue &&
//                     fieldValues[mappedFieldApi] !== null &&
//                     fieldValues[mappedFieldApi] !== undefined
//                         ? String(
//                             fieldValues[mappedFieldApi]
//                         )
//                         : '';

//                 return {
//                     ...q,
//                     value: mappedValue,

//                     selectedValues:
//                         q.isMultiPicklist && mappedValue
//                             ? mappedValue
//                                 .split(';')
//                                 .filter(value => value)
//                             : [],

//                     /*
//                      * Phone and Whatsapp_number__c are locked
//                      * based on the value returned by Apex.
//                      */
//                     lockAnswer:
//                         q.lockWhenCustomerFound === true,

//                     prefilledFromCustomer:
//                         hasMappedValue
//                 };
//             });

//         this.refreshQuestionDisabledState();
//     }

//     clearCustomerAutofill() {
//         this.selectedQuestions =
//             this.selectedQuestions.map(q => {
//                 if (!q.prefilledFromCustomer) {
//                     return {
//                         ...q,
//                         lockAnswer: false
//                     };
//                 }

//                 return {
//                     ...q,
//                     value: '',
//                     selectedValues: [],
//                     lockAnswer: false,
//                     prefilledFromCustomer: false
//                 };
//             });
//     }

//     refreshQuestionDisabledState() {
//         this.selectedQuestions =
//             this.selectedQuestions.map(q => {
//                 return {
//                     ...q,
//                     isDisabled:
//                         this.isCustomerInfoDisabled ||
//                         q.lockAnswer
//                 };
//             });
//     }

//     handleAnswerChange(event) {
//         const lineItemId =
//             event.target.dataset.id;

//         const value =
//             event.detail &&
//             event.detail.value !== undefined
//                 ? event.detail.value
//                 : event.target.value;

//         this.selectedQuestions =
//             this.selectedQuestions.map(q => {
//                 if (q.lineItemId === lineItemId) {
//                     return {
//                         ...q,
//                         value: value
//                     };
//                 }

//                 return q;
//             });
//     }

//     handleMultiPicklistChange(event) {
//         const lineItemId =
//             event.target.dataset.id;

//         const values =
//             event.detail &&
//             event.detail.value
//                 ? event.detail.value
//                 : [];

//         this.selectedQuestions =
//             this.selectedQuestions.map(q => {
//                 if (q.lineItemId === lineItemId) {
//                     return {
//                         ...q,
//                         selectedValues: values,
//                         value: values.join(';')
//                     };
//                 }

//                 return q;
//             });
//     }

//     handleResetAnswers() {
//         this.customerSearchRequestToken += 1;
//         this.lastSearchedPhone = '';

//         this.phoneNo = '';
//         this.normalizedPhoneNo = '';

//         this.customerDetails = null;
//         this.customerNotFound = false;
//         this.isCustomerSearchLoading = false;

//         this.selectedQuestions =
//             this.selectedQuestions.map(q => {
//                 return {
//                     ...q,
//                     value: '',
//                     selectedValues: [],
//                     lockAnswer: false,
//                     prefilledFromCustomer: false,
//                     isDisabled: true
//                 };
//             });

//         const phoneInput =
//             this.template.querySelector(
//                 '[data-phone-input="true"]'
//             );

//         if (phoneInput) {
//             phoneInput.value = '';
//             phoneInput.setCustomValidity('');
//             phoneInput.reportValidity();
//         }
//     }

//     handleSaveAnswers() {
//         const phoneInput =
//             this.template.querySelector(
//                 '[data-phone-input="true"]'
//             );

//         this.phoneNo =
//             this.sanitizePhoneInput(
//                 this.phoneNo
//             );

//         this.normalizedPhoneNo =
//             this.normalizePhoneNumber(
//                 this.phoneNo
//             );

//         this.setPhoneInputValidity(
//             phoneInput,
//             true
//         );

//         if (!this.normalizedPhoneNo) {
//             this.showToast(
//                 'Validation Error',
//                 'Please enter a valid 10-digit Phone No starting with 6, 7, 8, or 9.',
//                 'error'
//             );
//             return;
//         }

//         const inputComponents = [
//             ...this.template.querySelectorAll(
//                 'lightning-input, ' +
//                 'lightning-combobox, ' +
//                 'lightning-dual-listbox'
//             )
//         ];

//         const allValid =
//             inputComponents.reduce(
//                 (validSoFar, inputComponent) => {
//                     inputComponent.reportValidity();

//                     return (
//                         validSoFar &&
//                         inputComponent.checkValidity()
//                     );
//                 },
//                 true
//             );

//         if (!allValid) {
//             return;
//         }

//         if (!this.activityId) {
//             this.showToast(
//                 'Error',
//                 'Form Activity Id is missing.',
//                 'error'
//             );
//             return;
//         }

//         const answerPayload =
//             this.selectedQuestions.map(q => {
//                 return {
//                     lineItemId: q.lineItemId,
//                     question: q.question,
//                     answerType: q.answerType,
//                     answer: q.value
//                 };
//             });

//         this.isLoading = true;

//         saveCustomerResponse({
//             formActivityId: this.activityId,
//             phoneNo: this.normalizedPhoneNo,
//             latitude: this.latitude,
//             longitude: this.longitude,
//             answers: answerPayload
//         })
//             .then(() => {
//                 this.isLoading = false;

//                 this.showToast(
//                     'Success',
//                     'Customer response saved successfully.',
//                     'success'
//                 );

//                 this.dispatchEvent(
//                     new CustomEvent(
//                         'backtodashboard'
//                     )
//                 );
//             })
//             .catch(error => {
//                 this.isLoading = false;

//                 this.showToast(
//                     'Error',
//                     this.getErrorMessage(error),
//                     'error'
//                 );
//             });
//     }

//     handleBack() {
//         this.dispatchEvent(
//             new CustomEvent(
//                 'backtodashboard'
//             )
//         );
//     }

//     showToast(title, message, variant) {
//         this.dispatchEvent(
//             new ShowToastEvent({
//                 title: title,
//                 message: message,
//                 variant: variant
//             })
//         );
//     }

//     getErrorMessage(error) {
//         if (
//             error &&
//             error.body &&
//             error.body.message
//         ) {
//             return error.body.message;
//         }

//         if (error && error.message) {
//             return error.message;
//         }

//         return 'Something went wrong.';
//     }
// }