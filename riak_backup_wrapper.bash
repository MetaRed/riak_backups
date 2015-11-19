#!/bin/bash
# 
# archives riak db and copies backups to AWS S3
# -rl

EMAIL=bigkahuna@meta.red
SERVER_NAME=$(hostname --fqdn)

# create riak bitcask archive on local drive
/path/to/backup/scripts/riak_backup_cron_script.bash
if [ ! $? -eq 0 ]; then
  echo "riak_backup_cron_script.bash exited with nonzero status" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
  exit 1
fi
# copy backups to s3/glacier and trim NAS to 10 days
/path/to/backup/scripts/archive_riak_backups_to_s3.bash
if [ ! $? -eq 0 ]; then
  echo "archive_riak_backups_to_s3.bash exited with nonzero status" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
  exit 1
fi
