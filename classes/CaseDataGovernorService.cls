/**
 * @description CaseDataGovernorService - Central data management service for Case pages
 *
 * This service acts as a "Governor" that consolidates all data needs for Case record pages.
 * It provides a single Apex call that returns comprehensive case context, reducing redundant
 * queries and improving governor limit management.
 *
 * Key Responsibilities:
 * - Fetch all Case-related data in a single transaction
 * - Consolidate data from multiple ContextGetter services
 * - Provide unified data wrapper for LWC components
 * - Manage caching and performance optimization
 * - Support pub/sub architecture at LWC layer
 *
 * Architecture:
 * - Leverages existing ContextGetter classes (Case, Contact, Account, Asset, etc.)
 * - Uses CaseUIService for UI-specific logic
 * - Returns CasePageDataWrapper with all page context
 * - Designed to be called once per page load by caseDataGovernor LWC
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer
 */
public with sharing class CaseDataGovernorService {

    // ========================================================================
    // WRAPPER CLASS FOR COMPLETE PAGE DATA
    // ========================================================================

    /**
     * @description Comprehensive wrapper containing all data needed for Case page components
     * This wrapper is designed to be published via Lightning Message Service to child components
     */
    public class CasePageDataWrapper {
        // Core Case Data
        @AuraEnabled public Case caseRecord {get;set;}
        @AuraEnabled public CaseUIService.CaseUIWrapper caseUI {get;set;}

        // Related Records
        @AuraEnabled public Account clientAccount {get;set;}
        @AuraEnabled public Account locationAccount {get;set;}
        @AuraEnabled public Account supplierAccount {get;set;}
        @AuraEnabled public Contact caseContact {get;set;}
        @AuraEnabled public Asset caseAsset {get;set;}
        @AuraEnabled public List<Case> relatedCases {get;set;}

        // Business Rules & Validation
        @AuraEnabled public CaseUIService.BusinessRuleUIWrapper businessRules {get;set;}
        @AuraEnabled public CaseUIService.SLAUIWrapper slaInfo {get;set;}

        // User Context
        @AuraEnabled public UserContextWrapper userContext {get;set;}

        // Metadata & Configuration
        @AuraEnabled public Map<String, Object> pageConfig {get;set;}

        // Status & Timestamps
        @AuraEnabled public DateTime loadedAt {get;set;}
        @AuraEnabled public String cacheKey {get;set;}
        @AuraEnabled public Boolean isSuccess {get;set;}
        @AuraEnabled public String errorMessage {get;set;}

        public CasePageDataWrapper() {
            this.relatedCases = new List<Case>();
            this.pageConfig = new Map<String, Object>();
            this.loadedAt = DateTime.now();
            this.isSuccess = true;
            this.errorMessage = '';
        }
    }

    /**
     * @description User context information for permission-based UI logic
     */
    public class UserContextWrapper {
        @AuraEnabled public Id userId {get;set;}
        @AuraEnabled public String userName {get;set;}
        @AuraEnabled public String userEmail {get;set;}
        @AuraEnabled public String profileName {get;set;}
        @AuraEnabled public Boolean isCPQUser {get;set;}
        @AuraEnabled public Boolean isUpdateAssetActiveUser {get;set;}
        @AuraEnabled public String userCategorizationCode {get;set;}
        @AuraEnabled public String timeZone {get;set;}

        public UserContextWrapper() {
            this.userId = UserInfo.getUserId();
            this.userName = UserInfo.getName();
            this.userEmail = UserInfo.getUserEmail();
            this.timeZone = UserInfo.getTimeZone().getId();
        }
    }

    // ========================================================================
    // PUBLIC API METHODS
    // ========================================================================

    /**
     * @description Get complete Case page data in a single call
     * This is the primary entry point for the caseDataGovernor LWC component
     *
     * @param caseId Case record ID
     * @param includeRelated Whether to include related records (contacts, accounts, etc.)
     * @param includeBusinessRules Whether to evaluate business rules
     * @return CasePageDataWrapper with all page data
     */
    @AuraEnabled(cacheable=false)
    public static CasePageDataWrapper getCasePageData(Id caseId, Boolean includeRelated, Boolean includeBusinessRules) {
        CasePageDataWrapper pageData = new CasePageDataWrapper();

        try {
            if (caseId == null) {
                pageData.isSuccess = false;
                pageData.errorMessage = 'Case ID is required';
                return pageData;
            }

            // Set cache key for client-side caching
            pageData.cacheKey = generateCacheKey(caseId);

            // Load core case data
            loadCaseData(pageData, caseId);

            // Load related records if requested
            if (includeRelated && pageData.caseRecord != null) {
                loadRelatedRecords(pageData);
            }

            // Load business rules if requested
            if (includeBusinessRules) {
                loadBusinessRules(pageData, caseId);
            }

            // Load user context
            loadUserContext(pageData);

            // Load page configuration
            loadPageConfiguration(pageData);

        } catch (Exception ex) {
            pageData.isSuccess = false;
            pageData.errorMessage = ex.getMessage();
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                                                   UTIL_ErrorConstants.ERROR_APPLICATION,
                                                   LoggingLevel.ERROR);
        }

        return pageData;
    }

    /**
     * @description Refresh specific section of page data
     * Used when components need to reload only part of the data (e.g., after an update)
     *
     * @param caseId Case record ID
     * @param section Section to refresh ('case', 'contact', 'asset', 'businessRules', etc.)
     * @return Map with refreshed data for the specified section
     */
    @AuraEnabled
    public static Map<String, Object> refreshPageSection(Id caseId, String section) {
        Map<String, Object> sectionData = new Map<String, Object>();

        try {
            switch on section.toLowerCase() {
                when 'case' {
                    Case caseRecord = CaseContextGetter.getCaseByIdExtended(caseId);
                    sectionData.put('caseRecord', caseRecord);
                }
                when 'contact' {
                    Case caseRecord = CaseContextGetter.getCaseById(caseId);
                    if (caseRecord.ContactId != null) {
                        Map<Id, Contact> contactMap = ContactContextGetter.getContactById(new Set<Id>{caseRecord.ContactId});
                        sectionData.put('caseContact', contactMap.get(caseRecord.ContactId));
                    }
                }
                when 'asset' {
                    Case caseRecord = CaseContextGetter.getCaseById(caseId);
                    if (caseRecord.AssetId != null) {
                        Map<Id, Asset> assetMap = AssetContextGetter.getHeaderById(new Set<Id>{caseRecord.AssetId});
                        sectionData.put('caseAsset', assetMap.get(caseRecord.AssetId));
                    }
                }
                when 'businessrules' {
                    CaseUIService.BusinessRuleUIWrapper brWrapper = CaseUIService.getBusinessRule(caseId);
                    sectionData.put('businessRules', brWrapper);
                }
                when 'ui' {
                    CaseUIService.CaseUIWrapper uiWrapper = CaseUIService.getCaseMessages(caseId);
                    sectionData.put('caseUI', uiWrapper);
                }
                when else {
                    sectionData.put('error', 'Unknown section: ' + section);
                }
            }

            sectionData.put('isSuccess', true);
            sectionData.put('refreshedAt', DateTime.now());

        } catch (Exception ex) {
            sectionData.put('isSuccess', false);
            sectionData.put('errorMessage', ex.getMessage());
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(),
                                                   UTIL_ErrorConstants.ERROR_APPLICATION,
                                                   LoggingLevel.ERROR);
        }

        return sectionData;
    }

    // ========================================================================
    // PRIVATE HELPER METHODS
    // ========================================================================

    /**
     * @description Generate cache key for client-side caching
     */
    private static String generateCacheKey(Id caseId) {
        return caseId + '_' + String.valueOf(DateTime.now().getTime());
    }

    /**
     * @description Load core case data and UI wrapper
     */
    private static void loadCaseData(CasePageDataWrapper pageData, Id caseId) {
        // Get extended case record with all fields
        pageData.caseRecord = CaseContextGetter.getCaseByIdExtended(caseId);

        // Get UI-specific wrapper with validations and messages
        pageData.caseUI = CaseUIService.getCaseMessages(caseId);
    }

    /**
     * @description Load all related records (accounts, contacts, assets)
     */
    private static void loadRelatedRecords(CasePageDataWrapper pageData) {
        Case caseRecord = pageData.caseRecord;

        // Load Client Account
        if (caseRecord.Client__c != null) {
            Map<Id, Account> clientMap = AccountContextGetter.getClientById(new Set<Id>{caseRecord.Client__c});
            pageData.clientAccount = clientMap.get(caseRecord.Client__c);
        }

        // Load Location Account
        if (caseRecord.Location__c != null) {
            Map<Id, Account> locationMap = AccountContextGetter.getLocationById(new Set<Id>{caseRecord.Location__c});
            pageData.locationAccount = locationMap.get(caseRecord.Location__c);
        }

        // Load Supplier Account
        if (caseRecord.Supplier__c != null) {
            Map<Id, Account> supplierMap = AccountContextGetter.getClientById(new Set<Id>{caseRecord.Supplier__c});
            pageData.supplierAccount = supplierMap.get(caseRecord.Supplier__c);
        }

        // Load Case Contact
        if (caseRecord.ContactId != null) {
            Map<Id, Contact> contactMap = ContactContextGetter.getContactById(new Set<Id>{caseRecord.ContactId});
            pageData.caseContact = contactMap.get(caseRecord.ContactId);
        }

        // Load Case Asset
        if (caseRecord.AssetId != null) {
            Map<Id, Asset> assetMap = AssetContextGetter.getHeaderById(new Set<Id>{caseRecord.AssetId});
            pageData.caseAsset = assetMap.get(caseRecord.AssetId);
        }

        // Load Related Cases
        if (String.isNotBlank(caseRecord.Reference_Number__c)) {
            pageData.relatedCases = CaseContextGetter.getCasesByReferenceNumber(
                caseRecord.Reference_Number__c
            );
        }
    }

    /**
     * @description Load business rules and SLA information
     */
    private static void loadBusinessRules(CasePageDataWrapper pageData, Id caseId) {
        pageData.businessRules = CaseUIService.getBusinessRule(caseId);
        pageData.slaInfo = CaseUIService.getEntitlement(caseId);
    }

    /**
     * @description Load current user context and permissions
     */
    private static void loadUserContext(CasePageDataWrapper pageData) {
        UserContextWrapper userContext = new UserContextWrapper();

        // Load user details
        User currentUser = [
            SELECT Id, Name, Email, Profile.Name, CPQ_Active_User__c,
                   Update_Asset_Active_User__c, User_categorization_code__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        userContext.profileName = currentUser.Profile.Name;
        userContext.isCPQUser = CaseUIService.hasCPQAccess();
        userContext.isUpdateAssetActiveUser = CaseUIService.hasUpdateAssetAccess();
        userContext.userCategorizationCode = currentUser.User_categorization_code__c;

        pageData.userContext = userContext;
    }

    /**
     * @description Load page-level configuration and metadata
     */
    private static void loadPageConfiguration(CasePageDataWrapper pageData) {
        // Add any page-level configuration
        pageData.pageConfig.put('caseRecordTypes', CaseUIService.getCaseRecordTypeList());

        // Add feature flags or custom metadata as needed
        pageData.pageConfig.put('version', '1.0');
        pageData.pageConfig.put('lastModified', pageData.loadedAt);
    }
}
