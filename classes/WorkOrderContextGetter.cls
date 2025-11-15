public class WorkOrderContextGetter {
    
    /* The purpose of the work order context getter is to retrieve data related to work orders only.  
     * These methods should not perform complex mutations or calculations, and should only exist to 
     * retrieve data related to the work order structure
	*/
    
    //Getter methods for work order
    //Method 1 - Return Work Order by Id
    public static Map<Id, WorkOrder> getWorkOrdersByIds(Set<Id> idSet) {

        //Call the universal query utility while limiting on the basis of Id (constraint)
        List<WorkOrder> woList = (List<WorkOrder>) UniversalQueryUtility.universalQuery('WorkOrder', idSet, 'Id');
        Map<Id, WorkOrder> workOrderCache = new Map<Id, WorkOrder>();
        workOrderCache.putAll(woList);
        
        return workOrderCache;
    }
    
    
    //Method 3 - Return WorkOrderLineItems by Work Order Id.  This method could be created in a standalone 
    //Context Getter class, however is being included in work orders due to the single context by which it 
    //would be called.  If use cases evolve to have more targeted work order line item queries then this method
    //should be pulled into a dedicated class.
    public static Map<Id, WorkOrderLineItem> getWorkOrderLinesByWorkOrderId(Set<Id> idSet) {

        //Call the universal query utility while limiting on the basis of Id (constraint)
        List<WorkOrderLineItem> woList = (List<WorkOrderLineItem>) UniversalQueryUtility.universalQuery('WorkOrderLineItem', idSet, 'WorkOrderId');
        Map<Id, WorkOrderLineItem> workOrderLineCache = new Map<Id, WorkOrderLineItem>();
        workOrderLineCache.putAll(woList);
        
        return workOrderLineCache;
    }
}