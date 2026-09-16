@IsTest
private class CreateFormActivityController_Test {

    private static Integer sequenceNumber = 0;

    @IsTest
    static void testGetStoresAndSalesExecutives() {
        Store__c storeOne = createStore('Create Activity Store One');
        Store__c storeTwo = createStore('Create Activity Store Two');

        Sales_Executives__c executiveOne =
            createExecutive(storeOne.Id, 'Executive One');
        Sales_Executives__c executiveTwo =
            createExecutive(storeTwo.Id, 'Executive Two');

        Test.startTest();

        List<CreateFormActivityController.OptionWrapper> stores =
            CreateFormActivityController.getStores();

        List<CreateFormActivityController.SalesExecutiveOptionWrapper>
            executives =
                CreateFormActivityController.getSalesExecutivesByStores(
                    new List<Id>{
                        storeOne.Id,
                        storeTwo.Id,
                        storeOne.Id,
                        null
                    }
                );

        List<CreateFormActivityController.SalesExecutiveOptionWrapper>
            emptyForNull =
                CreateFormActivityController.getSalesExecutivesByStores(null);

        List<CreateFormActivityController.SalesExecutiveOptionWrapper>
            emptyForEmpty =
                CreateFormActivityController.getSalesExecutivesByStores(
                    new List<Id>()
                );

        Test.stopTest();

        Set<String> storeValues = new Set<String>();
        for (CreateFormActivityController.OptionWrapper optionRecord : stores) {
            storeValues.add(optionRecord.value);
        }

        System.assert(
            storeValues.contains(String.valueOf(storeOne.Id)),
            'Store One should be returned.'
        );
        System.assert(
            storeValues.contains(String.valueOf(storeTwo.Id)),
            'Store Two should be returned.'
        );

        Set<String> executiveValues = new Set<String>();
        for (
            CreateFormActivityController.SalesExecutiveOptionWrapper optionRecord :
                executives
        ) {
            executiveValues.add(optionRecord.value);
        }

        System.assert(
            executiveValues.contains(String.valueOf(executiveOne.Id)),
            'Executive One should be returned.'
        );
        System.assert(
            executiveValues.contains(String.valueOf(executiveTwo.Id)),
            'Executive Two should be returned.'
        );
        System.assertEquals(0, emptyForNull.size());
        System.assertEquals(0, emptyForEmpty.size());
    }

    @IsTest
    static void testCreateActivitySuccess() {
        Store__c storeRecord = createStore('Success Store');
        Sales_Executives__c executiveRecord =
            createExecutive(storeRecord.Id, 'Success Executive');
        Final_Customize_Form__c finalForm =
            createFinalForm(storeRecord.Id);

        Date startDate = Date.today();
        Date endDate = Date.today().addDays(2);

        CreateFormActivityController.StoreLocationWrapper location =
            new CreateFormActivityController.StoreLocationWrapper();
        location.storeId = String.valueOf(storeRecord.Id);
        location.activityLocation = 'LOCATION A';

        CreateFormActivityController.SalesExecutiveAssignmentWrapper assignment =
            new CreateFormActivityController.SalesExecutiveAssignmentWrapper();
        assignment.salesExecutiveId = String.valueOf(executiveRecord.Id);
        assignment.assignedDates = new List<String>{
            String.valueOf(startDate),
            String.valueOf(startDate.addDays(1)),
            String.valueOf(startDate.addDays(1))
        };

        Test.startTest();

        List<Id> activityIds =
            CreateFormActivityController.createActivity(
                finalForm.Id,
                new List<Id>{
                    storeRecord.Id,
                    storeRecord.Id,
                    null
                },
                'BTL Test Activity',
                startDate,
                endDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    location,
                    null
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    assignment,
                    null
                }
            );

        Test.stopTest();

        System.assertEquals(1, activityIds.size());

        Form_Activity__c createdActivity = [
            SELECT Id,
                   Final_Customize_Form__c,
                   Assigned_Store__c,
                   Activity_Name__c,
                   Activity_Date__c,
                   Activity_End_Date__c,
                   Activity_Location__c
            FROM Form_Activity__c
            WHERE Id = :activityIds[0]
        ];

        System.assertEquals(finalForm.Id, createdActivity.Final_Customize_Form__c);
        System.assertEquals(storeRecord.Id, createdActivity.Assigned_Store__c);
        System.assertEquals('BTL Test Activity', createdActivity.Activity_Name__c);
        System.assertEquals(startDate, createdActivity.Activity_Date__c);
        System.assertEquals(endDate, createdActivity.Activity_End_Date__c);
        System.assertEquals('LOCATION A', createdActivity.Activity_Location__c);

        List<Form_Activity_Assigned_Persons__c> assignedPersons = [
            SELECT Id,
                   Form_Activity__c,
                   Store__c,
                   Sales_Executives__c,
                   Person_Name__c
            FROM Form_Activity_Assigned_Persons__c
            WHERE Form_Activity__c = :createdActivity.Id
        ];

        System.assertEquals(1, assignedPersons.size());
        System.assertEquals(
            executiveRecord.Id,
            assignedPersons[0].Sales_Executives__c
        );

        List<Form_Activity_Assigned_Persons_Date__c> dateRows = [
            SELECT Id,
                   Form_Activity_Assigned_Persons__c,
                   Target_Date__c
            FROM Form_Activity_Assigned_Persons_Date__c
            WHERE Form_Activity_Assigned_Persons__c =
                :assignedPersons[0].Id
            ORDER BY Target_Date__c
        ];

        System.assertEquals(
            2,
            dateRows.size(),
            'Duplicate assigned dates must be removed.'
        );
        System.assertEquals(startDate, dateRows[0].Target_Date__c);
        System.assertEquals(startDate.addDays(1), dateRows[1].Target_Date__c);
    }

    @IsTest
    static void testCreateActivityForMultipleStores() {
        Store__c storeOne = createStore('Multi Store One');
        Store__c storeTwo = createStore('Multi Store Two');

        Sales_Executives__c executiveOne =
            createExecutive(storeOne.Id, 'Multi Executive One');
        Sales_Executives__c executiveTwo =
            createExecutive(storeTwo.Id, 'Multi Executive Two');

        Final_Customize_Form__c finalForm =
            createFinalForm(storeOne.Id);

        Date activityDate = Date.today();
        Date activityEndDate = Date.today().addDays(1);

        CreateFormActivityController.StoreLocationWrapper locationOne =
            new CreateFormActivityController.StoreLocationWrapper();
        locationOne.storeId = String.valueOf(storeOne.Id);
        locationOne.activityLocation = 'STORE ONE LOCATION';

        CreateFormActivityController.StoreLocationWrapper locationTwo =
            new CreateFormActivityController.StoreLocationWrapper();
        locationTwo.storeId = String.valueOf(storeTwo.Id);
        locationTwo.activityLocation = 'STORE TWO LOCATION';

        CreateFormActivityController.SalesExecutiveAssignmentWrapper assignmentOne =
            new CreateFormActivityController.SalesExecutiveAssignmentWrapper();
        assignmentOne.salesExecutiveId = String.valueOf(executiveOne.Id);
        assignmentOne.assignedDates = new List<String>{
            String.valueOf(activityDate)
        };

        CreateFormActivityController.SalesExecutiveAssignmentWrapper assignmentTwo =
            new CreateFormActivityController.SalesExecutiveAssignmentWrapper();
        assignmentTwo.salesExecutiveId = String.valueOf(executiveTwo.Id);
        assignmentTwo.assignedDates = new List<String>{
            String.valueOf(activityEndDate)
        };

        Test.startTest();

        List<Id> activityIds =
            CreateFormActivityController.createActivity(
                finalForm.Id,
                new List<Id>{ storeOne.Id, storeTwo.Id },
                'Multi Store Activity',
                activityDate,
                activityEndDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    locationOne,
                    locationTwo
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    assignmentOne,
                    assignmentTwo
                }
            );

        Test.stopTest();

        System.assertEquals(2, activityIds.size());

        List<Form_Activity__c> createdActivities = [
            SELECT Id, Assigned_Store__c, Activity_Location__c
            FROM Form_Activity__c
            WHERE Id IN :activityIds
        ];

        System.assertEquals(2, createdActivities.size());

        Integer assignedPersonsCount = [
            SELECT COUNT()
            FROM Form_Activity_Assigned_Persons__c
            WHERE Form_Activity__c IN :activityIds
        ];

        System.assertEquals(2, assignedPersonsCount);
    }

    @IsTest
    static void testRequiredFieldValidationBranches() {
        Store__c storeRecord = createStore('Validation Store');
        Sales_Executives__c executiveRecord =
            createExecutive(storeRecord.Id, 'Validation Executive');
        Final_Customize_Form__c finalForm =
            createFinalForm(storeRecord.Id);

        Date startDate = Date.today();
        Date endDate = Date.today().addDays(1);

        CreateFormActivityController.StoreLocationWrapper location =
            new CreateFormActivityController.StoreLocationWrapper();
        location.storeId = String.valueOf(storeRecord.Id);
        location.activityLocation = 'VALIDATION LOCATION';

        CreateFormActivityController.SalesExecutiveAssignmentWrapper assignment =
            new CreateFormActivityController.SalesExecutiveAssignmentWrapper();
        assignment.salesExecutiveId = String.valueOf(executiveRecord.Id);
        assignment.assignedDates = new List<String>{
            String.valueOf(startDate)
        };

        assertAuraException(
            new ValidationAction(
                null,
                new List<Id>{ storeRecord.Id },
                'Activity',
                startDate,
                endDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    location
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    assignment
                }
            )
        );

        assertAuraException(
            new ValidationAction(
                finalForm.Id,
                new List<Id>{ storeRecord.Id },
                '   ',
                startDate,
                endDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    location
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    assignment
                }
            )
        );

        assertAuraException(
            new ValidationAction(
                finalForm.Id,
                new List<Id>{ storeRecord.Id },
                'Activity',
                null,
                endDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    location
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    assignment
                }
            )
        );

        assertAuraException(
            new ValidationAction(
                finalForm.Id,
                new List<Id>{ storeRecord.Id },
                'Activity',
                startDate,
                null,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    location
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    assignment
                }
            )
        );

        assertAuraException(
            new ValidationAction(
                finalForm.Id,
                new List<Id>{ storeRecord.Id },
                'Activity',
                endDate,
                startDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    location
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    assignment
                }
            )
        );

        assertAuraException(
            new ValidationAction(
                finalForm.Id,
                new List<Id>(),
                'Activity',
                startDate,
                endDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    location
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    assignment
                }
            )
        );

        assertAuraException(
            new ValidationAction(
                finalForm.Id,
                new List<Id>{ storeRecord.Id },
                'Activity',
                startDate,
                endDate,
                null,
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    assignment
                }
            )
        );

        assertAuraException(
            new ValidationAction(
                finalForm.Id,
                new List<Id>{ storeRecord.Id },
                'Activity',
                startDate,
                endDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    location
                },
                null
            )
        );
    }

    @IsTest
    static void testSalesExecutiveAndDateValidationBranches() {
        Store__c storeOne = createStore('Exec Validation One');
        Store__c storeTwo = createStore('Exec Validation Two');

        Sales_Executives__c executiveOne =
            createExecutive(storeOne.Id, 'Exec Validation Executive One');

        Final_Customize_Form__c finalForm =
            createFinalForm(storeOne.Id);

        Date startDate = Date.today();
        Date endDate = Date.today().addDays(2);

        CreateFormActivityController.StoreLocationWrapper locationOne =
            new CreateFormActivityController.StoreLocationWrapper();
        locationOne.storeId = String.valueOf(storeOne.Id);
        locationOne.activityLocation = 'LOCATION ONE';

        CreateFormActivityController.StoreLocationWrapper locationTwo =
            new CreateFormActivityController.StoreLocationWrapper();
        locationTwo.storeId = String.valueOf(storeTwo.Id);
        locationTwo.activityLocation = 'LOCATION TWO';

        CreateFormActivityController.SalesExecutiveAssignmentWrapper noDates =
            new CreateFormActivityController.SalesExecutiveAssignmentWrapper();
        noDates.salesExecutiveId = String.valueOf(executiveOne.Id);
        noDates.assignedDates = new List<String>();

        assertAuraException(
            new ValidationAction(
                finalForm.Id,
                new List<Id>{ storeOne.Id },
                'Activity',
                startDate,
                endDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    locationOne
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    noDates
                }
            )
        );

        CreateFormActivityController.SalesExecutiveAssignmentWrapper invalidDate =
            new CreateFormActivityController.SalesExecutiveAssignmentWrapper();
        invalidDate.salesExecutiveId = String.valueOf(executiveOne.Id);
        invalidDate.assignedDates = new List<String>{ 'NOT-A-DATE' };

        assertAuraException(
            new ValidationAction(
                finalForm.Id,
                new List<Id>{ storeOne.Id },
                'Activity',
                startDate,
                endDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    locationOne
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    invalidDate
                }
            )
        );

        CreateFormActivityController.SalesExecutiveAssignmentWrapper outsideDate =
            new CreateFormActivityController.SalesExecutiveAssignmentWrapper();
        outsideDate.salesExecutiveId = String.valueOf(executiveOne.Id);
        outsideDate.assignedDates = new List<String>{
            String.valueOf(endDate.addDays(1))
        };

        assertAuraException(
            new ValidationAction(
                finalForm.Id,
                new List<Id>{ storeOne.Id },
                'Activity',
                startDate,
                endDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    locationOne
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    outsideDate
                }
            )
        );

        CreateFormActivityController.SalesExecutiveAssignmentWrapper validAssignment =
            new CreateFormActivityController.SalesExecutiveAssignmentWrapper();
        validAssignment.salesExecutiveId = String.valueOf(executiveOne.Id);
        validAssignment.assignedDates = new List<String>{
            String.valueOf(startDate)
        };

        // Executive belongs to storeOne, but selected store is storeTwo.
        assertAuraException(
            new ValidationAction(
                finalForm.Id,
                new List<Id>{ storeTwo.Id },
                'Activity',
                startDate,
                endDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    locationTwo
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    validAssignment
                }
            )
        );

        // Two stores selected, but only storeOne has an executive.
        assertAuraException(
            new ValidationAction(
                finalForm.Id,
                new List<Id>{ storeOne.Id, storeTwo.Id },
                'Activity',
                startDate,
                endDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    locationOne,
                    locationTwo
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    validAssignment
                }
            )
        );
    }

    @IsTest
    static void testInvalidWrapperIds() {
        Store__c storeRecord = createStore('Invalid Wrapper Store');
        Sales_Executives__c executiveRecord =
            createExecutive(storeRecord.Id, 'Invalid Wrapper Executive');
        Final_Customize_Form__c finalForm =
            createFinalForm(storeRecord.Id);

        Date selectedDate = Date.today();

        CreateFormActivityController.StoreLocationWrapper invalidLocation =
            new CreateFormActivityController.StoreLocationWrapper();
        invalidLocation.storeId = 'INVALID-ID';
        invalidLocation.activityLocation = 'LOCATION';

        CreateFormActivityController.SalesExecutiveAssignmentWrapper validExecutive =
            new CreateFormActivityController.SalesExecutiveAssignmentWrapper();
        validExecutive.salesExecutiveId = String.valueOf(executiveRecord.Id);
        validExecutive.assignedDates = new List<String>{
            String.valueOf(selectedDate)
        };

        assertAuraException(
            new ValidationAction(
                finalForm.Id,
                new List<Id>{ storeRecord.Id },
                'Activity',
                selectedDate,
                selectedDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    invalidLocation
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    validExecutive
                }
            )
        );

        CreateFormActivityController.StoreLocationWrapper validLocation =
            new CreateFormActivityController.StoreLocationWrapper();
        validLocation.storeId = String.valueOf(storeRecord.Id);
        validLocation.activityLocation = 'LOCATION';

        CreateFormActivityController.SalesExecutiveAssignmentWrapper invalidExecutive =
            new CreateFormActivityController.SalesExecutiveAssignmentWrapper();
        invalidExecutive.salesExecutiveId = 'INVALID-ID';
        invalidExecutive.assignedDates = new List<String>{
            String.valueOf(selectedDate)
        };

        assertAuraException(
            new ValidationAction(
                finalForm.Id,
                new List<Id>{ storeRecord.Id },
                'Activity',
                selectedDate,
                selectedDate,
                new List<CreateFormActivityController.StoreLocationWrapper>{
                    validLocation
                },
                new List<CreateFormActivityController.SalesExecutiveAssignmentWrapper>{
                    invalidExecutive
                }
            )
        );
    }

    /*
     * Small wrapper so the validation tests remain readable.
     */
    private class ValidationAction {
        Id finalFormId;
        List<Id> storeIds;
        String activityName;
        Date startDate;
        Date endDate;
        List<CreateFormActivityController.StoreLocationWrapper> locations;
        List<CreateFormActivityController.SalesExecutiveAssignmentWrapper> assignments;

        ValidationAction(
            Id finalFormId,
            List<Id> storeIds,
            String activityName,
            Date startDate,
            Date endDate,
            List<CreateFormActivityController.StoreLocationWrapper> locations,
            List<CreateFormActivityController.SalesExecutiveAssignmentWrapper> assignments
        ) {
            this.finalFormId = finalFormId;
            this.storeIds = storeIds;
            this.activityName = activityName;
            this.startDate = startDate;
            this.endDate = endDate;
            this.locations = locations;
            this.assignments = assignments;
        }

        void execute() {
            CreateFormActivityController.createActivity(
                finalFormId,
                storeIds,
                activityName,
                startDate,
                endDate,
                locations,
                assignments
            );
        }
    }

    private static void assertAuraException(ValidationAction action) {
        Boolean exceptionThrown = false;

        try {
            action.execute();
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }

        System.assertEquals(
            true,
            exceptionThrown,
            'Expected AuraHandledException was not thrown.'
        );
    }

    private static Store__c createStore(String requestedName) {
        Store__c record = new Store__c();
        setField(record, 'Name', requestedName);

        insertRecord(
            record,
            new Map<String, Id>{
                'User' => UserInfo.getUserId()
            }
        );

        return record;
    }

    private static Sales_Executives__c createExecutive(
        Id storeId,
        String requestedName
    ) {
        Sales_Executives__c record = new Sales_Executives__c();

        setField(record, 'Name', requestedName);
        setField(record, 'Store__c', storeId);

        insertRecord(
            record,
            new Map<String, Id>{
                'Store__c' => storeId,
                'User' => UserInfo.getUserId()
            }
        );

        return record;
    }

    private static Final_Customize_Form__c createFinalForm(Id storeId) {
        Final_Customize_Form__c record = new Final_Customize_Form__c();

        setField(record, 'Name', 'Test Final Form ' + uniqueToken());
        setField(record, 'Store__c', storeId);

        insertRecord(
            record,
            new Map<String, Id>{
                'Store__c' => storeId,
                'User' => UserInfo.getUserId()
            }
        );

        return record;
    }

    private static void insertRecord(
        SObject record,
        Map<String, Id> referenceDefaults
    ) {
        populateRequiredFields(record, referenceDefaults);
        insert record;
    }

    private static void populateRequiredFields(
        SObject record,
        Map<String, Id> referenceDefaults
    ) {
        Map<String, Schema.SObjectField> fieldMap =
            record.getSObjectType().getDescribe().fields.getMap();

        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult description =
                fieldMap.get(fieldName).getDescribe();

            if (
                !description.isCreateable() ||
                description.isCalculated() ||
                description.isAutoNumber() ||
                description.isNillable() ||
                description.isDefaultedOnCreate() ||
                record.get(fieldName) != null
            ) {
                continue;
            }

            String typeName =
                String.valueOf(description.getType()).toUpperCase();

            if (typeName == 'REFERENCE') {
                Id referenceId =
                    resolveReference(description, referenceDefaults);

                if (referenceId != null) {
                    record.put(fieldName, referenceId);
                }
            } else if (typeName == 'BOOLEAN') {
                record.put(fieldName, false);
            } else if (typeName == 'DATE') {
                record.put(fieldName, Date.today());
            } else if (typeName == 'DATETIME') {
                record.put(fieldName, System.now());
            } else if (typeName == 'TIME') {
                record.put(
                    fieldName,
                    Time.newInstance(9, 0, 0, 0)
                );
            } else if (
                typeName == 'INTEGER' ||
                typeName == 'DOUBLE' ||
                typeName == 'CURRENCY' ||
                typeName == 'PERCENT' ||
                typeName == 'LONG'
            ) {
                record.put(fieldName, 1);
            } else if (
                typeName == 'PICKLIST' ||
                typeName == 'MULTIPICKLIST' ||
                typeName == 'COMBOBOX'
            ) {
                String value = firstActiveValue(description);

                if (value != null) {
                    record.put(fieldName, value);
                }
            } else if (typeName == 'EMAIL') {
                record.put(
                    fieldName,
                    fitLength(
                        'test.' + uniqueToken() + '@example.com',
                        description.getLength()
                    )
                );
            } else if (typeName == 'PHONE') {
                record.put(fieldName, '9999999999');
            } else if (typeName == 'URL') {
                record.put(fieldName, 'https://example.com');
            } else if (typeName == 'BASE64') {
                record.put(fieldName, Blob.valueOf('Test'));
            } else if (
                typeName == 'STRING' ||
                typeName == 'TEXTAREA' ||
                typeName == 'ENCRYPTEDSTRING'
            ) {
                record.put(
                    fieldName,
                    fitLength(
                        'Test ' + fieldName + ' ' + uniqueToken(),
                        description.getLength()
                    )
                );
            }
        }
    }

    private static Id resolveReference(
        Schema.DescribeFieldResult description,
        Map<String, Id> referenceDefaults
    ) {
        for (
            Schema.SObjectType referencedType :
                description.getReferenceTo()
        ) {
            String apiName =
                referencedType.getDescribe().getName();

            if (
                referenceDefaults != null &&
                referenceDefaults.containsKey(apiName)
            ) {
                return referenceDefaults.get(apiName);
            }

            if (apiName == 'User') {
                return UserInfo.getUserId();
            }
        }

        return null;
    }

    private static void setField(
        SObject record,
        String fieldName,
        Object value
    ) {
        if (value == null) {
            return;
        }

        Map<String, Schema.SObjectField> fieldMap =
            record.getSObjectType().getDescribe().fields.getMap();

        if (!fieldMap.containsKey(fieldName)) {
            return;
        }

        Schema.DescribeFieldResult description =
            fieldMap.get(fieldName).getDescribe();

        if (
            !description.isCreateable() ||
            description.isCalculated() ||
            description.isAutoNumber()
        ) {
            return;
        }

        if (
            String.valueOf(description.getType()).toUpperCase() ==
                'PICKLIST' ||
            String.valueOf(description.getType()).toUpperCase() ==
                'MULTIPICKLIST' ||
            String.valueOf(description.getType()).toUpperCase() ==
                'COMBOBOX'
        ) {
            String requestedValue = String.valueOf(value);

            for (
                Schema.PicklistEntry entry :
                    description.getPicklistValues()
            ) {
                if (
                    entry.isActive() &&
                    entry.getValue() == requestedValue
                ) {
                    record.put(fieldName, requestedValue);
                    return;
                }
            }

            String fallbackValue = firstActiveValue(description);

            if (fallbackValue != null) {
                record.put(fieldName, fallbackValue);
            }

            return;
        }

        record.put(fieldName, value);
    }

    private static String firstActiveValue(
        Schema.DescribeFieldResult description
    ) {
        for (
            Schema.PicklistEntry entry :
                description.getPicklistValues()
        ) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }

        return null;
    }

    private static String fitLength(
        String value,
        Integer maximumLength
    ) {
        if (
            value == null ||
            maximumLength == null ||
            maximumLength <= 0 ||
            value.length() <= maximumLength
        ) {
            return value;
        }

        return value.substring(0, maximumLength);
    }

    private static String uniqueToken() {
        sequenceNumber++;

        return String.valueOf(DateTime.now().getTime()) +
            '-' +
            String.valueOf(sequenceNumber);
    }
}