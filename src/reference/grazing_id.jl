"""
    reference_grazing_id() -> InfluenceDiagramModel

The SPEC section 46 reference grazing-management influence diagram,
`InfluenceDiagrams.reference_grazing_model()`: 9 chance nodes, the `GrazingManagement`
decision informed by `ClimateForecast` and `CurrentVegetation`, and the utilities
`ConservationBenefit(Biodiversity)` (0 or 100) and `ManagementCost(GrazingManagement)`
(-40, -15, 0), with the tables of the `grazing_reference_id` fixtures of
BayesianNetworkFormats.jl bound. `load_model("reference_grazing_id")` returns the same
model and `model_ir("reference_grazing_id")` its `NetworkIR`.

```julia
g = reference_grazing_id()
optimize(g).expected_utility
```
"""
reference_grazing_id() = InfluenceDiagrams.reference_grazing_model()
