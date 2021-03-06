#!/bin/sh

ASSET_URL="https://spacenerdsinspace.com/snis-assets"
MANIFEST_URL="$ASSET_URL/manifest.txt"
PROG="$0"
MANIFEST_FILE=/tmp/snis_asset_manifest$$.txt
up_to_date_count=0
new_count=0
update_count=0
update_fail_count=0
export dryrun=0

sanity_check_environment()
{
	if [ ! -d share/snis/solarsystems ]
	then
		echo "$PROG"': Cannot find share/snis/solarsystems directory. Exiting.' 1>&2
		exit 1
	fi
	return 0
}

fetch_file()
{
	local URL="$1"
	local FILE="$2"
	local dryrun="$3"
	updating_or_creating="$4"
	if [ "$dryrun" != "0" ]
	then
		updating_or_creating="Not $updating_or_creating"
	fi
	echo -n 1>&2 "$updating_or_creating $FILE... "
	if [ "$dryrun" = "0" ]
	then
		wget --quiet "$1" -O - > "$FILE"
		if [ "$?" != "0" ]
		then
			/bin/rm -f "$FILE"
			echo 1>&2
			echo "$PROG"': Failed to fetch '"$URL" 1>&2
			return 1
		fi
	fi
	echo "done" 1>&2
	return 0
}

move_file()
{
	local dryrun="$1"
	local old="$2"
	local new="$3"
	if [ "$dryrun" = "0" ]
	then
		mv -f "$old" "$new"
	fi
	return $?
}

update_file()
{
	local checksum="$1"
	local filename="$2"
	if [ -f "$filename" ]
	then
		localchksum=$(md5sum $filename | awk '{ print $1 }')
		if [ "$localchksum" = "$checksum" ]
		then
			up_to_date_count=$((up_to_date_count + 1))
		else
			move_file "$dryrun" "$filename" "$filename".old
			if [ "$?" != "0" ]
			then
				echo "$PROG"':Cannot move old $filename out of the way, skipping' 1>&2
				update_fail_count=$((update_fail_count + 1))
			else
				fetch_file "$ASSET_URL"/"$filename" "$filename" "$dryrun" "Updating"
				if [ "$?" != "0" ]
				then
					update_fail_count=$((update_fail_count + 1))
				else
					update_count=$((update_count+1))
				fi
			fi
		fi
	else
		local dname=$(dirname "$filename")
		if [ ! -d "$dname" ]
		then
			if [ "$dryrun" = "0" ]
			then
				mkdir -p $dname
				if [ "$?" != "0" ]
				then
					echo "$PROG"': Failed to create directory for '"$filename" 1>&2
					update_fail_count=$((update_fail_count + 1))
				fi
			fi
		fi
		if [ -d "$dname" -o "$dryrun" != "0" ]
		then
			fetch_file $ASSET_URL/$filename $filename "$dryrun" "Creating"
			if [ "$?" = "0" ]
			then
				new_count=$((new_count+1))
			else
				update_fail_count=$((update_fail_count+1))
			fi
		fi
	fi
}

update_files()
{
	MANIFEST="$1"
	while (true)
	do
		read x
		if [ "$?" != "0" ]
		then
			break;
		fi
		update_file $x
	done < "$MANIFEST"
}

output_statistics()
{
	if [ "$dryrun" = "0" ]
	then
		updated="updated"
		new="new files"
	else
		updated="would be updated"
		new="new files would be created"
	fi

	echo
	echo "$up_to_date_count files already up to date"
	echo "$update_count files $updated"
	echo "$new_count $new"
	echo "$update_fail_count update failures"
	echo
}

if [ "$1" = "--dry-run" ]
then
	dryrun=1
	shift;
fi

sanity_check_environment
fetch_file "$MANIFEST_URL" "$MANIFEST_FILE" 0 "Fetching"
if [ "$?" != "0" ]
then
	exit 1
fi
update_files "$MANIFEST_FILE"
output_statistics

/bin/rm "$MANIFEST_FILE"

