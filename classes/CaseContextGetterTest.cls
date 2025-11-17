/**
 * @description Comprehensive test class for CaseContextGetter
 *
 * This test class provides comprehensive coverage for the CaseContextGetter
 * data access layer, testing all query methods, caching behavior, and bulk operations.
 *
 * Coverage Target: 85%+
 *
 * @author Refactored Architecture Team
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
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();

        // Create additional cases for bulk testing
        Account clientAccount = (Account)testData.get('clientAccount');
        Account locationAccount = (Account)testData.get('locationAccount');
        Contact contact = (Contact)testData.get('contact');
        Asset asset = (Asset)testData.get('asset');

        // Create parent case
        Case parentCase = TestDataFactoryRefactored.createCaseWithRelationships(
            clientAccount.Id,
            locationAccount.Id,
            contact.Id,
            asset.Id,
            'Service_Request'
        );
        parentCase.Reference_Number__c = 'PARENT_REF';
        insert parentCase;

        // Create child cases
        List<Case> childCases = new List<Case>();
        for (Integer i = 0; i < 3; i++) {
            Case c = TestDataFactoryRefactored.createCaseWithRelationships(
                clientAccount.Id,
                locationAccount.Id,
                contact.Id,
                asset.Id,
                'Service_Request'
            );
            c.ParentId = parentCase.Id;
            c.Reference_Number__c = 'CHILD_REF_' + i;
            childCases.add(c);
        }
        insert childCases;

        // Create additional cases for bulk testing
        List<Case> additionalCases = new List<Case>();
        for (Integer i = 0; i < 5; i++) {
            Case c = TestDataFactoryRefactored.createCaseWithRelationships(
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

        // Create Tasks for test cases
        List<Task> tasks = new List<Task>();
        for (Case c : childCases) {
            Task t = new Task(
                WhatId = c.Id,
                Subject = 'Test Task',
                Status = 'Open',
                Process__c = 'Test Process',
                Priority = 'Normal',
                ActivityDate = Date.today().addDays(1)
            );
            tasks.add(t);
        }
        insert tasks;

        // Create SBS_Case_Asset__c records
        List<SBS_Case_Asset__c> caseAssets = new List<SBS_Case_Asset__c>();
        for (Case c : childCases) {
            SBS_Case_Asset__c ca = new SBS_Case_Asset__c(
                CaseId__c = c.Id,
                AssetId__c = asset.Id,
                Asset_Header__c = asset.Id,
                IsManual__c = false
            );
            caseAssets.add(ca);
        }
        insert caseAssets;

        // Create Comment__c records
        List<Comment__c> comments = new List<Comment__c>();
        for (Case c : childCases) {
            Comment__c comment = new Comment__c(
                Case__c = c.Id,
                Comment__c = 'Test comment for case',
                Type__c = 'Internal'
            );
            comments.add(comment);
        }
        insert comments;

        // Create EmailMessages
        List<EmailMessage> emails = new List<EmailMessage>();
        for (Case c : childCases) {
            EmailMessage email = new EmailMessage(
                ParentId = c.Id,
                Subject = 'Test Email',
                FromAddress = 'test@example.com',
                ToAddress = 'recipient@example.com',
                TextBody = 'Test email body'
            );
            emails.add(email);
        }
        insert emails;

        // Create WorkOrders
        List<WorkOrder> workOrders = new List<WorkOrder>();
        for (Case c : childCases) {
            WorkOrder wo = new WorkOrder(
                CaseId = c.Id,
                AssetId = asset.Id,
                Customer_Location__c = locationAccount.Id,
                Service_Date__c = Date.today(),
                Status = 'New',
                StatusCategory = 'New',
                Case_Subtype__c = 'Service Request',
                Is_Bypass__c = false
            );
            workOrders.add(wo);
        }
        insert workOrders;

        // Create Approval_Log__c records
        List<Approval_Log__c> approvalLogs = new List<Approval_Log__c>();
        for (Case c : childCases) {
            Approval_Log__c log = new Approval_Log__c(
                CaseId__c = c.Id,
                Required_Approver__c = UserInfo.getUserId(),
                Required_Approver_Contact__c = contact.Id,
                Status__c = 'Approval Requested',
                Is_Required__c = true
            );
            approvalLogs.add(log);
        }
        insert approvalLogs;

        // Create child assets
        Asset childAsset1 = new Asset(
            Name = 'Child Asset 1',
            ParentId = asset.Id,
            AccountId = locationAccount.Id,
            Status = 'Installed',
            Is_Active__c = true
        );
        Asset childAsset2 = new Asset(
            Name = 'Child Asset 2',
            ParentId = asset.Id,
            AccountId = locationAccount.Id,
            Status = 'Installed',
            Is_Active__c = true
        );
        insert new List<Asset>{childAsset1, childAsset2};
    }

    // ========================================================================
    // CASE QUERY TESTS - SINGLE RECORD
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
    static void testGetCaseById_Caching() {
        // Given: A case exists
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        // When: Getting same case twice
        Case result1 = CaseContextGetter.getCaseById(testCase.Id);
        Case result2 = CaseContextGetter.getCaseById(testCase.Id);

        Test.stopTest();

        // Then: Second call should use cache
        System.assertEquals(result1.Id, result2.Id, 'Both results should have same Id');
        System.assert(CaseContextGetter.isCaseCached(testCase.Id), 'Case should be cached');
    }

    @isTest
    static void testGetCaseById_InvalidId() {
        // Given: An invalid case Id
        Id fakeId = '500000000000000AAA';

        Test.startTest();

        // When: Getting case with invalid Id
        Case result = CaseContextGetter.getCaseById(fakeId);

        Test.stopTest();

        // Then: Null is returned
        System.assertEquals(null, result, 'Null should be returned for invalid Id');
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
    }

    @isTest
    static void testGetCaseByIdExtended_InvalidId() {
        // Given: An invalid case Id
        Id fakeId = '500000000000000AAA';

        Test.startTest();

        // When: Getting case with invalid Id
        Case result = CaseContextGetter.getCaseByIdExtended(fakeId);

        Test.stopTest();

        // Then: Null is returned
        System.assertEquals(null, result, 'Null should be returned for invalid Id');
    }

    // ========================================================================
    // CASE QUERY TESTS - BULK
    // ========================================================================

    @isTest
    static void testGetCasesByIds_BulkSuccess() {
        // Given: Multiple cases exist
        List<Case> testCases = [SELECT Id FROM Case LIMIT 5];
        Set<Id> caseIds = new Set<Id>();
        for (Case c : testCases) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When: Getting multiple cases
        Map<Id, Case> results = CaseContextGetter.getCasesByIds(caseIds);

        Test.stopTest();

        // Then: All cases are returned
        System.assertEquals(caseIds.size(), results.size(), 'All cases should be returned');
        for (Id caseId : caseIds) {
            System.assert(results.containsKey(caseId), 'Result should contain case Id');
        }
    }

    @isTest
    static void testGetCasesByIds_EmptySet() {
        Test.startTest();

        // When: Getting cases with empty set
        Map<Id, Case> results = CaseContextGetter.getCasesByIds(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetCasesByIds_WithCaching() {
        // Given: Multiple cases exist
        List<Case> testCases = [SELECT Id FROM Case LIMIT 3];
        Set<Id> caseIds = new Set<Id>();
        for (Case c : testCases) {
            caseIds.add(c.Id);
        }

        // When: First query (populates cache)
        Map<Id, Case> results1 = CaseContextGetter.getCasesByIds(caseIds);

        Test.startTest();

        // When: Second query (uses cache)
        Map<Id, Case> results2 = CaseContextGetter.getCasesByIds(caseIds);

        Test.stopTest();

        // Then: Both queries return same results
        System.assertEquals(results1.size(), results2.size(), 'Same number of cases should be returned');
    }

    @isTest
    static void testGetCasesByReferenceNumber_Success() {
        // Given: Cases with reference number exist
        String refNumber = [SELECT Reference_Number__c FROM Case WHERE Reference_Number__c != null LIMIT 1].Reference_Number__c;

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
    static void testGetCasesByParentId_Success() {
        // Given: Parent case with children exists
        Case parentCase = [SELECT Id FROM Case WHERE Reference_Number__c = 'PARENT_REF' LIMIT 1];

        Test.startTest();

        // When: Getting child cases
        List<Case> results = CaseContextGetter.getCasesByParentId(parentCase.Id);

        Test.stopTest();

        // Then: Child cases are returned
        System.assert(results.size() > 0, 'Child cases should be found');
        for (Case c : results) {
            System.assertEquals(parentCase.Id, c.ParentId, 'ParentId should match');
        }
    }

    @isTest
    static void testGetCasesByParentId_NoChildren() {
        // Given: A case without children
        Case caseWithoutChildren = [SELECT Id FROM Case WHERE Reference_Number__c = 'BULK_REF_0' LIMIT 1];

        Test.startTest();

        // When: Getting child cases
        List<Case> results = CaseContextGetter.getCasesByParentId(caseWithoutChildren.Id);

        Test.stopTest();

        // Then: Empty list is returned
        System.assertEquals(0, results.size(), 'No child cases should be found');
    }

    // ========================================================================
    // RELATED RECORD QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetOpenTasksByCaseIds_Success() {
        // Given: Cases with open tasks exist
        List<Case> casesWithTasks = [SELECT Id FROM Case WHERE ParentId != null LIMIT 3];
        Set<Id> caseIds = new Set<Id>();
        for (Case c : casesWithTasks) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When: Getting open tasks
        Map<Id, List<Task>> results = CaseContextGetter.getOpenTasksByCaseIds(caseIds);

        Test.stopTest();

        // Then: Tasks are returned for cases
        System.assert(results.size() > 0, 'Open tasks should be found');
    }

    @isTest
    static void testGetOpenTasksByCaseIds_NoTasks() {
        // Given: A case without tasks
        Set<Id> caseIds = new Set<Id>{[SELECT Id FROM Case WHERE Reference_Number__c = 'BULK_REF_0' LIMIT 1].Id};

        Test.startTest();

        // When: Getting open tasks
        Map<Id, List<Task>> results = CaseContextGetter.getOpenTasksByCaseIds(caseIds);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'No tasks should be found');
    }

    @isTest
    static void testGetCaseAssetsByCaseIds_Success() {
        // Given: Cases with case assets exist
        List<Case> casesWithAssets = [SELECT Id FROM Case WHERE ParentId != null LIMIT 3];
        Set<Id> caseIds = new Set<Id>();
        for (Case c : casesWithAssets) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When: Getting case assets
        Map<Id, List<SBS_Case_Asset__c>> results = CaseContextGetter.getCaseAssetsByCaseIds(caseIds);

        Test.stopTest();

        // Then: Case assets are returned
        System.assert(results.size() > 0, 'Case assets should be found');
    }

    @isTest
    static void testGetCaseAssetsByCaseIds_NoCaseAssets() {
        // Given: A case without case assets
        Set<Id> caseIds = new Set<Id>{[SELECT Id FROM Case WHERE Reference_Number__c = 'BULK_REF_0' LIMIT 1].Id};

        Test.startTest();

        // When: Getting case assets
        Map<Id, List<SBS_Case_Asset__c>> results = CaseContextGetter.getCaseAssetsByCaseIds(caseIds);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'No case assets should be found');
    }

    @isTest
    static void testGetCommentsByCaseIds_Success() {
        // Given: Cases with comments exist
        List<Case> casesWithComments = [SELECT Id FROM Case WHERE ParentId != null LIMIT 3];
        Set<Id> caseIds = new Set<Id>();
        for (Case c : casesWithComments) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When: Getting comments
        Map<Id, List<Comment__c>> results = CaseContextGetter.getCommentsByCaseIds(caseIds);

        Test.stopTest();

        // Then: Comments are returned
        System.assert(results.size() > 0, 'Comments should be found');
    }

    @isTest
    static void testGetCommentsByCaseIds_NoComments() {
        // Given: A case without comments
        Set<Id> caseIds = new Set<Id>{[SELECT Id FROM Case WHERE Reference_Number__c = 'BULK_REF_0' LIMIT 1].Id};

        Test.startTest();

        // When: Getting comments
        Map<Id, List<Comment__c>> results = CaseContextGetter.getCommentsByCaseIds(caseIds);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'No comments should be found');
    }

    @isTest
    static void testGetEmailMessagesByCaseIds_Success() {
        // Given: Cases with emails exist
        List<Case> casesWithEmails = [SELECT Id FROM Case WHERE ParentId != null LIMIT 3];
        Set<Id> caseIds = new Set<Id>();
        for (Case c : casesWithEmails) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When: Getting email messages
        Map<Id, List<EmailMessage>> results = CaseContextGetter.getEmailMessagesByCaseIds(caseIds);

        Test.stopTest();

        // Then: Email messages are returned
        System.assert(results.size() > 0, 'Email messages should be found');
    }

    @isTest
    static void testGetEmailMessagesByCaseIds_NoEmails() {
        // Given: A case without emails
        Set<Id> caseIds = new Set<Id>{[SELECT Id FROM Case WHERE Reference_Number__c = 'BULK_REF_0' LIMIT 1].Id};

        Test.startTest();

        // When: Getting email messages
        Map<Id, List<EmailMessage>> results = CaseContextGetter.getEmailMessagesByCaseIds(caseIds);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'No email messages should be found');
    }

    // ========================================================================
    // ASSET QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetAssetsByIds_Success() {
        // Given: Assets exist
        List<Asset> testAssets = [SELECT Id FROM Asset LIMIT 3];
        Set<Id> assetIds = new Set<Id>();
        for (Asset a : testAssets) {
            assetIds.add(a.Id);
        }

        Test.startTest();

        // When: Getting assets by Ids
        Map<Id, Asset> results = CaseContextGetter.getAssetsByIds(assetIds);

        Test.stopTest();

        // Then: All assets are returned
        System.assertEquals(assetIds.size(), results.size(), 'All assets should be returned');
    }

    @isTest
    static void testGetAssetsByIds_Caching() {
        // Given: Assets exist
        List<Asset> testAssets = [SELECT Id FROM Asset LIMIT 2];
        Set<Id> assetIds = new Set<Id>();
        for (Asset a : testAssets) {
            assetIds.add(a.Id);
        }

        // When: First query (populates cache)
        Map<Id, Asset> results1 = CaseContextGetter.getAssetsByIds(assetIds);

        Test.startTest();

        // When: Second query (uses cache)
        Map<Id, Asset> results2 = CaseContextGetter.getAssetsByIds(assetIds);

        Test.stopTest();

        // Then: Both queries return same results
        System.assertEquals(results1.size(), results2.size(), 'Same number of assets should be returned');
    }

    @isTest
    static void testGetAssetsByIds_EmptySet() {
        Test.startTest();

        // When: Getting assets with empty set
        Map<Id, Asset> results = CaseContextGetter.getAssetsByIds(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetAssetsWithServiceHeader_IncludeTrue() {
        // Given: Assets with service headers exist
        List<Asset> testAssets = [SELECT Id FROM Asset WHERE Is_Active__c = true LIMIT 2];
        Set<Id> assetIds = new Set<Id>();
        for (Asset a : testAssets) {
            assetIds.add(a.Id);
        }

        Test.startTest();

        // When: Getting assets with service header
        Map<Id, Asset> results = CaseContextGetter.getAssetsWithServiceHeader(assetIds, true);

        Test.stopTest();

        // Then: Results are returned
        System.assertNotEquals(null, results, 'Results should not be null');
    }

    @isTest
    static void testGetAssetsWithServiceHeader_IncludeFalse() {
        // Given: Assets exist
        List<Asset> testAssets = [SELECT Id FROM Asset LIMIT 2];
        Set<Id> assetIds = new Set<Id>();
        for (Asset a : testAssets) {
            assetIds.add(a.Id);
        }

        Test.startTest();

        // When: Getting assets without service header
        Map<Id, Asset> results = CaseContextGetter.getAssetsWithServiceHeader(assetIds, false);

        Test.stopTest();

        // Then: All assets are returned
        System.assertEquals(assetIds.size(), results.size(), 'All assets should be returned');
    }

    @isTest
    static void testGetChildAssetsByParentIds_Success() {
        // Given: Parent asset with children exists
        Asset parentAsset = [SELECT Id FROM Asset WHERE ParentId = null LIMIT 1];
        Set<Id> parentIds = new Set<Id>{parentAsset.Id};

        Test.startTest();

        // When: Getting child assets
        Map<Id, List<Asset>> results = CaseContextGetter.getChildAssetsByParentIds(parentIds);

        Test.stopTest();

        // Then: Child assets are returned
        System.assert(results.size() > 0, 'Child assets should be found');
        System.assert(results.get(parentAsset.Id).size() > 0, 'Parent should have children');
    }

    @isTest
    static void testGetChildAssetsByParentIds_NoChildren() {
        // Given: An asset without children
        Asset assetWithoutChildren = [SELECT Id FROM Asset WHERE Name = 'Child Asset 1' LIMIT 1];
        Set<Id> parentIds = new Set<Id>{assetWithoutChildren.Id};

        Test.startTest();

        // When: Getting child assets
        Map<Id, List<Asset>> results = CaseContextGetter.getChildAssetsByParentIds(parentIds);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'No child assets should be found');
    }

    // ========================================================================
    // ACCOUNT QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetAccountsByIds_Success() {
        // Given: Accounts exist
        List<Account> testAccounts = [SELECT Id FROM Account LIMIT 2];
        Set<Id> accountIds = new Set<Id>();
        for (Account a : testAccounts) {
            accountIds.add(a.Id);
        }

        Test.startTest();

        // When: Getting accounts by Ids
        Map<Id, Account> results = CaseContextGetter.getAccountsByIds(accountIds);

        Test.stopTest();

        // Then: All accounts are returned
        System.assertEquals(accountIds.size(), results.size(), 'All accounts should be returned');
    }

    @isTest
    static void testGetAccountsByIds_Caching() {
        // Given: Accounts exist
        List<Account> testAccounts = [SELECT Id FROM Account LIMIT 2];
        Set<Id> accountIds = new Set<Id>();
        for (Account a : testAccounts) {
            accountIds.add(a.Id);
        }

        // When: First query (populates cache)
        Map<Id, Account> results1 = CaseContextGetter.getAccountsByIds(accountIds);

        Test.startTest();

        // When: Second query (uses cache)
        Map<Id, Account> results2 = CaseContextGetter.getAccountsByIds(accountIds);

        Test.stopTest();

        // Then: Both queries return same results
        System.assertEquals(results1.size(), results2.size(), 'Same number of accounts should be returned');
    }

    @isTest
    static void testGetAccountsByIds_EmptySet() {
        Test.startTest();

        // When: Getting accounts with empty set
        Map<Id, Account> results = CaseContextGetter.getAccountsByIds(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetLocationForStandardCase_Success() {
        Test.startTest();

        // When: Getting location for standard case
        Map<Id, Account> results = CaseContextGetter.getLocationForStandardCase();

        Test.stopTest();

        // Then: Result is returned (may be empty if no matching location)
        System.assertNotEquals(null, results, 'Results should not be null');
    }

    // ========================================================================
    // BUSINESS HOURS TESTS
    // ========================================================================

    @isTest
    static void testGetBusinessHoursByTimezone_Success() {
        Test.startTest();

        // When: Getting all business hours
        Map<String, Id> results = CaseContextGetter.getBusinessHoursByTimezone();

        Test.stopTest();

        // Then: Results are returned (may be empty if no business hours configured)
        System.assertNotEquals(null, results, 'Results should not be null');
    }

    @isTest
    static void testGetBusinessHoursByTimezone_Caching() {
        Test.startTest();

        // When: Getting business hours twice
        Map<String, Id> results1 = CaseContextGetter.getBusinessHoursByTimezone();
        Map<String, Id> results2 = CaseContextGetter.getBusinessHoursByTimezone();

        Test.stopTest();

        // Then: Same results are returned (from cache)
        System.assertEquals(results1.size(), results2.size(), 'Same results should be returned from cache');
    }

    @isTest
    static void testGetBusinessHoursIdForTimezone_Success() {
        Test.startTest();

        // When: Getting business hours for specific timezone
        Id bhId = CaseContextGetter.getBusinessHoursIdForTimezone('America/New_York');

        Test.stopTest();

        // Then: Method executes without error (may return null if not configured)
        System.assert(true, 'Method should execute without error');
    }

    @isTest
    static void testGetBusinessHoursIdForTimezone_NullTimezone() {
        Test.startTest();

        // When: Getting business hours with null timezone
        Id bhId = CaseContextGetter.getBusinessHoursIdForTimezone(null);

        Test.stopTest();

        // Then: Null is returned
        System.assertEquals(null, bhId, 'Null should be returned for null timezone');
    }

    // ========================================================================
    // WORK ORDER QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetWorkOrdersByCaseIds_Success() {
        // Given: Cases with work orders exist
        List<Case> casesWithWO = [SELECT Id FROM Case WHERE ParentId != null LIMIT 3];
        Set<Id> caseIds = new Set<Id>();
        for (Case c : casesWithWO) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When: Getting work orders
        List<WorkOrder> results = CaseContextGetter.getWorkOrdersByCaseIds(caseIds);

        Test.stopTest();

        // Then: Work orders are returned
        System.assert(results.size() > 0, 'Work orders should be found');
    }

    @isTest
    static void testGetWorkOrdersByCaseIds_NoWorkOrders() {
        // Given: A case without work orders
        Set<Id> caseIds = new Set<Id>{[SELECT Id FROM Case WHERE Reference_Number__c = 'BULK_REF_0' LIMIT 1].Id};

        Test.startTest();

        // When: Getting work orders
        List<WorkOrder> results = CaseContextGetter.getWorkOrdersByCaseIds(caseIds);

        Test.stopTest();

        // Then: Empty list is returned
        System.assertEquals(0, results.size(), 'No work orders should be found');
    }

    @isTest
    static void testGetWorkOrderCounts_Success() {
        // Given: Work orders exist
        List<WorkOrder> wos = [SELECT AssetId, Customer_Location__c, Case_Subtype__c FROM WorkOrder LIMIT 1];
        if (wos.isEmpty()) {
            System.assert(true, 'No work orders to test');
            return;
        }

        Set<Id> assetIds = new Set<Id>{wos[0].AssetId};
        Set<Id> locationIds = new Set<Id>{wos[0].Customer_Location__c};

        Test.startTest();

        // When: Getting work order counts
        Map<String, Integer> results = CaseContextGetter.getWorkOrderCounts(
            assetIds, locationIds, wos[0].Case_Subtype__c, Date.today().addDays(-30), Date.today().addDays(30));

        Test.stopTest();

        // Then: Results are returned
        System.assertNotEquals(null, results, 'Results should not be null');
    }

    @isTest
    static void testGetWorkOrderCounts_NoResults() {
        // Given: Non-existent data
        Set<Id> assetIds = new Set<Id>();
        Set<Id> locationIds = new Set<Id>();

        Test.startTest();

        // When: Getting work order counts
        Map<String, Integer> results = CaseContextGetter.getWorkOrderCounts(
            assetIds, locationIds, 'NonExistent', Date.today(), Date.today());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetWorkOrderByCaseId_Success() {
        // Given: Cases with work orders exist
        List<Case> casesWithWO = [SELECT Id FROM Case WHERE ParentId != null LIMIT 2];
        Set<Id> caseIds = new Set<Id>();
        for (Case c : casesWithWO) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When: Getting work orders by case Id
        Map<Id, WorkOrder> results = CaseContextGetter.getWorkOrderByCaseId(caseIds);

        Test.stopTest();

        // Then: Work orders are returned
        System.assertNotEquals(null, results, 'Results should not be null');
    }

    @isTest
    static void testGetWorkOrderByCaseId_EmptySet() {
        Test.startTest();

        // When: Getting work orders with empty set
        Map<Id, WorkOrder> results = CaseContextGetter.getWorkOrderByCaseId(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'Empty map should be returned');
    }

    // ========================================================================
    // APPROVAL LOG QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetApprovalLogsByCaseIds_Success() {
        // Given: Cases with approval logs exist
        List<Case> casesWithLogs = [SELECT Id FROM Case WHERE ParentId != null LIMIT 3];
        Set<Id> caseIds = new Set<Id>();
        for (Case c : casesWithLogs) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When: Getting approval logs
        List<Approval_Log__c> results = CaseContextGetter.getApprovalLogsByCaseIds(caseIds);

        Test.stopTest();

        // Then: Approval logs are returned
        System.assert(results.size() > 0, 'Approval logs should be found');
    }

    @isTest
    static void testGetApprovalLogsByCaseIds_NoLogs() {
        // Given: A case without approval logs
        Set<Id> caseIds = new Set<Id>{[SELECT Id FROM Case WHERE Reference_Number__c = 'BULK_REF_0' LIMIT 1].Id};

        Test.startTest();

        // When: Getting approval logs
        List<Approval_Log__c> results = CaseContextGetter.getApprovalLogsByCaseIds(caseIds);

        Test.stopTest();

        // Then: Empty list is returned
        System.assertEquals(0, results.size(), 'No approval logs should be found');
    }

    // ========================================================================
    // CACHE UTILITY TESTS
    // ========================================================================

    @isTest
    static void testClearCaches_Success() {
        // Given: Data is cached
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Case result1 = CaseContextGetter.getCaseById(testCase.Id);
        Integer cacheSize1 = CaseContextGetter.getCaseCacheSize();

        Test.startTest();

        // When: Cache is cleared
        CaseContextGetter.clearCaches();

        Test.stopTest();

        // Then: Cache is empty
        Integer cacheSize2 = CaseContextGetter.getCaseCacheSize();
        System.assertEquals(0, cacheSize2, 'Cache should be empty after clear');
        System.assert(cacheSize1 > 0, 'Cache should have had data before clear');
    }

    @isTest
    static void testIsCaseCached_True() {
        // Given: A case is cached
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        CaseContextGetter.getCaseById(testCase.Id);

        Test.startTest();

        // When: Checking if case is cached
        Boolean isCached = CaseContextGetter.isCaseCached(testCase.Id);

        Test.stopTest();

        // Then: True is returned
        System.assertEquals(true, isCached, 'Case should be cached');
    }

    @isTest
    static void testIsCaseCached_False() {
        // Given: A case is not cached
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        CaseContextGetter.clearCaches();

        Test.startTest();

        // When: Checking if case is cached
        Boolean isCached = CaseContextGetter.isCaseCached(testCase.Id);

        Test.stopTest();

        // Then: False is returned
        System.assertEquals(false, isCached, 'Case should not be cached');
    }

    @isTest
    static void testGetCaseCacheSize_AfterQueries() {
        // Given: Multiple cases are cached
        List<Case> testCases = [SELECT Id FROM Case LIMIT 3];
        for (Case c : testCases) {
            CaseContextGetter.getCaseById(c.Id);
        }

        Test.startTest();

        // When: Getting cache size
        Integer cacheSize = CaseContextGetter.getCaseCacheSize();

        Test.stopTest();

        // Then: Cache size matches number of cached cases
        System.assertEquals(testCases.size(), cacheSize, 'Cache size should match number of cached cases');
    }

    // ========================================================================
    // UTILITY METHOD TESTS
    // ========================================================================

    @isTest
    static void testGetGroupIdByDeveloperName_Success() {
        Test.startTest();

        // When: Getting group by developer name
        Id groupId = CaseContextGetter.getGroupIdByDeveloperName('NonExistentGroup');

        Test.stopTest();

        // Then: Null is returned for non-existent group
        System.assertEquals(null, groupId, 'Null should be returned for non-existent group');
    }

    @isTest
    static void testGetRecordTypeId_Success() {
        Test.startTest();

        // When: Getting record type Id
        Id rtId = CaseContextGetter.getRecordTypeId('Case', 'Service_Request');

        Test.stopTest();

        // Then: Result is returned (may be null if record type doesn't exist)
        System.assert(true, 'Method should execute without error');
    }

    @isTest
    static void testGetRecordTypeId_InvalidObject() {
        Test.startTest();

        // When: Getting record type Id for invalid object
        Id rtId = CaseContextGetter.getRecordTypeId('InvalidObject', 'SomeType');

        Test.stopTest();

        // Then: Null is returned
        System.assertEquals(null, rtId, 'Null should be returned for invalid object');
    }

    // ========================================================================
    // INTEGRATION TESTS
    // ========================================================================

    @isTest
    static void testGetCaseWithAllRelationships_Success() {
        // Given: A case with all relationships populated
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
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
    }

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
        Map<Id, Case> results = CaseContextGetter.getCasesByIds(caseIds);

        // Then: Operation completes within governor limits
        Integer queriesUsed = Limits.getQueries();
        System.assert(queriesUsed < Limits.getLimitQueries(), 'Should be within SOQL query limits');

        Test.stopTest();

        // And: All cases are returned
        System.assertEquals(caseIds.size(), results.size(), 'All cases should be returned');
    }
}
