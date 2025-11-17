/**
 * @description Test class for QuoteProcurementWrapperService
 *
 * Tests wrapper building operations including:
 * - Building ProductsWrapper from quote data
 * - Creating nested wrapper structures
 * - Retrieving case quotes
 * - Handling complex quote line hierarchies
 *
 * Utilizes TestDataFactoryRefactored for consistent test data creation.
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class QuoteProcurementWrapperServiceTest {

    /**
     * @description Set up test data for all test methods
     */
    @testSetup
    static void setupTestData() {
        // Create test account with parent
        Account parentAccount = TestDataFactoryRefactored.createAccount();
        parentAccount.AccountNumber = 'TEST-PARENT-001';
        insert parentAccount;

        Account testAccount = TestDataFactoryRefactored.createAccount();
        testAccount.ParentId = parentAccount.Id;
        insert testAccount;

        // Create test contact
        Contact testContact = TestDataFactoryRefactored.createContact(testAccount.Id);
        insert testContact;

        // Create test case
        Case testCase = TestDataFactoryRefactored.createCase(testAccount.Id, testContact.Id);
        insert testCase;

        // Create opportunity linked to case
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Case__c = testCase.Id
        );
        insert testOpp;

        // Create quote
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = testAccount.Id,
            SBQQ__Opportunity2__c = testOpp.Id,
            SBQQ__Status__c = 'Draft',
            SBQQ__PrimaryContact__c = testContact.Id,
            Quote_Only__c = false,
            SBQQ__Type__c = 'Quote'
        );
        insert testQuote;

        // Create test products
        Product2 containerProduct = TestDataFactoryRefactored.createProduct('Test Container', 'Container');
        Product2 wasteCategoryProduct = TestDataFactoryRefactored.createProduct('Test Waste Category', 'Waste Category');
        Product2 wasteStreamProduct = TestDataFactoryRefactored.createProduct('Test Waste Stream', 'Waste Stream');
        Product2 accessoryProduct = TestDataFactoryRefactored.createProduct('Test Accessory', 'Accessories');
        insert new List<Product2>{containerProduct, wasteCategoryProduct, wasteStreamProduct, accessoryProduct};

        // Create vendor
        Account vendor = new Account(
            Name = 'Test Vendor',
            AccountNumber = 'VEND-001',
            Vendor_Business_Unit__c = 'Test BU',
            Contact_Manually_Vendor__c = false,
            Prepayment_Required__c = 'No'
        );
        insert vendor;

        // Create parent quote line (container)
        SBQQ__QuoteLine__c parentQL = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuote.Id,
            SBQQ__Product__c = containerProduct.Id,
            SBQQ__Number__c = 1,
            SBQQ__Quantity__c = 1,
            Equipment_Size__c = '10 Yard',
            SBQQ__StartDate__c = Date.today(),
            SBQQ__EndDate__c = Date.today().addDays(365),
            Vendor__c = vendor.Id,
            Occurrence_Type__c = 'TOS',
            Service_Schedule__c = 'Weekly',
            Description_of_Waste__c = 'Test Waste',
            MASLibrary__c = 'TEST',
            MASCompany__c = 'TC',
            MASAccount__c = '12345',
            BypassPriceReview__c = false,
            DoNotCreateMASTicket__c = false
        );
        insert parentQL;

        // Create child quote lines
        SBQQ__QuoteLine__c wasteCategoryQL = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuote.Id,
            SBQQ__Product__c = wasteCategoryProduct.Id,
            SBQQ__RequiredBy__c = parentQL.Id,
            SBQQ__Number__c = 2,
            SBQQ__Quantity__c = 1,
            SBQQ__OptionLevel__c = 1,
            SBQQ__UnitCost__c = 100.00,
            SBQQ__ListPrice__c = 150.00,
            Cost_Unit_of_Measure__c = 'Each',
            PriceUOM__c = 'Each'
        );

        SBQQ__QuoteLine__c wasteStreamQL = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuote.Id,
            SBQQ__Product__c = wasteStreamProduct.Id,
            SBQQ__RequiredBy__c = wasteCategoryQL.Id,
            SBQQ__Number__c = 3,
            SBQQ__Quantity__c = 1,
            SBQQ__OptionLevel__c = 2,
            SBQQ__UnitCost__c = 50.00,
            SBQQ__ListPrice__c = 75.00
        );

        SBQQ__QuoteLine__c accessoryQL = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuote.Id,
            SBQQ__Product__c = accessoryProduct.Id,
            SBQQ__RequiredBy__c = parentQL.Id,
            SBQQ__Number__c = 4,
            SBQQ__Quantity__c = 2,
            SBQQ__OptionLevel__c = 1,
            SBQQ__UnitCost__c = 25.00,
            SBQQ__ListPrice__c = 40.00,
            Occurrence_Type__c = 'TOS'
        );

        insert new List<SBQQ__QuoteLine__c>{wasteCategoryQL, wasteStreamQL, accessoryQL};
    }

    /**
     * @description Test buildWrapper - success scenario
     */
    @isTest
    static void testBuildWrapper_Success() {
        SBQQ__Quote__c testQuote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        QuoteProcurementController.ProductsWrapper result =
            QuoteProcurementWrapperService.buildWrapper(testQuote.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertEquals(true, result.disableMAS, 'MAS should be disabled by default');
        System.assertEquals(true, result.disableCost, 'Cost should be disabled by default');
        System.assertEquals(true, result.disablePrice, 'Price should be disabled by default');
        System.assertNotEquals(null, result.configuredProducts, 'Configured products should not be null');
    }

    /**
     * @description Test buildWrapper - verify configured products
     */
    @isTest
    static void testBuildWrapper_VerifyConfiguredProducts() {
        SBQQ__Quote__c testQuote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        QuoteProcurementController.ProductsWrapper result =
            QuoteProcurementWrapperService.buildWrapper(testQuote.Id);
        Test.stopTest();

        System.assert(result.configuredProducts.size() > 0, 'Should have configured products');

        QuoteProcurementController.HeaderWrapper header = result.configuredProducts[0];
        System.assertNotEquals(null, header.parentId, 'Parent ID should be set');
        System.assertNotEquals(null, header.quoteID, 'Quote ID should be set');
        System.assertNotEquals(null, header.equipmentType, 'Equipment type should be set');
        System.assertEquals('10 Yard', header.equipmentSize, 'Equipment size should match');
    }

    /**
     * @description Test buildWrapper - verify MAS wrapper
     */
    @isTest
    static void testBuildWrapper_VerifyMASWrapper() {
        SBQQ__Quote__c testQuote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        QuoteProcurementController.ProductsWrapper result =
            QuoteProcurementWrapperService.buildWrapper(testQuote.Id);
        Test.stopTest();

        QuoteProcurementController.HeaderWrapper header = result.configuredProducts[0];
        System.assertNotEquals(null, header.MAS, 'MAS wrapper should not be null');
        System.assertEquals('TEST', header.MAS.MASLibrary, 'MAS library should match');
        System.assertEquals('TC', header.MAS.MASCompany, 'MAS company should match');
        System.assertEquals('12345', header.MAS.MASAccount, 'MAS account should match');
        System.assertEquals(false, header.MAS.MASBypassPrice, 'Bypass price should match');
    }

    /**
     * @description Test buildWrapper - verify detail wrappers
     */
    @isTest
    static void testBuildWrapper_VerifyDetailWrappers() {
        SBQQ__Quote__c testQuote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        QuoteProcurementController.ProductsWrapper result =
            QuoteProcurementWrapperService.buildWrapper(testQuote.Id);
        Test.stopTest();

        QuoteProcurementController.HeaderWrapper header = result.configuredProducts[0];
        System.assertNotEquals(null, header.details, 'Details should not be null');

        // Should have waste category and accessory (waste stream is handled separately)
        Boolean hasWasteCategory = false;
        Boolean hasAccessory = false;

        for (QuoteProcurementController.DetailWrapper detail : header.details) {
            if (detail.componentType != null) {
                if (detail.componentType.contains('Waste Category')) {
                    hasWasteCategory = true;
                    System.assertNotEquals(null, detail.vendorCost, 'Cost should be set');
                    System.assertNotEquals(null, detail.customerPrice, 'Price should be set');
                }
                if (detail.componentType.contains('Accessory')) {
                    hasAccessory = true;
                    System.assertEquals(2, detail.componentQuantity, 'Quantity should match');
                }
            }
        }

        System.assert(hasWasteCategory, 'Should have waste category detail');
        System.assert(hasAccessory, 'Should have accessory detail');
    }

    /**
     * @description Test buildWrapper - verify material type from waste stream
     */
    @isTest
    static void testBuildWrapper_VerifyMaterialType() {
        SBQQ__Quote__c testQuote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        QuoteProcurementController.ProductsWrapper result =
            QuoteProcurementWrapperService.buildWrapper(testQuote.Id);
        Test.stopTest();

        QuoteProcurementController.HeaderWrapper header = result.configuredProducts[0];
        // Material type should be set from waste stream
        System.assertNotEquals(null, header.materialType, 'Material type should be set from waste stream');
    }

    /**
     * @description Test buildWrapper - empty quote (no quote lines)
     */
    @isTest
    static void testBuildWrapper_EmptyQuote() {
        Account testAccount = [SELECT Id FROM Account WHERE ParentId != null LIMIT 1];

        // Create empty quote
        SBQQ__Quote__c emptyQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = testAccount.Id,
            SBQQ__Status__c = 'Draft'
        );
        insert emptyQuote;

        Test.startTest();
        QuoteProcurementController.ProductsWrapper result =
            QuoteProcurementWrapperService.buildWrapper(emptyQuote.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertEquals(emptyQuote.Id, result.singleQuoteId, 'Should set single quote ID for empty quote');
        System.assert(result.configuredProducts == null || result.configuredProducts.isEmpty(),
                     'Should have no configured products');
    }

    /**
     * @description Test getCaseQuotes - success scenario
     */
    @isTest
    static void testGetCaseQuotes_Success() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<QuoteProcurementController.ProductsWrapper> result =
            QuoteProcurementWrapperService.getCaseQuotes(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.size(), 'Should have one quote for the case');
        System.assertNotEquals(null, result[0].configuredProducts, 'Quote should have configured products');
    }

    /**
     * @description Test getCaseQuotes - multiple quotes for case
     */
    @isTest
    static void testGetCaseQuotes_MultipleQuotes() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE ParentId != null LIMIT 1];
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];

        // Create second quote for same case
        SBQQ__Quote__c secondQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = testAccount.Id,
            SBQQ__Opportunity2__c = testOpp.Id,
            SBQQ__Status__c = 'Draft'
        );
        insert secondQuote;

        Test.startTest();
        List<QuoteProcurementController.ProductsWrapper> result =
            QuoteProcurementWrapperService.getCaseQuotes(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(2, result.size(), 'Should have two quotes for the case');
    }

    /**
     * @description Test getCaseQuotes - no quotes for case
     */
    @isTest
    static void testGetCaseQuotes_NoQuotes() {
        Account testAccount = [SELECT Id FROM Account WHERE ParentId != null LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        // Create case with no quotes
        Case newCase = TestDataFactoryRefactored.createCase(testAccount.Id, testContact.Id);
        insert newCase;

        Test.startTest();
        List<QuoteProcurementController.ProductsWrapper> result =
            QuoteProcurementWrapperService.getCaseQuotes(newCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should have no quotes for new case');
    }

    /**
     * @description Test buildWrapper - verify vendor information
     */
    @isTest
    static void testBuildWrapper_VerifyVendorInfo() {
        SBQQ__Quote__c testQuote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        QuoteProcurementController.ProductsWrapper result =
            QuoteProcurementWrapperService.buildWrapper(testQuote.Id);
        Test.stopTest();

        QuoteProcurementController.HeaderWrapper header = result.configuredProducts[0];
        System.assertNotEquals(null, header.vendorId, 'Vendor ID should be set');
        System.assertNotEquals(null, header.vendorName, 'Vendor name should be set');
        System.assertEquals('VEND-001', header.vendorNumber, 'Vendor number should match');
        System.assertEquals('No', header.vendorManualDispatch, 'Vendor manual dispatch should match');
        System.assertEquals('No', header.vendorPrepayment, 'Vendor prepayment should match');
    }

    /**
     * @description Test buildWrapper - verify quote information
     */
    @isTest
    static void testBuildWrapper_VerifyQuoteInfo() {
        SBQQ__Quote__c testQuote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        QuoteProcurementController.ProductsWrapper result =
            QuoteProcurementWrapperService.buildWrapper(testQuote.Id);
        Test.stopTest();

        QuoteProcurementController.HeaderWrapper header = result.configuredProducts[0];
        System.assertEquals('Draft', header.quoteStatus, 'Quote status should match');
        System.assertEquals(false, header.quoteOnly, 'Quote only should match');
        System.assertEquals('Quote', header.quoteType, 'Quote type should match');
        System.assertNotEquals(null, header.primaryContact, 'Primary contact should be set');
    }

    /**
     * @description Test buildWrapper - verify error handling
     */
    @isTest
    static void testBuildWrapper_InvalidQuoteId() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            QuoteProcurementWrapperService.buildWrapper('INVALID_ID_123');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Failed to build wrapper'),
                         'Should throw proper exception for invalid quote ID');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for invalid quote ID');
    }

    /**
     * @description Test getCaseQuotes - verify error handling
     */
    @isTest
    static void testGetCaseQuotes_InvalidCaseId() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            QuoteProcurementWrapperService.getCaseQuotes('INVALID_ID_123');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Failed to retrieve case quotes'),
                         'Should throw proper exception for invalid case ID');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for invalid case ID');
    }
}
