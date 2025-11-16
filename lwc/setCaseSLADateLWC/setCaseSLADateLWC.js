import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publish, MessageContext } from 'lightning/messageService';
import SET_SERVICE_DATE_CHANNEL from '@salesforce/messageChannel/SetServiceDate__c';

// Import Apex methods
import getRecordTypeId from '@salesforce/apex/GetCaseInformation.getRecordTypeId';
import insertPlannerComment from '@salesforce/apex/GetCaseInformation.insertPlannerComment';

// Import Case fields
import SLA_SERVICE_DATETIME_FIELD from '@salesforce/schema/Case.SLA_Service_DateTime__c';
import SERVICE_DATE_FIELD from '@salesforce/schema/Case.Service_Date__c';

const CASE_FIELDS = [SLA_SERVICE_DATETIME_FIELD, SERVICE_DATE_FIELD];

export default class SetCaseSLADateLWC extends LightningElement {
    @api recordId;
    @api showForm = false;
    @api parentId;
    @api isCapacityEligible = false;
    @api isAvailDate = false;
    @api isDateNotListedCl = false;

    @track recordTypeId;
    @track loading = false;
    @track errorMessage = '';

    // Wire message context for LMS
    @wire(MessageContext)
    messageContext;

    // Wire case record to get current values
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    caseRecord;

    connectedCallback() {
        this.loadRecordType();
    }

    async loadRecordType() {
        try {
            this.recordTypeId = await getRecordTypeId({ caseId: this.recordId });
        } catch (error) {
            console.error('Error loading record type:', error);
        }
    }

    handleSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;

        // Add Availability_Checked__c if WM Capacity eligible
        if (this.isCapacityEligible) {
            fields.Availability_Checked__c = true;
        }

        // Validate the form
        if (this.validateForm(fields)) {
            this.loading = true;
            this.submitForm(fields);
        }
    }

    validateForm(fields) {
        this.errorMessage = '';

        const currentDate = new Date();
        const todayDateGMT = `${currentDate.getFullYear()}-${currentDate.getMonth() + 1}-${currentDate.getDate()} 00:00:00 GMT`;
        const todayDate = this.addMinutesToDate(new Date(todayDateGMT), new Date(todayDateGMT).getTimezoneOffset());

        // Get service date
        const serviceDateGMT = `${fields.Service_Date__c} 00:00:00 GMT`;
        const serviceDate = this.addMinutesToDate(new Date(serviceDateGMT), new Date(serviceDateGMT).getTimezoneOffset());

        // Get SLA service date from current record
        const slaSrvDateTimeValue = getFieldValue(this.caseRecord.data, SLA_SERVICE_DATETIME_FIELD);
        if (slaSrvDateTimeValue) {
            const getDateValuefromSLA = slaSrvDateTimeValue.substring(0, 10);
            const slaServiceDate = new Date(getDateValuefromSLA);

            // Validate: if service date is less than SLA date and greater than or equal to today
            if (serviceDate.getTime() < slaServiceDate.getTime() && serviceDate.getTime() >= todayDate.getTime()) {
                const slaOverrideReason = fields.SLA_Override_Reason__c;
                const slaOverrideComment = fields.SLA_Override_Comment__c;

                if (!slaOverrideReason || !slaOverrideComment || slaOverrideComment === '' || slaOverrideReason === '') {
                    this.errorMessage = 'Please fill SLA Override Reason and SLA Override Comment';
                    return false;
                }
            }
        }

        return true;
    }

    submitForm(fields) {
        const recordInput = { fields };
        this.template.querySelector('lightning-record-edit-form').submit(fields);

        // If date not listed, insert planner comment
        if (this.isDateNotListedCl) {
            this.insertComment();
        }
    }

    async insertComment() {
        try {
            await insertPlannerComment({
                caseId: this.recordId,
                selectedDate: '',
                isAvailDates: this.isAvailDate,
                isDateNotListed: this.isDateNotListedCl
            });
            console.log('Inserted planner comment');
        } catch (error) {
            console.error('Error inserting comment:', error);
        }
    }

    handleSuccess() {
        this.loading = false;

        // Publish message if parentId exists
        if (this.parentId && this.parentId !== 'undefined' && this.parentId !== null && this.parentId !== '') {
            const payload = { caseId: this.parentId };
            publish(this.messageContext, SET_SERVICE_DATE_CHANNEL, payload);
        }

        // Close form and refresh
        this.showForm = false;

        // Notify record update
        notifyRecordUpdateAvailable([{ recordId: this.recordId }]);

        // Dispatch refresh event
        this.dispatchEvent(new CustomEvent('refresh'));

        // Dispatch case updated event
        this.dispatchEvent(new CustomEvent('caseupdated', {
            detail: { caseId: this.recordId }
        }));

        this.showToast('Success', 'SLA Service Date updated successfully', 'success');
    }

    handleError(event) {
        this.loading = false;
        this.errorMessage = event.detail.message || 'An error occurred while saving';
        console.error('Form error:', event.detail);
    }

    addMinutesToDate(date, minutes) {
        return new Date(date.getTime() + minutes * 60000);
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get hasError() {
        return this.errorMessage !== '';
    }
}
