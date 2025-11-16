import { LightningElement, api } from 'lwc';

export default class CaseQuoteModalLWC extends LightningElement {
    @api recordId;

    connectedCallback() {
        console.log('caseQuoteModalLWC loaded with recordId:', this.recordId);
        // TODO: Implement full conversion from Aura component
    }
}
