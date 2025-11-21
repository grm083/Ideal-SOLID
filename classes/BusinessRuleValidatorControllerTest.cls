/**
 * @description Test class for BusinessRuleValidatorController
 * 
 * Tests business rule evaluation, validation, and button visibility logic
 * for the unified case management system.
 * 
 * @author George Martin
 * @date 2025-11-18
 * @group Test Classes
 */
@isTest
private class BusinessRuleValidatorControllerTest {
    
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
        
        // Create test asset
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
            PurchaseOrder_Number__c = 'PO123',
            Profile_Number__c = 'PROF456'
        );
        insert testCase;
    }
    
    /**
     * Test evaluateBusinessRules method
     */
    @isTest
    static void testEvaluateBusinessRules() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        BusinessRuleValidatorController.BusinessRuleEvaluation result = 
            BusinessRuleValidatorController.evaluateBusinessRules(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.messages != null, 'Messages list should be initialized');
    }
    
    /**
     * Test isPurchaseOrderRequired method
     */
    @isTest
    static void testIsPurchaseOrderRequired() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        Boolean result = BusinessRuleValidatorController.isPurchaseOrderRequired(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    /**
     * Test isProfileNumberRequired method
     */
    @isTest
    static void testIsProfileNumberRequired() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        Boolean result = BusinessRuleValidatorController.isProfileNumberRequired(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    /**
     * Test isPSIRequired method
     */
    @isTest
    static void testIsPSIRequired() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        Boolean result = BusinessRuleValidatorController.isPSIRequired(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    /**
     * Test shouldShowProgressCaseButton method
     */
    @isTest
    static void testShouldShowProgressCaseButton() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        Boolean result = BusinessRuleValidatorController.shouldShowProgressCaseButton(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    /**
     * Test shouldShowAddQuoteButton method
     */
    @isTest
    static void testShouldShowAddQuoteButton() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        Boolean result = BusinessRuleValidatorController.shouldShowAddQuoteButton(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    /**
     * Test updateCustomerInfoFields method
     */
    @isTest
    static void testUpdateCustomerInfoFields() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        BusinessRuleValidatorController.FieldUpdates updates = 
            new BusinessRuleValidatorController.FieldUpdates();
        updates.purchaseOrderNumber = 'PO999';
        updates.profileNumber = 'PROF999';
        updates.psi = 10.5;
        
        String updatesJson = JSON.serialize(updates);
        
        Test.startTest();
        BusinessRuleValidatorController.updateCustomerInfoFields(testCase.Id, updatesJson);
        Test.stopTest();
        
        Case updatedCase = [SELECT PurchaseOrder_Number__c, Profile_Number__c, PSI__c 
                           FROM Case WHERE Id = :testCase.Id];
        
        System.assertEquals('PO999', updatedCase.PurchaseOrder_Number__c, 'PO should be updated');
        System.assertEquals('PROF999', updatedCase.Profile_Number__c, 'Profile should be updated');
        System.assertEquals(10.5, updatedCase.PSI__c, 'PSI should be updated');
    }
    
    /**
     * Test getCurrentCustomerInfo method
     */
    @isTest
    static void testGetCurrentCustomerInfo() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        BusinessRuleValidatorController.CustomerInfoFields result = 
            BusinessRuleValidatorController.getCurrentCustomerInfo(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('PO123', result.purchaseOrderNumber, 'PO should match');
        System.assertEquals('PROF456', result.profileNumber, 'Profile should match');
    }
    
    /**
     * Test validateCustomerInfo method
     */
    @isTest
    static void testValidateCustomerInfo() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = BusinessRuleValidatorController.validateCustomerInfo(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('isValid'), 'Result should contain isValid key');
    }
    
    /**
     * Test null/blank input handling
     */
    @isTest
    static void testNullInputHandling() {
        Test.startTest();
        
        // Test null inputs
        BusinessRuleValidatorController.BusinessRuleEvaluation result1 = 
            BusinessRuleValidatorController.evaluateBusinessRules(null);
        System.assertNotEquals(null, result1, 'Should handle null input gracefully');
        
        Boolean result2 = BusinessRuleValidatorController.isPurchaseOrderRequired('');
        System.assertEquals(false, result2, 'Should return false for blank input');
        
        Test.stopTest();
    }
}
