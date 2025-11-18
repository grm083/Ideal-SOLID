import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAvailableRecordTypes from '@salesforce/apex/CaseTypeConfiguratorController.getAvailableRecordTypes';
import getCurrentConfiguration from '@salesforce/apex/CaseTypeConfiguratorController.getCurrentConfiguration';
import getCaseTypeValues from '@salesforce/apex/CaseTypeConfiguratorController.getCaseTypeValues';
import getCaseSubTypeValues from '@salesforce/apex/CaseTypeConfiguratorController.getCaseSubTypeValues';
import getCaseReasonValues from '@salesforce/apex/CaseTypeConfiguratorController.getCaseReasonValues';
import updateCaseConfiguration from '@salesforce/apex/CaseTypeConfiguratorController.updateCaseConfiguration';
import updateQuickCaseType from '@salesforce/apex/CaseTypeConfiguratorController.updateQuickCaseType';
import validateConfiguration from '@salesforce/apex/CaseTypeConfiguratorController.validateConfiguration';

/**
 * Case Type Configurator Component
 *
 * Unified component for configuring case record type and case type/sub-type/reason.
 * Replaces changeRecordType and FillCaseSubType components.
 *
 * Features:
 * - Record type selection
 * - Dependent picklists for Case Type → Sub-Type → Reason
 * - Quick actions for common case types (Pickup, SNP, ETA, New Service)
 * - Auto-population based on asset and record type
 * - Validation before save
 *
 * @author Claude (AI Assistant)
 * @date 2025-11-18
 */
export default class CaseTypeConfigurator extends LightningElement {
    // ========================================
    // Public Properties
    // ========================================

    /**
     * Case ID (required)
     */
    @api caseId;

    /**
     * Show record type selector
     */
    @api showRecordType = true;

    /**
     * Show quick actions
     */
    @api showQuickActions = true;

    // ========================================
    // Private Properties
    // ========================================

    @track selectedRecordTypeId = '';
    @track selectedCaseType = '';
    @track selectedCaseSubType = '';
    @track selectedCaseReason = '';

    @track recordTypeOptions = [];
    @track caseTypeOptions = [];
    @track caseSubTypeOptions = [];
    @track caseReasonOptions = [];

    @track currentConfig = {};
    @track isLoading = false;
    @track error = null;

    wiredConfigResult;

    // ========================================
    // Lifecycle Hooks
    // ========================================

    connectedCallback() {
        this.loadRecordTypes();
        this.loadCaseTypeOptions();
        if (this.caseId) {
            this.loadCurrentConfiguration();
        }
    }

    // ========================================
    // Computed Properties
    // ========================================

    /**
     * Whether save button should be disabled
     */
    get isSaveDisabled() {
        return this.isLoading || !this.selectedCaseType;
    }

    /**
     * Whether sub-type dropdown should be disabled
     */
    get disableSubType() {
        return this.isLoading || !this.selectedCaseType || this.caseSubTypeOptions.length === 0;
    }

    /**
     * Whether reason dropdown should be disabled
     */
    get disableReason() {
        return this.isLoading || !this.selectedCaseSubType || this.caseReasonOptions.length === 0;
    }

    /**
     * Whether current configuration is available
     */
    get hasConfiguration() {
        return this.currentConfig && Object.keys(this.currentConfig).length > 0;
    }

    // ========================================
    // Event Handlers - Quick Actions
    // ========================================

    /**
     * Handle quick pickup button click
     */
    handleQuickPickup(event) {
        event.preventDefault();
        this.updateQuickType('Pickup');
    }

    /**
     * Handle quick SNP button click
     */
    handleQuickSNP(event) {
        event.preventDefault();
        this.updateQuickType('SNP');
    }

    /**
     * Handle quick ETA button click
     */
    handleQuickETA(event) {
        event.preventDefault();
        this.updateQuickType('ETA');
    }

    /**
     * Handle quick new service button click
     */
    handleQuickNewService(event) {
        event.preventDefault();
        this.updateQuickType('New Service');
    }

    // ========================================
    // Event Handlers - Field Changes
    // ========================================

    /**
     * Handle record type change
     */
    handleRecordTypeChange(event) {
        this.selectedRecordTypeId = event.detail.value;
        this.loadCaseTypeOptions();
    }

    /**
     * Handle case type change
     */
    handleCaseTypeChange(event) {
        this.selectedCaseType = event.detail.value;
        this.selectedCaseSubType = '';
        this.selectedCaseReason = '';
        this.loadCaseSubTypeOptions();
    }

    /**
     * Handle case sub-type change
     */
    handleCaseSubTypeChange(event) {
        this.selectedCaseSubType = event.detail.value;
        this.selectedCaseReason = '';
        this.loadCaseReasonOptions();
    }

    /**
     * Handle case reason change
     */
    handleCaseReasonChange(event) {
        this.selectedCaseReason = event.detail.value;
    }

    /**
     * Handle reset button click
     */
    handleReset(event) {
        event.preventDefault();
        this.loadCurrentConfiguration();
    }

    /**
     * Handle save button click
     */
    handleSave(event) {
        event.preventDefault();

        if (!this.validateForm()) {
            return;
        }

        this.saveConfiguration();
    }

    // ========================================
    // Private Methods - Data Loading
    // ========================================

    /**
     * Load available record types
     */
    loadRecordTypes() {
        getAvailableRecordTypes()
            .then(result => {
                this.recordTypeOptions = result.map(rt => ({
                    label: rt.name,
                    value: rt.id
                }));
            })
            .catch(error => {
                console.error('Failed to load record types:', error);
                this.recordTypeOptions = [];
            });
    }

    /**
     * Load current configuration
     */
    loadCurrentConfiguration() {
        if (!this.caseId) return;

        this.isLoading = true;

        getCurrentConfiguration({ caseId: this.caseId })
            .then(result => {
                this.currentConfig = result;
                this.selectedRecordTypeId = result.recordTypeId || '';
                this.selectedCaseType = result.caseType || '';
                this.selectedCaseSubType = result.caseSubType || '';
                this.selectedCaseReason = result.caseReason || '';

                // Load dependent picklists
                this.loadCaseTypeOptions();
                if (this.selectedCaseType) {
                    this.loadCaseSubTypeOptions();
                }
                if (this.selectedCaseSubType) {
                    this.loadCaseReasonOptions();
                }
            })
            .catch(error => {
                this.showError('Failed to load configuration: ' + this.getErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Load case type options
     */
    loadCaseTypeOptions() {
        getCaseTypeValues({ recordTypeId: this.selectedRecordTypeId })
            .then(result => {
                this.caseTypeOptions = result.map(option => ({
                    label: option.label,
                    value: option.value
                }));
            })
            .catch(error => {
                console.error('Failed to load case type options:', error);
                this.caseTypeOptions = [];
            });
    }

    /**
     * Load case sub-type options
     */
    loadCaseSubTypeOptions() {
        getCaseSubTypeValues({
            caseType: this.selectedCaseType,
            recordTypeId: this.selectedRecordTypeId
        })
        .then(result => {
            this.caseSubTypeOptions = result.map(option => ({
                label: option.label,
                value: option.value
            }));
        })
        .catch(error => {
            console.error('Failed to load case sub-type options:', error);
            this.caseSubTypeOptions = [];
        });
    }

    /**
     * Load case reason options
     */
    loadCaseReasonOptions() {
        getCaseReasonValues({
            caseSubType: this.selectedCaseSubType,
            recordTypeId: this.selectedRecordTypeId
        })
        .then(result => {
            this.caseReasonOptions = result.map(option => ({
                label: option.label,
                value: option.value
            }));
        })
        .catch(error => {
            console.error('Failed to load case reason options:', error);
            this.caseReasonOptions = [];
        });
    }

    /**
     * Update case with quick type
     */
    updateQuickType(quickType) {
        if (!this.caseId) {
            this.showError('Case ID is required');
            return;
        }

        this.isLoading = true;

        updateQuickCaseType({
            caseId: this.caseId,
            quickType: quickType
        })
        .then(() => {
            this.showSuccess(`Case type updated to ${quickType}`);
            this.loadCurrentConfiguration();
            this.notifyConfigurationChange();
        })
        .catch(error => {
            this.showError('Failed to update case type: ' + this.getErrorMessage(error));
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    /**
     * Save configuration
     */
    saveConfiguration() {
        if (!this.caseId) {
            this.showError('Case ID is required');
            return;
        }

        const config = {
            recordTypeId: this.selectedRecordTypeId,
            caseType: this.selectedCaseType,
            caseSubType: this.selectedCaseSubType,
            caseReason: this.selectedCaseReason
        };

        const configJson = JSON.stringify(config);

        this.isLoading = true;

        updateCaseConfiguration({
            caseId: this.caseId,
            configJson: configJson
        })
        .then(() => {
            this.showSuccess('Configuration saved successfully');
            this.loadCurrentConfiguration();
            this.notifyConfigurationChange();
        })
        .catch(error => {
            this.showError('Failed to save configuration: ' + this.getErrorMessage(error));
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    // ========================================
    // Private Methods - Validation & Utilities
    // ========================================

    /**
     * Validate form
     */
    validateForm() {
        if (!this.selectedCaseType) {
            this.showError('Case Type is required');
            return false;
        }

        return true;
    }

    /**
     * Notify parent of configuration change
     */
    notifyConfigurationChange() {
        this.dispatchEvent(new CustomEvent('configurationchange', {
            detail: {
                recordTypeId: this.selectedRecordTypeId,
                caseType: this.selectedCaseType,
                caseSubType: this.selectedCaseSubType,
                caseReason: this.selectedCaseReason
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
     * Get current configuration
     */
    @api
    getCurrentConfiguration() {
        return {
            recordTypeId: this.selectedRecordTypeId,
            caseType: this.selectedCaseType,
            caseSubType: this.selectedCaseSubType,
            caseReason: this.selectedCaseReason
        };
    }

    /**
     * Set configuration programmatically
     */
    @api
    setConfiguration(recordTypeId, caseType, caseSubType, caseReason) {
        this.selectedRecordTypeId = recordTypeId || '';
        this.selectedCaseType = caseType || '';
        this.selectedCaseSubType = caseSubType || '';
        this.selectedCaseReason = caseReason || '';

        if (this.selectedCaseType) {
            this.loadCaseSubTypeOptions();
        }
        if (this.selectedCaseSubType) {
            this.loadCaseReasonOptions();
        }
    }

    /**
     * Refresh configuration from server
     */
    @api
    refreshConfiguration() {
        this.loadCurrentConfiguration();
    }
}
