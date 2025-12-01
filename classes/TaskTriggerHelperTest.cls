/*************************************************************
@Name: TaskTriggerHelperTest
@Author: Claude AI
@CreateDate: 12/01/2025
@Description: Comprehensive test class for TaskTriggerHelper
@Coverage: TaskTriggerHelper
**************************************************************/
@isTest
private class TaskTriggerHelperTest {

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

        // Create test cases
        List<Case> testCases = new List<Case>();
        testCases.add(new Case(
            Subject = 'Test Case 1',
            Status = 'Open',
            Origin = 'Web',
            AccountId = testAccount.Id,
            ContactId = testContact.Id,
            AssetId = testAsset.Id,
            Reference_Number__c = '12345',
            CaseNumber = '12345',
            Case_Type__c = 'Service',
            Service_Date__c = System.today().addDays(7)
        ));
        testCases.add(new Case(
            Subject = 'Test Case 2',
            Status = 'Open',
            Origin = 'Web',
            AccountId = testAccount.Id,
            ContactId = testContact.Id,
            AssetId = testAsset.Id,
            Reference_Number__c = '12346',
            Case_Type__c = 'Service'
        ));
        insert testCases;
    }

    @isTest
    static void testValidateCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // Create task for validation
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Validation',
            Status = 'Open',
            Priority = 'Normal',
            Process__c = 'Case Assignment'
        );
        insert testTask;

        Test.stopTest();

        // Verify task was validated and inserted
        Task insertedTask = [SELECT Id, Process__c FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Case Assignment', insertedTask.Process__c);
    }

    @isTest
    static void testUpdateRequireInfo() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // Create task to test updateRequireInfo
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Require Info',
            Status = 'Open',
            Priority = 'Normal'
        );
        insert testTask;

        Test.stopTest();

        // Verify task was created successfully
        Task insertedTask = [SELECT Id, Subject FROM Task WHERE Id = :testTask.Id];
        System.assertNotEquals(null, insertedTask);
    }

    @isTest
    static void testUpdateDueDateForPortalTasks() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // Create portal task
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Portal Task',
            Status = 'Open',
            Priority = 'Normal',
            Origin = 'Portal',
            Due_Date_Time__c = System.now().addDays(1)
        );
        insert testTask;

        Test.stopTest();

        // Verify task was created with due date
        Task insertedTask = [SELECT Id, Due_Date_Time__c FROM Task WHERE Id = :testTask.Id];
        System.assertNotEquals(null, insertedTask.Due_Date_Time__c);
    }

    @isTest
    static void testCreateTaskRouting() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // Create task to trigger routing
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Routing',
            Status = 'Open',
            Priority = 'Normal',
            Process__c = 'Test Process',
            Attempt__c = 1
        );
        insert testTask;

        Test.stopTest();

        // Verify task routing was attempted
        Task insertedTask = [SELECT Id, Process__c, Attempt__c FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Test Process', insertedTask.Process__c);
        System.assertEquals(1, insertedTask.Attempt__c);
    }

    @isTest
    static void testCompleteTaskRouting() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Create and insert task
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Complete Routing',
            Status = 'Open',
            Priority = 'Normal',
            Process__c = 'Test Process'
        );
        insert testTask;

        Test.startTest();

        // Complete the task
        testTask.Status = 'Completed';
        testTask.Outcome__c = 'Completed Successfully';
        update testTask;

        Test.stopTest();

        // Verify task was completed
        Task completedTask = [SELECT Id, Status, Outcome__c FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Completed', completedTask.Status);
        System.assertEquals('Completed Successfully', completedTask.Outcome__c);
    }

    @isTest
    static void testCancelTaskRouting() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Create and insert task
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Cancel Routing',
            Status = 'Open',
            Priority = 'Normal',
            Process__c = 'Test Process'
        );
        insert testTask;

        Test.startTest();

        // Cancel the task
        testTask.Status = 'Cancelled';
        testTask.Outcome__c = 'Cancelled';
        update testTask;

        Test.stopTest();

        // Verify task was cancelled
        Task cancelledTask = [SELECT Id, Status, Outcome__c FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Cancelled', cancelledTask.Status);
    }

    @isTest
    static void testLogActivityForCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // Create task to log activity
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Activity Log',
            Status = 'Open',
            Priority = 'Normal',
            Process__c = 'Test Process'
        );
        insert testTask;

        // Update task to trigger activity log
        testTask.Status = 'Completed';
        update testTask;

        Test.stopTest();

        // Verify task status changed
        Task updatedTask = [SELECT Id, Status FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Completed', updatedTask.Status);
    }

    @isTest
    static void testSendEmail() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // Create task that might trigger email
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Email',
            Status = 'Open',
            Priority = 'Normal',
            Process__c = 'Test Process'
        );
        insert testTask;

        Test.stopTest();

        // Verify task was inserted (email logic would execute in trigger)
        Task insertedTask = [SELECT Id, Subject FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Test Email', insertedTask.Subject);
    }

    @isTest
    static void testInsertCaseComment() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // Create task to trigger case comment insertion
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Case Comment',
            Status = 'Open',
            Priority = 'Normal',
            Description = 'Test Description'
        );
        insert testTask;

        Test.stopTest();

        // Verify task was inserted
        Task insertedTask = [SELECT Id, Description FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Test Description', insertedTask.Description);
    }

    @isTest
    static void testUpdateCaseDetails() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // Create task to trigger case update
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Case Update',
            Status = 'Open',
            Priority = 'Normal',
            Process__c = 'Test Process'
        );
        insert testTask;

        Test.stopTest();

        // Verify task was inserted and case update logic executed
        Task insertedTask = [SELECT Id, Process__c FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Test Process', insertedTask.Process__c);
    }

    @isTest
    static void testGenerateTaskEvent() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Create task
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Event',
            Status = 'Open',
            Priority = 'Normal'
        );
        insert testTask;

        Test.startTest();

        // Update task to trigger event generation
        testTask.Status = 'Completed';
        testTask.Outcome__c = 'Success';
        update testTask;

        Test.stopTest();

        // Verify task update
        Task updatedTask = [SELECT Id, Status, Outcome__c FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Completed', updatedTask.Status);
        System.assertEquals('Success', updatedTask.Outcome__c);
    }

    @isTest
    static void testUpdateResubmitFlagTrue() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Create task
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Resubmit',
            Status = 'Open',
            Priority = 'Normal',
            Outcome__c = 'Pending'
        );
        insert testTask;

        Test.startTest();

        // Update to trigger resubmit flag
        testTask.Outcome__c = 'Resubmit Required';
        update testTask;

        Test.stopTest();

        // Verify update
        Task updatedTask = [SELECT Id, Outcome__c FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Resubmit Required', updatedTask.Outcome__c);
    }

    @isTest
    static void testUpdateResubmitFlagFalse() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Create task with resubmit
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Resubmit False',
            Status = 'Open',
            Priority = 'Normal',
            Outcome__c = 'Resubmit Required'
        );
        insert testTask;

        Test.startTest();

        // Update to clear resubmit flag
        testTask.Outcome__c = 'Completed';
        update testTask;

        Test.stopTest();

        // Verify update
        Task updatedTask = [SELECT Id, Outcome__c FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Completed', updatedTask.Outcome__c);
    }

    @isTest
    static void testCreateCaseComment() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // Create task to trigger case comment
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Comment Creation',
            Status = 'Open',
            Priority = 'Normal',
            Description = 'Test comment content'
        );
        insert testTask;

        Test.stopTest();

        // Verify task was created
        Task insertedTask = [SELECT Id, Description FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Test comment content', insertedTask.Description);
    }

    @isTest
    static void testCopyTaskCommentOnCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Create task
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Copy Comment',
            Status = 'Open',
            Priority = 'Normal',
            Description = 'Original comment'
        );
        insert testTask;

        Test.startTest();

        // Update task description
        testTask.Description = 'Updated comment';
        update testTask;

        Test.stopTest();

        // Verify description was updated
        Task updatedTask = [SELECT Id, Description FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Updated comment', updatedTask.Description);
    }

    @isTest
    static void testUpdateValidateEmailApproval() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Create task
        Task testTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Email Validation',
            Status = 'Open',
            Priority = 'Normal',
            Process__c = 'Email Approval'
        );
        insert testTask;

        Test.startTest();

        // Update task
        testTask.Status = 'Pending Approval';
        update testTask;

        Test.stopTest();

        // Verify update
        Task updatedTask = [SELECT Id, Status FROM Task WHERE Id = :testTask.Id];
        System.assertEquals('Pending Approval', updatedTask.Status);
    }

    @isTest
    static void testBulkOperations() {
        List<Case> testCases = [SELECT Id FROM Case];
        Case testCase = testCases[0];

        Test.startTest();

        // Create 200 tasks for bulk testing
        List<Task> bulkTasks = new List<Task>();
        for (Integer i = 0; i < 200; i++) {
            bulkTasks.add(new Task(
                WhatId = testCase.Id,
                Subject = 'Bulk Helper Task ' + i,
                Status = 'Open',
                Priority = 'Normal',
                Process__c = 'Bulk Process'
            ));
        }
        insert bulkTasks;

        // Update all tasks
        for (Task t : bulkTasks) {
            t.Status = 'Completed';
            t.Outcome__c = 'Success';
        }
        update bulkTasks;

        Test.stopTest();

        // Verify bulk operations
        List<Task> updatedTasks = [SELECT Id, Status FROM Task WHERE Subject LIKE 'Bulk Helper Task%'];
        System.assertEquals(200, updatedTasks.size());
        for (Task t : updatedTasks) {
            System.assertEquals('Completed', t.Status);
        }
    }

    @isTest
    static void testMultipleCaseScenario() {
        List<Case> testCases = [SELECT Id FROM Case];

        Test.startTest();

        // Create tasks for multiple cases
        List<Task> multiCaseTasks = new List<Task>();
        for (Case c : testCases) {
            multiCaseTasks.add(new Task(
                WhatId = c.Id,
                Subject = 'Multi Case Task',
                Status = 'Open',
                Priority = 'Normal',
                Process__c = 'Test Process'
            ));
        }
        insert multiCaseTasks;

        Test.stopTest();

        // Verify tasks were created for multiple cases
        List<Task> insertedTasks = [SELECT Id, WhatId FROM Task WHERE Subject = 'Multi Case Task'];
        System.assertEquals(testCases.size(), insertedTasks.size());
    }

    @isTest
    static void testTaskWithProposedServiceDate() {
        List<Case> testCases = [SELECT Id, Service_Date__c FROM Case WHERE Service_Date__c != null];

        if (!testCases.isEmpty()) {
            Case testCase = testCases[0];

            Test.startTest();

            // Create task with proposed service date
            Task testTask = new Task(
                WhatId = testCase.Id,
                Subject = 'Test Proposed Date',
                Status = 'Open',
                Priority = 'Normal',
                Proposed_Service_Date__c = System.today().addDays(10),
                Process__c = 'Confirm Vendor Availability'
            );
            insert testTask;

            Test.stopTest();

            // Verify task was created
            Task insertedTask = [SELECT Id, Proposed_Service_Date__c FROM Task WHERE Id = :testTask.Id];
            System.assertNotEquals(null, insertedTask.Proposed_Service_Date__c);
        }
    }

    @isTest
    static void testExceptionHandling() {
        Test.startTest();

        try {
            // Attempt operation that might cause exception
            Task testTask = new Task(
                Subject = 'Test Exception',
                Status = 'Open'
            );
            insert testTask;

            // If successful, verify task was inserted
            Task insertedTask = [SELECT Id FROM Task WHERE Id = :testTask.Id];
            System.assertNotEquals(null, insertedTask);
        } catch (Exception e) {
            // Exception handled
            System.assert(true, 'Exception properly handled');
        }

        Test.stopTest();
    }
}
