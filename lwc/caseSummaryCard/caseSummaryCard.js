import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCaseSummaryData from '@salesforce/apex/CaseContextService.getCaseSummaryData';
import evaluateBusinessRules from '@salesforce/apex/BusinessRuleValidatorController.evaluateBusinessRules';

/**
 * Case Summary Card Component
 *
 * Displays a read-only summary of all wizard phases:
 * - Caller: Entity, Location, Contact
 * - Intent: Asset, Case Type, Sub-Type, Reason
 * - Details: Customer Info, Service Date
 * - Business Rules: Validation status
 *
 * Features:
 * - Progress indicator showing completion status
 * - Edit buttons for each section to jump back to specific phases
 * - Business rule validation status display
 * - Visual indicators for ready/not ready state
 *
 * @author Claude (AI Assistant)
 * @date 2025-11-18
 */
export default class CaseSummaryCard extends LightningElement {
    // ========================================
    // Public Properties
    // ========================================

    /**
     * Case ID (required)
     */
    @api caseId;

    /**
     * Show progress indicator
     */
    @api showProgress = true;

    // ========================================
    // Private Properties
    // ========================================

    @track summaryData = {};
    @track businessRuleMessages = [];
    @track isLoading = false;
    @track error = null;

    // ========================================
    // Lifecycle Hooks
    // ========================================

    connectedCallback() {
        if (this.caseId) {
            this.loadSummaryData();
            this.loadBusinessRules();
        }
    }

    // ========================================
    // Computed Properties
    // ========================================

    /**
     * Current phase for progress indicator
     */
    get currentPhase() {
        if (this.isReadyForSubmit) return 'review';
        if (this.summaryData.serviceDate) return 'details';
        if (this.summaryData.caseType) return 'intent';
        if (this.summaryData.contactName) return 'caller';
        return 'caller';
    }

    /**
     * Number of completed phases
     */
    get completedPhases() {
        let count = 0;
        if (this.summaryData.contactName) count++;
        if (this.summaryData.caseType) count++;
        if (this.summaryData.serviceDate) count++;
        if (this.isReadyForSubmit) count++;
        return count;
    }

    /**
     * Whether case is ready for submission
     */
    get isReadyForSubmit() {
        return this.summaryData.contactName &&
               this.summaryData.caseType &&
               this.summaryData.serviceDate &&
               this.businessRuleMessages.length === 0;
    }

    /**
     * Whether there are business rule messages
     */
    get hasBusinessRuleMessages() {
        return this.businessRuleMessages && this.businessRuleMessages.length > 0;
    }

    /**
     * Formatted service date
     */
    get formattedServiceDate() {
        if (!this.summaryData.serviceDate) return '--';

        try {
            const date = new Date(this.summaryData.serviceDate);
            return date.toLocaleDateString();
        } catch (error) {
            return this.summaryData.serviceDate;
        }
    }

    // ========================================
    // Event Handlers
    // ========================================

    /**
     * Handle edit caller button click
     */
    handleEditCaller(event) {
        event.preventDefault();
        this.dispatchPhaseEditEvent('caller');
    }

    /**
     * Handle edit intent button click
     */
    handleEditIntent(event) {
        event.preventDefault();
        this.dispatchPhaseEditEvent('intent');
    }

    /**
     * Handle edit details button click
     */
    handleEditDetails(event) {
        event.preventDefault();
        this.dispatchPhaseEditEvent('details');
    }

    // ========================================
    // Private Methods - Data Loading
    // ========================================

    /**
     * Load case summary data
     */
    loadSummaryData() {
        if (!this.caseId) return;

        this.isLoading = true;

        getCaseSummaryData({ caseId: this.caseId })
            .then(result => {
                this.summaryData = {
                    // Caller
                    entityType: result.entityType || '--',
                    locationName: result.locationName || '--',
                    vendorName: result.vendorName || '--',
                    clientName: result.clientName || '--',
                    contactName: result.contactName || '--',

                    // Intent
                    assetName: result.assetName || '--',
                    recordTypeName: result.recordTypeName || '--',
                    caseType: result.caseType || '--',
                    caseSubType: result.caseSubType || '--',
                    caseReason: result.caseReason || '--',

                    // Details
                    purchaseOrderNumber: result.purchaseOrderNumber || '--',
                    profileNumber: result.profileNumber || '--',
                    psi: result.psi || '--',
                    serviceDate: result.serviceDate || '--'
                };
            })
            .catch(error => {
                this.showError('Failed to load case summary: ' + this.getErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Load business rules
     */
    loadBusinessRules() {
        if (!this.caseId) return;

        evaluateBusinessRules({ caseId: this.caseId })
            .then(result => {
                const messages = [];

                // Collect all error and warning messages
                if (result.errors && result.errors.length > 0) {
                    messages.push(...result.errors);
                }

                if (result.warnings && result.warnings.length > 0) {
                    messages.push(...result.warnings);
                }

                this.businessRuleMessages = messages;
            })
            .catch(error => {
                console.error('Failed to load business rules:', error);
            });
    }

    // ========================================
    // Private Methods - Events
    // ========================================

    /**
     * Dispatch phase edit event
     */
    dispatchPhaseEditEvent(phase) {
        this.dispatchEvent(new CustomEvent('phaseedit', {
            detail: {
                phase: phase,
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
     * Refresh summary data
     */
    @api
    refreshSummary() {
        this.loadSummaryData();
        this.loadBusinessRules();
    }

    /**
     * Get summary data
     */
    @api
    getSummaryData() {
        return this.summaryData;
    }

    /**
     * Check if ready for submit
     */
    @api
    isReady() {
        return this.isReadyForSubmit;
    }
}
