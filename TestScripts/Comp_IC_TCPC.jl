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
gpd["stepsize"] = 10
gpd["transport_price"] = 0.1
gpd["simplified"] = true
gpd["disc_rate"] = 0.07
gpd["geo_scope"] = ["BE00","FR00"]
# gpd["target_cap_for_curves"] = "endo_invest"


#Start the building process of 3 models 
m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m2 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m3 = Model(optimizer_with_attributes(Gurobi.Optimizer))


gpd["type"] = "NTC"
gpd["target_cap_for_curves"] = "endo_invest"
gpd["trans_cap_other"] = "S"
m1 = full_build_and_return_investment_model(m1,global_param_dict= gpd)

gpd["type"] = "NTC"
gpd["target_cap_for_curves"] = "endo_invest"
gpd["trans_cap_other"] = 0
m2 = full_build_and_return_investment_model(m2,global_param_dict= gpd)

gpd["type"] = "TCPC"
m3 = full_build_and_return_investment_model(m3,global_param_dict= gpd)


optimize!(m1)
optimize!(m2)
optimize!(m3)

#Inspection
timesteps = collect(1:gpd["endtime"])

ntc_s_import,ntc_s_export =get_import_and_export(m1,country,"NTC")
net_imports_ntc_s = ntc_s_import-ntc_s_export

ntc_r_import,ntc_r_export = get_import_and_export(m2,country,"NTC")
net_imports_ntc_r = ntc_r_import-ntc_r_export

imports_tc_PC,exports_tc_PC = get_import_and_export(m3,country,"TCPC")
net_imports_tc_PC = imports_tc_PC - exports_tc_PC

#Visualise net imports
plot(net_imports_ntc_s, label = "Net import interconnected full")
plot!(net_imports_tc_PC, label = "Net import TC Per country")
plot!(net_imports_ntc_r, label = "Net import interconnected trans cap 0")
xlabel!("Time")
ylabel!("Net import (MW)")
plot!()
geo_scope_str = join(gpd["geo_scope"], "_")

path = joinpath("Results","Figures","Comp_IC_ICR_TC","import_price_curves$(gpd["year"])_$(gpd["Climate_year_ts"])_$(gpd["scenario"])_$(gpd["endtime"])_s_$(gpd["simplified"])_tc_$(gpd["country"])_gs_$(geo_scope_str)_$(gpd["stepsize"]).png")
savefig(path)
