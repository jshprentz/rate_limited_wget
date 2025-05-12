# init_rate_limit name event_count duration
#
# Initialize a rate limit
#
# Arguments
#   Name of the rate limit: unique shell variable name
#   Number of events allowed during some time period
#   Duration of the time period in seconds
#
# Globals Created
#   rl_seconds_<name>: duration of the time period in seconds
#   rl_ready_times_<name>: list of ready times in Linux epoch seconds,
#     initially times long before now

init_rate_limit() {
	eval "rl_seconds_$1=$3"
	eval "rl_ready_times_$1=\`seq $2\`"
}

# rate_limit_ready_times name
#
# Report ready times for the named rate limit 
#
# Arguments
#   Name of the rate limit: previously used by init_rate_limit
#
# Output
#   List of ready times in Linux epoch seconds
# 
# Returns
#   0 if successful; non-zero otherwise

rate_limit_ready_times() {
	eval "echo "'$'"rl_ready_times_$1"
}

# rate_limit_now [time]
#
# Report the supplied or current time in Linux epoch seconds
#
# Arguments
#   The time to report (optional)
#
# Output
#   The current or supplied time

rate_limit_now() {
	if [ -n "$1" ]; then
		echo $1
	else
		date "+%s"
	fi
}

# rate_limit_first item...
#
# Report the first item in a list
#
# Arguments
#   The items
#
# Output
#   The first item
#
# Returns
#   0 if the list has a first item; non-zero otherwise
rate_limit_first() {
	if [ $# -gt 0 ]; then
		echo "$1"
	else
		exit 1
	fi
}

# rate_limit_remove_first item...
#
# Remove the first item in a list
#
# Arguments
#   The items
#
# Output
#   The other items
#
# Returns
#   0 if the list has a first item; non-zero otherwise
rate_limit_remove_first() {
	if [ $# -gt 0 ]; then
		shift
		echo $*
	else
		exit 1
	fi
}

# rate_limit_last item...
#
# Report the last item in a list
#
# Arguments
#   The items
#
# Output
#   The last item
#
# Returns
#   0 if the list has a last item; non-zero otherwise

rate_limit_last() {
	if [ $# -gt 0 ]; then
		rate_limit_last_helper $# $*
	else
		exit 1
	fi
}

rate_limit_last_helper() {
	shift $1
	echo $1
}

# rate_limit_is_ready name [time]
#
# Test whether a rate limit is ready
#
# Arguments
#   Name of the rate limit: previously used by init_rate_limit
#   The time to check (optional, default now) in Linux Epoch seconds
# 
# Returns
#   0 if that name's first ready time is earlier than now
#   non-zero otherwise

rate_limit_is_ready() {
	ready_times=`rate_limit_ready_times $1`
	first_ready_time=`rate_limit_first $ready_times`
	now=`rate_limit_now $2`
	test $now -ge $first_ready_time
}

# rate_limit_event name [time]
#
# Record a rate limit event at a time, displacing the earliest recorded event
#
# Arguments
#   Name of the rate limit: previously used by init_rate_limit
#   The time to record (optional, default now) in Linux Epoch seconds
#
# Global variables updated
#   rl_ready_times_<name>: list of ready times in Linux epoch seconds
# 
# Returns
#   0 if successful; non-zero otherwise

rate_limit_event() {
	ready_times=`rate_limit_ready_times $1`
	retained_ready_times=`rate_limit_remove_first $ready_times`
	now=`rate_limit_now $2`
	eval "rl_ready_times_$1='$retained_ready_times $now'"
}

# rate_limit_wait name [time]
#
# Wait until a rate limit's first ready time 
#
# Arguments
#   Name of the rate limit: previously used by init_rate_limit
#   The current time (optional, default now) in Linux Epoch seconds
#
# Returns
#   The failing status of the test terminating the loop; this may be ignored

rate_limit_wait() {
	ready_times=`rate_limit_ready_times $1`
	now=`rate_limit_now $2`
	until rate_limit_is_ready $1 $now
	do
		sleep_time=$(expr $(rate_limit_first $ready_times) - $now)
		sleep $sleep_time
		now=`date "+%s"`
	done
}

# throttle name [time]
#
# Throttle an event using the named rate limit.
#
# Arguments
#   Name of the rate limit: previously used by init_rate_limit
#   The current time (optional, default now) in Linux Epoch seconds

rate_limit_throttle() {
	rate_limit_wait $*
	rate_limit_event $1
}

# vim: tabstop=8: autoindent
