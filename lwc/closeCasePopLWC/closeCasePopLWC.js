import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import Apex methods
import getRecordTypeId from '@salesforce/apex/GetCaseInformation.getRecordTypeId';
import createAcornComment from '@salesforce/apex/GetCaseInformation.createAcornComment';

// Import Case fields
import CASE_ID from '@salesforce/schema/Case.Id';
import CASE_RECORD_TYPE_ID from '@salesforce/schema/Case.RecordTypeId';
import CLOSE_CASE_REASON from '@salesforce/schema/Case.Close_Case_Reason__c';
import CASE_CLOSE_REASON from '@salesforce/schema/Case.Case_Close_Reason__c';

const CASE_FIELDS = [CASE_ID, CASE_RECORD_TYPE_ID];

/**
 * CloseCasePop - LWC component for closing cases with reason selection
 * Converted from Aura component: aura/CloseCasePop
 *
 * @description Modal form for closing cases with:
 * - Irrelevant case flag checkbox
 * - Close reason picklist
 * - Additional reason field (conditionally shown)
 * - Automatic Acorn comment creation on close
 */
export default class CloseCasePopLWC extends LightningElement {
    // Public properties
    @api recordId;
    @api showForm = true;

    // Private properties
    @track closeCaseReason = '';
    @track showAdditionalField = false;
    @track caseCloseReasonValue = '';

    // Reasons that require additional field
    REASONS_REQUIRING_ADDITIONAL_FIELD = [
        'No Action Needed',
        'Duplicate',
        'Call Issues'
    ];

    // Wire Case Record
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    caseRecord;

    // Computed property for record type ID
    get recordTypeId() {
        return getFieldValue(this.caseRecord.data, CASE_RECORD_TYPE_ID);
    }

    // Event Handlers
    handleCloseModal() {
        this.showForm = false;
        // Dispatch close event for parent components
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleCloseReasonChange(event) {
        this.closeCaseReason = event.target.value;

        // Show additional field for specific close reasons
        if (this.closeCaseReason) {
            this.showAdditionalField = this.REASONS_REQUIRING_ADDITIONAL_FIELD.includes(
                this.closeCaseReason
            );
        } else {
            this.showAdditionalField = false;
        }
    }

    async handleSuccess(event) {
        try {
            // Get the saved values from the form
            const fields = event.detail.fields;
            const closeCaseReasonValue = fields.Close_Case_Reason__c || '';
            const additionalReasonValue = fields.Case_Close_Reason__c || '';

            // Create combined comment for Acorn
            const comment = `${closeCaseReasonValue} ${additionalReasonValue}`.trim();

            // Create Acorn comment
            if (comment) {
                const result = await createAcornComment({
                    comment: comment,
                    caseId: this.recordId
                });

                if (result === 'ok') {
                    this.showToast('Success!', 'A new Comment has been added successfully.', 'success');
                } else {
                    this.showToast('Error!', result, 'error');
                }
            }

            // Close the modal
            this.handleCloseModal();

            // Refresh the record and view
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);

            // Dispatch custom event to refresh parent components
            this.dispatchEvent(new CustomEvent('caseclosed', {
                detail: { caseId: this.recordId }
            }));

        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error closing case', 'error');
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
