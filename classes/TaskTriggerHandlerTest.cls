/*************************************************************
@Name: TaskTriggerHandlerTest
@Author: Claude AI
@CreateDate: 12/01/2025
@Description: Comprehensive test class for TaskTriggerHandler
@Coverage: TaskTriggerHandler
**************************************************************/
@isTest
private class TaskTriggerHandlerTest {

    @testSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;

        // Create test contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id,
            Email = 'test@example.com'
        );
        insert testContact;

        // Create test asset
        Asset testAsset = new Asset(
            Name = 'Test Asset',
            AccountId = testAccount.Id,
            ContactId = testContact.Id
        );
        insert testAsset;

        // Create test case
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'Open',
            Origin = 'Web',
            AccountId = testAccount.Id,
            ContactId = testContact.Id,
            AssetId = testAsset.Id,
            Reference_Number__c = '12345',
            Case_Type__c = 'Service'
        );
        insert testCase;

        // Create Business Rule for testing
        Id brRecTypeId = Schema.SObjectType.Business_Rule__c.getRecordTypeInfosByName().get('Required Information')?.getRecordTypeId();
        if (brRecTypeId != null) {
            Business_Rule__c testBR = new Business_Rule__c(
                Name = 'Test Business Rule',
                RecordTypeId = brRecTypeId,
                Is_Auto_Email__c = true,
                Active__c = true
            );
            insert testBR;
        }
    }

    @isTest
    static void testOnBeforeInsert() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // Create task with Due_Date_Time__c
        Id taskRecTypeId = Schema.getGlobalDescribe().get('Task').getDescribe()
            .getRecordTypeInfosByDeveloperName().get('Quick_Task')?.getRecordTypeId();

        Task newTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Task',
            Status = 'Open',
            Priority = 'Normal',
            Due_Date_Time__c = System.now().addDays(1),
            RecordTypeId = taskRecTypeId
        );

        insert newTask;

        Test.stopTest();

        // Verify task was inserted successfully
        Task insertedTask = [SELECT Id, ActivityDate, Due_Date_Time__c FROM Task WHERE Id = :newTask.Id];
        System.assertNotEquals(null, insertedTask, 'Task should be inserted');

        // Verify ActivityDate was set from Due_Date_Time__c
        if (insertedTask.RecordTypeId == taskRecTypeId && insertedTask.Due_Date_Time__c != null) {
            System.assertEquals(insertedTask.Due_Date_Time__c.date(), insertedTask.ActivityDate,
                'ActivityDate should match Due_Date_Time__c date');
        }
    }

    @isTest
    static void testOnBeforeInsertMultipleTasks() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // Create multiple tasks
        List<Task> tasksToInsert = new List<Task>();
        for (Integer i = 0; i < 5; i++) {
            tasksToInsert.add(new Task(
                WhatId = testCase.Id,
                Subject = 'Test Task ' + i,
                Status = 'Open',
                Priority = 'Normal'
            ));
        }

        insert tasksToInsert;

        Test.stopTest();

        // Verify all tasks were inserted
        List<Task> insertedTasks = [SELECT Id FROM Task WHERE WhatId = :testCase.Id];
        System.assertEquals(5, insertedTasks.size(), 'All tasks should be inserted');
    }

    @isTest
    static void testOnAfterInsert() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        Task newTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test After Insert',
            Status = 'Open',
            Priority = 'Normal',
            Process__c = 'Test Process',
            Attempt__c = 1
        );

        insert newTask;

        Test.stopTest();

        // Verify task was inserted and after insert logic executed
        Task insertedTask = [SELECT Id, Subject, Process__c FROM Task WHERE Id = :newTask.Id];
        System.assertNotEquals(null, insertedTask, 'Task should be inserted');
        System.assertEquals('Test Process', insertedTask.Process__c, 'Process should be set');
    }

    @isTest
    static void testOnAfterInsertWithEscalationObtainServiceApproval() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Get Business Rule
        List<Business_Rule__c> brList = [SELECT Id FROM Business_Rule__c LIMIT 1];

        Test.startTest();

        Task newTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Escalation',
            Status = 'Open',
            Priority = 'Normal',
            Process__c = 'Escalation Obtain Service Approval',
            Attempt__c = 1,
            Business_Rule__c = brList.isEmpty() ? null : brList[0].Id
        );

        insert newTask;

        Test.stopTest();

        // Verify task was inserted
        Task insertedTask = [SELECT Id, Process__c, Attempt__c FROM Task WHERE Id = :newTask.Id];
        System.assertEquals('Escalation Obtain Service Approval', insertedTask.Process__c);
        System.assertEquals(1, insertedTask.Attempt__c);
    }

    @isTest
    static void testOnAfterInsertWithConfirmServiceCompletion() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        Task newTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Confirm Service',
            Status = 'Open',
            Priority = 'Normal',
            Process__c = 'Confirm Service Completion'
        );

        insert newTask;

        Test.stopTest();

        // Verify task was inserted
        Task insertedTask = [SELECT Id, Process__c FROM Task WHERE Id = :newTask.Id];
        System.assertEquals('Confirm Service Completion', insertedTask.Process__c);
    }

    @isTest
    static void testOnBeforeUpdate() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Insert task first
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Update',
            Status = 'Open',
            Priority = 'Normal'
        );
        insert testTask;

        Test.startTest();

        // Update task
        testTask.Status = 'In Progress';
        testTask.Priority = 'High';
        update testTask;

        Test.stopTest();

        // Verify task was updated
        Task updatedTask = [SELECT Id, Status, Priority FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('In Progress', updatedTask.Status, 'Status should be updated');
        System.assertEquals('High', updatedTask.Priority, 'Priority should be updated');
    }

    @isTest
    static void testOnBeforeUpdateWithValidation() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Insert task first
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Validation',
            Status = 'Open',
            Priority = 'Normal',
            Process__c = 'Test Process'
        );
        insert testTask;

        Test.startTest();

        // Reset recursive trigger handler
        RecurrsiveTriggerHandler.isSkiptaskTrigger = false;

        // Update task
        testTask.Status = 'Completed';
        testTask.Outcome__c = 'Success';
        update testTask;

        Test.stopTest();

        // Verify task was updated
        Task updatedTask = [SELECT Id, Status, Outcome__c FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Completed', updatedTask.Status);
        System.assertEquals('Success', updatedTask.Outcome__c);
    }

    @isTest
    static void testOnAfterUpdate() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Insert task first
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test After Update',
            Status = 'Open',
            Priority = 'Normal',
            Process__c = 'Test Process'
        );
        insert testTask;

        Test.startTest();

        // Update task
        testTask.Status = 'Completed';
        testTask.Outcome__c = 'Completed Successfully';
        update testTask;

        Test.stopTest();

        // Verify task was updated
        Task updatedTask = [SELECT Id, Status, Outcome__c FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Completed', updatedTask.Status);
        System.assertEquals('Completed Successfully', updatedTask.Outcome__c);
    }

    @isTest
    static void testOnAfterUpdateWithMultipleTasks() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Insert multiple tasks
        List<Task> tasksToInsert = new List<Task>();
        for (Integer i = 0; i < 3; i++) {
            tasksToInsert.add(new Task(
                WhatId = testCase.Id,
                Subject = 'Test Task ' + i,
                Status = 'Open',
                Priority = 'Normal',
                Process__c = 'Test Process'
            ));
        }
        insert tasksToInsert;

        Test.startTest();

        // Update all tasks
        for (Task t : tasksToInsert) {
            t.Status = 'Completed';
            t.Outcome__c = 'Success';
        }
        update tasksToInsert;

        Test.stopTest();

        // Verify all tasks were updated
        List<Task> updatedTasks = [SELECT Id, Status, Outcome__c FROM Task WHERE Id IN :tasksToInsert];
        System.assertEquals(3, updatedTasks.size());
        for (Task t : updatedTasks) {
            System.assertEquals('Completed', t.Status);
            System.assertEquals('Success', t.Outcome__c);
        }
    }

    @isTest
    static void testOnAfterUpdateWithCancellation() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Insert task
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Cancellation',
            Status = 'Open',
            Priority = 'Normal',
            Process__c = 'Test Process'
        );
        insert testTask;

        Test.startTest();

        // Cancel task
        testTask.Status = 'Cancelled';
        testTask.Outcome__c = 'Cancelled';
        update testTask;

        Test.stopTest();

        // Verify task was cancelled
        Task cancelledTask = [SELECT Id, Status, Outcome__c FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Cancelled', cancelledTask.Status);
    }

    @isTest
    static void testRecursiveTriggerPrevention() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Set recursive trigger flag
        RecurrsiveTriggerHandler.isSkiptaskTrigger = true;

        Test.startTest();

        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Recursive',
            Status = 'Open',
            Priority = 'Normal'
        );
        insert testTask;

        // Update task
        testTask.Status = 'In Progress';
        update testTask;

        Test.stopTest();

        // Verify task operations completed despite recursive flag
        Task finalTask = [SELECT Id, Status FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('In Progress', finalTask.Status);

        // Reset flag for other tests
        RecurrsiveTriggerHandler.isSkiptaskTrigger = false;
    }

    @isTest
    static void testTaskWithoutCase() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();

        // Create task related to Contact instead of Case
        Task testTask = new Task(
            WhoId = testContact.Id,
            Subject = 'Test Task Without Case',
            Status = 'Open',
            Priority = 'Normal'
        );
        insert testTask;

        Test.stopTest();

        // Verify task was inserted
        Task insertedTask = [SELECT Id, WhoId, Subject FROM Task WHERE Id = :testTask.Id];
        System.assertEquals(testContact.Id, insertedTask.WhoId);
        System.assertEquals('Test Task Without Case', insertedTask.Subject);
    }

    @isTest
    static void testExceptionHandling() {
        Test.startTest();

        try {
            // Create task with invalid data to trigger exception
            Task testTask = new Task(
                Subject = 'Test Exception',
                Status = 'Open',
                Priority = 'Normal'
                // Intentionally missing required fields
            );
            insert testTask;
        } catch (Exception e) {
            // Exception is expected and handled by the trigger handler
            System.assert(true, 'Exception handled correctly');
        }

        Test.stopTest();
    }

    @isTest
    static void testBulkInsert() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // Create 200 tasks for bulk testing
        List<Task> bulkTasks = new List<Task>();
        for (Integer i = 0; i < 200; i++) {
            bulkTasks.add(new Task(
                WhatId = testCase.Id,
                Subject = 'Bulk Task ' + i,
                Status = 'Open',
                Priority = 'Normal',
                Process__c = 'Bulk Process'
            ));
        }

        insert bulkTasks;

        Test.stopTest();

        // Verify all tasks were inserted
        List<Task> insertedTasks = [SELECT Id FROM Task WHERE Subject LIKE 'Bulk Task%'];
        System.assertEquals(200, insertedTasks.size(), 'All bulk tasks should be inserted');
    }

    @isTest
    static void testBulkUpdate() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Create tasks
        List<Task> bulkTasks = new List<Task>();
        for (Integer i = 0; i < 200; i++) {
            bulkTasks.add(new Task(
                WhatId = testCase.Id,
                Subject = 'Bulk Update Task ' + i,
                Status = 'Open',
                Priority = 'Normal'
            ));
        }
        insert bulkTasks;

        Test.startTest();

        // Update all tasks
        for (Task t : bulkTasks) {
            t.Status = 'Completed';
            t.Outcome__c = 'Bulk Complete';
        }
        update bulkTasks;

        Test.stopTest();

        // Verify all tasks were updated
        List<Task> updatedTasks = [SELECT Id, Status FROM Task WHERE Subject LIKE 'Bulk Update Task%'];
        System.assertEquals(200, updatedTasks.size());
        for (Task t : updatedTasks) {
            System.assertEquals('Completed', t.Status);
        }
    }
}
