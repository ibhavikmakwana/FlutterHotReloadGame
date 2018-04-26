import "dart:math";
import "command_tasks.dart";
import "icon_tasks.dart";
import "corner_radius_tasks.dart";

const int NumGameTasks = 30;

typedef String CodeUpdateStep(String code, List<CommandTask> availableTasks);

class TaskList
{
	List<CommandTask> _available = <CommandTask>[];

	List<CommandTask> allTasks = <CommandTask>
	[
		new FontSizeCommand(),
		new ListCornerRadius(),
		new FeaturedCornerRadius(),
		new AppPadding(),
		new SetBackgroundColor(),
		new AddIconATask(),
		new AddIconBTask(),
		new CarouselIcons(),
		new AddImages(),
		new ShowRatings(),
		new ShowDeliveryTimes(),
		new DollarSigns(),
		new CondenseListItems(),
		new CategoryFontWeight(),
		new ImageWidthTask(),
		new FontFamily()
	];

	int _tasksCompleted = 0;
	int _tasksAssigned = 0;
	int _completionsPerUpdate = 0;
	int _appliedUpdateIndex = -1;
	Random _rand = new Random();

	List<CodeUpdateStep> _automaticUpdates = <CodeUpdateStep>
	[
		(String code, List<CommandTask> availableTasks)
		{
			return code.replaceAll("CategorySimple", "CategoryAligned");
		},
		(String code, List<CommandTask> availableTasks)
		{
			return code.replaceAll("FeaturedRestaurantSimple", "FeaturedRestaurantAligned");
		},
		(String code, List<CommandTask> availableTasks)
		{
			return code.replaceAll("RestaurantsHeaderSimple", "RestaurantsHeaderAligned");
		},
		(String code, List<CommandTask> availableTasks)
		{
			availableTasks.add(new AddIconATask());
			availableTasks.add(new AddIconBTask());
			return code.replaceAll("CategoryAligned", "CategoryDesigned");
		},
		(String code, List<CommandTask> availableTasks)
		{
			return code.replaceAll("ListRestaurantSimple", "ListRestaurantAligned");
		},
		(String code, List<CommandTask> availableTasks)
		{
			return code.replaceAll("RestaurantsHeaderAligned", "RestaurantsHeaderDesigned");
		},
		(String code, List<CommandTask> availableTasks)
		{
			availableTasks.add(new CarouselIcons());
			return code.replaceAll("FEATURED_RESTAURANT_SIZE", "304.0");
		},
		(String code, List<CommandTask> availableTasks)
		{
			//availableTasks.add(new AddImages());
			return code.replaceAll("ListRestaurantAligned", "ListRestaurantDesigned");
		}
	];
	
	TaskList(this._completionsPerUpdate)
	{
		for(CommandTask task in allTasks)
		{
			if(!task.isDelayed())
			{
				_available.add(task);
			}
		}
	}

	bool get isEmpty
	{
		return _tasksAssigned > NumGameTasks;
	}
	
	String completeTask(String code)
	{
		_tasksCompleted++;
		int idx = _tasksCompleted ~/ _completionsPerUpdate;
		if(_appliedUpdateIndex != idx)
		{
			_appliedUpdateIndex = idx;
			if(idx < _automaticUpdates.length)
			{
				return _automaticUpdates[idx](code, _available);
			}
		}

		return code;
	}

	double get progress
	{
		double idx = _tasksCompleted / _completionsPerUpdate;
		return (idx / (_completionsPerUpdate * _automaticUpdates.length)).clamp(0.0, 1.0);
	}

	CommandTask setTaskValue(String taskType, int value)
	{
		for(CommandTask task in allTasks)
		{
			if(task.taskType() == taskType)
			{
				task.setCurrentValue(value);
				return task;
			}
		}
		return null;
	}
	
	IssuedTask nextTask(List<CommandTask> avoid, {double timeMultiplier = 1.0, List<CommandTask> lowerChance})
	{
		if(isEmpty)
		{
			return null;
		}
		const int highChanceWeight = 3;
		const int lowChanceWeight = 1;
		const int lowerWeightSeconds = 8;

		DateTime now = new DateTime.now();
		//List<String> avoidTypes = avoid.map((CommandTask task) { return task.taskType(); });
		for(int sanity = 0; sanity < 100; sanity++)
		{
			List<CommandTask> valid = new List<CommandTask>();
			for(CommandTask task in _available)
			{
				if(!task.isPlayable)
				{
					// A widget for this task wasn't assigned to any player.
					// This can happen if there are more tasks assignable than
					// total number of widget slots for all clients.
					// For example: two players (clients)
					// Widgets total: 16
					// The clients can only show a combined set of 10 widgets
					// So the last 6 cannot be assigned.
					// We track this by marking isPlayable to true when widgets
					// are assigned to clients at the start of the game.
					continue;
				}
				// Certain tasks we want to make sure do not get issued
				// We leave this up to the implementer but generally this
				// is the list of tasks that are already assigned.
				CommandTask avoidTask = avoid.firstWhere((CommandTask check)
				{
					return check.taskType() == task.taskType();
				}, orElse:()=>null);
				
				if(avoidTask == null)
				{
					// We also allow for a list of lower chance tasks.
					// If the task we are checking is in this list, we add it
					// less times to our valid stack such that it has lower
					// odds of being picked.
					CommandTask lowChanceTask = lowerChance.firstWhere((CommandTask check)
					{
						return check.taskType() == task.taskType();
					}, orElse:()=>null);
					
					int weight = lowChanceTask == null ? highChanceWeight : lowChanceWeight;

					int secondsSinceIssue = now.difference(task.lastIssued).inSeconds;
					
					if(secondsSinceIssue < lowerWeightSeconds)
					{
						// Task was issued recently, don't re-issue it.
						weight = 0;
					}
					else
					{
						// Weight task by lowerWeightSeconds since issue (provided it's less than the currently established weight).
						// This lets task gradually come back to high chance after 30 seconds.
						weight = min(weight, ((secondsSinceIssue-lowerWeightSeconds)/lowerWeightSeconds).floor());
					}
					
					for(int i = 0; i < weight; i++)
					{
						valid.add(task);
					}
				}
			}
			CommandTask chosenTask = valid[_rand.nextInt(valid.length)];
			IssuedTask issuedTask = chosenTask.issue();
			if(issuedTask != null)
			{
				chosenTask.lastIssued = new DateTime.now();
				_tasksAssigned++;
				issuedTask.expires = (issuedTask.expires*timeMultiplier).round();
				return issuedTask;
			}
			else
			{
				// Could not issue this command, remove it from the list.
				_available.remove(chosenTask);
			}
		}
		return null;
	}

	// void buildIssueList()
	// {
	// 	Random rand = new Random();
	// 	const int MaxLoop = 5000;
	// 	for(int counter = 0; _toIssue.length < NumGameTasks && counter < MaxLoop; counter++)
	// 	{
	// 		if(_highPrioriy.length > 0)
	// 		{
	// 			int index = rand.nextInt(_highPrioriy.length);
	// 			_highPrioriy.removeAt(index).tryToIssue(_toIssue);
	// 			continue;
	// 		}
	// 		int index = rand.nextInt(_available.length);
	// 		_available[index].tryToIssue(_toIssue);
	// 	}

	// 	for(IssuedTask t in _toIssue)
	// 	{
	// 		String lookingForType = t.task.taskType();
	// 		CommandTask found = allTasks.firstWhere((CommandTask t)
	// 		{
	// 			return t.taskType() == lookingForType;
	// 		}, orElse:(){ return null; });
	// 		if(found == null)
	// 		{
	// 			allTasks.add(t.task);
	// 		}
	// 	}
	// }
}