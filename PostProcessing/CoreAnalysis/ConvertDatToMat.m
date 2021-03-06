% ConvertDatToMat(working_dir,filespec,numField)
%
%   takes all .dat files from the directory working_dir, makes a new
%   subdirectory called comb, and combines the .dat files into .mat data
%   files
%
% ARGUMENTS:
%
%       working_dir :: string representation of directory to be analyzed
%
%       params.filespec     :: file format specification as a string (for
%           reading lines). 
%           EX: '%f %f %s %s %s %s %s %s'
%           
%
%       params.archiveDAT   :: 'on'/'off' 
%                   archive the DAT files after combining into DAT 
%                   default 'off'
%
%       params.folderName   :: String 
%                   Folder name for MAT files
%                   default './MAT_combined'                  
%

function faillist = ConvertDatToMat(working_dir,params)

%% Default parameters
params_default.filespec = '%f %f %s %s %s %s %s %s %s %s %f %f';
params_default.foldername = 'MAT_combined';
params_default.archiveDAT = 'off'; 
params_default.deleteDAT = 'off';
params_default.useArchiveDAT = 'off';
params_default.archiveDATName = 'rawDatFiles';

zip_complete = 0;
%% Assign parameters and populate with defaults if unspecificed in Function Call
S = fieldnames(params_default);
for i = 1:numel(S)
    if isfield(params,S{i})
        eval_str = strcat(S{i},'=',strcat('params.',S{i}),';');
        eval(eval_str);
    else
        eval_str = strcat(S{i},'=',strcat('params_default.',S{i}),';');
        eval(eval_str);
    end
end

numField = numel(strsplit(filespec));
%% Use Archive Data (zip)

%% Generate full file list
faillist = {};
filelist = dir(strcat(working_dir,'/*.dat'));
if isempty(filelist)
    error('ConvertDatToMat attempted on empty directory');
end

%Remove all empty files from the list

filelist = filelist([filelist.bytes]>0);

if ~exist(strcat(working_dir,'/',foldername), 'dir')
    mkdir(strcat(working_dir,'/',foldername));
end


%% Iterate through all files, processing and saving combined versions
fname = [working_dir,'/',filelist(1).name];
[working_buff] = read_dat_file(fname, filespec, numField);
frame_number = str2num(filelist(1).name(1:10));
start_frame = frame_number; 
mat_fname = [working_dir,'/',foldername,'/',filelist(1).name(1:end-4),'.mat'];
frame_run =1;

for i = 2:(length(filelist))
    fname = [working_dir,'/',filelist(i).name];
    framenumber_prev = frame_number;
    [record_list] = read_dat_file(fname, filespec, numField);
    frame_number = str2num(filelist(i).name(1:10));
    if ((framenumber_prev+1)==frame_number)
        %Because of hardware bug, remove 'odd' files that have > 25
        %nosepoke pairs
        frame_run = frame_run + 1;
        np = [0; record_list(:, 5); 0]>0.5; np = (diff(np) ~= 0);
        working_buff = [working_buff;record_list];
    else
        if numel(working_buff)>0
            if frame_run == (size(working_buff,1)/1000)
                dataFrame = working_buff;
                save(mat_fname,'start_frame','dataFrame');
            end
        end
        working_buff=record_list;
        start_frame = frame_number;
        frame_run = 1;
        mat_fname = [working_dir,'/',foldername,'/',filelist(i).name(1:end-4),'.mat'];        
    end
end

if  numel(working_buff)>0
    dataFrame = working_buff;
    save(mat_fname,'start_frame','dataFrame');
end

for i=1:numel(filelist)
    filelist_zip{i} = filelist(i).name;
end
%% Archive the data files
if strcmp(archiveDAT,'on')
    zip('rawDatFiles',filelist_zip);
    zip_complete = 1;
end

%% Delete Dat files
if strcmp(deleteDAT,'on')    
    if (strcmp(archiveDAT,'on')&&zip_complete)||strcmp(archiveDAT,'off')
        for i=1:numel(filelist_zip)
            delete(filelist_zip{i});
        end
    else
        disp('Not deleted because Archiving is On, and it Failed');
    end
end
end

function [record_list, frame_number] = read_dat_file(fname, filespec, numField)
% [record_list, frame_number] = read_dat_file(fname, filespec, numField)
%
%   reads the .dat file specified by fname in the format collectively
%   described by filespec and numField
%
% OUTPUTS
%
%   record_list - double matrix of length 1000, and columns equal to
%       numField+2 (analog inputs)
%
%   frame_number - number of .dat file (stripped from fname)
%
fid = fopen(fname);
frame_number = str2num(fname(1:10));

if (numel(filespec) == 0) || (numel(filespec) == 0)
    line_spec = fgetl(fid);
    line_spec = strsplit(line_spec,' ');
    
    numField = numel(line_spec);
    
    for i=1:numField
        data_format = line_spec{i};
        if numel(str2num(data_format))
            filespec = [filespec '%f '];
            isNumber_field(i) = 1;
        else
            filespec = [filespec '%s '];
            isNumber_field(i) = 0;
        end
    end
    
    frewind(fid);
end

datastruct = textscan(fid,filespec,1000);
filespec = strsplit(filespec,' ');

for kk=1:numField
    if strcmp(filespec{kk},'%f')
        record_list(:,kk) = [datastruct{kk}];
    else
        %boolean data is written to .dat file as 'TRUE'/'FALSE' - convert to 1/0
        record_list(:,kk) = strcmp(datastruct{:,kk},'TRUE');
    end
end

fclose(fid);
end
