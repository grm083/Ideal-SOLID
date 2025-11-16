import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publish, MessageContext } from 'lightning/messageService';
import SET_SERVICE_DATE_CHANNEL from '@salesforce/messageChannel/SetServiceDate__c';
import createMultipleCasesInvoke from '@salesforce/apex/CaseController.createMultipleCasesInvoke';

export default class CustomCalendarLWC extends LightningElement {
    @api recordId;
    @api servicedate = '';
    @api parentId;

    @track showModal = false;
    @track loadingSpinner = false;
    @track notReturn = false;
    @track createAMPMPickups = false;
    @track selectedDates = [];
    @track newDate = '';

    connectedCallback() {
        // Initialize with service date if provided
        if (this.servicedate) {
            this.selectedDates = [this.servicedate];
        }
    }

    handleNotReturnChange(event) {
        this.notReturn = event.target.checked;
    }

    handleAMPMChange(event) {
        this.createAMPMPickups = event.target.checked;
    }

    handleNewDateChange(event) {
        this.newDate = event.target.value;
    }

    handleAddDate() {
        if (this.newDate) {
            // Check if date already exists
            if (!this.selectedDates.includes(this.newDate)) {
                this.selectedDates = [...this.selectedDates, this.newDate];
                this.newDate = '';
            } else {
                this.showToast('Warning', 'This date has already been added', 'warning');
            }
        } else {
            this.showToast('Warning', 'Please select a date first', 'warning');
        }
    }

    handleRemoveDate(event) {
        const dateToRemove = event.target.dataset.date;
        this.selectedDates = this.selectedDates.filter(date => date !== dateToRemove);
    }

    async handleCopyCase() {
        this.loadingSpinner = true;

        try {
            // Filter out the original service date from selected dates
            let datesToCreate = this.selectedDates.filter(date => date !== this.servicedate);

            // Validate that we have dates to create OR AM/PM is checked
            if (datesToCreate.length === 0 && !this.createAMPMPickups) {
                this.showToast('Warning', 'Please select a date in future or past from Service Date.', 'warning');
                this.loadingSpinner = false;
                this.showModal = false;
                return;
            }

            // Call Apex to create multiple cases
            const result = await createMultipleCasesInvoke({
                selectedDueDateStr: datesToCreate,
                caseRecId: this.recordId,
                doNotReturn: this.notReturn,
                Create_AM_PM_Pickup: this.createAMPMPickups
            });

            if (result.success) {
                this.showToast('Success', 'Cases created successfully', 'success');

                // Check for duplicates
                if (result.dupList && result.dupList.length > 0) {
                    // Fire event to show duplicate check component
                    this.dispatchEvent(new CustomEvent('duplicatefound', {
                        detail: {
                            workorders: result.dupList,
                            caseList: result.childCases
                        }
                    }));
                } else {
                    // No duplicates, close modal
                    this.handleClose();
                }

                // Publish LMS message if parentId exists
                if (this.parentId && this.parentId !== 'undefined' && this.parentId !== null && this.parentId !== '') {
                    const payload = { caseId: this.parentId };
                    publish(this.messageContext, SET_SERVICE_DATE_CHANNEL, payload);
                }

                // Dispatch refresh event
                this.dispatchEvent(new CustomEvent('refresh'));

            } else {
                this.showToast('Error', result.message || 'Failed to create cases', 'error');
            }

        } catch (error) {
            console.error('Error creating cases:', error);
            this.showToast('Error', 'An error occurred while creating cases', 'error');
        } finally {
            this.loadingSpinner = false;
        }
    }

    handleClose() {
        this.showModal = false;
        this.dispatchEvent(new CustomEvent('close'));
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get hasSelectedDates() {
        return this.selectedDates.length > 0;
    }

    get selectedDatesWithIndex() {
        return this.selectedDates.map((date, index) => ({
            date: date,
            index: index,
            isServiceDate: date === this.servicedate
        }));
    }
}
