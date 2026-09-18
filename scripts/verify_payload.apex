Id custId = '001C400000XfqnBIAR';
Ctrl_PurchaseBehaviourInsights.CustomerInsightPayload payload = 
    Ctrl_PurchaseBehaviourInsights.getCustomerInsightsPayload(custId);

System.debug('Customer Name: ' + payload.customer.customerName);
System.debug('Total Categories: ' + payload.totalCategoriesCount);
System.debug('Active Categories: ' + payload.activeCategoriesCount);
System.debug('Total Fields Across Active Records: ' + payload.totalFieldsCount);

for (Ctrl_PurchaseBehaviourInsights.InsightCategory cat : payload.categories) {
    System.debug('Module: ' + cat.objectLabel + ' [' + cat.shortCode + '] - Has Record: ' + cat.hasRecord + ', Record ID: ' + cat.recordId + ', Populated Fields: ' + cat.fieldCount);
}
