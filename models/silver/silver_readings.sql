-- SILVER: one clean row per site, pollutant and hour, with site details joined on.

with readings as (
    select * from {{ source('bronze', 'raw_readings') }}
),

sites as (
    select * from {{ ref('bronze_sites') }}
)

select
    -- one id per reading, so we can test there are no duplicates
    r.site_code || '-' || r.species_code || '-' || strftime(r.measured_at, '%Y%m%d%H') as reading_id,

    r.site_code,
    s.site_name,
    s.borough,
    s.site_type,

    r.species_code,
    case r.species_code
        when 'NO2'  then 'Nitrogen dioxide'
        when 'PM25' then 'Fine particulates (PM2.5)'
        when 'PM10' then 'Particulates (PM10)'
        else r.species_code
    end                              as pollutant_name,

    r.measured_at                    as measured_at_gmt,   -- the API reports in GMT all year (no summer time)
    cast(r.measured_at as date)      as reading_date_gmt,
    r.value                          as concentration_ugm3, -- micrograms per cubic metre
    r.loaded_at

from readings r
left join sites s on s.site_code = r.site_code

-- negative concentrations are instrument noise around zero, not real air
where r.value >= 0
