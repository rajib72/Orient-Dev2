import { LightningElement, api, track } from 'lwc';
import FORM_FACTOR from '@salesforce/client/formFactor';

import getPostCodesByPin
    from '@salesforce/apex/Ctrl_OrientCustomerAddressSelection.getPostCodesByPin';
import getStateByCode
    from '@salesforce/apex/Ctrl_OrientCustomerAddressSelection.getStateByCode';
import getVillagesByPin
    from '@salesforce/apex/Ctrl_OrientCustomerAddressSelection.getVillagesByPin';

export default class LwcOrientCustomerAddressSelector extends LightningElement {
    _initialPinCode = '';
    initialized = false;

    @track pinCode = '';

    @track isSearching = false;
    @track errorMessage = '';
    @track infoMessage = '';

    rawPostalData = [];
    rawVillageData = [];
    stateMap = {};

    @track stateOptions = [];
    @track districtOptions = [];
    @track cityOptions = [];
    @track villageOptions = [];

    @track selectedStateVal = '';
    @track selectedDistrictVal = '';
    @track selectedCityVal = '';
    @track selectedVillageVal = '';

    @track villageSearchTerm = '';
    @track filteredVillageOptions = [];
    @track isVillageDropdownOpen = false;

    selectedPostalRecord = null;
    selectedStateRecord = null;
    selectedVillageRecord = null;

    @api
    set initialPinCode(value) {
        const nextValue =
            value === undefined ||
            value === null
                ? ''
                : String(value).trim();

        this._initialPinCode =
            nextValue;

        if (!this.initialized) {
            this.pinCode =
                nextValue;
        }
    }

    get initialPinCode() {
        return this._initialPinCode;
    }

    connectedCallback() {
        this.initialized = true;

        if (!this.pinCode) {
            this.pinCode =
                this._initialPinCode;
        }
    }

    get selectorShellClass() {
        return FORM_FACTOR === 'Large'
            ? 'selector-shell selector-shell-desktop'
            : 'selector-shell selector-shell-mobile';
    }

    get isBusy() {
        return this.isSearching;
    }

    get showSpinner() {
        return this.isSearching;
    }

    get hasPostalData() {
        return (
            Array.isArray(this.rawPostalData) &&
            this.rawPostalData.length > 0
        );
    }

    get isDistrictDisabled() {
        return (
            !this.selectedStateVal ||
            this.districtOptions.length === 0
        );
    }

    get isCityDisabled() {
        return (
            !this.selectedDistrictVal ||
            this.cityOptions.length === 0
        );
    }

    get isVillageDisabled() {
        return (
            !this.selectedCityVal ||
            this.villageOptions.length === 0
        );
    }

    get villageComboboxClass() {
        return (
            'slds-combobox ' +
            'slds-dropdown-trigger ' +
            'slds-dropdown-trigger_click ' +
            (
                this.isVillageDropdownOpen
                    ? 'slds-is-open'
                    : ''
            )
        );
    }

    get hasFilteredVillages() {
        return (
            Array.isArray(
                this.filteredVillageOptions
            ) &&
            this.filteredVillageOptions.length > 0
        );
    }

    get searchButtonDisabled() {
        return (
            this.isBusy ||
            !String(this.pinCode || '').trim()
        );
    }

    get hasCompleteSelection() {
        return Boolean(
            this.selectedPostalRecord &&
            this.selectedStateRecord &&
            this.selectedVillageRecord &&
            this.selectedStateVal &&
            this.selectedDistrictVal &&
            this.selectedCityVal &&
            this.selectedVillageVal
        );
    }

    get useAddressDisabled() {
        return (
            this.isBusy ||
            !this.hasCompleteSelection
        );
    }

    get selectedAddressSummary() {
        if (!this.hasCompleteSelection) {
            return '';
        }

        return [
            this.selectedVillageRecord?.name,
            this.selectedPostalRecord?.city,
            this.selectedPostalRecord?.district,
            this.selectedStateRecord?.description,
            this.selectedPostalRecord?.code
        ]
            .filter(Boolean)
            .join(', ');
    }

    handlePinChange(event) {
        this.pinCode =
            event.target.value;

        this.clearMessages();
    }

    async handleSearch() {
        await this.searchByPin();
    }

    async searchByPin() {
        const requestedPin =
            String(this.pinCode || '').trim();

        if (!requestedPin) {
            this.errorMessage =
                'Please enter a Pin Code.';
            return;
        }

        this.pinCode =
            requestedPin;
        this.isSearching =
            true;
        this.clearMessages();
        this.resetSelections();
        this.rawPostalData = [];

        try {
            const response =
                await getPostCodesByPin({
                    pinCode:
                        requestedPin
                });

            if (
                !response ||
                response.status !== 'Success' ||
                !Array.isArray(
                    response.postalOptions
                ) ||
                response.postalOptions.length === 0
            ) {
                this.infoMessage =
                    response?.message ||
                    'No postcode records found.';
                return;
            }

            this.rawPostalData =
                response.postalOptions;

            const uniqueStateCodes = [
                ...new Set(
                    this.rawPostalData
                        .map(
                            row =>
                                row.stateCode
                        )
                        .filter(Boolean)
                )
            ];

            for (
                const stateCode of
                uniqueStateCodes
            ) {
                if (
                    this.stateMap[
                        stateCode
                    ]
                ) {
                    continue;
                }

                this.stateMap = {
                    ...this.stateMap,
                    [stateCode]:
                        await getStateByCode({
                            stateCode
                        })
                };
            }

            this.stateOptions =
                uniqueStateCodes.map(
                    stateCode => ({
                        label:
                            this.stateMap[
                                stateCode
                            ]?.description ||
                            stateCode,
                        value:
                            stateCode
                    })
                );

            if (
                this.stateOptions.length === 1
            ) {
                this.selectedStateVal =
                    this.stateOptions[0].value;
                this.processStateSelection();
            }
        } catch (error) {
            this.handleError(
                error,
                'Failed to load postcode data.'
            );
        } finally {
            this.isSearching =
                false;
        }
    }

    handleStateChange(event) {
        this.selectedStateVal =
            event.detail.value;
        this.selectedDistrictVal =
            '';
        this.selectedCityVal =
            '';
        this.resetVillageData();
        this.districtOptions =
            [];
        this.cityOptions =
            [];
        this.processStateSelection();
    }

    processStateSelection() {
        this.selectedStateRecord =
            this.stateMap[
                this.selectedStateVal
            ] || null;

        const availableDistricts = [
            ...new Set(
                this.rawPostalData
                    .filter(
                        postal =>
                            postal.stateCode ===
                            this.selectedStateVal
                    )
                    .map(
                        postal =>
                            postal.district
                    )
                    .filter(Boolean)
            )
        ];

        this.districtOptions =
            availableDistricts.map(
                district => ({
                    label:
                        district,
                    value:
                        district
                })
            );

        if (
            this.districtOptions.length === 1
        ) {
            this.selectedDistrictVal =
                this.districtOptions[0].value;
            this.processDistrictSelection();
        }
    }

    handleDistrictChange(event) {
        this.selectedDistrictVal =
            event.detail.value;
        this.selectedCityVal =
            '';
        this.resetVillageData();
        this.cityOptions =
            [];
        this.processDistrictSelection();
    }

    processDistrictSelection() {
        const availableCities = [
            ...new Set(
                this.rawPostalData
                    .filter(
                        postal =>
                            postal.stateCode ===
                                this.selectedStateVal &&
                            postal.district ===
                                this.selectedDistrictVal
                    )
                    .map(
                        postal =>
                            postal.city
                    )
                    .filter(Boolean)
            )
        ];

        this.cityOptions =
            availableCities.map(
                city => ({
                    label:
                        city,
                    value:
                        city
                })
            );

        if (
            this.cityOptions.length === 1
        ) {
            this.selectedCityVal =
                this.cityOptions[0].value;
            this.processCitySelection();
        }
    }

    handleCityChange(event) {
        this.selectedCityVal =
            event.detail.value;
        this.resetVillageData();
        this.processCitySelection();
    }

    async processCitySelection() {
        this.selectedPostalRecord =
            this.rawPostalData.find(
                postal =>
                    postal.stateCode ===
                        this.selectedStateVal &&
                    postal.district ===
                        this.selectedDistrictVal &&
                    postal.city ===
                        this.selectedCityVal
            ) || null;

        if (
            this.selectedPostalRecord?.code
        ) {
            await this.loadVillages();
        }
    }

    async loadVillages() {
        this.isSearching =
            true;
        this.resetVillageData();

        try {
            const response =
                await getVillagesByPin({
                    pinCode:
                        this.selectedPostalRecord.code
                });

            if (
                response?.status ===
                    'Success' &&
                Array.isArray(
                    response.villageOptions
                )
            ) {
                this.rawVillageData =
                    response.villageOptions;

                this.villageOptions =
                    this.rawVillageData.map(
                        village => ({
                            label:
                                village.name,
                            value:
                                village.name
                        })
                    );

                this.filteredVillageOptions = [
                    ...this.villageOptions
                ];
                this.villageSearchTerm =
                    '';

                if (
                    this.villageOptions.length ===
                    0
                ) {
                    this.infoMessage =
                        response?.message ||
                        'No villages found.';
                }
            } else {
                this.infoMessage =
                    response?.message ||
                    'No villages found.';
            }
        } catch (error) {
            this.handleError(
                error,
                'Failed to load village data.'
            );
        } finally {
            this.isSearching =
                false;
        }
    }

    openVillageDropdown() {
        if (this.isVillageDisabled) {
            return;
        }

        this.isVillageDropdownOpen =
            true;
        this.filterVillages();
    }

    closeVillageDropdown() {
        window.setTimeout(() => {
            this.isVillageDropdownOpen =
                false;

            this.villageSearchTerm =
                this.selectedVillageVal ||
                '';
        }, 100);
    }

    handleVillageSearch(event) {
        this.villageSearchTerm =
            event.target.value;
        this.isVillageDropdownOpen =
            true;

        if (
            this.selectedVillageVal &&
            this.villageSearchTerm !==
                this.selectedVillageVal
        ) {
            this.selectedVillageVal =
                '';
            this.selectedVillageRecord =
                null;
        }

        this.filterVillages();
    }

    filterVillages() {
        const searchTerm =
            String(
                this.villageSearchTerm ||
                ''
            )
                .trim()
                .toLowerCase();

        this.filteredVillageOptions =
            searchTerm
                ? this.villageOptions.filter(
                    option =>
                        String(
                            option.label ||
                            ''
                        )
                            .toLowerCase()
                            .includes(
                                searchTerm
                            )
                )
                : [
                    ...this.villageOptions
                ];
    }

    handleVillageSelect(event) {
        const selectedValue =
            event.currentTarget
                .dataset.value;

        const selectedOption =
            this.villageOptions.find(
                option =>
                    option.value ===
                    selectedValue
            );

        if (!selectedOption) {
            return;
        }

        this.selectedVillageVal =
            selectedValue;
        this.villageSearchTerm =
            selectedOption.label;
        this.selectedVillageRecord =
            this.rawVillageData.find(
                village =>
                    village.name ===
                    selectedValue
            ) || null;
        this.isVillageDropdownOpen =
            false;
    }

    handleUseAddress() {
        if (!this.hasCompleteSelection) {
            return;
        }

        const values = {
            Pin_Code__c:
                this.selectedPostalRecord.code,
            Residential_City__c:
                this.selectedPostalRecord.city,
            Country__c:
                this.selectedPostalRecord.county ||
                'INDIA',
            Country_Region_Code__c:
                this.selectedPostalRecord
                    .countryRegionCode ||
                'IN',
            District__c:
                this.selectedPostalRecord.district,
            StateCode__c:
                this.selectedStateRecord?.code ||
                this.selectedPostalRecord.stateCode,
            State_Province__c:
                this.selectedStateRecord
                    ?.description ||
                null,
            Village__c:
                this.selectedVillageRecord?.name ||
                null
        };

        this.dispatchEvent(
            new CustomEvent(
                'addressselected',
                {
                    detail: {
                        values,
                        summary:
                            this.selectedAddressSummary
                    }
                }
            )
        );
    }

    handleCancel() {
        this.dispatchEvent(
            new CustomEvent(
                'canceladdress'
            )
        );
    }

    clearMessages() {
        this.errorMessage =
            '';
        this.infoMessage =
            '';
    }

    resetVillageData() {
        this.selectedVillageVal =
            '';
        this.villageSearchTerm =
            '';
        this.villageOptions =
            [];
        this.filteredVillageOptions =
            [];
        this.selectedVillageRecord =
            null;
        this.isVillageDropdownOpen =
            false;
    }

    resetSelections() {
        this.stateOptions =
            [];
        this.districtOptions =
            [];
        this.cityOptions =
            [];
        this.selectedStateVal =
            '';
        this.selectedDistrictVal =
            '';
        this.selectedCityVal =
            '';
        this.selectedPostalRecord =
            null;
        this.selectedStateRecord =
            null;
        this.resetVillageData();
    }

    handleError(error, fallbackMessage) {
        this.errorMessage =
            error?.body?.message ||
            error?.message ||
            fallbackMessage;
    }
}