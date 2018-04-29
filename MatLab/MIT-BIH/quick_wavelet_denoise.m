% Quick commands to do denoise with wavelets
load('100m.mat','val');
ecgsig = val(1,:);
% Gaussian noise 20dB
noise = wgn(1,650000,20);
% Add noise to ECG signal
ecgnoisy = ecgsig + noise;
dwtmode('per','nodisplay');
% Put your favorite wavelet name here
wname='sym6';
% Choose how many levels to go down in the DWT
level=5;
% Get the DWT coefficients just so we can plot them
[C,L] = wavedec(ecgnoisy,level,wname);
% Use the built-in wavelet de-noise function
% Different parameters can be played with here
ecgdenoised = wden(ecgnoisy,'rigrsure','s','sln',level,wname);
% Plot stuff
figure;
plot(C);
title('DWT coefficients of noisy ECG signal');
figure;
plot(ecgnoisy);
hold on;
plot(ecgdenoised);
hold off;
title('ECG data with noise added and after removing noise');
