import { LightningElement, api, track } from 'lwc';
import { buildVisitHero, buildVisitTiles } from 'c/fdbUtils';

const FIELD_DEFS = [
    { field: 'Mobile', label: 'Mobile Number', icon: 'utility:call', valueKey: 'MaskedPhone', type: 'tel' },
    { field: 'WhatsApp', label: 'WhatsApp Number', icon: 'utility:chat', valueKey: 'MaskedWhatsApp', type: 'tel' },
    { field: 'Email', label: 'Email Address', icon: 'utility:email', valueKey: 'MaskedEmail', type: 'email' },
    { field: 'DOB', label: 'Date of Birth', icon: 'utility:event', valueKey: 'DOB', type: 'date', lockKey: 'IsDobLocked' },
    { field: 'DOA', label: 'Anniversary Date', icon: 'utility:favorite', valueKey: 'Anniversary', type: 'date' }
];

/**
 * Two faces on one screen: the read-only visit summary on the way into
 * feedback, and the editable field list when the customer asks to update
 * something. Owns the edit state; the parent owns the Apex and the routing.
 */
export default class FdbProfileScreen extends LightningElement {
    /** The selected visit model, or the customer-only model when there is no visit. */
    @api visit = {};

    /** True when the screen was opened to edit the profile rather than to start feedback. */
    @api editMode = false;

    @track fieldState = this.blankFieldState();

    /** The notice shown when Request Update is pressed on the way into feedback. */
    @track showUpdateNotice = false;

    blankFieldState() {
        return {
            Mobile: { isSelected: false, newValue: '' },
            WhatsApp: { isSelected: false, newValue: '' },
            Email: { isSelected: false, newValue: '' },
            DOB: { isSelected: false, newValue: '' },
            DOA: { isSelected: false, newValue: '' }
        };
    }

    // ---- WHICH FACE ----
    get hasVisitToday() {
        return this.visit?.HasVisitToday === true;
    }

    get showVisitSummary() {
        return this.hasVisitToday && !this.editMode;
    }

    get showProfileEditor() {
        return !this.showVisitSummary;
    }

    // ---- COPY ----
    get bannerTitle() {
        return this.showVisitSummary ? 'Showroom Visit Found' : 'Customer Profile Found';
    }

    get bannerText() {
        return this.showVisitSummary
            ? "We found today's showroom visit linked to your profile."
            : 'We found your customer profile successfully.';
    }

    get continueButtonLabel() {
        return this.showVisitSummary ? 'Continue to Feedback' : 'Submit Update Request';
    }

    // ---- VIEW MODELS ----
    get visitHero() {
        return buildVisitHero(this.visit);
    }

    get visitTiles() {
        return buildVisitTiles(this.visit);
    }

    /**
     * The details are shown on both faces, but only the editing face opens a
     * field. On the way into feedback the rows are a record of what we hold,
     * and Request Update explains when a change can be asked for.
     */
    get profileRows() {
        const v = this.visit || {};
        const canEdit = this.showProfileEditor;
        return FIELD_DEFS.map((def, index) => {
            const state = this.fieldState[def.field] || {};
            const isEditing = canEdit && !!state.isSelected;
            const isLocked = def.lockKey ? !!v[def.lockKey] : false;
            return {
                field: def.field,
                label: def.label,
                icon: def.icon,
                type: def.type,
                value: v[def.valueKey],
                isEditing,
                newValue: state.newValue || '',
                isLocked,
                buttonLabel: isEditing ? 'Cancel' : 'Request Update',
                buttonClass: isEditing ? 'ojp-row__btn ojp-row__btn_active' : 'ojp-row__btn',
                rowClass: isLocked
                    ? 'ojp-row ojp-row_locked'
                    : (index % 2 === 1 ? 'ojp-row ojp-row_alt' : 'ojp-row')
            };
        });
    }

    // ---- EDIT HANDLERS ----
    handleInputChange(event) {
        const field = event.target.dataset.field;
        if (!field || !this.fieldState[field]) return;
        this.fieldState[field].newValue = event.target.value;
        this.fieldState = { ...this.fieldState };
    }

    /**
     * "Request Update" toggles the inline editor for a single field - unless
     * the customer is on the way into feedback, where the request belongs
     * after the visit is rated rather than before it. There the notice opens
     * instead, and nothing is put into edit.
     */
    handleRequestUpdate(event) {
        if (this.showVisitSummary) {
            this.showUpdateNotice = true;
            return;
        }
        const field = event.currentTarget.dataset.field;
        if (!field || !this.fieldState[field]) return;
        this.fieldState[field].isSelected = !this.fieldState[field].isSelected;
        if (!this.fieldState[field].isSelected) {
            this.fieldState[field].newValue = '';
        }
        this.fieldState = { ...this.fieldState };
    }

    // ---- UPDATE NOTICE ----
    handleNoticeCancel() {
        this.showUpdateNotice = false;
    }

    /** The one way on from the notice: the same route as the screen's CTA. */
    handleNoticeContinue() {
        this.showUpdateNotice = false;
        this.handleContinueToFeedback();
    }

    // ---- CTA ----
    handleContinueToFeedback() {
        const changes = [];
        for (const field in this.fieldState) {
            if (this.fieldState[field].isSelected && this.fieldState[field].newValue) {
                changes.push({ fieldName: field, newValue: this.fieldState[field].newValue });
            }
        }
        this.dispatchEvent(new CustomEvent('continue', { detail: { changes } }));
    }

    handleNav() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleHelp() {
        this.dispatchEvent(new CustomEvent('help'));
    }
}