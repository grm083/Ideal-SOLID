import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getWorkOrderPreviewInfo from '@salesforce/apex/WorkOrderPreviewController.getWorkOrderPreviewInfo';
import updateWorkOrderPreviewFields from '@salesforce/apex/WorkOrderPreviewController.updateWorkOrderPreviewFields';

/**
 * Work Order Preview Component
 *
 * Allows users to enter work order details for case:
 * - Onsite Contact Name
 * - Onsite Contact Phone
 * - Work Order Instructions
 * - By-Pass Work Order checkbox
 *
 * Features:
 * - Real-time preview of work order information
 * - Validation message display
 * - Existing work order alerts
 * - Save/Reset functionality
 *
 * @author Claude (AI Assistant)
 * @date 2025-11-18
 */
export default class WorkOrderPreview extends LightningElement {
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

    @track workOrderData = {
        siteContact: '',
        siteContactPhone: '',
        workOrderInstructions: '',
        byPassWorkOrder: false
    };

    @track validationMessages = [];
    @track isLoading = false;
    @track error = null;

    @track isWorkOrderRequired = true;
    @track isValidForWorkOrder = false;
    @track hasExistingWorkOrders = false;
    @track activeWorkOrderCount = 0;
    @track previewText = '';

    // ========================================
    // Lifecycle Hooks
    // ========================================

    connectedCallback() {
        if (this.caseId) {
            this.loadWorkOrderPreviewInfo();
        }
    }

    // ========================================
    // Computed Properties
    // ========================================

    /**
     * Whether save button should be disabled
     */
    get isSaveDisabled() {
        return this.isLoading;
    }

    /**
     * Whether there are validation messages
     */
    get hasValidationMessages() {
        return this.validationMessages && this.validationMessages.length > 0;
    }

    /**
     * Whether there is preview text to display
     */
    get hasPreviewText() {
        return this.previewText && this.previewText.trim().length > 0;
    }

    /**
     * Work order label (singular/plural)
     */
    get workOrderLabel() {
        return this.activeWorkOrderCount === 1 ? 'order' : 'orders';
    }

    // ========================================
    // Event Handlers
    // ========================================

    /**
     * Handle site contact change
     */
    handleSiteContactChange(event) {
        this.workOrderData.siteContact = event.target.value;
        this.updatePreview();
    }

    /**
     * Handle site contact phone change
     */
    handleSiteContactPhoneChange(event) {
        this.workOrderData.siteContactPhone = event.target.value;
        this.updatePreview();
    }

    /**
     * Handle work order instructions change
     */
    handleWorkOrderInstructionsChange(event) {
        this.workOrderData.workOrderInstructions = event.target.value;
        this.updatePreview();
    }

    /**
     * Handle by-pass work order change
     */
    handleByPassWorkOrderChange(event) {
        this.workOrderData.byPassWorkOrder = event.target.checked;
        this.updatePreview();
    }

    /**
     * Handle reset button click
     */
    handleReset(event) {
        event.preventDefault();
        this.loadWorkOrderPreviewInfo();
    }

    /**
     * Handle save button click
     */
    handleSave(event) {
        event.preventDefault();
        this.saveWorkOrderPreview();
    }

    // ========================================
    // Private Methods - Data Loading
    // ========================================

    /**
     * Load work order preview info
     */
    loadWorkOrderPreviewInfo() {
        if (!this.caseId) return;

        this.isLoading = true;

        getWorkOrderPreviewInfo({ caseId: this.caseId })
            .then(result => {
                this.workOrderData.siteContact = result.siteContact || '';
                this.workOrderData.siteContactPhone = result.siteContactPhone || '';
                this.workOrderData.workOrderInstructions = result.workOrderInstructions || '';
                this.workOrderData.byPassWorkOrder = result.byPassWorkOrder || false;

                this.isWorkOrderRequired = result.isWorkOrderRequired;
                this.isValidForWorkOrder = result.isValidForWorkOrder;
                this.validationMessages = result.validationMessages || [];
                this.hasExistingWorkOrders = result.hasExistingWorkOrders;
                this.activeWorkOrderCount = result.activeWorkOrderCount || 0;
                this.previewText = result.previewText || '';
            })
            .catch(error => {
                this.showError('Failed to load work order preview: ' + this.getErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Save work order preview
     */
    saveWorkOrderPreview() {
        if (!this.caseId) {
            this.showError('Case ID is required');
            return;
        }

        const workOrderDataJson = JSON.stringify({
            siteContact: this.workOrderData.siteContact,
            siteContactPhone: this.workOrderData.siteContactPhone,
            workOrderInstructions: this.workOrderData.workOrderInstructions,
            byPassWorkOrder: this.workOrderData.byPassWorkOrder
        });

        this.isLoading = true;

        updateWorkOrderPreviewFields({
            caseId: this.caseId,
            workOrderDataJson: workOrderDataJson
        })
        .then(() => {
            this.showSuccess('Work order details saved successfully');
            this.notifyWorkOrderChange();
        })
        .catch(error => {
            this.showError('Failed to save work order details: ' + this.getErrorMessage(error));
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    /**
     * Update preview text
     */
    updatePreview() {
        if (this.workOrderData.byPassWorkOrder) {
            this.previewText = 'Work Order creation will be bypassed for this case.';
            return;
        }

        if (!this.isWorkOrderRequired) {
            this.previewText = 'Work Order is not required for this case type.';
            return;
        }

        const previewLines = [];

        if (this.workOrderData.siteContact) {
            previewLines.push('Onsite Contact: ' + this.workOrderData.siteContact);
        }

        if (this.workOrderData.siteContactPhone) {
            previewLines.push('Contact Phone: ' + this.workOrderData.siteContactPhone);
        }

        if (this.workOrderData.workOrderInstructions) {
            previewLines.push('Instructions: ' + this.workOrderData.workOrderInstructions);
        }

        if (previewLines.length === 0) {
            this.previewText = 'No work order details provided yet.';
        } else {
            this.previewText = previewLines.join('\n');
        }
    }

    // ========================================
    // Private Methods - Events
    // ========================================

    /**
     * Notify parent of work order change
     */
    notifyWorkOrderChange() {
        this.dispatchEvent(new CustomEvent('workorderchange', {
            detail: {
                siteContact: this.workOrderData.siteContact,
                siteContactPhone: this.workOrderData.siteContactPhone,
                workOrderInstructions: this.workOrderData.workOrderInstructions,
                byPassWorkOrder: this.workOrderData.byPassWorkOrder
            }
        }));
    }

    // ========================================
    // Private Methods - Utilities
    // ========================================

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
     * Refresh work order preview
     */
    @api
    refreshPreview() {
        this.loadWorkOrderPreviewInfo();
    }

    /**
     * Get work order data
     */
    @api
    getWorkOrderData() {
        return this.workOrderData;
    }

    /**
     * Validate work order
     */
    @api
    validate() {
        // Work order fields are optional, so always return true
        return true;
    }
}
