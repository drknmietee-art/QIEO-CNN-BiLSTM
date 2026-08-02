function mdl = buildDispatchModel(Pmed, Pup, cfg)
%BUILDDISPATCHMODEL Programmatically create a Simulink dispatch model.
%   The model reads the forecast median, the forecast upper bound, and the
%   demand from the workspace. It computes conventional generation, the
%   interval-based reserve, a ramp-limited generation signal, and the cost.
%   Implements Eq. (23)-(26) as a discrete-time simulation.
%
%   Returns the model name. Signals are supplied later by runDispatch.

    mdl = 'pv_dispatch_model';
    if bdIsLoaded(mdl); close_system(mdl,0); end
    new_system(mdl);
    load_system(mdl);

    add = @(type,name,pos,varargin) add_block(type, [mdl '/' name], ...
        'Position', pos, varargin{:});

    % --- Source blocks (From Workspace) ------------------------------
    add('simulink/Sources/From Workspace','Pmed',[30 30 90 60], ...
        'VariableName','ts_Pmed','SampleTime','1');
    add('simulink/Sources/From Workspace','Pup',[30 110 90 140], ...
        'VariableName','ts_Pup','SampleTime','1');
    add('simulink/Sources/From Workspace','Demand',[30 200 90 230], ...
        'VariableName','ts_D','SampleTime','1');

    % --- Conventional generation Pg = D - Pmed (Eq.24) ---------------
    add('simulink/Math Operations/Add','SubPg',[160 110 190 160], ...
        'Inputs','+-');
    % --- Ramp limiter on Pg (Eq.26) ---------------------------------
    add('simulink/Discontinuities/Rate Limiter','Ramp',[230 110 270 160], ...
        'RisingSlewLimit',num2str(cfg.capacityMW*0.2), ...
        'FallingSlewLimit',num2str(-cfg.capacityMW*0.2));

    % --- Reserve = Pup - Pmed (Eq.25) -------------------------------
    add('simulink/Math Operations/Add','SubR',[160 30 190 80], ...
        'Inputs','+-');

    % --- Cost = cg*Pg + cr*Reserve (Eq.23) --------------------------
    cg = 40; cr = 8;                          % example unit costs
    add('simulink/Math Operations/Gain','Cg',[320 120 360 150], ...
        'Gain',num2str(cg));
    add('simulink/Math Operations/Gain','Cr',[320 40 360 70], ...
        'Gain',num2str(cr));
    add('simulink/Math Operations/Add','CostSum',[410 70 440 120], ...
        'Inputs','++');

    % --- Sinks (To Workspace) ---------------------------------------
    add('simulink/Sinks/To Workspace','Pg_out',[320 200 380 230], ...
        'VariableName','sim_Pg','SaveFormat','Array');
    add('simulink/Sinks/To Workspace','R_out',[410 200 470 230], ...
        'VariableName','sim_R','SaveFormat','Array');
    add('simulink/Sinks/To Workspace','Cost_out',[500 80 560 110], ...
        'VariableName','sim_Cost','SaveFormat','Array');

    % --- Wiring ------------------------------------------------------
    add_line(mdl,'Demand/1','SubPg/1','autorouting','on');
    add_line(mdl,'Pmed/1','SubPg/2','autorouting','on');
    add_line(mdl,'SubPg/1','Ramp/1','autorouting','on');
    add_line(mdl,'Ramp/1','Cg/1','autorouting','on');
    add_line(mdl,'Ramp/1','Pg_out/1','autorouting','on');

    add_line(mdl,'Pup/1','SubR/1','autorouting','on');
    add_line(mdl,'Pmed/1','SubR/2','autorouting','on');
    add_line(mdl,'SubR/1','Cr/1','autorouting','on');
    add_line(mdl,'SubR/1','R_out/1','autorouting','on');

    add_line(mdl,'Cr/1','CostSum/1','autorouting','on');
    add_line(mdl,'Cg/1','CostSum/2','autorouting','on');
    add_line(mdl,'CostSum/1','Cost_out/1','autorouting','on');

    % --- Solver settings (discrete, one step per 15-min interval) ----
    N = numel(Pmed);
    set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
        'FixedStep','1','StartTime','0','StopTime',num2str(N-1));

    save_system(mdl);
    fprintf('  Simulink model "%s" created with %d blocks.\n', ...
        mdl, numel(find_system(mdl,'Type','Block')));
end
