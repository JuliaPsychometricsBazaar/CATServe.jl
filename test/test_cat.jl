# Taking a test end to end: configure it on the index page, answer every
# question over the /test-ws websocket, and check the summary -- the ability
# estimate, the prediction table, and the recorded playback plot.

# The dummy banks hold eight items and `best_item` has nothing left to offer
# once they are used up, so a run must ask for no more than that.
const NITEMS = 5

@testset "take a test: $value" for value in DATASET_VALUES
    with_test_page(BROWSER, "$BASE/"; name = "cat-$value") do page
        select_dataset!(page, value)
        set_value!(locator(page, "#nitems"), string(NITEMS))
        click!(ok_button(page))
        expect(page; to_have_url = r"/test\?")

        reason = known_broken(value, :cat)
        if reason !== nothing
            @info "known broken: CAT run" value reason
            @test_broken cat_reaches_summary(page)
            return
        end

        @testset "answering" begin
            for step in 1:NITEMS
                # The server sends the progress counter before each question,
                # which is the only synchronisation point the page offers.
                expect(locator(page, "#info");
                       to_contain_text = "$step/$NITEMS", timeout = plot_timeout())
                expect(locator(page, "#question"); to_contain_text = "Question")
                if step > 1
                    # results_cont is on by default: the previous answer is
                    # reported above the counter.
                    info = inner_text(locator(page, "#info"))
                    @test occursin("Correct", info) || occursin("Incorrect", info)
                end
                # A mix of right and wrong answers, so the ability estimate has
                # to be somewhere in the middle rather than pinned to a bound.
                click!(isodd(step) ? answer_button(page) : dont_know_button(page))
            end
        end

        @testset "summary" begin
            # The summary replaces the whole websocket container. Its default
            # tab is empty, so the ability estimate is behind "Model".
            model_tab = summary_tab(page, "model")
            expect(model_tab; to_be_visible = true, timeout = plot_timeout())
            click!(model_tab)

            model = summary_panel(page, "model")
            expect(model; to_contain_text = "Ability:")
            est = abilities(inner_text(model))
            @test !isempty(est)
            @test all(isfinite, est)
            # The estimate lives inside the configured integrator bounds; a
            # broken run lands on NaN, on Inf, or hard against a bound.
            @test all(a -> -6.0 < a < 6.0, est)
            @test all(a -> abs(a) < 5.0, est)

            # One row per item of the whole bank, answered or not.
            expect(locator(page, "div[name=model] tbody tr"; strict = false);
                   to_have_count = 8)
        end

        @testset "playback plot" begin
            click!(summary_tab(page, "playback"))
            expect(locator(page, "canvas"; strict = false);
                   to_have_count = 1, timeout = plot_timeout())
            bonito_ready(page)
            painted, colours = wait_painted(page)
            painted || @warn "playback plot never painted" value colours
            @test painted

            # Zooming it ought to redraw, the way the inspect plots do.
            at_rest = plot_fingerprint(page)
            @test plot_is_stable(page, at_rest)
            @info "known broken: playback plot interaction" value PLAYBACK_INTERACTION_BROKEN
            @test_broken interact_with_plot!(page, at_rest)
        end
    end
end
