#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

julia --color=yes --depwarn=no --project=@. --sysimage=$SCRIPT_DIR/sysimg.so -q -i -- run.jl --startup-file=no -s=true "$@"
