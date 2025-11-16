/**
 * @description Test class for AccountContextGetter
 *
 * This test class provides comprehensive coverage for the AccountContextGetter
 * data access layer, testing all account query methods.
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class AccountContextGetterTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    @testSetup
    static void setupTestData() {
        // Create client accounts
        List<Account> clientAccounts = TestDataFactoryRefactored.createAccounts(3, 'Client', 'Client');
        insert clientAccounts;

        // Create location accounts under first client
        List<Account> locationAccounts = TestDataFactoryRefactored.createAccounts(5, 'Location', 'Location');
        for (Account loc : locationAccounts) {
            loc.ParentId = clientAccounts[0].Id;
        }
        insert locationAccounts;

        // Create additional location accounts under second client
        List<Account> moreLocations = TestDataFactoryRefactored.createAccounts(3, 'Location', 'Location');
        for (Account loc : moreLocations) {
            loc.ParentId = clientAccounts[1].Id;
        }
        insert moreLocations;
    }

    // ========================================================================
    // GET CLIENT BY ID TESTS
    // ========================================================================

    @isTest
    static void testGetClientById_SingleClient_Success() {
        // Given: A client account exists
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Client' LIMIT 1];
        Set<Id> clientIds = new Set<Id>{clientAccount.Id};

        Test.startTest();

        // When: Getting client by Id
        Map<Id, Account> result = AccountContextGetter.getClientById(clientIds);

        Test.stopTest();

        // Then: Client is returned
        System.assertEquals(1, result.size(), 'One client should be returned');
        System.assert(result.containsKey(clientAccount.Id), 'Result should contain client Id');
        System.assertNotEquals(null, result.get(clientAccount.Id), 'Client account should not be null');
    }

    @isTest
    static void testGetClientById_MultipleClients_Success() {
        // Given: Multiple client accounts exist
        List<Account> clientAccounts = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Client' LIMIT 3];
        Set<Id> clientIds = new Set<Id>();
        for (Account acc : clientAccounts) {
            clientIds.add(acc.Id);
        }

        Test.startTest();

        // When: Getting multiple clients
        Map<Id, Account> result = AccountContextGetter.getClientById(clientIds);

        Test.stopTest();

        // Then: All clients are returned
        System.assertEquals(clientIds.size(), result.size(), 'All clients should be returned');
        for (Id clientId : clientIds) {
            System.assert(result.containsKey(clientId), 'Result should contain client Id: ' + clientId);
        }
    }

    @isTest
    static void testGetClientById_EmptySet() {
        Test.startTest();

        // When: Getting clients with empty set
        Map<Id, Account> result = AccountContextGetter.getClientById(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetClientById_NullSet() {
        Test.startTest();

        // When: Getting clients with null set
        Map<Id, Account> result = AccountContextGetter.getClientById(null);

        Test.stopTest();

        // Then: Empty map is returned (method should handle gracefully)
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetClientById_NonExistentId() {
        // Given: A non-existent account Id
        Id fakeId = '001000000000000AAA';
        Set<Id> clientIds = new Set<Id>{fakeId};

        Test.startTest();

        // When: Getting client with non-existent Id
        Map<Id, Account> result = AccountContextGetter.getClientById(clientIds);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, result.size(), 'Empty map should be returned for non-existent Id');
    }

    // ========================================================================
    // GET LOCATION BY ID TESTS
    // ========================================================================

    @isTest
    static void testGetLocationById_SingleLocation_Success() {
        // Given: A location account exists
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Location' LIMIT 1];
        Set<Id> locationIds = new Set<Id>{locationAccount.Id};

        Test.startTest();

        // When: Getting location by Id
        Map<Id, Account> result = AccountContextGetter.getLocationById(locationIds);

        Test.stopTest();

        // Then: Location is returned
        System.assertEquals(1, result.size(), 'One location should be returned');
        System.assert(result.containsKey(locationAccount.Id), 'Result should contain location Id');
        System.assertNotEquals(null, result.get(locationAccount.Id), 'Location account should not be null');
    }

    @isTest
    static void testGetLocationById_MultipleLocations_Success() {
        // Given: Multiple location accounts exist
        List<Account> locationAccounts = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Location' LIMIT 5];
        Set<Id> locationIds = new Set<Id>();
        for (Account acc : locationAccounts) {
            locationIds.add(acc.Id);
        }

        Test.startTest();

        // When: Getting multiple locations
        Map<Id, Account> result = AccountContextGetter.getLocationById(locationIds);

        Test.stopTest();

        // Then: All locations are returned
        System.assertEquals(locationIds.size(), result.size(), 'All locations should be returned');
        for (Id locationId : locationIds) {
            System.assert(result.containsKey(locationId), 'Result should contain location Id: ' + locationId);
        }
    }

    @isTest
    static void testGetLocationById_EmptySet() {
        Test.startTest();

        // When: Getting locations with empty set
        Map<Id, Account> result = AccountContextGetter.getLocationById(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    // ========================================================================
    // GET LOCATIONS BY CLIENT ID TESTS
    // ========================================================================

    @isTest
    static void testGetLocationsByClientId_SingleClient_Success() {
        // Given: A client with multiple locations
        Account clientAccount = [
            SELECT Id, (SELECT Id FROM ChildAccounts WHERE RecordType.DeveloperName = 'Location')
            FROM Account
            WHERE RecordType.DeveloperName = 'Client'
            AND Id IN (SELECT ParentId FROM Account WHERE RecordType.DeveloperName = 'Location')
            LIMIT 1
        ];

        Integer expectedLocationCount = clientAccount.ChildAccounts.size();
        Set<Id> clientIds = new Set<Id>{clientAccount.Id};

        Test.startTest();

        // When: Getting locations by client Id
        Map<Id, Account> result = AccountContextGetter.getLocationsByClientId(clientIds);

        Test.stopTest();

        // Then: All child locations are returned
        System.assertEquals(expectedLocationCount, result.size(),
            'All child locations should be returned');

        // Verify all returned accounts are locations under this client
        for (Account loc : result.values()) {
            System.assertEquals(clientAccount.Id, loc.ParentId,
                'Location should be child of client');
        }
    }

    @isTest
    static void testGetLocationsByClientId_MultipleClients_Success() {
        // Given: Multiple clients with locations
        List<Account> clientAccounts = [
            SELECT Id, (SELECT Id FROM ChildAccounts WHERE RecordType.DeveloperName = 'Location')
            FROM Account
            WHERE RecordType.DeveloperName = 'Client'
            AND Id IN (SELECT ParentId FROM Account WHERE RecordType.DeveloperName = 'Location')
            LIMIT 2
        ];

        Set<Id> clientIds = new Set<Id>();
        Integer totalExpectedLocations = 0;

        for (Account client : clientAccounts) {
            clientIds.add(client.Id);
            totalExpectedLocations += client.ChildAccounts.size();
        }

        Test.startTest();

        // When: Getting locations by multiple client Ids
        Map<Id, Account> result = AccountContextGetter.getLocationsByClientId(clientIds);

        Test.stopTest();

        // Then: All child locations from all clients are returned
        System.assertEquals(totalExpectedLocations, result.size(),
            'All child locations from all clients should be returned');

        // Verify all returned accounts have one of the client Ids as parent
        for (Account loc : result.values()) {
            System.assert(clientIds.contains(loc.ParentId),
                'Location parent should be one of the requested clients');
        }
    }

    @isTest
    static void testGetLocationsByClientId_ClientWithNoLocations() {
        // Given: A client without any locations
        Account clientWithoutLocations = [
            SELECT Id
            FROM Account
            WHERE RecordType.DeveloperName = 'Client'
            AND Id NOT IN (SELECT ParentId FROM Account WHERE RecordType.DeveloperName = 'Location')
            LIMIT 1
        ];

        Set<Id> clientIds = new Set<Id>{clientWithoutLocations.Id};

        Test.startTest();

        // When: Getting locations by client Id with no locations
        Map<Id, Account> result = AccountContextGetter.getLocationsByClientId(clientIds);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, result.size(), 'Empty map should be returned for client with no locations');
    }

    @isTest
    static void testGetLocationsByClientId_EmptySet() {
        Test.startTest();

        // When: Getting locations with empty client set
        Map<Id, Account> result = AccountContextGetter.getLocationsByClientId(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetLocationsByClientId_NullSet() {
        Test.startTest();

        // When: Getting locations with null client set
        Map<Id, Account> result = AccountContextGetter.getLocationsByClientId(null);

        Test.stopTest();

        // Then: Empty map is returned (method should handle gracefully)
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    // ========================================================================
    // INTEGRATION TESTS
    // ========================================================================

    @isTest
    static void testFullClientLocationHierarchy_Success() {
        // Given: A complete client-location hierarchy
        Account clientAccount = [
            SELECT Id, (SELECT Id FROM ChildAccounts WHERE RecordType.DeveloperName = 'Location')
            FROM Account
            WHERE RecordType.DeveloperName = 'Client'
            AND Id IN (SELECT ParentId FROM Account WHERE RecordType.DeveloperName = 'Location')
            LIMIT 1
        ];

        Set<Id> clientIds = new Set<Id>{clientAccount.Id};
        Set<Id> locationIds = new Set<Id>();
        for (Account loc : clientAccount.ChildAccounts) {
            locationIds.add(loc.Id);
        }

        Test.startTest();

        // When: Getting both client and its locations
        Map<Id, Account> clientResult = AccountContextGetter.getClientById(clientIds);
        Map<Id, Account> locationsByIdResult = AccountContextGetter.getLocationById(locationIds);
        Map<Id, Account> locationsByClientResult = AccountContextGetter.getLocationsByClientId(clientIds);

        Test.stopTest();

        // Then: All queries return consistent data
        System.assertEquals(1, clientResult.size(), 'One client should be returned');
        System.assertEquals(locationIds.size(), locationsByIdResult.size(),
            'All locations should be returned by Id query');
        System.assertEquals(locationIds.size(), locationsByClientResult.size(),
            'All locations should be returned by client Id query');

        // Verify location data consistency
        for (Id locId : locationIds) {
            System.assert(locationsByIdResult.containsKey(locId),
                'Location should be in getLocationById result');
            System.assert(locationsByClientResult.containsKey(locId),
                'Location should be in getLocationsByClientId result');
        }
    }

    // ========================================================================
    // GOVERNOR LIMIT TESTS
    // ========================================================================

    @isTest
    static void testBulkOperations_WithinGovernorLimits() {
        // Given: All accounts in the system
        List<Account> allAccounts = [SELECT Id FROM Account];
        Set<Id> allAccountIds = new Set<Id>();
        for (Account acc : allAccounts) {
            allAccountIds.add(acc.Id);
        }

        Test.startTest();

        // When: Getting all accounts in bulk
        Map<Id, Account> result = AccountContextGetter.getClientById(allAccountIds);

        // Then: Operation completes within governor limits
        Integer queriesUsed = Limits.getQueries();
        System.assert(queriesUsed < Limits.getLimitQueries(), 'Should be within SOQL query limits');

        Test.stopTest();

        // And: All accounts are returned
        System.assertEquals(allAccountIds.size(), result.size(), 'All accounts should be returned');
    }

    @isTest
    static void testMultipleMethodCalls_PerformanceOptimization() {
        // Given: Client and location accounts
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Client' LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Location' LIMIT 1];

        Test.startTest();

        // When: Calling all methods
        Map<Id, Account> clients = AccountContextGetter.getClientById(new Set<Id>{clientAccount.Id});
        Map<Id, Account> locations = AccountContextGetter.getLocationById(new Set<Id>{locationAccount.Id});
        Map<Id, Account> locationsByClient = AccountContextGetter.getLocationsByClientId(new Set<Id>{clientAccount.Id});

        Test.stopTest();

        // Then: All queries succeed
        System.assert(clients.size() > 0, 'Clients should be returned');
        System.assert(locations.size() > 0, 'Locations should be returned');
        System.assertNotEquals(null, locationsByClient, 'Locations by client should be returned');
    }
}
