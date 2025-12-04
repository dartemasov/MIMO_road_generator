## How to use this repository
- Download [QuaDRiGa channel](https://github.com/fraunhoferhhi/QuaDRiGa) model and place `quadriga_src` folder in the root of the directory
- Use `main.m` for configuring and channel generating. Variables that could be easily changed are denoted with `(!)`. `conf.seed` is fixed for reproducebility.
- Function `generate_road_channel(conf, debug_mode);` is used for generating channel. Use `debug_mode=true` for plotting some usefull for analysis channel characteristics.
- Use generated `.mat` files for your needs. 
