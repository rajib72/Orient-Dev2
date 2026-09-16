import { LightningElement, api, track, wire } from 'lwc';
import getFeedbackQuestions from '@salesforce/apex/FeedbackController.getFeedbackQuestions';

/** Must match the Clarity_Rating__c picklist value exactly - it is restricted. */
const NOT_APPLICABLE = 'N.A.';

/**
 * The questionnaire. Owns the language toggle and every answer; the parent
 * receives a complete payload on submit and does the saving.
 */
export default class FdbFeedbackScreen extends LightningElement {
    /** Set by the parent while the submission is in flight. */
    @api isSubmitting = false;

    /**
     * 'modal' is the questionnaire opened on its own inside a dialog, from the
     * quick action on a showroom visit. There is nowhere to go back to there,
     * and the dialog owns the height. Anything else is the kiosk journey.
     */
    @api variant = '';

    get isModal() { return this.variant === 'modal'; }

    /** No label, no button - fdbScreen renders the nav only when it has one. */
    get navLabel() { return this.isModal ? '' : 'Back'; }

    get screenLayout() { return this.isModal ? 'inline' : ''; }

    @track selectedLanguage = 'EN';
    @track feedbackData = {};

    @track q1Selected = '';
    @track q2Selected = '';
    @track q3Selected = '';
    @track q4Selected = '';
    @track q5Selected = '';
    @track q6Value = '';

    @wire(getFeedbackQuestions)
    wiredQuestions({ error, data }) {
        if (data) {
            const mapped = {};
            data.forEach(q => {
                if (q.Sequence__c) {
                    mapped[`Question_${q.Sequence__c}_EN__c`] = q.Question_EN__c;
                    mapped[`Question_${q.Sequence__c}_BN__c`] = q.Question_BN__c;
                }
            });
            this.feedbackData = mapped;
        } else if (error) {
            console.error('Error fetching feedback questions', error);
        }
    }

    // ---- LANGUAGE ----
    get enBtnClass() { return this.selectedLanguage === 'EN' ? 'lang-btn active' : 'lang-btn'; }
    get bnBtnClass() { return this.selectedLanguage === 'BN' ? 'lang-btn active' : 'lang-btn'; }

    setLanguageEn() { this.selectedLanguage = 'EN'; }
    setLanguageBn() { this.selectedLanguage = 'BN'; }

    questionAt(sequence) {
        const suffix = this.selectedLanguage === 'BN' ? 'BN' : 'EN';
        return this.feedbackData[`Question_${sequence}_${suffix}__c`];
    }

    get question1() { return this.questionAt(1); }
    get question2() { return this.questionAt(2); }
    get question3() { return this.questionAt(3); }
    get question4() { return this.questionAt(4); }
    get question5() { return this.questionAt(5); }
    get question6() { return this.questionAt(6); }

    // ---- OPTIONS ----
    // Every question is a 1-5 scale now, drawn as stars. The star only ever
    // stands in for the number: the value carried out of here, saved, and
    // averaged is still '1'..'5'.
    get q1Options() { return this.generateStars(this.q1Selected); }
    get q2Options() { return this.generateStars(this.q2Selected); }
    get q3Options() { return this.generateStars(this.q3Selected); }
    get q4Options() { return this.generateStars(this.q4Selected); }
    get q5Options() { return this.generateStars(this.q5Selected); }

    /** The clarity question alone may be answered "not applicable". */
    get q3NotApplicableClass() {
        return this.q3Selected === NOT_APPLICABLE ? 'na-btn selected' : 'na-btn';
    }

    /**
     * Five stars, filled up to the chosen one - a rating reads as "four stars",
     * not "the fourth star", so every star below the choice is lit as well.
     */
    generateStars(selectedValue) {
        const selected = Number(selectedValue) || 0;
        return [1, 2, 3, 4, 5].map(n => ({
            value: String(n),
            class: n <= selected ? 'star-btn filled' : 'star-btn',
            ariaLabel: `${n} out of 5`,
            ariaPressed: String(n === selected)
        }));
    }

    handleOptionSelect(event) {
        // currentTarget, not target: the click usually lands on the star svg
        // inside the button, which carries no data attributes of its own.
        const { q, val } = event.currentTarget.dataset;
        if (q === '1') this.q1Selected = val;
        else if (q === '2') this.q2Selected = val;
        else if (q === '3') this.q3Selected = val;
        else if (q === '4') this.q4Selected = val;
        else if (q === '5') this.q5Selected = val;
    }

    handleQ6Change(event) {
        this.q6Value = event.target.value;
    }

    // ---- SUBMIT ----
    get submitButtonLabel() {
        return this.isSubmitting ? 'Submitting...' : 'Submit Feedback';
    }

    get isAnswerMissing() {
        return !this.q1Selected || !this.q2Selected || !this.q3Selected
            || !this.q4Selected || !this.q5Selected;
    }

    handleSubmitFeedback() {
        if (this.isSubmitting) return;

        if (this.isAnswerMissing) {
            this.dispatchEvent(new CustomEvent('incomplete'));
            return;
        }

        this.dispatchEvent(new CustomEvent('submit', {
            detail: {
                answers: {
                    q1: this.q1Selected,
                    q2: this.q2Selected,
                    q3: this.q3Selected,
                    q4: this.q4Selected,
                    q5: this.q5Selected
                },
                comments: this.q6Value,
                language: this.selectedLanguage
            }
        }));
    }

    handleNav() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleHelp() {
        this.dispatchEvent(new CustomEvent('help'));
    }
}