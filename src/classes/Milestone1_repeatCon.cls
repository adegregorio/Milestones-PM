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
public with sharing class Milestone1_repeatCon {

    public List<SelectOption> filterList {get;set;}
    public String filterItem {get;set;}
    private final String ALL_ITEMS = system.label.Milestone1_AllItems;
    private final String MY_TASKS = system.label.Milestone1_MyTasksOnly;
    private final String MY_MILESTONES_ONLY = system.label.Milestone1_MyMilestonesOnly;
    private final String MY_PROJECTS_AND_ITEMS = system.label.Milestone1_MyProjectsAndSubProjectItems;
    private Date currentDay;
    /**
     *Modified Date:04-20-2012.
     *Owner:Persistent.
     *Comment: To add an additional project filter.
     *Bug #: 66.
     */
    private List<String> projectIds {get;set;}
    private List<String> milestoneIds {get;set;}
    public List<SelectOption> activeProjectList {get;set;}
    public String selectedProject {get;set;}
    private Milestone1_Month month;

    public List<Milestone1_Project__c> getAllProjectItems() {
        return [
            SELECT
                Id,
                Name
            FROM
                Milestone1_Project__c
            WHERE
                Status__c ='Active'
            LIMIT
                500
        ];
    }

    @TestVisible
    private Map<ID, Milestone1_Project__c> getSelectedProject() {
        projectIds.clear();
        Map<ID,Milestone1_Project__c> projMap = new  Map<ID,Milestone1_Project__c>();
        if (selectedProject == 'AllProjects' || selectedProject == null ) {
            List<Milestone1_Project__c> projList = getAllProjectItems();
            for (Milestone1_Project__c projObj : projList) {
                projMap.put(projObj.id, projObj);
            }
        } else {
            Milestone1_Project__c project = [
                SELECT
                    id
                FROM
                    Milestone1_Project__c
                WHERE
                    id = :selectedProject
            ];
            projMap.put(project.id, project);
        }
        for (Id setId:projMap.keySet()) {
            projectIds.add(setId);
        }

        return projMap;
    }

    @TestVisible
    private Map<ID, Milestone1_Milestone__c> getProjectSpecificMilestone() {
        milestoneIds.clear();
        Map<ID, Milestone1_Milestone__c> milestonesMap = new  Map<ID, Milestone1_Milestone__c>();
        for (Milestone1_Milestone__c m : [
                SELECT
                    Id
                FROM
                    Milestone1_Milestone__c
                WHERE
                    Project__c IN :projectIds
                LIMIT
                    500
        ]) {
            milestonesMap.put(m.Id,m);
            //  milestoneIds.add(m.Id);
        }
        for (Id setId:milestonesMap.keySet()) {
            milestoneIds.add(setId);
        }
        return milestonesMap;
    }

    public void next() {
        addMonth(1);
    }

    public void prev() {
        addMonth(-1);
    }

    public void fiveDayView() {
        setMonth(currentDay);
        month.getCurrentWeek(currentDay);
        month.fiveDayView = true;
    }

    public void monthView() {
        month = new Milestone1_Month(currentDay);
        filter();
    }

    public Milestone1_repeatCon() {
        currentDay = system.today();  // default to today
        Integer mo = currentDay.month();
        projectIds = new List<String>();
        milestoneIds = new List<String>();
        String m_param = System.currentPageReference().getParameters().get('mo');
        String y_param = System.currentPageReference().getParameters().get('yr');

        // allow a month to be passed in on the url as mo=10
        if (m_param != null) {
            integer mi = integer.valueOf(m_param);
            if (mi > 0 && mi <= 12) {
                currentDay = Date.newinstance(currentDay.year(), mi, currentDay.day());
            }
        }
        // and year as yr=2008
        if (y_param != null) {
            integer yr = integer.valueOf(y_param);
            currentDay = Date.newinstance(yr, currentDay.month(), currentDay.day());
        }

        filterList = new List<SelectOption>{
            new SelectOption(ALL_ITEMS, ALL_ITEMS),
            new SelectOption(MY_PROJECTS_AND_ITEMS, MY_PROJECTS_AND_ITEMS),
            new SelectOption(MY_TASKS, MY_TASKS),
            new SelectOption(MY_MILESTONES_ONLY, MY_MILESTONES_ONLY)
        };
        /**
         *Modified Date:04-20-2012.
         *Owner:Persistent.
         *Comment: To add an additional project filter.
         *Bug #: 66.
         */
        activeProjectList = new List<SelectOption>();
        activeProjectList.add(new SelectOption('AllProjects', '     '));
        for (Milestone1_Project__c project:getAllProjectItems()) {
            activeProjectList.add(new SelectOption(project.id, project.name));
        }
        filterItem = ALL_ITEMS;
        setMonth(currentDay);
        fiveDayView();
    }

    public List<Milestone1_Month.Week> getWeeks() {
        system.assert(month != null, 'month is null');
        return month.getWeeks();
    }

    public Milestone1_Month getMonth() {
        return month;
    }

    public void filter() {
        List<Milestone1_Calendar_Item> filteredItems = new List<Milestone1_Calendar_Item>();
        month.clearEvents();
        /**
         *Modified Date:04-20-2012.
         *Owner:Persistent.
         *Comment: To add an additional project filter.
         *Bug #: 66.
         */

        if (filterItem == ALL_ITEMS) {
            filteredItems = getAllItems(month.getValidDateRange());
        } else if (filterItem == MY_TASKS) {
            filteredItems = getMyTasksOnly(month.getValidDateRange());
        } else if (filterItem == MY_MILESTONES_ONLY) {
            filteredItems = getMyMilestonesOnly(month.getValidDateRange());
        } else if (filterItem == MY_PROJECTS_AND_ITEMS) {
            filteredItems = getMyProjectsAndItems(month.getValidDateRange());
        }
        month.setEvents(filteredItems);
    }

    private void setMonth(Date d) {
        month = new Milestone1_Month(d);

        // system.assert(month != null);
        // Date[] da = month.getValidDateRange();  // gather events that fall in this month
        // month.setEvents(getAllItems(da));  // merge those events into the month class
        filter();
    }

    private List<Milestone1_Calendar_Item> getAllItems(Date[] da) {
        /**
         *Modified Date:04-20-2012.
         *Owner:Persistent.
         *Comment: To add an additional project filter.
         *Bug #: 66.
         */
        getSelectedProject();
        getProjectSpecificMilestone();
        List<Milestone1_Project__c> projects = [
            SELECT
                Id,
                Deadline__c,
                Name
            FROM
                Milestone1_Project__c
            WHERE
                Deadline__c >= :da[0]
                AND Deadline__c <= :da[1]
                AND id IN :projectIds
            LIMIT
                500
        ];
        List<Milestone1_Milestone__c> milestones = [
            SELECT
                Id,
                Deadline__c,
                Name
            FROM
                Milestone1_Milestone__c
            WHERE
                Deadline__c >= :da[0]
                AND Deadline__c <= :da[1]
                AND Project__c in :projectIds
            LIMIT
                500
        ];
        List<Milestone1_Task__c> tasks = [
            SELECT
                Id,
                Due_Date__c,
                Name
            FROM
                Milestone1_Task__c
            WHERE
                Due_Date__c >= :da[0]
                AND Due_Date__c <= :da[1]
                AND Project_Milestone__c IN :milestoneIds
            LIMIT
                500
        ];
        List<Milestone1_Calendar_Item> events = new List<Milestone1_Calendar_Item>();
        for (Milestone1_Project__c proj : projects) {
            Milestone1_Calendar_Item calItem = new Milestone1_Calendar_Item(
                proj.Id,
                proj.Name,
                proj.Deadline__c,
                Milestone1_Calendar_Item.PROJECT_TYPE
            );
            events.add(calItem);
        }
        for (Milestone1_Milestone__c milestone : milestones) {
            Milestone1_Calendar_Item calItem = new Milestone1_Calendar_Item(
                milestone.Id,
                milestone.Name,
                milestone.Deadline__c,
                Milestone1_Calendar_Item.MILESTONE_TYPE
            );
            events.add(calItem);
        }
        for (Milestone1_Task__c currTask : tasks) {
            Milestone1_Calendar_Item calItem = new Milestone1_Calendar_Item(
                currTask.Id,
                currTask.Name,
                currTask.Due_Date__c,
                Milestone1_Calendar_Item.TASK_TYPE
            );
            events.add(calItem);
        }
        return events;
    }

    private List<Milestone1_Calendar_Item> getMyProjectsAndItems(Date[] da) {
        /**
         *Modified Date:04-20-2012.
         *Owner:Persistent.
         *Comment: To add an additional project filter.
         *Bug #: 66.
         */
        getSelectedProject();
        getProjectSpecificMilestone();
        List<Milestone1_Calendar_Item> events = new List<Milestone1_Calendar_Item>();
        List<Milestone1_Project__c> projects = [
            SELECT
                Id,
                Deadline__c,
                Name
            FROM
                Milestone1_Project__c
            WHERE
                Deadline__c >= :da[0]
                AND Deadline__c <= :da[1]
                AND OwnerId = :Userinfo.getUserId()
                AND Id IN :projectIds
            LIMIT
                500
        ];
        List<String> projectIds = new List<String>();
        for (Milestone1_Project__c proj : projects) {
            projectIds.add(proj.Id);
            Milestone1_Calendar_Item calItem = new Milestone1_Calendar_Item(
                proj.Id,
                proj.Name,
                proj.Deadline__c,
                Milestone1_Calendar_Item.PROJECT_TYPE
            );
            events.add(calItem);
        }

        List<Milestone1_Milestone__c> milestones = [
            SELECT
                Id,
                Deadline__c,
                Name
            FROM
                Milestone1_Milestone__c
            WHERE
                Deadline__c >= :da[0]
                AND Deadline__c <= :da[1]
                AND Project__c IN :projectIds
            LIMIT
                500
        ];
        List<String> milestoneIds = new List<String>();
        for (Milestone1_Milestone__c milestone : milestones) {
            milestoneIds.add(milestone.Id);
            Milestone1_Calendar_Item calItem = new Milestone1_Calendar_Item(
                milestone.Id,
                milestone.Name,
                milestone.Deadline__c,
                Milestone1_Calendar_Item.MILESTONE_TYPE
            );
            events.add(calItem);
        }

        List<Milestone1_Task__c> tasks = [
            SELECT
                Id,
                Due_Date__c,
                Name
            FROM
                Milestone1_Task__c
            WHERE
                Due_Date__c >= :da[0]
                AND Due_Date__c <= :da[1]
                AND Project_Milestone__c IN :milestoneIds
            LIMIT
                500
        ];
        for (Milestone1_Task__c currTask : tasks) {
            Milestone1_Calendar_Item calItem = new Milestone1_Calendar_Item(
                currTask.Id,
                currTask.Name,
                currTask.Due_Date__c,
                Milestone1_Calendar_Item.TASK_TYPE
            );
            events.add(calItem);
        }

        return events;
    }

    private List<Milestone1_Calendar_Item> getMyMilestonesOnly(Date[] da) {
        /**
         *Modified Date:04-20-2012.
         *Owner:Persistent.
         *Comment: To add an additional project filter.
         *Bug #: 66.
         */
        getSelectedProject();
        getProjectSpecificMilestone();
        List<Milestone1_Milestone__c> milestones = [
            SELECT
                Id,
                Deadline__c,
                Name
            FROM
                Milestone1_Milestone__c
            WHERE
                Deadline__c >= :da[0]
                AND Deadline__c <= :da[1]
                AND OwnerId = :Userinfo.getUserId()
                AND Project__c IN :projectIds
            LIMIT
                500
        ];
        List<Milestone1_Calendar_Item> events = new List<Milestone1_Calendar_Item>();
        for (Milestone1_Milestone__c milestone : milestones) {
            Milestone1_Calendar_Item calItem = new Milestone1_Calendar_Item(
                milestone.Id,
                milestone.Name,
                milestone.Deadline__c,
                Milestone1_Calendar_Item.MILESTONE_TYPE
            );
            events.add(calItem);
        }
        return events;
    }

    private List<Milestone1_Calendar_Item> getMyTasksOnly(Date[] da) {
        /**
         *Modified Date:04-20-2012.
         *Owner:Persistent.
         *Comment: To add an additional project filter.
         *Bug #: 66.
         */
        getSelectedProject();
        getProjectSpecificMilestone();
        List<Milestone1_Task__c> tasks = [
            SELECT
                Id,
                Due_Date__c,
                Name
            FROM
                Milestone1_Task__c
            WHERE
                Due_Date__c >= :da[0]
                AND Due_Date__c <= :da[1]
                AND Assigned_To__c = :Userinfo.getUserId()
                AND Project_Milestone__c IN :milestoneIds
            LIMIT
                500
        ];
        List<Milestone1_Calendar_Item> events = new List<Milestone1_Calendar_Item>();
        for (Milestone1_Task__c currTask : tasks) {
            Milestone1_Calendar_Item calItem = new Milestone1_Calendar_Item(
                currTask.Id,
                currTask.Name,
                currTask.Due_Date__c,
                Milestone1_Calendar_Item.TASK_TYPE
            );
            events.add(calItem);
        }
        return events;
    }

    private void addMonth(integer val) {
        Date d = month.getFirstDate();
        d = d.addMonths(val);
        setMonth(d);
    }
}