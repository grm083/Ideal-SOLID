import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

// Import Apex methods
import fetchVendorOrClientWrapper from '@salesforce/apex/CaseController.fetchVendorOrClientWrapper';
import updateCaseOnVendorClientSelection from '@salesforce/apex/CaseController.updateCaseOnVendorClientSelection';

/**
 * ClientSearch - LWC component for client account search
 * Converted from Aura component: aura/ClientSearch
 *
 * @description Paginated client account search with filter options.
 * Allows searching and selecting client accounts to associate with a case.
 *
 * Features:
 * - Search input with "All Active and Inactive Accounts" filter checkbox
 * - Paginated results with configurable page size (10, 15, 20)
 * - Radio button selection for client accounts
 * - Save button to update case with selected client
 * - Enter key press support for search
 */
export default class ClientSearchLWC extends LightningElement {
    // Public properties
    @api recordId;

    // Search properties
    @track searchKeyword = '';
    @track previousSearchKeyword = '';
    @track selectedAccountFilter = false;

    // Pagination properties
    @track pageNumber = 1;
    @track totalPages = 0;
    @track totalRecords = 0;
    @track recordStart = 0;
    @track recordEnd = 0;
    @track pageSize = 10;

    // Results
    @track accountWrapperList = [];
    @track selectedClientAccountId = '';

    // UI state
    @track showMessage = false;
    @track showSaveButton = false;
    @track isLoading = false;

    // Computed properties
    get isPrevDisabled() {
        return this.pageNumber <= 1;
    }

    get isNextDisabled() {
        return this.pageNumber >= this.totalPages;
    }

    get isSaveDisabled() {
        return !this.selectedClientAccountId;
    }

    get pageSizeOptions() {
        return [
            { label: '10', value: '10' },
            { label: '15', value: '15' },
            { label: '20', value: '20' }
        ];
    }

    get paginationInfo() {
        return `${this.recordStart}-${this.recordEnd} of ${this.totalRecords} | Page ${this.pageNumber} of ${this.totalPages}`;
    }

    // Event Handlers
    handleSearchKeywordChange(event) {
        this.searchKeyword = event.target.value;
    }

    handleFilterChange(event) {
        this.selectedAccountFilter = event.target.checked;
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.detail.value, 10);
        this.pageNumber = 1; // Reset to first page
        this.performSearch();
    }

    handleSearchKeyPress(event) {
        if (event.keyCode === 13) {
            this.handleSearch();
        }
    }

    handleSearch() {
        // Validation
        if (!this.searchKeyword || this.searchKeyword.trim() === '') {
            this.showToast('Error', 'Please enter a search keyword', 'error');
            return;
        }

        // Reset to page 1 if new search
        if (this.searchKeyword !== this.previousSearchKeyword) {
            this.pageNumber = 1;
        }

        this.performSearch();
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.performSearch();
        }
    }

    handlePrev() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.performSearch();
        }
    }

    handleAccountSelection(event) {
        this.selectedClientAccountId = event.currentTarget.dataset.id;
        this.showSaveButton = true;
    }

    async handleSave() {
        if (!this.selectedClientAccountId) {
            this.showToast('Error', 'Please select a client account', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const result = await updateCaseOnVendorClientSelection({
                accountId: this.selectedClientAccountId,
                caseId: this.recordId,
                recordType: 'Client'
            });

            if (result === 'Success') {
                this.showToast('Success', 'Client updated successfully', 'success');
                this.dispatchEvent(new CustomEvent('refresh'));
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } else {
                this.showToast('Error', result, 'error');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error updating client', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Search Method
    async performSearch() {
        this.isLoading = true;
        this.showMessage = false;

        try {
            const result = await fetchVendorOrClientWrapper({
                searchKeyWord: this.searchKeyword,
                selectedFilter: this.selectedAccountFilter,
                pageNumber: this.pageNumber,
                pageSize: this.pageSize,
                CaseId: this.recordId,
                recordType: 'Client'
            });

            if (!result || !result.assetWrapperList || result.assetWrapperList.length === 0) {
                this.showMessage = true;
                this.accountWrapperList = [];
            } else {
                this.showMessage = false;
                this.accountWrapperList = result.assetWrapperList;
                this.pageNumber = result.pageNumber;
                this.totalRecords = result.totalRecords;
                this.recordStart = result.recordStart;
                this.recordEnd = result.recordEnd;
                this.totalPages = Math.ceil(result.totalRecords / this.pageSize);
                this.previousSearchKeyword = this.searchKeyword;
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error searching clients', 'error');
            this.showMessage = true;
            this.accountWrapperList = [];
        } finally {
            this.isLoading = false;
        }
    }

    // Helper Methods
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissible'
        });
        this.dispatchEvent(event);
    }
}
