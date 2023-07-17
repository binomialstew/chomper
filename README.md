# Chomper

Use cron to delete oldest files in `/reduce_directory` until `/volume_usage_directory` reaches the desired usage percentage

## General

2 volumes are necessary for this to run.

- We mount the directory to be reduced to the `/reduce_directory` mount point.
- The directory to be measured for usage percentage is mounted at the `/volume_usage_directory` mount point. Use the `ro` (read only) option to protect your data.
```
services:
  chomper:
    restart: unless-stopped
    build:
      context: ./chomper
      dockerfile: Dockerfile
    volumes:
      - ./host_directory_to_reduce:/reduce_directory
      - /:/volume_usage_directory:ro # we measure the usage at the volume root
    environment:
      - THRESHOLD=80
      - SCHEDULE=30 * * * * # Run every hour at the half hour
      - FILE_NUMBER=1
```

## Environment

This container takes the following environment variables:
  - THRESHOLD: The percentage of the measured volume this directory is allowed to use (default is 80)
  - FILE_NUMBER: The number of files deleted in each loop. This can be increased to speed up deletion and lessen resource usage (default is 1)
  - SCHEDULE: A cron expression that defines how often chomper is run (default is every hour)
