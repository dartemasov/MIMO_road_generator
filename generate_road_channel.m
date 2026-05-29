function generate_road_channel(conf, debug_mode)
%GENERATE_ROAD_CHANNEL Generate MIMO channels using QuaDRiGa.
%
% Modes:
%   conf.channel_model = "stochastic"  -> original layout/scenario based generator
%   conf.channel_model = "cdl"         -> 3GPP/V2X CDL/TDL models via qd_builder.gen_cdl_model
%
% CDL configuration example:
%   conf.channel_model = "cdl";
%   conf.CDL.models = {'NR-CDL-A','NR-CDL-B','NR-CDL-C','NR-CDL-D','NR-CDL-E'};
%   conf.CDL.n_realizations = 1;
%   conf.CDL.ds = [];          % RMS delay spread in ns, [] keeps 3GPP default
%   conf.CDL.kf = [];          % K-factor in dB for CDL-D/E, [] keeps default
%   conf.CDL.asd = [];         % AoD angular spread in deg, [] keeps default
%   conf.CDL.asa = [];         % AoA angular spread in deg, [] keeps default
%   conf.CDL.esd = [];         % EoD angular spread in deg, [] keeps default
%   conf.CDL.esa = [];         % EoA angular spread in deg, [] keeps default
%   conf.CDL.cas_factor = 1;   % per-cluster angular-spread scaling

if ~exist('debug_mode','var') || isempty(debug_mode)
    debug_mode = false;
end

if ~isfield(conf, 'channel_model') || isempty(conf.channel_model)
    conf.channel_model = "stochastic";
end

rng(conf.seed);     % fix random seed

%% Common simulation parameters config
simpar = qd_simulation_parameters;
simpar.center_frequency = conf.center_freq;                                 % set center frequency
simpar.use_absolute_delays = conf.use_absolute_delays;
simpar.show_progress_bars = 0;                                              % don't show progress bars
simpar.use_random_initial_phase = conf.use_random_initial_phase;
simpar.set_speed(conf.speed_kmh, conf.sample_rate);                         % set speed and sample rate

%% Common BS antenna
BS = conf.BS;
if BS.tilt == "auto"
   % Such tilt, that antenna norm is directed to the middle of track
   BS.tilt = rad2deg(pi/2 - atan2(conf.min_distance_m + conf.track_len_m/2 , conf.BS.height));
end
tx_ant = qd_arrayant('3gpp-mmw', BS.Ain, BS.Bin, BS.Cin, BS.Din, BS.Ein, BS.Fin, BS.N_ver, BS.N_hor, BS.Lin, BS.Jin); % bs antenna object
tx_ant.rotate_pattern(BS.tilt, 'y');    % apply tilt
BS.Pos = [0; 0; BS.height];             % base station position

%% Common UE antenna
UE = conf.UE;
rx_ant = qd_arrayant('3gpp-3d', UE.N_ver, UE.N_hor, conf.center_freq, UE.Din, [], 1); % ue antenna object
rx_ant.rotate_pattern(UE.XY_rotation, 'z');         % user orientation in XY plane

channel_model = lower(string(conf.channel_model));

switch channel_model
    case "cdl"
        generate_cdl_channels(conf, simpar, tx_ant, rx_ant, BS, debug_mode);
    otherwise
        generate_stochastic_channel(conf, simpar, tx_ant, rx_ant, BS, UE, debug_mode);
end
end

function generate_stochastic_channel(conf, simpar, tx_ant, rx_ant, BS, UE, debug_mode)
scenario_idxs = randi(length(conf.possible_scenarios), 1, conf.n_segments); % select scenario idxs for segments
conf.scenarios = conf.possible_scenarios(scenario_idxs);                    % scenarios per segment

%% User track
[x_ue, y_ue, alpha] = random_line_in_sector(conf.track_len_m, conf.min_distance_m); % generate params of line track
rx_center_pos = [x_ue; y_ue; UE.height];                                   % initial user position
track = qd_track('linear', conf.track_len_m, alpha);                       % user track object
track.initial_position = rx_center_pos;                                    % apply ue position

track.interpolate_positions(simpar.samples_per_meter);                     % sample track using speed and sample rate
segment_len_snap = floor(track.no_snapshots / conf.n_segments);            % segment length in samples
track.segment_index = 1:segment_len_snap:(track.no_snapshots-1);           % segment starting sample indices
track.scenario = conf.scenarios;                                           % apply scenarios for segments

%% layout
layout = qd_layout(simpar);
layout.tx_array = tx_ant;
layout.rx_array = rx_ant;
layout.rx_track = track;

layout.rx_position = rx_center_pos;
layout.tx_position = BS.Pos;

%% builder
builder = layout.init_builder();
builder.gen_parameters(5);                                                 % generate environment parameters

chan = builder.get_channels();                                             % generate channels
chan = merge(chan, conf.segment_overlap);                                  % merge segments with overlapping into one channel

save_channel_response(conf, chan, layout, BS, debug_mode);
end

function generate_cdl_channels(conf, simpar, tx_ant, rx_ant, BS, debug_mode)
% Generate one or more CDL channels. Each model/realization is saved as a
% separate .mat file to keep the same H shape as the original implementation.

CDL = get_cdl_defaults(conf);
models = CDL.models;
n_models = numel(models);
n_realizations = CDL.n_realizations;

if n_models == 0
    error('generate_road_channel:CDL','conf.CDL.models must contain at least one CDL model name.');
end

% Match the original temporal sampling as closely as possible. QuaDRiGa CDL
% uses sample_density, so convert requested snapshots-per-meter to the
% equivalent sample density.
if conf.speed_kmh > 0
    samples_per_meter = 1 / (conf.speed_kmh/3.6 * conf.sample_rate);
    cdl_sample_density = samples_per_meter * min(simpar.wavelength) / 2;
    duration_s = (conf.n_samples - 1) * conf.sample_rate;
else
    cdl_sample_density = simpar.sample_density;
    duration_s = 0;
end

for i_model = 1:n_models
    for i_real = 1:n_realizations
        local_conf = conf;
        local_conf.seed = conf.seed + (i_model-1)*n_realizations + (i_real-1);
        rng(local_conf.seed);

        cdl_model = models{i_model};
        local_conf.scenarios = {cdl_model};
        local_conf.CDL.active_model = cdl_model;
        local_conf.CDL.realization_index = i_real;

        builder = qd_builder.gen_cdl_model( ...
            cdl_model, ...
            conf.center_freq, ...
            conf.speed_kmh/3.6, ...
            duration_s, ...
            CDL.ds, CDL.kf, CDL.asd, CDL.asa, CDL.esd, CDL.esa, ...
            CDL.cas_factor, cdl_sample_density );

        % Replace default omni antennas with the configured MIMO arrays.
        % Do not call gen_parameters again here, because gen_cdl_model has
        % already written the standardized CDL path powers/delays/angles.
        builder.tx_array = tx_ant;
        builder.rx_array = rx_ant;
        builder.tx_position = BS.Pos;
        builder.simpar.use_absolute_delays = conf.use_absolute_delays;
        builder.simpar.use_random_initial_phase = conf.use_random_initial_phase;
        builder.simpar.show_progress_bars = 0;

        chan = builder.get_channels();
        save_channel_response(local_conf, chan, [], BS, debug_mode);
    end
end
end

function CDL = get_cdl_defaults(conf)
if isfield(conf, 'CDL')
    CDL = conf.CDL;
else
    CDL = struct;
end

if ~isfield(CDL, 'models') || isempty(CDL.models)
    CDL.models = {'NR-CDL-A'};
end
if ischar(CDL.models) || isstring(CDL.models)
    CDL.models = cellstr(CDL.models);
end
if ~isfield(CDL, 'n_realizations') || isempty(CDL.n_realizations)
    CDL.n_realizations = 1;
end
if ~isfield(CDL, 'ds'); CDL.ds = []; end             % ns
if ~isfield(CDL, 'kf'); CDL.kf = []; end             % dB
if ~isfield(CDL, 'asd'); CDL.asd = []; end           % deg
if ~isfield(CDL, 'asa'); CDL.asa = []; end           % deg
if ~isfield(CDL, 'esd'); CDL.esd = []; end           % deg
if ~isfield(CDL, 'esa'); CDL.esa = []; end           % deg
if ~isfield(CDL, 'cas_factor') || isempty(CDL.cas_factor)
    CDL.cas_factor = 1;
end
end

function save_channel_response(conf, chan, layout, BS, debug_mode)
%% Channel
conf.carriers_position = linspace(-0.5, 0.5, conf.n_sc);                   % SCs centered around carrier frequency

if chan.no_snap < conf.n_samples
    error('generate_road_channel:notEnoughSnapshots', ...
        'Generated channel has %d snapshots, but conf.n_samples=%d. Increase duration/sample density or reduce conf.n_samples.', ...
        chan.no_snap, conf.n_samples);
end

H = chan.fr(conf.bw, conf.carriers_position, 1:conf.n_samples);            % Band-limited channel
H = single(H);

[Nrx, Ntx, Nf, Nt] = size(H);

% Save channel
out_dir = "data";
chan_dir = fullfile(out_dir, "channels");
fig_dir = fullfile(out_dir, "figures");

if ~exist(out_dir, "dir")
    mkdir(out_dir);
end

if ~exist(chan_dir, "dir")
    mkdir(chan_dir);
end

if ~exist(fig_dir, "dir")
    mkdir(fig_dir);
end

filetag = strcat( ...
    "channel_", ...
    strjoin(unique(conf.scenarios, 'stable'), "-"), ...
    "_", num2str(conf.n_samples), ...
    "_samples_", num2str(conf.sample_rate*1000), ...
    "_ms_seed_", num2str(conf.seed));

if isfield(conf, 'CDL') && isfield(conf.CDL, 'realization_index')
    filetag = strcat(filetag, "_realization_", num2str(conf.CDL.realization_index));
end

filename = fullfile(chan_dir, filetag + ".mat");
save(filename, "H", "conf", "-v7.3");

%% image plotting
if debug_mode
    H_plot = reshape(H, [Nrx, 2, BS.N_ver, BS.N_hor, Nf, Nt]);

    if ~isempty(layout)
        layout.visualize();                                                % visualize BS, UE positions, ue track
        fig_layout = gcf;

        savefig(fig_layout, fullfile(fig_dir, filetag + "_layout.fig"));
        exportgraphics(fig_layout, fullfile(fig_dir, filetag + "_layout.png"), "Resolution", 300);
    end

    fig_profiles = figure();
    tiledlayout(4, 1, "TileSpacing", "none")

    %% Power
    nexttile
    P = 10*log10(squeeze(mean(abs(H_plot).^2, [1,2,3,4,5])));              % Calculate power per each time sample in log scale
    plot(P);
    ylabel('Power dB');
    title('Power, Delay, Azimuth, Elevation profiles')

    %% Power delay profile plot
    pdp = squeeze(10*log10(mean(abs(ifft(H_plot, [], 5)).^2, [1,2,3,4]))); % Calculate power-delay profile in log scale

    nexttile
    imagesc(pdp);
    ylabel('Delay bin');

    %% Power azimuth profile plot
    pap = squeeze(10*log10(mean(abs(fft(H_plot, [], 4)).^2, [1,2,3,5])));  % Calculate power-azimuth profile in log scale

    nexttile
    imagesc(pap);
    ylabel('Azimuth bin');

    %% Power elevation profile plot
    pep = squeeze(10*log10(mean(abs(fft(H_plot, [], 3)).^2, [1,2,4,5])));  % Calculate power-elevation profile in log scale

    nexttile
    imagesc(pep);
    ylabel('Elevation bin');
    xlabel('Time snapshot');

    savefig(fig_profiles, fullfile(fig_dir, filetag + "_profiles.fig"));
    exportgraphics(fig_profiles, fullfile(fig_dir, filetag + "_profiles.png"), "Resolution", 300);
end
end
