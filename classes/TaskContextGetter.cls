public class TaskContextGetter {
	
    /* The purpose of the task context getter is to retrieve data related to tasks only.  
     * These methods should not perform complex mutations or calculations, and should only exist to 
     * retrieve data related to the task structure
	*/
    
    //Getter methods for work order
    //Method 1 - Return Work Order by Id
    public static Map<Id, Task> getTaskById(Set<Id> idSet) {

        //Call the universal query utility while limiting on the basis of Id (constraint)
        List<Task> objList = (List<Task>) UniversalQueryUtility.universalQuery('Task', idSet, 'Id');
        Map<Id, Task> taskCache = new Map<Id, Task>();
        taskCache.putAll(objList);
        
        return taskCache;
    }
    
}