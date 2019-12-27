#include <amxmodx>
#include <engine>

#define AUTHOR "Wicked - amxx.pl/user/60210-wicked/"

#define ForArray(%1,%2) for(new %1 = 0; %1 < sizeof %2; %1++)
#define ForRange(%1,%2,%3) for(new %1 = %2; %1 <= %3; %1++)

/*
	[ Defines ]
*/
#pragma semicolon 1

//#define DEBUG_MODE
#define TASK_CYCLE 1337


/*
	[ Consts ]
*/
#if defined DEBUG_MODE
new const debug_prefix[] = "[DEBUG]";
#endif

new const cvarsData[][][] =
{
	{ "dc_lighting_levels", "bcdefghijklmnopqrs" },
	{ "dc_lighting_interval", "60.0" },
	{ "dc_lighting_default_level", "k" },
	{ "dc_lighting_night_start", "k" },
	{ "dc_lighting_cycles_per_map", "5" }
};

new const nativesData[][][] =
{
	{ "set_light", "native_set_light", 0 },
	{ "get_light", "native_get_light", 0 },

	{ "get_light_index", "native_get_light_index", 0 },
	{ "get_light_levels", "native_get_light_levels", 0 },
	{ "get_light_levels_count", "native_get_light_levels_count", 0 },

	{ "is_night", "native_is_night", 0 }
};

/*
	[ Enums ]
*/
enum forwardEnumerator (+= 1)
{
	forward_light_changed = 0,
	forward_day_part_changed
};

enum cvarEnumerator (+= 1)
{
	cvar_lighting_levels,
	cvar_lighting_interval,
	cvar_lighting_default_level,
	cvar_lighting_night_start,
	cvar_lighting_cycles_per_map
};

/*
	[ Variables ]
*/
new current_light[2],
	current_light_index,
	bool:lighting_enabled,
	bool:light_increment = true,
	bool:is_night,

	lighting_levels[64],

	forward_handles[forwardEnumerator],
	forward_dummy,

	cvar_handles[cvarEnumerator],
	cvar_dummy[64];


public plugin_init()
{
	register_plugin("Night/day cycle", "v1.0", AUTHOR);

	forward_handles[forward_light_changed] = CreateMultiForward("light_changed", ET_CONTINUE, FP_STRING);
	forward_handles[forward_day_part_changed] = CreateMultiForward("day_part_changed", ET_CONTINUE, FP_CELL);

	ForArray(i, cvarsData)
	{
		cvar_handles[cvarEnumerator:i] = register_cvar(cvarsData[i][0], cvarsData[i][1]);
	}

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

	get_pcvar_string(cvar_handles[cvar_lighting_levels], cvar_dummy, strlen(cvar_dummy));

	set_string(1, cvar_dummy, strlen(cvar_dummy));
}

public bool:native_is_night(plugin, parameters)
{
	return is_night;
}

public native_get_light_levels_count(plugin, parameters)
{
	get_pcvar_string(cvar_handles[cvar_lighting_levels], cvar_dummy, strlen(cvar_dummy));

	return strlen(cvar_dummy);
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

	get_pcvar_string(cvar_handles[cvar_lighting_levels], cvar_dummy, strlen(cvar_dummy));

	if(!strlen(cvar_dummy))
	{
		return;
	}

	static next_light[2];

	get_next_light(next_light);

	set_light(next_light);
}

get_next_light(next[])
{
	get_pcvar_string(cvar_handles[cvar_lighting_levels], cvar_dummy, strlen(cvar_dummy));

	if(!strlen(cvar_dummy))
	{
		return;
	}

	static index;

	// Determine if we want to increase or decrease lighting.
	if(current_light_index == strlen(cvar_dummy) - 1)
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
	copy(next, 1, cvar_dummy[index]);
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
		new Float:interval = get_pcvar_float(cvar_handles[cvar_lighting_interval]);

		get_pcvar_string(cvar_handles[cvar_lighting_default_level], cvar_dummy, strlen(cvar_dummy));

		set_light(cvar_dummy);

		if(interval == -1.0)
		{
			interval = (get_cvar_num("mp_timelimit") / get_pcvar_num(cvar_handles[cvar_lighting_cycles_per_map])) * 60.0;
		}

		set_task(interval, "update_cycle", TASK_CYCLE, .flags = "b");
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
	if(!strlen(lighting_levels))
	{
		return;
	}

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

	get_pcvar_string(cvar_handles[cvar_lighting_night_start], cvar_dummy, charsmax(cvar_dummy));

	// Update is_night.
	if(current_light_index > get_light_index(cvar_dummy))
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
		ExecuteForward(forward_handles[forward_light_changed], forward_dummy, current_light);
	}

	// Execute forward of day-part change.
	if(is_night != bool:old_day_part)
	{
		ExecuteForward(forward_handles[forward_day_part_changed], forward_dummy, is_night);
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