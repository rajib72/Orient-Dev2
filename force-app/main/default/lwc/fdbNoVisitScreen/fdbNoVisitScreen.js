import { LightningElement } from 'lwc';
import { buildSupportNumbers } from 'c/fdbUtils';

/**
 * The customer was found but has no showroom visit registered for today, so
 * there is no feedback to collect. A profile update request is still offered.
 */
export default class FdbNoVisitScreen extends LightningElement {
    supportNumbers = buildSupportNumbers();

    handleUpdateProfileFromNoVisit() {
        this.dispatchEvent(new CustomEvent('updateprofile'));
    }

    handleSearchAgain() {
        this.dispatchEvent(new CustomEvent('searchagain'));
    }

    handleHelp() {
        this.dispatchEvent(new CustomEvent('help'));
    }

    handleNav() {
        // no back button on this screen
    }
}