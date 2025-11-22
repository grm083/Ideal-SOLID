# SLACalculationUtility and Entitlement_Utility: Comprehensive Technical Specification

## Document Control

| Property | Value |
|----------|-------|
| Document Version | 1.0 |
| Last Updated | 2025-11-22 |
| Author | Development Team |
| Status | Active |
| Classification | Internal - Developer Reference |

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [SLACalculationUtility - Technical Deep Dive](#slacalculationutility---technical-deep-dive)
4. [Entitlement_Utility - Technical Deep Dive](#entitlement_utility---technical-deep-dive)
5. [Class Interplay and Integration Patterns](#class-interplay-and-integration-patterns)
6. [Data Model Dependencies](#data-model-dependencies)
7. [Algorithm Specifications](#algorithm-specifications)
8. [Error Handling and Edge Cases](#error-handling-and-edge-cases)
9. [Performance Characteristics](#performance-characteristics)
10. [Testing Strategy](#testing-strategy)
11. [Deployment and Configuration](#deployment-and-configuration)
12. [Troubleshooting Reference](#troubleshooting-reference)

---

## Executive Summary

### Purpose

This document provides a comprehensive technical specification for two core service layer classes responsible for entitlement resolution and SLA (Service Level Agreement) date calculation in the Salesforce implementation:

- **`Entitlement_Utility`**: Resolves which entitlement applies to Cases and Quotes using a sophisticated multi-tier prioritization algorithm
- **`SLACalculationUtility`**: Calculates service commitment dates and SLA timestamps based on resolved entitlements, business hours, timezones, and external capacity planning systems

### Business Context

These classes ensure that customer service commitments are:
- **Accurately determined** based on contractual agreements and service tiers
- **Properly prioritized** when multiple entitlements could apply
- **Correctly timed** accounting for business hours, timezones, and operational capacity
- **Automatically maintained** throughout the case/quote lifecycle

### Key Capabilities

| Capability | Class | Description |
|-----------|-------|-------------|
| Entitlement Resolution | Entitlement_Utility | Matches customer records to entitlements using metadata-driven field mappings |
| Multi-tier Prioritization | Entitlement_Utility | Ranks entitlements by Customer/Service/Transaction specificity |
| SLA Date Calculation | SLACalculationUtility | Computes service dates from entitlement SLA values |
| Timezone Management | SLACalculationUtility | Converts times to location-specific timezones |
| Business Hours Integration | SLACalculationUtility | Ensures dates fall on valid business days |
| Capacity Planning Integration | SLACalculationUtility | Interfaces with WM Capacity Planner API for rolloff services |
| Fallback Logic | Both | Provides industry standard defaults when specific entitlements unavailable |

---

## Architecture Overview

### Service Layer Pattern

Both classes implement the **Service Layer** architectural pattern, providing:

- **Reusability**: Business logic can be invoked from triggers, Lightning components, flows, and batch jobs
- **Testability**: Logic is isolated from UI and data access layers
- **Maintainability**: Changes to business rules centralized in one location
- **Bulkification**: All methods designed to process collections, not single records

### Design Principles

**SLACalculationUtility Design**:
- **Separation of DML**: Two versions of methods - one with DML (invocable), one without (trigger-safe)
- **Strategy Pattern**: Multiple calculation strategies (entitlement-based, capacity planner, industry standard)
- **Timezone Abstraction**: Centralized timezone conversion logic
- **Failsafe Defaults**: Always produces a valid date, even if errors occur

**Entitlement_Utility Design**:
- **Metadata-Driven**: Field mappings configurable via custom metadata
- **Composite Prioritization**: Multi-dimensional ranking algorithm
- **Stateless Operation**: No static variables (refactored for thread safety)
- **Polymorphic Input**: Handles both Cases and Quotes through common interface

### System Context Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         External Systems                                │
│  ┌──────────────────────┐         ┌────────────────────────────┐      │
│  │ WM Capacity Planner  │         │ Industry Standard SLA      │      │
│  │      (HTTP API)      │         │    (Custom Metadata)       │      │
│  └──────────────────────┘         └────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
                  ▲                                ▲
                  │                                │
                  │ HTTP Callout                   │ Metadata Query
                  │                                │
┌─────────────────┴────────────────────────────────┴─────────────────────┐
│                      Service Layer (Apex)                               │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │              SLACalculationUtility                          │       │
│  │  • setServiceDate() - Invocable with DML                   │       │
│  │  • calculateAndSetSLAFields() - Trigger-safe, no DML       │       │
│  │  • calculateServiceDateWithCapacity() - Strategy orchestr. │       │
│  │  • callWMCapacityPlannerAPI() - External integration       │       │
│  │  • getDaysDelta(), isBeforeCutoff() - Helper methods       │       │
│  └─────────────────────────────────────────────────────────────┘       │
│                            ▲                                            │
│                            │ Uses EntitlementId from                    │
│                            │                                            │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │              Entitlement_Utility                            │       │
│  │  • getPrioritizedEntitlements() - Returns single best       │       │
│  │  • getRelevantEntitlements() - Returns all valid            │       │
│  │  • prioritizeEntitlements() - Ranking algorithm             │       │
│  │  • filterEntitlementsByTime() - Day/time filtering          │       │
│  └─────────────────────────────────────────────────────────────┘       │
│                            ▲                                            │
└────────────────────────────┼────────────────────────────────────────────┘
                             │ Reads field mappings from
                             │
┌────────────────────────────┴────────────────────────────────────────────┐
│                    Configuration Layer                                  │
│  • Entitlement_Field_Mapping__mdt (Custom Metadata)                    │
│  • Integration_Request_URLs__mdt (API configuration)                   │
│  • BusinessHours (Standard Salesforce object)                          │
└─────────────────────────────────────────────────────────────────────────┘
                             ▲
                             │ Triggered by
                             │
┌────────────────────────────┴────────────────────────────────────────────┐
│                      Data & Automation Layer                            │
│  • Case Triggers (before/after insert/update)                          │
│  • Quote Triggers (before/after insert/update)                         │
│  • Process Builder / Flow                                              │
│  • Lightning Web Components                                            │
│  • Batch Jobs                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## SLACalculationUtility - Technical Deep Dive

### Class Structure

```apex
public class SLACalculationUtility {
    // Exception Classes
    public class NoEntitlementException extends Exception {}

    // Result Wrapper Classes
    public class ServiceDateCalculationResult { ... }
    public class CapacityResponse { ... }
    public class CapacitySiteData { ... }
    public class CapacitySite { ... }
    public class CapacityData { ... }

    // Public Methods (see details below)
    // Helper Methods (see details below)
}
```

### Method Catalog

#### 1. setServiceDate(List&lt;Case&gt; caseList)

**Signature**:
```apex
@InvocableMethod(label='Set Service Date')
public static void setServiceDate(List<Case> caseList)
```

**Purpose**: Primary entry point for Flow/Process Builder. Calculates SLA dates and performs DML update.

**Algorithm**:
1. Query default BusinessHours
2. Build Case-to-Location map with timezone data
3. Call `CaseEntitlement.populateEntitlement()` to set EntitlementId on all cases
4. Collect all EntitlementIds from cases
5. Query Entitlement records with SLA configuration fields
6. For each case:
   - If `SLA_Service_Date_Time__c` is null:
     - Validate EntitlementId exists (throw NoEntitlementException if null)
     - Calculate days delta from entitlement
     - Check if before cutoff time
     - Add delta to CreatedDate
     - Adjust for business hours (unless Override_Business_Hours__c = true)
     - Set Service_Date__c and SLA_Service_Date_Time__c
   - Catch exceptions and apply fallback logic
7. Perform single bulk DML update

**Error Handling**:
- If EntitlementId is null → Throws NoEntitlementException, caught by fallback
- If Entitlement not found in map → Throws NoEntitlementException
- If any exception → Sets date to tomorrow at 11:59 PM, adjusted for business hours

**DML Operations**: 1 (bulk update at end)

**SOQL Queries**: 3
1. BusinessHours default
2. Accounts for locations (tz__UTF_Offset__c)
3. Entitlements

**Code Sample**:
```apex
// Usage from Flow or Apex
List<Case> casesToProcess = [SELECT Id, CreatedDate, Location__c, EntitlementId
                              FROM Case WHERE Id IN :caseIds];
SLACalculationUtility.setServiceDate(casesToProcess);
```

---

#### 2. calculateAndSetSLAFields(List&lt;Case&gt; caseList, Map&lt;Id, Account&gt; caseLocationMap)

**Signature**:
```apex
public static void calculateAndSetSLAFields(
    List<Case> caseList,
    Map<Id, Account> caseLocationMap
)
```

**Purpose**: Trigger-safe version that calculates SLA fields WITHOUT performing DML. Designed for BEFORE trigger contexts.

**Algorithm**: Identical to `setServiceDate()` except:
- Does NOT perform DML update at end
- Accepts pre-built location map as parameter (optional, will build if null)
- Modifies Case records in-place
- Trigger framework handles the insert/update

**Key Differences from setServiceDate()**:

| Aspect | setServiceDate() | calculateAndSetSLAFields() |
|--------|------------------|----------------------------|
| DML Operation | YES (performs update) | NO (trigger handles DML) |
| Location Map | Builds internally | Accepts as parameter |
| Use Context | Flow, Process Builder, After Trigger | Before Trigger |
| Invocable | Yes (@InvocableMethod) | No |

**Code Sample**:
```apex
// Usage from BEFORE trigger
trigger CaseTrigger on Case (before insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        // Build location map once for all cases
        Map<Id, Account> locationMap = buildLocationMapHelper(Trigger.new);

        // Calculate SLA fields (no DML)
        SLACalculationUtility.calculateAndSetSLAFields(Trigger.new, locationMap);

        // Trigger framework performs insert with SLA fields populated
    }
}
```

---

#### 3. calculateServiceDateWithCapacity(Case, Asset, Entitlement, Account)

**Signature**:
```apex
public static ServiceDateCalculationResult calculateServiceDateWithCapacity(
    Case caseRecord,
    Asset asset,
    Entitlement entitlement,
    Account location
)
```

**Purpose**: Orchestrates service date calculation using multiple strategies. Returns detailed result wrapper.

**Decision Tree**:
```
START
  │
  ├─ Is Entitlement Gold Standard? ─YES→ Use Entitlement Calculation
  ├─ Is Entitlement Contractual? ─YES→ Use Entitlement Calculation
  ├─ Is Product Family = Commercial? ─YES→ Use Entitlement Calculation
  │
  ├─ Is Product Family = Rolloff? ─NO→ Use Entitlement Calculation (fallback)
  │                                ─YES→
  │                                   │
  │                                   ├─ Is Vendor = WM (Parent_Vendor_ID__c = '8')? ─NO→ Fallback
  │                                   │                                               ─YES→
  │                                   │                                                  │
  │                                   ├─ Does SBID exist? ─NO→ Fallback
  │                                   │                    ─YES→
  │                                   │                       │
  │                                   ├─ Call WM Capacity Planner API
  │                                   │      │
  │                                   │      ├─ Success with dates? ─YES→ Use Capacity Planner dates
  │                                   │      │                        ─NO→ Fallback to Entitlement
  │                                   │      │
  │                                   │      └─ API Failure/Timeout? ─YES→ Fallback to Entitlement
  │
  └─ Return ServiceDateCalculationResult
```

**Result Wrapper Fields**:
```apex
public class ServiceDateCalculationResult {
    public Date serviceDate;                   // Calculated Service_Date__c
    public DateTime slaServiceDateTime;         // Calculated SLA_Service_Date_Time__c
    public String calculationMethod;            // Which method was used
    public List<String> availableDates;         // From capacity planner (if used)
    public String errorMessage;                 // Any errors encountered
}
```

**Calculation Method Values**:
- `'Entitlement'` - Entitlement-based calculation used
- `'Capacity Planner'` - WM Capacity Planner API used
- `'Fallback - Entitlement'` - Capacity Planner failed, fell back to entitlement
- `'Fallback - No SBID'` - No SBID found, used entitlement
- `'Default - Entitlement'` - Default path
- `'Error - Fallback'` - Exception occurred, emergency fallback applied

**Code Sample**:
```apex
// Usage for detailed result inspection
ServiceDateCalculationResult result = SLACalculationUtility.calculateServiceDateWithCapacity(
    caseRecord,
    serviceHeaderAsset,
    selectedEntitlement,
    locationAccount
);

System.debug('Calculation method: ' + result.calculationMethod);
if (result.availableDates != null && !result.availableDates.isEmpty()) {
    System.debug('Available capacity dates: ' + result.availableDates);
}

// Apply results to case
caseRecord.Service_Date__c = result.serviceDate;
caseRecord.SLA_Service_Date_Time__c = result.slaServiceDateTime;
```

---

#### 4. callWMCapacityPlannerAPI(String sbid)

**Signature**:
```apex
public static List<String> callWMCapacityPlannerAPI(String sbid)
```

**Purpose**: Makes HTTP callout to WM Capacity Planner to retrieve available service dates.

**HTTP Request Details**:
```
Method: GET (from metadata)
Endpoint: {End_Point__c}/api/servicelines/{ServiceBaselineId}/capacity?serviceDate={YYYY-MM-DD}
Headers:
  - Content-Type: application/json
  - X-USERID: 1
  - X-PARTNER-KEY: {Client_Key__c from metadata}
  - Authorization: {Client_Token__c from metadata}
Timeout: {Timeout__c from metadata} milliseconds
```

**Response Structure**:
```json
{
  "Data": {
    "Site": {
      "Name": "Site Name",
      "Capacity": [
        {
          "LineOfBusiness": "Residential",
          "Status": "Available",
          "AvailableDates": [
            "2024/12/15",
            "2024/12/16",
            "2024/12/17"
          ]
        }
      ]
    }
  },
  "Problem": null
}
```

**Date Transformation**:
- Input format: `YYYY/MM/DD` (from API)
- Output format: `MM/DD/YYYY` (string list)

**Configuration**:
Uses `Integration_Request_URLs__mdt` record where `DeveloperName = 'Site_Capacity'`

**Error Handling**:
- Logs exceptions via `UTIL_LoggingService.logHandledException()`
- Returns empty list on failure (not null)
- Calling method checks for empty list and applies fallback

**Code Sample**:
```apex
String sbid = 'SB123456';
List<String> availableDates = SLACalculationUtility.callWMCapacityPlannerAPI(sbid);

if (availableDates.isEmpty()) {
    System.debug('No available dates from Capacity Planner, using entitlement calculation');
} else {
    System.debug('Available dates: ' + availableDates);
    // Parse dates and select optimal date
}
```

---

#### 5. buildCaseLocationMap(List&lt;Case&gt; caseList)

**Signature**:
```apex
public static Map<Case, Account> buildCaseLocationMap(List<Case> caseList)
```

**Purpose**: Constructs a map of Case records to their Location Account records with timezone information.

**Algorithm**:
1. Extract Location__c IDs from all cases
2. Query Accounts: `SELECT Id, tz__UTF_Offset__c FROM Account WHERE Id IN :caseLocationSet`
3. Build map pairing each Case with its Location Account
4. Return map

**Refactoring Note**:
Previously wrote to static variable `CaseTriggerHelper.casewithLocation`. Now returns map directly for better encapsulation and testability.

**Code Sample**:
```apex
List<Case> cases = [SELECT Id, Location__c FROM Case WHERE Id IN :caseIds];
Map<Case, Account> caseLocationMap = SLACalculationUtility.buildCaseLocationMap(cases);

for (Case c : caseLocationMap.keySet()) {
    Account location = caseLocationMap.get(c);
    System.debug('Case ' + c.Id + ' location UTC offset: ' + location.tz__UTF_Offset__c);
}
```

---

#### 6. getDaysDelta(Entitlement e)

**Signature**:
```apex
public static Integer getDaysDelta(Entitlement e)
```

**Purpose**: Converts entitlement SLA configuration to days delta for date calculation.

**Logic**:
```apex
if (e.Service_Guarantee_Category__c == 'Days') {
    // Direct conversion
    return Integer.valueOf(e.Service_Guarantee_Category_Value__c);
} else {
    // Assume 'Hours', convert to days (floor division)
    Integer hours = Integer.valueOf(e.Service_Guarantee_Category_Value__c);
    return Integer.valueOf(Math.floor(hours / 24));
}
```

**Examples**:

| Category | Value | Result | Explanation |
|----------|-------|--------|-------------|
| Days | 1 | 1 | Same Day delivery |
| Days | 2 | 2 | Next Day delivery |
| Days | 5 | 5 | 5 business days |
| Hours | 24 | 1 | 24 hours = 1 day |
| Hours | 48 | 2 | 48 hours = 2 days |
| Hours | 72 | 3 | 72 hours = 3 days |
| Hours | 30 | 1 | 30 hours = 1.25 days, floored to 1 |

**Code Sample**:
```apex
Entitlement ent = [SELECT Service_Guarantee_Category__c,
                           Service_Guarantee_Category_Value__c
                    FROM Entitlement WHERE Id = :entId];

Integer daysDelta = SLACalculationUtility.getDaysDelta(ent);
DateTime slaDate = caseRecord.CreatedDate.addDays(daysDelta);
```

---

#### 7. isBeforeCutoff(Case c, Account a, Integer cutoffHour)

**Signature**:
```apex
public static Boolean isBeforeCutoff(Case c, Account a, Integer cutoffHour)
```

**Purpose**: Determines if case was created before daily cutoff time in location's local timezone.

**Algorithm**:
1. Call `getLocalTime(a)` to get current time in location's timezone
2. Extract hour from local time
3. Compare: `localTime.hour() < cutoffHour`
4. Return boolean result

**Usage Pattern**:
```apex
Boolean beforeCutoff = isBeforeCutoff(c, acc, 14);  // 14 = 2 PM

if (!beforeCutoff) {
    daysDelta += 1;  // Created after cutoff, add 1 day
}
```

**Common Cutoff Hours**:
- `14` (2 PM) - Standard afternoon cutoff
- `10` (10 AM) - Morning cutoff
- `12` (12 PM) - Noon cutoff

**Code Sample**:
```apex
// Check if case created before 2 PM local time
Account locationAccount = [SELECT Id, tz__UTF_Offset__c
                           FROM Account WHERE Id = :caseRecord.Location__c];

Boolean beforeCutoff = SLACalculationUtility.isBeforeCutoff(
    caseRecord,
    locationAccount,
    14  // 2 PM cutoff
);

if (beforeCutoff) {
    System.debug('Case created before 2 PM, eligible for same-day service');
} else {
    System.debug('Case created after 2 PM, service date pushed to next day');
}
```

---

#### 8. getLocalTime(Account a)

**Signature**:
```apex
public static DateTime getLocalTime(Account a)
```

**Purpose**: Converts current UTC DateTime to location's local timezone.

**Algorithm**:
```apex
DateTime now = DateTime.now();
Decimal utcOffsetHours = a.tz__UTF_Offset__c;  // e.g., -5.0 for EST
DateTime localTime = now.addHours(Integer.valueOf(utcOffsetHours));
return localTime;
```

**Timezone Offset Examples**:

| Timezone | UTC Offset | Example Account Field Value |
|----------|-----------|------------------------------|
| EST (Eastern Standard Time) | -5 | -5.0 |
| EDT (Eastern Daylight Time) | -4 | -4.0 |
| CST (Central Standard Time) | -6 | -6.0 |
| MST (Mountain Standard Time) | -7 | -7.0 |
| PST (Pacific Standard Time) | -8 | -8.0 |
| UTC | 0 | 0.0 |

**Code Sample**:
```apex
Account location = [SELECT Id, tz__UTF_Offset__c FROM Account WHERE Id = :locationId];
DateTime localTime = SLACalculationUtility.getLocalTime(location);

System.debug('UTC time: ' + DateTime.now());
System.debug('Local time: ' + localTime);
System.debug('Local hour: ' + localTime.hour());
```

---

#### 9. requiresSLAandServiceDateReset(Case newCase, Case oldCase)

**Signature**:
```apex
public static Boolean requiresSLAandServiceDateReset(Case newCase, Case oldCase)
```

**Purpose**: Determines if critical Case fields changed, requiring entitlement and SLA recalculation.

**Critical Fields Monitored**:
1. `Case_Type__c`
2. `Case_Sub_Type__c`
3. `Location__c`
4. `AssetId`
5. `Reason`

**Logic**:
```apex
if (oldCase == null) return true;  // Insert = all fields "changed"

// Check each critical field
if (newCase.Case_Type__c != oldCase.Case_Type__c) return true;
if (newCase.Case_Sub_Type__c != oldCase.Case_Sub_Type__c) return true;
if (newCase.Location__c != oldCase.Location__c) return true;
if (newCase.AssetId != oldCase.AssetId) return true;
if (newCase.Reason != oldCase.Reason) return true;

return false;  // No critical changes
```

**Usage in Trigger**:
```apex
// BEFORE UPDATE trigger
for (Case c : Trigger.new) {
    Case oldCase = Trigger.oldMap.get(c.Id);

    if (SLACalculationUtility.requiresSLAandServiceDateReset(c, oldCase)) {
        // Critical field changed - clear and recalculate
        c.EntitlementId = null;
        c.SLA_Service_Date_Time__c = null;
        c.Service_Date__c = null;
        casesNeedingRecalc.add(c);
    }
}

// Recalculate for affected cases
SLACalculationUtility.calculateAndSetSLAFields(casesNeedingRecalc, locationMap);
```

---

### Legacy/Deprecated Methods

The following methods are maintained for backward compatibility but should NOT be used in new development:

#### calculateServiceDates()
- **Status**: Deprecated
- **Replacement**: Use `setServiceDate()` or `calculateAndSetSLAFields()`
- **Reason**: Complex logic, non-obvious parameters

#### correctSLADate()
- **Status**: Deprecated
- **Replacement**: Logic integrated into main calculation methods
- **Reason**: Edge case handling now built-in

#### convertToLocationTimezone()
- **Status**: Functional but prefer alternatives
- **Replacement**: Use `getLocalTime()` for current time conversion
- **Reason**: `getLocalTime()` provides simpler interface

#### calculateStandardServiceDates()
- **Status**: Special-purpose only
- **Use Case**: Only for Activate/Modify/Deactivate case types
- **Reason**: Specific to non-standard SLA logic

---

### Exception Handling

#### NoEntitlementException

**Definition**:
```apex
public class NoEntitlementException extends Exception {}
```

**When Thrown**:
1. `EntitlementId` is null when calculation requires it
2. Entitlement record not found in queried map

**Caught By**: `setServiceDate()` and `calculateAndSetSLAFields()`

**Fallback Behavior**:
```apex
catch (Exception ex) {
    System.debug('EXCEPTION: ' + ex.getMessage());

    // Emergency fallback: Tomorrow at 11:59 PM
    c.Service_Date__c = System.now().addDays(1).date();
    c.SLA_Service_Date_Time__c = DateTime.newInstance(
        c.Service_Date__c,
        Time.newInstance(23, 59, 59, 59)
    );

    // Adjust for business hours
    while (!BusinessHours.isWithin(bh.Id, c.Service_Date__c)) {
        c.Service_Date__c = c.Service_Date__c.addDays(1);
        c.SLA_Service_Date_Time__c = DateTime.newInstance(
            c.Service_Date__c,
            Time.newInstance(23, 59, 59, 59)
        );
    }
}
```

**Best Practices**:
- Always ensure EntitlementId is populated before calling SLA calculation methods
- Use `CaseEntitlement.populateEntitlement()` before calculation
- Monitor for fallback scenarios in production logs

---

## Entitlement_Utility - Technical Deep Dive

### Class Structure

```apex
public class Entitlement_Utility {
    // Constants
    static final String QUERY_INTRO = 'Select Id';
    static final String IND_STANDARD = 'Industry_SLA';
    static final String CUST_ENTITLEMENT = 'Customer Specific Entitlement';

    // Deprecated Static Variables (DO NOT USE)
    @Deprecated public static Set<Id> accountIdSet;
    @Deprecated public static Date minimumServiceDate;

    // Inner Classes (see details below)
    private class CommonEntitlementData { ... }
    private class CaseDetailsResult { ... }
    private class QuoteDetailsResult { ... }
    public class priorityFields { ... }
    public class priorityFieldSets { ... }
    public class prioritizationResult { ... }

    // Comparator Classes
    public class PrimaryPriorityCompare implements Comparator<prioritizationResult> { ... }
    public class CustomerPriorityCompare implements Comparator<prioritizationResult> { ... }
    public class ServicePriorityCompare implements Comparator<prioritizationResult> { ... }
    public class TransactionPriorityCompare implements Comparator<prioritizationResult> { ... }
    public class CompositePriorityCompare implements Comparator<prioritizationResult> { ... }

    // Public Methods (see details below)
    // Private Helper Methods (see details below)
}
```

### Method Catalog

#### 1. getPrioritizedEntitlements(Set&lt;Id&gt; targetRecords)

**Signature**:
```apex
public static Map<String, Entitlement> getPrioritizedEntitlements(Set<Id> targetRecords)
```

**Purpose**: Returns the SINGLE highest-priority entitlement for each target record.

**Algorithm Flow**:
```
START
  │
  ├─ Call getCommonEntitlementData(targetRecords)
  │    │
  │    ├─ Determine record types (Case vs Quote)
  │    ├─ Extract priority fields for each record type
  │    ├─ Collect account IDs and minimum service date
  │    ├─ Query entitlements with parameters
  │    └─ Return CommonEntitlementData wrapper
  │
  ├─ Call prioritizeEntitlements(priorityFieldList, allEntitlementsMap)
  │    │
  │    ├─ For each record ID:
  │    │    ├─ For each entitlement:
  │    │    │    ├─ Match priority fields against entitlement
  │    │    │    ├─ Calculate Customer/Service/Transaction scores
  │    │    │    ├─ Determine priority rank (0-7)
  │    │    │    └─ Create prioritizationResult
  │    │    │
  │    │    ├─ Sort results by CompositePriorityCompare
  │    │    └─ Select first result (highest priority)
  │    │
  │    └─ Return Map<RecordId, Entitlement>
  │
  └─ RETURN Map<String, Entitlement>
```

**Prioritization Logic**:

Priority Rank (0 = highest, 7 = lowest):

| Rank | Criteria | Example |
|------|----------|---------|
| 0 | Customer + Service + Transaction ALL match | Specific customer, specific service, specific timing |
| 1 | Customer + Service match | Specific customer and service, any timing |
| 2 | Customer + Transaction match | Specific customer and timing, any service |
| 3 | Customer only | Specific customer, generic service/timing |
| 4 | Service + Transaction match | Specific service and timing, any customer |
| 5 | Service only | Specific service, any customer/timing |
| 6 | Transaction only | Specific timing, any customer/service |
| 7 | No matches | Industry standard / default |

**Tie-Breaking**:
Within same priority rank, sorted by:
1. Customer score (descending) - More customer fields matched = higher priority
2. Service score (descending) - More service fields matched = higher priority
3. Transaction score (descending) - More transaction fields matched = higher priority

**Code Sample**:
```apex
Set<Id> caseIds = new Set<Id>{ caseRecord.Id };
Map<String, Entitlement> prioritizedMap =
    Entitlement_Utility.getPrioritizedEntitlements(caseIds);

Entitlement selectedEntitlement = prioritizedMap.get(caseRecord.Id);

if (selectedEntitlement != null) {
    System.debug('Selected Entitlement: ' + selectedEntitlement.Name);
    caseRecord.EntitlementId = selectedEntitlement.Id;
} else {
    System.debug('WARNING: No entitlement found for case');
}
```

---

#### 2. getRelevantEntitlements(Set&lt;Id&gt; targetRecords)

**Signature**:
```apex
public static Map<String, Map<String, List<Entitlement>>> getRelevantEntitlements(
    Set<Id> targetRecords
)
```

**Purpose**: Returns ALL valid entitlements for target records, grouped by type.

**Return Structure**:
```apex
Map<String, Map<String, List<Entitlement>>>
│
├─ Key: Record ID (Case or Quote ID)
│   │
│   └─ Value: Map<String, List<Entitlement>>
│       │
│       ├─ Key: "Industry_SLA"
│       │   └─ Value: List<Entitlement> (entitlements with AccountId = null)
│       │
│       └─ Key: "Customer Specific Entitlement"
│           └─ Value: List<Entitlement> (entitlements with AccountId populated)
```

**Filtering Applied**:
1. **Date Range**: `StartDate <= today` AND `EndDate >= today`
2. **Status**: `Status__c = 'Approved'` AND `Status != 'Expired'`
3. **Time/Day**: Filtered by `Call_On__c`, `Call_Time__c`, `Before_After__c`
4. **Account**: Either `AccountId = null` (Industry) OR `AccountId = record.Client__c`

**Code Sample**:
```apex
Set<Id> caseIds = new Set<Id>{ caseRecord.Id };
Map<String, Map<String, List<Entitlement>>> allEntitlements =
    Entitlement_Utility.getRelevantEntitlements(caseIds);

Map<String, List<Entitlement>> caseEntitlements = allEntitlements.get(caseRecord.Id);

if (caseEntitlements != null) {
    List<Entitlement> industryStandard = caseEntitlements.get('Industry_SLA');
    List<Entitlement> customerSpecific = caseEntitlements.get('Customer Specific Entitlement');

    System.debug('Industry Standard Entitlements: ' + industryStandard.size());
    System.debug('Customer Specific Entitlements: ' + customerSpecific.size());
}
```

---

#### 3. getCommonEntitlementData(Set&lt;Id&gt; targetRecords) [PRIVATE]

**Signature**:
```apex
private static CommonEntitlementData getCommonEntitlementData(Set<Id> targetRecords)
```

**Purpose**: Internal method that gathers all data needed for both `getPrioritizedEntitlements()` and `getRelevantEntitlements()`.

**Process**:
1. Separate Case IDs from Quote IDs based on ID prefix
2. For Cases: Call `getCaseDetailsWithMetadata()` to extract priority fields
3. For Quotes: Call `getQuoteDetailsWithMetadata()` to extract priority fields
4. Collect account IDs and minimum service date from records
5. Call `getEntitlementsWithParams()` to query entitlements
6. Return `CommonEntitlementData` wrapper

**CommonEntitlementData Structure**:
```apex
private class CommonEntitlementData {
    List<priorityFields> priorityFieldList;        // All priority fields from all records
    Map<String, List<Entitlement>> allEntitlementsMap;  // All queried entitlements
}
```

---

#### 4. getCaseDetailsWithMetadata() [PRIVATE]

**Signature**:
```apex
private static CaseDetailsResult getCaseDetailsWithMetadata(
    Set<Id> caseIdSet,
    Map<String, List<priorityFields>> casePriorityFields,
    List<Entitlement_Field_Mapping__mdt> fieldMapping
)
```

**Purpose**: Builds priority fields for Cases using metadata field mappings.

**Dynamic Query Construction**:
```apex
String queryString = 'SELECT Id';

// Add all fields from metadata Case__c column
for (Entitlement_Field_Mapping__mdt field : fieldMapping) {
    if (field.Case__c != null) {
        queryString += ', ' + field.Case__c;  // e.g., "Client__c", "Location__r.Name"
    }
}

queryString += ', Location__r.tz__UTF_Offset__c';
queryString += ' FROM Case WHERE Id IN :caseIdSet';

List<Case> caseList = Database.query(queryString);
```

**Relationship Traversal**:
Handles up to 3 levels of relationship depth:

| Depth | Example Field | Apex Code |
|-------|---------------|-----------|
| 0 | `Client__c` | `qCase.get(field.Case__c)` |
| 1 | `Location__r.Name` | `qCase.getSobject('Location__r').get('Name')` |
| 2 | `Asset__r.Product2.Name` | `qCase.getSobject('Asset__r').getSobject('Product2').get('Name')` |
| 3 | `Asset__r.Product2.Family__r.Name` | `qCase.getSobject(...).getSobject(...).getSobject(...).get(...)` |

**priorityFields Population**:
For each Case, for each metadata field mapping:
```apex
priorityFields priorityInstance = new priorityFields();
priorityInstance.recordId = qCase.Id;
priorityInstance.priorityLevel = field.Priority_Value__c;  // e.g., "0A", "2B"
priorityInstance.commonName = field.MasterLabel;  // e.g., "Account Name"
priorityInstance.entitlementField = field.Entitlement__c;  // e.g., "AccountId"
priorityInstance.objectValue = String.valueOf(qCase.get(field.Case__c));  // Actual value
```

**Return Value**:
```apex
private class CaseDetailsResult {
    Map<String, List<priorityFields>> priorityFieldsMap;  // Key = Case ID
    Set<Id> accountIds;              // Collected Client__c values
    Date minimumServiceDate;         // Minimum Service_Date__c found
}
```

---

#### 5. getQuoteDetailsWithMetadata() [PRIVATE]

**Signature**:
```apex
private static QuoteDetailsResult getQuoteDetailsWithMetadata(
    Set<Id> quoteIdSet,
    Map<String, List<priorityFields>> quotePriorityFields,
    List<Entitlement_Field_Mapping__mdt> fieldMapping
)
```

**Purpose**: Builds priority fields for CPQ Quotes using metadata field mappings.

**Integration with QuoteProcurementController**:
```apex
for (String quoteId : quoteIdSet) {
    QuoteProcurementController.ProductsWrapper productDesignations =
        QuoteProcurementController.buildQuoteWrapper(quoteId);

    for (QuoteProcurementController.HeaderWrapper hw : productDesignations.configuredProducts) {
        for (Entitlement_Field_Mapping__mdt field : fieldMapping) {
            priorityFields priorityInstance = new priorityFields();
            priorityInstance.recordId = hw.quoteID;
            priorityInstance.priorityLevel = field.Priority_Value__c;
            priorityInstance.commonName = field.MasterLabel;
            priorityInstance.entitlementField = field.Entitlement__c;
            priorityInstance.objectValue = (String) hw.getField(field.Quote__c);
            quoteFields.add(priorityInstance);
        }
        accountIds.add(hw.clientId);
    }
}
```

**Return Value**:
```apex
private class QuoteDetailsResult {
    Map<String, List<priorityFields>> priorityFieldsMap;  // Key = Quote ID
    Set<Id> accountIds;              // Collected account IDs
}
```

---

#### 6. getEntitlementsWithParams() [PRIVATE]

**Signature**:
```apex
private static Map<String, List<Entitlement>> getEntitlementsWithParams(
    Map<String, List<priorityFields>> priorityFields,
    List<Entitlement_Field_Mapping__mdt> mappedFields,
    Set<Id> paramAccountIdSet,
    Date paramMinimumServiceDate
)
```

**Purpose**: Queries entitlements with specific account IDs and date parameters.

**Dynamic Query Construction**:
```apex
String queryString = 'SELECT Id';

// Add all fields from metadata Entitlement__c column
for (Entitlement_Field_Mapping__mdt field : mappedFields) {
    queryString += ', ' + field.Entitlement__c;
}

queryString += ', Name';
queryString += ' FROM Entitlement';
queryString += ' WHERE AccountId IN :paramAccountIdSet';
queryString += ' AND StartDate <= :paramMinimumServiceDate';
queryString += ' AND Status__c = :approved';
queryString += ' AND Status != :STATUS_EXPIRED';
queryString += ' LIMIT 49999';

List<Entitlement> entitlementList = Database.query(queryString);
```

**Filtering via filterEntitlementsByTime()**:
After querying, applies additional time-based filtering:
```apex
Map<String, List<Entitlement>> entitlementMap =
    filterEntitlementsByTime(priorityFields, entitlementList);
```

---

#### 7. filterEntitlementsByTime()

**Signature**:
```apex
public static Map<String, List<Entitlement>> filterEntitlementsByTime(
    Map<String, List<priorityFields>> priorityFields,
    List<Entitlement> entitlementList
)
```

**Purpose**: Filters entitlements based on current day of week and time of day.

**Algorithm**:
```
For each record ID:
  For each priority field (find "Account Name" field):
    For each entitlement:

      1. Check Day of Week
         If Entitlement.Call_On__c is populated:
           Get current day (e.g., "Mon", "Tue", "Wed")
           If Call_On__c does NOT contain current day:
             SKIP this entitlement

      2. Check Call Time and Before/After
         If Call_Time__c OR Before_After__c is NULL:
           SKIP this entitlement

         Extract hour from Call_Time__c (e.g., "14:00" → 14)
         Get current hour

         If Before_After__c = "Before":
           If current hour >= call time hour:
             SKIP this entitlement

         If Before_After__c = "After":
           If current hour < call time hour:
             SKIP this entitlement

      3. Check Account Matching
         If Entitlement.AccountId = NULL (Industry Standard):
           ADD to result list
         Else if Entitlement.AccountId = priority field object value:
           ADD to result list
         Else:
           SKIP this entitlement

    Store result list for record ID
```

**Example Scenarios**:

**Scenario 1**: Current time is 10 AM on Monday
- Entitlement A: `Call_On__c = "Mon,Wed,Fri"`, `Call_Time__c = "14:00"`, `Before_After__c = "Before"`
  - ✅ Passes: Monday is included, 10 AM < 2 PM
- Entitlement B: `Call_On__c = "Tue,Thu"`, `Call_Time__c = "14:00"`, `Before_After__c = "Before"`
  - ❌ Fails: Monday not in Call_On__c
- Entitlement C: `Call_On__c = "Mon"`, `Call_Time__c = "09:00"`, `Before_After__c = "Before"`
  - ❌ Fails: 10 AM >= 9 AM (after cutoff)

**Scenario 2**: Current time is 3 PM on Wednesday
- Entitlement D: `Call_On__c = "Mon,Wed,Fri"`, `Call_Time__c = "14:00"`, `Before_After__c = "After"`
  - ✅ Passes: Wednesday included, 3 PM >= 2 PM
- Entitlement E: `Call_On__c = "Mon,Wed,Fri"`, `Call_Time__c = "14:00"`, `Before_After__c = "Before"`
  - ❌ Fails: 3 PM >= 2 PM (not before)

---

#### 8. prioritizeEntitlements()

**Signature**:
```apex
public static Map<String, Entitlement> prioritizeEntitlements(
    List<priorityFields> mappedFields,
    Map<String, List<Entitlement>> entitlementRules
)
```

**Purpose**: Applies the multi-tier prioritization algorithm to select the best entitlement for each record.

**Detailed Algorithm**:

```
1. Group priority fields by record ID
   Map<RecordId, List<priorityFields>> priorityFieldsByRecord

2. For each record ID:

   a. Create list of prioritizationResult objects

   b. For each entitlement for this record:

      Initialize scores:
      - customerScore = 0
      - serviceScore = 0
      - transactionScore = 0
      - noMatch = false

      For each priority field for this record:

         Extract entitlement value for the mapped field
         Compare entitlement value to priority field object value

         Match occurs if:
         - Entitlement value = object value, OR
         - Object value is populated AND entitlement value is NULL (wildcard match)

         If MATCH:
            Determine priority prefix (first character of Priority_Value__c):
            - If prefix = '0' or '1':
                customerScore++
                customerIdentification = true
            - If prefix = '2':
                serviceScore++
                serviceIdentification = true
            - If prefix = '3' or '4':
                transactionScore++
                transactionIdentification = true
         Else:
            noMatch = true (but continue checking other fields)

      Calculate priority rank based on flags:
      - All three true (Customer + Service + Transaction) → Rank 0
      - Customer + Service → Rank 1
      - Customer + Transaction → Rank 2
      - Customer only → Rank 3
      - Service + Transaction → Rank 4
      - Service only → Rank 5
      - Transaction only → Rank 6
      - None → Rank 7

      If NOT noMatch:
         Add prioritizationResult to list

   c. Sort list using CompositePriorityCompare:
      - First by priority rank (ascending)
      - Then by customer score (descending)
      - Then by service score (descending)
      - Then by transaction score (descending)

   d. Select first result (index 0) as the best entitlement

   e. Add to final map: recordId → entitlement

3. Return Map<RecordId, Entitlement>
```

**CompositePriorityCompare Logic**:
```apex
public Integer compare(prioritizationResult p1, prioritizationResult p2) {
    // Compare priority rank (lower is better)
    if (p1.priorityRank != p2.priorityRank) {
        return p1.priorityRank - p2.priorityRank;  // Ascending
    }

    // Tie-break by customer rank (higher is better)
    if (p1.customerRank != p2.customerRank) {
        return p2.customerRank - p1.customerRank;  // Descending
    }

    // Tie-break by service rank (higher is better)
    if (p1.serviceRank != p2.serviceRank) {
        return p2.serviceRank - p1.serviceRank;  // Descending
    }

    // Tie-break by transaction rank (higher is better)
    if (p1.transactionRank != p2.transactionRank) {
        return p2.transactionRank - p1.transactionRank;  // Descending
    }

    return 0;  // Exactly equal
}
```

**Example Prioritization**:

Given entitlements for a single case:

| Entitlement | Customer Matches | Service Matches | Transaction Matches | Rank | Customer Score | Service Score | Transaction Score | Final Priority |
|-------------|------------------|-----------------|---------------------|------|----------------|---------------|-------------------|----------------|
| A | ✅ Yes | ✅ Yes | ✅ Yes | 0 | 3 | 2 | 1 | **1st (SELECTED)** |
| B | ✅ Yes | ✅ Yes | ❌ No | 1 | 3 | 2 | 0 | 2nd |
| C | ✅ Yes | ❌ No | ✅ Yes | 2 | 3 | 0 | 1 | 3rd |
| D | ✅ Yes | ❌ No | ❌ No | 3 | 2 | 0 | 0 | 4th |
| E | ❌ No | ✅ Yes | ✅ Yes | 4 | 0 | 2 | 1 | 5th |
| F | ❌ No | ✅ Yes | ❌ No | 5 | 0 | 2 | 0 | 6th |
| G | ❌ No | ❌ No | ✅ Yes | 6 | 0 | 0 | 1 | 7th |
| H | ❌ No | ❌ No | ❌ No | 7 | 0 | 0 | 0 | 8th (Last resort) |

---

#### 9. getIndustryStandardSLA(Case caseRecord)

**Signature**:
```apex
public static List<Entitlement> getIndustryStandardSLA(Case caseRecord)
```

**Purpose**: Retrieves industry standard SLA entitlements (not customer-specific).

**Query Logic**:
```apex
String queryString = 'SELECT Id, Name, ...fields...';
queryString += ' FROM Entitlement';
queryString += ' WHERE RecordType.DeveloperName = :IND_STANDARD';  // 'Industry_SLA'
queryString += ' AND (Request_Type__c = :RequestType OR Request_Type__c = null)';

if (Service is not blank) {
    queryString += ' AND (Service__c = :Service OR (Service__c = null AND Request_Type__c != null))';
}

if (Case_Reason__c is not blank) {
    queryString += ' AND (Case_Reason__c = :caseReason OR (Case_Reason__c = null AND Service__c != null))';
}

queryString += ' LIMIT 49999';

List<Entitlement> industrySLAList = Database.query(queryString);
```

**Matching Strategy**:
Progressively narrows down from most general to most specific:

1. **Level 1**: Match Request_Type__c (Case_Type__c)
2. **Level 2**: Match Service__c (Case_Sub_Type__c) IF populated
3. **Level 3**: Match Case_Reason__c IF populated

**NULL Handling**: NULL entitlement fields act as wildcards (match anything)

**Code Sample**:
```apex
Case caseRecord = [SELECT Id, Case_Type__c, Case_Sub_Type__c, Case_Reason__c
                   FROM Case WHERE Id = :caseId];

List<Entitlement> industryStandards =
    Entitlement_Utility.getIndustryStandardSLA(caseRecord);

if (!industryStandards.isEmpty()) {
    System.debug('Found ' + industryStandards.size() + ' industry standard entitlements');
    // Use first match or apply further filtering
    caseRecord.EntitlementId = industryStandards[0].Id;
}
```

---

### Inner Classes

#### priorityFields

**Purpose**: Holds field matching data for a single metadata mapping and record.

**Structure**:
```apex
public class priorityFields {
    @AuraEnabled public Id recordId;             // Case/Quote ID
    @AuraEnabled public String priorityLevel;    // e.g., "0A", "2B" (from metadata)
    @AuraEnabled public String commonName;       // e.g., "Account Name" (from metadata)
    @AuraEnabled public String entitlementField; // e.g., "AccountId" (from metadata)
    @AuraEnabled public String objectValue;      // Actual value from record
}
```

**Example Instance**:
```apex
priorityFields pf = new priorityFields();
pf.recordId = '5001234567890ABC';
pf.priorityLevel = '0A';
pf.commonName = 'Account Name';
pf.entitlementField = 'AccountId';
pf.objectValue = '0011234567890DEF';  // Actual Account ID from case
```

---

#### prioritizationResult

**Purpose**: Holds scoring and ranking data for a single entitlement candidate.

**Structure**:
```apex
public class prioritizationResult {
    @AuraEnabled public Entitlement entitlementRecord;
    @AuraEnabled public Boolean customerIdentification;
    @AuraEnabled public Boolean serviceIdentification;
    @AuraEnabled public Boolean transactionIdentification;
    @AuraEnabled public Integer priorityRank;        // 0-7
    @AuraEnabled public Integer customerRank;        // Count of customer fields matched
    @AuraEnabled public Integer serviceRank;         // Count of service fields matched
    @AuraEnabled public Integer transactionRank;     // Count of transaction fields matched

    // Getter methods for comparators
    public Integer getPriorityRank() { return priorityRank; }
    public Integer getCustomerRank() { return customerRank; }
    public Integer getServiceRank() { return serviceRank; }
    public Integer getTransactionRank() { return transactionRank; }
}
```

**Example Instance**:
```apex
prioritizationResult pr = new prioritizationResult();
pr.entitlementRecord = [SELECT Id, Name FROM Entitlement WHERE Id = :entId];
pr.customerIdentification = true;   // Customer fields matched
pr.serviceIdentification = true;    // Service fields matched
pr.transactionIdentification = false; // No transaction fields matched
pr.priorityRank = 1;                // Rank 1 (Customer + Service)
pr.customerRank = 3;                // 3 customer fields matched
pr.serviceRank = 2;                 // 2 service fields matched
pr.transactionRank = 0;             // 0 transaction fields matched
```

---

### Comparator Classes

Five comparator classes provide different sorting strategies:

| Comparator | Sorts By | Order | Use Case |
|------------|----------|-------|----------|
| PrimaryPriorityCompare | priorityRank | Ascending | Primary ranking |
| CustomerPriorityCompare | customerRank | Descending | Customer specificity |
| ServicePriorityCompare | serviceRank | Descending | Service specificity |
| TransactionPriorityCompare | transactionRank | Descending | Transaction specificity |
| **CompositePriorityCompare** | All of the above | Composite | **RECOMMENDED** |

**Best Practice**: Use `CompositePriorityCompare` for complete multi-tier sorting.

---

## Class Interplay and Integration Patterns

### Call Sequence Diagram

```
┌─────────────┐
│   Trigger   │ (Case Before Insert)
│  or Flow    │
└──────┬──────┘
       │
       │ 1. Invoke
       ▼
┌────────────────────────────────────┐
│  Entitlement_Utility               │
│  .getPrioritizedEntitlements()     │
└──────┬─────────────────────────────┘
       │
       │ 2. Returns Map<Id, Entitlement>
       │
       ▼
┌─────────────┐
│  Assign     │ caseRecord.EntitlementId = entitlement.Id
│EntitlementId│
└──────┬──────┘
       │
       │ 3. Invoke
       ▼
┌────────────────────────────────────┐
│  SLACalculationUtility             │
│  .calculateAndSetSLAFields()       │
└──────┬─────────────────────────────┘
       │
       │ 4. Queries Entitlement with SLA fields
       │
       ▼
┌────────────────────────────────────┐
│  Calculate SLA Date                │
│  • Get days delta from entitlement │
│  • Check cutoff time               │
│  • Add delta to CreatedDate        │
│  • Adjust for business hours       │
└──────┬─────────────────────────────┘
       │
       │ 5. Sets fields in-memory
       │
       ▼
┌────────────────────────────────────┐
│  Case Record Updated               │
│  • Service_Date__c                 │
│  • SLA_Service_Date_Time__c        │
│  • SLA_Service_Date__c             │
└────────────────────────────────────┘
       │
       │ 6. Trigger framework performs DML
       ▼
┌────────────────────────────────────┐
│  Database                          │
└────────────────────────────────────┘
```

---

### Integration Pattern 1: Before Insert Trigger

**Use Case**: New cases need entitlement and SLA calculated before insert.

**Implementation**:
```apex
trigger CaseTrigger on Case (before insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        CaseTriggerHandler.handleBeforeInsert(Trigger.new);
    }
}
```

**Handler Method**:
```apex
public class CaseTriggerHandler {

    public static void handleBeforeInsert(List<Case> newCases) {

        // Filter to cases needing entitlement
        List<Case> needsEntitlement = new List<Case>();
        for (Case c : newCases) {
            if (c.EntitlementId == null && c.Client__c != null && c.Location__c != null) {
                needsEntitlement.add(c);
            }
        }

        if (needsEntitlement.isEmpty()) return;

        // STEP 1: Get prioritized entitlements
        Set<Id> caseIds = new Map<Id, Case>(needsEntitlement).keySet();
        Map<String, Entitlement> entitlements =
            Entitlement_Utility.getPrioritizedEntitlements(caseIds);

        // STEP 2: Assign EntitlementId
        for (Case c : needsEntitlement) {
            Entitlement ent = entitlements.get(c.Id);
            if (ent != null) {
                c.EntitlementId = ent.Id;
            }
        }

        // STEP 3: Calculate SLA dates (NO DML in before trigger)
        Map<Id, Account> locationMap = buildLocationMap(needsEntitlement);
        SLACalculationUtility.calculateAndSetSLAFields(needsEntitlement, locationMap);

        // Fields are set, trigger framework handles insert
    }

    private static Map<Id, Account> buildLocationMap(List<Case> cases) {
        Set<Id> locationIds = new Set<Id>();
        for (Case c : cases) {
            if (c.Location__c != null) {
                locationIds.add(c.Location__c);
            }
        }

        return new Map<Id, Account>([
            SELECT Id, tz__UTF_Offset__c, tz__Timezone_SFDC__c
            FROM Account WHERE Id IN :locationIds
        ]);
    }
}
```

---

### Integration Pattern 2: After Update Trigger (Recalculation)

**Use Case**: Critical fields changed, need to recalculate entitlement and SLA.

**Implementation**:
```apex
trigger CaseTrigger on Case (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        CaseTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
```

**Handler Method**:
```apex
public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldMap) {

    List<Case> casesNeedingRecalc = new List<Case>();

    for (Case c : newCases) {
        Case oldCase = oldMap.get(c.Id);

        // Check if critical fields changed
        if (SLACalculationUtility.requiresSLAandServiceDateReset(c, oldCase)) {
            // Clear existing SLA data
            c.EntitlementId = null;
            c.SLA_Service_Date_Time__c = null;
            c.Service_Date__c = null;
            casesNeedingRecalc.add(c);
        }
    }

    if (casesNeedingRecalc.isEmpty()) return;

    // Recalculate using invocable method (includes DML)
    SLACalculationUtility.setServiceDate(casesNeedingRecalc);
}
```

---

### Integration Pattern 3: Lightning Web Component

**Use Case**: User wants to see available entitlements and select one manually.

**Apex Controller**:
```apex
public class CaseEntitlementController {

    @AuraEnabled(cacheable=true)
    public static EntitlementOptionsWrapper getEntitlementOptions(Id caseId) {

        // Get both prioritized and all available
        Set<Id> caseIds = new Set<Id>{ caseId };

        Map<String, Entitlement> prioritized =
            Entitlement_Utility.getPrioritizedEntitlements(caseIds);

        Map<String, Map<String, List<Entitlement>>> allOptions =
            Entitlement_Utility.getRelevantEntitlements(caseIds);

        // Calculate service date for recommended entitlement
        Entitlement recommended = prioritized.get(caseId);
        Date calculatedServiceDate = null;

        if (recommended != null) {
            Case c = [SELECT Id, CreatedDate, Location__c FROM Case WHERE Id = :caseId];
            Account location = [SELECT Id, tz__UTF_Offset__c FROM Account WHERE Id = :c.Location__c];

            c.EntitlementId = recommended.Id;

            SLACalculationUtility.ServiceDateCalculationResult result =
                SLACalculationUtility.calculateServiceDateWithCapacity(
                    c, null, recommended, location
                );

            calculatedServiceDate = result.serviceDate;
        }

        // Build response wrapper
        EntitlementOptionsWrapper wrapper = new EntitlementOptionsWrapper();
        wrapper.recommendedEntitlement = recommended;
        wrapper.allEntitlements = allOptions.get(caseId);
        wrapper.calculatedServiceDate = calculatedServiceDate;

        return wrapper;
    }

    @AuraEnabled
    public static Date applyEntitlement(Id caseId, Id entitlementId) {

        Case c = [SELECT Id, CreatedDate, Location__c FROM Case WHERE Id = :caseId];
        c.EntitlementId = entitlementId;

        Entitlement ent = [SELECT Id, Service_Guarantee_Category__c,
                                   Service_Guarantee_Category_Value__c
                           FROM Entitlement WHERE Id = :entitlementId];

        Account location = [SELECT Id, tz__UTF_Offset__c FROM Account WHERE Id = :c.Location__c];

        SLACalculationUtility.ServiceDateCalculationResult result =
            SLACalculationUtility.calculateServiceDateWithCapacity(c, null, ent, location);

        c.Service_Date__c = result.serviceDate;
        c.SLA_Service_Date_Time__c = result.slaServiceDateTime;
        update c;

        return result.serviceDate;
    }

    public class EntitlementOptionsWrapper {
        @AuraEnabled public Entitlement recommendedEntitlement;
        @AuraEnabled public Map<String, List<Entitlement>> allEntitlements;
        @AuraEnabled public Date calculatedServiceDate;
    }
}
```

**LWC JavaScript**:
```javascript
import { LightningElement, api, wire } from 'lwc';
import getEntitlementOptions from '@salesforce/apex/CaseEntitlementController.getEntitlementOptions';
import applyEntitlement from '@salesforce/apex/CaseEntitlementController.applyEntitlement';

export default class CaseEntitlementSelector extends LightningElement {
    @api recordId;

    entitlementOptions;
    selectedEntitlementId;
    calculatedServiceDate;

    @wire(getEntitlementOptions, { caseId: '$recordId' })
    wiredOptions({ error, data }) {
        if (data) {
            this.entitlementOptions = data;
            this.selectedEntitlementId = data.recommendedEntitlement?.Id;
            this.calculatedServiceDate = data.calculatedServiceDate;
        }
    }

    handleEntitlementChange(event) {
        this.selectedEntitlementId = event.target.value;

        // Recalculate service date
        applyEntitlement({
            caseId: this.recordId,
            entitlementId: this.selectedEntitlementId
        })
        .then(result => {
            this.calculatedServiceDate = result;
            // Show success toast
        })
        .catch(error => {
            // Show error toast
        });
    }
}
```

---

## Data Model Dependencies

### Object Relationships

```
┌──────────────┐
│    Case      │
└──────┬───────┘
       │
       ├─ Client__c ───────────────┐
       │                           ▼
       │                    ┌──────────────┐
       │                    │   Account    │ (Client)
       │                    └──────────────┘
       │
       ├─ Location__c ─────────────┐
       │                           ▼
       │                    ┌──────────────┐
       │                    │   Account    │ (Location)
       │                    │ • tz__UTC_Offset__c
       │                    │ • tz__Timezone_SFDC__c
       │                    └──────────────┘
       │
       ├─ AssetId ─────────────────┐
       │                           ▼
       │                    ┌──────────────┐
       │                    │    Asset     │
       │                    │ • ProductFamily
       │                    │ • Assets_Parent__r
       │                    └──────────────┘
       │
       └─ EntitlementId ───────────┐
                                   ▼
                            ┌──────────────────┐
                            │   Entitlement    │
                            │ • Service_Guarantee_Category__c
                            │ • Service_Guarantee_Category_Value__c
                            │ • Call_Time__c
                            │ • Before_After__c
                            │ • Call_On__c
                            │ • Gold_Standard__c
                            │ • Contractual__c
                            └──────────────────┘
```

### Required Field Matrix

| Object | Field | Type | Required For | Purpose |
|--------|-------|------|--------------|---------|
| **Case** | Client__c | Lookup(Account) | Both | Customer identification |
| | Location__c | Lookup(Account) | Both | Location/timezone identification |
| | Case_Type__c | Picklist | Both | Service type categorization |
| | Case_Sub_Type__c | Picklist | Both | Service sub-categorization |
| | Case_Reason__c | Picklist | Entitlement | Fine-grained matching |
| | AssetId | Lookup(Asset) | SLA | Service header for capacity planning |
| | EntitlementId | Lookup(Entitlement) | SLA | SLA configuration source |
| | Service_Date__c | Date | SLA | Calculated service date |
| | SLA_Service_Date_Time__c | DateTime | SLA | Calculated SLA timestamp |
| | SLA_Service_Date__c | Date | SLA | Mirror of Service_Date__c |
| | CreatedDate | DateTime | SLA | Base time for calculation |
| **Account** | tz__UTC_Offset__c | Decimal | SLA | UTC offset in hours |
| (Location) | tz__Timezone_SFDC__c | Text | SLA | Salesforce timezone ID |
| **Entitlement** | AccountId | Lookup(Account) | Both | Null = Industry, populated = Customer |
| | StartDate | Date | Both | Validity period start |
| | EndDate | Date | Both | Validity period end |
| | Status__c | Picklist | Both | Must be 'Approved' |
| | Status | Picklist | Both | Must not be 'Expired' |
| | Service_Guarantee_Category__c | Picklist | SLA | 'Hours' or 'Days' |
| | Service_Guarantee_Category_Value__c | Number | SLA | SLA duration value |
| | Call_Time__c | Text | Entitlement | Time cutoff (e.g., '14:00') |
| | Before_After__c | Picklist | Entitlement | 'Before' or 'After' |
| | Call_On__c | Text | Entitlement | Days of week (e.g., 'Mon,Wed,Fri') |
| | Override_Business_Hours__c | Checkbox | SLA | Skip business hours check |
| | Gold_Standard__c | Checkbox | SLA | Force entitlement calculation |
| | Contractual__c | Checkbox | SLA | Force entitlement calculation |
| **Asset** | ProductFamily | Picklist | SLA | 'Rolloff', 'Commercial', etc. |
| | Assets_Parent__r | Child Relationship | SLA | Service detail children |
| **Custom Metadata** | | | | |
| Entitlement_Field_Mapping__mdt | Priority_Value__c | Text | Entitlement | e.g., '0A', '2B' |
| | Case__c | Text | Entitlement | Case field API name |
| | Entitlement__c | Text | Entitlement | Entitlement field API name |
| | Quote__c | Text | Entitlement | Quote field API name |
| Integration_Request_URLs__mdt | End_Point__c | Text | SLA | API endpoint URL |
| | Client_Key__c | Text | SLA | API key |
| | Client_Token__c | Text | SLA | Authorization token |
| | Timeout__c | Number | SLA | Timeout in milliseconds |
| | Method__c | Text | SLA | HTTP method |

---

## Algorithm Specifications

### SLA Date Calculation Algorithm

**Input**:
- Case record with CreatedDate, Location__c, EntitlementId
- Entitlement record with Service_Guarantee_Category__c, Service_Guarantee_Category_Value__c
- Account (Location) with tz__UTF_Offset__c
- BusinessHours record

**Output**:
- Service_Date__c (Date)
- SLA_Service_Date_Time__c (DateTime)
- SLA_Service_Date__c (Date, mirror of Service_Date__c)

**Algorithm**:
```
FUNCTION calculateSLADate(case, entitlement, location, businessHours):

    # Step 1: Get days delta from entitlement
    IF entitlement.Service_Guarantee_Category__c = 'Days':
        daysDelta = FLOOR(entitlement.Service_Guarantee_Category_Value__c)
    ELSE:  # Hours
        hours = entitlement.Service_Guarantee_Category_Value__c
        daysDelta = FLOOR(hours / 24)

    # Step 2: Check cutoff time (if applicable)
    beforeCutoff = TRUE
    IF entitlement.Call_Time__c IS NULL AND entitlement.Before_After__c IS NULL:
        # Use default cutoff of 2 PM (14:00)
        localTime = getLocalTime(location)
        beforeCutoff = (localTime.hour() < 14)

    # Step 3: Adjust delta if after cutoff
    IF NOT beforeCutoff:
        daysDelta = daysDelta + 1

    # Step 4: Calculate raw SLA date
    slaDateTime = case.CreatedDate.addDays(daysDelta)
    serviceDate = slaDateTime.date()

    # Step 5: Adjust for business hours
    IF NOT entitlement.Override_Business_Hours__c:
        WHILE NOT isWithinBusinessHours(businessHours, serviceDate):
            serviceDate = serviceDate.addDays(1)

    # Step 6: Set final values
    case.Service_Date__c = serviceDate
    case.SLA_Service_Date__c = serviceDate
    case.SLA_Service_Date_Time__c = slaDateTime

    RETURN case
```

**Example Walkthrough**:

Given:
- Case created: 2024-12-15 10:00 AM EST
- Entitlement: 2 Days, Before 14:00
- Location: EST timezone (UTC -5)
- Business Hours: Mon-Fri

Calculation:
1. Days delta = 2
2. Local time = 10 AM, before 2 PM cutoff → beforeCutoff = TRUE
3. No adjustment needed
4. SLA DateTime = 2024-12-15 10:00 AM + 2 days = 2024-12-17 10:00 AM
5. Service Date = 2024-12-17
6. Check business hours:
   - 2024-12-17 is Tuesday → within business hours → no adjustment
7. Final: Service_Date__c = 2024-12-17, SLA_Service_Date_Time__c = 2024-12-17 10:00 AM

---

### Entitlement Prioritization Algorithm

**Input**:
- List of Case/Quote records
- Entitlement_Field_Mapping__mdt records
- List of Entitlement records (already filtered by date/status)

**Output**:
- Map<RecordId, Entitlement> (one best entitlement per record)

**Algorithm**:
```
FUNCTION prioritizeEntitlements(records, fieldMappings, entitlements):

    finalMap = EMPTY_MAP

    FOR each record IN records:

        prioritizationResults = EMPTY_LIST

        FOR each entitlement IN entitlements[record.Id]:

            customerScore = 0
            serviceScore = 0
            transactionScore = 0
            customerMatch = FALSE
            serviceMatch = FALSE
            transactionMatch = FALSE

            FOR each fieldMapping IN fieldMappings:

                recordValue = record.get(fieldMapping.Case__c)
                entitlementValue = entitlement.get(fieldMapping.Entitlement__c)

                # Check for match
                isMatch = (recordValue = entitlementValue) OR
                          (recordValue IS NOT NULL AND entitlementValue IS NULL)

                IF isMatch:
                    priorityPrefix = fieldMapping.Priority_Value__c[0]

                    IF priorityPrefix IN ['0', '1']:
                        customerScore = customerScore + 1
                        customerMatch = TRUE
                    ELSE IF priorityPrefix = '2':
                        serviceScore = serviceScore + 1
                        serviceMatch = TRUE
                    ELSE IF priorityPrefix IN ['3', '4']:
                        transactionScore = transactionScore + 1
                        transactionMatch = TRUE

            # Determine priority rank
            IF customerMatch AND serviceMatch AND transactionMatch:
                priorityRank = 0
            ELSE IF customerMatch AND serviceMatch:
                priorityRank = 1
            ELSE IF customerMatch AND transactionMatch:
                priorityRank = 2
            ELSE IF customerMatch:
                priorityRank = 3
            ELSE IF serviceMatch AND transactionMatch:
                priorityRank = 4
            ELSE IF serviceMatch:
                priorityRank = 5
            ELSE IF transactionMatch:
                priorityRank = 6
            ELSE:
                priorityRank = 7

            result = NEW prioritizationResult(
                entitlement,
                customerMatch,
                serviceMatch,
                transactionMatch,
                priorityRank,
                customerScore,
                serviceScore,
                transactionScore
            )

            prioritizationResults.ADD(result)

        # Sort by composite priority
        SORT prioritizationResults BY:
            1. priorityRank (ascending)
            2. customerScore (descending)
            3. serviceScore (descending)
            4. transactionScore (descending)

        # Select best result
        IF prioritizationResults IS NOT EMPTY:
            bestEntitlement = prioritizationResults[0].entitlementRecord
            finalMap[record.Id] = bestEntitlement

    RETURN finalMap
```

---

## Error Handling and Edge Cases

### NoEntitlementException Scenarios

**Scenario 1**: Case has no Client__c or Location__c
```apex
// Entitlement_Utility cannot find matching entitlements
Map<String, Entitlement> result = Entitlement_Utility.getPrioritizedEntitlements(caseIds);
// result.get(caseId) returns null

// SLACalculationUtility throws NoEntitlementException
// Caught by fallback → Sets tomorrow at 11:59 PM
```

**Mitigation**:
- Ensure Client__c and Location__c are required fields on Case
- Add validation rule to prevent insert/update without these fields

---

**Scenario 2**: All entitlements are expired
```apex
// All entitlements have EndDate < today
// Entitlement_Utility filters them out
// Result map returns null for case

// SLA calculation applies fallback
```

**Mitigation**:
- Monitor entitlement expiration dates
- Create alert for entitlements expiring within 30 days
- Ensure industry standard entitlements have far-future end dates

---

**Scenario 3**: Call time filtering eliminates all options
```apex
// Current time: 3 PM on Monday
// Only entitlement: Call_On__c = "Tue,Wed,Thu", Call_Time__c = "14:00", Before_After__c = "Before"
// filterEntitlementsByTime() skips this entitlement (not Monday)
// Result: Empty list

// SLA calculation applies fallback
```

**Mitigation**:
- Review Call_On__c and Call_Time__c configurations
- Ensure at least one "catch-all" entitlement exists (NULL call time/day)
- Consider industry standard entitlements without time restrictions

---

### Business Hours Edge Cases

**Edge Case 1**: Service date falls on weekend

**Example**:
- Case created: Friday 3 PM
- Entitlement: Next Day (1 day delta)
- Calculated date: Saturday (weekend)

**Handling**:
```apex
while (!BusinessHours.isWithin(bh.Id, c.Service_Date__c)) {
    c.Service_Date__c = c.Service_Date__c.addDays(1);
}
// Bumps Saturday → Sunday → Monday
```

**Result**: Service_Date__c = Monday

---

**Edge Case 2**: Holiday on calculated date

**Handling**: Salesforce BusinessHours object supports holiday calendars.

**Configuration**:
1. Setup → Business Hours → Default Business Hours
2. Add holidays to calendar
3. `BusinessHours.isWithin()` automatically excludes holidays

**Result**: Algorithm bumps to next business day automatically

---

**Edge Case 3**: Override_Business_Hours__c = TRUE

**Example**: Emergency service entitlement

**Handling**:
```apex
if (!e.Override_Business_Hours__c) {
    while (!BusinessHours.isWithin(bh.Id, c.Service_Date__c)) {
        c.Service_Date__c = c.Service_Date__c.addDays(1);
    }
}
// If override = true, skip the while loop entirely
```

**Result**: Service date can fall on weekend/holiday

---

### Timezone Edge Cases

**Edge Case 1**: Location crosses midnight during calculation

**Example**:
- UTC time: 2024-12-15 23:30 (11:30 PM)
- Location: EST (UTC -5)
- Local time: 2024-12-15 18:30 (6:30 PM)

**Handling**:
```apex
DateTime localTime = DateTime.now().addHours(Integer.valueOf(a.tz__UTF_Offset__c));
// No date rollover issues because addHours handles it correctly
```

**Result**: Correct local date used for cutoff checks

---

**Edge Case 2**: Daylight Saving Time transition

**Issue**: `tz__UTC_Offset__c` is static (doesn't auto-adjust for DST)

**Example**:
- Winter (EST): UTC -5
- Summer (EDT): UTC -4
- If field not updated: wrong local time calculation

**Mitigation**:
- Implement scheduled job to update `tz__UTC_Offset__c` for DST transitions
- OR use `tz__Timezone_SFDC__c` with Timezone.getTimeZone() for automatic DST handling

**Recommended Approach**:
```apex
public static DateTime getLocalTime(Account a) {
    Timezone tz = Timezone.getTimeZone(a.tz__Timezone_SFDC__c);
    DateTime utcNow = DateTime.now();
    Integer offsetMillis = tz.getOffset(utcNow);
    return utcNow.addSeconds(offsetMillis / 1000);
}
```

---

### WM Capacity Planner Edge Cases

**Edge Case 1**: API returns empty AvailableDates array

**Response**:
```json
{
  "Data": {
    "Site": {
      "Capacity": [
        {
          "AvailableDates": []
        }
      ]
    }
  }
}
```

**Handling**:
```apex
if (availableDates == null || availableDates.isEmpty()) {
    System.debug('No available dates from Capacity Planner, using entitlement calculation');
    result.calculationMethod = 'Fallback - No Dates';
    return calculateEntitlementBasedServiceDate(...);
}
```

---

**Edge Case 2**: API timeout

**Handling**:
```apex
try {
    HttpResponse res = h.send(req);  // May timeout
} catch (Exception e) {
    System.debug('API callout failed: ' + e.getMessage());
    UTIL_LoggingService.logHandledException(e, ...);
    return new List<String>();  // Empty list triggers fallback
}
```

---

**Edge Case 3**: All capacity dates conflict with existing work orders

**Handling**:
```apex
Set<Date> existingWorkOrderDates = getExistingWorkOrderDates(asset.Id);

// Find first available date without conflict
Date selectedDate = null;
for (Date plannerDate : plannerDates) {
    if (!existingWorkOrderDates.contains(plannerDate)) {
        selectedDate = plannerDate;
        break;
    }
}

// If all dates have conflicts
if (selectedDate == null && !plannerDates.isEmpty()) {
    selectedDate = plannerDates[plannerDates.size() - 1];  // Last date
    selectedDate = getNextAvailableDateAfterConflicts(selectedDate, existingWorkOrderDates, location);
}
```

---

## Performance Characteristics

### SOQL Query Analysis

#### Entitlement_Utility.getPrioritizedEntitlements()

| Query | Target | Rows (Typical) | Selective | Notes |
|-------|--------|----------------|-----------|-------|
| 1 | Entitlement_Field_Mapping__mdt | 10-20 | N/A | Metadata, cached |
| 2 | Case (if cases provided) | Input size | Yes (Id IN) | Dynamic fields |
| 3 | SBQQ__Quote__c (if quotes provided) | Input size | Yes (Id IN) | Via QuoteProcurementController |
| 4 | Entitlement | 50-500 | Yes (AccountId, StartDate) | Filtered by date/status |

**Total**: 3-4 queries per invocation

**Scalability**:
- Linear with number of input records
- Entitlement query grows with number of accounts
- Recommended max input size: **200 records** per call

---

#### SLACalculationUtility.setServiceDate()

| Query | Target | Rows (Typical) | Selective | Notes |
|-------|--------|----------------|-----------|-------|
| 1 | BusinessHours | 1 | Yes (IsDefault=true) | Cached in transaction |
| 2 | Account | Input size | Yes (Id IN) | Location accounts |
| 3 | Entitlement | Input size | Yes (Id IN) | Already assigned to cases |
| 4 | (DML Update) | Input size | N/A | Bulk update |

**Total**: 3 queries + 1 DML per invocation

**Scalability**:
- Linear with number of input cases
- Recommended max input size: **200 cases** per call

---

### DML Operation Analysis

| Method | DML Operations | Bulk? | Trigger-Safe? |
|--------|----------------|-------|---------------|
| setServiceDate() | 1 update | Yes | No (use in after trigger or flow) |
| calculateAndSetSLAFields() | 0 | N/A | Yes (use in before trigger) |
| calculateServiceDateWithCapacity() | 0 | N/A | Yes (caller handles DML) |

---

### Callout Analysis

**WM Capacity Planner API**:
- Method: `callWMCapacityPlannerAPI()`
- Callouts per invocation: 1
- Timeout: Configured in metadata (typical: 10000ms = 10 seconds)
- Limits: Max 100 callouts per transaction

**Scalability Concern**:
If processing 100 rolloff cases, each needing capacity check:
- Would require 100 callouts → **EXCEEDS LIMIT**

**Mitigation Strategies**:

1. **Batch Processing**:
```apex
public class CapacityPlannerBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, AssetId FROM Case WHERE ProductFamily = 'Rolloff' AND Service_Date__c = null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Case> scope) {
        // Process up to 50 cases per batch (50 callouts < 100 limit)
        SLACalculationUtility.setServiceDate(scope);
    }
}
```

2. **Queueable Processing**:
```apex
public class CapacityPlannerQueueable implements Queueable, Database.AllowsCallouts {
    private List<Case> casesToProcess;

    public void execute(QueueableContext context) {
        // Process subset
        SLACalculationUtility.setServiceDate(casesToProcess);

        // Chain next batch if needed
        if (hasMoreRecords) {
            System.enqueueJob(new CapacityPlannerQueueable(nextBatch));
        }
    }
}
```

---

### CPU Time Analysis

**Entitlement_Utility Complexity**:
- **Worst Case**: O(R × E × F)
  - R = number of records
  - E = number of entitlements per record
  - F = number of field mappings
- **Typical**: 10 records × 20 entitlements × 15 fields = 3,000 iterations
- **CPU Time**: ~500-1000ms (depends on field complexity)

**SLACalculationUtility Complexity**:
- **Worst Case**: O(C × B)
  - C = number of cases
  - B = business hours iterations (max ~7 for a week)
- **Typical**: 100 cases × 2 iterations = 200 iterations
- **CPU Time**: ~200-400ms

**Governor Limit**: 10,000ms CPU time per transaction

**Scalability**: Both classes well within limits for typical batch sizes (< 200 records)

---

### Heap Size Analysis

**Entitlement_Utility**:
- Priority fields: ~500 bytes per record × 200 records = 100 KB
- Entitlements: ~2 KB per entitlement × 500 entitlements = 1 MB
- **Total Heap**: ~1.5 MB

**SLACalculationUtility**:
- Cases: ~1 KB per case × 200 cases = 200 KB
- Location map: ~500 bytes per account × 200 accounts = 100 KB
- **Total Heap**: ~500 KB

**Governor Limit**: 6 MB heap (synchronous), 12 MB (asynchronous)

**Scalability**: Both classes well within limits

---

## Testing Strategy

### Test Class Architecture

**SLACalculationUtilityTest**:
- Test setup: Creates full hierarchy (Account, Contact, Asset, Entitlement, Cases)
- Coverage target: 85%+
- Test methods: 30+ (see test class for details)

**Entitlement_UtilityTest**:
- Test setup: Creates multiple entitlements with different priorities
- Coverage target: 85%+
- Test methods: 25+ (see test class for details)

---

### Key Test Scenarios

#### SLACalculationUtility Tests

**1. Basic SLA Calculation**:
```apex
@isTest
static void testSetServiceDate_WithEntitlement() {
    // Given: Case with entitlement
    List<Case> cases = [SELECT Id FROM Case LIMIT 1];

    Test.startTest();
    SLACalculationUtility.setServiceDate(cases);
    Test.stopTest();

    // Then: SLA dates calculated
    Case c = [SELECT Service_Date__c, SLA_Service_Date_Time__c FROM Case WHERE Id = :cases[0].Id];
    System.assertNotEquals(null, c.Service_Date__c);
    System.assertNotEquals(null, c.SLA_Service_Date_Time__c);
}
```

**2. Business Hours Adjustment**:
```apex
@isTest
static void testSetServiceDate_AdjustsForWeekend() {
    // Given: Case created on Friday, 1-day entitlement
    // (Test data setup ensures this scenario)

    Test.startTest();
    SLACalculationUtility.setServiceDate(cases);
    Test.stopTest();

    // Then: Service date is Monday (not Saturday)
    Case c = [SELECT Service_Date__c FROM Case WHERE Id = :cases[0].Id];
    String dayOfWeek = c.Service_Date__c.format('E');
    System.assertNotEquals('Sat', dayOfWeek);
    System.assertNotEquals('Sun', dayOfWeek);
}
```

**3. Fallback Logic**:
```apex
@isTest
static void testSetServiceDate_FallbackWhenNoEntitlement() {
    // Given: Case with null EntitlementId
    Case c = new Case(Subject = 'Test', Status = 'New', Location__c = locationId);
    insert c;

    Test.startTest();
    SLACalculationUtility.setServiceDate(new List<Case>{ c });
    Test.stopTest();

    // Then: Fallback applied (tomorrow at 11:59 PM)
    c = [SELECT Service_Date__c, SLA_Service_Date_Time__c FROM Case WHERE Id = :c.Id];
    System.assertEquals(System.today().addDays(1), c.Service_Date__c);
}
```

**4. WM Capacity Planner Mock**:
```apex
@isTest
static void testCapacityPlannerIntegration() {
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
```

---

#### Entitlement_Utility Tests

**1. Prioritization Logic**:
```apex
@isTest
static void testGetPrioritizedEntitlements_SelectsHighestPriority() {
    // Given: Multiple entitlements (high, medium, low priority)
    Set<Id> caseIds = new Set<Id>{ testCase.Id };

    Test.startTest();
    Map<String, Entitlement> result = Entitlement_Utility.getPrioritizedEntitlements(caseIds);
    Test.stopTest();

    // Then: High priority entitlement selected
    Entitlement selected = result.get(testCase.Id);
    System.assertEquals(highPriorityEntitlement.Id, selected.Id);
}
```

**2. Time Filtering**:
```apex
@isTest
static void testFilterEntitlementsByTime_BeforeCutoff() {
    // Given: Current time is 10 AM
    // Entitlement: Call_Time__c = "14:00", Before_After__c = "Before"

    // When
    Map<String, List<Entitlement>> result = Entitlement_Utility.filterEntitlementsByTime(...);

    // Then: Entitlement included (10 AM < 2 PM)
    System.assert(!result.get(caseId).isEmpty());
}
```

**3. Comparator Logic**:
```apex
@isTest
static void testCompositePriorityCompare() {
    // Given: Two prioritization results
    Entitlement_Utility.prioritizationResult p1 = new Entitlement_Utility.prioritizationResult();
    p1.priorityRank = 1;
    p1.customerRank = 3;

    Entitlement_Utility.prioritizationResult p2 = new Entitlement_Utility.prioritizationResult();
    p2.priorityRank = 2;
    p2.customerRank = 5;

    // When
    Entitlement_Utility.CompositePriorityCompare comparator = new Entitlement_Utility.CompositePriorityCompare();
    Integer result = comparator.compare(p1, p2);

    // Then: p1 wins (lower priority rank)
    System.assert(result < 0);
}
```

---

### Test Data Patterns

**Reusable Test Data Factory**:
```apex
@isTest
public class TestDataFactoryRefactored {

    public static Map<String, Object> createFullTestHierarchy() {
        // Create Accounts
        Account clientAccount = new Account(Name = 'Test Client');
        Account locationAccount = new Account(
            Name = 'Test Location',
            tz__UTC_Offset__c = -5.0,
            tz__Timezone_SFDC__c = 'America/New_York'
        );
        insert new List<Account>{ clientAccount, locationAccount };

        // Create Contact
        Contact contact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = clientAccount.Id
        );
        insert contact;

        // Create Product
        Product2 product = new Product2(
            Name = 'Test Product',
            Family = 'Commercial',
            IsActive = true
        );
        insert product;

        // Create Asset
        Asset asset = new Asset(
            Name = 'Test Asset',
            AccountId = clientAccount.Id,
            Product2Id = product.Id,
            Status = 'Installed'
        );
        insert asset;

        // Create Service Contract
        ServiceContract sc = new ServiceContract(
            Name = 'Test Contract',
            AccountId = clientAccount.Id,
            StartDate = Date.today().addDays(-30),
            EndDate = Date.today().addDays(365)
        );
        insert sc;

        // Create Entitlement
        Entitlement entitlement = new Entitlement(
            Name = 'Test Entitlement',
            AccountId = clientAccount.Id,
            ServiceContractId = sc.Id,
            StartDate = Date.today().addDays(-30),
            EndDate = Date.today().addDays(365),
            Status__c = 'Approved',
            Service_Guarantee_Category__c = 'Days',
            Service_Guarantee_Category_Value__c = 2
        );
        insert entitlement;

        return new Map<String, Object>{
            'clientAccount' => clientAccount,
            'locationAccount' => locationAccount,
            'contact' => contact,
            'product' => product,
            'asset' => asset,
            'serviceContract' => sc,
            'entitlement' => entitlement
        };
    }

    public static Case createCaseWithRelationships(Id clientId, Id locationId, Id contactId, Id assetId, String recordTypeName) {
        RecordType rt = [SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = :recordTypeName LIMIT 1];

        return new Case(
            Subject = 'Test Case',
            Status = 'New',
            Client__c = clientId,
            Location__c = locationId,
            ContactId = contactId,
            AssetId = assetId,
            RecordTypeId = rt.Id,
            Case_Type__c = 'New Service',
            Case_Sub_Type__c = 'Roll Off Delivery'
        );
    }
}
```

---

## Deployment and Configuration

### Deployment Checklist

**Pre-Deployment**:
- [ ] Run all test classes in sandbox (85%+ coverage required)
- [ ] Validate no existing automations conflict
- [ ] Review custom metadata configuration
- [ ] Ensure Business Hours configured
- [ ] Test WM Capacity Planner connectivity (if applicable)

**Deployment Package**:
- [ ] SLACalculationUtility.cls
- [ ] SLACalculationUtility.cls-meta.xml
- [ ] SLACalculationUtilityTest.cls
- [ ] SLACalculationUtilityTest.cls-meta.xml
- [ ] Entitlement_Utility.cls
- [ ] Entitlement_Utility.cls-meta.xml
- [ ] Entitlement_UtilityTest.cls
- [ ] Entitlement_UtilityTest.cls-meta.xml
- [ ] Entitlement_Field_Mapping__mdt (metadata records)
- [ ] Integration_Request_URLs__mdt (metadata records)
- [ ] Custom fields (Case, Entitlement, Account)
- [ ] Triggers (CaseTrigger, if new)

**Post-Deployment**:
- [ ] Run smoke tests in production
- [ ] Monitor debug logs for first 24 hours
- [ ] Validate entitlements being assigned correctly
- [ ] Check SLA dates calculated accurately
- [ ] Review error logs for fallback scenarios

---

### Metadata Configuration

#### Entitlement_Field_Mapping__mdt

**Sample Records**:

| Label | Priority_Value__c | Case__c | Entitlement__c | Quote__c |
|-------|------------------|---------|----------------|----------|
| Account Name | 0A | Client__c | AccountId | Customer__c |
| Location | 0B | Location__c | Location__c | Location__c |
| Location Region | 1A | Location__r.Region__c | Region__c | Location__r.Region__c |
| Material Type | 2A | Material_Type__c | Material_Type__c | Product__c |
| Service Type | 2B | Case_Sub_Type__c | Service__c | Service_Type__c |
| Container Size | 2C | Asset__r.Product2.Size__c | Container_Size__c | Size__c |
| Request Type | 3A | Case_Type__c | Request_Type__c | Request_Type__c |
| Case Reason | 3B | Case_Reason__c | Case_Reason__c | Quote_Reason__c |
| Call Time | 4A | (calculated) | Call_Time__c | (calculated) |

**Priority Prefix Guidelines**:
- `0x`: Customer identification (Account, top-level location)
- `1x`: Location details (region, territory, sub-location)
- `2x`: Service identification (material, service type, equipment)
- `3x`: Transaction type (request type, reason)
- `4x`: Timing (call time, SLA override)

---

#### Integration_Request_URLs__mdt

**Site_Capacity Record**:

| Field | Value |
|-------|-------|
| DeveloperName | Site_Capacity |
| MasterLabel | WM Capacity Planner |
| End_Point__c | https://api.wm.com/v1/servicelines/{ServiceBaselineId}/capacity |
| Client_Key__c | (encrypted partner key) |
| Client_Token__c | (encrypted auth token) |
| Content_Type__c | application/json |
| Method__c | GET |
| Timeout__c | 10000 |

---

### Initial Data Setup

**Create Default Industry Standard Entitlements**:
```apex
// Script to create baseline entitlements
List<Entitlement> industryStandards = new List<Entitlement>();

// Same Day Service
industryStandards.add(new Entitlement(
    Name = 'Industry Standard - Same Day',
    StartDate = Date.today().addYears(-1),
    EndDate = Date.today().addYears(10),
    Status__c = 'Approved',
    RecordTypeId = industryStandardRT,
    Service_Guarantee_Category__c = 'Days',
    Service_Guarantee_Category_Value__c = 0,
    Request_Type__c = 'Pickup',
    Service__c = 'On-Call Pick'
));

// Next Day Service
industryStandards.add(new Entitlement(
    Name = 'Industry Standard - Next Day',
    StartDate = Date.today().addYears(-1),
    EndDate = Date.today().addYears(10),
    Status__c = 'Approved',
    RecordTypeId = industryStandardRT,
    Service_Guarantee_Category__c = 'Days',
    Service_Guarantee_Category_Value__c = 1,
    Request_Type__c = 'New Service',
    Call_Time__c = '14:00',
    Before_After__c = 'Before'
));

// 2-Day Service
industryStandards.add(new Entitlement(
    Name = 'Industry Standard - 2 Day',
    StartDate = Date.today().addYears(-1),
    EndDate = Date.today().addYears(10),
    Status__c = 'Approved',
    RecordTypeId = industryStandardRT,
    Service_Guarantee_Category__c = 'Days',
    Service_Guarantee_Category_Value__c = 2
));

insert industryStandards;
```

---

## Troubleshooting Reference

### Diagnostic Queries

**Find Cases with No Entitlement**:
```sql
SELECT Id, CaseNumber, CreatedDate, Client__c, Location__c, Status
FROM Case
WHERE EntitlementId = null
AND CreatedDate = TODAY
ORDER BY CreatedDate DESC
```

**Find Cases with Past SLA Dates**:
```sql
SELECT Id, CaseNumber, SLA_Service_Date_Time__c, Status
FROM Case
WHERE SLA_Service_Date_Time__c < NOW()
AND IsClosed = false
ORDER BY SLA_Service_Date_Time__c ASC
```

**Find Expiring Entitlements**:
```sql
SELECT Id, Name, AccountId, EndDate, Status__c
FROM Entitlement
WHERE EndDate <= NEXT_N_DAYS:30
AND Status__c = 'Approved'
ORDER BY EndDate ASC
```

**Check Entitlement Time Filters**:
```sql
SELECT Id, Name, Call_On__c, Call_Time__c, Before_After__c
FROM Entitlement
WHERE AccountId = :accountId
AND Status__c = 'Approved'
```

---

### Debug Log Analysis

**Enable Debug Logs**:
1. Setup → Debug Logs
2. User-Based Trace Flag
3. Set levels:
   - Apex Code: FINEST
   - Database: FINE
   - Workflow: INFO

**Key Debug Statements to Look For**:

**From SLACalculationUtility**:
```
'START setServiceDate, total cases = X'
'Default Business Hours = XXX'
'caseAccountMap size = X'
'Calling CaseEntitlement.populateEntitlement...'
'Case XXX initial EntitlementId = YYY'
'Total entitlementIds = {...}'
'Processing Case XXX SLA_Service_Date_Time__c = ...'
'ERROR: EntitlementId is null for case XXX'
'Calculated daysDelta = X for Entitlement YYY'
'beforeCutoff result = true/false'
'SLADate-Time = ...'
'Not within business hours, bumping date by 1'
'Final SLA_Service_Date__c = ...'
'EXCEPTION for Case XXX => ...'
'FALLBACK applied: Service_Date__c = ...'
```

**From Entitlement_Utility**:
```
'In getCommonEntitlementData():: '
'caseIdSet:: {...}'
'priorityFieldsMap:: {...}'
'In getPrioritizedEntitlements()'
'priorityFieldList::: {...}'
'allEntitlementsMap::: {...}'
'prioritizedMap::: {...}'
'In filterEntitlementsByTime::: '
'SKIPPED: Id Already added - '
'SKIPPED: Day does not match - ...'
'SKIPPED: Missing required fields'
'SKIPPED: Time does not match - ...'
'ADDED ENTITLEMENT: ... (Total now: X)'
```

---

### Common Issues and Resolutions

**Issue**: "No entitlement assigned to case"
- **Check**: Case has Client__c and Location__c populated
- **Check**: Entitlements exist for that account
- **Check**: Entitlements are approved and not expired
- **Check**: Call_On__c includes current day of week
- **Fix**: Create appropriate entitlement or industry standard

**Issue**: "SLA date is in the past"
- **Check**: Business Hours calendar is correct
- **Check**: Holidays configured properly
- **Check**: Entitlement SLA value is reasonable
- **Fix**: Recalculate SLA using `setServiceDate()`

**Issue**: "Capacity Planner not being called"
- **Check**: Product Family = 'Rolloff'
- **Check**: Vendor Parent_ID = '8'
- **Check**: SBID exists on asset
- **Check**: Entitlement is NOT Gold Standard or Contractual
- **Fix**: Verify asset hierarchy and vendor configuration

**Issue**: "Too many SOQL queries"
- **Check**: Batch size being processed
- **Check**: Not calling utility methods inside loops
- **Fix**: Process in smaller batches (< 200 records)

---

## Appendices

### Appendix A: Field API Reference

**Case Fields**:
- `Client__c` - Lookup(Account)
- `Location__c` - Lookup(Account)
- `Case_Type__c` - Picklist
- `Case_Sub_Type__c` - Picklist
- `Case_Reason__c` - Picklist
- `AssetId` - Lookup(Asset)
- `EntitlementId` - Lookup(Entitlement)
- `Service_Date__c` - Date
- `SLA_Service_Date__c` - Date
- `SLA_Service_Date_Time__c` - DateTime
- `SlaStartDate` - DateTime
- `Check_Case__c` - Checkbox

**Entitlement Fields**:
- `Service_Guarantee_Category__c` - Picklist (Hours, Days)
- `Service_Guarantee_Category_Value__c` - Number
- `Call_Time__c` - Text (HH:MM format)
- `Before_After__c` - Picklist (Before, After)
- `Call_On__c` - Text (Mon,Tue,Wed,Thu,Fri,Sat,Sun)
- `Override_Business_Hours__c` - Checkbox
- `Gold_Standard__c` - Checkbox
- `Contractual__c` - Checkbox
- `Status__c` - Picklist (Approved, Pending, Rejected)

**Account Fields** (Location):
- `tz__UTC_Offset__c` - Number (Decimal)
- `tz__Timezone_SFDC__c` - Text

---

### Appendix B: Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-22 | Development Team | Initial comprehensive technical specification |

---

**End of Document**
