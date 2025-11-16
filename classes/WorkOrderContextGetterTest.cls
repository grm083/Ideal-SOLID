/**
 * @description Test class for WorkOrderContextGetter
 *
 * This test class provides comprehensive coverage for the WorkOrderContextGetter
 * data access layer, testing all query methods and bulk operations.
 *
 * Coverage Target: 75%+
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class WorkOrderContextGetterTest {

    // ========================================================================
    // TEST SETUP
    // ========================================================================

    @testSetup
    static void setupTestData() {
        // Create full test hierarchy
        Map<String, Object> testData = TestDataFactory.createFullTestHierarchy();
        Account locationAccount = (Account)testData.get('locationAccount');
        Asset testAsset = (Asset)testData.get('asset');

        // Create work orders for testing
        List<WorkOrder> workOrders = new List<WorkOrder>();
        for (Integer i = 0; i < 5; i++) {
            WorkOrder wo = new WorkOrder(
                Subject = 'Test Work Order ' + i,
                AccountId = locationAccount.Id,
                AssetId = testAsset.Id,
                Status = 'New',
                Priority = 'Medium'
            );
            workOrders.add(wo);
        }
        insert workOrders;

        // Create work order line items
        List<WorkOrderLineItem> lineItems = new List<WorkOrderLineItem>();
        for (WorkOrder wo : workOrders) {
            WorkOrderLineItem woli = new WorkOrderLineItem(
                WorkOrderId = wo.Id,
                Subject = 'Test Line Item for ' + wo.Subject,
                Status = 'New',
                Priority = 'Medium'
            );
            lineItems.add(woli);
        }
        insert lineItems;
    }

    // ========================================================================
    // WORK ORDER QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetWorkOrdersByIds_Success() {
        // Given: A work order exists
        WorkOrder testWO = [SELECT Id FROM WorkOrder LIMIT 1];
        Set<Id> woIds = new Set<Id>{testWO.Id};

        Test.startTest();

        // When: Getting work order by Id
        Map<Id, WorkOrder> results = WorkOrderContextGetter.getWorkOrdersByIds(woIds);

        Test.stopTest();

        // Then: Work order is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return one work order');
        System.assert(results.containsKey(testWO.Id), 'Should contain the work order Id');
        System.assertNotEquals(null, results.get(testWO.Id).Subject, 'Subject should be populated');
    }

    @isTest
    static void testGetWorkOrdersByIds_NullSet() {
        Test.startTest();

        // When: Getting work order with null set
        Map<Id, WorkOrder> results = WorkOrderContextGetter.getWorkOrdersByIds(null);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Empty map should be returned for null');
    }

    @isTest
    static void testGetWorkOrdersByIds_EmptySet() {
        Test.startTest();

        // When: Getting work order with empty set
        Map<Id, WorkOrder> results = WorkOrderContextGetter.getWorkOrdersByIds(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetWorkOrdersByIds_BulkSuccess() {
        // Given: Multiple work orders exist
        List<WorkOrder> testWOs = [SELECT Id FROM WorkOrder LIMIT 5];
        Set<Id> woIds = new Set<Id>();
        for (WorkOrder wo : testWOs) {
            woIds.add(wo.Id);
        }

        Test.startTest();

        // When: Getting multiple work orders
        Map<Id, WorkOrder> results = WorkOrderContextGetter.getWorkOrdersByIds(woIds);

        Test.stopTest();

        // Then: All work orders are returned
        System.assertEquals(woIds.size(), results.size(), 'All work orders should be returned');
        for (Id woId : woIds) {
            System.assert(results.containsKey(woId), 'Result should contain work order Id: ' + woId);
            System.assertNotEquals(null, results.get(woId).Subject, 'Subject should be populated');
        }
    }

    // ========================================================================
    // WORK ORDER LINE ITEM QUERY TESTS
    // ========================================================================

    @isTest
    static void testGetWorkOrderLinesByWorkOrderId_Success() {
        // Given: A work order with line items exists
        WorkOrder testWO = [SELECT Id FROM WorkOrder LIMIT 1];
        Set<Id> woIds = new Set<Id>{testWO.Id};

        Test.startTest();

        // When: Getting work order line items by work order Id
        Map<Id, WorkOrderLineItem> results =
            WorkOrderContextGetter.getWorkOrderLinesByWorkOrderId(woIds);

        Test.stopTest();

        // Then: Line items are returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() > 0, 'Should return at least one line item');

        // Verify all line items belong to the work order
        for (WorkOrderLineItem woli : results.values()) {
            System.assertEquals(testWO.Id, woli.WorkOrderId,
                'Line item should belong to the work order');
        }
    }

    @isTest
    static void testGetWorkOrderLinesByWorkOrderId_NullSet() {
        Test.startTest();

        // When: Getting line items with null set
        Map<Id, WorkOrderLineItem> results =
            WorkOrderContextGetter.getWorkOrderLinesByWorkOrderId(null);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Empty map should be returned for null');
    }

    @isTest
    static void testGetWorkOrderLinesByWorkOrderId_EmptySet() {
        Test.startTest();

        // When: Getting line items with empty set
        Map<Id, WorkOrderLineItem> results =
            WorkOrderContextGetter.getWorkOrderLinesByWorkOrderId(new Set<Id>());

        Test.stopTest();

        // Then: Empty map is returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Empty map should be returned');
    }

    @isTest
    static void testGetWorkOrderLinesByWorkOrderId_BulkSuccess() {
        // Given: Multiple work orders with line items exist
        List<WorkOrder> testWOs = [SELECT Id FROM WorkOrder LIMIT 5];
        Set<Id> woIds = new Set<Id>();
        for (WorkOrder wo : testWOs) {
            woIds.add(wo.Id);
        }

        Test.startTest();

        // When: Getting line items for multiple work orders
        Map<Id, WorkOrderLineItem> results =
            WorkOrderContextGetter.getWorkOrderLinesByWorkOrderId(woIds);

        Test.stopTest();

        // Then: Line items for all work orders are returned
        System.assert(results.size() > 0, 'Should return line items');

        // Verify all line items belong to one of the work orders
        for (WorkOrderLineItem woli : results.values()) {
            System.assert(woIds.contains(woli.WorkOrderId),
                'Line item should belong to one of the queried work orders');
        }
    }

    // ========================================================================
    // GOVERNOR LIMIT TESTS
    // ========================================================================

    @isTest
    static void testBulkOperations_WithinGovernorLimits() {
        // Given: Many work orders exist
        List<WorkOrder> testWOs = [SELECT Id FROM WorkOrder];
        Set<Id> woIds = new Set<Id>();
        for (WorkOrder wo : testWOs) {
            woIds.add(wo.Id);
        }

        Test.startTest();

        // When: Getting all work orders and line items in bulk
        Map<Id, WorkOrder> woResults = WorkOrderContextGetter.getWorkOrdersByIds(woIds);
        Map<Id, WorkOrderLineItem> woliResults =
            WorkOrderContextGetter.getWorkOrderLinesByWorkOrderId(woIds);

        // Then: Operations complete within governor limits
        Integer queriesUsed = Limits.getQueries();
        System.assert(queriesUsed < Limits.getLimitQueries(), 'Should be within SOQL query limits');

        Test.stopTest();

        // And: All records are returned
        System.assertEquals(woIds.size(), woResults.size(), 'All work orders should be returned');
        System.assert(woliResults.size() > 0, 'Line items should be returned');
    }

    // ========================================================================
    // FIELD ACCESSIBILITY TESTS
    // ========================================================================

    @isTest
    static void testGetWorkOrdersByIds_FieldsAccessible() {
        // Given: A work order exists
        WorkOrder testWO = [SELECT Id, Subject, Status, Priority FROM WorkOrder LIMIT 1];
        Set<Id> woIds = new Set<Id>{testWO.Id};

        Test.startTest();

        // When: Getting work order by Id
        Map<Id, WorkOrder> results = WorkOrderContextGetter.getWorkOrdersByIds(woIds);

        Test.stopTest();

        // Then: Standard fields are accessible
        WorkOrder result = results.get(testWO.Id);
        System.assertNotEquals(null, result.Subject, 'Subject should be accessible');
        System.assertNotEquals(null, result.Status, 'Status should be accessible');
        System.assertNotEquals(null, result.Priority, 'Priority should be accessible');
    }

    // ========================================================================
    // NEGATIVE TESTS
    // ========================================================================

    @isTest
    static void testGetWorkOrdersByIds_InvalidId() {
        // Given: An invalid work order Id
        Id fakeId = '0WO000000000000AAA'; // Valid Id format, doesn't exist
        Set<Id> woIds = new Set<Id>{fakeId};

        Test.startTest();

        // When: Getting work order with invalid Id
        Map<Id, WorkOrder> results = WorkOrderContextGetter.getWorkOrdersByIds(woIds);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'Empty map should be returned for invalid Id');
    }

    @isTest
    static void testGetWorkOrderLinesByWorkOrderId_NoLineItems() {
        // Given: A work order without line items
        Account locationAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Location' LIMIT 1];
        WorkOrder woWithoutLines = new WorkOrder(
            Subject = 'WO Without Lines',
            AccountId = locationAccount.Id,
            Status = 'New'
        );
        insert woWithoutLines;

        Set<Id> woIds = new Set<Id>{woWithoutLines.Id};

        Test.startTest();

        // When: Getting line items for work order without any
        Map<Id, WorkOrderLineItem> results =
            WorkOrderContextGetter.getWorkOrderLinesByWorkOrderId(woIds);

        Test.stopTest();

        // Then: Empty map is returned
        System.assertEquals(0, results.size(), 'No line items should be returned');
    }
}
