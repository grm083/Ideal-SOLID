public class AssetContextGetter {

    /* The purpose of the task context getter is to retrieve data related to tasks only.  
     * These methods should not perform complex mutations or calculations, and should only exist to 
     * retrieve data related to the task structure
	*/
     public static Map<Id, Asset> getHeaderById(Set<Id> idSet) {

        //Call the universal query utility while limiting on the basis of Id (constraint)
        List<Asset> objList = (List<Asset>) UniversalQueryUtility.universalQuery('Asset', idSet, 'Id');
        Map<Id, Asset> assetCache = new Map<Id, Asset>();
        assetCache.putAll(objList);
        
        return assetCache;
    }
    
    //Method 2 - Return asset details by header Id.
    public static Map<Id, Asset> getDetailsbyHeaderId(Set<Id> idSet) {

        //Call the universal query utility while limiting on the basis of Id (constraint)
        List<Asset> objList = (List<Asset>) UniversalQueryUtility.universalQuery('Asset', idSet, 'ParentId');
        Map<Id, Asset> assetCache = new Map<Id, Asset>();
        assetCache.putAll(objList);
        
        return assetCache;
    }
    
}