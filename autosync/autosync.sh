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
