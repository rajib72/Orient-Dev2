import { LightningElement, track } from 'lwc';
// import getSchemeDetails from '@salesforce/apex/SchemePaymentController.getSchemeDetails';
// import savePayment from '@salesforce/apex/SchemePaymentController.savePayment';

export default class SchemePayment extends LightningElement {

    schemeNo;
    paymentAmount;

    @track schemeData = {};
    schemeFound = false;
    showError = false;

    handleSchemeChange(event) {
        this.schemeNo = event.target.value;

        if (!this.schemeNo) {
            this.schemeFound = false;
            return;
        }

        // MOCK DATA 
        if (this.schemeNo === 'SCH-001') {
            this.schemeData = {
                name: 'Gold Saving Scheme',
                customer: 'Amit Banerjee',
                totalAmount: 100000,
                pendingAmount: 40000
            };
            this.schemeFound = true;
            this.showError = false;
        } else {
            this.schemeFound = false;
            this.showError = true;
        }

        /*
        // 🔹 REAL APEX CALL
        getSchemeDetails({ schemeNo: this.schemeNo })
            .then(result => {
                this.schemeData = result;
                this.schemeFound = true;
                this.showError = false;
            })
            .catch(() => {
                this.schemeFound = false;
                this.showError = true;
            });
        */
    }

    handlePaymentChange(event) {
        this.paymentAmount = event.target.value;
    }
        handleCancel() {
    // Fire event to parent to close modal
    this.dispatchEvent(
        new CustomEvent('close', {
            bubbles: true,
            composed: true
        })
    );
}

   


    handleSavePayment() {
        if (!this.paymentAmount || this.paymentAmount <= 0) {
            alert('Please enter a valid payment amount');
            return;
        }

        // savePayment({ schemeNo: this.schemeNo, amount: this.paymentAmount });

        console.log('Payment Saved:', this.schemeNo, this.paymentAmount);
    }



}