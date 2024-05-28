using ItemResponseDatasets: VocabIQ
using RIrtWrappers.Mirt: fit_mirt
using RIrtWrappers.KernSmoothIRT
using Serialization
using Base.Filesystem


function vocabiq_4pl_1d()
    marked_df = VocabIQ.get_marked_df_cached()
    fit_4pl(marked_df; TOL=1e-2)[1], VocabIQ.questions
end

function vocabiq_monopoly()
    marked_df = VocabIQ.get_marked_df_cached()
    params = fit_mirt(marked_df; itemtype="monopoly", var"monopoly.k"=1)
    fit_4pl(marked_df; TOL=1e-2)[1], VocabIQ.questions
end

function vocabiq_ksirt()
    marked_df = VocabIQ.get_marked_df_cached()
    fit_ks_dichotomous(marked_df)[1], VocabIQ.questions
end

function main(outdir)
    mkpath(outdir)
    serialize(outdir * "/vocabiq_4pl_1d.jls", vocabiq_4pl_1d())
    serialize(outdir * "/vocabiq_ksirt.jls", vocabiq_ksirt())
end

if abspath(PROGRAM_FILE) == @__FILE__
    main("datasets")
end
