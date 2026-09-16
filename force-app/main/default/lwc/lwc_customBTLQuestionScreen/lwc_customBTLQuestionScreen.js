import { LightningElement, track } from 'lwc';

import getActivities from '@salesforce/apex/ctrl_BTLQuestionScreenController.getActivities';
import getQuestionsByActivities from '@salesforce/apex/ctrl_BTLQuestionScreenController.getQuestionsByActivities';
import saveFinalCustomizeForm from '@salesforce/apex/ctrl_BTLQuestionScreenController.saveFinalCustomizeForm';

export default class BtlQuestionScreen extends LightningElement {

    @track searchKey = '';
    @track activityList = [];
    @track selectedActivities = [];
    @track questionList = [];
    @track selectedActivityFilter = '';
    @track requiredQuestionState = {};
    @track serialQuestionState = {};

    @track showDropdown = false;
    @track removedQuestionIds = [];

    @track isReviewScreen = false;
    @track formName = '';
    @track formNameError = '';

    searchTimeout;

    connectedCallback() {
        this.loadActivities();
    }

    get maxSerialNumber() {
        return this.questionList ? this.questionList.length : 0;
    }

    get dropdownIcon() {
        return this.showDropdown
            ? 'utility:chevronup'
            : 'utility:chevrondown';
    }

    get selectedActivityOptions() {
        let options = [
            {
                label: 'None',
                value: ''
            }
        ];


        if (this.selectedActivities && this.selectedActivities.length > 0) {
            this.selectedActivities.forEach(item => {
                options.push({
                    label: item.activityName,
                    value: item.activityId
                });
            });
        }

        return options;
    }

    get filteredQuestionList() {
        if (!this.selectedActivityFilter) {
            return this.questionList;
        }

        return this.questionList.filter(
            item => item.activityId === this.selectedActivityFilter
        );
    }

    get formNameSectionClass() {
        return this.formNameError
            ? 'btl-form-name-section btl-form-error-section'
            : 'btl-form-name-section';
    }

    handleSelectedActivityFilterChange(event) {
        this.selectedActivityFilter = event.detail.value;
    }

    handleSerialNumberChange(event) {
        const questionId = event.currentTarget.dataset.id;
        const requestedSerialNo = Number(event.target.value);
        const totalQuestions = this.questionList.length;

        const currentQuestion = this.questionList.find(
            item => item.questionId === questionId
        );

        if (
            !Number.isInteger(requestedSerialNo) ||
            requestedSerialNo < 1 ||
            requestedSerialNo > totalQuestions
        ) {
            event.target.setCustomValidity(
                `Enter a serial number between 1 and ${totalQuestions}.`
            );
            event.target.reportValidity();

            if (currentQuestion) {
                event.target.value = currentQuestion.serialNo;
            }

            return;
        }

        event.target.setCustomValidity('');
        event.target.reportValidity();

        const currentIndex = this.questionList.findIndex(
            item => item.questionId === questionId
        );

        if (currentIndex === -1) {
            return;
        }

        const targetIndex = requestedSerialNo - 1;
        const reorderedQuestions = [...this.questionList];

        const movedQuestion = reorderedQuestions.splice(currentIndex, 1)[0];

        reorderedQuestions.splice(targetIndex, 0, movedQuestion);

        this.questionList = this.resequenceQuestions(reorderedQuestions);
        this.syncSerialQuestionState();
    }

    resequenceQuestions(questionList) {
        return questionList.map((item, index) => {
            return {
                ...item,
                serialNo: index + 1
            };
        });
    }

    syncSerialQuestionState() {
        const updatedState = {};

        this.questionList.forEach(item => {
            updatedState[item.questionId] = item.serialNo;
        });

        this.serialQuestionState = updatedState;
    }

    openDropdown(event) {
        if (event) {
            event.stopPropagation();
        }

        this.showDropdown = true;
    }

    toggleDropdown(event) {
        if (event) {
            event.stopPropagation();
        }

        this.showDropdown = !this.showDropdown;
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
        this.showDropdown = true;

        clearTimeout(this.searchTimeout);

        this.searchTimeout = setTimeout(() => {
            this.loadActivities();
        }, 300);
    }

    removeSelectedActivity(event) {
        event.stopPropagation();

        const activityId = event.currentTarget.dataset.id;

        // Remove selected activity pill
        this.selectedActivities = this.selectedActivities.filter(
            item => item.activityId !== activityId
        );

        // If top-right filter dropdown selected this activity, reset it to None
        if (this.selectedActivityFilter === activityId) {
            this.selectedActivityFilter = '';
        }

        // Close activity dropdown
        this.showDropdown = false;

        // Refresh checkbox selected state
        this.loadActivities();

        // Refresh related questions
        this.loadQuestions();
    }

    loadActivities() {
        getActivities({ searchKey: this.searchKey })
            .then(result => {
                const selectedIds = this.selectedActivities.map(
                    item => item.activityId
                );

                this.activityList = result.map(item => {
                    return {
                        ...item,
                        isSelected: selectedIds.includes(item.activityId)
                    };
                });
            })
            .catch(error => {
                console.error('Error loading activities:', error);
            });
    }

    handleActivitySelect(event) {
        event.stopPropagation();

        const activityId = event.target.dataset.id;
        const activityName = event.target.dataset.name;
        const checked = event.target.checked;

        if (checked) {
            const alreadySelected = this.selectedActivities.some(
                item => item.activityId === activityId
            );

            if (!alreadySelected) {
                this.selectedActivities = [
                    ...this.selectedActivities,
                    {
                        activityId: activityId,
                        activityName: activityName
                    }
                ];
            }
        } else {
            this.selectedActivities = this.selectedActivities.filter(
                item => item.activityId !== activityId
            );
        }

        this.showDropdown = true;
        this.loadActivities();
        this.loadQuestions();
    }

    handleRequiredToggle(event) {
        const questionId = event.currentTarget.dataset.id;

        let updatedValue = false;

        this.questionList = this.questionList.map(item => {
            if (item.questionId === questionId) {
                updatedValue = !item.isRequired;

                return {
                    ...item,
                    isRequired: updatedValue
                };
            }

            return item;
        });

        this.requiredQuestionState = {
            ...this.requiredQuestionState,
            [questionId]: updatedValue
        };
    }

    removeQuestion(event) {
        const questionId = event.currentTarget.dataset.id;

        if (!this.removedQuestionIds.includes(questionId)) {
            this.removedQuestionIds = [
                ...this.removedQuestionIds,
                questionId
            ];
        }

        this.questionList = this.resequenceQuestions(
            this.questionList.filter(
                item => item.questionId !== questionId
            )
        );

        const updatedRequiredState = {
            ...this.requiredQuestionState
        };

        delete updatedRequiredState[questionId];

        this.requiredQuestionState = updatedRequiredState;

        this.syncSerialQuestionState();
    }

    loadQuestions() {
        const activityIds = this.selectedActivities.map(
            item => item.activityId
        );

        if (activityIds.length === 0) {
            this.questionList = [];
            this.selectedActivityFilter = '';
            this.serialQuestionState = {};
            return;
        }

        getQuestionsByActivities({ activityIds: activityIds })
            .then(result => {
                const filteredQuestions = result.filter(
                    item => !this.removedQuestionIds.includes(item.questionId)
                );

                const preparedQuestions = filteredQuestions.map((item, index) => {
                    const hasRequiredState =
                        Object.prototype.hasOwnProperty.call(
                            this.requiredQuestionState,
                            item.questionId
                        );

                    const hasSerialState =
                        Object.prototype.hasOwnProperty.call(
                            this.serialQuestionState,
                            item.questionId
                        );

                    return {
                        ...item,
                        isRequired: hasRequiredState
                            ? this.requiredQuestionState[item.questionId]
                            : false,
                        savedSerialNo: hasSerialState
                            ? this.serialQuestionState[item.questionId]
                            : null,
                        originalIndex: index
                    };
                });

                preparedQuestions.sort((firstItem, secondItem) => {
                    const firstHasSerial =
                        Number.isInteger(firstItem.savedSerialNo);

                    const secondHasSerial =
                        Number.isInteger(secondItem.savedSerialNo);

                    if (firstHasSerial && secondHasSerial) {
                        return firstItem.savedSerialNo -
                            secondItem.savedSerialNo;
                    }

                    if (firstHasSerial) {
                        return -1;
                    }

                    if (secondHasSerial) {
                        return 1;
                    }

                    return firstItem.originalIndex -
                        secondItem.originalIndex;
                });

                this.questionList = preparedQuestions.map((item, index) => {
                    return {
                        questionId: item.questionId,
                        btlQuestionId: item.btlQuestionId,
                        questionName: item.questionName,
                        activityId: item.activityId,
                        activityName: item.activityName,
                        answerType: item.answerType,
                        category: item.category,
                        isRequired: item.isRequired,
                        serialNo: index + 1
                    };
                });

                this.syncSerialQuestionState();
            })
            .catch(error => {
                console.error('Error loading questions:', error);
            });
    }

    get showEmptyState() {
        return !this.showDropdown && this.selectedActivities.length === 0;
    }

    get hasSelectedActivities() {
        return this.selectedActivities && this.selectedActivities.length > 0;
    }

    get reviewQuestionList() {
        return [...this.questionList]
            .sort((firstItem, secondItem) => {
                return firstItem.serialNo - secondItem.serialNo;
            })
            .map(item => {
                return {
                    ...item
                };
            });
    }

    get hasQuestionsForReview() {
        return this.questionList && this.questionList.length > 0;
    }

    handleFinalReview() {
        if (!this.questionList || this.questionList.length === 0) {
            return;
        }

        this.isReviewScreen = true;
        this.showDropdown = false;
    }

    handleBackToMain() {
        this.isReviewScreen = false;
    }

    handleFormNameChange(event) {
        this.formName = event.target.value;

        if (this.formName && this.formName.trim() !== '') {
            this.formNameError = '';
        }
    }

    handleSave() {
        if (!this.formName || this.formName.trim() === '') {
            this.formNameError = 'Form Name is required.';
            return;
        }

        if (!this.reviewQuestionList || this.reviewQuestionList.length === 0) {
            this.formNameError = '';
            alert('Minimum one question is required.');
            return;
        }

        this.formNameError = '';

        const questionPayload = this.reviewQuestionList.map(ques => {
            return {
                activityId: ques.activityId,
                btlQuestionId: ques.btlQuestionId,
                activityWiseQuestionId: ques.questionId,
                questionName: ques.questionName,
                answerType: ques.answerType,
                activityName: ques.activityName,
                isRequired: ques.isRequired === true,
                serialNo: ques.serialNo
            };
        });

        console.log('Final Save Payload:', JSON.stringify(questionPayload));

        saveFinalCustomizeForm({
            formName: this.formName,
            questionList: questionPayload
        })
            .then(result => {
                alert('Final Customize Form created successfully.');

                console.log('Created Final Customize Form Id:', result);

                this.resetForm();
            })
            .catch(error => {
                console.error('Save error:', error);

                let message = 'Something went wrong while saving.';

                if (error && error.body && error.body.message) {
                    message = error.body.message;
                }

                alert(message);
            });
    }

    resetForm() {
        this.searchKey = '';
        this.activityList = [];
        this.selectedActivities = [];
        this.questionList = [];
        this.selectedActivityFilter = '';
        this.showDropdown = false;
        this.removedQuestionIds = [];
        this.isReviewScreen = false;
        this.formName = '';
        this.formNameError = '';
        this.requiredQuestionState = {};
        this.serialQuestionState = {};

        this.loadActivities();
    }
}