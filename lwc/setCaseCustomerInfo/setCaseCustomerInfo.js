import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import Apex methods
import getCaseRecordDetails from '@salesforce/apex/GetCaseInformation.getCaseRecordDetails';
import getCompanyCategory from '@salesforce/apex/GetCaseInformation.getCompanyCategory';

// Import Case fields
import CASE_ID from '@salesforce/schema/Case.Id';
import CASE_RECORD_TYPE_ID from '@salesforce/schema/Case.RecordTypeId';
import CASE_TYPE from '@salesforce/schema/Case.Case_Type__c';
import CASE_SUB_TYPE from '@salesforce/schema/Case.Case_Sub_Type__c';

const CASE_FIELDS = [CASE_ID, CASE_RECORD_TYPE_ID, CASE_TYPE, CASE_SUB_TYPE];

/**
 * SetCaseCustomerInfo - LWC component for setting customer-required information
 * Converted from Aura component: aura/SetCaseCustomerInfo
 *
 * @description Modal form for setting:
 * - Purchase Order information with override
 * - Company Category selection
 * - Haul Away service details (conditionally)
 * - PSI information
 * - Billing dispute information (conditionally)
 */
export default class SetCaseCustomerInfo extends LightningElement {
    // Public properties
    @api recordId;
    @api showForm = true;

    // Private properties
    @track companyCategoryOptions = [];
    @track selectedCompanyCategoryValue = '';
    @track selectedCompanyCategoryLabel = '';
    @track isHaulAwayChecked = false;
    @track vendorIdRequired = false;
    @track haulAwayBookedRequired = false;
    @track vendorSelected = '';
    @track isHaulAwayUIEnabled = false;
    @track isBillingInvoiceChargeDispute = false;

    // Wire Case Record
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    caseRecord;

    // Computed properties
    get recordTypeId() {
        return getFieldValue(this.caseRecord.data, CASE_RECORD_TYPE_ID);
    }

    get caseType() {
        return getFieldValue(this.caseRecord.data, CASE_TYPE);
    }

    get caseSubType() {
        return getFieldValue(this.caseRecord.data, CASE_SUB_TYPE);
    }

    // Lifecycle Hooks
    async connectedCallback() {
        await this.loadCaseDetails();
        await this.loadCompanyCategories();
    }

    // Data Loading Methods
    async loadCaseDetails() {
        try {
            const result = await getCaseRecordDetails({ caseId: this.recordId });

            if (result && result.length > 0) {
                // result[0] is record type ID (not needed with @wire)
                // result[2] is company category code

                if (result.length > 2) {
                    this.selectedCompanyCategoryValue = result[2];
                }

                // Parse result flags
                result.forEach((value) => {
                    if (value === 'true') {
                        this.isHaulAwayChecked = true;
                    }
                    if (value === 'VendorServiceIdReq') {
                        this.vendorIdRequired = true;
                    }
                    if (value === 'HaulAwayBookedService') {
                        this.haulAwayBookedRequired = true;
                    }
                    if (value === 'HaulAwayUIEnabled') {
                        this.isHaulAwayUIEnabled = true;
                    }
                    if (value === 'BillingInvoiceChargeDispute') {
                        this.isBillingInvoiceChargeDispute = true;
                    }
                });
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error loading case details', 'error');
        }
    }

    async loadCompanyCategories() {
        try {
            const options = await getCompanyCategory({ caseId: this.recordId });
            this.companyCategoryOptions = options || [];
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error loading company categories', 'error');
        }
    }

    // Event Handlers
    handleCloseModal() {
        this.showForm = false;
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleCompanyCategoryChange(event) {
        this.selectedCompanyCategoryValue = event.detail.value;

        // Find the selected option to get the label
        const selectedOption = this.companyCategoryOptions.find(
            opt => opt.value === event.detail.value
        );
        if (selectedOption) {
            this.selectedCompanyCategoryLabel = selectedOption.label;
        }
    }

    handleHaulAwayChange(event) {
        this.isHaulAwayChecked = event.detail.checked || event.detail.value;

        // Update vendor ID required based on vendor selection and haul away checkbox
        this.vendorIdRequired = this.vendorSelected === '223110_5378' && this.isHaulAwayChecked;
    }

    handleHaulAwayVendorChange(event) {
        this.vendorSelected = event.detail.value;

        // Update vendor ID required
        this.vendorIdRequired = this.vendorSelected === '223110_5378' && this.isHaulAwayChecked;

        // Update haul away booked required
        this.haulAwayBookedRequired = this.vendorSelected !== 'Not Available' && this.isHaulAwayChecked;
    }

    handleSubmit(event) {
        event.preventDefault();

        const fields = event.detail.fields;

        // Add Company Category fields if selected
        if (this.selectedCompanyCategoryLabel && this.selectedCompanyCategoryValue) {
            fields.Company_Category__c = this.selectedCompanyCategoryLabel;
            fields.CompanyCategoryCode__c = this.selectedCompanyCategoryValue;
        }

        // Submit the form with modified fields
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess() {
        this.showForm = false;

        // Refresh the record
        notifyRecordUpdateAvailable([{ recordId: this.recordId }]);

        // Dispatch success event
        this.dispatchEvent(new CustomEvent('customerinfoupdated', {
            detail: { caseId: this.recordId }
        }));

        this.showToast('Success', 'Customer information updated successfully', 'success');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}
