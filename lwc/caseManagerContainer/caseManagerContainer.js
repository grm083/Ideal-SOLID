import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

/**
 * Case Manager Container Component
 *
 * Main orchestrator for unified case management system.
 * Manages wizard flow for case creation/editing and displays persistent panels.
 *
 * Modes:
 * - create: New case creation wizard
 * - edit: Edit existing case via wizard
 * - view: View case with persistent panels
 *
 * Features:
 * - 4-phase wizard (Caller, Intent, Details, Review)
 * - Phase navigation with validation
 * - Persistent panels (highlight strip + action messages)
 * - State management across all phases
 * - Integration with CaseWizardService
 *
 * @author George Martin
 * @date 2025-11-18
 */
export default class CaseManagerContainer extends NavigationMixin(LightningElement) {
    // ========================================
    // Public Properties
    // ========================================

    /**
     * Record ID (automatically provided by Salesforce on record pages)
     */
    @api recordId;

    /**
     * Case ID (for manual configuration on app pages)
     */
    @api caseId;

    /**
     * Component mode: create, edit, view
     */
    @api mode = 'view';

    // ========================================
    // Private Properties
    // ========================================

    @track currentPhase = 'caller';
    @track isLoading = false;
    @track isSubmitting = false;
    @track wizardData = {};

    // ========================================
    // Lifecycle Hooks
    // ========================================

    connectedCallback() {
        this.initializeComponent();
    }

    // ========================================
    // Computed Properties
    // ========================================

    /**
     * Get effective case ID (recordId takes precedence over caseId)
     */
    get effectiveCaseId() {
        return this.recordId || this.caseId;
    }

    /**
     * Whether to show wizard
     */
    get showWizard() {
        return this.mode === 'create' || this.mode === 'edit';
    }

    /**
     * Whether to show persistent panels
     */
    get showPersistentPanels() {
        return this.mode === 'view' && this.effectiveCaseId;
    }

    /**
     * Whether currently in Phase 1
     */
    get isPhase1() {
        return this.currentPhase === 'caller';
    }

    /**
     * Whether currently in Phase 2
     */
    get isPhase2() {
        return this.currentPhase === 'intent';
    }

    /**
     * Whether currently in Phase 3
     */
    get isPhase3() {
        return this.currentPhase === 'details';
    }

    /**
     * Whether currently in Phase 4
     */
    get isPhase4() {
        return this.currentPhase === 'review';
    }

    /**
     * Whether on first phase
     */
    get isFirstPhase() {
        return this.currentPhase === 'caller';
    }

    /**
     * Whether on last phase
     */
    get isLastPhase() {
        return this.currentPhase === 'review';
    }

    // ========================================
    // Event Handlers
    // ========================================

    /**
     * Handle phase change from wizard stepper
     */
    handlePhaseChange(event) {
        this.currentPhase = event.detail.step;
    }

    /**
     * Handle previous button click
     */
    handlePrevious() {
        const phases = ['caller', 'intent', 'details', 'review'];
        const currentIndex = phases.indexOf(this.currentPhase);

        if (currentIndex > 0) {
            this.currentPhase = phases[currentIndex - 1];
        }
    }

    /**
     * Handle next button click
     */
    handleNext() {
        const phases = ['caller', 'intent', 'details', 'review'];
        const currentIndex = phases.indexOf(this.currentPhase);

        if (currentIndex < phases.length - 1) {
            this.currentPhase = phases[currentIndex + 1];
        }
    }

    /**
     * Handle submit button click
     */
    handleSubmit() {
        this.isSubmitting = true;

        // TODO: Call CaseWizardService to create/update case

        this.showSuccess('Case created successfully!');
        this.isSubmitting = false;
    }

    /**
     * Handle field edit from highlight strip
     */
    handleFieldEdit(event) {
        const field = event.detail.field;

        // Navigate to appropriate phase based on field
        if (field === 'location' || field === 'contact') {
            this.currentPhase = 'caller';
            this.mode = 'edit';
        } else if (field === 'asset' || field === 'caseType') {
            this.currentPhase = 'intent';
            this.mode = 'edit';
        } else if (field === 'customerInfo' || field === 'serviceDate') {
            this.currentPhase = 'details';
            this.mode = 'edit';
        }
    }

    /**
     * Handle action from action messages panel
     */
    handleAction(event) {
        const action = event.detail.action;

        // Handle different actions
        console.log('Action:', action);

        // TODO: Implement action handlers
    }

    // ========================================
    // Private Methods
    // ========================================

    /**
     * Initialize component
     */
    initializeComponent() {
        if (this.mode === 'create') {
            this.currentPhase = 'caller';
        } else if (this.mode === 'edit') {
            // Load case data
            this.loadCaseData();
        } else if (this.mode === 'view') {
            // View mode - show persistent panels
        }
    }

    /**
     * Load case data for edit mode
     */
    loadCaseData() {
        if (!this.effectiveCaseId) return;

        this.isLoading = true;

        // TODO: Load case data from CaseContextService

        this.isLoading = false;
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
     * Show error toast
     */
    showError(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        }));
    }

    // ========================================
    // Public API Methods
    // ========================================

    /**
     * Navigate to specific phase
     */
    @api
    goToPhase(phase) {
        this.currentPhase = phase;
    }

    /**
     * Get current wizard data
     */
    @api
    getWizardData() {
        return this.wizardData;
    }

    /**
     * Update wizard data
     */
    @api
    updateWizardData(data) {
        this.wizardData = { ...this.wizardData, ...data };
    }
}
