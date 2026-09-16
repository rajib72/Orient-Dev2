import { LightningElement, api, wire, track } from 'lwc';
import getSessions from '@salesforce/apex/SalesExecutiveSessionController.getSessions';
import getSalesExecutivesByShowroom from '@salesforce/apex/SalesExecutiveSessionController.getSalesExecutivesByShowroom';
import handoverSession from '@salesforce/apex/SalesExecutiveSessionController.handoverSession';
import markSessionExit from '@salesforce/apex/SalesExecutiveSessionController.markSessionExit';
import markSessionExitWithFollowUp from '@salesforce/apex/SalesExecutiveSessionController.markSessionExitWithFollowUp';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class SalesExecutiveSessionTracker extends NavigationMixin(LightningElement) {

    @api recordId;

    @track sessions = [];

    showModal = false;
    selectedSalesExecutive;

    showExitModal = false;
    exitSessionId;

    salesExecutiveOptions = [];

    updateExitTime = false;
    exitEndDate;
    exitEndTime;

    showFollowUpPage = false;
    followUpDate;

    selectedExitSession;
    isUpdateExitTimeMandatory = false;

    exitDuration = '00:00:00';
    previousDurationAtExit = '00:00:00';

    connectedCallback() {
        this.loadSessions();

        this.durationInterval = setInterval(() => {
            this.updateDurations();
        }, 1000);

        this.dataRefreshInterval = setInterval(() => {
            this.loadSessions();
        }, 5000);

        window.addEventListener('focus', this.handleWindowFocus);
        document.addEventListener('visibilitychange', this.handleVisibilityChange);
    }

    disconnectedCallback() {
        if (this.durationInterval) {
            clearInterval(this.durationInterval);
        }

        if (this.dataRefreshInterval) {
            clearInterval(this.dataRefreshInterval);
        }

        window.removeEventListener('focus', this.handleWindowFocus);
        document.removeEventListener('visibilitychange', this.handleVisibilityChange);
    }

    /* ================= DATE / TIME HELPERS ================= */

    getTodayDate() {
        const today = new Date();
        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');
        const day = String(today.getDate()).padStart(2, '0');

        return `${year}-${month}-${day}`;
    }

    getCurrentTime() {
        const now = new Date();

        return `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    }

    convertTimeStringToMilliseconds(timeValue) {
        if (!timeValue) {
            return null;
        }

        const parts = timeValue.split(':');
        const hour = parseInt(parts[0], 10);
        const minute = parseInt(parts[1], 10);

        return (hour * 60 * 60 * 1000) + (minute * 60 * 1000);
    }

    getCurrentTimeMilliseconds() {
        const now = new Date();

        return (
            now.getHours() * 60 * 60 * 1000
        ) + (
                now.getMinutes() * 60 * 1000
            ) + (
                now.getSeconds() * 1000
            );
    }

    getDateTime(dateValue, timeValue) {
        if (!dateValue || timeValue === null || timeValue === undefined) {
            return null;
        }

        const dateParts = dateValue.split('-');

        const year = parseInt(dateParts[0], 10);
        const month = parseInt(dateParts[1], 10) - 1;
        const day = parseInt(dateParts[2], 10);

        const totalSeconds = Math.floor(timeValue / 1000);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;

        return new Date(year, month, day, hours, minutes, seconds);
    }

    formatTime(milliseconds) {
        if (milliseconds === null || milliseconds === undefined) {
            return '';
        }

        const totalSeconds = Math.floor(milliseconds / 1000);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);

        const period = hours >= 12 ? 'PM' : 'AM';
        const displayHours = hours % 12 || 12;

        return `${displayHours}:${minutes.toString().padStart(2, '0')} ${period}`;
    }

    formatDate(dateValue) {
        if (!dateValue) {
            return '';
        }

        const dateParts = dateValue.split('-');

        const year = dateParts[0];
        const month = dateParts[1];
        const day = dateParts[2];

        return `${day}-${month}-${year}`;
    }

    formatDuration(milliseconds) {
        if (!milliseconds || milliseconds < 0) {
            return '00:00:00';
        }

        const totalSeconds = Math.floor(milliseconds / 1000);

        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;

        return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
    }

    isSelectedEndTimeFuture() {
        if (!this.exitEndTime) {
            return false;
        }

        const selectedEndDate = this.exitEndDate ? this.exitEndDate : this.getTodayDate();

        if (selectedEndDate !== this.getTodayDate()) {
            return false;
        }

        const selectedEndTimeMs = this.convertTimeStringToMilliseconds(this.exitEndTime);
        const currentTimeMs = this.getCurrentTimeMilliseconds();

        return selectedEndTimeMs > currentTimeMs;
    }

    calculateDurationMillisecondsForSession(s) {
        if (
            !s ||
            !s.rawStartDate ||
            s.rawStartTime === null ||
            s.rawStartTime === undefined
        ) {
            return 0;
        }

        const startDateTime = this.getDateTime(
            s.rawStartDate,
            s.rawStartTime
        );

        if (!startDateTime) {
            return 0;
        }

        let endDateTime;

        if (
            s.rawEndDate &&
            s.rawEndTime !== null &&
            s.rawEndTime !== undefined
        ) {
            endDateTime = this.getDateTime(
                s.rawEndDate,
                s.rawEndTime
            );
        } else {
            endDateTime = new Date();
        }

        const durationMilliseconds = endDateTime - startDateTime;

        if (durationMilliseconds <= 0) {
            return 0;
        }

        return durationMilliseconds;
    }

    calculateDuration(s) {
        if (s.isCompleted && s.durationText) {
            return s.durationText;
        }

        const durationMilliseconds = this.calculateDurationMillisecondsForSession(s);
        return this.formatDuration(durationMilliseconds);
    }

    updateDurations() {
        this.sessions = this.sessions.map(s => ({
            ...s,
            duration: this.calculateDuration(s)
        }));

        if (
            this.showExitModal &&
            this.selectedExitSession &&
            !this.updateExitTime
        ) {
            const runningMs = this.calculateDurationMillisecondsForSession(this.selectedExitSession);
            this.exitDuration = this.formatDuration(runningMs);
            this.previousDurationAtExit = this.formatDuration(runningMs);
        }
    }

    /* ================= LOAD SESSIONS ================= */

    loadSessions() {
        if (!this.recordId) {
            return;
        }

        getSessions({ showroomVisitId: this.recordId })
            .then(data => {
                this.sessions = data.map((s, index) => {
                    const row = {
                        ...s,

                        slNo: index + 1,

                        rawStartDate: s.startDate,
                        rawStartTime: s.startTime,
                        rawEndDate: s.endDate,
                        rawEndTime: s.endTime,

                        durationText: s.durationText,
                        previousDuration: s.previousDuration,

                        startDate: this.formatDate(s.startDate),
                        endDate: this.formatDate(s.endDate),

                        startTimeFormatted: this.formatTime(s.startTime),
                        endTimeFormatted: this.formatTime(s.endTime),

                        isCompleted: s.status === 'Completed',
                        isActive: s.status === 'Active',

                        statusClass:
                            s.status === 'Active'
                                ? 'status-active'
                                : 'status-completed'
                    };

                    row.duration = this.calculateDuration(row);
                    return row;
                });
            })
            .catch(error => {
                this.toast(
                    'Error',
                    error.body?.message || error.message || 'Unable to load sessions',
                    'error'
                );
            });
    }

    get noSessions() {
        return !this.sessions.length;
    }

    /* ================= SALES EXECUTIVES ================= */

    @wire(getSalesExecutivesByShowroom, { showroomVisitId: '$recordId' })
    wiredSalesExecs({ data, error }) {
        if (data) {
            this.salesExecutiveOptions = data.map(se => ({
                label: se.Name,
                value: se.Id
            }));
        } else if (error) {
            this.toast(
                'Error',
                error.body?.message || error.message || 'Unable to load Sales Executives',
                'error'
            );
        }
    }

    /* ================= HANDOVER ================= */

    openHandoverModal() {
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
        this.selectedSalesExecutive = null;
    }

    handleExecutiveChange(event) {
        this.selectedSalesExecutive = event.detail.value;
    }

    handleHandover() {
        if (!this.selectedSalesExecutive) {
            this.toast('Error', 'Please select Sales Executive', 'error');
            return;
        }

        /*
         * NEW VALIDATION:
         * User cannot handover active session to the same active Sales Executive.
         */
        const activeSession = this.sessions.find(s => s.status === 'Active');

        if (
            activeSession &&
            activeSession.salesExecutiveId &&
            activeSession.salesExecutiveId === this.selectedSalesExecutive
        ) {
            this.toast(
                'Error',
                'You cannot handover to the same active Sales Executive.',
                'error'
            );
            return;
        }

        handoverSession({
            showroomVisitId: this.recordId,
            newSalesExecutiveId: this.selectedSalesExecutive
        })
            .then(() => {
                this.toast('Success', 'Session handed over successfully', 'success');
                this.closeModal();
                this.loadSessions();
            })
            .catch(error => {
                this.toast(
                    'Error',
                    error.body?.message || error.message || 'Unable to handover session',
                    'error'
                );
            });
    }

    /* ================= MARK EXIT ================= */

    handleMarkExit(event) {
        this.exitSessionId = event.currentTarget.dataset.id;

        this.selectedExitSession = this.sessions.find(
            s => s.id === this.exitSessionId
        );

        const todayDate = this.getTodayDate();


        this.isUpdateExitTimeMandatory =
            this.selectedExitSession &&
            this.selectedExitSession.rawStartDate &&
            this.selectedExitSession.rawStartDate !== todayDate;


        if (this.isUpdateExitTimeMandatory) {
            this.updateExitTime = true;

            this.exitEndDate = this.selectedExitSession.rawStartDate;
            this.exitEndTime = null;
        } else {
            this.updateExitTime = false;
            this.exitEndDate = null;
            this.exitEndTime = null;
        }

        if (this.selectedExitSession) {
            const runningMs = this.calculateDurationMillisecondsForSession(this.selectedExitSession);

            this.previousDurationAtExit = this.formatDuration(runningMs);
            this.exitDuration = this.formatDuration(runningMs);
        } else {
            this.previousDurationAtExit = '00:00:00';
            this.exitDuration = '00:00:00';
        }

        this.showExitModal = true;
    }

    closeExitModal() {
        this.showExitModal = false;
        this.exitSessionId = null;

        this.updateExitTime = false;
        this.exitEndDate = null;
        this.exitEndTime = null;

        this.showFollowUpPage = false;
        this.followUpDate = null;

        this.selectedExitSession = null;
        this.isUpdateExitTimeMandatory = false;

        this.exitDuration = '00:00:00';
        this.previousDurationAtExit = '00:00:00';
    }

    /*handleUpdateExitTimeChange(event) {
        this.updateExitTime = event.target.checked;

        if (this.updateExitTime) {
            this.exitEndDate = this.getTodayDate();
            this.exitEndTime = this.getCurrentTime();
            this.calculateExitModalDuration();
        } else {
            if (this.isUpdateExitTimeMandatory) {
                this.updateExitTime = true;
                this.exitEndDate = this.getTodayDate();
                this.exitEndTime = this.getCurrentTime();
                this.calculateExitModalDuration();

                this.toast(
                    'Error',
                    'Update Exit Time is mandatory because session start date is not today.',
                    'error'
                );
                return;
            }

            this.exitEndDate = null;
            this.exitEndTime = null;

            if (this.selectedExitSession) {
                const runningMs = this.calculateDurationMillisecondsForSession(this.selectedExitSession);
                this.exitDuration = this.formatDuration(runningMs);
            } else {
                this.exitDuration = '00:00:00';
            }
        }
    }*/

    handleUpdateExitTimeChange(event) {
        this.updateExitTime = event.target.checked;

        if (this.updateExitTime) {
            this.exitEndDate = this.selectedExitSession
                ? this.selectedExitSession.rawStartDate
                : this.getTodayDate();

            this.exitEndTime = this.getCurrentTime();
            this.calculateExitModalDuration();
        } else {
            if (this.isUpdateExitTimeMandatory) {
                this.updateExitTime = true;

                this.exitEndDate = this.selectedExitSession
                    ? this.selectedExitSession.rawStartDate
                    : this.getTodayDate();

                this.exitEndTime = this.getCurrentTime();
                this.calculateExitModalDuration();

                this.toast(
                    'Error',
                    'Update Exit Time is mandatory because session start date is not today.',
                    'error'
                );
                return;
            }

            this.exitEndDate = null;
            this.exitEndTime = null;

            if (this.selectedExitSession) {
                const runningMs = this.calculateDurationMillisecondsForSession(this.selectedExitSession);
                this.exitDuration = this.formatDuration(runningMs);
            } else {
                this.exitDuration = '00:00:00';
            }
        }
    }

    handleExitEndDateChange(event) {
        this.exitEndDate = event.detail.value;
        this.calculateExitModalDuration();
    }

    /*handleExitEndTimeChange(event) {
        this.exitEndTime = event.detail.value;

        if (this.isSelectedEndTimeFuture()) {
            this.toast(
                'Error',
                'End Time cannot be greater than current time.',
                'error'
            );

            this.exitEndTime = null;
            this.exitDuration = '00:00:00';
            return;
        }

        this.calculateExitModalDuration();
    }*/

    handleExitEndTimeChange(event) {
        this.exitEndTime = event.detail.value;

        if (
            this.updateExitTime &&
            this.selectedExitSession &&
            this.selectedExitSession.rawStartDate
        ) {
            this.exitEndDate = this.selectedExitSession.rawStartDate;
        }

        this.calculateExitModalDuration();
    }

    calculateExitModalDuration() {
        if (!this.selectedExitSession) {
            this.exitDuration = '00:00:00';
            return;
        }

        const startDateTime = this.getDateTime(
            this.selectedExitSession.rawStartDate,
            this.selectedExitSession.rawStartTime
        );

        if (!startDateTime) {
            this.exitDuration = '00:00:00';
            return;
        }

        let endDateTime;

        if (this.updateExitTime && this.exitEndTime) {
            const endDate = this.exitEndDate ? this.exitEndDate : this.getTodayDate();
            const endTimeMs = this.convertTimeStringToMilliseconds(this.exitEndTime);

            endDateTime = this.getDateTime(
                endDate,
                endTimeMs
            );
        } else {
            endDateTime = new Date();
        }

        const durationMilliseconds = endDateTime - startDateTime;

        if (durationMilliseconds <= 0) {
            this.exitDuration = '00:00:00';
            return;
        }

        this.exitDuration = this.formatDuration(durationMilliseconds);
    }

    /* Old Method */

    /*validateExitTimeBeforeApex() {
        const todayDate = this.getTodayDate();

        if (
            this.selectedExitSession &&
            this.selectedExitSession.rawStartDate &&
            this.selectedExitSession.rawStartDate !== todayDate
        ) {
            this.isUpdateExitTimeMandatory = true;
            this.updateExitTime = true;
            this.exitEndDate = todayDate;

            if (!this.exitEndTime) {
                this.toast(
                    'Error',
                    'Please enter End Time. End Time is mandatory because session start date is not today.',
                    'error'
                );
                return false;
            }
        }

        if (this.updateExitTime) {
            if (!this.exitEndTime) {
                this.toast('Error', 'Please enter End Time.', 'error');
                return false;
            }

            if (this.isSelectedEndTimeFuture()) {
                this.toast(
                    'Error',
                    'End Time cannot be greater than current time.',
                    'error'
                );
                return false;
            }

            const startDateTime = this.getDateTime(
                this.selectedExitSession.rawStartDate,
                this.selectedExitSession.rawStartTime
            );

            const endTimeMs = this.convertTimeStringToMilliseconds(this.exitEndTime);
            const endDateTime = this.getDateTime(
                this.exitEndDate ? this.exitEndDate : todayDate,
                endTimeMs
            );

            if (startDateTime && endDateTime && endDateTime <= startDateTime) {
                this.toast(
                    'Error',
                    'Please give the end time always greater than start time.',
                    'error'
                );
                return false;
            }
        }

        return true;
    }*/

    /* Old Method */

    /* New Method */

    validateExitTimeBeforeApex() {
        const todayDate = this.getTodayDate();

        const normalizeDate = (dateValue) => {
            if (!dateValue) {
                return null;
            }

            if (typeof dateValue === 'string') {
                return dateValue.split('T')[0];
            }

            return dateValue;
        };

        if (!this.selectedExitSession) {
            this.toast('Error', 'Selected session is not available.', 'error');
            return false;
        }

        const startDate = normalizeDate(this.selectedExitSession.rawStartDate);

        if (!startDate) {
            this.toast('Error', 'Session start date is not available.', 'error');
            return false;
        }

        if (
            this.selectedExitSession.rawStartTime === null ||
            this.selectedExitSession.rawStartTime === undefined
        ) {
            this.toast('Error', 'Session start time is not available.', 'error');
            return false;
        }

        if (this.updateExitTime) {
            if (!this.exitEndTime) {
                this.toast('Error', 'Please enter End Time.', 'error');
                return false;
            }

            const startTimeMs = this.selectedExitSession.rawStartTime;
            const endTimeMs = this.convertTimeStringToMilliseconds(this.exitEndTime);

            if (endTimeMs === null || endTimeMs === undefined) {
                this.toast('Error', 'Invalid End Time.', 'error');
                return false;
            }

            /*
                Validation 1:
                End Time cannot be less than or equal to Start Time.
            */
            if (endTimeMs <= startTimeMs) {
                this.toast(
                    'Error',
                    'End Time cannot be less than or equal to Start Time.',
                    'error'
                );
                return false;
            }

            /*
                Validation 2:
                If Start Date is today, then End Time cannot be greater than current time.
                Example:
                Start Date: Today
                Start Time: 05:30 PM
                Current Time: 07:00 PM
                Entered End Time: 07:30 PM
                Result: Error
            */
            if (
                startDate === todayDate &&
                endTimeMs > this.getCurrentTimeMilliseconds()
            ) {
                this.toast(
                    'Error',
                    'Future time is not expected for same date.',
                    'error'
                );
                return false;
            }

            /*
                Final Mapping:
                Session_End_Date__c should be Start Date.
            */
            this.exitEndDate = startDate;
        }

        return true;
    }

    /* New Method */

    confirmMarkExit() {
        if (!this.validateExitTimeBeforeApex()) {
            return;
        }

        markSessionExit({
            showroomVisitId: this.recordId,
            endDateValue: this.updateExitTime ? this.exitEndDate : null,
            endTimeValue: this.updateExitTime ? this.exitEndTime : null,
            previousDurationValue: this.previousDurationAtExit
        })
            .then(() => {
                this.toast('Success', 'Session marked as exited', 'success');
                this.closeExitModal();
                this.loadSessions();
            })
            .catch(error => {
                this.toast(
                    'Error',
                    error.body?.message || error.message || 'Unable to mark exit',
                    'error'
                );
            });
    }

    /* ================= FOLLOW UP ================= */

    handleFollowUpDateChange(event) {
        this.followUpDate = event.detail.value;

        /*
         * NEW VALIDATION:
         * Follow Up Date cannot be past date.
         */
        if (this.followUpDate && this.followUpDate < this.getTodayDate()) {
            this.toast(
                'Error',
                'Follow Up Date cannot be a past date.',
                'error'
            );

            this.followUpDate = null;
        }
    }

    openFollowUpPage() {
        if (!this.validateExitTimeBeforeApex()) {
            return;
        }

        this.showFollowUpPage = true;
    }

    backToExitPage() {
        this.showFollowUpPage = false;
    }

    confirmExitWithFollowUp() {
        if (!this.validateExitTimeBeforeApex()) {
            return;
        }

        if (!this.followUpDate) {
            this.toast('Error', 'Please select Next Follow Up Date', 'error');
            return;
        }

        /*
         * NEW VALIDATION:
         * Follow Up Date cannot be past date.
         */
        if (this.followUpDate < this.getTodayDate()) {
            this.toast(
                'Error',
                'Follow Up Date cannot be a past date.',
                'error'
            );
            return;
        }

        markSessionExitWithFollowUp({
            showroomVisitId: this.recordId,
            endDateValue: this.updateExitTime ? this.exitEndDate : null,
            endTimeValue: this.updateExitTime ? this.exitEndTime : null,
            previousDurationValue: this.previousDurationAtExit,
            followUpDate: this.followUpDate
        })
            .then(() => {
                this.toast('Success', 'Session exited and follow up task created', 'success');
                this.closeExitModal();
                this.loadSessions();
            })
            .catch(error => {
                this.toast(
                    'Error',
                    error.body?.message || error.message || 'Unable to save follow up',
                    'error'
                );
            });
    }

    /* ================= VIEW ================= */

    handleView(event) {
        const recordId = event.currentTarget.dataset.id;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Sales_Executive_Activity_Tracking__c',
                actionName: 'view'
            }
        });
    }

    /* ================= REFRESH EVENTS ================= */

    handleWindowFocus = () => {
        this.loadSessions();
    };

    handleVisibilityChange = () => {
        if (!document.hidden) {
            this.loadSessions();
        }
    };

    /* ================= TOAST ================= */

    toast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}