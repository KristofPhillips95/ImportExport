include("../ImportExport/model_builder.jl")
include("../ImportExport/curve_based_model_builder.jl")
include("../ImportExport/cost_curves_builder.jl")
using Gurobi
using CSV
using Plots

# Start comparing the models in the old way
#First, define the global params
endtime = 96
CY = 1984
CY_ts = 2012
VOLL = 8000
country = "BE00"
transport_cost = 0.1
disc_rate = 0.07
simplified = true
target_cap_for_curves ="endo_invest"

sc_ty_tuples = [("National Trends",2025), ("National Trends",2030),("National Trends",2040),("Distributed Energy",2030),("Distributed Energy",2040)]
sc_ty_tuple = sc_ty_tuples[1]
scenario = sc_ty_tuple[1]
year = sc_ty_tuple[2]

#Start the building process of 2 models 
m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m2 = Model(optimizer_with_attributes(Gurobi.Optimizer))

#m1 will be the interconnected model, m2 is the one with trade curves

#Define sets
define_sets!(m1,scenario,year,CY,[],[country],simplified)

all_countries = get_all_countries(scenario,year,CY)
define_sets!(m2,scenario,year,CY,filter((e->e != "BE00"),all_countries),["BE00"])

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

curves = read_prices(scenario,year,CY_ts,endtime,simplified,target_cap_for_curves,100)
add_availability_curves_to_model!(m2,curves)
build_single_trade_curve_investment_model!(m2,endtime,VOLL,transport_cost,disc_rate,simplified)


optimize!(m1)
optimize!(m2)

#Inspection

timesteps = 1:endtime
trade_prices = m2.ext[:sets][:trade_prices]
# timesteps = collect(1:gpd["endtime"])
imports = [JuMP.value.(sum(m2.ext[:variables][:import]["BE00",p,t] for p in trade_prices)) for t in timesteps]
exports = [JuMP.value.(sum(m2.ext[:variables][:export]["BE00",p,t] for p in trade_prices)) for t in timesteps]


c_import = [sum(JuMP.value.(m1.ext[:variables][:import][country,neighbor,t] for neighbor in m1.ext[:sets][:connections][country])) for t in timesteps]
c_export = [sum(JuMP.value.(m1.ext[:variables][:export][country,neighbor,t] for neighbor in m1.ext[:sets][:connections][country])) for t in timesteps]


#Visualise total imports and exports
plot(imports,label = "Imports TC")
plot!(-exports, label = "Exports TC")
plot!(c_import -c_export, label = "Net import interconnected")


#With the newer methods 
using Plots
include("../ImportExport/build_and_run.jl")
include("../ImportExport/build_and_save_cost_curves.jl")
gpd = Dict()

endtime = gpd["endtime"] = 24*3
gpd["Climate_year"] = 1984
gpd["Climate_year_ts"] = 2012
gpd["ValOfLostLoad"] = 8000
country = gpd["country"] = "BE00" 
gpd["scenario"] = "National Trends"
gpd["year"] = 2025
gpd["stepsize"] = 10
gpd["transport_cost"] = 0.1
gpd["simplified"] = true
gpd["target_cap_for_curves"] = "TYNDP"
gpd["disc_rate"] = 0.07
gpd["geo_scope"] = "All"


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

m2.ext[:sets]
m3.ext[:sets]


optimize!(m1)
optimize!(m2)
optimize!(m3)

#Inspection
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

plot(net_imports_tc_endo - c_import + c_export)

m2.ext[:expressions][:import_cost]
m2.ext[:expressions][:trade_cost]

m2.ext[:timeseries][:trade][:import]

sum([JuMP.value(m1.ext[:expressions][:transport_cost][country,neighbor,t]) for neighbor in m1.ext[:sets][:connections][country] for t in timesteps])
sum(JuMP.value.(m2.ext[:expressions][:trade_cost]))
sum(JuMP.value.(m3.ext[:expressions][:trade_cost]))

dual_m2 = [JuMP.dual.(m2.ext[:constraints][:demand_met][country,t]) for t in timesteps]
dual_m1 = [JuMP.dual.(m1.ext[:constraints][:demand_met][country,t]) for t in timesteps ]
plot()
plot!(twinx(),dual_m2)
plot!(twinx(),dual_m1)

dual_diff = dual_m1 - dual_m2
plot(dual_diff)


technologies = m1.ext[:sets][:technologies][country]
non_inv_technologies = m1.ext[:sets][:non_investment_technologies][country]
inv_technologies = m1.ext[:sets][:investment_technologies][country]

[m1.ext[:constraints][:production_capacity_non_inv][country,tech,t] for tech in non_inv_technologies for t in timesteps]
[m2.ext[:constraints][:production_capacity_non_inv][country,tech,t] for tech in non_inv_technologies for t in timesteps]
m1.ext[:constraints][:production_capacity]