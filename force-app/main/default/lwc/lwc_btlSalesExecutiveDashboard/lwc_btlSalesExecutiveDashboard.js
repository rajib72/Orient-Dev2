import {
    LightningElement,
    wire
} from 'lwc';

import {
    NavigationMixin
} from 'lightning/navigation';

import {
    refreshApex
} from '@salesforce/apex';

import LightningConfirm from 'lightning/confirm';

import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';

import getDashboardContext from
    '@salesforce/apex/Ctrl_BTLSalesExecutiveDashboard.getDashboardContext';

import getDashboardData from
    '@salesforce/apex/Ctrl_BTLSalesExecutiveDashboard.getDashboardData';

import startActivity from
    '@salesforce/apex/Ctrl_BTLSalesExecutiveDashboard.startActivity';

import completeActivity from
    '@salesforce/apex/Ctrl_BTLSalesExecutiveDashboard.completeActivity';

import getActivityResponses from
    '@salesforce/apex/Ctrl_BTLSalesExecutiveDashboard.getActivityResponses';

export default class LwcBtlSalesExecutiveDashboard
    extends NavigationMixin(LightningElement) {

    isLoading = false;
    isSystemAdministrator = false;

    activeTab = 'TODAY';
    selectedStoreId = '';
    storeOptions = [];

    activities = [];
    serverDate;

    dashboardTabName;
    dashboardStoreId;
    wiredDashboardResult;

    showExecutionModal = false;
    executionStep = 'ATTENDANCE';

    selectedActivity;
    attendanceMembers = [];

    showResponseModal = false;
    isResponseLoading = false;
    responses = [];

    midnightTimer;
    interactiveFormModalView = true;

    connectedCallback() {
        this.initializeDashboard();
        this.scheduleMidnightRefresh();
    }

    disconnectedCallback() {
        if (this.midnightTimer) {
            window.clearTimeout(
                this.midnightTimer
            );
        }
    }

    @wire(
        getDashboardData,
        {
            tabName: '$dashboardTabName',
            selectedStoreId: '$dashboardStoreId'
        }
    )
    wiredDashboard(result) {
        this.wiredDashboardResult = result;

        const {
            data,
            error
        } = result;

        if (data) {
            this.serverDate =
                data.serverDate;

            this.activities =
                (data.activities || []).map(
                    (activity, index) =>
                        this.prepareActivity(
                            activity,
                            index
                        )
                );

            this.isLoading = false;
        } else if (error) {
            this.activities = [];
            this.isLoading = false;

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        }
    }

    async initializeDashboard() {
        this.isLoading = true;

        try {
            const context =
                await getDashboardContext();

            this.isSystemAdministrator =
                context.isSystemAdministrator === true;

            this.storeOptions =
                context.storeOptions || [];

            this.selectedStoreId =
                context.defaultStoreId || '';

            this.dashboardTabName =
                this.activeTab;

            this.dashboardStoreId =
                this.selectedStoreId || null;

        } catch (error) {
            this.isLoading = false;

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        }
    }

    prepareActivity(activity, index) {
        const members =
            (activity.members || []).map(
                member => ({
                    ...member,
                    memberName:
                        member.memberName ||
                        'Unnamed Member'
                })
            );

        const displayStatus =
            activity.status === 'Live'
            ? 'Ready to Start'
            : activity.status;

        return {
            ...activity,

            serialNo:
                index + 1,

            rowKey:
                activity.dailyExecutionId ||
                `${activity.activityId}-${activity.activityDate}`,

            members,

            activityLocationLabel:
                activity.activityLocation || '-',

            displayStatus,

            formattedDate:
                this.formatDate(
                    activity.activityDate
                ),

            formattedStartTime:
                this.formatTime(
                    activity.startDateTime
                ),

            formattedCompletedTime:
                this.formatTime(
                    activity.completedDateTime
                ),

            statusClass:
                this.getStatusClass(
                    activity.status
                ),

            showExpiredMessage:
                activity.status === 'Expired'
        };
    }

    get isTodayTab() {
        return this.activeTab === 'TODAY';
    }

    get todayTabClass() {
        return this.isTodayTab
            ? 'sidebar-button active'
            : 'sidebar-button';
    }

    get pastTabClass() {
        return !this.isTodayTab
            ? 'sidebar-button active'
            : 'sidebar-button';
    }

    get storeSelectionDisabled() {
        return !this.isSystemAdministrator;
    }

    get sectionTitle() {
        return this.isTodayTab
            ? 'Today’s Activities Overview'
            : 'Past Activities';
    }

    get activityCount() {
        return this.activities.length;
    }

    get hasActivities() {
        return this.activities.length > 0;
    }

    get totalActivities() {
        return this.activities.length;
    }

    get readyToStartActivities() {
        return this.activities.filter(
            activity =>
                activity.status === 'Live'
        ).length;
    }

    get completedActivities() {
        return this.activities.filter(
            activity =>
                activity.status === 'Completed'
        ).length;
    }

    get inProgressActivities() {
        return this.activities.filter(
            activity =>
                activity.status === 'In Progress'
        ).length;
    }

    get currentDateLabel() {
        const dateValue =
            this.toLocalDate(
                this.serverDate
            ) || new Date();

        return new Intl.DateTimeFormat(
            'en-IN',
            {
                day: '2-digit',
                month: 'short',
                year: 'numeric'
            }
        ).format(dateValue);
    }

    get currentDayLabel() {
        const dateValue =
            this.toLocalDate(
                this.serverDate
            ) || new Date();

        return new Intl.DateTimeFormat(
            'en-IN',
            {
                weekday: 'long'
            }
        ).format(dateValue);
    }

    get emptyStateMessage() {
        return this.isTodayTab
            ? 'No approved BTL activities are live for today.'
            : 'No past BTL activities were found.';
    }

    get isAttendanceStep() {
        return (
            this.executionStep ===
            'ATTENDANCE'
        );
    }

    get isFormStep() {
        return (
            this.executionStep ===
            'FORM'
        );
    }

    get executionModalTitle() {
        return this.isAttendanceStep
            ? 'Start BTL Activity'
            : 'Capture BTL Response';
    }

    get attendanceStepClass() {
        return this.isAttendanceStep
            ? 'step-item active'
            : 'step-item completed';
    }

    get formStepClass() {
        return this.isFormStep
            ? 'step-item active'
            : 'step-item';
    }

    get selectedAttendanceCount() {
        return this.attendanceMembers.filter(
            member => member.checked
        ).length;
    }

    get disableStartActivity() {
        return (
            this.selectedAttendanceCount === 0 ||
            this.isLoading
        );
    }

    get hasResponses() {
        return (
            !this.isResponseLoading &&
            this.responses.length > 0
        );
    }

    get showNoResponses() {
        return (
            !this.isResponseLoading &&
            this.responses.length === 0
        );
    }

    handleTabChange(event) {
        const selectedTab =
            event.currentTarget.dataset.tab;

        if (
            selectedTab ===
            this.activeTab
        ) {
            return;
        }

        this.activeTab =
            selectedTab;

        this.isLoading =
            true;

        this.dashboardTabName =
            selectedTab;
    }

    handleStoreChange(event) {
        this.selectedStoreId =
            event.detail.value;

        this.isLoading =
            true;

        this.dashboardStoreId =
            this.selectedStoreId || null;
    }

    async handleRefresh() {
        await this.refreshDashboardData(
            true
        );
    }

    async refreshDashboardData(
        showSuccessToast = false
    ) {
        if (!this.wiredDashboardResult) {
            await this.initializeDashboard();
            return;
        }

        this.isLoading = true;

        try {
            await refreshApex(
                this.wiredDashboardResult
            );

            if (showSuccessToast) {
                this.showToast(
                    'Refreshed',
                    'The dashboard has been refreshed.',
                    'success'
                );
            }
        } catch (error) {
            this.showToast(
                'Refresh Failed',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleStart(event) {
        const rowKey =
            event.currentTarget.dataset.key;

        this.selectedActivity =
            this.activities.find(
                activity =>
                    activity.rowKey === rowKey
            );

        if (!this.selectedActivity) {
            return;
        }

        if (
            !this.selectedActivity
                .dailyExecutionId
        ) {
            this.showToast(
                'Daily Execution Missing',
                'The Daily Execution record was not found for this activity.',
                'error'
            );

            this.selectedActivity =
                null;

            return;
        }

        this.attendanceMembers =
            this.selectedActivity.members.map(
                member => {
                    const checked =
                        member.present === true;

                    return {
                        ...member,

                        checked,

                        initials:
                            this.getInitials(
                                member.memberName
                            ),

                        attendanceClass:
                            checked
                            ? 'attendance-member selected'
                            : 'attendance-member'
                    };
                }
            );

        this.executionStep =
            'ATTENDANCE';

        this.showExecutionModal =
            true;
    }

    handleContinue(event) {
        const rowKey =
            event.currentTarget.dataset.key;

        this.selectedActivity =
            this.activities.find(
                activity =>
                    activity.rowKey === rowKey
            );

        if (!this.selectedActivity) {
            return;
        }

        if (
            !this.selectedActivity
                .dailyExecutionId
        ) {
            this.showToast(
                'Daily Execution Missing',
                'The Daily Execution record was not found for this activity.',
                'error'
            );

            this.selectedActivity =
                null;

            return;
        }

        this.executionStep =
            'FORM';

        this.showExecutionModal =
            true;
    }

    handleAttendanceChange(event) {
        const dateAssignmentId =
            event.target.dataset.id;

        const checked =
            event.target.checked;

        this.attendanceMembers =
            this.attendanceMembers.map(
                member => {
                    if (
                        member.dateAssignmentId !==
                        dateAssignmentId
                    ) {
                        return member;
                    }

                    return {
                        ...member,

                        checked,

                        attendanceClass:
                            checked
                            ? 'attendance-member selected'
                            : 'attendance-member'
                    };
                }
            );
    }

    async handleStartActivity() {
        const presentDateAssignmentIds =
            this.attendanceMembers
                .filter(
                    member =>
                        member.checked
                )
                .map(
                    member =>
                        member.dateAssignmentId
                );

        if (
            presentDateAssignmentIds.length === 0
        ) {
            this.showToast(
                'Attendance Required',
                'Please mark at least one member as Present.',
                'error'
            );

            return;
        }

        if (
            !this.selectedActivity ||
            !this.selectedActivity
                .dailyExecutionId
        ) {
            this.showToast(
                'Error',
                'Daily Execution Id is missing.',
                'error'
            );

            return;
        }

        this.isLoading = true;

        try {
            await startActivity({
                dailyExecutionId:
                    this.selectedActivity
                        .dailyExecutionId,

                presentDateAssignmentIds
            });

            this.executionStep =
                'FORM';

            this.showToast(
                'Activity Started',
                'Attendance was saved successfully.',
                'success'
            );

            await this.refreshDashboardData(
                false
            );

        } catch (error) {
            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async handleComplete(event) {
        const rowKey =
            event.currentTarget.dataset.key;

        const activity =
            this.activities.find(
                row =>
                    row.rowKey === rowKey
            );

        if (!activity) {
            return;
        }

        if (!activity.dailyExecutionId) {
            this.showToast(
                'Error',
                'Daily Execution Id is missing.',
                'error'
            );

            return;
        }

        const confirmed =
            await LightningConfirm.open({
                label:
                    'Complete Activity',

                theme:
                    'warning',

                message:
                    'After completion, no additional BTL responses can be captured for this activity. Do you want to continue?'
            });

        if (!confirmed) {
            return;
        }

        this.isLoading = true;

        try {
            await completeActivity({
                dailyExecutionId:
                    activity.dailyExecutionId
            });

            this.showToast(
                'Activity Completed',
                'The BTL activity has been completed successfully.',
                'success'
            );

            await this.refreshDashboardData(
                false
            );

        } catch (error) {
            this.showToast(
                'Unable to Complete',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async handleViewResponses(event) {
        const rowKey =
            event.currentTarget.dataset.key;

        this.selectedActivity =
            this.activities.find(
                row =>
                    row.rowKey === rowKey
            );

        if (!this.selectedActivity) {
            return;
        }

        if (
            !this.selectedActivity
                .dailyExecutionId
        ) {
            this.showToast(
                'Error',
                'Daily Execution Id is missing.',
                'error'
            );

            this.selectedActivity =
                null;

            return;
        }

        this.responses = [];
        this.showResponseModal = true;
        this.isResponseLoading = true;

        try {
            const result =
                await getActivityResponses({
                    dailyExecutionId:
                        this.selectedActivity
                            .dailyExecutionId
                });

            this.responses =
                (result || []).map(
                    response => ({
                        ...response,

                        customerName:
                            response.customerName ||
                            'Prospect Customer',

                        executiveNames:
                            response.executiveNames ||
                            '-',

                        formattedDateTime:
                            this.formatDateTime(
                                response.actualDateTime
                            )
                    })
                );

        } catch (error) {
            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isResponseLoading = false;
        }
    }

    handleOpenResponse(event) {
        const responseId =
            event.currentTarget.dataset.id;

        this[
            NavigationMixin.Navigate
        ]({
            type:
                'standard__recordPage',

            attributes: {
                recordId:
                    responseId,

                objectApiName:
                    'BTL_Customer_Response__c',

                actionName:
                    'view'
            }
        });
    }

    async handleFormBack() {
        this.closeExecutionModal();

        await this.refreshDashboardData(
            false
        );
    }

    closeExecutionModal() {
        this.showExecutionModal =
            false;

        this.executionStep =
            'ATTENDANCE';

        this.selectedActivity =
            null;

        this.attendanceMembers =
            [];
    }

    closeResponseModal() {
        this.showResponseModal =
            false;

        this.responses =
            [];

        this.selectedActivity =
            null;
    }

    getStatusClass(status) {
        switch (status) {
            case 'Live':
                return (
                    'status-pill ' +
                    'ready-status'
                );

            case 'Completed':
                return (
                    'status-pill ' +
                    'completed-status'
                );

            case 'In Progress':
                return (
                    'status-pill ' +
                    'progress-status'
                );

            case 'Expired':
                return (
                    'status-pill ' +
                    'expired-status'
                );

            case 'Pending Initiation':
                return (
                    'status-pill ' +
                    'pending-status'
                );

            default:
                return (
                    'status-pill ' +
                    'pending-status'
                );
        }
    }

    getInitials(memberName) {
        if (!memberName) {
            return 'NA';
        }

        return memberName
            .trim()
            .split(/\s+/)
            .slice(0, 2)
            .map(
                word =>
                    word.charAt(0)
                        .toUpperCase()
            )
            .join('');
    }

    formatDate(value) {
        const dateValue =
            this.toLocalDate(value);

        if (!dateValue) {
            return '-';
        }

        return new Intl.DateTimeFormat(
            'en-IN',
            {
                day: '2-digit',
                month: 'short',
                year: 'numeric'
            }
        ).format(dateValue);
    }

    formatTime(value) {
        if (!value) {
            return '-';
        }

        return new Intl.DateTimeFormat(
            'en-IN',
            {
                hour: '2-digit',
                minute: '2-digit',
                hour12: true
            }
        ).format(
            new Date(value)
        );
    }

    formatDateTime(value) {
        if (!value) {
            return '-';
        }

        return new Intl.DateTimeFormat(
            'en-IN',
            {
                day: '2-digit',
                month: 'short',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
                hour12: true
            }
        ).format(
            new Date(value)
        );
    }

    toLocalDate(value) {
        if (!value) {
            return null;
        }

        if (value instanceof Date) {
            return value;
        }

        const parts =
            String(value).split('-');

        if (parts.length !== 3) {
            return new Date(value);
        }

        return new Date(
            Number(parts[0]),
            Number(parts[1]) - 1,
            Number(parts[2])
        );
    }

    scheduleMidnightRefresh() {
        const now =
            new Date();

        const nextMidnight =
            new Date(
                now.getFullYear(),
                now.getMonth(),
                now.getDate() + 1,
                0,
                0,
                2,
                0
            );

        const timeout =
            nextMidnight.getTime() -
            now.getTime();

        this.midnightTimer =
            window.setTimeout(
                async () => {
                    await this
                        .refreshDashboardData(
                            false
                        );

                    this.scheduleMidnightRefresh();
                },
                timeout
            );
    }

    showToast(
        title,
        message,
        variant
    ) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    getErrorMessage(error) {
        if (
            error &&
            Array.isArray(error.body)
        ) {
            return error.body
                .map(
                    item =>
                        item.message
                )
                .join(', ');
        }

        if (
            error &&
            error.body &&
            error.body.message
        ) {
            return error.body.message;
        }

        if (
            error &&
            error.message
        ) {
            return error.message;
        }

        return 'Something went wrong.';
    }
}

// import {
//     LightningElement,
//     wire
// } from 'lwc';

// import {
//     NavigationMixin
// } from 'lightning/navigation';

// import {
//     refreshApex
// } from '@salesforce/apex';

// import LightningConfirm from 'lightning/confirm';

// import {
//     ShowToastEvent
// } from 'lightning/platformShowToastEvent';

// import getDashboardContext from
//     '@salesforce/apex/Ctrl_BTLSalesExecutiveDashboard.getDashboardContext';

// import getDashboardData from
//     '@salesforce/apex/Ctrl_BTLSalesExecutiveDashboard.getDashboardData';

// import startActivity from
//     '@salesforce/apex/Ctrl_BTLSalesExecutiveDashboard.startActivity';

// import completeActivity from
//     '@salesforce/apex/Ctrl_BTLSalesExecutiveDashboard.completeActivity';

// import getActivityResponses from
//     '@salesforce/apex/Ctrl_BTLSalesExecutiveDashboard.getActivityResponses';

// export default class LwcBtlSalesExecutiveDashboard
//     extends NavigationMixin(LightningElement) {

//     isLoading = false;
//     isSystemAdministrator = false;

//     activeTab = 'TODAY';
//     selectedStoreId = '';
//     storeOptions = [];

//     activities = [];
//     serverDate;

//     dashboardTabName;
//     dashboardStoreId;
//     wiredDashboardResult;

//     showExecutionModal = false;
//     executionStep = 'ATTENDANCE';

//     selectedActivity;
//     attendanceMembers = [];

//     showResponseModal = false;
//     isResponseLoading = false;
//     responses = [];

//     midnightTimer;
//     interactiveFormModalView = true;

//     connectedCallback() {
//         this.initializeDashboard();
//         this.scheduleMidnightRefresh();
//     }

//     disconnectedCallback() {
//         if (this.midnightTimer) {
//             window.clearTimeout(
//                 this.midnightTimer
//             );
//         }
//     }

//     @wire(
//         getDashboardData,
//         {
//             tabName: '$dashboardTabName',
//             selectedStoreId: '$dashboardStoreId'
//         }
//     )
//     wiredDashboard(result) {
//         this.wiredDashboardResult = result;

//         const {
//             data,
//             error
//         } = result;

//         if (data) {
//             this.serverDate =
//                 data.serverDate;

//             this.activities =
//                 (data.activities || []).map(
//                     (activity, index) =>
//                         this.prepareActivity(
//                             activity,
//                             index
//                         )
//                 );

//             this.isLoading = false;
//         } else if (error) {
//             this.activities = [];
//             this.isLoading = false;

//             this.showToast(
//                 'Error',
//                 this.getErrorMessage(error),
//                 'error'
//             );
//         }
//     }

//     async initializeDashboard() {
//         this.isLoading = true;

//         try {
//             const context =
//                 await getDashboardContext();

//             this.isSystemAdministrator =
//                 context.isSystemAdministrator === true;

//             this.storeOptions =
//                 context.storeOptions || [];

//             this.selectedStoreId =
//                 context.defaultStoreId || '';

//             this.dashboardTabName =
//                 this.activeTab;

//             this.dashboardStoreId =
//                 this.selectedStoreId || null;

//         } catch (error) {
//             this.isLoading = false;

//             this.showToast(
//                 'Error',
//                 this.getErrorMessage(error),
//                 'error'
//             );
//         }
//     }

//     prepareActivity(activity, index) {
//         const members =
//             (activity.members || []).map(
//                 member => ({
//                     ...member,
//                     memberName:
//                         member.memberName ||
//                         'Unnamed Member'
//                 })
//             );

//         const displayStatus =
//             activity.status === 'Live'
//             ? 'Ready to Start'
//             : activity.status;

//         return {
//             ...activity,

//             serialNo:
//                 index + 1,

//             rowKey:
//                 activity.dailyExecutionId ||
//                 `${activity.activityId}-${activity.activityDate}`,

//             members,

//             displayStatus,

//             formattedDate:
//                 this.formatDate(
//                     activity.activityDate
//                 ),

//             formattedStartTime:
//                 this.formatTime(
//                     activity.startDateTime
//                 ),

//             formattedCompletedTime:
//                 this.formatTime(
//                     activity.completedDateTime
//                 ),

//             statusClass:
//                 this.getStatusClass(
//                     activity.status
//                 ),

//             showExpiredMessage:
//                 activity.status === 'Expired'
//         };
//     }

//     get isTodayTab() {
//         return this.activeTab === 'TODAY';
//     }

//     get todayTabClass() {
//         return this.isTodayTab
//             ? 'sidebar-button active'
//             : 'sidebar-button';
//     }

//     get pastTabClass() {
//         return !this.isTodayTab
//             ? 'sidebar-button active'
//             : 'sidebar-button';
//     }

//     get storeSelectionDisabled() {
//         return !this.isSystemAdministrator;
//     }

//     get sectionTitle() {
//         return this.isTodayTab
//             ? 'Today’s Activities Overview'
//             : 'Past Activities';
//     }

//     get activityCount() {
//         return this.activities.length;
//     }

//     get hasActivities() {
//         return this.activities.length > 0;
//     }

//     get totalActivities() {
//         return this.activities.length;
//     }

//     get readyToStartActivities() {
//         return this.activities.filter(
//             activity =>
//                 activity.status === 'Live'
//         ).length;
//     }

//     get completedActivities() {
//         return this.activities.filter(
//             activity =>
//                 activity.status === 'Completed'
//         ).length;
//     }

//     get inProgressActivities() {
//         return this.activities.filter(
//             activity =>
//                 activity.status === 'In Progress'
//         ).length;
//     }

//     get currentDateLabel() {
//         const dateValue =
//             this.toLocalDate(
//                 this.serverDate
//             ) || new Date();

//         return new Intl.DateTimeFormat(
//             'en-IN',
//             {
//                 day: '2-digit',
//                 month: 'short',
//                 year: 'numeric'
//             }
//         ).format(dateValue);
//     }

//     get currentDayLabel() {
//         const dateValue =
//             this.toLocalDate(
//                 this.serverDate
//             ) || new Date();

//         return new Intl.DateTimeFormat(
//             'en-IN',
//             {
//                 weekday: 'long'
//             }
//         ).format(dateValue);
//     }

//     get emptyStateMessage() {
//         return this.isTodayTab
//             ? 'No approved BTL activities are live for today.'
//             : 'No past BTL activities were found.';
//     }

//     get isAttendanceStep() {
//         return (
//             this.executionStep ===
//             'ATTENDANCE'
//         );
//     }

//     get isFormStep() {
//         return (
//             this.executionStep ===
//             'FORM'
//         );
//     }

//     get executionModalTitle() {
//         return this.isAttendanceStep
//             ? 'Start BTL Activity'
//             : 'Capture BTL Response';
//     }

//     get attendanceStepClass() {
//         return this.isAttendanceStep
//             ? 'step-item active'
//             : 'step-item completed';
//     }

//     get formStepClass() {
//         return this.isFormStep
//             ? 'step-item active'
//             : 'step-item';
//     }

//     get selectedAttendanceCount() {
//         return this.attendanceMembers.filter(
//             member => member.checked
//         ).length;
//     }

//     get disableStartActivity() {
//         return (
//             this.selectedAttendanceCount === 0 ||
//             this.isLoading
//         );
//     }

//     get hasResponses() {
//         return (
//             !this.isResponseLoading &&
//             this.responses.length > 0
//         );
//     }

//     get showNoResponses() {
//         return (
//             !this.isResponseLoading &&
//             this.responses.length === 0
//         );
//     }

//     handleTabChange(event) {
//         const selectedTab =
//             event.currentTarget.dataset.tab;

//         if (
//             selectedTab ===
//             this.activeTab
//         ) {
//             return;
//         }

//         this.activeTab =
//             selectedTab;

//         this.isLoading =
//             true;

//         this.dashboardTabName =
//             selectedTab;
//     }

//     handleStoreChange(event) {
//         this.selectedStoreId =
//             event.detail.value;

//         this.isLoading =
//             true;

//         this.dashboardStoreId =
//             this.selectedStoreId || null;
//     }

//     async handleRefresh() {
//         await this.refreshDashboardData(
//             true
//         );
//     }

//     async refreshDashboardData(
//         showSuccessToast = false
//     ) {
//         if (!this.wiredDashboardResult) {
//             await this.initializeDashboard();
//             return;
//         }

//         this.isLoading = true;

//         try {
//             await refreshApex(
//                 this.wiredDashboardResult
//             );

//             if (showSuccessToast) {
//                 this.showToast(
//                     'Refreshed',
//                     'The dashboard has been refreshed.',
//                     'success'
//                 );
//             }
//         } catch (error) {
//             this.showToast(
//                 'Refresh Failed',
//                 this.getErrorMessage(error),
//                 'error'
//             );
//         } finally {
//             this.isLoading = false;
//         }
//     }

//     handleStart(event) {
//         const rowKey =
//             event.currentTarget.dataset.key;

//         this.selectedActivity =
//             this.activities.find(
//                 activity =>
//                     activity.rowKey === rowKey
//             );

//         if (!this.selectedActivity) {
//             return;
//         }

//         if (
//             !this.selectedActivity
//                 .dailyExecutionId
//         ) {
//             this.showToast(
//                 'Daily Execution Missing',
//                 'The Daily Execution record was not found for this activity.',
//                 'error'
//             );

//             this.selectedActivity =
//                 null;

//             return;
//         }

//         this.attendanceMembers =
//             this.selectedActivity.members.map(
//                 member => {
//                     const checked =
//                         member.present === true;

//                     return {
//                         ...member,

//                         checked,

//                         initials:
//                             this.getInitials(
//                                 member.memberName
//                             ),

//                         attendanceClass:
//                             checked
//                             ? 'attendance-member selected'
//                             : 'attendance-member'
//                     };
//                 }
//             );

//         this.executionStep =
//             'ATTENDANCE';

//         this.showExecutionModal =
//             true;
//     }

//     handleContinue(event) {
//         const rowKey =
//             event.currentTarget.dataset.key;

//         this.selectedActivity =
//             this.activities.find(
//                 activity =>
//                     activity.rowKey === rowKey
//             );

//         if (!this.selectedActivity) {
//             return;
//         }

//         if (
//             !this.selectedActivity
//                 .dailyExecutionId
//         ) {
//             this.showToast(
//                 'Daily Execution Missing',
//                 'The Daily Execution record was not found for this activity.',
//                 'error'
//             );

//             this.selectedActivity =
//                 null;

//             return;
//         }

//         this.executionStep =
//             'FORM';

//         this.showExecutionModal =
//             true;
//     }

//     handleAttendanceChange(event) {
//         const dateAssignmentId =
//             event.target.dataset.id;

//         const checked =
//             event.target.checked;

//         this.attendanceMembers =
//             this.attendanceMembers.map(
//                 member => {
//                     if (
//                         member.dateAssignmentId !==
//                         dateAssignmentId
//                     ) {
//                         return member;
//                     }

//                     return {
//                         ...member,

//                         checked,

//                         attendanceClass:
//                             checked
//                             ? 'attendance-member selected'
//                             : 'attendance-member'
//                     };
//                 }
//             );
//     }

//     async handleStartActivity() {
//         const presentDateAssignmentIds =
//             this.attendanceMembers
//                 .filter(
//                     member =>
//                         member.checked
//                 )
//                 .map(
//                     member =>
//                         member.dateAssignmentId
//                 );

//         if (
//             presentDateAssignmentIds.length === 0
//         ) {
//             this.showToast(
//                 'Attendance Required',
//                 'Please mark at least one member as Present.',
//                 'error'
//             );

//             return;
//         }

//         if (
//             !this.selectedActivity ||
//             !this.selectedActivity
//                 .dailyExecutionId
//         ) {
//             this.showToast(
//                 'Error',
//                 'Daily Execution Id is missing.',
//                 'error'
//             );

//             return;
//         }

//         this.isLoading = true;

//         try {
//             await startActivity({
//                 dailyExecutionId:
//                     this.selectedActivity
//                         .dailyExecutionId,

//                 presentDateAssignmentIds
//             });

//             this.executionStep =
//                 'FORM';

//             this.showToast(
//                 'Activity Started',
//                 'Attendance was saved successfully.',
//                 'success'
//             );

//             await this.refreshDashboardData(
//                 false
//             );

//         } catch (error) {
//             this.showToast(
//                 'Error',
//                 this.getErrorMessage(error),
//                 'error'
//             );
//         } finally {
//             this.isLoading = false;
//         }
//     }

//     async handleComplete(event) {
//         const rowKey =
//             event.currentTarget.dataset.key;

//         const activity =
//             this.activities.find(
//                 row =>
//                     row.rowKey === rowKey
//             );

//         if (!activity) {
//             return;
//         }

//         if (!activity.dailyExecutionId) {
//             this.showToast(
//                 'Error',
//                 'Daily Execution Id is missing.',
//                 'error'
//             );

//             return;
//         }

//         const confirmed =
//             await LightningConfirm.open({
//                 label:
//                     'Complete Activity',

//                 theme:
//                     'warning',

//                 message:
//                     'After completion, no additional BTL responses can be captured for this activity. Do you want to continue?'
//             });

//         if (!confirmed) {
//             return;
//         }

//         this.isLoading = true;

//         try {
//             await completeActivity({
//                 dailyExecutionId:
//                     activity.dailyExecutionId
//             });

//             this.showToast(
//                 'Activity Completed',
//                 'The BTL activity has been completed successfully.',
//                 'success'
//             );

//             await this.refreshDashboardData(
//                 false
//             );

//         } catch (error) {
//             this.showToast(
//                 'Unable to Complete',
//                 this.getErrorMessage(error),
//                 'error'
//             );
//         } finally {
//             this.isLoading = false;
//         }
//     }

//     async handleViewResponses(event) {
//         const rowKey =
//             event.currentTarget.dataset.key;

//         this.selectedActivity =
//             this.activities.find(
//                 row =>
//                     row.rowKey === rowKey
//             );

//         if (!this.selectedActivity) {
//             return;
//         }

//         if (
//             !this.selectedActivity
//                 .dailyExecutionId
//         ) {
//             this.showToast(
//                 'Error',
//                 'Daily Execution Id is missing.',
//                 'error'
//             );

//             this.selectedActivity =
//                 null;

//             return;
//         }

//         this.responses = [];
//         this.showResponseModal = true;
//         this.isResponseLoading = true;

//         try {
//             const result =
//                 await getActivityResponses({
//                     dailyExecutionId:
//                         this.selectedActivity
//                             .dailyExecutionId
//                 });

//             this.responses =
//                 (result || []).map(
//                     response => ({
//                         ...response,

//                         customerName:
//                             response.customerName ||
//                             'Prospect Customer',

//                         executiveNames:
//                             response.executiveNames ||
//                             '-',

//                         formattedDateTime:
//                             this.formatDateTime(
//                                 response.actualDateTime
//                             )
//                     })
//                 );

//         } catch (error) {
//             this.showToast(
//                 'Error',
//                 this.getErrorMessage(error),
//                 'error'
//             );
//         } finally {
//             this.isResponseLoading = false;
//         }
//     }

//     handleOpenResponse(event) {
//         const responseId =
//             event.currentTarget.dataset.id;

//         this[
//             NavigationMixin.Navigate
//         ]({
//             type:
//                 'standard__recordPage',

//             attributes: {
//                 recordId:
//                     responseId,

//                 objectApiName:
//                     'BTL_Customer_Response__c',

//                 actionName:
//                     'view'
//             }
//         });
//     }

//     async handleFormBack() {
//         this.closeExecutionModal();

//         await this.refreshDashboardData(
//             false
//         );
//     }

//     closeExecutionModal() {
//         this.showExecutionModal =
//             false;

//         this.executionStep =
//             'ATTENDANCE';

//         this.selectedActivity =
//             null;

//         this.attendanceMembers =
//             [];
//     }

//     closeResponseModal() {
//         this.showResponseModal =
//             false;

//         this.responses =
//             [];

//         this.selectedActivity =
//             null;
//     }

//     getStatusClass(status) {
//         switch (status) {
//             case 'Live':
//                 return (
//                     'status-pill ' +
//                     'ready-status'
//                 );

//             case 'Completed':
//                 return (
//                     'status-pill ' +
//                     'completed-status'
//                 );

//             case 'In Progress':
//                 return (
//                     'status-pill ' +
//                     'progress-status'
//                 );

//             case 'Expired':
//                 return (
//                     'status-pill ' +
//                     'expired-status'
//                 );

//             case 'Pending Initiation':
//                 return (
//                     'status-pill ' +
//                     'pending-status'
//                 );

//             default:
//                 return (
//                     'status-pill ' +
//                     'pending-status'
//                 );
//         }
//     }

//     getInitials(memberName) {
//         if (!memberName) {
//             return 'NA';
//         }

//         return memberName
//             .trim()
//             .split(/\s+/)
//             .slice(0, 2)
//             .map(
//                 word =>
//                     word.charAt(0)
//                         .toUpperCase()
//             )
//             .join('');
//     }

//     formatDate(value) {
//         const dateValue =
//             this.toLocalDate(value);

//         if (!dateValue) {
//             return '-';
//         }

//         return new Intl.DateTimeFormat(
//             'en-IN',
//             {
//                 day: '2-digit',
//                 month: 'short',
//                 year: 'numeric'
//             }
//         ).format(dateValue);
//     }

//     formatTime(value) {
//         if (!value) {
//             return '-';
//         }

//         return new Intl.DateTimeFormat(
//             'en-IN',
//             {
//                 hour: '2-digit',
//                 minute: '2-digit',
//                 hour12: true
//             }
//         ).format(
//             new Date(value)
//         );
//     }

//     formatDateTime(value) {
//         if (!value) {
//             return '-';
//         }

//         return new Intl.DateTimeFormat(
//             'en-IN',
//             {
//                 day: '2-digit',
//                 month: 'short',
//                 year: 'numeric',
//                 hour: '2-digit',
//                 minute: '2-digit',
//                 hour12: true
//             }
//         ).format(
//             new Date(value)
//         );
//     }

//     toLocalDate(value) {
//         if (!value) {
//             return null;
//         }

//         if (value instanceof Date) {
//             return value;
//         }

//         const parts =
//             String(value).split('-');

//         if (parts.length !== 3) {
//             return new Date(value);
//         }

//         return new Date(
//             Number(parts[0]),
//             Number(parts[1]) - 1,
//             Number(parts[2])
//         );
//     }

//     scheduleMidnightRefresh() {
//         const now =
//             new Date();

//         const nextMidnight =
//             new Date(
//                 now.getFullYear(),
//                 now.getMonth(),
//                 now.getDate() + 1,
//                 0,
//                 0,
//                 2,
//                 0
//             );

//         const timeout =
//             nextMidnight.getTime() -
//             now.getTime();

//         this.midnightTimer =
//             window.setTimeout(
//                 async () => {
//                     await this
//                         .refreshDashboardData(
//                             false
//                         );

//                     this.scheduleMidnightRefresh();
//                 },
//                 timeout
//             );
//     }

//     showToast(
//         title,
//         message,
//         variant
//     ) {
//         this.dispatchEvent(
//             new ShowToastEvent({
//                 title,
//                 message,
//                 variant
//             })
//         );
//     }

//     getErrorMessage(error) {
//         if (
//             error &&
//             Array.isArray(error.body)
//         ) {
//             return error.body
//                 .map(
//                     item =>
//                         item.message
//                 )
//                 .join(', ');
//         }

//         if (
//             error &&
//             error.body &&
//             error.body.message
//         ) {
//             return error.body.message;
//         }

//         if (
//             error &&
//             error.message
//         ) {
//             return error.message;
//         }

//         return 'Something went wrong.';
//     }
// }