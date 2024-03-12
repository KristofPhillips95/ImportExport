include("ImportExport/model_builder.jl")
include("ImportExport/curve_based_model_builder.jl")
include("ImportExport/cost_curves_builder.jl")
include("ImportExport/build_and_save_cost_curves.jl")
include("ImportExport/build_and_run.jl")
using Gurobi
using Plots

#Test building the model 
endtime = 72
CY = 1984
CY_ts = 2012
VOLL = 8000
country = "BE00"
transport_cost = 0.1
disc_rate = 0.07
geo_scope = "All"
#geo_scope = ["BE00","FR00","UK00"]

sc_ty_tuples = [("National Trends",2025), ("National Trends",2030),("National Trends",2040),("Distributed Energy",2030),("Distributed Energy",2040)]
sc_ty_tuple = sc_ty_tuples[1]
scenario = sc_ty_tuple[1]
year = sc_ty_tuple[2]
simplified = true

m = initialize_and_build_model_to_obtain_curves_per_country(country,scenario,year,CY,CY_ts,simplified,geo_scope)
m.ext[:sets][:connections][country] 

import_availabilities,export_availabilities = get_per_country_trade_availability(m)
import_lims,export_lims = get_per_country_trade_limits(m,country)

#functions to build the trade curves from Tim's method 

m = Model(optimizer_with_attributes(Gurobi.Optimizer))
all_countries = get_all_countries(scenario,year,CY)
define_sets!(m,scenario,year,CY,filter((e->e != "BE00"),all_countries),["BE00"],simplified)
process_parameters!(m,scenario,year,CY,[country],simplified)
process_time_series!(m,scenario,year,CY_ts,simplified,endtime)
remove_capacity_country!(m,country)
add_per_country_availability_curves_to_model!(m,import_availabilities,export_availabilities,import_lims,export_lims)
build_per_country_trade_curve_investment_model!(m,endtime,VOLL,transport_cost,disc_rate,simplified)
m.ext[:timeseries][:trade][:import]
optimize!(m)

#################################################
#Compare with new IE method for single neighbor #
#################################################

using Plots
gpd = Dict()

endtime = gpd["endtime"] = 72
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
geo_scope = gpd["geo_scope"] = ["BE00","UK00"]

#Obtain the availability curves for Tim's method
m = initialize_and_build_model_to_obtain_curves_per_country(country,scenario,year,CY,CY_ts,simplified,geo_scope)
import_availabilities,export_availabilities = get_per_country_trade_availability(m)
import_lims,export_lims = get_per_country_trade_limits(m,country)

gpd["type"] = "TradeCurves"
gpd["target_cap_for_curves"] = "endo_invest"
build_and_save_cost_curves(gpd = gpd,save_soc=true,save_results=true)

#Start the building process of 3 models 
m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m2 = Model(optimizer_with_attributes(Gurobi.Optimizer))

m2 = full_build_and_return_investment_model(m2,global_param_dict= gpd)

all_countries = get_all_countries(scenario,year,CY)
define_sets!(m1,scenario,year,CY,filter((e->e != country),all_countries),[country],simplified)
process_parameters!(m1,scenario,year,CY,[country],simplified)
process_time_series!(m1,scenario,year,CY_ts,simplified,endtime)
remove_capacity_country!(m1,country)
add_per_country_availability_curves_to_model!(m1,import_availabilities,export_availabilities,import_lims,export_lims)
build_per_country_trade_curve_investment_model!(m1,endtime,VOLL,transport_price,disc_rate,simplified)

#Inspection of trade curves 
t = 18

#Single timestep availibility 

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
neighbors = m1.ext[:sets][:neighbors]
prices = m1.ext[:sets][:trade_prices]
all_prices = union(vcat([prices[neighbor] for neighbor in neighbors]...))
availability = m1.ext[:timeseries][:trade][:import]
import_lims = m1.ext[:parameters][:import_lims]
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
availability["UK00"][0][t]

plot(tc_s,label = "Single")
plot!(tc_pc,label = "Per country")


m.ext[:sets][:intermittent_technologies]["UK00"]
sum(m.ext[:timeseries][:inter_gen]["UK00"][tech][t] * 
m.ext[:parameters][:technologies][:capacities]["UK00"][tech]
 for tech in m.ext[:sets][:intermittent_technologies]["UK00"])
get_zero_cost_prod(m,"UK00",t)[1][t]

m.ext[:timeseries][:demand]["UK00"][t]
m.ext[:parameters][:technologies][:capacities]["UK00"]

m.ext[:sets][:technologies]["UK00"]
m.ext[:timeseries][:hydro_inflow]["UK00"]["ROR"]


m0 = build_model_for_import_curve(200,nothing,nothing,gpd)
optimize!(m0)
[JuMP.dual.(m0.ext[:constraints][:demand_met][country,t]) for t in 1:endtime][71]
Dict(tech => JuMP.value.(m0.ext[:variables][:production]["UK00",tech,71]) for tech in m0.ext[:sets][:technologies]["UK00"])

[JuMP.value.(m0.ext[:variables][:production]["UK00","ROR",t]) for t in 1:endtime ]
#######################
#Inspection of Results
#######################
optimize!(m1)
optimize!(m2)




#Inspection of 
timesteps = collect(1:gpd["endtime"])

c_import = [sum(JuMP.value.(m1.ext[:variables][:import][gpd["country"],neighbor,t] for neighbor in m1.ext[:sets][:connections][gpd["country"]])) for t in timesteps]
c_export = [sum(JuMP.value.(m1.ext[:variables][:export][gpd["country"],neighbor,t] for neighbor in m1.ext[:sets][:connections][gpd["country"]])) for t in timesteps]

trade_prices = m2.ext[:sets][:trade_prices]
imports = [JuMP.value.(sum(m2.ext[:variables][:import]["BE00",p,t] for p in trade_prices)) for t in timesteps]
exports = [JuMP.value.(sum(m2.ext[:variables][:export]["BE00",p,t] for p in trade_prices)) for t in timesteps]
net_imports_tc_TYNDP = imports - exports


trade_prices = m3.ext[:sets][:trade_prices]
imports = [JuMP.value.(sum(m3.ext[:variables][:import]["BE00",p,t] for p in trade_prices)) for t in timesteps]
exports = [JuMP.value.(sum(m3.ext[:variables][:export]["BE00",p,t] for p in trade_prices)) for t in timesteps]
net_imports_tc_endo = imports - exports


net_imports_tc_TYNDP == net_imports_tc_endo

#Visualise total imports and exports
# plot(imports,label = "Imports TC")
# plot!(-exports, label = "Exports TC")
plot(net_imports_tc_TYNDP, label = "Net import TC TYNDP")
plot!(net_imports_tc_endo, label = "Net import TC endo")
plot!(c_import -c_export, label = "Net import interconnected")

m1.ext[:objective]
m2.ext[:objective]
