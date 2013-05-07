# HQ MongoDB check collection size

https://github.com/jamespharaoh/hq-mongodb-check-collection-size

This project provides a script to check that the size of your MongoDB
collections doesn't exceed various types of limits.

It is designed to be run either as a nagios or icinga plugin, or as a standalone
utility from the command line.

## Installation

For most use cases, simply install the ruby gem:

    gem install hq-mongodb-check-collection-size

You can also install the gem as part of a bundle and run it using the "bundle
exec" command.

    mkdir my-bundle
    cd my-bundle
    echo 'source "https://rubygems.org"' >> Gemfile
    echo 'gem "hq-mongodb-check-collection-size"' >> Gemfile
    bundle install --path gems

If you want to develop the script, clone the repository from github and use
bundler to satisfy dependencies:

    git clone git://github.com/jamespharaoh/hq-mongodb-check-collection-size.git
    cd hq-mongodb-check-collection-size
    bundle install --path gems

## Usage

If the gem is installed correctly, you should be able to run the command with
the following name:

    hq-mongodb-check-collection-size (options...)

If it was installed via bundler, then you will want to use bundler to invoke the
command correctly:

    bundle exec hq-mongodb-check-collection-size (options...)

You will also need to provide various options for the script to work correctly.

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

    --efficiency-warning PERCENT
    --efficiency-critical PERCENT
    --efficiency-size SIZE

This compares the data size of the collection to the total storage size
allocated to it.

100% represents a collection which fits exactly in the storage space allocated.
50% represents a collecion which takes up half the space and 0% represents a
collection with no data in it.

Any collections with a storage size less than `--efficiency-size` will not be
checked.
