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
public class Milestone1_Task_Trigger_Utility {

    public static final string SUBSCRIPTION_LIMIT_EXCEEDED = system.label.Milestone1_MaximumPer;

    public static void handleTaskAfterTrigger(
            Map<Id, Milestone1_Task__c> newTasksMap,
            Map<Id, Milestone1_Task__c> oldTasksMap
    ) {
        List<Milestone1_Log__c> taskBlockerLogs = new List<Milestone1_Log__c>();
	List<Milestone1_Task__c> newTasksForReview = new List<Milestone1_Task__c>();

        for (Milestone1_Task__c currentTask : newTasksMap.values()) {
            Milestone1_Task__c oldTask = oldTasksMap != null
                ? oldTasksMap.get(currentTask.Id)
                : null;

            if (taskChangedToBlocked(currentTask, oldTask)) {
                taskBlockerLogs.add(createTaskBlockerLog(currentTask));
            }

	    if (movedToReview(currentTask, oldTask)) {
		newTasksForReview.add(currentTask);
	    }
        }

        TasksChatterManager tasksChatterMgr = new TasksChatterManager(newTasksMap, oldTasksMap);
        insert tasksChatterMgr.newSubscriptions;
        delete tasksChatterMgr.subscriptionsToRemove;

        insert taskBlockerLogs;

        notifyReviewers(newTasksForReview);
    }

    private static Boolean taskChangedToBlocked(
            Milestone1_Task__c newRecord,
            Milestone1_Task__c oldRecord
    ) {
        return newRecord.Blocked__c && (oldRecord == null || !oldRecord.Blocked__c);
    }

    private static Milestone1_Log__c createTaskBlockerLog(Milestone1_Task__c newRecord) {
        return new Milestone1_Log__c(
            Project__c = newRecord.ProjectId__c,
            Project_Task__c = newRecord.Id,
            Type__c = 'Blocker',
            Subject__c = 'Task Blocked',
            Detail__c = 'Reason ' + newRecord.Blocked_Reason__c
        );
    }

    private static Boolean movedToReview(
            Milestone1_Task__c newRecord,
            Milestone1_Task__c oldRecord
    ) {
        return newRecord.Task_Stage__c == 'For review'
            && (oldRecord == null || oldRecord.Task_Stage__c != 'For review');
    }

    private static void notifyReviewers(List<Milestone1_Task__c> tasksForReview) {
        Map<Id, List<Milestone1_Task__c>> tasksByProject = getTasksByProject(tasksForReview);
        Map<Id, User> reviewerByProject = getReviewersByProject(tasksByProject.keySet());

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        for (Id projectId : tasksByProject.keySet()) {
            emailsToSend.add(
                buildEmail(reviewerByProject.get(projectId), tasksByProject.get(projectId))
            );
        }
        sendEmails(emailsToSend);
    }

    private static Map<Id, List<Milestone1_Task__c>> getTasksByProject(
            List<Milestone1_Task__c> tasksForReview
    ) {
        Map<Id, List<Milestone1_Task__c>> tasksByProject = new Map<Id, List<Milestone1_Task__c>>();

        for (Milestone1_Task__c task : tasksForReview) {
            List<Milestone1_Task__c> projectTasks = tasksByProject.get(task.ProjectId__c);

            if (projectTasks == null) {
                projectTasks = new List<Milestone1_Task__c>();
                tasksByProject.put(task.ProjectId__c, projectTasks);
            }
            projectTasks.add(task);
        }
        return tasksByProject;
    }

    private static Map<Id, User> getReviewersByProject(Set<Id> projectsIds) {

        List<Milestone1_Project__c> projects = [
            SELECT
                Id,
                OwnerId
            FROM
                Milestone1_Project__c
            WHERE
                Id IN :projectsIds
        ];

        Set<Id> reviewersIds = new Set<Id>();
        for (Milestone1_Project__c project : projects) {
            reviewersIds.add(project.OwnerId);
        }

        Map<Id, User> reviewers = new Map<Id, User>([
            SELECT
                Id,
                Name,
                Email
            FROM
                User
            WHERE
                Id IN :reviewersIds
        ]);

        Map<Id, User> reviewersByProject = new Map<Id, User>();
        for (Milestone1_Project__c project : projects) {
            reviewersByProject.put(project.Id, reviewers.get(project.OwnerId));
        }
        return reviewersByProject;
    }

    private static Messaging.SingleEmailMessage buildEmail(
            User reviewer,
            List<Milestone1_Task__c> tasks
    ) {
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setToAddresses(new List<String> {reviewer.Email});
        message.setReplyTo('no-reply@kovida.is');
        message.setSenderDisplayName('Kovida\'s Milestones PM');
        message.setSubject('New tasks for review');

        String htmlBody = '<p>' +
            'This is an email automaically sent by Kovida\'s Milestones PM app because you are ' +
            'the owner of a project. One or more tasks have been moved to the "For review" stage:' +
            '</p>' +
            '<ul>';
        for (Milestone1_Task__c task : tasks) {
            htmlBody += '<li><a href="' +
                URL.getSalesforceBaseUrl().toExternalForm() + '/' + task.Id + '">' +
                task.Summary__c + '</a></li>';
        }
        htmlBody += '</ul>';

        message.setHtmlBody(htmlBody);
        return message;
    }

    private static void sendEmails(List<Messaging.SingleEmailMessage> emailsToSend) {
        Messaging.sendEmail(emailsToSend);
    }

    /*
       handles successor dependencies.
       looks at changes to predecessor task due date and adjusts successor tasks start and due date
       by the same number of days.
     */
    public static void checkSuccessorDependencies(
            Map<Id, Milestone1_Task__c> oldMap,
            Map<Id, Milestone1_Task__c> newMap
    ) {
        Map<Id, Set<Milestone1_Task__c>> successorMap = new Map<Id, Set<Milestone1_Task__c>>();
        for (Milestone1_Task__c successor : [
                SELECT
                    Id,
                    Start_Date__c,
                    Due_Date__c,
                    Predecessor_Task__c
                FROM
                    Milestone1_Task__c
                WHERE
                    Predecessor_Task__c IN :newMap.keySet()
                    AND Id NOT IN :newMap.keySet()
        ]) {
            if (!successorMap.containsKey(successor.Predecessor_Task__c)) {
                successorMap.put(successor.Predecessor_Task__c, new Set<Milestone1_Task__c>());
            }
            successorMap.get(successor.Predecessor_Task__c).add(successor);
        }

        List<Milestone1_Task__c> successorsToUpdate = new List<Milestone1_Task__c>();
        for (Milestone1_Task__c newRec : newMap.values()) {
            Milestone1_Task__c oldRec = oldMap.get(newRec.Id);
            if (oldRec.Due_Date__c != null && newRec.Due_Date__c != null) {
                Integer deadlineShift = oldRec.Due_Date__c.daysBetween(newRec.Due_Date__c);
                if (deadlineShift != 0 && successorMap.containsKey(newRec.Id)) {
                    for (Milestone1_Task__c successor: successorMap.get(newRec.Id)) {
                        successor.Start_Date__c = successor.Start_Date__c.addDays(deadlineShift);
                        successor.Due_Date__c = successor.Due_Date__c.addDays(deadlineShift);
                    }
                    successorsToUpdate.addAll(successorMap.get(newRec.Id));
                }
            }
        }
        update successorsToUpdate;
    }

    public static void handleTaskBeforeTrigger(List<Milestone1_Task__c> recs) {
        Map<String,Milestone1_Milestone__c> taskMilestoneMap =
            Milestone1_Task_Trigger_Utility.retrieveParentMilestones(recs);

        for (Milestone1_Task__c rec : recs) {
            if (rec.Index_Helper__c.length() > 255) {
                rec.Index__c = rec.Index_Helper__c.substring(0, 255);
            } else {
                rec.Index__c = rec.Index_Helper__c;
            }

            if (rec.Due_Date__c == null) {
                Milestone1_Milestone__c parentMilestone =
                    taskMilestoneMap.get(rec.Project_Milestone__c);
                if (parentMilestone != null) {
                    rec.Due_Date__c = parentMilestone.Deadline__c;
                }
            }

            if (rec.Start_Date__c == null) {
                Milestone1_Milestone__c parentMilestone =
                    taskMilestoneMap.get(rec.Project_Milestone__c);
                if (parentMilestone != null) {
                    rec.Start_Date__c = parentMilestone.KickOff__c;
                }

                if (rec.Start_Date__c == null || rec.Start_Date__c < Date.TODAY()) {
                    rec.Start_Date__c = Date.Today();
                }
            }

            if(rec.Assigned_To__c == null)
            {
                rec.Assigned_To__c = UserInfo.getUserId();
            }

            if (rec.Complete__c == false && rec.Days_Late_Formula__c > 0) {
                rec.Days_Late__c = rec.Days_Late_Formula__c;
            } else {
                rec.Days_Late__c = 0;
            }
        }
    }

    public static Map<String,Milestone1_Milestone__c> retrieveParentMilestones(
            List<Milestone1_Task__c> recs
    ) {
        Set<String> ids = new Set<String>();
        for (Milestone1_Task__c rec : recs) {
            ids.add(rec.Project_Milestone__c);
        }
        List<Milestone1_Milestone__c> parentMilestones = [
            SELECT
                Id,
                Name,
                Deadline__c,
                KickOff__c
            FROM
                Milestone1_Milestone__c
            WHERE Id in :ids
        ];

        Map<String, Milestone1_Milestone__c> taskMilestoneMap =
            new Map<String, Milestone1_Milestone__c>();
        for (Milestone1_Milestone__c parentMilestone : parentMilestones) {
            taskMilestoneMap.put(parentMilestone.ID,parentMilestone);
        }

        return taskMilestoneMap;
    }

    /**
     * This method prevent task creations for Users w/o Permissions over parent Milestone of task.
     * Checks if OWD for Milestone1_Milestone__c object are Private and then, checks if the current
     * User have read/write permissons. The way to do it its if Milestone1_Milestone__share exist,
     * so we need do a QueryString to avoid compilations errors if that Object doesn't exist.
     * @params 		taskList
     * @return 		boolean
     * @author 		Sebastian Muñoz
     * @createDate 	January 19, 2011
     */
    public static Boolean checkOWDPermissions(List<Milestone1_Task__c> taskList) {

        // First of all, if the User is a SysAdmin and we are not runing a Test, leave this method.
        List<Sobject> obj_share = new List<Sobject>();
        if (Milestone1_General_Utility.isSysAdmin() && !Test.isRunningTest()) {
            return true;
        } else if (Schema.getGlobalDescribe().get('Milestone1_Milestone__Share') != null) {
            String inClause = '(';
            for (Milestone1_Task__c cTask : taskList) {
                inClause += '\'' + cTask.Project_Milestone__c + '\',';
            }
            inClause = inClause.substring( 0, inClause.length() - 1 );
            inClause += ')';

            String queryStr =
                'SELECT ' +
                    'm.UserOrGroupId, ' +
                    'm.RowCause, ' +
                    'm.ParentId, ' +
                    'm.AccessLevel ' +
                'FROM ' +
                    'Milestone1_Milestone__Share m ' +
                'WHERE ' +
                    'm.ParentId IN ' + inClause + ' ' +
                    'AND m.UserOrGroupId = \'' + Userinfo.getUserId() + '\' ' +
                    'AND m.AccessLevel = \'Read\'';

            obj_share = Database.query( queryStr );

            return obj_share.isEmpty();
        }
        return true;
    }
}