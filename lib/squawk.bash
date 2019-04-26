#!/usr/bin/env bash
squawk () {
  # This function simplifies error reporting and verbosity
  # and it always prints its message along with anything in $error_report_log
  # call it by preceding your message with a verbosity level
  # e.g. `squawk 3 "This is a squawk"`
  # if the current verbosity level is greater than or equal to
  # the number given then this function will echo out your message
  # and pad it with # to let you now how verbose that message was
  squawk_lvl=$1
  shift
  squawk=$1
  shift
  squawk_opt=$@

  if [[ "$VERBOSITY" -ge "$squawk_lvl" ]] ; then
    if [[ "$squawk_lvl" -le 20 ]] ; then
      count_squawk=0
      while [[ "$count_squawk" -lt "$squawk_lvl" ]]; do
        echo -n "#"
        count_squawk=`expr $count_squawk + 1`
      done
      echo " $squawk"
    else
      echo -n '#{ '
      echo -n "$squawk_lvl"
      echo -n " }#############"
      count_squawk=0
      while [[ "$count_squawk" -lt "$squawk_lvl" ]]; do
        echo -n "#"
        count_squawk=`expr $count_squawk + 5`
      done
      echo -n '#{ '
      echo -n "$squawk_lvl"
      echo -n ' }### '
      echo " $squawk"
    fi
  fi
}
