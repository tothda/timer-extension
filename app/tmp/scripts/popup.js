(function() {
  'use strict';  this.App = Ember.Application.create();

  this.localStorage = {};

  App.Store = DS.Store.extend({
    revision: 12,
    adapter: DS.LSAdapter.create()
  });

  App.Task = DS.Model.extend({
    title: DS.attr('string'),
    isCompleted: DS.attr('boolean'),
    isArchived: DS.attr('boolean'),
    logs: DS.hasMany('App.Log', {
      inverse: 'task'
    }),
    runningLog: DS.belongsTo('App.Log', {
      inverse: '_dummy'
    })
  });

  App.Log = DS.Model.extend({
    task: DS.belongsTo('App.Task', {
      inverse: 'logs'
    }),
    _dummy: DS.belongsTo('App.Task', {
      inverse: 'runningLog'
    }),
    startedAt: DS.attr('date'),
    finishedAt: DS.attr('date'),
    isCompleted: Ember.computed.bool('finishedAt'),
    elapsedSeconds: (function() {
      var finish, start;

      start = moment(this.get('startedAt'));
      finish = moment(this.get('finishedAt'));
      return finish.diff(start, 'seconds');
    }).property('startedAt', 'finishedAt')
  });

  App.ApplicationController = Ember.Controller.extend({
    time: null,
    isRunning: Ember.computed.bool('running'),
    running: (function() {
      return this.get('tasks').findProperty('runningLog');
    }).property('tasks.@each.runningLog'),
    init: function() {
      var _this = this;

      this._super();
      return setInterval((function() {
        return Em.run(function() {
          return _this.set('time', new Date());
        });
      }), 100);
    },
    tasks: (function() {
      return App.Task.all();
    }).property()
  });

  App.TasksController = Ember.ArrayController.extend({
    allTasks: (function() {
      return App.Task.all();
    }).property(),
    tasks: (function() {
      return this.get('allTasks').filterProperty('isArchived', false);
    }).property('allTasks.@each.isArchived'),
    openTasks: (function() {
      return this.get('tasks').filter(function(x) {
        return !x.get('isCompleted');
      });
    }).property('tasks.@each.isCompleted'),
    completedTasks: (function() {
      return this.get('tasks').filter(function(x) {
        return x.get('isCompleted');
      });
    }).property('tasks.@each.isCompleted')
  });

  App.TasksIndexController = Ember.Controller.extend({
    needs: ['tasks'],
    openTasks: Ember.computed.alias('controllers.tasks.openTasks'),
    completedTasks: Ember.computed.alias('controllers.tasks.completedTasks'),
    addTask: function(title) {
      this.get('store').createRecord(App.Task, {
        title: title,
        isArchived: false
      });
      return this.get('store').commit();
    },
    archiveTasks: function() {
      this.get('completedTasks').forEach(function(task) {
        return task.set('isArchived', true);
      });
      return this.get('store').commit();
    }
  });

  App.AddTaskField = Ember.TextField.extend({
    valueBinding: 'newTaskTitle',
    insertNewline: function() {
      this.get('controller').addTask(this.get('value'));
      return this.set('value', '');
    }
  });

  App.TaskController = Ember.ObjectController.extend({
    taskDidChange: (function() {
      var _this = this;

      return Ember.run.once(function() {
        return _this.get('store').commit();
      });
    }).observes('isCompleted', 'title'),
    editTask: function() {
      return this.set('isEditing', true);
    },
    removeTask: function() {
      var task;

      task = this.get('model');
      task.deleteRecord();
      return this.get('store').commit();
    },
    back: function() {
      return history.back();
    }
  });

  App.EditTaskView = Ember.TextField.extend({
    classNames: ['edit'],
    valueBinding: 'task.title',
    focusOut: function() {
      return this.set('controller.isEditing', false);
    },
    insertNewline: function() {
      return this.set('controller.isEditing', false);
    },
    didInsertElement: function() {
      return this.$().focus();
    }
  });

  App.LogsController = Ember.ArrayController.extend({
    itemController: 'log',
    sortProperties: ['startedAt'],
    sortAscending: false,
    showGrouped: true,
    day: new Date(),
    content: (function() {
      return App.Log.all();
    }).property(),
    logsOnDay: (function() {
      var day,
        _this = this;

      day = moment(this.get('day'));
      return this.filter(function(log) {
        var start;

        start = moment(log.get('startedAt'));
        return start.isAfter(day.startOf('day')) && start.isBefore(day.endOf('day'));
      });
    }).property('@each.startedAt', 'day'),
    logsOnDayByTask: (function() {
      var aggregate, id, item;

      aggregate = this.get('logsOnDay').reduce(function(acc, log) {
        var id, item;

        id = log.get('task.id');
        item = acc[id] != null ? acc[id] : acc[id] = Ember.Object.create({
          task: log.get('task'),
          elapsedSeconds: 0
        });
        item.incrementProperty('elapsedSeconds', log.get('elapsedSeconds'));
        return acc;
      }, {});
      return Ember.ArrayController.create({
        content: (function() {
          var _results;

          _results = [];
          for (id in aggregate) {
            item = aggregate[id];
            _results.push(item);
          }
          return _results;
        })()
      });
    }).property('logsOnDay.@each.elapsedSeconds'),
    totalSecondsCompleted: (function() {
      return this.get('logsOnDay').reduce((function(acc, item) {
        return acc + item.get('elapsedSeconds');
      }), 0);
    }).property('logsOnDay.@each.elapsedSeconds'),
    isToday: (function() {
      return moment(this.get('day')).startOf('day').isSame(moment().startOf('day'));
    }).property('day'),
    showPrevious: function() {
      var day;

      day = moment(this.get('day'));
      return this.set('day', day.subtract('days', 1));
    },
    showNext: function() {
      var day;

      day = moment(this.get('day'));
      return this.set('day', day.add('days', 1));
    }
  });

  App.LogController = Ember.ObjectController.extend({
    needs: ['application'],
    time: Ember.computed.alias('controllers.application.time'),
    elapsedSeconds: (function() {
      if (this.get('model.isCompleted')) {
        return this.get('model.elapsedSeconds');
      } else {
        return Math.floor((this.get('time') - this.get('model.startedAt')) / 1000);
      }
    }).property('model.elapsedSeconds', 'model.isCompleted', 'time')
  });

  App.TimerController = Ember.ObjectController.extend({
    needs: ['application', 'tasks'],
    selectedTask: null,
    openTasks: Ember.computed.alias('controllers.tasks.openTasks'),
    isRunning: Ember.computed.alias('controllers.application.isRunning'),
    log: Ember.computed.alias('controllers.application.running.runningLog'),
    time: Ember.computed.alias('controllers.application.time'),
    elapsedSeconds: (function() {
      return Math.floor((this.get('time') - this.get('log.startedAt')) / 1000);
    }).property('log.startedAt', 'time'),
    stop: function() {
      this.set('selectedTask', null);
      return this.send('stopTimer', this.get('log.task'));
    },
    stopAndClose: function() {
      this.get('log.task').set('isCompleted', true);
      return this.stop();
    },
    start: function() {
      return this.send('startTimer', this.get('selectedTask'));
    }
  });

  App.TimerSelect = Ember.Select.extend({
    selectionDidChange: (function() {
      var _this = this;

      if (!this.get('selection')) {
        return;
      }
      return Ember.run.once(function() {
        return _this.get('controller').start();
      });
    }).observes('selection')
  });

  App.LOG_TRANSITIONS = true;

  App.Router.map(function() {
    this.resource('tasks', function() {
      return this.resource('task', {
        path: '/tasks/:task_id'
      });
    });
    this.resource('logs');
    return this.resource('timer');
  });

  App.ApplicationRoute = Ember.Route.extend({
    setupController: function(controller) {
      return App.Task.find().then(function() {
        return App.Log.find().then(function() {
          return Em.run.next(function() {
            return controller.set('isInitialized', true);
          });
        });
      });
    },
    events: {
      startTimer: function(task) {
        var log;

        log = task.get('logs').createRecord({
          startedAt: new Date()
        });
        task.set('runningLog', log);
        this.get('store').commit();
        return this.transitionTo('timer');
      },
      stopTimer: function(task) {
        task.set('runningLog.finishedAt', new Date());
        task.set('runningLog', null);
        this.get('store').commit();
        return this.transitionTo('task', task);
      }
    }
  });

  App.IndexRoute = Ember.Route.extend({
    redirect: function() {
      return this.transitionTo('timer');
    }
  });

  App.TasksRoute = Ember.Route.extend({
    model: function() {
      return App.Task.all();
    }
  });

  App.LogsRoute = Ember.Route.extend({
    model: function() {
      return App.Log.all();
    }
  });

  Ember.Handlebars.registerBoundHelper('time', function(date) {
    if (date != null) {
      return moment(date).format('HH:mm');
    } else {
      return "-";
    }
  });

  Ember.Handlebars.registerBoundHelper('monthDay', function(date) {
    return moment(date).format('MMMM D.');
  });

  Ember.Handlebars.registerBoundHelper('dayTime', function(date) {
    return moment(date).format('MMMM D. - HH:mm');
  });

  Ember.Handlebars.registerBoundHelper('duration', function(seconds) {
    var hour, min, sec;

    hour = Math.floor(seconds / 3600);
    min = Math.floor((seconds - hour * 3600) / 60);
    sec = seconds - hour * 3600 - min * 60;
    if (min < 10) {
      min = "0" + min;
    }
    if (sec < 10) {
      sec = "0" + sec;
    }
    if (hour === 0) {
      return "%@:%@".fmt(min, sec);
    } else {
      return "%@:%@:%@".fmt(hour, min, sec);
    }
  });

}).call(this);
