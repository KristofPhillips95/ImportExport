include("cost_curves_builder.jl")
import JSON3

function build_and_save_cost_curves(; gpd::Dict,save_soc = true,save_results = true)
    #Start by extracting some parameters from the global parameter dictionary
    endtime = gpd["endtime"]
    stepsize = gpd["stepsize"]
    simplified = gpd["simplified"]
    country = gpd["country"]

    for i in 1:5
        println("############################################")
    end
    println("##Building dispatch model for trade curves##")
    for i in 1:5
        println("############################################")
    end

    # If we are not working with the simplified model, intertemporal constraints have to be taken care of to prevent issues. 
    if !(simplified) & !(gpd["target_cap_for_curves"]== "no_fix")
        #Optimize dispatch model with given capacities from input data
        m1,soc,production =  optimize_and_retain_intertemporal_decisions(gpd)
        if save_soc
            save_intertemporal_decisions(soc,production,gpd)
        end
        # if save_results
        #     println("Saving model results")
        #     save_model_results(m1,gpd)
        # end
        # # Load the soc and production levels of dispatch model
        # soc_dict = JSON3.read(read(joinpath("Results","soc_files","soc_$(gpd["year"])_$(gpd["Climate_year_ts"])_$(gpd["scenario"])_$(gpd["endtime"])_s_$(gpd["simplified"])_tc_$(gpd["target_cap_for_curves"]).json"), String))
        # production_dict = JSON3.read(read(joinpath("Results","soc_files","prod_$(gpd["year"])_$(gpd["Climate_year_ts"])_$(gpd["scenario"])_$(gpd["endtime"])_s_$(gpd["simplified"])_tc_$(gpd["target_cap_for_curves"]).json"), String))
    else
        soc = nothing
        production = nothing
    end

    

    m = build_model_for_import_curve(0,soc,production,gpd)
    trade_levels = get_trade_levels(m = m, country = country,stepsize = stepsize)


    trade_curve_dict = Dict()

    for trade_level in trade_levels
        for i in 1:2
            println("############################################")
        end
        println(trade_level)
        for i in 1:2
            println("############################################")
        end
        change_import_level!(m,endtime,trade_level,country)
        optimize!(m)
        check_production_zero!(m,country,endtime)
        check_net_import(m,country,trade_level,endtime,simplified)
        import_prices = [JuMP.dual.(m.ext[:constraints][:demand_met][country,t]) for t in 1:endtime]
        trade_curve_dict[trade_level] = import_prices
    
    end
    write_prices(trade_curve_dict,trade_levels,gpd)
end 

function save_intertemporal_decisions(soc,production,global_param_dict)
    endtime = global_param_dict["endtime"]
    CY_ts = global_param_dict["Climate_year_ts"]
    scenario = global_param_dict["scenario"]
    year = global_param_dict["year"]
    target_cap_for_curves = gpd["target_cap_for_curves"]
    simplified = gpd["simplified"]
    country = gpd["country"]
    geo_scope = gpd["geo_scope"]
    #Save the soc and production levels of dispatch model
    geo_scope_str = join(geo_scope, "_")
    open(joinpath("Results","soc_files","soc_$(year)_$(CY_ts)_$(scenario)_$(endtime)_s_$(simplified)_tc_$(country)_$(target_cap_for_curves)_gs_$(geo_scope_str).json"), "w") do io
        JSON3.write(io, write_sparse_axis_to_dict(soc))
    end


    open(joinpath("Results","soc_files","prod_$(year)_$(CY_ts)_$(scenario)_$(endtime)_s_$(simplified)_tc_$(country)_$(target_cap_for_curves)_gs_$(geo_scope_str).json"), "w") do io
        JSON3.write(io, write_sparse_axis_to_dict(production))
    end
end 

function get_trade_levels(; m,country,stepsize = 100)
    cap_import = sum(maximum.(values(m.ext[:parameters][:connections][country])))
    cap_export = sum(maximum.(m.ext[:parameters][:connections][neighbor][country] for neighbor in m.ext[:sets][:connections][country]))

    min_level = floor(cap_export/stepsize)*stepsize
    max_level = floor(cap_import/stepsize)*stepsize
    import_levels  = -min_level:stepsize:max_level
    return import_levels
end

