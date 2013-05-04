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
  runningLog: DS.belongsTo('App.Log', {inverse: '_dummy'})

App.Log = DS.Model.extend
  task: DS.belongsTo('App.Task', {inverse: 'logs'})
  _dummy: DS.belongsTo('App.Task', {inverse: 'runningLog'})
  startedAt: DS.attr('date')
  finishedAt: DS.attr('date')
  isCompleted: Ember.computed.bool('finishedAt')

  elapsedSeconds: (->
    start = moment(@get('startedAt'))
    finish = moment(@get('finishedAt'))
    finish.diff(start, 'seconds')
  ).property('startedAt', 'finishedAt')

App.ApplicationController = Ember.Controller.extend
  tasks: null
  running: (->
    @get('tasks').findProperty 'runningLog'
  ).property('tasks.@each.runningLog')
  isRunning: Ember.computed.bool('running')

App.TasksController = Ember.ArrayController.extend
  addTask: ->
    @get('store').createRecord(App.Task, {title: @get('newTaskTitle')})
    @get('store').commit()

  openTasks: (->
    @get('model').filter (x) -> !x.get('isCompleted')
  ).property('model.@each.isCompleted')

  completedTasks: (->
    @get('model').filter (x) -> x.get('isCompleted')
  ).property('model.@each.isCompleted')

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
  needs: ['application', 'tasks']
  selectedTask: null
  openTasks: Ember.computed.alias('controllers.tasks.openTasks')
  isRunning: Ember.computed.alias('controllers.application.isRunning')
  logs: (-> App.Log.find()).property()
  completedLogs: (->
    @get('logs').filterProperty('isCompleted')
  ).property('logs.@each.isCompleted')
  start: -> @send('startTimer', @get('selectedTask'))

App.TimerController = Ember.ObjectController.extend
  needs: ['application']
  isRunning: Ember.computed.alias('controllers.application.isRunning')
  log: Ember.computed.alias('controllers.application.running.runningLog')

  elapsedSeconds: (->
    (new Date()) - @get('log.startedAt')
  ).property('log.startedAt')

  stop: -> @send('stopTimer', @get('log.task'))

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
      task.set('runningLog', log)
      @transitionTo 'timer'

    stopTimer: (task) ->
      task.set('runningLog.finishedAt', new Date())
      task.set('runningLog', null)
      @transitionTo 'task', task

App.IndexRoute = Ember.Route.extend
  redirect: ->
    isRunning = @controllerFor('application').get('isRunning')
    console.log 'IndexRoute#redirect', isRunning
    @transitionTo 'tasks'

App.TasksRoute = Ember.Route.extend
  model: ->
    App.Task.all()

Ember.Handlebars.registerBoundHelper 'time', (date) ->
  moment(date).format('HH:mm')

Ember.Handlebars.registerBoundHelper 'duration', (seconds) ->
  if seconds < 60
    "%@s".fmt(seconds)
  else if 60 <= seconds and seconds < 3600
    "%@m".fmt(Math.floor(seconds/60))
  else
    hour = Math.floor(seconds/3600)
    min = Math.floor((seconds - hour * 3600) / 60)
    "%@h %@m".fmt(hour, min)


