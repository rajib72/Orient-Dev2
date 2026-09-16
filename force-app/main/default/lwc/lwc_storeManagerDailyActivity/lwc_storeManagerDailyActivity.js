import { LightningElement } from 'lwc';
import LightningConfirm from 'lightning/confirm';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getDashboard from
    '@salesforce/apex/ctrl_StoreManagerDailyActivityCnt_v2.getDashboard';

import getSalesExecutives from
    '@salesforce/apex/ctrl_StoreManagerDailyActivityCnt_v2.getSalesExecutives';

import initiateWithoutChanges from
    '@salesforce/apex/ctrl_StoreManagerDailyActivityCnt_v2.initiateWithoutChangesByLocation';

import saveAndSendForApproval from
    '@salesforce/apex/ctrl_StoreManagerDailyActivityCnt_v2.saveAndSendForApprovalByLocation';

import rescheduleActivity from
    '@salesforce/apex/ctrl_StoreManagerDailyActivityCnt_v2.rescheduleActivityByLocation';

import dropActivity from
    '@salesforce/apex/ctrl_StoreManagerDailyActivityCnt_v2.dropActivityByLocation';


export default class LwcStoreManagerDailyActivity
    extends LightningElement {

    isLoading = false;

    todayValue = this.getTodayValue();
    selectedDate = this.todayValue;
    selectedStoreId = '';

    isSystemAdministrator = false;
    storeOptions = [];
    activities = [];

    totalActivities = 0;
    pendingInitiation = 0;
    liveActivities = 0;
    inProgressActivities = 0;
    completedActivities = 0;

    refreshedAt;

    showChangeModal = false;
    showRescheduleModal = false;
    showDropModal = false;

    selectedActivity;
    executiveOptions = [];
    locationOptions = [];
    changeMembers = [];
    newMemberSequence = 0;

    newActivityDate = '';
    rescheduleReason = '';
    dropReason = '';

    connectedCallback() {
        this.loadDashboard();
    }

    get hasActivities() {
        return this.activities.length > 0;
    }

    get disableStoreSelection() {
        return !this.isSystemAdministrator;
    }

    get selectedDateLabel() {
        return this.formatDate(this.selectedDate);
    }

    get rescheduleMinDate() {
        const activityStart =
            this.selectedActivity?.startDate;

        if (!activityStart) {
            return this.todayValue;
        }

        return activityStart > this.todayValue
            ? activityStart
            : this.todayValue;
    }

    get rescheduleMaxDate() {
        return this.selectedActivity?.endDate || '';
    }

    get rescheduleTypeLabel() {
        if (
            !this.newActivityDate ||
            !this.selectedDate
        ) {
            return 'Select a new date';
        }

        if (this.newActivityDate > this.selectedDate) {
            return 'Postponed';
        }

        if (this.newActivityDate < this.selectedDate) {
            return 'Preponed';
        }

        return 'No Date Change';
    }

    get disableRescheduleSave() {
        return (
            !this.selectedActivity ||
            !this.newActivityDate ||
            this.newActivityDate === this.selectedDate ||
            !this.rescheduleReason?.trim() ||
            this.isLoading
        );
    }

    get disableDropSave() {
        return (
            !this.selectedActivity ||
            !this.dropReason?.trim() ||
            this.isLoading
        );
    }

    get activeChangeCount() {
        return this.changeMembers.filter(
            member => member.activeForDate
        ).length;
    }

    get predefinedChangeMembers() {
        return this.changeMembers.filter(
            member => member.isNew !== true
        );
    }

    get addedChangeMembers() {
        let addedIndex = 0;

        return this.changeMembers
            .filter(member => member.isNew === true)
            .map(member => {
                addedIndex += 1;

                return {
                    ...member,
                    addedRowLabel:
                        `Additional Executive ${addedIndex}`
                };
            });
    }

    get hasAddedChangeMembers() {
        return this.addedExecutiveCount > 0;
    }

    get predefinedExecutiveCount() {
        return this.predefinedChangeMembers.length;
    }

    get predefinedActiveCount() {
        return this.predefinedChangeMembers.filter(
            member => member.activeForDate === true
        ).length;
    }

    get addedExecutiveCount() {
        return this.changeMembers.filter(
            member => member.isNew === true
        ).length;
    }

    get disableAddExecutive() {
        return this.locationOptions.length === 0;
    }

    get hasMissingLocationSelection() {
        return this.changeMembers.some(
            member =>
                member.activeForDate === true &&
                !member.activityLocation
        );
    }

    get hasDuplicateSelectedExecutives() {
        const executiveLocationKeys =
            this.changeMembers
                .filter(
                    member =>
                        member.activeForDate === true &&
                        member.actualExecutiveId &&
                        member.activityLocation
                )
                .map(
                    member =>
                        `${member.actualExecutiveId}||` +
                        `${this.normalizeActivityLocationKey(
                            member.activityLocation
                        )}`
                );

        return (
            new Set(executiveLocationKeys).size !==
            executiveLocationKeys.length
        );
    }

    get hasMissingExecutiveSelection() {
        return this.changeMembers.some(
            member =>
                member.activeForDate &&
                !member.actualExecutiveId
        );
    }

    get disableInitiateWithChanges() {
        return (
            this.changeMembers.length === 0 ||
            this.activeChangeCount === 0 ||
            this.hasMissingExecutiveSelection ||
            this.hasMissingLocationSelection ||
            this.hasDuplicateSelectedExecutives
        );
    }

    get hasChangeValidationError() {
        return this.disableInitiateWithChanges;
    }

    get changeValidationMessage() {
        if (this.changeMembers.length === 0) {
            return 'No executive assignment rows were found.';
        }

        if (this.activeChangeCount === 0) {
            return 'Please keep at least one executive active for today.';
        }

        if (this.hasMissingExecutiveSelection) {
            return 'Please select an executive for every active row.';
        }

        if (this.hasMissingLocationSelection) {
            return 'Please select an Activity Location for every active executive.';
        }

        if (this.hasDuplicateSelectedExecutives) {
            return 'The same Sales Executive cannot be selected more than once for the same Activity Location within this Team.';
        }

        return '';
    }

    async loadDashboard() {
        this.isLoading = true;

        try {
            const result = await getDashboard({
                selectedDate: this.selectedDate,
                selectedStoreId:
                    this.selectedStoreId || null
            });

            this.isSystemAdministrator =
                result.isSystemAdministrator === true;

            this.storeOptions =
                result.storeOptions || [];

            this.selectedStoreId =
                result.selectedStoreId || '';

            this.totalActivities =
                result.totalActivities || 0;

            this.pendingInitiation =
                result.pendingInitiation || 0;

            this.liveActivities =
                result.liveActivities || 0;

            this.inProgressActivities =
                result.inProgressActivities || 0;

            this.completedActivities =
                result.completedActivities || 0;

            this.refreshedAt = result.refreshedAt;

            this.activities =
                (result.activities || []).map(
                    (activity, index) =>
                        this.prepareActivity(
                            activity,
                            index
                        )
                );
        } catch (error) {
            this.activities = [];
            this.resetSummary();

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    prepareActivity(activity, index) {
        const members =
            (activity.members || []).map(member => {
                const displayName =
                    member.displayExecutiveName ||
                    member.actualExecutiveName ||
                    member.assignedExecutiveName ||
                    'Executive Not Assigned';

                return {
                    ...member,
                    displayName,
                    initials:
                        this.getInitials(displayName),
                    memberClass:
                        member.isReplacement === true
                        ? 'member-item replacement-member'
                        : member.activeForDate === false
                        ? 'member-item inactive-member'
                        : 'member-item'
                };
            });

        const duration =
            this.calculateDuration(
                activity.startDate,
                activity.endDate
            );

        const hasInitiationDetails =
            Boolean(activity.initiatedDateTime);

        const rowKey =
            activity.rowKey ||
            (
                `${activity.activityId}|` +
                `${activity.teamKey || 'NO_TEAM'}|` +
                `${activity.locationKey || 'NO_LOCATION'}`
            );

        const approvalLocked =
            activity.approvalLocked === true;

        const approvalApproved =
            activity.approvalApproved === true;

        const pendingForApproval =
            !approvalApproved &&
            activity.status === 'Pending For Approval';

        const canReschedule =
            activity.canReschedule === true;

        const canDrop =
            activity.canDrop === true;

        const showAnyActions =
            (
                activity.canInitiate === true &&
                approvalApproved
            ) ||
            canReschedule ||
            canDrop;

        return {
            ...activity,
            rowKey,
            serialNo: index + 1,
            members,
            hasMembers: members.length > 0,
            teamDisplayLabel:
                (
                    activity.teamName ||
                    'No Team'
                ) +
                (
                    activity.activityLocation
                    ? ` / ${activity.activityLocation}`
                    : ''
                ),
            recordUrl:
                `/lightning/r/Form_Activity__c/${activity.activityId}/view`,
            periodLabel:
                `${this.formatDate(activity.startDate)} - ` +
                `${this.formatDate(activity.endDate)}`,
            endDateLabel:
                this.formatDate(activity.endDate),
            durationLabel:
                duration === 1
                ? '1 Day'
                : `${duration} Days`,
            statusClass:
                this.getStatusClass(activity.status),
            initiatedLabel:
                this.formatDateTime(
                    activity.initiatedDateTime
                ),
            hasInitiationDetails,
            approvalLocked,
            approvalApproved,
            pendingForApproval,
            rowClass:
                pendingForApproval
                ? 'approval-pending-row'
                : '',
            showInitiateActions:
                activity.canInitiate === true &&
                approvalApproved,
            canReschedule,
            canDrop,
            showAnyActions,
            disableInitiate:
                activity.canInitiate !== true ||
                !approvalApproved ||
                members.length === 0,
            actionIcon:
                pendingForApproval
                ? 'utility:lock'
                : this.getActionIcon(
                    activity.status
                ),
            actionMessage:
                pendingForApproval
                ? 'Pending For Approval'
                : this.getActionMessage(
                    activity.status
                )
        };
    }

    async handleDateChange(event) {
        this.selectedDate = event.target.value;
        await this.loadDashboard();
    }

    async handleStoreChange(event) {
        this.selectedStoreId =
            event.detail.value;

        await this.loadDashboard();
    }

    async handleRefresh() {
        await this.loadDashboard();
    }

    async handleInitiateWithoutChanges(event) {
        const rowKey =
            event.currentTarget.dataset.key;

        const activity =
            this.activities.find(
                row => row.rowKey === rowKey
            );

        if (!activity) {
            return;
        }

        if (!activity.approvalApproved) {
            this.showToast(
                'Pending For Approval',
                'Store Manager actions are available only after the Team / Activity Location group receives final approval.',
                'warning'
            );

            return;
        }

        if (!activity.hasMembers) {
            this.showToast(
                'Executive Required',
                'No Sales Executives are assigned for this Team, Activity Location, and date.',
                'error'
            );

            return;
        }

        const groupMessage =
            activity.teamDisplayLabel
            ? ` for ${activity.teamDisplayLabel}`
            : '';

        const confirmed =
            await LightningConfirm.open({
                label: 'Initiate Without Changes',
                theme: 'warning',
                message:
                    `Do you want to initiate "${activity.activityName}"` +
                    `${groupMessage} for ${this.selectedDateLabel} ` +
                    `using the predefined executives?`
            });

        if (!confirmed) {
            return;
        }

        this.isLoading = true;

        try {
            await initiateWithoutChanges({
                activityId:
                    activity.activityId,
                selectedDate:
                    this.selectedDate,
                teamKey:
                    activity.teamKey,
                locationKey:
                    activity.locationKey
            });

            this.showToast(
                'Team Activity Is Live',
                activity.hasTeam
                    ? `${activity.teamName} is now live for the assigned BTL Sales Executives.`
                    : 'The activity is now live for the assigned BTL Sales Executives.',
                'success'
            );

            await this.loadDashboard();
        } catch (error) {
            this.showToast(
                'Unable to Initiate',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async handleOpenWithChanges(event) {
        const rowKey =
            event.currentTarget.dataset.key;

        const activity =
            this.activities.find(
                row => row.rowKey === rowKey
            );

        if (!activity) {
            return;
        }

        if (!activity.approvalApproved) {
            this.showToast(
                'Pending For Approval',
                'Store Manager actions are available only after the Team / Activity Location group receives final approval.',
                'warning'
            );

            return;
        }

        if (!activity.hasMembers) {
            this.showToast(
                'Executive Required',
                'No Sales Executives are assigned for this Team, Activity Location, and date.',
                'error'
            );

            return;
        }

        this.selectedActivity = activity;
        this.isLoading = true;

        try {
            const result =
                await getSalesExecutives({
                    storeId: activity.storeId,
                    activityId: activity.activityId,
                    selectedDate: this.selectedDate,
                    teamKey: activity.teamKey
                });

            this.executiveOptions =
                result || [];

            this.locationOptions =
                this.buildLocationOptions(
                    activity.members
                );

            this.changeMembers =
                this.decorateChangeMembers(
                    activity.members.map(member => ({
                        ...member,
                        clientRowKey:
                            member.dateAssignmentId,
                        activeForDate:
                            member.activeForDate !== false,
                        actualExecutiveId:
                            member.actualExecutiveId ||
                            member.assignedExecutiveId ||
                            '',
                        activityLocation:
                            member.activityLocation || '',
                        isNew: false
                    }))
                );

            this.showChangeModal = true;
        } catch (error) {
            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );

            this.selectedActivity = null;
        } finally {
            this.isLoading = false;
        }
    }


    handleOpenReschedule(event) {
        const activity =
            this.getActivityFromEvent(event);

        if (!activity) {
            return;
        }

        if (!activity.canReschedule) {
            this.showToast(
                'Action Not Available',
                'Only a fully approved current or future Team activity that has not been initiated can be rescheduled.',
                'warning'
            );

            return;
        }

        this.selectedActivity = activity;
        this.newActivityDate = '';
        this.rescheduleReason = '';
        this.showRescheduleModal = true;
    }

    handleNewActivityDateChange(event) {
        this.newActivityDate =
            event.target.value;
    }

    handleRescheduleReasonChange(event) {
        this.rescheduleReason =
            event.target.value;
    }

    async handleConfirmReschedule() {
        const inputs =
            this.template.querySelectorAll(
                '.reschedule-action-input'
            );

        let isValid = true;

        inputs.forEach(input => {
            if (!input.reportValidity()) {
                isValid = false;
            }
        });

        if (
            !isValid ||
            this.disableRescheduleSave
        ) {
            return;
        }

        this.isLoading = true;

        try {
            const preview =
                await rescheduleActivity({
                    activityId:
                        this.selectedActivity.activityId,
                    currentDate:
                        this.selectedDate,
                    newDate:
                        this.newActivityDate,
                    teamKey:
                        this.selectedActivity.teamKey,
                    locationKey:
                        this.selectedActivity.locationKey,
                    reason:
                        this.rescheduleReason.trim(),
                    executeAction:
                        false
                });

            this.isLoading = false;

            const conflicts =
                preview?.conflicts || [];

            const locationWarning =
                preview?.locationWarning || '';

            let confirmationMessage;
            let confirmationLabel;

            if (conflicts.length > 0) {
                const conflictDetails =
                    conflicts
                        .slice(0, 5)
                        .map(conflict => {
                            const teamLabel =
                                conflict.teamName
                                ? ` / ${conflict.teamName}`
                                : '';

                            return (
                                `${conflict.executiveName} - ` +
                                `${conflict.activityName}${teamLabel}`
                            );
                        })
                        .join('; ');

                const additionalCount =
                    conflicts.length > 5
                    ? `; and ${conflicts.length - 5} more conflict(s)`
                    : '';

                confirmationLabel =
                    locationWarning
                        ? 'Reschedule Warning'
                        : 'Executive Already Assigned';

                confirmationMessage =
                    `${locationWarning ? locationWarning + ' ' : ''}` +
                    `${conflictDetails}${additionalCount}. ` +
                    `One or more executives are already involved in an ` +
                    `activity on ${this.formatDate(this.newActivityDate)}. ` +
                    `Do you still want to move ` +
                    `${this.selectedActivity.teamDisplayLabel} to this date?`;
            } else if (locationWarning) {
                confirmationLabel =
                    'Activity Location Warning';

                confirmationMessage =
                    `${locationWarning} ` +
                    `Do you still want to move ` +
                    `${this.selectedActivity.teamDisplayLabel} to this date?`;
            } else {
                confirmationLabel =
                    'Reschedule Team Activity';

                confirmationMessage =
                    `This will move ${this.selectedActivity.teamDisplayLabel} ` +
                    `from ${this.selectedDateLabel} to ` +
                    `${this.formatDate(this.newActivityDate)}. ` +
                    `The previous date records will remain as Rescheduled history ` +
                    `and the new date records will be sent for fresh approval. ` +
                    `Do you want to continue?`;
            }

            const confirmed =
                await LightningConfirm.open({
                    label: confirmationLabel,
                    theme: 'warning',
                    message: confirmationMessage
                });

            if (!confirmed) {
                return;
            }

            this.isLoading = true;

            const result =
                await rescheduleActivity({
                    activityId:
                        this.selectedActivity.activityId,
                    currentDate:
                        this.selectedDate,
                    newDate:
                        this.newActivityDate,
                    teamKey:
                        this.selectedActivity.teamKey,
                    locationKey:
                        this.selectedActivity.locationKey,
                    reason:
                        this.rescheduleReason.trim(),
                    executeAction:
                        true
                });

            const movedDate =
                this.newActivityDate;

            this.showToast(
                result?.actionType || 'Activity Rescheduled',
                result?.message ||
                    'The selected Team was rescheduled and sent for approval.',
                'success'
            );

            this.closeRescheduleModal();
            this.selectedDate = movedDate;
            await this.loadDashboard();
        } catch (error) {
            this.showToast(
                'Unable to Reschedule',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    closeRescheduleModal() {
        this.showRescheduleModal = false;
        this.selectedActivity = null;
        this.newActivityDate = '';
        this.rescheduleReason = '';
    }

    handleOpenDrop(event) {
        const activity =
            this.getActivityFromEvent(event);

        if (!activity) {
            return;
        }

        if (!activity.canDrop) {
            this.showToast(
                'Action Not Available',
                'Only a fully approved current or future Team activity that has not been initiated can be dropped.',
                'warning'
            );

            return;
        }

        this.selectedActivity = activity;
        this.dropReason = '';
        this.showDropModal = true;
    }

    handleDropReasonChange(event) {
        this.dropReason =
            event.target.value;
    }

    async handleConfirmDrop() {
        const reasonInput =
            this.template.querySelector(
                '.drop-action-input'
            );

        if (
            !reasonInput?.reportValidity() ||
            this.disableDropSave
        ) {
            return;
        }

        const confirmed =
            await LightningConfirm.open({
                label: 'Drop Team Activity',
                theme: 'error',
                message:
                    `This will drop ${this.selectedActivity.teamDisplayLabel} ` +
                    `and its active manpower assignments for ` +
                    `${this.selectedDateLabel}. Other Teams will remain unchanged. ` +
                    `This action cannot be undone.`
            });

        if (!confirmed) {
            return;
        }

        this.isLoading = true;

        try {
            const result =
                await dropActivity({
                    activityId:
                        this.selectedActivity.activityId,
                    selectedDate:
                        this.selectedDate,
                    teamKey:
                        this.selectedActivity.teamKey,
                    locationKey:
                        this.selectedActivity.locationKey,
                    reason:
                        this.dropReason.trim()
                });

            this.showToast(
                'Team Activity Dropped',
                result?.message ||
                    'The selected Team activity was dropped successfully.',
                'success'
            );

            this.closeDropModal();
            await this.loadDashboard();
        } catch (error) {
            this.showToast(
                'Unable to Drop Activity',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    closeDropModal() {
        this.showDropModal = false;
        this.selectedActivity = null;
        this.dropReason = '';
    }

    getActivityFromEvent(event) {
        const rowKey =
            event.currentTarget.dataset.key;

        return this.activities.find(
            row => row.rowKey === rowKey
        );
    }

    handleAddExecutive() {
        if (!this.selectedActivity) {
            return;
        }

        if (this.disableAddExecutive) {
            this.showToast(
                'Location Required',
                'No Activity Location is available for this Team, Form Activity, and Date.',
                'error'
            );

            return;
        }

        this.newMemberSequence += 1;

        const newMember = {
            clientRowKey:
                `NEW-${Date.now()}-${this.newMemberSequence}`,
            dateAssignmentId: null,
            assignedExecutiveId: null,
            assignedExecutiveName: 'New Executive',
            actualExecutiveId: '',
            activityLocation:
                this.locationOptions.length === 1
                ? this.locationOptions[0].value
                : '',
            activeForDate: true,
            teamName:
                this.selectedActivity.teamName || '',
            isNew: true
        };

        this.changeMembers =
            this.decorateChangeMembers([
                ...this.changeMembers,
                newMember
            ]);
    }

    handleRemoveExecutive(event) {
        const clientRowKey =
            event.currentTarget.dataset.key;

        const selectedMember =
            this.changeMembers.find(
                member =>
                    member.clientRowKey ===
                    clientRowKey
            );

        if (
            !selectedMember ||
            selectedMember.isNew !== true
        ) {
            return;
        }

        this.changeMembers =
            this.decorateChangeMembers(
                this.changeMembers.filter(
                    member =>
                        member.clientRowKey !==
                        clientRowKey
                )
            );
    }

    handleActiveMemberChange(event) {
        const clientRowKey =
            event.currentTarget.dataset.key;

        const checked =
            event.target.checked;

        const updatedMembers =
            this.changeMembers.map(member => {
                if (
                    member.clientRowKey !==
                    clientRowKey ||
                    member.isNew === true
                ) {
                    return member;
                }

                return {
                    ...member,
                    activeForDate: checked
                };
            });

        this.changeMembers =
            this.decorateChangeMembers(
                updatedMembers
            );
    }

    handleExecutiveChange(event) {
        const clientRowKey =
            event.currentTarget.dataset.key;

        const actualExecutiveId =
            event.detail.value;

        const updatedMembers =
            this.changeMembers.map(member => {
                if (
                    member.clientRowKey !==
                    clientRowKey
                ) {
                    return member;
                }

                return {
                    ...member,
                    actualExecutiveId
                };
            });

        this.changeMembers =
            this.decorateChangeMembers(
                updatedMembers
            );
    }

    handleLocationChange(event) {
        const clientRowKey =
            event.currentTarget.dataset.key;

        const activityLocation =
            event.detail.value;

        const updatedMembers =
            this.changeMembers.map(member => {
                if (
                    member.clientRowKey !==
                        clientRowKey ||
                    member.isNew !== true
                ) {
                    return member;
                }

                return {
                    ...member,
                    activityLocation
                };
            });

        this.changeMembers =
            this.decorateChangeMembers(
                updatedMembers
            );
    }

    normalizeActivityLocationKey(activityLocation) {
        return (
            activityLocation || ''
        )
            .trim()
            .toUpperCase();
    }

    buildLocationOptions(members) {
        const locationMap = new Map();

        (members || []).forEach(member => {
            const location =
                (member.activityLocation || '').trim();

            if (!location) {
                return;
            }

            const locationKey =
                location.toLowerCase();

            if (!locationMap.has(locationKey)) {
                locationMap.set(
                    locationKey,
                    location
                );
            }
        });

        return Array.from(
            locationMap.values()
        )
            .sort((first, second) =>
                first.localeCompare(second)
            )
            .map(location => ({
                label: location,
                value: location
            }));
    }

    decorateChangeMembers(members) {
        return members.map(member => {
            const isNew =
                member.isNew === true;

            const activeForDate =
                isNew
                ? true
                : member.activeForDate === true;

            const blockedExecutiveIds =
                new Set();

            const memberLocationKey =
                this.normalizeActivityLocationKey(
                    member.activityLocation
                );

            members
                .filter(
                    otherMember =>
                        otherMember.clientRowKey !==
                            member.clientRowKey &&
                        otherMember.activeForDate === true &&
                        this.normalizeActivityLocationKey(
                            otherMember.activityLocation
                        ) === memberLocationKey
                )
                .forEach(otherMember => {
                    const otherExecutiveId =
                        otherMember.actualExecutiveId ||
                        otherMember.assignedExecutiveId;

                    if (otherExecutiveId) {
                        blockedExecutiveIds.add(
                            otherExecutiveId
                        );
                    }
                });

            const rowExecutiveOptions =
                this.executiveOptions.filter(
                    option =>
                        !blockedExecutiveIds.has(
                            option.value
                        ) ||
                        option.value ===
                            member.actualExecutiveId ||
                        (
                            !isNew &&
                            option.value ===
                                member.assignedExecutiveId
                        )
                );

            return {
                ...member,
                isNew,
                activeForDate,
                activityLocation:
                    member.activityLocation || '',
                executiveOptions:
                    rowExecutiveOptions,
                locationOptions:
                    this.locationOptions,
                showActiveCheckbox:
                    !isNew,
                showRemoveButton:
                    isNew,
                selectionRequired:
                    isNew || activeForDate,
                locationRequired:
                    isNew || activeForDate,
                executiveDisabled:
                    !isNew && !activeForDate,
                locationDisabled:
                    !isNew,
                modalRowClass:
                    isNew
                    ? 'executive-assignment-row new-executive-row'
                    : activeForDate
                    ? 'executive-assignment-row existing-executive-row'
                    : 'executive-assignment-row existing-executive-row inactive-row'
            };
        });
    }

    async handleSaveAndSendForApproval() {
        if (this.disableInitiateWithChanges) {
            this.showToast(
                'Validation Error',
                this.changeValidationMessage,
                'error'
            );

            return;
        }

        const confirmed =
            await LightningConfirm.open({
                label: 'Save & Send for Approval',
                theme: 'warning',
                message:
                    'Do you want to save these executive and location changes and send them for approval?'
            });

        if (!confirmed) {
            return;
        }

        const executiveChanges =
            this.changeMembers.map(member => ({
                dateAssignmentId:
                    member.dateAssignmentId,
                actualExecutiveId:
                    member.activeForDate
                    ? member.actualExecutiveId
                    : null,
                activeForDate:
                    member.activeForDate === true,
                activityLocation:
                    member.activityLocation || null,
                isNew:
                    member.isNew === true
            }));

        this.isLoading = true;

        try {
            const result =
                await saveAndSendForApproval({
                    activityId:
                        this.selectedActivity.activityId,
                    selectedDate:
                        this.selectedDate,
                    teamKey:
                        this.selectedActivity.teamKey,
                    locationKey:
                        this.selectedActivity.locationKey,
                    executiveChanges
                });

            const createdCount =
                result?.createdExecutiveRecords || 0;

            const updatedCount =
                result?.updatedExecutiveRecords || 0;

            this.showToast(
                'Sent for Approval',
                `${createdCount} executive record(s) created and ` +
                `${updatedCount} existing assignment(s) updated. ` +
                'Approval hierarchy tagging completed.',
                'success'
            );

            this.closeChangeModal();
            await this.loadDashboard();
        } catch (error) {
            this.showToast(
                'Unable to Send for Approval',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    closeChangeModal() {
        this.showChangeModal = false;
        this.selectedActivity = null;
        this.executiveOptions = [];
        this.locationOptions = [];
        this.changeMembers = [];
        this.newMemberSequence = 0;
    }

    resetSummary() {
        this.totalActivities = 0;
        this.pendingInitiation = 0;
        this.liveActivities = 0;
        this.inProgressActivities = 0;
        this.completedActivities = 0;
    }

    getStatusClass(status) {
        switch (status) {
            case 'Pending For Approval':
                return 'status-pill approval-pending-status';

            case 'Live':
                return 'status-pill live-status';

            case 'In Progress':
                return 'status-pill progress-status';

            case 'Completed':
                return 'status-pill completed-status';

            case 'Expired':
                return 'status-pill expired-status';

            default:
                return 'status-pill pending-status';
        }
    }

    getActionIcon(status) {
        switch (status) {
            case 'Pending For Approval':
                return 'utility:lock';

            case 'Live':
                return 'utility:broadcast';

            case 'In Progress':
                return 'utility:play';

            case 'Completed':
                return 'utility:success';

            case 'Expired':
                return 'utility:clock';

            default:
                return 'utility:info';
        }
    }

    getActionMessage(status) {
        switch (status) {
            case 'Pending For Approval':
                return 'Pending For Approval';

            case 'Live':
                return 'Live for BTL Executives';

            case 'In Progress':
                return 'Activity In Progress';

            case 'Completed':
                return 'Activity Completed';

            case 'Expired':
                return 'Initiation Closed';

            default:
                return 'No Action Available';
        }
    }

    getInitials(name) {
        if (!name) {
            return 'NA';
        }

        return name
            .trim()
            .split(/\s+/)
            .slice(0, 2)
            .map(word =>
                word.charAt(0).toUpperCase()
            )
            .join('');
    }

    calculateDuration(startDate, endDate) {
        const start =
            this.toLocalDate(startDate);

        const end =
            this.toLocalDate(endDate);

        if (!start || !end) {
            return 0;
        }

        const difference =
            end.getTime() - start.getTime();

        return (
            Math.floor(
                difference /
                (1000 * 60 * 60 * 24)
            ) + 1
        );
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
        ).format(new Date(value));
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

        if (parts.length === 3) {
            return new Date(
                Number(parts[0]),
                Number(parts[1]) - 1,
                Number(parts[2])
            );
        }

        return new Date(value);
    }

    getTodayValue() {
        const today = new Date();

        return [
            today.getFullYear(),
            String(
                today.getMonth() + 1
            ).padStart(2, '0'),
            String(
                today.getDate()
            ).padStart(2, '0')
        ].join('-');
    }

    showToast(title, message, variant) {
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
                .map(item => item.message)
                .join(', ');
        }

        if (
            error &&
            error.body &&
            error.body.message
        ) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Something went wrong.';
    }
}