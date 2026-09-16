public with sharing class Ctrl_PushEstimateToBC {
    
    public class LineItemWrapper {
        @AuraEnabled public Id lineItemId;
        @AuraEnabled public String barcode;
        @AuraEnabled public String salesExecutiveCode;
        @AuraEnabled public String salesExecutiveName;
        @AuraEnabled public Decimal finalPrice;
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String status;
        @AuraEnabled public String documentNo;
    }

    public class CalloutResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String documentNo;
        @AuraEnabled public String errorMessage;
    }

    @AuraEnabled
    public static List<LineItemWrapper> getLineItemsForProcessing(Id orderId) {
        List<LineItemWrapper> wrapperList = new List<LineItemWrapper>();

        Customer_Order__c order = [SELECT Id, BC_Customer_No__c, Location_Code__c,
                                   (SELECT Id, Barcode_Value__c, Sales_Executive_Code__c, 
                                           Sales_Executive_Name__c, Final_Price__c, BC_Document_No__c 
                                    FROM Customer_Order_Line_Items__r WHERE Line_Item_Status_On_Salesforce__c != 'Removed' AND Line_Item_Status_On_Salesforce__c != 'Back To Available Wishlist Item') 
                                   FROM Customer_Order__c WHERE Id = :orderId LIMIT 1];

        for (Customer_Order_Line_Item__c item : order.Customer_Order_Line_Items__r) {
            LineItemWrapper wrapper = new LineItemWrapper();
            wrapper.lineItemId = item.Id;
            wrapper.barcode = item.Barcode_Value__c;
            wrapper.salesExecutiveCode = item.Sales_Executive_Code__c;
            wrapper.salesExecutiveName = item.Sales_Executive_Name__c;
            wrapper.finalPrice = item.Final_Price__c;
            wrapper.documentNo = item.BC_Document_No__c;
            
            // 1. Check if it's already processed
            if (String.isNotBlank(item.BC_Document_No__c)) {
                wrapper.isValid = false; 
                wrapper.status = 'Synced';
                wrapper.errorMessage = 'Item already pushed to BC.';
            } else {
                // 2. Validation Logic for unprocessed items
                List<String> missingFields = new List<String>();
                
                if (String.isBlank(item.Sales_Executive_Code__c)) missingFields.add('Exec Code');
                if (String.isBlank(order.Location_Code__c)) missingFields.add('Location');
                if (String.isBlank(order.BC_Customer_No__c)) missingFields.add('BC Customer No');
                if (String.isBlank(item.Barcode_Value__c)) missingFields.add('Barcode');

                if (!missingFields.isEmpty()) {
                    wrapper.isValid = false;
                    wrapper.status = 'Validation Error';
                    wrapper.errorMessage = 'Missing: ' + String.join(missingFields, ', ');
                } else {
                    wrapper.isValid = true;
                    wrapper.status = 'Pending';
                    wrapper.errorMessage = '';
                }
            }
            
            wrapperList.add(wrapper);
        }
        
        return wrapperList;
    }

    @AuraEnabled
    public static CalloutResult pushSingleLineItemToBC(Id lineItemId) {
        CalloutResult result = new CalloutResult();
        result.isSuccess = false;
        
        try {
            // Updated SOQL to pull Location, Pre_Document_No__c, Name (Estimation No) directly from the parent
            Customer_Order_Line_Item__c item = [
                SELECT Id, Barcode_Value__c, Sales_Executive_Code__c, Sales_Executive_Name__c, 
                       Customer_Order__c, 
                       Customer_Order__r.Name,
                       Customer_Order__r.BC_Customer_No__c,
                       Customer_Order__r.Location_Code__c,
                       Customer_Order__r.Pre_Document_No__c
                FROM Customer_Order_Line_Item__c 
                WHERE Id = :lineItemId LIMIT 1
            ];

            Map<String, Object> reqBody = new Map<String, Object>();
            reqBody.put('salespersonCode', item.Sales_Executive_Code__c);
            reqBody.put('location', item.Customer_Order__r.Location_Code__c); 
            reqBody.put('customerCode', item.Customer_Order__r.BC_Customer_No__c);
            reqBody.put('scanTagNo', item.Barcode_Value__c);
            
            // Dynamically pass Pre_Document_No__c or an empty string for the first call
            String currentDocNo = String.isNotBlank(item.Customer_Order__r.Pre_Document_No__c) ? item.Customer_Order__r.Pre_Document_No__c : '';
            reqBody.put('documentNo', currentDocNo);
            
            // Add SalesForceOrderNo using the Estimation Number format
            reqBody.put('salesForceOrderNo', item.Customer_Order__r.Name);

            String endpoint = 'callout:Orient_API_Access_NC/' + System.Label.BC_Endpoint + '/EstimateHeaderAPIJRS';

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setBody(JSON.serialize(reqBody));
            req.setTimeout(120000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                if (responseMap.containsKey('documentNo')) {
                    String docNo = String.valueOf(responseMap.get('documentNo'));
                    result.documentNo = docNo;
                    result.isSuccess = true;
                    
                    // Update Customer Order with Pre_Document_No__c if it was empty initially
                    if (String.isBlank(item.Customer_Order__r.Pre_Document_No__c)) {
                        Customer_Order__c parentUpdate = new Customer_Order__c(
                            Id = item.Customer_Order__c,
                            Pre_Document_No__c = docNo
                        );
                        update parentUpdate;
                    }
                    
                    // Update Line Item
                    item.BC_Document_No__c = docNo;
                    item.Line_Item_Status_On_Salesforce__c = 'Sent To ERP - PRE';
                    update item;
                } else {
                    result.errorMessage = 'Success response received but "documentNo" missing.';
                    IntegrationLogger.logError('Ctrl_PushEstimateToBC', 'pushSingleLineItemToBC', 80, res.getStatusCode(), 'Barcode: ' + item.Barcode_Value__c + ' | Error: ' + result.errorMessage, 'EstimateHeaderAPIJRS');
                }
            } else {
                result.errorMessage = 'API Error: ' + res.getStatus() + ' - ' + res.getBody();
                IntegrationLogger.logError('Ctrl_PushEstimateToBC', 'pushSingleLineItemToBC', 85, res.getStatusCode(), 'Barcode: ' + item.Barcode_Value__c + ' | Error: ' + result.errorMessage, 'EstimateHeaderAPIJRS');
            }
        } catch (Exception e) {
            result.errorMessage = 'Exception: ' + e.getMessage();
            IntegrationLogger.logError('Ctrl_PushEstimateToBC', 'pushSingleLineItemToBC', 90, 500, result.errorMessage, 'EstimateHeaderAPIJRS');
        }
        
        return result;
    }
}