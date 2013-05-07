'use strict';

this.App = Ember.Application.create()

this.localStorage = {}

App.Store = DS.Store.extend
  revision: 12
  adapter: DS.LSAdapter.create()

App.Task = DS.Model.extend
  title: DS.attr('string')
  isCompleted: DS.attr('boolean')
  isArchived: DS.attr('boolean')
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
  tasks: (-> App.Task.all()).property()
  running: (->
    @get('tasks').findProperty 'runningLog'
  ).property('tasks.@each.runningLog')
  isRunning: Ember.computed.bool('running')

App.TasksController = Ember.ArrayController.extend
  allTasks: (-> App.Task.all()).property()

  tasks: (->
    @get('allTasks').filterProperty('isArchived', false)
  ).property('allTasks.@each.isArchived')

  openTasks: (->
    @get('tasks').filter (x) -> !x.get('isCompleted')
  ).property('tasks.@each.isCompleted')

  completedTasks: (->
    @get('tasks').filter (x) -> x.get('isCompleted')
  ).property('tasks.@each.isCompleted')

  addTask: (title) ->
    @get('store').createRecord(App.Task, {title: title, isArchived: false})
    @get('store').commit()

  archiveTasks: ->
    @get('completedTasks').forEach (task) ->
      task.set('isArchived', true)
    @get('store').commit()

App.TasksIndexController = Ember.Controller.extend
  needs: ['tasks']
  openTasks: Ember.computed.alias('controllers.tasks.openTasks')
  completedTasks: Ember.computed.alias('controllers.tasks.completedTasks')

App.AddTaskField = Ember.TextField.extend
  valueBinding: 'newTaskTitle',

  insertNewline: ->
    @get('controller').addTask(@get('value'))
    @set('value', '')

App.TaskController = Ember.ObjectController.extend
  taskDidChange: (->
    Ember.run.once =>
      @get('store').commit()
  ).observes('isCompleted', 'title')

  editTask: ->
    @set('isEditing', true)

  removeTask: ->
    task = @get('model')
    task.deleteRecord()
    @get('store').commit()

  back: ->
    history.back()

App.EditTaskView = Ember.TextField.extend
  classNames: ['edit']
  valueBinding: 'task.title',

  focusOut: ->
    @set('controller.isEditing', false)

  insertNewline: ->
    @set('controller.isEditing', false)

  didInsertElement: ->
    this.$().focus()

App.LogsController = Ember.ArrayController.extend
  day: new Date()

  allLogs: (-> App.Log.all()).property()

  logs: (->
    return unless @get('allLogs.isLoaded')
    day = moment(@get('day'))
    console.log('logs', @get('allLogs.length'))
    @get('allLogs').filter (log) =>
      start = moment(log.get('startedAt'))
      start.isAfter(day.startOf('day')) and
        start.isBefore(day.endOf('day'))
  ).property('allLogs.isLoaded', 'allLogs.@each.startedAt', 'day')

  completedLogs: (->
    @get('logs').filterProperty('isCompleted')
  ).property('logs.@each.isCompleted')

  isToday: (->
    moment(@get('day')).startOf('day').isSame(moment().startOf('day'))
  ).property('day')

  showPrevious: ->
    day = moment(@get('day'))
    @set('day', day.subtract('days', 1))

  showNext: ->
    day = moment(@get('day'))
    @set('day', day.add('days', 1))

App.TimerController = Ember.ObjectController.extend
  needs: ['application', 'tasks']
  selectedTask: null
  openTasks: Ember.computed.alias('controllers.tasks.openTasks')
  isRunning: Ember.computed.alias('controllers.application.isRunning')
  log: Ember.computed.alias('controllers.application.running.runningLog')
  time: null # holds the current time

  init: ->
    @_super()
    setInterval (=> (Em.run => @set('time', new Date()))), 100

  elapsedSeconds: (->
    Math.floor((@get('time') - @get('log.startedAt')) / 1000)
  ).property('log.startedAt', 'time')

  stop: ->
    @set('selectedTask', null)
    @send('stopTimer', @get('log.task'))

  stopAndClose: ->
    @get('log.task').set('isCompleted', true)
    @stop()

  start: -> @send('startTimer', @get('selectedTask'))

App.TimerSelect = Ember.Select.extend
  selectionDidChange: (->
    # return if the select becomes empty (immediately after render)
    return unless @get('selection')
    Ember.run.once => @get('controller').start()
  ).observes('selection')

App.LOG_TRANSITIONS = true

App.Router.map ->
  @resource 'tasks', ->
    @resource 'task', path: '/tasks/:task_id'
  @resource 'logs'
  @resource 'timer'

App.ApplicationRoute = Ember.Route.extend
  setupController: (controller) ->
    App.Task.find().then ->
      App.Log.find().then ->
        Em.run.next ->
          controller.set('isInitialized', true)

  events:
    startTimer: (task) ->
      log = task.get('logs').createRecord
        startedAt: (new Date())
      task.set('runningLog', log)
      @get('store').commit()
      @transitionTo 'timer'

    stopTimer: (task) ->
      task.set('runningLog.finishedAt', new Date())
      task.set('runningLog', null)
      @get('store').commit()
      @transitionTo 'task', task

App.IndexRoute = Ember.Route.extend
  redirect: ->
    @transitionTo 'timer'

App.TasksRoute = Ember.Route.extend
  model: ->
    App.Task.all()

Ember.Handlebars.registerBoundHelper 'time', (date) ->
  moment(date).format('HH:mm')

Ember.Handlebars.registerBoundHelper 'monthDay', (date) ->
  moment(date).format('MMMM D.')

Ember.Handlebars.registerBoundHelper 'duration', (seconds) ->
  hour = Math.floor(seconds/3600)
  min = Math.floor((seconds - hour * 3600) / 60)
  sec = seconds - hour * 3600 - min * 60
  min = "0" + min if min < 10
  sec = "0" + sec if sec < 10
  if hour is 0
    "%@:%@".fmt(min, sec)
  else
    "%@:%@:%@".fmt(hour, min, sec)
