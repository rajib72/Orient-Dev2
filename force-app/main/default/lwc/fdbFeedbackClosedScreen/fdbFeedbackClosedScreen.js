import { LightningElement, api } from 'lwc';
import { buildVisitHero, buildVisitTiles } from 'c/fdbUtils';

/**
 * Reached when the selected visit already has a completed Feedback__c.
 * One feedback per showroom visit, so the questionnaire is not offered again.
 */
export default class FdbFeedbackClosedScreen extends LightningElement {
    @api visit = {};

    get visitHero() {
        return buildVisitHero(this.visit);
    }

    get visitTiles() {
        return buildVisitTiles(this.visit);
    }

    get feedbackSubmittedAt() {
        return this.visit?.FeedbackSubmittedAt || '';
    }

    get hasFeedbackSubmittedAt() {
        return !!this.feedbackSubmittedAt;
    }

    handleRequestInvoiceAfterFeedback() {
        this.dispatchEvent(new CustomEvent('requestinvoice'));
    }

    handleSearchAgain() {
        this.dispatchEvent(new CustomEvent('searchagain'));
    }

    handleNav() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleHelp() {
        this.dispatchEvent(new CustomEvent('help'));
    }
}