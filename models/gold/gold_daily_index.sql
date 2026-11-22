-- GOLD: the DAQI for each site, pollutant and day (the official method for past days).
--   NO2          -> the highest hourly value of the day
--   PM2.5, PM10  -> the mean of the day (only if 18+ hours were measured, i.e. 75%)

with readings as (
    select * from {{ ref('silver_readings') }}
),

daily as (
    select
        site_code,
        site_name,
        borough,
        species_code,
        pollutant_name,
        reading_date_gmt,
        count(*)                 as hours_measured,
        avg(concentration_ugm3)  as daily_mean_ugm3,
        max(concentration_ugm3)  as daily_max_hourly_ugm3
    from readings
    group by all
),

for_index as (
    select
        *,
        hours_measured >= 18 as is_complete_day,
        case
            when species_code = 'NO2' then daily_max_hourly_ugm3
            when hours_measured >= 18  then daily_mean_ugm3
        end as index_concentration_ugm3
    from daily
),

bands as (
    select * from {{ ref('daqi_bands') }}
)

select
    f.*,
    b.daqi_index,
    b.band
from for_index f
left join bands b
    on  b.species_code = f.species_code
    and round(f.index_concentration_ugm3) >= b.lower_bound_ugm3
qualify row_number() over (
    partition by f.site_code, f.species_code, f.reading_date_gmt
    order by b.daqi_index desc
) = 1
