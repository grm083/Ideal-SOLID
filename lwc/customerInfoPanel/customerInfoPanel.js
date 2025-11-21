import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import evaluateBusinessRules from '@salesforce/apex/BusinessRuleValidatorController.evaluateBusinessRules';
import getCurrentCustomerInfo from '@salesforce/apex/BusinessRuleValidatorController.getCurrentCustomerInfo';
import updateCustomerInfoFields from '@salesforce/apex/BusinessRuleValidatorController.updateCustomerInfoFields';
import validateCustomerInfo from '@salesforce/apex/BusinessRuleValidatorController.validateCustomerInfo';

/**
 * Customer Info Panel Component
 *
 * Manages customer information fields with business rule integration.
 * Fields: PO Number, Profile Number, PSI, Company Category
 *
 * Features:
 * - Business rule requirement indicators
 * - Override task checkboxes
 * - PSI override reason and comments
 * - Validation before save
 * - Auto-load based on case ID
 *
 * @author George Martin
 * @date 2025-11-18
 */
export default class CustomerInfoPanel extends LightningElement {
    // ========================================
    // Public Properties
    // ========================================

    /**
     * Case ID (required)
     */
    @api caseId;

    // ========================================
    // Private Properties
    // ========================================

    @track customerInfo = this.getEmptyCustomerInfo();
    @track businessRules = {};
    @track isLoading = false;
    @track error = null;

    // ========================================
    // Lifecycle Hooks
    // ========================================

    connectedCallback() {
        if (this.caseId) {
            this.loadData();
        }
    }

    // ========================================
    // Computed Properties
    // ========================================

    /**
     * Whether business rules have been loaded
     */
    get hasBusinessRules() {
        return this.businessRules && Object.keys(this.businessRules).length > 0;
    }

    /**
     * Whether PO is required by business rules
     */
    get isPORequired() {
        return this.businessRules.isPORequired === true;
    }

    /**
     * Whether Profile Number is required
     */
    get isProfileNumberRequired() {
        return this.businessRules.isProfileNumberRequired === true;
    }

    /**
     * Whether PSI is required
     */
    get isPSIRequired() {
        return this.businessRules.isPSIRequired === true;
    }

    /**
     * Whether to show PSI override reason field
     */
    get showPSIOverride() {
        return this.customerInfo.psi && this.customerInfo.psi.trim() !== '';
    }

    /**
     * Whether to show PSI comments field
     */
    get showPSIComments() {
        return this.showPSIOverride;
    }

    /**
     * Whether save button should be disabled
     */
    get isSaveDisabled() {
        return this.isLoading;
    }

    // ========================================
    // Event Handlers
    // ========================================

    /**
     * Handle PO Number change
     */
    handlePONumberChange(event) {
        this.customerInfo.purchaseOrderNumber = event.detail.value;
    }

    /**
     * Handle Override PO change
     */
    handleOverridePOChange(event) {
        this.customerInfo.overridePOCreateTask = event.detail.checked;
    }

    /**
     * Handle Profile Number change
     */
    handleProfileNumberChange(event) {
        this.customerInfo.profileNumber = event.detail.value;
    }

    /**
     * Handle Override Profile change
     */
    handleOverrideProfileChange(event) {
        this.customerInfo.overrideProfileNumberTask = event.detail.checked;
    }

    /**
     * Handle PSI change
     */
    handlePSIChange(event) {
        this.customerInfo.psi = event.detail.value;
    }

    /**
     * Handle PSI Override Reason change
     */
    handlePSIOverrideReasonChange(event) {
        this.customerInfo.psiOverrideReason = event.detail.value;
    }

    /**
     * Handle PSI Comments change
     */
    handlePSICommentsChange(event) {
        this.customerInfo.psiComments = event.detail.value;
    }

    /**
     * Handle Company Category change
     */
    handleCompanyCategoryChange(event) {
        this.customerInfo.companyCategory = event.detail.value;
    }

    /**
     * Handle Override Company Category change
     */
    handleOverrideCompanyCategoryChange(event) {
        this.customerInfo.overrideCompanyCategoryTask = event.detail.checked;
    }

    /**
     * Handle reset button click
     */
    handleReset(event) {
        event.preventDefault();
        this.loadData();
    }

    /**
     * Handle save button click
     */
    handleSave(event) {
        event.preventDefault();

        if (!this.validateForm()) {
            return;
        }

        this.saveCustomerInfo();
    }

    // ========================================
    // Private Methods - Data Loading
    // ========================================

    /**
     * Load all data (business rules + customer info)
     */
    loadData() {
        this.loadBusinessRules();
        this.loadCustomerInfo();
    }

    /**
     * Load business rules
     */
    loadBusinessRules() {
        if (!this.caseId) return;

        evaluateBusinessRules({ caseId: this.caseId })
            .then(result => {
                this.businessRules = result;
            })
            .catch(error => {
                console.error('Failed to load business rules:', error);
                this.businessRules = {};
            });
    }

    /**
     * Load current customer info
     */
    loadCustomerInfo() {
        if (!this.caseId) return;

        this.isLoading = true;

        getCurrentCustomerInfo({ caseId: this.caseId })
            .then(result => {
                this.customerInfo = {
                    purchaseOrderNumber: result.purchaseOrderNumber || '',
                    overridePOCreateTask: result.overridePOCreateTask || false,
                    profileNumber: result.profileNumber || '',
                    overrideProfileNumberTask: result.overrideProfileNumberTask || false,
                    psi: result.psi || '',
                    psiOverrideReason: result.psiOverrideReason || '',
                    psiComments: result.psiComments || '',
                    companyCategory: result.companyCategory || '',
                    overrideCompanyCategoryTask: result.overrideCompanyCategoryTask || false
                };
            })
            .catch(error => {
                this.showError('Failed to load customer info: ' + this.getErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Save customer info
     */
    saveCustomerInfo() {
        if (!this.caseId) {
            this.showError('Case ID is required');
            return;
        }

        this.isLoading = true;

        const fieldUpdatesJson = JSON.stringify(this.customerInfo);

        updateCustomerInfoFields({
            caseId: this.caseId,
            fieldUpdatesJson: fieldUpdatesJson
        })
        .then(() => {
            this.showSuccess('Customer information saved successfully');
            this.notifyChange();
        })
        .catch(error => {
            this.showError('Failed to save customer info: ' + this.getErrorMessage(error));
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    // ========================================
    // Private Methods - Validation & Utilities
    // ========================================

    /**
     * Validate form before save
     */
    validateForm() {
        // Check required fields based on business rules
        if (this.isPORequired && !this.customerInfo.purchaseOrderNumber) {
            this.showError('Purchase Order Number is required');
            return false;
        }

        if (this.isProfileNumberRequired && !this.customerInfo.profileNumber) {
            this.showError('Profile Number is required');
            return false;
        }

        if (this.isPSIRequired && !this.customerInfo.psi) {
            this.showError('PSI is required');
            return false;
        }

        return true;
    }

    /**
     * Get empty customer info object
     */
    getEmptyCustomerInfo() {
        return {
            purchaseOrderNumber: '',
            overridePOCreateTask: false,
            profileNumber: '',
            overrideProfileNumberTask: false,
            psi: '',
            psiOverrideReason: '',
            psiComments: '',
            companyCategory: '',
            overrideCompanyCategoryTask: false
        };
    }

    /**
     * Notify parent of change
     */
    notifyChange() {
        this.dispatchEvent(new CustomEvent('customerinfochange', {
            detail: {
                customerInfo: this.customerInfo
            }
        }));
    }

    /**
     * Show error toast
     */
    showError(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        }));
    }

    /**
     * Show success toast
     */
    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success'
        }));
    }

    /**
     * Extract error message from error object
     */
    getErrorMessage(error) {
        if (!error) return 'Unknown error';
        if (typeof error === 'string') return error;
        if (error.body) {
            if (error.body.message) return error.body.message;
            if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                return error.body.pageErrors[0].message;
            }
        }
        if (error.message) return error.message;
        return JSON.stringify(error);
    }

    // ========================================
    // Public API Methods
    // ========================================

    /**
     * Get current customer info
     */
    @api
    getCustomerInfo() {
        return this.customerInfo;
    }

    /**
     * Refresh data from server
     */
    @api
    refresh() {
        this.loadData();
    }
}
