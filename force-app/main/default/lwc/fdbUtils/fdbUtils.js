/**
 * Shared display formatters and view-model builders for the customer feedback
 * journey. Pure functions only - no component state, no Apex.
 */

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

export const SUPPORT_NUMBERS = ['+91 83730 99950', '+91 83730 99930'];

// Marker raised by FeedbackController when a visit's feedback is already Completed
export const ALREADY_SUBMITTED = 'FEEDBACK_ALREADY_SUBMITTED';

export function maskNumber(num) {
    if (!num) return 'Not available';
    const str = String(num).replace(/[^0-9]/g, '');
    if (str.length >= 10) {
        const last10 = str.slice(-10);
        return '+91 ' + last10.substring(0, 2) + 'XXXXXX' + last10.substring(8);
    }
    return '+91 ' + str;
}

export function maskEmail(email) {
    if (!email) return 'Not available';
    const parts = email.split('@');
    if (parts.length === 2) {
        return parts[0].substring(0, 1) + '***' + parts[0].substring(parts[0].length - 1) + '@' + parts[1];
    }
    return email;
}

/**
 * Salesforce Date fields arrive as 'YYYY-MM-DD'. The parts are parsed by hand
 * so the browser timezone can never shift the day.
 */
export function formatDate(dateStr, withWeekday) {
    if (!dateStr) return 'Not available';
    const parts = String(dateStr).substring(0, 10).split('-');
    if (parts.length !== 3) return dateStr;

    const y = Number(parts[0]);
    const m = Number(parts[1]);
    const d = Number(parts[2]);
    if (!y || !m || !d) return dateStr;

    let out = `${String(d).padStart(2, '0')}-${MONTHS[m - 1]}-${y}`;
    if (withWeekday) {
        out += ` (${DAYS[new Date(Date.UTC(y, m - 1, d)).getUTCDay()]})`;
    }
    return out;
}

/** Time fields arrive as milliseconds-since-midnight or as 'HH:mm:ss.SSSZ'. */
export function formatTime(timeValue) {
    if (timeValue === null || timeValue === undefined || timeValue === '') return 'Not available';

    let hours;
    let minutes;

    if (typeof timeValue === 'number') {
        hours = Math.floor(timeValue / 3600000);
        minutes = Math.floor((timeValue % 3600000) / 60000);
    } else {
        const parts = String(timeValue).split(':');
        if (parts.length < 2) return timeValue;
        hours = Number(parts[0]);
        minutes = Number(parts[1]);
    }

    if (isNaN(hours) || isNaN(minutes)) return timeValue;

    const suffix = hours >= 12 ? 'PM' : 'AM';
    const displayHour = hours % 12 === 0 ? 12 : hours % 12;
    return `${String(displayHour).padStart(2, '0')}:${String(minutes).padStart(2, '0')} ${suffix}`;
}

/** Submitted_Date_Time__c arrives as an ISO datetime string. */
export function formatDateTime(value) {
    if (!value) return '';
    const d = new Date(value);
    if (isNaN(d.getTime())) return '';
    const hours = d.getHours();
    const suffix = hours >= 12 ? 'PM' : 'AM';
    const displayHour = hours % 12 === 0 ? 12 : hours % 12;
    return `${String(d.getDate()).padStart(2, '0')}-${MONTHS[d.getMonth()]}-${d.getFullYear()}`
        + ` at ${String(displayHour).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')} ${suffix}`;
}

/** Customer-facing fields, used with or without a visit record. */
export function buildCustomerFields(cust) {
    return {
        CustomerName: cust ? cust.Name : '',
        CustomerPhone: cust ? cust.Phone : '',
        CustomerNo: cust?.Salesforce_Customer_No__c || cust?.BC_Customer_No__c || 'Not available',
        MaskedPhone: maskNumber(cust?.Phone),
        MaskedWhatsApp: maskNumber(cust?.WhatsApp_Number__c),
        MaskedEmail: maskEmail(cust?.Email_Address__c),
        DOB: formatDate(cust?.Date_Of_Birth__c),
        Anniversary: formatDate(cust?.Anniversary_Date__c),
        IsDobLocked: cust?.DOB_Verified__c === true
    };
}

export function buildVisitModel(visit) {
    let hasCompletedFeedback = false;
    let submittedAt = '';
    if (visit.Feedbacks__r && visit.Feedbacks__r.length > 0) {
        const fb = visit.Feedbacks__r[0];
        hasCompletedFeedback = fb.Status__c === 'Completed';
        submittedAt = formatDateTime(fb.Submitted_Date_Time__c);
    }

    return {
        ...visit,
        ...buildCustomerFields(visit.CUSTOMERlookup__r),
        HasVisitToday: true,
        FeedbackSubmittedAt: submittedAt,
        StoreName: visit.StoreLookup__r ? visit.StoreLookup__r.Name : '',
        VisitDateDisplay: formatDate(visit.Visit_Date__c || visit.CreatedDate, true),
        VisitTimeDisplay: formatTime(visit.Entry_Time__c),
        VisitStatus: visit.Marked_As_Exited__c ? 'Completed' : 'Active',
        HasCompletedFeedback: hasCompletedFeedback,
        SelectLabel: hasCompletedFeedback ? 'View' : 'Select',
        SelectVariant: hasCompletedFeedback ? 'neutral' : 'brand'
    };
}

/** Profile-only model, used when the customer has no showroom visit today. */
export function buildCustomerOnlyModel(cust) {
    return {
        Id: null,
        Name: null,
        CUSTOMERlookup__c: cust.Id,
        CUSTOMERlookup__r: cust,
        ...buildCustomerFields(cust),
        HasVisitToday: false,
        HasCompletedFeedback: false
    };
}

/** Showroom line of the visit card, with the status shown as a pill. */
export function buildVisitHero(visit) {
    const v = visit || {};
    const isCompleted = v.VisitStatus === 'Completed';
    return {
        store: v.StoreName || 'Not available',
        status: v.VisitStatus || '',
        statusClass: isCompleted ? 'ojpv__pill ojpv__pill_done' : 'ojpv__pill'
    };
}

export function buildVisitTiles(visit) {
    const v = visit || {};
    if (v.HasVisitToday !== true) return [];
    return [
        { key: 'date', label: 'Visit Date', icon: 'utility:event', value: v.VisitDateDisplay },
        { key: 'time', label: 'Entry Time', icon: 'utility:clock', value: v.VisitTimeDisplay },
        { key: 'no', label: 'Visit Number', icon: 'utility:file', value: v.Name || 'Not available' }
    ];
}

export function buildSupportNumbers() {
    return SUPPORT_NUMBERS.map(display => ({
        display,
        href: 'tel:' + display.replace(/\s/g, '')
    }));
}

/** True when Apex rejected the call because the visit's feedback is already done. */
export function isAlreadySubmittedError(error) {
    const message = (error && error.body && error.body.message) || (error && error.message) || '';
    return String(message).indexOf(ALREADY_SUBMITTED) !== -1;
}