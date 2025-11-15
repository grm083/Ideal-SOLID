public class ContactContextGetter {

    /* The purpose of the contact context getter is to retrieve data related to contacts only.  
     * These methods should not perform complex mutations or calculations, and should only exist 
     * to retrieve data related to the contact structure
	*/
    
    //Getter methods for account
    //Method 1 - Return Contact records.
    public static Map<Id, Contact> getContactById(Set<Id> idSet) {

        //Call the universal query utility while limiting on the basis of Id (constraint)
        List<Contact> contactList = (List<Contact>) UniversalQueryUtility.universalQuery('Contact', idSet, 'Id');
        Map<Id, Contact> contactCache = new Map<Id, Contact>();
        contactCache.putAll(contactList);
        
        return contactCache;
    }
    
    //Additional getter methods, while these could be standalone getters on their own classes they are 
    //explicit to the contact object and cannot exist without them, so we will include those queries on this
    //getter class
    
    //Method 2 - Return Department name for contacts based on Department Id
    public static Map<Id, Department__c> getDepartmentById(Set<Id> idSet) {

        //Call the universal query utility while limiting on the basis of Id (constraint)
        List<Department__c> departmentList = (List<Department__c>) UniversalQueryUtility.universalQuery('Department__c', idSet, 'Id');
        Map<Id, Department__c> departmentCache = new Map<Id, Department__c>();
        departmentCache.putAll(departmentList);
        
        return departmentCache;
    }
    
    //Method 3 - Return Title name for contacts based on Title Id
    public static Map<Id, Account_Title__c> getTitleById(Set<Id> idSet) {

        //Call the universal query utility while limiting on the basis of Id (constraint)
        List<Account_Title__c> titleList = (List<Account_Title__c>) UniversalQueryUtility.universalQuery('Account_Title__c', idSet, 'Id');
        Map<Id, Account_Title__c> titleCache = new Map<Id, Account_Title__c>();
        titleCache.putAll(titleList);
        
        return titleCache;
    }
    
}