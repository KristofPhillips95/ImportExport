include("../ImportExport/model_builder.jl")
using Gurobi
using Plots

scenario = "National Trends"
endtime = 24*20
year = 2025
CY = 1984
CY_ts = 2012
VOLL = 8000
investment_country = "BE00"

m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))
define_sets_simplified!(m1,scenario,year,CY,[],[investment_country])
process_parameters_simplified!(m1,scenario,year,CY,[investment_country])
process_time_series!(m1,scenario,year,CY_ts, true,endtime)
remove_capacity_country!(m1,investment_country,true)
build_NTC_investment_model!(m1,endtime,VOLL,0.1,0.07,true)
optimize!(m1)


m2 = Model(optimizer_with_attributes(Gurobi.Optimizer))
define_sets!(m2,scenario,year,CY,[],[investment_country])
process_parameters!(m2,scenario,year,CY,[investment_country])
process_time_series!(m2,scenario,year,CY_ts, false,endtime)
remove_capacity_country!(m2,investment_country,false)

build_NTC_investment_model!(m2,endtime,VOLL,0.1,0.07,false)
optimize!(m2)

sum(JuMP.value.(m1.ext[:expressions][:production_cost]))
sum(JuMP.value.(m2.ext[:expressions][:production_cost]))

sum(JuMP.value.(m1.ext[:expressions][:load_shedding_cost]))
sum(JuMP.value.(m2.ext[:expressions][:load_shedding_cost]))