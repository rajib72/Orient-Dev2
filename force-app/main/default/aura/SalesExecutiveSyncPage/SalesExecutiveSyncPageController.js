({
    doInit : function(component, event, helper) {
        helper.runSync(component);
    },

    doSync : function(component, event, helper) {
        helper.runSync(component);
    },

    handleCancel : function(component, event, helper) {

        var navService = component.find("navService");

        navService.navigate({
            type: "standard__objectPage",
            attributes: {
                objectApiName: "Sales_Executives__c",
                actionName: "list"
            },
            state: {
                filterName: "Recent"
            }
        });
    }
})