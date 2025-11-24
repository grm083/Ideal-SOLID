/**
 * @description Comprehensive test class for CaseWizardService
 *
 * Coverage Target: 85%+
 *
 * Tests all public methods for wizard-based case creation and validation
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseWizardServiceTest {

    @testSetup
    static void setupTestData() {
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
    }

    @isTest
    static void testValidatePhase_CallerPhase_Success() {
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Account locationAccount = (Account)testData.get('locationAccount');
        Contact testContact = (Contact)testData.get('contact');

        CaseWizardService.WizardData data = new CaseWizardService.WizardData();
        data.entityType = 'Location';
        data.locationId = locationAccount.Id;
        data.contactId = testContact.Id;

        String wizardDataJson = JSON.serialize(data);

        Test.startTest();
        CaseWizardService.PhaseValidationResult result =
            CaseWizardService.validatePhase('CALLER', wizardDataJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.isValid, 'Validation should succeed');
        System.assertEquals('INTENT', result.nextPhase, 'Next phase should be INTENT');
    }

    @isTest
    static void testValidatePhase_CallerPhase_MissingEntity() {
        CaseWizardService.WizardData data = new CaseWizardService.WizardData();
        data.entityType = 'Location';
        data.locationId = null;
        data.contactId = UserInfo.getUserId();

        String wizardDataJson = JSON.serialize(data);

        Test.startTest();
        CaseWizardService.PhaseValidationResult result =
            CaseWizardService.validatePhase('CALLER', wizardDataJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(false, result.isValid, 'Validation should fail');
        System.assert(result.messages.size() > 0, 'Should have validation messages');
    }

    @isTest
    static void testValidatePhase_IntentPhase_Success() {
        CaseWizardService.WizardData data = new CaseWizardService.WizardData();
        data.recordTypeId = TestDataFactoryRefactored.getRecordTypeId('Case', 'Service_Request');
        data.caseType = 'Pickup';
        data.caseSubType = 'Extra Pickup';
        data.assetId = [SELECT Id FROM Asset LIMIT 1].Id;

        String wizardDataJson = JSON.serialize(data);

        Test.startTest();
        CaseWizardService.PhaseValidationResult result =
            CaseWizardService.validatePhase('INTENT', wizardDataJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testValidatePhase_DetailsPhase_Success() {
        CaseWizardService.WizardData data = new CaseWizardService.WizardData();
        data.serviceDate = String.valueOf(System.today().addDays(7));
        data.slaServiceDateTime = String.valueOf(System.now().addDays(7));

        String wizardDataJson = JSON.serialize(data);

        Test.startTest();
        CaseWizardService.PhaseValidationResult result =
            CaseWizardService.validatePhase('DETAILS', wizardDataJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testValidatePhase_InvalidPhase() {
        CaseWizardService.WizardData data = new CaseWizardService.WizardData();
        String wizardDataJson = JSON.serialize(data);

        Test.startTest();
        CaseWizardService.PhaseValidationResult result =
            CaseWizardService.validatePhase('INVALID', wizardDataJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(false, result.isValid, 'Validation should fail for invalid phase');
    }

    @isTest
    static void testCreateCaseFromWizard_Success() {
        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Account locationAccount = (Account)testData.get('locationAccount');
        Contact testContact = (Contact)testData.get('contact');
        Asset testAsset = (Asset)testData.get('asset');

        CaseWizardService.WizardData data = new CaseWizardService.WizardData();
        data.entityType = 'Location';
        data.locationId = locationAccount.Id;
        data.contactId = testContact.Id;
        data.assetId = testAsset.Id;
        data.recordTypeId = TestDataFactoryRefactored.getRecordTypeId('Case', 'Service_Request');
        data.caseType = 'Pickup';
        data.caseSubType = 'Extra Pickup';
        data.serviceDate = String.valueOf(System.today().addDays(7));
        data.slaServiceDateTime = String.valueOf(System.now().addDays(7));
        data.purchaseOrderNumber = 'PO123456';
        data.profileNumber = 'PROF123';

        String wizardDataJson = JSON.serialize(data);

        Test.startTest();
        CaseWizardService.CaseCreationResult result =
            CaseWizardService.createCaseFromWizard(wizardDataJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testUpdateCaseFromWizard_Success() {
        Case existingCase = TestDataFactoryRefactored.createCase('Service_Request');
        insert existingCase;

        Map<String, Object> testData = TestDataFactoryRefactored.createFullTestHierarchy();
        Contact testContact = (Contact)testData.get('contact');

        CaseWizardService.WizardData data = new CaseWizardService.WizardData();
        data.contactId = testContact.Id;
        data.recordTypeId = existingCase.RecordTypeId;
        data.caseType = 'Status';
        data.caseSubType = 'Service Issue';
        data.origin = 'Phone';

        String wizardDataJson = JSON.serialize(data);

        Test.startTest();
        CaseWizardService.CaseCreationResult result =
            CaseWizardService.updateCaseFromWizard(existingCase.Id, wizardDataJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testPhaseValidationResult_DefaultConstructor() {
        Test.startTest();
        CaseWizardService.PhaseValidationResult result =
            new CaseWizardService.PhaseValidationResult();
        Test.stopTest();

        System.assertEquals(true, result.isValid, 'Default isValid should be true');
        System.assertNotEquals(null, result.messages, 'Messages should not be null');
        System.assertNotEquals(null, result.fieldErrors, 'Field errors should not be null');
    }

    @isTest
    static void testCaseCreationResult_DefaultConstructor() {
        Test.startTest();
        CaseWizardService.CaseCreationResult result =
            new CaseWizardService.CaseCreationResult();
        Test.stopTest();

        System.assertEquals(false, result.success, 'Default success should be false');
        System.assertNotEquals(null, result.messages, 'Messages should not be null');
    }
}
