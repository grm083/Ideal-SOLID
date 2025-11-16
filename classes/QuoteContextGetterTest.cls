/**
 * @description Test class for QuoteContextGetter
 *
 * This test class provides comprehensive coverage for the QuoteContextGetter
 * data access layer, testing all query methods and bulk operations.
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class QuoteContextGetterTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    @testSetup
    static void setupTestData() {
        // Create full test hierarchy including quotes
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();

        // Create additional quotes for bulk testing
        Opportunity testOpp = (Opportunity)testData.get('opportunity');

        List<Quote> additionalQuotes = new List<Quote>();
        for (Integer i = 0; i < 5; i++) {
            Quote q = TestDataFactoryRefactored.createQuote(testOpp.Id);
            q.Name = 'Bulk Test Quote ' + i;
            additionalQuotes.add(q);
        }
        insert additionalQuotes;
    }

    // ========================================================================
    // SINGLE RECORD QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetQuoteById_Success() {
        // Given: A quote exists
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        Set<Id> quoteIds = new Set<Id>{testQuote.Id};

        Test.startTest();

        // When: Getting quote by Id
        Map<Id, Quote> results = QuoteContextGetter.getQuoteById(quoteIds);

        Test.stopTest();

        // Then: Quote is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return one quote');
        System.assert(results.containsKey(testQuote.Id), 'Should contain the quote Id');
        System.assertNotEquals(null, results.get(testQuote.Id).Name, 'Name should be populated');
    }

    @isTest
    static void testGetQuoteById_NullSet() {
        Test.startTest();

        // When: Getting quote with null set
        Map<Id, Quote> results = QuoteContextGetter.getQuoteById(null);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Empty map should be returned for null');
    }

    @isTest
    static void testGetQuoteById_EmptySet() {
        Test.startTest();

        // When: Getting quote with empty set
        Map<Id, Quote> results = QuoteContextGetter.getQuoteById(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Empty map should be returned');
    }

    // ========================================================================
    // BULK QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetQuoteById_BulkSuccess() {
        // Given: Multiple quotes exist
        List<Quote> testQuotes = [SELECT Id FROM Quote LIMIT 5];
        Set<Id> quoteIds = new Set<Id>();
        for (Quote q : testQuotes) {
            quoteIds.add(q.Id);
        }

        Test.startTest();

        // When: Getting multiple quotes
        Map<Id, Quote> results = QuoteContextGetter.getQuoteById(quoteIds);

        Test.stopTest();

        // Then: All quotes are returned
        System.assertEquals(quoteIds.size(), results.size(), 'All quotes should be returned');
        for (Id quoteId : quoteIds) {
            System.assert(results.containsKey(quoteId), 'Result should contain quote Id: ' + quoteId);
            System.assertNotEquals(null, results.get(quoteId).Name, 'Name should be populated');
        }
    }

    // ========================================================================
    // NEGATIVE TESTS
    // ========================================================================

    @isTest
    static void testGetQuoteById_InvalidId() {
        // Given: An invalid quote Id (using a generic 15-char prefix)
        Id fakeId = '0Q0000000000000AAA'; // Valid Id format, doesn't exist
        Set<Id> quoteIds = new Set<Id>{fakeId};

        Test.startTest();

        // When: Getting quote with invalid Id
        Map<Id, Quote> results = QuoteContextGetter.getQuoteById(quoteIds);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'Empty map should be returned for invalid Id');
    }

    // ========================================================================
    // GOVERNOR LIMIT TESTS
    // ========================================================================

    @isTest
    static void testBulkOperations_WithinGovernorLimits() {
        // Given: Many quotes exist
        List<Quote> testQuotes = [SELECT Id FROM Quote];
        Set<Id> quoteIds = new Set<Id>();
        for (Quote q : testQuotes) {
            quoteIds.add(q.Id);
        }

        Test.startTest();

        // When: Getting all quotes in bulk
        Map<Id, Quote> results = QuoteContextGetter.getQuoteById(quoteIds);

        // Then: Operation completes within governor limits
        Integer queriesUsed = Limits.getQueries();
        System.assert(queriesUsed < Limits.getLimitQueries(), 'Should be within SOQL query limits');

        Test.stopTest();

        // And: All quotes are returned
        System.assertEquals(quoteIds.size(), results.size(), 'All quotes should be returned');
    }

    // ========================================================================
    // FIELD ACCESSIBILITY TESTS
    // ========================================================================

    @isTest
    static void testGetQuoteById_FieldsAccessible() {
        // Given: A quote exists
        Quote testQuote = [SELECT Id, Name, Status FROM Quote LIMIT 1];
        Set<Id> quoteIds = new Set<Id>{testQuote.Id};

        Test.startTest();

        // When: Getting quote by Id
        Map<Id, Quote> results = QuoteContextGetter.getQuoteById(quoteIds);

        Test.stopTest();

        // Then: Standard fields are accessible
        Quote result = results.get(testQuote.Id);
        System.assertNotEquals(null, result.Name, 'Name should be accessible');
        System.assertNotEquals(null, result.Status, 'Status should be accessible');
    }

    // ========================================================================
    // INTEGRATION TESTS
    // ========================================================================

    @isTest
    static void testGetQuoteById_WithOpportunity() {
        // Given: A quote with opportunity relationship
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Opportunity testOpp = (Opportunity)testData.get('opportunity');
        Quote testQuote = (Quote)testData.get('quote');

        Set<Id> quoteIds = new Set<Id>{testQuote.Id};

        Test.startTest();

        // When: Getting quote with relationships
        Map<Id, Quote> results = QuoteContextGetter.getQuoteById(quoteIds);

        Test.stopTest();

        // Then: Relationship fields are populated
        Quote result = results.get(testQuote.Id);
        System.assertEquals(testOpp.Id, result.OpportunityId, 'OpportunityId should be populated');
    }
}
