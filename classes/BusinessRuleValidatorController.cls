/**
 * Business Rule Validator Controller
 *
 * Unified LWC controller for business rule validation and evaluation.
 * Integrates with CaseBusinessRuleService for all business logic.
 *
 * Features:
 * - Purchase Order validation and requirement checking
 * - Profile Number validation and requirement checking
 * - PSI validation and requirement checking
 * - Work Order readiness validation
 * - Button visibility evaluation (Progress Case, Add Quote)
 * - Comprehensive business rule evaluation
 *
 * 100% Reuse of existing: CaseBusinessRuleService
 *
 * @author Claude (AI Assistant)
 * @date 2025-11-18
 */
public with sharing class BusinessRuleValidatorController {

    // ========================================
    // Business Rule Evaluation Methods
    // ========================================

    /**
     * Evaluate all business rules for a case
     *
     * @param caseId The ID of the case
     * @return Complete business rule evaluation result
     */
    @AuraEnabled(cacheable=true)
    public static BusinessRuleEvaluation evaluateBusinessRules(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                throw new AuraHandledException('Case ID is required');
            }

            // Use existing CaseBusinessRuleService
            Map<String, Object> evaluationResult = CaseBusinessRuleService.evaluateBusinessRules(caseId);

            BusinessRuleEvaluation result = new BusinessRuleEvaluation();
            result.isPORequired = (Boolean) evaluationResult.get('isPORequired');
            result.isProfileNumberRequired = (Boolean) evaluationResult.get('isProfileNumberRequired');
            result.isPSIRequired = (Boolean) evaluationResult.get('isPSIRequired');
            result.showProgressCaseButton = (Boolean) evaluationResult.get('showProgressCaseButton');
            result.showAddQuoteButton = (Boolean) evaluationResult.get('showAddQuoteButton');
            result.canCreateWorkOrder = (Boolean) evaluationResult.get('canCreateWorkOrder');
            result.bypassWorkOrder = (Boolean) evaluationResult.get('bypassWorkOrder');
            result.messages = (List<String>) evaluationResult.get('messages');
            result.warnings = (List<String>) evaluationResult.get('warnings');
            result.errors = (List<String>) evaluationResult.get('errors');

            return result;

        } catch (Exception e) {
            UTIL_LoggingService.logError('BusinessRuleValidatorController.evaluateBusinessRules',
                'Error evaluating business rules: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to evaluate business rules: ' + e.getMessage());
        }
    }

    /**
     * Check if Purchase Order is required
     *
     * @param caseId The ID of the case
     * @return Whether PO is required
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isPurchaseOrderRequired(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                return false;
            }

            return CaseBusinessRuleService.isPurchaseOrderRequired(caseId);

        } catch (Exception e) {
            UTIL_LoggingService.logError('BusinessRuleValidatorController.isPurchaseOrderRequired',
                'Error checking PO requirement: ' + e.getMessage(), e);
            return false;
        }
    }

    /**
     * Check if Profile Number is required
     *
     * @param caseId The ID of the case
     * @return Whether Profile Number is required
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isProfileNumberRequired(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                return false;
            }

            return CaseBusinessRuleService.isProfileNumberRequired(caseId);

        } catch (Exception e) {
            UTIL_LoggingService.logError('BusinessRuleValidatorController.isProfileNumberRequired',
                'Error checking Profile Number requirement: ' + e.getMessage(), e);
            return false;
        }
    }

    /**
     * Check if PSI is required
     *
     * @param caseId The ID of the case
     * @return Whether PSI is required
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isPSIRequired(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                return false;
            }

            return CaseBusinessRuleService.isPSIRequired(caseId);

        } catch (Exception e) {
            UTIL_LoggingService.logError('BusinessRuleValidatorController.isPSIRequired',
                'Error checking PSI requirement: ' + e.getMessage(), e);
            return false;
        }
    }

    /**
     * Validate case is ready for work order creation
     *
     * @param caseId The ID of the case
     * @return Validation result with messages
     */
    @AuraEnabled
    public static Map<String, Object> validateCaseReadyForWorkOrder(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                throw new AuraHandledException('Case ID is required');
            }

            return CaseBusinessRuleService.validateCaseReadyForWorkOrder(caseId);

        } catch (Exception e) {
            UTIL_LoggingService.logError('BusinessRuleValidatorController.validateCaseReadyForWorkOrder',
                'Error validating work order readiness: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to validate work order readiness: ' + e.getMessage());
        }
    }

    /**
     * Check if work order creation should be bypassed
     *
     * @param caseId The ID of the case
     * @return Whether to bypass work order creation
     */
    @AuraEnabled(cacheable=true)
    public static Boolean shouldBypassWorkOrderCreation(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                return false;
            }

            return CaseBusinessRuleService.shouldBypassWorkOrderCreation(caseId);

        } catch (Exception e) {
            UTIL_LoggingService.logError('BusinessRuleValidatorController.shouldBypassWorkOrderCreation',
                'Error checking work order bypass: ' + e.getMessage(), e);
            return false;
        }
    }

    // ========================================
    // Button Visibility Methods
    // ========================================

    /**
     * Check if Progress Case button should be shown
     *
     * @param caseId The ID of the case
     * @return Whether to show Progress Case button
     */
    @AuraEnabled(cacheable=true)
    public static Boolean shouldShowProgressCaseButton(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                return false;
            }

            return CaseBusinessRuleService.shouldShowProgressCaseButton(caseId);

        } catch (Exception e) {
            UTIL_LoggingService.logError('BusinessRuleValidatorController.shouldShowProgressCaseButton',
                'Error checking Progress Case button: ' + e.getMessage(), e);
            return false;
        }
    }

    /**
     * Check if Add Quote button should be shown
     *
     * @param caseId The ID of the case
     * @return Whether to show Add Quote button
     */
    @AuraEnabled(cacheable=true)
    public static Boolean shouldShowAddQuoteButton(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                return false;
            }

            return CaseBusinessRuleService.shouldShowAddQuoteButton(caseId);

        } catch (Exception e) {
            UTIL_LoggingService.logError('BusinessRuleValidatorController.shouldShowAddQuoteButton',
                'Error checking Add Quote button: ' + e.getMessage(), e);
            return false;
        }
    }

    // ========================================
    // Field Update Methods
    // ========================================

    /**
     * Update customer info fields on case
     *
     * @param caseId The ID of the case
     * @param fieldUpdatesJson JSON string of field updates
     */
    @AuraEnabled
    public static void updateCustomerInfoFields(String caseId, String fieldUpdatesJson) {
        try {
            if (String.isBlank(caseId)) {
                throw new AuraHandledException('Case ID is required');
            }

            FieldUpdates updates = (FieldUpdates) JSON.deserialize(fieldUpdatesJson, FieldUpdates.class);

            Case c = [
                SELECT Id, PurchaseOrder_Number__c, Override_PO_Create_Task__c,
                       Profile_Number__c, Override_Profile_Number_Task__c,
                       PSI__c, PSI_Override_Reason__c, PSI_Comments__c,
                       Company_Category__c, Override_Company_Category_Create_Task__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            // Update PO fields
            if (updates.purchaseOrderNumber != null) {
                c.PurchaseOrder_Number__c = updates.purchaseOrderNumber;
            }
            if (updates.overridePOCreateTask != null) {
                c.Override_PO_Create_Task__c = updates.overridePOCreateTask;
            }

            // Update Profile Number fields
            if (updates.profileNumber != null) {
                c.Profile_Number__c = updates.profileNumber;
            }
            if (updates.overrideProfileNumberTask != null) {
                c.Override_Profile_Number_Task__c = updates.overrideProfileNumberTask;
            }

            // Update PSI fields
            if (updates.psi != null) {
                c.PSI__c = updates.psi;
            }
            if (updates.psiOverrideReason != null) {
                c.PSI_Override_Reason__c = updates.psiOverrideReason;
            }
            if (updates.psiComments != null) {
                c.PSI_Comments__c = updates.psiComments;
            }

            // Update Company Category fields
            if (updates.companyCategory != null) {
                c.Company_Category__c = updates.companyCategory;
            }
            if (updates.overrideCompanyCategoryTask != null) {
                c.Override_Company_Category_Create_Task__c = updates.overrideCompanyCategoryTask;
            }

            update c;

            UTIL_LoggingService.logDebug('BusinessRuleValidatorController.updateCustomerInfoFields',
                'Updated case ' + caseId + ' with customer info fields');

        } catch (Exception e) {
            UTIL_LoggingService.logError('BusinessRuleValidatorController.updateCustomerInfoFields',
                'Error updating customer info fields: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to update fields: ' + e.getMessage());
        }
    }

    /**
     * Get current customer info field values
     *
     * @param caseId The ID of the case
     * @return Current field values
     */
    @AuraEnabled(cacheable=true)
    public static CustomerInfoFields getCurrentCustomerInfo(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                throw new AuraHandledException('Case ID is required');
            }

            Case c = [
                SELECT Id, PurchaseOrder_Number__c, Override_PO_Create_Task__c,
                       Profile_Number__c, Override_Profile_Number_Task__c,
                       PSI__c, PSI_Override_Reason__c, PSI_Comments__c,
                       Company_Category__c, Override_Company_Category_Create_Task__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            CustomerInfoFields fields = new CustomerInfoFields();
            fields.purchaseOrderNumber = c.PurchaseOrder_Number__c;
            fields.overridePOCreateTask = c.Override_PO_Create_Task__c;
            fields.profileNumber = c.Profile_Number__c;
            fields.overrideProfileNumberTask = c.Override_Profile_Number_Task__c;
            fields.psi = c.PSI__c;
            fields.psiOverrideReason = c.PSI_Override_Reason__c;
            fields.psiComments = c.PSI_Comments__c;
            fields.companyCategory = c.Company_Category__c;
            fields.overrideCompanyCategoryTask = c.Override_Company_Category_Create_Task__c;

            return fields;

        } catch (Exception e) {
            UTIL_LoggingService.logError('BusinessRuleValidatorController.getCurrentCustomerInfo',
                'Error getting customer info: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to get customer info: ' + e.getMessage());
        }
    }

    // ========================================
    // Validation Methods
    // ========================================

    /**
     * Validate customer info fields before save
     *
     * @param fieldUpdatesJson JSON string of field updates
     * @return Validation result
     */
    @AuraEnabled
    public static Map<String, Object> validateCustomerInfo(String fieldUpdatesJson) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('isValid', true);
        result.put('message', '');
        result.put('errors', new List<String>());

        try {
            FieldUpdates updates = (FieldUpdates) JSON.deserialize(fieldUpdatesJson, FieldUpdates.class);
            List<String> errors = new List<String>();

            // Validate PO Number format if provided
            if (String.isNotBlank(updates.purchaseOrderNumber)) {
                // Add any PO format validation here
            }

            // Validate Profile Number format if provided
            if (String.isNotBlank(updates.profileNumber)) {
                // Add any Profile Number format validation here
            }

            // Validate PSI value if provided
            if (String.isNotBlank(updates.psi)) {
                try {
                    Decimal psiValue = Decimal.valueOf(updates.psi);
                    if (psiValue < 0) {
                        errors.add('PSI cannot be negative');
                    }
                } catch (Exception e) {
                    errors.add('PSI must be a valid number');
                }
            }

            if (!errors.isEmpty()) {
                result.put('isValid', false);
                result.put('errors', errors);
                result.put('message', String.join(errors, '; '));
            }

            return result;

        } catch (Exception e) {
            result.put('isValid', false);
            result.put('message', 'Validation failed: ' + e.getMessage());
            return result;
        }
    }

    // ========================================
    // Wrapper Classes
    // ========================================

    /**
     * Business Rule Evaluation Result Wrapper
     */
    public class BusinessRuleEvaluation {
        @AuraEnabled public Boolean isPORequired { get; set; }
        @AuraEnabled public Boolean isProfileNumberRequired { get; set; }
        @AuraEnabled public Boolean isPSIRequired { get; set; }
        @AuraEnabled public Boolean showProgressCaseButton { get; set; }
        @AuraEnabled public Boolean showAddQuoteButton { get; set; }
        @AuraEnabled public Boolean canCreateWorkOrder { get; set; }
        @AuraEnabled public Boolean bypassWorkOrder { get; set; }
        @AuraEnabled public List<String> messages { get; set; }
        @AuraEnabled public List<String> warnings { get; set; }
        @AuraEnabled public List<String> errors { get; set; }
    }

    /**
     * Customer Info Fields Wrapper
     */
    public class CustomerInfoFields {
        @AuraEnabled public String purchaseOrderNumber { get; set; }
        @AuraEnabled public Boolean overridePOCreateTask { get; set; }
        @AuraEnabled public String profileNumber { get; set; }
        @AuraEnabled public Boolean overrideProfileNumberTask { get; set; }
        @AuraEnabled public String psi { get; set; }
        @AuraEnabled public String psiOverrideReason { get; set; }
        @AuraEnabled public String psiComments { get; set; }
        @AuraEnabled public String companyCategory { get; set; }
        @AuraEnabled public Boolean overrideCompanyCategoryTask { get; set; }
    }

    /**
     * Field Updates Input Wrapper
     */
    public class FieldUpdates {
        @AuraEnabled public String purchaseOrderNumber { get; set; }
        @AuraEnabled public Boolean overridePOCreateTask { get; set; }
        @AuraEnabled public String profileNumber { get; set; }
        @AuraEnabled public Boolean overrideProfileNumberTask { get; set; }
        @AuraEnabled public String psi { get; set; }
        @AuraEnabled public String psiOverrideReason { get; set; }
        @AuraEnabled public String psiComments { get; set; }
        @AuraEnabled public String companyCategory { get; set; }
        @AuraEnabled public Boolean overrideCompanyCategoryTask { get; set; }
    }
}
