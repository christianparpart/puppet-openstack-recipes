#! /bin/bash
# vim:ts=4:sw=4:noet:ai

NAME="$1"

if [[ "$NAME" != "" ]]; then
	nova list | grep -w "$NAME" | awk '{print $2}'
else
	echo "usage: os_instance_id INSTANCE_NAME"
fi
