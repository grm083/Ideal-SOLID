/**
 * @description Test class for ActionMessagesPanelController
 * 
 * Tests action panel data retrieval, button visibility, and message generation
 * for the unified case management system.
 * 
 * @author George Martin
 * @date 2025-11-18
 * @group Test Classes
 */
@isTest
private class ActionMessagesPanelControllerTest {
    
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
        
        // Create test case
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Web',
            Location__c = testLocation.Id,
            ContactId = testContact.Id,
            AssetId = testAsset.Id,
            Case_Type__c = 'Service',
            Case_Sub_Type__c = 'Delivery',
            Reference_Number__c = 'REF123',
            Is_MultiCalendar_Checked__c = true
        );
        insert testCase;
    }
    
    /**
     * Test getActionPanelData method
     */
    @isTest
    static void testGetActionPanelData() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        ActionMessagesPanelController.ActionPanelData result = 
            ActionMessagesPanelController.getActionPanelData(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(testCase.Id, result.caseId, 'Case ID should match');
        System.assertEquals('New', result.status, 'Status should match');
        System.assertEquals('Service', result.caseType, 'Case type should match');
        System.assertNotEquals(null, result.actionMessage, 'Action message should not be null');
        System.assertNotEquals(null, result.messageVariant, 'Message variant should not be null');
        System.assertNotEquals(null, result.messageIcon, 'Message icon should not be null');
    }
    
    /**
     * Test getButtonVisibility method
     */
    @isTest
    static void testGetButtonVisibility() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        ActionMessagesPanelController.ButtonVisibilityData result = 
            ActionMessagesPanelController.getButtonVisibility(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        // All button visibility flags should be initialized (true or false)
        System.assertNotEquals(null, result.showProgressCase, 'Progress Case visibility should be set');
        System.assertNotEquals(null, result.showAddQuote, 'Add Quote visibility should be set');
        System.assertNotEquals(null, result.showInitiateWorkOrder, 'Initiate WO visibility should be set');
        System.assertNotEquals(null, result.showViewCaseSummary, 'View Summary visibility should be set');
        System.assertNotEquals(null, result.showAddCaseAssets, 'Add Assets visibility should be set');
        System.assertNotEquals(null, result.showPendingInfoTask, 'Pending Task visibility should be set');
        System.assertNotEquals(null, result.showMultiDates, 'Multi Dates visibility should be set');
    }
    
    /**
     * Test message variant logic
     */
    @isTest
    static void testMessageVariants() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        
        // Test New status (should be info variant)
        ActionMessagesPanelController.ActionPanelData result1 = 
            ActionMessagesPanelController.getActionPanelData(testCase.Id);
        
        // Update to Open status
        testCase.Status = 'Open';
        update testCase;
        
        ActionMessagesPanelController.ActionPanelData result2 = 
            ActionMessagesPanelController.getActionPanelData(testCase.Id);
        
        // Update to Closed status
        testCase.Status = 'Closed';
        update testCase;
        
        ActionMessagesPanelController.ActionPanelData result3 = 
            ActionMessagesPanelController.getActionPanelData(testCase.Id);
        
        Test.stopTest();
        
        System.assertNotEquals(null, result1.messageVariant, 'New case should have message variant');
        System.assertNotEquals(null, result2.messageVariant, 'Open case should have message variant');
        System.assertNotEquals(null, result3.messageVariant, 'Closed case should have message variant');
    }
    
    /**
     * Test button visibility with different case states
     */
    @isTest
    static void testButtonVisibilityWithDifferentStates() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        
        // Test with New case
        ActionMessagesPanelController.ButtonVisibilityData result1 = 
            ActionMessagesPanelController.getButtonVisibility(testCase.Id);
        
        // Test with Open case
        testCase.Status = 'Open';
        update testCase;
        ActionMessagesPanelController.ButtonVisibilityData result2 = 
            ActionMessagesPanelController.getButtonVisibility(testCase.Id);
        
        // Test with Closed case
        testCase.Status = 'Closed';
        update testCase;
        ActionMessagesPanelController.ButtonVisibilityData result3 = 
            ActionMessagesPanelController.getButtonVisibility(testCase.Id);
        
        Test.stopTest();
        
        // Closed cases should have different button visibility
        System.assertEquals(false, result3.showInitiateWorkOrder, 
                          'Closed case should not show Initiate WO button');
        System.assertEquals(false, result3.showAddCaseAssets, 
                          'Closed case should not show Add Assets button');
    }
    
    /**
     * Test related case count
     */
    @isTest
    static void testRelatedCaseCount() {
        Case testCase = [SELECT Id, Reference_Number__c FROM Case LIMIT 1];
        
        // Create related case with same reference number
        Case relatedCase = new Case(
            Subject = 'Related Case',
            Status = 'New',
            Origin = 'Web',
            Reference_Number__c = testCase.Reference_Number__c
        );
        insert relatedCase;
        
        Test.startTest();
        ActionMessagesPanelController.ActionPanelData result = 
            ActionMessagesPanelController.getActionPanelData(testCase.Id);
        Test.stopTest();
        
        System.assertEquals(1, result.relatedCaseCount, 'Should have 1 related case');
    }
    
    /**
     * Test null/blank input handling
     */
    @isTest
    static void testNullInputHandling() {
        Test.startTest();
        
        // Test null case ID
        ActionMessagesPanelController.ActionPanelData result1 = 
            ActionMessagesPanelController.getActionPanelData(null);
        System.assertNotEquals(null, result1, 'Should handle null input gracefully');
        
        ActionMessagesPanelController.ButtonVisibilityData result2 = 
            ActionMessagesPanelController.getButtonVisibility('');
        System.assertNotEquals(null, result2, 'Should handle blank input gracefully');
        
        Test.stopTest();
    }
}
