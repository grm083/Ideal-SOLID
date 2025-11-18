/**
 * Asset Selector Controller
 *
 * Unified LWC controller for asset search and selection.
 * Replaces AssetHeadersForCaseController functionality.
 *
 * Features:
 * - Context-aware asset search (filters by location)
 * - Multi-field search: SID, Material Type, Schedule, Vendor, etc.
 * - Multi-asset selection support
 * - Recent assets for quick selection
 * - Asset validation based on case type
 * - Service Header and Service Detail support
 *
 * Refactored from: AssetHeadersForCaseController.cls
 *
 * @author Claude (AI Assistant)
 * @date 2025-11-18
 */
public with sharing class AssetSelectorController {

    private static final String SERVICE_HEADER = Constant_Util.SERVICE_HEADER;
    private static final String SERVICE_DETAILS = Constant_Util.SERVICE_DETAILS;
    private static final String NEW_SERVICE_CASE = Constant_Util.New_Service_Case;

    // ========================================
    // Asset Search Methods
    // ========================================

    /**
     * Search for assets based on location and search criteria
     *
     * @param locationId The ID of the location account
     * @param caseRecordType The case record type (New Service or other)
     * @param searchCriteria Map of search fields and values
     * @return List of matching assets
     */
    @AuraEnabled(cacheable=true)
    public static List<AssetSearchResult> searchAssets(String locationId, String caseRecordType, Map<String, String> searchCriteria) {
        try {
            if (String.isBlank(locationId)) {
                throw new AuraHandledException('Location ID is required');
            }

            // Build dynamic query
            String query = buildAssetSearchQuery(locationId, caseRecordType, searchCriteria);

            UTIL_LoggingService.logDebug('AssetSelectorController.searchAssets',
                'Query: ' + query);

            List<Asset> assets = Database.query(query);

            return buildAssetSearchResults(assets, locationId);

        } catch (Exception e) {
            UTIL_LoggingService.logError('AssetSelectorController.searchAssets',
                'Error searching assets: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to search assets: ' + e.getMessage());
        }
    }

    /**
     * Get all assets for a location (for initial load)
     *
     * @param locationId The ID of the location account
     * @param caseRecordType The case record type
     * @return List of all assets at the location
     */
    @AuraEnabled(cacheable=true)
    public static List<AssetSearchResult> getAssetsForLocation(String locationId, String caseRecordType) {
        try {
            if (String.isBlank(locationId)) {
                return new List<AssetSearchResult>();
            }

            String query = buildBaseAssetQuery(locationId, caseRecordType);

            List<Asset> assets = Database.query(query);

            return buildAssetSearchResults(assets, locationId);

        } catch (Exception e) {
            UTIL_LoggingService.logError('AssetSelectorController.getAssetsForLocation',
                'Error getting assets: ' + e.getMessage(), e);
            return new List<AssetSearchResult>();
        }
    }

    /**
     * Get asset by ID with full details
     *
     * @param assetId The ID of the asset
     * @return Asset details
     */
    @AuraEnabled(cacheable=true)
    public static AssetSearchResult getAssetById(String assetId) {
        try {
            if (String.isBlank(assetId)) {
                throw new AuraHandledException('Asset ID is required');
            }

            Asset asset = [
                SELECT Id, Name, Active__c, Acorn_SID__c, Service_Type__c, Schedule__c,
                       Material_Type__c, Duration__c, Occurrence_Type__c, Sensitivity_Code__c,
                       Vendor_ID__c, Supplier__r.Name, Start_Date__c, End_Date__c,
                       Category__c, Container_Position__c, Equipment_Owner__c, Quantity__c,
                       Has_Extra_Pickup__c, Vendor_Account_Number__c, MAS_Company_Account_Number__c,
                       MAS_Customer_Unique_Id__c, MAS_Library__c, Frequency__c, Is_Active__c,
                       Equipment_Type__c, AccountId, RecordType.DeveloperName
                FROM Asset
                WHERE Id = :assetId
                LIMIT 1
            ];

            return buildAssetSearchResult(asset, null);

        } catch (Exception e) {
            UTIL_LoggingService.logError('AssetSelectorController.getAssetById',
                'Error getting asset: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to get asset: ' + e.getMessage());
        }
    }

    /**
     * Get recent assets for a location
     *
     * @param locationId The ID of the location
     * @param limitCount Number of recent assets to return
     * @return List of recent assets
     */
    @AuraEnabled(cacheable=true)
    public static List<AssetSearchResult> getRecentAssets(String locationId, Integer limitCount) {
        try {
            if (String.isBlank(locationId)) {
                return new List<AssetSearchResult>();
            }

            Integer recordLimit = (limitCount != null && limitCount > 0) ? limitCount : 10;

            // Get recent assets based on last case created
            List<Id> recentAssetIds = new List<Id>();
            for (Case c : [
                SELECT AssetId
                FROM Case
                WHERE Location__c = :locationId
                AND AssetId != null
                ORDER BY CreatedDate DESC
                LIMIT :recordLimit
            ]) {
                if (!recentAssetIds.contains(c.AssetId)) {
                    recentAssetIds.add(c.AssetId);
                }
            }

            if (recentAssetIds.isEmpty()) {
                return new List<AssetSearchResult>();
            }

            List<Asset> assets = [
                SELECT Id, Name, Active__c, Acorn_SID__c, Service_Type__c, Schedule__c,
                       Material_Type__c, Duration__c, Occurrence_Type__c, Sensitivity_Code__c,
                       Vendor_ID__c, Supplier__r.Name, Start_Date__c, End_Date__c,
                       Category__c, Container_Position__c, Equipment_Owner__c, Quantity__c,
                       Has_Extra_Pickup__c, Vendor_Account_Number__c, MAS_Company_Account_Number__c,
                       MAS_Customer_Unique_Id__c, MAS_Library__c, Frequency__c, Is_Active__c,
                       Equipment_Type__c, AccountId, RecordType.DeveloperName
                FROM Asset
                WHERE Id IN :recentAssetIds
                ORDER BY Name
            ];

            return buildAssetSearchResults(assets, locationId);

        } catch (Exception e) {
            UTIL_LoggingService.logError('AssetSelectorController.getRecentAssets',
                'Error getting recent assets: ' + e.getMessage(), e);
            return new List<AssetSearchResult>();
        }
    }

    /**
     * Get highlighted assets for a case (already selected assets)
     *
     * @param caseId The ID of the case
     * @return List of asset IDs that should be highlighted
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getHighlightedAssets(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                return new List<String>();
            }

            Set<Id> highlightIds = new Set<Id>();

            Case currentCase = [
                SELECT Id, AssetId, ParentId, Location__c, Reference_Number__c, Is_Multiple_Asset__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            // Add current case asset
            if (currentCase.AssetId != null) {
                highlightIds.add(currentCase.AssetId);
            }

            // Add related case assets
            List<Case> relatedCases = [
                SELECT Id, AssetId, ParentId, Is_Multiple_Asset__c
                FROM Case
                WHERE Reference_Number__c = :currentCase.Reference_Number__c
                AND Location__c = :currentCase.Location__c
                AND Id != :currentCase.Id
            ];

            for (Case c : relatedCases) {
                if (c.AssetId != null && c.Is_Multiple_Asset__c
                    && currentCase.Is_Multiple_Asset__c
                    && c.ParentId == currentCase.ParentId) {
                    highlightIds.add(c.AssetId);
                }
            }

            // Add cached assets (session partition)
            Cache.SessionPartition sessionPart = Cache.Session.getPartition(Constant_UTIL.MULTI_ASSET_PARTITION);
            if (sessionPart.contains(caseId)) {
                String[] assets = (String[])sessionPart.get(caseId);
                for (String assetId : assets) {
                    highlightIds.add(assetId);
                }
            }

            List<String> result = new List<String>();
            for (Id assetId : highlightIds) {
                result.add(assetId);
            }

            return result;

        } catch (Exception e) {
            UTIL_LoggingService.logError('AssetSelectorController.getHighlightedAssets',
                'Error getting highlighted assets: ' + e.getMessage(), e);
            return new List<String>();
        }
    }

    // ========================================
    // Asset Selection Methods
    // ========================================

    /**
     * Update case with selected asset
     *
     * @param caseId The ID of the case
     * @param assetId The ID of the selected asset
     * @param selectedAssetIds List of additional selected asset IDs (multi-asset)
     */
    @AuraEnabled
    public static void updateAssetOnCase(String caseId, String assetId, List<String> selectedAssetIds) {
        try {
            Case caseRecord = [SELECT Id, AssetId, Selected_Asset_Header_Ids__c FROM Case WHERE Id = :caseId LIMIT 1];

            if (String.isNotBlank(assetId)) {
                caseRecord.AssetId = assetId;
            }

            // Store multi-asset selection in session cache
            if (selectedAssetIds != null && !selectedAssetIds.isEmpty()) {
                String[] assetArray = selectedAssetIds;
                Cache.SessionPartition sessionPart = Cache.Session.getPartition(Constant_UTIL.MULTI_ASSET_PARTITION);
                sessionPart.put(caseId, assetArray, 3600, Cache.Visibility.ALL, true);
            }

            // Store selected assets in field for quote creation
            List<String> allAssetIds = new List<String>();
            if (selectedAssetIds != null) {
                allAssetIds.addAll(selectedAssetIds);
            }
            if (String.isNotBlank(caseRecord.AssetId) && !allAssetIds.contains(caseRecord.AssetId)) {
                allAssetIds.add(caseRecord.AssetId);
            }
            if (!allAssetIds.isEmpty()) {
                caseRecord.Selected_Asset_Header_Ids__c = String.join(allAssetIds, ';');
            }

            update caseRecord;

            UTIL_LoggingService.logDebug('AssetSelectorController.updateAssetOnCase',
                'Updated case ' + caseId + ' with asset ' + assetId);

        } catch (Exception e) {
            UTIL_LoggingService.logError('AssetSelectorController.updateAssetOnCase',
                'Error updating asset on case: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to update asset: ' + e.getMessage());
        }
    }

    /**
     * Validate asset selection
     *
     * @param assetId The ID of the asset
     * @param caseRecordType The case record type
     * @return Validation result
     */
    @AuraEnabled
    public static Map<String, Object> validateAssetSelection(String assetId, String caseRecordType) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('isValid', true);
        result.put('message', '');

        try {
            if (String.isBlank(assetId)) {
                result.put('isValid', false);
                result.put('message', 'Asset ID is required');
                return result;
            }

            Asset asset = [
                SELECT Id, Active__c, Is_Active__c, End_Date__c
                FROM Asset
                WHERE Id = :assetId
                LIMIT 1
            ];

            // Check if asset is active
            if (!asset.Is_Active__c) {
                result.put('isValid', false);
                result.put('message', 'This asset is inactive and cannot be selected');
                return result;
            }

            // Check if asset has ended
            if (asset.End_Date__c != null && asset.End_Date__c < Date.today()) {
                result.put('isValid', false);
                result.put('message', 'This asset has ended and cannot be selected');
                return result;
            }

            return result;

        } catch (Exception e) {
            result.put('isValid', false);
            result.put('message', 'Asset validation failed: ' + e.getMessage());
            return result;
        }
    }

    // ========================================
    // Private Helper Methods
    // ========================================

    /**
     * Build base asset query for a location
     */
    private static String buildBaseAssetQuery(String locationId, String caseRecordType) {
        String query = 'SELECT Id, Name, Active__c, Acorn_SID__c, Service_Type__c, Schedule__c, ' +
                      'Material_Type__c, Duration__c, Occurrence_Type__c, Sensitivity_Code__c, ' +
                      'Vendor_ID__c, Supplier__r.Name, Start_Date__c, End_Date__c, ' +
                      'Category__c, Container_Position__c, Equipment_Owner__c, Quantity__c, ' +
                      'Has_Extra_Pickup__c, Vendor_Account_Number__c, MAS_Company_Account_Number__c, ' +
                      'MAS_Customer_Unique_Id__c, MAS_Library__c, Frequency__c, Is_Active__c, ' +
                      'Equipment_Type__c, AccountId, RecordType.DeveloperName ' +
                      'FROM Asset ' +
                      'WHERE AccountId = :locationId ' +
                      'AND RecordType.DeveloperName = :SERVICE_HEADER ';

        // For non-New Service cases, filter by CPQ_Product__c
        if (String.isNotBlank(caseRecordType) && !NEW_SERVICE_CASE.equals(caseRecordType)) {
            // Note: Commented out as per SDT-29408 fix in original code
            // query += 'AND CPQ_Product__c != null ';
        }

        query += 'ORDER BY Name';

        return query;
    }

    /**
     * Build dynamic asset search query
     */
    private static String buildAssetSearchQuery(String locationId, String caseRecordType, Map<String, String> searchCriteria) {
        String baseQuery = buildBaseAssetQuery(locationId, caseRecordType);

        // Remove ORDER BY for now
        baseQuery = baseQuery.replace('ORDER BY Name', '');

        List<String> conditions = new List<String>();

        // SID search
        if (searchCriteria.containsKey('sid') && String.isNotBlank(searchCriteria.get('sid'))) {
            String sid = String.escapeSingleQuotes(searchCriteria.get('sid').trim());
            conditions.add('Acorn_SID__c LIKE \'%' + sid + '%\'');
        }

        // Material Type search
        if (searchCriteria.containsKey('materialType') && String.isNotBlank(searchCriteria.get('materialType'))) {
            String materialType = String.escapeSingleQuotes(searchCriteria.get('materialType').trim());
            conditions.add('Material_Type__c LIKE \'%' + materialType + '%\'');
        }

        // Schedule search
        if (searchCriteria.containsKey('schedule') && String.isNotBlank(searchCriteria.get('schedule'))) {
            String schedule = String.escapeSingleQuotes(searchCriteria.get('schedule').trim());
            conditions.add('Schedule__c LIKE \'%' + schedule + '%\'');
        }

        // Vendor search
        if (searchCriteria.containsKey('vendorName') && String.isNotBlank(searchCriteria.get('vendorName'))) {
            String vendorName = String.escapeSingleQuotes(searchCriteria.get('vendorName').trim());
            conditions.add('Supplier__r.Name LIKE \'%' + vendorName + '%\'');
        }

        // Equipment Type search
        if (searchCriteria.containsKey('equipmentType') && String.isNotBlank(searchCriteria.get('equipmentType'))) {
            String equipmentType = String.escapeSingleQuotes(searchCriteria.get('equipmentType').trim());
            conditions.add('Equipment_Type__c LIKE \'%' + equipmentType + '%\'');
        }

        // Category search
        if (searchCriteria.containsKey('category') && String.isNotBlank(searchCriteria.get('category'))) {
            String category = String.escapeSingleQuotes(searchCriteria.get('category').trim());
            conditions.add('Category__c LIKE \'%' + category + '%\'');
        }

        // Active assets only filter
        if (searchCriteria.containsKey('activeOnly') && searchCriteria.get('activeOnly') == 'true') {
            conditions.add('Is_Active__c = true');
        }

        if (!conditions.isEmpty()) {
            baseQuery += ' AND (' + String.join(conditions, ' AND ') + ')';
        }

        baseQuery += ' ORDER BY Name LIMIT 500';

        return baseQuery;
    }

    /**
     * Build asset search results from Asset list
     */
    private static List<AssetSearchResult> buildAssetSearchResults(List<Asset> assets, String locationId) {
        List<AssetSearchResult> results = new List<AssetSearchResult>();

        // Get service detail (core) information
        Set<Id> headerIds = new Set<Id>();
        for (Asset asset : assets) {
            headerIds.add(asset.Id);
        }

        Map<Id, Asset> coreDetailMap = new Map<Id, Asset>();
        for (Asset detail : [
            SELECT Id, MAS_Customer_Unique_Id__c, Schedule__c, Quantity__c, RootAssetId
            FROM Asset
            WHERE RootAssetId IN :headerIds
            AND Is_Active__c = true
            AND Is_Core_Service__c = true
            AND RecordType.DeveloperName = :SERVICE_DETAILS
        ]) {
            coreDetailMap.put(detail.RootAssetId, detail);
        }

        for (Asset asset : assets) {
            AssetSearchResult result = buildAssetSearchResult(asset, coreDetailMap.get(asset.Id));
            results.add(result);
        }

        return results;
    }

    /**
     * Build single asset search result
     */
    private static AssetSearchResult buildAssetSearchResult(Asset asset, Asset coreDetail) {
        AssetSearchResult result = new AssetSearchResult();

        result.id = asset.Id;
        result.name = asset.Name;
        result.acornSID = asset.Acorn_SID__c;
        result.materialType = asset.Material_Type__c;
        result.duration = asset.Duration__c;
        result.occurrenceType = asset.Occurrence_Type__c;
        result.schedule = asset.Schedule__c;
        result.quantity = asset.Quantity__c;
        result.category = asset.Category__c;
        result.containerPosition = asset.Container_Position__c;
        result.hasExtraPickup = asset.Has_Extra_Pickup__c;
        result.supplierName = asset.Supplier__r != null ? asset.Supplier__r.Name : '';
        result.vendorId = asset.Vendor_ID__c;
        result.sensitivityCode = asset.Sensitivity_Code__c;
        result.vendorAccountNumber = asset.Vendor_Account_Number__c;
        result.masCompanyAccountNumber = asset.MAS_Company_Account_Number__c;
        result.masCustomerUniqueId = asset.MAS_Customer_Unique_Id__c;
        result.masLibrary = asset.MAS_Library__c;
        result.startDate = asset.Start_Date__c;
        result.endDate = asset.End_Date__c;
        result.equipmentOwner = asset.Equipment_Owner__c;
        result.isActive = asset.Is_Active__c;
        result.isProjectActive = asset.Active__c;
        result.equipmentType = asset.Equipment_Type__c;

        // Add core detail information if available
        if (coreDetail != null) {
            result.masCustomerUniqueId = coreDetail.MAS_Customer_Unique_Id__c;
            result.schedule = coreDetail.Schedule__c;
            result.quantity = coreDetail.Quantity__c;
        }

        return result;
    }

    // ========================================
    // Wrapper Classes
    // ========================================

    /**
     * Asset Search Result Wrapper
     */
    public class AssetSearchResult {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String acornSID { get; set; }
        @AuraEnabled public String materialType { get; set; }
        @AuraEnabled public String duration { get; set; }
        @AuraEnabled public String occurrenceType { get; set; }
        @AuraEnabled public String schedule { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String containerPosition { get; set; }
        @AuraEnabled public Boolean hasExtraPickup { get; set; }
        @AuraEnabled public String supplierName { get; set; }
        @AuraEnabled public String vendorId { get; set; }
        @AuraEnabled public String sensitivityCode { get; set; }
        @AuraEnabled public String vendorAccountNumber { get; set; }
        @AuraEnabled public String masCompanyAccountNumber { get; set; }
        @AuraEnabled public Decimal masCustomerUniqueId { get; set; }
        @AuraEnabled public String masLibrary { get; set; }
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        @AuraEnabled public String equipmentOwner { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }
        @AuraEnabled public Boolean isProjectActive { get; set; }
        @AuraEnabled public String equipmentType { get; set; }
    }
}
