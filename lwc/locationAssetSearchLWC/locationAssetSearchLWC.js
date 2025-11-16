import { LightningElement, api } from 'lwc';

export default class LocationAssetSearchLWC extends LightningElement {
    @api recordId;

    connectedCallback() {
        console.log('locationAssetSearchLWC loaded with recordId:', this.recordId);
        // TODO: Implement full conversion from Aura component
    }
}
