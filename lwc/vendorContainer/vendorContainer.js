import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import Case fields
import CASE_ID from '@salesforce/schema/Case.Id';
import CASE_STATUS from '@salesforce/schema/Case.Status';
import CASE_SUPPLIER from '@salesforce/schema/Case.Supplier__c';

const CASE_FIELDS = [CASE_ID, CASE_STATUS, CASE_SUPPLIER];

/**
 * VendorContainer - LWC component for vendor search modal
 * Converted from Aura component: aura/VendorContainer
 *
 * @description Displays a modal with vendor search functionality
 * Only enables vendor search when case status is 'New'
 */
export default class VendorContainer extends LightningElement {
    // Public properties
    @api recordId;
    @api showForm = true;

    // Private properties
    showVendorSearch = false;

    // Wire Case Record
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    caseRecord;

    // Computed properties
    get caseStatus() {
        return getFieldValue(this.caseRecord.data, CASE_STATUS);
    }

    get isCaseNew() {
        return this.caseStatus === 'New';
    }

    // Event Handlers
    handleCloseModal() {
        this.showForm = false;
        // Dispatch close event for parent components
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleVendorSearchTab() {
        this.showVendorSearch = true;
    }

    // Error handling for wire
    get hasError() {
        return this.caseRecord.error;
    }

    connectedCallback() {
        if (this.hasError) {
            this.showToast('Error', 'Failed to load case data', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}
