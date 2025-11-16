/**
 * Case Data Governor Component
 *
 * This component acts as the central data management hub for Case record pages.
 * It loads all case data in a single Apex call and publishes it via Lightning Message Service
 * to subscribing child components, eliminating redundant Apex calls and improving performance.
 *
 * Key Features:
 * - Single source of truth for case page data
 * - Publishes data via Lightning Message Service (LMS)
 * - Handles refresh requests from child components
 * - Manages loading and error states
 * - Reduces governor limits through consolidated queries
 *
 * Usage:
 * - Add this component to Case record page layouts
 * - Child components subscribe to CaseDataChannel LMS to receive data
 * - Child components can request targeted refreshes via custom events
 */
import { LightningElement, api, wire, track } from 'lwc';
import { publish, subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import CASE_DATA_CHANNEL from '@salesforce/messageChannel/CaseDataChannel__c';
import getCasePageData from '@salesforce/apex/CaseDataGovernorService.getCasePageData';
import refreshPageSection from '@salesforce/apex/CaseDataGovernorService.refreshPageSection';

export default class CaseDataGovernorLWC extends LightningElement {
    // ========================================================================
    // PUBLIC PROPERTIES
    // ========================================================================

    @api recordId; // Case ID from record page context

    // ========================================================================
    // PRIVATE PROPERTIES
    // ========================================================================

    @track pageData = null;
    @track isLoading = true;
    @track error = null;

    wiredPageDataResult;
    subscription = null;

    // ========================================================================
    // LIFECYCLE HOOKS
    // ========================================================================

    @wire(MessageContext)
    messageContext;

    /**
     * Load case data when component initializes
     */
    connectedCallback() {
        this.loadCaseData();
        this.subscribeToRefreshRequests();
    }

    /**
     * Cleanup subscriptions when component is destroyed
     */
    disconnectedCallback() {
        this.unsubscribeFromRefreshRequests();
    }

    // ========================================================================
    // DATA LOADING METHODS
    // ========================================================================

    /**
     * Load complete case page data from Apex
     */
    async loadCaseData() {
        if (!this.recordId) {
            this.error = 'No Case ID provided';
            this.isLoading = false;
            return;
        }

        this.isLoading = true;
        this.error = null;

        try {
            // Call Apex to get comprehensive case data
            const result = await getCasePageData({
                caseId: this.recordId,
                includeRelated: true,
                includeBusinessRules: true
            });

            if (result.isSuccess) {
                this.pageData = result;
                this.publishPageData('load', result);
            } else {
                this.error = result.errorMessage || 'Error loading case data';
                this.showError(this.error);
            }

        } catch (error) {
            console.error('Error loading case page data:', error);
            this.error = error.body?.message || 'Unknown error loading case data';
            this.showError(this.error);
            this.publishError(this.error);

        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Refresh specific section of page data
     * @param {string} section - Section to refresh (case, contact, asset, etc.)
     */
    async refreshSection(section) {
        if (!this.recordId || !section) {
            return;
        }

        try {
            const result = await refreshPageSection({
                caseId: this.recordId,
                section: section
            });

            if (result.isSuccess) {
                // Update local pageData with refreshed section
                this.updatePageDataSection(section, result);

                // Publish section update
                this.publishPageData('refresh', this.pageData, section);

            } else {
                this.showError(`Error refreshing ${section}: ${result.errorMessage}`);
            }

        } catch (error) {
            console.error(`Error refreshing section ${section}:`, error);
            this.showError(`Error refreshing ${section}`);
        }
    }

    /**
     * Update local pageData with refreshed section data
     */
    updatePageDataSection(section, sectionData) {
        switch (section.toLowerCase()) {
            case 'case':
                this.pageData.caseRecord = sectionData.caseRecord;
                break;
            case 'contact':
                this.pageData.caseContact = sectionData.caseContact;
                break;
            case 'asset':
                this.pageData.caseAsset = sectionData.caseAsset;
                break;
            case 'businessrules':
                this.pageData.businessRules = sectionData.businessRules;
                break;
            case 'ui':
                this.pageData.caseUI = sectionData.caseUI;
                break;
        }
    }

    // ========================================================================
    // LIGHTNING MESSAGE SERVICE (LMS) METHODS
    // ========================================================================

    /**
     * Publish case page data via LMS
     * @param {string} eventType - Type of event (load, refresh, update)
     * @param {object} data - Page data to publish
     * @param {string} section - Optional section being updated
     */
    publishPageData(eventType, data, section = null) {
        const message = {
            caseId: this.recordId,
            eventType: eventType,
            pageData: JSON.stringify(data),
            section: section,
            timestamp: new Date().toISOString()
        };

        publish(this.messageContext, CASE_DATA_CHANNEL, message);
    }

    /**
     * Publish error via LMS
     */
    publishError(errorMessage) {
        const message = {
            caseId: this.recordId,
            eventType: 'error',
            errorMessage: errorMessage,
            timestamp: new Date().toISOString()
        };

        publish(this.messageContext, CASE_DATA_CHANNEL, message);
    }

    /**
     * Subscribe to refresh requests from child components
     */
    subscribeToRefreshRequests() {
        if (this.subscription) {
            return;
        }

        this.subscription = subscribe(
            this.messageContext,
            CASE_DATA_CHANNEL,
            (message) => this.handleRefreshRequest(message)
        );
    }

    /**
     * Unsubscribe from LMS
     */
    unsubscribeFromRefreshRequests() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    /**
     * Handle refresh requests from child components
     */
    handleRefreshRequest(message) {
        // Only handle requests for this case
        if (message.caseId !== this.recordId) {
            return;
        }

        // Handle different request types
        switch (message.eventType) {
            case 'refresh':
                if (message.section) {
                    this.refreshSection(message.section);
                } else {
                    this.loadCaseData();
                }
                break;
            case 'reload':
                this.loadCaseData();
                break;
        }
    }

    // ========================================================================
    // EVENT HANDLERS
    // ========================================================================

    /**
     * Handle manual refresh button click (for debugging/admin)
     */
    handleRefresh() {
        this.loadCaseData();
    }

    // ========================================================================
    // UTILITY METHODS
    // ========================================================================

    /**
     * Show error toast notification
     */
    showError(message) {
        const event = new ShowToastEvent({
            title: 'Error Loading Case Data',
            message: message,
            variant: 'error',
            mode: 'sticky'
        });
        this.dispatchEvent(event);
    }

    /**
     * Show success toast notification
     */
    showSuccess(message) {
        const event = new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success'
        });
        this.dispatchEvent(event);
    }

    // ========================================================================
    // GETTERS FOR TEMPLATE
    // ========================================================================

    get hasData() {
        return this.pageData !== null;
    }

    get hasError() {
        return this.error !== null;
    }

    get caseNumber() {
        return this.pageData?.caseRecord?.CaseNumber || '';
    }

    get loadedAt() {
        if (this.pageData?.loadedAt) {
            return new Date(this.pageData.loadedAt).toLocaleTimeString();
        }
        return '';
    }
}
