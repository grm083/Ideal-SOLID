import { LightningElement, api, track } from 'lwc';
import evaluateBusinessRules from '@salesforce/apex/BusinessRuleValidatorController.evaluateBusinessRules';

export default class BusinessRuleValidator extends LightningElement {
    @api caseId;
    @track businessRules = {};
    @track allMessages = [];

    connectedCallback() {
        if (this.caseId) {
            this.evaluateRules();
        }
    }

    get hasBusinessRules() {
        return this.businessRules && Object.keys(this.businessRules).length > 0;
    }

    get hasMessages() {
        return this.allMessages.length > 0;
    }

    get poIcon() {
        return this.businessRules.isPORequired ? 'utility:check' : 'utility:close';
    }

    get poVariant() {
        return this.businessRules.isPORequired ? 'success' : 'error';
    }

    get profileIcon() {
        return this.businessRules.isProfileNumberRequired ? 'utility:check' : 'utility:close';
    }

    get profileVariant() {
        return this.businessRules.isProfileNumberRequired ? 'success' : 'error';
    }

    get psiIcon() {
        return this.businessRules.isPSIRequired ? 'utility:check' : 'utility:close';
    }

    get psiVariant() {
        return this.businessRules.isPSIRequired ? 'success' : 'error';
    }

    evaluateRules() {
        evaluateBusinessRules({ caseId: this.caseId })
            .then(result => {
                this.businessRules = result;
                this.allMessages = [
                    ...(result.errors || []).map(msg => ({ id: 'err_' + Math.random(), message: msg, variant: 'error' })),
                    ...(result.warnings || []).map(msg => ({ id: 'warn_' + Math.random(), message: msg, variant: 'warning' })),
                    ...(result.messages || []).map(msg => ({ id: 'info_' + Math.random(), message: msg, variant: 'info' }))
                ];
            })
            .catch(error => {
                console.error('Failed to evaluate business rules:', error);
            });
    }

    @api
    refresh() {
        this.evaluateRules();
    }
}
