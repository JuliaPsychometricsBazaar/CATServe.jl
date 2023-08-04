using ItemResponseDatasets: VocabIQ
using RIrtWrappers.Mirt: fit_4pl
using Serialization
using Base.Filesystem


function get_vocabiq()
    marked_df = VocabIQ.get_marked_df_cached()
    fit_4pl(marked_df; TOL=1e-2)[1], VocabIQ.questions
end

function main(outdir)
    mkpath(outdir)
    serialize(outdir * "/vocabiq.jls", get_vocabiq())
end

if abspath(PROGRAM_FILE) == @__FILE__
    main("datasets")
end