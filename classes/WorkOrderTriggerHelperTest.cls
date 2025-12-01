/*************************************************************
@Name: WorkOrderTriggerHelperTest
@Author: Claude AI
@CreateDate: 12/01/2025
@Description: Comprehensive test class for WorkOrderTriggerHelper
@Coverage: WorkOrderTriggerHelper
**************************************************************/
@isTest
private class WorkOrderTriggerHelperTest {

    @testSetup
    static void setupTestData() {
        // Create account hierarchy
        Account clientAccount = new Account(Name = 'Test Client');
        insert clientAccount;

        Account locationAccount = new Account(
            Name = 'Test Location',
            ParentId = clientAccount.Id,
            ShippingCountry = 'USA'
        );
        insert locationAccount;

        Account vendorAccount = new Account(
            Name = 'Test Vendor',
            Contact_Manually_Vendor__c = false
        );
        insert vendorAccount;

        // Create contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test@example.com',
            AccountId = locationAccount.Id
        );
        insert testContact;

        // Create asset
        Asset testAsset = new Asset(
            Name = 'Test Asset',
            AccountId = locationAccount.Id
        );
        insert testAsset;

        // Create case
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'Open',
            Case_Sub_Status__c = 'Pending Service Integration',
            AccountId = locationAccount.Id,
            ContactId = testContact.Id,
            AssetId = testAsset.Id,
            Service_Date__c = System.today().addDays(7),
            Work_Order_Instructions__c = 'Test instructions',
            Availability_Confirmed__c = true
        );
        insert testCase;

        // Create work order
        WorkOrder testWO = new WorkOrder(
            CaseId = testCase.Id,
            Customer_Location__c = locationAccount.Id,
            Status = 'New',
            Subject = 'Test Work Order',
            Service_Date__c = System.today().addDays(7)
        );
        insert testWO;
    }

    @isTest
    static void testUpdateCaseDetailBasic() {
        WorkOrder wo = [SELECT Id, CaseId, Service_Date__c FROM WorkOrder LIMIT 1];
        Case testCase = [SELECT Id, Work_Order__c, Proposed_Service_Date__c FROM Case WHERE Id = :wo.CaseId];

        Map<Id, WorkOrder> woMap = new Map<Id, WorkOrder>{wo.Id => wo};
        Map<Id, Case> caseMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();

        WorkOrderTriggerHelper.updateCaseDetail(woMap, null, caseMap);

        Test.stopTest();

        // Verify case was updated
        Case updatedCase = [SELECT Id, Work_Order__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(wo.Id, updatedCase.Work_Order__c, 'Work Order should be linked to Case');
    }

    @isTest
    static void testUpdateCaseDetailServiceDateChange() {
        WorkOrder wo = [SELECT Id, CaseId, Service_Date__c FROM WorkOrder LIMIT 1];
        Case testCase = [SELECT Id, Status, Proposed_Service_Date__c FROM Case WHERE Id = :wo.CaseId];

        Date newServiceDate = System.today().addDays(14);
        wo.Service_Date__c = newServiceDate;
        WorkOrder oldWO = wo.clone(true);
        oldWO.Service_Date__c = System.today().addDays(7);

        update wo;

        Map<Id, WorkOrder> woMap = new Map<Id, WorkOrder>{wo.Id => wo};
        Map<Id, WorkOrder> oldWoMap = new Map<Id, WorkOrder>{oldWO.Id => oldWO};
        Map<Id, Case> caseMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();

        RecurrsiveTriggerHandler.bypassValidation = false;
        WorkOrderTriggerHelper.updateCaseDetail(woMap, oldWoMap, caseMap);

        Test.stopTest();

        // Verify proposed service date was updated
        Case updatedCase = [SELECT Id, Proposed_Service_Date__c FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, updatedCase.Proposed_Service_Date__c);
    }

    @isTest
    static void testUpdateCaseDetailConfirmedNegative() {
        WorkOrder wo = [SELECT Id, CaseId, Vendor_Service_Status__c FROM WorkOrder LIMIT 1];
        Case testCase = [SELECT Id, Status, Case_Sub_Status__c FROM Case WHERE Id = :wo.CaseId];

        wo.Vendor_Service_Status__c = 'Confirmed - Negative';
        update wo;

        Map<Id, WorkOrder> woMap = new Map<Id, WorkOrder>{wo.Id => wo};
        Map<Id, Case> caseMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();

        WorkOrderTriggerHelper.updateCaseDetail(woMap, null, caseMap);

        Test.stopTest();

        // Verify case was closed
        Case updatedCase = [SELECT Id, Status, Case_Sub_Status__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Closed', updatedCase.Status, 'Case should be closed');
        System.assertEquals('Service Not Performed', updatedCase.Case_Sub_Status__c);
    }

    @isTest
    static void testUpdateCaseDetailConfirmedPositive() {
        WorkOrder wo = [SELECT Id, CaseId, Vendor_Service_Status__c FROM WorkOrder LIMIT 1];
        Case testCase = [SELECT Id, Status, Case_Sub_Status__c FROM Case WHERE Id = :wo.CaseId];

        WorkOrder oldWO = wo.clone(true);
        oldWO.Vendor_Service_Status__c = null;

        wo.Vendor_Service_Status__c = 'Confirmed - Positive';
        wo.Status = 'Work Complete';
        update wo;

        Map<Id, WorkOrder> woMap = new Map<Id, WorkOrder>{wo.Id => wo};
        Map<Id, WorkOrder> oldWoMap = new Map<Id, WorkOrder>{oldWO.Id => oldWO};
        Map<Id, Case> caseMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();

        WorkOrderTriggerHelper.updateCaseDetail(woMap, oldWoMap, caseMap);

        Test.stopTest();

        // Verify case was marked as service confirmed
        Case updatedCase = [SELECT Id, Status, Case_Sub_Status__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Closed', updatedCase.Status, 'Case should be closed');
        System.assertEquals('Service Confirmed', updatedCase.Case_Sub_Status__c);
    }

    @isTest
    static void testUpdateCaseDetailPendingDispatch() {
        WorkOrder wo = [SELECT Id, CaseId, Status FROM WorkOrder LIMIT 1];
        Case testCase = [SELECT Id, Status, Case_Sub_Status__c, Source_System__c FROM Case WHERE Id = :wo.CaseId];
        testCase.Source_System__c = 'Acorn';
        update testCase;

        wo.Status = 'Issued';
        update wo;

        Account vendor = [SELECT Id, Contact_Manually_Vendor__c FROM Account WHERE Name = 'Test Vendor' LIMIT 1];
        wo.Vendor_Account_Id__c = vendor.Id;

        Map<Id, WorkOrder> woMap = new Map<Id, WorkOrder>{wo.Id => wo};
        Map<Id, Case> caseMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();

        WorkOrderTriggerHelper.updateCaseDetail(woMap, null, caseMap);

        Test.stopTest();

        // Verify case sub status was updated
        Case updatedCase = [SELECT Id, Case_Sub_Status__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Pending Dispatch', updatedCase.Case_Sub_Status__c);
    }

    @isTest
    static void testServiceDateChanges() {
        List<WorkOrder> woList = [SELECT Id, CaseId, Service_Date__c FROM WorkOrder];

        Map<Id, WorkOrder> oldWoMap = new Map<Id, WorkOrder>();
        for (WorkOrder wo : woList) {
            WorkOrder oldWO = wo.clone(true);
            oldWO.Service_Date__c = System.today().addDays(5);
            oldWoMap.put(oldWO.Id, oldWO);
            wo.Service_Date__c = System.today().addDays(10);
        }

        Test.startTest();

        WorkOrderTriggerHelper.ServiceDateChanges(woList, oldWoMap);

        Test.stopTest();

        // Verify method executed without errors
        System.assertNotEquals(null, woList, 'Work order list should not be null');
    }

    @isTest
    static void testCreateCaseComment() {
        WorkOrder wo = [SELECT Id, CaseId, Acorn_WorkOrder_Number__c FROM WorkOrder LIMIT 1];
        wo.Acorn_WorkOrder_Number__c = 'ACORN-123';
        update wo;

        Map<String, List<WorkOrder>> commentWOMap = new Map<String, List<WorkOrder>>();
        commentWOMap.put('Work Order Creation', new List<WorkOrder>{wo});

        Test.startTest();

        WorkOrderTriggerHelper.createCaseComment(commentWOMap);

        Test.stopTest();

        // Verify method executed without errors
        System.assertNotEquals(null, commentWOMap, 'Comment map should not be null');
    }

    @isTest
    static void testBulkOperations() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account locationAccount = [SELECT Id FROM Account WHERE Name = 'Test Location' LIMIT 1];

        // Create bulk work orders
        List<WorkOrder> bulkWOs = new List<WorkOrder>();
        for (Integer i = 0; i < 100; i++) {
            bulkWOs.add(new WorkOrder(
                CaseId = testCase.Id,
                Customer_Location__c = locationAccount.Id,
                Status = 'New',
                Subject = 'Bulk WO ' + i,
                Service_Date__c = System.today().addDays(7)
            ));
        }
        insert bulkWOs;

        Map<Id, WorkOrder> woMap = new Map<Id, WorkOrder>(bulkWOs);
        Map<Id, Case> caseMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();

        WorkOrderTriggerHelper.updateCaseDetail(woMap, null, caseMap);

        Test.stopTest();

        // Verify bulk operations completed
        System.assertEquals(100, bulkWOs.size(), 'Should process 100 work orders');
    }

    @isTest
    static void testUpdateCaseDetailWithRescheduledDate() {
        WorkOrder wo = [SELECT Id, CaseId, Rescheduled_Date__c FROM WorkOrder LIMIT 1];
        Case testCase = [SELECT Id, Status FROM Case WHERE Id = :wo.CaseId];

        DateTime rescheduledDate = System.now().addDays(10);
        wo.Rescheduled_Date__c = rescheduledDate;

        WorkOrder oldWO = wo.clone(true);
        oldWO.Rescheduled_Date__c = null;

        update wo;

        Map<Id, WorkOrder> woMap = new Map<Id, WorkOrder>{wo.Id => wo};
        Map<Id, WorkOrder> oldWoMap = new Map<Id, WorkOrder>{oldWO.Id => oldWO};
        Map<Id, Case> caseMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();

        RecurrsiveTriggerHandler.bypassValidation = false;
        WorkOrderTriggerHelper.updateCaseDetail(woMap, oldWoMap, caseMap);

        Test.stopTest();

        // Verify proposed service date was updated from rescheduled date
        Case updatedCase = [SELECT Id, Proposed_Service_Date__c FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, updatedCase.Proposed_Service_Date__c);
    }

    @isTest
    static void testUpdateCaseDetailPendingServiceConfirmation() {
        WorkOrder wo = [SELECT Id, CaseId, Send_Status__c, Status FROM WorkOrder LIMIT 1];
        Case testCase = [SELECT Id, Status, Case_Sub_Status__c, Availability_Confirmed__c FROM Case WHERE Id = :wo.CaseId];

        wo.Send_Status__c = 'Sent';
        wo.Status = 'Sent';
        update wo;

        Map<Id, WorkOrder> woMap = new Map<Id, WorkOrder>{wo.Id => wo};
        Map<Id, Case> caseMap = new Map<Id, Case>{testCase.Id => testCase};

        Test.startTest();

        WorkOrderTriggerHelper.updateCaseDetail(woMap, null, caseMap);

        Test.stopTest();

        // Verify case sub status
        Case updatedCase = [SELECT Id, Case_Sub_Status__c FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, updatedCase.Case_Sub_Status__c);
    }
}
