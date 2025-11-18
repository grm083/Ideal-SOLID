/**
 * @description Test class for QuoteProcurementOrderService
 * @author Waste Management
 * @date 2025
 */
@isTest
private class QuoteProcurementOrderServiceTest {

    @testSetup
    static void setupTestData() {
        Account clientAccount = TestDataFactoryRefactored.createAccount('Client', 'Client');
        insert clientAccount;

        Product2 product = TestDataFactoryRefactored.createProduct('Rolloff');
        insert product;

        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.AccountId = clientAccount.Id;
        insert testCase;

        Opportunity opp = TestDataFactoryRefactored.createOpportunity(clientAccount.Id);
        opp.Case__c = testCase.Id;
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
            SBQQ__Quantity__c = 1
        );
        insert quoteLine;

        Quote_Order__c order = new Quote_Order__c(
            Quote_Line__c = quoteLine.Id,
            Service_Date__c = Date.today().addDays(7),
            Service_Type__c = 'Delivery'
        );
        insert order;
    }

    @isTest
    static void testGetQuoteOrders() {
        SBQQ__QuoteLine__c quoteLine = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];

        Test.startTest();
        List<Quote_Order__c> result = QuoteProcurementOrderService.getQuoteOrders(quoteLine.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return quote orders');
    }

    @isTest
    static void testDeleteQuoteOrders() {
        Quote_Order__c order = [SELECT Id FROM Quote_Order__c LIMIT 1];

        Test.startTest();
        String result = QuoteProcurementOrderService.deleteQuoteOrders(
            new List<Quote_Order__c>{order}
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', result, 'Delete should succeed');
    }

    @isTest
    static void testGenerateOrderWrapper() {
        Test.startTest();
        QuoteProcurementOrderService.OrderWrapper result =
            QuoteProcurementOrderService.generateOrderWrapper();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return order wrapper');
    }
}
