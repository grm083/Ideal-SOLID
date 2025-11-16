import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import ShowExistingQuotes from '@salesforce/apex/GetCaseInformation.ShowExistingQuotes';
import getAddProductId from '@salesforce/apex/GetCaseInformation.getAddProductId';
import createOppQuote from '@salesforce/apex/GetCaseInformation.createOppQuote';
import updateThisCaseToClose from '@salesforce/apex/GetCaseInformation.updateThisCaseToClose';

export default class ExistingQuoteModalLWC extends NavigationMixin(LightningElement) {
    @api recordId;

    @track quotesWrapper = [];
    @track showSpinner = false;
    @track existingQuoteModal = true;
    @track addFavoriteContainerModal = false;

    connectedCallback() {
        this.loadExistingQuotes();
    }

    async loadExistingQuotes() {
        this.showSpinner = true;

        try {
            const result = await ShowExistingQuotes({ CaseId: this.recordId });
            console.log('Existing quotes received:', result);

            if (result && result.length > 0) {
                this.quotesWrapper = result;
            }

            this.showSpinner = false;

        } catch (error) {
            console.error('Error loading existing quotes:', error);
            this.showSpinner = false;
        }
    }

    async handleAddQuote() {
        this.showSpinner = true;

        try {
            // Get add product ID
            const addId = await getAddProductId();

            // Create opportunity/quote
            const quoteID = await createOppQuote({ CaseId: this.recordId });

            // Close modal
            this.handleCloseExistingQuotes();

            // Navigate to quote
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: quoteID,
                    actionName: 'view'
                }
            });

            this.showSpinner = false;

        } catch (error) {
            console.error('Error adding quote:', error);
            let message = 'Unknown error';
            if (error && error.body && error.body.message) {
                message = error.body.message;
            }
            this.showToast('Error', 'Case Creation Error: ' + message, 'error');
            this.showSpinner = false;
        }
    }

    async handleCloseCase() {
        this.showSpinner = true;

        try {
            const closedStatus = await updateThisCaseToClose({ CaseId: this.recordId });

            if (closedStatus) {
                console.log('Case has been closed.');
                this.showToast('Success', 'Case closed successfully', 'success');
            }

            this.showSpinner = false;
            this.handleCloseExistingQuotes();

        } catch (error) {
            console.error('Error closing case:', error);
            this.showToast('Error', 'Failed to close case', 'error');
            this.showSpinner = false;
        }
    }

    handleCloseExistingQuotes() {
        this.existingQuoteModal = false;

        // Fire event to parent
        this.dispatchEvent(new CustomEvent('closemodal', {
            detail: { showQuoteModal: false }
        }));
    }

    handleNavigate(event) {
        const recordId = event.currentTarget.dataset.value;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    actionName: 'view'
                }
            });
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

    get hasQuotes() {
        return this.quotesWrapper && this.quotesWrapper.length > 0;
    }

    get allProducts() {
        // Flatten the quotesWrapper to get all configured products
        let products = [];
        if (this.quotesWrapper) {
            this.quotesWrapper.forEach(item => {
                if (item.configuredProducts) {
                    item.configuredProducts.forEach(product => {
                        products.push(product);
                    });
                }
            });
        }
        return products;
    }
}
