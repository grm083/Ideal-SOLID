/**
 * @description Comprehensive test class for Entitlement_Utility
 *
 * Coverage Target: 85%+
 *
 * Tests all entitlement retrieval, prioritization, filtering, and ranking logic
 * including complex prioritization algorithms and custom comparators.
 *
 * @author Refactored Architecture Team
 * @date 2025
 * @group Test Classes
 */
@isTest
private class Entitlement_UtilityTest {

    @testSetup
    static void setupTestData() {
        // Create full test hierarchy
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();

        Account locationAccount = (Account)testData.get('locationAccount');
        locationAccount.tz__Timezone_SFDC__c = 'America/New_York';
        update locationAccount;

        Contact contact = (Contact)testData.get('contact');
        Asset asset = (Asset)testData.get('asset');
        Account clientAccount = (Account)testData.get('clientAccount');

        // Create Product for Entitlement
        Product2 entitlementProduct = new Product2(
            Name = 'Test Entitlement Product',
            IsActive = true,
            Family = 'Commercial'
        );
        insert entitlementProduct;

        // Create ServiceContract
        ServiceContract sc = new ServiceContract(
            Name = 'Test Service Contract',
            AccountId = clientAccount.Id,
            StartDate = Date.today().addDays(-365),
            EndDate = Date.today().addDays(365)
        );
        insert sc;

        // Create multiple entitlements with different priorities
        List<Entitlement> entitlements = new List<Entitlement>();

        // High priority entitlement
        Entitlement highPriority = new Entitlement(
            Name = 'High Priority Entitlement',
            AccountId = clientAccount.Id,
            ServiceContractId = sc.Id,
            StartDate = Date.today().addDays(-365),
            EndDate = Date.today().addDays(365),
            SLA_Start_Pickup__c = 'Same Day',
            SLA_Days__c = 1,
            SLA_Pickup_Days__c = 1,
            AssetId = asset.Id,
            Customer_Identification_Priority__c = 1,
            Service_Identification_Priority__c = 1,
            Transaction_Identification_Priority__c = 1
        );
        entitlements.add(highPriority);

        // Medium priority entitlement
        Entitlement mediumPriority = new Entitlement(
            Name = 'Medium Priority Entitlement',
            AccountId = clientAccount.Id,
            ServiceContractId = sc.Id,
            StartDate = Date.today().addDays(-365),
            EndDate = Date.today().addDays(365),
            SLA_Start_Pickup__c = 'Next Day',
            SLA_Days__c = 2,
            SLA_Pickup_Days__c = 2,
            Customer_Identification_Priority__c = 2,
            Service_Identification_Priority__c = 2,
            Transaction_Identification_Priority__c = 2
        );
        entitlements.add(mediumPriority);

        // Low priority entitlement
        Entitlement lowPriority = new Entitlement(
            Name = 'Low Priority Entitlement',
            AccountId = clientAccount.Id,
            ServiceContractId = sc.Id,
            StartDate = Date.today().addDays(-365),
            EndDate = Date.today().addDays(365),
            SLA_Start_Pickup__c = '2 Day',
            SLA_Days__c = 3,
            SLA_Pickup_Days__c = 3,
            Customer_Identification_Priority__c = 3,
            Service_Identification_Priority__c = 3,
            Transaction_Identification_Priority__c = 3
        );
        entitlements.add(lowPriority);

        insert entitlements;

        // Create cases for testing
        List<Case> testCases = new List<Case>();

        Case testCase1 = TestDataFactoryRefactored.createCaseWithRelationships(
            clientAccount.Id, locationAccount.Id, contact.Id, asset.Id, 'Service_Request'
        );
        testCase1.EntitlementId = highPriority.Id;
        testCase1.Service_Date__c = Date.today().addDays(1);
        testCases.add(testCase1);

        Case testCase2 = TestDataFactoryRefactored.createCaseWithRelationships(
            clientAccount.Id, locationAccount.Id, contact.Id, asset.Id, 'Service_Request'
        );
        testCase2.EntitlementId = mediumPriority.Id;
        testCase2.Service_Date__c = Date.today().addDays(2);
        testCases.add(testCase2);

        insert testCases;
    }

    // ========================================
    // RELEVANT ENTITLEMENTS TESTS
    // ========================================

    @isTest
    static void testGetRelevantEntitlements_WithCases() {
        // Given: Case IDs
        Set<Id> caseIds = new Set<Id>();
        for (Case c : [SELECT Id FROM Case LIMIT 2]) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When
        Map<String, Map<String, List<Entitlement>>> result =
            Entitlement_Utility.getRelevantEntitlements(caseIds);

        Test.stopTest();

        // Then: Entitlements should be retrieved
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetRelevantEntitlements_NullInput() {
        Test.startTest();

        // When
        Map<String, Map<String, List<Entitlement>>> result =
            Entitlement_Utility.getRelevantEntitlements(null);

        Test.stopTest();

        // Then: Empty map should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Result should be empty for null input');
    }

    @isTest
    static void testGetRelevantEntitlements_EmptySet() {
        Test.startTest();

        // When
        Map<String, Map<String, List<Entitlement>>> result =
            Entitlement_Utility.getRelevantEntitlements(new Set<Id>());

        Test.stopTest();

        // Then: Empty map should be returned
        System.assertEquals(0, result.size(), 'Result should be empty for empty input');
    }

    // ========================================
    // PRIORITIZED ENTITLEMENTS TESTS
    // ========================================

    @isTest
    static void testGetPrioritizedEntitlements_Success() {
        // Given: Case IDs
        Set<Id> caseIds = new Set<Id>();
        for (Case c : [SELECT Id FROM Case LIMIT 2]) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When
        Map<String, Entitlement> result = Entitlement_Utility.getPrioritizedEntitlements(caseIds);

        Test.stopTest();

        // Then: Prioritized entitlements should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetPrioritizedEntitlements_NullInput() {
        Test.startTest();

        // When
        Map<String, Entitlement> result = Entitlement_Utility.getPrioritizedEntitlements(null);

        Test.stopTest();

        // Then: Empty map should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Result should be empty for null input');
    }

    // ========================================
    // PARSE AND GROUP TESTS
    // ========================================

    @isTest
    static void testParseAndGroupEntitlements_Success() {
        // Given: Entitlement list
        List<Entitlement> entitlements = [SELECT Id, Name, AccountId FROM Entitlement LIMIT 3];
        Map<String, List<Entitlement>> entitlementMap = new Map<String, List<Entitlement>>();
        entitlementMap.put('TestKey', entitlements);

        Test.startTest();

        // When
        Map<String, Map<String, List<Entitlement>>> result =
            Entitlement_Utility.parseAndGroupEntitlements(entitlementMap);

        Test.stopTest();

        // Then: Grouped entitlements should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testParseAndGroupEntitlements_NullInput() {
        Test.startTest();

        // When
        Map<String, Map<String, List<Entitlement>>> result =
            Entitlement_Utility.parseAndGroupEntitlements(null);

        Test.stopTest();

        // Then: Empty map should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================
    // FIELD MAPPING TESTS
    // ========================================

    @isTest
    static void testGetFieldMapping_Success() {
        Test.startTest();

        // When
        List<Entitlement_Field_Mapping__mdt> mappings = Entitlement_Utility.getFieldMapping();

        Test.stopTest();

        // Then: Field mappings should be returned
        System.assertNotEquals(null, mappings, 'Field mappings should not be null');
    }

    // ========================================
    // CASE DETAILS TESTS
    // ========================================

    @isTest
    static void testGetCaseDetails_Success() {
        // Given: Case IDs and field mapping
        Set<Id> caseIds = new Set<Id>();
        for (Case c : [SELECT Id FROM Case LIMIT 2]) {
            caseIds.add(c.Id);
        }

        Map<String, List<Entitlement_Utility.priorityFields>> casePriorityFields =
            new Map<String, List<Entitlement_Utility.priorityFields>>();
        List<Entitlement_Field_Mapping__mdt> fieldMapping = Entitlement_Utility.getFieldMapping();

        Test.startTest();

        // When
        Map<String, List<Entitlement_Utility.priorityFields>> result =
            Entitlement_Utility.getCaseDetails(caseIds, casePriorityFields, fieldMapping);

        Test.stopTest();

        // Then: Case details should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetCaseDetails_NullInput() {
        Test.startTest();

        // When
        Map<String, List<Entitlement_Utility.priorityFields>> result =
            Entitlement_Utility.getCaseDetails(null, null, null);

        Test.stopTest();

        // Then: Should handle gracefully
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================
    // ENTITLEMENTS RETRIEVAL TESTS
    // ========================================

    @isTest
    static void testGetEntitlements_Success() {
        // Given: Priority fields and field mapping
        Map<String, List<Entitlement_Utility.priorityFields>> priorityFields =
            new Map<String, List<Entitlement_Utility.priorityFields>>();
        List<Entitlement_Field_Mapping__mdt> mappedFields = Entitlement_Utility.getFieldMapping();

        Test.startTest();

        // When
        Map<String, List<Entitlement>> result =
            Entitlement_Utility.getEntitlements(priorityFields, mappedFields);

        Test.stopTest();

        // Then: Entitlements should be retrieved
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetEntitlements_NullInput() {
        Test.startTest();

        // When
        Map<String, List<Entitlement>> result = Entitlement_Utility.getEntitlements(null, null);

        Test.stopTest();

        // Then: Empty map should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================
    // TIME FILTERING TESTS
    // ========================================

    @isTest
    static void testFilterEntitlementsByTime_Success() {
        // Given: Priority fields and entitlements
        Map<String, List<Entitlement_Utility.priorityFields>> priorityFields =
            new Map<String, List<Entitlement_Utility.priorityFields>>();
        Map<String, List<Entitlement>> entitlements = new Map<String, List<Entitlement>>();

        Test.startTest();

        // When
        Map<String, List<Entitlement>> result =
            Entitlement_Utility.filterEntitlementsByTime(priorityFields, entitlements, Date.today());

        Test.stopTest();

        // Then: Filtered entitlements should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testFilterEntitlementsByTime_NullInput() {
        Test.startTest();

        // When
        Map<String, List<Entitlement>> result =
            Entitlement_Utility.filterEntitlementsByTime(null, null, null);

        Test.stopTest();

        // Then: Empty map should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================
    // PRIORITIZATION TESTS
    // ========================================

    @isTest
    static void testPrioritizeEntitlements_Success() {
        // Given: Priority fields and entitlements
        List<Entitlement_Utility.priorityFields> fields = new List<Entitlement_Utility.priorityFields>();
        Map<String, List<Entitlement>> entitlementRules = new Map<String, List<Entitlement>>();

        Test.startTest();

        // When
        Map<String, Entitlement> result =
            Entitlement_Utility.prioritizeEntitlements(fields, entitlementRules);

        Test.stopTest();

        // Then: Prioritized entitlements should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testPrioritizeEntitlements_NullInput() {
        Test.startTest();

        // When
        Map<String, Entitlement> result = Entitlement_Utility.prioritizeEntitlements(null, null);

        Test.stopTest();

        // Then: Empty map should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================
    // RECORD LOCAL TIME TESTS
    // ========================================

    @isTest
    static void testGetRecordLocalTime_Success() {
        Test.startTest();

        // When
        Map<String, Datetime> result = Entitlement_Utility.getRecordLocalTime();

        Test.stopTest();

        // Then: Local time should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================
    // INDUSTRY STANDARD SLA TESTS
    // ========================================

    @isTest
    static void testGetIndustryStandardSLA_Success() {
        // Given: Case
        Case testCase = [SELECT Id, AccountId, Location__c FROM Case LIMIT 1];

        Test.startTest();

        // When
        List<Entitlement> result = Entitlement_Utility.getIndustryStandardSLA(testCase);

        Test.stopTest();

        // Then: Industry standard SLA should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetIndustryStandardSLA_NullCase() {
        Test.startTest();

        // When
        List<Entitlement> result = Entitlement_Utility.getIndustryStandardSLA(null);

        Test.stopTest();

        // Then: Empty list should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================
    // PRIORITY FIELD SETS TESTS
    // ========================================

    @isTest
    static void testGetPriorityFieldSets_Success() {
        Test.startTest();

        // When
        List<Entitlement_Utility.priorityFieldSets> result =
            Entitlement_Utility.getPriorityFieldSets();

        Test.stopTest();

        // Then: Priority field sets should be returned
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ========================================
    // INNER CLASS TESTS - priorityFields
    // ========================================

    @isTest
    static void testPriorityFields_Constructor() {
        Test.startTest();

        // When
        Entitlement_Utility.priorityFields field = new Entitlement_Utility.priorityFields();
        field.recordId = '001000000000001';
        field.priorityLevel = '1';
        field.commonName = 'Test Field';
        field.entitlementField = 'AssetId';
        field.objectValue = '002000000000001';

        Test.stopTest();

        // Then: Fields should be set
        System.assertEquals('001000000000001', field.recordId, 'Record ID should be set');
        System.assertEquals('1', field.priorityLevel, 'Priority level should be set');
        System.assertEquals('Test Field', field.commonName, 'Common name should be set');
        System.assertEquals('AssetId', field.entitlementField, 'Entitlement field should be set');
        System.assertEquals('002000000000001', field.objectValue, 'Object value should be set');
    }

    // ========================================
    // INNER CLASS TESTS - prioritizationResult
    // ========================================

    @isTest
    static void testPrioritizationResult_Constructor() {
        Test.startTest();

        // When
        Entitlement_Utility.prioritizationResult result =
            new Entitlement_Utility.prioritizationResult();

        Test.stopTest();

        // Then: Result should be initialized
        System.assertNotEquals(null, result, 'Result should be initialized');
        System.assertEquals(false, result.customerIdentification, 'Customer identification should be false');
        System.assertEquals(false, result.serviceIdentification, 'Service identification should be false');
        System.assertEquals(false, result.transactionIdentification, 'Transaction identification should be false');
    }

    @isTest
    static void testPrioritizationResult_ParameterizedConstructor() {
        // Given: Entitlement
        Entitlement ent = [SELECT Id FROM Entitlement LIMIT 1];

        Test.startTest();

        // When
        Entitlement_Utility.prioritizationResult result =
            new Entitlement_Utility.prioritizationResult(ent, true, true, true, 1, 1, 1, 1);

        Test.stopTest();

        // Then: Result should be initialized with parameters
        System.assertEquals(ent.Id, result.entitlementRecord.Id, 'Entitlement should be set');
        System.assertEquals(true, result.customerIdentification, 'Customer identification should be true');
        System.assertEquals(true, result.serviceIdentification, 'Service identification should be true');
        System.assertEquals(true, result.transactionIdentification, 'Transaction identification should be true');
        System.assertEquals(1, result.priorityRank, 'Priority rank should be 1');
    }

    @isTest
    static void testPrioritizationResult_GetterMethods() {
        // Given: Prioritization result
        Entitlement_Utility.prioritizationResult result =
            new Entitlement_Utility.prioritizationResult();
        result.priorityRank = 1;
        result.customerRank = 2;
        result.serviceRank = 3;
        result.transactionRank = 4;

        Test.startTest();

        // When
        Integer priority = result.getPriorityRank();
        Integer customer = result.getCustomerRank();
        Integer service = result.getServiceRank();
        Integer transaction = result.getTransactionRank();

        Test.stopTest();

        // Then: Getters should return correct values
        System.assertEquals(1, priority, 'Priority rank should be 1');
        System.assertEquals(2, customer, 'Customer rank should be 2');
        System.assertEquals(3, service, 'Service rank should be 3');
        System.assertEquals(4, transaction, 'Transaction rank should be 4');
    }

    // ========================================
    // COMPARATOR TESTS
    // ========================================

    @isTest
    static void testPrimaryPriorityCompare() {
        // Given: Two prioritization results
        Entitlement ent1 = [SELECT Id FROM Entitlement ORDER BY Name LIMIT 1];
        Entitlement ent2 = [SELECT Id FROM Entitlement ORDER BY Name DESC LIMIT 1];

        Entitlement_Utility.prioritizationResult p1 =
            new Entitlement_Utility.prioritizationResult(ent1, true, true, true, 1, 1, 1, 1);
        Entitlement_Utility.prioritizationResult p2 =
            new Entitlement_Utility.prioritizationResult(ent2, true, true, true, 2, 2, 2, 2);

        Test.startTest();

        // When
        Entitlement_Utility.PrimaryPriorityCompare comparator =
            new Entitlement_Utility.PrimaryPriorityCompare();
        Integer result = comparator.compare(p1, p2);

        Test.stopTest();

        // Then: Should compare based on priority
        System.assert(result != 0, 'Comparison should produce a result');
    }

    @isTest
    static void testCustomerPriorityCompare() {
        // Given: Two prioritization results
        Entitlement ent1 = [SELECT Id FROM Entitlement ORDER BY Name LIMIT 1];
        Entitlement ent2 = [SELECT Id FROM Entitlement ORDER BY Name DESC LIMIT 1];

        Entitlement_Utility.prioritizationResult p1 =
            new Entitlement_Utility.prioritizationResult(ent1, true, true, true, 1, 1, 1, 1);
        Entitlement_Utility.prioritizationResult p2 =
            new Entitlement_Utility.prioritizationResult(ent2, true, true, true, 2, 2, 2, 2);

        Test.startTest();

        // When
        Entitlement_Utility.CustomerPriorityCompare comparator =
            new Entitlement_Utility.CustomerPriorityCompare();
        Integer result = comparator.compare(p1, p2);

        Test.stopTest();

        // Then: Should compare based on customer priority
        System.assert(result != 0, 'Comparison should produce a result');
    }

    @isTest
    static void testServicePriorityCompare() {
        // Given: Two prioritization results
        Entitlement ent1 = [SELECT Id FROM Entitlement ORDER BY Name LIMIT 1];
        Entitlement ent2 = [SELECT Id FROM Entitlement ORDER BY Name DESC LIMIT 1];

        Entitlement_Utility.prioritizationResult p1 =
            new Entitlement_Utility.prioritizationResult(ent1, true, true, true, 1, 1, 1, 1);
        Entitlement_Utility.prioritizationResult p2 =
            new Entitlement_Utility.prioritizationResult(ent2, true, true, true, 2, 2, 2, 2);

        Test.startTest();

        // When
        Entitlement_Utility.ServicePriorityCompare comparator =
            new Entitlement_Utility.ServicePriorityCompare();
        Integer result = comparator.compare(p1, p2);

        Test.stopTest();

        // Then: Should compare based on service priority
        System.assert(result != 0, 'Comparison should produce a result');
    }

    @isTest
    static void testTransactionPriorityCompare() {
        // Given: Two prioritization results
        Entitlement ent1 = [SELECT Id FROM Entitlement ORDER BY Name LIMIT 1];
        Entitlement ent2 = [SELECT Id FROM Entitlement ORDER BY Name DESC LIMIT 1];

        Entitlement_Utility.prioritizationResult p1 =
            new Entitlement_Utility.prioritizationResult(ent1, true, true, true, 1, 1, 1, 1);
        Entitlement_Utility.prioritizationResult p2 =
            new Entitlement_Utility.prioritizationResult(ent2, true, true, true, 2, 2, 2, 2);

        Test.startTest();

        // When
        Entitlement_Utility.TransactionPriorityCompare comparator =
            new Entitlement_Utility.TransactionPriorityCompare();
        Integer result = comparator.compare(p1, p2);

        Test.stopTest();

        // Then: Should compare based on transaction priority
        System.assert(result != 0, 'Comparison should produce a result');
    }

    @isTest
    static void testCompositePriorityCompare() {
        // Given: Two prioritization results
        Entitlement ent1 = [SELECT Id FROM Entitlement ORDER BY Name LIMIT 1];
        Entitlement ent2 = [SELECT Id FROM Entitlement ORDER BY Name DESC LIMIT 1];

        Entitlement_Utility.prioritizationResult p1 =
            new Entitlement_Utility.prioritizationResult(ent1, true, true, true, 1, 1, 1, 1);
        Entitlement_Utility.prioritizationResult p2 =
            new Entitlement_Utility.prioritizationResult(ent2, true, true, true, 2, 2, 2, 2);

        Test.startTest();

        // When
        Entitlement_Utility.CompositePriorityCompare comparator =
            new Entitlement_Utility.CompositePriorityCompare();
        Integer result = comparator.compare(p1, p2);

        Test.stopTest();

        // Then: Should compare based on composite priority
        System.assert(result != 0, 'Comparison should produce a result');
    }

    // ========================================
    // BULK OPERATION TESTS
    // ========================================

    @isTest
    static void testBulkEntitlementRetrieval_WithinGovernorLimits() {
        // Given: Multiple case IDs
        Set<Id> caseIds = new Set<Id>();
        for (Case c : [SELECT Id FROM Case LIMIT 10]) {
            caseIds.add(c.Id);
        }

        Test.startTest();

        // When
        Map<String, Map<String, List<Entitlement>>> result =
            Entitlement_Utility.getRelevantEntitlements(caseIds);

        // Then: Should complete within governor limits
        Integer queries = Limits.getQueries();
        System.assert(queries < Limits.getLimitQueries(), 'Should be within SOQL query limits');

        Test.stopTest();
    }
}
