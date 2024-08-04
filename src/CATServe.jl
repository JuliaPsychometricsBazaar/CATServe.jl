module CATServe

using Oxygen
@oxidise
using Oxygen.Core: stream_handler
using HTTP
using HTTP.WebSockets
using HTTP.WebSockets: upgrade
using JSON3
using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.Aggregators: PointAbilityEstimator
using Random
using ItemResponseDatasets: SelectMultipleExact, SelectMultiplePartial, SelectMultiple, PromptedTask, answers
using FittedItemBanks: ResponseType, item_params
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.Aggregators: TrackedResponses, add_response!
using ComputerAdaptiveTesting.Sim: NextItemError
using FittedItemBanks: BooleanResponse
using AdaptiveTestPlots: CatRecorder, lh_evolution_interactive

export serve_cat

include("./otera.jl")
using .OteraEngineTemplating: otera
include("./utils.jl")
include("./summary.jl")
include("./widgets.jl")
include("./config.jl")
include("./templates.jl")

const TEMPLATE_DIR::String = dirname(Base.source_path()) * "/../templates/"
templates::Dict{String, Any} = Dict()

function update_templates()
    for fn in readdir(TEMPLATE_DIR)
        path = TEMPLATE_DIR * fn
        if !(isfile(path) && endswith(fn, ".html"))
            continue
        end
        @info "xx" path
        template_compiled = otera(path; config=Dict("dir" => TEMPLATE_DIR))
        templates[fn] = template_compiled
    end
end

function __init__()
    update_templates()
end

#function __init__()
@get "/" function index()
    return templates["index.html"](
        init=Dict(
            "render_stacked" => render_stacked,
            "render_row" => render_row,
            "form" => form,
            "render_options" => render_options,
            "datasets" => datasets,
            "ability_estimation_distribution" => ability_estimation_distribution,
            "ability_estimation" => ability_estimation,
            "ability_tracker" => ability_tracker,
            "next_item_rules" => next_item_rules,
            "termination_conditions" => termination_conditions,
            "integrators" => integrators,
            "optimizers" => optimizers,
        )
    )
end

@get "/test" function test(req)
    query = HTTP.URI(req.target).query
    @info "test" queryparams(req) query

    return templates["test.html"](init=Dict("query" => query))
end

@get "/test-ws" function test_ws(req)
    # TODO return forbidden/upgrade required
    @info "middleware failed" req
end

#end

function parse_cat_rules(parse)
    abildist = parse(ability_estimation_distribution)
    abilest = parse(ability_estimation)
    lower_bound = parse(form.lower_bound)
    upper_bound = parse(form.upper_bound)
    order = parse(form.integrator_order)
    integrator = parse(integrators, lower_bound, upper_bound, order)
    optimizer = parse(optimizers, lower_bound, upper_bound)
    full_abilest = PointAbilityEstimator(abilest, abildist, integrator, optimizer)
    next_item_rule = parse(next_item_rules, full_abilest, abildist, integrator, optimizer)
    nitems = parse(form.nitems)
    termination_condition = parse(termination_conditions, nitems)
    @info "stuff" abilest abildist full_abilest next_item_rule termination_condition integrator optimizer
    ComputerAdaptiveTesting.CatRules(full_abilest, next_item_rule, termination_condition)
end

function question_progress(question_idx, termination_condition::FixedItemsTerminationCondition)
    "$(question_idx)/$(termination_condition.num_items)"
end

function question_progress(question_idx, termination_condition)
    "$(question_idx)/?"
end

format_response(::BooleanResponse, value) = value ? "Correct" : "Incorrect"

max_responses(item_bank, termination_condition::FixedItemsTerminationCondition) = termination_condition.num_items
max_responses(item_bank, termination_condition) = length(item_bank)

function run_cat_ws(ws, rules, item_bank, question_bank, display_prefs)
    (; next_item, termination_condition, ability_estimator, ability_tracker) = rules
    responses = TrackedResponses(
        BareResponses(ResponseType(item_bank)),
        item_bank,
        ability_tracker
    )
    if display_prefs.record
        xs = range(-2.5, 2.5, length=100)
        integrator = QuadGKIntegrator(-6.0, 6.0, 7)
        dist_ability_est = PriorAbilityEstimator(std_normal)
        ability_estimator = MeanAbilityEstimator(dist_ability_est, integrator)
        raw_estimator = LikelihoodAbilityEstimator()
        recorder = CatRecorder(xs, max_responses(item_bank, termination_condition), integrator, raw_estimator, ability_estimator)
    else
        recorder = nothing
    end
    response_type = ResponseType(item_bank)
    question_idx = 1
    response = nothing
    while true
        local next_index
        try
            next_index = next_item(responses, item_bank)
        catch exc
            if isa(exc, NextItemError)
                @warn "Terminating early due to error getting next item" err=sprint(showerror, e)
                break
            else
                rethrow()
            end
        end
        prog = question_progress(question_idx, termination_condition)
        if display_prefs.results_cont && response !== nothing
            formatted_response = format_response(response_type, response)
            send(ws, "<div id='info'>$(formatted_response)<br>$(prog)</div>")
        else
            send(ws, "<div id='info'>$(prog)</div>")
        end
        response = prompt_ws(ws, question_bank[next_index])
        @info "Got response" response
        add_response!(responses, ComputerAdaptiveTesting.Responses.Response(response_type, next_index, response))
        terminating = termination_condition(responses, item_bank)
        if recorder !== nothing
            recorder(responses, 1, terminating)
        end
        if terminating
            @info "Met termination condition"
            break
        end
        question_idx += 1
    end
    summary_page = result_summary(question_bank, ability_estimator, responses, display_prefs; recorder=recorder)
    @info "summary" summary_page
    send(ws, summary_page)
end

function prompt_ws(ws, task::PromptedTask)
    @info "prompt_ws" task.prompt task.task
    send(ws, "<div id='question'>" * task.prompt * "</div>")
    prompt_ws(ws, task.task)
end

function prompt_ws(ws, task::SelectMultipleExact)
    answer_html = """
        <div id="response">
            $(exact_checkboxes("answer", answers(task)))
            $(submit_cancel_buttons)
        </div>
    """
    send(ws, answer_html)
    resp_str = receive(ws)
    #resp_str, _ = iterate(ws)
    resp = JSON3.read(resp_str)
    if resp[:action] != "Answer"
        return false
    end
    if !haskey(resp, "answer")
        return false
    end
    response_answers = Set(resp["answer"])
    return response_answers == task.correct
end

function prompt_ws(ws, task::SelectMultiplePartial)
    html = partial_checkboxes("answer", answers(task))
    send(ws, html)
    resp = iterate(ws)
end

function handle_ws(ws)
    params = queryparams(ws.request)
    log(msg) = send(ws, "<div id='info'>" * msg * "</div>")
    #descget = mk_descget(params)
    parse = ParamParser(params)
    datasets_parsed = parse(datasets)
    if datasets_parsed === nothing
        send(ws, "<div id='info'>Error parsing datasets</div>")
        return
    end
    dataset, question_bank = datasets_parsed 
    cat_rules = parse_cat_rules(parse)
    display_prefs = (
        ability_end = parse(form.ability_end),
        results_end = parse(form.results_end),
        record = parse(form.record),
        results_cont = parse(form.results_cont),
        answer_cont = parse(form.answer_cont),
    )
    run_cat_ws(ws, cat_rules, dataset, question_bank, display_prefs)
end

function ws_handler(middleware::Function)
    inner = stream_handler(middleware)
    (stream::HTTP.Stream) -> begin
        path = HTTP.URI(stream.message.target).path
        if (
            HTTP.WebSockets.is_upgrade(stream.message) &&
            path == "/test-ws" &&
            stream.message.method == "GET"
        )
            HTTP.WebSockets.upgrade((args...; kwargs...) -> Base.invokelatest(handle_ws, args...; kwargs...), stream)
        else
            inner(stream)
        end
    end
end

#=
function serve_cat(; kwargs...)
    serve(middleware=[], handler=ws_handler; kwargs...)
end

if abspath(PROGRAM_FILE) == @__FILE__
    serve_cat()
end
=#

end
