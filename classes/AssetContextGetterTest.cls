/**
 * @description Test class for AssetContextGetter
 *
 * This test class provides comprehensive coverage for the AssetContextGetter
 * data access layer, testing asset header and detail queries.
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class AssetContextGetterTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    @testSetup
    static void setupTestData() {
        // Create account and product
        Account locationAccount = TestDataFactory.createAccount('Location', 'Location');
        insert locationAccount;

        Product2 product = TestDataFactory.createProduct('Rolloff');
        insert product;

        // Create parent assets (headers)
        List<Asset> parentAssets = TestDataFactory.createAssets(3, locationAccount.Id, product.Id);
        insert parentAssets;

        // Create child assets (details) under first parent
        List<Asset> childAssets = new List<Asset>();
        for (Integer i = 0; i < 5; i++) {
            Asset child = TestDataFactory.createAsset(locationAccount.Id, product.Id);
            child.ParentId = parentAssets[0].Id;
            child.Name = 'Child Asset ' + i;
            childAssets.add(child);
        }
        insert childAssets;

        // Create child assets under second parent
        List<Asset> moreChildAssets = new List<Asset>();
        for (Integer i = 0; i < 3; i++) {
            Asset child = TestDataFactory.createAsset(locationAccount.Id, product.Id);
            child.ParentId = parentAssets[1].Id;
            child.Name = 'Child Asset B ' + i;
            moreChildAssets.add(child);
        }
        insert moreChildAssets;
    }

    // ========================================================================
    // GET HEADER BY ID TESTS
    // ========================================================================

    @isTest
    static void testGetHeaderById_SingleAsset_Success() {
        // Given: An asset exists
        Asset testAsset = [SELECT Id FROM Asset WHERE ParentId = null LIMIT 1];
        Set<Id> assetIds = new Set<Id>{testAsset.Id};

        Test.startTest();

        // When: Getting asset by Id
        Map<Id, Asset> result = AssetContextGetter.getHeaderById(assetIds);

        Test.stopTest();

        // Then: Asset is returned
        System.assertEquals(1, result.size(), 'One asset should be returned');
        System.assert(result.containsKey(testAsset.Id), 'Result should contain asset Id');
        System.assertNotEquals(null, result.get(testAsset.Id), 'Asset should not be null');
    }

    @isTest
    static void testGetHeaderById_MultipleAssets_Success() {
        // Given: Multiple assets exist
        List<Asset> testAssets = [SELECT Id FROM Asset WHERE ParentId = null LIMIT 3];
        Set<Id> assetIds = new Set<Id>();
        for (Asset ast : testAssets) {
            assetIds.add(ast.Id);
        }

        Test.startTest();

        // When: Getting multiple assets
        Map<Id, Asset> result = AssetContextGetter.getHeaderById(assetIds);

        Test.stopTest();

        // Then: All assets are returned
        System.assertEquals(assetIds.size(), result.size(), 'All assets should be returned');
        for (Id assetId : assetIds) {
            System.assert(result.containsKey(assetId), 'Result should contain asset Id: ' + assetId);
        }
    }

    @isTest
    static void testGetHeaderById_EmptySet() {
        Test.startTest();

        // When: Getting assets with empty set
        Map<Id, Asset> result = AssetContextGetter.getHeaderById(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetHeaderById_NullSet() {
        Test.startTest();

        // When: Getting assets with null set
        Map<Id, Asset> result = AssetContextGetter.getHeaderById(null);

        Test.stopTest();

        // Then: Empty map is returned (method should handle gracefully)
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetHeaderById_NonExistentId() {
        // Given: A non-existent asset Id
        Id fakeId = '02i000000000000AAA';
        Set<Id> assetIds = new Set<Id>{fakeId};

        Test.startTest();

        // When: Getting asset with non-existent Id
        Map<Id, Asset> result = AssetContextGetter.getHeaderById(assetIds);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, result.size(), 'Empty map should be returned for non-existent Id');
    }

    // ========================================================================
    // GET DETAILS BY HEADER ID TESTS
    // ========================================================================

    @isTest
    static void testGetDetailsbyHeaderId_SingleParent_Success() {
        // Given: A parent asset with child assets
        Asset parentAsset = [
            SELECT Id, (SELECT Id FROM ChildAssets)
            FROM Asset
            WHERE ParentId = null
            AND Id IN (SELECT ParentId FROM Asset WHERE ParentId != null)
            LIMIT 1
        ];

        Integer expectedChildCount = parentAsset.ChildAssets.size();
        Set<Id> parentIds = new Set<Id>{parentAsset.Id};

        Test.startTest();

        // When: Getting child assets by parent Id
        Map<Id, Asset> result = AssetContextGetter.getDetailsbyHeaderId(parentIds);

        Test.stopTest();

        // Then: All child assets are returned
        System.assertEquals(expectedChildCount, result.size(),
            'All child assets should be returned');

        // Verify all returned assets are children of this parent
        for (Asset child : result.values()) {
            System.assertEquals(parentAsset.Id, child.ParentId,
                'Asset should be child of parent');
        }
    }

    @isTest
    static void testGetDetailsbyHeaderId_MultipleParents_Success() {
        // Given: Multiple parent assets with children
        List<Asset> parentAssets = [
            SELECT Id, (SELECT Id FROM ChildAssets)
            FROM Asset
            WHERE ParentId = null
            AND Id IN (SELECT ParentId FROM Asset WHERE ParentId != null)
            LIMIT 2
        ];

        Set<Id> parentIds = new Set<Id>();
        Integer totalExpectedChildren = 0;

        for (Asset parent : parentAssets) {
            parentIds.add(parent.Id);
            totalExpectedChildren += parent.ChildAssets.size();
        }

        Test.startTest();

        // When: Getting child assets by multiple parent Ids
        Map<Id, Asset> result = AssetContextGetter.getDetailsbyHeaderId(parentIds);

        Test.stopTest();

        // Then: All child assets from all parents are returned
        System.assertEquals(totalExpectedChildren, result.size(),
            'All child assets from all parents should be returned');

        // Verify all returned assets have one of the parent Ids as parent
        for (Asset child : result.values()) {
            System.assert(parentIds.contains(child.ParentId),
                'Asset parent should be one of the requested parents');
        }
    }

    @isTest
    static void testGetDetailsbyHeaderId_ParentWithNoChildren() {
        // Given: A parent asset without children
        Asset parentWithoutChildren = [
            SELECT Id
            FROM Asset
            WHERE ParentId = null
            AND Id NOT IN (SELECT ParentId FROM Asset WHERE ParentId != null)
            LIMIT 1
        ];

        Set<Id> parentIds = new Set<Id>{parentWithoutChildren.Id};

        Test.startTest();

        // When: Getting child assets by parent Id with no children
        Map<Id, Asset> result = AssetContextGetter.getDetailsbyHeaderId(parentIds);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, result.size(), 'Empty map should be returned for parent with no children');
    }

    @isTest
    static void testGetDetailsbyHeaderId_EmptySet() {
        Test.startTest();

        // When: Getting child assets with empty parent set
        Map<Id, Asset> result = AssetContextGetter.getDetailsbyHeaderId(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetDetailsbyHeaderId_NullSet() {
        Test.startTest();

        // When: Getting child assets with null parent set
        Map<Id, Asset> result = AssetContextGetter.getDetailsbyHeaderId(null);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    // ========================================================================
    // INTEGRATION TESTS
    // ========================================================================

    @isTest
    static void testParentChildAssetHierarchy_Success() {
        // Given: A complete parent-child asset hierarchy
        Asset parentAsset = [
            SELECT Id, (SELECT Id FROM ChildAssets)
            FROM Asset
            WHERE ParentId = null
            AND Id IN (SELECT ParentId FROM Asset WHERE ParentId != null)
            LIMIT 1
        ];

        Set<Id> parentIds = new Set<Id>{parentAsset.Id};
        Set<Id> childIds = new Set<Id>();
        for (Asset child : parentAsset.ChildAssets) {
            childIds.add(child.Id);
        }

        Test.startTest();

        // When: Getting both parent and its children
        Map<Id, Asset> parentResult = AssetContextGetter.getHeaderById(parentIds);
        Map<Id, Asset> childrenByIdResult = AssetContextGetter.getHeaderById(childIds);
        Map<Id, Asset> childrenByParentResult = AssetContextGetter.getDetailsbyHeaderId(parentIds);

        Test.stopTest();

        // Then: All queries return consistent data
        System.assertEquals(1, parentResult.size(), 'One parent should be returned');
        System.assertEquals(childIds.size(), childrenByIdResult.size(),
            'All children should be returned by Id query');
        System.assertEquals(childIds.size(), childrenByParentResult.size(),
            'All children should be returned by parent Id query');

        // Verify child data consistency
        for (Id childId : childIds) {
            System.assert(childrenByIdResult.containsKey(childId),
                'Child should be in getHeaderById result');
            System.assert(childrenByParentResult.containsKey(childId),
                'Child should be in getDetailsbyHeaderId result');
        }
    }

    @isTest
    static void testAssetWithAllFields_Success() {
        // Given: An asset with all fields populated
        Asset testAsset = [SELECT Id FROM Asset LIMIT 1];

        Test.startTest();

        // When: Getting asset
        Map<Id, Asset> result = AssetContextGetter.getHeaderById(new Set<Id>{testAsset.Id});

        Test.stopTest();

        // Then: Asset is returned with all fields
        Asset returnedAsset = result.get(testAsset.Id);
        System.assertNotEquals(null, returnedAsset, 'Asset should be returned');
        System.assertNotEquals(null, returnedAsset.Name, 'Asset name should be populated');
        // Note: Additional field assertions depend on what UniversalQueryUtility returns
    }

    // ========================================================================
    // GOVERNOR LIMIT TESTS
    // ========================================================================

    @isTest
    static void testBulkOperations_WithinGovernorLimits() {
        // Given: All assets in the system
        List<Asset> allAssets = [SELECT Id FROM Asset];
        Set<Id> allAssetIds = new Set<Id>();
        for (Asset ast : allAssets) {
            allAssetIds.add(ast.Id);
        }

        Test.startTest();

        // When: Getting all assets in bulk
        Map<Id, Asset> result = AssetContextGetter.getHeaderById(allAssetIds);

        // Then: Operation completes within governor limits
        Integer queriesUsed = Limits.getQueries();
        System.assert(queriesUsed < Limits.getLimitQueries(), 'Should be within SOQL query limits');

        Test.stopTest();

        // And: All assets are returned
        System.assertEquals(allAssetIds.size(), result.size(), 'All assets should be returned');
    }

    @isTest
    static void testMultipleMethodCalls_PerformanceOptimization() {
        // Given: Parent and child assets
        Asset parentAsset = [SELECT Id FROM Asset WHERE ParentId = null LIMIT 1];
        Asset childAsset = [SELECT Id FROM Asset WHERE ParentId != null LIMIT 1];

        Test.startTest();

        // When: Calling both methods
        Map<Id, Asset> parents = AssetContextGetter.getHeaderById(new Set<Id>{parentAsset.Id});
        Map<Id, Asset> children = AssetContextGetter.getDetailsbyHeaderId(new Set<Id>{parentAsset.Id});

        Test.stopTest();

        // Then: Both queries succeed
        System.assert(parents.size() > 0, 'Parents should be returned');
        System.assertNotEquals(null, children, 'Children query should complete');
    }

    // ========================================================================
    // EDGE CASE TESTS
    // ========================================================================

    @isTest
    static void testMixedValidInvalidIds() {
        // Given: Mix of valid and invalid Ids
        Asset validAsset = [SELECT Id FROM Asset LIMIT 1];
        Id invalidId = '02i000000000000AAA';

        Set<Id> mixedIds = new Set<Id>{validAsset.Id, invalidId};

        Test.startTest();

        // When: Getting assets with mixed Ids
        Map<Id, Asset> result = AssetContextGetter.getHeaderById(mixedIds);

        Test.stopTest();

        // Then: Only valid asset is returned
        System.assertEquals(1, result.size(), 'Only valid asset should be returned');
        System.assert(result.containsKey(validAsset.Id), 'Valid asset should be in result');
        System.assert(!result.containsKey(invalidId), 'Invalid Id should not be in result');
    }

    @isTest
    static void testGetDetailsbyHeaderId_ChildAssetId() {
        // Given: A child asset Id (not a parent)
        Asset childAsset = [SELECT Id FROM Asset WHERE ParentId != null LIMIT 1];
        Set<Id> childIds = new Set<Id>{childAsset.Id};

        Test.startTest();

        // When: Getting details by child asset Id (which is not a parent)
        Map<Id, Asset> result = AssetContextGetter.getDetailsbyHeaderId(childIds);

        Test.stopTest();

        // Then: Empty map is returned (child assets have no children)
        System.assertEquals(0, result.size(), 'Empty map should be returned for child asset with no children');
    }
}
