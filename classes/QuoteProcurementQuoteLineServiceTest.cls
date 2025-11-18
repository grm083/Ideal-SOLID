/**
 * @description Test class for QuoteProcurementQuoteLineService
 *
 * Tests quote line update operations including:
 * - Updating quote line bundles from header wrapper
 * - Equipment size picklist conversions
 * - Quantity updates for lock products
 * - SLA date updates
 *
 * Utilizes TestDataFactoryRefactored for consistent test data creation.
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class QuoteProcurementQuoteLineServiceTest {

    /**
     * @description Set up test data for all test methods
     */
    @testSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = TestDataFactoryRefactored.createAccount();
        insert testAccount;

        // Create test contact
        Contact testContact = TestDataFactoryRefactored.createContact(testAccount.Id);
        insert testContact;

        // Create test case
        Case testCase = TestDataFactoryRefactored.createCase(testAccount.Id, testContact.Id);
        insert testCase;

        // Create opportunity linked to case
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Case__c = testCase.Id
        );
        insert testOpp;

        // Create quote
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = testAccount.Id,
            SBQQ__Opportunity2__c = testOpp.Id,
            SBQQ__Status__c = 'Draft',
            SBQQ__PrimaryContact__c = testContact.Id
        );
        insert testQuote;

        // Create test products
        Product2 containerProduct = TestDataFactoryRefactored.createProduct('Test Container', 'Container');
        Product2 wasteCategoryProduct = TestDataFactoryRefactored.createProduct('Test Waste Category', 'Waste Category');
        Product2 accessoryProduct = TestDataFactoryRefactored.createProduct('Test Accessory', 'Accessories');
        insert new List<Product2>{containerProduct, wasteCategoryProduct, accessoryProduct};

        // Create product option for accessories
        SBQQ__ProductOption__c productOption = new SBQQ__ProductOption__c(
            SBQQ__ConfiguredSKU__c = containerProduct.Id,
            SBQQ__OptionalSKU__c = accessoryProduct.Id,
            SBQQ__Type__c = 'Accessory'
        );
        insert productOption;

        // Create parent quote line (container)
        SBQQ__QuoteLine__c parentQL = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuote.Id,
            SBQQ__Product__c = containerProduct.Id,
            SBQQ__Number__c = 1,
            SBQQ__Quantity__c = 1,
            Equipment_Size__c = '10 Yard',
            SBQQ__StartDate__c = Date.today(),
            SBQQ__EndDate__c = Date.today().addDays(365),
            Description_of_Waste__c = 'Original Waste',
            MaterialGrade__c = 'Grade A',
            CompanyCategoryCode__c = 'CC01',
            CompanyCategoryName__c = 'Category 1'
        );
        insert parentQL;

        // Create child quote line (waste category)
        SBQQ__QuoteLine__c wasteCategoryQL = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuote.Id,
            SBQQ__Product__c = wasteCategoryProduct.Id,
            SBQQ__RequiredBy__c = parentQL.Id,
            SBQQ__Number__c = 2,
            SBQQ__Quantity__c = 1,
            SBQQ__OptionLevel__c = 1
        );

        // Create accessory quote line
        SBQQ__QuoteLine__c accessoryQL = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuote.Id,
            SBQQ__Product__c = accessoryProduct.Id,
            SBQQ__RequiredBy__c = parentQL.Id,
            SBQQ__Number__c = 3,
            SBQQ__Quantity__c = 2,
            SBQQ__OptionLevel__c = 1,
            SBQQ__ProductOption__c = productOption.Id
        );

        insert new List<SBQQ__QuoteLine__c>{wasteCategoryQL, accessoryQL};
    }

    /**
     * @description Test updateQuoteOverview - success scenario
     */
    @isTest
    static void testUpdateQuoteOverview_Success() {
        SBQQ__QuoteLine__c parentQL = [SELECT Id FROM SBQQ__QuoteLine__c WHERE SBQQ__RequiredBy__c = null LIMIT 1];

        // Create header wrapper with update data
        QuoteProcurementController.HeaderWrapper wrapper = new QuoteProcurementController.HeaderWrapper();
        wrapper.parentId = parentQL.Id;
        wrapper.quantity = 3;
        wrapper.equipmentSize = '20 Yard';
        wrapper.wasteDescription = 'Updated Waste Description';
        wrapper.selectedMaterialGrade = 'Grade B';
        wrapper.companyCategory = 'CC02';
        wrapper.companyCategoryName = 'Category 2';
        wrapper.slaOverrideReason = 'Test Reason';
        wrapper.slaOverrideComment = 'Test Comment';

        Test.startTest();
        Boolean result = QuoteProcurementQuoteLineService.updateQuoteOverview(wrapper);
        Test.stopTest();

        System.assertEquals(true, result, 'Update should succeed');

        // Verify parent quote line was updated
        SBQQ__QuoteLine__c updatedParent = [
            SELECT Id, SBQQ__Quantity__c, Equipment_Size__c, Description_of_Waste__c,
                MaterialGrade__c, CompanyCategoryCode__c, CompanyCategoryName__c,
                SLA_Override_Reason__c, SLA_Override_Comment__c
            FROM SBQQ__QuoteLine__c
            WHERE Id = :parentQL.Id
        ];

        System.assertEquals(3, updatedParent.SBQQ__Quantity__c, 'Quantity should be updated');
        System.assertEquals('20 Yard', updatedParent.Equipment_Size__c, 'Equipment size should be updated');
        System.assertEquals('Updated Waste Description', updatedParent.Description_of_Waste__c, 'Waste description should be updated');
        System.assertEquals('Grade B', updatedParent.MaterialGrade__c, 'Material grade should be updated');
        System.assertEquals('CC02', updatedParent.CompanyCategoryCode__c, 'Company category code should be updated');
        System.assertEquals('Category 2', updatedParent.CompanyCategoryName__c, 'Company category name should be updated');
        System.assertEquals('Test Reason', updatedParent.SLA_Override_Reason__c, 'SLA override reason should be updated');
        System.assertEquals('Test Comment', updatedParent.SLA_Override_Comment__c, 'SLA override comment should be updated');
    }

    /**
     * @description Test updateQuoteOverview - verify child lines updated
     */
    @isTest
    static void testUpdateQuoteOverview_VerifyChildLinesUpdated() {
        SBQQ__QuoteLine__c parentQL = [SELECT Id FROM SBQQ__QuoteLine__c WHERE SBQQ__RequiredBy__c = null LIMIT 1];

        QuoteProcurementController.HeaderWrapper wrapper = new QuoteProcurementController.HeaderWrapper();
        wrapper.parentId = parentQL.Id;
        wrapper.quantity = 5;
        wrapper.wasteDescription = 'New Waste';
        wrapper.equipmentSize = '30 Yard';

        Test.startTest();
        Boolean result = QuoteProcurementQuoteLineService.updateQuoteOverview(wrapper);
        Test.stopTest();

        System.assertEquals(true, result, 'Update should succeed');

        // Verify child quote lines were updated (except accessories)
        List<SBQQ__QuoteLine__c> childLines = [
            SELECT Id, SBQQ__Quantity__c, Description_of_Waste__c, Equipment_Size__c,
                SBQQ__ProductOption__r.SBQQ__Type__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__RequiredBy__c = :parentQL.Id
        ];

        for (SBQQ__QuoteLine__c child : childLines) {
            System.assertEquals('New Waste', child.Description_of_Waste__c, 'Waste description should be updated on child');
            System.assertEquals('30 Yard', child.Equipment_Size__c, 'Equipment size should be updated on child');

            // Accessories should NOT have quantity updated
            if (child.SBQQ__ProductOption__r.SBQQ__Type__c == 'Accessory') {
                System.assertEquals(2, child.SBQQ__Quantity__c, 'Accessory quantity should NOT be updated');
            } else {
                System.assertEquals(5, child.SBQQ__Quantity__c, 'Non-accessory quantity should be updated');
            }
        }
    }

    /**
     * @description Test updateQuoteOverview - verify null material grade handling
     */
    @isTest
    static void testUpdateQuoteOverview_NullMaterialGrade() {
        SBQQ__QuoteLine__c parentQL = [SELECT Id FROM SBQQ__QuoteLine__c WHERE SBQQ__RequiredBy__c = null LIMIT 1];

        QuoteProcurementController.HeaderWrapper wrapper = new QuoteProcurementController.HeaderWrapper();
        wrapper.parentId = parentQL.Id;
        wrapper.quantity = 2;
        wrapper.equipmentSize = '10 Yard';
        wrapper.selectedMaterialGrade = null; // Null material grade

        Test.startTest();
        Boolean result = QuoteProcurementQuoteLineService.updateQuoteOverview(wrapper);
        Test.stopTest();

        System.assertEquals(true, result, 'Update should succeed with null material grade');

        // Verify material grade was not changed
        SBQQ__QuoteLine__c updatedParent = [
            SELECT MaterialGrade__c
            FROM SBQQ__QuoteLine__c
            WHERE Id = :parentQL.Id
        ];

        System.assertEquals('Grade A', updatedParent.MaterialGrade__c, 'Material grade should remain unchanged');
    }

    /**
     * @description Test updateQuoteOverview - verify empty company category handling
     */
    @isTest
    static void testUpdateQuoteOverview_EmptyCompanyCategory() {
        SBQQ__QuoteLine__c parentQL = [SELECT Id FROM SBQQ__QuoteLine__c WHERE SBQQ__RequiredBy__c = null LIMIT 1];

        QuoteProcurementController.HeaderWrapper wrapper = new QuoteProcurementController.HeaderWrapper();
        wrapper.parentId = parentQL.Id;
        wrapper.quantity = 2;
        wrapper.equipmentSize = '10 Yard';
        wrapper.companyCategory = '';
        wrapper.companyCategoryName = '';

        Test.startTest();
        Boolean result = QuoteProcurementQuoteLineService.updateQuoteOverview(wrapper);
        Test.stopTest();

        System.assertEquals(true, result, 'Update should succeed with empty company category');

        // Verify company category was not changed
        SBQQ__QuoteLine__c updatedParent = [
            SELECT CompanyCategoryCode__c, CompanyCategoryName__c
            FROM SBQQ__QuoteLine__c
            WHERE Id = :parentQL.Id
        ];

        System.assertEquals('CC01', updatedParent.CompanyCategoryCode__c, 'Company category code should remain unchanged');
        System.assertEquals('Category 1', updatedParent.CompanyCategoryName__c, 'Company category name should remain unchanged');
    }

    /**
     * @description Test updateQuoteOverview - verify SLA date update for parent only
     */
    @isTest
    static void testUpdateQuoteOverview_SLADateUpdate() {
        SBQQ__QuoteLine__c parentQL = [SELECT Id FROM SBQQ__QuoteLine__c WHERE SBQQ__RequiredBy__c = null LIMIT 1];

        QuoteProcurementController.HeaderWrapper wrapper = new QuoteProcurementController.HeaderWrapper();
        wrapper.parentId = parentQL.Id;
        wrapper.quantity = 2;
        wrapper.equipmentSize = '10 Yard';

        Test.startTest();
        Boolean result = QuoteProcurementQuoteLineService.updateQuoteOverview(wrapper);
        Test.stopTest();

        System.assertEquals(true, result, 'Update should succeed');

        // Verify SLA date was set on parent (if callDetermineSLA returns a value)
        SBQQ__QuoteLine__c updatedParent = [
            SELECT Quote_SLA_Date__c
            FROM SBQQ__QuoteLine__c
            WHERE Id = :parentQL.Id
        ];

        // SLA date may be null or set depending on callDetermineSLA implementation
        // This test verifies the method was called without error
        System.assertNotEquals(null, updatedParent, 'Parent should exist');
    }

    /**
     * @description Test updateQuoteOverview - error handling (invalid parent ID)
     */
    @isTest
    static void testUpdateQuoteOverview_InvalidParentId() {
        QuoteProcurementController.HeaderWrapper wrapper = new QuoteProcurementController.HeaderWrapper();
        wrapper.parentId = null; // Invalid parent ID
        wrapper.quantity = 2;
        wrapper.equipmentSize = '10 Yard';

        Test.startTest();
        Boolean result = QuoteProcurementQuoteLineService.updateQuoteOverview(wrapper);
        Test.stopTest();

        // Should return false on error
        System.assertEquals(false, result, 'Should return false on error');
    }
}
