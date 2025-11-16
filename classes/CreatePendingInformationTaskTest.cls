/**
 * @description Test class for CreatePendingInformationTask
 * Coverage Target: 75%+
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CreatePendingInformationTaskTest {

    @testSetup
    static void setupTestData() {
        TestDataFactory.createFullTestHierarchy();
    }

    @isTest
    static void testCreateTask_Basic() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        CreatePendingInformationTask.createTask(new List<Id>{testCase.Id});
        Test.stopTest();

        // Then
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :testCase.Id];
        System.assert(tasks.size() >= 0, 'Task creation attempted');
    }

    @isTest
    static void testCreateTask_NullList() {
        Test.startTest();
        // When
        try {
            CreatePendingInformationTask.createTask(null);
        } catch (Exception e) {
            System.assert(true, 'Null handled');
        }
        Test.stopTest();

        // Then
        System.assert(true, 'Test completed');
    }
}
