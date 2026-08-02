# Quantum-inspired probabilistic PV forecasting

This is the MATLAB code behind our paper on short-term solar PV power forecasting. The model is a CNN-BiLSTM that outputs quantiles instead of a single number, and its hyperparameters are tuned by a quantum-inspired evolutionary optimizer. The forecast intervals are then used to set the reserve in a small Simulink economic dispatch model.

I wrote and ran everything in MATLAB R2024b. You will need the Deep Learning Toolbox, the Statistics and Machine Learning Toolbox, and Simulink for the dispatch part. A GPU helps a lot but is not required.

## Data

The dataset is not in this repo because it is large. It is the solar and wind data from the State Grid renewable energy forecasting competition, hosted on Figshare (doi:10.6084/m9.figshare.17304221). Grab "Solar station site 1 (Nominal capacity-50MW).xlsx" and drop it in a folder called Dataset next to this code. If you keep it somewhere else, just change cfg.dataFile at the top of main_QIEO_PV.m.

## How to run

Open MATLAB, cd into this folder, and run:

    main_QIEO_PV

That loads the data, runs the optimizer, trains the final model, prints the metrics, and then builds and simulates the Simulink dispatch model. On my laptop (i5 with an RTX 2050) the optimizer takes about 10 to 25 minutes and the final training a few more. If you just want to check the pipeline works, cut cfg.qieo.popSize, cfg.qieo.generations and the epoch counts right down first.

To change the horizon, set cfg.horizonSteps: 1 is 15 minutes, 4 is one hour, 8 is two hours, 16 is four hours.

Once you have run it once, the results are saved to .mat files. You can redraw the figures without training again by running exportFigures, which writes editable .fig files along with png and pdf.

## Files

- main_QIEO_PV.m - the driver script, start here
- loadPVData.m - reads the Excel file, builds the sliding windows, splits into train/val/test
- trainQuantileNet.m - builds and trains the CNN-BiLSTM, also holds the ablation architectures
- pinballLoss.m - the multi-quantile pinball loss
- predictQuantiles.m - runs a trained network on a set of windows
- qieoOptimize.m - the quantum-inspired evolutionary optimizer
- psoOptimize.m - a particle swarm optimizer, used only for comparison
- evalForecast.m - the deterministic and probabilistic metrics
- buildDispatchModel.m and runDispatch.m - the Simulink dispatch model and its runner
- makeFigures.m and exportFigures.m - the result figures
- run_ablation.m - the ablation study
- run_sensitivity.m - the sensitivity study (the dispatch part needs no retraining)
- makeFig11_12.m - the ablation and sensitivity figures

## A couple of things worth knowing

The 15 minute horizon is genuinely hard to beat, because just carrying the last measured value forward is already a strong forecast at that lead time. If you want the learned model to clearly win on point error, turn on cfg.usePowerLag so it also sees the recent power. In our tests that dropped the normalized error a lot.

The optimizer trains a lot of small models, so the search dominates the runtime. Turning on a GPU and keeping the search subset small is the easiest way to keep it quick.

## Citation

If this code is useful for your work, please cite the paper. Bibtex will be added here once the paper is published.
