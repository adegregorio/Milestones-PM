/*
Copyright (c) 2011, salesforce.com, Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.
    * Neither the name of the salesforce.com, Inc. nor the names of its contributors
    may be used to endorse or promote products derived from this software
    without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
OF THE POSSIBILITY OF SUCH DAMAGE.

*/
public with sharing class Milestone1_Summary2 {

    private Map<String, Report> reportsByName;

    public ID targetProject {get; set;}
    public String searchText {get; set;}
    public List<Milestone1_Project__c> projectResults {get; private set;}
    public List<Milestone1_Milestone__c> milestoneResults {get; private set;}
    public List<Milestone1_Task__c> taskResults {get; private set;}
    public boolean displaySearchError {private get; private set;}
    public boolean searchLengthError {private get; private set;}
    public List<Pair> recentItems {get; private set;}
    public boolean hasSearchResultsError {
        get {
            return displaySearchError != null && displaySearchError == true;
        }
    }
    public boolean hasSearchLengthError {
    	get {
            return searchLengthError != null && searchLengthError == true;
    	}
    }
    public boolean hasProjectResults {
        get {
            return projectResults != null && !projectResults.isEmpty();
        }
    }
    public boolean hasMilestoneResults {
        get {
            return milestoneResults != null && !milestoneResults.isEmpty();
        }
    }
    public boolean hasTaskResults {
        get {
            return taskResults != null && !taskResults.isEmpty();
        }
    }
    public boolean hasSettings {
        get {
            return settings != null;
        }
    }
    public boolean isDeployed {
        get {
            Id myProfileId = UserInfo.getProfileId();
            Profile myProfile = [
                SELECT
                    Id,
                    Name
                FROM
                    Profile
                WHERE Id = :myProfileId
            ];
            Boolean objectsDeployed = true;

            if (myProfile.Name != 'System Administrator') {
                try {
                    Schema.DescribeFieldResult F = Schema.SObjectType.Milestone1_Milestone__C.fields.Name;
                    if (F.isAccessible() == true) {
                        return true;
                    } else {
                        return false;
                    }
                    return true;
                } catch (System.UnexpectedException e) {
                    return false;
                }
            }
            return objectsDeployed;
        }
    }

    public Milestone1_Settings__c settings = Milestone1_Settings__c.getInstance();

    public void initialize() {
        if (isDeployed) {
            loadRecentItems();
            loadReportsMap();
        }
    }

    private void loadRecentItems() {
        List<Milestone1_Project__c> recentProjects = [
            SELECT
                Id,
                Name
            FROM
                Milestone1_Project__c
            ORDER BY
                LastModifiedDate DESC
            LIMIT 5
        ];
        List<Milestone1_Milestone__c> recentMilestones = [
            SELECT
                Id,
                Name
            FROM
                Milestone1_Milestone__c
            ORDER BY
                LastModifiedDate DESC
            LIMIT 50
        ];
        List<Milestone1_Task__c> recentTasks = [
            SELECT
                Id,
                Name
            FROM
                Milestone1_Task__c
            ORDER BY
                LastModifiedDate DESC
            LIMIT 100
        ];

        this.recentItems = new List<Pair>();
        this.recentItems.addAll(createPairObjects(recentProjects, 'Project: '));
        this.recentItems.addAll(createPairObjects(recentMilestones, 'Milestone: '));
        this.recentItems.addAll(createPairObjects(recentTasks, 'Task: '));
    }

    private void loadReportsMap() {
        this.reportsByName = new Map<String, Report>();
        for (Report rep : [
            SELECT
                Id,
                Name,
                DeveloperName
            FROM
                Report
            WHERE
                Name LIKE '%(LPM1)'
        ]) {
            this.reportsByName.put(rep.DeveloperName, rep);
        }
    }

    public void searchProjects() {
        if (searchText.length() < 2) {
            this.searchLengthError = true;
            return;
        } else {
            this.searchLengthError = false;
        }

        List<List<SObject>> searchList = [
            FIND :searchText IN ALL FIELDS RETURNING
            Milestone1_Project__c (Id, Name, Owner.Name, Status__c LIMIT 5),
            Milestone1_Milestone__c (Id, Name, Project__r.Name LIMIT 10),
            Milestone1_Task__c (Id, Name, Project_Milestone__r.Name LIMIT 25)
        ];
        this.projectResults = (List<Milestone1_Project__c>)searchList[0];
        this.milestoneResults = (List<Milestone1_Milestone__c>)searchList[1];
        this.taskResults = (List<Milestone1_Task__c>)searchList[2];

        if (this.projectResults.isEmpty() && this.milestoneResults.isEmpty() && this.taskResults.isEmpty()) {
            this.displaySearchError = true;
        } else {
            this.displaySearchError = false;
        }
    }

    private List<Pair> createPairObjects(List<SObject> records, String namePrefix) {
        List<Pair> newPairs = new List<Pair>();
        for (SObject record: records) {
            //RSC 2011-05-06 am getting occassional script exceptions
            if (record != null && record.get('name') != null) {
                newPairs.add(new Pair(namePrefix + (String)record.get('name'), (String)record.id));
            }
        }
        return newPairs;
    }

    public List<Milestone1_Project__c> getProjects() {
         return (List<Milestone1_Project__c>) setCon.getRecords();
    }

    public ApexPages.StandardSetController setCon {
        get {
            if (setCon == null) {
                setCon = new ApexPages.StandardSetController(Database.getQueryLocator([
                    SELECT
                        Id,
                        Total_Open_Task_Count__c,
                        Total_Complete_Task_Count__c,
                        Total_Blocked_Task_Count__c,
                        Total_Late_Task_Count__c,
                        Status_TasksOpenBlockedLate__c,
                        Total_Hours_Budget__c,
                        Total_Hours_Budget_from_Milestones__c,
                        Total_Hours_Estimate__c,
                        Total_Hours_Incurred__c,
                        Status_BudgetMiletoneEstimate__c,
                        Status_BudgetExpenseSummary__c,
                        Name,
                        Deadline__c,
                        Kickoff__c,
                        Duration__c,
                        GoogleGanntUrl__c
                    FROM
                        Milestone1_Project__c
                    WHERE
                        Status__c = 'Active'
                ]));
                setCon.setPageSize(20);
            }
            return setCon;
        }
        set;
    }

    // Boolean to check if there are more records after the present displaying records
    public Boolean hasNext {
        get {
            return setCon.getHasNext();
        }
        set;
    }

    // Boolean to check if there are more records before the present displaying records
    public Boolean hasPrevious {
        get {
            return setCon.getHasPrevious();
        }
        set;
    }

    // Page number of the current displaying records
    public Integer pageNumber {
        get {
            return setCon.getPageNumber();
        }
        set;
    }

    public Integer totalPages {
        get {
            Integer pages = (setCon.getResultSize() / 20);
            if (math.mod(setCon.getResultSize(), 20) != 0) {
                pages += 1;
            }
            return pages;
        }
        set;
    }

    // Returns the previous page of records
    public void previous() {
        setCon.previous();
    }

    //Returns the next page of records
    public void next() {
        setCon.next();
    }

    public Pagereference view() {
        return new Pagereference('/' + targetProject);
    }

    public Pagereference viewMyTasks() {
        return new Pagereference(
            '/' + this.reportsByName.get('My_Project_Tasks') +
            '?pv0=' + String.valueOf(targetProject).substring(0,15) +
            '&pv1=' + UserInfo.getFirstName() + ' ' + UserInfo.getLastName()
        );
    }

    public Pagereference viewBlockedTasks() {
        return new Pagereference(
            '/' + this.reportsByName.get('Blocked_Tasks_by_Project') +
            '?pv0=' + String.valueOf(targetProject).substring(0,15)
        );
    }

    public Pagereference viewOverdueTasks() {
        return new Pagereference(
            '/' + this.reportsByName.get('Overdue_Tasks_by_Project') +
            '?pv0=' + String.valueOf(targetProject).substring(0,15)
        );
    }

    public Pagereference viewOpenTasks() {
        return new Pagereference(
            '/' + this.reportsByName.get('Open_Tasks_By_Project_LPM1') +
            '?pv0=' + String.valueOf(targetProject).substring(0,15)
        );
    }

    public Pagereference viewMilestoneOpenTasks() {
        return new Pagereference(
            '/' + this.reportsByName.get('Milestones_and_Open_Tasks_by_Proj_LPM1') +
            '?pv0=' + String.valueOf(targetProject).substring(0,15)
        );
    }

    public Pagereference incompleteTasksByProject() {
        return new Pagereference(
            '/' + this.reportsByName.get('My_Incomplete_Tasks_By_Project') +
            '?pv0=' + Encodingutil.urlEncode('' + UserInfo.getName(), 'UTF-8')
        );
    }

    public Pagereference incompleteTasksByPriority() {
        return new Pagereference(
            '/' + this.reportsByName.get('My_Incomplete_Tasks_By_Priority') +
            '?pv0=' + Encodingutil.urlEncode('' + UserInfo.getName(), 'UTF-8')
        );
    }

    public Pagereference summaryMyLateTasks() {
        return new Pagereference(
            '/' + this.reportsByName.get('Summary_My_Late_Tasks_LPM1') +
            '?pv0=' + Encodingutil.urlEncode('' + UserInfo.getName(), 'UTF-8')
        );
    }

    public Pagereference summaryMyBlockedTasks() {
        return new Pagereference(
            '/' + this.reportsByName.get('Summary_My_Blocked_Tasks_LPM1') +
            '?pv0=' + Encodingutil.urlEncode('' + UserInfo.getName(), 'UTF-8')
        );
    }

    class Pair {
        Pair(String key, String value) {
            this.key = key;
            this.value = value;
        }

        public String key {get; private set;}
        public String value {get; private set;}
    }
}