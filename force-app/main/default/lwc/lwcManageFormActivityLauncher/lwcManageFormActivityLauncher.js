import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class LwcManageFormActivityLauncher
    extends NavigationMixin(LightningElement) {

    @api recordId;
    @api buttonLabel = 'Manage Activity';

    isModalOpen = false;

    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleActivityCancel(event) {
        const parentRecordId =
            event.detail &&
            event.detail.recordId
                ? event.detail.recordId
                : this.recordId;

        this.closeModal();

        this.navigateToRecord(
            parentRecordId,
            'Final_Customize_Form__c'
        );
    }

    handleActivityUpdated(event) {
        const formActivityId =
            event.detail &&
            event.detail.recordId
                ? event.detail.recordId
                : null;

        this.closeModal();

        if (formActivityId) {
            this.navigateToRecord(
                formActivityId,
                'Form_Activity__c'
            );

            return;
        }

        this.navigateToRecord(
            this.recordId,
            'Final_Customize_Form__c'
        );
    }

    navigateToRecord(recordId, objectApiName) {
        if (!recordId) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName,
                actionName: 'view'
            }
        });
    }
}