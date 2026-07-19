#!/bin/bash

image="/tmp/current-lock.png"
blurred="/tmp/current-lock-blur.png"

if [ -f $image ]; then
  rm $image
fi

if [ -f $blurred ]; then
  rm $blurred
fi

scrot $image
convert $image -blur 0x5 $blurred
i3lock -i $blurred --nofork
