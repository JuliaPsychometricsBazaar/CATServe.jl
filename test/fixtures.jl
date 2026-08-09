# Server fixture: one CATServe instance for the whole suite, on a free port.

using Sockets
using HTTP
using Playwright: retry_until

function free_port()
    server = Sockets.listen(Sockets.InetAddr(Sockets.ip"127.0.0.1", 0))
    port = Int(Sockets.getsockname(server)[2])
    close(server)
    return port
end

# Connection-refused while the server warms up is a not-yet, not a failure --
# hence `on_error = :retry` (the idiom from Playwright.jl's examples/common.jl).
function wait_for_server(url; timeout = 120_000)
    up = retry_until(; timeout, interval = 200, on_error = :retry, on_timeout = :false) do
        HTTP.get(url; retry = false, status_exception = true)
        true
    end
    up || error("CATServe did not answer at $url within $(timeout)ms")
    return url
end

"""
    with_server(f)

Serve CATServe asynchronously on a free port, call `f(base_url)` and terminate
it afterwards. The process' working directory must already be the repository
root: `datasets/` and `static/` are looked up relative to it.
"""
function with_server(f)
    port = free_port()
    base = "http://127.0.0.1:$port"
    CATServe.serve(;
        host = "127.0.0.1",
        port = port,
        async = true,
        show_banner = false,
        docs = false,
        metrics = false,
    )
    try
        wait_for_server("$base/")
        return f(base)
    finally
        CATServe.CATServer.terminate()
    end
end
