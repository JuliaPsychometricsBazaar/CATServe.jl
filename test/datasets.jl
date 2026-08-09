# The item banks the browser tests drive. They are not in the repository
# (datasets/ is gitignored), so generate them on demand with the same script
# production uses -- `dummy8` needs no R, see preprocess_item_banks.jl.

const DATASET_VALUES =
    split(get(ENV, "CATSERVE_E2E_DATASETS", "dummy8_gpcm,dummy8_4pl_mirt_dimd"), ",")

dataset_path(root, value) = joinpath(root, "datasets", "$value.jls")

function ensure_datasets(root)
    absent = filter(v -> !isfile(dataset_path(root, v)), DATASET_VALUES)
    isempty(absent) && return
    @info "Generating the dummy8 item banks" absent
    script = joinpath(root, "preprocess_item_banks.jl")
    cmd = Cmd(`$(Base.julia_cmd()) --startup-file=no --project=$root $script dummy8`; dir = root)
    # Pkg.test runs us inside a sandbox environment whose JULIA_LOAD_PATH must
    # not leak into the generator, which runs under the package's own project.
    run(addenv(cmd, "JULIA_LOAD_PATH" => "@:@v#.#:@stdlib"))
    still_absent = filter(v -> !isfile(dataset_path(root, v)), DATASET_VALUES)
    isempty(still_absent) ||
        error("preprocess_item_banks.jl did not produce: $(join(still_absent, ", "))")
    return
end
