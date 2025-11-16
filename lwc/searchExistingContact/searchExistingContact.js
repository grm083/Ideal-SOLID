import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import Apex methods
import returnCase from '@salesforce/apex/ContactSearchandCreate.returnCase';
import searchContacts from '@salesforce/apex/ContactSearchandCreate.searchContacts';
import searchLocCont from '@salesforce/apex/ContactSearchandCreate.searchLocCont';
import returnVendors from '@salesforce/apex/ContactSearchandCreate.returnVendors';
import getVendorContacts from '@salesforce/apex/ContactSearchandCreate.getVendorContacts';
import getAccountTitles from '@salesforce/apex/ContactSearchandCreate.getAccountTitles';
import getAccountDepts from '@salesforce/apex/ContactSearchandCreate.getAccountDepts';
import checkDuplicateContacts from '@salesforce/apex/ContactSearchandCreate.checkDuplicateContacts';
import createNewContact from '@salesforce/apex/ContactSearchandCreate.createNewContact';
import createNewVenContact from '@salesforce/apex/ContactSearchandCreate.createNewVenContact';
import existingContact from '@salesforce/apex/ContactSearchandCreate.existingContact';
import getUsers from '@salesforce/apex/ContactSearchandCreate.getUsers';
import saveUserToCase from '@salesforce/apex/ContactSearchandCreate.saveUserToCase';

/**
 * SearchExistingContact - LWC component for contact search and creation
 * Converted from Aura component: aura/SearchExistingContact
 *
 * @description Extremely complex modal component with three operational modes:
 * - Customer Contact: Search/create customer contacts
 * - Vendor Contact: Search/create vendor contacts
 * - Internal User: Search for internal WM users
 *
 * Features:
 * - Multi-field contact search (first name, last name, email, phone, mobile)
 * - Vendor search with two-step process (vendor selection → contact selection)
 * - Internal user search
 * - New contact creation with duplicate detection
 * - Account title and department management
 * - Complex validation rules
 * - Conditional field requirements based on contact type
 *
 * NOTE: This is one of the largest Aura components (685 lines) with extensive
 * complexity. Full conversion requires:
 * - c-create-new-account-title child component (for adding new titles)
 * - Complex state management for 3 different modes
 * - Extensive validation logic
 * - Duplicate contact modal with selection capability
 */
export default class SearchExistingContact extends LightningElement {
    // Public properties
    @api recordId;
    @api showForm = true;
    @api isVendor = false;
    @api isClient = false;

    // Contact type state (Customer, Vendor, Internal)
    @track boolCustomer = true;
    @track boolVendor = false;
    @track boolInternal = false;
    @track conType = 'Customer';

    // UI display state
    @track boolNewContact = false;
    @track boolSOSL = false;
    @track showSearch = false;
    @track boolShowNew = false;
    @track boolEdit = false;
    @track boolShowUser = false;
    @track boolReadOnly = false;
    @track isOpen = false; // Duplicate modal

    // Case-derived data
    @track caseAccount = '';
    @track locAccount = '';
    @track caseContact = '';
    @track caseUser = '';
    @track caseStatus = '';
    @track vendorAcc = '';
    @track vendorAccount = '';
    @track vendorName = '';
    @track caseObj = {};

    // Search fields
    @track searchString = '';
    @track userString = '';
    @track searchFirstName = '';
    @track searchLastName = '';
    @track searchEmail = '';
    @track searchPhone = '';
    @track searchMobile = '';

    // Results and selections
    @track soslContacts = [];
    @track dupContacts = [];
    @track vendorAccts = [];
    @track contactId = '';
    @track userId = '';

    // New contact fields
    @track firstName = '';
    @track lastName = '';
    @track phone = '';
    @track email = '';
    @track title = '';
    @track preferred = '';
    @track extension = '';

    // Picklist options
    @track accountTitles = [];
    @track accountDepts = [];
    @track selDept = '';

    // Table columns
    soslColumns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'Title', fieldName: 'Title', type: 'text' },
        { label: 'Phone', fieldName: 'Phone', type: 'text' },
        { label: 'Email', fieldName: 'Email', type: 'text' }
    ];

    dupColumns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'Title', fieldName: 'Title', type: 'text' },
        { label: 'Phone', fieldName: 'Phone', type: 'text' },
        { label: 'Email', fieldName: 'Email', type: 'text' },
        { label: 'BR Association', fieldName: 'BusinessRuleAssociation', type: 'text' },
        { label: 'Last Activity', fieldName: 'LastActivityDate', type: 'datetime' }
    ];

    vendorColumns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'VID', fieldName: 'VID', type: 'text' }
    ];

    // Display fields for record forms
    contactDisplayFields = [
        'Name', 'Account_Title__c', 'Phone', 'Phone_Extension__c',
        'MobilePhone', 'Email', 'Preferred_Method__c', 'Email_Validated__c', 'Date_Validated__c'
    ];

    userDisplayFields = ['Name', 'Title', 'Phone', 'Email', 'AboutMe'];

    // Computed properties
    get isLocation() {
        return !this.isVendor && !this.isClient;
    }

    get showCustomerSearch() {
        return this.boolCustomer && (this.caseAccount || this.caseObj.Case_Sub_Type__c === 'New Client');
    }

    get showVendorSearch() {
        return this.boolVendor && (this.vendorAcc || this.caseObj.Case_Sub_Type__c === 'New Vendor');
    }

    get showLocationSearch() {
        return this.isLocation && (this.locAccount || this.caseObj.Case_Sub_Type__c === 'New Location');
    }

    get showContactInterface() {
        return !this.caseContact || this.boolEdit;
    }

    get preferredOptions() {
        return [
            { label: '', value: '' },
            { label: 'Email', value: 'Email' },
            { label: 'Phone', value: 'Phone' },
            { label: 'Mobile', value: 'MobilePhone' }
        ];
    }

    // Lifecycle Hooks
    async connectedCallback() {
        await this.loadCaseData();
    }

    // Data Loading Methods
    async loadCaseData() {
        try {
            const caseData = await returnCase({ recordId: this.recordId });

            this.caseObj = caseData;
            this.caseAccount = caseData.Client__c;
            this.locAccount = caseData.Location__c;
            this.vendorAcc = caseData.Supplier__c;
            this.caseContact = caseData.ContactId;
            this.caseUser = caseData.Requested_By_User__c;
            this.caseStatus = caseData.Status;

            this.boolShowUser = !!this.caseUser;

            // Load location contacts if applicable
            const accountToSearch = this.isLocation ? this.locAccount : this.isClient ? this.caseAccount : null;
            if (accountToSearch) {
                await this.loadLocationContacts(accountToSearch);
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error loading case data', 'error');
        }
    }

    async loadLocationContacts(accountId) {
        try {
            const results = await searchLocCont({ locId: accountId });
            this.soslContacts = results || [];
            this.boolSOSL = true;
        } catch (error) {
            console.error('Error loading location contacts:', error);
        }
    }

    // Button Click Handlers - Contact Type Selection
    handleCustomerClick() {
        this.resetContactType();
        this.boolCustomer = !this.boolCustomer;
        this.conType = 'Customer';

        if (this.boolCustomer) {
            this.boolVendor = false;
            this.boolInternal = false;

            const accountToSearch = this.isLocation ? this.locAccount : this.isClient ? this.caseAccount : null;
            if (accountToSearch) {
                this.loadLocationContacts(accountToSearch);
            }
        }
    }

    handleVendorClick() {
        this.resetContactType();
        this.boolVendor = !this.boolVendor;
        this.conType = 'Vendor';

        if (this.boolVendor) {
            this.boolCustomer = false;
            this.boolInternal = false;
            this.loadVendors();
        }
    }

    handleInternalClick() {
        this.resetContactType();
        this.boolInternal = !this.boolInternal;

        if (this.boolInternal) {
            this.boolCustomer = false;
            this.boolVendor = false;
        }
    }

    resetContactType() {
        this.contactId = '';
        this.userId = '';
        this.soslContacts = [];
        this.boolNewContact = false;
        this.boolShowNew = false;
        this.searchString = '';
        this.userString = '';
        this.resetSearchFields();
        this.resetNewContactFields();
    }

    resetSearchFields() {
        this.searchFirstName = '';
        this.searchLastName = '';
        this.searchEmail = '';
        this.searchPhone = '';
        this.searchMobile = '';
    }

    resetNewContactFields() {
        this.firstName = '';
        this.lastName = '';
        this.phone = '';
        this.email = '';
        this.title = '';
        this.preferred = '';
        this.extension = '';
    }

    // Search Methods
    async handleContactSearch() {
        if (this.searchFirstName.length < 3 && this.searchLastName.length < 3) {
            return;
        }

        try {
            const relevantAcct = this.isClient ? this.caseAccount : this.locAccount;

            const results = await searchContacts({
                firstName: this.searchFirstName,
                lastName: this.searchLastName,
                email: this.searchEmail,
                phone: this.searchPhone,
                mobile: this.searchMobile,
                acct: relevantAcct,
                caseId: this.recordId
            });

            // Highlight business rule associations
            const compareStr = 'Yes';
            results.forEach(record => {
                if (record.BusinessRuleAssociation) {
                    record.showClass = record.BusinessRuleAssociation.toLowerCase() === compareStr.toLowerCase()
                        ? 'bgHighlight' : 'noBgHighlight';
                }
            });

            this.soslContacts = results || [];
            this.boolShowNew = true;
            this.contactId = '';
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error searching contacts', 'error');
        }
    }

    async loadVendors() {
        try {
            const vendors = await returnVendors({ acct: this.locAccount });
            this.vendorAccts = vendors || [];
            this.showSearch = false;
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error loading vendors', 'error');
        }
    }

    async handleUserSearch() {
        if (this.userString.length < 3) return;

        try {
            const results = await getUsers({ query: this.userString });
            this.soslContacts = results || [];
            this.userId = '';
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error searching users', 'error');
        }
    }

    // Selection Handlers
    handleContactRowSelection(event) {
        const selectedRows = event.detail.selectedRows;

        if (selectedRows && selectedRows.length > 0) {
            const contactId = selectedRows[0].ContactId;

            if (contactId) {
                this.contactId = contactId;
                this.boolNewContact = false;

                // Check if read-only for vendor contacts
                if (this.boolVendor && selectedRows[0].Title) {
                    this.boolReadOnly = true;
                } else {
                    this.boolReadOnly = false;
                }
            } else {
                // Duplicate row selected - trigger new contact creation
                this.handleNewContact();
            }
        }
    }

    handleVendorRowSelection(event) {
        const selectedRows = event.detail.selectedRows;

        if (selectedRows && selectedRows.length > 0) {
            this.vendorAccount = selectedRows[0].AccountId;
            this.vendorName = selectedRows[0].Name;
            this.loadVendorContacts();
        }
    }

    async loadVendorContacts() {
        try {
            const results = await getVendorContacts({ vendor: this.vendorAccount });
            this.soslContacts = results || [];
            this.showSearch = true;
            this.boolShowNew = true;
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error loading vendor contacts', 'error');
        }
    }

    handleUserRowSelection(event) {
        const selectedRows = event.detail.selectedRows;

        if (selectedRows && selectedRows.length > 0) {
            this.userId = selectedRows[0].ContactId;
        }
    }

    // New Contact Methods
    async handleNewContact() {
        // Pre-fill from search
        this.firstName = this.searchFirstName;
        this.lastName = this.searchLastName;
        this.phone = this.searchPhone;
        this.email = this.searchEmail;

        this.contactId = '';
        this.boolNewContact = true;

        // Load picklists for customer contacts
        if (this.boolCustomer) {
            await this.loadAccountTitles();
            await this.loadAccountDepts();
        } else if (this.boolVendor) {
            this.lastName = this.vendorName;
        }
    }

    async loadAccountTitles() {
        try {
            const titles = await getAccountTitles({ acct: this.caseAccount });
            this.accountTitles = titles || [];
        } catch (error) {
            console.error('Error loading titles:', error);
        }
    }

    async loadAccountDepts() {
        try {
            const depts = await getAccountDepts({ acct: this.caseAccount });
            this.accountDepts = depts || [];
        } catch (error) {
            console.error('Error loading departments:', error);
        }
    }

    // Save Methods
    async handleSaveNewContact() {
        // Validation
        if (!this.phone && !this.email) {
            this.showToast('Error', 'You must enter either an email or phone number', 'error');
            return;
        }

        if (!this.firstName || !this.lastName || !this.preferred) {
            this.showToast('Error', 'Please complete all required fields', 'error');
            return;
        }

        if (this.boolCustomer && !this.title) {
            this.showToast('Error', 'Title is required for customer contacts', 'error');
            return;
        }

        // Check for duplicates (customer only)
        if (this.boolCustomer) {
            await this.checkForDuplicates();
        } else if (this.boolVendor) {
            await this.saveNewVendorContact();
        }
    }

    async checkForDuplicates() {
        try {
            const results = await checkDuplicateContacts({
                firstName: this.firstName,
                lastName: this.lastName,
                email: this.email,
                phone: this.phone,
                mobile: '',
                accountId: this.caseAccount,
                title: this.title,
                department: this.selDept,
                preferred: this.preferred,
                extension: this.extension,
                caseId: this.recordId
            });

            if (results && results.length > 1) {
                // Show duplicate modal
                this.dupContacts = results;
                this.isOpen = true;
                this.showForm = false;
            } else {
                // No duplicates, create contact
                await this.saveNewCustomerContact();
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error checking duplicates', 'error');
        }
    }

    async saveNewCustomerContact() {
        try {
            const newContactId = await createNewContact({
                firstName: this.firstName,
                lastName: this.lastName,
                accountId: this.caseAccount,
                caseId: this.recordId,
                phone: this.phone,
                email: this.email,
                title: this.title,
                department: this.selDept,
                preferred: this.preferred,
                extension: this.extension
            });

            this.contactId = newContactId;
            this.boolNewContact = false;
            this.resetSearchFields();
            this.showToast('Success', 'Contact created successfully', 'success');
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error creating contact', 'error');
        }
    }

    async saveNewVendorContact() {
        try {
            const newContactId = await createNewVenContact({
                firstName: this.firstName,
                lastName: this.lastName,
                accountId: this.vendorAccount,
                phone: this.phone,
                email: this.email,
                preferred: this.preferred,
                extension: this.extension
            });

            this.contactId = newContactId;
            this.boolNewContact = false;
            this.resetSearchFields();
            this.showToast('Success', 'Vendor contact created successfully', 'success');
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error creating vendor contact', 'error');
        }
    }

    async handleSaveExistingContact() {
        try {
            const relevantAcct = this.boolCustomer ? this.caseAccount : this.vendorAccount;

            const hasInactiveTitle = await existingContact({
                caseId: this.recordId,
                accountId: relevantAcct,
                contactId: this.contactId,
                type: this.conType
            });

            if (hasInactiveTitle) {
                this.showToast('Error',
                    'Contact\'s Account Title is inactive. Please update the Account Title on the contact to move forward.',
                    'error');
            } else {
                this.showForm = false;
                this.dispatchEvent(new CustomEvent('refresh'));
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
                this.showToast('Success', 'Contact saved to case', 'success');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error saving contact', 'error');
        }
    }

    async handleSaveUser() {
        try {
            await saveUserToCase({
                caseId: this.recordId,
                userId: this.userId
            });

            this.showForm = false;
            this.dispatchEvent(new CustomEvent('refresh'));
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            this.showToast('Success', 'User saved to case', 'success');
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error saving user', 'error');
        }
    }

    // Modal Actions
    handleCloseModal() {
        this.showForm = false;
        this.resetSearchFields();
        this.resetNewContactFields();
        this.boolShowNew = false;
    }

    handleCloseDuplicateModal() {
        this.isOpen = false;
        this.showForm = true;
    }

    handleChangeContact() {
        this.boolEdit = !this.boolEdit;
    }

    // Helper Methods
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissible'
        });
        this.dispatchEvent(event);
    }
}
