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

function get_production_summed(m,country,endtime)
    return Dict(tech => sum([JuMP.value.(m.ext[:variables][:production][country,tech,t]) for t in 1:endtime]) for tech in m.ext[:sets][:technologies][country] )
end

function get_import_and_export(m,country,model_type)
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