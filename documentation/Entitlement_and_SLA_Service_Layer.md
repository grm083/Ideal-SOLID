# Entitlement and SLA Service Layer Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Entitlement_Utility Class](#entitlement_utility-class)
4. [SLACalculationUtility Class](#slacalculationutility-class)
5. [Integration Patterns](#integration-patterns)
6. [Usage Examples](#usage-examples)
7. [Testing Considerations](#testing-considerations)
8. [Best Practices](#best-practices)

---

## Overview

The Entitlement and SLA Service Layer consists of two sister classes that work in concert to provide comprehensive service level agreement (SLA) management for customer cases:

- **Entitlement_Utility**: Identifies and prioritizes the appropriate entitlement for a customer based on their account, service details, and transaction context
- **SLACalculationUtility**: Calculates the SLA Service Date and Time using the entitlement and business rules

These classes serve as a **service layer** in the broader case management architecture, providing reusable business logic that can be invoked by triggers, Lightning components, Flow, and other service classes.

### Key Benefits

- **Separation of Concerns**: Entitlement selection is decoupled from SLA calculation
- **Reusability**: Methods can be called from multiple contexts (triggers, flows, UI components)
- **Testability**: Business logic is isolated from data access and DML operations
- **Maintainability**: Changes to entitlement or SLA rules are centralized

---

## Architecture

### System Context

```
┌─────────────────────────────────────────────────────────────┐
│                     Case Management System                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   SERVICE LAYER (You Are Here)                │
│  ┌─────────────────────┐         ┌──────────────────────┐   │
│  │ Entitlement_Utility │────────▶│ SLACalculationUtility│   │
│  └─────────────────────┘         └──────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Data Layer                               │
│  - Entitlement                                                │
│  - Case                                                       │
│  - Account                                                    │
│  - Asset                                                      │
│  - Entitlement_Field_Mapping__mdt                            │
│  - Industry_Standard_SLA__mdt                                │
└─────────────────────────────────────────────────────────────┘
```

### Design Pattern

These classes implement the **Service Layer Pattern** with these characteristics:

- **Stateless Operations**: Methods are static and don't maintain instance state
- **Parameter-Based**: All data dependencies are passed as method parameters
- **No DML Side Effects**: Service methods return data structures; calling code performs DML
- **Clear Contracts**: Public methods have well-defined inputs/outputs

---

## Entitlement_Utility Class

### Purpose

The `Entitlement_Utility` class is responsible for finding and prioritizing entitlements for Case and Quote records. It queries entitlements based on configurable field mappings and applies sophisticated prioritization logic to determine the "best" entitlement for each record.

### Core Responsibilities

1. **Query Construction**: Dynamically builds SOQL queries based on metadata configuration
2. **Field Mapping**: Matches fields between Cases/Quotes and Entitlements using custom metadata
3. **Filtering**: Applies time-based, day-of-week, and account-based filters
4. **Prioritization**: Ranks entitlements based on customer, service, and transaction matches

### Public API

#### Primary Methods

```apex
// Returns the single highest-priority entitlement for each target record
public static Map<String, Entitlement> getPrioritizedEntitlements(Set<Id> targetRecords)

// Returns all relevant entitlements grouped by type (Industry Standard vs Customer Specific)
public static Map<String, Map<String, List<Entitlement>>> getRelevantEntitlements(Set<Id> targetRecords)
```

#### Specialized Methods

```apex
// Returns industry standard SLA entitlements for a specific case
public static List<Entitlement> getIndustryStandardSLA(Case caseRecord)

// Returns field mapping metadata used for entitlement matching
public static List<Entitlement_Field_Mapping__mdt> getFieldMapping()
```

### How It Works

#### Step 1: Gather Record Details

When you pass a Set of Case or Quote IDs, the class:

1. Identifies which records are Cases vs Quotes
2. Queries the relevant fields from each object based on `Entitlement_Field_Mapping__mdt`
3. Extracts Account IDs and minimum Service Date for filtering
4. Constructs a `priorityFields` wrapper for each field that needs to be matched

**Example Field Mapping:**
```
Priority | Common Name    | Case Field              | Entitlement Field
---------|----------------|-------------------------|------------------
0A       | Account Name   | Client__c               | AccountId
1B       | Division       | Division__c             | Division__c
2A       | Material Type  | Material__c             | Material__c
3A       | Request Type   | Case_Type__c            | Request_Type__c
```

#### Step 2: Query Entitlements

The class queries all **approved** entitlements where:
- `AccountId` matches any of the collected Account IDs (or is null for industry standard)
- `StartDate` is on or before the minimum Service Date
- Status is "Approved" and not "Expired"

#### Step 3: Filter by Time and Day

Entitlements are filtered based on:
- **Day of Week**: Checks `Call_On__c` field (e.g., "Mon,Tue,Wed")
- **Time of Day**: Checks `Call_Time__c` and `Before_After__c` fields
- Current system time vs cutoff time

**Example:**
```apex
// Entitlement with Call_Time__c = '14:00' and Before_After__c = 'After'
// Will only be returned if current hour >= 14
```

#### Step 4: Prioritize Entitlements

The prioritization logic scores each entitlement based on field matches:

**Priority Scoring:**
```
Priority 0 (Highest): Customer + Service + Transaction match
Priority 1: Customer + Service match
Priority 2: Customer + Transaction match
Priority 3: Customer only match
Priority 4: Service + Transaction match
Priority 5: Service only match
Priority 6: Transaction only match
Priority 7 (Lowest): No matches
```

**Match Categories:**
- **Customer Identification** (Priority 0A-1H): Account, Division, Location details
- **Service Identification** (Priority 2A-2C): Material, Schedule type
- **Transaction Identification** (Priority 3A-4N): Request type, Case reason, Call time

The class returns the entitlement with the lowest priority rank (highest priority) and highest individual match scores.

### Data Structures

#### priorityFields Wrapper

```apex
public class priorityFields {
    public Id recordId { get; set; }           // Case or Quote ID
    public String priorityLevel { get; set; }  // e.g., "0A", "2C", "3B"
    public String commonName { get; set; }     // Human-readable field name
    public String entitlementField { get; set; } // API name on Entitlement
    public String objectValue { get; set; }    // Value from Case/Quote
}
```

#### prioritizationResult Wrapper

```apex
public class prioritizationResult {
    public Entitlement entitlementRecord { get; set; }
    public Boolean customerIdentification { get; set; }
    public Boolean serviceIdentification { get; set; }
    public Boolean transactionIdentification { get; set; }
    public Integer priorityRank { get; set; }      // 0-7 overall ranking
    public Integer customerRank { get; set; }      // Number of customer matches
    public Integer serviceRank { get; set; }       // Number of service matches
    public Integer transactionRank { get; set; }   // Number of transaction matches
}
```

### Configuration

The class relies on **Custom Metadata Types** for configuration:

#### Entitlement_Field_Mapping__mdt

Defines which fields should be compared between Cases/Quotes and Entitlements.

**Key Fields:**
- `Priority_Value__c`: Determines matching priority (e.g., "0A", "1B", "2C")
- `MasterLabel`: Human-readable field name
- `Case__c`: Field API name on Case (supports dot notation for relationships)
- `Quote__c`: Field API name on Quote
- `Entitlement__c`: Field API name on Entitlement

**Example Record:**
```
MasterLabel: Location Division
Priority_Value__c: 1B
Case__c: Location__r.Division__c
Quote__c: SBQQ__Account__r.Division__c
Entitlement__c: Division__c
```

---

## SLACalculationUtility Class

### Purpose

The `SLACalculationUtility` class calculates service dates and SLA timestamps for cases based on entitlements, business hours, time zones, and business rules. It handles multiple calculation scenarios including standard entitlements, capacity planning, and fallback logic.

### Core Responsibilities

1. **SLA Date Calculation**: Determines when service should be completed based on entitlement guarantees
2. **Business Hours Adjustment**: Ensures dates fall on business days
3. **Timezone Conversion**: Handles location-specific time calculations
4. **Capacity Planning Integration**: Coordinates with WM Capacity Planner API for Rolloff services
5. **Fallback Logic**: Provides default SLA dates when entitlements are missing

### Public API

#### Primary Calculation Methods

```apex
// Main invocable method for Flow/Process Builder
@InvocableMethod(label='Set Service Date')
public static void setServiceDate(List<Case> caseList)

// Trigger-safe version that modifies cases in-place without DML
public static void calculateAndSetSLAFields(List<Case> caseList, Map<Id, Account> caseLocationMap)

// Orchestrates calculation with capacity planning integration
public static ServiceDateCalculationResult calculateServiceDateWithCapacity(
    Case caseRecord,
    Asset asset,
    Entitlement entitlement,
    Account location
)
```

#### Helper Methods

```apex
// Builds case-to-location account map
public static Map<Case, Account> buildCaseLocationMap(List<Case> caseList)

// Converts datetime to location timezone
public static Datetime getLocalTime(Account a)
public static Boolean isBeforeCutoff(Case c, Account a, Integer cutoffHour)

// Calculates days delta from entitlement guarantee
public static Integer getDaysDelta(Entitlement e)

// Capacity planner integration
public static List<String> callWMCapacityPlannerAPI(String sbid)
```

### How It Works

#### Calculation Flow

```
┌──────────────────────────────────────────────────────────┐
│  1. Case Created/Updated                                  │
└──────────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────┐
│  2. Call Entitlement_Utility.getPrioritizedEntitlements  │
│     → Returns best entitlement for case                   │
└──────────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────┐
│  3. SLACalculationUtility.setServiceDate                 │
│     → Populates Case.EntitlementId                        │
│     → Calls CaseEntitlement.populateEntitlement()         │
└──────────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────┐
│  4. Calculate SLA                                         │
│     a. Get daysDelta from entitlement                     │
│     b. Check before/after cutoff time                     │
│     c. Add days to CreatedDate                            │
│     d. Adjust for business hours                          │
└──────────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────┐
│  5. Set Case Fields                                       │
│     - Service_Date__c                                     │
│     - SLA_Service_Date__c                                 │
│     - SLA_Service_Date_Time__c                            │
└──────────────────────────────────────────────────────────┘
```

#### Step 1: Populate Entitlement

The `setServiceDate` method first ensures each case has an entitlement:

```apex
// Calls CaseEntitlement service class
CaseEntitlement.populateEntitlement(caseList);
```

This sets `Case.EntitlementId` by calling `Entitlement_Utility.getPrioritizedEntitlements()` internally.

#### Step 2: Query Entitlements

Queries entitlements to get calculation fields:

```apex
SELECT Id, Name, Call_Time__c, Before_After__c, Override_Business_Hours__c,
       Service_Guarantee_Category__c, Service_Guarantee_Category_Value__c
FROM Entitlement
WHERE Id IN :entitlementIds
```

#### Step 3: Calculate Days Delta

Determines how many days to add based on entitlement guarantee:

```apex
public static Integer getDaysDelta(Entitlement e) {
    Integer daysDelta;
    
    if (e.Service_Guarantee_Category__c == 'Days') {
        // Direct day count: "2" = 2 days
        daysDelta = Integer.valueOf(e.Service_Guarantee_Category_Value__c);
    } else {
        // Hours converted to days: "24" hours = 1 day
        Integer hours = Integer.valueOf(e.Service_Guarantee_Category_Value__c);
        daysDelta = Integer.valueOf(Math.floor(hours/24));
    }
    
    return daysDelta;
}
```

**Example:**
- Entitlement with "2 Days" guarantee → daysDelta = 2
- Entitlement with "48 Hours" guarantee → daysDelta = 2

#### Step 4: Check Cutoff Time

If the entitlement doesn't specify `Call_Time__c` and `Before_After__c`, checks if case was created before the 2:00 PM cutoff:

```apex
Boolean beforeCutoff = isBeforeCutoff(c, account, 14); // 14 = 2:00 PM

if (!beforeCutoff) {
    daysDelta += 1; // Add an extra day if after cutoff
}
```

**Example:**
- Case created at 1:00 PM local time with 2-day SLA → Service Date = CreatedDate + 2 days
- Case created at 3:00 PM local time with 2-day SLA → Service Date = CreatedDate + 3 days

#### Step 5: Calculate and Adjust Date

```apex
DateTime SLADate = c.CreatedDate.addDays(daysDelta);
c.Service_Date__c = SLADate.Date();

// Adjust for business hours
BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault=true];
while (!BusinessHours.isWithin(bh.Id, c.Service_Date__c) && !e.Override_Business_Hours__c) {
    c.Service_Date__c = c.Service_Date__c.addDays(1);
}

c.SLA_Service_Date__c = c.Service_Date__c;
c.SLA_Service_Date_Time__c = SLADate;
```

**Business Hours Logic:**
- Checks if calculated date is a business day
- If not (weekend/holiday), increments by 1 day and checks again
- Continues until a valid business day is found
- Can be overridden by `Entitlement.Override_Business_Hours__c = true`

#### Step 6: Handle Exceptions

If any error occurs (missing entitlement, invalid data, etc.):

```apex
catch (Exception ex) {
    // Fallback: Next business day at 11:59 PM
    c.Service_Date__c = System.now().addDays(1).date();
    c.SLA_Service_Date__c = c.Service_Date__c;
    c.SLA_Service_Date_Time__c = DateTime.newInstance(
        c.SLA_Service_Date__c,
        Time.newInstance(23, 59, 59, 59)
    );
    
    // Still respect business hours
    while (!BusinessHours.isWithin(bh.Id, c.Service_Date__c)) {
        c.Service_Date__c = c.Service_Date__c.addDays(1);
        // ... adjust other fields
    }
}
```

### Capacity Planning Integration

For **Rolloff services** with **WM vendors**, the class can integrate with the WM Capacity Planner API.

#### Decision Logic

```apex
public static ServiceDateCalculationResult calculateServiceDateWithCapacity(
    Case caseRecord,
    Asset asset,
    Entitlement entitlement,
    Account location
) {
    // Decision 1: Use Entitlement if Gold Standard, Contractual, or Commercial
    Boolean useEntitlementCalculation = (
        entitlement.Gold_Standard__c ||
        entitlement.Contractual__c ||
        asset.ProductFamily == 'Commercial'
    );
    
    // Decision 2: Use Capacity Planner if Rolloff + WM Vendor + has SBID
    Boolean useCapacityPlanner = (
        !useEntitlementCalculation &&
        asset.ProductFamily == 'Rolloff' &&
        asset has WM vendor (Parent_Vendor_ID__c = '8') &&
        asset has valid SBID
    );
    
    // Execute appropriate calculation method
    if (useEntitlementCalculation) {
        return calculateEntitlementBasedServiceDate(...);
    } else if (useCapacityPlanner) {
        return calculateCapacityPlannerServiceDate(...);
    } else {
        return calculateEntitlementBasedServiceDate(...); // Default
    }
}
```

#### Capacity Planner Flow

```
┌─────────────────────────────────────────────────┐
│ Extract SBID from Asset Service Details         │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ Call WM Capacity Planner API                    │
│ GET /sites/{SBID}/capacity?serviceDate={date}  │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ Parse Available Dates from JSON Response        │
│ Returns: ["12/25/2024", "12/26/2024", ...]     │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ Query Existing Work Orders for Asset            │
│ Identify conflict dates                         │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ Select First Non-Conflicting Date               │
│ If all conflict, use next available after last  │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ Return ServiceDateCalculationResult              │
│ - serviceDate: Selected date                     │
│ - slaServiceDateTime: DateTime at 21:00         │
│ - calculationMethod: "Capacity Planner"         │
└─────────────────────────────────────────────────┘
```

**Fallback:** If Capacity Planner fails or returns no dates, automatically falls back to entitlement-based calculation.

### Timezone Handling

The class carefully manages timezone conversions for accurate local time calculations:

```apex
public static Datetime getLocalTime(Account a) {
    return DateTime.now().addHours(Integer.valueOf(a.tz__UTF_Offset__c));
}

public static Datetime convertToLocationTimezone(Datetime localdate, Case c, 
                                                  Map<Id,Account> casewithLocationMap) {
    Timezone tz;
    if (casewithLocationMap.containsKey(c.Location__c)) {
        String tzString = casewithLocationMap.get(c.Location__c).tz__Timezone_SFDC__c;
        tz = Timezone.getTimeZone(tzString);
        localdate = localdate.addSeconds((tz.getOffset(localdate)/1000));
    }
    return localdate;
}
```

**Key Principle:** Cases are always evaluated in the **location's local timezone**, not UTC or the user's timezone.

### Additional Calculation Methods

The class includes several specialized calculation methods for specific case types:

#### Standard Service Dates
```apex
// For Activate/Modify/Deactivate cases - uses EST timezone
public static List<Case> calculateStandardServiceDates(List<Case> newCaseList)
public static void syncStandardServiceDateToSLA(List<case> caseNewList, Map<Id,case> oldCasemap)
```

#### Intake SLA Datetime
```apex
// For pickup cases with specific SLA calculation rules
public static Datetime calculateIntakeSLADatetime(Datetime serviceDate, Datetime currentSLADate, 
                                                  Case c, Map<Id,Account> casewithLocationMap)
```

#### Service Date to SLA Sync
```apex
// Synchronizes SLA fields when Service_Date__c is manually changed
public static void syncServiceDateToSLA(List<case> caseNewList, Map<Id,case> oldCasemap, 
                                        Map<Id,Account> casewithLocationMap)
```

#### SLA Date Correction
```apex
// Prevents backdating of SLA dates (SDT-32837)
public static Datetime correctSLADate(Case c, Map<Id,Account> casewithLocationMap)
```

### Data Structures

#### ServiceDateCalculationResult

```apex
public class ServiceDateCalculationResult {
    public Date serviceDate { get; set; }
    public DateTime slaServiceDateTime { get; set; }
    public String calculationMethod { get; set; }  // 'Entitlement', 'Capacity Planner', 'Fallback'
    public List<String> availableDates { get; set; } // From capacity planner
    public String errorMessage { get; set; }
}
```

This wrapper provides full visibility into how the SLA was calculated, enabling audit trails and debugging.

---

## Integration Patterns

### How These Classes Work Together

The typical interaction flow:

```apex
// PATTERN 1: Trigger Context (Before Insert/Update)
// Called from CaseTriggerHandler

public void beforeInsert(List<Case> newCases) {
    // Step 1: Get entitlements
    Set<Id> caseIds = new Map<Id, Case>(newCases).keySet();
    Map<String, Entitlement> entitlementMap = 
        Entitlement_Utility.getPrioritizedEntitlements(caseIds);
    
    // Step 2: Set EntitlementId on cases
    for (Case c : newCases) {
        if (entitlementMap.containsKey(c.Id)) {
            c.EntitlementId = entitlementMap.get(c.Id).Id;
        }
    }
    
    // Step 3: Calculate SLA (no DML needed, trigger will save)
    Map<Id, Account> locationMap = buildLocationMap(newCases);
    SLACalculationUtility.calculateAndSetSLAFields(newCases, locationMap);
}
```

```apex
// PATTERN 2: Service Layer Context
// Called from another service class or controller

public static void processNewCustomerCase(Case newCase) {
    // Step 1: Ensure case has required data
    if (newCase.Location__c == null) {
        throw new RequiredFieldException('Location is required');
    }
    
    // Step 2: Get entitlement
    Map<String, Entitlement> entitlements = 
        Entitlement_Utility.getPrioritizedEntitlements(new Set<Id>{ newCase.Id });
    
    if (entitlements.containsKey(newCase.Id)) {
        newCase.EntitlementId = entitlements.get(newCase.Id).Id;
    }
    
    // Step 3: Calculate SLA
    Map<Id, Account> locationMap = new Map<Id, Account>{
        newCase.Location__c => [SELECT Id, tz__UTF_Offset__c, tz__Timezone_SFDC__c 
                                FROM Account WHERE Id = :newCase.Location__c]
    };
    
    SLACalculationUtility.calculateAndSetSLAFields(
        new List<Case>{ newCase }, 
        locationMap
    );
    
    // Step 4: DML
    insert newCase;
}
```

```apex
// PATTERN 3: Lightning Component / Aura Controller
// Called from UI

@AuraEnabled
public static Map<String, Object> getEntitlementAndSLA(Id caseId) {
    Map<String, Object> result = new Map<String, Object>();
    
    // Get case details
    Case c = [SELECT Id, Client__c, Location__c, Case_Type__c, Service_Date__c, AssetId
              FROM Case WHERE Id = :caseId];
    
    // Get available entitlements
    Map<String, Map<String, List<Entitlement>>> allEntitlements = 
        Entitlement_Utility.getRelevantEntitlements(new Set<Id>{ caseId });
    
    // Get prioritized entitlement
    Map<String, Entitlement> prioritized = 
        Entitlement_Utility.getPrioritizedEntitlements(new Set<Id>{ caseId });
    
    // Calculate SLA
    if (c.AssetId != null) {
        Asset serviceHeader = [SELECT Id, ProductFamily FROM Asset WHERE Id = :c.AssetId];
        Account location = [SELECT Id, tz__UTF_Offset__c, tz__Timezone_SFDC__c 
                           FROM Account WHERE Id = :c.Location__c];
        
        SLACalculationUtility.ServiceDateCalculationResult slaResult = 
            SLACalculationUtility.calculateServiceDateWithCapacity(
                c, serviceHeader, prioritized.get(caseId), location
            );
        
        result.put('slaResult', slaResult);
    }
    
    result.put('allEntitlements', allEntitlements);
    result.put('selectedEntitlement', prioritized.get(caseId));
    
    return result;
}
```

```apex
// PATTERN 4: Invocable Method (Flow/Process Builder)
// Declarative automation

// Create Flow with these elements:
// 1. Get Records: Query Cases
// 2. Action: Call SLACalculationUtility.setServiceDate
// 3. Update Records: Save Cases with calculated SLA fields

// Note: setServiceDate performs DML internally
```

### Calling Contexts

| Context | Use Case | Recommended Method | DML Handling |
|---------|----------|-------------------|--------------|
| Before Trigger | Set fields before insert/update | `calculateAndSetSLAFields()` | Trigger framework |
| After Trigger | Update related records | `setServiceDate()` | Internal DML |
| Service Class | Complex business logic | `calculateServiceDateWithCapacity()` | Caller responsibility |
| Lightning/Aura | UI interactions | `getRelevantEntitlements()` + calculation methods | Caller responsibility |
| Flow/Process Builder | Declarative automation | `@InvocableMethod setServiceDate()` | Internal DML |
| Batch Apex | Bulk processing | `calculateAndSetSLAFields()` | Batch framework |

### Integration with Other Service Classes

These classes integrate with several other service components:

#### CaseEntitlement Service
```apex
// Sets Case.EntitlementId by calling Entitlement_Utility internally
CaseEntitlement.populateEntitlement(List<Case> cases)
```

#### CaseBusinessRuleService
```apex
// May consult entitlements for business rule evaluation
public static void applyBusinessRules(List<Case> cases) {
    Map<String, Entitlement> entitlements = 
        Entitlement_Utility.getPrioritizedEntitlements(caseIds);
    // Apply rules based on entitlement properties
}
```

#### CaseWorkOrderService
```apex
// Uses SLA dates when creating work orders
public static List<WorkOrder> createWorkOrders(List<Case> cases) {
    for (Case c : cases) {
        WorkOrder wo = new WorkOrder();
        wo.Service_Date__c = c.Service_Date__c; // From SLA calculation
        wo.SLA_Service_Date_Time__c = c.SLA_Service_Date_Time__c;
        // ...
    }
}
```

---

## Usage Examples

### Example 1: Simple Entitlement Lookup

**Scenario:** Find the best entitlement for a new case.

```apex
// Create case
Case newCase = new Case(
    Subject = 'New Service Request',
    Case_Type__c = 'New Service',
    Case_Sub_Type__c = 'Additional Service',
    Client__c = '001xx000000001',
    Location__c = '001xx000000002',
    Service_Date__c = Date.today().addDays(3)
);
insert newCase;

// Get prioritized entitlement
Set<Id> caseIds = new Set<Id>{ newCase.Id };
Map<String, Entitlement> entitlementMap = 
    Entitlement_Utility.getPrioritizedEntitlements(caseIds);

if (entitlementMap.containsKey(newCase.Id)) {
    Entitlement bestEntitlement = entitlementMap.get(newCase.Id);
    System.debug('Best entitlement: ' + bestEntitlement.Name);
    System.debug('Service guarantee: ' + bestEntitlement.Service_Guarantee_Category_Value__c + 
                 ' ' + bestEntitlement.Service_Guarantee_Category__c);
}
```

**Output:**
```
Best entitlement: Gold Standard - Rolloff 2 Day
Service guarantee: 2 Days
```

### Example 2: Calculate SLA for Case

**Scenario:** Calculate and set SLA fields for a case in a trigger.

```apex
// In CaseTriggerHandler.cls (Before Insert)

public void beforeInsert(List<Case> newCases) {
    // Filter to only cases that need SLA calculation
    List<Case> casesNeedingSLA = new List<Case>();
    for (Case c : newCases) {
        if (c.SLA_Service_Date_Time__c == null && c.Location__c != null) {
            casesNeedingSLA.add(c);
        }
    }
    
    if (casesNeedingSLA.isEmpty()) return;
    
    // Build location map
    Set<Id> locationIds = new Set<Id>();
    for (Case c : casesNeedingSLA) {
        locationIds.add(c.Location__c);
    }
    
    Map<Id, Account> locationMap = new Map<Id, Account>(
        [SELECT Id, tz__UTF_Offset__c, tz__Timezone_SFDC__c 
         FROM Account WHERE Id IN :locationIds]
    );
    
    // Calculate SLA (modifies cases in-place, no DML)
    SLACalculationUtility.calculateAndSetSLAFields(casesNeedingSLA, locationMap);
}
```

**Result:** Cases will have these fields populated before insert:
- `Service_Date__c`
- `SLA_Service_Date__c`
- `SLA_Service_Date_Time__c`

### Example 3: Compare Industry vs Customer Entitlements

**Scenario:** Show user both industry standard and customer-specific entitlements.

```apex
@AuraEnabled
public static Map<String, Object> getEntitlementOptions(Id caseId) {
    Map<String, Object> result = new Map<String, Object>();
    
    // Get all relevant entitlements grouped by type
    Map<String, Map<String, List<Entitlement>>> grouped = 
        Entitlement_Utility.getRelevantEntitlements(new Set<Id>{ caseId });
    
    if (grouped.containsKey(caseId)) {
        Map<String, List<Entitlement>> typeMap = grouped.get(caseId);
        
        // Industry Standard entitlements
        if (typeMap.containsKey('Industry Standard')) {
            List<Entitlement> industryStandard = typeMap.get('Industry Standard');
            result.put('industryStandard', industryStandard);
            System.debug('Found ' + industryStandard.size() + ' industry standard entitlements');
        }
        
        // Customer Specific entitlements
        if (typeMap.containsKey('Customer Specific Entitlement')) {
            List<Entitlement> customerSpecific = typeMap.get('Customer Specific Entitlement');
            result.put('customerSpecific', customerSpecific);
            System.debug('Found ' + customerSpecific.size() + ' customer-specific entitlements');
        }
    }
    
    // Get the one that would be automatically selected
    Map<String, Entitlement> prioritized = 
        Entitlement_Utility.getPrioritizedEntitlements(new Set<Id>{ caseId });
    result.put('recommended', prioritized.get(caseId));
    
    return result;
}
```

### Example 4: Capacity Planning Integration

**Scenario:** Calculate service date for a Rolloff case using WM Capacity Planner.

```apex
// Get case and related data
Case pickupCase = [SELECT Id, Client__c, Location__c, AssetId, CreatedDate 
                   FROM Case WHERE Id = :caseId];

Asset serviceHeader = [SELECT Id, ProductFamily, (
                          SELECT Id, SBID_Text_c__c, Supplier__r.Parent_Vendor_ID__c,
                                 Is_Self_Service__c, Quantity__c
                          FROM Assets_Parent__r
                          WHERE Is_Self_Service__c = true
                       ) 
                       FROM Asset WHERE Id = :pickupCase.AssetId];

Account location = [SELECT Id, tz__UTF_Offset__c, tz__Timezone_SFDC__c 
                   FROM Account WHERE Id = :pickupCase.Location__c];

Entitlement ent = [SELECT Id, Name, Gold_Standard__c, Contractual__c,
                          Service_Guarantee_Category__c, Service_Guarantee_Category_Value__c
                   FROM Entitlement WHERE Id = :pickupCase.EntitlementId];

// Calculate with capacity planning
SLACalculationUtility.ServiceDateCalculationResult result = 
    SLACalculationUtility.calculateServiceDateWithCapacity(
        pickupCase,
        serviceHeader,
        ent,
        location
    );

System.debug('Calculation Method: ' + result.calculationMethod);
System.debug('Service Date: ' + result.serviceDate);
System.debug('SLA DateTime: ' + result.slaServiceDateTime);

if (result.calculationMethod.contains('Capacity Planner')) {
    System.debug('Available dates from planner: ' + result.availableDates);
}

// Apply to case
pickupCase.Service_Date__c = result.serviceDate;
pickupCase.SLA_Service_Date_Time__c = result.slaServiceDateTime;
update pickupCase;
```

**Sample Output:**
```
Calculation Method: Capacity Planner
Service Date: 2024-12-26
SLA DateTime: 2024-12-26 21:00:00
Available dates from planner: [12/26/2024, 12/27/2024, 12/30/2024]
```

### Example 5: Handling Missing Entitlements

**Scenario:** Graceful fallback when no entitlement is found.

```apex
public static void processCase(Case c) {
    // Attempt to get entitlement
    Map<String, Entitlement> entitlements = 
        Entitlement_Utility.getPrioritizedEntitlements(new Set<Id>{ c.Id });
    
    if (!entitlements.containsKey(c.Id) || entitlements.get(c.Id) == null) {
        // No entitlement found - apply fallback
        System.debug('No entitlement found for case ' + c.Id + ', using fallback SLA');
        
        // Fallback: Next business day at 11:59 PM
        BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault=true LIMIT 1];
        Date fallbackDate = System.today().addDays(1);
        
        // Ensure business day
        while (!BusinessHours.isWithin(bh.Id, fallbackDate)) {
            fallbackDate = fallbackDate.addDays(1);
        }
        
        c.Service_Date__c = fallbackDate;
        c.SLA_Service_Date__c = fallbackDate;
        c.SLA_Service_Date_Time__c = DateTime.newInstance(
            fallbackDate, 
            Time.newInstance(23, 59, 59, 59)
        );
        
        // Log for tracking
        System.debug('Applied fallback SLA: ' + c.SLA_Service_Date_Time__c);
        
    } else {
        // Normal entitlement-based calculation
        Entitlement ent = entitlements.get(c.Id);
        c.EntitlementId = ent.Id;
        
        Map<Id, Account> locationMap = new Map<Id, Account>{
            c.Location__c => [SELECT Id, tz__UTF_Offset__c, tz__Timezone_SFDC__c 
                             FROM Account WHERE Id = :c.Location__c]
        };
        
        SLACalculationUtility.calculateAndSetSLAFields(
            new List<Case>{ c }, 
            locationMap
        );
    }
    
    update c;
}
```

### Example 6: Industry Standard SLA Lookup

**Scenario:** Get industry standard SLA for a specific case type/subtype/reason.

```apex
Case newCase = new Case(
    Case_Type__c = 'New Service',
    Case_Sub_Type__c = 'Additional Service',
    Case_Reason__c = 'Customer Request'
);

// Get industry standard SLA
List<Entitlement> industryStandard = 
    Entitlement_Utility.getIndustryStandardSLA(newCase);

if (!industryStandard.isEmpty()) {
    Entitlement industrySLA = industryStandard[0];
    System.debug('Industry Standard: ' + industrySLA.Name);
    System.debug('Guarantee: ' + industrySLA.Service_Guarantee_Category_Value__c + 
                 ' ' + industrySLA.Service_Guarantee_Category__c);
} else {
    System.debug('No industry standard SLA found for this case type');
}
```

### Example 7: Bulk Processing

**Scenario:** Process 200 cases in a batch job.

```apex
public class CaseSLABatch implements Database.Batchable<SObject> {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Client__c, Location__c, Case_Type__c, Case_Sub_Type__c,
                   Service_Date__c, SLA_Service_Date_Time__c, CreatedDate, AssetId
            FROM Case
            WHERE SLA_Service_Date_Time__c = null
            AND Location__c != null
            AND CreatedDate = TODAY
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Case> scope) {
        // Get all case IDs
        Set<Id> caseIds = new Map<Id, Case>(scope).keySet();
        
        // Get entitlements for all cases
        Map<String, Entitlement> entitlements = 
            Entitlement_Utility.getPrioritizedEntitlements(caseIds);
        
        // Apply entitlement IDs
        for (Case c : scope) {
            if (entitlements.containsKey(c.Id)) {
                c.EntitlementId = entitlements.get(c.Id).Id;
            }
        }
        
        // Build location map
        Set<Id> locationIds = new Set<Id>();
        for (Case c : scope) {
            if (c.Location__c != null) locationIds.add(c.Location__c);
        }
        
        Map<Id, Account> locationMap = new Map<Id, Account>(
            [SELECT Id, tz__UTF_Offset__c, tz__Timezone_SFDC__c 
             FROM Account WHERE Id IN :locationIds]
        );
        
        // Calculate SLA for all cases
        SLACalculationUtility.calculateAndSetSLAFields(scope, locationMap);
        
        // Update cases
        update scope;
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('Batch completed');
    }
}

// Execute
Database.executeBatch(new CaseSLABatch(), 200);
```

---

## Testing Considerations

### Test Data Setup

Both classes require comprehensive test data:

#### Required Custom Metadata
```apex
@TestSetup
static void setupMetadata() {
    // Note: Custom Metadata Types must be created in the org
    // Cannot be inserted in tests, but can be queried
    
    // Verify Entitlement_Field_Mapping__mdt exists
    List<Entitlement_Field_Mapping__mdt> mappings = 
        [SELECT Id FROM Entitlement_Field_Mapping__mdt LIMIT 1];
    System.assert(!mappings.isEmpty(), 'Field mappings must exist');
}
```

#### Required SObjects
```apex
@TestSetup
static void setupData() {
    // Account with timezone
    Account testAccount = new Account(
        Name = 'Test Customer',
        tz__Timezone_SFDC__c = 'America/Chicago',
        tz__UTF_Offset__c = -6
    );
    insert testAccount;
    
    // Entitlement
    Entitlement testEntitlement = new Entitlement(
        Name = 'Test 2-Day SLA',
        AccountId = testAccount.Id,
        StartDate = Date.today().addDays(-30),
        EndDate = Date.today().addDays(365),
        Status__c = 'Approved',
        Service_Guarantee_Category__c = 'Days',
        Service_Guarantee_Category_Value__c = '2',
        Call_Time__c = '14:00',
        Before_After__c = 'Before',
        Call_On__c = 'Mon,Tue,Wed,Thu,Fri'
    );
    insert testEntitlement;
    
    // Asset
    Product2 testProduct = new Product2(
        Name = 'Test Product',
        ProductFamily = 'Rolloff'
    );
    insert testProduct;
    
    Asset testAsset = new Asset(
        Name = 'Test Asset',
        Product2Id = testProduct.Id,
        AccountId = testAccount.Id
    );
    insert testAsset;
    
    // Business Hours
    // Note: BusinessHours must already exist in org (IsDefault = true)
}
```

### Testing Entitlement_Utility

```apex
@IsTest
private class Entitlement_Utility_Test {
    
    @IsTest
    static void testGetPrioritizedEntitlements() {
        // Setup
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Case testCase = new Case(
            Subject = 'Test Case',
            Client__c = acc.Id,
            Location__c = acc.Id,
            Case_Type__c = 'New Service',
            Service_Date__c = Date.today().addDays(3)
        );
        insert testCase;
        
        // Test
        Test.startTest();
        Map<String, Entitlement> result = 
            Entitlement_Utility.getPrioritizedEntitlements(new Set<Id>{ testCase.Id });
        Test.stopTest();
        
        // Assert
        System.assert(result.containsKey(testCase.Id), 'Should return entitlement for case');
        Entitlement ent = result.get(testCase.Id);
        System.assertNotEquals(null, ent, 'Entitlement should not be null');
        System.assertEquals('Approved', ent.Status__c, 'Should be approved');
    }
    
    @IsTest
    static void testGetRelevantEntitlements() {
        // Setup
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Case testCase = new Case(
            Subject = 'Test Case',
            Client__c = acc.Id,
            Location__c = acc.Id,
            Case_Type__c = 'New Service',
            Service_Date__c = Date.today().addDays(3)
        );
        insert testCase;
        
        // Test
        Test.startTest();
        Map<String, Map<String, List<Entitlement>>> result = 
            Entitlement_Utility.getRelevantEntitlements(new Set<Id>{ testCase.Id });
        Test.stopTest();
        
        // Assert
        System.assert(result.containsKey(testCase.Id), 'Should return entitlements for case');
        Map<String, List<Entitlement>> typeMap = result.get(testCase.Id);
        
        // Should have either Industry Standard or Customer Specific
        Boolean hasIndustry = typeMap.containsKey('Industry Standard');
        Boolean hasCustomer = typeMap.containsKey('Customer Specific Entitlement');
        System.assert(hasIndustry || hasCustomer, 'Should have at least one entitlement type');
    }
    
    @IsTest
    static void testTimeBasedFiltering() {
        // Setup case
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Case testCase = new Case(
            Subject = 'Test Time Filtering',
            Client__c = acc.Id,
            Location__c = acc.Id,
            Case_Type__c = 'New Service',
            Service_Date__c = Date.today().addDays(3)
        );
        insert testCase;
        
        // Create entitlements with different time windows
        Entitlement beforeNoon = new Entitlement(
            Name = 'Before Noon',
            AccountId = acc.Id,
            StartDate = Date.today().addDays(-30),
            EndDate = Date.today().addDays(365),
            Status__c = 'Approved',
            Call_Time__c = '12:00',
            Before_After__c = 'Before'
        );
        
        Entitlement afterNoon = new Entitlement(
            Name = 'After Noon',
            AccountId = acc.Id,
            StartDate = Date.today().addDays(-30),
            EndDate = Date.today().addDays(365),
            Status__c = 'Approved',
            Call_Time__c = '12:00',
            Before_After__c = 'After'
        );
        
        insert new List<Entitlement>{ beforeNoon, afterNoon };
        
        // Test
        Test.startTest();
        Map<String, Entitlement> result = 
            Entitlement_Utility.getPrioritizedEntitlements(new Set<Id>{ testCase.Id });
        Test.stopTest();
        
        // Assert - one should be filtered out based on current time
        System.assertNotEquals(null, result.get(testCase.Id), 'Should return an entitlement');
    }
}
```

### Testing SLACalculationUtility

```apex
@IsTest
private class SLACalculationUtility_Test {
    
    @IsTest
    static void testSetServiceDate() {
        // Setup
        Account acc = [SELECT Id, tz__Timezone_SFDC__c, tz__UTF_Offset__c FROM Account LIMIT 1];
        Entitlement ent = [SELECT Id FROM Entitlement LIMIT 1];
        
        Case testCase = new Case(
            Subject = 'Test SLA',
            Client__c = acc.Id,
            Location__c = acc.Id,
            EntitlementId = ent.Id,
            Case_Type__c = 'New Service',
            Service_Date__c = Date.today().addDays(3)
        );
        insert testCase;
        
        // Clear SLA fields
        testCase.SLA_Service_Date_Time__c = null;
        update testCase;
        
        // Test
        Test.startTest();
        SLACalculationUtility.setServiceDate(new List<Case>{ testCase });
        Test.stopTest();
        
        // Assert
        Case updated = [SELECT Service_Date__c, SLA_Service_Date__c, SLA_Service_Date_Time__c 
                        FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, updated.Service_Date__c, 'Service Date should be set');
        System.assertNotEquals(null, updated.SLA_Service_Date_Time__c, 'SLA DateTime should be set');
    }
    
    @IsTest
    static void testCalculateAndSetSLAFields() {
        // Setup
        Account acc = [SELECT Id, tz__Timezone_SFDC__c, tz__UTF_Offset__c FROM Account LIMIT 1];
        Entitlement ent = [SELECT Id FROM Entitlement LIMIT 1];
        
        Case testCase = new Case(
            Subject = 'Test Trigger-Safe',
            Client__c = acc.Id,
            Location__c = acc.Id,
            EntitlementId = ent.Id,
            Case_Type__c = 'New Service'
        );
        // Don't insert - simulating before trigger
        
        Map<Id, Account> locationMap = new Map<Id, Account>{ acc.Id => acc };
        
        // Test
        Test.startTest();
        SLACalculationUtility.calculateAndSetSLAFields(new List<Case>{ testCase }, locationMap);
        Test.stopTest();
        
        // Assert - fields set but not saved
        System.assertNotEquals(null, testCase.Service_Date__c, 'Service Date should be set');
        System.assertNotEquals(null, testCase.SLA_Service_Date_Time__c, 'SLA DateTime should be set');
    }
    
    @IsTest
    static void testGetDaysDelta() {
        Entitlement daysBased = new Entitlement(
            Service_Guarantee_Category__c = 'Days',
            Service_Guarantee_Category_Value__c = '3'
        );
        
        Entitlement hoursBased = new Entitlement(
            Service_Guarantee_Category__c = 'Hours',
            Service_Guarantee_Category_Value__c = '48'
        );
        
        Test.startTest();
        Integer daysResult = SLACalculationUtility.getDaysDelta(daysBased);
        Integer hoursResult = SLACalculationUtility.getDaysDelta(hoursBased);
        Test.stopTest();
        
        System.assertEquals(3, daysResult, 'Should return 3 days');
        System.assertEquals(2, hoursResult, '48 hours should convert to 2 days');
    }
    
    @IsTest
    static void testCapacityPlannerIntegration() {
        // Setup mock for HTTP callout
        Test.setMock(HttpCalloutMock.class, new WMCapacityPlannerMock());
        
        Account acc = [SELECT Id, tz__Timezone_SFDC__c, tz__UTF_Offset__c FROM Account LIMIT 1];
        Asset ast = [SELECT Id, ProductFamily FROM Asset LIMIT 1];
        Entitlement ent = [SELECT Id FROM Entitlement LIMIT 1];
        
        Case testCase = new Case(
            Subject = 'Test Capacity',
            Client__c = acc.Id,
            Location__c = acc.Id,
            AssetId = ast.Id,
            EntitlementId = ent.Id
        );
        insert testCase;
        
        // Test
        Test.startTest();
        SLACalculationUtility.ServiceDateCalculationResult result = 
            SLACalculationUtility.calculateServiceDateWithCapacity(
                testCase, ast, ent, acc
            );
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, result, 'Should return result');
        System.assertNotEquals(null, result.serviceDate, 'Should calculate service date');
        System.assertNotEquals(null, result.calculationMethod, 'Should indicate method used');
    }
    
    @IsTest
    static void testFallbackLogic() {
        // Setup case with no entitlement
        Account acc = [SELECT Id, tz__Timezone_SFDC__c, tz__UTF_Offset__c FROM Account LIMIT 1];
        
        Case testCase = new Case(
            Subject = 'Test Fallback',
            Client__c = acc.Id,
            Location__c = acc.Id,
            Case_Type__c = 'New Service'
        );
        insert testCase;
        
        // Test
        Test.startTest();
        try {
            SLACalculationUtility.setServiceDate(new List<Case>{ testCase });
        } catch (Exception e) {
            // Should not throw exception - fallback should apply
            System.assert(false, 'Should not throw exception: ' + e.getMessage());
        }
        Test.stopTest();
        
        // Assert - should have fallback SLA
        Case updated = [SELECT Service_Date__c, SLA_Service_Date_Time__c 
                        FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, updated.Service_Date__c, 'Should have fallback date');
    }
}

// Mock for HTTP callouts
@IsTest
global class WMCapacityPlannerMock implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"Data":{"Site":{"Capacity":[{"AvailableDates":["2024/12/25","2024/12/26"]}]}}}');
        res.setStatusCode(200);
        return res;
    }
}
```

### Key Testing Scenarios

| Scenario | Classes Tested | Expected Outcome |
|----------|---------------|------------------|
| Happy path with customer entitlement | Both | Correct entitlement selected, SLA calculated |
| No customer entitlement found | Both | Industry standard used, SLA calculated |
| No entitlement at all | SLACalculationUtility | Fallback SLA applied (next business day) |
| After-hours case creation | Both | Extra day added to SLA |
| Weekend service date | SLACalculationUtility | Date adjusted to next business day |
| Capacity planner available dates | SLACalculationUtility | Date selected from planner response |
| Capacity planner failure | SLACalculationUtility | Falls back to entitlement calculation |
| Multiple cases bulk processing | Both | All cases processed correctly |
| Time zone conversion | SLACalculationUtility | Cutoff times evaluated in local time |

---

## Best Practices

### For Developers

#### 1. Always Pass Required Parameters
```apex
// ❌ BAD: Relies on deprecated static variables
Entitlement_Utility.accountIdSet = accountIds;
Entitlement_Utility.minimumServiceDate = minDate;

// ✅ GOOD: Uses parameter-based methods
Map<String, Entitlement> result = 
    Entitlement_Utility.getPrioritizedEntitlements(caseIds);
```

#### 2. Choose the Right Method for Context
```apex
// In Before Trigger (no DML)
SLACalculationUtility.calculateAndSetSLAFields(newCases, locationMap);

// In Service Class (handle DML yourself)
SLACalculationUtility.ServiceDateCalculationResult result = 
    SLACalculationUtility.calculateServiceDateWithCapacity(c, asset, ent, loc);

// In Flow (auto-DML)
// Use @InvocableMethod: setServiceDate
```

#### 3. Handle Null Entitlements Gracefully
```apex
Map<String, Entitlement> entitlements = 
    Entitlement_Utility.getPrioritizedEntitlements(caseIds);

for (Case c : cases) {
    if (entitlements.containsKey(c.Id) && entitlements.get(c.Id) != null) {
        c.EntitlementId = entitlements.get(c.Id).Id;
    } else {
        // Log warning and apply fallback
        System.debug(LoggingLevel.WARN, 'No entitlement found for case: ' + c.Id);
        // Fallback logic here
    }
}
```

#### 4. Bulkify Operations
```apex
// ✅ GOOD: Single call for all cases
Set<Id> allCaseIds = new Map<Id, Case>(caseList).keySet();
Map<String, Entitlement> entitlements = 
    Entitlement_Utility.getPrioritizedEntitlements(allCaseIds);

// ❌ BAD: Individual calls in loop
for (Case c : caseList) {
    Map<String, Entitlement> ent = 
        Entitlement_Utility.getPrioritizedEntitlements(new Set<Id>{ c.Id });
}
```

#### 5. Build Location Maps Efficiently
```apex
// Collect location IDs first
Set<Id> locationIds = new Set<Id>();
for (Case c : cases) {
    if (c.Location__c != null) locationIds.add(c.Location__c);
}

// Single query for all locations
Map<Id, Account> locationMap = new Map<Id, Account>(
    [SELECT Id, tz__UTF_Offset__c, tz__Timezone_SFDC__c 
     FROM Account WHERE Id IN :locationIds]
);

// Use the map
SLACalculationUtility.calculateAndSetSLAFields(cases, locationMap);
```

### For Architects

#### 1. Maintain Separation of Concerns

These classes should remain **service layer** components:
- **Do**: Perform calculations, apply business logic, return results
- **Don't**: Perform DML operations (except in @InvocableMethod), make UI decisions

#### 2. Configuration Over Code

Use Custom Metadata Types to configure behavior:
- `Entitlement_Field_Mapping__mdt`: Controls which fields are compared
- `Industry_Standard_SLA__mdt`: Defines fallback SLAs

This allows changes without code deployment.

#### 3. Integration Points

When integrating with external systems:
```apex
// Use Try-Catch and fallback logic
try {
    List<String> dates = SLACalculationUtility.callWMCapacityPlannerAPI(sbid);
    if (dates == null || dates.isEmpty()) {
        // Fallback to entitlement calculation
    }
} catch (Exception ex) {
    // Log error and use fallback
    UTIL_LoggingService.logHandledException(ex, ...);
    // Fallback logic
}
```

#### 4. Governor Limit Considerations

These classes are designed for bulk operations:
- Query all required data upfront
- Use collections (Maps, Sets) for efficient lookups
- Avoid SOQL in loops
- Current limits: ~100 cases per transaction is safe

#### 5. Extension Points

To extend functionality:

**Add New Entitlement Criteria:**
1. Add field to Entitlement object
2. Create Entitlement_Field_Mapping__mdt record
3. No code changes required!

**Add New SLA Calculation Rule:**
1. Create new method in SLACalculationUtility
2. Call from appropriate context
3. Follow existing patterns

### For Administrators

#### 1. Metadata Configuration

**Key Records to Maintain:**
- Entitlement_Field_Mapping__mdt: Field comparison rules
- Industry_Standard_SLA__mdt: Default SLA values
- Integration_Request_URLs__mdt: API endpoints

#### 2. Monitoring

**Debug Logs to Enable:**
- `Entitlement_Utility`: DEBUG level
- `SLACalculationUtility`: DEBUG level
- Look for keywords: "SKIPPED", "ADDED ENTITLEMENT", "Priority Rank"

**Key Metrics:**
```
System.debug('Selected Entitlement: ' + entitlement.Name + 
             ' with Priority Rank: ' + pr.priorityRank);
```

#### 3. Data Quality

Ensure clean data:
- All Cases have `Location__c` populated
- Accounts have timezone fields populated
- Entitlements are approved and have valid date ranges
- Business Hours is configured correctly

---

## Appendix: Field Reference

### Case Fields Used

| Field API Name | Purpose | Set By |
|---------------|---------|--------|
| EntitlementId | Links case to entitlement | Entitlement_Utility |
| Service_Date__c | Target service date | SLACalculationUtility |
| SLA_Service_Date__c | SLA target date | SLACalculationUtility |
| SLA_Service_Date_Time__c | Precise SLA timestamp | SLACalculationUtility |
| Client__c | Customer account | User |
| Location__c | Service location | User |
| Case_Type__c | Request type | User |
| Case_Sub_Type__c | Service type | User |
| Case_Reason__c | Reason for case | User |
| AssetId | Related asset | User |

### Entitlement Fields Used

| Field API Name | Purpose | Read By |
|---------------|---------|---------|
| AccountId | Customer or null for industry | Both |
| StartDate | Entitlement start date | Entitlement_Utility |
| EndDate | Entitlement end date | Entitlement_Utility |
| Status__c | Must be "Approved" | Entitlement_Utility |
| Service_Guarantee_Category__c | "Days" or "Hours" | SLACalculationUtility |
| Service_Guarantee_Category_Value__c | Numeric value | SLACalculationUtility |
| Call_Time__c | Cutoff time (e.g., "14:00") | Both |
| Before_After__c | "Before" or "After" cutoff | Both |
| Call_On__c | Days of week (e.g., "Mon,Tue,Wed") | Entitlement_Utility |
| Override_Business_Hours__c | Skip business day check | SLACalculationUtility |
| Gold_Standard__c | Priority flag | SLACalculationUtility |
| Contractual__c | Priority flag | SLACalculationUtility |

### Account Fields Used

| Field API Name | Purpose | Read By |
|---------------|---------|---------|
| tz__Timezone_SFDC__c | Salesforce timezone string | SLACalculationUtility |
| tz__UTF_Offset__c | UTC offset hours | SLACalculationUtility |

---

## Summary

The Entitlement and SLA Service Layer provides a robust, configurable system for managing customer service level agreements. By separating entitlement selection from SLA calculation, the architecture enables:

- **Flexibility**: Easy to add new entitlement criteria via metadata
- **Reliability**: Comprehensive fallback logic ensures SLAs are always set
- **Scalability**: Designed for bulk operations and high-volume processing
- **Maintainability**: Clear separation of concerns and reusable components

These classes serve as the foundation for case management SLA compliance across the organization.

---

## Related Documentation

- [Case Trigger Handler Architecture](./CaseTriggerHandler_Architecture.md)
- [Service Layer Design Patterns](./Service_Layer_Patterns.md)
- [Custom Metadata Configuration Guide](./Metadata_Configuration.md)
- [API Integration Patterns](./API_Integration_Guide.md)

---

**Document Version:** 1.0  
**Last Updated:** November 2024  
**Author:** Technical Architecture Team