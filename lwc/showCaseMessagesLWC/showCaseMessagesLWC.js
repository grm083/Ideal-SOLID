/**
 * ShowCaseMessagesLWC - Case Action Required Panel
 *
 * Displays case validation messages, action-required notifications, and provides
 * quick actions for case management (quotes, work orders, case summary, etc.)
 *
 * ARCHITECTURE - DUAL SUBSCRIPTION PATTERN:
 * ==========================================
 * This component uses a dual Lightning Message Service (LMS) subscription pattern:
 *
 * 1. CaseDataChannel (from CaseDataGovernor)
 *    - Purpose: Centralized case data distribution
 *    - Provides: Case UI state, related records, business rules
 *    - Benefit: Eliminates redundant Apex calls, improves governor limits
 *    - Replaces: Direct getCaseMessages Apex call
 *
 * 2. LMS Channel (legacy)
 *    - Purpose: Action/event notifications (multi-asset case actions)
 *    - Provides: User action signals, workflow triggers
 *    - Benefit: Component communication for workflows
 *
 * DATA LOADING STRATEGY:
 * ======================
 * - Primary: Subscribe to CaseDataGovernor for all case data
 * - Fallback: Direct Apex call if CaseDataGovernor not present (1s timeout)
 * - Refresh: Request data from governor via LMS, not direct Apex
 *
 * This follows the CQRS pattern: CaseDataChannel = queries, LMS = commands
 *
 * @see caseDataGovernorLWC - Centralized data hub
 * @see CaseDataGovernorService - Apex service consolidating data
 * @see GetCaseInformation - Legacy Apex (being replaced by governor pattern)
 */
import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { publish, subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import LMS_CHANNEL from '@salesforce/messageChannel/LMS__c';
import CASE_DATA_CHANNEL from '@salesforce/messageChannel/CaseDataChannel__c';

// Import Apex methods from service layer
import getCaseMessages from '@salesforce/apex/GetCaseInformation.getCaseMessages';
import getCaseSummary from '@salesforce/apex/GetCaseInformation.getCaseSummary';
import getCaseDetails from '@salesforce/apex/GetCaseInformation.getCaseDetails';
import initiateWorkOrder from '@salesforce/apex/GetCaseInformation.initiateWorkOrder';
import addWorkOrderDetails from '@salesforce/apex/GetCaseInformation.addWorkOrderDetails';
import saveAdditionalTemplate from '@salesforce/apex/GetCaseInformation.saveAdditionalTemplate';
import isWMCapacityPlannerVisible from '@salesforce/apex/GetCaseInformation.IsWMCapacityPlannerVisible';
import isTemplateVisible from '@salesforce/apex/GetCaseInformation.IsTemplateVisible';

// Import Case fields
import CASE_ID from '@salesforce/schema/Case.Id';
import CASE_PARENT_ID from '@salesforce/schema/Case.ParentId';
import CASE_NUMBER from '@salesforce/schema/Case.CaseNumber';
import CASE_REFERENCE_NUMBER from '@salesforce/schema/Case.Reference_Number__c';
import CASE_IS_MULTIPLE_ASSET from '@salesforce/schema/Case.Is_Multiple_Asset__c';
import CASE_SHOW_MULTIPLE_ASSET_CASES from '@salesforce/schema/Case.Show_Multiple_Asset_Cases__c';
import CASE_ASSET_ID from '@salesforce/schema/Case.AssetId';
import CASE_SERVICE_DATE from '@salesforce/schema/Case.Service_Date__c';
import CASE_TYPE from '@salesforce/schema/Case.Case_Type__c';
import CASE_SUB_TYPE from '@salesforce/schema/Case.Case_Sub_Type__c';
import CASE_CLIENT from '@salesforce/schema/Case.Client__c';
import CASE_LOCATION from '@salesforce/schema/Case.Location__c';
import CASE_CONTACT_ID from '@salesforce/schema/Case.ContactId';
import CASE_STATUS from '@salesforce/schema/Case.Status';
import CASE_SUB_STATUS from '@salesforce/schema/Case.Case_Sub_Status__c';
import CASE_CONTACT_NAME from '@salesforce/schema/Case.Contact.Name';

const CASE_FIELDS = [
    CASE_ID,
    CASE_PARENT_ID,
    CASE_NUMBER,
    CASE_REFERENCE_NUMBER,
    CASE_IS_MULTIPLE_ASSET,
    CASE_SHOW_MULTIPLE_ASSET_CASES,
    CASE_ASSET_ID,
    CASE_SERVICE_DATE,
    CASE_TYPE,
    CASE_SUB_TYPE,
    CASE_CLIENT,
    CASE_LOCATION,
    CASE_CONTACT_ID,
    CASE_STATUS,
    CASE_SUB_STATUS,
    CASE_CONTACT_NAME
];

export default class ShowCaseMessagesLWC extends NavigationMixin(LightningElement) {
    // Public API
    @api recordId;

    // Wire Message Context for LMS
    @wire(MessageContext)
    messageContext;

    // LMS Channels and Subscriptions
    lmsChannel = LMS_CHANNEL;
    caseDataChannel = CASE_DATA_CHANNEL;
    lmsSubscription = null;
    caseDataSubscription = null;

    // Wire Case Record
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    caseRecord;

    // Tracked Properties - UI State
    @track isLoading = false;
    @track reqInfoMsg = false;
    @track showMsgNTE = false;
    @track displayMsg = false;
    @track displayMultipleAssetCases = false;
    @track isAddCaseAsset = false;
    @track isShowProgressCase = false;
    @track isAddQuote = false;
    @track isOpportunityAdded = false;
    @track disableAddQuote = false;
    @track viewCaseSummary = false;
    @track woInstructions = false;
    @track caseEmailTemp = false;
    @track showModal = false;
    @track showQuoteModal = false;
    @track showFavoriteModal = false;
    @track isCapacityEligible = true;
    @track isTempVisible = false;
    @track initiateWoButton = false;
    @track woUpdatesDisabled = true;

    // Governor integration flag
    hasReceivedGovernorData = false;

    // Case Data
    @track caseMsg = '';
    @track reqInfo = '';
    @track approvalInfo = '';
    @track caseSummary = [];
    @track selectedCases = [];
    @track multiAssetCaseReferenceNo = '';
    @track displaySummary = false;

    // Work Order Form Data
    @track siteContact = '';
    @track siteContactPhone = '';
    @track woInstructionsText = '';
    @track isByPassWO = false;
    @track emailTemplateComments = '';

    // Computed Properties
    get caseStatus() {
        return getFieldValue(this.caseRecord.data, CASE_STATUS);
    }

    get isCaseClosed() {
        return this.caseStatus === 'Closed';
    }

    get actionIconClass() {
        return this.actionReqRed ? 'redicon' : 'greenicon';
    }

    get showViewCaseSummaryButton() {
        return this.displaySummary && !this.isCapacityEligible;
    }

    get viewCaseSummaryLabel() {
        return this.multiAssetCaseReferenceNo ? 'View Multi Asset Case Summary' : 'View Case Summary';
    }

    get caseSummaryTitle() {
        if (this.caseSummary && this.caseSummary.length > 0) {
            return `${this.caseSummary[0].Case_Type__c} Case Summary`;
        }
        return 'Case Summary';
    }

    get caseSummaryContact() {
        if (this.caseSummary && this.caseSummary.length > 0 && this.caseSummary[0].Contact) {
            return this.caseSummary[0].Contact.Name;
        }
        return '';
    }

    get caseSummaryReferenceNo() {
        if (this.caseSummary && this.caseSummary.length > 0) {
            return this.caseSummary[0].Reference_Number__c;
        }
        return '';
    }

    // Lifecycle Hooks
    connectedCallback() {
        this.subscribeToLMSChannel();
        this.subscribeToCaseDataChannel();

        // Request data from CaseDataGovernor (preferred method)
        // If CaseDataGovernor is present on the page, it will respond with data
        this.requestCaseDataRefresh();

        // Fallback: If no response from governor within 1 second, load directly
        // This ensures component works even without CaseDataGovernor
        setTimeout(() => {
            if (!this.hasReceivedGovernorData) {
                console.log('ShowCaseMessagesLWC: Falling back to direct Apex call');
                this.loadCaseMessages();
            }
        }, 1000);

        this.checkCapacityEligibility();
    }

    disconnectedCallback() {
        this.unsubscribeFromLMSChannel();
        this.unsubscribeFromCaseDataChannel();
    }

    // LMS Methods

    /**
     * Subscribe to LMS channel for action/event notifications (multi-asset, etc.)
     */
    subscribeToLMSChannel() {
        if (!this.lmsSubscription) {
            this.lmsSubscription = subscribe(
                this.messageContext,
                LMS_CHANNEL,
                (message) => this.handleLMSMessage(message)
            );
        }
    }

    unsubscribeFromLMSChannel() {
        if (this.lmsSubscription) {
            unsubscribe(this.lmsSubscription);
            this.lmsSubscription = null;
        }
    }

    /**
     * Subscribe to CaseDataChannel for centralized case data from CaseDataGovernor
     */
    subscribeToCaseDataChannel() {
        if (!this.caseDataSubscription) {
            this.caseDataSubscription = subscribe(
                this.messageContext,
                CASE_DATA_CHANNEL,
                (message) => this.handleCaseDataUpdate(message)
            );
        }
    }

    unsubscribeFromCaseDataChannel() {
        if (this.caseDataSubscription) {
            unsubscribe(this.caseDataSubscription);
            this.caseDataSubscription = null;
        }
    }

    /**
     * Handle multi-asset action notifications via LMS
     */
    handleLMSMessage(message) {
        if (message && message.caseId === this.recordId) {
            if (message.enable) {
                const caseData = this.caseRecord.data;
                const status = getFieldValue(caseData, CASE_STATUS);

                if (status === 'New') {
                    this.displayMsg = true;
                    this.displaySummary = true;
                    this.caseMsg = '';
                    this.showMultipleCaseLabel = true;
                    this.showOnRelatedMultiAssetCase = true;

                    if (!this.isCapacityEligible) {
                        this.viewCaseSummaryLabel = 'View Multi Asset Case Summary';
                    }

                    const referenceNo = getFieldValue(caseData, CASE_REFERENCE_NUMBER);
                    this.multiAssetCaseReferenceNo = referenceNo;
                }
            } else if (!message.enable) {
                this.displayMsg = true;
                this.displaySummary = false;
                this.caseMsg = "* Please complete the intake of related cases if any in 'New' status.";
            }
        }
    }

    /**
     * Handle case data updates from CaseDataGovernor
     * This provides centralized case data eliminating multiple Apex calls
     */
    handleCaseDataUpdate(message) {
        // Only process messages for this case
        if (!message || message.caseId !== this.recordId) {
            return;
        }

        // Handle different event types
        switch (message.eventType) {
            case 'load':
            case 'refresh':
            case 'update':
                this.processCaseDataFromGovernor(message);
                break;
            case 'error':
                console.error('CaseDataGovernor error:', message.errorMessage);
                break;
        }
    }

    /**
     * Process case data received from CaseDataGovernor
     */
    processCaseDataFromGovernor(message) {
        try {
            // Guard: Check if pageData exists before attempting to parse
            // Some messages (like refresh requests) don't include pageData
            if (!message.pageData) {
                console.log('ShowCaseMessagesLWC: Received message without pageData, ignoring:', message.eventType);
                return;
            }

            const pageData = JSON.parse(message.pageData);

            // Mark that we've received data from governor
            this.hasReceivedGovernorData = true;

            // Use caseUI data from governor (replaces direct getCaseMessages call)
            if (pageData.caseUI) {
                this.processCaseMessages(pageData.caseUI);
            }

            // Update case record data if available
            if (pageData.caseRecord) {
                // Update local case record reference
                this.caseRecord = {
                    data: pageData.caseRecord,
                    error: null
                };
            }

            // Use related case data if needed
            if (pageData.relatedCases) {
                // Store related cases for potential use
                this.relatedCasesData = pageData.relatedCases;
            }

        } catch (error) {
            console.error('Error processing case data from governor:', error);
        }
    }

    publishMessage(payload) {
        publish(this.messageContext, LMS_CHANNEL, payload);
    }

    /**
     * Request fresh data from CaseDataGovernor
     * This is the preferred way to refresh data (uses centralized governor)
     */
    requestCaseDataRefresh(section = null) {
        const message = {
            caseId: this.recordId,
            eventType: section ? 'refresh' : 'reload',
            section: section,
            requestedBy: 'showCaseMessagesLWC'
        };
        publish(this.messageContext, CASE_DATA_CHANNEL, message);
    }

    // Data Loading Methods
    async loadCaseMessages() {
        try {
            this.isLoading = true;
            const wrapper = await getCaseMessages({ caseId: this.recordId });

            if (wrapper) {
                this.processCaseMessages(wrapper);
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error loading case messages', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    processCaseMessages(wrapper) {
        // Set basic case information
        this.caseMsg = wrapper.caseInfo || '';
        this.reqInfo = wrapper.reqInfo || '';
        this.approvalInfo = wrapper.approvalInfo || '';

        // Set visibility flags
        this.reqInfoMsg = !!wrapper.reqInfo;
        this.showMsgNTE = this.caseMsg.includes('NTE Approval Needed');
        this.displayMsg = wrapper.caseInfo !== '';
        this.displayMultipleAssetCases = wrapper.multiAssetSelections && wrapper.multiAssetSelections.length > 0;
        this.isAddCaseAsset = wrapper.isAddCaseAsset || false;
        this.isShowProgressCase = wrapper.progressCaseVisibility || false;
        this.isAddQuote = wrapper.addQuoteVisibility || false;
        this.isOpportunityAdded = wrapper.isOpportunityCreated || false;
        this.disableAddQuote = false;
        this.displaySummary = wrapper.caseInfo === 'Ready' || wrapper.caseInfo === 'Multi Asset';

        // Set action icon color
        this.actionReqRed = wrapper.caseInfo && wrapper.caseInfo !== 'Ready';

        // Store multi-asset selections
        if (wrapper.multiAssetSelections) {
            this.multiAssetSelections = wrapper.multiAssetSelections;
        }
    }

    async checkCapacityEligibility() {
        try {
            const result = await isWMCapacityPlannerVisible({ caseRecId: this.recordId });
            this.isCapacityEligible = result;
        } catch (error) {
            console.error('Error checking capacity eligibility:', error);
        }
    }

    async checkTemplateVisibility() {
        try {
            const result = await isTemplateVisible({ caseRecId: this.recordId });
            this.isTempVisible = result;
        } catch (error) {
            console.error('Error checking template visibility:', error);
        }
    }

    async loadCaseSummary() {
        try {
            const caseData = this.caseRecord.data;
            const parentId = getFieldValue(caseData, CASE_PARENT_ID);

            const summary = await getCaseSummary({
                caseId: this.recordId,
                referenceNo: this.multiAssetCaseReferenceNo,
                parentId: parentId
            });

            this.caseSummary = summary || [];
            this.populateSelectedCases();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error loading case summary', 'error');
        }
    }

    populateSelectedCases() {
        const selectedCaseIds = [];
        if (this.caseSummary) {
            this.caseSummary.forEach(caseItem => {
                selectedCaseIds.push(caseItem.Id);
            });
        }
        this.selectedCases = selectedCaseIds;
        this.woUpdatesDisabled = selectedCaseIds.length !== 1;
        this.initiateWoButton = false;
    }

    // Event Handlers - Buttons
    async handleShowCaseSummary() {
        this.viewCaseSummary = true;
        await this.loadCaseSummary();
        await this.checkTemplateVisibility();
    }

    handleCloseModal() {
        this.viewCaseSummary = false;
    }

    handleCancelModal() {
        this.woInstructions = false;
        this.caseEmailTemp = false;
        this.clearWorkOrderForm();
    }

    clearWorkOrderForm() {
        this.siteContact = '';
        this.siteContactPhone = '';
        this.woInstructionsText = '';
        this.isByPassWO = false;
        this.emailTemplateComments = '';
    }

    handleCaseSelect(event) {
        const caseId = event.target.dataset.id;
        const isChecked = event.target.checked;

        if (isChecked) {
            if (!this.selectedCases.includes(caseId)) {
                this.selectedCases = [...this.selectedCases, caseId];
            }
        } else {
            this.selectedCases = this.selectedCases.filter(id => id !== caseId);
        }

        this.initiateWoButton = this.selectedCases.length === 0;
        this.woUpdatesDisabled = this.selectedCases.length !== 1;
    }

    async handleOpenWorkOrderPopup() {
        await this.loadCaseDetails();
        this.woInstructions = true;
    }

    async handleOpenEmailTemplatePopup() {
        await this.loadCaseDetails();
        this.caseEmailTemp = true;
    }

    handleOpenCaseAssetPopup() {
        // Navigate to case asset component or open modal
        // This would require the DisplayCaseAssets LWC component
        if (this.selectedCases.length > 0) {
            // TODO: Implement case asset popup
            console.log('Opening case asset popup for:', this.selectedCases[0]);
        }
    }

    async loadCaseDetails() {
        try {
            const caseData = await getCaseDetails({ caseRecId: this.recordId });
            if (caseData) {
                this.siteContact = caseData.Site_Contact__c || '';
                this.siteContactPhone = caseData.Site_Contact_Phone__c || '';
                this.woInstructionsText = caseData.User_Input_Work_Order_Instructions__c || '';
                this.emailTemplateComments = caseData.EmailTemplateAdditionalComments__c || '';
            }
        } catch (error) {
            console.error('Error loading case details:', error);
        }
    }

    // Form Input Handlers
    handleSiteContactChange(event) {
        this.siteContact = event.target.value;
    }

    handleSiteContactPhoneChange(event) {
        this.siteContactPhone = event.target.value;
    }

    handleWoInstructionsChange(event) {
        this.woInstructionsText = event.target.value;
    }

    handleByPassWOChange(event) {
        this.isByPassWO = event.target.checked;
    }

    handleEmailTemplateChange(event) {
        this.emailTemplateComments = event.target.value;
    }

    // Work Order Actions
    async handleSaveWorkOrderDetails() {
        // Validate form
        const isValid = [...this.template.querySelectorAll('lightning-input, lightning-textarea')]
            .reduce((validSoFar, input) => {
                input.reportValidity();
                return validSoFar && input.checkValidity();
            }, true);

        if (!isValid) {
            return;
        }

        try {
            const caseWoFields = {
                Site_Contact__c: this.siteContact,
                Site_Contact_Phone__c: this.siteContactPhone,
                User_Input_Work_Order_Instructions__c: this.woInstructionsText,
                Is_ByPassWO__c: this.isByPassWO
            };

            const result = await addWorkOrderDetails({
                caseWoFields: caseWoFields,
                caseIdList: this.selectedCases
            });

            if (result === 'Success') {
                this.showToast('Success', 'Work order details saved successfully', 'success');
                this.handleCancelModal();
                this.refreshView();
            } else {
                this.showToast('Error', 'Failed to save work order details', 'error');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error saving work order details', 'error');
        }
    }

    async handleSaveCaseTemplate() {
        try {
            const result = await saveAdditionalTemplate({
                emailTempDesc: this.emailTemplateComments,
                caseId: this.selectedCases
            });

            if (result === 'Success') {
                this.showToast('Success', 'Email template saved successfully', 'success');
                this.handleCancelModal();
                this.refreshView();
            } else {
                this.showToast('Error', 'Failed to save email template', 'error');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error saving email template', 'error');
        }
    }

    async handleInitiateWorkorder() {
        try {
            this.viewCaseSummary = false;
            this.isLoading = true;

            const result = await initiateWorkOrder({
                caseId: this.recordId,
                caseIdList: this.selectedCases
            });

            if (result === 'Success') {
                this.showToast('Success', 'Work order initiated successfully', 'success');

                // Refresh and publish message
                setTimeout(() => {
                    this.refreshView();

                    if (this.multiAssetCaseReferenceNo && !this.initiateWoButton) {
                        this.publishMessage({ caseId: this.recordId });
                    }
                }, 3000);
            } else {
                this.showToast('Error', 'Failed to initiate work order', 'error');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error initiating work order', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Quote Actions
    handleCreateQuote() {
        this.showQuoteModal = true;
    }

    handleGoToQuote() {
        this.showModal = true;
    }

    // Other Actions
    handleUpdatedRelatedCases() {
        // This would call updateRelatedCases Apex method
        console.log('Updating related cases');
    }

    handleAddCaseAsset() {
        // Navigate to add case asset component
        console.log('Adding case asset');
    }

    handleShowProgressBtns() {
        // Show progress buttons modal
        console.log('Showing progress buttons');
    }

    // Utility Methods
    refreshView() {
        // Refresh the case record
        notifyRecordUpdateAvailable([{ recordId: this.recordId }]);

        // Request refresh from CaseDataGovernor (preferred)
        // Falls back to direct call if governor not present
        if (this.hasReceivedGovernorData) {
            this.requestCaseDataRefresh();
        } else {
            this.loadCaseMessages();
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
