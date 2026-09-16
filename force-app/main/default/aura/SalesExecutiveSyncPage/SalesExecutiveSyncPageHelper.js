({
    runSync : function(component) {
        var helper = this;

        component.set("v.isLoading", true);
        component.set("v.message", "Starting sync...");

        var action = component.get("c.syncSalesExecutives");

        action.setCallback(this, function(response) {
            component.set("v.isLoading", false);

            var state = response.getState();

            if (state === "SUCCESS") {
                var result = response.getReturnValue();
                component.set("v.message", result.message);

                var toast = $A.get("e.force:showToast");
                if (toast) {
                    toast.setParams({
                        title: "Success",
                        message: result.message,
                        type: "success"
                    });
                    toast.fire();
                }
            } else {
                var errors = response.getError();
                var msg = "Unknown error";

                if (errors && errors.length > 0 && errors[0].message) {
                    msg = errors[0].message;
                }

                component.set("v.message", msg);

                var toastError = $A.get("e.force:showToast");
                if (toastError) {
                    toastError.setParams({
                        title: "Error",
                        message: msg,
                        type: "error"
                    });
                    toastError.fire();
                }
            }
        });

        $A.enqueueAction(action);
    }
})