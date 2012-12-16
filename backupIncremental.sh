#! /bin/bash
#set -x

#### Configuration

. /usr/local/bin/backup.conf

DATES=`date +%m%d%y%H%M` # make handy date string for log filenames
BACKUP_DIR=$BACKUP_DIR/$DATES

. backupFunctions.sh

# Check for and create if needed certain directories
if [ ! -d $BACKUP_DIR/log ]
then
	mkdir -p $BACKUP_DIR/log
fi
if [ ! -d $BACKUP_DIR/mysql ]
then
        mkdir -p $BACKUP_DIR/mysql
fi
if [ ! -d $BACKUP_DIR/crontabs ]
then
        mkdir -p $BACKUP_DIR/crontabs
fi



echo "Incremental Backup job starting at `date`."
echo "Writing output to $BACKUP_DIR/log/backup_$DATES.log"
echo "Incremental Backup job starting" > $BACKUP_DIR/log/backup_$DATES.log
echo "Writing output to $BACKUP_DIR/log/backup_$DATES.log" > $BACKUP_DIR/log/backup_$DATES.log

checkDropbox

# Shutdown Minecraft
if [ $MinecraftInstalled -eq 1 ]
then
echo "Shutting down minecraft..."
/etc/init.d/minecraft stop
fi

# Backing up OS related files
echo -n "Backing up OS related files..."

BACKUPMODULE='/var/spool/cron/crontabs'
echo ".....Backing up crontabs" >> $BACKUP_DIR/log/backup_$DATES.log
rsync -Hpavxhr --compare-dest=$BACKUP_DIR/../$LASTFULLBACKUP $BACKUPMODULE $BACKUP_DIR >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
rcCheck $?

BACKUPMODULE='/opt'
echo ".....Backing up /opt" >> $BACKUP_DIR/log/backup_$DATES.log
rsync -Hpavxhr --compare-dest=$BACKUP_DIR/../$LASTFULLBACKUP $BACKUPMODULE $BACKUP_DIR >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
rcCheck $?

BACKUPMODULE='/etc'
echo ".....Backing up /etc" >> $BACKUP_DIR/log/backup_$DATES.log
rsync -Hpavxhr --compare-dest=$BACKUP_DIR/../$LASTFULLBACKUP $BACKUPMODULE $BACKUP_DIR >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
rcCheck $?

BACKUPMODULE='/usr'
echo ".....Backing up /usr" >> $BACKUP_DIR/log/backup_$DATES.log
rsync -Hpavxhr --exclude-from=/usr/local/bin/backupExcludes_usr --compare-dest=$BACKUP_DIR/../$LASTFULLBACKUP $BACKUPMODULE $BACKUP_DIR >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
rcCheck $?

BACKUPMODULE='package list'
echo ".....Backing up package list" >> $BACKUP_DIR/log/backup_$DATES.log
dpkg --get-selections > $BACKUP_DIR/packagelist.$(uname -n)
rcCheck $?

echo "done."

BACKUPMODULE='user data'
echo -n "Backing up user data..." 
echo  "Backing up user data..."  >> $BACKUP_DIR/log/backup_$DATES.log
rsync -Hpavxhr --compare-dest=$BACKUP_DIR/../$LASTFULLBACKUP/ /home $BACKUP_DIR >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
rcCheck $?
echo "done."

# Backing up mysql databases
# Modified from comments on http://dev.mysql.com/doc/refman/5.1/en/mysqlhotcopy.html
if [ $backupMySQL -eq 1 ]
then
echo -n "Backing up mysql databases..."
echo "Backing up  mysql databases..."  >> $BACKUP_DIR/log/backup_$DATES.log
for i in `find /var/lib/mysql/* -type d -printf "%f\n"`
do 
	BACKUPMODULE="mysql database schema $i"
        echo "Backing up $BACKUPMODULE"
	mysqldump -R --add-drop-table -v --opt --lock-all-tables --log-error=$BACKUP_DIR/log/backup_$DATES.log -u $MYSQLROOTUSER -p$MYSQLROOTPASS $i | gzip > $BACKUP_DIR/mysql/$i.dmp.sql.gz
	rcCheck $?
	sleep 10
done


	i=information_schema
	BACKUPMODULE="mysql database schema $i"
        echo "Backing up $BACKUPMODULE"
	mysqldump -R --add-drop-table -v --opt --lock-all-tables --log-error=$BACKUP_DIR/log/backup_$DATES.log -u $MYSQLROOTUSER -p$MYSQLROOTPASS $i | gzip > $BACKUP_DIR/mysql/$i.dmp.sql.gz
	rcCheck $?
	sleep 10
echo "done."
fi

# Backing up websites
if [ $backupWWW -eq 1 ]
then
echo -n "Backing up websites in $WWWDIR..."
BACKUPMODULE="Backing up website in $WWWDIR"
echo "Backing up websites..."  >> $BACKUP_DIR/log/backup_$DATES.log
rsync -Hpavxhr --exclude-from=/usr/local/bin/backupExcludes_www --compare-dest=$BACKUP_DIR/../$LASTFULLBACKUP/ $WWWDIR $BACKUP_DIR >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
rcCheck $?
echo "done."
fi


#Backing up subversion repositories
if [ $backupSVN -eq 1 ]
then
echo -n "Backing up subversion repositores in $REPODIR ..."
echo "Backing up subversion repositories..."  >> $BACKUP_DIR/log/backup_$DATES.log
for x in `find $REPODIR/* -maxdepth 0 -type d -printf "%f\n"`
do
	BACKUPMODULE=$REPODIR/$x
	svn-backup-dumps  -z $REPODIR/$x $BACKUP_DIR/repos/ >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
	rcCheck $?
	find $BACKUP_DIR/repos/ -not -type d -name $x\* -not -name `(pushd $BACKUP_DIR/repos/ > /dev/null && ls -tr1 $x* | tail -n1 && popd > /dev/null)`  -delete
done
echo "done."
fi


date > $BACKUP_DIR/last.backup
date >> $BACKUP_DIR/log/backup_$DATES.log


copyBackupstoRemoteServer

checkDropbox

# Restarting Minecraft
if [ $MinecraftInstalled -eq 1 ]
then
echo "Restarting down minecraft..."
/etc/init.d/minecraft start
fi

# Finishing backup

echo "Backup job completed at `date`"
echo "Backup job completed at `date`" >> $BACKUP_DIR/log/backup_$DATES.log


copyBackupstoS3

mutt -s "Backup logs for `uname -n`" -a $BACKUP_DIR/log/backup_$DATES.log  -- $BACKUPNOTIFY < /var/log/backupIncremental.log

