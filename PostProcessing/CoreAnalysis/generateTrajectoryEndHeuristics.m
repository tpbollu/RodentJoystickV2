% [heuristics] = generateTrajectoryEndHeuristics(stats)
% generates the parameter values and distributions to identify the 'end' of a joystick trial
function [heuristics] = generateTrajectoryEndHeuristics(stats,params)
    plot_flag = params.plot_flag;
    plot_type = params.plot_type;
    
    out = seg_peakvel(stats);
    peakvel = out.peakvel*1000; %Change to mm/s
    
    logNormPeakVel = log10(peakvel);
    
    %% Identify the number of Gaussian components in the Velocity distribution by checking convergence of Fit and AIC convergence
    %warning('off','all');
    for k= 1:5
        GMModel = fitgmdist(logNormPeakVel',k,'Replicates',10,'Options',statset('MaxIter',1000));
        aic(k) = GMModel.AIC;     
        converged = GMModel.Converged;
        if ~converged
          break
        end
    end
    %warning('on','all');
    
    AIC_decay = find(diff(aic)>0);
    
    if numel(AIC_decay)
        components =  AIC_decay(1)-1;
    else
        components = k-1;
    end
    
   %% recompute GMmodel for estimated values
   GMModel_sel = fitgmdist(logNormPeakVel',components,'Replicates',10,'options',statset('MaxIter',1000));
   heuristics.model = GMModel_sel;
   
   %% Estimated Mixture model
   evaluation_points = 0:0.01:3;
   
   %% Plot any selected data 
    if plot_flag
        if strcmp(plot_type,'LogNorm')
            histogram(logNormPeakVel,evaluation_points,'EdgeColor','none','normalization','pdf')
            hold on;
            plot(evaluation_points',pdf(GMModel_sel,evaluation_points'),'k','linewidth',2);
            legend('Data','GMM Fit')
            xlabel('Log (Peak Velocity)');
        end
    end
end

