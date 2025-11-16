import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

// Import Apex methods
import fetchVendorOrClientWrapper from '@salesforce/apex/CaseController.fetchVendorOrClientWrapper';
import updateCaseOnVendorClientSelection from '@salesforce/apex/CaseController.updateCaseOnVendorClientSelection';

export default class VendorSearchLWC extends LightningElement {
    @api recordId;

    // Search properties
    @track searchKeyword = '';
    @track selectedAccountFilter = false;
    @track previousSearchKeyword = '';

    // Pagination properties
    @track pageNumber = 1;
    @track totalPages = 0;
    @track pageSize = 10;
    @track totalRecords = 0;
    @track recordStart = 0;
    @track recordEnd = 0;

    // Results and selection
    @track accountWrapperList = [];
    @track selectedVendorAccountId = '';
    @track showSaveButton = false;
    @track saveEnabled = false;

    // UI state
    @track isLoading = false;
    @track showMessage = false;

    // Page size options
    pageSizeOptions = [
        { label: '10', value: '10' },
        { label: '15', value: '15' },
        { label: '20', value: '20' }
    ];

    // Computed properties
    get hasResults() {
        return this.accountWrapperList && this.accountWrapperList.length > 0;
    }

    get isPrevDisabled() {
        return this.pageNumber === 0 || this.pageNumber === 1;
    }

    get isNextDisabled() {
        return this.pageNumber === this.totalPages;
    }

    get paginationText() {
        return `${this.recordStart}-${this.recordEnd} of ${this.totalRecords} | Page ${this.pageNumber} of ${this.totalPages}`;
    }

    // Event handlers
    handleSearchKeywordChange(event) {
        this.searchKeyword = event.target.value;
    }

    handleFilterChange(event) {
        this.selectedAccountFilter = event.target.checked;
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.target.value, 10);
        this.performSearch(1);
    }

    handleSearchKeyPress(event) {
        if (event.keyCode === 13) {
            this.handleSearch();
        }
    }

    handleSearch() {
        // Validate required field
        const searchInput = this.template.querySelector('lightning-input[data-id="searchField"]');
        if (!searchInput.reportValidity()) {
            return;
        }

        // If search keyword changed, start from page 1
        const newPageNumber = this.searchKeyword !== this.previousSearchKeyword ? 1 : this.pageNumber;
        this.performSearch(newPageNumber);
    }

    handleNext() {
        this.performSearch(this.pageNumber + 1);
    }

    handlePrev() {
        this.performSearch(this.pageNumber - 1);
    }

    handleRadioClick(event) {
        this.selectedVendorAccountId = event.currentTarget.dataset.recordId;
        this.showSaveButton = true;
        this.saveEnabled = false;
    }

    async handleSave() {
        if (!this.selectedVendorAccountId) {
            this.showToast('Error', 'Please select a vendor', 'error');
            return;
        }

        this.isLoading = true;
        this.saveEnabled = true;

        try {
            const result = await updateCaseOnVendorClientSelection({
                accountId: this.selectedVendorAccountId,
                caseId: this.recordId,
                recordType: 'Vendor'
            });

            if (result === 'Success') {
                this.showToast('Success', 'Vendor updated successfully', 'success');

                // Refresh the record
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);

                // Dispatch refresh event
                this.dispatchEvent(new CustomEvent('refresh'));

            } else {
                this.showToast('Error', result, 'error');
                this.saveEnabled = false;
            }

        } catch (error) {
            console.error('Error saving vendor:', error);
            this.showToast('Error', error.body?.message || 'Error saving vendor', 'error');
            this.saveEnabled = false;
        } finally {
            this.isLoading = false;
        }
    }

    // Search helper
    async performSearch(pageNumber) {
        this.isLoading = true;
        this.showMessage = false;

        try {
            const result = await fetchVendorOrClientWrapper({
                searchKeyWord: this.searchKeyword,
                selectedFilter: this.selectedAccountFilter,
                pageNumber: pageNumber,
                pageSize: this.pageSize,
                CaseId: this.recordId,
                recordType: 'Vendor'
            });

            if (result && result.assetWrapperList) {
                this.accountWrapperList = result.assetWrapperList;
                this.pageNumber = result.pageNumber;
                this.totalRecords = result.totalRecords;
                this.recordStart = result.recordStart;
                this.recordEnd = result.recordEnd;
                this.totalPages = Math.ceil(result.totalRecords / this.pageSize);
                this.previousSearchKeyword = this.searchKeyword;

                this.showMessage = result.assetWrapperList.length === 0;
            } else {
                this.showMessage = true;
                this.accountWrapperList = [];
            }

        } catch (error) {
            console.error('Error searching vendors:', error);
            this.showToast('Error', error.body?.message || 'Error searching vendors', 'error');
            this.showMessage = true;
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}
