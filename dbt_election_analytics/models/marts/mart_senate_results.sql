{{ config(materialized='table') }}

with candidate_performance as (
    select * from {{ ref('int_candidate_performance') }}
    where position_type = 'SENATOR'
),

geographic_analysis as (
    select * from {{ ref('int_geographic_analysis') }}
),

senate_winners as (
    select
        contest_code,
        contest_name,
        clean_candidate_name,
        party,
        total_votes,
        vote_share,
        vote_rank,
        precincts_contested,
        regions_contested,
        provinces_contested,
        municipalities_contested,
        avg_percentage_per_precinct,
        precincts_majority,
        precincts_strong,
        precincts_weak,
        
        -- Determine if candidate won (top 12 for Senate)
        case when vote_rank <= 12 then true else false end as is_winner,
        
        -- Calculate margin from 12th place
        total_votes - lag(total_votes, 12-vote_rank) over (order by total_votes desc) as margin_from_12th,
        
        -- Performance categories
        case 
            when vote_rank <= 3 then 'Top Tier'
            when vote_rank <= 6 then 'Upper Tier'
            when vote_rank <= 12 then 'Winning Tier'
            when vote_rank <= 20 then 'Competitive'
            else 'Non-Competitive'
        end as performance_tier
        
    from candidate_performance
),

regional_performance as (
    select
        sr.clean_candidate_name,
        sr.party,
        sr.is_winner,
        p.region,
        sum(er.votes) as regional_votes,
        avg(er.percentage) as avg_regional_percentage,
        count(distinct er.precinct_id) as regional_precincts,
        
        -- Regional ranking
        row_number() over (
            partition by p.region 
            order by sum(er.votes) desc
        ) as regional_rank
        
    from senate_winners sr
    join {{ ref('stg_election_results') }} er 
        on sr.clean_candidate_name = er.clean_candidate_name
        and er.position_type = 'SENATOR'
    join {{ ref('stg_precincts') }} p 
        on er.precinct_id = p.precinct_id
    group by 1, 2, 3, 4
),

final_senate_results as (
    select
        sw.*,
        
        -- Add regional strongholds (regions where candidate ranked in top 3)
        array_agg(
            case when rp.regional_rank <= 3 then rp.region else null end 
            ignore nulls
        ) as regional_strongholds,
        
        -- Count of regions where candidate was top 3
        countif(rp.regional_rank <= 3) as stronghold_regions_count,
        
        -- Geographic spread metrics
        stddev(rp.avg_regional_percentage) as regional_performance_variance,
        min(rp.avg_regional_percentage) as weakest_region_percentage,
        max(rp.avg_regional_percentage) as strongest_region_percentage
        
    from senate_winners sw
    left join regional_performance rp 
        on sw.clean_candidate_name = rp.clean_candidate_name
    group by all columns except regional_strongholds, stronghold_regions_count, 
             regional_performance_variance, weakest_region_percentage, strongest_region_percentage
)

select * from final_senate_results
order by vote_rank
