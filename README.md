[README.md](https://github.com/user-attachments/files/30848684/README.md)
# Quantum-inspired probabilistic PV forecasting

MATLAB code for the paper on short-term solar PV power forecasting. The model is a CNN-BiLSTM that outputs quantiles instead of a single number, tuned by a quantum-inspired evolutionary optimizer. The forecast intervals then set the reserve in a small Simulink economic dispatch model.

Everything was written and run in MATLAB R2024b. You need the Deep Learning Toolbox, the Statistics and Machine Learning Toolbox, and Simulink for the dispatch part. A GPU helps but is not required.

## Data

The dataset is not included here because it is large. It is the solar and wind data from the State Grid renewable energy forecasting competition, on Figshare (doi:10.6084/m9.figshare.17304221). Download "Solar station site 1 (Nominal capacity-50MW).xlsx" and put it in a folder named Dataset next to this code. If you keep it elsewhere, change cfg.dataFile at the top of main_QIEO_PV.m.

## How to run

Open MATLAB, cd into this folder, and run:

    main_QIEO_PV

That loads the data, runs the optimizer, trains the final model, prints the metrics, and builds and simulates the Simulink dispatch model. By default the model includes the recent PV power as an input (cfg.usePowerLag = true), which is the proposed configuration. Set it to false to reproduce the weather-only variant.

To change the horizon, set cfg.horizonSteps: 1 is 15 minutes, 4 is one hour, 8 is two hours, 16 is four hours.

After a run, the results are saved to .mat files, so you can redraw the figures without training again.

## Files

Core pipeline
- main_QIEO_PV.m - driver script, start here
- loadPVData.m - reads the Excel file, builds windows, splits the data, handles the input toggles
- trainQuantileNet.m - builds and trains the CNN-BiLSTM, also holds the ablation architectures
- pinballLoss.m - the multi-quantile pinball loss
- predictQuantiles.m - runs a trained network on a set of windows
- qieoOptimize.m - the quantum-inspired evolutionary optimizer
- psoOptimize.m - a particle swarm optimizer, used for comparison
- evalForecast.m - the deterministic and probabilistic metrics
- buildDispatchModel.m, runDispatch.m - the Simulink dispatch model and its runner

Studies and figures
- run_ablation.m - the ablation study (writes ablation_results.csv and .mat)
- run_sensitivity.m - the sensitivity study (dispatch part needs no retraining)
- makeFigures.m - the result figures (forecast, intervals, reliability, convergence, dispatch)
- exportFigures.m - regenerates the result figures from saved .mat as editable .fig plus png and pdf
- makeFig11_12_IEEE.m - IEEE-style ablation (Fig. 11) and sensitivity (Fig. 12) figures

Graphics
- graphical_abstract.drawio - editable graphical abstract, open with draw.io

## Notes

The recent power input is the largest driver of accuracy at the 15-minute horizon. With it, the model reaches about 3.1% normalized RMSE and beats persistence. Turning it off drops the model to about 10%.

The optimizer trains many small models, so the search dominates the runtime. Keep the search subset small and use a GPU to keep it quick.

## Citation

If this code is useful for your work, please cite the paper. BibTeX will be added once the paper is published.
