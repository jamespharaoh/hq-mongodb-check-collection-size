# HQ MongoDB check collection size

This project provides a script to check that the size of your MongoDB
collections doesn't exceed various types of limits.

It is designed to be run either as a nagios or icinga plugin, or as a standalone
utility from the command line.

## Usage

The script should simply be run from the command line.

### General options

    --verbose
    --breakdown
    --threads NUM

If `--verbose` is specified, then details will be shown for collections which
are within the limits, as well as those which exceed them.

The `--breakdown` option causes a separate line to be output for the data
without any indexes, and each index in turn, in addition to the combined line
which is normally shown.

The `--threads` option controls the number of worker threads the script uses.
These are used to reduce the total runtime if the many database requests the
script makes experience high latency. The default is 10 threads.

### Database connection

    --hostname HOSTNAME
    --port PORT

Specify the hostname and port of the MongoDB server to connect to. The default
is to connect to port 27017 at localhost.

### Total database size

    --total-warning SIZE
    --total-critical SIZE

Produce a warning or critical error if any collection has a total data size
which exceeds either of these values.

### Unsharded database size

    --unsharded-warning SIZE
    --unsharded-critical SIZE

Same as above, except this only checks collections which are not sharded.

### Storage efficiency

    --efficiency-warning RATIO
    --efficiency-critical RATIO
    --efficiency-size SIZE

This compares the data size of the collection to the total storage size
allocated to it. The ratios should be between 0 and 1. Any collections with
a storage size less than `--efficiencty-size` will not be checked.
