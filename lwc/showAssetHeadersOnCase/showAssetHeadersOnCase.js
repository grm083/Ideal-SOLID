import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// Import Apex methods
import getAssetHeaders from '@salesforce/apex/AssetHeadersForCaseController.getAssetHeaders';
import disableCheck from '@salesforce/apex/AssetHeadersForCaseController.disableCheck';
import replaceAssetHeader from '@salesforce/apex/AssetHeadersForCaseController.replaceAssetHeader';

// Import Case fields
import CASE_ID from '@salesforce/schema/Case.Id';
import CASE_NUMBER from '@salesforce/schema/Case.CaseNumber';
import CASE_ASSET_ID from '@salesforce/schema/Case.AssetId';
import CASE_STATUS from '@salesforce/schema/Case.Status';
import CASE_SUB_TYPE from '@salesforce/schema/Case.Case_Sub_Type__c';
import CASE_TYPE from '@salesforce/schema/Case.Case_Type__c';

// Import Custom Label
import SAVE_ASSET_HEADER_FAILURE from '@salesforce/label/c.Save_Asset_Header_Failure';

const CASE_FIELDS = [
    CASE_ID,
    CASE_NUMBER,
    CASE_ASSET_ID,
    CASE_STATUS,
    CASE_SUB_TYPE,
    CASE_TYPE
];

/**
 * ShowAssetHeadersOnCase - LWC component for asset header selection
 * Converted from Aura component: aura/ShowAssetHeadersOnCase
 *
 * @description Displays active and inactive asset headers in collapsible sections.
 * Allows users to select asset headers with checkboxes and save selections to the case.
 * Includes complex validation for case type/subtype combinations.
 */
export default class ShowAssetHeadersOnCase extends LightningElement {
    // Public properties
    @api recordId;

    // Private properties
    @track assetHeaders = [];
    @track selectedOptions = [];
    @track selectedAssetHeaders = [];
    @track loadingSpinner = false;
    @track DoDisable = false;
    @track saveEnabled = true;
    @track assetIdOnCase = '';
    @track officetrax = false;
    @track firstElementOnList = '';

    // Section state
    @track activeAssetHeaderSectionOpen = true;
    @track inactiveAssetHeaderSectionOpen = false;

    // Wire case record
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    caseRecord;

    wiredAssetHeadersResult;

    // Computed properties
    get caseStatus() {
        return getFieldValue(this.caseRecord.data, CASE_STATUS);
    }

    get caseType() {
        return getFieldValue(this.caseRecord.data, CASE_TYPE);
    }

    get caseSubType() {
        return getFieldValue(this.caseRecord.data, CASE_SUB_TYPE);
    }

    get activeAssetHeaders() {
        return this.assetHeaders
            .filter(asset => asset.isActiveAsset)
            .map(asset => this.enrichAssetData(asset, true));
    }

    get inactiveAssetHeaders() {
        return this.assetHeaders
            .filter(asset => !asset.isActiveAsset)
            .map(asset => this.enrichAssetData(asset, false));
    }

    enrichAssetData(asset, isActive) {
        return {
            ...asset,
            rowClass: asset.highlightRow ? 'highlight' : 'nohighlight',
            isSelected: this.selectedOptions.includes(asset.assetId),
            isDisabled: this.DoDisable || (!isActive && asset.highlightRow),
            assetNameClass: asset.assetId === this.firstElementOnList ? 'slds-size_1-of-19 highlightBold' : 'slds-size_1-of-19'
        };
    }

    get activeAssetHeaderSectionClass() {
        return this.activeAssetHeaderSectionOpen ? 'slds-section slds-is-open' : 'slds-section';
    }

    get inactiveAssetHeaderSectionClass() {
        return this.inactiveAssetHeaderSectionOpen ? 'slds-section slds-is-open' : 'slds-section';
    }

    // Lifecycle Hooks
    async connectedCallback() {
        await this.loadData();
    }

    // Data Loading Methods
    async loadData() {
        this.loadingSpinner = true;
        try {
            await Promise.all([
                this.loadAssetHeaders(),
                this.loadDisableCheck()
            ]);
        } catch (error) {
            console.error('Error loading data:', error);
            this.showToast('Error', error.body?.message || 'Error loading data', 'error');
        } finally {
            this.loadingSpinner = false;
        }
    }

    async loadAssetHeaders() {
        try {
            const data = await getAssetHeaders({ caseId: this.recordId });
            const alreadySelected = [];

            // Format dates and track selections
            data.forEach(asset => {
                // Format Start Date (YYYY-MM-DD to MM/DD/YYYY)
                if (asset.Start_Date) {
                    const parts = asset.Start_Date.split('-');
                    asset.Start_Date = `${parts[1]}/${parts[2]}/${parts[0]}`;
                }

                // Format End Date (YYYY-MM-DD to MM/DD/YYYY)
                if (asset.End_Date) {
                    const parts = asset.End_Date.split('-');
                    asset.End_Date = `${parts[1]}/${parts[2]}/${parts[0]}`;
                }

                // Track highlighted (already selected) assets
                if (asset.highlightRow) {
                    alreadySelected.push(asset.assetId);
                }
            });

            this.assetHeaders = data;
            this.selectedOptions = [...alreadySelected];
        } catch (error) {
            console.error('Error loading asset headers:', error);
            throw error;
        }
    }

    async loadDisableCheck() {
        try {
            const data = await disableCheck({ caseId: this.recordId });

            if (data && data.length > 0) {
                const caseData = data[0];
                this.assetIdOnCase = caseData.AssetId;

                // Move current asset to front of selection
                let selectedOptions = [...this.selectedOptions];
                if (caseData.AssetId) {
                    const index = selectedOptions.indexOf(caseData.AssetId);
                    if (index > -1) {
                        selectedOptions.splice(index, 1);
                    }
                    selectedOptions.unshift(caseData.AssetId);
                }

                this.selectedOptions = selectedOptions;
                this.selectedAssetHeaders = [...selectedOptions];
                this.firstElementOnList = caseData.AssetId;

                // Check if OfficeTrax case
                if (caseData.Origin && caseData.Origin.toLowerCase().includes('officetrax')) {
                    this.officetrax = true;
                }

                // Complex disable logic based on case status, type, and subtype
                this.DoDisable = !this.shouldEnableSelection(caseData);
            }
        } catch (error) {
            console.error('Error in disable check:', error);
            throw error;
        }
    }

    /**
     * Determines if asset selection should be enabled based on case properties
     * This is a complex business rule with many case type/subtype combinations
     */
    shouldEnableSelection(caseData) {
        const status = caseData.Status;
        const isMultipleAsset = caseData.Is_Multiple_Asset__c;
        const hasWorkOrder = caseData.Acorn_Work_order__c;
        const recordTypeName = caseData.RecordType?.Name;
        const caseType = caseData.Case_Type__c;
        const caseSubType = caseData.Case_Sub_Type__c;
        const caseReason = caseData.Case_Reason__c;

        // New status without multi-asset
        if (status === 'New' && !isMultipleAsset) {
            return true;
        }

        // Open status without work order and specific combinations
        if (status === 'Open' && !hasWorkOrder) {
            // Standard Case combinations
            if (recordTypeName === 'Standard Case' && caseType === 'General') return true;
            if (recordTypeName === 'Standard Case' && caseType === 'Payment Inquiries' && caseSubType === 'Past Due') return true;

            // Repair Case combinations
            if (recordTypeName === 'Repair Case' && caseType === 'Hauler Damage' && caseSubType === 'Equipment/Property') return true;

            // Service Request Case combinations
            if (recordTypeName === 'Service Request Case') {
                if (caseType === 'Add' && caseSubType === 'Equipment' && caseReason === 'Compactor') return true;
                if (caseType === 'Add' && caseSubType === 'Equipment' && caseReason === 'Compactor Accessories') return true;
                if (caseType === 'Add' && caseSubType === 'Fee(s)' && caseReason === 'General Fees') return true;
                if (caseType === 'Add' && caseSubType === 'Services' && caseReason === 'Missing Service') return true;
                if (caseType === 'Special Request' && caseSubType === 'Dumpster Fresh') return true;
                if (caseType === 'Special Request' && caseSubType === 'Lamptracker/Batterytracker/MedWaste') return true;
                if (caseType === 'Special Request' && caseSubType === 'Event Box(es)') return true;
                if (caseType === 'Special Request' && caseSubType === 'General Supplies') return true;
                if (caseType === 'Special Request' && caseSubType === 'Electronic Recycling (Computers, Laptops, etc.)' && caseReason === 'Electronic Recycling Collection') return true;
                if (caseType === 'Special Request' && caseSubType === 'Universal Waste (Lamps, Batteries, etc.)' && caseReason === 'Universal Waste Collection') return true;
            }

            // Pickup Case combinations
            if (recordTypeName === 'Pickup Case' && caseType === 'Pickup' && caseSubType === 'Bale(s)') return true;

            // Modify Existing Service Case combinations
            if (recordTypeName === 'Modify Existing Service Case' && caseType === 'Change Service' && caseSubType === 'Change/Correction' && caseReason === 'Remove End Dates') return true;

            // Status Case combinations
            if (recordTypeName === 'Status Case') {
                if (caseType === 'Status' && caseSubType === 'ETA') return true;
                if (caseType === 'Status' && caseSubType === 'Service Not Performed' && (caseReason === 'Customer Reported' || caseReason === 'Hauler Reported')) return true;
            }
        }

        return false;
    }

    // Event Handlers
    handleToggleActiveSection() {
        this.activeAssetHeaderSectionOpen = !this.activeAssetHeaderSectionOpen;
        if (this.activeAssetHeaderSectionOpen) {
            this.inactiveAssetHeaderSectionOpen = false;
        }
    }

    handleToggleInactiveSection() {
        this.inactiveAssetHeaderSectionOpen = !this.inactiveAssetHeaderSectionOpen;
        if (this.inactiveAssetHeaderSectionOpen) {
            this.activeAssetHeaderSectionOpen = false;
        }
    }

    handleSelectAsset(event) {
        const assetId = event.currentTarget.dataset.id;
        let assetIds = [...this.selectedOptions];

        this.saveEnabled = false;

        // Toggle selection
        const index = assetIds.indexOf(assetId);
        if (index > -1) {
            assetIds.splice(index, 1);
        } else {
            assetIds.push(assetId);
        }

        // Check if selections match original state
        if (assetIds.length === 0) {
            this.saveEnabled = true;
        }

        if (assetIds.length === this.selectedAssetHeaders.length &&
            this.checkContainer(assetIds, this.selectedAssetHeaders)) {
            this.saveEnabled = true;
            this.selectedOptions = [...this.selectedAssetHeaders];
        } else {
            this.selectedOptions = assetIds;
        }
    }

    async handleSaveAsset() {
        const assetSelections = [...this.selectedOptions];
        const existingAssetOnCase = this.assetIdOnCase;
        let assetToReplace = null;
        let multiAssetIds = [];
        const equipmentTypes = [];

        // Collect equipment types for selected assets
        assetSelections.forEach(assetId => {
            const asset = this.assetHeaders.find(a => a.assetId === assetId);
            if (asset && asset.EquipmentType) {
                equipmentTypes.push(asset.EquipmentType);
            }
        });

        // Determine replacement asset and multi-asset IDs
        if (assetSelections.length === 1 && !assetSelections.includes(existingAssetOnCase)) {
            assetToReplace = assetSelections[0];
        } else if (assetSelections.length > 1) {
            if (!assetSelections.includes(existingAssetOnCase)) {
                assetToReplace = assetSelections[0];
            }

            assetSelections.forEach(assetId => {
                if (existingAssetOnCase !== assetId) {
                    multiAssetIds.push(assetId);
                }
            });
        }

        // Remove first element from multiAssetIds if we have a replacement
        if (assetToReplace && multiAssetIds.length > 0) {
            multiAssetIds.shift();
        }

        // Validate Baler equipment type for specific case type
        if (this.caseStatus === 'Open' &&
            this.caseType === 'Pickup' &&
            this.caseSubType === 'Bale(s)' &&
            !equipmentTypes.includes('Baler')) {
            this.showToast('Error', 'You may only select Baler Equipment Type.', 'error');
            return;
        }

        // Save the selections
        await this.saveAssetSelection(assetToReplace, multiAssetIds);
    }

    async saveAssetSelection(assetToReplace, multiAssetIds) {
        this.loadingSpinner = true;

        try {
            await replaceAssetHeader({
                caseId: this.recordId,
                assetValue: assetToReplace,
                selectedAssets: multiAssetIds
            });

            this.saveEnabled = true;
            this.showToast('Success', 'Asset header(s) saved successfully', 'success');

            // Refresh data
            await this.loadData();

            // Dispatch custom event for parent components
            this.dispatchEvent(new CustomEvent('caseupdated', {
                detail: { caseId: this.recordId }
            }));
        } catch (error) {
            if (this.officetrax) {
                this.showToast('Error', 'You may only select Got Junk Assets for Officetrax cases.', 'error');
            } else {
                this.showToast('Error', SAVE_ASSET_HEADER_FAILURE, 'error');
            }
            console.error('Error saving asset selection:', error);
        } finally {
            this.loadingSpinner = false;
        }
    }

    // Helper Methods
    checkContainer(assetIds, alreadySelectedAssets) {
        return alreadySelectedAssets.every(assetId => assetIds.includes(assetId));
    }

    isAssetSelected(assetId) {
        return this.selectedOptions.includes(assetId);
    }

    isCheckboxDisabled(asset) {
        if (this.DoDisable) return true;
        if (asset.highlightRow && !asset.isActiveAsset) return true;
        return false;
    }

    getRowClass(asset) {
        return asset.highlightRow ? 'highlight' : 'nohighlight';
    }

    isAssetNameBold(assetId) {
        return assetId === this.firstElementOnList;
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

    // Public API method for refreshing data
    @api
    async updateAssetHeaders() {
        await this.loadData();
    }
}
