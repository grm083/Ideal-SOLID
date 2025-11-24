/**
 * @author Waste Management
 * @date 2025
 *
 * @group Cases
 * @group-content ../../ApexDocContent/Cases.htm
 *
 * @description Facade pattern implementation that coordinates all Case trigger services.
 *              This class reduces coupling by providing a single entry point for trigger operations.
 *
 * DESIGN PATTERNS:
 * - Facade Pattern: Simplifies complex subsystem interactions
 * - Dependency Injection: Constructor injection enables testing
 * - Single Responsibility: Orchestration only, no business logic
 *
 * BEFORE (CaseTriggerHandler had 12+ dependencies):
 * CaseTriggerHandler → CaseAttributeService
 *                   → CaseBusinessRuleService
 *                   → CaseAssetValidator
 *                   → SLACalculationUtility
 *                   → [8+ more services]
 *
 * AFTER (CaseTriggerHandler has 1 dependency):
 * CaseTriggerHandler → CaseServiceFacade → [All services]
 *
 * BENEFITS:
 * - Reduced coupling: Handler depends on 1 facade instead of 12+ services
 * - Testability: Can inject mock services via constructor
 * - Maintainability: Service coordination logic in one place
 * - Flexibility: Easy to add/remove service calls
 *
 * USAGE:
 * CaseTriggerContext context = CaseTriggerContext.buildFromCases(cases);
 * CaseServiceFacade facade = new CaseServiceFacade();
 * facade.processBeforeInsert(cases, context);
 */
public class CaseServiceFacade {

    // ========================================================================
    // INSTANCE VARIABLES (Injected dependencies)
    // ========================================================================

    private CaseAttributeService attributeService;
    private CaseBusinessRuleService businessRuleService;
    private CaseAssetValidator assetValidator;

    // ========================================================================
    // CONSTRUCTORS
    // ========================================================================

    /**
     * @description Default constructor - creates real service instances
     * Used in production code
     */
    public CaseServiceFacade() {
        this(
            new CaseAttributeService(),
            new CaseBusinessRuleService(),
            new CaseAssetValidator()
        );
    }

    /**
     * @description Constructor with dependency injection
     * Used for testing - allows mock services to be injected
     *
     * @param attributeService Service for case attribute management
     * @param businessRuleService Service for business rule evaluation
     * @param assetValidator Service for asset validation
     */
    @TestVisible
    private CaseServiceFacade(
        CaseAttributeService attributeService,
        CaseBusinessRuleService businessRuleService,
        CaseAssetValidator assetValidator
    ) {
        this.attributeService = attributeService;
        this.businessRuleService = businessRuleService;
        this.assetValidator = assetValidator;
    }

    // ========================================================================
    // PUBLIC API - BEFORE INSERT
    // ========================================================================

    /**
     * @description Orchestrates all before insert operations
     * Coordinates service calls in the correct order with proper error handling
     *
     * @param casesToProcess List of cases being inserted
     * @param context Context containing all related data
     */
    public void processBeforeInsert(List<Case> casesToProcess, CaseTriggerContext context) {
        if (casesToProcess == null || casesToProcess.isEmpty()) {
            return;
        }

        try {
            UTIL_LoggingService.log(
                'CaseServiceFacade.processBeforeInsert - Processing ' + casesToProcess.size() + ' cases',
                LoggingLevel.DEBUG
            );

            // Phase 1: Initialize and populate case attributes
            // This must happen first as other services depend on populated fields
            List<Case> casesNeedingAttributes = filterCasesNeedingAttributes(casesToProcess, context);
            if (!casesNeedingAttributes.isEmpty()) {
                attributeService.updateCaseDetails(casesNeedingAttributes, context);
                attributeService.populateInitialAttributes(casesNeedingAttributes, context);
            }

            // Phase 2: Calculate SLA dates
            // Must happen after attributes are populated but before business rules
            List<Case> casesNeedingSLA = filterCasesNeedingSLA(casesToProcess, context);
            if (!casesNeedingSLA.isEmpty()) {
                SLACalculationUtility.calculateAndSetSLAFields(
                    casesNeedingSLA,
                    context.getAllLocations()
                );
            }

            // Phase 3: Apply business rules and validation
            // Happens after all fields are populated
            businessRuleService.applyBusinessRulesBeforeInsert(casesToProcess, context);

            // Phase 4: Validate assets
            // Final validation before insert
            List<Case> casesWithAssets = filterCasesWithAssets(casesToProcess);
            if (!casesWithAssets.isEmpty()) {
                assetValidator.validateAssetEligibility(casesWithAssets, context);
            }

        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(
                e,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            throw e; // Re-throw to prevent partial insert
        }
    }

    // ========================================================================
    // PUBLIC API - BEFORE UPDATE
    // ========================================================================

    /**
     * @description Orchestrates all before update operations
     *
     * @param newCases List of cases with new values
     * @param oldCaseMap Map of cases with old values
     * @param context Context containing all related data
     */
    public void processBeforeUpdate(
        List<Case> newCases,
        Map<Id, Case> oldCaseMap,
        CaseTriggerContext context
    ) {
        if (newCases == null || newCases.isEmpty()) {
            return;
        }

        try {
            UTIL_LoggingService.log(
                'CaseServiceFacade.processBeforeUpdate - Processing ' + newCases.size() + ' cases',
                LoggingLevel.DEBUG
            );

            // Phase 1: Update changed attributes
            List<Case> casesWithChanges = filterCasesWithChanges(newCases, oldCaseMap);
            if (!casesWithChanges.isEmpty()) {
                attributeService.updateChangedAttributes(casesWithChanges, oldCaseMap, context);
            }

            // Phase 2: Handle SLA resets and recalculations
            List<Case> casesNeedingSLAReset = filterCasesNeedingSLAReset(newCases, oldCaseMap);
            if (!casesNeedingSLAReset.isEmpty()) {
                assetValidator.handleSLAResets(casesNeedingSLAReset, oldCaseMap, context);
            }

            List<Case> casesNeedingSLARecalc = filterCasesNeedingSLARecalc(newCases, oldCaseMap);
            if (!casesNeedingSLARecalc.isEmpty()) {
                SLACalculationUtility.calculateAndSetSLAFields(
                    casesNeedingSLARecalc,
                    context.getAllLocations()
                );
            }

            // Phase 3: Apply business rules
            businessRuleService.applyBusinessRulesBeforeUpdate(newCases, oldCaseMap, context);

            // Phase 4: Validate asset changes
            List<Case> casesWithAssetChanges = filterCasesWithAssetChanges(newCases, oldCaseMap);
            if (!casesWithAssetChanges.isEmpty()) {
                assetValidator.validateAssetChanges(casesWithAssetChanges, oldCaseMap, context);
            }

        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(
                e,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            throw e; // Re-throw to prevent partial update
        }
    }

    // ========================================================================
    // PUBLIC API - AFTER INSERT
    // ========================================================================

    /**
     * @description Orchestrates all after insert operations
     *
     * @param newCases List of inserted cases
     * @param context Context containing all related data
     */
    public void processAfterInsert(List<Case> newCases, CaseTriggerContext context) {
        if (newCases == null || newCases.isEmpty()) {
            return;
        }

        try {
            UTIL_LoggingService.log(
                'CaseServiceFacade.processAfterInsert - Processing ' + newCases.size() + ' cases',
                LoggingLevel.DEBUG
            );

            // Phase 1: Create related records (assets, logs, etc.)
            List<Case> casesNeedingAssetCreation = filterCasesNeedingAssetCreation(newCases, context);
            if (!casesNeedingAssetCreation.isEmpty()) {
                assetValidator.createCaseAssets(casesNeedingAssetCreation, context);
            }

            // Phase 2: Apply post-insert business rules
            businessRuleService.applyBusinessRulesAfterInsert(newCases, context);

            // Phase 3: Log contact activity and relationships
            List<Case> casesWithContacts = filterCasesWithContacts(newCases);
            if (!casesWithContacts.isEmpty()) {
                attributeService.logContactActivity(casesWithContacts, context);
            }

        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(
                e,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            // Don't re-throw - after insert failures shouldn't block the transaction
        }
    }

    // ========================================================================
    // PUBLIC API - AFTER UPDATE
    // ========================================================================

    /**
     * @description Orchestrates all after update operations
     *
     * @param newCases List of cases with new values
     * @param oldCaseMap Map of cases with old values
     * @param context Context containing all related data
     */
    public void processAfterUpdate(
        List<Case> newCases,
        Map<Id, Case> oldCaseMap,
        CaseTriggerContext context
    ) {
        if (newCases == null || newCases.isEmpty()) {
            return;
        }

        try {
            UTIL_LoggingService.log(
                'CaseServiceFacade.processAfterUpdate - Processing ' + newCases.size() + ' cases',
                LoggingLevel.DEBUG
            );

            // Phase 1: Handle asset updates
            List<Case> casesWithAssetUpdates = filterCasesWithAssetChanges(newCases, oldCaseMap);
            if (!casesWithAssetUpdates.isEmpty()) {
                assetValidator.updateCaseAssets(casesWithAssetUpdates, oldCaseMap, context);
            }

            // Phase 2: Apply post-update business rules
            businessRuleService.applyBusinessRulesAfterUpdate(newCases, oldCaseMap, context);

            // Phase 3: Log chargeability changes
            List<Case> casesWithChargeabilityChanges = filterCasesWithChargeabilityChanges(
                newCases,
                oldCaseMap
            );
            if (!casesWithChargeabilityChanges.isEmpty()) {
                businessRuleService.logChargeabilityChanges(
                    casesWithChargeabilityChanges,
                    oldCaseMap
                );
            }

        } catch (Exception e) {
            UTIL_LoggingService.logHandledException(
                e,
                UserInfo.getOrganizationId(),
                UTIL_ErrorConstants.ERROR_APPLICATION,
                LoggingLevel.ERROR
            );
            // Don't re-throw - after update failures shouldn't block the transaction
        }
    }

    // ========================================================================
    // PRIVATE HELPER METHODS - Case Filtering
    // ========================================================================

    private List<Case> filterCasesNeedingAttributes(
        List<Case> cases,
        CaseTriggerContext context
    ) {
        List<Case> filtered = new List<Case>();
        for (Case c : cases) {
            // Cases need attributes if they have a location or asset
            if (String.isNotBlank(c.Location__c) || String.isNotBlank(c.AssetId)) {
                filtered.add(c);
            }
        }
        return filtered;
    }

    private List<Case> filterCasesNeedingSLA(List<Case> cases, CaseTriggerContext context) {
        List<Case> filtered = new List<Case>();
        for (Case c : cases) {
            // Skip if SLA already set or no service date
            if (c.SLA_Date_Time__c == null && c.Service_Date__c != null) {
                filtered.add(c);
            }
        }
        return filtered;
    }

    private List<Case> filterCasesWithAssets(List<Case> cases) {
        List<Case> filtered = new List<Case>();
        for (Case c : cases) {
            if (String.isNotBlank(c.AssetId)) {
                filtered.add(c);
            }
        }
        return filtered;
    }

    private List<Case> filterCasesWithChanges(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        List<Case> filtered = new List<Case>();
        for (Case newCase : newCases) {
            Case oldCase = oldCaseMap.get(newCase.Id);
            if (hasSignificantChanges(newCase, oldCase)) {
                filtered.add(newCase);
            }
        }
        return filtered;
    }

    private List<Case> filterCasesNeedingSLAReset(
        List<Case> newCases,
        Map<Id, Case> oldCaseMap
    ) {
        List<Case> filtered = new List<Case>();
        for (Case newCase : newCases) {
            Case oldCase = oldCaseMap.get(newCase.Id);
            // Reset SLA if asset changed
            if (newCase.AssetId != oldCase.AssetId && newCase.AssetId != null) {
                filtered.add(newCase);
            }
        }
        return filtered;
    }

    private List<Case> filterCasesNeedingSLARecalc(
        List<Case> newCases,
        Map<Id, Case> oldCaseMap
    ) {
        List<Case> filtered = new List<Case>();
        for (Case newCase : newCases) {
            Case oldCase = oldCaseMap.get(newCase.Id);
            // Recalculate if service date changed
            if (newCase.Service_Date__c != oldCase.Service_Date__c) {
                filtered.add(newCase);
            }
        }
        return filtered;
    }

    private List<Case> filterCasesWithAssetChanges(
        List<Case> newCases,
        Map<Id, Case> oldCaseMap
    ) {
        List<Case> filtered = new List<Case>();
        for (Case newCase : newCases) {
            Case oldCase = oldCaseMap.get(newCase.Id);
            if (newCase.AssetId != oldCase.AssetId) {
                filtered.add(newCase);
            }
        }
        return filtered;
    }

    private List<Case> filterCasesNeedingAssetCreation(
        List<Case> cases,
        CaseTriggerContext context
    ) {
        List<Case> filtered = new List<Case>();
        for (Case c : cases) {
            // Create case asset if asset is specified
            if (String.isNotBlank(c.AssetId)) {
                filtered.add(c);
            }
        }
        return filtered;
    }

    private List<Case> filterCasesWithContacts(List<Case> cases) {
        List<Case> filtered = new List<Case>();
        for (Case c : cases) {
            if (String.isNotBlank(c.ContactId)) {
                filtered.add(c);
            }
        }
        return filtered;
    }

    private List<Case> filterCasesWithChargeabilityChanges(
        List<Case> newCases,
        Map<Id, Case> oldCaseMap
    ) {
        List<Case> filtered = new List<Case>();
        for (Case newCase : newCases) {
            Case oldCase = oldCaseMap.get(newCase.Id);
            if (newCase.Chargeable__c != oldCase.Chargeable__c) {
                filtered.add(newCase);
            }
        }
        return filtered;
    }

    private Boolean hasSignificantChanges(Case newCase, Case oldCase) {
        return newCase.Status != oldCase.Status ||
               newCase.Priority != oldCase.Priority ||
               newCase.OwnerId != oldCase.OwnerId ||
               newCase.Location__c != oldCase.Location__c ||
               newCase.AssetId != oldCase.AssetId ||
               newCase.ContactId != oldCase.ContactId;
    }
}
