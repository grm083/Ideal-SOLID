public class QuoteContextGetter {
    
    /* The purpose of the quote context getter is to retrieve data related to quote only.  
     * These methods should not perform complex mutations or calculations, and should only exist to 
     * retrieve data related to the quote structure
	*/
    
    //Getter methods for asset
    //Method 1 - Return asset header by Id
    public static Map<Id, SBQQ__Quote__c> getQuoteById(Set<Id> idSet) {

        //Call the universal query utility while limiting on the basis of Id (constraint)
        List<SBQQ__Quote__c> objList = (List<SBQQ__Quote__c>) UniversalQueryUtility.universalQuery('SBQQ__Quote__c', idSet, 'Id');
        Map<Id, SBQQ__Quote__c> quoteCache = new Map<Id, SBQQ__Quote__c>();
        quoteCache.putAll(objList);
        
        return quoteCache;
    }
}