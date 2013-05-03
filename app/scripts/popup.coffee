'use strict';

this.App = Ember.Application.create()

App.Store = DS.Store.extend
  revision: 12

App.Task = DS.Model.extend
  title: DS.attr('string')

App.TasksController = Ember.ArrayController.extend
  addTask: ->
    @get('store').load(App.Task, {title: @get('newTaskTitle')})

App.LOG_TRANSITIONS = true

App.Router.map ->
  @resource 'tasks'

App.IndexRoute = Ember.Route.extend
  redirect: ->
    @transitionTo 'tasks'

App.TasksRoute = Ember.Route.extend
  model: ->
    store = @get('store')
    store.load(App.Task, {id: 1, title: 'Well done!'})
    store.load(App.Task, {id: 2, title: 'Congrats!'})
    App.Task.all()

