# Non-Ideal Reactor Plus

`Non-Ideal Reactor Plus` is a MATLAB application for teaching and studying ideal and non-ideal reactors through RTD-based analysis, reactor-performance prediction, equivalent-model interpretation, design-oriented comparison tools, and Simulink flowsheets. The main launcher provides access to the ideal app, the non-ideal app, and the graphical flowsheet tools.

This project extends the original `ReactorApp` line developed at the University of Alicante. The current non-ideal-reactor branch keeps that educational spirit while adding RTD-driven prediction routes, visualization layers, session persistence, and a design workspace for fitting, reactive comparison, and process-side optimization.

## Requirements

- MATLAB with support for `uifigure`-based apps
- A local copy of this project extracted from the distributed ZIP package

## Installation and Launch

There is no installer. Use the project as a normal MATLAB folder:

1. Download the project ZIP.
2. Extract it to any local folder.
3. Open MATLAB.
4. In MATLAB, either:
   - set the extracted project folder as the current folder, or
   - add the extracted folder to the MATLAB path.
5. Open the `ReactorApp toolbox` folder inside MATLAB if needed.

The recommended entry point is the main launcher:

```matlab
NonIdealReactorPlus
```

It opens the ideal reactor app, the non-ideal reactor app, and the Simulink flowsheet tools with loading feedback. The launcher stays open so that you can open another part of the application.

The individual reactor apps can also be launched directly:

### Direct non-ideal launch

Run:

```matlab
NonIdealReactorApp
```

### Direct ideal launch

Run:

```matlab
ReactorApp
```

From `ReactorApp`, you can also open the non-ideal branch by selecting the corresponding non-ideal reactor option.

## Academic Origin and Acknowledgment

This work is rooted in the original `ReactorApp` created by **Isabela Fons** at the **University of Alicante**. The original project should be cited through:

- [Journal article](https://www.sciencedirect.com/science/article/pii/S1749772826000096?ref=pdf_download&fr=RR-2&rr=a1a6adaa1fb8c112)
- [University of Alicante repository (TFG)](https://hdl.handle.net/10045/107785)
- [MathWorks File Exchange project](https://es.mathworks.com/matlabcentral/fileexchange/76917-reactorapp-toolbox?s_tid=prof_contriblnk)

## Current NonIdealReactorApp Author

The current `NonIdealReactorApp` branch and its non-ideal-reactor extensions are authored and maintained by the present project author.

- [GitHub repository](https://github.com/JavierBerenguer/Trabajo-Final-de-Grado.git)
- MathWorks project page  [![View Trabajo-Final-de-Grado on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://es.mathworks.com/matlabcentral/fileexchange/184241-trabajo-final-de-grado)
- University of Alicante TFG repository entry: `[pending link]`

## Documentation

This folder belongs to the technical documentation branch. For user-facing help inside the app, use:

- `Help > User Guide`
- `Help > Technical Guide`
