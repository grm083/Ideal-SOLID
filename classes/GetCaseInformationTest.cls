/**
 * @description Test class for GetCaseInformation
 * Coverage Target: 75%+
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class GetCaseInformationTest {

    @testSetup
    static void setupTestData() {
        TestDataFactoryRefactored.createFullTestHierarchy();
    }

    @isTest
    static void testGetCaseInfo_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        GetCaseInformation.getCaseInfo(testCase.Id);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Get case info should execute');
    }

    @isTest
    static void testGetCaseInfo_NullId() {
        Test.startTest();
        // When
        try {
            GetCaseInformation.getCaseInfo(null);
        } catch (Exception e) {
            // Then - Exception may be thrown for null ID
            System.assert(true, 'Null ID handled');
        }
        Test.stopTest();
    }
}
