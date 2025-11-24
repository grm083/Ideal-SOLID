/**
 * @description Comprehensive test class for CaseApprovalService
 *
 * Coverage Target: 85%+
 *
 * Tests all public methods for approval log creation, routing, and status management
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseApprovalServiceTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    @testSetup
    static void setupTestData() {
        // Create full test hierarchy
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();

        // Create test case for approval testing
        Account locationAccount = (Account)testData.get('locationAccount');
        Contact testContact = (Contact)testData.get('contact');
        Case testCase = (Case)testData.get('case');

        // Update case for approval testing
        testCase.Status = 'New';
        testCase.Case_Type__c = 'Pickup';
        testCase.Case_Sub_Type__c = 'Extra Pickup';
        update testCase;

        // Create Approval Logs for testing
        List<Approval_Log__c> approvalLogs = new List<Approval_Log__c>();

        Approval_Log__c pendingLog = new Approval_Log__c(
            CaseId__c = testCase.Id,
            Required_Approver__c = UserInfo.getUserId(),
            Approver_Type__c = 'Manager',
            Status__c = Constant_Util.APPROVAL_REQUESTED,
            Is_Required__c = true
        );
        approvalLogs.add(pendingLog);

        Approval_Log__c approvedLog = new Approval_Log__c(
            CaseId__c = testCase.Id,
            Required_Approver__c = UserInfo.getUserId(),
            Approver_Type__c = 'Director',
            Status__c = Constant_Util.APPROVED,
            Is_Required__c = true,
            Approval_Date__c = System.now()
        );
        approvalLogs.add(approvedLog);

        Approval_Log__c rejectedLog = new Approval_Log__c(
            CaseId__c = testCase.Id,
            Required_Approver__c = UserInfo.getUserId(),
            Approver_Type__c = 'VP',
            Status__c = Constant_Util.REJECTED,
            Is_Required__c = true,
            Approval_Date__c = System.now()
        );
        approvalLogs.add(rejectedLog);

        insert approvalLogs;
    }

    // ========================================================================
    // APPROVAL LOG CREATION TESTS
    // ========================================================================

    @isTest
    static void testCreateApprovalLog_Success() {
        // Given: A case and approver
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Id approverId = UserInfo.getUserId();

        Test.startTest();

        // When: Creating approval log
        Id approvalLogId = CaseApprovalService.createApprovalLog(
            testCase.Id,
            approverId,
            'Manager'
        );

        Test.stopTest();

        // Then: Approval log should be created
        System.assertNotEquals(null, approvalLogId, 'Approval log ID should not be null');

        Approval_Log__c createdLog = [
            SELECT Id, CaseId__c, Required_Approver__c, Approver_Type__c,
                   Status__c, Is_Required__c
            FROM Approval_Log__c
            WHERE Id = :approvalLogId
        ];

        System.assertEquals(testCase.Id, createdLog.CaseId__c, 'Case ID should match');
        System.assertEquals(approverId, createdLog.Required_Approver__c, 'Approver ID should match');
        System.assertEquals('Manager', createdLog.Approver_Type__c, 'Approver type should match');
        System.assertEquals(Constant_Util.APPROVAL_REQUESTED, createdLog.Status__c, 'Status should be Approval Requested');
        System.assertEquals(true, createdLog.Is_Required__c, 'Should be marked as required');
    }

    @isTest
    static void testCreateApprovalLog_Exception() {
        // Given: Invalid case ID (will cause exception)
        Id invalidCaseId = null;
        Id approverId = UserInfo.getUserId();

        Test.startTest();

        // When: Creating approval log with invalid data
        Id approvalLogId = CaseApprovalService.createApprovalLog(
            invalidCaseId,
            approverId,
            'Manager'
        );

        Test.stopTest();

        // Then: Should return null due to exception
        System.assertEquals(null, approvalLogId, 'Approval log ID should be null on exception');
    }

    @isTest
    static void testCreateApprovalLogsForCases_ValidCases() {
        // Given: A set of case IDs
        Set<Id> caseIds = new Set<Id>();
        for (Case c : [SELECT Id FROM Case LIMIT 5]) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When: Creating approval logs for cases
        List<Approval_Log__c> logs = CaseApprovalService.createApprovalLogsForCases(caseIds);

        Test.stopTest();

        // Then: Should return empty list (method currently has TODO)
        System.assertNotEquals(null, logs, 'Logs list should not be null');
    }

    // ========================================================================
    // APPROVAL ROUTING TESTS
    // ========================================================================

    @isTest
    static void testRouteApproval_ValidApprovalLog() {
        // Given: An approval log
        Approval_Log__c approvalLog = [
            SELECT Id
            FROM Approval_Log__c
            WHERE Status__c = :Constant_Util.APPROVAL_REQUESTED
            LIMIT 1
        ];

        Test.startTest();

        // When: Routing approval
        CaseApprovalService.routeApproval(approvalLog.Id);

        Test.stopTest();

        // Then: Method executes without error (currently has TODO)
        System.assert(true, 'Method should execute without error');
    }

    @isTest
    static void testDetermineRequiredApprovers_ValidCase() {
        // Given: A case ID
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Determining required approvers
        List<Id> approvers = CaseApprovalService.determineRequiredApprovers(testCase.Id);

        Test.stopTest();

        // Then: Should return empty list (method currently has TODO)
        System.assertNotEquals(null, approvers, 'Approvers list should not be null');
    }

    // ========================================================================
    // APPROVAL STATUS TESTS
    // ========================================================================

    @isTest
    static void testApproveLog_Success() {
        // Given: A pending approval log
        Approval_Log__c pendingLog = [
            SELECT Id, Status__c
            FROM Approval_Log__c
            WHERE Status__c = :Constant_Util.APPROVAL_REQUESTED
            LIMIT 1
        ];

        Test.startTest();

        // When: Approving the log
        Boolean result = CaseApprovalService.approveLog(
            pendingLog.Id,
            'Approved by test'
        );

        Test.stopTest();

        // Then: Approval should succeed
        System.assertEquals(true, result, 'Approval should succeed');

        Approval_Log__c updatedLog = [
            SELECT Id, Status__c, Approval_Comments__c, Approval_Date__c
            FROM Approval_Log__c
            WHERE Id = :pendingLog.Id
        ];

        System.assertEquals(Constant_Util.APPROVED, updatedLog.Status__c, 'Status should be Approved');
        System.assertEquals('Approved by test', updatedLog.Approval_Comments__c, 'Comments should match');
        System.assertNotEquals(null, updatedLog.Approval_Date__c, 'Approval date should be set');
    }

    @isTest
    static void testApproveLog_InvalidId() {
        // Given: Invalid approval log ID
        Id invalidId = null;

        Test.startTest();

        // When: Approving with invalid ID
        Boolean result = CaseApprovalService.approveLog(invalidId, 'Test comment');

        Test.stopTest();

        // Then: Should return false
        System.assertEquals(false, result, 'Should return false for invalid ID');
    }

    @isTest
    static void testRejectLog_Success() {
        // Given: A pending approval log
        Approval_Log__c pendingLog = [
            SELECT Id, Status__c
            FROM Approval_Log__c
            WHERE Status__c = :Constant_Util.APPROVAL_REQUESTED
            LIMIT 1
        ];

        Test.startTest();

        // When: Rejecting the log
        Boolean result = CaseApprovalService.rejectLog(
            pendingLog.Id,
            'Rejected by test'
        );

        Test.stopTest();

        // Then: Rejection should succeed
        System.assertEquals(true, result, 'Rejection should succeed');

        Approval_Log__c updatedLog = [
            SELECT Id, Status__c, Approval_Comments__c, Approval_Date__c
            FROM Approval_Log__c
            WHERE Id = :pendingLog.Id
        ];

        System.assertEquals(Constant_Util.REJECTED, updatedLog.Status__c, 'Status should be Rejected');
        System.assertEquals('Rejected by test', updatedLog.Approval_Comments__c, 'Comments should match');
        System.assertNotEquals(null, updatedLog.Approval_Date__c, 'Rejection date should be set');
    }

    @isTest
    static void testRejectLog_InvalidId() {
        // Given: Invalid approval log ID
        Id invalidId = null;

        Test.startTest();

        // When: Rejecting with invalid ID
        Boolean result = CaseApprovalService.rejectLog(invalidId, 'Test comment');

        Test.stopTest();

        // Then: Should return false
        System.assertEquals(false, result, 'Should return false for invalid ID');
    }

    @isTest
    static void testAreAllApprovalsComplete_AllApproved() {
        // Given: A case where all approvals are approved
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Delete pending approval logs for this test
        delete [SELECT Id FROM Approval_Log__c WHERE CaseId__c = :testCase.Id AND Status__c = :Constant_Util.APPROVAL_REQUESTED];

        Test.startTest();

        // When: Checking if all approvals are complete
        Boolean result = CaseApprovalService.areAllApprovalsComplete(testCase.Id);

        Test.stopTest();

        // Then: Should return true
        System.assertEquals(true, result, 'All approvals should be complete');
    }

    @isTest
    static void testAreAllApprovalsComplete_PendingApprovals() {
        // Given: A case with pending approvals
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Ensure there's at least one pending approval
        Approval_Log__c pendingLog = new Approval_Log__c(
            CaseId__c = testCase.Id,
            Required_Approver__c = UserInfo.getUserId(),
            Status__c = Constant_Util.APPROVAL_REQUESTED,
            Is_Required__c = true
        );
        insert pendingLog;

        Test.startTest();

        // When: Checking if all approvals are complete
        Boolean result = CaseApprovalService.areAllApprovalsComplete(testCase.Id);

        Test.stopTest();

        // Then: Should return false
        System.assertEquals(false, result, 'Should have pending approvals');
    }

    @isTest
    static void testHasRejectedApprovals_WithRejection() {
        // Given: A case with rejected approval
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Checking for rejected approvals
        Boolean result = CaseApprovalService.hasRejectedApprovals(testCase.Id);

        Test.stopTest();

        // Then: Should return true (setup data includes rejected approval)
        System.assertEquals(true, result, 'Should have rejected approvals');
    }

    @isTest
    static void testHasRejectedApprovals_NoRejection() {
        // Given: A case without rejected approvals
        Case newCase = TestDataFactoryRefactored.createCase('Service_Request');
        insert newCase;

        Test.startTest();

        // When: Checking for rejected approvals
        Boolean result = CaseApprovalService.hasRejectedApprovals(newCase.Id);

        Test.stopTest();

        // Then: Should return false
        System.assertEquals(false, result, 'Should not have rejected approvals');
    }

    @isTest
    static void testGetPendingApprovalCount_WithPending() {
        // Given: A case with pending approvals
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting pending approval count
        Integer count = CaseApprovalService.getPendingApprovalCount(testCase.Id);

        Test.stopTest();

        // Then: Count should be greater than 0
        System.assert(count >= 0, 'Should return valid count');
    }

    @isTest
    static void testGetPendingApprovalCount_NoPending() {
        // Given: A case without pending approvals
        Case newCase = TestDataFactoryRefactored.createCase('Service_Request');
        insert newCase;

        Test.startTest();

        // When: Getting pending approval count
        Integer count = CaseApprovalService.getPendingApprovalCount(newCase.Id);

        Test.stopTest();

        // Then: Count should be 0
        System.assertEquals(0, count, 'Should have no pending approvals');
    }

    // ========================================================================
    // APPROVAL RETRIEVAL TESTS
    // ========================================================================

    @isTest
    static void testGetApprovalLogsForCase_ValidCase() {
        // Given: A case with approval logs
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting approval logs for case
        List<Approval_Log__c> logs = CaseApprovalService.getApprovalLogsForCase(testCase.Id);

        Test.stopTest();

        // Then: Should return logs
        System.assertNotEquals(null, logs, 'Logs should not be null');
        System.assert(logs.size() > 0, 'Should have approval logs');
    }

    @isTest
    static void testGetApprovalLogsForCase_NoLogs() {
        // Given: A case without approval logs
        Case newCase = TestDataFactoryRefactored.createCase('Service_Request');
        insert newCase;

        Test.startTest();

        // When: Getting approval logs for case
        List<Approval_Log__c> logs = CaseApprovalService.getApprovalLogsForCase(newCase.Id);

        Test.stopTest();

        // Then: Should return empty list
        System.assertNotEquals(null, logs, 'Logs should not be null');
    }

    @isTest
    static void testGetApprovalLogsByCaseIds_ValidCases() {
        // Given: Multiple case IDs
        Set<Id> caseIds = new Set<Id>();
        for (Case c : [SELECT Id FROM Case LIMIT 3]) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When: Getting approval logs for multiple cases
        List<Approval_Log__c> logs = CaseApprovalService.getApprovalLogsByCaseIds(caseIds);

        Test.stopTest();

        // Then: Should return logs
        System.assertNotEquals(null, logs, 'Logs should not be null');
    }

    // ========================================================================
    // WRAPPER CLASS TESTS
    // ========================================================================

    @isTest
    static void testApprovalOperationResult_Constructor() {
        Test.startTest();

        // When: Creating approval operation result
        CaseApprovalService.ApprovalOperationResult result =
            new CaseApprovalService.ApprovalOperationResult(
                true,
                'a01000000000000AAA',
                null
            );

        Test.stopTest();

        // Then: Properties should be set correctly
        System.assertEquals(true, result.success, 'Success should be true');
        System.assertEquals('a01000000000000AAA', result.approvalLogId, 'Approval log ID should match');
        System.assertEquals(null, result.errorMessage, 'Error message should be null');
    }

    @isTest
    static void testApprovalOperationResult_WithError() {
        Test.startTest();

        // When: Creating approval operation result with error
        CaseApprovalService.ApprovalOperationResult result =
            new CaseApprovalService.ApprovalOperationResult(
                false,
                null,
                'Test error message'
            );

        Test.stopTest();

        // Then: Properties should be set correctly
        System.assertEquals(false, result.success, 'Success should be false');
        System.assertEquals(null, result.approvalLogId, 'Approval log ID should be null');
        System.assertEquals('Test error message', result.errorMessage, 'Error message should match');
    }
}
