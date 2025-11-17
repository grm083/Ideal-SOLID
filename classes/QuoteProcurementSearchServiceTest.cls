/**
 * @description Test class for QuoteProcurementSearchService
 * @author Waste Management
 * @date 2025
 */
@isTest
private class QuoteProcurementSearchServiceTest {

    @testSetup
    static void setupTestData() {
        Account clientAccount = TestDataFactoryRefactored.createAccount('Client', 'Client');
        insert clientAccount;

        Account locationAccount = TestDataFactoryRefactored.createAccount('Location', 'Location');
        locationAccount.ParentId = clientAccount.Id;
        insert locationAccount;

        Account vendorAccount = TestDataFactoryRefactored.createAccount('Vendor', 'Vendor');
        vendorAccount.Name = 'Test Vendor Search';
        vendorAccount.AccountNumber = 'VEN123';
        insert vendorAccount;

        Account_Position__c position = new Account_Position__c(
            AccountId__c = locationAccount.Id,
            Container_Position__c = 'Test Position'
        );
        insert position;

        Opportunity opp = TestDataFactoryRefactored.createOpportunity(clientAccount.Id);
        insert opp;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Account__c = locationAccount.Id
        );
        insert quote;

        Project_Code__c project = new Project_Code__c(
            Name = 'Test Project',
            Client_Account__c = clientAccount.Id,
            Active__c = true
        );
        insert project;
    }

    @isTest
    static void testSearchVendors() {
        Test.setFixedSearchResults(new List<Id>{
            [SELECT Id FROM Account WHERE RecordType.Name = 'Vendor' LIMIT 1].Id
        });

        Test.startTest();
        List<Account> result = QuoteProcurementSearchService.searchVendors('Test Vendor');
        Test.stopTest();

        System.assert(result != null, 'Should return search results');
    }

    @isTest
    static void testGetAllPositions() {
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];

        Test.startTest();
        List<Account_Position__c> result =
            QuoteProcurementSearchService.getAllPositions(locationAccount.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return all positions');
    }

    @isTest
    static void testSearchPositions_WithSearchString() {
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{
            [SELECT Id FROM Account_Position__c LIMIT 1].Id
        });

        Test.startTest();
        List<Account_Position__c> result =
            QuoteProcurementSearchService.searchPositions(locationAccount.Id, 'Test');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return search results');
    }

    @isTest
    static void testSearchPositions_EmptySearch() {
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];

        Test.startTest();
        List<Account_Position__c> result =
            QuoteProcurementSearchService.searchPositions(locationAccount.Id, '');
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return all positions for empty search');
    }

    @isTest
    static void testSearchActiveProjects() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{
            [SELECT Id FROM Project_Code__c LIMIT 1].Id
        });

        Test.startTest();
        List<Project_Code__c> result =
            QuoteProcurementSearchService.searchActiveProjects(quote.Id, 'Test');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return project search results');
    }
}
