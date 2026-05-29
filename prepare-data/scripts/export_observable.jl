# scripts/export_observable.jl
using DataFrames
using Arrow

const SOURCE_DIR =
    const TARGET_DIR = dir_proj("dashboard", "src", "data") # Observable src/data folder

function export_for_dashboard()
    mkpath(TARGET_DIR)
    params = load_params()["double_iqd"]

    for tag in keys(params["experiments"])
        println("Compacting and moving experiment: ", tag)
        exp_dir = joinpath(SOURCE_DIR, "experiment=$tag")

        !isdir(exp_dir) && continue

        # Load independent tables
        df_density = DataFrame(Arrow.Table(joinpath(exp_dir, "density_xz.arrow")))
        df_ql = DataFrame(Arrow.Table(joinpath(exp_dir, "ql_xz.arrow")))

        # Merge values onto layout columns
        export_df = DataFrame(
            x_km=df_density.x_km,
            depth_km=df_density.depth_km,
            density=df_density.value,
            ql=df_ql.value
        )

        # Save as standard Arrow IPC stream format
        target_path = joinpath(TARGET_DIR, "exp_$(tag).arrow")
        Arrow.write(target_path, export_df, compress=:lz4)
    end
    println("✅ Web dashboard assets updated successfully.")
end

export_for_dashboard()