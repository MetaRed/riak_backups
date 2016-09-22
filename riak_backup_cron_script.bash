#!/bin/bash
#
# Copy Riak nodes with bitcask backend to local directory
#
# by RL

# cron's path
PATH=$PATH:/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin

# set the desired umask
umask 002

# declare variables
DATE=$(date +%Y%m%d_%H%M)
EMAIL=bigkahuna@meta.red
RIAK_RING_DIR=/path/to/riak/ring
RIAK_CONFIG_DIR=/path/to/etc/riak
BACKUP_DIR=/path/to/riak_backups
SERVER=$(hostname --fqdn | sed 's/\./-/g')
SERVER_NAME=$(hostname --fqdn)
LOG_DIR=/path/to/backup/log/dir

# email function
notify_email(){
  mail -s "${0}: failed on ${SERVER_NAME}" $EMAIL
}

# make sure our log directory exists
if [ ! -d $LOG_DIR ]; then
  mkdir $LOG_DIR
  if [ ! $? -eq 0 ]; then
    echo "Unable to create log dir: $LOG_DIR" | notify_email
    exit 1
  fi
else
  touch $LOG_DIR/test
  rm $LOG_DIR/test
  if [ ! $? -eq 0 ]; then
    echo "Unable to write to log dir: $LOG_DIR" | notify_email
    exit 1
  fi
fi

# make sure our backup directory exists and is writable
if [ ! -d $BACKUP_DIR ]; then
  mkdir -p $BACKUP_DIR
  if [ ! $? -eq 0 ]; then
    echo "Unable to create backup dir: $BACKUP_DIR" | notify_email
    exit 1
  fi
else
  touch $BACKUP_DIR/test
  rm $BACKUP_DIR/test
  if [ ! $? -eq 0 ]; then
    echo "Unable to write to backup dir: $BACKUP_DIR" | notify_email
    exit 1
  fi
fi

# clean up old files from backup directory
find $BACKUP_DIR -name "*.tar.gz" -mtime +10 -exec rm -f {} \;

# start hot backup of riak bitcask backend
# if your backend is not a bitcask configuration data loss may occur
# exit if the data directory is neither /ssd or /data
if [ -e /ssd/riak ]; then
  RIAK_DATA_DIR=/ssd/riak
elif [ -e /data/riak ]; then
  RIAK_DATA_DIR=/data/riak
else echo "Riak Data Directory NOT FOUND." | notify_email
  exit 1
fi

# start hot backup of riak bitcask backend
# if your backend is not a bitcask configuration data loss may occur
echo "Beginning backup... "
echo "$DATE"
tar -I pigz -cf $BACKUP_DIR/riak_data_"$SERVER"_"$DATE".tar.gz "$RIAK_CONFIG_DIR" "$RIAK_RING_DIR" "$RIAK_DATA_DIR"
ERROR_CODE=$?
if [ $ERROR_CODE -eq 2 ]; then
  echo "Unable to tar archive the riak bitcask backend $RIAK_CONFIG_DIR , $RIAK_RING_DIR , $RIAK_DATA_DIR to $BACKUP_DIR FATAL ERROR EXIT CODE $ERROR_CODE" | notify_email
  exit 1
elif [ $ERROR_CODE -eq 1 ]; then
echo "Tar archive the for bitcask backend $RIAK_CONFIG_DIR , $RIAK_RING_DIR , $RIAK_DATA_DIR to $BACKUP_DIR contains files that changed during the copy process.  Though expected during a hot backup process, you may consider changing the scheduled job to a time when the server is not as busy."
else
  exit 0
fi

# change permissions for user configured with S3 credentials to archive
for i in $(find $BACKUP_DIR -name "*.tar.gz"); do
chown s3_user:s3_user $i
if [ ! $? -eq 0 ]; then
  echo "Unable to change permissions on backup dir: $BACKUP_DIR" | notify_email
  exit 1
fi
done
exit 0
