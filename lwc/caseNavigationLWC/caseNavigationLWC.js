import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

// Import Apex method
import getRelatedCase from '@salesforce/apex/TaskPopUpMessageController.getRelatedCase';

/**
 * CaseNavigation - LWC component for displaying related cases
 * Converted from Aura component: aura/CaseNavigation
 *
 * @description Displays a table of related cases based on Reference_Number__c.
 * Shows cases that share the same reference number as the current case.
 * Supports navigation to related case records by clicking case number.
 */
export default class CaseNavigationLWC extends NavigationMixin(LightningElement) {
    // Public properties
    @api recordId;

    // Private properties
    @track caseLst = [];
    @track error;
    @track isLoading = true;

    // Lifecycle Hooks
    async connectedCallback() {
        await this.loadRelatedCases();
    }

    // Data Loading Methods
    async loadRelatedCases() {
        this.isLoading = true;
        try {
            const cases = await getRelatedCase({ recordId: this.recordId });
            this.caseLst = cases || [];
            this.error = undefined;
        } catch (error) {
            this.error = error;
            this.caseLst = [];
            console.error('Error loading related cases:', error);
        } finally {
            this.isLoading = false;
        }
    }

    // Computed properties
    get hasCases() {
        return this.caseLst && this.caseLst.length > 0;
    }

    get showNoRecordsMessage() {
        return !this.isLoading && !this.hasCases;
    }

    // Navigation Handler
    handleNavigateToCase(event) {
        event.preventDefault();
        const caseId = event.currentTarget.dataset.id;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: caseId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }
}
