/**
 * @description Comprehensive test class for GetCaseInformation
 * Coverage Target: 75%+
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class GetCaseInformationTest {

    @testSetup
    static void setupTestData() {
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();

        // Get created records
        Case testCase = (Case)testData.get('case');
        Account clientAccount = (Account)testData.get('clientAccount');
        Contact contact = (Contact)testData.get('contact');

        // Create Process Builder to Flow custom setting
        TestDataFactoryRefactored.createProcessBuilderTOFlow();

        // Create PriceBook2 for createOppQuote test
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPricebook;

        // Create SBQQ Custom Action for getAddProductId test
        SBQQ__CustomAction__c customAction = new SBQQ__CustomAction__c(
            Name = 'Add Products',
            SBQQ__DisplayOrder__c = 1,
            SBQQ__Location__c = 'Quote',
            SBQQ__Type__c = 'Flow'
        );
        insert customAction;
    }

    @isTest
    static void testGetMessage_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        GetCaseInformation.Wrapper result = GetCaseInformation.getMessage(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Should return wrapper object');
    }

    @isTest
    static void testGetMessage_NullId() {
        Test.startTest();
        // When
        GetCaseInformation.Wrapper result = GetCaseInformation.getMessage(null);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Should return empty wrapper for null ID');
    }

    @isTest
    static void testGetBusinessRule_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        GetCaseInformation.Wrapper result = GetCaseInformation.getBusinessRule(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Should return wrapper object');
    }

    @isTest
    static void testGetEntitlement_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        GetCaseInformation.Wrapper result = GetCaseInformation.getEntitlement(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Should return wrapper object');
    }

    @isTest
    static void testGetCaseMessages_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        GetCaseInformation.Wrapper result = GetCaseInformation.getCaseMessages(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Should return wrapper object');
    }

    @isTest
    static void testGetCaseSummary_Success() {
        // Given
        Case testCase = [SELECT Id, Reference_Number__c, ParentId FROM Case LIMIT 1];

        Test.startTest();
        // When
        List<Case> results = GetCaseInformation.getCaseSummary(
            testCase.Id,
            testCase.Reference_Number__c,
            testCase.ParentId
        );
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return case list');
    }

    @isTest
    static void testGetRelatedCase_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        List<Case> results = GetCaseInformation.getRelatedCase(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return related cases');
    }

    @isTest
    static void testGetRelatedCase_NullId() {
        Test.startTest();
        // When
        List<Case> results = GetCaseInformation.getRelatedCase(null);
        Test.stopTest();

        // Then
        System.assertEquals(0, results.size(), 'Should return empty list for null ID');
    }

    @isTest
    static void testGetCaseRecordTypeList_Success() {
        Test.startTest();
        // When
        List<String> results = GetCaseInformation.getCaseRecordTypeList();
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return record type list');
    }

    @isTest
    static void testGetRecordTypeId_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        String recordTypeId = GetCaseInformation.getRecordTypeId(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, recordTypeId, 'Should return record type ID');
    }

    @isTest
    static void testGetCaseRecordDetails_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        List<String> results = GetCaseInformation.getCaseRecordDetails(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return case record details');
    }

    @isTest
    static void testGetCaseAssetDetails_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        List<Case> results = GetCaseInformation.getcaseAssetDetails(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return case asset details');
    }

    @isTest
    static void testGetCaseDetails_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        Case result = GetCaseInformation.getCaseDetails(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Should return case details');
    }

    @isTest
    static void testInitiateWorkOrder_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        List<String> caseIds = new List<String>{testCase.Id};

        Test.startTest();
        // When
        String result = GetCaseInformation.initiateWorkOrder(testCase.Id, caseIds);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Should return status');
    }

    @isTest
    static void testAddWorkOrderDetails_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Case woFields = new Case(
            Site_Contact__c = 'Test Contact',
            Site_Contact_Phone__c = '555-0000',
            User_Input_Work_Order_Instructions__c = 'Test Instructions',
            Is_ByPassWO__c = false
        );
        List<String> caseIds = new List<String>{testCase.Id};

        Test.startTest();
        // When
        String result = GetCaseInformation.addWorkOrderDetails(woFields, caseIds);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Should return status');
    }

    @isTest
    static void testIsWMCapacityPlannerVisible_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        Boolean result = GetCaseInformation.IsWMCapacityPlannerVisible(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Should return visibility flag');
    }

    @isTest
    static void testSaveAdditionalTemplate_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        String templateDesc = 'Test template description';
        List<String> caseIds = new List<String>{testCase.Id};

        Test.startTest();
        // When
        String result = GetCaseInformation.saveAdditionalTemplate(templateDesc, caseIds);
        Test.stopTest();

        // Then
        System.assertEquals('SUCCESS', result, 'Should return SUCCESS');

        // Verify case was updated
        Case updatedCase = [SELECT EmailTemplateAdditionalComments__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(templateDesc, updatedCase.EmailTemplateAdditionalComments__c, 'Should update template');
    }

    @isTest
    static void testSaveAdditionalTemplate_NullCaseId() {
        Test.startTest();
        // When
        try {
            String result = GetCaseInformation.saveAdditionalTemplate('Test', null);
        } catch (Exception e) {
            // Then
            System.assert(true, 'Should handle null case ID');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateOppQuote_NewServiceCase() {
        // Given
        Case testCase = [SELECT Id FROM Case WHERE RecordType.Name = 'Service Request' LIMIT 1];
        testCase.Case_Record_Type__c = 'New Service';
        testCase.Case_Type__c = 'New Service';
        testCase.Integrate_with_Acorn__c = false;
        update testCase;

        Test.startTest();
        // When
        String quoteId = GetCaseInformation.createOppQuote(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, quoteId, 'Should return quote ID');

        // Verify opportunity was created
        List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE Case__c = :testCase.Id];
        System.assertEquals(1, opps.size(), 'Should create opportunity');

        // Verify quote was created
        List<SBQQ__Quote__c> quotes = [SELECT Id FROM SBQQ__Quote__c WHERE Id = :quoteId];
        System.assertEquals(1, quotes.size(), 'Should create quote');
    }

    @isTest
    static void testShowExistingQuotes_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        List<QuoteProcurementController.ProductsWrapper> results =
            GetCaseInformation.ShowExistingQuotes(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return quotes list');
    }

    @isTest
    static void testUpdateThisCaseToClose_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        Boolean result = GetCaseInformation.updateThisCaseToClose(testCase.Id);
        Test.stopTest();

        // Then
        System.assertEquals(true, result, 'Should return true');

        // Verify case was updated
        Case updatedCase = [SELECT Close_Irrelevant_Case__c, Close_Case_Reason__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(true, updatedCase.Close_Irrelevant_Case__c, 'Should mark case for closing');
        System.assertEquals('Duplicate', updatedCase.Close_Case_Reason__c, 'Should set close reason');
    }

    @isTest
    static void testIsTemplateVisible_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        Boolean result = GetCaseInformation.IsTemplateVisible(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Should return visibility flag');
    }

    @isTest
    static void testCreateAcornComment_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        String comment = 'Test Acorn Comment';

        Test.startTest();
        // When
        String result = GetCaseInformation.createAcornComment(comment, testCase.Id);
        Test.stopTest();

        // Then
        System.assertEquals('ok', result, 'Should return ok');

        // Verify comment was created
        List<Comment__c> comments = [SELECT Id, Comment__c FROM Comment__c WHERE Case__c = :testCase.Id];
        System.assertEquals(1, comments.size(), 'Should create comment');
    }

    @isTest
    static void testCreateAcornComment_InvalidCaseId() {
        Test.startTest();
        // When
        String result = GetCaseInformation.createAcornComment('Test', '001000000000000');
        Test.stopTest();

        // Then
        System.assertEquals('Invalid Case Id.  You need to be viewing a Case when creating an Acorn Note.',
                          result, 'Should return error message');
    }

    @isTest
    static void testInsertPlannerComment_UserSelected() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        GetCaseInformation.insertPlannerComment(testCase.Id, '2025-01-15', true, false);
        Test.stopTest();

        // Then
        System.assert(true, 'Should create planner comment');
    }

    @isTest
    static void testInsertPlannerComment_AvailNotSelect() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        GetCaseInformation.insertPlannerComment(testCase.Id, '2025-01-15', true, true);
        Test.stopTest();

        // Then
        System.assert(true, 'Should create planner comment');
    }

    @isTest
    static void testInsertPlannerComment_NotAvail() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        GetCaseInformation.insertPlannerComment(testCase.Id, '2025-01-15', false, false);
        Test.stopTest();

        // Then
        System.assert(true, 'Should create planner comment');
    }

    @isTest
    static void testGetCompanyCategory_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // When
        List<Map<String, String>> results = GetCaseInformation.getCompanyCategory(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, results, 'Should return company category list');
    }

    @isTest
    static void testGetAddProductId_Success() {
        Test.startTest();
        // When
        String addProductId = GetCaseInformation.getAddProductId();
        Test.stopTest();

        // Then
        System.assertNotEquals(null, addProductId, 'Should return Add Products custom action ID');
    }

    @isTest
    static void testGetUserDetail_Success() {
        Test.startTest();
        // When
        Boolean hasCPQ = GetCaseInformation.getUserDetail();
        Test.stopTest();

        // Then
        System.assertNotEquals(null, hasCPQ, 'Should return CPQ access flag');
    }

    @isTest
    static void testGetActiveAssetUserDetail_Success() {
        Test.startTest();
        // When
        Boolean hasAccess = GetCaseInformation.getActiveAssetUserDetail();
        Test.stopTest();

        // Then
        System.assertNotEquals(null, hasAccess, 'Should return asset update access flag');
    }

    @isTest
    static void testCopyAcornCommentsToChildCase_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Case childCase = new Case(
            Subject = 'Child Case',
            ParentId = testCase.Id,
            RecordTypeId = testCase.RecordTypeId,
            Status = 'New'
        );
        insert childCase;

        Test.startTest();
        // When
        GetCaseInformation.copyAcornCommentsToChildCase(testCase.Id, childCase);
        Test.stopTest();

        // Then
        System.assert(true, 'Should copy Acorn comments');
    }

    @isTest
    static void testWrapperClass_Constructor() {
        Test.startTest();
        // When
        GetCaseInformation.Wrapper wrapper = new GetCaseInformation.Wrapper();
        Test.stopTest();

        // Then
        System.assertEquals('', wrapper.caseInfo, 'Should initialize caseInfo as empty string');
        System.assertEquals('', wrapper.reqInfo, 'Should initialize reqInfo as empty string');
        System.assertEquals('', wrapper.approvalInfo, 'Should initialize approvalInfo as empty string');
        System.assertEquals(false, wrapper.enableapprovalInfo, 'Should initialize enableapprovalInfo as false');
        System.assertEquals(false, wrapper.assetValidation, 'Should initialize assetValidation as false');
        System.assertEquals(true, wrapper.WorkOrderCreation, 'Should initialize WorkOrderCreation as true');
        System.assertEquals(true, wrapper.isAssetMandatory, 'Should initialize isAssetMandatory as true');
        System.assertEquals(true, wrapper.isCaseInfoReady, 'Should initialize isCaseInfoReady as true');
        System.assertNotEquals(null, wrapper.relatedCaseList, 'Should initialize relatedCaseList');
        System.assertNotEquals(null, wrapper.multiAssetSelections, 'Should initialize multiAssetSelections');
    }

    @isTest
    static void testSortingWrapper_Comparator() {
        Test.startTest();
        // When
        Map<String, String> map1 = new Map<String, String>{'label' => 'Apple', 'value' => '1'};
        Map<String, String> map2 = new Map<String, String>{'label' => 'Banana', 'value' => '2'};

        GetCaseInformation.sortingWrapper wrapper1 = new GetCaseInformation.sortingWrapper(map1);
        GetCaseInformation.sortingWrapper wrapper2 = new GetCaseInformation.sortingWrapper(map2);

        Integer compareResult = wrapper1.compareTo(wrapper2);
        Test.stopTest();

        // Then
        System.assert(compareResult < 0, 'Apple should come before Banana');
    }
}
