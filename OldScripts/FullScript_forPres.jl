include("ImportExport/build_and_run.jl")
include("ImportExport/build_and_save_cost_curves.jl")
using Gurobi
# using Plots

#Initialise global parameters
gpd = Dict()

gpd["endtime"] = 24*30
# gpd["endtime"] = 24*365
gpd["Climate_year"] = 1984
gpd["Climate_year_ts"] = 2012
gpd["ValOfLostLoad"] = 8000
gpd["country"] = "BE00"
gpd["scenario"] = "National Trends"
gpd["year"] = 2025
gpd["transport_price"] = 0.1
gpd["disc_rate"] = 0.07

types = ["isolated","NTC","TradeCurves_S","TradeCurves_PC"]
stepsizes = [100]
target_caps_for_curves = ["endo_invest","TYNDP"]
target_caps_for_curves = ["endo_invest"]
geo_scopes = ["All",["DE00","NL00","FR00","UK00","BE00","LUG1"]]
# types = ["TradeCurves"]
#Start looping over desired global parameters: 
results = DataFrame()

run_name = "Test_loop_4models_forpres_DN_vs_ALL_WS_$(gpd["endtime"])"

# m = Model(optimizer_with_attributes(Gurobi.Optimizer))
# row = full_build_and_optimize_investment_model(m,global_param_dict = gpd)

for simpl in [true,false]
    gpd["simplified"] = simpl
    for type in types
        gpd["type"] = type
        
        if gpd["type"] != "isolated"
            for geo_scope in geo_scopes
                gpd["geo_scope"] = geo_scope
                # Then, build the relevant cost curves 
                if gpd["type"] == "TradeCurves_S"
                    for tcfc in target_caps_for_curves
                        gpd["target_cap_for_curves"] = tcfc
                        for stepsize in stepsizes
                            gpd["stepsize"] =stepsize
                            build_and_save_cost_curves(gpd = gpd)
                            m = Model(optimizer_with_attributes(Gurobi.Optimizer))
                            row = full_build_and_optimize_investment_model(m,global_param_dict = gpd)
                            global results = vcat(results,row)
                            CSV.write(joinpath("Results","InvestmentModelResults","$(run_name).csv"),results)
                        end
                    end
                else
                    @assert(type in ["TradeCurves_PC","NTC"])
                    gpd["target_cap_for_curves"] = "NA"
                    gpd["stepsize"] = "NA"

                    m = Model(optimizer_with_attributes(Gurobi.Optimizer))
                    row = full_build_and_optimize_investment_model(m,global_param_dict = gpd)
                    global results = vcat(results,row)
                    CSV.write(joinpath("Results","InvestmentModelResults","$(run_name).csv"),results)
                end
            end
        else
            gpd["target_cap_for_curves"] = "NA"
            gpd["stepsize"] = "NA"
            gpd["geo_scope"] = "NA"

            m = Model(optimizer_with_attributes(Gurobi.Optimizer))
            row = full_build_and_optimize_investment_model(m,global_param_dict = gpd)
            global results = vcat(results,row)
            CSV.write(joinpath("Results","InvestmentModelResults","$(run_name).csv"),results)

        end

    end
end


# #Inspection

# trade_prices = m.ext[:sets][:trade_prices]
# timesteps = collect(1:gpd["endtime"])
# imports = [JuMP.value.(sum(m.ext[:variables][:import]["BE00",p,t] for p in trade_prices)) for t in timesteps]
# exports = [JuMP.value.(sum(m.ext[:variables][:export]["BE00",p,t] for p in trade_prices)) for t in timesteps]


# c_import = [sum(JuMP.value.(m.ext[:variables][:import][gpd["country"],neighbor,t] for neighbor in m.ext[:sets][:connections][gpd["country"]])) for t in timesteps]
# c_export = [sum(JuMP.value.(m.ext[:variables][:export][gpd["country"],neighbor,t] for neighbor in m.ext[:sets][:connections][gpd["country"]])) for t in timesteps]


# #Visualise total imports and exports
# plot(imports,label = "Imports TC")
# plot!(-exports, label = "Exports TC")
# plot!(c_import -c_export, label = "Net import interconnected")

# m.ext[:objective]