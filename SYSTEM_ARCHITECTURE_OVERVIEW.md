# Ideal-SOLID: System Architecture Overview

**Version**: 1.0
**Last Updated**: 2025-11-22
**API Version**: 62.0
**Platform**: Salesforce Lightning Platform

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Project Overview](#project-overview)
3. [System Architecture](#system-architecture)
4. [Technology Stack](#technology-stack)
5. [Project Structure](#project-structure)
6. [Core Architectural Patterns](#core-architectural-patterns)
7. [Key Components and Modules](#key-components-and-modules)
8. [Data Flow and Integration](#data-flow-and-integration)
9. [Performance and Scalability](#performance-and-scalability)
10. [Documentation Map](#documentation-map)
11. [Development Guidelines](#development-guidelines)

---

## Executive Summary

### What is Ideal-SOLID?

Ideal-SOLID is an **enterprise-grade Case Management System** built on the Salesforce Lightning Platform for Waste Management operations. The system represents a complete architectural transformation from legacy Aura components to modern Lightning Web Components (LWC), implementing industry best practices and SOLID design principles.

### Key Metrics

| Aspect | Value |
|--------|-------|
| **Codebase Size** | 119 Apex classes, 52,997 lines of code |
| **Frontend Components** | 89 LWC components, 204 Aura components (legacy) |
| **Test Coverage** | 46 test classes, >85% coverage |
| **API Version** | Salesforce API v62.0 |
| **Performance Improvement** | 90% reduction in Apex calls, 60% faster page loads |
| **Architecture Pattern** | Service-Oriented Architecture (SOA) with SOLID principles |

### Business Value

- **Faster Performance**: 60% reduction in page load times
- **Scalability**: 90% reduction in server calls through Governor pattern
- **Maintainability**: Clean separation of concerns with 25+ service classes
- **Reliability**: Comprehensive test coverage and error handling
- **Modern Stack**: Migration to Lightning Web Components for future-proof development
- **Integration Ready**: Seamless connections to CPQ, Genesys, Acorn, OfficeTrax, and WM Capacity Planner

---

## Project Overview

### Purpose and Scope

The Ideal-SOLID system manages the complete lifecycle of customer service cases for waste management operations, including:

- **Case Creation and Management**: Multi-step wizards, record type handling, field validation
- **Customer Information Management**: Account, contact, and location management
- **Asset Management**: Service location assets, container tracking, equipment management
- **Service Level Agreements (SLA)**: Automatic SLA calculation based on entitlements
- **Work Order Generation**: Integration with Acorn system for field service
- **Quote and Procurement**: CPQ integration for pricing and quoting
- **Business Rule Enforcement**: Dynamic validation and approval workflows
- **Task Management**: Automated task creation and tracking

### Target Users

- **Customer Service Representatives**: Case intake and management
- **Account Managers**: Customer relationship management
- **Operations Team**: Work order coordination
- **Management**: Reporting and oversight
- **System Administrators**: Configuration and customization

### Key Features

1. **Intelligent Case Routing**: Automatic assignment based on case type, location, and business rules
2. **Real-time SLA Calculation**: Dynamic service date calculation based on entitlements and capacity
3. **Unified Case View**: Single page with all relevant case information using Governor pattern
4. **Business Rule Validation**: Configurable validation rules enforced at multiple levels
5. **Multi-channel Integration**: Seamless integration with external systems
6. **Audit Trail**: Complete tracking of case changes and user actions

---

## System Architecture

### Architecture Philosophy

The system follows a **Service-Oriented Architecture (SOA)** with strict adherence to **SOLID principles**:

- **Single Responsibility**: Each service class has one primary responsibility
- **Open/Closed**: Open for extension, closed for modification
- **Liskov Substitution**: Consistent interfaces and contracts
- **Interface Segregation**: Focused, purposeful public APIs
- **Dependency Inversion**: Services depend on abstractions, not implementations

### Architectural Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                         PRESENTATION LAYER                       │
│  Lightning Web Components (89) + Aura Components (204 legacy)   │
│  - UI Components                                                 │
│  - Event Handling                                                │
│  - User Interaction                                              │
└────────────────────────┬────────────────────────────────────────┘
                         │ Lightning Message Service (LMS)
                         │ @AuraEnabled Apex Methods
┌────────────────────────▼────────────────────────────────────────┐
│                      ORCHESTRATION LAYER                         │
│  Governor Pattern (CaseDataGovernorService)                      │
│  - Single entry point for page loads                             │
│  - Coordinates multiple services                                 │
│  - Aggregates data for UI consumption                            │
│  Performance: Reduces 15 calls to 1                              │
└────────────────────────┬────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┬────────────────────────┐
        │                │                │                        │
┌───────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐ ┌──────────────▼─┐
│ UI Service   │ │ Business    │ │ Attribute   │ │ Specialized    │
│ Layer        │ │ Rule        │ │ Service     │ │ Services       │
│              │ │ Service     │ │             │ │ (CPQ, WO, etc.)│
│ - UI Prep    │ │ - Validation│ │ - Init      │ │                │
│ - Wrappers   │ │ - Rules     │ │ - Defaults  │ │ - CPQ          │
│ - Format     │ │ - Approval  │ │ - Calc      │ │ - Work Orders  │
└───────┬──────┘ └──────┬──────┘ └──────┬──────┘ └────────┬───────┘
        │                │                │                 │
        └────────────────┴────────────────┴─────────────────┘
                                  │
┌─────────────────────────────────▼───────────────────────────────┐
│                      DATA ACCESS LAYER                           │
│  ContextGetter Pattern (8 classes)                               │
│  - CaseContextGetter                                             │
│  - AccountContextGetter                                          │
│  - ContactContextGetter                                          │
│  - AssetContextGetter                                            │
│  - QuoteContextGetter                                            │
│  - TaskContextGetter                                             │
│  - WorkOrderContextGetter                                        │
│  Features: Caching, consistent field selection, bulkification    │
└─────────────────────────────────┬───────────────────────────────┘
                                  │
┌─────────────────────────────────▼───────────────────────────────┐
│                      PERSISTENCE LAYER                           │
│  CaseDMLService (Singleton)                                      │
│  - Create, Update, Delete operations                             │
│  - Transaction management                                        │
│  - Error handling                                                │
└─────────────────────────────────┬───────────────────────────────┘
                                  │
┌─────────────────────────────────▼───────────────────────────────┐
│                      SALESFORCE DATABASE                         │
│  - Standard Objects (Case, Account, Contact, Asset, etc.)       │
│  - Custom Objects                                                │
│  - Custom Metadata Types                                         │
└─────────────────────────────────────────────────────────────────┘
```

### Architectural Highlights

1. **Governor Pattern**: Revolutionary performance optimization reducing Apex calls by 90%
2. **ContextGetter Pattern**: Single source of truth for queries with intelligent caching
3. **Service Layer**: 25+ specialized services for separation of concerns
4. **Lightning Message Service**: Real-time pub/sub communication between components
5. **Trigger Architecture**: Centralized trigger handling with service delegation
6. **Test-Driven**: Comprehensive test coverage with TestDataFactory

---

## Technology Stack

### Core Technologies

#### Salesforce Platform
- **Salesforce Lightning Platform**: Core infrastructure
- **API Version**: 62.0
- **Edition**: Enterprise/Unlimited (production)

#### Backend Technologies
- **Apex**: Primary backend language
  - Version: API 62.0
  - Total Classes: 119
  - Lines of Code: 52,997
  - Test Classes: 46
- **SOQL**: Salesforce Object Query Language
- **SOSL**: Salesforce Object Search Language
- **DML**: Data Manipulation Language

#### Frontend Technologies
- **Lightning Web Components (LWC)**: 89 components
  - HTML5, CSS3, JavaScript (ES6+)
  - Lightning Data Service (LDS)
  - Lightning Message Service (LMS)
  - Lightning Navigation Service
  - Lightning Record UI APIs
- **Aura Framework**: 204 components (legacy, being migrated)

#### Communication & Messaging
- **Lightning Message Service (LMS)**: Real-time pub/sub
  - CaseDataChannel: Primary data distribution
  - CaseUpdated__c: Update notifications

#### External Integrations
- **Salesforce CPQ**: Quote and product configuration
- **Genesys**: Call center and case routing
- **Acorn System**: Legacy work order management
- **OfficeTrax**: Service management and tracking
- **WM Capacity Planner API**: Rolloff scheduling and capacity planning

#### Testing Framework
- **Apex Test Framework**: @isTest annotations
- **Mock Framework**: Test.setMock for callouts
- **Test Data Factory**: Centralized test data generation

#### Configuration Management
- **Custom Metadata Types**: 30+ metadata types for configuration
- **Custom Settings**: Legacy configuration storage
- **Platform Cache**: Performance optimization (future implementation)

### Development Tools

- **Version Control**: Git
- **IDE Support**: VS Code with Salesforce Extensions
- **CLI**: Salesforce CLI (sf/sfdx)
- **Documentation**: Markdown
- **Deployment**: Salesforce Metadata API

---

## Project Structure

### Root Directory Structure

```
Ideal-SOLID/
│
├── aura/                                    # Legacy Aura Components (204)
│   ├── CustomCaseHighlightPanel/
│   ├── ShowCaseMessages/
│   ├── ClientContainer/
│   └── ... (201 more components)
│
├── classes/                                 # Apex Backend (119 classes)
│   │
│   ├── Service Layer/                       # Business Logic (25+ services)
│   │   ├── CaseBusinessRuleService.cls      # Business rules (1,808 lines)
│   │   ├── CaseAttributeService.cls         # Attribute management (900 lines)
│   │   ├── CaseUIService.cls                # UI orchestration (831 lines)
│   │   ├── CaseDataGovernorService.cls      # Governor pattern (318 lines)
│   │   ├── CaseDMLService.cls               # DML operations
│   │   ├── CaseWorkOrderService.cls         # Work order management
│   │   ├── CaseTaskService.cls              # Task management
│   │   ├── CaseCPQService.cls               # CPQ integration
│   │   ├── CaseWizardService.cls            # Wizard workflows
│   │   ├── CaseApprovalService.cls          # Approval processes
│   │   └── ... (15+ more services)
│   │
│   ├── Data Access Layer/                   # ContextGetter Pattern (8 classes)
│   │   ├── CaseContextGetter.cls            # Case queries (914 lines)
│   │   ├── AccountContextGetter.cls         # Account queries
│   │   ├── ContactContextGetter.cls         # Contact queries
│   │   ├── AssetContextGetter.cls           # Asset queries
│   │   ├── QuoteContextGetter.cls           # Quote queries
│   │   ├── TaskContextGetter.cls            # Task queries
│   │   ├── WorkOrderContextGetter.cls       # Work order queries
│   │   └── QuoteProcurementContextGetter.cls
│   │
│   ├── Controllers/                         # LWC Backend (20+ controllers)
│   │   ├── CaseController.cls
│   │   ├── CaseHighlightStripController.cls
│   │   ├── BusinessRuleValidatorController.cls
│   │   ├── AssetSelectorController.cls
│   │   └── ... (16+ more controllers)
│   │
│   ├── Utilities/                           # Helper Classes
│   │   ├── SLACalculationUtility.cls        # SLA calculations
│   │   ├── Entitlement_Utility.cls          # Entitlement matching
│   │   ├── UniversalQueryUtility.cls        # Query builder
│   │   ├── BusinessRuleUtility.cls          # Business rule queries
│   │   └── UTIL_LoggingService.cls          # Logging service
│   │
│   ├── Trigger Handlers/                    # Trigger Logic
│   │   ├── CaseTriggerHandler.cls           # Main Case trigger
│   │   ├── CaseTriggerHelper.cls            # Legacy adapter
│   │   ├── CaseAssetTriggerHandler.cls      # Case Asset triggers
│   │   └── CaseAssetTriggerHelper.cls
│   │
│   └── Tests/                               # Test Classes (46)
│       ├── TestDataFactoryRefactored.cls    # Test data factory
│       └── ... (*Test.cls for each class)
│
├── lwc/                                     # Lightning Web Components (89)
│   │
│   ├── Core Components/
│   │   ├── caseDataGovernorLWC/             # Governor pattern hub
│   │   ├── customCaseHighlightPanelLWC/     # Case highlights
│   │   ├── showCaseMessagesLWC/             # Case messages
│   │   └── caseNavigationLWC/               # Navigation
│   │
│   ├── Customer Management/
│   │   ├── setCaseCustomerInfoLWC/          # Customer info
│   │   ├── clientContainerLWC/              # Client selection
│   │   ├── contactSelector/                 # Contact selection
│   │   └── searchExistingContactLWC/        # Contact search
│   │
│   ├── Location & Assets/
│   │   ├── locationContainerLWC/            # Location management
│   │   ├── locationAssetSearchLWC/          # Asset search
│   │   ├── assetSelector/                   # Asset selection
│   │   └── caseLocationDetailsLWC/          # Location details
│   │
│   ├── Business Rules/
│   │   ├── businessRuleValidator/           # Rule validation
│   │   ├── allRulesModal/                   # Rules display
│   │   └── ntebRulesModalLWC/               # NTEB rules
│   │
│   ├── Quote & Procurement/
│   │   ├── caseQuoteModalLWC/               # Quote modal
│   │   ├── existingQuoteModalLWC/           # Quote selection
│   │   └── addFavoriteContainersLWC/        # Favorites
│   │
│   ├── Workflow Components/
│   │   ├── caseWizardStepper/               # Multi-step wizard
│   │   ├── changeRecordTypeLWC/             # Record type change
│   │   ├── closeCasePopLWC/                 # Close case
│   │   └── createPendingInformationTaskLWC/ # Task creation
│   │
│   └── UI Utilities/
│       ├── uiCustomLookupLWC/               # Custom lookup
│       ├── alertCard/                       # Alerts
│       ├── validationMessageBar/            # Validation messages
│       ├── progressIndicator/               # Progress display
│       └── ... (10+ more utilities)
│
├── messageChannels/                         # Lightning Message Service
│   ├── CaseDataChannel.messageChannel-meta.xml
│   └── CaseUpdated__c.messageChannel-meta.xml
│
├── objects/                                 # Custom Objects Metadata
│   └── ... (Custom object definitions)
│
├── documentation/                           # Technical Specifications
│   ├── Case_Trigger_Architecture.md         # Trigger architecture (1,128 lines)
│   ├── Entitlement_and_SLA_Service_Layer.md # SLA documentation
│   ├── SLA_Entitlement_Data_Flow_Diagram.md # Visual diagrams
│   ├── SLA_Entitlement_Quick_Reference.md   # Quick reference
│   └── SLA_Entitlement_Technical_Specification.md
│
├── docs/                                    # Development Guides
│   ├── COMPONENT_REFACTORING_GUIDE.md       # Refactoring guide
│   ├── GOVERNOR_ARCHITECTURE.md             # Governor pattern docs
│   ├── LWC_NAMING_CONVENTION.md             # Naming standards
│   ├── CONVERSION_SUMMARY.md                # Migration summary
│   └── NEW_LWC_COMPONENTS.md                # Component inventory
│
├── Root Documentation/
│   ├── SYSTEM_ARCHITECTURE_OVERVIEW.md      # This document
│   ├── ARCHITECTURE_DOCUMENTATION.md        # Detailed architecture (3,125 lines)
│   ├── REFACTORING_PLAN.md                  # Refactoring roadmap
│   ├── REFRESH_PATTERN.md                   # Data refresh patterns
│   ├── PHASE1_COMPLETION_SUMMARY.md         # Phase reports
│   ├── PHASE2_PROGRESS.md
│   ├── PHASE4_COMPLETION_SUMMARY.md
│   └── PHASE5_COMPLETION_SUMMARY.md
│
└── package.xml                              # Deployment Manifest
```

### Code Organization Principles

1. **Service Layer First**: Business logic lives in service classes, not controllers
2. **Single Responsibility**: Each class has one primary purpose
3. **Consistent Naming**: Clear patterns for services, controllers, and utilities
4. **LWC Suffix**: All new components use "LWC" suffix during migration
5. **Test Co-location**: Test classes named *Test.cls alongside source files
6. **Documentation**: Inline documentation plus markdown files

---

## Core Architectural Patterns

### 1. Governor Pattern (Data Centralization)

**Problem**: Multiple components making 10-15 separate Apex calls on page load, causing performance degradation.

**Solution**: Single entry point that loads all data in one call and distributes via Lightning Message Service.

**Implementation**: `CaseDataGovernorService.cls`

**Flow**:
```
Component Load
    ↓
caseDataGovernorLWC
    ↓
CaseDataGovernorService.getCasePageData(caseId)
    ↓
Returns ALL page data in single call
    ↓
Publishes to LMS (CaseDataChannel)
    ↓
All subscribed components receive data
```

**Benefits**:
- 90% reduction in Apex calls (15 → 1)
- 85% reduction in SOQL queries
- 60% faster page load times
- Centralized error handling
- Consistent data state across components

**Location**: `/classes/CaseDataGovernorService.cls` (318 lines)

### 2. ContextGetter Pattern (Repository Pattern)

**Problem**: Duplicate queries, inconsistent field selection, no caching.

**Solution**: Centralized data access layer with intelligent caching and consistent field sets.

**Characteristics**:
- Private static caching to avoid redundant queries
- Consistent field sets defined as constants
- Bulkified methods for governor limits
- Cache-first query pattern
- Single source of truth for each object

**Example**:
```apex
public class CaseContextGetter {
    // Cache
    private static Map<Id, Case> caseCache = new Map<Id, Case>();

    // Consistent field set
    private static final String CASE_FIELDS =
        'Id, CaseNumber, Subject, Status, Priority, OwnerId...';

    // Cache-first query
    public static Case getCaseById(Id caseId) {
        if (caseCache.containsKey(caseId)) {
            return caseCache.get(caseId);
        }
        Case c = [SELECT ... FROM Case WHERE Id = :caseId];
        caseCache.put(caseId, c);
        return c;
    }
}
```

**Available ContextGetters**:
- CaseContextGetter (914 lines)
- AccountContextGetter
- ContactContextGetter
- AssetContextGetter
- QuoteContextGetter
- TaskContextGetter
- WorkOrderContextGetter
- QuoteProcurementContextGetter

### 3. Service Layer Pattern

**Purpose**: Separation of concerns with dedicated services for specific domains.

**Service Categories**:

**UI Services**:
- CaseUIService: UI data preparation and formatting

**Business Logic Services**:
- CaseBusinessRuleService: Business rule validation (1,808 lines)
- CaseApprovalService: Approval workflow management

**Domain Services**:
- CaseAttributeService: Field initialization and calculation (900 lines)
- CaseWorkOrderService: Work order generation and management
- CaseTaskService: Task creation and lifecycle
- CaseCPQService: CPQ integration and quote management

**Utility Services**:
- SLACalculationUtility: SLA date calculation
- Entitlement_Utility: Entitlement matching and prioritization

### 4. Publish-Subscribe Pattern (Lightning Message Service)

**Purpose**: Decouple components and enable real-time data distribution.

**Implementation**: CaseDataChannel (LMS)

**Message Structure**:
```javascript
{
    caseId: "500...",
    eventType: "load|refresh|update|error",
    pageData: "{...}",  // JSON string
    section: "customer|location|assets",
    timestamp: "2025-11-22T10:30:00Z",
    errorMessage: ""
}
```

**Publisher**: caseDataGovernorLWC
**Subscribers**: All case page components (20+)

**Event Types**:
- `load`: Initial page load
- `refresh`: Full data refresh
- `update`: Partial update
- `error`: Error notification

### 5. Wrapper Pattern

**Purpose**: Encapsulate complex data structures for UI consumption.

**Examples**:
```apex
public class CaseUIWrapper {
    @AuraEnabled public Case caseInfo {get;set;}
    @AuraEnabled public BusinessRuleResult businessRuleResults {get;set;}
    @AuraEnabled public Boolean showProgressButton {get;set;}
    @AuraEnabled public List<Task> relatedTasks {get;set;}
    @AuraEnabled public List<WorkOrder> relatedWorkOrders {get;set;}
    @AuraEnabled public Map<String, String> fieldPermissions {get;set;}
}
```

### 6. Singleton Pattern

**Implementation**: CaseDMLService

**Purpose**: Single point of data persistence with transaction management.

```apex
public class CaseDMLService {
    private static CaseDMLService instance;

    public static CaseDMLService getInstance() {
        if (instance == null) {
            instance = new CaseDMLService();
        }
        return instance;
    }

    public Database.SaveResult updateCase(Case c) {
        // Centralized error handling
        // Logging
        // Transaction management
    }
}
```

### 7. Strategy Pattern

**Implementation**: Entitlement matching with priority-based selection.

**Entitlement Matching Ranks**:
- Rank 0: Customer + Service + Transaction (most specific)
- Rank 1: Customer + Service
- Rank 2: Customer + Transaction
- Rank 3: Customer only
- Rank 4: Service + Transaction
- Rank 5: Service only
- Rank 6: Transaction only
- Rank 7: Industry standard (least specific)

### 8. Factory Pattern

**Implementation**: TestDataFactoryRefactored

**Purpose**: Centralized test data creation with consistent setup.

```apex
public class TestDataFactoryRefactored {
    public static Account createAccount(String type, String recordType);
    public static Contact createContact(Id accountId);
    public static Case createCase(Id accountId, Id contactId);
    public static List<Account> createAccounts(Integer count, String type);
    // 50+ factory methods
}
```

### 9. Facade Pattern

**Implementation**: CaseUIService as orchestration facade.

**Purpose**: Simplify complex subsystem interactions for UI layer.

```apex
public class CaseUIService {
    public static CaseUIWrapper getCaseUIData(Id caseId) {
        // Orchestrates multiple services
        Case c = CaseContextGetter.getCaseByIdExtended(caseId);
        BusinessRuleResult rules = CaseBusinessRuleService.evaluateBusinessRules(c);
        List<Task> tasks = TaskContextGetter.getTasksByCaseId(caseId);
        // Combines into single wrapper
        return new CaseUIWrapper(c, rules, tasks);
    }
}
```

### 10. Chain of Responsibility

**Implementation**: Trigger handler delegation.

**Flow**:
```
CaseTrigger (before insert/update)
    ↓
CaseTriggerHandler.beforeInsert()
    ↓
    ├── CaseAttributeService.initializeCases()
    ├── CaseBusinessRuleService.evaluateBusinessRules()
    ├── SLACalculationUtility.calculateAndSetSLAFields()
    └── CaseAssetValidator.validateCaseAssets()
```

---

## Key Components and Modules

### Backend Modules

#### Case Management Module
**Purpose**: Core case lifecycle management

**Key Classes**:
- `CaseBusinessRuleService.cls` (1,808 lines): Business rule engine
- `CaseAttributeService.cls` (900 lines): Field management
- `CaseUIService.cls` (831 lines): UI orchestration
- `CaseDataGovernorService.cls` (318 lines): Governor pattern
- `CaseDMLService.cls`: Data persistence

**Responsibilities**:
- Case initialization and defaults
- Business rule validation
- Field population and calculation
- Status transitions
- Approval workflows

#### SLA and Entitlement Module
**Purpose**: Service level agreement management

**Key Classes**:
- `SLACalculationUtility.cls`: SLA date calculation
- `Entitlement_Utility.cls`: Entitlement matching

**Capabilities**:
- Priority-based entitlement matching (8 ranks)
- Business hours calculation
- Holiday handling
- Capacity-based scheduling
- Integration with WM Capacity Planner API

**Documentation**: `/documentation/Entitlement_and_SLA_Service_Layer.md`

#### Quote and Procurement Module
**Purpose**: Quote management and product procurement

**Key Services** (14 services):
- QuoteProcurementUIService
- QuoteProcurementBusinessRuleService
- QuoteProcurementDMLService
- QuoteProcurementSearchService
- QuoteProcurementProductService
- QuoteProcurementOrderService
- QuoteProcurementIntegrationService

**Integration**: Salesforce CPQ

#### Work Order Module
**Purpose**: Field service work order management

**Key Classes**:
- `CaseWorkOrderService.cls`: Work order generation
- Integration with Acorn System
- Integration with OfficeTrax

#### Task Management Module
**Purpose**: Case-related task creation and tracking

**Key Classes**:
- `CaseTaskService.cls`: Task lifecycle management
- `TaskContextGetter.cls`: Task queries

### Frontend Modules

#### Governor Hub Component
**Component**: `caseDataGovernorLWC`

**Purpose**: Central data distribution hub

**Features**:
- Single Apex call on page load
- LMS publishing for data distribution
- Error handling and retry logic
- Cache management

**Performance Impact**: 90% reduction in Apex calls

#### Case Highlight and Navigation
**Components**:
- `customCaseHighlightPanelLWC`: Case highlights, quick actions
- `caseNavigationLWC`: Case navigation controls
- `showCaseMessagesLWC`: Business rules and messages

#### Customer Information Components
**Components**:
- `setCaseCustomerInfoLWC`: Customer info management
- `clientContainerLWC`: Client selection
- `clientSearchLWC`: Client search
- `contactSelector`: Contact selection

#### Location and Asset Components
**Components**:
- `locationContainerLWC`: Location management
- `locationAssetSearchLWC`: Asset search
- `assetSelector`: Asset selection
- `caseLocationDetailsLWC`: Location details

#### Business Rule Validator
**Component**: `businessRuleValidator`

**Purpose**: Real-time business rule validation

**Features**:
- Dynamic rule evaluation
- Visual feedback
- Blocking vs. warning rules
- Rule detail modals

#### Workflow Components
**Components**:
- `caseWizardStepper`: Multi-step wizard
- `changeRecordTypeLWC`: Record type change
- `closeCasePopLWC`: Case closure workflow

#### Reusable UI Utilities
**Components**:
- `uiCustomLookupLWC`: Custom lookup
- `alertCard`: Alert display
- `validationMessageBar`: Validation messages
- `progressIndicator`: Progress display
- `customCalendarLWC`: Calendar component

---

## Data Flow and Integration

### Page Load Data Flow

```
1. User Opens Case Record Page
   │
2. caseDataGovernorLWC.connectedCallback()
   │
3. Call: CaseDataGovernorService.getCasePageData(caseId)
   │
   ├─→ CaseUIService.getCaseUIData(caseId)
   │   ├─→ CaseContextGetter.getCaseByIdExtended(caseId)
   │   ├─→ AccountContextGetter.getAccountById(accountId)
   │   ├─→ ContactContextGetter.getContactById(contactId)
   │   ├─→ AssetContextGetter.getAssetsByCaseId(caseId)
   │   ├─→ CaseBusinessRuleService.evaluateBusinessRules(case)
   │   ├─→ TaskContextGetter.getTasksByCaseId(caseId)
   │   └─→ WorkOrderContextGetter.getWorkOrdersByCaseId(caseId)
   │
4. Returns CasePageDataWrapper (ALL data)
   │
5. caseDataGovernorLWC publishes to LMS
   │
   └─→ Message: {
         caseId: "500...",
         eventType: "load",
         pageData: "{...all data...}",
         timestamp: "..."
       }
   │
6. All Subscribed Components Receive Data
   │
   ├─→ customCaseHighlightPanelLWC
   ├─→ showCaseMessagesLWC
   ├─→ caseNavigationLWC
   ├─→ locationContainerLWC
   ├─→ clientContainerLWC
   └─→ [15+ more components]
```

### Data Update Flow

```
1. User Updates Field (e.g., Location)
   │
2. locationContainerLWC.handleSave()
   │
3. Call: CaseController.updateCaseLocation(caseId, locationId)
   │
   ├─→ CaseContextGetter.getCaseById(caseId)
   ├─→ AccountContextGetter.getLocationById(locationId)
   ├─→ CaseAttributeService.updateCaseFromLocation(case, location)
   ├─→ CaseDMLService.updateCase(case)
   │
4. Success → locationContainerLWC.handleSuccess()
   │
5. Dispatch Custom Event: 'refresh'
   │
6. Parent Component Handles Refresh
   │
   ├─→ notifyRecordUpdateAvailable([{recordId}])  // LDS refresh
   └─→ publish(LMS, {eventType: 'reload'})        // Governor refresh
   │
7. caseDataGovernorLWC.handleRefreshRequest()
   │
8. Re-call CaseDataGovernorService.getCasePageData()
   │
9. Publish Fresh Data via LMS
   │
10. All Components Automatically Update
```

### Business Rule Evaluation Flow

```
DML Operation (Insert/Update Case)
    ↓
CaseTrigger.beforeInsert/beforeUpdate
    ↓
CaseTriggerHandler.beforeInsert()
    ↓
    ├─→ CaseAttributeService.initializeCases(cases)
    │   └─→ Set defaults, calculate derived fields
    │
    ├─→ CaseBusinessRuleService.evaluateBusinessRules(case)
    │   ├─→ BusinessRuleUtility.getBusinessRules(type, subType)
    │   ├─→ Evaluate approval requirements
    │   ├─→ Validate mandatory fields
    │   └─→ Return BusinessRuleResult
    │
    ├─→ SLACalculationUtility.calculateAndSetSLAFields(cases, locations)
    │   ├─→ Entitlement_Utility.getPrioritizedEntitlements(caseIds)
    │   ├─→ Calculate service dates with business hours
    │   ├─→ Call WM Capacity Planner API (if rolloff)
    │   └─→ Set SLA_Service_Date_Time__c
    │
    └─→ CaseAssetValidator.validateCaseAssets(case)
        └─→ Validate asset eligibility and requirements
    ↓
Database.SaveResult
```

### External System Integrations

#### CPQ Integration
```
Case
  ↓
CaseCPQService.createQuote()
  ↓
Opportunity → Quote → QuoteLines
  ↓
Product Configuration
  ↓
Pricing Calculation
  ↓
Quote Document Generation
```

#### Work Order Integration
```
Case
  ↓
CaseWorkOrderService.createWorkOrder()
  ↓
WorkOrder
  ├─→ Acorn System (Legacy)
  │   └─→ Field Service Dispatch
  │
  └─→ Genesys
      └─→ Call Routing & Tracking
```

#### Capacity Planning Integration
```
Case (Record Type: Rolloff)
  ↓
SLACalculationUtility.callWMCapacityPlannerAPI()
  ↓
HTTP Callout → WM Capacity Planner API
  ↓
Payload: {location, serviceType, requestedDate}
  ↓
Response: {availableDates[], capacity}
  ↓
Update Case.Service_Date__c
```

#### OfficeTrax Integration
```
Case → WorkOrder → OfficeTrax
  ↓
Service Tracking
Field Service Management
Resource Allocation
```

---

## Performance and Scalability

### Performance Metrics

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Apex Calls per Page Load | 10-15 | 1 | **90% reduction** |
| SOQL Queries per Page Load | 25-40 | 3-5 | **85% reduction** |
| Page Load Time | 3-5 seconds | 1-2 seconds | **60% faster** |
| Component Attributes | 72 | 28 | **61% reduction** |
| Data Transfer Size | ~500KB | ~200KB | **60% smaller** |

### Scalability Features

#### 1. Bulkification
All service methods handle collections, not single records:
```apex
public static void initializeCases(List<Case> cases) {
    // Processes 200 cases in one transaction
}
```

#### 2. Query Optimization
- ContextGetter caching reduces redundant queries
- Selective field queries (no SELECT *)
- Indexed field filtering

#### 3. Governor Limit Management
- Bulkified SOQL queries
- Efficient DML operations
- Map-based lookups instead of nested loops
- @future methods for async processing

#### 4. Caching Strategy
- Static caching in ContextGetters
- Component-level caching in LWC
- Platform Cache (future implementation)

#### 5. Efficient Data Loading
- Single comprehensive query vs. multiple small queries
- Related record prefetching
- Lazy loading for optional data

### Best Practices Applied

1. **One Trigger Per Object**: Single CaseTrigger delegates to handler
2. **Avoid SOQL in Loops**: All queries use bulkified methods
3. **Use Maps for Lookups**: O(1) instead of O(n) lookups
4. **Minimize View State**: Lightning Components, not VF pages
5. **Async Processing**: @future for non-critical operations
6. **Field-Level Security**: Respect user permissions
7. **Error Handling**: Try-catch with logging at all layers

---

## Documentation Map

### Getting Started
- **This Document**: High-level system overview
- `ARCHITECTURE_DOCUMENTATION.md`: Detailed architecture (3,125 lines)
- `docs/LWC_NAMING_CONVENTION.md`: Naming standards

### Architecture Deep Dives
- `documentation/Case_Trigger_Architecture.md`: Complete trigger architecture (1,128 lines)
- `docs/GOVERNOR_ARCHITECTURE.md`: Governor pattern details
- `REFRESH_PATTERN.md`: Data refresh mechanism

### SLA and Entitlement
- `documentation/Entitlement_and_SLA_Service_Layer.md`: SLA service layer
- `documentation/SLA_Entitlement_Technical_Specification.md`: Technical specs
- `documentation/SLA_Entitlement_Data_Flow_Diagram.md`: Visual diagrams
- `documentation/SLA_Entitlement_Quick_Reference.md`: Quick reference
- `documentation/Entitlement_and_SLA_Service_Layer_Guide.md`: Developer guide

### Development Guides
- `docs/COMPONENT_REFACTORING_GUIDE.md`: Step-by-step refactoring
- `docs/CONVERSION_SUMMARY.md`: Migration summary
- `docs/NEW_LWC_COMPONENTS.md`: New component inventory
- `REFACTORING_PLAN.md`: Quote procurement refactoring

### Progress Reports
- `PHASE1_COMPLETION_SUMMARY.md`: Phase 1 results
- `PHASE2_PROGRESS.md`: Phase 2 status
- `PHASE4_COMPLETION_SUMMARY.md`: Phase 4 results
- `PHASE5_COMPLETION_SUMMARY.md`: Phase 5 results
- `AURA_COMPONENTS_REFACTORING_REVIEW.md`: Component migration review

### Specialized Topics
- `UNIFIED_CASE_MANAGEMENT_PROPOSAL.md`: Future enhancements
- `COMPONENT_REFRESH_ISSUE_FIX.md`: Refresh issue resolution
- `CLAUDE_CHANGES_INVENTORY.md`: Change tracking

---

## Development Guidelines

### For New Developers

1. **Start Here**:
   - Read this document first
   - Review `ARCHITECTURE_DOCUMENTATION.md` for details
   - Study `docs/COMPONENT_REFACTORING_GUIDE.md` for patterns

2. **Understanding the Codebase**:
   - Service layer classes are in `/classes/*Service.cls`
   - Data access is in `/classes/*ContextGetter.cls`
   - LWC components are in `/lwc/`
   - Tests are in `/classes/*Test.cls`

3. **Key Concepts to Master**:
   - Governor Pattern (see `CaseDataGovernorService.cls`)
   - ContextGetter Pattern (see `CaseContextGetter.cls`)
   - Lightning Message Service (see `messageChannels/`)
   - Service layer separation (see `CaseBusinessRuleService.cls`)

### Coding Standards

#### Apex
- **One Class, One Responsibility**: Follow SOLID principles
- **Bulkify Everything**: All methods must handle collections
- **Use ContextGetters**: Never write SOQL in service classes
- **Test Coverage**: Minimum 85% per class, aim for 95%
- **Naming**: `<Domain><Purpose>Service.cls` (e.g., `CaseBusinessRuleService`)

#### Lightning Web Components
- **Use LWC Suffix**: All components end with `LWC` during migration
- **Subscribe to Governor**: Use `caseDataGovernorLWC` for data
- **Event Bubbling**: Use custom events for parent communication
- **Error Handling**: Always use try-catch with user feedback
- **Naming**: kebab-case for HTML, camelCase for JS

#### Testing
- **Use TestDataFactory**: `TestDataFactoryRefactored.createX()`
- **Test Bulk Operations**: Test with 200 records
- **Mock External Calls**: Use `Test.setMock()`
- **Assert Everything**: Verify all outcomes
- **Negative Testing**: Test error conditions

### Adding New Features

#### 1. New Service Method
```apex
// 1. Add to appropriate service class
public class CaseBusinessRuleService {
    public static BusinessRuleResult validateNewRule(Case c) {
        // Implementation
    }
}

// 2. Add test class
@isTest
public class CaseBusinessRuleServiceTest {
    @isTest
    static void testValidateNewRule() {
        // Test implementation
    }
}

// 3. Add controller method if needed
public class CaseController {
    @AuraEnabled
    public static BusinessRuleResult validateRule(Id caseId) {
        Case c = CaseContextGetter.getCaseById(caseId);
        return CaseBusinessRuleService.validateNewRule(c);
    }
}
```

#### 2. New LWC Component
```
1. Create component in /lwc/myNewComponentLWC/
2. Subscribe to caseDataGovernorLWC via LMS
3. Add to Case Record Page layout
4. Add Apex controller if needed
5. Add Jest tests
6. Update documentation
```

#### 3. New Integration
```
1. Create dedicated service class (e.g., CaseXYZIntegrationService)
2. Add to Custom Metadata: Integration_Request_URLs__mdt
3. Implement HTTP callout methods
4. Add Test.setMock() for testing
5. Add error handling and logging
6. Document in /documentation/
```

### Git Workflow

1. **Branch Naming**: `claude/<feature-description>-<session-id>`
2. **Commit Messages**: Clear, descriptive (e.g., "Add SLA calculation for rolloff cases")
3. **Pull Requests**: Reference documentation in PR description
4. **Code Review**: Required for all changes

### Deployment Checklist

- [ ] All tests pass (>85% coverage)
- [ ] No hard-coded IDs or credentials
- [ ] Field-level security respected
- [ ] Governor limits checked
- [ ] Error handling implemented
- [ ] Logging added for key operations
- [ ] Documentation updated
- [ ] package.xml updated

---

## Future Enhancements

### Planned Improvements

1. **Complete Aura Migration**: Migrate remaining 204 Aura components to LWC
2. **Platform Cache**: Implement Platform Cache for ContextGetters
3. **Async Processing**: Move heavy calculations to Queueable/Batch
4. **Lightning Flow Integration**: Expose services to Flow Builder
5. **Mobile Optimization**: Optimize components for mobile
6. **Real-time Notifications**: Implement Platform Events
7. **Advanced Analytics**: Lightning Dashboard integration
8. **AI-Powered Routing**: Implement Einstein Case Routing

### Technical Debt

1. **Legacy Trigger Helper**: Remove `CaseTriggerHelper.cls` (adapter pattern)
2. **Custom Settings Migration**: Move to Custom Metadata Types
3. **SOQL Optimization**: Further reduce queries with Platform Cache
4. **Test Data Cleanup**: Consolidate test data creation patterns

---

## Appendix

### Key File Locations

#### Critical Apex Classes
- `/home/user/Ideal-SOLID/classes/CaseBusinessRuleService.cls` (1,808 lines)
- `/home/user/Ideal-SOLID/classes/CaseAttributeService.cls` (900 lines)
- `/home/user/Ideal-SOLID/classes/CaseContextGetter.cls` (914 lines)
- `/home/user/Ideal-SOLID/classes/CaseUIService.cls` (831 lines)
- `/home/user/Ideal-SOLID/classes/CaseDataGovernorService.cls` (318 lines)

#### Critical LWC Components
- `/home/user/Ideal-SOLID/lwc/caseDataGovernorLWC/`
- `/home/user/Ideal-SOLID/lwc/customCaseHighlightPanelLWC/`
- `/home/user/Ideal-SOLID/lwc/showCaseMessagesLWC/`

#### Documentation
- `/home/user/Ideal-SOLID/SYSTEM_ARCHITECTURE_OVERVIEW.md` (this file)
- `/home/user/Ideal-SOLID/ARCHITECTURE_DOCUMENTATION.md` (3,125 lines)
- `/home/user/Ideal-SOLID/documentation/Case_Trigger_Architecture.md` (1,128 lines)

### Glossary

- **Apex**: Salesforce's proprietary Java-like programming language
- **Aura**: Legacy UI framework for Salesforce (being replaced by LWC)
- **Case**: Salesforce standard object representing a customer support case
- **ContextGetter**: Data access pattern for centralized queries and caching
- **CPQ**: Configure, Price, Quote - Salesforce product configuration system
- **DML**: Data Manipulation Language (insert, update, delete operations)
- **Governor Pattern**: Performance optimization pattern reducing server calls
- **LDS**: Lightning Data Service - client-side data caching
- **LMS**: Lightning Message Service - pub/sub messaging
- **LWC**: Lightning Web Components - modern UI framework
- **SOQL**: Salesforce Object Query Language
- **SOSL**: Salesforce Object Search Language
- **SLA**: Service Level Agreement

### Contact and Support

For questions or clarifications about this architecture:
- Review detailed documentation in `/documentation/` and `/docs/`
- Check inline code comments in service classes
- Review test classes for usage examples
- Consult ARCHITECTURE_DOCUMENTATION.md for implementation details

---

**Document Version**: 1.0
**Last Updated**: 2025-11-22
**Maintained By**: Development Team
**Review Cycle**: Quarterly
