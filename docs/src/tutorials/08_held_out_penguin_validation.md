# Held-out ecological prediction: Palmer penguins
Simon Frost

- [A prediction exercise with real
  observations](#a-prediction-exercise-with-real-observations)
- [Provenance and a fixed split](#provenance-and-a-fixed-split)
- [Learn the representation using training data
  only](#learn-the-representation-using-training-data-only)
- [Score untouched observations against a prior
  baseline](#score-untouched-observations-against-a-prior-baseline)
- [What this result does and does not
  establish](#what-this-result-does-and-does-not-establish)
- [References](#references)

## A prediction exercise with real observations

The earlier scoring examples used simulated cases to demonstrate
machinery. Here the observations are real measurements of adult penguins
collected around Palmer Station in 2007-2009 ([Gorman et al.
2014](#ref-Gorman2014)). We fit a small finite Bayesian network on
2007-2008 and predict species in the untouched 2009 observations.

The model is a deliberately simple classifier built for this vignette,
not a published model from the zoo. The question is predictive
discrimination within this sampling setting, not a causal effect or a
conservation recommendation.

## Provenance and a fixed split

The CC0 `palmerpenguins` table ([Horst et al. 2020](#ref-Horst2020)) is
included verbatim beside this source in `data/penguins.csv`, with its
source commit, SHA-256 and attribution in `data/LICENSE.md`. No model
download or user’s model cache is involved.

``` julia
using CSV
using Statistics
using BayesianNetworks
using BayesianNetworkInference

rows = [NamedTuple(row) for row in CSV.File(joinpath(@__DIR__, "data", "penguins.csv");
                                           missingstring = "NA")]
complete = filter(rows) do r
    !any(ismissing, (r.species, r.bill_length_mm, r.flipper_length_mm, r.sex, r.year))
end
training = filter(r -> r.year < 2009, complete)
held_out = filter(r -> r.year == 2009, complete)
(available = length(rows), complete_cases = length(complete),
 excluded = length(rows) - length(complete), training = length(training),
 held_out = length(held_out), training_years = sort(unique(r.year for r in training)))
```

    (available = 344, complete_cases = 333, excluded = 11, training = 216, held_out = 117, training_years = [2007, 2008])

Rows missing a required predictor are excluded, with the count reported
above. That is a complete-case analysis, not an assumption that
missingness is harmless. All 2009 rows are kept together. No
discretization cut point or CPT is learned from them.

## Learn the representation using training data only

Bill and flipper lengths are discretized at training-set tertiles. Three
bins and Laplace smoothing with pseudocount one are fixed choices for
this demonstration; we do not tune them against the held-out scores.

``` julia
bins = [:small, :medium, :large]
species = [:Adelie, :Chinstrap, :Gentoo]
sexes = [:female, :male]
bill_cuts = quantile([r.bill_length_mm for r in training], [1 / 3, 2 / 3])
flipper_cuts = quantile([r.flipper_length_mm for r in training], [1 / 3, 2 / 3])
bin(x, cuts) = bins[x <= cuts[1] ? 1 : x <= cuts[2] ? 2 : 3]
as_case(r) = Dict(:Species => Symbol(r.species),
                  :BillLength => bin(r.bill_length_mm, bill_cuts),
                  :FlipperLength => bin(r.flipper_length_mm, flipper_cuts),
                  :Sex => Symbol(r.sex))
train_cases = as_case.(training)
test_cases = as_case.(held_out)
(bill_cuts = bill_cuts, flipper_cuts = flipper_cuts)
```

    (bill_cuts = [40.9, 46.43333333333333], flipper_cuts = [191.0, 209.0])

The classifier assumes the three predictors are conditionally
independent given species. This naive-Bayes assumption is an
approximation: the measurements are biologically related. It is not a
claim about causal direction.

``` julia
bn = bayesnet(:Species => species, :BillLength => bins, :FlipperLength => bins,
              :Sex => sexes;
              mechanisms = [:BillLength => :Species, :FlipperLength => :Species,
                            :Sex => :Species])
function fit_classifier(cases)
    prior_counts = [1.0 + count(c -> c[:Species] == s, cases) for s in species]
    fitted = bind_cpt(BayesModel(bn), :Species => prior_counts ./ sum(prior_counts))
    for (variable, levels) in ((:BillLength, bins), (:FlipperLength, bins), (:Sex, sexes))
        counts = ones(length(species), length(levels))
        for c in cases
            i = findfirst(==(c[:Species]), species)
            j = findfirst(==(c[variable]), levels)
            counts[i, j] += 1
        end
        fitted = bind_cpt(fitted, variable => counts ./ sum(counts; dims = 2))
    end
    return fitted
end
model = fit_classifier(train_cases)
validate(model; closed = true, unique_names = true, semantics = true)
```

## Score untouched observations against a prior baseline

`predict` withholds the target even though each case includes its
observed label. The baseline ignores predictors and uses only the
species prior learned from the same training cases. Lower Brier score,
higher log score and higher accuracy are better.

``` julia
prediction = predict(model, test_cases, :Species;
                     evidence_vars = [:BillLength, :FlipperLength, :Sex])
prior_prediction = baseline(model, test_cases, :Species)
results = [(method = label, n = length(p), brier = brier_score(p),
            log_score = log_score(p), accuracy = accuracy(p))
           for (label, p) in (("naive Bayes", prediction), ("training prior", prior_prediction))]
results
```

    2-element Vector{@NamedTuple{method::String, n::Int64, brier::Float64, log_score::Float64, accuracy::Float64}}:
     (method = "naive Bayes", n = 117, brier = 0.1768949277634653, log_score = -0.3298607488958938, accuracy = 0.8632478632478633)
     (method = "training prior", n = 117, brier = 0.6378120256896763, log_score = -1.0530985668347588, accuracy = 0.4444444444444444)

``` julia
confusion_matrix(prediction)
```

    ConfusionMatrix over 3 states (accuracy 0.8632)
      observed \ predicted     Adelie  Chinstrap     Gentoo
           Adelie         43          8          1
        Chinstrap          2         20          2
           Gentoo          0          3         38

Aggregate accuracy can conceal differences between species, which is why
the confusion matrix accompanies the proper scores. The same queries
through a junction tree agree numerically with variable elimination:

``` julia
via_tree = predict(model, test_cases, :Species;
                   evidence_vars = [:BillLength, :FlipperLength, :Sex],
                   backend = JunctionTree())
(brier_difference = brier_score(prediction) - brier_score(via_tree),
 log_score_difference = log_score(prediction) - log_score(via_tree))
```

    (brier_difference = -1.6653345369377348e-16, log_score_difference = 1.1102230246251565e-16)

Backend agreement establishes computational consistency on these cases,
not predictive validity. The held-out labels provide the separate
predictive evidence.

## What this result does and does not establish

This is a temporal holdout with training-only preprocessing and an
explicit baseline, rather than a fit scored on its own training
observations. It remains one small dataset from one region. We have not
established performance on new islands, different sampling protocols or
future environmental conditions; the simplified table also does not let
us audit repeated-individual dependence. The complete-case restriction,
coarse bins and conditional-independence assumption are substantive
limitations.

No uncertainty interval or population-level superiority claim follows
from a single holdout score. A scientific deployment would need a
prespecified target population, appropriate grouping, missing-data
treatment, calibration assessment and external validation. The practical
lesson is to refit every learned preprocessing step inside the training
split and keep the evaluation question separate from whether inference
returns the right number for the fitted model.

## References

<div id="refs" class="references csl-bib-body hanging-indent">

<div id="ref-Gorman2014" class="csl-entry">

Gorman, Kristen B., Tony D. Williams, and William R. Fraser. 2014.
“Ecological Sexual Dimorphism and Environmental Variability Within a
Community of Antarctic Penguins (Genus Pygoscelis).” *PLOS ONE* 9 (3):
e90081. <https://doi.org/10.1371/journal.pone.0090081>.

</div>

<div id="ref-Horst2020" class="csl-entry">

Horst, Allison Marie, Alison Presmanes Hill, and Kristen B. Gorman.
2020. *Palmerpenguins: Palmer Archipelago (Antarctica) Penguin Data*.
<https://doi.org/10.5281/zenodo.3960218>.

</div>

</div>
