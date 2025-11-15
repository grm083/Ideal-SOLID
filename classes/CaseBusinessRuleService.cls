/**
 * @author Waste Management
 * @date 2024
 *
 * @group Cases
 * @group-content ../../ApexDocContent/Cases.htm
 *
 * @description Service class that acts as the central engine for all complex Case-related 
 *              business rules and state validations. This makes business logic explicit and easy 
 *              to manage. When a policy changes, we know exactly which class to update.
 *              It decouples the rules from the UI and DML operations, making the entire system 
 *              more flexible and robust.
 */
public without sharing class CaseBusinessRuleService {
    
    // Constants for business rule evaluation
    private static final String APPROVAL_RT = 'Approval';
    private static final String REQUIRED_INFO_RT = 'Required Information';
    private static final String NOTIFICATION_RT = 'Business Notification';
    
    /**
     * @description Wrapper class to encapsulate business rule evaluation results
     */
    public class BusinessRuleResult {
        public Boolean isAutoApproved { get; set; }
        public Boolean requiresApproval { get; set; }
        public Boolean occurrenceLimitReached { get; set; }
        public Map<Id, Business_Rule__c> approvalRules { get; set; }
        public Map<Id, Business_Rule__c> requiredInfoRules { get; set; }
        public List<String> validationMessages { get; set; }
        
        public BusinessRuleResult() {
            this.isAutoApproved = true;
            this.requiresApproval = false;
            this.occurrenceLimitReached = false;
            this.approvalRules = new Map<Id, Business_Rule__c>();
            this.requiredInfoRules = new Map<Id, Business_Rule__c>();
            this.validationMessages = new List<String>();
        }
    }
    
    /**
     * @description Evaluates all business rules for a given case
     * @param caseId The ID of the case to evaluate
     * @return BusinessRuleResult containing all business rule evaluations
     */
    public static BusinessRuleResult evaluateBusinessRules(Id caseId) {
        BusinessRuleResult result = new BusinessRuleResult();
        
        try {
            // Retrieve case with necessary fields
            Case currentCase = queryCaseForRuleEvaluation(caseId);
            
            if (currentCase == null) {
                result.validationMessages.add('Case not found');
                return result;
            }
            
            // Only evaluate rules for New or Pending cases
            if (!shouldEvaluateRules(currentCase)) {
                return result;
            }
            
            // Get applicable business rules
            Set<Id> recordTypeIds = getBusinessRuleRecordTypeIds();
            List<BusinessRuleHelper.BusinessRulewrapper> businessRules = 
                BusinessRuleHelper.businessRuleSelection(caseId, recordTypeIds);
            
            if (businessRules != null && !businessRules.isEmpty()) {
                categorizeBusinessRules(businessRules, result);
                evaluateApprovalRules(currentCase, result);
                evaluateRequiredInformation(currentCase, result);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            result.validationMessages.add('Error evaluating business rules: ' + ex.getMessage());
        }
        
        return result;
    }
    
    /**
     * @description Validates if a case meets all requirements to proceed to work order creation
     * @param caseId The ID of the case to validate
     * @return Map<String, Object> containing validation results
     */
    public static Map<String, Object> validateCaseReadyForWorkOrder(Id caseId) {
        Map<String, Object> validationResult = new Map<String, Object>{
            'isValid' => true,
            'messages' => new List<String>()
        };
        
        try {
            Case currentCase = queryCaseForWorkOrderValidation(caseId);
            
            if (currentCase == null) {
                validationResult.put('isValid', false);
                ((List<String>)validationResult.get('messages')).add('Case not found');
                return validationResult;
            }
            
            // Validate required fields
            validateRequiredFields(currentCase, validationResult);
            
            // Validate case status
            validateCaseStatus(currentCase, validationResult);
            
            // Validate SLA dates
            validateSLADates(currentCase, validationResult);
            
            // Validate asset eligibility
            validateAssetEligibility(currentCase, validationResult);
            
            // Validate case assets
            validateCaseAssets(currentCase, validationResult);
            
            // Validate business rule requirements
            validateBusinessRuleRequirements(currentCase, validationResult);
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            validationResult.put('isValid', false);
            ((List<String>)validationResult.get('messages')).add('Validation error: ' + ex.getMessage());
        }
        
        return validationResult;
    }
    
    /**
     * @description Determines if a case should bypass work order creation
     * @param currentCase The case to evaluate
     * @return Boolean indicating if WO creation should be bypassed
     */
    public static Boolean shouldBypassWorkOrderCreation(Case currentCase) {
        try {
            // Check WOCreation metadata
            if (String.isNotBlank(currentCase.Case_Type__c) && 
                String.isNotBlank(currentCase.Case_Sub_type__c)) {
                
                String metadataKey = currentCase.Case_Type__c + currentCase.Case_Sub_type__c;
                
                List<WOCreation__mdt> woMetadata = [
                    SELECT WO_Needed__c, Case_Reason__c
                    FROM WOCreation__mdt
                    WHERE Case_Type__c = :currentCase.Case_Type__c
                    AND Case_Subtype__c = :currentCase.Case_Sub_type__c
                    LIMIT 1
                ];
                
                if (!woMetadata.isEmpty()) {
                    WOCreation__mdt metadata = woMetadata[0];
                    
                    // Check if case reason matches
                    if (String.isNotBlank(currentCase.Case_Reason__c) && 
                        String.isNotBlank(metadata.Case_Reason__c)) {
                        return !metadata.WO_Needed__c && 
                               currentCase.Case_Reason__c.equals(metadata.Case_Reason__c);
                    }
                    
                    return !metadata.WO_Needed__c;
                }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return false;
    }
    
    /**
     * @description Validates if case status change is allowed
     * @param oldCase Previous case state
     * @param newCase New case state
     * @return Map containing validation result
     */
    public static Map<String, Object> validateStatusChange(Case oldCase, Case newCase) {
        Map<String, Object> result = new Map<String, Object>{
            'isValid' => true,
            'message' => ''
        };
        
        try {
            // Prevent reopening closed cases without proper permission
            if (oldCase.Status == Constant_Util.CLOSED && 
                oldCase.Status != newCase.Status) {
                
                String userProfileName = getUserProfileName();
                
                if (Constant_Util.CUSTOMER_SERVICE.equalsIgnoreCase(userProfileName) && 
                    !Test.isRunningTest()) {
                    result.put('isValid', false);
                    result.put('message', Constant_Util.CLOSE_CASE_ERROR_CSR);
                }
            }
            
            // Validate required fields for status changes
            if (newCase.Status == Constant_Util.PENDING && 
                String.isBlank(newCase.Case_Sub_Status__c)) {
                result.put('isValid', false);
                result.put('message', 'Case Sub-Status is required when moving to Pending');
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            result.put('isValid', false);
            result.put('message', 'Error validating status change: ' + ex.getMessage());
        }
        
        return result;
    }
    
    /**
     * @description Determines if a case should automatically close
     * @param currentCase The case to evaluate
     * @return Boolean indicating if case should auto-close
     */
    public static Boolean shouldAutoCloseCase(Case currentCase) {
        try {
            // Auto-close logic for specific scenarios
            if (currentCase.Close_Irrelevant_Case__c) {
                return true;
            }
            
            // Check if all related tasks are complete
            if (String.isNotBlank(currentCase.Case_Sub_Status__c) && 
                Constant_Util.CLOSED.equalsIgnoreCase(currentCase.Status)) {
                return true;
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return false;
    }
    
    /**
     * @description Validates if purchase order is required for the case
     * @param currentCase The case to evaluate
     * @return Boolean indicating if PO is required
     */
    public static Boolean isPurchaseOrderRequired(Case currentCase) {
        try {
            BusinessRuleResult ruleResult = evaluateBusinessRules(currentCase.Id);
            
            for (Business_Rule__c rule : ruleResult.requiredInfoRules.values()) {
                if (rule.Required_Information__c != null && 
                    rule.Required_Information__c.contains(Constant_Util.PO_NUMBER)) {
                    return true;
                }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return false;
    }
    
    /**
     * @description Validates if profile number is required for the case
     * @param currentCase The case to evaluate
     * @return Boolean indicating if profile number is required
     */
    public static Boolean isProfileNumberRequired(Case currentCase) {
        try {
            BusinessRuleResult ruleResult = evaluateBusinessRules(currentCase.Id);
            
            for (Business_Rule__c rule : ruleResult.requiredInfoRules.values()) {
                if (rule.Required_Information__c != null && 
                    rule.Required_Information__c.contains(Constant_Util.PROFILE_NUMBER)) {
                    return true;
                }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return false;
    }
    
    /**
     * @description Validates if PSI is required for the case
     * @param currentCase The case to evaluate
     * @return Boolean indicating if PSI is required
     */
    public static Boolean isPSIRequired(Case currentCase) {
        try {
            BusinessRuleResult ruleResult = evaluateBusinessRules(currentCase.Id);
            
            for (Business_Rule__c rule : ruleResult.requiredInfoRules.values()) {
                if (rule.Required_Information__c != null && 
                    rule.Required_Information__c.contains(Constant_Util.PSI)) {
                    return true;
                }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return false;
    }
    
    /**
     * @description Determines if case should have BackOffice flag set
     * @param currentCase The case to evaluate
     * @param corporateServiceQueueId The ID of the corporate services queue
     * @return Boolean indicating if BackOffice flag should be set
     */
    public static Boolean shouldSetBackOfficeFlag(Case currentCase, Id corporateServiceQueueId) {
        try {
            return currentCase.OwnerId != null && 
                   currentCase.OwnerId.equals(corporateServiceQueueId) && 
                   !currentCase.BackOffice_Case__c;
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return false;
    }
    
    /**
     * @description Determines if duplicate work order check should be bypassed
     * @param currentCase The case to evaluate
     * @return Boolean indicating if bypass flag should be set
     */
    public static Boolean shouldBypassDuplicateCheck(Case currentCase) {
        try {
            return currentCase.Create_AM_and_PM_Pickups__c == true || 
                   currentCase.Is_Multivendor__c == true;
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return false;
    }
    
    // ========================================
    // PRIVATE HELPER METHODS
    // ========================================
    
    /**
     * @description Queries case with fields needed for business rule evaluation
     * @param caseId The ID of the case
     * @return Case record with populated fields
     */
    private static Case queryCaseForRuleEvaluation(Id caseId) {
        try {
            return [
                SELECT Id, Status, Case_Sub_Status__c, Client__c, Case_Type__c, 
                       Case_Sub_type__c, Case_Reason__c, Location__c, AssetId, 
                       Service_Date__c, SLA_Service_Date_Time__c, Reference_Number__c,
                       PurchaseOrder_Number__c, Override_PO_Create_Task__c, 
                       Profile_Number__c, Override_Profile_Number_Task__c,
                       PSI__c, PSI_Override_Reason__c, PSI_Comments__c,
                       RecordTypeId, Source_System__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
        } catch (QueryException qe) {
            UTIL_LoggingService.logHandledException(qe, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return null;
        }
    }
    
    /**
     * @description Queries case with fields needed for work order validation
     * @param caseId The ID of the case
     * @return Case record with populated fields
     */
    private static Case queryCaseForWorkOrderValidation(Id caseId) {
        try {
            return [
                SELECT Id, Status, Case_Sub_Status__c, AssetId, ContactId, 
                       Case_Type__c, Case_Sub_type__c, Case_Reason__c,
                       Service_Date__c, SLA_Service_Date_Time__c, Location__c,
                       Is_Multivendor__c, Is_Multiple_Asset__c, RecordTypeId,
                       (SELECT Id FROM Case_Assets1__r)
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
        } catch (QueryException qe) {
            UTIL_LoggingService.logHandledException(qe, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return null;
        }
    }
    
    /**
     * @description Determines if business rules should be evaluated for a case
     * @param currentCase The case to check
     * @return Boolean indicating if rules should be evaluated
     */
    private static Boolean shouldEvaluateRules(Case currentCase) {
        return currentCase.Status == Constant_Util.STATUS_New || 
               (currentCase.Status == Constant_Util.PENDING && 
                (Constant_Util.PENDING_CUSTOMER_INFORMATION.equals(currentCase.Case_Sub_Status__c) || 
                 Constant_Util.PENDING_REQUEST_APPROVAL.equals(currentCase.Case_Sub_Status__c)));
    }
    
    /**
     * @description Gets the set of business rule record type IDs to query
     * @return Set of record type IDs
     */
    private static Set<Id> getBusinessRuleRecordTypeIds() {
        Set<Id> recordTypeIds = new Set<Id>();
        
        try {
            Schema.DescribeSObjectResult descResult = Business_Rule__c.SObjectType.getDescribe();
            Map<String, Schema.RecordTypeInfo> rtMap = descResult.getRecordTypeInfosByName();
            
            if (rtMap.containsKey(APPROVAL_RT)) {
                recordTypeIds.add(rtMap.get(APPROVAL_RT).getRecordTypeId());
            }
            
            if (rtMap.containsKey(REQUIRED_INFO_RT)) {
                recordTypeIds.add(rtMap.get(REQUIRED_INFO_RT).getRecordTypeId());
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return recordTypeIds;
    }
    
    /**
     * @description Categorizes business rules into approval and required info maps
     * @param businessRules List of business rule wrappers
     * @param result BusinessRuleResult to populate
     */
    private static void categorizeBusinessRules(
        List<BusinessRuleHelper.BusinessRulewrapper> businessRules, 
        BusinessRuleResult result) {
        
        try {
            Id approvalRtId = Schema.SObjectType.Business_Rule__c
                .getRecordTypeInfosByName().get(APPROVAL_RT).getRecordTypeId();
            Id reqInfoRtId = Schema.SObjectType.Business_Rule__c
                .getRecordTypeInfosByName().get(REQUIRED_INFO_RT).getRecordTypeId();
            
            for (BusinessRuleHelper.BusinessRulewrapper wrapper : businessRules) {
                if (wrapper.bRule.RecordTypeId == reqInfoRtId) {
                    result.requiredInfoRules.put(wrapper.caseId, wrapper.bRule);
                } else if (wrapper.bRule.RecordTypeId == approvalRtId) {
                    result.approvalRules.put(wrapper.caseId, wrapper.bRule);
                }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
     * @description Evaluates approval rules for a case
     * @param currentCase The case being evaluated
     * @param result BusinessRuleResult to update
     */
    private static void evaluateApprovalRules(Case currentCase, BusinessRuleResult result) {
        try {
            if (result.approvalRules.isEmpty()) {
                result.isAutoApproved = true;
                result.requiresApproval = false;
                return;
            }
            
            // Get approval evaluation from BusinessRuleHelper
            Map<Id, Case> caseMap = new Map<Id, Case>{ currentCase.Id => currentCase };
            List<Case> caseList = new List<Case>{ currentCase };
            
            BusinessRuleHelper.wrapperResult brWrapper = 
                BusinessRuleHelper.getapprovallog(
                    result.approvalRules, 
                    caseList, 
                    CaseTriggerHelper.caseWorkOrderCount
                );
            
            if (brWrapper != null && brWrapper.autoApprovemap != null) {
                result.isAutoApproved = brWrapper.autoApprovemap.containsKey(currentCase.Id) ? 
                    brWrapper.autoApprovemap.get(currentCase.Id) : true;
                result.requiresApproval = !result.isAutoApproved;
            }
            
            if (brWrapper != null && brWrapper.occurenceLimitmap != null) {
                result.occurrenceLimitReached = brWrapper.occurenceLimitmap.containsKey(currentCase.Id) ? 
                    brWrapper.occurenceLimitmap.get(currentCase.Id) : false;
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
     * @description Evaluates required information rules for a case
     * @param currentCase The case being evaluated
     * @param result BusinessRuleResult to update
     */
    private static void evaluateRequiredInformation(Case currentCase, BusinessRuleResult result) {
        try {
            for (Business_Rule__c rule : result.requiredInfoRules.values()) {
                if (rule.Required_Information__c == null) {
                    continue;
                }
                
                // Check PO requirement
                if (rule.Required_Information__c.contains(Constant_Util.PO_NUMBER) && 
                    String.isBlank(currentCase.PurchaseOrder_Number__c) && 
                    !currentCase.Override_PO_Create_Task__c) {
                    result.validationMessages.add(Constant_Util.PO_MSG);
                }
                
                // Check Profile Number requirement
                if (rule.Required_Information__c.contains(Constant_Util.PROFILE_NUMBER) && 
                    String.isBlank(currentCase.Profile_Number__c) && 
                    !currentCase.Override_Profile_Number_Task__c) {
                    result.validationMessages.add(Constant_Util.PROFILE_MSG);
                }
                
                // Check PSI requirement
                if (rule.Required_Information__c.contains(Constant_Util.PSI)) {
                    if (currentCase.PSI__c == null) {
                        if (currentCase.PSI_Override_Reason__c == null) {
                            result.validationMessages.add(Constant_Util.PSI_REQUIRED);
                        } else if (currentCase.PSI_Override_Reason__c == Constant_Util.OTHER_API && 
                                   currentCase.PSI_Comments__c == null) {
                            result.validationMessages.add(Constant_Util.PSI_COMMENTS);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
     * @description Validates required fields are populated
     * @param currentCase The case to validate
     * @param validationResult Map to update with results
     */
    private static void validateRequiredFields(Case currentCase, Map<String, Object> validationResult) {
        List<String> messages = (List<String>)validationResult.get('messages');
        
        if (String.isBlank(currentCase.ContactId)) {
            validationResult.put('isValid', false);
            messages.add(Constant_Util.SELECT_CONTACT);
        }
        
        if (String.isBlank(currentCase.Case_Sub_type__c)) {
            validationResult.put('isValid', false);
            messages.add(Constant_Util.SELECT_CASESUBTYPE);
        }
    }
    
    /**
     * @description Validates case status is appropriate for work order
     * @param currentCase The case to validate
     * @param validationResult Map to update with results
     */
    private static void validateCaseStatus(Case currentCase, Map<String, Object> validationResult) {
        List<String> messages = (List<String>)validationResult.get('messages');
        
        if (currentCase.Status != Constant_Util.STATUS_New && 
            currentCase.Status != Constant_Util.PENDING) {
            validationResult.put('isValid', false);
            messages.add('Case must be in New or Pending status');
        }
    }
    
    /**
     * @description Validates SLA dates are set correctly
     * @param currentCase The case to validate
     * @param validationResult Map to update with results
     */
    private static void validateSLADates(Case currentCase, Map<String, Object> validationResult) {
        List<String> messages = (List<String>)validationResult.get('messages');
        
        if (currentCase.SLA_Service_Date_Time__c == null) {
            validationResult.put('isValid', false);
            messages.add(Constant_Util.SELECT_CASESLADATE);
        }
    }
    
    /**
     * @description Validates asset eligibility for work order
     * @param currentCase The case to validate
     * @param validationResult Map to update with results
     */
    private static void validateAssetEligibility(Case currentCase, Map<String, Object> validationResult) {
        List<String> messages = (List<String>)validationResult.get('messages');
        
        // Asset validation will be handled by CaseAssetValidator service
        // This is a placeholder for integration
        if (String.isBlank(currentCase.AssetId) && 
            currentCase.Case_Sub_type__c != Constant_Util.BALES) {
            validationResult.put('isValid', false);
            messages.add(Constant_Util.SELECT_ASSET);
        }
    }
    
    /**
     * @description Validates case assets exist and are valid
     * @param currentCase The case to validate
     * @param validationResult Map to update with results
     */
    private static void validateCaseAssets(Case currentCase, Map<String, Object> validationResult) {
        List<String> messages = (List<String>)validationResult.get('messages');
        
        // Check if case assets exist when required
        if (currentCase.Case_Assets1__r == null || currentCase.Case_Assets1__r.isEmpty()) {
            if (currentCase.Case_Type__c == Constant_Util.PICKUP_CSTYPE && 
                !currentCase.Is_Multivendor__c) {
                validationResult.put('isValid', false);
                messages.add(Constant_Util.NO_CASE_ASSETS);
            }
        }
    }
    
    /**
     * @description Validates business rule requirements are met
     * @param currentCase The case to validate
     * @param validationResult Map to update with results
     */
    private static void validateBusinessRuleRequirements(Case currentCase, Map<String, Object> validationResult) {
        List<String> messages = (List<String>)validationResult.get('messages');
        
        BusinessRuleResult ruleResult = evaluateBusinessRules(currentCase.Id);
        
        if (!ruleResult.validationMessages.isEmpty()) {
            validationResult.put('isValid', false);
            messages.addAll(ruleResult.validationMessages);
        }
        
        if (ruleResult.requiresApproval) {
            validationResult.put('isValid', false);
            messages.add('Case requires approval before work order can be created');
        }
    }
    
    /**
     * @description Gets the current user's profile name
     * @return String profile name
     */
    private static String getUserProfileName() {
        try {
            Id userProfileId = UserInfo.getProfileId();
            Profile userProfile = [SELECT Name FROM Profile WHERE Id = :userProfileId LIMIT 1];
            return userProfile.Name;
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return '';
        }
    }
    
    // ========================================
    // WORKORDER-DRIVEN CASE UPDATES
    // ========================================
    
    /**
     * @description Processes all WorkOrder status changes and determines Case updates
     * @param woMap Map of WorkOrder records (new values)
     * @param oldWoMap Map of WorkOrder records (old values)
     * @param caseMap Map of related Case records
     * @return List of Case records to be updated
     */
    public static List<Case> processWorkOrderStatusChanges(
        Map<Id,WorkOrder> woMap, 
        Map<Id,WorkOrder> oldWoMap,
        Map<Id,Case> caseMap
    ) {
        List<Case> casesToUpdate = new List<Case>();
        List<Case> casesForRelatedCreation = new List<Case>();
        Map<Id,Account> vendorsMap = getVendorAccounts(woMap.values());
        
        try {
            for(WorkOrder wo : woMap.values()) {
                Case relatedCase = caseMap.get(wo.CaseId);
                if(relatedCase == null) continue;
                
                WorkOrder oldWo = oldWoMap != null ? oldWoMap.get(wo.Id) : null;
                
                // Process proposed service date updates
                updateProposedServiceDate(wo, oldWo, relatedCase);
                
                // Process vendor-related updates
                updateFromVendorChanges(wo, oldWo, relatedCase, vendorsMap);
                
                // Process sub-status changes based on WorkOrder status
                updateSubStatusFromWorkOrder(wo, oldWo, relatedCase);
                
                // Handle service confirmation
                handleServiceConfirmation(wo, oldWo, relatedCase);
                
                // Handle service not performed (requires related case creation)
                if(handleServiceNotPerformed(wo, oldWo, relatedCase)) {
                    casesForRelatedCreation.add(relatedCase);
                }
                
                // Handle rejection
                handleRejection(wo, oldWo, relatedCase);
                
                casesToUpdate.add(relatedCase);
            }
            
            // Create related cases for service not performed scenarios
            if(!casesForRelatedCreation.isEmpty()) {
                CaseCreation.createRelatedCase(casesForRelatedCreation);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.WORKORDER_TRIGGER_HELPER, LoggingLevel.ERROR);
        }
        
        return casesToUpdate;
    }
    
    /**
     * @description Updates Case Proposed_Service_Date__c based on WorkOrder changes
     */
    private static void updateProposedServiceDate(WorkOrder wo, WorkOrder oldWo, Case relatedCase) {
        if(Constant_Util.CLOSED.equalsIgnoreCase(relatedCase.Status)) return;
        
        // Update from Service_Date__c change
        if(oldWo != null && wo.Service_Date__c != oldWo.Service_Date__c && 
           wo.Vendor_Service_Status__c != oldWo.Vendor_Service_Status__c || 
           !RecurrsiveTriggerHandler.bypassValidation) {
            relatedCase.Proposed_Service_Date__c = wo.Service_Date__c;
        }
        
        // Update from Rescheduled_Date__c change
        if(oldWo != null && wo.Rescheduled_Date__c != oldWo.Rescheduled_Date__c && 
           wo.Vendor_Service_Status__c != oldWo.Vendor_Service_Status__c || 
           !RecurrsiveTriggerHandler.bypassValidation) {
            relatedCase.Proposed_Service_Date__c = wo.Rescheduled_Date__c != null ? 
                wo.Rescheduled_Date__c.Date() : null;
        }
    }
    
    /**
     * @description Updates Case based on vendor-related WorkOrder changes
     */
    private static void updateFromVendorChanges(
        WorkOrder wo, 
        WorkOrder oldWo, 
        Case relatedCase,
        Map<Id,Account> vendorsMap
    ) {
        if(oldWo == null || oldWo.Acorn_WorkOrder_Number__c == wo.Acorn_WorkOrder_Number__c) return;
        if(!Constant_Util.OPEN.equalsIgnoreCase(relatedCase.Status)) return;
        
        // Check if vendor requires manual dispatch
        Boolean isManualVendor = false;
        if(wo.Vendor_Account_Id__c != null && vendorsMap.containsKey(wo.Vendor_Account_Id__c)) {
            isManualVendor = vendorsMap.get(wo.Vendor_Account_Id__c).Contact_Manually_Vendor__c;
        }
        
        if(isManualVendor && 
           relatedCase.Service_Date__c >= relatedCase.Service_date_from_local_time__c && 
           !Constant_Util.Pending_Manual_Dispatch.equalsIgnoreCase(relatedCase.Case_Sub_Status__c) && 
           !wo.Is_Bypass__c) {
            relatedCase.Case_Sub_Status__c = Constant_Util.Pending_Manual_Dispatch;
            relatedCase.Status = Constant_Util.OPEN;
        } else {
            // Standard dispatch flow
            if((Constant_Util.PENDING_SERVICE_INTEGRATION.equalsIgnoreCase(relatedCase.Case_Sub_Status__c) || 
                relatedCase.Source_System__c == 'Acorn') && 
               Constant_Util.OPEN.equalsIgnoreCase(relatedCase.Status)) {
                
                if((Constant_Util.ISSUED.equalsIgnoreCase(wo.Status) || 
                    (Constant_Util.SENT.equalsIgnoreCase(wo.Status) && 
                     Constant_Util.SCHEDULED.equalsIgnoreCase(wo.Send_Status__c))) && 
                   !Constant_Util.Pending_Dispatch.equalsIgnoreCase(relatedCase.Case_Sub_Status__c) && 
                   !isManualVendor) {
                    relatedCase.Case_Sub_Status__c = Constant_Util.Pending_Dispatch;
                }
            }
        }
    }
    
    /**
     * @description Updates Case sub-status based on WorkOrder status transitions
     */
    private static void updateSubStatusFromWorkOrder(WorkOrder wo, WorkOrder oldWo, Case relatedCase) {
        if(Constant_Util.CLOSED.equalsIgnoreCase(relatedCase.Status)) return;
        
        // Check for service confirmation pending
        if((Constant_Util.SENT.equalsIgnoreCase(wo.Send_Status__c) || 
            Constant_Util.DELIVERED.equalsIgnoreCase(wo.Send_Status__c)) &&
           (!Constant_Util.ACCEPTED.equalsIgnoreCase(wo.Status) && 
            !Constant_Util.CANCELLED.equalsIgnoreCase(wo.Status) && 
            !Constant_Util.CLOSED.equalsIgnoreCase(wo.Status)) &&
           !Constant_Util.CLOSED.equalsIgnoreCase(relatedCase.Status) && 
           relatedCase.Service_Date__c >= System.today() &&
           !Constant_Util.Pending_Service_Confirmation.equalsIgnoreCase(relatedCase.Case_Sub_Status__c) &&
           !Constant_Util.Pending_Schedule_Confirmation.equalsIgnoreCase(relatedCase.Case_Sub_Status__c)) {
            
            if(relatedCase.Availability_Confirmed__c) {
                relatedCase.Case_Sub_Status__c = Constant_Util.Pending_Service_Confirmation;
            } else {
                relatedCase.Case_Sub_Status__c = Constant_Util.Pending_Schedule_Confirmation;
            }
            relatedCase.Status = Constant_Util.OPEN;
        }
        
        // Check for past service date requiring confirmation
        if(oldWo != null && 
           !Constant_Util.Pending_Service_Confirmation.equalsIgnoreCase(relatedCase.Case_Sub_Status__c) && 
           Constant_Util.OPEN.equalsIgnoreCase(relatedCase.Status)) {
            
            if(((wo.Status != oldWo.Status) && 
                (Constant_Util.SENT.equalsIgnoreCase(wo.Status) || 
                 Constant_Util.RELEASED_FOR_PAYMENT.equalsIgnoreCase(wo.Status) || 
                 Constant_Util.ACCEPTED.equalsIgnoreCase(wo.Status) || 
                 Constant_Util.WORK_COMPLETE.equalsIgnoreCase(wo.Status) || 
                 Constant_Util.CLOSED.equalsIgnoreCase(wo.Status)) &&
                wo.Service_Date__c < System.today() &&
                !Constant_Util.Pending_Manual_Dispatch.equalsIgnoreCase(relatedCase.Case_Sub_Status__c) &&
                (String.isBlank(wo.Vendor_Service_Status__c) || 
                 Constant_Util.SCHEDULED.equalsIgnoreCase(wo.Vendor_Service_Status__c))) ||
               (Constant_Util.SCHEDULED.equalsIgnoreCase(wo.Vendor_Service_Status__c) || 
                !String.isBlank(wo.MAS_Ticket__c)) ||
               (Constant_Util.OPEN.equalsIgnoreCase(relatedCase.Status) && 
                !Constant_Util.Pending_Manual_Dispatch.equalsIgnoreCase(relatedCase.Case_Sub_Status__c) && 
                Constant_Util.ACCEPTED.equalsIgnoreCase(wo.Status))) {
                
                relatedCase.Status = Constant_Util.OPEN;
                relatedCase.Case_Sub_Status__c = Constant_Util.Pending_Service_Confirmation;
            }
        }
    }
    
    /**
     * @description Handles service confirmation from WorkOrder
     */
    private static void handleServiceConfirmation(WorkOrder wo, WorkOrder oldWo, Case relatedCase) {
        if(wo.Vendor_Service_Status__c == null) return;
        if(oldWo != null && oldWo.Vendor_Service_Status__c == wo.Vendor_Service_Status__c) return;
        
        if(wo.Vendor_Service_Status__c.contains(Constant_Util.CONFIRMED_POSITIVE) &&
           (Constant_Util.CLOSED.equalsIgnoreCase(relatedCase.Status) ||
            ((Constant_Util.SENT.equalsIgnoreCase(wo.Status) ||
              Constant_Util.RELEASED_FOR_PAYMENT.equalsIgnoreCase(wo.Status) ||
              Constant_Util.ACCEPTED.equalsIgnoreCase(wo.Status) ||
              Constant_Util.WORK_COMPLETE.equalsIgnoreCase(wo.Status) ||
              Constant_Util.CLOSED.equalsIgnoreCase(wo.Status)) &&
             Constant_Util.OPEN.equalsIgnoreCase(relatedCase.Status) &&
             !Constant_Util.Pending_Manual_Dispatch.equalsIgnoreCase(relatedCase.Case_Sub_Status__c)))) {
            
            relatedCase.Case_Sub_Status__c = Constant_Util.SERVICE_CONFIRMED;
            relatedCase.Status = Constant_Util.CLOSED;
        }
    }
    
    /**
     * @description Handles service not performed scenario
     * @return Boolean indicating if related case should be created
     */
    private static Boolean handleServiceNotPerformed(WorkOrder wo, WorkOrder oldWo, Case relatedCase) {
        if(wo.Vendor_Service_Status__c == null) return false;
        if(!wo.Vendor_Service_Status__c.contains(Constant_Util.CONFIRMED_NEGATIVE)) return false;
        
        Boolean shouldCreateRelatedCase = Constant_Util.OPEN.equalsIgnoreCase(relatedCase.Status);
        
        relatedCase.Case_Sub_Status__c = Constant_Util.SERVICE_NOT_PERFORMED;
        relatedCase.Status = Constant_Util.CLOSED;
        
        return shouldCreateRelatedCase;
    }
    
    /**
     * @description Handles WorkOrder rejection
     */
    private static void handleRejection(WorkOrder wo, WorkOrder oldWo, Case relatedCase) {
        if(oldWo == null || oldWo.Status == wo.Status) return;
        
        if(Constant_Util.CANCELLED.equalsIgnoreCase(wo.Status) &&
           Constant_Util.OPEN.equalsIgnoreCase(relatedCase.Status) &&
           !Constant_Util.Request_Canceled.equalsIgnoreCase(relatedCase.Case_Sub_Status__c)) {
            relatedCase.Status = Constant_Util.CLOSED;
            relatedCase.Case_Sub_Status__c = Constant_Util.Request_Canceled;
        }
        
        if(Constant_Util.REJECTED.equalsIgnoreCase(wo.Status)) {
            relatedCase.Status = Constant_Util.CLOSED;
        }
    }
    
    /**
     * @description Retrieves vendor accounts for manual dispatch check
     */
    private static Map<Id,Account> getVendorAccounts(List<WorkOrder> workOrders) {
        Set<Id> vendorIds = new Set<Id>();
        for(WorkOrder wo : workOrders) {
            if(wo.Vendor_Account_Id__c != null) {
                vendorIds.add(wo.Vendor_Account_Id__c);
            }
        }
        
        if(vendorIds.isEmpty()) return new Map<Id,Account>();
        
        return new Map<Id,Account>(
            [SELECT Id, Contact_Manually_Vendor__c 
             FROM Account 
             WHERE Id IN :vendorIds]
        );
    }
    
    // ========================================
    // TASK-DRIVEN CASE UPDATES
    // ========================================
    
    /**
     * @description Updates Case Availability_Confirmed__c based on task outcome
     * @param tasks List of tasks with Confirm Vendor Availability process
     * @param relatedCases Map of related cases
     * @return List of cases to update
     */
    public static List<Case> processAvailabilityConfirmation(
        List<Task> tasks,
        Map<Id,Case> relatedCases
    ) {
        List<Case> casesToUpdate = new List<Case>();
        
        try {
            for(Task t : tasks) {
                if(String.isBlank(t.Process__c) || String.isBlank(t.Outcome__c)) continue;
                if(!t.Process__c.contains(Constant_Util.Confirm_Vendor_Availability)) continue;
                if(!t.Outcome__c.contains(Constant_Util.Vendor_Available)) continue;
                
                Case relatedCase = relatedCases.get(t.WhatId);
                if(relatedCase != null) {
                    relatedCase.Availability_Confirmed__c = true;
                    casesToUpdate.add(relatedCase);
                }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.TASK_TRIGGER_HELPER, LoggingLevel.ERROR);
        }
        
        return casesToUpdate;
    }
    
    /**
     * @description Processes task approval outcomes and updates Case accordingly
     * @param tasks List of approval tasks
     * @param relatedCases Map of related cases
     * @return List of cases to update
     */
    public static List<Case> processTaskApprovalOutcome(
        List<Task> tasks,
        Map<Id,Case> relatedCases
    ) {
        List<Case> casesToUpdate = new List<Case>();
        
        try {
            for(Task tsk : tasks) {
                if(tsk.Process__c != 'Escalation Obtain Service Approval') continue;
                if(tsk.Attempt__c != 2) continue;
                
                Case relatedCase = relatedCases.get(tsk.WhatId);
                if(relatedCase == null) continue;
                
                if(tsk.Outcome__c == 'Approved') {
                    relatedCase.Status = Constant_Util.OPEN;
                    relatedCase.Case_Sub_Status__c = 'Pending Service Integration';
                    casesToUpdate.add(relatedCase);
                } else if(tsk.Outcome__c == 'Rejected') {
                    relatedCase.Status = Constant_Util.CLOSED;
                    relatedCase.Case_Sub_Status__c = 'Request Not Approved';
                    casesToUpdate.add(relatedCase);
                }
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.TASK_TRIGGER_HELPER, LoggingLevel.ERROR);
        }
        
        return casesToUpdate;
    }
    
    // ========================================
    // ADDITIONAL BUSINESS RULE METHODS
    // ========================================
    
    /**
     * @description Processes approval logs and creates related tasks
     * @param newCasemap New case map
     * @param oldCasemap Old case map
     */
    public static void processApprovalLogs(Map<Id,Case> newCasemap, Map<Id,Case> oldCasemap) {
        try {
            List<Approval_Log__c> approvalLogsToInsert = new List<Approval_Log__c>();
            List<Task> tasksToCreate = new List<Task>();
            
            for (Case newCase : newCasemap.values()) {
                Case oldCase = oldCasemap != null ? oldCasemap.get(newCase.Id) : null;
                
                // Check if approval status changed
                if (oldCase != null && 
                    newCase.Status != oldCase.Status && 
                    newCase.Status == Constant_Util.PENDING && 
                    Constant_Util.PENDING_REQUEST_APPROVAL.equals(newCase.Case_Sub_Status__c)) {
                    
                    // Create approval log
                    Approval_Log__c approvalLog = new Approval_Log__c();
                    approvalLog.CaseId__c = newCase.Id;
                    approvalLog.Decision_Date_Time__c = System.now();
                    approvalLog.Status__c = 'Pending';
                    approvalLogsToInsert.add(approvalLog);
                    
                    // Create approval task
                    Task approvalTask = new Task();
                    approvalTask.WhatId = newCase.Id;
                    approvalTask.Subject = 'Approval Required';
                    approvalTask.Process__c = 'Escalation Obtain Service Approval';
                    approvalTask.Status = 'Open';
                    approvalTask.Priority = 'High';
                    approvalTask.ActivityDate = System.today().addDays(2);
                    tasksToCreate.add(approvalTask);
                }
            }
            
            // Insert approval logs
            if (!approvalLogsToInsert.isEmpty()) {
                Database.SaveResult[] logResults = Database.insert(approvalLogsToInsert, false);
                UTIL_LoggingService.logDmlResults(logResults, null, approvalLogsToInsert, '', 
                    UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
            }
            
            // Insert tasks
            if (!tasksToCreate.isEmpty()) {
                Database.SaveResult[] taskResults = Database.insert(tasksToCreate, false);
                UTIL_LoggingService.logDmlResults(taskResults, null, tasksToCreate, '', 
                    UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS, LoggingLevel.ERROR);
        }
    }
    
    /**
     * @description Evaluates business rules and updates case status accordingly
     * @param newcasemap New cases
     * @param oldCasemap Old cases
     * @param subtypeSet Case subtypes to evaluate
     * @param startDate Start dates for work order checking
     * @param endDate End dates for work order checking
     * @param casewithContainer Related assets
     * @param casewithLocation Related locations
     * @param caseWorkOrderCount Work order counts
     */
    public static void evaluateAndApplyBusinessRules(
        Map<Id,Case> newcasemap, 
        Map<Id,Case> oldCasemap, 
        Set<String> subtypeSet, 
        Map<String,Date> startDate, 
        Map<String,Date> endDate,
        Map<Id,Asset> casewithContainer, 
        Map<Id,Account> casewithLocation, 
        Map<String,Integer> caseWorkOrderCount
    ) {
        try {
            // Get business rule record types
            Set<Id> recordTypeIds = getBusinessRuleRecordTypeIds();
            
            // Query applicable business rules
            List<Id> recordIdList = new List<Id>(newcasemap.keyset());
            Map<Id, Map<String, List<Business_Rule__c>>> businessRules = BusinessRuleUtility.getPriorityBusinessRulesBulk(recordIdList);
            
            if (businessRules == null || businessRules.isEmpty()) {
                return;
            }
            
            // Categorize rules
            Map<Id, Business_Rule__c> approvalRules = new Map<Id, Business_Rule__c>();
            Map<Id, Business_Rule__c> requiredInfoRules = new Map<Id, Business_Rule__c>();
            
            
            for (Id c : recordIdList) {
                Map<String, List<Business_Rule__c>> recordBRMap = new Map<String, List<Business_Rule__c>>();
                if(businessRules.get(c) != null) {
                    recordBRMap = businessRules.get(c);
                    if(recordBRMap.get('Approval') != null) {
                        for (Business_Rule__c br : recordBRMap.get('Approval')) {
                            approvalRules.put(c, br);
                        }
                    }
                    if(recordBRMap.get('Required Information') != null) {
                        for (Business_Rule__c br : recordBRMap.get('Required Information')) {
                            requiredInfoRules.put(c, br);
                        }
                    }
                } else {
                    continue;
                }
            }
            
            // Process approval rules
            if (!approvalRules.isEmpty()) {
                List<Case> caseList = newcasemap.values();
                BusinessRuleHelper.wrapperResult brWrapper = 
                    BusinessRuleHelper.getapprovallog(approvalRules, caseList, caseWorkOrderCount);
                
                if (brWrapper != null && brWrapper.autoApprovemap != null) {
                    for (Id caseId : brWrapper.autoApprovemap.keySet()) {
                        Case currentCase = newcasemap.get(caseId);
                        if (currentCase != null && !brWrapper.autoApprovemap.get(caseId)) {
                            currentCase.Status = Constant_Util.PENDING;
                            currentCase.Case_Sub_Status__c = Constant_Util.PENDING_REQUEST_APPROVAL;
                        }
                    }
                }
            }
            
            // Process required information rules
            if (!requiredInfoRules.isEmpty()) {
                for (Id caseId : requiredInfoRules.keySet()) {
                    Case currentCase = newcasemap.get(caseId);
                    Business_Rule__c rule = requiredInfoRules.get(caseId);
                    
                    if (currentCase != null && rule.Required_Information__c != null) {
                        // Check for missing required information
                        if (rule.Required_Information__c.contains(Constant_Util.PO_NUMBER) && 
                            String.isBlank(currentCase.PurchaseOrder_Number__c) && 
                            !currentCase.Override_PO_Create_Task__c) {
                            currentCase.Status = Constant_Util.PENDING;
                            currentCase.Case_Sub_Status__c = Constant_Util.PENDING_CUSTOMER_INFORMATION;
                        }
                    }
                }
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS, LoggingLevel.ERROR);
        }
    }
    
    /**
     * @description Closes tasks related to closed cases
     * @param casemap Cases being closed
     * @param caseOldmap Previous case states
     */
    public static void closeRelatedTasks(Map<Id,Case> casemap, Map<Id,Case> caseOldmap) {
        try {
            List<Task> tasksToClose = new List<Task>();
            Set<Id> closedCaseIds = new Set<Id>();
            
            // Identify cases that were just closed
            for (Case newCase : casemap.values()) {
                Case oldCase = caseOldmap != null ? caseOldmap.get(newCase.Id) : null;
                
                if (oldCase != null && 
                    newCase.Status == Constant_Util.CLOSED && 
                    oldCase.Status != Constant_Util.CLOSED) {
                    closedCaseIds.add(newCase.Id);
                }
            }
            
            if (closedCaseIds.isEmpty()) {
                return;
            }
            
            // Query open tasks related to closed cases
            List<Task> openTasks = [
                SELECT Id, Status, IsClosed
                FROM Task
                WHERE WhatId IN :closedCaseIds
                AND IsClosed = false
            ];
            
            // Mark tasks as completed
            for (Task t : openTasks) {
                t.Status = 'Completed';
                tasksToClose.add(t);
            }
            
            if (!tasksToClose.isEmpty()) {
                Database.SaveResult[] results = Database.update(tasksToClose, false);
                UTIL_LoggingService.logDmlResults(results, null, tasksToClose, '', 
                    UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS, LoggingLevel.ERROR);
        }
    }
    
    /**
     * @description Declines quotes associated with closed cases
     * @param closedCaseMap Closed cases
     */
    public static void declineAssociatedQuotes(Map<Id,Case> closedCaseMap) {
        try {
            // Query quotes related to closed cases
            List<SBQQ__Quote__c> relatedQuotes = [
                SELECT Id, SBQQ__Status__c
                FROM SBQQ__Quote__c
                WHERE SBQQ__Opportunity2__r.Case__c IN :closedCaseMap.keySet()
                AND SBQQ__Status__c != 'Declined'
                AND SBQQ__Status__c != 'Accepted'
            ];
            
            if (relatedQuotes.isEmpty()) {
                return;
            }
            
            // Decline quotes
            for (SBQQ__Quote__c q : relatedQuotes) {
                q.SBQQ__Status__c = 'Declined';
            }
            
            Database.SaveResult[] results = Database.update(relatedQuotes, false);
            UTIL_LoggingService.logDmlResults(results, null, relatedQuotes, '', 
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS, LoggingLevel.ERROR);
        }
    }
    
    /**
     * @description Updates Genesys task routing records when case ownership changes
     * @param newMap New cases
     * @param oldMap Previous states
     */
    public static void updateGenesysRouting(Map<Id,Case> newMap, Map<Id,Case> oldMap) {
        try {
            List<Genesys_Routing__c> routingToUpdate = new List<Genesys_Routing__c>();
            Set<Id> caseIdsToUpdate = new Set<Id>();
            
            // Identify cases with owner changes
            for (Case newCase : newMap.values()) {
                Case oldCase = oldMap != null ? oldMap.get(newCase.Id) : null;
                
                if (oldCase != null && newCase.OwnerId != oldCase.OwnerId) {
                    caseIdsToUpdate.add(newCase.Id);
                }
            }
            
            if (caseIdsToUpdate.isEmpty()) {
                return;
            }
            
            // Query related Genesys routing records
            List<Genesys_Routing__c> existingRouting = [
                SELECT Id, SFDCObjRecordID__c, OwnerId
                FROM Genesys_Routing__c
                WHERE SFDCObjRecordID__c IN :caseIdsToUpdate
            ];
            
            // Update routing records with new owner
            for (Genesys_Routing__c routing : existingRouting) {
                Case relatedCase = newMap.get(routing.SFDCObjRecordID__c);
                if (relatedCase != null) {
                    routing.OwnerId = relatedCase.OwnerId;
                    routingToUpdate.add(routing);
                }
            }
            
            if (!routingToUpdate.isEmpty()) {
                Database.SaveResult[] results = Database.update(routingToUpdate, false);
                UTIL_LoggingService.logDmlResults(results, null, routingToUpdate, '', 
                    UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS, LoggingLevel.ERROR);
        }
    }
    
    /**
     * @description Sends email notifications for work order creation
     * @param emailCaseList Cases to send notifications about
     * @param emailTemplate Template name
     */
    public static void sendWorkOrderNotifications(List<Case> emailCaseList, String emailTemplate) {
        try {
            if (emailCaseList.isEmpty() || String.isBlank(emailTemplate)) {
                return;
            }
            
            // Query email template
            List<EmailTemplate> templates = [
                SELECT Id, Subject, Body
                FROM EmailTemplate
                WHERE DeveloperName = :emailTemplate
                LIMIT 1
            ];
            
            if (templates.isEmpty()) {
                return;
            }
            
            EmailTemplate template = templates[0];
            List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
            
            // Create emails for each case
            for (Case c : emailCaseList) {
                if (String.isBlank(c.ContactId)) {
                    continue;
                }
                
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setTemplateId(template.Id);
                email.setTargetObjectId(c.ContactId);
                email.setWhatId(c.Id);
                email.setSaveAsActivity(true);
                emailsToSend.add(email);
            }
            
            if (!emailsToSend.isEmpty()) {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emailsToSend, false);
                
                // Log any failures
                for (Integer i = 0; i < results.size(); i++) {
                    if (!results[i].isSuccess()) {
                        for (Messaging.SendEmailError error : results[i].getErrors()) {
                            UTIL_LoggingService.logHandledException(
                                new EmailException('Email send failed: ' + error.getMessage()), 
                                UserInfo.getOrganizationId(), 
                                UTIL_ErrorConstants.CASE_TRIGGER_CLASS, 
                                LoggingLevel.ERROR
                            );
                        }
                    }
                }
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS, LoggingLevel.ERROR);
        }
    }
    
    /**
     * @description Adds case comments for work order acceptance/rejection
     * @param caseLst Cases to comment on
     */
    public static void addWorkOrderStatusComments(List<Case> caseLst) {
        try {
            List<CaseComment> commentsToInsert = new List<CaseComment>();
            
            for (Case c : caseLst) {
                // Determine comment based on case status
                String commentBody = '';
                
                if (c.Case_Sub_Status__c == Constant_Util.SERVICE_CONFIRMED) {
                    commentBody = 'Work order has been accepted and service confirmed.';
                } else if (c.Case_Sub_Status__c == Constant_Util.SERVICE_NOT_PERFORMED) {
                    commentBody = 'Work order service was not performed as scheduled.';
                } else if (c.Case_Sub_Status__c == Constant_Util.Request_Canceled) {
                    commentBody = 'Work order has been cancelled.';
                } else if (c.Status == Constant_Util.CLOSED && 
                           c.Case_Sub_Status__c == 'Request Not Approved') {
                    commentBody = 'Work order request was not approved.';
                }
                
                if (String.isNotBlank(commentBody)) {
                    CaseComment comment = new CaseComment();
                    comment.ParentId = c.Id;
                    comment.CommentBody = commentBody;
                    comment.IsPublished = true;
                    commentsToInsert.add(comment);
                }
            }
            
            if (!commentsToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(commentsToInsert, false);
                UTIL_LoggingService.logDmlResults(results, null, commentsToInsert, '', 
                    UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS, LoggingLevel.ERROR);
        }
    }
    
    /**
     * @description Creates Genesys cancellation records for deleted cases
     * @param newMap Cases being deleted
     */
    public static void createGenesysCancellationRecords(Map<Id,Case> newMap) {
        try {
            List<Genesys_Routing__c> cancellationRecords = new List<Genesys_Routing__c>();
            
            for (Case c : newMap.values()) {
                Genesys_Routing__c cancellation = new Genesys_Routing__c();
                cancellation.Action_Reason__c = 'Case Deleted';
                cancellation.Action__c = 'Cancel';
                cancellation.LastAgentId__c = c.Last_Agent_Id__c;
                cancellation.MediaType__c = 'SFDCCase';
                cancellation.OwnerId = c.OwnerId;
                cancellation.SFDCAcctID__c = c.Client__c;
                cancellation.SFDCAcctLocationTimeZone__c = c.Location__r.tz__Timezone__c;
                cancellation.SFDCAcctLocation__c = c.Location__r.AccountNumber;
                cancellation.SFDCAcctSegment__c = c.Client__r.Primary_Segment__c;
                cancellation.SFDCCaseNumber__c = c.CaseNumber;
                cancellation.SFDCCaseReason__c = c.Case_Reason__c;
                cancellation.SFDCCaseRefNo__c = c.Reference_Number__c;
                cancellation.SFDCObjRecordID__c = c.Id;
                cancellationRecords.add(cancellation);
            }
            
            if (!cancellationRecords.isEmpty()) {
                Database.SaveResult[] results = Database.insert(cancellationRecords, false);
                UTIL_LoggingService.logDmlResults(results, null, cancellationRecords, '', 
                    UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS, LoggingLevel.ERROR);
        }
    }
    
    /**
     * @description Logs chargeability changes to case comments
     * @param newcaseList Cases with changed chargeability
     */
    public static void logChargeabilityChange(List<Case> newcaseList) {
        try {
            List<CaseComment> commentsToInsert = new List<CaseComment>();
            
            for (Case c : newcaseList) {
                String commentBody = '';
                
                if (c.Chargeable__c == 'Yes') {
                    commentBody = 'Case marked as chargeable.';
                } else if (c.Chargeable__c != 'Yes') {
                    commentBody = 'Case marked as non-chargeable.';
                }
                
                if (String.isNotBlank(commentBody)) {
                    CaseComment comment = new CaseComment();
                    comment.ParentId = c.Id;
                    comment.CommentBody = commentBody;
                    comment.IsPublished = false;
                    commentsToInsert.add(comment);
                }
            }
            
            if (!commentsToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(commentsToInsert, false);
                UTIL_LoggingService.logDmlResults(results, null, commentsToInsert, '', 
                    UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.CASE_TRIGGER_CLASS, LoggingLevel.ERROR);
        }
    }
    
    /**
     * @description Initiates work order creation process for one or more cases
     * @param caseId Primary case ID that triggered the work order request
     * @param caseIdList List of case IDs to create work orders for (may be multi-case)
     * @return SUCCESS or FAILURE status string
     */
    public static String initiateWorkOrderCreation(String caseId, List<String> caseIdList) {
        try {
            if (String.isBlank(caseId) || caseIdList == null || caseIdList.isEmpty()) {
                return Constant_Util.Failure;
            }
            
            // Validate all cases are ready for work order creation
            Set<Id> caseIdsToValidate = new Set<Id>();
            caseIdsToValidate.add(Id.valueOf(caseId));
            for (String cId : caseIdList) {
                caseIdsToValidate.add(Id.valueOf(cId));
            }
            
            // Validate each case
            Boolean allCasesValid = true;
            for (Id validationCaseId : caseIdsToValidate) {
                Map<String, Object> validationResult = validateCaseReadyForWorkOrder(validationCaseId);
                if (!(Boolean)validationResult.get('isValid')) {
                    UTIL_LoggingService.logHandledException(
                        new CustomException('Case validation failed: ' + validationResult.get('messages')),
                        UserInfo.getOrganizationId(),
                        UTIL_ErrorConstants.CASE_TRIGGER_CLASS,
                        LoggingLevel.ERROR
                    );
                    allCasesValid = false;
                }
            }
            
            if (!allCasesValid) {
                return Constant_Util.Failure;
            }
            
            // Get case records for work order creation
            List<Case> casesToProcess = [
                SELECT Id, Status, Case_Sub_Status__c, AssetId, ContactId, 
                       Case_Type__c, Case_Sub_Type__c, Service_Date__c,
                       Location__c, Client__c, Reference_Number__c, 
                       SLA_Service_Date_Time__c, Is_Multivendor__c,
                       Site_Contact__c, Site_Contact_Phone__c,
                       User_Input_Work_Order_Instructions__c
                FROM Case
                WHERE Id IN :caseIdsToValidate
            ];
            
            // Call work order creation logic (delegating to appropriate handler)
            // This would integrate with your existing WorkOrderCreation service/class
            Boolean workOrderCreated = WorkOrderCreation.createWorkOrders(casesToProcess);
            
            if (workOrderCreated) {
                // Update case statuses via CaseDMLService
                List<Case> casesToUpdate = new List<Case>();
                for (Case c : casesToProcess) {
                    c.Status = Constant_Util.OPEN;
                    c.Case_Sub_Status__c = Constant_Util.PENDING_SERVICE_INTEGRATION;
                    casesToUpdate.add(c);
                }
                
                CaseDMLService.DMLResult updateResult = CaseDMLService.getInstance().updateCases(casesToUpdate);
                
                if (updateResult.isAllSuccess()) {
                    return Constant_Util.SUCCESS;
                } else {
                    return Constant_Util.Failure;
                }
            }
            
            return Constant_Util.Failure;
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return Constant_Util.Failure;
        }
    }
    
    /**
     * @description Copies Acorn comments from parent case to child case
     * @param recordId Parent case ID
     * @param caseObj Child case object
     */
    public static void copyAcornComments(String recordId, Case caseObj) {
        try {
            if (String.isBlank(recordId) || caseObj == null) {
                return;
            }
            
            // Get Acorn comments from parent case
            List<CaseComment> parentComments = [
                SELECT CommentBody, IsPublished, CreatedDate, CreatedById
                FROM CaseComment
                WHERE ParentId = :recordId
                AND CommentBody LIKE '%Acorn%'
                ORDER BY CreatedDate DESC
            ];
            
            if (parentComments.isEmpty()) {
                return;
            }
            
            // Create new comments for child case
            List<CaseComment> childComments = new List<CaseComment>();
            for (CaseComment parentComment : parentComments) {
                CaseComment childComment = new CaseComment();
                childComment.ParentId = caseObj.Id;
                childComment.CommentBody = parentComment.CommentBody + 
                    '\n(Copied from parent case: ' + recordId + ')';
                childComment.IsPublished = parentComment.IsPublished;
                childComments.add(childComment);
            }
            
            if (!childComments.isEmpty()) {
                Database.SaveResult[] results = Database.insert(childComments, false);
                UTIL_LoggingService.logDmlResults(results, null, childComments, '',
                    UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', 
                    UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    // Custom exception class for better error handling
    private class CustomException extends Exception {}
}