include("model_builder.jl")

function price_curves_to_availability_curves(curves)
    # Firs, extract all unique prices: 
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
    
    for this_price in prices_sorted
        counts_per_row[this_price] = []
        import_available[this_price] = []
        export_available[this_price] = []
        for (curves_row,import_row,export_row) in zip(eachrow(curves),eachrow(import_columns),eachrow(export_columns))
            count = sum(skipmissing(curves_row) .== this_price)
            push!(counts_per_row[this_price], count)
            count_import = sum(skipmissing(import_row) .== this_price)
            push!(import_available[this_price], count_import*trade_level_step)
            count_export = sum(skipmissing(export_row) .== this_price)
            # if ! (this_price==0)
            #     push!(export_available[this_price], count_export*trade_level_step)
            # else
            #     push!(export_available[this_price], 0)
            # end
            push!(export_available[this_price], count_export*trade_level_step)

        end
    end
    return import_available,export_available
end

function add_availability_curves_to_model!(m,curves)
    import_availability,export_availability = price_curves_to_availability_curves(curves)
    all_prices = sort(collect(keys(import_availability)))

    #Add price leves to sets 
    m.ext[:sets][:trade_prices] = all_prices
    #Add timeseries of each price_level to timeseries
    m.ext[:timeseries][:trade] = Dict()
    m.ext[:timeseries][:trade][:import] = import_availability
    m.ext[:timeseries][:trade][:export] = export_availability
end

function build_single_trade_curve_investment_model!(m::Model,endtime,VOLL,transport_price,disc_rate,simplified)
    build_base_investment_model_v2!(m,endtime,VOLL,disc_rate,simplified)

    countries = m.ext[:sets][:countries]
    timesteps = 1:endtime

    trade_prices = m.ext[:sets][:trade_prices]

    total_production_timestep = m.ext[:expressions][:total_production_timestep]
    load_shedding = m.ext[:variables][:load_shedding]
    curtailment = m.ext[:variables][:curtailment]

    if !(simplified)
        storage_technologies = m.ext[:sets][:storage_technologies]
        charge = m.ext[:variables][:charge]
    end

    VOM_cost = m.ext[:expressions][:VOM_cost]
    fuel_cost = m.ext[:expressions][:fuel_cost]
    load_shedding_cost = m.ext[:expressions][:load_shedding_cost]
    CO2_cost = m.ext[:expressions][:CO2_cost]
    investment_cost = m.ext[:expressions][:investment_cost]


    demand = m.ext[:timeseries][:demand]
    import_availability = m.ext[:timeseries][:trade][:import]
    export_availability = m.ext[:timeseries][:trade][:export]


    #Variables for import and export 
    import_v = m.ext[:variables][:import]  = @variable(m,[c= countries, p=trade_prices,time=timesteps],base_name = "import_v")
    export_v = m.ext[:variables][:export]  = @variable(m,[c= countries, p=trade_prices,time=timesteps],base_name = "export_v")

    #Add expression representing cost of import and export 
    
    
    trade_premium = m.ext[:expressions][:trade_cost] =
    @expression(m, [c = countries, p = trade_prices, time = timesteps],
    import_v[c,p,time]*transport_price + export_v[c,p,time]*transport_price
    )

    import_cost = m.ext[:expressions][:import_cost] =
    @expression(m, [c = countries, p = trade_prices, time = timesteps],
    import_v[c,p,time]*p
    )
    export_revenue = m.ext[:expressions][:export_revenue] =
    @expression(m, [c = countries, p = trade_prices, time = timesteps],
    export_v[c,p,time]*p
    )


    #Import availability 
    m.ext[:constraints][:import_restrictions] = @constraint(m,[c = countries, p = trade_prices, time = timesteps],
    ##TODO, there is no country index here while it is present in the constraints and vars, bit weird maybe
        0 <= import_v[c,p,time] <= import_availability[p][time]
    )
    #Export availability 
    m.ext[:constraints][:export_restrictions] = @constraint(m,[c = countries, p = trade_prices, time = timesteps],
    ##TODO, there is no country index here while it is present in the constraints and vars, bit weird maybe
        0 <= export_v[c,p,time] <= export_availability[p][time]
    )

    if !(simplified)
        # Demand met for all timesteps
        m.ext[:constraints][:demand_met] = @constraint(m,[c = countries, time = timesteps],
            total_production_timestep[c,time] + load_shedding[c,time] - curtailment[c,time] + sum(import_v[c,p,time] for p in trade_prices)  == demand[c][time] +  sum(export_v[c,p,time] for p in trade_prices)  + sum(charge[c,tech,time] for tech in storage_technologies[c])
        )
    else
        m.ext[:constraints][:demand_met] = @constraint(m,[c = countries, time = timesteps],
        total_production_timestep[c,time] + load_shedding[c,time] - curtailment[c,time] + sum(import_v[c,p,time] for p in trade_prices)  == demand[c][time] +  sum(export_v[c,p,time] for p in trade_prices)
    )
    end

    m.ext[:objective] = @objective(m,Min,sum(investment_cost) + sum(VOM_cost) + sum(CO2_cost) + sum(fuel_cost) + sum(load_shedding_cost) + sum(trade_premium) + sum(import_cost) - sum(export_revenue))
end

function add_per_country_availability_curves_to_model!(m,import_availabilities,export_availabilities,import_lims,export_lims)
    all_prices = Dict()
    for neighbor in keys(import_availabilities)
        prices_this_neighbor = union(sort(collect(keys(import_availabilities[neighbor]))),sort(collect(keys(export_availabilities[neighbor]))))
        #print(prices_this_neighbor)
        all_prices[neighbor] = sort(collect(prices_this_neighbor))
        #print(all_prices)
    end
    #Add price leves to sets 
    m.ext[:sets][:trade_prices] = all_prices
    #Add neighbors to sets
    m.ext[:sets][:neighbors] = collect(keys(import_availabilities))
    #Add line capacities to parameters
    m.ext[:parameters][:import_lims] = import_lims 
    m.ext[:parameters][:export_lims] = export_lims 
    #Add timeseries of each price_level to timeseries
    m.ext[:timeseries][:trade] = Dict()
    m.ext[:timeseries][:trade][:import] = import_availabilities
    m.ext[:timeseries][:trade][:export] = export_availabilities
end

function build_per_country_trade_curve_investment_model!(m::Model,endtime,VOLL,transport_price,disc_rate,simplified)
    build_base_investment_model_v2!(m,endtime,VOLL,disc_rate,simplified)

    countries = m.ext[:sets][:countries]
    timesteps = 1:endtime

    trade_prices = m.ext[:sets][:trade_prices]

    total_production_timestep = m.ext[:expressions][:total_production_timestep]
    load_shedding = m.ext[:variables][:load_shedding]
    curtailment = m.ext[:variables][:curtailment]

    if !(simplified)
        storage_technologies = m.ext[:sets][:storage_technologies]
        charge = m.ext[:variables][:charge]
    end

    VOM_cost = m.ext[:expressions][:VOM_cost]
    fuel_cost = m.ext[:expressions][:fuel_cost]
    load_shedding_cost = m.ext[:expressions][:load_shedding_cost]
    CO2_cost = m.ext[:expressions][:CO2_cost]
    investment_cost = m.ext[:expressions][:investment_cost]


    demand = m.ext[:timeseries][:demand]
    import_availability = m.ext[:timeseries][:trade][:import]
    export_availability = m.ext[:timeseries][:trade][:export]
    neighbors = m.ext[:sets][:neighbors]
    #Variables for import and export 
    import_v = m.ext[:variables][:import]  = @variable(m,[c= countries,n = neighbors, p=trade_prices[n],time=timesteps],base_name = "import_v")
    export_v = m.ext[:variables][:export]  = @variable(m,[c= countries,n=neighbors, p=trade_prices[n],time=timesteps],base_name = "export_v")

    #Add expression representing cost of import and export 
    
    #print(neighbors)
    trade_premium = m.ext[:expressions][:trade_cost] =
    @expression(m, [c = countries,n=neighbors, p = trade_prices[n], time = timesteps],
    import_v[c,n,p,time]*transport_price + export_v[c,n,p,time]*transport_price
    )

    import_cost = m.ext[:expressions][:import_cost] =
    @expression(m, [c = countries,n=neighbors, p = trade_prices[n], time = timesteps],
    import_v[c,n,p,time]*p
    )
    export_revenue = m.ext[:expressions][:export_revenue] =
    @expression(m, [c = countries,n=neighbors, p = trade_prices[n], time = timesteps],
    export_v[c,n,p,time]*p
    )


    #Import availability 
    m.ext[:constraints][:import_restrictions] = @constraint(m,[c = countries, n = neighbors, p = trade_prices[n], time = timesteps],
    ##TODO, there is no country index here while it is present in the constraints and vars, bit weird maybe
        0 <= import_v[c,n,p,time] <= import_availability[n][p][time]
    )
    #Export availability 
    m.ext[:constraints][:export_restrictions] = @constraint(m,[c = countries, n = neighbors, p = trade_prices[n], time = timesteps],
    ##TODO, there is no country index here while it is present in the constraints and vars, bit weird maybe
        0 <= export_v[c,n,p,time] <= export_availability[n][p][time]
    )
    ##TODO: Add transmission line capacity restrictions
    #Export line capacity 
    m.ext[:constraints][:export_line_cap] = @constraint(m,[c = countries, n = neighbors, time = timesteps],
    ##TODO, there is no country index here while it is present in the constraints and vars, bit weird maybe
       sum(export_v[c,n,p,time] for p in trade_prices[n]) <= maximum(m.ext[:parameters][:export_lims][n])
    )
    #Export availability 
    m.ext[:constraints][:import_line_cap] = @constraint(m,[c = countries, n = neighbors, time = timesteps],
    ##TODO, there is no country index here while it is present in the constraints and vars, bit weird maybe
        sum(import_v[c,n,p,time] for  p in trade_prices[n]) <= maximum(m.ext[:parameters][:import_lims][n])
    )

    if !(simplified)
        # Demand met for all timesteps
        m.ext[:constraints][:demand_met] = @constraint(m,[c = countries, time = timesteps],
            total_production_timestep[c,time] + load_shedding[c,time] - curtailment[c,time] + sum(import_v[c,n,p,time] for n in neighbors for p in trade_prices[n])  == demand[c][time] +  sum(export_v[c,n,p,time] for n in neighbors for p in trade_prices[n])  + sum(charge[c,tech,time] for tech in storage_technologies[c])
        )
    else
        m.ext[:constraints][:demand_met] = @constraint(m,[c = countries, time = timesteps],
        total_production_timestep[c,time] + load_shedding[c,time] - curtailment[c,time] + sum(import_v[c,n,p,time] for n in neighbors for p in trade_prices[n])  == demand[c][time] +  sum(export_v[c,n,p,time] for n in neighbors for p in trade_prices[n])
    )
    end

    m.ext[:objective] = @objective(m,Min,sum(investment_cost) + sum(VOM_cost) + sum(CO2_cost) + sum(fuel_cost) + sum(load_shedding_cost) + sum(trade_premium) + sum(import_cost) - sum(export_revenue))
    return m
end