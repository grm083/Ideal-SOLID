/**
 * @description QuoteProcurementBusinessRuleService - Business logic and validation layer
 *
 * This service consolidates all business rule validations, error message generation,
 * and complex business logic for Quote Procurement operations. It provides consistent
 * validation across different quote stages and streamlines error handling.
 *
 * Key Responsibilities:
 * - Quote line validation for different stages (Product, Cost, Price Configured)
 * - Error message generation and assignment
 * - Business rule evaluation and application
 * - NTE (Not-To-Exceed) limit validation
 * - Vendor, MAS, and pricing validation
 *
 * Architecture:
 * - Centralized error message constants
 * - Stage-specific validation methods
 * - ValidationResult wrapper for standardized responses
 * - Integration with Business_Rule__c custom object
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - Business Logic
 */
public without sharing class QuoteProcurementBusinessRuleService {

    // ========================================================================
    // ERROR MESSAGE CONSTANTS
    // ========================================================================

    // Centralized error messages (previously scattered as static variables)
    public static final String ERR_VENDOR_MISSING = 'Vendor missing';
    public static final String ERR_MAS_LIBRARY_CODE = 'Missing MAS Library, Company Code';
    public static final String ERR_SETUP_COMMENT = 'Missing Setup Comment';
    public static final String ERR_OR_SETUP_COMMENT = ' or Setup Comment';
    public static final String ERR_COST_UOM_TYPE = 'Missing Cost Unit of Measure or Model Type';
    public static final String ERR_COST_MODEL_REBATE = 'Cost Model Type of Rebate must have a Cost of $0.00';
    public static final String ERR_COST_MISSING = 'Cost Missing';
    public static final String ERR_MANAGEMENT_FEE = 'Unit cost should be $0.00 and vendor name should start with WM Fee if product name is Management Fee ';
    public static final String ERR_VENDOR_INACTIVE = 'Selected vendor is not active ';
    public static final String ERR_WM_FEE_UNIT_COST = ' WM Fee charges should have a cost of 0$';
    public static final String ERR_MAS_ID_MISSING = 'MAS Unique ID is Missing';
    public static final String ERR_VCR_CODE_MISSING = 'Vendor requires VCR Code field';
    public static final String ERR_PRICE_MISSING = 'Price cannot be blank';
    public static final String ERR_PRICING_METHOD_MISSING = 'Price Model type (pricing method) must be specified';
    public static final String ERR_WM_FEE_LIST = ' WM Fee charges requires a price greater than 0';
    public static final String ERR_COST_MODEL_STP = 'You must enter 2 stepped cost if Cost model type is Stepped. ';
    public static final String ERR_PRICING_UNIT_STP = 'You must enter 2 stepped price if Price unit method is stepped. ';
    public static final String ERR_SCHEDULE_FREQ_MISSING = 'Scheduled service missing a service frequency (weekly, monthly, etc.)';
    public static final String ERR_SERVICE_DAYS_MISSING = 'Weekly scheduled service missing day(s) of the week';
    public static final String ERR_FREQ_INTERVAL_MISSING = 'Scheduled/SOC service missing frequency interval';
    public static final String ERR_OC_SHOULDNOT_HAVE_FREQ = 'On-call Service should not contain a Service Frequency or Frequency interval';
    public static final String ERR_END_DATE_VENDOR_COMMIT = 'End Dates must be greater than the vendor commit date';
    public static final String ERR_PRICE_UOM_MISSING = 'Missing price unit of measure';
    public static final String ERR_MANAGEMENT_FEE_PRICE = 'Price of Management Fee product option must be greater than $0.00';
    public static final String ERR_REMOVAL_SWAPOUT_SIZE = 'Please ensure your Swapout and Removal have the correct sizes';

    // Waste category set
    private static final Set<String> WASTE_CATEGORY_SET = new Set<String>{'Waste Stream', 'Waste Category'};

    // ========================================================================
    // PUBLIC API - QUOTELINE VALIDATION
    // ========================================================================

    /**
     * @description Validate QuoteLine and assign error message based on quote status
     * Refactored from: assignQuoteLineErrorMEssage() in QuoteProcurementController
     * @param quoteLine The QuoteLine to validate
     * @return String Error message (empty if valid)
     */
    public static String validateQuoteLine(SBQQ__QuoteLine__c quoteLine) {
        String errorMsg = '';

        if (quoteLine.SBQQ__Quote__r.SBQQ__Status__c == 'Draft') {
            errorMsg = validateProductConfiguredStage(quoteLine);
        } else if (quoteLine.SBQQ__Quote__r.SBQQ__Status__c == 'Product Configured') {
            errorMsg = validateProductConfiguredStage(quoteLine);
            if (String.isBlank(errorMsg)) {
                errorMsg = validateCostConfiguredStage(quoteLine);
            }
        } else if (quoteLine.SBQQ__Quote__r.SBQQ__Status__c == 'Cost Configured') {
            errorMsg = validateProductConfiguredStage(quoteLine);
            if (String.isBlank(errorMsg)) {
                errorMsg = validateCostConfiguredStage(quoteLine);
            }
            if (String.isBlank(errorMsg)) {
                errorMsg = validatePriceConfiguredStage(quoteLine);
            }
        }

        return errorMsg;
    }

    /**
     * @description Validate QuoteLine for Product Configured stage
     * Refactored from: vFStage() in QuoteProcurementController
     * @param quoteLine The QuoteLine to validate
     * @return String Error message (empty if valid)
     */
    public static String validateProductConfiguredStage(SBQQ__QuoteLine__c quoteLine) {
        String errorMsg = '';

        // Validate schedule frequency for SOC/SCH occurrence types
        if (quoteLine.Occurrence_Type__c == 'SOC' || quoteLine.Occurrence_Type__c == 'SCH') {
            if (String.isBlank(quoteLine.Schedule_Frequency__c)) {
                errorMsg = ERR_SCHEDULE_FREQ_MISSING;
            } else if (quoteLine.Schedule_Frequency__c == 'W' && String.isBlank(quoteLine.Service_Days__c)) {
                errorMsg = ERR_SERVICE_DAYS_MISSING;
            }
        }

        // Validate vendor status
        if (String.isBlank(errorMsg) && quoteLine.Vendor__c != null) {
            if ((quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' ||
                quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Exception' ||
                quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Correction' ||
                (quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' && quoteLine.SBQQ__Quote__r.STP__c == false)) ||
                (quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' && quoteLine.SBQQ__Quote__r.STP__c == true)) {

                if (quoteLine.Vendor__r.Status__c == 'Inactive') {
                    errorMsg = ERR_VENDOR_INACTIVE;
                }
            }
        }

        return errorMsg;
    }

    /**
     * @description Validate QuoteLine for Cost Configured stage
     * Refactored from: vSStage() in QuoteProcurementController
     * @param quoteLine The QuoteLine to validate
     * @return String Error message (empty if valid)
     */
    public static String validateCostConfiguredStage(SBQQ__QuoteLine__c quoteLine) {
        String errorMsg = '';

        // Check if quoteline changed for non-new service
        if (!QuoteLineServices.isQuoteLineChangedforNonNs(quoteLine)) {
            return errorMsg;
        }

        // Validate vendor
        if (quoteLine.Vendor__c == null) {
            return ERR_VENDOR_MISSING;
        }

        // Validate vendor status for non-STP quotes
        if ((quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' ||
            quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Exception' ||
            quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Correction' ||
            (quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' && quoteLine.SBQQ__Quote__r.STP__c == false)) &&
            quoteLine.Vendor__c != null) {

            if (quoteLine.Vendor__r.Status__c == 'Inactive') {
                return ERR_VENDOR_INACTIVE;
            }
        }

        String vendorName = quoteLine.Vendor__r.Name;
        String vendorId = quoteLine.Vendor__r.Parent_Vendor_ID__c;

        // Validate MAS requirements for WM vendors
        if (vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR) {
            if (String.isBlank(quoteLine.MASLibrary__c) || String.isBlank(quoteLine.MASCompany__c)) {
                errorMsg = ERR_MAS_LIBRARY_CODE;
            }

            // Validate setup comment
            if (String.isBlank(quoteLine.SetupComment__c) && quoteLine.DoNotCreateTaskGridTickets__c == false) {
                if (String.isNotBlank(errorMsg)) {
                    errorMsg += ERR_OR_SETUP_COMMENT;
                } else {
                    errorMsg = ERR_SETUP_COMMENT;
                }
            }
        }

        // Validate vendor commit date vs end date
        if (String.isBlank(errorMsg)) {
            Date vendorCommitDate = quoteLine.Vendor_Commit_Date__c;
            Date endDate = quoteLine.SBQQ__EndDate__c;

            if (vendorCommitDate != null && endDate != null && vendorCommitDate > endDate &&
                (quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' ||
                quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Quote')) {
                errorMsg = ERR_END_DATE_VENDOR_COMMIT;
            }
        }

        // Validate VCR Code for WM vendors on Quotes
        if (String.isBlank(errorMsg) &&
            (vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR) &&
            quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' &&
            vendorName != null &&
            String.isBlank(quoteLine.VCRCode__c)) {
            errorMsg = ERR_VCR_CODE_MISSING;
        }

        // Validate cost requirements
        if (String.isBlank(errorMsg)) {
            if (String.isBlank(quoteLine.Cost_Unit_of_Measure__c) || String.isBlank(quoteLine.CostModelType__c)) {
                errorMsg = ERR_COST_UOM_TYPE;
            } else {
                // Validate stepped pricing
                if (quoteLine.CostModelType__c == 'STP') {
                    if (quoteLine.CostPrice1__c == null || quoteLine.CostPrice2__c == null) {
                        errorMsg = ERR_COST_MODEL_STP;
                    }
                } else if (quoteLine.CostModelType__c == 'REB') {
                    if (quoteLine.SBQQ__UnitCost__c != 0) {
                        errorMsg = ERR_COST_MODEL_REBATE;
                    }
                } else {
                    if (quoteLine.SBQQ__UnitCost__c == null) {
                        errorMsg = ERR_COST_MISSING;
                    } else {
                        // Management Fee validation
                        if (quoteLine.SBQQ__ProductName__c == 'Management Fee') {
                            if (quoteLine.SBQQ__UnitCost__c != 0 || !vendorName.startsWithIgnoreCase('WM Fee')) {
                                errorMsg = ERR_MANAGEMENT_FEE;
                            }
                        } else if ((quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' ||
                                   quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Quote') &&
                                   !quoteLine.SBQQ__Quote__r.STP__c &&
                                   vendorName != null &&
                                   vendorName.startsWithIgnoreCase('WM Fee') &&
                                   quoteLine.SBQQ__UnitCost__c != 0) {
                            errorMsg = ERR_WM_FEE_UNIT_COST;
                        } else {
                            errorMsg = validateOccurrenceType(quoteLine);
                        }
                    }
                }
            }
        }

        // Validate removal and swapout size for commercial products
        if (String.isBlank(errorMsg) &&
            quoteLine.SBQQ__RequiredBy__r.SBQQ__ProductFamily__c == Constant_Util.COMMERCIAL &&
            quoteLine.SBQQ__Quote__r.SBQQ__Status__c == QuoteLineServices.STATUS_PRODUCT_CONFIGURED &&
            (quoteLine.SBQQ__Product__R.Name == Constant_Util.REMOVAL ||
             quoteLine.SBQQ__Product__r.Name == Constant_Util.SWAPOUT_PRODUCT) &&
            quoteLine.SBQQ__Quote__r.Case_record_Type__c != Constant_Util.New_Service_Case) {
            errorMsg = validateRemovalAndSwapoutSize(quoteLine);
        }

        return errorMsg;
    }

    /**
     * @description Validate QuoteLine for Price Configured stage
     * Refactored from: vTStage() in QuoteProcurementController
     * @param quoteLine The QuoteLine to validate
     * @return String Error message (empty if valid)
     */
    public static String validatePriceConfiguredStage(SBQQ__QuoteLine__c quoteLine) {
        String errorMsg = '';

        // Validate vendor status
        if ((quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' ||
            quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Exception' ||
            quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Correction' ||
            (quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' && quoteLine.SBQQ__Quote__r.STP__c == false)) &&
            quoteLine.Vendor__c != null) {

            if (quoteLine.Vendor__r.Status__c == 'Inactive') {
                errorMsg = ERR_VENDOR_INACTIVE;
            }
        }

        String vendorName = quoteLine.Vendor__r.Name;
        String vendorId = quoteLine.Vendor__r.Parent_Vendor_ID__c;

        // Validate vendor commit date vs end date
        if (String.isBlank(errorMsg)) {
            Date vendorCommitDate = quoteLine.Vendor_Commit_Date__c;
            Date endDate = quoteLine.SBQQ__EndDate__c;

            if (vendorCommitDate != null && endDate != null && vendorCommitDate > endDate &&
                (quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' ||
                quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Quote')) {
                errorMsg = ERR_END_DATE_VENDOR_COMMIT;
            }
        }

        // Validate MAS Unique ID for WM vendors on Amendments
        if (String.isBlank(errorMsg) &&
            (vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR) &&
            quoteLine.SBQQ__Quote__r.SBQQ__Type__c != 'Quote' &&
            quoteLine.MASCustomerUniqueId__c == null) {
            errorMsg = ERR_MAS_ID_MISSING;
        }

        // Validate VCR Code for WM vendors on Quotes
        if (String.isBlank(errorMsg) &&
            (vendorId == Constant_Util.WM_US_VENDOR || vendorId == Constant_Util.WM_CANADA_VENDOR) &&
            quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Quote' &&
            vendorName != null &&
            String.isBlank(quoteLine.VCRCode__c)) {
            errorMsg = ERR_VCR_CODE_MISSING;
        }

        // Validate pricing method for non-STP quotes
        if (String.isBlank(errorMsg) && !quoteLine.SBQQ__Quote__r.STP__c &&
            (quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' ||
             quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Quote') &&
            String.isBlank(quoteLine.SBQQ__PricingMethod__c)) {
            errorMsg = ERR_PRICING_METHOD_MISSING;
        }

        // Validate WM Fee list price
        if (String.isBlank(errorMsg) && vendorName != null && vendorName.startsWithIgnoreCase('WM Fee')) {
            if (quoteLine.SBQQ__ListPrice__c == 0) {
                errorMsg = ERR_WM_FEE_LIST;
            }
        }

        // Validate unit list price
        if (String.isBlank(errorMsg) &&
            (quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Amendment' ||
             quoteLine.SBQQ__Quote__r.SBQQ__Type__c == 'Quote') &&
            !quoteLine.SBQQ__Quote__r.STP__c &&
            quoteLine.SBQQ__ListPrice__c == null &&
            quoteLine.PricingUnitMethod__c != 'STP') {
            errorMsg = ERR_PRICE_MISSING;
        }

        // Validate price UOM
        if (String.isBlank(errorMsg) && String.isBlank(quoteLine.PriceUOM__c)) {
            errorMsg = ERR_PRICE_UOM_MISSING;
        } else if (String.isBlank(errorMsg) &&
                   quoteLine.SBQQ__ProductName__c == 'Management Fee' &&
                   (quoteLine.SBQQ__ListPrice__c == null || quoteLine.SBQQ__ListPrice__c <= 0)) {
            errorMsg = ERR_MANAGEMENT_FEE_PRICE;
        }

        // Validate stepped pricing
        if (String.isBlank(errorMsg) && quoteLine.SBQQ__PricingMethod__c == 'STP') {
            if (quoteLine.PricePrice1__c == null || quoteLine.PricePrice2__c == null) {
                errorMsg = ERR_PRICING_UNIT_STP;
            }
        }

        return errorMsg;
    }

    /**
     * @description Validate occurrence type and frequency
     * Refactored from: validateOccurence() in QuoteProcurementController
     * @param quoteLine The QuoteLine to validate
     * @return String Error message (empty if valid)
     */
    public static String validateOccurrenceType(SBQQ__QuoteLine__c quoteLine) {
        String errorMsg = '';

        if (quoteLine.Occurrence_Type__c == 'SOC' || quoteLine.Occurrence_Type__c == 'SCH') {
            if (quoteLine.Schedule_Frequency__c == 'D' ||
                quoteLine.Schedule_Frequency__c == 'M' ||
                quoteLine.Schedule_Frequency__c == 'Y' ||
                quoteLine.Schedule_Frequency__c == 'W') {

                if (String.isBlank(quoteLine.Frequency_Interval__c)) {
                    errorMsg = ERR_FREQ_INTERVAL_MISSING;
                }
            }
        } else if (quoteLine.Occurrence_Type__c == 'OC') {
            if (String.isNotBlank(quoteLine.Schedule_Frequency__c) ||
                String.isNotBlank(quoteLine.Frequency_Interval__c)) {
                errorMsg = ERR_OC_SHOULDNOT_HAVE_FREQ;
            }
        }

        return errorMsg;
    }

    /**
     * @description Validate removal and swapout equipment size
     * Refactored from: validateRemovalAndSwapoutSize() in QuoteProcurementController
     * @param quoteLine The QuoteLine to validate
     * @return String Error message (empty if valid)
     */
    public static String validateRemovalAndSwapoutSize(SBQQ__QuoteLine__c quoteLine) {
        String errorMsg = '';

        // Get equipment size picklist entries
        List<Schema.PicklistEntry> equipmentSizeEntries =
            Schema.SObjectType.SBQQ__QuoteLine__c.fields.Equipment_Size__c.getPicklistValues();

        // Check if parent is commercial family
        if (quoteLine.SBQQ__RequiredBy__c != null &&
            quoteLine.SBQQ__RequiredBy__r.SBQQ__ProductFamily__c == Constant_Util.COMMERCIAL) {

            String convertedAssetSize = AssetQuoteProcurementController.getPicklistEntryByLabel(
                equipmentSizeEntries,
                quoteLine.SBQQ__RequiredBy__r.AssetId__r.Equipment_Size__c
            );

            // Check if size changed for this bundle
            if (quoteLine.SBQQ__RequiredBy__r.Equipment_Size__c != convertedAssetSize) {
                // Check if size for removal or swapout is not the asset size
                if (quoteLine.Equipment_Size__c != convertedAssetSize) {
                    errorMsg = ERR_REMOVAL_SWAPOUT_SIZE;
                }
            }
        }

        return errorMsg;
    }

    // ========================================================================
    // PUBLIC API - BUSINESS RULE EVALUATION
    // ========================================================================

    /**
     * @description Determine if price review should be bypassed
     * Refactored from: bypassPriceReview() in QuoteProcurementController
     * @param quoteLineId The QuoteLine ID
     * @param masLibrary The MAS Library code
     * @return Boolean True if price review should be bypassed
     */
    public static Boolean shouldBypassPriceReview(Id quoteLineId, String masLibrary) {
        Boolean bypassReviewFlag = false;

        List<SBQQ__QuoteLine__c> quoteLineList = [SELECT Id, SBQQ__RequiredBy__c,
                                                        BypassPriceReview__c, sCode__c,
                                                        Vendor__r.Parent_Vendor_ID__c,
                                                        SBQQ__Quote__r.Name, Name,
                                                        (SELECT id, AAV_APIRequestOutput__c
                                                         FROM Asset_Availabilities__r)
                                                  FROM SBQQ__QuoteLine__c
                                                  WHERE Id = :quoteLineId];

        for (SBQQ__QuoteLine__c quoteLine : quoteLineList) {
            if (quoteLine.SBQQ__RequiredBy__c == null) {
                bypassReviewFlag = quoteLine.BypassPriceReview__c;

                for (AAV_Asset_Availability__c availabilityOutput : quoteLine.Asset_Availabilities__r) {
                    if (availabilityOutput != null) {
                        try {
                            AvailabilityAPIJsonDeserialize availabilityData =
                                AvailabilityAPIJsonDeserialize.parse(availabilityOutput.AAV_APIRequestOutput__c);

                            if (availabilityData.data != null &&
                                availabilityData.data.suppliers != null &&
                                availabilityData.data.suppliers.size() > 0) {

                                AvailabilityAPIJsonDeserialize.cls_suppliers supplier =
                                    availabilityData.data.suppliers[0];

                                if (supplier != null && supplier.contractType != null) {
                                    return PricingRequestSTPProcess.getBypassPriceReview(
                                        supplier.contractType,
                                        quoteLine.Vendor__r.Parent_Vendor_ID__c,
                                        masLibrary
                                    );
                                }
                            }
                        } catch (Exception ex) {
                            String appName = 'QuoteProcurementBusinessRuleService - Bypass Review ' +
                                           'Availability parser failed for Quote ' + quoteLine.SBQQ__Quote__r.Name +
                                           ' QuoteLine ' + quoteLine.Name;
                            STPExceptionUtil.setStepByStepExceptionObj('shouldBypassPriceReview', appName, ex.getMessage());
                        }
                    }
                }

                if (quoteLine.sCode__c == 'FRCH') {
                    return PricingRequestSTPProcess.getBypassPriceReview(
                        'WM Franchise',
                        quoteLine.Vendor__r.Parent_Vendor_ID__c,
                        masLibrary
                    );
                }
            }
        }

        return bypassReviewFlag;
    }

    /**
     * @description Get business rules for a quote
     * Refactored from: quoteBusinessRules() in QuoteProcurementController
     * @param quoteId The Quote ID
     * @param caseType The case type
     * @param subType The case sub-type
     * @return Business_Rule__c The limiting business rule
     */
    public static Business_Rule__c getQuoteBusinessRules(Id quoteId, String caseType, String subType) {
        Business_Rule__c limitingRule = new Business_Rule__c();

        SBQQ__Quote__c quote = QuoteProcurementContextGetter.getQuoteById(quoteId);

        List<Business_Rule__c> businessRuleList =
            QuoteProcurementContextGetter.getQuoteBusinessRules(
                quote.SBQQ__Account__r.ParentId,
                caseType,
                subType
            );

        for (Business_Rule__c br : businessRuleList) {
            // Most to least selective
            if (br.Service__c == subType) {
                limitingRule = br;
            } else if (br.Service__c == null) {
                limitingRule = br;
            }
        }

        return limitingRule;
    }

    // ========================================================================
    // PUBLIC API - NTE VALIDATION
    // ========================================================================

    /**
     * @description Validate NTE (Not-To-Exceed) limits for quote lines
     * Refactored from: showErrorWrapper() in QuoteProcurementController
     * @param quoteId The Quote ID
     * @param parentQLineIds List of parent QuoteLine IDs
     * @return List<NTEWrapper> List of NTE violations
     */
    public static List<NTEWrapper> validateNTELimits(Id quoteId, List<Id> parentQLineIds) {
        List<NTEWrapper> nWrapperList = new List<NTEWrapper>();
        List<SBQQ__QuoteLine__c> updateQList = new List<SBQQ__QuoteLine__c>();
        Boolean nteLimitExceeded = false;
        Boolean updateFlagNTE = false;

        // Get quotes with quote lines
        List<SBQQ__Quote__c> quotesWithQuoteLinesList = [
            SELECT Id, Case_Number__c, is_NTE_Quote__c, Project__c, Case_record_Type__c,
                   Business_Rule__c, SBQQ__Status__c,
                   (SELECT id, Name, ErrorComments__c, Occurrence_Type__c, Schedule_Frequency__c,
                           Service_Days__c, SBQQ__Cost__c, Vendor__c, Equipment_Size__c,
                           MaterialGrade__c, SBQQ__RequiredBy__c,
                           SBQQ__RequiredBy__r.SBQQ__ProductFamily__c,
                           SBQQ__Product__R.Name, SBQQ__RequiredBy__r.Equipment_Size__c,
                           SBQQ__ListPrice__c, NTE_amount_on_SR__c, SBQQ__ProductName__c,
                           SBQQ__MaximumPrice__c, SBQQ__RequiredBy__r.AssetId__r.Equipment_Size__c,
                           AssetId__c
                    FROM SBQQ__LineItems__r
                    WHERE SBQQ__ProductFamily__c NOT IN :WASTE_CATEGORY_SET
                          AND Bypass_Acorn_Integration__c = false
                          AND SBQQ__RequiredBy__c IN :parentQLineIds)
            FROM SBQQ__Quote__c
            WHERE id = :quoteId
        ];

        if (quotesWithQuoteLinesList.isEmpty()) {
            return nWrapperList;
        }

        // Get business rule for NTE
        Business_Rule__c brRules = GetBRQuotePriorityNTECtrl.getBRNTEPriority(quoteId);

        Boolean brWithNTE = false;
        List<service_approver__c> srList = new List<service_approver__c>();

        if (brRules != null) {
            Id reqInfoRecTypeId = Schema.SObjectType.Business_Rule__c
                .getRecordTypeInfosByName().get('Approval').getRecordTypeId();

            if (reqInfoRecTypeId.equals(brRules.RecordTypeId)) {
                if (brRules.NTE_Rules__c && !brRules.No_Approval_Required__c) {
                    brWithNTE = true;
                    srList = [SELECT id, NTE_Amount__c, Service_Type__c, RecordType.Name, Active__c
                             FROM service_approver__c
                             WHERE RecordType.Name = 'NTE Approval'
                                   AND Active__c = true
                                   AND Business_Rule__c = :brRules.Id];
                }
            }
        }

        // Validate NTE limits
        if (!srList.isEmpty()) {
            for (SBQQ__Quote__c qt : quotesWithQuoteLinesList) {
                for (SBQQ__QuoteLine__c qLine : qt.SBQQ__LineItems__r) {
                    for (Service_approver__c sr : srList) {
                        if ((qt.SBQQ__Status__c == 'Cost Configured' ||
                            qt.SBQQ__Status__c == 'Product Configured' ||
                            qt.SBQQ__Status__c == 'Price Configured') &&
                            qLine.SBQQ__ListPrice__c != null &&
                            qLine.SBQQ__ListPrice__c > sr.NTE_Amount__c &&
                            qLine.SBQQ__ProductName__c == sr.Service_Type__c) {

                            nteLimitExceeded = true;
                            NTEWrapper nWrapper = new NTEWrapper();
                            nWrapper.showMessage = nteLimitExceeded;
                            nWrapper.qlineDetails = qLine.Name;
                            nWrapper.qlineId = qLine.SBQQ__RequiredBy__c;
                            nWrapperList.add(nWrapper);

                            if (qline.NTE_amount_on_SR__c != sr.NTE_Amount__c) {
                                qline.NTE_amount_on_SR__c = sr.NTE_Amount__c;
                                updateFlagNTE = true;
                                updateQList.add(qline);
                            }
                        }
                    }
                }

                // Update quote NTE flag
                if ((qt.SBQQ__Status__c == 'Cost Configured' ||
                    qt.SBQQ__Status__c == 'Product Configured' ||
                    qt.SBQQ__Status__c == 'Price Configured') && nteLimitExceeded) {

                    if (qt.is_NTE_Quote__c == false) {
                        qt.is_NTE_Quote__c = true;
                        update qt;
                    }
                } else {
                    if (qt.is_NTE_Quote__c == true) {
                        qt.is_NTE_Quote__c = false;
                        update qt;
                    }
                }
            }

            if (updateFlagNTE && nteLimitExceeded) {
                update updateQList;
            }
        }

        return nWrapperList;
    }

    // ========================================================================
    // INNER CLASSES
    // ========================================================================

    /**
     * @description Wrapper for validation results
     */
    public class ValidationResult {
        @AuraEnabled public Boolean isValid {get; set;}
        @AuraEnabled public List<String> errorMessages {get; set;}
        @AuraEnabled public String iconName {get; set;}

        public ValidationResult() {
            this.isValid = true;
            this.errorMessages = new List<String>();
            this.iconName = 'utility:check';
        }
    }

    /**
     * @description Wrapper for NTE validation results
     */
    public class NTEWrapper {
        @AuraEnabled public Boolean showMessage {get; set;}
        @AuraEnabled public String qlineDetails {get; set;}
        @AuraEnabled public String qlineId {get; set;}
    }
}
