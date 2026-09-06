#! /usr/bin/env bash

hyprctl dispatch dpms off

libinput debug-events --device /dev/input/by-path/*-event-kbd | while read -r line; do
	hyprctl dispatch dpms on
	break
done
