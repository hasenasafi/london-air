-- Mart (grain: site x day). Feeds the daily history calendar and the
-- "warning days" and "worst day" headline numbers.
-- A site's DAQI for the day is its WORST pollutant, as the official index defines it.

with daily_by_pollutant as (

    select * from {{ ref('int_daqi_daily_by_pollutant') }}
    where daqi_index is not null

),

levels as (

    select * from {{ ref('int_daqi_levels') }}

),

site_day as (

    select
        site_code,
        site_name,
        borough,
        site_type,
        latitude,
        longitude,
        reading_date_gmt,
        max(daqi_index)                         as daqi_index,
        arg_max(pollutant_name, daqi_index)     as worst_pollutant,
        count(*)                                as pollutants_measured

    from daily_by_pollutant
    group by all

),

final as (

    select
        site_day.*,
        levels.band,
        levels.warn_respiratory_patients,
        levels.advice_at_risk

    from site_day
    left join levels
        on levels.daqi_index = site_day.daqi_index

)

select * from final
