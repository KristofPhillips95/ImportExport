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
single_neighbor = "DE00"
gpd["geo_scope"] = ["BE00",single_neighbor]
gpd["trans_cap_other"] = "S"
gpd["target_cap_for_curves"] = "endo_invest"

function get_import_cost(m,country,type)
    import_cost = Dict()
    
    timesteps = collect(1:length(m.ext[:timeseries][:demand][country]))
    local_price_t = [JuMP.dual.(m.ext[:constraints][:demand_met][country, t]) for t in timesteps]
    per_neighbor_import = get_pc_import_and_export(m,country,type)[1]
    

    for neighbor in keys(per_neighbor_import)
        import_cost[neighbor] = per_neighbor_import[neighbor] .* local_price_t
    end
    return import_cost
end
function get_export_revenue(m,coutry,type)
    export_rev = Dict()
    
    timesteps = collect(1:length(m.ext[:timeseries][:demand][country]))
    local_price_t = [JuMP.dual.(m.ext[:constraints][:demand_met][country, t]) for t in timesteps]
    per_neighbor_export = get_pc_import_and_export(m,country,type)[2]
    
    for neighbor in keys(per_neighbor_export)
        export_rev[neighbor] = per_neighbor_export[neighbor] .* local_price_t
    end
    return export_rev
end

function get_import_cost_and_export_revenue()
    import_cost = Dict()
    export_cost = Dict()
    
    timesteps = collect(1:length(m.ext[:timeseries][:demand][country]))
    local_price_t = [JuMP.dual.(m.ext[:constraints][:demand_met][country, t]) for t in timesteps]
    per_neighbor_import,per_neighbor_export = get_pc_import_and_export(m,country,type)[1]
    

    for neighbor in keys(per_neighbor_import)
        import_cost[neighbor] = per_neighbor_import[neighbor] .* local_price_t
        export_rev[neighbor] = per_neighbor_export[neighbor] .* local_price_t
    end
    return import_cost,export_rev
end
function get_congestion_rents(m,country,type)
    timesteps = collect(1:length(m.ext[:timeseries][:demand][country]))

    per_neighbor_import,per_neighbor_export,m_dp = get_pc_import_and_export(m,country,type)

    local_price_t = [JuMP.dual.(m.ext[:constraints][:demand_met][country, t]) for t in timesteps]
    print(local_price_t)


    if type == "NTC"
        neighbor_price_t = Dict(neighbor => [JuMP.dual.(m.ext[:constraints][:demand_met][neighbor, t]) for t in timesteps] for neighbor in m.ext[:sets][:connections][country])
    elseif type == "TCPC"
        import_pc,export_pc = get_pc_pp_import_and_export(m,country,"TCPC")
        neighbor_price_t_imp = get_pc_trade_price(import_pc,"i",0)
        neighbor_price_t_exp = get_pc_trade_price(export_pc,"e",0)
        println(neighbor_price_t_exp)
        println(neighbor_price_t_imp)

        neighbor_price_t = Dict(neighbor=> [max(neighbor_price_t_imp[neighbor][i], neighbor_price_t_exp[neighbor][i]) for i in 1:length(neighbor_price_t_exp[neighbor])] for neighbor in keys(neighbor_price_t_exp))
        print(neighbor_price_t)
    elseif type == "TCS"
        # soc = nothing
        # production = nothing

        # import_,export_ = get_import_and_export(m,country,type)
        # net_import_profile = import_-export_
        # println("Solving auxiliary model for congestion rents")
        # m_dp = build_model_for_import_curve(0,soc,production,gpd)
        # change_import_level_t!(m_dp,net_import_profile,"BE00")
        # optimize!(m_dp)
        # #import_,export_ = get_pc_import_and_export(m_dp,country,"NTC")
        neighbor_price_t = Dict(neighbor => [JuMP.dual.(m_dp.ext[:constraints][:demand_met][neighbor, t]) for t in timesteps] for neighbor in m_dp.ext[:sets][:connections][country])

    else
        error("Model type: ",model_type," not implemented")
    end

    cr_i = Dict()
    cr_e = Dict()

    for neighbor in keys(per_neighbor_import)
        cr_i[neighbor] = per_neighbor_import[neighbor] .* (local_price_t .- neighbor_price_t[neighbor])
        cr_e[neighbor] = per_neighbor_export[neighbor] .* (neighbor_price_t[neighbor] .- local_price_t)
    end

    return cr_i,cr_e
end

function get_total_trade_costs_and_rents(m,country,type)

    imp_c,exp_c = get_import_cost(m,country,type)

    tic = sum(sum(get_trade_cost(import_v,import_p)[neighbor]) for neighbor in keys(import_v))
    tec = sum(sum(get_trade_cost(export_v,export_p)[neighbor]) for neighbor in keys(export_v))
    return tic,tec
end
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


import_pc_1, export_pc_1 = get_pc_import_and_export(m1,"BE00","NTC")
import_pc_2,export_pc_2 = get_pc_import_and_export(m2,"BE00","TCPC")
#import_pc_3,export_pc_3 = get_pc_import_and_export(m3,"BE00","TCS")
import_3,export_3 = get_import_and_export(m3,"BE00","TCS")

net_import_profile = import_3-export_3

m = build_model_for_import_curve(0,nothing,nothing,gpd)
change_import_level_t!(m,net_import_profile,"BE00")
optimize!(m)

import_pc_3,export_pc_3 = get_pc_import_and_export(m,"BE00","NTC")


import_pc_1
import_pc_2

import_p_1,export_p_1 = get_pc_import_and_export_price(m1,"BE00","NTC")
import_p_2,export_p_2 = get_pc_import_and_export_price(m2,"BE00","TCPC")
import_p_3,export_p_3 = get_pc_import_and_export_price(m,"BE00","NTC")

#import_pc_p = get_pc_trade_price(import_pc,"i",gpd["transport_price"])
#export_pc_p = get_pc_trade_price(export_pc,"e",gpd["transport_price"])

sum(get_trade_cost(import_pc_1,import_p_1)[single_neighbor])
sum(get_trade_cost(import_pc_2,import_p_2)[single_neighbor])
sum(get_trade_cost(import_pc_3,import_p_3)[single_neighbor])

sum(get_trade_cost(export_pc_1,export_p_1)[single_neighbor])
sum(get_trade_cost(export_pc_2,export_p_2)[single_neighbor])
sum(get_trade_cost(export_pc_3,export_p_3)[single_neighbor])

sum(get_import_cost(m1,"BE00","NTC")[single_neighbor])
sum(get_export_revenue(m1,"BE00","NTC")[single_neighbor])

sum(get_import_cost(m2,"BE00","TCPC")[single_neighbor])
sum(get_export_revenue(m2,"BE00","TCPC")[single_neighbor])

sum(get_import_cost(m3,"BE00","TCS")[single_neighbor])
sum(get_export_revenue(m3,"BE00","TCS")[single_neighbor])


sum(get_congestion_rents(m1,"BE00","NTC")[1][single_neighbor])
sum(get_congestion_rents(m1,"BE00","NTC")[2][single_neighbor])

sum(get_congestion_rents(m2,"BE00","TCPC")[1][single_neighbor])
sum(get_congestion_rents(m2,"BE00","TCPC")[2][single_neighbor])

sum(get_congestion_rents(m3,"BE00","TCS")[1][single_neighbor])
sum(get_congestion_rents(m3,"BE00","TCS")[2][single_neighbor])

m1.ext[:constraints]
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



total_import_cost_1, total_export_rev_1 = get_total_trade_costs(m1,"BE00","NTC")
total_import_cost_2, total_export_rev_2 = get_total_trade_costs(m2,"BE00","TCPC")
total_import_cost_3, total_export_rev_3 = get_total_trade_costs(m3,"BE00","TCS")
total_import_cost_4, total_export_rev_4 = get_total_trade_costs(m4,"BE00","NTC")


import_2,export_2 = get_import_and_export(m2,"BE00","TCPC")
import_4,export_4 = get_import_and_export(m4,"BE00","NTC")

import_2 - import_4
export_2 - export_4

JuMP.value.(m4.ext[:variables][:invested_cap])
JuMP.value.(m2.ext[:variables][:invested_cap])
total_export_rev_2 - total_import_cost_2
total_export_rev_4 - total_import_cost_4
