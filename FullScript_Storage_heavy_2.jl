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

#Loop parameters
types = ["NTC","TCS"]
stepsizes = [100]
target_caps_for_curves = ["no_fix"]
trans_caps_others = ["S"]
#geo_scopes = [["BE00", "DE00","LUG1","FR00","UK00","NL00"]]
geo_scopes = ["All"]

#Start looping over desired global parameters: 
#run_name = "storage_heavy_red_geo_fsoc_$(gpd["country"])_$(gpd["endtime"])_reformed_2"
run_name = "storage_heavy_fsoc_$(gpd["country"])_$(gpd["endtime"])_reformed_2"
results_path = joinpath("Results","InvestmentModelResults_2","$(run_name).csv")
# m = Model(optimizer_with_attributes(Gurobi.Optimizer))
# row = full_build_and_optimize_investment_model(m,global_param_dict = gpd)

results = DataFrame()
t_start = time()
main(gpd,results,results_path,[false],types,geo_scopes,target_caps_for_curves,stepsizes,trans_caps_others)
t_total = time()-t_start
print(t_total)

#t_total
