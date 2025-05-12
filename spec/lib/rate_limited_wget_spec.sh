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

Describe 'Rate limiter initialization'

  setup_rate_limit_xyz() {
    init_rate_limit xyz 5 123
  }

  It 'sets up seconds'
    When call setup_rate_limit_xyz
    The value "$rl_seconds_xyz" should eq 123
  End

  Describe 'as words'

    echo_ready_times() { echo $rl_ready_times_xyz; }

    Before 'setup_rate_limit_xyz'

    It 'sets up ready times'
      When call echo_ready_times
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

End

# vim: tabstop=8: expandtab shiftwidth=2 softtabstop=2 autoindent
