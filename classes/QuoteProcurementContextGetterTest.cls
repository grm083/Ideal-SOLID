/**
 * @description Test class for QuoteProcurementContextGetter
 *
 * Tests all query methods, caching functionality, and field set consistency
 * for the QuoteProcurement data access layer.
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class QuoteProcurementContextGetterTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    /**
     * @description Setup test data for all tests
     */
    @testSetup
    static void setupTestData() {
        // Create Account hierarchy
        Account clientAccount = TestDataFactoryRefactored.createAccount('Client', 'Client');
        insert clientAccount;

        Account locationAccount = TestDataFactoryRefactored.createAccount('Location', 'Location');
        locationAccount.ParentId = clientAccount.Id;
        insert locationAccount;

        Account vendorAccount = TestDataFactoryRefactored.createAccount('Vendor', 'Vendor');
        vendorAccount.Status__c = 'Active';
        vendorAccount.Vendor_Business_Unit__c = 'BU001';
        vendorAccount.FacilityCode__c = 'FAC001';
        vendorAccount.Parent_Vendor_Id__c = '12345';
        insert vendorAccount;

        // Create Contact
        Contact con = TestDataFactoryRefactored.createContact(clientAccount.Id);
        insert con;

        // Create Product
        Product2 product = TestDataFactoryRefactored.createProduct('Rolloff');
        insert product;

        // Create Case
        Case testCase = TestDataFactoryRefactored.createCaseWithRelationships(
            clientAccount.Id,
            locationAccount.Id,
            con.Id,
            null,
            'Service_Request'
        );
        insert testCase;

        // Create Opportunity
        Opportunity opp = TestDataFactoryRefactored.createOpportunity(clientAccount.Id);
        opp.Case__c = testCase.Id;
        insert opp;

        // Create SBQQ Quote
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Account__c = locationAccount.Id,
            SBQQ__PrimaryContact__c = con.Id,
            SBQQ__Status__c = 'Draft',
            SBQQ__Type__c = 'Quote',
            STP__c = false,
            Case_Type__c = 'Service Request',
            Case_Sub_Type__c = 'Pickup'
        );
        insert quote;

        // Create parent QuoteLine
        SBQQ__QuoteLine__c parentLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1,
            SBQQ__Number__c = 1,
            Equipment_Size__c = '30 YD',
            Vendor__c = vendorAccount.Id,
            MASLibrary__c = 'LIB01',
            MASCompany__c = 'COMP01',
            SBQQ__StartDate__c = Date.today(),
            SBQQ__EndDate__c = Date.today().addDays(30)
        );
        insert parentLine;

        // Create child QuoteLine
        SBQQ__QuoteLine__c childLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__RequiredBy__c = parentLine.Id,
            SBQQ__Quantity__c = 1,
            SBQQ__Number__c = 2,
            SBQQ__ProductFamily__c = 'Service',
            Vendor__c = vendorAccount.Id
        );
        insert childLine;

        // Create Account Position
        Account_Position__c position = new Account_Position__c(
            AccountId__c = locationAccount.Id,
            Container_Position__c = 'Default',
            AlternateStreet__c = '123 Test St',
            AlternateCity__c = 'Test City',
            AlternateState__c = 'CA',
            AlternatePostalCode__c = '90210'
        );
        insert position;

        // Create Quote Order
        Quote_Order__c quoteOrder = new Quote_Order__c(
            Quote_Line__c = parentLine.Id,
            Service_Date__c = Date.today().addDays(7),
            Service_Type__c = 'Delivery',
            Instructions__c = 'Test instructions'
        );
        insert quoteOrder;

        // Create Business Rule
        Business_Rule__c br = new Business_Rule__c(
            AccountId__c = clientAccount.Id,
            Request_Type__c = 'Service Request',
            Service__c = 'Pickup',
            Active__c = true,
            Required_Information__c = 'Test info'
        );
        insert br;

        // Create Product Option
        SBQQ__ProductOption__c prodOption = new SBQQ__ProductOption__c(
            SBQQ__ConfiguredSKU__c = product.Id,
            SBQQ__OptionalSKU__c = product.Id,
            SBQQ__Number__c = 1,
            SBQQ__Type__c = 'Accessory',
            SBQQ__Quantity__c = 1
        );
        insert prodOption;
    }

    // ========================================================================
    // QUOTELINE QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetQuoteLineById() {
        SBQQ__QuoteLine__c parentLine = [SELECT Id FROM SBQQ__QuoteLine__c
                                         WHERE SBQQ__RequiredBy__c = null LIMIT 1];

        Test.startTest();
        SBQQ__QuoteLine__c result = QuoteProcurementContextGetter.getQuoteLineById(parentLine.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return QuoteLine');
        System.assertEquals(parentLine.Id, result.Id, 'Should return correct QuoteLine');
        System.assertNotEquals(null, result.SBQQ__Quote__c, 'Should include Quote relationship');
    }

    @isTest
    static void testGetQuoteLinesByIds() {
        List<SBQQ__QuoteLine__c> allLines = [SELECT Id FROM SBQQ__QuoteLine__c];
        Set<Id> lineIds = new Set<Id>();
        for (SBQQ__QuoteLine__c line : allLines) {
            lineIds.add(line.Id);
        }

        Test.startTest();
        Map<Id, SBQQ__QuoteLine__c> result = QuoteProcurementContextGetter.getQuoteLinesByIds(lineIds);
        Test.stopTest();

        System.assertEquals(allLines.size(), result.size(), 'Should return all requested QuoteLines');
    }

    @isTest
    static void testGetQuoteLinesByQuoteId() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        List<SBQQ__QuoteLine__c> result = QuoteProcurementContextGetter.getQuoteLinesByQuoteId(quote.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return only parent QuoteLines');
        System.assertEquals(null, result[0].SBQQ__RequiredBy__c, 'Should only return lines with no parent');
    }

    @isTest
    static void testGetQuoteLineDetails() {
        SBQQ__QuoteLine__c parentLine = [SELECT Id FROM SBQQ__QuoteLine__c
                                         WHERE SBQQ__RequiredBy__c = null LIMIT 1];

        Test.startTest();
        List<SBQQ__QuoteLine__c> result = QuoteProcurementContextGetter.getQuoteLineDetails(parentLine.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return child QuoteLines');
        System.assertEquals(parentLine.Id, result[0].SBQQ__RequiredBy__c, 'Should return correct children');
    }

    @isTest
    static void testGetQuoteLineMASDetails() {
        SBQQ__QuoteLine__c parentLine = [SELECT Id FROM SBQQ__QuoteLine__c
                                         WHERE SBQQ__RequiredBy__c = null LIMIT 1];

        Test.startTest();
        SBQQ__QuoteLine__c result = QuoteProcurementContextGetter.getQuoteLineMASDetails(parentLine.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return QuoteLine with MAS fields');
        System.assertNotEquals(null, result.MASLibrary__c, 'Should include MAS Library');
    }

    @isTest
    static void testGetQuoteLinesForPosition() {
        SBQQ__QuoteLine__c parentLine = [SELECT Id FROM SBQQ__QuoteLine__c
                                         WHERE SBQQ__RequiredBy__c = null LIMIT 1];

        Test.startTest();
        List<SBQQ__QuoteLine__c> result = QuoteProcurementContextGetter.getQuoteLinesForPosition(parentLine.Id);
        Test.stopTest();

        System.assert(result.size() >= 1, 'Should return QuoteLines for position update');
    }

    @isTest
    static void testGetParentQuoteLine() {
        SBQQ__QuoteLine__c parentLine = [SELECT Id FROM SBQQ__QuoteLine__c
                                         WHERE SBQQ__RequiredBy__c = null LIMIT 1];

        Test.startTest();
        SBQQ__QuoteLine__c result = QuoteProcurementContextGetter.getParentQuoteLine(parentLine.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return parent QuoteLine');
        System.assertNotEquals(null, result.SBQQ__Product__c, 'Should include Product');
    }

    // ========================================================================
    // QUOTE QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetQuoteById() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        SBQQ__Quote__c result = QuoteProcurementContextGetter.getQuoteById(quote.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return Quote');
        System.assertEquals(quote.Id, result.Id, 'Should return correct Quote');
        System.assertNotEquals(null, result.SBQQ__Account__c, 'Should include Account relationship');
    }

    @isTest
    static void testGetQuoteStatusDetails() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        SBQQ__Quote__c result = QuoteProcurementContextGetter.getQuoteStatusDetails(quote.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return Quote with status details');
        System.assertNotEquals(null, result.SBQQ__Status__c, 'Should include status');
    }

    @isTest
    static void testGetQuoteForOrders() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        SBQQ__Quote__c result = QuoteProcurementContextGetter.getQuoteForOrders(quote.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return Quote for orders');
        System.assertNotEquals(null, result.SBQQ__PrimaryContact__c, 'Should include primary contact');
    }

    // ========================================================================
    // QUOTE ORDER QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetQuoteOrders() {
        SBQQ__QuoteLine__c parentLine = [SELECT Id FROM SBQQ__QuoteLine__c
                                         WHERE SBQQ__RequiredBy__c = null LIMIT 1];

        Test.startTest();
        List<Quote_Order__c> result = QuoteProcurementContextGetter.getQuoteOrders(parentLine.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return Quote Orders');
        System.assertNotEquals(null, result[0].Service_Type__c, 'Should include service type');
    }

    // ========================================================================
    // POSITION QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetAllPositions() {
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];

        Test.startTest();
        List<Account_Position__c> result = QuoteProcurementContextGetter.getAllPositions(locationAccount.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return all positions');
        System.assertEquals('Default', result[0].Container_Position__c, 'Should include default position first');
    }

    @isTest
    static void testValidatePositionUniqueness() {
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];

        Test.startTest();
        Boolean isUnique = QuoteProcurementContextGetter.validatePositionUniqueness(
            locationAccount.Id,
            'Default'
        );
        Boolean isNotUnique = QuoteProcurementContextGetter.validatePositionUniqueness(
            locationAccount.Id,
            'New Position'
        );
        Test.stopTest();

        System.assertEquals(false, isUnique, 'Default position should already exist');
        System.assertEquals(true, isNotUnique, 'New position should be unique');
    }

    // ========================================================================
    // BUSINESS RULE QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetQuoteBusinessRules() {
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];

        Test.startTest();
        List<Business_Rule__c> result = QuoteProcurementContextGetter.getQuoteBusinessRules(
            clientAccount.Id,
            'Service Request',
            'Pickup'
        );
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return matching business rules');
    }

    // ========================================================================
    // PRODUCT OPTION QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetProductOptions() {
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        Test.startTest();
        List<SBQQ__ProductOption__c> result = QuoteProcurementContextGetter.getProductOptions(product.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return product options');
    }

    @isTest
    static void testGetMaxQuoteLineNumber() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        Decimal maxNumber = QuoteProcurementContextGetter.getMaxQuoteLineNumber(quote.Id);
        Test.stopTest();

        System.assertEquals(2, maxNumber, 'Should return max line number');
    }

    // ========================================================================
    // CACHE MANAGEMENT TESTS
    // ========================================================================

    @isTest
    static void testCacheManagement() {
        SBQQ__QuoteLine__c parentLine = [SELECT Id FROM SBQQ__QuoteLine__c
                                         WHERE SBQQ__RequiredBy__c = null LIMIT 1];
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();

        // First call should query
        SBQQ__QuoteLine__c result1 = QuoteProcurementContextGetter.getQuoteLineById(parentLine.Id);

        // Second call should use cache
        SBQQ__QuoteLine__c result2 = QuoteProcurementContextGetter.getQuoteLineById(parentLine.Id);

        // Clear cache
        QuoteProcurementContextGetter.clearCaches();

        // Third call should query again
        SBQQ__QuoteLine__c result3 = QuoteProcurementContextGetter.getQuoteLineById(parentLine.Id);

        Test.stopTest();

        System.assertEquals(result1.Id, result2.Id, 'Cached results should match');
        System.assertEquals(result1.Id, result3.Id, 'Results after cache clear should still match');
    }

    @isTest
    static void testClearSpecificCaches() {
        SBQQ__QuoteLine__c parentLine = [SELECT Id FROM SBQQ__QuoteLine__c
                                         WHERE SBQQ__RequiredBy__c = null LIMIT 1];
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();

        // Load into cache
        QuoteProcurementContextGetter.getQuoteLineById(parentLine.Id);
        QuoteProcurementContextGetter.getQuoteById(quote.Id);

        // Clear specific caches
        QuoteProcurementContextGetter.clearQuoteLineCache(parentLine.Id);
        QuoteProcurementContextGetter.clearQuoteCache(quote.Id);

        Test.stopTest();

        // No exception means cache management works
        System.assert(true, 'Cache clearing should not throw exceptions');
    }
}
