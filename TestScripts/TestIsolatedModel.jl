include("../ImportExport/model_builder.jl")

using Gurobi
using Statistics

scenario = "National Trends"
endtime = 24*50
year = 2025
CY = 1984
CY_ts = 2012
VOLL = 8000

simplified = true
only_bel = false

m = Model(optimizer_with_attributes(Gurobi.Optimizer))
define_sets!(m,scenario,year,CY,[],[],simplified)


all_countries = [key for key in keys(m.ext[:sets][:technologies])]


m_isolated =Model(optimizer_with_attributes(Gurobi.Optimizer))
define_sets!(m_isolated,scenario,year,CY,[],["BE00"],simplified)

m_only_bel = Model(optimizer_with_attributes(Gurobi.Optimizer))
define_sets!(m_only_bel,scenario,year,CY,filter((e->e != "BE00"),all_countries),["BE00"],simplified)

process_parameters!(m_isolated,scenario,year,CY,["BE00"],simplified)
process_time_series!(m_isolated,scenario,year,CY_ts,simplified)
remove_capacity_country!(m_isolated,"BE00")

process_parameters!(m_only_bel,scenario,year,CY,["BE00"],simplified)
process_time_series!(m_only_bel,scenario,year,CY_ts,simplified)
remove_capacity_country!(m_only_bel,"BE00")

build_isolated_investment_model!(m_isolated,endtime,VOLL,0.07,simplified)
optimize!(m_isolated)

build_isolated_investment_model!(m_only_bel,endtime,VOLL,0.07,simplified)
optimize!(m_only_bel)


#Check equivalence of belgian costs between isolated model with only belgium, and isolated model with entire EU
# print("Belgium only = ",only_bel, JuMP.value.(m.ext[:variables][:invested_cap]))
country = "BE00"
CO2_cost_ob = sum(JuMP.value.(m_only_bel.ext[:expressions][:CO2_cost][country,tech,t] for tech in m.ext[:sets][:dispatchable_technologies][country] for t in 1:endtime))
CO2_cost_i = sum(JuMP.value.(m_isolated.ext[:expressions][:CO2_cost][country,tech,t] for tech in m.ext[:sets][:dispatchable_technologies][country] for t in 1:endtime))
@assert(CO2_cost_i==CO2_cost_ob)

ls_cost_ob = sum(JuMP.value.(m_only_bel.ext[:expressions][:load_shedding_cost][country,t] for t in 1:endtime))
ls_cost_i = sum(JuMP.value.(m_isolated.ext[:expressions][:load_shedding_cost][country,t] for t in 1:endtime))
@assert(ls_cost_i==ls_cost_ob)

VOM_cost_ob = sum(JuMP.value.(m_only_bel.ext[:expressions][:VOM_cost][country,tech,t] for tech in m.ext[:sets][:technologies][country] for t in 1:endtime))
VOM_cost_i = sum(JuMP.value.(m_isolated.ext[:expressions][:VOM_cost][country,tech,t] for tech in m.ext[:sets][:technologies][country] for t in 1:endtime))
@assert(VOM_cost_i==VOM_cost_ob)

fuel_cost_ob =sum(JuMP.value.(m_only_bel.ext[:expressions][:fuel_cost][country,tech,t] for tech in m.ext[:sets][:dispatchable_technologies][country] for t in 1:endtime))
fuel_cost_i =sum(JuMP.value.(m_isolated.ext[:expressions][:fuel_cost][country,tech,t] for tech in m.ext[:sets][:dispatchable_technologies][country] for t in 1:endtime))
@assert(fuel_cost_i==fuel_cost_ob)

inv_cost_ob = sum(JuMP.value.(m_only_bel.ext[:expressions][:investment_cost][country,tech] for tech in m_only_bel.ext[:sets][:investment_technologies][country]))
inv_cost_i = sum(JuMP.value.(m_isolated.ext[:expressions][:investment_cost][country,tech] for tech in m_isolated.ext[:sets][:investment_technologies][country]))
@assert(inv_cost_ob == inv_cost_i)

include("StandardTests.jl")

#Check production below cap 
check_production_below_invested_cap(m_isolated,country)
check_production_below_existing_cap(m_isolated,"DE00")


#Inspect capacity factors to check if reasonable 

function get_capacity_factor_invested_tech(m_isolated,country,tech)
    production = [JuMP.value.(m_isolated.ext[:variables][:production][country,tech,t]) for t in 1:endtime]
    cap = JuMP.value.(m_isolated.ext[:variables][:invested_cap][country,tech])
    return mean(production)/cap
end

technologies = m_isolated.ext[:sets][:investment_technologies][country]
for tech in technologies
    println(tech, ": ",get_capacity_factor_invested_tech(m_isolated,country,tech))
end

#Check that if a certain technology is without cost, model depends only on this
tech_of_choice = "w_off"
m_only_bel.ext[:parameters][:investment_technologies][:cost][country][tech_of_choice] = 0
build_isolated_investment_model!(m_only_bel,endtime,VOLL,0.07,simplified)
optimize!(m_only_bel)

tech_values_dict = Dict(tech => JuMP.value.( m_only_bel.ext[:variables][:invested_cap][country,tech]) for tech in m_only_bel.ext[:sets][:investment_technologies][country])

# Check if all values are zero except for the chosen technology
non_zero_values_exist = false
for (tech, tech_value) in tech_values_dict
    if tech != tech_of_choice && tech_value != 0
        non_zero_values_exist = true
        break
    end
end

if non_zero_values_exist
    println("There are non-zero values for technologies other than $tech_of_choice.")
else
    println("All values are zero except for $tech_of_choice.")
end

