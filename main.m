% Variables that can be changed are labeled with (!):

addpath quadriga_src/

conf = struct;

conf.seed = 0;                      % random seed 
conf.center_freq = 3.5e9;           % central frequency [Hz]
conf.n_sc = 408;                    % number of subcarriers
conf.scs = 240e3;                   % subcarrier spacing [Hz]
conf.bw = conf.n_sc * conf.scs;     % bandwidth [Hz]
conf.speed_kmh = 3.6;               % user speed [km/h]
conf.sample_rate = 5e-3;            % sample rate of channel measurements [s]
conf.n_samples = 2000;              % number of time samples
conf.min_distance_m = 50;           % minimal distance between BS and UE along x axis [m]
conf.n_segments = 1;                % number of uncorrelated channels
conf.segment_overlap = 0;           % segment overlapping ratio. in range [0, 1]
conf.use_random_initial_phase = 1;  % random phases per ray
conf.use_absolute_delays = 0;       % LOS path has 0 delay
conf.track_len_m = conf.speed_kmh/3.6 * conf.sample_rate * conf.n_samples;

% Channel generator mode:
%   "stochastic" keeps the original scenario-based road generator.
%   "cdl" uses QuaDRiGa qd_builder.gen_cdl_model for 3GPP/V2X CDL/TDL profiles.
conf.channel_model = "stochastic";

% CDL config. Used only when conf.channel_model = "cdl".
conf.CDL = struct;
% conf.CDL.models = {'NR-CDL-A','NR-CDL-B','NR-CDL-C','NR-CDL-D','NR-CDL-E'};
conf.CDL.models = {'NR-CDL-C'};
conf.CDL.ds = [363];             % RMS delay spread [ns], [] keeps standard profile
conf.CDL.kf = [];                % K-factor [dB], [] keeps standard profile
conf.CDL.asd = [];               % AoD angular spread [deg], [] keeps standard profile
conf.CDL.asa = [];               % AoA angular spread [deg], [] keeps standard profile
conf.CDL.esd = [];               % EoD angular spread [deg], [] keeps standard profile
conf.CDL.esa = [];               % EoA angular spread [deg], [] keeps standard profile
conf.CDL.cas_factor = 1;         % per-cluster angular spread scaling


conf.possible_scenarios = ...   % Channel scenarios possible to appear. See files from quadriga_src/config
    {'3GPP_38.901_UMa_LOS'};

%% Base station config
conf.BS = struct;
conf.BS.Ain = 2;                % Number of vertical elements (combined)
conf.BS.Bin = 1;                % Number of horizontal elements (combined)
conf.BS.Cin = conf.center_freq; % Center frequency in Hz
conf.BS.Din = 6;                % Polarization indicator. 6: 45 deg polarized elements
conf.BS.Ein = 0;                % Electric downtilt angle in deg
conf.BS.Fin = 0.35;             % Element spacing
conf.BS.N_ver = 4;              % Number of nested panels in a column
conf.BS.N_hor = 8;              % Number of nested panels in a row
conf.BS.Lin = 0.5;              % Panel spacing in vertical direction (in wavelenghts)
conf.BS.Jin = 0.5;              % Panel spacing in horizontal direction (in wavelenghts)

conf.BS.tilt = "auto";          % angle in plane (YZ) from vector y [deg]
conf.BS.height = 25;            % base station height [m]
%% User config
conf.UE = struct; 
conf.UE.N_ver = 1;              % number of vertical elements
conf.UE.N_hor = 2;              % number of ho  rizontal elements
conf.UE.Din = 6;                % polarization index. 6: 45 deg polarized elements
conf.UE.height = 1.5;           % user height [m]
conf.UE.XY_rotation = 180;      % user orientation in XY plane [m] (To west)

generate_road_channel(conf, true);
