public class AccountContextGetter {
	
    /* The purpose of the account context getter is to retrieve data related to parent
		and child accounts only.  These methods should not perform complex mutations
		or calculations, and should only exist to retrieve data related to the account structure
	*/
    
    //Getter methods for account
    //Method 1 - Return Client Ids.  This is a redundant method due to two different caches (client and location)
    public static Map<Id, Account> getClientById(Set<Id> idSet) {

        //Call the universal query utility while limiting on the basis of Id (constraint)
        List<Account> accountList = (List<Account>) UniversalQueryUtility.universalQuery('Account', idSet, 'Id');
        Map<Id, Account> clientCache = new Map<Id, Account>(accountList);
        return clientCache;
    }
    
    //Method 2 - Return Location Ids.  This is a redundant method due to two different caches (client and location)
    public static Map<Id, Account> getLocationById(Set<Id> idSet) {

        //Call the universal query utility while limiting on the basis of Id (constraint)
        List<Account> accountList = (List<Account>) UniversalQueryUtility.universalQuery('Account', idSet, 'Id');
        Map<Id, Account> locationCache = new Map<Id, Account>(accountList);
        return locationCache;
    }
    
    //Method 3 - Return Location Ids by parent Id.  This is a redundant method due to two different 
    //caches (client and location)
    public static Map<Id, Account> getLocationsByClientId(Set<Id> idSet) {

        //Call the universal query utility while limiting on the basis of ParentId (constraint)
        List<Account> accountList = (List<Account>) UniversalQueryUtility.universalQuery('Account', idSet, 'ParentId');
        Map<Id, Account> locationCache = new Map<Id, Account>(accountList);
        return locationCache;
    }
}