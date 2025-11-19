/**
 * @description Test class for ServiceDateController
 * 
 * Tests service date management, SLA datetime calculation, and WM Capacity Planner
 * visibility logic for the unified case management system.
 * 
 * @author Claude (AI Assistant)
 * @date 2025-11-18
 * @group Test Classes
 */
@isTest
private class ServiceDateControllerTest {
    
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
            Service_Date__c = Date.today().addDays(7)
        );
        insert testCase;
    }
    
    /**
     * Test getServiceDateInfo method
     */
    @isTest
    static void testGetServiceDateInfo() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        ServiceDateController.ServiceDateInfo result = 
            ServiceDateController.getServiceDateInfo(testCase.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(Date.today().addDays(7), result.serviceDate, 'Service date should match');
    }
    
    /**
     * Test updateServiceDate method
     */
    @isTest
    static void testUpdateServiceDate() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Date newServiceDate = Date.today().addDays(14);
        DateTime newSLADateTime = DateTime.now().addDays(14);
        
        Test.startTest();
        ServiceDateController.updateServiceDate(testCase.Id, newServiceDate, newSLADateTime);
        Test.stopTest();
        
        Case updatedCase = [SELECT Service_Date__c, SLA_Service_Date_Time__c 
                           FROM Case WHERE Id = :testCase.Id];
        
        System.assertEquals(newServiceDate, updatedCase.Service_Date__c, 'Service date should be updated');
        System.assertEquals(newSLADateTime, updatedCase.SLA_Service_Date_Time__c, 'SLA datetime should be updated');
    }
    
    /**
     * Test updateMultiCalendarChecked method
     */
    @isTest
    static void testUpdateMultiCalendarChecked() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        ServiceDateController.updateMultiCalendarChecked(testCase.Id, true);
        Test.stopTest();
        
        Case updatedCase = [SELECT Is_MultiCalendar_Checked__c 
                           FROM Case WHERE Id = :testCase.Id];
        
        System.assertEquals(true, updatedCase.Is_MultiCalendar_Checked__c, 
                          'Multi-calendar flag should be updated');
    }
    
    /**
     * Test calculateSLADateTime method with valid inputs
     */
    @isTest
    static void testCalculateSLADateTime() {
        Date serviceDate = Date.today().addDays(7);
        String serviceTime = '14:30';
        
        Test.startTest();
        DateTime result = ServiceDateController.calculateSLADateTime(serviceDate, serviceTime);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(14, result.hour(), 'Hour should be 14');
        System.assertEquals(30, result.minute(), 'Minute should be 30');
    }
    
    /**
     * Test calculateSLADateTime method with default time
     */
    @isTest
    static void testCalculateSLADateTimeWithDefaultTime() {
        Date serviceDate = Date.today().addDays(7);
        
        Test.startTest();
        DateTime result = ServiceDateController.calculateSLADateTime(serviceDate, '');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(8, result.hour(), 'Default hour should be 8');
        System.assertEquals(0, result.minute(), 'Default minute should be 0');
    }
    
    /**
     * Test validateServiceDate method
     */
    @isTest
    static void testValidateServiceDate() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = ServiceDateController.validateServiceDate(testCase.Id);
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
        
        // Test null case ID
        ServiceDateController.ServiceDateInfo result1 = 
            ServiceDateController.getServiceDateInfo(null);
        System.assertNotEquals(null, result1, 'Should handle null input gracefully');
        
        // Test null service date
        DateTime result2 = ServiceDateController.calculateSLADateTime(null, '10:00');
        System.assertEquals(null, result2, 'Should return null for null service date');
        
        Test.stopTest();
    }
}
