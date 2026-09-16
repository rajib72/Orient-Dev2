import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

// Apex
import saveCustomer from '@salesforce/apex/CustomerEnrollmentController.saveCustomer';
import uploadFile from '@salesforce/apex/CustomerEnrollmentController.uploadFile';
import getPicklistValues from '@salesforce/apex/CustomerEnrollmentController.getPicklistValues';
import getActiveUsers from '@salesforce/apex/CustomerEnrollmentController.getActiveUsers';

export default class CustomerEnrollmentForm extends NavigationMixin(LightningElement) {

    @track formData = {};
    @track picklistOptions = {};
    @track userOptions = [];        // Preferred Sales Executive dropdown

    @track fileName = '';
    @track selectedFile = null;

    dobErrorMessage = '';
    anniversaryErrorMessage = '';

    showPreferredStoreOther = false;
    showPreferredLanguageOther = false;
    showGenderOther = false;



    @api recordId;

    connectedCallback() {
        this.loadPicklists();
        this.formData.Status__c = 'Prospect';
    }

    // Load picklists
    async loadPicklists() {
        try {
            const picklistMap = await getPicklistValues();
            this.picklistOptions = {};
            for (let field in picklistMap) {
                this.picklistOptions[field] = picklistMap[field].map(val => ({
                    label: val,
                    value: val
                }));
            }
            if (!this.formData.Status__c) this.formData.Status__c = 'Prospect';
        } catch (error) {
            console.error('loadPicklists error', error);
            this.showToast('Error', 'Failed to load picklist values', 'error');
        }
    }

    // Defensive user loader
    @wire(getActiveUsers)
    wiredUsers({ error, data }) {
        try {
            if (data && Array.isArray(data)) {
                // Ensure label/value shape and stringify values
                this.userOptions = data.map(u => {
                    const id = u.Id ? String(u.Id) : ''; // safest possible
                    const name = u.Name ? String(u.Name) : id;
                    return { label: name, value: id };
                }).filter(opt => opt.value !== ''); // drop any empty ids
            } else {
                this.userOptions = [];
            }

            // Debug logs - open browser console to verify
            // eslint-disable-next-line no-console
            console.log('wiredUsers -> userOptions:', JSON.stringify(this.userOptions));
        } catch (e) {
            console.error('wiredUsers exception', e);
            this.userOptions = [];
        }
    }

    // Single handler that handles combobox and other inputs
    handleChange(event) {
        try {
            // Lightning combobox places value in event.detail.value
            // For other inputs use event.target.value
            const field = event.target && event.target.name ? event.target.name : null;
            const value = event.detail && typeof event.detail.value !== 'undefined'
                ? event.detail.value
                : (event.target ? event.target.value : undefined);

            console.log('handleChange event:', event);
            console.log('handleChange field, value:', field, value);

            if (!field) {
                console.warn('handleChange: no field name on event.target. Make sure name property is set in HTML.');
                return;
            }

            // Ensure combobox value is string (combobox requires string)
            let safeValue = value;
            if (typeof safeValue !== 'string' && typeof safeValue !== 'number' && safeValue !== undefined && safeValue !== null) {
                try {
                    if (safeValue && safeValue.Id) safeValue = String(safeValue.Id);
                    else safeValue = String(safeValue);
                } catch (e) {
                    safeValue = '';
                }
            }
            if (typeof safeValue === 'number') safeValue = String(safeValue);

            // NEW LOGIC: Convert Pin_Code__c to number
            //if (field === 'Pin_Code__c') {
            //safeValue = Number(safeValue);
            //}

            // Update formData with safeValue
            this.formData = { ...this.formData, [field]: safeValue };

            // Auto-fill WhatsApp number whenever Phone is entered
            if (field === 'Phone') {
                this.formData.Whatsapp_Number__c = safeValue;
            }

            // Specific validations
            if (field === 'Date_Of_Birth__c') this.validateDOB(safeValue, event.target);
            if (field === 'Anniversary_Date__c') this.validateAnniversary(safeValue, event.target);

            // Conditional "Other" fields
            if (field === 'Preferred_Store__c') {
                this.showPreferredStoreOther = (safeValue === 'Other');
                if (!this.showPreferredStoreOther) this.formData.Preferred_Store_Other__c = null;
            }
            if (field === 'Preferred_Language__c') {
                this.showPreferredLanguageOther = (safeValue === 'Other');
                if (!this.showPreferredLanguageOther) this.formData.Preferred_Language_Other__c = null;
            }
            if (field === 'Gender__c') {
                this.showGenderOther = (safeValue === 'Other');
                if (!this.showGenderOther) this.formData.Gender_Other__c = null;
            }

            // eslint-disable-next-line no-console
            console.log('formData after change:', JSON.stringify(this.formData));
        } catch (err) {
            console.error('handleChange unexpected error', err);
            this.showToast('Error', 'An unexpected error occurred (see console).', 'error');
        }
    }




    validateDOB(value, inputField) {
        const today = new Date().toISOString().split('T')[0];

        if (!value) {
            this.dobErrorMessage = '';
            if (inputField && inputField.setCustomValidity) inputField.setCustomValidity('');
        } else if (value >= today) {
            this.dobErrorMessage = 'Enter valid DOB. DOB cannot be today or a future date';
            if (inputField && inputField.setCustomValidity) inputField.setCustomValidity(this.dobErrorMessage);
        } else {
            this.dobErrorMessage = '';
            if (inputField && inputField.setCustomValidity) inputField.setCustomValidity('');
        }
        if (inputField && inputField.reportValidity) inputField.reportValidity();
    }

    validateAnniversary(anniversaryValue, inputField) {
        try {
            if (inputField && inputField.setCustomValidity) inputField.setCustomValidity('');
            const dob = this.formData.Date_Of_Birth__c;

            if (!anniversaryValue) {
                this.anniversaryErrorMessage = '';
                if (inputField && inputField.reportValidity) inputField.reportValidity();
                return;
            }

            if (!dob) {
                this.anniversaryErrorMessage = 'Please enter Date of Birth before entering Anniversary Date.';
                if (inputField && inputField.setCustomValidity) inputField.setCustomValidity(this.anniversaryErrorMessage);
                if (inputField && inputField.reportValidity) inputField.reportValidity();
                return;
            }

            const dobDate = new Date(dob);
            const today = new Date();

            let age = today.getFullYear() - dobDate.getFullYear();
            const m = today.getMonth() - dobDate.getMonth();
            if (m < 0 || (m === 0 && today.getDate() < dobDate.getDate())) age--;

            if (age < 18) {
                this.anniversaryErrorMessage = 'Anniversary Date cannot be entered because age is below 18 years.';
                if (inputField && inputField.setCustomValidity) inputField.setCustomValidity(this.anniversaryErrorMessage);
            } else {
                this.anniversaryErrorMessage = '';
                if (inputField && inputField.setCustomValidity) inputField.setCustomValidity('');
            }

            if (inputField && inputField.reportValidity) inputField.reportValidity();
        } catch (e) {
            console.error('validateAnniversary error', e);
        }
    }

    // File handling (unchanged but defensive)
    handleFileChange(event) {
        try {
            if (event.target.files && event.target.files.length > 0) {
                const file = event.target.files[0];
                const validTypes = ['image/png', 'image/jpg', 'image/jpeg'];

                if (!validTypes.includes(file.type)) {
                    this.showToast('Error', 'Only PNG, JPG, or JPEG files are allowed', 'error');
                    this.selectedFile = null;
                    this.fileName = null;
                    return;
                }

                this.selectedFile = file;
                this.fileName = file.name;
            }
        } catch (e) {
            console.error('handleFileChange error', e);
        }
    }

    removeFile() {
        this.selectedFile = null;
        this.fileName = '';
        const input = this.template.querySelector('lightning-input[type="file"]');
        if (input) input.value = null;
    }

   async saveCustomerData(goNext, redirectToRecord) {
    try {
        const phoneInput = this.template.querySelector('lightning-input[name="Phone"]');

        if (!this.formData.Phone || this.formData.Phone.trim() === '') {
            if (phoneInput) {
                phoneInput.setCustomValidity("Enter Phone Number");
                phoneInput.reportValidity();
            }
            this.showToast('Error', 'Enter Phone Number', 'error');
            return;
        } else {
            if (phoneInput) {
                phoneInput.setCustomValidity("");
                phoneInput.reportValidity();
            }
        }

        const dobField = this.template.querySelector('lightning-input[name="Date_Of_Birth__c"]');
        const annField = this.template.querySelector('lightning-input[name="Anniversary_Date__c"]');

        if (dobField && !dobField.checkValidity()) {
            dobField.reportValidity();
            this.showToast('Error', 'Please correct the errors before saving', 'error');
            return;
        }

        if (annField && !annField.checkValidity()) {
            annField.reportValidity();
            this.showToast('Error', 'Please correct the errors before saving', 'error');
            return;
        }

        if (!this.formData.Name || this.formData.Name.trim() === '') {
            const first = this.formData.First_Name__c || '';
            const middle = this.formData.Middle_Name__c || '';
            const last = this.formData.Last_Name__c || '';
            this.formData.Name = [first, middle, last].filter(n => n).join(' ');
            if (!this.formData.Name) this.formData.Name = 'Blank Customer Name' ;
        }

        const result = await saveCustomer({ formData: this.formData });
        this.recordId = result.Id;

        this.showToast('Success', 'Customer saved successfully', 'success');

        // if (this.selectedFile) {
        //     const reader = new FileReader();

        //     reader.onloadend = async () => {
        //         const base64 = reader.result.split(',')[1];

        //         try {
        //             await uploadFile({
        //                 parentId: this.recordId,
        //                 fileName: this.selectedFile.name,
        //                 base64Data: base64
        //             });

        //             this.showToast('Success', 'File uploaded successfully', 'success');
        //         } catch (err) {
        //             console.error('uploadFile error', JSON.stringify(err));

        //             let uploadErrorMessage = 'Failed to upload file';

        //             if (err && err.body && err.body.message) {
        //                 uploadErrorMessage = err.body.message;
        //             } else if (err && err.message) {
        //                 uploadErrorMessage = err.message;
        //             }

        //             this.showToast('Error', uploadErrorMessage, 'error');
        //         }
        //     };

        //     reader.readAsDataURL(this.selectedFile);
        // }

        if (this.selectedFile) {
            const reader = new FileReader();

            reader.onloadend = async () => {
                const base64 = reader.result.split(',')[1];
                
                // --- NEW CODE: Extract extension and rename to CUST.extension ---
                const fileExtension = this.selectedFile.name.split('.').pop();
                const newFileName = `CUST.${fileExtension}`;
                // ----------------------------------------------------------------

                try {
                    await uploadFile({
                        parentId: this.recordId,
                        fileName: newFileName, // Pass the new file name here
                        base64Data: base64
                    });

                    this.showToast('Success', 'File uploaded successfully', 'success');
                } catch (err) {
                    console.error('uploadFile error', JSON.stringify(err));

                    let uploadErrorMessage = 'Failed to upload file';

                    if (err && err.body && err.body.message) {
                        uploadErrorMessage = err.body.message;
                    } else if (err && err.message) {
                        uploadErrorMessage = err.message;
                    }

                    this.showToast('Error', uploadErrorMessage, 'error');
                }
            };

            reader.readAsDataURL(this.selectedFile);
        }

        if (redirectToRecord) this.navigateToRecord(result.Id);
        if (goNext) this.resetForm();

    } catch (error) {
        console.error('saveCustomerData error', JSON.stringify(error));

        let errorMessage = 'Failed to save customer';

        if (error && error.body) {
            if (error.body.message) {
                errorMessage = error.body.message;
            } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                errorMessage = error.body.pageErrors[0].message;
            } else if (error.body.fieldErrors) {
                const fieldErrors = error.body.fieldErrors;
                const fieldNames = Object.keys(fieldErrors);

                if (fieldNames.length > 0 && fieldErrors[fieldNames[0]].length > 0) {
                    errorMessage = fieldErrors[fieldNames[0]][0].message;
                }
            }
        } else if (error && error.message) {
            errorMessage = error.message;
        }

        this.showToast('Error', errorMessage, 'error');
    }
}

    handleSave() { this.saveCustomerData(false, true); }
    handleSaveAndNext() { this.saveCustomerData(true, false); }
    handleReset() { this.resetForm(); }

    resetForm() {
        // Save the current Status__c value
        const currentStatus = this.formData.Status__c;

        // Clear all input fields
        this.template
            .querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')
            .forEach(input => {
                // Skip Status__c
                if (input.name !== 'Status__c') {
                    input.value = '';
                }
            });

        // Reset formData but keep Status__c
        this.formData = { Status__c: currentStatus };

        // Reset other component states
        this.dobErrorMessage = '';
        this.anniversaryErrorMessage = '';
        this.showPreferredStoreOther = false;
        this.showPreferredLanguageOther = false;
        this.showGenderOther = false;
        this.selectedFile = null;
        this.fileName = '';
    }

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Account',
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}