#! /bin/bash
#set -x

#### Configuration

. /usr/local/bin/backup.conf



#### Functions

rcCheck()
 {
if [ $1 -ne 0 ]
then
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
echo "***ERROR***" >> $BACKUP_DIR/$DATES/log/backup_$DATES.log
echo "`date` An error occurred while backing up $BACKUPMODULE.  Error code $1 was returned." >> $BACKUP_DIR/$DATES/log/backup_$DATES.log
echo "***ERROR***"
echo "`date` An error occurred while backing up $BACKUPMODULE.  Error code $1 was returned."
echo "`date` An error occurred while backing up $BACKUPMODULE.  Error code $1 was returned." | mutt -s "Error occurred during backup." -- $BACKUPNOTIFY
echo "***ERROR***"
fi


 }

# Check for and create if needed certain directories
if [ ! -d $BACKUP_DIR/$DATES/log ]
then
	mkdir -p $BACKUP_DIR/$DATES/log
fi
if [ ! -d $BACKUP_DIR/$DATES/mysql ]
then
        mkdir -p $BACKUP_DIR/$DATES/mysql
fi
if [ ! -d $BACKUP_DIR/$DATES/crontabs ]
then
        mkdir -p $BACKUP_DIR/$DATES/crontabs
fi



echo "Incremental Backup job starting at `date`."
echo "Writing output to $BACKUP_DIR/$DATES/log/backup_$DATES.log"
echo "Incremental Backup job starting" > $BACKUP_DIR/$DATES/log/backup_$DATES.log
echo "Writing output to $BACKUP_DIR/$DATES/log/backup_$DATES.log" > $BACKUP_DIR/$DATES/log/backup_$DATES.log

#Checking dropbox status
echo Checking dropbox...
/usr/local/bin/dropbox status
echo

# Shutdown Minecraft
echo "Shutting down minecraft..."
/etc/init.d/minecraft stop

# Backing up OS related files
echo -n "Backing up OS related files..."

BACKUPMODULE='/var/spool/cron/crontabs'
echo ".....Backing up crontabs" >> $BACKUP_DIR/$DATES/log/backup_$DATES.log
rsync -Hpavxhr --compare-dest=$BACKUP_DIR/$LASTFULLBACKUP $BACKUPMODULE $BACKUP_DIR/$DATES >> $BACKUP_DIR/$DATES/log/backup_$DATES.log 2>&1
rcCheck $?

BACKUPMODULE='/opt'
echo ".....Backing up /opt" >> $BACKUP_DIR/$DATES/log/backup_$DATES.log
rsync -Hpavxhr --compare-dest=$BACKUP_DIR/$LASTFULLBACKUP $BACKUPMODULE $BACKUP_DIR/$DATES >> $BACKUP_DIR/$DATES/log/backup_$DATES.log 2>&1
rcCheck $?

BACKUPMODULE='/etc'
echo ".....Backing up /etc" >> $BACKUP_DIR/$DATES/log/backup_$DATES.log
rsync -Hpavxhr --compare-dest=$BACKUP_DIR/$LASTFULLBACKUP $BACKUPMODULE $BACKUP_DIR/$DATES >> $BACKUP_DIR/$DATES/log/backup_$DATES.log 2>&1
rcCheck $?

BACKUPMODULE='/usr'
echo ".....Backing up /usr" >> $BACKUP_DIR/$DATES/log/backup_$DATES.log
rsync -Hpavxhr --compare-dest=$BACKUP_DIR/$LASTFULLBACKUP $BACKUPMODULE $BACKUP_DIR/$DATES >> $BACKUP_DIR/$DATES/log/backup_$DATES.log 2>&1
rcCheck $?

BACKUPMODULE='package list'
echo ".....Backing up package list" >> $BACKUP_DIR/$DATES/log/backup_$DATES.log
dpkg --get-selections > $BACKUP_DIR/$DATES/packagelist.$(uname -n)
rcCheck $?

echo "done."

BACKUPMODULE='user data'
echo -n "Backing up user data..." 
echo  "Backing up user data..."  >> $BACKUP_DIR/$DATES/log/backup_$DATES.log
rsync -Hpavxhr --compare-dest=$BACKUP_DIR/$LASTFULLBACKUP/ /home $BACKUP_DIR/$DATES >> $BACKUP_DIR/$DATES/log/backup_$DATES.log 2>&1
rcCheck $?
echo "done."

# Backing up mysql databases
# Modified from comments on http://dev.mysql.com/doc/refman/5.1/en/mysqlhotcopy.html
echo -n "Backing up mysql databases..."
echo "Backing up  mysql databases..."  >> $BACKUP_DIR/$DATES/log/backup_$DATES.log
for i in `find /var/lib/mysql/* -type d -printf "%f\n"`
do 
	BACKUPMODULE="mysql database schema $i"
        echo "Backing up $BACKUPMODULE"
	mysqldump -R --add-drop-table -v --opt --lock-all-tables --log-error=$BACKUP_DIR/$DATES/log/backup_$DATES.log -u $MYSQLROOTUSER -p$MYSQLROOTPASS $i | gzip > $BACKUP_DIR/$DATES/mysql/$i.dmp.sql.gz
	rcCheck $?
	sleep 10
done

	i=information_schema
	BACKUPMODULE="mysql database schema $i"
        echo "Backing up $BACKUPMODULE"
	mysqldump -R --add-drop-table -v --opt --lock-all-tables --log-error=$BACKUP_DIR/$DATES/log/backup_$DATES.log -u $MYSQLROOTUSER -p$MYSQLROOTPASS $i | gzip > $BACKUP_DIR/$DATES/mysql/$i.dmp.sql.gz
	rcCheck $?
	sleep 10
echo "done."

# Backing up websites
echo -n "Backing up websites in $WWWDIR..."
BACKUPMODULE="Backing up website in $WWWDIR"
echo "Backing up websites..."  >> $BACKUP_DIR/$DATES/log/backup_$DATES.log
rsync -Hpavxhr --exclude-from=/usr/local/bin/backupExcludes_www --compare-dest=$BACKUP_DIR/$LASTFULLBACKUP/ $WWWDIR $BACKUP_DIR/$DATES >> $BACKUP_DIR/$DATES/log/backup_$DATES.log 2>&1
rcCheck $?
echo "done."

#Backing up subversion repositories
#echo -n "Backing up subversion repositores in $REPODIR ..."
#echo "Backing up subversion repositories..."  >> $BACKUP_DIR/$DATES/log/backup_$DATES.log
#for x in `find $REPODIR/* -maxdepth 0 -type d -printf "%f\n"`
#do
#	BACKUPMODULE=$REPODIR/$x
#	svn-backup-dumps  -z $REPODIR/$x $BACKUP_DIR/$DATES/ >> $BACKUP_DIR/$DATES/log/backup_$DATES.log 2>&1
#	rcCheck $?
	#find $BACKUP_DIR/repos/ -not -type d -name $x\* -not -name `(pushd $BACKUP_DIR/repos/ > /dev/null && ls -tr1 $x* | tail -n1 && popd > /dev/null)`  -delete
#done
#echo "done."

date > $BACKUP_DIR/last.backup
date >> $BACKUP_DIR/$DATES/log/backup_$DATES.log

# Removing old backup files
#find $BACKUP_DIR/datedbackups -maxdepth 1 -type d -ctime +7 -delete
#find $BACKUP_DIR/datedbackups -maxdepth 1 -type d -ctime +7 -exec rm -rf {} \;
#find $BACKUP_DIR/log -ctime +7 -delete


# Sending backup files to remote backup host
#BACKUPMODULE="Using rsync to send files to $REMOTEBACKUPHOST:$REMOTEBACKUP_DIR"
#echo -n "Using rsync to send files to $REMOTEBACKUPHOST:$REMOTEBACKUP_DIR..."
#rsync -Hpavxhr --delete $BACKUP_DIR/datedbackups/ $REMOTEBACKUPHOST:$REMOTEBACKUP_DIR/ >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
#rcCheck $?
#echo "done."

#Checking dropbox status
echo Checking dropbox status...
/usr/local/bin/dropbox status
echo

# Shutdown Minecraft
echo "Restarting minecraft..."
/etc/init.d/minecraft start

# Finishing backup

echo "Backup job completed at `date`"
echo "Backup job completed at `date`" >> $BACKUP_DIR/$DATES/log/backup_$DATES.log

mutt -s "Backup logs for `uname -n`" -a $BACKUP_DIR/$DATES/log/backup_$DATES.log  -- $BACKUPNOTIFY < /var/log/backupIncremental.log

