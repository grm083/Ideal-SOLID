import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchContacts from '@salesforce/apex/ContactSelectorController.searchContacts';
import getContactById from '@salesforce/apex/ContactSelectorController.getContactById';
import getRecentContacts from '@salesforce/apex/ContactSelectorController.getRecentContacts';
import getVendorContacts from '@salesforce/apex/ContactSelectorController.getVendorContacts';
import checkDuplicateContact from '@salesforce/apex/ContactSelectorController.checkDuplicateContact';
import createContact from '@salesforce/apex/ContactSelectorController.createContact';
import updateContactOnCase from '@salesforce/apex/ContactSelectorController.updateContactOnCase';
import getAccountTitles from '@salesforce/apex/ContactSelectorController.getAccountTitles';
import getAccountDepartments from '@salesforce/apex/ContactSelectorController.getAccountDepartments';
import createAccountTitle from '@salesforce/apex/ContactSelectorController.createAccountTitle';
import getVendorRoles from '@salesforce/apex/ContactSelectorController.getVendorRoles';
import validateContactSelection from '@salesforce/apex/ContactSelectorController.validateContactSelection';

/**
 * Contact Selector Component
 *
 * Unified component for searching and selecting contacts.
 * Context-aware: Automatically filters by selected entity (Location/Vendor/Client)
 *
 * Replaces: SearchExistingContact
 *
 * Features:
 * - Context pills showing selected entity
 * - Multi-field search (first name, last name, email, phone, mobile)
 * - Recent contacts quick selection
 * - Duplicate detection
 * - Inline contact creation form
 * - Account title/department management
 * - Vendor contact search
 *
 * @author Claude (AI Assistant)
 * @date 2025-11-18
 */
export default class ContactSelector extends LightningElement {
    // ========================================
    // Public Properties
    // ========================================

    /**
     * Selected entity ID (Location/Vendor/Client)
     */
    @api entityId;

    /**
     * Selected entity name (for context display)
     */
    @api entityName;

    /**
     * Entity type: 'location', 'vendor', 'client'
     */
    @api entityType = 'location';

    /**
     * Pre-selected contact ID (for edit mode)
     */
    @api selectedContactId;

    /**
     * Show recent contacts section
     */
    @api showRecentContacts = true;

    /**
     * Number of recent contacts to show
     */
    @api recentContactLimit = 5;

    /**
     * Case ID (for updates)
     */
    @api caseId;

    /**
     * Location ID (for Contact.Location__c field)
     */
    @api locationId;

    // ========================================
    // Private Properties
    // ========================================

    @track selectedContact = null;
    @track recentContacts = [];
    @track searchResults = [];
    @track isLoading = false;
    @track error = null;

    // Contact creation properties
    @track showCreateContactModal = false;
    @track showDuplicateWarning = false;
    @track duplicateContacts = [];
    @track newContact = this.getEmptyContact();
    @track isSaving = false;
    @track isCheckingDuplicates = false;

    // Account title/department properties
    @track accountTitleOptions = [];
    @track accountDepartmentOptions = [];
    @track showCreateTitleForm = false;
    @track newTitleName = '';
    @track isCreatingTitle = false;

    // Preferred method options
    preferredMethodOptions = [
        { label: 'Email', value: 'Email' },
        { label: 'Phone', value: 'Phone' },
        { label: 'Mobile', value: 'Mobile' }
    ];

    // ========================================
    // Lifecycle Hooks
    // ========================================

    connectedCallback() {
        // Load pre-selected contact if ID provided
        if (this.selectedContactId) {
            this.loadSelectedContact();
        }

        // Load recent contacts
        if (this.entityId) {
            this.loadRecentContacts();
            this.loadAccountTitles();
            this.loadAccountDepartments();
        }
    }

    // ========================================
    // Computed Properties
    // ========================================

    /**
     * Whether entity context is available
     */
    get hasEntityContext() {
        return this.entityId != null && this.entityName != null;
    }

    /**
     * Entity icon name based on entity type
     */
    get entityIconName() {
        if (this.entityType === 'location') return 'standard:account';
        if (this.entityType === 'vendor') return 'standard:partner';
        if (this.entityType === 'client') return 'standard:client';
        return 'standard:account';
    }

    /**
     * Search title
     */
    get searchTitle() {
        if (this.entityType === 'vendor') {
            return 'Search Vendor Contacts';
        }
        return 'Search Contacts';
    }

    /**
     * Whether there are recent contacts
     */
    get hasRecentContacts() {
        return this.recentContacts && this.recentContacts.length > 0;
    }

    /**
     * Whether a contact is selected
     */
    get hasSelectedContact() {
        return this.selectedContact != null;
    }

    /**
     * Selected contact title for detail card
     */
    get selectedContactTitle() {
        if (!this.selectedContact) return '';
        return `Contact: ${this.selectedContact.name}`;
    }

    /**
     * Selected contact fields for detail card
     */
    get selectedContactFields() {
        if (!this.selectedContact) return [];

        const fields = [
            { id: 'name', label: 'Name', value: this.selectedContact.name, type: 'text' }
        ];

        if (this.selectedContact.accountTitle) {
            fields.push({
                id: 'title',
                label: 'Title',
                value: this.selectedContact.accountTitle,
                type: 'text'
            });
        }

        if (this.selectedContact.email) {
            fields.push({
                id: 'email',
                label: 'Email',
                value: this.selectedContact.email,
                type: 'text'
            });
        }

        if (this.selectedContact.phone) {
            fields.push({
                id: 'phone',
                label: 'Phone',
                value: this.selectedContact.phone,
                type: 'text'
            });
        }

        if (this.selectedContact.mobilePhone) {
            fields.push({
                id: 'mobile',
                label: 'Mobile',
                value: this.selectedContact.mobilePhone,
                type: 'text'
            });
        }

        if (this.selectedContact.accountName) {
            fields.push({
                id: 'account',
                label: 'Account',
                value: this.selectedContact.accountName,
                type: 'text'
            });
        }

        return fields;
    }

    /**
     * Search fields configuration for recordSearchBase
     */
    get searchFields() {
        return [
            {
                name: 'firstName',
                label: 'First Name',
                type: 'text',
                placeholder: 'Search by first name...',
                required: false
            },
            {
                name: 'lastName',
                label: 'Last Name',
                type: 'text',
                placeholder: 'Search by last name...',
                required: false
            },
            {
                name: 'email',
                label: 'Email',
                type: 'email',
                placeholder: 'Search by email...',
                required: false
            },
            {
                name: 'phone',
                label: 'Phone',
                type: 'tel',
                placeholder: 'Search by phone...',
                required: false
            },
            {
                name: 'mobile',
                label: 'Mobile',
                type: 'tel',
                placeholder: 'Search by mobile...',
                required: false
            }
        ];
    }

    /**
     * Columns configuration for recordSearchBase results table
     */
    get columns() {
        return [
            { label: 'Name', fieldName: 'name', type: 'text' },
            { label: 'Title', fieldName: 'accountTitle', type: 'text' },
            { label: 'Email', fieldName: 'email', type: 'text' },
            { label: 'Phone', fieldName: 'phone', type: 'text' },
            { label: 'Account', fieldName: 'accountName', type: 'text' }
        ];
    }

    // ========================================
    // Event Handlers - Search
    // ========================================

    /**
     * Handle search event from recordSearchBase
     */
    handleSearch(event) {
        if (!this.entityId) {
            this.showError('Please select an entity first');
            return;
        }

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
     * Handle recent contact button click
     */
    handleRecentContactClick(event) {
        const contactId = event.currentTarget.dataset.id;
        if (contactId) {
            this.loadContactById(contactId);
        }
    }

    /**
     * Handle record selection from recordSearchBase
     */
    handleRecordSelect(event) {
        const recordId = event.detail.recordId;
        if (recordId) {
            this.loadContactById(recordId);
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
        this.selectedContact = null;
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
    // Event Handlers - Contact Creation
    // ========================================

    /**
     * Handle create new button click
     */
    handleCreateNew(event) {
        this.newContact = this.getEmptyContact();
        this.newContact.accountId = this.entityId;
        this.showDuplicateWarning = false;
        this.duplicateContacts = [];
        this.showCreateContactModal = true;
    }

    /**
     * Handle contact field change in create form
     */
    handleContactFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this.newContact[field] = event.detail.value;
    }

    /**
     * Handle account title change
     */
    handleAccountTitleChange(event) {
        this.newContact.accountTitleId = event.detail.value;
    }

    /**
     * Handle account department change
     */
    handleAccountDepartmentChange(event) {
        this.newContact.accountDepartmentId = event.detail.value;
    }

    /**
     * Handle preferred method change
     */
    handlePreferredMethodChange(event) {
        this.newContact.preferredMethod = event.detail.value;
    }

    /**
     * Handle check duplicates button click
     */
    handleCheckDuplicates(event) {
        event.preventDefault();

        if (!this.validateContactForm()) {
            return;
        }

        this.isCheckingDuplicates = true;

        const contactDataJson = JSON.stringify(this.newContact);

        checkDuplicateContact({
            contactDataJson: contactDataJson,
            entityId: this.entityId
        })
        .then(result => {
            this.duplicateContacts = result.map((contact, index) => {
                return {
                    ...contact,
                    isNew: index === 0 // First item is the new contact
                };
            });

            if (this.duplicateContacts.length > 1) {
                this.showDuplicateWarning = true;
                this.showInfo('Found ' + (this.duplicateContacts.length - 1) + ' potential duplicate(s)');
            } else {
                this.showInfo('No duplicates found');
                this.showDuplicateWarning = false;
            }
        })
        .catch(error => {
            this.showError('Failed to check duplicates: ' + this.getErrorMessage(error));
        })
        .finally(() => {
            this.isCheckingDuplicates = false;
        });
    }

    /**
     * Handle select duplicate button click
     */
    handleSelectDuplicate(event) {
        const contactId = event.currentTarget.dataset.id;
        if (contactId) {
            this.loadContactById(contactId);
            this.handleCloseModal();
        }
    }

    /**
     * Handle save contact button click
     */
    handleSaveContact(event) {
        event.preventDefault();

        if (!this.validateContactForm()) {
            return;
        }

        this.isSaving = true;

        const contactDataJson = JSON.stringify(this.newContact);

        createContact({
            contactDataJson: contactDataJson,
            locationId: this.locationId || this.entityId
        })
        .then(contactId => {
            this.showSuccess('Contact created successfully');

            // Update case if caseId provided
            if (this.caseId) {
                return this.updateCaseContact(contactId);
            } else {
                return this.loadContactById(contactId);
            }
        })
        .then(() => {
            this.handleCloseModal();
        })
        .catch(error => {
            this.showError('Failed to save contact: ' + this.getErrorMessage(error));
        })
        .finally(() => {
            this.isSaving = false;
        });
    }

    /**
     * Handle close modal button click
     */
    handleCloseModal(event) {
        if (event) event.preventDefault();
        this.showCreateContactModal = false;
        this.showDuplicateWarning = false;
        this.duplicateContacts = [];
        this.newContact = this.getEmptyContact();
    }

    // ========================================
    // Event Handlers - Account Title
    // ========================================

    /**
     * Handle show create title link click
     */
    handleShowCreateTitle(event) {
        event.preventDefault();
        this.showCreateTitleForm = true;
    }

    /**
     * Handle new title name change
     */
    handleNewTitleNameChange(event) {
        this.newTitleName = event.detail.value;
    }

    /**
     * Handle create title button click
     */
    handleCreateTitle(event) {
        event.preventDefault();

        if (!this.newTitleName || this.newTitleName.trim() === '') {
            this.showError('Please enter a title name');
            return;
        }

        this.isCreatingTitle = true;

        createAccountTitle({
            accountId: this.entityId,
            titleName: this.newTitleName.trim()
        })
        .then(titleId => {
            this.showSuccess('Account title created successfully');

            // Reload account titles
            return this.loadAccountTitles();
        })
        .then(() => {
            // Set the newly created title as selected
            const newOption = this.accountTitleOptions.find(opt => opt.label === this.newTitleName.trim());
            if (newOption) {
                this.newContact.accountTitleId = newOption.value;
            }

            this.handleCancelCreateTitle();
        })
        .catch(error => {
            this.showError('Failed to create title: ' + this.getErrorMessage(error));
        })
        .finally(() => {
            this.isCreatingTitle = false;
        });
    }

    /**
     * Handle cancel create title button click
     */
    handleCancelCreateTitle(event) {
        if (event) event.preventDefault();
        this.showCreateTitleForm = false;
        this.newTitleName = '';
    }

    // ========================================
    // Private Methods - Data Loading
    // ========================================

    /**
     * Load selected contact by ID
     */
    loadSelectedContact() {
        if (!this.selectedContactId) return;

        this.isLoading = true;
        getContactById({ contactId: this.selectedContactId })
            .then(result => {
                if (result) {
                    this.selectedContact = result;
                    this.notifyContactSelected(result);
                }
            })
            .catch(error => {
                this.showError('Failed to load selected contact: ' + this.getErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Load contact by ID
     */
    loadContactById(contactId) {
        if (!contactId) return;

        this.isLoading = true;

        // First validate the contact selection
        validateContactSelection({
            contactId: contactId,
            entityId: this.entityId
        })
        .then(validationResult => {
            if (!validationResult.isValid) {
                this.showError(validationResult.message || 'Invalid contact selection');
                return Promise.reject(new Error('Invalid contact'));
            }

            // If valid, load the contact details
            return getContactById({ contactId: contactId });
        })
        .then(result => {
            if (result) {
                this.selectedContact = result;

                // Update case if caseId provided
                if (this.caseId) {
                    return this.updateCaseContact(contactId);
                } else {
                    this.notifyContactSelected(result);
                    return Promise.resolve();
                }
            }
        })
        .catch(error => {
            if (error.message !== 'Invalid contact') {
                this.showError('Failed to load contact: ' + this.getErrorMessage(error));
            }
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    /**
     * Load recent contacts
     */
    loadRecentContacts() {
        if (!this.showRecentContacts || !this.entityId) return;

        // Use vendor contacts for vendor entity type
        if (this.entityType === 'vendor') {
            this.loadVendorContacts();
            return;
        }

        getRecentContacts({
            entityId: this.entityId,
            limitCount: this.recentContactLimit
        })
        .then(result => {
            this.recentContacts = result || [];
        })
        .catch(error => {
            console.error('Failed to load recent contacts:', error);
            this.recentContacts = [];
        });
    }

    /**
     * Load vendor contacts
     */
    loadVendorContacts() {
        if (!this.entityId) return;

        getVendorContacts({
            vendorId: this.entityId
        })
        .then(result => {
            this.recentContacts = result || [];
        })
        .catch(error => {
            console.error('Failed to load vendor contacts:', error);
            this.recentContacts = [];
        });
    }

    /**
     * Perform contact search
     */
    performSearch(searchCriteria) {
        this.isLoading = true;

        searchContacts({
            entityId: this.entityId,
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
     * Load account titles
     */
    loadAccountTitles() {
        if (!this.entityId) return Promise.resolve();

        return getAccountTitles({ accountId: this.entityId })
            .then(result => {
                this.accountTitleOptions = result || [];
            })
            .catch(error => {
                console.error('Failed to load account titles:', error);
                this.accountTitleOptions = [];
            });
    }

    /**
     * Load account departments
     */
    loadAccountDepartments() {
        if (!this.entityId) return;

        getAccountDepartments({ accountId: this.entityId })
            .then(result => {
                this.accountDepartmentOptions = result || [];
            })
            .catch(error => {
                console.error('Failed to load account departments:', error);
                this.accountDepartmentOptions = [];
            });
    }

    /**
     * Update case with selected contact
     */
    updateCaseContact(contactId) {
        return updateContactOnCase({
            caseId: this.caseId,
            contactId: contactId,
            entityId: this.entityId,
            entityType: this.entityType
        })
        .then(() => {
            this.notifyContactSelected(this.selectedContact);
        });
    }

    // ========================================
    // Private Methods - Validation & Utilities
    // ========================================

    /**
     * Validate contact form
     */
    validateContactForm() {
        if (!this.newContact.firstName || this.newContact.firstName.trim() === '') {
            this.showError('First name is required');
            return false;
        }

        if (!this.newContact.lastName || this.newContact.lastName.trim() === '') {
            this.showError('Last name is required');
            return false;
        }

        if (!this.newContact.accountTitleId) {
            this.showError('Account title is required');
            return false;
        }

        return true;
    }

    /**
     * Get empty contact object
     */
    getEmptyContact() {
        return {
            firstName: '',
            lastName: '',
            accountId: '',
            phone: '',
            email: '',
            mobilePhone: '',
            preferredMethod: '',
            phoneExtension: '',
            accountTitleId: '',
            accountDepartmentId: ''
        };
    }

    /**
     * Notify parent that contact was selected
     */
    notifyContactSelected(contact) {
        this.dispatchEvent(new CustomEvent('contactselect', {
            detail: {
                contactId: contact.id,
                contact: contact
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
     * Show success toast
     */
    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success'
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
     * Get selected contact
     */
    @api
    getSelectedContact() {
        return this.selectedContact;
    }

    /**
     * Get selected contact ID
     */
    @api
    getSelectedContactId() {
        return this.selectedContact ? this.selectedContact.id : null;
    }

    /**
     * Clear selection
     */
    @api
    clearSelection() {
        this.selectedContact = null;
        this.searchResults = [];

        const searchBase = this.template.querySelector('c-record-search-base');
        if (searchBase) {
            searchBase.clearSearch();
        }
    }

    /**
     * Set entity context programmatically
     */
    @api
    setEntityContext(entityId, entityName, entityType) {
        this.entityId = entityId;
        this.entityName = entityName;
        this.entityType = entityType || 'location';

        this.loadRecentContacts();
        this.loadAccountTitles();
        this.loadAccountDepartments();
    }
}
