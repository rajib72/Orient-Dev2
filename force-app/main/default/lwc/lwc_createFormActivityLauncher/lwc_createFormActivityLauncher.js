import {
    LightningElement,
    api
} from 'lwc';

import {
    NavigationMixin
} from 'lightning/navigation';

export default class LwcCreateFormActivityLauncher
    extends NavigationMixin(LightningElement) {

    @api recordId;
    @api buttonLabel = 'Create Activity';

    isModalOpen = false;

    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleActivityCancel(event) {
        const finalCustomizeFormId =
            event.detail &&
            event.detail.recordId
                ? event.detail.recordId
                : this.recordId;

        this.closeModal();

        this.navigateToRecord(
            finalCustomizeFormId,
            'Final_Customize_Form__c'
        );
    }

    handleActivityCreated(event) {
        const createdFormActivityId =
            event.detail &&
            event.detail.recordId
                ? event.detail.recordId
                : null;

        this.closeModal();

        /*
         * When multiple Stores are selected, Apex creates
         * multiple Form Activities. The component redirects
         * to the first Form Activity returned by Apex.
         */
        if (createdFormActivityId) {
            this.navigateToRecord(
                createdFormActivityId,
                'Form_Activity__c'
            );

            return;
        }

        /*
         * Fallback in case Apex did not return an ID.
         */
        this.navigateToRecord(
            this.recordId,
            'Final_Customize_Form__c'
        );
    }

    navigateToRecord(
        recordId,
        objectApiName
    ) {
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

    handleKeyDown(event) {
        if (event.key === 'Escape') {
            event.preventDefault();
            this.closeModal();
        }
    }
}