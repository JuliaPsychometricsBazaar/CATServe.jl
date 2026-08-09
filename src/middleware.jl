using Oxygen
using HTTP

function PrintStacktraceMiddleware(handle)
    function(req)
        try
            return handle(req)
        catch e
            error_msg = sprint(showerror, e)
            st = sprint((io,v) -> show(io, "text/plain", v), stacktrace(catch_backtrace()))
            return HTTP.Response(500, "$error_msg\n$st")
        end
    end
end
