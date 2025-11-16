/**
 * @description TestDataFactory - Centralized test data creation for all test classes
 *
 * This factory class provides methods to create test data for all custom and standard
 * objects used in the application. It ensures consistent test data across all test classes
 * and reduces code duplication.
 *
 * Design Principles:
 * - All methods return SObjects that are NOT inserted by default
 * - Callers can modify returned objects before inserting
 * - Provides bulk creation methods for performance testing
 * - Uses realistic data that passes all validation rules
 * - Supports relationship building (Account -> Contact -> Case)
 *
 * @author Waste Management
 * @date 2025
 * @group Test Utilities
 */
@isTest
public class TestDataFactory {

    // ========================================================================
    // ACCOUNT CREATION METHODS
    // ========================================================================

    /**
     * @description Create a test Account with client/location configuration
     * @param accountType 'Client', 'Location', or 'Vendor'
     * @param recordTypeDevName Developer name of record type
     * @return Account Not inserted
     */
    public static Account createAccount(String accountType, String recordTypeDevName) {
        Account acc = new Account(
            Name = accountType + ' Test Account ' + System.now().getTime(),
            RecordTypeId = getRecordTypeId('Account', recordTypeDevName),
            BillingStreet = '123 Test St',
            BillingCity = 'Test City',
            BillingState = 'CA',
            BillingPostalCode = '90210',
            BillingCountry = 'United States',
            Phone = '555-0100'
        );

        // Add client-specific fields
        if (accountType == 'Client') {
            acc.Customer_Code__c = 'CUST' + String.valueOf(System.now().getTime()).substring(0, 8);
            acc.Primary_Segment__c = 'Commercial';
            acc.Vendor_ID__c = 'VEN' + String.valueOf(System.now().getTime()).substring(0, 6);
        }

        // Add location-specific fields
        if (accountType == 'Location') {
            acc.Location_Code__c = 'LOC' + String.valueOf(System.now().getTime()).substring(0, 8);
            acc.Location_Type__c = 'Commercial';
            acc.tz__Timezone__c = 'America/Los_Angeles';
            acc.tz__Timezone_SFDC__c = 'America/Los_Angeles';
            acc.Brand__c = 'Waste Management';
            acc.Geography__c = 'West';
            acc.Division__c = 'Pacific';
        }

        return acc;
    }

    /**
     * @description Create multiple test Accounts
     * @param count Number of accounts to create
     * @param accountType 'Client', 'Location', or 'Vendor'
     * @return List<Account> Not inserted
     */
    public static List<Account> createAccounts(Integer count, String accountType, String recordTypeDevName) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            Account acc = createAccount(accountType, recordTypeDevName);
            acc.Name = accountType + ' Test Account ' + i + ' ' + System.now().getTime();
            accounts.add(acc);
        }
        return accounts;
    }

    // ========================================================================
    // CONTACT CREATION METHODS
    // ========================================================================

    /**
     * @description Create a test Contact
     * @param accountId Account to associate contact with
     * @return Contact Not inserted
     */
    public static Contact createContact(Id accountId) {
        return new Contact(
            FirstName = 'Test',
            LastName = 'Contact ' + System.now().getTime(),
            Email = 'test.contact' + System.now().getTime() + '@example.com',
            Phone = '555-0101',
            MobilePhone = '555-0102',
            AccountId = accountId,
            Preferred_Method__c = 'Email',
            Email_Validated__c = true,
            Account_Title__c = 'Manager'
        );
    }

    /**
     * @description Create multiple test Contacts
     * @param count Number of contacts to create
     * @param accountId Account to associate contacts with
     * @return List<Contact> Not inserted
     */
    public static List<Contact> createContacts(Integer count, Id accountId) {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            Contact con = createContact(accountId);
            con.LastName = 'Contact ' + i + ' ' + System.now().getTime();
            con.Email = 'test.contact' + i + '.' + System.now().getTime() + '@example.com';
            contacts.add(con);
        }
        return contacts;
    }

    // ========================================================================
    // ASSET CREATION METHODS
    // ========================================================================

    /**
     * @description Create a test Asset
     * @param accountId Account to associate asset with
     * @param productId Product2 Id for the asset
     * @return Asset Not inserted
     */
    public static Asset createAsset(Id accountId, Id productId) {
        return new Asset(
            Name = 'Test Asset ' + System.now().getTime(),
            AccountId = accountId,
            Product2Id = productId,
            Acorn_SID__c = 'SID' + String.valueOf(System.now().getTime()).substring(0, 8),
            Status = 'Installed',
            Sensitivity_Code__c = 'Normal',
            Equipment_Type__c = 'Open Top',
            Duration__c = 'Permanent',
            ProductFamily = 'Rolloff'
        );
    }

    /**
     * @description Create multiple test Assets
     * @param count Number of assets to create
     * @param accountId Account to associate assets with
     * @param productId Product2 Id for the assets
     * @return List<Asset> Not inserted
     */
    public static List<Asset> createAssets(Integer count, Id accountId, Id productId) {
        List<Asset> assets = new List<Asset>();
        for (Integer i = 0; i < count; i++) {
            Asset ast = createAsset(accountId, productId);
            ast.Name = 'Test Asset ' + i + ' ' + System.now().getTime();
            ast.Acorn_SID__c = 'SID' + i + String.valueOf(System.now().getTime()).substring(0, 6);
            assets.add(ast);
        }
        return assets;
    }

    // ========================================================================
    // PRODUCT CREATION METHODS
    // ========================================================================

    /**
     * @description Create a test Product2
     * @param productFamily Product family (Rolloff, Commercial, etc.)
     * @return Product2 Not inserted
     */
    public static Product2 createProduct(String productFamily) {
        return new Product2(
            Name = 'Test Product ' + productFamily + ' ' + System.now().getTime(),
            ProductCode = 'PROD' + String.valueOf(System.now().getTime()).substring(0, 6),
            IsActive = true,
            Family = productFamily,
            ProductTypeSelected__c = productFamily
        );
    }

    /**
     * @description Create multiple test Products
     * @param count Number of products to create
     * @param productFamily Product family
     * @return List<Product2> Not inserted
     */
    public static List<Product2> createProducts(Integer count, String productFamily) {
        List<Product2> products = new List<Product2>();
        for (Integer i = 0; i < count; i++) {
            Product2 prod = createProduct(productFamily);
            prod.Name = 'Test Product ' + productFamily + ' ' + i + ' ' + System.now().getTime();
            prod.ProductCode = 'PROD' + i + String.valueOf(System.now().getTime()).substring(0, 5);
            products.add(prod);
        }
        return products;
    }

    // ========================================================================
    // CASE CREATION METHODS
    // ========================================================================

    /**
     * @description Create a test Case with all required fields
     * @param recordTypeDevName Developer name of Case record type
     * @return Case Not inserted
     */
    public static Case createCase(String recordTypeDevName) {
        return new Case(
            RecordTypeId = getRecordTypeId('Case', recordTypeDevName),
            Status = 'New',
            Origin = 'Phone',
            Case_Type__c = 'Pickup',
            Case_Sub_Type__c = 'Extra Pickup',
            Subject = 'Test Case ' + System.now().getTime(),
            Description = 'Test case description',
            Reference_Number__c = 'REF' + String.valueOf(System.now().getTime()).substring(0, 10),
            Service_Date__c = Date.today().addDays(7),
            PurchaseOrder_Number__c = 'PO' + String.valueOf(System.now().getTime()).substring(0, 8),
            Profile_Number__c = 'PROF' + String.valueOf(System.now().getTime()).substring(0, 6),
            Company_Category__c = 'Test Category',
            Chargeable__c = 'Yes'
        );
    }

    /**
     * @description Create a fully populated Case with relationships
     * @param clientId Client Account Id
     * @param locationId Location Account Id
     * @param contactId Contact Id
     * @param assetId Asset Id
     * @param recordTypeDevName Developer name of Case record type
     * @return Case Not inserted
     */
    public static Case createCaseWithRelationships(
        Id clientId,
        Id locationId,
        Id contactId,
        Id assetId,
        String recordTypeDevName
    ) {
        Case c = createCase(recordTypeDevName);
        c.Client__c = clientId;
        c.Location__c = locationId;
        c.ContactId = contactId;
        c.AssetId = assetId;
        c.AccountId = locationId; // Standard field
        return c;
    }

    /**
     * @description Create multiple test Cases
     * @param count Number of cases to create
     * @param recordTypeDevName Developer name of Case record type
     * @return List<Case> Not inserted
     */
    public static List<Case> createCases(Integer count, String recordTypeDevName) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            Case c = createCase(recordTypeDevName);
            c.Subject = 'Test Case ' + i + ' ' + System.now().getTime();
            c.Reference_Number__c = 'REF' + i + String.valueOf(System.now().getTime()).substring(0, 8);
            cases.add(c);
        }
        return cases;
    }

    // ========================================================================
    // TASK CREATION METHODS
    // ========================================================================

    /**
     * @description Create a test Task
     * @param whatId Related Case/Account Id
     * @param whoId Related Contact Id
     * @return Task Not inserted
     */
    public static Task createTask(Id whatId, Id whoId) {
        return new Task(
            Subject = 'Test Task ' + System.now().getTime(),
            Status = 'Not Started',
            Priority = 'Normal',
            ActivityDate = Date.today().addDays(1),
            WhatId = whatId,
            WhoId = whoId,
            Description = 'Test task description'
        );
    }

    /**
     * @description Create multiple test Tasks
     * @param count Number of tasks to create
     * @param whatId Related Case/Account Id
     * @return List<Task> Not inserted
     */
    public static List<Task> createTasks(Integer count, Id whatId) {
        List<Task> tasks = new List<Task>();
        for (Integer i = 0; i < count; i++) {
            Task t = createTask(whatId, null);
            t.Subject = 'Test Task ' + i + ' ' + System.now().getTime();
            tasks.add(t);
        }
        return tasks;
    }

    // ========================================================================
    // OPPORTUNITY/QUOTE CREATION METHODS
    // ========================================================================

    /**
     * @description Create a test Opportunity
     * @param accountId Account to associate opportunity with
     * @return Opportunity Not inserted
     */
    public static Opportunity createOpportunity(Id accountId) {
        return new Opportunity(
            Name = 'Test Opportunity ' + System.now().getTime(),
            AccountId = accountId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 10000,
            Probability = 50,
            Type = 'New Business'
        );
    }

    /**
     * @description Create a test Quote
     * @param opportunityId Opportunity to associate quote with
     * @return Quote Not inserted
     */
    public static Quote createQuote(Id opportunityId) {
        return new Quote(
            Name = 'Test Quote ' + System.now().getTime(),
            OpportunityId = opportunityId,
            Status = 'Draft',
            ExpirationDate = Date.today().addDays(30)
        );
    }

    // ========================================================================
    // USER CREATION METHODS
    // ========================================================================

    /**
     * @description Create a test User
     * @param profileName Profile name for the user
     * @return User Not inserted
     */
    public static User createUser(String profileName) {
        Profile prof = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];

        String uniqueStr = String.valueOf(System.now().getTime());

        return new User(
            FirstName = 'Test',
            LastName = 'User ' + uniqueStr,
            Email = 'testuser' + uniqueStr + '@test.com',
            Username = 'testuser' + uniqueStr + '@test.wm.com.test',
            Alias = 'tuser' + uniqueStr.substring(0, 4),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = prof.Id,
            IsActive = true
        );
    }

    // ========================================================================
    // UTILITY METHODS
    // ========================================================================

    /**
     * @description Get RecordTypeId by object and developer name
     * @param objectName SObject type name
     * @param developerName Developer name of record type
     * @return Id RecordType Id
     */
    public static Id getRecordTypeId(String objectName, String developerName) {
        try {
            return Schema.getGlobalDescribe()
                .get(objectName)
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get(developerName)
                .getRecordTypeId();
        } catch (Exception e) {
            // Return null if record type doesn't exist (tests can handle gracefully)
            return null;
        }
    }

    /**
     * @description Create a complete test data hierarchy
     * @return Map<String, Object> containing all created test data
     *
     * Returns map with keys:
     * - 'clientAccount' : Account
     * - 'locationAccount' : Account
     * - 'vendorAccount' : Account
     * - 'contact' : Contact
     * - 'product' : Product2
     * - 'asset' : Asset
     * - 'case' : Case
     * - 'opportunity' : Opportunity
     * - 'quote' : Quote
     *
     * All objects are inserted and ready to use
     */
    public static Map<String, Object> createFullTestHierarchy() {
        Map<String, Object> testData = new Map<String, Object>();

        // Create Accounts
        Account clientAccount = createAccount('Client', 'Client');
        insert clientAccount;
        testData.put('clientAccount', clientAccount);

        Account locationAccount = createAccount('Location', 'Location');
        locationAccount.ParentId = clientAccount.Id;
        insert locationAccount;
        testData.put('locationAccount', locationAccount);

        Account vendorAccount = createAccount('Vendor', 'Vendor');
        insert vendorAccount;
        testData.put('vendorAccount', vendorAccount);

        // Create Contact
        Contact con = createContact(clientAccount.Id);
        insert con;
        testData.put('contact', con);

        // Create Product and Asset
        Product2 prod = createProduct('Rolloff');
        insert prod;
        testData.put('product', prod);

        Asset ast = createAsset(locationAccount.Id, prod.Id);
        insert ast;
        testData.put('asset', ast);

        // Create Case
        Case c = createCaseWithRelationships(
            clientAccount.Id,
            locationAccount.Id,
            con.Id,
            ast.Id,
            'Service_Request'
        );
        insert c;
        testData.put('case', c);

        // Create Opportunity and Quote
        Opportunity opp = createOpportunity(clientAccount.Id);
        insert opp;
        testData.put('opportunity', opp);

        Quote q = createQuote(opp.Id);
        insert q;
        testData.put('quote', q);

        return testData;
    }

    /**
     * @description Create test data without relationships (for unit tests)
     * @return Map<String, SObject> with basic test data
     */
    public static Map<String, SObject> createBasicTestData() {
        Map<String, SObject> testData = new Map<String, SObject>();

        Account acc = createAccount('Client', 'Client');
        insert acc;
        testData.put('account', acc);

        Contact con = createContact(acc.Id);
        insert con;
        testData.put('contact', con);

        Case c = createCase('Service_Request');
        c.AccountId = acc.Id;
        c.ContactId = con.Id;
        insert c;
        testData.put('case', c);

        return testData;
    }
}
