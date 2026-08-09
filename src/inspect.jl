using PsychometricsBazaarBase.Integrators: Integrators
using ComputerAdaptiveTesting.Aggregators
using AdaptiveTestPlots: plot_likelihoods
using ComputerAdaptiveTesting.Compat.MirtCAT: mirtcat_quadpts
using Oxygen: redirect
using HTTP: HTTP
import URIs

function is_htmx(req)
    return HTTP.hasheader(req, "HX-Request")
end

function get_bonito_session(session_id)
    @info "getting" session_id
    return Bonnie.lookup(BONNIE[].context.sessions, session_id)
end

# The id of the root session created for this request's page, which owns the
# page's websocket. Fragments rendered for later htmx requests attach to it
# via the Bonito-Session-ID header.
current_root_session_id() = Bonnie.CURRENT_PAGE[].root.id

function render_subsession_html(parent, app)
    sub = Bonito.Session(parent)
    dom = Bonito.session_dom(sub, app)
    html = sprint(io -> show(io, MIME"text/html"(), dom))
    Bonito.mark_displayed!(sub)
    return html
end

function htmx_bonito_helper(cb, req, app)
    if is_htmx(req)
        sid = HTTP.header(req, "Bonito-Session-ID", "")
        parent = isempty(sid) ? nothing : get_bonito_session(sid)
        if parent === nothing
            @info "new parent"
            app_html = Bonnie.app_html(app)
            new_parent_sid = current_root_session_id()
            app_html *= "<script>window.current_bonito_session_id = \"$new_parent_sid\";</script>\n"
        else
            @info "old parent"
            app_html = render_subsession_html(parent, app)
        end
        return app_html
    else
        app_html = Bonnie.app_html(app)
        return cb(app_html, current_root_session_id())
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
    datasets_parsed = form_parse(datasets_select)
    if datasets_parsed === nothing
        #send(ws, "<div id='info'>Error parsing datasets</div>")
        return
    end
    item_bank, question_bank = datasets_parsed

    WGLMakie.activate!()
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
    htmx_bonito_helper(req, app) do app_html, sid
        items = eachindex(item_bank)

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
    item_bank, question_bank = form_parse(datasets_select)
    test = params["test"]

    integrator = Integrators.even_grid(-6.0, 6.0, mirtcat_quadpts(1))
    ability_integrator = AbilityIntegrator(integrator)
    lh_ability_est = LikelihoodAbilityEstimator()
    prior_ability_est = PosteriorAbilityEstimator(std_normal)
    bare_responses = BareResponses(ResponseType(item_bank), Int[], Bool[])
    for item in eachindex(item_bank)
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
            -6:0.1:6;
            fig = Figure(size = (950, 1000))
        )
    end

    htmx_bonito_helper(req, app) do app_html, sid
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
    datasets_parsed = parser(datasets_select)
    if datasets_parsed === nothing
        return
    end
    item_bank, question_bank = datasets_parsed
    question_html = prompt_html(question_bank[parse(Int, params["item"])])
    is_hx = is_htmx(req)
    template_path = is_hx ? "inspect/preview_snip.html" : "inspect/preview.html"
    return templates[template_path](
        init=Dict(
            "question_html" => question_html,
            "width" => (is_hx ? "300" : "800")
        )
    )
end
