function check_production_below_existing_cap(m_isolated,country)
    ##Check production below existing capacity
    technologies = m_isolated.ext[:sets][:technologies][country]
    for tech in technologies
        cap =  m_isolated.ext[:parameters][:technologies][:capacities][country][tech]
        prod = JuMP.value.([m_isolated.ext[:variables][:production][country,tech,t] for t in 1:endtime])
        @assert(maximum(prod) <= cap )
    end
end

function check_production_below_invested_cap(m_isolated,country)
    ##Check production below invested capacity
    technologies = m_isolated.ext[:sets][:investment_technologies][country]
    for tech in technologies
        cap =  JuMP.value.(m_isolated.ext[:variables][:invested_cap][country,tech])
        prod = JuMP.value.([m_isolated.ext[:variables][:production][country,tech,t] for t in 1:endtime])
        @assert(maximum(prod) <= cap )
    end
end

function check_production_below_invested_plus_existing_cap(m_isolated,country)
    ##Check production below invested capacity
    technologies = m_isolated.ext[:sets][:investment_technologies][country]
    for tech in technologies
        cap =  JuMP.value.(m_isolated.ext[:variables][:invested_cap][country,tech]) + m_isolated.ext[:parameters][:technologies][:capacities][country][tech]
        prod = JuMP.value.([m_isolated.ext[:variables][:production][country,tech,t] for t in 1:endtime])
        @assert(maximum(prod) <= cap )
    end
end