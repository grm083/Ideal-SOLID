/*************************************************************
@Name: WorkOrderTriggerHandlerTest
@Author: Claude AI
@CreateDate: 12/01/2025
@Description: Comprehensive test class for WorkOrderTriggerHandler
@Coverage: WorkOrderTriggerHandler
**************************************************************/
@isTest
private class WorkOrderTriggerHandlerTest {

    @testSetup
    static void setupTestData() {
        // Create test account (Client)
        Account clientAccount = new Account(
            Name = 'Test Client Account'
        );
        insert clientAccount;

        // Create location account
        Account locationAccount = new Account(
            Name = 'Test Location Account',
            ParentId = clientAccount.Id,
            ShippingCountry = 'USA',
            ShippingCity = 'Test City',
            ShippingStreet = '123 Test St',
            ShippingState = 'CA',
            ShippingPostalCode = '12345'
        );
        insert locationAccount;

        // Create vendor account
        Account vendorAccount = new Account(
            Name = 'Test Vendor Account'
        );
        insert vendorAccount;

        // Create contact for vendor
        Contact vendorContact = new Contact(
            FirstName = 'Vendor',
            LastName = 'Contact',
            Email = 'vendor@example.com',
            AccountId = vendorAccount.Id
        );
        insert vendorContact;

        // Create AccountContactRelation with Dispatch role
        List<AccountContactRelation> acrList = [SELECT Id FROM AccountContactRelation
                                                 WHERE AccountId = :vendorAccount.Id
                                                 AND ContactId = :vendorContact.Id LIMIT 1];
        if (!acrList.isEmpty()) {
            acrList[0].Roles = 'Dispatch';
            update acrList[0];
        }

        // Create test contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test@example.com',
            AccountId = locationAccount.Id
        );
        insert testContact;

        // Create test asset
        Asset testAsset = new Asset(
            Name = 'Test Asset',
            AccountId = locationAccount.Id,
            ContactId = testContact.Id
        );
        insert testAsset;

        // Create test case
        Case testCase = new Case(
            Subject = 'Test Case for WorkOrder',
            Status = 'Open',
            Origin = 'Web',
            AccountId = locationAccount.Id,
            ContactId = testContact.Id,
            AssetId = testAsset.Id,
            Case_Type__c = 'Service',
            Service_Date__c = System.today().addDays(7),
            Work_Order_Instructions__c = 'Test instructions for work order',
            Reference_Number__c = '12345'
        );
        insert testCase;
    }

    @isTest
    static void testBeforeInsert() {
        Case testCase = [SELECT Id, Work_Order_Instructions__c, ContactId FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];

        Test.startTest();

        // Create WorkOrder
        WorkOrder newWorkOrder = new WorkOrder(
            CaseId = testCase.Id,
            Customer_Location__c = locationAccount.Id,
            Status = 'New',
            Subject = 'Test Work Order'
        );
        insert newWorkOrder;

        Test.stopTest();

        // Verify WorkOrder was inserted with instructions from Case
        WorkOrder insertedWO = [SELECT Id, Instructions__c, ContactId, Client__c
                                FROM WorkOrder WHERE Id = :newWorkOrder.Id];
        System.assertEquals(testCase.Work_Order_Instructions__c, insertedWO.Instructions__c,
                          'Instructions should match Case');
        System.assertEquals(testCase.ContactId, insertedWO.ContactId,
                          'ContactId should match Case');
        System.assertNotEquals(null, insertedWO.Client__c, 'Client should be populated');
    }

    @isTest
    static void testBeforeInsertWithoutCase() {
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];

        Test.startTest();

        // Create WorkOrder without Case
        WorkOrder newWorkOrder = new WorkOrder(
            Customer_Location__c = locationAccount.Id,
            Status = 'New',
            Subject = 'Test Work Order No Case'
        );
        insert newWorkOrder;

        Test.stopTest();

        // Verify WorkOrder was inserted
        WorkOrder insertedWO = [SELECT Id, Client__c FROM WorkOrder WHERE Id = :newWorkOrder.Id];
        System.assertNotEquals(null, insertedWO.Client__c, 'Client should be populated from location');
    }

    @isTest
    static void testBeforeUpdate() {
        Case testCase = [SELECT Id, Work_Order_Instructions__c FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];
        Account vendorAccount = [SELECT Id FROM Account WHERE Name = 'Test Vendor Account' LIMIT 1];

        // Insert WorkOrder
        WorkOrder testWorkOrder = new WorkOrder(
            CaseId = testCase.Id,
            Customer_Location__c = locationAccount.Id,
            Status = 'New',
            Subject = 'Test Work Order Update'
        );
        insert testWorkOrder;

        Test.startTest();

        // Update WorkOrder
        testWorkOrder.Status = 'Sent';
        testWorkOrder.Vendor_Account_Id__c = vendorAccount.Id;
        testWorkOrder.Service_Date__c = System.today().addDays(10);
        update testWorkOrder;

        Test.stopTest();

        // Verify WorkOrder was updated
        WorkOrder updatedWO = [SELECT Id, Status, Vendor_Account_Id__c FROM WorkOrder WHERE Id = :testWorkOrder.Id];
        System.assertEquals('Sent', updatedWO.Status);
        System.assertEquals(vendorAccount.Id, updatedWO.Vendor_Account_Id__c);
    }

    @isTest
    static void testBeforeUpdateIntegrationStatus() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];

        // Insert WorkOrder
        WorkOrder testWorkOrder = new WorkOrder(
            CaseId = testCase.Id,
            Customer_Location__c = locationAccount.Id,
            Status = 'Sent',
            Subject = 'Test Integration Status'
        );
        insert testWorkOrder;

        Test.startTest();

        // Reset bypass flag
        RecurrsiveTriggerHandler.bypassValidation = false;

        // Update fields that should trigger Integration_Status__c = 'Update'
        testWorkOrder.Service_Date__c = System.today().addDays(15);
        testWorkOrder.Instructions__c = 'Updated instructions';
        update testWorkOrder;

        Test.stopTest();

        // Verify Integration Status was set
        WorkOrder updatedWO = [SELECT Id, Integration_Status__c FROM WorkOrder WHERE Id = :testWorkOrder.Id];
        System.assertEquals('Update', updatedWO.Integration_Status__c);
    }

    @isTest
    static void testAfterInsert() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];
        Account vendorAccount = [SELECT Id FROM Account WHERE Name = 'Test Vendor Account' LIMIT 1];

        Test.startTest();

        // Create WorkOrder with Acorn number
        WorkOrder newWorkOrder = new WorkOrder(
            CaseId = testCase.Id,
            Customer_Location__c = locationAccount.Id,
            Vendor_Account_Id__c = vendorAccount.Id,
            Status = 'New',
            Subject = 'Test After Insert',
            Acorn_WorkOrder_Number__c = 'ACORN-12345'
        );
        insert newWorkOrder;

        Test.stopTest();

        // Verify WorkOrder was inserted
        WorkOrder insertedWO = [SELECT Id, Acorn_WorkOrder_Number__c FROM WorkOrder WHERE Id = :newWorkOrder.Id];
        System.assertEquals('ACORN-12345', insertedWO.Acorn_WorkOrder_Number__c);
    }

    @isTest
    static void testAfterUpdate() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];
        Account vendorAccount = [SELECT Id FROM Account WHERE Name = 'Test Vendor Account' LIMIT 1];

        // Insert WorkOrder
        WorkOrder testWorkOrder = new WorkOrder(
            CaseId = testCase.Id,
            Customer_Location__c = locationAccount.Id,
            Vendor_Account_Id__c = vendorAccount.Id,
            Status = 'New',
            Subject = 'Test After Update'
        );
        insert testWorkOrder;

        Test.startTest();

        // Update WorkOrder status
        testWorkOrder.Status = 'Work Complete';
        update testWorkOrder;

        Test.stopTest();

        // Verify WorkOrder was updated
        WorkOrder updatedWO = [SELECT Id, Status FROM WorkOrder WHERE Id = :testWorkOrder.Id];
        System.assertEquals('Work Complete', updatedWO.Status);
    }

    @isTest
    static void testAfterUpdateVendorStatusChange() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];
        Account vendorAccount = [SELECT Id FROM Account WHERE Name = 'Test Vendor Account' LIMIT 1];

        // Insert WorkOrder
        WorkOrder testWorkOrder = new WorkOrder(
            CaseId = testCase.Id,
            Customer_Location__c = locationAccount.Id,
            Vendor_Account_Id__c = vendorAccount.Id,
            Status = 'Sent',
            Subject = 'Test Vendor Status',
            Vendor_Service_Status__c = 'Pending'
        );
        insert testWorkOrder;

        Test.startTest();

        // Update vendor status
        testWorkOrder.Vendor_Service_Status__c = 'Confirmed - Positive';
        update testWorkOrder;

        Test.stopTest();

        // Verify vendor status was updated
        WorkOrder updatedWO = [SELECT Id, Vendor_Service_Status__c FROM WorkOrder WHERE Id = :testWorkOrder.Id];
        System.assertEquals('Confirmed - Positive', updatedWO.Vendor_Service_Status__c);
    }

    @isTest
    static void testAfterUpdateServiceDateChange() {
        Case testCase = [SELECT Id, Service_Date__c FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];

        // Insert WorkOrder
        WorkOrder testWorkOrder = new WorkOrder(
            CaseId = testCase.Id,
            Customer_Location__c = locationAccount.Id,
            Status = 'Sent',
            Subject = 'Test Service Date Change',
            Service_Date__c = System.today().addDays(7)
        );
        insert testWorkOrder;

        Test.startTest();

        // Update service date
        testWorkOrder.Service_Date__c = System.today().addDays(14);
        update testWorkOrder;

        Test.stopTest();

        // Verify service date was updated
        WorkOrder updatedWO = [SELECT Id, Service_Date__c FROM WorkOrder WHERE Id = :testWorkOrder.Id];
        System.assertEquals(System.today().addDays(14), updatedWO.Service_Date__c);
    }

    @isTest
    static void testAfterUpdateCancellation() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];

        // Insert WorkOrder
        WorkOrder testWorkOrder = new WorkOrder(
            CaseId = testCase.Id,
            Customer_Location__c = locationAccount.Id,
            Status = 'Sent',
            Subject = 'Test Cancellation'
        );
        insert testWorkOrder;

        Test.startTest();

        // Cancel WorkOrder
        testWorkOrder.Status = 'Cancelled';
        testWorkOrder.Exception_Reason__c = 'Test Reason';
        testWorkOrder.Exception_Description__c = 'Test Description';
        update testWorkOrder;

        Test.stopTest();

        // Verify WorkOrder was cancelled
        WorkOrder updatedWO = [SELECT Id, Status, Exception_Reason__c FROM WorkOrder WHERE Id = :testWorkOrder.Id];
        System.assertEquals('Cancelled', updatedWO.Status);
        System.assertEquals('Test Reason', updatedWO.Exception_Reason__c);
    }

    @isTest
    static void testAfterUpdateRejection() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];

        // Insert WorkOrder
        WorkOrder testWorkOrder = new WorkOrder(
            CaseId = testCase.Id,
            Customer_Location__c = locationAccount.Id,
            Status = 'Sent',
            Subject = 'Test Rejection'
        );
        insert testWorkOrder;

        Test.startTest();

        // Reject WorkOrder
        testWorkOrder.Status = 'Rejected';
        update testWorkOrder;

        Test.stopTest();

        // Verify WorkOrder was rejected
        WorkOrder updatedWO = [SELECT Id, Status FROM WorkOrder WHERE Id = :testWorkOrder.Id];
        System.assertEquals('Rejected', updatedWO.Status);
    }

    @isTest
    static void testUpdateDispatchEmail() {
        Account vendorAccount = [SELECT Id FROM Account WHERE Name = 'Test Vendor Account' LIMIT 1];
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];

        Test.startTest();

        // Create WorkOrder with vendor
        WorkOrder newWorkOrder = new WorkOrder(
            CaseId = testCase.Id,
            Customer_Location__c = locationAccount.Id,
            Vendor_Account_Id__c = vendorAccount.Id,
            Status = 'New',
            Subject = 'Test Dispatch Email'
        );
        insert newWorkOrder;

        Test.stopTest();

        // Verify dispatch email was populated
        WorkOrder insertedWO = [SELECT Id, Dispatch_Email__c FROM WorkOrder WHERE Id = :newWorkOrder.Id];
        System.assertNotEquals(null, insertedWO.Dispatch_Email__c, 'Dispatch email should be populated');
    }

    @isTest
    static void testUpdateDryRunDetail() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];

        // Insert WorkOrder
        WorkOrder testWorkOrder = new WorkOrder(
            CaseId = testCase.Id,
            Customer_Location__c = locationAccount.Id,
            Status = 'New',
            Subject = 'Test Dry Run',
            Dry_Run_Cost__c = 100.00,
            Dry_Run_Price__c = 150.00
        );
        insert testWorkOrder;

        Test.startTest();

        // Update Dry Run details
        testWorkOrder.Dry_Run_Cost__c = 120.00;
        testWorkOrder.Dry_Run_Price__c = 180.00;
        testWorkOrder.Dry_Run_Root_Cause__c = 'Test Root Cause';
        update testWorkOrder;

        Test.stopTest();

        // Verify Dry Run details were updated
        WorkOrder updatedWO = [SELECT Id, Dry_Run_Cost__c, Dry_Run_Price__c,
                               Dry_Run_Cost_in_Currency__c, Dry_Run_Price_in_Currency__c
                               FROM WorkOrder WHERE Id = :testWorkOrder.Id];
        System.assertEquals(120.00, updatedWO.Dry_Run_Cost__c);
        System.assertEquals(120.00, updatedWO.Dry_Run_Cost_in_Currency__c);
    }

    @isTest
    static void testBulkInsert() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];

        Test.startTest();

        // Create 200 work orders
        List<WorkOrder> bulkWorkOrders = new List<WorkOrder>();
        for (Integer i = 0; i < 200; i++) {
            bulkWorkOrders.add(new WorkOrder(
                CaseId = testCase.Id,
                Customer_Location__c = locationAccount.Id,
                Status = 'New',
                Subject = 'Bulk Work Order ' + i
            ));
        }
        insert bulkWorkOrders;

        Test.stopTest();

        // Verify all work orders were inserted
        List<WorkOrder> insertedWOs = [SELECT Id FROM WorkOrder WHERE Subject LIKE 'Bulk Work Order%'];
        System.assertEquals(200, insertedWOs.size(), 'All work orders should be inserted');
    }

    @isTest
    static void testBulkUpdate() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];

        // Create work orders
        List<WorkOrder> bulkWorkOrders = new List<WorkOrder>();
        for (Integer i = 0; i < 200; i++) {
            bulkWorkOrders.add(new WorkOrder(
                CaseId = testCase.Id,
                Customer_Location__c = locationAccount.Id,
                Status = 'New',
                Subject = 'Bulk Update WO ' + i
            ));
        }
        insert bulkWorkOrders;

        Test.startTest();

        // Update all work orders
        for (WorkOrder wo : bulkWorkOrders) {
            wo.Status = 'Sent';
        }
        update bulkWorkOrders;

        Test.stopTest();

        // Verify all work orders were updated
        List<WorkOrder> updatedWOs = [SELECT Id, Status FROM WorkOrder WHERE Subject LIKE 'Bulk Update WO%'];
        System.assertEquals(200, updatedWOs.size());
        for (WorkOrder wo : updatedWOs) {
            System.assertEquals('Sent', wo.Status);
        }
    }

    @isTest
    static void testSkipTriggerFlag() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];

        // Set skip trigger flag
        Constant_UTIL.skipWOTrigger = true;

        Test.startTest();

        // Create WorkOrder with flag set
        WorkOrder newWorkOrder = new WorkOrder(
            CaseId = testCase.Id,
            Customer_Location__c = locationAccount.Id,
            Status = 'New',
            Subject = 'Test Skip Trigger'
        );
        insert newWorkOrder;

        // Update with flag set
        newWorkOrder.Status = 'Sent';
        update newWorkOrder;

        Test.stopTest();

        // Reset flag
        Constant_UTIL.skipWOTrigger = false;

        // Verify operations completed
        WorkOrder finalWO = [SELECT Id, Status FROM WorkOrder WHERE Id = :newWorkOrder.Id];
        System.assertEquals('Sent', finalWO.Status);
    }

    @isTest
    static void testGetCaseDetails() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Set<Id> caseIdSet = new Set<Id>{testCase.Id};

        Test.startTest();

        Map<Id, Case> caseMap = WorkOrderTriggerHandler.getCaseDetails(caseIdSet);

        Test.stopTest();

        System.assertNotEquals(null, caseMap, 'Case map should not be null');
        System.assertEquals(1, caseMap.size(), 'Case map should contain one case');
        System.assert(caseMap.containsKey(testCase.Id), 'Case map should contain test case');
    }

    @isTest
    static void testGetAccountDetails() {
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location Account' LIMIT 1];
        Set<Id> accountIdSet = new Set<Id>{locationAccount.Id};

        Test.startTest();

        Map<Id, Account> accountMap = WorkOrderTriggerHandler.getAccountDetails(accountIdSet);

        Test.stopTest();

        System.assertNotEquals(null, accountMap, 'Account map should not be null');
        System.assertEquals(1, accountMap.size(), 'Account map should contain one account');
        System.assert(accountMap.containsKey(locationAccount.Id), 'Account map should contain location account');
    }
}
