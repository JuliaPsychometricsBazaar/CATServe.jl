using Revise
#using Bonito
#using Oxygen
using CATServe: ws_handler, update_templates, serve, FlamegraphMiddleware
using Profile


Profile.init(;n=convert(Int, 1e8), delay=1e-2)


function ReviseHandler(handle)
    req -> begin
        if !isempty(Revise.revision_queue)
            @time "Sync revision" Revise.revise()
        end
        invokelatest(handle, req)
    end
end

@time "Initial revision" Revise.revise()
profilesvg_kwargs = (; maxframes=20000, maxdepth=200, width=1080, height=5000, C=true)
#middleware = FlamegraphMiddleware(profilesvg_kwargs=profilesvg_kwargs)
# middleware=[ReviseHandler, middleware]
serve(; host="127.0.0.1", port=8001, handler=ws_handler, middleware=[ReviseHandler], async=true)
key = Revise.add_callback(["templates"]) do
    @info "Starting template update"
    @time "Template update" invokelatest(update_templates)
end
try
    while true
        wait(Revise.revision_event)
        @info "Starting async revision"
        @time "Async revision" Revise.revise()
    end
finally
    Revise.remove_callback(key)
end
