import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchAccountAssetWrapper from '@salesforce/apex/CaseController.fetchAccountAssetWrapper';
import updateCase from '@salesforce/apex/CaseController.updateCase';

export default class LocationAssetSearchLWC extends LightningElement {
    @api recordId;

    @track searchKeyword = '';
    @track previousSearchKeyword = '';
    @track selectedAccountFilter = false;
    @track inactiveAssets = false;
    @track accountAssetWrapperList = [];
    @track expandedRows = new Set();
    @track selectedAssetIds = [];
    @track selectedLocationAccountId = '';
    @track selectedClientAccountId = '';
    @track selectedLocationAccountName = '';
    @track selectedClientAccountName = '';
    @track selectedAssetName = '';

    @track pageNumber = 0;
    @track totalPages = 0;
    @track totalRecords = 0;
    @track recordStart = 0;
    @track recordEnd = 0;
    @track pageSize = 10;
    @track showMessage = false;
    @track showSpinner = false;
    @track showSaveButton = false;
    @track selectionDetails = false;

    pageSizeOptions = [
        { label: '10', value: '10' },
        { label: '15', value: '15' },
        { label: '20', value: '20' }
    ];

    handleSearchKeywordChange(event) {
        this.searchKeyword = event.target.value;
    }

    handleFilterChange(event) {
        this.selectedAccountFilter = event.target.checked;
    }

    handleInactiveAssetsChange(event) {
        this.inactiveAssets = event.target.checked;
    }

    handleSearchKeyPress(event) {
        if (event.keyCode === 13) {
            this.handleSearch();
        }
    }

    handleSearch() {
        const searchField = this.template.querySelector('[data-id="searchField"]');
        const isValid = searchField.reportValidity();

        if (!isValid) {
            searchField.focus();
            return;
        }

        let pageNum;
        if (!this.previousSearchKeyword || this.searchKeyword !== this.previousSearchKeyword) {
            pageNum = 1;
        } else {
            pageNum = this.pageNumber;
        }

        this.performSearch(pageNum, this.pageSize);
    }

    async performSearch(pageNumber, pageSize) {
        this.showSpinner = true;

        try {
            const result = await fetchAccountAssetWrapper({
                searchKeyWord: this.searchKeyword,
                selectedFilter: this.selectedAccountFilter,
                pageNumber: pageNumber,
                pageSize: parseInt(pageSize),
                assetFilter: this.inactiveAssets,
                CaseId: this.recordId
            });

            if (!result || result.assetWrapperList.length === 0) {
                this.showMessage = true;
            } else {
                this.showMessage = false;
            }

            this.accountAssetWrapperList = result.assetWrapperList.map(wrapper => ({
                ...wrapper,
                isExpanded: false
            }));
            this.pageNumber = result.pageNumber;
            this.totalRecords = result.totalRecords;
            this.recordStart = result.recordStart;
            this.recordEnd = result.recordEnd;
            this.totalPages = Math.ceil(result.totalRecords / pageSize);
            this.previousSearchKeyword = this.searchKeyword;

            this.showSpinner = false;

        } catch (error) {
            console.error('Search error:', error);
            this.showToast('Error', 'Search failed: ' + (error.body?.message || error.message), 'error');
            this.showSpinner = false;
        }
    }

    handleNext() {
        this.performSearch(this.pageNumber + 1, this.pageSize);
    }

    handlePrev() {
        this.performSearch(this.pageNumber - 1, this.pageSize);
    }

    handlePageSizeChange(event) {
        this.pageSize = event.detail.value;
        this.performSearch(1, this.pageSize);
    }

    handleToggleRow(event) {
        const accountId = event.currentTarget.dataset.recordId;
        const index = parseInt(event.currentTarget.dataset.index);

        this.accountAssetWrapperList = this.accountAssetWrapperList.map((wrapper, idx) => {
            if (idx === index) {
                return {
                    ...wrapper,
                    isExpanded: !wrapper.isExpanded
                };
            }
            return wrapper;
        });

        if (!this.accountAssetWrapperList[index].isExpanded) {
            // Row was just expanded
            this.selectedLocationAccountId = accountId;
            const wrapper = this.accountAssetWrapperList[index];
            this.selectedLocationAccountName = wrapper.objAcc.Id;
            this.selectedClientAccountName = wrapper.objAcc.Parent?.Id;
            this.selectedClientAccountId = wrapper.objAcc.Parent?.Id;
            this.showSaveButton = true;
        }
    }

    handleAssetSelection(event) {
        const assetId = event.currentTarget.dataset.assetId;
        const checked = event.target.checked;

        if (checked) {
            if (!this.selectedAssetIds.includes(assetId)) {
                this.selectedAssetIds = [...this.selectedAssetIds, assetId];
            }
        } else {
            this.selectedAssetIds = this.selectedAssetIds.filter(id => id !== assetId);
        }

        // Update selection details
        if (this.selectedAssetIds.length > 0) {
            this.updateSelectionDetails(assetId);
            this.selectionDetails = true;
        } else {
            this.selectionDetails = false;
        }
    }

    updateSelectionDetails(assetId) {
        for (let wrapper of this.accountAssetWrapperList) {
            for (let asset of wrapper.assetList) {
                if (asset.Id === assetId) {
                    this.selectedAssetName = asset.Name;
                    this.selectedLocationAccountName = wrapper.objAcc.Name;
                    this.selectedClientAccountName = wrapper.objAcc.Parent?.Name;
                    this.selectedClientAccountId = wrapper.objAcc.Parent?.Id;
                    return;
                }
            }
        }
    }

    async handleSaveSelection() {
        this.showSpinner = true;

        try {
            const result = await updateCase({
                clientId: this.selectedClientAccountId,
                locationId: this.selectedLocationAccountId,
                assetId: this.selectedAssetIds,
                caseId: this.recordId
            });

            if (result === 'Success') {
                this.showToast('Success', 'Case updated successfully', 'success');
                this.dispatchEvent(new CustomEvent('refresh'));
            } else {
                this.showToast('Error', 'Error: ' + result, 'error');
            }

            this.showSpinner = false;

        } catch (error) {
            console.error('Save error:', error);
            this.showToast('Error', 'Save failed: ' + (error.body?.message || error.message), 'error');
            this.showSpinner = false;
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

    get isPrevDisabled() {
        return this.pageNumber === 0 || this.pageNumber === 1;
    }

    get isNextDisabled() {
        return this.pageNumber === this.totalPages;
    }

    get paginationText() {
        return `${this.recordStart}-${this.recordEnd} of ${this.totalRecords} | Page ${this.pageNumber} of ${this.totalPages}`;
    }

    get hasResults() {
        return this.accountAssetWrapperList && this.accountAssetWrapperList.length > 0;
    }

    get selectionText() {
        return `You have selected Client Name: ${this.selectedClientAccountName}, Location Name: ${this.selectedLocationAccountName} and Asset Name: ${this.selectedAssetName}`;
    }

    isAssetChecked(assetId) {
        return this.selectedAssetIds.includes(assetId);
    }
}
