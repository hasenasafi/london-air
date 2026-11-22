-- GOLD: one row per site per day. The day's DAQI is the WORST pollutant at that site,
-- with the advice for at-risk patients for that band. This is what the dashboard shows.

with daily as (
    select * from {{ ref('gold_daily_index') }}
    where daqi_index is not null
),

site_day as (
    select
        site_code,
        site_name,
        borough,
        reading_date_gmt,
        max(daqi_index)                       as daqi_index,
        arg_max(pollutant_name, daqi_index)   as worst_pollutant,
        count(*)                              as pollutants_measured
    from daily
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
from site_day s
left join advice a
    on a.band = case
        when s.daqi_index <= 3 then 'Low'
        when s.daqi_index <= 6 then 'Moderate'
        when s.daqi_index <= 9 then 'High'
        else 'Very High'
    end
