module CATServe

using PrecompileTools

@recompile_invalidations begin
    using Bonito
    using Oxygen
    using HTTP
    using HTTP.WebSockets
    using JSON3
    using WGLMakie
    using Bonnie
    using ComputerAdaptiveTesting
    using ComputerAdaptiveTesting.Aggregators: PointAbilityEstimator
    using Random
    using ItemResponseDatasets: SelectMultipleExact, SelectMultiplePartial, SelectMultiple, PromptedTask, answers
    using FittedItemBanks: ResponseType, item_params
    using ComputerAdaptiveTesting.Responses
    using ComputerAdaptiveTesting.Responses: add_response!
    using ComputerAdaptiveTesting.Aggregators: TrackedResponses
    using ComputerAdaptiveTesting.Sim: NextItemError
    using FittedItemBanks: BooleanResponse
    using AdaptiveTestPlots: CatRecorder, summary_plot, plot_item_bank
end

include("./CATServer.jl")
using .CATServer: update_templates, CATServer, PrintStacktraceMiddleware
export serve, update_templates, CATServer, PrintStacktraceMiddleware

# Serve through CATServer's oxidized Oxygen context, with Bonnie's middleware
# (which scopes the Bonito integration per request) always installed.
serve(; kwargs...) = CATServer.serve_cat(; kwargs...)

end
