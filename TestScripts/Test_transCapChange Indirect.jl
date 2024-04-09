include("../ImportExport/build_and_run.jl")
include("../ImportExport/build_and_save_cost_curves.jl")
using Gurobi
using Plots

gpd = Dict()

endtime = gpd["endtime"] = 72
CY = gpd["Climate_year"] = 1984
CY_ts= gpd["Climate_year_ts"] = 2012
VOLL = gpd["ValOfLostLoad"] = 8000
country = gpd["country"] = "BE00" 
scenario = gpd["scenario"] = "National Trends"
year = gpd["year"] = 2025
gpd["stepsize"] = 100
transp_price = gpd["transport_price"] = 0.1
simplified = gpd["simplified"] = true
disc_rate = gpd["disc_rate"] = 0.07
# gpd["target_cap_for_curves"] = "endo_invest"


#First, test with direct neighbors only
geo_scope = gpd["geo_scope"] = ["BE00","DE00","NL00","FR00","UK00","LUG"]
m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m2 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m3 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m4 = Model(optimizer_with_attributes(Gurobi.Optimizer))

gpd["type"] = "NTC"
gpd["trans_cap_other"] = 0
m1 = full_build_and_return_investment_model(m1,global_param_dict= gpd)
gpd["trans_cap_other"] = "S"
m2 = full_build_and_return_investment_model(m2,global_param_dict= gpd)
gpd["trans_cap_other"] = ("S",0)
m3 = full_build_and_return_investment_model(m3,global_param_dict= gpd)
gpd["type"] = "TCPC"
gpd["target_cap_for_curves"] = "NA"
m4 = full_build_and_return_investment_model(m4,global_param_dict= gpd)

optimize!(m1)
optimize!(m2)
optimize!(m3)
optimize!(m4)

m1.ext[:parameters][:connections]["BE00"]
m1.ext[:parameters][:connections]["DE00"]

m2.ext[:parameters][:connections]["BE00"]
m2.ext[:parameters][:connections]["DE00"]

m3.ext[:parameters][:connections]["BE00"]
m3.ext[:parameters][:connections]["DE00"]

#Inspection


#Next, include indirect neighbors
geo_scope = gpd["geo_scope"] = "All"
m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m2 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m3 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m4 = Model(optimizer_with_attributes(Gurobi.Optimizer))

gpd["type"] = "NTC"
gpd["trans_cap_other"] = 1e10
m1 = full_build_and_return_investment_model(m1,global_param_dict= gpd)
gpd["trans_cap_other"] = "S"
m2 = full_build_and_return_investment_model(m2,global_param_dict= gpd)
gpd["trans_cap_other"] = ("S",1e10)
m3 = full_build_and_return_investment_model(m3,global_param_dict= gpd)
gpd["type"] = "TCPC"
gpd["target_cap_for_curves"] = "NA"
m4 = full_build_and_return_investment_model(m4,global_param_dict= gpd)

optimize!(m1)
optimize!(m2)
optimize!(m3)
optimize!(m4)

JuMP.value(m1.ext[:objective])
JuMP.value(m2.ext[:objective])
JuMP.value(m3.ext[:objective])

m1.ext[:parameters][:connections]["BE00"]
m1.ext[:parameters][:connections]["DE00"]
m1.ext[:parameters][:connections]["CH00"]

m2.ext[:parameters][:connections]["BE00"]
m2.ext[:parameters][:connections]["DE00"]

m3.ext[:parameters][:connections]["BE00"]
m3.ext[:parameters][:connections]["DE00"]
m3.ext[:parameters][:connections]["CH00"]

m2.ext[:parameters][:connections]["NOS0"]

#Inspection
