@info "start"
using Oxygen
using CATServe
@info "imports done"

serve_cat(host=ARGS[1], port=parse(Int, ARGS[2]))
