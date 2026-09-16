import { LightningElement, wire } from 'lwc';
import getFeedbackVideoUrls from '@salesforce/apex/FeedbackController.getFeedbackVideoUrls';

/** Opening screen: brand video, benefits and the Start Feedback call to action. */
export default class FdbWelcomeScreen extends LightningElement {
    videoUrls = [];
    currentVideoIndex = 0;

    @wire(getFeedbackVideoUrls)
    wiredVideo({ error, data }) {
        if (data && data.length > 0) {
            this.videoUrls = data;
        } else if (error) {
            console.error('Error fetching video URLs', error);
        }
    }

    get currentVideoUrl() {
        return this.videoUrls.length > 0 ? this.videoUrls[this.currentVideoIndex] : null;
    }

    handleVideoEnded() {
        if (this.currentVideoIndex < this.videoUrls.length - 1) {
            this.currentVideoIndex++;
        } else {
            this.currentVideoIndex = 0; // Loop back to the first video
        }
        
        setTimeout(() => {
            const videoElement = this.template.querySelector('video');
            if (videoElement) {
                videoElement.load();
                videoElement.play().catch(e => console.error('Error auto-playing next video', e));
            }
        }, 0);
    }

    handleStartFeedback() {
        this.dispatchEvent(new CustomEvent('start'));
    }

    handleHelp() {
        this.dispatchEvent(new CustomEvent('help'));
    }

    handleNav() {
        // no back button on the welcome screen
    }
}