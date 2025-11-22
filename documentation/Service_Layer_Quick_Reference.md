# Service Layer Architecture - Quick Reference Guide

**Version**: 1.0
**Last Updated**: 2025-11-22
**Audience**: Developers extending the Ideal-SOLID codebase

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [The 5-Tier Pattern](#the-5-tier-pattern)
3. [Service Types & When to Use Them](#service-types--when-to-use-them)
4. [How to Reference Each Class](#how-to-reference-each-class)
5. [Common Patterns & Conventions](#common-patterns--conventions)
6. [Expanding the Architecture](#expanding-the-architecture)
7. [Quick Checklist](#quick-checklist)

---

## Architecture Overview

The Ideal-SOLID service layer implements a **5-tier architecture** that separates concerns across distinct layers:

```
UI Layer → Governor Service → Services → Data Access → Persistence
```

**Key Metrics**:
- 119 Apex classes
- 90% reduction in API calls (15 → 1 per page)
- 85% reduction in SOQL queries (25-40 → 3-5 per page)
- 60% faster page load times (3-5s → 1-2s)

**Core Principle**: **No SOQL in controllers, no business logic in UI services, no DML outside DML services**

---

## The 5-Tier Pattern

```
┌─────────────────────────────────────────────────────────┐
│  Layer 1: Lightning Web Components (UI)                 │
│  - User interaction                                     │
│  - LWC/Aura components                                  │
└────────────────────┬────────────────────────────────────┘
                     │ @AuraEnabled calls
                     │
┌────────────────────▼────────────────────────────────────┐
│  Layer 2: Governor Service (Orchestration)              │
│  - CaseDataGovernorService                              │
│  - Consolidates multiple calls → single response        │
│  - Example: 15 API calls → 1                            │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
┌───────▼──────┐ ┌──▼──────────┐ ┌▼─────────────┐
│ Layer 3a:    │ │ Layer 3b:   │ │ Layer 3c:    │
│ UI Service   │ │ Business    │ │ Attribute    │
│              │ │ Rule Service│ │ Service      │
│ - UI data    │ │ - Logic     │ │ - Defaults   │
│ - Wrappers   │ │ - Rules     │ │ - Init       │
└───────┬──────┘ └──┬──────────┘ └┬─────────────┘
        │           │              │
        └───────────┴──────────────┘
                    │
┌───────────────────▼─────────────────────────────────────┐
│  Layer 4: ContextGetter (Data Access)                   │
│  - CaseContextGetter, AccountContextGetter              │
│  - Caching, bulkification                               │
│  - Single source of truth for SOQL                      │
└───────────────────┬─────────────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────────────┐
│  Layer 5: DML Service (Data Persistence)                │
│  - CaseDMLService, QuoteProcurementDMLService           │
│  - All DML operations                                   │
│  - Error handling, logging                              │
└─────────────────────────────────────────────────────────┘
```

---

## Service Types & When to Use Them

### 1. Governor Service (Layer 2)

**Purpose**: Consolidate multiple API calls into a single orchestrated response

**When to Use**:
- Page loads requiring data from multiple services
- Need to reduce API call volume
- Want to provide all page context at once

**Example**:
```apex
// CaseDataGovernorService.cls
@AuraEnabled(cacheable=false)
public static CasePageDataWrapper getCasePageData(Id caseId,
                                                   Boolean includeRelated,
                                                   Boolean includeBusinessRules) {
    CasePageDataWrapper pageData = new CasePageDataWrapper();

    // Orchestrate multiple service calls
    loadCaseData(pageData, caseId);
    if (includeRelated) loadRelatedRecords(pageData);
    if (includeBusinessRules) loadBusinessRules(pageData, caseId);
    loadUserContext(pageData);

    return pageData;
}
```

**Key Classes**:
- `CaseDataGovernorService.cls` (318 lines)

---

### 2. UI Service (Layer 3a)

**Purpose**: Prepare data for UI consumption, orchestrate service calls for UI needs

**When to Use**:
- LWC/Aura components need formatted data
- Determining button/field visibility
- Creating UI-specific wrapper objects

**Rules**:
- ✅ **DO**: Use ContextGetters for data
- ✅ **DO**: Delegate to BusinessRuleService for logic
- ✅ **DO**: Return wrapper classes with `@AuraEnabled` properties
- ❌ **DON'T**: Write SOQL queries
- ❌ **DON'T**: Implement business logic
- ❌ **DON'T**: Perform DML operations

**Example**:
```apex
// CaseUIService.cls
@AuraEnabled
public static CaseUIWrapper getCaseMessages(Id caseId) {
    CaseUIWrapper wrapper = new CaseUIWrapper();

    // 1. Load data via ContextGetter
    Case caseObj = CaseContextGetter.getCaseByIdExtended(caseId);

    // 2. Delegate business logic
    BusinessRuleResult ruleResult =
        CaseBusinessRuleService.evaluateBusinessRules(caseId);

    // 3. Populate UI wrapper
    wrapper.caseId = caseObj.Id;
    wrapper.addQuoteVisibility = ruleResult.canAddQuote;

    return wrapper;
}

// Wrapper class for UI
public class CaseUIWrapper {
    @AuraEnabled public String caseId {get;set;}
    @AuraEnabled public String caseNumber {get;set;}
    @AuraEnabled public Boolean addQuoteVisibility {get;set;}
    @AuraEnabled public List<Case> relatedCaseList {get;set;}
}
```

**Key Classes**:
- `CaseUIService.cls` (819 lines)
- `QuoteProcurementUIService.cls`

---

### 3. Business Rule Service (Layer 3b)

**Purpose**: Encapsulate ALL business logic, validations, and rule evaluations

**When to Use**:
- Validating data before DML
- Evaluating approval rules
- Determining field requirements
- Complex business logic calculations

**Rules**:
- ✅ **DO**: Implement pure business logic
- ✅ **DO**: Use ContextGetters for data
- ✅ **DO**: Return result wrapper objects
- ✅ **DO**: Make methods testable in isolation
- ❌ **DON'T**: Include UI concerns
- ❌ **DON'T**: Perform DML operations
- ❌ **DON'T**: Write SOQL (delegate to ContextGetters)

**Example**:
```apex
// CaseBusinessRuleService.cls
public static BusinessRuleResult evaluateBusinessRules(Id caseId) {
    BusinessRuleResult result = new BusinessRuleResult();

    // Get case data via ContextGetter
    Case currentCase = CaseContextGetter.getCaseById(caseId);

    // Evaluate business rules
    if (currentCase.TotalAmount__c > 10000) {
        result.requiresApproval = true;
        result.approvalLevel = 'Senior Manager';
    }

    if (isEligibleForAutoApproval(currentCase)) {
        result.isAutoApproved = true;
    }

    return result;
}

// Result wrapper
public class BusinessRuleResult {
    public Boolean isAutoApproved {get;set;}
    public Boolean requiresApproval {get;set;}
    public String approvalLevel {get;set;}
    public List<String> validationMessages {get;set;}
}
```

**Key Classes**:
- `CaseBusinessRuleService.cls` (1,768 lines)
- `QuoteProcurementBusinessRuleService.cls`

---

### 4. Attribute Service (Layer 3c)

**Purpose**: Initialize records with default values and manage field attributes

**When to Use**:
- Setting default values on record creation
- Calculating derived field values
- Initializing complex object states

**Example**:
```apex
// CaseAttributeService.cls
public static Case initializeCaseDefaults(Id accountId, Id contactId) {
    Case newCase = new Case();

    // Set defaults from related records
    Account acc = AccountContextGetter.getAccountById(accountId);
    newCase.AccountId = accountId;
    newCase.Priority = acc.Default_Case_Priority__c;

    // Set default entitlement
    Entitlement ent = Entitlement_Utility.getDefaultEntitlement(accountId);
    newCase.EntitlementId = ent?.Id;

    return newCase;
}
```

**Key Classes**:
- `CaseAttributeService.cls`

---

### 5. ContextGetter (Layer 4)

**Purpose**: Single source of truth for ALL SOQL queries with caching and bulkification

**When to Use**:
- ANY time you need to query Salesforce data
- Replace direct SOQL queries in any service

**Rules**:
- ✅ **DO**: Implement cache-first pattern
- ✅ **DO**: Define field sets as constants
- ✅ **DO**: Support bulkified queries
- ✅ **DO**: Provide multiple query methods (by Id, by field, etc.)
- ❌ **DON'T**: Include business logic
- ❌ **DON'T**: Perform DML operations

**Example**:
```apex
// CaseContextGetter.cls
public with sharing class CaseContextGetter {
    // Static cache for performance
    private static Map<Id, Case> caseCache = new Map<Id, Case>();

    // Field sets as constants
    private static final String CASE_STANDARD_FIELDS =
        'Id, CaseNumber, Status, AccountId, ContactId, Subject';

    private static final String CASE_EXTENDED_FIELDS =
        CASE_STANDARD_FIELDS + ', Description, Priority, Origin';

    // Cache-first query
    public static Case getCaseById(Id caseId) {
        if (caseCache.containsKey(caseId)) {
            return caseCache.get(caseId);
        }

        String query = 'SELECT ' + CASE_STANDARD_FIELDS +
                       ' FROM Case WHERE Id = :caseId LIMIT 1';
        Case caseRecord = Database.query(query);

        if (caseRecord != null) {
            caseCache.put(caseId, caseRecord);
        }

        return caseRecord;
    }

    // Extended fields query
    public static Case getCaseByIdExtended(Id caseId) {
        String query = 'SELECT ' + CASE_EXTENDED_FIELDS +
                       ' FROM Case WHERE Id = :caseId LIMIT 1';
        return Database.query(query);
    }

    // Bulkified query
    public static Map<Id, Case> getCasesByIds(Set<Id> caseIds) {
        Set<Id> idsToQuery = new Set<Id>();

        // Check cache first
        for (Id caseId : caseIds) {
            if (!caseCache.containsKey(caseId)) {
                idsToQuery.add(caseId);
            }
        }

        // Query only uncached records
        if (!idsToQuery.isEmpty()) {
            String query = 'SELECT ' + CASE_STANDARD_FIELDS +
                           ' FROM Case WHERE Id IN :idsToQuery';
            List<Case> cases = Database.query(query);

            for (Case c : cases) {
                caseCache.put(c.Id, c);
            }
        }

        // Return from cache
        Map<Id, Case> result = new Map<Id, Case>();
        for (Id caseId : caseIds) {
            if (caseCache.containsKey(caseId)) {
                result.put(caseId, caseCache.get(caseId));
            }
        }

        return result;
    }
}
```

**Key Classes**:
- `CaseContextGetter.cls` (914 lines)
- `AccountContextGetter.cls`
- `ContactContextGetter.cls`
- `AssetContextGetter.cls`
- `QuoteContextGetter.cls`
- `TaskContextGetter.cls`
- `WorkOrderContextGetter.cls`
- `QuoteProcurementContextGetter.cls`

---

### 6. DML Service (Layer 5)

**Purpose**: Centralized data persistence with consistent error handling and logging

**When to Use**:
- ANY time you need to insert/update/delete/undelete records
- Replace direct DML operations in any service

**Rules**:
- ✅ **DO**: Use singleton pattern
- ✅ **DO**: Return standardized DMLResult wrappers
- ✅ **DO**: Implement comprehensive error handling
- ✅ **DO**: Log errors via UTIL_LoggingService
- ✅ **DO**: Support partial success scenarios
- ✅ **DO**: Use Database.* methods (not direct DML)
- ❌ **DON'T**: Include business logic
- ❌ **DON'T**: Query data (use ContextGetters)

**Example**:
```apex
// CaseDMLService.cls
public inherited sharing class CaseDMLService {
    // Singleton pattern
    private static CaseDMLService instance;
    private Database.DMLOptions dmlOpts;

    public static CaseDMLService getInstance() {
        if (instance == null) {
            instance = new CaseDMLService();
        }
        return instance;
    }

    // Private constructor
    private CaseDMLService() {
        dmlOpts = new Database.DMLOptions();
        dmlOpts.optAllOrNone = false; // Allow partial success
    }

    // Standardized update operation
    public DMLResult updateCase(Case caseRecord) {
        DMLResult result = new DMLResult();

        try {
            // Validate before DML
            validateCaseForUpdate(caseRecord);

            // Perform DML
            Database.SaveResult dbResult = Database.update(caseRecord, dmlOpts);

            // Process results
            if (dbResult.isSuccess()) {
                result.successCount = 1;
            } else {
                result.hasErrors = true;
                for (Database.Error err : dbResult.getErrors()) {
                    result.errors.add(new DMLError(err));
                }
                result.failureCount = 1;

                // Log error
                UTIL_LoggingService.logError('CaseDMLService',
                    'updateCase',
                    'Failed to update case: ' + caseRecord.Id,
                    dbResult.getErrors());
            }

        } catch (Exception e) {
            result.hasErrors = true;
            result.errors.add(new DMLError(e));
            result.failureCount = 1;

            UTIL_LoggingService.logException(e, 'CaseDMLService', 'updateCase');
        }

        return result;
    }

    // Bulk update operation
    public DMLResult updateCases(List<Case> cases) {
        DMLResult result = new DMLResult();

        try {
            List<Database.SaveResult> dbResults = Database.update(cases, dmlOpts);

            for (Integer i = 0; i < dbResults.size(); i++) {
                Database.SaveResult dbResult = dbResults[i];

                if (dbResult.isSuccess()) {
                    result.successCount++;
                } else {
                    result.hasErrors = true;
                    result.failureCount++;

                    for (Database.Error err : dbResult.getErrors()) {
                        result.errors.add(new DMLError(err));
                    }
                }
            }

            if (result.hasErrors) {
                UTIL_LoggingService.logError('CaseDMLService',
                    'updateCases',
                    'Failed to update ' + result.failureCount + ' cases',
                    null);
            }

        } catch (Exception e) {
            result.hasErrors = true;
            result.errors.add(new DMLError(e));
            UTIL_LoggingService.logException(e, 'CaseDMLService', 'updateCases');
        }

        return result;
    }

    // Validation helper
    private void validateCaseForUpdate(Case caseRecord) {
        if (caseRecord.Id == null) {
            throw new DMLServiceException('Cannot update Case without Id');
        }
    }
}

// Standardized result wrapper
public class DMLResult {
    public Boolean hasErrors {get;set;}
    public List<DMLError> errors {get;set;}
    public Integer successCount {get;set;}
    public Integer failureCount {get;set;}

    public DMLResult() {
        this.hasErrors = false;
        this.errors = new List<DMLError>();
        this.successCount = 0;
        this.failureCount = 0;
    }
}

public class DMLError {
    public String message {get;set;}
    public String fields {get;set;}
    public String statusCode {get;set;}

    public DMLError(Database.Error err) {
        this.message = err.getMessage();
        this.fields = String.join(err.getFields(), ', ');
        this.statusCode = String.valueOf(err.getStatusCode());
    }

    public DMLError(Exception e) {
        this.message = e.getMessage();
        this.statusCode = 'EXCEPTION';
    }
}
```

**Key Classes**:
- `CaseDMLService.cls` (~700 lines)
- `QuoteProcurementDMLService.cls`

---

## How to Reference Each Class

### In LWC Components

```javascript
// Import the Governor Service (preferred)
import getCasePageData from '@salesforce/apex/CaseDataGovernorService.getCasePageData';

// Call the service
getCasePageData({
    caseId: this.recordId,
    includeRelated: true,
    includeBusinessRules: true
})
.then(result => {
    this.caseData = result.caseRecord;
    this.caseUI = result.caseUI;
    this.userContext = result.userContext;
})
.catch(error => {
    // Handle error
});
```

### In Apex Controllers

```apex
// Use the Governor Service for page loads
public class MyCaseController {

    @AuraEnabled(cacheable=false)
    public static CaseDataGovernorService.CasePageDataWrapper getPageData(Id caseId) {
        return CaseDataGovernorService.getCasePageData(caseId, true, true);
    }
}
```

### In Service Classes

```apex
// From UI Service → call ContextGetter + BusinessRuleService
public class MyUIService {

    @AuraEnabled
    public static MyWrapper getData(Id recordId) {
        // 1. Get data via ContextGetter
        Case caseRecord = CaseContextGetter.getCaseById(recordId);

        // 2. Evaluate business rules
        CaseBusinessRuleService.BusinessRuleResult rules =
            CaseBusinessRuleService.evaluateBusinessRules(recordId);

        // 3. Prepare UI wrapper
        MyWrapper wrapper = new MyWrapper();
        wrapper.caseNumber = caseRecord.CaseNumber;
        wrapper.canProgress = rules.isApproved;

        return wrapper;
    }
}
```

### In Business Rule Service

```apex
// From BusinessRuleService → call ContextGetter (no DML!)
public class MyBusinessRuleService {

    public static ValidationResult validateCase(Id caseId) {
        // Get data via ContextGetter
        Case caseRecord = CaseContextGetter.getCaseByIdExtended(caseId);
        Account account = AccountContextGetter.getAccountById(caseRecord.AccountId);

        // Evaluate rules (no DML here!)
        ValidationResult result = new ValidationResult();

        if (caseRecord.Amount__c > account.Credit_Limit__c) {
            result.isValid = false;
            result.errors.add('Amount exceeds credit limit');
        }

        return result;
    }
}
```

### In Trigger or Batch Class

```apex
// From Trigger → call BusinessRuleService + DMLService
trigger CaseTrigger on Case (before update) {

    for (Case c : Trigger.new) {
        // Evaluate business rules
        CaseBusinessRuleService.BusinessRuleResult result =
            CaseBusinessRuleService.evaluateBusinessRules(c.Id);

        // Apply rule results
        if (result.requiresApproval) {
            c.Approval_Required__c = true;
        }
    }
}

// In Batch Class
public class CaseBatch implements Database.Batchable<SObject> {

    public void execute(Database.BatchableContext bc, List<Case> scope) {
        // Evaluate business rules
        for (Case c : scope) {
            CaseBusinessRuleService.BusinessRuleResult result =
                CaseBusinessRuleService.evaluateBusinessRules(c.Id);

            if (result.requiresUpdate) {
                c.Status = 'Updated';
            }
        }

        // Use DML Service for persistence
        CaseDMLService.getInstance().updateCases(scope);
    }
}
```

---

## Common Patterns & Conventions

### 1. Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Governor Service | `[Domain]DataGovernorService` | `CaseDataGovernorService` |
| UI Service | `[Domain]UIService` | `CaseUIService`, `QuoteProcurementUIService` |
| Business Rule Service | `[Domain]BusinessRuleService` | `CaseBusinessRuleService` |
| Attribute Service | `[Domain]AttributeService` | `CaseAttributeService` |
| ContextGetter | `[Domain]ContextGetter` | `CaseContextGetter`, `AccountContextGetter` |
| DML Service | `[Domain]DMLService` | `CaseDMLService`, `QuoteProcurementDMLService` |
| Specialized Service | `[Domain][Function]Service` | `CaseTaskService`, `CaseWorkOrderService` |

### 2. Wrapper Class Pattern

**Use for**: Complex data returns to UI components

```apex
public class MyWrapper {
    @AuraEnabled public String recordId {get;set;}
    @AuraEnabled public String recordName {get;set;}
    @AuraEnabled public Boolean isEditable {get;set;}
    @AuraEnabled public List<RelatedRecord> relatedRecords {get;set;}

    public MyWrapper() {
        this.relatedRecords = new List<RelatedRecord>();
    }
}
```

**Found in**:
- `CaseUIService.CaseUIWrapper`
- `CaseDataGovernorService.CasePageDataWrapper`
- `QuoteProcurementUIService.ProductsWrapper`

### 3. Singleton Pattern

**Use for**: Services requiring consistent configuration (DML Services)

```apex
private static MyService instance;

public static MyService getInstance() {
    if (instance == null) {
        instance = new MyService();
    }
    return instance;
}

private MyService() {
    // Initialize configuration
}
```

### 4. Result Wrapper Pattern

**Use for**: Standardized operation results (DML, validation, business rules)

```apex
public class OperationResult {
    public Boolean isSuccess {get;set;}
    public Boolean hasErrors {get;set;}
    public List<String> errors {get;set;}
    public String message {get;set;}

    public OperationResult() {
        this.isSuccess = true;
        this.hasErrors = false;
        this.errors = new List<String>();
    }
}
```

### 5. Constant Field Sets

**Use for**: Consistent field selection across ContextGetters

```apex
private static final String CASE_STANDARD_FIELDS =
    'Id, CaseNumber, Status, AccountId, ContactId';

private static final String CASE_EXTENDED_FIELDS =
    CASE_STANDARD_FIELDS + ', Description, Priority, Origin';

private static final String CASE_ALL_FIELDS =
    CASE_EXTENDED_FIELDS + ', Custom_Field_1__c, Custom_Field_2__c';
```

### 6. Cache-First Query Pattern

**Use for**: Performance optimization in ContextGetters

```apex
private static Map<Id, MyObject__c> cache = new Map<Id, MyObject__c>();

public static MyObject__c getById(Id recordId) {
    // Check cache first
    if (cache.containsKey(recordId)) {
        return cache.get(recordId);
    }

    // Query if not cached
    String query = 'SELECT ' + STANDARD_FIELDS + ' FROM MyObject__c WHERE Id = :recordId';
    MyObject__c record = Database.query(query);

    // Cache for future use
    if (record != null) {
        cache.put(recordId, record);
    }

    return record;
}
```

### 7. Bulkification Pattern

**Use for**: All ContextGetters and DML Services

```apex
// Bulkified ContextGetter method
public static Map<Id, Case> getCasesByIds(Set<Id> caseIds) {
    Map<Id, Case> results = new Map<Id, Case>();
    Set<Id> idsToQuery = new Set<Id>();

    // Check cache
    for (Id caseId : caseIds) {
        if (caseCache.containsKey(caseId)) {
            results.put(caseId, caseCache.get(caseId));
        } else {
            idsToQuery.add(caseId);
        }
    }

    // Bulk query uncached records
    if (!idsToQuery.isEmpty()) {
        String query = 'SELECT ' + CASE_STANDARD_FIELDS +
                       ' FROM Case WHERE Id IN :idsToQuery';
        List<Case> cases = Database.query(query);

        for (Case c : cases) {
            caseCache.put(c.Id, c);
            results.put(c.Id, c);
        }
    }

    return results;
}
```

---

## Expanding the Architecture

### Adding a New Domain (e.g., Opportunity)

Follow this step-by-step process:

#### Step 1: Create the ContextGetter

```apex
// OpportunityContextGetter.cls
public with sharing class OpportunityContextGetter {

    // 1. Define static cache
    private static Map<Id, Opportunity> oppCache = new Map<Id, Opportunity>();

    // 2. Define field sets as constants
    private static final String OPP_STANDARD_FIELDS =
        'Id, Name, AccountId, Amount, StageName, CloseDate';

    private static final String OPP_EXTENDED_FIELDS =
        OPP_STANDARD_FIELDS + ', Description, Probability, Type';

    // 3. Implement cache-first query
    public static Opportunity getOpportunityById(Id oppId) {
        if (oppCache.containsKey(oppId)) {
            return oppCache.get(oppId);
        }

        String query = 'SELECT ' + OPP_STANDARD_FIELDS +
                       ' FROM Opportunity WHERE Id = :oppId LIMIT 1';
        Opportunity opp = Database.query(query);

        if (opp != null) {
            oppCache.put(oppId, opp);
        }

        return opp;
    }

    // 4. Add extended fields method
    public static Opportunity getOpportunityByIdExtended(Id oppId) {
        String query = 'SELECT ' + OPP_EXTENDED_FIELDS +
                       ' FROM Opportunity WHERE Id = :oppId LIMIT 1';
        return Database.query(query);
    }

    // 5. Add bulk query method
    public static Map<Id, Opportunity> getOpportunitiesByIds(Set<Id> oppIds) {
        // Implement cache-first bulk query pattern
        // (See CaseContextGetter for reference)
    }
}
```

**Test Coverage**: Create `OpportunityContextGetter_Test.cls`

---

#### Step 2: Create the DML Service

```apex
// OpportunityDMLService.cls
public inherited sharing class OpportunityDMLService {

    // 1. Singleton pattern
    private static OpportunityDMLService instance;
    private Database.DMLOptions dmlOpts;

    public static OpportunityDMLService getInstance() {
        if (instance == null) {
            instance = new OpportunityDMLService();
        }
        return instance;
    }

    // 2. Private constructor
    private OpportunityDMLService() {
        dmlOpts = new Database.DMLOptions();
        dmlOpts.optAllOrNone = false;
    }

    // 3. Insert method
    public DMLResult insertOpportunity(Opportunity opp) {
        DMLResult result = new DMLResult();

        try {
            Database.SaveResult dbResult = Database.insert(opp, dmlOpts);

            if (dbResult.isSuccess()) {
                result.successCount = 1;
            } else {
                result.hasErrors = true;
                for (Database.Error err : dbResult.getErrors()) {
                    result.errors.add(new DMLError(err));
                }
                UTIL_LoggingService.logError('OpportunityDMLService',
                    'insertOpportunity',
                    'Failed to insert opportunity',
                    dbResult.getErrors());
            }
        } catch (Exception e) {
            result.hasErrors = true;
            result.errors.add(new DMLError(e));
            UTIL_LoggingService.logException(e, 'OpportunityDMLService', 'insertOpportunity');
        }

        return result;
    }

    // 4. Update method
    public DMLResult updateOpportunity(Opportunity opp) {
        // Similar to insert
    }

    // 5. Bulk methods
    public DMLResult insertOpportunities(List<Opportunity> opps) {
        // Bulk insert
    }

    public DMLResult updateOpportunities(List<Opportunity> opps) {
        // Bulk update
    }
}

// 6. Reuse DMLResult and DMLError classes from CaseDMLService
```

**Test Coverage**: Create `OpportunityDMLService_Test.cls`

---

#### Step 3: Create the Business Rule Service

```apex
// OpportunityBusinessRuleService.cls
public without sharing class OpportunityBusinessRuleService {

    // 1. Validation method
    public static ValidationResult validateOpportunity(Id oppId) {
        ValidationResult result = new ValidationResult();

        // Get data via ContextGetter
        Opportunity opp = OpportunityContextGetter.getOpportunityByIdExtended(oppId);

        // Business rule validation
        if (opp.Amount > 1000000 && String.isBlank(opp.Description)) {
            result.isValid = false;
            result.errors.add('Large opportunities require a description');
        }

        if (opp.Probability > 75 && opp.StageName == 'Prospecting') {
            result.isValid = false;
            result.errors.add('Stage does not match probability');
        }

        return result;
    }

    // 2. Business rule evaluation
    public static BusinessRuleResult evaluateBusinessRules(Id oppId) {
        BusinessRuleResult result = new BusinessRuleResult();

        Opportunity opp = OpportunityContextGetter.getOpportunityById(oppId);

        // Determine if requires approval
        if (opp.Amount > 500000) {
            result.requiresApproval = true;
            result.approvalLevel = 'VP Sales';
        }

        return result;
    }

    // 3. Result wrapper classes
    public class ValidationResult {
        public Boolean isValid {get;set;}
        public List<String> errors {get;set;}

        public ValidationResult() {
            this.isValid = true;
            this.errors = new List<String>();
        }
    }

    public class BusinessRuleResult {
        public Boolean requiresApproval {get;set;}
        public String approvalLevel {get;set;}
        public Boolean isAutoApproved {get;set;}

        public BusinessRuleResult() {
            this.requiresApproval = false;
            this.isAutoApproved = false;
        }
    }
}
```

**Test Coverage**: Create `OpportunityBusinessRuleService_Test.cls`

---

#### Step 4: Create the UI Service

```apex
// OpportunityUIService.cls
public with sharing class OpportunityUIService {

    // 1. Main UI method
    @AuraEnabled
    public static OpportunityUIWrapper getOpportunityUI(Id oppId) {
        OpportunityUIWrapper wrapper = new OpportunityUIWrapper();

        // Get opportunity data
        Opportunity opp = OpportunityContextGetter.getOpportunityByIdExtended(oppId);
        wrapper.opportunityId = opp.Id;
        wrapper.opportunityName = opp.Name;
        wrapper.amount = opp.Amount;

        // Evaluate business rules
        OpportunityBusinessRuleService.BusinessRuleResult rules =
            OpportunityBusinessRuleService.evaluateBusinessRules(oppId);

        // Determine visibility
        wrapper.showApprovalButton = rules.requiresApproval;
        wrapper.isEditable = !rules.requiresApproval;

        return wrapper;
    }

    // 2. UI Wrapper class
    public class OpportunityUIWrapper {
        @AuraEnabled public String opportunityId {get;set;}
        @AuraEnabled public String opportunityName {get;set;}
        @AuraEnabled public Decimal amount {get;set;}
        @AuraEnabled public Boolean showApprovalButton {get;set;}
        @AuraEnabled public Boolean isEditable {get;set;}

        public OpportunityUIWrapper() {
            this.showApprovalButton = false;
            this.isEditable = true;
        }
    }
}
```

**Test Coverage**: Create `OpportunityUIService_Test.cls`

---

#### Step 5: Create the Governor Service (Optional)

Only create if you have complex page loads requiring multiple service calls.

```apex
// OpportunityDataGovernorService.cls
public with sharing class OpportunityDataGovernorService {

    @AuraEnabled(cacheable=false)
    public static OpportunityPageDataWrapper getOpportunityPageData(
        Id oppId,
        Boolean includeRelated,
        Boolean includeBusinessRules
    ) {
        OpportunityPageDataWrapper pageData = new OpportunityPageDataWrapper();

        // Load opportunity data
        pageData.opportunity = OpportunityContextGetter.getOpportunityByIdExtended(oppId);

        // Load UI data
        pageData.opportunityUI = OpportunityUIService.getOpportunityUI(oppId);

        // Optionally load related records
        if (includeRelated) {
            loadRelatedRecords(pageData, oppId);
        }

        // Optionally load business rules
        if (includeBusinessRules) {
            pageData.businessRules =
                OpportunityBusinessRuleService.evaluateBusinessRules(oppId);
        }

        return pageData;
    }

    private static void loadRelatedRecords(OpportunityPageDataWrapper pageData, Id oppId) {
        // Load account, contact, etc.
        if (pageData.opportunity.AccountId != null) {
            pageData.account =
                AccountContextGetter.getAccountById(pageData.opportunity.AccountId);
        }
    }

    // Wrapper class
    public class OpportunityPageDataWrapper {
        @AuraEnabled public Opportunity opportunity {get;set;}
        @AuraEnabled public OpportunityUIService.OpportunityUIWrapper opportunityUI {get;set;}
        @AuraEnabled public Account account {get;set;}
        @AuraEnabled public OpportunityBusinessRuleService.BusinessRuleResult businessRules {get;set;}
    }
}
```

**Test Coverage**: Create `OpportunityDataGovernorService_Test.cls`

---

### Adding a New Function to Existing Domain

#### Example: Add "Clone Case" functionality

**Step 1: Add to Business Rule Service**

```apex
// CaseBusinessRuleService.cls
public static CloneValidationResult validateCaseForCloning(Id caseId) {
    CloneValidationResult result = new CloneValidationResult();

    // Get case data
    Case caseRecord = CaseContextGetter.getCaseByIdExtended(caseId);

    // Validate business rules for cloning
    if (caseRecord.Status == 'Closed') {
        result.canClone = false;
        result.errors.add('Cannot clone closed cases');
    }

    if (caseRecord.RecordType.DeveloperName == 'Internal') {
        result.canClone = false;
        result.errors.add('Cannot clone internal cases');
    }

    return result;
}

public class CloneValidationResult {
    public Boolean canClone {get;set;}
    public List<String> errors {get;set;}

    public CloneValidationResult() {
        this.canClone = true;
        this.errors = new List<String>();
    }
}
```

**Step 2: Add to Specialized Service (or create CaseCloneService)**

```apex
// CaseCloneService.cls
public with sharing class CaseCloneService {

    @AuraEnabled
    public static CloneResult cloneCase(Id caseId) {
        CloneResult result = new CloneResult();

        try {
            // 1. Validate can clone
            CaseBusinessRuleService.CloneValidationResult validation =
                CaseBusinessRuleService.validateCaseForCloning(caseId);

            if (!validation.canClone) {
                result.success = false;
                result.errors = validation.errors;
                return result;
            }

            // 2. Get source case
            Case sourceCase = CaseContextGetter.getCaseByIdExtended(caseId);

            // 3. Create cloned case
            Case clonedCase = sourceCase.clone(false, true, false, false);
            clonedCase.Status = 'New';
            clonedCase.Subject = 'Clone of: ' + sourceCase.Subject;

            // 4. Insert via DML Service
            CaseDMLService.DMLResult dmlResult =
                CaseDMLService.getInstance().insertCase(clonedCase);

            if (dmlResult.hasErrors) {
                result.success = false;
                result.errors.add('Failed to insert cloned case');
            } else {
                result.success = true;
                result.clonedCaseId = clonedCase.Id;
            }

        } catch (Exception e) {
            result.success = false;
            result.errors.add(e.getMessage());
            UTIL_LoggingService.logException(e, 'CaseCloneService', 'cloneCase');
        }

        return result;
    }

    public class CloneResult {
        @AuraEnabled public Boolean success {get;set;}
        @AuraEnabled public Id clonedCaseId {get;set;}
        @AuraEnabled public List<String> errors {get;set;}

        public CloneResult() {
            this.success = true;
            this.errors = new List<String>();
        }
    }
}
```

**Step 3: Update UI Service (if needed)**

```apex
// CaseUIService.cls
@AuraEnabled
public static CaseUIWrapper getCaseMessages(Id caseId) {
    CaseUIWrapper wrapper = new CaseUIWrapper();

    // Existing code...

    // Add clone button visibility
    CaseBusinessRuleService.CloneValidationResult cloneValidation =
        CaseBusinessRuleService.validateCaseForCloning(caseId);
    wrapper.showCloneButton = cloneValidation.canClone;

    return wrapper;
}

// Update wrapper class
public class CaseUIWrapper {
    // Existing fields...
    @AuraEnabled public Boolean showCloneButton {get;set;}
}
```

---

### Creating Utility Classes

For cross-cutting concerns that don't fit into a specific domain service:

#### Example: Create Date Calculation Utility

```apex
// UTIL_DateCalculation.cls
public with sharing class UTIL_DateCalculation {

    // Calculate business days between dates
    public static Integer calculateBusinessDays(Date startDate, Date endDate) {
        Integer businessDays = 0;
        Date currentDate = startDate;

        while (currentDate <= endDate) {
            // Check if weekday (not Saturday or Sunday)
            Datetime dt = Datetime.newInstance(currentDate, Time.newInstance(0, 0, 0, 0));
            String dayOfWeek = dt.format('E');

            if (dayOfWeek != 'Sat' && dayOfWeek != 'Sun') {
                businessDays++;
            }

            currentDate = currentDate.addDays(1);
        }

        return businessDays;
    }

    // Add business days to a date
    public static Date addBusinessDays(Date startDate, Integer daysToAdd) {
        Date currentDate = startDate;
        Integer daysAdded = 0;

        while (daysAdded < daysToAdd) {
            currentDate = currentDate.addDays(1);

            Datetime dt = Datetime.newInstance(currentDate, Time.newInstance(0, 0, 0, 0));
            String dayOfWeek = dt.format('E');

            if (dayOfWeek != 'Sat' && dayOfWeek != 'Sun') {
                daysAdded++;
            }
        }

        return currentDate;
    }
}
```

**Naming Convention**: `UTIL_[FunctionName]`

**Examples in codebase**:
- `UTIL_LoggingService.cls` - Centralized logging
- `UTIL_ErrorConstants.cls` - Error message constants
- `SLACalculationUtility.cls` - SLA date calculations
- `Entitlement_Utility.cls` - Entitlement resolution

---

## Quick Checklist

### Before Writing Code

- [ ] Identified which layer this functionality belongs to
- [ ] Checked if a service already exists for this domain
- [ ] Reviewed existing patterns in similar services
- [ ] Planned where to put business logic vs. UI logic

### Creating a New Service

- [ ] Named according to convention: `[Domain][Type]Service`
- [ ] Placed in correct layer (UI, Business Rule, DML, etc.)
- [ ] Followed appropriate pattern (Singleton for DML, etc.)
- [ ] Created wrapper classes for complex returns
- [ ] Added comprehensive error handling
- [ ] Logged errors via `UTIL_LoggingService`
- [ ] Created corresponding test class

### Creating a ContextGetter

- [ ] Defined field sets as `private static final String` constants
- [ ] Implemented static cache: `private static Map<Id, SObject>`
- [ ] Created cache-first query methods
- [ ] Added bulkified query methods
- [ ] Used `with sharing` for security
- [ ] Created test class with cache coverage

### Creating a DML Service

- [ ] Used singleton pattern
- [ ] Implemented `Database.*` methods (not direct DML)
- [ ] Used `Database.DMLOptions` with `optAllOrNone = false`
- [ ] Returned standardized `DMLResult` wrapper
- [ ] Logged all errors via `UTIL_LoggingService`
- [ ] Used `inherited sharing` for security
- [ ] Created test class with error scenarios

### Creating a UI Service

- [ ] Method is `@AuraEnabled`
- [ ] NO SOQL queries (delegates to ContextGetters)
- [ ] NO business logic (delegates to BusinessRuleService)
- [ ] Returns wrapper classes with `@AuraEnabled` properties
- [ ] Used `with sharing` for security
- [ ] Created test class

### Creating a Business Rule Service

- [ ] NO UI concerns (pure business logic)
- [ ] NO SOQL queries (delegates to ContextGetters)
- [ ] NO DML operations (returns results only)
- [ ] Returns result wrapper objects
- [ ] Methods are testable in isolation
- [ ] Used `without sharing` if cross-record validation needed
- [ ] Created comprehensive test class

### Code Review Checklist

- [ ] No SOQL in controllers or UI services
- [ ] No business logic in UI services
- [ ] No DML outside DML services
- [ ] All queries use ContextGetters
- [ ] All DML uses DML services
- [ ] Proper error handling and logging
- [ ] Follows naming conventions
- [ ] Test coverage > 85%
- [ ] Bulkification for triggers/batch

---

## Additional Resources

### Detailed Documentation

- **Entitlement & SLA Guide**: `/home/user/Ideal-SOLID/documentation/Entitlement_and_SLA_Service_Layer_Guide.md` (1,294 lines)
  - Comprehensive guide for Entitlement_Utility and SLACalculationUtility
  - Integration patterns
  - External API integration examples

- **Architecture Documentation**: `/home/user/Ideal-SOLID/ARCHITECTURE_DOCUMENTATION.md`
  - Overall system architecture
  - Design decisions and rationale

### Key Service Examples

| Service | Lines | Purpose |
|---------|-------|---------|
| `CaseBusinessRuleService.cls` | 1,768 | Business logic pattern |
| `CaseContextGetter.cls` | 914 | Data access pattern |
| `CaseUIService.cls` | 819 | UI orchestration pattern |
| `CaseDMLService.cls` | ~700 | Persistence pattern |
| `CaseDataGovernorService.cls` | 318 | Governor pattern |

### Common Mistakes to Avoid

1. **SOQL in Controllers**: Always delegate to ContextGetters
2. **Business Logic in UI Services**: Delegate to BusinessRuleService
3. **Direct DML**: Always use DML Services
4. **Mixing Concerns**: Keep each service focused on its layer
5. **Not Bulkifying**: Always support bulk operations
6. **Skipping Error Handling**: Use try/catch and log errors
7. **Inconsistent Naming**: Follow naming conventions
8. **Poor Test Coverage**: Aim for > 85% coverage

---

## Summary

The Ideal-SOLID service layer architecture provides a robust, scalable foundation for building Salesforce applications. By following these patterns and conventions, you ensure:

✅ **Performance**: 90% reduction in API calls, 85% reduction in SOQL queries
✅ **Maintainability**: Clear separation of concerns, easy to locate functionality
✅ **Testability**: Each service can be tested in isolation
✅ **Scalability**: Bulkification and caching built-in
✅ **Consistency**: Standardized patterns across the entire codebase

**Remember the golden rules**:
1. No SOQL in controllers or UI services
2. No business logic in UI services
3. No DML outside DML services
4. Always use ContextGetters for queries
5. Always use DML Services for persistence
6. Always log errors via UTIL_LoggingService

---

**Questions or need clarification?** Refer to the detailed documentation in `/home/user/Ideal-SOLID/documentation/` or review the exemplar services listed in this guide.
