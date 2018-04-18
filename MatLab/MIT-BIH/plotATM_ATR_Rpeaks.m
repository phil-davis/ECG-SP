function plotATM_ATR_Rpeaks(RecordName, startSeconds, endSeconds)

% usage: plotATM_ATR_Rpeaks('RECORD')
%
% This function reads files (RECORDm.mat RECORDm.info RECORD.atr).
% The first 2 are generated by 'wfdb2mat' from a PhysioBank record.
% It baseline-corrects and scales the time series contained in the .mat file,
% and plots them. The R peaks from the 'atr' file are plotted on top.
%
% R peak detection is also done, and those results plotted to compare
% with the peaks in the 'atr' file.
%
% Average RR interval and heart rate (bpm) are also displayed.
%
% Input Parameters:
%
% RecordName
%       The record "number" to read the signal and annotation data from
%       Do not include the "m" that is on the end of the MatLab format
%       files.
%
% startSeconds (optional)
%       How many seconds into the data to start the plot (default 0)
%
% endSeconds (optional)
%       How many seconds into the data to end the plot (default end of data)
%
% The baseline-corrected and scaled time series are the rows of matrix 'val',
% and each column contains simultaneous samples of each time series.
%
% The 'atr' files can be directly downloaded from PhysioNet, e.g.
% https://www.physionet.org/physiobank/database/mitdb/
% They do not require any conversion.
%
% 'wfdb2mat' is part of the open-source WFDB Software Package available at
%    http://physionet.org/physiotools/wfdb.shtml
% If you have installed a working copy of 'wfdb2mat', run a shell command
% such as
%    wfdb2mat -r 100s -f 0 -t 10 >100sm.info
% to create a pair of files ('100sm.mat', '100sm.info') that can be read
% by this function.
%
% The matlab format files needed by this function can also be produced by
% the PhysioBank ATM, at
%    http://physionet.org/cgi-bin/ATM
%

% plotATM_ATR_Rpeaks.m is an enhanced version of plotATM.m
%    O. Abdala     16 Mar 2009
%    James Hislop  27 Jan 2014 version 1.1
%    Phil Davis    01 Apr 2018 add start and end time, refactor
%    Phil Davis    15 Apr 2018 read an "atr" file and plot the R peaks
%    Phil Davis    15 Apr 2018 also do R peak detection and plot that

plotToEnd = false;

if (nargin == 2)
    % with only two arguments passed, we plot from 0 to arg2
    endSeconds = startSeconds;
    startSeconds = 0;
end

if (nargin < 2)
    % with only one argument, we plot all the data
    startSeconds = 0;
    endSeconds = 0;
    plotToEnd = true;
end

% Do not start or end in the past
startSeconds = max(startSeconds, 0);
endSeconds = max(endSeconds, 0);

if (startSeconds > endSeconds)
    % be nice and swap around the start and end, rather than erroring
    tempSeconds = startSeconds;
    startSeconds = endSeconds;
    endSeconds = tempSeconds;
end

if ((endSeconds - startSeconds) < 0.1)
    % Always plot at least 0.1 second
    % we do not want "empty" plots
    endSeconds = startSeconds + 0.1;
end

mName = strcat(RecordName, 'm');
infoName = strcat(mName, '.info');
matName = strcat(mName, '.mat');
Octave = exist('OCTAVE_VERSION');
load(matName, 'val');
fid = fopen(infoName, 'rt');
fgetl(fid);
fgetl(fid);
fgetl(fid);
[freqint] = sscanf(fgetl(fid), 'Sampling frequency: %f Hz  Sampling interval: %f sec');
sampleFreq = freqint(1);
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

numSamples = size(val,2);

startSample = int64(min((startSeconds*sampleFreq) + 1, numSamples));

if (plotToEnd)
    endSample = numSamples;
else
    endSample = int64(min(max(endSeconds*sampleFreq,1), numSamples));
end

% Get the annotation data from the atr file. 
% This has the beats (R peaks) detected and their type N(ormal) or some
% other beat annotation, or some special non-beat annotation character.
% The annotation file name has no 'm' at the end
[ann, anntype] = rdann(RecordName,'atr');

% Certain annotations are (supposed to be) on beats, so should be R-peaks
% see https://physionet.org/physiobank/annotations.shtml
beatAnnotationChars = "NLRBAaJSVrFejnE/fQ?";

% The non-beat annotations are anything else, but should be in this list:
% [!]x()ptu`'^|~+sT*D="@
% We ignore these for the purposes of this code that plots R-peaks

% Maybe true or not? Because the annotation sample numbers and the actual
% exact peaks sometimes match but are sometimes 1 sample off.
% The annotation sample numbers are zero-based?
% Increment them because the MatLab val array is 1-based?
%ann = ann + 1;

% Init variables
normal_r_peak_secs = [];
normal_r_peak_values = [];
arrhythmia_r_peak_secs = [];
arrhythmia_r_peak_values = [];
detected_r_peak_secs = [];
detected_r_peak_values = [];

r_peak_count = 0;
normal_r_peak_count = 0;
arrhythmia_r_peak_count = 0;
non_beat_annotations_count = 0;
non_beat_annotations_list = "";

r_peak_before_count = 0;
r_peak_after_count = 0;
r_peak_ok_count = 0;
first_r_peak_sample = 0;
last_r_peak_sample = 0;

detected_r_peak_count = 0;
detected_r_peak_before_count = 0;
detected_r_peak_after_count = 0;
detected_r_peak_ok_count = 0;
first_detected_r_peak_sample = 0;
last_detected_r_peak_sample = 0;

% Find the value of the peak at each annotation sample point.
% Use the values from signal 1 in the val array.
% Signal 1 is the signal from which the annotations were derived.
for k = 1 : length(ann)
    % Only use annotations that are between the desired start and end point
    if ((ann(k) >= startSample) && (ann(k) <= endSample))
        peak_sec = ann(k) * interval;
        peak_value = (val(1,ann(k)) - base(1)) / gain(1);
        if (anntype(k) == 'N')
            r_peak_count = r_peak_count + 1;
            normal_r_peak_count = normal_r_peak_count + 1;
            normal_r_peak_secs(normal_r_peak_count) = peak_sec;
            normal_r_peak_values(normal_r_peak_count) = peak_value;
        elseif (contains(beatAnnotationChars, anntype(k)))
            r_peak_count = r_peak_count + 1;
            arrhythmia_r_peak_count = arrhythmia_r_peak_count + 1;
            arrhythmia_r_peak_secs(arrhythmia_r_peak_count) = peak_sec;
            arrhythmia_r_peak_values(arrhythmia_r_peak_count) = peak_value;
        else
            non_beat_annotations_count = non_beat_annotations_count + 1;
            non_beat_annotations_list = non_beat_annotations_list + anntype(k);
        end
        
        peak_ok = true;
        
        last_r_peak_sample = ann(k);
        
        if (r_peak_count == 1)
            first_r_peak_sample = last_r_peak_sample;
        end
        
        % If the value of the sample before or after is higher, 
        % then the annotation is not exactly on the peak.
        if (val(1,ann(k)) < val(1,ann(k)-1))
            r_peak_before_count = r_peak_before_count + 1;
            peak_ok = false;
        end
        
        if (val(1,ann(k)) < val(1,ann(k)+1))
            r_peak_after_count = r_peak_after_count + 1;
            peak_ok = false;
        end
        
        if (peak_ok)
            r_peak_ok_count = r_peak_ok_count + 1;
        end
    end
end

% Do R-peak detection using the LIBROW-inspired algorithm
rpeaks = findRpeaks(val(1, :),sampleFreq);

for k = 1 : length(rpeaks)
    % Only use peaks that are between the desired start and end point
    if ((rpeaks(k) >= startSample) && (rpeaks(k) <= endSample))
        peak_sec = rpeaks(k) * interval;
        peak_value = (val(1,rpeaks(k)) - base(1)) / gain(1);
        detected_r_peak_count = detected_r_peak_count + 1;
        detected_r_peak_secs(detected_r_peak_count) = peak_sec;
        detected_r_peak_values(detected_r_peak_count) = peak_value;
        
        peak_ok = true;
        
        last_detected_r_peak_sample = rpeaks(k);
        
        if (detected_r_peak_count == 1)
            first_detected_r_peak_sample = last_detected_r_peak_sample;
        end
        
        % If the value of the sample before or after is higher, 
        % then the detected R peak is not exactly on a peak.
        if (val(1,rpeaks(k)) < val(1,rpeaks(k)-1))
            detected_r_peak_before_count = detected_r_peak_before_count + 1;
            peak_ok = false;
        end
        
        if (val(1,rpeaks(k)) < val(1,rpeaks(k)+1))
            detected_r_peak_after_count = detected_r_peak_after_count + 1;
            peak_ok = false;
        end
        
        if (peak_ok)
            detected_r_peak_ok_count = detected_r_peak_ok_count + 1;
        end

    end
end

% Report information about the numbers of annotated peaks found,
% and how many seem to be not quite in the right place.
fprintf('%d annotated R peaks are in the displayed time period\n', r_peak_count);
fprintf('%d are normal and %d are arrhythmias\n', normal_r_peak_count, arrhythmia_r_peak_count);

if (non_beat_annotations_count > 0)
    fprintf('%d non-beat annotations were found and ignored %s\n', non_beat_annotations_count, non_beat_annotations_list);
end

if (r_peak_ok_count < r_peak_count)
    fprintf('Only %d annotated peaks seem to be in the exactly correct place\n', r_peak_ok_count);
end

if (r_peak_before_count > 0)
    fprintf('The true peak is before %d annotated peaks\n', r_peak_before_count);
end

if (r_peak_after_count > 0)
    fprintf('The true peak is after %d annotated peaks\n', r_peak_after_count);
end

% Report information about the numbers of detected peaks found,
% and how many seem to be not quite in the right place.
fprintf('%d detected R peaks are in the displayed time period\n', detected_r_peak_count);

if (detected_r_peak_ok_count < detected_r_peak_count)
    fprintf('Only %d detected peaks seem to be in the exactly correct place\n', detected_r_peak_ok_count);
end

if (detected_r_peak_before_count > 0)
    fprintf('The true peak is before %d detected peaks\n', detected_r_peak_before_count);
end

if (detected_r_peak_after_count > 0)
    fprintf('The true peak is after %d detected peaks\n', detected_r_peak_after_count);
end

if (r_peak_count > 1)
    % We can calculate some inter-peak stats for the annotated R peaks
    peak_interval_first_to_last = (last_r_peak_sample - first_r_peak_sample) * interval;
    average_rr_interval_sec = peak_interval_first_to_last / (r_peak_count - 1);
    average_heart_rate_bpm = 60 / average_rr_interval_sec;
    fprintf('Average annotated    RR interval: %f\n', average_rr_interval_sec);
    fprintf('Average annotated heart rate bpm: %f\n', average_heart_rate_bpm);
    average_annotated_rr_interval_text = sprintf('Ave annotated RR %4.2f', average_rr_interval_sec);
    average_annotated_bpm_text = sprintf('Ave annotated BPM %3.0f', average_heart_rate_bpm);
else
    % with only 1 or no peaks, inter-peak stats are meaningless
    fprintf('Cannot calculate annotated average RR interval or heart rate - too few peaks\n');
    average_annotated_rr_interval_text = 'No annotated ave RR';
    average_annotated_bpm_text = 'No annotated BPM';
end

if (detected_r_peak_count > 1)
    % We can calculate some inter-peak stats for the detected R peaks
    peak_interval_first_to_last = (last_detected_r_peak_sample - first_detected_r_peak_sample) * interval;
    average_detected_rr_interval_sec = peak_interval_first_to_last / (detected_r_peak_count - 1);
    average_detected_heart_rate_bpm = 60 / average_detected_rr_interval_sec;
    fprintf('Average detected     RR interval: %f\n', average_detected_rr_interval_sec);
    fprintf('Average detected  heart rate bpm: %f\n', average_detected_heart_rate_bpm);
    average_detected_rr_interval_text = sprintf('Ave detected RR %4.2f', average_detected_rr_interval_sec);
    average_detected_bpm_text = sprintf('Ave detected BPM %3.0f', average_detected_heart_rate_bpm);
    stats_text = {sprintf('Ave RR %4.2f', average_detected_rr_interval_sec), sprintf('Ave BPM %3.0f', average_detected_heart_rate_bpm)};
else
    % with only 1 or no peaks, inter-peak stats are meaningless
    fprintf('Cannot calculate detected average RR interval or heart rate - too few peaks\n');
    average_detected_rr_interval_text = 'No detected ave RR';
    average_detected_bpm_text = 'No detected BPM';
end

val_to_plot = val(:,startSample:endSample);

for i = 1:size(val_to_plot, 1)
    val_to_plot(i, :) = (val_to_plot(i, :) - base(i)) / gain(i);
end

x = ((1:size(val_to_plot, 2)) * interval) + startSeconds;

figure;
% Plot the time-series data
plot(x', val_to_plot');
hold on;
% Overlay the normal R peaks in green
plot(normal_r_peak_secs', normal_r_peak_values', 'go', 'Markersize', 4);
% And overlay the arrhythmia R peaks in red
plot(arrhythmia_r_peak_secs', arrhythmia_r_peak_values', 'ro', 'Markersize', 4);
% Overlay the detected R peaks in blue
plot(detected_r_peak_secs', detected_r_peak_values', 'bo', 'Markersize', 4);
hold off;
% Add a text box with the stats
dim = [0.7 0.5 0.3 0.3];
stats_text = {average_annotated_rr_interval_text, average_annotated_bpm_text, average_detected_rr_interval_text, average_detected_bpm_text};
annotation('textbox', dim, 'String', stats_text, 'FitBoxToText', 'on');
% Add legends with signal lead and units details
for i = 1:length(signal)
    labels{i} = strcat(signal{i}, ' (', units{i}, ')'); 
end

legend(labels);
xlabel('Time (sec)');

% Add a title
title(sprintf('ECG plot for record %s with annotated and detected R peaks', RecordName));

% grid on

end
