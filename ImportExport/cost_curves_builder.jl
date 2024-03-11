include("model_builder.jl")
import Gurobi

#Functions related to building the novel method curves
function optimize_and_retain_intertemporal_decisions(global_param_dict)
    #Start by extracting relevant parameters
    endtime = global_param_dict["endtime"]
    CY_cap = global_param_dict["Climate_year"]
    CY_ts = global_param_dict["Climate_year_ts"]
    VOLL = global_param_dict["ValOfLostLoad"]
    transport_price = global_param_dict["transport_price"]
    country = global_param_dict["country"]
    scenario = global_param_dict["scenario"]
    year = global_param_dict["year"]
    simplified = global_param_dict["simplified"]
    target_cap_for_curves = global_param_dict["target_cap_for_curves"]
    disc_rate = global_param_dict["disc_rate"]
    geo_scope = global_param_dict["geo_scope"]

    if simplified
        error("Hey dumdum, with a simplified model it makes no sense to do this")
    end

    #Create a JuMP model instance
    m = Model(optimizer_with_attributes(Gurobi.Optimizer))
    
    #Based on the target_cap_for_curves parameter, make the list of countries (1 or zero)
    # in which investment is possible
    if target_cap_for_curves == "TYNDP"
        inv_country = []
    elseif target_cap_for_curves == "endo_invest"
        inv_country = [country]
    end
    #Based on the geo_scope parameter, make the list of countries which are excluded from the model

    c_excluded = get_list_of_excluded(geo_scope,scenario,year,CY_cap)


    # Then, add sets, parameters, and timeseries to the model
    define_sets!(m,scenario,year,CY_cap,c_excluded,inv_country,simplified)
    process_parameters!(m,scenario,year,CY_cap,inv_country,simplified)
    process_time_series!(m,scenario,year,CY_ts,simplified,endtime)

    #Based on the target_cap_for_curves parameter, build the relevant model
    if target_cap_for_curves == "TYNDP"
        build_NTC_dispatch_model!(m,endtime,VOLL,transport_price,simplified)
    elseif target_cap_for_curves == "endo_invest"
        remove_capacity_country!(m,country,simplified)
        build_NTC_investment_model!(m,endtime,VOLL,transport_price,disc_rate,simplified)
    end
    optimize!(m)
    soc = JuMP.value.(m.ext[:variables][:soc])
    production = JuMP.value.(m.ext[:variables][:production])

    return m,soc,production
end

function write_sparse_axis_to_dict(sparse_axis)
    dict =  Dict()
    for key in eachindex(sparse_axis)
        dict[key] = sparse_axis[key]
    end
    return dict
end

function build_model_for_import_curve_before_fixing(global_param_dict,import_level)
    endtime = global_param_dict["endtime"]
    CY_cap = global_param_dict["Climate_year"]
    CY_ts = global_param_dict["Climate_year_ts"]

    VOLL = global_param_dict["ValOfLostLoad"]
    transp_price = global_param_dict["transport_price"]
    country = global_param_dict["country"]
    scenario = global_param_dict["scenario"]
    year = global_param_dict["year"]
    simplified = global_param_dict["simplified"]
    geo_scope = global_param_dict["geo_scope"]

    m = Model(optimizer_with_attributes(Gurobi.Optimizer))

    c_excluded = get_list_of_excluded(geo_scope,scenario,year,CY_cap)

    define_sets!(m,scenario,year,CY_cap,c_excluded,[],simplified)
    process_parameters!(m,scenario,year,CY_cap,[],simplified)
    process_time_series!(m,scenario,year,CY_ts,simplified,endtime)
    remove_capacity_country!(m,country)
    set_demand_country(m,country,import_level)
    build_NTC_dispatch_model!(m,endtime,VOLL,transp_price,simplified)

    return m
end

function build_model_for_import_curve(import_level,soc,production,global_param_dict)
    m = build_model_for_import_curve_before_fixing(global_param_dict,import_level)
    endtime = global_param_dict["endtime"]
    country = global_param_dict["country"]
    simplified = global_param_dict["simplified"]
    if !(simplified)
        fix_soc_decisions(m,soc,production,1:endtime,country)
        #print("WATCH OUT!!! soc decisions not fixed")
    end
    #optimize!(m)
    return m
end

function build_model_for_import_curve_from_dict(import_level,soc,production,global_param_dict)
    m = build_model_for_import_curve_before_fixing(global_param_dict,import_level)
    endtime = global_param_dict["endtime"]
    country = global_param_dict["country"]
    fix_soc_decisions_from_dict(m,soc,production,1:endtime,country)
    #optimize!(m)
    return m
end

function change_import_level!(m,endtime,import_level,country)
    for t in 1:endtime
        set_normalized_rhs(m.ext[:constraints][:demand_met][country,t],import_level)
    end
end

#Some functions that check if expected values are indeed found for import-curve models
function check_equal_soc_for_all_but(m1,m2,country,endtime)
    countries = filter(e->e !=country,m1.ext[:sets][:countries])
    soc_technologies = m1.ext[:sets][:soc_technologies]
    for country in countries
        # print(country)
        for tech in m1.ext[:sets][:soc_technologies][country]
            soc_1 = [JuMP.value.(m1.ext[:variables][:soc][country,tech,t]) for t in 1:endtime]
            soc_2 = [JuMP.value.(m2.ext[:variables][:soc][country,tech,t]) for t in 1:endtime]
            @assert(soc_1 == soc_2)

            prod_soc_1  = [JuMP.value.(m1.ext[:variables][:production][country,tech,t]) for t in 1:endtime]
            prod_soc_1  = [JuMP.value.(m2.ext[:variables][:production][country,tech,t]) for t in 1:endtime]
            @assert(soc_1 == soc_2)

        end
    end
end

function check_net_import(m,country,import_level,endtime,simplified)

    net_import = [sum(JuMP.value.(m.ext[:variables][:import][country,nb,t]) - JuMP.value.(m.ext[:variables][:export][country,nb,t]) for nb in m.ext[:sets][:connections][country]) for t in 1:endtime]
    for t in 1:endtime
        if round(net_import[t] + JuMP.value.(m.ext[:variables][:load_shedding][country, t]), digits=3) != import_level
            print(keys(m.ext[:variables]))

            println("Assertion failed at time $t:")
            println("net_import[t]: ", net_import[t])
            println("load_shedding: ", JuMP.value.(m.ext[:variables][:load_shedding][country, t]))
            println("Expected import_level: ", import_level)
            println("Actual calculated value: ", round(net_import[t] + JuMP.value.(m.ext[:variables][:load_shedding][country, t]), digits=3))
            println("constraint: ", (m.ext[:constraints][:demand_met][country, t]))
            println("simplified: ", simplified)
            println("Production: ", Dict(tech => JuMP.value.(m.ext[:variables][:production][country,tech,t]) for tech in m.ext[:sets][:technologies][country]) )
            net_import_d = Dict( nb => JuMP.value.(m.ext[:variables][:import][country,nb,t]) - JuMP.value.(m.ext[:variables][:export][country,nb,t]) for nb in m.ext[:sets][:connections][country]) 
            import_d = Dict( nb => JuMP.value.(m.ext[:variables][:import][country,nb,t]) for nb in m.ext[:sets][:connections][country]) 
            export_d = Dict( nb => JuMP.value.(m.ext[:variables][:export][country,nb,t]) for nb in m.ext[:sets][:connections][country]) 

            println("Imports: ", import_d)
            println("Exports: ", export_d)
            charge = m.ext[:variables][:charge]
            println("Charge: ", JuMP.value.(charge["BE00","PS_C",t]) + JuMP.value.(charge["BE00","Battery",t]))
            println("Caps: ",m.ext[:parameters][:technologies][:capacities][country] )
            println("Charge: ", Dict(tech => JuMP.value.(m.ext[:variables][:charge][country,tech,t]) for tech in m.ext[:sets][:storage_technolgies][country]  ))
        end
        @assert( round(net_import[t] + JuMP.value.(m.ext[:variables][:load_shedding][country,t]) ,digits = 3)  == import_level)
    end
end

function check_charge_zero(m,country,endtime)
    for t in 1:endtime
        ls = sum(JuMP.value.(m.ext[:variables][:charge][country,tech,t]) for tech in m.ext[:sets][:storage_technologies][country])
        @assert( round(ls, digits=3) == 0 )
    end
end

function check_production_zero!(m,country,endtime)
    for t in 1:endtime
        for tech in m.ext[:sets][:technologies][country]
            @assert(JuMP.value.(m.ext[:variables][:production][country,tech,t]) == 0)
        end
    end
end

function write_prices(curve_dict,import_levels,global_param_dict)
    endtime = global_param_dict["endtime"]
    CY_ts = global_param_dict["Climate_year_ts"]

    transp_price = global_param_dict["transport_price"]
    country = global_param_dict["country"]
    scenario = global_param_dict["scenario"]
    year = global_param_dict["year"]
    simplified = global_param_dict["simplified"]
    target_cap_for_curves = global_param_dict["target_cap_for_curves"]
    stepsize = global_param_dict["stepsize"]
    geo_scope = global_param_dict["geo_scope"]

    geo_scope_str = join(geo_scope, "_")

    df_prices = DataFrame()
    for price in import_levels
        rounded_values = [round(val, digits=6) for val in curve_dict[price].+0.0000001 ] # Round to 6 decimal places
        insertcols!(df_prices,1,string(price) => rounded_values)
    end
    # # Convert string representations of prices back to floats
    # for col in names(df_prices)
    #      df_prices[!, col] = parse.(Float64, df_prices[!, col])
    # end
    path = joinpath("Results","TradeCurves","import_price_curves$(year)_$(CY_ts)_$(scenario)_$(endtime)_s_$(simplified)_tc_$(country)_$(target_cap_for_curves)_gs_$(geo_scope_str)_$(stepsize).csv")

    CSV.write(path,df_prices)
end

function read_prices(scenario,year,CY_ts,endtime,simplified,country,target_cap_for_curves,geo_scope,stepsize)
    geo_scope_str = join(geo_scope, "_")
    path = joinpath("Results","TradeCurves","import_price_curves$(year)_$(CY_ts)_$(scenario)_$(endtime)_s_$(simplified)_tc_$(country)_$(target_cap_for_curves)_gs_$(geo_scope_str)_$(stepsize).csv")
    return CSV.read(path,DataFrame)
end

#functions to build the trade curves from Tim's method 
function initialize_and_build_model_to_obtain_curves_per_country(endtime,country,scenario,year,CY,CY_ts,simplified,geo_scope)

    m = Model(optimizer_with_attributes(Gurobi.Optimizer))
    c_excluded = get_list_of_excluded(geo_scope,scenario,year,CY)
    define_sets!(m,scenario,year,CY,c_excluded,[country],simplified)

    #We start by redefining the sets here, to remove unnecessary countries. 
    for c in m.ext[:sets][:countries]
        if !(c in m.ext[:sets][:connections][country]) && !(c == country)
            push!(c_excluded,c)
        end
    end

    # # list_to_keep = ["BE00","FR00","NL00"]
    # # filter((e->e != "BE00"),all_countries)
    # all_countries = m.ext[:sets][:countries]
    # filtered_countries = filter(e -> !(e in list_to_keep), all_countries)
    # print(filtered_countries)
    
    define_sets!(m,scenario,year,CY,c_excluded,[],simplified)
    
    process_parameters!(m,scenario,year,CY,[],simplified)
    process_time_series!(m,scenario,year,CY_ts,simplified,endtime)    
    return m
end

function get_zero_cost_prod(m,c,endtime)
    intermittent_timeseries = m.ext[:timeseries][:inter_gen]
    hydro_timeseries = m.ext[:timeseries][:hydro_inflow]
    total_flat_gen = m.ext[:parameters][:technologies][:total_gen]

    intermittent_techs = m.ext[:sets][:intermittent_technologies][c]
    hydro_inflow_techs = m.ext[:sets][:hydro_flow_technologies][c]
    flat_run_techs = m.ext[:sets][:flat_run_technologies][c]

    capacities = m.ext[:parameters][:technologies][:capacities]

    ren_prod = [sum(capacities[c][tech]*intermittent_timeseries[c][tech][time] for tech in intermittent_techs) for time in 1:endtime]
    hydro_prod = [sum(hydro_timeseries[c][tech][time] for tech in hydro_inflow_techs) for time in 1:endtime]
    flat_prod = [sum(total_flat_gen[c][tech]/8760*1000 for tech in flat_run_techs) for time in 1:endtime]

    nb_techs_included = length(intermittent_techs) + length(hydro_inflow_techs) + length(flat_run_techs)
    total_zero_cost_prod = ren_prod + hydro_prod + flat_prod
    return total_zero_cost_prod,nb_techs_included
end

function get_soc_techs_prod(m,c,endtime)
    soc_techs = m.ext[:sets][:soc_technologies][c]
    soc_prod = [sum(m.ext[:variables][:production][tech][time] for tech in soc_techs) for time in 1:endtime]
    soc_charge = [sum(m.ext[:variables][:charge][tech][time] for tech in soc_techs) for time in 1:endtime]
    nb_soc_techs = length(soc_techs)
    return soc_prod - soc_charge, nb_soc_techs
end

function get_static_nonzero_cost_cap(m,c,VOLL)
    print(c)
    VOM = m.ext[:parameters][:technologies][:VOM]
    fuel_price = m.ext[:parameters][:technologies][:fuel_price]
    efficiencies = m.ext[:parameters][:technologies][:efficiencies]
    emissions = m.ext[:parameters][:technologies][:emissions]
    CO2_price = m.ext[:parameters][:CO2_price]
    capacities = m.ext[:parameters][:technologies][:capacities]

    production_costs = Dict(get_marginal_price(c,tech,VOM,efficiencies,fuel_price,emissions,CO2_price) => capacities[c][tech] for tech in m.ext[:sets][:dispatchable_technologies][c])
    production_costs[VOLL] = maximum(m.ext[:timeseries][:demand][c])
    return production_costs,length(m.ext[:sets][:dispatchable_technologies][c])
end

function get_marginal_price(c,tech,VOM,efficiencies,fuel_price,emissions,CO2_price)
    return VOM[c][tech] + (1/efficiencies[c][tech])*fuel_price[c][tech] + (1/efficiencies[c][tech])*emissions[c][tech]*CO2_price
end

function get_per_country_trade_limits(m,country)
    import_lims = m.ext[:parameters][:connections][country]
    export_lims = Dict(neighbor => m.ext[:parameters][:connections][neighbor][country] for neighbor in m.ext[:sets][:connections][country]) 
    return import_lims,export_lims
end

function get_supply_curves(m,c,zero_cost_prod,static_non_zero_cost_cap,endtime)
    supply_curves = Dict()
    supply_curves_incr = Dict()
    supply_curves_incr_minus_demand = Dict()
    supply_curves[0] = zero_cost_prod
    supply_curves_incr[0] = zero_cost_prod
    supply_curves_incr_minus_demand[0] = zero_cost_prod - [m.ext[:timeseries][:demand][c][t] for t in 1:endtime]
    prev_price = 0 
    for production_price in sort(collect(keys(static_non_zero_cost_cap)))
        supply_curves[production_price] = [static_non_zero_cost_cap[production_price] for t in 1:endtime]
        supply_curves_incr[production_price] = supply_curves_incr[prev_price] + [static_non_zero_cost_cap[production_price] for t in 1:endtime]
        supply_curves_incr_minus_demand[production_price] = supply_curves_incr_minus_demand[prev_price] + [static_non_zero_cost_cap[production_price] for t in 1:endtime]
        prev_price = production_price
    end
    return supply_curves,supply_curves_incr, supply_curves_incr_minus_demand
end

# function get_trade_availabilities_from_supply_curves(m,c,supply_curves,supply_curves_incr,supply_curves_incr_minus_demand)
#     import_availability = Dict()
#     export_availability = Dict()
    
#     for production_price in sort!(collect(keys(supply_curves)))
#         import_availability[production_price] = zeros(endtime)
#         export_availability[production_price] = zeros(endtime)
#         for t in 1:endtime
#             prev_was_export = true
#             if supply_curves_incr_minus_demand[production_price][t] <=0 
#                 ##As long as this is the case, the neighboring country does noet have enough capacity at this price to meet demand and will be willing to import 
#                 export_availability[production_price][t] = supply_curves[production_price][t]
#                 diff_dem = supply_curves_incr[production_price][t] - m.ext[:timeseries][:demand][c][t]
#             elseif supply_curves_incr_minus_demand[production_price][t] >=0
#                 ## In this case, the neighobring country has an excess at this price and is willing to export
#                 if !prev_was_export
#                     #This is the case where we are considering the marginal production price in the neighboring country
#                     #Part of the 
#                     export_availability[production_price][t] = diff_dem
#                     import_availability[production_price][t] = supply_curves[production_price][t] - diff_dem
    
#                     prev_was_export = false
#                 else
#                     import_availability[production_price][t] = supply_curves[production_price][t]
#                 end
#             end
#         end
#     end
#     return import_availability,export_availability
# end

# function get_per_country_trade_availability(m)
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

function get_trade_availabilities_from_supply_curves(m,c,supply_curves,supply_curves_incr,supply_curves_incr_minus_demand,endtime)
    import_availability = Dict()
    export_availability = Dict()
    demand = m.ext[:timeseries][:demand][c]
    diff_dem = [demand[t] for t in 1:endtime]

    for production_price in sort!(collect(keys(supply_curves)))
        println(production_price)
        import_availability[production_price] = zeros(endtime)
        export_availability[production_price] = zeros(endtime)
        for t in 1:endtime
            if supply_curves_incr_minus_demand[production_price][t] <=0
                ##As long as this is the case, the neighboring country does noet have enough capacity at this price to meet demand and will not be able to export
                import_availability[production_price][t] = 0
                #At the same time, the country will be willing to pay the same price as at home for this energy
                export_availability[production_price][t] = supply_curves[production_price][t]

                #We set the diff_dem parameter to the difference between the total production up to this price, and the demand
                diff_dem[t] = demand[t] - supply_curves_incr[production_price][t]

            elseif supply_curves_incr_minus_demand[production_price][t] >=0
                ## In this case, the neighobring country has an excess at this price and is willing to export
                export_availability[production_price][t] = diff_dem[t]

                import_availability[production_price][t] = supply_curves[production_price][t] - diff_dem[t]
                diff_dem[t] = 0 
            end
           
        end
    end

    return import_availability,export_availability
end
function get_per_country_trade_availability(m,simplified,country,endtime,VOLL)
    import_availabilities = Dict()
    export_availabilities = Dict()

    for neighbor in m.ext[:sets][:connections][country] 
        zero_cost_prod,nb_tech_zero_prod = get_zero_cost_prod(m,neighbor,endtime)
        static_non_zero_cost_cap,nb_tech_static = get_static_nonzero_cost_cap(m,neighbor,VOLL)
        supply_curves,supply_curves_incr, supply_curves_incr_minus_demand = get_supply_curves(m,neighbor,zero_cost_prod,static_non_zero_cost_cap,endtime)
        import_availabilities[neighbor],export_availabilities[neighbor] = get_trade_availabilities_from_supply_curves(m,neighbor,supply_curves,supply_curves_incr,supply_curves_incr_minus_demand,endtime)
    if !simplified
        nb_pure_storage = length(m.ext[:sets][:pure_storage_technologies][neighbor])
        @assert(nb_pure_storage + nb_tech_static + nb_tech_zero_prod == length(m.ext[:sets][:technologies][neighbor]))
    else
        @assert(nb_tech_static + nb_tech_zero_prod == length(m.ext[:sets][:technologies][neighbor]))
    end

    end
    return import_availabilities,export_availabilities
end