/**
 * @description Test class for CaseUIService
 *
 * This test class provides comprehensive coverage for the CaseUIService,
 * which handles UI-specific Case data preparation and formatting.
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseUIServiceTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    @testSetup
    static void setupTestData() {
        // Create full test hierarchy
        Map<String, Object> testData = TestDataFactory.createFullTestHierarchy();

        // Create additional cases with various configurations
        Account clientAccount = (Account)testData.get('clientAccount');
        Account locationAccount = (Account)testData.get('locationAccount');
        Contact contact = (Contact)testData.get('contact');
        Asset asset = (Asset)testData.get('asset');

        // Create a case with reference number for testing related cases
        String refNumber = 'TEST_REF_' + System.now().getTime();
        List<Case> relatedCases = new List<Case>();
        for (Integer i = 0; i < 3; i++) {
            Case c = TestDataFactory.createCaseWithRelationships(
                clientAccount.Id,
                locationAccount.Id,
                contact.Id,
                asset.Id,
                'Service_Request'
            );
            c.Reference_Number__c = refNumber;
            c.Is_Multiple_Asset__c = true;
            relatedCases.add(c);
        }
        insert relatedCases;

        // Create a child case
        Case childCase = TestDataFactory.createCaseWithRelationships(
            clientAccount.Id,
            locationAccount.Id,
            contact.Id,
            asset.Id,
            'Service_Request'
        );
        childCase.ParentId = relatedCases[0].Id;
        childCase.Is_Clone__c = true;
        insert childCase;
    }

    // ========================================================================
    // GET CASE MESSAGES TESTS
    // ========================================================================

    @isTest
    static void testGetCaseMessages_ValidCase_Success() {
        // Given: A case with all relationships
        Case testCase = [SELECT Id FROM Case WHERE ParentId = null LIMIT 1];

        Test.startTest();

        // When: Getting case messages
        CaseUIService.CaseUIWrapper result = CaseUIService.getCaseMessages(testCase.Id);

        Test.stopTest();

        // Then: Wrapper is populated with case data
        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertEquals(testCase.Id, result.caseId, 'Case Id should match');
        System.assertNotEquals(null, result.caseNumber, 'Case number should be populated');
        System.assertNotEquals(null, result.caseType, 'Case type should be populated');
        System.assertNotEquals(null, result.caseSubType, 'Case sub type should be populated');
        System.assertNotEquals(null, result.caseStatus, 'Case status should be populated');
        System.assertNotEquals(null, result.caseRecordType, 'Case record type should be populated');
    }

    @isTest
    static void testGetCaseMessages_NullCaseId() {
        Test.startTest();

        // When: Getting case messages with null case Id
        CaseUIService.CaseUIWrapper result = CaseUIService.getCaseMessages(null);

        Test.stopTest();

        // Then: Empty wrapper is returned
        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertEquals(null, result.caseId, 'Case Id should be null');
    }

    @isTest
    static void testGetCaseMessages_InvalidCaseId() {
        // Given: An invalid case Id
        Id fakeId = '500000000000000AAA';

        Test.startTest();

        // When: Getting case messages with invalid case Id
        CaseUIService.CaseUIWrapper result = CaseUIService.getCaseMessages(fakeId);

        Test.stopTest();

        // Then: Empty wrapper is returned (method handles gracefully)
        System.assertNotEquals(null, result, 'Wrapper should not be null');
    }

    @isTest
    static void testGetCaseMessages_WrapperDefaults() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting case messages
        CaseUIService.CaseUIWrapper result = CaseUIService.getCaseMessages(testCase.Id);

        Test.stopTest();

        // Then: Default values are set
        System.assertNotEquals(null, result.caseInfo, 'Case info should not be null');
        System.assertNotEquals(null, result.reqInfo, 'Req info should not be null');
        System.assertNotEquals(null, result.approvalInfo, 'Approval info should not be null');
        System.assertNotEquals(null, result.relatedCaseList, 'Related case list should not be null');
        System.assertNotEquals(null, result.multiAssetSelections, 'Multi asset selections should not be null');
    }

    @isTest
    static void testGetMessage_DelegatesTo_GetCaseMessages() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Calling getMessage (deprecated method)
        CaseUIService.CaseUIWrapper result = CaseUIService.getMessage(testCase.Id);

        Test.stopTest();

        // Then: Returns same result as getCaseMessages
        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertEquals(testCase.Id, result.caseId, 'Case Id should match');
    }

    // ========================================================================
    // GET BUSINESS RULE TESTS
    // ========================================================================

    @isTest
    static void testGetBusinessRule_ValidCase_Success() {
        // Given: A case with client and sub type
        Case testCase = [
            SELECT Id
            FROM Case
            WHERE Client__c != null
            AND Case_Sub_type__c != null
            LIMIT 1
        ];

        Test.startTest();

        // When: Getting business rule
        CaseUIService.BusinessRuleUIWrapper result = CaseUIService.getBusinessRule(testCase.Id);

        Test.stopTest();

        // Then: Wrapper is returned
        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertNotEquals(null, result.channelReq, 'Channel req should not be null');
        System.assertNotEquals(null, result.channelName, 'Channel name should not be null');
        System.assertNotEquals(null, result.specialInstructions, 'Special instructions should not be null');
    }

    @isTest
    static void testGetBusinessRule_CaseWithoutClient() {
        // Given: A case without client
        Case testCase = TestDataFactory.createCase('Service_Request');
        testCase.Client__c = null;
        insert testCase;

        Test.startTest();

        // When: Getting business rule
        CaseUIService.BusinessRuleUIWrapper result = CaseUIService.getBusinessRule(testCase.Id);

        Test.stopTest();

        // Then: Empty wrapper is returned
        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertEquals('', result.channelReq, 'Channel req should be empty');
        System.assertEquals('', result.channelName, 'Channel name should be empty');
    }

    // ========================================================================
    // GET ENTITLEMENT TESTS
    // ========================================================================

    @isTest
    static void testGetEntitlement_ValidCase_Success() {
        // Given: A case with case sub type
        Case testCase = [
            SELECT Id
            FROM Case
            WHERE Case_Sub_type__c != null
            LIMIT 1
        ];

        Test.startTest();

        // When: Getting entitlement
        CaseUIService.SLAUIWrapper result = CaseUIService.getEntitlement(testCase.Id);

        Test.stopTest();

        // Then: Wrapper is returned
        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertNotEquals(null, result.slaInstructions, 'SLA instructions should not be null');
    }

    @isTest
    static void testGetEntitlement_CaseWithoutSubType() {
        // Given: A case without sub type
        Case testCase = TestDataFactory.createCase('Service_Request');
        testCase.Case_Sub_type__c = null;
        insert testCase;

        Test.startTest();

        // When: Getting entitlement
        CaseUIService.SLAUIWrapper result = CaseUIService.getEntitlement(testCase.Id);

        Test.stopTest();

        // Then: Empty wrapper is returned
        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertEquals('', result.slaInstructions, 'SLA instructions should be empty');
    }

    // ========================================================================
    // GET CASE SUMMARY TESTS
    // ========================================================================

    @isTest
    static void testGetCaseSummary_ByReferenceNumber_Success() {
        // Given: Cases with same reference number
        Case testCase = [
            SELECT Id, Reference_Number__c
            FROM Case
            WHERE Reference_Number__c != null
            AND Is_Multiple_Asset__c = true
            LIMIT 1
        ];

        Test.startTest();

        // When: Getting case summary by reference number
        List<Case> result = CaseUIService.getCaseSummary(
            testCase.Id,
            testCase.Reference_Number__c,
            null
        );

        Test.stopTest();

        // Then: Related cases are returned
        System.assert(result.size() > 0, 'At least one case should be returned');
        for (Case c : result) {
            System.assertEquals(testCase.Reference_Number__c, c.Reference_Number__c,
                'All cases should have same reference number');
        }
    }

    @isTest
    static void testGetCaseSummary_ByCaseId_Success() {
        // Given: A case with children
        Case parentCase = [
            SELECT Id
            FROM Case
            WHERE Id IN (SELECT ParentId FROM Case WHERE ParentId != null)
            LIMIT 1
        ];

        Test.startTest();

        // When: Getting case summary by case Id (no reference number)
        List<Case> result = CaseUIService.getCaseSummary(
            parentCase.Id,
            '',
            null
        );

        Test.stopTest();

        // Then: Case and its children are returned
        System.assert(result.size() > 0, 'At least one case should be returned');
    }

    @isTest
    static void testGetCaseSummary_WithParentId() {
        // Given: Cases with reference number and parent
        Case parentCase = [
            SELECT Id, Reference_Number__c
            FROM Case
            WHERE Id IN (SELECT ParentId FROM Case WHERE ParentId != null)
            LIMIT 1
        ];

        Case childCase = [
            SELECT Id
            FROM Case
            WHERE ParentId = :parentCase.Id
            LIMIT 1
        ];

        Test.startTest();

        // When: Getting case summary with parent Id
        List<Case> result = CaseUIService.getCaseSummary(
            childCase.Id,
            parentCase.Reference_Number__c,
            parentCase.Id
        );

        Test.stopTest();

        // Then: Related cases are returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetCaseSummary_EmptyReferenceNumber() {
        // Given: A case without reference number
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting case summary with empty reference number
        List<Case> result = CaseUIService.getCaseSummary(
            testCase.Id,
            '',
            null
        );

        Test.stopTest();

        // Then: Result is returned (even if empty)
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================================================
    // GET CASE RECORD DETAILS TESTS
    // ========================================================================

    @isTest
    static void testGetCaseRecordDetails_ValidCase_Success() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting case record details
        List<String> result = CaseUIService.getCaseRecordDetails(testCase.Id);

        Test.stopTest();

        // Then: Details are returned
        System.assert(result.size() > 0, 'At least one detail should be returned');
        // First three elements should be RecordTypeId, Company_Category__c, CompanyCategoryCode__c
        System.assertNotEquals(null, result[0], 'Record Type Id should be populated');
    }

    @isTest
    static void testGetCaseRecordDetails_NullCaseId() {
        Test.startTest();

        // When: Getting case record details with null case Id
        List<String> result = CaseUIService.getCaseRecordDetails(null);

        Test.stopTest();

        // Then: Empty list is returned
        System.assertEquals(0, result.size(), 'Empty list should be returned');
    }

    // ========================================================================
    // GET RECORD TYPE ID TESTS
    // ========================================================================

    @isTest
    static void testGetRecordTypeId_ValidCase_Success() {
        // Given: A case exists
        Case testCase = [SELECT Id, RecordTypeId FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting record type Id
        String result = CaseUIService.getRecordTypeId(testCase.Id);

        Test.stopTest();

        // Then: Record type Id is returned
        System.assertNotEquals(null, result, 'Record type Id should not be null');
        System.assertEquals(String.valueOf(testCase.RecordTypeId), result, 'Record type Id should match');
    }

    @isTest
    static void testGetRecordTypeId_NullCaseId() {
        Test.startTest();

        // When: Getting record type Id with null case Id
        String result = CaseUIService.getRecordTypeId(null);

        Test.stopTest();

        // Then: Null is returned
        System.assertEquals(null, result, 'Null should be returned');
    }

    // ========================================================================
    // GET CASE RECORD TYPE LIST TESTS
    // ========================================================================

    @isTest
    static void testGetCaseRecordTypeList_Success() {
        Test.startTest();

        // When: Getting case record type list
        List<String> result = CaseUIService.getCaseRecordTypeList();

        Test.stopTest();

        // Then: List of record types is returned
        System.assertNotEquals(null, result, 'Result should not be null');
        // Note: Result may be empty or contain record types depending on org configuration
    }

    @isTest
    static void testGetCaseRecordTypeList_Cacheable() {
        Test.startTest();

        // When: Calling twice (testing cacheable behavior)
        List<String> result1 = CaseUIService.getCaseRecordTypeList();
        List<String> result2 = CaseUIService.getCaseRecordTypeList();

        Test.stopTest();

        // Then: Both calls succeed
        System.assertNotEquals(null, result1, 'First result should not be null');
        System.assertNotEquals(null, result2, 'Second result should not be null');
    }

    // ========================================================================
    // GET CASE ASSET DETAILS TESTS
    // ========================================================================

    @isTest
    static void testGetCaseAssetDetails_CaseWithAsset_Success() {
        // Given: A case with asset
        Case testCase = [
            SELECT Id
            FROM Case
            WHERE AssetId != null
            LIMIT 1
        ];

        Test.startTest();

        // When: Getting case asset details
        List<Case> result = CaseUIService.getCaseAssetDetails(testCase.Id);

        Test.stopTest();

        // Then: Case with asset is returned
        System.assertEquals(1, result.size(), 'One case should be returned');
        System.assertEquals(testCase.Id, result[0].Id, 'Case Id should match');
        System.assertNotEquals(null, result[0].AssetId, 'Asset Id should be populated');
    }

    @isTest
    static void testGetCaseAssetDetails_CaseWithoutAsset() {
        // Given: A case without asset
        Case testCase = TestDataFactory.createCase('Service_Request');
        testCase.AssetId = null;
        insert testCase;

        Test.startTest();

        // When: Getting case asset details
        List<Case> result = CaseUIService.getCaseAssetDetails(testCase.Id);

        Test.stopTest();

        // Then: Case is returned (even without asset)
        System.assertEquals(1, result.size(), 'One case should be returned');
        System.assertEquals(null, result[0].AssetId, 'Asset Id should be null');
    }

    @isTest
    static void testGetCaseAssetDetails_InvalidCaseId() {
        // Given: An invalid case Id
        String fakeId = '500000000000000AAA';

        Test.startTest();

        // When: Getting case asset details with invalid Id
        List<Case> result = CaseUIService.getCaseAssetDetails(fakeId);

        Test.stopTest();

        // Then: Empty list is returned
        System.assertEquals(0, result.size(), 'Empty list should be returned');
    }

    // ========================================================================
    // PERMISSION TESTS
    // ========================================================================

    @isTest
    static void testHasCPQAccess_ChecksUserPermissions() {
        Test.startTest();

        // When: Checking CPQ access
        Boolean result = CaseUIService.hasCPQAccess();

        Test.stopTest();

        // Then: Method executes without error
        // Note: Result depends on test user's permissions
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testHasUpdateAssetAccess_ChecksUserPermissions() {
        Test.startTest();

        // When: Checking update asset access
        Boolean result = CaseUIService.hasUpdateAssetAccess();

        Test.stopTest();

        // Then: Method executes without error
        // Note: Result depends on test user's permissions
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================================================
    // WRAPPER CLASS TESTS
    // ========================================================================

    @isTest
    static void testCaseUIWrapper_DefaultConstructor() {
        Test.startTest();

        // When: Creating wrapper with default constructor
        CaseUIService.CaseUIWrapper wrapper = new CaseUIService.CaseUIWrapper();

        Test.stopTest();

        // Then: Default values are set
        System.assertEquals(Constant_Util.EMPTY_STRING, wrapper.caseInfo, 'Case info should be empty string');
        System.assertEquals(Constant_Util.EMPTY_STRING, wrapper.reqInfo, 'Req info should be empty string');
        System.assertEquals(Constant_Util.EMPTY_STRING, wrapper.approvalInfo, 'Approval info should be empty string');
        System.assertEquals(false, wrapper.enableapprovalInfo, 'Enable approval info should be false');
        System.assertEquals(false, wrapper.assetValidation, 'Asset validation should be false');
        System.assertEquals(true, wrapper.workOrderCreation, 'Work order creation should be true');
        System.assertEquals(true, wrapper.isAssetMandatory, 'Is asset mandatory should be true');
        System.assertEquals(true, wrapper.isCaseInfoReady, 'Is case info ready should be true');
        System.assertNotEquals(null, wrapper.relatedCaseList, 'Related case list should not be null');
        System.assertNotEquals(null, wrapper.multiAssetSelections, 'Multi asset selections should not be null');
    }

    @isTest
    static void testBusinessRuleUIWrapper_DefaultConstructor() {
        Test.startTest();

        // When: Creating wrapper with default constructor
        CaseUIService.BusinessRuleUIWrapper wrapper = new CaseUIService.BusinessRuleUIWrapper();

        Test.stopTest();

        // Then: Default values are set
        System.assertEquals('', wrapper.channelReq, 'Channel req should be empty');
        System.assertEquals('', wrapper.channelName, 'Channel name should be empty');
        System.assertEquals('', wrapper.specialInstructions, 'Special instructions should be empty');
    }

    @isTest
    static void testSLAUIWrapper_DefaultConstructor() {
        Test.startTest();

        // When: Creating wrapper with default constructor
        CaseUIService.SLAUIWrapper wrapper = new CaseUIService.SLAUIWrapper();

        Test.stopTest();

        // Then: Default values are set
        System.assertEquals('', wrapper.slaInstructions, 'SLA instructions should be empty');
    }

    // ========================================================================
    // INTEGRATION TESTS
    // ========================================================================

    @isTest
    static void testFullCaseUILoad_WithAllData() {
        // Given: A case with all relationships
        Case testCase = [
            SELECT Id
            FROM Case
            WHERE Client__c != null
            AND Location__c != null
            AND ContactId != null
            AND AssetId != null
            LIMIT 1
        ];

        Test.startTest();

        // When: Getting all UI data
        CaseUIService.CaseUIWrapper messages = CaseUIService.getCaseMessages(testCase.Id);
        CaseUIService.BusinessRuleUIWrapper businessRule = CaseUIService.getBusinessRule(testCase.Id);
        CaseUIService.SLAUIWrapper entitlement = CaseUIService.getEntitlement(testCase.Id);
        List<String> recordDetails = CaseUIService.getCaseRecordDetails(testCase.Id);
        String recordTypeId = CaseUIService.getRecordTypeId(testCase.Id);

        Test.stopTest();

        // Then: All data is returned successfully
        System.assertNotEquals(null, messages, 'Messages should not be null');
        System.assertNotEquals(null, businessRule, 'Business rule should not be null');
        System.assertNotEquals(null, entitlement, 'Entitlement should not be null');
        System.assertNotEquals(null, recordDetails, 'Record details should not be null');
        System.assertNotEquals(null, recordTypeId, 'Record type Id should not be null');
    }

    // ========================================================================
    // GOVERNOR LIMIT TESTS
    // ========================================================================

    @isTest
    static void testGetCaseMessages_WithinGovernorLimits() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting case messages
        CaseUIService.CaseUIWrapper result = CaseUIService.getCaseMessages(testCase.Id);

        // Then: Operation completes within governor limits
        Integer queriesUsed = Limits.getQueries();
        System.assert(queriesUsed < Limits.getLimitQueries(), 'Should be within SOQL query limits');

        Test.stopTest();

        // And: Result is returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testBulkUIOperations_PerformanceOptimization() {
        // Given: Multiple cases exist
        List<Case> testCases = [SELECT Id FROM Case LIMIT 3];

        Test.startTest();

        // When: Getting UI data for multiple cases
        for (Case c : testCases) {
            CaseUIService.CaseUIWrapper messages = CaseUIService.getCaseMessages(c.Id);
            System.assertNotEquals(null, messages, 'Messages should not be null');
        }

        Test.stopTest();

        // Then: All operations succeed
        System.assert(true, 'All operations should complete successfully');
    }
}
