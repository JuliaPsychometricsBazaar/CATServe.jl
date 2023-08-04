function format_item_question(idx, item_bank, question, tracked_responses, ability_estimator, response_dict)
    exp_resp = Aggregators.response_expectation(
        ability_estimator,
        tracked_responses,
        idx
    )
    @htl """<tr>$(tds(idx, item_params(item_bank, idx), summarise_task(question), get(response_dict, idx, "N/A"), exp_resp))</tr>"""
end

function result_summary(question_bank, ability_estimator, tracked)
    ability = ability_estimator(tracked)
    response_dict = Dict(zip(
        tracked.responses.indices,
        tracked.responses.values
    ))
    return @htl """
        <div id="window">
            <div>
                Ability: $(ability)
            </div>
            <div class="sunken-panel" style="height: 120px; width: 240px;">
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
                        $((
                            format_item_question(idx, tracked.item_bank, question, tracked, ability_estimator, response_dict)
                            for (idx, question) in enumerate(question_bank))
                        ))
                    </tbody>
                </table>
            </div>
        </div>
    """
end

function summarise_task(task::PromptedTask)
    "[$(typeof(task.task))] Correct: $(join(task.task.correct, ", ")); Incorrect: $(join(task.task.incorrect, ", ")) $(task.prompt)"
end