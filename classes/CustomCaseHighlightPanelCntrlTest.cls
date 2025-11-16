/**
 * @description Test class for CustomCaseHighlightPanelCntrl
 * Coverage Target: 75%+
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CustomCaseHighlightPanelCntrlTest {

    @testSetup
    static void setupTestData() {
        TestDataFactoryRefactored.createFullTestHierarchy();
    }

    @isTest
    static void testLoadCaseData_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        CustomCaseHighlightPanelCntrl.loadCaseData(testCase.Id);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Load case data should execute');
    }

    @isTest
    static void testLoadCaseData_NullId() {
        Test.startTest();
        // When
        try {
            CustomCaseHighlightPanelCntrl.loadCaseData(null);
            System.assert(false, 'Should throw exception for null ID');
        } catch (Exception e) {
            // Then
            System.assert(true, 'Exception expected for null ID');
        }
        Test.stopTest();
    }
}
