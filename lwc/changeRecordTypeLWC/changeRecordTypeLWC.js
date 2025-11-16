import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

// Import Apex methods
import getRecordTypeNames from '@salesforce/apex/changeRecordTypeController.getRecordTypeNames';
import getInfo from '@salesforce/apex/changeRecordTypeController.getInfo';
import updateCaseRecord from '@salesforce/apex/changeRecordTypeController.updateCaseRecord';

// Import Custom Label
import CASE_RECORD_TYPE_ORDER from '@salesforce/label/c.CaseRecordType';
import CASE_SUB_TYPE_ERROR from '@salesforce/label/c.CaseSubTypeError';

/**
 * changeRecordType - LWC component for case record type selection
 * Converted from Aura component: aura/changeRecordType
 *
 * @description Allows users to change case record type and update related fields.
 * Features:
 * - Vertical navigation list of available record types
 * - Quick action buttons (Pickup, New Service, SNP, ETA)
 * - Case Type/SubType/Reason form
 * - Validation for restricted combinations
 */
export default class ChangeRecordTypeLWC extends LightningElement {
    // Public properties
    @api recordId;

    // Private properties
    @track recordTypes = [];
    @track selectedItem = '';
    @track itemDescription = '';
    @track newRecordTypeId = '';
    @track showForm = false;
    @track errorCombination = false;
    @track errorMsg = '';
    @track caseType = '';
    @track caseSubType = '';
    @track caseReason = '';

    // Restricted combinations (from Aura)
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

    // Computed properties
    get navigationItems() {
        return this.recordTypes
            .filter(rt => rt.Name !== 'Integration Case')
            .map(rt => ({
                label: rt.Name,
                name: rt.Name
            }));
    }

    // Lifecycle Hooks
    async connectedCallback() {
        await this.loadRecordTypes();
    }

    // Data Loading Methods
    async loadRecordTypes() {
        try {
            const recordTypes = await getRecordTypeNames({ recordId: this.recordId });

            // Order record types based on custom label
            const properOrder = CASE_RECORD_TYPE_ORDER.split('|');
            const orderedTypes = [];

            properOrder.forEach(orderName => {
                const foundType = recordTypes.find(rt => rt.Name === orderName);
                if (foundType) {
                    orderedTypes.push(foundType);
                }
            });

            // Add any remaining record types not in the order
            recordTypes.forEach(rt => {
                if (!orderedTypes.find(ot => ot.Name === rt.Name)) {
                    orderedTypes.push(rt);
                }
            });

            this.recordTypes = orderedTypes;
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error loading record types', 'error');
        }
    }

    // Event Handlers
    async handleRecordTypeSelect(event) {
        const selectedName = event.detail.name;
        this.selectedItem = selectedName;
        this.showForm = true;

        try {
            const info = await getInfo({
                recordId: this.recordId,
                recordType: selectedName
            });

            this.newRecordTypeId = info.recordTypeId;
            this.itemDescription = info.recordTypeDesc;

            // Reset error state
            this.errorCombination = false;
            this.errorMsg = '';
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error loading record type info', 'error');
        }
    }

    async handleQuickActionClick(event) {
        const buttonLabel = event.target.label;

        try {
            await updateCaseRecord({
                recordId: this.recordId,
                newRecordType: this.newRecordTypeId,
                caseBtnType: buttonLabel,
                casetype: '',
                caseSubType: '',
                caseReason: ''
            });

            this.showToast('Success', 'Record type updated successfully', 'success');
            this.dispatchEvent(new CustomEvent('refresh'));
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error updating record type', 'error');
        }
    }

    handleFieldChange(event) {
        const fieldName = event.target.fieldName;

        if (fieldName === 'Case_Type__c') {
            this.caseType = event.detail.value;
        } else if (fieldName === 'Case_Sub_Type__c') {
            this.caseSubType = event.detail.value;
        } else if (fieldName === 'Case_Reason__c') {
            this.caseReason = event.detail.value;
        }
    }

    async handleSubmit(event) {
        event.preventDefault();

        const fields = event.detail.fields;
        const caseType = fields.Case_Type__c;
        const caseSubType = fields.Case_Sub_Type__c;
        const caseReason = fields.Case_Reason__c;

        // Validation: Check for restricted combinations
        const isRestricted = this.RESTRICTED_COMBINATIONS.some(
            combo => combo.type === caseType && combo.subType === caseSubType
        );

        if (isRestricted) {
            this.errorCombination = true;
            this.errorMsg = CASE_SUB_TYPE_ERROR;
            return;
        }

        this.errorCombination = false;
        this.errorMsg = '';

        try {
            await updateCaseRecord({
                recordId: this.recordId,
                newRecordType: this.newRecordTypeId,
                caseBtnType: '',
                casetype: caseType,
                caseSubType: caseSubType,
                caseReason: caseReason
            });

            this.showForm = false;
            this.showToast('Success', 'Case updated successfully', 'success');
            this.dispatchEvent(new CustomEvent('refresh'));
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error updating case', 'error');
        }
    }

    handleSuccess() {
        this.showForm = false;
        this.showToast('Success', 'Case updated successfully', 'success');
        this.dispatchEvent(new CustomEvent('refresh'));
    }

    handleError(event) {
        const errorMessage = event.detail?.detail || 'An error occurred';
        this.showToast('Error', errorMessage, 'error');
    }

    // Helper Methods
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissible'
        });
        this.dispatchEvent(event);
    }
}
