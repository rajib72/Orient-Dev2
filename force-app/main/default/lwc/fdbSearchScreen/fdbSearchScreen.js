import { LightningElement, api } from 'lwc';

/**
 * Mobile number entry and, when more than one visit matches, the result table.
 * Owns the input masking; the parent owns the Apex search and the routing.
 */
export default class FdbSearchScreen extends LightningElement {
    @api isSearching = false;
    @api searchError = '';
    @api showSearchTable = false;
    @api visitList = [];
    @api columns = [];

    searchKey = '';

    /** Clears the field and returns focus to it, for "Search Again". */
    @api
    reset() {
        this.searchKey = '';
        const input = this.template.querySelector('.oj-phone__input');
        if (input) {
            input.value = '';
            input.focus();
        }
    }

    restrictToNumbers(event) {
        let value = event.target.value || '';
        value = value.replace(/[^0-9]/g, '');
        if (value.length > 10) {
            value = value.substring(0, 10);
        }
        this.searchKey = value;
        event.target.value = value;
        this.clearError();
    }

    allowOnlyNumbers(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleSearchProfile();
            return;
        }
        const allowedKeys = ['Backspace', 'Delete', 'Tab', 'Escape', 'ArrowLeft', 'ArrowRight', 'Home', 'End'];
        if (allowedKeys.includes(event.key)) return;
        if (event.ctrlKey && ['a', 'c', 'v', 'x'].includes(event.key.toLowerCase())) return;
        if (!/^[0-9]$/.test(event.key)) event.preventDefault();
    }

    handlePaste(event) {
        event.preventDefault();
        const pastedValue = (event.clipboardData || window.clipboardData).getData('text');
        let numericValue = pastedValue.replace(/[^0-9]/g, '');
        if (numericValue.length > 10) numericValue = numericValue.substring(0, 10);
        this.searchKey = numericValue;
        event.target.value = numericValue;
        this.clearError();
    }

    clearError() {
        if (this.searchError) {
            this.dispatchEvent(new CustomEvent('clearerror'));
        }
    }

    handleSearchProfile() {
        this.dispatchEvent(new CustomEvent('search', { detail: { phone: this.searchKey } }));
    }

    handleRowAction(event) {
        this.dispatchEvent(new CustomEvent('selectvisit', { detail: { row: event.detail.row } }));
    }

    handleHelp() {
        this.dispatchEvent(new CustomEvent('help'));
    }

    /** Back to the welcome screen; the parent decides what that means. */
    handleNav() {
        this.dispatchEvent(new CustomEvent('back'));
    }
}