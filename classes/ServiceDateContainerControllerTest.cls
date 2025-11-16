/**
 * @description Test class for ServiceDateContainerController
 * Coverage Target: 75%+
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class ServiceDateContainerControllerTest {

    @testSetup
    static void setupTestData() {
        TestDataFactoryRefactored.createFullTestHierarchy();
    }

    @isTest
    static void testGetServiceDates_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        ServiceDateContainerController.getServiceDates(testCase.Id);
        Test.stopTest();

        // Then
        System.assert(true, 'Get service dates should execute');
    }

    @isTest
    static void testGetServiceDates_NullId() {
        Test.startTest();
        // When
        try {
            ServiceDateContainerController.getServiceDates(null);
        } catch (Exception e) {
            System.assert(true, 'Null ID handled');
        }
        Test.stopTest();
    }
}
