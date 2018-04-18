function rpeaks=findRpeaksLibrow(ecg, samplingrate)

% usage: findRpeaks(ecg, samplingrate)
%
% This function finds the R peaks in the provided time-domain signal.
% Inspired by ecgdemo.m from LIBROW http://www.librow.com
% and uses ecgdemowinmax.m from the same source
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
% findRpeaksLibrow.m
%    Phil Davis    15 Apr 2018 initial version
%    Phil Davis    18 Apr 2018 Renamed to findRpeaksLibrow
%
% Remove lower frequencies - takes out the DC and "normalizes" the signal
fresult=fft(ecg);
fresult(1 : round(length(fresult)*5/samplingrate))=0;
fresult(end - round(length(fresult)*5/samplingrate) : end)=0;
corrected=real(ifft(fresult));

% Filter - first pass - ToDo: what is the magic of 571/1000 ?
WinSize = floor(samplingrate * 571 / 1000);
if rem(WinSize,2)==0
    WinSize = WinSize+1;
end
filtered1=ecgdemowinmax(corrected, WinSize);

% Scale ecg
peaks1=filtered1/(max(filtered1)/7);
% Filter by threshold filter
for data = 1:1:length(peaks1)
    if peaks1(data) < 4
        peaks1(data) = 0;
    else
        peaks1(data)=1;
    end
end
positions=find(peaks1);
distance=positions(2)-positions(1);
% Returns minimum distance between two peaks
for data=1:1:length(positions)-1
    if positions(data+1)-positions(data)<distance 
        distance=positions(data+1)-positions(data);
    end
end

% Optimize filter window size
QRdistance=floor(0.04*samplingrate);
if rem(QRdistance,2)==0
    QRdistance=QRdistance+1;
end
WinSize=2*distance-QRdistance;

% Filter - second pass
% The fractional height at which we declare something to be "big" and thus
% an R peak can be tuned. In typical ECG time-series, the base signal
% is staying around a small range (e.g. +-0.25mV) and the R peak is around
% 5 or more times larger. That makes R peak detection easy!
% But some cases are seen where the base lead voltage drifts up for a time
% (e.g. towards 1mV) and the R peak is only at around 1.5mV
% In that case, those peaks are relatively lower than the typical max peaks
% in the whole of the data. So they are easily accidentally ignored.
%
% MIT-BIH record 101 at around 90 to 100 seconds is an example.
%
% Turning down the fraction here (e.g. from 4/7 to 2/9) finds more peaks
% But perhaps will find other artifacts too easily.
peaks_scale = 7;
peaks_trigger_point = 4;
filtered2=ecgdemowinmax(corrected, WinSize);
peaks2=filtered2/(max(filtered2)/peaks_scale);
for data=1:1:length(peaks2)
    if peaks2(data)<peaks_trigger_point
        peaks2(data)=0;
    else
        peaks2(data)=1;
    end
end

% Remove any peak at the very start or end
% Those are artifacts of the first or last samples and should not be
% considered, if they ever happen.
peaks2(1) = 0;
peaks2(length(peaks2)) = 0;

% Return the positions of the non-zero entries - these are the peaks
rpeaks=find(peaks2);
