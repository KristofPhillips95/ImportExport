include("ImportExport/model_builder.jl")
include("ImportExport/curve_based_model_builder.jl")
include("ImportExport/cost_curves_builder.jl")
include("ImportExport/build_and_save_cost_curves.jl")
include("ImportExport/build_and_run.jl")
include("ImportExport/helper_inspection.jl")


gpd = Dict()
timer_dict = Dict()

endtime = gpd["endtime"] = 15
CY = gpd["Climate_year"] = 1984
CY_ts = gpd["Climate_year_ts"] = 2012
VOLL = gpd["ValOfLostLoad"] = 8000
country = gpd["country"] = "BE00" 
scenario = gpd["scenario"] = "National Trends"
year = gpd["year"] = 2025
gpd["stepsize"] = 10
transport_price = gpd["transport_price"] = 0.1
simplified = gpd["simplified"] = true
disc_rate = gpd["disc_rate"] = 0.07
single_neighbor = "LUG1"
gpd["geo_scope"] = ["BE00",single_neighbor]
gpd["trans_cap_other"] = "S"
gpd["target_cap_for_curves"] = "endo_invest"


###########################
# Test with single neighbor
###########################

m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))
gpd["type"] = "NTC"
m1 = full_build_and_return_investment_model(m1,global_param_dict= gpd,timer_dict = timer_dict)
optimize!(m1)

m2 = Model(optimizer_with_attributes(Gurobi.Optimizer))
gpd["type"] = "TCPC"
m2 = full_build_and_return_investment_model(m2,global_param_dict= gpd,timer_dict = timer_dict)
optimize!(m2)

m3 = Model(optimizer_with_attributes(Gurobi.Optimizer))
gpd["type"] = "TCS"
m3 = full_build_and_return_investment_model(m3,global_param_dict= gpd,timer_dict = timer_dict)
optimize!(m3)

sum(get_congestion_rents(m1,"BE00","NTC")[1][single_neighbor])
sum(get_congestion_rents(m1,"BE00","NTC")[2][single_neighbor])

sum(get_congestion_rents(m2,"BE00","TCPC")[1][single_neighbor])
sum(get_congestion_rents(m2,"BE00","TCPC")[2][single_neighbor])

sum(get_congestion_rents(m3,"BE00","TCS")[1][single_neighbor])
sum(get_congestion_rents(m3,"BE00","TCS")[2][single_neighbor])

sum(get_import_cost_and_export_revenue(m1,"BE00","NTC")[1][single_neighbor])
sum(get_import_cost_and_export_revenue(m1,"BE00","NTC")[2][single_neighbor])

sum(get_import_cost_and_export_revenue(m2,"BE00","TCPC")[1][single_neighbor])
sum(get_import_cost_and_export_revenue(m2,"BE00","TCPC")[2][single_neighbor])

sum(get_import_cost_and_export_revenue(m3,"BE00","TCS")[1][single_neighbor])
sum(get_import_cost_and_export_revenue(m3,"BE00","TCS")[2][single_neighbor])

get_total_trade_costs_and_rents(m1,"BE00","NTC")
get_total_trade_costs_and_rents(m2,"BE00","TCPC")
get_total_trade_costs_and_rents(m3,"BE00","TCS")

get_congestion_rents(m2,"BE00","TCPC")[2][single_neighbor]
get_congestion_rents(m1,"BE00","NTC")[2][single_neighbor]

get_neighbor_price(m2,"BE00","TCPC",nothing)
get_neighbor_price(m1,"BE00","NTC",nothing)

m1.ext[:parameters][:technologies][:capacities]["LUG1"]
m1.ext[:timeseries][:demand]["LUG1"]
get_production(m1,"LUG1",endtime)

m2.ext[:timeseries][:trade][:export]

get_pc_pp_import_and_export(m2,country,"TCPC")[2]
get_pc_import_and_export(m1,country,"NTC")[2]
get_pc_import_and_export(m2,country,"TCPC")[2]

#####################
# Test direct neighbors
#####################

gpd["geo_scope"] = ["DE00","NL00","FR00","UK00","BE00","LUG1"]

m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))
gpd["type"] = "NTC"
m1 = full_build_and_return_investment_model(m1,global_param_dict= gpd,timer_dict = timer_dict)
optimize!(m1)

m2 = Model(optimizer_with_attributes(Gurobi.Optimizer))
gpd["type"] = "TCPC"
m2 = full_build_and_return_investment_model(m2,global_param_dict= gpd,timer_dict = timer_dict)
optimize!(m2)

m3 = Model(optimizer_with_attributes(Gurobi.Optimizer))
gpd["type"] = "TCS"
m3 = full_build_and_return_investment_model(m3,global_param_dict= gpd,timer_dict = timer_dict)
optimize!(m3)

m4 = Model(optimizer_with_attributes(Gurobi.Optimizer))
gpd["type"] = "NTC"
gpd["trans_cap_other"] = 0 
m4 = full_build_and_return_investment_model(m4,global_param_dict= gpd,timer_dict = timer_dict)
optimize!(m4)
gpd["trans_cap_other"] = "S" 

get_total_trade_costs_and_rents(m1,"BE00","NTC")
get_total_trade_costs_and_rents(m2,"BE00","TCPC")
get_total_trade_costs_and_rents(m3,"BE00","TCS")
gpd["trans_cap_other"] = 0
get_total_trade_costs_and_rents(m4,"BE00","NTC")

get_congestion_rents(m2,"BE00","TCPC")[2]["LUG1"]
get_congestion_rents(m4,"BE00","NTC")[2]["LUG1"]

m2.ext[:timeseries][:trade][:export]["LUG1"]

JuMP.value.(m2.ext[:variables][:invested_cap])
JuMP.value.(m4.ext[:variables][:invested_cap])

m4.ext[:parameters][:connections]

JuMP.value.(m4.ext[:variables][:import]["LUG1",nb,t] for nb in m4.ext[:sets][:connections]["LUG1"] for t in 1:endtime)
m4.ext[:timeseries][:demand]
JuMP.value.(m4.ext[:variables][:import])