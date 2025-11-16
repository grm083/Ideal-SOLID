import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import Case fields
import CASE_ID from '@salesforce/schema/Case.Id';
import CASE_STATUS from '@salesforce/schema/Case.Status';
import CASE_LOCATION from '@salesforce/schema/Case.Location__c';

const CASE_FIELDS = [CASE_ID, CASE_STATUS, CASE_LOCATION];

/**
 * LocationContainer - LWC component for location selection modal
 * Converted from Aura component: aura/LocationContainer
 *
 * @description Displays a modal with location details and search tabs
 * - If location is already set: defaults to Location Details tab
 * - If location is not set: defaults to Location Search tab
 * - Only enables location search when case status is 'New'
 */
export default class LocationContainerLWC extends LightningElement {
    // Public properties
    @api recordId;
    @api showForm = true;

    // Private properties
    showLocationDetails = true;
    showLocationSearch = false;

    // Wire Case Record
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    caseRecord;

    // Computed properties
    get caseStatus() {
        return getFieldValue(this.caseRecord.data, CASE_STATUS);
    }

    get locationId() {
        return getFieldValue(this.caseRecord.data, CASE_LOCATION);
    }

    get isCaseNew() {
        return this.caseStatus === 'New';
    }

    get hasLocation() {
        return !!this.locationId;
    }

    // Event Handlers
    handleCloseModal() {
        this.showForm = false;
        // Dispatch close event for parent components
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleLocationDetailsTab() {
        this.showLocationDetails = true;
        this.showLocationSearch = false;
    }

    handleLocationSearchTab() {
        this.showLocationDetails = false;
        this.showLocationSearch = true;
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
