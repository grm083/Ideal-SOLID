/**
 * @description WorkOrderContextGetter - Data Access Layer for WorkOrder Records
 *
 * The purpose of the work order context getter is to retrieve data related to work orders only.
 * These methods should not perform complex mutations or calculations, and should only exist to
 * retrieve data related to the work order structure.
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer
 */
public class WorkOrderContextGetter {

    // ========================================================================
    // CACHE STRUCTURES
    // ========================================================================

    /**
     * @description Cache for WorkOrder records to avoid redundant queries
     */
    private static Map<Id, WorkOrder> workOrderCache = new Map<Id, WorkOrder>();

    // ========================================================================
    // WORKORDER QUERY METHODS
    // ========================================================================

    /**
     * @description Return Work Order by Ids using UniversalQueryUtility
     * @param idSet Set of WorkOrder Ids
     * @return Map of WorkOrder Ids to WorkOrder records
     */
    public static Map<Id, WorkOrder> getWorkOrdersByIds(Set<Id> idSet) {
        // Call the universal query utility while limiting on the basis of Id (constraint)
        List<WorkOrder> woList = (List<WorkOrder>) UniversalQueryUtility.universalQuery('WorkOrder', idSet, 'Id');
        Map<Id, WorkOrder> workOrderMap = new Map<Id, WorkOrder>();
        workOrderMap.putAll(woList);

        // Update cache
        workOrderCache.putAll(workOrderMap);

        return workOrderMap;
    }

    /**
     * @description Retrieves WorkOrders by Case Ids
     * @param caseIds Set of Case Ids
     * @return Map of Case Id to List of WorkOrders
     */
    public static Map<Id, List<WorkOrder>> getWorkOrdersByCaseIds(Set<Id> caseIds) {
        Map<Id, List<WorkOrder>> results = new Map<Id, List<WorkOrder>>();

        // Use UniversalQueryUtility with CaseId constraint
        List<WorkOrder> workOrders = (List<WorkOrder>) UniversalQueryUtility.universalQuery('WorkOrder', caseIds, 'CaseId');

        for (WorkOrder wo : workOrders) {
            if (!results.containsKey(wo.CaseId)) {
                results.put(wo.CaseId, new List<WorkOrder>());
            }
            results.get(wo.CaseId).add(wo);
            workOrderCache.put(wo.Id, wo);
        }

        return results;
    }

    /**
     * @description Retrieves WorkOrders by single Case Id
     * @param caseId The Case Id
     * @return List of WorkOrders for the case
     */
    public static List<WorkOrder> getWorkOrderByCaseId(Id caseId) {
        Map<Id, List<WorkOrder>> results = getWorkOrdersByCaseIds(new Set<Id>{caseId});
        List<WorkOrder> workOrders = results.get(caseId);

        if (workOrders == null) {
            workOrders = new List<WorkOrder>();
        }

        return workOrders;
    }

    /**
     * @description Counts WorkOrders matching specific criteria for occurrence limit validation
     * @param assetIds Set of Asset Ids
     * @param locationIds Set of Location Ids
     * @param caseSubtype Case subtype to filter on
     * @param startDate Start date for date range
     * @param endDate End date for date range
     * @return Map of composite key to count of work orders
     */
    public static Map<String, Integer> getWorkOrderCounts(
        Set<Id> assetIds,
        Set<Id> locationIds,
        String caseSubtype,
        Date startDate,
        Date endDate
    ) {
        Map<String, Integer> workOrderCounts = new Map<String, Integer>();
        Set<String> workOrderStatus = new Set<String>{
            Constant_Util.INPROGRESS,
            Constant_Util.STATUS_NEW,
            Constant_Util.COMPLETED,
            Constant_Util.CLOSED
        };

        List<AggregateResult> results = [
            SELECT COUNT(Id) num, AssetId, Customer_Location__c, Case.Case_Sub_Type__c
            FROM WorkOrder
            WHERE AssetId IN :assetIds
            AND Customer_Location__c IN :locationIds
            AND StatusCategory IN :workOrderStatus
            AND Case_Subtype__c = :caseSubtype
            AND Is_Bypass__c = false
            AND Service_Date__c >= :startDate
            AND Service_Date__c <= :endDate
            GROUP BY AssetId, Customer_Location__c, Case.Case_Sub_Type__c
        ];

        for (AggregateResult ar : results) {
            String key = String.valueOf(ar.get('AssetId')) +
                        String.valueOf(ar.get('Customer_Location__c')) +
                        String.valueOf(ar.get('Case_Sub_Type__c'));
            workOrderCounts.put(key, (Integer)ar.get('num'));
        }

        return workOrderCounts;
    }

    /**
     * @description Retrieves WorkOrders by Asset Ids
     * @param assetIds Set of Asset Ids
     * @return Map of Asset Id to List of WorkOrders
     */
    public static Map<Id, List<WorkOrder>> getWorkOrdersByAssetIds(Set<Id> assetIds) {
        Map<Id, List<WorkOrder>> results = new Map<Id, List<WorkOrder>>();

        // Use UniversalQueryUtility with AssetId constraint
        List<WorkOrder> workOrders = (List<WorkOrder>) UniversalQueryUtility.universalQuery('WorkOrder', assetIds, 'AssetId');

        for (WorkOrder wo : workOrders) {
            if (!results.containsKey(wo.AssetId)) {
                results.put(wo.AssetId, new List<WorkOrder>());
            }
            results.get(wo.AssetId).add(wo);
            workOrderCache.put(wo.Id, wo);
        }

        return results;
    }

    /**
     * @description Retrieves active WorkOrders (non-completed, non-cancelled) by Case Ids
     * @param caseIds Set of Case Ids
     * @return List of active WorkOrders
     */
    public static List<WorkOrder> getActiveWorkOrdersByCaseIds(Set<Id> caseIds) {
        Set<String> activeStatuses = new Set<String>{
            Constant_Util.INPROGRESS,
            Constant_Util.STATUS_NEW,
            'Dispatched',
            'Scheduled'
        };

        List<WorkOrder> allWorkOrders = (List<WorkOrder>) UniversalQueryUtility.universalQuery('WorkOrder', caseIds, 'CaseId');
        List<WorkOrder> activeWorkOrders = new List<WorkOrder>();

        for (WorkOrder wo : allWorkOrders) {
            if (activeStatuses.contains(wo.StatusCategory)) {
                activeWorkOrders.add(wo);
            }
        }

        return activeWorkOrders;
    }

    // ========================================================================
    // WORKORDER LINE ITEM METHODS
    // ========================================================================

    /**
     * @description Return WorkOrderLineItems by Work Order Id
     * This method could be created in a standalone Context Getter class, however is being included
     * in work orders due to the single context by which it would be called. If use cases evolve to
     * have more targeted work order line item queries then this method should be pulled into a dedicated class.
     * @param idSet Set of WorkOrder Ids
     * @return Map of WorkOrderLineItem Ids to WorkOrderLineItem records
     */
    public static Map<Id, WorkOrderLineItem> getWorkOrderLinesByWorkOrderId(Set<Id> idSet) {
        // Call the universal query utility while limiting on the basis of WorkOrderId (constraint)
        List<WorkOrderLineItem> woList = (List<WorkOrderLineItem>) UniversalQueryUtility.universalQuery('WorkOrderLineItem', idSet, 'WorkOrderId');
        Map<Id, WorkOrderLineItem> workOrderLineCache = new Map<Id, WorkOrderLineItem>();
        workOrderLineCache.putAll(woList);

        return workOrderLineCache;
    }

    /**
     * @description Retrieves WorkOrder LineItems grouped by WorkOrder Id
     * @param workOrderIds Set of WorkOrder Ids
     * @return Map of WorkOrder Id to List of WorkOrderLineItems
     */
    public static Map<Id, List<WorkOrderLineItem>> getWorkOrderLineItemsByWorkOrderIds(Set<Id> workOrderIds) {
        Map<Id, List<WorkOrderLineItem>> results = new Map<Id, List<WorkOrderLineItem>>();

        List<WorkOrderLineItem> lineItems = (List<WorkOrderLineItem>) UniversalQueryUtility.universalQuery('WorkOrderLineItem', workOrderIds, 'WorkOrderId');

        for (WorkOrderLineItem item : lineItems) {
            if (!results.containsKey(item.WorkOrderId)) {
                results.put(item.WorkOrderId, new List<WorkOrderLineItem>());
            }
            results.get(item.WorkOrderId).add(item);
        }

        return results;
    }

    // ========================================================================
    // UTILITY METHODS
    // ========================================================================

    /**
     * @description Clears all caches - useful for testing or transaction boundaries
     */
    public static void clearCaches() {
        workOrderCache.clear();
    }

    /**
     * @description Checks if a WorkOrder Id is already cached
     * @param workOrderId The WorkOrder Id to check
     * @return true if cached, false otherwise
     */
    public static Boolean isWorkOrderCached(Id workOrderId) {
        return workOrderCache.containsKey(workOrderId);
    }

    /**
     * @description Gets the current size of the work order cache
     * @return Number of cached WorkOrder records
     */
    public static Integer getWorkOrderCacheSize() {
        return workOrderCache.size();
    }
}