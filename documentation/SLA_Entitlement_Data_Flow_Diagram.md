# SLA & Entitlement Data Flow Diagrams

## Document Info
**Version**: 1.0 | **Date**: 2025-11-22 | **Purpose**: Visual Data Flow Reference

---

## Table of Contents

1. [High-Level System Architecture](#high-level-system-architecture)
2. [Entitlement Resolution Flow](#entitlement-resolution-flow)
3. [SLA Calculation Flow](#sla-calculation-flow)
4. [Complete Case Processing Flow](#complete-case-processing-flow)
5. [WM Capacity Planner Integration Flow](#wm-capacity-planner-integration-flow)
6. [Data Model Relationships](#data-model-relationships)
7. [Decision Trees](#decision-trees)
8. [Sequence Diagrams](#sequence-diagrams)

---

## High-Level System Architecture

### 4-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PRESENTATION LAYER                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  ┌───────────┐ │
│  │  Lightning Web │  │  Aura          │  │  Process       │  │  REST API │ │
│  │  Components    │  │  Components    │  │  Builder/Flow  │  │           │ │
│  └────────┬───────┘  └────────┬───────┘  └────────┬───────┘  └─────┬─────┘ │
└───────────┼──────────────────┼──────────────────┼────────────────┼───────┘
            │                  │                  │                │
            ▼                  ▼                  ▼                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      AUTOMATION LAYER (Triggers)                            │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                         Case Trigger                                 │   │
│  │  ┌──────────────────┐         ┌──────────────────┐                  │   │
│  │  │  Before Insert   │         │  After Update    │                  │   │
│  │  │  Before Update   │         │  (Recalculation) │                  │   │
│  │  └────────┬─────────┘         └────────┬─────────┘                  │   │
│  └───────────┼──────────────────────────┼─────────────────────────────┘   │
└─────────────┼──────────────────────────┼───────────────────────────────────┘
              │                          │
              ▼                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SERVICE LAYER                                        │
│  ┌────────────────────────────────────┐  ┌───────────────────────────────┐ │
│  │    Entitlement_Utility             │  │  SLACalculationUtility        │ │
│  │  • getPrioritizedEntitlements()    │  │  • setServiceDate()           │ │
│  │  • getRelevantEntitlements()       │  │  • calculateAndSetSLAFields() │ │
│  │  • prioritizeEntitlements()        │  │  • getDaysDelta()             │ │
│  │  • filterEntitlementsByTime()      │  │  • isBeforeCutoff()           │ │
│  └────────────┬───────────────────────┘  └───────┬───────────────────────┘ │
└───────────────┼──────────────────────────────────┼───────────────────────────┘
                │                                  │
                │ Queries Metadata                 │ Queries Objects
                │                                  │
                ▼                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DATA & CONFIGURATION LAYER                           │
│  ┌──────────────────────┐  ┌──────────────────┐  ┌──────────────────────┐  │
│  │  Custom Metadata     │  │  Standard        │  │  Custom Objects      │  │
│  │  • Entitlement Field │  │  Objects         │  │  • Case              │  │
│  │    Mapping           │  │  • Entitlement   │  │  • Account           │  │
│  │  • Integration URLs  │  │  • BusinessHours │  │  • Asset             │  │
│  └──────────────────────┘  └──────────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ HTTP Callouts
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        EXTERNAL SYSTEMS                                     │
│  ┌────────────────────────────────────────────────────────────┐             │
│  │           WM Capacity Planner API                          │             │
│  │  GET /servicelines/{SBID}/capacity?serviceDate=YYYY-MM-DD │             │
│  └────────────────────────────────────────────────────────────┘             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Entitlement Resolution Flow

### Step-by-Step Data Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ INPUT: Set<Id> targetRecords (Case IDs or Quote IDs)                        │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 1: Determine Record Type                                               │
│  • Inspect Id prefix                                                         │
│  • Separate Case IDs from Quote IDs                                         │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ├─────────────────────┬────────────────────────────┐
             ▼                     ▼                            ▼
┌─────────────────────┐  ┌─────────────────────┐   ┌─────────────────────┐
│ For Case IDs:       │  │ For Quote IDs:      │   │ Collect Metadata    │
│ Query Case records  │  │ Call Quote          │   │ Query Entitlement   │
│ with dynamic fields │  │ Procurement         │   │ Field Mapping       │
│ from metadata       │  │ Controller          │   │ records             │
└─────────┬───────────┘  └──────────┬──────────┘   └──────────┬──────────┘
          │                         │                         │
          │                         │                         │
          └─────────────┬───────────┴─────────────────────────┘
                        ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 2: Build Priority Fields                                               │
│  For each record:                                                            │
│    For each metadata mapping:                                               │
│      priorityFields {                                                        │
│        recordId: "5001234..."                                               │
│        priorityLevel: "0A", "2B", etc.                                      │
│        commonName: "Account Name", "Service Type"                           │
│        entitlementField: "AccountId", "Service__c"                          │
│        objectValue: Actual value from record                                │
│      }                                                                       │
│                                                                              │
│  Also collect:                                                               │
│    • Set<Id> accountIds (from Client__c or Customer__c)                    │
│    • Date minimumServiceDate (earliest Service_Date__c)                    │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 3: Query Entitlements                                                  │
│  Dynamic Query:                                                              │
│    SELECT Id, {all fields from metadata Entitlement__c column}              │
│    FROM Entitlement                                                          │
│    WHERE AccountId IN :accountIds                                            │
│      AND StartDate <= :minimumServiceDate                                    │
│      AND Status__c = 'Approved'                                              │
│      AND Status != 'Expired'                                                 │
│    LIMIT 49999                                                               │
│                                                                              │
│  Result: 50-500 entitlement records (varies by account)                     │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 4: Filter by Time/Day                                                  │
│  For each entitlement:                                                       │
│    Check 1: Is today in Call_On__c?                                         │
│      • Get current day of week (Mon, Tue, Wed, etc.)                        │
│      • If Call_On__c populated and doesn't contain today → SKIP             │
│                                                                              │
│    Check 2: Is current time before/after Call_Time__c?                      │
│      • If Call_Time__c = "14:00", Before_After__c = "Before"                │
│      • If current hour >= 14 → SKIP                                          │
│                                                                              │
│    Check 3: Account matching                                                │
│      • If AccountId = null → INCLUDE (Industry Standard)                    │
│      • If AccountId = record's client → INCLUDE (Customer Specific)         │
│      • Otherwise → SKIP                                                      │
│                                                                              │
│  Result: Filtered list of entitlements per record                           │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 5: Prioritize Entitlements                                             │
│  For each record:                                                            │
│    For each filtered entitlement:                                           │
│                                                                              │
│      A. Match priority fields against entitlement fields                    │
│         customerScore = 0, serviceScore = 0, transactionScore = 0           │
│                                                                              │
│         For each priority field:                                            │
│           recordValue = record.Client__c (for example)                      │
│           entitlementValue = entitlement.AccountId                          │
│                                                                              │
│           If values match OR (recordValue != null AND entValue = null):     │
│             Determine category from priority prefix:                        │
│             • '0' or '1' → customerScore++                                  │
│             • '2' → serviceScore++                                          │
│             • '3' or '4' → transactionScore++                               │
│                                                                              │
│      B. Calculate priority rank based on match flags:                       │
│         • All 3 categories matched → Rank 0 (BEST)                          │
│         • Customer + Service → Rank 1                                       │
│         • Customer + Transaction → Rank 2                                   │
│         • Customer only → Rank 3                                            │
│         • Service + Transaction → Rank 4                                    │
│         • Service only → Rank 5                                             │
│         • Transaction only → Rank 6                                         │
│         • None matched → Rank 7 (WORST)                                     │
│                                                                              │
│      C. Create prioritizationResult {                                       │
│           entitlementRecord, priorityRank,                                  │
│           customerRank, serviceRank, transactionRank                        │
│         }                                                                    │
│                                                                              │
│    Sort results by:                                                          │
│      1. priorityRank (ascending)                                            │
│      2. customerRank (descending)                                           │
│      3. serviceRank (descending)                                            │
│      4. transactionRank (descending)                                        │
│                                                                              │
│    Select FIRST result = BEST entitlement                                   │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ OUTPUT: Map<RecordId, Entitlement>                                          │
│  Example:                                                                    │
│    "5001234..." → Entitlement{Id='7101234...', Name='Premium SLA'}          │
│    "5005678..." → Entitlement{Id='7105678...', Name='Standard SLA'}         │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## SLA Calculation Flow

### Basic SLA Calculation

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ INPUT:                                                                       │
│  • List<Case> cases (with EntitlementId populated)                          │
│  • Map<Id, Account> locationMap (optional)                                  │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 1: Setup & Queries                                                     │
│  Query 1: BusinessHours bh = [SELECT Id WHERE IsDefault=true]               │
│  Query 2: Build/use locationMap with timezone data                          │
│  Query 3: Collect EntitlementIds and query Entitlement details              │
│            SELECT Id, Service_Guarantee_Category__c,                         │
│                   Service_Guarantee_Category_Value__c,                       │
│                   Call_Time__c, Before_After__c,                             │
│                   Override_Business_Hours__c                                 │
│            FROM Entitlement WHERE Id IN :entitlementIds                      │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 2: For Each Case (only if SLA_Service_Date_Time__c is null)           │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 2A: Validate Entitlement                                               │
│  If EntitlementId = null → Throw NoEntitlementException                     │
│  If Entitlement not in map → Throw NoEntitlementException                   │
│  Else → Continue                                                             │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 2B: Calculate Days Delta                                               │
│  If Service_Guarantee_Category__c = 'Days':                                 │
│    daysDelta = FLOOR(Service_Guarantee_Category_Value__c)                   │
│    Example: 2.0 → 2 days                                                    │
│                                                                              │
│  Else (Assume 'Hours'):                                                     │
│    hours = Service_Guarantee_Category_Value__c                              │
│    daysDelta = FLOOR(hours / 24)                                            │
│    Example: 48 hours → 2 days                                               │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 2C: Check Cutoff Time                                                  │
│  If Call_Time__c AND Before_After__c are NULL:                              │
│    Use default cutoff of 14:00 (2 PM)                                       │
│    Get location local time (UTC + tz__UTC_Offset__c)                        │
│    beforeCutoff = (localTime.hour() < 14)                                   │
│  Else:                                                                       │
│    beforeCutoff = true (explicit time handling elsewhere)                   │
│                                                                              │
│  If NOT beforeCutoff:                                                        │
│    daysDelta = daysDelta + 1  (push to next day)                            │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 2D: Calculate Raw SLA DateTime                                         │
│  slaDateTime = case.CreatedDate.addDays(daysDelta)                          │
│  serviceDate = slaDateTime.date()                                           │
│                                                                              │
│  Example:                                                                    │
│    CreatedDate: 2024-12-15 10:00 AM                                         │
│    daysDelta: 2                                                             │
│    slaDateTime: 2024-12-17 10:00 AM                                         │
│    serviceDate: 2024-12-17                                                  │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 2E: Adjust for Business Hours                                          │
│  If NOT Override_Business_Hours__c:                                         │
│    WHILE NOT BusinessHours.isWithin(bh.Id, serviceDate):                    │
│      serviceDate = serviceDate.addDays(1)                                   │
│                                                                              │
│  Example:                                                                    │
│    Calculated: Saturday 12/16                                               │
│    BusinessHours check: false (weekend)                                     │
│    Bump to: Sunday 12/17                                                    │
│    BusinessHours check: false (weekend)                                     │
│    Bump to: Monday 12/18                                                    │
│    BusinessHours check: true ✓                                              │
│    Final: Monday 12/18                                                      │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 2F: Set Final Fields                                                   │
│  case.Service_Date__c = serviceDate                                         │
│  case.SLA_Service_Date__c = serviceDate                                     │
│  case.SLA_Service_Date_Time__c = slaDateTime                                │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ EXCEPTION HANDLING: If any exception in Steps 2A-2F                         │
│  Fallback Logic:                                                             │
│    service_Date__c = tomorrow                                               │
│    SLA_Service_Date_Time__c = tomorrow at 11:59 PM                          │
│                                                                              │
│    Adjust for business hours:                                               │
│      WHILE NOT BusinessHours.isWithin(bh.Id, serviceDate):                  │
│        serviceDate++                                                         │
│        Update SLA_Service_Date_Time__c accordingly                          │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 3: DML (if setServiceDate method)                                      │
│  update cases; (bulk update)                                                │
│                                                                              │
│  OR (if calculateAndSetSLAFields method)                                    │
│  return; (no DML, trigger handles it)                                       │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ OUTPUT:                                                                      │
│  Cases with populated:                                                       │
│    • Service_Date__c                                                         │
│    • SLA_Service_Date__c                                                     │
│    • SLA_Service_Date_Time__c                                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Complete Case Processing Flow

### Before Insert Trigger - Full Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ TRIGGER EVENT: Case Before Insert                                           │
│  Input: Trigger.new (List<Case>)                                            │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ PHASE 1: Entitlement Resolution                                             │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │ Extract Case IDs                                                   │     │
│  │  Set<Id> caseIds = new Map<Id,Case>(Trigger.new).keySet()        │     │
│  └────────────────────┬───────────────────────────────────────────────┘     │
│                       │                                                      │
│                       ▼                                                      │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │ Call Entitlement_Utility                                          │     │
│  │  Map<String,Entitlement> ents =                                   │     │
│  │    Entitlement_Utility.getPrioritizedEntitlements(caseIds)        │     │
│  │                                                                    │     │
│  │  Internally executes:                                             │     │
│  │    1. Query Cases with metadata-driven fields                     │     │
│  │    2. Build priority fields (0A, 2B, 3A, etc.)                    │     │
│  │    3. Query Entitlements for accounts                             │     │
│  │    4. Filter by time/day                                          │     │
│  │    5. Prioritize and rank (0-7)                                   │     │
│  │    6. Select best match                                           │     │
│  └────────────────────┬───────────────────────────────────────────────┘     │
│                       │                                                      │
│                       ▼                                                      │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │ Assign EntitlementId to Cases                                     │     │
│  │  for (Case c : Trigger.new) {                                     │     │
│  │    Entitlement ent = ents.get(c.Id);                              │     │
│  │    if (ent != null) {                                             │     │
│  │      c.EntitlementId = ent.Id;                                    │     │
│  │    }                                                               │     │
│  │  }                                                                 │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                              │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ PHASE 2: SLA Date Calculation                                               │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │ Build Location Map                                                 │     │
│  │  Map<Id,Account> locationMap = buildLocationMap(Trigger.new)      │     │
│  │                                                                    │     │
│  │  Query: SELECT Id, tz__UTC_Offset__c, tz__Timezone_SFDC__c       │     │
│  │         FROM Account WHERE Id IN :locationIds                     │     │
│  └────────────────────┬───────────────────────────────────────────────┘     │
│                       │                                                      │
│                       ▼                                                      │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │ Call SLACalculationUtility (NO DML version)                       │     │
│  │  SLACalculationUtility.calculateAndSetSLAFields(                  │     │
│  │    Trigger.new,                                                   │     │
│  │    locationMap                                                    │     │
│  │  )                                                                 │     │
│  │                                                                    │     │
│  │  Internally executes:                                             │     │
│  │    1. Query BusinessHours                                         │     │
│  │    2. Query Entitlements with SLA config                          │     │
│  │    3. For each case:                                              │     │
│  │       a. Calculate days delta from entitlement                    │     │
│  │       b. Check cutoff time                                        │     │
│  │       c. Add delta to CreatedDate                                 │     │
│  │       d. Adjust for business hours                                │     │
│  │       e. Set Service_Date__c, SLA_Service_Date_Time__c            │     │
│  │    4. NO DML (sets fields in-memory)                              │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                              │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ PHASE 3: Database Operation                                                 │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │ Trigger Framework Performs INSERT                                  │     │
│  │  • EntitlementId set                                               │     │
│  │  • Service_Date__c set                                             │     │
│  │  • SLA_Service_Date_Time__c set                                    │     │
│  │  • SLA_Service_Date__c set                                         │     │
│  │  • All other Case fields                                           │     │
│  │                                                                    │     │
│  │  Database performs single bulk insert                             │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                              │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ RESULT:                                                                      │
│  Cases created with:                                                         │
│    ✓ Correct entitlement assigned                                           │
│    ✓ Accurate SLA dates calculated                                          │
│    ✓ Business hours respected                                               │
│    ✓ Timezone adjustments applied                                           │
│                                                                              │
│  Performance:                                                                │
│    • SOQL Queries: ~6-8 total                                               │
│    • DML Operations: 1 (the insert)                                         │
│    • CPU Time: ~500-1000ms for 100 cases                                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## WM Capacity Planner Integration Flow

### Decision Flow for Capacity Planning

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ START: calculateServiceDateWithCapacity()                                    │
│  Input: Case, Asset, Entitlement, Location Account                          │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ DECISION 1: Should use entitlement-based calculation?                       │
│                                                                              │
│  Check A: Is entitlement.Gold_Standard__c = true?                           │
│            YES → Use Entitlement Calculation                                │
│            NO → Continue                                                     │
│                                                                              │
│  Check B: Is entitlement.Contractual__c = true?                             │
│            YES → Use Entitlement Calculation                                │
│            NO → Continue                                                     │
│                                                                              │
│  Check C: Is asset.ProductFamily = 'Commercial'?                            │
│            YES → Use Entitlement Calculation                                │
│            NO → Continue to Decision 2                                       │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ DECISION 2: Should use WM Capacity Planner?                                 │
│                                                                              │
│  Check A: Is asset.ProductFamily = 'Rolloff'?                               │
│            NO → Use Entitlement Calculation (fallback)                      │
│            YES → Continue                                                    │
│                                                                              │
│  Check B: Does asset have WM vendor?                                        │
│            Query service detail assets:                                      │
│              asset.Assets_Parent__r                                          │
│                WHERE Supplier__r.Parent_Vendor_ID__c = '8'                   │
│            NO matches → Use Entitlement Calculation                          │
│            YES → Continue                                                    │
│                                                                              │
│  Check C: Does SBID exist?                                                  │
│            Extract from: asset.Assets_Parent__r.SBID_Text_c__c              │
│            NULL or blank → Use Entitlement Calculation                       │
│            EXISTS → Continue to Capacity Planner API call                    │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ CAPACITY PLANNER API CALL                                                   │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │ STEP 1: Build HTTP Request                                        │     │
│  │  • Get Integration_Request_URLs__mdt (DeveloperName='Site_Capacity') │  │
│  │  • Endpoint: .../servicelines/{SBID}/capacity?serviceDate=YYYY-MM-DD │  │
│  │  • Headers: X-PARTNER-KEY, Authorization, X-USERID                 │     │
│  │  • Timeout: From metadata (typically 10000ms)                      │     │
│  └────────────────────┬───────────────────────────────────────────────┘     │
│                       │                                                      │
│                       ▼                                                      │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │ STEP 2: Execute HTTP Callout                                      │     │
│  │  HttpResponse res = http.send(req);                               │     │
│  │                                                                    │     │
│  │  Response JSON Structure:                                         │     │
│  │  {                                                                 │     │
│  │    "Data": {                                                       │     │
│  │      "Site": {                                                     │     │
│  │        "Capacity": [                                               │     │
│  │          {                                                         │     │
│  │            "LineOfBusiness": "Residential",                        │     │
│  │            "AvailableDates": [                                     │     │
│  │              "2024/12/15",                                         │     │
│  │              "2024/12/16",                                         │     │
│  │              "2024/12/17"                                          │     │
│  │            ]                                                       │     │
│  │          }                                                         │     │
│  │        ]                                                           │     │
│  │      }                                                             │     │
│  │    }                                                               │     │
│  │  }                                                                 │     │
│  └────────────────────┬───────────────────────────────────────────────┘     │
│                       │                                                      │
│                       ▼                                                      │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │ STEP 3: Parse Response                                            │     │
│  │  • Extract AvailableDates array                                   │     │
│  │  • Convert format: "2024/12/15" → "12/15/2024"                    │     │
│  │  • Parse to Date objects: Date.newInstance(2024, 12, 15)          │     │
│  │                                                                    │     │
│  │  Result: List<Date> plannerDates                                  │     │
│  └────────────────────┬───────────────────────────────────────────────┘     │
│                       │                                                      │
│                       ▼                                                      │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │ STEP 4: Check for Conflicts with Existing Work Orders            │     │
│  │  Query: SELECT Service_Date__c FROM WorkOrder                     │     │
│  │         WHERE AssetId = :assetId                                  │     │
│  │           AND Status IN ('Sent','Accepted',...)                   │     │
│  │           AND Service_Date__c >= TODAY                            │     │
│  │                                                                    │     │
│  │  Build Set<Date> existingWorkOrderDates                           │     │
│  └────────────────────┬───────────────────────────────────────────────┘     │
│                       │                                                      │
│                       ▼                                                      │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │ STEP 5: Select Optimal Date                                       │     │
│  │  For each plannerDate:                                            │     │
│  │    If plannerDate NOT IN existingWorkOrderDates:                  │     │
│  │      selectedDate = plannerDate                                   │     │
│  │      BREAK                                                         │     │
│  │                                                                    │     │
│  │  If all dates conflict:                                           │     │
│  │    selectedDate = last plannerDate                                │     │
│  │    Find next available date after conflicts                       │     │
│  └────────────────────┬───────────────────────────────────────────────┘     │
│                       │                                                      │
│                       ▼                                                      │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │ STEP 6: Build Result                                              │     │
│  │  ServiceDateCalculationResult {                                   │     │
│  │    serviceDate = selectedDate                                     │     │
│  │    slaServiceDateTime = DateTime at 9 PM                          │     │
│  │    calculationMethod = "Capacity Planner"                         │     │
│  │    availableDates = plannerDates (for UI display)                 │     │
│  │  }                                                                 │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                              │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ ERROR HANDLING                                                               │
│                                                                              │
│  IF API timeout OR HTTP error:                                              │
│    CATCH exception                                                           │
│    LOG error via UTIL_LoggingService                                         │
│    RETURN empty List<String>                                                 │
│                                                                              │
│  IF availableDates is empty:                                                 │
│    System.debug('No dates from API, falling back to entitlement')           │
│    RETURN calculateEntitlementBasedServiceDate(...)                          │
│                                                                              │
│  Result.calculationMethod = "Fallback - Entitlement"                         │
└────────────┬─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ FINAL RESULT                                                                 │
│  ServiceDateCalculationResult returned to caller                             │
│  Caller applies:                                                             │
│    case.Service_Date__c = result.serviceDate                                │
│    case.SLA_Service_Date_Time__c = result.slaServiceDateTime                │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Data Model Relationships

### Entity Relationship Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          CORE ENTITIES                                       │
└──────────────────────────────────────────────────────────────────────────────┘

              ┌─────────────────┐
              │     Account     │ (Client)
              │  ┌───────────┐  │
              │  │ Id        │  │
              │  │ Name      │  │
              │  └───────────┘  │
              └────────┬────────┘
                       │
                       │ Client__c (Lookup)
                       │
                       ▼
         ┌─────────────────────────────┐
         │          Case               │
         │  ┌───────────────────────┐  │
         │  │ Id                    │  │
         │  │ Client__c       ─────────────┐
         │  │ Location__c     ──────┐  │   │
         │  │ AssetId         ──┐   │  │   │
         │  │ EntitlementId   ─┐│   │  │   │
         │  │ Service_Date__c  ││   │  │   │
         │  │ SLA_Service...   ││   │  │   │
         │  │ Case_Type__c     ││   │  │   │
         │  │ Case_Sub_Type__c ││   │  │   │
         │  └───────────────────┘│   │  │   │
         └────────────────────────┼───┼──┼───┘
                                  │   │  │
          ┌───────────────────────┘   │  │
          │                           │  │
          ▼                           │  │
┌──────────────────┐                  │  │
│   Entitlement    │                  │  │
│  ┌────────────┐  │                  │  │
│  │ Id         │  │                  │  │
│  │ AccountId  │◄─────────────────────┼──┘
│  │ Service... │  │                  │
│  │ Call_Time  │  │                  │
│  │ Gold_Stan  │  │                  │
│  └────────────┘  │                  │
└──────────────────┘                  │
                                      │
                                      │
                  ┌───────────────────┘
                  │
                  ▼
        ┌──────────────────┐
        │      Asset       │ (Service Header)
        │  ┌────────────┐  │
        │  │ Id         │  │
        │  │ AccountId  │  │
        │  │ Product... │  │
        │  └────────────┘  │
        └────────┬─────────┘
                 │
                 │ Assets_Parent__r (Child Relationship)
                 │
                 ▼
    ┌─────────────────────────┐
    │  Asset (Service Detail) │
    │  ┌───────────────────┐  │
    │  │ SBID_Text_c__c    │  │
    │  │ Quantity__c       │  │
    │  │ Is_Self_Service   │  │
    │  │ Supplier__c ─────────────┐
    │  └───────────────────┘  │   │
    └─────────────────────────┘   │
                                  │
                                  ▼
                        ┌──────────────────┐
                        │     Supplier     │
                        │  ┌────────────┐  │
                        │  │ Id         │  │
                        │  │ Parent_... │  │
                        │  │ (= '8')    │  │
                        │  └────────────┘  │
                        └──────────────────┘


                 ┌─────────────────┐
                 │    Account      │ (Location)
                 │  ┌───────────┐  │
                 │  │ Id        │  │
                 │  │ tz__UTC.. │  │
                 │  │ tz__Time. │  │
                 │  └───────────┘  │
                 └────────▲────────┘
                          │
                          │ Location__c (Lookup from Case)
                          │
                          └───────────────┐
                                          │
┌──────────────────────────────────────────────────────────────────────────────┐
│                         CONFIGURATION ENTITIES                               │
└──────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────┐      ┌────────────────────────────────┐
│ Entitlement_Field_Mapping__mdt    │      │ Integration_Request_URLs__mdt  │
│  ┌─────────────────────────────┐  │      │  ┌──────────────────────────┐  │
│  │ MasterLabel                 │  │      │  │ DeveloperName            │  │
│  │ Priority_Value__c (0A, 2B)  │  │      │  │ End_Point__c             │  │
│  │ Case__c (Field API Name)    │  │      │  │ Client_Key__c            │  │
│  │ Entitlement__c (Field API)  │  │      │  │ Client_Token__c          │  │
│  │ Quote__c (Field API Name)   │  │      │  │ Method__c                │  │
│  └─────────────────────────────┘  │      │  │ Timeout__c               │  │
└───────────────────────────────────┘      │  └──────────────────────────┘  │
                                           └────────────────────────────────┘

┌───────────────────────────────────┐
│       BusinessHours (Standard)    │
│  ┌─────────────────────────────┐  │
│  │ Id                          │  │
│  │ IsDefault                   │  │
│  │ Working Hours by Day        │  │
│  │ Holiday Calendar            │  │
│  └─────────────────────────────┘  │
└───────────────────────────────────┘
```

---

## Decision Trees

### Entitlement Selection Decision Tree

```
                            ┌───────────────┐
                            │   New Case    │
                            └───────┬───────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │ Does case have Client +       │
                    │ Location populated?           │
                    └───────┬───────────────────┬───┘
                            │                   │
                          YES                  NO
                            │                   │
                            │                   ▼
                            │          ┌──────────────────┐
                            │          │ STOP - Cannot    │
                            │          │ process without  │
                            │          │ Client/Location  │
                            │          └──────────────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │ Query Entitlements   │
                 │ for Client Account   │
                 └──────────┬───────────┘
                            │
                ┌───────────┴────────────┐
                │ Filter by Date Range:  │
                │ StartDate <= today     │
                │ EndDate >= today       │
                └───────────┬────────────┘
                            │
                ┌───────────┴────────────┐
                │ Filter by Status:      │
                │ Status__c = 'Approved' │
                └───────────┬────────────┘
                            │
                ┌───────────┴────────────┐
                │ Filter by Day of Week: │
                │ Call_On__c contains    │
                │ current day?           │
                └───────────┬────────────┘
                            │
                ┌───────────┴────────────┐
                │ Filter by Time:        │
                │ Before/After Call_Time │
                └───────────┬────────────┘
                            │
            ┌───────────────┴───────────────┐
            │ How many entitlements remain? │
            └───┬───────────────────────┬───┘
                │                       │
              ZERO                   ONE OR MORE
                │                       │
                ▼                       ▼
    ┌───────────────────┐   ┌─────────────────────┐
    │ Use Industry      │   │ Prioritize by:      │
    │ Standard          │   │ 1. Match specificity│
    │ Entitlement       │   │    (Customer+Service│
    │ (if available)    │   │     +Transaction)   │
    │                   │   │ 2. Number of fields │
    │ OR apply fallback │   │    matched          │
    └───────────────────┘   └──────────┬──────────┘
                                       │
                                       ▼
                           ┌────────────────────┐
                           │ Select RANK 0      │
                           │ (highest priority) │
                           │ entitlement        │
                           └────────────────────┘
```

### SLA Calculation Decision Tree

```
                       ┌────────────────────┐
                       │ Case with          │
                       │ EntitlementId      │
                       └─────────┬──────────┘
                                 │
                 ┌───────────────┴───────────────┐
                 │ Is ProductFamily 'Rolloff'?   │
                 │ AND Vendor = WM (8)?          │
                 │ AND SBID exists?              │
                 └───┬───────────────────────┬───┘
                     │                       │
                    YES                     NO
                     │                       │
                     │                       ▼
                     │           ┌────────────────────────┐
                     │           │ Use Entitlement-Based  │
                     │           │ Calculation:           │
                     │           │ • Get days delta       │
                     │           │ • Check cutoff time    │
                     │           │ • Add to CreatedDate   │
                     │           │ • Adjust for business  │
                     │           │   hours                │
                     │           └────────────────────────┘
                     │
                     ▼
         ┌──────────────────────┐
         │ Is Entitlement       │
         │ Gold Standard OR     │
         │ Contractual?         │
         └───┬──────────────┬───┘
             │              │
            YES            NO
             │              │
             │              ▼
             │   ┌─────────────────────┐
             │   │ Call WM Capacity    │
             │   │ Planner API         │
             │   └──────────┬──────────┘
             │              │
             │    ┌─────────┴─────────┐
             │    │ API returns dates?│
             │    └───┬───────────┬───┘
             │        │           │
             │       YES         NO
             │        │           │
             │        │           ▼
             │        │   ┌────────────────┐
             │        │   │ FALLBACK:      │
             │        │   │ Use entitlement│
             │        │   │ calculation    │
             │        │   └────────────────┘
             │        │
             │        ▼
             │  ┌───────────────────┐
             │  │ Check for Work    │
             │  │ Order conflicts   │
             │  └────────┬──────────┘
             │           │
             │           ▼
             │  ┌───────────────────┐
             │  │ Select optimal    │
             │  │ available date    │
             │  └───────────────────┘
             │
             ▼
  ┌──────────────────────────┐
  │ Use Entitlement          │
  │ Calculation (bypass API) │
  └──────────────────────────┘
```

---

## Sequence Diagrams

### Sequence: Complete Case Insert with Entitlement and SLA

```
User/System   Trigger      Entitlement_Utility    SLACalculationUtility   Database
    │             │                 │                      │                  │
    │  Create     │                 │                      │                  │
    │   Case      │                 │                      │                  │
    ├────────────>│                 │                      │                  │
    │             │                 │                      │                  │
    │             │ Before Insert   │                      │                  │
    │             │  Fires          │                      │                  │
    │             │                 │                      │                  │
    │             │ getPrioritized  │                      │                  │
    │             │ Entitlements()  │                      │                  │
    │             ├────────────────>│                      │                  │
    │             │                 │                      │                  │
    │             │                 │ Query Cases          │                  │
    │             │                 ├─────────────────────────────────────────>│
    │             │                 │<─────────────────────────────────────────┤
    │             │                 │ Cases with fields    │                  │
    │             │                 │                      │                  │
    │             │                 │ Query Entitlements   │                  │
    │             │                 ├─────────────────────────────────────────>│
    │             │                 │<─────────────────────────────────────────┤
    │             │                 │ Entitlements         │                  │
    │             │                 │                      │                  │
    │             │                 │ Filter by Time/Day   │                  │
    │             │                 │ (internal logic)     │                  │
    │             │                 │                      │                  │
    │             │                 │ Prioritize           │                  │
    │             │                 │ (internal logic)     │                  │
    │             │                 │                      │                  │
    │             │ Return Map      │                      │                  │
    │             │<────────────────┤                      │                  │
    │             │                 │                      │                  │
    │             │ Assign          │                      │                  │
    │             │ EntitlementId   │                      │                  │
    │             │ to cases        │                      │                  │
    │             │                 │                      │                  │
    │             │ calculateAndSet │                      │                  │
    │             │ SLAFields()     │                      │                  │
    │             ├─────────────────────────────────────────>│                  │
    │             │                 │                      │                  │
    │             │                 │                      │ Query BusinessHrs│
    │             │                 │                      ├─────────────────>│
    │             │                 │                      │<─────────────────┤
    │             │                 │                      │                  │
    │             │                 │                      │ Query Locations  │
    │             │                 │                      ├─────────────────>│
    │             │                 │                      │<─────────────────┤
    │             │                 │                      │                  │
    │             │                 │                      │ Query            │
    │             │                 │                      │ Entitlements     │
    │             │                 │                      ├─────────────────>│
    │             │                 │                      │<─────────────────┤
    │             │                 │                      │                  │
    │             │                 │                      │ Calculate SLA    │
    │             │                 │                      │ (internal logic) │
    │             │                 │                      │                  │
    │             │                 │                      │ Set fields       │
    │             │                 │                      │ in-memory        │
    │             │                 │                      │                  │
    │             │ Return (void)   │                      │                  │
    │             │<─────────────────────────────────────────┤                  │
    │             │                 │                      │                  │
    │             │ Trigger ends    │                      │                  │
    │             │ (fields set)    │                      │                  │
    │             │                 │                      │                  │
    │             │ Database INSERT │                      │                  │
    │             ├────────────────────────────────────────────────────────────>│
    │             │<────────────────────────────────────────────────────────────┤
    │             │ Insert complete │                      │                  │
    │             │                 │                      │                  │
    │  Success    │                 │                      │                  │
    │<────────────┤                 │                      │                  │
    │             │                 │                      │                  │
```

### Sequence: WM Capacity Planner API Flow

```
SLACalculation   WMCapacity   Integration   HTTP      WM API
   Utility        Method       Metadata    Request    Server
      │              │              │          │         │
      │ callWM       │              │          │         │
      │ CapacityAPI()│              │          │         │
      ├─────────────>│              │          │         │
      │              │              │          │         │
      │              │ Query        │          │         │
      │              │ metadata     │          │         │
      │              ├─────────────>│          │         │
      │              │<─────────────┤          │         │
      │              │ Config data  │          │         │
      │              │              │          │         │
      │              │ Build HTTP   │          │         │
      │              │ Request      │          │         │
      │              │              │          │         │
      │              │ Set endpoint │          │         │
      │              │ Set headers  │          │         │
      │              │ Set timeout  │          │         │
      │              │              │          │         │
      │              │ Execute      │          │         │
      │              │ callout      │          │         │
      │              ├──────────────────────────>         │
      │              │              │          │         │
      │              │              │          │ GET     │
      │              │              │          │ /api... │
      │              │              │          ├────────>│
      │              │              │          │<────────┤
      │              │              │          │ 200 OK  │
      │              │              │          │ + JSON  │
      │              │<──────────────────────────┤         │
      │              │ HTTP Response│          │         │
      │              │              │          │         │
      │              │ Parse JSON   │          │         │
      │              │ Extract dates│          │         │
      │              │ Format dates │          │         │
      │              │              │          │         │
      │ Return       │              │          │         │
      │ List<String> │              │          │         │
      │<─────────────┤              │          │         │
      │              │              │          │         │
      │ Check if     │              │          │         │
      │ empty        │              │          │         │
      │              │              │          │         │
      │ Use dates OR │              │          │         │
      │ fallback     │              │          │         │
      │              │              │          │         │
```

---

## Summary

This document provides visual representations of how data flows through the SLA and Entitlement service layer classes. Use these diagrams to:

1. **Understand the system architecture** - See how layers interact
2. **Debug data flow issues** - Trace where data goes
3. **Plan integrations** - Know what queries execute when
4. **Optimize performance** - Identify bottlenecks in the flow
5. **Train new developers** - Visual learning aid

---

**Related Documentation**:
- **Technical Specification**: `SLA_Entitlement_Technical_Specification.md` (detailed algorithms)
- **Quick Reference**: `SLA_Entitlement_Quick_Reference.md` (fact sheet)
- **Developer Guide**: `Entitlement_and_SLA_Service_Layer_Guide.md` (integration patterns)

---

**Document Version**: 1.0 | **Last Updated**: 2025-11-22 | **Maintained By**: Development Team
