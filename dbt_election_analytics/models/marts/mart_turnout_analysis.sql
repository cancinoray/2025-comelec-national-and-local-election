{{ config(materialized='table') }}

with geographic_analysis as (
    select * from {{ ref('int_geographic_analysis') }}
),

regional_turnout as (
    select
        region,
        sum(total_registered_voters) as region_registered_voters,
        sum(total_actual_voters) as region_actual_voters,
        avg(avg_turnout_percentage) as region_avg_turnout,
        sum(total_precincts) as region_total_precincts,
        sum(precincts_very_high_turnout) as region_very_high_turnout_precincts,
        sum(precincts_high_turnout) as region_high_turnout_precincts,
        sum(precincts_medium_turnout) as region_medium_turnout_precincts,
        sum(precincts_low_turnout) as region_low_turnout_precincts,
        sum(precincts_very_low_turnout) as region_very_low_turnout_precincts,
        
        -- Calculate regional turnout rate
        case 
            when sum(total_registered_voters) > 0 
            then round((sum(total_actual_voters) * 100.0) / sum(total_registered_voters), 2)
            else 0 
        end as region_calculated_turnout_rate,
        
        -- Regional turnout distribution
        round((sum(precincts_very_high_turnout) * 100.0) / sum(total_precincts), 2) as pct_very_high_turnout,
        round((sum(precincts_high_turnout) * 100.0) / sum(total_precincts), 2) as pct_high_turnout,
        round((sum(precincts_medium_turnout) * 100.0) / sum(total_precincts), 2) as pct_medium_turnout,
        round((sum(precincts_low_turnout) * 100.0) / sum(total_precincts), 2) as pct_low_turnout,
        round((sum(precincts_very_low_turnout) * 100.0) / sum(total_precincts), 2) as pct_very_low_turnout
        
    from geographic_analysis
    group by region
),

provincial_turnout as (
    select
        region,
        province,
        sum(total_registered_voters) as province_registered_voters,
        sum(total_actual_voters) as province_actual_voters,
        avg(avg_turnout_percentage) as province_avg_turnout,
        sum(total_precincts) as province_total_precincts,
        
        -- Provincial turnout rate
        case 
            when sum(total_registered_voters) > 0 
            then round((sum(total_actual_voters) * 100.0) / sum(total_registered_voters), 2)
            else 0 
        end as province_calculated_turnout_rate,
        
        -- Provincial ranking within region
        row_number() over (
            partition by region 
            order by avg(avg_turnout_percentage) desc
        ) as province_turnout_rank_in_region
        
    from geographic_analysis
    group by region, province
),

municipal_turnout as (
    select
        region,
        province,
        municipality,
        sum(total_registered_voters) as municipality_registered_voters,
        sum(total_actual_voters) as municipality_actual_voters,
        avg(avg_turnout_percentage) as municipality_avg_turnout,
        sum(total_precincts) as municipality_total_precincts,
        
        -- Municipal turnout rate
        case 
            when sum(total_registered_voters) > 0 
            then round((sum(total_actual_voters) * 100.0) / sum(total_registered_voters), 2)
            else 0 
        end as municipality_calculated_turnout_rate,
        
        -- Municipal ranking within province
        row_number() over (
            partition by region, province 
            order by avg(avg_turnout_percentage) desc
        ) as municipality_turnout_rank_in_province,
        
        -- Municipal size category
        case 
            when sum(total_registered_voters) >= 100000 then 'Very Large'
            when sum(total_registered_voters) >= 50000 then 'Large'
            when sum(total_registered_voters) >= 20000 then 'Medium'
            when sum(total_registered_voters) >= 5000 then 'Small'
            else 'Very Small'
        end as municipality_size_category
        
    from geographic_analysis
    group by region, province, municipality
),

turnout_insights as (
    select
        rt.*,
        
        -- Regional turnout category
        case 
            when rt.region_calculated_turnout_rate >= 85 then 'Excellent'
            when rt.region_calculated_turnout_rate >= 80 then 'Very Good'
            when rt.region_calculated_turnout_rate >= 75 then 'Good'
            when rt.region_calculated_turnout_rate >= 70 then 'Fair'
            else 'Poor'
        end as region_turnout_category,
        
        -- Regional ranking
        row_number() over (order by rt.region_calculated_turnout_rate desc) as region_turnout_rank,
        
        -- High engagement indicator
        case 
            when rt.pct_very_high_turnout + rt.pct_high_turnout >= 60 then true 
            else false 
        end as high_engagement_region
        
    from regional_turnout rt
)

select
    ti.*,
    pt.province,
    pt.province_calculated_turnout_rate,
    pt.province_turnout_rank_in_region,
    mt.municipality,
    mt.municipality_calculated_turnout_rate,
    mt.municipality_turnout_rank_in_province,
    mt.municipality_size_category
    
from turnout_insights ti
left join provincial_turnout pt on ti.region = pt.region
left join municipal_turnout mt on pt.region = mt.region and pt.province = mt.province
order by ti.region_turnout_rank, pt.province_turnout_rank_in_region, mt.municipality_turnout_rank_in_province
