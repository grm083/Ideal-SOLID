import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import LOCATION_FIELD from '@salesforce/schema/Case.Location__c';

const LOCATION_FIELDS = [
    'Account.Location_Code__c',
    'Account.ParentId',
    'Account.ShippingAddress',
    'Account.Customer_Location_Code__c',
    'Account.Phone',
    'Account.Primary_Segment__c',
    'Account.Status__c',
    'Account.tz__Local_Time_Short__c'
];

export default class CaseLocationDetailsLWC extends LightningElement {
    @api recordId; // Case ID

    locationId;
    fields = LOCATION_FIELDS;

    @wire(getRecord, { recordId: '$recordId', fields: [LOCATION_FIELD] })
    caseRecord({ error, data }) {
        if (data) {
            this.locationId = getFieldValue(data, LOCATION_FIELD);
        } else if (error) {
            console.error('Error loading case:', error);
        }
    }

    get hasLocation() {
        return this.locationId != null;
    }

    get noLocationMessage() {
        return 'Please select your location using the "Location Search" tab';
    }
}
