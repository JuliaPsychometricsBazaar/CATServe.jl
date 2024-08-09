
function safe_params(item_bank, idx)
    if hasmethod(item_params, Tuple{typeof(item_bank), typeof(idx)})
        item_params(item_bank, idx)
    else
        ""
    end
end

function format_item_question(idx, item_bank, question, tracked_responses, ability_estimator, response_dict)
    exp_resp = Aggregators.response_expectation(
        ability_estimator,
        tracked_responses,
        idx
    )
    """<tr>$(tds(idx, safe_params(item_bank, idx), summarise_task(question), Base.get(response_dict, idx, "N/A"), string(exp_resp)))</tr>"""
end

function get_answers(question_bank, ability_estimator, tracked, display_prefs; recorder=nothing)
    """
    """
end

function get_model(question_bank, ability_estimator, tracked, display_prefs; recorder=nothing)
    ability = ability_estimator(tracked)
    response_dict = Dict(zip(
        tracked.responses.indices,
        tracked.responses.values
    ))
    """
        <div>
            Ability: $(ability)
        </div>
        <div class="sunken-panel" style="height: 600px; width: 800px;">
            <table>
                <caption>Question item parameters/predictions</caption>
                <thead>
                    <tr>
                        <th>Index</th>
                        <th>Parameters</th>
                        <th>Question</th>
                        <th>Correct?</th>
                        <th>Prediction</th>
                    </tr>
                </thead>
                <tbody>
                    $(join((
                        format_item_question(idx, tracked.item_bank, question, tracked, ability_estimator, response_dict)
                        for (idx, question) in enumerate(question_bank)
                    ), "\n"))
                </tbody>
            </table>
        </div>
    """
end

function get_playback(question_bank, ability_estimator, tracked, display_prefs; recorder)
    WGLMakie.activate!()
    force_asset_server!(NoServer())
    app = App() do session::Session
        lh_evolution_interactive(recorder)
    end
    app_html = sprint(io-> show(io, MIME"text/html"(), app))
    return app_html
end


function render_tab(tab)
    """
    <li
     role="tab"
     :aria-selected="current_tab == '$( tab.name )'">
        <a href="#$( tab.name )" @click.prevent="current_tab = '$( tab.name )'">
            $( tab.label )
        </a>
    </li>
    """
end

function render_tab_content(tab, args...; kwargs...)
    """
    <div x-show="current_tab == '$( tab.name )'" name="$( tab.name )">
        $( tab.content(args...; kwargs...) )
    </div>
    """
end

function result_summary(question_bank, ability_estimator, tracked, display_prefs; recorder=nothing)
    tabs = [
        (name="answers", label="Answers", content=get_answers),
        (name="model", label="Model", content=get_model),
    ]
    if recorder !== nothing
        push!(tabs, (name="playback", label="Playback", content=get_playback))
    end
    return """
        <div id="window" x-data="{current_tab:'answers'}">
            <menu role="tablist">
                $(join((render_tab(tab) for tab in tabs), "\n"))
            </menu>
            <div class="window" role="tabpanel">
                <div class="window-body">
                    $(join((render_tab_content(tab, question_bank, ability_estimator, tracked, display_prefs; recorder) for tab in tabs), "\n"))
                </div>
            </div>
        </div>
    """
end

function summarise_task(task::PromptedTask)
    "[$(typeof(task.task))] Correct: $(join(task.task.correct, ", ")); Incorrect: $(join(task.task.incorrect, ", ")) $(task.prompt)"
end
