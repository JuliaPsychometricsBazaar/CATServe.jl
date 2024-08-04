using ItemResponseDatasets: VocabIQ
using RIrtWrappers.Mirt: fit_4pl
using ComputerAdaptiveTesting.Aggregators: LikelihoodAbilityEstimator, PriorAbilityEstimator, MeanAbilityEstimator, ModeAbilityEstimator, AbilityOptimizer
using ComputerAdaptiveTesting.NextItemRules: ItemStrategyNextItemRule, ExhaustiveSearch1Ply, ExpectationBasedItemCriterion, AbilityVarianceStateCriterion
using ComputerAdaptiveTesting.TerminationConditions: FixedItemsTerminationCondition
using PsychometricsBazaarBase.Integrators: QuadGKIntegrator, FixedGKIntegrator, even_grid
using PsychometricsBazaarBase.Optimizers: NelderMead, OneDimOptimOptimizer
using FittedItemBanks.DummyData: std_normal
using Serialization

const datasets_dir = "datasets"

const datasets = SelectWidget(
    name="test",
    label="Datasets",
    options=[
        (name="VocabIQ 4PL 1-dimensional", value="vocabiq_4pl_1d", get=() -> deserialize(datasets_dir * "/vocabiq_4pl_1d.jls")),
        (name="VocabIQ Kernel-Smoothing IRT", value="vocabiq_ksirt", get=() -> deserialize(datasets_dir * "/vocabiq_ksirt.jls")),
    ]
)

const ability_estimation_distribution = SelectWidget(
    name="abildist",
    label="Distribution",
    options=[
        (name="Likelihood", value="likelihood", get=() -> LikelihoodAbilityEstimator()),
        (name="Posterior", value="posterior", get=() -> PriorAbilityEstimator(std_normal))
    ]
)

const ability_estimation = SelectWidget(
    name="abilest",
    label="Estimation",
    options = [
        (name="Point mean estimate", value="mean", get=() -> MeanAbilityEstimator),
        (name="Point mode estimate", value="mode", get=() -> ModeAbilityEstimator),
    ]
)

const integrators = SelectWidget(
    name="integrator",
    label="Integrator",
    options=[
        (name="QuadGK", value="quadgk", get=(lo, hi, order) -> QuadGKIntegrator(lo, hi, order)),
        (name="FixedGK", value="fixedgk", get=(lo, hi, order) -> FixedGKIntegrator(lo, hi, order)),
        (name="even_grid", value="evengrid", get=(lo, hi, order) -> even_grid(lo, hi, order)),
    ]
)

const ability_tracker = SelectWidget(
    name="abiltrack",
    label="Ability Tracker",
    options=[
        (name="Prefer none", value="prefernone"),
        (name="Prefer yes", value="preferyes"),
    ]
)

const optimizers = SelectWidget(
    name="optimizer",
    label="Optimizer",
    options=[
        (name="NelderMead", value="neldermead", get=(lo, hi) -> AbilityOptimizer(OneDimOptimOptimizer(lo, hi, NelderMead()))),
    ]
)

const next_item_rules = SelectWidget(
    name="nextitem",
    label="Next item rule",
    options=[
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
)

const termination_conditions = SelectWidget(
    name="termcond",
    label="Termination condition",
    options=[
        (
            name="Fixed items",
            value="fixeditems",
            get=(n_items -> FixedItemsTerminationCondition(n_items))
        )
    ]
)

function mk_form(args...)
    (; zip(Symbol.([arg.name for arg in args]), args)...)
end

const form = mk_form(
    datasets,
    ability_estimation_distribution,
    ability_estimation,
    NumberWidget(name="lower_bound", label="Integrator / optimizer lower bound", default=-6.0),
    NumberWidget(name="upper_bound", label="Integrator / optimizer upper bound", default=6.0),
    integrators,
    NumberWidget(name="integrator_order", label="Integrator order", default=39),
    #ability_tracker,
    optimizers,
    next_item_rules,
    termination_conditions,
    NumberWidget(name="nitems", label="Number of items", default=10),
    CheckBoxWidget(name="ability_end", label="Display ability at end", default=true),
    CheckBoxWidget(name="results_end", label="Display results and predictions at end", default=true),
    CheckBoxWidget(name="record", label="Record responses so trace can be show at end", default=true),
    CheckBoxWidget(name="results_cont", label="Display correct/incorrect during test", default=true),
    CheckBoxWidget(name="answer_cont", label="Display correct answer during test", default=false),
)