/**
 * @description WorkOrderPreviewController - Apex controller for workOrderPreview LWC
 *
 * Provides methods for managing work order preview data, including onsite contact
 * information, work order instructions, and bypass flags.
 *
 * Key Responsibilities:
 * - Retrieve current work order preview data for a case
 * - Update work order fields on case
 * - Validate work order creation readiness
 * - Generate work order preview information
 *
 * Design Principles:
 * - Single Responsibility: Only handles work order preview UI data
 * - Service Layer Integration: Delegates to CaseWorkOrderService for business logic
 * - 100% reuse of existing validation logic
 *
 * @author Claude (AI Assistant)
 * @date 2025-11-18
 * @group Controllers
 */
public with sharing class WorkOrderPreviewController {

    // ========================================================================
    // DATA RETRIEVAL METHODS
    // ========================================================================

    /**
     * @description Gets work order preview data for a case
     * @param caseId The case ID
     * @return WorkOrderPreviewData wrapper with all WO preview fields
     */
    @AuraEnabled(cacheable=true)
    public static WorkOrderPreviewData getWorkOrderPreviewData(String caseId) {
        WorkOrderPreviewData result = new WorkOrderPreviewData();

        try {
            if (String.isBlank(caseId)) {
                return result;
            }

            // Query case with work order fields
            Case caseRecord = CaseContextGetter.getCaseById(Id.valueOf(caseId));

            if (caseRecord == null) {
                return result;
            }

            // Populate result
            result.siteContact = caseRecord.Site_Contact__c;
            result.siteContactPhone = caseRecord.Site_Contact_Phone__c;
            result.workOrderInstructions = caseRecord.User_Input_Work_Order_Instructions__c;
            result.byPassWorkOrder = caseRecord.Is_ByPassWO__c != null ? caseRecord.Is_ByPassWO__c : false;

            // Check if work order is required
            result.isWorkOrderRequired = !CaseBusinessRuleService.shouldBypassWorkOrderCreation(caseRecord);

            // Validate work order creation readiness
            Map<String, Object> validationResult = CaseBusinessRuleService.validateCaseReadyForWorkOrder(caseId);
            result.isValidForWorkOrder = (Boolean) validationResult.get('isValid');

            List<String> messages = (List<String>) validationResult.get('messages');
            if (messages != null && !messages.isEmpty()) {
                result.validationMessages = messages;
            }

            // Get existing work order count
            result.hasExistingWorkOrders = CaseWorkOrderService.hasActiveWorkOrders(Id.valueOf(caseId));
            result.activeWorkOrderCount = CaseWorkOrderService.getActiveWorkOrderCount(Id.valueOf(caseId));

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS,
                LoggingLevel.ERROR
            );
            throw new AuraHandledException('Failed to load work order preview data: ' + ex.getMessage());
        }

        return result;
    }

    /**
     * @description Gets work order preview information formatted for display
     * @param caseId The case ID
     * @return WorkOrderPreviewInfo with formatted display fields
     */
    @AuraEnabled(cacheable=true)
    public static WorkOrderPreviewInfo getWorkOrderPreviewInfo(String caseId) {
        WorkOrderPreviewInfo result = new WorkOrderPreviewInfo();

        try {
            WorkOrderPreviewData data = getWorkOrderPreviewData(caseId);

            result.siteContact = data.siteContact;
            result.siteContactPhone = data.siteContactPhone;
            result.workOrderInstructions = data.workOrderInstructions;
            result.byPassWorkOrder = data.byPassWorkOrder;
            result.isWorkOrderRequired = data.isWorkOrderRequired;
            result.isValidForWorkOrder = data.isValidForWorkOrder;
            result.validationMessages = data.validationMessages;
            result.hasExistingWorkOrders = data.hasExistingWorkOrders;
            result.activeWorkOrderCount = data.activeWorkOrderCount;

            // Generate preview text
            result.previewText = generateWorkOrderPreviewText(data);

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS,
                LoggingLevel.ERROR
            );
            throw new AuraHandledException('Failed to load work order preview info: ' + ex.getMessage());
        }

        return result;
    }

    // ========================================================================
    // DATA UPDATE METHODS
    // ========================================================================

    /**
     * @description Updates work order preview fields on case
     * @param caseId The case ID
     * @param workOrderDataJson JSON string of WorkOrderUpdateData
     */
    @AuraEnabled
    public static void updateWorkOrderPreviewFields(String caseId, String workOrderDataJson) {
        try {
            if (String.isBlank(caseId) || String.isBlank(workOrderDataJson)) {
                throw new AuraHandledException('Case ID and work order data are required');
            }

            WorkOrderUpdateData updateData = (WorkOrderUpdateData) JSON.deserialize(
                workOrderDataJson,
                WorkOrderUpdateData.class
            );

            // Query case
            Case caseRecord = new Case(Id = Id.valueOf(caseId));
            caseRecord.Site_Contact__c = updateData.siteContact;
            caseRecord.Site_Contact_Phone__c = updateData.siteContactPhone;
            caseRecord.User_Input_Work_Order_Instructions__c = updateData.workOrderInstructions;
            caseRecord.Is_ByPassWO__c = updateData.byPassWorkOrder;

            // Update via DML service
            CaseDMLService.DMLResult updateResult = CaseDMLService.getInstance().updateCases(
                new List<Case>{ caseRecord }
            );

            if (!updateResult.isSuccess) {
                throw new AuraHandledException('Failed to update work order fields: ' + updateResult.errorMessage);
            }

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS,
                LoggingLevel.ERROR
            );
            throw new AuraHandledException('Failed to update work order preview fields: ' + ex.getMessage());
        }
    }

    /**
     * @description Validates work order creation for a case
     * @param caseId The case ID
     * @return ValidationResultWrapper with validation details
     */
    @AuraEnabled(cacheable=true)
    public static ValidationResultWrapper validateWorkOrderCreation(String caseId) {
        ValidationResultWrapper result = new ValidationResultWrapper();

        try {
            if (String.isBlank(caseId)) {
                result.isValid = false;
                result.messages.add('Case ID is required');
                return result;
            }

            Map<String, Object> validationResult = CaseBusinessRuleService.validateCaseReadyForWorkOrder(caseId);
            result.isValid = (Boolean) validationResult.get('isValid');

            List<String> messages = (List<String>) validationResult.get('messages');
            if (messages != null) {
                result.messages = messages;
            }

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS,
                LoggingLevel.ERROR
            );
            result.isValid = false;
            result.messages.add('Validation error: ' + ex.getMessage());
        }

        return result;
    }

    // ========================================================================
    // PRIVATE HELPER METHODS
    // ========================================================================

    /**
     * @description Generates work order preview text from data
     * @param data WorkOrderPreviewData
     * @return Formatted preview text
     */
    private static String generateWorkOrderPreviewText(WorkOrderPreviewData data) {
        List<String> previewLines = new List<String>();

        if (data.byPassWorkOrder) {
            return 'Work Order creation will be bypassed for this case.';
        }

        if (!data.isWorkOrderRequired) {
            return 'Work Order is not required for this case type.';
        }

        if (String.isNotBlank(data.siteContact)) {
            previewLines.add('Onsite Contact: ' + data.siteContact);
        }

        if (String.isNotBlank(data.siteContactPhone)) {
            previewLines.add('Contact Phone: ' + data.siteContactPhone);
        }

        if (String.isNotBlank(data.workOrderInstructions)) {
            previewLines.add('Instructions: ' + data.workOrderInstructions);
        }

        if (previewLines.isEmpty()) {
            return 'No work order details provided yet.';
        }

        return String.join(previewLines, '\n');
    }

    // ========================================================================
    // WRAPPER CLASSES
    // ========================================================================

    /**
     * @description Work order preview data wrapper
     */
    public class WorkOrderPreviewData {
        @AuraEnabled public String siteContact { get; set; }
        @AuraEnabled public String siteContactPhone { get; set; }
        @AuraEnabled public String workOrderInstructions { get; set; }
        @AuraEnabled public Boolean byPassWorkOrder { get; set; }
        @AuraEnabled public Boolean isWorkOrderRequired { get; set; }
        @AuraEnabled public Boolean isValidForWorkOrder { get; set; }
        @AuraEnabled public List<String> validationMessages { get; set; }
        @AuraEnabled public Boolean hasExistingWorkOrders { get; set; }
        @AuraEnabled public Integer activeWorkOrderCount { get; set; }

        public WorkOrderPreviewData() {
            this.siteContact = '';
            this.siteContactPhone = '';
            this.workOrderInstructions = '';
            this.byPassWorkOrder = false;
            this.isWorkOrderRequired = true;
            this.isValidForWorkOrder = false;
            this.validationMessages = new List<String>();
            this.hasExistingWorkOrders = false;
            this.activeWorkOrderCount = 0;
        }
    }

    /**
     * @description Work order preview info wrapper
     */
    public class WorkOrderPreviewInfo {
        @AuraEnabled public String siteContact { get; set; }
        @AuraEnabled public String siteContactPhone { get; set; }
        @AuraEnabled public String workOrderInstructions { get; set; }
        @AuraEnabled public Boolean byPassWorkOrder { get; set; }
        @AuraEnabled public Boolean isWorkOrderRequired { get; set; }
        @AuraEnabled public Boolean isValidForWorkOrder { get; set; }
        @AuraEnabled public List<String> validationMessages { get; set; }
        @AuraEnabled public Boolean hasExistingWorkOrders { get; set; }
        @AuraEnabled public Integer activeWorkOrderCount { get; set; }
        @AuraEnabled public String previewText { get; set; }

        public WorkOrderPreviewInfo() {
            this.siteContact = '';
            this.siteContactPhone = '';
            this.workOrderInstructions = '';
            this.byPassWorkOrder = false;
            this.isWorkOrderRequired = true;
            this.isValidForWorkOrder = false;
            this.validationMessages = new List<String>();
            this.hasExistingWorkOrders = false;
            this.activeWorkOrderCount = 0;
            this.previewText = '';
        }
    }

    /**
     * @description Work order update data wrapper (for deserialization)
     */
    public class WorkOrderUpdateData {
        public String siteContact { get; set; }
        public String siteContactPhone { get; set; }
        public String workOrderInstructions { get; set; }
        public Boolean byPassWorkOrder { get; set; }
    }

    /**
     * @description Validation result wrapper
     */
    public class ValidationResultWrapper {
        @AuraEnabled public Boolean isValid { get; set; }
        @AuraEnabled public List<String> messages { get; set; }

        public ValidationResultWrapper() {
            this.isValid = true;
            this.messages = new List<String>();
        }
    }
}
