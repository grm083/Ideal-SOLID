/**
 * @description Test class for CaseController
 * Coverage Target: 75%+
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseControllerTest {

    @testSetup
    static void setupTestData() {
        TestDataFactoryRefactored.createFullTestHierarchy();
    }

    @isTest
    static void testCaseController_Basic() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When - Initialize controller
        ApexPages.StandardController sc = new ApexPages.StandardController(testCase);
        CaseController controller = new CaseController(sc);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, controller, 'Controller should be initialized');
    }
}
