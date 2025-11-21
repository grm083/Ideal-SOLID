/**
 * @description Test class for CaseHighlightStripController
 * 
 * Tests case highlight strip data retrieval and field status determination
 * for the unified case management system.
 * 
 * @author George Martin
 * @date 2025-11-18
 * @group Test Classes
 */
@isTest
private class CaseHighlightStripControllerTest {
    
    /**
     * Test data setup
     */
    @testSetup
    static void setupTestData() {
        // Create test account (location)
        Account testLocation = new Account(
            Name = 'Test Location',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Location').getRecordTypeId()
        );
        insert testLocation;
        
        // Create test contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testLocation.Id,
            Email = 'test@example.com'
        );
        insert testContact;
        
        // Create test product and asset
        Product2 testProduct = new Product2(Name = 'Test Product');
        insert testProduct;
        
        Asset testAsset = new Asset(
            Name = 'Test Asset',
            AccountId = testLocation.Id,
            Product2Id = testProduct.Id,
            Status = 'Active'
        );
        insert testAsset;
        
        // Create test case with comprehensive data
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Web',
            Location__c = testLocation.Id,
            ContactId = testContact.Id,
            AssetId = testAsset.Id,
            Case_Type__c = 'Service',
            Case_Sub_Type__c = 'Delivery',
            Case_Reason__c = 'Urgent',
            PurchaseOrder_Number__c = 'PO123',
            Profile_Number__c = 'PROF456',
            PSI__c = 10.5,
            Service_Date__c = Date.today().addDays(7),
            Reference_Number__c = 'REF123',
            Asset_Material__c = 'Steel',
            Tracking_Number__c = 'TRK456'
        );
        insert testCase;
    }
    
    /**
     * Test getCaseHighlightData method
     */
    @isTest
    static void testGetCaseHighlightData() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        CaseHighlightStripController.CaseHighlightData result = 
            CaseHighlightStripController.getCaseHighlightData(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(testCase.Id, result.caseId, 'Case ID should match');
        System.assertEquals('Test Location', result.locationName, 'Location name should match');
        System.assertEquals('Test Contact', result.contactName, 'Contact name should match');
        System.assertEquals('Test Asset', result.assetName, 'Asset name should match');
        System.assertEquals('Service', result.caseType, 'Case type should match');
        System.assertEquals('PO123', result.purchaseOrderNumber, 'PO should match');
        System.assertEquals('PROF456', result.profileNumber, 'Profile should match');
        System.assertEquals(10.5, result.psi, 'PSI should match');
    }
    
    /**
     * Test getCaseHighlightSummary method
     */
    @isTest
    static void testGetCaseHighlightSummary() {
        Case testCase = [SELECT Id, CaseNumber FROM Case LIMIT 1];
        
        Test.startTest();
        CaseHighlightStripController.CaseHighlightSummary result = 
            CaseHighlightStripController.getCaseHighlightSummary(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(testCase.CaseNumber, result.caseNumber, 'Case number should match');
        System.assertEquals('New', result.status, 'Status should match');
        System.assertEquals('Service', result.caseType, 'Case type should match');
        System.assertEquals(true, result.hasRequiredInfo, 'Should have required info');
    }
    
    /**
     * Test field status determination
     */
    @isTest
    static void testFieldStatusDetermination() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        CaseHighlightStripController.CaseHighlightData result = 
            CaseHighlightStripController.getCaseHighlightData(testCase.Id);
        Test.stopTest();
        
        // Verify field statuses are set
        System.assertNotEquals(null, result.locationStatus, 'Location status should be set');
        System.assertNotEquals(null, result.contactStatus, 'Contact status should be set');
        System.assertNotEquals(null, result.assetStatus, 'Asset status should be set');
        System.assertNotEquals(null, result.caseTypeStatus, 'Case type status should be set');
        System.assertNotEquals(null, result.serviceDateStatus, 'Service date status should be set');
        System.assertNotEquals(null, result.customerInfoStatus, 'Customer info status should be set');
        System.assertNotEquals(null, result.caseReadiness, 'Case readiness should be set');
    }
    
    /**
     * Test with missing required fields
     */
    @isTest
    static void testMissingRequiredFields() {
        // Create case with missing fields
        Case incompleteCase = new Case(
            Subject = 'Incomplete Case',
            Status = 'New',
            Origin = 'Web'
        );
        insert incompleteCase;
        
        Test.startTest();
        CaseHighlightStripController.CaseHighlightData result = 
            CaseHighlightStripController.getCaseHighlightData(incompleteCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('--', result.locationName, 'Location should be empty placeholder');
        System.assertEquals('--', result.contactName, 'Contact should be empty placeholder');
    }
    
    /**
     * Test null/blank input handling
     */
    @isTest
    static void testNullInputHandling() {
        Test.startTest();
        
        // Test null case ID
        CaseHighlightStripController.CaseHighlightData result1 = 
            CaseHighlightStripController.getCaseHighlightData(null);
        System.assertNotEquals(null, result1, 'Should handle null input gracefully');
        
        CaseHighlightStripController.CaseHighlightSummary result2 = 
            CaseHighlightStripController.getCaseHighlightSummary('');
        System.assertNotEquals(null, result2, 'Should handle blank input gracefully');
        
        Test.stopTest();
    }
}
