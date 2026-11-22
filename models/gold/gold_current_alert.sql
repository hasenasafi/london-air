-- GOLD: right now, per site. Uses each pollutant's latest hour in the last 24 hours,
-- then takes the worst one. This answers "should we warn patients today?"

with hourly as (
    select * from {{ ref('gold_hourly_index') }}
    where daqi_index is not null
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
        max(measured_at_gmt)                  as latest_reading_gmt,
        max(daqi_index)                       as daqi_index,
        arg_max(pollutant_name, daqi_index)   as worst_pollutant
    from latest_per_pollutant
    group by all
),

advice as (
    select * from {{ ref('daqi_advice') }}
)

select
    s.*,
    case
        when s.daqi_index <= 3 then 'Low'
        when s.daqi_index <= 6 then 'Moderate'
        when s.daqi_index <= 9 then 'High'
        else 'Very High'
    end                               as band,
    s.daqi_index >= 4                 as warn_respiratory_patients,
    a.advice_at_risk
from site_now s
left join advice a
    on a.band = case
        when s.daqi_index <= 3 then 'Low'
        when s.daqi_index <= 6 then 'Moderate'
        when s.daqi_index <= 9 then 'High'
        else 'Very High'
    end
