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


types = ["TCPC","isolated","NTC","TCS"]
stepsizes = [100]
target_caps_for_curves = ["endo_invest","TYNDP"]
target_caps_for_curves = ["endo_invest"]
geo_scopes = [["DE00","NL00","FR00","UK00","BE00"],"All"]
trans_caps_others = ["S",1e10]
# types = ["TradeCurves"]
#Start looping over desired global parameters: 
results = DataFrame()

run_name = "indirect_neighbors_$(gpd["endtime"])"

# m = Model(optimizer_with_attributes(Gurobi.Optimizer))
# row = full_build_and_optimize_investment_model(m,global_param_dict = gpd)
t_start = time()
main(gpd,results_path,[true],types,geo_scopes,target_caps_for_curves,stepsizes,trans_caps_others)

t_total = time()-t_start
print(t_total)

#t_total