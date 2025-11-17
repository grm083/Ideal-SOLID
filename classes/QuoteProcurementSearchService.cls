/**
 * @description QuoteProcurementSearchService - Search and lookup operations layer
 *
 * This service handles all SOSL search operations for vendors, positions, and projects.
 * It provides consistent search interfaces and result formatting.
 *
 * Key Responsibilities:
 * - Vendor SOSL searches
 * - Account Position searches
 * - Project Code searches
 * - Result sorting and formatting
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - Search Operations
 */
public with sharing class QuoteProcurementSearchService {

    // ========================================================================
    // PUBLIC API - VENDOR SEARCH
    // ========================================================================

    /**
     * @description Search for vendors using SOSL
     * Refactored from: searchVendors() in QuoteProcurementController
     * @param searchString The search term
     * @return List<Account> List of matching vendor accounts
     */
    @AuraEnabled
    public static List<Account> searchVendors(String searchString) {
        List<Account> vendorList = new List<Account>();

        List<List<SObject>> searchList = [
            FIND :searchString
            IN ALL FIELDS
            RETURNING Account(
                Id, Name, AccountNumber, Vendor_Business_Unit__c, ShippingState,
                ShippingCity, FacilityCode__c, Parent_Vendor_Id__c, Status__c
                WHERE RecordType.Name = 'Vendor'
            )
        ];

        if (!searchList.isEmpty()) {
            vendorList = (Account[])searchList[0];
        }

        return vendorList;
    }

    // ========================================================================
    // PUBLIC API - POSITION SEARCH
    // ========================================================================

    /**
     * @description Get all positions for a location
     * Refactored from: allPositions() in QuoteProcurementController
     * @param locationId The location Account ID
     * @return List<Account_Position__c> All positions for location
     */
    @AuraEnabled
    public static List<Account_Position__c> getAllPositions(Id locationId) {
        return QuoteProcurementContextGetter.getAllPositions(locationId);
    }

    /**
     * @description Search positions for a location
     * Refactored from: searchPositions() in QuoteProcurementController
     * @param locationId The location Account ID
     * @param searchString The search term (optional)
     * @return List<Account_Position__c> Matching positions
     */
    @AuraEnabled
    public static List<Account_Position__c> searchPositions(Id locationId, String searchString) {
        List<Account_Position__c> positions = new List<Account_Position__c>();

        if (String.isBlank(searchString)) {
            return getAllPositions(locationId);
        }

        List<List<SObject>> searchList = [
            FIND :searchString
            IN ALL FIELDS
            RETURNING Account_Position__c(
                Id, Name, Container_Position__c, AlternateStreet__c,
                AlternateCity__c, AlternateState__c, AlternatePostalCode__c
                WHERE AccountId__c = :locationId
                ORDER BY Container_Position__c ASC
            )
        ];

        if (!searchList.isEmpty()) {
            positions = (Account_Position__c[])searchList[0];
        }

        return positions;
    }

    // ========================================================================
    // PUBLIC API - PROJECT SEARCH
    // ========================================================================

    /**
     * @description Search for active projects
     * Refactored from: getActiveProjects() in QuoteProcurementController
     * @param quoteId The Quote ID
     * @param searchString The search term
     * @return List<Project_Code__c> Matching projects
     */
    @AuraEnabled
    public static List<Project_Code__c> searchActiveProjects(Id quoteId, String searchString) {
        SBQQ__Quote__c currentQuote = [
            SELECT Id, Project__c, Project__r.Name, SBQQ__Account__c, SBQQ__Account__r.ParentId
            FROM SBQQ__Quote__c
            WHERE Id = :quoteId
            LIMIT 1
        ];

        List<List<SObject>> projectSOSL = [
            FIND :searchString
            IN NAME FIELDS
            RETURNING Project_Code__c(
                Id, Name, Project_Manager__r.Name, Program_Manager__r.Name,
                Effective_Date__c, End_Date__c, Duration__c, Company_Category__c
                WHERE Client_Account__c = :currentQuote.SBQQ__Account__r.ParentId
                ORDER BY Project_Manager__r.Name ASC, Effective_Date__c DESC
            )
        ];

        List<Project_Code__c> activeProjects = new List<Project_Code__c>();
        if (!projectSOSL.isEmpty()) {
            activeProjects = (Project_Code__c[])projectSOSL[0];
        }

        return activeProjects;
    }
}
