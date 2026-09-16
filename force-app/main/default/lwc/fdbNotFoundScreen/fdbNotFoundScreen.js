import { LightningElement } from 'lwc';
import { buildSupportNumbers } from 'c/fdbUtils';

/** No customer record matched the mobile number that was searched. */
export default class FdbNotFoundScreen extends LightningElement {
    supportNumbers = buildSupportNumbers();

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