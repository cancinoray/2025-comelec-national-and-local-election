{{ config(materialized='view') }}

with source_data as (
    select
        precinct_id,
        machine_id,
        region,
        province,
        municipality,
        barangay,
        voting_center,
        precinct_in_cluster,
        registered_voters,
        actual_voters,
        valid_ballots,
        turnout_percentage,
        abstentions,
        total_er_received
    from {{ source('philippines_election_2025', 'precincts') }}
),

cleaned_data as (
    select
        precinct_id,
        machine_id,
        trim(upper(region)) as region,
        trim(upper(province)) as province,
        trim(upper(municipality)) as municipality,
        trim(upper(barangay)) as barangay,
        trim(voting_center) as voting_center,
        trim(precinct_in_cluster) as precinct_in_cluster,
        registered_voters,
        actual_voters,
        valid_ballots,
        round(turnout_percentage, 2) as turnout_percentage,
        coalesce(abstentions, 0) as abstentions,
        coalesce(total_er_received, 0) as total_er_received,
        
        -- Add derived fields
        actual_voters - valid_ballots as invalid_ballots,
        registered_voters - actual_voters as non_voters,
        
        -- Categorize turnout
        case 
            when turnout_percentage >= 90 then 'Very High'
            when turnout_percentage >= 80 then 'High'
            when turnout_percentage >= 70 then 'Medium'
            when turnout_percentage >= 60 then 'Low'
            else 'Very Low'
        end as turnout_category,
        
        -- Extract region number
        regexp_extract(region, r'REGION (\w+)') as region_code
        
    from source_data
    where registered_voters > 0  -- Filter out invalid precincts
      and actual_voters >= 0
      and turnout_percentage between 0 and 100
)

select * from cleaned_data
