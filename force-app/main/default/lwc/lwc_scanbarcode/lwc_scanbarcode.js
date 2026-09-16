import { LightningElement, api } from 'lwc';
import { getBarcodeScanner } from 'lightning/mobileCapabilities';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { FlowAttributeChangeEvent, FlowNavigationNextEvent } from 'lightning/flowSupport';

export default class Lwc_scanbarcode extends LightningElement {

    @api buttonLabel;
    @api buttonColor;
    // @api barcodeResult;   // Output for Flow
    // scannedBarcode = '';
    // scanButtonDisabled = false;
    // myScanner;

    // connectedCallback() {
    //     this.myScanner = getBarcodeScanner();

    //     if (!this.myScanner || !this.myScanner.isAvailable()) {
    //         this.scanButtonDisabled = true;
    //     }
    // }

    // handleBarcodeClick() {

    //     if (!this.myScanner || !this.myScanner.isAvailable()) {
    //         this.dispatchEvent(
    //             new ShowToastEvent({
    //                 title: 'Error',
    //                 message: 'This device does not support scanning',
    //                 variant: 'error'
    //             })
    //         );
    //         return;
    //     }

    //     const options = {
    //         barcodeTypes: [
    //             //this.myScanner.barcodeTypes.QR,
    //             //this.myScanner.barcodeTypes.UPC_E,
    //             //this.myScanner.barcodeTypes.EAN_13,
    //             this.myScanner.barcodeTypes.CODE_128
    //         ]
    //     };

    //     this.myScanner.beginCapture(options)
    //         .then(result => {
    //             const normalizedValue = result.value
    //                 .trim()
    //                 .toUpperCase();  

    //             this.scannedBarcode = normalizedValue;
    //             this.barcodeResult = normalizedValue;


    //             console.log('Scanner Raw Result:', result);
    //             console.log('Barcode Value:', result.value);




    //             console.log('Sending to Flow:', this.barcodeResult);

    //             // send value to flow
    //             this.dispatchEvent(
    //                 new FlowAttributeChangeEvent('barcodeResult', normalizedValue)

    //             );

    //             // auto-move to next flow screen
    //             this.dispatchEvent(
    //                 new FlowNavigationNextEvent()
    //             );

    //         })
    //         .catch(error => {
    //             console.error('Scanner error:', error);
    //         })
    //         .finally(() => {
    //             this.myScanner.endCapture();
    //         });
    // }


    //auto lauch scanner
    @api barcodeResult;
    myScanner;
    scanStarted = false;

    connectedCallback() {
        this.myScanner = getBarcodeScanner();

        if (!this.myScanner || !this.myScanner.isAvailable()) {
            this.showToast(
                'Error',
                'This device does not support barcode scanning',
                'error'
            );
            return;
        }

        // Auto-start scan after Flow screen renders
        setTimeout(() => {
            this.startScan();
        }, 10);
    }

    startScan() {
        if (this.scanStarted) return;
        this.scanStarted = true;

        const options = {
            barcodeTypes: [this.myScanner.barcodeTypes.CODE_128]
        };

        this.myScanner.beginCapture(options)
            .then(result => {
                const value = result.value.trim().toUpperCase();

                // Send barcode to Flow
                this.barcodeResult = value;
                this.dispatchEvent(
                    new FlowAttributeChangeEvent('barcodeResult', value)
                );

                // Auto-move to next screen
                this.dispatchEvent(new FlowNavigationNextEvent());
            })
            .catch(error => {
                console.error('Scanner error:', error);
            })
            .finally(() => {
                this.myScanner.endCapture();
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
   
}