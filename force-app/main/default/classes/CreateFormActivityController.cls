/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : CreateFormActivityController
 * Author          : <Amit>
 * Created Date    : May 26, 2026
 * Description     : This class is used to create Form Activity records and assigned sales executives.
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class CreateFormActivityController {

    private static final String ASSIGNED_PERSON_DATE_OBJECT_API = 'Form_Activity_Assigned_Persons_Date__c';
    private static final String ASSIGNED_PERSON_DATE_PARENT_FIELD_API = 'Form_Activity_Assigned_Persons__c';
    private static final String ASSIGNED_PERSON_TARGET_DATE_FIELD_API = 'Target_Date__c';

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getStores() {
        List<OptionWrapper> options = new List<OptionWrapper>();

        for (Store__c st : [
            SELECT Id, Name
            FROM Store__c
            ORDER BY Name ASC
            LIMIT 500
        ]) {
            options.add(new OptionWrapper(String.valueOf(st.Id), st.Name));
        }

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<SalesExecutiveOptionWrapper> getSalesExecutivesByStores(List<Id> storeIds) {
        List<SalesExecutiveOptionWrapper> options = new List<SalesExecutiveOptionWrapper>();

        Set<Id> storeIdSet = new Set<Id>();

        if (storeIds != null) {
            for (Id storeId : storeIds) {
                if (storeId != null) {
                    storeIdSet.add(storeId);
                }
            }
        }

        if (storeIdSet.isEmpty()) {
            return options;
        }

        for (Sales_Executives__c se : [
            SELECT Id, Name, Store__c, Store__r.Name
            FROM Sales_Executives__c
            WHERE Store__c IN :storeIdSet
            ORDER BY Store__r.Name ASC, Name ASC
            LIMIT 1000
        ]) {
            options.add(
                new SalesExecutiveOptionWrapper(
                    String.valueOf(se.Id),
                    se.Name,
                    String.valueOf(se.Store__c),
                    se.Store__r != null ? se.Store__r.Name : ''
                )
            );
        }

        return options;
    }

    @AuraEnabled
    public static List<Id> createActivity(
        Id finalCustomizeFormId,
        List<Id> assignedStoreIds,
        String activityName,
        Date activityDate,
        Date activityEndDate,
        List<StoreLocationWrapper> storeLocationAssignments,
        List<SalesExecutiveAssignmentWrapper> salesExecutiveAssignments
    ) {
        if (finalCustomizeFormId == null) {
            throw new AuraHandledException('Final Customize Form record id is missing.');
        }

        if (String.isBlank(activityName)) {
            throw new AuraHandledException('Please enter Activity Name.');
        }

        if (activityDate == null) {
            throw new AuraHandledException('Please enter Activity Start Date.');
        }

        if (activityEndDate == null) {
            throw new AuraHandledException('Please enter Activity End Date.');
        }

        if (activityEndDate < activityDate) {
            throw new AuraHandledException('Activity End Date cannot be before Activity Start Date.');
        }

        List<Id> finalStoreIds = new List<Id>();
        Set<Id> storeIdSet = new Set<Id>();

        if (assignedStoreIds != null) {
            for (Id storeId : assignedStoreIds) {
                if (storeId != null && !storeIdSet.contains(storeId)) {
                    storeIdSet.add(storeId);
                    finalStoreIds.add(storeId);
                }
            }
        }

        if (finalStoreIds.isEmpty()) {
            throw new AuraHandledException('Please select at least one Assigned Store.');
        }

        Map<Id, Store__c> storeMap = new Map<Id, Store__c>([
            SELECT Id, Name
            FROM Store__c
            WHERE Id IN :storeIdSet
        ]);

        Map<Id, String> activityLocationByStoreId = new Map<Id, String>();

        if (storeLocationAssignments != null) {
            for (StoreLocationWrapper locationWrapper : storeLocationAssignments) {
                if (locationWrapper == null || String.isBlank(locationWrapper.storeId)) {
                    continue;
                }

                Id locationStoreId;

                try {
                    locationStoreId = (Id) locationWrapper.storeId;
                } catch (Exception ex) {
                    throw new AuraHandledException('Invalid Store found for Activity Location.');
                }

                if (storeIdSet.contains(locationStoreId)) {
                    activityLocationByStoreId.put(
                        locationStoreId,
                        locationWrapper.activityLocation
                    );
                }
            }
        }

        List<String> missingLocationStoreNames = new List<String>();

        for (Id storeId : finalStoreIds) {
            if (String.isBlank(activityLocationByStoreId.get(storeId))) {
                missingLocationStoreNames.add(
                    storeMap.containsKey(storeId) ? storeMap.get(storeId).Name : String.valueOf(storeId)
                );
            }
        }

        if (!missingLocationStoreNames.isEmpty()) {
            throw new AuraHandledException(
                'Please enter Activity Location for Store(s): ' +
                String.join(missingLocationStoreNames, ', ')
            );
        }

        if (salesExecutiveAssignments == null || salesExecutiveAssignments.isEmpty()) {
            throw new AuraHandledException('Please select at least one Sales Executive.');
        }

        Set<Id> selectedExecutiveIdSet = new Set<Id>();
        Map<Id, List<Date>> assignedDatesByExecutiveId = new Map<Id, List<Date>>();

        for (SalesExecutiveAssignmentWrapper assignment : salesExecutiveAssignments) {
            if (assignment == null || String.isBlank(assignment.salesExecutiveId)) {
                continue;
            }

            Id executiveId;

            try {
                executiveId = (Id) assignment.salesExecutiveId;
            } catch (Exception ex) {
                throw new AuraHandledException('Invalid Sales Executive selected.');
            }

            if (assignment.assignedDates == null || assignment.assignedDates.isEmpty()) {
                throw new AuraHandledException('Please select Target Date(s) for all selected Sales Executives.');
            }

            List<Date> targetDates = new List<Date>();
            Set<Date> uniqueDateSet = new Set<Date>();

            for (String dateText : assignment.assignedDates) {
                if (String.isBlank(dateText)) {
                    continue;
                }

                Date targetDate;

                try {
                    targetDate = Date.valueOf(dateText);
                } catch (Exception ex) {
                    throw new AuraHandledException('Invalid Target Date selected.');
                }

                if (targetDate < activityDate || targetDate > activityEndDate) {
                    throw new AuraHandledException('Target Date(s) must be between Activity Start Date and Activity End Date.');
                }

                if (!uniqueDateSet.contains(targetDate)) {
                    uniqueDateSet.add(targetDate);
                    targetDates.add(targetDate);
                }
            }

            if (targetDates.isEmpty()) {
                throw new AuraHandledException('Please select Target Date(s) for all selected Sales Executives.');
            }

            selectedExecutiveIdSet.add(executiveId);
            assignedDatesByExecutiveId.put(executiveId, targetDates);
        }

        if (selectedExecutiveIdSet.isEmpty()) {
            throw new AuraHandledException('Please select at least one Sales Executive.');
        }

        List<Sales_Executives__c> selectedExecutives = [
            SELECT Id, Name, Store__c, Store__r.Name
            FROM Sales_Executives__c
            WHERE Id IN :selectedExecutiveIdSet
            AND Store__c IN :storeIdSet
        ];

        if (selectedExecutives.size() != selectedExecutiveIdSet.size()) {
            throw new AuraHandledException('One or more selected Sales Executives do not belong to the selected Stores.');
        }

        Map<Id, List<Sales_Executives__c>> executivesByStoreId = new Map<Id, List<Sales_Executives__c>>();

        for (Sales_Executives__c executiveRecord : selectedExecutives) {
            if (!executivesByStoreId.containsKey(executiveRecord.Store__c)) {
                executivesByStoreId.put(executiveRecord.Store__c, new List<Sales_Executives__c>());
            }

            executivesByStoreId.get(executiveRecord.Store__c).add(executiveRecord);
        }

        List<String> missingExecutiveStoreNames = new List<String>();

        for (Id storeId : finalStoreIds) {
            if (
                !executivesByStoreId.containsKey(storeId) ||
                executivesByStoreId.get(storeId).isEmpty()
            ) {
                missingExecutiveStoreNames.add(
                    storeMap.containsKey(storeId) ? storeMap.get(storeId).Name : String.valueOf(storeId)
                );
            }
        }

        if (!missingExecutiveStoreNames.isEmpty()) {
            throw new AuraHandledException(
                'Please select at least one Sales Executive for each selected Store. Missing Store(s): ' +
                String.join(missingExecutiveStoreNames, ', ')
            );
        }

        Schema.SObjectType dateObjectType =
            Schema.getGlobalDescribe().get(ASSIGNED_PERSON_DATE_OBJECT_API);

        if (dateObjectType == null) {
            throw new AuraHandledException(
                'Date child object not found. Please check API name: ' +
                ASSIGNED_PERSON_DATE_OBJECT_API
            );
        }

        Map<String, Schema.SObjectField> dateFieldMap =
            dateObjectType.getDescribe().fields.getMap();

        if (!dateFieldMap.containsKey(ASSIGNED_PERSON_DATE_PARENT_FIELD_API)) {
            throw new AuraHandledException(
                'Parent lookup field not found on date child object. Please check API name: ' +
                ASSIGNED_PERSON_DATE_PARENT_FIELD_API
            );
        }

        if (!dateFieldMap.containsKey(ASSIGNED_PERSON_TARGET_DATE_FIELD_API)) {
            throw new AuraHandledException(
                'Target Date field not found on date child object. Please check API name: ' +
                ASSIGNED_PERSON_TARGET_DATE_FIELD_API
            );
        }

        List<Form_Activity__c> activitiesToInsert = new List<Form_Activity__c>();

        for (Id storeId : finalStoreIds) {
            Form_Activity__c act = new Form_Activity__c();
            act.Final_Customize_Form__c = finalCustomizeFormId;
            act.Assigned_Store__c = storeId;
            act.Activity_Name__c = activityName;
            act.Activity_Date__c = activityDate;
            act.Activity_End_Date__c = activityEndDate;
            act.Activity_Location__c = activityLocationByStoreId.get(storeId);

            activitiesToInsert.add(act);
        }

        insert activitiesToInsert;

        List<Form_Activity_Assigned_Persons__c> assignedPersonsToInsert =
            new List<Form_Activity_Assigned_Persons__c>();

        for (Form_Activity__c activityRecord : activitiesToInsert) {
            List<Sales_Executives__c> executivesForStore =
                executivesByStoreId.get(activityRecord.Assigned_Store__c);

            if (executivesForStore != null) {
                for (Sales_Executives__c executiveRecord : executivesForStore) {
                    Form_Activity_Assigned_Persons__c person =
                        new Form_Activity_Assigned_Persons__c();

                    person.Form_Activity__c = activityRecord.Id;
                    person.Store__c = activityRecord.Assigned_Store__c;
                    person.Sales_Executives__c = executiveRecord.Id;
                    person.Person_Name__c = executiveRecord.Name;

                    assignedPersonsToInsert.add(person);
                }
            }
        }

        if (!assignedPersonsToInsert.isEmpty()) {
            insert assignedPersonsToInsert;
        }

        List<SObject> assignedPersonDateRows = new List<SObject>();

        for (Form_Activity_Assigned_Persons__c personRecord : assignedPersonsToInsert) {
            List<Date> targetDates =
                assignedDatesByExecutiveId.get(personRecord.Sales_Executives__c);

            if (targetDates != null) {
                for (Date targetDate : targetDates) {
                    SObject dateRow = dateObjectType.newSObject();

                    dateRow.put(
                        ASSIGNED_PERSON_DATE_PARENT_FIELD_API,
                        personRecord.Id
                    );

                    dateRow.put(
                        ASSIGNED_PERSON_TARGET_DATE_FIELD_API,
                        targetDate
                    );

                    assignedPersonDateRows.add(dateRow);
                }
            }
        }

        if (!assignedPersonDateRows.isEmpty()) {
            insert assignedPersonDateRows;
        }

        List<Id> createdActivityIds = new List<Id>();

        for (Form_Activity__c activityRecord : activitiesToInsert) {
            createdActivityIds.add(activityRecord.Id);
        }

        return createdActivityIds;
    }

    public class OptionWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public OptionWrapper(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }

    public class SalesExecutiveOptionWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String storeId;
        @AuraEnabled public String storeName;

        public SalesExecutiveOptionWrapper(
            String value,
            String label,
            String storeId,
            String storeName
        ) {
            this.value = value;
            this.label = label;
            this.storeId = storeId;
            this.storeName = storeName;
        }
    }

    public class StoreLocationWrapper {
        @AuraEnabled public String storeId { get; set; }
        @AuraEnabled public String activityLocation { get; set; }
    }

    public class SalesExecutiveAssignmentWrapper {
        @AuraEnabled public String salesExecutiveId { get; set; }
        @AuraEnabled public List<String> assignedDates { get; set; }
    }
}