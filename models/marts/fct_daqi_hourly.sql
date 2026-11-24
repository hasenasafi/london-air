-- Mart (grain: site x pollutant x hour). Feeds the PM2.5 trend charts.
-- All pollutants are kept; Tableau filters to the one it needs.

with hourly as (

    select * from {{ ref('int_daqi_hourly') }}

),

levels as (

    select * from {{ ref('int_daqi_levels') }}

),

final as (

    select
        hourly.site_code,
        hourly.site_name,
        hourly.borough,
        hourly.site_type,
        hourly.latitude,
        hourly.longitude,
        hourly.species_code,
        hourly.pollutant_name,
        hourly.measured_at_gmt,
        hourly.reading_date_gmt,
        hourly.hourly_ugm3,
        hourly.index_concentration_ugm3,
        hourly.averaging_used,
        hourly.daqi_index,
        levels.band

    from hourly
    left join levels
        on levels.daqi_index = hourly.daqi_index

)

select * from final
