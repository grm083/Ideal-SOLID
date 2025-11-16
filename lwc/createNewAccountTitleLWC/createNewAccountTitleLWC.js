import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import newTitle from '@salesforce/apex/ContactSearchandCreate.newTitle';

export default class CreateNewAccountTitleLWC extends LightningElement {
    @api accountId;
    @api accountTitle;

    titleVal = '';
    newTitleId = '';
    isLoading = false;

    handleInputChange(event) {
        this.titleVal = event.target.value;
    }

    closeModal() {
        // Dispatch close event to parent
        const closeEvent = new CustomEvent('close');
        this.dispatchEvent(closeEvent);
    }

    async handleSave() {
        // Validate input
        const inputField = this.template.querySelector('lightning-input');
        if (!inputField.reportValidity()) {
            return;
        }

        if (!this.titleVal || this.titleVal.trim() === '') {
            this.showToast('Error', 'Please enter a title', 'error');
            return;
        }

        try {
            this.isLoading = true;

            // Call Apex to create new title
            this.newTitleId = await newTitle({
                acct: this.accountId,
                title: this.titleVal
            });

            // Dispatch success event to parent with new title data
            const saveEvent = new CustomEvent('save', {
                detail: {
                    titleId: this.newTitleId,
                    titleName: this.titleVal
                }
            });
            this.dispatchEvent(saveEvent);

            this.showToast('Success', 'Account Title created successfully', 'success');

            // Close modal after successful save
            this.closeModal();

        } catch (error) {
            console.error('Error creating account title:', error);
            this.showToast('Error', error.body?.message || 'Error creating account title', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}
