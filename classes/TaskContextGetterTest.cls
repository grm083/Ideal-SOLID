/**
 * @description Test class for TaskContextGetter
 *
 * This test class provides comprehensive coverage for the TaskContextGetter
 * data access layer, testing all query methods and bulk operations.
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class TaskContextGetterTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    @testSetup
    static void setupTestData() {
        // Create full test hierarchy
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();

        // Create additional tasks for bulk testing
        Case testCase = (Case)testData.get('case');
        Contact testContact = (Contact)testData.get('contact');

        List<Task> additionalTasks = new List<Task>();
        for (Integer i = 0; i < 5; i++) {
            Task t = TestDataFactoryRefactored.createTask(testCase.Id, testContact.Id);
            t.Subject = 'Bulk Test Task ' + i;
            additionalTasks.add(t);
        }
        insert additionalTasks;
    }

    // ========================================================================
    // SINGLE RECORD QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetTaskById_Success() {
        // Given: A task exists
        Task testTask = [SELECT Id FROM Task LIMIT 1];
        Set<Id> taskIds = new Set<Id>{testTask.Id};

        Test.startTest();

        // When: Getting task by Id
        Map<Id, Task> results = TaskContextGetter.getTaskById(taskIds);

        Test.stopTest();

        // Then: Task is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return one task');
        System.assert(results.containsKey(testTask.Id), 'Should contain the task Id');
        System.assertNotEquals(null, results.get(testTask.Id).Subject, 'Subject should be populated');
    }

    @isTest
    static void testGetTaskById_NullSet() {
        Test.startTest();

        // When: Getting task with null set
        Map<Id, Task> results = TaskContextGetter.getTaskById(null);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Empty map should be returned for null');
    }

    @isTest
    static void testGetTaskById_EmptySet() {
        Test.startTest();

        // When: Getting task with empty set
        Map<Id, Task> results = TaskContextGetter.getTaskById(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Empty map should be returned');
    }

    // ========================================================================
    // BULK QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetTaskById_BulkSuccess() {
        // Given: Multiple tasks exist
        List<Task> testTasks = [SELECT Id FROM Task LIMIT 5];
        Set<Id> taskIds = new Set<Id>();
        for (Task t : testTasks) {
            taskIds.add(t.Id);
        }

        Test.startTest();

        // When: Getting multiple tasks
        Map<Id, Task> results = TaskContextGetter.getTaskById(taskIds);

        Test.stopTest();

        // Then: All tasks are returned
        System.assertEquals(taskIds.size(), results.size(), 'All tasks should be returned');
        for (Id taskId : taskIds) {
            System.assert(results.containsKey(taskId), 'Result should contain task Id: ' + taskId);
            System.assertNotEquals(null, results.get(taskId).Subject, 'Subject should be populated');
        }
    }

    // ========================================================================
    // NEGATIVE TESTS
    // ========================================================================

    @isTest
    static void testGetTaskById_InvalidId() {
        // Given: An invalid task Id
        Id fakeId = '00T000000000000AAA'; // Valid Id format, doesn't exist
        Set<Id> taskIds = new Set<Id>{fakeId};

        Test.startTest();

        // When: Getting task with invalid Id
        Map<Id, Task> results = TaskContextGetter.getTaskById(taskIds);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'Empty map should be returned for invalid Id');
    }

    // ========================================================================
    // GOVERNOR LIMIT TESTS
    // ========================================================================

    @isTest
    static void testBulkOperations_WithinGovernorLimits() {
        // Given: Many tasks exist
        List<Task> testTasks = [SELECT Id FROM Task];
        Set<Id> taskIds = new Set<Id>();
        for (Task t : testTasks) {
            taskIds.add(t.Id);
        }

        Test.startTest();

        // When: Getting all tasks in bulk
        Map<Id, Task> results = TaskContextGetter.getTaskById(taskIds);

        // Then: Operation completes within governor limits
        Integer queriesUsed = Limits.getQueries();
        System.assert(queriesUsed < Limits.getLimitQueries(), 'Should be within SOQL query limits');

        Test.stopTest();

        // And: All tasks are returned
        System.assertEquals(taskIds.size(), results.size(), 'All tasks should be returned');
    }

    // ========================================================================
    // FIELD ACCESSIBILITY TESTS
    // ========================================================================

    @isTest
    static void testGetTaskById_FieldsAccessible() {
        // Given: A task exists
        Task testTask = [SELECT Id, Subject, Status, Priority FROM Task LIMIT 1];
        Set<Id> taskIds = new Set<Id>{testTask.Id};

        Test.startTest();

        // When: Getting task by Id
        Map<Id, Task> results = TaskContextGetter.getTaskById(taskIds);

        Test.stopTest();

        // Then: Standard fields are accessible
        Task result = results.get(testTask.Id);
        System.assertNotEquals(null, result.Subject, 'Subject should be accessible');
        System.assertNotEquals(null, result.Status, 'Status should be accessible');
        System.assertNotEquals(null, result.Priority, 'Priority should be accessible');
    }

    // ========================================================================
    // INTEGRATION TESTS
    // ========================================================================

    @isTest
    static void testGetTaskById_WithRelationships() {
        // Given: A task with case and contact relationships
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Case testCase = (Case)testData.get('case');
        Contact testContact = (Contact)testData.get('contact');

        Task taskWithRelationships = TestDataFactoryRefactored.createTask(testCase.Id, testContact.Id);
        insert taskWithRelationships;

        Set<Id> taskIds = new Set<Id>{taskWithRelationships.Id};

        Test.startTest();

        // When: Getting task with relationships
        Map<Id, Task> results = TaskContextGetter.getTaskById(taskIds);

        Test.stopTest();

        // Then: Relationship fields are populated
        Task result = results.get(taskWithRelationships.Id);
        System.assertEquals(testCase.Id, result.WhatId, 'WhatId should be populated');
        System.assertEquals(testContact.Id, result.WhoId, 'WhoId should be populated');
    }
}
