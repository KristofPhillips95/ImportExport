include("Main.jl")
# using Plots

#Initialise global parameters
gpd = Dict()

gpd["endtime"] = 24*1
gpd["Climate_year"] = 1984
gpd["Climate_year_ts"] = 2012
gpd["ValOfLostLoad"] = 8000
gpd["country"] = "SE03"
gpd["scenario"] = "National Trends"
gpd["year"] = 2025
gpd["transport_price"] = 0.1
gpd["disc_rate"] = 0.07

#Loop parameters
types = ["NTC","TCS"]
stepsizes = [100]
target_caps_for_curves = ["TYNDP","endo_invest"]
geo_scopes = [["FI00", "SE02","DKW1","SE04","NOS0","SE03"]]
trans_caps_others = ["S"]

#Start looping over desired global parameters: 
run_name = "storage_heavy_red_geo_fsoc__$(gpd["country"])_$(gpd["endtime"])"
results_path = joinpath("Results","InvestmentModelResults_2","$(run_name).csv")
# m = Model(optimizer_with_attributes(Gurobi.Optimizer))
# row = full_build_and_optimize_investment_model(m,global_param_dict = gpd)


t_start = time()
main(gpd,results_path,[false],types,geo_scopes,target_caps_for_curves,stepsizes,trans_caps_others)
t_total = time()-t_start
print(t_total)

#t_total
