{{ config(materialized='view') }}

with election_results as (
    select * from {{ ref('stg_election_results') }}
),

precincts as (
    select * from {{ ref('stg_precincts') }}
),

candidate_stats as (
    select
        er.contest_code,
        er.contest_name,
        er.position_type,
        er.clean_candidate_name,
        er.party,
        
        -- Vote aggregations
        sum(er.votes) as total_votes,
        count(distinct er.precinct_id) as precincts_contested,
        avg(er.percentage) as avg_percentage_per_precinct,
        min(er.percentage) as min_percentage,
        max(er.percentage) as max_percentage,
        stddev(er.percentage) as stddev_percentage,
        
        -- Performance metrics
        sum(case when er.percentage > 50 then 1 else 0 end) as precincts_majority,
        sum(case when er.percentage > 25 then 1 else 0 end) as precincts_strong,
        sum(case when er.percentage < 5 then 1 else 0 end) as precincts_weak,
        
        -- Regional performance
        count(distinct p.region) as regions_contested,
        count(distinct p.province) as provinces_contested,
        count(distinct p.municipality) as municipalities_contested
        
    from election_results er
    left join precincts p on er.precinct_id = p.precinct_id
    group by 1, 2, 3, 4, 5
),

candidate_rankings as (
    select
        *,
        row_number() over (
            partition by contest_code 
            order by total_votes desc
        ) as vote_rank,
        
        percent_rank() over (
            partition by contest_code 
            order by total_votes desc
        ) as vote_percentile,
        
        -- Calculate vote share within contest
        total_votes / sum(total_votes) over (partition by contest_code) as vote_share
        
    from candidate_stats
)

select * from candidate_rankings
