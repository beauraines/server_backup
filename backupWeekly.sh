#! /bin/bash
#set -x

#### Configuration

. /usr/local/bin/backup.conf

DATES=`date +%m%d%y` # make handy date string for log filenames
BACKUP_DIR=$BACKUP_DIR/$DATES

. /usr/local/bin/backupFunctions.sh

# Check for and create if needed certain directories
if [ ! -d $BACKUP_DIR/pkg ]
then
	mkdir -p $BACKUP_DIR/pkg
fi
if [ ! -d $BACKUP_DIR/www ]
then
	mkdir -p $BACKUP_DIR/www 
fi
if [ ! -d $BACKUP_DIR/mysql ]
then
	mkdir -p $BACKUP_DIR/mysql
fi
if [ ! -d $BACKUP_DIR/repos ]	
then				
	mkdir -p $BACKUP_DIR/repos	
fi				
if [ ! -d $BACKUP_DIR/log ]	
then				
	mkdir -p $BACKUP_DIR/log	
fi				
if [ ! -d $BACKUP_DIR/etc ]	
then				
	mkdir -p $BACKUP_DIR/etc
fi				
if [ ! -d $BACKUP_DIR/opt ]	
then				
	mkdir -p $BACKUP_DIR/opt
fi				
if [ ! -d $BACKUP_DIR/crontabs ]
then
        mkdir -p $BACKUP_DIR/crontabs
fi

echo "Backup job starting at `date`."
echo "Writing output to $BACKUP_DIR/log/backup_$DATES.log"
echo "Backup job starting" > $BACKUP_DIR/log/backup_$DATES.log

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
rsync -Hpavxhr --copy-dest=$BACKUP_DIR/../$LASTFULLBACKUP $BACKUPMODULE $BACKUP_DIR/ >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
rcCheck $?

BACKUPMODULE='/opt'
echo ".....Backing up /opt" >> $BACKUP_DIR/log/backup_$DATES.log
rsync -Hpavxhr --copy-dest=$LASTBACKUP/opt /opt $BACKUP_DIR/ >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
rcCheck $?

BACKUPMODULE='/etc'
echo ".....Backing up /etc" >> $BACKUP_DIR/log/backup_$DATES.log
rsync -Hpavxhr --copy-dest=$LASTBACKUP/etc  /etc $BACKUP_DIR/ >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
rcCheck $?

BACKUPMODULE='/usr'
echo ".....Backing up /usr" >> $BACKUP_DIR/log/backup_$DATES.log
rsync -Hpavxhr --exclude-from=/usr/local/bin/backupExcludes_usr --copy-dest=$LASTBACKUP/usr  /usr $BACKUP_DIR/ >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
rcCheck $?

BACKUPMODULE='package list'
echo ".....Backing up package list" >> $BACKUP_DIR/log/backup_$DATES.log
dpkg --get-selections > $BACKUP_DIR/packagelist.$(uname -n)
rcCheck $?

echo "done."

BACKUPMODULE='user data'
echo -n "Backing up user data..." 
echo  "Backing up user data..."  >> $BACKUP_DIR/log/backup_$DATES.log
rsync -Hpavxhr --exclude-from=/usr/local/bin/backupExcludes_home --copy-dest=$LASTBACKUP/home /home $BACKUP_DIR/ >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
rcCheck $?
echo "done."

# Backing up mysql databases
# Modified from comments on http://dev.mysql.com/doc/refman/5.1/en/mysqlhotcopy.html
if [ $backupMySQL -eq 1 ]
then
echo -n "Backing up mysql databases..."
echo "Backing up  mysql databases..."  >> $BACKUP_DIR/log/backup_$DATES.log
for i in `mysql -u$MYSQLROOTUSER -p$MYSQLROOTPASS -BNe 'select  schema_name from information_schema.schemata;'`
do 
	BACKUPMODULE="mysql database schema $i"
        echo "Backing up $BACKUPMODULE"
	mysqldump -R --add-drop-table -v --opt --lock-all-tables --log-error=$BACKUP_DIR/log/backup_$DATES.log -u $MYSQLROOTUSER -p$MYSQLROOTPASS $i | gzip > $BACKUP_DIR/mysql/$i.dmp.sql.gz
	rcCheck $?
	sleep 10
done

echo "done."
fi

# Backing up websites
if [ $backupWWW -eq 1 ]
then
echo -n "Backing up websites in $WWWDIR..."
BACKUPMODULE="Backing up website in $WWWDIR"
echo "Backing up websites..."  >> $BACKUP_DIR/log/backup_$DATES.log
rsync -Hpavxhr --exclude-from=/usr/local/bin/backupExcludes_www --copy-dest=$LASTBACKUP/www  $WWWDIR $BACKUP_DIR/ >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
rcCheck $?
echo "done."
fi


#Backing up subversion repositories
if [ $backupSVN -eq 1 ]
then
echo -n "Backing up subversion repositores in $REPODIR ..."
echo "Backing up subversion repositories..."  >> $BACKUP_DIR/log/backup_$DATES.log
if [ ! -d $BACKUP_DIR/repos ]
then
        mkdir -p $BACKUP_DIR/repos
fi
for x in `find $REPODIR/* -maxdepth 0 -type d -printf "%f\n"`
do
	BACKUPMODULE=$REPODIR/$x
	svn-backup-dumps  -z $REPODIR/$x $BACKUP_DIR/repos/ >> $BACKUP_DIR/log/backup_$DATES.log 2>&1
	rcCheck $?
	find $BACKUP_DIR/repos/ -not -type d -name $x\* -not -name `(pushd $BACKUP_DIR/repos/ > /dev/null && ls -tr1 $x* | tail -n1 && popd > /dev/null)`  -delete
done
echo "done."
fi

# Backing up minecraft
if [ $backupMinecraft -eq 1 ]
then
# ensure the backup location is properly specifiy n the init script
BACKUPMODULE=minecraft.backup
echo -n "Backing up minecraft..."
/etc/init.d/minecraft backup >> $BACKUP_DIR/log/backup_$DATES.log
rcCheck $?
echo -n "Deleting old minecraft backups..."
echo "Deleting old minecraft backups..." >> $BACKUP_DIR/log/backup_$DATES.log
find  /mnt/storage/backups/minecraft.backup -maxdepth 1 -type f -ctime +2 >> $BACKUP_DIR/log/backup_$DATES.log
find  /mnt/storage/backups/minecraft.backup -maxdepth 1 -type d -ctime +2 >> $BACKUP_DIR/log/backup_$DATES.log
#find /mnt/storage/backups/minecraft.backup  -maxdepth 1 -type f -ctime +28 -exec rm -rf {} \; >> $BACKUP_DIR/log/backup_$DATES.log
#find /mnt/storage/backups/minecraft.backup  -maxdepth 1 -type d -ctime +28 -exec rm -rf {} \; >> $BACKUP_DIR/log/backup_$DATES.log
echo "done." >> $BACKUP_DIR/log/backup_$DATES.log
fi

date > $BACKUP_DIR/last.backup
date >> $BACKUP_DIR/log/backup_$DATES.log

deleteOldBackups

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

sendBackupLog /var/log/backupWeekly.log
