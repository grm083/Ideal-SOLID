/**
 * @description Test class for ContactContextGetter
 *
 * This test class provides comprehensive coverage for the ContactContextGetter
 * data access layer, testing contact queries and related object queries (Department, Title).
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class ContactContextGetterTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    @testSetup
    static void setupTestData() {
        // Create accounts
        Account clientAccount = TestDataFactoryRefactored.createAccount('Client', 'Client');
        insert clientAccount;

        // Create contacts
        List<Contact> contacts = TestDataFactoryRefactored.createContacts(5, clientAccount.Id);
        insert contacts;

        // Create Department records (custom object)
        List<Department__c> departments = new List<Department__c>();
        for (Integer i = 0; i < 3; i++) {
            departments.add(new Department__c(
                Name = 'Test Department ' + i,
                Account__c = clientAccount.Id,
                Is_Active__c = true
            ));
        }
        insert departments;

        // Create Account Title records (custom object)
        List<Account_Title__c> titles = new List<Account_Title__c>();
        for (Integer i = 0; i < 3; i++) {
            titles.add(new Account_Title__c(
                Name = 'Test Title ' + i,
                Account__c = clientAccount.Id,
                Is_Active__c = true
            ));
        }
        insert titles;
    }

    // ========================================================================
    // GET CONTACT BY ID TESTS
    // ========================================================================

    @isTest
    static void testGetContactById_SingleContact_Success() {
        // Given: A contact exists
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        Set<Id> contactIds = new Set<Id>{testContact.Id};

        Test.startTest();

        // When: Getting contact by Id
        Map<Id, Contact> result = ContactContextGetter.getContactById(contactIds);

        Test.stopTest();

        // Then: Contact is returned
        System.assertEquals(1, result.size(), 'One contact should be returned');
        System.assert(result.containsKey(testContact.Id), 'Result should contain contact Id');
        System.assertNotEquals(null, result.get(testContact.Id), 'Contact should not be null');
    }

    @isTest
    static void testGetContactById_MultipleContacts_Success() {
        // Given: Multiple contacts exist
        List<Contact> testContacts = [SELECT Id FROM Contact LIMIT 5];
        Set<Id> contactIds = new Set<Id>();
        for (Contact con : testContacts) {
            contactIds.add(con.Id);
        }

        Test.startTest();

        // When: Getting multiple contacts
        Map<Id, Contact> result = ContactContextGetter.getContactById(contactIds);

        Test.stopTest();

        // Then: All contacts are returned
        System.assertEquals(contactIds.size(), result.size(), 'All contacts should be returned');
        for (Id contactId : contactIds) {
            System.assert(result.containsKey(contactId), 'Result should contain contact Id: ' + contactId);
        }
    }

    @isTest
    static void testGetContactById_EmptySet() {
        Test.startTest();

        // When: Getting contacts with empty set
        Map<Id, Contact> result = ContactContextGetter.getContactById(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetContactById_NullSet() {
        Test.startTest();

        // When: Getting contacts with null set
        Map<Id, Contact> result = ContactContextGetter.getContactById(null);

        Test.stopTest();

        // Then: Empty map is returned (method should handle gracefully)
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetContactById_NonExistentId() {
        // Given: A non-existent contact Id
        Id fakeId = '003000000000000AAA';
        Set<Id> contactIds = new Set<Id>{fakeId};

        Test.startTest();

        // When: Getting contact with non-existent Id
        Map<Id, Contact> result = ContactContextGetter.getContactById(contactIds);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, result.size(), 'Empty map should be returned for non-existent Id');
    }

    // ========================================================================
    // GET DEPARTMENT BY ID TESTS
    // ========================================================================

    @isTest
    static void testGetDepartmentById_SingleDepartment_Success() {
        // Given: A department exists
        Department__c testDept = [SELECT Id FROM Department__c LIMIT 1];
        Set<Id> deptIds = new Set<Id>{testDept.Id};

        Test.startTest();

        // When: Getting department by Id
        Map<Id, Department__c> result = ContactContextGetter.getDepartmentById(deptIds);

        Test.stopTest();

        // Then: Department is returned
        System.assertEquals(1, result.size(), 'One department should be returned');
        System.assert(result.containsKey(testDept.Id), 'Result should contain department Id');
        System.assertNotEquals(null, result.get(testDept.Id), 'Department should not be null');
    }

    @isTest
    static void testGetDepartmentById_MultipleDepartments_Success() {
        // Given: Multiple departments exist
        List<Department__c> testDepts = [SELECT Id FROM Department__c LIMIT 3];
        Set<Id> deptIds = new Set<Id>();
        for (Department__c dept : testDepts) {
            deptIds.add(dept.Id);
        }

        Test.startTest();

        // When: Getting multiple departments
        Map<Id, Department__c> result = ContactContextGetter.getDepartmentById(deptIds);

        Test.stopTest();

        // Then: All departments are returned
        System.assertEquals(deptIds.size(), result.size(), 'All departments should be returned');
        for (Id deptId : deptIds) {
            System.assert(result.containsKey(deptId), 'Result should contain department Id: ' + deptId);
        }
    }

    @isTest
    static void testGetDepartmentById_EmptySet() {
        Test.startTest();

        // When: Getting departments with empty set
        Map<Id, Department__c> result = ContactContextGetter.getDepartmentById(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetDepartmentById_NullSet() {
        Test.startTest();

        // When: Getting departments with null set
        Map<Id, Department__c> result = ContactContextGetter.getDepartmentById(null);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    // ========================================================================
    // GET TITLE BY ID TESTS
    // ========================================================================

    @isTest
    static void testGetTitleById_SingleTitle_Success() {
        // Given: A title exists
        Account_Title__c testTitle = [SELECT Id FROM Account_Title__c LIMIT 1];
        Set<Id> titleIds = new Set<Id>{testTitle.Id};

        Test.startTest();

        // When: Getting title by Id
        Map<Id, Account_Title__c> result = ContactContextGetter.getTitleById(titleIds);

        Test.stopTest();

        // Then: Title is returned
        System.assertEquals(1, result.size(), 'One title should be returned');
        System.assert(result.containsKey(testTitle.Id), 'Result should contain title Id');
        System.assertNotEquals(null, result.get(testTitle.Id), 'Title should not be null');
    }

    @isTest
    static void testGetTitleById_MultipleTitles_Success() {
        // Given: Multiple titles exist
        List<Account_Title__c> testTitles = [SELECT Id FROM Account_Title__c LIMIT 3];
        Set<Id> titleIds = new Set<Id>();
        for (Account_Title__c title : testTitles) {
            titleIds.add(title.Id);
        }

        Test.startTest();

        // When: Getting multiple titles
        Map<Id, Account_Title__c> result = ContactContextGetter.getTitleById(titleIds);

        Test.stopTest();

        // Then: All titles are returned
        System.assertEquals(titleIds.size(), result.size(), 'All titles should be returned');
        for (Id titleId : titleIds) {
            System.assert(result.containsKey(titleId), 'Result should contain title Id: ' + titleId);
        }
    }

    @isTest
    static void testGetTitleById_EmptySet() {
        Test.startTest();

        // When: Getting titles with empty set
        Map<Id, Account_Title__c> result = ContactContextGetter.getTitleById(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetTitleById_NullSet() {
        Test.startTest();

        // When: Getting titles with null set
        Map<Id, Account_Title__c> result = ContactContextGetter.getTitleById(null);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Empty map should be returned');
    }

    // ========================================================================
    // INTEGRATION TESTS
    // ========================================================================

    @isTest
    static void testContactWithDepartmentAndTitle_Success() {
        // Given: Contact, Department, and Title exist
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        Department__c testDept = [SELECT Id FROM Department__c LIMIT 1];
        Account_Title__c testTitle = [SELECT Id FROM Account_Title__c LIMIT 1];

        Test.startTest();

        // When: Getting contact, department, and title
        Map<Id, Contact> contactResult = ContactContextGetter.getContactById(
            new Set<Id>{testContact.Id}
        );
        Map<Id, Department__c> deptResult = ContactContextGetter.getDepartmentById(
            new Set<Id>{testDept.Id}
        );
        Map<Id, Account_Title__c> titleResult = ContactContextGetter.getTitleById(
            new Set<Id>{testTitle.Id}
        );

        Test.stopTest();

        // Then: All records are returned
        System.assertEquals(1, contactResult.size(), 'Contact should be returned');
        System.assertEquals(1, deptResult.size(), 'Department should be returned');
        System.assertEquals(1, titleResult.size(), 'Title should be returned');

        System.assert(contactResult.containsKey(testContact.Id), 'Contact should be in result');
        System.assert(deptResult.containsKey(testDept.Id), 'Department should be in result');
        System.assert(titleResult.containsKey(testTitle.Id), 'Title should be in result');
    }

    // ========================================================================
    // GOVERNOR LIMIT TESTS
    // ========================================================================

    @isTest
    static void testBulkOperations_WithinGovernorLimits() {
        // Given: All contacts in the system
        List<Contact> allContacts = [SELECT Id FROM Contact];
        Set<Id> allContactIds = new Set<Id>();
        for (Contact con : allContacts) {
            allContactIds.add(con.Id);
        }

        Test.startTest();

        // When: Getting all contacts in bulk
        Map<Id, Contact> result = ContactContextGetter.getContactById(allContactIds);

        // Then: Operation completes within governor limits
        Integer queriesUsed = Limits.getQueries();
        System.assert(queriesUsed < Limits.getLimitQueries(), 'Should be within SOQL query limits');

        Test.stopTest();

        // And: All contacts are returned
        System.assertEquals(allContactIds.size(), result.size(), 'All contacts should be returned');
    }

    @isTest
    static void testMultipleMethodCalls_PerformanceOptimization() {
        // Given: Contact, department, and title exist
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        Department__c testDept = [SELECT Id FROM Department__c LIMIT 1];
        Account_Title__c testTitle = [SELECT Id FROM Account_Title__c LIMIT 1];

        Test.startTest();

        // When: Calling all methods
        Map<Id, Contact> contacts = ContactContextGetter.getContactById(
            new Set<Id>{testContact.Id}
        );
        Map<Id, Department__c> depts = ContactContextGetter.getDepartmentById(
            new Set<Id>{testDept.Id}
        );
        Map<Id, Account_Title__c> titles = ContactContextGetter.getTitleById(
            new Set<Id>{testTitle.Id}
        );

        Test.stopTest();

        // Then: All queries succeed
        System.assert(contacts.size() > 0, 'Contacts should be returned');
        System.assert(depts.size() > 0, 'Departments should be returned');
        System.assert(titles.size() > 0, 'Titles should be returned');
    }

    // ========================================================================
    // EDGE CASE TESTS
    // ========================================================================

    @isTest
    static void testMixedValidInvalidIds() {
        // Given: Mix of valid and invalid Ids
        Contact validContact = [SELECT Id FROM Contact LIMIT 1];
        Id invalidId = '003000000000000AAA';

        Set<Id> mixedIds = new Set<Id>{validContact.Id, invalidId};

        Test.startTest();

        // When: Getting contacts with mixed Ids
        Map<Id, Contact> result = ContactContextGetter.getContactById(mixedIds);

        Test.stopTest();

        // Then: Only valid contact is returned
        System.assertEquals(1, result.size(), 'Only valid contact should be returned');
        System.assert(result.containsKey(validContact.Id), 'Valid contact should be in result');
        System.assert(!result.containsKey(invalidId), 'Invalid Id should not be in result');
    }
}
