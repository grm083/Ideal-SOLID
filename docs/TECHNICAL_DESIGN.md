# Technical Design Document
## Ideal-SOLID: Enterprise Case Management System

**Version:** 1.0
**Last Updated:** November 30, 2025
**Platform:** Salesforce Lightning Platform
**Author:** Development Team

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Architecture](#system-architecture)
3. [Design Principles](#design-principles)
4. [Component Architecture](#component-architecture)
5. [Service Layer Design](#service-layer-design)
6. [Data Model](#data-model)
7. [Integration Architecture](#integration-architecture)
8. [Performance Optimization](#performance-optimization)
9. [Security & Access Control](#security--access-control)
10. [Deployment Architecture](#deployment-architecture)
11. [Technical Standards](#technical-standards)

---

## Executive Summary

### Project Overview

Ideal-SOLID is an enterprise-grade Salesforce Lightning application that implements a sophisticated Case Management System for Waste Management Services. The system demonstrates a complete architectural transformation from monolithic Aura components to modern Lightning Web Components (LWC) with a well-architected service layer following SOLID principles.

### Key Objectives

- **Maintainability**: Implement SOLID principles for long-term code maintainability
- **Performance**: Achieve 90% reduction in Apex calls and 60% faster page loads
- **Scalability**: Support enterprise-level transaction volumes
- **Testability**: Achieve comprehensive test coverage with isolated unit tests
- **Modernization**: Migrate from legacy Aura to modern LWC architecture

### Technical Achievements

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Apex Calls per Page Load | 10-15 | 1 | 90% reduction |
| SOQL Queries | 25-40 | 3-5 | 85% reduction |
| Page Load Time | 3-5 seconds | 1-2 seconds | 60% faster |
| Component Attributes | 72 | 28 | 61% reduction |
| CPU Time | 8000ms | 1500ms | 81% reduction |

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interface Layer                      │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Lightning Web Components (89 Components)              │  │
│  │  - Root: caseDataGovernorLWC                           │  │
│  │  - Containers: Client, Location, Vendor, Service Date  │  │
│  │  - Functional: Search, Create, Update, Wizards         │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              Lightning Message Service (LMS)                 │
│  - CaseDataChannel (Data Distribution)                      │
│  - CaseUpdated__c (State Synchronization)                   │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                  Controller Layer (AuraEnabled)              │
│  - Minimal logic, delegates to services                     │
│  - Exception handling and response formatting               │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer (4-Tier)                    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Tier 1: Data Access Layer (ContextGetter Pattern)   │  │
│  │  - CaseContextGetter, AccountContextGetter, etc.     │  │
│  │  - Single source of truth for SOQL                   │  │
│  │  - Built-in caching and bulkification                │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Tier 2: Business Logic Layer                        │  │
│  │  - CaseBusinessRuleService, CaseAttributeService     │  │
│  │  - Domain logic, validations, calculations           │  │
│  │  - Approval workflows, SLA enforcement               │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Tier 3: UI Orchestration Layer                      │  │
│  │  - CaseUIService, QuoteProcurementUIService          │  │
│  │  - Data aggregation and wrapper composition          │  │
│  │  - Orchestrates multiple lower-tier services         │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Tier 4: Data Persistence Layer                      │  │
│  │  - CaseDMLService (Singleton pattern)                │  │
│  │  - Centralized DML with error handling               │  │
│  │  - Transaction management                            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Data & Configuration                      │
│  - Custom Objects (Case, Account, Contact, Asset, etc.)     │
│  - Custom Metadata Types (Business Rules, Button Config)    │
│  - Custom Settings (Feature Flags, Limits)                  │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                  External Integrations                       │
│  - CPQ (Quote Management)                                   │
│  - Genesys (Call Center)                                    │
│  - Acorn System (Work Orders)                               │
│  - OfficeTrax (Asset Tracking)                              │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

- **Platform**: Salesforce Lightning Platform (API v55.0+)
- **Frontend**: Lightning Web Components (LWC)
- **Backend**: Apex (130 classes, 58,224 lines of code)
- **Communication**: Lightning Message Service (Pub/Sub)
- **Data**: Custom Objects, Custom Metadata Types, Custom Settings
- **Integration**: REST APIs, Platform Events, Queueable Apex

---

## Design Principles

### SOLID Principles Implementation

#### 1. Single Responsibility Principle (SRP)

Each service class has exactly one reason to change:

**Data Access Only:**
```apex
public class CaseContextGetter {
    // ONLY retrieves data - NO business logic, NO DML, NO UI
    public static Case getCaseById(Id caseId) {
        return [SELECT Id, CaseNumber, Status FROM Case WHERE Id = :caseId];
    }
}
```

**Business Logic Only:**
```apex
public class CaseBusinessRuleService {
    // ONLY business rules - NO queries, NO DML, NO UI
    public static BusinessRuleResult evaluateBusinessRules(Case caseRecord) {
        BusinessRuleResult result = new BusinessRuleResult();
        // Apply business rules
        return result;
    }
}
```

**Data Persistence Only:**
```apex
public class CaseDMLService {
    // ONLY DML operations - NO business logic, NO queries
    public SaveResult updateCase(Case caseToUpdate) {
        Database.SaveResult result = Database.update(caseToUpdate, false);
        return new SaveResult(result);
    }
}
```

**UI Orchestration Only:**
```apex
public class CaseUIService {
    // ONLY orchestration - delegates to other services
    public static CaseUIWrapper getCaseUIData(Id caseId) {
        Case c = CaseContextGetter.getCaseById(caseId);
        BusinessRuleResult rules = CaseBusinessRuleService.evaluateBusinessRules(c);
        return new CaseUIWrapper(c, rules);
    }
}
```

#### 2. Open/Closed Principle (OCP)

Open for extension, closed for modification via Custom Metadata Types:

```apex
// Adding new buttons requires NO code changes - just create metadata record
List<Case_Highlight_Panel_Button__mdt> buttons =
    [SELECT Label, Action__c, Visibility_Rule__c, Order__c
     FROM Case_Highlight_Panel_Button__mdt
     WHERE Active__c = true
     ORDER BY Order__c];

// Dynamic button rendering in LWC
for (const button of metadata) {
    this.createButton(button.Label, button.Action__c);
}
```

#### 3. Liskov Substitution Principle (LSP)

Subtypes are substitutable for their base types through dependency injection:

```apex
// Singleton with test injection point
public class CaseDMLService {
    @TestVisible
    private static CaseDMLService testInstance;

    public static CaseDMLService getInstance() {
        if (Test.isRunningTest() && testInstance != null) {
            return testInstance;  // Substitute mock in tests
        }
        return instance;
    }
}

// Test injects mock
@isTest
static void testCaseUpdate() {
    CaseDMLService.testInstance = new MockCaseDMLService();
    // Mock behaves identically to real service
}
```

#### 4. Interface Segregation Principle (ISP)

Clients depend only on methods they use via specialized wrapper classes:

```apex
// Full wrapper for comprehensive UI (70+ properties)
public class CaseUIWrapper {
    @AuraEnabled public Case caseInfo;
    @AuraEnabled public BusinessRuleResult businessRules;
    @AuraEnabled public List<Task> relatedTasks;
    @AuraEnabled public List<Asset> relatedAssets;
    // ... 66+ more properties
}

// Minimal wrapper for simple UI (3 properties)
public class CaseSummaryWrapper {
    @AuraEnabled public String caseNumber;
    @AuraEnabled public String status;
    @AuraEnabled public String priority;
}
```

#### 5. Dependency Inversion Principle (DIP)

High-level modules depend on abstractions, not concrete implementations:

```
High-level: CaseUIService
    ↓ depends on abstraction
Middle-level: CaseContextGetter (abstraction layer)
    ↓ implements
Low-level: SOQL Queries (concrete implementation)
```

### Design Patterns

#### ContextGetter Pattern (Repository Pattern)

**Purpose**: Single source of truth for all data access

**Implementation**:
```apex
public class CaseContextGetter {
    // Consistent field sets
    private static final String CASE_STANDARD_FIELDS =
        'Id, CaseNumber, Status, Priority, Origin, Subject, Description';

    // Private cache
    private static Map<Id, Case> caseCache = new Map<Id, Case>();

    // Cache-first query pattern
    public static Case getCaseById(Id caseId) {
        if (caseCache.containsKey(caseId)) {
            return caseCache.get(caseId);
        }

        String query = 'SELECT ' + CASE_STANDARD_FIELDS +
                      ' FROM Case WHERE Id = :caseId';
        Case c = Database.query(query);
        caseCache.put(caseId, c);
        return c;
    }

    // Bulkified query pattern
    public static Map<Id, Case> getCasesByIds(Set<Id> caseIds) {
        Set<Id> uncachedIds = new Set<Id>();
        for (Id caseId : caseIds) {
            if (!caseCache.containsKey(caseId)) {
                uncachedIds.add(caseId);
            }
        }

        if (!uncachedIds.isEmpty()) {
            String query = 'SELECT ' + CASE_STANDARD_FIELDS +
                          ' FROM Case WHERE Id IN :uncachedIds';
            List<Case> cases = Database.query(query);
            for (Case c : cases) {
                caseCache.put(c.Id, c);
            }
        }

        Map<Id, Case> result = new Map<Id, Case>();
        for (Id caseId : caseIds) {
            result.put(caseId, caseCache.get(caseId));
        }
        return result;
    }
}
```

#### Governor Pattern (Facade Pattern)

**Purpose**: Single entry point for all page data to minimize server round-trips

**Implementation**:
```apex
public class CaseDataGovernorService {
    @AuraEnabled
    public static CasePageDataWrapper getCasePageData(
        Id caseId,
        Boolean includeRelatedRecords,
        Boolean evaluateBusinessRules
    ) {
        CasePageDataWrapper result = new CasePageDataWrapper();

        try {
            // Single comprehensive data fetch
            result.caseRecord = CaseContextGetter.getCaseById(caseId);
            result.account = AccountContextGetter.getAccountByCaseId(caseId);
            result.contact = ContactContextGetter.getContactByCaseId(caseId);

            if (includeRelatedRecords) {
                result.tasks = TaskContextGetter.getTasksByCaseId(caseId);
                result.assets = AssetContextGetter.getAssetsByCaseId(caseId);
                result.workOrders = WorkOrderContextGetter.getWorkOrdersByCaseId(caseId);
            }

            if (evaluateBusinessRules) {
                result.businessRules =
                    CaseBusinessRuleService.evaluateBusinessRules(result.caseRecord);
            }

            result.isSuccess = true;
        } catch (Exception e) {
            result.isSuccess = false;
            result.errorMessage = e.getMessage();
        }

        return result;
    }

    public class CasePageDataWrapper {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Case caseRecord;
        @AuraEnabled public Account account;
        @AuraEnabled public Contact contact;
        @AuraEnabled public List<Task> tasks;
        @AuraEnabled public List<Asset> assets;
        @AuraEnabled public List<WorkOrder> workOrders;
        @AuraEnabled public BusinessRuleResult businessRules;
    }
}
```

#### Singleton Pattern

**Purpose**: Ensure single instance for DML services to maintain transaction context

**Implementation**:
```apex
public class CaseDMLService {
    private static CaseDMLService instance;

    @TestVisible
    private static CaseDMLService testInstance;

    private CaseDMLService() {
        // Private constructor prevents direct instantiation
    }

    public static CaseDMLService getInstance() {
        if (Test.isRunningTest() && testInstance != null) {
            return testInstance;
        }

        if (instance == null) {
            instance = new CaseDMLService();
        }
        return instance;
    }
}
```

---

## Component Architecture

### Lightning Web Components Hierarchy

```
caseDataGovernorLWC (Root Component)
├── Loads all data via CaseDataGovernorService.getCasePageData()
├── Publishes data via Lightning Message Service
└── Manages refresh/reload events

customCaseHighlightPanelLWC (Primary UI)
├── Subscribes to CaseDataChannel
├── Displays case information
├── Renders dynamic action buttons
└── Handles button click events

Case Manager Containers
├── clientContainerLWC
│   ├── Client/Contact information
│   └── Contact search and creation
├── locationContainerLWC
│   ├── Location details
│   └── Address management
├── vendorContainerLWC
│   ├── Vendor selection
│   └── Supplier information
└── serviceDateContainerLWC
    ├── Service scheduling
    └── SLA compliance

Functional Components (30+ components)
├── searchExistingContactLWC
├── createPendingInformationTaskLWC
├── setCaseCustomerInfoLWC
├── changeRecordTypeLWC
└── vendorSearchLWC
```

### Component Communication Pattern

**Pub/Sub via Lightning Message Service:**

```javascript
// Publisher (caseDataGovernorLWC)
import { publish, MessageContext } from 'lightning/messageService';
import CASE_DATA_CHANNEL from '@salesforce/messageChannel/CaseDataChannel__c';

@wire(MessageContext)
messageContext;

publishCaseData(caseData) {
    const message = {
        caseData: caseData,
        timestamp: Date.now()
    };
    publish(this.messageContext, CASE_DATA_CHANNEL, message);
}

// Subscriber (customCaseHighlightPanelLWC)
import { subscribe, MessageContext } from 'lightning/messageService';
import CASE_DATA_CHANNEL from '@salesforce/messageChannel/CaseDataChannel__c';

@wire(MessageContext)
messageContext;

connectedCallback() {
    this.subscription = subscribe(
        this.messageContext,
        CASE_DATA_CHANNEL,
        (message) => this.handleCaseDataUpdate(message)
    );
}

handleCaseDataUpdate(message) {
    this.caseData = message.caseData;
    this.evaluateButtonVisibility();
}
```

---

## Service Layer Design

### Tier 1: Data Access Layer - ContextGetter Pattern

**Location**: `/classes/*ContextGetter.cls`

**Key Classes**:
- **CaseContextGetter** (914 lines) - Case record queries
- **AccountContextGetter** - Account queries
- **ContactContextGetter** - Contact queries
- **AssetContextGetter** - Asset queries
- **QuoteContextGetter** - CPQ Quote queries
- **TaskContextGetter** - Task queries
- **WorkOrderContextGetter** - WorkOrder queries

**Responsibilities**:
- Execute all SOQL queries for their respective objects
- Maintain consistent field selections across the application
- Implement caching to avoid redundant queries
- Support bulkification for batch operations
- Provide specialized query methods (by Id, by parent, with relationships)

**Example Methods**:
```apex
public class CaseContextGetter {
    // Single record queries
    public static Case getCaseById(Id caseId) { }
    public static Case getCaseByNumber(String caseNumber) { }

    // Collection queries
    public static Map<Id, Case> getCasesByIds(Set<Id> caseIds) { }
    public static List<Case> getCasesByAccountId(Id accountId) { }
    public static List<Case> getCasesByContactId(Id contactId) { }

    // Relationship queries
    public static Case getCaseWithAccount(Id caseId) { }
    public static Case getCaseWithContact(Id caseId) { }
    public static Case getCaseWithAssets(Id caseId) { }

    // Filtered queries
    public static List<Case> getOpenCasesByAccountId(Id accountId) { }
    public static List<Case> getCasesByStatusAndPriority(String status, String priority) { }
}
```

### Tier 2: Business Logic Layer

**Location**: `/classes/*BusinessRuleService.cls`, `/classes/*AttributeService.cls`

**Key Classes**:
- **CaseBusinessRuleService** (1,768 lines)
- **CaseAttributeService** (897 lines)
- **CaseApprovalService**
- **CaseTaskService**
- **QuoteProcurementBusinessRuleService**

**Responsibilities**:
- Implement all business rules and validations
- Calculate derived values (SLA dates, capacity requirements)
- Evaluate approval workflows
- Manage state transitions
- Apply field requirement rules

**Example Implementation**:
```apex
public class CaseBusinessRuleService {
    /**
     * Evaluates all business rules for a case
     */
    public static BusinessRuleResult evaluateBusinessRules(Case caseRecord) {
        BusinessRuleResult result = new BusinessRuleResult();

        // Evaluate field requirements
        result.requiredFields = evaluateFieldRequirements(caseRecord);

        // Evaluate button visibility
        result.visibleButtons = evaluateButtonVisibility(caseRecord);

        // Evaluate SLA compliance
        result.slaStatus = evaluateSLACompliance(caseRecord);

        // Evaluate approval requirements
        result.requiresApproval = evaluateApprovalRequirements(caseRecord);

        return result;
    }

    /**
     * Determines which fields are required based on case context
     */
    private static Map<String, Boolean> evaluateFieldRequirements(Case caseRecord) {
        Map<String, Boolean> requirements = new Map<String, Boolean>();

        // Service type specific requirements
        if (caseRecord.Service_Type__c == 'New Service') {
            requirements.put('Asset__c', true);
            requirements.put('Service_Date__c', true);
            requirements.put('Customer_PO__c', true);
        }

        // Record type specific requirements
        if (caseRecord.RecordType.DeveloperName == 'Customer_Service') {
            requirements.put('Contact__c', true);
            requirements.put('Location__c', true);
        }

        return requirements;
    }

    /**
     * Determines which buttons should be visible based on case state
     */
    private static List<String> evaluateButtonVisibility(Case caseRecord) {
        List<String> visibleButtons = new List<String>();

        // Metadata-driven button configuration
        List<Case_Highlight_Panel_Button__mdt> buttonConfigs =
            [SELECT Label, Action__c, Visibility_Rule__c
             FROM Case_Highlight_Panel_Button__mdt
             WHERE Active__c = true
             ORDER BY Order__c];

        for (Case_Highlight_Panel_Button__mdt config : buttonConfigs) {
            if (evaluateVisibilityRule(config.Visibility_Rule__c, caseRecord)) {
                visibleButtons.add(config.Action__c);
            }
        }

        return visibleButtons;
    }

    public class BusinessRuleResult {
        @AuraEnabled public Map<String, Boolean> requiredFields;
        @AuraEnabled public List<String> visibleButtons;
        @AuraEnabled public String slaStatus;
        @AuraEnabled public Boolean requiresApproval;
        @AuraEnabled public List<String> validationErrors;
    }
}
```

### Tier 3: UI Orchestration Layer

**Location**: `/classes/*UIService.cls`

**Key Classes**:
- **CaseUIService** (819 lines)
- **QuoteProcurementUIService**
- **CaseWizardService**

**Responsibilities**:
- Orchestrate multiple ContextGetters and BusinessRuleServices
- Compose complex wrapper objects for UI consumption
- Transform data into UI-friendly formats
- Aggregate related data from multiple sources

**Example Implementation**:
```apex
public class CaseUIService {
    @AuraEnabled
    public static CaseUIWrapper getCaseUIData(Id caseId) {
        CaseUIWrapper result = new CaseUIWrapper();

        // Delegate to ContextGetters for data
        result.caseRecord = CaseContextGetter.getCaseById(caseId);
        result.account = AccountContextGetter.getAccountByCaseId(caseId);
        result.contact = ContactContextGetter.getContactByCaseId(caseId);
        result.tasks = TaskContextGetter.getTasksByCaseId(caseId);
        result.assets = AssetContextGetter.getAssetsByCaseId(caseId);

        // Delegate to BusinessRuleService for logic
        result.businessRules =
            CaseBusinessRuleService.evaluateBusinessRules(result.caseRecord);

        // UI-specific transformations
        result.formattedCaseNumber = formatCaseNumber(result.caseRecord.CaseNumber);
        result.statusBadgeVariant = getStatusBadgeVariant(result.caseRecord.Status);
        result.priorityIcon = getPriorityIcon(result.caseRecord.Priority);

        return result;
    }

    public class CaseUIWrapper {
        @AuraEnabled public Case caseRecord;
        @AuraEnabled public Account account;
        @AuraEnabled public Contact contact;
        @AuraEnabled public List<Task> tasks;
        @AuraEnabled public List<Asset> assets;
        @AuraEnabled public BusinessRuleResult businessRules;
        @AuraEnabled public String formattedCaseNumber;
        @AuraEnabled public String statusBadgeVariant;
        @AuraEnabled public String priorityIcon;
    }
}
```

### Tier 4: Data Persistence Layer

**Location**: `/classes/*DMLService.cls`

**Key Classes**:
- **CaseDMLService** (700 lines) - Singleton pattern
- **QuoteProcurementDMLService**

**Responsibilities**:
- Centralized DML operations (insert, update, delete, undelete)
- Consistent error handling and logging
- Transaction management
- Partial success handling
- Rollback on failure

**Example Implementation**:
```apex
public class CaseDMLService {
    private static CaseDMLService instance;

    public static CaseDMLService getInstance() {
        if (instance == null) {
            instance = new CaseDMLService();
        }
        return instance;
    }

    /**
     * Updates a case with comprehensive error handling
     */
    public SaveResult updateCase(Case caseToUpdate) {
        SaveResult result = new SaveResult();

        try {
            Database.SaveResult dbResult = Database.update(caseToUpdate, false);

            if (dbResult.isSuccess()) {
                result.isSuccess = true;
                result.recordId = dbResult.getId();
            } else {
                result.isSuccess = false;
                result.errors = extractErrors(dbResult.getErrors());
            }
        } catch (Exception e) {
            result.isSuccess = false;
            result.errors = new List<String>{ e.getMessage() };
            logException(e);
        }

        return result;
    }

    /**
     * Bulk update with partial success handling
     */
    public List<SaveResult> updateCases(List<Case> casesToUpdate) {
        List<SaveResult> results = new List<SaveResult>();

        Database.SaveResult[] dbResults = Database.update(casesToUpdate, false);

        for (Database.SaveResult dbResult : dbResults) {
            SaveResult result = new SaveResult();

            if (dbResult.isSuccess()) {
                result.isSuccess = true;
                result.recordId = dbResult.getId();
            } else {
                result.isSuccess = false;
                result.errors = extractErrors(dbResult.getErrors());
            }

            results.add(result);
        }

        return results;
    }

    public class SaveResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public Id recordId;
        @AuraEnabled public List<String> errors;
    }
}
```

---

## Data Model

### Core Objects

#### Case (Enhanced Standard Object)

**Custom Fields**:
- `Service_Type__c` (Picklist): New Service, Pickup, Activation, Modify, Deactivate
- `Service_Sub_Type__c` (Picklist): Context-dependent sub-types
- `Service_Reason__c` (Picklist): Reason codes for service request
- `Location__c` (Lookup): Related location record
- `Asset__c` (Lookup): Related asset/equipment
- `Service_Date__c` (Date): Scheduled service date
- `SLA_Due_Date__c` (Date): Calculated SLA deadline
- `Customer_PO__c` (Text): Customer purchase order reference
- `Customer_Profile__c` (Text): Customer profile identifier
- `Customer_PSI__c` (Text): Customer PSI reference
- `Approval_Status__c` (Picklist): Pending, Approved, Rejected
- `Approval_Required__c` (Checkbox): Calculated approval requirement
- `Business_Rule_Validation__c` (Long Text): JSON validation results

#### Account (Enhanced Standard Object)

**Custom Fields**:
- `Account_Type__c` (Picklist): Customer, Vendor, Partner
- `Service_Territory__c` (Lookup): Geographic service area
- `CPQ_Integration_Id__c` (Text): External CPQ system identifier
- `OfficeTrax_Id__c` (Text): OfficeTrax system identifier

#### Custom Metadata Types

**Case_Highlight_Panel_Button__mdt**:
- `Label` (Text): Button display text
- `Action__c` (Text): Action identifier
- `Visibility_Rule__c` (Text): Expression for visibility evaluation
- `Order__c` (Number): Display order
- `Active__c` (Checkbox): Enable/disable button
- `Icon_Name__c` (Text): Lightning Design System icon

**Business_Rule__mdt**:
- `Name` (Text): Rule identifier
- `Object__c` (Text): Target object API name
- `Condition__c` (Long Text): Evaluation expression
- `Message__c` (Text): User-facing message
- `Severity__c` (Picklist): Info, Warning, Error
- `Active__c` (Checkbox): Enable/disable rule

---

## Integration Architecture

### External Systems

#### 1. CPQ (Quote Management)

**Integration Pattern**: REST API + Platform Events

**Endpoints**:
- `POST /quote/create` - Create new quote
- `GET /quote/{id}` - Retrieve quote details
- `PUT /quote/{id}/approve` - Approve quote
- `PUT /quote/{id}/submit` - Submit for procurement

**Implementation**:
```apex
public class CPQIntegrationService {
    private static final String CPQ_BASE_URL = 'https://cpq.example.com/api/v2';

    public static QuoteResponse createQuote(Case caseRecord) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(CPQ_BASE_URL + '/quote/create');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(buildQuoteRequest(caseRecord)));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            return (QuoteResponse) JSON.deserialize(res.getBody(), QuoteResponse.class);
        } else {
            throw new IntegrationException('CPQ Quote creation failed: ' + res.getBody());
        }
    }
}
```

#### 2. Genesys (Call Center Integration)

**Integration Pattern**: Screen Pop + Activity Logging

**Implementation**: Lightning Message Service integration with Genesys CTI adapter

#### 3. Acorn System (Work Order Management)

**Integration Pattern**: Outbound Message + REST Callback

**Flow**:
1. Case status changes trigger outbound message
2. Acorn processes work order
3. Acorn sends callback to update case
4. Platform Event triggers case update

#### 4. OfficeTrax (Asset Tracking)

**Integration Pattern**: Scheduled Batch Synchronization

**Implementation**:
```apex
global class OfficeTraxSyncBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, OfficeTrax_Id__c FROM Asset WHERE LastModifiedDate >= LAST_N_DAYS:1'
        );
    }

    global void execute(Database.BatchableContext bc, List<Asset> scope) {
        for (Asset a : scope) {
            syncAssetToOfficeTrax(a);
        }
    }
}
```

---

## Performance Optimization

### Governor Pattern Implementation

**Problem**: 10-15 separate Apex calls per page load

**Solution**: Single consolidated call returning all data

**Impact**:
- 90% reduction in Apex calls
- 85% reduction in SOQL queries
- 60% faster page load times

### Caching Strategy

**ContextGetter Cache**:
```apex
private static Map<Id, Case> caseCache = new Map<Id, Case>();

public static Case getCaseById(Id caseId) {
    if (caseCache.containsKey(caseId)) {
        return caseCache.get(caseId);  // Cache hit
    }
    // Query and cache
}
```

**Platform Cache** (for expensive calculations):
```apex
public class CacheService {
    private static final String CACHE_PARTITION = 'local.CaseData';

    public static void put(String key, Object value, Integer ttlSeconds) {
        Cache.Org.put(CACHE_PARTITION + '.' + key, value, ttlSeconds);
    }

    public static Object get(String key) {
        return Cache.Org.get(CACHE_PARTITION + '.' + key);
    }
}
```

### Bulkification

All ContextGetters support bulkified operations:
```apex
// Single: 1 SOQL query
Case c = CaseContextGetter.getCaseById(caseId);

// Bulk: Still 1 SOQL query for 200 cases
Map<Id, Case> cases = CaseContextGetter.getCasesByIds(caseIds);
```

### SOQL Optimization

**Consistent Field Sets**:
```apex
private static final String CASE_STANDARD_FIELDS =
    'Id, CaseNumber, Status, Priority, Origin, Subject, Description, ' +
    'RecordTypeId, RecordType.DeveloperName, AccountId, ContactId, ' +
    'Service_Type__c, Service_Date__c, SLA_Due_Date__c';
```

**Selective Queries**:
```apex
// Only query what's needed
public static Case getCaseBasicInfo(Id caseId) {
    return [SELECT Id, CaseNumber, Status FROM Case WHERE Id = :caseId];
}

// vs full query when needed
public static Case getCaseFullDetails(Id caseId) {
    return [SELECT Id, CaseNumber, Status, /* 50+ fields */ FROM Case WHERE Id = :caseId];
}
```

---

## Security & Access Control

### Object-Level Security

- Utilizes Salesforce standard object permissions
- Respects sharing rules via `with sharing` keyword
- Field-level security enforced in all ContextGetters

### Record-Level Security

```apex
public with sharing class CaseContextGetter {
    // Respects user's sharing rules
    public static List<Case> getCasesByAccountId(Id accountId) {
        // User only sees cases they have access to
        return [SELECT Id FROM Case WHERE AccountId = :accountId];
    }
}
```

### Field-Level Security

```apex
public class CaseContextGetter {
    public static Case getCaseById(Id caseId) {
        // Strip inaccessible fields
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.READABLE,
            [SELECT Id, CaseNumber, Status, Confidential_Notes__c FROM Case WHERE Id = :caseId]
        );
        return (Case) decision.getRecords()[0];
    }
}
```

### API Security

All `@AuraEnabled` methods validate permissions:
```apex
@AuraEnabled
public static CaseUIWrapper getCaseUIData(Id caseId) {
    if (!Schema.sObjectType.Case.isAccessible()) {
        throw new SecurityException('Insufficient permissions to access Case');
    }
    // Proceed with data retrieval
}
```

---

## Deployment Architecture

### Environment Strategy

- **Sandbox (Dev)**: Active development
- **Sandbox (QA)**: Quality assurance testing
- **Sandbox (UAT)**: User acceptance testing
- **Production**: Live environment

### Deployment Process

1. **Local Development** → Commit to feature branch
2. **Feature Branch** → Create pull request
3. **Code Review** → Automated tests + peer review
4. **Merge to Main** → Deploy to Dev sandbox
5. **QA Testing** → Deploy to QA sandbox
6. **UAT** → Deploy to UAT sandbox
7. **Production** → Deploy to Production (change set or CI/CD)

### Version Control

- **Repository**: Git-based version control
- **Branching Strategy**: Feature branches from main
- **Commit Standards**: Conventional commits
- **Code Review**: Required for all merges

---

## Technical Standards

### Coding Standards

**Apex**:
- Classes must have JavaDoc comments
- Methods must have `@description` annotations
- Maximum method length: 50 lines
- Maximum class length: 1000 lines
- All variables must use descriptive names
- No hardcoded IDs or strings (use Custom Metadata)

**Lightning Web Components**:
- Follow official LWC style guide
- Component names use camelCase with 'LWC' suffix
- Maximum component complexity: 300 lines JavaScript
- All public properties must have JSDoc comments

### Testing Standards

- **Minimum Coverage**: 85% for all classes
- **Unit Tests**: Test each method in isolation
- **Integration Tests**: Test service layer orchestration
- **Test Data**: Use TestDataFactoryRefactored for all test data
- **Assertions**: Every test must have explicit assertions

### Documentation Standards

- **README**: Project overview and setup instructions
- **Architecture Docs**: Design decisions and patterns
- **API Docs**: JavaDoc for all public methods
- **Change Log**: Track all significant changes

---

## Appendix

### File Structure

```
/home/user/Ideal-SOLID/
├── classes/
│   ├── CaseContextGetter.cls
│   ├── CaseContextGetterTest.cls
│   ├── CaseBusinessRuleService.cls
│   ├── CaseBusinessRuleServiceTest.cls
│   ├── CaseUIService.cls
│   ├── CaseUIServiceTest.cls
│   ├── CaseDMLService.cls
│   ├── CaseDMLServiceTest.cls
│   ├── CaseDataGovernorService.cls
│   └── CaseDataGovernorServiceTest.cls
├── lwc/
│   ├── caseDataGovernorLWC/
│   ├── customCaseHighlightPanelLWC/
│   └── showCaseMessagesLWC/
├── messageChannels/
│   ├── CaseDataChannel.messageChannel-meta.xml
│   └── CaseUpdated__c.messageChannel-meta.xml
└── docs/
    ├── ARCHITECTURE_DOCUMENTATION.md
    ├── GOVERNOR_ARCHITECTURE.md
    └── TECHNICAL_DESIGN.md
```

### Key Metrics

- **Total Classes**: 130 Apex classes
- **Total Lines of Code**: 58,224 lines
- **Test Classes**: 53 test classes
- **Test Coverage**: 85%+ average
- **LWC Components**: 89 components
- **Legacy Aura Components**: 205 components

---

**Document Maintained By**: Development Team
**Last Review Date**: November 30, 2025
**Next Review Date**: February 28, 2026
