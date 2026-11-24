-- Intermediate: one clean row per site, pollutant and hour, with site details joined on.

with readings as (

    select * from {{ ref('stg_laqn__readings') }}

),

sites as (

    select * from {{ ref('stg_laqn__sites') }}

),

enriched as (

    select
        -- one id per reading, so a test can prove there are no duplicates
        readings.site_code || '-' || readings.species_code || '-'
            || strftime(readings.measured_at_gmt, '%Y%m%d%H')      as reading_id,

        readings.site_code,
        sites.site_name,
        sites.borough,
        sites.site_type,
        sites.latitude,
        sites.longitude,

        readings.species_code,
        case readings.species_code
            when 'NO2'  then 'Nitrogen dioxide'
            when 'PM25' then 'Fine particulates (PM2.5)'
            when 'PM10' then 'Particulates (PM10)'
            else readings.species_code
        end                                                         as pollutant_name,

        readings.measured_at_gmt,
        cast(readings.measured_at_gmt as date)                      as reading_date_gmt,
        readings.concentration_ugm3

    from readings
    left join sites
        on sites.site_code = readings.site_code

    -- negative concentrations are instrument noise around zero, not real air
    where readings.concentration_ugm3 >= 0

)

select * from enriched
