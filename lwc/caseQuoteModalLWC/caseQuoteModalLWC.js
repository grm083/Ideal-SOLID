import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getCaseQuotes from '@salesforce/apex/QuoteProcurementController.getCaseQuotes';

export default class CaseQuoteModalLWC extends NavigationMixin(LightningElement) {
    @api recordId;

    @track productWrapper = [];
    @track showSpinner = false;
    @track showModal = false;

    connectedCallback() {
        this.loadCaseQuotes();
    }

    async loadCaseQuotes() {
        this.showSpinner = true;

        try {
            const result = await getCaseQuotes({ CaseId: this.recordId });
            console.log('Quote data received:', result);

            if (result && result.length > 0) {
                // Check if has configured products
                if (result[0].configuredProducts && result[0].configuredProducts.length > 0) {
                    this.productWrapper = result;
                    this.showModal = true;
                } else if (result[0].singleQuoteId) {
                    // Single quote without products - navigate to it
                    this.navigateToRecord(result[0].singleQuoteId);
                }
            }

            this.showSpinner = false;

        } catch (error) {
            console.error('Error loading case quotes:', error);
            this.showSpinner = false;
        }
    }

    handleCloseModal() {
        this.showModal = false;

        // Fire event to parent
        this.dispatchEvent(new CustomEvent('closemodal', {
            detail: { showModal: false }
        }));
    }

    handleNavigate(event) {
        const recordId = event.currentTarget.dataset.value;
        if (recordId) {
            this.navigateToRecord(recordId);
        }
    }

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    get hasProducts() {
        return this.productWrapper && this.productWrapper.length > 0;
    }

    get allProducts() {
        // Flatten the productWrapper to get all configured products
        let products = [];
        if (this.productWrapper) {
            this.productWrapper.forEach(quote => {
                if (quote.configuredProducts) {
                    quote.configuredProducts.forEach(product => {
                        products.push(product);
                    });
                }
            });
        }
        return products;
    }
}
