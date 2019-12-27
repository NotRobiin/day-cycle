#include <amxmodx>
#include <engine>

#define AUTHOR "Wicked - amxx.pl/user/60210-wicked/"

#define ForArray(%1,%2) for(new %1 = 0; %1 < sizeof %2; %1++)
#define ForRange(%1,%2,%3) for(new %1 = %2; %1 <= %3; %1++)

/*
	[ Defines setup ]
*/
#pragma semicolon 1

//#define DEBUG_MODE
#define TASK_CYCLE 1337


/*
	[ Const setup]
*/
#if defined DEBUG_MODE
new const debug_prefix[] = "[DEBUG]";
#endif

new const lighting_levels[] = "bcdefghijklmnopqrs"; // "a" - darkest, "z" - lightest. Cannot be mixed.
new const Float:lighting_interval = 2.5; // Determines how often the lights change.
new const lighting_default_level[] = "k"; // What level of light server starts with.
new const lighting_night_start[] = "k"; // When does the night start.

new const nativesData[][][] =
{
	{ "set_light", "native_set_light", 0 },
	{ "get_light", "native_get_light", 0 },

	{ "get_light_index", "native_get_light_index", 0 },
	{ "get_light_levels", "native_get_light_levels", 0 },

	{ "is_night", "native_is_night", 0 },
	{ "get_light_levels_count", "native_get_light_levels_count", 0 }
};

/*
	[ Enums ]
*/
enum forwardEnumerator(+= 1)
{
	forward_light_changed = 0,
	forward_day_part_changed
};

/*
	[ Variables ]
*/
new current_light[2],
	current_light_index,
	bool:lighting_enabled,
	bool:light_increment = true,
	bool:is_night,

	forward_handles[forwardEnumerator],
	dummy;


public plugin_init()
{
	register_plugin("Night/day cycle", "v0.1", AUTHOR);

	forward_handles[forward_light_changed] = CreateMultiForward("light_changed", ET_CONTINUE, FP_STRING);
	forward_handles[forward_day_part_changed] = CreateMultiForward("day_part_changed", ET_CONTINUE, FP_CELL);

	toggle_cycle(true);
}

/*
	[ Natives ]
*/
public plugin_natives()
{
	ForArray(i, nativesData)
	{
		register_native(nativesData[i][0], nativesData[i][1], nativesData[i][2][0]);
	}
}

public native_set_light(plugin, parameters)
{
	if(parameters != 1)
	{
		#if defined DEBUG_MODE
			log_amx("%s Function ^"set_light^" has invalid amount of arguments (%i). Required: %i.", debug_prefix, parameters, 1);
		#endif

		return;
	}

	new light[2];

	get_string(1, light, 1);

	set_light(light);
}

public native_get_light(plugin, parameters)
{
	if(parameters != 1)
	{
		#if defined DEBUG_MODE
			log_amx("%s Function ^"get_light^" has invalid amount of arguments (%i). Required: %i.", debug_prefix, parameters, 1);
		#endif

		return;
	}

	set_string(1, current_light, 1);
}

public native_get_light_index(plugin, parameters)
{
	if(parameters != 1)
	{
		#if defined DEBUG_MODE
			log_amx("%s Function ^"get_light_index^" has invalid amount of arguments (%i). Required: %i.", debug_prefix, parameters, 1);
		#endif

		return -1;
	}

	new light[2];

	get_string(1, light, 1);

	return get_light_index(light);
}

public native_get_light_levels(plugin, parameters)
{
	if(parameters != 1)
	{
		#if defined DEBUG_MODE
			log_amx("%s Function ^"get_light_levels^" has invalid amount of arguments (%i). Required: %i.", debug_prefix, parameters, 1);
		#endif

		return;
	}

	static lights[64];

	copy(lights, strlen(lighting_levels), lighting_levels);

	set_string(1, lights, strlen(lighting_levels));
}

public bool:native_is_night(plugin, parameters)
{
	return is_night;
}

public native_get_light_levels_count(plugin, parameters)
{
	return strlen(lighting_levels);
}

/*
	[ Functions ]
*/
public update_cycle()
{
	if(!lighting_enabled)
	{
		return;
	}

	static next_light[2];

	get_next_light(next_light);

	set_light(next_light);
}

get_next_light(next[])
{
	static index;

	// Determine if we want to increase or decrease lighting.
	if(current_light_index == strlen(lighting_levels) - 1)
	{
		light_increment = false;
	}
	else if(current_light_index == 0)
	{
		light_increment = true;
	}

	// Get index of next light.
	if(light_increment)
	{
		index = current_light_index + 1;
	}
	else
	{
		index = current_light_index - 1;
	}

	// Copy new lighting.
	copy(next, 1, lighting_levels[index]);
}

toggle_cycle(bool:status)
{
	lighting_enabled = status;

	// Remove update task.
	if(task_exists(TASK_CYCLE))
	{
		remove_task(TASK_CYCLE);
	}

	// Set new tasks and lighting if toggled on.
	if(status)
	{
		set_light(lighting_default_level);
		set_task(lighting_interval, "update_cycle", TASK_CYCLE, .flags = "b");
	}

	#if defined DEBUG_MODE
		log_amx("%s Toggled lighting cycle. (Status: %s) (Interval: %0.2f sec.) (Levels: %s).",
			debug_prefix,
			lighting_enabled ? "Enabled" : "Disabled",
			lighting_interval,
			lighting_levels);
	#endif
}

set_light(const level[])
{
	#if defined DEBUG_MODE
		log_amx("%s Executing set_light function with level: ^"%s^".", debug_prefix, level);
	#endif

	static length,
		light[2];

	copy(light, 1, level[0]);
	length = strlen(light);

	// Empty level was given.
	if(!length)
	{
		#if defined DEBUG_MODE
			log_amx("%s Tried to set light level to empty value.", debug_prefix);
		#endif

		return;
	}

	// Make sure given level is a valid character.
	if(!is_in_array(light))
	{
		#if defined DEBUG_MODE
			log_amx("%s Tried to set light level to ^"%s^".", debug_prefix, light);
		#endif

		return;
	}

	static old_day_part,
		old_light_index;

	copy(current_light, charsmax(current_light), light);

	// Get old values.
	old_day_part = is_night;
	old_light_index = current_light_index;
	current_light_index = get_light_index(current_light);

	// Update is_night.
	if(current_light_index > get_light_index(lighting_night_start))
	{
		is_night = false;
	}
	else
	{
		is_night = true;
	}

	// Execute forward of light change.
	if(current_light_index != old_light_index)
	{
		ExecuteForward(forward_handles[forward_light_changed], dummy, current_light);
	}

	// Execute forward of day-part change.
	if(is_night != bool:old_day_part)
	{
		ExecuteForward(forward_handles[forward_day_part_changed], dummy, is_night);
	}

	set_lights(light);

	#if defined DEBUG_MODE
		log_amx("%s Executed set_light function successfully. Level: ^"%s^".", debug_prefix, light);
	#endif
}

get_light_index(const light[])
{
	static character[2];

	ForRange(i, 0, strlen(lighting_levels) - 1)
	{
		copy(character, 1, lighting_levels[i]);

		if(!equal(character, light))
		{
			continue;
		}

		return i;
	}

	return -1;
}

bool:is_in_array(const needle[])
{
	static character[2];

	ForRange(i, 0, strlen(lighting_levels) - 1)
	{
		copy(character, 1, lighting_levels[i]);

		if(!equal(character, needle))
		{
			continue;
		}

		return true;
	}

	return false;
}