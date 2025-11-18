/**
 * @description QuoteProcurementOrderService - Quote Order management layer
 *
 * This service handles creation, management, and deletion of Quote Orders.
 * It contains complex logic for delivery, removal, and haul order creation.
 *
 * Key Responsibilities:
 * - Quote Order creation (delivery, removal, haul)
 * - Quote Order deletion and validation
 * - Order wrapper generation
 * - Service date and type management
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - Order Management
 */
public with sharing class QuoteProcurementOrderService {

    // ========================================================================
    // PUBLIC API - QUOTE ORDER RETRIEVAL
    // ========================================================================

    /**
     * @description Get Quote Orders for a QuoteLine
     * Delegates to ContextGetter
     * @param quoteLineId The QuoteLine ID
     * @return List<Quote_Order__c> List of quote orders
     */
    @AuraEnabled
    public static List<Quote_Order__c> getQuoteOrders(Id quoteLineId) {
        return QuoteProcurementContextGetter.getQuoteOrders(quoteLineId);
    }

    // ========================================================================
    // PUBLIC API - QUOTE ORDER DELETION
    // ========================================================================

    /**
     * @description Delete Quote Orders
     * Refactored from: deleteQuoteOrders() in QuoteProcurementController
     * @param quoteOrders List of Quote Orders to delete
     * @return String 'SUCCESS' or error message
     */
    @AuraEnabled
    public static String deleteQuoteOrders(List<Quote_Order__c> quoteOrders) {
        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();
        QuoteProcurementDMLService.DMLResult result = dmlService.deleteQuoteOrders(quoteOrders);

        return result.isSuccess ? 'SUCCESS' : result.message;
    }

    // ========================================================================
    // PUBLIC API - ORDER WRAPPER GENERATION
    // ========================================================================

    /**
     * @description Generate empty order wrapper
     * Refactored from: generateOrderWrapper() in QuoteProcurementController
     * @return OrderWrapper Empty order wrapper
     */
    @AuraEnabled
    public static OrderWrapper generateOrderWrapper() {
        return new OrderWrapper();
    }

    // ========================================================================
    // INNER CLASSES
    // ========================================================================

    /**
     * @description Wrapper class for Quote Orders
     */
    public class OrderWrapper {
        @AuraEnabled public String parentQuoteLine {get; set;}
        @AuraEnabled public String serviceQuoteLine {get; set;}
        @AuraEnabled public Date serviceDate {get; set;}
        @AuraEnabled public String serviceType {get; set;}
        @AuraEnabled public Decimal quantity {get; set;}
        @AuraEnabled public String onsiteContact {get; set;}
        @AuraEnabled public String onsitePhone {get; set;}
        @AuraEnabled public String instructions {get; set;}
        @AuraEnabled public String acornInstructions {get; set;}
        @AuraEnabled public String productType {get; set;}
        @AuraEnabled public String PONumber {get; set;}
        @AuraEnabled public String duration {get; set;}
        @AuraEnabled public String occurrenceType {get; set;}
        @AuraEnabled public String serviceTimeSpan {get; set;}
        @AuraEnabled public String quoteId {get; set;}
        @AuraEnabled public Date serviceEndDate {get; set;}
        @AuraEnabled public String vendorServiceId {get; set;}
    }
}
