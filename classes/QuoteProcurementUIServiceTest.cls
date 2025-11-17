/**
 * @description Test class for QuoteProcurementUIService
 * @author Waste Management
 * @date 2025
 */
@isTest
private class QuoteProcurementUIServiceTest {

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
            Equipment_Size__c = '30 YD',
            SBQQ__ListPrice__c = 100
        );
        insert quoteLine;
    }

    @isTest
    static void testGetPicklistSchema() {
        Test.startTest();
        List<String> result = QuoteProcurementUIService.getPicklistSchema();
        Test.stopTest();

        System.assert(result.size() > 0, 'Should return picklist values');
    }

    @isTest
    static void testGetSLAOverrideReasons() {
        Test.startTest();
        List<String> result = QuoteProcurementUIService.getSLAOverrideReasons();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return SLA reasons');
    }

    @isTest
    static void testGetDeliveryOverrideReasons() {
        Test.startTest();
        List<String> result = QuoteProcurementUIService.getDeliveryOverrideReasons();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return delivery reasons');
    }

    @isTest
    static void testGetPicklistAPIName() {
        Test.startTest();
        String result = QuoteProcurementUIService.getPicklistAPIName('30 YD');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return API name');
    }

    @isTest
    static void testHasAssetAvailabilityPermission() {
        Test.startTest();
        Boolean result = QuoteProcurementUIService.hasAssetAvailabilityPermission();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return permission check');
    }

    @isTest
    static void testGetQuoteStatusDetails() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        SBQQ__Quote__c result = QuoteProcurementUIService.getQuoteStatusDetails(quote.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return quote details');
    }

    @isTest
    static void testGetFinancialDetails() {
        SBQQ__QuoteLine__c quoteLine = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];

        Test.startTest();
        QuoteProcurementUIService.FinancialDetailWrapper result =
            QuoteProcurementUIService.getFinancialDetails(quoteLine.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return financial details');
    }
}
