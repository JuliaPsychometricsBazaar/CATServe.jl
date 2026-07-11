module CATServe

using PrecompileTools

@recompile_invalidations begin
    using Bonito
    using Oxygen
    using Oxygen.Core: stream_handler
    using HTTP
    using HTTP.WebSockets
    using HTTP.WebSockets: upgrade
    using JSON3
    using WGLMakie
    using Bonito: force_asset_server!, NoServer
    using ComputerAdaptiveTesting
    using ComputerAdaptiveTesting.Aggregators: PointAbilityEstimator
    using Random
    using ItemResponseDatasets: SelectMultipleExact, SelectMultiplePartial, SelectMultiple, PromptedTask, answers
    using FittedItemBanks: ResponseType, item_params
    using ComputerAdaptiveTesting.Responses
    using ComputerAdaptiveTesting.Aggregators: TrackedResponses, add_response!
    using ComputerAdaptiveTesting.Sim: NextItemError
    using FittedItemBanks: BooleanResponse
    using AdaptiveTestPlots: CatRecorder, lh_evolution_interactive, plot_item_bank
end

include("./CATServer.jl")
using .CATServer: serve, ws_handler, update_templates, CATServer, FlamegraphMiddleware, PrintStacktraceMiddleware
export serve, ws_handler, update_templates, CATServer, FlamegraphMiddleware, PrintStacktraceMiddleware

end
