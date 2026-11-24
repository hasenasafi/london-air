-- Mart (grain: one row per site). Feeds "Today's alert" map and the "Today" headline.
-- Uses each pollutant's latest reading in the last 24 hours, then takes the worst one,
-- so a sensor that has stopped reporting can't show an old "Low" as if it were current.

with hourly as (

    select * from {{ ref('int_daqi_hourly') }}
    where daqi_index is not null

),

levels as (

    select * from {{ ref('int_daqi_levels') }}

),

latest_per_pollutant as (

    select *
    from hourly
    where measured_at_gmt >= (select max(measured_at_gmt) from hourly) - interval 24 hours
    qualify row_number() over (
        partition by site_code, species_code
        order by measured_at_gmt desc
    ) = 1

),

site_now as (

    select
        site_code,
        site_name,
        borough,
        site_type,
        latitude,
        longitude,
        max(measured_at_gmt)                    as latest_reading_gmt,
        max(daqi_index)                         as daqi_index,
        arg_max(pollutant_name, daqi_index)     as worst_pollutant

    from latest_per_pollutant
    group by all

),

final as (

    select
        site_now.*,
        levels.band,
        levels.warn_respiratory_patients,
        levels.advice_at_risk

    from site_now
    left join levels
        on levels.daqi_index = site_now.daqi_index

)

select * from final
