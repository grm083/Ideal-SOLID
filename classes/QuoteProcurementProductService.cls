/**
 * @description QuoteProcurementProductService - Product configuration and option management layer
 *
 * This service handles product options, accessories, configuration attributes,
 * and product rules for QuoteLines.
 *
 * Key Responsibilities:
 * - Product option management (add/remove)
 * - Accessory management
 * - Configuration attribute handling
 * - Product rule evaluation
 * - Keys and quantity management
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - Product Configuration
 */
public with sharing class QuoteProcurementProductService {

    // ========================================================================
    // PUBLIC API - ACCESSORY MANAGEMENT
    // ========================================================================

    /**
     * @description Get accessories with selection for a product
     * Refactored from: getAccessoriesWithSelection() in QuoteProcurementController
     * @param productId The Product2 ID
     * @param quoteId The Quote ID
     * @return Map<String,List<Object>> Map of accessories and selections
     */
    @AuraEnabled
    public static Map<String, List<Object>> getAccessoriesWithSelection(Id productId, Id quoteId) {
        List<Id> selectedAccessoryList = new List<Id>();
        List<Id> disabledAccessoryList = new List<Id>();
        Map<Id, Id> mapOptionIdAndOptionSKUId = new Map<Id, Id>();

        QuoteLineSelector.getProductOptionForQuote(
            quoteId,
            selectedAccessoryList,
            mapOptionIdAndOptionSKUId,
            disabledAccessoryList
        );

        Map<String, List<Object>> mapSelectedAndAvailableAssesory = new Map<String, List<Object>>();
        mapSelectedAndAvailableAssesory.put('AllAccessory', ProductServices.filterProductOptions(productId, quoteId));
        mapSelectedAndAvailableAssesory.put('SelectedAccessory', selectedAccessoryList);
        mapSelectedAndAvailableAssesory.put('mapOptionIdAndOptionSKUId', new List<Object>{mapOptionIdAndOptionSKUId});
        mapSelectedAndAvailableAssesory.put('disabledAccessoryList', disabledAccessoryList);

        return mapSelectedAndAvailableAssesory;
    }

    /**
     * @description Get accessories for a product
     * Refactored from: getAccessories() in QuoteProcurementController
     * @param productId The Product2 ID
     * @return List<SBQQ__ProductOption__c> List of accessories
     */
    @AuraEnabled
    public static List<SBQQ__ProductOption__c> getAccessories(Id productId) {
        return [
            SELECT Id, SBQQ__ConfiguredSKU__r.Name, SBQQ__OptionalSKU__c,
                   SBQQ__OptionalSKU__r.Name, SBQQ__QuantityEditable__c, SBQQ__Quantity__c
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__ConfiguredSKU__c = :productId
                  AND SBQQ__Feature__r.Name IN ('Additional Services', 'General Accessories')
            ORDER BY SBQQ__Number__c DESC
        ];
    }

    /**
     * @description Get padlock keys for products
     * Refactored from: getPadlockKeys() in QuoteProcurementController
     * @param padLockIdList List of padlock Product IDs
     * @return List<SBQQ__ProductOption__c> List of key options
     */
    @AuraEnabled
    public static List<SBQQ__ProductOption__c> getPadlockKeys(List<Id> padLockIdList) {
        List<SBQQ__ProductOption__c> accessoryList = [
            SELECT Id, SBQQ__ConfiguredSKU__r.Name, SBQQ__ConfiguredSKU__c,
                   SBQQ__OptionalSKU__c, SBQQ__OptionalSKU__r.Name,
                   SBQQ__QuantityEditable__c, SBQQ__Quantity__c
            FROM SBQQ__ProductOption__c
            WHERE SBQQ__ConfiguredSKU__c IN :padLockIdList
        ];

        return accessoryList.isEmpty() ? null : accessoryList;
    }

    // ========================================================================
    // PUBLIC API - CONFIGURATION ATTRIBUTES
    // ========================================================================

    /**
     * @description Get configuration attributes for a product
     * Returns attributes with picklist values
     * @param productId The Product2 ID
     * @param quoteLineId The QuoteLine ID
     * @return List<SBQQ__ConfigurationAttribute__c> Configuration attributes
     */
    @AuraEnabled
    public static List<SBQQ__ConfigurationAttribute__c> getConfigAttributes(Id productId,
                                                                            String quoteLineId) {
        // Product-specific equipment style exclusions
        Map<String, Set<String>> equipmentStyleValuesWithProduct = new Map<String, Set<String>>();
        equipmentStyleValuesWithProduct.put('Dumpster',
            new Set<String>{'Apartment Style', 'Pre-Crusher', 'Horizontal', 'Vertical'});
        equipmentStyleValuesWithProduct.put('Compactor',
            new Set<String>{'Slant Top', 'Tall', 'Split Container', 'Cathedral', 'Loading Dock', 'Slant-Top'});

        String currentProductName;
        if (String.isNotBlank(productId)) {
            Product2 productObj = [SELECT Id, Name FROM Product2 WHERE Id = :productId LIMIT 1];
            if (productObj != null) {
                currentProductName = productObj.Name;
            }
        }

        List<SBQQ__ConfigurationAttribute__c> attributeList = [
            SELECT Id, SBQQ__TargetField__c, SBQQ__ApplyToProductOptions__c, SBQQ__Product__r.Name,
                   SBQQ__ColumnOrder__c, SBQQ__DisplayOrder__c, SBQQ__Feature__r.Name,
                   Picklist_Values__c, Name
            FROM SBQQ__ConfigurationAttribute__c
            WHERE SBQQ__Product__c = :productId
                  AND SBQQ__TargetField__c NOT IN (
                      'Equipment_Size__c', 'Duration', 'Occurrence_Type__c',
                      'Certificate_of_Destruction__c', 'Certificate_of_Disposal__c',
                      'Description_of_Waste__c', 'Profile_Number__c', 'Vendor__c'
                  )
            ORDER BY SBQQ__Feature__r.Name ASC, SBQQ__DisplayOrder__c ASC, SBQQ__ColumnOrder__c ASC
        ];

        // Build field list for dynamic query
        String configList = '';
        for (SBQQ__ConfigurationAttribute__c conf : attributeList) {
            if (String.isBlank(configList)) {
                configList = conf.SBQQ__TargetField__c;
            } else {
                configList += ', ' + conf.SBQQ__TargetField__c;
            }
        }

        // Query QuoteLine for current values
        String queryString = 'SELECT Id, ' + configList +
                           ' FROM SBQQ__QuoteLine__c WHERE Id = :quoteLineId LIMIT 1';
        SBQQ__QuoteLine__c targetQL = Database.query(queryString);

        // Build picklist options with selected values
        for (SBQQ__ConfigurationAttribute__c conf : attributeList) {
            List<PicklistSelect> picklistOptions = new List<PicklistSelect>();
            Schema.DescribeFieldResult dfr = SBQQ__QuoteLine__c.SObjectType.getDescribe()
                .fields.getMap()
                .get(conf.SBQQ__TargetField__c)
                .getDescribe();

            List<Schema.PicklistEntry> ple = dfr.getPicklistValues();
            for (Schema.PicklistEntry p : ple) {
                PicklistSelect ps = new PicklistSelect();
                ps.value = p.getValue();
                ps.label = p.getLabel();
                ps.selected = (p.getValue() == targetQL.get(conf.SBQQ__TargetField__c));

                // Filter equipment style options based on product
                if (conf.SBQQ__TargetField__c.equalsIgnoreCase('Equipment_Style__c')) {
                    Boolean isOptionValid = isEquipmentStyleOptionValid(
                        equipmentStyleValuesWithProduct,
                        currentProductName,
                        conf.SBQQ__TargetField__c,
                        ps.value
                    );
                    if (isOptionValid) {
                        picklistOptions.add(ps);
                    }
                } else {
                    picklistOptions.add(ps);
                }
            }

            conf.Picklist_Values__c = JSON.serialize(picklistOptions);
        }

        return attributeList;
    }

    /**
     * @description Update configuration attribute on QuoteLines
     * @param quoteLineId The QuoteLine ID
     * @param fieldName The field API name
     * @param fieldValue The new value
     * @param quoteId The Quote ID
     * @return String 'SUCCESS' or error message
     */
    @AuraEnabled
    public static String updateConfigAttribute(Id quoteLineId, String fieldName,
                                               String fieldValue, Id quoteId) {
        String queryString = 'SELECT Id, SBQQ__Quote__c, ' +
                           String.escapeSingleQuotes(fieldName) +
                           ' FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :quoteId';

        List<SBQQ__QuoteLine__c> quoteLines = Database.query(queryString);

        for (SBQQ__QuoteLine__c ql : quoteLines) {
            if (fieldName == 'Ownership__c') {
                ql.Ownership__c = fieldValue;
            } else if (ql.Id == quoteLineId) {
                ql.put(fieldName, fieldValue);
            }
        }

        try {
            update quoteLines;
            return 'SUCCESS';
        } catch (Exception e) {
            return e.getMessage();
        }
    }

    // ========================================================================
    // PUBLIC API - PRODUCT RULES
    // ========================================================================

    /**
     * @description Get product rules for configuration
     * @param productId The Product2 ID
     * @return List<SBQQ__ErrorCondition__c> Product rules
     */
    @AuraEnabled
    public static List<SBQQ__ErrorCondition__c> getProductRules(Id productId) {
        List<SBQQ__ErrorCondition__c> errorConditions = new List<SBQQ__ErrorCondition__c>();
        Set<Id> ruleIds = new Set<Id>();

        List<SBQQ__ConfigurationRule__c> configRules = [
            SELECT Id, SBQQ__Product__c, SBQQ__ProductRule__c
            FROM SBQQ__ConfigurationRule__c
            WHERE SBQQ__Product__c = :productId AND SBQQ__Active__c = true
        ];

        if (configRules.isEmpty()) {
            return errorConditions;
        }

        for (SBQQ__ConfigurationRule__c c : configRules) {
            ruleIds.add(c.SBQQ__ProductRule__c);
        }

        errorConditions = [
            SELECT Id, SBQQ__Rule__c, SBQQ__TestedField__c, SBQQ__Operator__c,
                   SBQQ__FilterType__c, SBQQ__FilterValue__c
            FROM SBQQ__ErrorCondition__c
            WHERE SBQQ__Rule__c IN :ruleIds AND SBQQ__Operator__c = 'equals'
        ];

        return errorConditions;
    }

    // ========================================================================
    // PRIVATE HELPER METHODS
    // ========================================================================

    /**
     * @description Validate equipment style option by product name
     * @param equipmentStyleMap Map of product to excluded styles
     * @param productName Current product name
     * @param targetField Target field name
     * @param equipmentStyleOption Option value to check
     * @return Boolean True if valid
     */
    private static Boolean isEquipmentStyleOptionValid(
        Map<String, Set<String>> equipmentStyleMap,
        String productName,
        String targetField,
        String equipmentStyleOption
    ) {
        if (equipmentStyleMap.containsKey(productName) &&
            targetField.equalsIgnoreCase('Equipment_Style__c') &&
            !equipmentStyleMap.get(productName).contains(equipmentStyleOption)) {
            return true;
        }
        return false;
    }

    // ========================================================================
    // INNER CLASSES
    // ========================================================================

    /**
     * @description Wrapper for picklist selection
     */
    public class PicklistSelect {
        @AuraEnabled public String value {get; set;}
        @AuraEnabled public String label {get; set;}
        @AuraEnabled public Boolean selected {get; set;}
    }
}
