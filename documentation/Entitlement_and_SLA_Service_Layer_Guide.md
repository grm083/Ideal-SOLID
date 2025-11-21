# Entitlement & SLA Service Layer Developer Guide

## Overview

This guide documents two interdependent service layer classes that form the core of Waste Management's customer entitlement resolution and SLA date calculation system:

- **`Entitlement_Utility`**: Resolves the appropriate entitlement for customer cases and quotes
- **`SLACalculationUtility`**: Calculates service dates and SLA commitments using resolved entitlements

These classes work together to ensure customer service commitments are accurately determined and tracked throughout the case lifecycle.

---

## Architecture Overview

### Service Layer Pattern

Both classes implement the **Service Layer** pattern, providing reusable business logic that can be invoked by:
- Triggers (via trigger handlers)
- Lightning Web Components
- Aura Components
- Flow automations
- Other service classes
- Batch/scheduled jobs

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     Service Request (Case/Quote)                │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│               Entitlement_Utility.getPrioritizedEntitlements()  │
│                                                                 │
│  • Queries metadata-driven field mappings                      │
│  • Extracts account, location, service details from records    │
│  • Retrieves and filters potential entitlements                │
│  • Prioritizes based on customer/service/transaction match     │
│                                                                 │
│  Returns: Map<RecordId, Entitlement>                          │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│            SLACalculationUtility.setServiceDate()               │
│                      (or related calculation methods)           │
│                                                                 │
│  • Receives entitlement from previous step                     │
│  • Determines calculation strategy:                            │
│    - Entitlement-based (Gold/Contractual/Commercial)          │
│    - WM Capacity Planner API (Rolloff + WM vendor)            │
│    - Industry Standard fallback                                │
│  • Calculates Service_Date__c and SLA_Service_Date_Time__c    │
│  • Adjusts for business hours and timezones                    │
│                                                                 │
│  Updates: Case.Service_Date__c, SLA_Service_Date_Time__c      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Entitlement_Utility Class

### Purpose

Resolves which entitlement applies to a given case or quote by matching record attributes against configured entitlement criteria. Uses a sophisticated prioritization algorithm to select the most specific applicable entitlement.

### Key Methods

#### Public Interface Methods

##### `getPrioritizedEntitlements(Set<Id> targetRecords)`

**Purpose**: Returns the single highest-priority entitlement for each target record.

**Use When**: You need the definitive entitlement for SLA calculation, business rule evaluation, or display to users.

```apex
// Example: Get entitlements for a set of cases
Set<Id> caseIds = new Set<Id>{ caseRecord.Id };
Map<String, Entitlement> entitlements = Entitlement_Utility.getPrioritizedEntitlements(caseIds);
Entitlement selectedEntitlement = entitlements.get(caseRecord.Id);
```

**Parameters**:
- `targetRecords` - Set of Case IDs or Quote IDs (SBQQ__Quote__c)

**Returns**: 
- `Map<String, Entitlement>` - Key is record ID, value is the prioritized entitlement

**Algorithm**: Uses a multi-tier prioritization strategy:
1. **Priority Rank** (0-7, lower is better):
   - 0: All three match (Customer + Service + Transaction)
   - 1: Customer + Service match
   - 2: Customer + Transaction match
   - 3: Customer only
   - 4: Service + Transaction match
   - 5: Service only
   - 6: Transaction only
   - 7: No match (default/fallback)

2. **Within same priority rank, tie-breaks by**:
   - Customer score (number of customer fields matched)
   - Service score (number of service fields matched)
   - Transaction score (number of transaction fields matched)

##### `getRelevantEntitlements(Set<Id> targetRecords)`

**Purpose**: Returns ALL valid entitlements for target records, grouped by type (Industry Standard vs Customer Specific).

**Use When**: You need to display available entitlement options or analyze multiple possibilities.

```apex
// Example: Get all applicable entitlements for analysis
Map<String, Map<String, List<Entitlement>>> allEntitlements = 
    Entitlement_Utility.getRelevantEntitlements(caseIds);

// Structure: Map<RecordId, Map<EntitlementType, List<Entitlement>>>
// EntitlementType values: 'Industry Standard' or 'Customer Specific Entitlement'
```

### Metadata-Driven Configuration

The class uses **`Entitlement_Field_Mapping__mdt`** custom metadata to define which fields are compared between records and entitlements.

**Example Metadata Records**:

| MasterLabel | Priority_Value | Case__c | Entitlement__c | Quote__c |
|-------------|----------------|---------|----------------|----------|
| Account Name | 0A | Client__c | AccountId | Customer__c |
| Location | 0B | Location__c | Location__c | Location__c |
| Material Type | 2A | Material_Type__c | Material_Type__c | Product__c |
| Service Type | 2B | Case_Sub_Type__c | Service__c | Service_Type__c |

**Priority Value Prefixes**:
- `0x`: Customer identification fields (Account, Location)
- `1x`: Service/Location details
- `2x`: Material/Schedule (Service identification - Priority 1)
- `3x-4x`: Request/Service/Case details (Transaction identification - Priority 2)

### Entitlement Filtering Logic

The class applies several filters to ensure only valid entitlements are considered:

1. **Date Range**: Entitlement StartDate ≤ minimumServiceDate AND EndDate ≥ today
2. **Status**: Status__c = 'Approved' AND Status != 'Expired'
3. **Call Time/Day**: Filters by Before_After__c, Call_Time__c, and Call_On__c (day of week)
4. **Account Matching**: Either AccountId is null (Industry Standard) OR matches record's account

### Important Implementation Notes

**Deprecated Static Variables**:
```apex
// ❌ DO NOT USE - Deprecated and will be removed
public static Set<Id> accountIdSet;
public static Date minimumServiceDate;
```

These were replaced with parameter-based methods. The class now extracts necessary data from the records themselves.

**Thread Safety**: The class is stateless (after deprecation of static variables) and safe for concurrent execution in batch/trigger contexts.

---

## SLACalculationUtility Class

### Purpose

Calculates service commitment dates and SLA timestamps for cases based on:
- Resolved entitlements
- Business hours
- Location timezones  
- WM Capacity Planner API (for rolloff services)
- Industry standard SLA rules

### Key Methods

#### Primary Calculation Methods

##### `setServiceDate(List<Case> caseList)`

**Purpose**: Invocable method for Flow/Process Builder. Calculates and updates SLA fields with DML.

**Use When**: Called from Flow automations or when DML is acceptable.

```apex
// Example: Flow invocable action
@InvocableMethod(label='Set Service Date')
public static void setServiceDate(List<Case> caseList) {
    // Calculates SLA dates AND performs update DML
}
```

**Important**: This method:
1. Calls `CaseEntitlement.populateEntitlement()` to set EntitlementId
2. Queries entitlement details
3. Calculates service dates
4. **Performs DML** - updates Case records

##### `calculateAndSetSLAFields(List<Case> caseList, Map<Id, Account> caseLocationMap)`

**Purpose**: Trigger-safe version that calculates SLA fields WITHOUT performing DML.

**Use When**: Called from BEFORE triggers where DML is not allowed.

```apex
// Example: From CaseTriggerHandler beforeInsert
public void beforeInsert(List<Case> newCases) {
    // Build location map
    Map<Id, Account> locationMap = getLocationMapForCases(newCases);
    
    // Calculate SLA fields (no DML)
    SLACalculationUtility.calculateAndSetSLAFields(newCases, locationMap);
    
    // Trigger framework handles the insert
}
```

**Important**: This method modifies Case records in-place but does NOT update them. The trigger framework performs the DML.

#### Service Date Calculation Strategy

The class uses a decision tree to determine which calculation method to apply:

```
Is Gold Standard OR Contractual OR Product Family = Commercial?
│
├─YES → Use Entitlement-based calculation
│       (calculateEntitlementBasedServiceDate)
│
└─NO → Is Product Family = Rolloff AND Vendor = WM?
       │
       ├─YES → Try WM Capacity Planner API
       │       (calculateCapacityPlannerServiceDate)
       │       │
       │       └─API Success? 
       │           ├─YES → Use returned dates
       │           └─NO  → Fallback to entitlement
       │
       └─NO → Use Entitlement-based calculation
```

##### `calculateServiceDateWithCapacity(Case, Asset, Entitlement, Account)`

**Purpose**: Orchestrates the decision logic and returns structured results.

**Returns**: `ServiceDateCalculationResult` wrapper containing:
- `serviceDate` - Calculated Service_Date__c
- `slaServiceDateTime` - Calculated SLA_Service_Date_Time__c
- `calculationMethod` - String describing which method was used
- `availableDates` - List of dates from capacity planner (if used)
- `errorMessage` - Any errors encountered

```apex
// Example: Manual calculation with detailed results
ServiceDateCalculationResult result = SLACalculationUtility.calculateServiceDateWithCapacity(
    caseRecord,
    serviceHeaderAsset,
    selectedEntitlement,
    locationAccount
);

System.debug('Service Date calculated using: ' + result.calculationMethod);
caseRecord.Service_Date__c = result.serviceDate;
caseRecord.SLA_Service_Date_Time__c = result.slaServiceDateTime;
```

#### WM Capacity Planner Integration

##### `callWMCapacityPlannerAPI(String sbid)`

**Purpose**: Makes HTTP callout to WM Capacity Planner to retrieve available service dates.

**Use When**: Rolloff service with WM vendor (Parent_Vendor_ID__c = '8') and valid SBID.

```apex
// Example: Get available dates for a service baseline
String sbid = getServiceBaselineId(asset);
List<String> availableDates = SLACalculationUtility.callWMCapacityPlannerAPI(sbid);

// Returns dates in format: ["12/15/2024", "12/16/2024", "12/17/2024"]
```

**Integration Configuration**: Uses `Integration_Request_URLs__mdt` metadata (DeveloperName = 'Site_Capacity')

**SBID (Service Baseline ID)**: Retrieved from Asset service detail records where:
- `Is_Self_Service__c = true`
- `Quantity__c = 1`
- `Parent_Vendor_ID__c = '8'` (WM vendor)
- `SBID_Text_c__c` is not blank

#### Helper Methods

##### `buildCaseLocationMap(List<Case> caseList)`

**Purpose**: Constructs a map of Case to Location Account with timezone information.

**Returns**: `Map<Case, Account>` with populated `tz__UTF_Offset__c` field

```apex
// Example usage
Map<Case, Account> caseLocationMap = SLACalculationUtility.buildCaseLocationMap(cases);

// Access location timezone
for (Case c : caseLocationMap.keySet()) {
    Account location = caseLocationMap.get(c);
    Decimal utcOffset = location.tz__UTF_Offset__c;
}
```

**Refactoring Note**: Previously wrote to static `CaseTriggerHelper.casewithLocation` variable. Now returns the map directly for better testability.

##### `getDaysDelta(Entitlement e)`

**Purpose**: Converts entitlement SLA value to days delta.

```apex
// Example
Entitlement ent = [SELECT Service_Guarantee_Category__c, 
                           Service_Guarantee_Category_Value__c
                    FROM Entitlement WHERE Id = :entId];

Integer daysDelta = SLACalculationUtility.getDaysDelta(ent);

// If Category = 'Days' and Value = 3 → returns 3
// If Category = 'Hours' and Value = 48 → returns 2 (48/24 floored)
```

##### `isBeforeCutoff(Case c, Account a, Integer cutoffHour)`

**Purpose**: Determines if case was created before daily cutoff time in location timezone.

```apex
// Example: Check if before 2 PM local time
Boolean beforeCutoff = SLACalculationUtility.isBeforeCutoff(
    caseRecord, 
    locationAccount, 
    14  // 2 PM cutoff
);

// If true, service date can be today; if false, add 1 day
```

##### `getLocalTime(Account a)`

**Purpose**: Converts current DateTime to location's local timezone.

```apex
// Example
DateTime localTime = SLACalculationUtility.getLocalTime(locationAccount);
Integer localHour = localTime.hour();
```

#### Business Hours Integration

The class integrates with Salesforce **BusinessHours** object to ensure service dates fall on valid business days:

```apex
// Query default business hours
BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault=true];

// Adjust service date to next business day if necessary
while (!BusinessHours.isWithin(bh.Id, c.Service_Date__c) && !e.Override_Business_Hours__c) {
    c.Service_Date__c = c.Service_Date__c.addDays(1);
}
```

**Override**: Entitlements can skip business hours validation with `Override_Business_Hours__c = true`.

#### Legacy Methods (Maintained for Backward Compatibility)

These methods are maintained for existing integrations but should NOT be used in new development:

- `calculateServiceDates()` - Use `setServiceDate()` or `calculateAndSetSLAFields()` instead
- `correctSLADate()` - Logic integrated into main calculation methods
- `convertToLocationTimezone()` - Use `getLocalTime()` instead
- `calculateStandardServiceDates()` - For Activate/Modify/Deactivate cases only

---

## Integration Between Classes

### Typical Call Sequence

#### Scenario 1: Case Insert Trigger (Before Insert)

```apex
// In CaseTriggerHandler.beforeInsert()
public void beforeInsert(List<Case> newCases) {
    
    // STEP 1: Get prioritized entitlements
    Set<Id> caseIds = new Map<Id, Case>(newCases).keySet();
    Map<String, Entitlement> entitlementMap = 
        Entitlement_Utility.getPrioritizedEntitlements(caseIds);
    
    // STEP 2: Set EntitlementId on cases
    for (Case c : newCases) {
        Entitlement ent = entitlementMap.get(c.Id);
        if (ent != null) {
            c.EntitlementId = ent.Id;
        }
    }
    
    // STEP 3: Calculate SLA dates (no DML in before trigger)
    Map<Id, Account> locationMap = buildLocationMap(newCases);
    SLACalculationUtility.calculateAndSetSLAFields(newCases, locationMap);
    
    // Fields are set, trigger framework performs insert
}
```

#### Scenario 2: Case Update Trigger (After Update)

```apex
// In CaseTriggerHandler.afterUpdate()
public void afterUpdate(List<Case> newCases, Map<Id, Case> oldCaseMap) {
    
    List<Case> casesNeedingRecalc = new List<Case>();
    
    // STEP 1: Identify cases requiring SLA recalculation
    for (Case c : newCases) {
        Case oldCase = oldCaseMap.get(c.Id);
        
        if (SLACalculationUtility.requiresSLAandServiceDateReset(c, oldCase)) {
            // Critical fields changed - need to recalculate
            c.EntitlementId = null;  // Clear to force re-evaluation
            c.SLA_Service_Date_Time__c = null;
            casesNeedingRecalc.add(c);
        }
    }
    
    // STEP 2: Recalculate for affected cases (with DML)
    if (!casesNeedingRecalc.isEmpty()) {
        SLACalculationUtility.setServiceDate(casesNeedingRecalc);
    }
}
```

#### Scenario 3: Lightning Web Component

```apex
// In Apex controller for LWC
@AuraEnabled
public static CaseEntitlementWrapper getEntitlementDetails(Id caseId) {
    
    // STEP 1: Get prioritized entitlement
    Set<Id> caseIds = new Set<Id>{ caseId };
    Map<String, Entitlement> entitlements = 
        Entitlement_Utility.getPrioritizedEntitlements(caseIds);
    
    Entitlement selectedEnt = entitlements.get(caseId);
    
    // STEP 2: Get ALL available entitlements for comparison
    Map<String, Map<String, List<Entitlement>>> allEntitlements = 
        Entitlement_Utility.getRelevantEntitlements(caseIds);
    
    // STEP 3: Calculate service date using selected entitlement
    Case caseRecord = [SELECT Id, CreatedDate, Location__c, EntitlementId 
                       FROM Case WHERE Id = :caseId];
    caseRecord.EntitlementId = selectedEnt.Id;
    
    Account location = [SELECT Id, tz__UTF_Offset__c 
                        FROM Account WHERE Id = :caseRecord.Location__c];
    
    SLACalculationUtility.ServiceDateCalculationResult result = 
        SLACalculationUtility.calculateServiceDateWithCapacity(
            caseRecord,
            null, // Asset if available
            selectedEnt,
            location
        );
    
    // STEP 4: Return wrapped data to component
    CaseEntitlementWrapper wrapper = new CaseEntitlementWrapper();
    wrapper.selectedEntitlement = selectedEnt;
    wrapper.allEntitlements = allEntitlements.get(caseId);
    wrapper.calculatedServiceDate = result.serviceDate;
    wrapper.calculationMethod = result.calculationMethod;
    wrapper.availableDates = result.availableDates;
    
    return wrapper;
}
```

---

## Field Dependencies

### Required Case Fields

Both classes expect these fields to be populated on Case records:

**Customer Identification**:
- `Client__c` (Account lookup)
- `Location__c` (Account lookup)

**Service Identification**:
- `Case_Type__c` (e.g., 'Pickup', 'New Service', 'Modify')
- `Case_Sub_Type__c` (Service type)
- `Case_Reason__c`
- `AssetId` (Asset lookup)

**Timing Fields**:
- `Service_Date__c` (Date)
- `SLA_Service_Date_Time__c` (DateTime)
- `SLA_Service_Date__c` (Date - mirrors Service_Date__c for reporting)
- `CreatedDate` (auto-populated)

**Metadata**:
- `RecordTypeId`
- `Status`

### Required Entitlement Fields

**Core Fields**:
- `AccountId` (null for Industry Standard)
- `Name`
- `StartDate` / `EndDate`
- `Status__c` (must be 'Approved')
- `Status` (must not be 'Expired')

**SLA Configuration**:
- `Service_Guarantee_Category__c` ('Hours' or 'Days')
- `Service_Guarantee_Category_Value__c` (numeric value)

**Timing Rules**:
- `Call_Time__c` (e.g., '14:00')
- `Before_After__c` ('Before' or 'After')
- `Call_On__c` (days of week, e.g., 'Mon,Tue,Wed')

**Flags**:
- `Override_Business_Hours__c` (Boolean)
- `Gold_Standard__c` (Boolean)
- `Contractual__c` (Boolean)

**Service Matching** (must align with metadata mappings):
- `Location__c`
- `Material_Type__c`
- `Service__c`
- etc.

### Required Account Fields (Location)

- `tz__UTC_Offset__c` (Decimal - hours offset from UTC)
- `tz__Timezone_SFDC__c` (String - Salesforce timezone ID)

### Required Asset Fields

For Capacity Planner integration:
- `ProductFamily` ('Rolloff', 'Commercial', etc.)
- `Assets_Parent__r` (child relationship to service details)
  - `Is_Self_Service__c`
  - `Quantity__c`
  - `SBID_Text_c__c`
  - `Supplier__r.Parent_Vendor_ID__c`

---

## Error Handling & Fallbacks

### Entitlement_Utility

**If no entitlement found**:
- Returns null in the map for that record ID
- Calling code must handle null entitlements gracefully

**If multiple entitlements tie in prioritization**:
- Uses the entitlement that appears first in the sorted list
- Consistent ordering maintained within priority rank tiers

### SLACalculationUtility

**NoEntitlementException**: Custom exception thrown when EntitlementId is null during calculation.

**Fallback Logic**: When errors occur, applies emergency fallback:
```apex
catch (Exception ex) {
    // Fallback: Set to tomorrow at 11:59 PM
    c.Service_Date__c = System.now().addDays(1).date();
    c.SLA_Service_Date_Time__c = DateTime.newInstance(
        c.Service_Date__c,
        Time.newInstance(23, 59, 59, 59)
    );
    
    // Adjust for business hours
    while (!BusinessHours.isWithin(bh.Id, c.Service_Date__c)) {
        c.Service_Date__c = c.Service_Date__c.addDays(1);
        // Update SLA_Service_Date_Time__c accordingly
    }
}
```

**WM Capacity Planner API Failures**:
- If API returns no dates → Falls back to entitlement-based calculation
- If API times out → Falls back to entitlement-based calculation
- If work order conflicts → Finds next available date after conflicts

---

## Testing Considerations

### Test Data Setup

**Entitlement Test Data**:
```apex
// Create test entitlement
Entitlement testEnt = new Entitlement(
    Name = 'Test Gold Standard',
    AccountId = testAccount.Id,
    StartDate = Date.today().addDays(-30),
    EndDate = Date.today().addDays(365),
    Status__c = 'Approved',
    Status = 'Active',
    Gold_Standard__c = true,
    Service_Guarantee_Category__c = 'Days',
    Service_Guarantee_Category_Value__c = 2,
    Location__c = testLocation.Id,
    Service__c = 'Roll Off Delivery'
);
insert testEnt;
```

**Case Test Data**:
```apex
Case testCase = new Case(
    Client__c = testAccount.Id,
    Location__c = testLocation.Id,
    Case_Type__c = 'New Service',
    Case_Sub_Type__c = 'Roll Off Delivery',
    Case_Reason__c = 'Delivery Request',
    Status = 'New'
);
insert testCase;
```

### Mocking WM Capacity Planner

For Capacity Planner tests, use mock callout:
```apex
@isTest
private class SLACalculationUtilityTest {
    
    @isTest
    static void testCapacityPlannerIntegration() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new CapacityPlannerMock());
        
        Test.startTest();
        List<String> dates = SLACalculationUtility.callWMCapacityPlannerAPI('TEST123');
        Test.stopTest();
        
        System.assertNotEquals(null, dates);
        System.assert(!dates.isEmpty());
    }
    
    private class CapacityPlannerMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"Data":{"Site":{"Capacity":[{"AvailableDates":["2024/12/15","2024/12/16"]}]}}}');
            return res;
        }
    }
}
```

### Test Coverage Best Practices

1. **Test all prioritization scenarios**:
   - Customer + Service + Transaction match
   - Customer + Service match
   - Single category matches
   - No matches (fallback)

2. **Test timezone handling**:
   - Cases before cutoff time
   - Cases after cutoff time
   - Different location timezones

3. **Test business hours**:
   - Service dates falling on weekends
   - Service dates falling on holidays
   - Override business hours flag

4. **Test API failure scenarios**:
   - Capacity Planner timeout
   - Capacity Planner returns empty array
   - Capacity Planner returns invalid JSON

---

## Performance Considerations

### Bulkification

Both classes are designed for bulk processing:

**Entitlement_Utility**:
- Accepts `Set<Id>` of records (not single IDs)
- Queries all entitlements once for all records
- Processes all records in memory with a single query set

**SLACalculationUtility**:
- Accepts `List<Case>` (not single Case)
- Queries business hours once
- Queries entitlements once for all cases
- Performs single DML operation for all cases

### Governor Limit Management

**SOQL Queries**:
- Entitlement_Utility: ~3-5 queries per invocation (metadata, cases/quotes, entitlements)
- SLACalculationUtility: ~2-3 queries per invocation (business hours, locations, entitlements)

**Callouts**:
- WM Capacity Planner API counts as 1 callout per unique SBID
- Limited by Salesforce 100 callout limit per transaction
- Consider using @future or Queueable for high-volume scenarios

**DML Operations**:
- `setServiceDate()`: 1 DML operation (update cases)
- `calculateAndSetSLAFields()`: 0 DML operations (trigger handles it)

### Optimization Tips

1. **Pre-query related data** when possible:
```apex
// Good: Query locations once for all cases
Set<Id> locationIds = new Set<Id>();
for (Case c : cases) {
    locationIds.add(c.Location__c);
}
Map<Id, Account> locationMap = new Map<Id, Account>(
    [SELECT Id, tz__UTF_Offset__c FROM Account WHERE Id IN :locationIds]
);
```

2. **Use static maps for metadata** (already implemented):
```apex
// Metadata queries are cached in class execution context
static List<Entitlement_Field_Mapping__mdt> mappings;

if (mappings == null) {
    mappings = [SELECT ... FROM Entitlement_Field_Mapping__mdt];
}
```

3. **Avoid repeated entitlement queries**:
```apex
// Bad: Querying entitlement multiple times
for (Case c : cases) {
    Entitlement ent = [SELECT Id FROM Entitlement WHERE Id = :c.EntitlementId];
}

// Good: Query once, reference from map
Map<Id, Entitlement> entMap = new Map<Id, Entitlement>(
    [SELECT Id FROM Entitlement WHERE Id IN :entitlementIds]
);
for (Case c : cases) {
    Entitlement ent = entMap.get(c.EntitlementId);
}
```

---

## Common Integration Patterns

### Pattern 1: Before Trigger Integration

**When to use**: Case insert/update in before trigger context

```apex
trigger CaseTrigger on Case (before insert, before update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        CaseTriggerHandler.beforeInsert(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        CaseTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
}

// Handler class
public class CaseTriggerHandler {
    
    public static void beforeInsert(List<Case> newCases) {
        // Filter to cases needing entitlement
        List<Case> needsEntitlement = filterCasesNeedingEntitlement(newCases);
        
        if (!needsEntitlement.isEmpty()) {
            // Get entitlements
            Set<Id> caseIds = new Map<Id, Case>(needsEntitlement).keySet();
            Map<String, Entitlement> entitlements = 
                Entitlement_Utility.getPrioritizedEntitlements(caseIds);
            
            // Assign entitlement IDs
            for (Case c : needsEntitlement) {
                Entitlement ent = entitlements.get(c.Id);
                if (ent != null) {
                    c.EntitlementId = ent.Id;
                }
            }
            
            // Calculate SLA dates (no DML)
            Map<Id, Account> locationMap = buildLocationMap(needsEntitlement);
            SLACalculationUtility.calculateAndSetSLAFields(needsEntitlement, locationMap);
        }
    }
    
    public static void beforeUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        List<Case> needsRecalc = new List<Case>();
        
        for (Case c : newCases) {
            if (SLACalculationUtility.requiresSLAandServiceDateReset(c, oldMap.get(c.Id))) {
                c.EntitlementId = null;
                c.SLA_Service_Date_Time__c = null;
                needsRecalc.add(c);
            }
        }
        
        if (!needsRecalc.isEmpty()) {
            beforeInsert(needsRecalc); // Reuse insert logic
        }
    }
}
```

### Pattern 2: After Trigger Integration

**When to use**: When DML is acceptable (after trigger, async operations)

```apex
public class CaseTriggerHandler {
    
    public static void afterUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        List<Case> needsRecalc = new List<Case>();
        
        for (Case c : newCases) {
            Case oldCase = oldMap.get(c.Id);
            
            // Check if critical SLA fields changed
            if (c.Case_Type__c != oldCase.Case_Type__c ||
                c.Location__c != oldCase.Location__c ||
                c.AssetId != oldCase.AssetId) {
                    
                // Clear existing SLA data
                c.EntitlementId = null;
                c.SLA_Service_Date_Time__c = null;
                needsRecalc.add(c);
            }
        }
        
        if (!needsRecalc.isEmpty()) {
            // This method includes DML
            SLACalculationUtility.setServiceDate(needsRecalc);
        }
    }
}
```

### Pattern 3: Lightning Web Component Integration

**When to use**: User-initiated entitlement selection or date calculation

```apex
public class CaseEntitlementController {
    
    @AuraEnabled
    public static EntitlementSelectionWrapper getEntitlementOptions(Id caseId) {
        
        // Get both prioritized and all available entitlements
        Set<Id> caseIds = new Set<Id>{ caseId };
        
        Map<String, Entitlement> prioritized = 
            Entitlement_Utility.getPrioritizedEntitlements(caseIds);
            
        Map<String, Map<String, List<Entitlement>>> allOptions = 
            Entitlement_Utility.getRelevantEntitlements(caseIds);
        
        // Calculate service date for recommended entitlement
        Case caseRecord = [SELECT Id, CreatedDate, Location__c, AssetId, EntitlementId
                           FROM Case WHERE Id = :caseId];
        
        Entitlement recommended = prioritized.get(caseId);
        if (recommended != null) {
            caseRecord.EntitlementId = recommended.Id;
            
            // Calculate service date
            Account location = [SELECT Id, tz__UTF_Offset__c 
                                FROM Account WHERE Id = :caseRecord.Location__c];
            
            SLACalculationUtility.ServiceDateCalculationResult result = 
                SLACalculationUtility.calculateServiceDateWithCapacity(
                    caseRecord, null, recommended, location
                );
            
            // Prepare response
            EntitlementSelectionWrapper wrapper = new EntitlementSelectionWrapper();
            wrapper.recommendedEntitlement = recommended;
            wrapper.allEntitlements = allOptions.get(caseId);
            wrapper.calculatedServiceDate = result.serviceDate;
            wrapper.slaDateTime = result.slaServiceDateTime;
            wrapper.calculationMethod = result.calculationMethod;
            wrapper.availableDates = result.availableDates;
            
            return wrapper;
        }
        
        return null;
    }
    
    @AuraEnabled
    public static Date recalculateServiceDate(Id caseId, Id entitlementId) {
        
        // User selected different entitlement - recalculate
        Case c = [SELECT Id, CreatedDate, Location__c, AssetId FROM Case WHERE Id = :caseId];
        c.EntitlementId = entitlementId;
        
        Entitlement ent = [SELECT Id, Service_Guarantee_Category__c, 
                                   Service_Guarantee_Category_Value__c,
                                   Gold_Standard__c, Contractual__c
                           FROM Entitlement WHERE Id = :entitlementId];
        
        Account location = [SELECT Id, tz__UTF_Offset__c 
                            FROM Account WHERE Id = :c.Location__c];
        
        SLACalculationUtility.ServiceDateCalculationResult result = 
            SLACalculationUtility.calculateServiceDateWithCapacity(c, null, ent, location);
        
        // Update case
        c.Service_Date__c = result.serviceDate;
        c.SLA_Service_Date_Time__c = result.slaServiceDateTime;
        update c;
        
        return result.serviceDate;
    }
    
    public class EntitlementSelectionWrapper {
        @AuraEnabled public Entitlement recommendedEntitlement;
        @AuraEnabled public Map<String, List<Entitlement>> allEntitlements;
        @AuraEnabled public Date calculatedServiceDate;
        @AuraEnabled public DateTime slaDateTime;
        @AuraEnabled public String calculationMethod;
        @AuraEnabled public List<String> availableDates;
    }
}
```

### Pattern 4: Batch/Scheduled Job Integration

**When to use**: Mass recalculation of SLA dates for data cleanup

```apex
public class RecalculateSLABatch implements Database.Batchable<sObject> {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Find cases with missing or incorrect SLA dates
        return Database.getQueryLocator([
            SELECT Id, Client__c, Location__c, Case_Type__c, Case_Sub_Type__c,
                   EntitlementId, Service_Date__c, SLA_Service_Date_Time__c, CreatedDate
            FROM Case
            WHERE SLA_Service_Date_Time__c = null
            AND CreatedDate >= LAST_N_DAYS:30
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Case> scope) {
        
        // Clear entitlements to force recalculation
        for (Case c : scope) {
            c.EntitlementId = null;
            c.SLA_Service_Date_Time__c = null;
        }
        
        // Get prioritized entitlements
        Set<Id> caseIds = new Map<Id, Case>(scope).keySet();
        Map<String, Entitlement> entitlements = 
            Entitlement_Utility.getPrioritizedEntitlements(caseIds);
        
        // Assign entitlements
        for (Case c : scope) {
            Entitlement ent = entitlements.get(c.Id);
            if (ent != null) {
                c.EntitlementId = ent.Id;
            }
        }
        
        // Recalculate SLA dates (includes DML)
        SLACalculationUtility.setServiceDate(scope);
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('SLA recalculation batch completed');
    }
}

// Schedule the batch
System.schedule('Recalculate SLA Dates', '0 0 2 * * ?', new RecalculateSLABatch());
```

---

## Troubleshooting Guide

### Issue: Case has no EntitlementId after processing

**Possible Causes**:
1. No entitlement matches the case criteria
2. All potential entitlements are expired or unapproved
3. Call time/day filtering eliminated all options

**Debugging Steps**:
```apex
// Enable debug logs
Set<Id> caseIds = new Set<Id>{ caseId };

// Check what entitlements are being retrieved
Map<String, Map<String, List<Entitlement>>> allEnts = 
    Entitlement_Utility.getRelevantEntitlements(caseIds);
System.debug('All relevant entitlements: ' + allEnts);

// Check prioritization results
Map<String, Entitlement> prioritized = 
    Entitlement_Utility.getPrioritizedEntitlements(caseIds);
System.debug('Prioritized entitlement: ' + prioritized.get(caseId));
```

**Resolution**:
- Verify entitlement StartDate/EndDate ranges
- Check entitlement Status__c = 'Approved'
- Review Call_On__c day of week settings
- Ensure Account matching criteria align

### Issue: SLA date is incorrect or in the past

**Possible Causes**:
1. Service_Date__c was backdated
2. Business hours not configured correctly
3. Timezone offset incorrect on location

**Debugging Steps**:
```apex
// Check calculation details
Case c = [SELECT Id, CreatedDate, Service_Date__c, SLA_Service_Date_Time__c,
                 Location__r.tz__UTF_Offset__c, EntitlementId
          FROM Case WHERE Id = :caseId];

Entitlement e = [SELECT Service_Guarantee_Category__c, 
                        Service_Guarantee_Category_Value__c
                 FROM Entitlement WHERE Id = :c.EntitlementId];

Integer daysDelta = SLACalculationUtility.getDaysDelta(e);
System.debug('Days delta: ' + daysDelta);
System.debug('Created: ' + c.CreatedDate);
System.debug('Calculated SLA: ' + c.CreatedDate.addDays(daysDelta));

// Check business hours
BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault=true];
Boolean withinHours = BusinessHours.isWithin(bh.Id, c.Service_Date__c);
System.debug('Within business hours: ' + withinHours);
```

**Resolution**:
- Verify Business Hours calendar includes correct working days
- Check location timezone settings
- Review entitlement Service_Guarantee_Category_Value__c

### Issue: WM Capacity Planner not being called

**Possible Causes**:
1. Product Family is not 'Rolloff'
2. Vendor is not WM (Parent_Vendor_ID__c != '8')
3. SBID is missing
4. Entitlement is Gold Standard or Contractual (overrides capacity check)

**Debugging Steps**:
```apex
// Check decision criteria
Asset asset = [SELECT Id, ProductFamily, Assets_Parent__r.SBID_Text_c__c,
                      Assets_Parent__r.Supplier__r.Parent_Vendor_ID__c
               FROM Asset WHERE Id = :assetId];

Entitlement ent = [SELECT Gold_Standard__c, Contractual__c 
                   FROM Entitlement WHERE Id = :entitlementId];

System.debug('Product Family: ' + asset.ProductFamily);
System.debug('Vendor ID: ' + asset.Assets_Parent__r.Supplier__r.Parent_Vendor_ID__c);
System.debug('SBID: ' + asset.Assets_Parent__r.SBID_Text_c__c);
System.debug('Gold Standard: ' + ent.Gold_Standard__c);
System.debug('Contractual: ' + ent.Contractual__c);
```

**Resolution**:
- Ensure Product Family = 'Rolloff' (case-sensitive)
- Verify Parent_Vendor_ID__c = '8' on supplier
- Check SBID_Text_c__c is populated
- Review entitlement flags

### Issue: Performance degradation with large record sets

**Possible Causes**:
1. Not bulkifying queries
2. Querying inside loops
3. Too many callouts in single transaction

**Debugging Steps**:
```apex
// Check governor limits
System.debug('SOQL queries used: ' + Limits.getQueries());
System.debug('DML statements used: ' + Limits.getDmlStatements());
System.debug('Callouts used: ' + Limits.getCallouts());
```

**Resolution**:
- Process cases in batches of 200 or fewer
- Use @future or Queueable for callout-heavy operations
- Pre-query related data (locations, assets) before processing
- Consider async processing for large data volumes

---

## Configuration Checklist

### Initial Setup

- [ ] **Custom Metadata**: Configure Entitlement_Field_Mapping__mdt records
  - Define priority levels (0A-4N)
  - Map Case, Quote, and Entitlement fields
  
- [ ] **Entitlement Records**: Create baseline entitlements
  - Industry Standard (AccountId = null)
  - Customer-specific entitlements
  - Set StartDate/EndDate ranges
  - Configure Service_Guarantee_Category__c and values
  
- [ ] **Business Hours**: Configure default business hours calendar
  - Set working days
  - Set working hours per day
  - Account for holidays
  
- [ ] **Location Accounts**: Populate timezone fields
  - tz__UTC_Offset__c (decimal hours from UTC)
  - tz__Timezone_SFDC__c (Salesforce timezone ID)
  
- [ ] **Integration Settings** (if using WM Capacity Planner):
  - Configure Integration_Request_URLs__mdt (DeveloperName = 'Site_Capacity')
  - Set endpoint, authentication headers, timeout
  - Test connectivity from sandbox

### Validation Rules

Consider adding validation rules to ensure data quality:

```apex
// Validation: EntitlementId required for certain case types
AND(
    ISBLANK(TEXT(EntitlementId)),
    ISPICKVAL(Case_Type__c, 'New Service'),
    ISPICKVAL(Status, 'New')
)

// Error: "Entitlement required for New Service cases"
```

```apex
// Validation: Service Date required when EntitlementId set
AND(
    NOT(ISBLANK(TEXT(EntitlementId))),
    ISBLANK(Service_Date__c)
)

// Error: "Service Date must be calculated when entitlement is assigned"
```

### Monitoring & Alerting

Set up monitoring for:

1. **Cases with no entitlement** (after 24 hours):
```soql
SELECT Id, CaseNumber, CreatedDate, Case_Type__c
FROM Case
WHERE EntitlementId = null
AND CreatedDate < LAST_N_DAYS:1
AND Status = 'New'
```

2. **SLA dates in the past**:
```soql
SELECT Id, CaseNumber, SLA_Service_Date_Time__c
FROM Case
WHERE SLA_Service_Date_Time__c < TODAY
AND IsClosed = false
```

3. **WM Capacity Planner API failures** (via UTIL_LoggingService):
```soql
SELECT Id, Error_Message__c, CreatedDate
FROM Error_Log__c
WHERE Error_Message__c LIKE '%Capacity Planner%'
AND CreatedDate = TODAY
```

---

## Migration Guidance

### Migrating from Static Variables

If you have existing code using deprecated static variables:

**Old Pattern**:
```apex
// ❌ Deprecated pattern
Entitlement_Utility.accountIdSet = new Set<Id>{ accountId };
Entitlement_Utility.minimumServiceDate = Date.today();

// Call methods that read from static variables
Map<String, List<Entitlement>> ents = Entitlement_Utility.getEntitlements(...);
```

**New Pattern**:
```apex
// ✅ Current pattern
Set<Id> targetRecords = new Set<Id>{ caseId };
Map<String, Entitlement> ents = Entitlement_Utility.getPrioritizedEntitlements(targetRecords);
```

### Migrating from CaseTriggerHelper Static Maps

**Old Pattern**:
```apex
// ❌ Old code wrote to static variable
SLACalculationUtility.buildCaseLocationMap(cases);
Map<Case, Account> locations = CaseTriggerHelper.casewithLocation; // Read from helper
```

**New Pattern**:
```apex
// ✅ New code returns the map directly
Map<Case, Account> locations = SLACalculationUtility.buildCaseLocationMap(cases);
```

---

## Appendix: Key Classes & Methods Reference

### Entitlement_Utility

| Method | Parameters | Returns | Use Case |
|--------|-----------|---------|----------|
| `getPrioritizedEntitlements` | `Set<Id> targetRecords` | `Map<String, Entitlement>` | Get single best entitlement per record |
| `getRelevantEntitlements` | `Set<Id> targetRecords` | `Map<String, Map<String, List<Entitlement>>>` | Get all valid entitlements grouped by type |
| `getFieldMapping` | none | `List<Entitlement_Field_Mapping__mdt>` | Load metadata configuration |
| `parseAndGroupEntitlements` | `Map<String, List<Entitlement>>` | `Map<String, Map<String, List<Entitlement>>>` | Parse and group by type |
| `prioritizeEntitlements` | `List<priorityFields>`, `Map<String, List<Entitlement>>` | `Map<String, Entitlement>` | Apply prioritization algorithm |

### SLACalculationUtility

| Method | Parameters | Returns | Use Case |
|--------|-----------|---------|----------|
| `setServiceDate` | `List<Case>` | void | Flow/PB - calculates and updates with DML |
| `calculateAndSetSLAFields` | `List<Case>`, `Map<Id, Account>` | void | Before trigger - calculates without DML |
| `calculateServiceDateWithCapacity` | `Case`, `Asset`, `Entitlement`, `Account` | `ServiceDateCalculationResult` | Orchestrate capacity planner logic |
| `callWMCapacityPlannerAPI` | `String sbid` | `List<String>` | Get available dates from API |
| `buildCaseLocationMap` | `List<Case>` | `Map<Case, Account>` | Build location map with timezones |
| `getDaysDelta` | `Entitlement` | `Integer` | Convert SLA value to days |
| `isBeforeCutoff` | `Case`, `Account`, `Integer` | `Boolean` | Check if before daily cutoff |
| `getLocalTime` | `Account` | `DateTime` | Convert to location timezone |
| `requiresSLAandServiceDateReset` | `Case`, `Case` | `Boolean` | Determine if recalc needed |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-21 | Documentation Team | Initial comprehensive guide created |

---

## Additional Resources

- **Custom Metadata**: Setup → Custom Metadata Types → Entitlement_Field_Mapping
- **Entitlements**: Entitlement Management tab
- **Business Hours**: Setup → Business Hours
- **Integration Settings**: Setup → Custom Metadata Types → Integration_Request_URLs
- **Debug Logs**: Setup → Debug Logs (enable for User ID when troubleshooting)

---

**Questions or Issues?** Contact the Salesforce development team or submit a ticket to the IT Help Desk.
