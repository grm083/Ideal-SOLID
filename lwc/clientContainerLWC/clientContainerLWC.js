import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

// Import Case fields
import CASE_ID from '@salesforce/schema/Case.Id';
import CASE_STATUS from '@salesforce/schema/Case.Status';
import CASE_SUPPLIER from '@salesforce/schema/Case.Supplier__c';

const CASE_FIELDS = [CASE_ID, CASE_STATUS, CASE_SUPPLIER];

/**
 * ClientContainer - LWC component for client search modal
 * Converted from Aura component: aura/ClientContainer
 *
 * @description Modal container with tabset for client search functionality.
 * Only displays client search when case status is "New".
 */
export default class ClientContainerLWC extends LightningElement {
    // Public properties
    @api recordId;
    @api showForm = true;

    // Private properties
    @track showClientSearch = false;

    // Wire Case Record
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    caseRecord;

    // Computed properties
    get caseStatus() {
        return getFieldValue(this.caseRecord.data, CASE_STATUS);
    }

    get supplier() {
        return getFieldValue(this.caseRecord.data, CASE_SUPPLIER);
    }

    /**
     * Determines if client search should be shown
     * Only show when case status is "New"
     */
    get isStatusNew() {
        return this.caseStatus === 'New';
    }

    // Event Handlers
    handleCloseModal() {
        this.showForm = false;
        this.dispatchEvent(new CustomEvent('close'));
    }

    /**
     * Handle tab activation for Client Search
     * Sets showClientSearch to true when tab becomes active
     */
    handleClientSearchActive() {
        this.showClientSearch = true;
    }
}
