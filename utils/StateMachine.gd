extends Reference

# StateMachine
#
# Object representing a state machine
#
# Create a State machine by providing it:
# 	- a target object concerned by the state machine
# 	- the name of the initial state
# 	- a list of state data describing the states 
# 	- a list of transitions data describing the transitions between the states
#
# The states data will be analysed first, then transitions
#
# About states:
# States can have parent states and sub states (*..* link)
# The highest states in the hierarchy should be first in the list provided
# States have list of actions to execute on the target object when: they're entered, they're updated, they're exited
# When entered, states will reset clocks that were listed in their data
# When entering a state that has sub states, the first sub state will be entered by default, recursively, until state has no sub state
#
# About transitions:
# Transitions link an initial state to a final state
# transitions have a list of guards
# All guards must be positive to execute the transition
# Guards can use the state machine's clocks to determine if they're valide
# When executing a transition, it'll reset its list of custom clocks (provided in its data) and execute a list of action on the target object
#
# About the general functionning:
# Call the update function during the target object's Loop
# Each turn it'll test all the transitions of its current state
# Starting from its highest parent and going bellow recurcively until testing its own transitions
# The first transition to test positive will be executed
# 
# Tips:
# 	Guards all take the state machine object as argument and can read all the clock's states
#	Actions all take the state machine and the loop delta as argument
# 	The global clock will be reseted at each state change, measuring the time since last transition
# 	Specific actions can be set at any moment:
# 		- When executing a particular transition
#		- When entering a specific state,
# 		- When staying on a specific state,
# 		- When leaving a specific state
#	Use parent states to share guards, actions and transitions to states who have similar behaviour
#

# {Object} target object concerned by the state machine
var object
# {Dictionary} Dictionary of existing states by name within this state machine
var states = {}
# {Dictionary} Dictionary of clocks by name, values are floats
var clocks = {}
# {Float} global clock, reseted at every new state reached
var clock
# {State} Current state
var current_state


# _init
# 
# constructor
#
# @param {Object} object : The target object concerned by the state machine
# @param {String} initial_state_name : The name of the initial state
# @param {(String|Dictionary)[]} states_data : Array of states' name or states' data
# @param {Dictionary[]} transitions_data : Array of transitions' data
#
#
func _init(object, initial_state_name, states_data, transitions_data):
	self.object = object

	# create and adds states and transitions in the state machine
	upgrade( states_data, transitions_data )
	# get the initial state
	var initial_state = states[initial_state_name]
	# enters initial state and set it as current state
	initial_state.enter(0)
	current_state = initial_state
	# initialises global clock
	clock = 0

# upgrade
#
# Function used to upgrade the state machine with new states and new transitions
# Doesn't handle yet overriding or deletion of old states
#
# @param {(String|Dictionary)[]} states_data : Array of states' name or states' data
# @param {Dictionary[]} transitions_data : Array of transitions' data
#
func upgrade( states_data, transitions_data ):
	add_states( states_data )
	add_transitions( transitions_data )

# add_states
#
# Function used to add states to the state machine
#
# @param {(String|Dictionary)[]} states_data : Array of states' name or states' data
#
func add_states( states_data ):
	for state_data in states_data:
		add_state( state_data )

# add_transitions
#
# Function used to add transitions to the state machine
#
# @param {Dictionary[]} transitions_data : Array of transitions' data
#
func add_transitions( transitions_data ):
	for transition_data in transitions_data:
		add_transition( transition_data )

# add_state
#
# Function used to add one state to the state machine
#
# @param {String|Dictionary} state_data : state's name or data
#
func add_state( state_data ):
	var state = State.new(state_data, self)
	# register the transition in the list of transitions
	# potentially erases an existing state, WARNING this isn't supported
	states[state.name] = state
	
# add_transitions
#
# Function used to add one transition to the state machine
#
# @param {Dictionary} transition_data : transition's data
#
func add_transition( transition_data ):
	var transition = Transition.new(transition_data, self)

# update
#
# Function that must be called during the update loop of the target object
# Increments clocks
# Test transitions of the current state and transition if possible
#
# @param {Float} delta: target object's loop duration
#
func update(delta):
	# increment custom clocks
	for clock_name in clocks:
		clocks[clock_name] += delta
	# increment the global state machine's clock
	clock += delta
	
	# test current state's transitions, returns null if no transition tested positive
	var transition = current_state.test_transitions()
	# if returned a transition
	if( transition ):
		# reset global clock
		clock = 0
		# exit current state
		current_state.exit(delta)
		# executes transition and get the new state
		var new_state = transition.exec(delta)
		# enter the new state and set it as current state
		new_state = new_state.enter(delta)
		current_state = new_state
	# if no transition returned, simply update the current state
	else:
		current_state.update(delta)
		
	


# State
#
# Represents a state in the state machine
# 
class State:
	# {StateMachine} reference to the StateMachine object holding the state
	var state_machine
	
	# {String} the name of the state
	var name
	
	# {String[]} names of the actions to execute when entering the state
	var on_enter_action_names = []
	# {String[]} names of the actions to execute when updating on the state
	var on_update_action_names = []
	# {String[]} names of the actions to execute when exiting the state
	var on_exit_action_names = []
	
	# {State[]} list of parent states
	var parent_states = []
	# {State[]} list of children states
	var sub_states = []
	
	# {Transition[]} list of transitions which entrance is connected to this state
	var transitions = []
	
	#  {String[]} list of the clocks names which will be reseted while entering the state
	var clocks_names = []
	
	# _init
	#
	# constructor
	#
	# @param {String|Dictionary} state_data : The name of the state or an object containing the state's data
	# @param {String} state_data.name : The name of the state
	# @param {String} [states_data.parent_state] : Name of the eventual parent state
	# @param {String[]} [states_data.parent_states] : Array of name of eventual parent states
	# @param {String} [on_enter_action] : Name of the function to call when entering the state
	# @param {String[]} [on_enter_actions] : Array of names of the functions to call when entering the state
	# @param {String} [on_update_action] : Name of the function to call when staying on the state
	# @param {String[]} [on_update_actions] : Array of names of the functions to call when staying on the state
	# @param {String} [on_exit_action] : Name of the function to call when exiting the state
	# @param {String[]} [on_exit_actions] : Array of names of the functions to call when exiting the state
	# @param {String} [clock] : Clock name the state will reset while entering
	# @param {String[]} [clocks] : List of clocks names the state will reset while entering
	# @param {Object} state_machine : The state machine object holding this state
	#
	func _init( state_data, state_machine ):
		self.state_machine = state_machine
		
		# if state_data is a string, it contains the name of the state
		if( typeof(state_data) == TYPE_STRING ):
			name = state_data
		
		# if state_data is a dictionary, it contains more complex data
		if( typeof(state_data) == TYPE_DICTIONARY ):
			name = state_data.name
			
			# parent_state(s) contains the names of the parents states
			# recover the state object from the state_machine object
			if( state_data.has("parent_state") ):
				var parent_state = state_machine.states[state_data.parent_state]
				parent_states.push_back(parent_state)
				# register to parent state as sub state
				parent_state.sub_states.push_back(self)
			if( state_data.has("parent_states") ):
				for parent_state_name in state_data.parent_states :
					var parent_state =  state_machine.states[parent_state_name] 
					parent_states.push_back(parent_state)
					# register to parent state as sub state
					parent_state.sub_states.push_back(self)
			
			# remember the on enter actions
			if( state_data.has("on_enter_action") ):
				on_enter_action_names.push_back( state_data.on_enter_action )
			if( state_data.has("on_enter_actions") ):
				for action_name in state_data.on_enter_actions:
					on_enter_action_names.push_back( action_name )
				
			# remember the on update actions
			if( state_data.has("on_update_action") ):
				on_update_action_names.push_back( state_data.on_update_action )
			if( state_data.has("on_update_actions") ):
				for action_name in state_data.on_update_actions:
					on_update_action_names.push_back( action_name )
			
			# remember the on exit actions
			if( state_data.has("on_exit_action") ):
				on_exit_action_names.push_back( state_data.on_exit_action )
			if( state_data.has("on_exit_actions") ):
				for action_name in state_data.on_exit_actions:
					on_exit_action_names.push_back( action_name )
			
			# create the given clocks in the state_machine object and reset them
			if( state_data.has("clock") ):
				state_machine.clocks[state_data.clock] = 0
			if( state_data.has("clocks") ):
				clocks_names = state_data.clocks
				for clock_name in clocks_names:
					state_machine.clocks[clock_name] = 0
	
	# enter
	#
	# Function called when entering the state
	#
	# @param {Float} delta : The game loop's duration
	#
	# @return {State} : the lowest level state entered
	#
	func enter(delta):
		# for each action names
		for on_enter_action_name in on_enter_action_names:
			# call the action on the target object
			state_machine.object.call(on_enter_action_name, state_machine, delta)
		
		# for each clock name
		for clock_name in clocks_names:
			# reset the clock
			state_machine.clocks[clock_name] = 0
		
		# if has sub states
		if( !sub_states.empty() ):
			# enter the first one and returns it
			return sub_states[0].enter()
		else:
			# otherwise return self
			return self
			
	# enter
	#
	# Function called to update the state
	#
	# @param {Float} delta : The game loop's duration
	#
	func update(delta):
		# call the update actions on the target object
		for on_update_action_name in on_update_action_names:
			state_machine.object.call(on_update_action_name, state_machine, delta)
	
	# exit
	#
	# Function called when exiting the state
	#
	# @param {Float} delta : The game loop's duration
	#
	func exit(delta):
		# call the exit actions on the target object
		for on_exit_action_name in on_exit_action_names:
			state_machine.object.call(on_exit_action_name, state_machine, delta)
	
	# test_transitions
	#
	# Test all transitions, including its parent's transition recursively.
	# Parents transitions are tested first. First transition positive is returned.
	#
	# @return {Transition|Null} the first transition which tested positive or null if none has returned positive
	#
	func test_transitions():
		var prioritary_transition
		
		# if has parents
		if( !parent_states.empty() ):
			# call test_transitions on each parents (recursion) 
			for parent_state in parent_states:
				prioritary_transition = parent_state.test_transitions()
				# first transition to test positive is returned instantly
				if( prioritary_transition ):
					break
		
		# call all state's transitions in the same fashion
		if( !prioritary_transition ):
			for transition in transitions:
				if( transition.test() ):
					prioritary_transition = transition
		
		return prioritary_transition

# Transition
#
# Represents a transition in the state machine
#
class Transition:
	# {StateMachine} the state machine object holding the transition
	var state_machine
	
	# {State} The transition's start point
	var initial_state
	# {State} THe transition's end point
	var final_state
	
	# {String[]} List of guards to satisfy to execute the transition
	var guard_names = []
	# {String[]} List actions to execute when executing the transition
	var action_names = []
	# {String[]} List of clocks to reset when executing the transition
	var clocks_names = []
	
	
	# _init
	#
	# constructor
	#
	# @param {Dictionary} transition_data : The transition's data
	# @param {String} initial_state : Initial state's name, the transition starts from this state
	# @param {String} final_state : Final state's name, the transition ends on this state
	# @param {String} [guard] : A function name to call in order to test if the transition should execute
	# @param {String[]} [guards] : A list functions names to call in order to test if the transition should execute
	# @param {String} [action] : A function name to call if the transition is executed
	# @param {String[]} [actions] : A list of functions names to call if the transition is executed
	# @param {String[]} [clocks] : A list of clocks names the transition will reset while executing
	#
	func _init( transition_data, state_machine ):
		self.state_machine = state_machine
		
		# gets the state objects instanciated before
		initial_state = state_machine.states[transition_data.initial_state]
		final_state = state_machine.states[transition_data.final_state]
		# subscribe to the initial state as transition
		initial_state.transitions.push_back(self)
		
		
		if( transition_data.has("guard") ):
			guard_names.push_back( transition_data.guard )
		if( transition_data.has("guards") ):
			for guard_name in transition_data.guards:
				guard_names.push_back( guard_name )
				
		if( transition_data.has("action") ):
			action_names.push_back( transition_data.action )
		if( transition_data.has("actions") ):
			for action_name in transition_data.actions:
				action_names.push_back( action_name )
			
		if( transition_data.has("clocks") ):
			clocks_names = transition_data.clocks
			for clock_name in clocks_names:
				state_machine.clocks[clock_name] = 0
	
	# test
	#
	# Test if the transition should be executed
	# All the guards should return true to validate the test
	# 
	# @return {Boolean} : the result of the tests
	#
	func test():
		var res = true
		# for each guard names
		for guard_name in guard_names:
			# call the guard on the state object
			res = res && state_machine.object.call(guard_name, state_machine)
			if (!res):
				break
		return res
	
	# exec
	#
	# Executes the transition
	# Executes all actions linked to the transition
	#
	# @param {Float} delta : The game loop's duration
	#
	# @return {State} : returns the final state reached by executing the transition
	func exec(delta):
		# for each actions names
		for action_name in action_names:
			# call the action on the target objet
			state_machine.object.call(action_name, state_machine, delta)
		
		# for each clocks names
		for clock_name in clocks_names:
			# reset the clock
			state_machine.clocks[clock_name] = 0
		
		return final_state
			