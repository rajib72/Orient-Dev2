public class FDB_IntegrationLogger {
    
    // Method to log integration callouts with success/error events and null checking
    public static void logCallout(String className, String methodName, Integer lineNumber, Integer statusCode, String errorMessage, String apiType, Boolean isSuccess, String requestJson, String responseBody, String endpoint, String httpMethod, Long startTimeMs, Long durationMs, String stackTrace) {
        
        Integration_Result__c log = new Integration_Result__c();
        if (className != null) log.Apex_Class_Name__c = className;
        if (methodName != null) log.Method_Name__c = methodName;
        if (lineNumber != null) log.Line_Number__c = lineNumber;
        if (statusCode != null) log.Status_Code__c = statusCode;
        
        if (String.isNotBlank(errorMessage)) {
            log.Error_Message__c = errorMessage.length() > 32768 ? errorMessage.substring(0, 32765) + '...' : errorMessage;
        }
        
        if (String.isNotBlank(stackTrace)) {
            log.Stack_Trace__c = stackTrace.length() > 32768 ? stackTrace.substring(0, 32765) + '...' : stackTrace;
        }
        
        if (apiType != null) log.API_Type__c = apiType;
        if (isSuccess != null) log.Success__c = isSuccess;
        
        if (String.isNotBlank(requestJson)) {
            log.Request_JSON__c = requestJson.length() > 131072 ? requestJson.substring(0, 131069) + '...' : requestJson;
        }
        
        if (String.isNotBlank(responseBody)) {
            log.Response_Body__c = responseBody.length() > 131072 ? responseBody.substring(0, 131069) + '...' : responseBody;
        }
        
        if (endpoint != null) log.Endpoint__c = endpoint;
        if (httpMethod != null) log.HTTP_Method__c = httpMethod;
        if (durationMs != null) log.Duration_Milliseconds__c = durationMs;
        if (isSuccess != null) {
            log.Log_Status__c = isSuccess ? 'Success' : 'Failed';
        }
        
        if (startTimeMs != null) {
            log.Request_Date_Time__c = Datetime.newInstance(startTimeMs);
            if (durationMs != null) {
                log.Response_Date_Time__c = Datetime.newInstance(startTimeMs + durationMs);
            }
        }
        
        try {
            insert log;
        } catch (Exception e) {
            System.debug('CRITICAL: Failed to write to Integration_Result__c. Error: ' + e.getMessage());
        }
    }
}