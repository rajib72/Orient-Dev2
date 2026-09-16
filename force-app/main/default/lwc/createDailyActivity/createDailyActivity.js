import { LightningElement, track } from 'lwc';
import saveDailyActivity from '@salesforce/apex/DailyActivityController.saveDailyActivity';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import searchAccountByPhone from '@salesforce/apex/DailyActivityController.searchAccountByPhone';
import getAllCategories from '@salesforce/apex/DailyActivityController.getAllCategories';
import getSubCategoriesByCategory from '@salesforce/apex/DailyActivityController.getSubCategoriesByCategory';
import getSalesExecutiveByStore from '@salesforce/apex/DailyActivityController.getSalesExecutiveByStore';
import getStoreAccessInfo from '@salesforce/apex/DailyActivityController.getStoreAccessInfo';
import searchPurpose from '@salesforce/apex/DailyActivityController.searchPurpose';

export default class CreateDailyActivity extends NavigationMixin(LightningElement) {

    /* FORM DATA */
    @track form = {
        customer: '',
        phone: '',
        activityDate: '',
        activityTime: '',
        description: '',
        category: '',      // Will store "Option A, Option B"
        subCategory: '',   // Will store "Option C, Option D"
        store: null,
        salesExecutive: null,
        netWeight: '',
        budget: null,
        accountId: null,

        purposeSearch: '',
        purposeMasterId: null,
        purposeLevel1: '',
        purposeLevel2: '',
        purposeLevel3: ''
    };

    /* TRACKED VARIABLES */
    @track matchedAccounts = [];
    @track selectedAccountId = null;

    @track allCategoryOptions = [];
    @track selectedCategories = [];
    @track categoryError = '';

    @track allSubCategoryOptions = [];
    @track selectedSubCategories = [];
    @track subCategoryError = '';

    @track storeOptions = [];
    @track salesExecutiveOptions = [];
    @track isStoreDisabled = false;
    @track purposeResults = [];
    @track selectedPurposeId = null;
    @track designFiles = [];

    @track isSaving = false;
    @track isFileReading = false;

    MAX_FILE_SIZE = 5 * 1024 * 1024; // 5 MB

    /* ─────────────────────────────────────────
   UTILITY METHODS
───────────────────────────────────────── */

    /**
     * Returns today's date as YYYY-MM-DD in LOCAL timezone (not UTC).
     */
    getLocalDateString() {
        const now = new Date();
        const yyyy = now.getFullYear();
        const mm = String(now.getMonth() + 1).padStart(2, '0');
        const dd = String(now.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    /**
     * Returns current time as HH:MM in LOCAL timezone.
     */
    getLocalTimeString() {
        const now = new Date();
        const hh = String(now.getHours()).padStart(2, '0');
        const mm = String(now.getMinutes()).padStart(2, '0');
        return `${hh}:${mm}`;
    }

    /**
     * Validates a YYYY-MM-DD date string against today's local date.
     * Returns error message string, or '' if valid.
     */
    validateActivityDate(dateStr) {
        if (!dateStr) return '';

        const selectedDate = new Date(dateStr + 'T00:00:00'); // local midnight
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        if (isNaN(selectedDate.getTime())) {
            return 'Invalid date format.';
        }

        if (selectedDate < today) {
            return 'Date cannot be in the past.';
        }

        return '';
    }

    /* COMPONENT LOAD */
    connectedCallback() {
        this.form.activityDate = this.getLocalDateString();
        this.form.activityTime = this.getLocalTimeString();

        getAllCategories()
            .then(result => {
                this.allCategoryOptions = result.map(cat => ({
                    label: cat.Name,
                    value: cat.Name
                }));
            })
            .catch(error => {
                console.error(error);
            });

        getStoreAccessInfo()
            .then(result => {
                this.storeOptions = result.stores.map(store => ({
                    label: store.Name,
                    value: store.Id
                }));

                if (result.defaultStoreId) {
                    this.form.store = result.defaultStoreId;
                    this.isStoreDisabled = true;

                    getSalesExecutiveByStore({ storeId: result.defaultStoreId })
                        .then(execResult => {
                            this.salesExecutiveOptions = execResult.map(exec => ({
                                label: exec.Name,
                                value: exec.Id
                            }));
                        })
                        .catch(error => {
                            console.error(error);
                        });
                } else {
                    this.isStoreDisabled = false;
                }
            })
            .catch(error => {
                console.error(error);
            });
    }

    /* GETTERS FOR MULTISELECT */
    get availableCategoryOptions() {
        return this.allCategoryOptions.filter(
            option => !this.selectedCategories.includes(option.value)
        );
    }

    get availableSubCategoryOptions() {
        return this.allSubCategoryOptions.filter(
            option => !this.selectedSubCategories.includes(option.value)
        );
    }

    get isSubCategoryDisabled() {
        return this.allSubCategoryOptions.length === 0;
    }

    get isSalesExecutiveDisabled() {
        return !this.salesExecutiveOptions || this.salesExecutiveOptions.length === 0;
    }

    /* CATEGORY PILL LOGIC */
    handleCategorySelect(event) {
        const selectedVal = event.detail.value;
        if (selectedVal) {
            this.selectedCategories = [...this.selectedCategories, selectedVal];
            this.form.category = this.selectedCategories.join(', ');
            this.categoryError = '';

            const combobox = this.template.querySelector('.category-input');
            if (combobox) combobox.value = '';

            this.fetchSubCategories();
        }
    }

    handleCategoryRemove(event) {
        const removedVal = event.target.name;
        this.selectedCategories = this.selectedCategories.filter(cat => cat !== removedVal);
        this.form.category = this.selectedCategories.join(', ');

        this.fetchSubCategories();
    }

    /* SUB CATEGORY PILL LOGIC */
    handleSubCategorySelect(event) {
        const selectedVal = event.detail.value;
        if (selectedVal) {
            this.selectedSubCategories = [...this.selectedSubCategories, selectedVal];
            this.form.subCategory = this.selectedSubCategories.join(', ');
            this.subCategoryError = '';

            const combobox = this.template.querySelector('.subcategory-input');
            if (combobox) combobox.value = '';
        }
    }

    handleSubCategoryRemove(event) {
        const removedVal = event.target.name;
        this.selectedSubCategories = this.selectedSubCategories.filter(sub => sub !== removedVal);
        this.form.subCategory = this.selectedSubCategories.join(', ');
    }

    /* FETCH SUB CATEGORIES */
    fetchSubCategories() {
        this.allSubCategoryOptions = [];

        if (this.selectedCategories.length > 0) {
            getSubCategoriesByCategory({ categoryNames: this.selectedCategories })
                .then(result => {
                    this.allSubCategoryOptions = result.map(sub => ({
                        label: sub.Name,
                        value: sub.Name
                    }));

                    const validOptions = this.allSubCategoryOptions.map(opt => opt.value);
                    this.selectedSubCategories = this.selectedSubCategories.filter(sub => validOptions.includes(sub));
                    this.form.subCategory = this.selectedSubCategories.join(', ');
                })
                .catch(error => {
                    console.error(error);
                });
        } else {
            this.selectedSubCategories = [];
            this.form.subCategory = '';
        }
    }

    /* MULTIPLE FILE UPLOAD */
    /* MULTIPLE FILE UPLOAD */
    handleDesignFileUpload(event) {
        const files = Array.from(event.target.files);

        if (!files.length) {
            return;
        }

        const oversizedFiles = files.filter(file => file.size > this.MAX_FILE_SIZE);

        if (oversizedFiles.length > 0) {
            this.showToast(
                'File Size Error',
                'Maximum 5 MB file upload is allowed. Please upload file below 5 MB.',
                'error'
            );

            event.target.value = null;
            return;
        }

        this.isFileReading = true;

        const fileReadPromises = files.map(file => {
            return new Promise((resolve, reject) => {
                const reader = new FileReader();

                reader.onload = () => {
                    const base64 = reader.result.split(',')[1];

                    resolve({
                        fileName: file.name,
                        base64Data: base64,
                        contentType: file.type,
                        size: file.size
                    });
                };

                reader.onerror = () => {
                    reject(reader.error);
                };

                reader.readAsDataURL(file);
            });
        });

        Promise.all(fileReadPromises)
            .then(newFiles => {
                this.designFiles = [
                    ...this.designFiles,
                    ...newFiles
                ];

                this.form.designFiles = this.designFiles;

                this.showToast(
                    'File Uploaded',
                    'File selected successfully.',
                    'success'
                );
            })
            .catch(error => {
                console.error(error);
                this.showToast(
                    'File Upload Error',
                    'Unable to read selected file. Please try again.',
                    'error'
                );
            })
            .finally(() => {
                this.isFileReading = false;
                event.target.value = null;
            });
    }

    /* REMOVE SELECTED FILE */
    removeDesignFile(event) {
        const index = Number(event.currentTarget.dataset.index);
        this.designFiles = this.designFiles.filter((file, i) => i !== index);
        this.form.designFiles = this.designFiles;
    }

    /* PURPOSE SELECTION */
    selectPurpose(event) {
        const purposeId = event.currentTarget.dataset.id;
        const selected = this.purposeResults.find(p => p.Id === purposeId);

        if (selected) {
            this.selectedPurposeId = selected.Id;

            this.form = {
                ...this.form,
                purposeMasterId: selected.Id,
                purposeLevel1: selected.Purpose_Level_1__c,
                purposeLevel2: selected.Purpose_Level_2__c,
                purposeLevel3: selected.Purpose_Level_3__c,
                purposeSearch: selected.Purpose_Level_3__c
            };
        }

        this.purposeResults = [];
    }

    /* FIELD CHANGE HANDLER */
    updateField(event) {
        const field = event.target.dataset.field;
        let value = event.target.value;

        if (field === 'store') {
            this.form.salesExecutive = null;
            this.salesExecutiveOptions = [];

            if (value) {
                getSalesExecutiveByStore({ storeId: value })
                    .then(result => {
                        this.salesExecutiveOptions = result.map(exec => ({
                            label: exec.Name,
                            value: exec.Id
                        }));
                    })
                    .catch(error => {
                        console.error(error);
                    });
            }
        }

        if (field === 'phone') {
            value = value.replace(/[^0-9]/g, '');
            event.target.value = value;

            if (value.length >= 3) {
                searchAccountByPhone({ phone: value })
                    .then(result => {
                        this.matchedAccounts = result;
                    })
                    .catch(err => {
                        console.error(err);
                    });
            } else {
                this.matchedAccounts = [];
            }
        }

        if (field === 'purposeSearch') {
            this.form.purposeSearch = value;

            if (value && value.length >= 1) {
                searchPurpose({ searchKey: value })
                    .then(result => {
                        this.purposeResults = result;
                    })
                    .catch(error => {
                        console.error(error);
                        this.purposeResults = [];
                    });
            } else {
                this.purposeResults = [];
                this.selectedPurposeId = null;
                this.form.purposeMasterId = null;
                this.form.purposeLevel1 = '';
                this.form.purposeLevel2 = '';
                this.form.purposeLevel3 = '';
            }
        }

        if (field) {
            this.form[field] = value;
        }
    }

    /* SAVE BUTTON */
    saveRecord() {
        this.save(false);
    }

    /* SAVE & NEW BUTTON */
    saveAndNew() {
        this.save(true);
    }

    /* COMMON SAVE METHOD */
    /* COMMON SAVE METHOD */
    save(createNew) {
        if (this.isSaving || this.isFileReading) {
            this.showToast(
                'Please Wait',
                'File upload/save is already in progress.',
                'warning'
            );
            return;
        }

        if (!this.validateForm()) {
            return;
        }

        this.isSaving = true;

        saveDailyActivity({ formData: this.form, createNew })
            .then(newRecordId => {
                this.showToast('Success', 'Showroom Visit saved successfully!', 'success');

                if (createNew) {
                    this.resetForm();
                } else {
                    this.resetForm();

                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: newRecordId,
                            objectApiName: 'Showroom_Visit__c',
                            actionName: 'view'
                        }
                    });
                }
            })
            .catch(error => {
                console.error(error);
                this.showToast(
                    'Error',
                    error.body ? error.body.message : 'Unexpected error',
                    'error'
                );
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    /* RESET FORM */
    resetForm() {
        const today = this.getLocalDateString();
        const currentTime = this.getLocalTimeString();

        const defaultStore = this.isStoreDisabled ? this.form.store : null;

        this.form = {
            customer: '',
            phone: '',
            activityDate: today,
            activityTime: currentTime,
            description: '',
            category: '',
            subCategory: '',
            store: defaultStore,
            salesExecutive: null,
            netWeight: '',
            budget: null,
            accountId: null,

            purposeSearch: '',
            purposeMasterId: null,
            purposeLevel1: '',
            purposeLevel2: '',
            purposeLevel3: ''
        };

        this.designFiles = [];
        this.form.designFiles = [];

        this.matchedAccounts = [];
        this.selectedAccountId = null;

        this.purposeResults = [];
        this.selectedPurposeId = null;

        this.selectedCategories = [];
        this.selectedSubCategories = [];
        this.allSubCategoryOptions = [];
        this.categoryError = '';
        this.subCategoryError = '';

        if (!this.isStoreDisabled) {
            this.salesExecutiveOptions = [];
        }
    }

    /* SELECT CUSTOMER */
    selectAccount(event) {
        const accId = event.currentTarget.dataset.id;
        const selected = this.matchedAccounts.find(a => a.Id === accId);

        if (selected) {
            this.form.customer = selected.Name;
            this.form.accountId = selected.Id;

            const phoneValue = selected.Phone
                ? selected.Phone
                : selected.Whatsapp_Number__c;

            this.form.phone = phoneValue;

            const customerInput = this.template.querySelector('lightning-input[data-field="customer"]');
            const phoneInput = this.template.querySelector('lightning-input[data-field="phone"]');

            if (customerInput) {
                customerInput.value = selected.Name;
            }

            if (phoneInput) {
                phoneInput.value = phoneValue;
            }
        }

        this.matchedAccounts = [];
    }

    /* TOAST MESSAGE */
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    /* FORM VALIDATION */
    validateForm() {
        let isValid = true;

        // const requiredFields = this.template.querySelectorAll(
        //     'lightning-input[data-required="true"], lightning-textarea[data-required="true"]'
        // );
        const requiredFields = this.template.querySelectorAll(
            'lightning-input[data-required="true"], lightning-textarea[data-required="true"], lightning-combobox[data-required="true"]'
        );

        requiredFields.forEach(field => {
            let message = '';
            const value = field.value ? field.value.trim() : '';

            if (!value && field.dataset.field !== 'phone') {
                message = 'This field is required';
            }
            // Specific validation for Sales Executive
            if (field.dataset.field === 'salesExecutive' && !value) {
                message = 'Please select Sales Executive';
            }

            if (field.dataset.field === 'description' && value && value.length < 10) {
                message = 'Description must be at least 10 characters';
            }

            if (field.dataset.field === 'activityDate') {
                message = this.validateActivityDate(value);
            }

            if (field.dataset.field === 'phone') {
                const digitsOnly = value.replace(/\D/g, '');

                if (digitsOnly.length > 10) {
                    message = 'Phone number cannot exceed 10 digits';
                }

                this.form.phone = digitsOnly;
            }

            field.setCustomValidity(message);
            field.reportValidity();

            if (message) {
                isValid = false;
            }
        });

        // // Pill validation logic
        // if (this.selectedCategories.length === 0) {
        //     this.categoryError = 'Please select at least one Category.';
        //     isValid = false;
        // } else {
        //     this.categoryError = '';
        // }

        // if (this.selectedSubCategories.length === 0 && this.allSubCategoryOptions.length > 0) {
        //     this.subCategoryError = 'Please select at least one Sub Category.';
        //     isValid = false;
        // } else {
        //     this.subCategoryError = '';
        // }

        const hasPurpose = this.form.purposeMasterId;
        const descriptionValue = this.form.description ? this.form.description.trim() : '';
        const descriptionField = this.template.querySelector(
            'lightning-textarea[data-field="description"]'
        );

        if (descriptionField) {
            if (!hasPurpose && !descriptionValue) {
                descriptionField.setCustomValidity('Description is required if Purpose is not selected.');
                descriptionField.reportValidity();
                isValid = false;
            } else if (descriptionValue && descriptionValue.length < 10) {
                descriptionField.setCustomValidity('Description must be at least 10 characters.');
                descriptionField.reportValidity();
                isValid = false;
            } else {
                descriptionField.setCustomValidity('');
                descriptionField.reportValidity();
            }
        }

        return isValid;
    }

    /* CANCEL BUTTON */
    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}