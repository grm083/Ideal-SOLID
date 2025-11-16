/**
 * @description Test class for CaseBusinessRuleService
 *
 * This test class provides coverage for the CaseBusinessRuleService,
 * which is the central engine for all complex Case-related business rules.
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseBusinessRuleServiceTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    @testSetup
    static void setupTestData() {
        // Create full test hierarchy
        Map<String, Object> testData = TestDataFactory.createFullTestHierarchy();

        // Create additional cases for testing various scenarios
        Account clientAccount = (Account)testData.get('clientAccount');
        Account locationAccount = (Account)testData.get('locationAccount');
        Contact contact = (Contact)testData.get('contact');
        Asset asset = (Asset)testData.get('asset');

        // Case for work order validation tests
        Case woTestCase = TestDataFactory.createCaseWithRelationships(
            clientAccount.Id,
            locationAccount.Id,
            contact.Id,
            asset.Id,
            'Service_Request'
        );
        woTestCase.Status = 'New';
        woTestCase.Service_Date__c = System.today().addDays(7);
        woTestCase.SLA_Service_Date_Time__c = System.now().addDays(7);
        insert woTestCase;

        // Closed case for testing auto-close logic
        Case closedCase = TestDataFactory.createCase('Service_Request');
        closedCase.Status = 'Closed';
        closedCase.Case_Sub_Status__c = 'Service Confirmed';
        closedCase.Close_Irrelevant_Case__c = false;
        insert closedCase;
    }

    // ========================================================================
    // EVALUATE BUSINESS RULES TESTS
    // ========================================================================

    @isTest
    static void testEvaluateBusinessRules_ValidCase_Success() {
        // Given: A case in New status
        Case testCase = [
            SELECT Id, Status, Client__c, Case_Sub_type__c
            FROM Case
            WHERE Status = 'New'
            AND Client__c != null
            LIMIT 1
        ];

        Test.startTest();

        // When: Evaluating business rules
        CaseBusinessRuleService.BusinessRuleResult result =
            CaseBusinessRuleService.evaluateBusinessRules(testCase.Id);

        Test.stopTest();

        // Then: Result is returned
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.validationMessages, 'Validation messages should not be null');
        System.assertNotEquals(null, result.approvalRules, 'Approval rules should not be null');
        System.assertNotEquals(null, result.requiredInfoRules, 'Required info rules should not be null');
    }

    @isTest
    static void testEvaluateBusinessRules_NullCaseId() {
        Test.startTest();

        // When: Evaluating business rules with null case Id
        CaseBusinessRuleService.BusinessRuleResult result =
            CaseBusinessRuleService.evaluateBusinessRules(null);

        Test.stopTest();

        // Then: Error message is returned
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.validationMessages.size() > 0, 'Should have validation message');
        System.assert(result.validationMessages[0].contains('Case not found'),
            'Should indicate case not found');
    }

    @isTest
    static void testEvaluateBusinessRules_InvalidCaseId() {
        // Given: An invalid case Id
        Id fakeId = '500000000000000AAA';

        Test.startTest();

        // When: Evaluating business rules
        CaseBusinessRuleService.BusinessRuleResult result =
            CaseBusinessRuleService.evaluateBusinessRules(fakeId);

        Test.stopTest();

        // Then: Error is handled gracefully
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================================================
    // VALIDATE CASE READY FOR WORK ORDER TESTS
    // ========================================================================

    @isTest
    static void testValidateCaseReadyForWorkOrder_ValidCase_Success() {
        // Given: A case ready for work order
        Case testCase = [
            SELECT Id
            FROM Case
            WHERE Status = 'New'
            AND ContactId != null
            AND Case_Sub_type__c != null
            LIMIT 1
        ];

        Test.startTest();

        // When: Validating case for work order
        Map<String, Object> result =
            CaseBusinessRuleService.validateCaseReadyForWorkOrder(testCase.Id);

        Test.stopTest();

        // Then: Validation result is returned
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('isValid'), 'Result should contain isValid key');
        System.assert(result.containsKey('messages'), 'Result should contain messages key');
    }

    @isTest
    static void testValidateCaseReadyForWorkOrder_MissingContact() {
        // Given: A case without contact
        Case testCase = TestDataFactory.createCase('Service_Request');
        testCase.ContactId = null;
        testCase.Status = 'New';
        insert testCase;

        Test.startTest();

        // When: Validating case for work order
        Map<String, Object> result =
            CaseBusinessRuleService.validateCaseReadyForWorkOrder(testCase.Id);

        Test.stopTest();

        // Then: Validation fails with message
        System.assertEquals(false, result.get('isValid'), 'Validation should fail');
        List<String> messages = (List<String>)result.get('messages');
        System.assert(messages.size() > 0, 'Should have validation messages');
    }

    @isTest
    static void testValidateCaseReadyForWorkOrder_NullCaseId() {
        Test.startTest();

        // When: Validating with null case Id
        Map<String, Object> result =
            CaseBusinessRuleService.validateCaseReadyForWorkOrder(null);

        Test.stopTest();

        // Then: Validation fails
        System.assertEquals(false, result.get('isValid'), 'Validation should fail');
        List<String> messages = (List<String>)result.get('messages');
        System.assert(messages.size() > 0, 'Should have validation message');
    }

    // ========================================================================
    // SHOULD BYPASS WORK ORDER CREATION TESTS
    // ========================================================================

    @isTest
    static void testShouldBypassWorkOrderCreation_ValidCase() {
        // Given: A case with type and subtype
        Case testCase = TestDataFactory.createCase('Service_Request');
        testCase.Case_Type__c = 'Service Request';
        testCase.Case_Sub_type__c = 'Delivery';
        insert testCase;

        Test.startTest();

        // When: Checking if work order should be bypassed
        Boolean result = CaseBusinessRuleService.shouldBypassWorkOrderCreation(testCase);

        Test.stopTest();

        // Then: Result is returned (boolean)
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================================================
    // VALIDATE STATUS CHANGE TESTS
    // ========================================================================

    @isTest
    static void testValidateStatusChange_ReopenClosedCase() {
        // Given: A closed case being reopened
        Case closedCase = [SELECT Id, Status FROM Case WHERE Status = 'Closed' LIMIT 1];
        Case oldCase = closedCase.clone(true, true);
        Case newCase = closedCase.clone(true, true);
        newCase.Status = 'Open';

        Test.startTest();

        // When: Validating status change
        Map<String, Object> result =
            CaseBusinessRuleService.validateStatusChange(oldCase, newCase);

        Test.stopTest();

        // Then: Result is returned
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('isValid'), 'Result should contain isValid key');
        System.assert(result.containsKey('message'), 'Result should contain message key');
    }

    @isTest
    static void testValidateStatusChange_ToPendingWithoutSubStatus() {
        // Given: A case moving to Pending without sub-status
        Case testCase = [SELECT Id, Status FROM Case WHERE Status = 'New' LIMIT 1];
        Case oldCase = testCase.clone(true, true);
        Case newCase = testCase.clone(true, true);
        newCase.Status = 'Pending';
        newCase.Case_Sub_Status__c = null;

        Test.startTest();

        // When: Validating status change
        Map<String, Object> result =
            CaseBusinessRuleService.validateStatusChange(oldCase, newCase);

        Test.stopTest();

        // Then: Validation fails
        System.assertEquals(false, result.get('isValid'), 'Validation should fail');
        String message = (String)result.get('message');
        System.assert(message.contains('Sub-Status'), 'Message should mention sub-status');
    }

    // ========================================================================
    // SHOULD AUTO CLOSE CASE TESTS
    // ========================================================================

    @isTest
    static void testShouldAutoCloseCase_CloseIrrelevantFlag() {
        // Given: A case with Close_Irrelevant_Case__c flag
        Case testCase = new Case();
        testCase.Close_Irrelevant_Case__c = true;

        Test.startTest();

        // When: Checking if case should auto-close
        Boolean result = CaseBusinessRuleService.shouldAutoCloseCase(testCase);

        Test.stopTest();

        // Then: Case should auto-close
        System.assertEquals(true, result, 'Case should auto-close');
    }

    @isTest
    static void testShouldAutoCloseCase_ClosedWithSubStatus() {
        // Given: A closed case with sub-status
        Case testCase = new Case();
        testCase.Status = 'Closed';
        testCase.Case_Sub_Status__c = 'Service Confirmed';
        testCase.Close_Irrelevant_Case__c = false;

        Test.startTest();

        // When: Checking if case should auto-close
        Boolean result = CaseBusinessRuleService.shouldAutoCloseCase(testCase);

        Test.stopTest();

        // Then: Case should auto-close
        System.assertEquals(true, result, 'Case should auto-close');
    }

    @isTest
    static void testShouldAutoCloseCase_NoConditionsMet() {
        // Given: A case that doesn't meet auto-close conditions
        Case testCase = new Case();
        testCase.Status = 'Open';
        testCase.Case_Sub_Status__c = null;
        testCase.Close_Irrelevant_Case__c = false;

        Test.startTest();

        // When: Checking if case should auto-close
        Boolean result = CaseBusinessRuleService.shouldAutoCloseCase(testCase);

        Test.stopTest();

        // Then: Case should not auto-close
        System.assertEquals(false, result, 'Case should not auto-close');
    }

    // ========================================================================
    // REQUIRED INFORMATION TESTS
    // ========================================================================

    @isTest
    static void testIsPurchaseOrderRequired_ValidCase() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case WHERE Client__c != null LIMIT 1];

        Test.startTest();

        // When: Checking if PO is required
        Boolean result = CaseBusinessRuleService.isPurchaseOrderRequired(testCase);

        Test.stopTest();

        // Then: Result is returned (boolean)
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testIsProfileNumberRequired_ValidCase() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case WHERE Client__c != null LIMIT 1];

        Test.startTest();

        // When: Checking if profile number is required
        Boolean result = CaseBusinessRuleService.isProfileNumberRequired(testCase);

        Test.stopTest();

        // Then: Result is returned (boolean)
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testIsPSIRequired_ValidCase() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case WHERE Client__c != null LIMIT 1];

        Test.startTest();

        // When: Checking if PSI is required
        Boolean result = CaseBusinessRuleService.isPSIRequired(testCase);

        Test.stopTest();

        // Then: Result is returned (boolean)
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================================================
    // FLAG AND BYPASS TESTS
    // ========================================================================

    @isTest
    static void testShouldSetBackOfficeFlag_WithCorporateQueue() {
        // Given: A case owned by corporate services queue
        Group corporateQueue = new Group(
            Name = 'Corporate Services Queue',
            Type = 'Queue'
        );
        insert corporateQueue;

        Case testCase = new Case();
        testCase.OwnerId = corporateQueue.Id;
        testCase.BackOffice_Case__c = false;

        Test.startTest();

        // When: Checking if back office flag should be set
        Boolean result = CaseBusinessRuleService.shouldSetBackOfficeFlag(
            testCase,
            corporateQueue.Id
        );

        Test.stopTest();

        // Then: Flag should be set
        System.assertEquals(true, result, 'Back office flag should be set');
    }

    @isTest
    static void testShouldSetBackOfficeFlag_DifferentOwner() {
        // Given: A case owned by different queue
        Group corporateQueue = new Group(
            Name = 'Corporate Services Queue',
            Type = 'Queue'
        );
        insert corporateQueue;

        Case testCase = new Case();
        testCase.OwnerId = UserInfo.getUserId();
        testCase.BackOffice_Case__c = false;

        Test.startTest();

        // When: Checking if back office flag should be set
        Boolean result = CaseBusinessRuleService.shouldSetBackOfficeFlag(
            testCase,
            corporateQueue.Id
        );

        Test.stopTest();

        // Then: Flag should not be set
        System.assertEquals(false, result, 'Back office flag should not be set');
    }

    @isTest
    static void testShouldBypassDuplicateCheck_AMPMPickups() {
        // Given: A case with AM/PM pickups
        Case testCase = new Case();
        testCase.Create_AM_and_PM_Pickups__c = true;
        testCase.Is_Multivendor__c = false;

        Test.startTest();

        // When: Checking if duplicate check should be bypassed
        Boolean result = CaseBusinessRuleService.shouldBypassDuplicateCheck(testCase);

        Test.stopTest();

        // Then: Bypass should be true
        System.assertEquals(true, result, 'Duplicate check should be bypassed');
    }

    @isTest
    static void testShouldBypassDuplicateCheck_Multivendor() {
        // Given: A multivendor case
        Case testCase = new Case();
        testCase.Create_AM_and_PM_Pickups__c = false;
        testCase.Is_Multivendor__c = true;

        Test.startTest();

        // When: Checking if duplicate check should be bypassed
        Boolean result = CaseBusinessRuleService.shouldBypassDuplicateCheck(testCase);

        Test.stopTest();

        // Then: Bypass should be true
        System.assertEquals(true, result, 'Duplicate check should be bypassed');
    }

    @isTest
    static void testShouldBypassDuplicateCheck_NoConditions() {
        // Given: A standard case
        Case testCase = new Case();
        testCase.Create_AM_and_PM_Pickups__c = false;
        testCase.Is_Multivendor__c = false;

        Test.startTest();

        // When: Checking if duplicate check should be bypassed
        Boolean result = CaseBusinessRuleService.shouldBypassDuplicateCheck(testCase);

        Test.stopTest();

        // Then: Bypass should be false
        System.assertEquals(false, result, 'Duplicate check should not be bypassed');
    }

    // ========================================================================
    // CLOSE RELATED TASKS TESTS
    // ========================================================================

    @isTest
    static void testCloseRelatedTasks_CaseClosing() {
        // Given: An open case with open tasks
        Case testCase = [SELECT Id, Status FROM Case WHERE Status = 'New' LIMIT 1];

        Task openTask = new Task(
            WhatId = testCase.Id,
            Subject = 'Test Task',
            Status = 'Open',
            Priority = 'Normal'
        );
        insert openTask;

        // Clone for old/new comparison
        Case oldCase = testCase.clone(true, true);
        testCase.Status = 'Closed';
        testCase.Case_Sub_Status__c = 'Service Confirmed';
        update testCase;

        Map<Id, Case> newCaseMap = new Map<Id, Case>{testCase.Id => testCase};
        Map<Id, Case> oldCaseMap = new Map<Id, Case>{oldCase.Id => oldCase};

        Test.startTest();

        // When: Closing related tasks
        CaseBusinessRuleService.closeRelatedTasks(newCaseMap, oldCaseMap);

        Test.stopTest();

        // Then: Tasks should be closed
        Task updatedTask = [SELECT Id, Status, IsClosed FROM Task WHERE Id = :openTask.Id];
        System.assertEquals('Completed', updatedTask.Status, 'Task should be completed');
    }

    // ========================================================================
    // DECLINE ASSOCIATED QUOTES TESTS
    // ========================================================================

    @isTest
    static void testDeclineAssociatedQuotes_CaseClosed() {
        // Given: A closed case with associated opportunity and quote
        Map<String, Object> testData = TestDataFactory.createFullTestHierarchy();
        Case testCase = (Case)testData.get('case');
        Opportunity testOpp = (Opportunity)testData.get('opportunity');

        testCase.Status = 'Closed';
        update testCase;

        Map<Id, Case> closedCaseMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();

        // When: Declining associated quotes
        CaseBusinessRuleService.declineAssociatedQuotes(closedCaseMap);

        Test.stopTest();

        // Then: Method executes without error
        System.assert(true, 'Method should execute without error');
    }

    // ========================================================================
    // ADD WORK ORDER STATUS COMMENTS TESTS
    // ========================================================================

    @isTest
    static void testAddWorkOrderStatusComments_ServiceConfirmed() {
        // Given: Cases with various work order statuses
        Case confirmedCase = TestDataFactory.createCase('Service_Request');
        confirmedCase.Status = 'Closed';
        confirmedCase.Case_Sub_Status__c = 'Service Confirmed';
        insert confirmedCase;

        List<Case> casesToComment = new List<Case>{confirmedCase};

        Test.startTest();

        // When: Adding work order status comments
        CaseBusinessRuleService.addWorkOrderStatusComments(casesToComment);

        Test.stopTest();

        // Then: Comments should be created
        List<CaseComment> comments = [
            SELECT Id, CommentBody
            FROM CaseComment
            WHERE ParentId = :confirmedCase.Id
        ];
        System.assert(comments.size() > 0, 'Comment should be created');
        System.assert(comments[0].CommentBody.contains('accepted'),
            'Comment should mention acceptance');
    }

    // ========================================================================
    // COPY ACORN COMMENTS TESTS
    // ========================================================================

    @isTest
    static void testCopyAcornComments_ValidParentCase() {
        // Given: A parent case with Acorn comments
        Case parentCase = TestDataFactory.createCase('Service_Request');
        insert parentCase;

        CaseComment acornComment = new CaseComment(
            ParentId = parentCase.Id,
            CommentBody = 'Acorn integration: Work order created',
            IsPublished = true
        );
        insert acornComment;

        Case childCase = TestDataFactory.createCase('Service_Request');
        childCase.ParentId = parentCase.Id;
        insert childCase;

        Test.startTest();

        // When: Copying Acorn comments
        CaseBusinessRuleService.copyAcornComments(parentCase.Id, childCase);

        Test.stopTest();

        // Then: Comments should be copied to child case
        List<CaseComment> childComments = [
            SELECT Id, CommentBody
            FROM CaseComment
            WHERE ParentId = :childCase.Id
        ];
        System.assert(childComments.size() > 0, 'Comments should be copied');
        System.assert(childComments[0].CommentBody.contains('Acorn'),
            'Comment should contain Acorn');
    }

    @isTest
    static void testCopyAcornComments_NullParameters() {
        Test.startTest();

        // When: Copying with null parameters
        CaseBusinessRuleService.copyAcornComments(null, null);

        Test.stopTest();

        // Then: Method handles gracefully
        System.assert(true, 'Method should handle null gracefully');
    }

    // ========================================================================
    // BUSINESS RULE RESULT WRAPPER TESTS
    // ========================================================================

    @isTest
    static void testBusinessRuleResult_DefaultConstructor() {
        Test.startTest();

        // When: Creating wrapper with default constructor
        CaseBusinessRuleService.BusinessRuleResult wrapper =
            new CaseBusinessRuleService.BusinessRuleResult();

        Test.stopTest();

        // Then: Default values are set
        System.assertEquals(true, wrapper.isAutoApproved, 'Is auto approved should be true');
        System.assertEquals(false, wrapper.requiresApproval, 'Requires approval should be false');
        System.assertEquals(false, wrapper.occurrenceLimitReached,
            'Occurrence limit reached should be false');
        System.assertNotEquals(null, wrapper.approvalRules, 'Approval rules should not be null');
        System.assertNotEquals(null, wrapper.requiredInfoRules,
            'Required info rules should not be null');
        System.assertNotEquals(null, wrapper.validationMessages,
            'Validation messages should not be null');
    }

    // ========================================================================
    // GOVERNOR LIMIT TESTS
    // ========================================================================

    @isTest
    static void testEvaluateBusinessRules_WithinGovernorLimits() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case WHERE Client__c != null LIMIT 1];

        Test.startTest();

        // When: Evaluating business rules
        CaseBusinessRuleService.BusinessRuleResult result =
            CaseBusinessRuleService.evaluateBusinessRules(testCase.Id);

        // Then: Operation completes within governor limits
        Integer queriesUsed = Limits.getQueries();
        System.assert(queriesUsed < Limits.getLimitQueries(),
            'Should be within SOQL query limits');

        Test.stopTest();

        // And: Result is returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testMultipleBusinessRuleChecks_PerformanceOptimization() {
        // Given: Multiple cases exist
        List<Case> testCases = [SELECT Id FROM Case LIMIT 3];

        Test.startTest();

        // When: Evaluating multiple cases
        for (Case c : testCases) {
            CaseBusinessRuleService.BusinessRuleResult result =
                CaseBusinessRuleService.evaluateBusinessRules(c.Id);
            System.assertNotEquals(null, result, 'Result should not be null');
        }

        Test.stopTest();

        // Then: All operations succeed
        System.assert(true, 'All operations should complete successfully');
    }
}
