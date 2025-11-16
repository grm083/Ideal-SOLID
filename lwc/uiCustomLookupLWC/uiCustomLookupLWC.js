import { LightningElement, api, track } from 'lwc';
import fetchLookUpValues from '@salesforce/apex/UI_customLookUpController.fetchLookUpValues';

export default class UiCustomLookupLWC extends LightningElement {
    @api objectApiName;
    @api iconName;
    @api caseId;
    @api label = 'Search';
    @api placeholder = 'Search...';

    @track searchKeyword = '';
    @track listOfSearchRecords = [];
    @track selectedRecord = {};
    @track message = '';
    @track isLoading = false;
    @track isDropdownOpen = false;

    searchTimeout;

    get hasRecords() {
        return this.listOfSearchRecords && this.listOfSearchRecords.length > 0;
    }

    get hasSelectedRecord() {
        return this.selectedRecord && this.selectedRecord.Id;
    }

    get showSearchField() {
        return !this.hasSelectedRecord;
    }

    get showPill() {
        return this.hasSelectedRecord;
    }

    get selectedRecordName() {
        return this.selectedRecord ? this.selectedRecord.Name : '';
    }

    get dropdownClass() {
        return this.isDropdownOpen ? 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open' : 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-close';
    }

    handleFocus() {
        this.isDropdownOpen = true;
        this.isLoading = true;
        // Load default 5 records
        this.performSearch('');
    }

    handleBlur() {
        // Delay to allow click event on results to fire first
        setTimeout(() => {
            this.isDropdownOpen = false;
            this.listOfSearchRecords = [];
        }, 300);
    }

    handleInputChange(event) {
        this.searchKeyword = event.target.value;

        // Clear existing timeout
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }

        // Debounce search
        this.searchTimeout = setTimeout(() => {
            const keyword = this.searchKeyword;

            if (keyword && keyword.length > 0) {
                this.isDropdownOpen = true;
                this.performSearch(keyword);
            } else {
                this.isDropdownOpen = false;
                this.listOfSearchRecords = [];
            }
        }, 300);
    }

    async performSearch(searchKeyword) {
        try {
            this.isLoading = true;
            const result = await fetchLookUpValues({
                searchKeyWord: searchKeyword,
                ObjectName: this.objectApiName,
                caseId: this.caseId
            });

            if (result && result.length === 0) {
                this.message = 'No Result Found...';
                this.listOfSearchRecords = [];
            } else {
                this.message = '';
                this.listOfSearchRecords = result;
            }
        } catch (error) {
            console.error('Error searching records:', error);
            this.message = 'Error searching records';
            this.listOfSearchRecords = [];
        } finally {
            this.isLoading = false;
        }
    }

    handleRecordSelect(event) {
        const selectedRecordId = event.detail.recordId;
        const selectedRec = this.listOfSearchRecords.find(
            record => record.Id === selectedRecordId
        );

        if (selectedRec) {
            this.selectedRecord = selectedRec;
            this.searchKeyword = '';
            this.listOfSearchRecords = [];
            this.isDropdownOpen = false;

            // Dispatch event to parent
            const selectEvent = new CustomEvent('recordselect', {
                detail: {
                    recordId: selectedRec.Id,
                    record: selectedRec
                }
            });
            this.dispatchEvent(selectEvent);
        }
    }

    handleClear() {
        this.selectedRecord = {};
        this.searchKeyword = '';
        this.listOfSearchRecords = [];

        // Dispatch remove event to parent
        const removeEvent = new CustomEvent('recordremove', {
            detail: {}
        });
        this.dispatchEvent(removeEvent);
    }

    @api
    clearSelection() {
        this.handleClear();
    }
}
