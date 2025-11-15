public class UniversalQueryUtility {
    
    //The purpose of the universal query utility is to provide a single point in which we can retrieve
    //all fields across an object given a set of Ids.  This utilizes the "Is Accessible" functionality
    //on the field map to ensure that we are not querying fields for which we do not have appropriate
    //FLS access to prevent errors.
    
    //Global Schema Describe for universal query
    private static Map<String, Schema.SObjectType> globalDescribe = new Map<String, Schema.SObjectType>();
    
    public static List<Sobject> universalQuery(String sObjectName, Set<Id> idSet, String constraint) {
        
        List<SObject> sobjList = new List<SObject>();
        
        //Check if we have already stored global describe to prevent unnecessary requeries
        if(globalDescribe.isEmpty()) {
            globalDescribe = Schema.getGlobalDescribe();
        }
        
        //Store the sObjectType to invoke the getDescribe and fields functions
        Schema.SObjectType sobjType = globalDescribe.get(sObjectName);
        
        List<String> fields = new List<String>();
        
        //Store all fields related to the sObject, construct queryString, and do query
        Map<String, Schema.SObjectField> fieldMap = sobjType.getDescribe().fields.getMap();
        
        for (String fieldName : fieldMap.keyset()) {
            if (fieldMap.get(fieldName).getDescribe().isAccessible()) {
                fields.add(fieldName);
            }
        }
        
        String queryString = 'SELECT ' + String.join(fields, ',') + ' FROM ' + sObjectName + ' WHERE ' + constraint + ' IN: idSet';
        sobjList = Database.query(String.escapeSingleQuotes(queryString));
        
        return sobjList;
    }
    
}