/**
 * @description Test class for CaseDataGovernorService
 *
 * This test class provides comprehensive coverage for the CaseDataGovernorService,
 * which is the central data management service for Case pages.
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseDataGovernorServiceTest {

    @testSetup
    static void setupTestData() {
        // Create full test hierarchy with all relationships
        TestDataFactoryRefactored.createFullTestHierarchy();
    }

    // ========================================================================
    // GET CASE PAGE DATA TESTS
    // ========================================================================

    @isTest
    static void testGetCasePageData_FullLoad_Success() {
        // Given: A case with all relationships
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting full page data
        CaseDataGovernorService.CasePageDataWrapper result =
            CaseDataGovernorService.getCasePageData(
                testCase.Id,
                true,  // includeRelated
                true   // includeBusinessRules
            );

        Test.stopTest();

        // Then: All data is loaded successfully
        System.assert(result.isSuccess, 'Operation should succeed');
        System.assertNotEquals(null, result.caseRecord, 'Case record should be loaded');
        System.assertEquals(testCase.Id, result.caseRecord.Id, 'Case Id should match');

        // Verify related records are loaded
        System.assertNotEquals(null, result.clientAccount, 'Client account should be loaded');
        System.assertNotEquals(null, result.locationAccount, 'Location account should be loaded');
        System.assertNotEquals(null, result.caseContact, 'Contact should be loaded');
        System.assertNotEquals(null, result.caseAsset, 'Asset should be loaded');

        // Verify UI data is loaded
        System.assertNotEquals(null, result.caseUI, 'Case UI wrapper should be loaded');

        // Verify user context is loaded
        System.assertNotEquals(null, result.userContext, 'User context should be loaded');
        System.assertNotEquals(null, result.userContext.userId, 'User Id should be set');

        // Verify metadata
        System.assertNotEquals(null, result.loadedAt, 'LoadedAt timestamp should be set');
        System.assertNotEquals(null, result.cacheKey, 'Cache key should be generated');
        System.assertNotEquals(null, result.pageConfig, 'Page config should be initialized');
    }

    @isTest
    static void testGetCasePageData_MinimalLoad_Success() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting page data without related records and business rules
        CaseDataGovernorService.CasePageDataWrapper result =
            CaseDataGovernorService.getCasePageData(
                testCase.Id,
                false,  // includeRelated
                false   // includeBusinessRules
            );

        Test.stopTest();

        // Then: Only basic data is loaded
        System.assert(result.isSuccess, 'Operation should succeed');
        System.assertNotEquals(null, result.caseRecord, 'Case record should be loaded');

        // Related records should not be loaded
        System.assertEquals(null, result.clientAccount, 'Client account should not be loaded');
        System.assertEquals(null, result.locationAccount, 'Location account should not be loaded');
        System.assertEquals(null, result.caseContact, 'Contact should not be loaded');
        System.assertEquals(null, result.caseAsset, 'Asset should not be loaded');

        // Business rules should not be loaded
        System.assertEquals(null, result.businessRules, 'Business rules should not be loaded');
        System.assertEquals(null, result.slaInfo, 'SLA info should not be loaded');
    }

    @isTest
    static void testGetCasePageData_NullCaseId() {
        Test.startTest();

        // When: Getting page data with null case Id
        CaseDataGovernorService.CasePageDataWrapper result =
            CaseDataGovernorService.getCasePageData(null, true, true);

        Test.stopTest();

        // Then: Error is returned
        System.assert(!result.isSuccess, 'Operation should fail');
        System.assertNotEquals(null, result.errorMessage, 'Error message should be set');
        System.assert(result.errorMessage.contains('Case ID is required'), 'Error should mention Case ID');
    }

    @isTest
    static void testGetCasePageData_InvalidCaseId() {
        // Given: An invalid case Id
        Id fakeId = '500000000000000AAA';

        Test.startTest();

        // When: Getting page data with invalid case Id
        CaseDataGovernorService.CasePageDataWrapper result =
            CaseDataGovernorService.getCasePageData(fakeId, true, true);

        Test.stopTest();

        // Then: Error is handled gracefully
        System.assert(!result.isSuccess, 'Operation should fail');
        System.assertNotEquals(null, result.errorMessage, 'Error message should be set');
    }

    // ========================================================================
    // REFRESH PAGE SECTION TESTS
    // ========================================================================

    @isTest
    static void testRefreshPageSection_Case_Success() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Refreshing case section
        Map<String, Object> result =
            CaseDataGovernorService.refreshPageSection(testCase.Id, 'case');

        Test.stopTest();

        // Then: Case data is returned
        System.assert((Boolean)result.get('isSuccess'), 'Operation should succeed');
        System.assertNotEquals(null, result.get('caseRecord'), 'Case record should be returned');
        System.assertNotEquals(null, result.get('refreshedAt'), 'Refresh timestamp should be set');
    }

    @isTest
    static void testRefreshPageSection_Contact_Success() {
        // Given: A case with contact
        Case testCase = [SELECT Id, ContactId FROM Case WHERE ContactId != null LIMIT 1];

        Test.startTest();

        // When: Refreshing contact section
        Map<String, Object> result =
            CaseDataGovernorService.refreshPageSection(testCase.Id, 'contact');

        Test.stopTest();

        // Then: Contact data is returned
        System.assert((Boolean)result.get('isSuccess'), 'Operation should succeed');
        System.assertNotEquals(null, result.get('caseContact'), 'Contact should be returned');
    }

    @isTest
    static void testRefreshPageSection_Asset_Success() {
        // Given: A case with asset
        Case testCase = [SELECT Id, AssetId FROM Case WHERE AssetId != null LIMIT 1];

        Test.startTest();

        // When: Refreshing asset section
        Map<String, Object> result =
            CaseDataGovernorService.refreshPageSection(testCase.Id, 'asset');

        Test.stopTest();

        // Then: Asset data is returned
        System.assert((Boolean)result.get('isSuccess'), 'Operation should succeed');
        System.assertNotEquals(null, result.get('caseAsset'), 'Asset should be returned');
    }

    @isTest
    static void testRefreshPageSection_BusinessRules_Success() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Refreshing business rules section
        Map<String, Object> result =
            CaseDataGovernorService.refreshPageSection(testCase.Id, 'businessrules');

        Test.stopTest();

        // Then: Business rules data is returned
        System.assert((Boolean)result.get('isSuccess'), 'Operation should succeed');
        System.assertNotEquals(null, result.get('businessRules'), 'Business rules should be returned');
    }

    @isTest
    static void testRefreshPageSection_UI_Success() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Refreshing UI section
        Map<String, Object> result =
            CaseDataGovernorService.refreshPageSection(testCase.Id, 'ui');

        Test.stopTest();

        // Then: UI data is returned
        System.assert((Boolean)result.get('isSuccess'), 'Operation should succeed');
        System.assertNotEquals(null, result.get('caseUI'), 'Case UI should be returned');
    }

    @isTest
    static void testRefreshPageSection_UnknownSection() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Refreshing unknown section
        Map<String, Object> result =
            CaseDataGovernorService.refreshPageSection(testCase.Id, 'unknownsection');

        Test.stopTest();

        // Then: Error is returned
        System.assertNotEquals(null, result.get('error'), 'Error should be set');
        System.assert(
            ((String)result.get('error')).contains('Unknown section'),
            'Error should mention unknown section'
        );
    }

    // ========================================================================
    // USER CONTEXT TESTS
    // ========================================================================

    @isTest
    static void testUserContext_LoadedCorrectly() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting page data
        CaseDataGovernorService.CasePageDataWrapper result =
            CaseDataGovernorService.getCasePageData(testCase.Id, false, false);

        Test.stopTest();

        // Then: User context is populated
        System.assertNotEquals(null, result.userContext, 'User context should be loaded');
        System.assertEquals(UserInfo.getUserId(), result.userContext.userId, 'User Id should match');
        System.assertEquals(UserInfo.getName(), result.userContext.userName, 'User name should match');
        System.assertEquals(UserInfo.getUserEmail(), result.userContext.userEmail, 'User email should match');
        System.assertNotEquals(null, result.userContext.timeZone, 'Timezone should be set');
    }

    // ========================================================================
    // PAGE CONFIG TESTS
    // ========================================================================

    @isTest
    static void testPageConfig_LoadedCorrectly() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting page data
        CaseDataGovernorService.CasePageDataWrapper result =
            CaseDataGovernorService.getCasePageData(testCase.Id, false, false);

        Test.stopTest();

        // Then: Page config is populated
        System.assertNotEquals(null, result.pageConfig, 'Page config should be initialized');
        System.assert(result.pageConfig.size() > 0, 'Page config should contain data');
        System.assertNotEquals(null, result.pageConfig.get('version'), 'Version should be set');
        System.assertNotEquals(null, result.pageConfig.get('lastModified'), 'Last modified should be set');
    }

    // ========================================================================
    // RELATED CASES TESTS
    // ========================================================================

    @isTest
    static void testRelatedCases_LoadedByReferenceNumber() {
        // Given: Cases with same reference number
        String refNumber = 'TEST_REF_' + System.now().getTime();

        List<Case> relatedCases = TestDataFactoryRefactored.createCases(3, 'Service_Request');
        for (Case c : relatedCases) {
            c.Reference_Number__c = refNumber;
        }
        insert relatedCases;

        Test.startTest();

        // When: Getting page data for one of the cases
        CaseDataGovernorService.CasePageDataWrapper result =
            CaseDataGovernorService.getCasePageData(
                relatedCases[0].Id,
                true,
                false
            );

        Test.stopTest();

        // Then: Related cases are loaded
        System.assertNotEquals(null, result.relatedCases, 'Related cases should be loaded');
        System.assertEquals(3, result.relatedCases.size(), 'All related cases should be found');
    }

    // ========================================================================
    // INTEGRATION TESTS
    // ========================================================================

    @isTest
    static void testFullPageLoad_PerformanceWithinLimits() {
        // Given: Multiple cases exist
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting full page data
        CaseDataGovernorService.CasePageDataWrapper result =
            CaseDataGovernorService.getCasePageData(testCase.Id, true, true);

        // Then: Operation completes within governor limits
        Integer queriesUsed = Limits.getQueries();
        System.assert(queriesUsed < Limits.getLimitQueries(), 'Should be within SOQL limits');
        System.assert(result.isSuccess, 'Operation should succeed');

        Test.stopTest();
    }

    @isTest
    static void testMultipleRefreshes_PerformanceOptimization() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Refreshing multiple sections
        Map<String, Object> result1 = CaseDataGovernorService.refreshPageSection(testCase.Id, 'case');
        Map<String, Object> result2 = CaseDataGovernorService.refreshPageSection(testCase.Id, 'contact');
        Map<String, Object> result3 = CaseDataGovernorService.refreshPageSection(testCase.Id, 'asset');

        Test.stopTest();

        // Then: All operations succeed
        System.assert((Boolean)result1.get('isSuccess'), 'Case refresh should succeed');
        System.assert((Boolean)result2.get('isSuccess'), 'Contact refresh should succeed');
        System.assert((Boolean)result3.get('isSuccess'), 'Asset refresh should succeed');
    }
}
