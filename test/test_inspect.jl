# Inspecting an item bank: the item response curves (/inspect) and the ability
# likelihoods (/inspect/outcomes). Both are WGLMakie plots embedded through
# Bonnie, re-rendered into #plot-panel by an htmx partial request whenever the
# selection changes -- so each testset both looks at the pixels and checks that
# a new Bonito session took the panel over.

@testset "inspect $value" for value in DATASET_VALUES
    @testset "item bank plot" begin
        with_test_page(BROWSER, "$BASE/"; name = "inspect-items-$value") do page
            select_dataset!(page, value)
            click!(inspect_button(page))
            # /inspect redirects the whole config form down to just ?test=…
            expect(page; to_have_url = "$BASE/inspect?test=$value")

            # The item list and its previews do not depend on the plot.
            @test is_checked(item_checkbox(page, 8))
            click!(preview_link(page, 3))
            expect(locator(page, "#preview-panel"); to_contain_text = "Question 3")

            reason = known_broken(value, :items)
            if reason !== nothing
                @info "known broken: item bank plot" value reason
                @test_broken plot_appears(page)
                return
            end

            expect(locator(page, "canvas"; strict = false);
                   to_have_count = 1, timeout = plot_timeout())
            bonito_ready(page)
            painted, colours = wait_painted(page)
            painted || @warn "item bank plot never painted" value colours
            @test painted

            # The plot is live, not a picture: it sits still on its own, and
            # zooming it redraws.
            at_rest = plot_fingerprint(page)
            @test plot_is_stable(page, at_rest)
            @test interact_with_plot!(page, at_rest)

            # Narrow the selection to items 1 and 2, then to item 1 alone: each
            # time a different set of curves must come back.
            check_plot_update!(page; label = "$value items 1-2") do
                for item in 3:8
                    toggle_item!(page, item)
                end
                @test !is_checked(item_checkbox(page, 3))
                click!(update_button(page))
            end
            check_plot_update!(page; label = "$value item 1") do
                toggle_item!(page, 2)
                click!(update_button(page))
            end
        end
    end

    @testset "likelihood plot" begin
        with_test_page(BROWSER, "$BASE/inspect?test=$value";
                       name = "inspect-outcomes-$value") do page
            click!(outcomes_tab(page))
            expect(page; to_have_url = "$BASE/inspect/outcomes?test=$value")

            reason = known_broken(value, :outcomes)
            if reason !== nothing
                @info "known broken: likelihood plot" value reason
                @test_broken plot_appears(page)
                return
            end

            @test is_checked(outcome_radio(page, 1, "unanswered"))
            expect(locator(page, "canvas"; strict = false);
                   to_have_count = 1, timeout = plot_timeout())
            bonito_ready(page)
            painted, colours = wait_painted(page)
            painted || @warn "likelihood plot never painted" value colours
            @test painted

            # With every item unanswered the likelihood is flat; answering
            # items, and then answering them differently, has to move it.
            check_plot_update!(page; label = "$value outcomes 1+ 2-") do
                choose_outcome!(page, 1, "correct")
                choose_outcome!(page, 2, "incorrect")
                click!(update_button(page))
            end
            check_plot_update!(page; label = "$value outcomes 1+ 2- 3+ 4+") do
                choose_outcome!(page, 3, "correct")
                choose_outcome!(page, 4, "correct")
                click!(update_button(page))
            end
        end
    end
end
