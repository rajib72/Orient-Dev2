import { LightningElement, api, track } from 'lwc';
import getQuestionsForActivity from '@salesforce/apex/ctrl_BTLActivityQuestionController_V.getQuestionsForActivity';
import getQuestionCategories from '@salesforce/apex/ctrl_BTLActivityQuestionController_V.getQuestionCategories';
import saveActivityQuestions from '@salesforce/apex/ctrl_BTLActivityQuestionController_V.saveActivityQuestions';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';

export default class ActivityWiseBTLQuestion extends LightningElement {
    @api recordId;

    @track questions = [];
    @track categoryOptions = [
        { label: 'All Categories', value: 'All' }
    ];

    searchKey = '';
    selectedCategory = 'All';

    currentPage = 1;
    pageSize = 6;

    isLoading = false;
    isSaving = false;

    connectedCallback() {
        this.loadInitialData();
    }

    async loadInitialData() {
        this.isLoading = true;

        try {
            await Promise.all([
                this.loadCategories(),
                this.loadQuestions()
            ]);
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadCategories() {
        const result = await getQuestionCategories();

        let options = [
            { label: 'All Categories', value: 'All' }
        ];

        result.forEach(item => {
            options.push({
                label: item,
                value: item
            });
        });

        this.categoryOptions = options;
    }

    async loadQuestions() {
        const result = await getQuestionsForActivity({
            activityId: this.recordId
        });

        this.questions = result.map((item, index) => {
            return {
                questionId: item.questionId,
                questionText: item.questionText,
                category: item.category,
                isSelected: item.isSelected,
                junctionId: item.junctionId,
                originalIndex: index + 1
            };
        });

        if (this.currentPage > this.totalPages) {
            this.currentPage = this.totalPages;
        }

        if (!this.currentPage || this.currentPage < 1) {
            this.currentPage = 1;
        }
    }

    async handleRefresh() {
    this.isLoading = true;

        try {
            await this.loadQuestions();

            this.showToast(
                'Refreshed',
                'Questions refreshed successfully.',
                'success'
            );

        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleSearch(event) {
        this.searchKey = event.target.value;
        this.currentPage = 1;
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.target.value;
        this.currentPage = 1;
    }

    handleToggleQuestion(event) {
        const questionId = event.currentTarget.dataset.id;

        this.questions = this.questions.map(row => {
            if (row.questionId === questionId) {
                return {
                    ...row,
                    isSelected: !row.isSelected
                };
            }

            return row;
        });
    }

    get filteredQuestions() {
        let rows = [...this.questions];

        const key = this.searchKey ? this.searchKey.toLowerCase().trim() : '';

        if (key) {
            rows = rows.filter(row =>
                row.questionText &&
                row.questionText.toLowerCase().includes(key)
            );
        }

        if (this.selectedCategory && this.selectedCategory !== 'All') {
            rows = rows.filter(row => row.category === this.selectedCategory);
        }

        return rows.map((row, index) => {
            return {
                ...row,
                displayNumber: index + 1,
                cardClass: row.isSelected ? 'question-card selected-card' : 'question-card'
            };
        });
    }

    get pagedQuestions() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;

        return this.filteredQuestions.slice(start, end);
    }

    get totalQuestionCount() {
        return this.questions.length;
    }

    get selectedQuestionCount() {
        return this.questions.filter(row => row.isSelected).length;
    }

    get totalPages() {
        return Math.ceil(this.filteredQuestions.length / this.pageSize) || 1;
    }

    get disablePrevious() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage >= this.totalPages;
    }

    get paginationLabel() {
        const total = this.filteredQuestions.length;

        if (total === 0) {
            return 'Showing 0 questions';
        }

        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, total);

        return `Showing ${start} to ${end} of ${total} questions`;
    }

    get isSaveDisabled() {
        return this.isSaving || this.isLoading;
    }

    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
        }
    }

    async handleSave() {
    this.isSaving = true;

        try {
            const selectedQuestionIds = this.questions
                .filter(row => row.isSelected)
                .map(row => row.questionId);

            const result = await saveActivityQuestions({
                activityId: this.recordId,
                selectedQuestionIds: selectedQuestionIds
            });

            this.showToast('Success', result, 'success');

            await this.loadQuestions();

            this.dispatchEvent(new RefreshEvent());

        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isSaving = false;
        }
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