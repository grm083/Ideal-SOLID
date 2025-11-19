import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getServiceDateInfo from '@salesforce/apex/ServiceDateController.getServiceDateInfo';
import updateServiceDate from '@salesforce/apex/ServiceDateController.updateServiceDate';
import updateMultiCalendarChecked from '@salesforce/apex/ServiceDateController.updateMultiCalendarChecked';
import isWMCapacityPlannerVisible from '@salesforce/apex/ServiceDateController.isWMCapacityPlannerVisible';
import isMultiCalendarVisible from '@salesforce/apex/ServiceDateController.isMultiCalendarVisible';
import calculateSLADateTime from '@salesforce/apex/ServiceDateController.calculateSLADateTime';

export default class ServiceDateSelector extends LightningElement {
    @api caseId;
    @track serviceDate = '';
    @track serviceTime = '08:00';
    @track isMultiCalendarChecked = false;
    @track showWMCapacityPlanner = false;
    @track showMultiCalendar = false;
    @track isLoading = false;

    connectedCallback() {
        if (this.caseId) {
            this.loadData();
        }
    }

    get minDate() {
        return new Date().toISOString().split('T')[0];
    }

    get isSaveDisabled() {
        return this.isLoading || !this.serviceDate;
    }

    handleServiceDateChange(event) {
        this.serviceDate = event.detail.value;
    }

    handleServiceTimeChange(event) {
        this.serviceTime = event.detail.value;
    }

    handleMultiCalendarChange(event) {
        this.isMultiCalendarChecked = event.detail.checked;
    }

    handleReset(event) {
        event.preventDefault();
        this.loadData();
    }

    handleSave(event) {
        event.preventDefault();
        if (!this.serviceDate) {
            this.showError('Service date is required');
            return;
        }
        this.saveServiceDate();
    }

    loadData() {
        this.loadServiceDateInfo();
        this.loadVisibilityFlags();
    }

    loadServiceDateInfo() {
        if (!this.caseId) return;
        this.isLoading = true;
        getServiceDateInfo({ caseId: this.caseId })
            .then(result => {
                this.serviceDate = result.serviceDate || '';
                this.isMultiCalendarChecked = result.isMultiCalendarChecked || false;
                if (result.slaServiceDateTime) {
                    const dt = new Date(result.slaServiceDateTime);
                    this.serviceTime = dt.toTimeString().substr(0, 5);
                }
            })
            .catch(error => {
                this.showError('Failed to load service date: ' + this.getErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    loadVisibilityFlags() {
        if (!this.caseId) return;
        isWMCapacityPlannerVisible({ caseId: this.caseId })
            .then(result => {
                this.showWMCapacityPlanner = result;
            })
            .catch(error => {
                console.error('WM Capacity check failed:', error);
            });

        isMultiCalendarVisible({ caseId: this.caseId })
            .then(result => {
                this.showMultiCalendar = result.isVisible;
            })
            .catch(error => {
                console.error('Multi-calendar check failed:', error);
            });
    }

    saveServiceDate() {
        this.isLoading = true;
        const serviceDate = this.serviceDate ? new Date(this.serviceDate) : null;

        calculateSLADateTime({
            serviceDate: serviceDate,
            serviceTime: this.serviceTime
        })
        .then(slaDateTime => {
            return updateServiceDate({
                caseId: this.caseId,
                serviceDate: serviceDate,
                slaServiceDateTime: slaDateTime
            });
        })
        .then(() => {
            if (this.showMultiCalendar) {
                return updateMultiCalendarChecked({
                    caseId: this.caseId,
                    isChecked: this.isMultiCalendarChecked
                });
            }
        })
        .then(() => {
            this.showSuccess('Service date saved successfully');
            this.dispatchEvent(new CustomEvent('servicedatechange', {
                detail: { serviceDate: this.serviceDate, serviceTime: this.serviceTime }
            }));
        })
        .catch(error => {
            this.showError('Failed to save service date: ' + this.getErrorMessage(error));
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    showError(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        }));
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success'
        }));
    }

    getErrorMessage(error) {
        if (!error) return 'Unknown error';
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }

    @api
    refresh() {
        this.loadData();
    }
}
