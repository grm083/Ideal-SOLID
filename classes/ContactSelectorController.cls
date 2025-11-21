/**
 * Contact Selector Controller
 *
 * Unified LWC controller for contact search and selection.
 * Replaces SearchExistingContact Aura component functionality.
 *
 * Features:
 * - Context-aware contact search (filters by selected entity)
 * - Multi-field search: First Name, Last Name, Email, Phone, Mobile
 * - Duplicate detection
 * - Contact creation with account title/department management
 * - Recent contacts for quick selection
 * - Vendor contact search integration
 *
 * Refactored from: ContactSearchandCreate.cls
 *
 * @author George Martin
 * @date 2025-11-18
 */
public with sharing class ContactSelectorController {

    private static final String UNSPECIFIED = 'Unspecified';
    private static final Integer DEFAULT_LIMIT = 500;

    // ========================================
    // Contact Search Methods
    // ========================================

    /**
     * Search for contacts based on entity and search criteria
     *
     * Context-aware: Automatically filters by selected entity (Location/Vendor/Client)
     *
     * @param entityId The ID of the related account (Location/Vendor/Client)
     * @param searchCriteria Map of search fields and values
     * @return List of matching contacts
     */
    @AuraEnabled(cacheable=true)
    public static List<ContactSearchResult> searchContacts(String entityId, Map<String, String> searchCriteria) {
        try {
            if (String.isBlank(entityId)) {
                throw new AuraHandledException('Entity ID is required');
            }

            // Extract search criteria
            String firstName = searchCriteria.get('firstName');
            String lastName = searchCriteria.get('lastName');
            String email = searchCriteria.get('email');
            String phone = searchCriteria.get('phone');
            String mobile = searchCriteria.get('mobile');

            // Build dynamic query
            String query = buildContactSearchQuery(entityId, firstName, lastName, email, phone, mobile);

            UTIL_LoggingService.logDebug('ContactSelectorController.searchContacts',
                'Query: ' + query);

            List<Contact> contacts = Database.query(query);

            return buildContactSearchResults(contacts);

        } catch (Exception e) {
            UTIL_LoggingService.logError('ContactSelectorController.searchContacts',
                'Error searching contacts: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to search contacts: ' + e.getMessage());
        }
    }

    /**
     * Get recent contacts for an entity
     *
     * @param entityId The ID of the related account
     * @param limitCount Number of recent contacts to return
     * @return List of recent contacts
     */
    @AuraEnabled(cacheable=true)
    public static List<ContactSearchResult> getRecentContacts(String entityId, Integer limitCount) {
        try {
            if (String.isBlank(entityId)) {
                return new List<ContactSearchResult>();
            }

            Integer recordLimit = (limitCount != null && limitCount > 0) ? limitCount : 10;

            // Get account record type to determine contact query
            Account acc = [SELECT Id, RecordType.Name FROM Account WHERE Id = :entityId LIMIT 1];

            List<Contact> contacts;

            if (acc.RecordType.Name == Constant_Util.CLIENT) {
                // Direct client contacts
                contacts = [
                    SELECT Id, Name, FirstName, LastName, AccountNameForContact__c,
                           Tech_Contact_Account_Title__c, Phone, MobilePhone, Account.Name,
                           Email, Business_Rule_Association__c, Contact_Status__c,
                           Account_Title__r.Name, Last_Activity_Date__c
                    FROM Contact
                    WHERE Account.RecordType.Name = 'Client'
                    AND AccountId = :entityId
                    ORDER BY Last_Activity_Date__c DESC NULLS LAST
                    LIMIT :recordLimit
                ];
            } else {
                // Location-based contacts (from cases)
                contacts = [
                    SELECT Id, Name, FirstName, LastName, AccountNameForContact__c,
                           Tech_Contact_Account_Title__c, Phone, MobilePhone, Account.Name,
                           Email, Business_Rule_Association__c, Contact_Status__c,
                           Account_Title__r.Name, Last_Activity_Date__c
                    FROM Contact
                    WHERE Account.RecordType.Name = 'Client'
                    AND Id IN (SELECT ContactId FROM Case WHERE Location__c = :entityId)
                    ORDER BY Last_Activity_Date__c DESC NULLS LAST
                    LIMIT :recordLimit
                ];
            }

            return buildContactSearchResults(contacts);

        } catch (Exception e) {
            UTIL_LoggingService.logError('ContactSelectorController.getRecentContacts',
                'Error getting recent contacts: ' + e.getMessage(), e);
            return new List<ContactSearchResult>();
        }
    }

    /**
     * Get contact by ID with full details
     *
     * @param contactId The ID of the contact
     * @return Contact details
     */
    @AuraEnabled(cacheable=true)
    public static ContactSearchResult getContactById(String contactId) {
        try {
            if (String.isBlank(contactId)) {
                throw new AuraHandledException('Contact ID is required');
            }

            Contact con = [
                SELECT Id, Name, FirstName, LastName, Phone, MobilePhone, Email,
                       AccountId, Account.Name, Account_Title__c, Account_Title__r.Name,
                       Account_Department__c, Account_Department__r.Name,
                       Preferred_Method__c, Phone_Extension__c, Contact_Status__c,
                       Business_Rule_Association__c, Last_Activity_Date__c,
                       Location__c
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];

            return buildContactSearchResult(con);

        } catch (Exception e) {
            UTIL_LoggingService.logError('ContactSelectorController.getContactById',
                'Error getting contact: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to get contact: ' + e.getMessage());
        }
    }

    /**
     * Get vendor contacts via AccountContactRelation
     *
     * @param vendorId The ID of the vendor account
     * @return List of vendor contacts
     */
    @AuraEnabled(cacheable=true)
    public static List<ContactSearchResult> getVendorContacts(String vendorId) {
        try {
            if (String.isBlank(vendorId)) {
                return new List<ContactSearchResult>();
            }

            List<AccountContactRelation> relations = [
                SELECT ContactId, Contact.Name, Contact.FirstName, Contact.LastName,
                       Contact.Phone, Contact.MobilePhone, Contact.Email,
                       Contact.Preferred_Method__c, Contact.Contact_Status__c,
                       Contact.Account_Title__r.Name, Contact.Account.Name,
                       Type__c, Roles
                FROM AccountContactRelation
                WHERE AccountId = :vendorId
                ORDER BY Contact.Name
            ];

            List<ContactSearchResult> results = new List<ContactSearchResult>();

            for (AccountContactRelation rel : relations) {
                ContactSearchResult result = new ContactSearchResult();
                result.id = rel.ContactId;
                result.name = rel.Contact.Name;
                result.firstName = rel.Contact.FirstName;
                result.lastName = rel.Contact.LastName;
                result.phone = rel.Contact.Phone;
                result.mobilePhone = rel.Contact.MobilePhone;
                result.email = rel.Contact.Email;
                result.accountTitle = rel.Roles;
                result.accountName = rel.Contact.Account.Name;
                result.preferredMethod = rel.Contact.Preferred_Method__c;
                result.contactStatus = rel.Contact.Contact_Status__c;

                results.add(result);
            }

            return results;

        } catch (Exception e) {
            UTIL_LoggingService.logError('ContactSelectorController.getVendorContacts',
                'Error getting vendor contacts: ' + e.getMessage(), e);
            return new List<ContactSearchResult>();
        }
    }

    // ========================================
    // Contact Creation & Update Methods
    // ========================================

    /**
     * Check for duplicate contacts before creating new
     *
     * @param contactData Contact data to check
     * @param entityId The ID of the related account
     * @return List of potential duplicates (includes new contact as first item)
     */
    @AuraEnabled
    public static List<ContactSearchResult> checkDuplicateContact(String contactDataJson, String entityId) {
        try {
            ContactData data = (ContactData) JSON.deserialize(contactDataJson, ContactData.class);

            List<ContactSearchResult> results = new List<ContactSearchResult>();

            // Add the new contact as first item (with null ID)
            ContactSearchResult newContact = new ContactSearchResult();
            newContact.id = null;
            newContact.name = data.firstName + ' ' + data.lastName;
            newContact.firstName = data.firstName;
            newContact.lastName = data.lastName;
            newContact.phone = data.phone;
            newContact.email = data.email;
            newContact.mobilePhone = data.mobilePhone;
            newContact.accountTitle = getAccountTitleNameById(data.accountTitleId);

            results.add(newContact);

            // Query for potential duplicates
            String firstName = data.firstName;
            String lastName = data.lastName;
            String email = data.email;
            String phone = data.phone;
            String mobile = data.mobilePhone;
            Id accountId = data.accountId;

            List<Contact> duplicates = [
                SELECT Id, Name, FirstName, LastName, Phone, MobilePhone, Email,
                       Account_Title__r.Name, Account.Name, Business_Rule_Association__c,
                       Last_Activity_Date__c
                FROM Contact
                WHERE ((FirstName = :firstName AND LastName = :lastName)
                    OR (Email != '' AND Email = :email)
                    OR (Phone != '' AND Phone = :phone)
                    OR (MobilePhone != '' AND MobilePhone = :mobile))
                AND AccountId = :accountId
                ORDER BY Last_Activity_Date__c DESC NULLS LAST
            ];

            // Add duplicates to results
            for (Contact con : duplicates) {
                results.add(buildContactSearchResult(con));
            }

            return results;

        } catch (Exception e) {
            UTIL_LoggingService.logError('ContactSelectorController.checkDuplicateContact',
                'Error checking duplicates: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to check duplicates: ' + e.getMessage());
        }
    }

    /**
     * Create new contact
     *
     * @param contactDataJson JSON string of contact data
     * @param locationId The ID of the location (for Location__c field)
     * @return ID of created contact
     */
    @AuraEnabled
    public static String createContact(String contactDataJson, String locationId) {
        try {
            ContactData data = (ContactData) JSON.deserialize(contactDataJson, ContactData.class);

            Contact newContact = new Contact();
            newContact.FirstName = data.firstName;
            newContact.LastName = data.lastName;
            newContact.AccountId = data.accountId;
            newContact.Phone = data.phone;
            newContact.Email = data.email;
            newContact.MobilePhone = data.mobilePhone;
            newContact.Preferred_Method__c = data.preferredMethod;
            newContact.Phone_Extension__c = data.phoneExtension;
            newContact.Account_Title__c = data.accountTitleId;
            newContact.Business_Rule_Association__c = 'No';

            if (String.isNotBlank(locationId)) {
                newContact.Location__c = locationId;
            }

            if (String.isNotBlank(data.accountDepartmentId)) {
                newContact.Account_Department__c = data.accountDepartmentId;
            }

            insert newContact;

            UTIL_LoggingService.logDebug('ContactSelectorController.createContact',
                'Created contact: ' + newContact.Id);

            return newContact.Id;

        } catch (Exception e) {
            UTIL_LoggingService.logError('ContactSelectorController.createContact',
                'Error creating contact: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to create contact: ' + e.getMessage());
        }
    }

    /**
     * Update case with selected contact
     *
     * @param caseId The ID of the case
     * @param contactId The ID of the contact
     * @param entityId The ID of the entity (Location/Vendor/Client)
     * @param entityType Type of entity: 'location', 'vendor', 'client'
     */
    @AuraEnabled
    public static void updateContactOnCase(String caseId, String contactId, String entityId, String entityType) {
        try {
            // Get contact and validate status
            Contact con = [
                SELECT Id, FirstName, LastName, Contact_Status__c,
                       Account_Title__r.Status__c
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];

            // Check if account title is inactive
            if (con.Account_Title__r.Status__c == 'Inactive') {
                throw new AuraHandledException('Cannot select contact with inactive account title');
            }

            // Activate contact if inactive
            if (con.Contact_Status__c != 'Active') {
                con.Contact_Status__c = 'Active';
                update con;
            }

            // Update case
            Case caseRecord = [
                SELECT Id, ContactId, Location__c, Client__c, Requested_By_User__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            caseRecord.ContactId = contactId;
            caseRecord.Requested_By_User__c = null;

            update caseRecord;

            // Create/update account contact relationships
            if (entityType == 'location') {
                custRelationshipCheck(contactId, caseRecord.Client__c, caseRecord.Location__c);
            } else if (entityType == 'vendor' && String.isNotBlank(entityId)) {
                vendRelationshipCheck(contactId, entityId);
            }

            UTIL_LoggingService.logDebug('ContactSelectorController.updateContactOnCase',
                'Updated case ' + caseId + ' with contact ' + contactId);

        } catch (Exception e) {
            UTIL_LoggingService.logError('ContactSelectorController.updateContactOnCase',
                'Error updating contact on case: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to update contact: ' + e.getMessage());
        }
    }

    // ========================================
    // Supporting Data Methods
    // ========================================

    /**
     * Get account titles for an account
     *
     * @param accountId The ID of the account
     * @return List of account titles
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getAccountTitles(String accountId) {
        try {
            if (String.isBlank(accountId)) {
                return new List<PicklistOption>();
            }

            List<PicklistOption> options = new List<PicklistOption>();

            List<Account_Title__c> titles = [
                SELECT Id, Name
                FROM Account_Title__c
                WHERE Account__c = :accountId
                AND Status__c = 'Active'
                ORDER BY Name
            ];

            for (Account_Title__c title : titles) {
                options.add(new PicklistOption(title.Name, title.Id));
            }

            return options;

        } catch (Exception e) {
            UTIL_LoggingService.logError('ContactSelectorController.getAccountTitles',
                'Error getting account titles: ' + e.getMessage(), e);
            return new List<PicklistOption>();
        }
    }

    /**
     * Get account departments for an account
     *
     * @param accountId The ID of the account
     * @return List of account departments
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getAccountDepartments(String accountId) {
        try {
            if (String.isBlank(accountId)) {
                return new List<PicklistOption>();
            }

            List<PicklistOption> options = new List<PicklistOption>();

            List<Department__c> departments = [
                SELECT Id, Name
                FROM Department__c
                WHERE Account__c = :accountId
                ORDER BY Name
            ];

            for (Department__c dept : departments) {
                options.add(new PicklistOption(dept.Name, dept.Id));
            }

            return options;

        } catch (Exception e) {
            UTIL_LoggingService.logError('ContactSelectorController.getAccountDepartments',
                'Error getting account departments: ' + e.getMessage(), e);
            return new List<PicklistOption>();
        }
    }

    /**
     * Create new account title
     *
     * @param accountId The ID of the account
     * @param titleName The name of the new title
     * @return ID of created account title
     */
    @AuraEnabled
    public static String createAccountTitle(String accountId, String titleName) {
        try {
            Account_Title__c title = new Account_Title__c();
            title.Account__c = accountId;
            title.Name = titleName;
            title.Status__c = 'Active';

            insert title;

            UTIL_LoggingService.logDebug('ContactSelectorController.createAccountTitle',
                'Created account title: ' + title.Id);

            return title.Id;

        } catch (Exception e) {
            UTIL_LoggingService.logError('ContactSelectorController.createAccountTitle',
                'Error creating account title: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to create account title: ' + e.getMessage());
        }
    }

    /**
     * Get vendor roles from ACR picklist
     *
     * @return List of vendor roles
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getVendorRoles() {
        try {
            List<PicklistOption> options = new List<PicklistOption>();

            Schema.DescribeFieldResult fieldResult = AccountContactRelation.Roles.getDescribe();
            List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();

            for (Schema.PicklistEntry entry : entries) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }

            return options;

        } catch (Exception e) {
            UTIL_LoggingService.logError('ContactSelectorController.getVendorRoles',
                'Error getting vendor roles: ' + e.getMessage(), e);
            return new List<PicklistOption>();
        }
    }

    // ========================================
    // Validation Methods
    // ========================================

    /**
     * Validate contact selection
     *
     * @param contactId The ID of the contact
     * @param entityId The ID of the entity
     * @return Validation result
     */
    @AuraEnabled
    public static Map<String, Object> validateContactSelection(String contactId, String entityId) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('isValid', true);
        result.put('message', '');

        try {
            if (String.isBlank(contactId)) {
                result.put('isValid', false);
                result.put('message', 'Contact ID is required');
                return result;
            }

            // Check contact exists and is not inactive
            Contact con = [
                SELECT Id, Contact_Status__c, Account_Title__r.Status__c
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];

            if (con.Account_Title__r.Status__c == 'Inactive') {
                result.put('isValid', false);
                result.put('message', 'Contact has inactive account title');
                return result;
            }

            return result;

        } catch (Exception e) {
            result.put('isValid', false);
            result.put('message', 'Contact validation failed: ' + e.getMessage());
            return result;
        }
    }

    // ========================================
    // Private Helper Methods
    // ========================================

    /**
     * Build dynamic contact search query
     */
    private static String buildContactSearchQuery(String entityId, String firstName,
                                                  String lastName, String email,
                                                  String phone, String mobile) {

        String baseQuery = 'SELECT Id, Name, FirstName, LastName, AccountNameForContact__c, ' +
                          'Phone, MobilePhone, Email, Preferred_Method__c, Contact_Status__c, ' +
                          'Account_Title__r.Name, Account.Name, Business_Rule_Association__c, ' +
                          'Last_Activity_Date__c ' +
                          'FROM Contact WHERE ';

        List<String> conditions = new List<String>();

        // Entity condition
        conditions.add('(AccountId = :entityId OR Location__c = :entityId)');

        // Name conditions
        if (String.isNotBlank(firstName) && String.isNotBlank(lastName)) {
            String firstNamePattern = String.escapeSingleQuotes(firstName.trim()) + '%';
            String lastNamePattern = String.escapeSingleQuotes(lastName.trim()) + '%';
            conditions.add('(FirstName LIKE \'' + firstNamePattern + '\' OR LastName LIKE \'' + lastNamePattern + '\')');
        } else if (String.isNotBlank(firstName)) {
            String firstNamePattern = String.escapeSingleQuotes(firstName.trim()) + '%';
            conditions.add('FirstName LIKE \'' + firstNamePattern + '\'');
        } else if (String.isNotBlank(lastName)) {
            String lastNamePattern = String.escapeSingleQuotes(lastName.trim()) + '%';
            conditions.add('LastName LIKE \'' + lastNamePattern + '\'');
        }

        // Email condition
        if (String.isNotBlank(email)) {
            String emailEscaped = String.escapeSingleQuotes(email.trim());
            conditions.add('Email = \'' + emailEscaped + '\'');
        }

        // Phone condition
        if (String.isNotBlank(phone)) {
            String phoneEscaped = String.escapeSingleQuotes(phone.trim());
            conditions.add('Phone = \'' + phoneEscaped + '\'');
        }

        // Mobile condition
        if (String.isNotBlank(mobile)) {
            String mobileEscaped = String.escapeSingleQuotes(mobile.trim());
            conditions.add('MobilePhone = \'' + mobileEscaped + '\'');
        }

        String query = baseQuery + String.join(conditions, ' AND ') +
                      ' ORDER BY Last_Activity_Date__c DESC NULLS LAST LIMIT ' + DEFAULT_LIMIT;

        return query;
    }

    /**
     * Build contact search results from Contact list
     */
    private static List<ContactSearchResult> buildContactSearchResults(List<Contact> contacts) {
        List<ContactSearchResult> results = new List<ContactSearchResult>();

        for (Contact con : contacts) {
            // Filter out "Unspecified" contacts
            if (UNSPECIFIED.equalsIgnoreCase(con.FirstName) &&
                con.LastName.equalsIgnoreCase(con.AccountNameForContact__c)) {
                continue;
            }

            results.add(buildContactSearchResult(con));
        }

        return results;
    }

    /**
     * Build single contact search result
     */
    private static ContactSearchResult buildContactSearchResult(Contact con) {
        ContactSearchResult result = new ContactSearchResult();
        result.id = con.Id;
        result.name = con.Name;
        result.firstName = con.FirstName;
        result.lastName = con.LastName;
        result.phone = con.Phone;
        result.mobilePhone = con.MobilePhone;
        result.email = con.Email;
        result.accountTitle = con.Account_Title__r != null ? con.Account_Title__r.Name : '';
        result.accountName = con.Account != null ? con.Account.Name : '';
        result.businessRuleAssociation = con.Business_Rule_Association__c;
        result.contactStatus = con.Contact_Status__c;

        if (con.Last_Activity_Date__c != null) {
            result.lastActivityDate = String.valueOf(con.Last_Activity_Date__c);
        }

        return result;
    }

    /**
     * Get account title name by ID
     */
    private static String getAccountTitleNameById(String accountTitleId) {
        if (String.isBlank(accountTitleId)) {
            return '';
        }

        try {
            Account_Title__c title = [SELECT Id, Name FROM Account_Title__c WHERE Id = :accountTitleId LIMIT 1];
            return title.Name;
        } catch (Exception e) {
            return '';
        }
    }

    /**
     * Create customer account contact relationships
     */
    private static void custRelationshipCheck(Id contactId, Id clientId, Id locationId) {
        Contact con = [
            SELECT Id, Account_Title__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        // Check client relationship
        if (clientId != null) {
            List<AccountContactRelation> clientRel = [
                SELECT Id FROM AccountContactRelation
                WHERE ContactId = :contactId AND AccountId = :clientId
                LIMIT 1
            ];

            if (clientRel.isEmpty()) {
                AccountContactRelation acr = new AccountContactRelation();
                acr.AccountId = clientId;
                acr.Account_Title__c = con.Account_Title__c;
                acr.Type__c = 'Customer';
                acr.ContactId = contactId;
                insert acr;
            }
        }

        // Check location relationship
        if (locationId != null) {
            List<AccountContactRelation> locationRel = [
                SELECT Id FROM AccountContactRelation
                WHERE ContactId = :contactId AND AccountId = :locationId
                LIMIT 1
            ];

            if (locationRel.isEmpty()) {
                AccountContactRelation acr = new AccountContactRelation();
                acr.AccountId = locationId;
                acr.Account_Title__c = con.Account_Title__c;
                acr.Type__c = 'Customer';
                acr.ContactId = contactId;
                insert acr;
            }
        }
    }

    /**
     * Create vendor account contact relationship
     */
    private static void vendRelationshipCheck(Id contactId, Id vendorId) {
        Contact con = [
            SELECT Id, Account_Title__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        List<AccountContactRelation> vendorRel = [
            SELECT Id FROM AccountContactRelation
            WHERE ContactId = :contactId AND AccountId = :vendorId
            LIMIT 1
        ];

        if (vendorRel.isEmpty()) {
            AccountContactRelation acr = new AccountContactRelation();
            acr.AccountId = vendorId;
            acr.Account_Title__c = con.Account_Title__c;
            acr.Type__c = 'Vendor';
            acr.ContactId = contactId;
            insert acr;
        }
    }

    // ========================================
    // Wrapper Classes
    // ========================================

    /**
     * Contact Search Result Wrapper
     */
    public class ContactSearchResult {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String mobilePhone { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String accountTitle { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String businessRuleAssociation { get; set; }
        @AuraEnabled public String contactStatus { get; set; }
        @AuraEnabled public String lastActivityDate { get; set; }
    }

    /**
     * Contact Data Input Wrapper
     */
    public class ContactData {
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String accountId { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String mobilePhone { get; set; }
        @AuraEnabled public String preferredMethod { get; set; }
        @AuraEnabled public String phoneExtension { get; set; }
        @AuraEnabled public String accountTitleId { get; set; }
        @AuraEnabled public String accountDepartmentId { get; set; }
    }

    /**
     * Picklist Option Wrapper
     */
    public class PicklistOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
}
