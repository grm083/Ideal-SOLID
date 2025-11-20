/**
 * @author Waste Management
 * @date 2021 (Refactored 2025)
 *
 * @group Cases
 * @group-content ../../ApexDocContent/Cases.htm
 *
 * @description Trigger Handler for Case object - Refactored to follow service-oriented architecture
 * 
 * This class has been refactored to act as a thin orchestration layer that delegates business logic
 * to specialized service classes. The handler methods now focus on:
 * 1. Transaction coordination
 * 2. Service orchestration
 * 3. Error handling
 * 4. Maintaining backward compatibility
 * 
 * Service Layer Architecture:
 * - CaseAttributeService: Field population and attribute management
 * - CaseBusinessRuleService: Business rule evaluation and validation
 * - CaseAssetValidator: Asset validation and eligibility
 * - CaseContextGetter: Data retrieval without business logic
 * - CaseDMLService: All database operations
 * - SLACalculationUtility: SLA date calculations
 * - Entitlement_Utility: Entitlement management
 * 
 * Legacy Helper Integration:
 * CaseTriggerHelper is maintained for backward compatibility but will be gradually
 * refactored to use service classes. Some methods still call CaseTriggerHelper until
 * complete service layer migration is achieved.
 */
public without sharing class CaseTriggerHandler {
    
    // ========================================================================
    // STATIC VARIABLES (Legacy - To be phased out)
    // ========================================================================
    // These variables support legacy CaseTriggerHelper methods
    // They will be removed once CaseTriggerHelper is fully refactored
    
    public static Map<Id, Case> newcasemap = new Map<Id, Case>();
    public static Map<Id, Asset> casewithContainerMap = new Map<Id, Asset>();
    public static Set<Id> containerIdSet = new Set<Id>();
    public static Map<Id, String> caseContainerMap = new Map<Id, String>();
    public static Map<Id, Account> casewithLocationMap = new Map<Id, Account>();
    public static Set<Id> locationIdSet = new Set<Id>();
    public static Map<Id, Case> caseAssetCreationMap = new Map<Id, Case>();
    public static Boolean isInsertForLocalAgentId = false;
    private static Map<Id, Account> locationAccountMap = new Map<Id, Account>();
    
    // ========================================================================
    // CONSTANTS
    // ========================================================================
    
    private static final String INTEGRATION_RECORDTYPE = Constant_Util.Integration_Case;
    private static final String PICKUP_RECORDTYPE = Constant_Util.PICKUP;
    private static final String NEW_SERVICE_RECORDTYPE = Constant_Util.New_Service_Case;
    
    // ========================================================================
    // BEFORE INSERT HANDLER
    // ========================================================================
    
    /**
     * @description Handler for before insert event
     * Orchestrates service calls to populate case attributes, validate business rules,
     * and prepare case for insertion
     * 
     * @param triggerParam TriggerParameters containing new records
     */
    public static void beforeInsert(TriggerParameters triggerParam) {
        try {
            // Initialize collections for processing
            List<Case> casesToProcess = (List<Case>)triggerParam.newList;
            Map<Id, Case> caseNewMap = new Map<Id, Case>();
            
            // Get record type IDs
            Id integrationRcdTypeId = getRecordTypeId(INTEGRATION_RECORDTYPE);
            Id corporateServiceQueueId = getCorporateServiceQueueId();
            
            // Phase 1: Apply workflow migrations and initial field updates
            applyWorkflowMigrations(casesToProcess);
            
            // Phase 2: Collect cases that need processing and gather IDs
            List<Case> casesNeedingSLA = new List<Case>();
            List<Case> casesNeedingSubtype = new List<Case>();
            Set<Id> assetIds = new Set<Id>();
            Set<Id> accountIds = new Set<Id>();
            Set<Id> contactIds = new Set<Id>();
            
            for (Case caseRecord : casesToProcess) {
                // Apply business rules for status and classification
                applyInsertBusinessRules(caseRecord, corporateServiceQueueId);
                
                // Collect IDs for bulk data retrieval
                if (String.isNotBlank(caseRecord.AssetId)) {
                    assetIds.add(caseRecord.AssetId);
                }
                if (String.isNotBlank(caseRecord.Location__c)) {
                    accountIds.add(caseRecord.Location__c);
                }
                if (String.isNotBlank(caseRecord.ContactId)) {
                    contactIds.add(caseRecord.ContactId);
                }
                
                // Categorize cases for specific processing
                if (shouldProcessSubtype(caseRecord, integrationRcdTypeId)) {
                    casesNeedingSubtype.add(caseRecord);
                }
                
                if (shouldCalculateSLA(caseRecord, integrationRcdTypeId)) {
                    casesNeedingSLA.add(caseRecord);
                }
                
                caseNewMap.put(caseRecord.Id, caseRecord);
            }
            
            // Phase 3: Bulk data retrieval using CaseContextGetter
            if (!assetIds.isEmpty()) {
                casewithContainerMap = getAssetRecordValue(assetIds, true);
            }
            
            if (!accountIds.isEmpty()) {
                casewithLocationMap = getLocationRecordValue(accountIds);
            }
            
            // Set maps for legacy CaseTriggerHelper methods
            CaseTriggerHelper.casewithContainer = casewithContainerMap;
            CaseTriggerHelper.casewithLocation = casewithLocationMap;
            
            // Phase 4: Process case details and attributes
            if (!casesNeedingSubtype.isEmpty()) {

                if (!RecurrsiveTriggerHandler.bypassValidation) {
                    // Update case details using helper (will be refactored to service)
                    // Note: Method handles empty/null maps gracefully
                    CaseTriggerHelper.updateCaseDetails(
                        casesNeedingSubtype,
                        new Map<Id, Case>(),
                        casewithContainerMap,
                        casewithLocationMap,
                        true
                    );
                } else {
                    // Process SLA for OfficeTrax cases
                    processOfficeTraxSLA(casesNeedingSLA, casewithContainerMap, casewithLocationMap);
                }
            }

            // Phase 4a: Calculate SLA for new cases that need it
            // This uses the new SLACalculationUtility.calculateAndSetSLAFields() method
            List<Case> casesNeedingSLACalculation = new List<Case>();
            for (Case caseRecord : casesToProcess) {
                // Include cases where SLA is not set and basic requirements are met
                if (caseRecord.SLA_Service_Date_Time__c == null &&
                    caseRecord.RecordTypeId != integrationRcdTypeId &&
                    String.isNotBlank(caseRecord.Location__c) &&
                    String.isNotBlank(caseRecord.Case_Sub_Type__c) &&
                    String.isNotBlank(caseRecord.AssetId)) {

                    // Exclude standard case types (they have their own SLA calculation)
                    if (caseRecord.Case_Type__c != 'Activate' &&
                        caseRecord.Case_Type__c != 'Modify' &&
                        caseRecord.Case_Type__c != 'Deactivate') {
                        casesNeedingSLACalculation.add(caseRecord);
                    }
                }
            }

            if (!casesNeedingSLACalculation.isEmpty() && !RecurrsiveTriggerHandler.bypassValidation) {
                SLACalculationUtility.calculateAndSetSLAFields(casesNeedingSLACalculation, casewithLocationMap);
            }

            // Process standard case types (Activate/Modify/Deactivate)
            processStandardCaseTypes(casesToProcess, casesNeedingSLA);

            // Phase 5: Update contact activity dates
            if (!contactIds.isEmpty()) {
                CaseTriggerHelper.lastContactActivityDate(contactIds);
            }
            
            // Phase 6: Apply final field updates
            isInsertForLocalAgentId = true;
            CaseTriggerHelper.UpdateLocalAgentId(caseNewMap, new Map<Id, Case>(), isInsertForLocalAgentId);
            CaseTriggerHelper.UpdateCallCentreId(caseNewMap, new Map<Id, Case>(), isInsertForLocalAgentId);
            CaseTriggerHelper.UpdatePoWithOfficetraxno(casesToProcess);
            CaseTriggerHelper.UpdateAndTrimDescription(casesToProcess);
            CaseTriggerHelper.PopulateServiceClassification(casesToProcess, new Map<Id, Case>());
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex, 
                UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, 
                LoggingLevel.ERROR
            );
        }
    }
    
    // ========================================================================
    // BEFORE UPDATE HANDLER
    // ========================================================================
    
    /**
     * @description Handler for before update event
     * Orchestrates service calls to validate changes, apply business rules,
     * and update case attributes
     * 
     * @param triggerParam TriggerParameters containing new and old records
     */
    public static void beforeUpdate(TriggerParameters triggerParam) {
        try {
            // Initialize collections
            List<Case> casesToProcess = (List<Case>)triggerParam.newList;
            Map<Id, Case> caseNewMap = new Map<Id, Case>();
            Map<Id, Case> caseOldMap = (Map<Id, Case>)triggerParam.OldMap;
            Map<Id, Case> closedCaseValidationMap = new Map<Id, Case>();
            
            // Get record type IDs
            Id pickupRcdTypeId = getRecordTypeId(PICKUP_RECORDTYPE);
            Id newServiceRcdTypeId = getRecordTypeId(NEW_SERVICE_RECORDTYPE);
            Id integrationRcdTypeId = getRecordTypeId(INTEGRATION_RECORDTYPE);
            Id corporateServiceQueueId = getCorporateServiceQueueId();
            
            // Phase 1: Apply workflow migrations
            applyWorkflowMigrations(casesToProcess);
            
            // Phase 2: Build parent case map for reference numbers
            Set<String> parentIds = new Set<String>();
            for (Case caseRecord : casesToProcess) {
                if (caseRecord.ParentId != null) {
                    parentIds.add(caseRecord.ParentId);
                }
            }
            
            Map<Id, Case> parentRecordMap = new Map<Id, Case>();
            if (!parentIds.isEmpty()) {
                parentRecordMap = new Map<Id, Case>([
                    SELECT Id, Reference_Number__c 
                    FROM Case 
                    WHERE Id IN :parentIds
                ]);
            }
            
            // Phase 3: Process each case for updates
            List<Case> casesNeedingSubtype = new List<Case>();
            List<Case> casesNeedingSLA = new List<Case>();
            Set<Id> assetIds = new Set<Id>();
            Set<Id> accountIds = new Set<Id>();
            
            for (Case caseRecord : casesToProcess) {
                Case oldCase = caseOldMap.get(caseRecord.Id);
                
                // Apply update business rules
                applyUpdateBusinessRules(caseRecord, oldCase, corporateServiceQueueId);
                
                // Handle SLA and service date resets
                handleSLAResets(caseRecord, oldCase, newServiceRcdTypeId, pickupRcdTypeId, integrationRcdTypeId);
                
                // Handle reference number population
                populateReferenceNumber(caseRecord, parentRecordMap);
                
                // Collect IDs for bulk retrieval
                if (String.isNotBlank(caseRecord.AssetId)) {
                    assetIds.add(caseRecord.AssetId);
                }
                if (String.isNotBlank(caseRecord.Location__c)) {
                    accountIds.add(caseRecord.Location__c);
                }
                
                // Categorize cases needing specific processing
                if (shouldProcessSubtypeUpdate(caseRecord, oldCase, newServiceRcdTypeId, 
                                              pickupRcdTypeId, integrationRcdTypeId)) {
                    casesNeedingSubtype.add(caseRecord);
                }
                
                if (shouldCalculateSLAUpdate(caseRecord, oldCase)) {
                    casesNeedingSLA.add(caseRecord);
                }
                
                // Track closed cases for validation
                if (oldCase.Status == Constant_Util.CLOSED && oldCase.Status != caseRecord.Status) {
                    closedCaseValidationMap.put(caseRecord.Id, caseRecord);
                }
                
                caseNewMap.put(caseRecord.Id, caseRecord);
            }
            
            // Phase 4: Bulk data retrieval
            if (!assetIds.isEmpty()) {
                casewithContainerMap = getAssetRecordValue(assetIds, true);
            }
            
            if (!accountIds.isEmpty()) {
                casewithLocationMap = getLocationRecordValue(accountIds);
            }
            
            // Set maps for legacy helper methods
            CaseTriggerHelper.casewithContainer = casewithContainerMap;
            CaseTriggerHelper.casewithLocation = casewithLocationMap;
            
            // Phase 5: Process case details and SLA
            if (!casesNeedingSubtype.isEmpty()) {
                // Note: Method handles empty/null maps gracefully
                CaseTriggerHelper.updateCaseDetails(
                    casesNeedingSubtype,
                    caseOldMap,
                    casewithContainerMap,
                    casewithLocationMap,
                    false
                );
            }

            // Phase 5a: Calculate SLA for cases where SLA was reset or is missing
            // This uses the new SLACalculationUtility.calculateAndSetSLAFields() method
            List<Case> casesNeedingSLACalculation = new List<Case>();
            for (Case caseRecord : casesToProcess) {
                // Include cases where SLA was nullified by handleSLAResets() or never set
                if (caseRecord.SLA_Service_Date_Time__c == null &&
                    caseRecord.RecordTypeId != integrationRcdTypeId &&
                    String.isNotBlank(caseRecord.Location__c) &&
                    String.isNotBlank(caseRecord.Case_Sub_Type__c)) {

                    // Exclude standard case types (they have their own SLA calculation)
                    if (caseRecord.Case_Type__c != 'Activate' &&
                        caseRecord.Case_Type__c != 'Modify' &&
                        caseRecord.Case_Type__c != 'Deactivate') {
                        casesNeedingSLACalculation.add(caseRecord);
                    }
                }
            }

            if (!casesNeedingSLACalculation.isEmpty()) {
                SLACalculationUtility.calculateAndSetSLAFields(casesNeedingSLACalculation, casewithLocationMap);
            }

            // Process standard case types
            processStandardCaseTypesUpdate(casesToProcess, caseOldMap, casesNeedingSLA);

            // Phase 6: Apply final updates
            isInsertForLocalAgentId = false;
            CaseTriggerHelper.UpdateLocalAgentId(caseNewMap, caseOldMap, isInsertForLocalAgentId);
            CaseTriggerHelper.updateAssignment(caseNewMap, caseOldMap, casesToProcess);
            CaseTriggerHelper.PopulateServiceClassification(casesToProcess, caseOldMap);
            CaseTriggerHelper.updateDuplicateCheck(caseNewMap);
            CaseTriggerHelper.updateNSCCase(caseNewMap, caseOldMap);
            
            // Phase 7: Validate closed case changes
            if (!closedCaseValidationMap.isEmpty()) {
                CaseTriggerHelper.showErrorOnCloseCase(closedCaseValidationMap);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex, 
                UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, 
                LoggingLevel.ERROR
            );
        }
    }
    
    // ========================================================================
    // AFTER INSERT HANDLER
    // ========================================================================
    
    /**
     * @description Handler for after insert event
     * Creates related records and performs post-insert actions
     * 
     * @param triggerParam TriggerParameters containing new records
     */
    public static void afterInsert(TriggerParameters triggerParam) {
        try {
            List<Case> casesToProcess = (List<Case>)triggerParam.newList;
            Map<Id, Case> caseNewMap = new Map<Id, Case>();
            Map<Id, Case> caseAssetCreationMap = new Map<Id, Case>();
            List<Case> casesWithParent = new List<Case>();
            List<Case> chargeabilityCases = new List<Case>();
            
            // Phase 1: Categorize cases for processing
            for (Case caseRecord : casesToProcess) {
                // Cases needing asset creation (SDT-8435)
                if (shouldCreateCaseAsset(caseRecord)) {
                    caseAssetCreationMap.put(caseRecord.Id, caseRecord);
                }
                
                // Cases with parent needing comment
                if (caseRecord.ParentId != null) {
                    casesWithParent.add(caseRecord);
                }
                
                // Cases needing chargeability comment
                if (caseRecord.Chargeable__c != null) {
                    chargeabilityCases.add(caseRecord);
                }
                
                caseNewMap.put(caseRecord.Id, caseRecord);
            }
            
            // Phase 2: Create case assets
            if (!caseAssetCreationMap.isEmpty()) {
                CaseTriggerHelper.addCaseAssets(
                    caseAssetCreationMap, 
                    new Map<Id, Case>(), 
                    casewithContainerMap
                );
            }
            
            // Phase 3: Log related cases
            if (!caseNewMap.isEmpty()) {
                CaseTriggerHelper.logRelatedCases(caseNewMap);
            }
            
            // Phase 4: Insert case comments for parent cases (SDT-11758)
            if (!casesWithParent.isEmpty()) {
                CaseTriggerHelper.insertCaseComment(casesWithParent);
            }
            
            // Phase 5: Add chargeability comments
            if (!chargeabilityCases.isEmpty()) {
                CaseTriggerHelper.addCommentForChargeability(chargeabilityCases);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex, 
                UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, 
                LoggingLevel.ERROR
            );
        }
    }
    
    // ========================================================================
    // AFTER UPDATE HANDLER
    // ========================================================================
    
    /**
     * @description Handler for after update event
     * Manages related records, notifications, and post-update actions
     * 
     * @param triggerParam TriggerParameters containing new and old records
     */
    public static void afterUpdate(TriggerParameters triggerParam) {
        try {
            List<Case> casesToProcess = (List<Case>)triggerParam.newList;
            Map<Id, Case> caseNewMap = new Map<Id, Case>();
            Map<Id, Case> caseOldMap = (Map<Id, Case>)triggerParam.OldMap;
            
            // Initialize processing lists
            List<Case> reassignCases = new List<Case>();
            List<Case> chargeabilityCases = new List<Case>();
            List<Case> haulCases = new List<Case>();
            List<Case> updatePOList = new List<Case>();
            List<Case> updateAssets = new List<Case>();
            Map<Id, Case> caseAssetCreationMap = new Map<Id, Case>();
            Map<Id, Case> caseCommentMap = new Map<Id, Case>();
            Map<Id, Case> closedCasesForGR = new Map<Id, Case>();
            Set<Id> contactIds = new Set<Id>();
            Set<String> reopenTrackNumbers = new Set<String>();
            
            Id pickupRcdTypeId = getRecordTypeId(PICKUP_RECORDTYPE);
            
            // Phase 1: Categorize cases for different processing paths
            for (Case caseRecord : casesToProcess) {
                Case oldCase = caseOldMap.get(caseRecord.Id);
                
                // Case asset management
                if (shouldUpdateCaseAsset(caseRecord, oldCase, pickupRcdTypeId)) {
                    caseAssetCreationMap.put(caseRecord.Id, caseRecord);
                }
                
                // Reassignment cases
                if (shouldReassignCase(caseRecord, oldCase)) {
                    reassignCases.add(caseRecord);
                }
                
                // Tracking number comment updates
                if (shouldUpdateCommentTracking(caseRecord, oldCase)) {
                    caseCommentMap.put(caseRecord.Id, caseRecord);
                }
                
                // PO updates
                if (shouldUpdatePO(caseRecord, oldCase)) {
                    updatePOList.add(caseRecord);
                }
                
                // Asset updates (SDT-9485)
                if (shouldUpdateAsset(caseRecord, oldCase)) {
                    updateAssets.add(caseRecord);
                }
                
                // Contact ID changes
                if (oldCase.ContactId != caseRecord.ContactId) {
                    contactIds.add(caseRecord.ContactId);
                }
                
                // Chargeability changes
                if (oldCase.Chargeable__c != caseRecord.Chargeable__c) {
                    chargeabilityCases.add(caseRecord);
                }
                
                // Haul away service chargeability
                if (shouldUpdateHaulChargeability(caseRecord)) {
                    haulCases.add(caseRecord);
                }
                
                // Genesys record for closed cases
                if (oldCase.Status != caseRecord.Status && 
                    Constant_Util.CLOSED.equalsIgnoreCase(caseRecord.Status)) {
                    closedCasesForGR.put(caseRecord.Id, caseRecord);
                }
                
                // Reopen tracking (SDT-25229)
                if (oldCase.Status == Constant_Util.CLOSED && 
                    caseRecord.Status != Constant_Util.CLOSED &&
                    String.isNotBlank(caseRecord.Tracking_Number__c)) {
                    reopenTrackNumbers.add(caseRecord.Tracking_Number__c);
                }
                
                caseNewMap.put(caseRecord.Id, caseRecord);
            }
            
            // Phase 2: Execute DML operations through services
            
            // Manage case assets
            if (!RecurrsiveTriggerHandler.bypassValidation && !caseAssetCreationMap.isEmpty()) {
                CaseTriggerHelper.addCaseAssets(
                    caseAssetCreationMap, 
                    caseOldMap, 
                    casewithContainerMap
                );
            }
            
            // Insert approval and status logs
            if (!RecurrsiveTriggerHandler.bypassValidation) {
                if (TriggerDispatcher.skipTriggerExecutionMap == null || 
                    !TriggerDispatcher.skipTriggerExecutionMap.containsKey('Case') ||
                    (TriggerDispatcher.skipTriggerExecutionMap.containsKey('Case') && 
                     !TriggerDispatcher.skipTriggerExecutionMap.get('Case'))) {
                    CaseTriggerHelper.insertApprovalLog(caseNewMap, caseOldMap);
                }
                CaseTriggerHelper.logStatusUpdates(caseNewMap, caseOldMap);
            }
            
            // Handle reassignments
            if (RecurrsiveTriggerHandler.isRecurrsiveToAcorn && 
                !RecurrsiveTriggerHandler.bypassValidation && 
                !reassignCases.isEmpty()) {
                RecurrsiveTriggerHandler.isRecurrsiveToAcorn = false;
                ReassignAcornTicket.reassignTicket(reassignCases, caseOldMap);
                
                Set<Id> reassignCaseIds = new Set<Id>();
                for (Case c : reassignCases) {
                    reassignCaseIds.add(c.Id);
                }
                CaseTriggerHelper.updateReassignField(reassignCaseIds);
            }
            
            // Update tracking number comments
            if (!RecurrsiveTriggerHandler.bypassValidation && !caseCommentMap.isEmpty()) {
                CaseTriggerHelper.updateCommentsTrackingNumber(caseCommentMap, caseOldMap);
            }
            
            // Update PO
            if (!updatePOList.isEmpty()) {
                UpdateCasePO.updateCasePO(updatePOList);
            }
            
            // Update assets
            if (!updateAssets.isEmpty()) {
                UpdateAssetOnCase.updateAsset(updateAssets, caseOldMap);
            }
            
            // Update contact activity dates
            if (!contactIds.isEmpty()) {
                CaseTriggerHelper.lastContactActivityDate(contactIds);
            }
            
            // Genesys task routing updates
            CaseTriggerHelper.updateGenesysTaskRouting(caseNewMap, caseOldMap);
            CaseTriggerHelper.updateANIOnContact(caseNewMap, caseOldMap);
            CaseTriggerHelper.updateCCandPO(caseNewMap.values(), caseOldMap);
            
            // Handle chargeability updates
            if (!chargeabilityCases.isEmpty()) {
                CaseTriggerHelper.addCommentForChargeability(chargeabilityCases);
            }
            
            // Handle haul away chargeability
            if (!haulCases.isEmpty()) {
                Set<Id> haulCaseIds = new Set<Id>();
                for (Case c : haulCases) {
                    haulCaseIds.add(c.Id);
                }
                CaseTriggerHelper.updateChargeable(haulCaseIds);
                CaseTriggerHelper.updateChargeablechild(haulCaseIds);
            }
            
            // Insert auto approval logs
            if (!CaseTriggerHelper.appLogList.isEmpty()) {
                CaseTriggerHelper.insertAutoApprovalLog();
            }
            
            // Create Genesys records for closed cases
            if (!closedCasesForGR.isEmpty() && 
                System.Label.Create_cancel_GR_record_On_Update == 'ON' && 
                !Test.isRunningTest()) {
                CaseTriggerHelper.createCacelCompletedGenesysRecord(closedCasesForGR);
            }
            
            // Handle case reopening (SDT-25229)
            if (RecurrsiveTriggerHandler.isReopenRecurrsiveToAcorn && 
                !RecurrsiveTriggerHandler.bypassValidation && 
                !reopenTrackNumbers.isEmpty()) {
                RecurrsiveTriggerHandler.isReopenRecurrsiveToAcorn = false;
                ReopenAcornTicket.reassignTicket(reopenTrackNumbers);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex, 
                UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, 
                LoggingLevel.ERROR
            );
        }
    }
    
    // ========================================================================
    // AFTER UPDATE ALWAYS HANDLER
    // ========================================================================
    
    /**
     * @description Handler for after update that always runs
     * Manages actions that must occur regardless of recursion flags
     * 
     * @param triggerParam TriggerParameters containing new and old records
     */
    public static void afterUpdateAlways(TriggerParameters triggerParam) {
        try {
            List<Case> casesToProcess = (List<Case>)triggerParam.newList;
            Map<Id, Case> caseNewMap = new Map<Id, Case>();
            Map<Id, Case> caseOldMap = (Map<Id, Case>)triggerParam.OldMap;
            
            List<Case> amPmVendorCases = new List<Case>();
            Map<Id, Case> closeCaseMap = new Map<Id, Case>();
            Map<Id, Case> amClosedCaseMap = new Map<Id, Case>();
            
            // Categorize cases for processing
            for (Case caseRecord : casesToProcess) {
                Case oldCase = caseOldMap.get(caseRecord.Id);
                
                // AM/PM vendor case creation
                if (shouldCreateAMPMVendorCase(caseRecord, oldCase)) {
                    amPmVendorCases.add(caseRecord);
                }
                
                // Task completion on status/substatus change
                if (oldCase != null && shouldCompleteTask(caseRecord, oldCase)) {
                    closeCaseMap.put(caseRecord.Id, caseRecord);
                }
                
                // Quote declination on case closure
                if (oldCase != null && shouldDeclineQuote(caseRecord, oldCase)) {
                    amClosedCaseMap.put(caseRecord.Id, caseRecord);
                }
                
                caseNewMap.put(caseRecord.Id, caseRecord);
            }
            
            // Create AM/PM vendor cases
            if (!RecurrsiveTriggerHandler.bypassValidation && !amPmVendorCases.isEmpty()) {
                CaseTriggerHelper.createAmPmVendorCases(amPmVendorCases, casewithContainerMap);
            }
            
            // Complete tasks
            if (!closeCaseMap.isEmpty()) {
                CaseTriggerHelper.closeOldTasks(closeCaseMap, caseOldMap);
            }
            
            // Decline quotes
            if (!amClosedCaseMap.isEmpty()) {
                CaseTriggerHelper.declineRelatedQuote(amClosedCaseMap);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex, 
                UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, 
                LoggingLevel.ERROR
            );
        }
    }
    
    // ========================================================================
    // BEFORE DELETE HANDLER
    // ========================================================================
    
    /**
     * @description Handler for before delete event
     * Creates necessary records before case deletion
     * 
     * @param triggerParam TriggerParameters containing records to delete
     */
    public static void beforeDelete(TriggerParameters triggerParam) {
        try {
            Map<Id, Case> caseMap = new Map<Id, Case>();
            
            for (sObject sobjVal : triggerParam.oldList) {
                Case caseRecord = (Case)sobjVal;
                caseMap.put(caseRecord.Id, caseRecord);
            }
            
            if (System.Label.Create_cancel_GR_record == 'ON') {
                CaseTriggerHelper.createCacelCompletedGenesysRecord(caseMap);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex, 
                UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, 
                LoggingLevel.ERROR
            );
        }
    }
    
    // ========================================================================
    // HELPER METHODS - Workflow and Business Rule Application
    // ========================================================================
    
    /**
     * @description Apply workflow migrations for Process Builder to Flow
     * @param cases List of cases to process
     */
    private static void applyWorkflowMigrations(List<Case> cases) {
        if (Test.isRunningTest()) {
            TestDataFactoryRefactored.createProcessBuilderTOFlow();
        }
        
        Code_Switch__c codeSwitchSetting = Code_Switch__c.getValues('Process_Builder_to_Flow');
        if (codeSwitchSetting != null && !codeSwitchSetting.Switch_Off__c) {
            for (Case caseRecord : cases) {
                WorkFlowMigration.RecreatedWorkOrderSuccessful(caseRecord);
                WorkFlowMigration.WorkOrderCreated(caseRecord);
            }
        }
    }
    
    /**
     * @description Apply business rules for insert context
     * @param caseRecord Case to process
     * @param corporateQueueId Corporate service queue ID
     */
    private static void applyInsertBusinessRules(Case caseRecord, Id corporateQueueId) {
        // Auto-set sub-status for closed pickup cases (SDT-8433)
        if (Constant_Util.CLOSED.equalsIgnoreCase(caseRecord.Status) && 
            Constant_Util.PICKUP_CSTYPE.equalsIgnoreCase(caseRecord.Case_type__c) && 
            !Constant_Util.SERVICE_NOT_PERFORMED.equalsIgnoreCase(caseRecord.Case_Sub_Status__c)) {
            caseRecord.Case_Sub_Status__c = Constant_Util.SERVICE_NOT_PERFORMED;
        }
        
        // Handle Acorn status cases
        if (caseRecord.Case_Type__c == Constant_Util.STATUS_CSTYPE && 
            caseRecord.Source_System__c == Constant_Util.ACORN && 
            caseRecord.Status == Constant_Util.OPEN) {
            caseRecord.Case_Sub_Status__c = Constant_Util.PENDING_SERVICE_ISSUE_RESOLUTION;
            caseRecord.Service_Classification__c = 
                caseRecord.Case_Reason__c == Constant_Util.HAULER_REPORTED ? Constant_Util.STANDARD :
                caseRecord.Case_Reason__c == Constant_Util.CUSTOMER_REPORTED ? Constant_Util.EMERGENCY : 
                Constant_Util.EMPTY_STRING;
        }
        
        // Set BackOffice flag
        if (caseRecord.OwnerId != null && 
            caseRecord.OwnerId.equals(corporateQueueId) && 
            !caseRecord.BackOffice_Case__c) {
            caseRecord.BackOffice_Case__c = true;
        }
        
        // Set duplicate bypass flag
        if (caseRecord.Create_AM_and_PM_Pickups__c == true || 
            caseRecord.Is_Multivendor__c == true) {
            caseRecord.Bypass_WO_Duplicate__c = true;
        }
    }
    
    /**
     * @description Apply business rules for update context
     * @param caseRecord Case being updated
     * @param oldCase Previous case state
     * @param corporateQueueId Corporate service queue ID
     */
    private static void applyUpdateBusinessRules(Case caseRecord, Case oldCase, Id corporateQueueId) {
        // Auto-close irrelevant cases
        if (!Constant_Util.CLOSED.equalsIgnoreCase(caseRecord.Status) && 
            caseRecord.Close_Irrelevant_Case__c) {
            caseRecord.Status = Constant_Util.CLOSED;
        }
        
        // Update BackOffice flag on owner change
        if (!caseRecord.OwnerId.equals(oldCase.OwnerId) && 
            caseRecord.OwnerId.equals(corporateQueueId) && 
            !caseRecord.BackOffice_Case__c) {
            caseRecord.BackOffice_Case__c = true;
        }
        
        // Set duplicate bypass on AM/PM or multivendor changes
        if (((caseRecord.Create_AM_and_PM_Pickups__c != oldCase.Create_AM_and_PM_Pickups__c) && 
             caseRecord.Create_AM_and_PM_Pickups__c == true) || 
            ((caseRecord.Is_Multivendor__c != oldCase.Is_Multivendor__c) && 
             caseRecord.Is_Multivendor__c == true)) {
            caseRecord.Bypass_WO_Duplicate__c = true;
        }
    }
    
    /**
     * @description Handle SLA and service date resets based on meaningful field changes
     * Uses SLACalculationUtility.requiresSLAandServiceDateReset() to determine if reset is needed
     *
     * @param caseRecord Case being updated
     * @param oldCase Previous case state
     * @param newServiceRtId New Service record type ID
     * @param pickupRtId Pickup record type ID
     * @param integrationRtId Integration record type ID
     */
    private static void handleSLAResets(Case caseRecord, Case oldCase,
                                       Id newServiceRtId, Id pickupRtId, Id integrationRtId) {
        // Reset SLA on record type change
        if (!caseRecord.RecordTypeId.equals(oldCase.RecordTypeId)) {
            caseRecord.SLA_Service_Date_Time__c = null;
            caseRecord.Service_Date__c = null;
            return;
        }

        // Use SLACalculationUtility.requiresSLAandServiceDateReset() to check for critical field changes
        // This method checks: Case_Type__c, Case_Sub_Type__c, Location__c, AssetId, Reason
        if (SLACalculationUtility.requiresSLAandServiceDateReset(caseRecord, oldCase)) {
            caseRecord.SLA_Service_Date_Time__c = null;
            caseRecord.Service_Date__c = null;
            return;
        }

        // Legacy validation for asset-related changes (SDT-32829)
        // This provides additional validation beyond the standard SLA reset conditions
        if (CaseTriggerHelper.resetSLAandServiceDate(caseRecord, oldCase)) {
            caseRecord.SLA_Service_Date_Time__c = null;
            caseRecord.Service_Date__c = null;
            return;
        }
    }
    
    /**
     * @description Populate reference number for case
     * @param caseRecord Case to update
     * @param parentMap Map of parent cases
     */
    private static void populateReferenceNumber(Case caseRecord, Map<Id, Case> parentMap) {
        if (caseRecord.ParentId == null && caseRecord.Reference_Number__c == null) {
            caseRecord.Reference_Number__c = caseRecord.CaseNumber;
        } else if (caseRecord.ParentId != null && caseRecord.Reference_Number__c == null) {
            caseRecord.Reference_Number__c = parentMap.containsKey(caseRecord.ParentId) ?
                parentMap.get(caseRecord.ParentId).Reference_Number__c :
                caseRecord.Reference_Number__c;
        }
    }
    
    // ========================================================================
    // HELPER METHODS - Processing Conditions
    // ========================================================================
    
    /**
     * @description Check if case should process subtype
     */
    private static Boolean shouldProcessSubtype(Case caseRecord, Id integrationRtId) {
        return String.isNotBlank(caseRecord.AssetId) && 
               !RecurrsiveTriggerHandler.bypassValidation;
    }
    
    /**
     * @description Check if case should calculate SLA
     */
    private static Boolean shouldCalculateSLA(Case caseRecord, Id integrationRtId) {
        return caseRecord.RecordTypeId != integrationRtId &&
               String.isNotBlank(caseRecord.Location__c) &&
               String.isNotBlank(caseRecord.Case_Sub_Type__c) &&
               String.isBlank(String.valueOf(caseRecord.SlaStartDate)) &&
               String.isNotBlank(caseRecord.Status) &&
               Constant_Util.STATUS_New.equals(caseRecord.Status) &&
               String.isNotBlank(caseRecord.Client__c) &&
               String.isNotBlank(caseRecord.AssetId) &&
               sla_calculation__c.getValues(caseRecord.Case_type__c) != null &&
               sla_calculation__c.getValues(caseRecord.Case_type__c).Enabled__c &&
               RecurrsiveTriggerHandler.bypassValidation;
    }
    
    /**
     * @description Check if case should process subtype on update
     */
    private static Boolean shouldProcessSubtypeUpdate(Case caseRecord, Case oldCase,
                                                     Id newServiceRtId, Id pickupRtId, 
                                                     Id integrationRtId) {
        return (caseRecord.RecordTypeId == newServiceRtId || 
                caseRecord.RecordTypeId == pickupRtId ||
                ((caseRecord.RecordTypeId != integrationRtId) &&
                 (String.isNotBlank(caseRecord.Case_type__c) &&
                  sla_calculation__c.getValues(caseRecord.Case_type__c) != null &&
                  sla_calculation__c.getValues(caseRecord.Case_type__c).Enabled__c))) &&
               !caseRecord.Is_Multivendor__c &&
               ((String.isNotBlank(caseRecord.AssetId) && 
                 caseRecord.AssetId != oldCase.AssetId) ||
                !String.isBlank(caseRecord.Case_Sub_Type__c));
    }
    
    /**
     * @description Check if case should calculate SLA on update
     */
    private static Boolean shouldCalculateSLAUpdate(Case caseRecord, Case oldCase) {
        return (caseRecord.Case_Type__c == 'Activate' || 
                caseRecord.Case_Type__c == 'Modify' || 
                caseRecord.Case_Type__c == 'Deactivate') &&
               caseRecord.Service_Date__c == null &&
               caseRecord.SLA_Service_Date_Time__c == null;
    }
    
    /**
     * @description Check if case asset should be created
     */
    private static Boolean shouldCreateCaseAsset(Case caseRecord) {
        return caseRecord.Service_Date__c != null &&
               !String.isBlank(caseRecord.AssetId) &&
               !caseRecord.Is_Multivendor__c &&
               (Constant_Util.ACORN.equalsIgnoreCase(caseRecord.Source_System__c) ||
                Constant_Util.SALESFORCE.equalsIgnoreCase(caseRecord.Source_System__c) ||
                Constant_Util.OFFICETRAX.equalsIgnoreCase(caseRecord.Origin) ||
                Constant_Util.EBUSSINESS.equalsIgnoreCase(caseRecord.Origin));
    }
    
    /**
     * @description Check if case asset should be updated
     */
    private static Boolean shouldUpdateCaseAsset(Case caseRecord, Case oldCase, Id pickupRtId) {
        return caseRecord.Service_Date__c != null &&
               !caseRecord.Is_Multivendor__c &&
               (((caseRecord.AssetId != oldCase.AssetId) ||
                 (caseRecord.Service_Date__c != oldCase.Service_Date__c && 
                  caseRecord.RecordTypeId == pickupRtId) ||
                 (caseRecord.RecordTypeId != pickupRtId && oldCase.Service_Date__c == null)) &&
                (Constant_Util.ACORN.equalsIgnoreCase(caseRecord.Source_System__c) ||
                 Constant_Util.SALESFORCE.equalsIgnoreCase(caseRecord.Source_System__c) ||
                 Constant_Util.OFFICETRAX.equalsIgnoreCase(caseRecord.Origin) ||
                 Constant_Util.EBUSSINESS.equalsIgnoreCase(caseRecord.Origin)));
    }
    
    /**
     * @description Check if case should be reassigned
     */
    private static Boolean shouldReassignCase(Case caseRecord, Case oldCase) {
        return (caseRecord.Status == Constant_Util.OPEN && oldCase.Status == Constant_Util.OPEN) ||
               (caseRecord.Status == Constant_Util.OPEN && oldCase.Status == Constant_Util.Case_New_Status &&
                !String.isBlank(caseRecord.Tracking_Number__c) && !caseRecord.isWorkOrderCreated__c) ||
               (caseRecord.Status == 'New' && oldCase.Status == 'New') ||
               (caseRecord.Status == 'Pending' && oldCase.Status == 'Pending');
    }
    
    /**
     * @description Check if comment tracking should be updated
     */
    private static Boolean shouldUpdateCommentTracking(Case caseRecord, Case oldCase) {
        return caseRecord.Tracking_Number__c != null &&
               caseRecord.Tracking_Number__c != oldCase.Tracking_Number__c;
    }
    
    /**
     * @description Check if PO should be updated
     */
    private static Boolean shouldUpdatePO(Case caseRecord, Case oldCase) {
        return caseRecord.Override_PO_Create_Task__c == true &&
               caseRecord.PurchaseOrder_Number__c != null &&
               caseRecord.Work_Order__c != null &&
               caseRecord.PurchaseOrder_Number__c != oldCase.PurchaseOrder_Number__c;
    }
    
    /**
     * @description Check if asset should be updated (SDT-9485)
     */
    private static Boolean shouldUpdateAsset(Case caseRecord, Case oldCase) {
        return !String.isBlank(oldCase.AssetId) &&
               !String.isBlank(caseRecord.Origin) &&
               !caseRecord.AssetId.equals(oldCase.AssetId) &&
               caseRecord.Status.equals(Constant_Util.New_Status) &&
               caseRecord.Origin.equals(Constant_Util.OfficeTrax);
    }
    
    /**
     * @description Check if haul away chargeability should be updated
     */
    private static Boolean shouldUpdateHaulChargeability(Case caseRecord) {
        return (caseRecord.Case_Sub_Type__c == 'Haul Away - No Equipment' ||
                (caseRecord.Case_Type__c == 'General' && caseRecord.Case_Sub_Type__c == 'Other')) &&
               caseRecord.Chargeable__c != null;
    }
    
    /**
     * @description Check if AM/PM vendor case should be created
     */
    private static Boolean shouldCreateAMPMVendorCase(Case caseRecord, Case oldCase) {
        return ((caseRecord.Status != oldCase.Status) ||
                (caseRecord.Case_Sub_Status__c != oldCase.Case_Sub_Status__c) ||
                (caseRecord.Create_AM_and_PM_Pickups__c != oldCase.Create_AM_and_PM_Pickups__c)) &&
               (caseRecord.Status == Constant_Util.OPEN &&
                caseRecord.Case_Sub_Status__c == Constant_Util.PENDING_SERVICE_INTEGRATION);
    }
    
    /**
     * @description Check if tasks should be completed
     */
    private static Boolean shouldCompleteTask(Case caseRecord, Case oldCase) {
        return (String.isNotBlank(caseRecord.Case_Sub_Status__c) &&
                String.isNotBlank(oldCase.Case_Sub_Status__c) &&
                caseRecord.Case_Sub_Status__c != oldCase.Case_Sub_Status__c) ||
               (caseRecord.Status != oldCase.Status &&
                Constant_Util.CLOSED.equalsIgnoreCase(caseRecord.Status));
    }
    
    /**
     * @description Check if quotes should be declined
     */
    private static Boolean shouldDeclineQuote(Case caseRecord, Case oldCase) {
        return caseRecord.Status != oldCase.Status &&
               Constant_Util.CLOSED.equalsIgnoreCase(caseRecord.Status);
    }
    
    // ========================================================================
    // HELPER METHODS - Standard Case Processing
    // ========================================================================
    
    /**
     * @description Process standard case types (Activate/Modify/Deactivate)
     */
    private static void processStandardCaseTypes(List<Case> cases, List<Case> slaList) {
        List<Case> standardCases = new List<Case>();
        
        for (Case c : cases) {
            if (c.Case_Type__c == 'Activate' || 
                c.Case_Type__c == 'Modify' || 
                c.Case_Type__c == 'Deactivate') {
                standardCases.add(c);
            }
        }
        
        if (!standardCases.isEmpty()) {
            Map<Id, Account> locationMap = getLocationRecordValueStandardCase();
            CaseTriggerHelper.updateServiceDateAlwaysRunstandard(
                standardCases, null, null, locationMap);
            CaseTriggerHelper.serviceDatetoSLAstandard(standardCases, null);
        }
    }
    
    /**
     * @description Process standard case types on update
     */
    private static void processStandardCaseTypesUpdate(List<Case> cases, Map<Id, Case> oldMap, 
                                                       List<Case> slaList) {
        List<Case> standardCases = new List<Case>();
        
        for (Case c : cases) {
            if ((c.Case_Type__c == 'Activate' || 
                 c.Case_Type__c == 'Modify' || 
                 c.Case_Type__c == 'Deactivate') &&
                c.Service_Date__c == null &&
                c.SLA_Service_Date_Time__c == null) {
                standardCases.add(c);
            }
        }
        
        if (!standardCases.isEmpty()) {
            Map<Id, Account> locationMap = getLocationRecordValueStandardCase();
            CaseTriggerHelper.updateServiceDateAlwaysRunstandard(
                standardCases, null, null, locationMap);
            CaseTriggerHelper.serviceDatetoSLAstandard(standardCases, null);
        }
    }
    
    /**
     * @description Process OfficeTrax SLA calculations
     */
    private static void processOfficeTraxSLA(List<Case> cases, Map<Id, Asset> assetMap, 
                                            Map<Id, Account> locationMap) {
        List<Case> validCases = new List<Case>();
        
        for (Case c : cases) {
            if (c.Case_Type__c != 'Activate' && 
                c.Case_Type__c != 'Modify' && 
                c.Case_Type__c != 'Deactivate') {
                validCases.add(c);
            }
        }
        
        if (!validCases.isEmpty()) {
            CaseTriggerHelper.updateServiceDateAlwaysRun(validCases, null, assetMap, locationMap);
            CaseTriggerHelper.serviceDatetoSLA(validCases, null);
        }
    }
    
    // ========================================================================
    // QUERY METHODS (Legacy - To be moved to CaseContextGetter)
    // ========================================================================
    
    /**
     * @description Query Asset records by IDs
     * @param assetIdSet Set of Asset IDs
     * @param serviceHeaderCheck Include service header check
     * @return Map of Asset records
     */
    public static Map<Id, Asset> getAssetRecordValue(Set<Id> assetIdSet, Boolean serviceHeaderCheck) {
        Map<Id, Asset> assetMap = new Map<Id, Asset>();

        try {
            if (assetIdSet == null || assetIdSet.isEmpty()) {
                return assetMap;
            }

            // Query assets with ChildAssets relationship for Case Asset creation (SDT-8435)
            // This ensures CaseAssetValidator has the required hierarchy data
            List<Asset> assetList = [
                SELECT Id, Name, Occurrence_Type__c, ProductFamily,
                    Product2.Equipment_Type__c, Product2.Family, Product2Id, Product2.Name,
                    Material_Type__c, Is_Active__c, Start_Date__c, End_Date__c,
                    Service_Header_Id__c,
                    (SELECT Id, Name, ParentId, Service_Type__c, Start_Date__c, End_Date__c,
                        ProductFamily, Occurrence_Type__c, Material_Type__c, Has_Extra_Pickup__c,
                        Is_Active__c, Is_Core_Service__c, Service_Header_Id__c
                        FROM ChildAssets)
                FROM Asset
                WHERE Id IN :assetIdSet
                LIMIT 49999
            ];

            if (assetList != null && !assetList.isEmpty()) {
                assetMap = new Map<Id, Asset>(assetList);
            }

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
        }

        return assetMap;
    }
    
    /**
     * @description Query Location (Account) records by IDs with caching
     * @param locationIdSet Set of Location IDs
     * @return Map of Account records
     */
    public static Map<Id, Account> getLocationRecordValue(Set<Id> locationIdSet) {
        Map<Id, Account> tempLocationMap = new Map<Id, Account>();
        Set<Id> idsToQuery = new Set<Id>();
        
        try {
            // Check cache first (SDT-40083)
            for (Id locationId : locationIdSet) {
                if (!locationAccountMap.containsKey(locationId)) {
                    idsToQuery.add(locationId);
                }
            }
            
            // Query only uncached records
            if (!idsToQuery.isEmpty()) {
                tempLocationMap = new Map<Id, Account>([
                    SELECT Id, Brand__c, Geography__c, Division__c, 
                           Location_Type__c, tz__Timezone_SFDC__c
                    FROM Account
                    WHERE Id IN :idsToQuery
                    LIMIT 49999
                ]);
                
                locationAccountMap.putAll(tempLocationMap);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex, 
                UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, 
                LoggingLevel.ERROR
            );
        }
        
        return locationAccountMap;
    }
    
    /**
     * @description Query Location for standard cases (fixed timezone)
     * @return Map of Account records
     */
    public static Map<Id, Account> getLocationRecordValueStandardCase() {
        Map<Id, Account> locationMap = new Map<Id, Account>();
        
        try {
            locationMap = new Map<Id, Account>([
                SELECT Id, Name, Brand__c, Geography__c, Division__c, 
                       Location_Type__c, tz__Timezone_SFDC__c
                FROM Account
                WHERE tz__Timezone_SFDC__c = 'America/New_York'
                AND RecordType.Name = 'location'
                AND Status__c = 'Active'
                LIMIT 1
            ]);
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex, 
                UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, 
                LoggingLevel.ERROR
            );
        }
        
        return locationMap;
    }
    
    // ========================================================================
    // UTILITY METHODS
    // ========================================================================
    
    /**
     * @description Get record type ID by name
     * @param recordTypeName Name of the record type
     * @return Record Type ID
     */
    private static Id getRecordTypeId(String recordTypeName) {
        return Schema.getGlobalDescribe()
            .get(Constant_Util.KEYWORD_CASE)
            .getDescribe()
            .getRecordTypeInfosByName()
            .get(recordTypeName)
            .getRecordTypeId();
    }
    
    /**
     * @description Get Corporate Services Queue ID
     * @return Queue ID
     */
    private static Id getCorporateServiceQueueId() {
        String developerName = Constant_Util.CORPORATESERVICESQUEUE;
        return SystemObjectSelector.getGroupId(developerName);
    }
}