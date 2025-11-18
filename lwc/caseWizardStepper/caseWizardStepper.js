/**
 * @description Case Wizard Stepper Component
 * Orchestrates the 4-phase case creation wizard
 * Manages step navigation, validation, and submission
 *
 * PHASES:
 * 1. CALLER - Location/Vendor/Client + Contact selection
 * 2. INTENT - Asset + Case Type/Sub-Type/Reason configuration
 * 3. DETAILS - Customer Info + Service Date + Business Rules
 * 4. REVIEW - Summary and final submission
 *
 * @property {String} recordId - Case ID (for edit mode)
 * @property {String} mode - 'create' or 'edit'
 */
import { LightningElement, api } from 'lwc';
import validatePhase from '@salesforce/apex/CaseWizardService.validatePhase';
import createCaseFromWizard from '@salesforce/apex/CaseWizardService.createCaseFromWizard';
import updateCaseFromWizard from '@salesforce/apex/CaseWizardService.updateCaseFromWizard';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Wizard step constants
const STEPS = {
    CALLER: 'caller',
    INTENT: 'intent',
    DETAILS: 'details',
    REVIEW: 'review'
};

export default class CaseWizardStepper extends LightningElement {
    /**
     * @description Case record ID (for edit mode)
     */
    @api recordId;

    /**
     * @description Wizard mode ('create' or 'edit')
     */
    @api mode = 'create';

    /**
     * @description Submit button label
     */
    @api submitButtonLabel = 'Create Case';

    /**
     * @description Whether to show progress bar
     */
    @api showProgressBar = true;

    /**
     * @description Current step ID
     */
    currentStepId = STEPS.CALLER;

    /**
     * @description Whether wizard is submitting
     */
    isSubmitting = false;

    /**
     * @description Validation messages
     */
    validationMessages = [];

    /**
     * @description Wizard data (accumulated from all phases)
     */
    wizardData = {
        // Phase 1: Caller
        entityType: '',
        locationId: '',
        vendorId: '',
        clientId: '',
        contactId: '',

        // Phase 2: Intent
        assetId: '',
        recordTypeId: '',
        caseType: '',
        caseSubType: '',
        caseReason: '',

        // Phase 3: Details
        purchaseOrderNumber: '',
        overridePOCreateTask: false,
        profileNumber: '',
        overrideProfileNumberTask: false,
        psi: '',
        psiOverrideReason: '',
        psiComments: '',
        serviceDate: '',
        slaServiceDateTime: '',

        // Phase 4: Work Order (optional)
        siteContact: '',
        siteContactPhone: '',
        workOrderInstructions: '',
        byPassWorkOrder: false,

        // Additional fields
        origin: 'Web',
        subject: '',
        description: '',
        priority: 'Medium'
    };

    /**
     * @description Wizard steps configuration
     */
    wizardSteps = [
        {
            id: STEPS.CALLER,
            label: 'Caller',
            isComplete: false
        },
        {
            id: STEPS.INTENT,
            label: 'Intent',
            isComplete: false
        },
        {
            id: STEPS.DETAILS,
            label: 'Details',
            isComplete: false
        },
        {
            id: STEPS.REVIEW,
            label: 'Review',
            isComplete: false
        }
    ];

    /**
     * @description Computed property - whether step navigation is allowed
     */
    get allowStepNavigation() {
        return true; // Allow navigation to completed steps
    }

    /**
     * @description Computed property - whether there are validation messages
     */
    get hasValidationMessages() {
        return this.validationMessages && this.validationMessages.length > 0;
    }

    /**
     * @description Computed property - is caller phase
     */
    get isCallerPhase() {
        return this.currentStepId === STEPS.CALLER;
    }

    /**
     * @description Computed property - is intent phase
     */
    get isIntentPhase() {
        return this.currentStepId === STEPS.INTENT;
    }

    /**
     * @description Computed property - is details phase
     */
    get isDetailsPhase() {
        return this.currentStepId === STEPS.DETAILS;
    }

    /**
     * @description Computed property - is review phase
     */
    get isReviewPhase() {
        return this.currentStepId === STEPS.REVIEW;
    }

    /**
     * @description Computed property - is first step
     */
    get isFirstStep() {
        return this.currentStepId === STEPS.CALLER;
    }

    /**
     * @description Computed property - is last step
     */
    get isLastStep() {
        return this.currentStepId === STEPS.REVIEW;
    }

    /**
     * @description Handle step change from progress indicator
     * @param {Event} event - Step change event
     */
    handleStepChange(event) {
        const newStepId = event.detail.stepId;

        // Only allow navigation to completed steps
        const stepIndex = this.wizardSteps.findIndex(s => s.id === newStepId);
        const step = this.wizardSteps[stepIndex];

        if (step.isComplete || newStepId === this.currentStepId) {
            this.currentStepId = newStepId;
            this.clearValidationMessages();
        }
    }

    /**
     * @description Handle previous button click
     */
    handlePrevious() {
        const currentIndex = this.wizardSteps.findIndex(s => s.id === this.currentStepId);
        if (currentIndex > 0) {
            this.currentStepId = this.wizardSteps[currentIndex - 1].id;
            this.clearValidationMessages();
        }
    }

    /**
     * @description Handle next button click
     */
    async handleNext() {
        // Validate current phase
        const isValid = await this.validateCurrentPhase();

        if (isValid) {
            // Mark current step as complete
            this.markStepComplete(this.currentStepId);

            // Move to next step
            const currentIndex = this.wizardSteps.findIndex(s => s.id === this.currentStepId);
            if (currentIndex < this.wizardSteps.length - 1) {
                this.currentStepId = this.wizardSteps[currentIndex + 1].id;
                this.clearValidationMessages();
            }
        }
    }

    /**
     * @description Handle submit button click
     */
    async handleSubmit() {
        // Validate review phase
        const isValid = await this.validateCurrentPhase();

        if (isValid) {
            this.isSubmitting = true;

            try {
                let result;

                if (this.mode === 'create') {
                    // Create new case
                    result = await createCaseFromWizard({
                        wizardDataJson: JSON.stringify(this.wizardData)
                    });
                } else {
                    // Update existing case
                    result = await updateCaseFromWizard({
                        caseId: this.recordId,
                        wizardDataJson: JSON.stringify(this.wizardData)
                    });
                }

                if (result.success) {
                    // Show success message
                    this.showToast('Success', result.messages.join(', '), 'success');

                    // Dispatch success event to parent
                    this.dispatchEvent(new CustomEvent('success', {
                        detail: {
                            caseId: result.caseId,
                            caseNumber: result.caseNumber
                        }
                    }));

                    // Navigate to case record (if available)
                    if (result.caseId) {
                        this.navigateToCase(result.caseId);
                    }
                } else {
                    // Show error messages
                    this.validationMessages = result.messages.map((msg, index) => ({
                        id: `error-${index}`,
                        type: 'error',
                        message: msg
                    }));

                    this.showToast('Error', result.errorDetails || 'Failed to create case', 'error');
                }
            } catch (error) {
                console.error('Submit error:', error);
                this.showToast('Error', error.body?.message || 'An unexpected error occurred', 'error');
            } finally {
                this.isSubmitting = false;
            }
        }
    }

    /**
     * @description Validate current phase
     * @returns {Promise<Boolean>} Whether phase is valid
     */
    async validateCurrentPhase() {
        this.clearValidationMessages();

        try {
            // Map step ID to phase name for service
            const phaseMap = {
                [STEPS.CALLER]: 'CALLER',
                [STEPS.INTENT]: 'INTENT',
                [STEPS.DETAILS]: 'DETAILS',
                [STEPS.REVIEW]: 'REVIEW'
            };

            const phaseName = phaseMap[this.currentStepId];

            const result = await validatePhase({
                phase: phaseName,
                wizardDataJson: JSON.stringify(this.wizardData)
            });

            if (!result.isValid) {
                // Show validation messages
                this.validationMessages = result.messages.map((msg, index) => ({
                    id: `validation-${index}`,
                    type: 'error',
                    message: msg
                }));

                // Scroll to top to show messages
                window.scrollTo({ top: 0, behavior: 'smooth' });

                return false;
            }

            return true;
        } catch (error) {
            console.error('Validation error:', error);
            this.showToast('Validation Error', error.body?.message || 'Failed to validate phase', 'error');
            return false;
        }
    }

    /**
     * @description Mark a step as complete
     * @param {String} stepId - Step ID to mark complete
     */
    markStepComplete(stepId) {
        this.wizardSteps = this.wizardSteps.map(step => {
            if (step.id === stepId) {
                return { ...step, isComplete: true };
            }
            return step;
        });
    }

    /**
     * @description Clear validation messages
     */
    clearValidationMessages() {
        this.validationMessages = [];
    }

    /**
     * @description Handle close message event
     * @param {Event} event - Close message event
     */
    handleCloseMessage(event) {
        const messageId = event.detail.messageId;
        this.validationMessages = this.validationMessages.filter(msg => msg.id !== messageId);
    }

    /**
     * @description Show toast notification
     * @param {String} title - Toast title
     * @param {String} message - Toast message
     * @param {String} variant - Toast variant (success|error|warning|info)
     */
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }

    /**
     * @description Navigate to case record
     * @param {String} caseId - Case ID to navigate to
     */
    navigateToCase(caseId) {
        // Dispatch navigation event to parent
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: {
                caseId: caseId
            }
        }));
    }

    /**
     * @description Public API to update wizard data
     * @param {String} field - Field name
     * @param {*} value - Field value
     */
    @api
    updateWizardData(field, value) {
        this.wizardData = {
            ...this.wizardData,
            [field]: value
        };
    }

    /**
     * @description Public API to get wizard data
     * @returns {Object} Wizard data object
     */
    @api
    getWizardData() {
        return { ...this.wizardData };
    }

    /**
     * @description Public API to reset wizard
     */
    @api
    resetWizard() {
        this.currentStepId = STEPS.CALLER;
        this.wizardSteps = this.wizardSteps.map(step => ({
            ...step,
            isComplete: false
        }));
        this.wizardData = {
            entityType: '',
            locationId: '',
            vendorId: '',
            clientId: '',
            contactId: '',
            assetId: '',
            recordTypeId: '',
            caseType: '',
            caseSubType: '',
            caseReason: '',
            purchaseOrderNumber: '',
            overridePOCreateTask: false,
            profileNumber: '',
            overrideProfileNumberTask: false,
            psi: '',
            psiOverrideReason: '',
            psiComments: '',
            serviceDate: '',
            slaServiceDateTime: '',
            siteContact: '',
            siteContactPhone: '',
            workOrderInstructions: '',
            byPassWorkOrder: false,
            origin: 'Web',
            subject: '',
            description: '',
            priority: 'Medium'
        };
        this.clearValidationMessages();
    }
}
