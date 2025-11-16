/**
 * SetCaseCustomerInfo - REFACTORED to use Case Data Governor
 *
 * REFACTORING CHANGES:
 * - Subscribes to CaseDataChannel LMS
 * - Gets case details from pageData (eliminating getCaseRecordDetails call)
 * - Still calls getCompanyCategory (could be added to governor in future)
 * - Maintains backward compatibility with fallback
 */
import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, MessageContext, publish } from 'lightning/messageService';

// Import LMS Channel
import CASE_DATA_CHANNEL from '@salesforce/messageChannel/CaseDataChannel__c';

// Import Apex methods (fallback and company categories)
import getCaseRecordDetails from '@salesforce/apex/GetCaseInformation.getCaseRecordDetails';
import getCompanyCategory from '@salesforce/apex/GetCaseInformation.getCompanyCategory';

// Import Case fields
import CASE_ID from '@salesforce/schema/Case.Id';
import CASE_RECORD_TYPE_ID from '@salesforce/schema/Case.RecordTypeId';
import CASE_TYPE from '@salesforce/schema/Case.Case_Type__c';
import CASE_SUB_TYPE from '@salesforce/schema/Case.Case_Sub_Type__c';
import CASE_COMPANY_CATEGORY from '@salesforce/schema/Case.Company_Category__c';

const CASE_FIELDS = [CASE_ID, CASE_RECORD_TYPE_ID, CASE_TYPE, CASE_SUB_TYPE, CASE_COMPANY_CATEGORY];

export default class SetCaseCustomerInfoLWC extends LightningElement {
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

    // Governor integration
    subscription = null;
    hasReceivedGovernorData = false;
    governorTimeout = null;

    // Wire message context
    @wire(MessageContext)
    messageContext;

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

    // ========================================================================
    // LIFECYCLE HOOKS
    // ========================================================================

    connectedCallback() {
        this.subscribeToGovernor();
        this.loadCompanyCategories();

        // Fallback timeout if governor doesn't respond
        this.governorTimeout = setTimeout(() => {
            if (!this.hasReceivedGovernorData) {
                console.warn('Governor data not received, falling back to direct Apex');
                this.loadCaseDetailsDirectly();
            }
        }, 2000);
    }

    disconnectedCallback() {
        this.unsubscribeFromGovernor();
        if (this.governorTimeout) {
            clearTimeout(this.governorTimeout);
        }
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
                this.processGovernorData(message);
                break;
            case 'error':
                console.error('Governor error:', message.errorMessage);
                this.loadCaseDetailsDirectly();
                break;
        }
    }

    processGovernorData(message) {
        try {
            const pageData = JSON.parse(message.pageData);

            if (!pageData || !pageData.caseRecord) {
                return;
            }

            this.hasReceivedGovernorData = true;
            if (this.governorTimeout) {
                clearTimeout(this.governorTimeout);
            }

            // Map governor data to component
            this.mapGovernorDataToComponent(pageData);

        } catch (error) {
            console.error('Error processing governor data:', error);
            this.loadCaseDetailsDirectly();
        }
    }

    mapGovernorDataToComponent(pageData) {
        const caseRecord = pageData.caseRecord;

        // Set company category if available
        if (caseRecord.CompanyCategoryCode__c) {
            this.selectedCompanyCategoryValue = caseRecord.CompanyCategoryCode__c;
        }

        // Get haul away info from case record
        if (caseRecord.Is_Haul_Away_Service__c) {
            this.isHaulAwayChecked = true;
        }

        // Check haul away vendor requirements
        if (caseRecord.Haul_Away_Vendor__c === '223110_5378' && caseRecord.Is_Haul_Away_Service__c) {
            this.vendorIdRequired = true;
        }

        // Check if haul away service booked
        if (caseRecord.Haul_Away_Vendor__c &&
            caseRecord.Haul_Away_Vendor__c !== 'Not Available' &&
            caseRecord.Is_Haul_Away_Service__c) {
            this.haulAwayBookedRequired = true;
        }

        // Haul away UI enabled (could come from pageConfig in future)
        this.isHaulAwayUIEnabled = true;

        // Check for billing invoice charge dispute
        if (caseRecord.Case_Type__c === 'Billing' &&
            caseRecord.Case_Sub_Type__c === 'Invoice Charge Dispute') {
            this.isBillingInvoiceChargeDispute = true;
        }
    }

    // ========================================================================
    // FALLBACK DIRECT DATA LOADING
    // ========================================================================

    async loadCaseDetailsDirectly() {
        try {
            const result = await getCaseRecordDetails({ caseId: this.recordId });

            if (result && result.length > 0) {
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

    // ========================================================================
    // EVENT HANDLERS
    // ========================================================================

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

        // Request governor to refresh
        if (this.hasReceivedGovernorData) {
            this.requestGovernorRefresh();
        }

        // Dispatch success event
        this.dispatchEvent(new CustomEvent('customerinfoupdated', {
            detail: { caseId: this.recordId }
        }));

        this.showToast('Success', 'Customer information updated successfully', 'success');
    }

    requestGovernorRefresh() {
        const message = {
            caseId: this.recordId,
            eventType: 'refresh',
            section: 'case',
            timestamp: new Date().toISOString()
        };
        publish(this.messageContext, CASE_DATA_CHANNEL, message);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}
