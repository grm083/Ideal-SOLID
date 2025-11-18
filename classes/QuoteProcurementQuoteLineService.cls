/**
 * @description QuoteProcurementQuoteLineService - Handles quote line update operations
 *
 * This service manages quote line bundle update operations:
 * - Updating quote overview (quote line bundles)
 * - Equipment size picklist conversions
 *
 * Key Responsibilities:
 * - Update quote line bundles with header wrapper data
 * - Convert picklist labels to API names
 * - Handle quantity updates including lock products
 * - Update SLA dates, material grades, company categories
 *
 * Architecture:
 * - Integrates with QuoteLineServices for quote line queries and lock product updates
 * - Follows service layer pattern with comprehensive error handling
 * - Returns success/failure status for update operations
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - Quote Line Management
 */
public with sharing class QuoteProcurementQuoteLineService {

    // ========================================================================
    // PUBLIC API - QUOTE LINE UPDATES
    // ========================================================================

    /**
     * @description Update quote line bundle from header wrapper data
     * Refactored from: updateQuoteOverview() in QuoteProcurementController
     *
     * Updates all quote lines in a bundle with data from the header wrapper:
     * - Quantities (excluding accessories)
     * - Lock product quantities
     * - Equipment size, material grade, company category
     * - SLA override reason/comment
     * - Waste description
     * - SLA dates for parent lines
     *
     * @param productWrapper The header wrapper containing update data
     * @return Boolean True if update successful, false otherwise
     */
    @AuraEnabled
    public static Boolean updateQuoteOverview(QuoteProcurementController.HeaderWrapper productWrapper) {
        System.debug('QuoteProcurementQuoteLineService.updateQuoteOverview - Start: ' + productWrapper);

        try {
            // Get all quote lines in the bundle
            List<SBQQ__QuoteLine__c> qlList = QuoteLineServices.getQuoteLinesByParentId(productWrapper.parentId);

            // Convert equipment size label to API name
            productWrapper.equipmentSize = getPicklistAPIName(productWrapper.equipmentSize);

            // Update each quote line in the bundle
            for (SBQQ__QuoteLine__c ql : qlList) {
                // Update quantity (excluding accessories)
                if (ql.SBQQ__ProductOption__r.SBQQ__Type__c != 'Accessory') {
                    ql.SBQQ__Quantity__c = productWrapper.quantity;
                }

                // TCS-pkulkarn-SDT-33379-5-Dec-2023: Update Quantity on Lock Fee and Lock products
                QuoteLineServices.updateQuantityForLockProducts(ql, productWrapper.quantity);

                // Update quote line fields
                ql.Description_of_Waste__c = productWrapper.wasteDescription;
                ql.SLA_Override_Reason__c = productWrapper.slaOverrideReason;
                ql.SLA_Override_Comment__c = productWrapper.slaOverrideComment;
                ql.Equipment_Size__c = productWrapper.equipmentSize;

                // SDT-37527: Update material grade
                if (productWrapper.selectedMaterialGrade != null) {
                    ql.MaterialGrade__c = productWrapper.selectedMaterialGrade;
                }

                // Update company category
                if (!String.isEmpty(productWrapper.companyCategory)) {
                    ql.CompanyCategoryCode__c = productWrapper.companyCategory;
                }
                if (!String.isEmpty(productWrapper.companyCategoryName)) {
                    ql.CompanyCategoryName__c = productWrapper.companyCategoryName;
                }

                // SDT-42448: Update SLA date for parent lines only
                if (ql.SBQQ__RequiredBy__c == null) {
                    ql.Quote_SLA_Date__c = QuoteProcurementController.callDetermineSLA(ql.Id);
                }
            }

            // Update all quote lines
            update qlList;

            System.debug('Successfully updated ' + qlList.size() + ' quote lines');
            return true;

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Error in updateQuoteOverview: ' + ex.getMessage());
            UTIL_LoggingService.logHandledException(
                ex,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            return false;
        }
    }

    // ========================================================================
    // PRIVATE HELPER METHODS
    // ========================================================================

    /**
     * @description Convert picklist label to API name
     * @param labelName The picklist label
     * @return String The API name for the picklist value
     */
    private static String getPicklistAPIName(String labelName) {
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
}
