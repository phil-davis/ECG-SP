function rpeaks=findRpeaksSimple(ecg, samplingrate)

% usage: findRpeaksSimple(ecg, samplingrate)
%
% This function finds the R peaks in the provided time-domain signal.
%
% Output Parameters:
%
% rpeaks
%       Returns an array of the sample number for each detected R peak
%
% Input Parameters:
%
% ecg
%       An array of the time-domain samples of a single ECG lead signal
%
% samplingrate
%       An integer sampling rate (samples per second) of the signal
%
% findRpeaksSimple.m
%    Phil Davis    18 Apr 2018 initial version
%
% Use a high pass filter to remove lower frequencies
% takes out the DC and "normalizes" the signal
highPassFilter = fir1(samplingrate, 1/samplingrate*2,'high');
ecgFiltered = filter(highPassFilter,1,ecg);
delay = round(samplingrate/2);
% Square the signal, which makes the bigger values even more obvious
% This also highlights outlier values.
% Big spikes mess things up. In some of the data there are big negative
% spikes! So for now, leave this step out.
% ToDo: find a way to detect and remove/ignore big spikes
% ecgFilteredSquared = ecgFiltered .^ 2;

% Scale the data so we know the maximum
ecgScaled = ecgFiltered/(max(ecgFiltered)/7);
% Prefill assuming no peaks
ecgPeaks = zeros(size(ecgScaled));

lastPeakSample = -9999;
sampleFoundBelowThreshold = true;

% Look for peaks
for sample = 2:1:length(ecgScaled)-1
    if (ecgScaled(sample) < 2)
        sampleFoundBelowThreshold = true;
    end
    
    if (sample > delay) && (ecgScaled(sample) > ecgScaled(sample-1)) && (ecgScaled(sample) >= ecgScaled(sample+1))
        if (ecgScaled(sample) >= 2)
            % We have a big enough value that looks like a peak
            if (sampleFoundBelowThreshold)
                % This is the first peak seen since rising above the
                % threshold, so keep it.
                ecgPeaks(sample) = 1;
                lastPeakSample = sample;
            else
                % This is a later peak in the same "event" where the signal
                % has gone above the threshold. We only want to match
                % the highest peak in such high-signal events.
                if (ecgScaled(sample) > ecgScaled(lastPeakSample))
                    % This is a bigger peak in a "wiggly" section of high
                    % signal - prefer to keep it.
                    ecgPeaks(sample) = 1;
                    % And discard the previous peak
                    ecgPeaks(lastPeakSample) = 0;
                    % And remember the new highest
                    lastPeakSample = sample;
                end
            end
            sampleFoundBelowThreshold = false;
        end
    end
end

% Remove any peak at the very end
% That is likely an artifact of the very end sample(s) and should not be
% considered, if it ever happens.
ecgPeaks(length(ecgPeaks)) = 0;

% Find the positions of the non-zero entries - these are the peaks
delayedPeaks = find(ecgPeaks);
% Adjust for the FIR delay and return the resulting peaks
rpeaks = delayedPeaks - delay;

