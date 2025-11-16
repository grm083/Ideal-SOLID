import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';

// Import Apex method
import getCaseHighlightDetails from '@salesforce/apex/CustomCaseHighlightPanelCntrl.getCaseHighlightDetails';
import getCapacityEligibility from '@salesforce/apex/CustomCaseHighlightPanelCntrl.getCapacityEligibilty';
import getQueueName from '@salesforce/apex/CustomCaseHighlightPanelCntrl.getQueueName';

// Import Case fields
import CASE_ID from '@salesforce/schema/Case.Id';
import CASE_NUMBER from '@salesforce/schema/Case.CaseNumber';
import CASE_STATUS from '@salesforce/schema/Case.Status';

const CASE_FIELDS = [CASE_ID, CASE_NUMBER, CASE_STATUS];

/**
 * CustomCaseHighlightPanel - LWC component for case highlight panel
 * Converted from Aura component: aura/CustomCaseHighlightPanel
 *
 * @description Master orchestrator component that serves as the case management control center.
 * Displays a comprehensive 2-table layout showing all key case fields with clickable actions
 * to open various modal components for editing different aspects of the case.
 *
 * This component is one of the largest in the codebase (352 lines in Aura) and integrates
 * with ALL the other components we've converted:
 * - LocationContainer, VendorContainer, ClientContainer
 * - ShowAssetHeadersOnCase
 * - SearchExistingContact
 * - ServiceDateContainer
 * - FillCaseSubType
 * - SetCaseCustomerInfo
 * - CloseCasePop
 * - CaseNavigation
 * - changeRecordType
 * - HoverOverCards (for hover tooltips)
 *
 * Features:
 * - Two-row table layout with 20+ fields
 * - Conditional column headers based on case type/status
 * - Clickable field headers that open modals for editing
 * - Color-coding (actionColor, blankColor, capacityColor)
 * - Hover cards for Asset, Location, and Contact
 * - Queue name lookup
 * - Capacity eligibility check
 * - Business rule integration for New Service cases
 * - Task status highlighting
 *
 * NOTE: Full conversion requires all child components to be available as LWC.
 * This version provides the structure and integration points.
 */
export default class CustomCaseHighlightPanel extends NavigationMixin(LightningElement) {
    // Public properties
    @api recordId;

    // Case details
    @track caseDetails = {};
    @track isLoading = true;

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

    // Wire case record
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    caseRecord;

    // Computed properties
    get caseStatus() {
        return getFieldValue(this.caseRecord.data, CASE_STATUS);
    }

    // Lifecycle Hooks
    async connectedCallback() {
        await this.loadCaseDetails();
        await this.checkCapacityEligibility();
    }

    // Data Loading Methods
    async loadCaseDetails() {
        this.isLoading = true;
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
        } finally {
            this.isLoading = false;
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

        // Default to Location
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
        await this.loadCaseDetails();
        await this.checkCapacityEligibility();
        await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
    }

    // Hover Handlers
    handleAssetMouseEnter() {
        this.showAssetHover = true;
    }

    handleAssetMouseLeave() {
        this.showAssetHover = false;
    }

    handleLocationMouseEnter() {
        this.showLocationHover = true;
    }

    handleLocationMouseLeave() {
        this.showLocationHover = false;
    }

    handleContactMouseEnter() {
        this.showContactHover = true;
    }

    handleContactMouseLeave() {
        this.showContactHover = false;
    }
}
