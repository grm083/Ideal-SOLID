# SLA & Entitlement Utility - Quick Reference Guide

## Document Info
**Version**: 1.0 | **Date**: 2025-11-22 | **Purpose**: Knowledge Transfer & Quick Reference

---

## 🎯 Purpose at a Glance

| What | Why | Outcome |
|------|-----|---------|
| **Entitlement_Utility** finds the right service agreement for a customer | Customers have different SLA levels based on contracts | Cases get assigned the correct entitlement |
| **SLACalculationUtility** calculates when service is due | SLA dates ensure timely customer service | Cases have accurate service dates and deadlines |

---

## 📋 Quick Decision Tree

```
New Case Created
    │
    ├─ Does case have Client + Location?
    │   ├─ NO  → Cannot proceed (validation required)
    │   └─ YES → Continue
    │
    ├─ Find Entitlement (Entitlement_Utility)
    │   ├─ Customer-specific entitlement exists? → Use it
    │   ├─ Only industry standard exists? → Use it
    │   └─ Multiple exist? → Use highest priority
    │
    └─ Calculate SLA Date (SLACalculationUtility)
        ├─ Is it Gold/Contractual/Commercial? → Use entitlement SLA
        ├─ Is it Rolloff + WM vendor? → Check capacity planner
        │   ├─ API has dates? → Use those
        │   └─ API fails? → Fall back to entitlement
        └─ Set Service_Date__c and SLA_Service_Date_Time__c
```

---

## 🔧 Entitlement_Utility - Key Methods

### Primary Methods

| Method | Use When | Returns | Example |
|--------|----------|---------|---------|
| `getPrioritizedEntitlements(Set<Id>)` | You need THE ONE best entitlement | `Map<Id, Entitlement>` | `Entitlement ent = result.get(caseId);` |
| `getRelevantEntitlements(Set<Id>)` | You want to see ALL options | `Map<Id, Map<Type, List<Entitlement>>>` | Display dropdown of choices |
| `getIndustryStandardSLA(Case)` | Fallback when no customer entitlement | `List<Entitlement>` | Generic SLA for case type |

### How Prioritization Works

**Priority Ranks** (0 = best, 7 = worst):

| Rank | What Matched | Example Scenario |
|------|--------------|------------------|
| **0** | Customer + Service + Transaction | Specific customer, specific service, specific timing → MOST SPECIFIC |
| **1** | Customer + Service | Specific customer, specific service, any time |
| **2** | Customer + Transaction | Specific customer, specific timing, any service |
| **3** | Customer Only | Specific customer, generic service/timing |
| **4** | Service + Transaction | Specific service, specific timing, any customer |
| **5** | Service Only | Specific service, any customer/timing |
| **6** | Transaction Only | Specific timing, any customer/service |
| **7** | Nothing | Industry standard / default → LEAST SPECIFIC |

**Tie-Breaker**: If same rank, compare how many fields matched (more = better)

---

## 🔧 SLACalculationUtility - Key Methods

### Primary Methods

| Method | Use When | DML? | Trigger-Safe? |
|--------|----------|------|---------------|
| `setServiceDate(List<Case>)` | Flow, Process Builder, After Trigger | ✅ YES | ❌ NO |
| `calculateAndSetSLAFields(List<Case>, Map<Id,Account>)` | **Before Trigger** (recommended) | ❌ NO | ✅ YES |
| `calculateServiceDateWithCapacity(...)` | Manual calculation, need detailed results | ❌ NO | ✅ YES |

### Helper Methods (Common Usage)

| Method | Purpose | Example |
|--------|---------|---------|
| `buildCaseLocationMap(List<Case>)` | Get location timezones | `Map<Case, Account> map = ...` |
| `getDaysDelta(Entitlement)` | Convert SLA value to days | `2 Days → 2`, `48 Hours → 2` |
| `isBeforeCutoff(Case, Account, Integer)` | Check if before 2 PM local time | `isBeforeCutoff(c, acc, 14)` |
| `requiresSLAandServiceDateReset(New, Old)` | Check if recalc needed | Use in Before Update trigger |

---

## ⚙️ How They Work Together

### Typical Flow (Before Insert Trigger)

```
STEP 1: Get Entitlement
   caseIds = Set<Id>{ ... }
   entitlements = Entitlement_Utility.getPrioritizedEntitlements(caseIds)

STEP 2: Assign to Case
   for each case:
       case.EntitlementId = entitlements.get(case.Id)

STEP 3: Calculate SLA
   locationMap = buildLocationMap(cases)
   SLACalculationUtility.calculateAndSetSLAFields(cases, locationMap)

STEP 4: Trigger Framework Inserts (DML)
```

---

## 📊 Field Reference

### Case Fields (Required)

| Field | Type | Purpose |
|-------|------|---------|
| `Client__c` | Lookup(Account) | Who the customer is |
| `Location__c` | Lookup(Account) | Where service happens (timezone!) |
| `Case_Type__c` | Picklist | Pickup, New Service, etc. |
| `Case_Sub_Type__c` | Picklist | Specific service type |
| `EntitlementId` | Lookup | **Set by Entitlement_Utility** |
| `Service_Date__c` | Date | **Set by SLACalculationUtility** |
| `SLA_Service_Date_Time__c` | DateTime | **Set by SLACalculationUtility** |

### Entitlement Fields (Key Ones)

| Field | Values | What It Does |
|-------|--------|--------------|
| `AccountId` | Account ID or NULL | NULL = industry standard, ID = customer-specific |
| `Service_Guarantee_Category__c` | Hours, Days | How SLA is measured |
| `Service_Guarantee_Category_Value__c` | Number | 1 Day, 2 Days, 24 Hours, etc. |
| `Call_Time__c` | HH:MM (e.g., "14:00") | Cutoff time for same-day service |
| `Before_After__c` | Before, After | Before 2 PM or After 2 PM? |
| `Call_On__c` | "Mon,Tue,Wed" | Which days of week |
| `Gold_Standard__c` | Checkbox | Premium service level |
| `Contractual__c` | Checkbox | Contractual SLA (not capacity-based) |
| `Override_Business_Hours__c` | Checkbox | Can service on weekends/holidays |

### Account Fields (Location)

| Field | Example | Purpose |
|-------|---------|---------|
| `tz__UTC_Offset__c` | -5.0 | Hours from UTC (EST = -5) |
| `tz__Timezone_SFDC__c` | "America/New_York" | Salesforce timezone ID |

---

## 🚀 Common Code Patterns

### Pattern 1: Before Insert (RECOMMENDED)

```apex
// CaseTrigger
trigger CaseTrigger on Case (before insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        CaseHandler.handleBeforeInsert(Trigger.new);
    }
}

// CaseHandler
public static void handleBeforeInsert(List<Case> newCases) {
    // 1. Get entitlements
    Set<Id> caseIds = new Map<Id, Case>(newCases).keySet();
    Map<String, Entitlement> ents =
        Entitlement_Utility.getPrioritizedEntitlements(caseIds);

    // 2. Assign EntitlementId
    for (Case c : newCases) {
        if (ents.get(c.Id) != null) {
            c.EntitlementId = ents.get(c.Id).Id;
        }
    }

    // 3. Calculate SLA (NO DML)
    Map<Id, Account> locationMap = buildLocationMap(newCases);
    SLACalculationUtility.calculateAndSetSLAFields(newCases, locationMap);

    // Trigger framework handles insert
}
```

### Pattern 2: After Update (Recalculation)

```apex
trigger CaseTrigger on Case (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        CaseHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}

public static void handleAfterUpdate(List<Case> newCases, Map<Id,Case> oldMap) {
    List<Case> needsRecalc = new List<Case>();

    for (Case c : newCases) {
        // Check if critical fields changed
        if (SLACalculationUtility.requiresSLAandServiceDateReset(c, oldMap.get(c.Id))) {
            c.EntitlementId = null;
            c.SLA_Service_Date_Time__c = null;
            needsRecalc.add(c);
        }
    }

    if (!needsRecalc.isEmpty()) {
        // This method includes DML (safe in after trigger)
        SLACalculationUtility.setServiceDate(needsRecalc);
    }
}
```

### Pattern 3: Lightning Component

```apex
@AuraEnabled
public static EntitlementInfo getEntitlementInfo(Id caseId) {
    Set<Id> ids = new Set<Id>{ caseId };

    // Get recommended entitlement
    Map<String, Entitlement> prioritized =
        Entitlement_Utility.getPrioritizedEntitlements(ids);

    // Get all options for dropdown
    Map<String, Map<String, List<Entitlement>>> all =
        Entitlement_Utility.getRelevantEntitlements(ids);

    EntitlementInfo info = new EntitlementInfo();
    info.recommended = prioritized.get(caseId);
    info.allOptions = all.get(caseId);
    return info;
}
```

---

## 🔍 Troubleshooting Checklist

### ❌ Problem: Case has no EntitlementId

**Check**:
- [ ] Does case have `Client__c` populated?
- [ ] Does case have `Location__c` populated?
- [ ] Are there entitlements for this account?
- [ ] Are entitlements approved and not expired?
- [ ] Does current day match `Call_On__c`? (Mon/Tue/Wed/etc.)
- [ ] Does current time match `Call_Time__c` and `Before_After__c`?

**Query to Check**:
```sql
SELECT Id, Name, AccountId, Call_On__c, Call_Time__c, Before_After__c
FROM Entitlement
WHERE AccountId = '001...'
AND Status__c = 'Approved'
AND StartDate <= TODAY
AND EndDate >= TODAY
```

---

### ❌ Problem: SLA Date is Wrong or in the Past

**Check**:
- [ ] Is `Service_Guarantee_Category_Value__c` correct?
- [ ] Is Business Hours calendar configured?
- [ ] Are holidays added to Business Hours?
- [ ] Is location timezone (`tz__UTC_Offset__c`) correct?
- [ ] Is `Override_Business_Hours__c` set unexpectedly?

**Debug**:
```apex
Entitlement e = [SELECT Service_Guarantee_Category__c,
                        Service_Guarantee_Category_Value__c
                 FROM Entitlement WHERE Id = :entId];
Integer days = SLACalculationUtility.getDaysDelta(e);
System.debug('SLA Days: ' + days);
System.debug('Created Date: ' + caseRecord.CreatedDate);
System.debug('Expected SLA: ' + caseRecord.CreatedDate.addDays(days));
```

---

### ❌ Problem: Capacity Planner Not Being Called

**Check**:
- [ ] Is `ProductFamily = 'Rolloff'`? (case-sensitive!)
- [ ] Is `Parent_Vendor_ID__c = '8'`? (WM vendor)
- [ ] Does SBID exist on asset service details?
- [ ] Is entitlement Gold Standard? (overrides capacity check)
- [ ] Is entitlement Contractual? (overrides capacity check)

**Query to Verify**:
```sql
SELECT Id, ProductFamily,
       (SELECT SBID_Text_c__c, Supplier__r.Parent_Vendor_ID__c
        FROM Assets_Parent__r
        WHERE Is_Self_Service__c = true)
FROM Asset
WHERE Id = :assetId
```

---

## 📈 Performance Tips

### DO ✅

- **Process in batches** (≤ 200 records per call)
- **Query locations once** before calling SLA calculation
- **Use Before Trigger** for insert/update when possible (no extra DML)
- **Cache entitlements** if processing multiple times in same transaction

### DON'T ❌

- ❌ Call methods inside loops
- ❌ Query entitlements repeatedly
- ❌ Process more than 200 records at once (SOQL limits)
- ❌ Use in synchronous context with 100+ WM API callouts

---

## 🧪 Testing Quick Guide

### Test Data Setup

```apex
// Minimal test data
Account clientAcct = new Account(Name = 'Test Client');
Account locationAcct = new Account(
    Name = 'Test Location',
    tz__UTC_Offset__c = -5.0,
    tz__Timezone_SFDC__c = 'America/New_York'
);
insert new List<Account>{ clientAcct, locationAcct };

ServiceContract sc = new ServiceContract(
    Name = 'Test Contract',
    AccountId = clientAcct.Id,
    StartDate = Date.today().addDays(-30),
    EndDate = Date.today().addDays(365)
);
insert sc;

Entitlement ent = new Entitlement(
    Name = 'Test Entitlement',
    AccountId = clientAcct.Id,
    ServiceContractId = sc.Id,
    StartDate = Date.today().addDays(-30),
    EndDate = Date.today().addDays(365),
    Status__c = 'Approved',
    Service_Guarantee_Category__c = 'Days',
    Service_Guarantee_Category_Value__c = 2
);
insert ent;
```

### Mock WM API

```apex
@isTest
static void testCapacityAPI() {
    Test.setMock(HttpCalloutMock.class, new CapacityMock());

    List<String> dates = SLACalculationUtility.callWMCapacityPlannerAPI('TEST123');
    System.assert(!dates.isEmpty());
}

class CapacityMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"Data":{"Site":{"Capacity":[{"AvailableDates":["2024/12/15"]}]}}}');
        return res;
    }
}
```

---

## 📝 Configuration Checklist

### Initial Setup

- [ ] **Custom Metadata**: Create `Entitlement_Field_Mapping__mdt` records
  - Priority levels: 0A, 0B (customer), 2A, 2B (service), 3A, 3B (transaction)
  - Map Case fields to Entitlement fields

- [ ] **Entitlements**: Create baseline entitlements
  - Industry Standard (AccountId = null)
  - Customer-specific entitlements
  - Set StartDate/EndDate ranges (far future for standards)

- [ ] **Business Hours**: Configure calendar
  - Set working days (usually Mon-Fri)
  - Add holidays

- [ ] **Location Timezones**: Populate Account fields
  - `tz__UTC_Offset__c` (decimal, e.g., -5.0 for EST)
  - `tz__Timezone_SFDC__c` (e.g., "America/New_York")

- [ ] **WM API** (if using capacity planner):
  - Create `Integration_Request_URLs__mdt` record (DeveloperName = 'Site_Capacity')
  - Set endpoint, auth headers, timeout

### Monitoring

- [ ] **Weekly**: Check for cases without entitlement
  ```sql
  SELECT Id, CaseNumber FROM Case
  WHERE EntitlementId = null AND CreatedDate = THIS_WEEK
  ```

- [ ] **Daily**: Check for past SLA dates
  ```sql
  SELECT Id, CaseNumber, SLA_Service_Date_Time__c FROM Case
  WHERE SLA_Service_Date_Time__c < NOW() AND IsClosed = false
  ```

- [ ] **Monthly**: Check expiring entitlements
  ```sql
  SELECT Id, Name, EndDate FROM Entitlement
  WHERE EndDate <= NEXT_N_DAYS:30 AND Status__c = 'Approved'
  ```

---

## 💡 Key Takeaways

| Concept | Remember This |
|---------|---------------|
| **Entitlement Priority** | More specific = higher priority. Customer+Service+Transaction beats all. |
| **SLA Calculation** | CreatedDate + Days Delta, adjusted for business hours and timezone. |
| **Trigger Timing** | **Before Insert** = best (no extra DML). After Update = recalculation with DML. |
| **Fallback Logic** | If anything fails → Tomorrow at 11:59 PM (adjusted for business hours). |
| **WM Capacity** | Only for Rolloff + WM vendor. Gold Standard/Contractual bypass it. |
| **Time Filtering** | `Call_On__c`, `Call_Time__c`, `Before_After__c` filter by day and time. |
| **NULL = Wildcard** | NULL entitlement fields match anything (less specific). |

---

## 📞 Quick Help

| If You Need To... | Use This |
|-------------------|----------|
| Find the best entitlement for a case | `Entitlement_Utility.getPrioritizedEntitlements(caseIds)` |
| Calculate SLA date in a trigger | `SLACalculationUtility.calculateAndSetSLAFields(cases, locationMap)` |
| Recalculate SLA after field change | `SLACalculationUtility.setServiceDate(cases)` |
| Check if recalc is needed | `SLACalculationUtility.requiresSLAandServiceDateReset(newCase, oldCase)` |
| Get capacity planner dates | `SLACalculationUtility.callWMCapacityPlannerAPI(sbid)` |
| Debug entitlement selection | Enable Apex FINEST logs, search for "priorityRank" and "Selected Entitlement" |

---

## 🔗 Related Documentation

- **Full Technical Spec**: `SLA_Entitlement_Technical_Specification.md` (detailed algorithms and all methods)
- **Data Flow Diagram**: `SLA_Entitlement_Data_Flow_Diagram.md` (visual architecture)
- **Developer Guide**: `Entitlement_and_SLA_Service_Layer_Guide.md` (comprehensive integration patterns)

---

**Document Version**: 1.0 | **Last Updated**: 2025-11-22 | **Maintained By**: Development Team
