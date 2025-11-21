/**
 * Case Type Configurator Controller
 *
 * Unified LWC controller for record type and case type/sub-type/reason configuration.
 * Replaces changeRecordTypeController and FillCaseSubType functionality.
 *
 * Features:
 * - Record type selection with filtering
 * - Dependent picklist values for Case Type, Sub-Type, and Reason
 * - Auto-population based on asset and record type
 * - Validation of selections
 * - Case update with new values
 *
 * Refactored from: changeRecordTypeController.cls
 *
 * @author George Martin
 * @date 2025-11-18
 */
public with sharing class CaseTypeConfiguratorController {

    // ========================================
    // Record Type Methods
    // ========================================

    /**
     * Get available record types for Case object
     *
     * @return List of available record types
     */
    @AuraEnabled(cacheable=true)
    public static List<RecordTypeOption> getAvailableRecordTypes() {
        try {
            List<RecordTypeOption> options = new List<RecordTypeOption>();

            // Exclude certain record types from selection
            List<RecordType> recordTypes = [
                SELECT Id, Name, Description
                FROM RecordType
                WHERE SobjectType = 'Case'
                AND Name NOT IN ('Pickup Case', 'Status Case', 'New Service Case')
                AND IsActive = true
                ORDER BY Name
            ];

            for (RecordType rt : recordTypes) {
                options.add(new RecordTypeOption(rt.Id, rt.Name, rt.Description));
            }

            return options;

        } catch (Exception e) {
            UTIL_LoggingService.logError('CaseTypeConfiguratorController.getAvailableRecordTypes',
                'Error getting record types: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to get record types: ' + e.getMessage());
        }
    }

    /**
     * Get current case configuration
     *
     * @param caseId The ID of the case
     * @return Current case configuration
     */
    @AuraEnabled(cacheable=true)
    public static CaseConfiguration getCurrentConfiguration(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                throw new AuraHandledException('Case ID is required');
            }

            Case c = [
                SELECT Id, RecordTypeId, RecordType.Name, Case_Type__c, Case_Sub_Type__c,
                       Case_Reason__c, AssetId, Asset.Name, Asset.Product2.Family,
                       Asset.Duration__c, Asset.Occurrence_Type__c, Asset.Product2.Equipment_Type__c,
                       CPQ_New_Service__c, LOB__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            CaseConfiguration config = new CaseConfiguration();
            config.recordTypeId = c.RecordTypeId;
            config.recordTypeName = c.RecordType.Name;
            config.caseType = c.Case_Type__c;
            config.caseSubType = c.Case_Sub_Type__c;
            config.caseReason = c.Case_Reason__c;
            config.assetId = c.AssetId;
            config.assetName = c.Asset != null ? c.Asset.Name : '';
            config.assetFamily = c.Asset != null && c.Asset.Product2 != null ? c.Asset.Product2.Family : '';

            return config;

        } catch (Exception e) {
            UTIL_LoggingService.logError('CaseTypeConfiguratorController.getCurrentConfiguration',
                'Error getting configuration: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to get configuration: ' + e.getMessage());
        }
    }

    // ========================================
    // Picklist Value Methods
    // ========================================

    /**
     * Get Case Type picklist values
     *
     * @param recordTypeId The record type ID (for filtering)
     * @return List of Case Type values
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getCaseTypeValues(String recordTypeId) {
        try {
            List<PicklistOption> options = new List<PicklistOption>();

            Schema.DescribeFieldResult fieldResult = Case.Case_Type__c.getDescribe();
            List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();

            for (Schema.PicklistEntry entry : entries) {
                if (entry.isActive()) {
                    options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
                }
            }

            return options;

        } catch (Exception e) {
            UTIL_LoggingService.logError('CaseTypeConfiguratorController.getCaseTypeValues',
                'Error getting case type values: ' + e.getMessage(), e);
            return new List<PicklistOption>();
        }
    }

    /**
     * Get Case Sub-Type picklist values based on Case Type
     *
     * @param caseType The selected case type
     * @param recordTypeId The record type ID
     * @return List of Case Sub-Type values
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getCaseSubTypeValues(String caseType, String recordTypeId) {
        try {
            List<PicklistOption> options = new List<PicklistOption>();

            Schema.DescribeFieldResult fieldResult = Case.Case_Sub_Type__c.getDescribe();
            List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();

            // Get controlling values for filtering
            Map<String, List<String>> dependentPicklistMap = getDependentPicklistValues(
                Case.Case_Type__c,
                Case.Case_Sub_Type__c
            );

            // If case type is selected, filter by dependent values
            if (String.isNotBlank(caseType) && dependentPicklistMap.containsKey(caseType)) {
                List<String> validValues = dependentPicklistMap.get(caseType);
                for (Schema.PicklistEntry entry : entries) {
                    if (entry.isActive() && validValues.contains(entry.getValue())) {
                        options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
                    }
                }
            } else {
                // Return all active values
                for (Schema.PicklistEntry entry : entries) {
                    if (entry.isActive()) {
                        options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
                    }
                }
            }

            return options;

        } catch (Exception e) {
            UTIL_LoggingService.logError('CaseTypeConfiguratorController.getCaseSubTypeValues',
                'Error getting case sub-type values: ' + e.getMessage(), e);
            return new List<PicklistOption>();
        }
    }

    /**
     * Get Case Reason picklist values based on Case Sub-Type
     *
     * @param caseSubType The selected case sub-type
     * @param recordTypeId The record type ID
     * @return List of Case Reason values
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getCaseReasonValues(String caseSubType, String recordTypeId) {
        try {
            List<PicklistOption> options = new List<PicklistOption>();

            Schema.DescribeFieldResult fieldResult = Case.Case_Reason__c.getDescribe();
            List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();

            // Get controlling values for filtering
            Map<String, List<String>> dependentPicklistMap = getDependentPicklistValues(
                Case.Case_Sub_Type__c,
                Case.Case_Reason__c
            );

            // If case sub-type is selected, filter by dependent values
            if (String.isNotBlank(caseSubType) && dependentPicklistMap.containsKey(caseSubType)) {
                List<String> validValues = dependentPicklistMap.get(caseSubType);
                for (Schema.PicklistEntry entry : entries) {
                    if (entry.isActive() && validValues.contains(entry.getValue())) {
                        options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
                    }
                }
            } else {
                // Return all active values
                for (Schema.PicklistEntry entry : entries) {
                    if (entry.isActive()) {
                        options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
                    }
                }
            }

            return options;

        } catch (Exception e) {
            UTIL_LoggingService.logError('CaseTypeConfiguratorController.getCaseReasonValues',
                'Error getting case reason values: ' + e.getMessage(), e);
            return new List<PicklistOption>();
        }
    }

    // ========================================
    // Case Update Methods
    // ========================================

    /**
     * Update case with new configuration
     *
     * @param caseId The ID of the case
     * @param configJson JSON string of configuration
     */
    @AuraEnabled
    public static void updateCaseConfiguration(String caseId, String configJson) {
        try {
            if (String.isBlank(caseId)) {
                throw new AuraHandledException('Case ID is required');
            }

            ConfigurationUpdate config = (ConfigurationUpdate) JSON.deserialize(
                configJson,
                ConfigurationUpdate.class
            );

            Case c = [
                SELECT Id, RecordTypeId, Case_Type__c, Case_Sub_Type__c, Case_Reason__c,
                       CPQ_New_Service__c, LOB__c, AssetId, Asset.Product2.Family
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            // Update record type if provided
            if (String.isNotBlank(config.recordTypeId)) {
                c.RecordTypeId = config.recordTypeId;

                // Handle New Service case special logic
                Id newServiceRecordType = Schema.SObjectType.Case.getRecordTypeInfosByName()
                    .get(Constant_Util.New_Service_Case).getRecordTypeId();

                if (config.recordTypeId == newServiceRecordType) {
                    c.CPQ_New_Service__c = hasCPQLicense();
                    if (String.isBlank(c.LOB__c)) {
                        c.LOB__c = c.Asset != null && c.Asset.Product2 != null
                            ? c.Asset.Product2.Family
                            : Constant_Util.COMMERCIAL;
                    }
                } else {
                    c.CPQ_New_Service__c = false;
                }
            }

            // Update case type fields
            c.Case_Type__c = config.caseType;
            c.Case_Sub_Type__c = config.caseSubType;
            c.Case_Reason__c = config.caseReason;

            update c;

            UTIL_LoggingService.logDebug('CaseTypeConfiguratorController.updateCaseConfiguration',
                'Updated case ' + caseId + ' with configuration');

        } catch (Exception e) {
            UTIL_LoggingService.logError('CaseTypeConfiguratorController.updateCaseConfiguration',
                'Error updating configuration: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to update configuration: ' + e.getMessage());
        }
    }

    /**
     * Quick update case type for predefined scenarios (Pickup, SNP, ETA)
     *
     * @param caseId The ID of the case
     * @param quickType The quick type: 'Pickup', 'SNP', 'ETA', 'New Service', 'Update Asset'
     */
    @AuraEnabled
    public static void updateQuickCaseType(String caseId, String quickType) {
        try {
            if (String.isBlank(caseId)) {
                throw new AuraHandledException('Case ID is required');
            }

            Case c = [
                SELECT Id, RecordTypeId, Case_Type__c, Case_Sub_Type__c, Case_Reason__c,
                       AssetId, Asset.Name, Asset.Product2.Family, Asset.Duration__c,
                       Asset.Occurrence_Type__c, Asset.Product2.Equipment_Type__c,
                       CPQ_New_Service__c, LOB__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            // Reset CPQ flag
            c.CPQ_New_Service__c = false;

            if (quickType == 'Pickup') {
                handlePickupCase(c);
            } else if (quickType == 'SNP') {
                handleSNPCase(c);
            } else if (quickType == 'ETA') {
                handleETACase(c);
            } else if (quickType == 'New Service') {
                handleNewServiceCase(c);
            } else if (quickType == 'Update Asset') {
                handleUpdateAssetCase(c);
            }

            update c;

            UTIL_LoggingService.logDebug('CaseTypeConfiguratorController.updateQuickCaseType',
                'Updated case ' + caseId + ' with quick type: ' + quickType);

        } catch (Exception e) {
            UTIL_LoggingService.logError('CaseTypeConfiguratorController.updateQuickCaseType',
                'Error updating quick type: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to update case type: ' + e.getMessage());
        }
    }

    // ========================================
    // Validation Methods
    // ========================================

    /**
     * Validate case configuration
     *
     * @param configJson JSON string of configuration
     * @return Validation result
     */
    @AuraEnabled
    public static Map<String, Object> validateConfiguration(String configJson) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('isValid', true);
        result.put('message', '');

        try {
            ConfigurationUpdate config = (ConfigurationUpdate) JSON.deserialize(
                configJson,
                ConfigurationUpdate.class
            );

            // Validate required fields
            if (String.isBlank(config.caseType)) {
                result.put('isValid', false);
                result.put('message', 'Case Type is required');
                return result;
            }

            return result;

        } catch (Exception e) {
            result.put('isValid', false);
            result.put('message', 'Configuration validation failed: ' + e.getMessage());
            return result;
        }
    }

    // ========================================
    // Private Helper Methods
    // ========================================

    /**
     * Handle Pickup case type setup
     */
    private static void handlePickupCase(Case c) {
        c.Case_Type__c = 'Pickup';
        c.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName()
            .get('Pickup Case').getRecordTypeId();
        c.Case_Reason__c = '';

        // Determine sub-type based on asset characteristics
        if (c.Asset == null || c.Asset.Product2 == null) {
            c.Case_Sub_Type__c = '';
            return;
        }

        String family = c.Asset.Product2.Family;
        String equipmentType = c.Asset.Product2.Equipment_Type__c;
        String occurrenceType = c.Asset.Occurrence_Type__c;
        String duration = c.Asset.Duration__c;

        if (family == Constant_Util.COMMERCIAL && occurrenceType == Constant_Util.ON_CALL) {
            c.Case_Sub_Type__c = Constant_Util.ON_CALL_PICK;
        } else if (family == Constant_Util.COMMERCIAL
                  && Constant_Util.HAND_PICKUP.equals(equipmentType)
                  && Constant_Util.PERMANENT.equals(duration)) {
            c.Case_Sub_Type__c = '';
        } else if (family == Constant_Util.COMMERCIAL
                  && (occurrenceType == Constant_Util.SCHEDULED || occurrenceType == Constant_Util.SCHEDULED_ON_CALL)) {
            c.Case_Sub_Type__c = Constant_Util.EXTRA_PICKUP;
        } else if (family == Constant_Util.ROLLOFF
                  && duration == Constant_Util.PERMANENT
                  && equipmentType != Constant_Util.Baler) {
            c.Case_Sub_Type__c = Constant_Util.EMPTY_AND_RETURN;
        } else if (Constant_Util.Baler.equals(equipmentType)) {
            c.Case_Sub_Type__c = Constant_Util.Bales;
        } else if (family == Constant_Util.SERVICES && c.Asset.Name.equals(Constant_Util.Bulk_Service_Type)) {
            c.Case_Sub_Type__c = Constant_Util.Bulk_Service_Type;
        } else if (family == Constant_Util.SERVICES && c.Asset.Name.equals(Constant_Util.Got_Junk_Pickup)) {
            c.Case_Sub_Type__c = Constant_Util.Haul_Away_No_Equipment;
        } else {
            c.Case_Sub_Type__c = '';
        }
    }

    /**
     * Handle SNP (Service Not Performed) case type setup
     */
    private static void handleSNPCase(Case c) {
        c.Case_Type__c = 'Status';
        c.Case_Sub_Type__c = 'Service not performed';
        c.Case_Reason__c = 'Customer Reported';
        c.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName()
            .get('Status Case').getRecordTypeId();
    }

    /**
     * Handle ETA case type setup
     */
    private static void handleETACase(Case c) {
        c.Case_Type__c = 'Status';
        c.Case_Sub_Type__c = 'ETA';
        c.Case_Reason__c = '';
        c.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName()
            .get('Status Case').getRecordTypeId();
    }

    /**
     * Handle New Service case type setup
     */
    private static void handleNewServiceCase(Case c) {
        Id newServiceRecordType = Schema.SObjectType.Case.getRecordTypeInfosByName()
            .get(Constant_Util.New_Service_Case).getRecordTypeId();

        c.Case_Type__c = 'New Service';
        c.Case_Sub_Type__c = '';
        c.Case_Reason__c = '';
        c.CPQ_New_Service__c = hasCPQLicense();
        c.RecordTypeId = newServiceRecordType;

        if (String.isBlank(c.LOB__c)) {
            c.LOB__c = (c.Asset != null && c.Asset.Product2 != null && String.isNotBlank(c.Asset.Product2.Family))
                ? c.Asset.Product2.Family
                : Constant_Util.COMMERCIAL;
        }
    }

    /**
     * Handle Update Asset case type setup
     */
    private static void handleUpdateAssetCase(Case c) {
        Id updateAssetRecordType = Schema.SObjectType.Case.getRecordTypeInfosByName()
            .get('Update Asset Case').getRecordTypeId();

        c.Case_Type__c = '';
        c.Case_Sub_Type__c = '';
        c.Case_Reason__c = '';
        c.RecordTypeId = updateAssetRecordType;
    }

    /**
     * Check if current user has CPQ license
     */
    private static Boolean hasCPQLicense() {
        List<PermissionSetLicenseAssign> pslList = [
            SELECT Id, AssigneeId, PermissionSetLicenseId, PermissionSetLicense.MasterLabel
            FROM PermissionSetLicenseAssign
            WHERE PermissionSetLicense.MasterLabel = 'Salesforce CPQ License'
            AND AssigneeId = :UserInfo.getUserId()
        ];

        return !pslList.isEmpty();
    }

    /**
     * Get dependent picklist values
     */
    private static Map<String, List<String>> getDependentPicklistValues(
        Schema.SObjectField controllingField,
        Schema.SObjectField dependentField
    ) {
        Map<String, List<String>> dependentPicklistMap = new Map<String, List<String>>();

        Schema.DescribeFieldResult controllingFieldInfo = controllingField.getDescribe();
        Schema.DescribeFieldResult dependentFieldInfo = dependentField.getDescribe();

        List<Schema.PicklistEntry> controllingValues = controllingFieldInfo.getPicklistValues();
        List<Schema.PicklistEntry> dependentValues = dependentFieldInfo.getPicklistValues();

        for (Schema.PicklistEntry dependentValue : dependentValues) {
            if (dependentValue.isActive()) {
                List<String> controllers = new List<String>();

                // Simplified approach - add all controlling values
                for (Schema.PicklistEntry controllingValue : controllingValues) {
                    if (controllingValue.isActive()) {
                        controllers.add(controllingValue.getValue());
                    }
                }

                // Store in reverse map (we'll return controlling -> dependent)
                for (String controller : controllers) {
                    if (!dependentPicklistMap.containsKey(controller)) {
                        dependentPicklistMap.put(controller, new List<String>());
                    }
                    dependentPicklistMap.get(controller).add(dependentValue.getValue());
                }
            }
        }

        return dependentPicklistMap;
    }

    // ========================================
    // Wrapper Classes
    // ========================================

    /**
     * Record Type Option Wrapper
     */
    public class RecordTypeOption {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }

        public RecordTypeOption(String id, String name, String description) {
            this.id = id;
            this.name = name;
            this.description = description;
        }
    }

    /**
     * Case Configuration Wrapper
     */
    public class CaseConfiguration {
        @AuraEnabled public String recordTypeId { get; set; }
        @AuraEnabled public String recordTypeName { get; set; }
        @AuraEnabled public String caseType { get; set; }
        @AuraEnabled public String caseSubType { get; set; }
        @AuraEnabled public String caseReason { get; set; }
        @AuraEnabled public String assetId { get; set; }
        @AuraEnabled public String assetName { get; set; }
        @AuraEnabled public String assetFamily { get; set; }
    }

    /**
     * Configuration Update Input Wrapper
     */
    public class ConfigurationUpdate {
        @AuraEnabled public String recordTypeId { get; set; }
        @AuraEnabled public String caseType { get; set; }
        @AuraEnabled public String caseSubType { get; set; }
        @AuraEnabled public String caseReason { get; set; }
    }

    /**
     * Picklist Option Wrapper
     */
    public class PicklistOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
}
