#!/bin/bash
last=""

cd /tmp

play() {
  get_flash_videos -y -p --player "mplayer -really-quiet %s 2>/dev/null; rm %s" "$1"
}

while sleep 1; do
  clip="$(xclip -o)"

  # If changed
  if [ "${clip}x" != "${last}x" ]; then
    # Must be a http URL
    if [ "${clip/http:}" != "${clip}" ]; then
      # Looks like it might be a video..
      if [ "${clip/{watch,flv,show,video}}" != "${clip}" ]; then
        play "${clip}"
      fi
    fi
    last="${clip}"
  fi
done
