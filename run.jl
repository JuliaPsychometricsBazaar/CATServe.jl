using Oxygen
using CATServe

serve_cat(host=ARGS[1], port=parse(Int, ARGS[2]))
