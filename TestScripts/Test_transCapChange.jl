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
gpd["stepsize"] = 10
transp_price = gpd["transport_price"] = 0.1
simplified = gpd["simplified"] = true
disc_rate = gpd["disc_rate"] = 0.07
gpd["target_cap_for_curves"] = "endo_invest"
geo_scope = gpd["geo_scope"] = ["BE00","DE00","NL00","FR00","UK00","LUG"]


m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))
c_excluded = get_list_of_excluded(geo_scope,scenario,year,CY)
define_sets!(m1,scenario,year,CY,c_excluded,[country],simplified)
process_parameters!(m1,scenario,year,CY,[country],simplified)
process_time_series!(m1,scenario,year,CY_ts,simplified,endtime)
remove_capacity_country!(m1,country)
update_transfer_caps_of_non_focus(m1,0,country,)
build_NTC_investment_model!(m1,endtime,VOLL,transp_price,disc_rate,simplified)


gpd["type"] = "TradeCurves_PC"
m3 = full_build_and_return_investment_model(m3,global_param_dict= gpd)

m1.ext[:parameters][:connections]

optimize!(m1)
optimize!(m3)


#Inspection
timesteps = collect(1:gpd["endtime"])

c_import = [sum(JuMP.value.(m1.ext[:variables][:import][gpd["country"],neighbor,t] for neighbor in m1.ext[:sets][:connections][gpd["country"]])) for t in timesteps]
c_export = [sum(JuMP.value.(m1.ext[:variables][:export][gpd["country"],neighbor,t] for neighbor in m1.ext[:sets][:connections][gpd["country"]])) for t in timesteps]
net_imports_ntc = c_import-c_export

# trade_prices = m2.ext[:sets][:trade_prices]
# imports_tc_S = [JuMP.value.(sum(m2.ext[:variables][:import]["BE00",p,t] for p in trade_prices)) for t in timesteps]
# exports_tc_S = [JuMP.value.(sum(m2.ext[:variables][:export]["BE00",p,t] for p in trade_prices)) for t in timesteps]
# net_imports_tc_S = imports_tc_S - exports_tc_S
# Dict(p => [JuMP.value.(m2.ext[:variables][:export]["BE00",p,t]) for t in timesteps] for p in trade_prices)


trade_prices = m3.ext[:sets][:trade_prices]
imports_tc_PC = [JuMP.value.(sum(m3.ext[:variables][:import]["BE00",nb,p,t] for nb in m3.ext[:sets][:neighbors] for p in trade_prices[nb])) for t in timesteps]
exports_tc_PC = [JuMP.value.(sum(m3.ext[:variables][:export]["BE00",nb,p,t] for nb in m3.ext[:sets][:neighbors] for p in trade_prices[nb])) for t in timesteps]
net_imports_tc_PC = imports_tc_PC - exports_tc_PC


#Visualise net imports
plot(c_import -c_export, label = "Net import interconnected")
# plot!(net_imports_tc_S, label = "Net import TC Single")
plot!(net_imports_tc_PC, label = "Net import TC Per country")
xlabel!("Time")
ylabel!("Net import (MW)")
plot!()