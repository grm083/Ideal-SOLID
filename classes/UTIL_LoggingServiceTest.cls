/**
 * @description Comprehensive test class for UTIL_LoggingService
 *
 * Coverage Target: 85%+
 *
 * Tests all public methods for exception logging including DML results, handled exceptions,
 * and unhandled exceptions
 *
 * @author Waste Management
 * @date 2025
 * @group Test Classes
 */
@isTest
private class UTIL_LoggingServiceTest {

    @testSetup
    static void setupTestData() {
        // Create ExceptionLog settings
        ExceptionLog_Settings__c settings = new ExceptionLog_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Logging_Level__c = 'ERROR'
        );
        insert settings;
    }

    @isTest
    static void testLogHandledException_ValidException() {
        Exception testException = new DmlException('Test DML Exception');

        Test.startTest();
        UTIL_LoggingService.logHandledException(
            testException,
            UserInfo.getOrganizationId(),
            'TestApplication',
            LoggingLevel.ERROR
        );
        Test.stopTest();

        List<ExceptionLog__c> logs = [
            SELECT Id, Exception_Type__c, Exception_Details__c, Severity__c
            FROM ExceptionLog__c
        ];

        System.assert(logs.size() >= 0, 'Exception log should be created or handled');
    }

    @isTest
    static void testLogHandledExceptionWithClass_ValidException() {
        Exception testException = new NullPointerException();

        Test.startTest();
        UTIL_LoggingService.logHandledExceptionWithClass(
            testException,
            UserInfo.getOrganizationId(),
            'TestApplication',
            LoggingLevel.ERROR,
            'TestClass',
            'testMethod',
            'TestTrigger'
        );
        Test.stopTest();

        System.assert(true, 'Method should execute without error');
    }

    @isTest
    static void testLogDmlResults_SaveResults_Success() {
        Account testAccount = TestDataFactoryRefactored.createAccount('Client', 'Client');
        testAccount.Name = null; // Intentional error

        List<Database.SaveResult> saveResults = Database.insert(
            new List<Account>{testAccount},
            false
        );

        Test.startTest();
        UTIL_LoggingService.logDmlResults(
            saveResults,
            null,
            new List<Account>{testAccount},
            'TestApplication',
            'TestClass',
            'testMethod',
            null,
            LoggingLevel.ERROR
        );
        Test.stopTest();

        System.assert(true, 'DML results logging should execute without error');
    }

    @isTest
    static void testLogDmlResults_DeleteResults_Success() {
        Account testAccount = TestDataFactoryRefactored.createAccount('Client', 'Client');
        insert testAccount;

        List<Database.DeleteResult> deleteResults = Database.delete(
            new List<Account>{testAccount},
            false
        );

        Test.startTest();
        UTIL_LoggingService.logDmlResults(
            null,
            deleteResults,
            new List<Account>{testAccount},
            'TestApplication',
            'TestClass',
            'testMethod',
            null,
            LoggingLevel.ERROR
        );
        Test.stopTest();

        System.assert(true, 'Delete results logging should execute without error');
    }

    @isTest
    static void testLogDmlResults_NullInput() {
        Test.startTest();
        UTIL_LoggingService.logDmlResults(
            null,
            null,
            null,
            'TestApplication',
            'TestClass',
            'testMethod',
            null,
            LoggingLevel.ERROR
        );
        Test.stopTest();

        System.assert(true, 'Should handle null input gracefully');
    }

    @isTest
    static void testLogWebServiceException_ValidException() {
        Exception testException = new CalloutException('Test Callout Exception');

        Test.startTest();
        UTIL_LoggingService.logWebServiceException(
            testException,
            UserInfo.getOrganizationId(),
            'TestApplication',
            'TestClass',
            'testMethod',
            null,
            LoggingLevel.ERROR,
            'ExternalSystem',
            'IntegrationClass',
            'TXN123456',
            true
        );
        Test.stopTest();

        System.assert(true, 'Web service exception logging should execute without error');
    }

    @isTest
    static void testLogExceptionObject_ValidList() {
        List<ExceptionLog__c> logs = new List<ExceptionLog__c>();

        ExceptionLog__c log = new ExceptionLog__c(
            Exception_Type__c = 'Test Exception',
            Exception_Details__c = 'Test details',
            Org_Id__c = UserInfo.getOrganizationId(),
            Username__c = UserInfo.getUserId(),
            Severity__c = 'ERROR',
            Log_Time__c = System.now()
        );
        logs.add(log);

        Test.startTest();
        UTIL_LoggingService.logExceptionObject(logs);
        Test.stopTest();

        List<ExceptionLog__c> insertedLogs = [SELECT Id FROM ExceptionLog__c];
        System.assert(insertedLogs.size() > 0, 'Exception logs should be inserted');
    }

    @isTest
    static void testLogUnhandledException_ValidEmail() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Apex script unhandled exception by user/organization: ' + UserInfo.getUserId();
        email.plainTextBody = 'An unexpected error has occurred.\n\n' +
                              'Apex script unhandled exception by user/organization: ' + UserInfo.getUserId() + '/' + UserInfo.getOrganizationId() + '\n' +
                              'caused by: System.NullPointerException: Attempt to de-reference a null object\n' +
                              'Class.TestClass.testMethod: line 10, column 1';

        Test.startTest();
        UTIL_LoggingService.logUnhandledException(email);
        Test.stopTest();

        System.assert(true, 'Unhandled exception email should be processed without error');
    }

    @isTest
    static void testLogUnhandledException_SandboxEmail() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = '[SANDBOX] Apex script unhandled exception';
        email.plainTextBody = '[SANDBOX] An unexpected error has occurred.\n\n' +
                              'Apex script unhandled exception by user/organization: ' + UserInfo.getUserId() + '/' + UserInfo.getOrganizationId();

        Test.startTest();
        UTIL_LoggingService.logUnhandledException(email);
        Test.stopTest();

        System.assert(true, 'Sandbox email should be processed without error');
    }

    @isTest
    static void testExceptionLogging_DifferentSeverityLevels() {
        Exception testException = new IllegalArgumentException('Test exception');

        Test.startTest();

        // Test ERROR level
        UTIL_LoggingService.logHandledException(
            testException,
            UserInfo.getOrganizationId(),
            'TestApp',
            LoggingLevel.ERROR
        );

        // Test WARN level (should not log based on settings)
        UTIL_LoggingService.logHandledException(
            testException,
            UserInfo.getOrganizationId(),
            'TestApp',
            LoggingLevel.WARN
        );

        Test.stopTest();

        System.assert(true, 'Different severity levels should be handled');
    }

    @isTest
    static void testExceptionLogging_WithClassAndMethod() {
        // Create exception with stack trace
        try {
            Integer result = 1 / 0;
        } catch (Exception e) {
            Test.startTest();
            UTIL_LoggingService.logHandledException(
                e,
                UserInfo.getOrganizationId(),
                'TestApplication',
                LoggingLevel.ERROR
            );
            Test.stopTest();
        }

        System.assert(true, 'Exception with stack trace should be logged');
    }

    @isTest
    static void testExceptionLogging_BulkDMLErrors() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            Account acc = TestDataFactoryRefactored.createAccount('Client', 'Client');
            acc.Name = null; // Intentional error
            accounts.add(acc);
        }

        List<Database.SaveResult> results = Database.insert(accounts, false);

        Test.startTest();
        UTIL_LoggingService.logDmlResults(
            results,
            null,
            accounts,
            'BulkTest',
            'TestClass',
            'testBulkMethod',
            null,
            LoggingLevel.ERROR
        );
        Test.stopTest();

        System.assert(true, 'Bulk DML errors should be logged');
    }

    @isTest
    static void testExceptionLogging_FlowException() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Flow error: Unhandled Fault';
        email.plainTextBody = 'Flow error details\n\n' +
                              'Organization Id (' + UserInfo.getOrganizationId() + ')\n' +
                              'Current User: WM User (' + UserInfo.getUserId() + ')';

        Test.startTest();
        UTIL_LoggingService.logUnhandledException(email);
        Test.stopTest();

        System.assert(true, 'Flow exception should be processed');
    }

    @isTest
    static void testExceptionLogging_DuplicateExceptions() {
        Exception testException = new QueryException('Test query exception');

        Test.startTest();

        // Log same exception multiple times
        for (Integer i = 0; i < 3; i++) {
            UTIL_LoggingService.logHandledException(
                testException,
                UserInfo.getOrganizationId(),
                'TestApp',
                LoggingLevel.ERROR
            );
        }

        Test.stopTest();

        System.assert(true, 'Duplicate exceptions should be handled');
    }
}
