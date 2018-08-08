#!/bin/bash
#
#   Authored and Maintained by:
#   https://github.com/sebastientaggart/
#   sebastien.taggart@gmail.com
#
# MIT License
#
# Copyright (c) 2018 Sebastien Taggart
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Description:
#   This is a general purpose script I wrote primarily to back up SQL files.  It
#   takes a given file, and a given target location, and backs up that file.
#   Older file copies are retains up to the set limit, and the oldest file is
#   deleted as necessary.
#
#   This was originally adapted from https://superuser.com/questions/1164716/keeping-old-versions-of-bak-files

# Variables
FILES_TO_BACKUP="$(pwd)/testfile.txt" # Full path to the file you want to back up, add more files separated by spaces
    #  $(pwd)/test2.txt
FILE_BACKUP_EXTENSION=".bak" # Extension to append to backup file including period. This can be blank
BACKUP_LOCATION="$(pwd)/backups/" # Directory where backups should be stored, include trailing slash
    # Note that because we are specifying one backup location, if you specified
    # more than one FILES_TO_BACKUP all the backups would end up in this same
    # location.  Possible TODO: would be to have an array of files and corresponding
    # backup target directories.  Depends on usage though.
COPIES_TO_KEEP="5" # The number of old copies to keep

# TODO:
# - accept command line variables that overwrite defaults above

## Function to save/replace old copies of backups
function rotate_backups {
    # 'seq' generates a numerical sequence within a range, 1 - COPIES_TO_KEEP
    for count in $(seq ${COPIES_TO_KEEP} -1 1); do
        # Build the filename of this iteration, e.g. test.txt.1.bak
        old_backup="$(basename ${current_file})${FILE_BACKUP_EXTENSION}.${count}"
        # Check if this iteration exists, and is the oldest, delete it
        if [[ -e ${BACKUP_LOCATION}${old_backup} && ${count} == ${COPIES_TO_KEEP} ]]; then
            echo "Removing oldest backup file: ${BACKUP_LOCATION}${old_backup}"
            rm -f ${BACKUP_LOCATION}${old_backup}
        # If this iteration exists, but it's not the oldest one, then move it
        elif [[ -e ${BACKUP_LOCATION}${old_backup} ]]; then
            new_backup="$(basename ${current_file})${FILE_BACKUP_EXTENSION}.$(expr ${count} + 1)"
            echo "Replacing ${BACKUP_LOCATION}${old_backup} with ${BACKUP_LOCATION}${new_backup}"
            mv ${BACKUP_LOCATION}${old_backup} ${BACKUP_LOCATION}${new_backup}
        fi
    done
}

## Iterate though the list of files to back up
count=1
for current_file in ${FILES_TO_BACKUP} ; do
    # Iterate through our backups
    while [[ $count -le ${COPIES_TO_KEEP} ]] ; do
        # Build the filename, we use basename to extract the filename only
        backup_file="$(basename ${current_file})${FILE_BACKUP_EXTENSION}.${count}"
            # If this backup file exists already, then rotate backups
            if [[ -e ${BACKUP_LOCATION}${backup_file} ]] ; then
                # Call the rotate_backups function, with ${current_file} set
                rotate_backups
                # After backups are rotated, save the current file
                cp ${current_file} ${BACKUP_LOCATION}${backup_file}
                break
            # Else the backup files doesn't exist, so write it
            else
                cp ${current_file} ${BACKUP_LOCATION}${backup_file}
                break
            fi
        # Increment count so we stop looping when we count = COPIES_TO_KEEP
        count=$(expr ${count} + 1)
    done
done
