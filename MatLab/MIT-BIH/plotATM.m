function plotATM(Name, start_seconds, end_seconds)

% usage: plotATM('RECORDm')
%
% This function reads a pair of files (RECORDm.mat and RECORDm.info) generated
% by 'wfdb2mat' from a PhysioBank record, baseline-corrects and scales the time
% series contained in the .mat file, and plots them.  The baseline-corrected
% and scaled time series are the rows of matrix 'val', and each
% column contains simultaneous samples of each time series.
%
% 'wfdb2mat' is part of the open-source WFDB Software Package available at
%    http://physionet.org/physiotools/wfdb.shtml
% If you have installed a working copy of 'wfdb2mat', run a shell command
% such as
%    wfdb2mat -r 100s -f 0 -t 10 >100sm.info
% to create a pair of files ('100sm.mat', '100sm.info') that can be read
% by this function.
%
% The files needed by this function can also be produced by the
% PhysioBank ATM, at
%    http://physionet.org/cgi-bin/ATM
%

% plotATM.m
%    O. Abdala     16 March 2009
%    James Hislop  27 January 2014  version 1.1
%    Phil Davis    01 April 2018    add start and end time, refactor

plot_to_end = false;

if (nargin == 2)
    % with only two arguments passed, we plot from 0 to arg2
    end_seconds = start_seconds;
    start_seconds = 0;
end

if (nargin < 2)
    % with only one argument, we plot all the data
    start_seconds = 0;
    end_seconds = 0;
    plot_to_end = true;
end

% Do not start or end in the past
start_seconds = max(start_seconds, 0);
end_seconds = max(end_seconds, 0);

if (start_seconds > end_seconds)
    % be nice and swap around the start and end, rather than erroring
    temp_seconds = start_seconds;
    start_seconds = end_seconds;
    end_seconds = temp_seconds;
end

if ((end_seconds - start_seconds) < 0.1)
    % Always plot at least 0.1 second
    % we do not want "empty" plots
    end_seconds = start_seconds + 0.1;
end

infoName = strcat(Name, '.info');
matName = strcat(Name, '.mat');
Octave = exist('OCTAVE_VERSION');
load(matName, 'val');
fid = fopen(infoName, 'rt');
fgetl(fid);
fgetl(fid);
fgetl(fid);
[freqint] = sscanf(fgetl(fid), 'Sampling frequency: %f Hz  Sampling interval: %f sec');
sample_freq = freqint(1);
interval = freqint(2);
fgetl(fid);

if(Octave)
    for i = 1:size(val, 1)
       R = strsplit(fgetl(fid), char(9));
       signal{i} = R{2};
       gain(i) = str2double(R{3});
       base(i) = str2double(R{4});
       units{i} = R{5};
    end
else
    rowData=textscan(fid,'%d %s %f %f %s');
    signal = rowData{2};
    gain = cell2mat(rowData(3));
    base = cell2mat(rowData(4));
    units = rowData{5};
end

fclose(fid);
val(val==-32768) = NaN;

num_samples = size(val,2);

start_sample = int64(min((start_seconds*sample_freq) + 1, num_samples));

if (plot_to_end)
    end_sample = num_samples;
else
    end_sample = int64(min(max(end_seconds*sample_freq,1), num_samples));
end

val_to_plot = val(:,start_sample:end_sample);

for i = 1:size(val_to_plot, 1)
    val_to_plot(i, :) = (val_to_plot(i, :) - base(i)) / gain(i);
end

x = ((1:size(val_to_plot, 2)) * interval) + start_seconds;
plot(x', val_to_plot');

for i = 1:length(signal)
    labels{i} = strcat(signal{i}, ' (', units{i}, ')'); 
end

legend(labels);
xlabel('Time (sec)');
% grid on

end
