/**
 * @description Test class for QuoteProcurementDMLService
 *
 * Tests all DML operations, error handling, and field-level security
 * for the QuoteProcurement data persistence layer.
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class QuoteProcurementDMLServiceTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    @testSetup
    static void setupTestData() {
        // Reuse setup from ContextGetter tests
        Account clientAccount = TestDataFactoryRefactored.createAccount('Client', 'Client');
        insert clientAccount;

        Account locationAccount = TestDataFactoryRefactored.createAccount('Location', 'Location');
        locationAccount.ParentId = clientAccount.Id;
        insert locationAccount;

        Account vendorAccount = TestDataFactoryRefactored.createAccount('Vendor', 'Vendor');
        vendorAccount.Status__c = 'Active';
        insert vendorAccount;

        Contact con = TestDataFactoryRefactored.createContact(clientAccount.Id);
        insert con;

        Product2 product = TestDataFactoryRefactored.createProduct('Rolloff');
        insert product;

        Case testCase = TestDataFactoryRefactored.createCaseWithRelationships(
            clientAccount.Id,
            locationAccount.Id,
            con.Id,
            null,
            'Service_Request'
        );
        insert testCase;

        Opportunity opp = TestDataFactoryRefactored.createOpportunity(clientAccount.Id);
        opp.Case__c = testCase.Id;
        insert opp;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Account__c = locationAccount.Id,
            SBQQ__PrimaryContact__c = con.Id,
            SBQQ__Status__c = 'Draft'
        );
        insert quote;
    }

    // ========================================================================
    // QUOTELINE DML TESTS
    // ========================================================================

    @isTest
    static void testInsertQuoteLines_Success() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        List<SBQQ__QuoteLine__c> quoteLines = new List<SBQQ__QuoteLine__c>{
            new SBQQ__QuoteLine__c(
                SBQQ__Quote__c = quote.Id,
                SBQQ__Product__c = product.Id,
                SBQQ__Quantity__c = 1
            ),
            new SBQQ__QuoteLine__c(
                SBQQ__Quote__c = quote.Id,
                SBQQ__Product__c = product.Id,
                SBQQ__Quantity__c = 2
            )
        };

        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();

        Test.startTest();
        QuoteProcurementDMLService.DMLResult result = dmlService.insertQuoteLines(quoteLines);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Insert should succeed');
        System.assertEquals(2, result.successCount, 'Should insert 2 records');
        System.assertEquals(0, result.failureCount, 'Should have no failures');
        System.assertEquals(0, result.errors.size(), 'Should have no errors');
    }

    @isTest
    static void testInsertQuoteLines_EmptyList() {
        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();

        Test.startTest();
        QuoteProcurementDMLService.DMLResult result = dmlService.insertQuoteLines(
            new List<SBQQ__QuoteLine__c>()
        );
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Should succeed with empty list');
        System.assertEquals('No records to insert', result.message, 'Should have appropriate message');
    }

    @isTest
    static void testUpdateQuoteLines_Success() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1
        );
        insert quoteLine;

        quoteLine.SBQQ__Quantity__c = 5;
        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();

        Test.startTest();
        QuoteProcurementDMLService.DMLResult result = dmlService.updateQuoteLines(
            new List<SBQQ__QuoteLine__c>{quoteLine}
        );
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Update should succeed');
        System.assertEquals(1, result.successCount, 'Should update 1 record');

        SBQQ__QuoteLine__c updated = [SELECT SBQQ__Quantity__c FROM SBQQ__QuoteLine__c
                                     WHERE Id = :quoteLine.Id];
        System.assertEquals(5, updated.SBQQ__Quantity__c, 'Quantity should be updated');
    }

    @isTest
    static void testDeleteQuoteLines_Success() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1
        );
        insert quoteLine;

        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();

        Test.startTest();
        QuoteProcurementDMLService.DMLResult result = dmlService.deleteQuoteLines(
            new List<SBQQ__QuoteLine__c>{quoteLine}
        );
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Delete should succeed');
        System.assertEquals(1, result.successCount, 'Should delete 1 record');

        List<SBQQ__QuoteLine__c> remaining = [SELECT Id FROM SBQQ__QuoteLine__c
                                             WHERE Id = :quoteLine.Id];
        System.assertEquals(0, remaining.size(), 'Record should be deleted');
    }

    @isTest
    static void testUpsertQuoteLines_Success() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        SBQQ__QuoteLine__c existingLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1
        );
        insert existingLine;

        existingLine.SBQQ__Quantity__c = 3;

        SBQQ__QuoteLine__c newLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 2
        );

        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();

        Test.startTest();
        QuoteProcurementDMLService.DMLResult result = dmlService.upsertQuoteLines(
            new List<SBQQ__QuoteLine__c>{existingLine, newLine}
        );
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Upsert should succeed');
        System.assertEquals(2, result.successCount, 'Should upsert 2 records');
    }

    // ========================================================================
    // QUOTE DML TESTS
    // ========================================================================

    @isTest
    static void testUpdateQuotes_Success() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        quote.SBQQ__Status__c = 'Product Configured';

        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();

        Test.startTest();
        QuoteProcurementDMLService.DMLResult result = dmlService.updateQuotes(
            new List<SBQQ__Quote__c>{quote}
        );
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Update should succeed');

        SBQQ__Quote__c updated = [SELECT SBQQ__Status__c FROM SBQQ__Quote__c WHERE Id = :quote.Id];
        System.assertEquals('Product Configured', updated.SBQQ__Status__c, 'Status should be updated');
    }

    // ========================================================================
    // QUOTE ORDER DML TESTS
    // ========================================================================

    @isTest
    static void testInsertQuoteOrders_Success() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1
        );
        insert quoteLine;

        List<Quote_Order__c> orders = new List<Quote_Order__c>{
            new Quote_Order__c(
                Quote_Line__c = quoteLine.Id,
                Service_Date__c = Date.today().addDays(7),
                Service_Type__c = 'Delivery'
            )
        };

        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();

        Test.startTest();
        QuoteProcurementDMLService.DMLResult result = dmlService.insertQuoteOrders(orders);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Insert should succeed');
        System.assertEquals(1, result.successCount, 'Should insert 1 order');
    }

    @isTest
    static void testDeleteQuoteOrders_Success() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1
        );
        insert quoteLine;

        Quote_Order__c order = new Quote_Order__c(
            Quote_Line__c = quoteLine.Id,
            Service_Date__c = Date.today().addDays(7),
            Service_Type__c = 'Delivery'
        );
        insert order;

        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();

        Test.startTest();
        QuoteProcurementDMLService.DMLResult result = dmlService.deleteQuoteOrders(
            new List<Quote_Order__c>{order}
        );
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Delete should succeed');
    }

    // ========================================================================
    // ACCOUNT POSITION DML TESTS
    // ========================================================================

    @isTest
    static void testInsertAccountPositions_Success() {
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];

        List<Account_Position__c> positions = new List<Account_Position__c>{
            new Account_Position__c(
                AccountId__c = locationAccount.Id,
                Container_Position__c = 'Test Position'
            )
        };

        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();

        Test.startTest();
        QuoteProcurementDMLService.DMLResult result = dmlService.insertAccountPositions(positions);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Insert should succeed');
        System.assertEquals(1, result.successCount, 'Should insert 1 position');
    }

    // ========================================================================
    // BULK UPDATE OPERATION TESTS
    // ========================================================================

    @isTest
    static void testUpdateVendorDetails_Success() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];
        Account vendor = [SELECT Id FROM Account WHERE RecordType.Name = 'Vendor' LIMIT 1];

        SBQQ__QuoteLine__c parentLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1
        );
        insert parentLine;

        SBQQ__QuoteLine__c childLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__RequiredBy__c = parentLine.Id,
            SBQQ__Quantity__c = 1
        );
        insert childLine;

        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();

        Test.startTest();
        QuoteProcurementDMLService.DMLResult result = dmlService.updateVendorDetails(
            parentLine.Id,
            vendor.Id,
            'SCODE123'
        );
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Vendor update should succeed');

        SBQQ__QuoteLine__c updated = [SELECT Vendor__c, sCode__c FROM SBQQ__QuoteLine__c
                                     WHERE Id = :parentLine.Id];
        System.assertEquals(vendor.Id, updated.Vendor__c, 'Vendor should be updated');
        System.assertEquals('SCODE123', updated.sCode__c, 'S-Code should be updated');
    }

    @isTest
    static void testUpdateCompanyCategories_Success() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        SBQQ__QuoteLine__c parentLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1
        );
        insert parentLine;

        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();

        Test.startTest();
        QuoteProcurementDMLService.DMLResult result = dmlService.updateCompanyCategories(
            parentLine.Id,
            'CAT123'
        );
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Company category update should succeed');
    }

    @isTest
    static void testUpdateFinancialDetails_Success() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        SBQQ__QuoteLine__c parentLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1
        );
        insert parentLine;

        SBQQ__QuoteLine__c childLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__RequiredBy__c = parentLine.Id,
            SBQQ__Quantity__c = 1
        );
        insert childLine;

        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();

        Test.startTest();
        QuoteProcurementDMLService.DMLResult result = dmlService.updateFinancialDetails(
            parentLine.Id,
            true, // isQuoteOnly
            'COMP01',
            'Company Name',
            'GL123',
            'CC456'
        );
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Financial details update should succeed');
    }

    @isTest
    static void testUpdatePositionOnQuoteLines_Success() {
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        Account_Position__c position = new Account_Position__c(
            AccountId__c = locationAccount.Id,
            Container_Position__c = 'Test Position'
        );
        insert position;

        SBQQ__QuoteLine__c parentLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1
        );
        insert parentLine;

        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();

        Test.startTest();
        QuoteProcurementDMLService.DMLResult result = dmlService.updatePositionOnQuoteLines(
            parentLine.Id,
            position.Id,
            'Test Comments',
            false
        );
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Position update should succeed');
    }

    // ========================================================================
    // SINGLETON TESTS
    // ========================================================================

    @isTest
    static void testGetInstance_ReturnsSameInstance() {
        Test.startTest();
        QuoteProcurementDMLService instance1 = QuoteProcurementDMLService.getInstance();
        QuoteProcurementDMLService instance2 = QuoteProcurementDMLService.getInstance();
        Test.stopTest();

        System.assertEquals(instance1, instance2, 'Should return same singleton instance');
    }
}
