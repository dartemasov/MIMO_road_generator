%% TODO
% 1) turn into function
% 2) add comments
% 3) debug mode with images
% 4) segments

clear; 

seed = 106;
center_freq = 3.5e9;
bw = 100e6;
n_fft = 512;

speed_kmh = 5;
sample_rate = 50e-3; %5, 10 , 20, 40, 80, 160, 320

n_ver = 4;
n_hor = 8;

track_len_m = 40;
min_distance_m = 50;
n_segments = 2;
segment_overlap = 0.5;
possible_scenarios = {'3GPP_38.901_UMa_LOS', '3GPP_38.901_UMa_NLOS'}; % berlin, dresden

%% 
rng(seed);
scenario_idxs = randi(2, 1, length(possible_scenarios));
scenarios = possible_scenarios(scenario_idxs);

%% Bs antenna confing
BS = struct;
BS.Ain = 2;             % Number of vertical elements
BS.Bin = 1;             % Number of horizontal elements 
BS.Cin = center_freq;   % Center frequency in Hz
BS.Din = 6;             % Polarization indicator. 6: 45 deg polarized elements
BS.Ein = 0;             % Electric downtilt angle in deg
BS.Fin = 0.35;          % Element spacing
BS.Gin = n_ver;         % Number of nested panels in a column
BS.Hin = n_hor;         % Number of nested panels in a row
BS.Lin = 0.5;           % Panel spacing in vertical direction (in wavelenghts)
BS.Jin = 0.5;           % Panel spacing in horizontal direction (in wavelenghts)

BS.Tilt = 8.9;          % Mechanical Downtilt    Рассчитать, чтобы нормаль падала в середину трека
BS.Pos = [0;0;25];      % Base station position

%% UE antenna config
UE = struct; 
UE.N_VER = 1;
UE.N_HOR = 2;
UE.Din = 6;
UE.height = 1.5;

%% Simulation parameters config
simpar = qd_simulation_parameters;
simpar.center_frequency = center_freq;
simpar.use_absolute_delays = 0;
simpar.show_progress_bars = 0;
simpar.use_random_initial_phase = 1;
simpar.set_speed(speed_kmh, sample_rate);

tx_ant = qd_arrayant('3gpp-mmw', BS.Ain, BS.Bin, BS.Cin, BS.Din, BS.Ein, BS.Fin, BS.Gin, BS.Hin, BS.Lin, BS.Jin);
tx_ant.rotate_pattern(BS.Tilt, 'y');

rx_ant = qd_arrayant('3gpp-3d', UE.N_VER, UE.N_HOR, center_freq, UE.Din, [], 1);
%rx_ant.rotate_pattern(180, 'z');

%% User track  
[x_ue, y_ue, alpha] = random_line_in_sector(track_len_m, min_distance_m);
rx_center_pos = [x_ue; y_ue; 1.5];
t = qd_track('linear', track_len_m, alpha);
t.initial_position = rx_center_pos;

t.interpolate_positions(simpar.samples_per_meter);
segment_len_snap = floor(t.no_snapshots / n_segments);
t.segment_index = 1:segment_len_snap:(t.no_snapshots-1);
t.scenario = scenarios;
%% layout 
layout = qd_layout(simpar);
layout.tx_array = tx_ant;
layout.rx_array = rx_ant;
layout.rx_track = t;

layout.rx_position = rx_center_pos;
layout.tx_position = BS.Pos;

layout.visualize();

%% builder
builder = layout.init_builder();
builder.gen_parameters(5);

chan = builder.get_channels();
chan = merge(chan, segment_overlap);
%% Channel 
H = chan.fr(bw, n_fft);

[Nrx, Ntx, Nf, Nt] = size(H);
H = reshape(H, [Nrx, 2, n_ver, n_hor, Nf, Nt]);

figure();
%subplot(4,1,1);
tiledlayout(4, 1, "TileSpacing", "none")

%% Power
nexttile
P = 10*log10(squeeze(mean(abs(H).^2, [1,2,3,4,5])));
plot(P);
ylabel('Power dB');
title('Power, Delay, Azimuth, Elevation profiles')

%% Power delay profile plot
pdp = squeeze(10*log10(mean(abs(ifft(H, [], 5)).^2, [1,2,3,4])));

nexttile
imagesc(pdp);
ylabel('Delay bin');
%title('Power-delay profile')

%% Power azimuth profile plot
pap = squeeze(10*log10(mean(abs(fft(H, [], 4)).^2, [1,2,3,5])));

nexttile
imagesc(pap);
ylabel('Azimuth bin');
%title('Power-azimuth profile')

%% Power elevation profile plot
pep = squeeze(10*log10(mean(abs(fft(H, [], 3)).^2, [1,2,4,5])));

nexttile
imagesc(pep);
ylabel('Elevation bin');
xlabel('Time snapshot');

%title('Power-Elevation profile')
%save('channel_road_103.mat', 'H');



