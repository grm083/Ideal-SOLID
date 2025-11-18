/**
 * @description Record Search Base Component
 * Generic reusable search component for searching any record type
 * Used by entitySelector, contactSelector, assetSelector
 *
 * @property {String} searchTitle - Title for search card
 * @property {String} iconName - Lightning icon name
 * @property {Array} searchFields - Array of search field configurations
 * @property {Array} columns - Array of column configurations for results table
 * @property {Boolean} showRadioSelect - Whether to show radio buttons for selection
 * @property {Boolean} showCreateNew - Whether to show "Create New" button
 * @property {String} createNewLabel - Label for create new button
 * @property {Boolean} showPagination - Whether to show pagination controls
 */
import { LightningElement, api } from 'lwc';

const PAGE_SIZE = 10;

export default class RecordSearchBase extends LightningElement {
    /**
     * @description Title for the search card
     */
    @api searchTitle = 'Search Records';

    /**
     * @description Lightning icon name
     */
    @api iconName = 'standard:account';

    /**
     * @description Array of search field configurations
     * Each field: { name, label, type, placeholder, value }
     */
    @api searchFields = [];

    /**
     * @description Array of column configurations for results table
     * Each column: { fieldName, label, type, isLink, linkField }
     */
    @api columns = [];

    /**
     * @description Whether to show radio buttons for selection
     */
    @api showRadioSelect = true;

    /**
     * @description Whether to show "Create New" button
     */
    @api showCreateNew = true;

    /**
     * @description Label for create new button
     */
    @api createNewLabel = 'Create New';

    /**
     * @description Whether to show pagination
     */
    @api showPagination = true;

    /**
     * @description Search results
     */
    results = [];

    /**
     * @description All results (before pagination)
     */
    allResults = [];

    /**
     * @description Whether component is loading
     */
    isLoading = false;

    /**
     * @description Whether search has been performed
     */
    searchPerformed = false;

    /**
     * @description Selected record ID
     */
    selectedRecordId = '';

    /**
     * @description Current page number
     */
    currentPage = 1;

    /**
     * @description Total number of pages
     */
    totalPages = 1;

    /**
     * @description Computed property - whether there are results
     */
    get hasResults() {
        return this.results && this.results.length > 0;
    }

    /**
     * @description Computed property - whether to show no results message
     */
    get showNoResults() {
        return this.searchPerformed && !this.isLoading && (!this.results || this.results.length === 0);
    }

    /**
     * @description Computed property - results count text
     */
    get resultsCountText() {
        const total = this.allResults.length;
        if (total === 0) return 'No results';
        if (total === 1) return '1 result';
        return `${total} results`;
    }

    /**
     * @description Computed property - is first page
     */
    get isFirstPage() {
        return this.currentPage === 1;
    }

    /**
     * @description Computed property - is last page
     */
    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    /**
     * @description Handle search field change
     * @param {Event} event - Change event
     */
    handleFieldChange(event) {
        const fieldName = event.target.dataset.field;
        const value = event.target.value;

        // Update field value in searchFields array
        this.searchFields = this.searchFields.map(field => {
            if (field.name === fieldName) {
                return { ...field, value: value };
            }
            return field;
        });

        // Dispatch event to parent with search criteria
        this.dispatchEvent(new CustomEvent('fieldchange', {
            detail: {
                fieldName: fieldName,
                value: value,
                searchCriteria: this.getSearchCriteria()
            }
        }));
    }

    /**
     * @description Handle search button click
     */
    handleSearch() {
        const searchCriteria = this.getSearchCriteria();

        // Validate that at least one field has a value
        const hasSearchCriteria = Object.values(searchCriteria).some(value => value && value.trim() !== '');

        if (!hasSearchCriteria) {
            // Show error message
            this.dispatchEvent(new CustomEvent('error', {
                detail: {
                    message: 'Please enter at least one search criterion'
                }
            }));
            return;
        }

        this.isLoading = true;
        this.searchPerformed = true;

        // Dispatch event to parent to perform search
        this.dispatchEvent(new CustomEvent('search', {
            detail: {
                searchCriteria: searchCriteria
            }
        }));
    }

    /**
     * @description Handle clear button click
     */
    handleClear() {
        // Clear all field values
        this.searchFields = this.searchFields.map(field => ({
            ...field,
            value: ''
        }));

        // Clear results
        this.results = [];
        this.allResults = [];
        this.searchPerformed = false;
        this.selectedRecordId = '';
        this.currentPage = 1;
        this.totalPages = 1;

        // Dispatch event to parent
        this.dispatchEvent(new CustomEvent('clear'));
    }

    /**
     * @description Handle create new button click
     */
    handleCreateNew() {
        // Dispatch event to parent
        this.dispatchEvent(new CustomEvent('createnew'));
    }

    /**
     * @description Handle record selection (radio button)
     * @param {Event} event - Change event
     */
    handleRecordSelect(event) {
        const recordId = event.target.value;
        this.selectedRecordId = recordId;

        // Update selected state in results
        this.results = this.results.map(record => ({
            ...record,
            isSelected: record.Id === recordId
        }));

        // Find full record in allResults
        const selectedRecord = this.allResults.find(r => r.Id === recordId);

        // Dispatch event to parent
        this.dispatchEvent(new CustomEvent('recordselect', {
            detail: {
                recordId: recordId,
                record: selectedRecord
            }
        }));
    }

    /**
     * @description Handle record click (link click)
     * @param {Event} event - Click event
     */
    handleRecordClick(event) {
        event.preventDefault();
        const recordId = event.currentTarget.dataset.id;

        // Find full record
        const record = this.allResults.find(r => r.Id === recordId);

        // Dispatch event to parent
        this.dispatchEvent(new CustomEvent('recordclick', {
            detail: {
                recordId: recordId,
                record: record
            }
        }));
    }

    /**
     * @description Handle previous page
     */
    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateDisplayedResults();
        }
    }

    /**
     * @description Handle next page
     */
    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateDisplayedResults();
        }
    }

    /**
     * @description Get search criteria from fields
     * @returns {Object} Search criteria object
     */
    getSearchCriteria() {
        const criteria = {};
        this.searchFields.forEach(field => {
            if (field.value) {
                criteria[field.name] = field.value;
            }
        });
        return criteria;
    }

    /**
     * @description Public API to set search results
     * @param {Array} searchResults - Array of search result records
     */
    @api
    setResults(searchResults) {
        this.isLoading = false;
        this.allResults = searchResults || [];
        this.currentPage = 1;
        this.totalPages = Math.ceil(this.allResults.length / PAGE_SIZE);
        this.updateDisplayedResults();
    }

    /**
     * @description Update displayed results based on current page
     */
    updateDisplayedResults() {
        const startIndex = (this.currentPage - 1) * PAGE_SIZE;
        const endIndex = startIndex + PAGE_SIZE;
        this.results = this.allResults.slice(startIndex, endIndex).map(record => ({
            ...record,
            isSelected: record.Id === this.selectedRecordId
        }));
    }

    /**
     * @description Public API to show loading spinner
     */
    @api
    showLoading() {
        this.isLoading = true;
    }

    /**
     * @description Public API to hide loading spinner
     */
    @api
    hideLoading() {
        this.isLoading = false;
    }

    /**
     * @description Public API to get selected record ID
     * @returns {String} Selected record ID
     */
    @api
    getSelectedRecordId() {
        return this.selectedRecordId;
    }

    /**
     * @description Public API to get selected record
     * @returns {Object} Selected record object
     */
    @api
    getSelectedRecord() {
        return this.allResults.find(r => r.Id === this.selectedRecordId);
    }

    /**
     * @description Public API to set search field value
     * @param {String} fieldName - Field name
     * @param {String} value - Field value
     */
    @api
    setFieldValue(fieldName, value) {
        this.searchFields = this.searchFields.map(field => {
            if (field.name === fieldName) {
                return { ...field, value: value };
            }
            return field;
        });
    }

    /**
     * @description Public API to get search field value
     * @param {String} fieldName - Field name
     * @returns {String} Field value
     */
    @api
    getFieldValue(fieldName) {
        const field = this.searchFields.find(f => f.name === fieldName);
        return field ? field.value : '';
    }

    /**
     * @description Public API to trigger search programmatically
     */
    @api
    triggerSearch() {
        this.handleSearch();
    }

    /**
     * @description Public API to clear search
     */
    @api
    clearSearch() {
        this.handleClear();
    }
}
