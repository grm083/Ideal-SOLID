import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFavorites from '@salesforce/apex/QuoteProcurementController.getFavorites';
import getAddProductId from '@salesforce/apex/QuoteProcurementController.getAddProductId';
import addQuoteAndQuoteine from '@salesforce/apex/QuoteProcurementController.addQuoteAndQuoteine';
import addQuoteAsProductNotListed from '@salesforce/apex/QuoteProcurementController.addQuoteAsProductNotListed';

export default class AddFavoriteContainersLWC extends NavigationMixin(LightningElement) {
    @api showForm = false;
    @api caseId;
    @api quoteId = '';
    @api quoteScreen = false;

    @track quotesWrapper;
    @track selectedProduct = 'Please Select Any Product';
    @track containerDetailsList = [];
    @track favoriteId;
    @track productId;
    @track showSpinner = false;

    columns = [
        { label: 'Size', fieldName: 'equipmentSize', type: 'text' },
        { label: 'Material Type', fieldName: 'materialType', type: 'text' }
    ];

    connectedCallback() {
        this.loadFavorites();
    }

    async loadFavorites() {
        this.showSpinner = true;

        try {
            // Load favorites
            const data = await getFavorites();
            console.log('Data length:', data ? data.length : 0);

            if (data) {
                this.quotesWrapper = data;

                // Get add product ID
                const prodId = await getAddProductId();
                this.productId = prodId;
                console.log('prodId:', prodId);

                this.showSpinner = false;
            } else {
                this.showToast('Error', 'No Data In Favorites.', 'error');
                console.log('No Data');
                this.showSpinner = false;
            }

        } catch (error) {
            console.error('Error loading favorites:', error);
            this.showToast('Error', 'Failed to load favorites', 'error');
            this.showSpinner = false;
        }
    }

    handleCloseFavoriteContainerModal() {
        this.showForm = false;

        // Fire event to parent
        this.dispatchEvent(new CustomEvent('closemodal', {
            detail: { AddFavroiteContainerModal: false }
        }));
    }

    async handleAddFavoriteProductToQuote() {
        if (!this.favoriteId || this.favoriteId === 'undefined' || this.favoriteId === null) {
            this.showToast('Validation Error', 'Please Select Product Record First.', 'error');
            return;
        }

        this.showSpinner = true;

        try {
            const quoteResponse = await addQuoteAndQuoteine({
                caseId: this.caseId,
                favroiteId: this.favoriteId,
                quoteScreen: this.quoteScreen,
                quoteID: this.quoteId
            });

            if (quoteResponse && quoteResponse.length > 0) {
                this.showForm = false;

                // Navigate to quote
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: quoteResponse,
                        objectApiName: 'SBQQ__Quote__c',
                        actionName: 'view'
                    }
                });

                this.showSpinner = false;
            } else {
                this.showToast('Validation Error', 'Apex Failure', 'error');
                this.showSpinner = false;
            }

        } catch (error) {
            console.error('Error adding product to quote:', error);
            this.showToast('Error', 'Apex Failure', 'error');
            this.showSpinner = false;
        }
    }

    async handleAddProductNotListed() {
        console.log('quoteScreen:', this.quoteScreen);

        if (this.quoteScreen) {
            try {
                const addId = await getAddProductId();
                console.log('addId:', addId);

                // Navigate to VF page for product lookup
                const url = `/apex/sbqq__sb?scontrolCaching=1&id=${this.quoteId}#/product/lookup?qId=${this.quoteId}&aId=${addId}`;
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: {
                        url: url
                    }
                });

                this.showForm = false;

            } catch (error) {
                console.error('Error getting add product ID:', error);
                this.showToast('Error', 'Failed to get product ID', 'error');
            }
        } else {
            this.productNotListed();
        }
    }

    async productNotListed() {
        console.log('Print2');
        this.showSpinner = true;

        try {
            const quoteID = await addQuoteAsProductNotListed({ CaseId: this.caseId });
            console.log('state: SUCCESS');

            // Navigate to VF page for product lookup
            const url = `/apex/sbqq__sb?scontrolCaching=1&id=${quoteID}#/product/lookup?qId=${quoteID}&aId=${this.productId}`;
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: url
                }
            });

            this.showSpinner = false;

        } catch (error) {
            console.error('Error adding product not listed:', error);
            this.showToast('Error', 'Failed to add product', 'error');
            this.showSpinner = false;
        }
    }

    handleSelectProduct(event) {
        this.containerDetailsList = [];
        const containerItem = JSON.parse(event.currentTarget.dataset.item);
        this.selectedProduct = containerItem.productName;
        console.log('containerItem.listcontainerDetails:', JSON.stringify(containerItem.listcontainerDetails));
        this.containerDetailsList = containerItem.listcontainerDetails || [];
    }

    handleRowSelection(event) {
        this.favoriteId = '';
        const selectedRows = event.detail.selectedRows;

        if (selectedRows && selectedRows.length > 0) {
            const rowId = selectedRows[0].FavoriteID;
            if (typeof rowId !== 'undefined') {
                this.favoriteId = rowId;
            }
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissible'
        });
        this.dispatchEvent(event);
    }

    get hasContainerList() {
        return this.quotesWrapper && this.quotesWrapper.ContainerList && this.quotesWrapper.ContainerList.length > 0;
    }

    get isProductSelected() {
        return this.selectedProduct !== 'Please Select Any Product';
    }

    get hasContainerDetails() {
        return this.containerDetailsList && this.containerDetailsList.length > 0;
    }
}
