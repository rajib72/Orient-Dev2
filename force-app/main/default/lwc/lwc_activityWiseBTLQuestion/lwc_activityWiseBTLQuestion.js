import { LightningElement, api, track } from 'lwc';
import getQuestionsForActivity from '@salesforce/apex/ctrl_BTLActivityQuestionController.getQuestionsForActivity';
import saveActivityQuestions from '@salesforce/apex/ctrl_BTLActivityQuestionController.saveActivityQuestions';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';

export default class BtlActivityQuestionManager extends LightningElement {
    @api recordId;

    @track availableQuestions = [];
    @track selectedQuestions = [];

    availableSearchKey = '';
    selectedSearchKey = '';

    availablePage = 1;
    selectedPage = 1;
    pageSize = 8;

    isLoading = false;
    selectedAvailableIds = new Set();
    selectedSelectedIds = new Set();

    connectedCallback() {
        this.loadQuestions();
    }

    async loadQuestions() {
        this.isLoading = true;

        try {
            const result = await getQuestionsForActivity({
                activityId: this.recordId
            });

            let available = [];
            let selected = [];

            result.forEach(item => {
                let row = {
                    questionId: item.questionId,
                    questionText: item.questionText,
                    isChecked: false,
                    junctionId: item.junctionId
                };

                if (item.isSelected) {
                    selected.push(row);
                } else {
                    available.push(row);
                }
            });

            this.availableQuestions = available;
            this.selectedQuestions = selected;

            this.resetSelections();
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    resetSelections() {
        this.selectedAvailableIds = new Set();
        this.selectedSelectedIds = new Set();

        this.availableQuestions = this.availableQuestions.map(row => {
            return { ...row, isChecked: false };
        });

        this.selectedQuestions = this.selectedQuestions.map(row => {
            return { ...row, isChecked: false };
        });
    }

    handleRefresh() {
        this.loadQuestions();
    }

    handleAvailableSearch(event) {
        this.availableSearchKey = event.target.value;
        this.availablePage = 1;
    }

    handleSelectedSearch(event) {
        this.selectedSearchKey = event.target.value;
        this.selectedPage = 1;
    }

    get filteredAvailableQuestions() {
        const key = this.availableSearchKey ? this.availableSearchKey.toLowerCase() : '';

        if (!key) {
            return this.availableQuestions;
        }

        return this.availableQuestions.filter(row =>
            row.questionText &&
            row.questionText.toLowerCase().includes(key)
        );
    }

    get filteredSelectedQuestions() {
        const key = this.selectedSearchKey ? this.selectedSearchKey.toLowerCase() : '';

        let rows = !key
            ? this.selectedQuestions
            : this.selectedQuestions.filter(row =>
                row.questionText &&
                row.questionText.toLowerCase().includes(key)
            );

        return rows.map((row, index) => {
            return {
                ...row,
                rowNumber: index + 1
            };
        });
    }

    get pagedAvailableQuestions() {
        const start = (this.availablePage - 1) * this.pageSize;
        const end = start + this.pageSize;
        return this.filteredAvailableQuestions.slice(start, end);
    }

    get pagedSelectedQuestions() {
        const start = (this.selectedPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        return this.filteredSelectedQuestions.slice(start, end);
    }

    get totalAvailablePages() {
        return Math.ceil(this.filteredAvailableQuestions.length / this.pageSize) || 1;
    }

    get totalSelectedPages() {
        return Math.ceil(this.filteredSelectedQuestions.length / this.pageSize) || 1;
    }

    get disableAvailablePrevious() {
        return this.availablePage <= 1;
    }

    get disableAvailableNext() {
        return this.availablePage >= this.totalAvailablePages;
    }

    get disableSelectedPrevious() {
        return this.selectedPage <= 1;
    }

    get disableSelectedNext() {
        return this.selectedPage >= this.totalSelectedPages;
    }

    get availablePaginationLabel() {
        const total = this.filteredAvailableQuestions.length;

        if (total === 0) {
            return 'Showing 0 questions';
        }

        const start = (this.availablePage - 1) * this.pageSize + 1;
        const end = Math.min(this.availablePage * this.pageSize, total);

        return `Showing ${start} to ${end} of ${total} questions`;
    }

    get selectedPaginationLabel() {
        const total = this.filteredSelectedQuestions.length;

        if (total === 0) {
            return 'Showing 0 questions';
        }

        const start = (this.selectedPage - 1) * this.pageSize + 1;
        const end = Math.min(this.selectedPage * this.pageSize, total);

        return `Showing ${start} to ${end} of ${total} questions`;
    }

    previousAvailablePage() {
        if (this.availablePage > 1) {
            this.availablePage--;
        }
    }

    nextAvailablePage() {
        if (this.availablePage < this.totalAvailablePages) {
            this.availablePage++;
        }
    }

    previousSelectedPage() {
        if (this.selectedPage > 1) {
            this.selectedPage--;
        }
    }

    nextSelectedPage() {
        if (this.selectedPage < this.totalSelectedPages) {
            this.selectedPage++;
        }
    }

    handleAvailableCheck(event) {
        const questionId = event.target.dataset.id;
        const isChecked = event.target.checked;

        if (isChecked) {
            this.selectedAvailableIds.add(questionId);
        } else {
            this.selectedAvailableIds.delete(questionId);
        }

        this.availableQuestions = this.availableQuestions.map(row => {
            if (row.questionId === questionId) {
                return { ...row, isChecked: isChecked };
            }
            return row;
        });
    }

    handleSelectedCheck(event) {
        const questionId = event.target.dataset.id;
        const isChecked = event.target.checked;

        if (isChecked) {
            this.selectedSelectedIds.add(questionId);
        } else {
            this.selectedSelectedIds.delete(questionId);
        }

        this.selectedQuestions = this.selectedQuestions.map(row => {
            if (row.questionId === questionId) {
                return { ...row, isChecked: isChecked };
            }
            return row;
        });
    }

    handleSelectAllAvailable(event) {
        const checked = event.target.checked;
        const visibleIds = this.pagedAvailableQuestions.map(row => row.questionId);

        visibleIds.forEach(id => {
            if (checked) {
                this.selectedAvailableIds.add(id);
            } else {
                this.selectedAvailableIds.delete(id);
            }
        });

        this.availableQuestions = this.availableQuestions.map(row => {
            if (visibleIds.includes(row.questionId)) {
                return { ...row, isChecked: checked };
            }
            return row;
        });
    }

    handleSelectAllSelected(event) {
        const checked = event.target.checked;
        const visibleIds = this.pagedSelectedQuestions.map(row => row.questionId);

        visibleIds.forEach(id => {
            if (checked) {
                this.selectedSelectedIds.add(id);
            } else {
                this.selectedSelectedIds.delete(id);
            }
        });

        this.selectedQuestions = this.selectedQuestions.map(row => {
            if (visibleIds.includes(row.questionId)) {
                return { ...row, isChecked: checked };
            }
            return row;
        });
    }

    get isAllAvailableChecked() {
        const visibleRows = this.pagedAvailableQuestions;

        if (!visibleRows.length) {
            return false;
        }

        return visibleRows.every(row => this.selectedAvailableIds.has(row.questionId));
    }

    get isAllSelectedChecked() {
        const visibleRows = this.pagedSelectedQuestions;

        if (!visibleRows.length) {
            return false;
        }

        return visibleRows.every(row => this.selectedSelectedIds.has(row.questionId));
    }

    handleAddSelected() {
        if (this.selectedAvailableIds.size === 0) {
            this.showToast('Warning', 'Please select at least one question to add.', 'warning');
            return;
        }

        const idsToMove = Array.from(this.selectedAvailableIds);

        const rowsToMove = this.availableQuestions
            .filter(row => idsToMove.includes(row.questionId))
            .map(row => {
                return { ...row, isChecked: false };
            });

        this.selectedQuestions = [...this.selectedQuestions, ...rowsToMove];

        this.availableQuestions = this.availableQuestions.filter(
            row => !idsToMove.includes(row.questionId)
        );

        this.selectedAvailableIds = new Set();
        this.adjustPages();
    }

    handleAddAll() {
        const rowsToMove = this.filteredAvailableQuestions.map(row => {
            return { ...row, isChecked: false };
        });

        if (rowsToMove.length === 0) {
            this.showToast('Info', 'No available questions to add.', 'info');
            return;
        }

        const idsToMove = rowsToMove.map(row => row.questionId);

        this.selectedQuestions = [...this.selectedQuestions, ...rowsToMove];

        this.availableQuestions = this.availableQuestions.filter(
            row => !idsToMove.includes(row.questionId)
        );

        this.selectedAvailableIds = new Set();
        this.adjustPages();
    }

    handleRemoveSelected() {
        if (this.selectedSelectedIds.size === 0) {
            this.showToast('Warning', 'Please select at least one question to remove.', 'warning');
            return;
        }

        const idsToMove = Array.from(this.selectedSelectedIds);

        const rowsToMove = this.selectedQuestions
            .filter(row => idsToMove.includes(row.questionId))
            .map(row => {
                return { ...row, isChecked: false };
            });

        this.availableQuestions = [...this.availableQuestions, ...rowsToMove];

        this.selectedQuestions = this.selectedQuestions.filter(
            row => !idsToMove.includes(row.questionId)
        );

        this.selectedSelectedIds = new Set();
        this.adjustPages();
    }

    handleRemoveAll() {
        const rowsToMove = this.filteredSelectedQuestions.map(row => {
            return { ...row, isChecked: false };
        });

        if (rowsToMove.length === 0) {
            this.showToast('Info', 'No selected questions to remove.', 'info');
            return;
        }

        const idsToMove = rowsToMove.map(row => row.questionId);

        this.availableQuestions = [...this.availableQuestions, ...rowsToMove];

        this.selectedQuestions = this.selectedQuestions.filter(
            row => !idsToMove.includes(row.questionId)
        );

        this.selectedSelectedIds = new Set();
        this.adjustPages();
    }

    handleSingleRemove(event) {
        const questionId = event.currentTarget.dataset.id;

        const rowToMove = this.selectedQuestions.find(row => row.questionId === questionId);

        if (!rowToMove) {
            return;
        }

        this.availableQuestions = [
            ...this.availableQuestions,
            { ...rowToMove, isChecked: false }
        ];

        this.selectedQuestions = this.selectedQuestions.filter(
            row => row.questionId !== questionId
        );

        this.selectedSelectedIds.delete(questionId);
        this.adjustPages();
    }

    adjustPages() {
        if (this.availablePage > this.totalAvailablePages) {
            this.availablePage = this.totalAvailablePages;
        }

        if (this.selectedPage > this.totalSelectedPages) {
            this.selectedPage = this.totalSelectedPages;
        }
    }

    get isSaveDisabled() {
        return this.isLoading;
    }

    async handleSave() {
        this.isLoading = true;

        try {
            const selectedIds = this.selectedQuestions.map(row => row.questionId);

            const result = await saveActivityQuestions({
                activityId: this.recordId,
                selectedQuestionIds: selectedIds
            });

            this.showToast('Success', result, 'success');

            this.dispatchEvent(new RefreshEvent());

            // Close if used as Quick Action
            this.dispatchEvent(new CloseActionScreenEvent());

        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    getErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Something went wrong.';
    }
}