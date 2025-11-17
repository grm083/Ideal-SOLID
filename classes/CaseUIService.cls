/**
 * @description CaseUIService - Service layer for UI-specific Case data and operations
 * 
 * This service class is responsible only for preparing data for display and handling UI-specific actions.
 * It orchestrates calls to other services (CaseContextGetter for data, CaseBusinessRuleService for validation)
 * but doesn't contain any core business logic itself.
 * 
 * Key Responsibilities:
 * - Prepare Case data for UI consumption
 * - Coordinate between multiple service layers
 * - Format data for Lightning/Aura components
 * - Handle UI-specific validation messages
 * 
 * Design Principles:
 * - Thin controller layer - delegates to specialized services
 * - No direct SOQL queries - uses CaseContextGetter
 * - No business logic - uses CaseBusinessRuleService
 * - Returns UI-friendly wrapper classes
 * 
 * @author Waste Management
 * @date 2024
 * @group Service Layer
 */
public with sharing class CaseUIService {
    
    // ========================================================================
    // WRAPPER CLASSES FOR UI DATA
    // ========================================================================
    
    /**
     * @description Comprehensive wrapper for Case UI messages and state
     */
    public class CaseUIWrapper {
        @AuraEnabled public String caseId {get;set;}
        @AuraEnabled public String caseNumber {get;set;}
        @AuraEnabled public String referenceNo {get;set;}
        @AuraEnabled public String caseType {get;set;}
        @AuraEnabled public String caseSubType {get;set;}
        @AuraEnabled public String caseReason {get;set;}
        @AuraEnabled public String caseStatus {get;set;}
        @AuraEnabled public String caseRecordType {get;set;}
        
        // Information Messages
        @AuraEnabled public String caseInfo {get;set;}
        @AuraEnabled public String reqInfo {get;set;}
        @AuraEnabled public String approvalInfo {get;set;}
        @AuraEnabled public String channelReq {get;set;}
        @AuraEnabled public String specialInstructions {get;set;}
        @AuraEnabled public String slaInstructions {get;set;}
        @AuraEnabled public String channelName {get;set;}
        @AuraEnabled public String assetSCode {get;set;}
        @AuraEnabled public String caseAppliedRules {get;set;}
        
        // Boolean Flags
        @AuraEnabled public Boolean enableapprovalInfo {get;set;}
        @AuraEnabled public Boolean disableMultiCase {get;set;}
        @AuraEnabled public Boolean assetValidation {get;set;}
        @AuraEnabled public Boolean workOrderCreation {get;set;}
        @AuraEnabled public Boolean isAssetMandatory {get;set;}
        @AuraEnabled public Boolean isManualCaseAsset {get;set;}
        @AuraEnabled public Boolean isOpportunityCreated {get;set;}
        @AuraEnabled public Boolean isCPQUser {get;set;}
        @AuraEnabled public Boolean isUpdateAssetActiveUser {get;set;}
        @AuraEnabled public Boolean progressCaseVisibility {get;set;}
        @AuraEnabled public Boolean addQuoteVisibility {get;set;}
        @AuraEnabled public Boolean isAddCaseAsset {get;set;}
        @AuraEnabled public Boolean isCaseInfoReady {get;set;}
        @AuraEnabled public Boolean isHaulAwayService {get;set;}
        
        // Related Lists
        @AuraEnabled public List<Case> relatedCaseList {get;set;}
        @AuraEnabled public List<String> multiAssetSelections {get;set;}
        @AuraEnabled public List<String> caseRecordTypeList {get;set;}
        
        // Case Data
        @AuraEnabled public Case caseData {get;set;}
        @AuraEnabled public String assetId {get;set;}
        @AuraEnabled public Id cpqProduct {get;set;}
        
        public CaseUIWrapper() {
            this.caseInfo = Constant_Util.EMPTY_STRING;
            this.reqInfo = Constant_Util.EMPTY_STRING;
            this.approvalInfo = Constant_Util.EMPTY_STRING;
            this.enableapprovalInfo = false;
            this.assetValidation = false;
            this.workOrderCreation = true;
            this.isAssetMandatory = true;
            this.isCaseInfoReady = true;
            this.relatedCaseList = new List<Case>();
            this.multiAssetSelections = new List<String>();
        }
    }
    
    /**
     * @description Wrapper for business rule UI display
     */
    public class BusinessRuleUIWrapper {
        @AuraEnabled public String channelReq {get;set;}
        @AuraEnabled public String channelName {get;set;}
        @AuraEnabled public String specialInstructions {get;set;}
        
        public BusinessRuleUIWrapper() {
            this.channelReq = '';
            this.channelName = '';
            this.specialInstructions = '';
        }
    }
    
    /**
     * @description Wrapper for SLA instructions UI display
     */
    public class SLAUIWrapper {
        @AuraEnabled public String slaInstructions {get;set;}
        
        public SLAUIWrapper() {
            this.slaInstructions = '';
        }
    }
    
    /**
     * @description Wrapper for quote line items
     */
    public class QuoteLineWrapper {
        @AuraEnabled public String quoteNumber {get;set;}
        @AuraEnabled public String quoteId {get;set;}
        @AuraEnabled public String status {get;set;}
        @AuraEnabled public String quoteDuration {get;set;}
        @AuraEnabled public Date startDate {get;set;}
        @AuraEnabled public String productName {get;set;}
        @AuraEnabled public String productSize {get;set;}
        @AuraEnabled public String primaryContact {get;set;}
    }
    
    // ========================================================================
    // PUBLIC METHODS FOR UI COMPONENTS
    // ========================================================================
    
    /**
     * @description Get comprehensive case messages with all validations
     * This is the main entry point for Case UI data
     * @param caseId Case ID
     * @return CaseUIWrapper with complete case information
     */
    @AuraEnabled
    public static CaseUIWrapper getCaseMessages(Id caseId) {
        try {
            if (caseId == null) {
                return createEmptyWrapper();
            }
            
            // Load case data using CaseContextGetter
            Case caseObj = CaseContextGetter.getCaseByIdExtended(caseId);
            if (caseObj == null) {
                return createEmptyWrapper();
            }
            
            // Create wrapper and populate basic info
            CaseUIWrapper wrapper = new CaseUIWrapper();
            populateBasicCaseInfo(wrapper, caseObj);
            
            // Load user permissions
            loadUserPermissions(wrapper);
            
            // Get business rules and validations
            evaluateBusinessRules(wrapper, caseObj);
            
            // Get UI-specific data
            loadUISpecificData(wrapper, caseObj);
            
            // Determine button visibility
            determineButtonVisibility(wrapper, caseObj);
            
            return wrapper;
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                                                   UTIL_ErrorConstants.ERROR_APPLICATION,
                                                   LoggingLevel.ERROR);
            return createEmptyWrapper();
        }
    }
    
    /**
     * @description Get simple case message (deprecated - use getCaseMessages instead)
     * @param caseId Case ID
     * @return CaseUIWrapper with basic case information
     */
    @AuraEnabled
    public static CaseUIWrapper getMessage(Id caseId) {
        // Simplified version for backward compatibility
        // Delegates to getCaseMessages for full functionality
        return getCaseMessages(caseId);
    }
    
    /**
     * @description Get business rule channel requirements and special instructions
     * @param caseId Case ID
     * @return BusinessRuleUIWrapper with channel and instruction data
     */
    @AuraEnabled
    public static BusinessRuleUIWrapper getBusinessRule(Id caseId) {
        BusinessRuleUIWrapper wrapper = new BusinessRuleUIWrapper();
        
        try {
            Case caseObj = CaseContextGetter.getCaseByIdExtended(caseId);
            if (caseObj == null || 
                String.isBlank(caseObj.Client__c) || 
                String.isBlank(caseObj.Case_Sub_type__c)) {
                return wrapper;
            }
            
            // Get business notification rules
            CaseBusinessRuleService.BusinessRuleResult brResult = 
                CaseBusinessRuleService.evaluateBusinessRules(caseId);
            
            /*if (brResult != null && brResult.notificationRules != null) {
                for (Business_Rule__c rule : brResult.notificationRules.values()) {
                    if (String.isNotBlank(rule.Channel_Req__c) && 
                        String.isNotBlank(rule.Channel__c)) {
                        wrapper.channelReq = rule.Channel_Req__c;
                        wrapper.channelName = rule.Channel__c;
                    }
                    
                    if (String.isNotBlank(rule.Special_Ins__c)) {
                        wrapper.specialInstructions = rule.Special_Ins__c;
                    }
                }
            }*/
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                                                   UTIL_ErrorConstants.ERROR_APPLICATION,
                                                   LoggingLevel.ERROR);
        }
        
        return wrapper;
    }
    
    /**
     * @description Get SLA instructions from entitlement
     * @param caseId Case ID
     * @return SLAUIWrapper with SLA instructions
     */
    @AuraEnabled
    public static SLAUIWrapper getEntitlement(Id caseId) {
        SLAUIWrapper wrapper = new SLAUIWrapper();
        
        try {
            Case caseObj = CaseContextGetter.getCaseByIdExtended(caseId);
            if (caseObj == null || String.isBlank(caseObj.Case_Sub_type__c)) {
                return wrapper;
            }
            
            // Get SLA entitlement information
            // This would integrate with your SLA calculation logic
            Map<String, Entitlement> entitlementMap = 
                CaseTriggerHelper.fetchSLA(new Map<String, Case>{caseObj.Id => caseObj});
            
            if (entitlementMap != null && !entitlementMap.isEmpty()) {
                for (Entitlement ent : entitlementMap.values()) {
                    if (String.isNotBlank(ent.SLA_Ins__c)) {
                        wrapper.slaInstructions = ent.SLA_Ins__c;
                        break;
                    }
                }
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                                                   UTIL_ErrorConstants.ERROR_APPLICATION,
                                                   LoggingLevel.ERROR);
        }
        
        return wrapper;
    }
    
    /**
     * @description Get case summary for related cases
     * @param caseId Case ID
     * @param referenceNo Reference number
     * @param parentId Parent case ID
     * @return List of related cases
     */
    @AuraEnabled
    public static List<Case> getCaseSummary(String caseId, String referenceNo, String parentId) {
        List<Case> caseList = new List<Case>();
        Set<Id> multidateCaseIds = new Set<Id>();
        
        try {
            if (String.isBlank(referenceNo)) {
                // Get case and its children
                caseList = [
                    SELECT Id, Create_AM_and_PM_Pickups__c, Asset_Material__c, CaseNumber,
                           Case_Sub_Type__c, Case_Type__c, Reference_Number__c,
                           Contact.Name, Contact_Title__c, SLA_Date_Text__c, Service_Date_Text__c,
                           Asset.Name, SLA_Service_Date_Time__c, SLA_Service_DateTime__c,
                           Service_Date__c, Asset.Acorn_SID__c
                    FROM Case
                    WHERE (Id = :caseId OR (ParentId = :caseId AND Is_Clone__c = true))
                    AND ((Status = :Constant_Util.STATUS_NEW) OR 
                         (Status = :Constant_Util.OPEN AND Case_Type__c != :Constant_Util.PICKUP))
                    ORDER BY Service_Date__c ASC
                    LIMIT 49999
                ];
            } else {
                // Get cases by reference number
                List<Case> allRelatedCases = [
                    SELECT Id, isMultiCalendarChecked__c, Create_AM_and_PM_Pickups__c,
                           Asset_Material__c, CaseNumber, Case_Sub_Type__c, Case_Type__c,
                           Reference_Number__c, Contact.Name, Contact_Title__c,
                           SLA_Date_Text__c, Service_Date_Text__c, Asset.Name,
                           SLA_Service_Date_Time__c, SLA_Service_DateTime__c, Service_Date__c,
                           Is_Clone__c, ParentId, Asset.Acorn_SID__c
                    FROM Case
                    WHERE Reference_Number__c = :referenceNo
                    AND Status = :Constant_Util.STATUS_NEW
                    AND Is_Multiple_Asset__c = true
                    ORDER BY Service_Date__c ASC
                    LIMIT 49999
                ];
                
                for (Case c : allRelatedCases) {
                    if ((!String.isBlank(String.valueOf(c.ParentId)) && 
                         String.valueOf(c.ParentId).equals(parentId)) || 
                        (String.isBlank(String.valueOf(c.ParentId)) && 
                         String.isBlank(parentId))) {
                        caseList.add(c);
                        if (c.isMultiCalendarChecked__c) {
                            multidateCaseIds.add(c.Id);
                        }
                    }
                }
                
                // Get clone cases for multi-calendar cases
                if (!multidateCaseIds.isEmpty()) {
                    List<Case> cloneCases = [
                        SELECT Id, Create_AM_and_PM_Pickups__c, Asset_Material__c, CaseNumber,
                               Case_Sub_Type__c, Case_Type__c, Reference_Number__c,
                               Contact.Name, Contact_Title__c, SLA_Date_Text__c,
                               Service_Date_Text__c, Asset.Name, SLA_Service_Date_Time__c,
                               SLA_Service_DateTime__c, Service_Date__c, Asset.Acorn_SID__c
                        FROM Case
                        WHERE ParentId IN :multidateCaseIds
                        AND Is_Clone__c = true
                        AND Status = :Constant_Util.STATUS_NEW
                        ORDER BY Service_Date__c ASC
                        LIMIT 49999
                    ];
                    caseList.addAll(cloneCases);
                }
            }
            
            // Format service dates
            for (Case c : caseList) {
                if (c.Service_Date__c != null) {
                    c.Service_Date_Text__c = c.Service_Date__c.format();
                }
            }
            
            // Handle AM/PM duplicate if needed
            if (!caseList.isEmpty() && caseList[0].Create_AM_and_PM_Pickups__c) {
                caseList.add(caseList[0]);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                                                   UTIL_ErrorConstants.ERROR_APPLICATION,
                                                   LoggingLevel.ERROR);
            return new List<Case>();
        }
        
        return caseList;
    }
    
    /**
     * @description Get case record details for UI
     * @param caseId Case ID
     * @return List of case details as strings
     */
    @AuraEnabled
    public static List<String> getCaseRecordDetails(Id caseId) {
        List<String> caseDetails = new List<String>();
        
        try {
            Case c = CaseContextGetter.getCaseByIdExtended(caseId);
            if (c == null) {
                return caseDetails;
            }
            
            caseDetails.add(String.valueOf(c.RecordTypeId));
            caseDetails.add(c.Company_Category__c);
            caseDetails.add(c.CompanyCategoryCode__c);
            
            // Add Haul Away flag
            if (c.Is_Haul_Away_Service__c) {
                caseDetails.add('true');
            } else {
                caseDetails.add('false');
            }
            
            // Check if vendor service ID required
            if (c.Haul_Away_Vendor__c == HaulAwayService.Haul_Away_Vendor_Got_Junk_API && 
                c.Is_Haul_Away_Service__c) {
                caseDetails.add('VendorServiceIdReq');
            }
            
            // Check if haul away service is booked
            if (c.Haul_Away_Vendor__c != 'Not Available' && c.Is_Haul_Away_Service__c) {
                caseDetails.add('HaulAwayBookedService');
            }
            
            // Check if Haul Away UI is enabled
            Code_Switch__c codeSwitchSetting = Code_Switch__c.getValues('HaulAwayUIEnable');
            if (codeSwitchSetting != null && codeSwitchSetting.Switch_Off__c) {
                caseDetails.add('HaulAwayUIEnabled');
            }
            
            // Check for billing invoice charge dispute
            BillingService billing = new BillingService();
            if (c.Case_Type__c == billing.CASE_TYPE_BILLING && 
                c.Case_Sub_Type__c == billing.CASE_SUB_TYPE_Invoice_Charge_Dispute) {
                caseDetails.add('BillingInvoiceChargeDispute');
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                                                   UTIL_ErrorConstants.ERROR_APPLICATION,
                                                   LoggingLevel.ERROR);
        }
        
        return caseDetails;
    }
    
    /**
     * @description Get case record type ID
     * @param caseId Case ID
     * @return Record Type ID
     */
    @AuraEnabled
    public static String getRecordTypeId(Id caseId) {
        try {
            Case c = CaseContextGetter.getCaseById(caseId);
            return c != null ? String.valueOf(c.RecordTypeId) : null;
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                                                   UTIL_ErrorConstants.ERROR_APPLICATION,
                                                   LoggingLevel.ERROR);
            return null;
        }
    }
    
    /**
     * @description Get list of case record types
     * REFACTORED: Now uses CaseContextGetter for data access (Phase 3)
     * @return List of case record type names
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getCaseRecordTypeList() {
        List<String> recordTypeNames = new List<String>();

        try {
            Set<String> excludedTypes = new Set<String>{
                Constant_Util.UPDATE_ASSET_CASE,
                Constant_Util.New_Service_Case
            };

            List<RecordType> recordTypes = CaseContextGetter.getCaseRecordTypes(excludedTypes);

            for (RecordType rt : recordTypes) {
                recordTypeNames.add(rt.Name);
            }

        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                                                   UTIL_ErrorConstants.ERROR_APPLICATION,
                                                   LoggingLevel.ERROR);
        }

        return recordTypeNames;
    }
    
    /**
     * @description Get case asset details
     * @param caseId Case ID
     * @return List of cases with asset details
     */
    @AuraEnabled(cacheable=true)
    public static List<Case> getCaseAssetDetails(String caseId) {
        List<Case> caseAssets = new List<Case>();
        
        try {
            caseAssets = [
                SELECT Id, Asset.ProductFamily, Asset.Equipment_Type__c,
                       Asset.Duration__c, Asset.Occurrence_Type__c, AssetId
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                                                   UTIL_ErrorConstants.ERROR_APPLICATION,
                                                   LoggingLevel.ERROR);
        }
        
        return caseAssets;
    }
    
    // ========================================================================
    // PRIVATE HELPER METHODS
    // ========================================================================
    
    /**
     * @description Create an empty wrapper with default values
     */
    private static CaseUIWrapper createEmptyWrapper() {
        return new CaseUIWrapper();
    }
    
    /**
     * @description Populate basic case information in wrapper
     */
    private static void populateBasicCaseInfo(CaseUIWrapper wrapper, Case caseObj) {
        wrapper.caseId = caseObj.Id;
        wrapper.caseNumber = caseObj.CaseNumber;
        wrapper.referenceNo = caseObj.Reference_Number__c;
        wrapper.caseType = caseObj.Case_Type__c;
        wrapper.caseSubType = caseObj.Case_Sub_Type__c;
        wrapper.caseReason = caseObj.Case_Reason__c;
        wrapper.caseStatus = caseObj.Status;
        wrapper.caseRecordType = caseObj.RecordType.Name;
        wrapper.disableMultiCase = caseObj.isMultiCalendarChecked__c;
        wrapper.isOpportunityCreated = caseObj.IsOpportunity_Created__c;
        wrapper.caseData = caseObj;
        wrapper.assetId = caseObj.AssetId;
        
        if (caseObj.AssetId != null && caseObj.Asset != null) {
            wrapper.assetSCode = caseObj.Asset.Sensitivity_Code__c;
            wrapper.cpqProduct = caseObj.Asset.CPQ_Product__c;
        }
    }
    
    /**
     * @description Load user permissions for UI
     */
    private static void loadUserPermissions(CaseUIWrapper wrapper) {
        wrapper.isCPQUser = getUserDetail();
        wrapper.isUpdateAssetActiveUser = getActiveAssetUserDetail();
    }
    
    /**
     * @description Evaluate business rules and populate wrapper
     */
    private static void evaluateBusinessRules(CaseUIWrapper wrapper, Case caseObj) {
        // Use CaseBusinessRuleService to evaluate all business rules
        CaseBusinessRuleService.BusinessRuleResult brResult = 
            CaseBusinessRuleService.evaluateBusinessRules(caseObj.Id);
        
        if (brResult != null) {
            // Populate approval information
            wrapper.enableapprovalInfo = brResult.requiresApproval;
            if (wrapper.enableapprovalInfo) {
                wrapper.approvalInfo = 'Approval is required for this request, please review the active approval rules for further instruction.';
            }
            
            /* Populate required information
            if (String.isNotBlank(String.join(brResult.validationMessages,', '))) {
                wrapper.reqInfo = String.join(brResult.validationMessages, ',');
            }*/
            
            // Populate validation messages
            if (!brResult.validationMessages.isEmpty()) {
                wrapper.caseInfo = String.join(brResult.validationMessages, '\n');
            }
        }
    }
    
    /**
     * @description Load UI-specific data
     */
    private static void loadUISpecificData(CaseUIWrapper wrapper, Case caseObj) {
        // Load related cases
        List<Case> relatedCases = CaseContextGetter.getCasesByReferenceNumber(
            caseObj.Reference_Number__c);
        wrapper.relatedCaseList = relatedCases;
        
        // Load multi-asset selections from cache if available
        Cache.SessionPartition sessionPart = 
            Cache.Session.getPartition(Constant_UTIL.MULTI_ASSET_PARTITION);
        if (sessionPart.contains(caseObj.Id)) {
            String[] assets = (String[])sessionPart.get(caseObj.Id);
            wrapper.multiAssetSelections = assets;
        }
        
        // Load case record types
        wrapper.caseRecordTypeList = getCaseRecordTypeList();
        
        // Check for manual case assets
        List<SBS_Case_Asset__c> caseAssets = [
            SELECT Id, IsManual__c
            FROM SBS_Case_Asset__c
            WHERE CaseId__c = :caseObj.Id
            AND IsManual__c = true
            LIMIT 1
        ];
        wrapper.isManualCaseAsset = !caseAssets.isEmpty();
        
        // Check work order creation requirement
        determineWorkOrderRequirement(wrapper, caseObj);
    }
    
    /**
     * @description Determine work order creation requirement
     */
    private static void determineWorkOrderRequirement(CaseUIWrapper wrapper, Case caseObj) {
        String key = caseObj.Case_Type__c + caseObj.Case_Sub_Type__c;
        List<WOCreation__mdt> woMetadata = [
            SELECT WO_Needed__c, Is_Asset_Mandatory__c, Case_Reason__c
            FROM WOCreation__mdt
            WHERE Case_Type__c = :caseObj.Case_Type__c
            AND Case_Subtype__c = :caseObj.Case_Sub_Type__c
        ];
        
        for (WOCreation__mdt wo : woMetadata) {
            if (String.isNotBlank(caseObj.Case_Reason__c) && 
                wo.Case_Reason__c != null && 
                wo.Case_Reason__c.equals(caseObj.Case_Reason__c)) {
                wrapper.workOrderCreation = wo.WO_Needed__c;
                wrapper.isAssetMandatory = wo.Is_Asset_Mandatory__c;
                break;
            } else if (String.isBlank(caseObj.Case_Reason__c)) {
                wrapper.workOrderCreation = wo.WO_Needed__c;
                wrapper.isAssetMandatory = wo.Is_Asset_Mandatory__c;
            }
        }
    }
    
    /**
     * @description Determine button visibility based on case state and user permissions
     */
    private static void determineButtonVisibility(CaseUIWrapper wrapper, Case caseObj) {
        // Progress Case button visibility
        wrapper.progressCaseVisibility = shouldShowProgressCaseButton(wrapper, caseObj);

        // Add Quote button visibility
        wrapper.addQuoteVisibility = shouldShowAddQuoteButton(wrapper, caseObj);

        // Add Case Assets button visibility
        wrapper.isAddCaseAsset = shouldShowAddCaseAssetButton(wrapper, caseObj);
    }
    
    /**
     * @description Determine if Progress Case button should be visible
     * REFACTORED: Now delegates to CaseBusinessRuleService (Phase 2)
     * Business logic moved to proper service layer
     */
    private static Boolean shouldShowProgressCaseButton(CaseUIWrapper wrapper, Case caseObj) {
        // Delegate to CaseBusinessRuleService for business logic evaluation
        return CaseBusinessRuleService.shouldShowProgressCaseButton(
            caseObj,
            wrapper.isCPQUser,
            wrapper.isUpdateAssetActiveUser,
            wrapper.caseInfo,
            wrapper.workOrderCreation,
            wrapper.isAssetMandatory,
            wrapper.isCaseInfoReady
        );
    }
    
    /**
     * @description Determine if Add Quote button should be visible
     * REFACTORED: Now delegates to CaseBusinessRuleService (Phase 2)
     * Business logic moved to proper service layer
     */
    private static Boolean shouldShowAddQuoteButton(CaseUIWrapper wrapper, Case caseObj) {
        // Delegate to CaseBusinessRuleService for business logic evaluation
        return CaseBusinessRuleService.shouldShowAddQuoteButton(
            caseObj,
            wrapper.isCPQUser,
            wrapper.isUpdateAssetActiveUser,
            wrapper.caseInfo,
            wrapper.isOpportunityCreated
        );
    }
    
    /**
     * @description Logic check for Progress Case button visibility
     * DEPRECATED: This method has been moved to CaseBusinessRuleService (Phase 2)
     * Kept as a stub for backward compatibility only
     * @deprecated Use CaseBusinessRuleService.shouldShowProgressCaseButton instead
     */
    @Deprecated
    private static Boolean progressCaseVisibilityLogicCheck(CaseUIWrapper wrapper) {
        // This method is deprecated and should not be called
        // All logic has been moved to CaseBusinessRuleService
        return false;
    }
    
    /**
     * @description Determine if Add Case Assets button should be visible
     */
    private static Boolean shouldShowAddCaseAssetButton(CaseUIWrapper wrapper, Case caseObj) {
        // Don't show if case is closed
        if (caseObj.Status == 'Closed') {
            return false;
        }

        // Show button based on case info messages that indicate missing or invalid case assets
        if (String.isNotBlank(wrapper.caseInfo)) {
            // Show if there's a "No Case Asset" or similar error message
            if (wrapper.caseInfo.contains(Constant_Util.NO_CASE_ASSETS) ||
                wrapper.caseInfo.contains(Constant_Util.NO_CASE_ASSET_MSG) ||
                wrapper.caseInfo.contains(Constant_Util.CASE_ASSETS_END_DATE_PASSED) ||
                wrapper.caseInfo.contains(Constant_Util.ASSET_NOT_ACTIVE) ||
                wrapper.caseInfo == Constant_Util.SELECT_ASSET) {
                return true;
            }
        }

        // Show if asset validation is flagged and case is in New status
        if (wrapper.assetValidation &&
            caseObj.Status == Constant_Util.STATUS_New &&
            String.isNotBlank(caseObj.AssetId)) {
            return true;
        }

        // Show for manual case assets that need attention
        if (wrapper.isManualCaseAsset &&
            String.isNotBlank(caseObj.AssetId) &&
            String.isNotBlank(caseObj.ContactId) &&
            caseObj.Status == Constant_Util.STATUS_New) {
            // Don't show if already ready for work order
            if (wrapper.caseInfo != Constant_Util.READY &&
                wrapper.caseInfo != Constant_Util.READY_MULTIASSET) {
                return true;
            }
        }

        return false;
    }

    /**
     * @description Logic check for Add Quote button visibility
     * DEPRECATED: This method has been moved to CaseBusinessRuleService (Phase 2)
     * Kept as a stub for backward compatibility only
     * @deprecated Use CaseBusinessRuleService.shouldShowAddQuoteButton instead
     */
    @Deprecated
    private static Boolean addQuoteVisibilityLogicCheck(CaseUIWrapper wrapper) {
        // This method is deprecated and should not be called
        // All logic has been moved to CaseBusinessRuleService
        return false;
    }
    
    /**
     * @description Check if user has CPQ license and permissions
     * REFACTORED: Now uses CaseContextGetter for data access (Phase 3)
     */
    private static Boolean getUserDetail() {
        User u = CaseContextGetter.getCurrentUserWithPermissions();
        Boolean hasCPQLicense = CaseContextGetter.hasCPQLicense();

        return hasCPQLicense && u.CPQ_Active_User__c;
    }

    /**
     * @description Check if user has active asset update permissions
     * REFACTORED: Now uses CaseContextGetter for data access (Phase 3)
     */
    private static Boolean getActiveAssetUserDetail() {
        User u = CaseContextGetter.getCurrentUserWithPermissions();

        return u.Update_Asset_Active_User__c;
    }
    
    // ========================================================================
    // PUBLIC USER PERMISSION METHODS
    // ========================================================================
    
    /**
     * @description Check if current user has CPQ access (license and permissions)
     * Public method for use in refactored classes
     * @return True if user has CPQ license and CPQ_Active_User__c = true
     */
    public static Boolean hasCPQAccess() {
        return getUserDetail();
    }
    
    /**
     * @description Check if current user has update asset permissions
     * Public method for use in refactored classes
     * @return True if user has Update_Asset_Active_User__c = true 
     */
    public static Boolean hasUpdateAssetAccess() {
        return getActiveAssetUserDetail();
    }
    
    /**
     * @description Check user categorization code for button visibility
     * DEPRECATED: This method has been moved to CaseBusinessRuleService (Phase 2)
     * Kept as a stub for backward compatibility only
     * @deprecated Use CaseBusinessRuleService.shouldShowAddQuoteButton instead
     */
    @Deprecated
    private static Boolean getUserUCCDetail(CaseUIWrapper wrapper) {
        // This method is deprecated and should not be called
        // All logic has been moved to CaseBusinessRuleService
        return false;
    }
}