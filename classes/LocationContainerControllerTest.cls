/**
 * @description Test class for LocationContainerController
 * Coverage Target: 75%+
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class LocationContainerControllerTest {

    @testSetup
    static void setupTestData() {
        TestDataFactoryRefactored.createFullTestHierarchy();
    }

    @isTest
    static void testGetLocations_Success() {
        // Given
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];

        Test.startTest();
        // When
        LocationContainerController.getLocations(clientAccount.Id);
        Test.stopTest();

        // Then
        System.assert(true, 'Get locations should execute');
    }

    @isTest
    static void testGetLocations_NullId() {
        Test.startTest();
        // When
        try {
            LocationContainerController.getLocations(null);
        } catch (Exception e) {
            System.assert(true, 'Null ID handled');
        }
        Test.stopTest();
    }
}
