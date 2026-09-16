import { LightningElement } from 'lwc';
import homepageImage from '@salesforce/resourceUrl/homePage';
import homepageImage2 from '@salesforce/resourceUrl/homePage2';


export default class ParentContainer extends LightningElement {

    homepageImage = homepageImage;
    homepageImage2 = homepageImage2;

    isModalOpen = false;
    isReportModalOpen = false;

    modalTitle = '';
    modalSize = 'medium';

    showCreateActivity = false;
    showReport = false;
    showSchemeOpening = false;
    showSchemePayment = false;
    showSchemeRedemption = false;

    resetFlags() {
        this.showCreateActivity = false;
        this.showReport = false;
        this.showSchemeOpening = false;
        this.showSchemePayment = false;
        this.showSchemeRedemption = false;
    }

    openCreateActivity() {
        this.resetFlags();
        this.modalTitle = 'Create Daily Showroom Visit Activity';
        this.isModalOpen = true;
        this.showCreateActivity = true;
    }

    openReport() {
        this.resetFlags();
        this.modalTitle = 'Activity Report';
        this.modalSize = 'large';
        this.isReportModalOpen = true;
        this.showReport = true;
    }

    openSchemeOpening() {
        this.resetFlags();
        this.modalTitle = 'Scheme Opening';
        this.modalSize = 'large';
        this.isReportModalOpen = true;
        this.showSchemeOpening = true;
    }

    openSchemePayment() {
        this.resetFlags();
        this.modalTitle = 'Scheme Payment';
        this.isReportModalOpen = true;
        this.showSchemePayment = true;
    }

    openSchemeRedemption() {
        this.resetFlags();
        this.modalTitle = 'Scheme Redemption';
        this.modalSize = 'large';
        this.isReportModalOpen = true;
        this.showSchemeRedemption = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.isReportModalOpen = false;
        this.resetFlags();
    }
}