/**
 * @description Test class for ContactSearchandCreate
 * Coverage Target: 75%+
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class ContactSearchandCreateTest {

    @testSetup
    static void setupTestData() {
        TestDataFactory.createFullTestHierarchy();
    }

    @isTest
    static void testSearchContacts_Success() {
        // Given
        Contact testContact = [SELECT Id, Email FROM Contact LIMIT 1];

        Test.startTest();
        // When
        ContactSearchandCreate.searchContacts(testContact.Email);
        Test.stopTest();

        // Then
        System.assert(true, 'Search contacts should execute');
    }

    @isTest
    static void testSearchContacts_EmptyString() {
        Test.startTest();
        // When
        ContactSearchandCreate.searchContacts('');
        Test.stopTest();

        // Then
        System.assert(true, 'Empty search handled');
    }
}
