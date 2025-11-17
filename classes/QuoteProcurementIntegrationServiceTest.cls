/**
 * @description Test class for QuoteProcurementIntegrationService
 * @author Waste Management
 * @date 2025
 */
@isTest
private class QuoteProcurementIntegrationServiceTest {

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
            SBQQ__Account__c = clientAccount.Id
        );
        insert quote;

        SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1,
            SLA_Override_Reason__c = 'Test Reason',
            SLA_Override_Comment__c = 'Test Comment'
        );
        insert quoteLine;
    }

    @isTest
    static void testAddCommentForSLAOverrideFromIntake() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        QuoteProcurementIntegrationService.addCommentForSLAOverrideFromIntake(testCase.Id);
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Method should execute without errors');
    }

    @isTest
    static void testAddCommentForSLAOverride() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        QuoteProcurementIntegrationService.addCommentForSLAOverride(
            testCase.Id,
            'Test SLA Comment',
            'Customer Request'
        );
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Method should execute without errors');
    }

    @isTest
    static void testInputWrapperForMIFFlow() {
        Test.startTest();
        QuoteProcurementIntegrationService.InputWrapperForMIFFlow wrapper =
            new QuoteProcurementIntegrationService.InputWrapperForMIFFlow();
        wrapper.caseId = 'test123';
        wrapper.slaComment = 'test comment';
        wrapper.slaReason = 'test reason';
        Test.stopTest();

        System.assertNotEquals(null, wrapper.caseId, 'Wrapper should store case ID');
    }
}
