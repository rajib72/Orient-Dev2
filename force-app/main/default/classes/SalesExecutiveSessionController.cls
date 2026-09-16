public with sharing class SalesExecutiveSessionController {
    
    /* ================= DTO ================= */
    public class SessionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public Id salesExecutiveId;
        @AuraEnabled public String salesExecutiveName;
        @AuraEnabled public String status;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Time startTime;
        @AuraEnabled public Date endDate;
        @AuraEnabled public Time endTime;
        @AuraEnabled public String durationText;
        @AuraEnabled public String previousDuration;
        
        public SessionDTO(Sales_Executive_Activity_Tracking__c s) {
            id = s.Id;
            salesExecutiveId = s.Sales_Executive__c;
            salesExecutiveName =
                s.Sales_Executive__r != null ? s.Sales_Executive__r.Name : '';
            status = s.Session_Status__c;
            startDate = s.Session_Starting_Date__c;
            startTime = s.Session_Start_Time__c;
            endDate = s.Session_End_Date__c;
            endTime = s.Session_End_Time__c;
            durationText = s.Duration_Text__c;
            previousDuration = s.Previous_Duration__c;
        }
    }
    
    /* ================= FETCH SESSIONS ================= */
    @AuraEnabled
    public static List<SessionDTO> getSessions(Id showroomVisitId) {
        if (showroomVisitId == null) {
            return new List<SessionDTO>();
        }
        
        List<Sales_Executive_Activity_Tracking__c> records = [
            SELECT Id,
                   Sales_Executive__c,
                   Sales_Executive__r.Name,
                   Session_Status__c,
                   Session_Starting_Date__c,
                   Session_Start_Time__c,
                   Session_End_Date__c,
                   Session_End_Time__c,
                   Duration_Text__c,
                   Previous_Duration__c
            FROM Sales_Executive_Activity_Tracking__c
            WHERE Showroom_Visit__c = :showroomVisitId
            ORDER BY CreatedDate ASC
        ];
        
        List<SessionDTO> result = new List<SessionDTO>();
        for (Sales_Executive_Activity_Tracking__c r : records) {
            result.add(new SessionDTO(r));
        }
        return result;
    }
    
    /* ================= FETCH SALES EXECUTIVES BY STORE ================= */
    @AuraEnabled(cacheable=true)
    public static List<Sales_Executives__c> getSalesExecutivesByShowroom(
        Id showroomVisitId
    ) {
        if (showroomVisitId == null) {
            return new List<Sales_Executives__c>();
        }
        
        Showroom_Visit__c sv = [
            SELECT StoreLookup__c
            FROM Showroom_Visit__c
            WHERE Id = :showroomVisitId
            LIMIT 1
        ];
        
        if (sv.StoreLookup__c == null) {
            return new List<Sales_Executives__c>();
        }
        
        return [
            SELECT Id, Name
            FROM Sales_Executives__c
            WHERE Store__c = :sv.StoreLookup__c
            ORDER BY Name
        ];
    }
    
    /* ================= SESSION HANDOVER ================= */
    @AuraEnabled
    public static void handoverSession(
        Id showroomVisitId,
        Id newSalesExecutiveId
    ) {
        if (showroomVisitId == null) {
            throw new AuraHandledException('Showroom Visit is required.');
        }
        
        if (newSalesExecutiveId == null) {
            throw new AuraHandledException('Please select Sales Executive.');
        }
        
        Date todayDate = System.today();

        DateTime currentDateTime = DateTime.now();
        System.debug('Current Date Time: ' + currentDateTime);
        
        /*
         * IMPORTANT:
         * Do not manually add timezone offset here.
         * Manual offset caused 4:11 PM to become 9:41 PM.
         */
        Time nowTime = getCurrentUserTime();
        
        // Close active session
        List<Sales_Executive_Activity_Tracking__c> activeSessions = [
            SELECT Id,
                   Sales_Executive__c,
                   Sales_Executive__r.Name,
                   Session_Start_Date_Time__c,
                   Session_End_Date_Time__c,
                   Actual_Start_Date_Time__c,
                   Actual_End_Date_Time__c,
                   Session_Starting_Date__c,
                   Session_Start_Time__c,
                   Session_Status__c,
                   Duration_Text__c,
                   Previous_Duration__c
            FROM Sales_Executive_Activity_Tracking__c
            WHERE Showroom_Visit__c = :showroomVisitId
            AND Session_Status__c = 'Active'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        if (!activeSessions.isEmpty()) {
            Sales_Executive_Activity_Tracking__c oldSession = activeSessions[0];

            /*
             * NEW VALIDATION:
             * Active Sales Executive and selected handover Sales Executive
             * cannot be the same person.
             */
            if (oldSession.Sales_Executive__c == newSalesExecutiveId) {
                throw new AuraHandledException(
                    'You cannot handover to the same active Sales Executive.'
                );
            }
            
            oldSession.Session_Status__c = 'Completed';
            oldSession.Actual_End_Date_Time__c = currentDateTime;

            oldSession.Session_End_Time__c = nowTime;
            
            String handoverDuration = calculateDurationHHMMSS(
                oldSession.Session_Starting_Date__c,
                oldSession.Session_Start_Time__c,
                todayDate,
                nowTime
            );
            
            oldSession.Duration_Text__c = handoverDuration;
            oldSession.Previous_Duration__c = handoverDuration;
            
            update oldSession;
        }
        
        // Create new active session
        Sales_Executive_Activity_Tracking__c newSession =
            new Sales_Executive_Activity_Tracking__c(
                Showroom_Visit__c = showroomVisitId,
                Sales_Executive__c = newSalesExecutiveId,
                Session_Status__c = 'Active',
                Session_Start_Date_Time__c = currentDateTime,
                Actual_Start_Date_Time__c = currentDateTime,
                Session_Starting_Date__c = todayDate,
                Session_Start_Time__c = nowTime
            );
        
        insert newSession;
    }
    
    /* ================= MARK EXIT ================= */
    @AuraEnabled
    public static void markSessionExit(
        Id showroomVisitId,
        Date endDateValue,
        String endTimeValue,
        String previousDurationValue
    ) {
        closeActiveSession(
            showroomVisitId,
            endDateValue,
            endTimeValue,
            previousDurationValue
        );
    }
    
    /* ================= MARK EXIT WITH FOLLOW UP ================= */
    @AuraEnabled
    public static void markSessionExitWithFollowUp(
        Id showroomVisitId,
        Date endDateValue,
        String endTimeValue,
        String previousDurationValue,
        Date followUpDate
    ) {
        if (followUpDate == null) {
            throw new AuraHandledException('Please select Next Follow Up Date.');
        }

        /*
         * NEW VALIDATION:
         * Follow Up Date cannot be a past date.
         */
        if (followUpDate < System.today()) {
            throw new AuraHandledException('Follow Up Date cannot be a past date.');
        }

        closeActiveSession(
            showroomVisitId,
            endDateValue,
            endTimeValue,
            previousDurationValue
        );
        
        Showroom_Visit__c sv = [
            SELECT Id, CUSTOMERlookup__c
            FROM Showroom_Visit__c
            WHERE Id = :showroomVisitId
            LIMIT 1
        ];
        
        if (sv.CUSTOMERlookup__c == null) {
            throw new AuraHandledException('Account is not available on Showroom Visit.');
        }
        
        Task t = new Task();
        t.Subject = 'Next Follow Up';
        t.WhatId = sv.CUSTOMERlookup__c;
        t.ActivityDate = followUpDate;
        t.Status = 'Not Started';
        t.Priority = 'Normal';
        t.Next_Follow_Up_Date__c = followUpDate;
        
        insert t;
    }
    
    /* ================= CLOSE ACTIVE SESSION ================= */
    private static void closeActiveSession(
        Id showroomVisitId,
        Date endDateValue,
        String endTimeValue,
        String previousDurationValue
    ) {
        if (showroomVisitId == null) {
            return;
        }
        
        List<Sales_Executive_Activity_Tracking__c> activeSessions = [
            SELECT Id,
                   Session_Starting_Date__c,
                   Session_Start_Time__c,
                   Session_End_Date__c,
                   Session_End_Time__c,
                   Session_Start_Date_Time__c,
                   Session_End_Date_Time__c,
                   Actual_Start_Date_Time__c,
                   Actual_End_Date_Time__c,
                   Duration_Text__c,
                   Previous_Duration__c
            FROM Sales_Executive_Activity_Tracking__c
            WHERE Showroom_Visit__c = :showroomVisitId
            AND Session_Status__c = 'Active'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        if (activeSessions.isEmpty()) {
            return;
        }
        
        Sales_Executive_Activity_Tracking__c session = activeSessions[0];
        
        Date todayDate = System.today();
        Time currentTime = getCurrentUserTime();
        DateTime currentDateTime = DateTime.now();
        System.debug('Current Date Time: ' + currentDateTime);
        
        Date finalEndDate;

        if (String.isNotBlank(endTimeValue)) {
            /*
            * Final requirement:
            * Session_End_Date__c = Start Date
            * Session_End_Time__c = User entered End Time
            * Actual_End_Date_Time__c = Current Date + Current Time
            */
            finalEndDate = session.Session_Starting_Date__c;
        } else {
            finalEndDate = todayDate;
        }

        Boolean isEndDateSameAsStartDate =
            session.Session_Starting_Date__c != null &&
            finalEndDate == session.Session_Starting_Date__c;

        if (!isEndDateSameAsStartDate && String.isBlank(endTimeValue)) {
            throw new AuraHandledException('Please provide the end time.');
        }

        Time finalEndTime;
        if (String.isNotBlank(endTimeValue)) {
            finalEndTime = parseTimeValue(endTimeValue);
        } else {
            finalEndTime = currentTime;
        }

        if (session.Session_Starting_Date__c == null) {
            throw new AuraHandledException('Session start date is not available.');
        }

        if (session.Session_Start_Time__c == null) {
            throw new AuraHandledException('Session start time is not available.');
        }

        Integer startSeconds = getTotalSeconds(session.Session_Start_Time__c);
        Integer endSeconds = getTotalSeconds(finalEndTime);

        if (endSeconds <= startSeconds) {
            throw new AuraHandledException('End Time cannot be less than or equal to Start Time.');
        }

        /*
            * Final validation:
            * If Start Date is today, entered End Time cannot be greater than current time.
            */
            if (
            session.Session_Starting_Date__c == todayDate &&
            endSeconds > getTotalSeconds(currentTime)
            ) {
            throw new AuraHandledException('Future time is not expected for same date.');
            }

        /*
        * Actual_End_Date_Time__c should always be actual system current date-time.
        */
        DateTime combinedDateTime = currentDateTime;
        System.debug('combinedDateTime: ' + combinedDateTime);

        String finalDurationText = calculateDurationHHMMSS(
            session.Session_Starting_Date__c,
            session.Session_Start_Time__c,
            finalEndDate,
            finalEndTime
        );

        session.Session_Status__c = 'Completed';
        session.Session_End_Date__c = finalEndDate;
        session.Session_End_Time__c = finalEndTime;
        session.Actual_End_Date_Time__c = combinedDateTime;

        session.Duration_Text__c = finalDurationText;

        session.Previous_Duration__c = String.isNotBlank(previousDurationValue)
            ? previousDurationValue
            : finalDurationText;

        update session;
        
        Showroom_Visit__c visitToUpdate = new Showroom_Visit__c(
            Id = showroomVisitId,
            Marked_As_Exited__c = true
        );
        update visitToUpdate;
    }
    
    /* ================= HELPERS ================= */
    
    /*private static Time parseTimeValue(String timeValue) {
        if (String.isBlank(timeValue)) {
            return null;
        }
        
        List<String> parts = timeValue.split(':');
        
        Integer hour = Integer.valueOf(parts[0]);
        Integer minute = Integer.valueOf(parts[1]);
        Integer second = 0;
        
        if (parts.size() > 2) {
            second = Integer.valueOf(parts[2]);
        }
        
        return Time.newInstance(hour, minute, second, 0);
    }*/

    private static Time parseTimeValue(String timeValue) {
        if (String.isBlank(timeValue)) {
            return null;
        }

        List<String> parts = timeValue.split(':');

        Integer hour = Integer.valueOf(parts[0]);
        Integer minute = Integer.valueOf(parts[1]);
        Integer second = 0;

        if (parts.size() > 2) {
            String secondPart = parts[2];

            if (secondPart.contains('.')) {
                secondPart = secondPart.split('\\.')[0];
            }

            second = Integer.valueOf(secondPart);
        }

        return Time.newInstance(hour, minute, second, 0);
    }
    
    private static Integer getTotalSeconds(Time t) {
        return (t.hour() * 3600) + (t.minute() * 60) + t.second();
    }
    
    /*
     * Correct current time helper.
     * Do not add timezone offset manually.
     */
    private static Time getCurrentUserTime() {
        return System.now().time();
    }

    private static DateTime getCurrentUserDateTime() {
        return DateTime.now();
    }
    
    private static String calculateDurationHHMMSS(
        Date startDate,
        Time startTime,
        Date endDate,
        Time endTime
    ) {
        if (
            startDate == null ||
            startTime == null ||
            endDate == null ||
            endTime == null
        ) {
            return '00:00:00';
        }
        
        DateTime startDateTime = DateTime.newInstance(startDate, startTime);
        DateTime endDateTime = DateTime.newInstance(endDate, endTime);
        
        Long durationMilliseconds = endDateTime.getTime() - startDateTime.getTime();
        
        if (durationMilliseconds <= 0) {
            return '00:00:00';
        }
        
        Long totalSecondsLong = durationMilliseconds / 1000;
        Integer totalSeconds = Integer.valueOf(totalSecondsLong);
        
        return formatHHMMSS(totalSeconds);
    }
    
    private static String formatHHMMSS(Integer totalSeconds) {
        if (totalSeconds == null || totalSeconds < 0) {
            return '00:00:00';
        }
        
        Integer hours = totalSeconds / 3600;
        Integer remainingSeconds = Math.mod(totalSeconds, 3600);
        Integer minutes = remainingSeconds / 60;
        Integer seconds = Math.mod(remainingSeconds, 60);
        
        return pad2(hours) + ':' + pad2(minutes) + ':' + pad2(seconds);
    }
    
    private static String pad2(Integer value) {
        if (value == null) {
            return '00';
        }
        
        return value < 10
            ? '0' + String.valueOf(value)
            : String.valueOf(value);
    }
}