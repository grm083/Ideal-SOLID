# Production Support Debugging Guide

## Overview

This guide provides comprehensive debugging strategies for production support based on the service layer architecture. It covers common issues, debugging workflows, and troubleshooting techniques specific to the Case Management and Quote Procurement systems.

**Target Audience**: Production Support Engineers, DevOps, System Administrators, and Developers

**Last Updated**: 2025-11-22

---

## Table of Contents

1. [Architecture Quick Reference](#architecture-quick-reference)
2. [Logging and Monitoring](#logging-and-monitoring)
3. [Debugging Workflows](#debugging-workflows)
4. [Common Issues and Solutions](#common-issues-and-solutions)
5. [Layer-Specific Debugging](#layer-specific-debugging)
6. [Performance Troubleshooting](#performance-troubleshooting)
7. [Error Pattern Recognition](#error-pattern-recognition)
8. [Diagnostic Tools and Queries](#diagnostic-tools-and-queries)
9. [Escalation Checklist](#escalation-checklist)

---

## Architecture Quick Reference

### Service Layer Overview

The application uses a **Service-Oriented Architecture (SOA)** with the following layers:

```
┌────────────────────────────────────────────────┐
│              Trigger Layer                     │
│  Case.trigger, Quote.trigger                   │
└───────────────────┬────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────┐
│            Handler Layer                       │
│  CaseTriggerHandler, QuoteTriggerHandler       │
│  - Orchestrates service calls                  │
│  - Transaction management                      │
└───────────────────┬────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│  Service Layer   │    │   Service Layer  │
│  (Business)      │    │   (DML)          │
└────────┬─────────┘    └────────┬─────────┘
         │                       │
         ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│  Data Access     │    │   Utilities      │
│  (ContextGetter) │    │                  │
└──────────────────┘    └──────────────────┘
```

### Key Services by Domain

#### Case Management Services
- **CaseAttributeService** - Field initialization and population
- **CaseBusinessRuleService** - Validation and business rules
- **CaseDMLService** - Data persistence operations
- **CaseUIService** - UI data transformation
- **CaseDataGovernorService** - Governor limit optimization
- **CaseApprovalService** - Approval workflows
- **CaseTaskService** - Task creation
- **CaseWorkOrderService** - Work order orchestration

#### Quote Procurement Services
- **QuoteProcurementBusinessRuleService** - Quote validation
- **QuoteProcurementDMLService** - Quote/QuoteLine DML
- **QuoteProcurementProductService** - Product selection
- **QuoteProcurementUIService** - UI transformations

#### Supporting Services
- **UTIL_LoggingService** - Exception and error logging
- **SLACalculationUtility** - SLA date calculations
- **Entitlement_Utility** - Entitlement resolution

---

## Logging and Monitoring

### Understanding the Logging System

The application uses **UTIL_LoggingService** for centralized logging, which creates records in the `ExceptionLog__c` custom object.

#### Exception Log Fields

| Field | Description | Use in Debugging |
|-------|-------------|------------------|
| `Exception_Type__c` | Type of exception (e.g., DmlException) | Identify error category |
| `Exception_Message__c` | Full error message | Root cause details |
| `Stack_Trace__c` | Complete stack trace | Trace execution path |
| `Class_Name__c` | Class where error occurred | Locate problem code |
| `Method_Name__c` | Method where error occurred | Identify failing operation |
| `Line_Number__c` | Line number in code | Pinpoint exact location |
| `Severity__c` | ERROR, WARN, INFO, DEBUG | Filter by criticality |
| `User_ID__c` | User who triggered error | User-specific issues |
| `Occurrence_Count__c` | Number of occurrences | Identify recurring issues |
| `First_Occurred__c` | First occurrence timestamp | Track issue onset |
| `Last_Occurred__c` | Most recent occurrence | Monitor active issues |

### Accessing Logs

#### Developer Console Method
```apex
// Query recent errors
SELECT Id, Exception_Type__c, Exception_Message__c,
       Class_Name__c, Method_Name__c, Line_Number__c,
       User_ID__c, CreatedDate, Occurrence_Count__c
FROM ExceptionLog__c
WHERE CreatedDate = TODAY
ORDER BY CreatedDate DESC
LIMIT 50
```

#### Workbench Query Method
1. Navigate to Workbench → Queries → SOQL Query
2. Use the query above
3. Export to CSV for analysis

#### Find Logs by User
```apex
SELECT Id, Exception_Message__c, Class_Name__c, Method_Name__c,
       CreatedDate, User_ID__c
FROM ExceptionLog__c
WHERE User_ID__c = '005XXXXXXXXXXXXXXX'
  AND CreatedDate = LAST_N_DAYS:7
ORDER BY CreatedDate DESC
```

#### Find Logs by Error Type
```apex
SELECT Id, Exception_Message__c, Stack_Trace__c,
       Method_Name__c, Occurrence_Count__c
FROM ExceptionLog__c
WHERE Exception_Type__c = 'DmlException'
  AND CreatedDate = TODAY
ORDER BY Occurrence_Count__c DESC
```

### Debug Log Settings

For real-time debugging, configure debug logs:

1. **Setup** → **Debug Logs**
2. Click **New**
3. Set **Traced Entity Type** to User
4. Select specific user or yourself
5. Set log levels:
   - **Apex Code**: FINEST
   - **Database**: INFO
   - **Validation**: INFO
   - **Workflow**: INFO
   - **Callout**: INFO

### Monitoring Best Practices

#### Daily Health Checks
```apex
// Check for new error patterns
SELECT Exception_Type__c, COUNT(Id) errorCount,
       MIN(CreatedDate) firstOccurrence
FROM ExceptionLog__c
WHERE CreatedDate = TODAY
GROUP BY Exception_Type__c
ORDER BY COUNT(Id) DESC
```

#### Performance Monitoring
```apex
// Find governor limit issues
SELECT Id, Exception_Message__c, Class_Name__c, Method_Name__c
FROM ExceptionLog__c
WHERE Exception_Message__c LIKE '%governor%'
   OR Exception_Message__c LIKE '%limit%'
   OR Exception_Message__c LIKE '%CPU time%'
ORDER BY CreatedDate DESC
```

---

## Debugging Workflows

### Workflow 1: User Reports an Error

**Scenario**: User says "I got an error when saving a case"

#### Step 1: Gather Initial Information
Ask the user for:
- **Exact error message** shown on screen
- **Record ID** (Case ID, Quote ID, etc.)
- **Timestamp** when error occurred
- **What action** they were performing
- **Browser/device** information

#### Step 2: Check Exception Logs
```apex
// Query by user and timeframe
SELECT Id, Exception_Type__c, Exception_Message__c,
       Stack_Trace__c, Class_Name__c, Method_Name__c,
       Line_Number__c, CreatedDate
FROM ExceptionLog__c
WHERE User_ID__c = '005XXXXXXXXXXXXXXX'
  AND CreatedDate >= 2025-11-22T14:00:00Z
  AND CreatedDate <= 2025-11-22T15:00:00Z
ORDER BY CreatedDate DESC
```

#### Step 3: Analyze the Stack Trace
Look for:
- **Service class** where error originated
- **Line number** in code
- **Error type** (DML, Null Pointer, etc.)
- **Trigger context** (before/after insert/update)

Example Stack Trace Analysis:
```
Stack Trace:
Class.CaseAttributeService.updateCaseAttributes: line 245, column 1
Class.CaseTriggerHandler.beforeInsert: line 89, column 1
```

This tells us:
1. Error occurred in `CaseAttributeService.cls` at line 245
2. Called from `CaseTriggerHandler.beforeInsert` at line 89
3. Happened during a **before insert** trigger event

#### Step 4: Identify the Layer
Map the class to its layer:

| Class Pattern | Layer | Responsibility |
|--------------|-------|----------------|
| `*TriggerHandler` | Handler | Orchestration |
| `*AttributeService` | Service | Field population |
| `*BusinessRuleService` | Service | Validation |
| `*DMLService` | Service | Data persistence |
| `*UIService` | Service | UI transformation |
| `*ContextGetter` | Data Access | Queries |
| `*Utility` | Utility | Helper functions |

#### Step 5: Review the Code
Navigate to the specific file and line number:
- `classes/CaseAttributeService.cls:245`

Look for:
- **Try-catch blocks** - Is error being caught?
- **Null checks** - Are required objects validated?
- **Data validation** - Are inputs verified?

#### Step 6: Check Related Data
Query the record that failed:
```apex
// For Case errors
SELECT Id, Status, RecordType.Name, OwnerId, Owner.Name,
       ContactId, Contact.Name, AssetId, Asset.Name,
       AccountId, Account.Name, Case_Configuration__c,
       EntitlementId, Entitlement.Name
FROM Case
WHERE Id = '500XXXXXXXXXXXXXXX'
```

Check for:
- **Missing required relationships** (Asset, Contact, Account)
- **Invalid field values**
- **Record type mismatches**
- **Permission issues**

#### Step 7: Document Findings
Create a support ticket with:
- Error classification
- Root cause
- Affected users
- Workaround (if available)
- Permanent fix recommendation

---

### Workflow 2: Intermittent Failures

**Scenario**: "Cases sometimes save, sometimes fail"

#### Step 1: Identify Patterns
```apex
// Find all occurrences of the error
SELECT Id, Exception_Message__c, User_ID__c, User__r.Name,
       Class_Name__c, Method_Name__c, CreatedDate,
       Occurrence_Count__c
FROM ExceptionLog__c
WHERE Class_Name__c = 'CaseDMLService'
  AND CreatedDate = LAST_N_DAYS:7
ORDER BY CreatedDate DESC
```

Look for patterns:
- **Time-based**: Specific times of day?
- **User-based**: Specific users/profiles?
- **Data-based**: Specific record types or statuses?
- **Volume-based**: Only during high-load periods?

#### Step 2: Check Governor Limits
```apex
// Find governor limit errors
SELECT Id, Exception_Message__c, Stack_Trace__c,
       CreatedDate, Occurrence_Count__c
FROM ExceptionLog__c
WHERE (Exception_Message__c LIKE '%SOQL%'
   OR Exception_Message__c LIKE '%DML%'
   OR Exception_Message__c LIKE '%CPU%'
   OR Exception_Message__c LIKE '%Heap%')
  AND CreatedDate = LAST_N_DAYS:7
ORDER BY CreatedDate DESC
```

Common governor limit issues:
- **Too many SOQL queries** (101 limit)
- **Too many DML statements** (150 limit)
- **CPU time limit exceeded** (10,000ms synchronous)
- **Heap size exceeded** (6MB synchronous)

#### Step 3: Review Data Volume
Check if failures correlate with bulk operations:
```apex
// Check for bulk operations
SELECT COUNT(Id) caseCount, CreatedDate
FROM Case
WHERE CreatedDate = LAST_N_DAYS:7
GROUP BY CreatedDate
ORDER BY CreatedDate DESC
```

#### Step 4: Enable CaseDataGovernorService
If governor limits are hit, verify `CaseDataGovernorService` is active:

Check Custom Metadata: `Case_Configuration__mdt`
- Field: `Use_Data_Governor__c` should be `true`

This service optimizes queries and prevents governor limit issues.

---

### Workflow 3: Data Not Populating Correctly

**Scenario**: "The SLA date is not calculating correctly"

#### Step 1: Identify the Responsible Service
For SLA issues, the service is `SLACalculationUtility`

Reference: `/classes/SLACalculationUtility.cls`

#### Step 2: Check Service Dependencies
SLA calculation depends on:
1. **Entitlement_Utility** - Resolving the correct entitlement
2. **Case_Configuration__mdt** - SLA configuration
3. **Location (Account)** - Business hours
4. **Asset** - Asset-specific entitlements

#### Step 3: Verify Input Data
```apex
// Check Case data required for SLA
SELECT Id, Status, Priority, ContactId, Contact.AccountId,
       AssetId, Asset.Name, LocationId__c, Location_Name__c,
       EntitlementId, Entitlement.Name, Entitlement.SlaProcessId,
       Case_Configuration__c, Case_Configuration__r.Name
FROM Case
WHERE Id = '500XXXXXXXXXXXXXXX'
```

**Common Missing Data Issues**:
- `EntitlementId` is null
- `LocationId__c` is null
- `Case_Configuration__c` is null
- `AssetId` is null but required

#### Step 4: Check Entitlement Resolution
The `Entitlement_Utility.getEntitlement()` method resolves entitlements in this order:

1. **Asset-specific entitlement** (highest priority)
2. **Location-specific entitlement**
3. **Account-specific entitlement**
4. **Default entitlement** (from Case_Configuration__mdt)

Query to verify entitlements:
```apex
// Check available entitlements for a case
SELECT Id, Name, AssetId, Asset.Name, AccountId, Account.Name,
       StartDate, EndDate, Type, SlaProcessId
FROM Entitlement
WHERE (AssetId = '02iXXXXXXXXXXXXXXX'
   OR AccountId = '001XXXXXXXXXXXXXXX')
  AND StartDate <= TODAY
  AND EndDate >= TODAY
```

#### Step 5: Check Configuration
Query Case Configuration:
```apex
SELECT Id, DeveloperName, Label,
       Default_Entitlement_ID__c,
       Business_Hours_ID__c,
       POCharacters__c,
       Use_Data_Governor__c
FROM Case_Configuration__mdt
```

#### Step 6: Test Calculation Manually
Use Anonymous Apex to test:
```apex
// Test SLA calculation
Case testCase = [SELECT Id, ContactId, AssetId, LocationId__c,
                        Case_Configuration__c
                 FROM Case
                 WHERE Id = '500XXXXXXXXXXXXXXX'
                 LIMIT 1];

List<Case> cases = new List<Case>{testCase};

// Get dependencies
Map<Id, Account> locationMap = new Map<Id, Account>([
    SELECT Id, Name, Business_Hours__c
    FROM Account
    WHERE Id = :testCase.LocationId__c
]);

// Call utility
SLACalculationUtility.calculateAndSetSLAFields(cases, locationMap);

System.debug('SLA Response Date: ' + testCase.SLA_Response_Date__c);
System.debug('SLA Resolution Date: ' + testCase.SLA_Resolution_Date__c);
```

---

### Workflow 4: Performance Issues

**Scenario**: "Case creation is very slow"

#### Step 1: Enable Debug Logs
1. Setup → Debug Logs
2. Create new log for affected user
3. Set **Apex Code** to FINEST
4. Set **Database** to INFO

#### Step 2: Reproduce the Issue
Have user perform the slow operation while debug log is active

#### Step 3: Analyze Debug Log
Download the debug log and look for:

**SOQL Queries**:
```
16:45:12.001 SOQL_EXECUTE_BEGIN [89]|SELECT Id, Name FROM Asset WHERE Id = :tmpVar1
16:45:12.045 SOQL_EXECUTE_END [89]|Rows:1
```
- Time difference (45ms in this example)
- Number of rows returned
- Query location (line 89)

**DML Operations**:
```
16:45:13.123 DML_BEGIN [245]|Op:Insert|Type:Case|Rows:10
16:45:13.567 DML_END [245]
```
- Time difference (444ms in this example)
- Operation type
- Number of records

**CPU Time**:
```
CUMULATIVE_LIMIT_USAGE
  SOQL queries: 15 out of 100
  DML statements: 3 out of 150
  CPU time: 8234 out of 10000 ms
  Heap size: 2145678 out of 6291456 bytes
```

#### Step 4: Check for N+1 Query Problems
Look for queries inside loops:
```apex
// BAD PATTERN - causes N+1 queries
for (Case c : cases) {
    Asset a = [SELECT Id, Name FROM Asset WHERE Id = :c.AssetId];
    // Process asset
}

// GOOD PATTERN - uses ContextGetter
Set<Id> assetIds = new Set<Id>();
for (Case c : cases) {
    assetIds.add(c.AssetId);
}
Map<Id, Asset> assetMap = CaseContextGetter.getAssetsWithChildren(assetIds);
```

#### Step 5: Review CaseDataGovernorService
The `CaseDataGovernorService` should handle large data volumes efficiently.

Check if it's being used:
```apex
// In debug log, look for:
"CaseDataGovernorService.shouldUseGovernor: true"
"Publishing LMS message for async processing"
```

If not enabled, verify `Case_Configuration__mdt.Use_Data_Governor__c` is true.

#### Step 6: Check Bulk Processing
Verify triggers handle bulk operations:
```apex
// Debug log should show:
"Processing 200 cases in trigger"
NOT
"Processing 1 case in trigger" (repeated 200 times)
```

---

## Common Issues and Solutions

### Issue 1: DmlException - Required Field Missing

**Error Message**:
```
System.DmlException: Insert failed. First exception on row 0;
first error: REQUIRED_FIELD_MISSING, Required fields are missing: [Status]: [Status]
```

**Root Cause**:
- `CaseAttributeService.initializeCases()` not called in trigger
- Case Configuration not found
- Status field not populated during initialization

**Solution**:
1. Verify trigger handler calls `CaseAttributeService.initializeCases()`
2. Check Case Configuration exists:
```apex
SELECT Id, DeveloperName
FROM Case_Configuration__mdt
```
3. Verify the configuration is being selected correctly in `CaseAttributeService`

**Prevention**:
- Always call `initializeCases()` before any other processing
- Never allow cases to skip initialization

---

### Issue 2: NullPointerException in SLA Calculation

**Error Message**:
```
System.NullPointerException: Attempt to de-reference a null object
at Class.SLACalculationUtility.calculateResponseDate: line 156
```

**Root Cause**:
- Entitlement not found for the case
- Location (Account) not provided
- Business Hours configuration missing

**Solution**:
1. Check entitlement resolution:
```apex
Case c = [SELECT Id, ContactId, AssetId, LocationId__c, EntitlementId
          FROM Case WHERE Id = '500XXX'];
System.debug('EntitlementId: ' + c.EntitlementId);
```

2. If EntitlementId is null, check why:
```apex
// Run entitlement resolution manually
Id entitlementId = Entitlement_Utility.getEntitlement(
    c.AssetId,
    c.LocationId__c,
    c.ContactId,
    c.Case_Configuration__c
);
System.debug('Resolved Entitlement: ' + entitlementId);
```

3. Verify location has Business Hours:
```apex
Account loc = [SELECT Id, Business_Hours__c
               FROM Account
               WHERE Id = :c.LocationId__c];
System.debug('Business Hours: ' + loc.Business_Hours__c);
```

**Prevention**:
- Add null checks before calling SLA calculation
- Ensure all required relationships are populated first

---

### Issue 3: Governor Limits - Too Many SOQL Queries

**Error Message**:
```
System.LimitException: Too many SOQL queries: 101
```

**Root Cause**:
- Queries inside loops
- Not using ContextGetter classes
- Recursive trigger execution

**Solution**:
1. Enable `CaseDataGovernorService`:
   - Set `Case_Configuration__mdt.Use_Data_Governor__c = true`

2. Refactor code to use ContextGetter:
```apex
// BEFORE (bad)
for (Case c : cases) {
    Asset a = [SELECT Id FROM Asset WHERE Id = :c.AssetId];
}

// AFTER (good)
Set<Id> assetIds = new Set<Id>();
for (Case c : cases) {
    if (c.AssetId != null) assetIds.add(c.AssetId);
}
Map<Id, Asset> assetMap = CaseContextGetter.getAssetsWithChildren(assetIds);
```

3. Check for recursion:
```apex
// Look for debug log showing same handler multiple times
CaseTriggerHandler.beforeUpdate called
CaseTriggerHandler.beforeUpdate called (RECURSION!)
```

Add recursion prevention:
```apex
private static Boolean isExecuting = false;

public void beforeUpdate() {
    if (isExecuting) return;
    isExecuting = true;
    try {
        // Logic here
    } finally {
        isExecuting = false;
    }
}
```

**Prevention**:
- Always use ContextGetter classes for queries
- Never query inside loops
- Enable CaseDataGovernorService for high-volume scenarios

---

### Issue 4: Business Rule Validation Failing

**Error Message** (shown to user):
```
"Case cannot be submitted: Required field 'Cost Center' is missing"
```

**Root Cause**:
- Business Rule configured with required fields
- Field not populated before validation
- Rule evaluation order incorrect

**Solution**:
1. Find which business rule is failing:
```apex
Case c = [SELECT Id, Status, RecordType.Name FROM Case WHERE Id = '500XXX'];

// Test business rules
CaseBusinessRuleService.BusinessRuleResult result =
    CaseBusinessRuleService.evaluateBusinessRules(c.Id);

System.debug('Validation Messages: ' + result.validationMessages);
System.debug('Required Info Missing: ' + result.requiredInfoMissing);
```

2. Query the business rule:
```apex
SELECT Id, Name, Required_Fields__c, Status__c, RecordType__c
FROM Business_Rule__c
WHERE RecordType__c = :c.RecordType.Name
  AND Status__c = :c.Status
```

3. Check if fields are populated:
```apex
// If Required_Fields__c = 'Cost_Center__c;Department__c'
System.debug('Cost Center: ' + c.Cost_Center__c);
System.debug('Department: ' + c.Department__c);
```

**Prevention**:
- Populate all required fields before changing status
- Call `CaseBusinessRuleService.evaluateBusinessRules()` before DML
- Show validation messages to user

---

### Issue 5: Quote Line Validation Error

**Error Message**:
```
"Quote Line must have Product Category specified before advancing to Cost Configured"
```

**Root Cause**:
- Stage-based validation in `QuoteProcurementBusinessRuleService`
- Required fields not populated for current stage

**Solution**:
1. Identify the stage:
```apex
SBQQ__QuoteLine__c quoteLine = [
    SELECT Id, SBQQ__Quote__r.SBQQ__Status__c, Product_Category__c
    FROM SBQQ__QuoteLine__c
    WHERE Id = 'a0QXXX'
];
System.debug('Quote Stage: ' + quoteLine.SBQQ__Quote__r.SBQQ__Status__c);
```

2. Test validation:
```apex
String error = QuoteProcurementBusinessRuleService.validateQuoteLine(quoteLine);
System.debug('Validation Error: ' + error);
```

3. Check required fields by stage:

**Draft → Product Configured**:
- Product2Id (required)
- Quantity (required)

**Product Configured → Cost Configured**:
- Product_Category__c (required)
- Unit_Cost__c (required)

**Cost Configured → Price Configured**:
- Unit_Price__c (required)
- Margin__c (required)

**Prevention**:
- Validate fields before advancing stages
- Use `QuoteProcurementBusinessRuleService.validateQuoteLine()` before status change

---

### Issue 6: Entitlement Not Found

**Error Message**:
```
"No valid entitlement found for this asset and location"
```

**Root Cause**:
- No entitlement configured for asset/account
- Entitlement expired
- Entitlement query logic issue

**Solution**:
1. Check asset's entitlements:
```apex
SELECT Id, Name, AssetId, Asset.Name, AccountId, Account.Name,
       StartDate, EndDate, Type, SlaProcessId
FROM Entitlement
WHERE AssetId = '02iXXX'
  AND StartDate <= TODAY
  AND EndDate >= TODAY
```

2. Check account's entitlements:
```apex
SELECT Id, Name, AccountId, Account.Name,
       StartDate, EndDate, Type, SlaProcessId
FROM Entitlement
WHERE AccountId = '001XXX'
  AND StartDate <= TODAY
  AND EndDate >= TODAY
```

3. Test entitlement resolution:
```apex
Id entitlementId = Entitlement_Utility.getEntitlement(
    assetId,
    locationId,
    contactId,
    caseConfigurationId
);
System.debug('Resolved: ' + entitlementId);
```

4. Check default entitlement in configuration:
```apex
SELECT Id, Default_Entitlement_ID__c
FROM Case_Configuration__mdt
WHERE DeveloperName = 'XXX'
```

**Prevention**:
- Ensure all accounts have entitlements
- Configure default entitlement in Case_Configuration__mdt
- Monitor entitlement expiration dates

---

## Layer-Specific Debugging

### Trigger Layer Debugging

**File**: `Case.trigger`

**Common Issues**:
- Trigger not firing
- Trigger disabled
- Multiple trigger contexts

**Debug Steps**:
1. Verify trigger is active:
   - Setup → Apex Triggers → Case
   - Status should be "Active"

2. Add debug statements:
```apex
trigger Case on Case (before insert, before update, after insert, after update) {
    System.debug('Case Trigger Fired - Context: ' + Trigger.operationType);
    System.debug('New Size: ' + (Trigger.new != null ? Trigger.new.size() : 0));

    // Dispatch to handler
}
```

3. Check if recursion is occurring:
```apex
System.debug('Is Executing: ' + CaseTriggerHandler.isExecuting);
```

---

### Handler Layer Debugging

**Files**:
- `CaseTriggerHandler.cls`
- `QuoteProcurementTriggerHandler.cls`

**Common Issues**:
- Service orchestration order wrong
- Missing service calls
- Transaction rollback

**Debug Steps**:
1. Add debug at each phase:
```apex
public override void beforeInsert(TriggerParameters params) {
    System.debug('=== BEFORE INSERT START ===');

    System.debug('Phase 1: Initialize Cases');
    CaseAttributeService.initializeCases(newCases);

    System.debug('Phase 2: Retrieve Related Data');
    // ...

    System.debug('=== BEFORE INSERT END ===');
}
```

2. Check for exceptions:
```apex
try {
    CaseAttributeService.updateCaseAttributes(cases, assetMap, locationMap);
} catch (Exception ex) {
    System.debug('ERROR in updateCaseAttributes: ' + ex.getMessage());
    System.debug('Stack Trace: ' + ex.getStackTraceString());
    throw ex;
}
```

3. Verify service results:
```apex
CaseBusinessRuleService.BusinessRuleResult result =
    CaseBusinessRuleService.evaluateBusinessRules(caseId);

System.debug('Business Rule Result: ' + JSON.serializePretty(result));
```

---

### Service Layer Debugging

**Files**: All `*Service.cls` classes

**Common Issues**:
- Service not returning expected results
- Logic not executing
- Data transformation errors

**Debug Steps**:
1. Debug input parameters:
```apex
public static void updateCaseAttributes(List<Case> cases,
                                       Map<Id, Asset> assetMap,
                                       Map<Id, Account> locationMap) {
    System.debug('Input Cases: ' + cases.size());
    System.debug('Asset Map Size: ' + assetMap.size());
    System.debug('Location Map Size: ' + locationMap.size());

    // Service logic
}
```

2. Debug at decision points:
```apex
if (shouldProcessCase(caseRecord)) {
    System.debug('Processing case: ' + caseRecord.Id);
    // Process
} else {
    System.debug('Skipping case: ' + caseRecord.Id +
                 ' - Reason: Does not meet criteria');
}
```

3. Debug output:
```apex
public static BusinessRuleResult evaluateBusinessRules(Id caseId) {
    BusinessRuleResult result = new BusinessRuleResult();

    // Logic...

    System.debug('Final Result: ' + JSON.serializePretty(result));
    return result;
}
```

---

### DML Service Debugging

**Files**:
- `CaseDMLService.cls`
- `QuoteProcurementDMLService.cls`

**Common Issues**:
- DML failures
- Partial success scenarios
- FLS violations

**Debug Steps**:
1. Enable detailed DML logging:
```apex
Database.SaveResult[] saveResults = Database.insert(cases, dmlOpts);

for (Integer i = 0; i < saveResults.size(); i++) {
    Database.SaveResult sr = saveResults[i];
    if (!sr.isSuccess()) {
        System.debug('DML Error on record index ' + i);
        System.debug('Record: ' + JSON.serialize(cases[i]));
        for (Database.Error err : sr.getErrors()) {
            System.debug('Error: ' + err.getMessage());
            System.debug('Fields: ' + err.getFields());
            System.debug('Status Code: ' + err.getStatusCode());
        }
    }
}
```

2. Check DML options:
```apex
Database.DMLOptions dmlOpts = new Database.DMLOptions();
dmlOpts.allowFieldTruncation = true;
dmlOpts.optAllOrNone = false;

System.debug('DML Options: ' + JSON.serializePretty(dmlOpts));
```

3. Verify FLS:
```apex
SObjectAccessDecision decision = Security.stripInaccessible(
    AccessType.UPDATABLE,
    records
);

System.debug('Removed Fields: ' + decision.getRemovedFields());
System.debug('Modified Records: ' + decision.getRecords().size());
```

---

### Data Access Layer Debugging

**Files**: All `*ContextGetter.cls` classes

**Common Issues**:
- Queries returning no data
- Query timeout
- Relationship queries missing fields

**Debug Steps**:
1. Debug query parameters:
```apex
public static Map<Id, Asset> getAssetsWithChildren(Set<Id> assetIds) {
    System.debug('Querying assets for IDs: ' + assetIds);

    if (assetIds == null || assetIds.isEmpty()) {
        System.debug('WARNING: Empty asset ID set provided');
        return new Map<Id, Asset>();
    }

    // Query logic
}
```

2. Debug query results:
```apex
Map<Id, Asset> assetMap = new Map<Id, Asset>([
    SELECT Id, Name, (SELECT Id FROM ChildAssets__r)
    FROM Asset
    WHERE Id IN :assetIds
]);

System.debug('Assets returned: ' + assetMap.size());
System.debug('Requested: ' + assetIds.size());

if (assetMap.size() < assetIds.size()) {
    Set<Id> missingIds = new Set<Id>(assetIds);
    missingIds.removeAll(assetMap.keySet());
    System.debug('Missing Asset IDs: ' + missingIds);
}

return assetMap;
```

3. Check for governor limits:
```apex
System.debug('SOQL Queries used: ' + Limits.getQueries() + '/' + Limits.getLimitQueries());
System.debug('Query Rows: ' + Limits.getQueryRows() + '/' + Limits.getLimitQueryRows());
```

---

## Performance Troubleshooting

### Identifying Performance Bottlenecks

#### Method 1: Debug Log Analysis

1. Enable FINEST level logging
2. Execute the slow operation
3. Download debug log
4. Search for these patterns:

**Slow SOQL Queries** (>100ms):
```
SOQL_EXECUTE_BEGIN
SOQL_EXECUTE_END [duration > 100ms]
```

**Slow DML Operations** (>500ms):
```
DML_BEGIN
DML_END [duration > 500ms]
```

**CPU Time**:
```
CUMULATIVE_LIMIT_USAGE
CPU time: [approaching 10000]
```

#### Method 2: Event Monitoring

For production issues, use Event Monitoring:

1. Setup → Event Monitoring → Event Log File
2. Download ApexExecution logs
3. Look for:
   - `RUN_TIME` > 5000ms
   - `CPU_TIME` > 5000ms
   - `DB_TOTAL_TIME` > 3000ms

#### Method 3: Custom Instrumentation

Add timing code:
```apex
public static void processLargeDataSet(List<Case> cases) {
    Long startTime = System.currentTimeMillis();

    // Phase 1
    Long phase1Start = System.currentTimeMillis();
    retrieveRelatedData(cases);
    System.debug('Phase 1 Duration: ' + (System.currentTimeMillis() - phase1Start) + 'ms');

    // Phase 2
    Long phase2Start = System.currentTimeMillis();
    processBusinessRules(cases);
    System.debug('Phase 2 Duration: ' + (System.currentTimeMillis() - phase2Start) + 'ms');

    System.debug('Total Duration: ' + (System.currentTimeMillis() - startTime) + 'ms');
}
```

### Performance Optimization Checklist

- [ ] Use CaseDataGovernorService for bulk operations
- [ ] Consolidate queries in ContextGetter classes
- [ ] Use `Map<Id, SObject>` for lookups instead of loops
- [ ] Avoid queries inside loops
- [ ] Use `Database.Stateful` for batch jobs
- [ ] Limit query results with `LIMIT`
- [ ] Use selective queries (indexed fields in WHERE clause)
- [ ] Avoid `SELECT *`, specify only needed fields
- [ ] Use `@future` for long-running operations
- [ ] Implement caching for frequently accessed data

### Common Performance Issues

#### Issue: Case trigger takes 15+ seconds

**Symptoms**:
- Users experience delays when saving cases
- CPU time approaching limits
- Multiple SOQL queries

**Solution**:
Enable `CaseDataGovernorService`:

1. Set `Case_Configuration__mdt.Use_Data_Governor__c = true`
2. The service will:
   - Publish LMS messages for async processing
   - Defer non-critical updates
   - Batch related data retrieval

**Verification**:
```apex
System.debug('Data Governor Active: ' + CaseDataGovernorService.shouldUseGovernor());
```

#### Issue: SLA calculation timeout

**Symptoms**:
- Entitlement queries timing out
- Business hours calculation errors
- Null pointer exceptions

**Solution**:
1. Ensure entitlements are indexed:
   - AssetId
   - AccountId
   - StartDate, EndDate

2. Cache business hours:
```apex
private static Map<Id, BusinessHours> businessHoursCache =
    new Map<Id, BusinessHours>();

public static BusinessHours getBusinessHours(Id bhId) {
    if (!businessHoursCache.containsKey(bhId)) {
        businessHoursCache.put(bhId, [SELECT Id, Name FROM BusinessHours WHERE Id = :bhId]);
    }
    return businessHoursCache.get(bhId);
}
```

3. Pre-load entitlements:
```apex
// In CaseTriggerHandler, bulk load entitlements
Set<Id> assetIds = new Set<Id>();
Set<Id> accountIds = new Set<Id>();

for (Case c : cases) {
    if (c.AssetId != null) assetIds.add(c.AssetId);
    if (c.AccountId != null) accountIds.add(c.AccountId);
}

Map<Id, Entitlement> entitlementMap = new Map<Id, Entitlement>([
    SELECT Id, AssetId, AccountId, SlaProcessId
    FROM Entitlement
    WHERE (AssetId IN :assetIds OR AccountId IN :accountIds)
      AND StartDate <= TODAY
      AND EndDate >= TODAY
]);
```

---

## Error Pattern Recognition

### Pattern 1: Null Pointer Exceptions

**Signature**:
```
System.NullPointerException: Attempt to de-reference a null object
```

**Common Causes**:
1. Relationship field not queried
2. Map lookup returns null
3. Null check missing

**How to Identify**:
Look at the line number and check for:
```apex
// Line 245: NullPointerException
someObject.field = anotherObject.someField;
// anotherObject is null!
```

**Solution Pattern**:
```apex
// Add null checks
if (anotherObject != null && anotherObject.someField != null) {
    someObject.field = anotherObject.someField;
}
```

---

### Pattern 2: List Index Out of Bounds

**Signature**:
```
System.ListException: List index out of bounds: 0
```

**Common Causes**:
1. Accessing list[0] when empty
2. Assuming query always returns results

**How to Identify**:
```apex
// Line 123: ListException
List<Account> accounts = [SELECT Id FROM Account WHERE Name = :searchName];
Account acc = accounts[0];  // Fails if no results
```

**Solution Pattern**:
```apex
List<Account> accounts = [SELECT Id FROM Account WHERE Name = :searchName];
if (!accounts.isEmpty()) {
    Account acc = accounts[0];
    // Process
}
```

---

### Pattern 3: DML Exceptions

**Signature**:
```
System.DmlException: Insert failed. First exception on row 0
```

**Common Causes**:
1. Required fields missing
2. Validation rules
3. Duplicate values
4. FLS issues

**How to Identify**:
Look at the error message:
- `REQUIRED_FIELD_MISSING` - Field not populated
- `FIELD_CUSTOM_VALIDATION_EXCEPTION` - Validation rule failed
- `DUPLICATE_VALUE` - Unique field violation
- `INSUFFICIENT_ACCESS` - FLS or sharing issue

**Solution Pattern**:
Use `Database.DMLOptions` with `allOrNone = false`:
```apex
Database.DMLOptions dmlOpts = new Database.DMLOptions();
dmlOpts.optAllOrNone = false;

Database.SaveResult[] results = Database.insert(records, dmlOpts);

for (Database.SaveResult sr : results) {
    if (!sr.isSuccess()) {
        for (Database.Error err : sr.getErrors()) {
            // Log and handle each error
            UTIL_LoggingService.logMessage(
                'DML Error: ' + err.getMessage(),
                'CaseDMLService',
                'insertCases',
                LoggingLevel.ERROR
            );
        }
    }
}
```

---

### Pattern 4: Governor Limit Exceptions

**Signature**:
```
System.LimitException: Too many SOQL queries: 101
System.LimitException: Too many DML statements: 151
```

**Common Causes**:
1. Queries in loops
2. DML in loops
3. Recursive triggers
4. Inefficient code

**How to Identify**:
Search debug log for repeated patterns:
```
SOQL_EXECUTE_BEGIN (repeated 101 times)
```

**Solution Pattern**:
1. Use ContextGetter for bulk queries
2. Use DML services for bulk DML
3. Add recursion prevention
4. Enable CaseDataGovernorService

---

## Diagnostic Tools and Queries

### Essential Queries

#### 1. Find All Errors for a Record
```apex
SELECT Id, Exception_Type__c, Exception_Message__c,
       Stack_Trace__c, Class_Name__c, Method_Name__c,
       Line_Number__c, CreatedDate
FROM ExceptionLog__c
WHERE Exception_Message__c LIKE '%500XXXXXXXXXXXXXXX%'
ORDER BY CreatedDate DESC
```

#### 2. Find All Errors for a User
```apex
SELECT Id, Exception_Type__c, Exception_Message__c,
       Class_Name__c, Method_Name__c, CreatedDate
FROM ExceptionLog__c
WHERE User_ID__c = '005XXXXXXXXXXXXXXX'
  AND CreatedDate >= LAST_N_DAYS:7
ORDER BY CreatedDate DESC
LIMIT 100
```

#### 3. Find Most Common Errors
```apex
SELECT Exception_Type__c, Exception_Message__c,
       COUNT(Id) errorCount,
       MAX(CreatedDate) latestOccurrence
FROM ExceptionLog__c
WHERE CreatedDate = TODAY
GROUP BY Exception_Type__c, Exception_Message__c
ORDER BY COUNT(Id) DESC
LIMIT 20
```

#### 4. Find Governor Limit Issues
```apex
SELECT Id, Exception_Message__c, Stack_Trace__c,
       Class_Name__c, Method_Name__c, CreatedDate,
       Occurrence_Count__c
FROM ExceptionLog__c
WHERE (Exception_Type__c = 'LimitException'
   OR Exception_Message__c LIKE '%Too many%'
   OR Exception_Message__c LIKE '%limit%')
  AND CreatedDate >= LAST_N_DAYS:7
ORDER BY Occurrence_Count__c DESC
```

#### 5. Find Cases Missing Required Data
```apex
SELECT Id, CaseNumber, Status, RecordType.Name,
       ContactId, AssetId, LocationId__c, EntitlementId,
       Case_Configuration__c
FROM Case
WHERE (ContactId = NULL
   OR AssetId = NULL
   OR LocationId__c = NULL
   OR EntitlementId = NULL
   OR Case_Configuration__c = NULL)
  AND CreatedDate = LAST_N_DAYS:7
ORDER BY CreatedDate DESC
```

#### 6. Find Failed DML Operations
```apex
SELECT Id, Exception_Type__c, Exception_Message__c,
       Stack_Trace__c, CreatedDate, User__r.Name
FROM ExceptionLog__c
WHERE Exception_Type__c = 'DmlException'
  AND CreatedDate = TODAY
ORDER BY CreatedDate DESC
```

#### 7. Find Entitlement Resolution Issues
```apex
SELECT Id, CaseNumber, Status, AssetId, Asset.Name,
       AccountId, Account.Name, LocationId__c,
       EntitlementId, Case_Configuration__c
FROM Case
WHERE EntitlementId = NULL
  AND Status NOT IN ('Closed', 'Cancelled')
ORDER BY CreatedDate DESC
LIMIT 50
```

### Anonymous Apex Scripts

#### Test Entitlement Resolution
```apex
// Set the Case ID
Id caseId = '500XXXXXXXXXXXXXXX';

Case c = [SELECT Id, AssetId, LocationId__c, ContactId, Case_Configuration__c,
                 EntitlementId
          FROM Case
          WHERE Id = :caseId];

System.debug('=== Current Case Data ===');
System.debug('AssetId: ' + c.AssetId);
System.debug('LocationId: ' + c.LocationId__c);
System.debug('ContactId: ' + c.ContactId);
System.debug('Case_Configuration__c: ' + c.Case_Configuration__c);
System.debug('Current EntitlementId: ' + c.EntitlementId);

// Test entitlement resolution
Id resolvedEntitlementId = Entitlement_Utility.getEntitlement(
    c.AssetId,
    c.LocationId__c,
    c.ContactId,
    c.Case_Configuration__c
);

System.debug('=== Resolution Result ===');
System.debug('Resolved EntitlementId: ' + resolvedEntitlementId);

if (resolvedEntitlementId != null) {
    Entitlement ent = [SELECT Id, Name, AssetId, AccountId, Type, SlaProcessId
                       FROM Entitlement
                       WHERE Id = :resolvedEntitlementId];
    System.debug('Entitlement Details: ' + JSON.serializePretty(ent));
} else {
    System.debug('ERROR: No entitlement found');
}
```

#### Test SLA Calculation
```apex
// Set the Case ID
Id caseId = '500XXXXXXXXXXXXXXX';

Case c = [SELECT Id, ContactId, AssetId, LocationId__c,
                 Case_Configuration__c, Priority,
                 SLA_Response_Date__c, SLA_Resolution_Date__c
          FROM Case
          WHERE Id = :caseId];

System.debug('=== Before SLA Calculation ===');
System.debug('SLA Response Date: ' + c.SLA_Response_Date__c);
System.debug('SLA Resolution Date: ' + c.SLA_Resolution_Date__c);

// Get location for business hours
Map<Id, Account> locationMap = new Map<Id, Account>();
if (c.LocationId__c != null) {
    Account loc = [SELECT Id, Business_Hours__c
                   FROM Account
                   WHERE Id = :c.LocationId__c];
    locationMap.put(loc.Id, loc);
}

// Calculate SLA
List<Case> cases = new List<Case>{c};
SLACalculationUtility.calculateAndSetSLAFields(cases, locationMap);

System.debug('=== After SLA Calculation ===');
System.debug('SLA Response Date: ' + c.SLA_Response_Date__c);
System.debug('SLA Resolution Date: ' + c.SLA_Resolution_Date__c);
```

#### Test Business Rules
```apex
// Set the Case ID
Id caseId = '500XXXXXXXXXXXXXXX';

System.debug('=== Testing Business Rules ===');

CaseBusinessRuleService.BusinessRuleResult result =
    CaseBusinessRuleService.evaluateBusinessRules(caseId);

System.debug('Is Auto Approved: ' + result.isAutoApproved);
System.debug('Requires Approval: ' + result.requiresApproval);
System.debug('Validation Messages: ' + result.validationMessages);
System.debug('Required Info Missing: ' + result.requiredInfoMissing);

if (result.approvalRules != null && !result.approvalRules.isEmpty()) {
    System.debug('Approval Rules Found: ' + result.approvalRules.size());
    for (Business_Rule__c rule : result.approvalRules.values()) {
        System.debug('  - ' + rule.Name + ': ' + rule.Required_Fields__c);
    }
}
```

#### Bulk Load Test
```apex
// Test governor limit behavior
Integer recordCount = 200;

List<Case> testCases = new List<Case>();
for (Integer i = 0; i < recordCount; i++) {
    testCases.add(new Case(
        Subject = 'Bulk Test ' + i,
        Status = 'New',
        Origin = 'Email'
    ));
}

System.debug('=== Before Insert ===');
System.debug('SOQL Queries: ' + Limits.getQueries() + '/' + Limits.getLimitQueries());
System.debug('DML Statements: ' + Limits.getDMLStatements() + '/' + Limits.getLimitDMLStatements());
System.debug('CPU Time: ' + Limits.getCpuTime() + '/' + Limits.getLimitCpuTime());

Long startTime = System.currentTimeMillis();
insert testCases;
Long duration = System.currentTimeMillis() - startTime;

System.debug('=== After Insert ===');
System.debug('Duration: ' + duration + 'ms');
System.debug('SOQL Queries: ' + Limits.getQueries() + '/' + Limits.getLimitQueries());
System.debug('DML Statements: ' + Limits.getDMLStatements() + '/' + Limits.getLimitDMLStatements());
System.debug('CPU Time: ' + Limits.getCpuTime() + '/' + Limits.getLimitCpuTime());

// Cleanup
delete testCases;
```

---

## Escalation Checklist

When escalating an issue to development team, provide:

### 1. Issue Summary
- [ ] Clear description of the problem
- [ ] Impact assessment (# of users, business impact)
- [ ] Frequency (one-time, intermittent, consistent)

### 2. Error Details
- [ ] Full error message
- [ ] Exception type
- [ ] Stack trace
- [ ] Line numbers

### 3. Reproduction Steps
- [ ] Step-by-step instructions
- [ ] Test data used
- [ ] User profile/permissions
- [ ] Expected vs actual behavior

### 4. Logs and Diagnostics
- [ ] ExceptionLog__c records
- [ ] Debug logs
- [ ] Governor limit statistics
- [ ] Affected record IDs

### 5. Environment Information
- [ ] Sandbox vs Production
- [ ] Org ID
- [ ] Recent deployments
- [ ] Configuration changes

### 6. Troubleshooting Performed
- [ ] Steps already taken
- [ ] Workarounds attempted
- [ ] Test results

### 7. Business Context
- [ ] Business process affected
- [ ] Urgency/Priority
- [ ] Stakeholders
- [ ] Workaround acceptability

---

## Appendix: Service Reference

### CaseAttributeService
**File**: `/classes/CaseAttributeService.cls`

**Methods**:
- `initializeCases(List<Case>)` - Initialize new cases with default values
- `updateCaseAttributes(List<Case>, Map<Id, Asset>, Map<Id, Account>)` - Update attributes from related data
- `populateFieldsFromConfiguration(Case, Case_Configuration__mdt)` - Apply configuration-based field values

**When to Debug**:
- Missing default field values
- Attribute population issues
- Configuration-related problems

---

### CaseBusinessRuleService
**File**: `/classes/CaseBusinessRuleService.cls`

**Methods**:
- `evaluateBusinessRules(Id caseId)` - Evaluate all rules for a case
- `evaluateAndApplyBusinessRules(List<Case>)` - Apply rules during trigger

**Returns**: `BusinessRuleResult`
- `isAutoApproved` - Auto-approval flag
- `requiresApproval` - Approval required flag
- `validationMessages` - Validation errors
- `approvalRules` - Applicable approval rules

**When to Debug**:
- Validation failures
- Approval routing issues
- Required field errors

---

### CaseDMLService
**File**: `/classes/CaseDMLService.cls`

**Methods**:
- `insertCases(List<Case>)` - Bulk insert
- `updateCases(List<Case>)` - Bulk update
- `deleteCases(List<Case>)` - Bulk delete

**Returns**: `DMLResult`
- `hasErrors` - Error flag
- `successIds` - Successfully processed IDs
- `errors` - Error details

**When to Debug**:
- DML failures
- Partial success scenarios
- Data persistence issues

---

### SLACalculationUtility
**File**: `/classes/SLACalculationUtility.cls`

**Methods**:
- `calculateAndSetSLAFields(List<Case>, Map<Id, Account>)` - Calculate SLA dates
- `calculateResponseDate(Case, Entitlement, BusinessHours)` - Calculate response SLA
- `calculateResolutionDate(Case, Entitlement, BusinessHours)` - Calculate resolution SLA

**When to Debug**:
- Incorrect SLA dates
- Null SLA fields
- Business hours calculation errors

---

### Entitlement_Utility
**File**: `/classes/Entitlement_Utility.cls`

**Methods**:
- `getEntitlement(Id assetId, Id locationId, Id contactId, Id configId)` - Resolve entitlement

**Resolution Order**:
1. Asset-specific entitlement
2. Location-specific entitlement
3. Account-specific entitlement
4. Default from configuration

**When to Debug**:
- Entitlement not found
- Wrong entitlement selected
- SLA process issues

---

### UTIL_LoggingService
**File**: `/classes/UTIL_LoggingService.cls`

**Methods**:
- `logHandledException(Exception, String, String, LoggingLevel)` - Log exceptions
- `logDmlResults(List<SaveResult>, List<DeleteResult>, ...)` - Log DML errors
- `logMessage(String, String, String, LoggingLevel)` - Log custom messages

**When to Debug**:
- Logs not being created
- Missing error details
- Deduplication issues

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-22 | Claude Code | Initial creation |

---

## Additional Resources

- [Case Trigger Architecture Documentation](Case_Trigger_Architecture.md)
- [Governor Architecture Guide](../docs/GOVERNOR_ARCHITECTURE.md)
- [Entitlement and SLA Service Layer Guide](Entitlement_and_SLA_Service_Layer_Guide.md)
- [SLA Entitlement Technical Specification](SLA_Entitlement_Technical_Specification.md)

---

**For questions or clarifications, contact the development team.**
