include("ImportExport/build_and_run.jl")
include("ImportExport/build_and_save_cost_curves.jl")
using Gurobi
# using Plots

#Initialise global parameters
gpd = Dict()

gpd["endtime"] = 24*364
gpd["Climate_year"] = 1984
gpd["Climate_year_ts"] = 2012
gpd["ValOfLostLoad"] = 8000
gpd["country"] = "BE00"
gpd["scenario"] = "National Trends"
gpd["year"] = 2025
gpd["transport_price"] = 0.1
gpd["disc_rate"] = 0.07


types = ["TCS"]
stepsizes = [200,100,50]
target_caps_for_curves = ["endo_invest"]
#target_caps_for_curves = ["endo_invest"]
geo_scopes = ["All"]
trans_caps_others = ["S"]
# types = ["TradeCurves"]
#Start looping over desired global parameters: 
results = DataFrame()

run_name = "Loop_4models_granularity_5_$(gpd["endtime"])"

# m = Model(optimizer_with_attributes(Gurobi.Optimizer))
# row = full_build_and_optimize_investment_model(m,global_param_dict = gpd)
t_start = time()
for simpl in [true]
    gpd["simplified"] = simpl
    for type in types
        gpd["type"] = type
        if gpd["type"] != "isolated"
            for geo_scope in geo_scopes
                gpd["geo_scope"] = geo_scope
                if gpd["type"] == "TCS"
                    gpd["trans_cap_other"] = "NA"
                    for tcfc in target_caps_for_curves
                        gpd["target_cap_for_curves"] = tcfc
                        for stepsize in stepsizes
                            gpd["stepsize"] =stepsize
                            m = Model(optimizer_with_attributes(Gurobi.Optimizer))
                            row = full_build_and_optimize_investment_model(m,global_param_dict = gpd)
                            global results = vcat(results,row)
                            CSV.write(joinpath("Results","InvestmentModelResults","$(run_name).csv"),results)
                        end
                    end
                elseif type == "NTC"
                    @assert(type in ["TCPC","NTC"])
                    gpd["target_cap_for_curves"] = "NA"
                    gpd["stepsize"] = "NA"
                    for trans_cap_other in trans_caps_others
                        gpd["trans_cap_other"] = trans_cap_other
                        m = Model(optimizer_with_attributes(Gurobi.Optimizer))
                        row = full_build_and_optimize_investment_model(m,global_param_dict = gpd)
                        global results = vcat(results,row)
                        CSV.write(joinpath("Results","InvestmentModelResults","$(run_name).csv"),results)
                    end
                else
                    @assert(type == "TCPC")
                    gpd["target_cap_for_curves"] = "NA"
                    gpd["stepsize"] = "NA"
                    gpd["trans_cap_other"] = "NA"
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
t_total = time()-t_start
print(t_total)

#t_total
