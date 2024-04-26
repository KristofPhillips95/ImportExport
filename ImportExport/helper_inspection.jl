function get_investment_costs_c(m,country)
    return Dict(tech => JuMP.value.(m.ext[:expressions][:investment_cost][country,tech]) for tech in m.ext[:sets][:investment_technologies][country])
 end

 function get_VOM_costs_c(m,country)
     return Dict(tech => [JuMP.value.(m.ext[:expressions][:VOM_cost][country,tech,t]) for t in 1:endtime] for tech in m.ext[:sets][:technologies][country] )
 end

 function get_fuel_costs_c(m,country)
     return Dict(tech => [JuMP.value.(m.ext[:expressions][:fuel_cost][country,tech,t]) for t in 1:endtime] for tech in m.ext[:sets][:dispatchable_technologies][country])
 end

 function get_CO2_costs_c(m,country)
     return Dict(tech => [JuMP.value.(m.ext[:expressions][:CO2_cost][country,tech,t]) for t in 1:endtime] for tech in m.ext[:sets][:dispatchable_technologies][country])
 end

 function get_load_shedding_costs_c(m,country)
     return Dict(t => JuMP.value.(m.ext[:expressions][:load_shedding_cost][country,t]) for t in 1:endtime)
 end

 function get_production(m,country,endtime)
    return Dict(tech => [JuMP.value.(m.ext[:variables][:production][country,tech,t]) for t in 1:endtime] for tech in m.ext[:sets][:technologies][country] )
end

function get_curtailment(m,country,endtime)
    return [JuMP.value.(m.ext[:variables][:curtailment][country,t]) for t in 1:endtime]
end

function get_curtailment_summed(m,country,endtime)
    return sum([JuMP.value.(m.ext[:variables][:curtailment][country,t]) for t in 1:endtime])
end

function get_production_summed(m,country,endtime)
    return Dict(tech => sum([JuMP.value.(m.ext[:variables][:production][country,tech,t]) for t in 1:endtime]) for tech in m.ext[:sets][:technologies][country] )
end

function get_import_and_export(m,country,model_type)
    timesteps = collect(1:length(m.ext[:timeseries][:demand][country]))
    pc_imports_and_exports = get_pc_import_and_export(m,country,model_type)
    import_ = [sum(pc_imports_and_exports[1][nb][t] for nb in keys(pc_imports_and_exports[1])) for t in timesteps]
    export_ = [sum(pc_imports_and_exports[2][nb][t] for nb in keys(pc_imports_and_exports[2])) for t in timesteps]

    return import_,export_
end

function get_net_import_and_export(m,country,model_type)
    timesteps = collect(1:length(m.ext[:timeseries][:demand][country]))
    if model_type == "NTC"
        import_ = [sum(JuMP.value.(m.ext[:variables][:import][country,neighbor,t] for neighbor in m.ext[:sets][:connections][country])) for t in timesteps]
        export_ = [sum(JuMP.value.(m.ext[:variables][:export][country,neighbor,t] for neighbor in m.ext[:sets][:connections][country])) for t in timesteps]
    elseif model_type == "TCS"
        trade_prices = m.ext[:sets][:trade_prices]
        import_ = [JuMP.value.(sum(m.ext[:variables][:import][country,p,t] for p in trade_prices)) for t in timesteps]
        export_ = [JuMP.value.(sum(m.ext[:variables][:export][country,p,t] for p in trade_prices)) for t in timesteps]
    elseif model_type == "TCPC"
        trade_prices = m.ext[:sets][:trade_prices]
        import_ = [JuMP.value.(sum(m.ext[:variables][:import][country,nb,p,t] for nb in m.ext[:sets][:neighbors] for p in trade_prices[nb])) for t in timesteps]
        export_ = [JuMP.value.(sum(m.ext[:variables][:export][country,nb,p,t] for nb in m.ext[:sets][:neighbors] for p in trade_prices[nb])) for t in timesteps]
    else
        error("Model type: ",model_type," not implemented")
    end
    return import_,export_
end

function get_pc_import_and_export(m,country,model_type,soc = nothing,production=nothing)
    timesteps = collect(1:length(m.ext[:timeseries][:demand][country]))
    if model_type == "NTC"
        import_ = Dict(neighbor => [JuMP.value.(m.ext[:variables][:import][country,neighbor,t]) for t in timesteps] for neighbor in m.ext[:sets][:connections][country])
        export_ = Dict(neighbor => [JuMP.value.(m.ext[:variables][:export][country,neighbor,t]) for t in timesteps] for neighbor in m.ext[:sets][:connections][country])
        m_dp = nothing
    # elseif model_type == "TCS"
    #     trade_prices = m.ext[:sets][:trade_prices]
    #     import_ = [JuMP.value.(sum(m.ext[:variables][:import][country,p,t] for p in trade_prices)) for t in timesteps]
    #     export_ = [JuMP.value.(sum(m.ext[:variables][:export][country,p,t] for p in trade_prices)) for t in timesteps]
    elseif model_type == "TCPC"
        trade_prices = m.ext[:sets][:trade_prices]
        import_ = Dict(nb => [sum(JuMP.value.(m.ext[:variables][:import][country,nb,p,t]) for p in trade_prices[nb]) for t in timesteps] for nb in m.ext[:sets][:neighbors])
        export_ = Dict(nb => [sum(JuMP.value.(m.ext[:variables][:export][country,nb,p,t]) for p in trade_prices[nb]) for t in timesteps] for nb in m.ext[:sets][:neighbors])
        m_dp = nothing
    elseif model_type == "TCS"
        import_,export_ = get_net_import_and_export(m,country,model_type)
        net_import_profile = import_-export_
        println("Solving auxiliary model for congestion rents")
        m_dp = build_model_for_import_curve(0,soc,production,gpd)
        change_import_level_t!(m_dp,net_import_profile,country)
        optimize!(m_dp)
        import_,export_ = get_pc_import_and_export(m_dp,country,"NTC")
    else
        error("Model type: ",model_type," not implemented")
    end
    return import_,export_,m_dp
end

function get_pc_pp_import_and_export(m,country,model_type)
    timesteps = collect(1:length(m.ext[:timeseries][:demand][country]))

    if model_type == "TCPC"
        trade_prices = m.ext[:sets][:trade_prices]
        import_ = Dict(nb => Dict(p=> JuMP.value.([m.ext[:variables][:import][country,nb,p,t] for t in timesteps]) for p in trade_prices[nb]) for nb in m.ext[:sets][:neighbors])
        export_ = Dict(nb => Dict(p=> JuMP.value.([m.ext[:variables][:export][country,nb,p,t] for t in timesteps]) for p in trade_prices[nb]) for nb in m.ext[:sets][:neighbors])
    end
    return import_,export_
end

function get_pc_import_and_export_price(m,country,model_type)
    timesteps = collect(1:length(m.ext[:timeseries][:demand][country]))
    if model_type == "NTC"
        import_p = Dict(neighbor => [JuMP.dual.(m.ext[:constraints][:export_import][country,neighbor,t]) + JuMP.dual.(m.ext[:constraints][:import][country,neighbor,t]) for t in timesteps] for neighbor in m.ext[:sets][:connections][country])
        export_p = Dict(neighbor => [JuMP.dual.(m.ext[:constraints][:export_import][country,neighbor,t]) - JuMP.dual.(m.ext[:constraints][:import][neighbor,country,t]) for t in timesteps] for neighbor in m.ext[:sets][:connections][country])
    # elseif model_type == "TCS"
    #     trade_prices = m.ext[:sets][:trade_prices]
    #     import_ = [JuMP.value.(sum(m.ext[:variables][:import][country,p,t] for p in trade_prices)) for t in timesteps]
    #     export_ = [JuMP.value.(sum(m.ext[:variables][:export][country,p,t] for p in trade_prices)) for t in timesteps]
    elseif model_type == "TCPC"
        trade_prices = m.ext[:sets][:trade_prices]
        import_pc,export_pc = get_pc_pp_import_and_export(m,country,"TCPC")

        import_p = get_pc_trade_price(import_pc,"i",gpd["transport_price"])
        export_p= get_pc_trade_price(export_pc,"e",gpd["transport_price"])
    else
        error("Model type: ",model_type," not implemented")
    end
    return import_p,export_p
end


function get_pc_trade_price(trade_v,type,transport_price)
    prices_dict = Dict()
    for country in keys(trade_v)
        prices_dict[country] = get_sc_trade_price(trade_v[country],type,transport_price)
    end
    return prices_dict
end

function get_sc_trade_price(trade_v_c,type,transport_price)
    prices = []
    for t in 1:length(trade_v_c[0])
        price = 0 
        for p in keys(trade_v_c)
            if trade_v_c[p][t] > 0
                if type == "i"
                    price = p + transport_price
                else
                    price = p - transport_price
                end
            end
        end
        append!(prices,price)
    end
    return prices
end


function get_trade_cost(trade_v,trade_p)
    trade_cost = Dict()
    for nb in keys(trade_v)
        trade_cost[nb] = trade_v[nb].*trade_p[nb]
    end
    return trade_cost
end


function get_total_trade_costs(m,country,type)
    if type in ["TCPC","NTC"]
        import_v, export_v = get_pc_import_and_export(m,country,type)
        import_p,export_p = get_pc_import_and_export_price(m,country,type)

    elseif type =="TCS"
        import_,export_ = get_import_and_export(m,country,"TCS")
        net_import_profile = import_-export_
        m_dp = build_model_for_import_curve(0,nothing,nothing,gpd)
        change_import_level_t!(m_dp,net_import_profile,country)
        optimize!(m_dp)

        import_v, export_v = get_pc_import_and_export(m_dp,country,"NTC")
        import_p,export_p = get_pc_import_and_export_price(m_dp,country,"NTC")
    else
        error("Model type: ",type," not implemented")
    end
    tic = sum(sum(get_trade_cost(import_v,import_p)[neighbor]) for neighbor in keys(import_v))
    tec = sum(sum(get_trade_cost(export_v,export_p)[neighbor]) for neighbor in keys(export_v))
    return tic,tec
end

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
function get_export_revenue(m,country,type)
    export_rev = Dict()
    
    timesteps = collect(1:length(m.ext[:timeseries][:demand][country]))
    local_price_t = [JuMP.dual.(m.ext[:constraints][:demand_met][country, t]) for t in timesteps]
    per_neighbor_export = get_pc_import_and_export(m,country,type)[2]
    
    for neighbor in keys(per_neighbor_export)
        export_rev[neighbor] = per_neighbor_export[neighbor] .* local_price_t
    end
    return export_rev
end

function get_import_cost_and_export_revenue(m,country,type)
    import_cost = Dict()
    export_rev = Dict()
    
    timesteps = collect(1:length(m.ext[:timeseries][:demand][country]))
    local_price_t = [JuMP.dual.(m.ext[:constraints][:demand_met][country, t]) for t in timesteps]
    per_neighbor_import,per_neighbor_export,m_dp = get_pc_import_and_export(m,country,type)
    

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
    # print(local_price_t)

    neighbor_price_t = get_neighbor_price(m,country,type,m_dp)

    cr_i = Dict()
    cr_e = Dict()

    for neighbor in keys(per_neighbor_import)
        cr_i[neighbor] = per_neighbor_import[neighbor] .* (local_price_t .- neighbor_price_t[neighbor])
        cr_e[neighbor] = per_neighbor_export[neighbor] .* (neighbor_price_t[neighbor] .- local_price_t)
    end

    return cr_i,cr_e
end
function get_neighbor_price(m,country,type,m_dp)
    timesteps = collect(1:length(m.ext[:timeseries][:demand][country]))
    if type == "NTC"
        neighbor_price_t = Dict(neighbor => [JuMP.dual.(m.ext[:constraints][:demand_met][neighbor, t]) for t in timesteps] for neighbor in m.ext[:sets][:connections][country])
        # println(type)
        # println(neighbor_price_t)
    
    elseif type == "TCPC"
        import_pc,export_pc = get_pc_pp_import_and_export(m,country,"TCPC")
        neighbor_price_t_imp = get_pc_trade_price(import_pc,"i",0)
        neighbor_price_t_exp = get_pc_trade_price(export_pc,"e",0)
        # println(neighbor_price_t_exp)
        # println(neighbor_price_t_imp)

        neighbor_price_t = Dict(neighbor=> [max(neighbor_price_t_imp[neighbor][i], neighbor_price_t_exp[neighbor][i]) for i in 1:length(neighbor_price_t_exp[neighbor])] for neighbor in keys(neighbor_price_t_exp))
        # println(type)
        # println(neighbor_price_t)
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
        # println(type)
        # println(neighbor_price_t)
    else
        error("Model type: ",model_type," not implemented")
    end
end

function get_total_trade_costs_and_rents(m,country,type)

    imp_c,exp_c = get_import_cost_and_export_revenue(m,country,type)

    cong_r_i,cong_r_e = get_congestion_rents(m,country,type)

    tic = sum(sum(imp_c[neighbor]) for neighbor in keys(imp_c))
    tec = sum(sum(exp_c[neighbor]) for neighbor in keys(exp_c))

    tri = sum(sum(cong_r_i[neighbor]) for neighbor in keys(cong_r_i))
    tre = sum(sum(cong_r_e[neighbor]) for neighbor in keys(cong_r_e))

    return tic,tec,tri,tre
end