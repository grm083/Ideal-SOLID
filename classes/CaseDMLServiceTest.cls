/**
 * @description Test class for CaseDMLService
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseDMLServiceTest {

    @testSetup
    static void setupTestData() {
        TestDataFactory.createFullTestHierarchy();
    }

    @isTest
    static void testGetInstance() {
        Test.startTest();
        // When
        CaseDMLService service = CaseDMLService.getInstance();
        Test.stopTest();

        // Then
        System.assertNotEquals(null, service, 'Service instance should be created');
    }

    @isTest
    static void testInsertCase_Single() {
        // Given
        Case testCase = TestDataFactory.createCase('Service_Request');

        Test.startTest();
        // When
        CaseDMLService.DMLResult result = CaseDMLService.getInstance().insertCase(testCase);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(false, result.hasErrors, 'Should not have errors');
    }

    @isTest
    static void testInsertCases_Bulk() {
        // Given
        List<Case> cases = TestDataFactory.createCases(5, 'Service_Request');

        Test.startTest();
        // When
        CaseDMLService.DMLResult result = CaseDMLService.getInstance().insertCases(cases);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testInsertCases_Null() {
        Test.startTest();
        // When
        CaseDMLService.DMLResult result = CaseDMLService.getInstance().insertCases(null);
        Test.stopTest();

        // Then
        System.assertEquals(true, result.hasErrors, 'Should have error for null input');
    }

    @isTest
    static void testUpdateCase_Single() {
        // Given
        Case testCase = [SELECT Id, Status FROM Case LIMIT 1];
        testCase.Status = 'Open';

        Test.startTest();
        // When
        CaseDMLService.DMLResult result = CaseDMLService.getInstance().updateCase(testCase);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testUpdateCases_Bulk() {
        // Given
        List<Case> cases = [SELECT Id, Status FROM Case LIMIT 3];
        for (Case c : cases) {
            c.Status = 'Open';
        }

        Test.startTest();
        // When
        CaseDMLService.DMLResult result = CaseDMLService.getInstance().updateCases(cases);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testDeleteCase_Single() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        CaseDMLService.DMLResult result = CaseDMLService.getInstance().deleteCase(testCase);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testDeleteCases_Bulk() {
        // Given
        List<Case> cases = [SELECT Id FROM Case LIMIT 2];

        Test.startTest();
        // When
        CaseDMLService.DMLResult result = CaseDMLService.getInstance().deleteCases(cases);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
    }
}
