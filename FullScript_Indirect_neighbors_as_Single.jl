include("ImportExport/build_and_run.jl")
include("ImportExport/build_and_save_cost_curves.jl")
using Gurobi
# using Plots

#Initialise global parameters
gpd = Dict()

gpd["endtime"] = 24*365
gpd["Climate_year"] = 1984
gpd["Climate_year_ts"] = 2012
gpd["ValOfLostLoad"] = 8000
gpd["country"] = "BE00"
gpd["scenario"] = "National Trends"
gpd["year"] = 2025
gpd["transport_price"] = 0.1
gpd["disc_rate"] = 0.07


types = ["NTC"]
stepsizes = [100]
target_caps_for_curves = ["0"]
#target_caps_for_curves = ["endo_invest"]
geo_scopes = ["All"]
trans_caps_others = ["S",1e10,("S",1e10)]
# types = ["TradeCurves"]
#Start looping over desired global parameters: 
results = DataFrame()

run_name = "Loop_4models_indirect_neighbors_as_single_$(gpd["endtime"])"

# m = Model(optimizer_with_attributes(Gurobi.Optimizer))
# row = full_build_and_optimize_investment_model(m,global_param_dict = gpd)
t_start = time()
main(gpd,results,results_path,[false,true],types,geo_scopes,target_caps_for_curves,stepsizes,trans_caps_others)

t_total = time()-t_start
print(t_total)

#t_total