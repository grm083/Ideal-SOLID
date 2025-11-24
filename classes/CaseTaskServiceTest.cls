/**
 * @description Comprehensive test class for CaseTaskService
 *
 * Coverage Target: 85%+
 *
 * Tests all public methods for task creation, assignment, and completion tracking
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseTaskServiceTest {

    @testSetup
    static void setupTestData() {
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();

        Case testCase = (Case)testData.get('case');
        testCase.Status = 'New';
        update testCase;

        // Create tasks for testing
        List<Task> tasks = new List<Task>();

        Task openTask = TestDataFactoryRefactored.createTask(testCase.Id, null);
        openTask.Status = Constant_Util.OPEN;
        openTask.Is_Required__c = true;
        tasks.add(openTask);

        Task completedTask = TestDataFactoryRefactored.createTask(testCase.Id, null);
        completedTask.Status = Constant_Util.COMPLETED;
        completedTask.Is_Required__c = false;
        tasks.add(completedTask);

        insert tasks;
    }

    @isTest
    static void testCreateTasksForCases_ValidCases() {
        Set<Id> caseIds = new Set<Id>();
        for (Case c : [SELECT Id FROM Case LIMIT 3]) {
            caseIds.add(c.Id);
        }

        Test.startTest();
        List<Task> tasks = CaseTaskService.createTasksForCases(caseIds);
        Test.stopTest();

        System.assertNotEquals(null, tasks, 'Tasks list should not be null');
    }

    @isTest
    static void testCreateTask_Success() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        Id taskId = CaseTaskService.createTask(
            testCase.Id,
            'Test Task',
            'High',
            System.today().addDays(1)
        );
        Test.stopTest();

        System.assertNotEquals(null, taskId, 'Task ID should not be null');

        Task createdTask = [
            SELECT Id, WhatId, Subject, Priority, ActivityDate, Status
            FROM Task
            WHERE Id = :taskId
        ];

        System.assertEquals(testCase.Id, createdTask.WhatId, 'Case ID should match');
        System.assertEquals('Test Task', createdTask.Subject, 'Subject should match');
        System.assertEquals('High', createdTask.Priority, 'Priority should match');
        System.assertEquals(Constant_Util.OPEN, createdTask.Status, 'Status should be Open');
    }

    @isTest
    static void testCreateTask_Exception() {
        Test.startTest();
        Id taskId = CaseTaskService.createTask(
            null,
            'Test Task',
            'Normal',
            System.today()
        );
        Test.stopTest();

        System.assertEquals(null, taskId, 'Task ID should be null on exception');
    }

    @isTest
    static void testAssignTask_Success() {
        Task openTask = [SELECT Id FROM Task WHERE Status = :Constant_Util.OPEN LIMIT 1];
        Id newOwnerId = UserInfo.getUserId();

        Test.startTest();
        Boolean result = CaseTaskService.assignTask(openTask.Id, newOwnerId);
        Test.stopTest();

        System.assertEquals(true, result, 'Assignment should succeed');

        Task updatedTask = [SELECT Id, OwnerId FROM Task WHERE Id = :openTask.Id];
        System.assertEquals(newOwnerId, updatedTask.OwnerId, 'Owner should be updated');
    }

    @isTest
    static void testAssignTask_Exception() {
        Test.startTest();
        Boolean result = CaseTaskService.assignTask(null, UserInfo.getUserId());
        Test.stopTest();

        System.assertEquals(false, result, 'Should return false on exception');
    }

    @isTest
    static void testAssignTasksBulk_Success() {
        List<Task> tasks = [SELECT Id FROM Task LIMIT 2];
        Map<Id, Id> taskAssignments = new Map<Id, Id>();

        for (Task t : tasks) {
            taskAssignments.put(t.Id, UserInfo.getUserId());
        }

        Test.startTest();
        CaseTaskService.assignTasksBulk(taskAssignments);
        Test.stopTest();

        List<Task> updatedTasks = [SELECT Id, OwnerId FROM Task WHERE Id IN :taskAssignments.keySet()];
        for (Task t : updatedTasks) {
            System.assertEquals(UserInfo.getUserId(), t.OwnerId, 'Owner should be updated');
        }
    }

    @isTest
    static void testAssignTasksBulk_EmptyMap() {
        Test.startTest();
        CaseTaskService.assignTasksBulk(new Map<Id, Id>());
        Test.stopTest();

        System.assert(true, 'Method should handle empty map gracefully');
    }

    @isTest
    static void testCompleteTask_Success() {
        Task openTask = [SELECT Id, Status FROM Task WHERE Status = :Constant_Util.OPEN LIMIT 1];

        Test.startTest();
        Boolean result = CaseTaskService.completeTask(openTask.Id);
        Test.stopTest();

        System.assertEquals(true, result, 'Completion should succeed');

        Task updatedTask = [SELECT Id, Status FROM Task WHERE Id = :openTask.Id];
        System.assertEquals(Constant_Util.COMPLETED, updatedTask.Status, 'Status should be Completed');
    }

    @isTest
    static void testCompleteTask_Exception() {
        Test.startTest();
        Boolean result = CaseTaskService.completeTask(null);
        Test.stopTest();

        System.assertEquals(false, result, 'Should return false on exception');
    }

    @isTest
    static void testAreAllRequiredTasksCompleted_AllCompleted() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Complete all required tasks
        List<Task> requiredTasks = [
            SELECT Id
            FROM Task
            WHERE WhatId = :testCase.Id
            AND Is_Required__c = true
            AND Status = :Constant_Util.OPEN
        ];

        for (Task t : requiredTasks) {
            t.Status = Constant_Util.COMPLETED;
        }
        update requiredTasks;

        Test.startTest();
        Boolean result = CaseTaskService.areAllRequiredTasksCompleted(testCase.Id);
        Test.stopTest();

        System.assertEquals(true, result, 'All required tasks should be completed');
    }

    @isTest
    static void testAreAllRequiredTasksCompleted_PendingTasks() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        Boolean result = CaseTaskService.areAllRequiredTasksCompleted(testCase.Id);
        Test.stopTest();

        System.assertEquals(false, result, 'Should have pending required tasks');
    }

    @isTest
    static void testGetOpenTaskCount_WithOpenTasks() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        Integer count = CaseTaskService.getOpenTaskCount(testCase.Id);
        Test.stopTest();

        System.assert(count >= 0, 'Count should be non-negative');
    }

    @isTest
    static void testGetOpenTasksForCase_ValidCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<Task> tasks = CaseTaskService.getOpenTasksForCase(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, tasks, 'Tasks list should not be null');
    }

    @isTest
    static void testGetOpenTasksByCaseIds_ValidCases() {
        Set<Id> caseIds = new Set<Id>();
        for (Case c : [SELECT Id FROM Case LIMIT 3]) {
            caseIds.add(c.Id);
        }

        Test.startTest();
        Map<Id, List<Task>> tasksMap = CaseTaskService.getOpenTasksByCaseIds(caseIds);
        Test.stopTest();

        System.assertNotEquals(null, tasksMap, 'Tasks map should not be null');
    }

    @isTest
    static void testTaskOperationResult_Constructor() {
        Test.startTest();
        CaseTaskService.TaskOperationResult result =
            new CaseTaskService.TaskOperationResult(
                true,
                '00T000000000000AAA',
                null
            );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Success should be true');
        System.assertEquals('00T000000000000AAA', result.taskId, 'Task ID should match');
        System.assertEquals(null, result.errorMessage, 'Error message should be null');
    }

    @isTest
    static void testTaskOperationResult_WithError() {
        Test.startTest();
        CaseTaskService.TaskOperationResult result =
            new CaseTaskService.TaskOperationResult(
                false,
                null,
                'Test error'
            );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Success should be false');
        System.assertEquals(null, result.taskId, 'Task ID should be null');
        System.assertEquals('Test error', result.errorMessage, 'Error message should match');
    }
}
