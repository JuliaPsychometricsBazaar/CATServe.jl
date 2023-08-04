using Oxygen
using Oxygen.Core: stream_handler
using HypertextLiteral
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

include("./utils.jl")
include("./summary.jl")
include("./config.jl")
include("./templates.jl")

@get "/" function index()
    html_resp(index_tmpl())
end

@get "/test" function test(req)
    query = HTTP.URI(req.target).query
    @info "test" queryparams(req) query

    html_resp(test_tmpl(query))
end

@get "/test-ws" function test_ws(req)
    # TODO return forbidden/upgrade required
    @info "middleware failed" req
end

function cat_rules_from_params(params, descget)
    abildist = descget(ability_estimation_distribution, "abildist")
    abilest = descget(ability_estimation, "abilest")
    lower_bound = tryparse(Float64, params["lower_bound"])
    upper_bound = tryparse(Float64, params["upper_bound"])
    order = tryparse(UInt64, params["integrator_order"])
    integrator = descget(integrators, "integrator", lower_bound, upper_bound, order)
    optimizer = descget(optimizers, "optimizer", lower_bound, upper_bound)
    full_abilest = PointAbilityEstimator(abilest, abildist, integrator, optimizer)
    next_item_rule = descget(next_item_rules, "nextitem", full_abilest, abildist, integrator, optimizer)
    nitems = tryparse(UInt64, params["nitems"])
    termination_condition = descget(termination_conditions, "termcond", nitems)
    @info "stuff" abilest abildist full_abilest next_item_rule termination_condition integrator optimizer
    ComputerAdaptiveTesting.CatRules(full_abilest, next_item_rule, termination_condition)
end

function question_progress(ws, question_idx, termination_condition::FixedItemsTerminationCondition)
    send(ws, "<div id='info'>$(question_idx)/$(termination_condition.num_items)</div>")
end

function question_progress(ws, question_idx, termination_condition)
    send(ws, "<div id='info'>$(question_idx)/?</div>")
end

function run_cat_ws(ws, rules, item_bank, question_bank)
    (; next_item, termination_condition, ability_estimator, ability_tracker) = rules
    responses = TrackedResponses(
        BareResponses(ResponseType(item_bank)),
        item_bank,
        ability_tracker
    )
    question_idx = 1
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
        question_progress(ws, question_idx, termination_condition)
        response = prompt_ws(ws, question_bank[next_index])
        @info "Got response" response
        add_response!(responses, Response(ResponseType(item_bank), next_index, response))
        terminating = termination_condition(responses, item_bank)
        if terminating
            @info "Met termination condition"
            break
        end
        question_idx += 1
    end
    response = html_ws(result_summary(question_bank, ability_estimator, responses))
    @info "summary" response
    send(ws, response)
end

function prompt_ws(ws, task::PromptedTask)
    @info "prompt_ws" task.prompt task.task
    send(ws, "<div id='question'>" * task.prompt * "</div>")
    prompt_ws(ws, task.task)
end

function prompt_ws(ws, task::SelectMultipleExact)
    answer_html = html_ws(@htl("""
        <div id="response">
            $(exact_checkboxes("answer", answers(task)))
            $(submit_cancel_buttons)
        </div>
    """))
    send(ws, answer_html)
    resp_str, _ = iterate(ws)
    resp = JSON3.read(resp_str)
    if resp[:action] != "Answer"
        return false
    end
    response_answers = Set(resp["answer"])
    return response_answers == task.correct
end

function prompt_ws(ws, task::SelectMultiplePartial)
    send(
        ws,
        html_ws(partial_checkboxes("answer", answers(task)))
    )
    resp = iterate(ws)
end

#=
function prompt_readline(task::SelectMultipleExact)
    options = answers(task)
    options_fmt = join(options, "/")
    responses = Set()
    for idx in 1:length(task.correct)
        while true
            print("$idx/$(length(task.correct)): $options_fmt (blank = do not know) > ")
            word = readline()
            if strip(word) == ""
                return 0
            end
            if word in options
                push!(responses, word)
                break
            end
            println("Could not find $word in $options_fmt")
        end
    end
    return responses == task.correct ? 1 : 0
end

function prompt_readline(task::SelectMultiplePartial)
    options = answers(task)
    options_fmt = join(options, "/")
    responses = Set()
    while true
        print("$options_fmt (blank = finished) > ")
        word = readline()
        if strip(word) == ""
            break
        end
        if word in options
            push(responses, word)
        else
            println("Could not find $word in $options_fmt")
        end
    end
    return (length(intersect(task.correct, responses)), length(intersect(task.incorrect, responses)))
end
=#

function handle_ws(ws)
    params = queryparams(ws.request)
    log(msg) = send(ws, "<div id='info'>" * msg * "</div>")
    descget = mk_descget(params)
    dataset, question_bank = descget(datasets, "test")
    cat_rules = cat_rules_from_params(params, descget)
    run_cat_ws(ws, cat_rules, dataset, question_bank)
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

if abspath(PROGRAM_FILE) == @__FILE__
    serve(port=8001, handler=ws_handler)
end
