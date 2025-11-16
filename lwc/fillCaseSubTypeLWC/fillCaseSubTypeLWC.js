/**
 * FillCaseSubTypeLWC - Modal for filling case type, sub-type, and reason
 *
 * REFACTORED TO USE CASE DATA GOVERNOR:
 * ======================================
 * - Subscribes to CaseDataChannel LMS for centralized data
 * - Uses pageData.caseAsset from governor (eliminates getCaseAssetDetails call)
 * - Maintains backward compatibility with fallback to direct Apex
 * - Follows same pattern as setCaseCustomerInfoLWC and showCaseMessagesLWC
 *
 * @see caseDataGovernorLWC - Centralized data hub
 * @see CaseDataGovernorService - Apex service providing asset data
 */
import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, MessageContext, publish } from 'lightning/messageService';

// Import LMS Channel
import CASE_DATA_CHANNEL from '@salesforce/messageChannel/CaseDataChannel__c';

// Import Apex methods (fallback only)
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

    // Governor integration
    @track caseAsset = null; // Asset data from governor or direct call
    subscription = null;
    hasReceivedGovernorData = false;

    // Wire message context
    @wire(MessageContext)
    messageContext;

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

    // ========================================================================
    // LIFECYCLE HOOKS
    // ========================================================================

    connectedCallback() {
        this.subscribeToGovernor();
    }

    disconnectedCallback() {
        this.unsubscribeFromGovernor();
    }

    // ========================================================================
    // GOVERNOR INTEGRATION
    // ========================================================================

    subscribeToGovernor() {
        if (this.subscription) {
            return;
        }

        this.subscription = subscribe(
            this.messageContext,
            CASE_DATA_CHANNEL,
            (message) => this.handleGovernorMessage(message)
        );
    }

    unsubscribeFromGovernor() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    handleGovernorMessage(message) {
        if (message.caseId !== this.recordId) {
            return;
        }

        switch (message.eventType) {
            case 'load':
            case 'refresh':
            case 'update':
                this.processGovernorData(message);
                break;
            case 'error':
                console.error('Governor error:', message.errorMessage);
                break;
        }
    }

    processGovernorData(message) {
        try {
            const pageData = JSON.parse(message.pageData);

            if (!pageData) {
                return;
            }

            this.hasReceivedGovernorData = true;

            // Store asset data from governor
            if (pageData.caseAsset) {
                this.caseAsset = pageData.caseAsset;
            }

        } catch (error) {
            console.error('Error processing governor data:', error);
        }
    }

    requestGovernorRefresh() {
        const message = {
            caseId: this.recordId,
            eventType: 'refresh',
            section: 'asset',
            timestamp: new Date().toISOString()
        };
        publish(this.messageContext, CASE_DATA_CHANNEL, message);
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
            let asset = null;

            // PREFERRED: Use asset from governor if available
            if (this.hasReceivedGovernorData && this.caseAsset) {
                asset = this.caseAsset;
            } else {
                // FALLBACK: Load asset via direct Apex call
                const caseAssets = await getCaseAssetDetails({ caseId: this.recordId });

                if (caseAssets && caseAssets.length > 0) {
                    const caseData = caseAssets[0];
                    asset = caseData.Asset;

                    // Cache for future use
                    this.caseAsset = asset;
                }
            }

            // Perform validations if asset exists
            if (asset) {
                const newSubType = fields.Case_Sub_Type__c;

                // Check Rolloff validation
                if (asset.ProductFamily === 'Rolloff') {
                    // Skip validation for Open Top Temporary assets
                    const isOpenTopTemp = asset.Equipment_Type__c === 'Open Top' && asset.Duration__c === 'Temporary';

                    if (!isOpenTopTemp && !this.ROLLOFF_ALLOWED_SUBTYPES.includes(newSubType)) {
                        this.showErrorMessage = true;
                        this.errorMessage = 'For Product Family RollOff we can only select Empty and Return, Empty And DO NOT Return and Bale(s)';
                        return;
                    }
                }

                // Check Commercial validation
                if (asset.ProductFamily === 'Commercial' && asset.Equipment_Type__c !== 'Hand Pickup') {
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

        // Request governor to refresh if we received data from it
        if (this.hasReceivedGovernorData) {
            this.requestGovernorRefresh();
        }

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
