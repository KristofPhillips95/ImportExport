include("model_builder.jl")
include("curve_based_model_builder.jl")
include("helper_inspection.jl")

function full_build_and_optimize_investment_model(m::Model ; global_param_dict:: Dict)
    endtime = global_param_dict["endtime"]
    CY = global_param_dict["Climate_year"]
    CY_ts = global_param_dict["Climate_year_ts"]
    VOLL = global_param_dict["ValOfLostLoad"]
    transp_cost = global_param_dict["transport_price"]
    country = global_param_dict["country"]
    scenario = global_param_dict["scenario"]
    year = global_param_dict["year"]
    type = global_param_dict["type"]
    simplified = global_param_dict["simplified"]
    target_cap_for_curves = global_param_dict["target_cap_for_curves"]
    disc_rate = global_param_dict["disc_rate"]
    stepsize = global_param_dict["stepsize"]
    geo_scope = global_param_dict["geo_scope"]
    geo_scope_str = join(geo_scope, "_")
    
    timer_dict = Dict()

    m = full_build_and_return_investment_model(m,global_param_dict=global_param_dict,timer_dict=timer_dict)
    # define_sets!(m,scenario,year,CY,[],[country],simplified)
    # if type == "isolated"
    #     build_isolated!(m,endtime,scenario,year,CY,CY_ts,country,VOLL,disc_rate,simplified)
    # elseif type == "NTC"
    #     build_NTC!(m,endtime,scenario,year,CY,CY_ts,country,VOLL,transp_cost,disc_rate,simplified,geo_scope)
    # elseif type =="TradeCurves"
    #     build_with_trade_curves!(m,endtime,scenario,year,CY,CY_ts,country,VOLL,0,disc_rate,simplified,target_cap_for_curves,stepsize,geo_scope)
    # end

    t_start_solve = time()
    optimize!(m)
    timer_dict["time_solve"] = time()-t_start_solve
    # print("Belgium isolated = ",isolated, JuMP.value.(m.ext[:variables][:invested_cap]))
    peak_dem = maximum(m.ext[:timeseries][:demand][country][1:endtime])
    demand = sum(m.ext[:timeseries][:demand][country][1:endtime])
    production = sum(JuMP.value.(m.ext[:variables][:production][country,tech,t]) for tech in m.ext[:sets][:technologies][country] for t in 1:endtime)
    water_dumping = sum(JuMP.value.(m.ext[:variables][:water_dumping][country,tech,t]) for tech in m.ext[:sets][:hydro_flow_technologies][country] for t in 1:endtime)
    if type == "NTC"
        nb_techs_neighbors = sum(length(m.ext[:sets][:technologies][neighbor]) for neighbor in m.ext[:sets][:connections][country])
    else
        nb_techs_neighbors = 0
    end
    if !(simplified)
        charge = sum(JuMP.value.(m.ext[:variables][:charge][country,tech,t]) for tech in m.ext[:sets][:storage_technologies][country] for t in 1:endtime)
    else
        charge = 0 
    end
    if type == "isolated" 
        imported = 0
        exported = 0
    elseif type == "TCS" || type == "TCPC"
        imported = sum(JuMP.value.(m.ext[:variables][:import]))
        exported = sum(JuMP.value.(m.ext[:variables][:export]))
    elseif type == "NTC"
        imported = sum([sum(JuMP.value.(m.ext[:variables][:import][country,neighbor,t] for neighbor in m.ext[:sets][:connections][country])) for t in 1:endtime])
        exported = sum([sum(JuMP.value.(m.ext[:variables][:export][country,neighbor,t] for neighbor in m.ext[:sets][:connections][country])) for t in 1:endtime])
    end
    production = get_production_summed(m,country,endtime)
    row = DataFrame(
        "scenario" => scenario,
        "end" => endtime,
        "year" => year,
        "CY" => CY,
        "CY_ts" => CY_ts,
        "VOLL" => VOLL,
        "type" => type,
        "simplified" => simplified,
        "target_cap_for_curves" => target_cap_for_curves,
        "stepsize" => stepsize,
        "geoscope" =>geo_scope_str,
        "trans_cap_other" => gpd["trans_cap_other"],
        "CO2_cost"=>sum(JuMP.value.(m.ext[:expressions][:CO2_cost][country,tech,t] for tech in m.ext[:sets][:dispatchable_technologies][country] for t in 1:endtime)),
        "load_shedding_cost"=>sum(JuMP.value.(m.ext[:expressions][:load_shedding_cost][country,t] for t in 1:endtime)),
        "VOM_cost"=>sum(JuMP.value.(m.ext[:expressions][:VOM_cost][country,tech,t] for tech in m.ext[:sets][:technologies][country] for t in 1:endtime)),
        "fuel_cost"=>sum(JuMP.value.(m.ext[:expressions][:fuel_cost][country,tech,t] for tech in m.ext[:sets][:dispatchable_technologies][country] for t in 1:endtime)),
        "investment_cost"=>sum(JuMP.value.(m.ext[:expressions][:investment_cost][country,tech] for tech in m.ext[:sets][:investment_technologies][country])),
        "CCGT"=> JuMP.value.(m.ext[:variables][:invested_cap][country,"CCGT"]),
        "OCGT"=> JuMP.value.(m.ext[:variables][:invested_cap][country,"OCGT"]),
        "PV"=> JuMP.value.(m.ext[:variables][:invested_cap][country,"PV"]),
        "w_on"=> JuMP.value.(m.ext[:variables][:invested_cap][country,"w_on"]),
        "w_off"=> JuMP.value.(m.ext[:variables][:invested_cap][country,"w_off"]),
        "CCGT_prod"=> production["CCGT"],
        "OCGT_prod"=> production["OCGT"],
        "PV_prod"=> production["PV"],
        "w_on_prod"=> production["w_on"],
        "w_off_prod"=> production["w_off"],
        "imported" => imported,
        "exported" => exported,
        "demand" => demand,
        "peak_demand" => peak_dem,
        "nb_techs_neighbours"=> nb_techs_neighbors,
        # "total_prod" => production,
        "time_solve" => timer_dict["time_solve"],
        "time_build" => timer_dict["time_build"],
        "time_TC" => timer_dict["time_TC"],
    )
    return row
end

function build_isolated!(m,endtime,scenario,year,CY,CY_ts,country,VOLL,disc_rate,simplified)
    #We start by redefining the sets here, to remove unnecessary countries. 
    all_countries = get_all_countries(scenario,year,CY)
    define_sets!(m,scenario,year,CY,filter((e->e != country),all_countries),[country],simplified)
    process_parameters!(m,scenario,year,CY,[country],simplified)
    process_time_series!(m,scenario,year,CY_ts,simplified)
    remove_capacity_country!(m,country)
    build_isolated_investment_model!(m,endtime,VOLL,disc_rate,simplified)
end

function build_NTC!(m,endtime,scenario,year,CY,CY_ts,country,VOLL,transp_cost,disc_rate,simplified,geo_scope,trans_cap_other)
    # @show(simplified,"In Build_NTC!()")
    c_excluded = get_list_of_excluded(geo_scope,scenario,year,CY)
    define_sets!(m,scenario,year,CY,c_excluded,[country],simplified)
    process_parameters!(m,scenario,year,CY,[country],simplified)
    process_time_series!(m,scenario,year,CY_ts,simplified,endtime)
    remove_capacity_country!(m,country)
    if !(trans_cap_other == "S")
        update_transfer_caps_of_non_focus(m,trans_cap_other,country)
    end
    build_NTC_investment_model!(m,endtime,VOLL,transp_cost,disc_rate,simplified)
end

function build_with_trade_curves!(m,gpd,endtime,scenario,year,CY,CY_ts,country,VOLL,transport_price,disc_rate,simplified,type,target_cap_for_curves,stepsize,geo_scope,timer_dict)
    #We start by redefining the sets here, to remove unnecessary countries. 
    t_start_build = time()
    all_countries = get_all_countries(scenario,year,CY)
    define_sets!(m,scenario,year,CY,filter((e->e != country),all_countries),[country],simplified)
    process_parameters!(m,scenario,year,CY,[country],simplified)
    process_time_series!(m,scenario,year,CY_ts,simplified,endtime)
    remove_capacity_country!(m,country)

    #Obtain trade availability ts 
    # file_name_ext = "$(country)_$(year)_CY_$(CY_ts)_$(endtime)"
    # path = joinpath("Results","TradeCurves","import_price_curves$(scenario)_$(file_name_ext).csv")
    # trade_curves = CSV.read(path,DataFrame)

    if type == "TCS"
        t_start_TC = time()
        build_and_save_cost_curves(gpd = gpd)
        timer_dict["time_TC"] = time()-t_start_TC
        t_start_build_2 = time()
        trade_curves = read_prices(scenario,year,CY_ts,endtime,simplified,country,target_cap_for_curves,geo_scope,stepsize)
        add_availability_curves_to_model!(m,trade_curves)
        build_single_trade_curve_investment_model!(m,endtime,VOLL,0,disc_rate,simplified)
        timer_dict["time_build"] = time() -t_start_build_2
        #timer_dict["time_build"] = time() - t_start_build - timer_dict["time_TC"]

    elseif type == "TCPC"
        t_start_TC = time()
        m_for_curves = initialize_and_build_model_to_obtain_curves_per_country(endtime,country,scenario,year,CY,CY_ts,simplified,geo_scope)
        import_availabilities,export_availabilities = get_per_country_trade_availability(m_for_curves,gpd["simplified"],country,endtime,VOLL)
        import_lims,export_lims = get_per_country_trade_limits(m_for_curves,country)
        timer_dict["time_TC"] = time()-t_start_TC

        add_per_country_availability_curves_to_model!(m,import_availabilities,export_availabilities,import_lims,export_lims)
        build_per_country_trade_curve_investment_model!(m,endtime,VOLL,transport_price,disc_rate,simplified)
        timer_dict["time_build"] = time() - t_start_build - timer_dict["time_TC"]
    else
        error("Type: ",type," not implemented")
    end

end

function full_build_and_return_investment_model(m::Model ; global_param_dict:: Dict,timer_dict::Dict)
    endtime = global_param_dict["endtime"]
    CY = global_param_dict["Climate_year"]
    CY_ts = global_param_dict["Climate_year_ts"]
    VOLL = global_param_dict["ValOfLostLoad"]
    transp_price = global_param_dict["transport_price"]
    country = global_param_dict["country"]
    scenario = global_param_dict["scenario"]
    year = global_param_dict["year"]
    type = global_param_dict["type"]
    simplified = global_param_dict["simplified"]
    disc_rate = global_param_dict["disc_rate"]
    stepsize = global_param_dict["stepsize"]
    geo_scope = global_param_dict["geo_scope"]
   
    define_sets!(m,scenario,year,CY,[],[country],simplified)
    if type == "isolated"
        t_start_build =  time()
        build_isolated!(m,endtime,scenario,year,CY,CY_ts,country,VOLL,disc_rate,simplified)
        timer_dict["time_build"] = time()-t_start_build
        timer_dict["time_TC"] = 0
    elseif type == "NTC"
        t_start_build =  time()
        trans_cap_other = global_param_dict["trans_cap_other"]
        build_NTC!(m,endtime,scenario,year,CY,CY_ts,country,VOLL,transp_price,disc_rate,simplified,geo_scope,trans_cap_other)
        timer_dict["time_build"] = time()-t_start_build
        timer_dict["time_TC"] = 0
    elseif type in ["TCPC","TCS"]
        target_cap_for_curves = global_param_dict["target_cap_for_curves"]
        build_with_trade_curves!(m,global_param_dict,endtime,scenario,year,CY,CY_ts,country,VOLL,transp_price,disc_rate,simplified,type,target_cap_for_curves,stepsize,geo_scope,timer_dict)
    else
        error("Type: ",type," not implemented")
    end
    return m
end