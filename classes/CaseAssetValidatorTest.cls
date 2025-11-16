/**
 * @description Test class for CaseAssetValidator
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class CaseAssetValidatorTest {

    @testSetup
    static void setupTestData() {
        TestDataFactory.createFullTestHierarchy();
    }

    @isTest
    static void testValidatePickupAsset_Success() {
        // Given
        Asset testAsset = [SELECT Id, InstallDate FROM Asset LIMIT 1];
        Date serviceDate = Date.today().addDays(7);

        Test.startTest();
        // When
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(testAsset.Id, serviceDate);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.validationType, 'Validation type should be set');
    }

    @isTest
    static void testValidatePickupAsset_NullAsset() {
        Test.startTest();
        // When
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(null, Date.today());
        Test.stopTest();

        // Then
        System.assertEquals(false, result.isValid, 'Should be invalid for null asset');
    }

    @isTest
    static void testValidatePickupAsset_NullServiceDate() {
        // Given
        Asset testAsset = [SELECT Id FROM Asset LIMIT 1];

        Test.startTest();
        // When
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validatePickupAsset(testAsset.Id, null);
        Test.stopTest();

        // Then
        System.assertEquals(false, result.isValid, 'Should be invalid for null service date');
    }

    @isTest
    static void testValidateNonPickupAsset_Success() {
        // Given
        Asset testAsset = [SELECT Id FROM Asset LIMIT 1];
        Date serviceDate = Date.today().addDays(7);

        Test.startTest();
        // When
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validateNonPickupAsset(testAsset.Id, serviceDate);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testValidateNonPickupAsset_NullInputs() {
        Test.startTest();
        // When
        CaseAssetValidator.ValidationResult result =
            CaseAssetValidator.validateNonPickupAsset(null, null);
        Test.stopTest();

        // Then
        System.assertEquals(false, result.isValid, 'Should be invalid for null inputs');
    }

    @isTest
    static void testValidationResult_Constructor() {
        Test.startTest();
        // When
        CaseAssetValidator.ValidationResult result =
            new CaseAssetValidator.ValidationResult(true, 'Test message', 'TEST_TYPE');
        Test.stopTest();

        // Then
        System.assertEquals(true, result.isValid, 'isValid should be true');
        System.assertEquals('Test message', result.errorMessage, 'Error message should match');
        System.assertEquals('TEST_TYPE', result.validationType, 'Validation type should match');
    }
}
