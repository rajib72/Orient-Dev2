import { LightningElement, api, track } from 'lwc';
import pushAccountToOrient from '@salesforce/apex/OrientCustomerPushController.pushAccountToOrient';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { RefreshEvent } from 'lightning/refresh';

export default class OrientCustomerPushAction extends LightningElement {
    _recordId;
    _hasRun = false;

    @track isLoading = false;
    @track result;
    @track errorMessage;
    @track customerNo;

    @api
    set recordId(value) {
        this._recordId = value;

        if (value && !this._hasRun) {
            this._hasRun = true;
            this.sendRecord();
        }
    }
    get recordId() {
        return this._recordId;
    }

    async sendRecord() {
        this.isLoading = true;
        this.errorMessage = null;
        this.result = null;
        this.customerNo = null;

        try {
            const timeoutMs = 35000;

            const timeoutPromise = new Promise((_, reject) => {
                setTimeout(() => reject(new Error('Request timed out after 35 seconds.')), timeoutMs);
            });

            const apiPromise = pushAccountToOrient({ recordId: this.recordId });

            const res = await Promise.race([apiPromise, timeoutPromise]);

            this.result = res;
            this.customerNo = res.customerNo || null;

            if (res.success && this.customerNo) {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: res.alreadySent ? 'Already Sent' : (res.success ? 'Success' : 'Error'),
                    message: res.message,
                    variant: res.alreadySent ? 'warning' : (res.success ? 'success' : 'error')
                })
            );
        } catch (error) {
            this.errorMessage =
                error?.body?.message ||
                error?.message ||
                'Unexpected error occurred while sending the record.';

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.errorMessage,
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    get hasResult() {
        return this.result !== undefined && this.result !== null;
    }

    get hasError() {
        return !!this.errorMessage && !this.hasResult;
    }

    get boxClass() {
        if (this.result?.alreadySent) return 'warningBox';
        if (this.result?.success) return 'successBox';
        return 'errorBox'; // Shows red UI styling if phone missing/callout fail
    }

    get statusTitle() {
        if (this.result?.alreadySent) return 'Already Sent';
        if (this.result?.success) return 'Success';
        return 'Error'; // Swapped from "Status" so error states reflect accurately
    }

    get statusIcon() {
        if (this.result?.alreadySent) return 'utility:warning';
        if (this.result?.success) return 'utility:success';
        return 'utility:error'; // Swapped from "utility:info" for errors
    }

    get messageClass() {
        if (this.result?.alreadySent) return 'alreadySentMessage';
        if (this.result?.success) return 'successMessage';
        return 'errorMessage'; // Updated from 'neutralMessage' 
    }

    handleClose() {
        this.dispatchEvent(new RefreshEvent());
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}