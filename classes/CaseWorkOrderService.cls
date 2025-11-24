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
    // CASE UPDATE METHODS (REFACTORED FROM WORKORDERTRIGGERHELPER)
    // ========================================================================

    /**
     * @description Updates Cases based on WorkOrder status changes
     * REFACTORED: Extracted from WorkOrderTriggerHelper.updateCaseDetail() lines 19-147
     * This consolidates all WorkOrder-driven Case updates into the service layer
     *
     * @param workOrderMap Map of WorkOrder Id to WorkOrder record
     * @param oldWorkOrderMap Map of old WorkOrder records (for comparison)
     * @param relatedCaseMap Map of Case Id to Case record
     */
    public static void updateCasesFromWorkOrderChanges(
        Map<Id, WorkOrder> workOrderMap,
        Map<Id, WorkOrder> oldWorkOrderMap,
        Map<Id, Case> relatedCaseMap
    ) {
        if (workOrderMap == null || workOrderMap.isEmpty() || relatedCaseMap == null || relatedCaseMap.isEmpty()) {
            return;
        }

        List<Case> caseRelatedList = new List<Case>();
        List<Case> caseupdateList = new List<Case>();
        Map<String, String> caseWOIdMap = new Map<String, String>();
        Map<String, String> caseVendorIdMap = new Map<String, String>();
        Set<Id> woVendorList = new Set<Id>();
        Map<Id, Account> vendorsMap;

        try {
            // Build mappings
            for (WorkOrder woRecord : workOrderMap.values()) {
                caseWOIdMap.put(woRecord.CaseId, woRecord.Id);
                if (woRecord.Vendor_Account_Id__c != null) {
                    woVendorList.add(woRecord.Vendor_Account_Id__c);
                    caseVendorIdMap.put(woRecord.CaseId, woRecord.Vendor_Account_Id__c);
                }
            }

            // Query vendor accounts if needed
            if (!woVendorList.isEmpty()) {
                vendorsMap = new Map<Id, Account>([
                    SELECT Id, Contact_Manually_Vendor__c
                    FROM Account
                    WHERE Id IN :woVendorList
                ]);
            }

            // Process each case
            if (!caseWOIdMap.isEmpty()) {
                for (Case caseRecord : relatedCaseMap.values()) {
                    // Link Work Order to Case if not already set
                    if (String.isBlank(caseRecord.Work_Order__c)) {
                        caseRecord.Work_Order__c = caseWOIdMap.get(caseRecord.Id);
                    }

                    WorkOrder woRecord = workOrderMap.get(caseWOIdMap.get(caseRecord.Id));
                    if (woRecord == null) continue;

                    WorkOrder oldWoRecord = new WorkOrder();
                    if (oldWorkOrderMap != null && !oldWorkOrderMap.isEmpty() && oldWorkOrderMap.containsKey(caseWOIdMap.get(caseRecord.Id))) {
                        oldWoRecord = oldWorkOrderMap.get(caseWOIdMap.get(caseRecord.Id));
                    }

                    // Update Proposed Service Date from Service_Date__c
                    if (!Constant_Util.CLOSED.equalsIgnoreCase(caseRecord.Status) &&
                        ((oldWoRecord != null && woRecord.Service_Date__c != oldWoRecord.Service_Date__c &&
                          woRecord.Vendor_Service_Status__c != oldWoRecord.Vendor_Service_Status__c) ||
                         !RecurrsiveTriggerHandler.bypassValidation)) {
                        caseRecord.Proposed_Service_Date__c = woRecord.Service_Date__c;
                    }

                    // Update Proposed Service Date from Rescheduled_Date__c
                    if (!Constant_Util.CLOSED.equalsIgnoreCase(caseRecord.Status) &&
                        ((oldWoRecord != null && woRecord.Rescheduled_Date__c != oldWoRecord.Rescheduled_Date__c &&
                          woRecord.Vendor_Service_Status__c != oldWoRecord.Vendor_Service_Status__c) ||
                         !RecurrsiveTriggerHandler.bypassValidation)) {
                        caseRecord.Proposed_Service_Date__c = woRecord.Rescheduled_Date__c != null ? woRecord.Rescheduled_Date__c.Date() : null;
                    }

                    // Set to Pending Manual Dispatch
                    if ((oldWoRecord == null || (oldWoRecord != null && oldWoRecord.Acorn_WorkOrder_Number__c != woRecord.Acorn_WorkOrder_Number__c)) &&
                        Constant_Util.OPEN.equalsIgnoreCase(caseRecord.Status) &&
                        (vendorsMap != null && caseVendorIdMap != null && caseVendorIdMap.get(caseRecord.Id) != null &&
                         vendorsMap.get(caseVendorIdMap.get(caseRecord.Id)).Contact_Manually_Vendor__c) &&
                        caseRecord.Service_Date__c >= caseRecord.Service_date_from_local_time__c &&
                        !Constant_UTIL.Pending_Manual_Dispatch.equalsIgnoreCase(caseRecord.Case_Sub_Status__c) &&
                        !woRecord.Is_Bypass__c) {
                        caseRecord.Case_Sub_Status__c = Constant_UTIL.Pending_Manual_Dispatch;
                        caseRecord.Status = Constant_Util.OPEN;
                    } else {
                        // Set to Pending Dispatch
                        if (((Constant_UTIL.PENDING_SERVICE_INTEGRATION.equalsIgnoreCase(caseRecord.Case_Sub_Status__c) ||
                              caseRecord.Source_System__c == 'Acorn') &&
                             Constant_Util.OPEN.equalsIgnoreCase(caseRecord.Status)) &&
                            (Constant_UTIL.ISSUED.equalsIgnoreCase(woRecord.Status) ||
                             (Constant_UTIL.SENT.equalsIgnoreCase(woRecord.Status) &&
                              Constant_UTIL.SCHEDULED.equalsIgnoreCase(woRecord.send_status__c))) &&
                            !Constant_UTIL.Pending_Dispatch.equalsIgnoreCase(caseRecord.Case_Sub_Status__c) &&
                            !(vendorsMap != null && caseVendorIdMap != null && caseVendorIdMap.get(caseRecord.Id) != null &&
                              vendorsMap.get(caseVendorIdMap.get(caseRecord.Id)).Contact_Manually_Vendor__c)) {
                            caseRecord.Case_Sub_Status__c = Constant_UTIL.Pending_Dispatch;
                        }
                    }

                    // Service Not Performed (Confirmed Negative)
                    if (woRecord.Vendor_Service_Status__c != null && woRecord.Vendor_Service_Status__c.contains(Constant_Util.CONFIRMED_NEGATIVE)) {
                        if (Constant_Util.OPEN.equalsIgnoreCase(caseRecord.Status)) {
                            caseRelatedList.add(caseRecord);
                        }
                        caseRecord.Case_Sub_Status__c = Constant_Util.SERVICE_NOT_PERFORMED;
                        caseRecord.Status = Constant_Util.CLOSED;
                    }

                    // Pending Service/Schedule Confirmation
                    if ((Constant_UTIL.SENT.equalsIgnoreCase(woRecord.Send_Status__c) || Constant_UTIL.DELIVERED.equalsIgnoreCase(woRecord.Send_Status__c)) &&
                        (!Constant_Util.ACCEPTED.equalsIgnoreCase(woRecord.Status) || !Constant_Util.CANCELLED.equalsIgnoreCase(woRecord.Status) ||
                         !Constant_Util.CLOSED.equalsIgnoreCase(woRecord.Status)) &&
                        !Constant_Util.CLOSED.equalsIgnoreCase(caseRecord.Status) && caseRecord.Service_Date__c >= System.today() &&
                        !Constant_Util.Pending_Service_Confirmation.equalsIgnoreCase(caseRecord.Case_Sub_Status__c) &&
                        !Constant_Util.Pending_Schedule_Confirmation.equalsIgnoreCase(caseRecord.Case_Sub_Status__c)) {
                        if (caseRecord.Availability_Confirmed__c) {
                            caseRecord.Case_Sub_Status__c = Constant_Util.Pending_Service_Confirmation;
                        } else {
                            caseRecord.Case_Sub_Status__c = Constant_Util.Pending_Schedule_Confirmation;
                        }
                        caseRecord.Status = Constant_Util.OPEN;
                    }

                    // Service Confirmed (Confirmed Positive)
                    if (woRecord.Vendor_Service_Status__c != null && oldWoRecord.Vendor_Service_Status__c != woRecord.Vendor_Service_Status__c &&
                        woRecord.Vendor_Service_Status__c.contains(Constant_Util.CONFIRMED_POSITIVE) &&
                        (Constant_Util.CLOSED.equalsIgnoreCase(caseRecord.Status) ||
                         ((Constant_Util.SENT.equalsIgnoreCase(woRecord.Status) || Constant_Util.RELEASED_FOR_PAYMENT.equalsIgnoreCase(woRecord.Status) ||
                           Constant_Util.ACCEPTED.equalsIgnoreCase(woRecord.Status) || Constant_Util.WORK_COMPLETE.equalsIgnoreCase(woRecord.Status) ||
                           Constant_Util.CLOSED.equalsIgnoreCase(woRecord.Status)) &&
                          Constant_Util.OPEN.equalsIgnoreCase(caseRecord.Status) && !Constant_Util.Pending_Manual_Dispatch.equalsIgnoreCase(caseRecord.Case_Sub_Status__c)))) {
                        caseRecord.Case_Sub_Status__c = Constant_Util.SERVICE_CONFIRMED;
                        caseRecord.Status = Constant_Util.CLOSED;
                    }

                    // Additional Pending Service Confirmation scenarios
                    if (oldWoRecord != null && (!Constant_Util.Pending_Service_Confirmation.equalsIgnoreCase(caseRecord.Case_Sub_Status__c) &&
                        Constant_Util.OPEN.equalsIgnoreCase(caseRecord.Status) &&
                        ((((woRecord.Status != oldWoRecord.Status) &&
                           (Constant_Util.SENT.equalsIgnoreCase(woRecord.Status) || Constant_Util.RELEASED_FOR_PAYMENT.equalsIgnoreCase(woRecord.Status) ||
                            Constant_Util.ACCEPTED.equalsIgnoreCase(woRecord.Status) || Constant_Util.WORK_COMPLETE.equalsIgnoreCase(woRecord.Status) ||
                            Constant_Util.CLOSED.equalsIgnoreCase(woRecord.Status))) &&
                          woRecord.Service_Date__c < System.today() && Constant_Util.OPEN.equalsIgnoreCase(caseRecord.Status) &&
                          !Constant_Util.Pending_Manual_Dispatch.equalsIgnoreCase(caseRecord.Case_Sub_Status__c) &&
                          (String.isBlank(woRecord.Vendor_Service_Status__c) || Constant_Util.SCHEDULED.equalsIgnoreCase(woRecord.Vendor_Service_Status__c))) ||
                         (Constant_Util.SCHEDULED.equalsIgnoreCase(woRecord.Vendor_Service_Status__c) || !String.isBlank(woRecord.MAS_Ticket__c)) ||
                         (Constant_Util.OPEN.equalsIgnoreCase(caseRecord.Status) && !Constant_Util.Pending_Manual_Dispatch.equalsIgnoreCase(caseRecord.Case_Sub_Status__c) &&
                          Constant_Util.ACCEPTED.equalsIgnoreCase(woRecord.Status))))) {
                        caseRecord.Status = Constant_Util.OPEN;
                        caseRecord.Case_Sub_Status__c = Constant_Util.Pending_Service_Confirmation;
                    }

                    // Request Canceled
                    if (oldWoRecord.Status != woRecord.Status && Constant_Util.CANCELLED.equalsIgnoreCase(woRecord.Status) &&
                        Constant_Util.OPEN.equalsIgnoreCase(caseRecord.Status) && !Constant_Util.Request_Canceled.equalsIgnoreCase(caseRecord.Case_Sub_Status__c)) {
                        caseRecord.Status = Constant_Util.CLOSED;
                        caseRecord.Case_Sub_Status__c = Constant_Util.Request_Canceled;
                    }

                    // WorkOrder Rejected
                    if (Constant_UTIL.REJECTED.equalsIgnoreCase(woRecord.Status)) {
                        caseRecord.Status = Constant_Util.CLOSED;
                    }

                    caseupdateList.add(caseRecord);
                }
            }

            // Create related cases for Service Not Performed scenarios
            if (!caseRelatedList.isEmpty()) {
                CaseCreation.createRelatedCase(caseRelatedList);
            }

            // Perform DML through service layer
            if (!caseupdateList.isEmpty()) {
                if (!System.isBatch() && !System.isFuture() && caseupdateList.size() > 1) {
                    // Use batch for large volumes
                    SObjectUpdateBatch b = new SObjectUpdateBatch(caseupdateList);
                    Database.executeBatch(b, 10);
                } else {
                    // Use service layer for normal DML
                    CaseDMLService.getInstance().updateCases(caseupdateList);
                }
            }

        } catch (Exception excp) {
            UTIL_LoggingService.logHandledException(excp, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }

    /**
     * @description Updates Case task creation flags when WorkOrder service dates change
     * REFACTORED: Extracted from WorkOrderTriggerHelper.ServiceDateChanges() lines 216-232
     * Updates Is_Case_OSC_Created__c and Is_Case_CSC_Created__c flags based on service date changes
     *
     * @param caseTaskFlagMap Map of Case Id to flag type ('OSC' or 'CSC')
     */
    public static void updateCaseTaskFlagsForServiceDateChanges(Map<Id, String> caseTaskFlagMap) {
        if (caseTaskFlagMap == null || caseTaskFlagMap.isEmpty()) {
            return;
        }

        List<Case> updateCaseLst = new List<Case>();

        try {
            for (Id caseId : caseTaskFlagMap.keySet()) {
                Case cse = new Case(Id = caseId);
                String flagType = caseTaskFlagMap.get(caseId);

                if (flagType == 'OSC') {
                    cse.Is_Case_OSC_Created__c = false;
                } else if (flagType == 'CSC') {
                    cse.Is_Case_CSC_Created__c = false;
                }
                updateCaseLst.add(cse);
            }

            if (!updateCaseLst.isEmpty()) {
                CaseDMLService.DMLResult result = CaseDMLService.getInstance().updateCases(updateCaseLst);

                // Log any errors that occurred
                if (result.hasErrors) {
                    for (CaseDMLService.DMLError error : result.errors) {
                        System.debug('Error updating case task flags: ' + error.message);
                    }
                }
            }

        } catch (Exception excp) {
            UTIL_LoggingService.logHandledException(excp, UserInfo.getOrganizationId(), UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
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
