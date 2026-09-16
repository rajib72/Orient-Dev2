import { LightningElement, track } from 'lwc';
import getVisits from '@salesforce/apex/ActivityReportController.getVisits';

export default class ActivityReport extends LightningElement {

    @track startDate;
    @track endDate;
    @track records = [];
    @track noData = false;s

    updateStart(event) {
        this.startDate = event.target.value;
    }

    updateEnd(event) {
        this.endDate = event.target.value;
    }

   searchRecords() {
    // Ask parent to enlarge modal
    this.dispatchEvent(new CustomEvent('largemodal'));

    if (!this.startDate || !this.endDate) {
        this.records = [];
        this.noData = true;
        return;
    }

    getVisits({
        startDate: new Date(this.startDate),
        endDate: new Date(this.endDate)
    })
    .then(result => {
        // Map the results and format Entry/Exit times
        this.records = result.map(rec => {
            return {
                ...rec,
                Entry_Time__c: this.formatTime(rec.Entry_Time__c),
                Exit_Time__c: this.formatTime(rec.Exit_Time__c)
            };
        });

        this.noData = this.records.length === 0;

        // Auto-scroll to table after data loads
        setTimeout(() => {
            const table = this.template.querySelector('.result-table');
            if (table) {
                table.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        }, 50);
    })
    .catch(error => {
        console.error(error);
        this.noData = true;
    });
}

/**
 * Converts Salesforce Time field (milliseconds or HH:MM:SS) to human-readable format
 */
formatTime(timeValue) {
    if (!timeValue) return '';

    let date;

    if (typeof timeValue === 'number') {
        // If Salesforce returns milliseconds
        date = new Date(timeValue);
    } else {
        // If Salesforce returns a string like "14:38:00.000Z"
        date = new Date('1970-01-01T' + timeValue + 'Z'); // treat as UTC time
    }

    let hours = date.getUTCHours();
    const minutes = date.getUTCMinutes();
    const ampm = hours >= 12 ? 'PM' : 'AM';
    hours = hours % 12 || 12;
    const minStr = minutes < 10 ? '0' + minutes : minutes;

    return `${hours}:${minStr} ${ampm}`;
}

clearStartDate() {
    this.startDate = null;
}

clearEndDate() {
    this.endDate = null;
}

exportToExcel() {
    if (!this.records || this.records.length === 0) {
        return;
    }

    // Build HTML table as string
    let doc = '<table>';

    // Table styling
    doc += '<style>';
    doc += 'table, th, td { border:1px solid black; border-collapse: collapse; padding:6px; }';
    doc += 'th { background:#d3eafd; font-weight:bold; }';
    doc += '</style>';

    // Table header
    doc += '<tr>';
    doc += '<th>Customer</th>';
    doc += '<th>Phone</th>';
    doc += '<th>Description</th>';
    doc += '<th>Entry Time</th>';
    doc += '<th>Exit Time</th>';
    doc += '<th>Visit Date</th>';
    doc += '<th>Visit Purpose</th>';
    doc += '</tr>';

    // Table rows
    this.records.forEach(rec => {
        doc += '<tr>';
        doc += `<td>${rec.Customer_Name__c || ''}</td>`;
        doc += `<td>${rec.Phone__c || ''}</td>`;
        doc += `<td>${rec.Store_Interaction_Details__c || ''}</td>`;
        doc += `<td>${rec.Entry_Time__c || ''}</td>`;
        doc += `<td>${rec.Exit_Time__c || ''}</td>`;
        doc += `<td>${rec.Visit_Date__c || ''}</td>`;
        doc += `<td>${rec.Visit_Purpose__c || ''}</td>`;
        doc += '</tr>';
    });

    doc += '</table>';

    // Create an Excel-compatible download
    let element = 'data:application/vnd.ms-excel,' + encodeURIComponent(doc);

    let downloadElement = document.createElement('a');
    downloadElement.href = element;
    downloadElement.target = '_self';

    downloadElement.download =
        `Showroom_Visit_Activity_Report_${this.startDate}_to_${this.endDate}.xls`;

    document.body.appendChild(downloadElement);
    downloadElement.click();
    document.body.removeChild(downloadElement);
}

handleCancel() {
    // Fire event to parent to close modal
    this.dispatchEvent(new CustomEvent('close'));
}



}