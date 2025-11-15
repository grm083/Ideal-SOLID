/**
 * @author Waste Management
 * @date 2024
 *
 * @group Cases
 * @group-content ../../ApexDocContent/Cases.htm
 *
 * @description Service class responsible for all Work Order creation logic from Cases.
 *              This centralizes the complex work order generation business logic that was
 *              previously distributed across CaseTriggerHelper and other classes.
 *              
 *              Key responsibilities:
 *              - Creating work orders from cases (single and bulk)
 *              - Handling multi-vendor scenarios
 *              - Managing AM/PM pickup work orders
 *              - Quote order to work order conversion
 *              - Work order line item creation
 *              - Integration with Acorn and external systems
 */
public without sharing class WorkOrderCreation {
    
    // Constants for work order creation
    private static final String WO_STATUS_NEW = 'New';
    private static final String WO_STATUS_ISSUED = 'Issued';
    private static final String ACORN_INTEGRATION = 'Acorn';
    
    /**
     * @description Main entry point for creating work orders from a list of cases
     * @param casesToProcess List of cases ready for work order creation
     * @return Boolean indicating overall success of work order creation
     */
    public static Boolean createWorkOrders(List<Case> casesToProcess) {
        try {
            if (casesToProcess == null || casesToProcess.isEmpty()) {
                return false;
            }
            
            // Separate cases by creation scenario
            Map<String, List<Case>> casesByScenario = categorizeCasesByScenario(casesToProcess);
            
            Boolean allSuccess = true;
            
            // Process standard single work orders
            if (casesByScenario.containsKey('STANDARD')) {
                allSuccess = allSuccess && createStandardWorkOrders(casesByScenario.get('STANDARD'));
            }
            
            // Process multi-vendor work orders
            if (casesByScenario.containsKey('MULTI_VENDOR')) {
                allSuccess = allSuccess && createMultiVendorWorkOrders(casesByScenario.get('MULTI_VENDOR'));
            }
            
            // Process AM/PM work orders
            if (casesByScenario.containsKey('AM_PM')) {
                allSuccess = allSuccess && createAMPMWorkOrders(casesByScenario.get('AM_PM'));
            }
            
            // Process quote order conversions
            if (casesByScenario.containsKey('QUOTE_ORDER')) {
                allSuccess = allSuccess && createWorkOrdersFromQuoteOrders(casesByScenario.get('QUOTE_ORDER'));
            }
            
            return allSuccess;
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return false;
        }
    }
    
    /**
     * @description Categorizes cases into different work order creation scenarios
     * @param casesToProcess Cases to categorize
     * @return Map of scenario type to case lists
     */
    private static Map<String, List<Case>> categorizeCasesByScenario(List<Case> casesToProcess) {
        Map<String, List<Case>> scenarioMap = new Map<String, List<Case>>();
        
        for (Case c : casesToProcess) {
            String scenario = determineCreationScenario(c);
            
            if (!scenarioMap.containsKey(scenario)) {
                scenarioMap.put(scenario, new List<Case>());
            }
            scenarioMap.get(scenario).add(c);
        }
        
        return scenarioMap;
    }
    
    /**
     * @description Determines which work order creation scenario applies to a case
     * @param currentCase Case to evaluate
     * @return String representing the creation scenario
     */
    private static String determineCreationScenario(Case currentCase) {
        // Check for AM/PM scenario
        if (currentCase.Create_AM_and_PM_Pickups__c) {
            return 'AM_PM';
        }
        
        // Check for multi-vendor scenario
        if (currentCase.Is_Multivendor__c) {
            return 'MULTI_VENDOR';
        }
        
        // Check for quote order scenario
        if (currentCase.Source_System__c == 'CPQ' || hasQuoteOrders(currentCase.Id)) {
            return 'QUOTE_ORDER';
        }
        
        // Default to standard single work order
        return 'STANDARD';
    }
    
    /**
     * @description Creates standard single work orders for cases
     * @param standardCases Cases for standard work order creation
     * @return Boolean indicating success
     */
    private static Boolean createStandardWorkOrders(List<Case> standardCases) {
        try {
            List<WorkOrder> workOrdersToInsert = new List<WorkOrder>();
            Map<Id, Case> caseMap = new Map<Id, Case>(standardCases);
            
            // Query related data needed for work order creation
            Map<Id, List<SBS_Case_Asset__c>> caseAssetMap = getCaseAssets(caseMap.keySet());
            Map<Id, Account> vendorMap = getVendorAccounts(caseAssetMap);
            
            for (Case currentCase : standardCases) {
                // Create primary work order
                WorkOrder wo = buildWorkOrderFromCase(currentCase, caseAssetMap, vendorMap);
                
                if (wo != null) {
                    workOrdersToInsert.add(wo);
                }
            }
            
            if (!workOrdersToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(workOrdersToInsert, false);
                Boolean success = processWorkOrderInsertResults(results, workOrdersToInsert, caseMap);
                
                // Create work order line items
                if (success) {
                    createWorkOrderLineItems(workOrdersToInsert, caseAssetMap);
                }
                
                return success;
            }
            
            return true;
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return false;
        }
    }
    
    /**
     * @description Creates work orders for multi-vendor scenarios
     * @param multiVendorCases Cases requiring multiple vendors
     * @return Boolean indicating success
     */
    private static Boolean createMultiVendorWorkOrders(List<Case> multiVendorCases) {
        try {
            List<WorkOrder> workOrdersToInsert = new List<WorkOrder>();
            Map<Id, Case> caseMap = new Map<Id, Case>(multiVendorCases);
            
            // Query case assets grouped by vendor
            Map<Id, Map<Id, List<SBS_Case_Asset__c>>> caseAssetsByVendor = 
                getCaseAssetsGroupedByVendor(caseMap.keySet());
            Map<Id, Account> vendorMap = getVendorAccountsForMultiVendor(caseAssetsByVendor);
            
            for (Case currentCase : multiVendorCases) {
                Map<Id, List<SBS_Case_Asset__c>> vendorAssetMap = caseAssetsByVendor.get(currentCase.Id);
                
                if (vendorAssetMap != null && !vendorAssetMap.isEmpty()) {
                    // Create one work order per vendor
                    for (Id vendorId : vendorAssetMap.keySet()) {
                        WorkOrder wo = buildMultiVendorWorkOrder(
                            currentCase, 
                            vendorId, 
                            vendorAssetMap.get(vendorId),
                            vendorMap
                        );
                        
                        if (wo != null) {
                            workOrdersToInsert.add(wo);
                        }
                    }
                }
            }
            
            if (!workOrdersToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(workOrdersToInsert, false);
                Boolean success = processWorkOrderInsertResults(results, workOrdersToInsert, caseMap);
                
                // Create work order line items for multi-vendor scenario
                if (success) {
                    createMultiVendorWorkOrderLineItems(workOrdersToInsert, caseAssetsByVendor);
                }
                
                return success;
            }
            
            return true;
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return false;
        }
    }
    
    /**
     * @description Creates AM and PM work orders for cases requiring both
     * @param amPmCases Cases requiring AM/PM work orders
     * @return Boolean indicating success
     */
    private static Boolean createAMPMWorkOrders(List<Case> amPmCases) {
        try {
            List<WorkOrder> workOrdersToInsert = new List<WorkOrder>();
            Map<Id, Case> caseMap = new Map<Id, Case>(amPmCases);
            
            Map<Id, List<SBS_Case_Asset__c>> caseAssetMap = getCaseAssets(caseMap.keySet());
            Map<Id, Account> vendorMap = getVendorAccounts(caseAssetMap);
            
            for (Case currentCase : amPmCases) {
                // Create AM work order
                WorkOrder amWO = buildAMWorkOrder(currentCase, caseAssetMap, vendorMap);
                if (amWO != null) {
                    workOrdersToInsert.add(amWO);
                }
                
                // Create PM work order
                WorkOrder pmWO = buildPMWorkOrder(currentCase, caseAssetMap, vendorMap);
                if (pmWO != null) {
                    workOrdersToInsert.add(pmWO);
                }
            }
            
            if (!workOrdersToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(workOrdersToInsert, false);
                Boolean success = processWorkOrderInsertResults(results, workOrdersToInsert, caseMap);
                
                // Create line items for AM/PM work orders
                if (success) {
                    createAMPMWorkOrderLineItems(workOrdersToInsert, caseAssetMap);
                }
                
                return success;
            }
            
            return true;
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return false;
        }
    }
    
    /**
     * @description Converts quote orders into work orders
     * @param quoteOrderCases Cases with associated quote orders
     * @return Boolean indicating success
     */
    private static Boolean createWorkOrdersFromQuoteOrders(List<Case> quoteOrderCases) {
        try {
            List<WorkOrder> workOrdersToInsert = new List<WorkOrder>();
            Map<Id, Case> caseMap = new Map<Id, Case>(quoteOrderCases);
            
            // Query quote orders for these cases
            Map<Id, List<Quote_Order__c>> caseQuoteOrderMap = getQuoteOrders(caseMap.keySet());
            Map<Id, SBQQ__QuoteLine__c> quoteLineMap = getQuoteLines(caseQuoteOrderMap);
            Map<Id, Account> vendorMap = getVendorAccountsFromQuoteOrders(caseQuoteOrderMap);
            
            for (Case currentCase : quoteOrderCases) {
                List<Quote_Order__c> quoteOrders = caseQuoteOrderMap.get(currentCase.Id);
                
                if (quoteOrders != null && !quoteOrders.isEmpty()) {
                    for (Quote_Order__c qo : quoteOrders) {
                        // Skip if bypass flag is set
                        if (qo.Bypass_Work_Order__c) {
                            continue;
                        }
                        
                        WorkOrder wo = buildWorkOrderFromQuoteOrder(
                            currentCase, 
                            qo, 
                            quoteLineMap,
                            vendorMap
                        );
                        
                        if (wo != null) {
                            workOrdersToInsert.add(wo);
                        }
                    }
                }
            }
            
            if (!workOrdersToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(workOrdersToInsert, false);
                Boolean success = processWorkOrderInsertResults(results, workOrdersToInsert, caseMap);
                
                // Create line items from quote order details
                if (success) {
                    createWorkOrderLineItemsFromQuoteOrders(workOrdersToInsert, caseQuoteOrderMap, quoteLineMap);
                }
                
                return success;
            }
            
            return true;
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return false;
        }
    }
    
    // ========================================
    // WORK ORDER BUILDER METHODS
    // ========================================
    
    /**
     * @description Builds a standard work order from a case
     * @param currentCase Case to create work order from
     * @param caseAssetMap Map of case assets
     * @param vendorMap Map of vendor accounts
     * @return WorkOrder record ready for insert
     */
    private static WorkOrder buildWorkOrderFromCase(Case currentCase, 
                                                    Map<Id, List<SBS_Case_Asset__c>> caseAssetMap,
                                                    Map<Id, Account> vendorMap) {
        try {
            WorkOrder wo = new WorkOrder();
            
            // Core case fields
            wo.CaseId = currentCase.Id;
            wo.AccountId = currentCase.Client__c;
            wo.ContactId = currentCase.ContactId;
            wo.AssetId = currentCase.AssetId;
            wo.LocationId = currentCase.Location__c;
            
            // Service details
            wo.Service_Date__c = currentCase.Service_Date__c;
            wo.SLA_Service_Date_Time__c = currentCase.SLA_Service_Date_Time__c;
            wo.Subject = buildWorkOrderSubject(currentCase);
            wo.Description = buildWorkOrderDescription(currentCase);
            wo.Instructions__c = currentCase.Work_Order_Instructions__c;
            
            // Vendor and supplier information
            List<SBS_Case_Asset__c> caseAssets = caseAssetMap.get(currentCase.Id);
            if (caseAssets != null && !caseAssets.isEmpty()) {
                SBS_Case_Asset__c primaryAsset = caseAssets[0];
                wo.Vendor_Account_Id__c = primaryAsset.AssetId__r.Supplier__c;
            }
            
            // Status and flags
            wo.Status = WO_STATUS_NEW;
            wo.Is_Bypass__c = CaseBusinessRuleService.shouldBypassDuplicateCheck(currentCase);
            
            return wo;
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return null;
        }
    }
    
    /**
     * @description Builds a work order for multi-vendor scenario
     * @param currentCase Parent case
     * @param vendorId Vendor for this work order
     * @param vendorAssets Assets for this vendor
     * @param vendorMap Vendor account details
     * @return WorkOrder for specific vendor
     */
    private static WorkOrder buildMultiVendorWorkOrder(Case currentCase, 
                                                       Id vendorId,
                                                       List<SBS_Case_Asset__c> vendorAssets,
                                                       Map<Id, Account> vendorMap) {
        try {
            WorkOrder wo = buildWorkOrderFromCase(currentCase, 
                new Map<Id, List<SBS_Case_Asset__c>>{currentCase.Id => vendorAssets}, 
                vendorMap);
            
            if (wo != null) {
                wo.Vendor_Account_Id__c = vendorId;

            }
            
            return wo;
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return null;
        }
    }
    
    /**
     * @description Builds AM work order
     * @param currentCase Case requiring AM work order
     * @param caseAssetMap Case assets
     * @param vendorMap Vendors
     * @return AM WorkOrder
     */
    private static WorkOrder buildAMWorkOrder(Case currentCase,
                                             Map<Id, List<SBS_Case_Asset__c>> caseAssetMap,
                                             Map<Id, Account> vendorMap) {
        WorkOrder wo = buildWorkOrderFromCase(currentCase, caseAssetMap, vendorMap);
        
        if (wo != null) {
            wo.Description = 'AM Pickup - ' + (wo.Description != null ? wo.Description : '');
        }
        
        return wo;
    }
    
    /**
     * @description Builds PM work order
     * @param currentCase Case requiring PM work order
     * @param caseAssetMap Case assets
     * @param vendorMap Vendors
     * @return PM WorkOrder
     */
    private static WorkOrder buildPMWorkOrder(Case currentCase,
                                             Map<Id, List<SBS_Case_Asset__c>> caseAssetMap,
                                             Map<Id, Account> vendorMap) {
        WorkOrder wo = buildWorkOrderFromCase(currentCase, caseAssetMap, vendorMap);
        
        if (wo != null) {
            wo.Description = 'PM Pickup - ' + (wo.Description != null ? wo.Description : '');
        }
        
        return wo;
    }
    
    /**
     * @description Builds work order from quote order
     * @param currentCase Parent case
     * @param quoteOrder Quote order to convert
     * @param quoteLineMap Quote line details
     * @param vendorMap Vendor accounts
     * @return WorkOrder from quote order
     */
    private static WorkOrder buildWorkOrderFromQuoteOrder(Case currentCase,
                                                          Quote_Order__c quoteOrder,
                                                          Map<Id, SBQQ__QuoteLine__c> quoteLineMap,
                                                          Map<Id, Account> vendorMap) {
        try {
            WorkOrder wo = new WorkOrder();
            
            // Core fields from case
            wo.CaseId = currentCase.Id;
            wo.AccountId = currentCase.Client__c;
            wo.ContactId = quoteOrder.Onsite_Contact__c != null ? 
                currentCase.ContactId : currentCase.ContactId;
            wo.LocationId = currentCase.Location__c;
            
            // Service details from quote order
            wo.Service_Date__c = quoteOrder.Service_Date__c;
            wo.Instructions__c = quoteOrder.Service_Time_Span__c;
            wo.Subject = quoteOrder.Service_Type__c + ' - ' + quoteOrder.Product_Type__c;
            
            // Instructions and contact
            wo.Instructions__c += quoteOrder.Instructions__c;
            
            // Quote order reference
            wo.Quote_Order__c = quoteOrder.Id;
            
            // Status
            wo.Status = WO_STATUS_NEW;
            
            // Get vendor from quote line
            if (quoteOrder.Service_Quote_Line__c != null && 
                quoteLineMap.containsKey(quoteOrder.Service_Quote_Line__c)) {
                SBQQ__QuoteLine__c quoteLine = quoteLineMap.get(quoteOrder.Service_Quote_Line__c);
                
                // Vendor information would come from asset/product
                if (currentCase.AssetId != null) {
                    wo.AssetId = currentCase.AssetId;
                }
            }
            
            return wo;
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
            return null;
        }
    }
    
    // ========================================
    // WORK ORDER LINE ITEM CREATION METHODS
    // ========================================
    
    /**
     * @description Creates work order line items for standard work orders
     * @param workOrders Created work orders
     * @param caseAssetMap Case assets
     */
    private static void createWorkOrderLineItems(List<WorkOrder> workOrders,
                                                 Map<Id, List<SBS_Case_Asset__c>> caseAssetMap) {
        try {
            List<WorkOrderLineItem> lineItemsToInsert = new List<WorkOrderLineItem>();
            
            for (WorkOrder wo : workOrders) {
                if (wo.Id != null && wo.CaseId != null) {
                    List<SBS_Case_Asset__c> caseAssets = caseAssetMap.get(wo.CaseId);
                    
                    if (caseAssets != null) {
                        for (SBS_Case_Asset__c caseAsset : caseAssets) {
                            WorkOrderLineItem woli = new WorkOrderLineItem();
                            woli.WorkOrderId = wo.Id;
                            woli.AssetId = caseAsset.AssetId__c;
                            woli.Quantity = caseAsset.Quantity_Override__c != null ? 
                                caseAsset.Quantity_Override__c : 1;
                            woli.Description = caseAsset.AssetId__r.Name;
                            
                            lineItemsToInsert.add(woli);
                        }
                    }
                }
            }
            
            if (!lineItemsToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(lineItemsToInsert, false);
                UTIL_LoggingService.logDmlResults(results, null, lineItemsToInsert, '',
                    'WorkOrderCreation', '', 'createWorkOrderLineItems', LoggingLevel.ERROR);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
     * @description Creates line items for multi-vendor work orders
     * @param workOrders Created work orders
     * @param caseAssetsByVendor Case assets grouped by vendor
     */
    private static void createMultiVendorWorkOrderLineItems(List<WorkOrder> workOrders,
                                                           Map<Id, Map<Id, List<SBS_Case_Asset__c>>> caseAssetsByVendor) {
        try {
            List<WorkOrderLineItem> lineItemsToInsert = new List<WorkOrderLineItem>();
            
            for (WorkOrder wo : workOrders) {
                if (wo.Id != null && wo.CaseId != null && wo.Vendor_Account_Id__c != null) {
                    Map<Id, List<SBS_Case_Asset__c>> vendorAssetMap = caseAssetsByVendor.get(wo.CaseId);
                    
                    if (vendorAssetMap != null && vendorAssetMap.containsKey(wo.Vendor_Account_Id__c)) {
                        List<SBS_Case_Asset__c> vendorAssets = vendorAssetMap.get(wo.Vendor_Account_Id__c);
                        
                        for (SBS_Case_Asset__c caseAsset : vendorAssets) {
                            WorkOrderLineItem woli = new WorkOrderLineItem();
                            woli.WorkOrderId = wo.Id;
                            woli.AssetId = caseAsset.AssetId__c;
                            woli.Quantity = caseAsset.Quantity_Override__c != null ? 
                                caseAsset.Quantity_Override__c : 1;
                            woli.Description = caseAsset.AssetId__r.Name;
                            
                            lineItemsToInsert.add(woli);
                        }
                    }
                }
            }
            
            if (!lineItemsToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(lineItemsToInsert, false);
                UTIL_LoggingService.logDmlResults(results, null, lineItemsToInsert, '',
                    'WorkOrderCreation', '', 'createMultiVendorWorkOrderLineItems', LoggingLevel.ERROR);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    /**
     * @description Creates line items for AM/PM work orders
     * @param workOrders Created work orders
     * @param caseAssetMap Case assets
     */
    private static void createAMPMWorkOrderLineItems(List<WorkOrder> workOrders,
                                                    Map<Id, List<SBS_Case_Asset__c>> caseAssetMap) {
        // AM/PM line items follow same logic as standard
        createWorkOrderLineItems(workOrders, caseAssetMap);
    }
    
    /**
     * @description Creates line items from quote order details
     * @param workOrders Created work orders
     * @param caseQuoteOrderMap Quote orders by case
     * @param quoteLineMap Quote line details
     */
    private static void createWorkOrderLineItemsFromQuoteOrders(List<WorkOrder> workOrders,
                                                               Map<Id, List<Quote_Order__c>> caseQuoteOrderMap,
                                                               Map<Id, SBQQ__QuoteLine__c> quoteLineMap) {
        try {
            List<WorkOrderLineItem> lineItemsToInsert = new List<WorkOrderLineItem>();
            
            for (WorkOrder wo : workOrders) {
                if (wo.Id != null && wo.Quote_Order__c != null) {
                    // Find the quote order for this work order
                    for (List<Quote_Order__c> qoList : caseQuoteOrderMap.values()) {
                        for (Quote_Order__c qo : qoList) {
                            if (qo.Id == wo.Quote_Order__c) {
                                // Create line item from quote line
                                if (qo.Service_Quote_Line__c != null && 
                                    quoteLineMap.containsKey(qo.Service_Quote_Line__c)) {
                                    
                                    SBQQ__QuoteLine__c quoteLine = quoteLineMap.get(qo.Service_Quote_Line__c);
                                    
                                    WorkOrderLineItem woli = new WorkOrderLineItem();
                                    woli.WorkOrderId = wo.Id;
                                    woli.Description = quoteLine.SBQQ__Product__r.Name;
                                    woli.Quantity = quoteLine.SBQQ__Quantity__c;
                                    
                                    lineItemsToInsert.add(woli);
                                }
                                break;
                            }
                        }
                    }
                }
            }
            
            if (!lineItemsToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(lineItemsToInsert, false);
                UTIL_LoggingService.logDmlResults(results, null, lineItemsToInsert, '',
                    'WorkOrderCreation', '', 'createWorkOrderLineItemsFromQuoteOrders', LoggingLevel.ERROR);
            }
            
        } catch (Exception ex) {
            UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
                UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
        }
    }
    
    // ========================================
    // HELPER AND UTILITY METHODS
    // ========================================
    
    /**
     * @description Builds work order subject line
     * @param currentCase Case for work order
     * @return String subject line
     */
    private static String buildWorkOrderSubject(Case currentCase) {
        return currentCase.Case_Type__c + ' - ' + currentCase.Case_Sub_type__c;
    }
    
    /**
     * @description Builds work order description
     * @param currentCase Case for work order
     * @return String description
     */
    private static String buildWorkOrderDescription(Case currentCase) {
        String description = '';
        
        if (String.isNotBlank(currentCase.Case_Reason__c)) {
            description += currentCase.Case_Reason__c + ' - ';
        }
        
        if (String.isNotBlank(currentCase.Reference_Number__c)) {
            description += 'Ref: ' + currentCase.Reference_Number__c;
        }
        
        return description;
    }
    
    /**
     * @description Checks if case has quote orders
     * @param caseId Case to check
     * @return Boolean indicating presence of quote orders
     */
    private static Boolean hasQuoteOrders(Id caseId) {
        try {
            Integer count = [SELECT COUNT() FROM Quote_Order__c 
                           WHERE Quote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__c = :caseId 
                           LIMIT 1];
            return count > 0;
        } catch (Exception ex) {
            return false;
        }
    }
    
    /**
     * @description Retrieves case assets for cases
     * @param caseIds Cases to get assets for
     * @return Map of case ID to case assets
     */
    private static Map<Id, List<SBS_Case_Asset__c>> getCaseAssets(Set<Id> caseIds) {
        Map<Id, List<SBS_Case_Asset__c>> caseAssetMap = new Map<Id, List<SBS_Case_Asset__c>>();
        
        for (SBS_Case_Asset__c ca : [
            SELECT Id, CaseId__c, AssetId__c, AssetId__r.Name, AssetId__r.Supplier__c,
                   AssetId__r.Vendor_ID__c, Asset_Service_Type__c, Quantity_Override__c,
                   New_Client_Price__c, Original_Client_Price__c, Reason_Code__c,
                   Reason_Description__c
            FROM SBS_Case_Asset__c
            WHERE CaseId__c IN :caseIds
            ORDER BY CreatedDate
        ]) {
            if (!caseAssetMap.containsKey(ca.CaseId__c)) {
                caseAssetMap.put(ca.CaseId__c, new List<SBS_Case_Asset__c>());
            }
            caseAssetMap.get(ca.CaseId__c).add(ca);
        }
        
        return caseAssetMap;
    }
    
    /**
     * @description Retrieves case assets grouped by vendor
     * @param caseIds Cases to process
     * @return Map of case ID to vendor ID to assets
     */
    private static Map<Id, Map<Id, List<SBS_Case_Asset__c>>> getCaseAssetsGroupedByVendor(Set<Id> caseIds) {
        Map<Id, Map<Id, List<SBS_Case_Asset__c>>> result = new Map<Id, Map<Id, List<SBS_Case_Asset__c>>>();
        
        for (SBS_Case_Asset__c ca : [
            SELECT Id, CaseId__c, AssetId__c, AssetId__r.Name, AssetId__r.Supplier__c,
                   AssetId__r.Vendor_ID__c, Asset_Service_Type__c, Quantity_Override__c
            FROM SBS_Case_Asset__c
            WHERE CaseId__c IN :caseIds
            ORDER BY CreatedDate
        ]) {
            if (!result.containsKey(ca.CaseId__c)) {
                result.put(ca.CaseId__c, new Map<Id, List<SBS_Case_Asset__c>>());
            }
            
            Id vendorId = ca.AssetId__r.Supplier__c;
            if (!result.get(ca.CaseId__c).containsKey(vendorId)) {
                result.get(ca.CaseId__c).put(vendorId, new List<SBS_Case_Asset__c>());
            }
            
            result.get(ca.CaseId__c).get(vendorId).add(ca);
        }
        
        return result;
    }
    
    /**
     * @description Gets vendor accounts from case assets
     * @param caseAssetMap Case assets
     * @return Map of vendor accounts
     */
    private static Map<Id, Account> getVendorAccounts(Map<Id, List<SBS_Case_Asset__c>> caseAssetMap) {
        Set<Id> vendorIds = new Set<Id>();
        
        for (List<SBS_Case_Asset__c> caList : caseAssetMap.values()) {
            for (SBS_Case_Asset__c ca : caList) {
                if (ca.AssetId__r.Supplier__c != null) {
                    vendorIds.add(ca.AssetId__r.Supplier__c);
                }
            }
        }
        
        return new Map<Id, Account>([
            SELECT Id, Name, Contact_Manually_Vendor__c, Vendor_ID__c
            FROM Account
            WHERE Id IN :vendorIds
        ]);
    }
    
    /**
     * @description Gets vendor accounts for multi-vendor scenario
     * @param caseAssetsByVendor Case assets grouped by vendor
     * @return Map of vendor accounts
     */
    private static Map<Id, Account> getVendorAccountsForMultiVendor(
        Map<Id, Map<Id, List<SBS_Case_Asset__c>>> caseAssetsByVendor) {
        
        Set<Id> vendorIds = new Set<Id>();
        
        for (Map<Id, List<SBS_Case_Asset__c>> vendorMap : caseAssetsByVendor.values()) {
            vendorIds.addAll(vendorMap.keySet());
        }
        
        return new Map<Id, Account>([
            SELECT Id, Name, Contact_Manually_Vendor__c, Vendor_ID__c
            FROM Account
            WHERE Id IN :vendorIds
        ]);
    }
    
    /**
     * @description Gets quote orders for cases
     * @param caseIds Cases to get quote orders for
     * @return Map of case ID to quote orders
     */
    private static Map<Id, List<Quote_Order__c>> getQuoteOrders(Set<Id> caseIds) {
        Map<Id, List<Quote_Order__c>> result = new Map<Id, List<Quote_Order__c>>();
        
        for (Quote_Order__c qo : [
            SELECT Id, Quote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__c,
                   Service_Type__c, Product_Type__c, Service_Date__c, Service_Time_Span__c,
                   Onsite_Contact__c, Onsite_Contact_Phone__c, Instructions__c,
                   Cust_Ref_Number__c, Service_Quote_Line__c, Bypass_Work_Order__c
            FROM Quote_Order__c
            WHERE Quote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__c IN :caseIds
        ]) {
            Id caseId = qo.Quote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Case__c;
            
            if (!result.containsKey(caseId)) {
                result.put(caseId, new List<Quote_Order__c>());
            }
            result.get(caseId).add(qo);
        }
        
        return result;
    }
    
    /**
     * @description Gets quote lines
     * @param caseQuoteOrderMap Quote orders to get lines for
     * @return Map of quote line ID to quote line
     */
    private static Map<Id, SBQQ__QuoteLine__c> getQuoteLines(Map<Id, List<Quote_Order__c>> caseQuoteOrderMap) {
        Set<Id> quoteLineIds = new Set<Id>();
        
        for (List<Quote_Order__c> qoList : caseQuoteOrderMap.values()) {
            for (Quote_Order__c qo : qoList) {
                if (qo.Service_Quote_Line__c != null) {
                    quoteLineIds.add(qo.Service_Quote_Line__c);
                }
            }
        }
        
        return new Map<Id, SBQQ__QuoteLine__c>([
            SELECT Id, SBQQ__Product__r.Name, SBQQ__Quantity__c,
                   SBQQ__StartDate__c, SBQQ__EndDate__c
            FROM SBQQ__QuoteLine__c
            WHERE Id IN :quoteLineIds
        ]);
    }
    
    /**
     * @description Gets vendor accounts from quote orders
     * @param caseQuoteOrderMap Quote orders
     * @return Map of vendor accounts
     */
    private static Map<Id, Account> getVendorAccountsFromQuoteOrders(Map<Id, List<Quote_Order__c>> caseQuoteOrderMap) {
        // Vendor determination from quote orders would require additional logic
        // based on product/service type and business rules
        return new Map<Id, Account>();
    }
    
    /**
     * @description Processes work order insert results and logs errors
     * @param results Database save results
     * @param workOrders Work orders that were inserted
     * @param caseMap Related cases
     * @return Boolean indicating if all were successful
     */
    private static Boolean processWorkOrderInsertResults(Database.SaveResult[] results,
                                                         List<WorkOrder> workOrders,
                                                         Map<Id, Case> caseMap) {
        Boolean allSuccess = true;
        
        UTIL_LoggingService.logDmlResults(results, null, workOrders, '',
            'WorkOrderCreation', '', 'createWorkOrders', LoggingLevel.ERROR);
        
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                allSuccess = false;
            }
        }
        
        return allSuccess;
    }
}