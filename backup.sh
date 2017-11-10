#!/bin/bash

# backup YouTrack and Redmine then upload to s3 bucket
# s3://xxxxxx/xxxxx/youtrack
# s3://xxxxxx/xxxxx/redmine
# Assuming you've already setup your aws key id and secret access key in your server

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
YT_file=/opt/issuetracker_backup/s3list/yt_file.txt
RM_file=/opt/issuetracker_backup/s3list/rm_file.txt
RMD_file=/opt/issuetracker_backup/s3list/rmd_file.txt
DIR_YT=/var/lib/youtrack/backup
DIR_RM=/var/lib/docker/volumes/81d193982c464e5981632e2ab7709a62f1a95505dffe453c700ab7c733fxxxx/_data
DIR_DB=/var/lib/docker/volumes/777c9a0139996c1c502fa5974c27337d56c178661faf7c3f5cfb28e1f5exxxxx/_data/backup
DIR_BK=/opt/issuetracker_backup/backup_files
LOGFILE=/opt/issuetracker_backup/log/backup_log
BYT=s3://xxxxx/xxxxx/youtrack/
BRD=s3://xxxxxx/xxxxx/redmine/

function compress {
        while [ ! -f $DIR_BK/youtrack.`date +"%Y%m%d_%H*"` ]    
        do
                echo "`date -u` YouTrack compressed file does not exist!"
                docker exec youtrack bash -c 'tar -czf /var/lib/youtrack/backup/youtrack.`date +"%Y%m%d"_%H%M%S`.tgz /usr/local/youtrack'
                mv $DIR_YT/youtrack.`date +"%Y%m%d"_%H*` $DIR_BK
        done
	echo "`date -u` YouTrack file has already been compressed."

        while [ ! -f $DIR_BK/redmine.`date +"%Y%m%d_%H*"` ]
        do
                echo "`date -u` Redmine compressed file does not exist!"
                tar -czf /opt/issuetracker_backup/backup_files/redmine.`date +"%Y%m%d_%H%M%S"`.tgz $DIR_RM
        done
	echo "`date -u` Redmine file has already been compressed."
	
        while [ ! -f $DIR_BK/redmineDB.`date +"%Y%m%d_%H*"`.sql.tgz ]
        do
                echo "`date -u` Redmine database compressed file does not exist!"
                docker exec mariadb bash -c 'mysqldump --single-transaction bitnami_redmine > /bitnami/mariadb/backup/redmineDB.`date +"%Y%m%d"_%H%M%S`.sql'
                mv $DIR_DB/redmineDB.`date +"%Y%m%d"_%H*` $DIR_BK
		tar -czf $DIR_BK/redmineDB.`date +"%Y%m%d_%H%M%S"`.sql.tgz $DIR_BK/redmineDB.`date +"%Y%m%d_%H*"`.sql
        done
	echo "`date -u` Redmine database file has already been compressed."
}

function get {
	aws s3 ls s3://xxxxxx/xxxxxx/youtrack/ | grep youtrack.`date +"%Y%m%d_%H"` > $YT_file
	aws s3 ls s3://xxxxxx/xxxxxx/redmine/ | grep redmine.`date +"%Y%m%d_%H"` > $RM_file
	aws s3 ls s3://xxxxxx/xxxxxx/redmine/ | grep redmineDB.`date +"%Y%m%d_%H"` > $RMD_file
}

function upload {
	while [ ! -s $YT_file ]
        do
                echo "`date -u` YouTrack backup file does not exist in s3!"
                aws s3 cp /opt/issuetracker_backup/backup_files/youtrack.`date +"%Y%m%d_%H*"`.tgz $BYT
                aws s3 ls s3://xxxxxx/xxxxxx/youtrack/ | grep youtrack.`date +"%Y%m%d_%H"` > $YT_file
        done
	echo "`date -u` YouTrack backup file has been uploaded in s3."

        while [ ! -s $RM_file ]
        do
                echo "`date -u` Redmine backup file does not exist in s3!"
                aws s3 cp /opt/issuetracker_backup/backup_files/redmine.`date +"%Y%m%d_%H*"`.tgz $BRD
                aws s3 ls s3://xxxxxx/xxxxxx/redmine/ | grep redmine.`date +"%Y%m%d_%H"` > $RM_file
        done
        echo "`date -u` Redmine backup file has been uploaded in s3."

        while [ ! -s $RMD_file ]
        do
                echo "`date -u` Redmine database backup file does not exist in s3!"
                aws s3 cp /opt/issuetracker_backup/backup_files/redmineDB.`date +"%Y%m%d_%H*"`.sql.tgz $BRD
                aws s3 ls s3://xxxxxx/xxxxxx/redmine/ | grep redmineDB.`date +"%Y%m%d_%H"` > $RMD_file
        done
        echo "`date -u` Redmine database backup has been uploaded in s3."
}

function delete {
	find /opt/issuetracker_backup/backup_files/* -mtime +2 -exec rm {} \;
	echo "`date -u` Deleted backup files older than 2 days!"
}

function log {
        exec 1>>$LOGFILE 2>&1
}

log
echo " "
compress
get
upload
echo "`date -u` Compression and Backup Done!"
delete
echo " 
