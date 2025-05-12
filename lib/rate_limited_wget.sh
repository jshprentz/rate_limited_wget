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

# rate_limit_now [time]
#
# Report the supplied or current time in Linux epoch seconds
#
# Arguments
#   The time to report (optional)
rate_limit_now() {
	if [ -n "$1" ]; then
		echo $1
	else
		date "+%s"
	fi
}

# rate_limit_first +items
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

# rate_limit_remove_first +items
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
	ready_times=`eval "echo "'$'"rl_ready_times_$1"`
	ready_time=`rate_limit_first $ready_times`
	now=`rate_limit_now $2`
	test $now -ge $ready_time
}

# vim: tabstop=8: autoindent
