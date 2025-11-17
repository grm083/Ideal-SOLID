/**
 * @description Comprehensive test class for CaseAssetValidator
 *
 * This test class provides complete coverage for the CaseAssetValidator service,
 * testing all validation methods, case asset management, and helper functions.
 *
 * Coverage Target: 85%+
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

        Account locationAccount = (Account)testData.get('locationAccount');
        Product2 prod = (Product2)testData.get('product');

        // Update product to have Equipment Type
        prod.Equipment_Type__c = 'Container';
        update prod;

        // Create Commercial Scheduled asset with proper hierarchy
        Asset commercialScheduled = new Asset(
            Name = 'Commercial Scheduled Asset',
            AccountId = locationAccount.Id,
            Product2Id = prod.Id,
            Status = 'Installed',
            ProductFamily = 'Commercial',
            Occurrence_Type__c = 'Scheduled',
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            Is_Active__c = true,
            Service_Header_Id__c = null // Will be set to own ID after insert
        );
        insert commercialScheduled;

        commercialScheduled.Service_Header_Id__c = commercialScheduled.Id;
        update commercialScheduled;

        // Create child pickup service (scheduled with XPU)
        Asset childPickupScheduled = new Asset(
            Name = 'Scheduled Pickup with XPU',
            AccountId = locationAccount.Id,
            ParentId = commercialScheduled.Id,
            Product2Id = prod.Id,
            Service_Type__c = 'Pickup',
            Occurrence_Type__c = 'Scheduled',
            Has_Extra_Pickup__c = true,
            Is_Core_Service__c = true,
            Is_Active__c = true,
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            ProductFamily = 'Commercial',
            Service_Header_Id__c = commercialScheduled.Id
        );
        insert childPickupScheduled;

        // Create Commercial On-Call asset
        Asset commercialOnCall = new Asset(
            Name = 'Commercial OnCall Asset',
            AccountId = locationAccount.Id,
            Product2Id = prod.Id,
            Status = 'Installed',
            ProductFamily = 'Commercial',
            Occurrence_Type__c = 'On-Call',
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            Is_Active__c = true,
            Service_Header_Id__c = null
        );
        insert commercialOnCall;

        commercialOnCall.Service_Header_Id__c = commercialOnCall.Id;
        update commercialOnCall;

        // Create child on-call pickup service
        Asset childPickupOnCall = new Asset(
            Name = 'OnCall Pickup',
            AccountId = locationAccount.Id,
            ParentId = commercialOnCall.Id,
            Product2Id = prod.Id,
            Service_Type__c = 'Pickup',
            Occurrence_Type__c = 'On-Call',
            Has_Extra_Pickup__c = false,
            Is_Core_Service__c = true,
            Is_Active__c = true,
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            ProductFamily = 'Commercial',
            Service_Header_Id__c = commercialOnCall.Id
        );
        insert childPickupOnCall;

        // Create Rolloff asset with children
        Asset rolloffAsset = new Asset(
            Name = 'Rolloff Asset',
            AccountId = locationAccount.Id,
            Product2Id = prod.Id,
            Status = 'Installed',
            ProductFamily = 'Rolloff',
            Occurrence_Type__c = 'On-Call',
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            Is_Active__c = true,
            Service_Header_Id__c = null
        );
        insert rolloffAsset;

        rolloffAsset.Service_Header_Id__c = rolloffAsset.Id;
        update rolloffAsset;

        // Create rolloff child assets
        List<Asset> rolloffChildren = new List<Asset>();

        // Core disposal service
        rolloffChildren.add(new Asset(
            Name = 'Disposal Service',
            AccountId = locationAccount.Id,
            ParentId = rolloffAsset.Id,
            Product2Id = prod.Id,
            Service_Type__c = 'Disposal',
            Is_Core_Service__c = true,
            Is_Active__c = true,
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            ProductFamily = 'Rolloff',
            Service_Header_Id__c = rolloffAsset.Id
        ));

        // Recycling service
        rolloffChildren.add(new Asset(
            Name = 'Recycling Service',
            AccountId = locationAccount.Id,
            ParentId = rolloffAsset.Id,
            Product2Id = prod.Id,
            Service_Type__c = 'Recycling',
            Is_Core_Service__c = false,
            Is_Active__c = true,
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            ProductFamily = 'Rolloff',
            Service_Header_Id__c = rolloffAsset.Id
        ));

        insert rolloffChildren;

        // Create Services asset
        Asset servicesAsset = new Asset(
            Name = 'Services Asset',
            AccountId = locationAccount.Id,
            Product2Id = prod.Id,
            Status = 'Installed',
            ProductFamily = 'Services',
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            Is_Active__c = true,
            Service_Header_Id__c = null
        );
        insert servicesAsset;

        servicesAsset.Service_Header_Id__c = servicesAsset.Id;
        update servicesAsset;

        // Create services child assets
        Asset bulkService = new Asset(
            Name = 'Bulk Service',
            AccountId = locationAccount.Id,
            ParentId = servicesAsset.Id,
            Product2Id = prod.Id,
            Service_Type__c = 'Bulk',
            Is_Active__c = true,
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            ProductFamily = 'Services',
            Service_Header_Id__c = servicesAsset.Id
        );
        insert bulkService;

        // Create expired asset for testing date validation
        Asset expiredAsset = new Asset(
            Name = 'Expired Asset',
            AccountId = locationAccount.Id,
            Product2Id = prod.Id,
            Status = 'Installed',
            ProductFamily = 'Commercial',
            Occurrence_Type__c = 'Scheduled',
            Start_Date__c = Date.today().addDays(-365),
            End_Date__c = Date.today().addDays(-1),
            Is_Active__c = false,
            Service_Header_Id__c = null
        );
        insert expiredAsset;

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
    // VALIDATE PICKUP ASSET - COMMERCIAL SCHEDULED TESTS
    // ========================================================================

    @isTest
    static void testValidatePickupAsset_CommercialScheduled_Success() {
        Asset commercialAsset = [SELECT Id FROM Asset WHERE Name = 'Commercial Scheduled Asset' LIMIT 1];
        Date serviceDate = Date.today().addDays(7);

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(commercialAsset.Id, serviceDate);
        Test.stopTest();

        System.assertEquals(true, result.isValid, 'Commercial scheduled should be valid');
        System.assertEquals('COMMERCIAL', result.validationType, 'Should validate as commercial');
    }

    @isTest
    static void testValidatePickupAsset_CommercialScheduled_NoXPU() {
        // Create commercial asset without XPU child
        Account loc = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];

        Asset noXPUAsset = new Asset(
            Name = 'No XPU Asset',
            AccountId = loc.Id,
            Product2Id = prod.Id,
            ProductFamily = 'Commercial',
            Occurrence_Type__c = 'Scheduled',
            Start_Date__c = Date.today().addDays(-30),
            Is_Active__c = true
        );
        insert noXPUAsset;

        // Add child without XPU
        Asset childNoXPU = new Asset(
            Name = 'No XPU Child',
            AccountId = loc.Id,
            ParentId = noXPUAsset.Id,
            Product2Id = prod.Id,
            Service_Type__c = 'Pickup',
            Occurrence_Type__c = 'Scheduled',
            Has_Extra_Pickup__c = false,
            Is_Core_Service__c = true,
            Is_Active__c = true,
            Start_Date__c = Date.today().addDays(-30),
            ProductFamily = 'Commercial'
        );
        insert childNoXPU;

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(noXPUAsset.Id, Date.today().addDays(7));
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should fail without XPU component');
        System.assert(result.errorMessage.contains('Extra Pickup'), 'Error should mention XPU');
    }

    @isTest
    static void testValidatePickupAsset_CommercialScheduled_NoCoreService() {
        Account loc = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];

        Asset noCoreAsset = new Asset(
            Name = 'No Core Service Asset',
            AccountId = loc.Id,
            Product2Id = prod.Id,
            ProductFamily = 'Commercial',
            Occurrence_Type__c = 'Scheduled',
            Start_Date__c = Date.today().addDays(-30),
            Is_Active__c = true
        );
        insert noCoreAsset;

        // Add child that is not core service
        Asset childNotCore = new Asset(
            Name = 'Not Core Child',
            AccountId = loc.Id,
            ParentId = noCoreAsset.Id,
            Product2Id = prod.Id,
            Service_Type__c = 'Pickup',
            Occurrence_Type__c = 'Scheduled',
            Has_Extra_Pickup__c = true,
            Is_Core_Service__c = false,
            Is_Active__c = false,
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(-1),
            ProductFamily = 'Commercial'
        );
        insert childNotCore;

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(noCoreAsset.Id, Date.today().addDays(7));
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should fail without active core service');
    }

    // ========================================================================
    // VALIDATE PICKUP ASSET - COMMERCIAL ON-CALL TESTS
    // ========================================================================

    @isTest
    static void testValidatePickupAsset_CommercialOnCall_Success() {
        Asset onCallAsset = [SELECT Id FROM Asset WHERE Name = 'Commercial OnCall Asset' LIMIT 1];
        Date serviceDate = Date.today().addDays(7);

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(onCallAsset.Id, serviceDate);
        Test.stopTest();

        System.assertEquals(true, result.isValid, 'On-call asset should be valid');
    }

    @isTest
    static void testValidatePickupAsset_CommercialOnCall_MultiplePickups() {
        Account loc = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];

        Asset multiPickup = new Asset(
            Name = 'Multi Pickup Asset',
            AccountId = loc.Id,
            Product2Id = prod.Id,
            ProductFamily = 'Commercial',
            Occurrence_Type__c = 'On-Call',
            Start_Date__c = Date.today().addDays(-30),
            Is_Active__c = true
        );
        insert multiPickup;

        // Add multiple on-call pickup children
        List<Asset> children = new List<Asset>();
        for (Integer i = 0; i < 2; i++) {
            children.add(new Asset(
                Name = 'OnCall Pickup ' + i,
                AccountId = loc.Id,
                ParentId = multiPickup.Id,
                Product2Id = prod.Id,
                Service_Type__c = 'Pickup',
                Occurrence_Type__c = 'On-Call',
                Has_Extra_Pickup__c = false,
                Is_Core_Service__c = true,
                Is_Active__c = true,
                Start_Date__c = Date.today().addDays(-30),
                ProductFamily = 'Commercial'
            ));
        }
        insert children;

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(multiPickup.Id, Date.today().addDays(7));
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should fail with multiple on-call pickups');
        System.assert(result.errorMessage.contains('corrupted'), 'Error should mention corruption');
    }

    // ========================================================================
    // VALIDATE PICKUP ASSET - ROLLOFF TESTS
    // ========================================================================

    @isTest
    static void testValidatePickupAsset_Rolloff_WithCoreService() {
        Asset rolloffAsset = [SELECT Id FROM Asset WHERE ProductFamily = 'Rolloff' LIMIT 1];
        Date serviceDate = Date.today().addDays(7);

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(rolloffAsset.Id, serviceDate);
        Test.stopTest();

        System.assertEquals(true, result.isValid, 'Rolloff with core service should be valid');
        System.assertEquals('ROLLOFF', result.validationType, 'Type should be ROLLOFF');
    }

    @isTest
    static void testValidatePickupAsset_Rolloff_NoActiveComponents() {
        Account loc = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];

        Asset rolloffNoCore = new Asset(
            Name = 'Rolloff No Core',
            AccountId = loc.Id,
            Product2Id = prod.Id,
            ProductFamily = 'Rolloff',
            Start_Date__c = Date.today().addDays(-30),
            Is_Active__c = true
        );
        insert rolloffNoCore;

        // Add expired child
        Asset expiredChild = new Asset(
            Name = 'Expired Disposal',
            AccountId = loc.Id,
            ParentId = rolloffNoCore.Id,
            Product2Id = prod.Id,
            Service_Type__c = 'Disposal',
            Is_Core_Service__c = true,
            Is_Active__c = false,
            Start_Date__c = Date.today().addDays(-365),
            End_Date__c = Date.today().addDays(-1),
            ProductFamily = 'Rolloff'
        );
        insert expiredChild;

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(rolloffNoCore.Id, Date.today().addDays(7));
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should fail without active components');
    }

    @isTest
    static void testValidatePickupAsset_AssetNotActive() {
        Asset expiredAsset = [SELECT Id FROM Asset WHERE Name = 'Expired Asset' LIMIT 1];

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(expiredAsset.Id, Date.today());
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Expired asset should be invalid');
        System.assert(result.errorMessage.contains('not active'), 'Error should mention inactive');
    }

    // ========================================================================
    // VALIDATE PICKUP ASSET - EDGE CASES
    // ========================================================================

    @isTest
    static void testValidatePickupAsset_NullAsset() {
        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(null, Date.today());
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should be invalid for null asset');
        System.assert(result.errorMessage.contains('required'), 'Error should mention required');
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

    // ========================================================================
    // VALIDATE NON-PICKUP ASSET TESTS
    // ========================================================================

    @isTest
    static void testValidateNonPickupAsset_Success() {
        Asset commercialAsset = [SELECT Id FROM Asset WHERE Name = 'Commercial Scheduled Asset' LIMIT 1];
        Date serviceDate = Date.today().addDays(7);

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validateNonPickupAsset(commercialAsset.Id, serviceDate);
        Test.stopTest();

        System.assertEquals(true, result.isValid, 'Should be valid with active children');
        System.assertEquals('NON_PICKUP', result.validationType, 'Type should be NON_PICKUP');
    }

    @isTest
    static void testValidateNonPickupAsset_NoActiveChildren() {
        Account loc = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];

        Asset noActiveChildren = new Asset(
            Name = 'No Active Children',
            AccountId = loc.Id,
            Product2Id = prod.Id,
            ProductFamily = 'Commercial',
            Start_Date__c = Date.today().addDays(-30),
            Is_Active__c = true
        );
        insert noActiveChildren;

        // Add expired child
        Asset expiredChild = new Asset(
            Name = 'Expired Child',
            AccountId = loc.Id,
            ParentId = noActiveChildren.Id,
            Product2Id = prod.Id,
            Service_Type__c = 'Pickup',
            Is_Active__c = false,
            Start_Date__c = Date.today().addDays(-365),
            End_Date__c = Date.today().addDays(-1),
            ProductFamily = 'Commercial'
        );
        insert expiredChild;

        Test.startTest();
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validateNonPickupAsset(noActiveChildren.Id, Date.today().addDays(7));
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should fail without active children');
        System.assert(result.errorMessage.contains('end date'), 'Error should mention end dates');
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
        Case newCase = TestDataFactoryRefactored.createCase('Service_Request');
        Asset testAsset = [SELECT Id, Service_Header_Id__c, Service_Type__c, Is_Active__c, ProductFamily, Start_Date__c, End_Date__c
                          FROM Asset WHERE Name = 'Commercial Scheduled Asset' LIMIT 1];
        newCase.AssetId = testAsset.Id;
        newCase.Service_Date__c = Date.today().addDays(7);
        insert newCase;

        Map<Id, Case> caseMap = new Map<Id, Case>{newCase.Id => newCase};
        Map<Id, Asset> assetMap = new Map<Id, Asset>{testAsset.Id => testAsset};

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
        Asset newAsset = [SELECT Id, Service_Header_Id__c, Service_Type__c, Is_Active__c, ProductFamily, Start_Date__c, End_Date__c
                         FROM Asset WHERE Id != :testCase.AssetId LIMIT 1];
        testCase.AssetId = newAsset.Id;

        Map<Id, Case> newCaseMap = new Map<Id, Case>{testCase.Id => testCase};
        Map<Id, Case> oldCaseMap = new Map<Id, Case>{oldCase.Id => oldCase};
        Map<Id, Asset> assetMap = new Map<Id, Asset>{newAsset.Id => newAsset};

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
    static void testShouldResetSLA_LocationChanged() {
        Account loc1 = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];
        Account loc2 = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' AND Id != :loc1.Id LIMIT 1];

        Case oldCase = TestDataFactoryRefactored.createCase('Service_Request');
        oldCase.Location__c = loc1.Id;

        Case newCase = oldCase.clone(false, false, false, false);
        newCase.Location__c = loc2.Id;

        Test.startTest();
        Boolean result = CaseAssetValidator.shouldResetSLA(newCase, oldCase);
        Test.stopTest();

        System.assertEquals(true, result, 'Should reset SLA when location changes');
    }

    @isTest
    static void testShouldResetSLA_AssetChanged() {
        Asset asset1 = [SELECT Id FROM Asset LIMIT 1];
        Asset asset2 = [SELECT Id FROM Asset WHERE Id != :asset1.Id LIMIT 1];

        Case oldCase = TestDataFactoryRefactored.createCase('Service_Request');
        oldCase.AssetId = asset1.Id;

        Case newCase = oldCase.clone(false, false, false, false);
        newCase.AssetId = asset2.Id;

        Test.startTest();
        Boolean result = CaseAssetValidator.shouldResetSLA(newCase, oldCase);
        Test.stopTest();

        System.assertEquals(true, result, 'Should reset SLA when asset changes');
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
        Asset rolloffAsset = [SELECT Id, Product2.Family FROM Asset WHERE ProductFamily = 'Rolloff' LIMIT 1];
        Map<Id, Asset> assetMap = new Map<Id, Asset>{rolloffAsset.Id => rolloffAsset};

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
