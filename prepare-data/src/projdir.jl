dir_proj(args...) = pkgdir(PrepareData, args...)
dir_data(args...) = dir_proj("data", args...)
dir_results(args...) = dir_proj("results", args...)
dir_intermediate(args...) = dir_proj("intermediate", args...)
