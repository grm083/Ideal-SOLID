/**
 * @description QuoteProcurementContextGetter - Data access layer for Quote Procurement operations
 *
 * This service acts as the single source of truth for all SOQL queries related to QuoteLines,
 * Quotes, and related objects in the procurement process. It provides consistent field sets,
 * caching strategies, and governor limit management.
 *
 * Key Responsibilities:
 * - All SOQL queries for QuoteLine, Quote, and related objects
 * - Query result caching to minimize database calls
 * - Consistent field selection across the application
 * - Bulk query support for efficient data loading
 *
 * Architecture:
 * - Singleton pattern with static methods
 * - Cache management for frequently accessed data
 * - Field set constants for query consistency
 * - Support for related object queries (Vendor, Quote_Order, MAS_Setup_Detail, etc.)
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - Data Access
 */
public with sharing class QuoteProcurementContextGetter {

    // ========================================================================
    // CACHE STRUCTURES
    // ========================================================================

    private static Map<Id, SBQQ__QuoteLine__c> quoteLineCache = new Map<Id, SBQQ__QuoteLine__c>();
    private static Map<Id, SBQQ__Quote__c> quoteCache = new Map<Id, SBQQ__Quote__c>();
    private static Map<Id, List<SBQQ__QuoteLine__c>> quoteLinesByQuoteCache = new Map<Id, List<SBQQ__QuoteLine__c>>();
    private static Map<Id, List<Quote_Order__c>> quoteOrdersCache = new Map<Id, List<Quote_Order__c>>();

    // ========================================================================
    // FIELD SET CONSTANTS
    // ========================================================================

    // Standard QuoteLine fields for header records (parent lines)
    private static final String QUOTELINE_HEADER_FIELDS =
        'Id, PricingUnitMethod__c, SBQQ__Quote__c, Vendor__r.Status__c, Vendor_Commit_Date__c, ' +
        'SBQQ__Quote__r.STP__c, SBQQ__ListPrice__c, SBQQ__UnitCost__c, SBQQ__ProductName__c, ' +
        'SBQQ__ProductFamily__c, SBQQ__ProductCode__c, Vendor__c, Vendor__r.Vendor_Business_Unit__c, ' +
        'Vendor__r.Parent_Vendor_Id__c, Vendor__r.Name, Vendor__r.AccountNumber, Occurrence_Type__c, ' +
        'Schedule_Frequency__c, Frequency_Interval__c, Service_Days__c, SBQQ__Quantity__c, Name, ' +
        'PriceUOM__c, PriceMinQuantity__c, SBQQ__PricingMethod__c, CostModelType__c, ' +
        'Cost_Unit_of_Measure__c, Account__c, CostMinQuantity__c, MASLibrary__c, MASCompany__c, ' +
        'MASAccount__c, MASCustomerUniqueId__c, MASServiceLine__c, MASBox__c, BypassPriceReview__c, ' +
        'BypassMASServiceChange__c, SetupComment__c, DoNotCreateMASTicket__c, DoNotCreateTaskGridTickets__c, ' +
        'Location_Position_Name__c, SBQQ__RequiredBy__c, Equipment_Size__c, Duration__c, ' +
        'SBQQ__StartDate__c, SBQQ__EndDate__c, sCode__c, SBQQ__RequiredBy__r.SBQQ__RequiredBy__c, ' +
        'Vendor__r.Contact_Manually_Vendor__c, Vendor__r.Prepayment_Required__c, ' +
        'SBQQ__Quote__r.Case_Type__c, SBQQ__Quote__r.SBQQ__Status__c, CompanyCategoryCode__c, ' +
        'MaterialGrade__c, CompanyCategoryName__c, SBQQ__Quote__r.SBQQ__Account__r.Parent.AccountNumber, ' +
        'SBQQ__Quote__r.Name, SBQQ__Quote__r.SBQQ__PrimaryContact__r.Name, ' +
        'SBQQ__Quote__r.SBQQ__PrimaryContact__r.Id, Certificate_of_Destruction__c, ' +
        'Certificate_of_Disposal__c, VCRCode__c, Service_Schedule__c, SBQQ__Number__c, ' +
        'SBQQ__Quote__r.Quote_Only__c, Profile_Number__c, Description_of_Waste__c, SBQQ__Product__c, ' +
        'SBQQ__Product__r.SBQQ__QuantityEditable__c, SLA_Override_Reason__c, SLA_Override_Comment__c, ' +
        'ProcurementErrorMessage__c, BundleProcuredStatus__c, CurrencyIsoCode, ' +
        'SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.Recordtype.Name, ' +
        'AAV_Delivery_Override_Comment__c, AAV_Delivery_Override_Reason__c, ' +
        'AAV_Service_Override_Reason__c, AAV_Service_Day_Override_Comment__c, ' +
        'AAV_Requested_AdditionalServicesAccessor__c, AAV_Delivery_Availability__c, ' +
        'AAV_Service_Availability__c, Availability_Flag__c, AAV_Asset_Availability_API_Errors__c, ' +
        'Vendor__r.FacilityCode__c, Quote_Only_Copy_of__c, SBQQ__Quote__r.SBQQ__Type__c, ' +
        'CustomerApproval__c, Day_of_Month__c, Month_Relative_Interval__c, Month_Relative__c, ' +
        'SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.Is_Haul_Away_Service__c, ' +
        'SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__c';

    // QuoteLine fields for detail records (child lines)
    private static final String QUOTELINE_DETAIL_FIELDS =
        'Id, SBQQ__Quote__c, PricingUnitMethod__c, Vendor__r.Status__c, Vendor_Commit_Date__c, ' +
        'SBQQ__Quote__r.SBQQ__Type__c, SBQQ__Quote__r.Case_Type__c, SBQQ__Quote__r.STP__c, ' +
        'SBQQ__ListPrice__c, SBQQ__UnitCost__c, SBQQ__ProductName__c, SBQQ__ProductCode__c, ' +
        'SBQQ__ProductFamily__c, Vendor__c, Vendor__r.Vendor_Business_Unit__c, ' +
        'Vendor__r.Parent_Vendor_Id__c, Vendor__r.Name, Vendor__r.AccountNumber, Occurrence_Type__c, ' +
        'Schedule_Frequency__c, Frequency_Interval__c, Service_Days__c, SBQQ__Cost__c, ' +
        'SBQQ__Quantity__c, Name, PriceUOM__c, PriceMinQuantity__c, SBQQ__PricingMethod__c, ' +
        'CostModelType__c, Cost_Unit_of_Measure__c, ErrorComments__c, CostMinQuantity__c, ' +
        'MASLibrary__c, MASCompany__c, MASAccount__c, MASCustomerUniqueId__c, MASServiceLine__c, ' +
        'MASBox__c, BypassPriceReview__c, BypassMASServiceChange__c, SetupComment__c, ' +
        'DoNotCreateMASTicket__c, Location_Position_Name__c, SBQQ__RequiredBy__c, Equipment_Size__c, ' +
        'Duration__c, SBQQ__StartDate__c, SBQQ__EndDate__c, sCode__c, ' +
        'SBQQ__RequiredBy__r.SBQQ__RequiredBy__c, SBQQ__Quote__r.SBQQ__Status__c, ' +
        'Bypass_Acorn_Integration__c, VCRCode__c, SBQQ__Product__c, ' +
        'SBQQ__Product__r.SBQQ__QuantityEditable__c, Pricing_API_Method__c, CurrencyIsoCode, ' +
        'Cost_Compare_Message__c, IsAssetQuotelineDifferent__c, SBQQ__Quote__r.Case_record_Type__c, ' +
        'SBQQ__RequiredBy__r.SBQQ__ProductName__c, SBQQ__Product__R.Name, ' +
        'SBQQ__RequiredBy__r.Equipment_Size__c, SBQQ__RequiredBy__r.AssetId__r.Equipment_Size__c, ' +
        'SBQQ__RequiredBy__r.SBQQ__ProductFamily__c, AssetId__c, DoNotCreateTaskGridTickets__c, ' +
        'CostPrice1__c, CostPrice2__c, PricePrice1__c, PricePrice2__c';

    // MAS-specific QuoteLine fields
    private static final String QUOTELINE_MAS_FIELDS =
        'Id, Vendor__r.Status__c, PricingUnitMethod__c, Vendor_Commit_Date__c, ' +
        'SBQQ__Quote__r.SBQQ__Type__c, SBQQ__Quote__r.Case_Type__c, SBQQ__Quote__r.STP__c, ' +
        'MASLibrary__c, MASCompany__c, MASAccount__c, MASCustomerUniqueId__c, MASServiceLine__c, ' +
        'MASBox__c, BypassPriceReview__c, BypassMASServiceChange__c, SetupComment__c, ' +
        'DoNotCreateMASTicket__c, DoNotCreateTaskGridTickets__c, ' +
        'SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__r.RecordType.Name, Vendor__c, ' +
        'Vendor__r.FacilityCode__c, Vendor__r.Vendor_Business_Unit__c, SBQQ__Product__R.family';

    // ========================================================================
    // PUBLIC API - QUOTELINE QUERIES
    // ========================================================================

    /**
     * @description Get a single QuoteLine by ID with extended field set
     * @param quoteLineId The QuoteLine record ID
     * @return SBQQ__QuoteLine__c The QuoteLine record
     */
    public static SBQQ__QuoteLine__c getQuoteLineById(Id quoteLineId) {
        if (quoteLineCache.containsKey(quoteLineId)) {
            return quoteLineCache.get(quoteLineId);
        }

        String query = 'SELECT ' + QUOTELINE_HEADER_FIELDS +
                      ' FROM SBQQ__QuoteLine__c WHERE Id = :quoteLineId LIMIT 1';

        List<SBQQ__QuoteLine__c> results = Database.query(query);

        if (!results.isEmpty()) {
            quoteLineCache.put(quoteLineId, results[0]);
            return results[0];
        }

        return null;
    }

    /**
     * @description Get multiple QuoteLines by IDs
     * @param quoteLineIds Set of QuoteLine record IDs
     * @return Map<Id, SBQQ__QuoteLine__c> Map of QuoteLine IDs to records
     */
    public static Map<Id, SBQQ__QuoteLine__c> getQuoteLinesByIds(Set<Id> quoteLineIds) {
        Map<Id, SBQQ__QuoteLine__c> results = new Map<Id, SBQQ__QuoteLine__c>();
        Set<Id> uncachedIds = new Set<Id>();

        // Check cache first
        for (Id qLineId : quoteLineIds) {
            if (quoteLineCache.containsKey(qLineId)) {
                results.put(qLineId, quoteLineCache.get(qLineId));
            } else {
                uncachedIds.add(qLineId);
            }
        }

        // Query for uncached records
        if (!uncachedIds.isEmpty()) {
            String query = 'SELECT ' + QUOTELINE_HEADER_FIELDS +
                          ' FROM SBQQ__QuoteLine__c WHERE Id IN :uncachedIds';

            List<SBQQ__QuoteLine__c> queriedRecords = Database.query(query);

            for (SBQQ__QuoteLine__c qLine : queriedRecords) {
                results.put(qLine.Id, qLine);
                quoteLineCache.put(qLine.Id, qLine);
            }
        }

        return results;
    }

    /**
     * @description Get all parent QuoteLines for a Quote (header records only)
     * Refactored from: getQuoteProducts()
     * @param quoteId The Quote record ID
     * @return List<SBQQ__QuoteLine__c> List of parent QuoteLines
     */
    public static List<SBQQ__QuoteLine__c> getQuoteLinesByQuoteId(Id quoteId) {
        if (quoteLinesByQuoteCache.containsKey(quoteId)) {
            return quoteLinesByQuoteCache.get(quoteId);
        }

        String query = 'SELECT ' + QUOTELINE_HEADER_FIELDS +
                      ' FROM SBQQ__QuoteLine__c ' +
                      'WHERE SBQQ__Quote__c = :quoteId AND SBQQ__RequiredBy__c = null';

        List<SBQQ__QuoteLine__c> results = Database.query(query);
        quoteLinesByQuoteCache.put(quoteId, results);

        return results;
    }

    /**
     * @description Get detail/child QuoteLines for a parent QuoteLine
     * Refactored from: getQuoteDetails()
     * @param parentQuoteLineId The parent QuoteLine ID
     * @return List<SBQQ__QuoteLine__c> List of detail QuoteLines
     */
    public static List<SBQQ__QuoteLine__c> getQuoteLineDetails(Id parentQuoteLineId) {
        String query = 'SELECT ' + QUOTELINE_DETAIL_FIELDS +
                      ' FROM SBQQ__QuoteLine__c ' +
                      'WHERE (SBQQ__RequiredBy__c = :parentQuoteLineId OR ' +
                      'SBQQ__RequiredBy__r.SBQQ__RequiredBy__c = :parentQuoteLineId) ' +
                      'AND SBQQ__ProductFamily__c != \'Waste Category\'';

        return Database.query(query);
    }

    /**
     * @description Get QuoteLine with MAS-specific fields
     * Refactored from: getQuoteLineMASDetails()
     * @param quoteLineId The QuoteLine ID
     * @return SBQQ__QuoteLine__c QuoteLine with MAS fields
     */
    public static SBQQ__QuoteLine__c getQuoteLineMASDetails(Id quoteLineId) {
        String query = 'SELECT ' + QUOTELINE_MAS_FIELDS +
                      ' FROM SBQQ__QuoteLine__c WHERE id = :quoteLineId LIMIT 1';

        List<SBQQ__QuoteLine__c> results = Database.query(query);
        return results.isEmpty() ? null : results[0];
    }

    /**
     * @description Get QuoteLines for position update operations
     * @param parentQuoteLineId The parent QuoteLine ID
     * @return List<SBQQ__QuoteLine__c> QuoteLines needing position updates
     */
    public static List<SBQQ__QuoteLine__c> getQuoteLinesForPosition(Id parentQuoteLineId) {
        return [SELECT Id, Location_Position_Name__c, LocationPositionName__c, SetupComment__c
                FROM SBQQ__QuoteLine__c
                WHERE (Id = :parentQuoteLineId OR SBQQ__RequiredBy__c = :parentQuoteLineId OR
                      SBQQ__RequiredBy__r.SBQQ__RequiredBy__c = :parentQuoteLineId)];
    }

    /**
     * @description Get QuoteLines by parent ID for bulk operations
     * @param parentQuoteLineId The parent QuoteLine ID
     * @return List<SBQQ__QuoteLine__c> All QuoteLines related to parent
     */
    public static List<SBQQ__QuoteLine__c> getQuoteLinesByParentId(Id parentQuoteLineId) {
        return [SELECT Id, SBQQ__ProductName__c, SBQQ__Quantity__c, SBQQ__StartDate__c,
                      SBQQ__EndDate__c, Description_of_Waste__c, SLA_Override_Reason__c,
                      SLA_Override_Comment__c, Equipment_Size__c, MaterialGrade__c,
                      CompanyCategoryCode__c, CompanyCategoryName__c, SBQQ__RequiredBy__c,
                      SBQQ__ProductOption__r.SBQQ__Type__c, Quote_SLA_Date__c
                FROM SBQQ__QuoteLine__c
                WHERE (Id = :parentQuoteLineId OR SBQQ__RequiredBy__c = :parentQuoteLineId OR
                      SBQQ__RequiredBy__r.SBQQ__RequiredBy__c = :parentQuoteLineId)];
    }

    /**
     * @description Get QuoteLine for order operations with specific fields
     * @param quoteLineId The QuoteLine ID
     * @return SBQQ__QuoteLine__c QuoteLine for order operations
     */
    public static SBQQ__QuoteLine__c getQuoteLineForOrders(Id quoteLineId) {
        return [SELECT Id, Name, SBQQ__ProductName__c, SBQQ__ProductCode__c, SBQQ__ProductFamily__c,
                      SBQQ__Quote__c, Occurrence_Type__c, Schedule_Frequency__c, Service_Days__c,
                      Frequency_Interval__c, SBQQ__StartDate__c, SBQQ__EndDate__c
                FROM SBQQ__QuoteLine__c
                WHERE Id = :quoteLineId
                LIMIT 1];
    }

    /**
     * @description Get specific QuoteLine for haul/removal operations
     * @param quoteLineId The QuoteLine ID
     * @param productName The product name to filter
     * @return SBQQ__QuoteLine__c QuoteLine matching criteria
     */
    public static SBQQ__QuoteLine__c getQuoteLineByIdAndProduct(Id quoteLineId, String productName) {
        return [SELECT Id, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__Quantity__c,
                      SBQQ__RequiredBy__c, SBQQ__Quote__c
                FROM SBQQ__QuoteLine__c
                WHERE (SBQQ__RequiredBy__c = :quoteLineId OR
                      SBQQ__RequiredBy__r.SBQQ__RequiredBy__c = :quoteLineId)
                      AND SBQQ__ProductName__c = :productName
                LIMIT 1];
    }

    /**
     * @description Get parent QuoteLine for haul/removal operations
     * @param parentQuoteLineId The parent QuoteLine ID
     * @return SBQQ__QuoteLine__c Parent QuoteLine
     */
    public static SBQQ__QuoteLine__c getParentQuoteLine(Id parentQuoteLineId) {
        return [SELECT Id, SBQQ__Quote__c, SBQQ__ProductName__c, SBQQ__StartDate__c,
                      SBQQ__EndDate__c, SBQQ__Quantity__c, Occurrence_Type__c,
                      Schedule_Frequency__c, Frequency_Interval__c, Service_Days__c,
                      Duration__c, SBQQ__Product__c, SBQQ__Product__r.Family
                FROM SBQQ__QuoteLine__c
                WHERE Id = :parentQuoteLineId
                LIMIT 1];
    }

    // ========================================================================
    // PUBLIC API - QUOTE QUERIES
    // ========================================================================

    /**
     * @description Get Quote by ID with extended fields
     * @param quoteId The Quote record ID
     * @return SBQQ__Quote__c The Quote record
     */
    public static SBQQ__Quote__c getQuoteById(Id quoteId) {
        if (quoteCache.containsKey(quoteId)) {
            return quoteCache.get(quoteId);
        }

        SBQQ__Quote__c quote = [SELECT Id, SBQQ__Account__r.Parent.AccountNumber,
                                      SBQQ__Account__r.ParentId, Project__c, SBQQ__Account__c,
                                      SBQQ__Account__r.Division__c, SBQQ__Account__r.Geography__c,
                                      SBQQ__Account__r.Location_Type__c, SBQQ__Account__r.Brand__c,
                                      Case_Sub_Type__c, Case_Reason__c, Case_Type__c,
                                      SBQQ__Opportunity2__r.Case__r.Origin,
                                      SBQQ__Opportunity2__r.Case__r.Recordtype.Name,
                                      SBQQ__Status__c, SBQQ__PrimaryContact__r.Name,
                                      SBQQ__PrimaryContact__c, SBQQ__Type__c, Quote_Only__c,
                                      SBQQ__Opportunity2__r.Case__c, Name, STP__c
                                FROM SBQQ__Quote__c
                                WHERE Id = :quoteId
                                LIMIT 1];

        quoteCache.put(quoteId, quote);
        return quote;
    }

    /**
     * @description Get Quote with status details
     * @param quoteId The Quote ID
     * @return SBQQ__Quote__c Quote with status fields
     */
    public static SBQQ__Quote__c getQuoteStatusDetails(Id quoteId) {
        return [SELECT Id, SBQQ__Status__c, Assigned_To__r.Name, Quote_Only__c,
                      SBQQ__Opportunity2__r.Case__r.RecordType.Name,
                      SBQQ__PrimaryContact__r.Name, SBQQ__PrimaryContact__r.Phone,
                      SBQQ__Opportunity2__r.Case__c, Project__c, Project__r.Name,
                      Project_Services_Request__c, QuoteProcuredStatus__c, Special_Handling__c,
                      Special_Handling_Reason__c, Special_Handling_Reason_Details__c,
                      SBQQ__Type__c, SBQQ__Opportunity2__r.Case__r.Vendor_Service_Id__c,
                      SBQQ__Opportunity2__r.Case__r.Chargeable__c
                FROM SBQQ__Quote__c
                WHERE Id = :quoteId
                LIMIT 1];
    }

    /**
     * @description Get Quote for order operations
     * @param quoteId The Quote ID
     * @return SBQQ__Quote__c Quote with order-related fields
     */
    public static SBQQ__Quote__c getQuoteForOrders(Id quoteId) {
        return [SELECT Id, SBQQ__PrimaryContact__r.Name, SBQQ__PrimaryContact__r.Phone,
                      SBQQ__Opportunity2__r.Case__c, Project__c, Project_Services_Request__c,
                      SBQQ__Opportunity2__r.Case__r.Vendor_Service_Id__c
                FROM SBQQ__Quote__c
                WHERE Id = :quoteId
                LIMIT 1];
    }

    // ========================================================================
    // PUBLIC API - QUOTE ORDER QUERIES
    // ========================================================================

    /**
     * @description Get Quote Orders for a QuoteLine
     * Refactored from: getOrders()
     * @param quoteLineId The QuoteLine ID
     * @return List<Quote_Order__c> List of Quote Orders
     */
    public static List<Quote_Order__c> getQuoteOrders(Id quoteLineId) {
        if (quoteOrdersCache.containsKey(quoteLineId)) {
            return quoteOrdersCache.get(quoteLineId);
        }

        List<Quote_Order__c> quoteOrders = [SELECT Id, Service_Date__c, Service_Type__c,
                                                  Instructions__c, Acorn_Instructions__c,
                                                  Quote_Line__r.Location_Position_Name__r.Container_Position__c,
                                                  Quote_Line__r.Location_Position_Name__r.AlternateStreet__c
                                            FROM Quote_Order__c
                                            WHERE Quote_Line__c = :quoteLineId];

        quoteOrdersCache.put(quoteLineId, quoteOrders);
        return quoteOrders;
    }

    // ========================================================================
    // PUBLIC API - RELATED OBJECT QUERIES
    // ========================================================================

    /**
     * @description Get Account Positions for a location
     * @param locationId The Account (Location) ID
     * @return List<Account_Position__c> List of positions
     */
    public static List<Account_Position__c> getAllPositions(Id locationId) {
        List<Account_Position__c> positions = new List<Account_Position__c>();

        // Get default positions first
        List<Account_Position__c> defaultPositions = [SELECT Id, Name, Container_Position__c,
                                                            AlternateStreet__c, AlternateCity__c,
                                                            AlternateState__c, AlternatePostalCode__c
                                                      FROM Account_Position__c
                                                      WHERE AccountId__c = :locationId
                                                            AND Container_Position__c = 'Default'];

        // Get other positions
        List<Account_Position__c> otherPositions = [SELECT Id, Name, Container_Position__c,
                                                          AlternateStreet__c, AlternateCity__c,
                                                          AlternateState__c, AlternatePostalCode__c
                                                    FROM Account_Position__c
                                                    WHERE AccountId__c = :locationId
                                                          AND Container_Position__c != 'Default'
                                                    ORDER BY Container_Position__c ASC];

        positions.addAll(defaultPositions);
        positions.addAll(otherPositions);

        return positions;
    }

    /**
     * @description Get Account Positions by IDs
     * @param positionIds Set of position IDs
     * @return Map<Id, Account_Position__c> Map of positions
     */
    public static Map<Id, Account_Position__c> getPositionsByIds(Set<Id> positionIds) {
        return new Map<Id, Account_Position__c>([SELECT Id, Name, Container_Position__c,
                                                        AlternateStreet__c, AlternateCity__c,
                                                        AlternateState__c, AlternatePostalCode__c,
                                                        AccountId__c
                                                  FROM Account_Position__c
                                                  WHERE Id IN :positionIds]);
    }

    /**
     * @description Validate position uniqueness for a location
     * @param locationId The Account (Location) ID
     * @param containerPosition The container position text
     * @return Boolean True if position is unique
     */
    public static Boolean validatePositionUniqueness(Id locationId, String containerPosition) {
        List<Account_Position__c> existingPositions = [SELECT Id, Container_Position__c
                                                      FROM Account_Position__c
                                                      WHERE AccountId__c = :locationId];

        for (Account_Position__c pos : existingPositions) {
            if (pos.Container_Position__c == containerPosition) {
                return false;
            }
        }

        return true;
    }

    /**
     * @description Get MAS Setup Details by facility code
     * @param facilityCode The vendor facility code
     * @param lineOfBusiness The MAS line of business
     * @param newServiceCase Whether this is a new service case
     * @return List<AggregateResult> Aggregated MAS details
     */
    public static List<AggregateResult> getMASDetailsByFacility(String facilityCode,
                                                                 String lineOfBusiness,
                                                                 Boolean newServiceCase) {
        return [SELECT MAS_Library__c, MAS_Company_Code__c, MAS_Line_of_Business__c,
                      Bypass_Price_Review__c
                FROM MAS_Setup_Detail__c
                WHERE Facility_Id__c = :facilityCode
                      AND MAS_Line_of_Business__c = :lineOfBusiness
                      AND Valid_For_New_Service__c = :newServiceCase
                GROUP BY MAS_Library__c, MAS_Company_Code__c, MAS_Line_of_Business__c,
                        Bypass_Price_Review__c];
    }

    /**
     * @description Get MAS Setup Details by business unit
     * @param businessUnit The vendor business unit
     * @param lineOfBusiness The MAS line of business
     * @return List<AggregateResult> Aggregated MAS details
     */
    public static List<AggregateResult> getMASDetailsByBusinessUnit(String businessUnit,
                                                                    String lineOfBusiness) {
        return [SELECT MAS_Library__c, MAS_Company_Code__c, MAS_Line_of_Business__c,
                      Bypass_Price_Review__c
                FROM MAS_Setup_Detail__c
                WHERE Business_Unit_Number__c = :businessUnit
                      AND MAS_Line_of_Business__c = :lineOfBusiness
                GROUP BY MAS_Library__c, MAS_Company_Code__c, MAS_Line_of_Business__c,
                        Bypass_Price_Review__c];
    }

    /**
     * @description Get Active Projects for a client account
     * @param clientAccountId The client Account ID
     * @return List<Project_Code__c> List of active projects
     */
    public static List<Project_Code__c> getActiveProjectsByClient(Id clientAccountId) {
        return [SELECT Id, Name, Project_Manager__r.Name, Program_Manager__r.Name,
                      Effective_Date__c, End_Date__c, Duration__c, Company_Category__c
                FROM Project_Code__c
                WHERE Client_Account__c = :clientAccountId
                      AND Active__c = true
                ORDER BY Project_Manager__r.Name ASC, Effective_Date__c DESC];
    }

    /**
     * @description Get Business Rules for a quote
     * @param clientAccountId The client Account ID
     * @param caseType The case type
     * @param subType The case sub-type
     * @return List<Business_Rule__c> List of matching business rules
     */
    public static List<Business_Rule__c> getQuoteBusinessRules(Id clientAccountId,
                                                               String caseType,
                                                               String subType) {
        return [SELECT Id, AccountId__c, Request_Type__c, Service__c, Case_Reason__c,
                      Required_Information__c
                FROM Business_Rule__c
                WHERE AccountId__c = :clientAccountId
                      AND Active__c = true
                      AND ((Request_Type__c = :caseType AND Service__c = :subType)
                      OR (Request_Type__c = :caseType AND Service__c = null))];
    }

    /**
     * @description Get Product Options by product ID
     * @param productId The Product2 ID
     * @return List<SBQQ__ProductOption__c> List of product options
     */
    public static List<SBQQ__ProductOption__c> getProductOptions(Id productId) {
        return [SELECT Id, Name, SBQQ__OptionalSKU__c, SBQQ__OptionalSKU__r.Name,
                      SBQQ__Number__c, SBQQ__Type__c, SBQQ__Quantity__c
                FROM SBQQ__ProductOption__c
                WHERE SBQQ__ConfiguredSKU__c = :productId
                ORDER BY SBQQ__Number__c ASC];
    }

    /**
     * @description Get Product Option by parent and child product IDs
     * @param parentProductId The parent Product2 ID
     * @param childProductId The child Product2 ID
     * @return SBQQ__ProductOption__c The matching product option
     */
    public static SBQQ__ProductOption__c getProductOptionByProducts(Id parentProductId,
                                                                    Id childProductId) {
        List<SBQQ__ProductOption__c> results = [SELECT Id
                                                FROM SBQQ__ProductOption__c
                                                WHERE SBQQ__ConfiguredSKU__c = :parentProductId
                                                      AND SBQQ__OptionalSKU__c = :childProductId
                                                LIMIT 1];

        return results.isEmpty() ? null : results[0];
    }

    /**
     * @description Get Product by name and parent product ID
     * @param productName The product name
     * @param parentProductId The parent product ID
     * @return Id The matching Product2 ID
     */
    public static Id getProductIdByName(String productName, Id parentProductId) {
        List<SBQQ__ProductOption__c> results = [SELECT SBQQ__OptionalSKU__c
                                                FROM SBQQ__ProductOption__c
                                                WHERE SBQQ__ConfiguredSKU__c = :parentProductId
                                                      AND SBQQ__OptionalSKU__r.Name = :productName
                                                LIMIT 1];

        return results.isEmpty() ? null : results[0].SBQQ__OptionalSKU__c;
    }

    /**
     * @description Get maximum QuoteLine number for a Quote
     * @param quoteId The Quote ID
     * @return Decimal The maximum line number
     */
    public static Decimal getMaxQuoteLineNumber(Id quoteId) {
        List<SBQQ__QuoteLine__c> maxQL = [SELECT SBQQ__Number__c
                                          FROM SBQQ__QuoteLine__c
                                          WHERE SBQQ__Quote__c = :quoteId
                                          ORDER BY SBQQ__Number__c DESC
                                          LIMIT 1];

        return maxQL.isEmpty() ? 1 : maxQL[0].SBQQ__Number__c;
    }

    // ========================================================================
    // CACHE MANAGEMENT
    // ========================================================================

    /**
     * @description Clear all caches
     */
    public static void clearCaches() {
        quoteLineCache.clear();
        quoteCache.clear();
        quoteLinesByQuoteCache.clear();
        quoteOrdersCache.clear();
    }

    /**
     * @description Clear specific QuoteLine from cache
     * @param quoteLineId The QuoteLine ID to clear
     */
    public static void clearQuoteLineCache(Id quoteLineId) {
        quoteLineCache.remove(quoteLineId);
    }

    /**
     * @description Clear specific Quote from cache
     * @param quoteId The Quote ID to clear
     */
    public static void clearQuoteCache(Id quoteId) {
        quoteCache.remove(quoteId);
        quoteLinesByQuoteCache.remove(quoteId);
    }
}
