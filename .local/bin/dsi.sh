#!/bin/bash

case "$1" in
  wifi)
    title="Wifi"
    body=$(iwctl station wlan0 show | awk '
        /State/ { state = $2 }
        /Connected network/ { $1=""; $2=""; sub(/^ +/,""); ssid=$0 }
        /IPv4 address/ { ipv4 = $NF }
        END {
            if (state == "connected")
               printf "\nConnection [%s]\nIPv4 [%s]",ssid,ipv4
            else
               print "Disconnected"
        }
    ');;
  audio)
    v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)   # "Volume: 0.45 [MUTED]"
    pct=$(echo "$v" | awk '{print int($2*100) "%"}')
    case "$v" in *MUTED*) pct="$pct (muted)";; esac
    title="Volume"; body="$pct" ;;
  time)
    title=$(date '+%H:%M')
    body=$(date '+%A %d %B %Y') ;;
  battery)
    cap=$(cat /sys/class/power_supply/BAT0/capacity)
    st=$(cat /sys/class/power_supply/BAT0/status)
    title="Battery"; body="${cap}%  ${st}" ;;
  *)
    echo "usage: osd {wifi|audio|time|battery}" >&2; exit 1 ;;
esac

dunstify -r 9999 -t 2000 "$title" "$body"
