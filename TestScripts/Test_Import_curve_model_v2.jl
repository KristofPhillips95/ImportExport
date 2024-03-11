include("../ImportExport/build_and_run.jl")
include("../ImportExport/build_and_save_cost_curves.jl")
include("../ImportExport/helper_inspection.jl")
using Plots
gpd = Dict()

endtime = gpd["endtime"] = 24*3
gpd["Climate_year"] = 1984
gpd["Climate_year_ts"] = 2012
gpd["ValOfLostLoad"] = 8000
country = gpd["country"] = "BE00" 
gpd["scenario"] = "National Trends"
gpd["year"] = 2025
gpd["stepsize"] = 100
gpd["transport_price"] = 0.1
gpd["simplified"] = false
gpd["disc_rate"] = 0.07
gpd["geo_scope"] = ["BE00","UK00","FR00"]
gpd["target_cap_for_curves"] = "endo_invest"



#Inspect the models used for import_curves 
# If we are not working with the simplified model, intertemporal constraints have to be taken care of to prevent issues. 
if !(gpd["simplified"])
    #Optimize dispatch model with given capacities from input data
    m1,soc,production =  optimize_and_retain_intertemporal_decisions(gpd)
else
    soc = nothing
    production = nothing
end

# m1 = build_model_for_import_curve(0,soc,production,gpd)

# optimize!(m1)

# plot!(JuMP.value.([ m1.ext[:variables][:water_dumping][test_c,"ROR",t] for t in 1:endtime]))
# plot!(JuMP.value.([ m1.ext[:variables][:production][test_c,"ROR",t] for t in 1:endtime]))
# plot(JuMP.value.([ m1.ext[:variables][:production][test_c,"ROR",t] + m1.ext[:variables][:water_dumping][test_c,"ROR",t] for t in 1:endtime]))

gpd["type"] = "NTC"
m2 = JuMP.Model(Gurobi.Optimizer)
m2 = full_build_and_return_investment_model(m2,global_param_dict= gpd)
optimize!(m2)



test_c = "UK00"
prod_c = get_production(m1,test_c)
prod_cs = sum([prod_c[tech] for tech in keys(prod_c)])
plot(prod_cs,label = "prod m1")

prod_c = get_production(m2,test_c)
prod_cs = sum([prod_c[tech] for tech in keys(prod_c)])
plot!(prod_cs,label = "prod m2")

plot!(get_zero_cost_prod(m1,test_c,endtime)[1],label = "zc m1")
plot!(get_zero_cost_prod(m2,test_c,endtime)[1],label = "zc m2")

m.ext[:variables]

JuMP.value.(m.ext[:variables][:production])

#Start the building process of 3 models 
m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))


gpd["type"] = "TradeCurves"
gpd["target_cap_for_curves"] = "endo_invest"
build_and_save_cost_curves(gpd = gpd,save_soc=true,save_results=true)
m1 = full_build_and_return_investment_model(m1,global_param_dict= gpd)

optimize!(m1)


trade_prices = m1.ext[:sets][:trade_prices]
timesteps = collect(1:endtime)
imports = [JuMP.value.(sum(m1.ext[:variables][:import]["BE00",p,t] for p in trade_prices)) for t in timesteps]
exports = [JuMP.value.(sum(m1.ext[:variables][:export]["BE00",p,t] for p in trade_prices)) for t in timesteps]

#Visualise total imports and exports
plot(imports)
plot!(exports)


#Visualise import/export at different prices 
plot()
for price in trade_prices 
    imports_p = [JuMP.value.(m1.ext[:variables][:import]["BE00",price,t]) for t in timesteps]
    plot!(imports_p,label=("imp",price))
    exports_p = [JuMP.value.(m1.ext[:variables][:export]["BE00",price,t]) for t in timesteps]
    plot!(exports_p,label=("exp",price))
end
plot!()


# Check that trade levels do not exceed maxima
for price in trade_prices 
    imports_p = [JuMP.value.(m1.ext[:variables][:import]["BE00",price,t]) for t in timesteps]
    @assert all(imports_p .<= m1.ext[:timeseries][:trade][:import][price])

    exports_p = [JuMP.value.(m1.ext[:variables][:export]["BE00",price,t]) for t in timesteps]
    @assert all(exports_p .<= m1.ext[:timeseries][:trade][:export][price])
end


# Check that trade at a certain price occurs only if the more interesting price is saturated

#Import
prev_price = trade_prices[1]

for price in trade_prices[2:end]
    println(price)
    imports_prev_price = [JuMP.value.(m1.ext[:variables][:import]["BE00",prev_price,t]) for t in timesteps]
    imports_this_price = [JuMP.value.(m1.ext[:variables][:import]["BE00",price,t]) for t in timesteps]

    prev_equal_to_max = (imports_prev_price .== m1.ext[:timeseries][:trade][:import][prev_price])
    @assert all((prev_equal_to_max .& (imports_this_price .> 0)) .== (imports_this_price.>0))

    if sum((imports_this_price.>0)) >0
        prev_price = price
    end
end
JuMP.value.(m1.ext[:objective])

#Export
prev_price = trade_prices[end]
for price in reverse(trade_prices[1:end-1])
    println(price)
    exports_prev_price = [JuMP.value.(m1.ext[:variables][:export]["BE00",prev_price,t]) for t in timesteps]
    exports_this_price = [JuMP.value.(m1.ext[:variables][:export]["BE00",price,t]) for t in timesteps]

    prev_equal_to_max = (exports_prev_price .== m1.ext[:timeseries][:trade][:export][prev_price])
    #println(m1.ext[:timeseries][:trade][:export][prev_price]-exports_prev_price- prev_equal_to_max*100000)
    # println(exports_this_price)

    @assert all((prev_equal_to_max .& (exports_this_price .> 0)) .== (exports_this_price.>0))

    if sum((exports_this_price.>0)) >0
        prev_price = price
    end
end

