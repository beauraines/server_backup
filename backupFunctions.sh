#### Functions

rcCheck()
 {
if [ $1 -ne 0 ]
then
  if [ $1 -eq 24 ]
  then
  # Supressing any error messaging
  # Exit code 24 is not really an error: Partial transfer due to vanished source files
  # This means that a file was there to be backed up when it started, but when it got to that file
  # The file was gone and not able to be backed up.
  # This frequently happens with temporary and lock files
  return
  fi
echo 
echo "***ERROR***" >> $BACKUP_DIR/log/backup_$DATES.log
echo "`date` An error occurred while backing up $BACKUPMODULE.  Error code $1 was returned." >> $BACKUP_DIR/log/backup_$DATES.log
echo "***ERROR***"
echo "`date` An error occurred while backing up $BACKUPMODULE.  Error code $1 was returned."
echo "`date` An error occurred while backing up $BACKUPMODULE.  Error code $1 was returned." | mutt -s "Error occurred during backup." -- $BACKUPNOTIFY
echo "***ERROR***"
fi
}

s3exitCheck()
{
exitcode=$1
file=$2

if [ $1 - ne 0 ]
then
  echo 
  echo "***ERROR***" >> $BACKUP_DIR/log/backup_$DATES.log
  echo "`date` An error occurred while uploading $file.  Error code $1 was returned." >> $BACKUP_DIR/log/backup_$DATES.log
  echo "***ERROR***"
  echo "`date` An error occurred while uploading $file.  Error code $1 was returned."
  echo "`date` An error occurred while uploading $file.  Error code $1 was returned." | mutt -s "Error occurred during backup." -- $BACKUPNOTIFY
  echo "***ERROR***"
fi

}

copyBackupstoRemoteServer()
{
if [ $CopyBackupsRemote -eq 1 ]
then
# Sending backup files to remote backup host
BACKUPMODULE="Using rsync to send files to $REMOTEBACKUPHOST:$REMOTEBACKUP_DIR"
echo -n "Using rsync to send files to $REMOTEBACKUPHOST:$REMOTEBACKUP_DIR..."
rsync -Hpavxhr --delete $BACKUP_DIR $REMOTEBACKUPHOST:$REMOTEBACKUP_DIR/ >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
rcCheck $?
echo "done."
fi
}


checkDropbox()
{
if [ $UseDropbox -eq 1 ]
then
#Checking dropbox status
echo Checking dropbox...
/usr/local/bin/dropbox status
echo
fi
}

deleteOldBackups()
{
# Removing old backup files
#find $BACKUP_DIR/datedbackups -maxdepth 1 -type d -ctime +7 -delete
#find $BACKUP_DIR/datedbackups -maxdepth 1 -type d -ctime +7 -exec rm -rf {} \;
find $BACKUP_DIR/.. -ctime +14 -exec rm -rf {} \;
}

copyBackupstoS3()
{
if [ $CopyBackupsS3 -eq 1 ]
then
# Copy backups to S3
echo Copying backups to S3
# Create dated for directory on S3
echo Creating S3 backup directory
$s3cmd -c $S3CFGFILE put $BACKUP_DIR s3://$S3BUCKETNAME/`hostname`/ >> $BACKUP_DIR/log/backup_$DATES.log
echo done.

#copy mysql dumps to S3
echo -n Copying mysql dumps to S3...
$s3cmd -c $S3CFGFILE --recursive put $BACKUP_DIR/mysql s3://$S3BUCKETNAME/`hostname`/$DATES/ >> $BACKUP_DIR/log/backup_$DATES.log
s3exitCheck $?  $BACKUP_DIR/mysql/
echo done.

# find 1028120430/ -maxdepth 1 -type d ! -name mysql ! -name $DATES
echo -n Creating tar files of backuped up directories...
tar -czf /tmp/home.$DATES.tgz $BACKUP_DIR/home
tar -czf /tmp/usr.$DATES.tgz $BACKUP_DIR/usr
tar -czf /tmp/etc.$DATES.tgz $BACKUP_DIR/etc
tar -czf /tmp/crontabs.$DATES.tgz $BACKUP_DIR/crontabs
tar -czf /tmp/opt.$DATES.tgz $BACKUP_DIR/opt
tar -czf /tmp/www.$DATES.tgz $BACKUP_DIR/www
echo done.

echo Copying tarballs  to S3...
for tarfile in `ls /tmp/*.$DATES.tgz`
do
echo -n Uploading $tarfile ...
$s3cmd -c $S3CFGFILE put $tarfile s3://$S3BUCKETNAME/`hostname`/$DATES/ >> $BACKUP_DIR/log/backup_$DATES.log
s3exitCheck $? $tarfile
echo done.
done
echo Finished uploading tarballs.

#copy Package list file to S3
echo -n Copying package list to S3...
$s3cmd -c $S3CFGFILE put $BACKUP_DIR/packagelist* s3://$S3BUCKETNAME/`hostname`/$DATES/ >> $BACKUP_DIR/log/backup_$DATES.log
s3exitCheck $? $BACKUP_DIR/packagelist
echo done.

#copy log file to S3
echo -n Copying log file to S3...
$s3cmd -c $S3CFGFILE put $BACKUP_DIR/log/backup_$DATES.log s3://$S3BUCKETNAME/`hostname`/$DATES/ >> $BACKUP_DIR/log/backup_$DATES.log
s3exitCheck $? $BACKUP_DIR/log/backup_$DATES.log
echo done.

#Clean up after backups - but the problem is there isn't a good way to check for successful upload. 
echo -n Cleaning up...
rm /tmp/*$DATES.tgz
echo done.
fi
}
