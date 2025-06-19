{{ config(materialized='view') }}

with precincts as (
    select * from {{ ref('stg_precincts') }}
),

election_results as (
    select * from {{ ref('stg_election_results') }}
),

geographic_turnout as (
    select
        region,
        province,
        municipality,
        barangay,
        
        -- Voter statistics
        sum(registered_voters) as total_registered_voters,
        sum(actual_voters) as total_actual_voters,
        sum(valid_ballots) as total_valid_ballots,
        sum(invalid_ballots) as total_invalid_ballots,
        sum(non_voters) as total_non_voters,
        
        -- Turnout metrics
        avg(turnout_percentage) as avg_turnout_percentage,
        min(turnout_percentage) as min_turnout_percentage,
        max(turnout_percentage) as max_turnout_percentage,
        stddev(turnout_percentage) as stddev_turnout_percentage,
        
        -- Precinct counts
        count(*) as total_precincts,
        sum(case when turnout_category = 'Very High' then 1 else 0 end) as precincts_very_high_turnout,
        sum(case when turnout_category = 'High' then 1 else 0 end) as precincts_high_turnout,
        sum(case when turnout_category = 'Medium' then 1 else 0 end) as precincts_medium_turnout,
        sum(case when turnout_category = 'Low' then 1 else 0 end) as precincts_low_turnout,
        sum(case when turnout_category = 'Very Low' then 1 else 0 end) as precincts_very_low_turnout
        
    from precincts
    group by 1, 2, 3, 4
),

vote_concentration as (
    select
        p.region,
        p.province,
        p.municipality,
        p.barangay,
        er.position_type,
        
        -- Vote distribution metrics
        sum(er.votes) as total_votes_cast,
        count(distinct er.clean_candidate_name) as candidates_with_votes,
        max(er.votes) as highest_candidate_votes,
        
        -- Calculate Herfindahl-Hirschman Index for vote concentration
        sum(power(er.votes / sum(er.votes) over (
            partition by p.region, p.province, p.municipality, p.barangay, er.position_type
        ), 2)) as vote_concentration_index
        
    from precincts p
    join election_results er on p.precinct_id = er.precinct_id
    where er.votes > 0
    group by 1, 2, 3, 4, 5
),

final_geographic_analysis as (
    select
        gt.*,
        
        -- Calculate overall turnout rate
        case 
            when gt.total_registered_voters > 0 
            then round((gt.total_actual_voters * 100.0) / gt.total_registered_voters, 2)
            else 0 
        end as calculated_turnout_rate,
        
        -- Calculate invalid ballot rate
        case 
            when gt.total_actual_voters > 0 
            then round((gt.total_invalid_ballots * 100.0) / gt.total_actual_voters, 2)
            else 0 
        end as invalid_ballot_rate,
        
        -- Categorize geographic areas by size
        case 
            when gt.total_registered_voters >= 50000 then 'Large'
            when gt.total_registered_voters >= 10000 then 'Medium'
            when gt.total_registered_voters >= 1000 then 'Small'
            else 'Very Small'
        end as area_size_category
        
    from geographic_turnout gt
)

select * from final_geographic_analysis
