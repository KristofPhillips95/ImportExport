include("Main.jl")
using Gurobi

#Initialise global parameters
gpd = Dict()

gpd["endtime"] = 24*365
gpd["Climate_year"] = 1984
gpd["Climate_year_ts"] = 2012
gpd["ValOfLostLoad"] = 8000
gpd["country"] = "SE03"
gpd["scenario"] = "National Trends"
gpd["year"] = 2025
gpd["transport_price"] = 0.1
gpd["disc_rate"] = 0.07




types = ["NTC","TCS"]
stepsizes = [100]
target_caps_for_curves = ["TYNDP","endo_invest","0","no_fix"]
geo_scopes = [["FI00", "SE02","DKW1","SE04","NOS0","SE03"]]
trans_caps_others = ["S"]

simplifieds = [true,false]
run_name = "storage_heavy_red_geo_fsoc_$(gpd["country"])_$(gpd["endtime"])"
results_path = joinpath("Results","InvestmentModelResults_2","$(run_name).csv")


#Start looping over desired global parameters: 
results = DataFrame()


# m = Model(optimizer_with_attributes(Gurobi.Optimizer))
# row = full_build_and_optimize_investment_model(m,global_param_dict = gpd)
t_start = time()
main(gpd,results,results_path,simplifieds,types,geo_scopes,target_caps_for_curves,stepsizes,trans_caps_others)

t_total = time()-t_start
print(t_total)

#t_total
