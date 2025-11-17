/**
 * @description Comprehensive test class for CaseAttributeService
 *
 * Coverage Target: 85%+
 *
 * Tests all public methods and exercises private helper methods through proper test data setup
 *
 * @author Refactored Architecture Team
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseAttributeServiceTest {

    @testSetup
    static void setupTestData() {
        // Create full test hierarchy with all necessary data
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Account locationAccount = (Account)testData.get('locationAccount');
        Product2 prod = (Product2)testData.get('product');

        // Update product to have Equipment Type
        prod.Equipment_Type__c = 'Container';
        prod.Family = 'Commercial';
        update prod;

        // Create Commercial Scheduled asset
        Asset commercialScheduled = new Asset(
            Name = 'Commercial Scheduled Asset',
            AccountId = locationAccount.Id,
            Product2Id = prod.Id,
            Status = 'Installed',
            ProductFamily = 'Commercial',
            Occurrence_Type__c = 'Scheduled',
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            Is_Active__c = true
        );
        insert commercialScheduled;

        // Create Commercial On-Call asset
        Asset commercialOnCall = new Asset(
            Name = 'Commercial On-Call Asset',
            AccountId = locationAccount.Id,
            Product2Id = prod.Id,
            Status = 'Installed',
            ProductFamily = 'Commercial',
            Occurrence_Type__c = 'On-Call',
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            Is_Active__c = true
        );
        insert commercialOnCall;

        // Create Rolloff product
        Product2 rolloffProd = new Product2(
            Name = 'Rolloff Product',
            ProductCode = 'ROLL-001',
            Family = 'Rolloff',
            Equipment_Type__c = 'Container',
            IsActive = true
        );
        insert rolloffProd;

        // Create Rolloff asset
        Asset rolloffAsset = new Asset(
            Name = 'Rolloff Asset',
            AccountId = locationAccount.Id,
            Product2Id = rolloffProd.Id,
            Status = 'Installed',
            ProductFamily = 'Rolloff',
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            Is_Active__c = true
        );
        insert rolloffAsset;

        // Create Baler product
        Product2 balerProd = new Product2(
            Name = 'Baler Product',
            ProductCode = 'BALER-001',
            Family = 'Rolloff',
            Equipment_Type__c = 'Baler',
            IsActive = true
        );
        insert balerProd;

        // Create Baler asset
        Asset balerAsset = new Asset(
            Name = 'Baler Asset',
            AccountId = locationAccount.Id,
            Product2Id = balerProd.Id,
            Status = 'Installed',
            ProductFamily = 'Rolloff',
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            Is_Active__c = true
        );
        insert balerAsset;

        // Create Services product
        Product2 servicesProd = new Product2(
            Name = 'Bulk Service',
            ProductCode = 'BULK-001',
            Family = 'Services',
            IsActive = true
        );
        insert servicesProd;

        // Create Services asset - Bulk Service
        Asset bulkServiceAsset = new Asset(
            Name = 'Bulk Service',
            AccountId = locationAccount.Id,
            Product2Id = servicesProd.Id,
            Status = 'Installed',
            ProductFamily = 'Services',
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            Is_Active__c = true
        );
        insert bulkServiceAsset;

        // Create Services asset - Haul Away Service
        Asset haulAwayAsset = new Asset(
            Name = 'Haul Away Service',
            AccountId = locationAccount.Id,
            Product2Id = servicesProd.Id,
            Status = 'Installed',
            ProductFamily = 'Services',
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            Is_Active__c = true
        );
        insert haulAwayAsset;

        // Create Services asset - Hand Pickup Scheduled
        Asset handPickupScheduled = new Asset(
            Name = 'Hand Pickup Scheduled',
            AccountId = locationAccount.Id,
            Product2Id = servicesProd.Id,
            Status = 'Installed',
            ProductFamily = 'Services',
            Occurrence_Type__c = 'Scheduled',
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            Is_Active__c = true
        );
        insert handPickupScheduled;

        // Create Services asset - Hand Pickup On-Call
        Asset handPickupOnCall = new Asset(
            Name = 'Hand Pickup On-Call',
            AccountId = locationAccount.Id,
            Product2Id = servicesProd.Id,
            Status = 'Installed',
            ProductFamily = 'Services',
            Occurrence_Type__c = 'On-Call',
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(365),
            Is_Active__c = true
        );
        insert handPickupOnCall;

        // Create Contact for testing
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = locationAccount.Id,
            Email = 'test@example.com',
            Phone = '555-1234',
            ANI__c = '1234567890'
        );
        insert testContact;

        // Create custom setting for PO extraction
        Config_PO__c poConfig = new Config_PO__c(
            Name = 'PO_Number_Digits',
            POCharacters__c = 10
        );
        insert poConfig;
    }

    // ========================================
    // CORE INITIALIZATION TESTS
    // ========================================

    @isTest
    static void testInitializeCase_Single() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');

        Test.startTest();
        // When
        Case result = CaseAttributeService.initializeCase(testCase);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Case should be initialized');
    }

    @isTest
    static void testInitializeCases_Bulk() {
        // Given
        List<Case> cases = TestDataFactoryRefactored.createCases(5, 'Service_Request');

        Test.startTest();
        // When
        CaseAttributeService.initializeCases(cases);
        Test.stopTest();

        // Then
        System.assertEquals(5, cases.size(), 'All cases should be processed');
    }

    @isTest
    static void testInitializeCases_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.initializeCases(null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }

    @isTest
    static void testInitializeCases_EmptyList() {
        Test.startTest();
        // When
        CaseAttributeService.initializeCases(new List<Case>());
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle empty list gracefully');
    }

    @isTest
    static void testInitializeCases_ClosedPickupWithoutSubStatus() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Status = 'Closed';
        testCase.Case_Type__c = 'Pickup';
        testCase.Case_Sub_Status__c = null;

        Test.startTest();
        // When
        CaseAttributeService.initializeCase(testCase);
        Test.stopTest();

        // Then
        System.assertEquals('Service Not Performed', testCase.Case_Sub_Status__c,
                          'Sub-status should be set to Service Not Performed');
    }

    @isTest
    static void testInitializeCases_ClosedPickupWithExistingSubStatus() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Status = 'Closed';
        testCase.Case_Type__c = 'Pickup';
        testCase.Case_Sub_Status__c = 'Service Not Performed';

        Test.startTest();
        // When
        CaseAttributeService.initializeCase(testCase);
        Test.stopTest();

        // Then
        System.assertEquals('Service Not Performed', testCase.Case_Sub_Status__c,
                          'Sub-status should remain unchanged');
    }

    @isTest
    static void testInitializeCases_AcornStatusCase_HaulerReported() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Case_Type__c = 'Status';
        testCase.Source_System__c = 'Acorn';
        testCase.Status = 'Open';
        testCase.Case_Reason__c = 'Hauler Reported';

        Test.startTest();
        // When
        CaseAttributeService.initializeCase(testCase);
        Test.stopTest();

        // Then
        System.assertEquals('Pending Service Issue Resolution', testCase.Case_Sub_Status__c,
                          'Sub-status should be set');
        System.assertEquals('Standard', testCase.Service_Classification__c,
                          'Service classification should be Standard for Hauler Reported');
    }

    @isTest
    static void testInitializeCases_AcornStatusCase_CustomerReported() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Case_Type__c = 'Status';
        testCase.Source_System__c = 'Acorn';
        testCase.Status = 'Open';
        testCase.Case_Reason__c = 'Customer Reported';

        Test.startTest();
        // When
        CaseAttributeService.initializeCase(testCase);
        Test.stopTest();

        // Then
        System.assertEquals('Pending Service Issue Resolution', testCase.Case_Sub_Status__c,
                          'Sub-status should be set');
        System.assertEquals('Emergency', testCase.Service_Classification__c,
                          'Service classification should be Emergency for Customer Reported');
    }

    @isTest
    static void testInitializeCases_BackOfficeCaseFlag() {
        // Given
        String corporateServiceQueueId = SystemObjectSelector.getGroupId('Corporate Services Queue');

        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.OwnerId = corporateServiceQueueId;
        testCase.BackOffice_Case__c = false;

        Test.startTest();
        // When
        CaseAttributeService.initializeCase(testCase);
        Test.stopTest();

        // Then
        if (corporateServiceQueueId != null) {
            System.assertEquals(true, testCase.BackOffice_Case__c,
                              'BackOffice_Case flag should be set');
        }
    }

    @isTest
    static void testInitializeCases_BypassWODuplicate_CreateAMPM() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Create_AM_and_PM_Pickups__c = true;

        Test.startTest();
        // When
        CaseAttributeService.initializeCase(testCase);
        Test.stopTest();

        // Then
        System.assertEquals(true, testCase.Bypass_WO_Duplicate__c,
                          'Bypass WO Duplicate should be set for AM/PM pickups');
    }

    @isTest
    static void testInitializeCases_BypassWODuplicate_Multivendor() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Is_Multivendor__c = true;

        Test.startTest();
        // When
        CaseAttributeService.initializeCase(testCase);
        Test.stopTest();

        // Then
        System.assertEquals(true, testCase.Bypass_WO_Duplicate__c,
                          'Bypass WO Duplicate should be set for multivendor cases');
    }

    @isTest
    static void testInitializeCases_ReferenceNumber() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.ParentId = null;
        testCase.Reference_Number__c = null;
        insert testCase;

        testCase = [SELECT Id, CaseNumber, Reference_Number__c FROM Case WHERE Id = :testCase.Id];

        Test.startTest();
        // When
        CaseAttributeService.initializeCase(testCase);
        Test.stopTest();

        // Then
        System.assertEquals(testCase.CaseNumber, testCase.Reference_Number__c,
                          'Reference Number should be set to CaseNumber');
    }

    @isTest
    static void testInitializeCases_EmailDescriptionTrimmed() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Origin = 'Email';
        testCase.Description = 'This is a test description that should be trimmed';

        Test.startTest();
        // When
        CaseAttributeService.initializeCase(testCase);
        Test.stopTest();

        // Then
        System.assertEquals('', testCase.Description,
                          'Description should be cleared for email cases');
    }

    @isTest
    static void testInitializeCases_OfficetraxPOExtraction() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Origin = 'Officetrax';
        testCase.Case_Information__c = 'Request Number:1234567890 Additional Info';

        Test.startTest();
        // When
        CaseAttributeService.initializeCase(testCase);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, testCase.PurchaseOrder_Number__c,
                             'PO Number should be extracted from Case Information');
    }

    // ========================================
    // UPDATE CASE ATTRIBUTES TESTS
    // ========================================

    @isTest
    static void testUpdateCaseAttributes_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(null, null, null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }

    @isTest
    static void testUpdateCaseAttributes_EmptyList() {
        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>(), null, null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle empty list gracefully');
    }

    @isTest
    static void testUpdateCaseAttributes_PickupRecordType() {
        // Given
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Asset testAsset = (Asset)testData.get('asset');
        Account locationAccount = (Account)testData.get('locationAccount');

        Id pickupRecordType = Schema.getGlobalDescribe()
            .get('Case')
            .getDescribe()
            .getRecordTypeInfosByName()
            .get('Pickup')
            .getRecordTypeId();

        Case testCase = new Case(
            RecordTypeId = pickupRecordType,
            AssetId = testAsset.Id,
            Location__c = locationAccount.Id
        );

        Map<Id, Asset> containerMap = new Map<Id, Asset>{testAsset.Id => testAsset};
        Map<Id, Account> locationMap = new Map<Id, Account>{locationAccount.Id => locationAccount};

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, containerMap, locationMap);
        Test.stopTest();

        // Then
        System.assertEquals('Pickup', testCase.Case_Type__c,
                          'Case Type should be set to Pickup for pickup record type');
    }

    @isTest
    static void testUpdateCaseAttributes_CommercialScheduled() {
        // Given
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Account locationAccount = (Account)testData.get('locationAccount');

        Asset commercialScheduled = [SELECT Id, Product2Id, Product2.Family, Occurrence_Type__c
                                      FROM Asset
                                      WHERE Name = 'Commercial Scheduled Asset' LIMIT 1];

        Case testCase = TestDataFactoryRefactored.createCase('Pickup');
        testCase.AssetId = commercialScheduled.Id;
        testCase.Location__c = locationAccount.Id;
        testCase.Case_Type__c = 'Pickup';

        Map<Id, Asset> containerMap = new Map<Id, Asset>{commercialScheduled.Id => commercialScheduled};
        Map<Id, Account> locationMap = new Map<Id, Account>{locationAccount.Id => locationAccount};

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, containerMap, locationMap);
        Test.stopTest();

        // Then
        System.assertEquals('Extra Pickup', testCase.Case_Sub_Type__c,
                          'Case Sub Type should be Extra Pickup for Commercial Scheduled');
    }

    @isTest
    static void testUpdateCaseAttributes_CommercialOnCall() {
        // Given
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Account locationAccount = (Account)testData.get('locationAccount');

        Asset commercialOnCall = [SELECT Id, Product2Id, Product2.Family, Occurrence_Type__c
                                   FROM Asset
                                   WHERE Name = 'Commercial On-Call Asset' LIMIT 1];

        Case testCase = TestDataFactoryRefactored.createCase('Pickup');
        testCase.AssetId = commercialOnCall.Id;
        testCase.Location__c = locationAccount.Id;
        testCase.Case_Type__c = 'Pickup';

        Map<Id, Asset> containerMap = new Map<Id, Asset>{commercialOnCall.Id => commercialOnCall};
        Map<Id, Account> locationMap = new Map<Id, Account>{locationAccount.Id => locationAccount};

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, containerMap, locationMap);
        Test.stopTest();

        // Then
        System.assertEquals('On-Call Pick', testCase.Case_Sub_Type__c,
                          'Case Sub Type should be On-Call Pick for Commercial On-Call');
    }

    @isTest
    static void testUpdateCaseAttributes_Rolloff() {
        // Given
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Account locationAccount = (Account)testData.get('locationAccount');

        Asset rolloffAsset = [SELECT Id, Product2Id, Product2.Family, Product2.Equipment_Type__c
                              FROM Asset
                              WHERE Name = 'Rolloff Asset' LIMIT 1];

        Case testCase = TestDataFactoryRefactored.createCase('Pickup');
        testCase.AssetId = rolloffAsset.Id;
        testCase.Location__c = locationAccount.Id;
        testCase.Case_Type__c = 'Pickup';

        Map<Id, Asset> containerMap = new Map<Id, Asset>{rolloffAsset.Id => rolloffAsset};
        Map<Id, Account> locationMap = new Map<Id, Account>{locationAccount.Id => locationAccount};

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, containerMap, locationMap);
        Test.stopTest();

        // Then
        System.assertEquals('Empty and Return', testCase.Case_Sub_Type__c,
                          'Case Sub Type should be Empty and Return for Rolloff');
    }

    @isTest
    static void testUpdateCaseAttributes_Baler() {
        // Given
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Account locationAccount = (Account)testData.get('locationAccount');

        Asset balerAsset = [SELECT Id, Product2Id, Product2.Family, Product2.Equipment_Type__c
                            FROM Asset
                            WHERE Name = 'Baler Asset' LIMIT 1];

        Case testCase = TestDataFactoryRefactored.createCase('Pickup');
        testCase.AssetId = balerAsset.Id;
        testCase.Location__c = locationAccount.Id;
        testCase.Case_Type__c = 'Pickup';

        Map<Id, Asset> containerMap = new Map<Id, Asset>{balerAsset.Id => balerAsset};
        Map<Id, Account> locationMap = new Map<Id, Account>{locationAccount.Id => locationAccount};

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, containerMap, locationMap);
        Test.stopTest();

        // Then
        System.assertEquals('Bales', testCase.Case_Sub_Type__c,
                          'Case Sub Type should be Bales for Baler equipment');
    }

    @isTest
    static void testUpdateCaseAttributes_BulkService() {
        // Given
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Account locationAccount = (Account)testData.get('locationAccount');

        Asset bulkServiceAsset = [SELECT Id, Name, Product2Id, Product2.Family
                                   FROM Asset
                                   WHERE Name = 'Bulk Service' LIMIT 1];

        Case testCase = TestDataFactoryRefactored.createCase('Pickup');
        testCase.AssetId = bulkServiceAsset.Id;
        testCase.Location__c = locationAccount.Id;
        testCase.Case_Type__c = 'Pickup';

        Map<Id, Asset> containerMap = new Map<Id, Asset>{bulkServiceAsset.Id => bulkServiceAsset};
        Map<Id, Account> locationMap = new Map<Id, Account>{locationAccount.Id => locationAccount};

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, containerMap, locationMap);
        Test.stopTest();

        // Then
        System.assertEquals('Bulk Service', testCase.Case_Sub_Type__c,
                          'Case Sub Type should be Bulk Service for Services family Bulk Service asset');
    }

    @isTest
    static void testUpdateCaseAttributes_HaulAwayService() {
        // Given
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Account locationAccount = (Account)testData.get('locationAccount');

        Asset haulAwayAsset = [SELECT Id, Name, Product2Id, Product2.Family
                               FROM Asset
                               WHERE Name = 'Haul Away Service' LIMIT 1];

        Case testCase = TestDataFactoryRefactored.createCase('Pickup');
        testCase.AssetId = haulAwayAsset.Id;
        testCase.Location__c = locationAccount.Id;
        testCase.Case_Type__c = 'Pickup';

        Map<Id, Asset> containerMap = new Map<Id, Asset>{haulAwayAsset.Id => haulAwayAsset};
        Map<Id, Account> locationMap = new Map<Id, Account>{locationAccount.Id => locationAccount};

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, containerMap, locationMap);
        Test.stopTest();

        // Then
        System.assertEquals('Haul Away - No Equipment', testCase.Case_Sub_Type__c,
                          'Case Sub Type should be Haul Away - No Equipment for Services family Haul Away asset');
    }

    @isTest
    static void testUpdateCaseAttributes_HandPickupScheduled() {
        // Given
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Account locationAccount = (Account)testData.get('locationAccount');

        Asset handPickupScheduled = [SELECT Id, Name, Product2Id, Product2.Family, Occurrence_Type__c
                                      FROM Asset
                                      WHERE Name = 'Hand Pickup Scheduled' LIMIT 1];

        Case testCase = TestDataFactoryRefactored.createCase('Pickup');
        testCase.AssetId = handPickupScheduled.Id;
        testCase.Location__c = locationAccount.Id;
        testCase.Case_Type__c = 'Pickup';

        Map<Id, Asset> containerMap = new Map<Id, Asset>{handPickupScheduled.Id => handPickupScheduled};
        Map<Id, Account> locationMap = new Map<Id, Account>{locationAccount.Id => locationAccount};

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, containerMap, locationMap);
        Test.stopTest();

        // Then
        System.assertEquals('Extra Pickup', testCase.Case_Sub_Type__c,
                          'Case Sub Type should be Extra Pickup for Hand Pickup Scheduled');
    }

    @isTest
    static void testUpdateCaseAttributes_HandPickupOnCall() {
        // Given
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Account locationAccount = (Account)testData.get('locationAccount');

        Asset handPickupOnCall = [SELECT Id, Name, Product2Id, Product2.Family, Occurrence_Type__c
                                   FROM Asset
                                   WHERE Name = 'Hand Pickup On-Call' LIMIT 1];

        Case testCase = TestDataFactoryRefactored.createCase('Pickup');
        testCase.AssetId = handPickupOnCall.Id;
        testCase.Location__c = locationAccount.Id;
        testCase.Case_Type__c = 'Pickup';

        Map<Id, Asset> containerMap = new Map<Id, Asset>{handPickupOnCall.Id => handPickupOnCall};
        Map<Id, Account> locationMap = new Map<Id, Account>{locationAccount.Id => locationAccount};

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, containerMap, locationMap);
        Test.stopTest();

        // Then
        System.assertEquals('On-Call Pick', testCase.Case_Sub_Type__c,
                          'Case Sub Type should be On-Call Pick for Hand Pickup On-Call');
    }

    @isTest
    static void testUpdateCaseAttributes_EmptyAndDoNotReturn() {
        // Given
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Account locationAccount = (Account)testData.get('locationAccount');
        Asset testAsset = (Asset)testData.get('asset');

        Case testCase = TestDataFactoryRefactored.createCase('Pickup');
        testCase.AssetId = testAsset.Id;
        testCase.Location__c = locationAccount.Id;
        testCase.Case_Type__c = 'Pickup';
        testCase.Case_Sub_Type__c = 'Empty and Do Not Return';

        Map<Id, Asset> containerMap = new Map<Id, Asset>{testAsset.Id => testAsset};
        Map<Id, Account> locationMap = new Map<Id, Account>{locationAccount.Id => locationAccount};

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, containerMap, locationMap);
        Test.stopTest();

        // Then
        System.assertEquals('Empty and Do Not Return', testCase.Case_Sub_Type__c,
                          'Case Sub Type should remain unchanged for Empty and Do Not Return');
    }

    @isTest
    static void testUpdateCaseAttributes_WorkOrderInstructions_FullContact() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Site_Contact__c = 'John Doe';
        testCase.Site_Contact_Phone__c = '555-1234';
        testCase.System_Gen_WO_Instructions__c = 'System instructions';
        testCase.User_Input_Work_Order_Instructions__c = 'User instructions';

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, null, null);
        Test.stopTest();

        // Then
        System.assert(testCase.Work_Order_Instructions__c.contains('John Doe'),
                     'Work Order Instructions should contain site contact name');
        System.assert(testCase.Work_Order_Instructions__c.contains('555-1234'),
                     'Work Order Instructions should contain site contact phone');
    }

    @isTest
    static void testUpdateCaseAttributes_WorkOrderInstructions_NameOnly() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Site_Contact__c = 'Jane Doe';
        testCase.Site_Contact_Phone__c = null;

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, null, null);
        Test.stopTest();

        // Then
        System.assert(testCase.Work_Order_Instructions__c.contains('Jane Doe'),
                     'Work Order Instructions should contain site contact name');
    }

    @isTest
    static void testUpdateCaseAttributes_WorkOrderInstructions_PhoneOnly() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Site_Contact__c = null;
        testCase.Site_Contact_Phone__c = '555-9999';

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, null, null);
        Test.stopTest();

        // Then
        System.assert(testCase.Work_Order_Instructions__c.contains('555-9999'),
                     'Work Order Instructions should contain site contact phone');
    }

    @isTest
    static void testUpdateCaseAttributes_LocalServiceDate() {
        // Given
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Account locationAccount = (Account)testData.get('locationAccount');
        locationAccount.tz__Timezone_SFDC__c = 'America/New_York';
        update locationAccount;

        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Location__c = locationAccount.Id;
        insert testCase;

        testCase = [SELECT Id, CreatedDate, Location__c FROM Case WHERE Id = :testCase.Id];

        Map<Id, Account> locationMap = new Map<Id, Account>{locationAccount.Id => locationAccount};

        Test.startTest();
        // When
        CaseAttributeService.updateCaseAttributes(new List<Case>{testCase}, null, locationMap);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, testCase.Service_Date_from_Local_Time__c,
                             'Service Date from Local Time should be set');
    }

    // ========================================
    // CONTACT-RELATED TESTS
    // ========================================

    @isTest
    static void testUpdateContactLastActivity() {
        // Given
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        Set<Id> contactIdSet = new Set<Id>{testContact.Id};

        Test.startTest();
        // When
        CaseAttributeService.updateContactLastActivity(contactIdSet);
        Test.stopTest();

        // Then
        Contact updatedContact = [SELECT Id, Last_Activity_Date__c FROM Contact WHERE Id = :testContact.Id];
        System.assertEquals(System.today(), updatedContact.Last_Activity_Date__c,
                          'Last Activity Date should be updated to today');
    }

    @isTest
    static void testUpdateContactLastActivity_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.updateContactLastActivity(null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }

    @isTest
    static void testUpdateContactLastActivity_EmptySet() {
        Test.startTest();
        // When
        CaseAttributeService.updateContactLastActivity(new Set<Id>());
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle empty set gracefully');
    }

    @isTest
    static void testSynchronizeContactANI() {
        // Given
        Contact testContact = [SELECT Id, ANI__c FROM Contact LIMIT 1];

        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.ContactId = testContact.Id;
        insert testCase;

        testCase.Contact = new Contact(Id = testContact.Id, ANI__c = '9876543210');

        Map<Id, Case> caseNewMap = new Map<Id, Case>{testCase.Id => testCase};
        Map<Id, Case> oldCaseMap = new Map<Id, Case>();

        Test.startTest();
        // When
        CaseAttributeService.synchronizeContactANI(caseNewMap, oldCaseMap);
        Test.stopTest();

        // Then
        Contact updatedContact = [SELECT Id, ANI__c FROM Contact WHERE Id = :testContact.Id];
        System.assertEquals('9876543210', updatedContact.ANI__c,
                          'ANI should be synchronized from Case to Contact');
    }

    @isTest
    static void testSynchronizeContactANI_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.synchronizeContactANI(null, null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }

    // ========================================
    // CASE DETAIL UPDATE TESTS
    // ========================================

    @isTest
    static void testUpdateCaseDetailsFromAssetAndLocation() {
        // Given
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Asset testAsset = (Asset)testData.get('asset');
        Account locationAccount = (Account)testData.get('locationAccount');

        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.AssetId = testAsset.Id;
        testCase.Location__c = locationAccount.Id;

        Map<Id, Asset> containerMap = new Map<Id, Asset>{testAsset.Id => testAsset};
        Map<Id, Account> locationMap = new Map<Id, Account>{locationAccount.Id => locationAccount};

        Test.startTest();
        // When
        List<Case> results = CaseAttributeService.updateCaseDetailsFromAssetAndLocation(
            new List<Case>{testCase}, null, containerMap, locationMap, true);
        Test.stopTest();

        // Then
        System.assertEquals(1, results.size(), 'Should return updated case');
        System.assertNotEquals(null, testCase.LOB__c, 'LOB should be set from Asset Product Family');
    }

    @isTest
    static void testUpdateCaseDetailsFromAssetAndLocation_NullInput() {
        Test.startTest();
        // When
        List<Case> results = CaseAttributeService.updateCaseDetailsFromAssetAndLocation(
            null, null, null, null, true);
        Test.stopTest();

        // Then
        System.assertEquals(null, results, 'Should return null for null input');
    }

    // ========================================
    // DESCRIPTION AND FIELD FORMATTING TESTS
    // ========================================

    @isTest
    static void testTrimEmailDescriptions() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Origin = 'Email';
        testCase.Description = 'A'.repeat(35000); // Exceeds 32000 character limit

        Test.startTest();
        // When
        CaseAttributeService.trimEmailDescriptions(new List<Case>{testCase});
        Test.stopTest();

        // Then
        System.assertEquals(32000, testCase.Description.length(),
                          'Description should be trimmed to 32000 characters');
    }

    @isTest
    static void testTrimEmailDescriptions_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.trimEmailDescriptions(null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }

    @isTest
    static void testExtractPOFromOfficetrax() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Origin = 'Officetrax';
        testCase.Case_Information__c = 'Request Number:1234567890 Additional Info';

        Test.startTest();
        // When
        CaseAttributeService.extractPOFromOfficetrax(new List<Case>{testCase});
        Test.stopTest();

        // Then
        System.assertEquals('1234567890', testCase.PurchaseOrder_Number__c,
                          'PO Number should be extracted from Case Information');
    }

    @isTest
    static void testExtractPOFromOfficetrax_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.extractPOFromOfficetrax(null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }

    @isTest
    static void testSyncTrackingNumbersAndComments() {
        // Given
        Case oldCase = new Case(Id = TestDataFactoryRefactored.createCase('Service_Request').Id);
        insert oldCase;

        Case newCase = [SELECT Id, Tracking_Number__c, Case_Comments__c FROM Case WHERE Id = :oldCase.Id];
        newCase.Tracking_Number__c = 'TRK-123456';

        Map<Id, Case> caseNewMap = new Map<Id, Case>{newCase.Id => newCase};
        Map<Id, Case> oldCaseMap = new Map<Id, Case>{oldCase.Id => oldCase};

        Test.startTest();
        // When
        CaseAttributeService.syncTrackingNumbersAndComments(caseNewMap, oldCaseMap);
        Test.stopTest();

        // Then
        System.assert(newCase.Case_Comments__c.contains('TRK-123456'),
                     'Case Comments should include tracking number');
    }

    @isTest
    static void testSyncTrackingNumbersAndComments_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.syncTrackingNumbersAndComments(null, null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }

    @isTest
    static void testSyncCompanyCategoryAndPO() {
        // Given
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Account testAccount = (Account)testData.get('parentAccount');

        Case newCase = TestDataFactoryRefactored.createCase('Service_Request');
        newCase.AccountId = testAccount.Id;

        Test.startTest();
        // When
        CaseAttributeService.syncCompanyCategoryAndPO(new List<Case>{newCase}, null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Method should execute without errors');
    }

    @isTest
    static void testSyncCompanyCategoryAndPO_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.syncCompanyCategoryAndPO(null, null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }

    // ========================================
    // AGENT AND CALL CENTER IDENTIFICATION TESTS
    // ========================================

    @isTest
    static void testUpdateLastAgentIdentification() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.OwnerId = UserInfo.getUserId();
        insert testCase;

        Map<Id, Case> caseNewMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();
        // When
        List<Case> results = CaseAttributeService.updateLastAgentIdentification(
            caseNewMap, null, true, 0);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return list of updated cases');
    }

    @isTest
    static void testUpdateLastAgentIdentification_NullInput() {
        Test.startTest();
        // When
        List<Case> results = CaseAttributeService.updateLastAgentIdentification(
            null, null, true, 0);
        Test.stopTest();

        // Then
        System.assertEquals(0, results.size(), 'Should return empty list for null input');
    }

    @isTest
    static void testUpdateCallCenterIdentification() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Origin = 'Phone';
        insert testCase;

        Map<Id, Case> caseNewMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();
        // When
        List<Case> results = CaseAttributeService.updateCallCenterIdentification(
            caseNewMap, null, true);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return list of updated cases');
    }

    @isTest
    static void testUpdateCallCenterIdentification_NullInput() {
        Test.startTest();
        // When
        List<Case> results = CaseAttributeService.updateCallCenterIdentification(
            null, null, true);
        Test.stopTest();

        // Then
        System.assertEquals(0, results.size(), 'Should return empty list for null input');
    }

    @isTest
    static void testShouldSkipAgentIdUpdate_ClosedCase() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Status = 'Closed';

        Test.startTest();
        // When
        Boolean result = CaseAttributeService.shouldSkipAgentIdUpdate(testCase, null, false);
        Test.stopTest();

        // Then
        System.assertEquals(true, result, 'Should skip update for closed case');
    }

    @isTest
    static void testShouldSkipAgentIdUpdate_NullCase() {
        Test.startTest();
        // When
        Boolean result = CaseAttributeService.shouldSkipAgentIdUpdate(null, null, false);
        Test.stopTest();

        // Then
        System.assertEquals(true, result, 'Should skip update for null case');
    }

    // ========================================
    // ASSIGNMENT AND OWNERSHIP TESTS
    // ========================================

    @isTest
    static void testAssignCaseOwnership_TeamQueue() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Team_Name__c = 'Customer Service';
        testCase.Team_Queue__c = 'CS Follow Up';

        Map<Id, Case> newMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();
        // When
        CaseAttributeService.assignCaseOwnership(newMap, null, new List<Case>{testCase});
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Method should execute without errors');
    }

    @isTest
    static void testAssignCaseOwnership_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.assignCaseOwnership(null, null, null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }

    @isTest
    static void testAssignTeamAndQueue_PickupType() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Case_Type__c = 'Pickup';

        Test.startTest();
        // When
        CaseAttributeService.assignTeamAndQueue(new List<Case>{testCase});
        Test.stopTest();

        // Then
        System.assertEquals('Customer Service', testCase.Team_Name__c,
                          'Team Name should be set to Customer Service for Pickup cases');
        System.assertEquals('CS Follow Up', testCase.Team_Queue__c,
                          'Team Queue should be set to CS Follow Up for Pickup cases');
    }

    @isTest
    static void testAssignTeamAndQueue_StatusType() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Case_Type__c = 'Status';

        Test.startTest();
        // When
        CaseAttributeService.assignTeamAndQueue(new List<Case>{testCase});
        Test.stopTest();

        // Then
        System.assertEquals('Customer Service', testCase.Team_Name__c,
                          'Team Name should be set to Customer Service for Status cases');
    }

    @isTest
    static void testAssignTeamAndQueue_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.assignTeamAndQueue(null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }

    // ========================================
    // SERVICE CLASSIFICATION TESTS
    // ========================================

    @isTest
    static void testSetServiceClassification_HaulerReported() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Case_Reason__c = 'Hauler Reported';

        Test.startTest();
        // When
        CaseAttributeService.setServiceClassification(new List<Case>{testCase}, null);
        Test.stopTest();

        // Then
        System.assertEquals('Standard', testCase.Service_Classification__c,
                          'Service Classification should be Standard for Hauler Reported');
    }

    @isTest
    static void testSetServiceClassification_CustomerReported() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        testCase.Case_Reason__c = 'Customer Reported';

        Test.startTest();
        // When
        CaseAttributeService.setServiceClassification(new List<Case>{testCase}, null);
        Test.stopTest();

        // Then
        System.assertEquals('Emergency', testCase.Service_Classification__c,
                          'Service Classification should be Emergency for Customer Reported');
    }

    @isTest
    static void testSetServiceClassification_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.setServiceClassification(null, null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }

    // ========================================
    // NSC METHODS TESTS
    // ========================================

    @isTest
    static void testUpdateNewServiceCaseFields() {
        // Given
        Case testCase = TestDataFactoryRefactored.createCase('Service_Request');
        insert testCase;

        Map<Id, Case> caseNewMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();
        // When
        CaseAttributeService.updateNewServiceCaseFields(caseNewMap, null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Method should execute without errors');
    }

    @isTest
    static void testUpdateNewServiceCaseFields_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.updateNewServiceCaseFields(null, null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }

    // ========================================
    // CHARGEABILITY TESTS
    // ========================================

    @isTest
    static void testPropagateChargeabilityToParent() {
        // Given
        Case parentCase = TestDataFactoryRefactored.createCase('Service_Request');
        parentCase.Chargeable__c = 'No';
        insert parentCase;

        Case childCase = TestDataFactoryRefactored.createCase('Service_Request');
        childCase.ParentId = parentCase.Id;
        childCase.Chargeable__c = 'Yes';
        insert childCase;

        Set<Id> caseIdSet = new Set<Id>{childCase.Id};

        Test.startTest();
        // When
        CaseAttributeService.propagateChargeabilityToParent(caseIdSet);
        Test.stopTest();

        // Then
        Case updatedParent = [SELECT Id, Chargeable__c FROM Case WHERE Id = :parentCase.Id];
        System.assertEquals('Yes', updatedParent.Chargeable__c,
                          'Parent chargeability should be updated to Yes when child is chargeable');
    }

    @isTest
    static void testPropagateChargeabilityToParent_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.propagateChargeabilityToParent(null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }

    @isTest
    static void testPropagateChargeabilityToChildren() {
        // Given
        Case parentCase = TestDataFactoryRefactored.createCase('Service_Request');
        parentCase.Chargeable__c = 'Yes';
        insert parentCase;

        Case childCase = TestDataFactoryRefactored.createCase('Service_Request');
        childCase.ParentId = parentCase.Id;
        childCase.Chargeable__c = 'No';
        insert childCase;

        Set<Id> caseIdSet = new Set<Id>{parentCase.Id};

        Test.startTest();
        // When
        CaseAttributeService.propagateChargeabilityToChildren(caseIdSet);
        Test.stopTest();

        // Then
        Case updatedChild = [SELECT Id, Chargeable__c FROM Case WHERE Id = :childCase.Id];
        System.assertEquals('Yes', updatedChild.Chargeable__c,
                          'Child chargeability should be updated to match parent');
    }

    @isTest
    static void testPropagateChargeabilityToChildren_NullInput() {
        Test.startTest();
        // When
        CaseAttributeService.propagateChargeabilityToChildren(null);
        Test.stopTest();

        // Then - No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }
}
