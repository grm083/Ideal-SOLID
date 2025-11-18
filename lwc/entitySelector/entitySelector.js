import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchEntities from '@salesforce/apex/EntitySelectorController.searchEntities';
import getEntityById from '@salesforce/apex/EntitySelectorController.getEntityById';
import getRecentEntities from '@salesforce/apex/EntitySelectorController.getRecentEntities';
import validateEntitySelection from '@salesforce/apex/EntitySelectorController.validateEntitySelection';

/**
 * Entity Selector Component (Location/Vendor/Client)
 *
 * Unified component that can search and select Locations, Vendors, or Clients
 * based on mode parameter or user selection.
 *
 * Replaces: LocationContainer, VendorContainer, ClientContainer
 *
 * Features:
 * - 3 modes: Location, Vendor, Client
 * - Auto-detection of entity type from case
 * - Multi-field search (name, account number, address, city, state, ZIP, phone)
 * - Recent entities quick selection
 * - Detail display using inlineDetailCard
 * - Validation on selection
 *
 * @author Claude (AI Assistant)
 * @date 2025-11-18
 */
export default class EntitySelector extends LightningElement {
    // ========================================
    // Public Properties
    // ========================================

    /**
     * Mode: 'location', 'vendor', 'client', or null (user selects)
     */
    @api mode;

    /**
     * Pre-selected entity ID (for edit mode)
     */
    @api selectedEntityId;

    /**
     * Show recent entities section
     */
    @api showRecentEntities = true;

    /**
     * Number of recent entities to show
     */
    @api recentEntityLimit = 5;

    /**
     * Case record type (for validation)
     */
    @api caseRecordType;

    // ========================================
    // Private Properties
    // ========================================

    @track selectedEntityType = 'location';
    @track selectedEntity = null;
    @track recentEntities = [];
    @track searchResults = [];
    @track isLoading = false;
    @track error = null;

    // ========================================
    // Lifecycle Hooks
    // ========================================

    connectedCallback() {
        // Set entity type from mode if provided
        if (this.mode) {
            this.selectedEntityType = this.mode.toLowerCase();
        }

        // Load pre-selected entity if ID provided
        if (this.selectedEntityId) {
            this.loadSelectedEntity();
        }

        // Load recent entities
        this.loadRecentEntities();
    }

    // ========================================
    // Computed Properties
    // ========================================

    /**
     * Whether mode is fixed (not user-selectable)
     */
    get hasFixedMode() {
        return this.mode != null && this.mode !== '';
    }

    /**
     * Entity type label for display
     */
    get entityTypeLabel() {
        if (this.selectedEntityType === 'location') return 'Location';
        if (this.selectedEntityType === 'vendor') return 'Vendor';
        if (this.selectedEntityType === 'client') return 'Client';
        return 'Entity';
    }

    /**
     * Entity type options for radio group
     */
    get entityTypeOptions() {
        return [
            { label: 'Location', value: 'location' },
            { label: 'Vendor', value: 'vendor' },
            { label: 'Client', value: 'client' }
        ];
    }

    /**
     * Icon name based on entity type
     */
    get iconName() {
        if (this.selectedEntityType === 'location') return 'standard:account';
        if (this.selectedEntityType === 'vendor') return 'standard:partner';
        if (this.selectedEntityType === 'client') return 'standard:client';
        return 'standard:account';
    }

    /**
     * Search title based on entity type
     */
    get searchTitle() {
        return `Search ${this.entityTypeLabel}s`;
    }

    /**
     * Create new label based on entity type
     */
    get createNewLabel() {
        return `Create New ${this.entityTypeLabel}`;
    }

    /**
     * Whether there are recent entities
     */
    get hasRecentEntities() {
        return this.recentEntities && this.recentEntities.length > 0;
    }

    /**
     * Whether an entity is selected
     */
    get hasSelectedEntity() {
        return this.selectedEntity != null;
    }

    /**
     * Selected entity title for detail card
     */
    get selectedEntityTitle() {
        if (!this.selectedEntity) return '';
        return `${this.entityTypeLabel}: ${this.selectedEntity.name}`;
    }

    /**
     * Selected entity fields for detail card
     */
    get selectedEntityFields() {
        if (!this.selectedEntity) return [];

        const fields = [
            { id: 'name', label: 'Name', value: this.selectedEntity.name, type: 'text' },
            { id: 'accountNumber', label: 'Account Number', value: this.selectedEntity.accountNumber, type: 'text' }
        ];

        // Add address fields
        if (this.selectedEntity.billingStreet || this.selectedEntity.billingCity) {
            fields.push({
                id: 'address',
                label: 'Address',
                value: this.selectedEntity.fullAddress,
                type: 'text'
            });
        }

        // Add phone
        if (this.selectedEntity.phone) {
            fields.push({
                id: 'phone',
                label: 'Phone',
                value: this.selectedEntity.phone,
                type: 'text'
            });
        }

        // Location-specific fields
        if (this.selectedEntityType === 'location') {
            if (this.selectedEntity.division) {
                fields.push({ id: 'division', label: 'Division', value: this.selectedEntity.division, type: 'text' });
            }
            if (this.selectedEntity.geography) {
                fields.push({ id: 'geography', label: 'Geography', value: this.selectedEntity.geography, type: 'text' });
            }
            if (this.selectedEntity.isActive !== undefined) {
                fields.push({ id: 'isActive', label: 'Active', value: this.selectedEntity.isActive, type: 'boolean' });
            }
        }

        return fields;
    }

    /**
     * Search fields configuration for recordSearchBase
     */
    get searchFields() {
        return [
            {
                name: 'name',
                label: 'Name',
                type: 'text',
                placeholder: `Search by ${this.entityTypeLabel} name...`,
                required: false
            },
            {
                name: 'accountNumber',
                label: 'Account Number',
                type: 'text',
                placeholder: 'Search by account number...',
                required: false
            },
            {
                name: 'street',
                label: 'Street',
                type: 'text',
                placeholder: 'Search by street address...',
                required: false
            },
            {
                name: 'city',
                label: 'City',
                type: 'text',
                placeholder: 'Search by city...',
                required: false
            },
            {
                name: 'state',
                label: 'State',
                type: 'text',
                placeholder: 'Search by state...',
                required: false
            },
            {
                name: 'postalCode',
                label: 'ZIP Code',
                type: 'text',
                placeholder: 'Search by ZIP code...',
                required: false
            },
            {
                name: 'phone',
                label: 'Phone',
                type: 'text',
                placeholder: 'Search by phone number...',
                required: false
            }
        ];
    }

    /**
     * Columns configuration for recordSearchBase results table
     */
    get columns() {
        const baseColumns = [
            { label: 'Name', fieldName: 'name', type: 'text' },
            { label: 'Account Number', fieldName: 'accountNumber', type: 'text' },
            { label: 'City', fieldName: 'billingCity', type: 'text' },
            { label: 'State', fieldName: 'billingState', type: 'text' },
            { label: 'Phone', fieldName: 'phone', type: 'text' }
        ];

        // Add division for locations
        if (this.selectedEntityType === 'location') {
            baseColumns.push({ label: 'Division', fieldName: 'division', type: 'text' });
        }

        return baseColumns;
    }

    // ========================================
    // Event Handlers
    // ========================================

    /**
     * Handle entity type change from radio group
     */
    handleEntityTypeChange(event) {
        const previousType = this.selectedEntityType;
        this.selectedEntityType = event.detail.value;

        // Clear search and selection when type changes
        if (previousType !== this.selectedEntityType) {
            this.selectedEntity = null;
            this.searchResults = [];
            this.loadRecentEntities();

            // Notify parent of type change
            this.dispatchEvent(new CustomEvent('entitytypechange', {
                detail: {
                    entityType: this.selectedEntityType,
                    previousEntityType: previousType
                }
            }));
        }
    }

    /**
     * Handle recent entity button click
     */
    handleRecentEntityClick(event) {
        const entityId = event.currentTarget.dataset.id;
        if (entityId) {
            this.loadEntityById(entityId);
        }
    }

    /**
     * Handle search event from recordSearchBase
     */
    handleSearch(event) {
        const searchCriteria = event.detail.searchCriteria || {};

        // Check if any search criteria provided
        const hasSearchCriteria = Object.values(searchCriteria).some(value => value && value.trim() !== '');

        if (!hasSearchCriteria) {
            this.showError('Please enter at least one search criterion');
            return;
        }

        this.performSearch(searchCriteria);
    }

    /**
     * Handle record selection from recordSearchBase
     */
    handleRecordSelect(event) {
        const recordId = event.detail.recordId;
        if (recordId) {
            this.loadEntityById(recordId);
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
        this.selectedEntity = null;
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

    // ========================================
    // Private Methods
    // ========================================

    /**
     * Load selected entity by ID
     */
    loadSelectedEntity() {
        if (!this.selectedEntityId) return;

        this.isLoading = true;
        getEntityById({ entityId: this.selectedEntityId })
            .then(result => {
                if (result) {
                    this.selectedEntity = result;
                    this.notifyEntitySelected(result);
                }
            })
            .catch(error => {
                this.showError('Failed to load selected entity: ' + this.getErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Load entity by ID
     */
    loadEntityById(entityId) {
        if (!entityId) return;

        this.isLoading = true;

        // First validate the entity selection
        validateEntitySelection({
            entityId: entityId,
            entityType: this.selectedEntityType
        })
        .then(validationResult => {
            if (!validationResult.isValid) {
                this.showError(validationResult.message || 'Invalid entity selection');
                return Promise.reject(new Error('Invalid entity'));
            }

            // If valid, load the entity details
            return getEntityById({ entityId: entityId });
        })
        .then(result => {
            if (result) {
                this.selectedEntity = result;
                this.notifyEntitySelected(result);
            }
        })
        .catch(error => {
            if (error.message !== 'Invalid entity') {
                this.showError('Failed to load entity: ' + this.getErrorMessage(error));
            }
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    /**
     * Load recent entities
     */
    loadRecentEntities() {
        if (!this.showRecentEntities) return;

        getRecentEntities({
            entityType: this.selectedEntityType,
            limitCount: this.recentEntityLimit
        })
        .then(result => {
            this.recentEntities = result || [];
        })
        .catch(error => {
            console.error('Failed to load recent entities:', error);
            this.recentEntities = [];
        });
    }

    /**
     * Perform entity search
     */
    performSearch(searchCriteria) {
        this.isLoading = true;

        searchEntities({
            entityType: this.selectedEntityType,
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
     * Notify parent that entity was selected
     */
    notifyEntitySelected(entity) {
        this.dispatchEvent(new CustomEvent('entityselect', {
            detail: {
                entityId: entity.id,
                entityType: this.selectedEntityType,
                entity: entity
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
     * Get selected entity
     */
    @api
    getSelectedEntity() {
        return this.selectedEntity;
    }

    /**
     * Get selected entity ID
     */
    @api
    getSelectedEntityId() {
        return this.selectedEntity ? this.selectedEntity.id : null;
    }

    /**
     * Clear selection
     */
    @api
    clearSelection() {
        this.selectedEntity = null;
        this.searchResults = [];

        const searchBase = this.template.querySelector('c-record-search-base');
        if (searchBase) {
            searchBase.clearSearch();
        }
    }

    /**
     * Set entity type programmatically
     */
    @api
    setEntityType(entityType) {
        if (this.hasFixedMode) {
            console.warn('Cannot change entity type when mode is fixed');
            return;
        }

        const validTypes = ['location', 'vendor', 'client'];
        if (validTypes.includes(entityType.toLowerCase())) {
            this.selectedEntityType = entityType.toLowerCase();
            this.loadRecentEntities();
        } else {
            console.error('Invalid entity type:', entityType);
        }
    }
}
