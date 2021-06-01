#!/bin/sh

# Polybar Player
# Copyright (C) 2021 Matthew Sirman, Ellie Clifford
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public
# License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# Handle command line options

## Defaults
MAXWIDTH=-1

while [ $# -gt 0 ]; do
	case $1 in
		-m|--maxwidth)
			shift
			if [ $# -lt 1 ]; then
				echo "ERROR: --maxwidth requires an argument"
				exit 1
			fi
			MAXWIDTH=$1
			shift
			if echo $MAXWIDTH | egrep -vq '[0-9]+'; then
				echo "ERROR: MAXWIDTH must be a non-negative integer"
				exit 1
			elif [ $MAXWIDTH -le 3 ]; then
				echo "ERROR: MAXWIDTH must be at least 4"
				exit 1
			fi
			;;
		*)
			echo "ERROR: Unsupported option"
			exit 1
			;;
	esac
done

title_error="Unknown Title"
artist_error="Unknown Artist"


# dash has no arrays but i NEEED SPEEED

# format of the "array"
# substring match:icon/name:arbitrary sed command to run on title:options
# currently options only matches "noartist"

# The escaping of the sed command is a nightmare, be warned

regex_url_mappings='
.*youtube.*:%{F#ff5555}%{F-}::noartist
.*twitch.*:%{F#ffffff}%{F-}:s/ - Twitch//:
'

regex_title_mappings="
.* - Twitch::s/ - Twitch//:
"

regex_player_mappings="
spotify:%{F#50fa7b}%{F-}::
firefox:::
chromium:Brave::
vlc:VLC::
"

found_currently_playing=0

if [ -f /tmp/polybar-player-current ]; then
	current_player=$(cat /tmp/polybar-player-current)
else
	current_player=''
fi

# we want to process the current player last for a smooth experience
# sadly -z is a GNUism but oh well
players=$(playerctl -l | sed -z "s/\(.*\)\($current_player\n\)\(.*\)/\1\3\2/")

set_from_map() { # takes $1: map, $2 thing to match on

	# Set separator to a newline character
	# for our fucked up data structure
	IFS="
"
	for map in $1; do
		regex=$( echo $map | sed 's/^\(.*\):\(.*\):\(.*\):\(.*\)/\1/')
		icon=$(  echo $map | sed 's/^\(.*\):\(.*\):\(.*\):\(.*\)/\2/')
		sedcmd=$(echo $map | sed 's/^\(.*\):\(.*\):\(.*\):\(.*\)/\3/')
		option=$(echo $map | sed 's/^\(.*\):\(.*\):\(.*\):\(.*\)/\4/')
		if echo $2 | egrep -q "$regex"; then
			suffix=$icon
			if ! [ "$sedcmd" = '' ]; then
				title=$(echo $title | sed "$sedcmd")
			fi
			break
		fi
	done
}

for player in $players
do
	if [ $(playerctl -p $player status) = 'Playing' ]; then
		found_currently_playing=1
	else
		if [ $found_currently_playing -eq 1 ]; then
			# We'd prefer an active player and we've already found one
			continue
		fi
	fi

	title=$( { playerctl -p $player metadata title; } 2>/dev/null )
	if [ $? -ne 0 ]; then
	    title=$title_error
	fi

	artist=$( { playerctl -p $player metadata artist; } 2>/dev/null )
	if [ $? -ne 0 ]; then
	    artist=$artist_error
	fi

	url=''
	if echo "$player" | grep -q "firefox"; then
		# Process firefox player if we can access it
		if [ -f $HOME/.mozilla/firefox/*.default-release/sessionstore-backups/recovery.jsonlz4 ]
		then
			# Just trust in the black magic please
			# Ignore jq stderr, as it sometimes encounters quoting issues from
			# the firefox json. It will then fall back on the firefox logo.
			url=$(lz4jsoncat $HOME/.mozilla/firefox/*.default-release/sessionstore-backups/recovery.jsonlz4 \
				| jq "$(echo '.windows[] | .tabs[] | .entries[] ' \
					'| select(.title != null) | select(.title ' \
					'| contains("'"$(playerctl -p $player metadata title)"'")) ' \
					'| .url')" 2>/dev/null \
				| sed 's/^"//;s/"$//')
		fi
	fi

	if [ "$title" = "$title_error" ] && [ "$artist" = "$artist_error" ]; then
	    continue
	fi

	current_player=$player
	suffix="${player} (Unknown)" # Default

	set_from_map "$regex_player_mappings" "$player"
	set_from_map "$regex_title_mappings"  "$title"   # Titles take precedence
	set_from_map "$regex_url_mappings"    "$url"     # URLs take even more precedence
done



# write the player to a temp file for the play-pause script
# logic for if current_player = '' is on the other side
echo -n $current_player > /tmp/polybar-player-current

# Don't introduce a trailing - if there's no artist
# Don't include suffix until after comparing to MAXWIDTH
# (because it has ANSI codes in it)
if echo $artist | egrep -q '^[ \t]*$' \
	|| echo $option | grep -q 'noartist';
then
	out="$title"
else
	out="$title  -  $artist"
fi
if [ $MAXWIDTH -ne -1 ] && [ $(echo "$out" | wc -m) -gt $MAXWIDTH ]; then
	echo "  $(echo "$out" \
		| head -c $(echo "$MAXWIDTH - 3" | bc -l))...     $suffix"
else
	echo "  $out     $suffix"
fi
