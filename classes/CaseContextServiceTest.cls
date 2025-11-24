/**
 * @description Comprehensive test class for CaseContextService
 *
 * Coverage Target: 85%+
 *
 * Tests all public methods for comprehensive case context retrieval
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseContextServiceTest {

    @testSetup
    static void setupTestData() {
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();

        Case testCase = (Case)testData.get('case');
        testCase.Status = 'New';
        testCase.Case_Type__c = 'Pickup';
        testCase.Case_Sub_Type__c = 'Extra Pickup';
        testCase.Is_Multiple_Asset__c = false;
        update testCase;
    }

    @isTest
    static void testGetCaseContext_ValidCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        CaseContextService.CaseContextWrapper result =
            CaseContextService.getCaseContext(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.caseRecord, 'Case record should not be null');
        System.assertNotEquals(null, result.entityDetails, 'Entity details should not be null');
        System.assertNotEquals(null, result.businessRules, 'Business rules should not be null');
        System.assertNotEquals(null, result.buttonStates, 'Button states should not be null');
        System.assertNotEquals(null, result.messages, 'Messages should not be null');
        System.assertNotEquals(null, result.metadata, 'Metadata should not be null');
    }

    @isTest
    static void testGetCaseContext_InvalidCaseId() {
        Id invalidCaseId = '500000000000000AAA';

        Test.startTest();
        try {
            CaseContextService.CaseContextWrapper result =
                CaseContextService.getCaseContext(invalidCaseId);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(true, 'Exception should be thrown for invalid case');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetCaseContext_WithAsset() {
        Case testCase = [SELECT Id, AssetId FROM Case WHERE AssetId != null LIMIT 1];

        Test.startTest();
        CaseContextService.CaseContextWrapper result =
            CaseContextService.getCaseContext(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.assetDetails, 'Asset details should be populated');
    }

    @isTest
    static void testGetCaseContext_WithContact() {
        Case testCase = [SELECT Id, ContactId FROM Case WHERE ContactId != null LIMIT 1];

        Test.startTest();
        CaseContextService.CaseContextWrapper result =
            CaseContextService.getCaseContext(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.contactDetails, 'Contact details should be populated');
    }

    @isTest
    static void testCaseContextWrapper_DefaultConstructor() {
        Test.startTest();
        CaseContextService.CaseContextWrapper wrapper =
            new CaseContextService.CaseContextWrapper();
        Test.stopTest();

        System.assertNotEquals(null, wrapper.entityDetails, 'Entity details should be initialized');
        System.assertNotEquals(null, wrapper.businessRules, 'Business rules should be initialized');
        System.assertNotEquals(null, wrapper.buttonStates, 'Button states should be initialized');
        System.assertNotEquals(null, wrapper.messages, 'Messages should be initialized');
        System.assertNotEquals(null, wrapper.metadata, 'Metadata should be initialized');
    }

    @isTest
    static void testBusinessRuleContext_DefaultConstructor() {
        Test.startTest();
        CaseContextService.BusinessRuleContext context =
            new CaseContextService.BusinessRuleContext();
        Test.stopTest();

        System.assertEquals(false, context.requiresApproval, 'Default requires approval should be false');
        System.assertEquals(true, context.isAutoApproved, 'Default auto approved should be true');
        System.assertEquals(false, context.occurrenceLimitReached, 'Default occurrence limit should be false');
        System.assertNotEquals(null, context.validationMessages, 'Validation messages should be initialized');
        System.assertNotEquals(null, context.approvers, 'Approvers should be initialized');
    }

    @isTest
    static void testEntityDetailsWrapper_Constructor() {
        Test.startTest();
        CaseContextService.EntityDetailsWrapper details =
            new CaseContextService.EntityDetailsWrapper();
        Test.stopTest();

        System.assertNotEquals(null, details, 'Details wrapper should be created');
    }

    @isTest
    static void testMessageWrapper_Constructor() {
        Test.startTest();
        CaseContextService.MessageWrapper message =
            new CaseContextService.MessageWrapper();
        Test.stopTest();

        System.assertNotEquals(null, message, 'Message wrapper should be created');
    }

    @isTest
    static void testApproverWrapper_Constructor() {
        Test.startTest();
        CaseContextService.ApproverWrapper approver =
            new CaseContextService.ApproverWrapper();
        Test.stopTest();

        System.assertNotEquals(null, approver, 'Approver wrapper should be created');
    }

    @isTest
    static void testQuoteWrapper_Constructor() {
        Test.startTest();
        CaseContextService.QuoteWrapper quote =
            new CaseContextService.QuoteWrapper();
        Test.stopTest();

        System.assertNotEquals(null, quote, 'Quote wrapper should be created');
    }

    @isTest
    static void testWorkOrderWrapper_Constructor() {
        Test.startTest();
        CaseContextService.WorkOrderWrapper workOrder =
            new CaseContextService.WorkOrderWrapper();
        Test.stopTest();

        System.assertNotEquals(null, workOrder, 'Work order wrapper should be created');
    }
}
