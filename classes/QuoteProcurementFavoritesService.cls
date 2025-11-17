/**
 * @description QuoteProcurementFavoritesService - Handles favorite product operations
 *
 * This service manages operations related to favorite products, including:
 * - Retrieving and grouping favorite products
 * - Creating quotes and quote lines from favorites
 * - Building favorite product wrappers for UI display
 *
 * Key Responsibilities:
 * - Query favorite products with proper field sets
 * - Group favorites by product for UI presentation
 * - Create quotes and quote lines from favorite selections
 * - Handle configuration attributes and product hierarchies
 *
 * Architecture:
 * - Delegates DML operations to QuoteProcurementDMLService
 * - Uses QuoteProcurementContextGetter for data access
 * - Integrates with GetCaseInformation for quote creation
 * - Supports both case-based and quote-based favorite additions
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - Favorites Management
 */
public with sharing class QuoteProcurementFavoritesService {

    // ========================================================================
    // PUBLIC API - FAVORITE PRODUCT RETRIEVAL
    // ========================================================================

    /**
     * @description Get all favorite products grouped by product name
     * Refactored from: getFavorites() in QuoteProcurementController
     * @return FavoriteContainerWrapper Wrapper containing grouped favorites
     */
    @AuraEnabled
    public static QuoteProcurementController.FavoriteContainerWrapper getFavorites() {
        System.debug('QuoteProcurementFavoritesService.getFavorites - Start');

        try {
            // Query all favorites with hierarchy information
            List<SBQQ__FavoriteProduct__c> allFavorites = [
                SELECT Id, Name, SBQQ__ConfigurationAttributes__c, SBQQ__Favorite__c,
                       SBQQ__Product__c, SBQQ__Product__r.Name, SBQQ__RequiredBy__c,
                       SBQQ__RequiredBy__r.SBQQ__RequiredBy__c, SBQQ__RequiredBy__r.Name,
                       SBQQ__Quantity__c
                FROM SBQQ__FavoriteProduct__c
                ORDER BY SBQQ__Favorite__c, SBQQ__RequiredBy__c
            ];

            System.debug('Total favorites retrieved: ' + allFavorites.size());

            // Query parent favorites (top-level)
            List<SBQQ__FavoriteProduct__c> parentFavorites = [
                SELECT Id, Name, SBQQ__ConfigurationAttributes__c, SBQQ__Favorite__c,
                       SBQQ__Product__c, SBQQ__Product__r.Name, SBQQ__RequiredBy__c,
                       SBQQ__RequiredBy__r.SBQQ__RequiredBy__c, SBQQ__Quantity__c
                FROM SBQQ__FavoriteProduct__c
                WHERE SBQQ__RequiredBy__c = null
            ];

            // Build the wrapper
            return buildFavoriteWrapper(parentFavorites, allFavorites);

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error in getFavorites: ' + ex.getMessage());
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            throw new AuraHandledException('Failed to retrieve favorites: ' + ex.getMessage());
        }
    }

    /**
     * @description Create quote and quote lines from a favorite product
     * Refactored from: addQuoteAndQuoteine() in QuoteProcurementController
     * @param favoriteId The Favorite Product ID
     * @param caseId The Case ID
     * @param quoteId Existing Quote ID (optional)
     * @param quoteScreen Whether called from quote screen
     * @return String The Quote ID (created or provided)
     */
    @AuraEnabled
    public static String createQuoteFromFavorite(String favoriteId, String caseId,
                                                 String quoteId, Boolean quoteScreen) {
        System.debug('createQuoteFromFavorite - favoriteId: ' + favoriteId + ', caseId: ' + caseId);

        try {
            // Query the favorite product hierarchy with all necessary fields
            List<SBQQ__FavoriteProduct__c> favorites = [
                SELECT Id, Name, SBQQ__ConfigurationAttributes__c, SBQQ__Favorite__c,
                       SBQQ__Product__c, SBQQ__Product__r.Name, SBQQ__RequiredBy__c,
                       SBQQ__RequiredBy__r.SBQQ__RequiredBy__c, SBQQ__Quantity__c,
                       SBQQ__ProductOption__c, SBQQ__ProductOption__r.SBQQ__Type__c,
                       SBQQ__ProductOption__r.Occurrence_Type__c,
                       SBQQ__ProductOption__r.CostModelType__c,
                       SBQQ__ProductOption__r.Cost_Unit_of_Measure__c,
                       SBQQ__ProductOption__r.PriceUOM__c,
                       SBQQ__ProductOption__r.Schedule_Frequency__c,
                       SBQQ__ProductOption__r.Frequency_Interval__c,
                       SBQQ__ProductOption__r.SBQQ__Quantity__c,
                       SBQQ__ProductOption__r.SBQQ__ProductFamily__c
                FROM SBQQ__FavoriteProduct__c
                WHERE SBQQ__Favorite__c = :favoriteId
                ORDER BY SBQQ__Favorite__c, SBQQ__RequiredBy__c
            ];

            if (favorites.isEmpty()) {
                throw new AuraHandledException('No favorite product found with ID: ' + favoriteId);
            }

            // Get or create quote
            String targetQuoteId = quoteId;
            SBQQ__Quote__c quote;
            Decimal parentLineNumber;

            if (!quoteScreen) {
                targetQuoteId = GetCaseInformation.createOppQuote(caseId);
                System.debug('Created new quote: ' + targetQuoteId);
                quote = [SELECT Id, SBQQ__Account__c FROM SBQQ__Quote__c WHERE Id = :targetQuoteId];
                parentLineNumber = 1;
            } else {
                quote = [SELECT Id, SBQQ__Account__c FROM SBQQ__Quote__c WHERE Id = :quoteId];
            }

            // Get next quote line number
            List<SBQQ__QuoteLine__c> maxQL = [
                SELECT SBQQ__Number__c
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__Quote__c = :targetQuoteId
                ORDER BY SBQQ__Number__c DESC
                LIMIT 1
            ];
            parentLineNumber = maxQL.size() > 0 ? maxQL[0].SBQQ__Number__c : 1;

            // Create quote lines from favorites
            createQuoteLinesFromFavorites(favorites, quote, parentLineNumber);

            return targetQuoteId;

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error in createQuoteFromFavorite: ' + ex.getMessage());
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            throw new AuraHandledException('Failed to create quote from favorite: ' + ex.getMessage());
        }
    }

    // ========================================================================
    // PRIVATE HELPER METHODS
    // ========================================================================

    /**
     * @description Build FavoriteContainerWrapper from favorite products
     * @param parentFavorites List of parent (top-level) favorites
     * @param allFavorites List of all favorites (including children)
     * @return FavoriteContainerWrapper The built wrapper
     */
    private static QuoteProcurementController.FavoriteContainerWrapper buildFavoriteWrapper(
        List<SBQQ__FavoriteProduct__c> parentFavorites,
        List<SBQQ__FavoriteProduct__c> allFavorites
    ) {
        QuoteProcurementController.FavoriteContainerWrapper wrapper =
            new QuoteProcurementController.FavoriteContainerWrapper();
        List<QuoteProcurementController.FavoriteProductHeader> headerList =
            new List<QuoteProcurementController.FavoriteProductHeader>();

        // Get unique product names
        Set<String> productNameSet = new Set<String>();
        for (SBQQ__FavoriteProduct__c fav : parentFavorites) {
            productNameSet.add(fav.Name);
        }
        List<String> uniqueProductNames = new List<String>(productNameSet);

        // Build header for each unique product
        for (String productName : uniqueProductNames) {
            QuoteProcurementController.FavoriteProductHeader header =
                new QuoteProcurementController.FavoriteProductHeader();
            header.productName = productName;
            header.listcontainerDetails = buildFavoriteDetails(productName, parentFavorites, allFavorites);

            headerList.add(header);
            System.debug('Built header for product: ' + productName +
                        ', details count: ' + header.listcontainerDetails.size());
        }

        wrapper.ContainerList = headerList;
        return wrapper;
    }

    /**
     * @description Build favorite product details for a specific product name
     * @param productName The product name to filter by
     * @param parentFavorites List of parent favorites
     * @param allFavorites List of all favorites
     * @return List<FavoriteProductDetail> The detail records
     */
    private static List<QuoteProcurementController.FavoriteProductDetail> buildFavoriteDetails(
        String productName,
        List<SBQQ__FavoriteProduct__c> parentFavorites,
        List<SBQQ__FavoriteProduct__c> allFavorites
    ) {
        List<QuoteProcurementController.FavoriteProductDetail> detailList =
            new List<QuoteProcurementController.FavoriteProductDetail>();

        for (SBQQ__FavoriteProduct__c fav : parentFavorites) {
            if (fav.Name == productName) {
                QuoteProcurementController.FavoriteProductDetail detail =
                    new QuoteProcurementController.FavoriteProductDetail();

                detail.containerType = fav.SBQQ__Product__r.Name;
                detail.FavoriteID = fav.SBQQ__Favorite__c;

                // Parse configuration attributes for equipment size
                if (String.isNotBlank(fav.SBQQ__ConfigurationAttributes__c)) {
                    try {
                        Map<String, Object> attributes =
                            (Map<String, Object>)JSON.deserializeUntyped(fav.SBQQ__ConfigurationAttributes__c);
                        detail.equipmentSize = String.valueOf(attributes.get('Equipment_Size__c'));
                    } catch (Exception ex) {
                        System.debug('Error parsing configuration attributes: ' + ex.getMessage());
                        detail.equipmentSize = '';
                    }
                }

                // Find material type from child favorites
                for (SBQQ__FavoriteProduct__c childFav : allFavorites) {
                    if (childFav.SBQQ__Favorite__c == fav.SBQQ__Favorite__c &&
                        childFav.SBQQ__RequiredBy__c != fav.Id &&
                        childFav.SBQQ__RequiredBy__r.SBQQ__RequiredBy__c != null &&
                        childFav.SBQQ__RequiredBy__r.Name != null) {
                        detail.materialType = childFav.Name;
                        break;
                    }
                }

                detailList.add(detail);
            }
        }

        return detailList;
    }

    /**
     * @description Create quote lines from favorite products
     * @param favorites List of favorite products to convert
     * @param quote Target quote
     * @param parentLineNumber Starting line number
     */
    private static void createQuoteLinesFromFavorites(
        List<SBQQ__FavoriteProduct__c> favorites,
        SBQQ__Quote__c quote,
        Decimal parentLineNumber
    ) {
        // Parse configuration attributes from first favorite (parent)
        Map<String, Object> plAttributes = (Map<String, Object>)JSON.deserializeUntyped(
            favorites[0].SBQQ__ConfigurationAttributes__c
        );
        String equipmentPql = String.valueOf(plAttributes.get('Equipment_Size__c'));
        String occurrenceType = String.valueOf(plAttributes.get('Occurrence_Type__c'));

        // Create parent quote line using QuoteLineServices
        SBQQ__QuoteLine__c parentQLine = QuoteLineServices.returnParentQuoteline(
            quote.Id,
            favorites[0].SBQQ__Product__c,
            equipmentPql,
            occurrenceType,
            true,
            favorites[0].SBQQ__ProductOption__r.SBQQ__Quantity__c,
            parentLineNumber
        );

        insert parentQLine;
        System.debug('Created parent quote line: ' + parentQLine.Id);

        // Prepare for child quote lines
        List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();
        Date SLADate = null; // SDT-27107
        parentQLine.SBQQ__StartDate__c = SLADate;
        quoteLineList.add(parentQLine);

        String qLineID = parentQLine.Id;
        Decimal currLineNumber = parentLineNumber + 3;
        String wasteCategoryId;

        // Create child quote lines
        if (qLineID != '') {
            for (Integer i = 1; i < favorites.size(); i++) {
                SBQQ__FavoriteProduct__c fav = favorites[i];
                Map<String, Object> attributes = (Map<String, Object>)JSON.deserializeUntyped(
                    fav.SBQQ__ConfigurationAttributes__c
                );
                String equipmentSize = String.valueOf(attributes.get('Equipment_Size__c'));
                String productFamily = fav.SBQQ__ProductOption__r.SBQQ__ProductFamily__c;

                if (productFamily == 'Waste Category') {
                    // Waste Category is option level 1
                    SBQQ__QuoteLine__c qLine = new SBQQ__QuoteLine__c(
                        SBQQ__Quote__c = quote.Id,
                        SBQQ__Product__c = fav.SBQQ__Product__c,
                        Equipment_Size__c = equipmentSize,
                        SBQQ__RequiredBy__c = parentQLine.Id,
                        SBQQ__ProductOption__c = fav.SBQQ__ProductOption__c,
                        SBQQ__Favorite__c = fav.SBQQ__Favorite__c,
                        SBQQ__OptionLevel__c = 1,
                        SBQQ__Quantity__c = fav.SBQQ__ProductOption__r.SBQQ__Quantity__c,
                        SBQQ__Number__c = parentLineNumber + 1,
                        Occurrence_Type__c = fav.SBQQ__ProductOption__r.Occurrence_Type__c,
                        CostModelType__c = fav.SBQQ__ProductOption__r.CostModelType__c,
                        Cost_Unit_of_Measure__c = fav.SBQQ__ProductOption__r.Cost_Unit_of_Measure__c,
                        PriceUOM__c = fav.SBQQ__ProductOption__r.PriceUOM__c,
                        Schedule_Frequency__c = fav.SBQQ__ProductOption__r.Schedule_Frequency__c,
                        Frequency_Interval__c = fav.SBQQ__ProductOption__r.Frequency_Interval__c,
                        SBQQ__StartDate__c = SLADate,
                        SBQQ__EndDate__c = SLADate
                    );

                    try {
                        insert qLine;
                        wasteCategoryId = qLine.Id;
                    } catch (Exception e) {
                        System.debug('Error inserting waste category: ' + e.getMessage());
                    }
                } else {
                    // Other products (including Waste Stream)
                    SBQQ__QuoteLine__c qLine = new SBQQ__QuoteLine__c(
                        SBQQ__Quote__c = quote.Id,
                        SBQQ__Product__c = fav.SBQQ__Product__c,
                        Equipment_Size__c = equipmentSize,
                        SBQQ__RequiredBy__c = (productFamily == 'Waste Stream') ? wasteCategoryId : parentQLine.Id,
                        SBQQ__ProductOption__c = fav.SBQQ__ProductOption__c,
                        SBQQ__Favorite__c = fav.SBQQ__Favorite__c,
                        SBQQ__OptionLevel__c = (productFamily == 'Waste Stream') ? 2 : 1,
                        SBQQ__Number__c = (productFamily == 'Waste Stream') ? parentLineNumber + 2 : currLineNumber,
                        SBQQ__CostEditable__c = (productFamily == 'Waste Stream') ? false : true,
                        SBQQ__PriceEditable__c = (productFamily == 'Waste Stream') ? false : true,
                        SBQQ__Quantity__c = fav.SBQQ__ProductOption__r.SBQQ__Quantity__c,
                        Occurrence_Type__c = fav.SBQQ__ProductOption__r.Occurrence_Type__c,
                        CostModelType__c = fav.SBQQ__ProductOption__r.CostModelType__c,
                        Cost_Unit_of_Measure__c = fav.SBQQ__ProductOption__r.Cost_Unit_of_Measure__c,
                        PriceUOM__c = fav.SBQQ__ProductOption__r.PriceUOM__c,
                        Schedule_Frequency__c = fav.SBQQ__ProductOption__r.Schedule_Frequency__c,
                        Frequency_Interval__c = fav.SBQQ__ProductOption__r.Frequency_Interval__c,
                        SBQQ__StartDate__c = SLADate,
                        SBQQ__EndDate__c = SLADate
                    );

                    quoteLineList.add(qLine);
                    currLineNumber = currLineNumber + 1;
                }
            }

            upsert quoteLineList;
            System.debug('Created ' + quoteLineList.size() + ' quote lines total');
        }
    }

}
