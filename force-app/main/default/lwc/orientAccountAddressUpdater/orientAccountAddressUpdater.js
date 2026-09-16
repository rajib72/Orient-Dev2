import { LightningElement, api, track } from 'lwc';
import getAccountSeed from '@salesforce/apex/OrientAccountAddressLookupController.getAccountSeed';
import getPostCodesByPin from '@salesforce/apex/OrientAccountAddressLookupController.getPostCodesByPin';
import getStateByCode from '@salesforce/apex/OrientAccountAddressLookupController.getStateByCode';
import getVillagesByPin from '@salesforce/apex/OrientAccountAddressLookupController.getVillagesByPin';
import updateAccountAddress from '@salesforce/apex/OrientAccountAddressLookupController.updateAccountAddress';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

export default class OrientAccountAddressLookup extends LightningElement {
    _recordId;
    _hasInit = false;

    @track isLoading = false;
    @track isSearching = false;
    @track isSaving = false;

    @track seed;
    @track pinCode = '';

    // Raw Data Stores
    rawPostalData = [];
    rawVillageData = [];
    stateMap = {};

    // Dropdown Options
    @track stateOptions = [];
    @track districtOptions = [];
    @track cityOptions = [];
    @track villageOptions = [];

    // Selected Values
    @track selectedStateVal = '';
    @track selectedDistrictVal = '';
    @track selectedCityVal = '';
    @track selectedVillageVal = '';

    // Searchable Village Variables
    @track villageSearchTerm = '';
    @track filteredVillageOptions = [];
    @track isVillageDropdownOpen = false;

    // Final selected objects for the update payload
    selectedPostalRecord = null;
    selectedStateRecord = null;
    selectedVillageRecord = null;

    @track errorMessage;
    @track infoMessage;

    @api
    set recordId(value) {
        this._recordId = value;
        if (value && !this._hasInit) {
            this._hasInit = true;
            this.initialize();
        }
    }
    get recordId() { return this._recordId; }

    async initialize() {
        this.isLoading = true;
        this.clearMessages();

        try {
            this.seed = await getAccountSeed({ accountId: this.recordId });
            this.pinCode = this.seed?.pinCode || '';

            if (this.pinCode) {
                await this.searchByPin();
            }
        } catch (e) {
            this.handleError(e, 'Failed to load account.');
        } finally {
            this.isLoading = false;
        }
    }

    handlePinChange(event) {
        this.pinCode = event.target.value;
    }

    async handleSearch() {
        await this.searchByPin();
    }

    async searchByPin() {
        if (!this.pinCode) {
            this.toast('Warning', 'Please enter a Pin Code.', 'warning');
            return;
        }

        this.isSearching = true;
        this.clearMessages();
        this.resetSelections();
        this.rawPostalData = [];

        try {
            const resp = await getPostCodesByPin({ pinCode: this.pinCode });

            if (!resp || resp.status !== 'Success' || !resp.postalOptions || resp.postalOptions.length === 0) {
                this.infoMessage = resp?.message || 'No postcode records found.';
                return;
            }

            this.rawPostalData = resp.postalOptions;

            // 1. Fetch missing state definitions
            const uniqueStateCodes = [...new Set(this.rawPostalData.map(r => r.stateCode).filter(Boolean))];
            for (const code of uniqueStateCodes) {
                if (!this.stateMap[code]) {
                    try {
                        this.stateMap[code] = await getStateByCode({ stateCode: code });
                    } catch (err) {
                        console.error('Error fetching state for code:', code, err);
                    }
                }
            }

            // 2. Build State Options
            this.stateOptions = uniqueStateCodes.map(code => ({
                label: this.stateMap[code] ? this.stateMap[code].description : code,
                value: code
            }));

            // Auto-select if only 1 state
            if (this.stateOptions.length === 1) {
                this.selectedStateVal = this.stateOptions[0].value;
                this.processStateSelection();
            }

        } catch (e) {
            this.handleError(e, 'Failed to load postcode data.');
        } finally {
            this.isSearching = false;
        }
    }

    handleStateChange(event) {
        this.selectedStateVal = event.detail.value;
        this.selectedDistrictVal = '';
        this.selectedCityVal = '';
        this.resetVillageData();
        this.districtOptions = [];
        this.cityOptions = [];
        this.processStateSelection();
    }

    processStateSelection() {
        this.selectedStateRecord = this.stateMap[this.selectedStateVal];

        // Filter raw data by selected state to get available districts
        const availableDistricts = [...new Set(
            this.rawPostalData
                .filter(p => p.stateCode === this.selectedStateVal)
                .map(p => p.district)
                .filter(Boolean)
        )];

        this.districtOptions = availableDistricts.map(d => ({ label: d, value: d }));

        // Auto-select if only 1 district
        if (this.districtOptions.length === 1) {
            this.selectedDistrictVal = this.districtOptions[0].value;
            this.processDistrictSelection();
        }
    }

    handleDistrictChange(event) {
        this.selectedDistrictVal = event.detail.value;
        this.selectedCityVal = '';
        this.resetVillageData();
        this.cityOptions = [];
        this.processDistrictSelection();
    }

    processDistrictSelection() {
        // Filter raw data by state AND district to get available cities
        const availableCities = [...new Set(
            this.rawPostalData
                .filter(p => p.stateCode === this.selectedStateVal && p.district === this.selectedDistrictVal)
                .map(p => p.city)
                .filter(Boolean)
        )];

        this.cityOptions = availableCities.map(c => ({ label: c, value: c }));

        // Auto-select if only 1 city
        if (this.cityOptions.length === 1) {
            this.selectedCityVal = this.cityOptions[0].value;
            this.processCitySelection();
        }
    }

    handleCityChange(event) {
        this.selectedCityVal = event.detail.value;
        this.resetVillageData();
        this.processCitySelection();
    }

    async processCitySelection() {
        // Identify the exact postal record based on State + District + City
        this.selectedPostalRecord = this.rawPostalData.find(
            p => p.stateCode === this.selectedStateVal &&
                p.district === this.selectedDistrictVal &&
                p.city === this.selectedCityVal
        );

        if (this.selectedPostalRecord && this.selectedPostalRecord.code) {
            await this.loadVillages();
        }
    }

    async loadVillages() {
        this.isSearching = true;
        this.resetVillageData();

        try {
            const resp = await getVillagesByPin({ pinCode: this.selectedPostalRecord.code });

            if (resp && resp.status === 'Success' && resp.villageOptions) {
                this.rawVillageData = resp.villageOptions;
                this.villageOptions = this.rawVillageData.map(v => ({
                    label: v.name,
                    value: v.name
                }));

                // Initialize filtered options for the searchable dropdown
                this.filteredVillageOptions = [...this.villageOptions];
                this.villageSearchTerm = '';
            } else {
                this.infoMessage = resp?.message || 'No villages found.';
            }
        } catch (e) {
            this.handleError(e, 'Failed to load village data.');
        } finally {
            this.isSearching = false;
        }
    }

    // --- Searchable Village Methods ---

    openVillageDropdown() {
        if (!this.isVillageDisabled) {
            this.isVillageDropdownOpen = true;
            this.filteredVillageOptions = this.villageSearchTerm
                ? this.villageOptions.filter(opt => opt.label.toLowerCase().includes(this.villageSearchTerm.toLowerCase()))
                : [...this.villageOptions];
        }
    }

    closeVillageDropdown() {
        this.isVillageDropdownOpen = false;
        // If they leave without a valid selection, revert the text
        if (!this.selectedVillageVal) {
            this.villageSearchTerm = '';
        } else {
            this.villageSearchTerm = this.selectedVillageVal;
        }
    }

    handleVillageSearch(event) {
        this.villageSearchTerm = event.target.value;
        this.isVillageDropdownOpen = true;

        if (this.villageSearchTerm) {
            const searchTerm = this.villageSearchTerm.toLowerCase();
            this.filteredVillageOptions = this.villageOptions.filter(opt =>
                opt.label.toLowerCase().includes(searchTerm)
            );
        } else {
            this.filteredVillageOptions = [...this.villageOptions];
            this.selectedVillageVal = '';
            this.selectedVillageRecord = null;
        }
    }

    handleVillageSelect(event) {
        const selectedValue = event.currentTarget.dataset.value;
        const selectedOption = this.villageOptions.find(opt => opt.value === selectedValue);

        if (selectedOption) {
            this.selectedVillageVal = selectedValue;
            this.villageSearchTerm = selectedOption.label;
            this.selectedVillageRecord = this.rawVillageData.find(v => v.name === selectedValue);
        }

        this.isVillageDropdownOpen = false;
    }

    // --- Core Logic & API Calls ---

    async handleUpdateAddress() {
        this.isSaving = true;
        this.clearMessages();

        try {
            const resp = await updateAccountAddress({
                accountId: this.recordId,
                selectedPinCode: this.selectedPostalRecord.code,
                selectedCity: this.selectedPostalRecord.city,
                selectedCountryRegionCode: this.selectedPostalRecord.countryRegionCode || 'IN',
                selectedCounty: this.selectedPostalRecord.county || 'INDIA',
                selectedDistrict: this.selectedPostalRecord.district,
                selectedStateCode: this.selectedStateRecord?.code || this.selectedPostalRecord.stateCode,
                selectedStateDescription: this.selectedStateRecord?.description || null,
                selectedLocalityArea: this.selectedPostalRecord.searchCity || this.selectedPostalRecord.district,
                selectedGST: this.selectedStateRecord?.stateCodeGSTRegNo || null,
                selectedVillage: this.selectedVillageRecord?.name || null
            });

            this.toast('Success', resp.message, 'success');
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (e) {
            this.handleError(e, 'Failed to update address.');
        } finally {
            this.isSaving = false;
        }
    }

    // --- Helper Getters & Methods ---

    get hasPostalData() { return this.rawPostalData && this.rawPostalData.length > 0; }
    get isDistrictDisabled() { return !this.selectedStateVal || this.districtOptions.length === 0; }
    get isCityDisabled() { return !this.selectedDistrictVal || this.cityOptions.length === 0; }
    get isVillageDisabled() { return !this.selectedCityVal || this.villageOptions.length === 0; }

    get villageComboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${this.isVillageDropdownOpen ? 'slds-is-open' : ''}`;
    }

    get hasFilteredVillages() {
        return this.filteredVillageOptions && this.filteredVillageOptions.length > 0;
    }

    get searchButtonDisabled() { return this.isSearching || this.isSaving || !this.pinCode; }

    get updateButtonDisabled() {
        return this.isSearching ||
            this.isSaving ||
            !this.selectedPostalRecord ||
            !this.selectedStateRecord ||
            !this.selectedVillageVal;
    }

    clearMessages() {
        this.errorMessage = null;
        this.infoMessage = null;
    }

    resetVillageData() {
        this.selectedVillageVal = '';
        this.villageSearchTerm = '';
        this.villageOptions = [];
        this.filteredVillageOptions = [];
        this.selectedVillageRecord = null;
    }

    resetSelections() {
        this.stateOptions = [];
        this.districtOptions = [];
        this.cityOptions = [];
        this.selectedStateVal = '';
        this.selectedDistrictVal = '';
        this.selectedCityVal = '';
        this.selectedPostalRecord = null;
        this.selectedStateRecord = null;
        this.resetVillageData();
    }

    handleError(e, fallbackMsg) {
        this.errorMessage = e?.body?.message || e?.message || fallbackMsg;
        this.toast('Error', this.errorMessage, 'error');
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}