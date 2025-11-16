import { LightningElement, api } from 'lwc';

export default class ExistingQuoteModalLWC extends LightningElement {
    @api recordId;

    connectedCallback() {
        console.log('existingQuoteModalLWC loaded with recordId:', this.recordId);
        // TODO: Implement full conversion from Aura component
    }
}
