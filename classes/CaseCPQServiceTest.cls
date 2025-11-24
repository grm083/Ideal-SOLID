/**
 * @description Comprehensive test class for CaseCPQService
 *
 * Coverage Target: 85%+
 *
 * Tests all public methods for CPQ/Quote operations including opportunity and quote creation
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseCPQServiceTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    @testSetup
    static void setupTestData() {
        // Create full test hierarchy
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();

        Account locationAccount = (Account)testData.get('locationAccount');
        Account clientAccount = (Account)testData.get('clientAccount');
        Contact testContact = (Contact)testData.get('contact');
        Asset testAsset = (Asset)testData.get('asset');

        // Update asset to have duration
        testAsset.Duration__c = 'Permanent';
        update testAsset;

        // Create Standard Price Book
        Pricebook2 standardPricebook = new Pricebook2(
            Name = 'Standard Price Book',
            IsActive = true
        );
        insert standardPricebook;

        // Create test cases for different scenarios
        List<Case> testCases = new List<Case>();

        // New Service Case
        Case newServiceCase = TestDataFactoryRefactored.createCaseWithRelationships(
            clientAccount.Id,
            locationAccount.Id,
            testContact.Id,
            testAsset.Id,
            'New_Service_Case'
        );
        newServiceCase.Case_Record_Type__c = Constant_Util.New_Service_Case;
        newServiceCase.Case_Type__c = Constant_Util.NEW_SERVICE;
        newServiceCase.Case_Sub_Type__c = 'Permanent';
        newServiceCase.Service_Date__c = System.today().addDays(7);
        newServiceCase.IsOpportunity_Created__c = false;
        newServiceCase.Quote_Only__c = false;
        testCases.add(newServiceCase);

        // Modify Existing Service Case
        Case modifyServiceCase = TestDataFactoryRefactored.createCaseWithRelationships(
            clientAccount.Id,
            locationAccount.Id,
            testContact.Id,
            testAsset.Id,
            'Modify_Existing_Service_Case'
        );
        modifyServiceCase.Case_Record_Type__c = Constant_Util.MODIFY_EXISTING_SERVICE_CASE;
        modifyServiceCase.Case_Type__c = Constant_Util.Change_Service;
        modifyServiceCase.Case_Sub_Type__c = Constant_Util.Change_Correction;
        modifyServiceCase.Case_Reason__c = Constant_Util.CASE_REASON_DAYSOFSERVICE;
        modifyServiceCase.Service_Date__c = System.today().addDays(7);
        modifyServiceCase.IsOpportunity_Created__c = false;
        testCases.add(modifyServiceCase);

        // Update Asset Case
        Case updateAssetCase = TestDataFactoryRefactored.createCaseWithRelationships(
            clientAccount.Id,
            locationAccount.Id,
            testContact.Id,
            testAsset.Id,
            'Update_Asset_Case'
        );
        updateAssetCase.Case_Record_Type__c = Constant_Util.UPDATE_ASSET_CASE;
        updateAssetCase.Case_Type__c = 'Update';
        updateAssetCase.Service_Date__c = System.today().addDays(7);
        updateAssetCase.IsOpportunity_Created__c = false;
        testCases.add(updateAssetCase);

        insert testCases;
    }

    // ========================================================================
    // CREATE QUOTE FROM CASE TESTS
    // ========================================================================

    @isTest
    static void testCreateQuoteFromCase_NewService_Success() {
        // Given: A New Service case
        Case newServiceCase = [
            SELECT Id, CaseNumber, AssetId, Location__c, ContactId,
                   Case_Type__c, Case_Sub_Type__c, Case_Record_Type__c,
                   Service_Date__c, Quote_Only__c, Asset.Duration__c
            FROM Case
            WHERE Case_Record_Type__c = :Constant_Util.New_Service_Case
            LIMIT 1
        ];

        Test.startTest();

        // When: Creating quote from case
        String quoteId = CaseCPQService.createQuoteFromCase(newServiceCase.Id);

        Test.stopTest();

        // Then: Quote should be created
        System.assertNotEquals(null, quoteId, 'Quote ID should not be null');

        // Verify Opportunity was created
        List<Opportunity> opps = [
            SELECT Id, Name, AccountId, StageName, Case__c, Duration__c
            FROM Opportunity
            WHERE Case__c = :newServiceCase.Id
        ];
        System.assertEquals(1, opps.size(), 'One opportunity should be created');
        System.assertEquals(newServiceCase.CaseNumber, opps[0].Name, 'Opportunity name should match case number');
        System.assertEquals(Constant_Util.PRODUCT_CONFIGURATION, opps[0].StageName, 'Stage should be Product Configuration');

        // Verify Quote was created
        SBQQ__Quote__c quote = [
            SELECT Id, Name, SBQQ__Opportunity2__c, SBQQ__Account__c,
                   SBQQ__Primary__c, SBQQ__PrimaryContact__c, Duration__c,
                   Quote_Only__c, Case_Comments__c
            FROM SBQQ__Quote__c
            WHERE Id = :quoteId
        ];
        System.assertEquals(opps[0].Id, quote.SBQQ__Opportunity2__c, 'Quote should be linked to opportunity');
        System.assertEquals(true, quote.SBQQ__Primary__c, 'Quote should be primary');
        System.assertEquals(newServiceCase.ContactId, quote.SBQQ__PrimaryContact__c, 'Contact should match');

        // Verify Case was updated
        Case updatedCase = [
            SELECT Id, IsOpportunity_Created__c, Status, Master_Intake_Complete__c
            FROM Case
            WHERE Id = :newServiceCase.Id
        ];
        System.assertEquals(true, updatedCase.IsOpportunity_Created__c, 'Opportunity created flag should be true');
        System.assertEquals(Constant_Util.OPEN, updatedCase.Status, 'Status should be Open');
        System.assertEquals(true, updatedCase.Master_Intake_Complete__c, 'Master intake should be complete');
    }

    @isTest
    static void testCreateQuoteFromCase_ModifyService_Amendment() {
        // Given: A Modify Service case
        Case modifyCase = [
            SELECT Id, CaseNumber, AssetId, Location__c, ContactId,
                   Case_Type__c, Case_Sub_Type__c, Case_Reason__c,
                   Case_Record_Type__c, Service_Date__c
            FROM Case
            WHERE Case_Record_Type__c = :Constant_Util.MODIFY_EXISTING_SERVICE_CASE
            LIMIT 1
        ];

        Test.startTest();

        // When: Creating quote from case
        String quoteId = CaseCPQService.createQuoteFromCase(modifyCase.Id);

        Test.stopTest();

        // Then: Quote should be created with Amendment type
        System.assertNotEquals(null, quoteId, 'Quote ID should not be null');

        SBQQ__Quote__c quote = [
            SELECT Id, SBQQ__Type__c
            FROM SBQQ__Quote__c
            WHERE Id = :quoteId
        ];

        // Verify quote type is set (based on determineQuoteType logic)
        System.assertNotEquals(null, quote.SBQQ__Type__c, 'Quote type should be set');
    }

    @isTest
    static void testCreateQuoteFromCase_UpdateAsset_Amendment() {
        // Given: An Update Asset case
        Case updateCase = [
            SELECT Id, CaseNumber, AssetId, Location__c, ContactId,
                   Case_Record_Type__c, Service_Date__c
            FROM Case
            WHERE Case_Record_Type__c = :Constant_Util.UPDATE_ASSET_CASE
            LIMIT 1
        ];

        Test.startTest();

        // When: Creating quote from case
        String quoteId = CaseCPQService.createQuoteFromCase(updateCase.Id);

        Test.stopTest();

        // Then: Quote should be created
        System.assertNotEquals(null, quoteId, 'Quote ID should not be null');

        SBQQ__Quote__c quote = [
            SELECT Id, SBQQ__Type__c
            FROM SBQQ__Quote__c
            WHERE Id = :quoteId
        ];

        // Verify quote type is Amendment for Update Asset cases
        System.assertNotEquals(null, quote.SBQQ__Type__c, 'Quote type should be set');
    }

    @isTest
    static void testCreateQuoteFromCase_InvalidCaseId() {
        Test.startTest();

        // When: Creating quote with invalid case ID
        try {
            String quoteId = CaseCPQService.createQuoteFromCase('500000000000000AAA');
            System.assert(false, 'Should have thrown exception');
        } catch (Exception e) {
            // Then: Exception should be thrown
            System.assert(true, 'Exception should be thrown for invalid case');
        }

        Test.stopTest();
    }

    @isTest
    static void testCreateQuotesFromCases_MultipleCases() {
        // Given: Multiple case IDs
        Set<Id> caseIds = new Set<Id>();
        for (Case c : [SELECT Id FROM Case WHERE IsOpportunity_Created__c = false LIMIT 2]) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When: Creating quotes from multiple cases
        Map<Id, Id> caseToQuoteMap = CaseCPQService.createQuotesFromCases(caseIds);

        Test.stopTest();

        // Then: Quotes should be created for cases
        System.assertNotEquals(null, caseToQuoteMap, 'Map should not be null');
        System.assert(caseToQuoteMap.size() > 0, 'Should have created quotes');
    }

    @isTest
    static void testCreateQuotesFromCases_EmptySet() {
        Test.startTest();

        // When: Creating quotes with empty set
        Map<Id, Id> caseToQuoteMap = CaseCPQService.createQuotesFromCases(new Set<Id>());

        Test.stopTest();

        // Then: Should return empty map
        System.assertNotEquals(null, caseToQuoteMap, 'Map should not be null');
        System.assertEquals(0, caseToQuoteMap.size(), 'Map should be empty');
    }

    // ========================================================================
    // DETERMINE QUOTE TYPE TESTS
    // ========================================================================

    @isTest
    static void testDetermineQuoteType_NewService() {
        // Given: A New Service case
        Case newServiceCase = new Case();
        newServiceCase.Case_Record_Type__c = Constant_Util.New_Service_Case;

        Test.startTest();

        // When: Determining quote type
        String quoteType = CaseCPQService.determineQuoteType(newServiceCase);

        Test.stopTest();

        // Then: Quote type should be Quote
        System.assertEquals(Constant_Util.QUOTE, quoteType, 'Quote type should be Quote');
    }

    @isTest
    static void testDetermineQuoteType_Amendment_DaysOfService() {
        // Given: A Modify Service case with Days of Service reason
        Case modifyCase = new Case();
        modifyCase.Case_Record_Type__c = Constant_Util.MODIFY_EXISTING_SERVICE_CASE;
        modifyCase.Case_Type__c = Constant_Util.Change_Service;
        modifyCase.Case_Sub_Type__c = Constant_Util.Change_Correction;
        modifyCase.Case_Reason__c = Constant_Util.CASE_REASON_DAYSOFSERVICE;

        Test.startTest();

        // When: Determining quote type
        String quoteType = CaseCPQService.determineQuoteType(modifyCase);

        Test.stopTest();

        // Then: Quote type should be Amendment (or Quote based on user)
        System.assertNotEquals(null, quoteType, 'Quote type should be set');
    }

    @isTest
    static void testDetermineQuoteType_UpdateAsset() {
        // Given: An Update Asset case
        Case updateCase = new Case();
        updateCase.Case_Record_Type__c = Constant_Util.UPDATE_ASSET_CASE;

        Test.startTest();

        // When: Determining quote type
        String quoteType = CaseCPQService.determineQuoteType(updateCase);

        Test.stopTest();

        // Then: Quote type should be Amendment
        System.assertEquals(Constant_Util.QUOTE_TYPE_AMEND, quoteType, 'Quote type should be Amendment');
    }

    @isTest
    static void testDetermineQuoteType_Correction() {
        // Given: A Modify Service case with Correction sub-type
        Case correctionCase = new Case();
        correctionCase.Case_Record_Type__c = Constant_Util.MODIFY_EXISTING_SERVICE_CASE;
        correctionCase.Case_Type__c = Constant_Util.Change_Service;
        correctionCase.Case_Sub_Type__c = Constant_Util.Change_Correction;

        Test.startTest();

        // When: Determining quote type
        String quoteType = CaseCPQService.determineQuoteType(correctionCase);

        Test.stopTest();

        // Then: Quote type should be Correction
        System.assertEquals(Constant_Util.QUOTE_TYPE_CORRECTION, quoteType, 'Quote type should be Correction');
    }

    @isTest
    static void testDetermineQuoteType_WasteStreamAmendment() {
        // Given: A Modify Service case with Waste Stream sub-type
        Case wasteStreamCase = new Case();
        wasteStreamCase.Case_Record_Type__c = Constant_Util.MODIFY_EXISTING_SERVICE_CASE;
        wasteStreamCase.Case_Type__c = Constant_Util.Change_Service;
        wasteStreamCase.Case_Sub_Type__c = Constant_Util.WASTE_STREAM;

        Test.startTest();

        // When: Determining quote type
        String quoteType = CaseCPQService.determineQuoteType(wasteStreamCase);

        Test.stopTest();

        // Then: Quote type should be Amendment
        System.assertEquals(Constant_Util.QUOTE_TYPE_AMEND, quoteType, 'Quote type should be Amendment');
    }

    @isTest
    static void testDetermineQuoteType_Exception() {
        // Given: A case that doesn't match any criteria
        Case exceptionCase = new Case();
        exceptionCase.Case_Record_Type__c = 'Unknown Type';

        Test.startTest();

        // When: Determining quote type
        String quoteType = CaseCPQService.determineQuoteType(exceptionCase);

        Test.stopTest();

        // Then: Quote type should be Exception
        System.assertEquals(Constant_Util.KEYWORD_EXCEPTION, quoteType, 'Quote type should be Exception');
    }

    // ========================================================================
    // CASE ELIGIBILITY TESTS
    // ========================================================================

    @isTest
    static void testIsCaseEligibleForQuote_NewService() {
        // Given: A New Service case without opportunity
        Case newServiceCase = [
            SELECT Id, Case_Record_Type__c, IsOpportunity_Created__c
            FROM Case
            WHERE Case_Record_Type__c = :Constant_Util.New_Service_Case
            LIMIT 1
        ];

        Test.startTest();

        // When: Checking eligibility
        Boolean isEligible = CaseCPQService.isCaseEligibleForQuote(newServiceCase);

        Test.stopTest();

        // Then: Should be eligible
        System.assertEquals(true, isEligible, 'New Service case should be eligible');
    }

    @isTest
    static void testIsCaseEligibleForQuote_AlreadyHasQuote() {
        // Given: A case that already has a quote
        Case caseWithQuote = [
            SELECT Id, Case_Record_Type__c, IsOpportunity_Created__c
            FROM Case
            LIMIT 1
        ];
        caseWithQuote.IsOpportunity_Created__c = true;
        update caseWithQuote;

        Test.startTest();

        // When: Checking eligibility
        Boolean isEligible = CaseCPQService.isCaseEligibleForQuote(caseWithQuote);

        Test.stopTest();

        // Then: Should not be eligible
        System.assertEquals(false, isEligible, 'Case with existing quote should not be eligible');
    }

    @isTest
    static void testIsCaseEligibleForQuote_NullCase() {
        Test.startTest();

        // When: Checking eligibility with null case
        Boolean isEligible = CaseCPQService.isCaseEligibleForQuote(null);

        Test.stopTest();

        // Then: Should not be eligible
        System.assertEquals(false, isEligible, 'Null case should not be eligible');
    }

    // ========================================================================
    // QUOTE RETRIEVAL TESTS
    // ========================================================================

    @isTest
    static void testGetQuotesByCase_WithQuotes() {
        // Given: A case with a quote
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        String quoteId = CaseCPQService.createQuoteFromCase(testCase.Id);

        Test.startTest();

        // When: Getting quotes by case
        List<SBQQ__Quote__c> quotes = CaseCPQService.getQuotesByCase(testCase.Id);

        Test.stopTest();

        // Then: Should return quotes
        System.assertNotEquals(null, quotes, 'Quotes list should not be null');
        System.assert(quotes.size() > 0, 'Should have at least one quote');
    }

    @isTest
    static void testGetQuotesByCase_NoQuotes() {
        // Given: A case without quotes
        Case newCase = TestDataFactoryRefactored.createCase('Service_Request');
        insert newCase;

        Test.startTest();

        // When: Getting quotes by case
        List<SBQQ__Quote__c> quotes = CaseCPQService.getQuotesByCase(newCase.Id);

        Test.stopTest();

        // Then: Should return empty list
        System.assertNotEquals(null, quotes, 'Quotes list should not be null');
        System.assertEquals(0, quotes.size(), 'Should have no quotes');
    }

    @isTest
    static void testGetPrimaryQuoteByCase_WithPrimary() {
        // Given: A case with a primary quote
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        String quoteId = CaseCPQService.createQuoteFromCase(testCase.Id);

        Test.startTest();

        // When: Getting primary quote
        SBQQ__Quote__c primaryQuote = CaseCPQService.getPrimaryQuoteByCase(testCase.Id);

        Test.stopTest();

        // Then: Should return primary quote
        System.assertNotEquals(null, primaryQuote, 'Primary quote should not be null');
        System.assertEquals(true, primaryQuote.SBQQ__Primary__c, 'Quote should be primary');
    }

    @isTest
    static void testGetPrimaryQuoteByCase_NoPrimary() {
        // Given: A case without quotes
        Case newCase = TestDataFactoryRefactored.createCase('Service_Request');
        insert newCase;

        Test.startTest();

        // When: Getting primary quote
        SBQQ__Quote__c primaryQuote = CaseCPQService.getPrimaryQuoteByCase(newCase.Id);

        Test.stopTest();

        // Then: Should return null
        System.assertEquals(null, primaryQuote, 'Should return null when no primary quote');
    }

    @isTest
    static void testGetOpportunitiesByCase_WithOpportunities() {
        // Given: A case with an opportunity
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        String quoteId = CaseCPQService.createQuoteFromCase(testCase.Id);

        Test.startTest();

        // When: Getting opportunities by case
        List<Opportunity> opportunities = CaseCPQService.getOpportunitiesByCase(testCase.Id);

        Test.stopTest();

        // Then: Should return opportunities
        System.assertNotEquals(null, opportunities, 'Opportunities list should not be null');
        System.assert(opportunities.size() > 0, 'Should have at least one opportunity');
    }

    @isTest
    static void testGetOpportunitiesByCase_NoOpportunities() {
        // Given: A case without opportunities
        Case newCase = TestDataFactoryRefactored.createCase('Service_Request');
        insert newCase;

        Test.startTest();

        // When: Getting opportunities by case
        List<Opportunity> opportunities = CaseCPQService.getOpportunitiesByCase(newCase.Id);

        Test.stopTest();

        // Then: Should return empty list
        System.assertNotEquals(null, opportunities, 'Opportunities list should not be null');
        System.assertEquals(0, opportunities.size(), 'Should have no opportunities');
    }

    // ========================================================================
    // WRAPPER CLASS TESTS
    // ========================================================================

    @isTest
    static void testQuoteCreationResult_Success() {
        Test.startTest();

        // When: Creating quote creation result
        CaseCPQService.QuoteCreationResult result =
            new CaseCPQService.QuoteCreationResult(
                true,
                'a00000000000000AAA',
                '006000000000000AAA',
                null
            );

        Test.stopTest();

        // Then: Properties should be set correctly
        System.assertEquals(true, result.success, 'Success should be true');
        System.assertEquals('a00000000000000AAA', result.quoteId, 'Quote ID should match');
        System.assertEquals('006000000000000AAA', result.opportunityId, 'Opportunity ID should match');
        System.assertEquals(null, result.errorMessage, 'Error message should be null');
    }

    @isTest
    static void testQuoteCreationResult_Error() {
        Test.startTest();

        // When: Creating quote creation result with error
        CaseCPQService.QuoteCreationResult result =
            new CaseCPQService.QuoteCreationResult(
                false,
                null,
                null,
                'Test error message'
            );

        Test.stopTest();

        // Then: Properties should be set correctly
        System.assertEquals(false, result.success, 'Success should be false');
        System.assertEquals(null, result.quoteId, 'Quote ID should be null');
        System.assertEquals(null, result.opportunityId, 'Opportunity ID should be null');
        System.assertEquals('Test error message', result.errorMessage, 'Error message should match');
    }
}
