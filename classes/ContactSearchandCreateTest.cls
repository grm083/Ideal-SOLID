/**
 * @description Comprehensive test class for ContactSearchandCreate
 * Coverage Target: 75%+
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class ContactSearchandCreateTest {

    @testSetup
    static void setupTestData() {
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();

        // Get the created records
        Account clientAccount = (Account)testData.get('clientAccount');
        Account locationAccount = (Account)testData.get('locationAccount');
        Account vendorAccount = (Account)testData.get('vendorAccount');
        Contact contact = (Contact)testData.get('contact');
        Case testCase = (Case)testData.get('case');

        // Create additional contacts for search testing
        List<Contact> additionalContacts = new List<Contact>();
        for (Integer i = 0; i < 3; i++) {
            Contact con = TestDataFactoryRefactored.createContact(clientAccount.Id);
            con.FirstName = 'SearchTest' + i;
            con.LastName = 'Contact' + i;
            con.Email = 'searchtest' + i + '@example.com';
            con.Phone = '555-010' + i;
            con.MobilePhone = '555-020' + i;
            con.Location__c = locationAccount.Id;
            con.Contact_Status__c = 'Active';
            additionalContacts.add(con);
        }
        insert additionalContacts;

        // Create Account Title records
        Account_Title__c accountTitle = new Account_Title__c(
            Name = 'Test Title',
            Account__c = clientAccount.Id,
            Status__c = 'Active'
        );
        insert accountTitle;

        // Update contact with account title
        contact.Account_Title__c = accountTitle.Id;
        update contact;

        // Create Department
        Department__c dept = new Department__c(
            Name = 'Test Department',
            Account__c = clientAccount.Id
        );
        insert dept;

        // Create Asset with vendor for returnVendors test
        Product2 prod = (Product2)testData.get('product');
        Asset vendorAsset = TestDataFactoryRefactored.createAsset(locationAccount.Id, prod.Id);
        vendorAsset.Supplier__c = vendorAccount.Id;
        vendorAsset.RecordTypeId = TestDataFactoryRefactored.getRecordTypeId('Asset', 'Service_Header');
        insert vendorAsset;

        // Create AccountContactRelation for vendor
        AccountContactRelation acr = new AccountContactRelation(
            AccountId = vendorAccount.Id,
            ContactId = contact.Id,
            Roles = 'Decision Maker',
            Type__c = 'Vendor'
        );
        insert acr;

        // Create AccountTeamMember
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        AccountTeamMember atm = new AccountTeamMember(
            AccountId = clientAccount.Id,
            UserId = testUser.Id,
            TeamMemberRole = 'Account Manager'
        );
        insert atm;
    }

    @isTest
    static void testReturnCase_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        Case result = ContactSearchandCreate.returnCase(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Should return case record');
        System.assertEquals(testCase.Id, result.Id, 'Should return correct case');
    }

    @isTest
    static void testReturnCaseLastCreated_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        Case result = ContactSearchandCreate.returnCaseLastCreated(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Should return case record');
        System.assertEquals(testCase.Id, result.Id, 'Should return correct case');
    }

    @isTest
    static void testSearchLocCont_WithClientAccount() {
        // Given
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];

        Test.startTest();
        // When
        List<ContactSearchandCreate.allContacts> results = ContactSearchandCreate.searchLocCont(clientAccount.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return contact list');
    }

    @isTest
    static void testSearchLocCont_WithLocationAccount() {
        // Given
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];

        Test.startTest();
        // When
        List<ContactSearchandCreate.allContacts> results = ContactSearchandCreate.searchLocCont(locationAccount.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return contact list');
    }

    @isTest
    static void testSearchContact_WithSOSL() {
        // Given
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];
        String searchQuery = 'Test';

        Test.startTest();
        // When
        List<ContactSearchandCreate.allContacts> results = ContactSearchandCreate.searchContact(searchQuery, clientAccount.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return search results');
    }

    @isTest
    static void testSearchContacts_WithAllParameters() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];
        Contact testContact = [SELECT FirstName, LastName, Email, Phone, MobilePhone FROM Contact LIMIT 1];

        Test.startTest();
        // When
        List<ContactSearchandCreate.allContacts> results = ContactSearchandCreate.searchContacts(
            testContact.FirstName,
            testContact.LastName,
            testContact.Email,
            testContact.Phone,
            testContact.MobilePhone,
            clientAccount.Id,
            testCase.Id
        );
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return search results');
    }

    @isTest
    static void testSearchContacts_WithOnlyLastName() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];

        Test.startTest();
        // When
        List<ContactSearchandCreate.allContacts> results = ContactSearchandCreate.searchContacts(
            '',
            'Contact',
            '',
            '',
            '',
            clientAccount.Id,
            testCase.Id
        );
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return search results');
    }

    @isTest
    static void testSearchContacts_WithOnlyEmail() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];

        Test.startTest();
        // When
        List<ContactSearchandCreate.allContacts> results = ContactSearchandCreate.searchContacts(
            '',
            '',
            'searchtest0@example.com',
            '',
            '',
            clientAccount.Id,
            testCase.Id
        );
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return search results');
    }

    @isTest
    static void testSearchContacts_EmptyString() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];

        Test.startTest();
        // When
        List<ContactSearchandCreate.allContacts> results = ContactSearchandCreate.searchContacts(
            '',
            '',
            '',
            '',
            '',
            clientAccount.Id,
            testCase.Id
        );
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should handle empty search');
    }

    @isTest
    static void testSearchVendors_Success() {
        // Given
        String searchQuery = 'Vendor';

        Test.startTest();
        // When
        List<ContactSearchandCreate.allVendors> results = ContactSearchandCreate.searchVendors(searchQuery);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return vendor list');
    }

    @isTest
    static void testReturnVendors_Success() {
        // Given
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];

        Test.startTest();
        // When
        List<ContactSearchandCreate.allVendors> results = ContactSearchandCreate.returnVendors(locationAccount.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return vendor list');
    }

    @isTest
    static void testExistingContact_CustomerType_ActiveTitle() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE Account_Title__c != null LIMIT 1];
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];

        Test.startTest();
        // When
        Boolean result = ContactSearchandCreate.existingContact(
            testCase.Id,
            testContact.Id,
            clientAccount.Id,
            'Customer'
        );
        Test.stopTest();

        // Then
        System.assertEquals(false, result, 'Should return false for active title');

        // Verify case was updated
        Case updatedCase = [SELECT ContactId FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(testContact.Id, updatedCase.ContactId, 'Case should be updated with contact');
    }

    @isTest
    static void testExistingContact_VendorType() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        Account vendorAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Vendor' LIMIT 1];

        Test.startTest();
        // When
        Boolean result = ContactSearchandCreate.existingContact(
            testCase.Id,
            testContact.Id,
            vendorAccount.Id,
            'Vendor'
        );
        Test.stopTest();

        // Then
        System.assertEquals(false, result, 'Should return false for active contact');
    }

    @isTest
    static void testGetVendorRoles_Success() {
        Test.startTest();
        // When
        List<ContactSearchandCreate.dualList> results = ContactSearchandCreate.getVendorRoles();
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return roles list');
    }

    @isTest
    static void testGetAccountTitles_Success() {
        // Given
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];

        Test.startTest();
        // When
        List<ContactSearchandCreate.dualList> results = ContactSearchandCreate.getAccountTitles(clientAccount.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return account titles');
        System.assert(results.size() > 0, 'Should have at least one title');
    }

    @isTest
    static void testGetAccountDepts_Success() {
        // Given
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];

        Test.startTest();
        // When
        List<ContactSearchandCreate.dualList> results = ContactSearchandCreate.getAccountDepts(clientAccount.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return departments');
        System.assert(results.size() > 0, 'Should have at least one department');
    }

    @isTest
    static void testNewTitle_Success() {
        // Given
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];
        String titleName = 'New Test Title';

        Test.startTest();
        // When
        Id titleId = ContactSearchandCreate.newTitle(clientAccount.Id, titleName);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, titleId, 'Should return title Id');

        // Verify title was created
        Account_Title__c createdTitle = [SELECT Name, Status__c FROM Account_Title__c WHERE Id = :titleId];
        System.assertEquals(titleName, createdTitle.Name, 'Should create title with correct name');
        System.assertEquals('Active', createdTitle.Status__c, 'Should set status to Active');
    }

    @isTest
    static void testGetVendorContacts_Success() {
        // Given
        Account vendorAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Vendor' LIMIT 1];

        Test.startTest();
        // When
        List<ContactSearchandCreate.allContacts> results = ContactSearchandCreate.getVendorContacts(vendorAccount.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return vendor contacts');
    }

    @isTest
    static void testCheckDuplicateContacts_NoDuplicates() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];
        Account_Title__c accountTitle = [SELECT Id FROM Account_Title__c LIMIT 1];

        Test.startTest();
        // When
        List<ContactSearchandCreate.allContacts> results = ContactSearchandCreate.checkDuplicateContacts(
            'UniqueFirstName',
            'UniqueLastName',
            'unique@example.com',
            '555-9999',
            '555-8888',
            clientAccount.Id,
            accountTitle.Id,
            null,
            'Email',
            '123',
            testCase.Id
        );
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return results list');
        System.assertEquals(1, results.size(), 'Should return the new contact being created');
    }

    @isTest
    static void testCheckDuplicateContacts_WithDuplicates() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Contact existingContact = [SELECT FirstName, LastName, Email, AccountId FROM Contact LIMIT 1];
        Account_Title__c accountTitle = [SELECT Id FROM Account_Title__c LIMIT 1];

        Test.startTest();
        // When
        List<ContactSearchandCreate.allContacts> results = ContactSearchandCreate.checkDuplicateContacts(
            existingContact.FirstName,
            existingContact.LastName,
            existingContact.Email,
            '',
            '',
            existingContact.AccountId,
            accountTitle.Id,
            null,
            'Email',
            '',
            testCase.Id
        );
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return results list');
        System.assert(results.size() >= 1, 'Should find duplicate contact');
    }

    @isTest
    static void testCreateNewContact_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];
        Account_Title__c accountTitle = [SELECT Id FROM Account_Title__c LIMIT 1];
        Department__c dept = [SELECT Id FROM Department__c LIMIT 1];

        Test.startTest();
        // When
        Id newContactId = ContactSearchandCreate.createNewContact(
            'NewFirst',
            'NewLast',
            clientAccount.Id,
            testCase.Id,
            '555-1234',
            'newcontact@example.com',
            accountTitle.Id,
            dept.Id,
            'Email',
            '456'
        );
        Test.stopTest();

        // Then
        System.assertNotEquals(null, newContactId, 'Should return new contact Id');

        // Verify contact was created
        Contact createdContact = [SELECT FirstName, LastName, Email, Phone FROM Contact WHERE Id = :newContactId];
        System.assertEquals('NewFirst', createdContact.FirstName, 'Should set first name');
        System.assertEquals('NewLast', createdContact.LastName, 'Should set last name');
        System.assertEquals('newcontact@example.com', createdContact.Email, 'Should set email');
    }

    @isTest
    static void testCreateNewContact_WithoutDepartment() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];
        Account_Title__c accountTitle = [SELECT Id FROM Account_Title__c LIMIT 1];

        Test.startTest();
        // When
        Id newContactId = ContactSearchandCreate.createNewContact(
            'NewFirst2',
            'NewLast2',
            clientAccount.Id,
            testCase.Id,
            '555-5678',
            'newcontact2@example.com',
            accountTitle.Id,
            '',
            'Phone',
            ''
        );
        Test.stopTest();

        // Then
        System.assertNotEquals(null, newContactId, 'Should return new contact Id');
    }

    @isTest
    static void testCreateNewVenContact_Success() {
        // Given
        Account vendorAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Vendor' LIMIT 1];

        Test.startTest();
        // When
        Id newContactId = ContactSearchandCreate.createNewVenContact(
            'VendorFirst',
            'VendorLast',
            vendorAccount.Id,
            '555-7890',
            'vendor@example.com',
            'Email',
            '789'
        );
        Test.stopTest();

        // Then
        System.assertNotEquals(null, newContactId, 'Should return new vendor contact Id');

        // Verify contact was created
        Contact createdContact = [SELECT FirstName, LastName, Email FROM Contact WHERE Id = :newContactId];
        System.assertEquals('VendorFirst', createdContact.FirstName, 'Should set first name');
        System.assertEquals('VendorLast', createdContact.LastName, 'Should set last name');
    }

    @isTest
    static void testGetAccountTeam_Success() {
        // Given
        Account clientAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Client' LIMIT 1];

        Test.startTest();
        // When
        List<ContactSearchandCreate.allContacts> results = ContactSearchandCreate.getAccountTeam(clientAccount.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return account team members');
    }

    @isTest
    static void testGetUsers_Success() {
        Test.startTest();
        // When
        List<ContactSearchandCreate.allContacts> results = ContactSearchandCreate.getUsers('Test');
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return user list');
    }

    @isTest
    static void testSaveUserToCase_NewInternalContact() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Test.startTest();
        // When
        ContactSearchandCreate.saveUserToCase(testCase.Id, testUser.Id);
        Test.stopTest();

        // Then
        Case updatedCase = [SELECT Requested_By_User__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(testUser.Id, updatedCase.Requested_By_User__c, 'Should set requested by user');
    }

    @isTest
    static void testSaveUserToCase_ExistingInternalContact() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        User testUser = [SELECT Id, FirstName, LastName FROM User WHERE Id = :UserInfo.getUserId()];

        // Create internal contact for user first
        Contact internalContact = new Contact(
            FirstName = testUser.FirstName,
            LastName = testUser.LastName,
            Internal_User_ID__c = testUser.Id
        );
        insert internalContact;

        Test.startTest();
        // When
        ContactSearchandCreate.saveUserToCase(testCase.Id, testUser.Id);
        Test.stopTest();

        // Then
        Case updatedCase = [SELECT Requested_By_User__c, ContactId FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(testUser.Id, updatedCase.Requested_By_User__c, 'Should set requested by user');
        System.assertEquals(internalContact.Id, updatedCase.ContactId, 'Should use existing internal contact');
    }

    @isTest
    static void testGetInvalidVendors_Success() {
        Test.startTest();
        // When
        List<String> invalidVendors = ContactSearchandCreate.getInvalidVendors();
        Test.stopTest();

        // Then
        System.assertNotEquals(null, invalidVendors, 'Should return invalid vendor list');
        System.assert(invalidVendors.size() > 0, 'Should have invalid vendors');
        System.assert(invalidVendors.contains('200092'), 'Should contain specific invalid vendor');
    }

    @isTest
    static void testWrapperClasses_AllContacts() {
        // When
        ContactSearchandCreate.allContacts wrapper = new ContactSearchandCreate.allContacts(
            UserInfo.getUserId(),
            'Test Name',
            'Test Title',
            'Test Company',
            '555-0000',
            'test@example.com',
            'Yes',
            Date.today()
        );

        // Then
        System.assertEquals(UserInfo.getUserId(), wrapper.ContactId, 'Should set contact ID');
        System.assertEquals('Test Name', wrapper.Name, 'Should set name');
        System.assertEquals('Test Title', wrapper.Title, 'Should set title');
        System.assertEquals('Test Company', wrapper.Company, 'Should set company');
        System.assertEquals('555-0000', wrapper.Phone, 'Should set phone');
        System.assertEquals('test@example.com', wrapper.Email, 'Should set email');
        System.assertEquals('Yes', wrapper.BusinessRuleAssociation, 'Should set business rule association');
        System.assertEquals(Date.today(), wrapper.LastActivityDate, 'Should set last activity date');
    }

    @isTest
    static void testWrapperClasses_AllVendors() {
        // When
        ContactSearchandCreate.allVendors wrapper = new ContactSearchandCreate.allVendors(
            UserInfo.getUserId(),
            'Vendor Name',
            'VEN123'
        );

        // Then
        System.assertEquals(UserInfo.getUserId(), wrapper.AccountId, 'Should set account ID');
        System.assertEquals('Vendor Name', wrapper.Name, 'Should set name');
        System.assertEquals('VEN123', wrapper.VID, 'Should set VID');
    }

    @isTest
    static void testWrapperClasses_DualList() {
        // When
        ContactSearchandCreate.dualList wrapper = new ContactSearchandCreate.dualList(
            'Test Label',
            'test_value'
        );

        // Then
        System.assertEquals('Test Label', wrapper.label, 'Should set label');
        System.assertEquals('test_value', wrapper.value, 'Should set value');
    }
}
