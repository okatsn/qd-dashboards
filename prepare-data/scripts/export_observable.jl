# ============================================================================
# scripts/export_dashboard_data.jl
#
# Synopsis:
#   Discovers DVC-computed matrix outputs, validates schemas, and mirrors/stages
#   the lightweight Arrow binaries into the Observable Framework asset tree.
# ============================================================================

using PrepareData
using DataFrames
using Arrow

# ----------------------------------------------------------------------------
# Core Processing Functions
# ----------------------------------------------------------------------------

"""
    load_matrix_parameters() -> Dict

Parse the directory structure of the double-iqd results to extract the active combinations for:
- `window_size` (Float64 array)
- `ws_ratio` (Int array)
- `baseline` (String array)
"""
function load_matrix_parameters()
    base_dir = dir_data("double-iqd", "double_iqd")

    # 1. Discover window sizes from directories named window_size=*
    window_sizes = Float64[]
    ws_ratios = Int[]
    baselines = String[]

    if !isdir(base_dir)
        # Fallback to defaults
        println("⚠️ Base directory $base_dir not found. Using default matrix parameters.")
        return Dict(
            "window_size" => [10.0, 20.0],
            "ws_ratio" => [5],
            "baseline" => ["MeanMatchedBaseline", "ZeroBaseline"]
        )
    end

    for f in readdir(base_dir)
        if startswith(f, "window_size=")
            val = tryparse(Float64, split(f, "=")[2])
            if !isnothing(val) && !(val in window_sizes)
                push!(window_sizes, val)
            end
        end
    end

    # 2. Discover ws_ratios from subfolders
    for w in window_sizes
        w_dir = joinpath(base_dir, "window_size=$w")
        if isdir(w_dir)
            for f in readdir(w_dir)
                if startswith(f, "ws_ratio=")
                    val = tryparse(Int, split(f, "=")[2])
                    if !isnothing(val) && !(val in ws_ratios)
                        push!(ws_ratios, val)
                    end
                end
            end
        end
    end

    # 3. Discover baselines from subfolders
    for w in window_sizes, r in ws_ratios
        r_dir = joinpath(base_dir, "window_size=$w", "ws_ratio=$r")
        if isdir(r_dir)
            for f in readdir(r_dir)
                if startswith(f, "baseline=")
                    val = split(f, "=")[2]
                    if !(val in baselines)
                        push!(baselines, val)
                    end
                end
            end
        end
    end

    # Defaults in case empty
    isempty(window_sizes) && (window_sizes = [10.0, 20.0])
    isempty(ws_ratios) && (ws_ratios = [5])
    isempty(baselines) && (baselines = ["MeanMatchedBaseline", "ZeroBaseline"])

    return Dict(
        "window_size" => sort(window_sizes),
        "ws_ratio" => sort(ws_ratios),
        "baseline" => sort(baselines)
    )
end

"""
    validate_and_optimize_arrow(source_path::String, target_path::String; expected_cols=nothing)

Reads a source Arrow file, verifies it adheres to the expected column schema,
and writes it to the target dashboard directory using high-compression
settings (ZSTD) to minimize frontend payload size.
"""
function validate_and_optimize_arrow(source_path::String, target_path::String; expected_cols=nothing)
    if !isfile(source_path)
        println("⚠️  Source file not found: $source_path")
        return false
    end

    try
        # 1. Load table from source_path
        tbl = Arrow.Table(source_path)
        df = DataFrame(tbl)

        # 2. Assert expected columns exist
        if !isnothing(expected_cols)
            for col in expected_cols
                if !(string(col) in names(df))
                    error("❌ Schema mismatch: column '$col' not found in $source_path. Found: $(names(df))")
                end
            end
        end

        # 3. MKpath for target_path container folder
        mkpath(dirname(target_path))

        # 4. Write optimized Arrow table out to target_path with ZSTD compression
        Arrow.write(target_path, df; compress=:zstd)
        # Verify written file is readable
        Arrow.Table(target_path)
        return true
    catch e
        println("❌ Error processing $source_path: $e")
        rethrow(e)
    end
end

"""
    process_experiment_run(w_val::Float64, r_val::Int, b_val::String)

Orchestrates the discovery and staging of files for a single matrix point:
results/double_iqd/window_size={w}/ws_ratio={r}/baseline={b}/...
"""
function process_experiment_run(w_val::Float64, r_val::Int, b_val::String)
    w_str = string(w_val)
    r_str = string(r_val)

    # Source directory inside prepare-data/data/double-iqd/double_iqd
    source_dir = joinpath(dir_data("double-iqd", "double_iqd"), "window_size=$w_str", "ws_ratio=$r_str", "baseline=$b_val")
    # Target directory inside src/data/double_iqd
    target_dir = joinpath(dir_proj("..", "src", "data", "double_iqd"), "window_size=$w_str", "ws_ratio=$r_str", "baseline=$b_val")

    # 2. Export mandatory files ('density_xz.arrow', 'ql_xz.arrow')
    density_src = joinpath(source_dir, "density_xz.arrow")
    density_tgt = joinpath(target_dir, "density_xz.arrow")
    validate_and_optimize_arrow(density_src, density_tgt; expected_cols=[:x_km, :depth_km, :value])

    ql_src = joinpath(source_dir, "ql_xz.arrow")
    ql_tgt = joinpath(target_dir, "ql_xz.arrow")
    validate_and_optimize_arrow(ql_src, ql_tgt; expected_cols=[:x_km, :depth_km, :value])

    # 3. Conditional Check: If b_val == "MeanMatchedBaseline", export boundary profiles
    if b_val == "MeanMatchedBaseline"
        profile_x_src = joinpath(source_dir, "profile_x.arrow")
        profile_x_tgt = joinpath(target_dir, "profile_x.arrow")
        validate_and_optimize_arrow(profile_x_src, profile_x_tgt; expected_cols=[:depth_km, :value])

        profile_depth_src = joinpath(source_dir, "profile_depth.arrow")
        profile_depth_tgt = joinpath(target_dir, "profile_depth.arrow")
        validate_and_optimize_arrow(profile_depth_src, profile_depth_tgt; expected_cols=[:x_km, :value])
    end

    println("✅ Staged variation: w=$w_val, r=$r_val, b=$b_val")
end

# ----------------------------------------------------------------------------
# Main Orchestrator Entrypoint
# ----------------------------------------------------------------------------

"""
    main()

Main execution pipeline loop.
"""
function main()
    println("🚀 Starting Dashboard Data Asset Export Pipeline...")

    # Step 1: Load experiment matrix dimensions
    matrix_dims = load_matrix_parameters()

    # Step 2: Ensure target dashboard data directory exists
    target_dashboard_dir = dir_proj("..", "src", "data", "double_iqd")
    mkpath(target_dashboard_dir)

    # Step 3: Iterate through Cartesian Product of the matrix configurations
    # Replicates DVC Matrix behavior safely
    for w in matrix_dims["window_size"]
        for r in matrix_dims["ws_ratio"]
            for b in matrix_dims["baseline"]
                println("Processing variation: w=$w, r=$r, b=$b")
                process_experiment_run(w, r, b)
            end
        end
    end

    println("\n✅ Staging complete. Assets prepared for Observable Framework.")
end

# Script Entrypoint Guard
if !isempty(PROGRAM_FILE) && abspath(PROGRAM_FILE) == @__FILE__
    main()
end