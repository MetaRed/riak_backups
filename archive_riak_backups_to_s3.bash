#!/bin/bash
#
# Copy riak backup into S3
# -rl


# cron's path
PATH=$PATH:/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin

# set the desired umask
umask 002

# declare variables
EMAIL=bigkahuna@meta.red
BACKUP_DIR=/data/riak_backups
S3_BUCKET="s3://s3-link"
SERVER_NAME=$(hostname --fqdn)
LOG_DIR=/path/to/log/dir

# make sure our log directory exists
if [ ! -d $LOG_DIR ]; then
  mkdir $LOG_DIR
  if [ ! $? -eq 0 ]; then
    echo "Unable to create log dir: $LOG_DIR" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
    exit 1
  fi
else
  touch $LOG_DIR/test
  rm $LOG_DIR/test
  if [ ! $? -eq 0 ]; then
    echo "Unable to write to log dir: $LOG_DIR" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
    exit 1
  fi
fi

# make sure our local backup directory is writable
touch $BACKUP_DIR/test
rm $BACKUP_DIR/test
if [ ! $? -eq 0 ]; then
  echo "Unable to write to backup dir: $BACKUP_DIR" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
  exit 1
fi

# do s3 stuff
cd $BACKUP_DIR
for i in $(find $BACKUP_DIR -name "*.gz" -type f -daystart -mtime 0); do
sudo -u fxsync -i aws s3 cp $i $S3_BUCKET
if [ ! $? -eq 0 ]; then
       echo "Unable to copy backup file: $i to $S3_BUCKET" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
       S3_RETRY_COUNT=1
       until [ $S3_RETRY_COUNT -gt 3 ]; do
       echo "Retrying to copy backup file: $i to $S3_BUCKET for attempt number $S3_RETRY_COUNT" |mail -s "${0}: RE-TRY number $S3_RETRY_COUNT on $SERVER_NAME" $EMAIL
       sudo -u fxsync -i aws s3 cp $i $S3_BUCKET && break
       S3_RETRY_COUNT=$[$S3_RETRY_COUNT+1]
             if [ $S3_RETRY_COUNT -eq 4 ]; then
                 echo "AS root run the following:  sudo -u fxsync -i aws s3 cp $i $S3_BUCKET" |mail -s "${0}: FAILED ALL ATTEMPTS to COPY S3 BACKUP $SERVER_NAME" $EMAIL
                 exit 1
             fi
       done
fi
done

exit 0
