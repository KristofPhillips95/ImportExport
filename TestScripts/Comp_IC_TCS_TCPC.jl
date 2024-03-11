include("../ImportExport/build_and_run.jl")
include("../ImportExport/build_and_save_cost_curves.jl")
using Gurobi
using Plots
gpd = Dict()

endtime = gpd["endtime"] = 72
gpd["Climate_year"] = 1984
gpd["Climate_year_ts"] = 2012
gpd["ValOfLostLoad"] = 8000
country = gpd["country"] = "BE00" 
gpd["scenario"] = "National Trends"
gpd["year"] = 2025
gpd["stepsize"] = 1
gpd["transport_price"] = 0.1
gpd["simplified"] = true
gpd["disc_rate"] = 0.07
gpd["geo_scope"] = ["BE00","DE00","NL00"]
# gpd["target_cap_for_curves"] = "endo_invest"


#Start the building process of 3 models 
m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m2 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m3 = Model(optimizer_with_attributes(Gurobi.Optimizer))

gpd["type"] = "NTC"
gpd["trans_cap_other"] = "S"
m1 = full_build_and_return_investment_model(m1,global_param_dict= gpd)

gpd["type"] = "TradeCurves_S"
gpd["target_cap_for_curves"] = "endo_invest"
build_and_save_cost_curves(gpd = gpd,save_soc=true,save_results=false)
m2 = full_build_and_return_investment_model(m2,global_param_dict= gpd)

gpd["type"] = "TradeCurves_PC"
m3 = full_build_and_return_investment_model(m3,global_param_dict= gpd)

optimize!(m1)
optimize!(m2)
optimize!(m3)

#Inspection
timesteps = collect(1:gpd["endtime"])

c_import = [sum(JuMP.value.(m1.ext[:variables][:import][gpd["country"],neighbor,t] for neighbor in m1.ext[:sets][:connections][gpd["country"]])) for t in timesteps]
c_export = [sum(JuMP.value.(m1.ext[:variables][:export][gpd["country"],neighbor,t] for neighbor in m1.ext[:sets][:connections][gpd["country"]])) for t in timesteps]
net_imports_ntc = c_import-c_export

trade_prices = m2.ext[:sets][:trade_prices]
imports_tc_S = [JuMP.value.(sum(m2.ext[:variables][:import]["BE00",p,t] for p in trade_prices)) for t in timesteps]
exports_tc_S = [JuMP.value.(sum(m2.ext[:variables][:export]["BE00",p,t] for p in trade_prices)) for t in timesteps]
net_imports_tc_S = imports_tc_S - exports_tc_S
Dict(p => [JuMP.value.(m2.ext[:variables][:export]["BE00",p,t]) for t in timesteps] for p in trade_prices)


trade_prices = m3.ext[:sets][:trade_prices]
imports_tc_PC = [JuMP.value.(sum(m3.ext[:variables][:import]["BE00",nb,p,t] for nb in m3.ext[:sets][:neighbors] for p in trade_prices[nb])) for t in timesteps]
exports_tc_PC = [JuMP.value.(sum(m3.ext[:variables][:export]["BE00",nb,p,t] for nb in m3.ext[:sets][:neighbors] for p in trade_prices[nb])) for t in timesteps]
net_imports_tc_PC = imports_tc_PC - exports_tc_PC


#Visualise net imports
plot(c_import -c_export, label = "Net import interconnected")
plot!(net_imports_tc_S, label = "Net import TC Single")
plot!(net_imports_tc_PC, label = "Net import TC Per country")
xlabel!("Time")
ylabel!("Net import (MW)")
plot!()
geo_scope_str = join(gpd["geo_scope"], "_")

plot!(m2.ext[:timeseries][:trade][:export][0.0],label = "Export available at price 0")
# plot!(m2.ext[:timeseries][:trade][:import][0.0],label = "Import available at price 0")


path = joinpath("Results","Figures","Comp_IC_TC","import_price_curves$(gpd["year"])_$(gpd["Climate_year_ts"])_$(gpd["scenario"])_$(gpd["endtime"])_s_$(gpd["simplified"])_tc_$(gpd["country"])_gs_$(geo_scope_str)_$(gpd["stepsize"]).png")
savefig(path)

#Explicit differences
plot(c_import,label="ntc import")
plot!(imports_tc_PC,label="TC_PC import")
plot!(imports_tc_S,label="TC_S import")

plot!(imports_tc_S-c_import,label="Diff import S")
plot!(imports_tc_TYNDP-c_import,label="Diff import PC")


plot(c_export,label="ntc export")
plot!(exports_tc_S,label="TC_S export")
scatter(exports_tc_PC,label="TC_PC export")

plot((exports_tc_S-c_export)[7:12],label="Diff export S")
plot!(exports_tc_PC-c_export,label="Diff export PC")


plot((net_imports_tc_PC-c_import  + c_export),label="Diff net PC")
plot!((net_imports_tc_S-c_import  + c_export),label="Diff net S")


##Extract productions per tech
productions_ntc = Dict(tech => [JuMP.value.(m1.ext[:variables][:production][country,tech,t]) for t in 1:endtime] for tech in m1.ext[:sets][:technologies][country] )
productions_tc_S = Dict(tech => [JuMP.value.(m2.ext[:variables][:production][country,tech,t]) for t in 1:endtime] for tech in m2.ext[:sets][:technologies][country] )
productions_tc_PC = Dict(tech => [JuMP.value.(m2.ext[:variables][:production][country,tech,t]) for t in 1:endtime] for tech in m2.ext[:sets][:technologies][country] )


productions_ntc_s = Dict(tech => sum(JuMP.value.(m1.ext[:variables][:production][country,tech,t]) for t in 1:endtime) for tech in m1.ext[:sets][:technologies][country] )
productions_S_s = Dict(tech => sum(JuMP.value.(m2.ext[:variables][:production][country,tech,t]) for t in 1:endtime) for tech in m2.ext[:sets][:technologies][country] )


#Prices

dual_diff =[(JuMP.dual(m1.ext[:constraints][:demand_met]["BE00",t]) - JuMP.dual(m3.ext[:constraints][:demand_met]["BE00",t])) for t in 1:endtime]
dual_NTC = [(JuMP.dual(m1.ext[:constraints][:demand_met]["BE00",t])) for t in 1:endtime]
JuMP.dual(m2.ext[:constraints][:demand_met]["BE00",53])

plot(dual_diff)
plot!(dual_NTC)

plot(dual_diff./dual_NTC)

#Capacities invested
capacities_ntc = Dict(tech => [JuMP.value.(m1.ext[:variables][:invested_cap][country,tech])] for tech in m1.ext[:sets][:investment_technologies][country] )
capacities_tc_S = Dict(tech => [JuMP.value.(m2.ext[:variables][:invested_cap][country,tech])] for tech in m2.ext[:sets][:investment_technologies][country] )
capacities_tc_PC = Dict(tech => [JuMP.value.(m3.ext[:variables][:invested_cap][country,tech])] for tech in m3.ext[:sets][:investment_technologies][country] )

capacities_S_Diff = Dict(tech => [JuMP.value.(m1.ext[:variables][:invested_cap][country,tech]) - JuMP.value.(m2.ext[:variables][:invested_cap][country,tech])] for tech in m1.ext[:sets][:investment_technologies][country] )
capacities_PC_Diff = Dict(tech => [JuMP.value.(m1.ext[:variables][:invested_cap][country,tech]) - JuMP.value.(m3.ext[:variables][:invested_cap][country,tech])] for tech in m1.ext[:sets][:investment_technologies][country] )


capacities_C_Dev = Dict(tech => [(JuMP.value.(m1.ext[:variables][:invested_cap][country,tech]) - JuMP.value.(m2.ext[:variables][:invested_cap][country,tech]))/JuMP.value.(m1.ext[:variables][:invested_cap][country,tech])] for tech in m1.ext[:sets][:investment_technologies][country] )
capacities_C_Dev = Dict(tech => [(JuMP.value.(m1.ext[:variables][:invested_cap][country,tech]) - JuMP.value.(m3.ext[:variables][:invested_cap][country,tech]))/JuMP.value.(m1.ext[:variables][:invested_cap][country,tech])] for tech in m1.ext[:sets][:investment_technologies][country] )


neighb = "DE00"
productions_ntc = Dict(tech => [JuMP.value.(m1.ext[:variables][:production][neighb,tech,t]) for t in 1:endtime] for tech in m1.ext[:sets][:technologies][neighb] )

get_zero_cost_prod(m1,"DE00",72)

include("../ImportExport/helper_inspection.jl")
ic_ntc = sum(values(get_investment_costs_c(m1,country)))
ic_tc = sum(values(get_investment_costs_c(m2,country)))

vc_ntc =sum(sum(values(get_VOM_costs_c(m2,country))))
vc_tc =sum(sum(values(get_VOM_costs_c(m1,country))))

fc_ntc =sum(sum(values(get_fuel_costs_c(m1,country))))
fc_tc =sum(sum(values(get_fuel_costs_c(m2,country))))

cc_ntc =sum(sum(values(get_CO2_costs_c(m1,country))))
cc_tc =sum(sum(values(get_CO2_costs_c(m2,country))))

ls_ntc =sum(sum(values(get_load_shedding_costs_c(m1,country))))
ls_tc =sum(sum(values(get_load_shedding_costs_c(m2,country))))

tc_ntc = ic_ntc + vc_ntc + fc_ntc +cc_ntc +ls_ntc
tc_tc = ic_tc + vc_tc + fc_tc +cc_tc +ls_tc

tc_ntc/tc_tc

m1.ext[:expressions]

# sum(investment_cost) + sum(VOM_cost) + sum(CO2_cost) + sum(fuel_cost) + sum(load_shedding_cost) + sum(transport_cost)

JuMP.value.([ m1.ext[:variables][:water_dumping]["DE00","ROR",t] for t in 1:endtime])
JuMP.value.([ m1.ext[:variables][:production]["DE00","ROR",t] for t in 1:endtime])
plot(JuMP.value.([ m1.ext[:variables][:production]["DE00","RES",t] + m1.ext[:variables][:water_dumping]["DE00","RES",t] for t in 1:endtime]))

# plot!(JuMP.value.([m1.ext[:variables][:water_dumping]["DE00","ROR",t] for t in 1:endtime]))
# plot!(JuMP.value.([m1.ext[:variables][:production]["DE00","ROR",t] for t in 1:endtime]))

#plot!(JuMP.value.([ m1.ext[:variables][:soc]["DE00","ROR",t] for t in 1:endtime]))

plot!([m1.ext[:timeseries][:hydro_inflow]["DE00"]["RES"][t] for t in 1:endtime])
m1.ext[:constraints][:soc_evolution_inflow]["DE00","ROR",72]

JuMP.value.([m1.ext[:variables][:soc]["DE00","ROR",t] for t in 1:endtime])