/**
 * @author Waste Management
 * @date 2025
 *
 * @group Cases
 * @group-content ../../ApexDocContent/Cases.htm
 *
 * @description Test class for CaseTriggerContext
 *
 * WHAT THIS TESTS:
 * - Context building from cases
 * - Data retrieval methods
 * - Test data injection
 * - Null safety
 * - Bulk data handling
 */
@IsTest
private class CaseTriggerContextTest {

    // ========================================================================
    // TEST DATA SETUP
    // ========================================================================

    @TestSetup
    static void setupTestData() {
        // Create test accounts (locations)
        Account location1 = new Account(
            Name = 'Test Location 1',
            BillingCity = 'Chicago',
            BillingState = 'IL',
            BillingPostalCode = '60601',
            TimeZone__c = 'America/Chicago'
        );
        Account location2 = new Account(
            Name = 'Test Location 2',
            BillingCity = 'New York',
            BillingState = 'NY',
            BillingPostalCode = '10001',
            TimeZone__c = 'America/New_York'
        );
        insert new List<Account>{ location1, location2 };

        // Create test contacts
        Contact contact1 = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@test.com',
            AccountId = location1.Id
        );
        insert contact1;

        // Create test assets
        Asset asset1 = new Asset(
            Name = 'Test Asset 1',
            AccountId = location1.Id,
            Service__c = 'Commercial',
            Haul_Frequency__c = 'Weekly'
        );
        Asset asset2 = new Asset(
            Name = 'Test Asset 2',
            AccountId = location2.Id,
            Service__c = 'Rolloff',
            Haul_Frequency__c = 'On-Call'
        );
        insert new List<Asset>{ asset1, asset2 };

        // Create test cases
        Case case1 = new Case(
            Subject = 'Test Case 1',
            Status = 'New',
            Origin = 'Phone',
            Location__c = location1.Id,
            AssetId = asset1.Id,
            ContactId = contact1.Id
        );
        Case case2 = new Case(
            Subject = 'Test Case 2',
            Status = 'New',
            Origin = 'Email',
            Location__c = location2.Id,
            AssetId = asset2.Id
        );
        insert new List<Case>{ case1, case2 };
    }

    // ========================================================================
    // CONSTRUCTOR & BUILDER TESTS
    // ========================================================================

    @IsTest
    static void testBuildFromCases_WithRelatedData() {
        // Arrange
        List<Case> cases = [
            SELECT Id, Subject, AssetId, Location__c, ContactId, ParentId
            FROM Case
            LIMIT 2
        ];

        // Act
        Test.startTest();
        CaseTriggerContext context = CaseTriggerContext.buildFromCases(cases);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, context, 'Context should be created');

        // Verify assets were queried
        Asset asset = context.getAssetById(cases[0].AssetId);
        System.assertNotEquals(null, asset, 'Asset should be loaded');
        System.assertEquals('Test Asset 1', asset.Name, 'Asset name should match');

        // Verify locations were queried
        Account location = context.getLocation(cases[0].Location__c);
        System.assertNotEquals(null, location, 'Location should be loaded');
        System.assertEquals('Test Location 1', location.Name, 'Location name should match');

        // Verify contacts were queried
        Contact contact = context.getContact(cases[0].ContactId);
        System.assertNotEquals(null, contact, 'Contact should be loaded');
        System.assertEquals('Doe', contact.LastName, 'Contact last name should match');
    }

    @IsTest
    static void testBuildFromCases_WithEmptyList() {
        // Arrange
        List<Case> emptyCases = new List<Case>();

        // Act
        Test.startTest();
        CaseTriggerContext context = CaseTriggerContext.buildFromCases(emptyCases);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, context, 'Context should be created even with empty list');
        System.assertEquals(0, context.getAllAssets().size(), 'Assets map should be empty');
        System.assertEquals(0, context.getAllLocations().size(), 'Locations map should be empty');
    }

    @IsTest
    static void testBuildFromCases_WithNullFields() {
        // Arrange
        Case caseWithNulls = new Case(
            Subject = 'Test Case - No Related Data',
            Status = 'New',
            Origin = 'Phone'
        );
        insert caseWithNulls;

        List<Case> cases = [SELECT Id, AssetId, Location__c, ContactId FROM Case WHERE Id = :caseWithNulls.Id];

        // Act
        Test.startTest();
        CaseTriggerContext context = CaseTriggerContext.buildFromCases(cases);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, context, 'Context should handle null fields');
        System.assertNull(context.getAssetById(null), 'Null asset ID should return null');
        System.assertNull(context.getLocation(null), 'Null location ID should return null');
    }

    @IsTest
    static void testCreateEmptyContext() {
        // Act
        Test.startTest();
        CaseTriggerContext context = CaseTriggerContext.createEmptyContext();
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, context, 'Empty context should be created');
        System.assertEquals(0, context.getAllAssets().size(), 'Assets should be empty');
        System.assertEquals(0, context.getAllLocations().size(), 'Locations should be empty');
    }

    // ========================================================================
    // GETTER METHOD TESTS
    // ========================================================================

    @IsTest
    static void testGetAssetById() {
        // Arrange
        Asset testAsset = [SELECT Id, Name FROM Asset LIMIT 1];
        CaseTriggerContext context = CaseTriggerContext.createEmptyContext();
        context.setAssetByContainerId(testAsset.Id, testAsset);

        // Act
        Test.startTest();
        Asset retrieved = context.getAssetById(testAsset.Id);
        Test.stopTest();

        // Assert
        System.assertEquals(testAsset.Id, retrieved.Id, 'Should retrieve correct asset');
        System.assertEquals(testAsset.Name, retrieved.Name, 'Asset name should match');
    }

    @IsTest
    static void testGetLocation() {
        // Arrange
        Account testLocation = [SELECT Id, Name FROM Account LIMIT 1];
        CaseTriggerContext context = CaseTriggerContext.createEmptyContext();
        context.setLocation(testLocation.Id, testLocation);

        // Act
        Test.startTest();
        Account retrieved = context.getLocation(testLocation.Id);
        Test.stopTest();

        // Assert
        System.assertEquals(testLocation.Id, retrieved.Id, 'Should retrieve correct location');
        System.assertEquals(testLocation.Name, retrieved.Name, 'Location name should match');
    }

    @IsTest
    static void testGetContact() {
        // Arrange
        Contact testContact = [SELECT Id, LastName FROM Contact LIMIT 1];
        CaseTriggerContext context = CaseTriggerContext.createEmptyContext();
        context.setContact(testContact.Id, testContact);

        // Act
        Test.startTest();
        Contact retrieved = context.getContact(testContact.Id);
        Test.stopTest();

        // Assert
        System.assertEquals(testContact.Id, retrieved.Id, 'Should retrieve correct contact');
        System.assertEquals(testContact.LastName, retrieved.LastName, 'Contact last name should match');
    }

    @IsTest
    static void testGetBusinessHoursId() {
        // Arrange
        CaseTriggerContext context = CaseTriggerContext.createEmptyContext();
        Id testBusinessHoursId = UserInfo.getOrganizationId(); // Use any valid ID for test
        context.setBusinessHoursId('America/Chicago', testBusinessHoursId);

        // Act
        Test.startTest();
        Id retrieved = context.getBusinessHoursId('America/Chicago');
        Test.stopTest();

        // Assert
        System.assertEquals(testBusinessHoursId, retrieved, 'Should retrieve correct business hours ID');
    }

    @IsTest
    static void testGetRecordTypeIds() {
        // Arrange
        CaseTriggerContext context = CaseTriggerContext.createEmptyContext();
        Id integrationRt = UserInfo.getOrganizationId();
        Id pickupRt = UserInfo.getUserId();
        Id newServiceRt = UserInfo.getProfileId();
        context.setRecordTypeIds(integrationRt, pickupRt, newServiceRt);

        // Act
        Test.startTest();
        Id retrievedIntegration = context.getIntegrationRecordTypeId();
        Id retrievedPickup = context.getPickupRecordTypeId();
        Id retrievedNewService = context.getNewServiceRecordTypeId();
        Test.stopTest();

        // Assert
        System.assertEquals(integrationRt, retrievedIntegration, 'Integration RT should match');
        System.assertEquals(pickupRt, retrievedPickup, 'Pickup RT should match');
        System.assertEquals(newServiceRt, retrievedNewService, 'New Service RT should match');
    }

    @IsTest
    static void testGetCorporateServiceQueueId() {
        // Arrange
        CaseTriggerContext context = CaseTriggerContext.createEmptyContext();
        Id queueId = UserInfo.getOrganizationId(); // Use any valid ID for test
        context.setCorporateServiceQueueId(queueId);

        // Act
        Test.startTest();
        Id retrieved = context.getCorporateServiceQueueId();
        Test.stopTest();

        // Assert
        System.assertEquals(queueId, retrieved, 'Queue ID should match');
    }

    // ========================================================================
    // BULK DATA TESTS
    // ========================================================================

    @IsTest
    static void testGetAllAssets() {
        // Arrange
        List<Asset> testAssets = [SELECT Id, Name FROM Asset];
        CaseTriggerContext context = CaseTriggerContext.createEmptyContext();
        for (Asset asset : testAssets) {
            context.setAssetByContainerId(asset.Id, asset);
        }

        // Act
        Test.startTest();
        Map<Id, Asset> allAssets = context.getAllAssets();
        Test.stopTest();

        // Assert
        System.assertEquals(testAssets.size(), allAssets.size(), 'Should return all assets');
    }

    @IsTest
    static void testGetAllLocations() {
        // Arrange
        List<Account> testLocations = [SELECT Id, Name FROM Account];
        CaseTriggerContext context = CaseTriggerContext.createEmptyContext();
        for (Account location : testLocations) {
            context.setLocation(location.Id, location);
        }

        // Act
        Test.startTest();
        Map<Id, Account> allLocations = context.getAllLocations();
        Test.stopTest();

        // Assert
        System.assertEquals(testLocations.size(), allLocations.size(), 'Should return all locations');
    }

    // ========================================================================
    // EDGE CASE TESTS
    // ========================================================================

    @IsTest
    static void testContextIsImmutableForCaller() {
        // Arrange
        List<Case> cases = [SELECT Id, AssetId FROM Case LIMIT 1];
        CaseTriggerContext context = CaseTriggerContext.buildFromCases(cases);

        // Act - Get assets map and try to modify it
        Test.startTest();
        Map<Id, Asset> assetsMap = context.getAllAssets();
        Integer originalSize = assetsMap.size();
        assetsMap.clear(); // Try to clear the map
        Test.stopTest();

        // Assert - Original context should be unaffected
        Map<Id, Asset> assetsMapAfter = context.getAllAssets();
        System.assertEquals(originalSize, assetsMapAfter.size(),
            'Context should return new map instance, protecting internal state');
    }

    @IsTest
    static void testWorkOrderCountTracking() {
        // Arrange
        CaseTriggerContext context = CaseTriggerContext.createEmptyContext();
        String trackingNumber = 'TRK-12345';
        Integer count = 5;

        // Act
        Test.startTest();
        context.setWorkOrderCount(trackingNumber, count);
        Integer retrieved = context.getWorkOrderCount(trackingNumber);
        Test.stopTest();

        // Assert
        System.assertEquals(count, retrieved, 'Work order count should match');
    }

    @IsTest
    static void testMultipleCasesWithSameLocation() {
        // Arrange
        Account sharedLocation = [SELECT Id FROM Account LIMIT 1];
        Case case1 = new Case(
            Subject = 'Case 1',
            Status = 'New',
            Location__c = sharedLocation.Id
        );
        Case case2 = new Case(
            Subject = 'Case 2',
            Status = 'New',
            Location__c = sharedLocation.Id
        );
        insert new List<Case>{ case1, case2 };

        List<Case> cases = [SELECT Id, Location__c FROM Case WHERE Id IN (:case1.Id, :case2.Id)];

        // Act
        Test.startTest();
        CaseTriggerContext context = CaseTriggerContext.buildFromCases(cases);
        Test.stopTest();

        // Assert
        System.assertEquals(1, context.getAllLocations().size(),
            'Should only query shared location once');
        Account location = context.getLocation(sharedLocation.Id);
        System.assertNotEquals(null, location, 'Shared location should be available');
    }
}
