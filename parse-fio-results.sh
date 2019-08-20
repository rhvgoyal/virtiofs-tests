#!/bin/bash

get_total() {
  local data="$1"
  local i total

  for i in $data;do
    i=`printf "%.0f" "$i"`
    total=$(( total + i ))
  done 

  echo $total
}

get_avg() {
  local data="$1"
  local avg i total
  local nr_samples="0"

  for i in $data;do
    i=`printf "%.0f" "$i"`
    total=$(( total + i ))
    nr_samples=$((nr_samples + 1))
  done 

  avg=$((total/nr_samples))
  echo $avg
}

kib_to_mib() {
  local data=$1
  local total

  total=$(($data/1024))
  echo $total
}

get_op_data() {
  local op=$1
  local file=$2
  local write=$3
  local data

  if [ "$write" == "1" ];then
    data=`grep -e ";$op;" $file | awk -F\; '{print $48}'`
  else
    data=`grep -e ";$op;" $file | awk -F\; '{print $7}'`
  fi

  echo $data 
}

print_result_header() {
  local name="NAME"
  local op="I/O Operation"
  local bw="BW(Read/Write)"

  printf "%-24s%-24s%s\n" "$name" "$op" "$bw"
}

parse_print_ops() {
  local operations=$1
  local write=$2

  for op in $operations;do
    for file in $FILES;do
      TEST_NAME=`grep "^TEST_NAME=" $file | cut -d "=" -f2`
      [ -z "$TEST_NAME" ] && TEST_NAME="unknown"
      UNIT="KiB/s"
      NUMS=`get_op_data $op $file $write`
      if [ -z "$NUMS" ];then
        AVG="Unknown"
        printf "%-24s%-24s%s(%s)\n" "$TEST_NAME" "$op" "$AVG" "$UNIT"
      else
        AVG=`get_avg "$NUMS"`
        if [ $AVG -gt 10240 ]; then
          AVG=`kib_to_mib $AVG`
          UNIT="MiB/s"
        fi
        printf "%-24s%-24s%d(%s)\n" "$TEST_NAME" "$op" "$AVG" "$UNIT"
      fi
    done
    printf "\n"
  done
}

#Main script
if [ $# -lt 1 ];then
  echo "Usage: $0 FILE ..."
  exit 1
fi

FILES="$@"
READ_OPERATIONS="seqread-psync seqread-psync-multi seqread-mmap seqread-mmap-multi seqread-libaio seqread-libaio-multi randread-psync randread-psync-multi randread-mmap randread-mmap-multi randread-libaio randread-libaio-multi"

WRITE_OPERATIONS="seqwrite-psync seqwrite-psync-multi seqwrite-mmap seqwrite-mmap-multi seqwrite-libaio seqwrite-libaio-multi randwrite-psync randwrite-psync-multi randwrite-mmap randwrite-mmap-multi randwrite-libaio randwrite-libaio-multi"

# Parse and print numbers
print_result_header
parse_print_ops "$READ_OPERATIONS"
parse_print_ops "$WRITE_OPERATIONS" "1"
