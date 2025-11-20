/**
* @description CaseAssetValidator - Single Responsibility Service for Asset Validation
*              This class provides a single, authoritative source for asset validation.
*              It ensures consistent validation rules across the system and makes updates
*              to validation logic simple by centralizing all asset-related business rules.
* 
* @group Services
* @date 2025
* 
* SOLID Principles Applied:
* - Single Responsibility: Only handles asset validation logic
* - Open/Closed: Can be extended with new validation types without modifying existing code
* - Liskov Substitution: All validation methods return consistent ValidationResult objects
* - Interface Segregation: Provides focused public methods for specific validation needs
* - Dependency Inversion: Depends on abstractions (ValidationResult) not concrete implementations
*/
public without sharing class CaseAssetValidator {
    
    // Constants for validation messages
    private static final String CASE_ASSETS_END_DATE_PASSED = 'Case asset(s) have end dates that have passed';
    private static final String ASSET_NOT_ACTIVE = 'The selected asset is not active for the requested service date';
    private static final String HAS_XPU_COMPONENT_NOT_EXISTS = 'Required Extra Pickup component not found';
    private static final String HAS_XPU_COMPONENT_CORRUPTED = 'Extra Pickup component configuration is corrupted';
    private static final String HAS_XPU_COMPONENT_NOT_ACTIVE_SERVICEDATE = 'Extra Pickup component is not active for the service date';
    private static final String NO_CASE_ASSETS = 'No valid case assets found';
    private static final String ASSET_COMPONENT_CORRUPTED = 'Asset component configuration is corrupted';
    private static final String ROLLOFF_ASSET_ERROR = 'Rolloff asset does not have required active components';
    private static final String CASE_ASSET_NOT_ONCALL_SCHEDULED_ON_CALL = 'Asset is not configured for On-Call or Scheduled On-Call';
    
    /**
* @description Wrapper class to encapsulate validation results
*/
    public class ValidationResult {
        @AuraEnabled public Boolean isValid { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        @AuraEnabled public String validationType { get; set; }
        
        public ValidationResult(Boolean isValid, String errorMessage, String validationType) {
            this.isValid = isValid;
            this.errorMessage = errorMessage;
            this.validationType = validationType;
        }
    }
    
    /**
* @description Validates asset for pickup case type
* @param assetId The ID of the asset to validate
* @param serviceDate The requested service date
* @return ValidationResult indicating if validation passed
*/
    public static ValidationResult validatePickupAsset(Id assetId, Date serviceDate) {
        if (assetId == null || serviceDate == null) {
            return new ValidationResult(false, 'Asset ID and Service Date are required', 'PICKUP');
        }
        
        try {
            Asset header = queryAssetWithChildren(assetId);
            if (header == null) {
                return new ValidationResult(false, 'Asset not found', 'PICKUP');
            }
            
            DateTime serviceDatetime = DateTime.newInstance(serviceDate.year(), serviceDate.month(), serviceDate.day());
            
            // Check if parent asset is active
            if (!isAssetActiveForDate(header, serviceDatetime)) {
                // Check for extended assets (SDT-33377)
                if (!hasExtendedAssetActive(header, serviceDatetime)) {
                    return new ValidationResult(false, ASSET_NOT_ACTIVE, 'PICKUP');
                }
            }
            
            // Validate based on product family
            if (Constant_Util.COMMERCIAL.equals(header.ProductFamily)) {
                return validateCommercialAsset(header, serviceDatetime);
            } else if (Constant_Util.ROLLOFF.equals(header.ProductFamily)) {
                return validateRolloffAsset(header, serviceDatetime);
            }
            
            return new ValidationResult(true, null, 'PICKUP');
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return new ValidationResult(false, 'Validation error: ' + ex.getMessage(), 'PICKUP');
        }
    }
    
    /**
* @description Validates asset for non-pickup case types
* @param assetId The ID of the asset to validate
* @param serviceDate The requested service date
* @return ValidationResult indicating if validation passed
*/
    public static ValidationResult validateNonPickupAsset(Id assetId, Date serviceDate) {
        if (assetId == null || serviceDate == null) {
            return new ValidationResult(false, 'Asset ID and Service Date are required', 'NON_PICKUP');
        }
        
        try {
            Asset header = queryAssetWithChildren(assetId);
            if (header == null) {
                return new ValidationResult(false, 'Asset not found', 'NON_PICKUP');
            }
            
            DateTime serviceDatetime = DateTime.newInstance(serviceDate.year(), serviceDate.month(), serviceDate.day());
            
            // Check if parent asset is active
            if (!isAssetActiveForDate(header, serviceDatetime)) {
                // Check for extended assets
                if (!hasExtendedAssetActive(header, serviceDatetime)) {
                    return new ValidationResult(false, ASSET_NOT_ACTIVE, 'NON_PICKUP');
                }
            }
            
            // Count active child assets
            Integer activeChildAssetCount = 0;
            for (Asset childAsset : header.ChildAssets) {
                if (isAssetActiveForDate(childAsset, serviceDatetime)) {
                    activeChildAssetCount++;
                }
            }
            
            if (activeChildAssetCount == 0) {
                return new ValidationResult(false, CASE_ASSETS_END_DATE_PASSED, 'NON_PICKUP');
            }
            
            return new ValidationResult(true, null, 'NON_PICKUP');
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return new ValidationResult(false, 'Validation error: ' + ex.getMessage(), 'NON_PICKUP');
        }
    }
    
    /**
* @description Validates case assets for a specific case
* @param caseId The ID of the case
* @return ValidationResult indicating if validation passed
*/
    public static ValidationResult validateCaseAssets(Id caseId) {
        if (caseId == null) {
            return new ValidationResult(false, 'Case ID is required', 'CASE_ASSETS');
        }
        
        try {
            Case caseRecord = [SELECT Id, Service_Date__c FROM Case WHERE Id = :caseId LIMIT 1];
            List<SBS_Case_Asset__c> caseAssets = [
                SELECT Id, CaseId__r.Service_Date__c, AssetId__r.End_Date__c, 
                AssetId__r.Start_Date__c, AssetId__r.Occurrence_Type__c
                FROM SBS_Case_Asset__c 
                WHERE CaseId__c = :caseId
            ];
            
            if (caseAssets.isEmpty()) {
                return new ValidationResult(false, NO_CASE_ASSETS, 'CASE_ASSETS');
            }
            
            // Validate each case asset
            for (SBS_Case_Asset__c caseAsset : caseAssets) {
                if (caseAsset.AssetId__r.End_Date__c != null) {
                    if (!(caseAsset.AssetId__r.Start_Date__c <= caseRecord.Service_Date__c && 
                          caseAsset.AssetId__r.End_Date__c >= caseRecord.Service_Date__c)) {
                              return new ValidationResult(false, System.Label.CASE_ASSET_VAL_ERR_MSG, 'CASE_ASSETS');
                          }
                } else {
                    if (!(caseAsset.AssetId__r.Start_Date__c <= caseRecord.Service_Date__c)) {
                        return new ValidationResult(false, System.Label.CASE_ASSET_VAL_ERR_MSG, 'CASE_ASSETS');
                    }
                }
            }
            
            return new ValidationResult(true, null, 'CASE_ASSETS');
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return new ValidationResult(false, 'Validation error: ' + ex.getMessage(), 'CASE_ASSETS');
        }
    }
    
    // ==================== CASE ASSET RELATIONSHIP MANAGEMENT ====================
    
    /**
* @description Removes obsolete case asset links when asset or service date changes
* @param oldCaseAssetIdMap Map of case ID to old asset header ID
*/
    public static void removeObsoleteAssetLinks(Map<String, String> oldCaseAssetIdMap) {
        try {
            List<SBS_Case_Asset__c> caseAssetOldParentList = [
                SELECT Id, CaseId__c, AssetId__c, Asset_Header__c 
                FROM SBS_Case_Asset__c
                WHERE CaseId__c IN :oldCaseAssetIdMap.keySet() 
                AND (Asset_Header__c IN :oldCaseAssetIdMap.values() OR Asset_Header__c = NULL) 
                LIMIT 10000
            ];
            
            if (!caseAssetOldParentList.isEmpty()) {
                List<Database.DeleteResult> srList = Database.delete(caseAssetOldParentList, false);
                UTIL_LoggingService.logDmlResults(null, srList, caseAssetOldParentList, '', 
                                                  UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);
            }
        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
* @description Creates case asset relationships based on asset hierarchy and service type
* @param caseNewMap New cases with asset relationships
* @param oldCaseMap Previous case states
* @param assetMap Map of asset IDs to asset records with children
*/
    public static void createCaseAssetRelationships(Map<Id, Case> caseNewMap, Map<Id, Case> oldCaseMap, Map<Id, Asset> assetMap) {
        try {
            // DEBUG: Log entry into Case Asset creation
            System.debug('CaseAssetValidator.createCaseAssetRelationships - ENTRY');
            System.debug('  caseNewMap size: ' + (caseNewMap != null ? caseNewMap.size() : 0));
            System.debug('  assetMap size: ' + (assetMap != null ? assetMap.size() : 0));
            if (assetMap != null && !assetMap.isEmpty()) {
                for (Asset a : assetMap.values()) {
                    System.debug('  Asset: ' + a.Id + ', ProductFamily: ' + a.ProductFamily +
                        ', Product2.Family: ' + (a.Product2 != null ? a.Product2.Family : 'NULL') +
                        ', ChildAssets: ' + (a.ChildAssets != null ? a.ChildAssets.size() : 0));
                }
            }

            // Build asset hierarchy map
            Map<String, Map<String, List<Asset>>> assetByServiceHeaderMap = buildAssetHierarchyMap(assetMap);

            // DEBUG: Log hierarchy map results
            System.debug('  assetByServiceHeaderMap size: ' + assetByServiceHeaderMap.size());
            if (!assetByServiceHeaderMap.isEmpty()) {
                for (String headerKey : assetByServiceHeaderMap.keySet()) {
                    System.debug('  Service Header: ' + headerKey +
                        ', Service Types: ' + assetByServiceHeaderMap.get(headerKey).keySet());
                }
            }
            
            // Check for cases that need asset link updates
            Map<String, String> oldCaseAssetIdMap = new Map<String, String>();
            for (Case caseRecord : caseNewMap.values()) {
                if (oldCaseMap != null && oldCaseMap.containsKey(caseRecord.Id)) {
                    Case oldCase = oldCaseMap.get(caseRecord.Id);
                    if (caseRecord.AssetId != oldCase.AssetId || caseRecord.Service_Date__c != oldCase.Service_Date__c) {
                        oldCaseAssetIdMap.put(caseRecord.Id, oldCase.AssetId);
                    }
                }
            }
            
            // Remove old case assets if needed
            if (!oldCaseAssetIdMap.isEmpty()) {
                removeObsoleteAssetLinks(oldCaseAssetIdMap);
            }
            
            // Create new case assets
            List<SBS_Case_Asset__c> caseAssetList = buildCaseAssetList(caseNewMap, assetMap, assetByServiceHeaderMap);

            // DEBUG: Log Case Assets to be created
            System.debug('  caseAssetList size: ' + caseAssetList.size());
            if (!caseAssetList.isEmpty()) {
                for (SBS_Case_Asset__c ca : caseAssetList) {
                    System.debug('    Case Asset - CaseId: ' + ca.CaseId__c +
                        ', AssetId: ' + ca.AssetId__c + ', Asset_Header: ' + ca.Asset_Header__c);
                }
            }

            if (!caseAssetList.isEmpty()) {
                List<Database.SaveResult> srList = Database.insert(caseAssetList, false);
                UTIL_LoggingService.logDmlResults(srList, null, caseAssetList, '',
                                                  UTIL_ErrorConstants.CASE_TRIGGER_CLASS, '', UTIL_ErrorConstants.CASE_TRIGGER, LoggingLevel.ERROR);

                // DEBUG: Log insert results
                Integer successCount = 0;
                Integer failureCount = 0;
                for (Database.SaveResult sr : srList) {
                    if (sr.isSuccess()) {
                        successCount++;
                    } else {
                        failureCount++;
                        for (Database.Error err : sr.getErrors()) {
                            System.debug('    Case Asset insert ERROR: ' + err.getStatusCode() + ' - ' + err.getMessage());
                        }
                    }
                }
                System.debug('  Case Assets inserted - Success: ' + successCount + ', Failures: ' + failureCount);
            } else {
                System.debug('  NO Case Assets to insert - caseAssetList is EMPTY');
            }

            System.debug('CaseAssetValidator.createCaseAssetRelationships - EXIT');
        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
* @description Marks duplicate service date cases for the same asset/client/service date within 15 minutes
* @param newCaseMap Cases to check for duplicates
*/
    public static void markDuplicateServiceDateCases(Map<Id, Case> newCaseMap) {
        try {
            if (newCaseMap.isEmpty()) {
                return;
            }
            
            Id caseId = null;
            for (Id cId : newCaseMap.keySet()) {
                caseId = cId;
                break;
            }
            
            Case cs = newCaseMap.get(caseId);
            
            // Get list of other cases created within 15 minutes with same criteria
            List<Case> lstCase = [
                SELECT Id, CaseNumber, Client__c, AssetId, Service_Date__c, Case_Type__c, Status, 
                CreatedDate, CreatedById, Reference_Number__c 
                FROM Case
                WHERE Client__c = :cs.Client__c 
                AND AssetId = :cs.AssetId 
                AND Service_Date__c = :cs.Service_Date__c 
                AND Case_Type__c = :cs.Case_Type__c 
                AND Reference_Number__c = :cs.Reference_Number__c
                AND (Status = :Constant_Util.PENDING OR Status = :Constant_Util.OPEN) 
                AND CreatedDate >= :DateTime.now().addMinutes(-15)
                AND CreatedById = :UserInfo.getUserId() 
                AND Id != :caseId
            ];
            
            if (!lstCase.isEmpty()) { 
                for (Case ca : newCaseMap.values()) {                 
                    ca.Is_Multiple_Case_Per_ServiceDT__c = true;
                }
            }
        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
* @description Checks if parent case was created within specified time window
* @param caseId Case ID to check
* @param minuteWindow Time window in minutes
* @return True if parent case created within time window
*/
    public static Boolean isParentCaseWithinTimeWindow(Id caseId, Integer minuteWindow) {
        try {
            if (caseId == null) {
                return false;
            }
            
            Case cse = [
                SELECT Id, CreatedDate, Parent.CreatedDate, ParentId 
                FROM Case 
                WHERE Id = :caseId 
                LIMIT 1
            ];
            
            if (cse != null && cse.ParentId != null && cse.Parent.CreatedDate != null) {                
                if (cse.CreatedDate <= cse.Parent.CreatedDate.addMinutes(minuteWindow)) {
                    return true;
                }
            }
        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return false;
    }
    
    /**
* @description Validates that CSR users cannot edit closed cases
* @param newMap Cases being updated
*/
    public static void validateClosedCaseEdits(Map<Id, Case> newMap) {
        try {
            String loggedInUserProfileName = null; 
            Id userProfileId = UserInfo.getProfileId();
            loggedInUserProfileName = SystemObjectSelector.getLoggedInUserProfile(userProfileId);
            
            if (Trigger.isUpdate && Trigger.isBefore) {
                for (Case cse : newMap.values()) {
                    if (String.isNotBlank(loggedInUserProfileName) && 
                        loggedInUserProfileName == Constant_Util.CUSTOMER_SERVICE && 
                        !Test.isRunningTest()) {
                            cse.addError(Constant_Util.CLOSE_CASE_ERROR_CSR);
                        }
                }
            }
        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
* @description Determines if SLA should be reset based on case field changes
* @param caseRecord Current case record
* @param oldCaseRecord Previous case record
* @return True if SLA should be reset
*/
    public static Boolean shouldResetSLA(Case caseRecord, Case oldCaseRecord) {
        Boolean resetSla = false;
        
        if ((String.isNotBlank(caseRecord.Case_Type__c) && caseRecord.Case_Type__c != oldCaseRecord.Case_Type__c) || 
            (String.isNotBlank(caseRecord.Case_Sub_Type__c) && caseRecord.Case_Sub_Type__c != oldCaseRecord.Case_Sub_Type__c) || 
            (String.isNotBlank(caseRecord.Location__c) && caseRecord.Location__c != oldCaseRecord.Location__c) ||
            (String.isNotBlank(caseRecord.AssetId) && caseRecord.AssetId != oldCaseRecord.AssetId)) {
                resetSla = true;
            }
        
        return resetSla;
    }
    
    /**
* @description Identifies rolloff assets that have core pickup services affecting subtype logic
* @param caseWithContainerMap Map of case assets
* @return Set of parent asset IDs that meet criteria
*/
    public static Set<Id> identifyROLAssetsThatAffectSubtype(Map<Id, Asset> caseWithContainerMap) {
        Set<Id> assetIdSetAfterFilter = new Set<Id>();
        Set<Id> parentAssetIdSetAfterFilter = new Set<Id>();
        
        try {
            // Filter for rolloff assets
            for (Asset asst : caseWithContainerMap.values()) {
                if (asst.Product2.Family == Constant_Util.ROLLOFF) {
                    assetIdSetAfterFilter.add(asst.Id);
                }
            }
            
            // Check for rolloff assets with core pickup services
            if (!assetIdSetAfterFilter.isEmpty()) {
                for (Asset asst : [
                    SELECT Id, 
                    (SELECT Id, ParentId, Service_Type__c, Is_Core_Service__c 
                     FROM ChildAssets) 
                    FROM Asset 
                    WHERE Id IN :assetIdSetAfterFilter
                ]) {
                    List<Asset> childAssetList = asst.ChildAssets;
                    if (!childAssetList.isEmpty()) {
                        for (Asset childAsset : childAssetList) {
                            if (childAsset.Service_Type__c == Constant_Util.PICKUP_CSTYPE && 
                                childAsset.Is_Core_Service__c == true) {
                                    parentAssetIdSetAfterFilter.add(childAsset.ParentId);
                                }
                        }
                    }
                }
            }
        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return parentAssetIdSetAfterFilter;
    }
    
    // ==================== PRIVATE HELPER METHODS ====================
    
    /**
* @description Queries asset with all required child relationships
* @param assetId The asset ID to query
* @return Asset record with children
*/
    private static Asset queryAssetWithChildren(Id assetId) {
        List<Asset> assets = [
            SELECT Id, Name, Occurrence_Type__c, ProductFamily, Product2.Equipment_Type__c,
            Material_Type__c, Is_Active__c, Start_Date__c, End_Date__c,
            (SELECT Id, Name, ParentId, Service_Type__c, Start_Date__c, End_Date__c,
             ProductFamily, Occurrence_Type__c, Material_Type__c, Has_Extra_Pickup__c,
             Is_Active__c, Is_Core_Service__c
             FROM ChildAssets)
            FROM Asset
            WHERE Id = :assetId
            LIMIT 1
        ];
        
        return assets.isEmpty() ? null : assets[0];
    }
    
    /**
* @description Checks if an asset is active for a specific date
* @param asset The asset to check
* @param checkDate The date to validate against
* @return True if asset is active, false otherwise
*/
    private static Boolean isAssetActiveForDate(Asset asset, DateTime checkDate) {
        if (asset.End_Date__c == null) {
            return asset.Start_Date__c <= checkDate.dateGmt();
        } else {
            return asset.Start_Date__c <= checkDate.dateGmt() && 
                asset.End_Date__c >= checkDate.dateGmt();
        }
    }
    
    /**
* @description Checks if there are extended assets that are active
* @param header The parent asset
* @param serviceDatetime The service date to check
* @return True if extended assets exist and are active
*/
    private static Boolean hasExtendedAssetActive(Asset header, DateTime serviceDatetime) {
        for (Asset assetDetail : header.ChildAssets) {
            if (assetDetail.End_Date__c == null || assetDetail.End_Date__c >= Date.today()) {
                if (assetDetail.Start_Date__c <= serviceDatetime.dateGmt()) {
                    return true;
                }
            }
        }
        return false;
    }
    
    /**
* @description Validates commercial asset configuration
* @param header The parent asset
* @param serviceDate The service date
* @return ValidationResult for commercial asset
*/
    private static ValidationResult validateCommercialAsset(Asset header, DateTime serviceDate) {
        Integer scheduledActiveWithXPU = 0;
        Integer onCallActiveWithoutXPU = 0;
        Integer coreServiceActive = 0;
        
        for (Asset child : header.ChildAssets) {
            if (!isAssetActiveForDate(child, serviceDate)) {
                continue;
            }
            
            coreServiceActive += child.Is_Core_Service__c ? 1 : 0;
            
            if (Constant_Util.PICKUP_CSTYPE.equals(child.Service_Type__c)) {
                if (Constant_Util.SCHEDULED.equals(child.Occurrence_Type__c) && child.Has_Extra_Pickup__c) {
                    scheduledActiveWithXPU++;
                } else if (Constant_Util.ON_CALL.equals(child.Occurrence_Type__c) && !child.Has_Extra_Pickup__c) {
                    onCallActiveWithoutXPU++;
                }
            }
        }
        
        // Validate scheduled assets
        if (Constant_Util.SCHEDULED.equals(header.Occurrence_Type__c)) {
            if (coreServiceActive == 0) {
                return new ValidationResult(false, CASE_ASSETS_END_DATE_PASSED, 'COMMERCIAL');
            }
            if (scheduledActiveWithXPU == 0) {
                return new ValidationResult(false, HAS_XPU_COMPONENT_NOT_EXISTS, 'COMMERCIAL');
            }
            if (scheduledActiveWithXPU > 1 || onCallActiveWithoutXPU > 1) {
                return new ValidationResult(false, HAS_XPU_COMPONENT_CORRUPTED, 'COMMERCIAL');
            }
        } 
        // Validate on-call assets
        else if (Constant_Util.ON_CALL.equals(header.Occurrence_Type__c)) {
            if (onCallActiveWithoutXPU == 0) {
                return new ValidationResult(false, NO_CASE_ASSETS, 'COMMERCIAL');
            }
            if (onCallActiveWithoutXPU > 1) {
                return new ValidationResult(false, ASSET_COMPONENT_CORRUPTED, 'COMMERCIAL');
            }
        }
        
        return new ValidationResult(true, null, 'COMMERCIAL');
    }
    
    /**
* @description Validates rolloff asset configuration
* @param header The parent asset
* @param serviceDate The service date
* @return ValidationResult for rolloff asset
*/
    private static ValidationResult validateRolloffAsset(Asset header, DateTime serviceDate) {
        Integer coreActiveCount = 0;
        Integer recyclingActiveCount = 0;
        Integer balerCount = 0;
        Set<Id> parentAssetIdSetAfterFilter = getFilteredRolloffParentAssets(new Set<Id>{header.Id});
        
        for (Asset child : header.ChildAssets) {
            if (!isAssetActiveForDate(child, serviceDate)) {
                continue;
            }
            
            if (child.Is_Core_Service__c) {
                coreActiveCount++;
            }
            if (Constant_Util.RECYCLING.equals(child.Service_Type__c)) {
                recyclingActiveCount++;
            }
            if (Constant_Util.BALER.equals(header.Product2.Equipment_Type__c) && 
                Constant_Util.PICKUP_CSTYPE.equals(child.Service_Type__c)) {
                    balerCount++;
                }
            
            // Handle pickup service type for scheduled rolloffs
            if (Constant_Util.PICKUP_CSTYPE.equals(child.Service_Type__c)) {
                if (!parentAssetIdSetAfterFilter.isEmpty() && 
                    parentAssetIdSetAfterFilter.contains(header.Id) &&
                    Constant_Util.SCHEDULED.equals(child.Occurrence_Type__c)) {
                        // Asset is valid for extra pickup
                        return new ValidationResult(true, null, 'ROLLOFF');
                    }
            }
        }
        
        if (coreActiveCount == 0 && recyclingActiveCount == 0 && balerCount == 0) {
            return new ValidationResult(false, ROLLOFF_ASSET_ERROR, 'ROLLOFF');
        }
        
        return new ValidationResult(true, null, 'ROLLOFF');
    }
    
    /**
* @description Gets filtered rolloff parent assets that have core pickup services
* @param assetIds Set of asset IDs to check
* @return Set of parent asset IDs that meet criteria
*/
    private static Set<Id> getFilteredRolloffParentAssets(Set<Id> assetIds) {
        Set<Id> parentAssetIdSetAfterFilter = new Set<Id>();
        
        List<Asset> assetsToCheck = [
            SELECT Id, 
            (SELECT Id, ParentId, Service_Type__c, Is_Core_Service__c 
             FROM ChildAssets)
            FROM Asset 
            WHERE Id IN :assetIds
        ];
        
        for (Asset asst : assetsToCheck) {
            for (Asset childAsset : asst.ChildAssets) {
                if (Constant_Util.PICKUP_CSTYPE.equals(childAsset.Service_Type__c) && 
                    childAsset.Is_Core_Service__c) {
                        parentAssetIdSetAfterFilter.add(childAsset.ParentId);
                    }
            }
        }
        
        return parentAssetIdSetAfterFilter;
    }
    
    /**
* @description Builds hierarchical map of assets by service header and service type
* Handles both flat asset maps (with Service_Header_Id__c) and parent assets with ChildAssets
* @param assetMap Map of all assets (may be parent assets with ChildAssets or flat child asset map)
* @return Nested map: Service Header ID (Parent Asset ID) -> Service Type -> List of Assets
*/
    private static Map<String, Map<String, List<Asset>>> buildAssetHierarchyMap(Map<Id, Asset> assetMap) {
        Map<String, Map<String, List<Asset>>> assetByServiceHeaderMap = new Map<String, Map<String, List<Asset>>>();

        if (assetMap != null && !assetMap.isEmpty()) {
            for (Asset asst : assetMap.values()) {
                // First, check if this is a parent asset with ChildAssets relationship populated
                if (asst.ChildAssets != null && !asst.ChildAssets.isEmpty()) {
                    // Process child assets from the relationship
                    for (Asset childAsset : asst.ChildAssets) {
                        if (childAsset.Is_Active__c) {
                            addAssetToHierarchyMap(assetByServiceHeaderMap, asst.Id, childAsset);
                        }
                    }
                }
                // Otherwise, check if this is a child asset with Service_Header_Id__c (flat map structure)
                else if (asst.Service_Header_Id__c != null && asst.Is_Active__c) {
                    addAssetToHierarchyMap(assetByServiceHeaderMap, asst.Service_Header_Id__c, asst);
                }
            }
        }

        return assetByServiceHeaderMap;
    }

    /**
* @description Helper method to add an asset to the hierarchy map
* @param hierarchyMap The map to add to
* @param serviceHeaderId The service header (parent) ID
* @param childAsset The child asset to add
*/
    private static void addAssetToHierarchyMap(Map<String, Map<String, List<Asset>>> hierarchyMap,
                                               String serviceHeaderId,
                                               Asset childAsset) {
        Map<String, List<Asset>> assetbyServiceTypeMap = hierarchyMap.get(serviceHeaderId);

        if (assetbyServiceTypeMap == null) {
            assetbyServiceTypeMap = new Map<String, List<Asset>>();
            hierarchyMap.put(serviceHeaderId, assetbyServiceTypeMap);
        }

        if (!assetbyServiceTypeMap.containsKey(childAsset.Service_Type__c)) {
            assetbyServiceTypeMap.put(childAsset.Service_Type__c, new List<Asset>());
        }

        assetbyServiceTypeMap.get(childAsset.Service_Type__c).add(childAsset);
    }
    
    /**
* @description Builds list of case assets based on asset hierarchy and case criteria
* @param caseNewMap Cases needing asset relationships
* @param assetMap Map of all assets
* @param assetByServiceHeaderMap Hierarchical asset map
* @return List of case assets to insert
*/
    private static List<SBS_Case_Asset__c> buildCaseAssetList(Map<Id, Case> caseNewMap, 
                                                              Map<Id, Asset> assetMap,
                                                              Map<String, Map<String, List<Asset>>> assetByServiceHeaderMap) {
                                                                  List<SBS_Case_Asset__c> caseAssetList = new List<SBS_Case_Asset__c>();
                                                                  Set<Id> parentIDsetAfterFilterRolOf = new Set<Id>();
                                                                  
                                                                  if (!assetMap.isEmpty()) {
                                                                      parentIDsetAfterFilterRolOf = identifyROLAssetsThatAffectSubtype(assetMap);
                                                                  }
                                                                  
                                                                  for (Case caseRecord : caseNewMap.values()) {
                                                                      if (String.isBlank(caseRecord.AssetId) || !assetMap.containsKey(caseRecord.AssetId)) {
                                                                          continue;
                                                                      }
                                                                      
                                                                      Asset asstRecord = assetMap.get(caseRecord.AssetId);
                                                                      List<Asset> childAsstList = getRelevantChildAssets(caseRecord, asstRecord, 
                                                                                                                         assetByServiceHeaderMap, 
                                                                                                                         parentIDsetAfterFilterRolOf);
                                                                      
                                                                      // Create case asset records for valid child assets
                                                                      for (Asset asstVal : childAsstList) {
                                                                          if (isAssetValidForServiceDate(asstVal, caseRecord.Service_Date__c)) {
                                                                              SBS_Case_Asset__c caseAsset = new SBS_Case_Asset__c();
                                                                              caseAsset.CaseId__c = caseRecord.Id;
                                                                              caseAsset.Asset_Header__c = caseRecord.AssetId;
                                                                              caseAsset.AssetId__c = asstVal.Id;
                                                                              caseAssetList.add(caseAsset);
                                                                          }
                                                                      }
                                                                  }
                                                                  
                                                                  return caseAssetList;
                                                              }
    
    /**
* @description Gets relevant child assets based on asset family and case type
* @param caseRecord The case record
* @param parentAsset The parent asset
* @param assetByServiceHeaderMap Asset hierarchy map
* @param parentIDsetAfterFilterRolOf Filtered rolloff asset IDs
* @return List of relevant child assets
*/
    private static List<Asset> getRelevantChildAssets(Case caseRecord, Asset parentAsset,
                                                      Map<String, Map<String, List<Asset>>> assetByServiceHeaderMap,
                                                      Set<Id> parentIDsetAfterFilterRolOf) {
                                                          List<Asset> childAsstList = new List<Asset>();
                                                          
                                                          if (!assetByServiceHeaderMap.containsKey(parentAsset.Id)) {
                                                              return childAsstList;
                                                          }
                                                          
                                                          Map<String, List<Asset>> childAssetMap = assetByServiceHeaderMap.get(parentAsset.Id);
                                                          
                                                          if (Constant_Util.ROLLOFF.equalsIgnoreCase(parentAsset.ProductFamily)) {
                                                              childAsstList = getRolloffChildAssets(childAssetMap, parentAsset, parentIDsetAfterFilterRolOf);
                                                          } else if (Constant_Util.COMMERCIAL.equalsIgnoreCase(parentAsset.ProductFamily)) {
                                                              childAsstList = getCommercialChildAssets(childAssetMap);
                                                          } else if (Constant_Util.SERVICES.equalsIgnoreCase(parentAsset.ProductFamily)) {
                                                              childAsstList = getServicesChildAssets(childAssetMap);
                                                          }
                                                          
                                                          return childAsstList;
                                                      }
    
    /**
* @description Gets child assets for rolloff containers
* @param childAssetMap Map of child assets by service type
* @param parentAsset Parent asset
* @param parentIDsetAfterFilterRolOf Filtered rolloff IDs
* @return List of relevant child assets
*/
    private static List<Asset> getRolloffChildAssets(Map<String, List<Asset>> childAssetMap, 
                                                     Asset parentAsset,
                                                     Set<Id> parentIDsetAfterFilterRolOf) {
                                                         List<Asset> childAsstList = new List<Asset>();
                                                         
                                                         for (String asstKey : childAssetMap.keySet()) {
                                                             if (Constant_Util.DISPOSAL.equalsIgnoreCase(asstKey) || Constant_Util.RECYCLING.equalsIgnoreCase(asstKey)) {
                                                                 for (Asset asstRec : childAssetMap.get(asstKey)) {
                                                                     if (!asstRec.Is_Core_Service__c) {
                                                                         childAsstList.add(asstRec);
                                                                     }
                                                                 }
                                                             } else if (Constant_Util.PICKUP_CSTYPE.equalsIgnoreCase(asstKey)) {
                                                                 for (Asset asstRec : childAssetMap.get(asstKey)) {
                                                                     if ((Constant_Util.SCHEDULED.equalsIgnoreCase(asstRec.Occurrence_Type__c) && asstRec.Has_Extra_Pickup__c) ||
                                                                         Constant_Util.ON_CALL.equalsIgnoreCase(asstRec.Occurrence_Type__c)) {
                                                                             childAsstList.add(asstRec);
                                                                         }
                                                                 }
                                                             } else {
                                                                 for (Asset asstRec : childAssetMap.get(asstKey)) {
                                                                     if (asstRec.Is_Core_Service__c) {
                                                                         childAsstList.add(asstRec);
                                                                     }
                                                                 }
                                                             }
                                                         }
                                                         
                                                         return childAsstList;
                                                     }
    
    /**
* @description Gets child assets for commercial containers
* @param childAssetMap Map of child assets by service type
* @return List of relevant child assets
*/
    private static List<Asset> getCommercialChildAssets(Map<String, List<Asset>> childAssetMap) {
        List<Asset> childAsstList = new List<Asset>();
        
        for (String asstKey : childAssetMap.keySet()) {
            if (Constant_Util.PICKUP_CSTYPE.equalsIgnoreCase(asstKey) || 
                Constant_Util.HAND_PICKUP.equalsIgnoreCase(asstKey)) {
                    for (Asset asstRec : childAssetMap.get(asstKey)) {
                        if (Constant_Util.SCHEDULED.equalsIgnoreCase(asstRec.Occurrence_Type__c) || 
                            Constant_Util.ON_CALL.equalsIgnoreCase(asstRec.Occurrence_Type__c)) {
                                childAsstList.add(asstRec);
                            }
                    }
                }
        }
        
        return childAsstList;
    }
    
    /**
* @description Gets child assets for services
* @param childAssetMap Map of child assets by service type
* @return List of relevant child assets
*/
    private static List<Asset> getServicesChildAssets(Map<String, List<Asset>> childAssetMap) {
        List<Asset> childAsstList = new List<Asset>();
        
        if (childAssetMap.containsKey(Constant_Util.BULKSTRING)) {
            childAsstList.addAll(childAssetMap.get(Constant_Util.BULKSTRING));
        }
        if (childAssetMap.containsKey(Constant_Util.Haul_Away_Service)) {
            childAsstList.addAll(childAssetMap.get(Constant_Util.Haul_Away_Service));
        }
        if (childAssetMap.containsKey(Constant_Util.HAND_PICKUP)) {
            childAsstList.addAll(childAssetMap.get(Constant_Util.HAND_PICKUP));
        }
        
        return childAsstList;
    }
    
    /**
* @description Checks if asset is valid for the given service date
* @param asset Asset to validate
* @param serviceDate Service date to check
* @return True if asset is valid for service date
*/
    private static Boolean isAssetValidForServiceDate(Asset asset, Date serviceDate) {
        if (serviceDate == null) {
            return false;
        }
        
        if ((asset.Start_Date__c != null && asset.Start_Date__c <= serviceDate) && 
            (asset.End_Date__c == null || asset.End_Date__c >= serviceDate)) {
                return true;
            }
        
        if (asset.Start_Date__c == null && asset.End_Date__c == null) {
            return true;
        }
        
        return false;
    }
    
    /**
     * @description Validates pickup assets against business rules
     * @param assetParam Map of Asset ID to Service Date
     * @return Map of Asset ID to validation message (empty value = valid)
     */
    public static Map<Id, String> validatePickupAssets(Map<Id, Date> assetParam) {
        Map<Id, String> validationResults = new Map<Id, String>();
        
        try {
            if (assetParam == null || assetParam.isEmpty()) {
                return validationResults;
            }
            
            // Validate each asset
            for (Id assetId : assetParam.keySet()) {
                Date serviceDate = assetParam.get(assetId);
                ValidationResult result = validatePickupAsset(assetId, serviceDate);
                
                if (!result.isValid) {
                    validationResults.put(assetId, result.errorMessage);
                } else {
                    validationResults.put(assetId, '');
                }
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return validationResults;
    }
    
    /**
     * @description Validates non-pickup assets against business rules
     * @param assetParam Map of Asset ID to Service Date
     * @return Map of Asset ID to validation message (empty value = valid)
     */
    public static Map<Id, String> validateNonPickupAssets(Map<Id, Date> assetParam) {
        Map<Id, String> validationResults = new Map<Id, String>();
        
        try {
            if (assetParam == null || assetParam.isEmpty()) {
                return validationResults;
            }
            
            // Validate each asset
            for (Id assetId : assetParam.keySet()) {
                Date serviceDate = assetParam.get(assetId);
                ValidationResult result = validateNonPickupAsset(assetId, serviceDate);
                
                if (!result.isValid) {
                    validationResults.put(assetId, result.errorMessage);
                } else {
                    validationResults.put(assetId, '');
                }
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                                                    UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
        
        return validationResults;
    }
}