% Variables that can be changed are labeled with (!):

addpath quadriga_src/

conf = struct;

conf.seed = 0;                      % random seed 
conf.center_freq = 3.5e9;           % central frequency [Hz]
conf.n_sc = 408;                    % number of subcarriers
conf.scs = 240e3;                   % subcarrier spacing [Hz]
conf.bw = conf.n_sc * conf.scs;     % bandwidth [Hz]
conf.speed_kmh = 5;                 % user speed [km/h]
conf.sample_rate = 5e-3;            % sample rate of channel measurements [s]
conf.n_samples = 10;                % number of time samples
conf.min_distance_m = 50;           % minimal distance between BS and UE along x axis [m]
conf.n_segments = 10;               % number of uncorrelated channels
conf.segment_overlap = 0.5;         % segment overlapping ratio. in range [0, 1]
conf.use_random_initial_phase = 1;  % random phases per ray
conf.use_absolute_delays = 0;       % LOS path has 0 delay
conf.track_len_m = conf.speed_kmh/3.6 * conf.sample_rate * conf.n_samples;

conf.possible_scenarios = ...   % Channel scenarios possible to appear 
    {'3GPP_38.901_UMa_LOS'}; 
    % {'3GPP_38.901_UMa_LOS','3GPP_38.901_UMa_NLOS', ...
    % 'BERLIN_UMa_LOS', 'BERLIN_UMa_NLOS', ...
    % 'DRESDEN_UMa_LOS', 'DRESDEN_UMa_NLOS'};    

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
