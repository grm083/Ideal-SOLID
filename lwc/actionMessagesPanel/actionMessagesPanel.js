import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getActionPanelData from '@salesforce/apex/ActionMessagesPanelController.getActionPanelData';

/**
 * Action Messages Panel Component
 *
 * Displays action messages and button group for case operations:
 * - Message section with icon and heading
 * - Button section with all available actions
 * - Button visibility controlled by CaseBusinessRuleService
 * - Spinner overlay during operations
 *
 * Features:
 * - Progress Case
 * - View Case Summary (multi-asset)
 * - Add Quote / View Quotes
 * - Initiate Work Order
 * - Add Case Assets
 * - Create Pending Info Task
 * - Multi Dates
 *
 * Replaces: ShowCaseMessages (Aura + LWC)
 *
 * @author Claude (AI Assistant)
 * @date 2025-11-18
 */
export default class ActionMessagesPanel extends NavigationMixin(LightningElement) {
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

    @track panelData = {};
    @track isLoading = false;
    @track isProcessing = false;
    @track error = null;

    // ========================================
    // Lifecycle Hooks
    // ========================================

    connectedCallback() {
        if (this.caseId) {
            this.loadActionPanelData();
        }
    }

    // ========================================
    // Computed Properties
    // ========================================

    /**
     * Whether there is an action message to display
     */
    get hasActionMessage() {
        return this.panelData.actionMessage && this.panelData.actionMessage.trim().length > 0;
    }

    /**
     * Message heading based on variant
     */
    get messageHeading() {
        if (this.panelData.messageVariant === 'error') {
            return 'Action Required';
        } else if (this.panelData.messageVariant === 'warning') {
            return 'Attention Needed';
        } else if (this.panelData.messageVariant === 'success') {
            return 'Ready';
        } else {
            return 'Information';
        }
    }

    /**
     * Message CSS class based on variant
     */
    get messageClass() {
        const baseClass = 'slds-notify slds-notify_alert slds-m-bottom_medium';

        if (this.panelData.messageVariant === 'error') {
            return baseClass + ' slds-alert_error';
        } else if (this.panelData.messageVariant === 'warning') {
            return baseClass + ' slds-alert_warning';
        } else if (this.panelData.messageVariant === 'success') {
            return baseClass + ' slds-theme_success';
        } else {
            return baseClass + ' slds-alert_info';
        }
    }

    /**
     * Case summary button label
     */
    get caseSummaryLabel() {
        if (this.panelData.relatedCaseCount > 0) {
            return `View Case Summary (${this.panelData.relatedCaseCount})`;
        }
        return 'View Case Summary';
    }

    // ========================================
    // Event Handlers
    // ========================================

    /**
     * Handle Progress Case button click
     */
    handleProgressCase(event) {
        event.preventDefault();
        this.dispatchActionEvent('progresscase');
    }

    /**
     * Handle View Case Summary button click
     */
    handleViewCaseSummary(event) {
        event.preventDefault();
        this.dispatchActionEvent('viewcasesummary');
    }

    /**
     * Handle Add Quote button click
     */
    handleAddQuote(event) {
        event.preventDefault();
        this.dispatchActionEvent('addquote');
    }

    /**
     * Handle Initiate Work Order button click
     */
    handleInitiateWorkOrder(event) {
        event.preventDefault();
        this.dispatchActionEvent('initiateworkorder');
    }

    /**
     * Handle Add Case Assets button click
     */
    handleAddCaseAssets(event) {
        event.preventDefault();
        this.dispatchActionEvent('addcaseassets');
    }

    /**
     * Handle Create Pending Info Task button click
     */
    handlePendingInfoTask(event) {
        event.preventDefault();
        this.dispatchActionEvent('pendinginfotask');
    }

    /**
     * Handle Multi Dates button click
     */
    handleMultiDates(event) {
        event.preventDefault();
        this.dispatchActionEvent('multidates');
    }

    // ========================================
    // Private Methods - Data Loading
    // ========================================

    /**
     * Load action panel data
     */
    loadActionPanelData() {
        if (!this.caseId) return;

        this.isLoading = true;

        getActionPanelData({ caseId: this.caseId })
            .then(result => {
                this.panelData = result;
            })
            .catch(error => {
                console.error('Failed to load action panel data:', error);
                this.showError('Failed to load action panel: ' + this.getErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ========================================
    // Private Methods - Events
    // ========================================

    /**
     * Dispatch action event to parent
     */
    dispatchActionEvent(actionType) {
        this.dispatchEvent(new CustomEvent('action', {
            detail: {
                action: actionType,
                caseId: this.caseId
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
     * Refresh action panel data
     */
    @api
    refreshPanel() {
        this.loadActionPanelData();
    }

    /**
     * Get panel data
     */
    @api
    getPanelData() {
        return this.panelData;
    }

    /**
     * Set processing state
     */
    @api
    setProcessing(isProcessing) {
        this.isProcessing = isProcessing;
    }
}
