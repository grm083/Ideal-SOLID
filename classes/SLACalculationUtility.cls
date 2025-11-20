public class SLACalculationUtility {
    
    /*
* This method is to get the Service Date for the respective case based on the Entitlement availability or based on Industry Standard SLA.
* @owner : Priyadharshini R
* @param : CaseList
*/    
    
    //New methods added by George for managing the nuances of SLA Date Calculation
    //UPdated by Srishti as per CNM-1 & CNM-2 to ensure EntitlementId is set based on priority logic from caseEntitlement
    
    
    @InvocableMethod(label='Set Service Date')
    public static void setServiceDate(List<Case> caseList) {

        System.debug('kkk =>16 START setServiceDate, total cases = ' + caseList.size());

        BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault=true];
        System.debug('kkk =>18 Default Business Hours = ' + bh.Id);

        Map<Case, Account> caseAccountMap = buildCaseLocationMap(caseList);
        System.debug('kkk =>22 caseAccountMap size = ' + caseAccountMap.size());

        Map<Id, Case> caseMap = new Map<Id, Case>(caseList);
        Set<Id> caseIdSet = caseMap.keyset();
        System.debug('kkk =>26 caseIdSet = ' + caseIdSet);

        List<Case> casesToUpdate = new List<Case>();

        // STEP 1: Set entitlement
        System.debug('kkk =>31 Calling CaseEntitlement.populateEntitlement...');
        CaseEntitlement.populateEntitlement(caseList);

        // STEP 2: collect entitlement ids
        Set<Id> entitlementIds = new Set<Id>();
        for (Case c : caseList) {
            System.debug('kkk =>37 Case ' + c.Id + ' initial EntitlementId = ' + c.EntitlementId);
            if (c.EntitlementId != null) {
                entitlementIds.add(c.EntitlementId);
            }
        }
        System.debug('kkk =>42 Total entitlementIds = ' + entitlementIds);

        Map<Id, Entitlement> entitlementMap = new Map<Id, Entitlement>();
        if (!entitlementIds.isEmpty()) {
            entitlementMap = new Map<Id, Entitlement>([
                SELECT Id, Name, Call_Time__c, Before_After__c, Override_Business_Hours__c,Service_Guarantee_Category__c
                FROM Entitlement
                WHERE Id IN :entitlementIds
            ]);
        }
        System.debug('kkk =>52 entitlementMap size = ' + entitlementMap.size());

        // STEP 3: Calculate SLA
        for (Case c : caseAccountMap.keyset()) {

            System.debug('kkk =>57 Processing Case ' + c.Id + ' SLA_Service_Date_Time__c = ' + c.SLA_Service_Date_Time__c);

            if (c.SLA_Service_Date_Time__c == null) {
                try {

                    // Check entitlement presence
                    if (c.EntitlementId == null) {
                        System.debug('kkk =>64 ERROR: EntitlementId is null for case ' + c.Id);
                        throw new NoEntitlementException('No entitlement assigned to case: ' + c.Id);
                    }

                    Entitlement e = entitlementMap.get(c.EntitlementId);
                    System.debug('kkk =>69 Retrieved Entitlement for Case ' + c.Id + ' = ' + e);

                    if (e == null) {
                        System.debug('kkk =>72 ERROR: Entitlement missing in ENT map for case ' + c.Id);
                        throw new NoEntitlementException('Entitlement not found: ' + c.EntitlementId);
                    }

                    System.debug('kkk =>76 Using Entitlement ' + e.Id + ' for Case ' + c.Id);

                    // Calculate SLA
                    Integer daysDelta = getDaysDelta(e);
                    System.debug('kkk =>80 Calculated daysDelta = ' + daysDelta + ' for Entitlement ' + e.Id);

                    Boolean beforeCutoff = true;
                    if (e.Call_Time__c == null && e.Before_After__c == null) {
                        Account acc = caseAccountMap.get(c);
                        System.debug('kkk =>85 Calling isBeforeCutoff for Case ' + c.Id + ' with Account = ' + acc);
                        beforeCutoff = isBeforeCutoff(c, acc, 14);
                        System.debug('kkk =>87 beforeCutoff result = ' + beforeCutoff);
                    }

                    if (!beforeCutoff) {
                        daysDelta += 1;
                        System.debug('kkk =>92 Adjusted daysDelta due to after cutoff = ' + daysDelta);
                    }

                    DateTime SLADate = c.CreatedDate.addDays(daysDelta);
                    System.debug('kkk =>95 SLADate-Time = ' + SLADate);

                    c.Service_Date__c = SLADate.Date();
                    System.debug('kkk =>99 Initial Service_Date__c = ' + c.Service_Date__c);

                    while (!BusinessHours.isWithin(bh.Id, c.Service_Date__c) && !e.Override_Business_Hours__c) {
                        System.debug('kkk =>102 Not within business hours, bumping date by 1 for Case ' + c.Id);
                        c.Service_Date__c = c.Service_Date__c.addDays(1);
                    }

                    c.SLA_Service_Date__c = c.Service_Date__c;
                    c.SLA_Service_Date_Time__c = SLADate;

                    System.debug('kkk =>109 Final SLA_Service_Date__c = ' + c.SLA_Service_Date__c);
                    System.debug('kkk =>110 Final SLA_Service_Date_Time__c = ' + c.SLA_Service_Date_Time__c);

                } catch (Exception ex) {

                    System.debug('kkk => EXCEPTION for Case ' + c.Id + ' => ' + ex.getMessage());

                    // Fallback logic
                    c.Service_Date__c = System.now().addDays(1).date();
                    c.SLA_Service_Date__c = c.Service_Date__c;
                    c.SLA_Service_Date_Time__c = DateTime.newInstance(
                        c.SLA_Service_Date__c,
                        Time.newInstance(23, 59, 59, 59)
                    );

                    System.debug('kkk => FALLBACK applied: Service_Date__c = ' + c.Service_Date__c);

                    while (!BusinessHours.isWithin(bh.Id, c.Service_Date__c)) {
                        System.debug('kkk => Fallback: bump by +1 day due to business hours');
                        c.Service_Date__c = c.Service_Date__c.addDays(1);
                        c.SLA_Service_Date__c = c.Service_Date__c;
                        c.SLA_Service_Date_Time__c = DateTime.newInstance(
                            c.SLA_Service_Date__c,
                            Time.newInstance(23, 59, 59, 59)
                        );
                    }
                }

                casesToUpdate.add(c);
            }
        }

        System.debug('kkk => Updating ' + casesToUpdate.size() + ' cases.');
        update casesToUpdate;
        System.debug('kkk => END setServiceDate');
    }


    /**
     * @description Trigger-safe version of setServiceDate that calculates and sets SLA fields
     * WITHOUT performing DML. This method is designed to be called from before triggers.
     *
     * IMPORTANT: This method modifies the Case records in-place but does NOT update them.
     * The trigger framework will handle the DML operation.
     *
     * @param caseList List of cases to process
     * @param caseLocationMap Pre-built map of Case to Account (location) relationships
     */
    public static void calculateAndSetSLAFields(List<Case> caseList, Map<Id, Account> caseLocationMap) {

        System.debug('START calculateAndSetSLAFields (trigger-safe), total cases = ' + caseList.size());

        // Query default business hours
        BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault=true];

        // Build case-location map if not provided
        Map<Case, Account> caseAccountMap = new Map<Case, Account>();
        if (caseLocationMap != null && !caseLocationMap.isEmpty()) {
            for (Case c : caseList) {
                if (c.Location__c != null && caseLocationMap.containsKey(c.Location__c)) {
                    caseAccountMap.put(c, caseLocationMap.get(c.Location__c));
                }
            }
        }

        // If no location map provided, build it
        if (caseAccountMap.isEmpty()) {
            caseAccountMap = buildCaseLocationMap(caseList);
        }

        // STEP 1: Set entitlement
        CaseEntitlement.populateEntitlement(caseList);

        // STEP 2: Collect entitlement IDs
        Set<Id> entitlementIds = new Set<Id>();
        for (Case c : caseList) {
            if (c.EntitlementId != null) {
                entitlementIds.add(c.EntitlementId);
            }
        }

        // Query entitlements
        Map<Id, Entitlement> entitlementMap = new Map<Id, Entitlement>();
        if (!entitlementIds.isEmpty()) {
            entitlementMap = new Map<Id, Entitlement>([
                SELECT Id, Name, Call_Time__c, Before_After__c, Override_Business_Hours__c,
                       Service_Guarantee_Category__c, Service_Guarantee_Category_Value__c
                FROM Entitlement
                WHERE Id IN :entitlementIds
            ]);
        }

        // STEP 3: Calculate SLA for each case
        for (Case c : caseAccountMap.keyset()) {

            // Only process if SLA not already set
            if (c.SLA_Service_Date_Time__c == null) {
                try {

                    // Check entitlement presence
                    if (c.EntitlementId == null) {
                        System.debug('WARNING: EntitlementId is null for case ' + c.Id + ', applying fallback');
                        throw new NoEntitlementException('No entitlement assigned to case: ' + c.Id);
                    }

                    Entitlement e = entitlementMap.get(c.EntitlementId);

                    if (e == null) {
                        System.debug('WARNING: Entitlement not found for case ' + c.Id + ', applying fallback');
                        throw new NoEntitlementException('Entitlement not found: ' + c.EntitlementId);
                    }

                    // Calculate SLA days delta
                    Integer daysDelta = getDaysDelta(e);

                    // Check if before/after cutoff time
                    Boolean beforeCutoff = true;
                    if (e.Call_Time__c == null && e.Before_After__c == null) {
                        Account acc = caseAccountMap.get(c);
                        beforeCutoff = isBeforeCutoff(c, acc, 14);
                    }

                    if (!beforeCutoff) {
                        daysDelta += 1;
                    }

                    // Calculate SLA datetime
                    DateTime SLADate = c.CreatedDate.addDays(daysDelta);
                    c.Service_Date__c = SLADate.Date();

                    // Adjust for business hours
                    while (!BusinessHours.isWithin(bh.Id, c.Service_Date__c) && !e.Override_Business_Hours__c) {
                        c.Service_Date__c = c.Service_Date__c.addDays(1);
                    }

                    // Set final SLA fields
                    c.SLA_Service_Date__c = c.Service_Date__c;
                    c.SLA_Service_Date_Time__c = SLADate;

                    System.debug('Set SLA for Case ' + c.Id + ': Service_Date__c=' + c.Service_Date__c +
                                ', SLA_Service_Date_Time__c=' + c.SLA_Service_Date_Time__c);

                } catch (Exception ex) {

                    System.debug('EXCEPTION for Case ' + c.Id + ' => ' + ex.getMessage() + ', applying fallback SLA');

                    // Fallback logic: Set to next business day at 11:59 PM
                    c.Service_Date__c = System.now().addDays(1).date();
                    c.SLA_Service_Date__c = c.Service_Date__c;
                    c.SLA_Service_Date_Time__c = DateTime.newInstance(
                        c.SLA_Service_Date__c,
                        Time.newInstance(23, 59, 59, 59)
                    );

                    // Adjust for business hours
                    while (!BusinessHours.isWithin(bh.Id, c.Service_Date__c)) {
                        c.Service_Date__c = c.Service_Date__c.addDays(1);
                        c.SLA_Service_Date__c = c.Service_Date__c;
                        c.SLA_Service_Date_Time__c = DateTime.newInstance(
                            c.SLA_Service_Date__c,
                            Time.newInstance(23, 59, 59, 59)
                        );
                    }
                }
            }
        }

        System.debug('END calculateAndSetSLAFields');
    }
    
    
    public class NoEntitlementException extends Exception {}
    
    
    /**
     * REFACTORED: No longer writes to static CaseTriggerHelper.casewithLocation variable.
     * Callers should use the returned Map instead of accessing static variables.
     * This eliminates hidden coupling and improves testability.
     */
    public static Map<Case, Account> buildCaseLocationMap(List<Case> caseList) {
        Map<Case, Account> caseLocationMap = new Map<Case, Account>();
        Set<Id> caseLocationSet = new Set<Id>();

        for (Case c : caseList) {
            caseLocationSet.add(c.Location__c);
        }

        Map<Id, Account> locationMap = new Map<Id, Account>(
            [SELECT Id, tz__UTF_Offset__c FROM Account WHERE Id IN :caseLocationSet]
        );

        for (Case c : caseList) {
            Account acc = locationMap.get(c.Location__c);
            if (acc != null) {
                caseLocationMap.put(c, acc);
            }
        }

        // REFACTORED: Removed static variable write
        // Old code: CaseTriggerHelper.casewithLocation.putAll(casewithLocationMap);
        // Callers should use the returned map directly
        return caseLocationMap;
    }
    
    
    public static DateTime getLocalTime(Account a) {
        return DateTime.now().addHours(Integer.valueOf(a.tz__UTF_Offset__c));
    }
    
    public static Boolean isBeforeCutoff(Case c, Account a, Integer cutoffHour) {
        
        DateTime localTime = getLocalTime(a);
        return (localTime.hour() < cutoffHour ? true : false);
    }
    
    public static Integer getDaysDelta(Entitlement e) {
        
        Integer daysDelta;
        
        if (e.Service_Guarantee_Category__c == 'Days') {
            daysDelta = Integer.valueOf(e.Service_Guarantee_Category_Value__c);
        } else {
            Integer hours = Integer.valueOf(e.Service_Guarantee_Category_Value__c);
            daysDelta = Integer.valueOf(Math.floor(hours/24));
        }
        
        return daysDelta;
    }
    //End methods added by George
    
    //Use entitlement to calculate SLA date
    public static DateTime calculateEntitlementSLA(Entitlement e, BusinessHours bh) {
        DateTime additionalDate;
        Date targetDate;
        Time targetTime;
        QuoteFavoritesController.currentDateTime currDateTime = new QuoteFavoritesController.currentDateTime();
        integer currentHour = Integer.valueOf(currDateTime.hours.split(':')[0]);
        Long milliseconds = 0;
        DateTime productSLA;
        
        switch on e.Service_Guarantee_Category__c {
            when 'Hours' {
                milliseconds = Integer.valueOf(e.Service_Guarantee_Category_Value__c) * 3600000;
            }
            when 'Days' {
                integer serviceGuaranteeCategoryValue = Integer.valueOf(e.Service_Guarantee_Category_Value__c);
                //For Same Day and Next Day Entitlements SDT-24917, In Before Logic one extra Day shouldn't get added
                if(e.Before_After__c!='' && (Constant_Util.BEFORE).equalsIgnorecase(e.Before_After__c) && currentHour < 9){
                    if(serviceGuaranteeCategoryValue!=0 && serviceGuaranteeCategoryValue==1){
                        serviceGuaranteeCategoryValue=serviceGuaranteeCategoryValue + 1;
                    }
                }
                else if(e.Before_After__c!='' && (Constant_Util.BEFORE).equalsIgnorecase(e.Before_After__c) && currentHour >= 10){
                    if(serviceGuaranteeCategoryValue!=0 && serviceGuaranteeCategoryValue!=1){
                        serviceGuaranteeCategoryValue=serviceGuaranteeCategoryValue-1;
                    }
                }
                else if(e.Before_After__c!='' && (Constant_Util.BEFORE).equalsIgnorecase(e.Before_After__c) && currentHour < 10){
                    if(serviceGuaranteeCategoryValue!=0 && serviceGuaranteeCategoryValue!=1){
                        serviceGuaranteeCategoryValue=serviceGuaranteeCategoryValue;
                        system.debug('serviceGuaranteeCategoryValue for else if Before 10 in before condition==>'+serviceGuaranteeCategoryValue);                        
                    }
                }
                //'After' 14:00 Scenarios for Entitlements to get picked up
                else if(e.Before_After__c!='' && (Constant_Util.AFTER).equalsIgnorecase(e.Before_After__c) && (e.Call_Time__c == '14:00' || e.Call_Time__c == '15:00' || e.Call_Time__c == '23:59')){
                    serviceGuaranteeCategoryValue=serviceGuaranteeCategoryValue;
                }
                //'After' and before 14:00 Scenarios for Entitlements to get picked up
                else if(e.Before_After__c!='' && (Constant_Util.AFTER).equalsIgnorecase(e.Before_After__c) && e.Call_Time__c == '13:00' || e.Call_Time__c == '12:00' || e.Call_Time__c == '10:00' ){
                    if(serviceGuaranteeCategoryValue!=0 && serviceGuaranteeCategoryValue!=1){
                        serviceGuaranteeCategoryValue=serviceGuaranteeCategoryValue-1;
                    }
                }
                milliseconds = serviceGuaranteeCategoryValue * 16 * 3600000;
            }
        }
        productSLA = QuoteFavoritesController.getBusinessHours(bh.Id, currDateTime.local, milliseconds);   
        system.debug('productSLA From QF Controllers calculateEntitlementSLA-->'+productSLA);
        return productSLA;        
    }
    
    /**
* @description Determines if a change in critical Case fields (Type, Sub Type, Location) 
* requires the Entitlement and Service Date to be recalculated/reset.
* * Note: This method is retained from the original trigger logic 
* for backwards compatibility and to encapsulate the "dirty field" check.
* * @param newCase The new version of the Case record (Trigger.new)
* @param oldCase The old version of the Case record (Trigger.old)
* @return Boolean True if any critical field has changed, indicating an SLA recalculation is needed.
*/
    public static Boolean requiresSLAandServiceDateReset(Case newCase, Case oldCase) {
        
        // Safety check: if oldCase is null, this is an insert, and all fields are 'changed'.
        // However, the handler only calls this in beforeUpdate, so oldCase should exist.
        if (oldCase == null) {
            return true; 
        }
        
        // Critical fields that drive Entitlement/SLA calculation
        // 1. Case Type
        if (newCase.Case_Type__c != oldCase.Case_Type__c) {
            return true;
        }
        
        // 2. Case Sub Type
        if (newCase.Case_Sub_Type__c != oldCase.Case_Sub_Type__c) {
            return true;
        }
        
        // 3. Location (a look-up to Account)
        // The Location field is critical because Entitlements are tied to Accounts/Locations.
        if (newCase.Location__c != oldCase.Location__c) {
            return true;
        }
        
        // 4. Asset (a look-up to Asset)
        // The Asset often dictates the type of service, which can affect the SLA.
        if (newCase.AssetId != oldCase.AssetId) {
            return true;
        }
        
        // 5. Case Reason (often used to differentiate service needs within a Type/Sub Type)
        if (newCase.Reason != oldCase.Reason) {
            return true;
        }
        
        // If none of the critical fields have changed, no SLA recalculation is required.
        return false;
    }
    
    // ================================================================================
    // METHOD 1: calculateServiceDates
    // Called from: CaseTriggerHelper_REFACTORED.getServiceDate()
    // Purpose: Calculates and sets Service Date based on SLA rules
    // ================================================================================
    public static List<Case> calculateServiceDates(List<Case> newCaseList, 
                                                   Map<Id,Asset> casewithContainerMap, 
                                                   Map<Id,Account> casewithLocationMap) {
                                                       map<string,case> caseMap = new map<string,case>();
                                                       List<Case> caseList = new List<Case>();
                                                       string container = null;
                                                       string casekey = null;
                                                       DateTime serviceTime = DateTime.newInstance(0, 0, 0, 0, 0, 0);
                                                       string scheduleType = null;
                                                       Boolean isBackDatedCase = false;
                                                       
                                                       Map<String,Industry_Standard_SLA__mdt> industyStandardSLAMap = new Map<String,Industry_Standard_SLA__mdt>();
                                                       Map<String,Id> businessIdMap = new Map<String,Id>();
                                                       Map<string,Entitlement> casekeywithEntitlementMap = new map<string,Entitlement>();
                                                       Set<Id> parentAccountIdset = new Set<Id>();
                                                       Set<String> serviceset = new Set<String>();
                                                       
                                                       try{
                                                           // Load Industry Standard SLA metadata
                                                           for(Industry_Standard_SLA__mdt sla : Industry_Standard_SLA__mdt.getAll().values()){ 
                                                               industyStandardSLAMap.put(sla.Service__c, sla);
                                                           }
                                                           
                                                           // Load Business Hours
                                                           for(BusinessHours b : [SELECT id, TimeZoneSidKey FROM BusinessHours LIMIT 39999]){
                                                               businessIdMap.put(b.TimeZoneSidKey, b.Id);
                                                           }
                                                           
                                                           // Build case key map
                                                           for(Case thisCase : newCaseList){
                                                               if(String.ISBlank(thisCase.Case_Type__c) || 
                                                                  (businessIdMap != null && !businessIdMap.isEmpty() && 
                                                                   casewithLocationMap.containsKey(thisCase.Location__c) &&
                                                                   !businessIdMap.containsKey(casewithLocationMap.get(thisCase.Location__c).tz__Timezone_SFDC__c))){
                                                                       continue;
                                                                   }
                                                               
                                                               if(thisCase.Service_Date__c != null && thisCase.Service_Date__c < date.today()){
                                                                   isBackDatedCase = true;
                                                               }
                                                               
                                                               thisCase.SlaStartDate = convertToLocationTimezone(System.now(), thisCase, casewithLocationMap);
                                                               parentAccountIdset.add(thisCase.Client__c);
                                                               serviceset.add(thisCase.Case_Sub_Type__c);
                                                               
                                                               if(String.ISNotBlank(thisCase.Case_Type__c) && 
                                                                  thisCase.Case_Type__c.equalsIgnoreCase(Constant_Util.NEW_SERVICE)){
                                                                      container = thisCase.Equipment_Type_Code__c != Null ? thisCase.Equipment_Type_Code__c : Null;
                                                                  }
                                                               else{
                                                                   container = casewithContainerMap != null && casewithContainerMap.containsKey(thisCase.AssetId) ? 
                                                                       casewithContainerMap.get(thisCase.AssetId).Product2.ProductTypeSelected__c : null;
                                                                   scheduleType = casewithContainerMap != null && casewithContainerMap.containsKey(thisCase.AssetId) ? 
                                                                       casewithContainerMap.get(thisCase.AssetId).Duration__c : null;
                                                               }
                                                               
                                                               casekey = thisCase.Client__c + Constant_Util.STAR + thisCase.Location__c + Constant_Util.STAR + 
                                                                   container + Constant_Util.STAR + thisCase.Case_Sub_Type__c + Constant_Util.STAR + scheduleType;
                                                               caseMap.put(casekey, thisCase);
                                                           }
                                                       }
                                                       catch(Exception e){
                                                           System.debug('Exception in calculateServiceDates: ' + e.getStackTraceString());
                                                           UTIL_LoggingService.logHandledException(e, UserInfo.getOrganizationId(),
                                                               UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
                                                       }

                                                       // FIX: Return the cases that were processed (from caseMap)
                                                       // Previously returned empty caseList - now returning actual processed cases
                                                       return caseMap.values();
                                                   }
    
    // ================================================================================
    // METHOD 2: correctSLADate
    // Called from: CaseTriggerHelper_REFACTORED.getSLACorrectedDate()
    // Purpose: Corrects SLA date to prevent back-dating (SDT-32837)
    // ================================================================================
    public static Datetime correctSLADate(Case c, Map<Id,Account> casewithLocationMap){
        DateTime newSLADatetime;
        DateTime locDate;
        Integer Difference; 
        
        locDate = convertToLocationTimezone(c.SLA_Service_Date_Time__c, c, casewithLocationMap); 
        Date date1;
        Date date2;
        if(c.Service_Date__c != null && c.SLA_Service_Date_Time__c != null){
            date1 = c.Service_Date__c;
            date2 = c.SLA_Service_Date_Time__c.dateGMT();
        }
        if(date2 != null && date1 != null){
            difference = date2.daysBetween(date1);
        }
        if(c.Service_Date__c > locdate && difference != null && difference == 0){
            newSLADatetime = c.SLA_Service_Date_Time__c.addDays(1);
        }
        return newSLADatetime;
    }
    
    // ================================================================================
    // METHOD 3: convertToLocationTimezone
    // Called from: CaseTriggerHelper_REFACTORED.getservicedatetime()
    // Purpose: Converts datetime to location timezone
    // ================================================================================
    public static Datetime convertToLocationTimezone(Datetime localdate, Case c, Map<Id,Account> casewithLocationMap){
        Timezone tz;
        System.debug('casewithLocationMap---' + casewithLocationMap);
        if(string.isNotBlank(c.Location__c) && casewithLocationMap != null && 
           casewithLocationMap.containsKey(c.Location__c) && 
           String.isNotBlank(casewithLocationMap.get(c.Location__c).tz__Timezone_SFDC__c)){
               tz = Timezone.getTimeZone(casewithLocationMap.get(c.Location__c).tz__Timezone_SFDC__c);
               localdate = localdate.addSeconds((tz.getOffset(localdate)/1000));        
           }
        return localdate;
    }
    
    // ================================================================================
    // METHOD 4: calculateIntakeSLADatetime
    // Called from: CaseTriggerHelper_REFACTORED.getIntakeSLADatetime()
    // Purpose: Updates SLA datetime for intake pickup cases (SDT-38039)
    // ================================================================================
    public static Datetime calculateIntakeSLADatetime(Datetime serviceDate, Datetime currentSLADate, 
                                                      Case c, Map<Id,Account> casewithLocationMap){
                                                          Datetime updatedSLA;        
                                                          if(string.isNotBlank(c.Location__c) && casewithLocationMap != null && 
                                                             casewithLocationMap.containsKey(c.Location__c) && 
                                                             String.isNotBlank(casewithLocationMap.get(c.Location__c).tz__Timezone_SFDC__c))
                                                          {
                                                              Date targetDate = Date.newInstance(serviceDate.year(), serviceDate.month(), serviceDate.day());
                                                              Time targetTime = Time.newInstance(21, 0, 0, 0);
                                                              updatedSLA = getadditionalDate(targetDate, targetTime, 
                                                                                             casewithLocationMap.get(c.Location__c).tz__Timezone_SFDC__c);
                                                              updatedSLA = updatedSLA.addDays(1);
                                                          }
                                                          return updatedSLA;
                                                      }
    
    // ================================================================================
    // Helper method for calculateIntakeSLADatetime
    // ================================================================================
    private static Datetime getadditionalDate(Date targetDate, Time targetTime, String Totimezone){
        TimeZone targetTimezone;
        Integer offsetSeconds;
        DateTime additionalDate;
        
        targetTimezone = TimeZone.getTimeZone(Totimezone);
        offsetSeconds = targetTimezone.getOffset(targetDate) / 1000;
        additionalDate = Datetime.newInstanceGmt(targetDate, targetTime).addSeconds(-offsetSeconds);
        return additionalDate;
    }
    
    // ================================================================================
    // METHOD 5: syncServiceDateToSLA
    // Called from: CaseTriggerHelper_REFACTORED.serviceDatetoSLA()
    // Purpose: Updates SLA Service Date Time from Service Date
    // ================================================================================
    public static void syncServiceDateToSLA(List<case> caseNewList, Map<Id,case> oldCasemap, 
                                            Map<Id,Account> casewithLocationMap){
                                                DateTime slaDateTime = null;
                                                try{
                                                    for(Case c : caseNewList){
                                                        // SDT-38039: Intake Pickup Case SLA Date Logic
                                                        if(UserInfo.getName() != null && UserInfo.getName().equals(Constant_Util.API_USER_ONLY_NAME)
                                                           && (c.status.equals(Constant_Util.STATUS_NEW))
                                                           && c.Case_Type__c.equals(Constant_Util.PICKUP_CSTYPE)
                                                           && c.Service_Date__c != null && c.SLA_Service_Date_Time__c != null
                                                           && (c.Service_Date__c > c.SLA_Service_Date_Time__c.dateGmt()))
                                                        {
                                                            c.SLA_Service_Date_Time__c = calculateIntakeSLADatetime(c.Service_Date__c, 
                                                                                                                    c.SLA_Service_Date_Time__c, 
                                                                                                                    c, casewithLocationMap);
                                                        }
                                                        else if(c.SLA_Service_Date_Time__c != null)
                                                        {
                                                            slaDateTime = DateTime.newInstanceGmt(c.SLA_Service_Date_Time__c.dateGmt(), 
                                                                                                  c.SLA_Service_Date_Time__c.TimeGmt());
                                                            slaDateTime = convertToLocationTimezone(slaDateTime, c, casewithLocationMap);
                                                            
                                                            if((c.ParentId != null && c.Service_Date__c != null && c.Check_Case__c ) 
                                                               || (!oldCasemap.isEmpty() && oldCasemap.containskey(c.Id) && 
                                                                   oldCasemap.get(c.id).Service_Date__c != null && 
                                                                   c.RecordTypeId == oldCasemap.get(c.id).RecordTypeId && 
                                                                   c.Service_Date__c != null && 
                                                                   oldCasemap.get(c.Id).Service_Date__c != c.Service_Date__c
                                                                   && slaDateTime != null && c.Service_Date__c >= slaDateTime.dateGmt() && 
                                                                   !Constant_Util.SLA_OVERRIDE_REASON.equals(c.SLA_Override_Reason__c))  
                                                               || (c.Service_Date__c != null && c.Service_Date__c < date.today() && 
                                                                   (Constant_Util.STATUS_NEW).Equals(c.status))){
                                                                       Date targetDate = Date.newInstance(c.Service_Date__c.year(), 
                                                                                                          c.Service_Date__c.month(), 
                                                                                                          c.Service_Date__c.day());
                                                                       Time targetTime = Time.newInstance(21, 0, 0, 0);
                                                                       c.SLA_Service_Date_Time__c = getadditionalDate(targetDate, targetTime, 
                                                                                                                      casewithLocationMap.get(c.Location__c).tz__Timezone_SFDC__c);
                                                                       c.Check_Case__c = false;                                                                                                            
                                                                   }
                                                        }
                                                    }
                                                }
                                                Catch(Exception ex){
                                                    System.debug('Exception in syncServiceDateToSLA: ' + ex.getStackTraceString());
                                                }
                                            }
    
    // ================================================================================
    // METHOD 6: calculateStandardServiceDates
    // Called from: CaseTriggerHelper_REFACTORED.getServiceDateStandard()
    // Purpose: Standard service date calculation (for Activate/Modify/Deactivate cases)
    // ================================================================================
    public static List<Case> calculateStandardServiceDates(List<Case> newCaseList){
        map<string,case> caseMap = new map<string,case>();
        List<Case> caseList = new List<Case>();
        string casekey = null;
        DateTime serviceTime = DateTime.newInstance(0, 0, 0, 0, 0, 0);
        Boolean isBackDatedCase = false;
        
        Map<String,Industry_Standard_SLA__mdt> industyStandardSLAMap = new Map<String,Industry_Standard_SLA__mdt>();
        Map<String,Id> businessIdMap = new Map<String,Id>();
        Set<String> serviceset = new Set<String>();
        
        try{
            // Load Industry Standard SLA metadata
            for(Industry_Standard_SLA__mdt sla : Industry_Standard_SLA__mdt.getAll().values()){ 
                industyStandardSLAMap.put(sla.Service__c, sla);
            }
            
            // Load Business Hours
            for(BusinessHours b : [SELECT id, TimeZoneSidKey FROM BusinessHours LIMIT 39999]){
                businessIdMap.put(b.TimeZoneSidKey, b.Id);
            }
            
            for(Case thisCase : newCaseList){
                if(String.ISBlank(thisCase.Case_Type__c) || 
                   (businessIdMap != null && !businessIdMap.isEmpty() && 
                    !businessIdMap.containsKey('America/New_York'))){
                        continue;
                    }
                
                if(thisCase.Service_Date__c != null && thisCase.Service_Date__c < date.today()){
                    isBackDatedCase = true;
                }
                
                thisCase.SlaStartDate = convertToStandardTimezone(System.now(), thisCase);
                serviceset.add(thisCase.Case_Sub_Type__c);
                
                casekey = '' + Constant_Util.STAR + '' + Constant_Util.STAR + '' + Constant_Util.STAR + 
                    thisCase.Case_Sub_Type__c + Constant_Util.STAR + '';
                caseMap.put(casekey, thisCase);
            }
            
            If(!caseMap.isEmpty() && caseMap.size() > 0){
                DateTime additionalDate;
                
                for(String key : caseMap.keySet()){
                    additionalDate = null;
                    String con;
                    
                    if(String.isNotBlank(CaseMap.get(key).Case_Reason__c) && 
                       !Constant_Util.PICKUP_CSTYPE.equalsIgnoreCase(CaseMap.get(key).case_type__c) && 
                       !Constant_Util.NEW_SERVICE.equalsIgnoreCase(CaseMap.get(key).case_type__c)) {
                           con = CaseMap.get(key).Case_Type__c + Constant_Util.UNDERSCORE + 
                               CaseMap.get(key).Case_Sub_Type__c + Constant_Util.UNDERSCORE + 
                               CaseMap.get(key).Case_Reason__c;      
                       }
                    
                    // Calculate service time based on hour of day
                    if(CaseMap.get(key).SlaStartDate.hourGmt() > 14 || 
                       (CaseMap.get(key).SlaStartDate.hourGmt() == 14 && 
                        CaseMap.get(key).SlaStartDate.minuteGmt() > 0)){
                            serviceTime = System.now().addDays(2);
                        } else {
                            serviceTime = System.now().addDays(1);
                        }
                    
                    // Handle backdated or SLA override cases
                    If(!CaseMap.IsEmpty() && String.isNotBlank(CaseMap.get(Key).SLA_Override_Reason__c) && 
                       Constant_Util.SLA_OVERRIDE_REASON.equals(CaseMap.get(Key).SLA_Override_Reason__c) && 
                       CaseMap.get(key).SLA_Service_Date_Time__c != null){
                           continue;
                       } else {
                           CaseMap.get(key).SLA_Service_Date_Time__c = serviceTime;
                       }
                    
                    If(string.isBlank(string.valueOf(CaseMap.get(key).Service_Date__c))){
                        CaseMap.get(key).Service_Date__c = serviceTime.dateGmt();
                    }
                }
                
                // Map results back to original case list
                for(case c : newCaseList){
                    casekey = '' + Constant_Util.STAR + '' + Constant_Util.STAR + '' + Constant_Util.STAR + 
                        c.Case_Sub_Type__c + Constant_Util.STAR + '';
                    if(CaseMap.containskey(casekey)){
                        c.Service_Date__c = string.isBlank(String.valueof(c.Service_Date__c)) ? 
                            CaseMap.get(casekey).Service_Date__c : c.Service_Date__c;
                        c.SLA_Service_Date_Time__c = CaseMap.get(casekey).SLA_Service_Date_Time__c;
                    }
                    caseList.add(c);
                }
            }
        }
        catch(Exception e){
            System.debug('Exception in calculateStandardServiceDates: ' + e.getStackTraceString());
        }
        return caseList;
    }
    
    // ================================================================================
    // METHOD 7: convertToStandardTimezone
    // Called from: CaseTriggerHelper_REFACTORED.getservicedatetimestandard()
    // Purpose: Converts datetime to standard EST/EDT timezone
    // ================================================================================
    public static Datetime convertToStandardTimezone(Datetime localdate, Case c){
        Timezone tz;
        if(c.Case_Type__c == 'Activate' || c.Case_Type__c == 'Modify' || c.Case_Type__c == 'Deactivate'){
            tz = Timezone.getTimeZone('America/New_York');
            localdate = localdate.addSeconds((tz.getOffset(localdate)/1000));
        }
        return localdate;
    }
    
    // ================================================================================
    // METHOD 8: syncStandardServiceDateToSLA
    // Called from: CaseTriggerHelper_REFACTORED.serviceDatetoSLAstandard()
    // Purpose: Updates SLA to standard timezone for Activate/Modify/Deactivate cases
    // ================================================================================
    public static void syncStandardServiceDateToSLA(List<case> caseNewList, Map<Id,case> oldCasemap){
        DateTime slaDateTime = null;
        try{
            for(Case c : caseNewList){
                If(c.SLA_Service_Date_Time__c != null){
                    slaDateTime = DateTime.newInstanceGmt(c.SLA_Service_Date_Time__c.dateGmt(), 
                                                          c.SLA_Service_Date_Time__c.TimeGmt());
                    slaDateTime = convertToStandardTimezone(slaDateTime, c);
                }
                
                // Calculate service date based on current EST time
                Datetime dt = System.now() + 0.04;
                String datetimeESTStr = dt.format('yyyy-MM-dd\'T\'HH:mm:ssZ', 'EST');
                String[] abc2 = datetimeESTStr.split('T');
                String serDate = abc2[0]; 
                Date sdt = Date.valueOf(serDate);
                
                String dtEST = dt.format('HH:mm:ss', 'EST');
                String[] abc = dtEST.split(':');
                String hours = abc[0]; 
                integer hq = Integer.valueof(hours.trim());
                
                if(hq < 14){
                    if(c.Case_Type__c == 'Activate' || c.Case_Type__c == 'Modify'){
                        c.SLA_Service_Date_Time__c = sdt;
                        c.Service_Date__c = sdt;
                        c.Check_Case__c = false; 
                    } else {
                        c.SLA_Service_Date_Time__c = sdt + 1;
                        c.Service_Date__c = sdt + 1;
                        c.Check_Case__c = false; 
                    }
                } else {
                    if(c.Case_Type__c == 'Activate' || c.Case_Type__c == 'Modify'){
                        c.SLA_Service_Date_Time__c = sdt + 1;
                        c.Service_Date__c = sdt + 1;
                        c.Check_Case__c = false; 
                    } else {
                        c.SLA_Service_Date_Time__c = sdt + 2;
                        c.Service_Date__c = sdt + 2;
                        c.Check_Case__c = false; 
                    }
                }
            }
        }
        Catch(Exception ex){
            System.debug('Exception in syncStandardServiceDateToSLA: ' + ex.getStackTraceString());
        }
    }
    
}