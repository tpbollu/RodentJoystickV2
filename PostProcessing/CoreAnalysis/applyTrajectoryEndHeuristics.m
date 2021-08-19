% [stats] = applyTrajectoryEndHeuristics(stats)
% applies heuristics generated by 'generateTrajectoryEndHeuristics' to get trajectory end

function [stats_out] = applyTrajectoryEndHeuristics(stats,params)
try
    tstruct = stats.traj_struct;
    %% Use Generated Heuristics to assign values to Segments
    model = params.model;
    
    mu = model.mu;
    sigma = sqrt(model.Sigma);
    comp_prop = model.ComponentProportion;
    
    
    [mu,I] = sort(mu);
    sigma = sigma(I);
    comp_prop = comp_prop(I);
    
    for i=1:numel(tstruct)
        seginfo = tstruct(i).seginfo;
        if numel(seginfo)
            peakvel_seg = 1000*[tstruct(i).seginfo.peakvel];
            
            % Create a membership function list
            for j=1:numel(mu)
                mem_prob(j,:) = comp_prop(j)*gaussmf(log10(peakvel_seg),[sigma(j) mu(j)]);
            end
            [~,mem_index] = max(mem_prob,[],1);
            
            for j=1:numel(tstruct(i).seginfo)
                tstruct(i).seginfo(j).mem_index = mem_index(j);
            end
            clear mem_prob;
        end
    end
    
    %% Clip trajectories according to Identified membership functions
    for i=1:numel(tstruct)
        if numel(tstruct(i).seginfo)
            mem_index = [tstruct(i).seginfo.mem_index];
            traj_x = tstruct(i).traj_x_seg;
            traj_y = tstruct(i).traj_y_seg;
            velmag = 1000*sqrt(diff(traj_x).^2+ diff(traj_y).^2);
            rw_onset = tstruct(i).rw_onset;
            seginfo = tstruct(i).seginfo;
            traj_x_orig = tstruct(i).traj_x_orig;
            traj_y_orig = tstruct(i).traj_y_orig;
            
            % Was the trial rewarded?
            if tstruct(i).rw == 1
                % If trial was rewarded, plot until RW segment
                
                seg_start = [seginfo.start];
                seg_end = [seginfo.stop];
                seg_index = (rw_onset>=seg_start)&(rw_onset<=seg_end);
                rw_end = seginfo(seg_index).stop;
            end
            
            % Identify and eliminate the first 'JS return segment'
            % The JS return seg is usually the Fastest Segment, so find the
            % fastest seg going towards the center
            
            js_return_seg = find((mem_index == numel(mu)));
            if numel(js_return_seg)
                for j = 1:numel(js_return_seg)
                    % determine if the angle is towards the center
                    seg_x_start = traj_x(seginfo(js_return_seg(j)).start);
                    seg_y_start = traj_y(seginfo(js_return_seg(j)).start);
                    seg_x_end = traj_x(seginfo(js_return_seg(j)).stop);
                    seg_y_end = traj_y(seginfo(js_return_seg(j)).stop);
                    
                    angle_seg = atan2d((seg_y_end-seg_y_start),(seg_x_end-seg_x_start));
                    angle_tocenter = atan2d((0-traj_y_orig - seg_y_end),(0-traj_x_orig-seg_x_end));
                    angle_diff = mod(abs(angle_seg-angle_tocenter),180);
                    if angle_diff<30
                        %if Angle is toward the center; declare as 'return seg'
                        %and terminate
                        if js_return_seg(j)>1
                            seginfo = seginfo(1:(js_return_seg(j)-1));
                            mem_index = [seginfo.mem_index];
                        else
                            seginfo = seginfo(1:(js_return_seg(j)));
                            mem_index = [seginfo.mem_index];
                        end
                        break;
                    end
                end
            end
            
            % find the first 'correction segment' after a 'reach' segment
            reach_seg = find(mem_index == numel(mu));
            corr_seg = find((mem_index == 2)|(mem_index == 1));
            if numel(reach_seg)
                corr_seg = corr_seg(corr_seg>reach_seg(1));
                if numel(corr_seg)
                    index_end = seginfo(corr_seg(1)).stop;
                    seginfo = seginfo(1:corr_seg(1));
                else
                    index_end = seginfo(end).stop;
                end
            else
                index_end = seginfo(end).stop;
            end
            
            if tstruct(i).rw == 1
                index_end = min(index_end,rw_end);
            end
            
            % Used the estimated end point to assign outputs
            tstruct(i).traj_x = traj_x(1:index_end);
            tstruct(i).traj_y =  traj_y(1:index_end);
            tstruct(i).velmag = velmag(1:index_end);
            tstruct(i).seginfo = seginfo;
            % Temporary
            %figure;plot(tstruct(i).traj_x,tstruct(i).traj_y);axis equal;xlim([-7 7]);ylim([-7 7]);
        end
    end
    
    %% output
    stats_out = stats;
    stats_out.traj_struct = tstruct;
catch e
    display(e)
    flag = 1;
end
end