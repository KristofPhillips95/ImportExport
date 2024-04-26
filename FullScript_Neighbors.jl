include("Main.jl")
using Gurobi

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
geo_scopes = [["DE00","NL00","FR00","UK00","BE00","LUG1"]]
trans_caps_others = ["S",0,1e10]
simplifieds = [true]

run_name = "neighbors_only_$(gpd["endtime"])"
results_path = joinpath("Results","InvestmentModelResults_2","$(run_name).csv")

#Start looping over desired global parameters: 
results = DataFrame()

t_start = time()
main(gpd,results,results_path,simplifieds,types,geo_scopes,target_caps_for_curves,stepsizes,trans_caps_others)

t_total = time()-t_start
print(t_total)

