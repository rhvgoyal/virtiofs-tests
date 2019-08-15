#!/bin/bash

# Defaults
# default runtime is 30 seconds
RUNTIME=30
# Number of times each job is run
LOOPS=3

drop_cache() {
  sync
  echo 3 > /proc/sys/vm/drop_caches
}

get_shm_regions() {
  local regions

  regions=`cat /proc/iomem | grep "virtio-pci-shm" | sed 's/^ *//' | cut -d " " -f1 | tr '\n' ' '`
  echo $regions
}

# Print metadata about the job
output_meta_info() {
  echo "TESTDIR=$TESTDIR"
  echo "JOB_FILES=$JOB_FILES"
  echo "TEST_NAME=$TEST_NAME"
  echo "SYSTEMINFO=`uname -a`"
  echo "MOUNTPOINT=`findmnt -n --target $TESTDIR`"
  echo "VIRTO_SHM_REGIONS=`get_shm_regions`"
  echo ""
}

run_test() {
  drop_cache
  fio --directory=$TESTDIR --runtime=$RUNTIME --append-terse $1
}

usage() {
  cmd=$1

  cat <<-FOE
Usage: $cmd: [OPTIONS] <name> <test-directory> <fio-job> ....

Run fio tests

Options:
  -h | --help		Print help message
  --runtime		Time in seconds for which each job should run. Default                          is 30 seconds.
  --loops		Number of times each job is run. Default is 3.
FOE
}

# Main script

#shift
JOB_FILES="$@"

if [ $# -lt 3 ];then
  usage $(basename $0)
  exit 1
fi

# Parse options
OPTS=`getopt -o h -l help -l runtime: -l loops: -- $@`
eval set -- "$OPTS"
while true; do
  case "$1" in
    -h | --help)  usage $(basename $0); exit 0;;
    --runtime) RUNTIME=$2; shift 2;;
    --loops) LOOPS=$2; shift 2;;
    --) shift; break;;
    esac
done

# Give a short name, for ex. virtiofs-cache-dax. This signifies tests being
# run on virtio-fs with cache=always and dax is enabled. This will be saved
# in output file and parsed by parser script.
TEST_NAME=$1

TESTDIR=$2
if [ ! -d "$TESTDIR" ];then
  echo "$TESTDIR is not a valid directory."
  usage $0
  exit 1
fi

shift 2
JOB_FILES="$@"

if [ -z "$JOB_FILES" ];then
  echo "Specify atleast one job file"
  usage $0
  exit 1
fi

output_meta_info
drop_cache
for jobname in $JOB_FILES;do
  for i in `seq 1 $LOOPS`;do
     run_test $jobname
  done
done

drop_cache
