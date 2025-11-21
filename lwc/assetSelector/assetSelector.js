import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchAssets from '@salesforce/apex/AssetSelectorController.searchAssets';
import getAssetById from '@salesforce/apex/AssetSelectorController.getAssetById';
import getRecentAssets from '@salesforce/apex/AssetSelectorController.getRecentAssets';
import getAssetsForLocation from '@salesforce/apex/AssetSelectorController.getAssetsForLocation';
import getHighlightedAssets from '@salesforce/apex/AssetSelectorController.getHighlightedAssets';
import updateAssetOnCase from '@salesforce/apex/AssetSelectorController.updateAssetOnCase';
import validateAssetSelection from '@salesforce/apex/AssetSelectorController.validateAssetSelection';

/**
 * Asset Selector Component
 *
 * Unified component for searching and selecting assets at a location.
 * Supports both single and multi-asset selection.
 *
 * Replaces: AssetHeadersForCase Aura component
 *
 * Features:
 * - Context pill showing selected location
 * - Multi-field search (SID, Material Type, Schedule, Vendor, Equipment Type, Category)
 * - Recent assets quick selection
 * - Single or multi-asset selection modes
 * - Highlighted assets (already selected on related cases)
 * - Inline asset detail display
 * - Active/inactive asset filtering
 *
 * @author George Martin
 * @date 2025-11-18
 */
export default class AssetSelector extends LightningElement {
    // ========================================
    // Public Properties
    // ========================================

    /**
     * Location ID (required for asset search)
     */
    @api locationId;

    /**
     * Location name (for context display)
     */
    @api locationName;

    /**
     * Case ID (for highlighting already selected assets)
     */
    @api caseId;

    /**
     * Case record type name
     */
    @api caseRecordType;

    /**
     * Pre-selected asset ID (for edit mode)
     */
    @api selectedAssetId;

    /**
     * Allow multi-asset selection
     */
    @api allowMultiSelect = false;

    /**
     * Show recent assets section
     */
    @api showRecentAssets = true;

    /**
     * Number of recent assets to show
     */
    @api recentAssetLimit = 5;

    /**
     * Show only active assets
     */
    @api activeAssetsOnly = false;

    // ========================================
    // Private Properties
    // ========================================

    @track selectedAsset = null;
    @track selectedAssets = [];
    @track recentAssets = [];
    @track highlightedAssetIds = [];
    @track searchResults = [];
    @track isLoading = false;
    @track error = null;

    // ========================================
    // Lifecycle Hooks
    // ========================================

    connectedCallback() {
        // Load highlighted assets if case ID provided
        if (this.caseId) {
            this.loadHighlightedAssets();
        }

        // Load pre-selected asset if ID provided
        if (this.selectedAssetId) {
            this.loadSelectedAsset();
        }

        // Load recent assets
        if (this.locationId) {
            this.loadRecentAssets();
        }
    }

    // ========================================
    // Computed Properties
    // ========================================

    /**
     * Whether location context is available
     */
    get hasLocationContext() {
        return this.locationId != null && this.locationName != null;
    }

    /**
     * Whether there are recent assets
     */
    get hasRecentAssets() {
        return this.recentAssets && this.recentAssets.length > 0;
    }

    /**
     * Whether an asset is selected
     */
    get hasSelectedAsset() {
        return this.selectedAsset != null;
    }

    /**
     * Whether multiple assets are selected
     */
    get hasMultipleSelectedAssets() {
        return this.allowMultiSelect && this.selectedAssets.length > 0;
    }

    /**
     * Count of selected assets
     */
    get selectedAssetCount() {
        return this.selectedAssets.length;
    }

    /**
     * Selected asset title for detail card
     */
    get selectedAssetTitle() {
        if (!this.selectedAsset) return '';
        return `Asset: ${this.selectedAsset.acornSID || this.selectedAsset.name}`;
    }

    /**
     * Show radio select or checkbox
     */
    get showRadioSelect() {
        return !this.allowMultiSelect;
    }

    /**
     * Selected asset fields for detail card
     */
    get selectedAssetFields() {
        if (!this.selectedAsset) return [];

        const fields = [];

        if (this.selectedAsset.acornSID) {
            fields.push({ id: 'sid', label: 'SID', value: this.selectedAsset.acornSID, type: 'text' });
        }

        if (this.selectedAsset.name) {
            fields.push({ id: 'name', label: 'Name', value: this.selectedAsset.name, type: 'text' });
        }

        if (this.selectedAsset.materialType) {
            fields.push({ id: 'material', label: 'Material Type', value: this.selectedAsset.materialType, type: 'text' });
        }

        if (this.selectedAsset.schedule) {
            fields.push({ id: 'schedule', label: 'Schedule', value: this.selectedAsset.schedule, type: 'text' });
        }

        if (this.selectedAsset.quantity != null) {
            fields.push({ id: 'quantity', label: 'Quantity', value: this.selectedAsset.quantity, type: 'text' });
        }

        if (this.selectedAsset.supplierName) {
            fields.push({ id: 'supplier', label: 'Supplier', value: this.selectedAsset.supplierName, type: 'text' });
        }

        if (this.selectedAsset.equipmentType) {
            fields.push({ id: 'equipment', label: 'Equipment Type', value: this.selectedAsset.equipmentType, type: 'text' });
        }

        if (this.selectedAsset.category) {
            fields.push({ id: 'category', label: 'Category', value: this.selectedAsset.category, type: 'text' });
        }

        if (this.selectedAsset.startDate) {
            fields.push({ id: 'start', label: 'Start Date', value: this.selectedAsset.startDate, type: 'date' });
        }

        if (this.selectedAsset.endDate) {
            fields.push({ id: 'end', label: 'End Date', value: this.selectedAsset.endDate, type: 'date' });
        }

        if (this.selectedAsset.isActive != null) {
            fields.push({ id: 'active', label: 'Active', value: this.selectedAsset.isActive, type: 'boolean' });
        }

        return fields;
    }

    /**
     * Search fields configuration for recordSearchBase
     */
    get searchFields() {
        return [
            {
                name: 'sid',
                label: 'SID',
                type: 'text',
                placeholder: 'Search by SID...',
                required: false
            },
            {
                name: 'materialType',
                label: 'Material Type',
                type: 'text',
                placeholder: 'Search by material type...',
                required: false
            },
            {
                name: 'schedule',
                label: 'Schedule',
                type: 'text',
                placeholder: 'Search by schedule...',
                required: false
            },
            {
                name: 'vendorName',
                label: 'Vendor/Supplier',
                type: 'text',
                placeholder: 'Search by vendor...',
                required: false
            },
            {
                name: 'equipmentType',
                label: 'Equipment Type',
                type: 'text',
                placeholder: 'Search by equipment type...',
                required: false
            },
            {
                name: 'category',
                label: 'Category',
                type: 'text',
                placeholder: 'Search by category...',
                required: false
            }
        ];
    }

    /**
     * Columns configuration for recordSearchBase results table
     */
    get columns() {
        return [
            { label: 'SID', fieldName: 'acornSID', type: 'text' },
            { label: 'Name', fieldName: 'name', type: 'text' },
            { label: 'Material Type', fieldName: 'materialType', type: 'text' },
            { label: 'Schedule', fieldName: 'schedule', type: 'text' },
            { label: 'Quantity', fieldName: 'quantity', type: 'number' },
            { label: 'Supplier', fieldName: 'supplierName', type: 'text' },
            { label: 'Active', fieldName: 'isActive', type: 'boolean' }
        ];
    }

    // ========================================
    // Event Handlers - Search
    // ========================================

    /**
     * Handle search event from recordSearchBase
     */
    handleSearch(event) {
        if (!this.locationId) {
            this.showError('Please select a location first');
            return;
        }

        const searchCriteria = event.detail.searchCriteria || {};

        // Add active filter if enabled
        if (this.activeAssetsOnly) {
            searchCriteria.activeOnly = 'true';
        }

        // Check if any search criteria provided
        const hasSearchCriteria = Object.values(searchCriteria).some(value => value && value.trim() !== '');

        if (!hasSearchCriteria) {
            // If no criteria, load all assets for location
            this.loadAllAssets();
            return;
        }

        this.performSearch(searchCriteria);
    }

    /**
     * Handle recent asset button click
     */
    handleRecentAssetClick(event) {
        const assetId = event.currentTarget.dataset.id;
        if (assetId) {
            this.loadAssetById(assetId);
        }
    }

    /**
     * Handle record selection from recordSearchBase
     */
    handleRecordSelect(event) {
        const recordId = event.detail.recordId;
        if (recordId) {
            this.loadAssetById(recordId);
        }
    }

    /**
     * Handle record click from recordSearchBase
     */
    handleRecordClick(event) {
        const recordId = event.detail.recordId;
        if (recordId) {
            // Navigate to record detail page
            this.dispatchEvent(new CustomEvent('navigate', {
                detail: {
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: recordId,
                        actionName: 'view'
                    }
                }
            }));
        }
    }

    /**
     * Handle clear event from recordSearchBase
     */
    handleClear(event) {
        this.selectedAsset = null;
        this.selectedAssets = [];
        this.searchResults = [];

        // Notify parent of clear
        this.dispatchEvent(new CustomEvent('clear'));
    }

    /**
     * Handle error event from recordSearchBase
     */
    handleError(event) {
        const message = event.detail.message || 'An error occurred';
        this.showError(message);
    }

    /**
     * Handle remove asset from multi-select list
     */
    handleRemoveAsset(event) {
        const assetId = event.currentTarget.dataset.id;
        this.selectedAssets = this.selectedAssets.filter(asset => asset.id !== assetId);

        // Update case
        if (this.caseId) {
            this.updateCaseAssets();
        }

        this.notifyAssetChange();
    }

    // ========================================
    // Private Methods - Data Loading
    // ========================================

    /**
     * Load selected asset by ID
     */
    loadSelectedAsset() {
        if (!this.selectedAssetId) return;

        this.isLoading = true;
        getAssetById({ assetId: this.selectedAssetId })
            .then(result => {
                if (result) {
                    this.selectedAsset = result;
                    if (this.allowMultiSelect && !this.selectedAssets.find(a => a.id === result.id)) {
                        this.selectedAssets = [...this.selectedAssets, result];
                    }
                    this.notifyAssetSelected(result);
                }
            })
            .catch(error => {
                this.showError('Failed to load selected asset: ' + this.getErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Load asset by ID
     */
    loadAssetById(assetId) {
        if (!assetId) return;

        this.isLoading = true;

        // First validate the asset selection
        validateAssetSelection({
            assetId: assetId,
            caseRecordType: this.caseRecordType
        })
        .then(validationResult => {
            if (!validationResult.isValid) {
                this.showError(validationResult.message || 'Invalid asset selection');
                return Promise.reject(new Error('Invalid asset'));
            }

            // If valid, load the asset details
            return getAssetById({ assetId: assetId });
        })
        .then(result => {
            if (result) {
                if (this.allowMultiSelect) {
                    // Add to multi-select list if not already added
                    if (!this.selectedAssets.find(a => a.id === result.id)) {
                        this.selectedAssets = [...this.selectedAssets, result];
                    }
                    this.selectedAsset = result;
                } else {
                    // Single select mode
                    this.selectedAsset = result;
                    this.selectedAssets = [result];
                }

                // Update case if caseId provided
                if (this.caseId) {
                    this.updateCaseAssets();
                } else {
                    this.notifyAssetSelected(result);
                }
            }
        })
        .catch(error => {
            if (error.message !== 'Invalid asset') {
                this.showError('Failed to load asset: ' + this.getErrorMessage(error));
            }
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    /**
     * Load recent assets
     */
    loadRecentAssets() {
        if (!this.showRecentAssets || !this.locationId) return;

        getRecentAssets({
            locationId: this.locationId,
            limitCount: this.recentAssetLimit
        })
        .then(result => {
            this.recentAssets = result || [];
        })
        .catch(error => {
            console.error('Failed to load recent assets:', error);
            this.recentAssets = [];
        });
    }

    /**
     * Load highlighted assets (already selected)
     */
    loadHighlightedAssets() {
        if (!this.caseId) return;

        getHighlightedAssets({ caseId: this.caseId })
            .then(result => {
                this.highlightedAssetIds = result || [];
            })
            .catch(error => {
                console.error('Failed to load highlighted assets:', error);
                this.highlightedAssetIds = [];
            });
    }

    /**
     * Load all assets for location
     */
    loadAllAssets() {
        this.isLoading = true;

        getAssetsForLocation({
            locationId: this.locationId,
            caseRecordType: this.caseRecordType
        })
        .then(result => {
            this.searchResults = result || [];

            // Pass results to recordSearchBase
            const searchBase = this.template.querySelector('c-record-search-base');
            if (searchBase) {
                searchBase.setResults(this.searchResults);
            }

            if (this.searchResults.length === 0) {
                this.showInfo('No assets found for this location');
            }
        })
        .catch(error => {
            this.showError('Failed to load assets: ' + this.getErrorMessage(error));
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    /**
     * Perform asset search
     */
    performSearch(searchCriteria) {
        this.isLoading = true;

        searchAssets({
            locationId: this.locationId,
            caseRecordType: this.caseRecordType,
            searchCriteria: searchCriteria
        })
        .then(result => {
            this.searchResults = result || [];

            // Pass results to recordSearchBase
            const searchBase = this.template.querySelector('c-record-search-base');
            if (searchBase) {
                searchBase.setResults(this.searchResults);
            }

            if (this.searchResults.length === 0) {
                this.showInfo('No results found. Try different search criteria.');
            }
        })
        .catch(error => {
            this.showError('Search failed: ' + this.getErrorMessage(error));
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    /**
     * Update case with selected assets
     */
    updateCaseAssets() {
        const assetId = this.allowMultiSelect && this.selectedAssets.length > 0
            ? this.selectedAssets[0].id
            : (this.selectedAsset ? this.selectedAsset.id : null);

        const selectedIds = this.selectedAssets.map(a => a.id);

        updateAssetOnCase({
            caseId: this.caseId,
            assetId: assetId,
            selectedAssetIds: selectedIds
        })
        .then(() => {
            this.notifyAssetChange();
        })
        .catch(error => {
            this.showError('Failed to update case: ' + this.getErrorMessage(error));
        });
    }

    // ========================================
    // Private Methods - Notifications
    // ========================================

    /**
     * Notify parent that asset was selected
     */
    notifyAssetSelected(asset) {
        this.dispatchEvent(new CustomEvent('assetselect', {
            detail: {
                assetId: asset.id,
                asset: asset,
                selectedAssets: this.selectedAssets
            }
        }));
    }

    /**
     * Notify parent of asset change
     */
    notifyAssetChange() {
        this.dispatchEvent(new CustomEvent('assetchange', {
            detail: {
                selectedAssets: this.selectedAssets,
                primaryAssetId: this.selectedAssets.length > 0 ? this.selectedAssets[0].id : null
            }
        }));
    }

    /**
     * Show error toast
     */
    showError(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        }));
    }

    /**
     * Show info toast
     */
    showInfo(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Info',
            message: message,
            variant: 'info'
        }));
    }

    /**
     * Extract error message from error object
     */
    getErrorMessage(error) {
        if (!error) return 'Unknown error';
        if (typeof error === 'string') return error;
        if (error.body) {
            if (error.body.message) return error.body.message;
            if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                return error.body.pageErrors[0].message;
            }
        }
        if (error.message) return error.message;
        return JSON.stringify(error);
    }

    // ========================================
    // Public API Methods
    // ========================================

    /**
     * Get selected asset
     */
    @api
    getSelectedAsset() {
        return this.selectedAsset;
    }

    /**
     * Get selected asset ID
     */
    @api
    getSelectedAssetId() {
        return this.selectedAsset ? this.selectedAsset.id : null;
    }

    /**
     * Get all selected assets (multi-select)
     */
    @api
    getSelectedAssets() {
        return this.selectedAssets;
    }

    /**
     * Get all selected asset IDs (multi-select)
     */
    @api
    getSelectedAssetIds() {
        return this.selectedAssets.map(a => a.id);
    }

    /**
     * Clear selection
     */
    @api
    clearSelection() {
        this.selectedAsset = null;
        this.selectedAssets = [];
        this.searchResults = [];

        const searchBase = this.template.querySelector('c-record-search-base');
        if (searchBase) {
            searchBase.clearSearch();
        }
    }

    /**
     * Set location context programmatically
     */
    @api
    setLocationContext(locationId, locationName, caseRecordType) {
        this.locationId = locationId;
        this.locationName = locationName;
        this.caseRecordType = caseRecordType;

        this.loadRecentAssets();
    }
}
