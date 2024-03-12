include("ImportExport/model_builder.jl")
include("ImportExport/curve_based_model_builder.jl")
include("ImportExport/cost_curves_builder.jl")
include("ImportExport/build_and_save_cost_curves.jl")
include("ImportExport/build_and_run.jl")
include("ImportExport/helper_inspection.jl")

using Plots
####################
## Compare results #
####################

gpd = Dict()

endtime = gpd["endtime"] = 72
CY = gpd["Climate_year"] = 1984
CY_ts = gpd["Climate_year_ts"] = 2012
VOLL = gpd["ValOfLostLoad"] = 8000
country = gpd["country"] = "BE00" 
scenario = gpd["scenario"] = "National Trends"
year = gpd["year"] = 2025
gpd["stepsize"] = 100
transport_price = gpd["transport_price"] = 0.1
simplified = gpd["simplified"] = true
disc_rate = gpd["disc_rate"] = 0.07
gpd["geo_scope"] = ["BE00","DE00","FR00"]

# function get_trade_availabilities_from_supply_curves(m,c,supply_curves,supply_curves_incr,supply_curves_incr_minus_demand)
#     import_availability = Dict()
#     export_availability = Dict()
#     demand = m.ext[:timeseries][:demand][c]
#     diff_dem = [demand[t] for t in 1:endtime]

#     for production_price in sort!(collect(keys(supply_curves)))
#         println(production_price)
#         import_availability[production_price] = zeros(endtime)
#         export_availability[production_price] = zeros(endtime)
#         for t in 1:endtime
#             if supply_curves_incr_minus_demand[production_price][t] <=0
#                 ##As long as this is the case, the neighboring country does noet have enough capacity at this price to meet demand and will not be able to export
#                 import_availability[production_price][t] = 0
#                 #At the same time, the country will be willing to pay the same price as at home for this energy
#                 export_availability[production_price][t] = supply_curves[production_price][t]

#                 #We set the diff_dem parameter to the difference between the total production up to this price, and the demand
#                 diff_dem[t] = demand[t] - supply_curves_incr[production_price][t]

#             elseif supply_curves_incr_minus_demand[production_price][t] >=0
#                 ## In this case, the neighobring country has an excess at this price and is willing to export
#                 export_availability[production_price][t] = diff_dem[t]

#                 import_availability[production_price][t] = supply_curves[production_price][t] - diff_dem[t]
#                 diff_dem[t] = 0 
#             end
           
#         end
#     end

#     return import_availability,export_availability
# end
# function get_per_country_trade_availability(m,simplified)
#     import_availabilities = Dict()
#     export_availabilities = Dict()

#     for neighbor in m.ext[:sets][:connections][country] 
#         zero_cost_prod,nb_tech_zero_prod = get_zero_cost_prod(m,neighbor,endtime)
#         static_non_zero_cost_cap,nb_tech_static = get_static_nonzero_cost_cap(m,neighbor)
#         supply_curves,supply_curves_incr, supply_curves_incr_minus_demand = get_supply_curves(m,neighbor,zero_cost_prod,static_non_zero_cost_cap)
#         import_availabilities[neighbor],export_availabilities[neighbor] = get_trade_availabilities_from_supply_curves(m,neighbor,supply_curves,supply_curves_incr,supply_curves_incr_minus_demand)
#     if !simplified
#         nb_pure_storage = length(m.ext[:sets][:pure_storage_technologies][neighbor])
#         @assert(nb_pure_storage + nb_tech_static + nb_tech_zero_prod == length(m.ext[:sets][:technologies][neighbor]))
#     else
#         @assert(nb_tech_static + nb_tech_zero_prod == length(m.ext[:sets][:technologies][neighbor]))
#     end

#     end
#     return import_availabilities,export_availabilities
# end

m = initialize_and_build_model_to_obtain_curves_per_country(endtime,gpd["country"],gpd["scenario"],gpd["year"],gpd["Climate_year"],gpd["Climate_year_ts"],gpd["simplified"],gpd["geo_scope"])


import_availabilities,export_availabilities = get_per_country_trade_availability(m,gpd["simplified"],country,endtime,VOLL)
import_lims,export_lims = get_per_country_trade_limits(m,country)
# m.ext[:timeseries][:demand]

# plot(import_availabilities["NL00"][collect(keys(import_availabilities["NL00"]))[5]])

# p = collect(keys(import_availabilities["NL00"]))[5]
# plot!(supply_curves_incr_minus_demand[p],label = p)
# collect(keys(import_availabilities["NL00"]))[5]

neighbor = "FR00"
zero_cost_prod,nb_tech_zero_prod = get_zero_cost_prod(m,neighbor,endtime)
static_non_zero_cost_cap,nb_tech_static = get_static_nonzero_cost_cap(m,neighbor,VOLL)
supply_curves,supply_curves_incr, supply_curves_incr_minus_demand = get_supply_curves(m,neighbor,zero_cost_prod,static_non_zero_cost_cap,endtime)
# import_availabilities[neighbor],export_availabilities[neighbor] = get_trade_availabilities_from_supply_curves(m,neighbor,supply_curves,supply_curves_incr,supply_curves_incr_minus_demand)

# import_availabilities[neighbor]
# Dict(p => [export_availabilities[neighbor][p][t] for t in 391:400] for p in keys(export_availabilities[neighbor]))
# supply_curves_incr_minus_demand
# supply_curves_incr
# supply_curves'
# Dict(p => [import_availabilities[neighbor][p][t] for t in 391:400] for p in keys(export_availabilities[neighbor]))


m = Model(optimizer_with_attributes(Gurobi.Optimizer))
all_countries = get_all_countries(scenario,year,CY)
define_sets!(m,scenario,year,CY,filter((e->e != "BE00"),all_countries),["BE00"],simplified)
process_parameters!(m,scenario,year,CY,[country],simplified)
process_time_series!(m,scenario,year,CY_ts,simplified,endtime)
remove_capacity_country!(m,country)
add_per_country_availability_curves_to_model!(m,import_availabilities,export_availabilities,import_lims,export_lims)
build_per_country_trade_curve_investment_model!(m,endtime,VOLL,transport_price,disc_rate,simplified)
m.ext[:timeseries][:trade][:import]
optimize!(m)

m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))
gpd["type"] = "NTC"
m1 = full_build_and_return_investment_model(m1,global_param_dict= gpd)
optimize!(m1)

m1.ext[:sets][:connections]["BE00"]

m2 = Model(optimizer_with_attributes(Gurobi.Optimizer))
gpd["type"] = "TradeCurves_S"
gpd["target_cap_for_curves"] = "endo_invest"
build_and_save_cost_curves(gpd = gpd,save_soc=true,save_results=true)
m2 = full_build_and_return_investment_model(m2,global_param_dict= gpd)
optimize!(m2)

m3 = Model(optimizer_with_attributes(Gurobi.Optimizer))
gpd["type"] = "TradeCurves_PC"
m3 = full_build_and_return_investment_model(m3,global_param_dict= gpd)
optimize!(m3)

#Inspection
timesteps = collect(1:gpd["endtime"])

c_import = [sum(JuMP.value.(m1.ext[:variables][:import][gpd["country"],neighbor,t] for neighbor in m1.ext[:sets][:connections][gpd["country"]])) for t in timesteps]
c_export = [sum(JuMP.value.(m1.ext[:variables][:export][gpd["country"],neighbor,t] for neighbor in m1.ext[:sets][:connections][gpd["country"]])) for t in timesteps]
net_imports_ic = c_import - c_export

trade_prices = m.ext[:sets][:trade_prices]
imports_tc_PC = [JuMP.value.(sum(m.ext[:variables][:import]["BE00",nb,p,t] for nb in m.ext[:sets][:neighbors] for p in trade_prices[nb])) for t in timesteps]
exports_tc_PC = [JuMP.value.(sum(m.ext[:variables][:export]["BE00",nb,p,t] for nb in m.ext[:sets][:neighbors] for p in trade_prices[nb])) for t in timesteps]
net_imports_tc_PC = imports_tc_PC - exports_tc_PC


trade_prices = m2.ext[:sets][:trade_prices]
imports_tc_endo = [JuMP.value.(sum(m2.ext[:variables][:import]["BE00",p,t] for p in trade_prices)) for t in timesteps]
exports_tc_endo = [JuMP.value.(sum(m2.ext[:variables][:export]["BE00",p,t] for p in trade_prices)) for t in timesteps]
net_imports_tc_endo = imports_tc_endo - exports_tc_endo

trade_prices = m3.ext[:sets][:trade_prices]
imports_tc_pc_2 = [JuMP.value.(sum(m3.ext[:variables][:import]["BE00",nb,p,t] for nb in m3.ext[:sets][:neighbors] for p in trade_prices[nb])) for t in timesteps]
exports_tc_pc_2= [JuMP.value.(sum(m3.ext[:variables][:export]["BE00",nb,p,t] for nb in m3.ext[:sets][:neighbors] for p in trade_prices[nb])) for t in timesteps]
net_imports_tc_pc_2 = imports_tc_pc_2 - exports_tc_pc_2


net_imports_tc_PC == net_imports_tc_pc_2
#Visualise net imports
s = 1
e = 72
plot(net_imports_ic[s:e], label = "Net import interconnected")
plot!(net_imports_tc_PC[s:e], label = "Net import TC Per country")
#plot!(net_imports_tc_pc_2[s:e], label = "Net import TC Per country 2")
plot!(net_imports_tc_endo[s:e], label = "Net import TC endo")
xlabel!("Time")
ylabel!("Net import (MW)")
plot!()

geo_scope_str = join(gpd["geo_scope"], "_")

path = joinpath("Results","Figures","Comp_IC_TCS_TCPC","net_import_$(gpd["year"])_$(gpd["Climate_year_ts"])_$(gpd["scenario"])_$(gpd["endtime"])_s_$(gpd["simplified"])_tc_$(gpd["country"])_gs_$(geo_scope_str)_$(gpd["stepsize"]).png")
savefig(path)


plot((net_imports_tc_endo-c_import  + c_export),label="Diff net NTC vs TC s endo")
plot!((net_imports_tc_PC-c_import  + c_export),label="Diff net NTC vs TC PC")

plot(c_export[s:e])
plot!(exports_tc_endo[s:e])
plot!(exports_tc_PC[s:e])

m.ext[:expressions][:export_revenue]

m.ext[:timeseries][:trade][:export]["FR00"]
m2.ext[:timeseries][:trade][:export]

sum(exports_tc_PC)
sum(exports_tc_endo)
sum(c_export)

sum(imports_tc_PC)
sum(imports_tc_endo)
sum(c_import)


##############################################################################################################################################################################
#Inspection of trade curves 
#Single timestep availibility 

t = 4
##Import

#For new method: single trade curve
prices = m2.ext[:sets][:trade_prices]
availability = m2.ext[:timeseries][:trade][:import]

tc_s = []
for p in prices
    a = repeat([p],floor(Int,availability[p][t]))
    append!(tc_s,a)
    print(" price: ",p," lenght: ",length(a))
end

#For Tim's method: curve per country 
neighbors = m.ext[:sets][:neighbors]
prices = m.ext[:sets][:trade_prices]
all_prices = union(vcat([prices[neighbor] for neighbor in neighbors]...))
availability = m.ext[:timeseries][:trade][:import]
import_lims = m.ext[:parameters][:import_lims]
tc_pc = []

trans_cap_available = Dict()
for n in neighbors
    trans_cap_available[n] = maximum(import_lims[n])
end
for p in all_prices
    availability_this_price = 0 
    for n in neighbors
        if p in (prices[n])
            actual_available = min(availability[n][p][t],trans_cap_available[n])
            trans_cap_available[n] -= actual_available 
            availability_this_price += actual_available
        end
    end
    a = repeat([p],floor(Int,availability_this_price))
    append!(tc_pc,a)
    print(" price: ",p," lenght: ",length(a))
end
trans_cap_available

plot(tc_s,label = "Single")
plot!(tc_pc,label = "Per country (summed)")
xlabel!("Price (Eur/MWh)")
ylabel!("Time")
title!("Export curve")

geo_scope_str = join(gpd["geo_scope"], "_")
path = joinpath("Results","Figures","Comp_IC_TCS_TCPC","export_curve_$(gpd["year"])_$(gpd["Climate_year_ts"])_$(gpd["scenario"])_$(gpd["endtime"])_s_$(gpd["simplified"])_tc_$(gpd["country"])_gs_$(geo_scope_str)_$(gpd["stepsize"]).png")
savefig(path)

##Export

#For new method: single trade curve
prices = m2.ext[:sets][:trade_prices]
availability = m2.ext[:timeseries][:trade][:export]

tc_s = []
for p in reverse(prices)
    a = repeat([p],floor(Int,availability[p][t]))
    append!(tc_s,a)
    print(" price: ",p," lenght: ",length(a))
end

#For Tim's method: curve per country 
neighbors = m.ext[:sets][:neighbors]
prices = m.ext[:sets][:trade_prices]
all_prices = reverse(sort((union(vcat([prices[neighbor] for neighbor in neighbors]...)))))
availability = m.ext[:timeseries][:trade][:export]
import_lims = m.ext[:parameters][:export_lims]
tc_pc = []

trans_cap_available = Dict()
for n in neighbors
    trans_cap_available[n] = maximum(export_lims[n])
end
for p in all_prices
    availability_this_price = 0 
    for n in neighbors
        if p in (prices[n])
            actual_available = min(availability[n][p][t],trans_cap_available[n])
            trans_cap_available[n] -= actual_available 
            availability_this_price += actual_available
        end
    end
    a = repeat([p],floor(Int,availability_this_price))
    append!(tc_pc,a)
    print(" price: ",p," lenght: ",length(a))
end
trans_cap_available
availability["DE00"]
plot(tc_s,label = "Single")
plot!(tc_pc,label = "Per country (summed)")
xlabel!("Time")
ylabel!("Price (EUR/MWh)")

m.ext[:parameters]
m2.ext[]
##############################################################################################################################################################################
#######################
# Intermediate models #
#######################

m = initialize_and_build_model_to_obtain_curves_per_country(gpd["country"],gpd["scenario"],gpd["year"],gpd["Climate_year"],gpd["Climate_year_ts"],gpd["simplified"],gpd["geo_scope"])

gpd["type"] = "NTC"
m1 = full_build_and_return_investment_model(m1,global_param_dict= gpd)

plot(get_zero_cost_prod(m,"FR00",gpd["endtime"])[1])
plot!(get_zero_cost_prod(m1,"FR00",gpd["endtime"])[1])

net_demand = get_zero_cost_prod(m1,"FR00",gpd["endtime"])[1] -  m1.ext[:timeseries][:demand]["FR00"]

get_zero_cost_prod(m,"BE00",gpd["endtime"])[1]
get_zero_cost_prod(m1,"BE00",gpd["endtime"])[1]

get_production(m,"BE00")
get_production(m1,"BE00")
