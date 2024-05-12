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




types = ["NTC"]
stepsizes = [100]
target_caps_for_curves = []
geo_scopes = [["BE00","NL00"],["BE00","DE00"],["BE00","FR00"],["BE00","UK00"],["DE00","NL00","FR00","UK00","BE00","LUG1","ES00"],["DE00","NL00","FR00","UK00","BE00","LUG1","CH00"],["DE00","NL00","FR00","UK00","BE00","LUG1","ITN1"],["DE00","NL00","FR00","UK00","BE00","LUG1","DKW1"],["DE00","NL00","FR00","UK00","BE00","LUG1","NOS0"]]
trans_caps_others = ["S"]

simplifieds = [true,false]
run_name = "comp_times_$(gpd["country"])_$(gpd["endtime"])"
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
