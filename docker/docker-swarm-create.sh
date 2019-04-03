#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options]
Create a Docker Swarm using docker-machine.

options:
    -m, --managers=1           Create the specified number of managers.
    -w, --workers=1            Create the specified number of workers.
    -f, --format='node%.f'     Use printf-style floating point format for hostname.
    -d, --driver='virtualbox'  Driver to create machine with.
    -v, --verbose              Be verbose.
    -n, --dry-run              Print commands instead of executing them.
    -h, --help                 Display this message.
"
}

error() {
    echo "$program: $*" >&2
    exit 1
}

bad_usage() {
    echo "$program: $*" >&2
    echo "Try \`$program --help' for more information." >&2
    exit 1
}

missing_arg() {
    bad_usage "option \`$1' requires an argument"
}

verbose_docker() {
    echo docker "$@"
    command docker "$@"
}

verbose_docker_machine() {
    echo docker-machine "$@"
    command docker-machine "$@"
}

### command line #######################################################

nmanagers=1
nworkers=1
format=node%.f
driver=virtualbox
verbose=false
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        --managers)
            [ $# -gt 0 ] || missing_arg "$option"
            nmanagers="$1"
            shift
            ;;

        --managers=*)
            nmanagers="${option#${option%%=*}=}"
            ;;

        -m*)
            nmanagers="${option:2}"
            ;;

        --workers)
            [ $# -gt 0 ] || missing_arg "$option"
            nworkers="$1"
            shift
            ;;

        --workers=*)
            nworkers="${option#${option%%=*}=}"
            ;;

        -w*)
            nworkers="${option:2}"
            ;;

        --format)
            [ $# -gt 0 ] || missing_arg "$option"
            format="$1"
            shift
            ;;

        --format=*)
            format="${option#${option%%=*}=}"
            ;;

        -f*)
            format="${option:2}"
            ;;

        --driver)
            [ $# -gt 0 ] || missing_arg "$option"
            driver="$1"
            shift
            ;;

        --driver=*)
            driver="${option#${option%%=*}=}"
            ;;

        -d*)
            driver="${option:2}"
            ;;

        -v | --verbose)
            verbose=true
            ;;

        -n | --dry-run)
            dry_run=true
            ;;

        -h | --help)
            usage
            exit
            ;;

        --)
            break
            ;;

        -?)
            bad_usage "unrecognized option \`$option'"
            ;;

        -*)
            set -- "${option::2}" -"${option:2}" "$@"
            ;;

        *)
            set -- "$option" "$@"
            break
            ;;
    esac
done

if [ "$nmanagers" -ne "$nmanagers" ]
then
    bad_usage "--managers must be a number"
fi

if [ "$nmanagers" -le 0 ]
then
    bad_usage "--managers must be greater than zero"
fi

if [ "$nworkers" -ne "$nworkers" ]
then
    bad_usage "--workers must be a number"
fi

if [ "$nworkers" -lt 0 ]
then
    bad_usage "--workers must be greater than or equal to zero"
fi

if $dry_run
then
    docker='echo docker'
    docker_machine='echo docker-machine'
elif $verbose
then
    docker=verbose_docker
    docker_machine=verbose_docker_machine
else
    docker=docker
    docker_machine=docker-machine
fi

### main ###############################################################

managers=($(seq --format="$format" $nmanagers))
workers=($(seq --format="$format" $((nmanagers + 1)) $((nmanagers + nworkers))))
leader=${managers[0]}

for node in ${managers[@]} ${workers[@]}
do
    $docker_machine create --driver="$driver" $node
done

if $dry_run
then
    echo "leader_ip=\$(docker-machine ip $leader)"
    leader_ip='$leader_ip'
else
    leader_ip=$(docker-machine ip $leader)
fi

if $dry_run
then
    echo "eval \$(docker-machine env $leader)"
else
    eval $(docker-machine env $leader)
fi

$docker swarm init --advertise-addr=$leader_ip

if $dry_run
then
    echo "manager_token=\$(docker swarm join-token --quiet manager)"
    manager_token='$manager_token'
else
    manager_token=$(docker swarm join-token --quiet manager)
fi

if $dry_run
then
    echo "worker_token=\$(docker swarm join-token --quiet worker)"
    worker_token='$worker_token'
else
    worker_token=$(docker swarm join-token --quiet worker)
fi

for node in ${managers[@]:1}
do
    if $dry_run
    then
        echo "eval \$(docker-machine env $node)"
    else
        eval $(docker-machine env $node)
    fi

    $docker swarm join --token=$manager_token $leader_ip:2377
done

for node in ${workers[@]}
do
    if $dry_run
    then
        echo "eval \$(docker-machine env $node)"
    else
        eval $(docker-machine env $node)
    fi

    $docker swarm join --token=$worker_token $leader_ip:2377
done
