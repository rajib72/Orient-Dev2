@isTest
private class FDB_IntegrationLoggerTest {

    @isTest
    static void testLogCallout_Success() {
        Test.startTest();
        Long startTime = System.now().getTime();
        FDB_IntegrationLogger.logCallout(
            'TestClass', 
            'testMethod', 
            42, 
            200, 
            null, 
            'TestAPI', 
            true, 
            '{"req":"data"}', 
            '{"res":"data"}', 
            'https://example.com/api', 
            'POST', 
            startTime, 
            150L, 
            null
        );
        Test.stopTest();

        List<Integration_Result__c> logs = [
            SELECT Id, Apex_Class_Name__c, Method_Name__c, Line_Number__c, Status_Code__c, 
                   API_Type__c, Success__c, Request_JSON__c, Response_Body__c, Endpoint__c, 
                   HTTP_Method__c, Duration_Milliseconds__c, Log_Status__c, Request_Date_Time__c, 
                   Response_Date_Time__c 
            FROM Integration_Result__c
        ];
        
        System.assertEquals(1, logs.size(), 'One log should be inserted');
        Integration_Result__c log = logs[0];
        System.assertEquals('TestClass', log.Apex_Class_Name__c);
        System.assertEquals('testMethod', log.Method_Name__c);
        System.assertEquals(42, log.Line_Number__c);
        System.assertEquals(200, log.Status_Code__c);
        System.assertEquals('TestAPI', log.API_Type__c);
        System.assertEquals(true, log.Success__c);
        System.assertEquals('{"req":"data"}', log.Request_JSON__c);
        System.assertEquals('{"res":"data"}', log.Response_Body__c);
        System.assertEquals('https://example.com/api', log.Endpoint__c);
        System.assertEquals('POST', log.HTTP_Method__c);
        System.assertEquals(150, log.Duration_Milliseconds__c);
        System.assertEquals('Success', log.Log_Status__c);
        System.assertEquals(Datetime.newInstance(startTime), log.Request_Date_Time__c);
        System.assertEquals(Datetime.newInstance(startTime + 150), log.Response_Date_Time__c);
    }

    @isTest
    static void testLogCallout_Error() {
        Test.startTest();
        FDB_IntegrationLogger.logCallout(
            'TestClass', 
            'testMethodError', 
            null, 
            500, 
            'Internal Server Error', 
            'TestAPI', 
            false, 
            null, 
            null, 
            null, 
            null, 
            null, 
            null, 
            'System.Exception: Something went wrong'
        );
        Test.stopTest();

        List<Integration_Result__c> logs = [
            SELECT Id, Log_Status__c, Error_Message__c, Stack_Trace__c, Success__c 
            FROM Integration_Result__c
        ];
        
        System.assertEquals(1, logs.size(), 'One log should be inserted');
        Integration_Result__c log = logs[0];
        System.assertEquals('Failed', log.Log_Status__c);
        System.assertEquals('Internal Server Error', log.Error_Message__c);
        System.assertEquals('System.Exception: Something went wrong', log.Stack_Trace__c);
        System.assertEquals(false, log.Success__c);
    }

    @isTest
    static void testLogCallout_Truncation() {
        // Build very large strings to hit the limits
        String longError = 'E'.repeat(33000);
        String longStack = 'S'.repeat(33000);
        String longReq = 'R'.repeat(132000);
        String longRes = 'P'.repeat(132000);
        
        Test.startTest();
        FDB_IntegrationLogger.logCallout(
            'TestClass', 
            'testTruncation', 
            1, 
            400, 
            longError, 
            'TestAPI', 
            false, 
            longReq, 
            longRes, 
            'https://example.com/api', 
            'GET', 
            System.now().getTime(), 
            50L, 
            longStack
        );
        Test.stopTest();

        List<Integration_Result__c> logs = [
            SELECT Id, Error_Message__c, Stack_Trace__c, Request_JSON__c, Response_Body__c 
            FROM Integration_Result__c
        ];
        
        System.assertEquals(1, logs.size(), 'One log should be inserted');
        Integration_Result__c log = logs[0];
        
        System.assertEquals(32768, log.Error_Message__c.length(), 'Error message should be truncated to max length');
        System.assert(log.Error_Message__c.endsWith('...'), 'Truncated error message should end with ...');
        
        System.assertEquals(32768, log.Stack_Trace__c.length(), 'Stack trace should be truncated to max length');
        System.assert(log.Stack_Trace__c.endsWith('...'), 'Truncated stack trace should end with ...');
        
        System.assertEquals(131072, log.Request_JSON__c.length(), 'Request JSON should be truncated to max length');
        System.assert(log.Request_JSON__c.endsWith('...'), 'Truncated request JSON should end with ...');
        
        System.assertEquals(131072, log.Response_Body__c.length(), 'Response Body should be truncated to max length');
        System.assert(log.Response_Body__c.endsWith('...'), 'Truncated response body should end with ...');
    }
}