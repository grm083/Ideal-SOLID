/**
 * @description QuoteProcurementPositionService - Account Position management layer
 *
 * This service handles creation, validation, and management of Account Positions
 * for QuoteLines. It supports both onsite and offsite positions.
 *
 * Key Responsibilities:
 * - Onsite position creation
 * - Offsite position creation with address
 * - Position uniqueness validation
 * - Position assignment to QuoteLines
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - Position Management
 */
public with sharing class QuoteProcurementPositionService {

    // ========================================================================
    // PUBLIC API - POSITION CREATION
    // ========================================================================

    /**
     * @description Create an onsite position
     * Refactored from: storeOnsite() in QuoteProcurementController
     * @param locationId The location Account ID
     * @param positionName The position name
     * @return String 'Success' or 'Duplicate'
     */
    @AuraEnabled
    public static String createOnsitePosition(Id locationId, String positionName) {
        // Validate uniqueness
        if (!QuoteProcurementContextGetter.validatePositionUniqueness(locationId, positionName)) {
            return 'Duplicate';
        }

        // Create position
        Account_Position__c position = new Account_Position__c();
        position.AccountId__c = locationId;
        position.Container_Position__c = positionName;

        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();
        QuoteProcurementDMLService.DMLResult result = dmlService.insertAccountPositions(
            new List<Account_Position__c>{position}
        );

        return result.isSuccess ? 'Success' : 'Failed';
    }

    /**
     * @description Create an offsite position with address
     * Refactored from: storeOffsite() in QuoteProcurementController
     * @param locationId The location Account ID
     * @param positionName The position name
     * @param street Street address
     * @param city City
     * @param state State
     * @param postal Postal code
     * @return String 'Success' or 'Duplicate'
     */
    @AuraEnabled
    public static String createOffsitePosition(Id locationId, String positionName,
                                              String street, String city,
                                              String state, String postal) {
        // Build position record
        Account_Position__c position = new Account_Position__c();
        position.AccountId__c = locationId;
        position.AlternateStreet__c = String.isNotBlank(street) ? street : Constant_Util.EMPTY_STRING;
        position.AlternateCity__c = String.isNotBlank(city) ? city : Constant_Util.EMPTY_STRING;
        position.AlternateState__c = String.isNotBlank(state) ? state : Constant_Util.EMPTY_STRING;
        position.AlternatePostalCode__c = String.isNotBlank(postal) ? postal : Constant_Util.EMPTY_STRING;

        // Build container position with address
        position.Container_Position__c = Constant_Util.OFFSITE + Constant_Util.COLON +
                                        Constant_Util.BLANKSPACE + positionName;

        if (String.isNotBlank(street) || String.isNotBlank(city) ||
            String.isNotBlank(state) || String.isNotBlank(postal)) {
            position.Container_Position__c +=
                ' at ' +
                position.AlternateStreet__c + Constant_Util.BLANKSPACE +
                position.AlternateCity__c + Constant_Util.BLANKSPACE +
                position.AlternateState__c + Constant_Util.BLANKSPACE +
                position.AlternatePostalCode__c;
        }

        // Validate uniqueness
        if (!QuoteProcurementContextGetter.validatePositionUniqueness(
            locationId,
            position.Container_Position__c
        )) {
            return 'Duplicate';
        }

        // Create position
        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();
        QuoteProcurementDMLService.DMLResult result = dmlService.insertAccountPositions(
            new List<Account_Position__c>{position}
        );

        return result.isSuccess ? 'Success' : 'Failed';
    }

    // ========================================================================
    // PUBLIC API - POSITION ASSIGNMENT
    // ========================================================================

    /**
     * @description Update position on QuoteLines
     * Delegates to DMLService
     * @param parentQuoteLineId The parent QuoteLine ID
     * @param positionId The Account Position ID
     * @param setupComments Setup comments
     * @param isOffsite Whether position is offsite
     * @return QuoteProcurementDMLService.DMLResult Result of operation
     */
    public static QuoteProcurementDMLService.DMLResult updatePositionOnQuoteLines(
        Id parentQuoteLineId,
        Id positionId,
        String setupComments,
        Boolean isOffsite
    ) {
        QuoteProcurementDMLService dmlService = QuoteProcurementDMLService.getInstance();
        return dmlService.updatePositionOnQuoteLines(
            parentQuoteLineId,
            positionId,
            setupComments,
            isOffsite
        );
    }

    // ========================================================================
    // PUBLIC API - POSITION DISPLAY
    // ========================================================================

    /**
     * @description Get QuoteLine positions for display
     * Refactored from: showLocationPosition() in QuoteProcurementController
     * @param quoteLineId The QuoteLine ID
     * @return List<SBQQ__QuoteLine__c> QuoteLines with position info
     */
    @AuraEnabled
    public static List<SBQQ__QuoteLine__c> getQuoteLinePositions(Id quoteLineId) {
        return [
            SELECT Id, LocationPositionName__c, Location_Position_Name__c,
                   Location_Position_Name__r.Name, Location_Position_Name__r.Container_Position__c
            FROM SBQQ__QuoteLine__c
            WHERE Id = :quoteLineId
            ORDER BY CreatedDate DESC
        ];
    }
}
