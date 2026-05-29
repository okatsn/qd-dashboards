# scripts/export_observable.jl
using DataFrames
using Arrow
using PrepareData

# ============================================================================
# Paths
# ============================================================================
const SOURCE_DIR = dir_data("double-iqd", "double_iqd")
const TARGET_DIR = dir_proj("..", "src", "data") # Observable src/data folder

# ============================================================================
# Logging Utilities
# ============================================================================
log_success(msg) = println("\n✅ ", msg)
log_warn(msg) = println("\n⚠️  ", msg)
log_error(msg) = println("\n❌ ", msg)

# ============================================================================
# Main Logic
# ============================================================================
function export_for_dashboard()
    if !isdir(SOURCE_DIR)
        log_error("Source directory does not exist: $(SOURCE_DIR)")
        return
    end

    mkpath(TARGET_DIR)

    # Walk through the SOURCE_DIR to find experiment directories
    count = 0
    for entry in readdir(SOURCE_DIR)
        if startswith(entry, "experiment=")
            tag = replace(entry, "experiment=" => "")
            exp_dir = joinpath(SOURCE_DIR, entry)

            density_file = joinpath(exp_dir, "density_xz.arrow")
            ql_file = joinpath(exp_dir, "ql_xz.arrow")

            if !isfile(density_file) || !isfile(ql_file)
                log_warn("Missing raw arrow files for experiment tag: $(tag)")
                continue
            end

            println("Compacting and moving experiment: ", tag)

            # Load independent tables
            df_density = DataFrame(Arrow.Table(density_file))
            df_ql = DataFrame(Arrow.Table(ql_file))

            # Merge values onto layout columns and enforce Float64 types
            export_df = DataFrame(
                x_km=Float64.(df_density.x_km),
                depth_km=Float64.(df_density.depth_km),
                density=Float64.(df_density.value),
                ql=Float64.(df_ql.value)
            )

            # Save as standard Arrow IPC stream format
            target_path = joinpath(TARGET_DIR, "exp_$(tag).arrow")
            Arrow.write(target_path, export_df, compress=:lz4)
            count += 1
        end
    end

    if count > 0
        log_success("Web dashboard assets updated successfully. Processed $(count) experiments.")
    else
        log_warn("No experiment datasets were processed.")
    end
end

# SCRIPT ENTRYPOINT
if !isempty(PROGRAM_FILE) && abspath(PROGRAM_FILE) == @__FILE__
    # --- CLI EXECUTION ---
    println("Running in CLI mode...")
    export_for_dashboard()
else
    # --- INTERACTIVE EXECUTION (REPL/VSCode) ---
    println("Running in REPL/interactive mode. Run `export_for_dashboard()` to update assets.")
end