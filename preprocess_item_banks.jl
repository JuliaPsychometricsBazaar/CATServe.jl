using ItemResponseDatasets: VocabIQ
using RIrtWrappers.Mirt: Mirt
using RIrtWrappers.KernSmoothIRT: KernSmoothIRT
using Serialization
using Base.Filesystem


function vocabiq_4pl_1d()
    marked_df = VocabIQ.get_marked_df_cached()
    Mirt.fit_4pl(marked_df; TOL=1e-2)[1], VocabIQ.questions
end

function vocabiq_monopoly()
    marked_df = VocabIQ.get_marked_df_cached()
    Mirt.fit_monopoly(marked_df; TOL=1e-2)[1], VocabIQ.questions
end

function vocabiq_ksirt()
    marked_df = VocabIQ.get_marked_df_cached()
    KernSmoothIRT.fit_ks_dichotomous(marked_df)[1], VocabIQ.questions
end

function main(outdir)
    mkpath(outdir)
    serialize(outdir * "/vocabiq_4pl_1d.jls", vocabiq_4pl_1d())
    serialize(outdir * "/vocabiq_ksirt.jls", vocabiq_ksirt())
end

if abspath(PROGRAM_FILE) == @__FILE__
    main("datasets")
end
