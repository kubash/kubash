#!/usr/bin/env bash
croak () {
    # The difference between squawk and croak is that croak calls exit 1 at the end
  # This function simplifies error reporting on death and verbosity
  # call it by preceding your error message with a verbosity level
  # e.g. `croak 3 "This is a croak"`
  # if the current verbosity level is greater than or equal to
  # the number given then this function will echo out your message
  # and pad it with # to let you now how verbose that message was
  croak_lvl=$1
  shift
  croak=$1
  shift
  croak_opt=$@

  if [[ -z $error_report_log ]]; then
    horizontal_rule
    echo "Error report log $error_report_log"
  fi

  horizontal_rule
  if [[ "$VERBOSITY" -ge "$croak_lvl" ]] ; then
    if [[ "$croak_lvl" -le 20 ]] ; then
      count_croak=0
      while [[ "$count_croak" -lt "$croak_lvl" ]]; do
        echo -n "#"
        count_croak=`expr $count_croak + 1`
      done
      echo " $croak"
    else
      echo -n '#{ '
      echo -n "$croak_lvl"
      echo -n " }#############"
      count_croak=0
      while [[ "$count_croak" -lt "$croak_lvl" ]]; do
        echo -n "#"
        count_croak=`expr $count_croak + 5`
      done
      echo -n '#{ '
      echo -n "$croak_lvl"
      echo -n ' }### '
      echo " $croak"
    fi
  else
    echo " $croak"
  fi
  horizontal_rule
  exit 1
}
