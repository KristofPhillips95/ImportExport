include("ImportExport/build_and_run.jl")
include("ImportExport/build_and_save_cost_curves.jl")

using Gurobi


function main(gpd, results_path, simplifieds, types, geo_scopes, target_caps_for_curves,stepsizes, trans_caps_others)
    results = DataFrame()
    for simpl in simplifieds
        gpd["simplified"] = simpl

        for type in types
            gpd["type"] = type

            if gpd["type"] != "isolated"
                for geo_scope in geo_scopes
                    gpd["geo_scope"] = geo_scope

                    if gpd["type"] == "TCS"
                        gpd["trans_cap_other"] = "NA"

                        for tcfc in target_caps_for_curves
                            gpd["target_cap_for_curves"] = tcfc
                            for stepsize in stepsizes
                                gpd["stepsize"] = stepsize

                                m = Model(optimizer_with_attributes(Gurobi.Optimizer))
                                row = full_build_and_optimize_investment_model(m, global_param_dict=gpd)

                                global results = vcat(results,row)
                                # Write results to CSV after each iteration
                                CSV.write(results_path, results)
                            end
                        end
                    elseif type == "NTC"
                        @assert type in ["TCPC", "NTC"]
                        gpd["target_cap_for_curves"] = "NA"
                        gpd["stepsize"] = "NA"

                        for trans_cap_other in trans_caps_others
                            gpd["trans_cap_other"] = trans_cap_other

                            m = Model(optimizer_with_attributes(Gurobi.Optimizer))
                            row = full_build_and_optimize_investment_model(m, global_param_dict=gpd)

                            global results = vcat(results,row)
                            # Write results to CSV after each iteration
                            CSV.write(results_path, results)
                        end
                    else
                        @assert type == "TCPC"
                        gpd["target_cap_for_curves"] = "NA"
                        gpd["stepsize"] = "NA"
                        gpd["trans_cap_other"] = "NA"

                        m = Model(optimizer_with_attributes(Gurobi.Optimizer))
                        row = full_build_and_optimize_investment_model(m, global_param_dict=gpd)

                        global results = vcat(results,row)
                        # Write results to CSV after each iteration
                        CSV.write(results_path, results)
                    end
                end
            else
                gpd["target_cap_for_curves"] = "NA"
                gpd["stepsize"] = "NA"
                gpd["geo_scope"] = "NA"

                m = Model(optimizer_with_attributes(Gurobi.Optimizer))
                row = full_build_and_optimize_investment_model(m, global_param_dict=gpd)

                global results = vcat(results,row)
                # Write results to CSV after each iteration
                CSV.write(results_path, results)
            end
        end
    end
end
