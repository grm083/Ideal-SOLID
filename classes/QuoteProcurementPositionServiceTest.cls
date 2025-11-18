/**
 * @description Test class for QuoteProcurementPositionService
 * @author Waste Management
 * @date 2025
 */
@isTest
private class QuoteProcurementPositionServiceTest {

    @testSetup
    static void setupTestData() {
        Account locationAccount = TestDataFactoryRefactored.createAccount('Location', 'Location');
        insert locationAccount;

        Product2 product = TestDataFactoryRefactored.createProduct('Rolloff');
        insert product;

        Account clientAccount = TestDataFactoryRefactored.createAccount('Client', 'Client');
        insert clientAccount;

        Opportunity opp = TestDataFactoryRefactored.createOpportunity(clientAccount.Id);
        insert opp;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Account__c = locationAccount.Id
        );
        insert quote;

        SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1
        );
        insert quoteLine;
    }

    @isTest
    static void testCreateOnsitePosition_Success() {
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];

        Test.startTest();
        String result = QuoteProcurementPositionService.createOnsitePosition(
            locationAccount.Id,
            'New Onsite Position'
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Position creation should succeed');

        List<Account_Position__c> positions = [SELECT Id FROM Account_Position__c
                                              WHERE AccountId__c = :locationAccount.Id
                                              AND Container_Position__c = 'New Onsite Position'];
        System.assertEquals(1, positions.size(), 'Position should be created');
    }

    @isTest
    static void testCreateOnsitePosition_Duplicate() {
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];

        Account_Position__c existingPosition = new Account_Position__c(
            AccountId__c = locationAccount.Id,
            Container_Position__c = 'Duplicate Position'
        );
        insert existingPosition;

        Test.startTest();
        String result = QuoteProcurementPositionService.createOnsitePosition(
            locationAccount.Id,
            'Duplicate Position'
        );
        Test.stopTest();

        System.assertEquals('Duplicate', result, 'Should return duplicate error');
    }

    @isTest
    static void testCreateOffsitePosition_Success() {
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];

        Test.startTest();
        String result = QuoteProcurementPositionService.createOffsitePosition(
            locationAccount.Id,
            'Offsite Test',
            '123 Test St',
            'Test City',
            'CA',
            '90210'
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Offsite position creation should succeed');
    }

    @isTest
    static void testGetQuoteLinePositions() {
        SBQQ__QuoteLine__c quoteLine = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];

        Test.startTest();
        List<SBQQ__QuoteLine__c> result =
            QuoteProcurementPositionService.getQuoteLinePositions(quoteLine.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return quoteline positions');
    }
}
