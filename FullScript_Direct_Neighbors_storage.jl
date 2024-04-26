include("ImportExport/build_and_run.jl")
include("ImportExport/build_and_save_cost_curves.jl")
using Gurobi
# using Plots

#Initialise global parameters
gpd = Dict()

gpd["endtime"] = 24*1
gpd["Climate_year"] = 1984
gpd["Climate_year_ts"] = 2012
gpd["ValOfLostLoad"] = 8000
gpd["country"] = "BE00"
gpd["scenario"] = "National Trends"
gpd["year"] = 2025
gpd["transport_price"] = 0.1
gpd["disc_rate"] = 0.07


types = ["NTC","TCS"]
stepsizes = [1000,100,10]
target_caps_for_curves = ["endo_invest","TYNDP"]
#target_caps_for_curves = ["endo_invest"]
geo_scopes = [["DE00","NL00","FR00","UK00","BE00"]]
trans_caps_others = ["S",1e10]
# types = ["TradeCurves"]
#Start looping over desired global parameters: 
results = DataFrame()

run_name = "Direct_neighbors_storage_$(gpd["country"])_$(gpd["endtime"])"
results_path = joinpath("Results","InvestmentModelResults_2","$(run_name).csv")

t_start = time()
main(gpd,results,results_path,[false],types,geo_scopes,target_caps_for_curves,stepsizes,trans_caps_others)
t_total = time()-t_start
print(t_total)

#t_total