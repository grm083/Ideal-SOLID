/**
 * @description QuoteProcurementUIService - UI presentation and wrapper layer
 *
 * This service handles all UI-specific logic including wrapper class construction,
 * picklist support, user permission checks, and Lightning component data preparation.
 *
 * Key Responsibilities:
 * - Wrapper class construction (ProductsWrapper, HeaderWrapper, etc.)
 * - Picklist value retrieval and conversion
 * - User permission checks
 * - UI-specific data formatting
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - UI Support
 */
public with sharing class QuoteProcurementUIService {

    // ========================================================================
    // PUBLIC API - PICKLIST SUPPORT
    // ========================================================================

    /**
     * @description Get material types for a material
     * Refactored from: getMaterialTypes() in QuoteProcurementController
     * @param material The material type
     * @return List<Map<String, String>> Material grade picklist values
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMaterialTypes(String material) {
        List<Map<String, String>> grades = new List<Map<String, String>>();
        grades.add(new Map<String, String>{'label' => '--None--', 'value' => ''});

        for (Material_type_Material_Grade_mapping__mdt m : [
            SELECT Material_Type__c, Material_Grade__c, Material_Grade_Code__c
            FROM Material_type_Material_Grade_mapping__mdt
            WHERE Material_Type__c = :material
        ]) {
            Map<String, String> grade = new Map<String, String>();
            grade.put('label', m.Material_Grade__c);
            grade.put('value', m.Material_Grade__c);
            grades.add(grade);
        }

        return grades;
    }

    /**
     * @description Get picklist schema for Quote Order service type
     * Refactored from: getPicklistSchema() in QuoteProcurementController
     * @return List<String> Service type picklist values
     */
    @AuraEnabled
    public static List<String> getPicklistSchema() {
        List<String> options = new List<String>();
        Schema.DescribeFieldResult fieldResult = Quote_Order__c.Service_Type__c.getDescribe();
        List<Schema.PicklistEntry> pList = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry p : pList) {
            options.add(p.getValue());
        }

        return options;
    }

    /**
     * @description Get equipment sizes for a product
     * Refactored from: getSizes() in QuoteProcurementController
     * @param productId The Product2 ID
     * @param returnAll Whether to return all sizes
     * @return Map<String, String> Size map
     */
    @AuraEnabled
    public static Map<String, String> getEquipmentSizes(Id productId, Boolean returnAll) {
        return QuoteFavoritesController.getSizes(productId, returnAll);
    }

    /**
     * @description Get SLA override reasons
     * Refactored from: getSLAOverrideReasons() in QuoteProcurementController
     * @return List<String> SLA override reasons
     */
    @AuraEnabled
    public static List<String> getSLAOverrideReasons() {
        List<String> reasonList = new List<String>();
        Schema.DescribeFieldResult fieldResult = SBQQ__QuoteLine__c.SLA_Override_Reason__c.getDescribe();
        List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                reasonList.add(entry.getValue());
            }
        }

        return reasonList;
    }

    /**
     * @description Get delivery override reasons
     * Refactored from: getDeliveryOverrideReasons() in QuoteProcurementController
     * @return List<String> Delivery override reasons
     */
    @AuraEnabled
    public static List<String> getDeliveryOverrideReasons() {
        List<String> deliveryOverrideReasons = new List<String>();

        for (Schema.PicklistEntry pick :
            SBQQ__QuoteLine__c.AAV_Delivery_Override_Reason__c.getDescribe().getPicklistValues()) {
            if (pick.isActive()) {
                deliveryOverrideReasons.add(pick.getValue());
            }
        }

        return deliveryOverrideReasons;
    }

    /**
     * @description Convert picklist label to API name
     * Refactored from: getPicklistAPIName() in QuoteProcurementController
     * @param labelName The picklist label
     * @return String The API value
     */
    public static String getPicklistAPIName(String labelName) {
        String result = labelName;
        Schema.DescribeFieldResult fieldResult = SBQQ__QuoteLine__c.Equipment_Size__c.getDescribe();
        List<Schema.PicklistEntry> values = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry v : values) {
            if (v.getLabel() == labelName) {
                result = v.getValue();
            }
        }

        return result;
    }

    /**
     * @description Convert picklist API value to label
     * Refactored from: getPicklistLabel() in QuoteProcurementController
     * @param apiValue The picklist API value
     * @return String The label
     */
    public static String getPicklistLabel(String apiValue) {
        String picklistLabel = '';
        Schema.DescribeFieldResult fieldResult = SBQQ__QuoteLine__c.Equipment_Size__c.getDescribe();
        Map<String, String> picklistValuesMap = new Map<String, String>();

        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            picklistValuesMap.put(entry.getValue(), entry.getLabel());
        }

        if (picklistValuesMap.containsKey(apiValue)) {
            picklistLabel = picklistValuesMap.get(apiValue);
        }

        return picklistLabel;
    }

    // ========================================================================
    // PUBLIC API - USER PERMISSIONS
    // ========================================================================

    /**
     * @description Check if user has Asset Availability permission
     * Refactored from: hasAssetAvailabilityPermission() in QuoteProcurementController
     * @return Boolean True if user has permission
     */
    @AuraEnabled
    public static Boolean hasAssetAvailabilityPermission() {
        return FeatureManagement.checkPermission(Constant_Util.ASSET_AVAILABILITY_CUSTOM_PERMISSION);
    }

    /**
     * @description Check Asset Availability permission with haul away check
     * Refactored from: hasAssetAvailabilityPermissionWithHaulAway() in QuoteProcurementController
     * @param caseId The Case ID
     * @return Boolean True if user has permission and not haul away
     */
    @AuraEnabled
    public static Boolean hasAssetAvailabilityPermissionWithHaulAway(Id caseId) {
        Boolean isHaul = HaulAwayService.getIsHaulAwayService(caseId);
        return FeatureManagement.checkPermission(Constant_Util.ASSET_AVAILABILITY_CUSTOM_PERMISSION) && !isHaul;
    }

    /**
     * @description Fetch user permissions for a quote
     * Refactored from: fetchUser() in QuoteProcurementController
     * @param quoteId The Quote ID
     * @return Map<String, Object> User permission map
     */
    @AuraEnabled
    public static Map<String, Object> fetchUserPermissions(Id quoteId) {
        Map<String, Object> userPermissionMap = new Map<String, Object>();

        User currentUser = [
            SELECT Id, Name, CPQ_Active_User__c, Update_Asset_Active_User__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        userPermissionMap.put('hasCPQAccess', currentUser.CPQ_Active_User__c);
        userPermissionMap.put('hasUpdateAssetAccess', currentUser.Update_Asset_Active_User__c);

        return userPermissionMap;
    }

    // ========================================================================
    // PUBLIC API - QUOTE STATUS
    // ========================================================================

    /**
     * @description Get quote status details
     * Delegates to ContextGetter
     * @param quoteId The Quote ID
     * @return SBQQ__Quote__c Quote with status details
     */
    @AuraEnabled
    public static SBQQ__Quote__c getQuoteStatusDetails(Id quoteId) {
        return QuoteProcurementContextGetter.getQuoteStatusDetails(quoteId);
    }

    /**
     * @description Get quote for orders
     * Delegates to ContextGetter
     * @param quoteId The Quote ID
     * @return SBQQ__Quote__c Quote for orders
     */
    @AuraEnabled
    public static SBQQ__Quote__c getQuoteForOrders(Id quoteId) {
        return QuoteProcurementContextGetter.getQuoteForOrders(quoteId);
    }

    /**
     * @description Update quote for orders
     * @param updatedQuote The updated Quote
     * @return Boolean True if successful
     */
    @AuraEnabled
    public static Boolean updateQuoteForOrders(SBQQ__Quote__c updatedQuote) {
        try {
            update updatedQuote;
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    // ========================================================================
    // PUBLIC API - QUOTELINE WRAPPERS
    // ========================================================================

    /**
     * @description Get QuoteLine wrapper for orders
     * Refactored from: getQuoteLineForOrdersWrapper() in QuoteProcurementController
     * @param quoteLineId The QuoteLine ID
     * @return qLineWrapper Wrapped QuoteLine
     */
    @AuraEnabled
    public static qLineWrapper getQuoteLineForOrdersWrapper(Id quoteLineId) {
        SBQQ__QuoteLine__c targetQuoteLine = [
            SELECT Id, Profile_Number__c, Landfill_Tickets__c, Special_Disposal_Description__c,
                   Service_Start_Time__c, Service_End_Time__c, Gate_Code__c,
                   Certificate_of_Destruction__c, Certificate_of_Disposal__c,
                   Restriction_Details__c, Location_Position_Name__c, SLA_Override_Comment__c,
                   SLA_Override_Reason__c, Equipment_Size__c, AssetId__r.Equipment_Size__c,
                   SBQQ__Quantity__c, AssetId__r.Quantity__c
            FROM SBQQ__QuoteLine__c
            WHERE Id = :quoteLineId
            LIMIT 1
        ];

        qLineWrapper wrap = new qLineWrapper();
        wrap.cQLine = targetQuoteLine;
        wrap.serviceStartTime = String.valueOf(targetQuoteLine.Service_Start_Time__c);
        wrap.serviceEndTime = String.valueOf(targetQuoteLine.Service_End_Time__c);

        // Check for delivery line
        List<SBQQ__QuoteLine__c> deliveryLine = [
            SELECT Id, SBQQ__Product__r.Name, SBQQ__Product__r.ProductCode, SBQQ__RequiredBy__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__RequiredBy__c = :quoteLineId
                  AND SBQQ__Product__r.Name = :Constant_Util.ServiceType_Delivery
            LIMIT 1
        ];

        if (!deliveryLine.isEmpty()) {
            wrap.hasDelivery = true;
        }

        String quoteLineEquipsize = getPicklistLabel(targetQuoteLine.Equipment_Size__c);

        // Check size/quantity differences
        if ((quoteLineEquipsize != targetQuoteLine.AssetId__r.Equipment_Size__c) ||
            (targetQuoteLine.SBQQ__Quantity__c > targetQuoteLine.AssetId__r.Quantity__c)) {
            wrap.hasDelivery = true;
        }

        return wrap;
    }

    /**
     * @description Get financial details for a QuoteLine
     * Refactored from: getQLFinancialDetail() in QuoteProcurementController
     * @param quoteLineId The QuoteLine ID
     * @return FinancialDetailWrapper Financial details
     */
    @AuraEnabled
    public static FinancialDetailWrapper getFinancialDetails(Id quoteLineId) {
        FinancialDetailWrapper fdWrapper = new FinancialDetailWrapper();

        try {
            List<SBQQ__QuoteLine__c> qlData = [
                SELECT Id, SBQQ__Quote__c, CompanyCategoryCode__c, ClientGLAccount__c,
                       ClientCostCenter__c, SBQQ__Quote__r.Quote_Only__c
                FROM SBQQ__QuoteLine__c
                WHERE Id = :quoteLineId
                LIMIT 1
            ];

            if (!qlData.isEmpty()) {
                fdWrapper.quoteOnly = qlData[0].SBQQ__Quote__r.Quote_Only__c;
                fdWrapper.companyCategory = qlData[0].CompanyCategoryCode__c;
                fdWrapper.clientGLNo = qlData[0].ClientGLAccount__c;
                fdWrapper.customerCostCenter = qlData[0].ClientCostCenter__c;
            }
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
        }

        return fdWrapper;
    }

    // ========================================================================
    // INNER CLASSES - WRAPPERS
    // ========================================================================

    /**
     * @description Wrapper for QuoteLine with service times
     */
    public class qLineWrapper {
        @AuraEnabled public SBQQ__QuoteLine__c cQLine {get; set;}
        @AuraEnabled public String serviceStartTime {get; set;}
        @AuraEnabled public String serviceEndTime {get; set;}
        @AuraEnabled public Boolean hasDelivery {get; set;}
    }

    /**
     * @description Wrapper for financial details
     */
    public class FinancialDetailWrapper {
        @AuraEnabled public Boolean quoteOnly {get; set;}
        @AuraEnabled public String companyCategory {get; set;}
        @AuraEnabled public String clientGLNo {get; set;}
        @AuraEnabled public String customerCostCenter {get; set;}
    }
}
