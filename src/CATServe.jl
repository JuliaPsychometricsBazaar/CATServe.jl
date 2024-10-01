module CATServe

using PrecompileTools

@recompile_invalidations begin
    using Bonito
    using Oxygen
    include("./CATServer.jl")
end
using .CATServer: serve, ws_handler, update_templates, CATServer, FlamegraphMiddleware
export serve, ws_handler, update_templates, CATServer, FlamegraphMiddleware

end
