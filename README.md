# Non-Ideal Reactor Plus (NIRP)

[![View NIRP - (Non) Ideal Reactorapp Plus on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://es.mathworks.com/matlabcentral/fileexchange/185035-nirp-non-ideal-reactorapp-plus)

First public release: **v1.0 (October 2026)**. NIRP is under active development as a master's thesis project at the University of Alicante.

## Overview

Non-Ideal Reactor Plus is a MATLAB application for teaching and studying ideal and non-ideal chemical reactors. Run `NonIdealReactorPlus` to open the main launcher and choose **Ideal Reactor Design**, **RTD Analysis**, the steady Simulink flowsheet, or **Network RTD (tracer)**.

The current release includes:

- An ideal-reactor application for defining streams and reaction systems, analysing ideal reactors, and working with reactor arrangements and utilities.
- A non-ideal-reactor application with six main tabs:
  1. **RTD Analysis** for residence-time-distribution data and ideal RTD models.
  2. **Prediction Models** for segregation and maximum-mixedness predictions.
  3. **Tanks-in-Series**.
  4. **Dispersion Model**.
  5. **Design & Optimization**, including diagnosis and fitting, reactive-performance comparisons, and optimization.
  6. **Convolution**, with convolution and deconvolution workflows.
- A Simulink library for steady-state flowsheets built from ideal and RTD-based reactors. Its blocks are **Stream**, **CSTR**, **PFR**, **Non-ideal Reactor**, **Mixer**, **Splitter**, **Separator**, **Heater**, **Jacket**, **Recycle**, **Adjust**, and the **Flowsheet** controller.
- A separate **Network RTD (tracer)** library for linear series/parallel vessel networks and transfer of their exact RTD to the analysis app.
- Generatable Simulink example flowsheets and solved application sessions in `saves/`, including the convolution examples `SECT01`-`SECT03` and `SEC02`-`SEC09`.

## Requirements

NIRP was developed and tested with **MATLAB R2025b** and requires:

- Simulink
- Optimization Toolbox
- Global Optimization Toolbox
- Symbolic Math Toolbox
- Curve Fitting Toolbox
- Statistics and Machine Learning Toolbox

Simscape is not required.

## Installation and Launch

There is no installer. Download and extract the repository ZIP, or clone the repository with Git. Then start MATLAB and either make the repository root the current folder or add that folder to the MATLAB path.

Launch the complete application from the repository root:

```matlab
NonIdealReactorPlus
```

The launcher provides **Ideal Reactor Design**, **RTD Analysis**, **Flowsheet (Simulink)**, and **Network RTD (tracer)** actions. Each flowsheet group can open its block library, restore an example, or create a new model.

The reactor applications can also be launched directly:

```matlab
ReactorApp
NonIdealReactorApp
```

## Documentation and Help

User documentation is stored in `docs/`. In **RTD Analysis**, open **Help > User Guide** or **Help > Technical Guide**. In **Ideal Reactor Design**, select **Help**. The process-flowsheet and Network RTD guides are also included under `docs/` and linked from their Simulink workflows.

## Verification Scripts

The repository provides `scripts/runTests.m` for MATLAB tests, `simulink/run_examples.m` for generated flowsheet examples, and `simulink/run_validation.m` for Simulink validation cases.

## Academic Origin and Credits

NIRP extends **Non-Ideal-Reactor-App**, the undergraduate thesis work by **Javier Berenguer Sabater**, which in turn builds on the original **ReactorApp** created by **Isabela Fons** at the **University of Alicante**. NIRP is authored and maintained by Javier Berenguer Sabater.

ReactorApp references:

- [Journal article](https://www.sciencedirect.com/science/article/pii/S1749772826000096?ref=pdf_download&fr=RR-2&rr=a1a6adaa1fb8c112)
- [University of Alicante repository (TFG)](https://hdl.handle.net/10045/107785)
- [MathWorks File Exchange project](https://es.mathworks.com/matlabcentral/fileexchange/76917-reactorapp-toolbox?s_tid=prof_contriblnk)

Non-Ideal-Reactor-App references:

- [University of Alicante TFG repository entry](https://hdl.handle.net/10045/169730)
- [GitHub repository](https://github.com/JavierBerenguer/Trabajo-Final-de-Grado.git)
- [MathWorks File Exchange project](https://es.mathworks.com/matlabcentral/fileexchange/184241-trabajo-final-de-grado)

NIRP references:

- Master's thesis (University of Alicante repository): link pending publication.
- [MathWorks File Exchange project](https://es.mathworks.com/matlabcentral/fileexchange/185035-nirp-non-ideal-reactorapp-plus)

## License

NIRP is distributed under the [MIT License](LICENSE). The original ReactorApp components retain their [BSD license and copyright notice](license.txt).
