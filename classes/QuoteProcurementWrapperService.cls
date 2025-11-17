/**
 * @description QuoteProcurementWrapperService - Handles UI wrapper building operations
 *
 * This service manages complex wrapper building operations for Lightning components:
 * - Building ProductsWrapper from quote data
 * - Creating nested wrapper structures (Header, MAS, WorkOrder, Detail)
 * - Retrieving case quotes with their wrapper data
 *
 * Key Responsibilities:
 * - Query quotes and quote lines for wrapper building
 * - Build complex nested wrapper structures for UI display
 * - Handle MAS information, work orders, and detail records
 * - Integrate with external services (Acorn, HaulAway, Availability)
 *
 * Architecture:
 * - Uses QuoteProcurementController helper methods for SOQL queries
 * - Integrates with multiple external services and utilities
 * - Builds wrapper classes defined in QuoteProcurementController
 * - Supports caseQuoteModalLWC and related components
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - UI Wrapper Management
 */
public with sharing class QuoteProcurementWrapperService {

    // ========================================================================
    // PUBLIC API - WRAPPER BUILDING
    // ========================================================================

    /**
     * @description Get all quotes for a case with their wrapper data
     * Refactored from: getCaseQuotes() in QuoteProcurementController
     *
     * @param caseId The Case ID
     * @return List<QuoteProcurementController.ProductsWrapper> List of wrapper data for each quote
     */
    @AuraEnabled
    public static List<QuoteProcurementController.ProductsWrapper> getCaseQuotes(String caseId) {
        System.debug('QuoteProcurementWrapperService.getCaseQuotes - Start: ' + caseId);

        try {
            List<QuoteProcurementController.ProductsWrapper> caseProducts =
                new List<QuoteProcurementController.ProductsWrapper>();

            // Query all quotes for the case
            List<SBQQ__Quote__c> caseQuotes = [
                SELECT Id
                FROM SBQQ__Quote__c
                WHERE SBQQ__Opportunity2__r.Case__c = :caseId
            ];

            System.debug('Found ' + caseQuotes.size() + ' quotes for case');

            // Build wrapper for each quote
            for (SBQQ__Quote__c q : caseQuotes) {
                QuoteProcurementController.ProductsWrapper pw = buildWrapper(q.Id);
                caseProducts.add(pw);
            }

            System.debug('Built wrappers for ' + caseProducts.size() + ' quotes');
            return caseProducts;

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error in getCaseQuotes: ' + ex.getMessage());
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            throw new AuraHandledException('Failed to retrieve case quotes: ' + ex.getMessage());
        }
    }

    /**
     * @description Build complete ProductsWrapper from quote data
     * Refactored from: buildWrapper() in QuoteProcurementController
     *
     * Creates a complex nested wrapper structure containing:
     * - Header records (quote lines)
     * - MAS information
     * - Work orders
     * - Detail records (child quote lines)
     *
     * @param quoteId The Quote ID
     * @return QuoteProcurementController.ProductsWrapper Complete wrapper with all nested data
     */
    @AuraEnabled
    public static QuoteProcurementController.ProductsWrapper buildWrapper(String quoteId) {
        System.debug('QuoteProcurementWrapperService.buildWrapper - Start: ' + quoteId);

        try {
            // Query parent quote for company details
            SBQQ__Quote__c parentQuote = [
                SELECT Id, SBQQ__Account__r.Parent.AccountNumber
                FROM SBQQ__Quote__c
                WHERE Id = :quoteId
            ];

            // Get company categories map from Acorn
            Map<String, String> companyCategoriesMap =
                AcornCompanyDetails.getAcornCCMap(parentQuote.SBQQ__Account__r.Parent.AccountNumber);

            // Initialize wrapper with default values
            QuoteProcurementController.ProductsWrapper pw = new QuoteProcurementController.ProductsWrapper();
            pw.disableMAS = true;
            pw.disableCost = true;
            pw.disablePrice = true;

            // Get header records (parent quote lines)
            List<SBQQ__QuoteLine__c> headerRecords = QuoteProcurementController.getQuoteProducts(quoteId);
            Map<Id, Boolean> bundleStatusMap = PricingRequestSTPProcess.getQuoteProductDetail(quoteId);

            // If no headers, return empty wrapper with quote ID
            if (headerRecords == null || headerRecords.size() == 0) {
                pw.singleQuoteId = quoteId;
                return pw;
            }

            System.debug('Processing ' + headerRecords.size() + ' header records');

            // Build header wrappers
            List<QuoteProcurementController.HeaderWrapper> confProducts =
                new List<QuoteProcurementController.HeaderWrapper>();

            for (SBQQ__QuoteLine__c header : headerRecords) {
                QuoteProcurementController.HeaderWrapper prod =
                    buildHeaderWrapper(header, companyCategoriesMap, bundleStatusMap);
                confProducts.add(prod);
            }

            pw.configuredProducts = confProducts;

            System.debug('Built wrapper with ' + confProducts.size() + ' configured products');
            return pw;

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error in buildWrapper: ' + ex.getMessage());
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            throw new AuraHandledException('Failed to build wrapper: ' + ex.getMessage());
        }
    }

    /**
     * @description Build simplified ProductsWrapper for quote overview
     * Refactored from: buildQuoteWrapper() in QuoteProcurementController
     *
     * Creates a simpler wrapper structure for quote overview display:
     * - Header records with key properties
     * - Material type extraction from waste stream
     * - No MAS, work orders, or detail wrappers
     *
     * @param quoteId The Quote ID
     * @return QuoteProcurementController.ProductsWrapper Wrapper with configured products
     */
    @AuraEnabled
    public static QuoteProcurementController.ProductsWrapper buildQuoteWrapper(String quoteId) {
        System.debug('QuoteProcurementWrapperService.buildQuoteWrapper - Start: ' + quoteId);

        try {
            // Query parent quote with extended quote and account information
            SBQQ__Quote__c parentQuote = [
                SELECT Id, SBQQ__Account__r.Parent.AccountNumber,
                    SBQQ__Account__r.ParentId, Project__c, SBQQ__Account__c,
                    SBQQ__Account__r.Division__c, SBQQ__Account__r.Geography__c,
                    SBQQ__Account__r.Location_Type__c, SBQQ__Account__r.Brand__c,
                    Case_Sub_Type__c, Case_Reason__c, Case_Type__c,
                    SBQQ__Opportunity2__r.Case__r.Origin,
                    SBQQ__Opportunity2__r.Case__r.Recordtype.Name,
                    toLabel(SBQQ__Status__c),
                    SBQQ__PrimaryContact__r.Name,
                    SBQQ__PrimaryContact__c
                FROM SBQQ__Quote__c
                WHERE Id = :quoteId
            ];

            QuoteProcurementController.ProductsWrapper pw = new QuoteProcurementController.ProductsWrapper();

            // Query header records (parent quote lines) - TCS-SDT-31625: Added SBQQ__Quantity__c field
            List<SBQQ__QuoteLine__c> headerRecords = [
                SELECT SBQQ__Quote__r.Case_Type__c, SBQQ__Quote__r.Name, SBQQ__Quote__c,
                    MaterialGrade__c, SBQQ__ProductName__c, toLabel(Duration__c),
                    Vendor__r.Name, Vendor__r.Parent_Vendor_Id__c,
                    toLabel(Equipment_Size__c), SBQQ__StartDate__c, SBQQ__EndDate__c,
                    Occurrence_Type__c, SBQQ__Quantity__c, AssetId__c, CompanyCategoryName__c,
                    SBQQ__Product__c, SBQQ__ProductFamily__c, SBQQ__ProductCode__c
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__Quote__c = :quoteId
                AND SBQQ__RequiredBy__c = null
            ];

            List<QuoteProcurementController.HeaderWrapper> confProducts =
                new List<QuoteProcurementController.HeaderWrapper>();

            for (SBQQ__QuoteLine__c header : headerRecords) {
                QuoteProcurementController.HeaderWrapper prod =
                    buildQuoteOverviewHeader(header, parentQuote);
                confProducts.add(prod);
            }

            pw.configuredProducts = confProducts;

            System.debug('Built quote wrapper with ' + confProducts.size() + ' configured products');
            return pw;

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error in buildQuoteWrapper: ' + ex.getMessage());
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            throw new AuraHandledException('Failed to build quote wrapper: ' + ex.getMessage());
        }
    }

    // ========================================================================
    // PRIVATE HELPER METHODS
    // ========================================================================

    /**
     * @description Build simplified HeaderWrapper for quote overview
     * @param header The parent quote line
     * @param parentQuote The parent quote with extended information
     * @return QuoteProcurementController.HeaderWrapper The built header wrapper
     */
    private static QuoteProcurementController.HeaderWrapper buildQuoteOverviewHeader(
        SBQQ__QuoteLine__c header,
        SBQQ__Quote__c parentQuote
    ) {
        QuoteProcurementController.HeaderWrapper prod = new QuoteProcurementController.HeaderWrapper();

        // Quote and case information
        prod.caseType = parentQuote.Case_Type__c;
        prod.caseSubType = parentQuote.Case_Sub_Type__c;
        prod.caseReason = parentQuote.Case_Reason__c;
        prod.caseOrigin = parentQuote.SBQQ__Opportunity2__r.Case__r.Origin;
        prod.caseRecordType = parentQuote.SBQQ__Opportunity2__r.Case__r.Recordtype.Name;
        prod.quoteName = header.SBQQ__Quote__r.Name;
        prod.quoteStatus = parentQuote.SBQQ__Status__c;
        prod.quoteID = header.SBQQ__Quote__c;

        // Product information
        prod.productId = header.SBQQ__Product__c;
        prod.productFamily = header.SBQQ__ProductFamily__c;
        prod.equipmentType = header.SBQQ__ProductName__c;
        prod.equipmentTypeCode = header.SBQQ__ProductCode__c; // SDT-38040-MAA
        prod.equipmentSize = header.Equipment_Size__c;
        prod.quantity = header.SBQQ__Quantity__c;
        prod.duration = header.Duration__c;
        prod.selectedMaterialGrade = header.MaterialGrade__c; // SDT-37527
        prod.occurrenceType = header.Occurrence_Type__c;

        // Dates
        prod.startDate = header.SBQQ__StartDate__c;
        prod.endDate = header.SBQQ__EndDate__c;

        // Contact information
        prod.primaryContact = parentQuote.SBQQ__PrimaryContact__r.Name;
        prod.contactID = parentQuote.SBQQ__PrimaryContact__c;

        // Account information
        prod.clientId = parentQuote.SBQQ__Account__r.ParentId;
        prod.locationId = parentQuote.SBQQ__Account__c;
        prod.locationDivision = parentQuote.SBQQ__Account__r.Division__c;
        prod.locationGeography = parentQuote.SBQQ__Account__r.Geography__c;
        prod.locationType = parentQuote.SBQQ__Account__r.Location_Type__c;
        prod.locationBrand = parentQuote.SBQQ__Account__r.Brand__c;

        // Vendor information
        prod.vendorName = header.Vendor__r.Name;
        prod.parentVendorId = header.Vendor__r.Parent_Vendor_Id__c;

        // Other fields
        prod.projectCodeId = parentQuote.Project__c;
        prod.assetId = header.AssetId__c;
        prod.companyCategoryName = header.CompanyCategoryName__c;

        // Query and set material type from waste stream
        List<SBQQ__QuoteLine__c> detailRecords = [
            SELECT SBQQ__ProductName__c, SBQQ__ProductCode__c, SBQQ__ProductFamily__c
            FROM SBQQ__QuoteLine__c
            WHERE (SBQQ__RequiredBy__c = :header.Id OR SBQQ__RequiredBy__r.SBQQ__RequiredBy__c = :header.Id)
            AND SBQQ__ProductFamily__c != 'Waste Category'
        ];

        for (SBQQ__QuoteLine__c detail : detailRecords) {
            // Immediately store the material type to the header record and skip to next iteration
            if (detail.SBQQ__ProductFamily__c == 'Waste Stream') {
                prod.materialType = detail.SBQQ__ProductName__c;
                prod.materialTypeCode = detail.SBQQ__ProductCode__c;
                break;
            }
        }

        return prod;
    }

    /**
     * @description Build HeaderWrapper from quote line data
     * @param header The parent quote line
     * @param companyCategoriesMap Company categories mapping
     * @param bundleStatusMap Bundle procurement status mapping
     * @return QuoteProcurementController.HeaderWrapper The built header wrapper
     */
    private static QuoteProcurementController.HeaderWrapper buildHeaderWrapper(
        SBQQ__QuoteLine__c header,
        Map<String, String> companyCategoriesMap,
        Map<Id, Boolean> bundleStatusMap
    ) {
        QuoteProcurementController.HeaderWrapper prod = new QuoteProcurementController.HeaderWrapper();

        // Store key attributes related to the product
        prod.quoteOnlyCopyOf = header.Quote_Only_Copy_of__c;
        prod.caseType = header.SBQQ__Quote__r.Case_Type__c;
        prod.caseRecordType = header.SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.Recordtype.Name;
        prod.parentId = header.Id;
        prod.locationId = header.Account__c;
        prod.quoteLineName = header.Name;
        prod.companyCategories = companyCategoriesMap;
        prod.productId = header.SBQQ__Product__c;
        prod.equipmentType = header.SBQQ__ProductName__c;
        prod.equipmentTypeCode = header.SBQQ__ProductCode__c;
        prod.equipmentSize = header.Equipment_Size__c;
        prod.duration = header.Duration__c;
        prod.startDate = header.SBQQ__StartDate__c;

        // Determine SLA date
        DateTime slaDateTime = QuoteFavoritesController.determineSLA(header.Id);
        if (slaDateTime != null) {
            prod.originalSLAstartDate = slaDateTime.date();
        }

        prod.slaOverrideReason = header.SLA_Override_Reason__c;
        prod.slaOverrideComment = header.SLA_Override_Comment__c;
        prod.endDate = header.SBQQ__EndDate__c;
        prod.companyCategory = header.CompanyCategoryCode__c;
        prod.selectedMaterialGrade = header.MaterialGrade__c;
        prod.companyCategoryName = header.CompanyCategoryName__c;

        // Vendor information
        prod.vendorId = header.Vendor__c;
        prod.vendorName = header.Vendor__r.Name;
        prod.vendorNumber = header.Vendor__r.AccountNumber;
        prod.vendorBU = header.Vendor__r.Vendor_Business_Unit__c;
        prod.vendorFacilityCode = header.Vendor__r.FacilityCode__c;
        prod.parentVendorId = header.Vendor__r.Parent_Vendor_Id__c;

        // Quote information
        prod.quoteStatus = header.SBQQ__Quote__r.SBQQ__Status__c;
        prod.quoteName = header.SBQQ__Quote__r.Name;
        prod.quoteIdNav = '/' + header.SBQQ__Quote__c;
        prod.sCode = header.sCode__c;
        prod.monthlyScheduleDetails = QuoteLineServices.generateMonthlyScheduleDetails(header);
        prod.lineFrequency = header.Service_Schedule__c;
        prod.quoteLineNumber = header.SBQQ__Number__c;
        prod.wasteDescription = header.Description_of_Waste__c;
        prod.Quantity = header.SBQQ__Quantity__c;
        prod.quantityEditable = header.SBQQ__Product__r.SBQQ__QuantityEditable__c;

        // Additional quote fields
        prod.quoteID = header.SBQQ__Quote__c;
        prod.primaryContact = header.SBQQ__Quote__r.SBQQ__PrimaryContact__r.Name;
        prod.contactID = header.SBQQ__Quote__r.SBQQ__PrimaryContact__r.Id;
        prod.occurrenceType = header.Occurrence_Type__c;
        prod.productFamily = header.SBQQ__ProductFamily__c;
        prod.bundleProcuredStatus = header.BundleProcuredStatus__c;
        prod.deliveryOverrideReason = header.AAV_Delivery_Override_Reason__c;
        prod.deliveryOverrideComment = header.AAV_Delivery_Override_Comment__c;
        prod.serviceOverrideReason = header.AAV_Service_Override_Reason__c;
        prod.serviceOverrideComment = header.AAV_Service_Day_Override_Comment__c;
        prod.nteWarnning = false;
        prod.nteWarnningMessage = '';

        // Haul away service check
        Id caseId = header.SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__c;
        prod.isHaulAway = HaulAwayService.getIsHaulAwayService(caseId);

        // Certificate of Destruction/Disposal
        if (header.Certificate_of_Destruction__c == true || header.Certificate_of_Disposal__c == true) {
            prod.isCOD = true;
        } else {
            prod.isCOD = false;
        }

        // Vendor flags
        if (header.Vendor__r.Contact_Manually_Vendor__c == true) {
            prod.vendorManualDispatch = 'Yes';
        } else {
            prod.vendorManualDispatch = 'No';
        }

        if (header.Vendor__r.Prepayment_Required__c == 'Yes' && header.Vendor__r.Prepayment_Required__c != null) {
            prod.vendorPrepayment = 'Yes';
        } else {
            prod.vendorPrepayment = 'No';
        }

        prod.quoteOnly = header.SBQQ__Quote__r.Quote_Only__c;
        prod.quoteType = header.SBQQ__Quote__r.SBQQ__Type__c;
        prod.customerApproval = header.CustomerApproval__c;

        // Build MAS wrapper
        prod.MAS = buildMASWrapper(header);

        // Build work orders
        prod.workOrders = buildWorkOrderWrappers(header.Id);

        // Build detail records and handle material type
        String costCompareMessage = buildDetailWrappers(header.Id, prod);

        // Set procurement error message
        prod.procurementErrorMessage = bundleStatusMap.get(header.Id) == true
            ? ''
            : header.ProcurementErrorMessage__c;

        // Add cost compare message if present
        if (!String.isEmpty(costCompareMessage)) {
            if (prod.procurementErrorMessage == Constant_Util.QLI_PROCURMENT_SUCCESS) {
                prod.procurementErrorMessage = costCompareMessage;
            } else {
                prod.procurementErrorMessage += '\n' + costCompareMessage;
            }
        }

        // Add availability message
        if (header.Availability_Flag__c != null) {
            prod.procurementErrorMessage =
                AAV_AvailabilityUtility.getAvailabilityBellIconMessage(header, prod.procurementErrorMessage);
            System.debug('Test Availability MSG ' + prod.procurementErrorMessage);
        }

        return prod;
    }

    /**
     * @description Build MASWrapper from quote line data
     * @param header The quote line containing MAS information
     * @return QuoteProcurementController.MASWrapper The built MAS wrapper
     */
    private static QuoteProcurementController.MASWrapper buildMASWrapper(SBQQ__QuoteLine__c header) {
        QuoteProcurementController.MASWrapper prodMAS = new QuoteProcurementController.MASWrapper();
        prodMAS.MASLibrary = header.MASLibrary__c;
        prodMAS.MASCompany = header.MASCompany__c;
        prodMAS.MASAccount = header.MASAccount__c;
        prodMAS.MASUniqueId = header.MASCustomerUniqueId__c;
        prodMAS.MASServiceLine = header.MASServiceLine__c;
        prodMAS.MASBox = header.MASBox__c;
        prodMAS.MASComment = header.SetupComment__c;
        prodMAS.MASBypassPrice = header.BypassPriceReview__c;
        prodMAS.MASDoNotCreate = header.DoNotCreateMASTicket__c;
        prodMAS.DoNotCreateTaskGridTickets = header.DoNotCreateTaskGridTickets__c;
        prodMAS.VCRCode = header.VCRCode__c;
        return prodMAS;
    }

    /**
     * @description Build list of WorkOrderWrappers from quote orders
     * @param quoteLineId The parent quote line ID
     * @return List<QuoteProcurementController.WOWrapper> List of work order wrappers
     */
    private static List<QuoteProcurementController.WOWrapper> buildWorkOrderWrappers(Id quoteLineId) {
        List<QuoteProcurementController.WOWrapper> workOrders =
            new List<QuoteProcurementController.WOWrapper>();

        List<Quote_Order__c> quoteOrders = QuoteProcurementController.getOrders(quoteLineId);

        for (Quote_Order__c qo : quoteOrders) {
            QuoteProcurementController.WOWrapper woInstance = new QuoteProcurementController.WOWrapper();
            woInstance.serviceDate = qo.Service_Date__c;
            woInstance.serviceType = qo.Service_Type__c;
            woInstance.instructions = qo.Acorn_Instructions__c;
            workOrders.add(woInstance);
        }

        return workOrders;
    }

    /**
     * @description Build list of DetailWrappers from child quote lines
     * Also sets material type on the header wrapper
     *
     * @param quoteLineId The parent quote line ID
     * @param headerWrapper The header wrapper to update with material type and details
     * @return String Cost compare message if present
     */
    private static String buildDetailWrappers(
        Id quoteLineId,
        QuoteProcurementController.HeaderWrapper headerWrapper
    ) {
        List<QuoteProcurementController.DetailWrapper> prodDetails =
            new List<QuoteProcurementController.DetailWrapper>();
        String costCompareMessage = '';

        List<SBQQ__QuoteLine__c> detailRecords = QuoteProcurementController.getQuoteDetails(quoteLineId);

        for (SBQQ__QuoteLine__c detail : detailRecords) {
            // Handle Waste Stream - set on header and skip
            if (detail.SBQQ__ProductFamily__c == 'Waste Stream') {
                headerWrapper.materialType = detail.SBQQ__ProductName__c;
                headerWrapper.materialTypeCode = detail.SBQQ__ProductCode__c;
                continue;
            }

            QuoteProcurementController.DetailWrapper detailInstance =
                new QuoteProcurementController.DetailWrapper();

            detailInstance.quoteLineName = detail.Name;
            detailInstance.componentId = detail.Id;
            detailInstance.componentType = detail.SBQQ__ProductName__c;
            detailInstance.componentQuantity = Integer.valueOf(detail.SBQQ__Quantity__c);
            detailInstance.componentStartDate = detail.SBQQ__StartDate__c;
            detailInstance.componentEndDate = detail.SBQQ__EndDate__c;
            detailInstance.occurrenceType = detail.Occurrence_Type__c;
            detailInstance.scheduleFrequency = detail.Schedule_Frequency__c;
            detailInstance.frequencyInterval = detail.Frequency_Interval__c;
            detailInstance.serviceDays = detail.Service_Days__c;
            detailInstance.errorMessage = detail.ErrorComments__c;

            // Set icon and error status
            if (String.isBlank(detail.ErrorComments__c)) {
                detailInstance.iconName = 'utility:check';
                detailInstance.errorMessage = 'All validations passed';
            } else {
                detailInstance.iconName = 'utility:warning';
                headerWrapper.lineError = true;
            }

            // Cost details
            detailInstance.vendorCost = detail.SBQQ__UnitCost__c;
            detailInstance.costCurrencyCode = detail.SBQQ__UnitCost__c != null
                ? detail.CurrencyIsoCode
                : Constant_Util.EMPTY_STRING;
            detailInstance.costUOM = detail.Cost_Unit_of_Measure__c;
            detailInstance.costMin = detail.CostMinQuantity__c;

            // Price details
            detailInstance.customerPrice = detail.SBQQ__ListPrice__c;
            detailInstance.priceCurrencyCode = detail.SBQQ__ListPrice__c != null
                ? detail.CurrencyIsoCode
                : Constant_Util.EMPTY_STRING;
            detailInstance.priceUOM = detail.PriceUOM__c;
            detailInstance.priceMin = detail.PriceMinQuantity__c;

            // Extract cost compare message from H product
            if (detail.SBQQ__ProductCode__c == 'H') {
                costCompareMessage = detail.Cost_Compare_Message__c;
            }

            prodDetails.add(detailInstance);
        }

        headerWrapper.details = prodDetails;
        return costCompareMessage;
    }
}
