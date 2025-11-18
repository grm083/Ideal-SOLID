/**
 * @description Test class for QuoteProcurementProductOptionService
 *
 * Tests product option operations including:
 * - Adding product options to quote lines
 * - Removing product options from quote lines
 * - Removing product options with associated keys
 * - Updating key quantities
 *
 * Utilizes TestDataFactoryRefactored for consistent test data creation.
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class QuoteProcurementProductOptionServiceTest {

    /**
     * @description Set up test data for all test methods
     */
    @testSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = TestDataFactoryRefactored.createAccount();
        insert testAccount;

        // Create test products
        Product2 containerProduct = TestDataFactoryRefactored.createProduct('Test Container', 'Container');
        Product2 accessoryProduct = TestDataFactoryRefactored.createProduct('Test Accessory', 'Accessories');
        Product2 keyProduct = TestDataFactoryRefactored.createProduct(Constant_Util.KEYS, 'Accessories');
        insert new List<Product2>{containerProduct, accessoryProduct, keyProduct};

        // Create quote
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = testAccount.Id,
            SBQQ__Status__c = 'Draft'
        );
        insert testQuote;

        // Create parent quote line
        SBQQ__QuoteLine__c parentQuoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuote.Id,
            SBQQ__Product__c = containerProduct.Id,
            SBQQ__Number__c = 1,
            SBQQ__Quantity__c = 1,
            Equipment_Size__c = '10 Yard',
            SBQQ__StartDate__c = Date.today(),
            SID__c = 'TEST-SID-001'
        );
        insert parentQuoteLine;

        // Create product options
        SBQQ__ProductOption__c accessoryOption = new SBQQ__ProductOption__c(
            SBQQ__ConfiguredSKU__c = containerProduct.Id,
            SBQQ__OptionalSKU__c = accessoryProduct.Id,
            SBQQ__Quantity__c = 2,
            Occurrence_Type__c = 'TOS',
            CostModelType__c = 'Flat',
            Cost_Unit_of_Measure__c = 'Each',
            PriceUOM__c = 'Each',
            Schedule_Frequency__c = 'Weekly',
            Frequency_Interval__c = '1'
        );

        SBQQ__ProductOption__c keyOption = new SBQQ__ProductOption__c(
            SBQQ__ConfiguredSKU__c = accessoryProduct.Id,
            SBQQ__OptionalSKU__c = keyProduct.Id,
            SBQQ__Quantity__c = 1,
            Occurrence_Type__c = 'TOS'
        );

        insert new List<SBQQ__ProductOption__c>{accessoryOption, keyOption};
    }

    /**
     * @description Test addProductOption - success scenario
     */
    @isTest
    static void testAddProductOption_Success() {
        SBQQ__QuoteLine__c parentQL = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];
        SBQQ__ProductOption__c accessoryOption = [
            SELECT Id
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__OptionalSKU__r.Name = 'Test Accessory'
            LIMIT 1
        ];

        Test.startTest();
        String result = QuoteProcurementProductOptionService.addProductOption(
            parentQL.Id,
            accessoryOption.Id
        );
        Test.stopTest();

        // Verify quote line was created
        System.assertNotEquals(null, result, 'Should return quote line ID');
        System.assert(!result.startsWith('Error'), 'Should not return error: ' + result);

        // Verify the quote line exists
        List<SBQQ__QuoteLine__c> childLines = [
            SELECT Id, SBQQ__RequiredBy__c, SBQQ__Product__c, SBQQ__OptionLevel__c,
                   SBQQ__Quantity__c, Equipment_Size__c
            FROM SBQQ__QuoteLine__c
            WHERE Id = :result
        ];

        System.assertEquals(1, childLines.size(), 'Child quote line should be created');
        System.assertEquals(parentQL.Id, childLines[0].SBQQ__RequiredBy__c, 'Should be child of parent');
        System.assertEquals(1, childLines[0].SBQQ__OptionLevel__c, 'Should be option level 1');
        System.assertEquals(2, childLines[0].SBQQ__Quantity__c, 'Quantity should match product option');
        System.assertEquals('10 Yard', childLines[0].Equipment_Size__c, 'Equipment size should be inherited');
    }

    /**
     * @description Test addProductOption - Keys product special handling
     */
    @isTest
    static void testAddProductOption_KeysProduct() {
        SBQQ__QuoteLine__c parentQL = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];
        Product2 keyProduct = [SELECT Id FROM Product2 WHERE Name = :Constant_Util.KEYS LIMIT 1];
        SBQQ__ProductOption__c keyOption = [
            SELECT Id
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__OptionalSKU__c = :keyProduct.Id
            LIMIT 1
        ];

        Test.startTest();
        String result = QuoteProcurementProductOptionService.addProductOption(
            parentQL.Id,
            keyOption.Id
        );
        Test.stopTest();

        // Verify Keys special handling - end date should equal start date
        List<SBQQ__QuoteLine__c> keyLines = [
            SELECT Id, SBQQ__StartDate__c, SBQQ__EndDate__c
            FROM SBQQ__QuoteLine__c
            WHERE Id = :result
        ];

        System.assertEquals(1, keyLines.size(), 'Key quote line should be created');
        System.assertNotEquals(null, keyLines[0].SBQQ__EndDate__c, 'End date should be set for Keys');
        System.assertEquals(keyLines[0].SBQQ__StartDate__c, keyLines[0].SBQQ__EndDate__c,
                          'End date should equal start date for Keys');
    }

    /**
     * @description Test addProductOption - verify line numbering
     */
    @isTest
    static void testAddProductOption_LineNumbering() {
        SBQQ__QuoteLine__c parentQL = [SELECT Id, SBQQ__Number__c FROM SBQQ__QuoteLine__c LIMIT 1];
        SBQQ__ProductOption__c accessoryOption = [
            SELECT Id
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__OptionalSKU__r.Name = 'Test Accessory'
            LIMIT 1
        ];

        Test.startTest();
        String result = QuoteProcurementProductOptionService.addProductOption(
            parentQL.Id,
            accessoryOption.Id
        );
        Test.stopTest();

        // Verify line number is parent + 1
        SBQQ__QuoteLine__c childLine = [
            SELECT SBQQ__Number__c
            FROM SBQQ__QuoteLine__c
            WHERE Id = :result
        ];

        System.assertEquals(parentQL.SBQQ__Number__c + 1, childLine.SBQQ__Number__c,
                          'Line number should be parent + 1');
    }

    /**
     * @description Test addProductOption - invalid quote line ID
     */
    @isTest
    static void testAddProductOption_InvalidQuoteLineId() {
        SBQQ__ProductOption__c accessoryOption = [
            SELECT Id
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__OptionalSKU__r.Name = 'Test Accessory'
            LIMIT 1
        ];

        Test.startTest();
        String result = QuoteProcurementProductOptionService.addProductOption(
            'INVALID_ID_123',
            accessoryOption.Id
        );
        Test.stopTest();

        System.assert(result.contains('error') || result.contains('Error') || result.contains('not found'),
                     'Should return error message for invalid ID');
    }

    /**
     * @description Test removeProductOption - success scenario
     */
    @isTest
    static void testRemoveProductOption_Success() {
        // First, add a product option
        SBQQ__QuoteLine__c parentQL = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];
        SBQQ__ProductOption__c accessoryOption = [
            SELECT Id, SBQQ__OptionalSKU__c
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__OptionalSKU__r.Name = 'Test Accessory'
            LIMIT 1
        ];

        String addResult = QuoteProcurementProductOptionService.addProductOption(
            parentQL.Id,
            accessoryOption.Id
        );

        System.assertNotEquals(null, addResult, 'Should create quote line');

        Test.startTest();
        String result = QuoteProcurementProductOptionService.removeProductOption(
            parentQL.Id,
            accessoryOption.SBQQ__OptionalSKU__c
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', result, 'Should return SUCCESS');

        // Verify quote line was deleted
        List<SBQQ__QuoteLine__c> childLines = [
            SELECT Id
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__RequiredBy__c = :parentQL.Id
        ];

        System.assertEquals(0, childLines.size(), 'Child quote line should be deleted');
    }

    /**
     * @description Test removeProductOption - no matching quote line
     */
    @isTest
    static void testRemoveProductOption_NoMatchingLine() {
        SBQQ__QuoteLine__c parentQL = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];
        Product2 accessoryProduct = [SELECT Id FROM Product2 WHERE Name = 'Test Accessory' LIMIT 1];

        Test.startTest();
        String result = QuoteProcurementProductOptionService.removeProductOption(
            parentQL.Id,
            accessoryProduct.Id
        );
        Test.stopTest();

        System.assertNotEquals('SUCCESS', result, 'Should return error when no matching line found');
    }

    /**
     * @description Test removeProductOptionWithKeys - success scenario
     */
    @isTest
    static void testRemoveProductOptionWithKeys_Success() {
        // Create accessory and key quote lines
        SBQQ__QuoteLine__c parentQL = [SELECT Id, SBQQ__Quote__c FROM SBQQ__QuoteLine__c LIMIT 1];
        SBQQ__ProductOption__c accessoryOption = [
            SELECT Id, SBQQ__OptionalSKU__c
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__OptionalSKU__r.Name = 'Test Accessory'
            LIMIT 1
        ];
        SBQQ__ProductOption__c keyOption = [
            SELECT Id
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__OptionalSKU__r.Name = :Constant_Util.KEYS
            LIMIT 1
        ];

        // Create accessory quote line
        SBQQ__QuoteLine__c accessoryQL = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = parentQL.SBQQ__Quote__c,
            SBQQ__Product__c = accessoryOption.SBQQ__OptionalSKU__c,
            SBQQ__RequiredBy__c = parentQL.Id,
            SBQQ__ProductOption__c = accessoryOption.Id,
            SBQQ__Number__c = 2,
            SBQQ__Quantity__c = 1
        );
        insert accessoryQL;

        // Create key quote line
        SBQQ__QuoteLine__c keyQL = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = parentQL.SBQQ__Quote__c,
            SBQQ__Product__c = keyOption.SBQQ__OptionalSKU__c,
            SBQQ__RequiredBy__c = accessoryQL.Id,
            SBQQ__ProductOption__c = keyOption.Id,
            SBQQ__Number__c = 3,
            SBQQ__Quantity__c = 1
        );
        insert keyQL;

        Test.startTest();
        String result = QuoteProcurementProductOptionService.removeProductOptionWithKeys(
            parentQL.Id,
            accessoryOption.SBQQ__OptionalSKU__c,
            keyOption.Id
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', result, 'Should return SUCCESS');

        // Verify both quote lines were deleted
        List<SBQQ__QuoteLine__c> remainingLines = [
            SELECT Id
            FROM SBQQ__QuoteLine__c
            WHERE Id IN (:accessoryQL.Id, :keyQL.Id)
        ];

        System.assertEquals(0, remainingLines.size(), 'Both accessory and key lines should be deleted');
    }

    /**
     * @description Test updateKeysQuantity - success scenario
     */
    @isTest
    static void testUpdateKeysQuantity_Success() {
        // Create accessory and key quote lines
        SBQQ__QuoteLine__c parentQL = [SELECT Id, SBQQ__Quote__c FROM SBQQ__QuoteLine__c LIMIT 1];
        SBQQ__ProductOption__c accessoryOption = [
            SELECT Id, SBQQ__OptionalSKU__c
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__OptionalSKU__r.Name = 'Test Accessory'
            LIMIT 1
        ];
        SBQQ__ProductOption__c keyOption = [
            SELECT Id, SBQQ__OptionalSKU__c
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__OptionalSKU__r.Name = :Constant_Util.KEYS
            LIMIT 1
        ];

        // Create accessory quote line
        SBQQ__QuoteLine__c accessoryQL = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = parentQL.SBQQ__Quote__c,
            SBQQ__Product__c = accessoryOption.SBQQ__OptionalSKU__c,
            SBQQ__RequiredBy__c = parentQL.Id,
            SBQQ__ProductOption__c = accessoryOption.Id,
            SBQQ__Number__c = 2,
            SBQQ__Quantity__c = 1
        );
        insert accessoryQL;

        // Create key quote line
        SBQQ__QuoteLine__c keyQL = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = parentQL.SBQQ__Quote__c,
            SBQQ__Product__c = keyOption.SBQQ__OptionalSKU__c,
            SBQQ__RequiredBy__c = accessoryQL.Id,
            SBQQ__ProductOption__c = keyOption.Id,
            SBQQ__Number__c = 3,
            SBQQ__Quantity__c = 1
        );
        insert keyQL;

        // Create key map wrapper
        QuoteProcurementController.KeyMapWrapper keyWrapper = new QuoteProcurementController.KeyMapWrapper();
        keyWrapper.id = keyOption.Id;
        keyWrapper.value = '5';

        Test.startTest();
        String result = QuoteProcurementProductOptionService.updateKeysQuantity(
            parentQL.Id,
            new List<QuoteProcurementController.KeyMapWrapper>{keyWrapper}
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', result, 'Should return SUCCESS');

        // Verify quantity was updated
        SBQQ__QuoteLine__c updatedKeyQL = [
            SELECT SBQQ__Quantity__c
            FROM SBQQ__QuoteLine__c
            WHERE Id = :keyQL.Id
        ];

        System.assertEquals(5, updatedKeyQL.SBQQ__Quantity__c, 'Quantity should be updated to 5');
    }

    /**
     * @description Test updateKeysQuantity - zero quantity
     */
    @isTest
    static void testUpdateKeysQuantity_ZeroQuantity() {
        // Create accessory and key quote lines
        SBQQ__QuoteLine__c parentQL = [SELECT Id, SBQQ__Quote__c FROM SBQQ__QuoteLine__c LIMIT 1];
        SBQQ__ProductOption__c accessoryOption = [
            SELECT Id, SBQQ__OptionalSKU__c
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__OptionalSKU__r.Name = 'Test Accessory'
            LIMIT 1
        ];
        SBQQ__ProductOption__c keyOption = [
            SELECT Id, SBQQ__OptionalSKU__c
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__OptionalSKU__r.Name = :Constant_Util.KEYS
            LIMIT 1
        ];

        // Create accessory quote line
        SBQQ__QuoteLine__c accessoryQL = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = parentQL.SBQQ__Quote__c,
            SBQQ__Product__c = accessoryOption.SBQQ__OptionalSKU__c,
            SBQQ__RequiredBy__c = parentQL.Id,
            SBQQ__ProductOption__c = accessoryOption.Id,
            SBQQ__Number__c = 2,
            SBQQ__Quantity__c = 1
        );
        insert accessoryQL;

        // Create key quote line
        SBQQ__QuoteLine__c keyQL = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = parentQL.SBQQ__Quote__c,
            SBQQ__Product__c = keyOption.SBQQ__OptionalSKU__c,
            SBQQ__RequiredBy__c = accessoryQL.Id,
            SBQQ__ProductOption__c = keyOption.Id,
            SBQQ__Number__c = 3,
            SBQQ__Quantity__c = 10
        );
        insert keyQL;

        // Create key map wrapper with empty value (should set to 0)
        QuoteProcurementController.KeyMapWrapper keyWrapper = new QuoteProcurementController.KeyMapWrapper();
        keyWrapper.id = keyOption.Id;
        keyWrapper.value = '';

        Test.startTest();
        String result = QuoteProcurementProductOptionService.updateKeysQuantity(
            parentQL.Id,
            new List<QuoteProcurementController.KeyMapWrapper>{keyWrapper}
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', result, 'Should return SUCCESS');

        // Verify quantity was updated to 0
        SBQQ__QuoteLine__c updatedKeyQL = [
            SELECT SBQQ__Quantity__c
            FROM SBQQ__QuoteLine__c
            WHERE Id = :keyQL.Id
        ];

        System.assertEquals(0, updatedKeyQL.SBQQ__Quantity__c, 'Empty value should set quantity to 0');
    }

    /**
     * @description Test updateKeysQuantity - multiple keys
     */
    @isTest
    static void testUpdateKeysQuantity_MultipleKeys() {
        // Create accessory and two key quote lines
        SBQQ__QuoteLine__c parentQL = [SELECT Id, SBQQ__Quote__c FROM SBQQ__QuoteLine__c LIMIT 1];
        SBQQ__ProductOption__c accessoryOption = [
            SELECT Id, SBQQ__OptionalSKU__c
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__OptionalSKU__r.Name = 'Test Accessory'
            LIMIT 1
        ];
        SBQQ__ProductOption__c keyOption = [
            SELECT Id, SBQQ__OptionalSKU__c
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__OptionalSKU__r.Name = :Constant_Util.KEYS
            LIMIT 1
        ];

        // Create accessory quote line
        SBQQ__QuoteLine__c accessoryQL = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = parentQL.SBQQ__Quote__c,
            SBQQ__Product__c = accessoryOption.SBQQ__OptionalSKU__c,
            SBQQ__RequiredBy__c = parentQL.Id,
            SBQQ__ProductOption__c = accessoryOption.Id,
            SBQQ__Number__c = 2,
            SBQQ__Quantity__c = 1
        );
        insert accessoryQL;

        // Create another product option for second key
        SBQQ__ProductOption__c keyOption2 = new SBQQ__ProductOption__c(
            SBQQ__ConfiguredSKU__c = accessoryOption.SBQQ__OptionalSKU__c,
            SBQQ__OptionalSKU__c = keyOption.SBQQ__OptionalSKU__c,
            SBQQ__Quantity__c = 1
        );
        insert keyOption2;

        // Create two key quote lines
        SBQQ__QuoteLine__c keyQL1 = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = parentQL.SBQQ__Quote__c,
            SBQQ__Product__c = keyOption.SBQQ__OptionalSKU__c,
            SBQQ__RequiredBy__c = accessoryQL.Id,
            SBQQ__ProductOption__c = keyOption.Id,
            SBQQ__Number__c = 3,
            SBQQ__Quantity__c = 1
        );

        SBQQ__QuoteLine__c keyQL2 = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = parentQL.SBQQ__Quote__c,
            SBQQ__Product__c = keyOption.SBQQ__OptionalSKU__c,
            SBQQ__RequiredBy__c = accessoryQL.Id,
            SBQQ__ProductOption__c = keyOption2.Id,
            SBQQ__Number__c = 4,
            SBQQ__Quantity__c = 1
        );

        insert new List<SBQQ__QuoteLine__c>{keyQL1, keyQL2};

        // Create key map wrappers for both keys
        QuoteProcurementController.KeyMapWrapper keyWrapper1 = new QuoteProcurementController.KeyMapWrapper();
        keyWrapper1.id = keyOption.Id;
        keyWrapper1.value = '3';

        QuoteProcurementController.KeyMapWrapper keyWrapper2 = new QuoteProcurementController.KeyMapWrapper();
        keyWrapper2.id = keyOption2.Id;
        keyWrapper2.value = '7';

        Test.startTest();
        String result = QuoteProcurementProductOptionService.updateKeysQuantity(
            parentQL.Id,
            new List<QuoteProcurementController.KeyMapWrapper>{keyWrapper1, keyWrapper2}
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', result, 'Should return SUCCESS');

        // Verify both quantities were updated
        Map<Id, SBQQ__QuoteLine__c> updatedKeys = new Map<Id, SBQQ__QuoteLine__c>([
            SELECT Id, SBQQ__Quantity__c
            FROM SBQQ__QuoteLine__c
            WHERE Id IN (:keyQL1.Id, :keyQL2.Id)
        ]);

        System.assertEquals(3, updatedKeys.get(keyQL1.Id).SBQQ__Quantity__c, 'First key should be 3');
        System.assertEquals(7, updatedKeys.get(keyQL2.Id).SBQQ__Quantity__c, 'Second key should be 7');
    }
}
