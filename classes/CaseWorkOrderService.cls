/**
 * @description CaseWorkOrderService - Service Layer for Case-WorkOrder Interactions
 *
 * This service class handles all interactions between Cases and WorkOrders.
 * It provides centralized logic for WorkOrder creation, updates, status synchronization,
 * and business rules related to work order management.
 *
 * Key Responsibilities:
 * - Create WorkOrders from Cases
 * - Synchronize Case and WorkOrder statuses
 * - Handle work order-driven case updates
 * - Manage work order validation and business rules
 *
 * Design Principles:
 * - Single Responsibility: Only handles Case-WorkOrder interactions
 * - Service Layer: No direct UI dependencies
 * - Testability: All methods are mockable and bulkified where possible
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer
 */
public class CaseWorkOrderService {

    // ========================================================================
    // WORKORDER CREATION METHODS
    // ========================================================================

    /**
     * @description Creates WorkOrders from Cases
     * REFACTORED (Phase 5E): Implemented to delegate to WorkOrderCreation
     *
     * @param caseIds Set of Case Ids to create work orders from
     * @return Map of Case Id to WorkOrder Id
     */
    public static Map<Id, Id> createWorkOrdersFromCases(Set<Id> caseIds) {
        Map<Id, Id> caseToWorkOrderMap = new Map<Id, Id>();

        if (caseIds == null || caseIds.isEmpty()) {
            return caseToWorkOrderMap;
        }

        // Query cases with required fields for work order creation
        List<Case> casesToProcess = [
            SELECT Id, Status, Case_Sub_Status__c, AssetId, ContactId,
                   Case_Type__c, Case_Sub_Type__c, Service_Date__c,
                   Location__c, Client__c, Reference_Number__c,
                   SLA_Service_Date_Time__c, Is_Multivendor__c,
                   Site_Contact__c, Site_Contact_Phone__c,
                   User_Input_Work_Order_Instructions__c
            FROM Case
            WHERE Id IN :caseIds
        ];

        // Delegate to WorkOrderCreation for actual creation
        Boolean success = WorkOrderCreation.createWorkOrders(casesToProcess);

        if (success) {
            // Query created work orders and map them back to cases
            List<WorkOrder> createdWorkOrders = [
                SELECT Id, CaseId
                FROM WorkOrder
                WHERE CaseId IN :caseIds
                ORDER BY CreatedDate DESC
            ];

            for (WorkOrder wo : createdWorkOrders) {
                if (!caseToWorkOrderMap.containsKey(wo.CaseId)) {
                    caseToWorkOrderMap.put(wo.CaseId, wo.Id);
                }
            }
        }

        return caseToWorkOrderMap;
    }

    /**
     * @description Creates a single WorkOrder from a Case
     * @param caseId The Case Id
     * @return WorkOrder Id of created work order
     */
    public static Id createWorkOrderFromCase(Id caseId) {
        Map<Id, Id> results = createWorkOrdersFromCases(new Set<Id>{caseId});
        return results.get(caseId);
    }

    /**
     * @description Initiates work order creation with validation
     * REFACTORED (Phase 5E): Moved from CaseBusinessRuleService
     * This is the main entry point for UI-triggered work order creation
     *
     * @param caseId Primary case ID
     * @param caseIdList List of case IDs to create work orders for
     * @return SUCCESS or FAILURE status string
     */
    @AuraEnabled
    public static String initiateWorkOrderCreation(String caseId, List<String> caseIdList) {
        try {
            if (String.isBlank(caseId) || caseIdList == null || caseIdList.isEmpty()) {
                return Constant_Util.Failure;
            }

            // Build set of all case IDs to process
            Set<Id> caseIdsToProcess = new Set<Id>();
            caseIdsToProcess.add(Id.valueOf(caseId));
            for (String cId : caseIdList) {
                caseIdsToProcess.add(Id.valueOf(cId));
            }

            // Validate all cases are ready for work order creation
            for (Id validationCaseId : caseIdsToProcess) {
                ValidationResult validationResult = validateWorkOrderCreation(validationCaseId);
                if (!validationResult.isValid) {
                    UTIL_LoggingService.logHandledException(
                        new CustomException('Work Order validation failed: ' + validationResult.errorMessage),
                        UserInfo.getOrganizationId(),
                        UTIL_ErrorConstants.CASE_TRIGGER_CLASS,
                        LoggingLevel.ERROR
                    );
                    return Constant_Util.Failure;
                }
            }

            // Create work orders
            Map<Id, Id> createdWorkOrders = createWorkOrdersFromCases(caseIdsToProcess);

            if (createdWorkOrders.isEmpty()) {
                return Constant_Util.Failure;
            }

            // Update case statuses
            List<Case> casesToUpdate = [
                SELECT Id, Status, Case_Sub_Status__c
                FROM Case
                WHERE Id IN :caseIdsToProcess
            ];

            for (Case c : casesToUpdate) {
                c.Status = Constant_Util.OPEN;
                c.Case_Sub_Status__c = Constant_Util.PENDING_SERVICE_INTEGRATION;
            }

            CaseDMLService.DMLResult updateResult = CaseDMLService.getInstance().updateCases(casesToUpdate);

            return updateResult.isSuccess ? Constant_Util.SUCCESS : Constant_Util.Failure;

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            return Constant_Util.Failure;
        }
    }

    // ========================================================================
    // STATUS SYNCHRONIZATION METHODS
    // ========================================================================

    /**
     * @description Synchronizes Case status based on WorkOrder status changes
     * This method should be called from WorkOrder trigger or when WO status updates
     *
     * @param workOrderIds Set of WorkOrder Ids that have changed status
     */
    public static void syncCaseStatusFromWorkOrders(Set<Id> workOrderIds) {
        // TODO: Extract from CaseBusinessRuleService (lines 681-906)
        // This handles work order-driven case updates
    }

    /**
     * @description Updates WorkOrders when Case status changes
     * @param caseIds Set of Case Ids that have changed status
     */
    public static void syncWorkOrderStatusFromCases(Set<Id> caseIds) {
        // TODO: Implement bidirectional status sync
    }

    // ========================================================================
    // WORKORDER BUSINESS RULES
    // ========================================================================

    /**
     * @description Validates if a Case can create a WorkOrder
     * REFACTORED (Phase 5E): Delegates to CaseBusinessRuleService for validation logic
     *
     * @param caseId The Case ID to validate
     * @return ValidationResult indicating if WO creation is allowed
     */
    public static ValidationResult validateWorkOrderCreation(Id caseId) {
        ValidationResult result = new ValidationResult();

        // Delegate to CaseBusinessRuleService for business rule validation
        Map<String, Object> businessRuleValidation = CaseBusinessRuleService.validateCaseReadyForWorkOrder(caseId);

        result.isValid = (Boolean) businessRuleValidation.get('isValid');
        List<String> messages = (List<String>) businessRuleValidation.get('messages');

        if (messages != null && !messages.isEmpty()) {
            result.errorMessage = String.join(messages, '; ');
        }

        return result;
    }

    /**
     * @description Determines if WorkOrder creation is required for a Case
     * @param caseRecord The Case record
     * @return True if WorkOrder creation is required
     */
    public static Boolean isWorkOrderRequired(Case caseRecord) {
        // TODO: Implement business logic to determine if WO is needed
        // Based on Case Type, Status, Configuration, etc.
        return false;
    }

    /**
     * @description Gets count of active WorkOrders for a Case
     * @param caseId The Case Id
     * @return Count of active work orders
     */
    public static Integer getActiveWorkOrderCount(Id caseId) {
        List<WorkOrder> activeWOs = WorkOrderContextGetter.getActiveWorkOrdersByCaseIds(new Set<Id>{caseId});
        return activeWOs.size();
    }

    /**
     * @description Checks if a Case has any open or in-progress WorkOrders
     * @param caseId The Case Id
     * @return True if case has active work orders
     */
    public static Boolean hasActiveWorkOrders(Id caseId) {
        return getActiveWorkOrderCount(caseId) > 0;
    }

    // ========================================================================
    // HELPER METHODS AND INNER CLASSES
    // ========================================================================

    /**
     * @description Result wrapper for work order operations
     */
    public class WorkOrderOperationResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public Id workOrderId { get; set; }
        @AuraEnabled public String errorMessage { get; set; }

        public WorkOrderOperationResult(Boolean success, Id woId, String error) {
            this.success = success;
            this.workOrderId = woId;
            this.errorMessage = error;
        }
    }

    /**
     * @description Validation result wrapper
     */
    public class ValidationResult {
        public Boolean isValid { get; set; }
        public String errorMessage { get; set; }

        public ValidationResult() {
            this.isValid = true;
            this.errorMessage = '';
        }

        public ValidationResult(Boolean isValid, String message) {
            this.isValid = isValid;
            this.errorMessage = message;
        }
    }
}
