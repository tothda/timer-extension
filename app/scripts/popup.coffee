'use strict';

this.App = Ember.Application.create()

this.localStorage = {}

App.Store = DS.Store.extend
  revision: 12
  adapter: DS.LSAdapter.create()

App.Task = DS.Model.extend
  title: DS.attr('string')
  isCompleted: DS.attr('boolean')
  logs: DS.hasMany('App.Log', {inverse: 'task'})
  runningLog: DS.belongsTo('App.Log')

  didLogsChanged: (->
    logs = @get('logs')
    startedAt = logs.get('startedAt')
    finishedAt = logs.get('finishedAt')
    runningLog = logs.get('runningLog')

    notYetStarted = (logs.filter (x) -> !startedAt?).get('length')
    startedLogs = logs.filter (x) -> startedAt? and !finishedAt?
    started = startedLogs.get('length')
    finished = (logs.filter (x) -> finishedAt?).get('length')

    Ember.assert("More than one running log in task (%@)".fmt(@get('id')), started > 1)

    if !runningLog? and started is 1
      @set('runningLog', startedLogs.get('firstObject'))
    else if runningLog? and started is 0
      @set('runningLog', null)
  ).observes('logs.@each.startedAt', 'logs.@each.finishedAt')

App.Log = DS.Model.extend
  task: DS.belongsTo('App.Task', {inverse: 'logs'})
  startedAt: DS.attr('date')
  finishedAt: DS.attr('date')

App.ApplicationController = Ember.Controller.extend
  tasks: null
  running: (->
    @get('tasks').findProperty 'runningLog'
  ).property('tasks.@each.running')

App.TasksController = Ember.ArrayController.extend
  addTask: ->
    @get('store').createRecord(App.Task, {title: @get('newTaskTitle')})
    @get('store').commit()

App.TaskController = Ember.ObjectController.extend
  taskDidChange: (->
    Ember.run.once =>
      @get('store').commit()
  ).observes('model.isCompleted')

  editTask: ->
    @set('isEditing', true)

  removeTask: ->
    task = @get('model')
    task.deleteRecord()
    @get('store').commit()

App.EditTaskView = Ember.TextField.extend
  classNames: ['edit']
  valueBinding: 'task.title',

  focusOut: ->
    @set('controller.isEditing', false)

  insertNewline: ->
    @set('controller.isEditing', false)

  didInsertElement: ->
    this.$().focus()

App.TodayController = Ember.ArrayController.extend
  needs: ['tasks']
  selectedTask: null
  start: -> @send('startTimer', @get('selectedTask'))

App.TimerController = Ember.ObjectController.extend
  needs: ['application']
  running: Ember.computed.alias('controllers.application.running')
  log: Ember.computed.alias('running.runningLog')

  elapsedSeconds: (->
    (new Date()) - @get('log.startedAt')
  ).property('log.startedAt')

App.LOG_TRANSITIONS = true

App.Router.map ->
  @resource 'tasks'
  @resource 'task', path: '/tasks/:task_id'
  @resource 'today'
  @resource 'timer'

App.ApplicationRoute = Ember.Route.extend
  setupController: (controller) ->
    controller.set('tasks', App.Task.find())

  events:
    startTimer: (task) ->
      log = task.get('logs').createRecord
        startedAt: (new Date())
      @transitionTo 'task', task

App.IndexRoute = Ember.Route.extend
  redirect: ->
    @transitionTo 'tasks'

App.TasksRoute = Ember.Route.extend
  model: ->
    App.Task.all()

App.TodayRoute = Ember.Route.extend
  setupController: (controller) ->
    controller.set('allTasks', App.Task.all())



