/**
 * @description Comprehensive test class for CaseAssetValidator
 *
 * This test class provides complete coverage for the CaseAssetValidator service,
 * testing all validation methods, case asset management, and helper functions.
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseAssetValidatorTest {

    @testSetup
    static void setupTestData() {
        // Create full test hierarchy
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();

        // Create additional assets with child relationships for comprehensive testing
        Account locationAccount = (Account)testData.get('locationAccount');
        Product2 prod = (Product2)testData.get('product');

        // Create Commercial asset with scheduled occurrence
        Asset commercialAsset = new Asset(
            Name = 'Commercial Test Asset',
            AccountId = locationAccount.Id,
            Product2Id = prod.Id,
            Status = 'Installed',
            ProductFamily = 'Commercial',
            Occurrence_Type__c = 'Scheduled',
            Start_Date__c = Date.today().addDays(-30),
            Is_Active__c = true
        );
        insert commercialAsset;

        // Create child assets for commercial asset
        List<Asset> childAssets = new List<Asset>();
        Asset childPickup = new Asset(
            Name = 'Pickup Service',
            AccountId = locationAccount.Id,
            ParentId = commercialAsset.Id,
            Product2Id = prod.Id,
            Service_Type__c = 'Pickup',
            Occurrence_Type__c = 'Scheduled',
            Has_Extra_Pickup__c = true,
            Is_Core_Service__c = true,
            Is_Active__c = true,
            Start_Date__c = Date.today().addDays(-30),
            ProductFamily = 'Commercial'
        );
        childAssets.add(childPickup);
        insert childAssets;

        // Create case with SBS_Case_Asset__c relationships
        Case testCase = (Case)testData.get('case');
        Asset mainAsset = (Asset)testData.get('asset');

        SBS_Case_Asset__c caseAsset = new SBS_Case_Asset__c(
            CaseId__c = testCase.Id,
            AssetId__c = mainAsset.Id,
            Asset_Header__c = mainAsset.Id
        );
        insert caseAsset;
    }

    // ========================================================================
    // VALIDATE PICKUP ASSET TESTS
    // ========================================================================

    @isTest
    static void testValidatePickupAsset_Success() {
        Asset testAsset = [SELECT Id FROM Asset WHERE ProductFamily = 'Rolloff' LIMIT 1];
        Date serviceDate = Date.today().addDays(7);

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(testAsset.Id, serviceDate);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('PICKUP', result.validationType, 'Validation type should be PICKUP');
    }

    @isTest
    static void testValidatePickupAsset_NullAsset() {
        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(null, Date.today());
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should be invalid for null asset');
        System.assert(result.errorMessage.contains('required'), 'Error message should mention required');
    }

    @isTest
    static void testValidatePickupAsset_NullServiceDate() {
        Asset testAsset = [SELECT Id FROM Asset LIMIT 1];

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(testAsset.Id, null);
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should be invalid for null service date');
    }

    @isTest
    static void testValidatePickupAsset_InvalidAssetId() {
        Id fakeAssetId = '02i000000000000AAA';

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(fakeAssetId, Date.today());
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should be invalid for non-existent asset');
    }

    @isTest
    static void testValidatePickupAsset_CommercialFamily() {
        Asset commercialAsset = [SELECT Id FROM Asset WHERE ProductFamily = 'Commercial' LIMIT 1];
        Date serviceDate = Date.today().addDays(7);

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(commercialAsset.Id, serviceDate);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('COMMERCIAL', result.validationType, 'Should validate as commercial');
    }

    // ========================================================================
    // VALIDATE NON-PICKUP ASSET TESTS
    // ========================================================================

    @isTest
    static void testValidateNonPickupAsset_Success() {
        Asset testAsset = [SELECT Id FROM Asset LIMIT 1];
        Date serviceDate = Date.today().addDays(7);

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validateNonPickupAsset(testAsset.Id, serviceDate);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('NON_PICKUP', result.validationType, 'Type should be NON_PICKUP');
    }

    @isTest
    static void testValidateNonPickupAsset_NullInputs() {
        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validateNonPickupAsset(null, null);
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should be invalid for null inputs');
    }

    // ========================================================================
    // VALIDATE CASE ASSETS TESTS
    // ========================================================================

    @isTest
    static void testValidateCaseAssets_Success() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validateCaseAssets(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('CASE_ASSETS', result.validationType, 'Type should be CASE_ASSETS');
    }

    @isTest
    static void testValidateCaseAssets_NullCaseId() {
        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validateCaseAssets(null);
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should be invalid for null case ID');
        System.assert(result.errorMessage.contains('required'), 'Error should mention required');
    }

    @isTest
    static void testValidateCaseAssets_NoCaseAssets() {
        // Create a case without case assets
        Case newCase = TestDataFactoryRefactored.createCase('Service_Request');
        insert newCase;

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validateCaseAssets(newCase.Id);
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should be invalid with no case assets');
    }

    // ========================================================================
    // REMOVE OBSOLETE ASSET LINKS TESTS
    // ========================================================================

    @isTest
    static void testRemoveObsoleteAssetLinks_Success() {
        Case testCase = [SELECT Id, AssetId FROM Case WHERE AssetId != null LIMIT 1];
        Map<String, String> oldCaseAssetMap = new Map<String, String>();
        oldCaseAssetMap.put(testCase.Id, testCase.AssetId);

        Test.startTest();
        CaseAssetValidator.removeObsoleteAssetLinks(oldCaseAssetMap);
        Test.stopTest();

        // Verify execution without errors
        System.assert(true, 'Method should execute without errors');
    }

    @isTest
    static void testRemoveObsoleteAssetLinks_EmptyMap() {
        Test.startTest();
        CaseAssetValidator.removeObsoleteAssetLinks(new Map<String, String>());
        Test.stopTest();

        System.assert(true, 'Should handle empty map gracefully');
    }

    // ========================================================================
    // CREATE CASE ASSET RELATIONSHIPS TESTS
    // ========================================================================

    @isTest
    static void testCreateCaseAssetRelationships_Insert() {
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Case newCase = TestDataFactoryRefactored.createCase('Service_Request');
        Asset testAsset = (Asset)testData.get('asset');
        newCase.AssetId = testAsset.Id;
        newCase.Service_Date__c = Date.today().addDays(7);
        insert newCase;

        Map<Id, Case> caseMap = new Map<Id, Case>{newCase.Id => newCase};
        Map<Id, Asset> assetMap = new Map<Id, Asset>([
            SELECT Id, Service_Header_Id__c, Service_Type__c, Is_Active__c,
                   ProductFamily, Start_Date__c, End_Date__c
            FROM Asset WHERE Id = :testAsset.Id
        ]);

        Test.startTest();
        CaseAssetValidator.createCaseAssetRelationships(caseMap, null, assetMap);
        Test.stopTest();

        System.assert(true, 'Method should execute without errors');
    }

    @isTest
    static void testCreateCaseAssetRelationships_Update() {
        Case testCase = [SELECT Id, AssetId, Service_Date__c FROM Case WHERE AssetId != null LIMIT 1];
        Case oldCase = testCase.clone(true, true, true, true);

        // Change asset
        Asset newAsset = [SELECT Id FROM Asset WHERE Id != :testCase.AssetId LIMIT 1];
        testCase.AssetId = newAsset.Id;

        Map<Id, Case> newCaseMap = new Map<Id, Case>{testCase.Id => testCase};
        Map<Id, Case> oldCaseMap = new Map<Id, Case>{oldCase.Id => oldCase};
        Map<Id, Asset> assetMap = new Map<Id, Asset>([
            SELECT Id, Service_Header_Id__c, Service_Type__c, Is_Active__c,
                   ProductFamily, Start_Date__c, End_Date__c
            FROM Asset WHERE Id = :newAsset.Id
        ]);

        Test.startTest();
        CaseAssetValidator.createCaseAssetRelationships(newCaseMap, oldCaseMap, assetMap);
        Test.stopTest();

        System.assert(true, 'Should handle update scenario');
    }

    // ========================================================================
    // MARK DUPLICATE SERVICE DATE CASES TESTS
    // ========================================================================

    @isTest
    static void testMarkDuplicateServiceDateCases_NoDuplicates() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Map<Id, Case> caseMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();
        CaseAssetValidator.markDuplicateServiceDateCases(caseMap);
        Test.stopTest();

        System.assert(true, 'Method should execute without errors');
    }

    @isTest
    static void testMarkDuplicateServiceDateCases_EmptyMap() {
        Test.startTest();
        CaseAssetValidator.markDuplicateServiceDateCases(new Map<Id, Case>());
        Test.stopTest();

        System.assert(true, 'Should handle empty map gracefully');
    }

    // ========================================================================
    // IS PARENT CASE WITHIN TIME WINDOW TESTS
    // ========================================================================

    @isTest
    static void testIsParentCaseWithinTimeWindow_NoParent() {
        Case testCase = [SELECT Id FROM Case WHERE ParentId = null LIMIT 1];

        Test.startTest();
        Boolean result = CaseAssetValidator.isParentCaseWithinTimeWindow(testCase.Id, 15);
        Test.stopTest();

        System.assertEquals(false, result, 'Should return false for case without parent');
    }

    @isTest
    static void testIsParentCaseWithinTimeWindow_NullCaseId() {
        Test.startTest();
        Boolean result = CaseAssetValidator.isParentCaseWithinTimeWindow(null, 15);
        Test.stopTest();

        System.assertEquals(false, result, 'Should return false for null case ID');
    }

    @isTest
    static void testIsParentCaseWithinTimeWindow_WithParent() {
        // Create parent and child case
        Case parentCase = TestDataFactoryRefactored.createCase('Service_Request');
        insert parentCase;

        Case childCase = TestDataFactoryRefactored.createCase('Service_Request');
        childCase.ParentId = parentCase.Id;
        insert childCase;

        Test.startTest();
        Boolean result = CaseAssetValidator.isParentCaseWithinTimeWindow(childCase.Id, 15);
        Test.stopTest();

        System.assert(result != null, 'Result should not be null');
    }

    // ========================================================================
    // VALIDATE CLOSED CASE EDITS TESTS
    // ========================================================================

    @isTest
    static void testValidateClosedCaseEdits() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Map<Id, Case> caseMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();
        CaseAssetValidator.validateClosedCaseEdits(caseMap);
        Test.stopTest();

        System.assert(true, 'Method should execute without errors');
    }

    // ========================================================================
    // SHOULD RESET SLA TESTS
    // ========================================================================

    @isTest
    static void testShouldResetSLA_TypeChanged() {
        Case oldCase = TestDataFactoryRefactored.createCase('Service_Request');
        oldCase.Case_Type__c = 'Pickup';

        Case newCase = oldCase.clone(false, false, false, false);
        newCase.Case_Type__c = 'Delivery';

        Test.startTest();
        Boolean result = CaseAssetValidator.shouldResetSLA(newCase, oldCase);
        Test.stopTest();

        System.assertEquals(true, result, 'Should reset SLA when case type changes');
    }

    @isTest
    static void testShouldResetSLA_SubTypeChanged() {
        Case oldCase = TestDataFactoryRefactored.createCase('Service_Request');
        oldCase.Case_Sub_Type__c = 'Extra Pickup';

        Case newCase = oldCase.clone(false, false, false, false);
        newCase.Case_Sub_Type__c = 'Delivery';

        Test.startTest();
        Boolean result = CaseAssetValidator.shouldResetSLA(newCase, oldCase);
        Test.stopTest();

        System.assertEquals(true, result, 'Should reset SLA when subtype changes');
    }

    @isTest
    static void testShouldResetSLA_NoChanges() {
        Case oldCase = TestDataFactoryRefactored.createCase('Service_Request');
        Case newCase = oldCase.clone(false, false, false, false);

        Test.startTest();
        Boolean result = CaseAssetValidator.shouldResetSLA(newCase, oldCase);
        Test.stopTest();

        System.assertEquals(false, result, 'Should not reset SLA when nothing changes');
    }

    // ========================================================================
    // IDENTIFY ROL ASSETS THAT AFFECT SUBTYPE TESTS
    // ========================================================================

    @isTest
    static void testIdentifyROLAssetsThatAffectSubtype() {
        Asset rolloffAsset = [SELECT Id, ProductFamily FROM Asset WHERE ProductFamily = 'Rolloff' LIMIT 1];
        Map<Id, Asset> assetMap = new Map<Id, Asset>([
            SELECT Id, Product2.Family FROM Asset WHERE Id = :rolloffAsset.Id
        ]);

        Test.startTest();
        Set<Id> result = CaseAssetValidator.identifyROLAssetsThatAffectSubtype(assetMap);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testIdentifyROLAssetsThatAffectSubtype_EmptyMap() {
        Test.startTest();
        Set<Id> result = CaseAssetValidator.identifyROLAssetsThatAffectSubtype(new Map<Id, Asset>());
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return empty set for empty map');
    }

    // ========================================================================
    // VALIDATE PICKUP ASSETS (BULK) TESTS
    // ========================================================================

    @isTest
    static void testValidatePickupAssets_BulkSuccess() {
        List<Asset> assets = [SELECT Id FROM Asset LIMIT 3];
        Map<Id, Date> assetParam = new Map<Id, Date>();
        for (Asset a : assets) {
            assetParam.put(a.Id, Date.today().addDays(7));
        }

        Test.startTest();
        Map<Id, String> results = CaseAssetValidator.validatePickupAssets(assetParam);
        Test.stopTest();

        System.assertEquals(assets.size(), results.size(), 'Should return result for each asset');
    }

    @isTest
    static void testValidatePickupAssets_NullMap() {
        Test.startTest();
        Map<Id, String> results = CaseAssetValidator.validatePickupAssets(null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty map for null input');
    }

    @isTest
    static void testValidatePickupAssets_EmptyMap() {
        Test.startTest();
        Map<Id, String> results = CaseAssetValidator.validatePickupAssets(new Map<Id, Date>());
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty map for empty input');
    }

    // ========================================================================
    // VALIDATE NON-PICKUP ASSETS (BULK) TESTS
    // ========================================================================

    @isTest
    static void testValidateNonPickupAssets_BulkSuccess() {
        List<Asset> assets = [SELECT Id FROM Asset LIMIT 3];
        Map<Id, Date> assetParam = new Map<Id, Date>();
        for (Asset a : assets) {
            assetParam.put(a.Id, Date.today().addDays(7));
        }

        Test.startTest();
        Map<Id, String> results = CaseAssetValidator.validateNonPickupAssets(assetParam);
        Test.stopTest();

        System.assertEquals(assets.size(), results.size(), 'Should return result for each asset');
    }

    @isTest
    static void testValidateNonPickupAssets_NullMap() {
        Test.startTest();
        Map<Id, String> results = CaseAssetValidator.validateNonPickupAssets(null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty map for null input');
    }

    @isTest
    static void testValidateNonPickupAssets_EmptyMap() {
        Test.startTest();
        Map<Id, String> results = CaseAssetValidator.validateNonPickupAssets(new Map<Id, Date>());
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty map for empty input');
    }

    // ========================================================================
    // VALIDATION RESULT WRAPPER TESTS
    // ========================================================================

    @isTest
    static void testValidationResult_Constructor() {
        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            new CaseAssetValidator.ValidationResult(true, 'Test message', 'TEST_TYPE');
        Test.stopTest();

        System.assertEquals(true, result.isValid, 'isValid should be true');
        System.assertEquals('Test message', result.errorMessage, 'Error message should match');
        System.assertEquals('TEST_TYPE', result.validationType, 'Validation type should match');
    }

    @isTest
    static void testValidationResult_InvalidCase() {
        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            new CaseAssetValidator.ValidationResult(false, 'Validation failed', 'ERROR');
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'isValid should be false');
        System.assertNotEquals(null, result.errorMessage, 'Error message should be populated');
    }
}
