public with sharing class TasksHomeComponentController {
    public List<Milestone1_Task__c> myTasks {
        get {
            return [
                SELECT
                    Id,
                    Summary__c,
                    Short_ID__c,
                    Priority__c,
                    Class__c,
                    Task_Stage__c,
                    Due_Date__c,
                    Blocked__c,
                    Hours_Balance__c
                FROM
                    Milestone1_Task__c
                WHERE
                    Assigned_To__c = :UserInfo.getUserId()
                    AND Complete__c = false
                ORDER BY
                    Due_Date__c
            ];
        }
    }
}