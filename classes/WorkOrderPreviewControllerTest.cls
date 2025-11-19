/**
 * @description Test class for WorkOrderPreviewController
 * 
 * Tests work order preview data retrieval, updates, and validation
 * for the unified case management system.
 * 
 * @author Claude (AI Assistant)
 * @date 2025-11-18
 * @group Test Classes
 */
@isTest
private class WorkOrderPreviewControllerTest {
    
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
        
        // Create test case
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Web',
            Location__c = testLocation.Id,
            ContactId = testContact.Id,
            Case_Type__c = 'Service',
            Case_Sub_Type__c = 'Delivery',
            Site_Contact__c = 'John Doe',
            Site_Contact_Phone__c = '555-1234',
            User_Input_Work_Order_Instructions__c = 'Test instructions'
        );
        insert testCase;
    }
    
    /**
     * Test getWorkOrderPreviewData method
     */
    @isTest
    static void testGetWorkOrderPreviewData() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        WorkOrderPreviewController.WorkOrderPreviewData result = 
            WorkOrderPreviewController.getWorkOrderPreviewData(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('John Doe', result.siteContact, 'Site contact should match');
        System.assertEquals('555-1234', result.siteContactPhone, 'Site phone should match');
        System.assertEquals('Test instructions', result.workOrderInstructions, 'Instructions should match');
    }
    
    /**
     * Test getWorkOrderPreviewInfo method
     */
    @isTest
    static void testGetWorkOrderPreviewInfo() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        WorkOrderPreviewController.WorkOrderPreviewInfo result = 
            WorkOrderPreviewController.getWorkOrderPreviewInfo(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.previewText, 'Preview text should not be null');
        System.assertEquals('John Doe', result.siteContact, 'Site contact should match');
    }
    
    /**
     * Test updateWorkOrderPreviewFields method
     */
    @isTest
    static void testUpdateWorkOrderPreviewFields() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        WorkOrderPreviewController.WorkOrderUpdateData updateData = 
            new WorkOrderPreviewController.WorkOrderUpdateData();
        updateData.siteContact = 'Jane Smith';
        updateData.siteContactPhone = '555-9999';
        updateData.workOrderInstructions = 'Updated instructions';
        updateData.byPassWorkOrder = true;
        
        String updateDataJson = JSON.serialize(updateData);
        
        Test.startTest();
        WorkOrderPreviewController.updateWorkOrderPreviewFields(testCase.Id, updateDataJson);
        Test.stopTest();
        
        Case updatedCase = [SELECT Site_Contact__c, Site_Contact_Phone__c, 
                                  User_Input_Work_Order_Instructions__c, Is_ByPassWO__c
                           FROM Case WHERE Id = :testCase.Id];
        
        System.assertEquals('Jane Smith', updatedCase.Site_Contact__c, 'Site contact should be updated');
        System.assertEquals('555-9999', updatedCase.Site_Contact_Phone__c, 'Site phone should be updated');
        System.assertEquals('Updated instructions', updatedCase.User_Input_Work_Order_Instructions__c, 
                          'Instructions should be updated');
        System.assertEquals(true, updatedCase.Is_ByPassWO__c, 'Bypass flag should be updated');
    }
    
    /**
     * Test validateWorkOrderCreation method
     */
    @isTest
    static void testValidateWorkOrderCreation() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        WorkOrderPreviewController.ValidationResultWrapper result = 
            WorkOrderPreviewController.validateWorkOrderCreation(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.messages, 'Messages should be initialized');
    }
    
    /**
     * Test null/blank input handling
     */
    @isTest
    static void testNullInputHandling() {
        Test.startTest();
        
        // Test null case ID
        WorkOrderPreviewController.WorkOrderPreviewData result1 = 
            WorkOrderPreviewController.getWorkOrderPreviewData(null);
        System.assertNotEquals(null, result1, 'Should handle null input gracefully');
        
        // Test blank case ID for validation
        WorkOrderPreviewController.ValidationResultWrapper result2 = 
            WorkOrderPreviewController.validateWorkOrderCreation('');
        System.assertEquals(false, result2.isValid, 'Should be invalid for blank input');
        System.assert(result2.messages.size() > 0, 'Should have validation message');
        
        Test.stopTest();
    }
    
    /**
     * Test error handling
     */
    @isTest
    static void testErrorHandling() {
        Test.startTest();
        
        try {
            // Try to update with null data
            WorkOrderPreviewController.updateWorkOrderPreviewFields(null, null);
            System.assert(false, 'Should have thrown exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('required'), 'Error message should mention required');
        }
        
        Test.stopTest();
    }
}
