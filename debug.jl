using Revise
using Bonito
using Oxygen
using CATServe: ws_handler, update_templates, CATServe

function ReviseHandler(handle)
    req -> begin
        if !isempty(Revise.revision_queue)
            @time "Sync revision" Revise.revise()
        end
        invokelatest(handle, req)
    end
end

@time "Initial revision" Revise.revise()
CATServe.serve(; host="127.0.0.1", port=8001, handler=ws_handler, middleware=[ReviseHandler], async=true)
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
