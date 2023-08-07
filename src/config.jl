using ItemResponseDatasets: VocabIQ
using RIrtWrappers.Mirt: fit_4pl
using ComputerAdaptiveTesting.Aggregators: LikelihoodAbilityEstimator, PriorAbilityEstimator, MeanAbilityEstimator, ModeAbilityEstimator, AbilityOptimizer
using ComputerAdaptiveTesting.NextItemRules: ItemStrategyNextItemRule, ExhaustiveSearch1Ply, ExpectationBasedItemCriterion, AbilityVarianceStateCriterion
using ComputerAdaptiveTesting.TerminationConditions: FixedItemsTerminationCondition
using PsychometricsBazaarBase.Integrators: QuadGKIntegrator, FixedGKIntegrator
using PsychometricsBazaarBase.Optimizers: NelderMead, OneDimOptimOptimizer
using FittedItemBanks.DummyData: std_normal
using Serialization

const datasets_dir = "datasets"

const datasets = [
    (name="VocabIQ 4PL 1-dimensional", value="vocabiq_4pl_1d", get=() -> deserialize(datasets_dir * "/vocabiq_4pl_1d.jls")),
    (name="VocabIQ Kernel-Smoothing IRT", value="vocabiq_ksirt", get=() -> deserialize(datasets_dir * "/vocabiq_ksirt.jls")),
]

const ability_estimation_distribution = [
    (name="Likelihood", value="likelihood", get=() -> LikelihoodAbilityEstimator()),
    (name="Posterior", value="posterior", get=() -> PriorAbilityEstimator(std_normal))
]

const ability_estimation = [
    (name="Point mean estimate", value="mean", get=() -> MeanAbilityEstimator),
    (name="Point mode estimate", value="mode", get=() -> ModeAbilityEstimator),
]

const integrators = [
    (name="QuadGK", value="quadgk", get=(lo, hi, order) -> QuadGKIntegrator(lo, hi, order)),
    (name="FixedGK", value="fixedgk", get=(lo, hi, order) -> FixedGKIntegrator(lo, hi, order)),
]

const optimizers = [
    (name="NelderMead", value="neldermead", get=(lo, hi) -> AbilityOptimizer(OneDimOptimOptimizer(lo, hi, NelderMead()))),
]

const next_item_rules = [
    (
        name="Minimise expected ability variance",
        value="mepv",
        get=(
            (ability_estimator, dist_ability_estimator, integrator, optimizer) ->
            ItemStrategyNextItemRule(
                ExhaustiveSearch1Ply(false),
                ExpectationBasedItemCriterion(
                    ability_estimator,
                    AbilityVarianceStateCriterion(dist_ability_estimator, integrator)
                )
            )
        )
    ),
    (
        name="Maximum fisher information",
        value="mfi",
        get=(
            (ability_estimator, dist_ability_estimator, integrator, optimizer) ->
            ItemStrategyNextItemRule(
                ExhaustiveSearch1Ply(false),
                InformationItemCriterion(dist_ability_estimator, optimizer)
            )
        )
    ),
]

const termination_conditions = [
    (
        name="Fixed items",
        value="fixeditems",
        get=(n_items -> FixedItemsTerminationCondition(n_items))
    )
]

function confget(configs, val)
    idx = findfirst(c -> c.value == val, configs)
    if idx !== nothing
        return configs[idx]
    end
end

function mk_descget(params)
    function descget(conf, name, args...; kwargs...)
        desc = confget(conf, params[name])
        desc.get(args...; kwargs...)
    end
    descget
end
