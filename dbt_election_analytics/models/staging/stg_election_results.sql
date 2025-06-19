{{ config(materialized='view') }}

with source_data as (
    select
        precinct_id,
        contest_code,
        contest_name,
        candidate_name,
        party,
        votes,
        percentage,
        election_level,
        over_votes,
        under_votes,
        valid_votes,
        obtained_votes
    from {{ source('philippines_election_2025', 'election_results') }}
),

cleaned_data as (
    select
        precinct_id,
        contest_code,
        trim(contest_name) as contest_name,
        trim(candidate_name) as candidate_name,
        case 
            when trim(party) = '' then 'INDEPENDENT'
            else trim(party)
        end as party,
        votes,
        round(percentage, 2) as percentage,
        lower(trim(election_level)) as election_level,
        coalesce(over_votes, 0) as over_votes,
        coalesce(under_votes, 0) as under_votes,
        coalesce(valid_votes, 0) as valid_votes,
        coalesce(obtained_votes, 0) as obtained_votes,
        
        -- Add derived fields
        case 
            when contest_name like '%SENATOR%' then 'SENATOR'
            when contest_name like '%PRESIDENT%' then 'PRESIDENT'
            when contest_name like '%VICE PRESIDENT%' then 'VICE_PRESIDENT'
            when contest_name like '%GOVERNOR%' then 'GOVERNOR'
            when contest_name like '%MAYOR%' then 'MAYOR'
            when contest_name like '%CONGRESSMAN%' or contest_name like '%REPRESENTATIVE%' then 'CONGRESSMAN'
            else 'OTHER'
        end as position_type,
        
        -- Extract candidate number from name
        regexp_extract(candidate_name, r'^(\d+)\.') as candidate_number,
        
        -- Clean candidate name (remove number prefix)
        trim(regexp_replace(candidate_name, r'^\d+\.\s*', '')) as clean_candidate_name
        
    from source_data
    where votes >= 0  -- Filter out any negative vote counts
)

select * from cleaned_data
