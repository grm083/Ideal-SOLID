/**
 * @description Progress Indicator / Wizard Stepper Component
 * Displays a visual progress indicator for multi-step wizards
 * Used in the case management wizard to show user's progress
 *
 * @property {Array} steps - Array of step objects
 * @property {String} currentStep - ID of the current active step
 * @property {String} variant - Visual variant (base|shade)
 * @property {Boolean} allowNavigation - Whether clicking steps navigates
 * @property {Boolean} showProgressBar - Whether to show progress bar below steps
 */
import { LightningElement, api } from 'lwc';

export default class ProgressIndicator extends LightningElement {
    /**
     * @description Array of step objects
     * Each step should have: { id, label, isComplete }
     */
    @api steps = [];

    /**
     * @description ID of the currently active step
     */
    @api currentStep = '';

    /**
     * @description Visual variant
     * Options: base (default), shade
     */
    @api variant = 'base';

    /**
     * @description Whether clicking on steps allows navigation
     */
    @api allowNavigation = true;

    /**
     * @description Whether to show progress bar below steps
     */
    @api showProgressBar = true;

    /**
     * @description Computed array of steps with status classes
     */
    get stepsWithStatus() {
        if (!this.steps || this.steps.length === 0) {
            return [];
        }

        const currentIndex = this.steps.findIndex(step => step.id === this.currentStep);

        return this.steps.map((step, index) => {
            const isActive = step.id === this.currentStep;
            const isCompleted = step.isComplete || index < currentIndex;
            const isPending = !isActive && !isCompleted;
            const isClickable = this.allowNavigation && (isCompleted || isActive);

            // Build CSS class for list item
            let liClass = 'slds-progress__item';
            if (isCompleted) {
                liClass += ' slds-is-completed';
            } else if (isActive) {
                liClass += ' slds-is-active';
            }

            // Status text for accessibility
            let statusText = '';
            if (isCompleted) {
                statusText = 'Completed';
            } else if (isActive) {
                statusText = 'Active';
            } else {
                statusText = 'Pending';
            }

            return {
                ...step,
                liClass,
                isActive,
                isCompleted,
                isPending,
                isClickable,
                statusText
            };
        });
    }

    /**
     * @description Computed progress percentage
     */
    get progressPercentage() {
        if (!this.steps || this.steps.length === 0) {
            return 0;
        }

        const currentIndex = this.steps.findIndex(step => step.id === this.currentStep);
        if (currentIndex === -1) {
            return 0;
        }

        // Calculate percentage based on current step
        // Add 1 to currentIndex because we're counting completed steps including current
        const percentage = ((currentIndex + 1) / this.steps.length) * 100;
        return Math.round(percentage);
    }

    /**
     * @description Inline style for progress bar width
     */
    get progressBarStyle() {
        return `width: ${this.progressPercentage}%`;
    }

    /**
     * @description Handle step click event
     * @param {Event} event - Click event
     */
    handleStepClick(event) {
        event.preventDefault();

        if (!this.allowNavigation) {
            return;
        }

        const stepId = event.currentTarget.dataset.step;

        // Only allow navigation to completed steps or current step
        const step = this.stepsWithStatus.find(s => s.id === stepId);
        if (step && (step.isCompleted || step.isActive)) {
            // Dispatch event to parent component
            this.dispatchEvent(new CustomEvent('stepchange', {
                detail: {
                    stepId: stepId,
                    previousStepId: this.currentStep
                }
            }));
        }
    }

    /**
     * @description Public API to mark a step as complete
     * @param {String} stepId - ID of step to mark complete
     */
    @api
    markStepComplete(stepId) {
        const step = this.steps.find(s => s.id === stepId);
        if (step) {
            step.isComplete = true;
            // Force re-render by creating new array reference
            this.steps = [...this.steps];
        }
    }

    /**
     * @description Public API to mark a step as incomplete
     * @param {String} stepId - ID of step to mark incomplete
     */
    @api
    markStepIncomplete(stepId) {
        const step = this.steps.find(s => s.id === stepId);
        if (step) {
            step.isComplete = false;
            // Force re-render by creating new array reference
            this.steps = [...this.steps];
        }
    }

    /**
     * @description Public API to go to next step
     */
    @api
    nextStep() {
        if (!this.steps || this.steps.length === 0) {
            return;
        }

        const currentIndex = this.steps.findIndex(step => step.id === this.currentStep);
        if (currentIndex === -1 || currentIndex === this.steps.length - 1) {
            // Already at last step or current step not found
            return;
        }

        // Mark current step as complete
        this.markStepComplete(this.currentStep);

        // Move to next step
        const nextStep = this.steps[currentIndex + 1];
        this.currentStep = nextStep.id;

        // Dispatch event
        this.dispatchEvent(new CustomEvent('stepchange', {
            detail: {
                stepId: nextStep.id,
                previousStepId: this.steps[currentIndex].id
            }
        }));
    }

    /**
     * @description Public API to go to previous step
     */
    @api
    previousStep() {
        if (!this.steps || this.steps.length === 0) {
            return;
        }

        const currentIndex = this.steps.findIndex(step => step.id === this.currentStep);
        if (currentIndex === -1 || currentIndex === 0) {
            // Already at first step or current step not found
            return;
        }

        // Move to previous step
        const prevStep = this.steps[currentIndex - 1];
        this.currentStep = prevStep.id;

        // Dispatch event
        this.dispatchEvent(new CustomEvent('stepchange', {
            detail: {
                stepId: prevStep.id,
                previousStepId: this.steps[currentIndex].id
            }
        }));
    }

    /**
     * @description Public API to go to a specific step
     * @param {String} stepId - ID of step to navigate to
     */
    @api
    goToStep(stepId) {
        const step = this.steps.find(s => s.id === stepId);
        if (!step) {
            return;
        }

        const previousStepId = this.currentStep;
        this.currentStep = stepId;

        // Dispatch event
        this.dispatchEvent(new CustomEvent('stepchange', {
            detail: {
                stepId: stepId,
                previousStepId: previousStepId
            }
        }));
    }

    /**
     * @description Public API to reset all steps to incomplete
     */
    @api
    resetSteps() {
        this.steps = this.steps.map(step => ({
            ...step,
            isComplete: false
        }));

        // Go back to first step
        if (this.steps.length > 0) {
            this.currentStep = this.steps[0].id;
        }
    }
}
