include("../ImportExport/build_and_save_cost_curves.jl")
include("../ImportExport/curve_based_model_builder.jl")
using Gurobi
using CSV
using Plots

# Start comparing the models in the old way
#First, define the global params
endtime = 72
CY = 1984
CY_ts = 2012
VOLL = 8000
country = "BE00"
transport_cost = 0.1
disc_rate = 0.07
simplified = false
target_cap_for_curves ="endo_invest"

sc_ty_tuples = [("National Trends",2025), ("National Trends",2030),("National Trends",2040),("Distributed Energy",2030),("Distributed Energy",2040)]
sc_ty_tuple = sc_ty_tuples[1]
scenario = sc_ty_tuple[1]
year = sc_ty_tuple[2]

gpd = Dict()
endtime = gpd["endtime"] = 24*3
gpd["Climate_year"] = 1984
gpd["Climate_year_ts"] = 2012
gpd["ValOfLostLoad"] = 8000
country = gpd["country"] = "BE00" 
gpd["scenario"] = "National Trends"
gpd["year"] = 2025
stepsize = gpd["stepsize"] = 100
gpd["transport_price"] = 0.1
gpd["simplified"] = false
gpd["target_cap_for_curves"] = "endo_invest"
gpd["disc_rate"] = 0.07
geo_scope = gpd["geo_scope"] = ["BE00","FR00"]

#We are dealing here first with a simplified model, so no need to fix storage schedules.
soc = production = nothing

#However, we do need to build the import-export curves with the reduced geographical scope.
m = build_model_for_import_curve(0,soc,production,gpd)
trade_levels = get_trade_levels(m = m, country = country,stepsize = stepsize)
trade_curve_dict = Dict()

for trade_level in trade_levels
    change_import_level!(m,endtime,trade_level,country)
    optimize!(m)
    check_production_zero!(m,country,endtime)
    check_net_import(m,country,trade_level,endtime,simplified)
    import_prices = [JuMP.dual.(m.ext[:constraints][:demand_met][country,t]) for t in 1:endtime]
    trade_curve_dict[trade_level] = import_prices
end
write_prices(trade_curve_dict,trade_levels,gpd)


#Start the building process of 2 models 
m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m2 = Model(optimizer_with_attributes(Gurobi.Optimizer))

# m1 will be the interconnected model, m2 is the one with trade curves

#Define sets
all_countries = get_all_countries(scenario,year,CY)
included_countries = ["BE00","DE00"]
filter((e->!(e in included_countries)),all_countries)

define_sets!(m1,scenario,year,CY,filter((e->!(e in included_countries)),all_countries),[country],simplified)
define_sets!(m2,scenario,year,CY,filter((e->e != "BE00"),all_countries),["BE00"],simplified)

#Parameters
process_parameters!(m1,scenario,year,CY,[country],simplified)
process_parameters!(m2,scenario,year,CY,[country],simplified)

#Time series
process_time_series!(m1,scenario,year,CY_ts,simplified,endtime)
process_time_series!(m2,scenario,year,CY_ts,simplified,endtime)

#remove cap from inv country
remove_capacity_country!(m1,country)
remove_capacity_country!(m2,country)

#Build models
build_NTC_investment_model!(m1,endtime,VOLL,transport_cost,disc_rate,simplified)

curves = read_prices(scenario,year,CY_ts,endtime,simplified,country,target_cap_for_curves,geo_scope,stepsize)
add_availability_curves_to_model!(m2,curves)
build_single_trade_curve_investment_model!(m2,endtime,VOLL,0,disc_rate,simplified)


prices_sorted = sort(unique(Matrix(curves)))
trade_levels = parse.(Float64,names(curves))
trade_level_step = trade_levels[1] - trade_levels[2]

#Then, for each price, find the availability 
counts_per_row = Dict()
import_available = Dict()
export_available = Dict()


n_cols = size(curves, 2)  # Get the total number of columns
midpoint = div(n_cols, 2)  # Calculate the midpoint
imp_exp_bound_i = findall(x -> x ==0,parse.(Float64,names(curves)))[1]
export_columns = curves[:, imp_exp_bound_i+1:end]
import_columns = curves[:, 1:imp_exp_bound_i-1]
names(import_columns)
names(export_columns)


optimize!(m1)
optimize!(m2)

#Inspection
timesteps = collect(1:gpd["endtime"])

c_import = [sum(JuMP.value.(m1.ext[:variables][:import][gpd["country"],neighbor,t] for neighbor in m1.ext[:sets][:connections][gpd["country"]])) for t in timesteps]
c_export = [sum(JuMP.value.(m1.ext[:variables][:export][gpd["country"],neighbor,t] for neighbor in m1.ext[:sets][:connections][gpd["country"]])) for t in timesteps]

trade_prices = m2.ext[:sets][:trade_prices]
imports = [JuMP.value.(sum(m2.ext[:variables][:import]["BE00",p,t] for p in trade_prices)) for t in timesteps]
exports = [JuMP.value.(sum(m2.ext[:variables][:export]["BE00",p,t] for p in trade_prices)) for t in timesteps]
net_imports_tc_TYNDP = imports - exports


# trade_prices = m3.ext[:sets][:trade_prices]
# imports = [JuMP.value.(sum(m3.ext[:variables][:import]["BE00",p,t] for p in trade_prices)) for t in timesteps]
# exports = [JuMP.value.(sum(m3.ext[:variables][:export]["BE00",p,t] for p in trade_prices)) for t in timesteps]
# net_imports_tc_endo = imports - exports


# net_imports_tc_TYNDP == net_imports_tc_endo

#Visualise total imports and exports
# plot(imports,label = "Imports TC")
# plot!(-exports, label = "Exports TC")
plot(net_imports_tc_TYNDP, label = "Net import TC TYNDP")
# plot!(net_imports_tc_endo, label = "Net import TC endo")
plot!(c_import -c_export, label = "Net import interconnected")



m2.ext[:expressions][:trade_cost]


#With the newer methods 

include("../ImportExport/build_and_run.jl")
include("../ImportExport/build_and_save_cost_curves.jl")
using Plots
gpd = Dict()

endtime = gpd["endtime"] = 24*3
gpd["Climate_year"] = 1984
gpd["Climate_year_ts"] = 2012
gpd["ValOfLostLoad"] = 8000
country = gpd["country"] = "BE00" 
gpd["scenario"] = "National Trends"
gpd["year"] = 2025
gpd["stepsize"] = 100
gpd["transport_price"] = 0.1
gpd["simplified"] = true
gpd["disc_rate"] = 0.07
gpd["geo_scope"] =["BE00","UK","DE00"]
# gpd["target_cap_for_curves"] = "endo_invest"


#Start the building process of 3 models 
m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m2 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m3 = Model(optimizer_with_attributes(Gurobi.Optimizer))

gpd["type"] = "NTC"
m1 = full_build_and_return_investment_model(m1,global_param_dict= gpd)

gpd["type"] = "TradeCurves"
gpd["target_cap_for_curves"] = "TYNDP"
build_and_save_cost_curves(gpd = gpd,save_soc=true,save_results=false)
m2 = full_build_and_return_investment_model(m2,global_param_dict= gpd)

gpd["type"] = "TradeCurves"
gpd["target_cap_for_curves"] = "endo_invest"
build_and_save_cost_curves(gpd = gpd,save_soc=true,save_results=true)
m3 = full_build_and_return_investment_model(m3,global_param_dict= gpd)

optimize!(m1)
optimize!(m2)
optimize!(m3)

#Inspection
timesteps = collect(1:gpd["endtime"])

c_import = [sum(JuMP.value.(m1.ext[:variables][:import][gpd["country"],neighbor,t] for neighbor in m1.ext[:sets][:connections][gpd["country"]])) for t in timesteps]
c_export = [sum(JuMP.value.(m1.ext[:variables][:export][gpd["country"],neighbor,t] for neighbor in m1.ext[:sets][:connections][gpd["country"]])) for t in timesteps]

trade_prices = m2.ext[:sets][:trade_prices]
imports_tc_TYNDP = [JuMP.value.(sum(m2.ext[:variables][:import]["BE00",p,t] for p in trade_prices)) for t in timesteps]
exports_tc_TYNDP = [JuMP.value.(sum(m2.ext[:variables][:export]["BE00",p,t] for p in trade_prices)) for t in timesteps]
net_imports_tc_TYNDP = imports_tc_TYNDP - exports_tc_TYNDP


trade_prices = m3.ext[:sets][:trade_prices]
imports_tc_endo = [JuMP.value.(sum(m3.ext[:variables][:import]["BE00",p,t] for p in trade_prices)) for t in timesteps]
exports_tc_endo = [JuMP.value.(sum(m3.ext[:variables][:export]["BE00",p,t] for p in trade_prices)) for t in timesteps]
net_imports_tc_endo = imports_tc_endo - exports_tc_endo


net_imports_tc_TYNDP == net_imports_tc_endo

#Visualise net imports
plot(c_import -c_export, label = "Net import interconnected")
plot!(net_imports_tc_TYNDP, label = "Net import TC TYNDP")
plot!(net_imports_tc_endo, label = "Net import TC endo")
xlabel!("Time")
ylabel!("Net import (MW)")
plot!()
geo_scope_str = join(gpd["geo_scope"], "_")

path = joinpath("Results","Figures","Comp_IC_TC","import_price_curves$(gpd["year"])_$(gpd["Climate_year_ts"])_$(gpd["scenario"])_$(gpd["endtime"])_s_$(gpd["simplified"])_tc_$(gpd["country"])_gs_$(geo_scope_str)_$(gpd["stepsize"]).png")
savefig(path)

#Explicit differences
plot(imports_tc_endo,label="TC_endo import")
plot!(imports_tc_TYNDP,label="TC_TYNDP import")
plot!(c_import,label="ntc import")
plot!(imports_tc_endo-c_import,label="Diff import endo")
plot!(imports_tc_TYNDP-c_import,label="Diff import TYNDP")



plot(exports_tc_endo,label="TC_endo export")
plot!(exports_tc_TYNDP,label="TC_TYNDP export")
plot!(c_export,label="ntc export")
plot!(exports_tc_endo-c_export,label="Diff export")


plot((net_imports_tc_endo-c_import  + c_export),label="Diff net")

##Extract productions per tech
productions_ntc = Dict(tech => [JuMP.value.(m1.ext[:variables][:production][country,tech,t]) for t in 1:endtime] for tech in m1.ext[:sets][:technologies][country] )
productions_tc = Dict(tech => [JuMP.value.(m2.ext[:variables][:production][country,tech,t]) for t in 1:endtime] for tech in m2.ext[:sets][:technologies][country] )

productions_ntc_s = Dict(tech => sum(JuMP.value.(m1.ext[:variables][:production][country,tech,t]) for t in 1:endtime) for tech in m1.ext[:sets][:technologies][country] )


#Prices

dual_diff =[(JuMP.dual(m1.ext[:constraints][:demand_met]["BE00",t]) - JuMP.dual(m3.ext[:constraints][:demand_met]["BE00",t])) for t in 1:endtime]
dual_NTC = [(JuMP.dual(m1.ext[:constraints][:demand_met]["BE00",t])) for t in 1:endtime]
JuMP.dual(m2.ext[:constraints][:demand_met]["BE00",53])

plot(dual_diff)
plot!(dual_NTC)

plot(dual_diff./dual_NTC)

#Capacities invested
capacities_ntc = Dict(tech => [JuMP.value.(m1.ext[:variables][:invested_cap][country,tech])] for tech in m1.ext[:sets][:investment_technologies][country] )
capacities_tc = Dict(tech => [JuMP.value.(m2.ext[:variables][:invested_cap][country,tech])] for tech in m2.ext[:sets][:investment_technologies][country] )
capacities_tc = Dict(tech => [JuMP.value.(m3.ext[:variables][:invested_cap][country,tech])] for tech in m3.ext[:sets][:investment_technologies][country] )


neighb = "DE00"
productions_ntc = Dict(tech => [JuMP.value.(m1.ext[:variables][:production][neighb,tech,t]) for t in 1:endtime] for tech in m1.ext[:sets][:technologies][neighb] )
get_zero_cost_prod(m1,"DE00",72)

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