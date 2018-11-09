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
#   This is a script designed for AWS, to run on an EC2 that has access to an
#   S3 bucket.  This will take one or more files and back them up to S3, using
#   the AWS CLI, and assuming that the correct permissions are set.  It has the
#   option to rotate the file backups as needed.

## ASSUMPTIONS
# - aws cli is installed
# - aws cli has access to S3 bucket, either using a key or IAM role, etc.
# - gzip is installed
# - a .env file exists with:
#   - PROJECT_NAME - used to generate backup filenames and paths, e.g. BACKUP_BUCKET
#   - DB_USER
#   - DB_PASSWORD
#   - DB_NAME - name of mysql db to dump
#   - BACKUP_BUCKET - with the path, e.g. "s3://mybucketname/db-${PROJECT_NAME}/integration/"
# NOTE: if you set the options below in the .env, they will override everything else.
#   e.g. if you have COPIES_TO_KEEP in your .env, it doesn't matter what you pass,
#   or what you set in this file, the .env value will override.

## OPTIONS
# These are overwritten with command-line variables below
ENV_FILE="$(pwd)/.env" # This can be any text file with bash variables set inside it
FILES_TO_BACKUP="$(pwd)/testfile.txt" # Full path to the file you want to back up, add more files separated by spaces
    #  $(pwd)/test2.txt
FILE_BACKUP_EXTENSION=".bak" # Extension to append to backup file including period. This can be blank
BACKUP_LOCATION="$(pwd)/backups/" # Directory where backups should be stored, include trailing slash
    # Note that because we are specifying one backup location, if you specified
    # more than one FILES_TO_BACKUP all the backups would end up in this same
    # location.  Possible TODO: would be to have an array of files and corresponding
    # backup target directories.  Depends on usage though.
COPIES_TO_KEEP="5" # The number of old copies to keep

## COMMAND LINE VARIABLES
#
# Command: backup
# -f FILES_TO_BACKUP
# -e FILE_BACKUP_EXTENSION
# -l BACKUP_LOCATION
# -c COPIES_TO_KEEP
#
# Command: restore
#

# Get the passed arguments
args=("$@")

# Make sure we have at least one
if [[ $# -lt 1 ]]; then
    echo "ERROR: you must supply a command, e.g. restore or backup"
    exit 1
fi

# Read the values passed from the command line
while getopts f:e:l:c:n: option
do
case "${option}"
in
f) FILES_TO_BACKUP=${OPTARG};;
e) FILE_BACKUP_EXTENSION=${OPTARG};;
l) BACKUP_LOCATION=${OPTARG};;
c) COPIES_TO_KEEP=$OPTARG;;
n) ENV_FILE=$OPTARG;;
esac
done

# Check if a .env file is set, error out if not set or not found
if [ ! -f ${ENV_FILE} ]; then
    echo "ERROR: ${ENV_FILE} does not exist, please add one, or pass it via -n"
    exit 1
fi

# Load the variables in the .env
# NOTE: This overwrites any command line or hard-coded options above
source ${ENV_FILE}

# Sanity check to verify we have access to S3 bucket, and it exists
if [ ! aws s3api head-bucket --bucket "${BACKUP_BUCKET}" 2>/dev/null ]; then
    echo "ERROR: Access check to ${BACKUP_BUCKET} failed.  Check that you have access to this bucket."
    exit 1
fi

### Actions

## Backup

# Export the Database
# TODO: this assumes ${PROJECT_NAME}_mariadb, change this for portability later
# TODO: this assumes db/${PROJECT_NAME}.sql, change this for portability later
docker exec -i ${PROJECT_NAME}_mariadb /bin/bash -c "export TERM=xterm && mysqldump -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME}" | gzip > db/${PROJECT_NAME}.sql.gz

## Rotate our backups into ${BACKUP_LOCATION}, keeping ${COPIES_TO_KEEP}
# Operations are executed directly on S3 bucket defined in ${BACKUP_BUCKET}

# Function to save/replace old copies of backups
function rotate_backups {
    # 'seq' generates a numerical sequence within a range, 1 - COPIES_TO_KEEP
    for count in $(seq ${COPIES_TO_KEEP} -1 1); do
        # Build the filename of this iteration, e.g. test.txt.1.bak
        old_backup="$(basename ${current_file})${FILE_BACKUP_EXTENSION}.${count}"
        # Check if this iteration exists, and is the oldest, delete it
        if [[ -e ${BACKUP_LOCATION}${old_backup} && ${count} == ${COPIES_TO_KEEP} ]]; then
            #rm -f ${BACKUP_LOCATION}${old_backup}
            aws s3 rm ${BACKUP_BUCKET}${old_backup}
        # If this iteration exists, but it's not the oldest one, then move it
        elif [[ -e ${BACKUP_LOCATION}${old_backup} ]]; then
            new_backup="$(basename ${current_file})${FILE_BACKUP_EXTENSION}.$(expr ${count} + 1)"
            #mv ${BACKUP_LOCATION}${old_backup} ${BACKUP_LOCATION}${new_backup}
            aws s3 mv ${BACKUP_BUCKET}${old_backup} ${BACKUP_BUCKET}${new_backup}
        fi
    done
}

# Iterate though the list of files to back up
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
                #cp ${current_file} ${BACKUP_LOCATION}${backup_file}
                aws s3 cp ${current_file} ${BACKUP_BUCKET}${backup_file}
                break
            # Else the backup files doesn't exist, so write it
            else
                #cp ${current_file} ${BACKUP_LOCATION}${backup_file}
                aws s3 cp ${current_file} ${BACKUP_BUCKET}${backup_file}
                break
            fi
        # Increment count so we stop looping when we count = COPIES_TO_KEEP
        count=$(expr ${count} + 1)
    done
done
