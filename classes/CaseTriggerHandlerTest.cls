/**
 * @description Test class for CaseTriggerHandler
 *
 * This test class provides coverage for the CaseTriggerHandler,
 * which orchestrates all Case trigger operations.
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseTriggerHandlerTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    @testSetup
    static void setupTestData() {
        // Create Code Switch setting
        TestDataFactory.createProcessBuilderTOFlow();

        // Create full test hierarchy
        TestDataFactory.createFullTestHierarchy();
    }

    // ========================================================================
    // BEFORE INSERT TESTS
    // ========================================================================

    @isTest
    static void testBeforeInsert_BasicCase() {
        // Given: Test data exists
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        Asset testAsset = [SELECT Id FROM Asset LIMIT 1];

        Test.startTest();

        // When: Inserting a new case
        Case testCase = TestDataFactory.createCaseWithRelationships(
            clientAccount.Id,
            locationAccount.Id,
            testContact.Id,
            testAsset.Id,
            'Service_Request'
        );
        testCase.Status = 'New';
        insert testCase;

        Test.stopTest();

        // Then: Case is inserted successfully with proper field values
        Case result = [SELECT Id, Status, Reference_Number__c FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, result, 'Case should be inserted');
        System.assertEquals('New', result.Status, 'Status should be New');
    }

    @isTest
    static void testBeforeInsert_ClosedPickupCase() {
        // Given: A closed pickup case
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];

        Test.startTest();

        // When: Inserting a closed pickup case
        Case testCase = TestDataFactory.createCase('Service_Request');
        testCase.Status = 'Closed';
        testCase.Case_type__c = 'Pickup';
        testCase.Location__c = locationAccount.Id;
        insert testCase;

        Test.stopTest();

        // Then: Sub-status is auto-populated
        Case result = [SELECT Id, Case_Sub_Status__c FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, result.Case_Sub_Status__c, 'Sub-status should be populated');
    }

    // ========================================================================
    // BEFORE UPDATE TESTS
    // ========================================================================

    @isTest
    static void testBeforeUpdate_StatusChange() {
        // Given: An existing case
        Case testCase = [SELECT Id, Status FROM Case LIMIT 1];
        String originalStatus = testCase.Status;

        Test.startTest();

        // When: Updating case status
        testCase.Status = 'Open';
        update testCase;

        Test.stopTest();

        // Then: Case is updated
        Case result = [SELECT Id, Status FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Open', result.Status, 'Status should be updated');
    }

    @isTest
    static void testBeforeUpdate_CloseIrrelevantCase() {
        // Given: A case with Close_Irrelevant_Case__c flag
        Case testCase = [SELECT Id, Status, Close_Irrelevant_Case__c FROM Case LIMIT 1];

        Test.startTest();

        // When: Setting close irrelevant flag
        testCase.Close_Irrelevant_Case__c = true;
        update testCase;

        Test.stopTest();

        // Then: Case is auto-closed
        Case result = [SELECT Id, Status FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Closed', result.Status, 'Case should be auto-closed');
    }

    // ========================================================================
    // AFTER INSERT TESTS
    // ========================================================================

    @isTest
    static void testAfterInsert_CaseCreation() {
        // Given: Test data for new case
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];

        Test.startTest();

        // When: Creating a new case
        Case testCase = TestDataFactory.createCase('Service_Request');
        testCase.Client__c = clientAccount.Id;
        testCase.Location__c = locationAccount.Id;
        testCase.Chargeable__c = 'Yes';
        insert testCase;

        Test.stopTest();

        // Then: Case is created successfully
        Case result = [SELECT Id, Chargeable__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Yes', result.Chargeable__c, 'Chargeable field should be set');
    }

    // ========================================================================
    // AFTER UPDATE TESTS
    // ========================================================================

    @isTest
    static void testAfterUpdate_CaseUpdate() {
        // Given: An existing case
        Case testCase = [SELECT Id, Chargeable__c FROM Case LIMIT 1];

        Test.startTest();

        // When: Updating case
        testCase.Chargeable__c = 'No';
        update testCase;

        Test.stopTest();

        // Then: Case is updated
        Case result = [SELECT Id, Chargeable__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('No', result.Chargeable__c, 'Chargeable should be updated');
    }

    // ========================================================================
    // HELPER METHOD TESTS
    // ========================================================================

    @isTest
    static void testGetAssetRecordValue() {
        // Given: An asset exists
        Asset testAsset = [SELECT Id FROM Asset LIMIT 1];
        Set<Id> assetIds = new Set<Id>{testAsset.Id};

        Test.startTest();

        // When: Getting asset record
        Map<Id, Asset> results = CaseTriggerHandler.getAssetRecordValue(assetIds, true);

        Test.stopTest();

        // Then: Asset is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.containsKey(testAsset.Id), 'Should contain asset');
    }

    @isTest
    static void testGetLocationRecordValue() {
        // Given: A location account exists
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];
        Set<Id> locationIds = new Set<Id>{locationAccount.Id};

        Test.startTest();

        // When: Getting location record
        Map<Id, Account> results = CaseTriggerHandler.getLocationRecordValue(locationIds);

        Test.stopTest();

        // Then: Location is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.containsKey(locationAccount.Id), 'Should contain location');
    }

    @isTest
    static void testGetLocationRecordValueStandardCase() {
        Test.startTest();

        // When: Getting standard case location
        Map<Id, Account> results = CaseTriggerHandler.getLocationRecordValueStandardCase();

        Test.stopTest();

        // Then: Query executes without error
        System.assertNotEquals(null, results, 'Results should not be null');
    }

    // ========================================================================
    // BULK OPERATIONS TESTS
    // ========================================================================

    @isTest
    static void testBulkInsert_MultipleCases() {
        // Given: Test data for multiple cases
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];

        List<Case> casesToInsert = new List<Case>();
        for (Integer i = 0; i < 10; i++) {
            Case c = TestDataFactory.createCase('Service_Request');
            c.Client__c = clientAccount.Id;
            c.Location__c = locationAccount.Id;
            c.Subject = 'Bulk Test Case ' + i;
            casesToInsert.add(c);
        }

        Test.startTest();

        // When: Inserting multiple cases
        insert casesToInsert;

        Test.stopTest();

        // Then: All cases are inserted
        List<Case> results = [SELECT Id FROM Case WHERE Id IN :casesToInsert];
        System.assertEquals(10, results.size(), 'All cases should be inserted');
    }

    @isTest
    static void testBulkUpdate_MultipleCases() {
        // Given: Multiple existing cases
        List<Case> testCases = [SELECT Id, Status FROM Case LIMIT 5];

        Test.startTest();

        // When: Updating multiple cases
        for (Case c : testCases) {
            c.Status = 'Open';
        }
        update testCases;

        Test.stopTest();

        // Then: All cases are updated
        List<Case> results = [SELECT Id, Status FROM Case WHERE Id IN :testCases];
        for (Case c : results) {
            System.assertEquals('Open', c.Status, 'Status should be Open');
        }
    }

    // ========================================================================
    // ERROR HANDLING TESTS
    // ========================================================================

    @isTest
    static void testGetAssetRecordValue_EmptySet() {
        Test.startTest();

        // When: Getting asset with empty set
        Map<Id, Asset> results = CaseTriggerHandler.getAssetRecordValue(new Set<Id>(), true);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetAssetRecordValue_NullSet() {
        Test.startTest();

        // When: Getting asset with null set
        Map<Id, Asset> results = CaseTriggerHandler.getAssetRecordValue(null, true);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Empty map should be returned for null');
    }
}
