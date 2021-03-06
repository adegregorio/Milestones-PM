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
public with sharing class Milestone1_Charts_GanttController {

    private String nameFieldName;
    private String completedFieldName;
    private String filterFieldName;
    private List<Sobject> sobjectList;
    private static final String REGEXP_QUOTES = '(?<!\\\\)"';

    public String mytarget {get;
        set {
            this.mytarget = value;
            init();
        }
    }
    public String objectType {get;set;}
    public String startDateFieldName {get;set;}
    public String endDateFieldName {get;set;}
    public String idFieldName {get;set;}
    public String fullViewURL {get;set;}
    public String projectGanttJson{get;set;}

    public static final String COLOR_COMPLETE = '#F2F3F3';
    public static final String COLOR_LATE = '#EE3322';
    public static final String COLOR_FUTURE = '#859900';
    public static final String COLOR_CURRENT = '#268BD2';

    public Milestone1_Charts_GanttController() {
        init();
    }

    private void init() {
        if (myTarget != null) {
            initFieldNames();
            retrieveData();
            projectGanttJson = toJSon();
        }
    }

    public String getProjectGanttJson() {
        init();
        return projectGanttJson;
    }

    /*
     * 	Initialize the variables depending on the object type possible values:
     * 	Milestone1_Milestone__c and Milestone1_Task__c
     */
    private void initFieldNames() {
        if (mytarget != null) {
            if (mytarget.startsWith(Schema.SObjectType.Milestone1_Project__c.getKeyPrefix())) {
                startDateFieldName = Milestone1_Milestone__c.Kickoff__c.getDescribe().getName();
                endDateFieldName = Milestone1_Milestone__c.Deadline__c.getDescribe().getName();
                nameFieldName = Milestone1_Milestone__c.NameClean__c.getDescribe().getName();
                filterFieldName = Milestone1_Milestone__c.Project__c.getDescribe().getName();

                objectType = Schema.SObjectType.Milestone1_Milestone__c.getName();
            } else if (mytarget.startsWith(Schema.SObjectType.Milestone1_Milestone__c.getKeyPrefix())) {
                startDateFieldName = Milestone1_Task__c.Start_Date__c.getDescribe().getName();
                endDateFieldName = Milestone1_Task__c.Due_Date__c.getDescribe().getName();
                nameFieldName = Milestone1_Task__c.Summary__c.getDescribe().getName();
                filterFieldName = Milestone1_Task__c.Project_Milestone__c.getDescribe().getName();

                objectType = Schema.SObjectType.Milestone1_Task__c.getName();
            } else {
                throw new Milestone1_Exception('[initFieldNames] Unable to generate JSON for ' + mytarget);
            }
            idFieldName = 'Id';
            completedFieldName = 'Complete__c';
        }
    }

    /*
     * 	Retrieve the data doing a dynamic query by object type.
     */
    private void retrieveData() {
        String query =
            'SELECT ' +
                idFieldName + ',' +
                startDateFieldName + ',' +
                endDateFieldName + ',' +
                nameFieldName + ',' +
                completedFieldName + ' ' +
            'FROM ' +
                objectType + ' ' +
            'WHERE ' +
                filterFieldName + '=\'' + mytarget + '\' ' +
            'ORDER BY ' +
                'Name';
        sobjectList = Database.query(query);
    }

    /**
     *	Generate the output in json format to be rendered in the jquery gantt.
     */
    private String toJSon() {
        String ret = 'var ganttData' + mytarget + ' = [{id: 1, name: "", series: [';
        Boolean addComma = false;
        Date startDate;
        Date endDate;

        for (Sobject current : sobjectList) {
            if (current.get(startDateFieldName) == null) {
                startDate = Date.today();
            } else {
                startDate = Date.valueOf(current.get(startDateFieldName));
            }
            if (current.get(endDateFieldName) == null) {
                endDate = startDate;
            } else {
                endDate = Date.valueOf(current.get(endDateFieldName));
            }

            Boolean completed = Boolean.valueOf(current.get(completedFieldName));
            String name = escapeDoubleQuotes(String.valueOf(current.get(nameFieldName)));
            String id = String.valueOf(current.get(idFieldName));

            if (addComma) {
                ret += ',';
            }

            String color = COLOR_CURRENT;

            if (completed) {
                color = COLOR_COMPLETE;
            } else if (endDate < Date.today()) {
                color = COLOR_LATE;
            } else if (startDate > Date.today()) {
                color = COLOR_FUTURE;
            }

            ret += '{' +
                'id:"' + id + '",' +
                'name: "' + name + '",' +
                'start: new Date(' + startDate.year() + ',' + (startDate.month() - 1) + ',' + startDate.day() + '),' +
                'end: new Date(' + endDate.year() + ',' + (endDate.month() - 1) + ',' + endDate.day() + '), ' +
                'color: "' + color + '"' +
            '}';

            addComma = true;
        }

        ret += ']}];';
        return ret;
    }

    private String escapeDoubleQuotes(String word) {
        return word.replaceAll(REGEXP_QUOTES,'\\\\"');
    }
}