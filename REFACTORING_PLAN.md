# QuoteProcurementController Refactoring Plan

## Overview
This document outlines the refactoring plan for QuoteProcurementController.cls, migrating 81 @AuraEnabled methods to use the new service layer architecture following SOLID principles.

## Service Layer Architecture

The following service classes have been created to replace the monolithic controller:

1. **QuoteProcurementContextGetter** - Data access layer (queries)
2. **QuoteProcurementDMLService** - DML operations
3. **QuoteProcurementBusinessRuleService** - Validation logic
4. **QuoteProcurementMASService** - MAS operations
5. **QuoteProcurementOrderService** - Order management
6. **QuoteProcurementProductService** - Product configuration
7. **QuoteProcurementSearchService** - SOSL searches
8. **QuoteProcurementUIService** - UI support
9. **QuoteProcurementPositionService** - Position management
10. **QuoteProcurementIntegrationService** - SLA & integrations

## Method Mapping by Service Class

### QuoteProcurementContextGetter (Data Access)
| Line | Method | Return Type | Status |
|------|--------|-------------|--------|
| 41 | buildQuoteWrapper | ProductsWrapper | To Refactor |
| 118 | showErrorWrapper | List<nteWrapper> | To Refactor |
| 873 | getOrders | List<Quote_Order__c> | ✓ Service exists |
| 1270 | getCaseQuotes | List<ProductsWrapper> | To Refactor |
| 1294 | getDuplicates | List<ProductsWrapper> | To Refactor |
| 1410 | showLocationPosition | List<SBQQ__QuoteLine__c> | ✓ Service exists |
| 1955 | getQuoteStatusDetails | SBQQ__Quote__c | To Refactor |
| 2022 | getQuoteForOrders | SBQQ__Quote__c | To Refactor |
| 2114 | getQuoteLineForOrders | SBQQ__QuoteLine__c | To Refactor |
| 2144 | getQuoteLineForOrdersWrapper | qLineWrapper | To Refactor |
| 3861 | fetchUser | Map<string,Object> | To Refactor |
| 3877 | getQuoteLinesByQuote | List<HeaderWrapper> | To Refactor |
| 3940 | getParentQlineRec | SBQQ__QuoteLine__c | To Refactor |

### QuoteProcurementDMLService (DML Operations)
| Line | Method | Return Type | Status |
|------|--------|-------------|--------|
| 603 | updateVendorDetails | Boolean | ✓ Service exists |
| 633 | updateCompanyCategories | Boolean | ✓ Service exists |
| 662 | writeMASDetails | MASResponseWrapper | ✓ Service exists |
| 1427 | updateALPOnQuoteLine | void | To Refactor |
| 1459 | updateQuoteOverview | Boolean | To Refactor |
| 1850 | updateFinancialDetail | string | ✓ Service exists |
| 2033 | updateQuoteForOrders | Boolean | To Refactor |
| 2179 | updateQuoteLineForOrders | Boolean | To Refactor |
| 3266 | updateStatus | String | To Refactor |
| 5450 | saveQuoteOnly | void | To Refactor |
| 5462 | approveQuoteLine | void | To Refactor |

### QuoteProcurementBusinessRuleService (Validation)
| Line | Method | Return Type | Status |
|------|--------|-------------|--------|
| 1927 | quoteBusinessRules | Business_Rule__c | To Refactor |
| 3620 | validateHaulRemovalqLine | string | To Refactor |

### QuoteProcurementMASService (MAS Operations)
| Line | Method | Return Type | Status |
|------|--------|-------------|--------|
| 544 | returnUniqueMASDetails | List<AggregateResult> | ✓ Service exists |
| 735 | bypassPriceReview | boolean | ✓ Service exists |
| 1790 | getMasDetails | MASWrapper | ✓ Service exists |

### QuoteProcurementOrderService (Order Management)
| Line | Method | Return Type | Status |
|------|--------|-------------|--------|
| 886 | deleteQuoteOrders | string | ✓ Service exists |
| 2648 | createDelivery | QuoteSummaryWrapper | ✓ Service exists |
| 3239 | generateOrderWrapper | OrderWrapper | ✓ Service exists |

### QuoteProcurementProductService (Product Configuration)
| Line | Method | Return Type | Status |
|------|--------|-------------|--------|
| 1521 | getSizes | Map<String, String> | To Refactor |
| 2330 | getAccessoriesWithSelection | Map<String,List<Object>> | ✓ Service exists |
| 2351 | getAccessories | List<SBQQ__ProductOption__c> | To Refactor |
| 2370 | getPadlockKeys | List<SBQQ__ProductOption__c> | To Refactor |
| 2383 | getConfigAttributes | List<SBQQ__ConfigurationAttribute__c> | ✓ Service exists |
| 2476 | updateConfigAttribute | string | ✓ Service exists |
| 2499 | addProductOption | string | To Refactor |
| 2552 | removeProductOption | string | To Refactor |
| 2576 | removeProductOption (overload) | string | To Refactor |
| 2599 | updateKeysQuantity | string | To Refactor |
| 3910 | getProducts | List<Product2> | To Refactor |
| 3917 | getPreselectedProduct | Product2 | To Refactor |
| 3923 | getWasteStreams | List<SBQQ__ProductOption__c> | To Refactor |

### QuoteProcurementSearchService (SOSL Searches)
| Line | Method | Return Type | Status |
|------|--------|-------------|--------|
| 1199 | searchVendors | List<Account> | ✓ Service exists |
| 1215 | allPositions | List<Account_Position__c> | ✓ Service exists |
| 1239 | searchPositions | List<Account_Position__c> | ✓ Service exists |
| 1908 | getActiveProjects | List<Project_Code__c> | ✓ Service exists |

### QuoteProcurementUIService (UI Support)
| Line | Method | Return Type | Status |
|------|--------|-------------|--------|
| 267 | getMaterialTypes | List<Map<String, String>> | To Refactor |
| 1778 | getPicklistSchema | List<String> | ✓ Service exists |
| 1824 | getQLFinancialDetail | FinancialDetailWrapper | ✓ Service exists |
| 1988 | getDeliveryOverrideReasons | List<String> | To Refactor |
| 3337 | getSLAOverrideReasons | List<String> | ✓ Service exists |
| 3928 | getDurations | Map<String, String> | To Refactor |
| 4099 | getCompanyCategory | List<Map<String, String>> | To Refactor |

### QuoteProcurementPositionService (Position Management)
| Line | Method | Return Type | Status |
|------|--------|-------------|--------|
| 1323 | storeOnsite | String | ✓ Service exists |
| 1347 | storeOffsite | String | ✓ Service exists |

### QuoteProcurementIntegrationService (SLA & Integrations)
| Line | Method | Return Type | Status |
|------|--------|-------------|--------|
| 1970 | hasAssetAvailabilityPermission | Boolean | To Refactor |
| 1975 | hasAssetAvailabilityPermissionWithHaulAway | Boolean | To Refactor |
| 1983 | getAvailabilityResponse | AAV_Asset_Availability__c | ✓ Service exists |
| 1999 | updateAlternateProduct | Boolean | ✓ Service exists |
| 2219 | addCommentForSLAOverrideFromIntake | void | To Refactor |
| 2243 | addCommentForSLAOverride | void | ✓ Service exists |
| 3985 | callDetermineSLA | Date | To Refactor |
| 4019 | removeStartAndEndDateOnRelatedQL | void | To Refactor |

### Complex Methods Requiring Special Handling
| Line | Method | Return Type | Notes |
|------|--------|-------------|-------|
| 283 | buildWrapper | ProductsWrapper | Large wrapper builder - needs multiple services |
| 1515 | getAddProductId | string | Simple query - can stay in controller |
| 1558 | addQuoteAndQuoteine | String | Complex - needs DML + Context services |
| 1699 | getFavorites | FavoriteContainerWrapper | Complex wrapper - needs refactoring |
| 1762 | addQuoteAsProductNotListed | String | Uses GetCaseInformation - refactor |
| 1770 | goToCase | string | Simple query - can stay in controller |
| 3348 | createQuoteLines | String | Complex DML - needs refactoring |
| 3590 | deleteHaulRemovalqLine | string | DML operation - use DMLService |
| 3956 | createQuoteComment | void | Comment creation - needs refactoring |
| 5434 | getIsAmendmentQuote | Boolean | Simple query - can stay in controller |
| 5439 | getshowAddQuoteOnlyServiceButtonForAmendment | Boolean | Logic - needs refactoring |
| 5444 | getDisableQuoteOnlyButtonForAmendment | Boolean | Logic - needs refactoring |
| 5456 | displayApprovalButton | boolean | Logic - needs refactoring |
| 5474 | getMultivendorPricingRecord | List<Pricing_Request__c> | Query - use ContextGetter |
| 5485 | getAMMultiVendorSwitch | boolean | Feature flag check |

## Component Dependencies

### LWC Components
1. **addFavoriteContainersLWC** - Uses: getFavorites, getAddProductId, addQuoteAndQuoteine, addQuoteAsProductNotListed
2. **caseQuoteModalLWC** - Uses: getCaseQuotes

### Aura Components
1. **AddFavoriteContainers** - Uses: getFavorites, getAddProductId, addQuoteAndQuoteine, addQuoteAsProductNotListed
2. **CaseQuoteModal** - Uses: getCaseQuotes

## Refactoring Phases

### Phase 1: Controller Wrapper Methods (Priority: High)
Refactor @AuraEnabled methods that are direct wrappers around service methods:
- Update to delegate to service classes
- Add error handling
- Maintain backward compatibility

### Phase 2: Complex Business Logic (Priority: High)
Refactor methods with complex logic:
- buildWrapper
- addQuoteAndQuoteine
- createQuoteLines
- getFavorites

### Phase 3: Simple Query Methods (Priority: Medium)
Refactor simple query methods to use ContextGetter:
- getQuoteStatusDetails
- getQuoteForOrders
- getQuoteLinesByQuote

### Phase 4: Validation & Integration (Priority: Medium)
Complete remaining validation and integration methods

### Phase 5: Testing & Validation (Priority: Critical)
- Verify all components work with refactored controller
- Run test classes
- Validate coverage remains above 85%

## Success Criteria
- All 81 @AuraEnabled methods refactored to use services
- No breaking changes to component interfaces
- Test coverage maintained above 85%
- All existing functionality preserved
