#!/bin/bash

# AeroSpace workspace indicator plugin for SketchyBar
# Highlights the currently focused workspace

WORKSPACE_ID=$1

if [ "$FOCUSED_WORKSPACE" = "$WORKSPACE_ID" ]; then
  sketchybar --set $NAME \
    background.drawing=on \
    background.color=0xff7aa2f7 \
    label.color=0xff000000
else
  sketchybar --set $NAME \
    background.drawing=off \
    label.color=0x80ffffff
fi
