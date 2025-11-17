/**
 * @description QuoteProcurementProductOptionService - Handles product option operations
 *
 * This service manages operations related to product options on quote lines, including:
 * - Adding product options to quote lines
 * - Removing product options from quote lines
 * - Updating key quantities for accessory options
 *
 * Key Responsibilities:
 * - Create quote lines for product options with proper field mappings
 * - Handle special logic for Keys products (end date = start date)
 * - Remove accessory and key quote lines
 * - Bulk update key quantities
 *
 * Architecture:
 * - Follows service layer patterns from QuoteProcurementFavoritesService
 * - Uses standard error handling with AuraHandledException
 * - Integrates with UTIL_LoggingService for error tracking
 * - Returns operation results as strings ('SUCCESS' or error message)
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - Product Options Management
 */
public with sharing class QuoteProcurementProductOptionService {

    // ========================================================================
    // PUBLIC API - PRODUCT OPTION MANAGEMENT
    // ========================================================================

    /**
     * @description Add a product option to a quote line
     * Refactored from: addProductOption() in QuoteProcurementController
     *
     * Creates a new child quote line for the specified product option.
     * Special handling for Keys products: sets end date equal to start date.
     *
     * @param quoteLineId The parent quote line ID
     * @param productOptionId The product option ID to add
     * @return String The created quote line ID on success, or error message on failure
     */
    @AuraEnabled
    public static String addProductOption(Id quoteLineId, Id productOptionId) {
        System.debug('QuoteProcurementProductOptionService.addProductOption - Start');
        System.debug('quoteLineId: ' + quoteLineId + ', productOptionId: ' + productOptionId);

        try {
            // Query parent quote line and its children
            List<SBQQ__QuoteLine__c> quoteLines = [
                SELECT Id, SBQQ__Number__c, SBQQ__StartDate__c, Equipment_Size__c,
                       SBQQ__Quote__c, SID__c
                FROM SBQQ__QuoteLine__c
                WHERE Id = :quoteLineId OR SBQQ__RequiredBy__c = :quoteLineId
                ORDER BY SBQQ__Number__c DESC
            ];

            if (quoteLines.isEmpty()) {
                throw new AuraHandledException('Quote line not found with ID: ' + quoteLineId);
            }

            // Query product option details
            SBQQ__ProductOption__c prodOption = [
                SELECT Id, SBQQ__OptionalSKU__c, SBQQ__OptionalSKU__r.Name,
                       SBQQ__OptionalSKU__r.ProductCode, SBQQ__Quantity__c, Occurrence_Type__c,
                       CostModelType__c, Cost_Unit_of_Measure__c, PriceUOM__c,
                       Schedule_Frequency__c, Frequency_Interval__c
                FROM SBQQ__ProductOption__c
                WHERE Id = :productOptionId
            ];

            // Build new quote line for the option
            SBQQ__QuoteLine__c qLine = new SBQQ__QuoteLine__c(
                SBQQ__Quote__c = quoteLines[0].SBQQ__Quote__c,
                SBQQ__Product__c = prodOption.SBQQ__OptionalSKU__c,
                Equipment_Size__c = quoteLines[0].Equipment_Size__c,
                SBQQ__RequiredBy__c = quoteLineId,
                SBQQ__ProductOption__c = prodOption.Id,
                SBQQ__OptionLevel__c = 1,
                SBQQ__Number__c = quoteLines[0].SBQQ__Number__c + 1,
                SBQQ__CostEditable__c = true,
                SBQQ__PriceEditable__c = true,
                SBQQ__Quantity__c = prodOption.SBQQ__Quantity__c,
                Occurrence_Type__c = prodOption.Occurrence_Type__c,
                CostModelType__c = prodOption.CostModelType__c,
                Cost_Unit_of_Measure__c = prodOption.Cost_Unit_of_Measure__c,
                PriceUOM__c = prodOption.PriceUOM__c,
                Schedule_Frequency__c = prodOption.Schedule_Frequency__c,
                Frequency_Interval__c = prodOption.Frequency_Interval__c,
                SBQQ__StartDate__c = quoteLines[0].SBQQ__StartDate__c,
                SID__c = quoteLines[0].SID__c
            );

            System.debug('Created quote line: ' + qLine);

            // Special handling for Keys products - set end date = start date
            if (prodOption.SBQQ__OptionalSKU__r.Name == Constant_Util.KEYS) {
                qLine.SBQQ__EndDate__c = qLine.SBQQ__StartDate__c;
                System.debug('Keys product detected - setting end date = start date');
            }

            // Insert the quote line
            insert qLine;
            System.debug('Quote line inserted successfully: ' + qLine.Id);

            return String.valueOf(qLine.Id);

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error in addProductOption: ' + ex.getMessage());
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            return ex.getMessage();
        }
    }

    /**
     * @description Remove a product option from a quote line
     * Refactored from: removeProductOption(Id, Id) in QuoteProcurementController
     *
     * Deletes the child quote line associated with the specified product option.
     *
     * @param quoteLineId The parent quote line ID
     * @param productOptionId The optional SKU ID of the product option to remove
     * @return String 'SUCCESS' on success, or error message on failure
     */
    @AuraEnabled
    public static String removeProductOption(Id quoteLineId, Id productOptionId) {
        System.debug('QuoteProcurementProductOptionService.removeProductOption - Start');
        System.debug('quoteLineId: ' + quoteLineId + ', productOptionId: ' + productOptionId);

        try {
            // Find the child quote line to remove
            SBQQ__QuoteLine__c quoteLine = [
                SELECT Id
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__RequiredBy__c = :quoteLineId
                AND SBQQ__ProductOption__r.SBQQ__OptionalSKU__c = :productOptionId
                LIMIT 1
            ];

            delete quoteLine;
            System.debug('Quote line deleted successfully');

            return 'SUCCESS';

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error in removeProductOption: ' + ex.getMessage());
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            return ex.getMessage();
        }
    }

    /**
     * @description Remove a product option and its associated keys from a quote line
     * Refactored from: removeProductOption(Id, Id, Id) in QuoteProcurementController
     *
     * Deletes both the accessory quote line and any associated key quote lines.
     * This is used when an accessory that has keys is unchecked.
     *
     * @param quoteLineId The parent quote line ID
     * @param productOptionId The optional SKU ID of the accessory to remove
     * @param keyOptionId The product option ID of the associated key
     * @return String 'SUCCESS' on success, or error message on failure
     */
    @AuraEnabled
    public static String removeProductOptionWithKeys(Id quoteLineId, Id productOptionId, Id keyOptionId) {
        System.debug('QuoteProcurementProductOptionService.removeProductOptionWithKeys - Start');
        System.debug('quoteLineId: ' + quoteLineId + ', productOptionId: ' + productOptionId +
                    ', keyOptionId: ' + keyOptionId);

        try {
            // Find both the accessory and key quote lines to remove
            List<SBQQ__QuoteLine__c> quoteLine = [
                SELECT Id
                FROM SBQQ__QuoteLine__c
                WHERE (SBQQ__RequiredBy__c = :quoteLineId
                       AND SBQQ__ProductOption__r.SBQQ__OptionalSKU__c = :productOptionId)
                OR (SBQQ__RequiredBy__r.SBQQ__RequiredBy__c = :quoteLineId
                    AND SBQQ__ProductOption__c = :keyOptionId)
                LIMIT 2
            ];

            delete quoteLine;
            System.debug('Quote lines deleted successfully: ' + quoteLine.size() + ' records');

            return 'SUCCESS';

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error in removeProductOptionWithKeys: ' + ex.getMessage());
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            return ex.getMessage();
        }
    }

    /**
     * @description Update quantities on key quote lines
     * Refactored from: updateKeysQuantity() in QuoteProcurementController
     *
     * Updates the quantities for padlock key quote lines based on the provided map.
     * Used when user adjusts key quantities for accessories.
     *
     * @param parentId The parent quote line ID
     * @param keyObj List of KeyMapWrapper objects containing key IDs and quantities
     * @return String 'SUCCESS' on success, or error message on failure
     */
    @AuraEnabled
    public static String updateKeysQuantity(Id parentId, List<QuoteProcurementController.KeyMapWrapper> keyObj) {
        System.debug('QuoteProcurementProductOptionService.updateKeysQuantity - Start');
        System.debug('parentId: ' + parentId + ', keyObj size: ' + keyObj.size());

        try {
            // Build sets and maps from the key objects
            Set<String> idSet = new Set<String>();
            Map<String, String> keyMap = new Map<String, String>();

            for (QuoteProcurementController.KeyMapWrapper obj : keyObj) {
                System.debug('Processing key: ' + obj.id + ' = ' + obj.value);
                idSet.add((String)obj.id);
                keyMap.put((String)obj.id, (String)obj.value);
            }

            // Query the key quote lines
            List<SBQQ__QuoteLine__c> quoteLines = [
                SELECT Id, SBQQ__Quantity__c, SBQQ__ProductOption__c
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__RequiredBy__r.SBQQ__RequiredBy__c = :parentId
                AND SBQQ__ProductOption__c IN :idSet
            ];

            System.debug('Found ' + quoteLines.size() + ' key quote lines to update');

            // Update quantities
            List<SBQQ__QuoteLine__c> updatedQuoteLinesList = new List<SBQQ__QuoteLine__c>();

            for (SBQQ__QuoteLine__c ql : quoteLines) {
                if (keyMap.containsKey(ql.SBQQ__ProductOption__c)) {
                    String quantityValue = keyMap.get(ql.SBQQ__ProductOption__c);
                    ql.SBQQ__Quantity__c = (quantityValue == null || quantityValue == '')
                        ? 0
                        : Decimal.valueOf(quantityValue);
                    updatedQuoteLinesList.add(ql);
                }
            }

            // Perform update if there are changes
            if (!updatedQuoteLinesList.isEmpty()) {
                update updatedQuoteLinesList;
                System.debug('Updated ' + updatedQuoteLinesList.size() + ' quote lines');
            }

            return 'SUCCESS';

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error in updateKeysQuantity: ' + ex.getMessage());
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            return ex.getMessage();
        }
    }
}
