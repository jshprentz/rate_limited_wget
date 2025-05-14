# ========= Shell Utilities =========
#

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

# ========= Rate Limits =========
#

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

# rate_limit_seconds name
#
# Report the duration of the named rate limit
#
# Arguments
#   Name of the rate limit: previously used by init_rate_limit
#
# Output
#   Duration of the time period in seconds
#
# Returns
#   0 if successful; non-zero otherwise

rate_limit_seconds() {
	eval "echo "'$'"rl_seconds_$1"
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
	duration=`rate_limit_seconds $1`
	next_ready_time=`expr $now + $duration`
	eval "rl_ready_times_$1='$retained_ready_times $next_ready_time'"
}

# rate_limit_events name...
#
# Record rate limit events
#
# Arguments
#   Names of rate limits
#
# Global variables updated
#   rl_ready_times_<name>: list of ready times in Linux epoch seconds
#
# Returns
#   0 if successful; non-zero otherwise

rate_limit_events() {
	now=`rate_limit_now`
	for name
	do
		rate_limit_event $name $now
	done
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

#  wait_for_rate_limits name...
#
#  Wait until the ready times of the named rate limits
#
#  Arguments
#    Names of rate limits
#
# Returns
#   The failing status of the test terminating the loop; this may be ignored

wait_for_rate_limits() {
	for name
	do
		rate_limit_wait $name
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

# ========= Rate Limited Wget =========
#

# init_wget_rate_limit count duration host...
#
# Initialze a wget rate limit and assign it a name of the form "wget_<i>"
#
# Arguments
#   Number of events allowed during some time period
#   Duration of the time period in seconds
#   Hosts to which the rate limits apply
#
# Globals Created or Modified
#   wget_rate_limits: a mapping of hosts to rate limit names
#   rl_seconds_<name>: duration of the time period in seconds
#   rl_ready_times_<name>: list of ready times in Linux epoch seconds,
#     initially times long before now

init_wget_rate_limit() {
	name=`next_wget_name $wget_rate_limits`
	init_rate_limit $name $1 $2
	shift 2
	until [ $# -eq 0 ]
	do
		wget_rate_limits="$wget_rate_limits $1 $name"
		shift
	done
}

# next_wget_name wget_rate_limits
#
# Choose the next wget rate limit name
#
# Arguments
#   wget_rate_limits: a mapping of hosts to rate limit names
#
# Output
#   The new name

next_wget_name() {
	echo "wget_"$(expr $# / 2 + 1)
}

# wget_hosts arg...
#
# List hosts found among URLs in the arguments
#
# Arguments
#   wget arguments
#
# Output
#   HTTP hosts 

wget_hosts() {
	printf "%s\n" $* | sed -n -E 's/^https?:\/\/([^:/?]*).*/\1/p'
}

# wget_rate_limits_for_host host [host name]...
#
# Report the rate limit names for a host
#
# Arguments
#   Host for which to find rate limit names
#   [host name] pairs, typically from wget_rate_limits
#
# Output
#   Rate limit names

wget_rate_limits_for_host() {
	target_host="$1"
	shift
	until [ $# -eq 0 ]
	do
		if [ "$target_host" = "$1" ]
		then
			echo "$2"
		fi
		shift 2
	done
}

# wget_rate_limits_for_hosts host...
#
# Report the rate limit names for a list of hosts
#
# Arguments
#   Hosts
#
# Output
#   Rate limit names

wget_rate_limits_for_hosts() {
	until [ $# -eq 0 ]
	do
		wget_rate_limits_for_host $1 $wget_rate_limits
		shift
	done
}

# rate_limited_wget args
#
# Run wget with the supplied arguments after waiting for any rate limits
#
# Arguments
#   See wget(1), for example at https://www.gnu.org/software/wget/manual/wget.html
#
# Outputs
#   See wget(1)
#
# Status
#   See wget(1)
#
# Globals Created or Modified
#   rl_ready_times_<name>: list of ready times in Linux epoch seconds,
#     initially times long before now

rate_limited_wget() {
	hosts=`wget_hosts $*`
	rate_limits=`wget_rate_limits_for_hosts $hosts`
	wait_for_rate_limits $rate_limits
	wget !*
	status=$?
	rate_limit_events $rate_limits
	exit $status
}

# vim: tabstop=8: autoindent
