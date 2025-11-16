import { LightningElement, api } from 'lwc';

export default class WmCapacityLWC extends LightningElement {
    @api recordId;

    connectedCallback() {
        console.log('wmCapacityLWC loaded with recordId:', this.recordId);
        // TODO: Implement full conversion from Aura component
    }
}
