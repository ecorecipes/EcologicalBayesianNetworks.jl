# The SPEC section 45 reference habitat network is built by BayesianNetworks.jl
# (`reference_habitat_bn` for the structure, `reference_habitat_model` with the CPTs of
# the habitat_reference fixtures). Both are re-exported here so that the zoo is the one
# entry point for ecological examples; the manifest models/reference_habitat_bn registers
# `reference_habitat_model` as the constructor used by `load_model`.
using BayesianNetworks: reference_habitat_bn, reference_habitat_model
