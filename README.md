# Bash Script for Backing up Files

This script backs up one or more files to a target directory, and keeps rolling copies up to a set number.  For example, you could back up a file and the last 6 versions, with a structure that might look like:

```
testfile.txt
backups/testfile.txt.bak.1
backups/testfile.txt.bak.2
backups/testfile.txt.bak.3
backups/testfile.txt.bak.4
backups/testfile.txt.bak.5
```

The original file overwrites `1`, `1` overwrites `2`, `2` overwrites `3`, etc.

Real-world usage would be to run this in cron.  

## Options:

- **FILES_TO_BACKUP** `="$(pwd)/testfile.txt $(pwd)/test2.txt"` # Full path to the file you want to back up, add more files separated by spaces
- **FILE_BACKUP_EXTENSION** `=".bak"` # Extension to append to backup file including period. This can be blank
- **BACKUP_LOCATION** `="$(pwd)/backups/"` # Directory where backups should be stored, include trailing slash
- **COPIES_TO_KEEP** `="5"` # The number of old copies to keep

## Planning Improvements

- Read command-line variables so it's possible to overwrite the variables hard-coded in the sprint.  e.g. `./backup.sh --files=./testfile.txt --count=5 --target=./backups/ --ext=.bak` to make it a more general-purpose tool
