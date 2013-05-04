'use strict';

this.App = Ember.Application.create()

this.localStorage = {}

App.Store = DS.Store.extend
  revision: 12
  adapter: DS.LSAdapter.create()

App.Task = DS.Model.extend
  title: DS.attr('string')
  isCompleted: DS.attr('boolean')

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

App.LOG_TRANSITIONS = true

App.Router.map ->
  @resource 'tasks'

App.IndexRoute = Ember.Route.extend
  redirect: ->
    @transitionTo 'tasks'

App.TasksRoute = Ember.Route.extend
  model: ->
    App.Task.find()

