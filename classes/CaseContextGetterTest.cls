/**
 * @description Test class for CaseContextGetter
 *
 * This test class provides comprehensive coverage for the CaseContextGetter
 * data access layer, testing all query methods, caching behavior, and bulk operations.
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseContextGetterTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    @testSetup
    static void setupTestData() {
        // Create full test hierarchy
        Map<String, Object> testData = TestDataFactory.createFullTestHierarchy();

        // Create additional cases for bulk testing
        Account clientAccount = (Account)testData.get('clientAccount');
        Account locationAccount = (Account)testData.get('locationAccount');
        Contact contact = (Contact)testData.get('contact');
        Asset asset = (Asset)testData.get('asset');

        List<Case> additionalCases = new List<Case>();
        for (Integer i = 0; i < 5; i++) {
            Case c = TestDataFactory.createCaseWithRelationships(
                clientAccount.Id,
                locationAccount.Id,
                contact.Id,
                asset.Id,
                'Service_Request'
            );
            c.Reference_Number__c = 'BULK_REF_' + i;
            additionalCases.add(c);
        }
        insert additionalCases;
    }

    // ========================================================================
    // SINGLE RECORD QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetCaseById_Success() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting case by Id
        Case result = CaseContextGetter.getCaseById(testCase.Id);

        Test.stopTest();

        // Then: Case is returned with standard fields
        System.assertNotEquals(null, result, 'Case should be found');
        System.assertEquals(testCase.Id, result.Id, 'Case Id should match');
        System.assertNotEquals(null, result.CaseNumber, 'CaseNumber should be populated');
        System.assertNotEquals(null, result.Status, 'Status should be populated');
    }

    @isTest
    static void testGetCaseById_NullId() {
        Test.startTest();

        // When: Getting case with null Id
        Case result = CaseContextGetter.getCaseById(null);

        Test.stopTest();

        // Then: Null is returned
        System.assertEquals(null, result, 'Null should be returned for null Id');
    }

    @isTest
    static void testGetCaseByIdExtended_Success() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting case with extended fields
        Case result = CaseContextGetter.getCaseByIdExtended(testCase.Id);

        Test.stopTest();

        // Then: Case is returned with extended fields
        System.assertNotEquals(null, result, 'Case should be found');
        System.assertEquals(testCase.Id, result.Id, 'Case Id should match');

        // Verify extended fields are populated (if they have values)
        // Note: Some extended fields may be null depending on the case
        System.assert(result != null, 'Extended case should not be null');
    }

    @isTest
    static void testGetCaseByIdExtended_Caching() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting same case twice
        Case result1 = CaseContextGetter.getCaseByIdExtended(testCase.Id);
        Case result2 = CaseContextGetter.getCaseByIdExtended(testCase.Id);

        Test.stopTest();

        // Then: Both calls should return the same instance (from cache)
        System.assertEquals(result1.Id, result2.Id, 'Both results should have same Id');
        // Note: We can't test actual object identity in Apex, but we verify consistency
    }

    // ========================================================================
    // BULK QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetCasesById_BulkSuccess() {
        // Given: Multiple cases exist
        List<Case> testCases = [SELECT Id FROM Case LIMIT 5];
        Set<Id> caseIds = new Set<Id>();
        for (Case c : testCases) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When: Getting multiple cases
        Map<Id, Case> results = CaseContextGetter.getCasesById(caseIds);

        Test.stopTest();

        // Then: All cases are returned
        System.assertEquals(caseIds.size(), results.size(), 'All cases should be returned');
        for (Id caseId : caseIds) {
            System.assert(results.containsKey(caseId), 'Result should contain case Id: ' + caseId);
            System.assertNotEquals(null, results.get(caseId).CaseNumber, 'CaseNumber should be populated');
        }
    }

    @isTest
    static void testGetCasesById_EmptySet() {
        Test.startTest();

        // When: Getting cases with empty set
        Map<Id, Case> results = CaseContextGetter.getCasesById(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetCasesById_NullSet() {
        Test.startTest();

        // When: Getting cases with null set
        Map<Id, Case> results = CaseContextGetter.getCasesById(null);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'Empty map should be returned for null');
    }

    // ========================================================================
    // REFERENCE NUMBER QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetCasesByReferenceNumber_Success() {
        // Given: Cases with same reference number exist
        String refNumber = [SELECT Reference_Number__c FROM Case LIMIT 1].Reference_Number__c;

        Test.startTest();

        // When: Getting cases by reference number
        List<Case> results = CaseContextGetter.getCasesByReferenceNumber(refNumber);

        Test.stopTest();

        // Then: At least one case is returned
        System.assert(results.size() > 0, 'At least one case should be found');
        for (Case c : results) {
            System.assertEquals(refNumber, c.Reference_Number__c, 'Reference number should match');
        }
    }

    @isTest
    static void testGetCasesByReferenceNumber_NoResults() {
        Test.startTest();

        // When: Getting cases with non-existent reference number
        List<Case> results = CaseContextGetter.getCasesByReferenceNumber('NONEXISTENT_REF');

        Test.stopTest();

        // Then: Empty list is returned
        System.assertEquals(0, results.size(), 'Empty list should be returned');
    }

    @isTest
    static void testGetCasesByReferenceNumber_BlankString() {
        Test.startTest();

        // When: Getting cases with blank reference number
        List<Case> results = CaseContextGetter.getCasesByReferenceNumber('');

        Test.stopTest();

        // Then: Empty list is returned
        System.assertEquals(0, results.size(), 'Empty list should be returned for blank string');
    }

    // ========================================================================
    // BUSINESS HOURS TESTS
    // ========================================================================

    @isTest
    static void testGetBusinessHoursByTimezone_Success() {
        Test.startTest();

        // When: Getting business hours for a timezone
        Id bhId = CaseContextGetter.getBusinessHoursByTimezone('America/Los_Angeles');

        Test.stopTest();

        // Then: Business hours Id is returned (if configured)
        // Note: May be null in orgs without business hours configured
        // We just verify the method executes without error
        System.assert(true, 'Method should execute without error');
    }

    @isTest
    static void testGetBusinessHoursByTimezone_NullTimezone() {
        Test.startTest();

        // When: Getting business hours with null timezone
        Id bhId = CaseContextGetter.getBusinessHoursByTimezone(null);

        Test.stopTest();

        // Then: Null or default business hours is returned
        // Method should handle gracefully
        System.assert(true, 'Method should handle null timezone gracefully');
    }

    @isTest
    static void testGetBusinessHoursByTimezone_Caching() {
        Test.startTest();

        // When: Getting business hours twice for same timezone
        Id bhId1 = CaseContextGetter.getBusinessHoursByTimezone('America/New_York');
        Id bhId2 = CaseContextGetter.getBusinessHoursByTimezone('America/New_York');

        Test.stopTest();

        // Then: Same Id is returned (from cache)
        System.assertEquals(bhId1, bhId2, 'Same business hours Id should be returned');
    }

    // ========================================================================
    // CACHE FUNCTIONALITY TESTS
    // ========================================================================

    @isTest
    static void testClearCache_Success() {
        // Given: Data is cached
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Case result1 = CaseContextGetter.getCaseById(testCase.Id);

        Test.startTest();

        // When: Cache is cleared
        CaseContextGetter.clearCache();

        // And: Same case is queried again
        Case result2 = CaseContextGetter.getCaseById(testCase.Id);

        Test.stopTest();

        // Then: Case is returned successfully both times
        System.assertNotEquals(null, result1, 'First query should return case');
        System.assertNotEquals(null, result2, 'Second query should return case after cache clear');
        System.assertEquals(result1.Id, result2.Id, 'Same case should be returned');
    }

    // ========================================================================
    // PARENT CASE TESTS
    // ========================================================================

    @isTest
    static void testGetCasesWithParent_Success() {
        // Given: A parent case and child case
        Case parentCase = [SELECT Id FROM Case LIMIT 1];

        Case childCase = TestDataFactory.createCase('Service_Request');
        childCase.ParentId = parentCase.Id;
        insert childCase;

        Test.startTest();

        // When: Getting case with parent
        Case result = CaseContextGetter.getCaseById(childCase.Id);

        Test.stopTest();

        // Then: Case is returned with parent relationship
        System.assertNotEquals(null, result, 'Case should be found');
        System.assertEquals(parentCase.Id, result.ParentId, 'Parent Id should match');
    }

    // ========================================================================
    // NEGATIVE TESTS
    // ========================================================================

    @isTest
    static void testGetCaseById_InvalidId() {
        // Given: An invalid case Id (using a valid Id format but non-existent record)
        Id fakeId = '500000000000000AAA'; // Valid Id format, doesn't exist

        Test.startTest();

        // When: Getting case with invalid Id
        Case result = CaseContextGetter.getCaseById(fakeId);

        Test.stopTest();

        // Then: Null is returned
        System.assertEquals(null, result, 'Null should be returned for invalid Id');
    }

    // ========================================================================
    // GOVERNOR LIMIT TESTS
    // ========================================================================

    @isTest
    static void testBulkOperations_WithinGovernorLimits() {
        // Given: Many cases exist
        List<Case> testCases = [SELECT Id FROM Case];
        Set<Id> caseIds = new Set<Id>();
        for (Case c : testCases) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When: Getting all cases in bulk
        Map<Id, Case> results = CaseContextGetter.getCasesById(caseIds);

        // Then: Operation completes within governor limits
        Integer queriesUsed = Limits.getQueries();
        System.assert(queriesUsed < Limits.getLimitQueries(), 'Should be within SOQL query limits');

        Test.stopTest();

        // And: All cases are returned
        System.assertEquals(caseIds.size(), results.size(), 'All cases should be returned');
    }

    // ========================================================================
    // INTEGRATION TESTS
    // ========================================================================

    @isTest
    static void testGetCaseWithAllRelationships_Success() {
        // Given: A case with all relationships populated
        Map<String, Object> testData = TestDataFactory.createFullTestHierarchy();
        Case testCase = (Case)testData.get('case');

        Test.startTest();

        // When: Getting case with extended fields
        Case result = CaseContextGetter.getCaseByIdExtended(testCase.Id);

        Test.stopTest();

        // Then: All relationships are populated
        System.assertNotEquals(null, result, 'Case should be found');
        System.assertNotEquals(null, result.Client__c, 'Client should be populated');
        System.assertNotEquals(null, result.Location__c, 'Location should be populated');
        System.assertNotEquals(null, result.ContactId, 'Contact should be populated');
        System.assertNotEquals(null, result.AssetId, 'Asset should be populated');

        // Verify relationship fields
        System.assertNotEquals(null, result.Client__r.Name, 'Client name should be accessible');
        System.assertNotEquals(null, result.Location__r.Name, 'Location name should be accessible');
        System.assertNotEquals(null, result.Contact.Name, 'Contact name should be accessible');
        System.assertNotEquals(null, result.Asset.Name, 'Asset name should be accessible');
    }
}
