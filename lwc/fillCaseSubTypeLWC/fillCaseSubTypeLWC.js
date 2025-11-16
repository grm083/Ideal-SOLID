import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import Apex methods
import getCaseAssetDetails from '@salesforce/apex/GetCaseInformation.getcaseAssetDetails';

// Import custom label
import CaseSubTypeError from '@salesforce/label/c.CaseSubTypeError';

// Import Case fields
import CASE_ID from '@salesforce/schema/Case.Id';
import CASE_RECORD_TYPE_ID from '@salesforce/schema/Case.RecordTypeId';
import CASE_TYPE from '@salesforce/schema/Case.Case_Type__c';
import CASE_SUB_TYPE from '@salesforce/schema/Case.Case_Sub_Type__c';
import CASE_REASON from '@salesforce/schema/Case.Case_Reason__c';

const CASE_FIELDS = [CASE_ID, CASE_RECORD_TYPE_ID, CASE_TYPE, CASE_SUB_TYPE, CASE_REASON];

/**
 * FillCaseSubType - LWC component for filling case type, sub-type, and reason
 * Converted from Aura component: aura/FillCaseSubType
 *
 * @description Modal form with complex validation logic for:
 * - Case Type selection
 * - Case Sub-Type selection (dependent on type)
 * - Case Reason selection (required for certain combinations)
 * - Product family validation for Pickup cases
 */
export default class FillCaseSubTypeLWC extends LightningElement {
    // Public properties
    @api recordId;
    @api showForm = false;

    // Private properties
    @track caseType = '';
    @track caseSubType = '';
    @track caseReason = '';
    @track showErrorMessage = false;
    @track errorMessage = '';

    // Custom label
    label = {
        CaseSubTypeError
    };

    // Restricted case type/sub-type combinations
    RESTRICTED_COMBINATIONS = [
        { type: 'Vendor Confirmation', subType: 'Hauler of Record' },
        { type: 'Vendor Confirmation', subType: 'Schedule A' },
        { type: 'Discrepencies', subType: 'Asset' },
        { type: 'Discrepencies', subType: 'Hauler' },
        { type: 'Discrepencies', subType: 'Price' },
        { type: 'Discrepencies', subType: 'Service Date' },
        { type: 'Discrepencies', subType: 'Vendor' },
        { type: 'Discrepencies', subType: 'Vendor or Client Identification' }
    ];

    // Allowed sub-types by product family for Pickup cases
    ROLLOFF_ALLOWED_SUBTYPES = ['Empty and Return', 'Empty and Do NOT Return', 'Bale(s)'];
    COMMERCIAL_ALLOWED_SUBTYPES = ['Extra Pickup', 'On Call', 'Bale(s)'];

    // Wire Case Record
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    caseRecord;

    // Computed properties
    get recordTypeId() {
        return getFieldValue(this.caseRecord.data, CASE_RECORD_TYPE_ID);
    }

    get caseReasonFieldClass() {
        return this.showErrorMessage && this.errorMessage.includes('Case Reason')
            ? 'slds-form-element slds-has-error'
            : '';
    }

    // Event Handlers
    handleCloseModal() {
        this.showForm = false;
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleFieldChange(event) {
        const fieldName = event.target.fieldName;
        const value = event.target.value;

        if (fieldName === 'Case_Type__c') {
            this.caseType = value;
        } else if (fieldName === 'Case_Sub_Type__c') {
            this.caseSubType = value;
        } else if (fieldName === 'Case_Reason__c') {
            this.caseReason = value;
        }

        // Clear error when user changes values
        if (this.showErrorMessage) {
            this.showErrorMessage = false;
            this.errorMessage = '';
        }
    }

    async handleSubmit(event) {
        event.preventDefault();

        const fields = event.detail.fields;
        const caseType = fields.Case_Type__c || '';
        const caseSubType = fields.Case_Sub_Type__c || '';
        const caseReason = fields.Case_Reason__c || '';

        // Validation 1: Service Not Performed requires Case Reason
        if (caseType === 'Status' && caseSubType === 'Service Not Performed' && !caseReason) {
            this.showErrorMessage = true;
            this.errorMessage = 'Case Reason is Required, when case sub type is selected as Service Not Performed.';
            return;
        }

        // Validation 2: Check restricted combinations
        const isRestricted = this.RESTRICTED_COMBINATIONS.some(
            combo => combo.type === caseType && combo.subType === caseSubType
        );

        if (isRestricted) {
            this.showErrorMessage = true;
            this.errorMessage = this.label.CaseSubTypeError;
            return;
        }

        // Validation 3: For Pickup cases, validate against product family
        if (caseType === 'Pickup') {
            await this.validatePickupCase(fields);
        } else {
            // Clear errors and submit
            this.showErrorMessage = false;
            this.errorMessage = '';
            this.submitForm(fields);
        }
    }

    async validatePickupCase(fields) {
        try {
            const caseAssets = await getCaseAssetDetails({ caseId: this.recordId });

            if (caseAssets && caseAssets.length > 0) {
                const caseData = caseAssets[0];
                const asset = caseData.Asset;
                const newSubType = fields.Case_Sub_Type__c;

                // Check Rolloff validation
                if (asset && asset.ProductFamily === 'Rolloff') {
                    // Skip validation for Open Top Temporary assets
                    const isOpenTopTemp = asset.Equipment_Type__c === 'Open Top' && asset.Duration__c === 'Temporary';

                    if (!isOpenTopTemp && !this.ROLLOFF_ALLOWED_SUBTYPES.includes(newSubType)) {
                        this.showErrorMessage = true;
                        this.errorMessage = 'For Product Family RollOff we can only select Empty and Return, Empty And DO NOT Return and Bale(s)';
                        return;
                    }
                }

                // Check Commercial validation
                if (asset && asset.ProductFamily === 'Commercial' && asset.Equipment_Type__c !== 'Hand Pickup') {
                    if (!this.COMMERCIAL_ALLOWED_SUBTYPES.includes(newSubType)) {
                        this.showErrorMessage = true;
                        this.errorMessage = 'For Product Family Commercial we can only select Extra Pickup, On-Call and Bale(s)';
                        return;
                    }
                }
            }

            // If all validations pass, submit the form
            this.showErrorMessage = false;
            this.errorMessage = '';
            this.submitForm(fields);

        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error validating case', 'error');
        }
    }

    submitForm(fields) {
        // Submit the form
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess() {
        this.showForm = false;

        // Refresh the record
        setTimeout(() => {
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        }, 2000);

        // Dispatch success event
        this.dispatchEvent(new CustomEvent('subtypeupdated', {
            detail: { caseId: this.recordId }
        }));

        this.showToast('Success', 'Case Sub-Type updated successfully', 'success');
    }

    handleError(error) {
        this.showToast('Error', 'An error occurred while updating the case', 'error');
        console.error('Form error:', error);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}
