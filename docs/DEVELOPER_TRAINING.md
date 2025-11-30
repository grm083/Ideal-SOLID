# Developer Training Guide
## Ideal-SOLID: Enterprise Case Management System

**Version:** 1.0
**Last Updated:** November 30, 2025
**Target Audience:** New developers joining the Ideal-SOLID project

---

## Table of Contents

1. [Welcome & Overview](#welcome--overview)
2. [Development Environment Setup](#development-environment-setup)
3. [Architecture Deep Dive](#architecture-deep-dive)
4. [Hands-On: Your First Feature](#hands-on-your-first-feature)
5. [Service Layer Development](#service-layer-development)
6. [LWC Component Development](#lwc-component-development)
7. [Testing Best Practices](#testing-best-practices)
8. [Common Patterns & Anti-Patterns](#common-patterns--anti-patterns)
9. [Debugging & Troubleshooting](#debugging--troubleshooting)
10. [Code Review Guidelines](#code-review-guidelines)
11. [Resources & References](#resources--references)

---

## Welcome & Overview

### About Ideal-SOLID

Welcome to the Ideal-SOLID development team! This project is an enterprise-grade Salesforce Lightning application implementing a sophisticated Case Management System for Waste Management Services. Our codebase demonstrates best-in-class architecture following SOLID principles and modern Lightning Web Component patterns.

### What You'll Learn

By the end of this training, you will:
- Understand the 4-tier service layer architecture
- Know how to implement features following SOLID principles
- Be able to create and test Lightning Web Components
- Understand the ContextGetter and Governor patterns
- Write comprehensive unit tests achieving 85%+ coverage
- Follow team coding standards and best practices

### Team Culture

- **Quality over Speed**: We prioritize maintainable, well-tested code
- **Documentation**: All code must be self-documenting with clear JavaDoc
- **Code Reviews**: All changes require peer review
- **Testing**: No code is complete without comprehensive tests
- **Continuous Learning**: We share knowledge and improve together

---

## Development Environment Setup

### Prerequisites

1. **Salesforce CLI (sf)**
   ```bash
   npm install -g @salesforce/cli
   sf --version
   ```

2. **Visual Studio Code**
   - Install from: https://code.visualstudio.com/
   - Required Extensions:
     - Salesforce Extension Pack
     - ESLint
     - Prettier

3. **Git**
   ```bash
   git --version
   # Should be 2.0+
   ```

### Environment Setup Steps

#### Step 1: Clone the Repository

```bash
git clone https://github.com/your-org/Ideal-SOLID.git
cd Ideal-SOLID
```

#### Step 2: Authorize Your Dev Sandbox

```bash
# Authorize to your developer sandbox
sf org login web --alias my-dev-sandbox

# Set as default org
sf config set target-org=my-dev-sandbox
```

#### Step 3: Pull Source from Org

```bash
# Retrieve latest source
sf project retrieve start --manifest manifest/package.xml
```

#### Step 4: Install Dependencies

```bash
# If there are npm dependencies for LWC development
npm install
```

#### Step 5: Verify Setup

```bash
# Run all tests to verify environment
sf apex run test --test-level RunLocalTests --result-format human

# Should see 85%+ coverage
```

### IDE Configuration

#### VS Code Settings (`.vscode/settings.json`)

```json
{
  "salesforcedx-vscode-core.push-or-deploy-on-save.enabled": true,
  "salesforcedx-vscode-apex.enable-semantic-errors": true,
  "editor.formatOnSave": true,
  "apex.enable-sobject-refresh-on-startup": true,
  "eslint.enable": true,
  "prettier.enable": true
}
```

---

## Architecture Deep Dive

### The 4-Tier Service Layer

Our architecture separates concerns into four distinct tiers. Understanding this is critical to contributing effectively.

```
┌─────────────────────────────────────────┐
│  Tier 1: Data Access (ContextGetter)   │  ← SOQL Only
├─────────────────────────────────────────┤
│  Tier 2: Business Logic                │  ← Business Rules Only
├─────────────────────────────────────────┤
│  Tier 3: UI Orchestration              │  ← Coordination Only
├─────────────────────────────────────────┤
│  Tier 4: Data Persistence (DML)        │  ← DML Only
└─────────────────────────────────────────┘
```

### Tier 1: ContextGetter Pattern

**Purpose**: Single source of truth for all data queries

**Key Principle**: If you need data, get it from a ContextGetter

**Example**:
```apex
// ✅ CORRECT: Use ContextGetter
Case caseRecord = CaseContextGetter.getCaseById(caseId);

// ❌ WRONG: Direct SOQL in other layers
Case caseRecord = [SELECT Id FROM Case WHERE Id = :caseId];
```

**Creating a New ContextGetter**:

```apex
/**
 * @description OpportunityContextGetter - Data Access Layer for Opportunity Records
 *
 * Single source of truth for all Opportunity-related queries.
 * Implements caching and bulkification patterns.
 *
 * @group Service Layer - Tier 1
 */
public class OpportunityContextGetter {

    // Define standard field set
    private static final String OPPORTUNITY_STANDARD_FIELDS =
        'Id, Name, StageName, Amount, CloseDate, AccountId, OwnerId';

    // Cache for frequently accessed records
    private static Map<Id, Opportunity> opportunityCache = new Map<Id, Opportunity>();

    /**
     * @description Retrieves a single Opportunity by Id with caching
     * @param opportunityId The Opportunity Id
     * @return Opportunity record or null if not found
     */
    public static Opportunity getOpportunityById(Id opportunityId) {
        // Check cache first
        if (opportunityCache.containsKey(opportunityId)) {
            return opportunityCache.get(opportunityId);
        }

        // Query if not cached
        String query = 'SELECT ' + OPPORTUNITY_STANDARD_FIELDS +
                      ' FROM Opportunity WHERE Id = :opportunityId';

        try {
            Opportunity opp = Database.query(query);
            opportunityCache.put(opportunityId, opp);
            return opp;
        } catch (QueryException e) {
            return null;
        }
    }

    /**
     * @description Retrieves Opportunities by Account Id (bulkified)
     * @param accountId The Account Id
     * @return List of Opportunities
     */
    public static List<Opportunity> getOpportunitiesByAccountId(Id accountId) {
        String query = 'SELECT ' + OPPORTUNITY_STANDARD_FIELDS +
                      ' FROM Opportunity WHERE AccountId = :accountId';
        return Database.query(query);
    }

    /**
     * @description Clears the cache (useful in test context)
     */
    @TestVisible
    private static void clearCache() {
        opportunityCache.clear();
    }
}
```

### Tier 2: Business Logic Services

**Purpose**: Implement all business rules, validations, and calculations

**Key Principle**: Business logic lives here and ONLY here

**Example**:
```apex
/**
 * @description OpportunityBusinessRuleService - Business Logic Layer
 *
 * Implements all business rules for Opportunity records.
 * No data access (delegates to ContextGetters).
 * No DML operations (delegates to DMLService).
 *
 * @group Service Layer - Tier 2
 */
public class OpportunityBusinessRuleService {

    /**
     * @description Evaluates if opportunity requires approval
     * @param opp The Opportunity record
     * @return Boolean true if approval required
     */
    public static Boolean requiresApproval(Opportunity opp) {
        // Business Rule: Opportunities over $100k require approval
        if (opp.Amount > 100000) {
            return true;
        }

        // Business Rule: All deals with high-risk accounts require approval
        if (opp.Account.Risk_Rating__c == 'High') {
            return true;
        }

        return false;
    }

    /**
     * @description Calculates probability based on stage and historical data
     * @param opp The Opportunity record
     * @return Decimal probability percentage
     */
    public static Decimal calculateProbability(Opportunity opp) {
        // Business logic for probability calculation
        Map<String, Decimal> stageProbability = new Map<String, Decimal>{
            'Prospecting' => 10,
            'Qualification' => 20,
            'Needs Analysis' => 40,
            'Value Proposition' => 60,
            'Negotiation' => 80,
            'Closed Won' => 100
        };

        return stageProbability.get(opp.StageName);
    }

    /**
     * @description Validates opportunity data before save
     * @param opp The Opportunity record
     * @return ValidationResult with any errors
     */
    public static ValidationResult validateOpportunity(Opportunity opp) {
        ValidationResult result = new ValidationResult();
        result.isValid = true;
        result.errors = new List<String>();

        // Validation: Amount must be positive
        if (opp.Amount <= 0) {
            result.isValid = false;
            result.errors.add('Amount must be greater than zero');
        }

        // Validation: Close date must be in future for non-closed deals
        if (opp.StageName != 'Closed Won' && opp.CloseDate < Date.today()) {
            result.isValid = false;
            result.errors.add('Close Date must be in the future');
        }

        return result;
    }

    public class ValidationResult {
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public List<String> errors;
    }
}
```

### Tier 3: UI Orchestration Services

**Purpose**: Coordinate multiple services to prepare data for UI consumption

**Key Principle**: Orchestrate, don't implement

**Example**:
```apex
/**
 * @description OpportunityUIService - UI Orchestration Layer
 *
 * Orchestrates ContextGetters and BusinessRuleServices to prepare
 * data for UI consumption. Returns wrapper classes optimized for LWC.
 *
 * @group Service Layer - Tier 3
 */
public class OpportunityUIService {

    @AuraEnabled
    public static OpportunityUIWrapper getOpportunityUIData(Id opportunityId) {
        OpportunityUIWrapper result = new OpportunityUIWrapper();

        try {
            // Delegate to ContextGetters for data
            result.opportunity = OpportunityContextGetter.getOpportunityById(opportunityId);
            result.account = AccountContextGetter.getAccountById(result.opportunity.AccountId);
            result.relatedContacts = ContactContextGetter.getContactsByAccountId(result.account.Id);

            // Delegate to BusinessRuleService for logic
            result.requiresApproval = OpportunityBusinessRuleService.requiresApproval(result.opportunity);
            result.calculatedProbability = OpportunityBusinessRuleService.calculateProbability(result.opportunity);

            // UI-specific transformations
            result.formattedAmount = formatCurrency(result.opportunity.Amount);
            result.stageProgressPercentage = getStageProgress(result.opportunity.StageName);

            result.isSuccess = true;
        } catch (Exception e) {
            result.isSuccess = false;
            result.errorMessage = e.getMessage();
        }

        return result;
    }

    /**
     * @description Wrapper class for UI consumption
     */
    public class OpportunityUIWrapper {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Opportunity opportunity;
        @AuraEnabled public Account account;
        @AuraEnabled public List<Contact> relatedContacts;
        @AuraEnabled public Boolean requiresApproval;
        @AuraEnabled public Decimal calculatedProbability;
        @AuraEnabled public String formattedAmount;
        @AuraEnabled public Integer stageProgressPercentage;
    }

    private static String formatCurrency(Decimal amount) {
        return '$' + String.valueOf(amount.setScale(2));
    }

    private static Integer getStageProgress(String stage) {
        // Map stage to progress percentage
        Map<String, Integer> progressMap = new Map<String, Integer>{
            'Prospecting' => 10,
            'Qualification' => 25,
            'Needs Analysis' => 50,
            'Value Proposition' => 70,
            'Negotiation' => 90,
            'Closed Won' => 100
        };
        return progressMap.get(stage);
    }
}
```

### Tier 4: DML Services

**Purpose**: Centralized data persistence with consistent error handling

**Key Principle**: All DML operations go through DMLService

**Example**:
```apex
/**
 * @description OpportunityDMLService - Data Persistence Layer
 *
 * Singleton service for all Opportunity DML operations.
 * Provides consistent error handling and transaction management.
 *
 * @group Service Layer - Tier 4
 */
public class OpportunityDMLService {
    private static OpportunityDMLService instance;

    @TestVisible
    private static OpportunityDMLService testInstance;

    private OpportunityDMLService() {
        // Private constructor for singleton
    }

    public static OpportunityDMLService getInstance() {
        if (Test.isRunningTest() && testInstance != null) {
            return testInstance;
        }

        if (instance == null) {
            instance = new OpportunityDMLService();
        }
        return instance;
    }

    /**
     * @description Updates an opportunity with error handling
     * @param oppToUpdate The Opportunity to update
     * @return DMLResult with success/error information
     */
    public DMLResult updateOpportunity(Opportunity oppToUpdate) {
        DMLResult result = new DMLResult();

        try {
            Database.SaveResult saveResult = Database.update(oppToUpdate, false);

            if (saveResult.isSuccess()) {
                result.isSuccess = true;
                result.recordId = saveResult.getId();
            } else {
                result.isSuccess = false;
                result.errors = extractErrors(saveResult.getErrors());
            }
        } catch (DmlException e) {
            result.isSuccess = false;
            result.errors = new List<String>{ e.getMessage() };
        }

        return result;
    }

    private List<String> extractErrors(Database.Error[] errors) {
        List<String> errorMessages = new List<String>();
        for (Database.Error error : errors) {
            errorMessages.add(error.getMessage());
        }
        return errorMessages;
    }

    public class DMLResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public Id recordId;
        @AuraEnabled public List<String> errors;
    }
}
```

---

## Hands-On: Your First Feature

Let's implement a complete feature from scratch to practice the architecture.

### Feature Requirement

**User Story**: As a sales manager, I want to see a warning when an opportunity is at risk based on its age and stage.

### Step 1: Create the ContextGetter Method

If you need new data that doesn't exist in a ContextGetter, add it:

```apex
// In OpportunityContextGetter.cls
public static Opportunity getOpportunityWithAge(Id opportunityId) {
    String query = 'SELECT ' + OPPORTUNITY_STANDARD_FIELDS +
                  ', CreatedDate, LastActivityDate ' +
                  'FROM Opportunity WHERE Id = :opportunityId';
    return Database.query(query);
}
```

### Step 2: Implement Business Logic

```apex
// In OpportunityBusinessRuleService.cls
/**
 * @description Evaluates if opportunity is at risk
 * @param opp The Opportunity record
 * @return RiskAssessment with risk level and reasons
 */
public static RiskAssessment evaluateRisk(Opportunity opp) {
    RiskAssessment result = new RiskAssessment();
    result.isAtRisk = false;
    result.riskFactors = new List<String>();

    // Calculate days since creation
    Integer daysSinceCreation = Date.today().daysBetween(opp.CreatedDate.date());

    // Calculate days since last activity
    Integer daysSinceActivity = opp.LastActivityDate != null ?
        Date.today().daysBetween(opp.LastActivityDate) : daysSinceCreation;

    // Business Rule: Stale opportunities are at risk
    if (daysSinceActivity > 30) {
        result.isAtRisk = true;
        result.riskFactors.add('No activity in ' + daysSinceActivity + ' days');
    }

    // Business Rule: Old opportunities in early stages are at risk
    if (daysSinceCreation > 90 &&
        (opp.StageName == 'Prospecting' || opp.StageName == 'Qualification')) {
        result.isAtRisk = true;
        result.riskFactors.add('Opportunity is ' + daysSinceCreation + ' days old but still in early stage');
    }

    // Business Rule: No activity before close date
    if (opp.CloseDate != null) {
        Integer daysUntilClose = Date.today().daysBetween(opp.CloseDate);
        if (daysUntilClose < 7 && daysSinceActivity > 7) {
            result.isAtRisk = true;
            result.riskFactors.add('Closing in ' + daysUntilClose + ' days with no recent activity');
        }
    }

    return result;
}

public class RiskAssessment {
    @AuraEnabled public Boolean isAtRisk;
    @AuraEnabled public List<String> riskFactors;
}
```

### Step 3: Update UI Service

```apex
// In OpportunityUIService.cls - add to OpportunityUIWrapper
@AuraEnabled
public static OpportunityUIWrapper getOpportunityUIData(Id opportunityId) {
    OpportunityUIWrapper result = new OpportunityUIWrapper();

    // ... existing code ...

    // Add risk assessment
    result.riskAssessment = OpportunityBusinessRuleService.evaluateRisk(result.opportunity);

    return result;
}

// Add to wrapper class
public class OpportunityUIWrapper {
    // ... existing properties ...
    @AuraEnabled public RiskAssessment riskAssessment;
}
```

### Step 4: Create LWC Component

```javascript
// opportunityRiskWarning.js
import { LightningElement, api } from 'lwc';

export default class OpportunityRiskWarning extends LightningElement {
    @api riskAssessment;

    get showWarning() {
        return this.riskAssessment && this.riskAssessment.isAtRisk;
    }

    get riskMessage() {
        if (!this.showWarning) return '';

        return 'This opportunity is at risk: ' +
               this.riskAssessment.riskFactors.join(', ');
    }
}
```

```html
<!-- opportunityRiskWarning.html -->
<template>
    <template if:true={showWarning}>
        <lightning-card title="Risk Warning" icon-name="utility:warning">
            <div class="slds-p-around_medium">
                <lightning-icon
                    icon-name="utility:warning"
                    alternative-text="Warning"
                    size="small"
                    class="slds-m-right_small">
                </lightning-icon>
                <span class="risk-message">{riskMessage}</span>
            </div>
        </lightning-card>
    </template>
</template>
```

### Step 5: Write Tests

```apex
// OpportunityBusinessRuleServiceTest.cls
@isTest
private class OpportunityBusinessRuleServiceTest {

    @isTest
    static void testRiskEvaluation_StaleOpportunity() {
        // Create test data
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            Amount = 50000,
            LastActivityDate = Date.today().addDays(-31)  // 31 days ago
        );
        insert opp;

        // Execute
        OpportunityBusinessRuleService.RiskAssessment result =
            OpportunityBusinessRuleService.evaluateRisk(opp);

        // Verify
        System.assertEquals(true, result.isAtRisk, 'Stale opportunity should be at risk');
        System.assertEquals(false, result.riskFactors.isEmpty(), 'Should have risk factors');
        System.assert(
            result.riskFactors[0].contains('No activity'),
            'Should mention lack of activity'
        );
    }

    @isTest
    static void testRiskEvaluation_HealthyOpportunity() {
        // Create test data
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Negotiation',
            CloseDate = Date.today().addDays(15),
            Amount = 50000,
            LastActivityDate = Date.today().addDays(-5)  // 5 days ago
        );
        insert opp;

        // Execute
        OpportunityBusinessRuleService.RiskAssessment result =
            OpportunityBusinessRuleService.evaluateRisk(opp);

        // Verify
        System.assertEquals(false, result.isAtRisk, 'Healthy opportunity should not be at risk');
    }
}
```

---

## Service Layer Development

### Decision Tree: Which Service to Use?

```
Do you need to query data?
│
├─ YES → Use existing ContextGetter method
│        OR create new method in appropriate ContextGetter
│
├─ NO → Do you need to perform DML?
        │
        ├─ YES → Use DMLService.getInstance()
        │
        └─ NO → Do you need to evaluate business rules?
                │
                ├─ YES → Add to BusinessRuleService
                │
                └─ NO → Are you preparing data for UI?
                        │
                        ├─ YES → Add to UIService
                        │
                        └─ NO → Re-evaluate your approach!
```

### Common Service Patterns

#### Pattern 1: Field Requirement Evaluation

```apex
// In BusinessRuleService
public static Map<String, Boolean> evaluateFieldRequirements(SObject record) {
    Map<String, Boolean> requirements = new Map<String, Boolean>();

    // Metadata-driven approach
    List<Field_Requirement__mdt> rules = [
        SELECT Field_API_Name__c, Condition__c
        FROM Field_Requirement__mdt
        WHERE Object_API_Name__c = :String.valueOf(record.getSObjectType())
    ];

    for (Field_Requirement__mdt rule : rules) {
        Boolean isRequired = evaluateCondition(rule.Condition__c, record);
        requirements.put(rule.Field_API_Name__c, isRequired);
    }

    return requirements;
}
```

#### Pattern 2: Approval Workflow

```apex
// In BusinessRuleService
public static ApprovalDecision determineApprovalNeeds(Case caseRecord) {
    ApprovalDecision decision = new ApprovalDecision();
    decision.requiresApproval = false;
    decision.approvers = new List<Id>();
    decision.reasons = new List<String>();

    // Rule 1: High-value cases require manager approval
    if (caseRecord.Estimated_Value__c > 50000) {
        decision.requiresApproval = true;
        decision.approvers.add(caseRecord.Owner.ManagerId);
        decision.reasons.add('High value case requires manager approval');
    }

    // Rule 2: Emergency cases require director approval
    if (caseRecord.Priority == 'Emergency') {
        decision.requiresApproval = true;
        decision.approvers.add(getDirectorId());
        decision.reasons.add('Emergency priority requires director approval');
    }

    return decision;
}
```

---

## LWC Component Development

### Component Architecture

Our LWC components follow a hub-and-spoke pattern with the Governor pattern:

```
caseDataGovernorLWC (Hub)
├── Loads all data once
├── Publishes via LMS
└── Handles refresh events
    │
    ├─→ Component A (Spoke) - Subscribes to relevant data
    ├─→ Component B (Spoke) - Subscribes to relevant data
    └─→ Component C (Spoke) - Subscribes to relevant data
```

### Creating a New LWC Component

#### Step 1: Generate Component

```bash
sf lightning generate component --type lwc --component-name myNewComponent --output-dir force-app/main/default/lwc
```

#### Step 2: Component Structure

```javascript
// myNewComponent.js
import { LightningElement, api, wire } from 'lwc';
import { subscribe, MessageContext } from 'lightning/messageService';
import CASE_DATA_CHANNEL from '@salesforce/messageChannel/CaseDataChannel__c';

export default class MyNewComponent extends LightningElement {
    // Public API - what parent components can set
    @api recordId;

    // Private properties
    caseData;
    subscription = null;

    // Wire message context for LMS
    @wire(MessageContext)
    messageContext;

    // Lifecycle hooks
    connectedCallback() {
        this.subscribeToMessageChannel();
    }

    disconnectedCallback() {
        this.unsubscribeFromMessageChannel();
    }

    // Subscribe to LMS
    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                CASE_DATA_CHANNEL,
                (message) => this.handleCaseDataUpdate(message)
            );
        }
    }

    unsubscribeFromMessageChannel() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    // Handle LMS message
    handleCaseDataUpdate(message) {
        this.caseData = message.caseData;
        this.processData();
    }

    // Getters for template
    get displayValue() {
        return this.caseData ? this.caseData.caseNumber : '';
    }

    // Event handlers
    handleButtonClick() {
        // Dispatch custom event to parent
        this.dispatchEvent(new CustomEvent('buttonclick', {
            detail: { action: 'someAction' }
        }));
    }

    // Private helper methods
    processData() {
        // Process the data
    }
}
```

```html
<!-- myNewComponent.html -->
<template>
    <lightning-card title="My Component" icon-name="standard:case">
        <div class="slds-p-around_medium">
            <template if:true={caseData}>
                <p>Case Number: {displayValue}</p>

                <lightning-button
                    label="Click Me"
                    onclick={handleButtonClick}
                    variant="brand">
                </lightning-button>
            </template>

            <template if:false={caseData}>
                <lightning-spinner
                    alternative-text="Loading..."
                    size="small">
                </lightning-spinner>
            </template>
        </div>
    </lightning-card>
</template>
```

### LWC Best Practices

#### 1. Use Getters for Computed Values

```javascript
// ✅ GOOD: Reactive getter
get statusVariant() {
    if (this.status === 'Open') return 'success';
    if (this.status === 'Closed') return 'default';
    return 'warning';
}

// ❌ BAD: Computing in template
// <div class={status === 'Open' ? 'success' : 'default'}></div>
```

#### 2. Keep Components Focused

```javascript
// ✅ GOOD: Single responsibility
export default class CaseStatus extends LightningElement {
    @api status;
    // Only handles displaying status
}

// ❌ BAD: Too many responsibilities
export default class CaseEverything extends LightningElement {
    // Handles status, tasks, comments, attachments, etc.
}
```

#### 3. Use Custom Events for Parent Communication

```javascript
// Child component
handleSave() {
    const event = new CustomEvent('save', {
        detail: { recordId: this.recordId, data: this.formData }
    });
    this.dispatchEvent(event);
}

// Parent component HTML
<c-child-component onsave={handleChildSave}></c-child-component>

// Parent component JS
handleChildSave(event) {
    const { recordId, data } = event.detail;
    // Handle save
}
```

---

## Testing Best Practices

### Test Coverage Requirements

- **Minimum Coverage**: 85% for all classes
- **Test All Paths**: Every if/else, every exception handler
- **Use Assertions**: Every test must verify expected behavior

### Test Structure

```apex
@isTest
private class MyServiceTest {

    // Test data setup
    @TestSetup
    static void setupTestData() {
        // Create common test data used by multiple tests
        Account testAccount = TestDataFactoryRefactored.createAccount();
        Case testCase = TestDataFactoryRefactored.createTestCase(testAccount.Id);
    }

    // Test happy path
    @isTest
    static void testSuccessfulOperation() {
        // Given - Set up test context
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // When - Execute the method being tested
        Test.startTest();
        MyService.Result result = MyService.doSomething(testCase.Id);
        Test.stopTest();

        // Then - Verify expected behavior
        System.assertEquals(true, result.isSuccess, 'Operation should succeed');
        System.assertNotEquals(null, result.data, 'Should return data');
    }

    // Test error handling
    @isTest
    static void testErrorHandling() {
        // Given
        Id invalidId = null;

        // When
        Test.startTest();
        MyService.Result result = MyService.doSomething(invalidId);
        Test.stopTest();

        // Then
        System.assertEquals(false, result.isSuccess, 'Should fail with invalid input');
        System.assertNotEquals(null, result.errorMessage, 'Should have error message');
    }

    // Test bulk operations
    @isTest
    static void testBulkOperation() {
        // Given
        List<Case> cases = [SELECT Id FROM Case];

        // When
        Test.startTest();
        List<MyService.Result> results = MyService.processBulk(cases);
        Test.stopTest();

        // Then
        System.assertEquals(cases.size(), results.size(), 'Should process all records');
    }
}
```

### Using Test Data Factory

```apex
// Always use TestDataFactoryRefactored
Account testAccount = TestDataFactoryRefactored.createAccount();
Case testCase = TestDataFactoryRefactored.createTestCase(testAccount.Id);
Asset testAsset = TestDataFactoryRefactored.createTestAsset(testAccount.Id);

// With custom parameters
Case customCase = TestDataFactoryRefactored.createTestCase(
    testAccount.Id,
    'High',          // Priority
    'Emergency',     // Status
    'New Service'    // Service Type
);
```

### Testing with Mocks

```apex
@isTest
static void testWithMock() {
    // Create mock DML service
    MockDMLService mockDML = new MockDMLService();
    mockDML.shouldSucceed = false;  // Simulate failure

    // Inject mock
    CaseDMLService.testInstance = mockDML;

    // Test
    Test.startTest();
    MyService.Result result = MyService.updateCase(testCaseId);
    Test.stopTest();

    // Verify mock was called and error was handled
    System.assertEquals(true, mockDML.wasCalled);
    System.assertEquals(false, result.isSuccess);
}

// Mock class
private class MockDMLService extends CaseDMLService {
    public Boolean wasCalled = false;
    public Boolean shouldSucceed = true;

    public override DMLResult updateCase(Case caseToUpdate) {
        wasCalled = true;
        DMLResult result = new DMLResult();
        result.isSuccess = shouldSucceed;
        if (!shouldSucceed) {
            result.errors = new List<String>{ 'Mock error' };
        }
        return result;
    }
}
```

---

## Common Patterns & Anti-Patterns

### ✅ Patterns to Follow

#### 1. Separation of Concerns

```apex
// ✅ GOOD: Each class has one job
public class CaseContextGetter {
    public static Case getCaseById(Id caseId) {
        return [SELECT Id FROM Case WHERE Id = :caseId];
    }
}

public class CaseBusinessRuleService {
    public static Boolean requiresApproval(Case c) {
        return c.Amount__c > 10000;
    }
}

// ❌ BAD: Mixed responsibilities
public class CaseHelper {
    public static Case getCaseAndCheckApproval(Id caseId) {
        Case c = [SELECT Id FROM Case WHERE Id = :caseId];  // Data access
        if (c.Amount__c > 10000) {  // Business logic
            c.Requires_Approval__c = true;
            update c;  // DML
        }
        return c;
    }
}
```

#### 2. Defensive Programming

```apex
// ✅ GOOD: Null checks and validation
public static Case getCaseById(Id caseId) {
    if (caseId == null) {
        throw new IllegalArgumentException('caseId cannot be null');
    }

    List<Case> cases = [SELECT Id FROM Case WHERE Id = :caseId LIMIT 1];

    if (cases.isEmpty()) {
        return null;  // Or throwNotFoundException
    }

    return cases[0];
}

// ❌ BAD: No validation
public static Case getCaseById(Id caseId) {
    return [SELECT Id FROM Case WHERE Id = :caseId];  // Can throw QueryException
}
```

#### 3. Bulkification

```apex
// ✅ GOOD: Bulkified
public static Map<Id, Case> getCasesByIds(Set<Id> caseIds) {
    Map<Id, Case> result = new Map<Id, Case>();

    List<Case> cases = [
        SELECT Id, CaseNumber, Status
        FROM Case
        WHERE Id IN :caseIds
    ];

    for (Case c : cases) {
        result.put(c.Id, c);
    }

    return result;
}

// ❌ BAD: Not bulkified (will hit governor limits)
public static List<Case> getCasesByIds(Set<Id> caseIds) {
    List<Case> results = new List<Case>();

    for (Id caseId : caseIds) {
        Case c = [SELECT Id FROM Case WHERE Id = :caseId];  // SOQL in loop!
        results.add(c);
    }

    return results;
}
```

### ❌ Anti-Patterns to Avoid

#### 1. God Classes

```apex
// ❌ BAD: One class does everything
public class CaseManager {
    public static Case getCase(Id caseId) { /* ... */ }
    public static Boolean needsApproval(Case c) { /* ... */ }
    public static void updateCase(Case c) { /* ... */ }
    public static void sendEmail(Case c) { /* ... */ }
    public static void createTask(Case c) { /* ... */ }
    // ... 50 more methods
}
```

#### 2. Hardcoded Values

```apex
// ❌ BAD: Hardcoded
if (caseRecord.RecordTypeId == '0120000000xxxxx') {  // Hardcoded Id
    // ...
}

// ✅ GOOD: Use metadata or dynamic query
Id customerServiceRT = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
    .get('Customer_Service').getRecordTypeId();

if (caseRecord.RecordTypeId == customerServiceRT) {
    // ...
}
```

#### 3. Direct DML in Business Logic

```apex
// ❌ BAD: DML in business logic
public class CaseBusinessRuleService {
    public static void processCase(Case c) {
        if (c.Amount__c > 10000) {
            c.Requires_Approval__c = true;
            update c;  // NO! Business logic should not do DML
        }
    }
}

// ✅ GOOD: Return result, let caller handle DML
public class CaseBusinessRuleService {
    public static ProcessResult processCase(Case c) {
        ProcessResult result = new ProcessResult();
        result.requiresUpdate = false;
        result.modifiedCase = c.clone(true, true, true, true);

        if (c.Amount__c > 10000) {
            result.modifiedCase.Requires_Approval__c = true;
            result.requiresUpdate = true;
        }

        return result;
    }
}

// Caller handles DML
ProcessResult result = CaseBusinessRuleService.processCase(myCase);
if (result.requiresUpdate) {
    CaseDMLService.getInstance().updateCase(result.modifiedCase);
}
```

---

## Debugging & Troubleshooting

### Debug Logs

#### Enable Debug Logs

1. Setup → Debug Logs
2. Click "New" under User Trace Flags
3. Select your user
4. Set Debug Level to "SFDC_DevConsole"
5. Set expiration to tomorrow

#### Reading Debug Logs

```apex
// Add debug statements
System.debug('CaseId: ' + caseId);
System.debug('Processing case with status: ' + caseRecord.Status);
System.debug(LoggingLevel.ERROR, 'Critical error occurred: ' + e.getMessage());
```

Search logs for:
- `SOQL_EXECUTE_BEGIN` - See your queries
- `DML_BEGIN` - See your DML operations
- `EXCEPTION_THROWN` - Find errors
- `USER_DEBUG` - Your debug statements

### Common Issues & Solutions

#### Issue 1: "List has no rows for assignment to SObject"

**Cause**: Query returned no results

**Solution**:
```apex
// ❌ BAD
Case c = [SELECT Id FROM Case WHERE Id = :caseId];

// ✅ GOOD
List<Case> cases = [SELECT Id FROM Case WHERE Id = :caseId LIMIT 1];
if (cases.isEmpty()) {
    throw new NotFoundException('Case not found: ' + caseId);
}
Case c = cases[0];
```

#### Issue 2: "Too many SOQL queries: 101"

**Cause**: SOQL in loops or not using ContextGetter cache

**Solution**:
```apex
// ❌ BAD
for (Id accountId : accountIds) {
    Account a = [SELECT Id FROM Account WHERE Id = :accountId];  // SOQL in loop
}

// ✅ GOOD
Map<Id, Account> accounts = new Map<Id, Account>(
    [SELECT Id FROM Account WHERE Id IN :accountIds]
);
for (Id accountId : accountIds) {
    Account a = accounts.get(accountId);
}
```

#### Issue 3: Component Not Updating

**Cause**: LWC reactivity not triggered

**Solution**:
```javascript
// ❌ BAD: Mutating object doesn't trigger reactivity
this.caseData.Status = 'Closed';

// ✅ GOOD: Create new object to trigger reactivity
this.caseData = { ...this.caseData, Status: 'Closed' };
```

---

## Code Review Guidelines

### What Reviewers Look For

1. **Architecture Compliance**
   - Is data access in ContextGetters?
   - Is business logic in BusinessRuleServices?
   - Is DML in DMLServices?

2. **Test Coverage**
   - Are there tests for new code?
   - Do tests cover error cases?
   - Is coverage 85%+?

3. **Code Quality**
   - Are variable names descriptive?
   - Are methods less than 50 lines?
   - Is code well-commented?

4. **Security**
   - Is user input validated?
   - Are SOQL queries using bind variables?
   - Is sharing respected (`with sharing`)?

5. **Performance**
   - Are queries bulkified?
   - Is there SOQL in loops?
   - Are indexes available for query filters?

### Code Review Checklist

Before submitting PR:

- [ ] All tests pass locally
- [ ] New code has 85%+ test coverage
- [ ] No SOQL/DML in loops
- [ ] All methods have JavaDoc comments
- [ ] Variable names are descriptive
- [ ] No hardcoded IDs or values
- [ ] Code follows SOLID principles
- [ ] LWC components follow naming conventions
- [ ] Debug statements removed
- [ ] Updated relevant documentation

---

## Resources & References

### Internal Documentation

- **ARCHITECTURE_DOCUMENTATION.md** - Detailed architecture guide
- **GOVERNOR_ARCHITECTURE.md** - Governor pattern deep dive
- **COMPONENT_REFACTORING_GUIDE.md** - Aura to LWC migration guide
- **USER_SCENARIOS.md** - User stories and acceptance criteria

### Salesforce Documentation

- [Apex Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/)
- [Lightning Web Components Developer Guide](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
- [Lightning Message Service](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.use_message_channel)
- [SOQL and SOSL Reference](https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/)

### Team Contacts

- **Tech Lead**: [Name] - For architecture questions
- **QA Lead**: [Name] - For testing questions
- **DevOps**: [Name] - For deployment questions

### Training Schedule

- **Week 1**: Environment setup, read architecture docs
- **Week 2**: Complete hands-on tutorial, shadow team member
- **Week 3**: Take first simple ticket with pair programming
- **Week 4**: Independent development with code review

---

## Appendix: Quick Reference

### Service Layer Cheat Sheet

```
Need to...                          Use...
─────────────────────────────────────────────────────────
Query data                       → ContextGetter
Validate/calculate              → BusinessRuleService
Prepare data for UI             → UIService
Save/update/delete data         → DMLService
Orchestrate in controller       → UIService methods
```

### LWC Lifecycle Hooks

```javascript
constructor()           // Component created, no DOM access
connectedCallback()     // Component inserted into DOM
renderedCallback()      // After render (use sparingly)
disconnectedCallback()  // Component removed from DOM
errorCallback()         // Error in component tree
```

### Common Apex Patterns

```apex
// Singleton
public static MyService getInstance() {
    if (instance == null) {
        instance = new MyService();
    }
    return instance;
}

// Wrapper class
public class MyWrapper {
    @AuraEnabled public String field1;
    @AuraEnabled public Integer field2;
}

// Result pattern
public class OperationResult {
    @AuraEnabled public Boolean isSuccess;
    @AuraEnabled public String errorMessage;
    @AuraEnabled public Object data;
}
```

---

**Welcome to the team! Happy coding!**

**Document Maintained By**: Development Team
**Last Updated**: November 30, 2025
**Version**: 1.0
