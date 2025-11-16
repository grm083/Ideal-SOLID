import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

// Import Apex methods
import isMultiVisible from '@salesforce/apex/ServiceDateContainerController.IsMultiVisible';
import isWMCapacityPlannerVisible from '@salesforce/apex/ServiceDateContainerController.IsWMCapacityPlannerVisible';

// Import Case fields
import CASE_ID from '@salesforce/schema/Case.Id';
import CASE_SERVICE_DATE from '@salesforce/schema/Case.Service_Date__c';
import CASE_STATUS from '@salesforce/schema/Case.Status';
import CASE_IS_MULTIPLE_ASSET from '@salesforce/schema/Case.Is_Multiple_Asset__c';
import CASE_SHOW_MULTIPLE_ASSET_CASES from '@salesforce/schema/Case.Show_Multiple_Asset_Cases__c';

const CASE_FIELDS = [
    CASE_ID,
    CASE_SERVICE_DATE,
    CASE_STATUS,
    CASE_IS_MULTIPLE_ASSET,
    CASE_SHOW_MULTIPLE_ASSET_CASES
];

/**
 * ServiceDateContainer - LWC component for service date selection
 * Converted from Aura component: aura/ServiceDateContainer
 *
 * @description Modal container with two modes:
 * - Service Date: Shows SetCaseSLADate or WMCapacity component
 * - Multi Dates: Shows CustomCalendar component for multi-asset cases
 */
export default class ServiceDateContainerLWC extends LightningElement {
    // Public properties
    @api recordId;
    @api showForm = false;
    @api parentId;

    // Private properties
    @track isLoading = true;
    @track isModalOpenServiceDate = true;
    @track isOpenSetCaseDateComp = false;
    @track isOpenMultiDateComp = false;
    @track isOpenWMCapacityComp = false;
    @track isCapacityEligible = false;
    @track isAvailDate = false;
    @track isDateNotListedCl = false;

    // Multi-date visibility properties
    @track displaySummary = false;
    @track psiReq = true;
    @track isMultiCheckedVisible = true;
    @track showMultipleCaseLabel = true;
    @track showOnRelatedMultiAssetCase = false;

    // Asset codes that disable multi-date
    ASSET_CODES_NO_MULTI = ['Utility', 'UTL', 'CAM'];

    // Wire Case Record
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    caseRecord;

    // Computed properties
    get serviceDate() {
        return getFieldValue(this.caseRecord.data, CASE_SERVICE_DATE);
    }

    get caseStatus() {
        return getFieldValue(this.caseRecord.data, CASE_STATUS);
    }

    get isMultipleAsset() {
        return getFieldValue(this.caseRecord.data, CASE_IS_MULTIPLE_ASSET);
    }

    get showMultipleAssetCases() {
        return getFieldValue(this.caseRecord.data, CASE_SHOW_MULTIPLE_ASSET_CASES);
    }

    get showMultiDatesButton() {
        return (
            (this.displaySummary || this.showOnRelatedMultiAssetCase) &&
            this.psiReq &&
            this.isMultiCheckedVisible &&
            this.showMultipleCaseLabel
        );
    }

    get serviceDateButtonVariant() {
        return this.isModalOpenServiceDate ? 'brand' : 'neutral';
    }

    get serviceDateButtonIcon() {
        return this.isModalOpenServiceDate ? 'utility:check' : 'utility:add';
    }

    get multiDatesButtonVariant() {
        return this.isOpenMultiDateComp ? 'brand' : 'neutral';
    }

    get multiDatesButtonIcon() {
        return this.isOpenMultiDateComp ? 'utility:check' : 'utility:add';
    }

    // Lifecycle Hooks
    async connectedCallback() {
        this.isLoading = true;
        this.isModalOpenServiceDate = true;
        await Promise.all([
            this.setMultiDateVisibility(),
            this.setWMCapacityVisibility()
        ]);
        this.isLoading = false;
    }

    // Data Loading Methods
    async setMultiDateVisibility() {
        try {
            const wrapper = await isMultiVisible({ caseRecId: this.recordId });

            if (wrapper) {
                // Check for PSI requirement
                if (wrapper.reqInfo && wrapper.reqInfo.includes('PSI is Required.Provide valid PSI or Bypass reason')) {
                    this.psiReq = false;
                }

                if (wrapper.caseAppliedRules && wrapper.caseAppliedRules.includes('PSI')) {
                    this.psiReq = false;
                }

                // Set multi-case visibility
                this.isMultiCheckedVisible = !wrapper.disableMultiCase;

                // Check case sub-type
                if (wrapper.CaseSubType === 'Empty and Do NOT Return' || wrapper.CaseSubType === 'Bale(s)') {
                    this.showMultipleCaseLabel = false;
                }

                // Check case type (only Pickup cases can have multi-dates)
                if (wrapper.CaseType !== 'Pickup') {
                    this.showMultipleCaseLabel = false;
                }

                // Check asset S-code
                if (wrapper.assetSCode && this.ASSET_CODES_NO_MULTI.includes(wrapper.assetSCode)) {
                    this.showMultipleCaseLabel = false;
                }

                // Set display summary based on case info
                const caseInfo = wrapper.caseInfo || '';

                if (caseInfo.includes('Ready')) {
                    if (this.isMultipleAsset && !this.showMultipleAssetCases) {
                        this.displaySummary = false;
                        this.showOnRelatedMultiAssetCase = true;
                    } else {
                        this.displaySummary = true;
                    }
                } else if (caseInfo.includes('Multi Asset')) {
                    if (wrapper.reqInfo === '' && this.isMultipleAsset && this.showMultipleAssetCases) {
                        this.showOnRelatedMultiAssetCase = true;
                    }
                } else if (
                    caseInfo.includes('Complete the intake of related cases(if any) from the parent case') &&
                    this.caseStatus === 'New'
                ) {
                    this.showMultipleCaseLabel = true;
                    this.showOnRelatedMultiAssetCase = true;
                } else {
                    this.displaySummary = false;
                }

                // Hide display summary if there are required info messages
                if (wrapper.reqInfo && wrapper.reqInfo !== '' &&
                    (caseInfo === '' || caseInfo === 'Ready' || caseInfo === 'Multi Asset')) {
                    this.displaySummary = false;
                }
            }
        } catch (error) {
            console.error('Error setting multi-date visibility:', error);
        }
    }

    async setWMCapacityVisibility() {
        try {
            const isCapacityVisible = await isWMCapacityPlannerVisible({ caseRecId: this.recordId });

            if (isCapacityVisible) {
                this.isOpenWMCapacityComp = true;
                this.isOpenSetCaseDateComp = false;
                this.isCapacityEligible = true;
            } else {
                this.isOpenWMCapacityComp = false;
                this.isOpenSetCaseDateComp = true;
                this.isCapacityEligible = false;
            }
        } catch (error) {
            console.error('Error setting WM capacity visibility:', error);
            // Default to SetCaseSLADate on error
            this.isOpenWMCapacityComp = false;
            this.isOpenSetCaseDateComp = true;
        }
    }

    // Event Handlers
    handleCloseModal() {
        this.showForm = false;
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleServiceDateClick() {
        this.isModalOpenServiceDate = true;
        this.isOpenMultiDateComp = false;
    }

    handleMultiDatesClick() {
        this.isOpenMultiDateComp = true;
        this.isModalOpenServiceDate = false;
    }

    // Handle event from WM Capacity Planner to open SLA component
    @api
    handleOpenSetSlaComp(isAvailDate, isDateNotListed) {
        this.isModalOpenServiceDate = true;
        this.isOpenSetCaseDateComp = true;
        this.isOpenWMCapacityComp = false;
        this.isAvailDate = isAvailDate;
        this.isDateNotListedCl = isDateNotListed;
    }
}
