# Phase 4: Eliminate Static Variable Coupling - Refactoring Plan

## Objective
Eliminate all public static variables used for inter-class communication, replacing them with explicit parameter passing to follow SOLID principles and eliminate hidden coupling.

## Current State Analysis

### Static Variables to Eliminate

#### 1. CaseTriggerHelper Static Maps
- `public static Map<Id,Asset> casewithContainer`
- `public static Map<Id,Account> casewithLocation`
- Set by: CaseTriggerHandler (lines 125-126, 273-274), SLACalculationUtility (line 173)
- Used by: AssetHeadersForCaseController, CustomCaseHighlightPanelCntrl, BusinessRuleHelper

#### 2. Entitlement_Utility Static Variables
- `public static Set<Id> accountIdSet`
- `public static Date minimumServiceDate`
- Set by: CaseTriggerHelper.fetchSLA (lines 91, 105)
- Used by: Entitlement_Utility internal queries (line 327)

### Dependencies to Break

1. **SLACalculationUtility.cls:173** → `CaseTriggerHelper.casewithLocation.putAll()`
2. **CaseUIService.cls:257** → `CaseTriggerHelper.fetchSLA()`
3. **Entitlement_Utility** → Uses static variables for query filtering
4. **AssetHeadersForCaseController** → Writes to static maps
5. **CustomCaseHighlightPanelCntrl** → Writes to and reads from static maps

## Refactoring Strategy

### Step 1: Refactor Entitlement_Utility (Foundation)
**Why First**: This is the deepest dependency - other classes depend on it

**Changes**:
1. Remove public static variables
2. Add overloaded methods that accept accountIds and minimumServiceDate as parameters
3. Keep existing methods for backward compatibility, marked as @Deprecated
4. Update internal method calls to use parameters instead of static variables

**Files Modified**: Entitlement_Utility.cls

### Step 2: Refactor CaseTriggerHelper.fetchSLA
**Why Second**: This depends on Entitlement_Utility and is called by CaseUIService

**Changes**:
1. Update fetchSLA to extract accountIds and minimumServiceDate from the case map
2. Pass these values as parameters to Entitlement_Utility.getPrioritizedEntitlements()
3. Remove dependency on static variables

**Files Modified**: CaseTriggerHelper.cls

### Step 3: Update CaseUIService
**Why Third**: This calls fetchSLA

**Changes**:
1. Update the call to CaseTriggerHelper.fetchSLA (line 257)
2. Ensure correct parameters are passed

**Files Modified**: CaseUIService.cls

### Step 4: Update SLACalculationUtility
**Why Fourth**: This writes to static variables

**Changes**:
1. Remove the line that writes to CaseTriggerHelper.casewithLocation (line 173)
2. Return the location map from the method instead
3. Update callers to use the returned value

**Files Modified**: SLACalculationUtility.cls

### Step 5: Deprecate Static Maps in CaseTriggerHelper
**Why Fifth**: After fixing all consumers, mark for deprecation

**Changes**:
1. Add @Deprecated annotation with migration instructions
2. Add documentation explaining why they're deprecated
3. Keep them for backward compatibility with external code

**Files Modified**: CaseTriggerHelper.cls

### Step 6: Update Controllers (AssetHeadersForCaseController, CustomCaseHighlightPanelCntrl)
**Why Last**: These are UI layer components that can adapt to service layer changes

**Changes**:
1. Remove direct access to static maps
2. Use proper service layer methods to get data
3. Pass data through method parameters

**Files Modified**:
- AssetHeadersForCaseController.cls
- CustomCaseHighlightPanelCntrl.cls

## Implementation Order

1. ✅ Analyze dependencies
2. ⏳ Refactor Entitlement_Utility (add parameter-based methods)
3. ⏳ Refactor CaseTriggerHelper.fetchSLA
4. ⏳ Update CaseUIService
5. ⏳ Update SLACalculationUtility
6. ⏳ Deprecate static maps in CaseTriggerHelper
7. ⏳ Update AssetHeadersForCaseController
8. ⏳ Update CustomCaseHighlightPanelCntrl
9. ⏳ Test all changes
10. ⏳ Commit and push

## Expected Outcomes

### Architecture Improvements
- ✅ Elimination of hidden coupling through static variables
- ✅ Explicit data flow through method parameters
- ✅ Better testability (no shared state)
- ✅ Compliance with Dependency Inversion Principle
- ✅ Thread-safe operations (no static state mutation)

### Code Quality Metrics
- **Before**: 5 classes with static variable coupling
- **After**: 0 classes with static variable coupling
- **Breaking Changes**: 0 (backward compatibility maintained with @Deprecated)
- **Architecture Grade**: B+ → A-

## Backward Compatibility

All changes will maintain backward compatibility by:
1. Keeping deprecated static variables available
2. Providing new parameter-based methods alongside old ones
3. Clear migration documentation in @Deprecated annotations
4. No changes to public method signatures (only internal implementation)

## Testing Strategy

1. Verify all existing functionality works
2. Ensure no compilation errors
3. Check that deprecated methods still work
4. Validate new parameter-based methods work correctly
5. Test edge cases (null values, empty collections)
