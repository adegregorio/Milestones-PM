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
public with sharing class Milestone1_GettingStartedController {

    public Boolean settingsReady {get;set;}
    public Boolean projectReady {get;set;}

    public String lastResult {get;set;}

    public Milestone1_GettingStartedController() {
        settingsReady = Milestone1_Settings__c.getOrgDefaults() != null;

    }

    public void setupStandardSettings() {

        Milestone1_Settings__c settings = Milestone1_Settings__c.getOrgDefaults();

        if (settings != null) {
            lastResult = system.label.Milestone1_SettingsAlreadyExistNoChanges;
        } else {
            settings = getInitialSettingsWithoutSave();



            insert settings;

            settingsReady = true;


            handleGettingStartedProjectInitialization();


        }

    }

    public Milestone1_Project__c handleGettingStartedProjectInitialization() {
        Milestone1_Project__c project = getSampleProject();
        project = setProperDates(project);
        return project;
    }

    private Milestone1_Project__c getSampleProject() {
        Milestone1_XML_Import_Utility util = new Milestone1_XML_Import_Utility();
        return util.importProject(getSampleProjectXml());
    }

    private String getSampleProjectXml() {
        String sampleProjectName = 'Starter Project (LPM1)';
        String result = '';
        List<Document> docs = [
            SELECT
                Name,
                Id,
                Body
            FROM
                Document
            WHERE
                Name = :sampleProjectName
        ];

        if (docs.size() == 1) {
            Document sampleProjectDocument = docs.get(0);
            result = sampleProjectDocument.body.toString();
        } else {
            throw new Milestone1_Exception(
                'The ' + sampleProjectName + ' document was not found or there are more than one.'
            );
        }

        return result;
    }

    private Milestone1_Project__c setProperDates(Milestone1_Project__c project) {
        project = updateProjectDatesAndStatus(project);

        List<Milestone1_Milestone__c> milestones = new List<Milestone1_Milestone__c>();
        List<Milestone1_Task__c> tasks = new List<Milestone1_Task__c>();

        Integer aliasCount = [
            SELECT
                Id
            FROM
                Milestone1_Milestone__c
            WHERE
                Alias__c LIKE 'DEMO_%'
        ].size();

        Date milestoneKickoff = project.Kickoff__c;

        for (Milestone1_Milestone__c milestone : getMilestonesWithTasks(project)) {
            List<Milestone1_Task__c> editedTasks = setProperTasksDates(milestone, milestoneKickoff);
            tasks.addAll(editedTasks);

            milestone.Kickoff__c = milestoneKickoff;
            milestone.Deadline__c = editedTasks.size() > 0
                ? editedTasks[editedTasks.size() - 1].Due_Date__c
                : milestoneKickoff;
            milestone.Complete__c = milestone.Name.startsWith('1');
            milestone.Alias__c = getUniqueAlias(milestone, aliasCount);
            aliasCount++;

            milestones.add(milestone);
            milestoneKickoff = milestone.Deadline__c;
        }

        update tasks;
        update milestones;

        return project;
    }

    private Milestone1_Project__c updateProjectDatesAndStatus(Milestone1_Project__c project) {
        project.Kickoff__c = Date.today().addDays(-5);
        project.Deadline__c = Date.today().addDays(28);
        project.Status__c = 'Active';
        update project;

        return project;
    }

    private List<Milestone1_Milestone__c> getMilestonesWithTasks(Milestone1_Project__c project) {
        return [
            SELECT
                Name,
                Kickoff__c,
                Id,
                Alias__c,
                Deadline__c,
                Project__c,
                (SELECT
                    Id,
                    Name,
                    Blocked_Reason__c,
                    Blocked__c,
                    Complete__c,
                    Due_Date__c,
                    Priority__c,
                    Start_Date__c
                 FROM
                    Project_Tasks__r
                 ORDER BY Name
                )
            FROM
                Milestone1_Milestone__c
            WHERE
                Project__c = :project.Id
            ORDER BY
                Name
        ];
    }

    private List<Milestone1_Task__c> setProperTasksDates(
            Milestone1_Milestone__c milestone,
            Date milestoneKickoff
    ) {
        List<Milestone1_Task__c> tasks = new List<Milestone1_Task__c>();
        Date taskKickoff = milestoneKickoff;

        for (Milestone1_Task__c task : milestone.Project_Tasks__r) {
            task.Start_Date__c = taskKickoff;
            task.Due_Date__c = taskKickoff.addDays(1);
            task.Complete__c = milestone.Name.startsWith('1');

            tasks.add(task);
            taskKickoff = task.Due_Date__c;
        }

        return tasks;
    }

    private String getUniqueAlias(Milestone1_Milestone__c milestone, Integer aliasCount) {
        String targetAlias = milestone.Name.substring(0, 1);
        if (aliasCount > 0) {
            targetAlias = '' + (aliasCount + 1);
        }
        return 'DEMO_' + targetAlias;
    }

    public Milestone1_Settings__c getInitialSettingsWithoutSave() {

            Milestone1_Settings__c settings = new Milestone1_Settings__c();

            List<Report> reports = [Select Id, Name from Report Where Name like '%(LPM1)'];

            Id blockedTasks;
            Id myTasks;
            Id overdueTasks;
            Id overallTaskStatus;
            Id openTaskStatus;
            Id projMilestones;
            Id reportMyTasksAllProjects;
            Id reportMyTasksByPriority;
            Id summaryBlockedTasks;
            Id summaryLateTasks;


            //these change from install to install so we have to update in settings
            for (Report current : reports) {
                System.debug(current.name);
                if (current.name.indexOf('Blocked Tasks by Project') > -1) {
                    blockedTasks = current.Id;
                } else if (current.name.indexOf('Summary: My Blocked Tasks') > -1) {
                    summaryBlockedTasks = current.Id;
                } else if (current.name.indexOf('Summary: My Late Tasks') > -1) {
                    summaryLateTasks = current.Id;
                } else if (current.name.indexOf('My Incomplete Tasks, By Project') > -1) {
                    reportMyTasksAllProjects = current.id;
                } else if (current.name.indexOf('My Incomplete Tasks, By Priority') > -1) {
                    reportMyTasksByPriority = current.id;
                } else if (current.name.indexOf('My') > -1) {
                    myTasks = current.Id;
                } else if (current.name.indexOf('Overdue') > -1) {
                    overdueTasks = current.Id;
                } else if (current.name.indexOf('Milestones and Open Tasks') > -1) {
                    projMilestones = current.id;
                } else if (current.name.indexOf('Open Tasks') > -1) {
                    openTaskStatus = current.Id;
                } else if (current.name.indexOf('Tasks By Project') > -1) {
                    overallTaskStatus = current.id;
                }
            }
            settings.Report_Id_Blocked_Tasks_by_Project__c = String.valueOf(blockedTasks).substring(0,15);
            settings.Report_Id_My_tasks_by_project__c = String.valueOf(myTasks).substring(0,15);
            settings.Report_Id_Overdue_Tasks_by_Project__c = String.valueOf(overdueTasks).substring(0,15);
            settings.Report_Id_Task_Status_By_Project__c = String.valueOf(overallTaskStatus).substring(0,15);
            settings.Report_Id_Open_Task_Status_by_Project__c = String.valueOf(openTaskStatus).substring(0,15);
            settings.Report_Id_Project_Milestone_Open_Task__c = String.valueOf(projMilestones).substring(0,15);
            settings.Report_Id_My_Tasks_By_Project_Milesto__c = String.valueOf(reportMyTasksAllProjects).substring(0,15);
            settings.Report_Id_My_Tasks_By_Priority_Project__c = String.valueOf(reportMyTasksByPriority).substring(0,15);
            settings.Report_Id_My_Blocked_Tasks__c = String.valueOf(summaryBlockedTasks).substring(0,15);
            settings.Report_Id_My_Late_Tasks__c = String.valueOf(summaryLateTasks).substring(0,15);

            settings.Auto_Follow_Task__c = false;
            settings.Auto_Unfollow_Reassignment__c = false;
            settings.Auto_Follow_Complete_Task__c = false;

            return settings;

    }

    static testMethod void testGetSettings() {

        Milestone1_GettingStartedController cont = new Milestone1_GettingStartedController();

        Milestone1_Settings__c settings = cont.getInitialSettingsWithoutSave();

        System.assert(settings.Report_Id_Blocked_Tasks_by_Project__c != null);
        System.assert(settings.Report_Id_My_tasks_by_project__c != null);
        System.assert(settings.Report_Id_Overdue_Tasks_by_Project__c != null);
        System.assert(settings.Report_Id_Task_Status_By_Project__c != null);
        System.assert(settings.Report_Id_Open_Task_Status_by_Project__c != null);
        System.assert(settings.Report_Id_Project_Milestone_Open_Task__c != null);
        System.assert(settings.Report_Id_My_Tasks_By_Project_Milesto__c != null);
        System.assert(settings.Report_Id_My_Tasks_By_Priority_Project__c != null);
        System.assert(settings.Report_Id_My_Blocked_Tasks__c != null);
        System.assert(settings.Report_Id_My_Late_Tasks__c != null);

        System.assert(!settings.Auto_Follow_Complete_Task__c);
        System.assert(!settings.Auto_Follow_Task__c);
        System.assert(!settings.Auto_Unfollow_Reassignment__c);

    }


    static testMethod void testGettingStartedProject() {

        Test.startTest();

        Milestone1_GettingStartedController cont = new Milestone1_GettingStartedController();

        Milestone1_Project__c project = cont.handleGettingStartedProjectInitialization();

        System.assert(project != null);

        Test.stopTest();

    }
}