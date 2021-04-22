#!/bin/bash

# Defaults
# default runtime is 20 seconds
RUNTIME=20
# Number of times each job is run
LOOPS=3
IODEPTH=16
SIZE="4G"
DIRECT=1
BLOCKSIZE="4K"

drop_cache() {
  sync
  echo 3 > /proc/sys/vm/drop_caches
}

empty_testdir() {
  rm -f $TESTDIR/*
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
  echo "RUNTIME=$RUNTIME LOOPS=$LOOPS IODEPTH=$IODEPTH SIZE=$SIZE DIRECT=$DIRECT BLOCKSIZE=$BLOCKSIZE"
  echo ""
}

run_test() {
  local fio_cmd

  [ -n "$CREATEFILE" ] && empty_testdir
  drop_cache

  fio_cmd="fio --directory=$TESTDIR --runtime=$RUNTIME --iodepth=$IODEPTH --size="$SIZE" --direct=$DIRECT --blocksize="$BLOCKSIZE" --append-terse $1"
  echo "Running: $fio_cmd"
  $fio_cmd
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
  --iodepth		Number of I/O units to keep in flight. Default is 16.
  --size		Total size of file. Default is 4G.
  --direct		If set to 1, use non-buffered I/O. Default is 1.
  --blocksize		Specify blocksize. Default is 4K.
  -c | --createfile	Setup new file on each run. Remove existing file.
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
OPTS=`getopt -o h -l help -l runtime: -l loops: -l iodepth: -l size: -l direct: -l blocksize: -o c -l createfile -- $@`
eval set -- "$OPTS"
while true; do
  case "$1" in
    -h | --help)  usage $(basename $0); exit 0;;
    --runtime) RUNTIME=$2; shift 2;;
    --loops) LOOPS=$2; shift 2;;
    --iodepth) IODEPTH=$2; shift 2;;
    --size) SIZE=$2; shift 2;;
    --direct) DIRECT=$2; shift 2;;
    --blocksize) BLOCKSIZE=$2; shift 2;;
    -c | --createfile) CREATEFILE=1; shift 1;;
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

# If user wants to setup new file for each job and each run, make sure
# initial directory is empty. We will empty it after each run so that
# fio is forced to setup new files.
if [ -n "$CREATEFILE" ] && [ "$(ls -A $TESTDIR)" ];then
  echo "$TESTDIR is not empty. It needs to be empty with option -c."
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
