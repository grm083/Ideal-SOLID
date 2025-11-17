/**
 * @description Test class for QuoteProcurementFavoritesService
 *
 * Tests favorite product retrieval, grouping, and quote/quoteline creation from favorites.
 * Utilizes TestDataFactoryRefactored for consistent test data creation.
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class QuoteProcurementFavoritesServiceTest {

    /**
     * @description Set up test data for all test methods
     */
    @testSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = TestDataFactoryRefactored.createAccount();
        insert testAccount;

        // Create test contact
        Contact testContact = TestDataFactoryRefactored.createContact(testAccount.Id);
        insert testContact;

        // Create test case
        Case testCase = TestDataFactoryRefactored.createCase(testAccount.Id, testContact.Id);
        insert testCase;

        // Create test products
        Product2 containerProduct = TestDataFactoryRefactored.createProduct('Test Container', 'Container');
        Product2 wasteCategoryProduct = TestDataFactoryRefactored.createProduct('Test Waste Category', 'Waste Category');
        Product2 wasteStreamProduct = TestDataFactoryRefactored.createProduct('Test Waste Stream', 'Waste Stream');
        insert new List<Product2>{containerProduct, wasteCategoryProduct, wasteStreamProduct};

        // Create favorite record
        SBQQ__Favorite__c favorite = new SBQQ__Favorite__c(
            Name = 'Test Favorite'
        );
        insert favorite;

        // Create configuration attributes JSON
        Map<String, Object> configAttributes = new Map<String, Object>{
            'Equipment_Size__c' => '10 Yard',
            'Occurrence_Type__c' => 'TOS'
        };
        String configJSON = JSON.serialize(configAttributes);

        // Create product options
        SBQQ__ProductOption__c containerOption = new SBQQ__ProductOption__c(
            SBQQ__ConfiguredSKU__c = containerProduct.Id,
            SBQQ__OptionalSKU__c = containerProduct.Id,
            SBQQ__ProductFamily__c = 'Container',
            SBQQ__Quantity__c = 1,
            Occurrence_Type__c = 'TOS'
        );

        SBQQ__ProductOption__c wasteCategoryOption = new SBQQ__ProductOption__c(
            SBQQ__ConfiguredSKU__c = containerProduct.Id,
            SBQQ__OptionalSKU__c = wasteCategoryProduct.Id,
            SBQQ__ProductFamily__c = 'Waste Category',
            SBQQ__Quantity__c = 1,
            Occurrence_Type__c = 'TOS'
        );

        SBQQ__ProductOption__c wasteStreamOption = new SBQQ__ProductOption__c(
            SBQQ__ConfiguredSKU__c = containerProduct.Id,
            SBQQ__OptionalSKU__c = wasteStreamProduct.Id,
            SBQQ__ProductFamily__c = 'Waste Stream',
            SBQQ__Quantity__c = 1
        );

        insert new List<SBQQ__ProductOption__c>{containerOption, wasteCategoryOption, wasteStreamOption};

        // Create favorite products
        SBQQ__FavoriteProduct__c parentFavorite = new SBQQ__FavoriteProduct__c(
            Name = 'Test Container',
            SBQQ__Favorite__c = favorite.Id,
            SBQQ__Product__c = containerProduct.Id,
            SBQQ__ConfigurationAttributes__c = configJSON,
            SBQQ__ProductOption__c = containerOption.Id,
            SBQQ__Quantity__c = 1
        );
        insert parentFavorite;

        // Create child favorite products
        SBQQ__FavoriteProduct__c wasteCategoryFavorite = new SBQQ__FavoriteProduct__c(
            Name = 'Test Waste Category',
            SBQQ__Favorite__c = favorite.Id,
            SBQQ__Product__c = wasteCategoryProduct.Id,
            SBQQ__RequiredBy__c = parentFavorite.Id,
            SBQQ__ConfigurationAttributes__c = configJSON,
            SBQQ__ProductOption__c = wasteCategoryOption.Id,
            SBQQ__Quantity__c = 1
        );

        SBQQ__FavoriteProduct__c wasteStreamFavorite = new SBQQ__FavoriteProduct__c(
            Name = 'Test Waste Stream',
            SBQQ__Favorite__c = favorite.Id,
            SBQQ__Product__c = wasteStreamProduct.Id,
            SBQQ__RequiredBy__c = wasteCategoryFavorite.Id,
            SBQQ__ConfigurationAttributes__c = configJSON,
            SBQQ__ProductOption__c = wasteStreamOption.Id,
            SBQQ__Quantity__c = 1
        );

        insert new List<SBQQ__FavoriteProduct__c>{wasteCategoryFavorite, wasteStreamFavorite};
    }

    /**
     * @description Test getFavorites method - basic retrieval
     */
    @isTest
    static void testGetFavorites_Success() {
        Test.startTest();
        QuoteProcurementController.FavoriteContainerWrapper result =
            QuoteProcurementFavoritesService.getFavorites();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertNotEquals(null, result.ContainerList, 'Container list should not be null');
        System.assert(result.ContainerList.size() > 0, 'Should have at least one container');
    }

    /**
     * @description Test getFavorites method - verify grouping by product name
     */
    @isTest
    static void testGetFavorites_VerifyGrouping() {
        Test.startTest();
        QuoteProcurementController.FavoriteContainerWrapper result =
            QuoteProcurementFavoritesService.getFavorites();
        Test.stopTest();

        // Verify unique product names are grouped
        Set<String> productNames = new Set<String>();
        for (QuoteProcurementController.FavoriteProductHeader header : result.ContainerList) {
            productNames.add(header.productName);
        }

        System.assert(productNames.size() > 0, 'Should have unique product groups');
    }

    /**
     * @description Test getFavorites method - verify detail population
     */
    @isTest
    static void testGetFavorites_VerifyDetails() {
        Test.startTest();
        QuoteProcurementController.FavoriteContainerWrapper result =
            QuoteProcurementFavoritesService.getFavorites();
        Test.stopTest();

        // Verify details are populated
        for (QuoteProcurementController.FavoriteProductHeader header : result.ContainerList) {
            if (header.listcontainerDetails != null && header.listcontainerDetails.size() > 0) {
                QuoteProcurementController.FavoriteProductDetail detail = header.listcontainerDetails[0];
                System.assertNotEquals(null, detail.containerType, 'Container type should be set');
                System.assertNotEquals(null, detail.FavoriteID, 'Favorite ID should be set');
            }
        }
    }

    /**
     * @description Test createQuoteFromFavorite - create new quote from case
     */
    @isTest
    static void testCreateQuoteFromFavorite_NewQuote() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        SBQQ__Favorite__c favorite = [SELECT Id FROM SBQQ__Favorite__c LIMIT 1];

        Test.startTest();
        String quoteId = QuoteProcurementFavoritesService.createQuoteFromFavorite(
            favorite.Id,
            testCase.Id,
            null,
            false // Not from quote screen - create new quote
        );
        Test.stopTest();

        System.assertNotEquals(null, quoteId, 'Quote ID should be returned');

        // Verify quote was created
        List<SBQQ__Quote__c> quotes = [SELECT Id FROM SBQQ__Quote__c WHERE Id = :quoteId];
        System.assertEquals(1, quotes.size(), 'Quote should be created');
    }

    /**
     * @description Test createQuoteFromFavorite - add to existing quote
     */
    @isTest
    static void testCreateQuoteFromFavorite_ExistingQuote() {
        // Create a test quote first
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = testAccount.Id,
            SBQQ__Status__c = 'Draft'
        );
        insert testQuote;

        SBQQ__Favorite__c favorite = [SELECT Id FROM SBQQ__Favorite__c LIMIT 1];

        Test.startTest();
        String quoteId = QuoteProcurementFavoritesService.createQuoteFromFavorite(
            favorite.Id,
            null,
            testQuote.Id,
            true // From quote screen - use existing quote
        );
        Test.stopTest();

        System.assertEquals(testQuote.Id, quoteId, 'Should return same quote ID');
    }

    /**
     * @description Test createQuoteFromFavorite - verify quote lines created
     */
    @isTest
    static void testCreateQuoteFromFavorite_VerifyQuoteLines() {
        // Create a test quote first
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = testAccount.Id,
            SBQQ__Status__c = 'Draft'
        );
        insert testQuote;

        SBQQ__Favorite__c favorite = [SELECT Id FROM SBQQ__Favorite__c LIMIT 1];

        Test.startTest();
        String quoteId = QuoteProcurementFavoritesService.createQuoteFromFavorite(
            favorite.Id,
            null,
            testQuote.Id,
            true
        );
        Test.stopTest();

        // Verify quote lines were created
        List<SBQQ__QuoteLine__c> quoteLines = [
            SELECT Id, SBQQ__RequiredBy__c, SBQQ__OptionLevel__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c = :quoteId
        ];

        System.assert(quoteLines.size() > 0, 'Quote lines should be created');

        // Verify parent quote line exists
        Boolean hasParentLine = false;
        for (SBQQ__QuoteLine__c ql : quoteLines) {
            if (ql.SBQQ__RequiredBy__c == null) {
                hasParentLine = true;
                break;
            }
        }
        System.assert(hasParentLine, 'Should have parent quote line');
    }

    /**
     * @description Test createQuoteFromFavorite - verify option levels
     */
    @isTest
    static void testCreateQuoteFromFavorite_VerifyOptionLevels() {
        // Create a test quote first
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = testAccount.Id,
            SBQQ__Status__c = 'Draft'
        );
        insert testQuote;

        SBQQ__Favorite__c favorite = [SELECT Id FROM SBQQ__Favorite__c LIMIT 1];

        Test.startTest();
        String quoteId = QuoteProcurementFavoritesService.createQuoteFromFavorite(
            favorite.Id,
            null,
            testQuote.Id,
            true
        );
        Test.stopTest();

        // Verify option levels are correct
        List<SBQQ__QuoteLine__c> quoteLines = [
            SELECT Id, SBQQ__OptionLevel__c, SBQQ__Product__r.Family
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c = :quoteId
            AND SBQQ__RequiredBy__c != null
        ];

        for (SBQQ__QuoteLine__c ql : quoteLines) {
            if (ql.SBQQ__Product__r.Family == 'Waste Category') {
                System.assertEquals(1, ql.SBQQ__OptionLevel__c, 'Waste Category should be level 1');
            } else if (ql.SBQQ__Product__r.Family == 'Waste Stream') {
                System.assertEquals(2, ql.SBQQ__OptionLevel__c, 'Waste Stream should be level 2');
            }
        }
    }

    /**
     * @description Test createQuoteFromFavorite - invalid favorite ID
     */
    @isTest
    static void testCreateQuoteFromFavorite_InvalidFavoriteId() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = testAccount.Id,
            SBQQ__Status__c = 'Draft'
        );
        insert testQuote;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            QuoteProcurementFavoritesService.createQuoteFromFavorite(
                'INVALID_ID_123',
                null,
                testQuote.Id,
                true
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('No favorite product found'),
                         'Should throw exception for invalid favorite ID');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for invalid favorite ID');
    }

    /**
     * @description Test getFavorites - no favorites exist
     */
    @isTest
    static void testGetFavorites_NoFavorites() {
        // Delete all favorite products
        delete [SELECT Id FROM SBQQ__FavoriteProduct__c];

        Test.startTest();
        QuoteProcurementController.FavoriteContainerWrapper result =
            QuoteProcurementFavoritesService.getFavorites();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertEquals(0, result.ContainerList.size(), 'Container list should be empty');
    }

    /**
     * @description Test createQuoteFromFavorite - verify line numbering
     */
    @isTest
    static void testCreateQuoteFromFavorite_LineNumbering() {
        // Create a test quote with existing quote line
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = testAccount.Id,
            SBQQ__Status__c = 'Draft'
        );
        insert testQuote;

        // Create existing quote line
        SBQQ__QuoteLine__c existingLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Number__c = 1
        );
        insert existingLine;

        SBQQ__Favorite__c favorite = [SELECT Id FROM SBQQ__Favorite__c LIMIT 1];

        Test.startTest();
        String quoteId = QuoteProcurementFavoritesService.createQuoteFromFavorite(
            favorite.Id,
            null,
            testQuote.Id,
            true
        );
        Test.stopTest();

        // Verify new quote lines start after existing line number
        List<SBQQ__QuoteLine__c> newQuoteLines = [
            SELECT Id, SBQQ__Number__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c = :quoteId
            AND Id != :existingLine.Id
            ORDER BY SBQQ__Number__c
        ];

        if (newQuoteLines.size() > 0) {
            System.assert(newQuoteLines[0].SBQQ__Number__c > existingLine.SBQQ__Number__c,
                         'New quote lines should have higher line numbers');
        }
    }
}
