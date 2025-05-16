## Tests for Rate Limited Wget
#
# Copyright (C) 2025 by Joel Shprentz
# https://github.com/jshprentz/rate_limited_wget
# v0.0.1 (2025-05-15)
#
## Usage
#
# To run the development tests, download the rate limited wget project
# (typically with git clone), install the ShellSpec testing framework,
# and execute shellspec. For example,
#
#   git clone https://github.com/jshprentz/rate_limited_wget.git
#   wget -O- https://git.io/shellspec | sh
#   cd rate_limited_wget
#   shellspec
#
# ShellSpec: https://github.com/shellspec/shellspec#shellspec-full-featured-bdd-unit-testing-framework
#
## Begin Change Log
# 2025-05-15 0.0.1 The library emerges from the primordial ooze.
## End Change Log

Include 'lib/rate_limited_wget.sh'

Describe 'Rate limiter now'

  It 'provides the supplied time'
    When call rate_limit_now 12345
    The output should eq 12345
  End

  It 'provides a time not in the past'
    now_is_not_in_the_past() {
      now=`rate_limit_now`
      past=`date --date="5 seconds ago" "+%s"`
      test $now -gt $past
    }
    When call now_is_not_in_the_past
    The status should be success
  End

  It 'provides a time not in the future'
    now_is_not_in_the_future() {
      now=`rate_limit_now`
      future=`date --date="5 seconds" "+%s"`
      test $now -lt $future
    }
    When call now_is_not_in_the_future
    The status should be success
  End

End

Describe 'Rate limiter first'

  It 'returns first item'
    When call rate_limit_first a b c
    The status should be success
    The output should eq "a"
  End

  It 'fails with no items'
    When run rate_limit_first
    The status should be failure
  End

End

Describe 'Rate limiter remove first'

  It 'removes first item'
    When call rate_limit_remove_first a b c
    The status should be success
    The output should eq "b c"
  End

  It 'fails with no items'
    When run rate_limit_remove_first
    The status should be failure
  End

End

Describe 'Rate limiter last'

  It 'returns last item'
    When call rate_limit_last a b c d e f g h i j k l m n o p q r s t u v w x y z
    The status should be success
    The output should eq "z"
  End

  It 'fails with no items'
    When run rate_limit_last
    The status should be failure
  End

End

Describe 'Rate limiter initialization'

  setup_rate_limit_xyz() {
    init_rate_limit xyz 5 123
  }

  It 'sets up seconds'
    When call setup_rate_limit_xyz
    The value "$rl_seconds_xyz" should eq 123
  End

  Describe 'accessed from functions'

    Before 'setup_rate_limit_xyz'

    It 'sets up ready times'
      When call rate_limit_ready_times xyz
      The output should eq "1 2 3 4 5"
    End

  End

End

Describe 'Rate limiter'

  setup_rate_limit_xyz() {
    init_rate_limit xyz 3 17
  }

  Before 'setup_rate_limit_xyz'

  It 'is ready after initialization'
    When call rate_limit_is_ready 'xyz'
    The status should be success
    The output should be blank
  End

  Describe 'after some timed events'

      pass_time() {
        rate_limit_event xyz 100
        rate_limit_event xyz 200
        rate_limit_event xyz 300
      }

      Before 'pass_time'

    It 'is ready after enough time has passed'
      When call rate_limit_is_ready 'xyz' 400
      The status should be success
      The output should be blank
    End

    It 'is not ready before enough time has passed'
      When call rate_limit_is_ready 'xyz' 99
      The status should be failure
      The output should be blank
    End

    It 'waits until the next ready time'
      check_wait_time() {
        start_time=`date "+%s"`
        rate_limit_wait xyz 114
        end_time=`date "+%s"`
        duration=`expr $end_time - $start_time`
        test $duration -ge 2 && test $duration -le 5
      }
      When call check_wait_time
      The status should be success
    End

    It 'waits 0 seconds after the first ready time'
      check_wait_time() {
        start_time=`date "+%s"`
        rate_limit_wait xyz 118
        end_time=`date "+%s"`
        duration=`expr $end_time - $start_time`
        test $duration -ge 0 && test $duration -le 2
      }
      When call check_wait_time
      The status should be success
    End

    It 'throttles until the next ready time'
      check_throttle_time() {
        start_time=`date "+%s"`
        rate_limit_throttle xyz 115
        end_time=`date "+%s"`
        duration=`expr $end_time - $start_time`
        expr duration '>=' 1 '&' duration '<=' 4 > /dev/null
      }
      When call check_throttle_time
      The status should be failure
    End

    It 'throttle queues current time as a ready time'
      check_ready_times() {
        start_time=`date "+%s"`
        rate_limit_throttle xyz
        end_time=`date "+%s"`
        duration=`expr $end_time - $start_time`
        last_ready_time=$(rate_limit_last $(rate_limit_ready_times xyz))
        expr last_ready_time '>=' start_time '&' last_ready_time '<=' end_time > /dev/null
      }
      When call check_ready_times
      The status should be failure
    End

  End

End

Describe 'Multiple rate limiters'

  setup_rate_limits() {
    init_rate_limit abc 2 2
    init_rate_limit xyz 2 5
  }

  preload_events() {
    rate_limit_event abc
    rate_limit_event abc
    rate_limit_event xyz
    rate_limit_event xyz
  }

  Before 'setup_rate_limits' 'preload_events'

  It 'waits for all limits'
    check_wait_time() {
      start_time=`date "+%s"`
      wait_for_rate_limits abc xyz
      end_time=`date "+%s"`
      duration=`expr $end_time - $start_time`
      test $duration -ge 4 && test $duration -le 6
    }
    When call check_wait_time
    The status should be success
  End

  It 'rate limits events with different names'
    rate_limit_different_events() {
      start_time=`date "+%s"`
      rate_limit_events abc xyz
      end_time=`date "+%s"`
      last_abc=$(rate_limit_last $(rate_limit_ready_times abc))
      last_xyz=$(rate_limit_last $(rate_limit_ready_times xyz))
      status=1
      if [ `expr $last_abc + 3` -ne $last_xyz ]; then
        echo "last_abc:" $last_abc "+ 3 != last_xyz:" $last_xyz
      elif [ `expr $start_time + 1` -gt $last_abc ]; then
        echo "start_time:" $start_time "+ 1 > last_abc:" $last_abc
      elif [ `expr $start_time + 3` -lt $last_abc ]; then
        echo "start_time:" $start_time "+ 3 < last_abc:" $last_abc
      elif [ `expr $start_time + 4` -gt $last_xyz ]; then
        echo "start_time:" $start_time "+ 4 > last_xyz:" $last_xyz
      elif [ `expr $start_time + 6` -lt $last_xyz ]; then
        echo "start_time:" $start_time "+ 6 < last_xyz:" $last_xyz
      else
        status=0
      fi
      return $status
    }
    When call rate_limit_different_events
    The status should be success
  End

  It 'rate limits events with identical names'
    rate_limit_different_events() {
      start_time=`date "+%s"`
      rate_limit_events abc abc
      end_time=`date "+%s"`
      first_abc=$(rate_limit_first $(rate_limit_ready_times abc))
      last_abc=$(rate_limit_last $(rate_limit_ready_times abc))
      status=1
      if [ $first_abc -ne $last_abc ]; then
        echo "first_abc:" $first_abc "!= last_abc:" $last_abc
      elif [ `expr $start_time + 1` -gt $last_abc ]; then
        echo "start_time:" $start_time "+ 1 > last_abc:" $last_abc
      elif [ `expr $start_time + 3` -lt $last_abc ]; then
        echo "start_time:" $start_time "+ 3 < last_abc:" $last_abc
      else
        status=0
      fi
      return $status
    }
    When call rate_limit_different_events
    The status should be success
  End

End

Describe 'Initialization of wget rate limiters'

  wget_1_ready_times() {
    rate_limit_ready_times wget_1
  }

  wget_3_ready_times() {
    rate_limit_ready_times wget_3
  }

  It 'sets up a rate limit with two hosts'
    When call init_wget_rate_limit 5 50 example.com sample.com
    The value "$wget_rate_limits" should eq " example.com wget_1 sample.com wget_1"
    The value "$rl_seconds_wget_1" should eq 50
    The result of function wget_1_ready_times should eq "1 2 3 4 5"
  End

  Describe 'after setting up a rate limit with two hosts'

    setup_first_wget_rate_limit() {
      init_wget_rate_limit 5 50 example.com sample.com
    }

    Before 'setup_first_wget_rate_limit'

    It 'sets up a rate limit with one host'
      When call init_wget_rate_limit 4 60 foo.com
      The value "$wget_rate_limits" should eq " example.com wget_1 sample.com wget_1 foo.com wget_3"
      The value "$rl_seconds_wget_3" should eq 60
      The result of function wget_3_ready_times should eq "1 2 3 4"
    End

  End

End

Describe 'Extraction of hosts from arguments'

  wget_hosts_normalized() {
    echo `wget_hosts $*`
  }

  It 'finds a single host'
    When call wget_hosts https://example.com/foo/bar.html
    The output should eq "example.com"
  End

  It 'finds multiple hosts'
    When call wget_hosts_normalized https://example.com/foo/bar.html http://www.sample.com/blog/
    The output should eq "example.com www.sample.com"
  End

  It 'finds repeated hosts'
    When call wget_hosts_normalized https://www.sample.com/foo/bar.html http://www.sample.com/blog/
    The output should eq "www.sample.com www.sample.com"
  End

  It 'finds a host in typical wget arguments'
    When call wget_hosts -q "https://github.com/asterisk/dahdi-linux/commit/12345.patch" -O /tmp/12345..patch --no-cache
    The output should eq "github.com"
  End

End

Describe 'Host lookup to find range limits'

wget_rate_limits_for_hosts_normalized() {
    echo `wget_rate_limits_for_hosts $*`
  }

  setup_wget_rate_limit() {
    init_wget_rate_limit 5 50 example.com sample.com
    init_wget_rate_limit 4 60 sample.com www.sample.com
    init_wget_rate_limit 3 70 github.com
  }

  Before 'setup_wget_rate_limit'

  It 'finds a host and returns a name'
    When call wget_rate_limits_for_host example.com sample.com wget_1 example.com wget_2 foo.com wget_3
    The output should eq "wget_2"
  End

  It 'finds hosts and returns multiple names'
    When call wget_rate_limits_for_hosts_normalized github.com sample.com gitlab.com
    The output should eq "wget_5 wget_1 wget_3"
  End

End

Describe 'Rate limited wget'

  setup_example_wget_rate_limit() {
    init_wget_rate_limit 3 2 example.com
  }

  Before 'setup_example_wget_rate_limit'

  It 'runs wget with all supplied arguments'
    wget() {
      echo "$@"
    }
    When call rate_limited_wget -q "https://raw.githubusercontent.com/InterLinked1/astdocgen/master/astdocgen.php" -O astdocgen.php --no-cache
    The output should eq "-q https://raw.githubusercontent.com/InterLinked1/astdocgen/master/astdocgen.php -O astdocgen.php --no-cache"
    End

  It 'retains spaces and special characters in wget arguments'
    list_args() {
      for arg
      do
        echo "<<"$arg">>"
      done
    }
    wget() {
      echo `list_args "$@"`
    }
    When call rate_limited_wget "https://sample.com/foo.py" --requester "John O'Malley" --cost '$3.00'
    The output should eq "<<https://sample.com/foo.py>> <<--requester>> <<John O'Malley>> <<--cost>> <<"'$'"3.00>>"
    End

  It 'does not delay the first few requests'
    wget() {
      true
    }
    check_elapsed_time() {
      start_time=`date "+%s"`
      rate_limited_wget https://example.com/foo/bar.html
      rate_limited_wget https://example.com/foo/bar.html
      rate_limited_wget https://example.com/foo/bar.html
      end_time=`date "+%s"`
      duration=`expr $end_time - $start_time`
      test $duration -gt 1 && echo "duration > 1:" $duration && return 1
      return 0
    }
    When call check_elapsed_time
    The status should be success
  End

  It 'delays the request after the rate limit is satisfied'
    wget() {
      true
    }
    check_elapsed_time() {
      start_time=`date "+%s"`
      rate_limited_wget https://example.com/foo/bar.html
      rate_limited_wget https://example.com/foo/bar.html
      rate_limited_wget https://example.com/foo/bar.html
      rate_limited_wget https://example.com/foo/bar.html
      end_time=`date "+%s"`
      duration=`expr $end_time - $start_time`
      test $duration -lt 2 && echo "duration < 2:" $duration && return 1
      test $duration -gt 4 && echo "duration > 4:" $duration && return 1
      return 0
    }
    When call check_elapsed_time
    The status should be success
  End

  It 'delays requests after the rate limit is satisfied'
    wget() {
      sleep 1
    }
    check_elapsed_time() {
      start_time=`date "+%s"`
      rate_limited_wget https://example.com/foo/bar.html
      rate_limited_wget https://example.com/foo/bar.html
      rate_limited_wget https://example.com/foo/bar.html
      rate_limited_wget https://example.com/foo/bar.html
      rate_limited_wget https://example.com/foo/bar.html
      end_time=`date "+%s"`
      duration=`expr $end_time - $start_time`
      test $duration -lt 3 && echo "duration < 3:" $duration && return 1
      test $duration -gt 6 && echo "duration > 6:" $duration && return 1
      return 0
    }
    When call check_elapsed_time
    The status should be success
  End

End

# vim: tabstop=8: expandtab shiftwidth=2 softtabstop=2 autoindent
