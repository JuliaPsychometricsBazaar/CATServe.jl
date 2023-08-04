using Revise

includet("src/CATServe.jl")

#=
server = Ref(nothing)

@sync begin
    @async entr([], all=true) do
        println("Revise updated")
        server[] = serve(; port=8001, handler=ws_handler, async=true)[]
    end
end
=#

serve(; port=8001, handler=ws_handler)
