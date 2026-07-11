# Generic Sigma Adapter

The core ERIE-C numerical path is not Lenia-specific. Any finite-dimensional
system can enter the pipeline when it can be expressed as an action-to-sensory
map:

```julia
sigma(a::AbstractVector) -> AbstractVector
```

## Minimal Interface

`SigmaSystemAdapter` builds `sigma(a)` from three pieces:

- `state`: initial or reference system state
- `update(state, action) -> next_state`
- `feature_extractor(next_state) -> sensory_features`

The induced map is:

```julia
sigma(a) = feature_extractor(update(state, a))
```

## Requirements

- `action` is finite-dimensional and represented as `AbstractVector`.
- For a body-coupled system, each action coordinate weights a field-state
  intervention basis. The action must not rewrite the system's update law.
- `feature_extractor` returns a finite-dimensional vector.
- `sigma` is differentiable enough for `ForwardDiff.jacobian`.
- Discrete branches, random sampling, `argmax`, and hard thresholds should be
  avoided or replaced with smooth approximations.

## Pipeline

The generic end-to-end path is:

```julia
sensory = system_features(adapter, action)
T = system_sensitivity_tensor(adapter, action)
wld = system_actuated_world(adapter, action)
bridge = DCWorldBridge(dc_result, wld, direction)
summary = summarize_observation(sensory, wld, dc_result)
```

`run_system_pipeline` performs this sequence and returns a structured result.

## Lenia Position

Lenia should be implemented as one concrete `SigmaSystemAdapter`, not as a
special case in the core. Its `update` is the field evolution step and its
`feature_extractor` maps the field to sensory coordinates.

For Lenia, the action space is the coefficient vector of a low-rank spatial
intervention basis `B_M`. The update has the form:

```julia
acted_field = field + B_M * action
next_field = lenia_update(acted_field, experiment_conditions)
```

Kernel and growth parameters such as `mu`, `sigma`, `dt`, and the convolution
kernel are experiment conditions. They are not action coordinates. Changing
those conditions belongs to an external parameter sweep, not to ERIE's bodily
action.

The production action dimension is 16 to 24. Smaller dimensions remain valid
for prototype and CI runs, but artifacts must identify them as prototypes.

`lenia_body_action_contract` exposes this distinction through
`action_semantics=:field_intervention`,
`kernel_parameter_role=:experiment_condition`, and a production/prototype
profile.
