### 1. Backup file ke .tar.gz

```bash
tar -czvf file.tar.gz directory/ /directory2 --exclude=/home/path/ --exclude=*.mp4
```

dengan date;


```bash
# backupDate=`date +"%Y-%m-%d %T"`; # 2020-09-23 10:51:22

backupDate=`date+"%Y-%m-%d"`;


# fille yg di compile: webapps_2017-11-14.tar.gz

tar -czvf webapps_${backupDate}.tar.gz directory/
```

kasus lain;

```
#!/bin/bash

ORIGIN="/home/yourusername/projects/*"
DESTINATION="/media/yourusername/Elements/jobs/projects/"

if [ -d $DESTINATION ]; then
    rsync -a --exclude "*.pyc" $ORIGIN $DESTINATION;
    echo "Updated at:" $(date);
else
    echo "Path $DESTINATION not found.";
    echo "Not updated at:" $(date);
fi
```

Change mode for your bash file:

```
$ chmod +x autosync.sh
```

Don’t miss to add into cronjobs

```
$ crontab -e
```

then, in your editor:

```
# Select shell mode
SHELL=/bin/bash


# Setup to daily method.
# [minute] [hour] [date] [month] [year]
# sync the folders for every hours, for more: https://crontab.guru/every-1-hour
0 * * * * /home/yourusername/tools/autosync.sh > /yourusername/tools/autosync.log 2>&1
```


1. https://github.com/library-collections/pytest-monitor
2. https://kubernetes.io/id/docs/concepts/overview/object-management-kubectl/imperative-command/
3. https://zakkymuhammad.com/blog/perintah-perintah-dasar-pada-docker-dan-contohnya/
4. http://blog.gaza.my.id/2017/11/self-reminder-wawancara-posisi-devops.html
5. https://id.bitdegree.org/tutorial/docker-tutorial/#heading-11
6. https://phoenixnap.com/kb/how-to-install-docker-on-ubuntu-18-04
7. https://www.simplilearn.com/tutorials/devops-tutorial/devops-interview-questions
