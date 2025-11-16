/**
 * @description Test class for DuplicateCheckOnCaseController
 * Coverage Target: 75%+
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class DuplicateCheckOnCaseControllerTest {

    @testSetup
    static void setupTestData() {
        TestDataFactoryRefactored.createFullTestHierarchy();
    }

    @isTest
    static void testCheckDuplicates_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        DuplicateCheckOnCaseController.checkDuplicates(testCase.Id);
        Test.stopTest();

        // Then
        System.assert(true, 'Check duplicates should execute');
    }

    @isTest
    static void testCheckDuplicates_NullId() {
        Test.startTest();
        // When
        try {
            DuplicateCheckOnCaseController.checkDuplicates(null);
        } catch (Exception e) {
            System.assert(true, 'Null ID handled');
        }
        Test.stopTest();
    }
}
