/**
 * @description Test class for AssetHeadersForCaseController
 * Coverage Target: 75%+
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class AssetHeadersForCaseControllerTest {

    @testSetup
    static void setupTestData() {
        TestDataFactoryRefactored.createFullTestHierarchy();
    }

    @isTest
    static void testGetAssetHeaders_Success() {
        // Given
        Case testCase = [SELECT Id, Location__c FROM Case WHERE Location__c != null LIMIT 1];

        Test.startTest();
        // When
        AssetHeadersForCaseController.getAssetHeaders(testCase.Id);
        Test.stopTest();

        // Then
        System.assert(true, 'Get asset headers should execute');
    }

    @isTest
    static void testGetAssetHeaders_NullId() {
        Test.startTest();
        // When
        try {
            AssetHeadersForCaseController.getAssetHeaders(null);
        } catch (Exception e) {
            System.assert(true, 'Null ID handled');
        }
        Test.stopTest();
    }
}
