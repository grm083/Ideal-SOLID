# CLAUDE.md - AI Assistant Guide for Ideal-SOLID Repository

**Version:** 1.0
**Last Updated:** 2025-12-01
**Purpose:** Comprehensive guide for AI assistants working with the Ideal-SOLID codebase

---

## Table of Contents

1. [Repository Overview](#repository-overview)
2. [Technology Stack](#technology-stack)
3. [Architecture & Design Patterns](#architecture--design-patterns)
4. [Directory Structure](#directory-structure)
5. [Service Layer Guidelines](#service-layer-guidelines)
6. [Naming Conventions](#naming-conventions)
7. [Code Standards & Best Practices](#code-standards--best-practices)
8. [Development Workflow](#development-workflow)
9. [Testing Strategy](#testing-strategy)
10. [Common Tasks & Examples](#common-tasks--examples)
11. [Key Documentation](#key-documentation)
12. [Golden Rules (CRITICAL)](#golden-rules-critical)

---

## Repository Overview

### Project Purpose

Ideal-SOLID is an **enterprise-grade Salesforce Lightning platform application** implementing a sophisticated **Waste Management Service System** with Case Management at its core. The project demonstrates a systematic refactoring from monolithic Aura components to modern Lightning Web Components (LWC) with a well-architected service layer following SOLID principles.

### Business Domain

- **Primary Focus:** Service request management (pickups, equipment changes, service modifications)
- **Asset Management:** Container, rolloff, baler, and compactor tracking
- **Work Order Management:** Automated vendor assignment and routing
- **Quote & Pricing:** CPQ integration for multi-vendor quoting
- **SLA Management:** Service level agreement calculations with business hours

### Key Achievements

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Apex Calls per Page Load | 10-15 | 1 | **90% reduction** |
| SOQL Queries per Page | 25-40 | 3-5 | **85% reduction** |
| Page Load Time | 3-5 seconds | 1-2 seconds | **60% faster** |
| Component Attributes | 72 | 28 | **61% reduction** |

---

## Technology Stack

### Platform & Languages

- **Platform:** Salesforce Lightning Platform (API v62.0)
- **Backend:** Apex (58,224 lines across 130 classes)
- **Frontend:**
  - Lightning Web Components (LWC) - 90+ components (modern)
  - Aura Components - 200+ components (legacy, being phased out)
- **Markup:** HTML5, CSS3, JavaScript (ES6+)
- **Query Language:** SOQL (Salesforce Object Query Language)

### Key Integrations

- **Salesforce CPQ** - Quote and opportunity management
- **Genesys** - Call center routing and agent identification
- **Lightning Message Service (LMS)** - Component communication
- **Acorn** - Legacy work order system
- **OfficeTrax** - Service management system

### Deployment

- **Metadata API:** Standard Salesforce deployment tools
- **Package-based:** Using package.xml manifest (21,657 bytes)
- **Version Control:** Git with feature branch workflow
- **No SFDX Project:** Traditional Salesforce development approach

---

## Architecture & Design Patterns

### 5-Tier Service Architecture

```
┌─────────────────────────────────────────────────────┐
│  Layer 1: Lightning Web Components (UI)             │
│  - User interaction and display logic               │
│  - LWC/Aura components                              │
└────────────────────┬────────────────────────────────┘
                     │ @AuraEnabled calls
┌────────────────────▼────────────────────────────────┐
│  Layer 2: Governor Service (Orchestration)          │
│  - CaseDataGovernorService                          │
│  - Consolidates 15 calls → 1 call                   │
│  - Returns comprehensive data wrapper               │
└────────────────────┬────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
┌───────▼──────┐ ┌──▼──────────┐ ┌▼─────────────┐
│ Layer 3a:    │ │ Layer 3b:   │ │ Layer 3c:    │
│ UI Service   │ │ Business    │ │ Attribute    │
│              │ │ Rule Service│ │ Service      │
│ - Wrappers   │ │ - Logic     │ │ - Defaults   │
│ - UI prep    │ │ - Rules     │ │ - Init       │
└───────┬──────┘ └──┬──────────┘ └┬─────────────┘
        │           │              │
        └───────────┴──────────────┘
                    │
┌───────────────────▼─────────────────────────────────┐
│  Layer 4: ContextGetter (Data Access)               │
│  - CaseContextGetter, AccountContextGetter, etc.    │
│  - Cache-first query pattern                        │
│  - Single source of truth for SOQL                  │
│  - Bulkification and optimization                   │
└───────────────────┬─────────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────────┐
│  Layer 5: DML Service (Data Persistence)            │
│  - CaseDMLService, QuoteProcurementDMLService       │
│  - All DML operations centralized                   │
│  - Error handling and logging                       │
└─────────────────────────────────────────────────────┘
```

### SOLID Principles Implementation

#### Single Responsibility Principle (SRP)
- **CaseBusinessRuleService:** ONLY business logic, no data access or DML
- **CaseContextGetter:** ONLY data queries, no business logic
- **CaseDMLService:** ONLY database operations, no business logic
- **CaseUIService:** ONLY UI preparation, delegates everything else

#### Open/Closed Principle (OCP)
- Services are open for extension through inheritance
- New service types added without modifying existing services
- Business rules configurable via Custom Metadata Types

#### Liskov Substitution Principle (LSP)
- All services return consistent wrapper/result objects
- Standardized DMLResult, ValidationResult, BusinessRuleResult patterns
- Services can be mocked for testing

#### Interface Segregation Principle (ISP)
- Focused public methods (e.g., `validatePickupAsset()` vs `validateNonPickupAsset()`)
- Clients depend only on methods they need
- Multiple specialized services instead of monolithic classes

#### Dependency Inversion Principle (DIP)
- Services depend on ContextGetters (abstraction), not direct SOQL
- DML operations depend on DMLService (abstraction), not direct DML
- Business logic depends on result objects, not concrete implementations

### Design Patterns Used

1. **Repository Pattern:** ContextGetter classes act as data repositories
2. **Singleton Pattern:** DMLService classes for configuration consistency
3. **Facade Pattern:** Governor Service provides simplified interface
4. **Strategy Pattern:** Business rules evaluated dynamically via metadata
5. **Observer Pattern:** Lightning Message Service for component communication
6. **Factory Pattern:** TestDataFactoryRefactored for test data creation
7. **Wrapper Pattern:** Extensive use of wrapper classes for data transfer
8. **Trigger Handler Pattern:** Thin orchestration delegating to services

---

## Directory Structure

```
/home/user/Ideal-SOLID/
├── classes/                    # Apex classes (130 classes)
│   ├── *Service.cls           # 25 service layer classes
│   │   ├── CaseDataGovernorService.cls      (Layer 2 - Orchestration)
│   │   ├── CaseUIService.cls                (Layer 3a - UI prep)
│   │   ├── CaseBusinessRuleService.cls      (Layer 3b - Business logic)
│   │   ├── CaseAttributeService.cls         (Layer 3c - Initialization)
│   │   └── CaseDMLService.cls               (Layer 5 - Persistence)
│   │
│   ├── *Controller.cls        # 20 controller classes for LWC
│   ├── *ContextGetter.cls     # 8 data access layer classes (Layer 4)
│   │   ├── CaseContextGetter.cls
│   │   ├── AccountContextGetter.cls
│   │   ├── ContactContextGetter.cls
│   │   ├── AssetContextGetter.cls
│   │   └── ...
│   │
│   ├── *TriggerHandler.cls    # Trigger orchestration classes
│   ├── *Test.cls              # 53 test classes (>85% coverage)
│   └── UTIL_*.cls             # Shared utility classes
│       └── UTIL_LoggingService.cls
│
├── lwc/                       # Lightning Web Components (90+ components)
│   ├── caseDataGovernorLWC/           # Governor pattern - data orchestration
│   ├── customCaseHighlightPanelLWC/   # Case highlight panel
│   ├── showCaseMessagesLWC/           # Case messages display
│   ├── actionMessagesPanelLWC/        # Action messages
│   └── .../*LWC/              # All LWCs have "LWC" suffix
│
├── aura/                      # Aura Components (200+ legacy components)
│   ├── CaseCreationComponent/
│   ├── CustomCaseHighlightPanel/
│   └── .../                   # Being migrated to LWC
│
├── objects/                   # Custom Objects & Extensions
│   ├── Case.object            # Heavily customized
│   ├── Asset.object           # Equipment tracking
│   ├── Account.object         # Client/Location records
│   └── .../*__c.object        # 400+ custom objects
│
├── messageChannels/           # Lightning Message Service
│   ├── CaseDataChannel.messageChannel-meta.xml
│   └── CaseUpdated__c.messageChannel-meta.xml
│
├── documentation/             # Technical documentation (detailed)
│   ├── Service_Layer_Quick_Reference.md       (1,429 lines)
│   ├── Entitlement_and_SLA_Service_Layer_Guide.md
│   ├── Case_Trigger_Architecture.md           (1,128 lines)
│   ├── Production_Support_Debugging_Guide.md
│   └── .../*.md
│
├── docs/                      # User-facing documentation
│   ├── USER_SCENARIOS.md              # Given/When/Then scenarios
│   ├── LWC_NAMING_CONVENTION.md       # LWC naming standards
│   ├── GOVERNOR_ARCHITECTURE.md       # API call reduction strategy
│   ├── COMPONENT_REFACTORING_GUIDE.md
│   └── .../*.md
│
├── ARCHITECTURE_DOCUMENTATION.md      # Main architecture guide (96KB)
├── package.xml                        # Salesforce package manifest
├── PHASE*_COMPLETION_SUMMARY.md       # Refactoring progress tracking
└── CLAUDE.md                          # This file
```

---

## Service Layer Guidelines

### Service Types & Responsibilities

| Service Type | Purpose | Layer | Example |
|-------------|---------|-------|---------|
| **Governor Service** | Consolidate multiple calls into single response | Layer 2 | `CaseDataGovernorService` |
| **UI Service** | Prepare data for UI, orchestrate service calls | Layer 3a | `CaseUIService` |
| **Business Rule Service** | Business logic, validations, rules | Layer 3b | `CaseBusinessRuleService` |
| **Attribute Service** | Default values, initialization | Layer 3c | `CaseAttributeService` |
| **ContextGetter** | Data access with caching | Layer 4 | `CaseContextGetter` |
| **DML Service** | Database operations, error handling | Layer 5 | `CaseDMLService` |
| **Utility** | Shared utilities | Cross-cutting | `UTIL_LoggingService` |

### Layer Interaction Rules

#### ✅ ALLOWED Interactions

```apex
// LWC → Governor Service
@AuraEnabled
public static CasePageDataWrapper getCasePageData(Id caseId) {
    return CaseDataGovernorService.getCasePageData(caseId, true, true);
}

// Governor Service → UI Service
wrapper.caseUI = CaseUIService.getCaseUIWrapper(caseId);

// UI Service → ContextGetter
Case caseRecord = CaseContextGetter.getCaseById(caseId);

// UI Service → Business Rule Service
BusinessRuleResult result = CaseBusinessRuleService.evaluateBusinessRules(caseId);

// Any Service → DML Service
DMLResult result = CaseDMLService.getInstance().updateCase(caseRecord);
```

#### ❌ FORBIDDEN Interactions

```apex
// ❌ NEVER: Controller → Database directly
@AuraEnabled
public static Case getCase(Id caseId) {
    return [SELECT Id FROM Case WHERE Id = :caseId]; // WRONG!
}

// ❌ NEVER: UI Service → Business Logic directly
// (in CaseUIService)
if (caseRecord.Amount__c > 10000) {  // WRONG!
    wrapper.requiresApproval = true;
}

// ❌ NEVER: Business Rule Service → DML directly
// (in CaseBusinessRuleService)
update caseRecord; // WRONG!

// ❌ NEVER: ContextGetter → Business Logic
// (in CaseContextGetter)
if (caseRecord.Status == 'Open') { // WRONG!
    // Business logic doesn't belong here
}
```

### ContextGetter Cache-First Pattern

All data access MUST use ContextGetters with this pattern:

```apex
public class CaseContextGetter {
    // Static cache for request scope
    private static Map<Id, Case> caseCache = new Map<Id, Case>();

    /**
     * Get Case by ID with caching
     * @param caseId Case record ID
     * @return Case record with all required fields
     */
    public static Case getCaseById(Id caseId) {
        // 1. Check cache first
        if (caseCache.containsKey(caseId)) {
            return caseCache.get(caseId);
        }

        // 2. Query if not cached
        Case caseRecord = [
            SELECT Id, CaseNumber, Status, Origin, Type, Priority,
                   AccountId, ContactId, AssetId, Subject, Description
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        // 3. Cache for future use
        caseCache.put(caseId, caseRecord);

        return caseRecord;
    }

    /**
     * Clear cache (for testing or after DML)
     */
    public static void clearCache() {
        caseCache.clear();
    }
}
```

### DML Service Pattern

All database operations MUST go through DML Services:

```apex
public class CaseDMLService {
    private static CaseDMLService instance;

    // Singleton pattern
    public static CaseDMLService getInstance() {
        if (instance == null) {
            instance = new CaseDMLService();
        }
        return instance;
    }

    /**
     * Update a single Case record
     * @param caseRecord Case to update
     * @return DMLResult with success/error details
     */
    public DMLResult updateCase(Case caseRecord) {
        DMLResult result = new DMLResult();
        try {
            update caseRecord;
            result.isSuccess = true;
            result.recordId = caseRecord.Id;
        } catch (DmlException e) {
            result.isSuccess = false;
            result.errorMessage = e.getMessage();
            UTIL_LoggingService.logException(
                e,
                'CaseDMLService',
                'updateCase'
            );
        }
        return result;
    }

    /**
     * DML Result wrapper
     */
    public class DMLResult {
        @AuraEnabled public Boolean isSuccess {get;set;}
        @AuraEnabled public String errorMessage {get;set;}
        @AuraEnabled public Id recordId {get;set;}

        public DMLResult() {
            this.isSuccess = false;
        }
    }
}
```

### Wrapper Class Pattern

All UI-facing methods MUST return wrapper classes:

```apex
public class CaseUIService {
    /**
     * Case UI Wrapper for component consumption
     */
    public class CaseUIWrapper {
        @AuraEnabled public String caseId {get;set;}
        @AuraEnabled public String caseNumber {get;set;}
        @AuraEnabled public Boolean showProgressButton {get;set;}
        @AuraEnabled public Boolean showCloseButton {get;set;}
        @AuraEnabled public List<Task> relatedTasks {get;set;}
        @AuraEnabled public Map<String, String> picklistValues {get;set;}

        public CaseUIWrapper() {
            this.relatedTasks = new List<Task>();
            this.picklistValues = new Map<String, String>();
        }
    }

    /**
     * Get Case UI data
     */
    @AuraEnabled
    public static CaseUIWrapper getCaseUIWrapper(Id caseId) {
        CaseUIWrapper wrapper = new CaseUIWrapper();

        // 1. Get data from ContextGetter
        Case caseRecord = CaseContextGetter.getCaseById(caseId);

        // 2. Delegate business logic
        BusinessRuleResult ruleResult =
            CaseBusinessRuleService.evaluateBusinessRules(caseId);

        // 3. Populate wrapper
        wrapper.caseId = caseRecord.Id;
        wrapper.caseNumber = caseRecord.CaseNumber;
        wrapper.showProgressButton = ruleResult.canProgress;
        wrapper.showCloseButton = ruleResult.canClose;

        return wrapper;
    }
}
```

---

## Naming Conventions

### LWC Component Naming (CRITICAL)

**To avoid Aura/LWC conflicts during migration, ALL LWC components have "LWC" suffix:**

#### Directory Structure
```
✅ CORRECT:
lwc/customCaseHighlightPanelLWC/
    ├── customCaseHighlightPanelLWC.js
    ├── customCaseHighlightPanelLWC.html
    ├── customCaseHighlightPanelLWC.css
    └── customCaseHighlightPanelLWC.js-meta.xml

❌ INCORRECT:
lwc/customCaseHighlightPanel/    # Will conflict with Aura!
```

#### JavaScript Class Names
```javascript
// ✅ CORRECT
export default class CustomCaseHighlightPanelLWC extends LightningElement {
    // ...
}

// ❌ INCORRECT
export default class CustomCaseHighlightPanel extends LightningElement {
    // Will conflict with Aura!
}
```

#### HTML Template References
```html
<!-- ✅ CORRECT -->
<c-custom-case-highlight-panel-l-w-c record-id={recordId}>
</c-custom-case-highlight-panel-l-w-c>

<!-- ❌ INCORRECT -->
<c-custom-case-highlight-panel record-id={recordId}>
</c-custom-case-highlight-panel>
```

### Service Class Naming

| Type | Pattern | Example |
|------|---------|---------|
| Governor Service | `[Domain]DataGovernorService` | `CaseDataGovernorService` |
| UI Service | `[Domain]UIService` | `CaseUIService` |
| Business Rule Service | `[Domain]BusinessRuleService` | `CaseBusinessRuleService` |
| Attribute Service | `[Domain]AttributeService` | `CaseAttributeService` |
| ContextGetter | `[Domain]ContextGetter` | `CaseContextGetter` |
| DML Service | `[Domain]DMLService` | `CaseDMLService` |
| Utility | `UTIL_[FunctionName]` | `UTIL_LoggingService` |
| Test Class | `[ClassName]Test` | `CaseBusinessRuleServiceTest` |

### Variable & Method Naming

```apex
// ✅ CORRECT - Descriptive, clear intent
public static List<Case> getCasesByAccountId(Id accountId)
public static Boolean validatePickupAsset(Id assetId)
private static void logException(Exception ex, String className, String methodName)

// ❌ INCORRECT - Too generic, unclear
public static List<Case> getCases(Id id)
public static Boolean validate(Id id)
private static void log(Exception ex)
```

---

## Code Standards & Best Practices

### Error Handling

**ALWAYS use UTIL_LoggingService for error logging:**

```apex
try {
    // Business logic
    Case caseRecord = CaseContextGetter.getCaseById(caseId);
    // ... operations ...
} catch (QueryException qe) {
    UTIL_LoggingService.logException(
        qe,
        'CaseUIService',
        'getCaseUIWrapper'
    );
    throw new AuraHandledException('Unable to load case data: ' + qe.getMessage());
} catch (Exception ex) {
    UTIL_LoggingService.logHandledException(
        ex,
        UserInfo.getOrganizationId(),
        UTIL_ErrorConstants.ERROR_APPLICATION,
        LoggingLevel.ERROR
    );
    throw new AuraHandledException('An unexpected error occurred: ' + ex.getMessage());
}
```

### Bulkification

**ALL Apex code MUST handle bulk operations:**

```apex
// ✅ CORRECT - Bulkified
public static Map<Id, Case> getCasesByIds(Set<Id> caseIds) {
    return new Map<Id, Case>([
        SELECT Id, CaseNumber, Status
        FROM Case
        WHERE Id IN :caseIds
    ]);
}

// ❌ INCORRECT - NOT bulkified (NEVER do this)
public static Case getCaseById(Id caseId) {
    // Called in a loop = SOQL limit issues!
}
```

### Governor Limit Best Practices

```apex
// ✅ CORRECT - Query once, use Map
Map<Id, Account> accountMap = AccountContextGetter.getAccountsByIds(accountIds);
for (Case c : cases) {
    Account acct = accountMap.get(c.AccountId);
    // Process...
}

// ❌ INCORRECT - Query in loop
for (Case c : cases) {
    Account acct = [SELECT Id FROM Account WHERE Id = :c.AccountId];
    // SOQL in loop = FAIL!
}
```

### @AuraEnabled Method Pattern

```apex
/**
 * @description Get Case page data for LWC component
 * @param caseId Case record ID
 * @return CaseUIWrapper with all UI data
 */
@AuraEnabled(cacheable=false)
public static CaseUIWrapper getCaseUIData(Id caseId) {
    try {
        // Validate input
        if (caseId == null) {
            throw new IllegalArgumentException('Case ID is required');
        }

        // Delegate to service layer
        return CaseUIService.getCaseUIWrapper(caseId);

    } catch (Exception ex) {
        // Log error
        UTIL_LoggingService.logException(ex, 'CaseController', 'getCaseUIData');
        // Return user-friendly error
        throw new AuraHandledException('Unable to load case data: ' + ex.getMessage());
    }
}
```

### Security Best Practices

```apex
// ✅ CORRECT - Use 'with sharing' for user-context classes
public with sharing class CaseUIService {
    // Enforces sharing rules
}

// ✅ CORRECT - Use 'without sharing' only when needed
public without sharing class CaseContextGetter {
    // System context for consistent data access
}

// ✅ CORRECT - Strip inaccessible fields
List<Case> cases = [SELECT Id, Custom__c FROM Case];
SObjectAccessDecision decision = Security.stripInaccessible(
    AccessType.READABLE,
    cases
);
return decision.getRecords();
```

### Documentation Standards

```apex
/**
 * @description CaseBusinessRuleService - Business rule evaluation for Case records
 *
 * This service evaluates all business rules for Case records including:
 * - Approval requirements
 * - NTE (Not To Exceed) limits
 * - Occurrence tracking
 * - Service eligibility
 *
 * @author Waste Management
 * @date 2025
 * @group Service Layer - Business Logic
 */
public with sharing class CaseBusinessRuleService {

    /**
     * @description Evaluate all business rules for a Case
     * @param caseId Case record ID
     * @return BusinessRuleResult with rule evaluation results
     * @throws BusinessRuleException if critical rule validation fails
     */
    public static BusinessRuleResult evaluateBusinessRules(Id caseId) {
        // Implementation...
    }
}
```

---

## Development Workflow

### Branch Naming Convention

```bash
# Current development branch
claude/add-claude-documentation-01XdKUmg672TZzNpFZVhJ9Pm

# Pattern for feature branches
claude/[feature-description]-[session-id]
```

### Git Workflow

```bash
# 1. Check current status
git status

# 2. Stage changes
git add classes/NewService.cls
git add lwc/newComponentLWC/

# 3. Commit with descriptive message
git commit -m "feat: Add NewService for feature X

- Implement NewService following 5-tier architecture
- Add NewContextGetter for data access
- Create test class with >85% coverage
- Update documentation"

# 4. Push to feature branch
git push -u origin claude/[branch-name]
```

### Deployment Process

1. **Validate changes in sandbox first**
   ```bash
   # Deploy to sandbox
   sfdx force:source:deploy -x package.xml --testlevel RunSpecifiedTests
   ```

2. **Run all test classes** (must achieve >85% coverage)
   ```apex
   // Run from Developer Console or CLI
   Test.runSpecifiedTests([list of test classes]);
   ```

3. **Validate metadata dependencies**
   - Check package.xml includes all new components
   - Verify Custom Metadata Types are included
   - Confirm Lightning Message Channels are deployed

4. **Deploy to production**
   - Always deploy with tests
   - Monitor deployment logs
   - Validate in production after deployment

### Refactoring Phases

The project is in ongoing refactoring with documented phases:

- ✅ **Phase 1:** Service layer foundation - COMPLETED
- ✅ **Phase 2:** ShowCaseMessages component - COMPLETED
- ✅ **Phase 4:** Aura performance optimization - COMPLETED
- ✅ **Phase 5:** Custom component refactoring - COMPLETED
- 🔄 **Ongoing:** Aura to LWC migration

See `PHASE*_COMPLETION_SUMMARY.md` files for details.

---

## Testing Strategy

### Test Coverage Requirements

- **Minimum:** 85% code coverage for all classes
- **Recommended:** 90%+ for critical service classes
- **Required:** All public methods must have test coverage

### Test Class Organization

```
classes/
├── CaseBusinessRuleService.cls
├── CaseBusinessRuleServiceTest.cls    # Unit tests
├── CaseContextGetter.cls
├── CaseContextGetterTest.cls          # Data access tests
├── CaseDMLService.cls
├── CaseDMLServiceTest.cls             # DML tests
└── TestDataFactoryRefactored.cls      # Test data factory
```

### Test Data Factory Pattern

```apex
// TestDataFactoryRefactored.cls
public class TestDataFactoryRefactored {

    /**
     * Create Account - NOT inserted by default
     * @param recordTypeName Record type developer name
     * @param accountType Account type (Client, Location, Supplier)
     * @return Account record ready for insert
     */
    public static Account createAccount(String recordTypeName, String accountType) {
        return new Account(
            Name = 'Test Account ' + DateTime.now().getTime(),
            Type = accountType,
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get(recordTypeName).getRecordTypeId()
        );
    }

    /**
     * Create Case - NOT inserted by default
     */
    public static Case createCase(Id accountId, Id contactId, String caseType) {
        return new Case(
            AccountId = accountId,
            ContactId = contactId,
            Type = caseType,
            Status = 'New',
            Origin = 'Phone',
            Subject = 'Test Case ' + DateTime.now().getTime()
        );
    }

    // More factory methods...
}
```

### Test Class Template

```apex
/**
 * @description Test class for CaseBusinessRuleService
 */
@isTest
private class CaseBusinessRuleServiceTest {

    /**
     * @description Test setup - create test data
     */
    @TestSetup
    static void setupTestData() {
        // Create test data
        Account clientAccount = TestDataFactoryRefactored.createAccount(
            'Commercial_Account',
            'Client'
        );
        insert clientAccount;

        Contact testContact = TestDataFactoryRefactored.createContact(
            clientAccount.Id
        );
        insert testContact;

        Case testCase = TestDataFactoryRefactored.createCase(
            clientAccount.Id,
            testContact.Id,
            'Pickup'
        );
        insert testCase;
    }

    /**
     * @description Test positive scenario
     */
    @isTest
    static void testEvaluateBusinessRules_Success() {
        // Given
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // When
        Test.startTest();
        CaseBusinessRuleService.BusinessRuleResult result =
            CaseBusinessRuleService.evaluateBusinessRules(testCase.Id);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.isSuccess, 'Evaluation should succeed');
    }

    /**
     * @description Test bulk processing
     */
    @isTest
    static void testBulkProcessing() {
        // Given
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(TestDataFactoryRefactored.createAccount(
                'Commercial_Account',
                'Client'
            ));
        }
        insert accounts;

        // When
        Test.startTest();
        // Process 200 records...
        Test.stopTest();

        // Then
        // Verify no governor limits hit
    }

    /**
     * @description Test error handling
     */
    @isTest
    static void testErrorHandling() {
        // Given - invalid data

        // When
        try {
            Test.startTest();
            CaseBusinessRuleService.evaluateBusinessRules(null);
            Test.stopTest();
            System.assert(false, 'Should have thrown exception');
        } catch (Exception ex) {
            // Then
            System.assert(true, 'Exception expected');
        }
    }
}
```

---

## Common Tasks & Examples

### Task 1: Add New Service Method

**Scenario:** Add method to get Cases by Account

```apex
// Step 1: Add to ContextGetter (Layer 4)
public class CaseContextGetter {

    /**
     * Get Cases by Account ID
     * @param accountId Account ID
     * @return List of Cases for the Account
     */
    public static List<Case> getCasesByAccountId(Id accountId) {
        return [
            SELECT Id, CaseNumber, Status, Type, Priority
            FROM Case
            WHERE AccountId = :accountId
            ORDER BY CreatedDate DESC
        ];
    }
}

// Step 2: Add to UI Service (Layer 3a)
public class CaseUIService {

    /**
     * Get Account Cases Wrapper
     */
    @AuraEnabled
    public static List<CaseUIWrapper> getAccountCases(Id accountId) {
        List<CaseUIWrapper> wrappers = new List<CaseUIWrapper>();

        // Get data from ContextGetter
        List<Case> cases = CaseContextGetter.getCasesByAccountId(accountId);

        // Convert to wrappers
        for (Case c : cases) {
            CaseUIWrapper wrapper = new CaseUIWrapper();
            wrapper.caseId = c.Id;
            wrapper.caseNumber = c.CaseNumber;
            wrappers.add(wrapper);
        }

        return wrappers;
    }
}

// Step 3: Add test class
@isTest
private class CaseContextGetterTest {
    @isTest
    static void testGetCasesByAccountId() {
        // Setup
        Account testAccount = TestDataFactoryRefactored.createAccount(
            'Commercial_Account',
            'Client'
        );
        insert testAccount;

        // Test
        Test.startTest();
        List<Case> cases = CaseContextGetter.getCasesByAccountId(
            testAccount.Id
        );
        Test.stopTest();

        // Verify
        System.assertNotEquals(null, cases);
    }
}
```

### Task 2: Create New LWC Component

```bash
# Step 1: Create component with LWC suffix
mkdir lwc/accountCaseListLWC
```

```javascript
// lwc/accountCaseListLWC/accountCaseListLWC.js
import { LightningElement, api, track } from 'lwc';
import getAccountCases from '@salesforce/apex/CaseUIService.getAccountCases';

export default class AccountCaseListLWC extends LightningElement {
    @api recordId;
    @track cases = [];
    @track error;

    connectedCallback() {
        this.loadCases();
    }

    loadCases() {
        getAccountCases({ accountId: this.recordId })
            .then(result => {
                this.cases = result;
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.cases = [];
            });
    }
}
```

```html
<!-- lwc/accountCaseListLWC/accountCaseListLWC.html -->
<template>
    <lightning-card title="Account Cases">
        <template if:true={cases}>
            <template for:each={cases} for:item="case">
                <div key={case.caseId}>
                    {case.caseNumber} - {case.status}
                </div>
            </template>
        </template>
        <template if:true={error}>
            <p>Error: {error.body.message}</p>
        </template>
    </lightning-card>
</template>
```

### Task 3: Add Business Rule

```apex
// Add to CaseBusinessRuleService.cls
public class CaseBusinessRuleService {

    /**
     * Check if Case requires approval based on amount
     */
    public static Boolean requiresApproval(Id caseId) {
        // Get data from ContextGetter
        Case caseRecord = CaseContextGetter.getCaseById(caseId);

        // Business rule logic
        Decimal nteLimit = 10000;
        Boolean requiresApproval = false;

        if (caseRecord.Amount__c != null &&
            caseRecord.Amount__c > nteLimit) {
            requiresApproval = true;
        }

        return requiresApproval;
    }
}
```

---

## Key Documentation

### Essential Reading (Priority Order)

1. **ARCHITECTURE_DOCUMENTATION.md** (96KB)
   - Complete system overview
   - Service layer details
   - SOLID principles in practice
   - Read this first!

2. **documentation/Service_Layer_Quick_Reference.md** (1,429 lines)
   - Quick reference for service patterns
   - How to extend architecture
   - Code examples

3. **documentation/Case_Trigger_Architecture.md** (1,128 lines)
   - Trigger handler patterns
   - Service orchestration in triggers

4. **docs/LWC_NAMING_CONVENTION.md**
   - LWC naming standards
   - Aura migration strategy
   - CRITICAL for component work

5. **docs/GOVERNOR_ARCHITECTURE.md**
   - API call reduction strategy
   - Performance optimization patterns

6. **docs/USER_SCENARIOS.md**
   - Given/When/Then use cases
   - Business requirements

### Additional Resources

- **documentation/Entitlement_and_SLA_Service_Layer_Guide.md** - SLA calculations
- **documentation/Production_Support_Debugging_Guide.md** - Troubleshooting
- **PHASE*_COMPLETION_SUMMARY.md** - Refactoring history

---

## Golden Rules (CRITICAL)

### Rule 1: NO SOQL in Controllers or UI Services

```apex
// ❌ WRONG - NEVER do this
@AuraEnabled
public static Case getCase(Id caseId) {
    return [SELECT Id FROM Case WHERE Id = :caseId];
}

// ✅ RIGHT - Always use ContextGetter
@AuraEnabled
public static Case getCase(Id caseId) {
    return CaseContextGetter.getCaseById(caseId);
}
```

### Rule 2: NO Business Logic in UI Services

```apex
// ❌ WRONG - Business logic in UI Service
public class CaseUIService {
    public static CaseUIWrapper getWrapper(Id caseId) {
        Case c = CaseContextGetter.getCaseById(caseId);
        wrapper.requiresApproval = c.Amount__c > 10000; // WRONG!
        return wrapper;
    }
}

// ✅ RIGHT - Delegate to Business Rule Service
public class CaseUIService {
    public static CaseUIWrapper getWrapper(Id caseId) {
        Case c = CaseContextGetter.getCaseById(caseId);
        wrapper.requiresApproval =
            CaseBusinessRuleService.requiresApproval(caseId); // RIGHT!
        return wrapper;
    }
}
```

### Rule 3: NO DML Outside DML Services

```apex
// ❌ WRONG - Direct DML
update caseRecord;

// ✅ RIGHT - Use DML Service
DMLResult result = CaseDMLService.getInstance().updateCase(caseRecord);
if (!result.isSuccess) {
    // Handle error
}
```

### Rule 4: ALWAYS Use ContextGetters for Queries

```apex
// ❌ WRONG
List<Case> cases = [SELECT Id FROM Case WHERE AccountId = :accountId];

// ✅ RIGHT
List<Case> cases = CaseContextGetter.getCasesByAccountId(accountId);
```

### Rule 5: ALWAYS Log Errors via UTIL_LoggingService

```apex
// ❌ WRONG
catch (Exception e) {
    System.debug(e.getMessage());
}

// ✅ RIGHT
catch (Exception e) {
    UTIL_LoggingService.logException(e, 'ClassName', 'methodName');
    throw new AuraHandledException('User-friendly message');
}
```

### Rule 6: ALL LWC Components Must Have "LWC" Suffix

```
// ❌ WRONG - Will conflict with Aura
lwc/customCaseHighlightPanel/

// ✅ RIGHT
lwc/customCaseHighlightPanelLWC/
```

### Rule 7: ALWAYS Return Wrapper Objects from @AuraEnabled Methods

```apex
// ❌ WRONG - Returning SObject directly limits flexibility
@AuraEnabled
public static Case getCase(Id caseId) {
    return CaseContextGetter.getCaseById(caseId);
}

// ✅ RIGHT - Return wrapper with additional context
@AuraEnabled
public static CaseUIWrapper getCaseUI(Id caseId) {
    return CaseUIService.getCaseUIWrapper(caseId);
}
```

### Rule 8: ALWAYS Write Tests with >85% Coverage

Every new class MUST have a corresponding test class achieving minimum 85% coverage.

### Rule 9: ALWAYS Document Complex Logic

Use JavaDoc-style comments for all public methods and complex logic blocks.

### Rule 10: ALWAYS Bulkify Code

Every method must handle bulk operations (200+ records).

---

## Quick Reference Checklist

### Before Adding New Code

- [ ] Search for existing services that may already provide needed functionality
- [ ] Determine correct architecture layer (2, 3a, 3b, 3c, 4, or 5)
- [ ] Review naming conventions
- [ ] Check if ContextGetter method already exists

### When Writing New Service

- [ ] Place code in correct layer
- [ ] Follow naming convention for service type
- [ ] Use ContextGetters for ALL data access
- [ ] Use DMLService for ALL database operations
- [ ] Return wrapper objects from @AuraEnabled methods
- [ ] Add comprehensive error handling with logging
- [ ] Bulkify all code (handle 200+ records)
- [ ] Write test class with >85% coverage
- [ ] Document public methods with JavaDoc comments

### When Creating New LWC

- [ ] Add "LWC" suffix to directory name
- [ ] Add "LWC" suffix to file names
- [ ] Add "LWC" suffix to JavaScript class name
- [ ] Use kebab-case with `-l-w-c` suffix in HTML references
- [ ] Call @AuraEnabled methods from appropriate service
- [ ] Handle errors gracefully in JavaScript
- [ ] Test component in isolation and integrated

### Before Committing

- [ ] Run all test classes locally
- [ ] Verify >85% code coverage
- [ ] Check no SOQL in controllers/UI services
- [ ] Check no business logic in UI services
- [ ] Check no DML outside DML services
- [ ] Verify all errors logged via UTIL_LoggingService
- [ ] Update documentation if architecture changed
- [ ] Write clear commit message

### Before Deploying

- [ ] Deploy to sandbox first
- [ ] Run all test classes in sandbox
- [ ] Validate metadata dependencies in package.xml
- [ ] Test in sandbox org
- [ ] Review deployment logs
- [ ] Deploy to production with tests
- [ ] Validate in production

---

## Contact & Support

### Documentation Issues

If you find issues with this documentation:
- Update CLAUDE.md directly
- Document changes in commit message
- Notify team of significant changes

### Architecture Questions

Refer to:
- `ARCHITECTURE_DOCUMENTATION.md` - Overall architecture
- `documentation/Service_Layer_Quick_Reference.md` - Service patterns
- `documentation/Case_Trigger_Architecture.md` - Trigger patterns

### Code Questions

Review existing implementations:
- `classes/CaseDataGovernorService.cls` - Governor pattern example
- `classes/CaseUIService.cls` - UI Service example
- `classes/CaseBusinessRuleService.cls` - Business logic example
- `classes/CaseContextGetter.cls` - Data access example
- `classes/CaseDMLService.cls` - DML pattern example

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-01 | Initial creation - Comprehensive AI assistant guide |

---

**Remember:** This codebase represents enterprise-grade Salesforce development with exemplary architecture following SOLID principles. When in doubt, follow the patterns established by existing services and always prioritize maintainability and testability over clever solutions.

**The Golden Rules are non-negotiable. Follow them always.**
