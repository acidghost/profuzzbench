#!/bin/bash

DOCIMAGE=$1   #name of the docker image
RUNS=$2       #number of runs
SAVETO=$3     #path to folder keeping the results

FUZZER=$4     #fuzzer name (e.g., aflnet) -- this name must match the name of the fuzzer folder inside the Docker container
OUTDIR=$5     #name of the output folder created inside the docker container
OPTIONS=$6    #all configured options for fuzzing
TIMEOUT=$7    #time for fuzzing
SKIPCOUNT=$8  #used for calculating coverage over time. e.g., SKIPCOUNT=5 means we run gcovr after every 5 test cases

#keep all container ids
cids=()

#number of available cores
ncores=52   # cores 0-51 are available here
# ncores=$(nproc)
if [[ ! "$ncores" =~ [0-9]+ ]]; then
    >&2 echo "FATAL: could not get the number of cores"
    exit 1
fi

# associative array of taken cores
declare -A taken

#find available cores (use afl's logic for core pinning)
for f in /proc/*/status
do
    pid=$(dirname "$f" | sed -e 's,/proc/,,g')
    core=$(gawk '/^Cpus_allowed_list:\s+[0-9]+$/ {if (has_vmsize) print $2}
                 /^VmSize:\s/ {has_vmsize=1}' "$f" 2>/dev/null)
    if [ -n "$core" ]; then
        taken[$core]="$pid"
    fi
done
unset f pid core

#check available cores before starting anything
available=$((ncores - ${#taken[@]}))
if [ $available -lt "$RUNS" ]; then
    >&2 echo "FATAL: not enough cores available"
    >&2 echo "Taken cores:" "${!taken[@]}"
    exit 1
fi
unset available

findcore() {
    local core
    for core in $(seq 0 $((ncores-1))); do
        if [ -z "${taken[$core]}" ]; then
            cpunum=$core
            break
        fi
        cpunum=
    done
    if [ -z "$cpunum" ]; then
        #this should not happen (TM) as we checked beforehand
        >&2 echo "FATAL: no available cores"
        exit 1
    fi
    taken[$cpunum]=1
}

#create one container for each run
for _ in $(seq 1 "$RUNS"); do
  findcore
  cmd="cd ${WORKDIR} && run ${FUZZER} ${OUTDIR} '${OPTIONS}' ${TIMEOUT} ${SKIPCOUNT}"
  id=$(docker run --cpus=1 --cpuset-cpus="$cpunum" -d -it "$DOCIMAGE" /bin/bash -c "$cmd")
  cids+=("${id::12}") #store only the first 12 characters of a container ID
done

#wait until all these dockers are stopped
echo -en "\n${FUZZER^^}: Fuzzing in progress ..."
echo -en "\n${FUZZER^^}: Waiting for the following containers to stop:" "${cids[@]}"
docker wait "${cids[@]}" > /dev/null
wait

#collect the fuzzing results from the containers
echo -en "\n${FUZZER^^}: Collecting results and save them to ${SAVETO}"
index=1
for id in "${cids[@]}"; do
  echo -en "\n${FUZZER^^}: Collecting results from container ${id}"
  docker cp "${id}:/home/ubuntu/experiments/${OUTDIR}.tar.gz" \
            "${SAVETO}/${OUTDIR}_${index}.tar.gz" > /dev/null
  index=$((index+1))
done

echo -e "\n${FUZZER^^}: I am done!"
