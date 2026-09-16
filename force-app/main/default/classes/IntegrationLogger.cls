public class IntegrationLogger {
    
    // Method to log callout errors or Apex exceptions
    public static void logError(String className, String methodName, Integer lineNumber, Integer statusCode, String errorMessage, String apiType) {
        
        Integration_Result__c log = new Integration_Result__c();
        log.Apex_Class_Name__c = className;
        log.Method_Name__c = methodName;
        log.Line_Number__c = lineNumber;
        log.Status_Code__c = statusCode;
        
        // Truncate the message just in case it somehow exceeds the Long Text Area limit
        if (String.isNotBlank(errorMessage) && errorMessage.length() > 32768) {
            log.Error_Message__c = errorMessage.substring(0, 32765) + '...';
        } else {
            log.Error_Message__c = errorMessage;
        }
        
        log.API_Type__c = apiType;
        
        try {
            insert log;
        } catch (Exception e) {
            // Failsafe: If the logger fails, output to debug log so it isn't lost completely
            System.debug('CRITICAL: Failed to write to Integration_Result__c. Error: ' + e.getMessage());
        }
    }
}