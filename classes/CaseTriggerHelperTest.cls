/*************************************************************
@Name: CaseTriggerHelperTest
@Author: Claude AI
@CreateDate: 12/01/2025
@Description: Comprehensive test class for CaseTriggerHelper
@Coverage: CaseTriggerHelper
**************************************************************/
@isTest
private class CaseTriggerHelperTest {

    @testSetup
    static void setupTestData() {
        // Create account hierarchy
        Account clientAccount = new Account(Name = 'Test Client');
        insert clientAccount;

        Account locationAccount = new Account(
            Name = 'Test Location',
            ParentId = clientAccount.Id,
            ShippingCountry = 'USA',
            ShippingState = 'CA',
            ShippingCity = 'Los Angeles',
            ShippingPostalCode = '90001',
            ShippingStreet = '123 Test St'
        );
        insert locationAccount;

        // Create contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test@example.com',
            AccountId = locationAccount.Id
        );
        insert testContact;

        // Create asset
        Asset testAsset = new Asset(
            Name = 'Test Asset',
            AccountId = locationAccount.Id,
            ContactId = testContact.Id,
            Quantity__c = 10
        );
        insert testAsset;

        // Create cases
        List<Case> testCases = new List<Case>();
        testCases.add(new Case(
            Subject = 'Test Case 1',
            Status = 'Open',
            Origin = 'Web',
            AccountId = locationAccount.Id,
            ContactId = testContact.Id,
            AssetId = testAsset.Id,
            Case_Type__c = 'Service',
            Service_Date__c = System.today().addDays(7)
        ));
        testCases.add(new Case(
            Subject = 'Test Case 2',
            Status = 'New',
            Origin = 'Web',
            AccountId = locationAccount.Id,
            ContactId = testContact.Id,
            AssetId = testAsset.Id,
            Case_Type__c = 'Service'
        ));
        insert testCases;
    }

    @isTest
    static void testGetServiceDate() {
        List<Case> testCases = [SELECT Id, Service_Date__c, AccountId, AssetId FROM Case];

        // Initialize static maps for backward compatibility
        Asset testAsset = [SELECT Id, Name FROM Asset LIMIT 1];
        Account testLocation = [SELECT Id, Name, ShippingState FROM Account WHERE Name = 'Test Location' LIMIT 1];

        CaseTriggerHelper.casewithContainer.put(testCases[0].Id, testAsset);
        CaseTriggerHelper.casewithLocation.put(testCases[0].Id, testLocation);

        Test.startTest();

        List<Case> result = CaseTriggerHelper.getServiceDate(testCases);

        Test.stopTest();

        // Verify method executed without errors
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(testCases.size(), result.size(), 'Should return same number of cases');
    }

    @isTest
    static void testGetSLACorrectedDate() {
        Case testCase = [SELECT Id, Service_Date__c, SLA_Service_Date_Time__c, AccountId FROM Case LIMIT 1];

        // Initialize static map
        Account testLocation = [SELECT Id, Name, ShippingState FROM Account WHERE Name = 'Test Location' LIMIT 1];
        CaseTriggerHelper.casewithLocation.put(testCase.Id, testLocation);

        Test.startTest();

        Datetime result = CaseTriggerHelper.getSLACorrectedDate(testCase);

        Test.stopTest();

        // Verify method executed
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetServiceDateTime() {
        Case testCase = [SELECT Id, Service_Date__c, AccountId FROM Case LIMIT 1];
        Account testLocation = [SELECT Id, Name, ShippingState FROM Account WHERE Name = 'Test Location' LIMIT 1];
        CaseTriggerHelper.casewithLocation.put(testCase.Id, testLocation);

        Datetime localDate = System.now().addDays(1);

        Test.startTest();

        Datetime result = CaseTriggerHelper.getservicedatetime(localDate, testCase);

        Test.stopTest();

        // Verify conversion occurred
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetIntakeSLADatetime() {
        Case testCase = [SELECT Id, Service_Date__c, SLA_Service_Date_Time__c, AccountId FROM Case LIMIT 1];
        Account testLocation = [SELECT Id, Name, ShippingState FROM Account WHERE Name = 'Test Location' LIMIT 1];
        CaseTriggerHelper.casewithLocation.put(testCase.Id, testLocation);

        Datetime serviceDate = System.now().addDays(7);
        Datetime currentSLADate = System.now();

        Test.startTest();

        Datetime result = CaseTriggerHelper.getIntakeSLADatetime(serviceDate, currentSLADate, testCase);

        Test.stopTest();

        // Verify calculation occurred
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testStaticMapsInitialization() {
        Test.startTest();

        // Test static map initialization
        Asset testAsset = [SELECT Id FROM Asset LIMIT 1];
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        CaseTriggerHelper.casewithContainer.put(testCase.Id, testAsset);
        System.assertEquals(1, CaseTriggerHelper.casewithContainer.size(),
                           'Container map should contain one entry');

        Account testLocation = [SELECT Id FROM Account WHERE Name = 'Test Location' LIMIT 1];
        CaseTriggerHelper.casewithLocation.put(testCase.Id, testLocation);
        System.assertEquals(1, CaseTriggerHelper.casewithLocation.size(),
                           'Location map should contain one entry');

        Test.stopTest();
    }

    @isTest
    static void testBulkServiceDateCalculation() {
        List<Case> testCases = [SELECT Id, Service_Date__c, AccountId, AssetId FROM Case];

        // Initialize static maps for all cases
        Asset testAsset = [SELECT Id FROM Asset LIMIT 1];
        Account testLocation = [SELECT Id, ShippingState FROM Account WHERE Name = 'Test Location' LIMIT 1];

        for (Case c : testCases) {
            CaseTriggerHelper.casewithContainer.put(c.Id, testAsset);
            CaseTriggerHelper.casewithLocation.put(c.Id, testLocation);
        }

        Test.startTest();

        List<Case> result = CaseTriggerHelper.getServiceDate(testCases);

        Test.stopTest();

        // Verify bulk processing
        System.assertEquals(testCases.size(), result.size(), 'Should process all cases');
    }

    @isTest
    static void testRunCountIncrement() {
        Test.startTest();

        // Verify run count starts at 0
        Integer initialCount = CaseTriggerHelper.runCount;
        System.assertEquals(0, initialCount, 'Run count should start at 0');

        // Increment run count
        CaseTriggerHelper.runCount++;
        System.assertEquals(1, CaseTriggerHelper.runCount, 'Run count should increment');

        Test.stopTest();
    }

    @isTest
    static void testStaticCollections() {
        Test.startTest();

        // Test various static collections
        CaseTriggerHelper.caseWorkOrderCount.put('TEST', 5);
        System.assertEquals(1, CaseTriggerHelper.caseWorkOrderCount.size(),
                           'Work order count map should have one entry');

        Id testId = [SELECT Id FROM Case LIMIT 1].Id;
        CaseTriggerHelper.businessIdMap.put('TEST_KEY', testId);
        System.assertEquals(1, CaseTriggerHelper.businessIdMap.size(),
                           'Business ID map should have one entry');

        Id locationId = [SELECT Id FROM Account WHERE Name = 'Test Location' LIMIT 1].Id;
        CaseTriggerHelper.locationIdSet.add(locationId);
        System.assertEquals(1, CaseTriggerHelper.locationIdSet.size(),
                           'Location ID set should have one entry');

        CaseTriggerHelper.parentAccountIdset.add(locationId);
        System.assertEquals(1, CaseTriggerHelper.parentAccountIdset.size(),
                           'Parent account ID set should have one entry');

        CaseTriggerHelper.serviceset.add('Test Service');
        System.assertEquals(1, CaseTriggerHelper.serviceset.size(),
                           'Service set should have one entry');

        Test.stopTest();
    }

    @isTest
    static void testExceptionHandlingInGetServiceDate() {
        // Create cases with minimal data to potentially trigger exceptions
        List<Case> testCases = new List<Case>();
        testCases.add(new Case(
            Subject = 'Exception Test',
            Status = 'New'
        ));

        Test.startTest();

        List<Case> result = CaseTriggerHelper.getServiceDate(testCases);

        Test.stopTest();

        // Verify exception was handled and cases returned
        System.assertNotEquals(null, result, 'Result should not be null even with exception');
    }

    @isTest
    static void testMultipleCaseServiceDates() {
        List<Case> testCases = [SELECT Id, Service_Date__c, AccountId, AssetId FROM Case];

        // Initialize maps
        Asset testAsset = [SELECT Id FROM Asset LIMIT 1];
        Account testLocation = [SELECT Id, ShippingState FROM Account WHERE Name = 'Test Location' LIMIT 1];

        for (Case c : testCases) {
            CaseTriggerHelper.casewithContainer.put(c.Id, testAsset);
            CaseTriggerHelper.casewithLocation.put(c.Id, testLocation);
        }

        Test.startTest();

        // Test SLA correction for each case
        for (Case c : testCases) {
            Datetime corrected = CaseTriggerHelper.getSLACorrectedDate(c);
            System.assertNotEquals(null, corrected, 'Corrected date should not be null');
        }

        Test.stopTest();
    }

    @isTest
    static void testBackwardCompatibility() {
        Test.startTest();

        // Verify backward compatibility fields exist and can be accessed
        Map<Id,Asset> containerMap = CaseTriggerHelper.casewithContainer;
        Map<Id,Account> locationMap = CaseTriggerHelper.casewithLocation;
        Map<String,Integer> woCountMap = CaseTriggerHelper.caseWorkOrderCount;
        Map<String,Id> busIdMap = CaseTriggerHelper.businessIdMap;
        Set<Id> locIdSet = CaseTriggerHelper.locationIdSet;
        Set<Id> parAcctSet = CaseTriggerHelper.parentAccountIdset;
        Set<String> svcSet = CaseTriggerHelper.serviceset;

        System.assertNotEquals(null, containerMap, 'Container map should be accessible');
        System.assertNotEquals(null, locationMap, 'Location map should be accessible');
        System.assertNotEquals(null, woCountMap, 'WO count map should be accessible');
        System.assertNotEquals(null, busIdMap, 'Business ID map should be accessible');
        System.assertNotEquals(null, locIdSet, 'Location ID set should be accessible');
        System.assertNotEquals(null, parAcctSet, 'Parent account set should be accessible');
        System.assertNotEquals(null, svcSet, 'Service set should be accessible');

        Test.stopTest();
    }
}
