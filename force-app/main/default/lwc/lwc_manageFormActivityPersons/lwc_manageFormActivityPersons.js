import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getFormActivities from '@salesforce/apex/ctrl_ManageFormActivityPersonsController.getFormActivities';
import getActivityDetails from '@salesforce/apex/ctrl_ManageFormActivityPersonsController.getActivityDetails';
import addAssignedPersons from '@salesforce/apex/ctrl_ManageFormActivityPersonsController.addAssignedPersons';
import deleteAssignedPerson from '@salesforce/apex/ctrl_ManageFormActivityPersonsController.deleteAssignedPerson';

export default class ManageFormActivityPersons extends LightningElement {
    @api recordId;

    isLoading = false;

    selectedActivityId;
    selectedStoreId;
    selectedStoreName;

    activityOptions = [];
    assignedPersons = [];
    availableExecutives = [];

    selectedExecutiveIds = [];
    showAddSection = false;
    searchKey = '';

    get assignedCount() {
        return this.assignedPersons ? this.assignedPersons.length : 0;
    }

    get selectedExecutiveCount() {
        return this.selectedExecutiveIds ? this.selectedExecutiveIds.length : 0;
    }

    get hasAssignedPersons() {
        return this.filteredAssignedPersons && this.filteredAssignedPersons.length > 0;
    }

    get hasAvailableExecutives() {
        return this.availableExecutives && this.availableExecutives.length > 0;
    }

    get filteredAssignedPersons() {
        let records = this.assignedPersons || [];

        if (this.searchKey) {
            const key = this.searchKey.toLowerCase();

            records = records.filter(item => {
                return (
                    (item.personName && item.personName.toLowerCase().includes(key)) ||
                    (item.salesExecutiveName && item.salesExecutiveName.toLowerCase().includes(key)) ||
                    (item.storeName && item.storeName.toLowerCase().includes(key))
                );
            });
        }

        return records.map((item, index) => {
            return {
                ...item,
                slNo: index + 1,
                initial: item.personName ? item.personName.charAt(0).toUpperCase() : 'P'
            };
        });
    }

    @wire(getFormActivities, { finalCustomizeFormId: '$recordId' })
    wiredActivities(result) {
        if (result.data) {
            this.activityOptions = result.data;
        } else if (result.error) {
            this.showToast('Error', this.getErrorMessage(result.error), 'error');
        }
    }

    handleActivityChange(event) {
        this.selectedActivityId = event.detail.value;
        this.showAddSection = false;
        this.selectedExecutiveIds = [];
        this.searchKey = '';

        this.loadActivityDetails();
    }

    loadActivityDetails() {
        if (!this.selectedActivityId) {
            return;
        }

        this.isLoading = true;

        getActivityDetails({
            formActivityId: this.selectedActivityId
        })
            .then(result => {
                this.selectedStoreId = result.storeId;
                this.selectedStoreName = result.storeName;

                this.assignedPersons = result.assignedPersons || [];

                this.availableExecutives = (result.availableExecutives || []).map(item => {
                    return {
                        id: item.id,
                        name: item.name,
                        alreadyAssigned: item.alreadyAssigned,
                        selected: false,
                        initial: item.name ? item.name.charAt(0).toUpperCase() : 'S',
                        cardClass: item.alreadyAssigned ? 'executiveCard disabledCard' : 'executiveCard'
                    };
                });

                this.selectedExecutiveIds = [];
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', this.getErrorMessage(error), 'error');
            });
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
    }

    handleOpenAddSection() {
        this.showAddSection = true;
        this.selectedExecutiveIds = [];

        this.availableExecutives = this.availableExecutives.map(item => {
            return {
                ...item,
                selected: false,
                cardClass: item.alreadyAssigned ? 'executiveCard disabledCard' : 'executiveCard'
            };
        });
    }

    handleCloseAddSection() {
        this.showAddSection = false;
        this.selectedExecutiveIds = [];

        this.availableExecutives = this.availableExecutives.map(item => {
            return {
                ...item,
                selected: false,
                cardClass: item.alreadyAssigned ? 'executiveCard disabledCard' : 'executiveCard'
            };
        });
    }

    handleExecutiveSelect(event) {
        const executiveId = event.currentTarget.dataset.id;

        const clickedExecutive = this.availableExecutives.find(item => item.id === executiveId);

        if (clickedExecutive && clickedExecutive.alreadyAssigned) {
            return;
        }

        this.availableExecutives = this.availableExecutives.map(item => {
            if (item.id === executiveId) {
                const newSelected = !item.selected;

                return {
                    ...item,
                    selected: newSelected,
                    cardClass: newSelected ? 'executiveCard selectedCard' : 'executiveCard'
                };
            }

            return item;
        });

        this.selectedExecutiveIds = this.availableExecutives
            .filter(item => item.selected && !item.alreadyAssigned)
            .map(item => item.id);
    }

    handleAddSelected() {
        if (!this.selectedExecutiveIds || this.selectedExecutiveIds.length === 0) {
            this.showToast(
                'Validation Error',
                'Please select at least one Sales Executive.',
                'error'
            );
            return;
        }

        this.isLoading = true;

        addAssignedPersons({
            formActivityId: this.selectedActivityId,
            storeId: this.selectedStoreId,
            salesExecutiveIds: this.selectedExecutiveIds
        })
            .then(() => {
                this.showToast(
                    'Success',
                    'Assigned persons added successfully.',
                    'success'
                );

                this.showAddSection = false;
                this.selectedExecutiveIds = [];
                this.loadActivityDetails();
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', this.getErrorMessage(error), 'error');
            });
    }

    handleDeletePerson(event) {
        const assignedPersonId = event.currentTarget.dataset.id;

        if (!assignedPersonId) {
            return;
        }

        this.isLoading = true;

        deleteAssignedPerson({
            assignedPersonId: assignedPersonId
        })
            .then(() => {
                this.showToast(
                    'Success',
                    'Assigned person deleted successfully.',
                    'success'
                );

                this.loadActivityDetails();
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', this.getErrorMessage(error), 'error');
            });
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
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
        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Something went wrong.';
    }
}