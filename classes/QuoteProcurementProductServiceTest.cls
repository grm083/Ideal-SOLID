/**
 * @description Test class for QuoteProcurementProductService
 * @author Waste Management
 * @date 2025
 */
@isTest
private class QuoteProcurementProductServiceTest {

    @testSetup
    static void setupTestData() {
        Account clientAccount = TestDataFactoryRefactored.createAccount('Client', 'Client');
        insert clientAccount;

        Product2 product = TestDataFactoryRefactored.createProduct('Rolloff');
        insert product;

        Opportunity opp = TestDataFactoryRefactored.createOpportunity(clientAccount.Id);
        insert opp;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Account__c = clientAccount.Id,
            SBQQ__Status__c = 'Draft'
        );
        insert quote;

        SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1,
            Equipment_Size__c = '30 YD'
        );
        insert quoteLine;

        SBQQ__ProductOption__c prodOption = new SBQQ__ProductOption__c(
            SBQQ__ConfiguredSKU__c = product.Id,
            SBQQ__OptionalSKU__c = product.Id,
            SBQQ__Number__c = 1,
            SBQQ__Quantity__c = 1
        );
        insert prodOption;
    }

    @isTest
    static void testGetAccessories() {
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        Test.startTest();
        List<SBQQ__ProductOption__c> result =
            QuoteProcurementProductService.getAccessories(product.Id);
        Test.stopTest();

        System.assert(result != null, 'Should return accessories list');
    }

    @isTest
    static void testGetProductRules() {
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        Test.startTest();
        List<SBQQ__ErrorCondition__c> result =
            QuoteProcurementProductService.getProductRules(product.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return product rules list');
    }

    @isTest
    static void testUpdateConfigAttribute() {
        SBQQ__QuoteLine__c quoteLine = [SELECT Id, SBQQ__Quote__c FROM SBQQ__QuoteLine__c LIMIT 1];

        Test.startTest();
        String result = QuoteProcurementProductService.updateConfigAttribute(
            quoteLine.Id,
            'Equipment_Size__c',
            '40 YD',
            quoteLine.SBQQ__Quote__c
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', result, 'Update should succeed');
    }
}
