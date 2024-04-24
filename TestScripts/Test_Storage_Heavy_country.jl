include("../ImportExport/build_and_run.jl")
include("../ImportExport/build_and_save_cost_curves.jl")
using Gurobi
using Plots



gpd = Dict()

endtime = gpd["endtime"] = 24*10
CY = gpd["Climate_year"] = 1984
CY_ts= gpd["Climate_year_ts"] = 2012
VOLL = gpd["ValOfLostLoad"] = 8000
country = gpd["country"] = "SE03" 
scenario = gpd["scenario"] = "National Trends"
year = gpd["year"] = 2025
gpd["stepsize"] = 100
transp_price = gpd["transport_price"] = 0.1
simplified = gpd["simplified"] = false
disc_rate = gpd["disc_rate"] = 0.07
geo_scope = gpd["geo_scope"] = ["FI00", "SE02","DKW1","SE04","NOS0","SE03"]
geo_scope = gpd["geo_scope"] = "All"
gpd["trans_cap_other"] = "S"
gpd["target_cap_for_curves"] = "TYNDP"


m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))

gpd["type"] = "NTC"
m1 = full_build_and_return_investment_model(m1,global_param_dict = gpd)
# gpd["type"] = "TCS"
# m2 = full_build_and_return_investment_model(m2,global_param_dict = gpd)


##First find some nodes with a lot of storage 

##############################################################################
##############################################################################
# neighb_stor_cap = Dict()
# neighb_stor_e_cap = Dict()

# neighb_stor_cap_s = Dict()
# neighb_stor_e_cap_s = Dict()

# own_stor_cap = Dict()
# own_stor_e_cap = Dict()

# excluded_countries = ["CY00","FR15","DKKF"]
# for c in m1.ext[:sets][:countries]
#     if !(c in excluded_countries)
#         println(c)
#         neighb_stor_cap[c] = Dict()
#         neighb_stor_e_cap[c] = Dict()
#         peak_dem = 1
#         if !(isempty(m1.ext[:sets][:soc_technologies][c]))
#             own_stor_cap[c] = sum(m1.ext[:parameters][:technologies][:capacities][c][tech] for tech in m1.ext[:sets][:soc_technologies][c]) /peak_dem
#             own_stor_e_cap[c] = sum(m1.ext[:parameters][:technologies][:energy_capacities][c][tech] for tech in m1.ext[:sets][:soc_technologies][c]) /peak_dem
#         end
#         for neighb in m1.ext[:sets][:connections][c]
#             if !(isempty(m1.ext[:sets][:soc_technologies][neighb]))

#                 neighb_stor_cap[c][neighb] = sum(m1.ext[:parameters][:technologies][:capacities][neighb][tech] for tech in m1.ext[:sets][:soc_technologies][neighb])
#                 neighb_stor_e_cap[c][neighb] = sum(m1.ext[:parameters][:technologies][:energy_capacities][neighb][tech] for tech in m1.ext[:sets][:soc_technologies][neighb])
#                 # println(neighb_stor_cap)
#                 # println(neighb_stor_e_cap)
#             end
#         end
#         neighb_stor_cap_s[c] = sum(neighb_stor_cap[c][neighb] for neighb in keys(neighb_stor_cap[c]) )/peak_dem
#         neighb_stor_e_cap_s[c] = sum(neighb_stor_e_cap[c][neighb] for neighb in keys(neighb_stor_e_cap[c]) )/peak_dem
#     end
# end


# println("START")

# # Convert keys to an array and sort them by values in neighb_stor_cap_s in descending order
# sorted_keys = sort(collect(keys(neighb_stor_cap_s)), by=x->neighb_stor_e_cap_s[x], rev=true)

# for c in sorted_keys
#     println(c)
#     println(neighb_stor_cap_s[c])
#     println(neighb_stor_e_cap_s[c])
# end


# neighb_stor_cap_s["SE03"]
# neighb_stor_e_cap_s["SE03"]

# own_stor_cap
# own_stor_e_cap

##############################################################################
##############################################################################

gpd = Dict()

endtime = gpd["endtime"] = 24*365
CY = gpd["Climate_year"] = 1984
CY_ts= gpd["Climate_year_ts"] = 2012
VOLL = gpd["ValOfLostLoad"] = 8000
country = gpd["country"] = "SE03" 
scenario = gpd["scenario"] = "National Trends"
year = gpd["year"] = 2025
gpd["stepsize"] = 1000
transp_price = gpd["transport_price"] = 0.1
simplified = gpd["simplified"] = false
disc_rate = gpd["disc_rate"] = 0.07
geo_scope = gpd["geo_scope"] = ["FI00", "SE02","DKW1","SE04","NOS0","SE03"]
gpd["trans_cap_other"] = "S"
gpd["target_cap_for_curves"] = "TYNDP"


m1 = Model(optimizer_with_attributes(Gurobi.Optimizer))
m2 = Model(optimizer_with_attributes(Gurobi.Optimizer))

gpd["type"] = "NTC"
m1 = full_build_and_return_investment_model(m1,global_param_dict = gpd)
gpd["type"] = "TCS"
m2 = full_build_and_return_investment_model(m2,global_param_dict = gpd)

optimize!(m1)
optimize!(m2)


JuMP.value.(m1.ext[:variables][:invested_cap])
JuMP.value.(m2.ext[:variables][:invested_cap])

Dict( neighb => m1.ext[:timeseries][:demand][neighb] for neighb in m1.ext[:sets][:connections][country])
m1.ext[:sets][:technologies]["SE03"]

m1.ext[:sets][:technologies][country]
m1.ext[:parameters][:connections]["NOM1"]

m1.ext[:sets][:investment_technologies][country]
m1.ext[:sets][:non_investment_technologies][country]


m1.ext[:parameters][:technologies][:capacities]["DE00"]
m1.ext[:parameters][:technologies][:energy_capacities]

