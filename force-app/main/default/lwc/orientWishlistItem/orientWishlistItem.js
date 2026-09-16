import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getItemByBarcode from '@salesforce/apex/Ctrl_WishListItemPageDesign.getItemByBarcode';
import saveQuestions from '@salesforce/apex/Ctrl_WishListItemPageDesign.saveQuestions';

const FIELDS = ['Wishlist_Item__c.Barcode_Value__c'];

export default class WishlistItemPageDesign extends LightningElement {
    @api recordId;

    wiredWishlistResult;
    refreshInterval;
    lastBarcode;

    productName;
    barcode;
    price;
    productPriceInclusiveGST;
    taxAmount;
    grossWeight;
    netWeight;
    goldPurity;
    goldColor;
    designCode;
    size;
    diamondWeight;
    stoneWeight;
    certificationBy;

    @track detailLines = [];
    @track scmLines = [];
    @track questions = [];

    @track mediaList = [];
    activeMediaIndex = 0;

    hasData = false;
    isZoomOpen = false;
    @track isZoomedIn = false;
    zoomImage;
    isLoading = false;

    @track isVideoPlaying = true;

    isFirstLoad = true;
    hasFetchedOnce = false;
    noDataRetryCount = 0;
    maxNoDataRetry = 2;

    touchStartX = 0;
    touchEndX = 0;

    localQuestionState = new Map();

    connectedCallback() {
        this.refreshInterval = setInterval(() => {
            if (this.lastBarcode) {
                this.fetchItem(this.lastBarcode);
            }
            if (this.wiredWishlistResult) {
                refreshApex(this.wiredWishlistResult);
            }
        }, 5000);
    }

    disconnectedCallback() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
        }
    }

    get showNoData() {
        return this.hasFetchedOnce && !this.isLoading && !this.hasData;
    }

    get hasDetailLines() {
        return this.detailLines?.length > 0;
    }

    get hasScmLines() {
        return this.scmLines?.length > 0;
    }

    get hasQuestions() {
        return this.questions?.length > 0;
    }

    get currentMedia() {
        if (this.mediaList && this.mediaList.length > 0) {
            return this.mediaList[this.activeMediaIndex];
        }
        return null;
    }

    get showIndicators() {
        return this.mediaList && this.mediaList.length > 1;
    }

    get indicators() {
        if (!this.mediaList) return [];
        return this.mediaList.map((item, index) => {
            return {
                id: item.key,
                index: index,
                class: index === this.activeMediaIndex ? 'indicator active' : 'indicator'
            };
        });
    }

    handlePrev() {
        this.activeMediaIndex = this.activeMediaIndex > 0 ? this.activeMediaIndex - 1 : this.mediaList.length - 1;
        this.isVideoPlaying = true;
    }

    handleNext() {
        this.activeMediaIndex = this.activeMediaIndex < this.mediaList.length - 1 ? this.activeMediaIndex + 1 : 0;
        this.isVideoPlaying = true;
    }

    handleIndicatorClick(event) {
        this.activeMediaIndex = parseInt(event.target.dataset.index, 10);
        this.isVideoPlaying = true;
    }

    handleTouchStart(event) {
        this.touchStartX = event.changedTouches[0].screenX;
    }

    handleTouchEnd(event) {
        this.touchEndX = event.changedTouches[0].screenX;
        this.handleSwipe();
    }

    handleSwipe() {
        const swipeThreshold = 50;
        if (this.touchEndX < this.touchStartX - swipeThreshold) {
            this.handleNext();
        } else if (this.touchEndX > this.touchStartX + swipeThreshold) {
            this.handlePrev();
        }
    }

    togglePlayPause(event) {
        const video = event.target;
        if (video.paused) {
            video.play();
        } else {
            video.pause();
        }
    }

    togglePlayPauseOverlay(event) {
        const container = event.currentTarget.closest('.video-container');
        if (container) {
            const video = container.querySelector('video');
            if (video) {
                video.play();
            }
        }
    }

    handleVideoPlay() {
        this.isVideoPlaying = true;
    }

    handleVideoPause() {
        this.isVideoPlaying = false;
    }

    get zoomImageClass() {
        return this.isZoomedIn ? 'zoom-image zoomed-in' : 'zoom-image zoomed-out';
    }

    openZoom(event) {
        this.zoomImage = event.target.dataset.src;
        this.isZoomOpen = true;
        this.isZoomedIn = false;
    }

    closeZoom() {
        this.isZoomOpen = false;
        this.isZoomedIn = false;
    }

    handleImageZoomClick(event) {
        event.stopPropagation();
        this.isZoomedIn = !this.isZoomedIn;
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wishlistRecord(result) {
        this.wiredWishlistResult = result;
        const { data, error } = result;

        if (data) {
            const barcode = data.fields.Barcode_Value__c?.value;

            if (!barcode) {
                this.lastBarcode = null;
                this.hasFetchedOnce = true;
                this.noDataRetryCount = 0;
                this.resetData();
                this.isLoading = false;
                this.isFirstLoad = false;
                return;
            }

            if (barcode !== this.lastBarcode) {
                this.lastBarcode = barcode;
                this.hasFetchedOnce = false;
                this.noDataRetryCount = 0;
                this.localQuestionState.clear();
                this.fetchItem(barcode);
            }
        } else if (error) {
            console.error('Error fetching wishlist record', error);
            this.hasFetchedOnce = true;
            this.resetData();
            this.isLoading = false;
            this.isFirstLoad = false;
        }
    }

    // --- NEW CURRENCY FORMATTER ---
    formatCurrency(value) {
        if (value === null || value === undefined || value === '') return '0.00';
        return Number(value).toLocaleString('en-IN', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    formatThreeDecimal(value) {
        if (value === null || value === undefined || value === '') return '0.000';
        return Number(value).toFixed(3);
    }

    formatTwoDecimal(value) {
        if (value === null || value === undefined || value === '') return '0.00';
        return Number(value).toFixed(2);
    }

    fetchItem(barcode) {
        if (this.isFirstLoad) {
            this.isLoading = true;
        }

        getItemByBarcode({
            barcode: barcode,
            wishlistId: this.recordId
        })
            .then(result => {
                if (!result || Object.keys(result).length === 0) {
                    this.noDataRetryCount++;
                    if (this.noDataRetryCount <= this.maxNoDataRetry) {
                        return;
                    }
                    this.hasFetchedOnce = true;
                    this.resetData();
                    this.isLoading = false;
                    this.isFirstLoad = false;
                    return;
                }

                this.noDataRetryCount = 0;
                this.hasFetchedOnce = true;

                this.productName = result.productName || '';
                this.barcode = result.barcode || '';

                // --- APPLIED CURRENCY FORMATTING HERE ---
                this.price = this.formatCurrency(result.price);
                this.productPriceInclusiveGST = this.formatCurrency(result.productPriceInclusiveGST ?? result.Product_Price_Inclusive_GST__c);
                this.taxAmount = this.formatCurrency(result.taxAmount ?? result.Tax_Amount__c);

                this.goldPurity = result.goldPurity || '';
                this.goldColor = result.goldColor || '';
                this.designCode = result.designCode || '';
                this.size = result.size ?? '';
                this.certificationBy = result.certificationBy || '';

                this.grossWeight = this.formatThreeDecimal(result.grossWeight);
                this.netWeight = this.formatThreeDecimal(result.netWeight);
                this.diamondWeight = this.formatThreeDecimal(result.diamondWeight);
                this.stoneWeight = this.formatThreeDecimal(result.stoneWeight);

                this.detailLines = (result.detailLines || []).map((row, index) => ({
                    ...row,
                    key: `D-${index}`,
                    quantity: this.formatThreeDecimal(row.quantity),
                    rate: this.formatTwoDecimal(row.rate),
                    amount: this.formatTwoDecimal(row.amount)
                }));

                this.scmLines = (result.scmLines || []).map((row, index) => ({
                    ...row,
                    key: `S-${index}`,
                    quantity: this.formatThreeDecimal(row.quantity),
                    rate: this.formatTwoDecimal(row.rate),
                    amount: this.formatTwoDecimal(row.amount)
                }));

                this.questions = (result.questions || []).map(q => {
                    const isLocallyChecked = this.localQuestionState.has(q.questionId)
                        ? this.localQuestionState.get(q.questionId)
                        : q.isChecked;
                    return {
                        Id: q.questionId,
                        Question__c: q.questionText,
                        Question_Checked__c: isLocallyChecked
                    };
                });

                if (this.mediaList.length === 0 || JSON.stringify(this.mediaList) !== JSON.stringify(result.mediaItems)) {
                    this.mediaList = result.mediaItems || [];
                    this.activeMediaIndex = 0;
                }

                this.hasData = true;

                requestAnimationFrame(() => {
                    this.isLoading = false;
                    this.isFirstLoad = false;
                });
            })
            .catch(error => {
                console.error('Apex error => ', error);
                this.hasFetchedOnce = true;
                this.resetData();
                this.isLoading = false;
                this.isFirstLoad = false;
            });
    }

    handleQuestionChange(event) {
        const qId = event.target.dataset.id;
        const checked = event.target.checked;

        this.localQuestionState.set(qId, checked);

        const qIndex = this.questions.findIndex(q => q.Id === qId);
        if (qIndex !== -1) {
            this.questions[qIndex].Question_Checked__c = checked;
        }

        const recordToUpdate = [{
            sobjectType: 'Wishlist_Item_Question__c',
            Id: qId,
            Question_Checked__c: checked
        }];

        saveQuestions({ questionsToUpdate: recordToUpdate })
            .then(() => {
                this.localQuestionState.delete(qId);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Saved',
                        message: 'Question status updated.',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                console.error('Error updating question', error);
                this.localQuestionState.delete(qId);
                if (qIndex !== -1) {
                    this.questions[qIndex].Question_Checked__c = !checked;
                }
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error updating question',
                        message: error.body?.message || 'An unexpected error occurred.',
                        variant: 'error'
                    })
                );
            });
    }

    resetData() {
        this.productName = '';
        this.barcode = '';
        this.price = '';
        this.productPriceInclusiveGST = '';
        this.taxAmount = '';
        this.grossWeight = '';
        this.netWeight = '';
        this.goldPurity = '';
        this.goldColor = '';
        this.designCode = '';
        this.size = '';
        this.diamondWeight = '';
        this.stoneWeight = '';
        this.certificationBy = '';
        this.detailLines = [];
        this.scmLines = [];
        this.questions = [];

        this.mediaList = [];
        this.activeMediaIndex = 0;
        this.isVideoPlaying = true;

        this.hasData = false;
        this.localQuestionState.clear();
    }
}