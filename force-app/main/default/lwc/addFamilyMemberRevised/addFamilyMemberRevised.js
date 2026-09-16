import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';

import getCurrentAccount from '@salesforce/apex/AddFamilyMemberControllerRevised.getCurrentAccount';
import searchAccountsByPhone from '@salesforce/apex/AddFamilyMemberControllerRevised.searchAccountsByPhone';
import saveFamilyMember from '@salesforce/apex/AddFamilyMemberControllerRevised.saveFamilyMember';

export default class AddFamilyMemberRevised extends LightningElement {

    _recordId;
    pageRef;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        if (value) {
            this._recordId = value;
            this.loadCurrentAccount();
        }
    }

    @track currentAccount;
    @track currentAccountGender = '';
    @track phone = '';
    @track phoneError = '';
    @track familyMemberName = '';
    @track relationshipType = '';
    @track existingAccounts = [];
    @track selectedExistingAccountId = null;

    isLoading = false;
    searchTimeout;
    currentAccountLoaded = false;

    genderOptions = [
        { label: 'Male', value: 'Male' },
        { label: 'Female', value: 'Female' },
        { label: 'Other', value: 'Other' },
        { label: 'Prefer not to say', value: 'Prefer not to say' }
    ];

    relationshipOptions = [
        { label: 'Father', value: 'Father' },
        { label: 'Mother', value: 'Mother' },
        { label: 'Daughter', value: 'Daughter' },
        { label: 'Son', value: 'Son' },
        { label: 'Sister', value: 'Sister' },
        { label: 'Brother', value: 'Brother' },
        { label: 'Husband', value: 'Husband' },
        { label: 'Wife', value: 'Wife' },
        { label: 'Grandfather', value: 'Grandfather' },
        { label: 'Grandmother', value: 'Grandmother' },
        { label: 'Cousin', value: 'Cousin' },
        { label: 'Father In-laws', value: 'Father In-laws' },
        { label: 'Mother In-laws', value: 'Mother In-laws' },
        { label: 'Son In-laws', value: 'Son In-laws' },
        { label: 'Daughter In-laws', value: 'Daughter In-laws' },
        { label: 'Brother In-laws', value: 'Brother In-laws' },
        { label: 'Sister In-laws', value: 'Sister In-laws' },
        { label: 'Niece', value: 'Niece' },
        { label: 'Nephew', value: 'Nephew' },
        { label: 'Friend', value: 'Friend' },
        { label: 'Aunt', value: 'Aunt' },
        { label: 'Uncle', value: 'Uncle' },
        { label: 'Maternal Grandmother', value: 'Maternal Grandmother' },
        { label: 'Maternal Grandfather', value: 'Maternal Grandfather' },
        { label: 'Grandson', value: 'Grandson' },
        { label: 'Granddaughter', value: 'Granddaughter' },
        { label: 'Other', value: 'Other' }

    ];

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        this.pageRef = pageRef;

        const resolvedId = this.resolveRecordId();

        if (resolvedId && !this._recordId) {
            this._recordId = resolvedId;
            this.loadCurrentAccount();
        }
    }

    connectedCallback() {
        setTimeout(() => {
            const resolvedId = this.resolveRecordId();

            if (resolvedId && !this._recordId) {
                this._recordId = resolvedId;
                this.loadCurrentAccount();
            }
        }, 300);
    }

    resolveRecordId() {
        if (this._recordId) {
            return this._recordId;
        }

        if (this.pageRef) {
            if (this.pageRef.state) {
                if (this.pageRef.state.recordId) {
                    return this.pageRef.state.recordId;
                }

                if (this.pageRef.state.c__recordId) {
                    return this.pageRef.state.c__recordId;
                }

                if (this.pageRef.state.id) {
                    return this.pageRef.state.id;
                }

                if (this.pageRef.state.backgroundContext) {
                    const bgId = this.extractRecordIdFromText(this.pageRef.state.backgroundContext);
                    if (bgId) {
                        return bgId;
                    }
                }
            }

            if (this.pageRef.attributes && this.pageRef.attributes.recordId) {
                return this.pageRef.attributes.recordId;
            }
        }

        try {
            const url = window.location.href;
            const urlId = this.extractRecordIdFromText(url);

            if (urlId) {
                return urlId;
            }
        } catch (e) {
            // Ignore URL parsing error.
        }

        return null;
    }

    extractRecordIdFromText(textValue) {
        if (!textValue) {
            return null;
        }

        let text = textValue;

        try {
            text = decodeURIComponent(text);
        } catch (e) {
            // Ignore decoding error.
        }

        const accountIdMatch = text.match(/001[A-Za-z0-9]{12,15}/);

        if (accountIdMatch && accountIdMatch[0]) {
            return accountIdMatch[0];
        }

        return null;
    }

    loadCurrentAccount() {
        const accId = this.resolveRecordId();

        if (!accId || this.currentAccountLoaded) {
            return;
        }

        this._recordId = accId;
        this.currentAccountLoaded = true;

        getCurrentAccount({ accountId: accId })
            .then(result => {
                this.currentAccount = result;
                console.log('Current Account Loaded:', JSON.stringify(result));
            })
            .catch(error => {
                this.currentAccountLoaded = false;
                this.showToast('Error', this.reduceError(error), 'error');
            });
    }

    get showExistingAccounts() {
        return this.existingAccounts && this.existingAccounts.length > 0;
    }

    get showNameInput() {
        return this.phone && this.phone.length === 10 && !this.phoneError;
    }

    get disableSave() {
        return this.isLoading === true;
    }

    handleGenderChange(event) {
        this.currentAccountGender = event.detail.value;
    }

    handlePhoneChange(event) {
        let value = event.target.value || '';

        value = value.replace(/\D/g, '');

        if (value.length > 10) {
            value = value.substring(0, 10);
        }

        this.phone = value;
        event.target.value = value;

        this.phoneError = '';
        this.selectedExistingAccountId = null;
        this.existingAccounts = [];
        this.familyMemberName = '';

        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }

        if (value.length !== 10) {
            if (value.length > 0) {
                this.phoneError = 'Please enter valid 10 digit phone number.';
            }
            return;
        }

        this.validateCurrentPhone();

        if (this.phoneError) {
            return;
        }

        this.searchTimeout = setTimeout(() => {
            this.searchExistingAccounts();
        }, 400);
    }

    validateCurrentPhone() {
        if (!this.currentAccount || !this.currentAccount.Phone) {
            return;
        }

        let currentPhone = this.normalizePhone(this.currentAccount.Phone);

        if (currentPhone === this.phone) {
            this.phoneError = 'Please input different phone number. This phone number belongs to current customer.';
        }
    }

    searchExistingAccounts() {
        const currentId = this.resolveRecordId();

        searchAccountsByPhone({ phone: this.phone })
            .then(result => {
                let rows = result || [];

                rows = rows.filter(acc => acc.accountId !== currentId);

                this.existingAccounts = rows.map(acc => {
                    return {
                        ...acc,
                        initial: this.getInitial(acc.name),
                        isSelected: false,
                        rowClass: 'accountCard'
                    };
                });

                if (this.existingAccounts.length === 1) {
                    this.familyMemberName = this.existingAccounts[0].name;
                }
            })
            .catch(error => {
                this.showToast('Error', this.reduceError(error), 'error');
            });
    }

    handleSelectAccount(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selectedName = event.currentTarget.dataset.name;

        this.selectedExistingAccountId = selectedId;
        this.familyMemberName = selectedName;

        this.existingAccounts = this.existingAccounts.map(acc => {
            const selected = acc.accountId === selectedId;

            return {
                ...acc,
                isSelected: selected,
                rowClass: selected ? 'accountCard selectedCard' : 'accountCard'
            };
        });
    }

    handleNameChange(event) {
        this.familyMemberName = event.target.value;
    }

    handleRelationChange(event) {
        this.relationshipType = event.detail.value;
    }

    handleSave() {
        const currentId = this._recordId || this.resolveRecordId();

        if (currentId && !this._recordId) {
            this._recordId = currentId;
        }

        const inputFields = this.template.querySelectorAll(
            'lightning-input, lightning-combobox'
        );

        let allValid = true;

        inputFields.forEach(inputCmp => {
            inputCmp.reportValidity();

            if (!inputCmp.checkValidity()) {
                allValid = false;
            }
        });

        if (!allValid) {
            return;
        }

        if (!currentId) {
            this.showToast(
                'Error',
                'Current Account Id is missing. Please open this action from Account record.',
                'error'
            );
            return;
        }

        if (!this.currentAccountGender) {
            this.showToast('Error', 'Please select current account gender.', 'error');
            return;
        }

        if (!this.phone || this.phone.length !== 10) {
            this.showToast('Error', 'Phone number must be exactly 10 digits.', 'error');
            return;
        }

        this.validateCurrentPhone();

        if (this.phoneError) {
            this.showToast('Error', this.phoneError, 'error');
            return;
        }

        if (!this.familyMemberName || this.familyMemberName.trim() === '') {
            this.showToast('Error', 'Please enter family member name.', 'error');
            return;
        }

        if (this.showExistingAccounts && !this.selectedExistingAccountId) {
            this.showToast(
                'Error',
                'Existing Account found. Please select existing Account before saving.',
                'error'
            );
            return;
        }

        if (!this.relationshipType) {
            this.showToast('Error', 'Please select relationship type.', 'error');
            return;
        }

        this.isLoading = true;

        console.log('Current Id Before Save:', currentId);
        console.log('Save Values:', JSON.stringify({
            currentAccountId: currentId,
            currentAccountGender: this.currentAccountGender,
            phone: this.phone,
            familyMemberName: this.familyMemberName,
            relationshipType: this.relationshipType,
            selectedExistingAccountId: this.selectedExistingAccountId
        }));

        saveFamilyMember({
            currentAccountId: currentId,
            currentAccountGender: this.currentAccountGender,
            phone: this.phone,
            familyMemberName: this.familyMemberName,
            relationshipType: this.relationshipType,
            selectedExistingAccountId: this.selectedExistingAccountId
        })
            .then(result => {
                if (result && result.success) {
                    this.showToast('Success', result.message, 'success');

                    this.dispatchEvent(new RefreshEvent());
                    this.dispatchEvent(new CloseActionScreenEvent());
                } else {
                    this.showToast('Error', 'Something went wrong.', 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', this.reduceError(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    normalizePhone(value) {
        if (!value) {
            return '';
        }

        let phone = value.replace(/\D/g, '');

        if (phone.length > 10) {
            phone = phone.substring(phone.length - 10);
        }

        return phone;
    }

    getInitial(name) {
        if (!name) {
            return '?';
        }

        return name.substring(0, 1).toUpperCase();
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

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (
            error &&
            error.body &&
            error.body.pageErrors &&
            error.body.pageErrors.length > 0
        ) {
            return error.body.pageErrors[0].message;
        }

        if (
            error &&
            error.body &&
            error.body.fieldErrors
        ) {
            const fieldErrors = error.body.fieldErrors;
            const fieldNames = Object.keys(fieldErrors);

            if (fieldNames.length > 0) {
                return fieldErrors[fieldNames[0]][0].message;
            }
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Something went wrong.';
    }
}