import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publish, MessageContext } from 'lightning/messageService';
import SET_SERVICE_DATE_CHANNEL from '@salesforce/messageChannel/SetServiceDate__c';

// TODO: WMCapacityController Apex class needs to be created with these methods:
// - getAcornBaseline(Id caseId)
// - getSLADate(Id caseId)
// - getAvailableDates(String baseline)
// - updateCase(Id caseId, String serviceDate)
import getAcornBaseline from '@salesforce/apex/WMCapacityController.getAcornBaseline';
import getSLADate from '@salesforce/apex/WMCapacityController.getSLADate';
import getAvailableDates from '@salesforce/apex/WMCapacityController.getAvailableDates';
import updateCase from '@salesforce/apex/WMCapacityController.updateCase';

export default class WmCapacityLWC extends LightningElement {
    @api recordId;
    @api parentId;

    @track slaDate = '';
    @track baseline = '';
    @track selectedDate = '';
    @track availDates = [];
    @track boolDisplay = true;
    @track loaded = true;
    @track loadingSpinner = false;
    @track isDateAvailable = false;

    // Wire message context for LMS
    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.initializeComponent();
    }

    async initializeComponent() {
        try {
            await this.loadAcornBaseline();
        } catch (error) {
            console.error('Error initializing WM Capacity:', error);
            this.showToast('Error', 'Failed to load WM Capacity data', 'error');
            this.boolDisplay = false;
            this.loaded = false;
        }
    }

    async loadAcornBaseline() {
        try {
            // Get Acorn baseline
            this.baseline = await getAcornBaseline({ caseId: this.recordId });
            console.log('Baseline is', this.baseline);

            // Get SLA Date
            this.slaDate = await getSLADate({ caseId: this.recordId });
            console.log('SLA Date is', this.slaDate);

            // Get available dates
            const results = await getAvailableDates({ baseline: this.baseline });
            console.log('Available dates:', results);

            if (results && results.length > 0) {
                this.loaded = false;
                this.availDates = results;
                this.isDateAvailable = true;
            } else {
                this.boolDisplay = false;
                this.loaded = false;
            }
        } catch (error) {
            console.error('Error loading capacity data:', error);
            this.boolDisplay = false;
            this.loaded = false;
            throw error;
        }
    }

    handleDateSelection(event) {
        this.loadingSpinner = true;
        this.selectedDate = event.target.dataset.date;
        console.log('Selected date:', this.selectedDate);

        if (this.selectedDate) {
            this.loaded = true;
            this.performUpdateCase();
        } else {
            this.showToast('Warning', 'You must select a date prior to pressing save', 'warning');
            this.loadingSpinner = false;
        }
    }

    async performUpdateCase() {
        try {
            await updateCase({
                caseId: this.recordId,
                serviceDate: this.selectedDate
            });

            // Publish message if parentId exists
            if (this.parentId && this.parentId !== 'undefined' && this.parentId !== null && this.parentId !== '') {
                const payload = { caseId: this.parentId };
                publish(this.messageContext, SET_SERVICE_DATE_CHANNEL, payload);
            }

            this.loadingSpinner = false;
            this.loaded = false;

            // Fire refresh event
            this.dispatchEvent(new CustomEvent('refresh'));

            // Fire case updated event
            this.dispatchEvent(new CustomEvent('caseupdated', {
                detail: { caseId: this.recordId }
            }));

            this.showToast('Success', 'Service date updated successfully', 'success');

            // Close/destroy component
            this.dispatchEvent(new CustomEvent('close'));

        } catch (error) {
            console.error('Error updating case:', error);
            this.showToast('Error', 'Failed to update service date', 'error');
            this.loadingSpinner = false;
            this.loaded = false;
        }
    }

    handleDateNotListed() {
        this.loadingSpinner = true;

        // Fire event to open SetCaseSLA component
        this.dispatchEvent(new CustomEvent('opensla', {
            detail: {
                isOpenSLAComp: true,
                isAvailDate: this.isDateAvailable
            }
        }));
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get formattedSLADate() {
        return this.slaDate || '';
    }

    get showAvailableDates() {
        return this.boolDisplay && !this.loaded && this.availDates.length > 0;
    }

    get showNoAvailabilityMessage() {
        return !this.boolDisplay && !this.loaded;
    }

    get showLoadingSpinner() {
        return this.loaded;
    }
}
