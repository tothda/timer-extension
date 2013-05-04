### Dummy inverse property needed on App.Log

`_dummy: DS.belongsTo('App.Task', {inverse: 'runningLog'})`

Because of the following:

### Where to define the `completedTasks` property?

In the `TasksController`? If yes, it seems obvious that it is
dependent of the `model` property of the controller, which is populated by the `TasksRoute`.
However, we need to use the `completedTasks` property from the `timer`
controller even before `TasksRoute` has a chance the load the `model`
array.

### Auto-save

Instead of calling `store.commit()` in several places, it would be nice to have
some kind of auto-save mechanism.

Also odd the `taskDidChange` observer in `TaskController`. It fires every time
the `model` property is reset.