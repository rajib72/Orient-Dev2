/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : ctrl_ManageFormActivityPersonsController
 * Author          : <Amit>
 * Created Date    : May 27, 2026
 * Last Modified By: <Amit>
 * Last Modified On: May 27, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  May 27, 2026  │ <Amit>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class ctrl_ManageFormActivityPersonsController {

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getFormActivities(Id finalCustomizeFormId) {
        List<OptionWrapper> options = new List<OptionWrapper>();

        if (finalCustomizeFormId == null) {
            return options;
        }

        List<Form_Activity__c> activityList = [
            SELECT Id, Name, Activity_Date__c, Assigned_Store__c, Assigned_Store__r.Name
            FROM Form_Activity__c
            WHERE Final_Customize_Form__c = :finalCustomizeFormId
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];

        for (Form_Activity__c act : activityList) {
            String label = act.Name;

            if (act.Activity_Date__c != null) {
                label += ' - ' + String.valueOf(act.Activity_Date__c);
            }

            if (act.Assigned_Store__r != null) {
                label += ' - ' + act.Assigned_Store__r.Name;
            }

            options.add(new OptionWrapper(String.valueOf(act.Id), label));
        }

        return options;
    }

    @AuraEnabled
    public static ActivityDetailWrapper getActivityDetails(Id formActivityId) {
        ActivityDetailWrapper response = new ActivityDetailWrapper();
        response.assignedPersons = new List<AssignedPersonWrapper>();
        response.availableExecutives = new List<ExecutiveWrapper>();

        if (formActivityId == null) {
            return response;
        }

        Form_Activity__c activity = [
            SELECT Id, Name, Assigned_Store__c, Assigned_Store__r.Name
            FROM Form_Activity__c
            WHERE Id = :formActivityId
            LIMIT 1
        ];

        response.formActivityId = activity.Id;
        response.formActivityName = activity.Name;
        response.storeId = activity.Assigned_Store__c;
        response.storeName = activity.Assigned_Store__r != null ? activity.Assigned_Store__r.Name : '';

        Set<Id> alreadyAssignedExecutiveIds = new Set<Id>();

        List<Form_Activity_Assigned_Persons__c> assignedList = [
            SELECT Id, Name, Person_Name__c, Sales_Executives__c, Sales_Executives__r.Name,
                   Store__c, Store__r.Name, Form_Activity__c
            FROM Form_Activity_Assigned_Persons__c
            WHERE Form_Activity__c = :formActivityId
            ORDER BY CreatedDate DESC
        ];

        for (Form_Activity_Assigned_Persons__c person : assignedList) {
            AssignedPersonWrapper wrapper = new AssignedPersonWrapper();
            wrapper.id = person.Id;
            wrapper.recordName = person.Name;
            wrapper.personName = person.Person_Name__c;
            wrapper.salesExecutiveId = person.Sales_Executives__c;
            wrapper.salesExecutiveName = person.Sales_Executives__r != null ? person.Sales_Executives__r.Name : '';
            wrapper.storeId = person.Store__c;
            wrapper.storeName = person.Store__r != null ? person.Store__r.Name : '';

            response.assignedPersons.add(wrapper);

            if (person.Sales_Executives__c != null) {
                alreadyAssignedExecutiveIds.add(person.Sales_Executives__c);
            }
        }

        if (activity.Assigned_Store__c != null) {
            List<Sales_Executives__c> executiveList = [
                SELECT Id, Name
                FROM Sales_Executives__c
                WHERE Store__c = :activity.Assigned_Store__c
                ORDER BY Name ASC
                LIMIT 500
            ];

            for (Sales_Executives__c executiveRecord : executiveList) {
                ExecutiveWrapper ex = new ExecutiveWrapper();
                ex.id = executiveRecord.Id;
                ex.name = executiveRecord.Name;
                ex.alreadyAssigned = alreadyAssignedExecutiveIds.contains(executiveRecord.Id);

                response.availableExecutives.add(ex);
            }
        }

        return response;
    }

    @AuraEnabled
    public static void addAssignedPersons(
        Id formActivityId,
        Id storeId,
        List<Id> salesExecutiveIds
    ) {
        if (formActivityId == null) {
            throw new AuraHandledException('Please select Form Activity.');
        }

        if (storeId == null) {
            throw new AuraHandledException('Store is missing for selected activity.');
        }

        if (salesExecutiveIds == null || salesExecutiveIds.isEmpty()) {
            throw new AuraHandledException('Please select at least one Sales Executive.');
        }

        Set<Id> incomingExecutiveIds = new Set<Id>(salesExecutiveIds);
        Set<Id> existingExecutiveIds = new Set<Id>();

        List<Form_Activity_Assigned_Persons__c> existingList = [
            SELECT Id, Sales_Executives__c
            FROM Form_Activity_Assigned_Persons__c
            WHERE Form_Activity__c = :formActivityId
            AND Sales_Executives__c IN :incomingExecutiveIds
        ];

        for (Form_Activity_Assigned_Persons__c existingPerson : existingList) {
            if (existingPerson.Sales_Executives__c != null) {
                existingExecutiveIds.add(existingPerson.Sales_Executives__c);
            }
        }

        List<Sales_Executives__c> executives = [
            SELECT Id, Name
            FROM Sales_Executives__c
            WHERE Id IN :incomingExecutiveIds
        ];

        List<Form_Activity_Assigned_Persons__c> personsToInsert = new List<Form_Activity_Assigned_Persons__c>();

        for (Sales_Executives__c ex : executives) {
            if (!existingExecutiveIds.contains(ex.Id)) {
                Form_Activity_Assigned_Persons__c person = new Form_Activity_Assigned_Persons__c();
                person.Form_Activity__c = formActivityId;
                person.Store__c = storeId;
                person.Sales_Executives__c = ex.Id;
                person.Person_Name__c = ex.Name;

                personsToInsert.add(person);
            }
        }

        if (!personsToInsert.isEmpty()) {
            insert personsToInsert;
        }
    }

    @AuraEnabled
    public static void deleteAssignedPerson(Id assignedPersonId) {
        if (assignedPersonId == null) {
            throw new AuraHandledException('Assigned person record id is missing.');
        }

        List<Form_Activity_Assigned_Persons__c> recordsToDelete = [
            SELECT Id
            FROM Form_Activity_Assigned_Persons__c
            WHERE Id = :assignedPersonId
            LIMIT 1
        ];

        if (!recordsToDelete.isEmpty()) {
            delete recordsToDelete;
        }
    }

    public class OptionWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public OptionWrapper(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }

    public class ActivityDetailWrapper {
        @AuraEnabled public Id formActivityId;
        @AuraEnabled public String formActivityName;
        @AuraEnabled public Id storeId;
        @AuraEnabled public String storeName;
        @AuraEnabled public List<AssignedPersonWrapper> assignedPersons;
        @AuraEnabled public List<ExecutiveWrapper> availableExecutives;
    }

    public class AssignedPersonWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String recordName;
        @AuraEnabled public String personName;
        @AuraEnabled public Id salesExecutiveId;
        @AuraEnabled public String salesExecutiveName;
        @AuraEnabled public Id storeId;
        @AuraEnabled public String storeName;
    }

    public class ExecutiveWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Boolean alreadyAssigned;
    }
}