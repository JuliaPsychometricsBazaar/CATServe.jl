using PsychometricsBazaarBase.Integrators: Integrators
using ComputerAdaptiveTesting.Aggregators
using AdaptiveTestPlots: plot_likelihoods
using ComputerAdaptiveTesting.NextItemRules: mirtcat_quadpts
using Oxygen.Core.Util: redirect
using Oxygen.Types: LazyRequest, headers
using HTTP: HTTP
import URIs

function is_htmx(req)
    meta = headers(LazyRequest(request=req))
    return haskey(meta, "HX-Request")
end

function get_bonito_session(context, session_id)
    @info "getting" session_id
    bonito_context = context.ext[:bonito_connection]
    local session = nothing
    @lock bonito_context.lock begin
        @info "open sessions" collect(keys(bonito_context.open_connections))
        if session_id in keys(bonito_context.open_connections)
            session = bonito_context.open_connections[session_id]
        end
    end
    return session
end

function htmx_bonito_helper(cb, req, app)
    if is_htmx(req)
        sid = HTTP.header(req.headers, "Bonito-Session-ID")
        parent = get_bonito_session(CONTEXT[], sid)
        if parent === nothing
            @info "new parent"
            app_html = sprint(io -> show(io, MIME"text/html"(), app))
            new_parent_sid = app.session[].id
            app_html *= "<script>window.current_bonito_session_id = \"$new_parent_sid\";</script>\n"
        else
            @info "old parent"
            app_html = sprint(io -> show(io, MIME"text/html"(), app; parent=parent))
        end
        return app_html
    else
        app_html = sprint(io-> show(io, MIME"text/html"(), app))
        return cb(app_html)
    end
end

@get "/inspect" function inspect(req)
    uri_parsed = URIs.URI(req.target)
    params = URIs.queryparams(uri_parsed)
    param_pairs = URIs.queryparampairs(uri_parsed)
    test = params["test"]
    if haskey(params, "abildist")
        return redirect("/inspect?test=" * test)
    end
    form_parse = ParamParser(params)
    datasets_parsed = form_parse(datasets)
    if datasets_parsed === nothing
        #send(ws, "<div id='info'>Error parsing datasets</div>")
        return
    end
    item_bank, question_bank = datasets_parsed
    if haskey(params, "item")
        @info "params" params
        @info "item" params["item"]
    end

    WGLMakie.activate!()
    force_asset_server!(NoServer())
    items = [parse(Int, value) for (name, value) in param_pairs if name == "item"]
    if isempty(items)
        items = eachindex(item_bank)
    end
    app = App() do session::Session
        plot_item_bank(
            item_bank,
            fig = Figure(size = (950, 1000)),
            zero_symmetric = false,
            include_outcome_toggles = true,
            item_selection = nothing,
            include_legend=false,
            items=items
        )
    end
    htmx_bonito_helper(req, app) do app_html
        items = eachindex(item_bank)
        sid = app.session[].id

        return templates["inspect/inspect_items.html"](
            init=Dict(
                "sid" => sid,
                "item_bank" => item_bank,
                "question_bank" => question_bank,
                "plot_html" => app_html,
                "items" => items,
                "test" => test
            )
        )
    end
end

@get "/inspect/outcomes" function inspect_outcomes(req)
    uri_parsed = URIs.URI(req.target)
    params = URIs.queryparams(uri_parsed)
    form_parse = ParamParser(params)
    item_bank, question_bank = form_parse(datasets)
    test = params["test"]

    integrator = Integrators.even_grid(-6.0, 6.0, mirtcat_quadpts(1))
    ability_integrator = AbilityIntegrator(integrator)
    lh_ability_est = LikelihoodAbilityEstimator()
    prior_ability_est = PriorAbilityEstimator(std_normal)
    bare_responses = BareResponses(ResponseType(item_bank), Int[], Bool[])
    for item in eachindex(item_bank)
        @info "x" item
        name = "item-$item"
        if !(name in keys(params)) || params[name] == "unanswered"
            continue
        end
        response = params[name] == "correct" ? true : false
        add_response!(bare_responses, ComputerAdaptiveTesting.Responses.Response(ResponseType(item_bank), item, response))
    end

    tracked_responses = TrackedResponses(bare_responses, item_bank)
    app = App() do session::Session
        plot_likelihoods(
            [
                ("Likelihood", lh_ability_est),
                ("Prior", prior_ability_est),
            ],
            tracked_responses,
            ability_integrator,
            -6:0.1:6,
        )
    end

    htmx_bonito_helper(req, app) do app_html
        sid = app.session[].id
        items = eachindex(item_bank)

        return templates["inspect/inspect_outcomes.html"](
            init=Dict(
                "sid" => sid,
                "item_bank" => item_bank,
                "question_bank" => question_bank,
                "plot_html" => app_html,
                "items" => items,
                "test" => test
            )
        )
    end
end

@get "/preview" function preview(req)
    params = queryparams(req)
    parser = ParamParser(params)
    datasets_parsed = parser(datasets)
    if datasets_parsed === nothing
        return
    end
    item_bank, question_bank = datasets_parsed
    question_html = prompt_html(question_bank[parse(Int, params["item"])])
    is_hx = is_htmx(req)
    template_path = is_hx ? "preview_snip.html" : "preview.html"
    return templates[template_path](
        init=Dict(
            "question_html" => question_html,
            "width" => (is_hx ? "300" : "800")
        )
    )
end
