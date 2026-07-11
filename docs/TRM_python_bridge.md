# Official TRM Python bridge

The upstream implementation is cloned separately under
`external/TinyRecursiveModels` and is not vendored into the ERIEC repository.

```bash
scripts/setup_trm_python.sh
```

On Intel macOS the setup installs the last compatible CPU PyTorch wheel. This is
enough for bridge validation and inference, but not for upstream training. The
official training runner hard-codes CUDA and requires a supported NVIDIA host.

Julia calls the bridge over a one-request/one-response JSON subprocess protocol:

```julia
using ERIEC

trm_python_health()
result = trm_python_infer(reshape([0, 1, 2, 1], 1, :); steps=3)
result.predictions
```

`trm_python_infer` runs all recursive reasoning steps before returning the final
prediction. It does not advance the ERIEC environment between internal TRM
steps. Official checkpoints must be accompanied by their exact architecture and
dataset metadata and are loaded with PyTorch's `weights_only=true` mode.
