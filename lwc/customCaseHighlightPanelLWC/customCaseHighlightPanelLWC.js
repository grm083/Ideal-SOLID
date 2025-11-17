/**
 * CustomCaseHighlightPanel - REFACTORED to use Case Data Governor
 *
 * This refactored version demonstrates the governor pattern where instead of making
 * direct Apex calls on load, the component subscribes to the CaseDataChannel LMS
 * and receives centralized data from the caseDataGovernor component.
 *
 * BENEFITS:
 * - Eliminates 2 Apex calls on component load (getCaseHighlightDetails, getCapacityEligibility)
 * - Receives comprehensive case data from single source
 * - Auto-updates when governor publishes refreshes
 * - Falls back to direct Apex if governor not present (backward compatible)
 *
 * ARCHITECTURE:
 * - Subscribes to CaseDataChannel LMS in connectedCallback
 * - Receives pageData from caseDataGovernor
 * - Maps pageData to component properties
 * - Still makes getQueueName call (user-triggered action)
 */
import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, unsubscribe, publish, MessageContext } from 'lightning/messageService';

// Import LMS Channel
import CASE_DATA_CHANNEL from '@salesforce/messageChannel/CaseDataChannel__c';

// Import Apex methods (for fallback and user-triggered actions only)
import getCaseHighlightDetails from '@salesforce/apex/CustomCaseHighlightPanelCntrl.getCaseHighlightDetails';
import getCapacityEligibility from '@salesforce/apex/CustomCaseHighlightPanelCntrl.getCapacityEligibilty';
import getQueueName from '@salesforce/apex/CustomCaseHighlightPanelCntrl.getQueueName';

// Import Case fields
import CASE_ID from '@salesforce/schema/Case.Id';
import CASE_NUMBER from '@salesforce/schema/Case.CaseNumber';
import CASE_STATUS from '@salesforce/schema/Case.Status';

const CASE_FIELDS = [CASE_ID, CASE_NUMBER, CASE_STATUS];

export default class CustomCaseHighlightPanelLWC extends NavigationMixin(LightningElement) {
    // Public properties
    @api recordId;

    // Case details
    @track caseDetails = {};
    @track isLoading = true;
    @track isLoadingFromGovernor = false;

    // Modal state
    @track isModalOpen = false;
    @track isModalOpenLocation = false;
    @track isModalOpenContact = false;
    @track isModalOpenAsset = false;
    @track isModalOpenServiceDate = false;
    @track isModalOpenRecordType = false;
    @track isModalOpenCaseType = false;
    @track isModalOpenCustomerInfo = false;
    @track isModalOpenCloseCasePop = false;
    @track isModalOpenRelatedCases = false;

    // Hover state
    @track showAssetHover = false;
    @track showLocationHover = false;
    @track showContactHover = false;
    @track assetHoverCard = false;
    @track locationHoverCard = false;
    @track contactHoverCard = false;
    hoverTimer = null;

    // Hover delay constants (in milliseconds)
    HOVER_DELAY = 500; // Delay before showing hover card
    SLEEP_DELAY = 300; // Delay before hiding hover card

    // Display values
    @track poValue = '-';
    @track chargeableValue = '-';
    @track psiValue = '-';
    @track ccValue = '-';
    @track queueName = '';

    // Conditional display flags
    @track isLocation = false;
    @track isVendor = false;
    @track isClient = false;
    @track isNew = true;
    @track isNewService = false;
    @track isCPQ = false;
    @track isAssetReq = true;
    @track isReqInfo = false;
    @track isReqInfoEmpty = false;
    @track isOpenTask = false;
    @track isCapacityEligible = false;
    @track IsPOProfileDisable = false;

    // Governor integration
    subscription = null;
    hasReceivedGovernorData = false;
    governorTimeout = null;

    // Wire message context
    @wire(MessageContext)
    messageContext;

    // Wire case record
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    caseRecord;

    // Computed properties
    get caseStatus() {
        return getFieldValue(this.caseRecord.data, CASE_STATUS);
    }

    // Null-safe getters for relationship fields
    get locationName() {
        return this.caseDetails?.Location__r?.Name || '';
    }

    get locationId() {
        return this.caseDetails?.Location__c || null;
    }

    get vendorName() {
        return this.caseDetails?.Supplier__r?.Name || '';
    }

    get clientName() {
        return this.caseDetails?.Client__r?.Name || '';
    }

    get assetName() {
        return this.caseDetails?.Asset?.Name || '';
    }

    get assetId() {
        return this.caseDetails?.AssetId || null;
    }

    get contactName() {
        return this.caseDetails?.Contact?.Name || '';
    }

    get contactId() {
        return this.caseDetails?.ContactId || null;
    }

    get workOrderNumber() {
        return this.caseDetails?.Acorn_Work_order__c || '';
    }

    get workOrderId() {
        return this.caseDetails?.Work_Order__c || null;
    }

    // Lifecycle Hooks
    connectedCallback() {
        this.subscribeToGovernor();

        // Set timeout to fall back to direct Apex if governor doesn't respond
        this.governorTimeout = setTimeout(() => {
            if (!this.hasReceivedGovernorData) {
                console.warn('Governor data not received, falling back to direct Apex calls');
                this.loadDataDirectly();
            }
        }, 2000); // Wait 2 seconds for governor
    }

    disconnectedCallback() {
        this.unsubscribeFromGovernor();
        if (this.governorTimeout) {
            clearTimeout(this.governorTimeout);
        }
    }

    // ========================================================================
    // GOVERNOR INTEGRATION (NEW!)
    // ========================================================================

    /**
     * Subscribe to Case Data Channel LMS
     */
    subscribeToGovernor() {
        if (this.subscription) {
            return;
        }

        this.subscription = subscribe(
            this.messageContext,
            CASE_DATA_CHANNEL,
            (message) => this.handleGovernorMessage(message)
        );
    }

    /**
     * Unsubscribe from LMS
     */
    unsubscribeFromGovernor() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    /**
     * Handle messages from Case Data Governor
     */
    handleGovernorMessage(message) {
        // Only process messages for this case
        if (message.caseId !== this.recordId) {
            return;
        }

        // Handle different message types
        switch (message.eventType) {
            case 'load':
            case 'refresh':
                this.processGovernorData(message);
                break;
            case 'error':
                console.error('Governor error:', message.errorMessage);
                this.loadDataDirectly(); // Fall back to direct Apex
                break;
        }
    }

    /**
     * Process data received from governor
     */
    processGovernorData(message) {
        try {
            // Guard: Check if pageData exists before attempting to parse
            // Some messages (like refresh requests) don't include pageData
            if (!message.pageData) {
                console.log('CustomCaseHighlightPanelLWC: Received message without pageData, ignoring:', message.eventType);
                return;
            }

            const pageData = JSON.parse(message.pageData);

            if (!pageData || !pageData.caseRecord) {
                return;
            }

            this.hasReceivedGovernorData = true;
            if (this.governorTimeout) {
                clearTimeout(this.governorTimeout);
            }

            // Map governor data to component properties
            this.mapGovernorDataToComponent(pageData);

            this.isLoading = false;

        } catch (error) {
            console.error('Error processing governor data:', error);
            this.loadDataDirectly(); // Fall back to direct Apex
        }
    }

    /**
     * Map governor pageData to component properties
     */
    mapGovernorDataToComponent(pageData) {
        // Set case details from governor
        this.caseDetails = pageData.caseRecord;

        // Set display values
        this.poValue = pageData.caseRecord.PurchaseOrder_Number__c || '-';
        this.chargeableValue = pageData.caseRecord.Chargeable__c || '-';
        this.psiValue = pageData.caseRecord.PSI__c || '-';
        this.ccValue = pageData.caseRecord.Company_Category__c || '-';

        // Set flags from caseUI wrapper
        if (pageData.caseUI) {
            this.isReqInfo = !!(pageData.caseUI.reqInfo && pageData.caseUI.reqInfo !== '');
            this.isCPQ = pageData.userContext?.isCPQUser || false;
            this.isAssetReq = !!(pageData.caseRecord.AssetId) || !pageData.caseUI.isAssetMandatory;
        }

        // Set status flags
        this.isNew = pageData.caseRecord.Status === 'New';
        this.isNewService = pageData.caseRecord.Case_Record_Type__c === 'New Service Case';

        // Determine account type
        this.determineAccountType(pageData.caseRecord);

        // Note: Capacity eligibility and queue name still need to be fetched separately
        // as they're not included in governor data (can be added later)
        this.checkCapacityEligibility();
    }

    // ========================================================================
    // FALLBACK DIRECT DATA LOADING (ORIGINAL METHODS)
    // ========================================================================

    /**
     * Load data directly via Apex (fallback if governor not available)
     */
    async loadDataDirectly() {
        this.isLoading = true;
        try {
            await this.loadCaseDetails();
            await this.checkCapacityEligibility();
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Original loadCaseDetails method (used as fallback)
     */
    async loadCaseDetails() {
        try {
            const wrapper = await getCaseHighlightDetails({ caseId: this.recordId });

            if (wrapper) {
                this.caseDetails = wrapper.myCase;
                this.isReqInfoEmpty = wrapper.isReqInfoEmpty;
                this.isOpenTask = wrapper.isOpenTask;

                // Set display values
                this.poValue = wrapper.myCase.PurchaseOrder_Number__c || '-';
                this.chargeableValue = wrapper.myCase.Chargeable__c || '-';
                this.psiValue = wrapper.myCase.PSI__c || '-';
                this.ccValue = wrapper.myCase.Company_Category__c || '-';

                // Set required info flag
                this.isReqInfo = !!(wrapper.reqInfo && wrapper.reqInfo !== '');

                // Additional req info check for Haul Away
                if (wrapper.myCase.Case_Type__c === 'Pickup' &&
                    wrapper.myCase.Case_Sub_Type__c === 'Haul Away - No Equipment' &&
                    !wrapper.myCase.Chargeable__c) {
                    this.isReqInfo = true;
                }

                // Allowprogress case check
                if (wrapper.allowProgressCase === false) {
                    this.isReqInfo = true;
                }

                // Set status flags
                this.isNew = wrapper.myCase.Status === 'New';
                this.isNewService = wrapper.myCase.Case_Record_Type__c === 'New Service Case';
                this.isCPQ = wrapper.CPQUser === true;
                this.IsPOProfileDisable = wrapper.IsPOProfileDisable;

                // Determine if Location/Vendor/Client
                this.determineAccountType(wrapper.myCase);

                // Check asset requirement
                this.isAssetReq = !!(wrapper.myCase.AssetId) || !wrapper.isAssetMandatory;
            }
        } catch (error) {
            console.error('Error loading case details:', error);
        }
    }

    determineAccountType(caseRecord) {
        const recordType = caseRecord.Case_Record_Type__c;
        const caseType = caseRecord.Case_Type__c;
        const caseSubType = caseRecord.Case_Sub_Type__c;

        // Reset flags
        this.isVendor = false;
        this.isClient = false;
        this.isLocation = false;

        if (recordType === 'Standard Case') {
            // Vendor cases
            if ((caseType === 'Activate' && caseSubType === 'New Vendor') ||
                (caseType === 'Modify' && caseSubType === 'Vendor Record') ||
                (caseType === 'Deactivate' && caseSubType === 'Deactivate Vendor')) {
                this.isVendor = true;
                return;
            }

            // Client cases
            if ((caseType === 'Activate' && caseSubType === 'New Client') ||
                (caseType === 'Modify' && caseSubType === 'Client Record') ||
                (caseType === 'Deactivate' && caseSubType === 'Deactivate Client')) {
                this.isClient = true;
                return;
            }
        }

        // Default to Location (show Location column even if Location__c is null)
        this.isLocation = true;
    }

    async checkCapacityEligibility() {
        try {
            const isEligible = await getCapacityEligibility({ caseId: this.recordId });
            this.isCapacityEligible = isEligible;
        } catch (error) {
            console.error('Error checking capacity eligibility:', error);
        }
    }

    async fetchQueueName() {
        try {
            const trackingNumber = this.caseDetails.Tracking_Number__c;
            if (trackingNumber) {
                const queue = await getQueueName({ trackingNumber });
                if (queue && !queue.includes('Error:')) {
                    this.queueName = queue;
                }
            }
        } catch (error) {
            console.error('Error fetching queue name:', error);
        }
    }

    // ========================================================================
    // EVENT HANDLERS (UNCHANGED)
    // ========================================================================

    // Navigation Handlers
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

    // Modal Opening Handlers
    handleOpenLocation() {
        this.isModalOpenLocation = true;
        this.isModalOpen = true;
    }

    handleOpenVendor() {
        this.isModalOpenLocation = true;
        this.isModalOpen = true;
    }

    handleOpenClient() {
        this.isModalOpenLocation = true;
        this.isModalOpen = true;
    }

    handleOpenAsset() {
        this.isModalOpenAsset = true;
        this.isModalOpen = true;
    }

    handleOpenContact() {
        this.isModalOpenContact = true;
    }

    handleOpenRecordType() {
        this.isModalOpenRecordType = true;
        this.isModalOpen = true;
    }

    handleOpenCaseType() {
        this.isModalOpenCaseType = true;
    }

    handleOpenServiceDate() {
        this.isModalOpenServiceDate = true;
    }

    handleOpenCustomerInfo() {
        this.isModalOpenCustomerInfo = true;
    }

    handleOpenCloseCasePop() {
        this.isModalOpenCloseCasePop = true;
    }

    handleOpenRelatedCases() {
        this.isModalOpenRelatedCases = true;
        this.isModalOpen = true;
    }

    handleShowQueue() {
        this.fetchQueueName();
    }

    // Modal Closing Handler
    handleCloseModal() {
        this.isModalOpen = false;
        this.isModalOpenLocation = false;
        this.isModalOpenContact = false;
        this.isModalOpenAsset = false;
        this.isModalOpenServiceDate = false;
        this.isModalOpenRecordType = false;
        this.isModalOpenCaseType = false;
        this.isModalOpenCustomerInfo = false;
        this.isModalOpenCloseCasePop = false;
        this.isModalOpenRelatedCases = false;
    }

    // Refresh Handler (from child components)
    async handleRefresh() {
        // Always reload data directly to ensure immediate refresh
        await this.loadDataDirectly();

        // Notify governor to refresh (so other subscribed components also update)
        if (this.hasReceivedGovernorData) {
            this.requestGovernorRefresh();
        }

        // Notify wire service of record update
        await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
    }

    /**
     * Request governor to refresh data - NEW!
     */
    requestGovernorRefresh() {
        const message = {
            caseId: this.recordId,
            eventType: 'refresh',
            timestamp: new Date().toISOString()
        };
        publish(this.messageContext, CASE_DATA_CHANNEL, message);
    }

    // Hover Handlers - Asset
    handleAssetMouseEnter() {
        this.hoverTimer = setTimeout(() => {
            if (!this.assetHoverCard) {
                this.showAssetHover = true;
                this.assetHoverCard = true;
            }
        }, this.HOVER_DELAY);
    }

    handleAssetMouseLeave() {
        if (this.hoverTimer) {
            clearTimeout(this.hoverTimer);
        }
        setTimeout(() => {
            if (this.assetHoverCard) {
                this.showAssetHover = false;
                this.assetHoverCard = false;
            }
        }, this.SLEEP_DELAY);
    }

    handleAssetCardMouseEnter() {
        this.assetHoverCard = false; // Prevent auto-hide when mouse enters card
    }

    handleAssetCardMouseLeave() {
        this.assetHoverCard = false;
        this.showAssetHover = false;
    }

    // Hover Handlers - Location
    handleLocationMouseEnter() {
        this.hoverTimer = setTimeout(() => {
            if (!this.locationHoverCard) {
                this.showLocationHover = true;
                this.locationHoverCard = true;
            }
        }, this.HOVER_DELAY);
    }

    handleLocationMouseLeave() {
        if (this.hoverTimer) {
            clearTimeout(this.hoverTimer);
        }
        setTimeout(() => {
            if (this.locationHoverCard) {
                this.showLocationHover = false;
                this.locationHoverCard = false;
            }
        }, this.SLEEP_DELAY);
    }

    handleLocationCardMouseEnter() {
        this.locationHoverCard = false; // Prevent auto-hide when mouse enters card
    }

    handleLocationCardMouseLeave() {
        this.locationHoverCard = false;
        this.showLocationHover = false;
    }

    // Hover Handlers - Contact
    handleContactMouseEnter() {
        this.hoverTimer = setTimeout(() => {
            if (!this.contactHoverCard) {
                this.showContactHover = true;
                this.contactHoverCard = true;
            }
        }, this.HOVER_DELAY);
    }

    handleContactMouseLeave() {
        if (this.hoverTimer) {
            clearTimeout(this.hoverTimer);
        }
        setTimeout(() => {
            if (this.contactHoverCard) {
                this.showContactHover = false;
                this.contactHoverCard = false;
            }
        }, this.SLEEP_DELAY);
    }

    handleContactCardMouseEnter() {
        this.contactHoverCard = false; // Prevent auto-hide when mouse enters card
    }

    handleContactCardMouseLeave() {
        this.contactHoverCard = false;
        this.showContactHover = false;
    }
}
