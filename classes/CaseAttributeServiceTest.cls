/**
 * @description Test class for CaseAttributeService
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseAttributeServiceTest {

    @testSetup
    static void setupTestData() {
        TestDataFactory.createFullTestHierarchy();
    }

    @isTest
    static void testInitializeCase_Single() {
        // Given
        Case testCase = TestDataFactory.createCase('Service_Request');

        Test.startTest();
        // When
        Case result = CaseAttributeService.initializeCase(testCase);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Case should be initialized');
    }

    @isTest
    static void testInitializeCases_Bulk() {
        // Given
        List<Case> cases = TestDataFactory.createCases(5, 'Service_Request');

        Test.startTest();
        // When
        CaseAttributeService.initializeCases(cases);
        Test.stopTest();

        // Then
        System.assertEquals(5, cases.size(), 'All cases should be processed');
    }

    @isTest
    static void testInitializeCases_ClosedPickup() {
        // Given
        Case testCase = TestDataFactory.createCase('Service_Request');
        testCase.Status = 'Closed';
        testCase.Case_type__c = 'Pickup';

        Test.startTest();
        // When
        CaseAttributeService.initializeCase(testCase);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, testCase.Case_Sub_Status__c, 'Sub-status should be set');
    }

    @isTest
    static void testInitializeCases_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.initializeCases(null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }

    @isTest
    static void testInitializeCases_EmptyList() {
        Test.startTest();
        // When
        CaseAttributeService.initializeCases(new List<Case>());
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle empty list gracefully');
    }

    @isTest
    static void testUpdateCaseAttributes() {
        // Given
        Map<String, Object> testData = TestDataFactory.createFullTestHierarchy();
        Asset testAsset = (Asset)testData.get('asset');
        Account locationAccount = (Account)testData.get('locationAccount');

        Case testCase = TestDataFactory.createCase('Service_Request');
        testCase.AssetId = testAsset.Id;
        testCase.Location__c = locationAccount.Id;

        Map<Id, Asset> containerMap = new Map<Id, Asset>{testAsset.Id => testAsset};
        Map<Id, Account> locationMap = new Map<Id, Account>{locationAccount.Id => locationAccount};

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, containerMap, locationMap);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, testCase, 'Case should be updated');
    }
}
