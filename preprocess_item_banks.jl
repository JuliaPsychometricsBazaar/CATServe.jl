using ItemResponseDatasets: VocabIQ, MGKT
using RIrtWrappers.Mirt: Mirt
using RIrtWrappers.KernSmoothIRT: KernSmoothIRT
using Serialization
using Base.Filesystem
using ResumableFunctions
using FittedItemBanks
using FittedItemBanks.DummyData
using FittedItemBanks: iterate_simple_item_bank_specs
using Random: Random


function vocabiq_4pl_1d()
    marked_df = VocabIQ.get_marked_df_cached()
    (;
        model=Mirt.fit_4pl(marked_df; TOL=1e-2)[1],
        questions=VocabIQ.questions,
        name="VocabIQ 4PL 1-dimensional",
        value="vocabiq_4pl_1d",
    )
end

function vocabiq_2pl_2d()
    marked_df = VocabIQ.get_marked_df_cached()
    (;
        model=Mirt.fit_mirt_2pl(marked_df, 2; TOL=1e-2)[1],
        questions=VocabIQ.questions,
        name="VocabIQ 4PL 2-dimensional",
        value="vocabiq_4pl_2d",
    )
end

function vocabiq_bspline()
    marked_df = VocabIQ.get_marked_df_cached()
    (;
        model=Mirt.fit_spline(marked_df; TOL=1e-2)[1],
        questions=VocabIQ.questions,
        name="VocabIQ B-spline IRT",
        value="vocabiq_bspline",
    )
end

function vocabiq_monopoly()
    marked_df = VocabIQ.get_marked_df_cached()
    (;
        model=Mirt.fit_monopoly(marked_df; TOL=1e-2)[1],
        questions=VocabIQ.questions,
        name="VocabIQ Monotonous-polynomial IRT",
        value="vocabiq_monopoly",
    )
end

function vocabiq_ksirt()
    marked_df = VocabIQ.get_marked_df_cached()
    (;
        model=KernSmoothIRT.fit_ks_dichotomous(marked_df)[1],
        questions=VocabIQ.questions,
        name="VocabIQ Kernel-Smoothing IRT",
        value="vocabiq_ksirt",
    )
end

function mgkt_gpcm()
    marked_df = MGKT.get_marked_df_cached()
    (;
        model=Mirt.fit_gpcm(marked_df)[1],
        questions=MGKT.questions,
        name="MGKT GPCM IRT",
        value="mgkt_gpcm",
    )
end

@resumable function dummy_data()
    num_questions = 8
    for spec in iterate_simple_item_bank_specs()
        rng = Random.default_rng(42)
        item_bank = nothing
        if spec.domain isa VectorContinuousDomain
            item_bank = dummy_item_bank(rng, spec, num_questions, 2)
        else
            item_bank = dummy_item_bank(rng, spec, num_questions)
        end
        model_info = (;
            model=item_bank,
            questions=["Question $n" for n in 1:num_questions],
            name="8-item dummy " * spec_description_short(spec),
            value="dummy8_" * spec_description_slug(spec),
            description="Eight item dummy dataset. Model: " * spec_description_long(spec)
        )
        @yield model_info
    end
    rng = Random.default_rng(42)
    item_bank = dummy_item_bank(rng, MonopolyItemBank)
    model_info = (;
        model=item_bank,
        questions=["Question $n" for n in 1:num_questions],
        name="8-item dummy " * spec_description_short(spec),
        value="dummy8_" * spec_description_slug(spec),
        description="Eight item dummy dataset. Model: " * spec_description_long(spec)
    )
end

function main(outdir)
    mkpath(outdir)
    make_dataset(name) = length(ARGS) == 0 || ARGS[1] == name
    if make_dataset("vocabiq")
        serialize(outdir * "/vocabiq_4pl_1d.jls", vocabiq_4pl_1d())
        serialize(outdir * "/vocabiq_2pl_2d.jls", vocabiq_2pl_2d())
        serialize(outdir * "/vocabiq_bspline.jls", vocabiq_bspline())
        serialize(outdir * "/vocabiq_monopoly.jls", vocabiq_monopoly())
        serialize(outdir * "/vocabiq_ksirt.jls", vocabiq_ksirt())
    end
    if make_dataset("mgkt")
        serialize(outdir * "/mgkt_gpcm.jls", mgkt_gpcm())
    end
    if make_dataset("dummy8")
        dummy_data()
        for model_info in dummy_data()
            serialize("$outdir/$(model_info.value).jls", model_info)
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main("datasets")
end
