@info "start"
using Oxygen
using CATServe: CATServe
@info "imports done"

CATServe.serve(host=ARGS[1], port=parse(Int, ARGS[2]))
