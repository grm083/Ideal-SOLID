# Case Trigger Architecture Documentation

## Overview

The Case trigger architecture has been refactored from a monolithic design into a service-oriented architecture following SOLID principles. This document outlines the complete architecture, service layers, and their responsibilities.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Trigger Handler Layer](#trigger-handler-layer)
3. [Service Layer Components](#service-layer-components)
4. [Data Access Layer](#data-access-layer)
5. [Utility Layer](#utility-layer)
6. [Integration Points](#integration-points)
7. [Dependency Graph](#dependency-graph)
8. [Migration Status](#migration-status)

---

## Architecture Overview

### Design Pattern: Service-Oriented Architecture

The architecture follows a layered approach with clear separation of concerns:

```
┌──────────────────────────────────────────────────┐
│          Trigger (Case.trigger)                   │
│  - Minimal logic                                  │
│  - Delegates to TriggerDispatcher                 │
└──────────────────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────┐
│       CaseTriggerHandler (Orchestration)          │
│  - Coordinates trigger events                     │
│  - Manages transaction flow                       │
│  - Error handling                                 │
└──────────────────────────────────────────────────┘
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
┌─────────────────────┐  ┌─────────────────────┐
│  CaseTriggerHelper  │  │   Service Layer     │
│  (Legacy Adapter)   │  │   (Refactored)      │
│  - Being phased out │  │   - Business logic  │
│  - Delegates to     │  │   - Validations     │
│    services         │  │   - Processing      │
└─────────────────────┘  └─────────────────────┘
                                  │
                      ┌───────────┴───────────┐
                      ▼                       ▼
            ┌─────────────────┐    ┌─────────────────┐
            │  Data Access    │    │    Utilities    │
            │     Layer       │    │                 │
            └─────────────────┘    └─────────────────┘
```

### Key Principles

1. **Single Responsibility**: Each service class has one primary responsibility
2. **Open/Closed**: Services are open for extension but closed for modification
3. **Liskov Substitution**: Service methods return consistent result objects
4. **Interface Segregation**: Public methods are focused and purposeful
5. **Dependency Inversion**: Services depend on abstractions, not concrete implementations

---

## Trigger Handler Layer

### CaseTriggerHandler.cls

**Primary Responsibility**: Orchestrates trigger execution and coordinates service calls

**Key Methods**:

- `beforeInsert(TriggerParameters)` - Orchestrates before insert logic
- `beforeUpdate(TriggerParameters)` - Orchestrates before update logic
- `afterInsert(TriggerParameters)` - Orchestrates after insert logic
- `afterUpdate(TriggerParameters)` - Orchestrates after update logic
- `afterUpdateAlways(TriggerParameters)` - Logic that always runs on update
- `beforeDelete(TriggerParameters)` - Handles before delete

**Processing Flow** (Before Insert Example):

```
1. Apply workflow migrations (Process Builder → Flow)
2. Apply business rules for status/classification
3. Bulk data retrieval (Assets, Locations, Contacts)
4. Process case details and attributes
5. Calculate SLA dates
6. Update contact activity dates
7. Apply final field updates
```

**Responsibilities**:
- Transaction coordination
- Service orchestration
- Error handling at trigger level
- Maintaining backward compatibility with CaseTriggerHelper

### CaseTriggerHelper.cls

**Status**: LEGACY - Being phased out during refactoring

**Current Role**: Thin delegation layer that routes to appropriate service classes

**Deprecated Features**:
- Static variables for inter-class communication (`casewithContainer`, `casewithLocation`)
- Direct field manipulation
- Inline business logic

**Migration Strategy**: Methods are being gradually migrated to appropriate service classes while maintaining backward compatibility.

---

## Service Layer Components

### 1. CaseAttributeService.cls

**Purpose**: Field population and attribute management

**Responsibilities**:
- Initialize cases with default values
- Update case attributes based on related data
- Populate derived fields
- Handle field transformations

**Key Methods**:

```apex
// Initialize single case with defaults
public static Case initializeCase(Case caseRecord)

// Initialize multiple cases
public static void initializeCases(List<Case> cases)

// Update case attributes from Asset and Location data
public static void updateCaseAttributes(List<Case> cases, 
                                        Map<Id, Asset> containerMap, 
                                        Map<Id, Account> locationMap)

// Update contact last activity date
public static void updateContactLastActivity(Set<Id> contactIdSet)

// Sync ANI from Case to Contact
public static void synchronizeContactANI(Map<Id,Case> caseNewMap, Map<Id,Case> oldCaseMap)

// Update case details from related records
public static List<Case> updateCaseDetailsFromAssetAndLocation(
    List<Case> caseList, Map<Id,Case> oldCaseMap, 
    Map<Id,Asset> caseWithContainerMap, 
    Map<Id,Account> caseWithLocationMap, Boolean isInsert)

// Field formatting methods
public static void trimEmailDescriptions(List<Case> newcaselst)
public static void extractPOFromOfficetrax(List<Case> newcaselst)
public static void syncTrackingNumbersAndComments(Map<Id,Case> caseNewMap, Map<Id,Case> oldcaseMap)

// Agent identification
public static List<Case> updateLastAgentIdentification(Map<Id, Case> casemap, 
    Map<Id, Case> oldCaseMap, Boolean isInsertForLocalAgentId, Integer runCount)
public static List<Case> updateCallCenterIdentification(Map<Id, Case> casemap, 
    Map<Id, Case> oldCaseMap, Boolean isInsertForLocalAgentId)

// Assignment
public static void assignCaseOwnership(Map<Id,Case> newMap, Map<Id,Case> oldMap, List<Case> caselst)
public static void assignTeamAndQueue(List<Case> newcaseList)

// Service Classification
public static void setServiceClassification(List<Case> newcaseList, Map<Id,Case> oldCaseMap)

// Chargeability
public static void propagateChargeabilityToParent(Set<Id> caselst)
public static void propagateChargeabilityToChildren(Set<Id> caselst)
```

**Usage Example**:

```apex
// In CaseTriggerHandler.beforeInsert()
List<Case> casesToProcess = (List<Case>)triggerParam.newList;

// Phase 1: Initialize with defaults
CaseAttributeService.initializeCases(casesToProcess);

// Phase 2: Update from related data
CaseAttributeService.updateCaseAttributes(
    casesToProcess, 
    casewithContainerMap, 
    casewithLocationMap
);
```

---

### 2. CaseBusinessRuleService.cls

**Purpose**: Central engine for all complex business rules and validations

**Responsibilities**:
- Business rule evaluation
- State validations
- Eligibility checks
- Approval logic
- UI button visibility logic
- WorkOrder-driven case updates

**Key Methods**:

```apex
// Core business rule evaluation
public static BusinessRuleResult evaluateBusinessRules(Id caseId)

// Work order readiness validation
public static Map<String, Object> validateCaseReadyForWorkOrder(Id caseId)

// Business logic checks
public static Boolean shouldBypassWorkOrderCreation(Case currentCase)
public static Map<String, Object> validateStatusChange(Case oldCase, Case newCase)
public static Boolean shouldAutoCloseCase(Case currentCase)
public static Boolean isPurchaseOrderRequired(Case currentCase)
public static Boolean isProfileNumberRequired(Case currentCase)
public static Boolean isPSIRequired(Case currentCase)
public static Boolean shouldSetBackOfficeFlag(Case currentCase, Id corporateServiceQueueId)
public static Boolean shouldBypassDuplicateCheck(Case currentCase)

// WorkOrder-driven case updates
public static List<Case> processWorkOrderStatusChanges(
    Map<Id,WorkOrder> woMap, 
    Map<Id,WorkOrder> oldWoMap,
    Map<Id,Case> caseMap)

// Task-driven case updates
public static List<Case> processAvailabilityConfirmation(List<Task> tasks, Map<Id,Case> relatedCases)
public static List<Case> processTaskApprovalOutcome(List<Task> tasks, Map<Id,Case> relatedCases)

// Approval and task management
public static void processApprovalLogs(Map<Id,Case> newCasemap, Map<Id,Case> oldCasemap)
public static void evaluateAndApplyBusinessRules(Map<Id,Case> newcasemap, 
    Map<Id,case> oldCasemap, Set<String> subtypeSet, 
    Map<string,Date> startDate, Map<string,Date> endDate,
    Map<Id,Asset> casewithContainer, Map<Id,Account> casewithLocation, 
    Map<String,Integer> caseWorkOrderCount)
public static void closeRelatedTasks(Map<Id,Case> casemap, Map<Id,Case> caseOldmap)

// Quote and notification management
public static void declineAssociatedQuotes(Map<Id,Case> closedCaseMap)
public static void updateGenesysRouting(Map<Id,Case> newMap, Map<Id,Case> oldMap)
public static void sendWorkOrderNotifications(List<Case> emailCaseList, String emailTemplate)
public static void addWorkOrderStatusComments(List<Case> caseLst)

// Cancellation
public static void createGenesysCancellationRecords(Map<Id,Case> newMap)

// Chargeability logging
public static void logChargeabilityChange(List<Case> newcaseList)

// UI Button Visibility Business Logic
public static Boolean shouldShowProgressCaseButton(Case caseRecord, Boolean isCPQUser, 
    Boolean isUpdateAssetActiveUser, String caseInfo, Boolean workOrderCreation, 
    Boolean isAssetMandatory, Boolean isCaseInfoReady)
public static Boolean shouldShowAddQuoteButton(Case caseRecord, Boolean isCPQUser, 
    Boolean isUpdateAssetActiveUser, String caseInfo, Boolean isOpportunityCreated)
```

**BusinessRuleResult Wrapper**:

```apex
public class BusinessRuleResult {
    public Boolean isAutoApproved { get; set; }
    public Boolean requiresApproval { get; set; }
    public Boolean occurrenceLimitReached { get; set; }
    public Map<Id, Business_Rule__c> approvalRules { get; set; }
    public Map<Id, Business_Rule__c> requiredInfoRules { get; set; }
    public List<String> validationMessages { get; set; }
}
```

**Usage Example**:

```apex
// Evaluate business rules before progressing case
BusinessRuleResult ruleResult = CaseBusinessRuleService.evaluateBusinessRules(caseId);

if (!ruleResult.isValid) {
    // Handle validation failures
    for (String msg : ruleResult.validationMessages) {
        // Display to user
    }
}

if (ruleResult.requiresApproval) {
    // Route to approval process
}
```

---

### 3. CaseAssetValidator.cls

**Purpose**: Single responsibility service for asset validation

**Responsibilities**:
- Asset eligibility validation
- Asset component validation
- Asset date range validation
- Case Asset relationship management
- Duplicate service date detection

**Key Methods**:

```apex
// Primary validation methods
public static ValidationResult validatePickupAsset(Id assetId, Date serviceDate)
public static ValidationResult validateNonPickupAsset(Id assetId, Date serviceDate)
public static ValidationResult validateCaseAssets(Id caseId)

// Bulk validation methods
public static Map<Id, String> validatePickupAssets(Map<Id, Date> assetParam)
public static Map<Id, String> validateNonPickupAssets(Map<Id, Date> assetParam)

// Case Asset relationship management
public static void removeObsoleteAssetLinks(Map<String, String> oldCaseAssetIdMap)
public static void createCaseAssetRelationships(Map<Id, Case> caseNewMap, 
    Map<Id, Case> oldCaseMap, Map<Id, Asset> assetMap)

// Duplicate detection
public static void markDuplicateServiceDateCases(Map<Id, Case> newCaseMap)
public static Boolean isParentCaseWithinTimeWindow(Id caseId, Integer minuteWindow)

// Validation helpers
public static void validateClosedCaseEdits(Map<Id, Case> newMap)
public static Boolean shouldResetSLA(Case caseRecord, Case oldCaseRecord)
public static Set<Id> identifyROLAssetsThatAffectSubtype(Map<Id, Asset> caseWithContainerMap)
```

**ValidationResult Wrapper**:

```apex
public class ValidationResult {
    @AuraEnabled public Boolean isValid { get; set; }
    @AuraEnabled public String errorMessage { get; set; }
    @AuraEnabled public String validationType { get; set; }
}
```

**Asset Validation Rules**:

1. **Commercial Assets**:
   - Must be active for service date
   - Scheduled assets require Extra Pickup component
   - On-Call assets must not have Extra Pickup
   - No duplicate components allowed

2. **Rolloff Assets**:
   - Must have active core service or recycling service
   - Baler assets require active pickup service
   - Scheduled rolloffs with core pickup support extra pickups

3. **Services Assets**:
   - Bulk, Haul Away, and Hand Pickup services validated
   - Must be active for service date

**Usage Example**:

```apex
// Validate asset before case creation
ValidationResult result = CaseAssetValidator.validatePickupAsset(assetId, serviceDate);

if (!result.isValid) {
    throw new AuraHandledException(result.errorMessage);
}

// Create Case Asset relationships after case insert
CaseAssetValidator.createCaseAssetRelationships(
    caseNewMap, 
    oldCaseMap, 
    casewithContainerMap
);
```

---

### 4. CaseContextGetter.cls

**Purpose**: Data access layer for Case-related queries

**Responsibilities**:
- Execute all Case-related SOQL queries
- Cache frequently accessed data
- Provide consistent field selections
- Reduce SOQL query count through bulkification

**Key Methods**:

```apex
// Case queries
public static Case getCaseById(Id caseId)
public static List<Case> getCasesByIds(Set<Id> caseIds)
public static Map<Id, Case> getCaseMapByIds(Set<Id> caseIds)

// Asset queries
public static Asset getAssetById(Id assetId)
public static Map<Id, Asset> getAssetsWithChildren(Set<Id> assetIds)
public static List<Asset> getAssetsByServiceHeader(Id serviceHeaderId)

// Location queries
public static Account getLocationById(Id locationId)
public static Map<Id, Account> getLocationsByIds(Set<Id> locationIds)
public static Map<Id, Account> getLocationsByCaseIds(Set<Id> caseIds)

// Related record queries
public static List<SBS_Case_Asset__c> getCaseAssetsByCaseId(Id caseId)
public static List<SBS_Case_Asset__c> getCaseAssetsByCaseIds(Set<Id> caseIds)
public static List<WorkOrder> getWorkOrdersByCaseIds(Set<Id> caseIds)

// Metadata queries
public static Case_Highlight_Panel_Button__mdt getButtonVisibilityMetadata(
    String recordTypeName, String caseType, String caseSubType, 
    String caseReason, String buttonName, 
    Boolean isCPQUser, Boolean isUpdateAssetActiveUser)
public static Add_Quote__mdt getAddQuoteMetadataByUCC(String userCategorizationCode)

// User queries
public static User getCurrentUserWithPermissions()

// Cache management
public static void clearCaches()
public static void initializeCaches(Set<Id> caseIds)
```

**Field Sets**:

```apex
// Consistent field selections across application
private static final String CASE_STANDARD_FIELDS = 
    'Id, CaseNumber, Status, Case_Sub_Status__c, RecordTypeId, RecordType.Name, ' +
    'AccountId, Client__c, Location__c, ContactId, AssetId, ' +
    'Case_Type__c, Case_Sub_Type__c, Case_Reason__c, ' +
    'Service_Date__c, SLA_Service_Date_Time__c, ...';

private static final String ASSET_STANDARD_FIELDS = 
    'Id, Name, Product2Id, Product2.Family, ProductFamily, ' +
    'Occurrence_Type__c, Material_Type__c, Start_Date__c, End_Date__c, ...';
```

**Caching Strategy**:

```apex
// Cache structures
private static Map<Id, Case> caseCache = new Map<Id, Case>();
private static Map<Id, Asset> assetCache = new Map<Id, Asset>();
private static Map<Id, Account> accountCache = new Map<Id, Account>();

// Cache methods
public static void clearCaches() {
    caseCache.clear();
    assetCache.clear();
    accountCache.clear();
}
```

**Usage Example**:

```apex
// Retrieve cases with consistent fields
Map<Id, Case> caseMap = CaseContextGetter.getCaseMapByIds(caseIds);

// Retrieve assets with children for validation
Map<Id, Asset> assetMap = CaseContextGetter.getAssetsWithChildren(assetIds);

// Query metadata for UI logic
Case_Highlight_Panel_Button__mdt metadata = 
    CaseContextGetter.getButtonVisibilityMetadata(
        recordTypeName, caseType, caseSubType, caseReason, 
        'Progress Case', isCPQUser, isUpdateAssetActiveUser
    );
```

---

### 5. CaseDMLService.cls

**Purpose**: Centralized DML operations for Case records

**Responsibilities**:
- Execute all Case DML operations
- Log DML results
- Handle partial success scenarios
- Maintain data integrity

**Key Methods**:

```apex
// Case DML operations
public static List<Database.SaveResult> insertCases(List<Case> cases)
public static List<Database.SaveResult> updateCases(List<Case> cases)
public static List<Database.DeleteResult> deleteCases(List<Case> cases)
public static List<Database.UpsertResult> upsertCases(List<Case> cases)

// Case Asset DML operations
public static List<Database.SaveResult> insertCaseAssets(List<SBS_Case_Asset__c> caseAssets)
public static List<Database.SaveResult> updateCaseAssets(List<SBS_Case_Asset__c> caseAssets)
public static List<Database.DeleteResult> deleteCaseAssets(List<SBS_Case_Asset__c> caseAssets)

// Approval Log DML operations
public static List<Database.SaveResult> insertApprovalLogs(List<Approval_Log__c> approvalLogs)
public static List<Database.SaveResult> updateApprovalLogs(List<Approval_Log__c> approvalLogs)

// Task DML operations
public static List<Database.SaveResult> insertTasks(List<Task> tasks)
public static List<Database.SaveResult> updateTasks(List<Task> tasks)

// Case Comment DML operations
public static List<Database.SaveResult> insertCaseComments(List<CaseComment> comments)

// Status logging
public static void logStatusUpdates(Map<Id, Case> newCaseMap, Map<Id, Case> oldCaseMap)

// Error handling with partial success
public static void handlePartialSuccess(List<Database.SaveResult> results, 
    List<sObject> records, String operation)
```

**Usage Example**:

```apex
// Insert cases with error handling
List<Database.SaveResult> results = CaseDMLService.insertCases(newCases);

// Handle any failures
CaseDMLService.handlePartialSuccess(results, newCases, 'Insert');

// Log status updates
CaseDMLService.logStatusUpdates(newCaseMap, oldCaseMap);
```

---

### 6. SLACalculationUtility.cls

**Purpose**: SLA date calculations and business hours management

**Responsibilities**:
- Calculate SLA dates based on entitlements
- Handle business hours and holidays
- Manage timezone conversions
- Validate and correct SLA dates

**Key Methods**:

```apex
// Primary SLA calculation
public static void calculateAndSetSLAFields(List<Case> cases, 
    Map<Id, Account> locationMap)

// Service date calculation
public static List<Case> calculateServiceDates(List<Case> newCaseList, 
    Map<Id, Asset> containerMap, Map<Id, Account> locationMap)

// SLA date correction
public static Datetime correctSLADate(Case c, Map<Id, Account> locationMap)

// Timezone conversion
public static Datetime convertToLocationTimezone(Datetime localdate, Case c, 
    Map<Id, Account> locationMap)

// Intake SLA calculation
public static Datetime calculateIntakeSLADatetime(Datetime serviceDate, 
    Datetime currentSLADate, Case c, Map<Id, Account> locationMap)

// SLA reset validation
public static Boolean requiresSLAandServiceDateReset(Case caseRecord, Case oldCase)

// Business hours calculation
public static Datetime addBusinessHours(Id businessHoursId, Datetime startDate, 
    Integer hoursToAdd)
public static Datetime addBusinessDays(Datetime startDate, Integer daysToAdd, 
    String timezone)
```

**Usage Example**:

```apex
// Calculate SLA for new cases
List<Case> casesNeedingSLA = new List<Case>();
for (Case c : newCases) {
    if (c.SLA_Service_Date_Time__c == null && 
        c.Location__c != null && 
        c.Case_Sub_Type__c != null) {
        casesNeedingSLA.add(c);
    }
}

if (!casesNeedingSLA.isEmpty()) {
    SLACalculationUtility.calculateAndSetSLAFields(
        casesNeedingSLA, 
        locationMap
    );
}
```

---

### 7. Entitlement_Utility.cls

**Purpose**: Entitlement management and SLA rule retrieval

**Responsibilities**:
- Query and match entitlements to cases
- Prioritize applicable entitlements
- Extract account and service date information
- Support legacy static variable pattern (deprecated)

**Key Methods**:

```apex
// REFACTORED: No longer uses static variables
public static Map<String, Entitlement> getPrioritizedEntitlements(Set<Id> caseIds)

// Helper methods
public static Map<Id, Account> extractAccountsFromCases(Set<Id> caseIds)
public static Date extractMinimumServiceDate(Set<Id> caseIds)
public static Map<String, Entitlement> matchEntitlementsToCase s(
    Map<Id, Case> caseMap, 
    List<Entitlement> entitlements)
```

**Legacy Static Variables (Deprecated)**:

```apex
// These are deprecated and should not be used in new code
@Deprecated
public static Set<Id> accountIdSet = new Set<Id>();
@Deprecated  
public static Date minimumServiceDate;
```

**Usage Example**:

```apex
// Fetch entitlements for cases
Set<Id> caseIds = new Set<Id>();
for (Case c : caseMap.values()) {
    caseIds.add(c.Id);
}

Map<String, Entitlement> entitlements = 
    Entitlement_Utility.getPrioritizedEntitlements(caseIds);
```

---

### 8. Additional Service Classes

#### CaseWorkOrderService.cls

**Purpose**: Work order creation and management orchestration

**Key Responsibilities**:
- Initiate work order creation process
- Validate work order prerequisites
- Coordinate multi-case work orders
- Handle work order state transitions

#### CaseTaskService.cls

**Purpose**: Task creation and management for cases

**Key Responsibilities**:
- Create approval tasks
- Create follow-up tasks
- Update task status based on case changes
- Manage task assignments

#### CaseUIService.cls

**Purpose**: UI component support and data transformation

**Key Responsibilities**:
- Prepare data for Lightning components
- Button visibility logic (being moved to CaseBusinessRuleService)
- Field formatting for display
- Wrapper class construction

#### CaseContextService.cls

**Purpose**: Context-aware case operations

**Key Responsibilities**:
- Determine user context and permissions
- Apply context-specific business rules
- Handle multi-user scenarios
- Manage session state

#### CaseDataGovernorService.cls

**Purpose**: Governor limit management and optimization

**Key Responsibilities**:
- Monitor SOQL queries
- Track DML operations
- Optimize bulkification
- Provide limit warnings

#### CaseCPQService.cls

**Purpose**: CPQ integration for quotes and opportunities

**Key Responsibilities**:
- Create opportunities from cases
- Link quotes to cases
- Sync CPQ data
- Handle quote approvals

#### CaseWizardService.cls

**Purpose**: Multi-step case creation wizard support

**Key Responsibilities**:
- Manage wizard state
- Validate wizard steps
- Coordinate wizard completion
- Handle wizard cancellation

---

## Data Access Layer

### CaseContextGetter.cls (Detailed Above)

**Architecture Pattern**: Repository Pattern

**Benefits**:
- Single source of truth for queries
- Consistent field selection
- Performance optimization through caching
- Reduced SOQL query count
- Easier testing through mockability

---

## Utility Layer

### 1. SLACalculationUtility.cls (Detailed Above)

**Type**: Domain-specific utility

**Focus**: SLA calculations, business hours, holidays

### 2. Entitlement_Utility.cls (Detailed Above)

**Type**: Domain-specific utility

**Focus**: Entitlement matching and prioritization

### 3. BusinessRuleHelper.cls

**Type**: Business rule engine utility

**Responsibilities**:
- Business rule selection
- Rule evaluation
- Approval log generation
- Occurrence limit checking

### 4. BusinessRuleUtility.cls

**Type**: Business rule query utility

**Responsibilities**:
- Bulk business rule queries
- Priority-based rule selection
- Rule caching

### 5. SystemObjectSelector.cls

**Type**: System object query utility

**Responsibilities**:
- Queue ID retrieval
- Profile name retrieval
- Record type ID retrieval

### 6. UTIL_LoggingService.cls

**Type**: Logging utility

**Responsibilities**:
- Exception logging
- DML result logging
- Error message formatting
- Log persistence

---

## Integration Points

### External Systems

1. **Acorn** (Legacy work order system)
   - WorkOrder status updates trigger Case updates
   - Bidirectional sync via Genesys_Routing__c

2. **OfficeTrax** (Service management system)
   - Cases created from OfficeTrax requests
   - PO number extraction from Case_Information__c

3. **Genesys** (Call center routing)
   - Task routing updates
   - Agent ID synchronization
   - ANI (Automatic Number Identification) sync

4. **CPQ** (Salesforce CPQ)
   - Quote creation from cases
   - Opportunity linking
   - Quote approval workflows

### Internal Salesforce Objects

1. **Asset** (Equipment hierarchy)
   - Parent-child relationships
   - Service components
   - Active date ranges

2. **Account** (Client and Location)
   - Client hierarchy
   - Location details
   - Timezone information

3. **Contact** (Customer contacts)
   - Last activity date sync
   - ANI sync
   - Preferred communication method

4. **WorkOrder** (Service requests)
   - Bidirectional case updates
   - Status synchronization
   - Vendor information

5. **Task** (Follow-up actions)
   - Approval tasks
   - Required information tasks
   - Availability confirmation tasks

6. **Approval_Log__c** (Approval tracking)
   - Auto-approval logging
   - Manual approval requests
   - Decision tracking

7. **SBS_Case_Asset__c** (Case-Asset relationships)
   - Links cases to specific asset components
   - Tracks service date eligibility
   - Supports multi-asset scenarios

8. **Genesys_Routing__c** (Call center integration)
   - Task routing
   - Agent assignment
   - Service level tracking

---

## Dependency Graph

```
CaseTriggerHandler
├── CaseTriggerHelper (Legacy - being phased out)
│   ├── SLACalculationUtility
│   ├── Entitlement_Utility
│   ├── CaseBusinessRuleService
│   ├── BusinessRuleHelper
│   └── CaseAttributeService
│
├── CaseAttributeService
│   ├── CaseContextGetter
│   ├── SystemObjectSelector
│   └── UTIL_LoggingService
│
├── CaseBusinessRuleService
│   ├── BusinessRuleHelper
│   ├── BusinessRuleUtility
│   ├── CaseContextGetter
│   ├── CaseWorkOrderService
│   ├── CaseTaskService
│   └── UTIL_LoggingService
│
├── CaseAssetValidator
│   ├── CaseContextGetter
│   ├── CaseDMLService
│   └── UTIL_LoggingService
│
├── SLACalculationUtility
│   ├── Entitlement_Utility
│   ├── CaseContextGetter
│   └── UTIL_LoggingService
│
├── CaseDMLService
│   └── UTIL_LoggingService
│
├── CaseContextGetter
│   └── UTIL_LoggingService
│
└── Entitlement_Utility
    ├── CaseContextGetter
    └── UTIL_LoggingService
```

---

## Migration Status

### Completed Migrations

✅ **CaseAttributeService** - Fully refactored
- Field initialization logic
- Contact synchronization
- Agent identification
- Basic attribute updates

✅ **CaseBusinessRuleService** - Fully refactored
- Business rule evaluation
- Approval logic
- WorkOrder-driven updates
- Task-driven updates
- UI button visibility logic

✅ **CaseAssetValidator** - Fully refactored
- Asset validation logic
- Case Asset relationship management
- Duplicate detection

✅ **CaseContextGetter** - Fully implemented
- Query centralization
- Caching implementation
- Consistent field selection

✅ **CaseDMLService** - Fully implemented
- DML centralization
- Error logging
- Partial success handling

✅ **SLACalculationUtility** - Refactored
- Eliminated static variable dependencies
- Parameter-based methods
- Improved testability

✅ **Entitlement_Utility** - Refactored
- Deprecated static variables
- Parameter-based getPrioritizedEntitlements()
- Improved data extraction

### Partial Migrations

🔄 **CaseTriggerHelper** - In progress
- Many methods delegating to services
- Static variables deprecated but maintained for compatibility
- Gradual method migration to appropriate services

### Pending Migrations

⏳ **CaseWorkOrderService** - Planned
- Work order creation orchestration
- Currently scattered across CaseTriggerHelper and CaseBusinessRuleService

⏳ **Integration Services** - Planned
- Acorn integration logic
- OfficeTrax integration logic
- Genesys integration logic

---

## Best Practices

### 1. Service Method Design

```apex
// ✅ GOOD: Clear responsibility, returns result object
public static ValidationResult validatePickupAsset(Id assetId, Date serviceDate) {
    // Validation logic
    return new ValidationResult(isValid, errorMessage, validationType);
}

// ❌ BAD: Unclear responsibility, modifies static variables
public static void validateAsset(Case c) {
    isValid = true; // Static variable
    // Validation logic modifies case directly
}
```

### 2. Data Access Pattern

```apex
// ✅ GOOD: Use CaseContextGetter
Map<Id, Case> cases = CaseContextGetter.getCaseMapByIds(caseIds);

// ❌ BAD: Direct SOQL in service classes
Map<Id, Case> cases = new Map<Id, Case>([SELECT Id FROM Case WHERE Id IN :caseIds]);
```

### 3. Error Handling

```apex
// ✅ GOOD: Proper exception handling with logging
try {
    // Business logic
} catch (Exception ex) {
    UTIL_LoggingService.logHandledException(ex, UserInfo.getOrganizationId(), 
        UTIL_ErrorConstants.ERROR_APPLICATION, LoggingLevel.ERROR);
    throw new AuraHandledException('User-friendly message');
}
```

### 4. Bulkification

```apex
// ✅ GOOD: Bulk processing
public static void processCases(List<Case> cases) {
    Set<Id> assetIds = new Set<Id>();
    for (Case c : cases) {
        if (c.AssetId != null) assetIds.add(c.AssetId);
    }
    Map<Id, Asset> assets = CaseContextGetter.getAssetsWithChildren(assetIds);
    // Process all cases with assets map
}

// ❌ BAD: Per-record processing
public static void processCase(Case c) {
    Asset a = CaseContextGetter.getAssetById(c.AssetId); // Query per case!
}
```

---

## Testing Strategy

### Unit Testing

Each service class should have comprehensive unit tests:

```apex
@isTest
private class CaseAttributeServiceTest {
    
    @testSetup
    static void setup() {
        // Create test data
    }
    
    @isTest
    static void testInitializeCases() {
        // Test case initialization
    }
    
    @isTest
    static void testUpdateCaseAttributes() {
        // Test attribute updates
    }
    
    @isTest
    static void testBulkProcessing() {
        // Test with 200 records
    }
}
```

### Integration Testing

Test service interaction:

```apex
@isTest
private class CaseTriggerHandlerTest {
    
    @isTest
    static void testBeforeInsertOrchestration() {
        // Test complete before insert flow
        // Validates multiple services working together
    }
}
```

---

## Performance Optimization

### 1. Caching Strategy

```apex
// CaseContextGetter implements caching
private static Map<Id, Case> caseCache = new Map<Id, Case>();

public static Case getCaseById(Id caseId) {
    if (caseCache.containsKey(caseId)) {
        return caseCache.get(caseId);
    }
    // Query and cache
}
```

### 2. Query Optimization

- Consistent field sets prevent redundant queries
- Bulk query methods reduce SOQL count
- Selective field querying reduces view state

### 3. DML Optimization

- Bulkified DML operations
- Database.insert(records, false) for partial success
- Strategic use of allOrNone parameter

---

## Conclusion

The Case trigger architecture has evolved from a monolithic design to a well-structured, service-oriented architecture that:

1. **Improves Maintainability**: Clear separation of concerns makes changes easier
2. **Enhances Testability**: Isolated services are easier to unit test
3. **Increases Performance**: Caching and bulkification reduce resource usage
4. **Supports Scalability**: Services can be extended without modifying existing code
5. **Ensures Consistency**: Centralized query and DML methods ensure data integrity

The architecture continues to evolve as legacy code is migrated to the new service layers, with the ultimate goal of completely phasing out CaseTriggerHelper and achieving a pure service-oriented design.
