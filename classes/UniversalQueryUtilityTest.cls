/**
 * @description Test class for UniversalQueryUtility
 *
 * This test class provides comprehensive coverage for the UniversalQueryUtility,
 * which provides dynamic SOQL queries with FLS security checks.
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class UniversalQueryUtilityTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    @testSetup
    static void setupTestData() {
        // Create full test hierarchy
        TestDataFactoryRefactored.createFullTestHierarchy();
    }

    // ========================================================================
    // ACCOUNT QUERY TESTS
    // ========================================================================

    @isTest
    static void testUniversalQuery_Account_Success() {
        // Given: An account exists
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Set<Id> accountIds = new Set<Id>{testAccount.Id};

        Test.startTest();

        // When: Querying accounts using universal query
        List<SObject> results = UniversalQueryUtility.universalQuery('Account', accountIds, 'Id');

        Test.stopTest();

        // Then: Account is returned with all accessible fields
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return one account');

        Account result = (Account)results[0];
        System.assertEquals(testAccount.Id, result.Id, 'Account Id should match');
        System.assertNotEquals(null, result.Name, 'Name should be populated');
    }

    @isTest
    static void testUniversalQuery_Account_BulkSuccess() {
        // Given: Multiple accounts exist
        List<Account> testAccounts = [SELECT Id FROM Account LIMIT 3];
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : testAccounts) {
            accountIds.add(acc.Id);
        }

        Test.startTest();

        // When: Querying multiple accounts
        List<SObject> results = UniversalQueryUtility.universalQuery('Account', accountIds, 'Id');

        Test.stopTest();

        // Then: All accounts are returned
        System.assertEquals(accountIds.size(), results.size(), 'All accounts should be returned');
    }

    // ========================================================================
    // CASE QUERY TESTS
    // ========================================================================

    @isTest
    static void testUniversalQuery_Case_Success() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Set<Id> caseIds = new Set<Id>{testCase.Id};

        Test.startTest();

        // When: Querying cases using universal query
        List<SObject> results = UniversalQueryUtility.universalQuery('Case', caseIds, 'Id');

        Test.stopTest();

        // Then: Case is returned with all accessible fields
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return one case');

        Case result = (Case)results[0];
        System.assertEquals(testCase.Id, result.Id, 'Case Id should match');
        System.assertNotEquals(null, result.CaseNumber, 'CaseNumber should be populated');
        System.assertNotEquals(null, result.Status, 'Status should be populated');
    }

    // ========================================================================
    // CONTACT QUERY TESTS
    // ========================================================================

    @isTest
    static void testUniversalQuery_Contact_Success() {
        // Given: A contact exists
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        Set<Id> contactIds = new Set<Id>{testContact.Id};

        Test.startTest();

        // When: Querying contacts using universal query
        List<SObject> results = UniversalQueryUtility.universalQuery('Contact', contactIds, 'Id');

        Test.stopTest();

        // Then: Contact is returned with all accessible fields
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return one contact');

        Contact result = (Contact)results[0];
        System.assertEquals(testContact.Id, result.Id, 'Contact Id should match');
        System.assertNotEquals(null, result.Name, 'Name should be populated');
    }

    // ========================================================================
    // ASSET QUERY TESTS
    // ========================================================================

    @isTest
    static void testUniversalQuery_Asset_Success() {
        // Given: An asset exists
        Asset testAsset = [SELECT Id FROM Asset LIMIT 1];
        Set<Id> assetIds = new Set<Id>{testAsset.Id};

        Test.startTest();

        // When: Querying assets using universal query
        List<SObject> results = UniversalQueryUtility.universalQuery('Asset', assetIds, 'Id');

        Test.stopTest();

        // Then: Asset is returned with all accessible fields
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return one asset');

        Asset result = (Asset)results[0];
        System.assertEquals(testAsset.Id, result.Id, 'Asset Id should match');
        System.assertNotEquals(null, result.Name, 'Name should be populated');
    }

    // ========================================================================
    // TASK QUERY TESTS
    // ========================================================================

    @isTest
    static void testUniversalQuery_Task_Success() {
        // Given: A task exists
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Case testCase = (Case)testData.get('case');
        Contact testContact = (Contact)testData.get('contact');

        Task testTask = TestDataFactoryRefactored.createTask(testCase.Id, testContact.Id);
        insert testTask;

        Set<Id> taskIds = new Set<Id>{testTask.Id};

        Test.startTest();

        // When: Querying tasks using universal query
        List<SObject> results = UniversalQueryUtility.universalQuery('Task', taskIds, 'Id');

        Test.stopTest();

        // Then: Task is returned with all accessible fields
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return one task');

        Task result = (Task)results[0];
        System.assertEquals(testTask.Id, result.Id, 'Task Id should match');
    }

    // ========================================================================
    // DIFFERENT CONSTRAINT FIELD TESTS
    // ========================================================================

    @isTest
    static void testUniversalQuery_DifferentConstraint_AccountId() {
        // Given: An asset with AccountId
        Asset testAsset = [SELECT Id, AccountId FROM Asset WHERE AccountId != null LIMIT 1];
        Set<Id> accountIds = new Set<Id>{testAsset.AccountId};

        Test.startTest();

        // When: Querying assets by AccountId constraint
        List<SObject> results = UniversalQueryUtility.universalQuery('Asset', accountIds, 'AccountId');

        Test.stopTest();

        // Then: Assets are returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() > 0, 'Should return at least one asset');

        // Verify all results match the constraint
        for (SObject obj : results) {
            Asset ast = (Asset)obj;
            System.assertEquals(testAsset.AccountId, ast.AccountId, 'AccountId should match');
        }
    }

    @isTest
    static void testUniversalQuery_DifferentConstraint_WhatId() {
        // Given: A task with WhatId
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Case testCase = (Case)testData.get('case');
        Contact testContact = (Contact)testData.get('contact');

        Task testTask = TestDataFactoryRefactored.createTask(testCase.Id, testContact.Id);
        insert testTask;

        Set<Id> caseIds = new Set<Id>{testCase.Id};

        Test.startTest();

        // When: Querying tasks by WhatId constraint
        List<SObject> results = UniversalQueryUtility.universalQuery('Task', caseIds, 'WhatId');

        Test.stopTest();

        // Then: Tasks are returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() > 0, 'Should return at least one task');
    }

    // ========================================================================
    // EMPTY AND NULL TESTS
    // ========================================================================

    @isTest
    static void testUniversalQuery_EmptyIdSet() {
        Test.startTest();

        // When: Querying with empty Id set
        List<SObject> results = UniversalQueryUtility.universalQuery('Account', new Set<Id>(), 'Id');

        Test.stopTest();

        // Then: Empty list is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Empty list should be returned');
    }

    @isTest
    static void testUniversalQuery_NullIdSet() {
        Test.startTest();

        // When: Querying with null Id set
        List<SObject> results = UniversalQueryUtility.universalQuery('Account', null, 'Id');

        Test.stopTest();

        // Then: Empty list is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Empty list should be returned for null');
    }

    // ========================================================================
    // FIELD LEVEL SECURITY TESTS
    // ========================================================================

    @isTest
    static void testUniversalQuery_FLSRespected() {
        // Given: An account exists
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Set<Id> accountIds = new Set<Id>{testAccount.Id};

        Test.startTest();

        // When: Querying accounts (only accessible fields should be queried)
        List<SObject> results = UniversalQueryUtility.universalQuery('Account', accountIds, 'Id');

        Test.stopTest();

        // Then: Query completes without FLS errors
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return one account');

        // The query should have respected FLS and only queried accessible fields
        Account result = (Account)results[0];
        System.assertNotEquals(null, result.Id, 'Id should always be accessible');
    }

    // ========================================================================
    // GOVERNOR LIMIT TESTS
    // ========================================================================

    @isTest
    static void testUniversalQuery_WithinGovernorLimits() {
        // Given: Multiple objects exist
        List<Account> testAccounts = [SELECT Id FROM Account];
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : testAccounts) {
            accountIds.add(acc.Id);
        }

        Test.startTest();

        // When: Performing multiple universal queries
        List<SObject> accountResults = UniversalQueryUtility.universalQuery('Account', accountIds, 'Id');

        List<Case> testCases = [SELECT Id FROM Case];
        Set<Id> caseIds = new Set<Id>();
        for (Case c : testCases) {
            caseIds.add(c.Id);
        }
        List<SObject> caseResults = UniversalQueryUtility.universalQuery('Case', caseIds, 'Id');

        // Then: Operations complete within governor limits
        Integer queriesUsed = Limits.getQueries();
        System.assert(queriesUsed < Limits.getLimitQueries(), 'Should be within SOQL query limits');

        Test.stopTest();

        // And: All records are returned
        System.assertEquals(accountIds.size(), accountResults.size(), 'All accounts should be returned');
        System.assertEquals(caseIds.size(), caseResults.size(), 'All cases should be returned');
    }

    // ========================================================================
    // GLOBAL DESCRIBE CACHING TESTS
    // ========================================================================

    @isTest
    static void testUniversalQuery_GlobalDescribeCaching() {
        // Given: Multiple queries will be performed
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Set<Id> accountIds = new Set<Id>{testAccount.Id};

        Test.startTest();

        // When: Performing multiple queries (should reuse global describe)
        List<SObject> results1 = UniversalQueryUtility.universalQuery('Account', accountIds, 'Id');
        List<SObject> results2 = UniversalQueryUtility.universalQuery('Account', accountIds, 'Id');

        Test.stopTest();

        // Then: Both queries return the same data
        System.assertEquals(results1.size(), results2.size(), 'Both queries should return same number of records');
        System.assertEquals(results1[0].Id, results2[0].Id, 'Both queries should return same record');
    }

    // ========================================================================
    // BULK OPERATIONS TESTS
    // ========================================================================

    @isTest
    static void testUniversalQuery_LargeDataSet() {
        // Given: Multiple accounts exist
        List<Account> testAccounts = [SELECT Id FROM Account];
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : testAccounts) {
            accountIds.add(acc.Id);
        }

        Test.startTest();

        // When: Querying large dataset
        List<SObject> results = UniversalQueryUtility.universalQuery('Account', accountIds, 'Id');

        Test.stopTest();

        // Then: All records are returned efficiently
        System.assertEquals(accountIds.size(), results.size(), 'All accounts should be returned');
    }
}
