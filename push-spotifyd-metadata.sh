#!/bin/sh

mkdir -p /tmp/polybar-player
if [ "$PLAYER_EVENT" = "start" ] || [ "$PLAYER_EVENT" = "change" ]; then
	playerctl -p spotifyd metadata title > /tmp/polybar-player/spotifyd-title
	playerctl -p spotifyd metadata artist > /tmp/polybar-player/spotifyd-artist
	echo "Playing" > /tmp/polybar-player/spotifyd-status
elif [ "$PLAYER_EVENT" = "play" ]; then
	echo "Playing" > /tmp/polybar-player/spotifyd-status
elif [ "$PLAYER_EVENT" = "pause" ]; then
	echo "Paused" > /tmp/polybar-player/spotifyd-status
fi


