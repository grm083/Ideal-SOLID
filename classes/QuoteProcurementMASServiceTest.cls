/**
 * @description Test class for QuoteProcurementMASService
 * @author Waste Management
 * @date 2025
 */
@isTest
private class QuoteProcurementMASServiceTest {

    @testSetup
    static void setupTestData() {
        Account clientAccount = TestDataFactoryRefactored.createAccount('Client', 'Client');
        insert clientAccount;

        Account locationAccount = TestDataFactoryRefactored.createAccount('Location', 'Location');
        locationAccount.ParentId = clientAccount.Id;
        insert locationAccount;

        Account vendorAccount = TestDataFactoryRefactored.createAccount('Vendor', 'Vendor');
        vendorAccount.Vendor_Business_Unit__c = 'BU001';
        vendorAccount.FacilityCode__c = 'FAC001';
        insert vendorAccount;

        Product2 product = TestDataFactoryRefactored.createProduct('Rolloff');
        insert product;

        Case testCase = TestDataFactoryRefactored.createCaseWithRelationships(
            clientAccount.Id, locationAccount.Id, null, null, 'Service_Request'
        );
        insert testCase;

        Opportunity opp = TestDataFactoryRefactored.createOpportunity(clientAccount.Id);
        opp.Case__c = testCase.Id;
        insert opp;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Account__c = locationAccount.Id,
            SBQQ__Status__c = 'Draft'
        );
        insert quote;

        SBQQ__QuoteLine__c parentLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1,
            Vendor__c = vendorAccount.Id,
            MASLibrary__c = 'LIB01',
            MASCompany__c = 'COMP01',
            MASAccount__c = 12345,
            MASCustomerUniqueId__c = 99999
        );
        insert parentLine;
    }

    @isTest
    static void testGetMASWrapper() {
        SBQQ__QuoteLine__c quoteLine = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];

        Test.startTest();
        QuoteProcurementMASService.MASWrapper result =
            QuoteProcurementMASService.getMASWrapper(quoteLine.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return MAS wrapper');
        System.assertEquals('LIB01', result.MASLibrary, 'Should include MAS Library');
        System.assertEquals('COMP01', result.MASCompany, 'Should include MAS Company');
    }

    @isTest
    static void testUpdateMASDetails() {
        SBQQ__QuoteLine__c quoteLine = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];

        QuoteProcurementMASService.MASWrapper masData = new QuoteProcurementMASService.MASWrapper();
        masData.MASLibrary = 'LIB02';
        masData.MASCompany = 'COMP02';
        masData.MASAccount = 54321;
        masData.MASBypassPrice = true;

        Test.startTest();
        QuoteProcurementMASService.MASResponseWrapper result =
            QuoteProcurementMASService.updateMASDetails(quoteLine.Id, masData);
        Test.stopTest();

        System.assertEquals(true, result.IsSuccess, 'Update should succeed');

        SBQQ__QuoteLine__c updated = [SELECT MASLibrary__c, MASCompany__c, MASAccount__c
                                     FROM SBQQ__QuoteLine__c WHERE Id = :quoteLine.Id];
        System.assertEquals('LIB02', updated.MASLibrary__c, 'MAS Library should be updated');
    }
}
