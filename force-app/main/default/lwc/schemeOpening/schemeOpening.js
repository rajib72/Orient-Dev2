import { LightningElement, track } from 'lwc';

export default class SchemeEnrollment extends LightningElement {

    phone;
    customerName;

    isCustomerFound = false;
    isNewCustomer = false;
    showSchemeSection = false;
    showSchemeDetails = false;
    showSave = false;

    @track customer = {};
    @track scheme = {};

    schemeOptions = [
        { label: 'Gold Saving Scheme – 11 Months', value: 'GSS11' },
        { label: 'Gold Saving Scheme – 6 Months', value: 'GSS6' }
    ];

    // ================= PHONE SEARCH =================
    handlePhoneChange(event) {
        this.phone = event.target.value;

        if (this.phone === '9999999999') {
            // MOCK EXISTING CUSTOMER
            this.customer = {
                name: 'Amit Banerjee',
                code: 'CUST-001'
            };
            this.isCustomerFound = true;
            this.isNewCustomer = false;
            this.showSchemeSection = true;
        } else if (this.phone && this.phone.length >= 10) {
            // MOCK NEW CUSTOMER
            this.isCustomerFound = false;
            this.isNewCustomer = true;
            this.showSchemeSection = true;
        } else {
            this.resetAll();
        }
    }

    handleNameChange(event) {
        this.customerName = event.target.value;
    }

    // ================= SCHEME SELECTION =================
    handleSchemeChange(event) {
        const value = event.detail.value;

        if (value === 'GSS11') {
            this.scheme = {
                duration: 11,
                total: 100000,
                installment: 9000,
                firstPayment: 9000
            };
        } else if (value === 'GSS6') {
            this.scheme = {
                duration: 6,
                total: 60000,
                installment: 10000,
                firstPayment: 10000
            };
        }

        this.showSchemeDetails = true;
        this.showSave = true;
    }

    // ================= SAVE =================
    handleSave() {
        const payload = {
            phone: this.phone,
            customerName: this.customerName || this.customer.name,
            scheme: this.scheme
        };

        console.log('Saving Scheme Enrollment:', JSON.stringify(payload));
        alert('Scheme enrollment saved successfully!');
    }

    resetAll() {
        this.isCustomerFound = false;
        this.isNewCustomer = false;
        this.showSchemeSection = false;
        this.showSchemeDetails = false;
        this.showSave = false;
        this.customer = {};
        this.scheme = {};
    }

handleCancel() {
    this.resetAll();
    this.dispatchEvent(
        new CustomEvent('close', {
            bubbles: true,
            composed: true
        })
    );
}


}