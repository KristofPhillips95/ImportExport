include("../ImportExport/cost_curves_builder.jl")
include("../ImportExport/build_and_save_cost_curves.jl")
import JSON3

#Define global parameters
gpd = Dict()
gpd["endtime"] = 2
gpd["Climate_year"] = 1984
gpd["Climate_year_ts"] = 2012
gpd["ValOfLostLoad"] = 8000
gpd["country"] = "BE00"
gpd["scenario"] = "National Trends"
gpd["year"] = 2025
gpd["stepsize"] = 100
gpd["transport_price"] = 0.1
gpd["simplified"] = true
gpd["target_cap_for_curves"] = "0"
gpd["disc_rate"] = 0.07
gpd["geo_scope"] = ["BE00", "UK00"]

curve_dict = Dict()
import_dict = Dict()
export_dict = Dict()

stepsize = 100

import_levels = -1000:stepsize:1000

if !(gpd["simplified"])
    #Optimize dispatch model with given capacities from input data
    m,soc,production =  optimize_and_retain_intertemporal_decisions(gpd)
    save_intertemporal_decisions(soc,production,gpd)
    # Load the soc and production levels of dispatch model
    soc_dict = JSON3.read(read(joinpath("Results","soc_files","soc_$(gpd["year"])_$(gpd["Climate_year_ts"])_$(gpd["scenario"])_$(gpd["endtime"])_s_$(gpd["simplified"])_tc_$(gpd["target_cap_for_curves"]).json"), String))
    production_dict = JSON3.read(read(joinpath("Results","soc_files","prod_$(gpd["year"])_$(gpd["Climate_year_ts"])_$(gpd["scenario"])_$(gpd["endtime"])_s_$(gpd["simplified"])_tc_$(gpd["target_cap_for_curves"]).json"), String))
else
    soc = nothing
    production = nothing
end

country = "BE00"
tech = "Battery"
# soc[country,tech,1]
# soc[country,tech,2]
# soc[country,tech,3]
#Test equality of soc and production dict

m2 = build_model_for_import_curve(0,soc,production,gpd)
#Test the model
# optimize!(m2)
# m2.ext[:constraints][:soc_fixed]
# m2.ext[:constraints][:soc_fixed]["DE00","PS_C",1]


#m3 = build_model_for_import_curve_from_dict(0,soc_dict,production_dict,gpd)



for import_level in import_levels
    country_fail = "DE00"
    country = gpd["country"]
    endtime = gpd["endtime"]
    simplified = gpd["simplified"]
    change_import_level!(m2,endtime,import_level,country)
    #change_import_level!(m3,endtime,import_level,country)

    optimize!(m2)
    #optimize!(m3)

    check_production_zero!(m2,country,endtime)
    check_net_import(m2,country,import_level,endtime,simplified)

    # check_production_zero!(m2,country_fail,endtime)
    # check_net_import(m2,country_fail,import_level,endtime)

    #check_production_zero!(m3,country,endtime)
   # check_net_import(m3,country,import_level,endtime,simplified)

    #check_equal_soc_for_all_but(m,m2,country,endtime)
    #check_equal_soc_for_all_but(m3,m2,country,endtime)

    #TODO: Check why this one does not fail the assertion 
    #check_equal_soc_for_all_but(m3,m2,country_fail,endtime)
    println(JuMP.objective_value(m2))
   # println(JuMP.objective_value(m3) - JuMP.objective_value(m2))
    #@assert(round(JuMP.objective_value(m2),digits = 0) == round(JuMP.objective_value(m3),digits = 0))

    import_prices = [JuMP.dual.(m2.ext[:constraints][:demand_met][country,t]) for t in 1:endtime]
    curve_dict[import_level] = import_prices

    import_dict[import_level] = [sum(JuMP.value.(m2.ext[:variables][:import][country,nb,t]) for nb in m2.ext[:sets][:connections][country]) for t in 1:endtime]
    export_dict[import_level] = [sum(JuMP.value.(m2.ext[:variables][:export][country,nb,t]) for nb in m2.ext[:sets][:connections][country]) for t in 1:endtime]
    end


write_prices(curve_dict,import_levels,gpd)

country = gpd["country"]
endtime = gpd["endtime"]
net_import = [sum(JuMP.value.(m.ext[:variables][:import][country,nb,t]) - JuMP.value.(m.ext[:variables][:export][country,nb,t]) for nb in m.ext[:sets][:connections][country]) for t in 1:endtime]

# import_dict[1000]
# export_dict[1000]
# m2.ext[:objective]

m2.ext[:constraints]