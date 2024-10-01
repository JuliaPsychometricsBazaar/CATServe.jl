using Base.Filesystem: mkpath
using Profile
using ProfileSVG
using Oxygen
using HTTP


@kwdef mutable struct FlamegraphMiddleware
    profidx::Int = 1
    lock::ReentrantLock = ReentrantLock()
    profilesvg_kwargs=(;)
end


function (middleware::FlamegraphMiddleware)(handler)
    return function(req::HTTP.Request)
        Profile.clear()
        try
            return @profile handler(req)
        finally
            mkpath("profiles")
            data = Profile.fetch()
            if isempty(data)
                @info "No profile data (try increasing the sample rate)"
            else
                Profile.clear()
                local dest
                lock(middleware.lock)
                try
                    dest = joinpath("profiles", "$(middleware.profidx).svg")
                    middleware.profidx += 1
                finally
                    unlock(middleware.lock)
                end
                rm(dest; force=true)
                ProfileSVG.save(dest, data; middleware.profilesvg_kwargs...)
                @info "Profile saved to $dest with $(length(data)) samples"
            end
        end
    end
end

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
