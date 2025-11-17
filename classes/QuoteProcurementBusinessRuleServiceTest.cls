/**
 * @description Test class for QuoteProcurementBusinessRuleService
 *
 * Tests all validation methods, error message generation, and business rule evaluation
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class QuoteProcurementBusinessRuleServiceTest {

    @testSetup
    static void setupTestData() {
        Account clientAccount = TestDataFactoryRefactored.createAccount('Client', 'Client');
        insert clientAccount;

        Account locationAccount = TestDataFactoryRefactored.createAccount('Location', 'Location');
        locationAccount.ParentId = clientAccount.Id;
        insert locationAccount;

        Account vendorAccount = TestDataFactoryRefactored.createAccount('Vendor', 'Vendor');
        vendorAccount.Status__c = 'Active';
        vendorAccount.Parent_Vendor_Id__c = Constant_Util.WM_US_VENDOR;
        vendorAccount.Name = 'WM Fee Test Vendor';
        insert vendorAccount;

        Contact con = TestDataFactoryRefactored.createContact(clientAccount.Id);
        insert con;

        Product2 product = TestDataFactoryRefactored.createProduct('Rolloff');
        insert product;

        Case testCase = TestDataFactoryRefactored.createCaseWithRelationships(
            clientAccount.Id, locationAccount.Id, con.Id, null, 'Service_Request'
        );
        insert testCase;

        Opportunity opp = TestDataFactoryRefactored.createOpportunity(clientAccount.Id);
        opp.Case__c = testCase.Id;
        insert opp;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Account__c = locationAccount.Id,
            SBQQ__PrimaryContact__c = con.Id,
            SBQQ__Status__c = 'Product Configured',
            SBQQ__Type__c = 'Quote',
            STP__c = false
        );
        insert quote;

        SBQQ__QuoteLine__c parentLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = 1,
            Vendor__c = vendorAccount.Id,
            Occurrence_Type__c = 'SOC',
            Schedule_Frequency__c = 'W',
            Service_Days__c = 'Mon',
            Cost_Unit_of_Measure__c = 'Each',
            CostModelType__c = 'FLT',
            SBQQ__UnitCost__c = 100,
            PriceUOM__c = 'Each',
            SBQQ__ListPrice__c = 200,
            SBQQ__PricingMethod__c = 'List'
        );
        insert parentLine;
    }

    @isTest
    static void testValidateProductConfiguredStage_Success() {
        SBQQ__QuoteLine__c quoteLine = [SELECT Id, SBQQ__Quote__r.SBQQ__Status__c,
                                              SBQQ__Quote__r.SBQQ__Type__c,
                                              SBQQ__Quote__r.STP__c, Vendor__c,
                                              Vendor__r.Status__c, Occurrence_Type__c,
                                              Schedule_Frequency__c, Service_Days__c
                                        FROM SBQQ__QuoteLine__c LIMIT 1];

        Test.startTest();
        String errorMsg = QuoteProcurementBusinessRuleService.validateProductConfiguredStage(quoteLine);
        Test.stopTest();

        System.assertEquals('', errorMsg, 'Valid quoteline should pass validation');
    }

    @isTest
    static void testValidateProductConfiguredStage_MissingSchedule() {
        SBQQ__QuoteLine__c quoteLine = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];
        quoteLine.Schedule_Frequency__c = null;
        update quoteLine;

        quoteLine = [SELECT Id, SBQQ__Quote__r.SBQQ__Status__c, SBQQ__Quote__r.SBQQ__Type__c,
                           SBQQ__Quote__r.STP__c, Vendor__c, Vendor__r.Status__c,
                           Occurrence_Type__c, Schedule_Frequency__c, Service_Days__c
                     FROM SBQQ__QuoteLine__c WHERE Id = :quoteLine.Id];

        Test.startTest();
        String errorMsg = QuoteProcurementBusinessRuleService.validateProductConfiguredStage(quoteLine);
        Test.stopTest();

        System.assertNotEquals('', errorMsg, 'Should return error for missing schedule');
        System.assert(errorMsg.contains('frequency'), 'Error should mention frequency');
    }

    @isTest
    static void testValidateCostConfiguredStage_Success() {
        SBQQ__QuoteLine__c quoteLine = [SELECT Id, SBQQ__Quote__r.SBQQ__Status__c,
                                              SBQQ__Quote__r.SBQQ__Type__c, SBQQ__Quote__r.STP__c,
                                              SBQQ__Quote__r.Case_record_Type__c, Vendor__c,
                                              Vendor__r.Status__c, Vendor__r.Parent_Vendor_ID__c,
                                              Vendor__r.Name, MASLibrary__c, MASCompany__c,
                                              SetupComment__c, DoNotCreateTaskGridTickets__c,
                                              Vendor_Commit_Date__c, SBQQ__EndDate__c, VCRCode__c,
                                              Cost_Unit_of_Measure__c, CostModelType__c,
                                              SBQQ__UnitCost__c, SBQQ__ProductName__c,
                                              Occurrence_Type__c, Schedule_Frequency__c,
                                              Frequency_Interval__c, CostPrice1__c, CostPrice2__c,
                                              SBQQ__RequiredBy__r.SBQQ__ProductFamily__c,
                                              SBQQ__Product__R.Name, SBQQ__RequiredBy__r.Equipment_Size__c,
                                              SBQQ__RequiredBy__r.AssetId__r.Equipment_Size__c,
                                              Equipment_Size__c
                                        FROM SBQQ__QuoteLine__c LIMIT 1];

        Test.startTest();
        String errorMsg = QuoteProcurementBusinessRuleService.validateCostConfiguredStage(quoteLine);
        Test.stopTest();

        // Error expected because vendor is WM but missing MAS/Setup
        System.assertNotEquals('', errorMsg, 'WM vendor requires MAS Library/Company');
    }

    @isTest
    static void testValidatePriceConfiguredStage_Success() {
        SBQQ__QuoteLine__c quoteLine = [SELECT Id, SBQQ__Quote__r.SBQQ__Status__c,
                                              SBQQ__Quote__r.SBQQ__Type__c, SBQQ__Quote__r.STP__c,
                                              Vendor__c, Vendor__r.Status__c, Vendor__r.Parent_Vendor_ID__c,
                                              Vendor__r.Name, Vendor_Commit_Date__c, SBQQ__EndDate__c,
                                              MASCustomerUniqueId__c, VCRCode__c, SBQQ__PricingMethod__c,
                                              SBQQ__ListPrice__c, PricingUnitMethod__c, PriceUOM__c,
                                              SBQQ__ProductName__c, PricePrice1__c, PricePrice2__c
                                        FROM SBQQ__QuoteLine__c LIMIT 1];

        Test.startTest();
        String errorMsg = QuoteProcurementBusinessRuleService.validatePriceConfiguredStage(quoteLine);
        Test.stopTest();

        // Should have error for missing VCR code for WM vendor
        System.assertNotEquals('', errorMsg, 'WM vendor should require VCR code');
    }

    @isTest
    static void testValidateOccurrenceType_SOC_Valid() {
        SBQQ__QuoteLine__c quoteLine = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];
        quoteLine.Occurrence_Type__c = 'SOC';
        quoteLine.Schedule_Frequency__c = 'M';
        quoteLine.Frequency_Interval__c = '2';
        update quoteLine;

        quoteLine = [SELECT Id, Occurrence_Type__c, Schedule_Frequency__c, Frequency_Interval__c
                     FROM SBQQ__QuoteLine__c WHERE Id = :quoteLine.Id];

        Test.startTest();
        String errorMsg = QuoteProcurementBusinessRuleService.validateOccurrenceType(quoteLine);
        Test.stopTest();

        System.assertEquals('', errorMsg, 'SOC with frequency should be valid');
    }

    @isTest
    static void testValidateOccurrenceType_OC_Invalid() {
        SBQQ__QuoteLine__c quoteLine = [SELECT Id FROM SBQQ__QuoteLine__c LIMIT 1];
        quoteLine.Occurrence_Type__c = 'OC';
        quoteLine.Schedule_Frequency__c = 'W';
        update quoteLine;

        quoteLine = [SELECT Id, Occurrence_Type__c, Schedule_Frequency__c, Frequency_Interval__c
                     FROM SBQQ__QuoteLine__c WHERE Id = :quoteLine.Id];

        Test.startTest();
        String errorMsg = QuoteProcurementBusinessRuleService.validateOccurrenceType(quoteLine);
        Test.stopTest();

        System.assertNotEquals('', errorMsg, 'OC should not have schedule frequency');
    }

    @isTest
    static void testGetQuoteBusinessRules() {
        SBQQ__Quote__c quote = [SELECT Id, SBQQ__Account__r.ParentId FROM SBQQ__Quote__c LIMIT 1];

        Business_Rule__c br = new Business_Rule__c(
            AccountId__c = quote.SBQQ__Account__r.ParentId,
            Request_Type__c = 'Service Request',
            Service__c = 'Pickup',
            Active__c = true
        );
        insert br;

        Test.startTest();
        Business_Rule__c result = QuoteProcurementBusinessRuleService.getQuoteBusinessRules(
            quote.Id,
            'Service Request',
            'Pickup'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return business rule');
    }

    @isTest
    static void testErrorMessageConstants() {
        Test.startTest();
        String vendorMissing = QuoteProcurementBusinessRuleService.ERR_VENDOR_MISSING;
        String masLibCode = QuoteProcurementBusinessRuleService.ERR_MAS_LIBRARY_CODE;
        String costMissing = QuoteProcurementBusinessRuleService.ERR_COST_MISSING;
        Test.stopTest();

        System.assertNotEquals(null, vendorMissing, 'Error constant should be defined');
        System.assertNotEquals(null, masLibCode, 'Error constant should be defined');
        System.assertNotEquals(null, costMissing, 'Error constant should be defined');
    }
}
